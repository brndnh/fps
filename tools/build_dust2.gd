extends SceneTree
## Generates scenes/dust2.tscn: a greybox of de_dust2 built from its navigation mesh.
##   godot --headless -s tools/build_dust2.gd
## WARNING: overwrites scenes/dust2.tscn (and its dust2_*.res / radar image). Change the
## data or the code here and rerun rather than editing the scene.
##
## tools/data/dust2.txt comes from CS2's de_dust2 nav mesh (the walkable areas bots path
## on, with real floor heights), converted to metres and Godot axes. The converter evened
## out the sandy ground: near-level areas joined into flat floors, and slopes (stairs,
## ramps) meet those floors exactly, so there are no bumps or lips.
##   POLY bottom x,y,z ...    a walkable area: a flat floor or a slope. It's built as a solid
##                            block from its top surface down to `bottom`, so raised areas,
##                            stairs, crates and ramps are all solid. (Nav areas stop half a
##                            player-width short of walls; the converter pushed them back out.)
##   WALL x0 z0 x1 z1 top bottom   building: everywhere the nav mesh doesn't reach.
##   GRID / ROW               the same on a 0.5 m grid with floor heights, for the radar.
##   SPAWN, LOOK, LABEL, TARGET, ZONE, ROOF   where things go. (No weapon rack: racks
##   are only in the firing range; buy guns here instead.)
## Everything is one mesh and one collision shape, saved next to the scene.

const DATA := "res://tools/data/dust2.txt"
const RADAR_IMAGE := "res://textures/dust2_radar.png"

var _root: Node3D
var _mat := {}


# Built on the first frame rather than in _init: by then the autoloads (Settings, Sfx) exist,
# so the player, buy zone and spawner scripts compile when they're attached.
func _process(_delta: float) -> bool:
	_build()
	return true


func _build() -> void:
	_make_materials()
	_root = Node3D.new()
	_root.name = "Dust2"
	_environment()
	var floors := SurfaceTool.new()
	floors.begin(Mesh.PRIMITIVE_TRIANGLES)
	floors.set_smooth_group(-1) # Flat shading: every face lit on its own, crisp edges.
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	walls.set_smooth_group(-1)
	var places: Array = []
	var radar_rows: Array = []
	var grid := PackedStringArray()
	for line in FileAccess.get_file_as_string(DATA).split("\n"):
		if line.is_empty() or line.begins_with("#"):
			continue
		var f := line.split(" ", false)
		match f[0]:
			"POLY":
				_prism(floors, f)
			"WALL":
				_box(walls, Vector3(f[1].to_float(), f[6].to_float(), f[2].to_float()),
						Vector3(f[3].to_float(), f[5].to_float(), f[4].to_float()))
			"ROOF":
				_box(walls, Vector3(f[1].to_float(), f[5].to_float(), f[2].to_float()),
						Vector3(f[3].to_float(), f[5].to_float() + 0.5, f[4].to_float()))
			"GRID":
				grid = f
				# A floor under the whole map, so a gap can never drop you into the void.
				var x0 := f[3].to_float()
				var z0 := f[4].to_float()
				var size := f[5].to_float()
				_box(walls, Vector3(x0, -7.5, z0), Vector3(x0 + f[1].to_int() * size, -6.5, z0 + f[2].to_int() * size))
			"ROW":
				radar_rows.append(f[1])
			_:
				places.append(f)
	_level_geometry(floors, walls)
	_radar(grid, radar_rows)
	_props(places)
	var ps := PackedScene.new()
	ps.pack(_root)
	ResourceSaver.save(ps, "res://scenes/dust2.tscn")
	_root.free()
	print("Dust II built.")


# --- Geometry -----------------------------------------------------------------------------

## A nav area as a solid: its (possibly sloped) top, straight sides, flat bottom.
func _prism(st: SurfaceTool, f: PackedStringArray) -> void:
	var bottom := f[1].to_float()
	var top: Array[Vector3] = []
	var centre := Vector3.ZERO
	for k in range(2, f.size()):
		var c := f[k].split(",")
		top.append(Vector3(c[0].to_float(), c[1].to_float(), c[2].to_float()))
		centre += top[-1]
	var n := top.size()
	centre /= n
	# Triangulated properly, since pushing edges out can leave a nav area slightly concave.
	var outline := PackedVector2Array()
	for p in top:
		outline.append(Vector2(p.x, p.z))
	var tris := Geometry2D.triangulate_polygon(outline)
	if tris.is_empty(): # Outline crosses itself (a sharp corner pushed out): a fan still covers it.
		for k in range(1, n - 1):
			tris.append_array([0, k, k + 1])
	for k in range(0, tris.size(), 3):
		_face(st, top[tris[k]], top[tris[k + 1]], top[tris[k + 2]], Vector3.UP)
	for k in n:
		var a := top[k]
		var b := top[(k + 1) % n]
		var a2 := Vector3(a.x, bottom, a.z)
		var b2 := Vector3(b.x, bottom, b.z)
		var out := Vector3((a.x + b.x) * 0.5 - centre.x, 0.0, (a.z + b.z) * 0.5 - centre.z)
		_face(st, a, a2, b2, out)
		_face(st, a, b2, b, out)


## Axis-aligned box from min corner to max corner.
func _box(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	for q: Array in [[4, 5, 6, 7, Vector3.UP], [0, 1, 2, 3, Vector3.DOWN], [0, 1, 5, 4, Vector3.FORWARD],
			[3, 2, 6, 7, Vector3.BACK], [1, 2, 6, 5, Vector3.RIGHT], [0, 3, 7, 4, Vector3.LEFT]]:
		_face(st, c[q[0]], c[q[1]], c[q[2]], q[4])
		_face(st, c[q[0]], c[q[2]], c[q[3]], q[4])


## Adds a triangle that faces `out`. Godot draws a triangle's front where its corners run
## clockwise, which is where (b - a) x (c - a) points away from the viewer.
func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _level_geometry(floors: SurfaceTool, walls: SurfaceTool) -> void:
	var geo := _node(_root, "Geometry")
	var mesh := ArrayMesh.new()
	for pair: Array in [[floors, _mat.dust_sand], [walls, _mat.dust_wall]]:
		var st: SurfaceTool = pair[0]
		st.generate_normals()
		st.index()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	# Saved on their own (binary): as text they'd make the scene file megabytes long.
	ResourceSaver.save(mesh, "res://scenes/dust2_mesh.res")
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true # Solid from either side, whatever a face's winding.
	ResourceSaver.save(shape, "res://scenes/dust2_shape.res")
	var body := StaticBody3D.new()
	body.name = "Level"
	_add(geo, body)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = load("res://scenes/dust2_mesh.res")
	_add(body, mi)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = load("res://scenes/dust2_shape.res")
	_add(body, cs)


## Radar picture from the height grid: dark buildings, floor shaded by height (higher =
## lighter, like CS radars). The level's metadata tells radar.gd where it sits.
func _radar(grid: PackedStringArray, rows: Array) -> void:
	var w := grid[1].to_int()
	var h := grid[2].to_int()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for r in h:
		var row: String = rows[r]
		for c in w:
			if row[c] == "#":
				img.set_pixel(c, r, Color(0.07, 0.07, 0.08, 0.9))
			else:
				var height := (row.unicode_at(c) - 48) / 4.0 - 6.0
				var v := clampf(0.42 + height * 0.05, 0.25, 0.85)
				img.set_pixel(c, r, Color(v, v * 0.95, v * 0.82))
	img.save_png(RADAR_IMAGE)
	_root.set_meta("radar_image", RADAR_IMAGE)
	_root.set_meta("radar_rect", Rect2(grid[3].to_float(), grid[4].to_float(), w * grid[5].to_float(), h * grid[5].to_float()))


# --- Props ---------------------------------------------------------------------------------

func _props(places: Array) -> void:
	var targets := _node(_root, "Targets")
	var buy := _node(_root, "BuyZones")
	var target_scene: PackedScene = load("res://scenes/target.tscn")
	var zone_script: Script = load("res://scripts/buy_zone.gd")
	var labels: Array = []
	var spawn := Vector3.ZERO
	var look := Vector3.FORWARD
	for f: PackedStringArray in places:
		var p := Vector3(f[2].to_float(), f[3].to_float(), f[4].to_float())
		match f[0]:
			"SPAWN":
				spawn = p
			"LOOK":
				look = p
			"LABEL":
				labels.append([f[1], p.x, p.z])
			"TARGET":
				var tg := target_scene.instantiate() as Node3D
				tg.name = f[1]
				tg.position = p
				_add(targets, tg)
			"ZONE":
				var a := Area3D.new()
				a.name = f[1]
				a.set_script(zone_script)
				a.set("size", Vector3(f[5].to_float(), 6, f[6].to_float()))
				a.position = p
				_add(buy, a)
	_root.set_meta("radar_labels", labels)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Node3D
	player.name = "Player"
	player.position = spawn + Vector3(0, 0.1, 0)
	var to := look - spawn
	player.rotation.y = atan2(-to.x, -to.z) # Out of T spawn, towards mid and long.
	_add(_root, player)


# --- Materials, light, helpers ----------------------------------------------------------

func _make_materials() -> void:
	for spec: Array in [["dust_sand", "light", Color(0.93, 0.83, 0.64)], ["dust_wall", "light", Color(0.86, 0.73, 0.54)]]:
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://textures/grid_%s.png" % spec[1])
		m.albedo_color = spec[2]
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.25
		m.roughness = 0.9
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		ResourceSaver.save(m, "res://materials/%s.tres" % spec[0])
		_mat[spec[0]] = load("res://materials/%s.tres" % spec[0])


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.55, 0.82)
	sky_mat.sky_horizon_color = Color(0.85, 0.8, 0.72)
	sky_mat.ground_horizon_color = Color(0.85, 0.8, 0.72)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_add(_root, we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	_add(_root, sun)


func _node(parent: Node, n: String) -> Node3D:
	var nd := Node3D.new()
	nd.name = n
	_add(parent, nd)
	return nd


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = _root
