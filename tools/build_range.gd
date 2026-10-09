extends SceneTree
## Generates scenes/firing_range.tscn, the hub: a compact firing range with some height to it.
##   godot --headless -s tools/build_range.gd
## WARNING: overwrites scenes/firing_range.tscn. Change the layout here and rerun rather
## than editing the scene (or stop using this and edit the scene by hand from then on).
##
## Looking north (-Z) from the spawn, about 60 x 76 m inside 8 m walls:
##   Hub (south): spawn, buy zone, a lounge under the overlook (fireplace, armchairs, beds), a
##     kitchen with a dining table on the east side, a bedroom behind the south wall, the armory (a two-level gun rack on the west wall and a
##     table of pistols in front of it), launch terminal, enemy lever,
##     supply crate, hazard pad, physics crates, bleachers along the south wall, benches,
##     a balcony over the firing line and an overlook platform in the south-west corner.
##   Range (middle): shooting bench with five lanes (10 / 20 / spray wall / 30 / 40 m), side
##     walls you can walk along the top of, an orange backstop.
##   Yard (west): two-storey scaffolding (stairs, a ramp up to the top deck), crates, benches.
##   Course (east): slide ramp and slide strip, 3 / 5 / 7 m gap jumps, a crouch tunnel,
##     mantle blocks, climb walls (3.6 m makes it, 4.6 m doesn't) and a tower.
##   Ziplines: overlook -> yard, yard top deck -> course tower, balcony -> slide tower.
##   Enemies come from the yard and the course.
##   Lamps all round (lit in the evening and at night), and a clock by the terminals that
##   steps the time of day (scripts/hub.gd, the level script).

const X0 := -26.0
const X1 := 34.0
const Z0 := -46.0
const Z1 := 30.0
const WALL_H := 8.0
const FOREST_MESHES := "res://scenes/firing_range_forest_%s.res" ## The baked trees (_forest()).
const DORM_DOORS := [[-13.0, -11.0], [10.0, 12.0]] ## x ranges of the doorways in the south wall, through to the bedroom.
const DOOR_H := 3.0
const DORM_X := 14.5 ## The dorm runs from -DORM_X to DORM_X...
const DORM_DEPTH := 12.0 ## ...and this far back behind the south wall.

var _root: Node3D
var _geo: Node3D
var _labels: Node3D
var _mat := {}
var _n := 0 ## For unique names.
var _bulb: StandardMaterial3D ## Shared by every lamp's bulb (hub.gd turns the glow up at night).


# Built on the first frame rather than in _init: by then the autoloads exist, so scripts
# that use them compile when they're attached.
func _process(_delta: float) -> bool:
	_build()
	return true


func _build() -> void:
	for m: String in ["grid_dark", "grid_light", "grid_orange", "grid_blue", "marker", "stripe"]:
		_mat[m] = load("res://materials/%s.tres" % m)
	_root = Node3D.new()
	_root.name = "FiringRange"
	_root.set_script(load("res://scripts/hub.gd")) # Time of day.
	_root.set_meta("radar_labels", [["HUB", -4.0, 18.0], ["RANGE", 0.0, -22.0], ["YARD", -20.0, -26.0], ["COURSE", 24.0, -12.0]])
	_environment()
	_geo = _node(_root, "Geometry")
	_labels = _node(_root, "Labels")
	_shell()
	_hub()
	_range()
	_yard()
	_course()
	_ziplines()
	_lamps()
	_dorm()
	_scenery()
	var ps := PackedScene.new()
	ps.pack(_root)
	ResourceSaver.save(ps, "res://scenes/firing_range.tscn")
	_root.free()
	print("Firing range built.")


func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.fog_enabled = true # A little haze, so the mountains sit back in the distance.
	env.fog_density = 0.0024
	env.fog_aerial_perspective = 0.85 # Far things take on the sky's colour: the mountains go blue.
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_add(_root, we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, 145, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	_add(_root, sun)


# --- The pieces ----------------------------------------------------------------------

## Floor and outer walls.
func _shell() -> void:
	var w := X1 - X0
	var d := Z1 - Z0
	var cx := (X0 + X1) * 0.5
	var cz := (Z0 + Z1) * 0.5
	_solid("Ground", Vector3(w + 2, 1, d + 2), Vector3(cx, -0.5, cz), "grid_dark")
	_solid("WallWest", Vector3(1, WALL_H, d + 2), Vector3(X0 - 0.5, WALL_H * 0.5, cz), "grid_light")
	_solid("WallEast", Vector3(1, WALL_H, d + 2), Vector3(X1 + 0.5, WALL_H * 0.5, cz), "grid_light")
	_solid("WallNorth", Vector3(w + 2, WALL_H, 1), Vector3(cx, WALL_H * 0.5, Z0 - 0.5), "grid_light")
	# The south wall has doorways through to the dorm behind it.
	var x := X0 - 1.0
	for door: Array in DORM_DOORS + [[X1 + 1.0, X1 + 1.0]]:
		if door[0] > x:
			_solid("WallSouth", Vector3(door[0] - x, WALL_H, 1), Vector3((x + door[0]) * 0.5, WALL_H * 0.5, Z1 + 0.5), "grid_light")
		if door[1] > door[0]:
			_solid("DoorLintel", Vector3(door[1] - door[0], WALL_H - DOOR_H, 1), Vector3((door[0] + door[1]) * 0.5, (WALL_H + DOOR_H) * 0.5, Z1 + 0.5), "grid_light")
		x = door[1]


func _hub() -> void:
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 0, 8)
	spawn.rotation_degrees.y = 180.0 # Facing the terminals.
	spawn.add_to_group("player_spawns", true)
	_add(_root, spawn)

	var zones := _node(_root, "BuyZones")
	_script_node(zones, "Spawn", Area3D.new(), "res://scripts/buy_zone.gd", Vector3(0, 0, 8), 0.0,
			{size = Vector3(24, 4, 9), flip_label = true})
	_script_node(zones, "Course", Area3D.new(), "res://scripts/buy_zone.gd", Vector3(17, 0, 26), 0.0,
			{size = Vector3(6, 4, 6)})

	_script_node(_root, "LaunchTerminal", Node3D.new(), "res://scripts/expedition/launch_terminal.gd", Vector3(-3, 0, 14))
	_script_node(_root, "EnemyLever", Node3D.new(), "res://scripts/enemy_lever.gd", Vector3(3, 0, 14), 90.0)
	_script_node(_root, "SupplyCrate", Node3D.new(), "res://scripts/supply_crate.gd", Vector3(7, 0, 14))
	_script_node(_root, "DayClock", Node3D.new(), "res://scripts/day_clock.gd", Vector3(-7, 0, 14))
	_script_node(_root, "Hazard", Area3D.new(), "res://scripts/hazard_zone.gd", Vector3(-11, 0, 20))

	_armory()
	_lounge()
	_kitchen()

	# Bleachers along the south wall, looking out over the range: four tiers.
	for i in 4:
		var top := 0.45 * (i + 1)
		var z_from := 23.6 + 1.1 * i
		_solid("Bleacher%d" % i, Vector3(18, top, Z1 - z_from), Vector3(0, top * 0.5, (z_from + Z1) * 0.5), "grid_blue")
	# Benches round the hub.
	_bench(Vector3(-18.2, 0, 5), 90.0, 3.0) # Facing the armory.
	_bench(Vector3(-18.2, 0, 16), 90.0, 3.0)
	_bench(Vector3(11, 0, 6), 90.0, 2.5) # Facing the spawn.
	_bench(Vector3(11, 0, 10), 90.0, 2.5)

	# Balcony over the firing line (stairs up from the west), railing on the range side.
	_platform("Balcony", Vector3(-6, 0, 4), Vector3(6, 0, 7), 3.4)
	_solid("BalconyRail", Vector3(12, 1.0, 0.15), Vector3(0, 3.9, 4.05), "grid_orange")
	_stairs("BalconyStairs", Vector3(-14, 0, 5), Vector3.RIGHT, 8.0, 3.4, 2.0, 8)
	_bench(Vector3(0, 3.4, 6.2), 0.0, 4.0) # Seats up there too.

	# Overlook in the south-west corner (stairs up its east side), with seats facing the range.
	_platform("Overlook", Vector3(X0, 0, 23), Vector3(-15, 0, Z1), 4.0)
	_stairs("OverlookStairs", Vector3(-16, 0, 13), Vector3.BACK, 10.0, 4.0, 2.0, 10)
	# Railing along the front, with a gap where the zipline leaves.
	_solid("OverlookRail", Vector3(-22.0 - X0, 1.0, 0.15), Vector3((X0 - 22.0) * 0.5, 4.5, 23.05), "grid_orange")
	_solid("OverlookRail", Vector3(3.0, 1.0, 0.15), Vector3(-18.5, 4.5, 23.05), "grid_orange")
	_bench(Vector3(-23, 4.0, 26), 0.0, 3.0)
	_bench(Vector3(-19, 4.0, 26), 0.0, 3.0)

	# Physics crates to shove about.
	var props := _node(_root, "Props")
	_script_node(props, "Crate", Marker3D.new(), "res://scripts/physics/prop_spawn.gd", Vector3(4.65, 0, 19.5))
	_script_node(props, "Crate2", Marker3D.new(), "res://scripts/physics/prop_spawn.gd", Vector3(5.95, 0, 19.5))
	_script_node(props, "Crate3", Marker3D.new(), "res://scripts/physics/prop_spawn.gd", Vector3(5.3, 1.22, 19.5))
	_script_node(props, "Crate4", Marker3D.new(), "res://scripts/physics/prop_spawn.gd", Vector3(-5, 0, 18), 23.0)
	_script_node(props, "Crate5", Marker3D.new(), "res://scripts/physics/prop_spawn.gd", Vector3(-3.4, 0, 19.5), 0.0,
			{size = Vector3(0.8, 0.8, 0.8), mass = 10.0})
	_script_node(props, "BigCrate", Marker3D.new(), "res://scripts/physics/prop_spawn.gd", Vector3(6, 0, 22.4), 0.0,
			{size = Vector3(2, 2, 2), mass = 90.0})


## The lounge, tucked under the overlook in the south-west corner: a stone fireplace with a
## fire that's always going (scripts/fireplace.gd flickers it), a rug and two armchairs
## facing it, and two beds along the west wall with a nightstand between them.
func _lounge() -> void:
	_flat("stone", Color(0.46, 0.44, 0.42))
	_flat("soot", Color(0.06, 0.05, 0.05))
	_flat("wood", Color(0.42, 0.26, 0.14))
	_flat("fabric", Color(0.55, 0.16, 0.14))
	_flat("linen", Color(0.9, 0.88, 0.82))
	_flat("rug", Color(0.5, 0.3, 0.16))
	_flat("flame", Color(1.0, 0.55, 0.15), 4.0)
	_flat("ember", Color(1.0, 0.3, 0.05), 2.5)
	_flat("glow", Color(1.0, 0.85, 0.6), 2.0)
	var fire := _script_node(_root, "Fireplace", Node3D.new(), "res://scripts/fireplace.gd", Vector3(-21, 0, 29.6))
	_solid("Hearth", Vector3(2.8, 0.15, 1.3), Vector3(0, 0.075, -0.25), "stone", fire)
	for x: float in [-1.0, 1.0]:
		_solid("Jamb", Vector3(0.6, 1.4, 0.8), Vector3(x, 0.85, 0.0), "stone", fire)
	_solid("Lintel", Vector3(2.6, 0.35, 0.8), Vector3(0, 1.725, 0.0), "stone", fire)
	_solid("Firebox", Vector3(1.4, 1.4, 0.15), Vector3(0, 0.85, 0.32), "soot", fire)
	_solid("Chimney", Vector3(2.0, 1.85, 0.6), Vector3(0, 2.825, 0.1), "stone", fire)
	_solid("Mantle", Vector3(2.9, 0.1, 0.4), Vector3(0, 1.95, -0.15), "wood", fire)
	_mesh(fire, "Log", Vector3(1.0, 0.14, 0.14), Vector3(0, 0.23, 0.0), Vector3(0, 15, 0), "wood")
	_mesh(fire, "Log", Vector3(0.9, 0.13, 0.13), Vector3(0.05, 0.33, 0.04), Vector3(0, -20, 0), "wood")
	_mesh(fire, "Embers", Vector3(0.9, 0.04, 0.4), Vector3(0, 0.17, 0.0), Vector3.ZERO, "ember")
	for i in 3: # Each flame grows from its base, so the script can lick it up and down.
		var flame := Node3D.new()
		flame.name = "Flame%d" % i
		flame.position = Vector3(-0.28 + i * 0.28, 0.3, -0.02 + (i % 2) * 0.06)
		_add(fire, flame)
		_mesh(flame, "Mesh", Vector3(0.22, 0.42 - absf(i - 1) * 0.1, 0.1), Vector3(0, 0.2, 0), Vector3(0, i * 25.0, 0), "flame")
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.position = Vector3(0, 0.8, -0.7)
	light.omni_range = 8.0
	light.light_energy = 2.0
	light.light_color = Color(1.0, 0.55, 0.25)
	_add(fire, light)

	_deco("Rug", Vector3(3.2, 0.02, 2.2), Vector3(-21, 0.01, 26.9), "rug")
	_armchair(Vector3(-22.4, 0, 26.6), 165.0)
	_armchair(Vector3(-19.6, 0, 26.6), 195.0)
	for z: float in [24.6, 27.8]:
		_bed(Vector3(-25, 0, z))
	_solid("Nightstand", Vector3(0.45, 0.5, 0.45), Vector3(-25.6, 0.25, 26.2), "wood")
	_deco("BedsideLamp", Vector3(0.18, 0.22, 0.18), Vector3(-25.6, 0.61, 26.2), "glow")


## A kitchen on the hub's east side: a counter with a stove (and a kettle on it), a sink and
## a fridge, and a dining table with four chairs.
func _kitchen() -> void:
	_flat("steel", Color(0.7, 0.72, 0.75))
	_flat("white", Color(0.92, 0.92, 0.9))
	_flat("burner", Color(0.8, 0.15, 0.05), 0.8)
	_solid("Counter", Vector3(0.7, 0.88, 5.0), Vector3(13.0, 0.44, 19.0), "wood")
	_solid("Countertop", Vector3(0.78, 0.06, 5.1), Vector3(13.0, 0.91, 19.0), "stone")
	_deco("Stove", Vector3(0.6, 0.02, 0.6), Vector3(13.0, 0.95, 17.6), "soot")
	for b: Vector2 in [Vector2(-0.14, -0.14), Vector2(0.14, -0.14), Vector2(-0.14, 0.14), Vector2(0.14, 0.14)]:
		_deco("Burner", Vector3(0.14, 0.01, 0.14), Vector3(13.0 + b.x, 0.965, 17.6 + b.y), "burner")
	_deco("OvenDoor", Vector3(0.02, 0.5, 0.55), Vector3(12.64, 0.4, 17.6), "soot")
	_deco("Kettle", Vector3(0.18, 0.2, 0.18), Vector3(13.14, 1.07, 17.46), "steel")
	_deco("Sink", Vector3(0.5, 0.025, 0.45), Vector3(13.0, 0.945, 20.2), "steel")
	_deco("Faucet", Vector3(0.04, 0.28, 0.04), Vector3(13.25, 1.08, 20.2), "steel")
	_deco("Spout", Vector3(0.18, 0.03, 0.03), Vector3(13.17, 1.2, 20.2), "steel")
	_solid("Fridge", Vector3(0.75, 1.9, 0.75), Vector3(13.0, 0.95, 22.1), "white")
	_deco("FridgeHandle", Vector3(0.03, 0.5, 0.03), Vector3(12.6, 1.2, 21.85), "steel")
	_deco("FridgeSeam", Vector3(0.01, 0.02, 0.76), Vector3(12.62, 1.35, 22.1), "soot")
	# Dining table and chairs.
	_solid("DiningTable", Vector3(1.0, 0.06, 1.6), Vector3(9.8, 0.75, 19.4), "wood")
	for c: Vector2 in [Vector2(-0.42, -0.7), Vector2(0.42, -0.7), Vector2(-0.42, 0.7), Vector2(0.42, 0.7)]:
		_solid("TableLeg", Vector3(0.07, 0.72, 0.07), Vector3(9.8 + c.x, 0.36, 19.4 + c.y), "wood")
	for z: float in [18.95, 19.85]:
		_chair(Vector3(9.0, 0, z), -90.0)
		_chair(Vector3(10.6, 0, z), 90.0)


func _armchair(at: Vector3, yaw: float) -> void:
	var holder := _node(_geo, "Armchair%d" % _next())
	holder.position = at
	holder.rotation_degrees.y = yaw
	_solid("Seat", Vector3(0.8, 0.45, 0.8), Vector3(0, 0.225, 0), "fabric", holder)
	_solid("Back", Vector3(0.8, 0.6, 0.15), Vector3(0, 0.75, 0.33), "fabric", holder)
	for x: float in [-0.4, 0.4]:
		_solid("Arm", Vector3(0.14, 0.25, 0.8), Vector3(x, 0.57, 0), "fabric", holder)


func _chair(at: Vector3, yaw: float) -> void:
	var holder := _node(_geo, "Chair%d" % _next())
	holder.position = at
	holder.rotation_degrees.y = yaw
	_solid("Seat", Vector3(0.42, 0.05, 0.42), Vector3(0, 0.45, 0), "wood", holder)
	_solid("Back", Vector3(0.42, 0.5, 0.05), Vector3(0, 0.72, 0.19), "wood", holder)
	for c: Vector2 in [Vector2(-0.17, -0.17), Vector2(0.17, -0.17), Vector2(-0.17, 0.17), Vector2(0.17, 0.17)]:
		_solid("Leg", Vector3(0.04, 0.43, 0.04), Vector3(c.x, 0.215, c.y), "wood", holder)


## A bed along x with its head against the west wall: frame, mattress, blanket, pillow, headboard.
func _bed(at: Vector3, yaw: float = 0.0) -> void:
	var holder := _node(_geo, "Bed%d" % _next())
	holder.position = at
	holder.rotation_degrees.y = yaw # 0: head to the west.
	_solid("Frame", Vector3(2.0, 0.35, 1.1), Vector3(0, 0.175, 0), "wood", holder)
	_solid("Mattress", Vector3(1.9, 0.18, 1.0), Vector3(0.05, 0.44, 0), "linen", holder)
	_mesh(holder, "Blanket", Vector3(1.25, 0.06, 1.04), Vector3(0.6, 0.55, 0), Vector3.ZERO, "fabric")
	_mesh(holder, "Pillow", Vector3(0.35, 0.1, 0.7), Vector3(-0.65, 0.58, 0), Vector3.ZERO, "linen")
	_solid("Headboard", Vector3(0.08, 0.9, 1.1), Vector3(-0.96, 0.45, 0), "wood", holder)


## A plain material for the furniture, kept under `n` in _mat.
func _flat(n: String, color: Color, glow: float = 0.0) -> void:
	if _mat.has(n):
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_mat[n] = m


## A mesh-only box under `parent` (positions local to it).
func _mesh(parent: Node, n: String, size: Vector3, at: Vector3, rot: Vector3, mat: String) -> void:
	var m := MeshInstance3D.new()
	m.name = "%s%d" % [n, _next()] if n != "Mesh" else n
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _mat[mat]
	m.position = at
	m.rotation_degrees = rot
	_add(parent, m)


## The armory on the west wall: a big two-level rack of long guns on pegs, and a table in
## front of it with the pistols and SMG lying on it. No labels: look at a gun for its name
## (coloured by ammo type). Lit at night by lamps over the rack and either end of the table.
func _armory() -> void:
	var rack := _node(_root, "WeaponRack")
	var wall := X0 + 0.15
	_solid("RackBoard", Vector3(0.3, 3.4, 21), Vector3(wall, 1.7, 11), "grid_blue")
	_deco("RackTrim", Vector3(0.32, 0.12, 21), Vector3(wall, 3.4, 11), "grid_orange")
	_label("ARMOURY", Vector3(wall + 0.17, 3.9, 11), 96, 90.0)
	var long_guns := [["Carbine", "carbine"], ["M4A4", "m4"], ["AK47", "ak47"], ["Shotgun", "shotgun"],
			["DMR", "dmr"], ["SSG", "ssg"], ["Sniper", "sniper"], ["Olympia", "olympia"], ["Negev", "negev"]]
	for level in 2:
		var y := 1.25 + level * 1.15
		_solid("RackShelf", Vector3(0.45, 0.06, 21), Vector3(wall + 0.37, y - 0.3, 11), "grid_light")
		for i in 5:
			if level * 5 + i >= long_guns.size():
				break
			var g: Array = long_guns[level * 5 + i]
			var z := 2.8 + i * 3.85
			for dz: float in [-0.25, 0.2]: # Pegs it rests on.
				_deco("Peg", Vector3(0.3, 0.05, 0.05), Vector3(wall + 0.3, y - 0.12, z + dz), "grid_orange")
			var d: WeaponData = load("res://weapons/%s.tres" % g[1])
			_script_node(rack, g[0], Node3D.new(), "res://scripts/weapons/weapon_spawner.gd",
					Vector3(wall + 0.4, y, z), 0.0, {weapon = d, resting = true})
	# The table, with the small guns lying on their sides, barrels to the wall.
	var tx := X0 + 4.5
	_solid("ArmoryTable", Vector3(1.2, 0.08, 12), Vector3(tx, 0.91, 11), "grid_light")
	for c: Vector2 in [Vector2(-0.5, -5.8), Vector2(0.5, -5.8), Vector2(-0.5, 5.8), Vector2(0.5, 5.8)]:
		_solid("TableLeg", Vector3(0.08, 0.87, 0.08), Vector3(tx + c.x, 0.435, 11 + c.y), "grid_blue")
	var small_guns := [["Sidearm", "sidearm"], ["DesertEagle", "deagle"], ["Revolver", "revolver"], ["SMG", "smg"]]
	for i in small_guns.size():
		var d: WeaponData = load("res://weapons/%s.tres" % small_guns[i][1])
		var z := 6.5 + i * 3.0
		var slot := _script_node(rack, small_guns[i][0], Node3D.new(), "res://scripts/weapons/weapon_spawner.gd",
				Vector3(tx, 1.0, z), 90.0, {weapon = d, resting = true})
		slot.rotation_degrees.z = 90.0 # On its side.


func _range() -> void:
	_solid("Bench", Vector3(26, 1, 0.6), Vector3(0, 0.5, 0), "grid_blue")
	for x: float in [-7.8, -2.6, 2.6, 7.8]:
		_solid("Divider", Vector3(0.15, 2.4, 3), Vector3(x, 1.2, 1.5), "grid_light")
	for x: float in [-10.4, -5.2, 0.0, 5.2, 10.4]:
		_solid("Stool", Vector3(0.5, 0.5, 0.5), Vector3(x, 0.25, 2.3), "grid_orange")
	# Side walls, walkable along the top (get up from the yard's scaffolding).
	_solid("RangeWallLeft", Vector3(1, 4, 45), Vector3(-13.5, 2, -22.5), "grid_light")
	_solid("RangeWallRight", Vector3(1, 4, 45), Vector3(13.5, 2, -22.5), "grid_light")
	_solid("Backstop", Vector3(28, 8, 2), Vector3(0, 4, Z0 + 1.0), "grid_orange")
	_solid("SprayWall", Vector3(4, 3.4, 0.3), Vector3(-10.4, 1.7, -15), "grid_light") # Lane 3 sits far left, lane 1 in the middle.
	_deco("AimDot", Vector3(0.2, 0.2, 0.05), Vector3(-10.4, 2.6, -14.83), "marker")

	var targets := _node(_root, "Targets")
	var target_scene: PackedScene = load("res://scenes/target.tscn")
	var lanes := [[1, 0.0, -10.0], [2, -5.2, -20.0], [4, 5.2, -30.0], [5, 10.4, -40.0]]
	for lane: Array in lanes:
		for dx: float in [-1.6, 0.0, 1.6]:
			var t := target_scene.instantiate() as Node3D
			t.name = "Target_L%d_%d" % [lane[0], roundi(dx * 10)]
			t.position = Vector3(lane[1] + dx, 0, lane[2])
			_add(targets, t)
		_label("LANE %d\n%d m" % [lane[0], -int(lane[2])], Vector3(lane[1], 2.6, -0.2), 40)
	_label("LANE 3\nSPRAY WALL", Vector3(-10.4, 2.6, -0.2), 40)
	for z: float in [-10.0, -20.0, -30.0, -40.0]:
		_deco("DistLine", Vector3(26, 0.02, 0.15), Vector3(0, 0.01, z), "stripe")
		_label("%d m" % -int(z), Vector3(-12.9, 2.2, z), 72, 90.0)


func _yard() -> void:
	# Scaffolding: a deck at 3 m (stairs up from the hub side), a ramp up to a top deck at 6 m.
	_platform("DeckLow", Vector3(X0, 0, -22), Vector3(-16, 0, -14), 3.0)
	_stairs("DeckStairs", Vector3(-17, 0, -4), Vector3.FORWARD, 10.0, 3.0, 2.0, 8)
	_ramp("DeckRamp", Vector3(-22.5, 3.0, -22), Vector3(-22.5, 6.0, -28), 3.0)
	_platform("DeckHigh", Vector3(X0, 0, -36), Vector3(-19, 0, -28), 6.0)
	# Railing on the range side, with a gap where the zipline leaves.
	_solid("DeckHighRail", Vector3(0.15, 1.0, 2.6), Vector3(-19.05, 6.5, -34.7), "grid_orange")
	_solid("DeckHighRail", Vector3(0.15, 1.0, 2.6), Vector3(-19.05, 6.5, -29.3), "grid_orange")
	_bench(Vector3(-23.5, 6.0, -34.5), 0.0, 3.0)
	_bench(Vector3(-23, 0, -26), 90.0, 3.0) # Under the decks.
	_bench(Vector3(-23, 0, -9), 90.0, 3.0)
	# Cover.
	_solid("YardCrate", Vector3(2, 1.2, 2), Vector3(-18, 0.6, -40), "grid_blue")
	_solid("YardCrate", Vector3(1.5, 2.2, 1.5), Vector3(-16, 1.1, -43), "grid_blue")
	_solid("YardCrate", Vector3(3, 1.0, 1.2), Vector3(-22, 0.5, -42), "grid_blue")
	var spawners := _node(_root, "EnemySpawners")
	_script_node(spawners, "West", Marker3D.new(), "res://scripts/enemies/enemy_spawner.gd", Vector3(-17, 0, -30))
	_script_node(spawners, "East", Marker3D.new(), "res://scripts/enemies/enemy_spawner.gd", Vector3(19, 0, -43))


func _course() -> void:
	# Slide ramp: up the south side, a long run down to the north, a strip to measure the slide.
	_solid("RampTower", Vector3(5, 5, 5), Vector3(24, 2.5, 18.5), "grid_light")
	_ramp("RampUp", Vector3(24, 0, 29), Vector3(24, 5, 21), 5.0)
	_ramp("RampDown", Vector3(24, 0, 2), Vector3(24, 5, 16), 5.0)
	_label("SLIDE RAMP", Vector3(24, 7.5, 18.5), 72)
	_deco("SlideStrip", Vector3(0.4, 0.02, 24), Vector3(24, 0.01, -10), "stripe")
	for i in range(1, 5):
		_label("%d" % (i * 5), Vector3(24, 0.03, 2.0 - i * 5.0), 96, 0.0, true)

	# Gap jumps on platforms 1 m up: 3, 5 and 7 m.
	_ramp("GapRamp", Vector3(31.5, 0, 26), Vector3(31.5, 1, 20), 3.0)
	var z := 20.0
	var gaps := [3.0, 5.0, 7.0]
	for i in 4:
		_solid("GapPlatform%d" % (i + 1), Vector3(3, 1, 6), Vector3(31.5, 0.5, z - 3.0), "grid_blue")
		z -= 6.0
		if i < gaps.size():
			_label("%d m GAP" % int(gaps[i]), Vector3(31.5, 2.5, z - gaps[i] * 0.5), 48)
			z -= gaps[i]

	# Crouch tunnel.
	_solid("TunnelWallW", Vector3(0.5, 1.3, 10), Vector3(15.25, 0.65, -9), "grid_light")
	_solid("TunnelWallE", Vector3(0.5, 1.3, 10), Vector3(18.75, 0.65, -9), "grid_light")
	_solid("TunnelRoof", Vector3(4, 0.3, 10), Vector3(17, 1.45, -9), "grid_light")
	_label("CROUCH / SLIDE", Vector3(17, 2.4, -3.8), 48)

	# Mantle blocks and climb walls.
	var heights := [0.5, 1.0, 1.5, 2.0]
	for i in heights.size():
		var h: float = heights[i]
		_solid("MantleBlock", Vector3(1.6, h, 2), Vector3(15.5 + i * 2.2, h * 0.5, -28), "grid_blue")
		_label("%s m" % str(h), Vector3(15.5 + i * 2.2, h + 0.6, -26.9), 40)
	_label("MANTLE", Vector3(18.8, 3.4, -27), 56)
	_solid("ClimbWall", Vector3(3, 3.6, 2), Vector3(26.5, 1.8, -28), "grid_light")
	_label("WALL CLIMB 3.6 m", Vector3(26.5, 4.3, -26.9), 40)
	_solid("ClimbWallHigh", Vector3(3, 4.6, 2), Vector3(31, 2.3, -28), "grid_light")
	_label("4.6 m: TOO HIGH", Vector3(31, 5.3, -26.9), 40)

	# The tower (a zipline lands on top): climb up from the step block.
	_solid("CourseTower", Vector3(5, 6, 6), Vector3(30.5, 3, -40), "grid_light")
	_solid("TowerStep", Vector3(3, 2.4, 3), Vector3(26.5, 1.2, -40), "grid_blue")
	_solid("TowerStepLow", Vector3(2, 1.2, 3), Vector3(24, 0.6, -40), "grid_blue")
	# A bit of cover between.
	_solid("CourseCrate", Vector3(2, 1, 2), Vector3(20, 0.5, -36), "grid_blue")
	_solid("CourseCrate", Vector3(1.5, 1.5, 1.5), Vector3(27, 0.75, -19), "grid_blue")


func _ziplines() -> void:
	var lines := _node(_root, "Ziplines")
	# [from, to, pole under start, pole under end]
	for z: Array in [
			[Vector3(-21, 6.6, 24.5), Vector3(-21, 5.6, -17.5), 2.6, 2.6], # Overlook -> low deck.
			[Vector3(-22, 8.6, -32), Vector3(29.0, 8.6, -39.5), 2.6, 2.6], # Top deck -> course tower, over the range.
			[Vector3(4.5, 6.0, 5.6), Vector3(22.5, 7.6, 18.0), 2.6, 2.6]]: # Balcony -> slide ramp tower.
		var from: Vector3 = z[0]
		var to: Vector3 = z[1]
		_script_node(lines, "Zipline", Node3D.new(), "res://scripts/zipline.gd", from, 0.0,
				{end = to - from, pole_a = z[2], pole_b = z[3]})
	_label("ZIPLINE", Vector3(-21, 7.4, 23.8), 48)


## Lamp posts round every area and on the platforms. Off by day; hub.gd brings them up for
## the evening and night.
func _lamps() -> void:
	_bulb = StandardMaterial3D.new()
	_bulb.albedo_color = Color(1.0, 0.92, 0.75)
	_bulb.emission_enabled = true
	_bulb.emission = Color(1.0, 0.85, 0.6)
	_bulb.emission_energy_multiplier = 0.05
	for at: Vector3 in [
			# Hub.
			Vector3(-12, 0, 2.6), Vector3(12, 0, 2), Vector3(-11, 0, 11), Vector3(8.6, 0, 16), Vector3(0, 0, 21.5),
			# Range, down both sides.
			Vector3(-12.3, 0, -5), Vector3(12.3, 0, -5), Vector3(-12.3, 0, -22), Vector3(12.3, 0, -22),
			Vector3(-12.3, 0, -35), Vector3(12.3, 0, -35),
			# Yard.
			Vector3(-20, 0, -8), Vector3(-16, 0, -26), Vector3(-24.5, 0, -44),
			# Course.
			Vector3(20, 0, 10), Vector3(28, 0, -6), Vector3(21, 0, -22), Vector3(22, 0, -34), Vector3(33.3, 0, 28),
			# Up on the platforms.
			Vector3(-25.2, 4, 29.2), Vector3(-25.2, 6, -35.2), Vector3(-5.5, 3.4, 6.6), Vector3(25.8, 5, 20.4),
			Vector3(32.3, 6, -42.4),
			# Either end of the armory table.
			Vector3(X0 + 4.5, 0, 3.8), Vector3(X0 + 4.5, 0, 18.2)]:
		_lamp(at)
	# The armory rack's own lights: a glowing strip along its top and lights shining down on the guns.
	var strip := MeshInstance3D.new()
	strip.name = "RackLightStrip"
	var sm := BoxMesh.new()
	sm.size = Vector3(0.12, 0.05, 20)
	strip.mesh = sm
	strip.material_override = _bulb
	strip.position = Vector3(X0 + 0.45, 3.5, 11)
	strip.add_to_group("lamp_bulbs", true)
	_add(_geo, strip)
	for z: float in [4.0, 11.0, 18.0]:
		var light := OmniLight3D.new()
		light.name = "RackLight%d" % _next()
		light.position = Vector3(X0 + 1.4, 3.2, z)
		light.omni_range = 8.0
		light.light_color = Color(1.0, 0.9, 0.75)
		light.light_energy = 0.0
		light.set_meta("full_energy", 2.0)
		light.visible = false
		light.add_to_group("range_lamps", true)
		_add(_geo, light)


## A lamp post: a pole, a shade, a glowing bulb and a light under it.
func _lamp(at: Vector3, height: float = 4.2, energy: float = 2.2, reach: float = 15.0) -> void:
	var holder := _node(_geo, "Lamp%d" % _next())
	holder.position = at
	_solid("Post", Vector3(0.14, height, 0.14), Vector3(0, height * 0.5, 0), "grid_blue", holder)
	var shade := MeshInstance3D.new()
	shade.name = "Shade"
	var sm := BoxMesh.new()
	sm.size = Vector3(0.55, 0.12, 0.55)
	shade.mesh = sm
	shade.material_override = _mat["grid_blue"]
	shade.position = Vector3(0, height + 0.06, 0)
	_add(holder, shade)
	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.05, 0.4)
	bulb.mesh = bm
	bulb.material_override = _bulb
	bulb.position = Vector3(0, height - 0.02, 0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.add_to_group("lamp_bulbs", true)
	_add(holder, bulb)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0, height - 0.3, 0)
	light.omni_range = reach
	light.light_color = Color(1.0, 0.86, 0.66)
	light.light_energy = 0.0
	light.set_meta("full_energy", energy)
	light.visible = false
	light.add_to_group("range_lamps", true)
	_add(holder, light)


## The bedroom, behind the south wall (in through the doorways either end of the bleachers):
## four beds against the back wall in two pairs, each pair with a nightstand and a lamp
## under a window, wardrobes between the pairs, a reading corner (armchairs, a side table
## and a floor lamp) by the west wall, a desk and bookshelf by the east wall, plants, a big
## rug, pictures on the walls and ceiling lights that are always on.
func _dorm() -> void:
	_flat("wood", Color(0.42, 0.26, 0.14))
	_flat("linen", Color(0.9, 0.88, 0.82))
	_flat("fabric", Color(0.55, 0.16, 0.14))
	_flat("rug", Color(0.5, 0.3, 0.16))
	_flat("glow", Color(1.0, 0.85, 0.6), 2.0)
	_flat("soot", Color(0.06, 0.05, 0.05))
	_flat("sky", Color(0.55, 0.75, 0.95), 1.2)
	_flat("leaf", Color(0.2, 0.45, 0.2))
	_flat("pot", Color(0.6, 0.35, 0.25))
	_flat("teal", Color(0.15, 0.45, 0.5))
	_flat("gold", Color(0.85, 0.65, 0.2))
	var z0 := Z1 + 1.0 # Inside face of the south wall.
	var z1 := z0 + DORM_DEPTH # The back wall.
	var cz := (z0 + z1) * 0.5
	_solid("DormFloor", Vector3(DORM_X * 2 + 2, 1, DORM_DEPTH + 1), Vector3(0, -0.5, cz), "grid_dark")
	_solid("DormWallW", Vector3(1, 4.3, DORM_DEPTH + 1), Vector3(-DORM_X - 0.5, 2.15, cz), "grid_light")
	_solid("DormWallE", Vector3(1, 4.3, DORM_DEPTH + 1), Vector3(DORM_X + 0.5, 2.15, cz), "grid_light")
	_solid("DormWallS", Vector3(DORM_X * 2 + 2, 4.3, 1), Vector3(0, 2.15, z1 + 0.5), "grid_light")
	_solid("DormRoof", Vector3(DORM_X * 2 + 2, 0.3, DORM_DEPTH + 2), Vector3(0, 4.15, cz), "grid_light")
	_deco("BedroomRug", Vector3(14, 0.02, 5), Vector3(0, 0.01, z1 - 3.8), "rug")
	_deco("RugBorder", Vector3(14.4, 0.015, 5.4), Vector3(0, 0.005, z1 - 3.8), "teal")
	# Two pairs of beds, a nightstand, lamp and window between each pair.
	for pair: float in [-7.0, 7.0]:
		for side: float in [-1.6, 1.6]:
			_bed(Vector3(pair + side, 0, z1 - 1.05), 90.0)
		_solid("Nightstand", Vector3(0.5, 0.55, 0.45), Vector3(pair, 0.275, z1 - 0.3), "wood")
		_deco("BedsideLamp", Vector3(0.2, 0.26, 0.2), Vector3(pair, 0.68, z1 - 0.3), "glow")
		_deco("Window", Vector3(1.4, 1.0, 0.04), Vector3(pair, 2.2, z1 - 0.02), "sky")
		_deco("WindowFrame", Vector3(1.6, 1.2, 0.03), Vector3(pair, 2.2, z1 - 0.005), "wood")
	# Wardrobes between the pairs.
	for x: float in [-1.2, 1.2]:
		_solid("Wardrobe", Vector3(2.0, 2.3, 0.65), Vector3(x, 1.15, z1 - 0.33), "wood")
		_deco("WardrobeSeam", Vector3(0.02, 2.1, 0.02), Vector3(x, 1.15, z1 - 0.66), "soot")
		_deco("WardrobeHandle", Vector3(0.04, 0.2, 0.03), Vector3(x - 0.12, 1.2, z1 - 0.67), "gold")
		_deco("WardrobeHandle", Vector3(0.04, 0.2, 0.03), Vector3(x + 0.12, 1.2, z1 - 0.67), "gold")
	# Reading corner by the west wall.
	_armchair(Vector3(-13.2, 0, z0 + 4.4), -60.0)
	_armchair(Vector3(-13.2, 0, z0 + 6.8), -120.0)
	_solid("SideTable", Vector3(0.6, 0.5, 0.6), Vector3(-13.9, 0.25, z0 + 5.6), "wood")
	_deco("Books", Vector3(0.3, 0.08, 0.22), Vector3(-13.9, 0.54, z0 + 5.6), "teal")
	_solid("FloorLampPole", Vector3(0.06, 1.6, 0.06), Vector3(-13.9, 0.8, z0 + 3.3), "soot")
	_deco("FloorLampShade", Vector3(0.45, 0.35, 0.45), Vector3(-13.9, 1.7, z0 + 3.3), "glow")
	# Desk and bookshelf by the east wall.
	_solid("Desk", Vector3(0.65, 0.05, 1.5), Vector3(13.85, 0.75, z0 + 3.2), "wood")
	for c: Vector2 in [Vector2(-0.28, -0.7), Vector2(0.28, -0.7), Vector2(-0.28, 0.7), Vector2(0.28, 0.7)]:
		_solid("DeskLeg", Vector3(0.04, 0.73, 0.04), Vector3(13.85 + c.x, 0.365, z0 + 3.2 + c.y), "wood")
	_deco("Screen", Vector3(0.03, 0.3, 0.5), Vector3(14.1, 0.95, z0 + 3.2), "soot")
	_deco("DeskLamp", Vector3(0.12, 0.18, 0.12), Vector3(13.9, 0.87, z0 + 2.6), "glow")
	_chair(Vector3(13.1, 0, z0 + 3.2), 90.0)
	_solid("Bookshelf", Vector3(0.4, 2.0, 2.2), Vector3(14.25, 1.0, z0 + 6.0), "wood")
	for i in 4:
		var y := 0.35 + i * 0.45
		_deco("Shelf", Vector3(0.42, 0.03, 2.1), Vector3(14.04, y - 0.18, z0 + 6.0), "soot")
		for b in 5:
			var mat := "teal" if (i + b) % 3 == 0 else ("fabric" if (i + b) % 3 == 1 else "gold")
			_deco("Book", Vector3(0.22, 0.3, 0.16), Vector3(14.0, y, z0 + 5.3 + b * 0.35), mat)
	# Plants in the corners.
	for at: Vector3 in [Vector3(-13.9, 0, z1 - 0.6), Vector3(13.9, 0, z1 - 0.6), Vector3(-13.9, 0, z0 + 0.6), Vector3(9.5, 0, z0 + 0.6)]:
		_solid("Pot", Vector3(0.5, 0.5, 0.5), at + Vector3(0, 0.25, 0), "pot")
		_deco("Plant", Vector3(0.7, 0.9, 0.7), at + Vector3(0, 0.95, 0), "leaf")
		_deco("PlantTop", Vector3(0.45, 0.45, 0.45), at + Vector3(0, 1.55, 0), "leaf")
	# Pictures on the side walls.
	for p: Array in [[Vector3(-DORM_X + 0.02, 2.1, z0 + 7.0), "teal"], [Vector3(-DORM_X + 0.02, 2.1, z0 + 9.5), "gold"],
			[Vector3(DORM_X - 0.02, 2.2, z0 + 9.0), "fabric"]]:
		_deco("PictureFrame", Vector3(0.03, 1.0, 1.4), p[0], "wood")
		_deco("Picture", Vector3(0.04, 0.8, 1.2), p[0], p[1])
	for x: float in [-9.0, 0.0, 9.0]:
		_deco("CeilingLight", Vector3(2.0, 0.05, 0.6), Vector3(x, 3.97, cz), "glow")
		var light := OmniLight3D.new()
		light.name = "DormLight%d" % _next()
		light.position = Vector3(x, 3.5, cz)
		light.omni_range = 10.0
		light.light_energy = 1.3
		light.light_color = Color(1.0, 0.9, 0.78)
		_add(_geo, light)
	_label("BEDROOM", Vector3(0, 3.3, Z1 - 0.05), 64, 180.0) # On the hub side of the wall.


## Beyond the walls, just for looks (no collision, no way out): grass to the horizon, a ring
## of mountains, apartment blocks (their windows light up at night: "night_windows"), and
## pine trees close round the walls, tall enough to show over them.
func _scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2610
	var out := _node(_root, "Scenery")
	var cx := (X0 + X1) * 0.5
	var cz := (Z0 + Z1 + DORM_DEPTH) * 0.5
	_flat("grass", Color(0.3, 0.38, 0.2))
	_flat("rock", Color(0.34, 0.41, 0.53)) # Blue-grey: hazy with distance.
	_flat("snow", Color(0.86, 0.91, 0.98))
	_flat("bark", Color(0.3, 0.2, 0.12))
	_flat("pine", Color(0.15, 0.3, 0.17))
	_flat("roof", Color(0.22, 0.22, 0.24))
	var ground := MeshInstance3D.new()
	ground.name = "Grass"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	ground.mesh = pm
	ground.material_override = _mat["grass"]
	ground.position = Vector3(cx, -0.03, cz)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(out, ground)

	# Mountains: low-poly cones in a ring, snow on the tall ones.
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.12, 0.12)
		var dist := rng.randf_range(330.0, 440.0)
		var r := rng.randf_range(80.0, 140.0)
		var h := rng.randf_range(70.0, 150.0)
		var at := Vector3(cx + cos(a) * dist, 0, cz + sin(a) * dist)
		_cone(out, "Mountain", r, h, at + Vector3(0, h * 0.5 - 4.0, 0), rng.randi_range(5, 8), "rock", rng.randf() * TAU)
		if h > 100.0:
			_cone(out, "Snow", r * 0.32, h * 0.32, at + Vector3(0, h - 4.0 - h * 0.16 + 0.5, 0), 6, "snow", rng.randf() * TAU)

	# Apartment blocks: rows behind the north wall, out east and west.
	var windows := _window_material()
	var blocks: Array = []
	for i in 7:
		blocks.append(Vector3(-55 + i * 22 + rng.randf_range(-4, 4), 0, Z0 - rng.randf_range(55, 95)))
	for i in 4:
		blocks.append(Vector3(X1 + rng.randf_range(55, 80), 0, -40 + i * 26))
		blocks.append(Vector3(X0 - rng.randf_range(55, 80), 0, -40 + i * 26))
	for b: Vector3 in blocks:
		var size := Vector3(rng.randf_range(14, 24), rng.randf_range(18, 46), rng.randf_range(12, 18))
		var block := MeshInstance3D.new()
		block.name = "Apartments%d" % _next()
		var bm := BoxMesh.new()
		bm.size = size
		block.mesh = bm
		block.material_override = windows
		block.position = b + Vector3(0, size.y * 0.5, 0)
		block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		block.add_to_group("night_windows", true)
		_add(out, block)
		_mesh(out, "Roof", Vector3(size.x + 0.6, 0.8, size.z + 0.6), b + Vector3(0, size.y + 0.4, 0), Vector3.ZERO, "roof")

	# Scattered pines round the walls: three sparse rows, well spread out and a little taller the
	# further out, so the buildings and mountains still show between and over them from the range.
	# Baked into one mesh for the trunks and one for the needles.
	var spots: Array[Transform3D] = []
	var min_x := X0 - 3.0
	var max_x := X1 + 3.0
	var min_z := Z0 - 3.0
	var max_z := Z1 + DORM_DEPTH + 3.0
	for row in 3:
		var off := 6.0 + row * 14.0
		var step := 14.0 + row * 6.0
		var edges := [[Vector2(min_x - off, min_z - off), Vector2(max_x + off, min_z - off)],
				[Vector2(max_x + off, min_z - off), Vector2(max_x + off, max_z + off)],
				[Vector2(max_x + off, max_z + off), Vector2(min_x - off, max_z + off)],
				[Vector2(min_x - off, max_z + off), Vector2(min_x - off, min_z - off)]]
		for e: Array in edges:
			var a2: Vector2 = e[0]
			var b2: Vector2 = e[1]
			var n := int(a2.distance_to(b2) / step)
			for k in n:
				var p := a2.lerp(b2, (k + rng.randf_range(0.0, 0.8)) / n) + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
				var s := rng.randf_range(0.8 + row * 0.15, 1.25 + row * 0.25)
				spots.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, 0, p.y)))
	_forest(out, spots)


## Apartment walls: concrete with a grid of windows (a small texture tiled every 4 m across
## the walls), and a glow map with some windows lit, turned up at night by hub.gd.
func _window_material() -> StandardMaterial3D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var glow := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(0.62, 0.6, 0.57))
	glow.fill(Color.BLACK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for cy in 2:
		for cxi in 2:
			var r := Rect2i(cxi * 16 + 4, cy * 16 + 4, 9, 8)
			img.fill_rect(r, Color(0.16, 0.22, 0.3))
			if rng.randf() < 0.6:
				glow.fill_rect(r, Color(1.0, 0.82, 0.5))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.emission_enabled = true
	m.emission_texture = ImageTexture.create_from_image(glow)
	m.emission_energy_multiplier = 0.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.9
	return m


func _cone(parent: Node, n: String, radius: float, height: float, at: Vector3, sides: int, mat: String, yaw: float) -> void:
	var m := MeshInstance3D.new()
	m.name = "%s%d" % [n, _next()]
	m.mesh = _cylinder_mesh(0.0, radius, height, sides)
	m.material_override = _mat[mat]
	m.position = at
	m.rotation.y = yaw
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, m)


func _cylinder_mesh(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


## Every tree at `spots` (each a trunk and two tiers of needles) baked into two meshes, one
## for the bark and one for the needles, saved next to the scene (FOREST_MESHES). Not a
## MultiMesh: generated headless, a MultiMesh comes out with no trees in it.
func _forest(parent: Node, spots: Array[Transform3D]) -> void:
	var trunk := _cylinder_mesh(0.35, 0.45, 4.0, 6)
	var low := _cylinder_mesh(0.0, 3.6, 7.0, 7)
	var high := _cylinder_mesh(0.0, 2.6, 5.5, 7)
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var needles := SurfaceTool.new()
	needles.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t: Transform3D in spots:
		bark.append_from(trunk, 0, Transform3D(t.basis, t.origin + t.basis * Vector3(0, 2.0, 0)))
		needles.append_from(low, 0, Transform3D(t.basis, t.origin + t.basis * Vector3(0, 6.5, 0)))
		needles.append_from(high, 0, Transform3D(t.basis, t.origin + t.basis * Vector3(0, 10.0, 0)))
	for part: Array in [["Trunks", bark, "bark"], ["Needles", needles, "pine"]]:
		var path: String = FOREST_MESHES % String(part[0]).to_lower()
		ResourceSaver.save((part[1] as SurfaceTool).commit(), path)
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = load(path) # Referenced from its own file, not written out into the scene.
		mi.material_override = _mat[part[2]]
		_add(parent, mi)


# --- Building blocks ---------------------------------------------------------------------

## A deck at `top` over the box from `a` to `b` (x/z corners): a 0.4 m slab on pillars.
func _platform(n: String, a: Vector3, b: Vector3, top: float) -> void:
	var lo := Vector3(minf(a.x, b.x), 0, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), 0, maxf(a.z, b.z))
	var size := hi - lo
	_solid(n, Vector3(size.x, 0.4, size.z), Vector3((lo.x + hi.x) * 0.5, top - 0.2, (lo.z + hi.z) * 0.5), "grid_light")
	for c: Vector2 in [Vector2(lo.x, lo.z), Vector2(hi.x, lo.z), Vector2(lo.x, hi.z), Vector2(hi.x, hi.z)]:
		var p := Vector3(clampf(c.x, lo.x + 0.4, hi.x - 0.4), (top - 0.4) * 0.5, clampf(c.y, lo.z + 0.4, hi.z - 0.4))
		_solid(n + "Pillar", Vector3(0.5, top - 0.4, 0.5), p, "grid_blue")


## Stairs from `start` (the middle of the bottom step's front edge) going `dir`, climbing
## `rise` over `run` metres in `steps` steps, `width` wide. The steps are just for looks:
## you walk up a hidden ramp under them, so you glide up rather than catching on each edge.
func _stairs(n: String, start: Vector3, dir: Vector3, run: float, rise: float, width: float, steps: int) -> void:
	var d := run / steps
	var holder := _node(_geo, "%s%d" % [n, _next()])
	for i in steps:
		var h := rise * (i + 1) / steps
		var length := run - i * d
		var step := MeshInstance3D.new()
		step.name = "Step%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(width, h, length)
		step.mesh = bm
		step.material_override = _mat["grid_light"]
		step.position = start + dir * (i * d + length * 0.5) + Vector3.UP * (h * 0.5)
		step.basis = Basis.looking_at(dir, Vector3.UP)
		_add(holder, step)
	_ramp(n + "Ramp", start, start + dir * run + Vector3.UP * rise, width, holder, false) # Collision only.
	# Solid underneath, so nothing walks under it.
	var fill := _solid(n + "Fill", Vector3(width, rise * 0.5, run * 0.5), start + dir * (run * 0.75) + Vector3.UP * (rise * 0.25),
			"grid_light", holder, false)
	fill.basis = Basis.looking_at(dir, Vector3.UP)


## A slope from `low` up to `high` (the middles of its bottom and top edges), `width` wide.
func _ramp(n: String, low: Vector3, high: Vector3, width: float, parent: Node = null, visible: bool = true) -> StaticBody3D:
	var along := high - low
	var t := 0.5
	var body := _solid(n, Vector3(width, t, along.length()), Vector3.ZERO, "grid_light", parent, visible)
	body.basis = Basis.looking_at(along.normalized(), Vector3.UP) # The box's length runs up the slope.
	var up := body.basis.y
	body.position = (low + high) * 0.5 - up * (t * 0.5)
	return body


## A bench: a seat on two legs with a backrest, `length` long, facing `yaw` (0 = north).
func _bench(at: Vector3, yaw: float, length: float) -> void:
	var holder := _node(_geo, "Bench%d" % _next())
	holder.position = at
	holder.rotation_degrees.y = yaw
	_solid("Seat", Vector3(length, 0.1, 0.5), Vector3(0, 0.45, 0), "grid_orange", holder)
	for x: float in [-length * 0.5 + 0.2, length * 0.5 - 0.2]:
		_solid("Leg", Vector3(0.1, 0.4, 0.45), Vector3(x, 0.2, 0), "grid_blue", holder)
	_solid("Back", Vector3(length, 0.5, 0.08), Vector3(0, 0.8, 0.27), "grid_orange", holder)


## A solid box: StaticBody3D with a mesh and a collision shape. Under Geometry unless told.
func _solid(n: String, size: Vector3, at: Vector3, mat: String, parent: Node = null, visible: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "%s%d" % [n, _next()]
	body.position = at
	_add(parent if parent != null else _geo, body)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _mat[mat]
	if visible:
		_add(body, mesh)
	else:
		mesh.free()
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	_add(body, shape)
	return body


## A box you can't touch (floor markings, panels on walls).
func _deco(n: String, size: Vector3, at: Vector3, mat: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "%s%d" % [n, _next()]
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _mat[mat]
	mesh.position = at
	_add(_geo, mesh)


func _label(text: String, at: Vector3, font_size: int, yaw: float = 0.0, flat: bool = false) -> void:
	var l := Label3D.new()
	l.name = "Label%d" % _next()
	l.text = text
	l.font_size = font_size
	l.outline_size = 18
	l.pixel_size = 0.01
	l.position = at
	l.rotation_degrees = Vector3(-90 if flat else 0, yaw, 0)
	_add(_labels, l)


func _script_node(parent: Node, n: String, node: Node3D, script: String, at: Vector3, yaw: float = 0.0, values: Dictionary = {}) -> Node3D:
	node.name = n
	node.set_script(load(script))
	node.position = at
	node.rotation_degrees.y = yaw
	for k: String in values:
		node.set(k, values[k])
	_add(parent, node)
	return node


func _node(parent: Node, n: String) -> Node3D:
	var node := Node3D.new()
	node.name = n
	_add(parent, node)
	return node


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child, true)
	child.owner = _root


func _next() -> int:
	_n += 1
	return _n
