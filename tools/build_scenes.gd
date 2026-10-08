extends SceneTree
## Generates the starter scenes, materials and input map.
##   godot --headless -s tools/build_scenes.gd
## WARNING: overwrites scenes/*.tscn and materials/*.tres. After you start editing
## the scenes in the editor, don't rerun this (or edit this script instead).

var _mat := {}


func _init() -> void:
	_setup_input_map()
	_make_materials()
	_save(_build_target(), "res://scenes/target.tscn")
	_save(_build_player(), "res://scenes/player.tscn")
	_save(_build_range(), "res://scenes/firing_range.tscn")
	print("Scenes built.")
	quit()


# --- Input ----------------------------------------------------------------

func _setup_input_map() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"jump": [KEY_SPACE], "crouch": [KEY_CTRL, KEY_C], "sprint": [KEY_SHIFT],
		"reload": [KEY_R], "inspect": [KEY_F], "melee": [KEY_V],
		"toggle_debug": [KEY_F3],
	}
	for action: String in keys:
		var events: Array = []
		for k: int in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			e.device = -1
			events.append(e)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	for pair: Array in [["fire", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT]]:
		var m := InputEventMouseButton.new()
		m.button_index = pair[1]
		m.device = -1
		ProjectSettings.set_setting("input/" + pair[0], {"deadzone": 0.2, "events": [m]})
	ProjectSettings.save()


# --- Materials --------------------------------------------------------------

func _make_materials() -> void:
	for n: String in ["dark", "light", "orange", "blue"]:
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://textures/grid_%s.png" % n)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.25 # 1 texture per 4 m -> 0.5 m grid cells
		m.roughness = 0.9
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mat[n] = _save_res(m, "res://materials/grid_%s.tres" % n)
	var flat := {"target_body": Color(0.85, 0.42, 0.15), "target_head": Color(0.95, 0.2, 0.2),
		"marker": Color(1, 0.55, 0.1), "stripe": Color(0.25, 0.45, 0.8)}
	for n: String in flat:
		var m := StandardMaterial3D.new()
		m.albedo_color = flat[n]
		m.roughness = 0.8
		_mat[n] = _save_res(m, "res://materials/%s.tres" % n)
	var shader: Shader = load("res://materials/viewmodel.gdshader")
	var vm := {"vm_gun": [Color(0.17, 0.18, 0.2), 0.45, 0.3], "vm_gun_accent": [Color(0.35, 0.37, 0.4), 0.5, 0.3],
		"vm_glove": [Color(0.12, 0.12, 0.12), 0.9, 0.0], "vm_sleeve": [Color(0.32, 0.38, 0.28), 0.95, 0.0]}
	for n: String in vm:
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("albedo", vm[n][0])
		sm.set_shader_parameter("roughness", vm[n][1])
		sm.set_shader_parameter("metallic", vm[n][2])
		_mat[n] = _save_res(sm, "res://materials/%s.tres" % n)


func _save_res(r: Resource, path: String) -> Resource:
	ResourceSaver.save(r, path)
	return load(path)


# --- Target -----------------------------------------------------------------

func _build_target() -> Node3D:
	var root := Node3D.new()
	root.name = "Target"
	root.add_to_group("targets", true)
	_box(root, root, "Stand", Vector3(0.6, 0.1, 0.6), Vector3(0, 0.05, 0), _mat.dark)
	var body := _box(root, root, "Body", Vector3(0.5, 1.4, 0.25), Vector3(0, 0.8, 0), _mat.target_body)
	body.set_meta("hitzone", "body")
	var head := _box(root, root, "Head", Vector3(0.26, 0.28, 0.26), Vector3(0, 1.66, 0), _mat.target_head)
	head.set_meta("hitzone", "head")
	return root


# --- Player -----------------------------------------------------------------

func _build_player() -> Node3D:
	var p := CharacterBody3D.new()
	p.name = "Player"
	p.set_script(load("res://scripts/player/player.gd"))
	p.floor_snap_length = 0.35
	p.floor_max_angle = deg_to_rad(46.0)

	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	_add(p, p, cs)

	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 1.65
	_add(p, p, head)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 90.0
	cam.near = 0.05
	cam.current = true
	_add(p, head, cam)

	var vm := Node3D.new()
	vm.name = "Viewmodel"
	vm.set_script(load("res://scripts/player/viewmodel.gd"))
	vm.position = Vector3(0.19, -0.2, -0.52)
	_add(p, cam, vm)

	# Placeholder rifle + arms. Swap these for a real model (.glb) later.
	var gun := Node3D.new()
	gun.name = "Gun"
	_add(p, vm, gun)
	_vm(p, gun, "Receiver", Vector3(0.06, 0.09, 0.32), Vector3(0, 0, 0), Vector3.ZERO, _mat.vm_gun)
	_vm(p, gun, "Handguard", Vector3(0.05, 0.065, 0.26), Vector3(0, 0.005, -0.29), Vector3.ZERO, _mat.vm_gun_accent)
	_vm(p, gun, "Barrel", Vector3(0.025, 0.025, 0.14), Vector3(0, 0.015, -0.48), Vector3.ZERO, _mat.vm_gun)
	_vm(p, gun, "Magazine", Vector3(0.04, 0.15, 0.07), Vector3(0, -0.1, -0.07), Vector3(12, 0, 0), _mat.vm_gun_accent)
	_vm(p, gun, "Grip", Vector3(0.04, 0.1, 0.05), Vector3(0, -0.08, 0.1), Vector3(-15, 0, 0), _mat.vm_gun)
	_vm(p, gun, "Stock", Vector3(0.045, 0.075, 0.13), Vector3(0, -0.01, 0.22), Vector3.ZERO, _mat.vm_gun_accent)
	_vm(p, gun, "RearSight", Vector3(0.025, 0.03, 0.04), Vector3(0, 0.058, 0.08), Vector3.ZERO, _mat.vm_gun)
	_vm(p, gun, "FrontSight", Vector3(0.012, 0.04, 0.015), Vector3(0, 0.055, -0.39), Vector3.ZERO, _mat.vm_gun)

	var arms := Node3D.new()
	arms.name = "Arms"
	_add(p, vm, arms)
	_vm(p, arms, "RightHand", Vector3(0.075, 0.075, 0.09), Vector3(0.01, -0.11, 0.12), Vector3(-15, 0, 0), _mat.vm_glove)
	_vm_segment(p, arms, "RightForearm", Vector3(0.02, -0.13, 0.15), Vector3(0.16, -0.36, 0.45), 0.085, _mat.vm_sleeve)
	_vm(p, arms, "LeftHand", Vector3(0.075, 0.06, 0.1), Vector3(-0.005, -0.045, -0.27), Vector3(0, 0, -20), _mat.vm_glove)
	_vm_segment(p, arms, "LeftForearm", Vector3(-0.03, -0.07, -0.25), Vector3(-0.42, -0.32, 0.02), 0.085, _mat.vm_sleeve)

	var hud := CanvasLayer.new()
	hud.name = "DebugHUD"
	hud.set_script(load("res://scripts/ui/debug_hud.gd"))
	_add(p, p, hud)

	var xh := Control.new()
	xh.name = "Crosshair"
	xh.set_script(load("res://scripts/ui/crosshair.gd"))
	xh.set_anchors_preset(Control.PRESET_FULL_RECT)
	xh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(p, hud, xh)

	var stats := Label.new()
	stats.name = "Stats"
	stats.position = Vector2(20, 16)
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_constant_override("outline_size", 5)
	stats.add_theme_color_override("font_outline_color", Color.BLACK)
	_add(p, hud, stats)
	return p


## Box stretched between two points (for forearms).
func _vm_segment(owner_node: Node, parent: Node, n: String, a: Vector3, b: Vector3, thick: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thick, thick, a.distance_to(b))
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) * 0.5)
	_add(owner_node, parent, mi)


func _vm(owner_node: Node, parent: Node, n: String, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation_degrees = rot
	_add(owner_node, parent, mi)


# --- Firing range -------------------------------------------------------------

func _build_range() -> Node3D:
	var root := Node3D.new()
	root.name = "FiringRange"

	# Environment + light
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_add(root, root, we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	_add(root, root, sun)

	var geo := _group(root, "Geometry")
	var tgt := _group(root, "Targets")
	var lbl := _group(root, "Labels")

	# Ground + perimeter (x -20..75, z -100..40)
	_box(root, geo, "Ground", Vector3(95, 1, 140), Vector3(27.5, -0.5, -30), _mat.dark)
	_box(root, geo, "WallWest", Vector3(1, 6, 140), Vector3(-20.5, 3, -30), _mat.light)
	_box(root, geo, "WallEast", Vector3(1, 6, 140), Vector3(75.5, 3, -30), _mat.light)
	_box(root, geo, "WallSouth", Vector3(97, 6, 1), Vector3(27.5, 3, 40.5), _mat.light)
	_box(root, geo, "WallNorth", Vector3(97, 6, 1), Vector3(27.5, 3, -100.5), _mat.light)

	# ---- Shooting range: 5 lanes, firing line at z = 0, shooting toward -Z ----
	_box(root, geo, "RangeWallLeft", Vector3(1, 4, 88), Vector3(-13.5, 2, -44), _mat.light)
	_box(root, geo, "RangeWallRight", Vector3(1, 4, 88), Vector3(13.5, 2, -44), _mat.light)
	_box(root, geo, "Backstop", Vector3(28, 8, 2), Vector3(0, 4, -89), _mat.orange)
	_box(root, geo, "Bench", Vector3(26, 1.0, 0.6), Vector3(0, 0.5, 0), _mat.blue)
	for x: float in [-7.8, -2.6, 2.6, 7.8]:
		_box(root, geo, "Divider", Vector3(0.15, 2.4, 3), Vector3(x, 1.2, 1.5), _mat.light)

	var lanes := [[-10.4, 10.0], [-5.2, 25.0], [0.0, 15.0], [5.2, 40.0], [10.4, 60.0]]
	for i in lanes.size():
		var x: float = lanes[i][0]
		var dist: float = lanes[i][1]
		if i == 2:
			_label(root, lbl, "LANE 3\nSPRAY WALL · 15 m", Vector3(x, 2.6, -0.2), 40)
			_box(root, geo, "SprayWall", Vector3(4, 3, 0.2), Vector3(0, 1.7, -dist), _mat.light)
			_box(root, geo, "AimDot", Vector3(0.12, 0.12, 0.02), Vector3(0, 2.6, -dist + 0.11), _mat.marker, Vector3.ZERO, false)
		else:
			_label(root, lbl, "LANE %d\n%d m" % [i + 1, int(dist)], Vector3(x, 2.6, -0.2), 40)
			for off: float in [-1.6, 0.0, 1.6]:
				var t: Node3D = (load("res://scenes/target.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
				t.name = "Target_L%d_%d" % [i + 1, int(off * 10)]
				t.position = Vector3(x + off, 0, -dist)
				tgt.add_child(t)
				t.owner = root
	for d: int in [10, 25, 50, 75]:
		_box(root, geo, "DistLine%d" % d, Vector3(26, 0.02, 0.15), Vector3(0, 0.01, -d), _mat.stripe, Vector3.ZERO, false)
		_label(root, lbl, "%d m" % d, Vector3(-12.9, 2.2, -d), 72, 90.0)

	# ---- Movement course (east side, x 16..75) ----
	# 1) Slide-boost ramp: platform 6 m up, 23° walk-up ramp behind, 13° slide-down ramp in front.
	_box(root, geo, "RampTower", Vector3(8, 6, 8), Vector3(30, 3, 20), _mat.light)
	_ramp(root, geo, "RampUp", 4.0, Vector3(30, 0, 37), Vector3(30, 6, 24), _mat.orange)
	_ramp(root, geo, "RampDown", 6.0, Vector3(30, 6, 16), Vector3(30, 0, -10), _mat.orange)
	_label(root, lbl, "SLIDE RAMP", Vector3(30, 8, 20), 96)
	_box(root, geo, "SlideStrip", Vector3(6, 0.02, 70), Vector3(30, 0.01, -45), _mat.stripe, Vector3.ZERO, false)
	for m: int in range(10, 80, 10):
		_label(root, lbl, "%d" % m, Vector3(30, 0.03, -10 - m), 160, 0.0, true)

	# 2) Gap jumps: 1 m platforms with 3 / 5 / 7 m gaps.
	_ramp(root, geo, "GapRamp", 4.0, Vector3(45, 0, 20), Vector3(45, 1, 12), _mat.orange)
	var plats := [[12.0, 0.0], [-3.0, -10.0], [-15.0, -22.0], [-29.0, -36.0]]
	for i in plats.size():
		var z0: float = plats[i][0]
		var z1: float = plats[i][1]
		_box(root, geo, "GapPlatform%d" % (i + 1), Vector3(4, 1, z0 - z1), Vector3(45, 0.5, (z0 + z1) * 0.5), _mat.light)
	for g: Array in [[3, -1.5], [5, -12.5], [7, -25.5]]:
		_label(root, lbl, "%d m GAP" % g[0], Vector3(45, 2.5, g[1]), 64)

	# 3) Crouch tunnel (1.3 m ceiling).
	_box(root, geo, "TunnelWallW", Vector3(0.5, 1.3, 8), Vector3(56.25, 0.65, 5), _mat.light)
	_box(root, geo, "TunnelWallE", Vector3(0.5, 1.3, 8), Vector3(59.75, 0.65, 5), _mat.light)
	_box(root, geo, "TunnelRoof", Vector3(4, 0.4, 8), Vector3(58, 1.5, 5), _mat.orange)
	_label(root, lbl, "CROUCH / SLIDE", Vector3(58, 2.4, 9.2), 64)

	# 4) Crate field for strafing / jump practice.
	var crates := [[18, -24, 1.0], [21, -28, 0.5], [17, -33, 1.5], [22, -37, 1.0], [19, -42, 0.5],
		[23, -47, 1.5], [18, -52, 1.0], [21, -57, 0.5], [55, -20, 1.0], [60, -26, 1.5],
		[65, -32, 1.0], [58, -40, 0.5], [66, -46, 1.5], [52, -50, 1.0]]
	for i in crates.size():
		var c: Array = crates[i]
		var h: float = c[2]
		_box(root, geo, "Crate%d" % i, Vector3(1.6, h, 1.6), Vector3(c[0], h * 0.5, c[1]), _mat.blue)

	# Player spawn behind the firing line.
	var player: Node3D = (load("res://scenes/player.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.position = Vector3(0, 0, 8)
	root.add_child(player)
	player.owner = root
	return root


# --- Builders -------------------------------------------------------------------

func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child, true)
	if child != owner_node:
		child.owner = owner_node


func _group(root: Node, n: String) -> Node3D:
	var g := Node3D.new()
	g.name = n
	_add(root, root, g)
	return g


func _box(owner_node: Node, parent: Node, n: String, size: Vector3, pos: Vector3, mat: Material,
		rot: Vector3 = Vector3.ZERO, collide: bool = true) -> Node3D:
	var node: Node3D = StaticBody3D.new() if collide else Node3D.new()
	node.name = n
	node.position = pos
	node.rotation_degrees = rot
	_add(owner_node, parent, node)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	_add(owner_node, node, mi)
	if collide:
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		_add(owner_node, node, cs)
	return node


## Ramp whose top surface runs from `bottom` to `top` (both are centre points of the edges).
func _ramp(owner_node: Node, parent: Node, n: String, width: float, bottom: Vector3, top: Vector3, mat: Material) -> void:
	var thickness := 0.5
	var dir := top - bottom
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	var length := dir.length() + 0.2
	var pos := (bottom + top) * 0.5 - basis.y * thickness * 0.5
	var node := _box(owner_node, parent, n, Vector3(width, thickness, length), Vector3.ZERO, mat)
	node.transform = Transform3D(basis, pos)


func _label(owner_node: Node, parent: Node, text: String, pos: Vector3, font_size: int,
		yaw: float = 0.0, flat: bool = false) -> void:
	var l := Label3D.new()
	l.name = "Label"
	l.text = text
	l.font_size = font_size
	l.outline_size = 18
	l.pixel_size = 0.01
	l.position = pos
	l.rotation_degrees = Vector3(-90 if flat else 0, yaw, 0)
	_add(owner_node, parent, l)


func _save(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("Pack failed for %s: %s" % [path, err])
	ResourceSaver.save(ps, path)
	root.free()
