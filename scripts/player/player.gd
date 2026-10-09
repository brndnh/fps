class_name Player
extends CharacterBody3D
## First-person controller, tuned toward Apex Legends.
## Ground/air physics are Source-engine style: acceleration + friction on the
## ground, a capped air wish-speed so you can air-strafe.
## Sliding is Apex/Titanfall style: crouch while sprinting to slide, get a one-time
## boost (on a cooldown), keep momentum, and jump out of it to slide-hop.
## Firing or aiming stops a sprint (the WeaponManager sets sprint_blocked).
## Mantling, Apex style: jump at a ledge you can reach (mantle_min_height to mantle_reach
## above your feet) while moving towards it, and you pull yourself up onto it.
## Walls, Apex style: jump at one holding forward and you scramble up it for a moment
## (wall_climb_time), so a ledge too high to mantle from the ground comes into reach. Jump
## while you're against a wall in the air (climbing or not) and you kick off it.
## Ziplines (Zipline): Interact near one (standing or mid-jump) and you hang from it and ride it
## towards the end you're looking at. Jump to leap off with your speed; crouch or Interact
## to drop; at the end you're flung off. You can look around and shoot on the way.
## Every tuning value is exported, so you can tweak it live in the Inspector.
##
## Networking: Game spawns one of these per peer. Each peer simulates its own player
## (client-authoritative movement: it feels the same as offline, and cheating doesn't
## matter in co-op) and publishes the net_* values. Everyone else's copy is "remote": no
## camera, HUD or weapons, just a coloured body that follows the synced values, smoothed.

signal state_changed(new_state: MoveState)

enum MoveState { GROUND, AIR, SLIDE, MANTLE, ZIPLINE }

const SYNC_RATE := 30.0 ## Movement updates per second, per player.
const REMOTE_SMOOTHING := 18.0 ## How fast remote copies catch up with the latest update.
const MAX_EXTRAPOLATION := 0.1 ## Seconds a remote copy keeps moving on its last velocity when updates are late.
const SNAP_DISTANCE := 4.0 ## Further off than this (respawns, map changes), remote copies jump instead of gliding.
const LOCAL_ONLY := ["DebugHUD", "WeaponHUD", "StatusHUD", "BuyMenu", "Inventory", "Weapons", "Interact", "Heal", "Head/Camera3D/Viewmodel"] ## Removed from remote copies.
const SPECTATE_DISTANCE := 3.0 ## Metres behind the teammate you're watching once you're out.
const THIRD_PERSON_DISTANCE := 2.6 ## Self-reviving: the camera pulls back this far behind you...
const THIRD_PERSON_HEIGHT := 1.5 ## ...and this far up.
const THIRD_PERSON_BLEND := 0.35 ## Seconds to swing out to third person and back.
const PROP_PUSH := 80.0 ## How hard you shove props you walk into, per m/s you're moving into them. One player shifts up to about 60 kg; heavier takes teamwork.
const MANTLE_MASK := 1 | 32 ## You can mantle onto the world and props (crates).
const AUTO_RUN_TAP := 0.3 ## Two sprint presses this close together start auto-run.
const ZIP_END_CARRY := 0.35 ## Share of the ride speed you come off the end of a zipline with (enough to land on its platform, not fly past).
const AUTO_RUN_STOPS := ["move_forward", "move_back", "crouch", "fire", "aim", "reload", "interact", "heal", "melee", "throw_weapon"]
const COLORS := [
	Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 1.0), Color(0.35, 0.9, 0.4), Color(1.0, 0.8, 0.2),
	Color(0.75, 0.4, 1.0), Color(1.0, 0.55, 0.15), Color(0.2, 0.9, 0.9), Color(1.0, 0.45, 0.75),
	Color(0.6, 0.85, 0.25), Color(0.9, 0.9, 0.9),
] ## One per spawn slot, so everyone's body is easy to tell apart.

## Sensitivity, invert Y, FOV and hold/toggle modes come from the Settings autoload
## (Esc > Settings in game). Defaults live in scripts/settings.gd.
@export_group("Look")
@export var max_pitch_deg: float = 89.0

@export_group("Ground")
@export var run_speed: float = 4.4
@export var sprint_speed: float = 7.4
@export var crouch_speed: float = 2.4
@export var ground_accel: float = 12.0
@export var friction: float = 6.0
@export var stop_speed: float = 2.0 ## Below this speed friction acts as if you were going this fast (snappier stops).

@export_group("Air")
@export var gravity: float = 19.0
@export var jump_height: float = 1.1
@export var step_height: float = 0.45 ## Walks straight up ledges this high (curbs, door sills, stairs), like Source's 18 units.
@export var air_accel: float = 14.0
@export var air_speed_cap: float = 1.3 ## Low cap = Source-style air strafing. Raise for more air control.
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.12 ## Jump pressed this long before landing still fires on the landing tick (no friction = bhop).
@export var max_speed: float = 30.0

@export_group("Slide")
@export var slide_enter_speed: float = 6.0
@export var slide_exit_speed: float = 3.5
@export var slide_boost: float = 2.4
@export var slide_boost_cooldown: float = 2.0
@export var slide_decel: float = 3.5 ## m/s lost per second on flat ground.
@export var slide_slope_accel: float = 1.0 ## Multiplier for gravity pulling you down slopes.
@export var slide_steer_rate: float = 1.5

@export_group("Crouch")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
@export var stand_eye_height: float = 1.65
@export var crouch_eye_height: float = 0.95
@export var crouch_transition_speed: float = 14.0

@export_group("Mantle")
@export var mantle_min_height: float = 0.5 ## Lower ledges are steps (step_height) or a hop, not a mantle.
@export var mantle_reach: float = 1.7 ## The highest ledge you can grab, above your feet at the time.
@export var mantle_time: float = 0.32 ## Seconds to climb a waist-high ledge; the highest ones take about 1.4x.
@export var mantle_exit_speed: float = 3.0 ## You come off the top moving forward at least this fast.
@export var mantle_tilt_deg: float = 4.0 ## Camera roll while climbing.
@export var superglide_window: float = 0.1 ## Jump within this many seconds of a mantle's end (just before or just after) to superglide. Earlier spoils it.
@export var superglide_speed: float = 10.0 ## A superglide launches you forward at least this fast.
@export var superglide_hop: float = 0.45 ## Height of the low hop it comes with.

@export_group("Walls")
@export var wall_climb_speed: float = 4.5 ## m/s up a wall while you scramble up it...
@export var wall_climb_time: float = 0.42 ## ...for at most this long per jump (about 1.9 m), then you drop off unless a ledge came into mantle reach.
@export var wall_climb_min_fall: float = -4.0 ## Falling faster than this (m/s) you can't start a climb: you have to meet the wall on the way up or near the top of a jump.
@export var wall_jump_push: float = 4.5 ## m/s away from the wall a wall jump gives you...
@export var wall_jump_height: float = 0.75 ## ...and how high it hops.
@export var wall_jumps: int = 2 ## Wall jumps per time in the air (not off the same wall twice in a row).

@export_group("Zipline")
@export var zip_grab_range: float = 1.6 ## Interact grabs a zipline this close to your hands (on the ground or in the air).
@export var zip_ramp_time: float = 0.35 ## Seconds to get up to the zipline's speed from however fast you grabbed it.
@export var zip_jump_carry: float = 0.85 ## Share of the ride speed you keep jumping off.

@export_group("Downed")
@export var crawl_speed: float = 1.1
@export var downed_height: float = 0.8 ## Collider height while downed (the capsule's minimum: 2 x radius).
@export var downed_eye_height: float = 0.45

@export_group("Camera FX")
@export var speed_fov_kick: float = 8.0
@export var fov_kick_full_speed: float = 16.0
@export var slide_tilt_deg: float = 4.0 ## Camera roll at full lean: leans the way the slide is carrying you sideways.
@export var slide_lean_full: float = 0.5 ## Sideways share of the slide speed that counts as full lean (0.5 = sliding 30 degrees off where you look).
@export var land_dip_scale: float = 0.012
@export var view_punch_return: float = 18.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var health: PlayerHealth = $Health
@onready var interact: InteractInput = get_node_or_null("Interact") ## Only on your own player.
@onready var heal_input: HealInput = get_node_or_null("Heal") ## Only on your own player.

var state: MoveState = MoveState.GROUND
var is_crouched: bool = false
var is_sprinting: bool = false
var auto_running: bool = false ## Double-tapped sprint: running forward hands-free (see _update_auto_run()).

var _capsule: CapsuleShape3D
## Collider height as set, kept here because the shape stores it as a 32-bit float
## (1.8 reads back as 1.7999999, which compared as "crouched" and stuck you crouching).
var _height: float = 1.8
var _pitch: float = 0.0
var _eye_height: float = 1.65
var _land_dip: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _slide_boost_timer: float = 0.0
var _last_fall_speed: float = 0.0
var _wish_dir: Vector3 = Vector3.ZERO
var _look_delta: Vector2 = Vector2.ZERO
var _crouch_down: bool = false ## Logical crouch state (handles hold vs toggle).
var _crouch_started: bool = false ## True on the tick crouch turns on.
var _sprint_toggled: bool = false
var base_fov: float = 90.0
var _fov_kick: float = 0.0
var _recoil_debt := Vector2.ZERO ## Recoil (right, up) in radians that you haven't pulled against yet.
var _view_punch := Vector2.ZERO

## Set every frame by the WeaponManager.
var sprint_blocked: bool = false
var move_speed_multiplier: float = 1.0 ## ADS slowdown (doesn't affect sprint).
var weapon_speed_multiplier: float = 1.0 ## Weapon in hand, e.g. knife out = faster (affects sprint).
var zoom: float = 1.0
var ads_amount: float = 0.0
## -1..1 while sliding: which way the slide carries you relative to where you look
## (+ = right). 0 sliding straight ahead or when not sliding. Smoothed.
var slide_lean: float = 0.0

## Set by setup_network() before the player enters the tree.
var peer_id: int = 1
var slot: int = 0 ## Spawn slot: where you start, and your body colour.
var is_local: bool = true ## This machine controls this player.

## Published by the controlling peer, synced to everyone else.
var net_position := Vector3.ZERO
var net_velocity := Vector3.ZERO
var net_yaw: float = 0.0
var net_pitch: float = 0.0
var net_crouched: bool = false
var _net_age: float = 0.0 ## Seconds since the last update arrived (remote copies).
var _avatar: Humanoid
var _avatar_gun: Node3D
var _avatar_visor: Node3D
var _tag: Label3D
var _bars: Node3D
var _health_fill: MeshInstance3D
var _spectating: Player ## Once you're out: the teammate the camera follows.
var _third_person := 0.0 ## 0 = first person, 1 = behind you (self-reviving). Blends.
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_t := 0.0
var _mantle_len := 0.3
var _mantle_exit := 0.0 ## Forward speed when you come off the top.
var _mantle_cooldown := 0.0
var _glide_queued := false ## Jump pressed in the window at the end of this mantle.
var _glide_spoiled := false ## Jump pressed too early in this mantle.
var _glide_open := 0.0 ## Seconds left to superglide after a mantle ended.
var _climb_left := 0.0 ## Seconds of wall climb left this time in the air.
var _climbing := false ## Scrambling up a wall right now.
var _wall_jumps_left := 0
var _last_wall := Vector3.ZERO ## Normal of the wall last jumped off (this time in the air).
var _zip: Zipline ## The zipline you're riding.
var _zip_t := 0.0 ## 0..1 along it.
var _zip_dir := 1.0 ## +1 towards its end, -1 back towards its start.
var _zip_speed := 0.0
var _zip_cooldown := 0.0 ## Seconds before you can grab a zipline again (just let go of one).
var _knocked := 0.0 ## Seconds since a knockback to ignore the floor, so you leave the ground.
var _shake := 0.0 ## Camera shake strength.
var _since_sprint_tap := 9.0


func _ready() -> void:
	# Unique shape so resizing it for crouch never affects another instance.
	_capsule = (collision.shape as CapsuleShape3D).duplicate()
	collision.shape = _capsule
	_set_collider_height(stand_height)
	_eye_height = stand_eye_height
	health.life_changed.connect(_on_life_changed)
	if not is_local:
		set_process_unhandled_input(false)
		_build_avatar()
		return
	health.hurt.connect(func(amount: float) -> void: add_view_punch(-clampf(amount * 0.15, 0.5, 3.0)))
	health.knocked.connect(_on_knocked)
	_build_avatar() # Hidden: only seen in third person (self-reviving).
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	camera.fov = base_fov
	if not PauseMenu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Game.level_ready:
		respawn(Game.spawn_transform(slot))


## Called by Game before the player enters the tree. Remote copies lose the camera, HUD
## and weapons (their owner runs those) and get a body you can see instead.
func setup_network(id: int, spawn_slot: int, local: bool) -> void:
	name = str(id)
	peer_id = id
	slot = spawn_slot
	is_local = local
	if not local:
		(get_node("Head/Camera3D") as Camera3D).current = false
		for path: String in LOCAL_ONLY:
			var n := get_node(path)
			n.get_parent().remove_child(n)
			n.free()
	var h := get_node("Health") as PlayerHealth
	h.add_child(h.make_synchronizer())
	add_child(_make_synchronizer())
	set_multiplayer_authority(id)
	h.set_multiplayer_authority(1) # The host decides health, for everyone.


## Puts the player on a spawn point, standing up, still, and facing the way it faces.
## Also the fallback for a stuck stance: every spawn starts you standing.
func respawn(at: Transform3D) -> void:
	global_position = at.origin
	rotation = Vector3(0.0, at.basis.get_euler().y, 0.0)
	velocity = Vector3.ZERO
	_pitch = 0.0
	head.rotation.x = 0.0
	_crouch_down = false
	_sprint_toggled = false
	_set_collider_height(stand_height)
	is_crouched = false
	_eye_height = stand_eye_height
	_change_state(MoveState.GROUND)
	_publish()


func _apply_settings() -> void:
	base_fov = Settings.get_vertical_fov()
	if not Settings.toggle_crouch:
		_crouch_down = Input.is_action_pressed("crouch")
	if not Settings.toggle_sprint:
		_sprint_toggled = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = (event as InputEventMouseMotion).screen_relative
		# ADS: scale by zoom so aiming feels the same speed on screen, times your multiplier.
		var look := Settings.get_look_scale() * lerpf(1.0, Settings.ads_sensitivity / zoom, ads_amount)
		var y_sign := -1.0 if Settings.invert_y else 1.0
		var right := rel.x * look
		var up := -rel.y * look * y_sign
		_turn(right, up)
		_pay_recoil_debt(right, up)
		_look_delta += Vector2(rel.x, rel.y * y_sign)


func _physics_process(delta: float) -> void:
	if not is_local or not Game.level_ready or health.eliminated:
		return
	if global_position.y < Game.FALL_LIMIT: # Fell out of the map somehow: back to a spawn point.
		respawn(Game.spawn_transform(slot))
		return
	_tick_timers(delta)
	if state == MoveState.MANTLE:
		_watch_superglide()
		_tick_mantle(delta)
		_publish()
		return
	if state == MoveState.ZIPLINE:
		_tick_zipline(delta)
		_publish()
		return
	_read_input()
	if _try_zipline():
		_publish()
		return
	var grounded := is_on_floor() and _knocked <= 0.0
	var crouch_held := _crouch_down

	# State transitions
	match state:
		MoveState.GROUND, MoveState.SLIDE:
			if not grounded:
				_change_state(MoveState.AIR)
		MoveState.AIR:
			if grounded:
				_on_landed(crouch_held)
	if state == MoveState.AIR and _try_mantle():
		_publish()
		return
	if state == MoveState.AIR:
		_try_wall_jump()
	if state == MoveState.GROUND and _crouch_started \
			and get_horizontal_speed() >= slide_enter_speed:
		_start_slide()

	var jump_now := _jump_buffer_timer > 0.0 and (grounded or _coyote_timer > 0.0)

	match state:
		MoveState.GROUND:
			_move_ground(delta, jump_now)
		MoveState.SLIDE:
			_move_slide(delta, crouch_held)
		MoveState.AIR:
			if not _wall_climb(delta):
				_move_air(delta)

	if jump_now:
		if _glide_open > 0.0:
			_superglide() # Jumped just after coming over the top of a mantle.
		else:
			_jump()

	_clamp_speed()
	_update_crouch(crouch_held)
	if state != MoveState.AIR and not jump_now:
		_step_up(delta)
	var moving := velocity
	move_and_slide()
	if _push_props(moving, delta):
		# Keep leaning into it: bumping a prop doesn't stop you dead, so the shove carries
		# on and a crate light enough to move goes along at your pace.
		velocity.x = moving.x
		velocity.z = moving.z
	_publish()


## Walking into a crate or a body shoves it, harder the faster you're going. True if
## you're pushing one.
func _push_props(moving: Vector3, delta: float) -> bool:
	var pushing := false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var prop := c.get_collider() as PhysicsProp
		if prop != null:
			# How hard you're pushing: your speed into it, or (pressed up against it) how fast
			# you're trying to walk into it.
			var into := maxf(Vector3(moving.x, 0.0, moving.z).dot(-c.get_normal()), _wish_dir.dot(-c.get_normal()) * run_speed)
			if into <= 0.0:
				continue
			var along := Vector3(-c.get_normal().x, 0.0, -c.get_normal().z).normalized() # Level: not into the floor.
			prop.push(along * into * PROP_PUSH * delta, prop.global_position)
			pushing = true
	return pushing


## If this tick's move runs into a low ledge, lift the player onto it first: try the
## move raised by step_height, and if that's clear, set down on top of the ledge.
func _step_up(delta: float) -> void:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.0005:
		return
	var from := global_transform
	if not test_move(from, motion):
		return # Nothing in the way.
	var up := Vector3.UP * step_height
	if test_move(from, up):
		return # Ceiling.
	var raised := from.translated(up)
	# Reach a little further than this tick's move, so it catches the edge before the wall stops us.
	var ahead := motion.normalized() * maxf(motion.length(), 0.08)
	if test_move(raised, ahead):
		return # Still blocked up there: a wall, not a step.
	var hit := KinematicCollision3D.new()
	if not test_move(raised.translated(ahead), -up, hit):
		return # Nothing to stand on.
	if hit.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return
	var rise := step_height - hit.get_travel().length()
	if rise < 0.02:
		return
	global_position.y += rise + 0.01


# --- Ziplines -------------------------------------------------------------------

## Where you hold on: just over your head.
func _hands() -> Vector3:
	return global_position + Vector3.UP * (_height + 0.2)


## The zipline Interact would grab right now (close to your hands), or null.
func get_zipline_candidate() -> Zipline:
	if _zip_cooldown > 0.0 or not health.is_up() or state == MoveState.ZIPLINE or state == MoveState.MANTLE:
		return null
	return _nearest_zipline(zip_grab_range)


func _nearest_zipline(within: float) -> Zipline:
	var hands := _hands()
	var best: Zipline = null
	var best_d := within
	for n in get_tree().get_nodes_in_group("ziplines"):
		var z := n as Zipline
		var d := z.point_at(z.param_at(hands)).distance_to(hands)
		if d < best_d:
			best = z
			best_d = d
	return best


## Interact near a zipline (with nothing else to use or revive there): grab on. Always by
## hand: you never latch on just by touching or jumping into one.
func _try_zipline() -> bool:
	var z: Zipline = null
	var nothing_else := interact == null or (interact.get_interactable() == null and interact.get_candidate() == null)
	if Input.is_action_just_pressed("interact") and nothing_else and not PauseMenu.visible:
		z = get_zipline_candidate()
	if z == null:
		return false
	_zip = z
	_zip_t = z.param_at(_hands())
	# Ride towards the end you're looking at.
	var along := (z.point_b() - z.point_a()).normalized()
	_zip_dir = 1.0 if (-head.global_basis.z).dot(along) >= 0.0 else -1.0
	_zip_speed = minf(maxf(velocity.dot(along * _zip_dir), 4.0), z.speed)
	is_sprinting = false
	auto_running = false
	_change_state(MoveState.ZIPLINE)
	add_view_punch(-1.5)
	Sfx.play("slide_home", -6.0) # The trolley clacking onto the cable.
	return true


## Riding: slide along at the zipline's speed, hanging under the cable. Jump leaps off with
## the speed you had; crouch or Interact drops you; the end flings you off.
func _tick_zipline(delta: float) -> void:
	var z := _zip
	if not is_instance_valid(z) or not health.is_up():
		_leave_zipline(velocity * 0.3)
		return
	var along := (z.point_b() - z.point_a()).normalized() * _zip_dir
	_zip_speed = move_toward(_zip_speed, z.speed, z.speed / maxf(zip_ramp_time, 0.01) * delta)
	_zip_t += _zip_dir * _zip_speed * delta / maxf(z.length(), 0.01)
	velocity = along * _zip_speed
	if not PauseMenu.visible:
		if Input.is_action_just_pressed("jump"):
			_leave_zipline(along * _zip_speed * zip_jump_carry + Vector3.UP * sqrt(2.0 * gravity * jump_height))
			return
		if Input.is_action_just_pressed("crouch") or Input.is_action_just_pressed("interact"):
			_leave_zipline(along * _zip_speed * 0.5)
			return
	if _zip_t >= 1.0 or _zip_t <= 0.0: # The end: flung off forward with a little hop.
		_zip_t = clampf(_zip_t, 0.0, 1.0)
		var flat := Vector3(along.x, 0.0, along.z).normalized()
		_leave_zipline(flat * _zip_speed * ZIP_END_CARRY + Vector3.UP * 3.0)
		return
	var hang := z.point_at(_zip_t) - Vector3.UP * (_height + 0.2)
	var hit := move_and_collide(hang - global_position) # Something in the way: you're knocked off.
	if hit != null:
		_leave_zipline(Vector3.ZERO)


func _leave_zipline(new_velocity: Vector3) -> void:
	_zip = null
	_zip_cooldown = 0.4
	velocity = new_velocity
	_change_state(MoveState.AIR)
	Sfx.play("catch", -8.0)


func is_on_zipline() -> bool:
	return state == MoveState.ZIPLINE


# --- Walls ----------------------------------------------------------------------

## A wall within reach that way (level, chest high): the ray hit, or {} if there's none
## (or it's a slope or a floor, not a wall).
func _wall_hit(dir: Vector3) -> Dictionary:
	var from := global_position + Vector3.UP * (_height * 0.55)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (_capsule.radius + 0.35), MANTLE_MASK)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.3:
		return {}
	return hit


## In the air holding forward into a wall you're facing: scramble up it, for at most
## wall_climb_time per time in the air. A ledge that comes into reach on the way gets
## mantled (_try_mantle() runs first every tick). True while climbing (instead of the air move).
func _wall_climb(delta: float) -> bool:
	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var can := _climb_left > 0.0 and not health.downed and not is_crouched and _wish_dir.dot(fwd) > 0.7 \
			and (_climbing or velocity.y > wall_climb_min_fall)
	var wall := _wall_hit(fwd) if can else {}
	if wall.is_empty() or fwd.dot(-(wall.normal as Vector3)) < 0.6:
		_climbing = false
		return false
	if not _climbing:
		_climbing = true
		add_view_punch(-1.0)
		Sfx.play("catch", -10.0) # Hands on the wall.
	_climb_left -= delta
	var n: Vector3 = wall.normal
	n.y = 0.0
	velocity = -n.normalized() * 0.5 + Vector3.UP * wall_climb_speed # Pressed to the wall, going up.
	return true


## Jump pressed in the air with a wall right next to you (any side): kick off it, away and
## up a little. wall_jumps per time in the air, never off the same wall twice in a row, and
## no climbing again afterwards.
func _try_wall_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer > 0.0 or _wall_jumps_left <= 0 or health.downed:
		return
	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	for dir: Vector3 in [fwd, right, -right, -fwd]:
		var wall := _wall_hit(dir)
		if wall.is_empty():
			continue
		var n: Vector3 = wall.normal
		n.y = 0.0
		n = n.normalized()
		if n.dot(_last_wall) > 0.9:
			return # The wall you just kicked off.
		_wall_jumps_left -= 1
		_last_wall = n
		_climbing = false
		_climb_left = 0.0
		_jump_buffer_timer = 0.0
		var h := get_horizontal_velocity()
		h -= n * minf(h.dot(n), 0.0) # Lose the speed you had going into the wall.
		velocity = h + n * wall_jump_push + Vector3.UP * sqrt(2.0 * gravity * wall_jump_height)
		add_view_punch(-1.2)
		Sfx.play("throw", -12.0)
		return


## Scrambling up a wall right now (the viewmodel tucks the gun away like a mantle).
func is_wall_climbing() -> bool:
	return _climbing and state == MoveState.AIR


# --- Mantling -------------------------------------------------------------------

## In the air and moving towards a ledge you can reach (a solid face in front of you with
## a flat top mantle_min_height..mantle_reach above your feet, and room to stand on it):
## start climbing onto it.
func _try_mantle() -> bool:
	if _mantle_cooldown > 0.0 or health.downed or _wish_dir == Vector3.ZERO:
		return false
	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	if _wish_dir.dot(fwd) < 0.5:
		return false
	var feet := global_position
	var space := get_world_3d().direct_space_state
	var reach := _capsule.radius + 0.45
	var face := {}
	for h: float in [mantle_min_height + 0.05, (mantle_min_height + mantle_reach) * 0.5, mantle_reach - 0.05]:
		var from := feet + Vector3.UP * h
		face = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + fwd * reach, MANTLE_MASK))
		if not face.is_empty():
			break
	if face.is_empty() or absf((face.normal as Vector3).y) > 0.3:
		return false # Nothing in front, or it's a slope rather than a ledge.
	# Look down just past the face for the top.
	var over: Vector3 = (face.position as Vector3) + fwd * (_capsule.radius + 0.1)
	var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(over.x, feet.y + mantle_reach + 0.25, over.z), Vector3(over.x, feet.y + mantle_min_height - 0.1, over.z), MANTLE_MASK))
	if top.is_empty() or (top.normal as Vector3).y < 0.75:
		return false
	var top_y: float = (top.position as Vector3).y
	var rise := top_y - feet.y
	if rise < mantle_min_height or rise > mantle_reach:
		return false
	var target := Vector3(over.x, top_y + 0.02, over.z)
	if test_move(global_transform, Vector3.UP * (rise + 0.05)) or not _fits_at(target, stand_height):
		return false # A ceiling over you, or no room up there.
	_mantle_from = feet
	_mantle_to = target
	_mantle_t = 0.0
	var how_high := clampf((rise - mantle_min_height) / maxf(mantle_reach - mantle_min_height, 0.01), 0.0, 1.0)
	_mantle_len = mantle_time * lerpf(1.0, 1.4, how_high)
	_mantle_exit = maxf(get_horizontal_speed() * 0.6, mantle_exit_speed)
	velocity = Vector3.ZERO
	_change_state(MoveState.MANTLE)
	add_view_punch(-2.0)
	return true


## Up first, then over the top: the body rises against the face for most of the climb
## and only moves forward once it's nearly level with the top.
func _tick_mantle(delta: float) -> void:
	_mantle_t += delta
	var p := get_mantle_progress()
	var up := smoothstep(0.0, 0.65, p)
	var across := smoothstep(0.55, 1.0, p)
	global_position = Vector3(lerpf(_mantle_from.x, _mantle_to.x, across), lerpf(_mantle_from.y, _mantle_to.y, up),
			lerpf(_mantle_from.z, _mantle_to.z, across))
	velocity = Vector3.ZERO
	if p < 1.0:
		return
	var fwd := _mantle_to - _mantle_from
	fwd.y = 0.0
	velocity = fwd.normalized() * _mantle_exit
	_mantle_cooldown = 0.25
	_land_dip = 0.06
	_change_state(MoveState.GROUND)
	Sfx.play("catch", -6.0)
	if _glide_queued:
		_superglide()
	else:
		_glide_open = 0.0 if _glide_spoiled else superglide_window
	_glide_queued = false
	_glide_spoiled = false


## Watches for the superglide jump during a mantle: in the last superglide_window it's
## queued for the moment you come over the top; any earlier and it's spoiled.
func _watch_superglide() -> void:
	if not Input.is_action_just_pressed("jump") or PauseMenu.visible:
		return
	if _mantle_len - _mantle_t <= superglide_window:
		_glide_queued = true
	else:
		_glide_spoiled = true


## Apex's superglide: a perfectly timed jump off the top of a mantle launches you forward
## with a low hop. Hold crouch to land it in a slide.
func _superglide() -> void:
	var fwd := -global_basis.z
	fwd.y = 0.0
	var speed := maxf(get_horizontal_speed(), superglide_speed)
	velocity = fwd.normalized() * speed + Vector3.UP * sqrt(2.0 * gravity * superglide_hop)
	_glide_open = 0.0
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_change_state(MoveState.AIR)
	add_view_punch(-1.5)
	Sfx.play("throw", -8.0) # A rush of air.


## A big hit (Health.knocked, on this machine only): thrown back, camera shaken.
func _on_knocked(impulse: Vector3) -> void:
	velocity += impulse
	if impulse.y > 0.0:
		_knocked = 0.15
		_coyote_timer = 0.0
		_change_state(MoveState.AIR)
	add_shake(impulse.length() * 0.1)


## Shakes the camera (only the camera: aim isn't affected). Strength around 0.5-1.
func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.5)


## For the HUD's superglide cue: seconds until the jump window opens (0 = jump now), or -1
## when there's nothing to time.
func superglide_wait() -> float:
	if state == MoveState.MANTLE:
		return maxf(_mantle_len - _mantle_t - superglide_window, 0.0)
	return 0.0 if _glide_open > 0.0 else -1.0


## Jumped too early in this mantle: no superglide this time.
func superglide_spoiled() -> bool:
	return state == MoveState.MANTLE and _glide_spoiled


## 0..1 through the current mantle.
func get_mantle_progress() -> float:
	return clampf(_mantle_t / maxf(_mantle_len, 0.01), 0.0, 1.0)


## A capsule of this height, standing at `feet`, wouldn't overlap the world, a player or
## an enemy.
func _fits_at(feet: Vector3, h: float) -> bool:
	var probe := CapsuleShape3D.new()
	probe.radius = _capsule.radius - 0.02
	probe.height = h
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.collision_mask = 1 | 4 | 8 | 16 | 32
	q.exclude = [get_rid()]
	q.transform = Transform3D(Basis(), feet + Vector3.UP * (h * 0.5 + 0.02))
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Self-reviving swings the camera out behind you (you see yourself on the ground and
## what's coming) and back when you're up. Blends over THIRD_PERSON_BLEND.
func _third_person_camera(delta: float) -> void:
	var want := 1.0 if health.is_self_reviving() else 0.0
	_third_person = move_toward(_third_person, want, delta / THIRD_PERSON_BLEND)
	_set_avatar_visible(_third_person > 0.01)
	if _third_person <= 0.01:
		return
	_update_avatar()
	var focus := global_position + Vector3.UP * 0.5
	var want_pos := focus + global_basis.z * THIRD_PERSON_DISTANCE + Vector3.UP * THIRD_PERSON_HEIGHT
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(focus, want_pos, 1))
	if not hit.is_empty(): # Don't put the camera inside a wall.
		want_pos = (hit.position as Vector3) + (focus - want_pos).normalized() * 0.2
	var behind := Transform3D(Basis(), want_pos).looking_at(focus, Vector3.UP)
	camera.global_transform = camera.global_transform.interpolate_with(behind, smoothstep(0.0, 1.0, _third_person))


func _process(delta: float) -> void:
	var target_eye := stand_eye_height
	if health.downed:
		target_eye = downed_eye_height
	elif is_crouched:
		target_eye = crouch_eye_height
	_eye_height = lerpf(_eye_height, target_eye, 1.0 - exp(-crouch_transition_speed * delta))
	_land_dip = lerpf(_land_dip, 0.0, 1.0 - exp(-8.0 * delta))
	head.position.y = _eye_height - _land_dip
	if not is_local:
		_follow_network(delta)
		_update_avatar()
		return
	if health.eliminated:
		_spectate(delta)
		return

	camera.position = Vector3.ZERO # Back on your head (third person moves it).
	var span := maxf(fov_kick_full_speed - run_speed, 0.01)
	var speed_t := clampf((get_horizontal_speed() - run_speed) / span, 0.0, 1.0)
	_fov_kick = lerpf(_fov_kick, speed_fov_kick * speed_t * (1.0 - ads_amount), 1.0 - exp(-6.0 * delta))
	var zoomed := rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) * 0.5) / zoom))
	camera.fov = zoomed + _fov_kick

	# View punch only shakes the camera; aim comes from the Head, so shots aren't affected.
	_view_punch = _view_punch.lerp(Vector2.ZERO, 1.0 - exp(-view_punch_return * delta))
	camera.rotation.x = _view_punch.x
	camera.rotation.y = _view_punch.y
	var lean := 0.0
	if state == MoveState.SLIDE:
		var side := get_local_velocity().x / maxf(get_horizontal_speed(), 1.0)
		lean = clampf(side / maxf(slide_lean_full, 0.01), -1.0, 1.0)
	slide_lean = lerpf(slide_lean, lean, 1.0 - exp(-8.0 * delta))
	var roll := -deg_to_rad(slide_tilt_deg) * slide_lean
	if state == MoveState.MANTLE: # Lean into the climb, and back out as you come over the top.
		roll += deg_to_rad(mantle_tilt_deg) * sin(get_mantle_progress() * PI)
	camera.rotation.z = lerpf(camera.rotation.z, roll, 1.0 - exp(-10.0 * delta))
	_shake = lerpf(_shake, 0.0, 1.0 - exp(-5.0 * delta))
	if _shake > 0.01: # Rattles the camera round; your aim (the Head) doesn't move.
		camera.rotation += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * _shake * 0.05
	_third_person_camera(delta)


# --- Movement per state -----------------------------------------------------

func _move_ground(delta: float, jumping: bool) -> void:
	# Skipping friction on the jump tick is what lets bunny hops keep speed.
	if not jumping:
		_apply_friction(friction, delta)
	_accelerate(_wish_dir, _ground_target_speed(), ground_accel, delta)
	velocity.y = 0.0


func _move_air(delta: float) -> void:
	_last_fall_speed = maxf(-velocity.y, 0.0)
	var wish_speed := sprint_speed if is_sprinting else run_speed
	_air_accelerate(_wish_dir, wish_speed * move_speed_multiplier * weapon_speed_multiplier, delta)
	velocity.y -= gravity * delta


func _move_slide(delta: float, crouch_held: bool) -> void:
	var h := get_horizontal_velocity()

	# Gravity pulls you along the slope (speeds you up downhill, slows you uphill).
	var n := get_floor_normal()
	var g := Vector3.DOWN * gravity
	var along_slope := g - n * g.dot(n)
	along_slope.y = 0.0
	h += along_slope * slide_slope_accel * delta

	var speed := maxf(h.length() - slide_decel * delta, 0.0)
	if speed > 0.01:
		var dir := h.normalized()
		# Light steering, only toward directions you're already roughly facing.
		if _wish_dir != Vector3.ZERO and dir.dot(_wish_dir) > 0.0:
			dir = dir.slerp(_wish_dir, clampf(slide_steer_rate * delta, 0.0, 1.0)).normalized()
		h = dir * speed
	else:
		h = Vector3.ZERO

	velocity.x = h.x
	velocity.z = h.z
	velocity.y = 0.0

	if speed < slide_exit_speed or not crouch_held:
		_change_state(MoveState.GROUND)


# --- Helpers ----------------------------------------------------------------

func _read_input() -> void:
	# Stand still: online the game keeps running behind the menu, and reviving (someone
	# else, being revived, or using a kit) holds you in place.
	var held := PauseMenu.visible or (health.downed and health.reviver != 0) \
			or (interact != null and interact.is_reviving())
	if held:
		_wish_dir = Vector3.ZERO
		is_sprinting = false
		_crouch_started = false
		_jump_buffer_timer = 0.0
		auto_running = false
		return
	_update_auto_run()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if auto_running:
		input.y = -1.0 # Forward, flat out; strafe keys still steer.
	var dir := transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	_wish_dir = dir.normalized()

	var was_crouched := _crouch_down
	if Settings.toggle_crouch:
		if Input.is_action_just_pressed("crouch"):
			_crouch_down = not _crouch_down
	else:
		_crouch_down = Input.is_action_pressed("crouch")
	_crouch_started = _crouch_down and not was_crouched

	var moving_forward := input.y < -0.5
	if Settings.toggle_sprint:
		if Input.is_action_just_pressed("sprint"):
			_sprint_toggled = not _sprint_toggled
		if not moving_forward:
			_sprint_toggled = false
		is_sprinting = _sprint_toggled and moving_forward and not is_crouched and not sprint_blocked
	else:
		is_sprinting = Input.is_action_pressed("sprint") and moving_forward and not is_crouched and not sprint_blocked
	if auto_running:
		is_sprinting = not is_crouched and not sprint_blocked
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	if health.downed: # Crawling: no sprint, slide or jump.
		is_sprinting = false
		_crouch_started = false
		_jump_buffer_timer = 0.0
	if health.healing:
		is_sprinting = false


## Auto-run: double-tap sprint and you keep sprinting forward hands-free (strafe keys
## steer, jumping and mantling carry on) until you do something else: move forward or
## back, crouch, shoot, aim, reload, use, heal, melee or throw, get downed, or stop to
## revive.
func _update_auto_run() -> void:
	if Input.is_action_just_pressed("sprint"):
		if _since_sprint_tap <= AUTO_RUN_TAP and not health.downed:
			auto_running = true
		_since_sprint_tap = 0.0
	if not auto_running:
		return
	if health.downed or health.healing:
		auto_running = false
		return
	for action: String in AUTO_RUN_STOPS:
		if Input.is_action_just_pressed(action):
			auto_running = false
			return


func _tick_timers(delta: float) -> void:
	_since_sprint_tap += delta
	_mantle_cooldown = maxf(_mantle_cooldown - delta, 0.0)
	_zip_cooldown = maxf(_zip_cooldown - delta, 0.0)
	_glide_open = maxf(_glide_open - delta, 0.0)
	_knocked = maxf(_knocked - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_slide_boost_timer = maxf(_slide_boost_timer - delta, 0.0)
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)


func _ground_target_speed() -> float:
	if health.downed:
		return crawl_speed
	if health.healing: # Patching yourself up: a slow walk.
		return run_speed * 0.5
	if is_crouched:
		return crouch_speed * move_speed_multiplier * weapon_speed_multiplier
	if is_sprinting:
		return sprint_speed * weapon_speed_multiplier
	return run_speed * move_speed_multiplier * weapon_speed_multiplier


func _apply_friction(amount: float, delta: float) -> void:
	var h := get_horizontal_velocity()
	var speed := h.length()
	if speed < 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var drop := maxf(speed, stop_speed) * amount * delta
	var scale := maxf(speed - drop, 0.0) / speed
	velocity.x *= scale
	velocity.z *= scale


func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
	if wish_dir == Vector3.ZERO:
		return
	var add := wish_speed - velocity.dot(wish_dir)
	if add <= 0.0:
		return
	velocity += wish_dir * minf(accel * wish_speed * delta, add)


func _air_accelerate(wish_dir: Vector3, wish_speed: float, delta: float) -> void:
	# Source-style: the *cap* limits how much speed you can add along wish_dir,
	# but acceleration still uses full wish_speed. Turning while strafing gains speed.
	if wish_dir == Vector3.ZERO:
		return
	var add := minf(wish_speed, air_speed_cap) - get_horizontal_velocity().dot(wish_dir)
	if add <= 0.0:
		return
	velocity += wish_dir * minf(air_accel * wish_speed * delta, add)


func _jump() -> void:
	velocity.y = sqrt(2.0 * gravity * jump_height)
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_change_state(MoveState.AIR)


func _on_landed(crouch_held: bool) -> void:
	_land_dip = clampf(_last_fall_speed * land_dip_scale, 0.0, 0.18)
	if _last_fall_speed > 6.0: # A real drop, not a hop.
		Sfx.play("land", lerpf(-14.0, -4.0, clampf((_last_fall_speed - 6.0) / 10.0, 0.0, 1.0)))
	if crouch_held and get_horizontal_speed() >= slide_enter_speed:
		_start_slide()
	else:
		_change_state(MoveState.GROUND)


func _start_slide() -> void:
	var h := get_horizontal_velocity()
	var speed := h.length()
	if speed < 0.01:
		return
	if _slide_boost_timer <= 0.0:
		h = h / speed * (speed + slide_boost)
		velocity.x = h.x
		velocity.z = h.z
		_slide_boost_timer = slide_boost_cooldown
	_change_state(MoveState.SLIDE)


func _clamp_speed() -> void:
	var h := get_horizontal_velocity()
	if h.length() > max_speed:
		h = h.normalized() * max_speed
		velocity.x = h.x
		velocity.z = h.z


## Collider height: lowest while downed, then crouching or sliding, then standing.
## Getting taller waits until there's room overhead.
func _update_crouch(crouch_held: bool) -> void:
	var want := stand_height
	if health.downed:
		want = downed_height
	elif crouch_held or state == MoveState.SLIDE:
		want = crouch_height
	if want < _height or (want > _height and _has_headroom(want)):
		_set_collider_height(want)
	is_crouched = _height < stand_height


## Room to grow to height h. The world, a teammate or an enemy over your head all keep
## you down. The probe is a little thinner than you and starts above your feet, so
## touching a wall, the floor or someone beside you never counts as being blocked.
func _has_headroom(h: float) -> bool:
	var probe := CapsuleShape3D.new()
	probe.radius = _capsule.radius - 0.05
	var bottom := 0.15
	probe.height = maxf(h - bottom, probe.radius * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.collision_mask = 1 | 4 | 8 | 16 | 32
	q.exclude = [get_rid()]
	q.transform = Transform3D(Basis(), global_position + Vector3.UP * (bottom + probe.height * 0.5))
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _set_collider_height(h: float) -> void:
	_height = h
	_capsule.height = h
	collision.position.y = h * 0.5


## Turns the view: right/up in radians.
func _turn(right: float, up: float) -> void:
	rotate_y(-right)
	var limit := deg_to_rad(max_pitch_deg)
	_pitch = clampf(_pitch + up, -limit, limit)
	head.rotation.x = _pitch


## Mouse movement against the recoil counts as compensation, so recovery
## won't drag you past where you pulled to.
func _pay_recoil_debt(right: float, up: float) -> void:
	if _recoil_debt.y > 0.0 and up < 0.0:
		_recoil_debt.y = maxf(_recoil_debt.y + up, 0.0)
	if right != 0.0 and signf(right) != signf(_recoil_debt.x):
		_recoil_debt.x = move_toward(_recoil_debt.x, 0.0, absf(right))


func _change_state(new_state: MoveState) -> void:
	if new_state == state:
		return
	if new_state == MoveState.AIR: # Off the ground: a fresh wall climb and wall jumps.
		_climb_left = wall_climb_time
		_wall_jumps_left = wall_jumps
		_last_wall = Vector3.ZERO
	_climbing = false
	state = new_state
	state_changed.emit(state)


# --- Public API (used by viewmodel / HUD, and later by weapons) ------------

func get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func get_horizontal_speed() -> float:
	return get_horizontal_velocity().length()


func get_local_velocity() -> Vector3:
	return global_transform.basis.inverse() * velocity


func get_state_name() -> String:
	return MoveState.keys()[state]


func is_slide_boost_ready() -> bool:
	return _slide_boost_timer <= 0.0


## Recoil kick: moves your actual aim. Degrees, up / right.
func add_recoil(up_deg: float, right_deg: float) -> void:
	var r := Vector2(deg_to_rad(right_deg), deg_to_rad(up_deg))
	_turn(r.x, r.y)
	_recoil_debt += r


## Drifts the view back by up to `amount` radians of recoil you didn't pull against.
func recover_recoil(amount: float) -> void:
	if _recoil_debt == Vector2.ZERO:
		return
	var step := _recoil_debt.limit_length(amount)
	_turn(-step.x, -step.y)
	_recoil_debt -= step


## Visual-only camera shake (degrees, upward).
func add_view_punch(deg: float) -> void:
	_view_punch += Vector2(deg_to_rad(deg), deg_to_rad(deg) * randf_range(-0.3, 0.3))


## Mouse movement since the last call. The viewmodel uses it for sway.
func consume_look_delta() -> Vector2:
	var d := _look_delta
	_look_delta = Vector2.ZERO
	return d


## Shows a shot to everyone else: a tracer to each end point, and an impact where
## hits[i] says it hit something (0 = nothing, 1 = world, gets a bullet hole, 2 = a
## target, just a spark). Cosmetic: damage stays with the shooter for now.
func broadcast_shot(sound: String, ends: PackedVector3Array, normals: PackedVector3Array, hits: PackedByteArray) -> void:
	if Net.is_online():
		_remote_shot.rpc(sound, ends, normals, hits)


# --- Networking -----------------------------------------------------------------

func _make_synchronizer() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for prop: String in ["net_position", "net_velocity", "net_yaw", "net_pitch", "net_crouched"]:
		var path := NodePath(".:" + prop)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE \
				if prop == "net_crouched" else SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = config
	sync.replication_interval = 1.0 / SYNC_RATE
	sync.delta_interval = 1.0 / SYNC_RATE
	sync.synchronized.connect(func() -> void: _net_age = 0.0)
	return sync


func _publish() -> void:
	net_position = global_position
	net_velocity = velocity
	net_yaw = rotation.y
	net_pitch = _pitch
	net_crouched = is_crouched


## Remote copies: glide towards the latest update, carrying on along its velocity for a
## moment so movement doesn't stutter between updates.
func _follow_network(delta: float) -> void:
	_net_age += delta
	var target := net_position + net_velocity * minf(_net_age, MAX_EXTRAPOLATION)
	var k := 1.0 - exp(-REMOTE_SMOOTHING * delta)
	if global_position.distance_to(target) > SNAP_DISTANCE:
		global_position = target
	else:
		global_position = global_position.lerp(target, k)
	rotation.y = lerp_angle(rotation.y, net_yaw, k)
	head.rotation.x = lerpf(head.rotation.x, net_pitch, k)
	velocity = net_velocity
	var h := stand_height
	if health.downed:
		h = downed_height
	elif net_crouched:
		h = crouch_height
	if h != _height:
		_set_collider_height(h)
	is_crouched = h < stand_height


## Going down, getting up, or being taken out. Out means no collision: bullets and
## teammates pass through, and your own camera follows a teammate instead.
func _on_life_changed() -> void:
	collision.set_deferred("disabled", health.eliminated)
	if not is_local:
		return
	if health.eliminated:
		velocity = Vector3.ZERO
		_spectating = null
	else:
		camera.transform = Transform3D.IDENTITY # Back from spectating.


## Out of the run: the camera follows a living (or downed) teammate from behind. Fire
## switches to the next one.
func _spectate(delta: float) -> void:
	if Input.is_action_just_pressed("fire") and not PauseMenu.visible:
		_spectating = _next_to_spectate(_spectating)
	if _spectating == null or not is_instance_valid(_spectating) or _spectating.health.eliminated:
		_spectating = _next_to_spectate(null)
	if _spectating == null:
		return
	var focus := _spectating.head.global_position
	var want := focus + _spectating.global_basis.z * SPECTATE_DISTANCE + Vector3.UP * 0.8
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(focus, want, 1))
	if not hit.is_empty(): # Don't put the camera inside a wall.
		want = (hit.position as Vector3) + (focus - want).normalized() * 0.2
	camera.global_position = camera.global_position.lerp(want, 1.0 - exp(-10.0 * delta))
	if camera.global_position.distance_squared_to(focus) > 0.01:
		camera.look_at(focus, Vector3.UP)


## The teammate after `after` in the player list who's still in the run, or null.
func _next_to_spectate(after: Player) -> Player:
	var options: Array[Player] = []
	for p: Player in Game.players.get_children():
		if p != self and not p.health.eliminated:
			options.append(p)
	if options.is_empty():
		return null
	var i := options.find(after)
	return options[(i + 1) % options.size()]


## The teammate the camera follows once you're out, or null.
func get_spectated() -> Player:
	return _spectating if health.eliminated else null


@rpc("authority", "call_remote", "unreliable_ordered")
func _remote_shot(sound: String, ends: PackedVector3Array, normals: PackedVector3Array, hits: PackedByteArray) -> void:
	var world := get_tree().current_scene
	if world == null or _avatar_gun == null:
		return
	var muzzle := _avatar_gun.global_position - _avatar_gun.global_basis.z * 0.3
	for i in ends.size():
		WeaponFx.tracer(world, muzzle, ends[i])
		if hits[i] != 0:
			WeaponFx.impact(world, ends[i], normals[i], hits[i] == 1)
	Sfx.play_at(sound, muzzle, -5.0)


## What other players see: a person in this player's colour (legs, arms, the lot: see
## Humanoid) holding a gun, a visor and the gun following where they look, and their name
## and health bar overhead. Your own player gets the body too (no tag or bar), hidden
## except in third person.
func _build_avatar() -> void:
	var color: Color = COLORS[slot % COLORS.size()]
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.08, 0.08, 0.1)

	_avatar = Humanoid.new(color, stand_height)
	_avatar.name = "Avatar"
	_avatar.arms_free = false # Both hands on the gun.
	add_child(_avatar)

	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.26, 0.1, 0.06)
	visor.mesh = visor_mesh
	visor.material_override = dark_mat
	visor.position = Vector3(0.0, 0.02, -0.17)
	head.add_child(visor)
	_avatar_visor = visor

	var gun := MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.07, 0.1, 0.55)
	gun.mesh = gun_mesh
	gun.material_override = dark_mat
	gun.position = Vector3(0.28, -0.3, -0.45)
	head.add_child(gun)
	_avatar_gun = gun
	if is_local:
		_set_avatar_visible(false)
		return

	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true # Teammates' tags show through walls, so you can find them when they're down.
	_tag.outline_size = 12
	_tag.font_size = 40
	_tag.pixel_size = 0.006
	add_child(_tag)

	_bars = HealthBar3D.new(Color(0.95, 0.95, 0.95), 0.6)
	add_child(_bars)
	_update_avatar()


func _set_avatar_visible(on: bool) -> void:
	_avatar.visible = on
	_avatar_visor.visible = on and not health.downed
	_avatar_gun.visible = on and not health.downed


## Every frame the body shows: its pose (standing, crouched lower, lying face down when
## downed), and for remote copies, gone when out, plus the tag and health bar overhead.
func _update_avatar() -> void:
	if health.downed: # Lying on the ground, head towards where they face, arms limp.
		_avatar.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		_avatar.position = Vector3(0.0, 0.16, stand_height * 0.5)
		_avatar.scale = Vector3.ONE
		_avatar.left_arm.rotation.x = 0.0
		_avatar.right_arm.rotation.x = 0.0
	else:
		_avatar.rotation = Vector3.ZERO
		_avatar.position = Vector3.ZERO
		_avatar.scale = Vector3(1.0, _height / stand_height, 1.0) # Crouching squats down.
		_avatar.right_arm.rotation.x = 1.35 + head.rotation.x # Gun up, following where they aim.
		_avatar.left_arm.rotation.x = 1.15 + head.rotation.x
		_avatar.left_arm.rotation.z = -0.35
	if is_local:
		return
	var out := health.eliminated
	_set_avatar_visible(not out)
	_tag.visible = not out
	_bars.visible = not out

	var color: Color = COLORS[slot % COLORS.size()]
	var top := (downed_height if health.downed else _height) + 0.25
	_bars.position.y = top
	_bars.set_fill(health.health / health.max_health)
	_bars.set_shield(health.shield / health.max_shield if health.max_shield > 0.0 else 0.0, PlayerHealth.shield_color(health.max_shield))
	_tag.position.y = top + 0.2
	_tag.text = Game.player_name(peer_id)
	_tag.modulate = color
	if health.downed:
		_tag.modulate = Color(1.0, 0.3, 0.25)
		if health.reviver != 0:
			_tag.text += "  REVIVING %d%%" % roundi(health.revive_progress * 100.0)
		else:
			_tag.text += "  DOWNED %d" % ceili(health.bleed_left)
