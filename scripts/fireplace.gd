extends Node3D
## A fire that's always lit (the hub's fireplace): its "FireLight" child flickers and the
## "Flame*" meshes lick up and down, each out of step with the others. The hearth itself is
## plain geometry built by tools/build_range.gd.

const FLICKER_SPEED := 9.0

var _light: OmniLight3D
var _flames: Array[Node3D] = []
var _base_energy := 1.0
var _t := 0.0


func _ready() -> void:
	_light = get_node_or_null("FireLight") as OmniLight3D
	if _light != null:
		_base_energy = _light.light_energy
	for c in get_children():
		if c.name.begins_with("Flame"):
			_flames.append(c as Node3D)


func _process(delta: float) -> void:
	_t += delta * FLICKER_SPEED
	if _light != null:
		_light.light_energy = _base_energy * (0.85 + 0.1 * sin(_t * 1.3) + 0.08 * sin(_t * 2.9 + 1.0) + randf_range(-0.04, 0.04))
	for i in _flames.size():
		var f := _flames[i]
		var k := 0.8 + 0.25 * sin(_t * (1.1 + i * 0.37) + i * 2.1) + 0.1 * sin(_t * 3.3 + i)
		f.scale = Vector3(1.0, k, 1.0)
