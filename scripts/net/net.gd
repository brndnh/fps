extends Node
## Connection to other players (autoload "Net"): host a game, or join one by address.
## ENet for now: LAN, or over the internet with the host's UDP port forwarded. Steam
## lobbies will replace the peer setup in host() and join() later. Nothing else touches
## the transport, so the rest of the game won't need to change for that.
##
## From the command line (after `--`): --host, --join=<address>, --port=<n>
##   godot --path . -- --host
##   godot --path . -- --join=127.0.0.1

signal joining ## About to connect to a host: the offline session's players have to go first.
signal session_ended(was_host: bool) ## Back offline: left, the host went away, or the connection failed.
signal status_changed

enum State { OFFLINE, HOSTING, CONNECTING, CONNECTED }

const DEFAULT_PORT := 24680
const MAX_PLAYERS := 10 ## Host included.

var state: State = State.OFFLINE
var status: String = "Offline" ## One line for the UI: what's happening, or what went wrong.


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_leave.bind("Couldn't reach the host"))
	multiplayer.server_disconnected.connect(_leave.bind("The host left"))
	multiplayer.peer_connected.connect(func(_id: int) -> void: status_changed.emit())
	multiplayer.peer_disconnected.connect(func(_id: int) -> void: status_changed.emit())
	_run_command_line.call_deferred()


func is_online() -> bool:
	return state != State.OFFLINE


## Players in the session, you included.
func player_count() -> int:
	if state == State.CONNECTING:
		return 0
	return multiplayer.get_peers().size() + 1


func host(port: int = DEFAULT_PORT) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		_set_state(State.OFFLINE, "Couldn't host on port %d (%s)" % [port, error_string(err)])
		return
	multiplayer.multiplayer_peer = peer
	_set_state(State.HOSTING, "Hosting on port %d" % port)


func join(address: String, port: int = DEFAULT_PORT) -> void:
	leave()
	address = address.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_set_state(State.OFFLINE, "Couldn't connect to %s:%d (%s)" % [address, port, error_string(err)])
		return
	joining.emit()
	multiplayer.multiplayer_peer = peer
	_set_state(State.CONNECTING, "Connecting to %s:%d…" % [address, port])


func leave() -> void:
	_leave("Offline")


func _leave(reason: String) -> void:
	if state == State.OFFLINE:
		return
	var was_host := state == State.HOSTING
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_state(State.OFFLINE, reason)
	session_ended.emit(was_host)


func _on_connected() -> void:
	_set_state(State.CONNECTED, "Connected")


func _set_state(s: State, text: String) -> void:
	state = s
	status = text
	print("[Net] ", text)
	status_changed.emit()


func _run_command_line() -> void:
	var port := DEFAULT_PORT
	var address := ""
	var hosting := false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--host":
			hosting = true
		elif arg.begins_with("--join="):
			address = arg.trim_prefix("--join=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	if hosting:
		host(port)
	elif not address.is_empty():
		join(address, port)
