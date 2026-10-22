class_name Player
extends CharacterBody2D
## The mage Hukulshish. WASD / virtual joystick movement; spells fire automatically (SpellCaster child).

signal hp_changed(hp: int, max_hp: int)
signal died

const SpellCasterScript: GDScript = preload("res://scripts/spells/spell_caster.gd")

var max_hp: int = Config.PLAYER_MAX_HP
var hp: int = Config.PLAYER_MAX_HP
## Map area the player is kept inside. Set by Game; empty = unlimited.
var bounds: Rect2 = Rect2()

var _iframes: float = 0.0
var _dead: bool = false
var _radius: float = Config.tiles(Config.PLAYER_RADIUS_TILES)
var _facing: Vector2 = Vector2.RIGHT


func _ready() -> void:
	add_to_group("player")
	collision_layer = Config.LAYER_PLAYER
	collision_mask = Config.LAYER_WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)

	var camera := Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = true
	if bounds.has_area():
		camera.limit_left = int(bounds.position.x)
		camera.limit_top = int(bounds.position.y)
		camera.limit_right = int(bounds.end.x)
		camera.limit_bottom = int(bounds.end.y)
	add_child(camera)

	var caster: Node2D = SpellCasterScript.new()
	caster.name = "SpellCaster"
	add_child(caster)

	hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		_facing = input.normalized()
	velocity = input * Config.tiles(Config.PLAYER_SPEED_TILES)
	move_and_slide()
	if bounds.has_area():
		global_position = global_position.clamp(bounds.position + Vector2.ONE * _radius, bounds.end - Vector2.ONE * _radius)

	if _iframes > 0.0:
		_iframes -= delta
		modulate.a = 0.4 if int(_iframes * 20.0) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0
	queue_redraw()


func take_damage(amount: float) -> void:
	if _dead or _iframes > 0.0:
		return
	hp = maxi(0, hp - int(round(amount)))
	_iframes = Config.PLAYER_IFRAMES_SEC
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_dead = true
		died.emit()
		GameState.on_player_died()


## Heals the player up to 7/10 of max HP when entering the castle shop (§5).
## Never reduces HP if the player is already above 7/10.
func heal_at_castle() -> void:
	if _dead:
		return
	var cap: int = int(floor(max_hp * Config.CASTLE_HEAL_FRACTION))
	if hp < cap:
		hp = cap
		hp_changed.emit(hp, max_hp)


func is_dead() -> bool:
	return _dead


func _draw() -> void:
	# Robe
	draw_circle(Vector2.ZERO, _radius, Color(0.25, 0.3, 0.85))
	# Hat
	var hat := PackedVector2Array([
		Vector2(-_radius * 0.9, -_radius * 0.3),
		Vector2(_radius * 0.9, -_radius * 0.3),
		Vector2(_radius * 0.2, -_radius * 1.8),
	])
	draw_colored_polygon(hat, Color(0.45, 0.2, 0.75))
	# Facing indicator
	draw_circle(_facing * _radius * 0.6, _radius * 0.25, Color(1, 0.95, 0.6))
