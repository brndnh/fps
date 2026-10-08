extends CanvasLayer
## Pause menu + Settings screen (autoload "PauseMenu"). Esc opens/closes it.
## Built in code so it works in every level without being added to scenes.

const ACCENT := Color(0.35, 1.0, 0.45)

var _root: Control
var _main_panel: Control
var _settings_panel: Control
var _sens_slider: HSlider
var _sens_spin: SpinBox
var _invert_check: CheckButton
var _fov_slider: HSlider
var _fov_value: Label
var _crouch_mode: OptionButton
var _sprint_mode: OptionButton
var _aim_mode: OptionButton
var _ads_slider: HSlider
var _ads_value: Label
var _bind_buttons := {} # "action:slot" -> Button

var _listening := false
var _listen_action := ""
var _listen_slot := 0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	Settings.changed.connect(_refresh)
	_refresh()
	visible = false


# --- Open / close -------------------------------------------------------------

func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_main()


func resume() -> void:
	_cancel_listen()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_main() -> void:
	_cancel_listen()
	_main_panel.visible = true
	_settings_panel.visible = false


func _show_settings() -> void:
	_main_panel.visible = false
	_settings_panel.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not visible:
			open()
		elif _settings_panel.visible:
			_show_main()
		else:
			resume()
		get_viewport().set_input_as_handled()
	elif not visible and event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Clicking back into the window (e.g. after alt-tab) recaptures the mouse.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


# --- Rebinding ----------------------------------------------------------------

func _start_listen(action: String, slot: int) -> void:
	_cancel_listen()
	_listening = true
	_listen_action = action
	_listen_slot = slot
	var b: Button = _bind_buttons["%s:%d" % [action, slot]]
	b.text = "Press a key…"
	b.add_theme_color_override("font_color", ACCENT)


func _cancel_listen() -> void:
	if not _listening:
		return
	_listening = false
	_refresh()


func _input(event: InputEvent) -> void:
	if not _listening:
		return
	var new_event: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if code == KEY_ESCAPE:
			_cancel_listen()
			get_viewport().set_input_as_handled()
			return
		if code == KEY_BACKSPACE or code == KEY_DELETE:
			_listening = false
			Settings.set_binding(_listen_action, _listen_slot, null)
			get_viewport().set_input_as_handled()
			return
		var nk := InputEventKey.new()
		nk.physical_keycode = code
		nk.device = -1
		new_event = nk
	elif event is InputEventMouseButton and event.pressed:
		var nm := InputEventMouseButton.new()
		nm.button_index = (event as InputEventMouseButton).button_index
		nm.device = -1
		new_event = nm
	if new_event != null:
		_listening = false
		Settings.set_binding(_listen_action, _listen_slot, new_event)
		get_viewport().set_input_as_handled()


# --- Sync UI with Settings ------------------------------------------------------

func _refresh() -> void:
	_sens_slider.set_value_no_signal(Settings.sensitivity)
	_sens_spin.set_value_no_signal(Settings.sensitivity)
	_invert_check.set_pressed_no_signal(Settings.invert_y)
	_fov_slider.set_value_no_signal(Settings.fov)
	_fov_value.text = "%d°" % int(Settings.fov)
	_crouch_mode.select(1 if Settings.toggle_crouch else 0)
	_sprint_mode.select(1 if Settings.toggle_sprint else 0)
	_aim_mode.select(1 if Settings.toggle_aim else 0)
	_ads_slider.set_value_no_signal(Settings.ads_sensitivity)
	_ads_value.text = "%.2f" % Settings.ads_sensitivity
	for key: String in _bind_buttons:
		var parts := key.split(":")
		var b: Button = _bind_buttons[key]
		b.text = Settings.event_label(Settings.get_binding(parts[0], int(parts[1])))
		b.remove_theme_color_override("font_color")


# --- UI construction ------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	# Main pause panel
	_main_panel = _panel(Vector2(360, 0))
	center.add_child(_main_panel)
	var mv := _vbox(_main_panel, 12)
	_title(mv, "PAUSED")
	_button(mv, "Resume", resume)
	_button(mv, "Settings", _show_settings)
	_button(mv, "Quit", func() -> void: get_tree().quit())

	# Settings panel
	_settings_panel = _panel(Vector2(780, 660))
	center.add_child(_settings_panel)
	var sv := _vbox(_settings_panel, 12)
	_title(sv, "SETTINGS")
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(tabs)
	_build_mouse_tab(tabs)
	_build_controls_tab(tabs)

	var bottom := HBoxContainer.new()
	sv.add_child(bottom)
	_button(bottom, "Reset to defaults", func() -> void: Settings.reset_all())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	_button(bottom, "Back", _show_main)


func _build_mouse_tab(tabs: TabContainer) -> void:
	var page := _tab_page(tabs, "Mouse & View")

	var row := _row(page, "Sensitivity")
	_sens_slider = HSlider.new()
	_sens_slider.min_value = 0.05
	_sens_slider.max_value = 10.0
	_sens_slider.step = 0.01
	_sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sens_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_sens_slider)
	_sens_spin = SpinBox.new()
	_sens_spin.min_value = 0.01
	_sens_spin.max_value = 20.0
	_sens_spin.step = 0.01
	_sens_spin.custom_minimum_size.x = 110
	row.add_child(_sens_spin)
	_sens_slider.value_changed.connect(func(v: float) -> void: Settings.set_value("sensitivity", v))
	_sens_spin.value_changed.connect(func(v: float) -> void: Settings.set_value("sensitivity", v))
	_hint(page, "Same scale as CS2 / Source games. Type in your CS2 sensitivity to get the same feel.")

	row = _row(page, "ADS sensitivity")
	_ads_slider = HSlider.new()
	_ads_slider.min_value = 0.2
	_ads_slider.max_value = 2.0
	_ads_slider.step = 0.05
	_ads_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ads_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_ads_slider)
	_ads_value = Label.new()
	_ads_value.custom_minimum_size.x = 60
	row.add_child(_ads_value)
	_ads_slider.value_changed.connect(func(v: float) -> void: Settings.set_value("ads_sensitivity", v))
	_hint(page, "1.00 = aiming feels the same speed on screen as hipfire, whatever the zoom.")

	row = _row(page, "Invert Y")
	_invert_check = CheckButton.new()
	row.add_child(_invert_check)
	_invert_check.toggled.connect(func(on: bool) -> void: Settings.set_value("invert_y", on))

	row = _row(page, "Field of view")
	_fov_slider = HSlider.new()
	_fov_slider.min_value = 80
	_fov_slider.max_value = 120
	_fov_slider.step = 1
	_fov_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fov_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_fov_slider)
	_fov_value = Label.new()
	_fov_value.custom_minimum_size.x = 60
	row.add_child(_fov_value)
	_fov_slider.value_changed.connect(func(v: float) -> void: Settings.set_value("fov", v))
	_hint(page, "Horizontal FOV at 16:9. 106 matches CS2.")


func _build_controls_tab(tabs: TabContainer) -> void:
	var page := _tab_page(tabs, "Controls")

	var row := _row(page, "Crouch")
	_crouch_mode = _mode_picker(row)
	_crouch_mode.item_selected.connect(func(i: int) -> void: Settings.set_value("toggle_crouch", i == 1))
	row = _row(page, "Sprint")
	_sprint_mode = _mode_picker(row)
	_sprint_mode.item_selected.connect(func(i: int) -> void: Settings.set_value("toggle_sprint", i == 1))
	_hint(page, "Toggle sprint turns off when you stop moving forward.")
	row = _row(page, "Aim down sights")
	_aim_mode = _mode_picker(row)
	_aim_mode.item_selected.connect(func(i: int) -> void: Settings.set_value("toggle_aim", i == 1))
	_hint(page, "Toggle aim turns off when you sprint or switch weapons.")

	for group: String in Settings.REBINDABLE:
		var header := Label.new()
		header.text = group.to_upper()
		header.add_theme_color_override("font_color", ACCENT)
		page.add_child(header)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		page.add_child(grid)
		for col: String in ["", "Primary", "Secondary"]:
			var ch := Label.new()
			ch.text = col
			ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ch.add_theme_font_size_override("font_size", 14)
			ch.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
			grid.add_child(ch)
		for pair: Array in Settings.REBINDABLE[group]:
			var name_label := Label.new()
			name_label.text = pair[1]
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(name_label)
			for slot in Settings.SLOTS:
				var b := Button.new()
				b.custom_minimum_size = Vector2(170, 34)
				b.pressed.connect(_start_listen.bind(pair[0], slot))
				grid.add_child(b)
				_bind_buttons["%s:%d" % [pair[0], slot]] = b
	_hint(page, "Click a binding, then press a key or mouse button. Esc cancels, Backspace clears.")


# --- Small UI helpers -------------------------------------------------------------

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.09, 0.1, 0.12, 0.96)
	panel.border_color = Color(1, 1, 1, 0.08)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(24)
	t.set_stylebox("panel", "PanelContainer", panel)
	for st: Array in [["normal", 0.07], ["hover", 0.14], ["pressed", 0.2], ["focus", 0.0]]:
		var b := StyleBoxFlat.new()
		b.bg_color = Color(1, 1, 1, st[1])
		b.set_corner_radius_all(4)
		b.set_content_margin_all(8)
		if st[0] == "focus":
			b.draw_center = false
			b.border_color = Color(ACCENT, 0.6)
			b.set_border_width_all(1)
		t.set_stylebox(st[0], "Button", b)
		t.set_stylebox(st[0], "OptionButton", b)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.15)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(ACCENT, 0.8)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	return t


func _panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


func _vbox(parent: Control, sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v


func _title(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 42)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _tab_page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	return v


func _row(parent: Control, label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	parent.add_child(h)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 170
	h.add_child(l)
	return h


func _hint(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	parent.add_child(l)


func _mode_picker(row: HBoxContainer) -> OptionButton:
	var o := OptionButton.new()
	o.add_item("Hold")
	o.add_item("Toggle")
	o.custom_minimum_size.x = 170
	row.add_child(o)
	return o
