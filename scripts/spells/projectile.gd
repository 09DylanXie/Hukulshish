class_name Projectile
extends Area2D
## A straight-line projectile. Used for player spells and the boss bolt.
## Uses swept-segment hit detection against targets so projectiles never pass through nests or fast enemies.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 192.0
var damage: float = 1.0
var from_player: bool = true
var color: Color = Color.WHITE
var radius: float = 6.0
var max_distance: float = 320.0

var _traveled: float = 0.0
var _spent: bool = false


func setup(dir: Vector2, speed_px: float, dmg: float, is_player: bool, col: Color, radius_px: float, max_distance_px: float = 320.0) -> void:
	direction = dir.normalized()
	speed = speed_px
	damage = dmg
	from_player = is_player
	color = col
	radius = radius_px
	max_distance = max_distance_px


func _ready() -> void:
	monitoring = true
	monitorable = true
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
	if _spent:
		return
	var prev_pos: Vector2 = global_position
	var step: float = speed * delta
	position += direction * step
	_traveled += step

	# Swept-segment hit check guarantees hits on StaticBody2D nests, monsters, and bosses.
	_check_swept_hits(prev_pos, global_position)
	if _spent:
		return

	if max_distance > 0.0 and _traveled >= max_distance:
		queue_free()


func _check_swept_hits(from_pos: Vector2, to_pos: Vector2) -> void:
	if from_player:
		var best_node: Node2D = null
		var best_dist_sq: float = INF
		for node in get_tree().get_nodes_in_group("targets"):
			var target := node as Node2D
			if target == null or target.is_queued_for_deletion() or not target.has_method("take_damage"):
				continue
			var hit_r: float = float(target.call("get_hit_radius")) if target.has_method("get_hit_radius") else Config.tiles(0.5)
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target.global_position, from_pos, to_pos)
			if closest.distance_to(target.global_position) <= radius + hit_r:
				var d_sq: float = from_pos.distance_squared_to(target.global_position)
				if d_sq < best_dist_sq:
					best_dist_sq = d_sq
					best_node = target
		if best_node != null:
			_on_body_entered(best_node)
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and not player.is_queued_for_deletion() and player.has_method("take_damage"):
			var hit_r: float = Config.tiles(Config.PLAYER_RADIUS_TILES)
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(player.global_position, from_pos, to_pos)
			if closest.distance_to(player.global_position) <= radius + hit_r:
				_on_body_entered(player)


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
