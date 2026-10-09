class_name WeaponPickup
extends RigidBody3D
## A gun lying in the world. Look at it and press Interact (E) to pick it up.
## Walking over it with a free gun slot picks it up too (not for guns on a rack).
## Remembers what's in its magazine (spare rounds stay with whoever carried it: they're
## shared between guns, see WeaponManager.AMMO). A thrown gun damages the first target
## it hits hard enough.

const LAYER := 2 ## Physics layer for pickups: bullets and the player pass through them.
const THROW_HIT_SPEED := 4.0
const AUTO_PICKUP_DELAY := 1.0 ## Seconds before a gun you dropped or threw can be walked over and taken again.

@export var weapon: WeaponData
@export var mag: int = -1 ## -1 = full.

var thrower: WeaponManager ## Set while the gun is in flight after a throw.
var auto_pickup_delay := 0.0
var _speed := 0.0 ## Last tick's speed (contacts report after the bounce).

static var _world_mats := {}


func _ready() -> void:
	add_to_group("weapon_pickups")
	collision_layer = LAYER
	collision_mask = 1 | 8 | 16 | 32 # World, enemies, doors and props (a thrown gun can hit those).
	mass = 3.0
	if mag < 0:
		mag = weapon.mag_size
	_build_visual()
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


## Throws or drops a gun into the world.
static func spawn(parent: Node, data: WeaponData, ammo: int, at: Transform3D,
		velocity: Vector3, spin: Vector3, by: WeaponManager = null) -> WeaponPickup:
	var p := WeaponPickup.new()
	p.weapon = data
	p.mag = ammo
	p.thrower = by
	p.auto_pickup_delay = AUTO_PICKUP_DELAY
	parent.add_child(p)
	p.global_transform = at
	p.linear_velocity = velocity
	p.angular_velocity = spin
	return p


func _physics_process(delta: float) -> void:
	_speed = linear_velocity.length()
	auto_pickup_delay = maxf(auto_pickup_delay - delta, 0.0)


## Landed (not in flight) and not just dropped.
func can_auto_pickup() -> bool:
	return thrower == null and auto_pickup_delay <= 0.0


func _on_body_entered(body: Node) -> void:
	if thrower != null and is_instance_valid(thrower) and _speed >= THROW_HIT_SPEED:
		thrower.deal_damage(body, weapon.throw_damage, 2.0, global_position)
	thrower = null # Only the first impact counts.


## World copy of the viewmodel's Pivot/Gun, with normal materials (the viewmodel
## shader would draw it on top of everything) and a box collider around it.
func _build_visual() -> void:
	var model: Node = weapon.model_scene.instantiate()
	var gun: Node3D = model.get_node("Pivot/Gun")
	gun.get_parent().remove_child(gun)
	model.free()
	gun.transform = Transform3D.IDENTITY
	add_child(gun)
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in gun.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = world_material(mi.material_override)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var local: AABB = (gun.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb() \
				if mi.is_inside_tree() else mi.transform * mi.get_aabb()
		box = local if first else box.merge(local)
		first = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size.max(Vector3.ONE * 0.04)
	cs.shape = shape
	cs.position = box.get_center()
	add_child(cs)


static func world_material(m: Material) -> Material:
	var sm := m as ShaderMaterial
	if sm == null:
		return m
	if not _world_mats.has(sm):
		var w := StandardMaterial3D.new()
		w.albedo_color = sm.get_shader_parameter("albedo")
		var r: Variant = sm.get_shader_parameter("roughness")
		w.roughness = r if r != null else 0.6
		var mt: Variant = sm.get_shader_parameter("metallic")
		w.metallic = mt if mt != null else 0.0
		var e: Variant = sm.get_shader_parameter("emission")
		if e is Color and (e as Color) != Color.BLACK:
			w.emission_enabled = true
			w.emission = e
		_world_mats[sm] = w
	return _world_mats[sm]
