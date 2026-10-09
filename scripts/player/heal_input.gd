class_name HealInput
extends Node
## The heal key, Apex style, on your own player. Hold it and the heal wheel opens (the
## StatusHUD draws it): nudge the mouse towards an item and let go to use it. A quick tap
## uses the last one you picked (or the smallest that helps: shields first if yours is
## dented, Apex style). Once started, the heal applies itself: no holding; the host
## counts it down (see PlayerHealth). Shooting, aiming,
## sprinting, meleeing, reloading, switching, throwing or using something cancels it, and
## you keep the item. While it applies, the item is in your hands, being used.

const WHEEL_DELAY := 0.18 ## Hold this long to open the wheel (shorter is a tap).
const PICK_DISTANCE := 20.0 ## Mouse travel (pixels) before a slice is picked.
const POINTER_MAX := 120.0
## The wheel clockwise from the top, as in Apex: trauma kit (the Phoenix kit's spot), shield
## battery, shield cell, syringe, medkit. Indices into PlayerHealth.HEALS.
const WHEEL_ORDER := [2, 4, 3, 0, 1]
const CANCELS := ["fire", "aim", "sprint", "melee", "reload", "weapon_1", "weapon_2", "weapon_3",
		"weapon_last", "weapon_next", "weapon_prev", "throw_weapon", "interact"]
const APPLY_SOUND_TIME := 0.7 ## Seconds between the item's "being used" sounds.

@onready var player: Player = get_parent()

var wheel_open := false
var selected := -1 ## The wheel slice pointed at (index into HEALS), -1 for none.
var last_kind := -1 ## What a tap uses (once you have picked one from the wheel).

var _held := -1.0 ## Seconds the heal key has been down; -1 when it's up.
var _pointer := Vector2.ZERO
var _shown_kind := -1 ## The heal being shown (it stays while the arms lower afterwards).
var _shown := 0.0 ## 0..1: the item raised into view.
var _apply_t := 0.0
var _was_healing := false
var _last_progress := 0.0


func _ready() -> void:
	_build_items()


## Anything in your pouch you could use right now?
func can_heal() -> bool:
	for k in PlayerHealth.HEALS.size():
		if player.health.can_heal_with(k):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if wheel_open and event is InputEventMouseMotion: # Steering the wheel, not the camera.
		_pointer = (_pointer + (event as InputEventMouseMotion).screen_relative).limit_length(POINTER_MAX)
		selected = _slice(_pointer)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("heal"):
		if player.health.healing:
			player.health.cancel_heal.rpc_id(1) # Pressing it again stops it.
		elif player.health.is_up():
			_held = 0.0
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("heal") and _held >= 0.0:
		use_heal(selected if wheel_open else _quick_pick())
		_close()
		get_viewport().set_input_as_handled()
		return
	if player.health.healing:
		for action: String in CANCELS:
			if event.is_action_pressed(action):
				player.health.cancel_heal.rpc_id(1) # And let the action through.
				return


func _process(delta: float) -> void:
	if _held >= 0.0:
		_held += delta
		if not wheel_open and _held >= WHEEL_DELAY:
			wheel_open = true
			_pointer = Vector2.ZERO
			selected = -1
	if wheel_open and (PauseMenu.visible or not player.health.is_up()):
		_close()
	_animate_item(delta)


## Starts a heal (the wheel, a tap, or a click in the inventory).
func use_heal(kind: int) -> void:
	if kind < 0 or not player.health.can_heal_with(kind):
		return
	last_kind = kind
	player.health.request_heal.rpc_id(1, kind)
	Sfx.play("heal_start", -4.0)


## The item the HUD shows as selected: your last pick from the wheel (while you have one),
## else what a tap would use, else anything you carry (-1 if nothing).
func shown_kind() -> int:
	if last_kind >= 0 and player.health.heals[last_kind] > 0:
		return last_kind
	var k := _quick_pick()
	if k >= 0:
		return k
	for i in PlayerHealth.HEALS.size():
		if player.health.heals[i] > 0:
			return i
	return -1


## A tap: the last one picked if you can, else the smallest that helps, shields first.
func _quick_pick() -> int:
	if player.health.can_heal_with(last_kind):
		return last_kind
	for shields: bool in [true, false]:
		for k in PlayerHealth.HEALS.size():
			if PlayerHealth.is_shield_item(k) == shields and player.health.can_heal_with(k):
				return k
	return -1


func _close() -> void:
	wheel_open = false
	selected = -1
	_held = -1.0


## Where a heal item (index into HEALS) sits on the wheel: the middle of its slice, as a
## screen angle (y is down). Apex's layout, clockwise from the top: WHEEL_ORDER.
static func slice_angle(kind: int) -> float:
	return -PI * 0.5 + TAU * WHEEL_ORDER.find(kind) / WHEEL_ORDER.size()


## The slice the pointer is in, or -1 near the middle.
func _slice(v: Vector2) -> int:
	if v.length() < PICK_DISTANCE:
		return -1
	var best := -1
	var best_dot := -2.0
	for i in PlayerHealth.HEALS.size():
		var d := Vector2.from_angle(slice_angle(i)).dot(v.normalized())
		if d > best_dot:
			best = i
			best_dot = d
	return best


# --- The heal in your hands -------------------------------------------------------------
# While a heal applies, the gun drops out of view (Viewmodel heal pose) and your own two
# arms come up and use the item, all in camera space:
#   syringe: a bandage roll wound round and round the left forearm, the wrap growing;
#   medkit / trauma kit: held in both hands, the lid flips open and the right hand keeps
#     dipping in for supplies;
#   shield cell / battery: one half in each hand, pulled apart (the charge glowing in the
#     gap), then pushed back together and pressed to your chest, Apex style.

const ARM_LENGTH := 0.42 ## Forearm, wrist to elbow.
const LEFT_ELBOW := Vector3(-0.32, -0.42, -0.2)
const RIGHT_ELBOW := Vector3(0.32, -0.42, -0.2)

var _rig: Node3D ## The arms and every item, under the camera.
var _arm_l: Node3D
var _arm_r: Node3D
var _props := {} ## Item parts by name.


## Raised into view while a heal applies, used, then lowered. Sounds along the way; a
## chime when it's done.
func _animate_item(delta: float) -> void:
	var h := player.health
	var healing := h.healing and h.heal_kind >= 0
	if _was_healing and not healing and _last_progress > 0.9:
		Sfx.play("heal_done", -8.0)
	_was_healing = healing
	if healing:
		_shown_kind = h.heal_kind
		_last_progress = h.heal_progress
	_shown = move_toward(_shown, 1.0 if healing else 0.0, delta / 0.25)
	_rig.visible = _shown > 0.01 and _shown_kind >= 0
	if not _rig.visible:
		return
	_rig.scale = Vector3(-1, 1, 1) if Settings.left_handed else Vector3.ONE
	var kind := _shown_kind
	for n: String in _props:
		(_props[n] as Node3D).visible = n.begins_with(_group(kind))
	var t := Time.get_ticks_msec() * 0.001
	var drop := Vector3(0, -0.45 * (1.0 - smoothstep(0.0, 1.0, _shown)), 0)
	var p := _last_progress
	match kind:
		0:
			_animate_bandage(t, p, drop)
		1, 2:
			_animate_kit(t, p, drop, 1.0 if kind == 1 else 1.3)
		_:
			_animate_cell(t, p, drop, 1.0 if kind == 3 else 1.35)
	if healing:
		_apply_t -= delta
		if _apply_t <= 0.0:
			_apply_t = APPLY_SOUND_TIME
			Sfx.play("heal_apply", -6.0)


func _group(kind: int) -> String:
	return "Bandage" if kind == 0 else ("Kit" if kind <= 2 else "Cell")


## Syringe: the left forearm held across, the right hand winding a bandage round it.
func _animate_bandage(t: float, p: float, drop: Vector3) -> void:
	var lh := Vector3(-0.02, -0.2, -0.42) + drop
	_arm_to(_arm_l, lh, LEFT_ELBOW + drop)
	var axis := (lh - (LEFT_ELBOW + drop)).normalized()
	var mid := lh - axis * ARM_LENGTH * 0.45
	var u := axis.cross(Vector3.UP).normalized()
	var v := axis.cross(u)
	var w := t * 7.0
	var rh := mid + (u * cos(w) + v * sin(w)) * 0.085 + axis * sin(t * 1.3) * 0.05
	_arm_to(_arm_r, rh, RIGHT_ELBOW + drop)
	var roll: Node3D = _props.BandageRoll
	roll.position = rh
	var wrap: Node3D = _props.BandageWrap
	wrap.position = mid
	wrap.basis = Basis.looking_at(axis, Vector3.UP)
	wrap.scale = Vector3(1, 1, lerpf(0.15, 1.0, p))


## Medkit / trauma kit: held in both hands, lid open, the right hand dipping in and out.
func _animate_kit(t: float, p: float, drop: Vector3, s: float) -> void:
	var kit: Node3D = _props.KitBody
	var centre := Vector3(0, -0.25, -0.46) + drop + Vector3(0, sin(t * 2.0) * 0.006, 0)
	kit.position = centre
	kit.rotation = Vector3(0.35, 0, 0)
	kit.scale = Vector3.ONE * s
	var lid: Node3D = _props.KitLid
	lid.position = centre + kit.basis * (Vector3(0, 0.065, 0.075) * s)
	lid.rotation = Vector3(0.35 - 1.3 * smoothstep(0.0, 0.2, p), 0, 0) # Flips open.
	lid.scale = Vector3.ONE * s
	_arm_to(_arm_l, centre + Vector3(-0.12 * s, -0.01, 0.02), LEFT_ELBOW + drop)
	var dip := maxf(sin(t * 5.5), 0.0) # In for supplies, out again.
	var rh := centre + Vector3(0.12 * s, -0.01, 0.02).lerp(Vector3(0.03, 0.07 * s, 0.0), dip)
	_arm_to(_arm_r, rh, RIGHT_ELBOW + drop)


## Shield cell / battery: one half in each hand, pulled apart with the charge glowing
## between, then pushed together and pressed to your chest at the end.
func _animate_cell(t: float, p: float, drop: Vector3, s: float) -> void:
	var press := smoothstep(0.82, 1.0, p)
	var open := smoothstep(0.0, 0.3, p) * (1.0 - press)
	var gap := 0.01 + 0.08 * open + 0.008 * sin(t * 14.0) * open
	var centre := Vector3(0, -0.22, -0.42) + drop + Vector3(0, -0.05, 0.14) * press
	var half_w := 0.03 * s
	var left: Node3D = _props.CellLeft
	var right: Node3D = _props.CellRight
	left.position = centre - Vector3(gap * 0.5 + half_w, 0, 0)
	right.position = centre + Vector3(gap * 0.5 + half_w, 0, 0)
	left.scale = Vector3.ONE * s
	right.scale = Vector3.ONE * s
	var core: Node3D = _props.CellCore
	core.position = centre
	core.scale = Vector3(maxf(gap, 0.001) / 0.01, s * (0.8 + 0.2 * sin(t * 20.0)), s)
	_arm_to(_arm_l, left.position - Vector3(half_w + 0.02, 0.0, -0.01), LEFT_ELBOW + drop)
	_arm_to(_arm_r, right.position + Vector3(half_w + 0.02, 0.0, 0.01), RIGHT_ELBOW + drop)


## Puts a hand at `hand` with its forearm reaching back towards `elbow`.
func _arm_to(arm: Node3D, hand: Vector3, elbow: Vector3) -> void:
	arm.position = hand
	arm.basis = Basis.looking_at(elbow - hand, Vector3.UP)


func _build_items() -> void:
	_rig = Node3D.new()
	_rig.name = "HealArms"
	_rig.visible = false
	player.get_node("Head/Camera3D").add_child(_rig) # (player.camera isn't set yet: the player is ready after us.)
	var glove: Material = load("res://materials/vm_glove.tres")
	var sleeve: Material = load("res://materials/vm_sleeve.tres")
	for side in 2:
		var arm := Node3D.new()
		_rig.add_child(arm)
		_part(arm, Vector3(0.075, 0.07, 0.1), Vector3.ZERO, glove) # Hand.
		_part(arm, Vector3(0.08, 0.08, ARM_LENGTH), Vector3(0, 0, -ARM_LENGTH * 0.5 - 0.05), sleeve) # Forearm.
		if side == 0:
			_arm_l = arm
		else:
			_arm_r = arm
	var white := Interactable.flat_material(Color(0.95, 0.95, 0.95))
	var red := Interactable.flat_material(Color(0.9, 0.1, 0.1))
	# Syringe: a bandage roll, and the wrap on the forearm (it grows along its length).
	_prop("BandageRoll", [[Vector3(0.05, 0.05, 0.06), Vector3.ZERO, white]])
	_prop("BandageWrap", [[Vector3(0.095, 0.095, 0.22), Vector3.ZERO, white]])
	# Kits: a white case with a red cross, and a lid hinged at the back.
	_prop("KitBody", [[Vector3(0.22, 0.12, 0.15), Vector3.ZERO, white], [Vector3(0.1, 0.03, 0.152), Vector3.ZERO, red],
			[Vector3(0.03, 0.09, 0.152), Vector3.ZERO, red]])
	_prop("KitLid", [[Vector3(0.22, 0.012, 0.15), Vector3(0, 0, -0.075), white]])
	# Shields: two halves of a dark canister, bands glowing, and the charge between them.
	var dark := Interactable.flat_material(Color(0.12, 0.13, 0.16))
	var glow := Interactable.flat_material(PlayerHealth.HEALS[3].color, 3.0)
	for n: String in ["CellLeft", "CellRight"]:
		_prop(n, [[Vector3(0.06, 0.11, 0.06), Vector3.ZERO, dark], [Vector3(0.062, 0.02, 0.062), Vector3(0, 0.03, 0), glow],
				[Vector3(0.062, 0.02, 0.062), Vector3(0, -0.03, 0), glow]])
	_prop("CellCore", [[Vector3(0.01, 0.07, 0.04), Vector3.ZERO, Interactable.flat_material(Color(0.6, 0.85, 1.0), 6.0)]])


func _prop(n: String, parts: Array) -> void:
	var root := Node3D.new()
	root.name = n
	_rig.add_child(root)
	for p: Array in parts:
		_part(root, p[0], p[1], p[2])
	_props[n] = root


func _part(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
