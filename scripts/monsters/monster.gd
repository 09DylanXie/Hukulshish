class_name Monster
extends CharacterBody2D
## Generic melee monster that chases the player through the maze. Configured by a MonsterStats resource (§6.5).
## Speed comes from its size (Config.monster_speed_tiles). Call setup() before adding it to the tree.
## Undead also cast a 0-damage slow spell moving at half normal spell speed (3.0 tiles/sec).

signal died(gold: int, at: Vector2)


var stats: MonsterStats
var max_hp: float = 1.0
var hp: float = 1.0
var killing_player: RunState
var status: EnemyStatus = EnemyStatus.new()
var _damage_owner: RunState

var _radius: float = 12.0
var _speed: float = 32.0
var _has_bubble_shield: bool = false
var _shield_regen_left: float = 0.0
var _is_undead: bool = false
var _attack_cooldown: float = 0.0
var _slow_fire_cooldown: float = Config.UNDEAD_SLOW_FIRE_INTERVAL_SEC
var _flash: float = 0.0
var _dead: bool = false
var _world: World
var _anim_t: float = 0.0
var _facing_left: bool = false
var _sprite_path: String = ""


func setup(monster_stats: MonsterStats, _hp_mult: float) -> void:
	stats = monster_stats
	max_hp = GameState.scaled_monster_hp(stats.hp)
	hp = max_hp
	_radius = Config.tiles(stats.radius_tiles)
	_speed = Config.tiles(Config.monster_speed_tiles(stats.radius_tiles))
	_has_bubble_shield = stats.has_bubble_shield or stats.name == "Demon"
	_is_undead = stats.name == "Undead"
	_slow_fire_cooldown = randf_range(1.2, Config.UNDEAD_SLOW_FIRE_INTERVAL_SEC)
	_anim_t = randf() * TAU
	match stats.name:
		"Goblin":
			_sprite_path = "res://assets/sprites/monsters/goblin.png"
		"Undead":
			_sprite_path = "res://assets/sprites/monsters/undead.png"
		"Ogre":
			_sprite_path = "res://assets/sprites/monsters/ogre.png"
		"Demon":
			_sprite_path = "res://assets/sprites/monsters/demon.png"
		_:
			_sprite_path = "res://assets/sprites/monsters/goblin.png"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_anim_t += delta * 10.0
	if _is_undead:
		_slow_fire_cooldown -= delta
	if _flash > 0.0:
		_flash -= delta
	queue_redraw()
	status.update(delta, self)
	if _dead:
		return
	if _shield_regen_left > 0.0:
		_shield_regen_left -= delta
		if _shield_regen_left <= 0.0:
			_has_bubble_shield = true
			AudioManager.play_at("demon_shield_regen", global_position)
	if status.is_stunned():
		velocity = Vector2.ZERO
		return

	var player: Player = Player.nearest_living_player(get_tree(), global_position)
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
			player.take_damage(stats.damage)
			_attack_cooldown = Config.MONSTER_ATTACK_COOLDOWN_SEC
	else:
		var dir: Vector2 = _world.flow_direction(global_position, player.global_position) if _world != null else to_player.normalized()
		velocity = dir * _speed * World.terrain_speed_mult(self) * status.speed_mult()
		if absf(velocity.x) > 8.0:
			_facing_left = velocity.x < 0.0
	move_and_slide()

	if _is_undead and _slow_fire_cooldown <= 0.0 and to_player.length() <= Config.tiles(Config.UNDEAD_SLOW_RANGE_TILES):
		_slow_fire_cooldown = Config.UNDEAD_SLOW_FIRE_INTERVAL_SEC
		_fire_slow_spell(player.global_position)


func _fire_slow_spell(target_pos: Vector2) -> void:
	AudioManager.play_at("undead_slow_cast", global_position)
	var p: Projectile = Config.projectile_scene().instantiate()
	var speed_px: float = Config.tiles(Config.UNDEAD_SLOW_BOLT_SPEED_TILES)
	p.setup(
		global_position.direction_to(target_pos),
		speed_px,
		0.0,
		false,
		Color.WHITE,
		Config.tiles(0.18),
		Config.tiles(Config.UNDEAD_SLOW_RANGE_TILES * 1.4),
		false,
		Projectile.ProjKind.INITIAL,
		null,
		false,
		{},
		Config.UNDEAD_SLOW_DURATION_SEC
	)
	p.global_position = global_position
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_parent()
	container.add_child(p)


func get_hit_radius() -> float:
	return _radius


func facing_left() -> bool:
	return _facing_left


## A guest's copy takes its state from the host.
func apply_net(new_hp: float, new_max_hp: float, flags: int) -> void:
	if new_hp < hp:
		_flash = 0.1
	else:
		_flash = 0.0
	hp = new_hp
	max_hp = new_max_hp
	_has_bubble_shield = flags & 1 != 0
	_facing_left = flags & 2 != 0
	queue_redraw()


func strip_shield() -> void:
	_has_bubble_shield = false
	_shield_regen_left = 0.0


func has_bubble_shield() -> bool:
	return _has_bubble_shield


func take_player_damage(amount: float, source: RunState) -> void:
	_damage_owner = source
	take_damage(amount)
	_damage_owner = null


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	if _has_bubble_shield:
		_has_bubble_shield = false
		_shield_regen_left = Config.DEMON_SHIELD_REGEN_SEC
		_flash = 0.15
		AudioManager.play_at("demon_shield_break", global_position)
		GameState.spawn_floating_text(global_position + Vector2(0, -_radius), "SHIELD BREAK", Color(0.45, 0.95, 1.0))
		queue_redraw()
		return
	hp -= amount
	_flash = 0.1
	GameState.spawn_floating_text(
		global_position + Vector2(randf_range(-8, 8), -_radius),
		"-%d" % maxi(1, int(round(amount))),
		Color(1.0, 0.92, 0.45)
	)
	queue_redraw()
	if hp <= 0.0:
		_dead = true
		killing_player = _damage_owner
		AudioManager.play_at(stats.name.to_lower() + "_death", global_position)
		died.emit(stats.gold, global_position)
		queue_free()


func _draw() -> void:
	if stats == null:
		return
	# Flat ground shadow directly beneath the monster's feet
	Config.draw_ground_shadow(self, _radius, _radius * 0.72, 0.34)

	var tex: Texture2D = Config.get_tex(_sprite_path)
	var bob: float = sin(_anim_t) * 1.2 if velocity.length_squared() > 4.0 else sin(_anim_t * 0.35) * 0.4
	if tex != null:
		var mod_col: Color = Color(2.5, 2.5, 2.5, 1.0) if _flash > 0.0 else Color.WHITE
		Config.draw_sprite_centered(
			self,
			tex,
			Vector2(0, bob),
			Vector2(_radius * 2.35, _radius * 2.35),
			mod_col,
			_facing_left
		)
	else:
		var body_color: Color = Color.WHITE if _flash > 0.0 else stats.color
		draw_circle(Vector2.ZERO, _radius, body_color)
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 24, body_color.darkened(0.5), 1.5)
		draw_circle(Vector2(-_radius * 0.35, -_radius * 0.2), _radius * 0.15, Color.BLACK)
		draw_circle(Vector2(_radius * 0.35, -_radius * 0.2), _radius * 0.15, Color.BLACK)

	# Demon bubble shield centered on the (0, 0) hitbox
	if _has_bubble_shield:
		var sr: float = _radius * 1.38
		draw_circle(Vector2.ZERO, sr, Color(0.25, 0.85, 1.0, 0.22))
		draw_arc(Vector2.ZERO, sr, 0.0, TAU, 28, Color(0.45, 0.95, 1.0, 0.92), 2.0)
	# HP bar (only once damaged)
	if hp < max_hp:
		var w: float = _radius * 2.1
		var top: Vector2 = Vector2(-w * 0.5, -_radius - 10.0)
		draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 5)), Color(0, 0, 0, 0.72))
		draw_rect(Rect2(top, Vector2(w * maxf(hp, 0.0) / max_hp, 3)), Color(0.95, 0.22, 0.28))
	status.draw(self, _radius)

