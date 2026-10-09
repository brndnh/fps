extends Node3D
## The Firing Range (the hub) level script: time of day. The clock (DayClock) steps it
## through morning, noon, evening and night for everyone; the host keeps it in
## Game.map_state.time_of_day, so late joiners get the same sky. Each change fades over
## FADE seconds: the sun (the moon at night) swings round and changes colour, the sky and
## its ambient light (and the haze) shift, and the lamps (lights in the "range_lamps" group, bulbs in
## "lamp_bulbs") and the windows of the apartments outside come on for the evening and night.
## The standing signs fold down flat while you aim down sights, so they never block the view.

const TIMES := [
	{name = "MORNING", hour = 7.0, sun_rot = Vector3(-14, 100, 0), sun_color = Color(1.0, 0.78, 0.58), sun_energy = 0.85,
		sky_top = Color(0.33, 0.5, 0.78), sky_horizon = Color(0.95, 0.76, 0.6), ground = Color(0.26, 0.23, 0.2), ambient = 0.75, lamps = 0.0},
	{name = "NOON", hour = 12.0, sun_rot = Vector3(-55, 145, 0), sun_color = Color(1.0, 0.98, 0.95), sun_energy = 1.0,
		sky_top = Color(0.385, 0.454, 0.55), sky_horizon = Color(0.646, 0.656, 0.671), ground = Color(0.2, 0.169, 0.133), ambient = 1.0, lamps = 0.0},
	{name = "EVENING", hour = 18.5, sun_rot = Vector3(-8, 250, 0), sun_color = Color(1.0, 0.5, 0.28), sun_energy = 0.7,
		sky_top = Color(0.22, 0.22, 0.42), sky_horizon = Color(1.0, 0.48, 0.3), ground = Color(0.16, 0.12, 0.12), ambient = 0.55, lamps = 0.7},
	{name = "NIGHT", hour = 23.0, sun_rot = Vector3(-40, 200, 0), sun_color = Color(0.55, 0.65, 1.0), sun_energy = 0.12,
		sky_top = Color(0.01, 0.015, 0.04), sky_horizon = Color(0.04, 0.05, 0.1), ground = Color(0.02, 0.02, 0.03), ambient = 0.2, lamps = 1.0},
]
const DEFAULT_TIME := 1 ## Noon.
const FADE := 2.5 ## Seconds to change over.
const BULB_GLOW := 4.0 ## Bulb emission energy with the lamps fully on.
const WINDOW_GLOW := 1.6 ## The apartments' lit windows at night (group "night_windows").
const SIGN_FOLD_TIME := 0.18 ## Seconds for the signs to fold down when you aim (and back up).

var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _shown := -1
var _from := {}
var _to := {}
var _t := 1.0
var _signs: Array[Label3D] = [] ## The standing signs (lanes, distances, course...), folded flat while you aim.
var _fold := 0.0 ## 0 = standing, 1 = folded down.


func _ready() -> void:
	_sun = get_node("Sun") as DirectionalLight3D
	_env = (get_node("WorldEnvironment") as WorldEnvironment).environment
	_sky = _env.sky.sky_material as ProceduralSkyMaterial
	Game.map_state_changed.connect(_on_state_changed)
	_show(time_of_day(), true)
	for n in get_node("Labels").get_children():
		if n is Label3D and is_zero_approx((n as Label3D).rotation.x): # Not the ones painted on the floor.
			_signs.append(n)


func time_of_day() -> int:
	return int(Game.map_state.get("time_of_day", DEFAULT_TIME))


func time_name() -> String:
	return TIMES[time_of_day()].name


## The clock's hour, for its hands (eases round with the fade).
func clock_hour() -> float:
	return lerpf(_from.get("hour", _to.hour), _to.hour, smoothstep(0.0, 1.0, _t))


## Host: players' requests (Game.request_action). "clock": on to the next time of day.
func handle_action(action: String, _arg: int, _by: int) -> void:
	if action == "clock":
		Game.set_map_state({time_of_day = (time_of_day() + 1) % TIMES.size()})


func _on_state_changed() -> void:
	if is_inside_tree() and time_of_day() != _shown:
		_show(time_of_day(), false)


func _show(index: int, instant: bool) -> void:
	_shown = index
	_from = _current()
	_to = TIMES[index].duplicate()
	_to.sun_quat = Quaternion.from_euler((_to.sun_rot as Vector3) * (PI / 180.0))
	_t = 1.0 if instant else 0.0
	_apply(1.0 if instant else 0.0)


## What's showing right now, to fade from.
func _current() -> Dictionary:
	if _to.is_empty():
		return {}
	var now := {}
	var k := smoothstep(0.0, 1.0, _t)
	for key: String in ["sun_color", "sun_energy", "sky_top", "sky_horizon", "ground", "ambient", "lamps", "hour"]:
		now[key] = _to[key] if _from.is_empty() else lerp(_from[key], _to[key], k)
	now.sun_quat = _sun.quaternion
	return now


func _process(delta: float) -> void:
	_fold_signs(delta)
	if _t >= 1.0:
		return
	_t = minf(_t + delta / FADE, 1.0)
	_apply(smoothstep(0.0, 1.0, _t))


## Aiming down sights (your own player): the signs tip forward onto their faces, edge on
## and out of the way; they stand back up when you stop.
func _fold_signs(delta: float) -> void:
	var aiming := false
	for p: Player in Game.players.get_children():
		if p.is_local:
			var weapons := p.get_node_or_null("Weapons") as WeaponManager
			aiming = weapons != null and weapons.ads > 0.3
	var target := 1.0 if aiming else 0.0
	if is_equal_approx(_fold, target):
		return
	_fold = move_toward(_fold, target, delta / SIGN_FOLD_TIME)
	var angle := PI * 0.5 * smoothstep(0.0, 1.0, _fold)
	for s in _signs:
		s.rotation.x = angle
		s.visible = _fold < 0.98


func _apply(k: float) -> void:
	var a := _from if not _from.is_empty() else _to
	var b := _to
	_sun.quaternion = (a.sun_quat as Quaternion).slerp(b.sun_quat, k)
	_sun.light_color = (a.sun_color as Color).lerp(b.sun_color, k)
	_sun.light_energy = lerpf(a.sun_energy, b.sun_energy, k)
	_sky.sky_top_color = (a.sky_top as Color).lerp(b.sky_top, k)
	_sky.sky_horizon_color = (a.sky_horizon as Color).lerp(b.sky_horizon, k)
	_sky.ground_horizon_color = _sky.sky_horizon_color.darkened(0.3)
	_sky.ground_bottom_color = (a.ground as Color).lerp(b.ground, k)
	_env.ambient_light_energy = lerpf(a.ambient, b.ambient, k)
	_env.background_energy_multiplier = lerpf(a.ambient, b.ambient, k)
	_env.fog_light_color = _sky.sky_horizon_color.lerp(_sky.sky_top_color, 0.45) # The haze takes the sky's colour, bluer by day.
	var lamps := lerpf(a.lamps, b.lamps, k)
	for n in get_tree().get_nodes_in_group("night_windows"): # The apartments' lit windows.
		var windows := (n as MeshInstance3D).material_override as StandardMaterial3D
		if windows != null:
			windows.emission_energy_multiplier = WINDOW_GLOW * lamps
	for n in get_tree().get_nodes_in_group("range_lamps"):
		var light := n as Light3D
		light.light_energy = float(light.get_meta("full_energy", 1.0)) * lamps
		light.visible = lamps > 0.01
	for n in get_tree().get_nodes_in_group("lamp_bulbs"):
		var bulb := (n as MeshInstance3D).material_override as StandardMaterial3D
		if bulb != null:
			bulb.emission_energy_multiplier = BULB_GLOW * lamps + 0.05
