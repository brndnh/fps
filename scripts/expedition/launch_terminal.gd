class_name LaunchTerminal
extends Interactable
## In the hub: starts a new expedition (a freshly generated Research Complex) for
## everyone. Anyone can use it; the host does the launching. Faces its -Z.

const COLOR := Color(0.3, 0.8, 1.0)


func _ready() -> void:
	super()
	focus_offset = Vector3(0.0, 1.1, 0.0)
	add_box(Vector3(1.4, 1.0, 0.8), Vector3(0.0, 0.5, 0.0), flat_material(Color(0.2, 0.22, 0.25)))
	var screen := add_box(Vector3(1.2, 0.7, 0.08), Vector3(0.0, 1.3, -0.1), flat_material(COLOR, 2.0), false)
	screen.rotation.x = 0.5 # Leaning back, facing up at whoever's in front (-Z).
	var label := add_sign("EXPEDITION", 2.3)
	label.modulate = COLOR


func get_prompt() -> String:
	return "START EXPEDITION: RESEARCH COMPLEX"


func use(_by: Player) -> void:
	Game.request_expedition.rpc_id(1)
