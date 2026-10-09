class_name SupplyCrate
extends Interactable
## A supply crate (the Firing Range has one): Interact fills your pouch with every heal
## and shield item, up to what you can carry. Never runs out. The host does the filling
## (PlayerHealth.request_supplies()).

var _label: Label3D


func _ready() -> void:
	super()
	focus_offset = Vector3(0.0, 0.7, 0.0)
	_build()


func get_prompt() -> String:
	return "TAKE HEALS AND SHIELDS"


func can_use(by: Player) -> bool:
	for k in PlayerHealth.HEALS.size():
		if by.health.can_carry(k):
			return true
	return false


func use(by: Player) -> void:
	by.health.request_supplies.rpc_id(1)
	Sfx.play("pickup", -2.0)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var by := cam.get_parent()
	while by != null and not (by is Player):
		by = by.get_parent()
	_label.modulate.a = 1.0 if by == null or can_use(by as Player) else 0.4


## A crate on a pallet, a red cross on each side, and a sign over it. Solid.
func _build() -> void:
	var white := flat_material(Color(0.9, 0.9, 0.88))
	var red := flat_material(Color(0.9, 0.12, 0.1), 1.2)
	var blue := flat_material(Color(0.35, 0.65, 1.0), 2.0)
	add_box(Vector3(1.3, 0.12, 0.9), Vector3(0, 0.06, 0), flat_material(Color(0.4, 0.3, 0.2)))
	add_box(Vector3(1.2, 0.8, 0.8), Vector3(0, 0.52, 0), white)
	for z: float in [-0.41, 0.41]:
		add_box(Vector3(0.5, 0.14, 0.02), Vector3(-0.25, 0.55, z), red, false)
		add_box(Vector3(0.14, 0.5, 0.02), Vector3(-0.25, 0.55, z), red, false)
		add_box(Vector3(0.3, 0.12, 0.02), Vector3(0.32, 0.55, z), blue, false) # A shield cell stencil.
	_label = Label3D.new()
	_label.text = "SUPPLIES"
	_label.font_size = 48
	_label.outline_size = 12
	_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_label.position = Vector3(0, 1.35, 0)
	add_child(_label)
