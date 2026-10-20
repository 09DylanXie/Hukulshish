extends Node2D
## Fires the base spell and every applied spell mod at the nearest target (child of Player).
## Base spell damage follows GameState.spell_level; mods use the damage frozen when applied (§6.3).

const ProjectileScene: PackedScene = preload("res://scenes/spells/Projectile.tscn")

var _base_cooldown: float = 0.0
## One cooldown per active mod, same order as GameState.active_mods.
var _mod_cooldowns: Array[float] = []


func _physics_process(delta: float) -> void:
	var owner_player := get_parent() as Player
	if owner_player != null and owner_player.is_dead():
		return

	var target: Node2D = _find_target()

	_base_cooldown -= delta
	if _base_cooldown <= 0.0 and target != null:
		var base: SpellData = Config.BASE_SPELL
		_fire(base, Config.spell_damage(GameState.spell_level), target)
		_base_cooldown = 1.0 / base.fire_rate

	while _mod_cooldowns.size() < GameState.active_mods.size():
		_mod_cooldowns.append(0.0)
	for i in GameState.active_mods.size():
		_mod_cooldowns[i] -= delta
		if _mod_cooldowns[i] <= 0.0 and target != null:
			var mod: Dictionary = GameState.active_mods[i]
			var data: SpellData = mod["data"]
			_fire(data, mod["damage"], target)
			_mod_cooldowns[i] = 1.0 / data.fire_rate


## Nearest monster / boss / nest within range (§6.1 "auto-aims at the nearest monster").
func _find_target() -> Node2D:
	var best: Node2D = null
	var best_dist: float = Config.tiles(Config.SPELL_TARGET_RANGE_TILES)
	for node in get_tree().get_nodes_in_group("targets"):
		var n := node as Node2D
		if n == null or n.is_queued_for_deletion():
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d < best_dist:
			best_dist = d
			best = n
	return best


func _fire(data: SpellData, damage: int, target: Node2D) -> void:
	var scene: PackedScene = data.projectile_scene if data.projectile_scene != null else ProjectileScene
	var p: Projectile = scene.instantiate()
	var dir: Vector2 = global_position.direction_to(target.global_position)
	p.setup(dir, Config.tiles(data.speed_tiles), damage, true, data.color, Config.tiles(data.radius_tiles))
	p.global_position = global_position
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_tree().current_scene
	container.add_child(p)
