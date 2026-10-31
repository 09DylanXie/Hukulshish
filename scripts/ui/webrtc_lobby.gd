extends Control
## Isolated connection/movement prototype. Does not start or modify a survival run.

const Settings: GDScript = preload("res://scripts/network/webrtc_config.gd")
const SessionScript: GDScript = preload("res://scripts/network/webrtc_session.gd")
const COLORS: Array[Color] = [Color.CORNFLOWER_BLUE, Color.MEDIUM_SEA_GREEN, Color.ORANGE]

var _session: SessionScript
var _url: LineEdit
var _code: LineEdit
var _ice: LineEdit
var _status: Label
var _host_button: Button
var _join_button: Button
var _arena: Control
var _positions: Dictionary = {}
var _inputs: Dictionary = {}
var _input_times: Dictionary = {}
var _send_timer: float = 0.0


func _ready() -> void:
	name = "WebRTCLobby"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box: VBoxContainer = UIKit.make_centered_menu(self, "Three-player co-op", "WebRTC connection test - combat is not connected yet")
	box.custom_minimum_size.x = 780
	_url = _field(box, "Signaling service URL", "ws://127.0.0.1:9080")
	_code = _field(box, "Room code (leave empty when hosting)", "")
	_ice = _field(box, "ICE servers JSON (local tests can use [])", "[]")
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	_host_button = UIKit.make_button("Host room", _connect_room.bind(true))
	_join_button = UIKit.make_button("Join room", _connect_room.bind(false))
	buttons.add_child(_host_button)
	buttons.add_child(_join_button)
	_status = UIKit.make_label("Host a room, then share its code with two friends.", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_arena = Control.new()
	_arena.custom_minimum_size = Vector2(780, 220)
	_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.draw.connect(_draw_arena)
	box.add_child(_arena)
	box.add_child(UIKit.make_label("WASD / arrows: move your colored marker", 18))
	box.add_child(UIKit.make_button("Leave room", _leave))
	box.add_child(UIKit.make_button("Back", queue_free))
	_session = SessionScript.new()
	_session.name = "Session"
	_session.room_joined.connect(_on_joined)
	_session.peer_connected.connect(_on_connected)
	_session.peer_disconnected.connect(_on_disconnected)
	_session.failed.connect(_on_failed)
	add_child(_session)


func _field(box: VBoxContainer, caption: String, initial: String) -> LineEdit:
	box.add_child(UIKit.make_label(caption, 18))
	var field: LineEdit = LineEdit.new()
	field.text = initial
	field.custom_minimum_size.y = 42
	field.add_theme_font_size_override("font_size", 20)
	box.add_child(field)
	return field


func _connect_room(hosting: bool) -> void:
	if not hosting and _code.text.strip_edges().is_empty():
		_status.text = "Enter the host's room code."
		return
	var parsed: Variant = JSON.parse_string(_ice.text)
	if parsed is not Array:
		_status.text = "ICE settings must be a JSON array."
		return
	var servers: Array[Dictionary] = []
	for item: Variant in parsed:
		if item is not Dictionary or not item.has("urls"):
			_status.text = "Each ICE server needs a urls entry."
			return
		servers.append(item)
	_positions.clear()
	_inputs.clear()
	_input_times.clear()
	var error: Error = _session.connect_room(
		_url.text.strip_edges(), "" if hosting else _code.text, servers
	)
	if error != OK:
		_status.text = "Cannot connect: %s. HTTPS pages require a wss:// service." % error_string(error)
		return
	_set_busy(true)
	get_viewport().gui_release_focus()
	_status.text = "Connecting..."


func _on_joined(code: String, peer_id: int) -> void:
	_code.text = code
	if peer_id == Settings.HOST_ID:
		_add_player(peer_id)
	_status.text = "Room %s - you are player %d. Waiting for WebRTC peers." % [code, peer_id]


func _on_connected(id: int) -> void:
	if _session.local_id == Settings.HOST_ID:
		_add_player(id)
	_status.text = "Room %s - %d / 3 players connected. You are player %d." % [
		_session.room_code, multiplayer.get_peers().size() + 1, _session.local_id,
	]


func _on_disconnected(id: int) -> void:
	_positions.erase(id)
	_inputs.erase(id)
	_input_times.erase(id)
	_status.text = "Player %d disconnected." % id


func _on_failed(reason: String) -> void:
	_reset()
	_status.text = reason


func _leave() -> void:
	_session.close()
	_reset()
	_status.text = "Left the room."


func _reset() -> void:
	_positions.clear()
	_inputs.clear()
	_input_times.clear()
	_set_busy(false)
	_arena.queue_redraw()


func _set_busy(busy: bool) -> void:
	_host_button.disabled = busy
	_join_button.disabled = busy
	_url.editable = not busy
	_ice.editable = not busy
	_code.editable = not busy


func _add_player(id: int) -> void:
	_positions[id] = Vector2(float(id) / float(Settings.MAX_PLAYERS + 1), 0.5)
	_inputs[id] = Vector2.ZERO
	_input_times[id] = Time.get_ticks_msec()


func _physics_process(delta: float) -> void:
	if _session == null or _session.local_id == 0:
		return
	var direction: Vector2 = Vector2.ZERO
	if not get_viewport().gui_get_focus_owner() is LineEdit:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_send_timer += delta
	if _session.local_id == Settings.HOST_ID:
		_inputs[Settings.HOST_ID] = direction
		_input_times[Settings.HOST_ID] = Time.get_ticks_msec()
		var speed: float = Config.tiles(Config.PLAYER_SPEED_TILES)
		for id: int in _positions:
			var movement: Vector2 = _inputs.get(id, Vector2.ZERO)
			if Time.get_ticks_msec() - int(_input_times.get(id, 0)) > Settings.INPUT_TIMEOUT_SEC * 1000.0:
				movement = Vector2.ZERO
			var position: Vector2 = _positions[id]
			position += movement * speed * delta / _arena.size
			_positions[id] = position.clamp(Vector2(0.04, 0.1), Vector2(0.96, 0.9))
		if _send_timer >= Settings.INPUT_INTERVAL_SEC and not multiplayer.get_peers().is_empty():
			_receive_positions.rpc(_positions)
	elif _send_timer >= Settings.INPUT_INTERVAL_SEC and multiplayer.get_peers().has(Settings.HOST_ID):
		_submit_input.rpc_id(Settings.HOST_ID, direction)
	if _send_timer >= Settings.INPUT_INTERVAL_SEC:
		_send_timer = 0.0
	_arena.queue_redraw()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_input(direction: Vector2) -> void:
	if _session.local_id != Settings.HOST_ID or not direction.is_finite():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _positions.has(sender):
		return
	_inputs[sender] = direction.limit_length(1.0)
	_input_times[sender] = Time.get_ticks_msec()


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_positions(positions: Dictionary) -> void:
	if _session.local_id == Settings.HOST_ID:
		return
	_positions = positions


func _draw_arena() -> void:
	_arena.draw_style_box(_arena_style(), Rect2(Vector2.ZERO, _arena.size))
	for id: int in _positions:
		var point: Vector2 = (_positions[id] as Vector2) * _arena.size
		_arena.draw_circle(point, 12.0, COLORS[id - 1])
		_arena.draw_string(ThemeDB.fallback_font, point + Vector2(-4, -20), str(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 18)


func _arena_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.08)
	style.border_color = Color(0.3, 0.4, 0.6)
	style.set_border_width_all(2)
	return style
