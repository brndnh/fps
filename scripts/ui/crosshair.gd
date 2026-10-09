extends Control
## Hipfire crosshair. The gap opens with the weapon's current spread (so it
## shows exactly where bullets can land), and it fades out while aiming.
## Hit markers: white = body, gold = head, red = kill. Tweak in the Inspector.

@export var color: Color = Color(0.35, 1.0, 0.45)
@export var gap: float = 3.0 ## Extra pixels on top of the spread.
@export var length: float = 7.0
@export var thickness: float = 2.0
@export var outline: bool = true

@export_group("Hit marker")
@export var marker_time: float = 0.18
@export var marker_size: float = 9.0
@export var head_color: Color = Color(1.0, 0.8, 0.2)
@export var kill_color: Color = Color(1.0, 0.25, 0.2)

var _weapons: WeaponManager
var _marker_t := 0.0
var _marker_color := Color.WHITE
var _marker_scale := 1.0


func _ready() -> void:
	_weapons = owner.get_node_or_null("Weapons") if owner != null else null
	if _weapons != null:
		_weapons.hit_confirmed.connect(_on_hit)


func _process(delta: float) -> void:
	_marker_t = maxf(_marker_t - delta, 0.0)
	queue_redraw()


func _on_hit(headshot: bool, killed: bool) -> void:
	_marker_t = marker_time * (1.6 if killed else 1.0)
	_marker_color = kill_color if killed else (head_color if headshot else Color.WHITE)
	_marker_scale = 1.4 if killed else 1.0


func _draw() -> void:
	var c := size * 0.5
	var alpha := 1.0
	var g := gap
	var gv := gap # Vertical gap: the same, except a line-spread shotgun's pellets only spread sideways.
	var cam := get_viewport().get_camera_3d()
	if _weapons != null and not _weapons.is_physics_processing():
		alpha = 0.0 # Downed or out: nothing in your hands.
	elif owner is Player and (owner as Player).superglide_wait() >= 0.0:
		alpha = 0.0 # The superglide cue (StatusHUD) is in its place.
	elif _weapons != null and cam != null:
		alpha = 1.0 - clampf(_weapons.ads * 2.0, 0.0, 1.0)
		# Spread cone (degrees) -> pixels. Camera FOV is vertical.
		var spread := deg_to_rad(_weapons.get_spread_deg())
		g += tan(spread) / tan(deg_to_rad(cam.fov) * 0.5) * size.y * 0.5
		gv += tan(deg_to_rad(_weapons.get_vertical_spread_deg())) / tan(deg_to_rad(cam.fov) * 0.5) * size.y * 0.5
	if alpha > 0.01:
		var col := Color(color, alpha)
		var out := Color(0, 0, 0, alpha)
		for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var dg := g if dir.y == 0.0 else gv
			var a: Vector2 = c + dir * dg
			var b: Vector2 = c + dir * (dg + length)
			if outline:
				draw_line(a - dir, b + dir, out, thickness + 2.0)
			draw_line(a, b, col, thickness)

	if _marker_t > 0.0:
		var t := _marker_t / marker_time
		var col := Color(_marker_color, clampf(t * 2.0, 0.0, 1.0))
		var inner := 5.0 * _marker_scale
		var outer := inner + marker_size * _marker_scale
		for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var d := dir.normalized()
			draw_line(c + d * inner, c + d * outer, Color(0, 0, 0, col.a * 0.7), 4.0)
			draw_line(c + d * inner, c + d * outer, col, 2.0)
