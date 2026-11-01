extends Node
## Checks unique spell stats, firing, placement and on-hit effects.

const GAME_SCENE: String = "res://scenes/main/Game.tscn"
const STEP_SEC: float = 0.1

var _failures: int = 0
var _game: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_status_timers()
	_game = load(GAME_SCENE).instantiate()
	get_tree().root.add_child(_game)
	await get_tree().physics_frame
	_check_placement()
	_check_magnet_ignores_unique()
	_check_stats()
	await _check_firing()
	await _check_hit_effects()
	print("unique spells test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _step(status: EnemyStatus, target: Node, seconds: float) -> void:
	for i in int(round(seconds / STEP_SEC)):
		status.update(STEP_SEC, target)


func _check_status_timers() -> void:
	var dummy: DamageDummy = DamageDummy.new()
	var status := EnemyStatus.new()
	status.apply_slow()
	_check(is_equal_approx(status.speed_mult(), 0.8), "Water must slow by 20%")
	_step(status, dummy, 2.0)
	status.apply_slow()
	_step(status, dummy, 2.0)
	_check(status.speed_mult() < 1.0, "A repeat hit must refresh the slow")
	_step(status, dummy, 1.5)
	_check(status.speed_mult() == 1.0, "The slow must end after 3 seconds")

	status.apply_stun()
	_check(status.is_stunned(), "Earth must stun")
	_step(status, dummy, 1.1)
	_check(not status.is_stunned(), "The stun must last 1 second")
	status.apply_stun()
	_check(not status.is_stunned(), "A recovering monster must not be stunned straight away")
	_step(status, dummy, 2.1)
	status.apply_stun()
	_check(status.is_stunned(), "Stun must work again after the cooldown")

	var boss_status := EnemyStatus.new()
	boss_status.immune_to_stun = true
	boss_status.apply_stun()
	_check(not boss_status.is_stunned(), "Bosses must be immune to stun")

	status.apply_poison(null)
	_step(status, dummy, 4.0)
	_check(is_equal_approx(dummy.damage, 9.0), "Poison must deal 3 HP/sec for 3 seconds, got %s" % dummy.damage)
	dummy.damage = 0.0
	status.apply_poison(null)
	_step(status, dummy, 1.5)
	status.apply_poison(null)
	_step(status, dummy, 4.0)
	_check(is_equal_approx(dummy.damage, 12.0), "Poison must refresh instead of stacking, got %s" % dummy.damage)
	dummy.free()


func _unique_pickups() -> Array[ModPickup]:
	var found: Array[ModPickup] = []
	for child: Node in _game._entities.get_children():
		if child is ModPickup and (child as ModPickup).kind == ModPickup.Kind.UNIQUE_SPELL:
			found.append(child)
	return found


func _check_placement() -> void:
	var expected: Array[String] = ["Water", "Earth", "Death", "Fireball"]
	for i in expected.size():
		_check(Config.LAYERS[i].unique_spell.name == expected[i], "Layer %d must hide %s" % [i, expected[i]])
	_check(Config.LAYERS[4].unique_spell == null, "The Abyss must have no unique spell")

	var pickups: Array[ModPickup] = _unique_pickups()
	_check(pickups.size() == 1, "Each layer must hide one unique spell")
	var world: World = get_tree().get_first_node_in_group("world")
	var half: float = world.rect.size.x * 0.5
	for i in 40:
		var pos: Vector2 = world.random_reachable_position(Vector2.ZERO, half * Config.UNIQUE_SPELL_MIN_CENTER_FRACTION)
		_check(pos.length() >= half * Config.UNIQUE_SPELL_MIN_CENTER_FRACTION, "Unique spells must not sit near the center")
		_check(world.speed_mult_at(pos) == 1.0, "Unique spells must not sit in a river")
		var tile: Vector2i = world._tile_of(pos)
		_check(world._dist[tile.y * world._n + tile.x] >= 0, "Unique spells must be reachable")


func _check_magnet_ignores_unique() -> void:
	var pickup: ModPickup = _unique_pickups()[0]
	var start: Vector2 = pickup.global_position
	GameState.magnet_unlocked = true
	pickup._physics_process(0.5)
	GameState.magnet_unlocked = false
	_check(pickup.global_position == start, "The Magnet must not pull unique spells")


func _check_stats() -> void:
	GameState.spell_level = 3
	var base: Dictionary = GameState.base_spell_stats()
	var multipliers: Array[float] = [1.0, 2.0, 3.0, 4.0]
	for i in multipliers.size():
		var spell: Dictionary = GameState.acquire_unique_spell(Config.LAYERS[i].unique_spell)
		_check(is_equal_approx(spell["damage"], base["damage"] * multipliers[i]), "Wrong damage multiplier for layer %d" % i)
		_check(spell["mana_cost"] == 1.0, "Unique spells must cost 1 mana")
		_check(not spell["uses_augments"], "Unique spells must not be augmented")
		_check(spell["fire_rate"] == base["fire_rate"], "Unique spells must match the base fire rate")
	GameState.spell_level = 9
	_check(is_equal_approx(GameState.unique_spells[1]["damage"], 10.0), "Stats must freeze at pickup")


func _projectiles() -> Array[Projectile]:
	var found: Array[Projectile] = []
	for child: Node in _game._entities.get_children():
		if child is Projectile:
			found.append(child)
	return found


func _check_firing() -> void:
	var caster: Node = _game._player.get_node("SpellCaster")
	GameState.mana = 20.0
	GameState.mod_levels["mana_pool"] = 20
	_check(caster._fire_all(GameState.all_spells(), Vector2.RIGHT), "A volley must fire with enough mana")
	_check(_projectiles().size() == 5, "All unique spells must fire with the base spell")
	_check(is_equal_approx(GameState.mana, 14.0), "A volley must cost 2 + 1 per unique spell")
	for projectile: Projectile in _projectiles():
		projectile.free()
	GameState.mana = 1.5
	_check(not caster._fire_all(GameState.all_spells(), Vector2.RIGHT), "Unique spells can't fire without the base spell")
	_check(_projectiles().is_empty() and GameState.mana == 1.5, "A failed volley must spend nothing")
	GameState.mana = 3.0
	_check(caster._fire_all(GameState.all_spells(), Vector2.RIGHT), "The base spell fires even if mana runs short")
	_check(_projectiles().size() == 2, "Unique spells fire until the mana runs out")
	for projectile: Projectile in _projectiles():
		projectile.free()
	await get_tree().physics_frame


func _make_monster(pos: Vector2) -> Monster:
	var monster: Monster = load("res://scenes/monsters/Monster.tscn").instantiate()
	monster.setup(Config.MONSTERS[0], 1.0)
	monster.max_hp = 1000.0
	monster.hp = 1000.0
	monster.position = pos
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	_game._entities.add_child(monster)
	return monster


func _hit_with(effect: SpellData.Effect, target: Monster) -> Projectile:
	var projectile: Projectile = load("res://scenes/spells/Projectile.tscn").instantiate()
	projectile.source_state = GameState
	projectile.setup(Vector2.RIGHT, 100.0, 10.0, true, Color.WHITE, 4.0, 400.0)
	projectile.effect = effect
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	_game._entities.add_child(projectile)
	projectile.global_position = target.global_position
	projectile._on_body_entered(target)
	return projectile


func _check_hit_effects() -> void:
	var at := Vector2(320.0, 320.0)
	var monster: Monster = _make_monster(at)
	_hit_with(SpellData.Effect.SLOW, monster)
	_check(monster.status.speed_mult() < 1.0, "Water must slow what it hits")
	_hit_with(SpellData.Effect.STUN, monster)
	_check(monster.status.is_stunned(), "Earth must stun what it hits")
	_hit_with(SpellData.Effect.POISON, monster)
	_check(monster.status._poison_ticks_left > 0, "Death must poison what it hits")

	var near: Monster = _make_monster(at + Vector2(Config.tiles(1.5), 0.0))
	var far: Monster = _make_monster(at + Vector2(Config.tiles(4.0), 0.0))
	var hp_before: float = monster.hp
	_hit_with(SpellData.Effect.EXPLODE, monster)
	_check(hp_before - monster.hp == 10.0, "A Fireball must hit its target once, not twice")
	_check(near.max_hp - near.hp == 10.0, "The explosion must deal the same damage across its area")
	_check(far.hp == far.max_hp, "The explosion must stop at the Bombspell's radius")
	await get_tree().physics_frame

	var boss: NestBoss = load("res://scenes/bosses/NestBoss.tscn").instantiate()
	boss.setup(Color.WHITE, 1.0)
	boss.position = at + Vector2(0.0, Config.tiles(6.0))
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	_game._entities.add_child(boss)
	boss.status.apply_stun()
	boss.status.apply_slow()
	_check(not boss.status.is_stunned() and boss.status.speed_mult() < 1.0, "Bosses resist stun but not slow")
