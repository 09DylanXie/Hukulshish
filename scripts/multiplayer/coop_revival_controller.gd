class_name CoopRevivalController
extends Node
## Host-owned life cycle for a three-player team. A dead player's node stays at
## the death position until the revive interaction and castle return both finish.

signal revival_started(reviver_id: int, target_id: int)
signal revival_progressed(reviver_id: int, target_id: int, seconds: float)
signal revival_interrupted(reviver_id: int, target_id: int)
signal respawn_scheduled(target_id: int, seconds: float)
signal player_respawned(peer_id: int)
signal team_defeated

var castle_position: Vector2 = Vector2.ZERO
var running: bool = false
var ended: bool = false
var _players: Dictionary = {}
var _channels: Dictionary = {}
var _respawns: Dictionary = {}


func register_player(peer_id: int, player: Player) -> bool:
	if running or peer_id <= 0 or _players.has(peer_id):
		return false
	if _players.size() >= int(Config.COOP_RULES.player_count):
		return false
	if not is_instance_valid(player) or player.progress == null or not player.progress.coop_mode:
		return false
	_players[peer_id] = player
	player.died.connect(_on_player_downed.bind(peer_id))
	return true


func start() -> bool:
	if running or ended or _players.size() != int(Config.COOP_RULES.player_count):
		return false
	for player: Player in _players.values():
		if not is_instance_valid(player) or player.is_dead() or player.progress.run_over:
			return false
	running = true
	return true


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		advance(delta)


## Separate from the frame callback so timing can be tested without wall-clock waits.
func advance(delta: float) -> void:
	if not running or ended or delta <= 0.0 or not is_finite(delta):
		return
	if _check_team_defeat():
		return
	# Only timers that existed before this tick advance. A newly completed
	# three-second interaction always receives its full five-second delay.
	for id: int in _respawns.keys():
		_respawns[id] = maxf(0.0, float(_respawns[id]) - delta)
		if float(_respawns[id]) <= 0.0:
			var player: Player = _players[id]
			_respawns.erase(id)
			if is_instance_valid(player) and player.revive_at_castle(castle_position):
				player_respawned.emit(id)

	# Invalid interactions are removed before another player may claim a body.
	for reviver_id: int in _channels.keys():
		var channel: Dictionary = _channels[reviver_id]
		if not _can_revive(reviver_id, int(channel["target"])):
			_interrupt(reviver_id)

	var ids: Array = _players.keys()
	ids.sort()
	for reviver_id: int in ids:
		if not _channels.has(reviver_id):
			for target_id: int in ids:
				if _can_revive(reviver_id, target_id) and not _body_claimed(target_id):
					_channels[reviver_id] = {"target": target_id, "seconds": 0.0}
					revival_started.emit(reviver_id, target_id)
					break
		if not _channels.has(reviver_id):
			continue
		var channel: Dictionary = _channels[reviver_id]
		var target_id: int = channel["target"]
		channel["seconds"] = float(channel["seconds"]) + delta
		var required: float = Config.COOP_RULES.revival_interaction_seconds
		revival_progressed.emit(reviver_id, target_id, minf(float(channel["seconds"]), required))
		if float(channel["seconds"]) >= required:
			_channels.erase(reviver_id)
			var delay: float = Config.COOP_RULES.revival_respawn_seconds
			_respawns[target_id] = delay
			var target: Player = _players[target_id]
			target.respawn_pending = true
			target.queue_redraw()
			respawn_scheduled.emit(target_id, delay)


func respawn_seconds(peer_id: int) -> float:
	return float(_respawns.get(peer_id, 0.0))


func interaction_seconds(peer_id: int) -> float:
	var channel: Dictionary = _channels.get(peer_id, {})
	return float(channel.get("seconds", 0.0))


func _can_revive(reviver_id: int, target_id: int) -> bool:
	if reviver_id == target_id or not _players.has(reviver_id) or not _players.has(target_id):
		return false
	var reviver: Player = _players[reviver_id]
	var target: Player = _players[target_id]
	if not is_instance_valid(reviver) or not is_instance_valid(target):
		return false
	if reviver.is_dead() or not target.is_dead() or target.respawn_pending:
		return false
	if not reviver.progress.revival_unlocked or reviver.progress.run_over:
		return false
	# "Stand over the body" means the existing player footprints overlap.
	# This reuses the player radius rather than introducing a new balance distance.
	var overlap_distance: float = Config.tiles(Config.PLAYER_RADIUS_TILES) * 2.0
	return reviver.global_position.distance_squared_to(target.global_position) <= overlap_distance * overlap_distance


func _body_claimed(target_id: int) -> bool:
	for channel: Dictionary in _channels.values():
		if int(channel["target"]) == target_id:
			return true
	return false


func _interrupt(reviver_id: int) -> void:
	if _channels.has(reviver_id):
		var target_id: int = _channels[reviver_id]["target"]
		_channels.erase(reviver_id)
		revival_interrupted.emit(reviver_id, target_id)


func _on_player_downed(peer_id: int) -> void:
	_interrupt(peer_id)
	if running:
		_check_team_defeat()


func _check_team_defeat() -> bool:
	for player: Player in _players.values():
		if is_instance_valid(player) and not player.is_dead():
			return false
	# All three at zero HP ends the run immediately, including a teammate whose
	# castle return was already queued. Pending timers cannot undo a team wipe.
	ended = true
	running = false
	_channels.clear()
	_respawns.clear()
	for player: Player in _players.values():
		if is_instance_valid(player):
			player.respawn_pending = false
			player.progress.end_run_in_defeat()
	team_defeated.emit()
	return true
