extends Control
## The co-op lobby. Hosts and joins a team over LAN (desktop) or WebRTC (browser), then starts the run.

const Settings: GDScript = preload("res://scripts/network/webrtc_config.gd")
const MIN_PLAYERS: int = 2

var _url: LineEdit
var _code: LineEdit
var _ice: LineEdit
var _address: LineEdit
var _status: Label
var _roster: Label
var _connect_box: VBoxContainer
var _host_box: VBoxContainer
var _map_choice: OptionButton
var _difficulty_choice: OptionButton
var _endless_toggle: CheckButton
var _start_button: Button
var _uses_webrtc: bool = false


func _ready() -> void:
	name = "WebRTCLobby"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box: VBoxContainer = UIKit.make_centered_menu(self, "Co-op", "Two or three players, one host")
	box.custom_minimum_size.x = 780

	_connect_box = VBoxContainer.new()
	_connect_box.add_theme_constant_override("separation", 8)
	box.add_child(_connect_box)
	if not OS.has_feature("web"):
		_build_lan_controls()
	_build_webrtc_controls()

	_status = UIKit.make_label("Host a game, or join a friend's.", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_roster = UIKit.make_label("", 20, Color(0.75, 0.95, 0.8))
	box.add_child(_roster)

	_build_host_controls(box)
	box.add_child(UIKit.make_button("Leave", _leave, 20))
	box.add_child(UIKit.make_button("Back", _back, 20))

	Coop.roster_changed.connect(_on_roster_changed)
	Coop.failed.connect(_on_failed)
	Coop.session.room_joined.connect(_on_joined)
	multiplayer.connected_to_server.connect(_on_connected_to_host)


func _build_lan_controls() -> void:
	_connect_box.add_child(UIKit.make_label("Same network", 22, Color(0.45, 0.85, 1.0)))
	_address = _field(_connect_box, "Host's address (127.0.0.1 for a second copy on this computer)", "127.0.0.1")
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_connect_box.add_child(buttons)
	buttons.add_child(UIKit.make_button("Host LAN game", _host_lan))
	buttons.add_child(UIKit.make_button("Join LAN game", _join_lan))


func _build_webrtc_controls() -> void:
	_connect_box.add_child(UIKit.make_label("Online room", 22, Color(0.45, 0.85, 1.0)))
	_url = _field(_connect_box, "Signaling service URL", "ws://127.0.0.1:9080")
	_code = _field(_connect_box, "Room code (leave empty when hosting)", "")
	_ice = _field(_connect_box, "ICE servers JSON (local tests can use [])", "[]")
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_connect_box.add_child(buttons)
	buttons.add_child(UIKit.make_button("Host room", _connect_room.bind(true)))
	buttons.add_child(UIKit.make_button("Join room", _connect_room.bind(false)))


func _build_host_controls(box: VBoxContainer) -> void:
	_host_box = VBoxContainer.new()
	_host_box.add_theme_constant_override("separation", 8)
	_host_box.hide()
	box.add_child(_host_box)
	_map_choice = OptionButton.new()
	for map: MapSizeData in Config.MAP_SIZES:
		_map_choice.add_item("Map: %s" % map.name)
	_map_choice.select(1)
	_host_box.add_child(_map_choice)
	_difficulty_choice = OptionButton.new()
	for difficulty: DifficultyData in Config.DIFFICULTIES:
		_difficulty_choice.add_item("Difficulty: %s" % difficulty.name)
	_difficulty_choice.select(1)
	_host_box.add_child(_difficulty_choice)
	_endless_toggle = CheckButton.new()
	_endless_toggle.text = "Endless Mode (the game continues after the final boss)"
	_host_box.add_child(_endless_toggle)
	_start_button = UIKit.make_button("Start game", _start)
	_start_button.disabled = true
	_host_box.add_child(_start_button)


func _field(box: VBoxContainer, caption: String, initial: String) -> LineEdit:
	box.add_child(UIKit.make_label(caption, 18))
	var field: LineEdit = LineEdit.new()
	field.text = initial
	field.custom_minimum_size.y = 42
	field.add_theme_font_size_override("font_size", 20)
	box.add_child(field)
	return field


func _host_lan() -> void:
	var error: Error = Coop.host_lan()
	if error != OK:
		_status.text = "Cannot host: %s. Is another copy already hosting?" % error_string(error)
		return
	_uses_webrtc = false
	_set_connected(true)
	_status.text = "Hosting on port %d. Friends on your network join with this computer's address." % Coop.LAN_PORT


func _join_lan() -> void:
	var error: Error = Coop.join_lan(_address.text.strip_edges())
	if error != OK:
		_status.text = "Cannot connect: %s" % error_string(error)
		return
	_uses_webrtc = false
	_set_connected(true)
	_status.text = "Connecting..."


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
	Coop.close()
	var error: Error = Coop.session.connect_room(_url.text.strip_edges(), "" if hosting else _code.text, servers)
	if error != OK:
		_status.text = "Cannot connect: %s. HTTPS pages require a wss:// service." % error_string(error)
		return
	_uses_webrtc = true
	_set_connected(true)
	get_viewport().gui_release_focus()
	_status.text = "Connecting..."


func _on_joined(code: String, peer_id: int) -> void:
	_code.text = code
	var hosting: bool = peer_id == Settings.HOST_ID
	_host_box.visible = hosting
	_status.text = "Room %s. Share this code with your team." % code if hosting else "Room %s. Waiting for the host to start." % code


func _on_connected_to_host() -> void:
	_status.text = "Connected. Waiting for the host to start."


func _on_roster_changed() -> void:
	var count: int = Coop.seats.size()
	_roster.text = "Players: %d / %d" % [count, Settings.MAX_PLAYERS] if count > 0 else ""
	var hosting: bool = multiplayer.is_server() and count > 0
	_host_box.visible = hosting
	if hosting:
		_start_button.disabled = count < MIN_PLAYERS


func _on_failed(reason: String) -> void:
	_set_connected(false)
	_roster.text = ""
	_host_box.hide()
	_status.text = reason


func _start() -> void:
	Coop.start_run(_map_choice.selected, _difficulty_choice.selected, _endless_toggle.button_pressed)


func _leave() -> void:
	Coop.close()
	_set_connected(false)
	_roster.text = ""
	_host_box.hide()
	_status.text = "Left the game."


func _back() -> void:
	Coop.close()
	queue_free()


func _set_connected(connected: bool) -> void:
	_connect_box.visible = not connected
