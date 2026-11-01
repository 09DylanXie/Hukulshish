class_name Portal
extends Area2D
## One-way exit to the next layer (§6.6). Opens where the nest stood once the layer's boss is dead.
## It stays inactive for a moment after opening, so a player standing on the spot can collect the boss's drops.

signal entered(player: Player)

## A guest's copy, which only draws: the host decides who goes through.
var is_view: bool = false

var _radius: float = Config.tiles(Config.PORTAL_RADIUS_TILES)
var _arm_timer: float = Config.PORTAL_ARM_SEC
var _t: float = 0.0


func _ready() -> void:
	if is_view:
		monitoring = false
		_arm_timer = 0.0
		return
	collision_layer = 0
	collision_mask = Config.LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius * 0.7
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	AudioManager.play("portal_open")


func _physics_process(delta: float) -> void:
	_t += delta
	_arm_timer = maxf(0.0, _arm_timer - delta)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _arm_timer <= 0.0 and body is Player and not (body as Player).is_dead():
		entered.emit(body as Player)


func _draw() -> void:
	var open: float = 1.0 - _arm_timer / Config.PORTAL_ARM_SEC
	var r: float = _radius * (0.5 + 0.5 * open)
	var pulse: float = 1.0 + 0.05 * sin(_t * 4.0)
	draw_circle(Vector2.ZERO, r * 1.35 * pulse, Color(0.45, 0.2, 0.95, 0.18))
	draw_circle(Vector2.ZERO, r, Color(0.08, 0.03, 0.18, 0.95))
	draw_circle(Vector2.ZERO, r * 0.62, Color(0.3, 0.12, 0.72, 0.8))
	draw_circle(Vector2.ZERO, r * 0.3, Color(0.78, 0.62, 1.0, 0.9))
	for i in 3:
		var start: float = _t * 2.4 + float(i) * TAU / 3.0
		draw_arc(Vector2.ZERO, r * (0.55 + 0.2 * float(i)), start, start + TAU * 0.38, 20, Color(0.72, 0.5, 1.0, 0.85), 2.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.85, 0.72, 1.0, 0.9), 2.5)
