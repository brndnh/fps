class_name Zipline
extends Node3D
## A zipline, Apex / Titanfall style: a cable from this node (anchor A) to `end` (anchor B,
## relative to this node), each anchor on a pole down to the ground. Press Interact near
## the cable (standing or mid-jump) to grab on (see Player): you ride it towards whichever end
## you're looking at, at the same speed up or down. Jump to leap off with your speed, crouch
## (or Interact) to drop off; at the end you're flung off forward.
## Put one in a map and set `end` and the pole heights; everything else is built here.

const CABLE_COLOR := Color(1.0, 0.78, 0.2)
const POLE_OFFSET := 0.9 ## Metres the poles stand to the side of the cable.

@export var end: Vector3 = Vector3(0, -3, 20) ## Anchor B, from this node.
@export var pole_a: float = 3.5 ## Pole height under anchor A (0 = none, e.g. hung off a wall).
@export var pole_b: float = 3.5 ## Pole height under anchor B.
@export var speed: float = 14.0 ## m/s along the cable.


func _ready() -> void:
	add_to_group("ziplines")
	_build()


func point_a() -> Vector3:
	return global_position


func point_b() -> Vector3:
	return to_global(end)


## 0..1 along the cable of the point on it closest to `p`.
func param_at(p: Vector3) -> float:
	var a := point_a()
	var seg := point_b() - a
	return clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)


func point_at(t: float) -> Vector3:
	return point_a().lerp(point_b(), t)


func length() -> float:
	return point_a().distance_to(point_b())


func _build() -> void:
	var cable_mat := StandardMaterial3D.new()
	cable_mat.albedo_color = CABLE_COLOR
	cable_mat.emission_enabled = true
	cable_mat.emission = CABLE_COLOR
	cable_mat.emission_energy_multiplier = 0.6
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.2, 0.21, 0.24)
	var cable := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = end.length()
	cm.radial_segments = 6
	cable.mesh = cm
	cable.material_override = cable_mat
	cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cable)
	# A cylinder stands along Y: tip it over to lie along the cable.
	cable.basis = Basis(Quaternion(Vector3.UP, end.normalized()))
	cable.position = end * 0.5
	# Poles stand to one side of the cable (an arm reaches over to the pulley), so a rider
	# hanging under the cable never runs into them.
	var flat := Vector3(end.x, 0.0, end.z)
	var side := Vector3.UP.cross(flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD) * POLE_OFFSET
	for anchor: Array in [[Vector3.ZERO, pole_a], [end, pole_b]]:
		var at: Vector3 = anchor[0]
		var h: float = anchor[1]
		_box(Vector3(0.35, 0.35, 0.35), at, cable_mat) # The pulley the cable runs into.
		if h <= 0.0:
			continue
		var arm := _box(Vector3(0.12, 0.12, POLE_OFFSET + 0.15), at + side * 0.5 + Vector3.UP * 0.25, pole_mat)
		arm.basis = Basis.looking_at(side, Vector3.UP)
		var body := StaticBody3D.new() # The pole: solid, so you can't walk through it.
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.25, h + 0.3, 0.25)
		shape.shape = box
		body.add_child(shape)
		body.position = at + side + Vector3(0, -h * 0.5 + 0.15, 0)
		add_child(body)
		var mesh := _box(box.size, Vector3.ZERO, pole_mat)
		mesh.reparent(body, false)


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = at
	add_child(m)
	return m
