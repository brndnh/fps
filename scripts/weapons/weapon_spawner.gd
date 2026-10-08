extends Node3D
## Weapon rack slot: a gun floats here, slowly turning. Take it and another
## one appears after respawn_delay.

@export var weapon: WeaponData
@export var respawn_delay: float = 3.0
@export var spin_speed: float = 0.8 ## Radians per second.

var _pickup: WeaponPickup
var _timer := 0.0
var _t := 0.0


func _ready() -> void:
	_spawn()


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_pickup) and _pickup.freeze:
		_pickup.rotation.y += spin_speed * delta
		_pickup.position.y = sin(_t * 2.0) * 0.04
		return
	_timer -= delta
	if _timer <= 0.0:
		_spawn()


func _spawn() -> void:
	if weapon == null:
		return
	_pickup = WeaponPickup.new()
	_pickup.weapon = weapon
	_pickup.freeze = true
	add_child(_pickup)
	_pickup.tree_exiting.connect(func() -> void: _timer = respawn_delay)
