class_name Enemy
extends CharacterBody3D
## Basic enemy: the "grunt" (gun) and the "brawler" (claws, `melee` on). The host runs it: it walks the navigation mesh towards the
## nearest player who's still standing, and once it can see them within attack_range it
## stops, winds up (its eye lights up: your cue to get to cover), and fires a short
## burst. Between bursts it closes in to about preferred_range. It ignores downed players,
## so a revive is a gamble rather than a death sentence. Whoever shot it last becomes its
## target. Clients get a copy that follows the synced values.
##
## Spawned idle (not `alerted`) it holds its spot, facing the way it was placed, until it
## sees a player (within sight_range and roughly in front), hears one close by
## (hear_range; much closer if they are crouched, so you can sneak up behind one), or gets
## shot. Then it wakes the others within ALERT_RADIUS: one of you
## blundering in can bring the whole room down on the squad. Noise does it too
## (Enemy.alert_near(), e.g. throwing a breaker).
##
## Damage works like the target dummies: the shooter sees their damage number straight
## away and reports the hit, the host applies it, and everyone sees the same health bar.
##
## Spawned by Game.spawn_enemy() (usually from an EnemySpawner in the map). Collision
## layer 4 ("enemies"): players' shots hit it, the head is its own shape (hitzone = head).

enum State { CHASE, WIND_UP, FIRE, RECOVER }

const SYNC_RATE := 20.0
const SMOOTHING := 14.0
const SNAP_DISTANCE := 4.0
const SHOT_MASK := 1 | 4 | 16 | 32 ## World, players, doors and props. Other enemies don't block its shots.
const SIGHT_MASK := 1 | 16 ## The world and doors block its view.
const EYE_HEIGHT := 1.68
const RETARGET_TIME := 0.3 ## Seconds between picking the nearest player and repathing.
const HEAD_COLOR := Color(1.0, 0.8, 0.2)
const ALERT_RADIUS := 15.0 ## Waking up wakes the others this close.
const LOOK_TIME := 0.25 ## Seconds between idle enemies looking around for players.
const PROP_SHOVE := 60.0 ## How hard it pushes props it walks into, per m/s of its speed.
const ARMS_REACH := 1.3 ## Melee: arms held out in front, reaching for you (radians up from hanging).

@export var max_health: float = 100.0
@export var move_speed: float = 3.8 ## Players run 4.4 and sprint 7.4: you can always outrun a grunt.
@export var attack_range: float = 22.0
@export var preferred_range: float = 10.0
@export var wind_up_time: float = 0.6
@export var burst_shots: int = 3
@export var burst_interval: float = 0.14
@export var recover_time: float = 1.4
@export var shot_damage: float = 7.0
@export var spread_deg: float = 2.0
@export var gravity: float = 19.0
@export var body_color: Color = Color(0.85, 0.35, 0.1)
@export var sight_range: float = 25.0 ## Idle: spots players this far away, in front of it (about 140 degrees).
@export var hear_range: float = 6.0 ## Idle: notices players this close, whichever way it's facing...
@export var crouch_hear_range: float = 1.5 ## ...or this close if they're crouched: sneak up behind one for a backstab.

@export_group("Melee")
@export var melee: bool = false ## Claws instead of a gun: runs you down and hits on contact (the gun settings above don't apply).
@export var melee_range: float = 1.4 ## Touching distance (centre to centre): you're hit the moment it gets this close.
@export var melee_damage: float = 18.0
@export var melee_knockback: float = 8.0 ## m/s you're thrown back.
@export var melee_recover: float = 0.8 ## Seconds before it can hit again.

## Host: awake and hunting. Set at spawn (Game.spawn_enemy); idle ones wake up as above.
var alerted := true

# Synced from the host.
var health: float = 100.0: set = _set_health
var dead: bool = false: set = _set_dead
var aiming: bool = false ## Winding up: the eye glows.
var net_position := Vector3.ZERO
var net_yaw: float = 0.0
var net_pitch: float = 0.0

var _state: State = State.CHASE
var _state_t := 0.0
var _shots_left := 0
var _target: Player
var _retarget_t := 0.0
var _pitch := 0.0
var _pivot: Node3D ## Visuals; tips over on death.
var _aim: Node3D ## Eye and gun, pitched to where it's aiming.
var _gun: Node3D
var _arms: Array[Node3D] = [] ## Melee: the two arms that swing.
var _body: Humanoid
var _body_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _bars: HealthBar3D
var _flash := 0.0
var _look_t := 0.0

@onready var agent: NavigationAgent3D = $Agent


func _init() -> void:
	add_child(_make_synchronizer())


func _ready() -> void:
	if multiplayer.is_server():
		health = max_health
		net_position = global_position
		net_yaw = rotation.y
	_build_visuals()


# --- Damage (any peer) -----------------------------------------------------------------

## Called by the WeaponManager of whoever hit it. Returns true if this hit kills it (as
## far as the shooter can tell; the host has the final say).
func take_damage(amount: float, headshot: bool, at: Vector3) -> bool:
	if dead:
		return false
	WeaponFx.damage_number(get_tree().current_scene, at, amount, HEAD_COLOR if headshot else Color.WHITE, headshot)
	var killed := health - amount <= 0.0
	if multiplayer.is_server():
		_apply_damage(amount)
	else:
		_apply_damage.rpc_id(1, amount)
		health = maxf(health - amount, 0.0) # Predicted; the host's value replaces it.
	return killed


@rpc("any_peer", "call_remote", "reliable")
func _apply_damage(amount: float) -> void:
	if not multiplayer.is_server() or dead:
		return
	health = maxf(health - amount, 0.0)
	var by := multiplayer.get_remote_sender_id()
	if by == 0:
		by = multiplayer.get_unique_id() # The host shot it.
	var shooter := Game.players.get_node_or_null(str(by)) as Player
	alert()
	if shooter != null and shooter.health.is_up():
		_target = shooter # Turn on whoever's shooting it.
		_retarget_t = 1.0
	if health <= 0.0:
		dead = true
		aiming = false
		# Its body becomes a physics corpse, knocked away from whoever killed it.
		var away := Vector3(0, 0, 1).rotated(Vector3.UP, rotation.y)
		if shooter != null:
			away = global_position - shooter.global_position
		away.y = 0.0
		var velocity_out := away.normalized() * clampf(6.0 + amount * 0.15, 6.0, 20.0) + Vector3.UP * 3.5
		Game.spawn_corpse(Transform3D(global_basis, global_position), body_color, velocity_out)
		await get_tree().create_timer(0.3).timeout
		queue_free() # Despawns for everyone.


# --- Host: behaviour ------------------------------------------------------------------

## Host: wake up, and wake the others nearby.
func alert() -> void:
	if alerted or dead:
		return
	alerted = true
	for e: Enemy in Game.enemies.get_children():
		if e != self and not e.alerted and e.global_position.distance_to(global_position) <= ALERT_RADIUS:
			e.alerted = true # Just these: no chain reaction across the whole map.


## Host: a loud noise at `pos` wakes every enemy within `radius`.
static func alert_near(pos: Vector3, radius: float) -> void:
	for e: Enemy in Game.enemies.get_children():
		if e.global_position.distance_to(pos) <= radius:
			e.alert()


## Idle: a player in sight (in front, nothing in the way) or right next to it.
func _notices_someone() -> bool:
	var fwd := -global_basis.z
	for p: Player in Game.players.get_children():
		if not p.health.is_up():
			continue
		var to := p.global_position - global_position
		var dist := to.length()
		if dist <= (crouch_hear_range if p.net_crouched else hear_range):
			return true
		if dist <= sight_range and Vector2(to.x, to.z).normalized().dot(Vector2(fwd.x, fwd.z).normalized()) > 0.35 \
				and _can_see(p):
			return true
	return false


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or dead:
		return
	if not alerted:
		velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		net_position = global_position
		_look_t -= delta
		if _look_t <= 0.0:
			_look_t = LOOK_TIME
			if _notices_someone():
				alert()
		return
	_retarget_t -= delta
	if _retarget_t <= 0.0 or not _is_valid_target(_target):
		_retarget_t = RETARGET_TIME
		_target = _nearest_target()
		if _target != null:
			agent.target_position = _target.global_position

	var sees := _target != null and _can_see(_target)
	var dist := global_position.distance_to(_target.global_position) if _target != null else INF
	_state_t += delta
	var move := _melee_brain(sees, dist) if melee else _ranged_brain(sees, dist)
	aiming = _state == State.WIND_UP or _state == State.FIRE

	velocity.x = move.x * move_speed
	velocity.z = move.z * move_speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	_shove_props()

	# Face the target while fighting, otherwise where it's walking.
	var look := Vector3.ZERO
	if _target != null and (sees or aiming):
		look = _target.global_position - global_position
		var to_chest := _target_point(_target) - (global_position + Vector3.UP * EYE_HEIGHT)
		_pitch = atan2(to_chest.y, Vector2(to_chest.x, to_chest.z).length())
	elif move != Vector3.ZERO:
		look = move
		_pitch = 0.0
	if Vector2(look.x, look.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), 1.0 - exp(-10.0 * delta))
	_aim.rotation.x = _pitch
	net_position = global_position
	net_yaw = rotation.y
	net_pitch = _pitch


## Gun: stop where it can see you, wind up, burst, close in a bit, repeat. Returns which
## way to walk.
func _ranged_brain(sees: bool, dist: float) -> Vector3:
	match _state:
		State.CHASE:
			if sees and dist <= attack_range:
				_set_state(State.WIND_UP)
			elif _target != null:
				return _path_direction()
		State.WIND_UP:
			if not sees:
				_set_state(State.CHASE)
			elif _state_t >= wind_up_time:
				_shots_left = burst_shots
				_set_state(State.FIRE)
				_state_t = burst_interval # First shot straight away.
		State.FIRE:
			if _state_t >= burst_interval:
				_state_t = 0.0
				if _target != null:
					_fire()
				_shots_left -= 1
				if _shots_left <= 0:
					_set_state(State.RECOVER)
		State.RECOVER:
			if _state_t >= recover_time:
				_set_state(State.CHASE)
			if _target != null and (not sees or dist > preferred_range):
				return _path_direction()
	return Vector3.ZERO


## Claws: run you down, and the moment it touches you (within melee_range) you're hit and
## knocked back. Then it needs melee_recover before it can hit again. Returns which way
## to walk: it never stops coming.
func _melee_brain(_sees: bool, _dist: float) -> Vector3:
	_state = State.CHASE
	if _state_t >= melee_recover:
		var hit := false
		for p: Player in Game.players.get_children():
			if p.health.is_up() and p.global_position.distance_to(global_position) <= melee_range:
				p.health.take_damage(melee_damage, global_position + Vector3.UP * EYE_HEIGHT, melee_knockback)
				hit = true
		if hit:
			_state_t = 0.0
			_swing_fx.rpc()
	return _path_direction() if _target != null else Vector3.ZERO


@rpc("authority", "call_local", "unreliable")
func _swing_fx() -> void:
	for i in _arms.size(): # Up over its head, chop down through you, back to reaching.
		var arm := _arms[i]
		var tw := create_tween()
		tw.tween_property(arm, "rotation:x", 2.7, 0.06).set_delay(i * 0.04)
		tw.tween_property(arm, "rotation:x", 0.1, 0.1)
		tw.tween_property(arm, "rotation:x", ARMS_REACH, 0.25)
	Sfx.play_at("melee_hit", global_position + Vector3.UP * 1.2, -16.0)


func _set_state(s: State) -> void:
	_state = s
	_state_t = 0.0


func _is_valid_target(p: Player) -> bool:
	return p != null and is_instance_valid(p) and p.health.is_up()


func _nearest_target() -> Player:
	var best: Player = null
	var best_dist := INF
	for p: Player in Game.players.get_children():
		if not p.health.is_up():
			continue
		var d := p.global_position.distance_squared_to(global_position)
		if d < best_dist:
			best = p
			best_dist = d
	return best


func _target_point(p: Player) -> Vector3:
	return p.global_position + Vector3.UP * (p.head.position.y * 0.8)


func _can_see(p: Player) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * EYE_HEIGHT, _target_point(p), SIGHT_MASK)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Unit direction along the navigation path (or straight at the target until the map's
## navigation is baked).
func _path_direction() -> Vector3:
	var next := _target.global_position
	if Game.nav_ready:
		if agent.is_navigation_finished():
			return Vector3.ZERO
		next = agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.05 else Vector3.ZERO


func _fire() -> void:
	var from := _muzzle()
	var dir := (_target_point(_target) - from).normalized()
	var spread := deg_to_rad(spread_deg)
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	dir = dir.rotated(dir.cross(Vector3.UP).normalized(), randf_range(-spread, spread))
	var end := from + dir * attack_range * 1.5
	var q := PhysicsRayQueryParameters3D.create(from, end, SHOT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var normal := Vector3.ZERO
	var kind := 0
	if not hit.is_empty():
		end = hit.position
		normal = hit.normal
		kind = 1
		if hit.collider is Player:
			kind = 2
			(hit.collider as Player).health.take_damage(shot_damage, global_position + Vector3.UP * EYE_HEIGHT)
	_shot_fx.rpc(from, end, normal, kind)


@rpc("authority", "call_local", "unreliable")
func _shot_fx(from: Vector3, to: Vector3, normal: Vector3, kind: int) -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	WeaponFx.tracer(world, from, to)
	if kind != 0:
		WeaponFx.impact(world, to, normal, kind == 1)
	Sfx.play_at("shot_enemy", from, -3.0)


func _muzzle() -> Vector3:
	return _gun.global_position - _gun.global_basis.z * 0.35


# --- Every peer: visuals ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not multiplayer.is_server() and not dead:
		var k := 1.0 - exp(-SMOOTHING * delta)
		if global_position.distance_to(net_position) > SNAP_DISTANCE:
			global_position = net_position
		else:
			global_position = global_position.lerp(net_position, k)
		rotation.y = lerp_angle(rotation.y, net_yaw, k)
		_aim.rotation.x = lerpf(_aim.rotation.x, net_pitch, k)
	var glow := 6.0 if aiming else 0.4
	_eye_mat.emission_energy_multiplier = lerpf(_eye_mat.emission_energy_multiplier, glow, 1.0 - exp(-12.0 * delta))
	if _flash > 0.0:
		_flash -= delta
		_body_mat.albedo_color = Color.WHITE if _flash > 0.0 else body_color


func _set_health(v: float) -> void:
	if v < health:
		_flash = 0.05
	health = v
	if _bars != null:
		_bars.set_fill(health / max_health)
		_bars.visible = not dead and health < max_health


## Host: barging through crates and bodies knocks them aside.
func _shove_props() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var prop := c.get_collider() as PhysicsProp
		if prop != null:
			prop.push(-c.get_normal() * move_speed * PROP_SHOVE * get_physics_process_delta_time(), c.get_position())


## Dead: the physics corpse (Game.spawn_corpse) takes over, so this body just vanishes.
func _set_dead(v: bool) -> void:
	if v == dead:
		return
	dead = v
	if not dead:
		return
	$Body.set_deferred("disabled", true)
	$Head.set_deferred("disabled", true)
	if _bars != null:
		_bars.visible = false
	if _pivot != null:
		_pivot.visible = false


func _make_synchronizer() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for prop: String in ["net_position", "net_yaw", "net_pitch", "health", "dead", "aiming"]:
		var path := NodePath(".:" + prop)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS \
				if prop.begins_with("net_") else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = config
	sync.replication_interval = 1.0 / SYNC_RATE
	sync.delta_interval = 1.0 / SYNC_RATE
	return sync


## Box-and-capsule body in body_color, a glowing eye, a gun, and a health bar.
func _build_visuals() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.12)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(1.0, 0.85, 0.3)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(1.0, 0.6, 0.1)
	_eye_mat.emission_energy_multiplier = 0.4

	# The body: legs, torso, head, arms (see Humanoid), walking as it moves.
	_body = Humanoid.new(body_color, 1.9)
	_body.arms_free = false
	_pivot.add_child(_body)
	_body_mat = _body.body_mat

	_aim = Node3D.new()
	_aim.position.y = EYE_HEIGHT
	_pivot.add_child(_aim)
	var eye := MeshInstance3D.new()
	var eye_mesh := BoxMesh.new()
	eye_mesh.size = Vector3(0.26, 0.07, 0.06)
	eye.mesh = eye_mesh
	eye.material_override = _eye_mat
	eye.position = Vector3(0.0, 0.02, -0.18)
	_aim.add_child(eye)
	if melee:
		# Arms reaching for you, each ending in a long claw; they chop down when it hits.
		for arm: Node3D in [_body.left_arm, _body.right_arm]:
			var claw := MeshInstance3D.new()
			var claw_mesh := BoxMesh.new()
			claw_mesh.size = Vector3(0.1, 0.45, 0.06)
			claw.mesh = claw_mesh
			claw.material_override = dark
			claw.position = Vector3(0.0, -0.8, 0.0)
			arm.add_child(claw)
			arm.rotation.x = ARMS_REACH
			_arms.append(arm)
	else:
		_body.left_arm.rotation.x = 1.35 # Holding the gun up.
		_body.right_arm.rotation.x = 1.45
		_body.left_arm.rotation.z = -0.35
		_gun = MeshInstance3D.new()
		var gun_mesh := BoxMesh.new()
		gun_mesh.size = Vector3(0.09, 0.12, 0.6)
		(_gun as MeshInstance3D).mesh = gun_mesh
		(_gun as MeshInstance3D).material_override = dark
		_gun.position = Vector3(0.3, -0.35, -0.4)
		_aim.add_child(_gun)

	_bars = HealthBar3D.new(Color(1.0, 0.35, 0.25), 0.7)
	_bars.position.y = 2.15
	_bars.visible = false
	add_child(_bars)
