extends Node

const PORT = 7777
const MAX_PLAYERS = 2

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed
signal server_disconnected

var players: Dictionary = {}
var _ngrok_pid: int = -1

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host() -> bool:
	var peer = WebSocketMultiplayerPeer.new()
	var err = peer.create_server(PORT)
	if err != OK:
		return false
	multiplayer.multiplayer_peer = peer
	players[1] = 1
	return true

func join(url: String) -> bool:
	# ws:// または wss:// がなければ ws:// を付ける
	var ws_url = url
	if not url.begins_with("ws://") and not url.begins_with("wss://"):
		if url.begins_with("https://"):
			ws_url = "wss://" + url.trim_prefix("https://")
		elif url.begins_with("http://"):
			ws_url = "ws://" + url.trim_prefix("http://")
		else:
			ws_url = "ws://" + url
	var peer = WebSocketMultiplayerPeer.new()
	var headers = PackedStringArray(["ngrok-skip-browser-warning: true"])
	var err = peer.create_client(ws_url, [], headers)
	if err != OK:
		return false
	multiplayer.multiplayer_peer = peer
	return true

func start_ngrok() -> int:
	# ngrokプロセスを起動してPIDを返す
	var pid = OS.create_process("ngrok", ["http", str(PORT), "--log=stdout"])
	_ngrok_pid = pid
	return pid

func stop_ngrok() -> void:
	if _ngrok_pid > 0:
		OS.kill(_ngrok_pid)
		_ngrok_pid = -1

func get_sorted_ids() -> Array:
	var ids = players.keys()
	ids.sort()
	return ids

func _on_peer_connected(id: int) -> void:
	players[id] = id
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	var id = multiplayer.get_unique_id()
	players[id] = id
	player_connected.emit(id)

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	server_disconnected.emit()
