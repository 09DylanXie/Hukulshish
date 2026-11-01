extends Node
## Online co-op (autoload "Coop"). The host runs the only real simulation. Guests send inputs and
## requests, and draw the snapshots they receive. Works over LAN (ENet) or WebRTC, which only differ
## in how the MultiplayerPeer is created.

signal roster_changed
signal failed(reason: String)

const SessionScript: GDScript = preload("res://scripts/network/webrtc_session.gd")
const Settings: GDScript = preload("res://scripts/network/webrtc_config.gd")
const HOST_SEAT: int = 1
const LAN_PORT: int = 9081
const SELF_STATE_INTERVAL_SEC: float = 0.25
## Requests a guest may make of their own RunState. Everything else is refused.
const ALLOWED_ACTIONS: Array[String] = ["toggle_homing"]
## Sounds only the person using the menu or item should hear.
const PRIVATE_SOUNDS: Array[String] = ["ui_click", "shop_buy", "shop_deny", "castle_enter", "potion_use"]

## WebRTC signaling and connections.
var session: Node
var in_run: bool = false
## Peer ID -> seat (1 to 3). Seats, not peer IDs, identify players, because ENet IDs are random.
var seats: Dictionary = {}
var local_seat: int = HOST_SEAT
## Why the last session ended, for the Main Menu to show.
var last_message: String = ""

var _game: Node
var _waiting_peers: Array[int] = []
var _ready_peers: Array[int] = []
var _events: Array = []
var _last_input_ms: Dictionary = {}
var _input_timer: float = 0.0
var _self_state_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = SessionScript.new()
	session.name = "Session"
	session.failed.connect(_on_session_failed)
	session.room_joined.connect(_on_room_joined)
	add_child(session)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- Connecting ---

func host_lan(port: int = LAN_PORT) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, Settings.MAX_PLAYERS - 1)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		seats = {multiplayer.get_unique_id(): HOST_SEAT}
		roster_changed.emit()
	return error


func join_lan(address: String, port: int = LAN_PORT) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


## The host needs a seat before anyone joins.
func _on_room_joined(_code: String, _peer_id: int) -> void:
	if multiplayer.is_server():
		seats = {multiplayer.get_unique_id(): HOST_SEAT}
		roster_changed.emit()


func close() -> void:
	session.close()
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	in_run = false
	seats.clear()
	local_seat = HOST_SEAT
	_game = null
	_waiting_peers.clear()
	_ready_peers.clear()
	_events.clear()
	_last_input_ms.clear()
	GameState.is_mirror = false
	GameState.coop_mode = false


func _end_session(reason: String) -> void:
	var was_running: bool = in_run
	close()
	last_message = reason
	failed.emit(reason)
	if was_running:
		SceneRouter.goto(SceneRouter.MAIN_MENU)


func _on_session_failed(reason: String) -> void:
	_end_session(reason)


func _on_connection_failed() -> void:
	_end_session("Could not reach the host.")


func _on_server_disconnected() -> void:
	_end_session("The host left, so the game ended.")


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var seat: int = _free_seat()
	if in_run or seat == 0:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	seats[peer_id] = seat
	_receive_seats.rpc(seats)
	roster_changed.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server() or not seats.has(peer_id):
		return
	var seat: int = seats[peer_id]
	seats.erase(peer_id)
	_ready_peers.erase(peer_id)
	_waiting_peers.erase(peer_id)
	_last_input_ms.erase(peer_id)
	if _game_running():
		_game.remove_coop_player(seat)
	_receive_seats.rpc(seats)
	roster_changed.emit()


func _free_seat() -> int:
	for seat in range(HOST_SEAT + 1, Settings.MAX_PLAYERS + 1):
		if not seats.values().has(seat):
			return seat
	return 0


@rpc("authority", "call_remote", "reliable")
func _receive_seats(new_seats: Dictionary) -> void:
	seats = new_seats
	local_seat = int(seats.get(multiplayer.get_unique_id(), HOST_SEAT))
	roster_changed.emit()


# --- Starting a run ---

func is_host() -> bool:
	return in_run and multiplayer.is_server()


func is_guest() -> bool:
	return in_run and not multiplayer.is_server()


func start_run(map_index: int, difficulty_index: int, endless: bool) -> void:
	if multiplayer.is_server() and seats.size() >= 2:
		_begin_run.rpc(map_index, difficulty_index, endless, seats)


@rpc("authority", "call_local", "reliable")
func _begin_run(map_index: int, difficulty_index: int, endless: bool, final_seats: Dictionary) -> void:
	seats = final_seats
	local_seat = int(seats.get(multiplayer.get_unique_id(), HOST_SEAT))
	in_run = true
	GameState.map_size = Config.MAP_SIZES[map_index]
	GameState.difficulty = Config.DIFFICULTIES[difficulty_index]
	GameState.endless_mode = endless
	GameState.sandbox_mode = false
	GameState.coop_mode = true
	GameState.is_mirror = not multiplayer.is_server()
	SceneRouter.goto(SceneRouter.GAME)


## Every seat in the run, host included.
func team_seats() -> Array[int]:
	var team: Array[int] = []
	for seat: int in seats.values():
		team.append(seat)
	team.sort()
	return team


func _peer_of_seat(seat: int) -> int:
	for peer_id: int in seats:
		if int(seats[peer_id]) == seat:
			return peer_id
	return 0


## Game calls this once its scene is built.
func attach_game(game: Node) -> void:
	_game = game
	if is_guest():
		_guest_ready.rpc_id(1)
		return
	for peer_id: int in _waiting_peers:
		_admit(peer_id)
	_waiting_peers.clear()


@rpc("any_peer", "call_remote", "reliable")
func _guest_ready() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if not is_host() or not seats.has(sender) or _ready_peers.has(sender):
		return
	if _game == null:
		if not _waiting_peers.has(sender):
			_waiting_peers.append(sender)
		return
	_admit(sender)


func _admit(peer_id: int) -> void:
	_game.add_coop_player(int(seats[peer_id]))
	_ready_peers.append(peer_id)
	_last_input_ms[peer_id] = Time.get_ticks_msec()
	_load_layer.rpc_id(peer_id, _game.layer_message())


func broadcast_layer(message: Dictionary) -> void:
	for peer_id: int in _ready_peers:
		_load_layer.rpc_id(peer_id, message)


@rpc("authority", "call_remote", "reliable")
func _load_layer(message: Dictionary) -> void:
	if _game_running():
		_game.load_guest_layer(message)


# --- Guest to host ---

func _physics_process(delta: float) -> void:
	if not in_run or not _game_running():
		return
	if is_guest():
		_send_input(delta)
	else:
		_expire_inputs()
		_send_self_states(delta)


## The game scene goes away at the end screens, while the session lives on until the Main Menu.
func _game_running() -> bool:
	return is_instance_valid(_game) and _game.is_inside_tree()


func _send_input(delta: float) -> void:
	_input_timer += delta
	if _input_timer < Settings.INPUT_INTERVAL_SEC:
		return
	_input_timer = 0.0
	var player: Player = _game.local_player()
	if player == null:
		return
	var menus_open: bool = GameState.castle_menu_open or GameState.pause_menu_open
	var move: Vector2 = Vector2.ZERO if menus_open else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var fire: bool = not menus_open and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_viewport().gui_get_hovered_control() == null
	var fire_all: bool = not menus_open and Input.is_physical_key_pressed(KEY_E)
	_submit_input.rpc_id(1, move, player.get_global_mouse_position(), fire, fire_all, GameState.selected_effect, menus_open)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_input(move: Vector2, aim: Vector2, fire: bool, fire_all: bool, spell: int, menus_open: bool) -> void:
	var player: Player = _sender_player()
	if player == null or not move.is_finite() or not aim.is_finite():
		return
	_last_input_ms[multiplayer.get_remote_sender_id()] = Time.get_ticks_msec()
	player.remote_move_direction = move.limit_length(1.0)
	player.remote_aim_position = aim
	player.remote_fire_pressed = fire
	player.remote_fire_all = fire_all
	player.progress.select_spell(spell)
	player.progress.castle_menu_open = menus_open


func _sender_player() -> Player:
	var sender: int = multiplayer.get_remote_sender_id()
	if not is_host() or not _game_running() or not seats.has(sender):
		return null
	return _game.player_of_seat(int(seats[sender]))


## Lost input must not leave a character running or firing forever.
func _expire_inputs() -> void:
	var now: int = Time.get_ticks_msec()
	for peer_id: int in _last_input_ms:
		if now - int(_last_input_ms[peer_id]) > Settings.INPUT_TIMEOUT_SEC * 1000.0:
			var player: Player = _game.player_of_seat(int(seats[peer_id]))
			if player != null:
				player.remote_move_direction = Vector2.ZERO
				player.remote_fire_pressed = false
				player.remote_fire_all = false


## Runs a shop purchase or toggle on the guest's real state. Their own copy already applied it,
## and the next self state corrects it if the host disagrees.
func request_action(method: String, args: Array = []) -> void:
	if is_guest():
		_request_action.rpc_id(1, method, args)


@rpc("any_peer", "call_remote", "reliable")
func _request_action(method: String, args: Array) -> void:
	var player: Player = _sender_player()
	if player == null:
		return
	if method.begins_with("try_buy_") or method == "try_upgrade_spell" or ALLOWED_ACTIONS.has(method):
		if player.progress.has_method(method):
			player.progress.callv(method, args)


func request_hotbar(index: int) -> void:
	if is_guest():
		_request_hotbar.rpc_id(1, index)


@rpc("any_peer", "call_remote", "reliable")
func _request_hotbar(index: int) -> void:
	var player: Player = _sender_player()
	if player != null:
		player.progress.use_slot(index, player)


# --- Host to guest ---

func _send_self_states(delta: float) -> void:
	_self_state_timer += delta
	if _self_state_timer < SELF_STATE_INTERVAL_SEC:
		return
	_self_state_timer = 0.0
	for peer_id: int in _ready_peers:
		var player: Player = _game.player_of_seat(int(seats[peer_id]))
		if player != null:
			_receive_self_state.rpc_id(peer_id, player.progress.to_net())


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_self_state(state: Dictionary) -> void:
	GameState.apply_net(state)


func send_snapshot(data: Dictionary) -> void:
	data["e"] = _events
	_events = []
	for peer_id: int in _ready_peers:
		_receive_snapshot.rpc_id(peer_id, data)


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_snapshot(data: Dictionary) -> void:
	if _game_running():
		_game.apply_snapshot(data)


func open_shop_for(seat: int, section: int) -> void:
	var peer_id: int = _peer_of_seat(seat)
	if peer_id != 0:
		_open_shop.rpc_id(peer_id, section)


@rpc("authority", "call_remote", "reliable")
func _open_shop(section: int) -> void:
	if _game_running():
		_game.open_guest_shop(section)


func announce_end(won: bool) -> void:
	if is_host():
		_run_ended.rpc(won)


@rpc("authority", "call_remote", "reliable")
func _run_ended(won: bool) -> void:
	GameState.finish_mirrored_run(won)


# --- Events shared with guests ---

func share_sound(sound_name: String, world_position: Vector2, positional: bool) -> void:
	if is_host() and not PRIVATE_SOUNDS.has(sound_name):
		_events.append(["s", sound_name, world_position, positional])


func share_text(world_position: Vector2, text: String, color: Color) -> void:
	if is_host():
		_events.append(["t", world_position, text, color])


func share_shake(intensity: float, duration: float) -> void:
	if is_host():
		_events.append(["k", intensity, duration])
