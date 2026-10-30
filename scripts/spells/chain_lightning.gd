extends Node2D
## Brief visual lightning bolt drawn between two positions when Split Spell Lv 3 triggers Chain Lightning.

var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var _lifetime: float = 0.25
var _elapsed: float = 0.0
var _points: PackedVector2Array = PackedVector2Array()


func setup(start_world: Vector2, end_world: Vector2) -> void:
	from_pos = start_world
	to_pos = end_world
	global_position = Vector2.ZERO
	_rebuild_jagged_points()


func _rebuild_jagged_points() -> void:
	_points.clear()
	_points.append(from_pos)
	var diff: Vector2 = to_pos - from_pos
	var perp: Vector2 = Vector2(-diff.y, diff.x).normalized()
	var segments: int = 6
	for i in range(1, segments):
		var t: float = float(i) / float(segments)
		var base_pt: Vector2 = from_pos.lerp(to_pos, t)
		var jitter: float = randf_range(-10.0, 10.0)
		_points.append(base_pt + perp * jitter)
	_points.append(to_pos)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return
	var alpha: float = clampf(1.0 - (_elapsed / _lifetime), 0.0, 1.0)
	draw_polyline(_points, Color(0.35, 0.85, 1.0, alpha * 0.55), 6.0)
	draw_polyline(_points, Color(0.95, 1.0, 0.55, alpha), 2.5)
	draw_circle(from_pos, 6.0, Color(0.6, 0.95, 1.0, alpha * 0.8))
	draw_circle(to_pos, 6.0, Color(0.6, 0.95, 1.0, alpha * 0.8))

