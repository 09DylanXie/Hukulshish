class_name World
extends Node2D
## Generated map: a square field centered on (0, 0) with border walls and a random, spacious maze
## in the outer part of the map (§6.9). A new maze is generated every run.
## Also provides a flow field so monsters can path through the maze toward the player.
## Set `size_in_tiles` and `clear_zones` before adding to the tree.

## How often the flow field toward the player is recomputed.
const FLOW_INTERVAL_SEC: float = 0.25

var size_in_tiles: int = 60
## Circles kept free of maze walls (nests, gold mines …). Each Vector3 = (center.x, center.y, radius) in px.
var clear_zones: Array[Vector3] = []
## Fixed seed for testing. 0 = random every run.
var rng_seed: int = 0

## Maze wall rectangles in local (= global) px.
var wall_rects: Array[Rect2] = []

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


func _ready() -> void:
	add_to_group("world")
	z_index = -10
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	_generate_maze(rng)
	_build_walls()
	_build_nav_grid()


func _physics_process(delta: float) -> void:
	_flow_timer -= delta
	if _flow_timer > 0.0:
		return
	_flow_timer = FLOW_INTERVAL_SEC
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_update_flow(player.global_position)


# --- Maze generation ---

func _generate_maze(rng: RandomNumberGenerator) -> void:
	wall_rects.clear()
	var n: int = size_in_tiles / Config.MAZE_CELL_TILES
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
		if right[i] == 1 and rng.randf() < Config.MAZE_EXTRA_OPENING_CHANCE:
			right[i] = 0
		if down[i] == 1 and rng.randf() < Config.MAZE_EXTRA_OPENING_CHANCE:
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
	if _n == 0:
		return
	_dist.fill(-1)
	var s: Vector2i = _tile_of(target)
	var start: int = s.y * _n + s.x
	_dist[start] = 0
	_queue[0] = start
	var head: int = 0
	var tail: int = 1
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


## True if `pos` is free of maze walls (with a margin). Used to place things.
func is_open(pos: Vector2, margin: float = 0.0) -> bool:
	for w in wall_rects:
		if w.grow(margin).has_point(pos):
			return false
	return rect.grow(-margin).has_point(pos)


func _draw() -> void:
	var r: Rect2 = rect
	var tile: float = Config.tiles(1)
	draw_rect(r.grow(tile * 4), Color(0.08, 0.1, 0.08))
	draw_rect(r, Color(0.22, 0.42, 0.22))
	# Checker grass every 2 tiles
	var cell: float = tile * 2.0
	var cols: int = int(r.size.x / cell)
	var alt := Color(0.2, 0.39, 0.2)
	for x in cols:
		for y in cols:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(r.position + Vector2(x, y) * cell, Vector2(cell, cell)), alt)
	draw_rect(r, Color(0.35, 0.25, 0.15), false, 4.0)
	# Maze walls (hedge-stone look)
	for w in wall_rects:
		draw_rect(w.grow(2.0), Color(0.12, 0.14, 0.12))
		draw_rect(w, Color(0.45, 0.47, 0.42))
