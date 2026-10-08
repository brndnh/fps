class_name Radar
extends Control
## CS-style radar in the top-left corner. It rotates with you (your facing is always
## up) and shows target dummies as red dots, plus any letters the map names in its
## "radar_labels" meta ([[text, x, z], ...], e.g. the bombsites).
## The map picture is the level's own when it has one (metadata "radar_image", a picture
## of "radar_rect" in world x/z, like Dust II's). Otherwise it's drawn when the level
## loads, from its collision boxes seen from above: floor is light, raised floors and
## crates are shades of tan, buildings are dark. Slabs hanging in the air are skipped.

const SIZE := 230.0 ## Pixels.
const PIXELS_PER_METRE := 3.2 ## On screen. 3.2 shows about 36 m each way.
const TEXELS_PER_METRE := 4.0 ## Resolution of the map picture.
const FLOOR := Color(0.55, 0.52, 0.45)
const RAISED := Color(0.7, 0.66, 0.56)
const CRATE := Color(0.42, 0.38, 0.32)
const WALL := Color(0.07, 0.07, 0.08, 0.9)

var _player: Player
var _map: Texture2D
var _origin := Vector2.ZERO ## World (x, z) of the picture's top-left corner.
var _texels := TEXELS_PER_METRE ## Picture pixels per metre.
var _labels: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(16, 16)
	size = Vector2(SIZE, SIZE)
	clip_contents = true
	var n := get_parent()
	while n != null and not (n is Player):
		n = n.get_parent()
	_player = n as Player
	_build.call_deferred() # After the level's nodes are all in.


func _process(_delta: float) -> void:
	queue_redraw()


func _build() -> void:
	var level := get_tree().current_scene
	if level == null:
		return
	_labels = level.get_meta("radar_labels", [])
	if level.has_meta("radar_image"):
		_map = load(level.get_meta("radar_image"))
		var rect: Rect2 = level.get_meta("radar_rect")
		_origin = rect.position
		_texels = _map.get_width() / rect.size.x
		return
	var boxes: Array = [] # [Rect2 in world x/z, top]
	var bounds := Rect2()
	for body: Node in level.find_children("*", "StaticBody3D", true, false):
		if _in_targets(body):
			continue
		for cs: Node in body.get_children():
			var aabb := _shape_aabb(cs as CollisionShape3D)
			if aabb.size == Vector3.ZERO or aabb.position.y > 2.0: # Floating: roofs, not floors.
				continue
			var r := Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z)
			boxes.append([r, aabb.end.y])
			bounds = r if bounds.size == Vector2.ZERO else bounds.merge(r)
	if boxes.is_empty():
		return
	_origin = bounds.position
	var w := clampi(ceili(bounds.size.x * TEXELS_PER_METRE), 1, 2048)
	var h := clampi(ceili(bounds.size.y * TEXELS_PER_METRE), 1, 2048)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	# Lowest first, so taller things paint over what's under them.
	boxes.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	for b: Array in boxes:
		var r: Rect2 = b[0]
		var top: float = b[1]
		var col := FLOOR if top <= 0.3 else (WALL if top > 3.2 else (RAISED if r.get_area() > 12.0 else CRATE))
		var px := Rect2i(Vector2i(((r.position - _origin) * TEXELS_PER_METRE).floor()),
				Vector2i((r.size * TEXELS_PER_METRE).ceil()))
		img.fill_rect(px, col)
	_map = ImageTexture.create_from_image(img)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	if _player == null:
		return
	var c := size * 0.5
	var me := Vector2(_player.global_position.x, _player.global_position.z)
	var yaw := _player.global_rotation.y
	# World (x, z) -> radar: around you, turned so your facing points up.
	var to_radar := func(p: Vector2) -> Vector2:
		return c + ((p - me) * PIXELS_PER_METRE).rotated(yaw)
	if _map != null:
		var s := PIXELS_PER_METRE / _texels
		draw_set_transform(c, yaw, Vector2(s, s))
		draw_texture(_map, (_origin - me) * _texels)
		draw_set_transform(Vector2.ZERO)
	var font := ThemeDB.fallback_font
	for l: Array in _labels:
		var p: Vector2 = to_radar.call(Vector2(l[1], l[2]))
		var t := String(l[0])
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string_outline(font, p + Vector2(-tw * 0.5, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(0, 0, 0, 0.8))
		draw_string(font, p + Vector2(-tw * 0.5, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.3))
	for t: Node in get_tree().get_nodes_in_group("targets"):
		var t3 := t as Node3D
		if t3 == null:
			continue
		var p: Vector2 = to_radar.call(Vector2(t3.global_position.x, t3.global_position.z))
		var dead: bool = t.get("dead") == true
		draw_circle(p, 3.5, Color(0, 0, 0, 0.7))
		draw_circle(p, 2.5, Color(1, 0.25, 0.2, 0.35 if dead else 1.0))
	# You: an arrow pointing up.
	var arrow := PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 6), c + Vector2(0, 3), c + Vector2(-6, 6)])
	draw_colored_polygon(arrow, Color(0.35, 1.0, 0.45))
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0, 0, 0, 0.8), 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.25), false, 1.5)


func _in_targets(n: Node) -> bool:
	while n != null:
		if n.is_in_group("targets"):
			return true
		n = n.get_parent()
	return false


func _shape_aabb(cs: CollisionShape3D) -> AABB:
	if cs == null or cs.shape == null or cs.disabled:
		return AABB()
	var local := AABB()
	if cs.shape is BoxShape3D:
		var e: Vector3 = (cs.shape as BoxShape3D).size
		local = AABB(-e * 0.5, e)
	elif cs.shape is ConvexPolygonShape3D:
		var pts := (cs.shape as ConvexPolygonShape3D).points
		if pts.is_empty():
			return AABB()
		local = AABB(pts[0], Vector3.ZERO)
		for p in pts:
			local = local.expand(p)
	else:
		return AABB()
	return cs.global_transform * local
