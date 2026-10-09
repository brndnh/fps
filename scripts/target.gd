extends Node3D
## Firing range dummy. Shield then health like Apex (100 + 100 = purple armour).
## Shows floating damage numbers and bars, falls over when killed, and resets
## after a few seconds without taking damage.
##
## Online, the host owns its shield and health so everyone sees the same bars. Whoever
## shoots it sees their damage number and the flash straight away (only they see the
## number) and reports the hit; the host applies it and sends everyone the result.

const SHIELD_COLOR := Color(0.72, 0.35, 1.0)
const HEALTH_COLOR := Color(0.95, 0.95, 0.95)
const HEAD_COLOR := Color(1.0, 0.8, 0.2)
const BAR_WIDTH := 0.7

@export var max_shield: float = 100.0
@export var max_health: float = 100.0
@export var reset_delay: float = 3.0 ## Refills after this long without being hit.
@export var respawn_delay: float = 2.0

var shield: float
var health: float
var dead := false

var _since_hit := 0.0
var _pivot: Node3D
var _bodies: Array[StaticBody3D] = []
var _meshes: Array[MeshInstance3D] = []
var _materials: Array[Material] = []
var _flash := 0.0
var _bars: Node3D
var _shield_fill: MeshInstance3D
var _health_fill: MeshInstance3D
var _fall: Tween

static var _flash_mat: StandardMaterial3D


func _ready() -> void:
	shield = max_shield
	health = max_health
	# Body and head fall over around a pivot at the base.
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position.y = 0.1
	add_child(_pivot)
	for n: String in ["Body", "Head"]:
		var b := get_node(n) as StaticBody3D
		b.reparent(_pivot)
		_bodies.append(b)
		var m := b.get_node("Mesh") as MeshInstance3D
		_meshes.append(m)
		_materials.append(m.material_override)
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1, 1, 1)
	_build_bars()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			for i in _meshes.size():
				_meshes[i].material_override = _materials[i]
	if dead:
		return
	_since_hit += delta
	if multiplayer.is_server() and _since_hit >= reset_delay and _bars.visible:
		_set_state.rpc(max_shield, max_health, false) # Refill.
	var cam := get_viewport().get_camera_3d()
	if _bars.visible and cam != null:
		var p := cam.global_position
		p.y = _bars.global_position.y
		if p.distance_squared_to(_bars.global_position) > 0.01:
			_bars.look_at(p, Vector3.UP, true)


## Called by the WeaponManager of whoever hit it. Returns true if this hit kills it
## (as far as the shooter can tell; the host has the final say).
## Which way its front faces (for backstabs): +Z, towards the firing line.
func get_facing() -> Vector3:
	return global_basis.z


func take_damage(amount: float, headshot: bool, at: Vector3) -> bool:
	if dead:
		return false
	var to_shield := minf(amount, shield)
	var color := HEAD_COLOR if headshot else (SHIELD_COLOR if to_shield > 0.0 else HEALTH_COLOR)
	WeaponFx.damage_number(get_tree().current_scene, at, amount, color, headshot)
	var new_health := maxf(health - (amount - to_shield), 0.0)
	if multiplayer.is_server():
		_apply_damage(amount)
	else:
		_apply_damage.rpc_id(1, amount)
		_show_state(shield - to_shield, new_health, new_health <= 0.0) # Predicted; the host's answer replaces it.
	return new_health <= 0.0


## Host: the authoritative hit.
@rpc("any_peer", "call_remote", "reliable")
func _apply_damage(amount: float) -> void:
	if not multiplayer.is_server() or dead:
		return
	var to_shield := minf(amount, shield)
	var new_health := maxf(health - (amount - to_shield), 0.0)
	_set_state.rpc(shield - to_shield, new_health, new_health <= 0.0)
	if new_health <= 0.0:
		await get_tree().create_timer(0.3 + respawn_delay).timeout
		_set_state.rpc(max_shield, max_health, false) # Stand back up.


@rpc("authority", "call_local", "reliable")
func _set_state(new_shield: float, new_health: float, is_dead: bool) -> void:
	_show_state(new_shield, new_health, is_dead)


func _show_state(new_shield: float, new_health: float, is_dead: bool) -> void:
	var hurt := new_shield + new_health < shield + health
	shield = new_shield
	health = new_health
	if hurt:
		_since_hit = 0.0
		for m in _meshes:
			m.material_override = _flash_mat
		_flash = 0.05
	_update_bars()
	if is_dead and not dead:
		_die()
	elif not is_dead and dead:
		_respawn()
	_bars.visible = not dead and (shield < max_shield or health < max_health)


func _die() -> void:
	dead = true
	_bars.visible = false
	for b in _bodies:
		b.collision_layer = 0
	if _fall != null:
		_fall.kill()
	_fall = create_tween()
	_fall.tween_property(_pivot, "rotation:x", -1.45, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _respawn() -> void:
	dead = false
	for b in _bodies:
		b.collision_layer = 1
	if _fall != null:
		_fall.kill()
	_fall = create_tween()
	_fall.tween_property(_pivot, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Bars ------------------------------------------------------------------------

func _build_bars() -> void:
	_bars = Node3D.new()
	_bars.name = "Bars"
	_bars.position = Vector3(0.0, 2.05, 0.0)
	add_child(_bars)
	_bar(Color(0, 0, 0, 0.6), Vector3(0.0, 0.0, -0.005), Vector2(BAR_WIDTH + 0.03, 0.15))
	_shield_fill = _bar(SHIELD_COLOR, Vector3(0.0, 0.035, 0.0), Vector2(BAR_WIDTH, 0.05))
	_health_fill = _bar(HEALTH_COLOR, Vector3(0.0, -0.035, 0.0), Vector2(BAR_WIDTH, 0.05))
	_bars.visible = false


func _bar(color: Color, pos: Vector3, bar_size: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = bar_size
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	_bars.add_child(mi)
	return mi


func _update_bars() -> void:
	_set_fill(_shield_fill, shield / max_shield if max_shield > 0.0 else 0.0)
	_set_fill(_health_fill, health / max_health)


## Shrinks the bar from the right.
func _set_fill(bar: MeshInstance3D, f: float) -> void:
	f = maxf(f, 0.001)
	bar.scale.x = f
	bar.position.x = -BAR_WIDTH * 0.5 * (1.0 - f)
