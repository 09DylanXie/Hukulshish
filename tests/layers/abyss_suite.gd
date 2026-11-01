extends Node
## Plays the final fight: the arena, crystal, Mega Boss, summons, dragon and the white flash.

const GAME_SCENE: String = "res://scenes/main/Game.tscn"
const ABYSS: int = 4

var _failures: int = 0
var _game: Node
var _player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_shapes()
	_game = load(GAME_SCENE).instantiate()
	get_tree().root.add_child(_game)
	await get_tree().physics_frame
	_player = _game._player
	_player.max_hp = 500
	_player.hp = 500
	_game._clear_layer()
	GameState.layer_index = ABYSS
	_game._build_layer()
	await get_tree().physics_frame

	await _check_crystal()
	var mega: MegaBoss = get_tree().get_first_node_in_group("mega_boss")
	await _check_monster_waves(mega)
	await _check_summons(mega)
	await _check_waiting(mega)
	await _check_fire_line()
	await _check_dragon(mega)
	await _check_hazards(mega)
	await _check_hidden_boss()
	await _check_ending()
	print("abyss test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _check_shapes() -> void:
	for map: MapSizeData in Config.MAP_SIZES:
		var world := World.new()
		world.apply_layer(Config.LAYERS[ABYSS])
		world.size_in_tiles = map.size_in_tiles
		add_child(world)
		var spawn := Vector2(0.0, world.rect.end.y - Config.tiles(Config.FINAL_LAYER_SPAWN_INSET_TILES))
		var top := Vector2(0.0, world.rect.position.y + Config.tiles(3.0))
		_check(world.is_open(spawn) and world.is_open(top), "%s: both corridors must be open" % map.name)
		_check(world.is_open(Vector2(world.arena_radius() - Config.tiles(1.0), 0.0)), "%s: the arena must be open" % map.name)
		_check(not world.is_open(Vector2(world.arena_radius() + Config.tiles(1.0), 0.0)), "%s: rock must surround the arena" % map.name)
		_check(not world.is_open(Vector2(Config.tiles(4.0), spawn.y)), "%s: rock must line the corridor" % map.name)
		world._update_flow(spawn)
		var cut_off: int = 0
		for i in world._blocked.size():
			if world._blocked[i] == 0 and world._dist[i] == -1:
				cut_off += 1
		_check(cut_off == 0, "%s: %d open tiles are cut off from the spawn" % [map.name, cut_off])
		_check(world.wall_rects.size() < map.size_in_tiles * 3, "%s: too many wall pieces (%d)" % [map.name, world.wall_rects.size()])
		world.free()


func _check_crystal() -> void:
	_check(_player.global_position.y > 0.0, "The player must arrive at the bottom")
	_check(get_tree().get_nodes_in_group("mega_boss").is_empty(), "The Mega Boss must wait inside the crystal")
	_check(GameState.in_abyss_approach(), "The walk to the crystal must be slow")
	_player.global_position = Vector2(0.0, Config.tiles(6.0))
	for frame in 10:
		await get_tree().physics_frame
	_check(get_tree().get_nodes_in_group("mega_boss").is_empty(), "Entering the arena must not break the crystal")
	_player.global_position = Vector2(0.0, Config.tiles(1.0))
	for frame in 10:
		await get_tree().physics_frame
	_check(get_tree().get_nodes_in_group("mega_boss").size() == 1, "Touching the crystal must release the Mega Boss")
	_check(not GameState.in_abyss_approach(), "The player must get their speed back")
	_check(GameState.mega_boss_spawned, "The HUD must learn the Mega Boss is out")


func _count_monsters(monster_name: String) -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("monsters"):
		if (node as Monster).stats.name == monster_name:
			count += 1
	return count


func _check_monster_waves(mega: MegaBoss) -> void:
	var expected: Dictionary = {"Goblin": 4, "Ogre": 3, "Undead": 2, "Demon": 1}
	for stats: MonsterStats in Config.MONSTERS:
		_check(stats.mega_spawn_count == expected[stats.name], "Wrong %s spawn count" % stats.name)
	mega._spawn_monsters(2.1)
	await get_tree().process_frame
	_check(_count_monsters("Goblin") == 4, "Goblins must spawn 4 every 2 seconds")
	_check(_count_monsters("Ogre") == 0, "Ogres must wait 3 seconds")
	for wave in 8:
		mega._spawn_monsters(5.1)
	await get_tree().process_frame
	for monster_name: String in expected:
		_check(_count_monsters(monster_name) <= 10, "%s must stop at the cap of 10" % monster_name)
	_check(_count_monsters("Goblin") == 10, "Goblins must reach the cap")
	for node: Node in get_tree().get_nodes_in_group("monsters"):
		node.free()
	await get_tree().physics_frame
	_check(mega._waves.alive[0] == 0, "Dead monsters must free up the cap")
	mega.process_mode = Node.PROCESS_MODE_DISABLED


func _floor_bosses() -> Array[NestBoss]:
	var found: Array[NestBoss] = []
	for node: Node in get_tree().get_nodes_in_group("bosses"):
		if not node is MegaBoss:
			found.append(node)
	return found


func _check_summons(mega: MegaBoss) -> void:
	var expected_hp: Array[float] = [480.0, 720.0, 1080.0]
	var expected_look: Array[String] = ["goblin", "ogre", "undead"]
	for i in 3:
		mega.shield = 0.0
		mega.take_damage(mega.max_hp)
		await get_tree().process_frame
		var bosses: Array[NestBoss] = _floor_bosses()
		_check(bosses.size() == i + 1, "Summon %d: expected %d floor bosses, found %d" % [i, i + 1, bosses.size()])
		_check(mega.phase == MegaBoss.Phase.FIGHT, "A huge hit must not skip a quarter")
		_check(is_equal_approx(mega.hp, mega.max_hp * [0.75, 0.5, 0.25][i]), "HP must stop at each quarter")
		_check(mega.shield == mega.max_shield, "The shield must regenerate at each quarter")
		await _check_cataclysm(mega)
		var newest: NestBoss = bosses[bosses.size() - 1]
		_check(newest.max_hp == expected_hp[i], "Summon %d must have its own layer's HP" % i)
		_check(newest.sprite_path.ends_with(expected_look[i] + ".png"), "Summon %d is the wrong boss" % i)
	_check(get_tree().get_nodes_in_group("mega_boss").size() == 1, "The Mega Boss must no longer split")


func _check_waiting(mega: MegaBoss) -> void:
	mega.shield = 0.0
	mega.take_damage(mega.max_hp)
	await get_tree().process_frame
	_check(mega.phase == MegaBoss.Phase.WAITING, "At 0% it must wait for its summons")
	_check(is_instance_valid(mega) and not mega.is_queued_for_deletion(), "It must stay on the map")
	_check(_floor_bosses().size() == 4, "The Demon boss must arrive at 0%")
	_check(_floor_bosses()[3].max_hp == 1620.0, "The Demon boss must have its own layer's HP")
	_check(not mega.is_in_group("targets"), "Homing must ignore it while it waits")
	var before: float = mega.hp
	mega.take_damage(100.0)
	_check(mega.hp == before, "It must be invulnerable while it waits")
	_check(not GameState.mega_boss_defeated, "The fight isn't over yet")

	mega.process_mode = Node.PROCESS_MODE_INHERIT
	var bosses: Array[NestBoss] = _floor_bosses()
	for i in 3:
		bosses[i].take_damage(bosses[i].hp * 2.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(mega.phase == MegaBoss.Phase.WAITING, "One boss left means it keeps waiting")
	var gold_before: int = GameState.gold
	bosses[3].take_damage(bosses[3].hp * 2.0)
	_check(GameState.gold == gold_before, "Summoned bosses must drop nothing")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(mega.phase == MegaBoss.Phase.DRAGON, "Killing every summon must wake the dragon")
	_check(_game._music_track() == "dragon", "The dragon must have its own track")
	_check(mega.hp == mega.max_hp and mega.shield == 0.0, "The dragon must revive to full HP with no shield")
	_check(mega.is_in_group("targets"), "The dragon must be targetable")
	_check(mega.collision_mask == 0, "The dragon must fly over walls")
	mega.process_mode = Node.PROCESS_MODE_DISABLED


func _check_fire_line() -> void:
	_player.global_position = Vector2(0.0, Config.tiles(6.0))
	_player._iframes = 0.0
	_player.hp = 100
	_player.shield = 2
	var line := FireLine.new()
	line.setup(_player.global_position - Vector2(Config.tiles(5.0), 0.0), Vector2.RIGHT)
	line.process_mode = Node.PROCESS_MODE_DISABLED
	var ended: Array[bool] = [false]
	line.finished.connect(func() -> void: ended[0] = true)
	_game._entities.add_child(line)
	_check(is_equal_approx(line.length, Config.tiles(10.0)), "Fire lines must match the original spell range")
	_check(is_equal_approx(line.width, Config.tiles(0.4)), "Fire lines must match a boss spell's width")

	line._physics_process(Config.DRAGON_FIRE_WARNING_SEC - 0.05)
	_check(not line.is_burning() and _player.shield == 2, "The warning must not hurt anyone")
	line._physics_process(0.1)
	_check(line.is_burning(), "Fire must start after 3 seconds")
	line._physics_process(0.01)
	_check(_player.shield == 1 and _player.hp == 100, "Fire must eat 1 shield per second first")
	line._physics_process(1.0)
	_check(_player.shield == 0 and _player.hp == 100, "HP must be safe until the shield breaks")
	line._physics_process(1.0)
	_check(_player.hp == 97, "Fire must burn 3 HP per second once the shield is gone")
	line._physics_process(1.0)
	_check(ended[0], "Fire must stop after 3 seconds")
	await get_tree().process_frame

	var missed := FireLine.new()
	missed.setup(_player.global_position + Vector2(0.0, Config.tiles(2.0)), Vector2.RIGHT)
	_check(not missed._touches(_player), "Stepping out of the line must be safe")
	missed.free()


func _check_dragon(mega: MegaBoss) -> void:
	mega.process_mode = Node.PROCESS_MODE_INHERIT
	mega._fire_cooldown_left = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(mega._fire_line != null, "The dragon must breathe fire")
	var first: FireLine = mega._fire_line
	first.finished.emit()
	first.free()
	_check(mega._fire_line == null and is_equal_approx(mega._fire_cooldown_left, 5.0), "The next line must wait 5 seconds after the last ends")
	var start: Vector2 = mega.global_position
	await get_tree().create_timer(0.3).timeout
	_check(mega.global_position != start, "The dragon must keep moving")
	_check(get_tree().get_nodes_in_group("monsters").is_empty(), "The dragon must spawn nothing")


## A Cataclysm blocks all damage and hides the boss from homing until it ends.
func _check_cataclysm(mega: MegaBoss) -> void:
	_check(mega.in_cataclysm(), "Every quarter must start a Cataclysm")
	_check(not mega.is_in_group("targets"), "Homing must ignore the boss during a Cataclysm")
	var before: float = mega.hp
	var shield_before: float = mega.shield
	mega.take_damage(99999.0)
	_check(mega.hp == before and mega.shield == shield_before, "The boss must be invulnerable during a Cataclysm")
	_skip_cataclysm(mega)
	await get_tree().process_frame
	_check(not mega.in_cataclysm() and mega.is_in_group("targets"), "The boss must be hittable again afterwards")


func _skip_cataclysm(mega: MegaBoss) -> void:
	var running: Cataclysm = mega._cataclysm
	running.finished.emit()
	running.free()


func _hazard(pattern: Cataclysm.Pattern) -> Cataclysm:
	var cataclysm := Cataclysm.new()
	cataclysm.pattern = pattern
	cataclysm.position = Vector2.ZERO
	cataclysm.process_mode = Node.PROCESS_MODE_DISABLED
	_game._entities.add_child(cataclysm)
	return cataclysm


func _check_hazards(mega: MegaBoss) -> void:
	mega.process_mode = Node.PROCESS_MODE_DISABLED
	_player.global_position = Vector2(Config.tiles(3.0), 0.0)
	_player.hp = 100
	_player.shield = 0
	_player._iframes = 0.0

	var meteors: Cataclysm = _hazard(Cataclysm.Pattern.METEORS)
	meteors._physics_process(0.01)
	_check(not meteors.net_shapes().is_empty(), "Meteors must be marked on the ground first")
	_check(_player.hp == 100, "A meteor must not hurt before its fuse ends")
	meteors._physics_process(Config.METEOR_FUSE_SEC + 0.02)
	_check(_player.hp == 100 - Config.METEOR_DAMAGE, "Standing on a marked spot must hurt")
	meteors.free()

	_player._iframes = 0.0
	var waves: Cataclysm = _hazard(Cataclysm.Pattern.SHOCKWAVES)
	waves._waves = [Vector2(Config.tiles(2.5), PI * 0.5)]
	waves._update_waves(0.2)
	_check(_player.hp == 100 - Config.METEOR_DAMAGE - Config.SHOCKWAVE_DAMAGE, "A ring must hit a player outside its gaps")
	_player._iframes = 0.0
	var hp_before: int = _player.hp
	waves._waves = [Vector2(Config.tiles(2.5), 0.0)]
	waves._update_waves(0.2)
	_check(_player.hp == hp_before, "Standing in a gap must be safe")
	waves.free()

	_player._iframes = 0.0
	hp_before = _player.hp
	var collapse: Cataclysm = _hazard(Cataclysm.Pattern.COLLAPSE)
	collapse._safe_center = _player.global_position
	collapse._safe_target = _player.global_position
	collapse._collapse_warning = 0.0
	collapse._update_collapse(0.1)
	_check(_player.hp == hp_before, "The safe circle must be safe")
	collapse._safe_center = Vector2(Config.tiles(30.0), 0.0)
	collapse._safe_target = collapse._safe_center
	collapse._collapse_tick = 0.0
	collapse._update_collapse(0.1)
	_check(_player.hp == hp_before - Config.COLLAPSE_DAMAGE, "Outside the safe circle must burn")
	collapse.free()
	mega.process_mode = Node.PROCESS_MODE_INHERIT

	# The dragon has three Cataclysms of its own, and big hits can't skip them.
	mega.take_damage(mega.max_hp * 3.0)
	_check(mega.in_cataclysm() and is_equal_approx(mega.hp, mega.max_hp * 0.75), "The dragon must stop at 75% for its first Cataclysm")
	_check(mega._cataclysm.pattern == Cataclysm.Pattern.INFERNO, "The dragon opens with the Inferno")
	_skip_cataclysm(mega)
	mega.take_damage(mega.max_hp * 3.0)
	_check(is_equal_approx(mega.hp, mega.max_hp * 0.5), "The dragon must stop at 50% for its second Cataclysm")
	_check(mega._cataclysm.pattern == Cataclysm.Pattern.DRAGONS_BREATH, "The second must be Dragon's Breath")
	await _check_breath(mega._cataclysm)
	_skip_cataclysm(mega)
	mega.take_damage(mega.max_hp * 3.0)
	_check(is_equal_approx(mega.hp, mega.max_hp * 0.25), "The dragon must stop at 25% for its third Cataclysm")
	_skip_cataclysm(mega)
	await get_tree().process_frame


func _check_breath(breath: Cataclysm) -> void:
	breath._beam_warning = 1.0
	var tip: Vector2 = breath._beam_tip(0)
	_player.global_position = breath.global_position.lerp(tip, 0.4)
	_player._iframes = 0.0
	var hp_before: int = _player.hp
	breath._update_breath(0.1)
	_check(_player.hp == hp_before, "The beams must not hurt during their warning")
	breath._beam_warning = 0.0
	_player._iframes = 0.0
	_player.global_position = breath.global_position.lerp(breath._beam_tip(0), 0.4)
	breath._update_breath(0.01)
	_check(_player.hp == hp_before - Config.BREATH_DAMAGE, "A beam must burn whoever it sweeps over")
	_player._iframes = 0.0


func _check_hidden_boss() -> void:
	var dragon: MegaBoss = get_tree().get_first_node_in_group("mega_boss")
	dragon.take_damage(dragon.hp * 2.0)
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(not GameState.run_over, "Killing the dragon must not end the game yet")
	var hidden: MegaBoss = null
	for node: Node in get_tree().get_nodes_in_group("mega_boss"):
		if not (node as MegaBoss)._dead:
			hidden = node
	_check(hidden != null and hidden.phase == MegaBoss.Phase.HIDDEN, "The hidden boss must follow the dragon")
	_check(hidden.max_hp == Config.MEGA_BOSS_HP * 2.0, "It must have 2× the Mega Boss's HP")
	_check(_game._music_track() == "hidden_boss", "It must have its own track")
	hidden.process_mode = Node.PROCESS_MODE_DISABLED
	hidden.shield = 0.0
	var hp_before: float = hidden.hp
	var shot: Projectile = load("res://scenes/spells/Projectile.tscn").instantiate()
	shot.source_state = GameState
	shot.setup(Vector2.RIGHT, 100.0, 0.0, true, Color.WHITE, 4.0, 400.0)
	shot.effect = SpellData.Effect.CORRUPTION
	shot.process_mode = Node.PROCESS_MODE_DISABLED
	_game._entities.add_child(shot)
	shot._on_body_entered(hidden)
	_check(is_equal_approx(hp_before - hidden.hp, GameState.combined_spell_damage()), "Corruption must deal combined damage, not one-shot it")
	hidden.take_damage(hidden.max_hp * 3.0)
	_check(is_equal_approx(hidden.hp, hidden.max_hp * 0.66) and hidden.in_cataclysm(), "It must stop at 66%")
	_skip_cataclysm(hidden)
	hidden.take_damage(hidden.max_hp * 3.0)
	_check(is_equal_approx(hidden.hp, hidden.max_hp * 0.33) and hidden.in_cataclysm(), "It must stop at 33%")
	_skip_cataclysm(hidden)
	await get_tree().process_frame


func _check_ending() -> void:
	var mega: MegaBoss = get_tree().get_first_node_in_group("mega_boss")
	mega.take_damage(mega.hp * 2.0)
	_check(GameState.run_over and GameState.mega_boss_defeated, "Killing the hidden boss must win the game")
	_check(get_tree().paused, "The game must freeze for the white flash")
	await get_tree().create_timer(0.3).timeout
	var flash: ColorRect = null
	for child: Node in _game.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer == 100:
			flash = child.get_child(0) as ColorRect
	_check(flash != null and flash.color.a > 0.05 and flash.color.a < 1.0, "The screen must be fading to white")
	await get_tree().create_timer(Config.VICTORY_FLASH_SEC).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not get_tree().paused, "The flash must unpause on the way out")
	var scene: Node = get_tree().current_scene
	_check(scene != null and scene.scene_file_path == SceneRouter.VICTORY, "The flash must lead to the Victory screen")
