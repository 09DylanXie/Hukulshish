class_name FireZone
extends Node2D
## Medium-sized Bombspell fire explosion that burns enemies for 3 seconds.
## 1 tick of fire damage breaks a Demon's bubble shield.

var dps: float = Config.BOMB_BASE_DPS
var duration: float = Config.BOMB_DURATION_SEC
var radius: float = Config.tiles(Config.BOMB_RADIUS_TILES)
var source_state: RunState

var _elapsed: float = 0.0
var _tick_timer: float = 0.0


func setup(fire_dps: float, dur: float = Config.BOMB_DURATION_SEC, rad_px: float = -1.0) -> void:
	dps = fire_dps
	duration = dur
	if rad_px > 0.0:
		radius = rad_px


func _ready() -> void:
	z_index = -2
	GameState.request_shake(3.5, 0.14)
	# Apply first tick immediately on impact so enemies in the blast take an instant tick (breaking Demon shields).
	_apply_tick(Config.BOMB_TICK_SEC)
	_tick_timer = Config.BOMB_TICK_SEC


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer += Config.BOMB_TICK_SEC
		_apply_tick(Config.BOMB_TICK_SEC)
	queue_redraw()
	if _elapsed >= duration:
		queue_free()


func _apply_tick(dt: float) -> void:
	var tick_dmg: float = dps * dt
	for node in get_tree().get_nodes_in_group("targets"):
		var target := node as Node2D
		if target == null or target.is_queued_for_deletion() or not target.has_method("take_damage"):
			continue
		var hit_r: float = float(target.call("get_hit_radius")) if target.has_method("get_hit_radius") else Config.tiles(0.5)
		if global_position.distance_to(target.global_position) <= radius + hit_r:
			if is_instance_valid(source_state):
				source_state.deal_damage(target, tick_dmg)
			else:
				target.take_damage(tick_dmg)


func _draw() -> void:
	var fade: float = clampf(1.0 - (_elapsed / duration) * 0.45, 0.2, 1.0)
	var pulse: float = 1.0 + 0.06 * sin(_elapsed * 14.0)
	var r: float = radius * pulse
	# Hades-style hellfire sigil zone
	draw_circle(Vector2.ZERO, r, Color(0.95, 0.22, 0.05, 0.24 * fade))
	draw_circle(Vector2.ZERO, r * 0.72, Color(1.0, 0.55, 0.08, 0.28 * fade))
	draw_circle(Vector2.ZERO, r * 0.36, Color(1.0, 0.9, 0.35, 0.32 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.52, 0.12, 0.9 * fade), 2.5)
	draw_arc(Vector2.ZERO, r * 0.78, _elapsed * 2.2, _elapsed * 2.2 + TAU * 0.75, 28, Color(1.0, 0.85, 0.28, 0.65 * fade), 1.8)
	for i in 6:
		var ang: float = _elapsed * 2.5 + float(i) * TAU / 6.0
		var p_in: Vector2 = Vector2.from_angle(ang) * (r * 0.45)
		var p_out: Vector2 = Vector2.from_angle(ang + 0.35) * (r * 0.92)
		draw_line(p_in, p_out, Color(1.0, 0.78, 0.22, 0.55 * fade), 2.0)


