extends Node
## Global settings (autoload "Settings"). Saved to user://settings.cfg.
## Sensitivity uses the Source/CS scale (0.022° per mouse count × sens), so you
## can type in your CS2 sensitivity and get the same cm/360.

signal changed

const SAVE_PATH := "user://settings.cfg"
## Bump when a default changes and old saves should pick up the new one.
## 2: aim down sights became toggle by default.
const VERSION := 2
const SOURCE_YAW := 0.022 # degrees per count at sens 1.0

## Actions shown in the Controls tab, grouped for the UI.
const REBINDABLE := {
	"Movement": [
		["move_forward", "Forward"], ["move_back", "Back"],
		["move_left", "Left"], ["move_right", "Right"],
		["jump", "Jump"], ["crouch", "Crouch / Slide"], ["sprint", "Sprint"],
	],
	"Combat": [
		["fire", "Fire"], ["aim", "Aim"], ["reload", "Reload"],
		["inspect", "Inspect"], ["melee", "Melee"],
		["weapon_1", "Weapon 1"], ["weapon_2", "Weapon 2"], ["weapon_3", "Knife"],
		["weapon_next", "Next weapon"], ["weapon_prev", "Previous weapon"],
		["throw_weapon", "Throw weapon"], ["interact", "Pick up"], ["buy_menu", "Buy menu"],
	],
}
const SLOTS := 2

## Knives in the buy menu: [id, name, resource]. The last one bought is saved.
const KNIVES := [
	["combat", "Combat Knife", "res://weapons/knife.tres"],
	["karambit", "Karambit", "res://weapons/knife_karambit.tres"],
	["butterfly", "Butterfly Knife", "res://weapons/knife_butterfly.tres"],
	["flip", "Flip Knife", "res://weapons/knife_flip.tres"],
	["bayonet", "Bayonet", "res://weapons/knife_bayonet.tres"],
]

var sensitivity: float = 2.0
var invert_y: bool = false
var fov: float = 106.0 ## Horizontal FOV at 16:9 (CS2 = 106).
var toggle_crouch: bool = false
var toggle_sprint: bool = false
var toggle_aim: bool = true
var ads_sensitivity: float = 1.0 ## Multiplier on top of zoom-matched ADS sensitivity.
var knife: String = "combat" ## Id from KNIVES.

var _default_bindings := {} # action -> Array[InputEvent|null] (from project.godot)


func _ready() -> void:
	for action in all_actions():
		_default_bindings[action] = _slots_from_events(InputMap.action_get_events(action))
	load_settings()


# --- Values -------------------------------------------------------------------

## Id of a knife resource ("" if it isn't in KNIVES).
func knife_id(d: WeaponData) -> String:
	for k: Array in KNIVES:
		if k[2] == d.resource_path:
			return k[0]
	return ""


## The selected knife's WeaponData (null if the id is unknown).
func get_knife_data() -> WeaponData:
	for k: Array in KNIVES:
		if k[0] == knife:
			return load(k[2])
	return null


## Radians of rotation per mouse count.
func get_look_scale() -> float:
	return deg_to_rad(SOURCE_YAW * sensitivity)


## Vertical FOV for Camera3D (which uses vertical FOV by default).
func get_vertical_fov() -> float:
	var h := deg_to_rad(fov)
	return rad_to_deg(2.0 * atan(tan(h * 0.5) * 9.0 / 16.0))


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	save_settings()
	changed.emit()


# --- Bindings -----------------------------------------------------------------

func all_actions() -> Array[String]:
	var out: Array[String] = []
	for group: String in REBINDABLE:
		for pair: Array in REBINDABLE[group]:
			out.append(pair[0])
	return out


func get_binding(action: String, slot: int) -> InputEvent:
	return get_bindings(action)[slot]


func get_bindings(action: String) -> Array:
	return _slots_from_events(InputMap.action_get_events(action))


## Binds `event` to action/slot (null clears it). If another action already
## uses that input, it gets unbound there so nothing is double-bound.
func set_binding(action: String, slot: int, event: InputEvent) -> void:
	if event != null:
		for other in all_actions():
			var slots := get_bindings(other)
			var dirty := false
			for i in SLOTS:
				if slots[i] != null and _same_input(slots[i], event) and not (other == action and i == slot):
					slots[i] = null
					dirty = true
			if dirty:
				_apply_slots(other, slots)
	var mine := get_bindings(action)
	mine[slot] = event
	_apply_slots(action, mine)
	save_settings()
	changed.emit()


func reset_bindings() -> void:
	for action: String in _default_bindings:
		_apply_slots(action, (_default_bindings[action] as Array).duplicate())
	save_settings()
	changed.emit()


func reset_all() -> void:
	sensitivity = 2.0
	invert_y = false
	fov = 106.0
	toggle_crouch = false
	toggle_sprint = false
	toggle_aim = true
	ads_sensitivity = 1.0
	knife = "combat"
	reset_bindings()


static func event_label(e: InputEvent) -> String:
	if e == null:
		return "—"
	if e is InputEventKey:
		var k := e as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		var mapped := code
		# Show the key as labelled on the user's layout (e.g. AZERTY), when supported.
		if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			mapped = DisplayServer.keyboard_get_keycode_from_physical(code)
		var s := OS.get_keycode_string(mapped)
		return s if s != "" else OS.get_keycode_string(code)
	if e is InputEventMouseButton:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Mouse 1"
			MOUSE_BUTTON_RIGHT: return "Mouse 2"
			MOUSE_BUTTON_MIDDLE: return "Mouse 3"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			var b: return "Mouse %d" % b
	return e.as_text()


func _apply_slots(action: String, slots: Array) -> void:
	InputMap.action_erase_events(action)
	for e: Variant in slots:
		if e != null:
			InputMap.action_add_event(action, e)


func _slots_from_events(events: Array) -> Array:
	var slots: Array = []
	slots.resize(SLOTS) # fills with null
	for i in mini(events.size(), SLOTS):
		slots[i] = events[i]
	return slots


static func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return _key_code(a) == _key_code(b)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


static func _key_code(e: InputEventKey) -> int:
	return e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode


# --- Save / load --------------------------------------------------------------

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("mouse", "sensitivity", sensitivity)
	cfg.set_value("mouse", "invert_y", invert_y)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("movement", "toggle_crouch", toggle_crouch)
	cfg.set_value("movement", "toggle_sprint", toggle_sprint)
	cfg.set_value("combat", "toggle_aim", toggle_aim)
	cfg.set_value("mouse", "ads_sensitivity", ads_sensitivity)
	cfg.set_value("loadout", "knife", knife)
	for action in all_actions():
		var data: Array = []
		for e: Variant in get_bindings(action):
			data.append(_event_to_dict(e))
		cfg.set_value("bindings", action, data)
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	sensitivity = cfg.get_value("mouse", "sensitivity", sensitivity)
	invert_y = cfg.get_value("mouse", "invert_y", invert_y)
	fov = cfg.get_value("video", "fov", fov)
	toggle_crouch = cfg.get_value("movement", "toggle_crouch", toggle_crouch)
	toggle_sprint = cfg.get_value("movement", "toggle_sprint", toggle_sprint)
	var version: int = cfg.get_value("meta", "version", 1)
	# Saves from before v2 always stored hold-to-aim (every save writes every value),
	# so they get the new toggle default instead.
	if version >= 2:
		toggle_aim = cfg.get_value("combat", "toggle_aim", toggle_aim)
	ads_sensitivity = cfg.get_value("mouse", "ads_sensitivity", ads_sensitivity)
	knife = cfg.get_value("loadout", "knife", knife)
	for action in all_actions():
		if not cfg.has_section_key("bindings", action):
			continue
		var slots: Array = []
		for d: Variant in cfg.get_value("bindings", action):
			slots.append(_dict_to_event(d))
		slots.resize(SLOTS)
		_apply_slots(action, slots)
	changed.emit()


static func _event_to_dict(e: Variant) -> Dictionary:
	if e is InputEventKey:
		return {"type": "key", "code": _key_code(e)}
	if e is InputEventMouseButton:
		return {"type": "mouse", "button": (e as InputEventMouseButton).button_index}
	return {}


static func _dict_to_event(d: Variant) -> InputEvent:
	if not d is Dictionary:
		return null
	match (d as Dictionary).get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = d["code"]
			k.device = -1
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = d["button"]
			m.device = -1
			return m
	return null
