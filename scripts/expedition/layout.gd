class_name ExpeditionLayout
extends RefCounted
## Plans an expedition: which room modules go where on the grid, which doorways join, and
## which get sealed. Pure data, driven by one seeded RandomNumberGenerator, so the same
## seed always gives the same plan and every peer builds the same map from the seed alone.
##
## The plan grows as a tree from the start room, so every room can be reached:
## 1. a main path of MAIN_PATH corridor and combat rooms out of the start;
## 2. OBJECTIVES objective rooms (one breaker each) branching off the main path;
## 3. the extraction room at the end of the main path, the deepest point;
## 4. a couple of side branches, dead ends worth exploring.
## Where two unused doorways happen to face each other, they're joined too, which makes
## the odd loop for flanking. Every doorway still unused gets sealed.

const MAIN_PATH := 6
const OBJECTIVES := 2
const BRANCHES := Vector2i(2, 3) ## Min and max.
const MAX_TRIES := 30


## A room module, read once from its scene.
class Template:
	var path: String
	var scene: PackedScene
	var kind: Room.Kind
	var cells: Array[Vector2i] = []
	var doors: Array = [] ## [{cell, dir}] in the room's own grid, in the scene's order.
	var weight: float = 1.0


## A room as placed in the plan. Cells and doors are in world grid terms.
class Placed:
	var template: Template
	var origin: Vector2i
	var turns: int
	var cells: Array[Vector2i] = []
	var doors: Array = [] ## [{cell, dir, used}]
	var depth: int = 0


var rooms: Array[Placed] = []
var extraction: Placed
var objectives: Array[Placed] = []

var _grid := {} ## Vector2i -> Placed
var _rng := RandomNumberGenerator.new()
var _by_kind := {} ## Room.Kind -> Array[Template]


## Reads each room scene's footprint and doorways.
static func load_templates(paths: Array) -> Array[Template]:
	var out: Array[Template] = []
	for path: String in paths:
		var scene := load(path) as PackedScene
		var room := scene.instantiate() as Room
		var t := Template.new()
		t.path = path
		t.scene = scene
		t.kind = room.kind
		t.cells = room.cells.duplicate()
		t.weight = room.weight
		for d: Dictionary in room.local_doors():
			t.doors.append({cell = d.cell, dir = d.dir})
		room.free()
		out.append(t)
	return out


static func plan(seed: int, templates: Array[Template]) -> ExpeditionLayout:
	var layout := ExpeditionLayout.new()
	layout._rng.seed = seed
	for t in templates:
		if not layout._by_kind.has(t.kind):
			layout._by_kind[t.kind] = []
		layout._by_kind[t.kind].append(t)
	for i in MAX_TRIES:
		if layout._try():
			layout._join_facing_doors()
			return layout
	push_warning("Expedition layout: no full plan after %d tries (seed %d); using what fits." % [MAX_TRIES, seed])
	return layout


func _try() -> bool:
	rooms.clear()
	objectives.clear()
	extraction = null
	_grid.clear()
	var start := _place(_pick(Room.Kind.START), Vector2i.ZERO, 0)
	if start == null:
		return false

	var path: Array[Placed] = [start]
	for i in MAIN_PATH:
		var kind := Room.Kind.CORRIDOR if _rng.randf() < 0.45 else Room.Kind.COMBAT
		var next := _grow(path[-1], kind)
		if next == null:
			next = _grow(path[-1], Room.Kind.CORRIDOR if kind == Room.Kind.COMBAT else Room.Kind.COMBAT)
		if next == null:
			break
		path.append(next)
	if path.size() < 4:
		return false

	extraction = _grow(path[-1], Room.Kind.EXTRACTION)
	if extraction == null:
		return false

	var hosts := path.slice(1) # Objectives branch off the main path, not the start.
	for i in OBJECTIVES:
		var placed: Placed = null
		for host in _shuffled(hosts):
			placed = _grow(host, Room.Kind.OBJECTIVE)
			if placed != null:
				break
		if placed == null:
			return false
		objectives.append(placed)

	for i in _rng.randi_range(BRANCHES.x, BRANCHES.y):
		var candidates := rooms.filter(func(p: Placed) -> bool:
			return p != extraction and p.template.kind != Room.Kind.START)
		for host: Placed in _shuffled(candidates):
			if _grow(host, Room.Kind.COMBAT if _rng.randf() < 0.6 else Room.Kind.CORRIDOR) != null:
				break
	return true


## Attaches a room of `kind` to one of `from`'s free doorways. Null if nothing fits.
func _grow(from: Placed, kind: Room.Kind) -> Placed:
	var open: Array = []
	for i in from.doors.size():
		var d: Dictionary = from.doors[i]
		if not d.used and not _grid.has(d.cell + d.dir):
			open.append(i)
	for i: int in _shuffled(open):
		for t: Template in _weighted_order(kind):
			var p := _attach(from, i, t)
			if p != null:
				return p
	return null


## Tries every turn and every doorway of `t` that can face doorway `door_i` of `from`.
func _attach(from: Placed, door_i: int, t: Template) -> Placed:
	var door: Dictionary = from.doors[door_i]
	var target: Vector2i = door.cell + door.dir
	var facing: Vector2i = -door.dir
	for turns: int in _shuffled([0, 1, 2, 3]):
		for j: int in _shuffled(range(t.doors.size())):
			var d: Dictionary = t.doors[j]
			if Room.turn(d.dir, turns) != facing:
				continue
			var origin: Vector2i = target - Room.turn(d.cell, turns)
			var p := _place(t, origin, turns)
			if p == null:
				continue
			p.doors[j].used = true
			door.used = true
			p.depth = from.depth + 1
			return p
	return null


func _place(t: Template, origin: Vector2i, turns: int) -> Placed:
	if t == null:
		return null
	var cells: Array[Vector2i] = []
	for c in t.cells:
		var w := origin + Room.turn(c, turns)
		if _grid.has(w):
			return null
		cells.append(w)
	var p := Placed.new()
	p.template = t
	p.origin = origin
	p.turns = turns
	p.cells = cells
	for d: Dictionary in t.doors:
		p.doors.append({cell = origin + Room.turn(d.cell, turns), dir = Room.turn(d.dir, turns), used = false})
	for c in cells:
		_grid[c] = p
	rooms.append(p)
	return p


## Unused doorways that face each other across a shared edge become a connection.
func _join_facing_doors() -> void:
	for p in rooms:
		for d: Dictionary in p.doors:
			if d.used:
				continue
			var other: Placed = _grid.get(d.cell + d.dir)
			if other == null or other == p:
				continue
			for o: Dictionary in other.doors:
				if not o.used and o.cell == d.cell + d.dir and o.dir == -d.dir:
					o.used = true
					d.used = true


func _pick(kind: Room.Kind) -> Template:
	var order := _weighted_order(kind)
	return order[0] if not order.is_empty() else null


## Templates of `kind` in a random order, heavier weights tending to come first.
func _weighted_order(kind: Room.Kind) -> Array:
	var pool: Array = (_by_kind.get(kind, []) as Array).duplicate()
	var out: Array = []
	while not pool.is_empty():
		var total := 0.0
		for t: Template in pool:
			total += t.weight
		var roll := _rng.randf() * total
		var i := 0
		while i < pool.size() - 1 and roll > (pool[i] as Template).weight:
			roll -= (pool[i] as Template).weight
			i += 1
		out.append(pool.pop_at(i))
	return out


## A shuffled copy, using this layout's RNG (Array.shuffle would use the global one and
## differ between peers).
func _shuffled(items: Array) -> Array:
	var a := items.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a
