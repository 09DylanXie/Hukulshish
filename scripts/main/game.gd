extends Node2D

signal coop_shop_entered(peer_id: int, section: ShopStall.Section)
## Root of a run (Normal mode). Builds each layer of the descent and wires everything together with signals.
## Can be run directly with F6 (uses Medium/Medium).

const WorldScene: PackedScene = preload("res://scenes/world/World.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player/Player.tscn")
const CastleScene: PackedScene = preload("res://scenes/castle/Castle.tscn")
const NestScene: PackedScene = preload("res://scenes/nests/Nest.tscn")
const BossScene: PackedScene = preload("res://scenes/bosses/NestBoss.tscn")
const MegaBossScene: PackedScene = preload("res://scenes/bosses/MegaBoss.tscn")
const ModPickupScene: PackedScene = preload("res://scenes/spells/ModPickup.tscn")
const GoldMineScene: PackedScene = preload("res://scenes/world/GoldMine.tscn")
const HUDScene: PackedScene = preload("res://scenes/ui/HUD.tscn")
const CastleMenuScene: PackedScene = preload("res://scenes/ui/CastleMenu.tscn")
const DoppelgangerScript: GDScript = preload("res://scripts/player/doppelganger.gd")

const MEGA_BOSS_TINT: Color = Color(0.6, 0.1, 0.6)
const TEAM_COLORS: Array[Color] = [Color.CORNFLOWER_BLUE, Color.MEDIUM_SEA_GREEN, Color.ORANGE]

var _entities: Node2D
var _fx_layer: Node2D
var _floating_texts: Array[Dictionary] = []
var _player: Player
var _castle_menu: CastleMenu
var _bounds: Rect2 = Rect2()
var _world: Node2D
var _castle: Castle
## The boss guarding this layer's portal.
var _layer_boss: NestBoss
var _darkness: Darkness
var _portal_position: Vector2 = Vector2.ZERO
var _descending: bool = false
var _coop_players: Dictionary = {}
var _revivals: CoopRevivalController
var _guest_view: CoopGuestView
var _crystal: AbyssCrystal
var _layer_seed: int = 0
var _keep_clear: Array[Vector2] = []
## Counts layers built, so guests can ignore snapshots from the layer before.
var _layer_token: int = 0
var _hidden_boss_fought: bool = false


func _ready() -> void:
	GameState.start_run()
	GameState.victory.connect(_on_victory)
	GameState.defeat.connect(_on_defeat)
	GameState.endless_started.connect(_begin_endless, CONNECT_DEFERRED)
	GameState.doppelganger_spawn_requested.connect(_on_doppelganger_spawn_requested)
	GameState.floating_text_requested.connect(_on_floating_text_requested)

	var half: float = Config.tiles(GameState.map_size.size_in_tiles) * 0.5
	_bounds = Rect2(-half, -half, half * 2.0, half * 2.0)

	# All moving things live here so they y-sort together.
	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.y_sort_enabled = true
	_entities.add_to_group("projectile_container")
	add_child(_entities)

	# The player persists across layers. Everything else is rebuilt by _build_layer().
	_player = PlayerScene.instantiate()
	_player.bounds = _bounds
	_player.position = _spawn_position(GameState.current_layer())
	if Coop.in_run:
		_player.team_color = TEAM_COLORS[Coop.local_seat - 1]
	if Coop.is_guest():
		_player.net_view = true
	_entities.add_child(_player)

	if not Coop.is_guest():
		_build_layer()

	_fx_layer = Node2D.new()
	_fx_layer.name = "FXLayer"
	_fx_layer.z_index = 15
	_fx_layer.draw.connect(_draw_fx_layer)
	add_child(_fx_layer)

	var hud: HUD = HUDScene.instantiate()
	add_child(hud)
	hud.bind_player(_player)

	_castle_menu = CastleMenuScene.instantiate()
	add_child(_castle_menu)
	if Coop.is_guest():
		_add_guest_views()
	elif GameState.coop_mode:
		_revivals = CoopRevivalController.new()
		_revivals.castle_position = _player.global_position
		if Coop.in_run:
			_revivals.team_size = Coop.seats.size()
			GameState.mine_share = 1.0 / float(Coop.seats.size())
		add_child(_revivals)
		_coop_players[1] = _player
		_revivals.register_player(1, _player)
	if Coop.is_host():
		var sync := CoopHostSync.new()
		sync.game = self
		add_child(sync)
	if Coop.in_run:
		Coop.attach_game(self)


## Called by the authoritative session once a guest has joined the run.
## The network transport supplies this player's remote input separately.
func add_coop_player(peer_id: int) -> Player:
	if not multiplayer.is_server() or GameState.run_over:
		return null
	if not GameState.coop_mode or _revivals == null or _coop_players.has(peer_id):
		return null
	if peer_id < 2 or peer_id > int(Config.COOP_RULES.player_count):
		return null
	var progress: RunState = RunState.new()
	progress.coop_mode = true
	progress.map_size = GameState.map_size
	progress.difficulty = GameState.difficulty
	add_child(progress)
	progress.start_run()
	if Coop.in_run:
		progress.mine_share = 1.0 / float(Coop.seats.size())
	progress.doppelganger_spawn_requested.connect(_on_doppelganger_spawn_requested.bind(progress))
	progress.floating_text_requested.connect(_on_floating_text_requested)
	var player: Player = PlayerScene.instantiate()
	player.progress = progress
	player.accepts_local_input = false
	player.bounds = _bounds
	player.team_color = TEAM_COLORS[peer_id - 1]
	player.position = _player.position
	_entities.add_child(player)
	_coop_players[peer_id] = player
	_revivals.register_player(peer_id, player)
	if _coop_players.size() == _revivals.team_size:
		_revivals.start()
	return player


## A guest disconnected. The run continues without them.
func remove_coop_player(seat: int) -> void:
	var player: Player = _coop_players.get(seat)
	if player == null:
		return
	_coop_players.erase(seat)
	if _revivals != null:
		_revivals.unregister_player(seat)
	for node: Node in get_tree().get_nodes_in_group("doppelgangers"):
		if node.get("progress") == player.progress:
			node.queue_free()
	var progress: RunState = player.progress
	player.free()
	progress.queue_free()


# --- Co-op: shared by the host's sync and the guest's view ---

func player_of_seat(seat: int) -> Player:
	return _coop_players.get(seat)


func local_player() -> Player:
	return _player


func entity_root() -> Node2D:
	return _entities


func entity_nodes() -> Array[Node]:
	return _entities.get_children()


func seated_players() -> Array[int]:
	var result: Array[int] = []
	for seat: int in _coop_players:
		result.append(seat)
	return result


func layer_token() -> int:
	return _layer_token


func players_in_void() -> int:
	var count: int = 0
	for player: Player in _team():
		if player.in_void:
			count += 1
	return count


## What a guest needs to rebuild this layer exactly: the map comes from the same seed.
func layer_message() -> Dictionary:
	return {
		"token": _layer_token,
		"index": GameState.layer_index,
		"seed": _layer_seed,
		"clear": PackedVector2Array(_keep_clear),
		"endless": GameState.endless_active,
	}


func _add_guest_views() -> void:
	_coop_players[Coop.local_seat] = _player
	for seat: int in Coop.team_seats():
		if seat == Coop.local_seat:
			continue
		var player: Player = PlayerScene.instantiate()
		player.net_view = true
		player.accepts_local_input = false
		player.bounds = _bounds
		player.team_color = TEAM_COLORS[seat - 1]
		_entities.add_child(player)
		_coop_players[seat] = player
	_guest_view = CoopGuestView.new()
	_guest_view.game = self
	add_child(_guest_view)


func load_guest_layer(message: Dictionary) -> void:
	if _world != null:
		_clear_layer()
		_guest_view.forget_all()
	_layer_token = int(message["token"])
	GameState.enter_net_layer(int(message["index"]), bool(message["endless"]))
	var layer: LayerData = GameState.current_layer()
	var spawn: Vector2 = _spawn_position(layer)
	_layer_seed = int(message["seed"])
	var keep_clear: Array[Vector2] = []
	keep_clear.assign(Array(message["clear"]))
	_add_world(keep_clear)
	_add_layer_scenery(layer)
	for player: Player in _team():
		player.place_at(spawn)
	if layer.has_darkness:
		_add_darkness()


func apply_snapshot(data: Dictionary) -> void:
	if _guest_view != null and _world != null and int(data["L"]) == _layer_token:
		_guest_view.apply(data)


func apply_mine_gold(stored: PackedFloat32Array) -> void:
	var mines: Array[Node] = get_tree().get_nodes_in_group("gold_mines")
	for i in mini(mines.size(), stored.size()):
		(mines[i] as GoldMine).set_stored(stored[i])


func apply_run_state(state: PackedFloat32Array) -> void:
	var stage := int(state[0]) as RunState.LayerStage
	var awake: bool = state[2] > 0.5
	if stage == RunState.LayerStage.PORTAL:
		_lift_darkness()
	if awake and _crystal != null:
		_crystal.queue_free()
		_crystal = null
	var dirty: bool = stage != GameState.layer_stage or awake != GameState.mega_boss_spawned \
		or int(state[1]) != GameState.layer_nests_left or int(state[3]) != GameState.endless_megas_defeated
	GameState.layer_stage = stage
	GameState.layer_nests_left = int(state[1])
	GameState.mega_boss_spawned = awake
	GameState.endless_megas_defeated = int(state[3])
	GameState.endless_next_boss_sec = state[4]
	GameState.nests_destroyed = int(state[6])
	GameState.bosses_defeated = int(state[7])
	if dirty:
		GameState.changed.emit()


func open_guest_shop(section: int) -> void:
	AudioManager.play("castle_enter")
	_castle_menu.open(section as ShopStall.Section)


func _on_shop_entered(player: Player, section: ShopStall.Section) -> void:
	if player == null or player.is_dead():
		return
	player.heal_at_shop()
	if player == _player:
		AudioManager.play("castle_enter")
		_castle_menu.open(section)
	elif GameState.coop_mode:
		for id: int in _coop_players:
			if _coop_players[id] == player:
				coop_shop_entered.emit(id, section)
				Coop.open_shop_for(id, section)
				break


func _physics_process(_delta: float) -> void:
	if not GameState.coop_mode or Coop.is_guest() or _descending:
		return
	# The team goes down together once everyone still standing is through the portal.
	var waiting: bool = false
	for player: Player in _team():
		if player.in_void:
			waiting = true
		elif not player.is_dead():
			return
	if waiting:
		_descending = true
		_descend.call_deferred()


## Worked out from what's on the map, so guests get the same answer as the host.
func _music_track() -> String:
	if GameState.endless_active:
		return "endless"
	var mega: MegaBoss = get_tree().get_first_node_in_group("mega_boss") as MegaBoss
	if mega != null:
		match mega.phase:
			MegaBoss.Phase.DRAGON:
				return "dragon"
			MegaBoss.Phase.HIDDEN:
				return "hidden_boss"
		return "mega_boss"
	if get_tree().get_first_node_in_group("bosses") != null:
		return "floor_boss"
	return GameState.current_layer().name.to_lower()


func _process(delta: float) -> void:
	# The end screen picks its own track, so the last boss's death doesn't flick back to the layer's.
	if not GameState.run_over:
		AudioManager.play_music(_music_track())
	if _floating_texts.is_empty():
		return
	var i: int = _floating_texts.size() - 1
	while i >= 0:
		var item: Dictionary = _floating_texts[i]
		var t: float = float(item["t"]) + delta
		if t >= float(item["dur"]):
			_floating_texts.remove_at(i)
		else:
			item["t"] = t
			item["pos"] = (item["pos"] as Vector2) + Vector2(0, -28.0 * delta)
		i -= 1
	if _fx_layer != null:
		_fx_layer.queue_redraw()


func _on_floating_text_requested(world_pos: Vector2, text: String, col: Color) -> void:
	Coop.share_text(world_pos, text, col)
	if _floating_texts.size() > 60:
		_floating_texts.pop_front()
	_floating_texts.append({
		"pos": world_pos,
		"text": text,
		"col": col,
		"t": 0.0,
		"dur": 0.75,
	})
	if _fx_layer != null:
		_fx_layer.queue_redraw()


func _draw_fx_layer() -> void:
	var font: Font = ThemeDB.fallback_font
	for item in _floating_texts:
		var ratio: float = clampf(1.0 - float(item["t"]) / float(item["dur"]), 0.0, 1.0)
		var pos: Vector2 = item["pos"] as Vector2
		var col: Color = item["col"] as Color
		var txt: String = String(item["text"])
		_fx_layer.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, 4, Color(0, 0, 0, ratio * 0.9))
		_fx_layer.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(col.r, col.g, col.b, ratio))



## Builds the current layer around the players: map, shop, nest (or Mega Boss) and gold mines.
func _build_layer() -> void:
	var layer: LayerData = GameState.current_layer()
	var spawn: Vector2 = _spawn_position(layer)
	var keep_clear: Array[Vector2] = [spawn]
	var nest_positions: Array[Vector2] = []
	if layer.monster != null and not GameState.endless_active:
		nest_positions = _pick_nest_positions()
		keep_clear.append_array(nest_positions)
	var mine_positions: Array[Vector2] = []
	if layer.has_gold_mines:
		mine_positions = _column_positions(Config.GOLD_MINE_COUNT, 1.0)
		keep_clear.append_array(mine_positions)
	var stall_positions: Array[Vector2] = []
	if layer.has_shop:
		stall_positions = _column_positions(ShopStall.Section.size(), -1.0)
		keep_clear.append_array(stall_positions)

	_keep_clear = keep_clear
	_layer_seed = randi_range(1, 2147483647)
	_layer_token += 1
	_add_world(keep_clear)

	if layer.has_castle:
		_castle = CastleScene.instantiate()
		_castle.position = Vector2.ZERO
		add_child(_castle)
	_spawn_shop(stall_positions)

	for player: Player in _team():
		player.place_at(spawn)
	for dop: Node in get_tree().get_nodes_in_group("doppelgangers"):
		(dop as Node2D).global_position = spawn + Vector2(-Config.tiles(1.5), Config.tiles(1.0))
	if _revivals != null:
		_revivals.castle_position = spawn

	GameState.set_layer_nests(nest_positions.size())
	for pos: Vector2 in nest_positions:
		_spawn_nest(pos, layer.monster)
	_spawn_gold_mines(mine_positions)
	if layer.unique_spell != null and not GameState.endless_active:
		_hide_unique_spell(layer.unique_spell, spawn)
	if layer.has_darkness:
		_add_darkness()
	if layer.is_final:
		_place_crystal()
		if _anyone_bought_nothing():
			_place_unique_spell(Config.ABYSSAL_CORRUPTION, Vector2(0.0, _bounds.position.y + Config.tiles(Config.FINAL_LAYER_SPAWN_INSET_TILES)))


## What a guest draws for a layer, built from the same rules as the host's.
func _add_layer_scenery(layer: LayerData) -> void:
	if layer.has_castle:
		_castle = CastleScene.instantiate()
		_castle.position = Vector2.ZERO
		add_child(_castle)
	if layer.has_shop:
		_spawn_shop(_column_positions(ShopStall.Section.size(), -1.0))
	if layer.has_gold_mines:
		_spawn_gold_mines(_column_positions(Config.GOLD_MINE_COUNT, 1.0))
	if layer.is_final:
		_place_crystal()


func _add_darkness() -> void:
	_darkness = Darkness.new()
	_darkness.target = _player
	_darkness.bounds = _bounds
	add_child(_darkness)


func _anyone_bought_nothing() -> bool:
	for player: Player in _team():
		if player.progress.nothing_unlocked:
			return true
	return false


func _place_crystal() -> void:
	var crystal := AbyssCrystal.new()
	_crystal = crystal
	if Coop.is_guest():
		crystal.monitoring = false
	crystal.shattered.connect(_spawn_mega_boss.bind(Vector2.ZERO, MEGA_BOSS_TINT), CONNECT_DEFERRED)
	_entities.add_child(crystal)


func _hide_unique_spell(spell: SpellData, spawn: Vector2) -> void:
	var min_distance: float = _bounds.size.x * 0.5 * Config.UNIQUE_SPELL_MIN_CENTER_FRACTION
	_place_unique_spell(spell, (_world as World).random_reachable_position(spawn, min_distance) if _world is World else spawn)


func _place_unique_spell(spell: SpellData, pos: Vector2) -> void:
	var pickup: ModPickup = ModPickupScene.instantiate()
	pickup.kind = ModPickup.Kind.UNIQUE_SPELL
	pickup.spell = spell
	pickup.position = pos
	_entities.add_child(pickup)


func _add_world(keep_clear: Array[Vector2]) -> void:
	var map: MapSizeData = GameState.map_size
	if map.scene != null:
		_world = map.scene.instantiate()
	else:
		var w: World = WorldScene.instantiate()
		w.size_in_tiles = map.size_in_tiles
		w.apply_layer(GameState.current_layer())
		w.rng_seed = _layer_seed
		var clear_radius: float = Config.tiles(3.0)
		for pos in keep_clear:
			w.clear_zones.append(Vector3(pos.x, pos.y, clear_radius))
		_world = w
	add_child(_world)
	move_child(_world, 0)
	if _world is World:
		_spawn_props((_world as World).props)


## Trees and rocks join the y-sorted entities so characters can walk behind them.
func _spawn_props(props: Array[Dictionary]) -> void:
	for prop: Dictionary in props:
		var sprite := Sprite2D.new()
		sprite.texture = Config.get_tex(String(prop["texture"]))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = prop["position"] as Vector2
		if sprite.texture != null:
			sprite.offset = Vector2(0.0, -sprite.texture.get_height() * 0.5)
		_entities.add_child(sprite)


func _team() -> Array[Player]:
	var team: Array[Player] = [_player]
	for player: Player in _coop_players.values():
		if player != _player:
			team.append(player)
	return team


## Removes everything that belongs to the current layer, keeping players and doppelgangers.
func _clear_layer() -> void:
	var mines: Array[Node] = get_tree().get_nodes_in_group("gold_mines")
	if not mines.is_empty() and not Coop.is_guest():
		var stored: int = 0
		for mine: Node in mines:
			stored += (mine as GoldMine).stored_gold()
		for player: Player in _team():
			player.progress.leave_mines_behind(stored)
	for child: Node in _entities.get_children():
		if child is Player or child.is_in_group("doppelgangers"):
			continue
		child.free()
	if _castle != null:
		_castle.free()
		_castle = null
	_world.free()
	_world = null
	_layer_boss = null
	_crystal = null
	_lift_darkness()


func _lift_darkness() -> void:
	if _darkness != null:
		_darkness.queue_free()
		_darkness = null


func _on_portal_entered(player: Player) -> void:
	if GameState.coop_mode:
		player.enter_void()
		return
	if not _descending:
		_descending = true
		_descend.call_deferred()


## Deferred, because physics callbacks can't remove collision objects.
func _descend() -> void:
	if GameState.run_over or not GameState.descend():
		return
	AudioManager.play("portal_enter")
	_clear_layer()
	_build_layer()
	_sync_team_layers()
	_descending = false


## Each player's own state has to agree with the host's about where the team is.
func _sync_team_layers() -> void:
	for player: Player in _team():
		player.progress.layer_index = GameState.layer_index
	Coop.broadcast_layer(layer_message())


func _spawn_position(layer: LayerData) -> Vector2:
	if layer.is_final:
		return Vector2(0.0, _bounds.end.y - Config.tiles(Config.FINAL_LAYER_SPAWN_INSET_TILES))
	return Vector2.ZERO


## Random edge spots, kept apart so that clearing a layer means crossing the map.
func _pick_nest_positions() -> Array[Vector2]:
	var spacing: float = Config.tiles(Config.NEST_MIN_SPACING_TILES)
	var positions: Array[Vector2] = []
	for _i in Config.nests_on_layer(GameState.layer_index):
		var pos: Vector2 = _random_edge_position()
		for _attempt in 40:
			var clear: bool = true
			for other: Vector2 in positions:
				clear = clear and pos.distance_to(other) >= spacing
			if clear:
				break
			pos = _random_edge_position()
		positions.append(pos)
	return positions


## A random spot near one of the map's 4 edges (§6.7).
func _random_edge_position() -> Vector2:
	var inset: float = Config.tiles(Config.NEST_EDGE_INSET_TILES)
	var area: Rect2 = _bounds.grow(-inset)
	var along: float = randf()
	match randi_range(0, 3):
		0:
			return area.position + Vector2(area.size.x * along, 0.0)
		1:
			return Vector2(area.position.x + area.size.x * along, area.end.y)
		2:
			return area.position + Vector2(0.0, area.size.y * along)
		_:
			return Vector2(area.end.x, area.position.y + area.size.y * along)


## An evenly spaced row beside the map center. `side` is -1 for left, 1 for right.
func _column_positions(count: int, side: float) -> Array[Vector2]:
	var spacing: float = Config.tiles(Config.CASTLE_COLUMN_SPACING_TILES)
	var positions: Array[Vector2] = []
	for i in count:
		var along: float = (float(i) - float(count - 1) * 0.5) * spacing
		positions.append(Vector2(side * Config.tiles(Config.CASTLE_COLUMN_OFFSET_TILES), along))
	return positions


func _spawn_shop(positions: Array[Vector2]) -> void:
	for i in positions.size():
		var stall := ShopStall.new()
		stall.section = ShopStall.Section.values()[i] as ShopStall.Section
		stall.position = positions[i]
		# On guests the host decides who walked in.
		stall.monitoring = not Coop.is_guest()
		stall.entered.connect(_on_shop_entered)
		_entities.add_child(stall)


func _spawn_nest(pos: Vector2, stats: MonsterStats) -> void:
	var nest: Nest = NestScene.instantiate()
	nest.stats = stats
	nest.hp_mult = GameState.difficulty.hp_mult
	nest.position = pos
	nest.monster_spawned.connect(_on_monster_spawned)
	nest.destroyed.connect(_on_nest_destroyed)
	_entities.add_child(nest)


func _spawn_gold_mines(positions: Array[Vector2]) -> void:
	# Returning in Endless Mode, the mines hold what built up while the player was below.
	var share: float = GameState.take_mine_gold() / float(positions.size()) if not positions.is_empty() else 0.0
	for pos in positions:
		var mine: GoldMine = GoldMineScene.instantiate()
		mine.position = pos
		if Coop.is_guest():
			mine.monitoring = false
			mine.process_mode = Node.PROCESS_MODE_DISABLED
		_entities.add_child(mine)
		mine.add_stored(share)


func _on_monster_spawned(monster: Monster) -> void:
	monster.died.connect(_on_monster_died.bind(monster))


func _on_monster_died(gold: int, pos: Vector2, monster: Monster) -> void:
	# Endless monsters drop nothing, not even gold (§6.13). Nor do the Abyss's, which would only
	# clutter the fight, unless the shops are coming back afterwards.
	if GameState.endless_active or (GameState.current_layer().is_final and not GameState.endless_mode):
		return
	GameState.award_kill_gold(gold, monster.killing_player)
	var killer: RunState = monster.killing_player if GameState.coop_mode else GameState
	if killer == GameState:
		AudioManager.play("gold_pickup")
	var stats: MonsterStats = monster.stats
	if stats.guaranteed_drop:
		# Luck doesn't apply here (§6.8).
		var kind: ModPickup.Kind = ModPickup.Kind.ENHANCER if randf() < 0.5 else ModPickup.Kind.MOD_PART
		_drop_pickups(kind, randi_range(Config.GUARANTEED_DROP_MIN, Config.GUARANTEED_DROP_MAX), pos)
		return
	var luck: int = killer.luck_multiplier() if is_instance_valid(killer) else 1
	if randf() < stats.enhancer_chance:
		_drop_pickups(ModPickup.Kind.ENHANCER, luck, pos + Vector2(-12, 0))
	if randf() < stats.scroll_chance:
		_drop_pickups(ModPickup.Kind.MOD_PART, luck, pos + Vector2(12, 0))


func _drop_pickups(kind: ModPickup.Kind, count: int, pos: Vector2) -> void:
	for i in count:
		var pickup: ModPickup = ModPickupScene.instantiate()
		pickup.kind = kind
		pickup.position = pos + Vector2.from_angle(float(i) * TAU / float(count)) * Config.tiles(0.8)
		_entities.call_deferred("add_child", pickup)


func _on_nest_destroyed(nest: Nest) -> void:
	var pos: Vector2 = nest.position
	var tint: Color = nest.stats.color
	GameState.on_nest_destroyed()
	if GameState.layer_nests_left > 0:
		return

	# Nest boss spawns directly after destroying the nest (spawner).
	if not is_inside_tree() or GameState.run_over:
		return
	var boss: NestBoss = BossScene.instantiate()
	boss.setup(tint, GameState.difficulty.hp_mult)
	boss.take_look_of(nest.stats)
	boss.escort_stats = nest.stats
	boss.escort_spawned.connect(_on_monster_spawned)
	boss.position = pos
	boss.died.connect(_on_boss_died.bind(boss))
	_layer_boss = boss
	_portal_position = pos
	_entities.call_deferred("add_child", boss)
	AudioManager.play("boss_spawn")


func _spawn_mega_boss(pos: Vector2, tint: Color, hidden: bool = false) -> void:
	GameState.on_mega_boss_spawned()
	AudioManager.play("mega_boss_spawn")
	var mega: MegaBoss = MegaBossScene.instantiate()
	mega.setup(tint, GameState.difficulty.hp_mult)
	if hidden:
		mega.make_hidden_boss()
	if GameState.endless_active:
		mega.scale_hp(GameState.endless_mega_hp_mult())
		mega.spawns_monsters = false
	mega.position = pos
	mega.minion_spawned.connect(_on_mega_minion_spawned)
	mega.died.connect(_on_mega_boss_died)
	_entities.call_deferred("add_child", mega)


func _on_mega_minion_spawned(minion: Node) -> void:
	if minion is Monster:
		(minion as Monster).died.connect(_on_monster_died.bind(minion))
	elif minion is NestBoss:
		(minion as NestBoss).died.connect(_on_boss_died.bind(minion))


func _on_boss_died(gold: int, pos: Vector2, boss: NestBoss) -> void:
	GameState.on_boss_defeated()
	# Bosses summoned by the Mega Boss drop nothing (§6.9).
	if boss != _layer_boss:
		return
	_layer_boss = null
	GameState.award_kill_gold(gold, boss.killing_player)
	var killer: RunState = boss.killing_player if GameState.coop_mode else GameState
	if killer == GameState:
		AudioManager.play("gold_mine_collect")
	_drop_pickups(ModPickup.Kind.AUG_SCROLL, randi_range(Config.BOSS_AUG_SCROLL_DROP_MIN, Config.BOSS_AUG_SCROLL_DROP_MAX), pos)
	GameState.on_layer_boss_defeated()
	_lift_darkness()
	_open_portal.call_deferred(_portal_position)


func _open_portal(pos: Vector2) -> void:
	var portal := Portal.new()
	portal.position = pos
	portal.entered.connect(_on_portal_entered)
	_entities.add_child(portal)


func _on_doppelganger_spawn_requested(snapshot: Dictionary, progress: RunState = null) -> void:
	if not is_inside_tree() or _entities == null or Coop.is_guest():
		return
	if progress == null:
		progress = GameState
	var dop: Node2D = DoppelgangerScript.new()
	dop.set("progress", progress)
	dop.call("setup_from_snapshot", snapshot, _bounds)
	var owner_player: Player = _player
	for player: Player in _coop_players.values():
		if player.progress == progress:
			owner_player = player
			break
	var base_pos: Vector2 = owner_player.global_position if owner_player != null else Vector2.ZERO
	dop.position = base_pos + Vector2(-Config.tiles(1.5), Config.tiles(1.0))
	_entities.add_child(dop)


func _on_mega_boss_died(_gold: int, pos: Vector2) -> void:
	# The first dragon to fall gives way to the hidden boss, which ends the fight for real.
	if not GameState.endless_active and not _hidden_boss_fought and not GameState.run_over:
		_hidden_boss_fought = true
		GameState.spawn_floating_text(pos, "SOMETHING CRAWLS OUT...", Color(0.75, 0.4, 1.0))
		_spawn_mega_boss(pos, MEGA_BOSS_TINT, true)
		return
	GameState.on_mega_boss_defeated()


func _begin_endless() -> void:
	_clear_layer()
	GameState.start_endless()
	_build_layer()
	_sync_team_layers()
	AudioManager.play("endless_wave")
	var director := EndlessDirector.new()
	director.place_monster = _place_endless_monster
	director.spawn_mega_boss = func() -> void: _spawn_mega_boss(_open_edge_position(), MEGA_BOSS_TINT)
	add_child(director)


func _place_endless_monster(monster: Monster) -> void:
	monster.position = _open_edge_position()
	_on_monster_spawned(monster)
	_entities.add_child(monster)


## A spot near the map edge that isn't inside a tree or rock.
func _open_edge_position() -> Vector2:
	var pos: Vector2 = _random_edge_position()
	for _attempt in 20:
		if not _world is World or (_world as World).is_open(pos, Config.tiles(1)):
			break
		pos = _random_edge_position()
	return pos


## The game ends with a flash of white (§5).
func _on_victory() -> void:
	Coop.announce_end(true)
	AudioManager.play("victory")
	if not GameState.coop_mode:
		get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	var tween: Tween = flash.create_tween()
	tween.tween_property(flash, "color:a", 1.0, Config.VICTORY_FLASH_SEC)
	await tween.finished
	SceneRouter.goto(SceneRouter.VICTORY)


func _on_defeat() -> void:
	Coop.announce_end(false)
	# Short pause so the player sees what happened.
	await get_tree().create_timer(1.0).timeout
	AudioManager.play("defeat")
	SceneRouter.goto(SceneRouter.GAME_OVER)
