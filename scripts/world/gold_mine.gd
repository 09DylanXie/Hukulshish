class_name GoldMine
extends Area2D
## Produces 10 gold/sec up to a 500-gold cap (§6.8). Walk over it to collect stored gold.

var _stored: float = 0.0
var _radius: float = Config.tiles(1.1)
var _player_inside: bool = false
var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_t += delta
	var cap: float = float(GameState.gold_mine_cap())
	var rate: float = GameState.gold_mine_rate()
	_stored = minf(cap, _stored + rate * delta)
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
	collect()


func collect() -> int:
	var whole: int = int(floor(_stored))
	if whole > 0:
		_stored -= whole
		GameState.add_gold(whole)
		GameState.spawn_floating_text(global_position + Vector2(0, -_radius), "+%d Gold" % whole, Color(1.0, 0.88, 0.25))
		queue_redraw()
	return whole


func stored_gold() -> int:
	return int(floor(_stored))


func _draw() -> void:
	var ratio: float = clampf(_stored / float(maxi(1, GameState.gold_mine_cap())), 0.0, 1.0)
	# Warm golden aura beneath the mine that intensifies as gold accumulates
	draw_circle(Vector2.ZERO, _radius * (1.05 + 0.15 * ratio), Color(1.0, 0.82, 0.2, 0.10 + 0.22 * ratio))
	draw_arc(Vector2.ZERO, _radius * 1.02, 0.0, TAU, 36, Color(1.0, 0.85, 0.28, 0.35 + 0.45 * ratio), 1.8)

	var tex: Texture2D = Config.get_tex("res://assets/sprites/world/gold_mine.png")
	if tex != null:
		var tint: Color = Color(0.92, 0.92, 0.95).lerp(Color(1.08, 1.05, 0.88), ratio)
		Config.draw_sprite_centered(self, tex, Vector2.ZERO, Vector2(_radius * 2.15, _radius * 2.15), tint)
	else:
		draw_circle(Vector2.ZERO, _radius, Color(0.38, 0.35, 0.32))
		draw_circle(Vector2.ZERO, _radius * 0.78, Color(0.28, 0.25, 0.22))
		var gold_col := Color(0.98, 0.82, 0.18).lerp(Color(1.0, 0.95, 0.5), ratio)
		for offset in [Vector2(-0.35, -0.25), Vector2(0.3, -0.2), Vector2(0.0, 0.3), Vector2(-0.2, 0.15), Vector2(0.25, 0.25)]:
			draw_circle(offset * _radius, _radius * (0.14 + 0.08 * ratio), gold_col)

	# Storage bar + gold amount above the mine
	var w: float = _radius * 2.0
	var top := Vector2(-_radius, -_radius - 11.0)
	draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 7)), Color(0.05, 0.03, 0.08, 0.88))
	draw_rect(Rect2(top, Vector2(w * ratio, 5)), Color(1.0, 0.85, 0.18))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, top + Vector2(0, -3), "%dg" % int(floor(_stored)), HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(1.0, 0.92, 0.45))


