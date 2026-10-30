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
var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_t += delta
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
	GameState.spawn_floating_text(global_position + Vector2(randf_range(-10, 10), -_radius), "-%d" % maxi(1, int(round(amount))), Color(1.0, 0.78, 0.32))
	queue_redraw()
	if hp <= 0.0:
		_dead = true
		GameState.request_shake(7.0, 0.28)
		destroyed.emit(self)
		queue_free()


func _draw() -> void:
	var base_col: Color = stats.color if stats != null else Color.GRAY
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.2)
	# Corrupted void aura beneath nest
	draw_circle(Vector2.ZERO, _radius * (1.18 + 0.06 * pulse), Color(base_col.r, base_col.g, base_col.b, 0.22))
	draw_arc(Vector2.ZERO, _radius * 1.15, 0.0, TAU, 36, Color(base_col.lightened(0.25), 0.65), 2.0)

	var tex: Texture2D = Config.get_tex("res://assets/sprites/nests/nest.png")
	if tex != null:
		var mod_col: Color = Color(2.2, 2.2, 2.2, 1.0) if _flash > 0.0 else base_col.lerp(Color.WHITE, 0.45)
		Config.draw_sprite_centered(self, tex, Vector2.ZERO, Vector2(_radius * 2.25, _radius * 2.25), mod_col)
	else:
		var col: Color = Color.WHITE if _flash > 0.0 else base_col
		draw_circle(Vector2.ZERO, _radius, col.darkened(0.55))
		draw_circle(Vector2.ZERO, _radius * 0.75, col.darkened(0.35))
		draw_circle(Vector2.ZERO, _radius * 0.35, Color(0.05, 0.02, 0.05))

	# HP bar
	var w: float = _radius * 2.1
	var top: Vector2 = Vector2(-w * 0.5, -_radius - 12.0)
	draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 7)), Color(0.04, 0.02, 0.08, 0.85))
	draw_rect(Rect2(top, Vector2(w * maxf(hp, 0.0) / max_hp, 5)), Color(0.95, 0.58, 0.15))

