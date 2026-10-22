class_name MegaBoss
extends NestBoss
## Appears once all 4 nests are destroyed (§6.7). 1000 HP, same damage + speed as a nest boss.
## Summons a nest boss every 50 s and spawns every monster class at its normal rate.
## Defeating it wins the game.

signal minion_spawned(minion: Node)

const MonsterScene: PackedScene = preload("res://scenes/monsters/Monster.tscn")
const BossScene: PackedScene = preload("res://scenes/bosses/NestBoss.tscn")

var hp_mult: float = 1.0

var _boss_timer: float = Config.MEGA_BOSS_SPAWN_BOSS_SEC
## One spawn timer per monster class, same order as Config.MONSTERS.
var _monster_timers: Array[float] = []
var _minions: int = 0


func _init() -> void:
	max_hp = Config.MEGA_BOSS_HP
	hp = max_hp
	gold = 0
	_radius = Config.tiles(Config.MEGA_BOSS_RADIUS_TILES)
	color = Color(0.35, 0.05, 0.4)


func setup(tint: Color, mult: float) -> void:
	hp_mult = mult
	color = tint.darkened(0.5)
	if Config.DIFFICULTY_SCALES_NESTS_AND_BOSSES:
		max_hp = Config.scale_hp(Config.MEGA_BOSS_HP, mult)
		hp = max_hp


func _ready() -> void:
	super._ready()
	add_to_group("mega_boss")
	for stats in Config.MONSTERS:
		_monster_timers.append((stats as MonsterStats).spawn_interval)


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
			_monster_timers[i] = stats.spawn_interval
			if _minions < Config.MEGA_BOSS_MAX_MINIONS:
				var scene: PackedScene = stats.scene if stats.scene != null else MonsterScene
				var m: Monster = scene.instantiate()
				m.setup(stats, hp_mult)
				_spawn_minion(m, true)


func _spawn_minion(node: Node2D, counts: bool) -> void:
	node.position = position + Vector2.from_angle(randf() * TAU) * (_radius + Config.tiles(1.0))
	if counts:
		_minions += 1
		node.tree_exited.connect(func() -> void: _minions -= 1)
	get_parent().add_child(node)
	minion_spawned.emit(node)


func _draw() -> void:
	super._draw()
	# Crown
	var r: float = _radius
	draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.5, -r * 0.75), Vector2(-r * 0.5, -r * 1.05), Vector2(-r * 0.25, -r * 0.88),
		Vector2(0, -r * 1.15), Vector2(r * 0.25, -r * 0.88), Vector2(r * 0.5, -r * 1.05), Vector2(r * 0.5, -r * 0.75),
	]), Color(1, 0.82, 0.2))

