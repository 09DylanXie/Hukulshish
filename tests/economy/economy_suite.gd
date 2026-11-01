extends Node
## Checks upgrades, drops, shops, gold mines, spell selection and homing.

const GAME_SCENE: String = "res://scenes/main/Game.tscn"
## Away from the player, who would otherwise collect the drops before they can be counted.
const DROP_POSITION: Vector2 = Vector2(300.0, 300.0)

var _failures: int = 0
var _game: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_upgrades()
	await _start_game()
	await _check_shop()
	await _check_drops()
	_check_mine_estimate()
	await _check_spell_selection()
	await _check_doppelganger()
	_check_spawn_rates()
	await _check_abyss_drops()
	_check_homing_cone()
	print("economy test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _check_upgrades() -> void:
	GameState.start_run()
	_check(Config.spell_damage(9) == 23 and Config.spell_damage(10) == 28, "Level 10 must keep the +5 step")
	_check(Config.spell_damage(17) == 63, "Level 17 must deal 63 damage")
	var total: int = 0
	for level in range(1, Config.SPELL_MAX_LEVEL):
		total += Config.upgrade_cost(level)
	_check(Config.upgrade_cost(1) == 25 and total == 37400, "The spell must cost 37,400 gold to max")

	_check(Config.mod_cost(0) == 1 and Config.mod_cost(19) == 20, "A mod level costs its own number")
	GameState.sandbox_mode = true
	for id: String in ["damage", "mana_regen", "mana_pool", "range"]:
		while GameState.try_buy_mod(id):
			pass
	GameState.sandbox_mode = false
	_check(is_equal_approx(GameState.mod_multiplier("damage"), 3.0), "Damage must reach 3× at level 20")
	_check(is_equal_approx(GameState.mana_regen(), 11.0), "Mana regen must reach 11/s at level 20")
	_check(GameState.max_mana() == 45, "Mana pool must reach 45 at level 20")
	_check(Config.max_mana_for_level(5) == 15 and Config.max_mana_for_level(12) == 29, "Early mana steps must not change")
	_check(is_equal_approx(GameState.mod_multiplier("range"), 5.0), "Range must stop at 5×")

	var expected_luck: Array[int] = [1, 1, 2, 3]
	for level in expected_luck.size():
		GameState.personal_levels["luck"] = level
		_check(GameState.luck_multiplier() == expected_luck[level], "Wrong Luck multiplier at level %d" % level)
	GameState.start_run()


func _start_game() -> void:
	_game = load(GAME_SCENE).instantiate()
	get_tree().root.add_child(_game)
	await get_tree().physics_frame


func _stalls() -> Array[ShopStall]:
	var stalls: Array[ShopStall] = []
	for child: Node in _game._entities.get_children():
		if child is ShopStall:
			stalls.append(child)
	return stalls


func _check_shop() -> void:
	var stalls: Array[ShopStall] = _stalls()
	_check(stalls.size() == 5, "The shop must have 5 stalls")
	var mines: Array[Node] = get_tree().get_nodes_in_group("gold_mines")
	_check(mines.size() == 5, "There must be 5 gold mines")
	for stall: ShopStall in stalls:
		_check(stall.position.x < 0.0, "Stalls must stand left of the castle")
	for mine: Node in mines:
		_check((mine as Node2D).position.x > 0.0, "Mines must stand right of the castle")

	var player: Player = _game._player
	var menu: CastleMenu = _game._castle_menu
	player.hp = 1
	var gold_stall: ShopStall = stalls[ShopStall.Section.GOLD]
	player.global_position = gold_stall.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.hp == 6, "Stalls must heal to 75% of max HP, rounded up")
	_check(menu._root.visible and get_tree().paused, "Walking into a stall must open the menu and pause")
	_check(menu._sections[ShopStall.Section.GOLD].visible, "The Gold stall must show the Gold section")
	_check(not menu._sections[ShopStall.Section.MODS].visible, "A stall must show only its own section")
	menu.close()
	await get_tree().physics_frame
	player.hp = 7
	player.heal_at_shop()
	_check(player.hp == 7, "Shops must never lower HP")
	player.global_position = Vector2.ZERO
	await get_tree().physics_frame


func _make_monster(stats: MonsterStats) -> Monster:
	var monster: Monster = Monster.new()
	monster.stats = stats
	return monster


func _monster_stats(monster_name: String) -> MonsterStats:
	for stats: MonsterStats in Config.MONSTERS:
		if stats.name == monster_name:
			return stats
	return null


func _check_drops() -> void:
	var goblin: MonsterStats = _monster_stats("Goblin")
	var ogre: MonsterStats = _monster_stats("Ogre")
	var undead: MonsterStats = _monster_stats("Undead")
	var demon: MonsterStats = _monster_stats("Demon")
	_check(goblin.enhancer_chance == 0.25 and goblin.scroll_chance == 0.0, "Goblins drop only Enhancers")
	_check(ogre.enhancer_chance == 0.25 and is_equal_approx(ogre.scroll_chance, 0.25), "Ogres drop both")
	_check(is_equal_approx(undead.enhancer_chance, 0.3) and is_equal_approx(undead.scroll_chance, 0.3), "Undead drop both at ×1.2")
	_check(demon.guaranteed_drop, "Demons must guarantee a drop")
	await _check_demon_drops(demon)
	_check_move_speed()
	await _check_luck_drops(ogre)


func _pickups_on_map() -> Array[ModPickup]:
	var found: Array[ModPickup] = []
	for child: Node in _game._entities.get_children():
		if child is ModPickup and (child as ModPickup).kind != ModPickup.Kind.UNIQUE_SPELL:
			found.append(child)
	return found


func _clear_pickups() -> void:
	for pickup: ModPickup in _pickups_on_map():
		pickup.free()


func _check_demon_drops(demon: MonsterStats) -> void:
	var monster: Monster = _make_monster(demon)
	GameState.personal_levels["luck"] = 3
	var saw_enhancer: bool = false
	var saw_scroll: bool = false
	for i in 40:
		_game._on_monster_died(0, DROP_POSITION, monster)
		await get_tree().process_frame
		var pickups: Array[ModPickup] = _pickups_on_map()
		_check(pickups.size() >= 1 and pickups.size() <= 3, "Demons drop 1-3 items, and Luck can't raise that")
		var kind: ModPickup.Kind = pickups[0].kind
		for pickup: ModPickup in pickups:
			_check(pickup.kind == kind, "A Demon drop must be all one type")
		_check(kind != ModPickup.Kind.AUG_SCROLL, "Demons no longer drop Augmentation Scrolls")
		saw_enhancer = saw_enhancer or kind == ModPickup.Kind.ENHANCER
		saw_scroll = saw_scroll or kind == ModPickup.Kind.MOD_PART
		_clear_pickups()
	_check(saw_enhancer and saw_scroll, "Demons must drop both types over time")
	GameState.personal_levels["luck"] = 0
	monster.free()


func _check_move_speed() -> void:
	var expected: Array[float] = [3.0, 3.3, 3.6, 3.9]
	for level in expected.size():
		GameState.personal_levels["move_speed"] = level
		_check(is_equal_approx(GameState.player_speed_tiles(), expected[level]), "Movement Speed %d must be %s tiles/sec" % [level, expected[level]])
	GameState.personal_levels["move_speed"] = 0


func _check_luck_drops(ogre: MonsterStats) -> void:
	var certain := MonsterStats.new()
	certain.enhancer_chance = 1.0
	certain.scroll_chance = 0.0
	var monster: Monster = _make_monster(certain)
	var expected: Array[int] = [1, 1, 2, 3]
	for level in expected.size():
		GameState.personal_levels["luck"] = level
		_game._on_monster_died(0, DROP_POSITION, monster)
		await get_tree().process_frame
		_check(_pickups_on_map().size() == expected[level], "Luck %d must give ×%d drops" % [level, expected[level]])
		_clear_pickups()
	GameState.personal_levels["luck"] = 0
	monster.free()
	_check(ogre.enhancer_chance < 1.0, "Luck tests must not change real drop chances")


func _check_mine_estimate() -> void:
	var mines: Array[Node] = get_tree().get_nodes_in_group("gold_mines")
	for mine: Node in mines:
		mine._stored = 100.0
	_game._clear_layer()
	GameState.layer_index = 1
	_game._build_layer()
	_check(GameState.mines_left_behind, "Descending must leave the mines filling")
	_check(GameState.mine_gold_estimate == 500.0, "The estimate must start from what the mines held")
	GameState._process(10.0)
	_check(is_equal_approx(GameState.mine_gold_estimate, 500.0 + 7.5 * 5.0 * 10.0), "The estimate must fill at all 5 mines' rate")
	GameState._process(10000.0)
	_check(is_equal_approx(GameState.mine_gold_estimate, 333.0 * 5.0), "The estimate must stop at the mines' cap")
	var before: int = GameState.gold
	GameState.collect_all_gold_mines()
	_check(GameState.gold - before == 1665 and GameState.mine_gold_estimate < 1.0, "The collector must work from below")
	_check(Config.GOLD_SHOP_AUTO_COLLECTOR_COST == 1000 and Config.AUTO_COLLECTOR_INTERVAL_SEC == 15.0, "Collector price and timer")


func _check_spell_selection() -> void:
	for nest: Node in get_tree().get_nodes_in_group("nests"):
		nest.free()
	var caster: Node = _game._player.get_node("SpellCaster")
	_check(not GameState.select_spell(SpellData.Effect.SLOW), "A spell the player doesn't have can't be selected")
	_check(GameState.selected_effect == SpellData.Effect.NONE, "The base spell starts selected")
	GameState.acquire_unique_spell(Config.LAYERS[0].unique_spell)
	_check(GameState.select_spell(SpellData.Effect.SLOW), "Water must be selectable once owned")
	GameState.mana = 10.0
	var spell: Dictionary = GameState.selected_spell()
	_check(caster._fire_one(spell, Vector2.RIGHT), "The selected spell must fire")
	_check(is_equal_approx(GameState.mana, 9.0), "Only that spell's mana must be spent")
	var fired: Array[Projectile] = _projectiles()
	_check(fired.size() == 1 and fired[0].effect == SpellData.Effect.SLOW, "Only the selected spell must fire")
	for shot: Projectile in fired:
		shot.free()
	_check(Config.BASE_SPELL.color == Color.WHITE, "The base spell must be white")
	GameState.select_spell(SpellData.Effect.NONE)
	GameState.unique_spells.clear()
	await get_tree().physics_frame


func _projectiles() -> Array[Projectile]:
	var found: Array[Projectile] = []
	for child: Node in _game._entities.get_children():
		if child is Projectile:
			found.append(child)
	return found


func _check_doppelganger() -> void:
	GameState.gold = 5000
	_check(GameState.try_buy_doppelganger() and GameState.doppelganger_items == 1, "Buying must give a hotbar item")
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("doppelgangers").is_empty(), "Buying must not summon it")
	_check(GameState.use_slot(3, _game._player), "Slot 4 must summon it")
	_check(GameState.doppelganger_items == 0, "Summoning must use the item")
	await get_tree().process_frame
	var twins: Array[Node] = get_tree().get_nodes_in_group("doppelgangers")
	_check(twins.size() == 1, "The twin must appear")
	_check(not GameState.use_slot(3, _game._player), "Only one twin at a time")
	var twin: Doppelganger = twins[0]
	await get_tree().create_timer(0.6).timeout
	_check(_projectiles().is_empty(), "The twin must not shoot on its own")
	var point: Vector2 = twin.global_position + Vector2(0.0, Config.tiles(5.0))
	twin.mirror_shot(SpellData.Effect.NONE, false, point)
	var shots: Array[Projectile] = _projectiles()
	_check(shots.size() == 1 and shots[0].direction.dot(Vector2.DOWN) > 0.99, "The twin must shoot at the player's aim point")
	for shot: Projectile in shots:
		shot.free()
	twin.free()
	GameState.on_doppelganger_died()


func _check_spawn_rates() -> void:
	for layer in 4:
		GameState.layer_index = layer
		_check(is_equal_approx(GameState.spawn_rate_mult(), 1.0 + 0.5 * layer), "Layer %d's spawn rate is wrong" % layer)
	GameState.layer_index = 0


func _check_abyss_drops() -> void:
	var certain := MonsterStats.new()
	certain.enhancer_chance = 1.0
	var monster: Monster = _make_monster(certain)
	GameState.layer_index = 4
	var gold_before: int = GameState.gold
	_game._on_monster_died(5, DROP_POSITION, monster)
	await get_tree().process_frame
	_check(_pickups_on_map().is_empty() and GameState.gold == gold_before, "The Abyss's monsters must drop nothing")
	GameState.endless_mode = true
	_game._on_monster_died(0, DROP_POSITION, monster)
	await get_tree().process_frame
	_check(_pickups_on_map().size() == 1, "With Endless on, the Abyss's monsters still drop")
	GameState.endless_mode = false
	GameState.layer_index = 0
	_clear_pickups()
	monster.free()


func _check_homing_cone() -> void:
	var inside: Node2D = _dummy_target(Vector2(100.0, 10.0))
	var outside: Node2D = _dummy_target(Vector2(0.0, 40.0))
	var projectile: Projectile = load("res://scenes/spells/Projectile.tscn").instantiate()
	projectile.setup(Vector2.RIGHT, 100.0, 1.0, true, Color.WHITE, 4.0, 400.0)
	_game._entities.add_child(projectile)
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	projectile.global_position = Vector2.ZERO
	_check(projectile._find_homing_target(false, true) == inside, "Homing must skip closer targets outside the cone")
	_check(projectile._find_homing_target(true, false) == outside, "Sniper shots must still take the closest target")
	inside.free()
	_check(projectile._find_homing_target(false, true) == null, "Nothing in the cone means no homing")
	outside.free()
	projectile.free()


func _dummy_target(pos: Vector2) -> Node2D:
	var script := GDScript.new()
	script.source_code = "extends Node2D\nfunc take_damage(_amount: float) -> void:\n\tpass\n"
	script.reload()
	var dummy: Node2D = Node2D.new()
	dummy.set_script(script)
	dummy.position = pos
	dummy.add_to_group("targets")
	_game._entities.add_child(dummy)
	return dummy
