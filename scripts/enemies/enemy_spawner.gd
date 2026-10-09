extends Marker3D
## Keeps up to max_alive enemies alive around this point, facing the way it faces. When
## one dies, a replacement comes respawn_delay later. Host only, and only while
## Game.enemies_enabled (the ENEMIES lever). A map with one of these gets a navigation mesh
## baked when it loads (see Game).

@export_file("*.tscn") var enemy_scene: String = "res://scenes/enemies/brawler.tscn" ## grunt.tscn for the gun version.
@export var max_alive: int = 5
@export var first_delay: float = 1.0 ## Seconds after the lever's pulled before the first one.
@export var respawn_delay: float = 3.0
@export var scatter: float = 2.0 ## Metres of random offset, so they don't stack up.

var _alive: Array[Node] = []
var _timer := 0.0


func _ready() -> void:
	add_to_group("enemy_spawners")
	_timer = first_delay


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not Game.level_ready or not Game.enemies_enabled:
		return
	var before := _alive.size()
	var still: Array[Node] = [] # One by one: a freed enemy can't be handed to a typed lambda.
	for e: Variant in _alive:
		if is_instance_valid(e) and not (e as Node).is_queued_for_deletion() and not (e as Enemy).dead:
			still.append(e)
	_alive = still
	if _alive.size() < before:
		_timer = maxf(_timer, respawn_delay) # One just died.
	if _alive.size() >= max_alive:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.4 # The next one shortly after, if there's still room.
	var offset := Vector3(randf_range(-scatter, scatter), 0.0, randf_range(-scatter, scatter))
	_alive.append(Game.spawn_enemy(enemy_scene, Transform3D(global_basis, global_position + offset)))
