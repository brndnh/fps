extends Node3D
## Root of a weapon viewmodel scene. Method tracks in its animations call
## play_sfx() so sounds stay in sync with the keyframes (and with reload speed).
##
## It also keeps the arms on: each <Side>Wrist marker rides along with its hand,
## and every frame the <Side>Forearm, <Side>Elbow and <Side>UpperArm boxes are
## solved from there to a shoulder that stays put relative to the camera (two-bone
## IK). So the arm bends at the elbow however the hand moves, instead of swinging
## around as one rigid limb. tools/build_weapons.gd bakes the rest pose.

## Reload cues that kick the camera (degrees, + = up), so mags slamming home and slides
## racking feel punchy. Only while the weapon is actually reloading.
const RELOAD_PUNCH := {"mag_out": 0.45, "mag_in": -0.9, "rack": 0.8, "slide_back": 0.5, "slide_home": -0.85}

## Shoulders in camera space (metres; -Z = forward).
const SHOULDERS := {"Right": Vector3(0.22, -0.33, 0.05), "Left": Vector3(-0.22, -0.33, 0.05)}
## Which way the elbows bend, in camera space: out, and a bit down.
const POLES := {"Right": Vector3(1.0, -0.55, 0.1), "Left": Vector3(-1.0, -0.55, 0.1)}

var _sounds: Array = [] ## [player, stream] for sounds this weapon's animations started.
var _arms: Array = [] ## [side, wrist, forearm, elbow, upper_arm, forearm_length, upper_arm_length]


func _ready() -> void:
	process_priority = 10 # After the AnimationPlayer and the procedural viewmodel motion have moved the hands.
	for side: String in SHOULDERS:
		var wrist := find_child(side + "Wrist", true, false) as Node3D
		var fore := get_node_or_null(side + "Forearm") as Node3D
		var upper := get_node_or_null(side + "UpperArm") as Node3D
		if wrist != null and fore != null and upper != null:
			_arms.append([side, wrist, fore, get_node_or_null(side + "Elbow"), upper,
					wrist.get_meta("forearm_length", 0.3), wrist.get_meta("upper_arm_length", 0.3)])


func _process(_delta: float) -> void:
	if _arms.is_empty() or not is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_local := global_transform.affine_inverse() * cam.global_transform
	for arm: Array in _arms:
		var wrist: Vector3 = global_transform.affine_inverse() * (arm[1] as Node3D).global_position
		solve_arm(arm[2], arm[3], arm[4], wrist, to_local * SHOULDERS[arm[0]], to_local.basis * POLES[arm[0]], arm[5], arm[6])


func play_sfx(sound: String, volume_db: float = -6.0) -> void:
	# Looked up by path (not the Sfx global) so tools/build_weapons.gd can load this script.
	var sfx := get_node_or_null("/root/Sfx")
	if sfx == null:
		return
	_reload_punch(RELOAD_PUNCH.get(sound, 0.0))
	var p: AudioStreamPlayer = sfx.play(sound, volume_db)
	if p != null:
		_sounds = _sounds.filter(func(s: Array) -> bool: return s[0].playing and s[0].stream == s[1])
		_sounds.append([p, p.stream])


func _reload_punch(deg: float) -> void:
	if deg == 0.0 or not is_visible_in_tree():
		return
	# Found by method, not class, so tools/build_weapons.gd can load this script on its own.
	var n := get_parent()
	while n != null and not n.has_method("add_view_punch"):
		n = n.get_parent()
	var weapons := n.get_node_or_null("Weapons") if n != null else null
	if weapons != null and weapons.is_reloading():
		n.add_view_punch(deg)


## Cuts off whatever its animations are still playing (the weapon was put away).
## Only stops a voice that's still playing this weapon's sound, not one reused since.
func stop_sounds() -> void:
	for s: Array in _sounds:
		var p: AudioStreamPlayer = s[0]
		if p.playing and p.stream == s[1]:
			p.stop()
	_sounds.clear()


## Places the arm boxes (unit length along Z, children of the rig root) from wrist to
## shoulder, bending at the elbow towards `pole`. All in rig space. Out of reach, the
## arm straightens and both bones stretch to fit.
static func solve_arm(fore: Node3D, elbow_box: Node3D, upper: Node3D, wrist: Vector3, shoulder: Vector3,
		pole: Vector3, fore_length: float, upper_length: float) -> void:
	var to := shoulder - wrist
	var d := maxf(to.length(), 0.001)
	var dir := to / d
	var bend := pole - dir * pole.dot(dir)
	bend = bend.normalized() if bend.length() > 0.001 else Vector3.DOWN
	# Law of cosines: how far along wrist->shoulder the elbow sits, and how far out it bends.
	var stretch := maxf(d / (fore_length + upper_length), 1.0)
	var a := fore_length * stretch
	var along := clampf((a * a - upper_length * upper_length * stretch * stretch + d * d) / (2.0 * d), 0.0, a)
	var elbow := wrist + dir * along + bend * sqrt(maxf(a * a - along * along, 0.0))
	_bone(fore, wrist, elbow, pole)
	_bone(upper, elbow, shoulder, pole)
	if elbow_box != null:
		elbow_box.transform = Transform3D(fore.basis.orthonormalized(), elbow)


static func _bone(node: Node3D, a: Vector3, b: Vector3, up: Vector3) -> void:
	var v := b - a
	var span := maxf(v.length(), 0.001)
	var along := v / span
	var look := Basis.looking_at(along, up if absf(along.dot(up.normalized())) < 0.99 else Vector3.FORWARD)
	node.transform = Transform3D(Basis(look.x, look.y, look.z * span), (a + b) * 0.5)
