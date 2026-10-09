class_name PhysicsProp
extends RigidBody3D
## Something with real physics that anyone can shove around: crates, and the bodies of
## the dead (enemies, and players who bled out), which tumble away from whatever killed
## them. The host simulates it; everyone else's copy follows the synced position, frozen
## and kinematic, so you still bump into it. Shots, walking into it, enemies running into
## it and blasts all push it; a push on a client goes to the host.
##
## Spawned by Game.spawn_prop() with a description (setup()), on every peer. Props placed
## in maps come from PropSpawn markers. Physics layer 6 ("props").

enum Kind { CRATE, CORPSE }

const LAYER := 32
const MASK := 1 | 4 | 8 | 16 | 32 ## World, players, enemies, doors, other props.
const SYNC_RATE := 20.0
const SMOOTHING := 16.0
const SNAP_DISTANCE := 3.0
const PUSH_SEND_TIME := 0.05 ## Clients batch their pushes and send them this often.
const MAX_PUSH := 60.0 ## Biggest impulse (N s) the host accepts from one message.

var kind: Kind = Kind.CRATE
var size := Vector3.ONE ## Crates: the box. Corpses: x = radius, y = height.
var color := Color.WHITE
var lifetime := 0.0 ## Host: seconds until it's removed (0 = stays).

# Synced from the host.
var net_position := Vector3.ZERO
var net_rotation := Quaternion.IDENTITY

var _start_velocity := Vector3.ZERO
var _start_spin := Vector3.ZERO
var _push := Vector3.ZERO
var _push_at := Vector3.ZERO
var _push_t := 0.0


func _init() -> void:
	add_child(_make_synchronizer())


## Called by Game before it enters the tree, from the spawn data (the same on every peer).
func setup(data: Dictionary) -> void:
	kind = data.get("kind", Kind.CRATE)
	size = data.get("size", Vector3.ONE)
	color = data.get("color", Color(0.85, 0.55, 0.2))
	mass = data.get("mass", 20.0)
	lifetime = data.get("lifetime", 0.0)
	_start_velocity = data.get("velocity", Vector3.ZERO)
	_start_spin = data.get("spin", Vector3.ZERO)
	transform = data.get("transform", Transform3D.IDENTITY)
	net_position = transform.origin
	net_rotation = transform.basis.get_rotation_quaternion()


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = MASK
	angular_damp = 1.5 if kind == Kind.CORPSE else 0.5
	var surface := PhysicsMaterial.new()
	surface.friction = 0.6 # Slides when shoved, rather than sticking to the floor.
	physics_material_override = surface
	linear_damp = 0.3
	_build()
	if multiplayer.is_server():
		linear_velocity = _start_velocity
		angular_velocity = _start_spin
		if lifetime > 0.0:
			get_tree().create_timer(lifetime).timeout.connect(queue_free)
	else:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true


## Shove it: `impulse` (N s) at world point `at`.
func push(impulse: Vector3, at: Vector3) -> void:
	if multiplayer.is_server():
		apply_impulse(impulse, at - global_position)
		return
	_push += impulse
	_push_at = at


@rpc("any_peer", "call_remote", "unreliable")
func _receive_push(impulse: Vector3, at: Vector3) -> void:
	if multiplayer.is_server():
		apply_impulse(impulse.limit_length(MAX_PUSH), at - global_position)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		net_position = global_position
		net_rotation = global_basis.get_rotation_quaternion()
		return
	_push_t -= delta
	if _push != Vector3.ZERO and _push_t <= 0.0:
		_push_t = PUSH_SEND_TIME
		_receive_push.rpc_id(1, _push, _push_at)
		_push = Vector3.ZERO
	var k := 1.0 - exp(-SMOOTHING * delta)
	var pos := net_position if global_position.distance_to(net_position) > SNAP_DISTANCE \
			else global_position.lerp(net_position, k)
	var rot := global_basis.get_rotation_quaternion().slerp(net_rotation, k)
	global_transform = Transform3D(Basis(rot), pos)


func _make_synchronizer() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for prop: String in ["net_position", "net_rotation"]:
		var path := NodePath(".:" + prop)
		config.add_property(path)
		config.property_set_spawn(path, true)
		# Only while it's moving: a prop at rest sends nothing.
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = config
	sync.delta_interval = 1.0 / SYNC_RATE
	return sync


func _build() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var shape := CollisionShape3D.new()
	var mesh := MeshInstance3D.new()
	mesh.material_override = mat
	match kind:
		Kind.CRATE:
			var box := BoxShape3D.new()
			box.size = size
			shape.shape = box
			var bm := BoxMesh.new()
			bm.size = size
			mesh.mesh = bm
		Kind.CORPSE:
			# A limp body (see Humanoid) on a capsule, standing on its feet at the spawn;
			# the start velocity knocks it over.
			var capsule := CapsuleShape3D.new()
			capsule.radius = size.x
			capsule.height = size.y
			shape.shape = capsule
			shape.position.y = size.y * 0.5
			var body := Humanoid.new(color, size.y)
			body.animated = false
			body.left_arm.rotation.z = -0.5 # Arms flung out, legs apart.
			body.right_arm.rotation.z = 0.5
			body.left_leg.rotation.z = -0.15
			body.right_leg.rotation.z = 0.15
			add_child(body)
			center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
			center_of_mass = Vector3(0.0, size.y * 0.45, 0.0)
	add_child(shape)
	if mesh.mesh != null:
		add_child(mesh)
	else:
		mesh.free() # Bodies draw a Humanoid instead; don't leave this lying about.
