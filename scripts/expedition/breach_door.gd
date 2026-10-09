class_name BreachDoor
extends Interactable
## The way into the facility, in the yard where the squad arrives. It's shut until you
## breach it: shoot or hit it until it gives (max_health; everyone sees the same bar), or
## plant a charge on it (Interact) and stand back: FUSE seconds later it blows, hurting
## anyone within BLAST_RADIUS. Either way it's loud, and whatever's inside comes to see.
## The host runs it through the Expedition (Game.map_state: door_hp, charge, breached).
##
## The door is on physics layer 5 ("doors"): players, enemies and bullets all stop at it,
## but the navigation mesh is baked as if it weren't there, so once it's down enemies can
## path straight through the doorway. Faces its -Z (the yard side).

const FUSE := 3.0
const BLAST_RADIUS := 5.0
const BLAST_DAMAGE := 45.0 ## At the door; less further out.
const LAYER := 16
const STRIPE := Color(1.0, 0.75, 0.1)

@export var max_health: float = 400.0

var _door: Node3D
var _body: StaticBody3D
var _bars: HealthBar3D
var _charge_mat: StandardMaterial3D
var _charge: MeshInstance3D
var _open := false
var _beep_t := 0.0


func _ready() -> void:
	super()
	focus_offset = Vector3(0.0, 1.4, 0.0)
	reach = 3.0
	_build()


func is_breached() -> bool:
	return Game.map_state.get("breached", false)


func health() -> float:
	return Game.map_state.get("door_hp", max_health)


func get_prompt() -> String:
	return "PLANT BREACH CHARGE"


func can_use(_by: Player) -> bool:
	return not is_breached() and not Game.map_state.get("charge", false)


func use(_by: Player) -> void:
	Game.request_action("plant_charge")


## Shot or hit (WeaponManager): the shooter sees the number, the host takes the damage.
func take_damage(amount: float, headshot: bool, at: Vector3) -> bool:
	if is_breached():
		return false
	WeaponFx.damage_number(get_tree().current_scene, at, amount, Color.WHITE, headshot)
	Game.request_action("door_damage", roundi(amount))
	return health() - amount <= 0.0


func _process(delta: float) -> void:
	var hp := health()
	_bars.visible = not is_breached() and hp < max_health
	_bars.set_fill(hp / max_health)
	var planted: bool = Game.map_state.get("charge", false) and not is_breached()
	_charge.visible = planted
	if planted:
		_beep_t -= delta
		if _beep_t <= 0.0:
			_beep_t = 0.5
			Sfx.play_at("dry_fire", _charge.global_position, 4.0)
		_charge_mat.emission_energy_multiplier = 4.0 if fmod(Time.get_ticks_msec() * 0.004, 1.0) < 0.5 else 0.5
	if is_breached() and not _open:
		_blow_open(Game.map_state.get("charge", false))


## It gives: blown off its frame by a charge, or knocked flat by gunfire. Either way it goes
## inwards (+Z), into the facility; the door node pivots on its bottom edge.
func _blow_open(blast: bool) -> void:
	_open = true
	_body.queue_free()
	_bars.visible = false
	var world := get_tree().current_scene
	var tw := create_tween().set_parallel(true)
	if blast:
		WeaponFx.impact(world, global_position + Vector3.UP * 1.5, global_basis.z * -1.0, false)
		Sfx.play_at("shot_sniper", global_position + Vector3.UP * 1.5, 8.0)
		tw.tween_property(_door, "position", Vector3(0.0, 0.2, 4.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_door, "rotation", Vector3(1.5, 0.4, 0.2), 0.35)
	else:
		Sfx.play_at("melee_hit", global_position + Vector3.UP * 1.5, 6.0)
		tw.tween_property(_door, "rotation:x", 1.52, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _build() -> void:
	_door = Node3D.new()
	_door.name = "Door"
	add_child(_door)
	var size := Vector3(Room.DOOR_WIDTH, Room.DOOR_HEIGHT, 0.4)
	var slab := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = size
	slab.mesh = sm
	slab.material_override = flat_material(Color(0.3, 0.32, 0.35))
	slab.position.y = size.y * 0.5
	_door.add_child(slab)
	for i in 3: # Hazard stripes on both faces.
		var stripe := MeshInstance3D.new()
		var stm := BoxMesh.new()
		stm.size = Vector3(size.x - 0.2, 0.18, size.z + 0.04)
		stripe.mesh = stm
		stripe.material_override = flat_material(STRIPE)
		stripe.position.y = 0.6 + i * 1.1
		_door.add_child(stripe)

	_body = StaticBody3D.new()
	_body.collision_layer = LAYER
	_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	_body.add_child(shape)
	add_child(_body)

	_charge_mat = flat_material(Color(1.0, 0.15, 0.1), 4.0)
	_charge = MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.5, 0.35, 0.15)
	_charge.mesh = cm
	_charge.material_override = _charge_mat
	_charge.position = Vector3(0.7, 1.3, -0.28)
	_charge.visible = false
	add_child(_charge)

	_bars = HealthBar3D.new(STRIPE, 1.6)
	_bars.position.y = size.y + 0.5
	_bars.visible = false
	add_child(_bars)
