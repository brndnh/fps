class_name EnemyLever
extends Interactable
## Lever that turns the test enemies on and off for everyone (Game.enemies_enabled).
## Anyone can pull it; the host does the switching. Enemies are off whenever a map
## (re)starts, so the lever starts in the off position.

const HANDLE_ANGLE := 0.7 ## Radians either side of upright: back = off, forward = on.
const ON_COLOR := Color(1.0, 0.3, 0.2)
const OFF_COLOR := Color(0.6, 0.6, 0.6)

var _handle: Node3D
var _knob_mat: StandardMaterial3D
var _label: Label3D


func _ready() -> void:
	super()
	focus_offset = Vector3(0.0, 1.1, 0.0)
	_build()
	Game.enemies_switched.connect(_on_switched)


func _on_switched(_on: bool) -> void:
	if is_inside_tree(): # Not while its map is being swapped out.
		Sfx.play_at("slide_home", get_focus(), 0.0)


func get_prompt() -> String:
	return "TURN ENEMIES OFF" if Game.enemies_enabled else "TURN ENEMIES ON"


func use(_by: Player) -> void:
	Game.request_enemies.rpc_id(1, not Game.enemies_enabled)


func _process(delta: float) -> void:
	var on := Game.enemies_enabled
	_handle.rotation.x = lerpf(_handle.rotation.x, -HANDLE_ANGLE if on else HANDLE_ANGLE, 1.0 - exp(-12.0 * delta))
	_label.text = "ENEMIES: ON" if on else "ENEMIES: OFF"
	_label.modulate = ON_COLOR if on else OFF_COLOR
	_knob_mat.albedo_color = ON_COLOR if on else OFF_COLOR


## A post with a slot on top, a handle with a knob, and a sign. The post is solid.
func _build() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.15, 0.15, 0.17)
	_knob_mat = StandardMaterial3D.new()
	_knob_mat.albedo_color = OFF_COLOR

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.9, 0.3)
	shape.shape = box
	shape.position.y = 0.45
	body.add_child(shape)
	add_child(body)
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = box.size
	post.mesh = post_mesh
	post.material_override = dark
	post.position.y = 0.45
	add_child(post)

	_handle = Node3D.new()
	_handle.position.y = 0.9
	_handle.rotation.x = HANDLE_ANGLE
	add_child(_handle)
	var stick := MeshInstance3D.new()
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.025
	stick_mesh.bottom_radius = 0.025
	stick_mesh.height = 0.45
	stick.mesh = stick_mesh
	stick.material_override = dark
	stick.position.y = 0.225
	_handle.add_child(stick)
	var knob := MeshInstance3D.new()
	var knob_mesh := SphereMesh.new()
	knob_mesh.radius = 0.07
	knob_mesh.height = 0.14
	knob.mesh = knob_mesh
	knob.material_override = _knob_mat
	knob.position.y = 0.46
	_handle.add_child(knob)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.pixel_size = 0.006
	_label.outline_size = 10
	_label.position.y = 1.75
	add_child(_label)
