extends Node
## Players and the current map (autoload "Game").
##
## The map is the current scene. Players live here instead, under Game/Players, so they
## survive map changes. The host (or you, offline) spawns one Player per peer, named after
## the peer id and owned by that peer, and the MultiplayerSpawner copies it to everyone.
## Each peer moves its own player; everyone else's copy follows it (see player.gd).
## The host picks the map, and clients load whatever the host has loaded.
##
## Enemies live here too (Game/Enemies), spawned by the host for everyone. The host runs
## them, on a navigation mesh it bakes from the map's collision when the map has enemy
## spawners. They only spawn while enemies are switched on (the lever in the Firing
## Range); every map starts with them off. When nobody is left standing it's a squad
## wipe, and the map restarts.
##
## The roster (who's in which slot, and their names) is kept by the host and sent to
## everyone, for the lobby screen and name tags.
##
## Expeditions: the hub (the Firing Range) launches one with start_expedition(): a new
## random seed, and every peer generates the same layout from it. The current map's
## shared state (objectives, countdowns...) is map_state, set by the host and sent to
## everyone, late joiners included. Players' presses go to the host with request_action().

signal squad_wiped ## Every peer. The map restarts (or, on an expedition, everyone goes home) WIPE_RESTART_DELAY later.
signal level_started ## Every peer, once the map is loaded and local players are on it.
signal enemies_switched(on: bool) ## Every peer.
signal roster_changed ## Every peer.
signal map_state_changed ## Every peer.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUB := "res://scenes/firing_range.tscn"
const EXPEDITION := "res://scenes/expedition.tscn"
const SPAWN_SPACING := 1.3 ## Metres between players lined up around a spawn point.
const WIPE_RESTART_DELAY := 4.0
const MAX_NAME_LENGTH := 16
const FALL_LIMIT := -30.0 ## Below this height you've fallen out of the map: back to a spawn point.
const CORPSE_TIME := 45.0 ## Seconds a body stays.
const MAX_CORPSES := 30

var level_ready := false ## The map is loaded and local players are standing on it.
var players: Node3D
var enemies: Node3D
var props: Node3D ## Physics props: crates and corpses (see PhysicsProp).
var nav_ready := false ## Host only: the map's navigation mesh is baked, so enemies can find their way.
var enemies_enabled := false ## Synced from the host. Enemy spawners only spawn while it's on.
var roster := {} ## Synced from the host: peer id -> {name, slot}.
var map_seed := 0 ## The current map's generation seed (expeditions).
var map_state := {} ## Synced from the host: the current map's shared state. Empty at every map load.

var _spawner: MultiplayerSpawner
var _enemy_spawner: MultiplayerSpawner
var _prop_spawner: MultiplayerSpawner
var _slots := {} ## Host only: peer id -> spawn slot (0 to Net.MAX_PLAYERS - 1).
var _names := {} ## Host only: peer id -> name.
var _next_enemy_id := 0
var _next_prop_id := 0
var _corpses: Array[Node] = [] ## Host: oldest first, so the oldest go when there are too many.
var _wiping := false


func _ready() -> void:
	players = Node3D.new()
	players.name = "Players"
	add_child(players)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "PlayerSpawner"
	_spawner.spawn_path = NodePath("../Players")
	_spawner.spawn_limit = Net.MAX_PLAYERS
	_spawner.spawn_function = _create_player
	add_child(_spawner)
	enemies = Node3D.new()
	enemies.name = "Enemies"
	add_child(enemies)
	_enemy_spawner = MultiplayerSpawner.new()
	_enemy_spawner.name = "EnemySpawner"
	_enemy_spawner.spawn_path = NodePath("../Enemies")
	_enemy_spawner.spawn_function = _create_enemy
	add_child(_enemy_spawner)
	props = Node3D.new()
	props.name = "Props"
	add_child(props)
	_prop_spawner = MultiplayerSpawner.new()
	_prop_spawner.name = "PropSpawner"
	_prop_spawner.spawn_path = NodePath("../Props")
	_prop_spawner.spawn_function = _create_prop
	add_child(_prop_spawner)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func() -> void: _register_name.rpc_id(1, Settings.get_player_name()))
	Net.joining.connect(_clear_players)
	Net.session_ended.connect(_on_session_ended)
	get_tree().scene_changed.connect(_on_level_loaded)
	_start.call_deferred() # Once the first map is in.


func _start() -> void:
	if multiplayer.is_server(): # Offline or hosting from the command line. Joining spawns nothing here.
		_spawn_player(multiplayer.get_unique_id())
	_on_level_loaded()


## The player this machine controls, or null (e.g. while connecting).
func local_player() -> Player:
	for p: Player in players.get_children():
		if p.is_local:
			return p
	return null


# --- Maps ------------------------------------------------------------------------

func current_map() -> String:
	var level := get_tree().current_scene
	return level.scene_file_path if level != null else ""


## Switches everyone to another map. Only the host (or you, offline) can.
func change_map(path: String, seed: int = 0) -> void:
	if multiplayer.is_server():
		_load_map.rpc(path, true, seed)


## Host: everyone into a freshly generated expedition.
func start_expedition() -> void:
	change_map(EXPEDITION, randi())


## Anyone (the hub's launch terminal): asks the host to start an expedition.
@rpc("any_peer", "call_local", "reliable")
func request_expedition() -> void:
	if multiplayer.is_server() and current_map() == HUB:
		start_expedition()


func return_to_hub() -> void:
	change_map(HUB)


func in_expedition() -> bool:
	return current_map() == EXPEDITION


@rpc("authority", "call_local", "reliable")
func _load_map(path: String, reload: bool, seed: int) -> void:
	if not reload and path == current_map() and seed == map_seed:
		return # Joined a host on the map we already had open.
	level_ready = false
	map_seed = seed
	map_state = {}
	map_state_changed.emit()
	if multiplayer.is_server():
		clear_enemies()
		clear_props()
	get_tree().change_scene_to_file(path)


## Host: merges `changes` into the map state and sends it to everyone.
func set_map_state(changes: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	map_state.merge(changes, true)
	_sync_map_state.rpc(map_state)


@rpc("authority", "call_local", "reliable")
func _sync_map_state(state: Dictionary) -> void:
	map_state = state
	map_state_changed.emit()


## Anyone: asks the host to have the current map do something (throw a breaker...).
## The host calls the map's handle_action(action, arg, by_peer).
func request_action(action: String, arg: int = 0) -> void:
	_map_action.rpc_id(1, action, arg)


@rpc("any_peer", "call_local", "reliable")
func _map_action(action: String, arg: int) -> void:
	var level := get_tree().current_scene
	if multiplayer.is_server() and level != null and level.has_method("handle_action"):
		level.handle_action(action, arg, multiplayer.get_remote_sender_id())


func _on_level_loaded() -> void:
	level_ready = false
	nav_ready = false
	# Let the new map's collision settle in before placing anyone on it.
	await get_tree().physics_frame
	await get_tree().physics_frame
	level_ready = true
	_wiping = false
	for p: Player in players.get_children():
		if multiplayer.is_server():
			p.health.reset()
		if p.is_local:
			p.respawn(spawn_transform(p.slot))
	if multiplayer.is_server():
		if enemies_enabled:
			_set_enemies.rpc(false) # Every map starts quiet.
		for spawn: Node in get_tree().get_nodes_in_group("prop_spawns"):
			spawn_prop((spawn as PropSpawn).describe())
		_bake_navigation()
	level_started.emit()


## Host: nobody standing, and nobody downed with a kit to get themselves up = squad wipe.
func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or not level_ready or _wiping or players.get_child_count() == 0:
		return
	for p: Player in players.get_children():
		if p.health.is_up() or (p.health.downed and p.health.kits > 0):
			return
	_wiping = true
	_announce_wipe.rpc()
	await get_tree().create_timer(WIPE_RESTART_DELAY).timeout
	if not _wiping:
		return
	if in_expedition():
		return_to_hub() # Expedition failed.
	else:
		change_map(current_map())


@rpc("authority", "call_local", "reliable")
func _announce_wipe() -> void:
	squad_wiped.emit()


## Where the player in this slot starts on the current map. Uses the map's Marker3Ds in
## the "player_spawns" group. With fewer markers than players, the rest line up in rows
## beside and behind the first marker, skipping spots in walls or over drops.
func spawn_transform(slot: int) -> Transform3D:
	var marks := get_tree().get_nodes_in_group("player_spawns")
	if slot < marks.size():
		return (marks[slot] as Node3D).global_transform
	var anchor := Transform3D(Basis(), Vector3.UP)
	if not marks.is_empty():
		anchor = (marks[0] as Node3D).global_transform
	var spots: Array[Transform3D] = [anchor]
	var space := get_tree().root.world_3d.direct_space_state
	for row in 4:
		for col: int in [0, 1, -1, 2, -2]:
			if row == 0 and col == 0:
				continue
			var p := anchor.origin + anchor.basis.x * col * SPAWN_SPACING + anchor.basis.z * row * SPAWN_SPACING
			var floor_y := _clear_spot(space, anchor.origin, p)
			if not is_nan(floor_y):
				spots.append(Transform3D(anchor.basis, Vector3(p.x, floor_y + 0.05, p.z)))
	return spots[slot % spots.size()]


## Floor height at `to` if a player can stand there and it's in sight of `from`, else NAN.
func _clear_spot(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> float:
	var up := Vector3.UP
	var reach := (to - from).normalized() * 0.5 # Not hard up against a wall either.
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from + up, to + up + reach, 1)).is_empty():
		return NAN
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(to + up, to - up * 1.5, 1))
	return NAN if hit.is_empty() else (hit.position as Vector3).y


# --- Enemies ---------------------------------------------------------------------

## Host only. Spawns an enemy for everyone and returns it. Not `alerted`, it stands
## where it's put until it sees someone (see Enemy).
func spawn_enemy(scene_path: String, at: Transform3D, alerted: bool = true) -> Node:
	_next_enemy_id += 1
	return _enemy_spawner.spawn([scene_path, at, _next_enemy_id, alerted])


## Runs on every peer for each enemy spawn, with the same data.
func _create_enemy(data: Array) -> Node:
	var e := (load(data[0]) as PackedScene).instantiate() as Enemy
	e.name = "E%d" % data[2]
	e.transform = data[1]
	e.alerted = data[3]
	return e


## Host only (despawns replicate). Map changes, and turning enemies off.
func clear_enemies() -> void:
	for e: Node in enemies.get_children():
		e.queue_free()


# --- Physics props ---------------------------------------------------------------

## Host only. Spawns a physics prop for everyone (see PhysicsProp.setup() for `data`).
## Corpses fade out after CORPSE_TIME, and the oldest go once there are MAX_CORPSES.
func spawn_prop(data: Dictionary) -> PhysicsProp:
	_next_prop_id += 1
	data.id = _next_prop_id
	if data.get("kind", 0) == PhysicsProp.Kind.CORPSE:
		data.lifetime = CORPSE_TIME
	var p := _prop_spawner.spawn(data) as PhysicsProp
	if p.kind == PhysicsProp.Kind.CORPSE:
		# Drop bodies that already went (timed out, or the map was cleared). Checked one by
		# one: a freed body can't be handed to a typed lambda.
		var kept: Array[Node] = []
		for c: Variant in _corpses:
			if is_instance_valid(c) and not (c as Node).is_queued_for_deletion():
				kept.append(c)
		_corpses = kept
		_corpses.append(p)
		while _corpses.size() > MAX_CORPSES:
			_corpses.pop_front().queue_free()
	return p


## Host: a body left where something died, knocked over by `velocity`.
func spawn_corpse(at: Transform3D, color: Color, velocity: Vector3) -> void:
	var spin := Vector3(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0), randf_range(-2.0, 2.0))
	spawn_prop({kind = PhysicsProp.Kind.CORPSE, transform = at, color = color, size = Vector3(0.4, 1.8, 0.0),
			mass = 45.0, velocity = velocity, spin = spin})


## Runs on every peer for each prop spawn, with the same data.
func _create_prop(data: Dictionary) -> Node:
	var p := PhysicsProp.new()
	p.name = "P%d" % data.id
	p.setup(data)
	return p


## Host: shoves every prop within `radius` of `at` outwards (blasts).
func blast_props(at: Vector3, radius: float, strength: float) -> void:
	for p: Node in props.get_children():
		var prop := p as PhysicsProp
		var to := prop.global_position - at
		if to.length() < radius:
			prop.push((to.normalized() + Vector3.UP * 0.5) * strength * prop.mass * (1.0 - to.length() / radius), prop.global_position)


## Host only (despawns replicate). Map changes.
func clear_props() -> void:
	_corpses.clear()
	for p: Node in props.get_children():
		p.queue_free()


## Anyone (the lever): asks the host to turn enemies on or off for everyone.
@rpc("any_peer", "call_local", "reliable")
func request_enemies(on: bool) -> void:
	if multiplayer.is_server() and on != enemies_enabled:
		_set_enemies.rpc(on)


@rpc("authority", "call_local", "reliable")
func _set_enemies(on: bool) -> void:
	enemies_enabled = on
	if not on and multiplayer.is_server():
		clear_enemies()
	enemies_switched.emit(on)


## Bakes a navigation mesh from the map's collision (world layer only) on a thread.
## Only maps with enemy spawners, or in the "needs_navigation" group (expeditions).
func _bake_navigation() -> void:
	var level := get_tree().current_scene
	if level == null:
		return
	if get_tree().get_nodes_in_group("enemy_spawners").is_empty() and not level.is_in_group("needs_navigation"):
		return
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = &"navigation_source"
	# Heights in whole 0.25 m cells (the navigation map's cell height).
	mesh.agent_radius = 0.5
	mesh.agent_height = 2.0
	mesh.agent_max_climb = 0.25 # Enemies don't step up ledges like players do; their capsule rides over this much.
	mesh.agent_max_slope = 50.0
	level.add_to_group("navigation_source")
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = mesh
	level.add_child(region)
	region.bake_finished.connect(func() -> void: nav_ready = true)
	region.bake_navigation_mesh(true)


# --- Players ---------------------------------------------------------------------

func _spawn_player(id: int) -> void:
	if players.has_node(str(id)):
		return
	var used := _slots.values()
	var slot := 0
	while slot in used:
		slot += 1
	_slots[id] = slot
	if id == multiplayer.get_unique_id():
		_names[id] = Settings.get_player_name()
	_spawner.spawn([id, slot])
	_send_roster()


## Name shown for a peer: their name from the roster, or their slot.
func player_name(peer_id: int) -> String:
	var entry: Dictionary = roster.get(peer_id, {})
	return entry.get("name", "?")


## Your name changed (lobby screen): saved, and sent to the host.
func rename_me(new_name: String) -> void:
	Settings.set_player_name(_clean_name(new_name))
	if multiplayer.is_server():
		_names[multiplayer.get_unique_id()] = Settings.get_player_name()
		_send_roster()
	elif Net.state == Net.State.CONNECTED:
		_register_name.rpc_id(1, Settings.get_player_name())


@rpc("any_peer", "call_remote", "reliable")
func _register_name(new_name: String) -> void:
	if multiplayer.is_server():
		_names[multiplayer.get_remote_sender_id()] = _clean_name(new_name)
		_send_roster()


static func _clean_name(s: String) -> String:
	s = s.strip_edges().left(MAX_NAME_LENGTH)
	return s if not s.is_empty() else "Player"


## Host: tells everyone who's in which slot.
func _send_roster() -> void:
	if not multiplayer.is_server():
		return
	var r := {}
	for id: int in _slots:
		r[id] = {name = _names.get(id, "Player %d" % (_slots[id] + 1)), slot = _slots[id]}
	_set_roster.rpc(r)


@rpc("authority", "call_local", "reliable")
func _set_roster(r: Dictionary) -> void:
	roster = r
	roster_changed.emit()


## Runs on every peer for each spawn, with the same data.
func _create_player(data: Array) -> Node:
	var p := PLAYER_SCENE.instantiate() as Player
	p.setup_network(data[0], data[1], data[0] == multiplayer.get_unique_id())
	return p


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[Game] player %d joined" % id)
	_load_map.rpc_id(id, current_map(), false, map_seed)
	_sync_map_state.rpc_id(id, map_state)
	_set_enemies.rpc_id(id, enemies_enabled)
	_spawn_player(id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[Game] player %d left" % id)
	_slots.erase(id)
	_names.erase(id)
	var p := players.get_node_or_null(str(id))
	if p != null:
		p.queue_free()
	_send_roster()


## Joining: the host will spawn everyone (us included) and their enemies, so nothing
## local can stay.
func _clear_players() -> void:
	_slots.clear()
	_names.clear()
	_free_all(enemies)
	_free_all(props)
	_free_all(players)
	roster = {}
	roster_changed.emit()


func _free_all(parent: Node) -> void:
	for n: Node in parent.get_children():
		parent.remove_child(n)
		n.free()


## Back offline. A host keeps their player (offline is peer 1 too) and enemies; a
## client gets a new player, and the host's enemies go.
func _on_session_ended(was_host: bool) -> void:
	_slots.clear()
	_names = {1: Settings.get_player_name()}
	if not was_host:
		_free_all(enemies)
		_free_all(props)
	for p: Player in players.get_children():
		if p.is_local and p.peer_id == 1:
			_slots[1] = p.slot
		else:
			players.remove_child(p)
			p.free()
	_spawn_player(1)
	_send_roster()
