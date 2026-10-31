extends Node
## Host-authoritative WebRTC star: peer 1 hosts; peers 2 and 3 connect to peer 1.
## The signaling service carries SDP/ICE only, never gameplay state.

signal room_joined(code: String, peer_id: int)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal failed(reason: String)

const Settings: GDScript = preload("res://scripts/network/webrtc_config.gd")

var local_id: int = 0
var room_code: String = ""
var _socket: WebSocketPeer
var _peer: WebRTCMultiplayerPeer
var _connections: Dictionary = {}
var _remote_descriptions: Dictionary = {}
var _pending_candidates: Dictionary = {}
var _deadlines: Dictionary = {}
var _ice_servers: Array[Dictionary] = []
var _request: Dictionary = {}
var _started_at: int = 0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func connect_room(url: String, code: String, ice_servers: Array[Dictionary]) -> Error:
	close()
	if not url.begins_with("ws://") and not url.begins_with("wss://"):
		return ERR_INVALID_PARAMETER
	if OS.has_feature("web") and JavaScriptBridge.eval("location.protocol") == "https:":
		if not url.begins_with("wss://"):
			return ERR_UNAUTHORIZED
	_ice_servers = ice_servers.duplicate(true)
	_request = {"type": "create" if code.is_empty() else "join", "version": Settings.PROTOCOL_VERSION}
	if not code.is_empty():
		_request["room"] = code.strip_edges().to_upper()
	_socket = WebSocketPeer.new()
	_started_at = Time.get_ticks_msec()
	var error: Error = _socket.connect_to_url(url)
	if error != OK:
		close()
	return error


func close() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	if _peer != null:
		_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_peer = null
	_connections.clear()
	_remote_descriptions.clear()
	_pending_candidates.clear()
	_deadlines.clear()
	_request.clear()
	local_id = 0
	room_code = ""


func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	var state: int = _socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		_fail("Signaling disconnected. Reconnect to create or join a room.")
		return
	if local_id == 0 and Time.get_ticks_msec() - _started_at > Settings.CONNECTION_TIMEOUT_SEC * 1000.0:
		_fail("Room connection timed out.")
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	if not _request.is_empty():
		_send(_request)
		_request.clear()
	while _socket != null and _socket.get_available_packet_count() > 0:
		var packet: PackedByteArray = _socket.get_packet()
		if packet.size() > Settings.MAX_SIGNAL_BYTES:
			_fail("Signaling message exceeded the protocol limit.")
			return
		var message: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if message is Dictionary:
			_handle_message(message)
	for id: int in _deadlines.keys():
		if Time.get_ticks_msec() > int(_deadlines[id]):
			_fail("WebRTC connection timed out. Check the STUN/TURN settings and both networks.")
			return


func _handle_message(message: Dictionary) -> void:
	match str(message.get("type", "")):
		"joined":
			local_id = int(message.get("id", 0))
			if local_id < 1 or local_id > Settings.MAX_PLAYERS or _peer != null:
				_fail("Invalid room assignment.")
				return
			_peer = WebRTCMultiplayerPeer.new()
			var error: Error = _peer.create_server() if local_id == Settings.HOST_ID else _peer.create_client(local_id)
			if error != OK:
				_fail("Cannot initialize WebRTC: %s" % error_string(error))
				return
			multiplayer.multiplayer_peer = _peer
			room_code = str(message.get("room", ""))
			if local_id != Settings.HOST_ID and not _add_connection(Settings.HOST_ID):
				return
			room_joined.emit(room_code, local_id)
		"peer_joined":
			if local_id == Settings.HOST_ID:
				var id: int = int(message.get("id", 0))
				if _add_connection(id):
					var connection: WebRTCPeerConnection = _connections[id]
					if connection.create_offer() != OK:
						_fail("Cannot create a WebRTC offer.")
		"peer_left":
			var id: int = int(message.get("id", 0))
			if _peer != null and _peer.has_peer(id):
				_peer.remove_peer(id)
			_forget_connection(id)
		"signal":
			_handle_signal(int(message.get("from", 0)), message.get("data", {}))
		"error":
			_fail(str(message.get("message", "Room request failed.")))
		"room_closed":
			_fail("The host left. This room has closed.")


func _add_connection(id: int) -> bool:
	if id < 1 or id > Settings.MAX_PLAYERS or id == local_id or _connections.has(id):
		return false
	var connection: WebRTCPeerConnection = WebRTCPeerConnection.new()
	var error: Error = connection.initialize({"iceServers": _ice_servers})
	if error != OK:
		_fail("WebRTC is unavailable. Native builds need the webrtc-native extension.")
		return false
	connection.session_description_created.connect(_on_description.bind(id))
	connection.ice_candidate_created.connect(_on_candidate.bind(id))
	error = _peer.add_peer(connection, id)
	if error != OK:
		connection.close()
		_fail("Cannot add WebRTC peer: %s" % error_string(error))
		return false
	_connections[id] = connection
	_pending_candidates[id] = []
	_deadlines[id] = Time.get_ticks_msec() + int(Settings.CONNECTION_TIMEOUT_SEC * 1000.0)
	return true


func _on_description(kind: String, sdp: String, id: int) -> void:
	if not _connections.has(id):
		return
	var connection: WebRTCPeerConnection = _connections[id]
	if connection.set_local_description(kind, sdp) != OK:
		_fail("Cannot set local WebRTC description.")
		return
	_send_signal(id, {"type": "description", "kind": kind, "sdp": sdp})


func _on_candidate(media: String, index: int, candidate: String, id: int) -> void:
	_send_signal(id, {"type": "candidate", "media": media, "index": index, "candidate": candidate})


func _handle_signal(id: int, data: Variant) -> void:
	if not _connections.has(id) or data is not Dictionary:
		return
	var connection: WebRTCPeerConnection = _connections[id]
	match str(data.get("type", "")):
		"description":
			var kind: String = str(data.get("kind", ""))
			if kind != ("answer" if local_id == Settings.HOST_ID else "offer"):
				return
			if connection.set_remote_description(kind, str(data.get("sdp", ""))) != OK:
				_fail("Cannot accept WebRTC description.")
				return
			_remote_descriptions[id] = true
			for pending: Dictionary in _pending_candidates[id]:
				if not _apply_candidate(connection, pending):
					return
			_pending_candidates[id] = []
		"candidate":
			if _remote_descriptions.has(id):
				_apply_candidate(connection, data)
			else:
				_pending_candidates[id].append(data)


func _apply_candidate(connection: WebRTCPeerConnection, data: Dictionary) -> bool:
	var error: Error = connection.add_ice_candidate(
		str(data.get("media", "")), int(data.get("index", 0)), str(data.get("candidate", ""))
	)
	if error != OK:
		_fail("Cannot accept WebRTC ICE candidate.")
		return false
	return true


func _on_peer_connected(id: int) -> void:
	_deadlines.erase(id)
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	_forget_connection(id)
	peer_disconnected.emit(id)


func _forget_connection(id: int) -> void:
	if _connections.has(id):
		var connection: WebRTCPeerConnection = _connections[id]
		connection.close()
	_connections.erase(id)
	_remote_descriptions.erase(id)
	_pending_candidates.erase(id)
	_deadlines.erase(id)


func _on_connection_failed() -> void:
	_fail("Could not connect to the host.")


func _on_server_disconnected() -> void:
	_fail("The host disconnected. Rejoin or create a new room.")


func _send_signal(id: int, data: Dictionary) -> void:
	_send({"type": "signal", "to": id, "data": data})


func _send(message: Dictionary) -> void:
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if _socket.send_text(JSON.stringify(message)) != OK:
			_fail("Cannot send signaling data.")


func _fail(reason: String) -> void:
	close()
	failed.emit(reason)


func _exit_tree() -> void:
	close()
