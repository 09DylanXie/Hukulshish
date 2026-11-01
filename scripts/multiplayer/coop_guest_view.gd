class_name CoopGuestView
extends Node2D
## A guest's picture of the host's world. Characters are the real scenes with their logic switched
## off, so they look identical. Short-lived things like spells are simply drawn here.

const MonsterScene: PackedScene = preload("res://scenes/monsters/Monster.tscn")
const BossScene: PackedScene = preload("res://scenes/bosses/NestBoss.tscn")
const MegaBossScene: PackedScene = preload("res://scenes/bosses/MegaBoss.tscn")
const NestScene: PackedScene = preload("res://scenes/nests/Nest.tscn")
const ModPickupScene: PackedScene = preload("res://scenes/spells/ModPickup.tscn")
const PLAYER_STRIDE: int = 8
const MONSTER_STRIDE: int = 7
const BOSS_STRIDE: int = 11
const HATCHLING_STRIDE: int = 6
const NEST_STRIDE: int = 6
const PICKUP_STRIDE: int = 5
## How quickly drawn positions catch up with snapshots, per second.
const SMOOTHING: float = 14.0

## The Game node this draws for.
var game: Node

## Host entity ID -> node on this machine.
var _nodes: Dictionary = {}
## Node -> latest position from the host.
var _targets: Dictionary = {}
var _shots := PackedFloat32Array()
var _zones := PackedFloat32Array()
var _lines := PackedFloat32Array()
var _twins := PackedFloat32Array()
var _hazards := PackedFloat32Array()
var _arcs := PackedFloat32Array()
var _portal: Portal


func _ready() -> void:
	z_index = 5


## Everything drawn here was removed along with the old layer.
func forget_all() -> void:
	_nodes.clear()
	_targets.clear()
	_portal = null


func _process(delta: float) -> void:
	var weight: float = 1.0 - exp(-SMOOTHING * delta)
	for node: Variant in _targets.keys():
		if not is_instance_valid(node):
			_targets.erase(node)
			continue
		(node as Node2D).position = (node as Node2D).position.lerp(_targets[node], weight)


func apply(data: Dictionary) -> void:
	_apply_players(data["p"])
	var seen: Dictionary = {}
	_apply_monsters(data["m"], seen)
	_apply_bosses(data["b"], seen)
	_apply_hatchlings(data["h"], seen)
	_apply_nests(data["n"], seen)
	_apply_pickups(data["i"], seen)
	_remove_unseen(seen)
	_shots = data["s"]
	_zones = data["z"]
	_lines = data["l"]
	_twins = data["d"]
	_hazards = data["c"]
	_arcs = data["a"]
	_apply_portal(data["o"])
	game.apply_mine_gold(data["g"])
	game.apply_run_state(data["r"])
	for event: Array in data["e"]:
		_play_event(event)
	queue_redraw()


func _remove_unseen(seen: Dictionary) -> void:
	for net_id: int in _nodes.keys():
		if seen.has(net_id):
			continue
		var node: Node = _nodes[net_id]
		_nodes.erase(net_id)
		_targets.erase(node)
		if is_instance_valid(node):
			node.queue_free()


func _apply_players(data: PackedFloat32Array) -> void:
	for i in range(0, data.size(), PLAYER_STRIDE):
		var player: Player = game.player_of_seat(int(data[i]))
		if player == null:
			continue
		var pos := Vector2(data[i + 1], data[i + 2])
		player.apply_net(pos, data[i + 3], int(data[i + 4]), int(data[i + 5]), int(data[i + 6]), int(data[i + 7]))
		if player != game.local_player():
			_targets[player] = pos


func _add_view(net_id: int, node: Node2D, pos: Vector2, seen: Dictionary) -> void:
	node.position = pos
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_nodes[net_id] = node
	seen[net_id] = true
	game.entity_root().add_child(node)


func _apply_monsters(data: PackedFloat32Array, seen: Dictionary) -> void:
	for i in range(0, data.size(), MONSTER_STRIDE):
		var net_id: int = int(data[i])
		var pos := Vector2(data[i + 2], data[i + 3])
		seen[net_id] = true
		if not _nodes.has(net_id):
			var monster: Monster = MonsterScene.instantiate()
			monster.setup(Config.MONSTERS[int(data[i + 1])], 1.0)
			_add_view(net_id, monster, pos, seen)
		var view: Monster = _nodes[net_id]
		_targets[view] = pos
		view.apply_net(data[i + 4], data[i + 5], int(data[i + 6]))


func _apply_bosses(data: PackedFloat32Array, seen: Dictionary) -> void:
	for i in range(0, data.size(), BOSS_STRIDE):
		var net_id: int = int(data[i])
		var pos := Vector2(data[i + 3], data[i + 4])
		seen[net_id] = true
		if not _nodes.has(net_id):
			_add_view(net_id, _make_boss(data[i + 1] > 0.5, int(data[i + 2])), pos, seen)
		var view: NestBoss = _nodes[net_id]
		_targets[view] = pos
		view.apply_net(data[i + 5], data[i + 6], data[i + 9] > 0.5)
		if view is MegaBoss:
			(view as MegaBoss).apply_net_phase(data[i + 7], int(data[i + 8]), data[i + 10] > 0.5)


func _apply_hatchlings(data: PackedFloat32Array, seen: Dictionary) -> void:
	for i in range(0, data.size(), HATCHLING_STRIDE):
		var net_id: int = int(data[i])
		var pos := Vector2(data[i + 1], data[i + 2])
		seen[net_id] = true
		if not _nodes.has(net_id):
			_add_view(net_id, DragonHatchling.new(), pos, seen)
		var view: DragonHatchling = _nodes[net_id]
		_targets[view] = pos
		view.apply_net(data[i + 3], data[i + 4], data[i + 5] > 0.5)


func _make_boss(is_mega: bool, look: int) -> NestBoss:
	var boss: NestBoss = MegaBossScene.instantiate() if is_mega else BossScene.instantiate()
	if look >= 0:
		boss.take_look_of(Config.MONSTERS[look])
	return boss


func _apply_nests(data: PackedFloat32Array, seen: Dictionary) -> void:
	for i in range(0, data.size(), NEST_STRIDE):
		var net_id: int = int(data[i])
		seen[net_id] = true
		if not _nodes.has(net_id):
			var nest: Nest = NestScene.instantiate()
			nest.stats = Config.MONSTERS[int(data[i + 1])]
			_add_view(net_id, nest, Vector2(data[i + 2], data[i + 3]), seen)
		(_nodes[net_id] as Nest).apply_net(data[i + 4], data[i + 5])


func _apply_pickups(data: PackedFloat32Array, seen: Dictionary) -> void:
	for i in range(0, data.size(), PICKUP_STRIDE):
		var net_id: int = int(data[i])
		seen[net_id] = true
		if _nodes.has(net_id):
			continue
		var pickup: ModPickup = ModPickupScene.instantiate()
		pickup.kind = int(data[i + 1]) as ModPickup.Kind
		pickup.spell = Config.unique_spell_at(int(data[i + 2]))
		pickup.monitoring = false
		_add_view(net_id, pickup, Vector2(data[i + 3], data[i + 4]), seen)


func _apply_portal(data: PackedFloat32Array) -> void:
	if data.is_empty() or _portal != null:
		return
	_portal = Portal.new()
	_portal.is_view = true
	_portal.position = Vector2(data[0], data[1])
	game.entity_root().add_child(_portal)


func _play_event(event: Array) -> void:
	match str(event[0]):
		"s":
			if bool(event[3]):
				AudioManager.play_at(str(event[1]), event[2])
			else:
				AudioManager.play(str(event[1]))
		"t":
			GameState.spawn_floating_text(event[1], str(event[2]), event[3])
		"k":
			GameState.request_shake(float(event[1]), float(event[2]))


func _draw() -> void:
	Cataclysm.draw_shapes(self, _hazards)
	for i in range(0, _zones.size(), 4):
		var center := Vector2(_zones[i], _zones[i + 1])
		var fade: float = _zones[i + 3]
		draw_circle(center, _zones[i + 2], Color(0.95, 0.22, 0.05, 0.24 * fade))
		draw_circle(center, _zones[i + 2] * 0.6, Color(1.0, 0.55, 0.08, 0.28 * fade))
		draw_arc(center, _zones[i + 2], 0.0, TAU, 40, Color(1.0, 0.52, 0.12, 0.9 * fade), 2.5)
	for i in range(0, _lines.size(), 6):
		_draw_fire_line(i)
	for i in range(0, _twins.size(), 2):
		var twin := Vector2(_twins[i], _twins[i + 1])
		draw_circle(twin, Config.tiles(0.4), Color(0.55, 0.25, 0.95, 0.5))
		draw_arc(twin, Config.tiles(0.4), 0.0, TAU, 20, Color(0.8, 0.6, 1.0, 0.85), 1.5)
	for i in range(0, _arcs.size(), 4):
		Projectile.draw_arc_between(self, Vector2(_arcs[i], _arcs[i + 1]), Vector2(_arcs[i + 2], _arcs[i + 3]))
	for i in range(0, _shots.size(), 7):
		var color := Color(_shots[i + 4], _shots[i + 5], _shots[i + 6])
		var pos := Vector2(_shots[i], _shots[i + 1])
		var tail: Vector2 = pos - Vector2.from_angle(_shots[i + 2]) * 12.0
		draw_line(tail, pos, Color(color, 0.5), _shots[i + 3] * 0.9)
		draw_circle(pos, maxf(_shots[i + 3] * 0.7, 3.0), color)


func _draw_fire_line(i: int) -> void:
	var start := Vector2(_lines[i], _lines[i + 1])
	var end: Vector2 = start + Vector2.from_angle(_lines[i + 2]) * _lines[i + 4]
	if _lines[i + 3] > 0.5:
		draw_line(start, end, Color(1.0, 0.5, 0.1, 0.9), _lines[i + 5] * 2.4)
		draw_line(start, end, Color(1.0, 0.88, 0.4, 0.95), _lines[i + 5] * 1.1)
	else:
		draw_line(start, end, Color(1.0, 0.25, 0.1, 0.55), _lines[i + 5])
