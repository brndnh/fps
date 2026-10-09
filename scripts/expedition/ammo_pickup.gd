class_name AmmoPickup
extends Interactable
## A box of one ammo type (`type`, a WeaponManager.AMMO key) left lying around an
## expedition. Interact takes it if you've room for more of that ammo; the host passes the
## rounds to you. The Expedition places these at rooms' Supplies spots; which were taken is
## in Game.map_state.taken_ammo, so everyone sees them gone.

var index := -1 ## Set by the Expedition.
var type := "light" ## Set by the Expedition, before it's added.

var _box: Node3D


func _ready() -> void:
	super()
	focus_offset = Vector3(0.0, 0.2, 0.0)
	reach = 2.2
	var info: Dictionary = WeaponManager.AMMO[type]
	_box = Node3D.new()
	add_child(_box)
	_box.position.y = 0.12
	_box.rotation.y = float(index) * 1.7 # Not all lined up the same way.
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.24, 0.26)
	body.mesh = bm
	body.material_override = flat_material(Color(0.22, 0.24, 0.2))
	_box.add_child(body)
	var band := MeshInstance3D.new() # The ammo type's colour, glowing round the middle.
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.43, 0.06, 0.27)
	band.mesh = band_mesh
	band.material_override = flat_material(info.color, 2.0)
	_box.add_child(band)


func taken() -> bool:
	return index in (Game.map_state.get("taken_ammo", []) as Array)


func get_prompt() -> String:
	var info: Dictionary = WeaponManager.AMMO[type]
	return "TAKE %s AMMO (%d)" % [info.name, int(info.box)]


func can_use(by: Player) -> bool:
	var w := by.get_node_or_null("Weapons") as WeaponManager
	return not taken() and w != null and w.can_take_ammo(type)


func use(_by: Player) -> void:
	Game.request_action("take_ammo", index)


func _process(_delta: float) -> void:
	visible = not taken()
