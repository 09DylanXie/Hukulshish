class_name MegaBoss
extends NestBoss
## The Pit Boss (§6.10). Emerges when the crystal shatters. Its HP ignores difficulty and depth.
## Fight: a regenerating shield, floor boss summons at each 1/4 of HP lost, and waves of every monster.
## At set HP in both forms it starts a Cataclysm: it can't be hit, and the arena turns on the team.
## Waiting: at 0% HP it lies inert until all four floor bosses are dead.
## Dragon: revives to full HP and flies over walls, attacking only with telegraphed fire lines.
## Hidden: what comes out of the dragon. A plainer fight with twice the HP, kept secret from the guide.

signal minion_spawned(minion: Node)

enum Phase {
	FIGHT,
	WAITING,
	DRAGON,
	HIDDEN,
}

const BossScene: PackedScene = preload("res://scenes/bosses/NestBoss.tscn")
const QUARTER_THRESHOLDS: Array[float] = [0.75, 0.50, 0.25]
const QUARTER_CATACLYSMS: Array[Cataclysm.Pattern] = [Cataclysm.Pattern.METEORS, Cataclysm.Pattern.SHOCKWAVES, Cataclysm.Pattern.COLLAPSE]
const DRAGON_THRESHOLDS: Array[float] = [0.75, 0.50, 0.25]
const DRAGON_CATACLYSMS: Array[Cataclysm.Pattern] = [Cataclysm.Pattern.INFERNO, Cataclysm.Pattern.DRAGONS_BREATH, Cataclysm.Pattern.FALLING_SKY]
const HIDDEN_THRESHOLDS: Array[float] = [0.66, 0.33]
const HIDDEN_CATACLYSMS: Array[Cataclysm.Pattern] = [Cataclysm.Pattern.METEORS, Cataclysm.Pattern.SHOCKWAVES]

var hp_mult: float = 1.0
var max_shield: float = Config.MEGA_BOSS_SHIELD_HP
var shield: float = Config.MEGA_BOSS_SHIELD_HP
var phase: Phase = Phase.FIGHT
## Off in Endless Mode, where the map edge supplies the monsters.
var spawns_monsters: bool = true

var _base_tint: Color = Color(0.6, 0.1, 0.6)
var _next_quarter_idx: int = 0
var _next_dragon_idx: int = 0
var _cataclysm: Cataclysm
## A guest's copy only knows that one is running.
var _net_cataclysm: bool = false
## How many floor bosses have been summoned, which is also the next one's layer index.
var _summons_made: int = 0
var _summons_alive: int = 0
var _waves: MonsterWaves = MonsterWaves.new()
var _fire_cooldown_left: float = Config.DRAGON_FIRE_INTERVAL_SEC
var _fire_line: FireLine
var _orbit_t: float = 0.0


func _init() -> void:
	max_hp = Config.MEGA_BOSS_HP
	hp = max_hp
	max_shield = Config.MEGA_BOSS_SHIELD_HP
	shield = max_shield
	gold = 0
	bolt_speed_tiles = Config.BASE_SPELL.speed_tiles
	_radius = Config.tiles(Config.MEGA_BOSS_RADIUS_TILES)
	color = Color(0.35, 0.05, 0.4)


func _spawn_protection_duration() -> float:
	return 0.0


func setup(tint: Color, mult: float) -> void:
	_base_tint = tint
	hp_mult = mult
	color = tint.darkened(0.5)
	max_hp = GameState.scaled_mega_boss_hp()
	hp = max_hp
	max_shield = Config.MEGA_BOSS_SHIELD_HP
	shield = max_shield
	_next_quarter_idx = 0


func scale_hp(mult: float) -> void:
	max_hp *= mult
	hp = max_hp


## Call before adding to the tree.
func make_hidden_boss() -> void:
	phase = Phase.HIDDEN
	spawns_monsters = false
	scale_hp(Config.HIDDEN_BOSS_HP_MULT)


func _ready() -> void:
	super._ready()
	add_to_group("mega_boss")


func _physics_process(delta: float) -> void:
	match phase:
		Phase.FIGHT, Phase.HIDDEN:
			if in_cataclysm():
				_anim_t += delta * 2.0
				queue_redraw()
			else:
				super._physics_process(delta)
			if not _dead and spawns_monsters:
				_spawn_monsters(delta)
		Phase.WAITING:
			_anim_t += delta * 2.0
			queue_redraw()
			if _summons_alive <= 0:
				_become_dragon()
		Phase.DRAGON:
			_dragon_process(delta)


func _spawn_monsters(delta: float) -> void:
	_waves.advance(delta, _place_minion)


## Floor bosses return in layer order, at the HP they had on their own layers.
func _summon_floor_boss() -> void:
	var layer: LayerData = Config.LAYERS[_summons_made]
	var boss: NestBoss = BossScene.instantiate()
	boss.setup(layer.monster.color, hp_mult)
	boss.max_hp = GameState.boss_hp_on_layer(_summons_made)
	boss.hp = boss.max_hp
	boss.take_look_of(layer.monster)
	_summons_made += 1
	_summons_alive += 1
	boss.tree_exited.connect(func() -> void: _summons_alive -= 1)
	AudioManager.play("boss_spawn")
	_place_minion(boss)


func _place_minion(node: Node2D) -> void:
	node.position = position + Vector2.from_angle(randf() * TAU) * (_radius + Config.tiles(1.0))
	get_parent().add_child(node)
	minion_spawned.emit(node)


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0 or phase == Phase.WAITING or in_cataclysm():
		return
	_flash = 0.1
	AudioManager.play_at("boss_hit", global_position)
	GameState.spawn_floating_text(
		global_position + Vector2(randf_range(-16, 16), -_radius),
		"-%d" % maxi(1, int(round(amount))),
		Color(0.45, 0.92, 1.0) if shield > 0.0 else Color(1.0, 0.38, 0.55)
	)
	if shield > 0.0:
		if amount <= shield:
			shield -= amount
			queue_redraw()
			return
		amount -= shield
		shield = 0.0

	hp -= amount
	if phase == Phase.FIGHT:
		_check_quarters()
	else:
		_check_phase_thresholds()
	queue_redraw()
	if hp > 0.0:
		return
	if phase == Phase.FIGHT:
		_start_waiting()
	else:
		_die()


## Each 1/4 of HP lost regenerates the shield and summons a floor boss. HP stops at the
## threshold, so one big hit can't skip a summon.
func _check_quarters() -> void:
	if _next_quarter_idx >= QUARTER_THRESHOLDS.size():
		return
	var threshold_hp: float = max_hp * QUARTER_THRESHOLDS[_next_quarter_idx]
	if hp > threshold_hp:
		return
	_next_quarter_idx += 1
	hp = threshold_hp
	shield = max_shield
	AudioManager.play("mega_boss_shield_regen")
	GameState.spawn_floating_text(global_position + Vector2(0, -_radius - 18.0), "SHIELD REGENERATED!", Color(0.35, 0.92, 1.0))
	GameState.request_shake(8.0, 0.25)
	_summon_floor_boss()
	_start_cataclysm(QUARTER_CATACLYSMS[_next_quarter_idx - 1])


## Like the quarters, one big hit can't skip these.
func _check_phase_thresholds() -> void:
	var is_dragon: bool = phase == Phase.DRAGON
	var thresholds: Array[float] = DRAGON_THRESHOLDS if is_dragon else HIDDEN_THRESHOLDS
	if _next_dragon_idx >= thresholds.size():
		return
	var threshold_hp: float = max_hp * thresholds[_next_dragon_idx]
	if hp > threshold_hp:
		return
	hp = threshold_hp
	_start_cataclysm(DRAGON_CATACLYSMS[_next_dragon_idx] if is_dragon else HIDDEN_CATACLYSMS[_next_dragon_idx])
	_next_dragon_idx += 1


func in_cataclysm() -> bool:
	return _cataclysm != null or _net_cataclysm


## Out of reach for the duration, so spells pass through and homing looks elsewhere.
func _start_cataclysm(pattern: Cataclysm.Pattern) -> void:
	velocity = Vector2.ZERO
	remove_from_group("targets")
	remove_from_group("bosses")
	collision_layer = 0
	_cataclysm = Cataclysm.new()
	_cataclysm.pattern = pattern
	_cataclysm.position = position
	_cataclysm.finished.connect(_end_cataclysm)
	get_parent().add_child(_cataclysm)


func _end_cataclysm() -> void:
	_cataclysm = null
	add_to_group("targets")
	if phase != Phase.DRAGON:
		add_to_group("bosses")
		collision_layer = Config.LAYER_ENEMIES


func _start_waiting() -> void:
	hp = 0.0
	phase = Phase.WAITING
	shield = max_shield
	velocity = Vector2.ZERO
	# Out of reach until phase 2, so homing ignores it.
	remove_from_group("targets")
	remove_from_group("bosses")
	collision_layer = 0
	GameState.request_shake(10.0, 0.3)
	_summon_floor_boss()


func _become_dragon() -> void:
	phase = Phase.DRAGON
	hp = max_hp
	shield = 0.0
	add_to_group("targets")
	# It flies over walls, so nothing collides with it.
	collision_mask = 0
	_radius = Config.tiles(Config.DRAGON_RADIUS_TILES)
	_fire_cooldown_left = Config.DRAGON_FIRE_INTERVAL_SEC
	AudioManager.play("dragon_transform")
	GameState.request_shake(14.0, 0.5)
	GameState.spawn_floating_text(global_position + Vector2(0, -_radius - 18.0), "THE DRAGON RISES!", Color(1.0, 0.4, 0.3))
	queue_redraw()


func _dragon_process(delta: float) -> void:
	_anim_t += delta * 5.0
	_orbit_t += delta
	if _flash > 0.0:
		_flash -= delta
	queue_redraw()
	if in_cataclysm():
		return
	status.update(delta, self)
	if _dead:
		return
	var player: Player = Player.nearest_living_player(get_tree(), global_position)
	if player == null:
		return
	var orbit: Vector2 = Vector2.from_angle(_orbit_t * Config.DRAGON_ORBIT_SPEED) * Config.tiles(Config.DRAGON_ORBIT_TILES)
	var speed: float = Config.tiles(Config.PLAYER_SPEED_TILES * Config.BOSS_SPEED_MULT) * status.speed_mult()
	var before: Vector2 = global_position
	global_position = global_position.move_toward(player.global_position + orbit, speed * delta)
	if absf(global_position.x - before.x) > 0.01:
		_facing_left = global_position.x < before.x

	if _fire_line != null:
		return
	_fire_cooldown_left -= delta
	if _fire_cooldown_left <= 0.0:
		_breathe_fire(player)


func _breathe_fire(player: Player) -> void:
	_fire_line = FireLine.new()
	_fire_line.setup(global_position, global_position.direction_to(player.global_position))
	_fire_line.finished.connect(_on_fire_line_finished)
	get_parent().add_child(_fire_line)


func _on_fire_line_finished() -> void:
	_fire_line = null
	_fire_cooldown_left = Config.DRAGON_FIRE_INTERVAL_SEC


func _die() -> void:
	_dead = true
	killing_player = _damage_owner
	GameState.request_shake(14.0, 0.45)
	AudioManager.play("mega_boss_death")
	if _fire_line != null:
		_fire_line.queue_free()
	if _cataclysm != null:
		_cataclysm.queue_free()
	_on_killed()
	died.emit(gold, global_position)
	queue_free()


## A guest's copy takes its state from the host.
func apply_net_phase(new_shield: float, new_phase: int, cataclysm_running: bool) -> void:
	shield = new_shield
	phase = new_phase as Phase
	_net_cataclysm = cataclysm_running
	if phase == Phase.DRAGON:
		_radius = Config.tiles(Config.DRAGON_RADIUS_TILES)


func _draw() -> void:
	if phase == Phase.DRAGON:
		_draw_dragon()
		return
	var r: float = _radius
	Config.draw_ground_shadow(self, r * 1.08, r * 0.72, 0.42)
	draw_circle(Vector2.ZERO, r * 1.22, Color(0.42, 0.1, 0.58, 0.25))

	var tex: Texture2D = Config.get_tex("res://assets/sprites/bosses/hidden_boss.png" if phase == Phase.HIDDEN else "res://assets/sprites/bosses/mega_boss.png")
	var bob: float = sin(_anim_t) * 1.8
	if tex != null:
		var idle_col: Color = Color(0.45, 0.42, 0.5) if phase == Phase.WAITING else Color.WHITE
		var mod_col: Color = Color(2.4, 2.4, 2.4, 1.0) if _flash > 0.0 else idle_col
		Config.draw_sprite_centered(
			self,
			tex,
			Vector2(0, bob),
			Vector2(r * 2.55, r * 2.55),
			mod_col,
			_facing_left
		)
	else:
		super._draw()

	# HP bar
	var w: float = r * 2.2
	var top: Vector2 = Vector2(-w * 0.5, -r - 14.0)
	draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 7)), Color(0, 0, 0, 0.82))
	draw_rect(Rect2(top, Vector2(w * maxf(hp, 0.0) / max_hp, 5)), Color(0.95, 0.2, 0.55))
	status.draw(self, r)

	if in_cataclysm():
		_draw_invulnerable(r)

	# Mega Boss regenerating shield aura & bar
	if shield > 0.0:
		var sr: float = r * 1.32
		draw_circle(Vector2.ZERO, sr, Color(0.2, 0.78, 1.0, 0.20))
		draw_arc(Vector2.ZERO, sr, 0.0, TAU, 36, Color(0.35, 0.9, 1.0, 0.92), 2.5)
		var s_top: Vector2 = Vector2(-w * 0.5, -r - 22.0)
		draw_rect(Rect2(s_top - Vector2(1, 1), Vector2(w + 2, 6)), Color(0, 0, 0, 0.82))
		draw_rect(Rect2(s_top, Vector2(w * clampf(shield / max_shield, 0.0, 1.0), 4)), Color(0.25, 0.85, 1.0))


func _draw_dragon() -> void:
	var r: float = _radius
	# A shadow far below, because it flies.
	draw_circle(Vector2(0, r * 1.5), r * 0.8, Color(0, 0, 0, 0.3))
	var tex: Texture2D = Config.get_tex("res://assets/sprites/bosses/dragon.png")
	var bob: float = sin(_anim_t) * 4.0
	if tex != null:
		var mod_col: Color = Color(2.4, 2.4, 2.4, 1.0) if _flash > 0.0 else Color.WHITE
		Config.draw_sprite_centered(self, tex, Vector2(0, bob), Vector2(r * 3.4, r * 2.7), mod_col, _facing_left)
	var w: float = r * 2.2
	var top: Vector2 = Vector2(-w * 0.5, -r * 1.4 - 12.0)
	draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 7)), Color(0, 0, 0, 0.82))
	draw_rect(Rect2(top, Vector2(w * maxf(hp, 0.0) / max_hp, 5)), Color(1.0, 0.35, 0.15))
	status.draw(self, r)
	if in_cataclysm():
		_draw_invulnerable(r)


func _draw_invulnerable(r: float) -> void:
	var pulse: float = 1.0 + 0.08 * sin(_anim_t * 2.0)
	draw_circle(Vector2.ZERO, r * 1.5 * pulse, Color(0.7, 0.2, 1.0, 0.22))
	draw_arc(Vector2.ZERO, r * 1.5 * pulse, 0.0, TAU, 40, Color(0.9, 0.7, 1.0, 0.95), 3.0)
