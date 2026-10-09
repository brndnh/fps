class_name MapView
extends Control
## The full map (the map key, M): the whole level north up, with the fog of war, where
## everyone is and which way they're facing, and the map's markers (the way in, breakers,
## extraction) once the squad has uncovered them. The same key closes it; you can keep
## moving while it's up. Draws the radar's picture (see Radar), so it needs `radar`.

const MARGIN := 70.0
const ME := Color(0.35, 1.0, 0.45)

var radar: Radar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_menu") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible and PauseMenu.visible:
		visible = false
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.82))
	var font := ThemeDB.fallback_font
	_text(font, Vector2(size.x * 0.5, 40), "MAP    [%s] close" % Settings.event_label(Settings.get_binding("map_menu", 0)), 22, Color.WHITE)
	var tex := radar.get_map_texture() if radar != null else null
	if tex == null:
		_text(font, size * 0.5, "No map here", 22, Color(1, 1, 1, 0.6))
		return
	var world_size := Vector2(tex.get_size()) / radar.get_texels()
	var avail := size - Vector2.ONE * MARGIN * 2.0
	var scale := minf(avail.x / world_size.x, avail.y / world_size.y) # Screen pixels per metre.
	var top_left := (size - world_size * scale) * 0.5
	var origin := radar.get_origin()
	var to_screen := func(p: Vector3) -> Vector2:
		return top_left + (Vector2(p.x, p.z) - origin) * scale

	draw_set_transform(top_left, 0.0, Vector2.ONE * scale / radar.get_texels())
	draw_texture(tex, Vector2.ZERO)
	var fog := radar.get_fog_texture()
	if fog != null:
		draw_set_transform(top_left, 0.0, Vector2.ONE * scale / Radar.FOG_TEXELS_PER_METRE)
		draw_texture(fog, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(top_left, world_size * scale), Color(1, 1, 1, 0.25), false, 1.5)

	for l: Array in radar.get_labels():
		_text(font, to_screen.call(Vector3(l[1], 0.0, l[2])), String(l[0]), 26, Color(1.0, 0.85, 0.3))
	var level := get_tree().current_scene
	if level != null and level.has_method("get_map_markers"):
		for m: Array in level.get_map_markers():
			if not radar.is_revealed(m[1]):
				continue
			var at: Vector2 = to_screen.call(m[1])
			draw_circle(at, 7.0, Color(0, 0, 0, 0.8))
			draw_circle(at, 5.0, m[2])
			_text(font, at + Vector2(0, -16), m[0], 15, m[2])

	for p: Player in Game.players.get_children():
		if p.health.eliminated:
			continue
		var color: Color = ME if p.is_local else Player.COLORS[p.slot % Player.COLORS.size()]
		var at: Vector2 = to_screen.call(p.global_position)
		var fwd := Vector2(-sin(p.global_rotation.y), -cos(p.global_rotation.y)) # -Z is up on the map.
		var side := Vector2(-fwd.y, fwd.x)
		var arrow := PackedVector2Array([at + fwd * 11.0, at - fwd * 7.0 + side * 7.0, at - fwd * 3.0, at - fwd * 7.0 - side * 7.0])
		draw_colored_polygon(arrow, color)
		draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0, 0, 0, 0.8), 1.5)
		var label := "YOU" if p.is_local else Game.player_name(p.peer_id)
		if p.health.downed:
			label += " (DOWN)"
		_text(font, at + Vector2(0, 24), label, 14, color)


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := at + Vector2(-w * 0.5, font_size * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
