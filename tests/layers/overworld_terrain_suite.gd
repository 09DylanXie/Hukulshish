extends Node
## Checks generated Overworld terrain, and how walkers and spells behave on it.

const GAME_SCENE: String = "res://scenes/main/Game.tscn"
const SEEDS_PER_SIZE: int = 6
## Off the shop, because walking into a stall opens its menu and pauses the game.
const PARK_POSITION: Vector2 = Vector2(100.0, 0.0)

var _failures: int = 0


func _ready() -> void:
	_check_generated_maps()
	await _check_in_game()
	print("overworld test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _make_world(size: int, world_seed: int, terrain: LayerData.Terrain) -> World:
	var world := World.new()
	world.size_in_tiles = size
	world.rng_seed = world_seed
	world.terrain = terrain
	world.clear_zones.append(Vector3(0.0, 0.0, Config.tiles(3.0)))
	world.clear_zones.append(Vector3(Config.tiles(size * 0.5 - 4.0), 0.0, Config.tiles(3.0)))
	add_child(world)
	return world


func _check_generated_maps() -> void:
	for map: MapSizeData in Config.MAP_SIZES:
		for i in SEEDS_PER_SIZE:
			var world: World = _make_world(map.size_in_tiles, i + 1, LayerData.Terrain.WILDS)
			var label: String = "%s seed %d" % [map.name, i + 1]
			_check(world.props.size() >= map.size_in_tiles, "%s has too few trees and rocks" % label)
			_check(world.props.size() == world.wall_rects.size(), "%s: every obstacle needs a sprite" % label)
			_check(_river_tile_count(world) > map.size_in_tiles * 3, "%s needs rivers" % label)
			_check(world.speed_mult_at(Vector2.ZERO) == 1.0, "%s: the spawn must stay dry" % label)
			_check(_all_open_tiles_reachable(world), "%s: a walkable tile is cut off" % label)
			world.free()
	var maze: World = _make_world(60, 1, LayerData.Terrain.MAZE)
	_check(maze.props.is_empty(), "Maze layers must have no trees or rocks")
	_check(maze.speed_mult_at(Vector2.ZERO) == 1.0 and _river_tile_count(maze) == 0, "Maze layers must have no rivers")
	maze.free()


func _river_tile_count(world: World) -> int:
	var count: int = 0
	for flag: int in world._river:
		count += flag
	return count


func _all_open_tiles_reachable(world: World) -> bool:
	world._update_flow(Vector2.ZERO)
	for i in world._blocked.size():
		if world._blocked[i] == 0 and world._dist[i] == -1:
			return false
	return true


func _check_in_game() -> void:
	var game: Node = load(GAME_SCENE).instantiate()
	get_tree().root.add_child(game)
	await get_tree().physics_frame
	var world: World = get_tree().get_first_node_in_group("world")
	var player: Player = game._player
	_check(world.terrain == LayerData.Terrain.WILDS, "The Overworld must use wilds terrain")
	var sprites: int = 0
	for child: Node in game._entities.get_children():
		if child is Sprite2D:
			sprites += 1
	_check(sprites == world.props.size(), "Trees and rocks must be y-sorted with characters")

	await _check_river_slowdown(world, player)
	await _check_monster_slowdown(game, world, player)
	await _check_spell_blocking(game, world, player)


func _river_position(world: World) -> Vector2:
	for y in world.size_in_tiles:
		for x in world.size_in_tiles:
			var pos: Vector2 = world.rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * Config.tiles(1)
			if world.speed_mult_at(pos) < 1.0 and world.speed_mult_at(pos + Vector2(Config.tiles(1), 0.0)) < 1.0:
				return pos
	return Vector2.ZERO


func _check_river_slowdown(world: World, player: Player) -> void:
	player.accepts_local_input = false
	player.remote_move_direction = Vector2.RIGHT
	var dry_speed: float = Config.tiles(GameState.player_speed_tiles())
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(is_equal_approx(player.velocity.length(), dry_speed), "The player must walk at full speed on dry land")
	player.global_position = _river_position(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(is_equal_approx(player.velocity.length(), dry_speed * 0.5), "Rivers must halve the player's speed")
	player.remote_move_direction = Vector2.ZERO
	player.global_position = PARK_POSITION


func _check_monster_slowdown(game: Node, world: World, player: Player) -> void:
	var monster: Monster = load("res://scenes/monsters/Monster.tscn").instantiate()
	monster.setup(Config.MONSTERS[0], 1.0)
	monster.position = _river_position(world)
	game._entities.add_child(monster)
	player.global_position = monster.position + Vector2(Config.tiles(1), Config.tiles(8)) * -signf(monster.position.y)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(is_equal_approx(monster.velocity.length(), monster._speed * 0.5), "Rivers must slow monsters")
	monster.free()
	player.global_position = PARK_POSITION


func _check_spell_blocking(game: Node, world: World, player: Player) -> void:
	var obstacle: Rect2 = world.wall_rects[0]
	var blocked: float = await _spell_reach(game, obstacle)
	_check(blocked > obstacle.position.x - Config.tiles(1), "The spell must reach the obstacle")
	_check(blocked < obstacle.end.x, "Trees and rocks must stop spells")
	GameState.wall_pierce_unlocked = true
	var pierced: float = await _spell_reach(game, obstacle)
	GameState.wall_pierce_unlocked = false
	_check(pierced > obstacle.end.x + Config.tiles(1), "Shoot Through Walls must pass trees and rocks")


## Fires a spell past `obstacle` and returns the furthest x position it reached.
func _spell_reach(game: Node, obstacle: Rect2) -> float:
	var projectile: Projectile = load("res://scenes/spells/Projectile.tscn").instantiate()
	projectile.source_state = GameState
	projectile.setup(Vector2.RIGHT, Config.tiles(6.0), 1.0, true, Color.WHITE, Config.tiles(0.2), Config.tiles(5.0))
	projectile.global_position = obstacle.get_center() - Vector2(Config.tiles(2.0), 0.0)
	game._entities.add_child(projectile)
	var furthest: float = projectile.global_position.x
	for frame in 90:
		await get_tree().physics_frame
		if not is_instance_valid(projectile):
			break
		furthest = maxf(furthest, projectile.global_position.x)
	return furthest
