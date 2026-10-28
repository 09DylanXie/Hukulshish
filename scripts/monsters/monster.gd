class_name Monster
extends CharacterBody2D
## Generic melee monster that chases the player through the maze. Configured by a MonsterStats resource (§6.5).
## Speed comes from its size (Config.monster_speed_tiles). Call setup() before adding it to the tree.

signal died(gold: int, at: Vector2, is_demon: bool, is_goblin: bool)

var stats: MonsterStats
var max_hp: float = 1.0
var hp: float = 1.0

var _radius: float = 12.0
var _speed: float = 32.0
var _has_bubble_shield: bool = false
var _attack_cooldown: float = 0.0
var _flash: float = 0.0
var _dead: bool = false
var _world: World


func setup(monster_stats: MonsterStats, _hp_mult: float) -> void:
	stats = monster_stats
	max_hp = GameState.scaled_monster_hp(stats.hp)
	hp = max_hp
	_radius = Config.tiles(stats.radius_tiles)
	_speed = Config.tiles(Config.monster_speed_tiles(stats.radius_tiles))
	_has_bubble_shield = stats.has_bubble_shield or stats.name == "Demon"


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
	_world = get_tree().get_first_node_in_group("world") as World


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
		var dir: Vector2 = _world.flow_direction(global_position, player.global_position) if _world != null else to_player.normalized()
		velocity = dir * _speed
	move_and_slide()


func get_hit_radius() -> float:
	return _radius


func has_bubble_shield() -> bool:
	return _has_bubble_shield


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	if _has_bubble_shield:
		_has_bubble_shield = false
		_flash = 0.15
		queue_redraw()
		return
	hp -= amount
	_flash = 0.1
	queue_redraw()
	if hp <= 0.0:
		_dead = true
		var is_demon: bool = stats != null and (stats.has_bubble_shield or stats.name == "Demon")
		var is_goblin: bool = stats != null and stats.name == "Goblin"
		died.emit(stats.gold, global_position, is_demon, is_goblin)
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
	# Demon bubble shield
	if _has_bubble_shield:
		var sr: float = _radius * 1.38
		draw_circle(Vector2.ZERO, sr, Color(0.25, 0.85, 1.0, 0.26))
		draw_arc(Vector2.ZERO, sr, 0.0, TAU, 28, Color(0.45, 0.95, 1.0, 0.92), 2.0)
	# HP bar (only once damaged)
	if hp < max_hp:
		var w: float = _radius * 2.0
		var top: Vector2 = Vector2(-_radius, -_radius - 6.0)
		draw_rect(Rect2(top, Vector2(w, 3)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * hp / max_hp, 3)), Color(0.9, 0.2, 0.2))
