class_name Player
extends CharacterBody3D
## First-person controller, tuned toward Apex Legends.
## Ground/air physics are Source-engine style: acceleration + friction on the
## ground, a capped air wish-speed so you can air-strafe.
## Sliding is Apex/Titanfall style: crouch while sprinting to slide, get a one-time
## boost (on a cooldown), keep momentum, and jump out of it to slide-hop.
## Firing or aiming stops a sprint (the WeaponManager sets sprint_blocked).
## Every tuning value is exported, so you can tweak it live in the Inspector.

signal state_changed(new_state: MoveState)

enum MoveState { GROUND, AIR, SLIDE }

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

@export_group("Camera FX")
@export var speed_fov_kick: float = 8.0
@export var fov_kick_full_speed: float = 16.0
@export var slide_tilt_deg: float = 4.0
@export var land_dip_scale: float = 0.012
@export var view_punch_return: float = 18.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D

var state: MoveState = MoveState.GROUND
var is_crouched: bool = false
var is_sprinting: bool = false

var _capsule: CapsuleShape3D
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


func _ready() -> void:
	# Unique shape so resizing it for crouch never affects another instance.
	_capsule = (collision.shape as CapsuleShape3D).duplicate()
	collision.shape = _capsule
	_set_collider_height(stand_height)
	_eye_height = stand_eye_height
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	camera.fov = base_fov
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	_tick_timers(delta)
	_read_input()
	var grounded := is_on_floor()
	var crouch_held := _crouch_down

	# State transitions
	match state:
		MoveState.GROUND, MoveState.SLIDE:
			if not grounded:
				_change_state(MoveState.AIR)
		MoveState.AIR:
			if grounded:
				_on_landed(crouch_held)
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
			_move_air(delta)

	if jump_now:
		_jump()

	_clamp_speed()
	_update_crouch(crouch_held)
	move_and_slide()


func _process(delta: float) -> void:
	var target_eye := crouch_eye_height if is_crouched else stand_eye_height
	_eye_height = lerpf(_eye_height, target_eye, 1.0 - exp(-crouch_transition_speed * delta))
	_land_dip = lerpf(_land_dip, 0.0, 1.0 - exp(-8.0 * delta))
	head.position.y = _eye_height - _land_dip

	var span := maxf(fov_kick_full_speed - run_speed, 0.01)
	var speed_t := clampf((get_horizontal_speed() - run_speed) / span, 0.0, 1.0)
	_fov_kick = lerpf(_fov_kick, speed_fov_kick * speed_t * (1.0 - ads_amount), 1.0 - exp(-6.0 * delta))
	var zoomed := rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) * 0.5) / zoom))
	camera.fov = zoomed + _fov_kick

	# View punch only shakes the camera; aim comes from the Head, so shots aren't affected.
	_view_punch = _view_punch.lerp(Vector2.ZERO, 1.0 - exp(-view_punch_return * delta))
	camera.rotation.x = _view_punch.x
	camera.rotation.y = _view_punch.y
	var tilt := deg_to_rad(slide_tilt_deg) if state == MoveState.SLIDE else 0.0
	camera.rotation.z = lerpf(camera.rotation.z, tilt, 1.0 - exp(-10.0 * delta))


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
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


func _tick_timers(delta: float) -> void:
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_slide_boost_timer = maxf(_slide_boost_timer - delta, 0.0)
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)


func _ground_target_speed() -> float:
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


func _update_crouch(crouch_held: bool) -> void:
	var want := crouch_held or state == MoveState.SLIDE
	if want and not is_crouched:
		is_crouched = true
		_set_collider_height(crouch_height)
	elif not want and is_crouched and _can_stand():
		is_crouched = false
		_set_collider_height(stand_height)


func _can_stand() -> bool:
	return not test_move(global_transform, Vector3.UP * (stand_height - crouch_height + 0.05))


func _set_collider_height(h: float) -> void:
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
