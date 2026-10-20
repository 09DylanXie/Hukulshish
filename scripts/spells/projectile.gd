class_name Projectile
extends Area2D
## A straight-line projectile. Used for player spells and the boss bolt.
## Call setup() before adding it to the tree.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 32.0
var damage: int = 1
var from_player: bool = true
var color: Color = Color.WHITE
var radius: float = 6.0
var lifetime: float = Config.SPELL_LIFETIME_SEC

var _spent: bool = false


func setup(dir: Vector2, speed_px: float, dmg: int, is_player: bool, col: Color, radius_px: float) -> void:
	direction = dir.normalized()
	speed = speed_px
	damage = dmg
	from_player = is_player
	color = col
	radius = radius_px


func _ready() -> void:
	monitorable = false
	collision_layer = Config.LAYER_PLAYER_PROJECTILES if from_player else Config.LAYER_ENEMY_PROJECTILES
	collision_mask = (Config.LAYER_ENEMIES | Config.LAYER_NESTS) if from_player else Config.LAYER_PLAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	if body.has_method("take_damage"):
		_spent = true
		body.take_damage(damage)
		queue_free()


func _draw() -> void:
	# Little comet: glow + core + tail (drawn along +X, node is rotated to face direction).
	draw_circle(Vector2.ZERO, radius * 1.6, Color(color, 0.3))
	draw_circle(Vector2.ZERO, radius, color)
	draw_line(Vector2.ZERO, Vector2(-radius * 3.0, 0), Color(color, 0.5), radius * 0.8)
