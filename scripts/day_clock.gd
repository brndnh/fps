class_name DayClock
extends Interactable
## A clock on a post in the hub: Interact moves the time of day on (morning, noon, evening,
## night) for everyone. The level (scripts/hub.gd) does the lighting; this shows the time,
## its hands sweeping round as the light changes.

var _hour_hand: Node3D
var _minute_hand: Node3D
var _label: Label3D


func _ready() -> void:
	super()
	focus_offset = Vector3(0, 2.0, 0)
	_build()


func get_prompt() -> String:
	var level := get_tree().current_scene
	var next := ""
	if level != null and level.has_method("time_of_day"):
		next = level.TIMES[(level.time_of_day() + 1) % level.TIMES.size()].name
	return "SET TIME TO %s" % next if next != "" else "CHANGE TIME"


func use(_by: Player) -> void:
	Game.request_action("clock")
	Sfx.play("hammer", -6.0)


func _process(_delta: float) -> void:
	var level := get_tree().current_scene
	if level == null or not level.has_method("clock_hour"):
		return
	var hour: float = level.clock_hour()
	_hour_hand.rotation.z = -TAU * fmod(hour, 12.0) / 12.0
	_minute_hand.rotation.z = -TAU * fmod(hour, 1.0)
	_label.text = level.time_name()


## A post with a round face (on both sides, so it reads from anywhere), hands and a sign.
func _build() -> void:
	var dark := flat_material(Color(0.15, 0.15, 0.17))
	add_box(Vector3(0.15, 2.0, 0.15), Vector3(0, 1.0, 0), dark)
	var face := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 0.08
	face.mesh = cyl
	face.material_override = flat_material(Color(0.95, 0.93, 0.85), 0.3)
	face.rotation_degrees.x = 90.0
	face.position = Vector3(0, 2.35, 0)
	add_child(face)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.41
	torus.outer_radius = 0.47
	rim.mesh = torus
	rim.material_override = flat_material(Color(0.85, 0.55, 0.15))
	rim.rotation_degrees.x = 90.0
	rim.position = face.position
	add_child(rim)
	for i in 12: # Hour ticks, front and back.
		var a := TAU * i / 12.0
		for z: float in [0.045, -0.045]:
			var tick := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.03, 0.08 if i % 3 == 0 else 0.05, 0.01)
			tick.mesh = tm
			tick.material_override = dark
			tick.position = face.position + Vector3(sin(a) * 0.34, cos(a) * 0.34, z)
			tick.rotation.z = -a
			add_child(tick)
	_hour_hand = _hand(0.2, 0.035, dark)
	_minute_hand = _hand(0.32, 0.022, dark)
	_label = Label3D.new()
	_label.font_size = 48
	_label.outline_size = 12
	_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_label.position = Vector3(0, 3.05, 0)
	add_child(_label)


## A hand pivoting at the face's centre, drawn on both sides.
func _hand(length: float, width: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 2.35, 0)
	add_child(pivot)
	for z: float in [0.05, -0.05]:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width, length, 0.01)
		m.mesh = bm
		m.material_override = mat
		m.position = Vector3(0, length * 0.5, z)
		pivot.add_child(m)
	return pivot
