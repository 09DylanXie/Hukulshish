class_name FireLine
extends Node2D
## The dragon's attack (§6.10). A line glows on the ground as a warning, then fire engulfs it.
## Fire must break a shield before it can touch HP.

signal finished

var length: float = Config.tiles(Config.BASE_SPELL.range_tiles)
var width: float = Config.tiles(Config.DRAGON_FIRE_WIDTH_TILES)

var _direction: Vector2 = Vector2.RIGHT
var _warning_left: float = Config.DRAGON_FIRE_WARNING_SEC
var _burn_left: float = Config.DRAGON_FIRE_BURN_SEC
var _tick_left: float = 0.0
var _t: float = 0.0


## Both are fixed here, so the player can step out of the line once it lights up.
func setup(start: Vector2, direction: Vector2) -> void:
	position = start
	_direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
	rotation = _direction.angle()


func _ready() -> void:
	z_index = -1
	AudioManager.play_at("fire_line_warn", global_position)


func is_burning() -> bool:
	return _warning_left <= 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not is_burning():
		_warning_left -= delta
		if is_burning():
			AudioManager.play_at("fire_line_burn", global_position)
		return
	_burn_left -= delta
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left += Config.DRAGON_FIRE_TICK_SEC
		_burn_targets()
	if _burn_left <= 0.0:
		finished.emit()
		queue_free()


func _burn_targets() -> void:
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player: Player = node as Player
		if player != null and _touches(player):
			player.take_fire_tick()
	for node: Node in get_tree().get_nodes_in_group("doppelgangers"):
		if _touches(node as Node2D):
			node.call("take_damage", Config.DRAGON_FIRE_HP_DAMAGE)


func _touches(target: Node2D) -> bool:
	var end: Vector2 = global_position + _direction * length
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target.global_position, global_position, end)
	return closest.distance_to(target.global_position) <= width * 0.5 + Config.tiles(Config.PLAYER_RADIUS_TILES)


func _draw() -> void:
	var half: float = width * 0.5
	if not is_burning():
		var charge: float = 1.0 - _warning_left / Config.DRAGON_FIRE_WARNING_SEC
		var pulse: float = 0.5 + 0.5 * sin(_t * (6.0 + charge * 14.0))
		draw_rect(Rect2(0.0, -half, length, width), Color(1.0, 0.25, 0.1, 0.2 + 0.35 * charge * pulse + 0.15 * charge))
		draw_line(Vector2(0.0, -half), Vector2(length, -half), Color(1.0, 0.55, 0.2, 0.8), 1.0)
		draw_line(Vector2(0.0, half), Vector2(length, half), Color(1.0, 0.55, 0.2, 0.8), 1.0)
		return
	draw_rect(Rect2(0.0, -half * 1.6, length, width * 1.6), Color(0.95, 0.25, 0.05, 0.55))
	var step: float = Config.tiles(0.5)
	var x: float = 0.0
	var i: int = 0
	while x < length:
		var flicker: float = 0.75 + 0.25 * sin(_t * 18.0 + float(i) * 1.7)
		draw_circle(Vector2(x, 0.0), width * 1.1 * flicker, Color(1.0, 0.5, 0.1, 0.85))
		draw_circle(Vector2(x, 0.0), width * 0.6 * flicker, Color(1.0, 0.88, 0.4, 0.95))
		x += step
		i += 1
