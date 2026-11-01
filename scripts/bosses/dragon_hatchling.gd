class_name DragonHatchling
extends CharacterBody2D
## A small dragon hatched during Dragon's Breath (§6.10). It flies over walls, keeps its distance,
## and spits little fireballs. Its shield takes damage before its HP, and it drops nothing.

var max_hp: float = Config.HATCHLING_HP
var hp: float = Config.HATCHLING_HP
var shield: float = Config.HATCHLING_SHIELD_HP
var status: EnemyStatus = EnemyStatus.new()

var _radius: float = Config.tiles(Config.HATCHLING_RADIUS_TILES)
var _fire_timer: float = randf_range(0.5, Config.HATCHLING_FIRE_INTERVAL_SEC)
var _facing_left: bool = false
var _flash: float = 0.0
var _anim_t: float = randf() * TAU
var _dead: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("targets")
	add_to_group("hatchlings")
	collision_layer = Config.LAYER_ENEMIES
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	_anim_t += delta * 6.0
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()
	status.update(delta, self)
	if _dead or status.is_stunned():
		return
	var player: Player = Player.nearest_living_player(get_tree(), global_position)
	if player == null:
		return
	var to_player: Vector2 = player.global_position - global_position
	_facing_left = to_player.x < 0.0
	if to_player.length() > Config.tiles(Config.HATCHLING_KEEP_AWAY_TILES):
		velocity = to_player.normalized() * Config.tiles(Config.HATCHLING_SPEED_TILES) * status.speed_mult()
		move_and_slide()
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = Config.HATCHLING_FIRE_INTERVAL_SEC
		_spit_fireball(player.global_position)


func _spit_fireball(target_pos: Vector2) -> void:
	AudioManager.play_at("boss_shot", global_position)
	var p: Projectile = Config.projectile_scene().instantiate()
	p.setup(global_position.direction_to(target_pos), Config.tiles(Config.HATCHLING_BOLT_SPEED_TILES), Config.HATCHLING_BOLT_DAMAGE, false,
		Color(1.0, 0.5, 0.1), Config.tiles(Config.HATCHLING_BOLT_RADIUS_TILES), Config.tiles(Config.HATCHLING_BOLT_RANGE_TILES))
	p.global_position = global_position
	get_parent().add_child(p)


func get_hit_radius() -> float:
	return _radius


func take_player_damage(amount: float, _source: RunState) -> void:
	take_damage(amount)


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	_flash = 0.1
	AudioManager.play_at("boss_hit", global_position)
	GameState.spawn_floating_text(
		global_position + Vector2(randf_range(-10, 10), -_radius),
		"-%d" % maxi(1, int(round(amount))),
		Color(0.45, 0.92, 1.0) if shield > 0.0 else Color(1.0, 0.6, 0.3)
	)
	if shield > 0.0:
		var absorbed: float = minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		_dead = true
		AudioManager.play_at("demon_death", global_position)
		queue_free()


## Abyssal Corruption goes straight through the shield.
func strip_shield() -> void:
	shield = 0.0


func facing_left() -> bool:
	return _facing_left


## A guest's copy takes its state from the host.
func apply_net(new_hp: float, new_shield: float, is_facing_left: bool) -> void:
	_flash = 0.1 if new_hp + new_shield < hp + shield else _flash
	hp = new_hp
	shield = new_shield
	_facing_left = is_facing_left
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, _radius * 1.6), _radius * 0.5, Color(0, 0, 0, 0.3))
	var tex: Texture2D = Config.get_tex("res://assets/sprites/bosses/dragon_hatchling.png")
	var bob: float = sin(_anim_t) * 2.0
	var mod_col: Color = Color(2.4, 2.4, 2.4, 1.0) if _flash > 0.0 else Color.WHITE
	Config.draw_sprite_centered(self, tex, Vector2(0, bob), Vector2(_radius * 3.0, _radius * 2.6), mod_col, _facing_left)
	var w: float = _radius * 2.2
	var top: Vector2 = Vector2(-w * 0.5, -_radius * 1.5 - 8.0)
	draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 5)), Color(0, 0, 0, 0.82))
	draw_rect(Rect2(top, Vector2(w * maxf(hp, 0.0) / max_hp, 3)), Color(1.0, 0.35, 0.15))
	if shield > 0.0:
		draw_rect(Rect2(top + Vector2(0, -4), Vector2(w * shield / Config.HATCHLING_SHIELD_HP, 3)), Color(0.25, 0.85, 1.0))
		draw_arc(Vector2.ZERO, _radius * 1.25, 0.0, TAU, 24, Color(0.35, 0.9, 1.0, 0.7), 1.5)
	status.draw(self, _radius)
