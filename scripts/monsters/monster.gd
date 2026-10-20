class_name Monster
extends CharacterBody2D
## Generic melee monster that chases the player. Configured by a MonsterStats resource (§6.5).
## Call setup() before adding it to the tree.

signal died(gold: int)

var stats: MonsterStats
var max_hp: int = 1
var hp: int = 1

var _radius: float = 12.0
var _attack_cooldown: float = 0.0
var _flash: float = 0.0
var _dead: bool = false


func setup(monster_stats: MonsterStats, hp_mult: float) -> void:
	stats = monster_stats
	max_hp = Config.scale_hp(stats.hp, hp_mult)
	hp = max_hp
	_radius = Config.tiles(stats.radius_tiles)


func _ready() -> void:
	add_to_group("targets")
	add_to_group("monsters")
	collision_layer = Config.LAYER_ENEMIES
	collision_mask = Config.LAYER_WORLD | Config.LAYER_ENEMIES
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	if stats == null:
		return
	_attack_cooldown -= delta
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()

	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		velocity = Vector2.ZERO
		return

	var to_player: Vector2 = player.global_position - global_position
	var reach: float = _radius + Config.tiles(Config.PLAYER_RADIUS_TILES) + 2.0
	if to_player.length() <= reach:
		velocity = Vector2.ZERO
		if _attack_cooldown <= 0.0:
			player.take_damage(stats.damage)
			_attack_cooldown = Config.MONSTER_ATTACK_COOLDOWN_SEC
	else:
		velocity = to_player.normalized() * Config.tiles(Config.PLAYER_SPEED_TILES * stats.speed_mult)
	move_and_slide()


func take_damage(amount: int) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 0.1
	queue_redraw()
	if hp <= 0:
		_dead = true
		died.emit(stats.gold)
		queue_free()


func _draw() -> void:
	if stats == null:
		return
	var body_color: Color = Color.WHITE if _flash > 0.0 else stats.color
	draw_circle(Vector2.ZERO, _radius, body_color)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 24, body_color.darkened(0.5), 1.5)
	# Eyes
	draw_circle(Vector2(-_radius * 0.35, -_radius * 0.2), _radius * 0.15, Color.BLACK)
	draw_circle(Vector2(_radius * 0.35, -_radius * 0.2), _radius * 0.15, Color.BLACK)
	# HP bar (only once damaged)
	if hp < max_hp:
		var w: float = _radius * 2.0
		var top: Vector2 = Vector2(-_radius, -_radius - 6.0)
		draw_rect(Rect2(top, Vector2(w, 3)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * float(hp) / max_hp, 3)), Color(0.9, 0.2, 0.2))
