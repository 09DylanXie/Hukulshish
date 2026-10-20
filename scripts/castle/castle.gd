class_name Castle
extends Area2D
## The kingdom castle at the map center (§5). No HP. Walk into it to open the upgrade menu.

signal player_entered

var _size: float = Config.tiles(Config.CASTLE_SIZE_TILES)
## The player spawns inside the castle; only trigger after they've left once.
var _armed: bool = false


func _ready() -> void:
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


func _on_body_entered(body: Node) -> void:
	if body is Player and _armed:
		player_entered.emit()


func _on_body_exited(body: Node) -> void:
	if body is Player:
		_armed = true


func _draw() -> void:
	var h: float = _size * 0.5
	var stone := Color(0.55, 0.55, 0.6)
	var dark := Color(0.35, 0.35, 0.42)
	# Courtyard floor
	draw_rect(Rect2(-h, -h, _size, _size), Color(0.45, 0.42, 0.38))
	# Walls
	var t: float = Config.tiles(0.35)
	draw_rect(Rect2(-h, -h, _size, t), stone)
	draw_rect(Rect2(-h, h - t, _size, t), stone)
	draw_rect(Rect2(-h, -h, t, _size), stone)
	draw_rect(Rect2(h - t, -h, t, _size), stone)
	# Corner towers
	var tower: float = Config.tiles(0.6)
	for c in [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h)]:
		draw_circle(c, tower, dark)
		draw_circle(c, tower * 0.6, stone)
	# Banner
	draw_line(Vector2(0, -h * 0.2), Vector2(0, -h * 0.75), Color(0.3, 0.2, 0.1), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -h * 0.75), Vector2(h * 0.35, -h * 0.62), Vector2(0, -h * 0.5)]), Color(0.9, 0.75, 0.15))
