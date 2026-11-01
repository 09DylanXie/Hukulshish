extends Node
## Checks the Underworld, Catacombs and Pandemonium: their terrain, darkness, lava and demon shields.

const GAME_SCENE: String = "res://scenes/main/Game.tscn"
const UNDERWORLD: int = 1
const CATACOMBS: int = 2
const PANDEMONIUM: int = 3

var _failures: int = 0
var _game: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_generated_mazes()
	_check_lava_placement()
	_game = load(GAME_SCENE).instantiate()
	get_tree().root.add_child(_game)
	await get_tree().physics_frame
	await _check_darkness()
	await _check_lava_damage()
	await _check_demon_shield()
	_check_boss_look()
	await _check_boss_attacks()
	print("lower layers test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _make_world(index: int, size: int, world_seed: int) -> World:
	var world := World.new()
	world.apply_layer(Config.LAYERS[index])
	world.size_in_tiles = size
	world.rng_seed = world_seed
	world.clear_zones.append(Vector3(0.0, 0.0, Config.tiles(3.0)))
	add_child(world)
	return world


func _check_generated_mazes() -> void:
	var denser: World = _make_world(CATACOMBS, 60, 1)
	var rigid: World = _make_world(UNDERWORLD, 60, 1)
	_check(denser.wall_rects.size() > rigid.wall_rects.size() * 1.3, "The Catacombs must feel more like a maze")
	denser.free()
	rigid.free()
	for index: int in [UNDERWORLD, CATACOMBS, PANDEMONIUM]:
		for map: MapSizeData in Config.MAP_SIZES:
			for world_seed in range(1, 5):
				var world: World = _make_world(index, map.size_in_tiles, world_seed)
				world._update_flow(Vector2.ZERO)
				var cut_off: int = 0
				for i in world._blocked.size():
					if world._blocked[i] == 0 and world._dist[i] == -1:
						cut_off += 1
				_check(cut_off == 0, "%s %s seed %d has %d cut-off tiles" % [Config.LAYERS[index].name, map.name, world_seed, cut_off])
				world.free()


func _check_lava_placement() -> void:
	var world: World = _make_world(PANDEMONIUM, 60, 3)
	var count: int = 0
	for flag: int in world._lava:
		count += flag
	_check(count > 40, "Pandemonium needs lava cracks")
	_check(count < world._lava.size() / 2, "Lava must stay as cracks, not cover the floor")
	_check(world._lava_cracks.size() >= 30, "Pandemonium needs plenty of cracks, found %d" % world._lava_cracks.size())
	var sample: Vector2 = world.lava_sample_point()
	_check(world._lava_tile(sample), "A crack's center must burn")
	var burning: int = 0
	var tested: int = 0
	for flag_index in world._lava.size():
		if world._lava[flag_index] == 1:
			tested += 1
			if world._lava_tile(world._tile_center(Vector2i(flag_index % world._n, flag_index / world._n))):
				burning += 1
	_check(burning < tested, "Lava must follow the crack, not fill whole tiles")
	_check(not world._lava_tile(Vector2.ZERO), "The spawn must stay clear of lava")
	world.free()
	var plain: World = _make_world(UNDERWORLD, 60, 3)
	_check(plain._lava.is_empty(), "Only Pandemonium has lava")
	plain.free()


func _go_to_layer(index: int) -> void:
	_game._clear_layer()
	GameState.layer_index = index
	GameState.layer_stage = RunState.LayerStage.NEST
	_game._build_layer()
	await get_tree().physics_frame


func _check_darkness() -> void:
	_check(_game._darkness == null, "The Overworld must not be dark")
	await _go_to_layer(CATACOMBS)
	var darkness: Darkness = _game._darkness
	_check(darkness != null and darkness.is_inside_tree(), "The Catacombs must be dark")
	_check(darkness.target == _game._player, "The darkness must follow the player")
	_game._player.global_position = Vector2(60.0, 40.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var center: Variant = darkness._material.get_shader_parameter("center")
	_check(center == _game._player.global_position, "The dark circle must center on the player, got %s" % center)

	_destroy_nests()
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(_game._darkness != null, "It must stay dark until the boss dies")
	var boss: NestBoss = get_tree().get_first_node_in_group("bosses")
	boss.take_damage(boss.hp * 2.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(_game._darkness == null, "Killing the boss must restore vision")
	await _go_to_layer(UNDERWORLD)
	_check(_game._darkness == null, "Darkness must not follow the player to other layers")


func _check_lava_damage() -> void:
	await _go_to_layer(PANDEMONIUM)
	var player: Player = _game._player
	var world: World = get_tree().get_first_node_in_group("world")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = world.lava_sample_point()
	player.hp = 7
	player.shield = 0
	player._update_lava(Config.LAVA_DAMAGE_INTERVAL_SEC - 0.1)
	_check(player.hp == 7, "Lava must take 3 seconds to burn")
	player._update_lava(0.2)
	_check(player.hp == 6, "Lava must burn 1 HP every 3 seconds")
	player._iframes = 0.0
	player.shield = 2
	player._update_lava(Config.LAVA_DAMAGE_INTERVAL_SEC * 2.0)
	_check(player.hp == 6 and player.shield == 2, "An active shield must block lava without being used up")
	player.shield = 0
	player.global_position = Vector2.ZERO
	player._update_lava(Config.LAVA_DAMAGE_INTERVAL_SEC * 2.0)
	_check(player.hp == 6, "Solid ground must not burn")
	player.process_mode = Node.PROCESS_MODE_INHERIT


func _check_demon_shield() -> void:
	var demon: Monster = load("res://scenes/monsters/Monster.tscn").instantiate()
	demon.setup(Config.MONSTERS[3], 1.0)
	demon.position = Vector2(200.0, 200.0)
	_game._entities.add_child(demon)
	var full_hp: float = demon.hp
	_check(demon.has_bubble_shield(), "Demons start shielded")
	demon.take_damage(1.0)
	_check(not demon.has_bubble_shield() and demon.hp == full_hp, "One hit must break the bubble")
	for i in int(Config.DEMON_SHIELD_REGEN_SEC / 0.5) - 1:
		demon._physics_process(0.5)
	_check(not demon.has_bubble_shield(), "The bubble must stay down for 9 seconds")
	demon._physics_process(0.6)
	_check(demon.has_bubble_shield(), "The bubble must come back after 9 seconds")
	demon.free()


## A boss must survive long enough to actually fire and call its escorts.
func _check_boss_attacks() -> void:
	await _go_to_layer(UNDERWORLD)
	_destroy_nests()
	_game._player.global_position = Vector2(100.0, 0.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	var boss: NestBoss = get_tree().get_first_node_in_group("bosses")
	boss.global_position = Vector2(100.0, Config.tiles(5.0))
	boss._fire_cooldown = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bolts: int = 0
	for child: Node in _game._entities.get_children():
		if child is Projectile:
			bolts += 1
	_check(bolts >= 1, "The boss must fire a bolt")

	boss._escort_timer = 0.0
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(_monster_count() == 3, "A nest boss must bring 3 monsters, found %d" % _monster_count())
	var first: Monster = get_tree().get_first_node_in_group("monsters")
	_check(first.stats.name == "Ogre", "Escorts must match the boss")
	_check(first.position.distance_to(boss.position) < Config.tiles(3.0), "Escorts must spawn near the boss")
	var gold_before: int = GameState.gold
	first.take_damage(first.hp * 2.0)
	_check(GameState.gold > gold_before, "Escorts must pay gold like other monsters")
	await get_tree().process_frame
	_check(boss._escorts_spawned == 3, "Dead escorts must still count toward the total")
	boss._escorts_spawned = Config.BOSS_ESCORT_MAX_TOTAL - 1
	boss._escort_timer = 0.0
	var below_cap: int = _monster_count()
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(_monster_count() == below_cap + 1, "The last wave must stop exactly at 30")
	boss._escort_timer = 0.0
	var before: int = _monster_count()
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(_monster_count() == before, "Escorts must stop for good after 30 in total")

	var summoned: NestBoss = load("res://scenes/bosses/NestBoss.tscn").instantiate()
	summoned.setup(Color.WHITE, 1.0)
	summoned.take_look_of(Config.LAYERS[UNDERWORLD].monster)
	_check(summoned.escort_stats == null, "Only bosses from nests have escorts")
	summoned.free()


func _destroy_nests() -> void:
	for node: Node in get_tree().get_nodes_in_group("nests"):
		var nest: Nest = node as Nest
		nest.take_damage(nest.hp + 1.0)


func _monster_count() -> int:
	return get_tree().get_nodes_in_group("monsters").size()


func _check_boss_look() -> void:
	var boss: NestBoss = load("res://scenes/bosses/NestBoss.tscn").instantiate()
	boss.take_look_of(Config.LAYERS[UNDERWORLD].monster)
	_check(boss.sprite_path.ends_with("ogre.png"), "The Underworld boss must look like an Ogre")
	_check(ResourceLoader.exists(boss.sprite_path), "Boss sprites must exist")
	boss.free()
