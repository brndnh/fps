class_name Viewmodel
extends Node3D
## Procedural viewmodel motion: mouse sway, strafe roll, walk bob,
## sprint/slide poses, and jump/land kick. The node's position and rotation
## in the scene are its rest pose; everything here is an offset from that.
## The WeaponManager sets the hip/ADS rest positions per weapon, the ADS blend,
## recoil kicks, and reload/switch/inspect/melee offsets, which stack on top.

@export_group("Sway")
@export var sway_amount: float = 0.0012 ## Radians per mouse count.
@export var sway_max_deg: float = 5.0
@export var sway_return: float = 7.0
@export var sway_smooth: float = 14.0
@export var strafe_roll: float = 0.008

@export_group("Bob")
@export var bob_frequency: float = 0.28 ## Cycles per metre travelled.
@export var bob_amount: Vector2 = Vector2(0.010, 0.008)

@export_group("Idle")
## Breathing sway while you stand still, so the hands never freeze. Fades out as the
## walk bob takes over, and shrinks with the rest of the motion when aimed.
@export var idle_position: Vector3 = Vector3(0.0025, 0.0035, 0.002) ## Metres.
@export var idle_rotation_deg: Vector3 = Vector3(0.7, 0.5, 0.6)
@export var idle_speed: float = 1.0 ## 1 = one slow breath every ~4 s.

@export_group("Poses")
@export var sprint_position: Vector3 = Vector3(-0.03, -0.05, 0.03)
@export var sprint_rotation_deg: Vector3 = Vector3(-12.0, 28.0, 8.0)
@export var slide_position: Vector3 = Vector3(-0.02, -0.02, 0.02)
@export var slide_rotation_deg: Vector3 = Vector3(0.0, 0.0, -14.0) ## The roll (z) is for sliding right; it mirrors sliding left and fades out sliding straight.
@export var mantle_position: Vector3 = Vector3(0.04, -0.18, 0.08) ## Gun tucked down and away while you pull yourself up a ledge.
@export var mantle_rotation_deg: Vector3 = Vector3(-35.0, -12.0, 22.0)
@export var heal_position: Vector3 = Vector3(0.0, -0.7, 0.15) ## Gun dropped right out of view while your arms use a heal (HealInput).
@export var heal_rotation_deg: Vector3 = Vector3(-40.0, 8.0, 0.0)
@export var pose_speed: float = 9.0
@export var mantle_pose_speed: float = 18.0 ## Mantles are quick: the tuck has to keep up.

@export_group("Vertical")
@export var air_offset_scale: float = 0.004
@export var land_kick: float = 0.035

@export_group("Weapon")
@export var ads_motion_scale: float = 0.2 ## How much sway/bob is left when fully aimed.
@export var kick_return: float = 16.0
@export var kick_max_back: float = 0.08
@export var kick_max_rotation_deg: float = 10.0

var player: Player

var _rest_position: Vector3
var _rest_rotation: Vector3
var _sway_target := Vector3.ZERO
var _sway := Vector3.ZERO
var _bob_phase := 0.0
var _bob_weight := 0.0
var _idle_t := 0.0
var _pose_pos := Vector3.ZERO
var _pose_rot := Vector3.ZERO
var _vertical := 0.0
var _land := 0.0
var _prev_state: int = -1
var _hip_position: Vector3
var _ads_position: Vector3
var _kick_back := 0.0
var _kick_rot := 0.0

## Set every frame by the WeaponManager.
var ads_blend := 0.0
var action_position := Vector3.ZERO
var action_rotation_deg := Vector3.ZERO


func _ready() -> void:
	_rest_position = position
	_rest_rotation = rotation
	_hip_position = position
	_ads_position = position
	var n := get_parent()
	while n != null and not (n is Player):
		n = n.get_parent()
	player = n as Player


func _process(delta: float) -> void:
	if player == null:
		return
	var speed := player.get_horizontal_speed()
	var st := player.state

	# Sway: the weapon lags behind your aim, then springs back.
	var look := player.consume_look_delta()
	var max_sway := deg_to_rad(sway_max_deg)
	_sway_target.x = clampf(_sway_target.x + look.y * sway_amount, -max_sway, max_sway)
	_sway_target.y = clampf(_sway_target.y + look.x * sway_amount, -max_sway, max_sway)
	_sway_target = _sway_target.lerp(Vector3.ZERO, 1.0 - exp(-sway_return * delta))
	var roll := clampf(-player.get_local_velocity().x * strafe_roll, -0.08, 0.08)
	_sway = _sway.lerp(Vector3(_sway_target.x, _sway_target.y, roll), 1.0 - exp(-sway_smooth * delta))

	# Bob while moving on the ground.
	var bobbing := st == Player.MoveState.GROUND and speed > 0.5
	var bob_target := clampf(speed / player.run_speed, 0.0, 1.4) if bobbing else 0.0
	_bob_weight = lerpf(_bob_weight, bob_target, 1.0 - exp(-10.0 * delta))
	_bob_phase = fmod(_bob_phase + speed * bob_frequency * delta * TAU, TAU * 2.0)
	var bob := Vector3(sin(_bob_phase) * bob_amount.x, sin(_bob_phase * 2.0) * bob_amount.y, 0.0) * _bob_weight

	# Idle breathing: a few slow, out-of-step waves so it never looks like a loop.
	_idle_t += delta * idle_speed
	var still := clampf(1.0 - _bob_weight * 1.5, 0.0, 1.0)
	var breath := sin(_idle_t * 1.6)
	var idle_pos := Vector3(sin(_idle_t * 0.9) * idle_position.x, breath * idle_position.y,
			sin(_idle_t * 1.3 + 1.0) * idle_position.z) * still
	var idle_rot := Vector3(breath * idle_rotation_deg.x, sin(_idle_t * 0.7 + 2.0) * idle_rotation_deg.y,
			sin(_idle_t * 1.1 + 0.5) * idle_rotation_deg.z) * still

	# Sprint / slide poses.
	var target_pos := Vector3.ZERO
	var target_rot := Vector3.ZERO
	var speed_k := pose_speed
	if st == Player.MoveState.MANTLE or player.is_wall_climbing():
		target_pos = mantle_position
		target_rot = mantle_rotation_deg
		speed_k = mantle_pose_speed
	elif player.health.healing:
		target_pos = heal_position
		target_rot = heal_rotation_deg
	elif st == Player.MoveState.SLIDE:
		target_pos = slide_position
		target_rot = Vector3(slide_rotation_deg.x, slide_rotation_deg.y, slide_rotation_deg.z * player.slide_lean)
	elif st == Player.MoveState.GROUND and player.is_sprinting and speed > player.run_speed * 0.9 and not _own_sprint_pose():
		target_pos = sprint_position
		target_rot = sprint_rotation_deg
	var k := 1.0 - exp(-speed_k * delta)
	_pose_pos = _pose_pos.lerp(target_pos, k)
	_pose_rot = _pose_rot.lerp(target_rot, k)

	# Weapon trails vertical motion in the air, and dips on landing.
	var v_target := 0.0
	if st == Player.MoveState.AIR:
		v_target = clampf(-player.velocity.y * air_offset_scale, -0.05, 0.05)
	if _prev_state == Player.MoveState.AIR and st != Player.MoveState.AIR:
		_land = land_kick
	_prev_state = st
	_vertical = lerpf(_vertical, v_target, 1.0 - exp(-8.0 * delta))
	_land = lerpf(_land, 0.0, 1.0 - exp(-10.0 * delta))

	# Recoil kick snaps back toward rest.
	var kr := 1.0 - exp(-kick_return * delta)
	_kick_back = lerpf(_kick_back, 0.0, kr)
	_kick_rot = lerpf(_kick_rot, 0.0, kr)

	var motion := lerpf(1.0, ads_motion_scale, ads_blend)
	var hip := 1.0 - ads_blend
	_rest_position = _hip_position.lerp(_ads_position, ads_blend)
	position = _rest_position + _pose_pos * hip + (bob + idle_pos + Vector3(0.0, _vertical - _land, 0.0)) * motion \
			+ action_position + Vector3(0.0, 0.0, _kick_back)
	rotation = _rest_rotation + (_sway + idle_rot * (PI / 180.0)) * motion + _pose_rot * (PI / 180.0) * hip \
			+ action_rotation_deg * (PI / 180.0) + Vector3(deg_to_rad(_kick_rot), 0.0, 0.0)
	# Left-handed (Settings.left_handed, H): everything mirrored across the middle of the screen.
	if Settings.left_handed:
		position.x = -position.x
		rotation.y = -rotation.y
		rotation.z = -rotation.z
		scale = Vector3(-1, 1, 1)
	else:
		scale = Vector3.ONE


## The weapon in hand has its own sprint animation (the kunai), so the general sprint pose stays off.
func _own_sprint_pose() -> bool:
	var weapons := player.get_node_or_null("Weapons") as WeaponManager
	return weapons != null and weapons.has_own_sprint_pose()


## Hip and ADS rest positions for the weapon in hand.
func set_rest(hip: Vector3, ads: Vector3) -> void:
	_hip_position = hip
	_ads_position = ads


## Per-shot push: back along the camera, muzzle flipping up.
func kick(back: float, rotation_deg: float) -> void:
	_kick_back = minf(_kick_back + back, kick_max_back)
	_kick_rot = minf(_kick_rot + rotation_deg, kick_max_rotation_deg)
