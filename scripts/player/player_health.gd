class_name PlayerHealth
extends Node
## A player's health, downed state and revives (the "Health" node under each Player).
## The host decides all of it and syncs it to everyone, so every player sees the same
## health bars. Clients only ask the host to start or stop a revive.
##
## At 0 health you're downed: you crawl, can't use weapons, and bleed out after
## bleed_out_time. A teammate holding Interact next to you revives you in revive_time;
## holding Interact yourself uses a self-revive kit (self_revive_time). A revive in
## progress pauses the bleed-out. Bleeding out takes you out (you spectate) until the
## map restarts. If nobody is left standing and nobody downed has a kit, it's a squad
## wipe (see Game).
## Shields (Apex style): up to max_shield of armour on top of your health, taking damage
## first. They never recharge by themselves: top them up with shield cells and batteries.
## Downed, they're gone; you get back up without them.
## Healing: standing and not hurt for regen_delay seconds, health trickles back at
## regen_rate (slowly). Or use a heal item (HEALS: syringe, medkit, trauma kit, shield cell,
## shield battery), picked from the heal
## wheel (hold the heal key; see HealInput): it then applies itself over its time while
## you move slowly and can't shoot, unless you cancel. You carry a few of each; more are lying
## around expeditions.

signal hurt(amount: float) ## Every peer, when health drops.
signal shield_hurt(amount: float, broke: bool) ## Every peer, when the shield takes damage (broke: and it's gone).
signal life_changed ## Every peer, when you go down, get back up, or are taken out. Once per frame at most.
signal hit_from(position: Vector3) ## Only on the owner's machine: where the damage came from.
signal knocked(impulse: Vector3) ## Only on the owner's machine: a hit with knockback (velocity to add).

## The heal items, quick and small to slow and big. amount: health (or, with shield,
## shield; with full, it fills both health and shield) restored; time:
## seconds it takes to apply; carry: most you can hold.
const HEALS := [
	{name = "SYRINGE", short = "SYRINGE", amount = 25.0, time = 2.0, carry = 4, color = Color(0.45, 1.0, 0.55)},
	{name = "MEDKIT", short = "MED", amount = 60.0, time = 4.0, carry = 2, color = Color(1.0, 0.3, 0.3)},
	{name = "TRAUMA KIT", short = "TRAUMA", amount = 100.0, time = 7.0, carry = 1, color = Color(1.0, 0.75, 0.2), full = true},
	{name = "SHIELD CELL", short = "CELL", amount = 25.0, time = 1.25, carry = 4, color = Color(0.35, 0.65, 1.0), shield = true},
	{name = "SHIELD BATTERY", short = "BATT", amount = 100.0, time = 2.5, carry = 2, color = Color(0.25, 0.45, 1.0), shield = true},
]

@export var max_health: float = 100.0
@export var revive_health: float = 30.0 ## Health you get back up with.
@export var bleed_out_time: float = 30.0
@export var revive_time: float = 5.0 ## A teammate reviving you.
@export var self_revive_time: float = 5.0 ## Using a self-revive kit.
@export var revive_range: float = 2.5 ## Metres between reviver and downed player.
@export var starting_kits: int = 1
@export var spawn_protection: float = 1.0 ## Seconds of no damage after the map (re)starts.
@export var regen_delay: float = 12.0 ## Seconds without taking damage before health starts coming back.
@export var regen_rate: float = 1.0 ## Health per second while regenerating (a minute and a half from empty).
@export var starting_heals: Array[int] = [2, 1, 0, 2, 0] ## How many of each HEALS item you start a map with.
@export var max_shield: float = 100.0 ## Its tier sets the bar colour (shield_color()): 100 is purple.
@export var starting_shield: float = 100.0 ## Shield you start a map with.

# Synced from the host. Order matters: see make_synchronizer().
var health: float = 100.0: set = _set_health
var eliminated: bool = false: set = _set_eliminated
var downed: bool = false: set = _set_downed
var kits: int = 1
var bleed_left: float = 0.0 ## Seconds until a downed player bleeds out.
var reviver: int = 0 ## Peer id doing the revive (the player themselves with a kit), 0 = nobody.
var revive_progress: float = 0.0 ## 0..1
var shield: float = 0.0: set = _set_shield
var heals: Array[int] = [2, 1, 0, 2, 0] ## How many of each HEALS item you carry. Always replaced whole, so it syncs.
var healing: bool = false ## Applying a heal right now.
var heal_kind: int = -1 ## Which one (index into HEALS).
var heal_progress: float = 0.0 ## 0..1

var _life_signal_queued := false
var _protected := 0.0 ## Host: seconds of spawn protection left.
var _since_hurt := 0.0 ## Host: seconds since the last damage, for regen.

@onready var player: Player = get_parent()


func _ready() -> void:
	if multiplayer.is_server():
		reset()


func is_up() -> bool:
	return not downed and not eliminated


func is_self_reviving() -> bool:
	return downed and reviver == player.peer_id


## Seconds a revive by this peer takes.
func revive_duration(by: int) -> float:
	return self_revive_time if by == player.peer_id else revive_time


## Synced from the host to everyone. Eliminated comes before downed, so bleeding out
## (eliminated on, then downed off) never looks like getting back up.
func make_synchronizer() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for prop: String in ["health", "eliminated", "downed", "kits", "bleed_left", "reviver", "revive_progress",
			"heals", "heal_kind", "healing", "heal_progress", "shield"]:
		var path := NodePath(".:" + prop)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = config
	sync.delta_interval = 1.0 / 20.0
	return sync


# --- Host ---------------------------------------------------------------------------

## Host only. `from` is where the damage came from, for the hit direction on screen.
## `knockback` (m/s) throws the player away from `from` and shakes their camera: big
## hits send you flying, even the one that downs you.
func take_damage(amount: float, from: Vector3 = Vector3.INF, knockback: float = 0.0) -> void:
	if not multiplayer.is_server() or not is_up() or amount <= 0.0 or _protected > 0.0:
		return
	var absorbed := minf(amount, shield) # The shield takes it first.
	shield -= absorbed
	health = maxf(health - (amount - absorbed), 0.0)
	_since_hurt = 0.0
	if from != Vector3.INF:
		_notify_hit.rpc_id(player.peer_id, from)
		if knockback > 0.0:
			var away := player.global_position - from
			away.y = 0.0
			away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
			_knock.rpc_id(player.peer_id, away * knockback + Vector3.UP * knockback * 0.4)
	if health <= 0.0:
		downed = true
		shield = 0.0
		bleed_left = bleed_out_time
		_stop_revive()


## Host only: full health and shield, back on your feet, kits and heals restocked (map start).
func reset() -> void:
	health = max_health
	shield = starting_shield
	eliminated = false
	downed = false
	kits = starting_kits
	heals = starting_heals.duplicate()
	bleed_left = 0.0
	_protected = spawn_protection
	_stop_revive()
	_stop_heal()


## Host only: picked up a heal item. False if you can't carry another of that kind.
func give_heal(kind: int) -> bool:
	if not can_carry(kind):
		return false
	var h := heals.duplicate()
	h[kind] += 1
	heals = h
	return true


func can_carry(kind: int) -> bool:
	return kind >= 0 and kind < HEALS.size() and heals[kind] < int(HEALS[kind].carry)


## Could you use this heal right now? (Shield items need a dented shield; the rest, lost health.)
func can_heal_with(kind: int) -> bool:
	return kind >= 0 and kind < HEALS.size() and heals[kind] > 0 and is_up() and not healing and needs(kind)


## Would this item do anything for you?
func needs(kind: int) -> bool:
	if is_full_item(kind):
		return health < max_health or shield < max_shield
	return shield < max_shield if is_shield_item(kind) else health < max_health


## What a heal item does, for the wheel and the inventory: "+25 HP", "FULL SHIELD",
## "FULL HEAL + SHIELD"...
func describe(kind: int) -> String:
	var item: Dictionary = HEALS[kind]
	if is_full_item(kind):
		return "FULL HEAL + SHIELD"
	if is_shield_item(kind):
		return "FULL SHIELD" if float(item.amount) >= max_shield else "+%d SHIELD" % int(item.amount)
	return "FULL HEALTH" if float(item.amount) >= max_health else "+%d HP" % int(item.amount)


## Fills health and shield both (the trauma kit).
static func is_full_item(kind: int) -> bool:
	return kind >= 0 and kind < HEALS.size() and (HEALS[kind] as Dictionary).get("full", false)


## The shield's colour for its capacity, Apex tiers: white 50, blue 75, purple 100, red 125.
static func shield_color(capacity: float) -> Color:
	if capacity >= 125.0:
		return Color(1.0, 0.25, 0.25)
	if capacity >= 100.0:
		return Color(0.72, 0.35, 1.0)
	if capacity >= 75.0:
		return Color(0.35, 0.65, 1.0)
	return Color(0.9, 0.9, 0.9)


static func is_shield_item(kind: int) -> bool:
	return kind >= 0 and kind < HEALS.size() and (HEALS[kind] as Dictionary).get("shield", false)


func total_heals() -> int:
	var n := 0
	for c in heals:
		n += c
	return n


func _physics_process(delta: float) -> void:
	_protected = maxf(_protected - delta, 0.0)
	if not multiplayer.is_server():
		return
	_since_hurt += delta
	if is_up() and health < max_health and _since_hurt >= regen_delay:
		health = minf(health + regen_rate * delta, max_health)
	if healing:
		if not is_up() or heals[heal_kind] <= 0:
			_stop_heal()
		else:
			var item: Dictionary = HEALS[heal_kind]
			heal_progress = minf(heal_progress + delta / float(item.time), 1.0)
			if heal_progress >= 1.0:
				if is_full_item(heal_kind): # Trauma kit: everything back.
					health = max_health
					shield = max_shield
				elif is_shield_item(heal_kind):
					shield = minf(shield + float(item.amount), max_shield)
				else:
					health = minf(health + float(item.amount), max_health)
				var h := heals.duplicate()
				h[heal_kind] -= 1
				heals = h
				_stop_heal()
	if not downed:
		return
	if reviver != 0:
		if not _reviver_still_valid():
			_stop_revive()
			return
		revive_progress = minf(revive_progress + delta / revive_duration(reviver), 1.0)
		if revive_progress >= 1.0:
			if reviver == player.peer_id:
				kits -= 1
			health = revive_health
			downed = false
			_since_hurt = 0.0 # Regen starts regen_delay after getting up, not straight away.
			_stop_revive()
		return
	bleed_left = maxf(bleed_left - delta, 0.0)
	if bleed_left <= 0.0:
		eliminated = true
		downed = false
		health = 0.0
		# Their body stays behind, for anyone to drag about.
		Game.spawn_corpse(Transform3D(player.global_basis, player.global_position),
				Player.COLORS[player.slot % Player.COLORS.size()], Vector3(0.0, 0.5, 0.0))


func _reviver_still_valid() -> bool:
	if reviver == player.peer_id:
		return kits > 0
	var by := Game.players.get_node_or_null(str(reviver)) as Player
	# The host sees other players a moment late, so allow a little extra range.
	return by != null and by.health.is_up() \
			and by.global_position.distance_to(player.global_position) <= revive_range + 1.0


func _stop_revive() -> void:
	reviver = 0
	revive_progress = 0.0


func _stop_heal() -> void:
	healing = false
	heal_progress = 0.0


# --- Requests from players ------------------------------------------------------------

## A teammate next to this downed player, or the player themselves with a kit, asks
## the host to start reviving.
@rpc("any_peer", "call_local", "reliable")
func request_revive() -> void:
	if not multiplayer.is_server() or not downed or reviver != 0:
		return
	reviver = multiplayer.get_remote_sender_id()
	revive_progress = 0.0
	if not _reviver_still_valid():
		_stop_revive()


## Let go of Interact (or moved off): the revive stops and its progress is lost.
@rpc("any_peer", "call_local", "reliable")
func cancel_revive() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == reviver:
		_stop_revive()


## The player picked a heal from the wheel: it applies itself from here on (the host
## counts it down) unless they cancel. Only while up, hurt, and carrying one.
@rpc("any_peer", "call_local", "reliable")
func request_heal(kind: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player.peer_id:
		return
	if can_heal_with(kind):
		heal_kind = kind
		heal_progress = 0.0
		healing = true


## A supply crate (SupplyCrate): fill the pouch with every heal and shield item.
@rpc("any_peer", "call_local", "reliable")
func request_supplies() -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player.peer_id:
		return
	var h: Array[int] = []
	for item: Dictionary in HEALS:
		h.append(int(item.carry))
	heals = h


## Cancelled (fired, sprinted, switched weapon...): the item isn't used up.
@rpc("any_peer", "call_local", "reliable")
func cancel_heal() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.peer_id:
		_stop_heal()


## Host only: ammo this player picked up. Ammo lives in their WeaponManager, which only
## their own machine has, so it's passed on to them.
func give_ammo(type: String, rounds: int) -> void:
	if multiplayer.is_server():
		_give_ammo.rpc_id(player.peer_id, type, rounds)


@rpc("authority", "call_local", "reliable")
func _give_ammo(type: String, rounds: int) -> void:
	var weapons := player.get_node_or_null("Weapons") as WeaponManager
	if weapons != null:
		weapons.receive_ammo(type, rounds)


@rpc("authority", "call_local", "reliable")
func _knock(impulse: Vector3) -> void:
	knocked.emit(impulse)


@rpc("authority", "call_local", "unreliable")
func _notify_hit(from: Vector3) -> void:
	hit_from.emit(from)


# --- Setters (run on every peer as values sync in) --------------------------------------

func _set_health(v: float) -> void:
	var drop := health - v
	health = v
	if drop > 0.0:
		hurt.emit(drop)


func _set_shield(v: float) -> void:
	var drop := shield - v
	shield = v
	if drop > 0.0:
		shield_hurt.emit(drop, v <= 0.0)


func _set_downed(v: bool) -> void:
	if v != downed:
		downed = v
		_queue_life_signal()


func _set_eliminated(v: bool) -> void:
	if v != eliminated:
		eliminated = v
		_queue_life_signal()


func _queue_life_signal() -> void:
	if not _life_signal_queued:
		_life_signal_queued = true
		_emit_life_changed.call_deferred()


func _emit_life_changed() -> void:
	_life_signal_queued = false
	life_changed.emit()
