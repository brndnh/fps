class_name WeaponFx
## One-shot visual effects: tracers, bullet impacts, muzzle flashes.
## Everything is built from primitive meshes so there are no assets to manage.

const TRACER_SPEED := 450.0 ## m/s
const TRACER_LENGTH := 3.5
const MAX_DECALS := 96

static var _decals: Array[Node3D] = []
static var _mat_tracer: StandardMaterial3D
static var _mat_decal: StandardMaterial3D
static var _mat_spark: StandardMaterial3D
static var _glow_tex: GradientTexture2D


static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 1.0:
		return
	var dir := (to - from) / dist
	var length := minf(TRACER_LENGTH, dist)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, length)
	mi.mesh = mesh
	mi.material_override = _tracer_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var start := from + dir * length * 0.5
	var end := to - dir * length * 0.5
	mi.global_transform = Transform3D(_basis_facing(dir), start)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", end, maxf(dist - length, 0.0) / TRACER_SPEED)
	tw.tween_callback(mi.queue_free)


## Floating damage number that drifts up and fades. Only the shooter sees these.
static func damage_number(parent: Node, at: Vector3, amount: float, color: Color, big: bool) -> void:
	var l := Label3D.new()
	l.text = str(roundi(amount))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0009
	l.font_size = 52 if big else 40
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.modulate = color
	l.render_priority = 20
	l.outline_render_priority = 19
	parent.add_child(l)
	var side := Vector3(randf_range(-0.25, 0.25), 0.0, 0.0)
	l.global_position = at + Vector3(0.0, 0.15, 0.0) + side
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0.0, 0.5, 0.0) + side, 0.7) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)


## Bullet hole + spark. Pass decal = false for things that move (targets).
static func impact(parent: Node, pos: Vector3, normal: Vector3, decal: bool = true) -> void:
	if decal:
		var hole := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 0.06
		hole.mesh = q
		hole.material_override = _decal_material()
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(hole)
		# QuadMesh faces +Z, so point +Z along the surface normal.
		hole.global_transform = Transform3D(_basis_facing(-normal), pos + normal * 0.004)
		hole.rotate_object_local(Vector3.FORWARD, randf() * TAU)
		_decals.append(hole)
		while _decals.size() > MAX_DECALS:
			var old: Node3D = _decals.pop_front()
			if is_instance_valid(old):
				old.queue_free()

	var spark := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2.ONE * 0.22
	spark.mesh = sq
	spark.material_override = _spark_material()
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(spark)
	spark.global_position = pos + normal * 0.03
	var tw := spark.create_tween()
	tw.tween_property(spark, "scale", Vector3.ONE * 0.1, 0.08)
	tw.tween_callback(spark.queue_free)


## Builds a hidden muzzle flash (cross of glow quads + light) under `muzzle`.
static func make_muzzle_flash(muzzle: Node3D, size: float) -> Node3D:
	var root := Node3D.new()
	root.name = "MuzzleFlash"
	muzzle.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 10
	mat.albedo_color = Color(1.0, 0.75, 0.4)
	mat.albedo_texture = _glow_texture()
	for i in 3:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.16, 0.06) * size if i < 2 else Vector2.ONE * 0.09 * size
		mi.mesh = q
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.z = PI * 0.5 * i
		root.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 2.5
	light.omni_range = 5.0
	light.position.z = -0.05
	root.add_child(light)
	root.visible = false
	return root


# --- Helpers --------------------------------------------------------------------

## Basis whose -Z points along dir.
static func _basis_facing(dir: Vector3) -> Basis:
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(dir, up)


static func _tracer_material() -> StandardMaterial3D:
	if _mat_tracer == null:
		_mat_tracer = StandardMaterial3D.new()
		_mat_tracer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_tracer.albedo_color = Color(1.0, 0.85, 0.5)
	return _mat_tracer


static func _decal_material() -> StandardMaterial3D:
	if _mat_decal == null:
		_mat_decal = StandardMaterial3D.new()
		_mat_decal.albedo_color = Color(0.03, 0.03, 0.03)
		_mat_decal.albedo_texture = _glow_texture()
		_mat_decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_decal.roughness = 1.0
	return _mat_decal


static func _spark_material() -> StandardMaterial3D:
	if _mat_spark == null:
		_mat_spark = StandardMaterial3D.new()
		_mat_spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_spark.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_spark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_spark.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_mat_spark.albedo_color = Color(1.0, 0.8, 0.45)
		_mat_spark.albedo_texture = _glow_texture()
	return _mat_spark


## Soft round dot: opaque centre fading to transparent at the edge.
static func _glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.8))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	return _glow_tex
