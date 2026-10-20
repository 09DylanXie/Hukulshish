extends Node2D
## Root of a run (Normal mode). Builds the map, spawns the castle / player / nests,
## and wires everything together with signals. Can be run directly with F6 (uses Medium/Medium).

const WorldScene: PackedScene = preload("res://scenes/world/World.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player/Player.tscn")
const CastleScene: PackedScene = preload("res://scenes/castle/Castle.tscn")
const NestScene: PackedScene = preload("res://scenes/nests/Nest.tscn")
const BossScene: PackedScene = preload("res://scenes/bosses/NestBoss.tscn")
const ModPickupScene: PackedScene = preload("res://scenes/spells/ModPickup.tscn")
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
	var world: Node2D
	if map.scene != null:
		world = map.scene.instantiate()
	else:
		var w: World = WorldScene.instantiate()
		w.size_in_tiles = map.size_in_tiles
		world = w
	add_child(world)
	# Custom map scenes must expose a `rect: Rect2` property like World does.
	var bounds: Rect2 = world.get("rect")

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

	_spawn_nests(bounds)

	var hud: HUD = HUDScene.instantiate()
	add_child(hud)
	hud.bind_player(_player)

	_castle_menu = CastleMenuScene.instantiate()
	add_child(_castle_menu)
	castle.player_entered.connect(_castle_menu.open)


func _spawn_nests(bounds: Rect2) -> void:
	var inset: float = Config.tiles(NEST_CORNER_INSET_TILES)
	var corners: Array[Vector2] = [
		bounds.position + Vector2(inset, inset),
		Vector2(bounds.end.x - inset, bounds.position.y + inset),
		Vector2(bounds.position.x + inset, bounds.end.y - inset),
		bounds.end - Vector2(inset, inset),
	]
	for i in corners.size():
		var nest: Nest = NestScene.instantiate()
		nest.stats = Config.MONSTERS[i]
		nest.hp_mult = GameState.difficulty.hp_mult
		nest.position = corners[i]
		nest.monster_spawned.connect(_on_monster_spawned)
		nest.destroyed.connect(_on_nest_destroyed)
		_entities.add_child(nest)


func _on_monster_spawned(monster: Monster) -> void:
	monster.died.connect(GameState.add_gold)


func _on_nest_destroyed(nest: Nest) -> void:
	var pos: Vector2 = nest.position
	var tint: Color = nest.stats.color
	GameState.on_nest_destroyed()

	if randf() < Config.NEST_MOD_DROP_CHANCE and not Config.SPELL_MODS.is_empty():
		var pickup: ModPickup = ModPickupScene.instantiate()
		pickup.mod = Config.SPELL_MODS.pick_random()
		pickup.position = pos
		_entities.add_child(pickup)

	# Boss appears at the nest's spot 20 s later (timer respects pause).
	await get_tree().create_timer(Config.NEST_BOSS_DELAY_SEC, false).timeout
	if not is_inside_tree() or GameState.run_over:
		return
	var boss: NestBoss = BossScene.instantiate()
	boss.setup(tint, GameState.difficulty.hp_mult)
	boss.position = pos
	boss.died.connect(_on_boss_died)
	_entities.add_child(boss)


func _on_boss_died(gold: int) -> void:
	GameState.add_gold(gold)
	GameState.on_boss_defeated()


func _on_victory() -> void:
	SceneRouter.goto(SceneRouter.VICTORY)


func _on_defeat() -> void:
	# Short pause so the player sees what happened.
	await get_tree().create_timer(1.0).timeout
	SceneRouter.goto(SceneRouter.GAME_OVER)
