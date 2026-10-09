class_name ExtractionPad
extends Node3D
## Where you have to be standing when the extraction countdown ends (see Expedition).
## Builds its own floor marking; brighter while the extraction is running.

const COLOR := Color(0.3, 0.8, 1.0)

@export var size: Vector2 = Vector2(8, 8) ## Metres, x by z.

var _fill: StandardMaterial3D


func _ready() -> void:
	add_to_group("extraction_pads")
	_fill = StandardMaterial3D.new()
	_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill.albedo_color = Color(COLOR, 0.12)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	plane.mesh = pm
	plane.material_override = _fill
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.position.y = 0.02
	add_child(plane)
	var edge := StandardMaterial3D.new()
	edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge.albedo_color = COLOR
	var w := 0.12
	for e: Array in [[Vector2(size.x, w), Vector3(0, 0, size.y * 0.5)], [Vector2(size.x, w), Vector3(0, 0, -size.y * 0.5)],
			[Vector2(w, size.y), Vector3(size.x * 0.5, 0, 0)], [Vector2(w, size.y), Vector3(-size.x * 0.5, 0, 0)]]:
		var strip := MeshInstance3D.new()
		var sm := PlaneMesh.new()
		sm.size = e[0]
		strip.mesh = sm
		strip.material_override = edge
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strip.position = e[1] + Vector3(0, 0.03, 0)
		add_child(strip)
	var l := Label3D.new()
	l.text = "EXTRACTION"
	l.font_size = 120
	l.pixel_size = 0.01
	l.modulate = Color(COLOR, 0.6)
	l.outline_size = 0
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.position = Vector3(0, 0.04, 0)
	add_child(l)


## Is this world position on the pad?
func contains(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.y * 0.5 and l.y > -1.0 and l.y < 4.0


func _process(_delta: float) -> void:
	var running: bool = Game.map_state.get("phase", "") == "extracting"
	var pulse := 0.12 + (0.18 + 0.1 * sin(Time.get_ticks_msec() * 0.008) if running else 0.0)
	_fill.albedo_color = Color(COLOR, pulse)
