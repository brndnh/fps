extends CanvasLayer
## Ammo counter (underlined in its ammo type's colour) with the weapon slots under it (stacked
## down the right, CS2 style: name and key, the one in your hands lit), reload bar, pickup
## prompt, the sniper scope and the radar.
## Built in code; reads the WeaponManager every frame.

const ACCENT := Color(0.35, 1.0, 0.45)
const LOW_AMMO := Color(1.0, 0.35, 0.3)
const DIM := Color(1, 1, 1, 0.4)

var _weapons: WeaponManager
var _slots: Array[Label] = [] ## Each slot's name and key.
var _underline: ColorRect ## Under the ammo count, in the ammo type's colour.
var _mag: Label
var _reserve: Label
var _mode: Label ## Fire mode (SEMI / BURST) on guns that can switch.
var _hint: Label
var _prompt: Label
var _buy: Label
var _ammo_row: HBoxContainer
var _box: VBoxContainer
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _scope: Control


func _ready() -> void:
	_weapons = get_parent().get_node_or_null("Weapons")
	_build()


func _process(_delta: float) -> void:
	var armed := _weapons != null and _weapons.is_physics_processing()
	_box.visible = armed # Downed or out: no weapons to show.
	if not armed:
		for c: Control in [_scope, _prompt, _buy, _bar_bg, _hint]:
			c.visible = false
		return
	var d := _weapons.data()
	var scoped := _weapons.is_scoped()
	if scoped != _scope.visible:
		_scope.visible = scoped
		_scope.queue_redraw()
	var selected := _weapons.get_selected_slot()
	var names := _weapons.get_slot_names()
	for i in _slots.size():
		_slots[i].text = "%s   %d" % [names[i].to_upper() if names[i] != "" else "—", i + 1]
		_slots[i].add_theme_color_override("font_color", Color.WHITE if i == selected else DIM)
		_slots[i].add_theme_font_size_override("font_size", 22 if i == selected else 17)
	_underline.color = WeaponManager.ammo_color(d)
	var menu := get_parent().get_node_or_null("BuyMenu")
	_buy.visible = _weapons.can_buy() and not (menu != null and menu.is_open())
	_buy.text = "[%s]  BUY" % Settings.event_label(Settings.get_binding("buy_menu", 0))

	var p := _weapons.get_pickup_candidate()
	_prompt.visible = p != null
	if p != null:
		var verb := "PICK UP" if _weapons.has_free_gun_slot() else "SWAP FOR"
		_prompt.text = "[%s]  %s %s" % [Settings.event_label(Settings.get_binding("interact", 0)), verb, p.weapon.display_name.to_upper()]

	_ammo_row.visible = not d.is_melee
	if d.is_melee:
		_bar_bg.visible = false
		_hint.visible = false
		return
	var mag := _weapons.get_mag()
	var low := mag <= ceili(d.mag_size * 0.25)
	_mag.text = str(mag)
	_mag.add_theme_color_override("font_color", LOW_AMMO if low else Color.WHITE)
	var reserve := _weapons.get_reserve()
	_reserve.text = "/ ∞" if reserve < 0 else "/ %d" % reserve
	_mode.text = _weapons.get_fire_mode_name()
	_mode.visible = _mode.text != ""

	var reloading := _weapons.is_reloading()
	_bar_bg.visible = reloading
	if reloading:
		_bar_fill.size.x = _bar_bg.size.x * _weapons.get_reload_progress()
	_hint.visible = low and not reloading
	_hint.text = "NO AMMO" if mag == 0 else "RELOAD  [%s]" % Settings.event_label(Settings.get_binding("reload", 0))


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Scope first, so the ammo and prompts draw over it.
	_scope = Control.new()
	_scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.visible = false
	_scope.draw.connect(_draw_scope)
	_scope.resized.connect(_scope.queue_redraw)
	root.add_child(_scope)

	var radar := Radar.new()
	root.add_child(radar)
	var map := MapView.new() # The full map (M).
	map.radar = radar
	root.add_child(map)

	var box := VBoxContainer.new()
	_box = box
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.position = Vector2(-40, -36)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 2)
	root.add_child(box)

	var ammo := HBoxContainer.new()
	_ammo_row = ammo
	ammo.alignment = BoxContainer.ALIGNMENT_END
	ammo.add_theme_constant_override("separation", 8)
	box.add_child(ammo)
	var mag_col := VBoxContainer.new() # The count with its ammo-colour underline.
	mag_col.add_theme_constant_override("separation", 0)
	ammo.add_child(mag_col)
	_mag = _label("0", 64)
	mag_col.add_child(_mag)
	_underline = ColorRect.new()
	_underline.custom_minimum_size = Vector2(0, 5)
	_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mag_col.add_child(_underline)
	_reserve = _label("/ 0", 28)
	_reserve.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_reserve.size_flags_vertical = Control.SIZE_SHRINK_END
	ammo.add_child(_reserve)
	_mode = _label("", 16)
	_mode.add_theme_color_override("font_color", ACCENT)
	_mode.size_flags_vertical = Control.SIZE_SHRINK_END
	ammo.add_child(_mode)

	var slots := VBoxContainer.new() # Under the ammo.
	slots.alignment = BoxContainer.ALIGNMENT_END
	slots.add_theme_constant_override("separation", 4)
	box.add_child(slots)
	for i in 3:
		var l := _label("", 17)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slots.add_child(l)
		_slots.append(l)

	# Reload bar + hint, just under the crosshair.
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0, 0, 0, 0.5)
	_bar_bg.set_anchors_preset(Control.PRESET_CENTER)
	_bar_bg.size = Vector2(120, 5)
	_bar_bg.position = Vector2(-60, 46)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color.WHITE
	_bar_fill.size = Vector2(0, 5)
	_bar_bg.add_child(_bar_fill)

	_hint = _label("RELOAD", 18)
	_hint.set_anchors_preset(Control.PRESET_CENTER)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(240, 30)
	_hint.position = Vector2(-120, 40)
	_hint.add_theme_color_override("font_color", LOW_AMMO)
	root.add_child(_hint)

	_buy = _label("", 20)
	_buy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_buy.position = Vector2(40, -160) # Above the health (StatusHUD).
	_buy.add_theme_color_override("font_color", ACCENT)
	root.add_child(_buy)

	_prompt = _label("", 20)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(400, 30)
	_prompt.position = Vector2(-200, 90)
	root.add_child(_prompt)


## Full-screen scope: black outside a circle, fine crosshair that thickens toward the edge.
func _draw_scope() -> void:
	var size := _scope.size
	var c := size * 0.5
	var r := size.y * 0.46
	var black := Color(0, 0, 0)
	var cover := size.length() # Thick enough to reach every corner.
	_scope.draw_arc(c, r + cover * 0.5, 0.0, TAU, 128, black, cover)
	_scope.draw_arc(c, r, 0.0, TAU, 128, Color(0, 0, 0, 0.6), 6.0)
	var line := Color(0, 0, 0, 0.9)
	_scope.draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), line, 1.0)
	_scope.draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), line, 1.0)
	var thick := r * 0.55
	for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		_scope.draw_line(c + dir * thick, c + dir * r, black, 4.0)
	_scope.draw_circle(c, 1.5, Color(1.0, 0.25, 0.2))


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
