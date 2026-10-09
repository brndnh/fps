class_name PropSpawn
extends Marker3D
## Where a physics prop (a crate you can push and shoot around) starts in a map. The host
## spawns a PhysicsProp here for everyone when the map loads (see Game). The marker sits
## at the bottom centre of the crate.

@export var size: Vector3 = Vector3(1.2, 1.2, 1.2)
@export var color: Color = Color(0.85, 0.55, 0.2)
@export var mass: float = 25.0


func _ready() -> void:
	add_to_group("prop_spawns")


## The spawn description for Game.spawn_prop().
func describe() -> Dictionary:
	var at := global_transform
	at.origin += at.basis.y * size.y * 0.5
	return {kind = PhysicsProp.Kind.CRATE, size = size, color = color, mass = mass, transform = at}
