class_name ExtractionConsole
extends Interactable
## Starts the extraction once every breaker is on (see Expedition). Faces its -Z.

const LOCKED := Color(1.0, 0.25, 0.2)
const READY := Color(0.3, 0.8, 1.0)

var _screen: StandardMaterial3D
var _sign: Label3D


func _ready() -> void:
	super()
	focus_offset = Vector3(0.0, 1.1, 0.0)
	add_box(Vector3(1.2, 1.0, 0.8), Vector3(0.0, 0.5, 0.0), flat_material(Color(0.2, 0.22, 0.25)))
	_screen = flat_material(LOCKED, 2.0)
	var screen := add_box(Vector3(1.0, 0.6, 0.08), Vector3(0.0, 1.25, -0.1), _screen, false)
	screen.rotation.x = 0.5 # Leaning back, facing up at whoever's in front (-Z).
	_sign = add_sign("", 2.2)


func get_prompt() -> String:
	match Game.map_state.get("phase", ""):
		"extracting":
			return "EXTRACTION RUNNING"
		"powered":
			return "START EXTRACTION"
	var states: Array = Game.map_state.get("breakers", [])
	return "NO POWER (%d / %d BREAKERS ON)" % [states.count(true), states.size()]


func can_use(_by: Player) -> bool:
	return Game.map_state.get("phase", "") != "over"


func use(_by: Player) -> void:
	Game.request_action("extract")


func _process(_delta: float) -> void:
	var phase: String = Game.map_state.get("phase", "")
	var live := phase == "powered" or phase == "extracting"
	_screen.albedo_color = READY if live else LOCKED
	_screen.emission = _screen.albedo_color
	_sign.text = "EXTRACTION" if live else "NO POWER"
	_sign.modulate = _screen.albedo_color
