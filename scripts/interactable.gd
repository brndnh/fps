class_name Interactable
extends Node3D
## Something players use with Interact (E) when they're within reach and looking at it.
## Extend it and override get_prompt() and use(). use() runs on the machine of the
## player who pressed it, so anything that changes shared state has to ask the host.

@export var reach: float = 2.5 ## Metres from your eyes to get_focus().
@export var focus_offset: Vector3 = Vector3(0, 1.0, 0) ## The point you look at, from this node.


func _ready() -> void:
	add_to_group("interactables")


## Text after the key in the prompt, e.g. "PULL LEVER".
func get_prompt() -> String:
	return "USE"


func can_use(_by: Player) -> bool:
	return true


func use(_by: Player) -> void:
	pass


func get_focus() -> Vector3:
	return global_transform * focus_offset


## Greybox helper for building the visuals in code: a box of `size` centred at `pos`
## (local), solid unless told otherwise. Returns the mesh.
func add_box(size: Vector3, pos: Vector3, material: Material, solid: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		body.position = pos
		add_child(body)
	return mesh


static func flat_material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m


## A floating sign over the thing.
func add_sign(text: String, height: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 44
	l.pixel_size = 0.006
	l.outline_size = 10
	l.position.y = height
	add_child(l)
	return l
