class_name World
extends Node2D
## Generated map: a square field centered on (0, 0), filled with either a random, spacious maze or
## open wilds with trees, rocks and rivers (§6.12). New terrain is generated every run.
## Also provides a flow field so monsters can path around obstacles toward the player.
## Set `size_in_tiles` and `clear_zones` before adding to the tree.

## How often the flow field toward the player is recomputed.
const FLOW_INTERVAL_SEC: float = 0.25
const TREE_TEXTURES: Array[String] = ["res://assets/sprites/world/tree_1.png", "res://assets/sprites/world/tree_2.png"]
const ROCK_TEXTURES: Array[String] = ["res://assets/sprites/world/rock_1.png", "res://assets/sprites/world/rock_2.png"]

var size_in_tiles: int = 60
var terrain: LayerData.Terrain = LayerData.Terrain.MAZE
var maze_cell_tiles: int = Config.MAZE_CELL_TILES
var maze_opening_chance: float = Config.MAZE_EXTRA_OPENING_CHANCE
var has_lava: bool = false
var has_graves: bool = false
var floor_crack_color: Color = Color.TRANSPARENT
var floor_texture: String = "res://assets/tilesets/ground_tile.png"
var wall_textures: Array[String] = ["res://assets/tilesets/wall_tile.png"]
var backdrop_color: Color = Color(0.1, 0.15, 0.09)
## Circles kept free of maze walls (nests, gold mines …). Each Vector3 = (center.x, center.y, radius) in px.
var clear_zones: Array[Vector3] = []
## Fixed seed for testing. 0 = random every run.
var rng_seed: int = 0

## Maze wall and obstacle rectangles in local (= global) px.
var wall_rects: Array[Rect2] = []
## Trees and rocks as { texture, position }. Game adds them to the y-sorted entities.
var props: Array[Dictionary] = []

var rect: Rect2:
	get:
		var s: float = Config.tiles(size_in_tiles)
		return Rect2(-s * 0.5, -s * 0.5, s, s)

var _n: int = 0
var _blocked: PackedByteArray
var _dist: PackedInt32Array
var _queue: PackedInt32Array
var _flow_timer: float = 0.0
var _flow_ready: bool = false
## Deterministic outdoor meadow details: Vector4(x, y, radius_or_size, kind)
var _decor: Array[Vector4] = []
## One flag per tile, empty on layers without rivers.
var _river: PackedByteArray = PackedByteArray()
## Each river's center line, for drawing.
var _river_lines: Array[PackedVector2Array] = []
## Short highlights on the water, as Rect2(start, offset).
var _river_ripples: Array[Rect2] = []
## One flag per tile, empty on layers without lava.
var _lava: PackedByteArray = PackedByteArray()
var _lava_cracks: Array[PackedVector3Array] = []
## Tile index -> the crack segments crossing it.
var _lava_segments: Dictionary = {}
var _dry_cracks: Array[PackedVector3Array] = []


## Takes the look and rules of a layer. Call before adding to the tree.
func apply_layer(layer: LayerData) -> void:
	terrain = layer.terrain
	maze_cell_tiles = layer.maze_cell_tiles
	maze_opening_chance = layer.maze_opening_chance
	has_lava = layer.has_lava
	has_graves = layer.has_graves
	floor_crack_color = layer.floor_crack_color
	floor_texture = layer.floor_texture
	wall_textures = layer.wall_textures
	backdrop_color = layer.backdrop_color


func _ready() -> void:
	add_to_group("world")
	z_index = -10
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	match terrain:
		LayerData.Terrain.WILDS:
			_generate_wilds(rng)
		LayerData.Terrain.ABYSS:
			_generate_abyss()
		_:
			_generate_maze(rng)
	if has_lava:
		_generate_lava(rng)
	if floor_crack_color.a > 0.0:
		_dry_cracks = _grow_cracks(rng, size_in_tiles / Config.LAVA_TILES_PER_CRACK, Config.DRY_CRACK_WIDTH)
	_build_walls()
	_build_nav_grid()
	_build_outdoor_decor(rng)


func _physics_process(delta: float) -> void:
	_flow_timer -= delta
	if _flow_timer > 0.0:
		return
	_flow_timer = FLOW_INTERVAL_SEC
	var targets: Array[Vector2] = []
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player: Player = node as Player
		if player != null and player.is_targetable():
			targets.append(player.global_position)
	if not targets.is_empty():
		_update_flow_from(targets)


# --- Maze generation ---

func _generate_maze(rng: RandomNumberGenerator) -> void:
	wall_rects.clear()
	var n: int = size_in_tiles / maze_cell_tiles
	if n < 2:
		return
	var r: Rect2 = rect
	var cell: float = r.size.x / n
	# right[i]: wall between cell (x, y) and (x+1, y). down[i]: wall between (x, y) and (x, y+1). i = y*n + x
	var right := PackedByteArray()
	right.resize(n * n)
	right.fill(1)
	var down := PackedByteArray()
	down.resize(n * n)
	down.fill(1)
	var visited := PackedByteArray()
	visited.resize(n * n)

	# Randomized depth-first carve → every cell is reachable.
	var start := Vector2i(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1))
	var stack: Array[Vector2i] = [start]
	visited[start.y * n + start.x] = 1
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in dirs:
			var nb: Vector2i = cur + d
			if nb.x >= 0 and nb.y >= 0 and nb.x < n and nb.y < n and visited[nb.y * n + nb.x] == 0:
				options.append(nb)
		if options.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		var a: Vector2i = Vector2i(mini(cur.x, nxt.x), mini(cur.y, nxt.y))
		if cur.y == nxt.y:
			right[a.y * n + a.x] = 0
		else:
			down[a.y * n + a.x] = 0
		visited[nxt.y * n + nxt.x] = 1
		stack.push_back(nxt)

	# Knock out extra walls so it's a spacious maze with loops, not a strict labyrinth.
	for i in n * n:
		if right[i] == 1 and rng.randf() < maze_opening_chance:
			right[i] = 0
		if down[i] == 1 and rng.randf() < maze_opening_chance:
			down[i] = 0

	# Turn wall flags into rectangles, skipping the clear center and clear zones.
	# (Removing walls never disconnects a maze, so everything stays reachable.)
	var t: float = Config.tiles(Config.MAZE_WALL_THICKNESS_TILES)
	var center_clear: float = r.size.x * 0.5 * Config.MAZE_CLEAR_CENTER_FRACTION
	for y in n:
		for x in n:
			var i: int = y * n + x
			if x < n - 1 and right[i] == 1:
				_try_add_wall(Rect2(r.position.x + (x + 1) * cell - t * 0.5, r.position.y + y * cell - t * 0.5, t, cell + t), center_clear)
			if y < n - 1 and down[i] == 1:
				_try_add_wall(Rect2(r.position.x + x * cell - t * 0.5, r.position.y + (y + 1) * cell - t * 0.5, cell + t, t), center_clear)


func _try_add_wall(wall: Rect2, center_clear: float) -> void:
	if _rect_hits_circle(wall, rect.get_center(), center_clear):
		return
	for z in clear_zones:
		if _rect_hits_circle(wall, Vector2(z.x, z.y), z.z):
			return
	wall_rects.append(wall)


static func _rect_hits_circle(r: Rect2, c: Vector2, radius: float) -> bool:
	return c.clamp(r.position, r.end).distance_to(c) < radius


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = Config.LAYER_WORLD
	walls.collision_mask = 0
	var r: Rect2 = rect
	var t: float = Config.tiles(1)
	var pieces: Array[Rect2] = [
		Rect2(r.position.x - t, r.position.y - t, r.size.x + 2 * t, t),  # top
		Rect2(r.position.x - t, r.end.y, r.size.x + 2 * t, t),  # bottom
		Rect2(r.position.x - t, r.position.y, t, r.size.y),  # left
		Rect2(r.end.x, r.position.y, t, r.size.y),  # right
	]
	pieces.append_array(wall_rects)
	for p in pieces:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = p.size
		shape.shape = box
		shape.position = p.get_center()
		walls.add_child(shape)
	add_child(walls)


# --- Abyss shape (§6.12) ---

## A corridor up the middle of the map, passing through a circular arena. The rest is solid rock.
func _generate_abyss() -> void:
	wall_rects.clear()
	var tile: float = Config.tiles(1)
	var half_width: float = Config.tiles(Config.ABYSS_CORRIDOR_HALF_WIDTH_TILES)
	var arena: float = arena_radius()
	for y in size_in_tiles:
		var run_start: int = -1
		for x in size_in_tiles + 1:
			var center: Vector2 = rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * tile
			var solid: bool = x < size_in_tiles and absf(center.x) > half_width and center.length() > arena
			if solid and run_start < 0:
				run_start = x
			elif not solid and run_start >= 0:
				var origin: Vector2 = rect.position + Vector2(run_start, y) * tile
				wall_rects.append(Rect2(origin, Vector2(x - run_start, 1) * tile))
				run_start = -1


func arena_radius() -> float:
	return rect.size.x * Config.ABYSS_ARENA_RADIUS_FRACTION


# --- Wilds generation (§6.12) ---

func _generate_wilds(rng: RandomNumberGenerator) -> void:
	wall_rects.clear()
	_river.resize(size_in_tiles * size_in_tiles)
	_river.fill(0)
	var horizontal_first: bool = rng.randf() < 0.5
	_carve_river(rng, horizontal_first)
	_carve_river(rng, not horizontal_first)
	_clear_river_zones()
	_scatter_obstacles(rng)


## A meandering band across the whole map, kept out of the clear center.
func _carve_river(rng: RandomNumberGenerator, horizontal: bool) -> void:
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	var offset: float = side * rng.randf_range(Config.RIVER_MIN_OFFSET, Config.RIVER_MAX_OFFSET) * size_in_tiles
	var phase_a: float = rng.randf() * TAU
	var phase_b: float = rng.randf() * TAU
	var line := PackedVector2Array()
	var tile_px: float = Config.tiles(1)
	for along in range(-1, size_in_tiles + 2):
		var bend_out: float = sin(along * 0.21 + phase_a) * 2.0 + sin(along * 0.08 + phase_b) * 1.2
		var across_out: float = size_in_tiles * 0.5 + offset + bend_out
		var point: Vector2 = Vector2(along + 0.5, across_out) if horizontal else Vector2(across_out, along + 0.5)
		line.append(rect.position + point * tile_px)
	_river_lines.append(line)
	for _ripple in size_in_tiles * Config.RIVER_RIPPLES_PER_TILE:
		var spot: Vector2 = line[rng.randi_range(0, line.size() - 1)]
		var drift := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * tile_px * Config.RIVER_WIDTH_TILES * 0.3
		var flow: Vector2 = Vector2.RIGHT if horizontal else Vector2.DOWN
		_river_ripples.append(Rect2(spot + drift, flow * rng.randf_range(5.0, 14.0)))
	for along in size_in_tiles:
		var bend: float = sin(along * 0.21 + phase_a) * 2.0 + sin(along * 0.08 + phase_b) * 1.2
		var center: float = size_in_tiles * 0.5 + offset + bend
		for width in Config.RIVER_WIDTH_TILES:
			var across: int = clampi(floori(center - Config.RIVER_WIDTH_TILES * 0.5) + width, 0, size_in_tiles - 1)
			var tile := Vector2i(along, across) if horizontal else Vector2i(across, along)
			_river[tile.y * size_in_tiles + tile.x] = 1


## Clear zones become islands, so nothing important sits in the water.
func _clear_river_zones() -> void:
	var tile_px: float = Config.tiles(1)
	for y in size_in_tiles:
		for x in size_in_tiles:
			var pos: Vector2 = rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * tile_px
			for z in clear_zones:
				if pos.distance_to(Vector2(z.x, z.y)) < z.z:
					_river[y * size_in_tiles + x] = 0


func _scatter_obstacles(rng: RandomNumberGenerator) -> void:
	var target: int = size_in_tiles * size_in_tiles / Config.TILES_PER_OBSTACLE
	var area: Rect2 = rect.grow(-Config.tiles(2))
	var placed: Array[Vector2] = []
	for _attempt in target * 24:
		if placed.size() >= target:
			break
		var pos := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if _obstacle_fits(pos, placed):
			placed.append(pos)
			_add_obstacle(pos, rng)


func _obstacle_fits(pos: Vector2, placed: Array[Vector2]) -> bool:
	var tile_px: float = Config.tiles(1)
	if pos.length() < rect.size.x * 0.5 * Config.MAZE_CLEAR_CENTER_FRACTION:
		return false
	for z in clear_zones:
		if pos.distance_to(Vector2(z.x, z.y)) < z.z + tile_px:
			return false
	for offset: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if _river_tile(pos + offset * tile_px):
			return false
	# Wide gaps guarantee that nothing can ever be walled off, even for bosses.
	var spacing: float = Config.tiles(Config.OBSTACLE_SPACING_TILES)
	for other in placed:
		if pos.distance_to(other) < spacing:
			return false
	return true


func _add_obstacle(pos: Vector2, rng: RandomNumberGenerator) -> void:
	var half: float = Config.tiles(Config.OBSTACLE_SIZE_TILES) * 0.5
	wall_rects.append(Rect2(pos - Vector2(half, half), Vector2(half, half) * 2.0))
	var textures: Array[String] = TREE_TEXTURES if rng.randf() < Config.OBSTACLE_TREE_CHANCE else ROCK_TEXTURES
	props.append({"texture": textures[rng.randi_range(0, textures.size() - 1)], "position": pos + Vector2(0.0, half)})


## Speed multiplier for walking across `pos`.
func speed_mult_at(pos: Vector2) -> float:
	return Config.RIVER_SPEED_MULT if _river_tile(pos) else 1.0


func _river_tile(pos: Vector2) -> bool:
	if _river.is_empty():
		return false
	var p: Vector2 = (pos - rect.position) / Config.tiles(1)
	var tile := Vector2i(clampi(floori(p.x), 0, size_in_tiles - 1), clampi(floori(p.y), 0, size_in_tiles - 1))
	return _river[tile.y * size_in_tiles + tile.x] == 1


# --- Lava and floor cracks (§6.6) ---

## Each crack is a jagged line of Vector3(x, y, width). Lava burns only where a crack is drawn.
func _generate_lava(rng: RandomNumberGenerator) -> void:
	_lava.resize(size_in_tiles * size_in_tiles)
	_lava.fill(0)
	_lava_cracks = _grow_cracks(rng, size_in_tiles / Config.LAVA_TILES_PER_CRACK, Config.LAVA_CRACK_WIDTH)
	for crack: PackedVector3Array in _lava_cracks:
		for i in crack.size() - 1:
			_index_lava_segment(crack[i], crack[i + 1])


func _grow_cracks(rng: RandomNumberGenerator, count: int, width: float) -> Array[PackedVector3Array]:
	var cracks: Array[PackedVector3Array] = []
	for _crack in count:
		var start := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		var steps: int = rng.randi_range(Config.LAVA_CRACK_MIN_LENGTH, Config.LAVA_CRACK_MAX_LENGTH)
		_grow_crack(rng, cracks, start, rng.randf() * TAU, steps, width, true)
	return cracks


## Walks a jagged line that narrows to a point at both ends, and sometimes forks.
func _grow_crack(rng: RandomNumberGenerator, cracks: Array[PackedVector3Array], start: Vector2, heading: float, steps: int, width: float, can_fork: bool) -> void:
	var points := PackedVector3Array()
	var pos: Vector2 = start
	var forks: Array[Vector3] = []
	for step in steps:
		if not _crack_allowed(pos):
			break
		var along: float = float(step) / float(maxi(steps - 1, 1))
		points.append(Vector3(pos.x, pos.y, width * sin(along * PI) * rng.randf_range(0.7, 1.15)))
		if can_fork and rng.randf() < Config.LAVA_CRACK_FORK_CHANCE:
			var side: float = 1.0 if rng.randf() < 0.5 else -1.0
			forks.append(Vector3(pos.x, pos.y, heading + side * rng.randf_range(0.5, 1.0)))
		heading += rng.randf_range(-0.7, 0.7)
		pos += Vector2.from_angle(heading) * Config.tiles(rng.randf_range(0.5, 1.1))
	if points.size() >= 2:
		# A crack stopped early still narrows to a point.
		var last: Vector3 = points[points.size() - 1]
		points[points.size() - 1] = Vector3(last.x, last.y, 0.0)
		cracks.append(points)
	for fork: Vector3 in forks:
		_grow_crack(rng, cracks, Vector2(fork.x, fork.y), fork.z, steps / 2, width * 0.65, false)


func _crack_allowed(pos: Vector2) -> bool:
	if not rect.grow(-Config.tiles(0.5)).has_point(pos):
		return false
	if pos.length() < rect.size.x * 0.5 * Config.MAZE_CLEAR_CENTER_FRACTION:
		return false
	for z in clear_zones:
		if pos.distance_to(Vector2(z.x, z.y)) < z.z:
			return false
	return true


## Files a segment under every tile it crosses, so a lookup only checks nearby cracks.
func _index_lava_segment(a: Vector3, b: Vector3) -> void:
	var from := Vector2(a.x, a.y)
	var to := Vector2(b.x, b.y)
	var samples: int = ceili(from.distance_to(to) / (Config.tiles(1) * 0.5)) + 1
	for i in samples + 1:
		var tile: Vector2i = _tile_at(from.lerp(to, float(i) / float(samples)))
		var index: int = tile.y * size_in_tiles + tile.x
		_lava[index] = 1
		if not _lava_segments.has(index):
			_lava_segments[index] = []
		if not _lava_segments[index].has([a, b]):
			_lava_segments[index].append([a, b])


func _tile_at(pos: Vector2) -> Vector2i:
	var p: Vector2 = (pos - rect.position) / Config.tiles(1)
	return Vector2i(clampi(floori(p.x), 0, size_in_tiles - 1), clampi(floori(p.y), 0, size_in_tiles - 1))


func _lava_tile(pos: Vector2) -> bool:
	if _lava.is_empty():
		return false
	var tile: Vector2i = _tile_at(pos)
	for segment: Array in _lava_segments.get(tile.y * size_in_tiles + tile.x, []):
		var a: Vector3 = segment[0]
		var b: Vector3 = segment[1]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pos, Vector2(a.x, a.y), Vector2(b.x, b.y))
		if closest.distance_to(pos) <= maxf(a.z, b.z) * 0.5 + Config.LAVA_TOUCH_MARGIN_PX:
			return true
	return false


## A spot on a crack, for tests.
func lava_sample_point() -> Vector2:
	for crack: PackedVector3Array in _lava_cracks:
		var middle: Vector3 = crack[crack.size() / 2]
		if _lava_tile(Vector2(middle.x, middle.y)):
			return Vector2(middle.x, middle.y)
	return Vector2.ZERO


static func is_on_lava(walker: Node2D) -> bool:
	var world := walker.get_tree().get_first_node_in_group("world") as World
	return world != null and world._lava_tile(walker.global_position)


## Terrain speed multiplier for anything walking through the current layer.
static func terrain_speed_mult(walker: Node2D) -> float:
	var world := walker.get_tree().get_first_node_in_group("world") as World
	return world.speed_mult_at(walker.global_position) if world != null else 1.0


# --- Flow field (monster pathfinding) ---

func _build_nav_grid() -> void:
	_n = size_in_tiles
	_blocked = PackedByteArray()
	_blocked.resize(_n * _n)
	_dist = PackedInt32Array()
	_dist.resize(_n * _n)
	_dist.fill(-1)
	_queue = PackedInt32Array()
	_queue.resize(_n * _n)
	var tile: float = Config.tiles(1)
	var origin: Vector2 = rect.position
	for w in wall_rects:
		var g: Rect2 = w.grow(tile * 0.3)
		var x0: int = clampi(floori((g.position.x - origin.x) / tile), 0, _n - 1)
		var x1: int = clampi(floori((g.end.x - origin.x) / tile), 0, _n - 1)
		var y0: int = clampi(floori((g.position.y - origin.y) / tile), 0, _n - 1)
		var y1: int = clampi(floori((g.end.y - origin.y) / tile), 0, _n - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				_blocked[y * _n + x] = 1


func _tile_of(pos: Vector2) -> Vector2i:
	var p: Vector2 = (pos - rect.position) / Config.tiles(1)
	return Vector2i(clampi(floori(p.x), 0, _n - 1), clampi(floori(p.y), 0, _n - 1))


func _tile_center(t: Vector2i) -> Vector2:
	return rect.position + (Vector2(t) + Vector2(0.5, 0.5)) * Config.tiles(1)


## Breadth-first distances (in tiles) from the target's tile to every open tile.
func _update_flow(target: Vector2) -> void:
	_update_flow_from([target])


## Monsters head for whichever player is closest by path.
func _update_flow_from(targets: Array[Vector2]) -> void:
	if _n == 0:
		return
	_dist.fill(-1)
	var head: int = 0
	var tail: int = 0
	for target: Vector2 in targets:
		var s: Vector2i = _tile_of(target)
		var start: int = s.y * _n + s.x
		if _dist[start] == 0:
			continue
		_dist[start] = 0
		_queue[tail] = start
		tail += 1
	while head < tail:
		var i: int = _queue[head]
		head += 1
		var x: int = i % _n
		var d: int = _dist[i] + 1
		if x > 0 and _dist[i - 1] == -1 and _blocked[i - 1] == 0:
			_dist[i - 1] = d
			_queue[tail] = i - 1
			tail += 1
		if x < _n - 1 and _dist[i + 1] == -1 and _blocked[i + 1] == 0:
			_dist[i + 1] = d
			_queue[tail] = i + 1
			tail += 1
		if i >= _n and _dist[i - _n] == -1 and _blocked[i - _n] == 0:
			_dist[i - _n] = d
			_queue[tail] = i - _n
			tail += 1
		if i < _n * (_n - 1) and _dist[i + _n] == -1 and _blocked[i + _n] == 0:
			_dist[i + _n] = d
			_queue[tail] = i + _n
			tail += 1
	_flow_ready = true


## Direction a chaser at `from` should move to reach `target` (the player) around maze walls.
func flow_direction(from: Vector2, target: Vector2) -> Vector2:
	var direct: Vector2 = from.direction_to(target)
	if not _flow_ready:
		return direct
	var t: Vector2i = _tile_of(from)
	var here: int = _dist[t.y * _n + t.x]
	if here >= 0 and here <= 2:
		return direct
	var best: int = here if here >= 0 else 1 << 30
	var best_tile: Vector2i = t
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = t.x + dx
			var ny: int = t.y + dy
			if nx < 0 or ny < 0 or nx >= _n or ny >= _n:
				continue
			# No diagonal corner-cutting past walls.
			if dx != 0 and dy != 0 and (_blocked[t.y * _n + nx] == 1 or _blocked[ny * _n + t.x] == 1):
				continue
			var d: int = _dist[ny * _n + nx]
			if d >= 0 and d < best:
				best = d
				best_tile = Vector2i(nx, ny)
	if best_tile == t:
		return direct
	return from.direction_to(_tile_center(best_tile))


## A random dry tile that can be walked to from `from`, at least `min_distance` px from the map center.
func random_reachable_position(from: Vector2, min_distance: float) -> Vector2:
	_update_flow(from)
	var spots: Array[Vector2] = []
	for y in _n:
		for x in _n:
			var pos: Vector2 = _tile_center(Vector2i(x, y))
			if _dist[y * _n + x] >= 0 and pos.length() >= min_distance and not _river_tile(pos) and not _lava_tile(pos):
				spots.append(pos)
	return spots.pick_random() if not spots.is_empty() else from


## True if `pos` is free of maze walls (with a margin). Used to place things.
func is_open(pos: Vector2, margin: float = 0.0) -> bool:
	for w in wall_rects:
		if w.grow(margin).has_point(pos):
			return false
	return rect.grow(-margin).has_point(pos)


func _build_outdoor_decor(rng: RandomNumberGenerator) -> void:
	_decor.clear()
	var r: Rect2 = rect
	var area_scale: float = float(size_in_tiles * size_in_tiles) / 3600.0
	var grass_patches: int = int(round(95.0 * area_scale))
	var stones_count: int = int(round(65.0 * area_scale))
	var wilds: bool = terrain == LayerData.Terrain.WILDS
	var flowers_count: int = int(round(75.0 * area_scale)) if wilds else 0
	var bushes_count: int = int(round(45.0 * area_scale)) if wilds else 0
	var graves_count: int = int(round(70.0 * area_scale)) if has_graves else 0
	var plaza_r: float = Config.tiles(4.1)

	for _i in grass_patches:
		var p := Vector2(rng.randf_range(r.position.x + 24.0, r.end.x - 24.0), rng.randf_range(r.position.y + 24.0, r.end.y - 24.0))
		if p.length() > plaza_r + 16.0:
			_decor.append(Vector4(p.x, p.y, rng.randf_range(14.0, 38.0), 0.0 if rng.randf() < 0.5 else 1.0))

	for _i in stones_count:
		var p := Vector2(rng.randf_range(r.position.x + 20.0, r.end.x - 20.0), rng.randf_range(r.position.y + 20.0, r.end.y - 20.0))
		if p.length() > plaza_r * 0.85 and is_open(p, 8.0):
			_decor.append(Vector4(p.x, p.y, rng.randf_range(2.2, 4.4), 2.0))

	for _i in flowers_count:
		var p := Vector2(rng.randf_range(r.position.x + 20.0, r.end.x - 20.0), rng.randf_range(r.position.y + 20.0, r.end.y - 20.0))
		if p.length() > plaza_r + 8.0 and is_open(p, 8.0):
			_decor.append(Vector4(p.x, p.y, 1.5, 3.0 if rng.randf() < 0.55 else 4.0))

	for _i in bushes_count:
		var p := Vector2(rng.randf_range(r.position.x + 20.0, r.end.x - 20.0), rng.randf_range(r.position.y + 20.0, r.end.y - 20.0))
		if p.length() > plaza_r + 16.0 and is_open(p, 24.0) and not _river_tile(p):
			_decor.append(Vector4(p.x, p.y, 0.0, 5.0))

	for _i in graves_count:
		var p := Vector2(rng.randf_range(r.position.x + 20.0, r.end.x - 20.0), rng.randf_range(r.position.y + 20.0, r.end.y - 20.0))
		if p.length() > plaza_r and is_open(p, 24.0):
			_decor.append(Vector4(p.x, p.y, 0.0, 6.0 if rng.randf() < 0.6 else 7.0))


func _draw() -> void:
	var r: Rect2 = rect
	var tile: float = Config.tiles(1)
	var wilds: bool = terrain == LayerData.Terrain.WILDS
	# Deep forest-shadow perimeter outside map bounds
	draw_rect(r.grow(tile * 8.0), backdrop_color)

	var ground_tex: Texture2D = Config.get_tex(floor_texture)
	if ground_tex != null:
		draw_texture_rect(ground_tex, r, true, Color.WHITE)
	else:
		draw_rect(r, Color(0.22, 0.31, 0.18))

	# Non-repeating outdoor meadow variations (soft sunlit/shaded grass patches, pebbles, tiny wildflowers)
	for d in _decor:
		var p := Vector2(d.x, d.y)
		var kind: int = int(d.w)
		if kind == 0:
			if wilds:
				draw_circle(p, d.z, Color(0.1, 0.42, 0.14, 0.14))
		elif kind == 1:
			if wilds:
				draw_circle(p, d.z, Color(0.62, 0.88, 0.3, 0.12))
		elif kind == 2:
			draw_circle(p + Vector2(1.0, 1.2), d.z, Color(0.12, 0.17, 0.10, 0.35))
			draw_circle(p, d.z, Color(0.42, 0.44, 0.40, 0.65))
			draw_circle(p + Vector2(-0.6, -0.6), d.z * 0.55, Color(0.54, 0.56, 0.51, 0.55))
		elif kind == 3:
			draw_circle(p, 1.6, Color(0.92, 0.84, 0.36, 0.78))
		elif kind == 4:
			draw_circle(p, 1.5, Color(0.90, 0.94, 0.86, 0.72))
		else:
			var decor_path: String = "res://assets/sprites/world/bush_1.png"
			if kind > 5:
				decor_path = "res://assets/sprites/world/grave_%d.png" % (kind - 5)
			var decor_tex: Texture2D = Config.get_tex(decor_path)
			if decor_tex != null:
				draw_texture(decor_tex, p - decor_tex.get_size() * 0.5)

	_draw_dry_cracks()
	_draw_river()
	_draw_lava_cracks()

	# Soft packed-earth clearings beneath Gold Mines & Nests
	if wilds:
		for z in clear_zones:
			var zp := Vector2(z.x, z.y)
			var zr: float = minf(z.z * 0.62, Config.tiles(1.8))
			draw_circle(zp, zr * 1.15, Color(0.28, 0.25, 0.17, 0.24))
			draw_circle(zp, zr * 0.85, Color(0.34, 0.30, 0.20, 0.26))

	if wilds:
		# Outdoor cobblestone & packed-earth courtyard around the Kingdom Castle at (0, 0)
		var plaza_r: float = Config.tiles(3.9)
		draw_circle(Vector2.ZERO, plaza_r * 1.12, Color(0.30, 0.27, 0.19, 0.34))
		draw_circle(Vector2.ZERO, plaza_r, Color(0.33, 0.32, 0.29, 0.48))
		draw_arc(Vector2.ZERO, plaza_r, 0.0, TAU, 64, Color(0.46, 0.45, 0.41, 0.55), 2.5)
		draw_arc(Vector2.ZERO, plaza_r * 0.78, 0.0, TAU, 48, Color(0.76, 0.66, 0.34, 0.28), 1.5)
		_draw_forest_edge()
		return

	# Outer boundary wall
	var wall_tex: Texture2D = Config.get_tex(wall_textures[0])
	var bt: float = Config.tiles(0.75)
	var border_pieces: Array[Rect2] = [
		Rect2(r.position.x - bt, r.position.y - bt, r.size.x + 2.0 * bt, bt),
		Rect2(r.position.x - bt, r.end.y, r.size.x + 2.0 * bt, bt),
		Rect2(r.position.x - bt, r.position.y, bt, r.size.y),
		Rect2(r.end.x, r.position.y, bt, r.size.y),
	]
	for bp in border_pieces:
		draw_rect(Rect2(bp.position + Vector2(3, 5), bp.size), Color(0.05, 0.08, 0.04, 0.52))
		if wall_tex != null:
			draw_texture_rect(wall_tex, bp, true)
		else:
			draw_rect(bp, Color(0.32, 0.34, 0.38))
		draw_rect(bp, Color(0.18, 0.20, 0.22, 0.8), false, 1.5)

	# Maze walls
	var solid_rock: bool = terrain == LayerData.Terrain.ABYSS
	for i in wall_rects.size():
		var w: Rect2 = wall_rects[i]
		if solid_rock:
			draw_texture_rect(Config.get_tex(wall_textures[0]), w, true)
			continue
		draw_rect(Rect2(w.position + Vector2(3, 5), w.size), Color(0.05, 0.08, 0.04, 0.48))
		draw_rect(w.grow(1.5), Color(0.08, 0.08, 0.1))
		var maze_tex: Texture2D = Config.get_tex(wall_textures[i % wall_textures.size()])
		if maze_tex != null:
			draw_texture_rect(maze_tex, w, true)
		else:
			draw_rect(w, Color(0.32, 0.34, 0.38))
		draw_rect(w, Color(0.8, 0.8, 0.82, 0.12), false, 1.2)


## Rivers are drawn as bands along their paths, in depth layers, rather than tile by tile.
func _draw_river() -> void:
	if _river_lines.is_empty():
		return
	var width: float = Config.tiles(Config.RIVER_WIDTH_TILES)
	for line: PackedVector2Array in _river_lines:
		draw_polyline(line, Color(0.42, 0.33, 0.18), width + 8.0, true)
	for line: PackedVector2Array in _river_lines:
		draw_polyline(line, Color(0.3, 0.66, 0.84), width, true)
	for line: PackedVector2Array in _river_lines:
		draw_polyline(line, Color(0.2, 0.54, 0.78), width * 0.72, true)
	for line: PackedVector2Array in _river_lines:
		draw_polyline(line, Color(0.15, 0.45, 0.71), width * 0.38, true)
	for ripple: Rect2 in _river_ripples:
		draw_line(ripple.position, ripple.position + ripple.size, Color(0.72, 0.9, 0.97, 0.55), 1.5)
	# Clear zones are dry land, so anything important sits on an island.
	for z in clear_zones:
		var center := Vector2(z.x, z.y)
		if _river_near(center, z.z):
			draw_circle(center, z.z + 3.0, Color(0.42, 0.33, 0.18))
			draw_circle(center, z.z, Color(0.34, 0.72, 0.28))


func _river_near(center: Vector2, radius: float) -> bool:
	for line: PackedVector2Array in _river_lines:
		for point: Vector2 in line:
			if point.distance_to(center) < radius + Config.tiles(Config.RIVER_WIDTH_TILES) * 0.5:
				return true
	return false


## A crack is drawn as tapered layers: charred edge, molten body, bright core.
func _draw_lava_cracks() -> void:
	for crack: PackedVector3Array in _lava_cracks:
		_draw_crack_layer(crack, 2.6, 4.0, Color(0.1, 0.03, 0.02, 0.9))
	for crack: PackedVector3Array in _lava_cracks:
		_draw_crack_layer(crack, 1.0, 0.0, Color(0.93, 0.32, 0.06))
	for crack: PackedVector3Array in _lava_cracks:
		_draw_crack_layer(crack, 0.42, 0.0, Color(1.0, 0.82, 0.32))


func _draw_crack_layer(crack: PackedVector3Array, width_mult: float, extra: float, color: Color) -> void:
	for i in crack.size() - 1:
		var a: Vector3 = crack[i]
		var b: Vector3 = crack[i + 1]
		var from := Vector2(a.x, a.y)
		var to := Vector2(b.x, b.y)
		var side: Vector2 = (to - from).normalized().orthogonal()
		var half_a: float = a.z * width_mult * 0.5 + extra * 0.5
		var half_b: float = b.z * width_mult * 0.5 + extra * 0.5
		draw_colored_polygon(PackedVector2Array([from + side * half_a, to + side * half_b, to - side * half_b, from - side * half_a]), color)
		draw_circle(to, half_b, color)


## Harmless surface cracks, drawn straight onto the floor.
func _draw_dry_cracks() -> void:
	for crack: PackedVector3Array in _dry_cracks:
		_draw_crack_layer(crack, 1.0, 0.0, floor_crack_color)


## Rows of trees just outside the map, so the border reads as forest instead of a wall.
func _draw_forest_edge() -> void:
	var r: Rect2 = rect
	var step: float = Config.tiles(1.5)
	var count: int = ceili(r.size.x / step) + 2
	var tree_a: Texture2D = Config.get_tex(TREE_TEXTURES[0])
	var tree_b: Texture2D = Config.get_tex(TREE_TEXTURES[1])
	if tree_a == null or tree_b == null:
		return
	for row: float in [-2.2, -1.4, -0.6]:
		_draw_tree_line(r.position + Vector2(-step, Config.tiles(row)), Vector2(step, 0.0), count, tree_a, tree_b)
	for i in count:
		var y: float = r.position.y + step * float(i)
		_draw_edge_tree(Vector2(r.position.x - Config.tiles(0.9), y), i, tree_a, tree_b)
		_draw_edge_tree(Vector2(r.end.x + Config.tiles(0.9), y), i + 1, tree_a, tree_b)
	for row: float in [2.6, 3.4, 4.2]:
		_draw_tree_line(Vector2(r.position.x - step, r.end.y + Config.tiles(row)), Vector2(step, 0.0), count, tree_a, tree_b)


func _draw_tree_line(start: Vector2, step: Vector2, count: int, tree_a: Texture2D, tree_b: Texture2D) -> void:
	var row_shift: int = int(start.y) % 3
	for i in count:
		_draw_edge_tree(start + step * float(i), i + row_shift, tree_a, tree_b)


func _draw_edge_tree(base: Vector2, index: int, tree_a: Texture2D, tree_b: Texture2D) -> void:
	var tex: Texture2D = tree_b if index % 3 == 0 else tree_a
	draw_texture(tex, base - Vector2(tex.get_width() * 0.5, tex.get_height()))

