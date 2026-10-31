extends Node
## Real Player/RunState integration checks, driven with deterministic timer steps.

const PlayerScene: PackedScene = preload("res://scenes/player/Player.tscn")
const MonsterScene: PackedScene = preload("res://scenes/monsters/Monster.tscn")
const BossScene: PackedScene = preload("res://scenes/bosses/NestBoss.tscn")
const MegaScene: PackedScene = preload("res://scenes/bosses/MegaBoss.tscn")
const ControllerScript: GDScript = preload("res://scripts/multiplayer/coop_revival_controller.gd")

var _failures: int = 0
var _states: Array[RunState] = []
var _players: Array[Player] = []
var _controller: CoopRevivalController
var _defeats: int = 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	GameState.set_process(false)
	_check_scaling()
	_make_team()
	_check_purchases()
	_check_revival()
	_check_team_wipe()
	await _check_kill_credit_and_pickups()
	await _check_shop()
	await _check_game_registration()
	if _failures == 0:
		print("PASS: co-op HP, permanent revival purchase, 3+5 second timing, interruption, team wipe, kill gold and pickups")
	get_tree().quit(0 if _failures == 0 else 1)


func _check_scaling() -> void:
	GameState.coop_mode = false
	GameState.start_run()
	GameState.set_process(false)
	_check(GameState.player_max_hp() == 7, "Single-player starting HP must remain 7")
	_check(GameState.scaled_monster_hp(3) == 3.0, "Single-player monster HP changed")
	_check(GameState.scaled_boss_hp() == 240.0, "Single-player boss HP changed")
	GameState.coop_mode = true
	_check(GameState.player_max_hp() == 7, "Co-op must not double player HP")
	_check(GameState.scaled_monster_hp(3) == 6.0, "Co-op Goblin must have 6 base HP")
	_check(GameState.scaled_nest_hp() == 70.0, "Co-op must not double nest HP")
	_check(GameState.scaled_boss_hp() == 1200.0, "Boss multiplier must be 5 total, not 10")
	_check(GameState.scaled_mega_boss_hp() == 10000.0, "Mega Boss must have 10000 base HP")
	GameState.run_time = Config.TIME_SCALE_START_SEC
	_check(GameState.scaled_monster_hp(3) == 11.0, "Double base HP before the Medium +5 time step")
	GameState.run_time = 0.0
	var mega: MegaBoss = MegaScene.instantiate()
	mega.setup(Color.WHITE, 1.0)
	_check(mega.max_hp == 10000.0 and mega.max_shield == 100.0, "Mega HP scaling must not multiply its shield")
	mega.free()
	GameState.difficulty = Config.DIFFICULTIES[0]
	_check(GameState.scaled_monster_hp(3) == 3.0, "Easy difficulty must apply after doubling base HP")
	GameState.difficulty = Config.DIFFICULTIES[1]


func _make_team() -> void:
	_controller = ControllerScript.new()
	_controller.castle_position = Vector2(320.0, 320.0)
	get_tree().root.add_child(_controller)
	_controller.set_physics_process(false)
	_controller.team_defeated.connect(func() -> void: _defeats += 1)
	for index: int in 3:
		var state: RunState = RunState.new()
		state.coop_mode = true
		get_tree().root.add_child(state)
		state.start_run()
		state.set_process(false)
		_states.append(state)
		var player: Player = PlayerScene.instantiate()
		player.progress = state
		player.accepts_local_input = false
		player.position = Vector2(float(index) * 100.0, 0.0)
		get_tree().root.add_child(player)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		_players.append(player)
		_check(_controller.register_player(index + 1, player), "Could not register co-op player")
	_check(_controller.start(), "A complete three-player team should start")


func _check_purchases() -> void:
	_states[0].gold = 998
	_check(not _states[0].try_buy_revival_unlock(), "998 gold must not buy revival")
	_check(_states[0].gold == 998 and not _states[0].revival_unlocked, "Failed purchase must not mutate state")
	_states[0].gold = 999
	_check(_states[0].try_buy_revival_unlock(), "999 gold should unlock revival")
	_check(_states[0].gold == 0 and _states[0].revival_unlocked, "Revival must cost exactly 999")
	_states[0].gold = 999
	_check(not _states[0].try_buy_revival_unlock() and _states[0].gold == 999, "Permanent unlock must not charge twice")
	_check(not _states[1].revival_unlocked, "Revival ownership must not be shared")


func _check_revival() -> void:
	_players[1].take_damage(100.0)
	_check(_players[1].is_dead() and not _states[1].run_over, "One death must not end co-op")
	_players[2].global_position = _players[1].global_position
	_controller.advance(4.0)
	_check(not _players[1].respawn_pending, "A player without the unlock must not revive")
	_players[2].global_position = Vector2(800.0, 0.0)
	_players[0].global_position = _players[1].global_position
	_controller.advance(2.9)
	_check(not _players[1].respawn_pending, "Revival must require the full three seconds")
	_players[0].global_position += Vector2(100.0, 0.0)
	_controller.advance(0.2)
	_check(_controller.interaction_seconds(1) == 0.0, "Leaving the body must reset the interaction")
	_players[0].global_position = _players[1].global_position
	_states[2].gold = 999
	_states[2].try_buy_revival_unlock()
	_players[2].global_position = _players[1].global_position
	_controller.advance(1.5)
	_check(_controller.interaction_seconds(3) == 0.0, "Two helpers must not stack revive speed")
	_controller.advance(1.5)
	_check(_players[1].respawn_pending and _players[1].hp == 0, "Successful interaction should queue a return, not heal immediately")
	_check(_controller.respawn_seconds(2) == 5.0, "A new return must receive its full five seconds")
	_controller.advance(4.99)
	_check(_players[1].is_dead(), "Player returned before five seconds")
	_controller.advance(0.02)
	_check(not _players[1].is_dead() and _players[1].hp == 5, "Revival must restore exactly 5 HP")
	_check(_players[1].global_position == _controller.castle_position, "Player must respawn at the castle")
	_check(_states[0].revival_unlocked and _states[0].gold == 999, "Using revival must not consume or charge the unlock")
	_players[1].take_damage(100.0)
	_players[0].global_position = _players[1].global_position
	_controller.advance(3.0)
	_check(_players[1].respawn_pending, "The same unlock must allow another revival")


func _check_team_wipe() -> void:
	_players[0].take_damage(100.0)
	_check(not _controller.ended, "Two downed players must not end the run")
	_players[2].take_damage(100.0)
	_check(_controller.ended and _defeats == 1, "All three downed must end the run exactly once")
	_controller.advance(100.0)
	_check(_players[1].hp == 0 and not _players[1].respawn_pending, "Team defeat must cancel pending respawns")


func _check_kill_credit_and_pickups() -> void:
	var first: RunState = RunState.new()
	var killer: RunState = RunState.new()
	get_tree().root.add_child(first)
	get_tree().root.add_child(killer)
	first.start_run()
	killer.start_run()
	first.set_process(false)
	killer.set_process(false)
	first.coop_mode = true
	killer.coop_mode = true
	var monster: Monster = MonsterScene.instantiate()
	monster.setup(Config.MONSTERS[0], 1.0)
	get_tree().root.add_child(monster)
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	monster.died.connect(func(gold: int, _pos: Vector2, _demon: bool, _enhancer: bool) -> void:
		GameState.award_kill_gold(gold, monster.killing_player))
	first.deal_damage(monster, 1.0)
	killer.deal_damage(monster, 100.0)
	_check(monster.killing_player == killer, "Killing blow must replace earlier damage attribution")
	_check(first.gold == 0 and killer.gold == Config.MONSTERS[0].gold, "Only the killer receives the reward")
	var previous: int = killer.gold
	killer.deal_damage(monster, 100.0)
	_check(killer.gold == previous, "A dead enemy must not award gold twice")
	var boss: NestBoss = BossScene.instantiate()
	boss.setup(Color.WHITE, 1.0)
	get_tree().root.add_child(boss)
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	boss.died.connect(func(gold: int, _pos: Vector2) -> void: GameState.award_kill_gold(gold, boss.killing_player))
	killer.deal_damage(boss, 100000.0)
	_check(killer.gold == previous + Config.BOSS_GOLD, "Boss kill reward must go to its killer")
	var collector: Player = PlayerScene.instantiate()
	collector.progress = first
	collector.accepts_local_input = false
	get_tree().root.add_child(collector)
	collector.process_mode = Node.PROCESS_MODE_DISABLED
	var other: Player = PlayerScene.instantiate()
	other.progress = killer
	other.accepts_local_input = false
	get_tree().root.add_child(other)
	other.process_mode = Node.PROCESS_MODE_DISABLED
	var pickup: ModPickup = load("res://scenes/spells/ModPickup.tscn").instantiate()
	get_tree().root.add_child(pickup)
	pickup.call("_on_body_entered", collector)
	pickup.call("_on_body_entered", other)
	_check(first.mod_parts == 1 and killer.mod_parts == 0, "Only the first collector receives a pickup")
	collector.take_damage(100.0)
	var second_pickup: ModPickup = load("res://scenes/spells/ModPickup.tscn").instantiate()
	second_pickup.kind = ModPickup.Kind.ENHANCER
	get_tree().root.add_child(second_pickup)
	second_pickup.call("_on_body_entered", collector)
	second_pickup.call("_on_body_entered", other)
	_check(first.enhancers == 0 and killer.enhancers == 1, "Downed bodies must not collect loot")
	await _check_attack_ownership(killer)
	collector.queue_free()
	other.queue_free()
	# Ordinary healing cannot revive a body or bypass the unlock/timers.
	_check(not _players[1].heal_amount(5), "Healing potions must not revive a downed player")
	_check(not _players[1].revive_at_castle(Vector2.ZERO), "A late revive callback must not revive a player after team defeat")
	await get_tree().process_frame
	first.queue_free()
	killer.queue_free()


func _check_attack_ownership(killer: RunState) -> void:
	var victim: Monster = MonsterScene.instantiate()
	victim.setup(Config.MONSTERS[0], 1.0)
	victim.hp = 1.0
	get_tree().root.add_child(victim)
	victim.process_mode = Node.PROCESS_MODE_DISABLED
	var previous: int = killer.gold
	victim.died.connect(func(gold: int, _pos: Vector2, _demon: bool, _enhancer: bool) -> void:
		GameState.award_kill_gold(gold, victim.killing_player))
	var fire: FireZone = FireZone.new()
	fire.source_state = killer
	fire.dps = 1.0 / Config.BOMB_TICK_SEC
	get_tree().root.add_child(fire)
	_check(victim.killing_player == killer and killer.gold == previous + Config.MONSTERS[0].gold, "Fire damage must retain the caster's kill credit")
	fire.queue_free()
	var container: Node2D = Node2D.new()
	container.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(container)
	var shot: Projectile = load("res://scenes/spells/Projectile.tscn").instantiate()
	shot.source_state = killer
	shot.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(shot)
	var target: Node2D = Node2D.new()
	get_tree().root.add_child(target)
	shot.call("_spawn_split_shots", container, target)
	shot.call("_spawn_sniper_shot", container, target)
	shot.call("_spawn_bomb_zone", container)
	await get_tree().process_frame
	_check(container.get_child_count() == 4, "Expected two split shots, a sniper shot, and a fire zone")
	for child: Node in container.get_children():
		_check(child.get("source_state") == killer, "An augmentation lost its original owner's identity")
	container.queue_free()
	shot.queue_free()
	target.queue_free()


func _check_shop() -> void:
	GameState.coop_mode = true
	GameState.start_run()
	GameState.set_process(false)
	GameState.gold = 999
	var shop: CastleMenu = load("res://scenes/ui/CastleMenu.tscn").instantiate()
	get_tree().root.add_child(shop)
	shop.open()
	_check(not get_tree().paused, "A co-op shop must not pause the entire team")
	var found: bool = false
	for button: Node in shop.find_children("*", "Button", true, false):
		if (button as Button).text.begins_with("Unlock Revival"):
			found = true
			_check(not (button as Button).disabled, "Revival must be affordable at 999 gold")
			(button as Button).pressed.emit()
			break
	_check(found and GameState.revival_unlocked and GameState.gold == 0, "Gold Shop button must buy the permanent unlock")
	shop.close()
	shop.queue_free()
	await get_tree().process_frame
	GameState.coop_mode = false
	GameState.start_run()
	_check(not GameState.revival_unlocked, "A new run must reset the run-specific unlock")


func _check_game_registration() -> void:
	GameState.coop_mode = true
	var game: Node2D = load("res://scenes/main/Game.tscn").instantiate()
	get_tree().root.add_child(game)
	GameState.run_over = true
	_check(game.call("add_coop_player", 2) == null, "An ended run must reject guest registration")
	GameState.run_over = false
	var guest2: Player = game.call("add_coop_player", 2)
	var guest3: Player = game.call("add_coop_player", 3)
	_check(guest2 != null and guest3 != null, "Game must accept the two co-op guests")
	_check(guest2.progress != guest3.progress and guest2.progress != GameState, "Game must assign independent guest inventories")
	_check(guest2.hp == 7 and guest3.hp == 7, "Co-op player HP changed during scene construction")
	var controller: CoopRevivalController = game.get("_revivals")
	_check(controller.running, "Game must start its revive controller after all three registrations")
	_check(game.call("add_coop_player", 2) == null, "Duplicate guest registration must be rejected")
	game.queue_free()
	await get_tree().process_frame
	GameState.coop_mode = false
	GameState.start_run()
