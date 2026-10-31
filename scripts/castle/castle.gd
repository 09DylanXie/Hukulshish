class_name Castle
extends Area2D
## The kingdom castle at the map center (§5). No HP. Walk into it to open the upgrade menu.

signal player_entered(player: Player)

var _size: float = Config.tiles(Config.CASTLE_SIZE_TILES)
## The player spawns inside the castle; only trigger after they've left once.
var _armed_players: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 0
	collision_mask = Config.LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(_size, _size)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	z_index = -1


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Player and _armed_players.has(body.get_instance_id()) and not (body as Player).is_dead():
		player_entered.emit(body as Player)


func _on_body_exited(body: Node) -> void:
	if body is Player:
		_armed_players[body.get_instance_id()] = true


func _draw() -> void:
	var h: float = _size * 0.5
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.5)
	# Sanctuary healing aura beneath castle
	draw_circle(Vector2.ZERO, h * 1.28, Color(0.25, 0.85, 0.72, 0.10 + 0.06 * pulse))
	draw_arc(Vector2.ZERO, h * 1.26, 0.0, TAU, 48, Color(0.95, 0.82, 0.35, 0.45 + 0.25 * pulse), 2.0)

	var tex: Texture2D = Config.get_tex("res://assets/sprites/world/castle.png")
	if tex != null:
		# Soft ground shadow
		draw_rect(Rect2(Vector2(-h * 1.02, -h * 0.95), Vector2(_size * 1.04, _size * 1.04)), Color(0, 0, 0, 0.45))
		Config.draw_sprite_centered(self, tex, Vector2.ZERO, Vector2(_size * 1.18, _size * 1.18))
		return

	var stone := Color(0.55, 0.55, 0.6)
	var dark := Color(0.35, 0.35, 0.42)
	draw_rect(Rect2(-h, -h, _size, _size), Color(0.45, 0.42, 0.38))
	var t: float = Config.tiles(0.35)
	draw_rect(Rect2(-h, -h, _size, t), stone)
	draw_rect(Rect2(-h, h - t, _size, t), stone)
	draw_rect(Rect2(-h, -h, t, _size), stone)
	draw_rect(Rect2(h - t, -h, t, _size), stone)
	var tower: float = Config.tiles(0.6)
	for c in [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h)]:
		draw_circle(c, tower, dark)
		draw_circle(c, tower * 0.6, stone)
	draw_line(Vector2(0, -h * 0.2), Vector2(0, -h * 0.75), Color(0.3, 0.2, 0.1), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -h * 0.75), Vector2(h * 0.35, -h * 0.62), Vector2(0, -h * 0.5)]), Color(0.9, 0.75, 0.15))


