extends Node2D
## Root of a run (Normal mode). Builds the map + random maze, spawns the castle / player / nests / gold mines,
## and wires everything together with signals. Can be run directly with F6 (uses Medium/Medium).

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

## How far nests sit from the map corners, in tiles.
const NEST_CORNER_INSET_TILES: float = 4.0

var _entities: Node2D
var _fx_layer: Node2D
var _floating_texts: Array[Dictionary] = []
var _player: Player
var _castle_menu: CastleMenu
var _bounds: Rect2 = Rect2()
var _nest_positions: Array[Vector2] = []


func _ready() -> void:
	GameState.start_run()
	GameState.victory.connect(_on_victory)
	GameState.defeat.connect(_on_defeat)
	GameState.endless_wave_started.connect(_on_endless_wave_started)
	GameState.doppelganger_spawn_requested.connect(_on_doppelganger_spawn_requested)
	GameState.floating_text_requested.connect(_on_floating_text_requested)

	var map: MapSizeData = GameState.map_size
	var half: float = Config.tiles(map.size_in_tiles) * 0.5
	var bounds := Rect2(-half, -half, half * 2.0, half * 2.0)

	_nest_positions = _compute_nest_positions(bounds)
	var mine_positions: Array[Vector2] = _pick_gold_mine_positions(bounds, _nest_positions)

	var world: Node2D
	if map.scene != null:
		world = map.scene.instantiate()
	else:
		var w: World = WorldScene.instantiate()
		w.size_in_tiles = map.size_in_tiles
		var clear_radius: float = Config.tiles(3.0)
		for np in _nest_positions:
			w.clear_zones.append(Vector3(np.x, np.y, clear_radius))
		for mp in mine_positions:
			w.clear_zones.append(Vector3(mp.x, mp.y, clear_radius))
		world = w
	add_child(world)
	bounds = world.get("rect")
	_bounds = bounds

	# All moving things live here so they y-sort together.
	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.y_sort_enabled = true
	_entities.add_to_group("projectile_container")
	add_child(_entities)

	var castle: Castle = CastleScene.instantiate()
	castle.position = Vector2.ZERO
	add_child(castle)

	_player = PlayerScene.instantiate()
	_player.bounds = bounds
	_player.position = Vector2.ZERO
	_entities.add_child(_player)

	_spawn_nests(_nest_positions)
	_spawn_gold_mines(mine_positions)

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
	castle.player_entered.connect(_on_castle_entered)


func _on_castle_entered() -> void:
	if _player != null:
		_player.heal_at_castle()
	_castle_menu.open()


func _process(delta: float) -> void:
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



func _compute_nest_positions(bounds: Rect2) -> Array[Vector2]:
	var inset: float = Config.tiles(NEST_CORNER_INSET_TILES)
	return [
		bounds.position + Vector2(inset, inset),
		Vector2(bounds.end.x - inset, bounds.position.y + inset),
		Vector2(bounds.position.x + inset, bounds.end.y - inset),
		bounds.end - Vector2(inset, inset),
	]


func _pick_gold_mine_positions(bounds: Rect2, nest_positions: Array[Vector2]) -> Array[Vector2]:
	var half: float = bounds.size.x * 0.5
	var min_dist_center: float = Config.tiles(6.0)
	var max_dist_center: float = half - Config.tiles(6.0)
	var min_dist_nest: float = Config.tiles(7.0)
	var chosen: Array[Vector2] = []
	for i in Config.GOLD_MINE_COUNT:
		var pos := Vector2.ZERO
		for _attempt in 40:
			var angle: float = randf_range(0.0, TAU)
			var dist: float = randf_range(min_dist_center, maxf(min_dist_center + 32.0, max_dist_center))
			var cand: Vector2 = Vector2.from_angle(angle) * dist
			var ok: bool = true
			for np in nest_positions:
				if cand.distance_to(np) < min_dist_nest:
					ok = false
					break
			for prev in chosen:
				if cand.distance_to(prev) < Config.tiles(8.0):
					ok = false
					break
			if ok:
				pos = cand
				break
		if pos == Vector2.ZERO:
			var fallback_angle: float = float(i) * TAU / float(maxi(1, Config.GOLD_MINE_COUNT))
			pos = Vector2.from_angle(fallback_angle) * (half * 0.5)
		chosen.append(pos)
	return chosen


func _spawn_nests(corners: Array[Vector2]) -> void:
	for i in corners.size():
		var nest: Nest = NestScene.instantiate()
		nest.stats = Config.MONSTERS[i]
		nest.hp_mult = GameState.difficulty.hp_mult
		nest.position = corners[i]
		nest.monster_spawned.connect(_on_monster_spawned)
		nest.destroyed.connect(_on_nest_destroyed)
		_entities.add_child(nest)


func _spawn_gold_mines(positions: Array[Vector2]) -> void:
	for pos in positions:
		var mine: GoldMine = GoldMineScene.instantiate()
		mine.position = pos
		_entities.add_child(mine)


func _on_monster_spawned(monster: Monster) -> void:
	monster.died.connect(_on_monster_died)


func _on_monster_died(gold: int, pos: Vector2, is_demon: bool, drops_enhancer: bool) -> void:
	GameState.add_combat_gold(gold)
	var luck: float = GameState.luck_multiplier()
	if randf() < Config.MOD_PART_DROP_CHANCE * luck:
		var pickup: ModPickup = ModPickupScene.instantiate()
		pickup.kind = ModPickup.Kind.MOD_PART
		pickup.position = pos
		_entities.call_deferred("add_child", pickup)
	if is_demon and randf() < Config.AUG_SCROLL_DROP_CHANCE * luck:
		var aug_pickup: ModPickup = ModPickupScene.instantiate()
		aug_pickup.kind = ModPickup.Kind.AUG_SCROLL
		aug_pickup.position = pos + Vector2(12, 0)
		_entities.call_deferred("add_child", aug_pickup)
	if drops_enhancer and randf() < Config.ENHANCER_DROP_CHANCE * luck:
		var enh_pickup: ModPickup = ModPickupScene.instantiate()
		enh_pickup.kind = ModPickup.Kind.ENHANCER
		enh_pickup.position = pos + Vector2(-12, 0)
		_entities.call_deferred("add_child", enh_pickup)


func _on_nest_destroyed(nest: Nest) -> void:
	var pos: Vector2 = nest.position
	var tint: Color = nest.stats.color
	GameState.on_nest_destroyed()

	if GameState.nests_destroyed >= GameState.TOTAL_NESTS and not GameState.mega_boss_spawned:
		_spawn_mega_boss(pos, tint)

	# Nest boss spawns directly after destroying the nest (spawner).
	if not is_inside_tree() or GameState.run_over:
		return
	var boss: NestBoss = BossScene.instantiate()
	boss.setup(tint, GameState.difficulty.hp_mult)
	boss.position = pos
	boss.died.connect(_on_boss_died)
	_entities.call_deferred("add_child", boss)


func _spawn_mega_boss(pos: Vector2, tint: Color) -> void:
	GameState.on_mega_boss_spawned()
	var mega: MegaBoss = MegaBossScene.instantiate()
	mega.setup(tint, GameState.difficulty.hp_mult)
	mega.position = pos
	mega.minion_spawned.connect(_on_mega_minion_spawned)
	mega.duplicated_boss.connect(_on_mega_boss_duplicated)
	mega.died.connect(_on_mega_boss_died)
	_entities.call_deferred("add_child", mega)


func _on_mega_boss_duplicated(pos: Vector2, tint: Color, mult: float) -> void:
	if not is_inside_tree() or GameState.run_over or _entities == null:
		return
	var clone: MegaBoss = MegaBossScene.instantiate()
	clone.setup_as_duplicate(tint, mult)
	var spawn_pos: Vector2 = pos + Vector2(Config.tiles(2.2), 0.0)
	if _bounds.has_area():
		var r: float = Config.tiles(Config.MEGA_BOSS_RADIUS_TILES)
		spawn_pos = spawn_pos.clamp(_bounds.position + Vector2.ONE * r, _bounds.end - Vector2.ONE * r)
	clone.position = spawn_pos
	clone.minion_spawned.connect(_on_mega_minion_spawned)
	clone.died.connect(_on_mega_boss_died)
	_entities.call_deferred("add_child", clone)


func _on_mega_minion_spawned(minion: Node) -> void:
	if minion is Monster:
		(minion as Monster).died.connect(_on_monster_died)
	elif minion is NestBoss:
		(minion as NestBoss).died.connect(_on_boss_died)


func _on_boss_died(gold: int, pos: Vector2) -> void:
	GameState.add_combat_gold(gold)
	GameState.on_boss_defeated()
	if randf() < Config.BOSS_SPELL_DROP_CHANCE * GameState.luck_multiplier():
		var pickup: ModPickup = ModPickupScene.instantiate()
		pickup.kind = ModPickup.Kind.BOSS_SPELL
		pickup.position = pos
		_entities.call_deferred("add_child", pickup)


func _on_doppelganger_spawn_requested(snapshot: Dictionary) -> void:
	if not is_inside_tree() or _entities == null:
		return
	var dop: Node2D = DoppelgangerScript.new()
	dop.call("setup_from_snapshot", snapshot, _bounds)
	var base_pos: Vector2 = _player.global_position if _player != null else Vector2.ZERO
	dop.position = base_pos + Vector2(-Config.tiles(1.5), Config.tiles(1.0))
	_entities.add_child(dop)


func _on_mega_boss_died(_gold: int, pos: Vector2) -> void:
	var both_defeated: bool = GameState.on_mega_boss_defeated()
	if both_defeated and GameState.endless_mode:
		# Guaranteed 1/1 Mega Boss Spell drop when both Mega Bosses are defeated in Endless Mode.
		var pickup: ModPickup = ModPickupScene.instantiate()
		pickup.kind = ModPickup.Kind.MEGA_BOSS_SPELL
		pickup.position = pos
		_entities.call_deferred("add_child", pickup)


func _on_endless_wave_started(_wave: int) -> void:
	if not is_inside_tree() or GameState.run_over:
		return
	# Double the HP of any already-active monsters and bosses on the map.
	for node in get_tree().get_nodes_in_group("monsters"):
		var m := node as Monster
		if m != null and not m.is_queued_for_deletion():
			m.max_hp *= Config.ENDLESS_WAVE_HP_MULT
			m.hp *= Config.ENDLESS_WAVE_HP_MULT
	for node in get_tree().get_nodes_in_group("bosses"):
		var b := node as NestBoss
		if b != null and not b.is_queued_for_deletion():
			b.max_hp *= Config.ENDLESS_WAVE_HP_MULT
			b.hp *= Config.ENDLESS_WAVE_HP_MULT
	# Spawn 4 new spawners in the corners with 2× HP.
	call_deferred("_spawn_nests", _nest_positions)


func _on_victory() -> void:
	SceneRouter.goto(SceneRouter.VICTORY)


func _on_defeat() -> void:
	# Short pause so the player sees what happened.
	await get_tree().create_timer(1.0).timeout
	SceneRouter.goto(SceneRouter.GAME_OVER)
