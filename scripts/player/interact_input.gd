class_name InteractInput
extends Node
## Interact (E) on your own player:
## - hold it next to a downed teammate you're looking roughly at to revive them, or while
##   you're downed to use a self-revive kit (the host runs the timer, see PlayerHealth);
## - press it at an Interactable you're looking at (the enemies lever...).
## Weapon pickups are the WeaponManager's: it only sees Interact when nothing here used
## it, because this node comes after Weapons in the player scene and gets input first.

const FACING := 0.5 ## Look at least this directly at a downed teammate (dot product)...
const NEAR := 1.2 ## ...unless they're this close.
const AIM := 0.85 ## How directly you look at an Interactable (dot product).
const ANSWER_TIME := 0.5 ## Seconds to wait for the host to start a revive before giving up.

@onready var player: Player = get_parent()

var _target: PlayerHealth ## Whoever we're reviving (maybe ourselves).
var _since_request := 0.0


## True while you're reviving someone else: you can't move, the host checks your distance.
func is_reviving() -> bool:
	return _target != null and _target != player.health


## The health of whoever Interact would revive right now, or null.
func get_candidate() -> PlayerHealth:
	var me := player.health
	if me.eliminated:
		return null
	if me.downed:
		return me if me.kits > 0 and me.reviver == 0 else null
	var eye := player.head.global_transform
	var best: PlayerHealth = null
	var best_dist := INF
	for p: Player in Game.players.get_children():
		if p == player or not p.health.downed or (p.health.reviver != 0 and p.health.reviver != player.peer_id):
			continue
		var dist := p.global_position.distance_to(player.global_position)
		if dist > me.revive_range or dist >= best_dist:
			continue
		var to := (p.global_position + Vector3.UP * 0.3 - eye.origin).normalized()
		if dist > NEAR and to.dot(-eye.basis.z) < FACING:
			continue
		best = p.health
		best_dist = dist
	return best


## The Interactable you're looking at and close enough to use, or null. Only while
## you're up.
func get_interactable() -> Interactable:
	if not player.health.is_up():
		return null
	var eye := player.head.global_transform
	var best: Interactable = null
	var best_dot := AIM
	for n in get_tree().get_nodes_in_group("interactables"):
		var it := n as Interactable
		if it == null or not it.can_use(player):
			continue
		var to := it.get_focus() - eye.origin
		if to.length() > it.reach:
			continue
		var dot := to.normalized().dot(-eye.basis.z)
		if dot > best_dot:
			best = it
			best_dot = dot
	return best


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if not event.is_action_pressed("interact"):
		return
	var t := get_candidate()
	if t != null:
		_target = t
		_since_request = 0.0
		t.request_revive.rpc_id(1)
		get_viewport().set_input_as_handled()
		return
	var it := get_interactable()
	if it != null:
		it.use(player)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	if not is_instance_valid(_target) or not _target.downed:
		_target = null # Done, or they bled out.
		return
	_since_request += delta
	if _since_request > ANSWER_TIME and _target.reviver != player.peer_id:
		_target = null # The host said no (someone else got there first).
		return
	var let_go := not Input.is_action_pressed("interact") or PauseMenu.visible
	var cut_off := is_reviving() and (not player.health.is_up() \
			or _target.player.global_position.distance_to(player.global_position) > player.health.revive_range + 0.5)
	if let_go or cut_off:
		_stop()


func _stop() -> void:
	if is_instance_valid(_target) and _target.reviver == player.peer_id:
		_target.cancel_revive.rpc_id(1)
	_target = null
