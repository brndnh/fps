class_name Humanoid
extends Node3D
## A blocky person built from boxes: legs, hips, torso, head and arms, standing on this
## node's origin, `height` tall. Used for other players, enemies and corpses.
## While `animated`, it walks by itself: it watches how fast its own position changes and
## swings its legs (and arms, unless the owner poses them) to match, so it looks right on
## remote copies and the host alike without syncing anything extra.

const STRIDE := 2.6 ## Leg swing cycles (radians) per metre walked.

var height := 1.8
var animated := true
var arms_free := true ## False: the owner poses the arms (holding a gun, claws out).
var body_mat: StandardMaterial3D ## Torso and head; enemies flash it white when hit.

var torso: Node3D
var head: Node3D
var left_arm: Node3D ## Shoulder pivots: rotation.x swings the arm (+ = forward and up).
var right_arm: Node3D
var left_leg: Node3D ## Hip pivots.
var right_leg: Node3D

var _phase := 0.0
var _speed := 0.0
var _last := Vector3.INF


func _init(color: Color = Color.WHITE, tall: float = 1.8) -> void:
	height = tall
	var s := tall / 1.8
	body_mat = _mat(color)
	var limb_mat := _mat(color.darkened(0.25))
	var leg_mat := _mat(color.darkened(0.45))
	var boot_mat := _mat(Color(0.12, 0.12, 0.14))
	var hip_y := 0.86 * s

	for side: float in [-1.0, 1.0]:
		var leg := _pivot(Vector3(0.12 * side, hip_y, 0.0) )
		_box(leg, Vector3(0.2, hip_y - 0.08 * s, 0.22) , Vector3(0.0, -(hip_y - 0.08 * s) * 0.5, 0.0), leg_mat)
		_box(leg, Vector3(0.22, 0.1 * s, 0.32), Vector3(0.0, -hip_y + 0.05 * s, -0.05), boot_mat)
		if side < 0.0:
			left_leg = leg
		else:
			right_leg = leg

	torso = _pivot(Vector3(0.0, hip_y, 0.0))
	_box(torso, Vector3(0.44, 0.16 * s, 0.26), Vector3(0.0, 0.06 * s, 0.0), leg_mat) # Hips.
	_box(torso, Vector3(0.52, 0.48 * s, 0.3), Vector3(0.0, 0.38 * s, 0.0), body_mat) # Chest.
	head = _pivot(Vector3(0.0, hip_y + 0.66 * s, 0.0))
	_box(head, Vector3(0.3, 0.3 * s, 0.3), Vector3(0.0, 0.17 * s, 0.0), body_mat)

	for side: float in [-1.0, 1.0]:
		var arm := _pivot(Vector3(0.34 * side, hip_y + 0.56 * s, 0.0))
		_box(arm, Vector3(0.14, 0.62 * s, 0.16), Vector3(0.0, -0.29 * s, 0.0), limb_mat)
		if side < 0.0:
			left_arm = arm
		else:
			right_arm = arm


func _process(delta: float) -> void:
	if not animated or delta <= 0.0:
		return
	var at := global_position
	if _last == Vector3.INF:
		_last = at
	var moved := Vector2(at.x - _last.x, at.z - _last.z).length()
	_last = at
	_speed = lerpf(_speed, minf(moved / delta, 12.0), 1.0 - exp(-10.0 * delta))
	var amount := clampf(_speed / 4.0, 0.0, 1.0) # Bigger strides when running.
	_phase = fmod(_phase + moved * STRIDE, TAU)
	var swing := sin(_phase) * 0.75 * amount
	var k := 1.0 - exp(-14.0 * delta)
	left_leg.rotation.x = lerpf(left_leg.rotation.x, swing, k)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, -swing, k)
	if arms_free:
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -swing * 0.7, k)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, swing * 0.7, k)


func _pivot(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	return n


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = at
	parent.add_child(m)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
