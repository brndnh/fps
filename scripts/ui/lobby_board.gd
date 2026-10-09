class_name LobbyBoard
extends VBoxContainer
## The lobby: all Net.MAX_PLAYERS slots, two columns. Each shows the player's colour,
## slot (P1 is the host), name, HOST / YOU tags and how they're doing (health, DOWNED,
## OUT); empty slots say OPEN. Used in Esc → Lobby and the hold-Tab overlay. Refreshes
## itself while visible.

const DOWNED := Color(1.0, 0.3, 0.25)
const DIM := Color(1, 1, 1, 0.35)

var _header: Label
var _rows: Array = [] ## Per slot: {swatch, slot, name, tags, status}


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_header = _label("", 18)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_header)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	for i in Net.MAX_PLAYERS:
		grid.add_child(_make_row(i))
	_refresh()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		_refresh()


func _refresh() -> void:
	var by_slot := {}
	for id: int in Game.roster:
		by_slot[int(Game.roster[id].slot)] = id
	var count := by_slot.size()
	match Net.state:
		Net.State.HOSTING:
			_header.text = "%s  ·  %d / %d players" % [Net.status, count, Net.MAX_PLAYERS]
		Net.State.CONNECTED:
			_header.text = "Connected  ·  %d / %d players" % [count, Net.MAX_PLAYERS]
		Net.State.CONNECTING:
			_header.text = Net.status
		_:
			_header.text = "Offline: host or join a game to fill these slots"
	var me := multiplayer.get_unique_id()
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var color: Color = Player.COLORS[i % Player.COLORS.size()]
		if not by_slot.has(i):
			(row.swatch as ColorRect).color = Color(color, 0.15)
			_paint(row.name, "OPEN", DIM)
			_paint(row.tags, "", DIM)
			_paint(row.status, "", DIM)
			continue
		var id: int = by_slot[i]
		(row.swatch as ColorRect).color = color
		_paint(row.name, Game.player_name(id), Color.WHITE)
		var tags := PackedStringArray()
		if id == 1 and Net.is_online():
			tags.append("HOST")
		if id == me:
			tags.append("YOU")
		_paint(row.tags, "  ".join(tags), color)
		var p := Game.players.get_node_or_null(str(id)) as Player
		if p == null:
			_paint(row.status, "JOINING", DIM)
		elif p.health.eliminated:
			_paint(row.status, "OUT", DIM)
		elif p.health.downed:
			_paint(row.status, "DOWNED", DOWNED)
		else:
			var sh := ceili(p.health.shield)
			_paint(row.status, ("%d SH  " % sh if sh > 0 else "") + "%d HP" % ceili(p.health.health), Color.WHITE)


func _make_row(i: int) -> Control:
	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.05)
	bg.set_corner_radius_all(4)
	bg.content_margin_left = 0
	bg.content_margin_right = 12
	panel.add_theme_stylebox_override("panel", bg)
	panel.custom_minimum_size = Vector2(330, 40)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(6, 40)
	h.add_child(swatch)
	var slot := _label("P%d" % (i + 1), 16)
	slot.custom_minimum_size.x = 34
	slot.modulate = Color(1, 1, 1, 0.6)
	h.add_child(slot)
	var name_label := _label("", 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	h.add_child(name_label)
	var tags := _label("", 13)
	h.add_child(tags)
	var status := _label("", 15)
	status.custom_minimum_size.x = 70
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(status)
	_rows.append({swatch = swatch, name = name_label, tags = tags, status = status})
	return panel


func _paint(l: Label, text: String, color: Color) -> void:
	l.text = text
	l.add_theme_color_override("font_color", color)


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
