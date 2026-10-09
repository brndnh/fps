extends CanvasLayer
## CS:GO-style radial buy menu. Press B in a buy zone: pick a category, then an
## item. Point with the mouse (or press its number) and click. Right-click or
## Backspace goes back, B or Esc closes. You can keep moving while it's open.
## Everything is free.

const ACCENT := Color(0.35, 1.0, 0.45)
const INNER := 95.0
const OUTER := 270.0
const GAP := 0.025 ## Radians between wedges.

var _weapons: WeaponManager
var _wheel: Control
var _open := false
var _category := -1 ## -1 = showing the category ring.
var _hover := -1
var _categories: Array = [] ## [{name, items: Array[WeaponData]}]


func _ready() -> void:
	layer = 5
	_weapons = get_parent().get_node_or_null("Weapons")
	var knives: Array = Settings.KNIVES.map(func(k: Array) -> WeaponData: return load(k[2]))
	_categories = [
		{name = "Pistols", items = [load("res://weapons/sidearm.tres"), load("res://weapons/deagle.tres"),
				load("res://weapons/revolver.tres")]},
		{name = "SMGs", items = [load("res://weapons/smg.tres")]},
		{name = "Heavy", items = [load("res://weapons/shotgun.tres"), load("res://weapons/olympia.tres"), load("res://weapons/negev.tres")]},
		{name = "Rifles", items = [load("res://weapons/carbine.tres"), load("res://weapons/m4.tres"), load("res://weapons/ak47.tres")]},
		{name = "Snipers", items = [load("res://weapons/dmr.tres"), load("res://weapons/ssg.tres"), load("res://weapons/sniper.tres")]},
		{name = "Knives", items = knives},
	]
	_wheel = Control.new()
	_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.draw.connect(_draw_wheel)
	_wheel.visible = false
	add_child(_wheel)


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if _open or _weapons == null:
		return
	if event.is_action_pressed("buy_menu") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _weapons.can_buy():
		_set_open(true)
		get_viewport().set_input_as_handled()


## While open, grab clicks and menu keys before the game (or the pause menu) sees them.
## Movement keys pass through.
func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("buy_menu") or event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				_pick(_hover)
			MOUSE_BUTTON_RIGHT:
				_back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var code := (event as InputEventKey).physical_keycode
		if code >= KEY_1 and code <= KEY_9:
			var i := code - KEY_1
			if i < _labels().size():
				_pick(i)
			get_viewport().set_input_as_handled()
		elif code == KEY_BACKSPACE:
			_back()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _open:
		return
	if not _weapons.can_buy():
		_set_open(false)
		return
	var v := _wheel.get_local_mouse_position() - _wheel.size * 0.5
	var n := _labels().size()
	_hover = -1
	if v.length() > INNER * 0.5:
		var step := TAU / n
		_hover = int(round(wrapf(v.angle() + PI * 0.5, 0.0, TAU) / step)) % n
	_wheel.queue_redraw()


func _set_open(on: bool) -> void:
	_open = on
	_wheel.visible = on
	_category = -1
	_hover = -1
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().warp_mouse(get_viewport().get_visible_rect().size * 0.5)
	elif not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pick(i: int) -> void:
	if i < 0:
		return
	if _category < 0:
		_category = i
		_hover = -1
		Sfx.play("catch", -8.0)
		return
	var d: WeaponData = _categories[_category].items[i]
	_set_open(false)
	_weapons.buy(d)


func _back() -> void:
	if _category >= 0:
		_category = -1
		_hover = -1
	else:
		_set_open(false)


func _labels() -> Array:
	if _category < 0:
		return _categories.map(func(c: Dictionary) -> String: return c.name)
	return _categories[_category].items.map(func(d: WeaponData) -> String: return d.display_name)


# --- Drawing ------------------------------------------------------------------------

func _draw_wheel() -> void:
	var c := _wheel.size * 0.5
	var font := ThemeDB.fallback_font
	var labels := _labels()
	var n := labels.size()
	var step := TAU / n
	var mid_r := (INNER + OUTER) * 0.5
	_wheel.draw_circle(c, OUTER + 16.0, Color(0, 0, 0, 0.35))
	for i in n:
		var mid := -PI * 0.5 + i * step
		var a0 := mid - step * 0.5 + (GAP if n > 1 else 0.0)
		var a1 := mid + step * 0.5 - (GAP if n > 1 else 0.0)
		var col := Color(ACCENT, 0.32) if i == _hover else Color(0.1, 0.11, 0.13, 0.8)
		# A thick arc is a ring wedge.
		_wheel.draw_arc(c, mid_r, a0, a1, maxi(8, int((a1 - a0) / 0.05)), col, OUTER - INNER)

		var item: WeaponData = _categories[_category].items[i] if _category >= 0 else null
		var owned := item != null and _weapons.owns(item)
		var p := c + Vector2.from_angle(mid) * mid_r
		# Busy wheels (the knives) get smaller labels, with long names wrapped onto two lines.
		var font_size := 18 if n <= 6 else 13
		var label := String(labels[i]).to_upper()
		var lines := [label]
		if n > 6 and label.contains(" "):
			var cut := label.rfind(" ")
			lines = [label.substr(0, cut), label.substr(cut + 1)]
		var top := p - Vector2(0, (lines.size() - 1) * font_size * 0.6)
		for li in lines.size():
			var line: String = ("%d  " % (i + 1) if li == 0 and i < 9 else "") + String(lines[li])
			_text(font, top + Vector2(0, li * font_size * 1.2), line, font_size, ACCENT if owned else Color.WHITE)
		if owned:
			_text(font, top + Vector2(0, lines.size() * font_size * 1.2 + 4), "EQUIPPED" if item.is_melee else "OWNED · REFILL",
					11 if n > 6 else 12, Color(ACCENT, 0.8))

	_wheel.draw_circle(c, INNER - 8.0, Color(0.05, 0.06, 0.07, 0.9))
	var title := "BUY" if _category < 0 else String(_categories[_category].name).to_upper()
	_text(font, c + Vector2(0, -16), title, 22, ACCENT)
	var sub := "PICK A CATEGORY" if _category < 0 else "FREE"
	if _hover >= 0:
		sub = String(labels[_hover]).to_upper()
	_text(font, c + Vector2(0, 10), sub, 13, Color.WHITE)
	_text(font, c + Vector2(0, 30), "RMB BACK · B CLOSE", 10, Color(1, 1, 1, 0.5))


## Centered text with an outline.
func _text(font: Font, at: Vector2, s: String, size: int, color: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at + Vector2(-w * 0.5, size * 0.35)
	_wheel.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8))
	_wheel.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
