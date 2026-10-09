class_name HealthBar3D
extends Node3D
## A health bar floating in the world, over teammates and enemies. Turns to face the
## camera around the vertical axis, like the target dummies' bars.

const HEIGHT := 0.05

var _width: float
var _fill: MeshInstance3D
var _shield: MeshInstance3D ## A thinner bar above, for players' shields (made on first set_shield()).


func _init(color: Color = Color.WHITE, width: float = 0.7) -> void:
	_width = width
	_quad(Color(0, 0, 0, 0.6), Vector2(width + 0.03, HEIGHT + 0.03), -0.005)
	_fill = _quad(color, Vector2(width, HEIGHT), 0.0)


## 0..1. Shrinks from the right.
func set_fill(f: float) -> void:
	f = clampf(f, 0.001, 1.0)
	_fill.scale.x = f
	_fill.position.x = -_width * 0.5 * (1.0 - f)


## 0..1 of the shield bar above (made the first time). Hidden at 0.
func set_shield(f: float, color: Color) -> void:
	if _shield == null:
		_shield = _quad(color, Vector2(_width, HEIGHT * 0.6), 0.0)
		_shield.position.y = HEIGHT * 1.05
	(_shield.material_override as StandardMaterial3D).albedo_color = color
	_shield.visible = f > 0.0
	f = clampf(f, 0.001, 1.0)
	_shield.scale.x = f
	_shield.position.x = -_width * 0.5 * (1.0 - f)


func set_color(c: Color) -> void:
	(_fill.material_override as StandardMaterial3D).albedo_color = c


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_visible_in_tree():
		return
	var p := cam.global_position
	p.y = global_position.y
	if p.distance_squared_to(global_position) > 0.01:
		look_at(p, Vector3.UP, true)


func _quad(color: Color, size: Vector2, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.z = z
	add_child(mi)
	return mi
