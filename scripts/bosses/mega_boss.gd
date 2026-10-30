class_name MegaBoss
extends NestBoss
## Appears once all 4 nests are destroyed (§6.7). 2000 base HP, same spell speed as player's base spell (6 tiles/s),
## and a 100 HP shield that regenerates after each 1/4 of its HP lost (at 75%, 50%, and 25% HP).
## Summons a nest boss every 25 s (2× rate) and spawns every monster class at 2× its normal rate.
## Defeating it wins the game (or starts the next 2× HP wave in Endless mode).

signal minion_spawned(minion: Node)

const MonsterScene: PackedScene = preload("res://scenes/monsters/Monster.tscn")
const BossScene: PackedScene = preload("res://scenes/bosses/NestBoss.tscn")
const QUARTER_THRESHOLDS: Array[float] = [0.75, 0.50, 0.25]

var hp_mult: float = 1.0
var max_shield: float = Config.MEGA_BOSS_SHIELD_HP
var shield: float = Config.MEGA_BOSS_SHIELD_HP

var _next_quarter_idx: int = 0
var _boss_timer: float = Config.MEGA_BOSS_SPAWN_BOSS_SEC
## One spawn timer per monster class, same order as Config.MONSTERS.
var _monster_timers: Array[float] = []
var _minions: int = 0


func _init() -> void:
	max_hp = Config.MEGA_BOSS_HP
	hp = max_hp
	max_shield = Config.MEGA_BOSS_SHIELD_HP
	shield = max_shield
	gold = 0
	bolt_speed_tiles = Config.BASE_SPELL.speed_tiles
	_radius = Config.tiles(Config.MEGA_BOSS_RADIUS_TILES)
	color = Color(0.35, 0.05, 0.4)


func setup(tint: Color, mult: float) -> void:
	hp_mult = mult
	color = tint.darkened(0.5)
	max_hp = GameState.scaled_mega_boss_hp()
	hp = max_hp
	max_shield = Config.MEGA_BOSS_SHIELD_HP
	shield = max_shield
	_next_quarter_idx = 0


func _ready() -> void:
	super._ready()
	add_to_group("mega_boss")
	for stats in Config.MONSTERS:
		_monster_timers.append((stats as MonsterStats).spawn_interval / Config.MEGA_BOSS_SPAWN_RATE_MULT)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _dead:
		return
	_boss_timer -= delta
	if _boss_timer <= 0.0:
		_boss_timer = Config.MEGA_BOSS_SPAWN_BOSS_SEC
		var boss: NestBoss = BossScene.instantiate()
		boss.setup(color.lightened(0.3), hp_mult)
		_spawn_minion(boss, false)
	for i in _monster_timers.size():
		_monster_timers[i] -= delta
		if _monster_timers[i] <= 0.0:
			var stats: MonsterStats = Config.MONSTERS[i]
			_monster_timers[i] = stats.spawn_interval / Config.MEGA_BOSS_SPAWN_RATE_MULT
			if _minions < Config.MEGA_BOSS_MAX_MINIONS:
				var scene: PackedScene = stats.scene if stats.scene != null else MonsterScene
				var m: Monster = scene.instantiate()
				m.setup(stats, hp_mult)
				_spawn_minion(m, true)


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	_flash = 0.1
	GameState.spawn_floating_text(
		global_position + Vector2(randf_range(-16, 16), -_radius),
		"-%d" % maxi(1, int(round(amount))),
		Color(0.45, 0.92, 1.0) if shield > 0.0 else Color(1.0, 0.38, 0.55)
	)
	if shield > 0.0:
		if amount <= shield:
			shield -= amount
			queue_redraw()
			return
		amount -= shield
		shield = 0.0

	hp -= amount
	# Regenerate the 100 HP shield after each 1/4 of max HP lost (75%, 50%, 25%).
	while _next_quarter_idx < QUARTER_THRESHOLDS.size() and hp <= max_hp * QUARTER_THRESHOLDS[_next_quarter_idx]:
		var threshold_hp: float = max_hp * QUARTER_THRESHOLDS[_next_quarter_idx]
		_next_quarter_idx += 1
		if hp > 0.0:
			hp = maxf(hp, threshold_hp)
			shield = max_shield
			GameState.spawn_floating_text(global_position + Vector2(0, -_radius - 18.0), "SHIELD REGENERATED!", Color(0.35, 0.92, 1.0))
			GameState.request_shake(8.0, 0.25)
			break

	queue_redraw()
	if hp <= 0.0:
		_dead = true
		GameState.request_shake(14.0, 0.45)
		_on_killed()
		died.emit(gold, global_position)
		queue_free()


func _spawn_minion(node: Node2D, counts: bool) -> void:
	node.position = position + Vector2.from_angle(randf() * TAU) * (_radius + Config.tiles(1.0))
	if counts:
		_minions += 1
		node.tree_exited.connect(func() -> void: _minions -= 1)
	get_parent().add_child(node)
	minion_spawned.emit(node)


func _draw() -> void:
	var r: float = _radius
	draw_circle(Vector2(0, r * 0.65), r * 1.1, Color(0, 0, 0, 0.48))
	draw_circle(Vector2.ZERO, r * 1.25, Color(0.42, 0.1, 0.58, 0.28))

	var tex: Texture2D = Config.get_tex("res://assets/sprites/bosses/mega_boss.png")
	var bob: float = sin(_anim_t) * 2.2
	if tex != null:
		var mod_col: Color = Color(2.4, 2.4, 2.4, 1.0) if _flash > 0.0 else Color.WHITE
		Config.draw_sprite_centered(
			self,
			tex,
			Vector2(0, -r * 0.18 + bob),
			Vector2(r * 2.75, r * 2.75),
			mod_col,
			_facing_left
		)
	else:
		super._draw()

	# HP bar
	var w: float = r * 2.2
	var top: Vector2 = Vector2(-w * 0.5, -r - 14.0)
	draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 7)), Color(0, 0, 0, 0.82))
	draw_rect(Rect2(top, Vector2(w * maxf(hp, 0.0) / max_hp, 5)), Color(0.95, 0.2, 0.55))

	# Mega Boss 100 HP regenerating shield aura & bar
	if shield > 0.0:
		var sr: float = r * 1.32
		draw_circle(Vector2.ZERO, sr, Color(0.2, 0.78, 1.0, 0.20))
		draw_arc(Vector2.ZERO, sr, 0.0, TAU, 36, Color(0.35, 0.9, 1.0, 0.92), 2.5)
		var s_top: Vector2 = Vector2(-w * 0.5, -r - 22.0)
		draw_rect(Rect2(s_top - Vector2(1, 1), Vector2(w + 2, 6)), Color(0, 0, 0, 0.82))
		draw_rect(Rect2(s_top, Vector2(w * clampf(shield / max_shield, 0.0, 1.0), 4)), Color(0.25, 0.85, 1.0))


