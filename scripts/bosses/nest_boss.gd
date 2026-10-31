class_name NestBoss
extends CharacterBody2D
## Spawns immediately when its nest is destroyed (§6.6). Melee + a straight 1-damage bolt aimed at the player.
## Drops 1000 gold and has a 1-in-3 chance to drop a new spell (handled by Game via `died`).

signal died(gold: int, at: Vector2)

const ProjectileScene: PackedScene = preload("res://scenes/spells/Projectile.tscn")

var color: Color = Color(0.6, 0.1, 0.6)
var max_hp: float = Config.BOSS_HP
var hp: float = Config.BOSS_HP
var killing_player: RunState
var _damage_owner: RunState
var gold: int = Config.BOSS_GOLD
var bolt_speed_tiles: float = Config.BOSS_BOLT_SPEED_TILES

var _radius: float = Config.tiles(Config.BOSS_RADIUS_TILES)
var _attack_cooldown: float = 0.0
var _fire_cooldown: float = Config.BOSS_FIRE_INTERVAL_SEC
var _flash: float = 0.0
var _dead: bool = false
var _world: World
var _anim_t: float = 0.0
var _facing_left: bool = false


## `tint` = colour of the nest it came from. `hp_mult` only applies if Config says so (§9 Q4).
func setup(tint: Color, _hp_mult: float) -> void:
	color = tint.darkened(0.3)
	max_hp = GameState.scaled_boss_hp()
	hp = max_hp


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_anim_t += delta * 7.0
	if _flash > 0.0:
		_flash -= delta
	queue_redraw()

	var player: Player = Player.first_living_player(get_tree())
	if player == null or player.is_dead():
		velocity = Vector2.ZERO
		return

	var to_player: Vector2 = player.global_position - global_position
	var reach: float = _radius + Config.tiles(Config.PLAYER_RADIUS_TILES) + 2.0
	if to_player.length() <= reach:
		velocity = Vector2.ZERO
		if absf(to_player.x) > 4.0:
			_facing_left = to_player.x < 0.0
		if _attack_cooldown <= 0.0:
			player.take_damage(Config.BOSS_MELEE_DAMAGE)
			_attack_cooldown = Config.MONSTER_ATTACK_COOLDOWN_SEC
	else:
		var dir: Vector2 = _world.flow_direction(global_position, player.global_position) if _world != null else to_player.normalized()
		velocity = dir * Config.tiles(Config.PLAYER_SPEED_TILES * Config.BOSS_SPEED_MULT)
		if absf(velocity.x) > 8.0:
			_facing_left = velocity.x < 0.0
	move_and_slide()

	if _fire_cooldown <= 0.0 and to_player.length() <= Config.tiles(Config.BOSS_FIRE_RANGE_TILES):
		_fire_cooldown = Config.BOSS_FIRE_INTERVAL_SEC
		_fire_at(player.global_position)


func _fire_at(target_pos: Vector2) -> void:
	var p: Projectile = ProjectileScene.instantiate()
	var speed: float = Config.tiles(bolt_speed_tiles)
	p.setup(global_position.direction_to(target_pos), speed, Config.BOSS_BOLT_DAMAGE, false,
		Color(1, 0.3, 0.1), Config.tiles(0.2), Config.tiles(Config.BOSS_FIRE_RANGE_TILES * 1.5))
	p.global_position = global_position
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_parent()
	container.add_child(p)


func get_hit_radius() -> float:
	return _radius


func take_player_damage(amount: float, source: RunState) -> void:
	_damage_owner = source
	take_damage(amount)
	_damage_owner = null


func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 0.1
	GameState.spawn_floating_text(
		global_position + Vector2(randf_range(-12, 12), -_radius),
		"-%d" % maxi(1, int(round(amount))),
		Color(1.0, 0.72, 0.95)
	)
	if hp <= 0.0:
		_dead = true
		killing_player = _damage_owner
		GameState.request_shake(9.0, 0.32)
		_on_killed()
		died.emit(gold, global_position)
		queue_free()


## Hook for subclasses.
func _on_killed() -> void:
	pass


func _draw() -> void:
	Config.draw_ground_shadow(self, _radius * 1.05, _radius * 0.72, 0.38)
	draw_circle(Vector2.ZERO, _radius * 1.15, Color(color, 0.22))
	var tex: Texture2D = Config.get_tex("res://assets/sprites/bosses/nest_boss.png")
	var bob: float = sin(_anim_t) * 1.5
	if tex != null:
		var mod_col: Color = Color(2.4, 2.4, 2.4, 1.0) if _flash > 0.0 else color.lightened(0.45)
		Config.draw_sprite_centered(
			self,
			tex,
			Vector2(0, bob),
			Vector2(_radius * 2.4, _radius * 2.4),
			mod_col,
			_facing_left
		)
	else:
		var body_color: Color = Color.WHITE if _flash > 0.0 else color
		draw_circle(Vector2.ZERO, _radius, body_color)
		draw_colored_polygon(PackedVector2Array([Vector2(-_radius * 0.7, -_radius * 0.5), Vector2(-_radius * 0.3, -_radius * 0.8), Vector2(-_radius * 0.8, -_radius * 1.4)]), Color(0.95, 0.9, 0.75))
		draw_colored_polygon(PackedVector2Array([Vector2(_radius * 0.7, -_radius * 0.5), Vector2(_radius * 0.3, -_radius * 0.8), Vector2(_radius * 0.8, -_radius * 1.4)]), Color(0.95, 0.9, 0.75))
	var w: float = _radius * 2.15
	var top: Vector2 = Vector2(-w * 0.5, -_radius - 13.0)
	draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 7)), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(top, Vector2(w * maxf(hp, 0.0) / max_hp, 5)), Color(0.92, 0.22, 0.92))

