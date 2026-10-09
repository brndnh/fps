class_name Breaker
extends Interactable
## Objective: a breaker panel in an objective room. Interact restores its power. Every
## breaker in the expedition has to be on before the extraction console works. Throwing
## one is loud: idle enemies nearby wake up and come for you (see Expedition).
## Faces its -Z (stand in front of that side to use it).

const OFF_COLOR := Color(1.0, 0.25, 0.2)
const ON_COLOR := Color(0.3, 1.0, 0.4)

var index := -1 ## Set by the Expedition: which entry in Game.map_state.breakers this is.

var _light: StandardMaterial3D
var _handle: Node3D
var _sign: Label3D


func _ready() -> void:
	super()
	focus_offset = Vector3(0.0, 1.3, 0.0)
	var dark := flat_material(Color(0.2, 0.22, 0.25))
	add_box(Vector3(1.4, 2.0, 0.35), Vector3(0.0, 1.0, 0.0), dark)
	_light = flat_material(OFF_COLOR, 3.0)
	add_box(Vector3(0.9, 0.12, 0.05), Vector3(0.0, 1.85, -0.2), _light, false)
	_handle = Node3D.new()
	_handle.position = Vector3(0.0, 1.2, -0.2)
	add_child(_handle)
	var stick := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.12, 0.5, 0.12)
	stick.mesh = sm
	stick.material_override = flat_material(Color(0.9, 0.75, 0.2))
	stick.position.y = 0.2
	_handle.add_child(stick)
	_sign = add_sign("", 2.5)


func is_on() -> bool:
	var states: Array = Game.map_state.get("breakers", [])
	return index >= 0 and index < states.size() and states[index]


func get_prompt() -> String:
	return "RESTORE POWER"


func can_use(_by: Player) -> bool:
	return not is_on()


func use(_by: Player) -> void:
	Game.request_action("breaker", index)


func _process(delta: float) -> void:
	var on := is_on()
	_light.albedo_color = ON_COLOR if on else OFF_COLOR
	_light.emission = _light.albedo_color
	_handle.rotation.x = lerpf(_handle.rotation.x, -2.4 if on else 0.0, 1.0 - exp(-10.0 * delta))
	_sign.text = "POWER ON" if on else "BREAKER"
	_sign.modulate = ON_COLOR if on else OFF_COLOR
