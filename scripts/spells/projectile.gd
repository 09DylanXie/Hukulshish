class_name Projectile
extends Area2D
## A projectile used for player spells (initial, split, sniper), boss bolts, and Undead slow bolts.
## Uses swept-segment hit detection against targets so projectiles never pass through nests or fast enemies.

enum ProjKind {
	INITIAL,
	SPLIT,
	SNIPER,
}

const FireZoneScript: GDScript = preload("res://scripts/spells/fire_zone.gd")
const ChainLightningScript: GDScript = preload("res://scripts/spells/chain_lightning.gd")
const TRAIL_DURATION_SEC: float = 0.14

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
## Whether this player projectile triggers augmentations (true for Base Spell & Mega Boss Spell).
var uses_augments: bool = true
## Copied augment levels (used by Mega Boss Spell; empty = read live GameState.aug_levels).
var aug_override: Dictionary = {}
## Slow duration in seconds (used by Undead 0-damage slow spell).
var slow_duration: float = 0.0
## How many times this projectile has already split (0 = initial cast, 1..3 = split generations).
var split_depth: int = 0

var _traveled: float = 0.0
var _spent: bool = false
var _trail_pts: PackedVector2Array = PackedVector2Array()
var _trail_ages: PackedFloat32Array = PackedFloat32Array()
var _glint_t: float = 0.0


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
	ignored: Node2D = null,
	can_use_augments: bool = true,
	copied_augs: Dictionary = {},
	slow_sec: float = 0.0,
	split_gen: int = 0
) -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	speed = speed_px
	damage = dmg
	from_player = is_player
	color = col
	radius = radius_px
	max_distance = max_distance_px
	# Homing does not work on split shots.
	homing = is_homing and kind != ProjKind.SPLIT
	proj_kind = kind
	ignore_target = ignored
	uses_augments = can_use_augments
	aug_override = copied_augs
	slow_duration = slow_sec
	split_depth = split_gen


func _aug_lvl(id: String) -> int:
	if not uses_augments:
		return 0
	var live: int = GameState.aug_level(id)
	var snap: int = int(aug_override.get(id, 0))
	return maxi(live, snap)


func _bomb_dps_for_proj() -> float:
	var lvl: int = _aug_lvl("bomb")
	if lvl <= 0:
		return Config.BOMB_BASE_DPS
	return Config.BOMB_BASE_DPS + Config.BOMB_DPS_STEP * (lvl - 1)


func _sniper_mult_for_proj() -> float:
	var lvl: int = _aug_lvl("sniper")
	if lvl <= 0:
		return 0.0
	return Config.SNIPER_BASE_DAMAGE_MULT + Config.SNIPER_DAMAGE_STEP * (lvl - 1)


func _max_split_depth_for_proj() -> int:
	return _aug_lvl("split")


func _can_pierce_walls() -> bool:
	return from_player and GameState.wall_pierce_unlocked


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = Config.LAYER_PLAYER_PROJECTILES if from_player else Config.LAYER_ENEMY_PROJECTILES
	if from_player:
		# Sniper shots only target monsters and bosses, never nests.
		collision_mask = Config.LAYER_ENEMIES if proj_kind == ProjKind.SNIPER else (Config.LAYER_ENEMIES | Config.LAYER_NESTS)
	else:
		collision_mask = Config.LAYER_PLAYER
	if not _can_pierce_walls():
		collision_mask |= Config.LAYER_WORLD
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()
	_push_trail_point(global_position)


func _push_trail_point(wpos: Vector2) -> void:
	_trail_pts.append(wpos)
	_trail_ages.append(0.0)


func _age_trail(delta: float) -> void:
	var write_idx: int = 0
	for i in _trail_ages.size():
		var new_age: float = _trail_ages[i] + delta
		if new_age < TRAIL_DURATION_SEC:
			_trail_ages[write_idx] = new_age
			_trail_pts[write_idx] = _trail_pts[i]
			write_idx += 1
	_trail_ages.resize(write_idx)
	_trail_pts.resize(write_idx)


func _retire_with_trail() -> void:
	_spent = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_push_trail_point(global_position)
	queue_redraw()
	if not from_player or _trail_pts.size() < 2:
		queue_free()


func _physics_process(delta: float) -> void:
	_glint_t += delta * 24.0
	_age_trail(delta)
	if _spent:
		queue_redraw()
		if _trail_pts.size() < 2:
			queue_free()
		return
	# Homing does not apply to Split Shots; Sniper always homes to monsters/bosses.
	var should_home: bool = from_player and proj_kind != ProjKind.SPLIT and (
		proj_kind == ProjKind.SNIPER or (homing and GameState.is_homing_active())
	)
	if should_home:
		var target: Node2D = _find_homing_target(proj_kind == ProjKind.SNIPER)
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
	_push_trail_point(global_position)
	queue_redraw()

	# Swept-segment hit check guarantees hits on StaticBody2D nests, monsters, and bosses.
	_check_swept_hits(prev_pos, global_position)
	if _spent:
		return

	if max_distance > 0.0 and _traveled >= max_distance:
		_on_range_expired()
		_retire_with_trail()


func _on_range_expired() -> void:
	if not from_player or not uses_augments:
		return
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_parent()
	# Bombspell Lv 3 unique ability: when the spell runs out of range, it still explodes.
	if (proj_kind == ProjKind.INITIAL or proj_kind == ProjKind.SPLIT) and _aug_lvl("bomb") >= 3:
		_spawn_bomb_zone(container)


func _find_homing_target(exclude_nests: bool = false) -> Node2D:
	var best: Node2D = null
	var best_score: float = INF
	for node in get_tree().get_nodes_in_group("targets"):
		var target := node as Node2D
		if target == null or target == ignore_target or target.is_queued_for_deletion() or not target.has_method("take_damage"):
			continue
		if exclude_nests and target.is_in_group("nests"):
			continue
		var d: float = global_position.distance_to(target.global_position)
		# Prefer active enemies (monsters & bosses) over static nests when nearby.
		var score: float = d if not target.is_in_group("nests") else d + Config.tiles(1.5)
		if score < best_score:
			best_score = score
			best = target
	return best


func _segment_wall_hit_t(from_pos: Vector2, to_pos: Vector2) -> float:
	var world := get_tree().get_first_node_in_group("world") as World
	if world == null:
		return -1.0
	var seg: Vector2 = to_pos - from_pos
	var best_t: float = INF
	var pad: float = radius * 0.25
	for w in world.wall_rects:
		var box: Rect2 = w.grow(pad)
		var tmin: float = 0.0
		var tmax: float = 1.0
		if absf(seg.x) < 1e-6:
			if from_pos.x < box.position.x or from_pos.x > box.end.x:
				continue
		else:
			var tx1: float = (box.position.x - from_pos.x) / seg.x
			var tx2: float = (box.end.x - from_pos.x) / seg.x
			if tx1 > tx2:
				var tmp: float = tx1
				tx1 = tx2
				tx2 = tmp
			tmin = maxf(tmin, tx1)
			tmax = minf(tmax, tx2)
		if absf(seg.y) < 1e-6:
			if from_pos.y < box.position.y or from_pos.y > box.end.y:
				continue
		else:
			var ty1: float = (box.position.y - from_pos.y) / seg.y
			var ty2: float = (box.end.y - from_pos.y) / seg.y
			if ty1 > ty2:
				var tmp_y: float = ty1
				ty1 = ty2
				ty2 = tmp_y
			tmin = maxf(tmin, ty1)
			tmax = minf(tmax, ty2)
		if tmin <= tmax and tmin < best_t:
			best_t = tmin
	if not world.rect.has_point(to_pos):
		best_t = minf(best_t, 1.0)
	return best_t if best_t <= 1.0 else -1.0


func _check_swept_hits(from_pos: Vector2, to_pos: Vector2) -> void:
	var effective_to: Vector2 = to_pos
	var hit_wall: bool = false
	if not _can_pierce_walls():
		var wt: float = _segment_wall_hit_t(from_pos, to_pos)
		if wt >= 0.0:
			hit_wall = true
			effective_to = from_pos.lerp(to_pos, wt)

	if from_player:
		var best_node: Node2D = null
		var best_dist_sq: float = INF
		for node in get_tree().get_nodes_in_group("targets"):
			var target := node as Node2D
			if target == null or target == ignore_target or target.is_queued_for_deletion() or not target.has_method("take_damage"):
				continue
			# Sniper only targets monsters and bosses, never nests.
			if proj_kind == ProjKind.SNIPER and target.is_in_group("nests"):
				continue
			var hit_r: float = float(target.call("get_hit_radius")) if target.has_method("get_hit_radius") else Config.tiles(0.5)
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target.global_position, from_pos, effective_to)
			if closest.distance_to(target.global_position) <= radius + hit_r:
				var d_sq: float = from_pos.distance_squared_to(target.global_position)
				if d_sq < best_dist_sq:
					best_dist_sq = d_sq
					best_node = target
		if best_node != null:
			_on_body_entered(best_node)
			return
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and not player.is_queued_for_deletion() and player.has_method("take_damage"):
			var hit_r: float = Config.tiles(Config.PLAYER_RADIUS_TILES)
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(player.global_position, from_pos, effective_to)
			if closest.distance_to(player.global_position) <= radius + hit_r:
				_on_body_entered(player)
				return
		for node in get_tree().get_nodes_in_group("doppelgangers"):
			var dop := node as Node2D
			if dop != null and not dop.is_queued_for_deletion() and dop.has_method("take_damage"):
				var hit_r: float = Config.tiles(Config.PLAYER_RADIUS_TILES)
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(dop.global_position, from_pos, effective_to)
				if closest.distance_to(dop.global_position) <= radius + hit_r:
					_on_body_entered(dop)
					return

	if hit_wall and not _spent:
		global_position = effective_to
		_retire_with_trail()


func _on_body_entered(body: Node) -> void:
	if _spent or body == ignore_target:
		return
	if not _can_pierce_walls() and body is StaticBody2D and not body.is_in_group("nests"):
		_retire_with_trail()
		return
	if from_player and proj_kind == ProjKind.SNIPER and body.is_in_group("nests"):
		return
	if not from_player and slow_duration > 0.0 and body.has_method("apply_slow"):
		_spent = true
		body.call("apply_slow", slow_duration)
		if damage > 0.0 and body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
		return
	if body.has_method("take_damage"):
		_spent = true
		if damage > 0.0:
			body.take_damage(damage)
		if from_player and body is Node2D and uses_augments:
			_apply_augmentations(body as Node2D)
		_retire_with_trail()


func _apply_augmentations(hit_target: Node2D) -> void:
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_parent()

	if proj_kind == ProjKind.SNIPER:
		# Sniper Lv 3 unique ability: sniper shell explodes with the explosion augmentation on hit.
		if _aug_lvl("sniper") >= 3:
			_spawn_bomb_zone(container)
		return

	var bomb_lvl: int = _aug_lvl("bomb")
	var split_lvl: int = _max_split_depth_for_proj()

	# 1. Sniper: only on initial first impact of player spell on enemy (targets monsters & bosses only, not nests).
	if proj_kind == ProjKind.INITIAL and _aug_lvl("sniper") > 0:
		_spawn_sniper_shot(container, hit_target)

	# 2. Split Spell Lv 3 unique ability: chain lightning across split hits, connecting hit_target with another enemy
	# and zapping both alongside each other for the same damage as the split shot.
	if proj_kind == ProjKind.SPLIT and split_lvl >= 3:
		_trigger_chain_lightning(container, hit_target)

	# 3. Recursive Split Spell: each hit splits into 2 projectiles at 45° (½ damage, no homing),
	# and each of those can re-split on hit up to `split_lvl` times (1 split at Lv 1, 2 at Lv 2, 3 at Lv 3).
	var can_split: bool = split_depth < split_lvl
	if can_split:
		_spawn_split_shots(container, hit_target)
		# Bombspell Lv 3 unique ability: explodes on each hit no matter if they split or not.
		if bomb_lvl >= 3:
			_spawn_bomb_zone(container)
	elif bomb_lvl > 0:
		# Final split projectiles (or unsplit spells when Split is Lv 0) trigger Bombspell on impact.
		_spawn_bomb_zone(container)


func _trigger_chain_lightning(container: Node, hit_target: Node2D) -> void:
	var best: Node2D = null
	var best_dist: float = Config.tiles(Config.CHAIN_LIGHTNING_RANGE_TILES)
	for node in get_tree().get_nodes_in_group("targets"):
		var candidate := node as Node2D
		if candidate == null or candidate == hit_target or candidate.is_queued_for_deletion() or not candidate.has_method("take_damage"):
			continue
		if candidate.is_in_group("nests"):
			continue
		var d: float = hit_target.global_position.distance_to(candidate.global_position)
		if d <= best_dist:
			best_dist = d
			best = candidate
	if best == null:
		return
	var start_pos: Vector2 = hit_target.global_position
	var end_pos: Vector2 = best.global_position
	# Both connected enemies get zapped alongside each other for the same damage as the split shot.
	if not hit_target.is_queued_for_deletion() and hit_target.has_method("take_damage"):
		hit_target.take_damage(damage)
	if not best.is_queued_for_deletion() and best.has_method("take_damage"):
		best.take_damage(damage)
	var arc: Node2D = ChainLightningScript.new()
	arc.call("setup", start_pos, end_pos)
	container.call_deferred("add_child", arc)


func _spawn_split_shots(container: Node, hit_target: Node2D) -> void:
	var count: int = Config.SPLIT_PROJECTILES_PER_HIT
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
			color.lightened(0.12),
			maxf(3.0, radius * 0.85),
			max_distance,
			false,
			ProjKind.SPLIT,
			hit_target,
			uses_augments,
			aug_override,
			0.0,
			split_depth + 1
		)
		p.global_position = global_position
		container.call_deferred("add_child", p)


func _spawn_sniper_shot(container: Node, hit_target: Node2D) -> void:
	# Sniper only targets monsters and bosses, never nests.
	var prev_ignore: Node2D = ignore_target
	ignore_target = hit_target
	var next_target: Node2D = _find_homing_target(true)
	ignore_target = prev_ignore
	var sniper_dir: Vector2 = direction
	if next_target != null:
		sniper_dir = global_position.direction_to(next_target.global_position)
	elif not hit_target.is_in_group("nests"):
		sniper_dir = direction
	else:
		# Hit a nest and there are no monsters or bosses alive on the map.
		return
	var this_scene: PackedScene = load("res://scenes/spells/Projectile.tscn")
	var p: Projectile = this_scene.instantiate()
	p.setup(
		sniper_dir,
		speed * Config.SNIPER_SPEED_MULT,
		damage * _sniper_mult_for_proj(),
		true,
		Color(1.0, 0.95, 0.25),
		radius * 0.9,
		max_distance * 1.5,
		true,
		ProjKind.SNIPER,
		hit_target,
		uses_augments,
		aug_override
	)
	p.global_position = global_position
	container.call_deferred("add_child", p)


func _spawn_bomb_zone(container: Node) -> void:
	var zone: Node2D = FireZoneScript.new()
	zone.call("setup", _bomb_dps_for_proj(), Config.BOMB_DURATION_SEC, Config.tiles(Config.BOMB_RADIUS_TILES))
	zone.global_position = global_position
	container.call_deferred("add_child", zone)


func _draw() -> void:
	if from_player:
		var len_f: float = clampf(radius * (1.75 if proj_kind == ProjKind.SNIPER else 1.45), 6.2, 12.5)
		var wing_y: float = clampf(radius * 0.55, 2.4, 4.6)
		var back_x: float = -len_f * 0.58

		# 1. Small temporary fading world-space trail behind the sharp spell triangle
		var cnt: int = _trail_pts.size()
		if cnt >= 2:
			for i in range(cnt - 1):
				var p0: Vector2 = to_local(_trail_pts[i])
				var p1: Vector2 = to_local(_trail_pts[i + 1])
				var frac: float = 1.0 - clampf(_trail_ages[i + 1] / TRAIL_DURATION_SEC, 0.0, 1.0)
				if frac <= 0.02:
					continue
				draw_line(p0, p1, Color(color, 0.28 * frac), maxf(1.2, wing_y * 1.45 * frac))
				draw_line(p0, p1, Color(color.lightened(0.45), 0.78 * frac), maxf(0.8, wing_y * 0.62 * frac))
				if i % 2 == 1 and frac > 0.3:
					draw_circle(p0.lerp(p1, 0.5), maxf(0.8, 1.3 * frac), Color(1.0, 1.0, 1.0, 0.65 * frac))

		if _spent:
			return

		# 2. Flashy outer arcane triangle halo
		var pulse: float = 0.28 + 0.08 * sin(_glint_t)
		draw_colored_polygon(PackedVector2Array([
			Vector2(len_f * 1.28, 0.0),
			Vector2(back_x * 1.22, -wing_y * 1.45),
			Vector2(back_x * 1.22, wing_y * 1.45),
		]), Color(color.lightened(0.18), pulse))

		# 3. Sharp small triangle spell body + bright rim
		var tri := PackedVector2Array([
			Vector2(len_f, 0.0),
			Vector2(back_x, -wing_y),
			Vector2(back_x, wing_y),
		])
		draw_colored_polygon(tri, color.lightened(0.12))
		draw_polyline(PackedVector2Array([
			Vector2(len_f, 0.0),
			Vector2(back_x, -wing_y),
			Vector2(back_x, wing_y),
			Vector2(len_f, 0.0),
		]), color.lightened(0.55), 1.1)

		# 4. Blazing white-hot inner needle triangle + tip star-glint
		draw_colored_polygon(PackedVector2Array([
			Vector2(len_f * 0.74, 0.0),
			Vector2(back_x * 0.52, -wing_y * 0.44),
			Vector2(back_x * 0.52, wing_y * 0.44),
		]), Color.WHITE)
		var glint_len: float = wing_y * (0.95 + 0.25 * sin(_glint_t * 1.3))
		var gp := Vector2(len_f * 0.58, 0.0)
		draw_line(gp + Vector2(0.0, -glint_len), gp + Vector2(0.0, glint_len), Color(1.0, 1.0, 1.0, 0.78), 1.1)
	else:
		# Enemy bolts (Boss fiery bolt & Undead white slow orb)
		var tail_len: float = radius * 3.0
		draw_line(Vector2.ZERO, Vector2(-tail_len, 0), Color(color, 0.28), radius * 1.35)
		draw_circle(Vector2.ZERO, radius * 1.65, Color(color, 0.24))
		draw_circle(Vector2.ZERO, radius * 1.08, color)
		draw_circle(Vector2.ZERO, radius * 0.52, Color.WHITE)

