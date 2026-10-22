extends Node2D
## Root of a run (Normal mode). Builds the map + random maze, spawns the castle / player / nests / gold mines,
## and wires everything together with signals. Can be run directly with F6 (uses Medium/Medium).

const WorldScene: PackedScene = preload("res://scenes/world/World.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player/Player.tscn")
const CastleScene: PackedScene = preload("res://scenes/castle/Castle.tscn")
const NestScene: PackedScene = preload("res://scenes/nests/Nest.tscn")
const BossScene: PackedScene = preload("res://scenes/bosses/NestBoss.tscn")
const MegaBossScene: PackedScene = preload("res://scenes/bosses/MegaBoss.tscn")
const ModPickupScene: PackedScene = preload("res://scenes/spells/ModPickup.tscn")
const GoldMineScene: PackedScene = preload("res://scenes/world/GoldMine.tscn")
const HUDScene: PackedScene = preload("res://scenes/ui/HUD.tscn")
const CastleMenuScene: PackedScene = preload("res://scenes/ui/CastleMenu.tscn")

## How far nests sit from the map corners, in tiles.
const NEST_CORNER_INSET_TILES: float = 4.0

var _entities: Node2D
var _player: Player
var _castle_menu: CastleMenu


func _ready() -> void:
	GameState.start_run()
	GameState.victory.connect(_on_victory)
	GameState.defeat.connect(_on_defeat)

	var map: MapSizeData = GameState.map_size
	var half: float = Config.tiles(map.size_in_tiles) * 0.5
	var bounds := Rect2(-half, -half, half * 2.0, half * 2.0)

	var nest_positions: Array[Vector2] = _compute_nest_positions(bounds)
	var mine_positions: Array[Vector2] = _pick_gold_mine_positions(bounds, nest_positions)

	var world: Node2D
	if map.scene != null:
		world = map.scene.instantiate()
	else:
		var w: World = WorldScene.instantiate()
		w.size_in_tiles = map.size_in_tiles
		var clear_radius: float = Config.tiles(3.0)
		for np in nest_positions:
			w.clear_zones.append(Vector3(np.x, np.y, clear_radius))
		for mp in mine_positions:
			w.clear_zones.append(Vector3(mp.x, mp.y, clear_radius))
		world = w
	add_child(world)
	bounds = world.get("rect")

	# All moving things live here so they y-sort together.
	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.y_sort_enabled = true
	_entities.add_to_group("projectile_container")
	add_child(_entities)

	var castle: Castle = CastleScene.instantiate()
	castle.position = Vector2.ZERO
	add_child(castle)

	_player = PlayerScene.instantiate()
	_player.bounds = bounds
	_player.position = Vector2.ZERO
	_entities.add_child(_player)

	_spawn_nests(nest_positions)
	_spawn_gold_mines(mine_positions)

	var hud: HUD = HUDScene.instantiate()
	add_child(hud)
	hud.bind_player(_player)

	_castle_menu = CastleMenuScene.instantiate()
	add_child(_castle_menu)
	castle.player_entered.connect(_on_castle_entered)


func _on_castle_entered() -> void:
	if _player != null:
		_player.heal_at_castle()
	_castle_menu.open()


func _compute_nest_positions(bounds: Rect2) -> Array[Vector2]:
	var inset: float = Config.tiles(NEST_CORNER_INSET_TILES)
	return [
		bounds.position + Vector2(inset, inset),
		Vector2(bounds.end.x - inset, bounds.position.y + inset),
		Vector2(bounds.position.x + inset, bounds.end.y - inset),
		bounds.end - Vector2(inset, inset),
	]


func _pick_gold_mine_positions(bounds: Rect2, nest_positions: Array[Vector2]) -> Array[Vector2]:
	var half: float = bounds.size.x * 0.5
	var min_dist_center: float = Config.tiles(6.0)
	var max_dist_center: float = half - Config.tiles(6.0)
	var min_dist_nest: float = Config.tiles(7.0)
	var chosen: Array[Vector2] = []
	for i in Config.GOLD_MINE_COUNT:
		var pos := Vector2.ZERO
		for _attempt in 40:
			var angle: float = randf_range(0.0, TAU)
			var dist: float = randf_range(min_dist_center, maxf(min_dist_center + 32.0, max_dist_center))
			var cand: Vector2 = Vector2.from_angle(angle) * dist
			var ok: bool = true
			for np in nest_positions:
				if cand.distance_to(np) < min_dist_nest:
					ok = false
					break
			for prev in chosen:
				if cand.distance_to(prev) < Config.tiles(8.0):
					ok = false
					break
			if ok:
				pos = cand
				break
		if pos == Vector2.ZERO:
			var side: float = 1.0 if i % 2 == 0 else -1.0
			pos = Vector2(side * half * 0.5, 0.0)
		chosen.append(pos)
	return chosen


func _spawn_nests(corners: Array[Vector2]) -> void:
	for i in corners.size():
		var nest: Nest = NestScene.instantiate()
		nest.stats = Config.MONSTERS[i]
		nest.hp_mult = GameState.difficulty.hp_mult
		nest.position = corners[i]
		nest.monster_spawned.connect(_on_monster_spawned)
		nest.destroyed.connect(_on_nest_destroyed)
		_entities.add_child(nest)


func _spawn_gold_mines(positions: Array[Vector2]) -> void:
	for pos in positions:
		var mine: GoldMine = GoldMineScene.instantiate()
		mine.position = pos
		_entities.add_child(mine)


func _on_monster_spawned(monster: Monster) -> void:
	monster.died.connect(_on_monster_died)


func _on_monster_died(gold: int, pos: Vector2) -> void:
	GameState.add_gold(gold)
	if randf() < Config.MOD_PART_DROP_CHANCE:
		var pickup: ModPickup = ModPickupScene.instantiate()
		pickup.kind = ModPickup.Kind.MOD_PART
		pickup.position = pos
		_entities.call_deferred("add_child", pickup)


func _on_nest_destroyed(nest: Nest) -> void:
	var pos: Vector2 = nest.position
	var tint: Color = nest.stats.color
	GameState.on_nest_destroyed()

	if GameState.nests_destroyed >= GameState.TOTAL_NESTS and not GameState.mega_boss_spawned:
		_spawn_mega_boss(pos, tint)

	# Nest boss appears at the nest's spot 20 s later (timer respects pause).
	await get_tree().create_timer(Config.NEST_BOSS_DELAY_SEC, false).timeout
	if not is_inside_tree() or GameState.run_over:
		return
	var boss: NestBoss = BossScene.instantiate()
	boss.setup(tint, GameState.difficulty.hp_mult)
	boss.position = pos
	boss.died.connect(_on_boss_died)
	_entities.add_child(boss)


func _spawn_mega_boss(pos: Vector2, tint: Color) -> void:
	GameState.on_mega_boss_spawned()
	var mega: MegaBoss = MegaBossScene.instantiate()
	mega.setup(tint, GameState.difficulty.hp_mult)
	mega.position = pos
	mega.minion_spawned.connect(_on_mega_minion_spawned)
	mega.died.connect(_on_mega_boss_died)
	_entities.call_deferred("add_child", mega)


func _on_mega_minion_spawned(minion: Node) -> void:
	if minion is Monster:
		(minion as Monster).died.connect(_on_monster_died)
	elif minion is NestBoss:
		(minion as NestBoss).died.connect(_on_boss_died)


func _on_boss_died(gold: int, pos: Vector2) -> void:
	GameState.add_gold(gold)
	GameState.on_boss_defeated()
	if randf() < Config.BOSS_SPELL_DROP_CHANCE:
		var pickup: ModPickup = ModPickupScene.instantiate()
		pickup.kind = ModPickup.Kind.BOSS_SPELL
		pickup.position = pos
		_entities.call_deferred("add_child", pickup)


func _on_mega_boss_died(_gold: int, _pos: Vector2) -> void:
	GameState.on_mega_boss_defeated()


func _on_victory() -> void:
	SceneRouter.goto(SceneRouter.VICTORY)


func _on_defeat() -> void:
	# Short pause so the player sees what happened.
	await get_tree().create_timer(1.0).timeout
	SceneRouter.goto(SceneRouter.GAME_OVER)
