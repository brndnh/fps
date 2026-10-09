extends CanvasLayer
## The inventory (Tab, Apex style), on your own player. Tab or Esc closes it; you can keep
## moving while it's open, but not look around or shoot. Two pages, picked at the top:
##   Inventory:
##     Weapons: your two guns and your knife. Drag one gun onto the other (or press the
##       swap button) to swap their slots; right-click a gun (or DROP) to drop it.
##     Backpack: your heals and shields (click one to use it), self-revive kits, and spare
##       ammo by type (shared by every gun taking it; unlimited in the hub).
##   Squad: the lobby board, everyone's shield and health. The only page while you're
##     down or out.
## Built in code; reads the Player's PlayerHealth and WeaponManager.

const ACCENT := Color(0.35, 1.0, 0.45)
const DIM := Color(1, 1, 1, 0.45)
const PANEL_BG := Color(0.06, 0.07, 0.09, 0.92)
const CELL_BG := Color(1, 1, 1, 0.05)
const CELL := Vector2(118, 112)
const PAGES := ["INVENTORY", "SQUAD"]

var _player: Player
var _weapons: WeaponManager
var _open := false
var _page := 0
var _root: Control
var _pages: Array[Control] = []
var _page_buttons: Array[Button] = []
var _cells: Array = [] ## Backpack: [kind ("heal"/"ammo"/"kit"), key, panel, title, count, detail]
var _cards: Array = [] ## Weapon cards per slot: [panel, slot label, name, ammo tag, rounds, drop button]
var _knife_label: Label
var _hint: Label


func _ready() -> void:
	layer = 6
	_player = get_parent() as Player
	_weapons = _player.get_node_or_null("Weapons") as WeaponManager
	_build()
	_root.visible = false


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if _open or not event.is_action_pressed("inventory"):
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_set_open(true)
		get_viewport().set_input_as_handled()


## While open, the close keys go to us first (Esc closes this, not opens the pause menu).
func _input(event: InputEvent) -> void:
	if _open and (event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel")):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _open:
		return
	if PauseMenu.visible:
		_set_open(false)
		return
	_refresh()


func _set_open(on: bool) -> void:
	_open = on
	_root.visible = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().warp_mouse(get_viewport().get_visible_rect().size * 0.5)
		_refresh()
	elif not get_tree().paused and not PauseMenu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_page(i: int) -> void:
	_page = i
	for k in _pages.size():
		_pages[k].visible = k == i
		_page_buttons[k].button_pressed = k == i


# --- Refresh ------------------------------------------------------------------------

func _refresh() -> void:
	var h := _player.health
	# Down or out: nothing in your hands or pouch to use, so just the squad.
	_page_buttons[0].disabled = not h.is_up()
	if not h.is_up() and _page == 0:
		_show_page(1)
	if _page != 0:
		return
	for c: Array in _cells:
		var title: Label = c[3]
		var count: Label = c[4]
		var detail: Label = c[5]
		var panel: PanelContainer = c[2]
		var alpha := 1.0
		match c[0]:
			"heal":
				var k: int = c[1]
				var item: Dictionary = PlayerHealth.HEALS[k]
				count.text = "%d / %d" % [h.heals[k], int(item.carry)]
				var usable := h.can_heal_with(k)
				alpha = 1.0 if h.heals[k] > 0 else 0.4
				detail.text = "CLICK TO USE" if usable else ("FULL" if h.heals[k] > 0 else "NONE")
				detail.add_theme_color_override("font_color", ACCENT if usable else DIM)
			"ammo":
				var type: String = c[1]
				var info: Dictionary = WeaponManager.AMMO[type]
				if _weapons == null or _weapons.infinite_reserve:
					count.text = "∞"
					detail.text = "UNLIMITED HERE"
				else:
					var have: int = _weapons.ammo.get(type, 0)
					count.text = "%d / %d" % [have, int(info.carry)]
					detail.text = _guns_taking(type)
					alpha = 1.0 if have > 0 else 0.4
			"kit":
				count.text = "%d" % h.kits
				alpha = 1.0 if h.kits > 0 else 0.4
		title.modulate.a = alpha
		count.modulate.a = alpha
		panel.modulate.a = 0.6 + 0.4 * alpha
	for i in WeaponManager.GUN_SLOTS:
		_refresh_card(i)
	var knife := _weapons.get_slot_data(WeaponManager.MELEE_SLOT) if _weapons != null else null
	_knife_label.text = "3   %s" % (knife.display_name.to_upper() if knife != null else "NO KNIFE")


## Which of your guns take this ammo, e.g. "VANTA · HORNET".
func _guns_taking(type: String) -> String:
	var names := PackedStringArray()
	for i in WeaponManager.GUN_SLOTS:
		var d := _weapons.get_slot_data(i)
		if d != null and d.ammo_type == type:
			names.append(d.display_name.to_upper())
	return " · ".join(names) if not names.is_empty() else "—"


func _refresh_card(i: int) -> void:
	var card: Array = _cards[i]
	var d := _weapons.get_slot_data(i) if _weapons != null else null
	var name_label: Label = card[2]
	var tag: Label = card[3]
	var rounds: Label = card[4]
	var drop: Button = card[5]
	var panel: PanelContainer = card[0]
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	var held := _weapons != null and _weapons.get_selected_slot() == i
	style.border_color = Color(ACCENT, 0.8) if held else Color(1, 1, 1, 0.12)
	if d == null:
		name_label.text = "EMPTY"
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.modulate.a = 0.4
		tag.text = ""
		rounds.text = "Pick up a gun to fill this slot"
		drop.visible = false
		return
	name_label.text = d.display_name.to_upper()
	name_label.modulate.a = 1.0
	var info: Dictionary = WeaponManager.AMMO.get(d.ammo_type, {})
	tag.text = ("%s AMMO" % info.name) if not info.is_empty() else ""
	tag.add_theme_color_override("font_color", info.get("color", Color.WHITE))
	var spare := "∞" if _weapons.infinite_reserve else str(_weapons.ammo.get(d.ammo_type, 0))
	rounds.text = "MAG %d / %d    SPARE %s" % [_weapons.get_slot_mag(i), d.mag_size, spare]
	drop.visible = true


# --- Actions ------------------------------------------------------------------------

func _use_heal(k: int) -> void:
	if _player.heal_input == null or not _player.health.can_heal_with(k):
		return
	_set_open(false) # Apex style: you see it go on.
	_player.heal_input.use_heal(k)


func _swap() -> void:
	if _weapons != null:
		_weapons.swap_gun_slots()


func _drop(i: int) -> void:
	if _weapons != null:
		_weapons.drop_gun(i)


# --- Building ----------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)

	# The page tabs along the top.
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for i in PAGES.size():
		var b := Button.new()
		b.text = PAGES[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(180, 40)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_show_page.bind(i))
		tabs.add_child(b)
		_page_buttons.append(b)

	_pages.append(_build_inventory_page(v))
	_pages.append(_build_squad_page(v))

	_hint = _label("[%s] close   ·   Click a heal to use it   ·   Drag a gun onto the other to swap   ·   Right-click a gun to drop it" \
			% _key("inventory"), 15)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.7
	v.add_child(_hint)
	_show_page(0)


## Weapons on top, the backpack under them.
func _build_inventory_page(parent: Control) -> Control:
	var page := _panel(Vector2.ZERO)
	parent.add_child(page)
	var v := _vbox(page, 10)

	v.add_child(_heading("WEAPONS"))
	var guns := HBoxContainer.new()
	guns.add_theme_constant_override("separation", 8)
	v.add_child(guns)
	for i in WeaponManager.GUN_SLOTS:
		guns.add_child(_card(i))
		if i == 0:
			var swap := Button.new()
			swap.text = "⇄"
			swap.tooltip_text = "Swap slots"
			swap.focus_mode = Control.FOCUS_NONE
			swap.custom_minimum_size = Vector2(44, 0)
			swap.add_theme_font_size_override("font_size", 22)
			swap.pressed.connect(_swap)
			guns.add_child(swap)
	_knife_label = _label("", 16)
	_knife_label.modulate.a = 0.75
	v.add_child(_knife_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	v.add_child(_heading("BACKPACK"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for k in PlayerHealth.HEALS.size():
		var item: Dictionary = PlayerHealth.HEALS[k]
		var amount := (_player.get_node("Health") as PlayerHealth).describe(k) # (player.health isn't set yet: the player is ready after us.)
		var cell := _cell(grid, "heal", k, item.name, item.color, "%s · %ss" % [amount, str(item.time)])
		cell.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_use_heal(k))
	for type: String in WeaponManager.AMMO_ORDER:
		var info: Dictionary = WeaponManager.AMMO[type]
		_cell(grid, "ammo", type, "%s AMMO" % info.name, info.color, "")
	_cell(grid, "kit", 0, "SELF-REVIVE", Color(0.95, 0.8, 0.3), "Hold [%s] when down" % _key("interact"))
	return page


## The lobby board: everyone in the session, with their shield and health.
func _build_squad_page(parent: Control) -> Control:
	var page := _panel(Vector2(720, 0))
	parent.add_child(page)
	var v := _vbox(page, 10)
	v.add_child(_heading("SQUAD"))
	v.add_child(LobbyBoard.new())
	return page


func _cell(grid: GridContainer, kind: String, key: Variant, title_text: String, color: Color, detail_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CELL
	var style := StyleBoxFlat.new()
	style.bg_color = CELL_BG
	style.border_color = Color(color, 0.8)
	style.border_width_top = 4
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if kind == "heal":
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	grid.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var title := _label(title_text, 13)
	title.add_theme_color_override("font_color", color)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(title)
	if kind == "heal": # What it does under the title; the bottom line says whether you can use it.
		var amount := _label(detail_text, 11)
		amount.modulate.a = 0.7
		v.add_child(amount)
		detail_text = ""
	var count := _label("", 24)
	v.add_child(count)
	var detail := _label(detail_text, 11)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail.modulate.a = 0.75
	v.add_child(detail)
	_cells.append([kind, key, panel, title, count, detail])
	return panel


## A gun slot's card. Drag it onto the other card to swap them; right-click drops the gun.
func _card(i: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = CELL_BG
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_DRAG
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var slot_label := _label(str(i + 1), 22)
	slot_label.modulate.a = 0.5
	top.add_child(slot_label)
	var name_label := _label("", 22)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var drop := Button.new()
	drop.text = "DROP"
	drop.focus_mode = Control.FOCUS_NONE
	drop.pressed.connect(_drop.bind(i))
	top.add_child(drop)
	var tag := _label("", 13)
	v.add_child(tag)
	var rounds := _label("", 15)
	v.add_child(rounds)
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			_drop(i))
	panel.set_drag_forwarding(
		func(_at: Vector2) -> Variant:
			if _weapons == null or _weapons.get_slot_data(i) == null:
				return null
			var preview := _label(_weapons.get_slot_data(i).display_name.to_upper(), 22)
			preview.modulate.a = 0.8
			panel.set_drag_preview(preview)
			return {inventory_slot = i},
		func(_at: Vector2, data: Variant) -> bool:
			return data is Dictionary and (data as Dictionary).get("inventory_slot", -1) == 1 - i,
		func(_at: Vector2, _data: Variant) -> void:
			_swap())
	_cards.append([panel, slot_label, name_label, tag, rounds, drop])
	return panel


func _panel(min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _vbox(parent: Control, separation: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	parent.add_child(v)
	return v


func _heading(text: String) -> Label:
	var l := _label(text, 15)
	l.modulate.a = 0.6
	return l


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _key(action: String) -> String:
	return Settings.event_label(Settings.get_binding(action, 0))
