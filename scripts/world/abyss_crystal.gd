class_name AbyssCrystal
extends Area2D
## The large purple crystal at the Abyss's center (§6.10), an egg holding the Mega Boss.
## Walking up and touching it breaks it open.

signal shattered

var trigger_radius: float = Config.tiles(Config.CRYSTAL_TOUCH_RADIUS_TILES)

var _is_shattered: bool = false
var _shatter_t: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 0
	collision_mask = Config.LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = trigger_radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not _is_shattered:
		return
	_shatter_t += delta
	if _shatter_t >= Config.CRYSTAL_SHATTER_SEC:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _is_shattered or not body is Player:
		return
	# Physics can report a player who was just moved here from a layer's old position.
	if body.global_position.distance_to(global_position) > trigger_radius + Config.tiles(Config.PLAYER_RADIUS_TILES):
		return
	_is_shattered = true
	AudioManager.play("crystal_shatter")
	GameState.request_shake(12.0, 0.5)
	shattered.emit()


func _draw() -> void:
	if _is_shattered:
		_draw_shards()
		return
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.2)
	draw_circle(Vector2.ZERO, Config.tiles(2.6 + 0.3 * pulse), Color(0.55, 0.2, 0.95, 0.14))
	var tex: Texture2D = Config.get_tex("res://assets/sprites/world/crystal.png")
	if tex != null:
		draw_texture(tex, Vector2(-tex.get_width() * 0.5, -tex.get_height() * 0.72))


func _draw_shards() -> void:
	var t: float = _shatter_t / Config.CRYSTAL_SHATTER_SEC
	var fade: float = 1.0 - t
	draw_circle(Vector2.ZERO, Config.tiles(1.0 + 3.0 * t), Color(0.85, 0.65, 1.0, 0.6 * fade))
	for i in 14:
		var angle: float = float(i) * TAU / 14.0 + float(i % 3) * 0.2
		var tip: Vector2 = Vector2.from_angle(angle) * Config.tiles(1.0 + (3.0 + float(i % 4)) * t)
		var side: Vector2 = Vector2.from_angle(angle + PI * 0.5) * 3.0
		var shard := PackedVector2Array([tip * 1.15, tip + side, tip - side])
		draw_colored_polygon(shard, Color(0.72, 0.42, 1.0, fade))
