extends CanvasLayer
## Your health and revive state: health number, shield and health bars, self-revive kits
## and the selected heal (bottom left, Apex style: the heal box right of the bars; the shield in SHIELD_SEGMENT chunks,
## Apex style), a red
## vignette (pulsing while you're down, flashing when you're hit) and a hit direction marker,
## the downed / out / squad wiped screens
## (the world fades to DOWNED_SATURATION colour while you're down), revive and use
## prompts, and revive progress. Built in code; reads the player's PlayerHealth.

const ACCENT := Color(0.35, 1.0, 0.45)
const HURT := Color(1.0, 0.3, 0.25)
const SHIELD_SEGMENT := 25.0 ## Shield per chunk of the shield bar.
const LOW_HEALTH := 0.3
const HIT_MARK_TIME := 1.0 ## Seconds a damage direction marker stays up.
const GLIDE_CUE_RADIUS := 16.0 ## The superglide cue's circle (pixels)...
const GLIDE_CUE_CLOSE_SPEED := 180.0 ## ...and how fast its ring closes in (pixels per second).
const GLIDE_CUE_OFFSET := 0.0 ## Dead centre: it takes the crosshair's place while it's up.
const HEAL_PROMPT_BELOW := 0.25 ## The "hold to heal" reminder shows at or under this share of your health.
const WHEEL_INNER := 100.0 ## The heal wheel (pixels): its clear middle circle...
const WHEEL_ITEM := 168.0 ## ...where the items sit...
const WHEEL_OUTER := 240.0 ## ...and how far the slices reach.
const DOWNED_SATURATION := 0.25
const SATURATION_FADE := 0.8 ## Seconds to fade fully in or out.
const DESATURATE := preload("res://materials/desaturate.gdshader")
const VIGNETTE := preload("res://materials/vignette.gdshader")
const DOWNED_VIGNETTE := 0.85 ## Red vignette strength while you're down (it pulses a little).

var _player: Player
var _grade: ColorRect ## Full-screen saturation shader, on a layer under the HUD.
var _saturation := 1.0
var _health: PlayerHealth
var _hp_bar: ColorRect
var _hp_fill: ColorRect
var _hp_label: Label
var _sh_bar: ColorRect
var _sh_fill: ColorRect
var _sh_ticks: Control
var _shield_flash := 0.0
var _kits: Control ## The self-revive kits: a yellow + and how many.
var _heal_box: Control ## The heal item selected on the wheel: its icon, how many, and the key.
var _vignette: ColorRect ## Red edges: while downed, and a flash when you're hit.
var _hit_flash := 0.0
var _downed_glow := 0.0
var _tint: ColorRect
var _title: Label
var _sub: Label
var _prompt: Label
var _progress_bg: ColorRect
var _progress_fill: ColorRect
var _progress_label: Label
var _hit_marks: Control
var _hits: Array = [] ## [world position, seconds left]
var _wiped := false
var _objective: Label ## Top middle: what the map wants you to do (expeditions).


func _ready() -> void:
	_player = get_parent() as Player
	_health = _player.get_node("Health") as PlayerHealth
	_build()
	_health.hurt.connect(_on_hurt)
	_health.shield_hurt.connect(_on_shield_hurt)
	_health.hit_from.connect(func(from: Vector3) -> void: _hits.append([from, HIT_MARK_TIME]))
	Game.squad_wiped.connect(func() -> void: _wiped = true)
	Game.level_started.connect(func() -> void: _wiped = false)


func _process(delta: float) -> void:
	var h := _health
	var frac := h.health / h.max_health
	_hp_fill.size.x = _hp_bar.size.x * clampf(frac, 0.0, 1.0)
	_hp_fill.color = HURT if frac <= LOW_HEALTH else Color.WHITE
	_hp_label.text = str(ceili(h.health))
	var sh_frac := h.shield / h.max_shield if h.max_shield > 0.0 else 0.0
	_sh_fill.size.x = _sh_bar.size.x * clampf(sh_frac, 0.0, 1.0)
	_shield_flash = maxf(_shield_flash - delta * 3.0, 0.0)
	var tier := PlayerHealth.shield_color(h.max_shield)
	_sh_fill.color = tier.lerp(Color.WHITE, _shield_flash)
	_sh_bar.color = Color(0, 0, 0, 0.5).lerp(Color(tier, 0.6), _shield_flash * 0.6)
	_hp_label.add_theme_color_override("font_color", HURT if frac <= LOW_HEALTH else Color.WHITE)
	_kits.queue_redraw()
	_heal_box.queue_redraw()
	_hit_flash = maxf(_hit_flash - delta * 1.8, 0.0)
	_downed_glow = move_toward(_downed_glow, 1.0 if h.downed else 0.0, delta * 2.0)
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.004)
	var vig := maxf(_downed_glow * DOWNED_VIGNETTE * pulse, _hit_flash)
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", clampf(vig, 0.0, 1.0))
	_vignette.visible = vig > 0.001
	var want := DOWNED_SATURATION if h.downed else 1.0
	_saturation = move_toward(_saturation, want, delta * (1.0 - DOWNED_SATURATION) / SATURATION_FADE)
	(_grade.material as ShaderMaterial).set_shader_parameter("saturation", _saturation)
	_grade.visible = _saturation < 0.999

	var level := get_tree().current_scene
	var objective: String = level.get_objective_text() if level != null and level.has_method("get_objective_text") else ""
	_objective.text = objective
	_objective.visible = objective != ""
	_objective.add_theme_color_override("font_color", HURT if objective.begins_with("EXTRACTION IN") else Color.WHITE)
	var results: Dictionary = level.get_results() if level != null and level.has_method("get_results") else {}

	_title.visible = true
	_sub.visible = true
	_tint.visible = true
	_title.add_theme_color_override("font_color", HURT)
	if not results.is_empty():
		var made_it: bool = _player.peer_id in results.extracted
		_title.text = "EXTRACTED" if made_it else "LEFT BEHIND"
		_title.add_theme_color_override("font_color", ACCENT if made_it else HURT)
		_sub.text = "Extracted: %s   ·   Left behind: %s   ·   Back to the hub…" % [_names(results.extracted), _names(results.left)]
		_tint.color = Color(0.0, 0.0, 0.0, 0.45)
	elif _wiped:
		_title.text = "SQUAD WIPED"
		_sub.text = "Expedition failed. Back to the hub…" if Game.in_expedition() else "Restarting the map…"
		_tint.color = Color(0.0, 0.0, 0.0, 0.55)
	elif h.eliminated:
		_title.text = "YOU'RE OUT"
		var watching := _player.get_spectated()
		_sub.text = "Back in when the map restarts.   Watching %s  ·  [%s] next" % [
				_name(watching.peer_id), _key("fire")] if watching != null else "Back in when the map restarts."
		_tint.color = Color(0.0, 0.0, 0.0, 0.25)
	elif h.downed:
		_title.text = "DOWNED"
		_sub.text = "Revive paused" if h.reviver != 0 else "Bleeding out in %d" % ceili(h.bleed_left)
		_tint.color = Color(0.0, 0.0, 0.0, 0.0) # The red vignette does it.
	else:
		_title.visible = false
		_sub.visible = false
		_tint.visible = false

	_update_revive()
	_hits = _hits.filter(func(hit: Array) -> bool:
		hit[1] -= delta
		return hit[1] > 0.0)
	_hit_marks.queue_redraw()


func _update_revive() -> void:
	var h := _health
	var interact := _player.interact
	var progress := -1.0
	var label := ""
	var prompt := ""
	if h.downed and h.reviver != 0:
		progress = h.revive_progress
		label = "USING SELF-REVIVE KIT" if h.is_self_reviving() else "%s IS REVIVING YOU" % _name(h.reviver)
	elif h.healing:
		progress = h.heal_progress
		label = "USING %s" % PlayerHealth.HEALS[h.heal_kind].name if h.heal_kind >= 0 else "HEALING"
	elif interact != null and interact.is_reviving():
		var target := _reviving_target()
		if target != null and target.reviver == _player.peer_id:
			progress = target.revive_progress
			label = "REVIVING %s" % _name(target.player.peer_id)
	if progress < 0.0 and not h.eliminated and not _wiped and interact != null:
		var candidate := interact.get_candidate()
		var thing := interact.get_interactable()
		if candidate == h:
			prompt = "HOLD [%s]  USE SELF-REVIVE KIT (%d)" % [_key("interact"), h.kits]
		elif candidate != null:
			prompt = "HOLD [%s]  REVIVE %s" % [_key("interact"), _name(candidate.player.peer_id)]
		elif h.downed and h.reviver == 0:
			prompt = "NO SELF-REVIVE KITS: GET A TEAMMATE TO REVIVE YOU"
		elif thing != null:
			prompt = "[%s]  %s" % [_key("interact"), thing.get_prompt()]
		elif _player.is_on_zipline():
			prompt = "[%s] JUMP OFF    [%s] DROP" % [_key("jump"), _key("crouch")]
		elif _player.get_zipline_candidate() != null:
			prompt = "[%s]  ZIPLINE" % _key("interact")
		elif _player.heal_input != null and _player.heal_input.can_heal() and h.health <= h.max_health * HEAL_PROMPT_BELOW:
			prompt = "HOLD [%s]  HEAL" % _key("heal")
	_progress_bg.visible = progress >= 0.0
	_progress_label.visible = progress >= 0.0
	if progress >= 0.0:
		_progress_fill.size.x = _progress_bg.size.x * progress
		_progress_label.text = label
	_prompt.visible = prompt != ""
	_prompt.text = prompt


## The downed teammate we're holding Interact on (they show it as their reviver).
func _reviving_target() -> PlayerHealth:
	for p: Player in Game.players.get_children():
		if p != _player and p.health.downed and p.health.reviver == _player.peer_id:
			return p.health
	return null


func _on_hurt(amount: float) -> void:
	_hit_flash = clampf(_hit_flash + 0.25 + amount * 0.012, 0.0, 0.8)


## The shield soaking a hit: the bar flashes and it clangs; when it breaks, a shatter.
func _on_shield_hurt(_amount: float, broke: bool) -> void:
	if _health.downed:
		return # Lost to going down, not to a hit.
	_shield_flash = 1.0
	Sfx.play("shield_break" if broke else "shield_hit", -4.0 if broke else -9.0)


func _name(peer_id: int) -> String:
	return Game.player_name(peer_id).to_upper()


func _names(peer_ids: Array) -> String:
	if peer_ids.is_empty():
		return "nobody"
	return ", ".join(peer_ids.map(func(id: int) -> String: return Game.player_name(id)))


func _key(action: String) -> String:
	return Settings.event_label(Settings.get_binding(action, 0))


## Red arcs around the crosshair pointing at where recent hits came from.
func _draw_hit_marks() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := _hit_marks.size * 0.5
	for hit: Array in _hits:
		var to: Vector3 = cam.global_transform.affine_inverse() * (hit[0] as Vector3)
		var angle := atan2(to.x, -to.z) # 0 = straight ahead (up on screen), clockwise.
		var a := Color(HURT, clampf(hit[1] / HIT_MARK_TIME, 0.0, 1.0) * 0.9)
		_hit_marks.draw_arc(c, 130.0, angle - PI * 0.5 - 0.3, angle - PI * 0.5 + 0.3, 24, a, 7.0)
	_draw_superglide_cue(c)
	_draw_heal_wheel(c)
	if _player.auto_running:
		var font := ThemeDB.fallback_font
		var text := "AUTO-RUN"
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_hit_marks.draw_string_outline(font, c + Vector2(-w * 0.5, 175), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0, 0, 0, 0.8))
		_hit_marks.draw_string(font, c + Vector2(-w * 0.5, 175), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))


## The heal wheel (hold the heal key, see HealInput), laid out like Apex's: a clear circle in
## the middle, ringed by a slice per item (HealInput.WHEEL_ORDER) split by thin lines, each
## with its icon and how many you have. Pointing at one lights its slice and an arc on the
## middle circle's edge, and the middle names it; with nothing picked it says CANCEL
## (letting go then does nothing). Items you can't use right now are dimmed.
func _draw_heal_wheel(c: Vector2) -> void:
	var heal := _player.heal_input
	if heal == null or not heal.wheel_open:
		return
	var font := ThemeDB.fallback_font
	var n := HealInput.WHEEL_ORDER.size()
	var half := PI / n
	# A dark haze fading out from the middle, the clear middle circle, and the dividers.
	for i in 4:
		_hit_marks.draw_circle(c, WHEEL_OUTER * (1.0 - i * 0.12), Color(0, 0, 0, 0.12))
	_hit_marks.draw_circle(c, WHEEL_INNER, Color(0, 0, 0, 0.12))
	for i in n:
		var dir := Vector2.from_angle(-PI * 0.5 + half + TAU * i / n)
		_hit_marks.draw_line(c + dir * WHEEL_INNER, c + dir * WHEEL_OUTER, Color(1, 1, 1, 0.35), 1.5, true)
	_hit_marks.draw_arc(c, WHEEL_INNER, 0.0, TAU, 96, Color(1, 1, 1, 0.55), 2.0, true)
	if heal.selected >= 0:
		var a := HealInput.slice_angle(heal.selected)
		var wedge := PackedVector2Array()
		for s in 17:
			wedge.append(c + Vector2.from_angle(a - half + 2.0 * half * s / 16.0) * WHEEL_INNER)
		for s in 17:
			wedge.append(c + Vector2.from_angle(a + half - 2.0 * half * s / 16.0) * WHEEL_OUTER)
		_hit_marks.draw_colored_polygon(wedge, Color(1, 1, 1, 0.07))
		_hit_marks.draw_arc(c, WHEEL_INNER + 6.0, a - half * 0.85, a + half * 0.85, 32, Color(1, 1, 1, 0.18), 14.0, true)
		_hit_marks.draw_arc(c, WHEEL_INNER + 3.0, a - half * 0.85, a + half * 0.85, 32, Color.WHITE, 4.0, true)
	for k: int in HealInput.WHEEL_ORDER:
		var item: Dictionary = PlayerHealth.HEALS[k]
		var at := c + Vector2.from_angle(HealInput.slice_angle(k)) * WHEEL_ITEM
		var alpha := 1.0 if _health.can_heal_with(k) else 0.4
		if heal.selected == k:
			alpha = maxf(alpha, 0.7)
		_draw_heal_icon(_hit_marks, k, at + Vector2(-8, 0), Color(item.color, alpha))
		var count := "%d" % _health.heals[k]
		_hit_marks.draw_string_outline(font, at + Vector2(18, 16), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8))
		_hit_marks.draw_string(font, at + Vector2(18, 16), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, alpha))
	# The middle: what you're pointing at, or CANCEL.
	if heal.selected < 0:
		_wheel_text(font, c + Vector2(0, WHEEL_INNER * 0.6), "CANCEL", 16, Color(1, 1, 1, 0.85))
		return
	var picked: Dictionary = PlayerHealth.HEALS[heal.selected]
	var amount := _health.describe(heal.selected)
	_wheel_text(font, c + Vector2(0, -12), picked.name, 18, picked.color)
	_wheel_text(font, c + Vector2(0, 12), "%s  ·  %ss" % [amount, str(picked.time)], 13, Color(1, 1, 1, 0.85))
	if not _health.can_heal_with(heal.selected):
		var why := "NONE LEFT" if _health.heals[heal.selected] <= 0 else ("SHIELD FULL" if PlayerHealth.is_shield_item(heal.selected) \
				else "ALREADY FULL" if PlayerHealth.is_full_item(heal.selected) else "HEALTH FULL")
		_wheel_text(font, c + Vector2(0, 34), why, 12, Color(HURT, 0.9))


## A little flat icon for a heal item, centred on `at`: a syringe, a medkit, a big gold
## trauma kit, a small shield cell canister, a big shield battery.
func _draw_heal_icon(canvas: CanvasItem, kind: int, at: Vector2, col: Color) -> void:
	var white := Color(1, 1, 1, col.a)
	var r := func(x: float, y: float, w: float, h: float, color: Color) -> void:
		canvas.draw_rect(Rect2(at + Vector2(x, y), Vector2(w, h)), color)
	match kind:
		0: # Stim: plunger, barrel, needle.
			r.call(-7, -21, 14, 3, white)
			r.call(-1, -18, 2, 5, white)
			r.call(-5, -13, 10, 20, col)
			r.call(-1, 7, 2, 9, white)
		1, 2: # Medkit / trauma kit: a case with a handle and a cross.
			var s := 1.0 if kind == 1 else 1.25
			r.call(-7 * s, -15 * s, 14 * s, 3 * s, col)
			r.call(-17 * s, -12 * s, 34 * s, 24 * s, col)
			r.call(-2.5 * s, -8 * s, 5 * s, 16 * s, white)
			r.call(-8 * s, -2.5 * s, 16 * s, 5 * s, white)
		3, 4: # Shield cell / battery: a canister with a cap and glowing bands.
			var s := 1.0 if kind == 3 else 1.35
			r.call(-4 * s, -16 * s, 8 * s, 3 * s, white)
			r.call(-8 * s, -13 * s, 16 * s, 27 * s, col)
			r.call(-8 * s, -5 * s, 16 * s, 2 * s, white)
			r.call(-8 * s, 3 * s, 16 * s, 2 * s, white)


func _wheel_text(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := at + Vector2(-w * 0.5, font_size * 0.35)
	_hit_marks.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.8))
	_hit_marks.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Superglide timing, in place of the crosshair while you mantle: a ring closes in on a circle,
## and when it meets it (it goes green) is the moment to jump. Red: you jumped too early.
func _draw_superglide_cue(c: Vector2) -> void:
	var wait := _player.superglide_wait()
	if wait < 0.0:
		return
	var at := c + Vector2(0.0, GLIDE_CUE_OFFSET)
	var col := Color(1, 1, 1, 0.9)
	if _player.superglide_spoiled():
		col = Color(HURT, 0.8)
	elif wait <= 0.0:
		col = ACCENT
	_hit_marks.draw_arc(at, GLIDE_CUE_RADIUS, 0.0, TAU, 48, Color(col, col.a * 0.45), 4.0)
	_hit_marks.draw_arc(at, GLIDE_CUE_RADIUS + wait * GLIDE_CUE_CLOSE_SPEED, 0.0, TAU, 64, col, 2.5)


func _build() -> void:
	layer = 1
	# The saturation grade sits on a layer below this one (and below the weapon HUD),
	# so it greys out the world but not the HUD.
	var grade_layer := CanvasLayer.new()
	grade_layer.layer = -1
	add_child(grade_layer)
	_grade = ColorRect.new()
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = DESATURATE
	_grade.material = mat
	_grade.visible = false
	grade_layer.add_child(_grade)
	_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_tint = _rect(root, Color(0, 0, 0, 0))
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette = _rect(root, Color.WHITE)
	var vmat := ShaderMaterial.new()
	vmat.shader = VIGNETTE
	_vignette.material = vmat
	_vignette.visible = false
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_hit_marks = Control.new()
	_hit_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_marks.draw.connect(_draw_hit_marks)
	root.add_child(_hit_marks)
	_hit_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Stats, bottom left like Apex: the health number, the shield bar over the health bar, the
	# self-revive kits (a yellow +) under them, and the selected heal in its box to their right.
	var x0 := 36.0
	_hp_label = _label(root, "100", 56)
	_place(_hp_label, Control.PRESET_BOTTOM_LEFT, Vector2(x0, -116), Vector2(112, 72))
	var bx := x0 + 112.0
	_sh_bar = _rect(root, Color(0, 0, 0, 0.5))
	_place(_sh_bar, Control.PRESET_BOTTOM_LEFT, Vector2(bx, -100), Vector2(260, 8))
	_sh_fill = _rect(_sh_bar, Color.WHITE)
	_sh_fill.size = Vector2(260, 8)
	_sh_ticks = Control.new() # Gaps between the shield's chunks.
	_sh_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sh_bar.add_child(_sh_ticks)
	_sh_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sh_ticks.draw.connect(func() -> void:
		var chunks := int(ceilf(_health.max_shield / SHIELD_SEGMENT))
		for i in range(1, chunks):
			var x := _sh_ticks.size.x * i / chunks
			_sh_ticks.draw_rect(Rect2(x - 1.5, 0, 3, _sh_ticks.size.y), Color(0, 0, 0, 0.9)))
	_hp_bar = _rect(root, Color(0, 0, 0, 0.5))
	_place(_hp_bar, Control.PRESET_BOTTOM_LEFT, Vector2(bx, -86), Vector2(260, 12))
	_hp_fill = _rect(_hp_bar, Color.WHITE)
	_hp_fill.size = Vector2(260, 12)
	_kits = _canvas(root, _draw_kits)
	_place(_kits, Control.PRESET_BOTTOM_LEFT, Vector2(bx, -66), Vector2(80, 44))
	_heal_box = _canvas(root, _draw_heal_box)
	_place(_heal_box, Control.PRESET_BOTTOM_LEFT, Vector2(bx + 272, -110), Vector2(172, 44))

	# Downed / out / wiped, upper middle.
	_title = _label(root, "", 48)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", HURT)
	_place(_title, Control.PRESET_CENTER_TOP, Vector2(-400, 160), Vector2(800, 64))
	_sub = _label(root, "", 22)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_sub, Control.PRESET_CENTER_TOP, Vector2(-500, 226), Vector2(1000, 32))

	# Revive progress and prompts, under the crosshair.
	_progress_bg = _rect(root, Color(0, 0, 0, 0.5))
	_place(_progress_bg, Control.PRESET_CENTER, Vector2(-120, 74), Vector2(240, 8))
	_progress_fill = _rect(_progress_bg, ACCENT)
	_progress_fill.size = Vector2(0, 8)
	_progress_label = _label(root, "", 18)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_progress_label, Control.PRESET_CENTER, Vector2(-200, 84), Vector2(400, 26))
	_prompt = _label(root, "", 20)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", ACCENT)
	_place(_prompt, Control.PRESET_CENTER, Vector2(-350, 122), Vector2(700, 30))

	_objective = _label(root, "", 22)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_objective, Control.PRESET_CENTER_TOP, Vector2(-450, 24), Vector2(900, 32))


## Anchors c at a corner, edge or the centre of the screen and puts its top-left
## `at` pixels from that point, sized `box`. Works whether or not it's laid out yet.
func _place(c: Control, preset: Control.LayoutPreset, at: Vector2, box: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = at.x
	c.offset_top = at.y
	c.offset_right = at.x + box.x
	c.offset_bottom = at.y + box.y


## Self-revive kits: a yellow + and how many (dim with none).
func _draw_kits() -> void:
	var a := 1.0 if _health.kits > 0 else 0.35
	var yellow := Color(1.0, 0.82, 0.2, a)
	var c := Vector2(18, 22)
	_kits.draw_rect(Rect2(c + Vector2(-13, -5), Vector2(26, 10)), Color(0, 0, 0, 0.6 * a))
	_kits.draw_rect(Rect2(c + Vector2(-5, -13), Vector2(10, 26)), Color(0, 0, 0, 0.6 * a))
	_kits.draw_rect(Rect2(c + Vector2(-11, -3.5), Vector2(22, 7)), yellow)
	_kits.draw_rect(Rect2(c + Vector2(-3.5, -11), Vector2(7, 22)), yellow)
	_canvas_text(_kits, Vector2(38, 30), "×%d" % _health.kits, 22, Color(1, 1, 1, a))


## The heal selected on the wheel, in its own box: its icon, how many, and the heal key.
func _draw_heal_box() -> void:
	var box := Rect2(Vector2.ZERO, _heal_box.size)
	_heal_box.draw_rect(box, Color(0, 0, 0, 0.45))
	_heal_box.draw_rect(box, Color(1, 1, 1, 0.18), false, 1.5)
	var kind := _player.heal_input.shown_kind() if _player.heal_input != null else -1
	var key := "[%s]" % _key("heal")
	if kind < 0:
		_canvas_text(_heal_box, Vector2(10, 28), "%s  NO HEALS" % key, 15, Color(1, 1, 1, 0.4))
		return
	var item: Dictionary = PlayerHealth.HEALS[kind]
	var a := 1.0 if _health.heals[kind] > 0 else 0.4
	_heal_box.draw_set_transform(Vector2(24, 23), 0.0, Vector2.ONE * 0.75)
	_draw_heal_icon(_heal_box, kind, Vector2.ZERO, Color(item.color, a))
	_heal_box.draw_set_transform(Vector2.ZERO)
	_canvas_text(_heal_box, Vector2(48, 20), "%s ×%d" % [item.short, _health.heals[kind]], 17, Color(1, 1, 1, a))
	_canvas_text(_heal_box, Vector2(48, 38), key, 14, Color(1, 1, 1, 0.65))


func _canvas_text(canvas: CanvasItem, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.8 * color.a))
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## A blank Control that draws itself with `draw`.
func _canvas(parent: Control, draw: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(draw)
	parent.add_child(c)
	return c


func _rect(parent: Control, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _label(parent: Control, text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
