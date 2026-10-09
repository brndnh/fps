extends Area3D
## Floor area that hurts players standing in it (fire, acid, a broken reactor...).
## Builds its own trigger box and a red floor marking, so you only place it and set
## its size. Runs on the host, which owns everyone's health; downed players are safe.

const COLOR := Color(1.0, 0.25, 0.15)

@export var size: Vector3 = Vector3(5, 3, 5)
@export var damage_per_second: float = 25.0
@export var label: String = "HAZARD"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4 # Players.
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	_build_marking()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for body in get_overlapping_bodies():
		if body is Player:
			(body as Player).health.take_damage(damage_per_second * delta)


func _build_marking() -> void:
	var fill := StandardMaterial3D.new()
	fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.albedo_color = Color(COLOR, 0.25)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	plane.mesh = pm
	plane.material_override = fill
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.position.y = 0.015
	add_child(plane)

	var l := Label3D.new()
	l.text = label
	l.font_size = 120
	l.pixel_size = 0.01
	l.modulate = Color(COLOR, 0.8)
	l.outline_size = 0
	l.rotation_degrees = Vector3(-90, 180, 0)
	l.position = Vector3(0, 0.025, 0)
	add_child(l)
