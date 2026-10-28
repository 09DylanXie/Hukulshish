extends Node2D
## Fires the player's base spell (2 mana) and any acquired boss spells (3 mana each).
## By default, the player clicks to shoot toward the cursor (respecting each spell's fire rate cooldown and mana).
## Once Auto-Shooting is unlocked in the Gold Shop (1000 gold), spells also auto-aim at the nearest target.
## Once Homing is unlocked in the Gold Shop (1500 gold), fired projectiles home toward the closest enemy.

const ProjectileScene: PackedScene = preload("res://scenes/spells/Projectile.tscn")

## One manual cooldown and one auto-fire cooldown per spell in GameState.all_spells().
## Auto-shooting fires at 1/2 the spell's fire rate so players can still manually fire.
var _manual_cooldowns: Array[float] = []
var _auto_cooldowns: Array[float] = []


func _physics_process(delta: float) -> void:
	var owner_player := get_parent() as Player
	if owner_player != null and owner_player.is_dead():
		return

	var spells: Array[Dictionary] = GameState.all_spells()
	while _manual_cooldowns.size() < spells.size():
		_manual_cooldowns.append(0.0)
	while _auto_cooldowns.size() < spells.size():
		_auto_cooldowns.append(0.0)

	var manual_click: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_viewport().gui_get_hovered_control() == null
	var mouse_world: Vector2 = get_global_mouse_position()

	for i in spells.size():
		_manual_cooldowns[i] = maxf(0.0, _manual_cooldowns[i] - delta)
		_auto_cooldowns[i] = maxf(0.0, _auto_cooldowns[i] - delta)

		var spell: Dictionary = spells[i]
		var max_range: float = Config.tiles(float(spell["range_tiles"]))
		var mana_cost: float = float(spell.get("mana_cost", Config.BASE_SPELL_MANA_COST))
		var base_rate: float = maxf(0.05, float(spell["fire_rate"]))

		if manual_click:
			if _manual_cooldowns[i] > 0.0:
				continue
			if not GameState.try_spend_mana(mana_cost):
				continue
			var dir: Vector2 = global_position.direction_to(mouse_world)
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			_fire_dir(spell, dir, max_range)
			_manual_cooldowns[i] = 1.0 / base_rate
		elif GameState.is_auto_shoot_active():
			if _auto_cooldowns[i] > 0.0:
				continue
			var target: Node2D = _find_target(max_range)
			if target != null:
				if not GameState.try_spend_mana(mana_cost):
					continue
				var dir: Vector2 = global_position.direction_to(target.global_position)
				_fire_dir(spell, dir, max_range)
				var auto_rate: float = maxf(0.05, base_rate * Config.AUTO_SHOOT_FIRE_RATE_MULT)
				_auto_cooldowns[i] = 1.0 / auto_rate


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


func _fire_dir(spell: Dictionary, dir: Vector2, max_range: float) -> void:
	var p: Projectile = ProjectileScene.instantiate()
	var dmg: float = float(spell["damage"]) * GameState.damage_boost_multiplier()
	p.setup(
		dir,
		Config.tiles(float(spell["speed_tiles"])),
		dmg,
		true,
		spell["color"] as Color,
		Config.tiles(float(spell["radius_tiles"])),
		max_range,
		GameState.is_homing_active(),
		Projectile.ProjKind.INITIAL,
		null
	)
	p.global_position = global_position
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_tree().current_scene
	container.add_child(p)
