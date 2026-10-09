class_name Expedition
extends Node3D
## A generated Research Complex expedition (scenes/expedition.tscn), started from the
## hub's launch terminal. Every peer builds the same rooms from Game.map_seed in _ready,
## before anyone is placed (see ExpeditionLayout).
##
## The job: get in (the squad starts outside, in the yard: breach the door by shooting it
## down or blowing it with a charge), restore power at every breaker, then start the
## extraction console. After EXTRACT_TIME seconds, whoever's on the extraction pad gets
## out and anyone else is left behind. Either way the expedition is over and everyone goes
## back to the hub (extraction model A). A squad wipe ends it too.
## Heal items (syringes, medkits, trauma kits, shield cells and batteries) and ammo boxes
## are left at some of the rooms' Supplies spots (the same ones on every peer,
## picked with the map seed). The radar starts dark here (fog of war, see Radar).
##
## The host runs it. Its state lives in Game.map_state (phase, breakers, countdown,
## results) so every peer, late joiners included, sees the same thing; players' button
## presses come in through Game.request_action() to handle_action().
## Enemies: a room's encounter spawns, standing idle, the first time a player comes within
## ACTIVATE_RANGE of it, with more of them deeper in and for bigger squads. Throwing a
## breaker wakes idle enemies within NOISE_RADIUS. Starting the extraction brings waves in
## from the back of the extraction room.

const ROOMS := [
	"res://scenes/rooms/research/yard.tscn",
	"res://scenes/rooms/research/airlock.tscn",
	"res://scenes/rooms/research/corridor.tscn",
	"res://scenes/rooms/research/corner.tscn",
	"res://scenes/rooms/research/junction.tscn",
	"res://scenes/rooms/research/lab.tscn",
	"res://scenes/rooms/research/office.tscn",
	"res://scenes/rooms/research/atrium.tscn",
	"res://scenes/rooms/research/server_room.tscn",
	"res://scenes/rooms/research/generator_room.tscn",
	"res://scenes/rooms/research/extraction.tscn",
]
const ENEMY := "res://scenes/enemies/brawler.tscn" ## Melee for now; grunt.tscn is the gun version.
const ACTIVATE_RANGE := Room.CELL + 2.0 ## Metres from any of a room's cell centres: about one room away.
const NOISE_RADIUS := 30.0
const MEDKIT_SHARE := 0.4 ## Of the Supplies spots, this share get a medkit...
const MIN_MEDKITS := 3 ## ...but at least this many.
const AMMO_SHARE := 0.35 ## Of the Supplies spots left, this share get an ammo box...
const MIN_AMMO := 4 ## ...but at least this many (if there are spots).
const EXTRACT_TIME := 25.0
const WAVES := 3 ## Extraction waves: one at the start, then evenly through the countdown.
const RESULTS_TIME := 7.0 ## Seconds on the results before going back to the hub.

var layout: ExpeditionLayout
var rooms: Array[Room] = []
var breakers: Array[Breaker] = []
var medkits: Array[MedkitPickup] = []
var ammo_boxes: Array[AmmoPickup] = []
var pad: ExtractionPad
var door: BreachDoor

var _extraction_room: Room
var _check_t := 0.0
var _extract_left := 0.0 ## For the HUD, every peer: counts down between the host's updates.
var _countdown := 0.0 ## Host: the real countdown.
var _waves_sent := 0


func _ready() -> void:
	add_to_group("needs_navigation")
	add_to_group("fog_of_war")
	_build()
	Game.map_state_changed.connect(_on_state_changed)
	if multiplayer.is_server():
		var states: Array = []
		states.resize(breakers.size())
		states.fill(false)
		Game.set_map_state({phase = "breach" if door != null else "explore", breakers = states,
				door_hp = door.max_health if door != null else 0.0, taken_medkits = [], taken_ammo = []})
	else:
		_on_state_changed()


func _build() -> void:
	layout = ExpeditionLayout.plan(Game.map_seed, ExpeditionLayout.load_templates(ROOMS))
	var holder := Node3D.new()
	holder.name = "Rooms"
	add_child(holder)
	for i in layout.rooms.size():
		var p: ExpeditionLayout.Placed = layout.rooms[i]
		var room := p.template.scene.instantiate() as Room
		room.name = "Room%d" % i
		room.grid_origin = p.origin
		room.turns = p.turns
		room.depth = p.depth
		room.position = Vector3(p.origin.x, 0.0, p.origin.y) * Room.CELL
		room.rotation.y = p.turns * PI * 0.5
		holder.add_child(room)
		var doors := room.local_doors()
		for j in doors.size():
			if not p.doors[j].used:
				room.seal(doors[j].marker)
		rooms.append(room)
		if p == layout.extraction:
			_extraction_room = room
		for b: Node in room.find_children("*", "Breaker", true, false):
			(b as Breaker).index = breakers.size()
			breakers.append(b)
		if pad == null:
			for n: Node in room.find_children("*", "ExtractionPad", true, false):
				pad = n
		if door == null:
			for n: Node in room.find_children("*", "BreachDoor", true, false):
				door = n
	_place_medkits()
	print("[Expedition] seed %d: %d rooms, %d breakers, %d heal items, %d ammo boxes" % [Game.map_seed, rooms.size(),
			breakers.size(), medkits.size(), ammo_boxes.size()])


## Heal items at a share of the Supplies spots, then ammo boxes at a share of the rest.
## Picked with the map seed, so every peer puts the same ones in the same places.
func _place_medkits() -> void:
	var spots: Array[Node3D] = []
	for room in rooms:
		spots.append_array(room.supply_spots())
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.map_seed ^ 0x5EED
	for i in range(spots.size() - 1, 0, -1): # Shuffle with this RNG, not the global one.
		var j := rng.randi_range(0, i)
		var tmp := spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	var count := mini(spots.size(), maxi(MIN_MEDKITS, roundi(spots.size() * MEDKIT_SHARE)))
	for i in count:
		var kit := MedkitPickup.new()
		kit.name = "Medkit%d" % i
		kit.index = i
		var roll := rng.randf() # Stims and cells mostly, some medkits, a few batteries, the odd trauma kit.
		kit.kind = 0 if roll < 0.3 else 1 if roll < 0.48 else 2 if roll < 0.54 else 3 if roll < 0.86 else 4
		spots[i].add_child(kit)
		medkits.append(kit)
	var boxes := mini(spots.size() - count, maxi(MIN_AMMO, roundi((spots.size() - count) * AMMO_SHARE)))
	for i in boxes:
		var box := AmmoPickup.new()
		box.name = "Ammo%d" % i
		box.index = i
		box.type = WeaponManager.AMMO_ORDER[rng.randi() % WeaponManager.AMMO_ORDER.size()]
		spots[count + i].add_child(box)
		ammo_boxes.append(box)


func phase() -> String:
	return Game.map_state.get("phase", "")


## One line for the HUD: what to do now.
func get_objective_text() -> String:
	match phase():
		"breach":
			if Game.map_state.get("charge", false):
				return "CHARGE PLANTED: STAND BACK!"
			return "Get inside: shoot the door down, or plant a breach charge on it"
		"explore":
			var states: Array = Game.map_state.get("breakers", [])
			return "Restore power: %d / %d breakers on" % [states.count(true), states.size()]
		"powered":
			return "Power restored. Start the extraction console"
		"extracting":
			return "EXTRACTION IN %d: GET ON THE PAD!" % ceili(_extract_left)
	return ""


## For the radar's fog of war: the floor area (world x/z rects, one per cell) of the
## room at `pos`, so a room shows up whole the moment anyone sets foot in it. Empty
## outside every room.
func get_reveal_rects(pos: Vector3) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var cell := Vector2i(roundi(pos.x / Room.CELL), roundi(pos.z / Room.CELL))
	var placed: ExpeditionLayout.Placed = layout._grid.get(cell)
	if placed == null:
		return out
	var half := Room.CELL * 0.5
	for c in placed.cells:
		out.append(Rect2(c.x * Room.CELL - half, c.y * Room.CELL - half, Room.CELL, Room.CELL))
	return out


## For the full map (M): things worth marking, [text, world position, colour].
func get_map_markers() -> Array:
	var out: Array = []
	if door != null:
		out.append(["ENTRANCE", door.global_position, Color(1.0, 0.75, 0.1)])
	for b in breakers:
		out.append(["POWER ON" if b.is_on() else "BREAKER", b.global_position, Color(0.3, 1.0, 0.4) if b.is_on() else Color(1.0, 0.3, 0.25)])
	if pad != null:
		out.append(["EXTRACTION", pad.global_position, Color(0.3, 0.8, 1.0)])
	return out


## {extracted: [peer ids], left: [peer ids]} once it's over, else empty.
func get_results() -> Dictionary:
	return Game.map_state.get("results", {})


func _on_state_changed() -> void:
	if Game.map_state.has("extract_left"):
		_extract_left = Game.map_state.extract_left


func _process(delta: float) -> void:
	if phase() == "extracting":
		_extract_left = maxf(_extract_left - delta, 0.0)


# --- Host -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not Game.level_ready:
		return
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.5
		_activate_rooms()
		if phase() == "extracting":
			_tick_extraction()


## Players' presses (and hits on the door), from Game.request_action().
func handle_action(action: String, arg: int, by: int) -> void:
	match action:
		"door_damage":
			if phase() != "breach" or door == null:
				return
			var hp := maxf(float(Game.map_state.get("door_hp", 0.0)) - arg, 0.0)
			Game.set_map_state({door_hp = hp})
			if hp <= 0.0:
				_breach(false)
		"plant_charge":
			if phase() != "breach" or door == null or Game.map_state.get("charge", false):
				return
			Game.set_map_state({charge = true})
			await get_tree().create_timer(BreachDoor.FUSE).timeout
			if phase() == "breach":
				_breach(true)
		"take_medkit":
			var taken: Array = (Game.map_state.get("taken_medkits", []) as Array).duplicate()
			var taker := Game.players.get_node_or_null(str(by)) as Player
			if arg < 0 or arg >= medkits.size() or arg in taken or taker == null or not taker.health.give_heal(medkits[arg].kind):
				return
			taken.append(arg)
			Game.set_map_state({taken_medkits = taken})
		"take_ammo": # The taker checked they had room; the rounds go to them.
			var taken: Array = (Game.map_state.get("taken_ammo", []) as Array).duplicate()
			var taker := Game.players.get_node_or_null(str(by)) as Player
			if arg < 0 or arg >= ammo_boxes.size() or arg in taken or taker == null:
				return
			taken.append(arg)
			Game.set_map_state({taken_ammo = taken})
			var box := ammo_boxes[arg]
			taker.health.give_ammo(box.type, int(WeaponManager.AMMO[box.type].box))
		"breaker":
			if phase() != "explore" or arg < 0 or arg >= breakers.size() or breakers[arg].is_on():
				return
			var states: Array = (Game.map_state.get("breakers", []) as Array).duplicate()
			states[arg] = true
			Enemy.alert_near(breakers[arg].global_position, NOISE_RADIUS)
			Game.set_map_state({breakers = states, phase = "powered" if not states.has(false) else "explore"})
		"extract":
			if phase() != "powered":
				return
			_countdown = EXTRACT_TIME
			_waves_sent = 0
			Game.set_map_state({phase = "extracting", extract_left = EXTRACT_TIME})
			_send_wave()


## The door's down: in you go. A charge also hurts anyone too close to it. Loud either way.
func _breach(blast: bool) -> void:
	var at := door.global_position + Vector3.UP * 1.5
	Game.set_map_state({phase = "explore", breached = true, door_hp = 0.0})
	Enemy.alert_near(at, NOISE_RADIUS)
	if not blast:
		return
	Game.blast_props(at, BreachDoor.BLAST_RADIUS * 2.0, 10.0)
	for p: Player in Game.players.get_children():
		var d := p.global_position.distance_to(door.global_position)
		if d < BreachDoor.BLAST_RADIUS:
			var near := 1.0 - d / BreachDoor.BLAST_RADIUS
			p.health.take_damage(lerpf(10.0, BreachDoor.BLAST_DAMAGE, near), at, lerpf(5.0, 16.0, near))


func _activate_rooms() -> void:
	for room in rooms:
		if room.activated or room.kind == Room.Kind.START or room.kind == Room.Kind.EXTRACTION:
			continue
		if _player_near(room):
			room.activated = true
			_spawn_encounter(room)


func _player_near(room: Room) -> bool:
	for p: Player in Game.players.get_children():
		if p.health.eliminated:
			continue
		for c in room.cell_centres():
			if c.distance_to(p.global_position) < ACTIVATE_RANGE:
				return true
	return false


## Idle enemies at the room's spawn points: 2, plus 1 every 2 rooms deep, plus 1 per 2
## players, never more than the room allows. Corridors are sometimes empty.
func _spawn_encounter(room: Room) -> void:
	if room.kind == Room.Kind.CORRIDOR and randf() < 0.25:
		return
	var spots := room.enemy_spawns()
	spots.shuffle()
	var count := 2 + room.depth / 2 + Game.players.get_child_count() / 2
	count = mini(count, mini(room.max_enemies, spots.size()))
	for i in count:
		Game.spawn_enemy(ENEMY, spots[i].global_transform, false)


## Extraction waves come in awake, from the far end of the extraction room.
func _send_wave() -> void:
	_waves_sent += 1
	if _extraction_room == null:
		return
	var spots := _extraction_room.enemy_spawns()
	spots.shuffle()
	var count := mini(3 + Game.players.get_child_count(), spots.size())
	for i in count:
		Game.spawn_enemy(ENEMY, spots[i].global_transform, true)


func _tick_extraction() -> void:
	_countdown = maxf(_countdown - 0.5, 0.0)
	if _waves_sent < WAVES and _countdown <= EXTRACT_TIME * (1.0 - float(_waves_sent) / WAVES):
		_send_wave()
	if _countdown > 0.0:
		Game.set_map_state({extract_left = _countdown})
		return
	var extracted: Array = []
	var left: Array = []
	for p: Player in Game.players.get_children():
		if not p.health.eliminated and pad != null and pad.contains(p.global_position):
			extracted.append(p.peer_id)
		else:
			left.append(p.peer_id)
	Game.set_map_state({phase = "over", extract_left = 0.0, results = {extracted = extracted, left = left}})
	Game.clear_enemies()
	await get_tree().create_timer(RESULTS_TIME).timeout
	Game.return_to_hub()
