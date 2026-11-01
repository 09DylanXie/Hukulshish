extends Node
## Plays a co-op run across real processes: one host and two guests. Arguments after `--`:
## --role=host|guest2|guest3 --port=N
## Steps are kept in order by waiting on what the other players should see, not on fixed timers.

const STEP_TIMEOUT_SEC: float = 25.0

var _role: String = ""
var _port: int = 9190
## With these set, the test runs over WebRTC instead of LAN, which needs the webrtc-native plugin.
var _signal_url: String = ""
var _room_file: String = ""
## Saves what this guest sees during the boss fight. Needs a real window, not --headless.
var _shot_path: String = ""
var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
		elif arg.begins_with("--port="):
			_port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--signal="):
			_signal_url = arg.trim_prefix("--signal=")
		elif arg.begins_with("--room-file="):
			_room_file = arg.trim_prefix("--room-file=")
	if _role == "host":
		await _run_host()
	else:
		await _run_guest()
	print("%s: %d failures" % [_role, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL [%s]: %s" % [_role, message])


## Waits for `condition`, and reports a failure if it never comes true.
func _until(condition: Callable, what: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(STEP_TIMEOUT_SEC * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().physics_frame
	_check(false, "timed out waiting for: %s" % what)
	return false


func _game() -> Node:
	var scene: Node = get_tree().current_scene
	return scene if scene != null and scene.has_method("layer_message") else null


func _guest_player(seat: int) -> Player:
	return _game().player_of_seat(seat) if _game() != null else null


# --- Host ---

func _run_host() -> void:
	if _signal_url.is_empty():
		_check(Coop.host_lan(_port) == OK, "the host must open its port")
	else:
		Coop.session.room_joined.connect(func(code: String, _id: int) -> void:
			FileAccess.open(_room_file, FileAccess.WRITE).store_string(code))
		_check(Coop.session.connect_room(_signal_url, "", []) == OK, "the host must reach signaling")
	await _until(func() -> bool: return Coop.seats.size() == 3, "both guests to connect")
	Coop.start_run(0, 1, false)
	await _until(func() -> bool: return _game() != null and _game().seated_players().size() == 3, "all three players in the run")
	# Nobody is playing, so stop the goblins from ending the test early.
	for seat: int in _game().seated_players():
		_game().player_of_seat(seat)._iframes = 9999.0
	var guest: Player = _guest_player(2)
	await _until(func() -> bool: return guest.position.x > 64.0, "guest 2's input to move their character")
	_check(guest.progress != GameState, "guests must have their own inventory")

	# A purchase is a request: only the host's copy of the guest may change for real.
	guest.progress.gold = 700
	await _until(func() -> bool: return guest.progress.magnet_unlocked, "guest 2's Magnet purchase")
	_check(guest.progress.gold == 400, "the host must charge the guest, got %d" % guest.progress.gold)
	_check(GameState.gold == 0 and not GameState.magnet_unlocked, "a guest's purchase must not touch the host")

	# Fight: the guests should see the nests fall, the boss, and its escorts.
	for nest: Node in get_tree().get_nodes_in_group("nests"):
		nest.take_damage(float(nest.get("hp")) + 1.0)
	await _until(func() -> bool: return get_tree().get_nodes_in_group("bosses").size() == 1, "the boss")
	var boss: NestBoss = get_tree().get_nodes_in_group("bosses")[0]
	await _until(func() -> bool: return get_tree().get_nodes_in_group("monsters").size() >= 3, "the boss's escorts")
	guest.global_position = boss.global_position + Vector2(Config.tiles(4.0), 0.0)
	# Escorts and trees can catch the shots, so check that the guest fired, then that damage shows.
	var mana_before: float = guest.progress.mana
	await _until(func() -> bool: return guest.progress.mana < mana_before, "guest 2's E key to shoot")
	print("VOLLEY mana %.1f boss %.0f/%.0f monsters %d" % [guest.progress.mana, boss.hp, boss.max_hp, get_tree().get_nodes_in_group("monsters").size()])
	guest.progress.deal_damage(boss, 5.0)
	_report_snapshot_size()

	# The kill belongs to whoever lands it, and the portal waits for the whole team.
	var gold_before: int = guest.progress.gold
	guest.progress.deal_damage(boss, boss.hp * 2.0)
	await _until(func() -> bool: return _find_portal() != null, "the portal")
	_check(guest.progress.gold >= gold_before + 1000, "the boss's gold must go to the killer")
	_check(GameState.gold == 0, "the host must get nothing for a guest's kill")
	await get_tree().create_timer(Config.PORTAL_ARM_SEC + 0.2).timeout

	var portal: Portal = _find_portal()
	_player_enters(_game().local_player(), portal)
	await _until(func() -> bool: return _game().local_player().in_void, "the host to reach the void")
	_check(GameState.layer_index == 0, "one player alone must not descend")
	_player_enters(_guest_player(2), portal)
	await _until(func() -> bool: return _guest_player(2).in_void, "guest 2 to reach the void")
	await get_tree().create_timer(0.4).timeout
	_check(GameState.layer_index == 0, "two of three must not descend")
	_player_enters(_guest_player(3), portal)
	await _until(func() -> bool: return GameState.layer_index == 1, "the team to descend together")
	_check(not _guest_player(2).in_void, "descending must empty the void")
	await get_tree().create_timer(0.6).timeout
	print("WORLD %d" % _world_hash())

	# Guest 3 drops out, and the run carries on without them.
	await _until(func() -> bool: return Coop.seats.size() == 2, "guest 3 to disconnect")
	await _until(func() -> bool: return _guest_player(3) == null, "guest 3's character to leave")
	_check(not GameState.run_over, "one player leaving must not end the run")

	await get_tree().create_timer(0.5).timeout
	var team: Array[Player] = [_game().local_player(), _guest_player(2)]
	for player: Player in team:
		player._iframes = 0.0
		player.take_damage(9999.0)
	await _until(func() -> bool: return GameState.run_over, "a team wipe to end the run")
	await get_tree().create_timer(1.0).timeout


func _player_enters(player: Player, portal: Portal) -> void:
	player.global_position = portal.global_position
	portal.entered.emit(player)


func _find_portal() -> Portal:
	for node: Node in _game().entity_nodes():
		if node is Portal:
			return node
	return null


func _report_snapshot_size() -> void:
	for node: Node in _game().get_children():
		if node is CoopHostSync:
			print("SNAPSHOT %d bytes" % var_to_bytes((node as CoopHostSync).build()).size())


func _world_hash() -> int:
	var world: World = get_tree().get_first_node_in_group("world")
	return hash(world.wall_rects)


# --- Guests ---

func _run_guest() -> void:
	# The host needs a moment to open its port.
	await get_tree().create_timer(0.8).timeout
	if _signal_url.is_empty():
		_check(Coop.join_lan("127.0.0.1", _port) == OK, "the guest must connect")
	else:
		await _until(func() -> bool: return FileAccess.file_exists(_room_file), "the room code")
		_check(Coop.session.connect_room(_signal_url, FileAccess.get_file_as_string(_room_file), []) == OK, "the guest must reach signaling")
	await _until(func() -> bool: return _game() != null and GameState.coop_mode and get_tree().get_first_node_in_group("world") != null, "the shared run to load")
	# Seats go to whoever connects first, so the script follows the seat.
	_role = "guest%d" % Coop.local_seat
	var game: Node = _game()
	var me: Player = game.local_player()
	_check(me.net_view and not me.has_node("SpellCaster"), "guests must not simulate spells")
	await _until(func() -> bool: return game.seated_players().size() == 3, "all three players to appear")
	var first_world: int = _world_hash()
	_check(first_world != 0, "the guest must have a map")

	if _role == "guest2":
		var start: Vector2 = me.global_position
		Input.action_press("move_right")
		await _until(func() -> bool: return me.global_position.x > start.x + 90.0, "prediction to move this player")
		Input.action_release("move_right")

		await _until(func() -> bool: return GameState.gold == 700, "the host's gold grant to reach this guest")
		game._castle_menu._purchase("try_buy_magnet")
		await _until(func() -> bool: return GameState.gold == 400 and GameState.magnet_unlocked, "the purchase to be confirmed")
		var fire_all := InputEventKey.new()
		fire_all.physical_keycode = KEY_E
		fire_all.pressed = true
		Input.parse_input_event(fire_all)

	await _until(func() -> bool: return get_tree().get_nodes_in_group("bosses").size() == 1, "the boss to appear here")
	_check(get_tree().get_nodes_in_group("nests").is_empty(), "the nests must vanish here")
	var boss: NestBoss = get_tree().get_nodes_in_group("bosses")[0]
	_check(boss.look_stats != null and boss.look_stats.name == "Goblin", "the boss must look like a goblin")
	await _until(func() -> bool: return get_tree().get_nodes_in_group("monsters").size() >= 3, "monsters to appear here")
	_check(boss.process_mode == Node.PROCESS_MODE_DISABLED, "a guest's boss must only be a drawing")
	if not _shot_path.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_shot_path, _role])
	await _until(func() -> bool: return not is_instance_valid(boss) or boss.hp < boss.max_hp, "the boss's damage to show here")

	await _until(func() -> bool: return GameState.layer_stage == RunState.LayerStage.PORTAL, "the portal stage")
	await _until(func() -> bool: return GameState.layer_index == 1 and GameState.current_layer().name == "Underworld", "the team to descend")
	await get_tree().create_timer(0.4).timeout
	print("WORLD %d" % _world_hash())
	_check(get_tree().get_nodes_in_group("nests").size() == Config.nests_on_layer(1), "the new nests must appear here")

	if _role == "guest3":
		await get_tree().create_timer(0.5).timeout
		Coop.close()
		await get_tree().create_timer(0.3).timeout
		return

	await _until(func() -> bool: return GameState.run_over, "the host's team wipe to reach this guest")
	await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == SceneRouter.GAME_OVER, "the Game Over screen")
