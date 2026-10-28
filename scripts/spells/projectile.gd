class_name Projectile
extends Area2D
## A projectile used for player spells (initial, split, sniper) and the boss bolt.
## Uses swept-segment hit detection against targets so projectiles never pass through nests or fast enemies.

enum ProjKind {
	INITIAL,
	SPLIT,
	SNIPER,
}

const FireZoneScript: GDScript = preload("res://scripts/spells/fire_zone.gd")

var direction: Vector2 = Vector2.RIGHT
var speed: float = 192.0
var damage: float = 1.0
var from_player: bool = true
var color: Color = Color.WHITE
var radius: float = 6.0
var max_distance: float = 320.0
var homing: bool = false
var proj_kind: ProjKind = ProjKind.INITIAL
## Target to ignore (so split/sniper projectiles spawned on impact don't immediately re-hit the same enemy).
var ignore_target: Node2D = null

var _traveled: float = 0.0
var _spent: bool = false


func setup(
	dir: Vector2,
	speed_px: float,
	dmg: float,
	is_player: bool,
	col: Color,
	radius_px: float,
	max_distance_px: float = 320.0,
	is_homing: bool = false,
	kind: ProjKind = ProjKind.INITIAL,
	ignored: Node2D = null
) -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	speed = speed_px
	damage = dmg
	from_player = is_player
	color = col
	radius = radius_px
	max_distance = max_distance_px
	homing = is_homing
	proj_kind = kind
	ignore_target = ignored


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
	if from_player and ((homing and GameState.is_homing_active()) or proj_kind == ProjKind.SNIPER):
		var target: Node2D = _find_homing_target()
		if target != null:
			var to_target: Vector2 = global_position.direction_to(target.global_position)
			if to_target != Vector2.ZERO:
				if proj_kind == ProjKind.SNIPER or global_position.distance_to(target.global_position) <= Config.tiles(2.5):
					direction = to_target
				else:
					var new_angle: float = rotate_toward(direction.angle(), to_target.angle(), Config.HOMING_TURN_SPEED * delta)
					direction = Vector2.from_angle(new_angle)
				rotation = direction.angle()
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


func _find_homing_target() -> Node2D:
	var best: Node2D = null
	var best_score: float = INF
	for node in get_tree().get_nodes_in_group("targets"):
		var target := node as Node2D
		if target == null or target == ignore_target or target.is_queued_for_deletion() or not target.has_method("take_damage"):
			continue
		var d: float = global_position.distance_to(target.global_position)
		# Prefer active enemies (monsters & bosses) over static nests when nearby.
		var score: float = d if not target.is_in_group("nests") else d + Config.tiles(1.5)
		if score < best_score:
			best_score = score
			best = target
	return best


func _check_swept_hits(from_pos: Vector2, to_pos: Vector2) -> void:
	if from_player:
		var best_node: Node2D = null
		var best_dist_sq: float = INF
		for node in get_tree().get_nodes_in_group("targets"):
			var target := node as Node2D
			if target == null or target == ignore_target or target.is_queued_for_deletion() or not target.has_method("take_damage"):
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
	if _spent or body == ignore_target:
		return
	if body.has_method("take_damage"):
		_spent = true
		body.take_damage(damage)
		if from_player and body is Node2D:
			_apply_augmentations(body as Node2D)
		queue_free()


func _apply_augmentations(hit_target: Node2D) -> void:
	# Sniper shots do not apply any other augmentations upon impact and do not repeat.
	if proj_kind == ProjKind.SNIPER:
		return

	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_parent()

	if proj_kind == ProjKind.INITIAL:
		# 1. Sniper: only on initial first impact of player spell on enemy.
		if GameState.aug_level("sniper") > 0:
			_spawn_sniper_shot(container, hit_target)

		# 2. Split Spell: splits into 2/3/4 projectiles at 30° spacing, each doing 1/2 damage.
		var splits: int = GameState.split_count()
		if splits > 0:
			_spawn_split_shots(container, hit_target, splits)
		elif GameState.aug_level("bomb") > 0:
			# If Split is not unlocked, Bombspell still triggers on the spell's final impact.
			_spawn_bomb_zone(container)
	elif proj_kind == ProjKind.SPLIT:
		# Bombspell applies on final split spells (not initial).
		if GameState.aug_level("bomb") > 0:
			_spawn_bomb_zone(container)


func _spawn_split_shots(container: Node, hit_target: Node2D, count: int) -> void:
	var step_rad: float = deg_to_rad(Config.SPLIT_ANGLE_DEG)
	var base_angle: float = direction.angle()
	var this_scene: PackedScene = load("res://scenes/spells/Projectile.tscn")
	for i in count:
		var angle_offset: float = (float(i) - float(count - 1) * 0.5) * step_rad
		var split_dir: Vector2 = Vector2.from_angle(base_angle + angle_offset)
		var p: Projectile = this_scene.instantiate()
		p.setup(
			split_dir,
			speed,
			damage * Config.SPLIT_DAMAGE_MULT,
			true,
			color.lightened(0.15),
			radius * 0.85,
			max_distance,
			GameState.is_homing_active(),
			ProjKind.SPLIT,
			hit_target
		)
		p.global_position = global_position
		container.call_deferred("add_child", p)


func _spawn_sniper_shot(container: Node, hit_target: Node2D) -> void:
	var this_scene: PackedScene = load("res://scenes/spells/Projectile.tscn")
	var p: Projectile = this_scene.instantiate()
	var sniper_dir: Vector2 = direction
	# Aim directly at the nearest other enemy if one exists.
	var prev_ignore: Node2D = ignore_target
	ignore_target = hit_target
	var next_target: Node2D = _find_homing_target()
	ignore_target = prev_ignore
	if next_target != null:
		sniper_dir = global_position.direction_to(next_target.global_position)
	p.setup(
		sniper_dir,
		speed * Config.SNIPER_SPEED_MULT,
		damage * GameState.sniper_damage_mult(),
		true,
		Color(1.0, 0.95, 0.25),
		radius * 0.9,
		max_distance * 1.5,
		true,
		ProjKind.SNIPER,
		hit_target
	)
	p.global_position = global_position
	container.call_deferred("add_child", p)


func _spawn_bomb_zone(container: Node) -> void:
	var zone: Node2D = FireZoneScript.new()
	zone.call("setup", GameState.bomb_dps(), Config.BOMB_DURATION_SEC, Config.tiles(Config.BOMB_RADIUS_TILES))
	zone.global_position = global_position
	container.call_deferred("add_child", zone)


func _draw() -> void:
	# Little comet: glow + core + tail (drawn along +X, node is rotated to face direction).
	draw_circle(Vector2.ZERO, radius * 1.6, Color(color, 0.3))
	draw_circle(Vector2.ZERO, radius, color)
	var tail_len: float = radius * (5.0 if proj_kind == ProjKind.SNIPER else 3.0)
	draw_line(Vector2.ZERO, Vector2(-tail_len, 0), Color(color, 0.5), radius * 0.8)
