extends Area3D
## Area where the buy menu (B) works. Builds its own trigger box and a
## translucent floor marking, so you only place it and set its size.

const COLOR := Color(0.35, 1.0, 0.45)

@export var size: Vector3 = Vector3(10, 4, 10)
@export var label: String = "BUY ZONE"
@export var flip_label: bool = false ## The floor text reads facing -Z; flip it to read facing +Z.


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	_build_marking()
	body_entered.connect(_on_body.bind(1))
	body_exited.connect(_on_body.bind(-1))


func _on_body(body: Node, delta: int) -> void:
	var w := body.get_node_or_null("Weapons") as WeaponManager
	if w != null:
		w.buy_zones += delta


func _build_marking() -> void:
	var fill := StandardMaterial3D.new()
	fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.albedo_color = Color(COLOR, 0.035)
	var edge := fill.duplicate() as StandardMaterial3D
	edge.albedo_color = Color(COLOR, 0.45)

	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	plane.mesh = pm
	plane.material_override = fill
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.position.y = 0.015
	add_child(plane)

	# Border strips along the four edges.
	var w := 0.08
	for e: Array in [[Vector2(size.x, w), Vector3(0, 0, size.z * 0.5)], [Vector2(size.x, w), Vector3(0, 0, -size.z * 0.5)],
			[Vector2(w, size.z), Vector3(size.x * 0.5, 0, 0)], [Vector2(w, size.z), Vector3(-size.x * 0.5, 0, 0)]]:
		var strip := MeshInstance3D.new()
		var sm := PlaneMesh.new()
		sm.size = e[0]
		strip.mesh = sm
		strip.material_override = edge
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strip.position = e[1] + Vector3(0, 0.02, 0)
		add_child(strip)

	var l := Label3D.new()
	l.text = label
	l.font_size = 160
	l.pixel_size = 0.01
	l.modulate = Color(COLOR, 0.35)
	l.outline_size = 0
	l.rotation_degrees = Vector3(-90, 180 if flip_label else 0, 0)
	l.position = Vector3(0, 0.025, size.z * 0.5 - 1.0)
	add_child(l)
