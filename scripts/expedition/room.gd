class_name Room
extends Node3D
## One handcrafted room module for expeditions (scenes/rooms/...).
##
## Rooms sit on a grid of CELL-metre cells; `cells` is the footprint, with cell (0, 0)
## centred on this node. They join through doorways in the middle of a cell edge: each
## Marker3D under "Doors" is one, on the edge and facing out of the room (its -Z). The
## Expedition rotates rooms in 90-degree steps and joins facing doorways; a doorway left
## unused gets sealed with a wall plug. All doorways are DOOR_WIDTH x DOOR_HEIGHT, so any
## two rooms fit together and a squad can move through side by side.
##
## Also looked for: Marker3Ds under "EnemySpawns" (where this room's enemies stand,
## facing their -Z), Marker3Ds under "Supplies" (where a medkit might be left), and
## objective pieces (BreachDoor, Breaker, ExtractionConsole, ExtractionPad).
## Floors are at y = 0. Keep everything inside the footprint and the walls.
## The START room is the yard outside the facility, where the squad arrives.

enum Kind { START, CORRIDOR, COMBAT, OBJECTIVE, EXTRACTION }

const CELL := 24.0
const DOOR_WIDTH := 4.4
const DOOR_HEIGHT := 3.6
const WALL_THICKNESS := 0.5
const WALL_HEIGHT := 6.0

@export var kind: Kind = Kind.COMBAT
@export var cells: Array[Vector2i] = [Vector2i.ZERO]
@export var max_enemies: int = 3 ## This room's encounter never has more (nor more than EnemySpawns markers).
@export var weight: float = 1.0 ## How often the generator picks this room among rooms of its kind.

# Set by the Expedition when it places the room.
var grid_origin := Vector2i.ZERO
var turns := 0 ## 90-degree steps, counter-clockwise from above.
var depth := 0 ## Rooms between this one and the start.
var activated := false ## Host: its encounter has spawned.


## Doorways in this room's own grid: [{cell: Vector2i, dir: Vector2i, marker: Marker3D}].
func local_doors() -> Array:
	var out: Array = []
	var doors := get_node_or_null("Doors")
	if doors == null:
		return out
	for m: Node in doors.get_children():
		var mk := m as Node3D
		if mk == null:
			continue
		var fwd := -mk.transform.basis.z
		var dir := Vector2i(roundi(fwd.x), roundi(fwd.z))
		var centre := mk.position - Vector3(dir.x, 0.0, dir.y) * CELL * 0.5
		out.append({cell = Vector2i(roundi(centre.x / CELL), roundi(centre.z / CELL)), dir = dir, marker = mk})
	return out


## Fills an unused doorway with wall.
func seal(marker: Node3D) -> void:
	var fwd := -marker.transform.basis.z
	var body := StaticBody3D.new()
	body.name = "Seal_" + marker.name
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(DOOR_WIDTH + 0.1, DOOR_HEIGHT, WALL_THICKNESS)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mesh.mesh = bm
	mesh.material_override = load("res://materials/grid_light.tres")
	body.add_child(mesh)
	add_child(body)
	body.transform = Transform3D(marker.transform.basis,
			marker.position - fwd * WALL_THICKNESS * 0.5 + Vector3.UP * DOOR_HEIGHT * 0.5)


## Where this room's enemies stand.
func enemy_spawns() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var spawns := get_node_or_null("EnemySpawns")
	if spawns != null:
		for m: Node in spawns.get_children():
			if m is Node3D:
				out.append(m)
	return out


## Where supplies (medkits) can be left in this room.
func supply_spots() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var supplies := get_node_or_null("Supplies")
	if supplies != null:
		for m: Node in supplies.get_children():
			if m is Node3D:
				out.append(m)
	return out


## World-space centres of this room's cells.
func cell_centres() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for c in cells:
		out.append(global_transform * Vector3(c.x * CELL, 0.0, c.y * CELL))
	return out


## A grid cell or direction turned by `steps` x 90 degrees, the same way rotation.y turns.
static func turn(v: Vector2i, steps: int) -> Vector2i:
	for i in posmod(steps, 4):
		v = Vector2i(v.y, -v.x)
	return v
