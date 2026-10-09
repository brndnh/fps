class_name MedkitPickup
extends Interactable
## A heal item left lying around an expedition: a syringe, a medkit or a trauma kit (`kind`,
## an index into PlayerHealth.HEALS). Interact takes it, if you've room for another of
## that kind. The Expedition places these at rooms' Supplies spots; which were taken is
## in Game.map_state.taken_medkits, so everyone sees them gone.

var index := -1 ## Set by the Expedition.
var kind := 1 ## Set by the Expedition, before it's added.

var _kit: Node3D
var _t := 0.0


func _ready() -> void:
	super()
	focus_offset = Vector3(0.0, 0.35, 0.0)
	reach = 2.2
	_kit = Node3D.new()
	add_child(_kit)
	_kit.position.y = 0.35
	var color: Color = PlayerHealth.HEALS[kind].color
	var red := flat_material(Color(0.9, 0.1, 0.1), 1.5)
	match kind:
		0: # Stim: a glowing syringe.
			_part(Vector3(0.07, 0.07, 0.34), flat_material(color, 2.5))
			_part(Vector3(0.02, 0.02, 0.48), flat_material(Color(0.95, 0.95, 0.95)))
		3, 4: # Shield cell / battery: a dark canister ringed with glowing bands.
			var s := 1.0 if kind == 3 else 1.5
			var glow := flat_material(color, 3.0)
			_part(Vector3(0.14, 0.28, 0.14) * s, flat_material(Color(0.12, 0.13, 0.16)))
			for y: float in [-0.07, 0.07]:
				var band := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.15, 0.04, 0.15) * s
				band.mesh = bm
				band.material_override = glow
				band.position.y = y * s
				_kit.add_child(band)
		_:
			var s := 1.0 if kind == 1 else 1.35
			_part(Vector3(0.5, 0.3, 0.35) * s, flat_material(Color(0.95, 0.95, 0.95) if kind == 1 else color))
			_part(Vector3(0.28, 0.32, 0.08) * s, red) # A red cross through it.
			_part(Vector3(0.08, 0.32, 0.28) * s, red)


func taken() -> bool:
	return index in (Game.map_state.get("taken_medkits", []) as Array)


func get_prompt() -> String:
	return "TAKE %s" % PlayerHealth.HEALS[kind].name


func can_use(by: Player) -> bool:
	return not taken() and by.health.can_carry(kind)


func use(_by: Player) -> void:
	Game.request_action("take_medkit", index)


func _process(delta: float) -> void:
	visible = not taken()
	_t += delta
	_kit.rotation.y = _t * 1.2
	_kit.position.y = 0.35 + sin(_t * 2.0) * 0.05


func _part(size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	_kit.add_child(m)
