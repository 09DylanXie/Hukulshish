class_name ModPickup
extends Area2D
## A spell mod dropped by a destroyed nest. Walk over it to pick it up, then apply it at the castle.

var mod: SpellData

var _t: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Config.LAYER_PLAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Config.tiles(0.5)
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Player and mod != null:
		GameState.add_pending_mod(mod)
		queue_free()


func _draw() -> void:
	var col: Color = mod.color if mod != null else Color.WHITE
	var r: float = Config.tiles(0.4) * (1.0 + 0.15 * sin(_t * 4.0))
	draw_circle(Vector2.ZERO, r * 1.6, Color(col, 0.25))
	var diamond := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.7, 0), Vector2(0, r), Vector2(-r * 0.7, 0)])
	draw_colored_polygon(diamond, col)
