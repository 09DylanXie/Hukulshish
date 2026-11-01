extends Node
## Checks the Nothing item, Abyssal Corruption, and Endless Mode.

const GAME_SCENE: String = "res://scenes/main/Game.tscn"
const ABYSS: int = 4

var _failures: int = 0
var _game: Node
var _player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.endless_mode = true
	_game = load(GAME_SCENE).instantiate()
	get_tree().root.add_child(_game)
	await get_tree().physics_frame
	_player = _game._player
	_player.max_hp = 500
	_player.hp = 500
	_check_nothing()
	await _check_hidden_spell_placement()
	_check_corruption()
	await _check_endless_start()
	await _check_endless_bosses()
	GameState.endless_mode = false
	print("endless test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _check_nothing() -> void:
	GameState.gold = 9999
	_check(not GameState.try_buy_nothing(), "Nothing must cost 10000 gold")
	GameState.gold = 10000
	_check(GameState.try_buy_nothing() and GameState.gold == 0, "Nothing must take the gold")
	GameState.gold = 10000
	_check(not GameState.try_buy_nothing() and GameState.gold == 10000, "Nothing can't be bought twice")
	GameState.gold = 0


func _spell_pickups() -> Array[ModPickup]:
	var found: Array[ModPickup] = []
	for child: Node in _game._entities.get_children():
		if child is ModPickup and (child as ModPickup).kind == ModPickup.Kind.UNIQUE_SPELL:
			found.append(child)
	return found


func _go_to_abyss() -> void:
	_game._clear_layer()
	GameState.layer_index = ABYSS
	_game._build_layer()
	await get_tree().physics_frame


func _check_hidden_spell_placement() -> void:
	GameState.nothing_unlocked = false
	await _go_to_abyss()
	_game._on_crystal_shattered()
	await get_tree().physics_frame
	_check(_spell_pickups().is_empty(), "No key means no hidden spell")
	GameState.nothing_unlocked = true
	await _go_to_abyss()
	_check(_spell_pickups().is_empty(), "The hidden spell must wait for the crystal")
	_game._on_crystal_shattered()
	await get_tree().physics_frame
	var pickups: Array[ModPickup] = _spell_pickups()
	_check(pickups.size() == 1, "The key must reveal the hidden spell")
	var world: World = get_tree().get_first_node_in_group("world")
	_check(pickups[0].position.y < -world.arena_radius(), "It must sit past the arena, at the top of the map")
	_check(world.is_open(pickups[0].position), "It must be reachable")
	pickups[0]._collect(GameState)
	var spell: Dictionary = GameState.unique_spells[0]
	_check(spell["speed_tiles"] == 3.0, "It must move at 1/2 speed")
	_check(not spell["can_home"], "It must never home")
	_check(not spell["uses_augments"] and spell["mana_cost"] == 1.0, "It fires like a unique spell")
	GameState.homing_unlocked = true
	GameState.homing_enabled = true
	var caster: Node = _player.get_node("SpellCaster")
	GameState.mana = 10.0
	caster._fire_all(GameState.all_spells(), Vector2.RIGHT)
	var homing: Array[bool] = []
	for child: Node in _game._entities.get_children():
		if child is Projectile:
			homing.append((child as Projectile).homing)
			child.free()
	_check(homing == [true, false], "Only the base spell should home")
	GameState.homing_unlocked = false
	GameState.homing_enabled = false


func _projectile() -> Projectile:
	var projectile: Projectile = load("res://scenes/spells/Projectile.tscn").instantiate()
	projectile.source_state = GameState
	projectile.setup(Vector2.RIGHT, 100.0, 0.0, true, Color.WHITE, 4.0, 400.0)
	projectile.effect = SpellData.Effect.CORRUPTION
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	_game._entities.add_child(projectile)
	return projectile


func _check_corruption() -> void:
	var demon: Monster = load("res://scenes/monsters/Monster.tscn").instantiate()
	demon.setup(Config.MONSTERS[3], 1.0)
	demon.process_mode = Node.PROCESS_MODE_DISABLED
	_game._entities.add_child(demon)
	_projectile()._on_body_entered(demon)
	_check(demon._dead, "Corruption must one-shot monsters, even through a Demon's bubble")

	var boss: NestBoss = load("res://scenes/bosses/NestBoss.tscn").instantiate()
	boss.setup(Color.WHITE, 1.0)
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	_game._entities.add_child(boss)
	_projectile()._on_body_entered(boss)
	_check(boss._dead, "Corruption must one-shot floor bosses, even with spawn protection")

	var nest: Nest = load("res://scenes/nests/Nest.tscn").instantiate()
	nest.stats = Config.MONSTERS[0]
	nest.process_mode = Node.PROCESS_MODE_DISABLED
	_game._entities.add_child(nest)
	_projectile()._on_body_entered(nest)
	_check(nest._dead, "Corruption must one-shot nests")

	GameState.spell_level = 5
	GameState.acquire_unique_spell(Config.LAYERS[1].unique_spell)
	var mega: MegaBoss = load("res://scenes/bosses/MegaBoss.tscn").instantiate()
	mega.setup(Color.WHITE, 1.0)
	mega.shield = 0.0
	mega.process_mode = Node.PROCESS_MODE_DISABLED
	_game._entities.add_child(mega)
	var expected: float = GameState.combined_spell_damage()
	_check(expected == 27.0, "Combined damage must add every spell, got %s" % expected)
	var before: float = mega.hp
	_projectile()._on_body_entered(mega)
	_check(is_equal_approx(before - mega.hp, expected), "The Mega Boss must take combined damage, not die")
	mega.free()
	for child: Node in _game._entities.get_children():
		if child is Projectile:
			child.free()


func _check_endless_start() -> void:
	for node: Node in get_tree().get_nodes_in_group("mega_boss"):
		node.free()
	var crystal_layer: bool = GameState.current_layer().is_final
	_check(crystal_layer, "The fight must be in the Abyss")
	_game._hidden_boss_fought = true
	GameState.mine_gold_estimate = 500.0
	GameState.mines_left_behind = true
	_game._on_mega_boss_died(0, Vector2.ZERO)
	_check(not GameState.run_over, "Endless must not end the run")
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(GameState.endless_active, "Endless must take over")
	_check(_game._music_track() == "endless", "Endless must play its own track")
	_check(GameState.current_layer().name == "Overworld", "Endless must return to the Overworld")
	_check(get_tree().get_nodes_in_group("nests").is_empty(), "Endless has no nest")
	_check(_game._castle != null, "The castle must be back")
	var mines: Array[Node] = get_tree().get_nodes_in_group("gold_mines")
	_check(mines.size() == 5, "Gold Mines must work again")
	_check((mines[0] as GoldMine).stored_gold() >= 100, "The mines must hold what built up below")
	_check(not GameState.mines_left_behind, "The estimate must stop once the mines are back")
	_check(_spell_pickups().is_empty(), "Endless has no unique spell")
	_check(GameState.scaled_monster_hp(3) == 16.0, "Endless monsters must keep the Abyss's HP")


func _director() -> EndlessDirector:
	for child: Node in _game.get_children():
		if child is EndlessDirector:
			return child
	return null


func _check_endless_bosses() -> void:
	var director: EndlessDirector = _director()
	_check(director != null, "Endless must have a director")
	var nest_free_kills: int = GameState.gold
	await get_tree().create_timer(2.2).timeout
	var monsters: Array[Node] = get_tree().get_nodes_in_group("monsters")
	_check(monsters.size() >= 4, "Endless monsters must arrive, found %d" % monsters.size())
	var half: float = Config.tiles(GameState.map_size.size_in_tiles) * 0.5
	_check((monsters[0] as Node2D).position.length() > half * 0.7, "They must come from the map edge")
	var monster: Monster = monsters[0]
	monster.take_damage(monster.hp * 2.0)
	await get_tree().process_frame
	_check(GameState.gold == nest_free_kills, "Endless monsters must drop no gold")
	_check(_drops().is_empty(), "Endless monsters must drop nothing")

	_check(get_tree().get_nodes_in_group("mega_boss").is_empty(), "The first Mega Boss must wait a minute")
	director._mega_timer = 0.0
	await get_tree().physics_frame
	await get_tree().process_frame
	var first: MegaBoss = get_tree().get_first_node_in_group("mega_boss")
	_check(first != null and first.max_hp == 12000.0, "The first Mega Boss must have 1.5× HP")
	_check(not first.spawns_monsters, "Endless Mega Bosses must not spawn extra monsters")
	first.process_mode = Node.PROCESS_MODE_DISABLED

	director._mega_timer = 0.0
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("mega_boss").size() == 1, "Mega Bosses must never stack")

	first._become_dragon()
	first._next_dragon_idx = MegaBoss.DRAGON_THRESHOLDS.size()
	first.take_damage(first.hp * 2.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(GameState.endless_megas_defeated == 1, "A kill must count")
	_check(not GameState.run_over, "Killing an Endless Mega Boss must not end the run")
	await get_tree().physics_frame
	await get_tree().process_frame
	var second: MegaBoss = get_tree().get_first_node_in_group("mega_boss")
	_check(second != null and second.max_hp == 16000.0, "The next one must arrive once the last dies, with 2× HP")


func _drops() -> Array[ModPickup]:
	var found: Array[ModPickup] = []
	for child: Node in _game._entities.get_children():
		if child is ModPickup:
			found.append(child)
	return found
