class_name World
extends Node2D
## Generated prototype map: a square field centered on (0, 0) with border walls.
## Set `size_in_tiles` before adding to the tree.

var size_in_tiles: int = 60

var rect: Rect2:
	get:
		var s: float = Config.tiles(size_in_tiles)
		return Rect2(-s * 0.5, -s * 0.5, s, s)


func _ready() -> void:
	z_index = -10
	_build_walls()


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = Config.LAYER_WORLD
	walls.collision_mask = 0
	var r: Rect2 = rect
	var t: float = Config.tiles(1)
	var pieces: Array[Rect2] = [
		Rect2(r.position.x - t, r.position.y - t, r.size.x + 2 * t, t),  # top
		Rect2(r.position.x - t, r.end.y, r.size.x + 2 * t, t),  # bottom
		Rect2(r.position.x - t, r.position.y, t, r.size.y),  # left
		Rect2(r.end.x, r.position.y, t, r.size.y),  # right
	]
	for p in pieces:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = p.size
		shape.shape = box
		shape.position = p.get_center()
		walls.add_child(shape)
	add_child(walls)


func _draw() -> void:
	var r: Rect2 = rect
	var tile: float = Config.tiles(1)
	draw_rect(r.grow(tile * 4), Color(0.08, 0.1, 0.08))
	draw_rect(r, Color(0.22, 0.42, 0.22))
	# Checker grass every 2 tiles
	var cell: float = tile * 2.0
	var cols: int = int(r.size.x / cell)
	var alt := Color(0.2, 0.39, 0.2)
	for x in cols:
		for y in cols:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(r.position + Vector2(x, y) * cell, Vector2(cell, cell)), alt)
	draw_rect(r, Color(0.35, 0.25, 0.15), false, 4.0)
