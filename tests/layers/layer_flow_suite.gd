extends Node
## Plays a real descent: nest, boss, drops, portal, next layer, through to the Mega Boss.

const GAME_SCENE: String = "res://scenes/main/Game.tscn"

var _failures: int = 0
var _game: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_hp_scaling()
	await _check_descent()
	print("layer test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _check_hp_scaling() -> void:
	GameState.coop_mode = false
	GameState.difficulty = Config.DIFFICULTIES[1]
	GameState.start_run()
	GameState.layer_index = 2
	_check(GameState.scaled_monster_hp(4) == 9.0, "Medium layer 3 Undead must have 4 × 1.5² HP")
	_check(GameState.scaled_nest_hp() == 158.0, "Nests must scale like monsters, rounded up")
	_check(GameState.scaled_boss_hp() == 1080.0, "Layer 3 boss must have 1080 HP")
	_check(GameState.scaled_mega_boss_hp() == 8000.0, "The Mega Boss must ignore depth")

	GameState.difficulty = Config.DIFFICULTIES[3]
	GameState.layer_index = 4
	_check(GameState.scaled_monster_hp(3) == 1215.0, "Extreme Abyss Goblin must have 3 × 5 × 3⁴ HP")
	_check(GameState.scaled_boss_hp() == 2430.0, "Bosses must ignore difficulty")
	_check(GameState.scaled_mega_boss_hp() == 8000.0, "The Mega Boss must ignore difficulty")

	GameState.difficulty = Config.DIFFICULTIES[1]
	GameState.layer_index = Config.LAYERS.size() - 1
	_check(not GameState.descend(), "The final layer must have nowhere to descend to")
	GameState.layer_index = 0


func _check_descent() -> void:
	_game = load(GAME_SCENE).instantiate()
	get_tree().root.add_child(_game)
	await get_tree().physics_frame
	var player: Player = _game._player
	player.shield = 3
	player.hp = 6

	var expected_monsters: Array[String] = ["Goblin", "Ogre", "Undead", "Demon"]
	var expected_boss_hp: Array[float] = [480.0, 720.0, 1080.0, 1620.0]
	for i in expected_monsters.size():
		await _clear_layer(player, expected_monsters[i], expected_boss_hp[i], i)

	var layer: LayerData = GameState.current_layer()
	_check(layer.name == "Abyss" and layer.is_final, "The fifth layer must be the Abyss")
	_check(player.global_position.y > 0.0, "The Abyss spawn must be at the bottom of the map")
	_check(_game._castle == null and _stall_count() == 0, "The Abyss must have no castle or shop")
	_check(get_tree().get_nodes_in_group("gold_mines").is_empty(), "Gold mines must stay on the Overworld")
	_check(player.hp == 6 and player.shield == 3, "HP and shield must carry across layers")


func _clear_layer(player: Player, monster_name: String, boss_hp: float, index: int) -> void:
	_check(GameState.layer_index == index, "Expected to be on layer %d" % index)
	_check(GameState.layer_stage == RunState.LayerStage.NEST, "A new layer must start at its nest")
	var nests: Array[Node] = get_tree().get_nodes_in_group("nests")
	_check(nests.size() == 2, "Layer %d must have two nests, found %d" % [index, nests.size()])
	_check((nests[0] as Nest).position.distance_to((nests[1] as Nest).position) >= Config.tiles(Config.NEST_MIN_SPACING_TILES), "Nests must stay apart")
	for standing: Node in nests:
		_check((standing as Nest).stats.name == monster_name, "Layer %d nests must spawn %s" % [index, monster_name])
		_check(_near_edge((standing as Nest).position), "Nests must sit near a map edge")
	var first_nest: Nest = nests[0]
	var nest: Nest = nests[1]
	_check(get_tree().get_nodes_in_group("bosses").is_empty(), "Old bosses must not follow the player down")
	var mines: int = get_tree().get_nodes_in_group("gold_mines").size()
	_check((mines > 0) == (index == 0), "Layer %d has the wrong gold mines" % index)
	_check(_stall_count() == 5, "Layer %d must have a 5-stall shop" % index)
	_check((_game._castle != null) == (index == 0), "Only the Overworld has a castle")
	_check(player.global_position.is_equal_approx(Vector2.ZERO), "The player must arrive in the middle")

	var nest_position: Vector2 = nest.position
	first_nest.take_damage(first_nest.hp + 1.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(GameState.layer_stage == RunState.LayerStage.NEST, "One nest left must not call the boss")
	_check(get_tree().get_nodes_in_group("bosses").is_empty(), "The boss must wait for the last nest")
	nest.take_damage(nest.hp + 1.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(GameState.layer_stage == RunState.LayerStage.BOSS, "Destroying the last nest must call the boss")
	_check(get_tree().get_nodes_in_group("nests").is_empty(), "The nests must be gone")
	var boss: NestBoss = get_tree().get_first_node_in_group("bosses")
	_check(boss != null and boss.max_hp == boss_hp, "Layer %d boss must have %d HP" % [index, boss_hp])
	_check(_find_portal() == null, "The portal must stay closed until the boss dies")

	var scrolls_before: int = GameState.aug_scrolls
	var gold_before: int = GameState.gold
	boss.take_damage(boss.hp * 2.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(GameState.layer_stage == RunState.LayerStage.PORTAL, "Killing the boss must open the portal")
	_check(GameState.gold - gold_before == Config.BOSS_GOLD, "Bosses must drop 1000 gold")
	var pickups: Array[ModPickup] = []
	for node: Node in get_tree().get_nodes_in_group("pickups"):
		if (node as ModPickup).kind != ModPickup.Kind.UNIQUE_SPELL:
			pickups.append(node)
	_check(pickups.size() >= Config.BOSS_AUG_SCROLL_DROP_MIN and pickups.size() <= Config.BOSS_AUG_SCROLL_DROP_MAX, "Bosses must drop 3–5 scrolls")
	for pickup: ModPickup in pickups:
		_check(pickup.kind == ModPickup.Kind.AUG_SCROLL, "Boss drops must all be Augmentation Scrolls")
		pickup._collect(GameState)
	_check(GameState.aug_scrolls - scrolls_before == pickups.size(), "Collecting must grant each scroll")
	var portal: Portal = _find_portal()
	_check(portal != null and portal.position == nest_position, "The portal must open where the last nest stood")

	# A player already standing there isn't pulled through before collecting the drops.
	player.global_position = nest_position
	await get_tree().create_timer(0.2).timeout
	_check(GameState.layer_index == index, "A new portal must not take the player straight away")
	player.global_position = nest_position.move_toward(Vector2.ZERO, Config.tiles(5.0))
	await get_tree().create_timer(Config.PORTAL_ARM_SEC).timeout
	player.global_position = nest_position
	for frame in 30:
		await get_tree().physics_frame
		if GameState.layer_index != index:
			break
	await get_tree().process_frame
	_check(GameState.layer_index == index + 1, "Entering the portal must descend from layer %d" % index)
	_check(_find_portal() == null, "The old portal must not follow the player down")


func _near_edge(pos: Vector2) -> bool:
	var half: float = Config.tiles(GameState.map_size.size_in_tiles) * 0.5
	return maxf(absf(pos.x), absf(pos.y)) >= half - Config.tiles(Config.NEST_EDGE_INSET_TILES) - 1.0


func _stall_count() -> int:
	var count: int = 0
	for child: Node in _game._entities.get_children():
		if child is ShopStall:
			count += 1
	return count


func _find_portal() -> Portal:
	for child: Node in _game._entities.get_children():
		if child is Portal:
			return child
	return null
