class_name Nest
extends StaticBody2D
## A monster nest in a map corner (§6.4). Spawns its monster class after a delay until destroyed.
## Set `stats` and `hp_mult` before adding it to the tree.

signal monster_spawned(monster: Monster)
signal destroyed(nest: Nest)

const MonsterScene: PackedScene = preload("res://scenes/monsters/Monster.tscn")

var stats: MonsterStats
var hp_mult: float = 1.0
var max_hp: float = Config.NEST_HP
var hp: float = Config.NEST_HP

var _radius: float = Config.tiles(Config.NEST_RADIUS_TILES)
var _spawn_timer: float = Config.NEST_SPAWN_DELAY_SEC
var _alive: int = 0
var _flash: float = 0.0
var _dead: bool = false


func _ready() -> void:
	add_to_group("targets")
	add_to_group("nests")
	collision_layer = Config.LAYER_NESTS
	collision_mask = 0
	max_hp = GameState.scaled_nest_hp()
	hp = max_hp
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)


func get_hit_radius() -> float:
	return _radius


func _physics_process(delta: float) -> void:
	if _dead or stats == null:
		return
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = stats.spawn_interval
		if _alive < Config.NEST_MAX_ALIVE:
			_spawn()


func _spawn() -> void:
	var scene: PackedScene = stats.scene if stats.scene != null else MonsterScene
	var m: Monster = scene.instantiate()
	m.setup(stats, hp_mult)
	var angle: float = randf() * TAU
	# Spawn right on the nest's center hole (tiny offset so multiple monsters don't stack at 0,0).
	m.position = position + Vector2.from_angle(angle) * Config.tiles(0.1)
	_alive += 1
	m.tree_exited.connect(func() -> void: _alive -= 1)
	get_parent().add_child(m)
	monster_spawned.emit(m)


func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 0.12
	queue_redraw()
	if hp <= 0.0:
		_dead = true
		destroyed.emit(self)
		queue_free()


func _draw() -> void:
	var col: Color = stats.color if stats != null else Color.GRAY
	if _flash > 0.0:
		col = Color.WHITE
	# Mound
	draw_circle(Vector2.ZERO, _radius, col.darkened(0.55))
	draw_circle(Vector2.ZERO, _radius * 0.75, col.darkened(0.35))
	draw_circle(Vector2.ZERO, _radius * 0.35, Color(0.05, 0.02, 0.05))
	# HP bar
	var w: float = _radius * 2.0
	var top: Vector2 = Vector2(-_radius, -_radius - 8.0)
	draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(w * maxf(hp, 0.0) / max_hp, 4)), Color(0.95, 0.6, 0.1))
