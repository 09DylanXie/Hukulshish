class_name CoopHostSync
extends Node
## Packs the host's world into a snapshot for guests. Packed float arrays keep each one small,
## and every entity kind has a fixed stride that CoopGuestView unpacks.

const SNAPSHOT_INTERVAL_SEC: float = 0.05
const BOSS_LOOK_NONE: float = -1.0

## The Game node this reports on.
var game: Node

var _timer: float = 0.0
var _next_id: int = 1


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer < SNAPSHOT_INTERVAL_SEC:
		return
	_timer = 0.0
	Coop.send_snapshot(build())


func _net_id(node: Node) -> float:
	if not node.has_meta("net_id"):
		node.set_meta("net_id", _next_id)
		_next_id += 1
	return float(node.get_meta("net_id"))


func build() -> Dictionary:
	var monsters := PackedFloat32Array()
	var bosses := PackedFloat32Array()
	var nests := PackedFloat32Array()
	var shots := PackedFloat32Array()
	var pickups := PackedFloat32Array()
	var zones := PackedFloat32Array()
	var lines := PackedFloat32Array()
	var mines := PackedFloat32Array()
	var twins := PackedFloat32Array()
	var portal := PackedFloat32Array()
	var hazards := PackedFloat32Array()
	var arcs := PackedFloat32Array()
	for node: Node in game.entity_nodes():
		if node is Monster:
			_add_monster(monsters, node as Monster)
		elif node is MegaBoss or node is NestBoss:
			_add_boss(bosses, node as NestBoss)
		elif node is Nest:
			_add_nest(nests, node as Nest)
		elif node is Projectile:
			_add_shot(shots, node as Projectile)
			if (node as Projectile).has_arc():
				var start: Vector2 = (node as Projectile).global_position
				var end: Vector2 = (node as Projectile).arc_end()
				arcs.append_array([start.x, start.y, end.x, end.y])
		elif node is ModPickup:
			_add_pickup(pickups, node as ModPickup)
		elif node is FireZone:
			_add_zone(zones, node as FireZone)
		elif node is FireLine:
			_add_line(lines, node as FireLine)
		elif node is GoldMine:
			mines.append((node as GoldMine).stored_gold())
		elif node is Doppelganger:
			twins.append_array([(node as Node2D).position.x, (node as Node2D).position.y])
		elif node is Cataclysm:
			hazards.append_array((node as Cataclysm).net_shapes())
		elif node is Portal:
			portal.append_array([(node as Node2D).position.x, (node as Node2D).position.y])
	return {
		"L": game.layer_token(),
		"p": _players(),
		"m": monsters,
		"b": bosses,
		"n": nests,
		"s": shots,
		"i": pickups,
		"z": zones,
		"l": lines,
		"g": mines,
		"d": twins,
		"o": portal,
		"c": hazards,
		"a": arcs,
		"r": _run_state(),
	}


func _players() -> PackedFloat32Array:
	var data := PackedFloat32Array()
	for seat: int in game.seated_players():
		var player: Player = game.player_of_seat(seat)
		data.append_array([
			float(seat), player.position.x, player.position.y, player.aim_angle(),
			float(player.hp), float(player.max_hp), float(player.shield), float(player.net_flags()),
		])
	return data


func _run_state() -> PackedFloat32Array:
	return PackedFloat32Array([
		float(GameState.layer_stage),
		float(GameState.layer_nests_left),
		1.0 if GameState.mega_boss_spawned else 0.0,
		float(GameState.endless_megas_defeated),
		GameState.endless_next_boss_sec,
		float(game.players_in_void()),
		float(GameState.nests_destroyed),
		float(GameState.bosses_defeated),
	])


func _add_monster(data: PackedFloat32Array, monster: Monster) -> void:
	var flags: int = (1 if monster.has_bubble_shield() else 0) | (2 if monster.facing_left() else 0)
	data.append_array([
		_net_id(monster), float(Config.MONSTERS.find(monster.stats)), monster.position.x, monster.position.y,
		monster.hp, monster.max_hp, float(flags),
	])


func _add_boss(data: PackedFloat32Array, boss: NestBoss) -> void:
	var is_mega: bool = boss is MegaBoss
	var look: float = BOSS_LOOK_NONE if boss.look_stats == null else float(Config.MONSTERS.find(boss.look_stats))
	data.append_array([
		_net_id(boss), 1.0 if is_mega else 0.0, look, boss.position.x, boss.position.y, boss.hp, boss.max_hp,
		(boss as MegaBoss).shield if is_mega else 0.0, float((boss as MegaBoss).phase) if is_mega else 0.0,
		1.0 if boss.facing_left() else 0.0,
		1.0 if is_mega and (boss as MegaBoss).in_cataclysm() else 0.0,
	])


func _add_nest(data: PackedFloat32Array, nest: Nest) -> void:
	data.append_array([_net_id(nest), float(Config.MONSTERS.find(nest.stats)), nest.position.x, nest.position.y, nest.hp, nest.max_hp])


func _add_shot(data: PackedFloat32Array, shot: Projectile) -> void:
	if shot.is_spent():
		return
	data.append_array([shot.global_position.x, shot.global_position.y, shot.direction.angle(), shot.radius, shot.color.r, shot.color.g, shot.color.b])


func _add_pickup(data: PackedFloat32Array, pickup: ModPickup) -> void:
	data.append_array([_net_id(pickup), float(pickup.kind), float(Config.unique_spell_index(pickup.spell)), pickup.position.x, pickup.position.y])


func _add_zone(data: PackedFloat32Array, zone: FireZone) -> void:
	data.append_array([zone.global_position.x, zone.global_position.y, zone.radius, clampf(1.0 - zone.elapsed_ratio() * 0.45, 0.2, 1.0)])


func _add_line(data: PackedFloat32Array, line: FireLine) -> void:
	data.append_array([line.global_position.x, line.global_position.y, line.rotation, 1.0 if line.is_burning() else 0.0, line.length, line.width])
