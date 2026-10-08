class_name WeaponManager
extends Node
## Two gun slots plus a melee weapon (the knife, always carried). Handles firing,
## ADS, reload, switching (Q = last weapon), inspect, melee, throwing (G), picking
## up (E, or walk over a dropped gun with a free slot) and buying (the buy menu
## calls buy() while you're in a buy zone).
## Lives under the Player.
## Shots are hitscan from the eye. Recoil kicks the real view (Apex style): ADS
## shots land exactly on the crosshair, and you pull down against a fixed pattern.
## Keyframed animations (draw flourishes, inspect, reload, slashes) live in each
## viewmodel scene's AnimationPlayer. Holster and throw motion is procedural here.
## viewmodel.gd still does sway/bob, the ADS blend and recoil kick.

signal hit_confirmed(headshot: bool, killed: bool)
signal fired

enum Action { NONE, RELOAD, HOLSTER, DRAW, INSPECT, MELEE, THROW }
enum Melee { LIGHT, HEAVY, QUICK }
enum Shells { START, LOAD, END } ## Phases of a shell-by-shell reload.

const GUN_SLOTS := 2
const MELEE_SLOT := 2
const BLEND := 0.12 ## Seconds to blend between animations.


## One carried weapon and its viewmodel.
class Slot:
	var data: WeaponData
	var mag: int
	var reserve: int
	var model: Node3D
	var anim: AnimationPlayer
	var muzzle: Node3D
	var flash: Node3D
	var bolt: Node3D
	var bolt_rest: Vector3
	var draw_index: int = 0 ## Which draw animation comes next (they take turns).


@export var starting_weapons: Array[WeaponData] = [] ## Up to two guns.
@export var melee_weapon: WeaponData ## Fallback; the knife last bought in the buy menu (saved in Settings) wins.
@export var infinite_reserve: bool = true
@export var always_flourish_guns: bool = true ## Guns always play their full "draw" flourish. Off = they take turns with their other draw* animations (knives always do).
@export var stow_on_switch: bool = false ## Lower the old weapon before drawing the new one. Off = CS style: the new weapon's draw starts straight away.
@export var max_range: float = 300.0

@export_group("Throw / Pickup")
@export var pickup_range: float = 2.5
@export var auto_pickup_radius: float = 1.0 ## Walk this close to a dropped gun with a free slot and it's yours.
@export var throw_speed: float = 13.0
@export var throw_time: float = 0.34
@export var throw_release: float = 0.15 ## Seconds into the throw when the gun leaves your hand.

@onready var player: Player = get_parent()
@onready var viewmodel: Viewmodel = player.get_node("Head/Camera3D/Viewmodel")

var buy_zones: int = 0 ## How many buy zones you're standing in (BuyZone updates it).
var current: int = MELEE_SLOT
var ads: float = 0.0 ## 0 = hip, 1 = fully aimed.
var action: Action = Action.NONE

var _slots: Array = [null, null, null] ## Slot or null. 0-1 guns, 2 melee.
var _action_t: float = 0.0
var _action_len: float = 0.0
var _pending: int = 0 ## Slot to draw once the holster finishes.
var _last_gun: int = 0
var _last_slot: int = -1 ## The weapon you had out before this one (Q).
var _shell_phase: Shells = Shells.START
var _stop_after_shell := false ## Fire was pressed mid shell reload: finish this shell, close up, then you can shoot.
var _melee_kind: Melee = Melee.LIGHT
var _melee_hit_time: float = 0.0
var _melee_damage: float = 0.0
var _melee_done: bool = false
var _slash_left: bool = false
var _thrown: bool = false
var _shot_timer: float = 0.0
var _draw_left: float = 0.0 ## Draw time still to go. Inspecting a knife mid-draw doesn't skip it.
var _prime: float = 0.0 ## Seconds the revolver hammer has been cocking.
var _semi_buffer: float = 0.0 ## Fire pressed recently (buffers semi-auto clicks).
var _spray_index: int = 0
var _since_shot: float = 99.0
var _bloom: float = 0.0
var _sprint_out: float = 0.0
var _aim_toggled: bool = false
var _reload_committed: bool = false
var _commit_at: float = 0.0 ## Seconds into the reload (or shell) when the ammo goes in: the "mag_in" moment.
var _bolt_kick: float = 0.0
var _flash_timer: float = 0.0
var _want_reload: bool = false
var _want_inspect: bool = false
var _want_melee: bool = false
var _want_heavy: bool = false
var _want_throw: bool = false
var _want_pickup: bool = false


func _ready() -> void:
	for i in mini(starting_weapons.size(), GUN_SLOTS):
		if starting_weapons[i] != null:
			_slots[i] = _make_slot(starting_weapons[i], -1, -1)
	var knife := _chosen_knife()
	if knife != null:
		_slots[MELEE_SLOT] = _make_slot(knife, 0, 0)
	Settings.changed.connect(_on_settings_changed)
	var first := _cycle_from(-1, 1)
	if first < 0:
		set_process(false)
		set_physics_process(false)
		return
	_equip(first)


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not is_physics_processing():
		return
	for i in 3:
		if event.is_action_pressed("weapon_%d" % (i + 1)):
			_request_switch(i)
	if event.is_action_pressed("weapon_last"):
		_request_switch(_quick_switch_target())
	if event.is_action_pressed("weapon_next"):
		_request_switch(_cycle_from(get_selected_slot(), 1))
	elif event.is_action_pressed("weapon_prev"):
		_request_switch(_cycle_from(get_selected_slot(), -1))
	if event.is_action_pressed("reload"):
		_want_reload = true
	if event.is_action_pressed("inspect"):
		_want_inspect = true
	if event.is_action_pressed("melee"):
		_want_melee = true
	if event.is_action_pressed("throw_weapon"):
		_want_throw = true
	if event.is_action_pressed("interact"):
		_want_pickup = true
	if event.is_action_pressed("fire"):
		_semi_buffer = 0.15
	if event.is_action_pressed("aim"):
		_want_heavy = true
		if Settings.toggle_aim:
			_aim_toggled = not _aim_toggled
	if event.is_action_pressed("sprint"):
		_aim_toggled = false # Like Apex: sprinting drops toggle ADS.


func _physics_process(delta: float) -> void:
	var s := slot()
	var d := s.data
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_since_shot += delta
	_shot_timer -= delta
	_semi_buffer = maxf(_semi_buffer - delta, 0.0)
	_bloom = maxf(_bloom - d.bloom_decay * delta, 0.0)

	if player.is_sprinting:
		_sprint_out = d.sprint_to_fire_time
	else:
		_sprint_out = maxf(_sprint_out - delta, 0.0)

	# Aim
	var aim_input := _aim_toggled if Settings.toggle_aim else (captured and Input.is_action_pressed("aim"))
	var fire_held := captured and Input.is_action_pressed("fire")
	var can_aim := not d.is_melee and (action == Action.NONE or action == Action.RELOAD or action == Action.INSPECT)
	var cycling := d.unscope_on_shot and _shot_timer > 0.0 # Working the bolt: scope comes back after.
	var want_ads := aim_input and can_aim and not player.is_sprinting and not cycling
	ads = move_toward(ads, 1.0 if want_ads else 0.0, delta / maxf(d.ads_time, 0.01))
	if want_ads:
		_settle_flourish(s)
		if action == Action.INSPECT:
			action = Action.NONE
	player.sprint_blocked = (aim_input and can_aim) or (fire_held and not d.is_melee \
			and action != Action.HOLSTER and action != Action.DRAW and action != Action.THROW)

	# One-shot actions
	_draw_left = maxf(_draw_left - delta, 0.0)
	var busy := action == Action.HOLSTER or action == Action.DRAW or action == Action.THROW or action == Action.MELEE \
			or _draw_left > 0.0
	if action != Action.THROW and has_free_gun_slot():
		_auto_pickup()
	if _want_pickup and action != Action.THROW and action != Action.HOLSTER:
		_try_pickup()
	elif _want_throw and not d.is_melee and not busy:
		_start_throw()
	elif _want_melee and not busy:
		_start_melee(Melee.LIGHT if d.is_melee else Melee.QUICK)
	elif d.is_melee and not busy and (fire_held or _semi_buffer > 0.0):
		_semi_buffer = 0.0
		_start_melee(Melee.LIGHT)
	elif d.is_melee and not busy and _want_heavy:
		_start_melee(Melee.HEAVY)
	elif _want_reload and action == Action.INSPECT:
		_cancel_inspect() # R stops an inspect (and reloads, if there's anything to reload).
		if not d.is_melee:
			_try_reload()
	elif _want_reload and not d.is_melee and action == Action.NONE:
		_try_reload()
	elif _want_inspect and ads < 0.05 and (action == Action.NONE or (d.is_melee and action == Action.DRAW)):
		# Knives can inspect mid-draw: the draw blends into the inspect, which makes for some
		# new flourishes. The draw time still counts. An inspect already playing carries on.
		var blend := 0.2 if action == Action.DRAW else BLEND
		_start(Action.INSPECT, _play(slot(), "inspect", -1.0, blend))
	_want_melee = false
	_want_heavy = false
	_want_reload = false
	_want_inspect = false
	_want_throw = false
	_want_pickup = false

	_tick_action(delta)
	s = slot()
	d = s.data
	if not d.is_melee:
		_tick_fire(s, fire_held)
		# Recoil recovery once the spray is over
		if _since_shot > 60.0 / d.rpm + 0.12:
			_spray_index = 0
			if d.recoil_recovery > 0.0:
				player.recover_recoil(deg_to_rad(d.recoil_recovery) * delta)


func _process(delta: float) -> void:
	var s := slot()
	var d := s.data
	var a := smoothstep(0.0, 1.0, ads)
	player.ads_amount = a
	player.zoom = lerpf(1.0, d.ads_zoom, a)
	player.move_speed_multiplier = lerpf(1.0, d.ads_move_speed, a)
	player.weapon_speed_multiplier = d.move_speed
	viewmodel.ads_blend = a
	viewmodel.visible = not is_scoped() # The HUD draws the scope.

	# Procedural motion for holster and throw; everything else is keyframed.
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO # degrees
	var p := clampf(_action_t / maxf(_action_len, 0.001), 0.0, 1.0)
	match action:
		Action.HOLSTER:
			var l := smoothstep(0.0, 1.0, p)
			pos = Vector3(0.02, -0.25, 0.05) * l
			rot = Vector3(-40.0, 10.0, 20.0) * l
		Action.THROW:
			var wind := smoothstep(0.0, 0.4, p)
			var fling := smoothstep(0.38, 0.6, p)
			pos = Vector3(0.03, 0.05, 0.1) * wind * (1.0 - fling) + Vector3(-0.08, 0.1, -0.5) * fling
			rot = Vector3(30.0, -15.0, -20.0) * wind * (1.0 - fling) + Vector3(-80.0, 15.0, 30.0) * fling
	viewmodel.action_position = pos
	viewmodel.action_rotation_deg = rot

	# Slide / bolt blowback (only while no animation owns that node)
	_bolt_kick = lerpf(_bolt_kick, 0.0, 1.0 - exp(-25.0 * delta))
	if s.bolt != null and (s.anim == null or not s.anim.is_playing()):
		s.bolt.position = s.bolt_rest + Vector3(0.0, 0.0, _bolt_kick)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and s.flash != null:
			s.flash.visible = false


# --- Slots ---------------------------------------------------------------------

func _chosen_knife() -> WeaponData:
	var k := Settings.get_knife_data()
	return k if k != null else melee_weapon


## Swaps in a newly picked knife. If it's in your hands, it comes out with its first draw.
func _on_settings_changed() -> void:
	var knife := _chosen_knife()
	var old: Slot = _slots[MELEE_SLOT]
	if knife == null or (old != null and old.data == knife):
		return
	if action == Action.MELEE:
		action = Action.NONE
		if current != MELEE_SLOT:
			_play(slot(), "idle")
	_free_slot(MELEE_SLOT)
	_slots[MELEE_SLOT] = _make_slot(knife, 0, 0)
	if current == MELEE_SLOT:
		_equip(MELEE_SLOT)


func _make_slot(d: WeaponData, mag: int, reserve: int) -> Slot:
	var s := Slot.new()
	s.data = d
	s.mag = d.mag_size if mag < 0 else mag
	s.reserve = d.reserve_ammo if reserve < 0 else reserve
	s.model = d.model_scene.instantiate()
	s.model.visible = false
	viewmodel.add_child(s.model)
	s.anim = s.model.get_node_or_null("AnimationPlayer")
	s.muzzle = s.model.get_node_or_null("Pivot/Gun/Muzzle")
	if s.muzzle == null:
		s.muzzle = s.model
	if not d.is_melee:
		s.flash = WeaponFx.make_muzzle_flash(s.muzzle, d.muzzle_flash_size)
	s.bolt = s.model.get_node_or_null(d.bolt_node)
	if s.bolt != null:
		s.bolt_rest = s.bolt.position
	return s


func _free_slot(i: int) -> void:
	var s: Slot = _slots[i]
	if s != null:
		s.model.queue_free()
	_slots[i] = null


## Next occupied slot after `from` in direction `dir` (-1 if none at all).
func _cycle_from(from: int, dir: int) -> int:
	for k in range(1, 4):
		var j := wrapi(from + dir * k, 0, 3)
		if _slots[j] != null:
			return j
	return -1


# --- Animation helpers -----------------------------------------------------------

## Plays an animation, optionally stretched to `fit` seconds. Returns its duration.
func _play(s: Slot, anim_name: String, fit: float = -1.0, blend: float = BLEND) -> float:
	if s == null or s.anim == null or not s.anim.has_animation(anim_name):
		return maxf(fit, 0.0)
	var length := s.anim.get_animation(anim_name).length
	var speed := length / fit if fit > 0.0 else 1.0
	if s.anim.current_animation == anim_name:
		s.anim.stop()
	s.anim.play(anim_name, blend, speed)
	return length / speed


## Cuts a draw/inspect flourish short (smoothly) when you start doing something.
func _settle_flourish(s: Slot) -> void:
	if s.anim != null and s.anim.current_animation in ["draw", "draw_quick", "inspect"]:
		s.anim.play("idle", BLEND)


# --- Actions -------------------------------------------------------------------

func _start(a: Action, length: float) -> void:
	action = a
	_action_t = 0.0
	_action_len = length


func _tick_action(delta: float) -> void:
	if action == Action.NONE:
		return
	_action_t += delta
	var d := slot().data
	match action:
		Action.RELOAD:
			if d.shell_reload:
				_tick_shell_reload()
				return
			if not _reload_committed and _action_t >= _commit_at:
				_commit_reload()
		Action.MELEE:
			if not _melee_done and _action_t >= _melee_hit_time:
				_melee_done = true
				_melee_hit()
			if _action_t >= _action_len and _melee_kind == Melee.QUICK:
				var knife: Slot = _slots[MELEE_SLOT]
				knife.model.visible = false
				knife.model.position = Vector3.ZERO
		Action.HOLSTER:
			if _action_t >= _action_len:
				_equip(_pending)
			return
		Action.INSPECT:
			# Holding inspect loops it (it starts and ends at rest, so it loops cleanly).
			if _action_t >= _action_len and Input.is_action_pressed("inspect"):
				_start(Action.INSPECT, _play(slot(), "inspect", -1.0, 0.05))
				return
		Action.THROW:
			if not _thrown and _action_t >= throw_release:
				_thrown = true
				_release_throw()
			if _action_t >= _action_len:
				_free_slot(current)
				_equip(_cycle_from(current, 1))
			return
	if _action_t >= _action_len:
		action = Action.NONE


func _equip(i: int) -> void:
	for s: Slot in _slots:
		if s != null:
			if s.model.has_method("stop_sounds"):
				s.model.stop_sounds() # Put away: its draw/reload sounds stop with it.
			s.model.visible = false
			s.model.position = Vector3.ZERO
			if s.flash != null:
				s.flash.visible = false
	if i != current:
		_last_slot = current
	current = i
	if i < GUN_SLOTS:
		_last_gun = i
	var s := slot()
	s.model.visible = true
	viewmodel.set_rest(s.data.hip_position, s.data.ads_position)
	_spray_index = 0
	_bloom = 0.0
	_shot_timer = 0.0
	_prime = 0.0
	_bolt_kick = 0.0
	# Weapons take turns through their "draw*" animations (flourish, quick, flourish...),
	# except guns while always_flourish_guns is on: always the full flourish.
	var draws: Array = []
	if not s.data.is_melee and always_flourish_guns:
		draws = ["draw"]
	elif s.anim != null:
		draws = Array(s.anim.get_animation_list()).filter(func(n: StringName) -> bool: return String(n).begins_with("draw"))
		draws.sort()
	var anim_name: String = draws[s.draw_index % draws.size()] if not draws.is_empty() else "draw"
	s.draw_index += 1
	# You can't shoot (or slash) until the whole draw animation has played.
	var length := _play(s, anim_name, -1.0, 0.0)
	_start(Action.DRAW, maxf(length, s.data.quick_draw_time if anim_name == "draw_quick" else s.data.draw_time))
	_draw_left = _action_len


func _request_switch(i: int) -> void:
	if i < 0 or i >= 3 or _slots[i] == null:
		return
	if action == Action.THROW or action == Action.MELEE:
		return
	if action == Action.HOLSTER:
		if i == current:
			_raise_again()
		else:
			_pending = i
		return
	if i == current:
		return
	_pending = i
	_aim_toggled = false
	if not stow_on_switch:
		Sfx.play("swap", -10.0)
		_equip(i)
		return
	_start(Action.HOLSTER, slot().data.holster_time)
	_play(slot(), "idle")
	Sfx.play("swap", -10.0)


## Q: the weapon you had out before this one, like CS. Q Q swaps out and straight back,
## which skips the rest of a reload once the ammo is in (with stow_on_switch on, the
## second Q catches the weapon mid-lower and brings it straight back up).
func _quick_switch_target() -> int:
	if action == Action.HOLSTER and _pending != current:
		return current
	var from := get_selected_slot()
	if _last_slot >= 0 and _last_slot != from and _slots[_last_slot] != null:
		return _last_slot
	return _cycle_from(from, 1)


## Switching back to the weapon you're lowering: it comes straight back up from
## wherever it got to, without a full draw. Ends whatever it was doing (a reload
## keeps its ammo only if it got past reload_commit).
func _raise_again() -> void:
	var s := slot()
	var lowered := smoothstep(0.0, 1.0, get_action_progress())
	_pending = current
	# draw_quick starts at the holster pose and is back up 60% of the way in, then settles.
	var up := _play(s, "draw_quick", -1.0, 0.05) * 0.6
	if s.anim != null and s.anim.current_animation == "draw_quick":
		s.anim.seek(up * (1.0 - lowered), true)
	_start(Action.DRAW, maxf(up * lowered, 0.05))


func _try_reload() -> void:
	var s := slot()
	if s.mag >= s.data.mag_size:
		return
	if not infinite_reserve and s.reserve <= 0:
		return
	var empty := s.mag == 0
	_reload_committed = false
	_stop_after_shell = false
	if s.data.shell_reload:
		_shell_phase = Shells.START
		_start(Action.RELOAD, _play(s, "reload_start", s.data.reload_start_time))
		return
	var t := s.data.reload_empty_time if empty else s.data.reload_time
	var anim_name := "reload_empty" if empty else "reload"
	_start(Action.RELOAD, _play(s, anim_name, t))
	_commit_at = _mag_in_time(s, anim_name, t, s.data.reload_commit)


## Shell-by-shell: reload_start, then reload_shell per round until full (or out of
## reserve), then reload_end. Each round goes in at its "mag_in" moment,
## and pulling the trigger stops it after the current shell (then reload_end plays out).
func _tick_shell_reload() -> void:
	var s := slot()
	var d := s.data
	if _shell_phase == Shells.LOAD and not _reload_committed and _action_t >= _commit_at:
		_reload_committed = true
		s.mag += 1
		if not infinite_reserve:
			s.reserve -= 1
	if _action_t < _action_len:
		return
	if _shell_phase == Shells.END:
		action = Action.NONE
	elif s.mag < d.mag_size and (infinite_reserve or s.reserve > 0) and not _stop_after_shell:
		_shell_phase = Shells.LOAD
		_reload_committed = false
		_start(Action.RELOAD, _play(s, "reload_shell", d.shell_time, 0.0))
		_commit_at = _mag_in_time(s, "reload_shell", d.shell_time, d.reload_commit)
	else:
		_shell_phase = Shells.END
		_start(Action.RELOAD, _play(s, "reload_end", d.reload_end_time))


## When the magazine (or shell) goes in: the "mag_in" sound key in the reload animation,
## stretched to `fit` seconds like the animation is. Ammo commits right then, so a quick
## swap straight after keeps it. Falls back to `fallback` of the way through.
func _mag_in_time(s: Slot, anim_name: String, fit: float, fallback: float) -> float:
	if s.anim != null and s.anim.has_animation(anim_name):
		var a := s.anim.get_animation(anim_name)
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_METHOD:
				continue
			for k in a.track_get_key_count(t):
				var args: Array = a.method_track_get_params(t, k)
				if not args.is_empty() and args[0] == "mag_in":
					return a.track_get_key_time(t, k) * fit / a.length
	return fit * fallback


func _cancel_inspect() -> void:
	action = Action.NONE
	_play(slot(), "idle")


func _commit_reload() -> void:
	var s := slot()
	_reload_committed = true
	var need := s.data.mag_size - s.mag
	var take := need if infinite_reserve else mini(need, s.reserve)
	s.mag += take
	if not infinite_reserve:
		s.reserve -= take


func _start_melee(kind: Melee) -> void:
	var knife: Slot = _slots[MELEE_SLOT]
	if knife == null:
		return
	var md := knife.data
	var length := 0.0
	match kind:
		Melee.LIGHT:
			_slash_left = not _slash_left
			length = _play(knife, "slash_left" if _slash_left else "slash_right", -1.0, 0.05)
			_melee_hit_time = md.light_hit_time
			_melee_damage = md.light_damage
		Melee.HEAVY:
			length = _play(knife, "heavy", -1.0, 0.05)
			_melee_hit_time = md.heavy_hit_time
			_melee_damage = md.heavy_damage
		Melee.QUICK:
			# The gun ducks out of the way and the knife slashes in from the side.
			knife.model.visible = true
			knife.model.position = md.hip_position - slot().data.hip_position
			length = _play(knife, "quick_slash", -1.0, 0.0)
			_play(slot(), "melee_lower", length, 0.06)
			_melee_hit_time = md.quick_hit_time
			_melee_damage = md.light_damage
	_start(Action.MELEE, length)
	_melee_kind = kind
	_melee_done = false
	_aim_toggled = false
	Sfx.play("knife_swing", -4.0 if kind == Melee.HEAVY else -7.0)


func _melee_hit() -> void:
	var knife: Slot = _slots[MELEE_SLOT]
	var reach := knife.data.melee_range
	var eye := player.head.global_transform
	for offset: Vector2 in [Vector2.ZERO, Vector2(10, 0), Vector2(-10, 0), Vector2(0, -10)]:
		var dir := eye.basis * Basis.from_euler(Vector3(deg_to_rad(offset.y), deg_to_rad(-offset.x), 0.0)) * Vector3.FORWARD
		var hit := _ray(eye.origin, eye.origin + dir * reach)
		if hit.is_empty():
			continue
		var hit_target := deal_damage(hit.collider, _melee_damage, 1.0, hit.position)
		if not hit_target:
			WeaponFx.impact(get_tree().current_scene, hit.position, hit.normal, false)
		Sfx.play("knife_hit", 0.0 if hit_target else -8.0)
		player.add_view_punch(-2.5 if _melee_kind == Melee.HEAVY else -1.2)
		return


func _start_throw() -> void:
	_settle_flourish(slot())
	_start(Action.THROW, throw_time)
	_thrown = false
	_aim_toggled = false


func _release_throw() -> void:
	var s := slot()
	var eye := player.head.global_transform
	var fwd := -eye.basis.z
	var at := Transform3D(eye.basis, eye.origin + fwd * 0.5 + eye.basis.x * 0.12 - eye.basis.y * 0.08)
	var vel := fwd * throw_speed + Vector3.UP * 2.0 + player.velocity
	var spin := eye.basis.x * -16.0 + eye.basis.y * randf_range(-3.0, 3.0) # End over end.
	var p := WeaponPickup.spawn(get_tree().current_scene, s.data, s.mag, s.reserve, at, vel, spin, self)
	p.add_collision_exception_with(player)
	s.model.visible = false
	Sfx.play("throw", -2.0)


## Picks up the gun you're looking at (swapping if both slots are full).
func _try_pickup() -> void:
	var p := get_pickup_candidate()
	if p == null:
		return
	_add_gun(p.weapon, p.mag, p.reserve)
	p.queue_free()
	Sfx.play("pickup", -2.0)


## Walking over a dropped gun takes it when you have a free slot (CS style). It goes
## in the slot without switching to it. Guns on the rack still need Interact.
func _auto_pickup() -> void:
	var feet := player.global_position
	for n in get_tree().get_nodes_in_group("weapon_pickups"):
		var p := n as WeaponPickup
		if p == null or p.is_queued_for_deletion() or p.freeze or not p.can_auto_pickup() or owns(p.weapon):
			continue
		var to := p.global_position - feet
		if Vector2(to.x, to.z).length() > auto_pickup_radius or to.y < -0.5 or to.y > 1.6:
			continue
		_add_gun(p.weapon, p.mag, p.reserve, false)
		p.queue_free()
		Sfx.play("pickup", -2.0)
		return


## Puts a gun in a free slot, or swaps out the one in hand (dropping it). Draws it
## unless `equip` is off.
func _add_gun(d: WeaponData, mag: int, reserve: int, equip: bool = true) -> void:
	var target := -1
	for i in GUN_SLOTS:
		if _slots[i] == null:
			target = i
			break
	if target < 0:
		target = current if current < GUN_SLOTS else _last_gun
		_drop(target)
	_slots[target] = _make_slot(d, mag, reserve)
	if equip:
		_equip(target)


func _drop(i: int) -> void:
	var s: Slot = _slots[i]
	var eye := player.head.global_transform
	var fwd := -eye.basis.z
	var at := Transform3D(eye.basis, eye.origin + fwd * 0.4 - eye.basis.y * 0.3)
	var p := WeaponPickup.spawn(get_tree().current_scene, s.data, s.mag, s.reserve, at,
			fwd * 2.5 + Vector3.UP * 1.5 + player.velocity, Vector3(randf(), randf(), randf()) * 2.0)
	p.add_collision_exception_with(player)
	_free_slot(i)


# --- Firing --------------------------------------------------------------------

func _tick_fire(s: Slot, fire_held: bool) -> void:
	var d := s.data
	var pressed := _semi_buffer > 0.0
	var trigger := fire_held if d.fire_mode == WeaponData.FireMode.AUTO else pressed
	if trigger and action == Action.INSPECT:
		action = Action.NONE
	# No shooting until a draw or reload has completely finished. A shell reload stops after
	# the shell going in when you pull the trigger, then you can fire once it's closed up.
	if trigger and action == Action.RELOAD and d.shell_reload and s.mag > 0:
		_stop_after_shell = true
	var ready := action == Action.NONE and _sprint_out <= 0.0 and not player.is_sprinting
	if not (trigger and ready):
		_shot_timer = maxf(_shot_timer, 0.0)
		if _prime > 0.0: # Let go before the hammer was back: ease it down.
			_prime = 0.0
			_play(s, "idle")
		return
	if s.mag <= 0:
		if pressed:
			_semi_buffer = 0.0
			Sfx.play("dry_fire", -6.0)
			_try_reload()
		return
	_settle_flourish(s)
	if d.prime_time > 0.0:
		# Revolver: the hammer cocks while you hold, and the shot goes when it's back.
		if _shot_timer > 0.0:
			return
		_shot_timer = 0.0
		if _prime <= 0.0:
			_play(s, "prime", d.prime_time, 0.05)
			Sfx.play("hammer", -6.0)
		_prime += get_physics_process_delta_time()
		if _prime < d.prime_time:
			return
		_prime = 0.0
	while _shot_timer <= 0.0 and s.mag > 0:
		_shoot(s)
		_shot_timer += 60.0 / d.rpm
		if d.fire_mode == WeaponData.FireMode.SEMI or d.prime_time > 0.0:
			_semi_buffer = 0.0
			break
	if s.mag == 0:
		_try_reload() # Auto-reload on empty, like Apex.


func _shoot(s: Slot) -> void:
	var d := s.data
	s.mag -= 1
	_since_shot = 0.0
	var eye := player.head.global_transform
	var aim := _spread_direction(eye.basis, _aim_spread_deg())
	var aim_basis := Basis.looking_at(aim, eye.basis.y)
	var cone := lerpf(d.pellet_spread, d.pellet_spread_ads, ads)
	var world := get_tree().current_scene
	var hits := {} # Target -> damage summed over pellets, so a shotgun blast lands as one hit.
	for i in d.pellets:
		var dir := aim if i == 0 else _pellet_direction(aim_basis, cone, i, d.pellets)
		var from := eye.origin
		var end := from + dir * max_range
		var hit := _ray(from, end)
		if not hit.is_empty():
			end = hit.position
			var target := _damageable(hit.collider)
			WeaponFx.impact(world, end, hit.normal, target == null)
			if target != null:
				var headshot: bool = (hit.collider as Node).get_meta("hitzone", "body") == "head"
				var h: Dictionary = hits.get_or_add(target, {amount = 0.0, headshot = false, pos = end})
				h.amount += d.damage * _falloff(d, from.distance_to(end)) * (d.head_multiplier if headshot else 1.0)
				h.headshot = h.headshot or headshot
		WeaponFx.tracer(world, s.muzzle.global_position, end)
	for target: Node in hits:
		_apply_damage(target, hits[target].amount, hits[target].headshot, hits[target].pos)

	s.flash.visible = true
	s.flash.rotation.z = randf() * TAU
	s.flash.scale = Vector3.ONE * randf_range(0.8, 1.2) * lerpf(1.0, d.ads_flash_scale, ads)
	_flash_timer = 0.035
	_bolt_kick = d.bolt_kick

	# Recoil is applied after the shot, so the first bullet always goes where you aimed.
	var kick := _pattern(d, _spray_index) * lerpf(1.0, d.recoil_scale_ads, ads)
	kick += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * d.recoil_jitter
	player.add_recoil(kick.y, kick.x)
	player.add_view_punch(d.view_punch * lerpf(1.0, 0.5, ads))
	viewmodel.kick(d.kick_back * lerpf(1.0, 0.5, ads), d.kick_rotation * lerpf(1.0, 0.35, ads))
	_spray_index += 1
	_bloom = minf(_bloom + d.bloom_per_shot, d.bloom_max)
	Sfx.play("shot_" + d.sound_prefix, -5.0)
	if d.cycle_after_shot and s.mag > 0:
		_play(s, "cycle", -1.0, 0.05)
	fired.emit()


## Applies damage if the collider belongs to something with take_damage().
## head_mult applies when the collider is tagged hitzone = "head". Returns true on a hit.
func deal_damage(collider: Object, amount: float, head_mult: float, pos: Vector3) -> bool:
	var n := _damageable(collider)
	if n == null:
		return false
	var headshot: bool = (collider as Node).get_meta("hitzone", "body") == "head"
	_apply_damage(n, amount * (head_mult if headshot else 1.0), headshot, pos)
	return true


## The node with take_damage() that owns this collider, or null.
func _damageable(collider: Object) -> Node:
	var n := collider as Node
	while n != null and not n.has_method("take_damage"):
		n = n.get_parent()
	return n


func _apply_damage(n: Node, amount: float, headshot: bool, pos: Vector3) -> void:
	var killed: bool = n.take_damage(amount, headshot, pos)
	hit_confirmed.emit(headshot, killed)
	if killed:
		Sfx.play("kill", -2.0, 0.0)
	else:
		Sfx.play("hit_head" if headshot else "hit_body", -3.0 if headshot else -5.0, 0.0)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 # World and targets, not pickups.
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q)


func _spread_direction(basis: Basis, spread_deg: float) -> Vector3:
	if spread_deg <= 0.001:
		return -basis.z
	var r := deg_to_rad(spread_deg) * sqrt(randf())
	var a := randf() * TAU
	return (basis * Vector3(sin(r) * cos(a), sin(r) * sin(a), -cos(r))).normalized()


## Shotgun pattern: pellet 0 goes dead centre (see _shoot), the rest spread round a
## ring, with a little jitter so no two blasts are identical.
func _pellet_direction(basis: Basis, cone_deg: float, i: int, count: int) -> Vector3:
	var a := TAU * float(i - 1) / float(count - 1) + randf_range(-0.25, 0.25)
	var r := deg_to_rad(cone_deg) * randf_range(0.55, 1.0)
	return (basis * Vector3(sin(r) * cos(a), sin(r) * sin(a), -cos(r))).normalized()


func _pattern(d: WeaponData, i: int) -> Vector2:
	var p := d.recoil_pattern
	if p.is_empty():
		return Vector2.ZERO
	if i < p.size():
		return p[i]
	var loop := mini(8, p.size())
	return p[p.size() - loop + (i - p.size()) % loop]


func _falloff(d: WeaponData, dist: float) -> float:
	if dist <= d.falloff_start:
		return 1.0
	var t := clampf((dist - d.falloff_start) / maxf(d.falloff_end - d.falloff_start, 0.01), 0.0, 1.0)
	return lerpf(1.0, d.falloff_min, t)


# --- Public API (HUD / crosshair / pickups) --------------------------------------

func slot() -> Slot:
	return _slots[current]


func data() -> WeaponData:
	return slot().data


## Where the crosshair opens to: the aim spread, plus the pellet cone for shotguns.
func get_spread_deg() -> float:
	var d := data()
	var spread := _aim_spread_deg()
	if d.pellets > 1:
		spread += lerpf(d.pellet_spread, d.pellet_spread_ads, ads)
	return spread


## Cone (degrees) the shot's aim point can land in.
func _aim_spread_deg() -> float:
	var d := data()
	if d.is_melee:
		return 0.0
	var hip := 1.0 - ads
	var spread := lerpf(d.hip_spread, d.ads_spread, ads)
	spread += clampf(player.get_horizontal_speed() / player.sprint_speed, 0.0, 1.0) * lerpf(d.move_spread, d.ads_move_spread, ads)
	if not player.is_on_floor():
		spread += d.air_spread * hip
	return spread + _bloom * hip


## Fully aimed with a scoped weapon: the HUD shows the scope instead of the viewmodel.
func is_scoped() -> bool:
	return data().scope_overlay and ads >= 0.75


func get_mag() -> int:
	return slot().mag


func get_reserve() -> int:
	return -1 if infinite_reserve else slot().reserve


func is_reloading() -> bool:
	return action == Action.RELOAD


func get_action_progress() -> float:
	return clampf(_action_t / maxf(_action_len, 0.001), 0.0, 1.0)


## Reload bar fill. Shell reloads show how full the tube is.
func get_reload_progress() -> float:
	var s := slot()
	if s.data.shell_reload:
		return float(s.mag) / maxf(s.data.mag_size, 1.0)
	return get_action_progress()


## Names per slot ("" for an empty slot).
func get_slot_names() -> PackedStringArray:
	var names := PackedStringArray()
	for s: Slot in _slots:
		names.append(s.data.display_name if s != null else "")
	return names


## The weapon in hand, or the one being switched to.
func get_selected_slot() -> int:
	return _pending if action == Action.HOLSTER else current


func can_buy() -> bool:
	return buy_zones > 0


## True if this weapon is in a slot (for knives: the knife you carry).
func owns(d: WeaponData) -> bool:
	for s: Slot in _slots:
		if s != null and s.data == d:
			return true
	return false


## Buy menu purchase (free). Guns: you already have it = refill and switch to it;
## otherwise it fills a free slot or replaces the gun in hand. Knives replace your
## knife (and become your saved knife) and come out with their draw.
func buy(d: WeaponData) -> void:
	if action == Action.THROW or action == Action.MELEE:
		return
	Sfx.play("pickup", -2.0)
	if d.is_melee:
		var id := Settings.knife_id(d)
		if id != "" and id != Settings.knife:
			Settings.set_value("knife", id) # _on_settings_changed swaps the model.
		if current == MELEE_SLOT:
			if action != Action.DRAW:
				_equip(MELEE_SLOT)
		else:
			_request_switch(MELEE_SLOT)
		return
	for i in GUN_SLOTS:
		var s: Slot = _slots[i]
		if s != null and s.data == d:
			s.mag = d.mag_size
			s.reserve = d.reserve_ammo
			_request_switch(i)
			return
	_add_gun(d, -1, -1)


func has_free_gun_slot() -> bool:
	return _slots[0] == null or _slots[1] == null


## The pickup you'd grab by pressing Interact: close by and roughly in front of you.
func get_pickup_candidate() -> WeaponPickup:
	var eye := player.head.global_transform
	var fwd := -eye.basis.z
	var best: WeaponPickup = null
	var best_score := -INF
	for n in get_tree().get_nodes_in_group("weapon_pickups"):
		var p := n as WeaponPickup
		if p == null or p.is_queued_for_deletion() or p.thrower != null: # Skip guns still in flight.
			continue
		var to := p.global_position - eye.origin
		var dist := to.length()
		if dist > pickup_range:
			continue
		var facing := fwd.dot(to / maxf(dist, 0.001))
		if facing < 0.85 and dist > 1.2:
			continue
		var score := facing - dist * 0.3
		if score > best_score:
			best_score = score
			best = p
	return best
