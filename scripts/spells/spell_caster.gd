extends Node2D
## Fires the player's base spell and any acquired boss spells at the nearest target (child of Player).
## Base spell stats scale with level + castle mods; boss spells use their frozen stats (§6.2–6.3).

const ProjectileScene: PackedScene = preload("res://scenes/spells/Projectile.tscn")

## One cooldown per spell in GameState.all_spells().
var _cooldowns: Array[float] = []


func _physics_process(delta: float) -> void:
	var owner_player := get_parent() as Player
	if owner_player != null and owner_player.is_dead():
		return

	var spells: Array[Dictionary] = GameState.all_spells()
	while _cooldowns.size() < spells.size():
		_cooldowns.append(0.0)

	for i in spells.size():
		_cooldowns[i] -= delta
		if _cooldowns[i] <= 0.0:
			var spell: Dictionary = spells[i]
			var max_range: float = Config.tiles(float(spell["range_tiles"]))
			var target: Node2D = _find_target(max_range)
			if target != null:
				_fire(spell, target, max_range)
				_cooldowns[i] = 1.0 / maxf(0.05, float(spell["fire_rate"]))


## Nearest monster / boss / nest within `max_range` pixels.
func _find_target(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist: float = max_range
	for node in get_tree().get_nodes_in_group("targets"):
		var n := node as Node2D
		if n == null or n.is_queued_for_deletion():
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d <= best_dist:
			best_dist = d
			best = n
	return best


func _fire(spell: Dictionary, target: Node2D, max_range: float) -> void:
	var p: Projectile = ProjectileScene.instantiate()
	var dir: Vector2 = global_position.direction_to(target.global_position)
	p.setup(
		dir,
		Config.tiles(float(spell["speed_tiles"])),
		float(spell["damage"]),
		true,
		spell["color"] as Color,
		Config.tiles(float(spell["radius_tiles"])),
		max_range
	)
	p.global_position = global_position
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_tree().current_scene
	container.add_child(p)
