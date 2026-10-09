extends SceneTree
## Generates the Research Complex room modules: scenes/rooms/research/*.tscn
##   godot --headless -s tools/build_rooms.gd
## These are starting greyboxes for you to edit by hand in the editor. Rerunning
## overwrites every room listed in _process(), so once you've hand-edited a room, take it
## out of that list.
##
## A room: its footprint on the 24 m grid (cell (0, 0) centred on the room's origin), its
## doorways (cell + side), cover and props (boxes and ramps), where its enemies stand,
## where supplies can be left, its crates (physics props), and its objective pieces. Floors and the outer walls are
## built from the footprint, with a DOOR_W x DOOR_H gap wherever there's a doorway.
## Inside rooms get a ceiling (just a mesh, for the look and the shade) and lights; the
## yard outside doesn't. See scripts/expedition/room.gd.

const OUT := "res://scenes/rooms/research/"
const CELL := 24.0
const HALF := 12.0
const IN := 11.75 ## Inside face of the outer walls, from a cell's centre.
const WALL_T := 0.5
const WALL_H := 6.0
const DOOR_W := 4.4
const DOOR_H := 3.6

const N := Vector2i(0, -1)
const E := Vector2i(1, 0)
const S := Vector2i(0, 1)
const W := Vector2i(-1, 0)

const MATERIALS := {
	floor = "res://materials/grid_dark.tres",
	wall = "res://materials/grid_light.tres",
	cover = "res://materials/grid_blue.tres",
	accent = "res://materials/grid_orange.tres",
}

var _root: Node3D
var _count := 0


# Built on the first frame rather than in _init: by then the autoloads exist, so the
# room, breaker and console scripts compile when they're attached.
func _process(_delta: float) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_yard()
	_airlock()
	_corridor()
	_corner()
	_junction()
	_lab()
	_office()
	_atrium()
	_server_room()
	_generator_room()
	_extraction()
	print("Built %d rooms in %s" % [_count, OUT])
	return true


# --- Rooms -------------------------------------------------------------------------------

## Outside, where the squad arrives: an open yard (1 x 2 cells, no roof) in front of the
## facility, and the breach door that's the only way in.
func _yard() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	_begin("Yard", Room.Kind.START, cells, [[Vector2i(0, 0), N]], 0, false)
	_box("Truck", Vector3(-7.5, 1.4, 20.0), Vector3(2.6, 2.8, 7.0), "accent")
	_box("TruckCab", Vector3(-7.5, 1.1, 15.4), Vector3(2.6, 2.2, 2.2), "accent")
	for p: Vector3 in [Vector3(-4.0, 0.5, 2.0), Vector3(4.0, 0.5, 2.0), Vector3(7.5, 0.5, 9.0), Vector3(-1.5, 0.5, 11.0)]:
		_box("Barrier", p, Vector3(3.0, 1.0, 0.6), "cover")
	_crate(Vector3(8.5, 1.2, 24.0), Vector3(2.4, 2.4, 2.4))
	_crate(Vector3(6.4, 0.6, 24.6), Vector3(1.2, 1.2, 1.2))
	_box("Booth", Vector3(9.0, 1.4, -6.0), Vector3(3.0, 2.8, 3.0), "wall")
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0.0, 0.05, 28.0) # Facing the facility (-Z); players line up behind.
	_add(_root, spawn)
	spawn.add_to_group("player_spawns", true)
	# The door sits in the doorway, its front (-Z) facing the yard.
	_piece("BreachDoor", "res://scripts/expedition/breach_door.gd", Vector3(0.0, 0.0, -HALF + WALL_T * 0.5), 180.0)
	_supply(Vector3(9.0, 0.0, -3.5))
	_save("yard")


## Just inside: a decontamination hall with benches.
func _airlock() -> void:
	_begin("Airlock", Room.Kind.CORRIDOR, [Vector2i.ZERO], [[Vector2i.ZERO, N], [Vector2i.ZERO, S]], 2)
	_box("SideWall", Vector3(-6.75, WALL_H * 0.5, 0.0), Vector3(0.5, WALL_H, CELL - 1.0), "wall")
	_box("SideWall2", Vector3(6.75, WALL_H * 0.5, 0.0), Vector3(0.5, WALL_H, CELL - 1.0), "wall")
	_box("Bench", Vector3(-5.5, 0.45, -2.0), Vector3(1.2, 0.9, 6.0), "cover")
	_box("Bench2", Vector3(5.5, 0.45, 3.0), Vector3(1.2, 0.9, 6.0), "cover")
	for z: float in [-6.0, 6.0]:
		for x: float in [-3.6, 3.6]:
			_box("Frame", Vector3(x, 1.9, z), Vector3(0.5, 3.8, 0.5), "accent")
	_enemy(Vector3(0.0, 0.0, -8.0))
	_enemy(Vector3(2.5, 0.0, 8.5))
	_supply(Vector3(-5.5, 0.9, 1.5))
	_save("airlock")


## A 9 m wide hall straight through, with cover.
func _corridor() -> void:
	_begin("Corridor", Room.Kind.CORRIDOR, [Vector2i.ZERO], [[Vector2i.ZERO, N], [Vector2i.ZERO, S]], 3)
	_box("SideWall", Vector3(-4.75, WALL_H * 0.5, 0.0), Vector3(0.5, WALL_H, CELL - 1.0), "wall")
	_box("SideWall2", Vector3(4.75, WALL_H * 0.5, 0.0), Vector3(0.5, WALL_H, CELL - 1.0), "wall")
	_box("Barrier", Vector3(2.0, 0.55, 3.0), Vector3(2.6, 1.1, 0.5), "cover")
	_box("Barrier2", Vector3(-2.0, 0.55, -4.5), Vector3(2.6, 1.1, 0.5), "cover")
	_crate(Vector3(3.2, 0.6, -9.0), Vector3(1.2, 1.2, 1.2))
	_enemy(Vector3(0.0, 0.0, -8.5))
	_enemy(Vector3(-2.5, 0.0, 8.0))
	_enemy(Vector3(2.5, 0.0, 0.0))
	_save("corridor")


## An L-shaped turn: in from one side, out the other.
func _corner() -> void:
	_begin("Corner", Room.Kind.CORRIDOR, [Vector2i.ZERO], [[Vector2i.ZERO, N], [Vector2i.ZERO, E]], 3)
	_box("Block", Vector3(-8.125, WALL_H * 0.5, 0.0), Vector3(7.25, WALL_H, CELL - 1.0), "wall")
	_box("Block2", Vector3(3.625, WALL_H * 0.5, 8.125), Vector3(16.25, WALL_H, 7.25), "wall")
	_box("Pillar", Vector3(4.5, WALL_H * 0.5, -4.5), Vector3(1.6, WALL_H, 1.6), "wall")
	_crate(Vector3(-2.5, 0.6, -9.5), Vector3(1.2, 1.2, 1.2))
	_enemy(Vector3(8.0, 0.0, -8.0))
	_enemy(Vector3(-2.0, 0.0, 2.0))
	_enemy(Vector3(9.0, 0.0, 1.5))
	_save("corner")


## A T: three ways on, pillars to duck behind.
func _junction() -> void:
	_begin("Junction", Room.Kind.CORRIDOR, [Vector2i.ZERO], [[Vector2i.ZERO, N], [Vector2i.ZERO, E], [Vector2i.ZERO, W]], 4)
	_box("Block", Vector3(0.0, WALL_H * 0.5, 8.125), Vector3(CELL - 1.0, WALL_H, 7.25), "wall")
	_box("Pillar", Vector3(-6.0, WALL_H * 0.5, -4.5), Vector3(1.6, WALL_H, 1.6), "wall")
	_box("Pillar2", Vector3(6.0, WALL_H * 0.5, -4.5), Vector3(1.6, WALL_H, 1.6), "wall")
	_box("Barrier", Vector3(0.0, 0.55, 0.5), Vector3(3.0, 1.1, 0.5), "cover")
	_enemy(Vector3(8.5, 0.0, -8.5))
	_enemy(Vector3(-8.5, 0.0, -8.5))
	_enemy(Vector3(0.0, 0.0, -9.5))
	_enemy(Vector3(0.0, 0.0, 2.5))
	_save("junction")


## Lab benches (crouch cover) around a tall fume hood. Doors on every side.
func _lab() -> void:
	_begin("Lab", Room.Kind.COMBAT, [Vector2i.ZERO], [[Vector2i.ZERO, N], [Vector2i.ZERO, E], [Vector2i.ZERO, S], [Vector2i.ZERO, W]], 8)
	for p: Vector3 in [Vector3(-6, 0.5, -5.5), Vector3(6, 0.5, -5.5), Vector3(-6, 0.5, 5.5), Vector3(6, 0.5, 5.5)]:
		_box("Bench", p, Vector3(7.0, 1.0, 1.4), "cover")
	_box("FumeHood", Vector3(0.0, 1.2, 0.0), Vector3(3.5, 2.4, 3.5), "accent")
	_box("Shelf", Vector3(-10.6, 1.1, -8.0), Vector3(1.2, 2.2, 5.0), "wall")
	_box("Shelf2", Vector3(10.6, 1.1, 8.0), Vector3(1.2, 2.2, 5.0), "wall")
	for p: Vector3 in [Vector3(-9, 0, -9), Vector3(9, 0, -9), Vector3(9, 0, 9), Vector3(-9, 0, 9), Vector3(0, 0, -9), Vector3(0, 0, 9),
			Vector3(-9, 0, 0), Vector3(9, 0, 0)]:
		_enemy(p)
	_supply(Vector3(-6.0, 1.0, -5.5))
	_supply(Vector3(6.0, 1.0, 5.5))
	_save("lab")


## Rows of cubicles either side of a central aisle.
func _office() -> void:
	_begin("Office", Room.Kind.COMBAT, [Vector2i.ZERO], [[Vector2i.ZERO, N], [Vector2i.ZERO, S]], 7)
	for x: float in [-6.0, 6.0]:
		_box("Partition", Vector3(x, 0.8, 0.0), Vector3(0.2, 1.6, 15.0), "cover")
		var outward := signf(x)
		for z: float in [-7.5, -2.5, 2.5, 7.5]:
			_box("Partition", Vector3(x + outward * 2.75, 0.8, z), Vector3(5.3, 1.6, 0.2), "cover")
		_box("Desk", Vector3(x + outward * 3.0, 0.4, -5.0), Vector3(2.0, 0.8, 1.0), "accent")
		_box("Desk", Vector3(x + outward * 3.0, 0.4, 5.0), Vector3(2.0, 0.8, 1.0), "accent")
	_box("Printer", Vector3(2.0, 0.6, 0.0), Vector3(1.2, 1.2, 1.2), "wall")
	for p: Vector3 in [Vector3(-9, 0, 0), Vector3(9, 0, 0), Vector3(0, 0, -9), Vector3(-9, 0, -10), Vector3(9, 0, 10),
			Vector3(0, 0, 9), Vector3(9, 0, -10)]:
		_enemy(p)
	_supply(Vector3(-9.0, 0.8, -5.0))
	_supply(Vector3(9.0, 0.8, 5.0))
	_save("office")


## The big one (2 x 2 cells): a raised platform with ramps up to it, and a catwalk along
## the north wall reached from the platform. Room to slide, jump and flank.
func _atrium() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	_begin("Atrium", Room.Kind.COMBAT, cells,
			[[Vector2i(0, 0), N], [Vector2i(1, 0), E], [Vector2i(1, 1), S], [Vector2i(0, 1), W]], 12)
	_box("Platform", Vector3(12.0, 1.25, 12.0), Vector3(12.0, 2.5, 12.0), "cover")
	_ramp("RampEast", Vector3(25.5, 0.0, 12.0), Vector3(18.0, 2.5, 12.0), 4.0)
	_ramp("RampWest", Vector3(-1.5, 0.0, 12.0), Vector3(6.0, 2.5, 12.0), 4.0)
	_ramp("RampCatwalk", Vector3(12.0, 2.5, 6.0), Vector3(12.0, 4.0, -8.0), 3.0)
	_box("Catwalk", Vector3(12.0, 3.85, -9.625), Vector3(46.0, 0.3, 3.25), "accent")
	for p: Vector3 in [Vector3(0, WALL_H * 0.5, 0), Vector3(24, WALL_H * 0.5, 0), Vector3(0, WALL_H * 0.5, 24), Vector3(24, WALL_H * 0.5, 24)]:
		_box("Pillar", p, Vector3(2.0, WALL_H, 2.0), "wall")
	for p: Vector3 in [Vector3(3, 0.6, 30), Vector3(21, 0.6, 30), Vector3(30, 0.6, 20), Vector3(-6, 0.6, 18), Vector3(18, 0.6, 3)]:
		_crate(p, Vector3(1.4, 1.2, 1.4))
	for p: Vector3 in [Vector3(12, 2.5, 12), Vector3(4, 4, -9.6), Vector3(20, 4, -9.6), Vector3(30, 0, 30), Vector3(-6, 0, 30),
			Vector3(30, 0, -4), Vector3(-6, 0, -4), Vector3(12, 0, 28), Vector3(12, 4, -9.6), Vector3(28, 4, -9.6),
			Vector3(12, 2.5, 16), Vector3(30, 0, 12)]:
		_enemy(p)
	_supply(Vector3(12.0, 2.5, 12.0))
	_supply(Vector3(-9.0, 0.0, 33.0))
	_supply(Vector3(33.0, 0.0, -9.0))
	_save("atrium")


## Objective: server racks in aisles, the breaker at the back.
func _server_room() -> void:
	_begin("ServerRoom", Room.Kind.OBJECTIVE, [Vector2i.ZERO], [[Vector2i.ZERO, S], [Vector2i.ZERO, N]], 6)
	for x: float in [-9.0, -4.5, 4.5, 9.0]:
		_box("Rack", Vector3(x, 1.3, 0.0), Vector3(1.2, 2.6, 13.0), "cover")
	_piece("Breaker", "res://scripts/expedition/breaker.gd", Vector3(-10.9, 0.0, -9.5), -90.0)
	for p: Vector3 in [Vector3(6.75, 0, 9), Vector3(-6.75, 0, 9), Vector3(0, 0, -8.5), Vector3(6.75, 0, -9), Vector3(0, 0, 8.5),
			Vector3(-6.75, 0, 0)]:
		_enemy(p)
	_supply(Vector3(10.5, 0.0, 9.5))
	_save("server_room")


## Objective: a big generator with the breaker on its side, pipes along the wall.
func _generator_room() -> void:
	_begin("GeneratorRoom", Room.Kind.OBJECTIVE, [Vector2i.ZERO], [[Vector2i.ZERO, S], [Vector2i.ZERO, E]], 6)
	_box("Generator", Vector3(-3.0, 2.0, -3.0), Vector3(7.0, 4.0, 7.0), "accent")
	_box("Pipes", Vector3(0.0, 4.6, -11.0), Vector3(21.0, 0.8, 0.8), "wall")
	_box("Tank", Vector3(-9.3, 1.4, 7.5), Vector3(3.0, 2.8, 4.0), "cover")
	_crate(Vector3(6.5, 0.6, 4.5), Vector3(1.4, 1.2, 1.4))
	_crate(Vector3(7.5, 0.6, -7.0), Vector3(1.4, 1.2, 1.4))
	_piece("Breaker", "res://scripts/expedition/breaker.gd", Vector3(-3.0, 0.0, 0.7), 180.0)
	for p: Vector3 in [Vector3(7.5, 0, -9), Vector3(-9, 0, 1), Vector3(7.5, 0, 9), Vector3(1, 0, -9.5), Vector3(3, 0, 9),
			Vector3(-9, 0, -9)]:
		_enemy(p)
	_supply(Vector3(-9.3, 2.8, 7.5))
	_save("generator_room")


## Two cells: the pad and the console by the way in; the far end is where the wave
## breaches from once the extraction starts, with cover to hold them off.
func _extraction() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, -1)]
	_begin("Extraction", Room.Kind.EXTRACTION, cells, [[Vector2i(0, 0), S]], 8)
	var pad := Node3D.new()
	pad.name = "ExtractionPad"
	pad.set_script(load("res://scripts/expedition/extraction_pad.gd"))
	pad.position = Vector3(0.0, 0.0, -2.0)
	pad.set("size", Vector2(10, 10))
	_add(_root, pad)
	_piece("ExtractionConsole", "res://scripts/expedition/extraction_console.gd", Vector3(-8.0, 0.0, 7.5), 180.0)
	for p: Vector3 in [Vector3(-6.0, 0.6, -9.0), Vector3(6.0, 0.6, -9.0), Vector3(0.0, 0.6, -9.6)]:
		_box("Barricade", p, Vector3(3.4, 1.2, 0.5), "cover")
	for p: Vector3 in [Vector3(-4.5, 0.6, -18), Vector3(4.5, 0.6, -18), Vector3(0, 0.6, -25), Vector3(-8, 0.6, -27), Vector3(8, 0.6, -23)]:
		_crate(p, Vector3(2.0, 1.2, 1.4))
	for p: Vector3 in [Vector3(-7, 0, -32), Vector3(7, 0, -32), Vector3(0, 0, -33.5), Vector3(-9, 0, -22), Vector3(9, 0, -22), Vector3(0, 0, -29),
			Vector3(-4, 0, -30), Vector3(4, 0, -30)]:
		_enemy(p, Vector3(0, 0, 0))
	_supply(Vector3(8.0, 0.0, 8.5))
	_save("extraction")


# --- Building blocks ---------------------------------------------------------------------

## Starts a room: root with room.gd, floor under every cell, outer walls with doorway gaps,
## a door marker per doorway and, inside, a ceiling and a light per cell.
func _begin(room_name: String, kind: Room.Kind, cells: Array[Vector2i], doors: Array, max_enemies: int, indoors: bool = true) -> void:
	_root = Node3D.new()
	_root.name = room_name
	_root.set_script(load("res://scripts/expedition/room.gd"))
	_root.set("kind", kind)
	_root.set("cells", cells)
	_root.set("max_enemies", max_enemies)
	_node(_root, "Geometry")
	_node(_root, "Doors")
	_node(_root, "EnemySpawns")
	_node(_root, "Supplies")
	_node(_root, "Props")
	for c in cells:
		var centre := Vector3(c.x * CELL, 0.0, c.y * CELL)
		_box("Floor", centre + Vector3(0.0, -0.25, 0.0), Vector3(CELL, 0.5, CELL), "floor")
		if indoors:
			_ceiling(centre)
		for d: Vector2i in [N, E, S, W]:
			if cells.has(c + d):
				continue
			var has_door := false
			for door: Array in doors:
				if door[0] == c and door[1] == d:
					has_door = true
			_wall(centre, d, has_door)
	for door: Array in doors:
		var c: Vector2i = door[0]
		var d: Vector2i = door[1]
		var m := Marker3D.new()
		m.name = "Door"
		m.position = Vector3(c.x * CELL + d.x * HALF, 0.0, c.y * CELL + d.y * HALF)
		m.rotation.y = atan2(-float(d.x), -float(d.y)) # -Z faces out of the room.
		_add(_root.get_node("Doors"), m)


## The outer wall along one side of a cell, set just inside the cell. With a doorway it's
## two pieces and a lintel over the gap.
func _wall(centre: Vector3, d: Vector2i, door: bool) -> void:
	var along_x := d.x == 0 # North and south walls run along X.
	var mid := centre + Vector3(d.x, 0.0, d.y) * (HALF - WALL_T * 0.5)
	var run := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var size_for := func(length: float, height: float) -> Vector3:
		return Vector3(length, height, WALL_T) if along_x else Vector3(WALL_T, height, length)
	if not door:
		_box("Wall", mid + Vector3.UP * WALL_H * 0.5, size_for.call(CELL, WALL_H), "wall")
		return
	var piece := (CELL - DOOR_W) * 0.5
	for side: float in [-1.0, 1.0]:
		_box("Wall", mid + run * side * (DOOR_W * 0.5 + piece * 0.5) + Vector3.UP * WALL_H * 0.5,
				size_for.call(piece, WALL_H), "wall")
	_box("Lintel", mid + Vector3.UP * (DOOR_H + (WALL_H - DOOR_H) * 0.5), size_for.call(DOOR_W, WALL_H - DOOR_H), "wall")


## A roof over one cell (a mesh only: nobody can get up there, and it keeps the
## navigation mesh off the roof) and a light under it.
func _ceiling(centre: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "Ceiling"
	var bm := BoxMesh.new()
	bm.size = Vector3(CELL, 0.5, CELL)
	mesh.mesh = bm
	mesh.material_override = load(MATERIALS.wall)
	mesh.position = centre + Vector3.UP * (WALL_H + 0.25)
	_add(_root.get_node("Geometry"), mesh)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(0.9, 0.95, 1.0)
	light.light_energy = 1.4
	light.omni_range = 20.0
	light.position = centre + Vector3.UP * (WALL_H - 0.7)
	_add(_root.get_node("Geometry"), light)


## A solid box: StaticBody3D with a mesh and a matching collision shape.
func _box(box_name: String, centre: Vector3, size: Vector3, material: String, basis: Basis = Basis()) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.transform = Transform3D(basis, centre)
	_add(_root.get_node("Geometry"), body)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = load(MATERIALS[material])
	_add(body, mesh)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	_add(body, shape)


## A ramp: a thin slab whose top runs from `from` (the low edge's middle) to `to` (the
## high edge's middle).
func _ramp(ramp_name: String, from: Vector3, to: Vector3, width: float) -> void:
	var x := (to - from).normalized()
	var w := Vector3.UP.cross(x).normalized()
	var y := x.cross(w)
	var basis := Basis(x, y, x.cross(y))
	var thickness := 0.4
	_box(ramp_name, (from + to) * 0.5 - y * thickness * 0.5, Vector3(from.distance_to(to), thickness, width), "cover", basis)


## Where one of this room's enemies stands, facing `look_at` (default: the room's middle).
func _enemy(pos: Vector3, look_at: Variant = null) -> void:
	var target: Vector3 = look_at if look_at != null else _room_middle()
	var m := Marker3D.new()
	m.name = "Enemy"
	m.position = pos
	var to := target - pos
	if Vector2(to.x, to.z).length() > 0.01:
		m.rotation.y = atan2(-to.x, -to.z)
	_add(_root.get_node("EnemySpawns"), m)


## A crate you can push and shoot around: a PropSpawn (the host spawns a PhysicsProp
## there when the map loads). `centre` and `size` as for _box().
func _crate(centre: Vector3, size: Vector3) -> void:
	var m := Marker3D.new()
	m.name = "Crate"
	m.set_script(load("res://scripts/physics/prop_spawn.gd"))
	m.position = centre - Vector3.UP * size.y * 0.5
	m.set("size", size)
	m.set("mass", 12.0 * size.x * size.y * size.z + 8.0)
	_add(_root.get_node("Props"), m)


## Where a medkit might be left (on the floor, or on top of something).
func _supply(pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = "Supply"
	m.position = pos
	_add(_root.get_node("Supplies"), m)


## An objective piece (a scripted Node3D) facing `yaw_deg` (0 = its front faces -Z).
func _piece(piece_name: String, script: String, pos: Vector3, yaw_deg: float) -> void:
	var n := Node3D.new()
	n.name = piece_name
	n.set_script(load(script))
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	_add(_root, n)


func _room_middle() -> Vector3:
	var sum := Vector3.ZERO
	var cells: Array[Vector2i] = _root.get("cells")
	for c in cells:
		sum += Vector3(c.x * CELL, 0.0, c.y * CELL)
	return sum / cells.size()


func _save(file: String) -> void:
	var ps := PackedScene.new()
	ps.pack(_root)
	ResourceSaver.save(ps, OUT + file + ".tscn")
	_root.free()
	_count += 1


func _node(parent: Node, n: String) -> Node3D:
	var nd := Node3D.new()
	nd.name = n
	_add(parent, nd)
	return nd


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child, true)
	child.owner = _root
