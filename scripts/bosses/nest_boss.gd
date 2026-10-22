class_name NestBoss
extends CharacterBody2D
## Spawns 20 s after its nest is destroyed (§6.6). Melee + a straight 1-damage bolt aimed at the player.
## Drops 1000 gold and has a 1-in-3 chance to drop a new spell (handled by Game via `died`).

signal died(gold: int, at: Vector2)

const ProjectileScene: PackedScene = preload("res://scenes/spells/Projectile.tscn")

var color: Color = Color(0.6, 0.1, 0.6)
var max_hp: float = Config.BOSS_HP
var hp: float = Config.BOSS_HP
var gold: int = Config.BOSS_GOLD

var _radius: float = Config.tiles(Config.BOSS_RADIUS_TILES)
var _attack_cooldown: float = 0.0
var _fire_cooldown: float = Config.BOSS_FIRE_INTERVAL_SEC
var _flash: float = 0.0
var _dead: bool = false
var _world: World


## `tint` = colour of the nest it came from. `hp_mult` only applies if Config says so (§9 Q4).
func setup(tint: Color, hp_mult: float) -> void:
	color = tint.darkened(0.3)
	if Config.DIFFICULTY_SCALES_NESTS_AND_BOSSES:
		max_hp = Config.scale_hp(int(max_hp), hp_mult)
		hp = max_hp


func _ready() -> void:
	add_to_group("targets")
	add_to_group("bosses")
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
	_attack_cooldown -= delta
	_fire_cooldown -= delta
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
			player.take_damage(Config.BOSS_MELEE_DAMAGE)
			_attack_cooldown = Config.MONSTER_ATTACK_COOLDOWN_SEC
	else:
		var dir: Vector2 = _world.flow_direction(global_position, player.global_position) if _world != null else to_player.normalized()
		velocity = dir * Config.tiles(Config.PLAYER_SPEED_TILES * Config.BOSS_SPEED_MULT)
	move_and_slide()

	if _fire_cooldown <= 0.0 and to_player.length() <= Config.tiles(Config.BOSS_FIRE_RANGE_TILES):
		_fire_cooldown = Config.BOSS_FIRE_INTERVAL_SEC
		_fire_at(player.global_position)


func _fire_at(target_pos: Vector2) -> void:
	var p: Projectile = ProjectileScene.instantiate()
	var speed: float = Config.tiles(Config.BOSS_BOLT_SPEED_TILES)
	p.setup(global_position.direction_to(target_pos), speed, Config.BOSS_BOLT_DAMAGE, false,
		Color(1, 0.3, 0.1), Config.tiles(0.2), Config.tiles(Config.BOSS_FIRE_RANGE_TILES * 1.5))
	p.global_position = global_position
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_parent()
	container.add_child(p)


func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 0.1
	if hp <= 0.0:
		_dead = true
		_on_killed()
		died.emit(gold, global_position)
		queue_free()


## Hook for subclasses.
func _on_killed() -> void:
	pass


func _draw() -> void:
	var body_color: Color = Color.WHITE if _flash > 0.0 else color
	draw_circle(Vector2.ZERO, _radius * 1.15, Color(color, 0.25))
	draw_circle(Vector2.ZERO, _radius, body_color)
	# Horns
	draw_colored_polygon(PackedVector2Array([Vector2(-_radius * 0.7, -_radius * 0.5), Vector2(-_radius * 0.3, -_radius * 0.8), Vector2(-_radius * 0.8, -_radius * 1.4)]), Color(0.95, 0.9, 0.75))
	draw_colored_polygon(PackedVector2Array([Vector2(_radius * 0.7, -_radius * 0.5), Vector2(_radius * 0.3, -_radius * 0.8), Vector2(_radius * 0.8, -_radius * 1.4)]), Color(0.95, 0.9, 0.75))
	draw_circle(Vector2(-_radius * 0.35, -_radius * 0.1), _radius * 0.15, Color(1, 0.9, 0.1))
	draw_circle(Vector2(_radius * 0.35, -_radius * 0.1), _radius * 0.15, Color(1, 0.9, 0.1))
	var w: float = _radius * 2.0
	var top: Vector2 = Vector2(-_radius, -_radius - 10.0)
	draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(w * maxf(hp, 0.0) / max_hp, 4)), Color(0.9, 0.2, 0.9))
