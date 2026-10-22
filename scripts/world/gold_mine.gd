class_name GoldMine
extends Area2D
## Produces 10 gold/sec up to a 500-gold cap (§6.8). Walk over it to collect stored gold.

var _stored: float = 0.0
var _radius: float = Config.tiles(1.1)
var _player_inside: bool = false


func _ready() -> void:
	add_to_group("gold_mines")
	collision_layer = 0
	collision_mask = Config.LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	_stored = minf(float(Config.GOLD_MINE_CAP), _stored + Config.GOLD_MINE_RATE * delta)
	if _player_inside:
		_collect()
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_inside = true
		_collect()


func _on_body_exited(body: Node) -> void:
	if body is Player:
		_player_inside = false


func _collect() -> void:
	var whole: int = int(floor(_stored))
	if whole > 0:
		_stored -= whole
		GameState.add_gold(whole)


func stored_gold() -> int:
	return int(floor(_stored))


func _draw() -> void:
	# Rocky base
	draw_circle(Vector2.ZERO, _radius, Color(0.38, 0.35, 0.32))
	draw_circle(Vector2.ZERO, _radius * 0.78, Color(0.28, 0.25, 0.22))
	# Gold nuggets / veins (brighter as storage fills)
	var ratio: float = clampf(_stored / float(Config.GOLD_MINE_CAP), 0.0, 1.0)
	var gold_col := Color(0.98, 0.82, 0.18).lerp(Color(1.0, 0.95, 0.5), ratio)
	for offset in [Vector2(-0.35, -0.25), Vector2(0.3, -0.2), Vector2(0.0, 0.3), Vector2(-0.2, 0.15), Vector2(0.25, 0.25)]:
		draw_circle(offset * _radius, _radius * (0.14 + 0.08 * ratio), gold_col)
	# Storage bar above the mine
	var w: float = _radius * 2.0
	var top := Vector2(-_radius, -_radius - 8.0)
	draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(top, Vector2(w * ratio, 4)), Color(1.0, 0.85, 0.15))
