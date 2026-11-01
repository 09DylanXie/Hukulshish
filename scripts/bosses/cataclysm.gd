class_name Cataclysm
extends Node2D
## The Mega Boss's invulnerable phases (§6.10). While one runs, the boss can't be hit, and the arena
## turns against the team. Because each lasts a fixed time, no build can skip them. Guests receive
## the same shapes from net_shapes() and draw them with draw_shapes().

signal finished

enum Pattern {
	METEORS,
	SHOCKWAVES,
	COLLAPSE,
	INFERNO,
	FALLING_SKY,
	DRAGONS_BREATH,
}

const NAMES: Dictionary = {
	Pattern.METEORS: "METEOR STORM",
	Pattern.SHOCKWAVES: "SHOCKWAVES",
	Pattern.COLLAPSE: "THE COLLAPSE",
	Pattern.INFERNO: "INFERNO",
	Pattern.FALLING_SKY: "THE SKY FALLS",
	Pattern.DRAGONS_BREATH: "DRAGON'S BREATH",
}
const SHAPE_STRIDE: int = 5
const SHAPE_METEOR: float = 0.0
const SHAPE_BLAST: float = 1.0
const SHAPE_WAVE: float = 2.0
const SHAPE_COLLAPSE: float = 3.0
const SHAPE_BEAM: float = 4.0
const BLAST_FLASH_SEC: float = 0.25
const COLLAPSE_VOID_WIDTH_PX: float = 6000.0

var pattern: Pattern = Pattern.METEORS

## Each is a position, with the fuse left in z.
var _meteors: Array[Vector3] = []
## Each is a position, with the flash time left in z.
var _blasts: Array[Vector3] = []
## Each is (radius, gap angle).
var _waves: Array[Vector2] = []
var _time_left: float = Config.CATACLYSM_DURATION_SEC
var _meteor_timer: float = 0.0
var _wave_timer: float = 0.0
var _line_timer: float = 0.0
var _safe_center: Vector2 = Vector2.ZERO
var _safe_target: Vector2 = Vector2.ZERO
var _collapse_warning: float = Config.COLLAPSE_WARNING_SEC
var _collapse_tick: float = 0.0
var _beam_angle: float = randf() * TAU
var _beam_warning: float = Config.BREATH_WARNING_SEC
var _hatch_timer: float = 0.0


func _ready() -> void:
	z_index = -1
	var victim: Player = Player.nearest_living_player(get_tree(), global_position)
	_safe_center = victim.global_position if victim != null else global_position
	_safe_target = _safe_center
	AudioManager.play("cataclysm_roar")
	GameState.request_shake(12.0, 0.6)
	GameState.spawn_floating_text(global_position + Vector2(0, -80), "%s!" % NAMES[pattern], Color(1.0, 0.4, 0.3))


func uses_collapse() -> bool:
	return pattern == Pattern.COLLAPSE or pattern == Pattern.FALLING_SKY


func _physics_process(delta: float) -> void:
	_time_left -= delta
	_update_meteors(delta)
	_update_waves(delta)
	_update_collapse(delta)
	_update_fire_lines(delta)
	_update_breath(delta)
	queue_redraw()
	if _time_left <= 0.0:
		finished.emit()
		queue_free()


func _targets() -> Array[Player]:
	var targets: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player: Player = node as Player
		if player != null and player.is_targetable():
			targets.append(player)
	return targets


# --- Meteors ---

func _update_meteors(delta: float) -> void:
	for i in range(_blasts.size() - 1, -1, -1):
		var blast: Vector3 = _blasts[i]
		blast.z -= delta
		_blasts[i] = blast
		if blast.z <= 0.0:
			_blasts.remove_at(i)
	for i in range(_meteors.size() - 1, -1, -1):
		var meteor: Vector3 = _meteors[i]
		meteor.z -= delta
		_meteors[i] = meteor
		if meteor.z <= 0.0:
			_detonate(Vector2(meteor.x, meteor.y))
			_meteors.remove_at(i)
	if pattern == Pattern.SHOCKWAVES or pattern == Pattern.COLLAPSE or pattern == Pattern.DRAGONS_BREATH:
		return
	_meteor_timer -= delta
	if _meteor_timer > 0.0:
		return
	_meteor_timer = Config.METEOR_INTERVAL_SEC
	for player: Player in _targets():
		_add_meteor(player.global_position)
		for _i in Config.METEORS_PER_VOLLEY:
			var offset: Vector2 = Vector2.from_angle(randf() * TAU) * Config.tiles(randf_range(2.0, Config.METEOR_SCATTER_TILES))
			_add_meteor(player.global_position + offset)


func _add_meteor(pos: Vector2) -> void:
	_meteors.append(Vector3(pos.x, pos.y, Config.METEOR_FUSE_SEC))


func _detonate(pos: Vector2) -> void:
	_blasts.append(Vector3(pos.x, pos.y, BLAST_FLASH_SEC))
	AudioManager.play_at("bomb_explosion", pos)
	var reach: float = Config.tiles(Config.METEOR_RADIUS_TILES + Config.PLAYER_RADIUS_TILES)
	for player: Player in _targets():
		if player.global_position.distance_to(pos) <= reach:
			player.take_damage(Config.METEOR_DAMAGE)


# --- Shockwaves ---

func _update_waves(delta: float) -> void:
	var speed: float = Config.tiles(Config.SHOCKWAVE_SPEED_TILES)
	for i in range(_waves.size() - 1, -1, -1):
		var wave: Vector2 = _waves[i]
		var before: float = wave.x
		wave.x += speed * delta
		_waves[i] = wave
		_hit_with_wave(before, wave.x, wave.y)
		if wave.x > Config.tiles(Config.SHOCKWAVE_MAX_RADIUS_TILES):
			_waves.remove_at(i)
	if pattern != Pattern.SHOCKWAVES:
		return
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = Config.SHOCKWAVE_INTERVAL_SEC
		_waves.append(Vector2(0.0, randf() * TAU))
		AudioManager.play("shockwave")


## The ring only hurts as it sweeps across a player outside its gaps.
func _hit_with_wave(before: float, after: float, gap: float) -> void:
	for player: Player in _targets():
		var to_player: Vector2 = player.global_position - global_position
		var distance: float = to_player.length()
		if distance < before or distance > after:
			continue
		if not in_wave_gap(to_player.angle(), gap):
			player.take_damage(Config.SHOCKWAVE_DAMAGE)


## Each ring has two gaps, on opposite sides.
static func in_wave_gap(angle: float, gap: float) -> bool:
	var half_width: float = deg_to_rad(Config.SHOCKWAVE_GAP_DEG) * 0.5
	return absf(angle_difference(angle, gap)) <= half_width or absf(angle_difference(angle, gap + PI)) <= half_width


# --- The Collapse ---

func _update_collapse(delta: float) -> void:
	if not uses_collapse():
		return
	var radius: float = Config.tiles(Config.COLLAPSE_SAFE_RADIUS_TILES)
	if _safe_center.distance_to(_safe_target) < Config.tiles(0.5):
		_safe_target = global_position + Vector2.from_angle(randf() * TAU) * Config.tiles(randf_range(2.0, Config.COLLAPSE_DRIFT_TILES))
	_safe_center = _safe_center.move_toward(_safe_target, Config.tiles(Config.COLLAPSE_DRIFT_SPEED_TILES) * delta)
	if _collapse_warning > 0.0:
		_collapse_warning -= delta
		return
	_collapse_tick -= delta
	if _collapse_tick > 0.0:
		return
	_collapse_tick = Config.COLLAPSE_TICK_SEC
	for player: Player in _targets():
		if player.global_position.distance_to(_safe_center) > radius:
			player.take_damage(Config.COLLAPSE_DAMAGE)


# --- Inferno ---

func _update_fire_lines(delta: float) -> void:
	if pattern != Pattern.INFERNO or _time_left < Config.DRAGON_FIRE_WARNING_SEC + Config.DRAGON_FIRE_BURN_SEC:
		return
	_line_timer -= delta
	if _line_timer > 0.0:
		return
	_line_timer = Config.INFERNO_LINE_INTERVAL_SEC
	var start: float = randf() * TAU
	for i in Config.INFERNO_LINES:
		var line := FireLine.new()
		line.setup(global_position, Vector2.from_angle(start + float(i) * TAU / float(Config.INFERNO_LINES)))
		get_parent().add_child(line)


# --- Dragon's Breath ---

func _beam_tip(index: int) -> Vector2:
	var angle: float = _beam_angle + float(index) * TAU / float(Config.BREATH_BEAMS)
	return global_position + Vector2.from_angle(angle) * Config.tiles(Config.BREATH_LENGTH_TILES)


## Beams of fire sweep slowly around the dragon, after a warning.
func _update_breath(delta: float) -> void:
	if pattern != Pattern.DRAGONS_BREATH:
		return
	if _beam_warning > 0.0:
		_beam_warning -= delta
		if _beam_warning <= 0.0:
			AudioManager.play("fire_line_burn")
		return
	_beam_angle += Config.BREATH_TURN_SPEED * delta
	_hatch_timer -= delta
	if _hatch_timer <= 0.0:
		_hatch_timer = Config.HATCHLING_SPAWN_INTERVAL_SEC
		for _i in Config.HATCHLING_SPAWN_COUNT:
			var hatchling := DragonHatchling.new()
			hatchling.position = position + Vector2.from_angle(randf() * TAU) * Config.tiles(randf_range(2.5, 4.0))
			get_parent().add_child(hatchling)
	var reach: float = Config.tiles(Config.BREATH_WIDTH_TILES * 0.5 + Config.PLAYER_RADIUS_TILES)
	for player: Player in _targets():
		for i in Config.BREATH_BEAMS:
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(player.global_position, global_position, _beam_tip(i))
			if closest.distance_to(player.global_position) <= reach:
				player.take_damage(Config.BREATH_DAMAGE)
				break


# --- Drawing, shared with guests ---

## Every active hazard as packed floats: kind, x, y, radius or angle, progress.
func net_shapes() -> PackedFloat32Array:
	var data := PackedFloat32Array()
	for meteor: Vector3 in _meteors:
		data.append_array([SHAPE_METEOR, meteor.x, meteor.y, Config.tiles(Config.METEOR_RADIUS_TILES), 1.0 - meteor.z / Config.METEOR_FUSE_SEC])
	for blast: Vector3 in _blasts:
		data.append_array([SHAPE_BLAST, blast.x, blast.y, Config.tiles(Config.METEOR_RADIUS_TILES), blast.z / BLAST_FLASH_SEC])
	for wave: Vector2 in _waves:
		data.append_array([SHAPE_WAVE, global_position.x, global_position.y, wave.x, wave.y])
	if uses_collapse():
		var armed: float = 1.0 if _collapse_warning <= 0.0 else 1.0 - _collapse_warning / Config.COLLAPSE_WARNING_SEC
		data.append_array([SHAPE_COLLAPSE, _safe_center.x, _safe_center.y, Config.tiles(Config.COLLAPSE_SAFE_RADIUS_TILES), armed])
	if pattern == Pattern.DRAGONS_BREATH:
		for i in Config.BREATH_BEAMS:
			var tip: Vector2 = _beam_tip(i) - global_position
			data.append_array([SHAPE_BEAM, global_position.x, global_position.y, tip.angle(), 1.0 - maxf(_beam_warning, 0.0) / Config.BREATH_WARNING_SEC])
	return data


func _draw() -> void:
	# Hazards are in world coordinates, and this node sits at the boss.
	draw_set_transform(-global_position)
	draw_shapes(self, net_shapes())


static func draw_shapes(canvas: CanvasItem, shapes: PackedFloat32Array) -> void:
	for i in range(0, shapes.size(), SHAPE_STRIDE):
		var kind: float = shapes[i]
		var pos := Vector2(shapes[i + 1], shapes[i + 2])
		if kind == SHAPE_METEOR:
			canvas.draw_circle(pos, shapes[i + 3], Color(1.0, 0.25, 0.08, 0.14 + 0.2 * shapes[i + 4]))
			canvas.draw_arc(pos, shapes[i + 3], 0.0, TAU, 28, Color(1.0, 0.55, 0.2, 0.9), 2.0)
			canvas.draw_circle(pos, shapes[i + 3] * shapes[i + 4], Color(1.0, 0.55, 0.15, 0.45))
		elif kind == SHAPE_BLAST:
			canvas.draw_circle(pos, shapes[i + 3] * 1.2, Color(1.0, 0.85, 0.45, 0.8 * shapes[i + 4]))
		elif kind == SHAPE_WAVE:
			_draw_wave(canvas, pos, shapes[i + 3], shapes[i + 4])
		elif kind == SHAPE_COLLAPSE:
			_draw_collapse(canvas, pos, shapes[i + 3], shapes[i + 4])
		elif kind == SHAPE_BEAM:
			_draw_beam(canvas, pos, shapes[i + 3], shapes[i + 4])


static func _draw_wave(canvas: CanvasItem, center: Vector2, radius: float, gap: float) -> void:
	var half_gap: float = deg_to_rad(Config.SHOCKWAVE_GAP_DEG) * 0.5
	for side: float in [0.0, PI]:
		var start: float = gap + side + half_gap
		canvas.draw_arc(center, radius, start, start + PI - half_gap * 2.0, 48, Color(0.75, 0.35, 1.0, 0.9), 10.0)
		canvas.draw_arc(center, radius, start, start + PI - half_gap * 2.0, 48, Color(0.95, 0.85, 1.0, 0.95), 3.0)


static func _draw_beam(canvas: CanvasItem, start: Vector2, angle: float, armed: float) -> void:
	var tip: Vector2 = start + Vector2.from_angle(angle) * Config.tiles(Config.BREATH_LENGTH_TILES)
	var width: float = Config.tiles(Config.BREATH_WIDTH_TILES)
	if armed < 1.0:
		canvas.draw_line(start, tip, Color(1.0, 0.25, 0.1, 0.2 + 0.4 * armed), width * armed)
		return
	canvas.draw_line(start, tip, Color(1.0, 0.45, 0.08, 0.85), width)
	canvas.draw_line(start, tip, Color(1.0, 0.9, 0.5, 0.95), width * 0.4)


## Everything outside the safe circle falls away into the abyss.
static func _draw_collapse(canvas: CanvasItem, center: Vector2, radius: float, armed: float) -> void:
	var void_color := Color(0.03, 0.01, 0.07, 0.85) if armed >= 1.0 else Color(0.5, 0.1, 0.6, 0.12 + 0.3 * armed)
	canvas.draw_arc(center, radius + COLLAPSE_VOID_WIDTH_PX * 0.5, 0.0, TAU, 96, void_color, COLLAPSE_VOID_WIDTH_PX)
	canvas.draw_arc(center, radius, 0.0, TAU, 64, Color(0.8, 0.5, 1.0, 0.95), 3.0)
