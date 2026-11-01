extends SceneTree
## Run with Godot --headless --path . --script res://scripts/network/signaling_server.gd
## Optional user arguments: -- --bind=127.0.0.1 --port=9080
## Public deployments must terminate WSS at a reverse proxy.

const Settings: GDScript = preload("res://scripts/network/webrtc_config.gd")
const CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var _listener: TCPServer = TCPServer.new()
var _clients: Dictionary = {}
var _rooms: Dictionary = {}
var _next_id: int = 1


func _initialize() -> void:
	var address: String = "127.0.0.1"
	var port: int = Settings.DEFAULT_PORT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--bind="):
			address = argument.trim_prefix("--bind=")
		elif argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
	var error: Error = _listener.listen(port, address)
	if error != OK:
		push_error("Cannot start signaling service: %s" % error_string(error))
		quit(1)
		return
	print("Hukulshish signaling: ws://%s:%d (three players per room)" % [address, port])


func _process(_delta: float) -> bool:
	while _listener.is_connection_available():
		var stream: StreamPeerTCP = _listener.take_connection()
		if _clients.size() >= Settings.MAX_CONNECTIONS:
			stream.disconnect_from_host()
			continue
		var socket: WebSocketPeer = WebSocketPeer.new()
		var error: Error = socket.accept_stream(stream)
		if error != OK:
			stream.disconnect_from_host()
			continue
		_clients[_next_id] = {
			"socket": socket, "room": "", "peer": 0,
			"created": Time.get_ticks_msec(), "window": Time.get_ticks_msec(), "messages": 0,
		}
		_next_id += 1
	for id: int in _clients.keys():
		var client: Dictionary = _clients[id]
		var socket: WebSocketPeer = client["socket"]
		socket.poll()
		var state: int = socket.get_ready_state()
		if state == WebSocketPeer.STATE_CLOSED:
			_remove_client(id)
			continue
		if String(client["room"]).is_empty() and (
			Time.get_ticks_msec() - int(client["created"]) > Settings.CONNECTION_TIMEOUT_SEC * 1000.0
		):
			_remove_client(id)
			continue
		if state != WebSocketPeer.STATE_OPEN:
			continue
		while socket.get_available_packet_count() > 0 and _clients.has(id):
			var packet: PackedByteArray = socket.get_packet()
			if not socket.was_string_packet() or packet.size() > Settings.MAX_SIGNAL_BYTES:
				_remove_client(id)
				break
			var now: int = Time.get_ticks_msec()
			if now - int(client["window"]) >= 1000:
				client["window"] = now
				client["messages"] = 0
			client["messages"] = int(client["messages"]) + 1
			if int(client["messages"]) > Settings.MAX_MESSAGES_PER_SECOND:
				_remove_client(id)
				break
			var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if parsed is not Dictionary:
				_remove_client(id)
				break
			_handle_message(id, parsed)
	return false


func _handle_message(id: int, message: Dictionary) -> void:
	var kind: String = str(message.get("type", ""))
	var client: Dictionary = _clients[id]
	if kind == "create" or kind == "join":
		if not String(client["room"]).is_empty():
			_reject(id, "Already in a room.")
			return
		if message.get("version") != Settings.PROTOCOL_VERSION:
			_reject(id, "Client and server versions do not match.")
			return
		if kind == "create":
			_create_room(id)
		else:
			_join_room(id, str(message.get("room", "")).strip_edges().to_upper())
	elif kind == "signal":
		_relay_signal(id, message)
	else:
		_reject(id, "Unknown message.")


func _create_room(id: int) -> void:
	var code: String = _new_code()
	while _rooms.has(code):
		code = _new_code()
	_rooms[code] = {Settings.HOST_ID: id}
	_clients[id]["room"] = code
	_clients[id]["peer"] = Settings.HOST_ID
	_send(id, {"type": "joined", "room": code, "id": Settings.HOST_ID})


func _join_room(id: int, code: String) -> void:
	if not _rooms.has(code):
		_reject(id, "Room not found.")
		return
	var members: Dictionary = _rooms[code]
	if members.size() >= Settings.MAX_PLAYERS:
		_reject(id, "This room already has three players.")
		return
	var peer_id: int = 2
	while members.has(peer_id):
		peer_id += 1
	members[peer_id] = id
	_clients[id]["room"] = code
	_clients[id]["peer"] = peer_id
	_send(id, {"type": "joined", "room": code, "id": peer_id})
	_send(int(members[Settings.HOST_ID]), {"type": "peer_joined", "id": peer_id})


func _relay_signal(id: int, message: Dictionary) -> void:
	var client: Dictionary = _clients[id]
	var code: String = client["room"]
	if not _rooms.has(code):
		return
	var members: Dictionary = _rooms[code]
	var source: int = client["peer"]
	var target: int = int(message.get("to", 0))
	# Only host/guest connections are allowed. The sender ID always comes from the server.
	if source == target or not members.has(target):
		return
	if source != Settings.HOST_ID and target != Settings.HOST_ID:
		return
	var data: Variant = message.get("data")
	if data is not Dictionary:
		return
	_send(int(members[target]), {"type": "signal", "from": source, "data": data})


func _remove_client(id: int) -> void:
	if not _clients.has(id):
		return
	var client: Dictionary = _clients[id]
	_clients.erase(id)
	var socket: WebSocketPeer = client["socket"]
	socket.close()
	var code: String = client["room"]
	if not _rooms.has(code):
		return
	var members: Dictionary = _rooms[code]
	var peer_id: int = client["peer"]
	if peer_id == Settings.HOST_ID:
		_rooms.erase(code)
		for guest: int in members:
			if guest != Settings.HOST_ID:
				var guest_id: int = members[guest]
				_send(guest_id, {"type": "room_closed"})
				_clients[guest_id]["room"] = ""
				_clients[guest_id]["peer"] = 0
	else:
		members.erase(peer_id)
		_send(int(members[Settings.HOST_ID]), {"type": "peer_left", "id": peer_id})


func _reject(id: int, reason: String) -> void:
	_send(id, {"type": "error", "message": reason})


func _send(id: int, message: Dictionary) -> void:
	if _clients.has(id):
		var socket: WebSocketPeer = _clients[id]["socket"]
		socket.send_text(JSON.stringify(message))


func _new_code() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(Settings.ROOM_CODE_LENGTH)
	var code: String = ""
	for value: int in bytes:
		code += CODE_ALPHABET[value % CODE_ALPHABET.length()]
	return code
