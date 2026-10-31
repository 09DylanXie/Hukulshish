class_name Doppelganger
extends CharacterBody2D
## Spectral twin of the player bought in the Gold Shop for 5000 gold.
## Copies the player's current abilities at purchase time, follows the player around,
## has 5 max HP, and can never have a shield.

signal died

const ProjectileScene: PackedScene = preload("res://scenes/spells/Projectile.tscn")

var max_hp: int = Config.DOPPELGANGER_MAX_HP
var hp: int = Config.DOPPELGANGER_MAX_HP
var bounds: Rect2 = Rect2()
var progress: RunState

var _spells: Array[Dictionary] = []
var _aug_levels: Dictionary = {}
var _homing_copied: bool = false
var _speed_tiles: float = Config.PLAYER_SPEED_TILES
var _regen_per_10s: int = 0
var _regen_timer: float = 0.0
var _cooldowns: Array[float] = []

var _iframes: float = 0.0
var _melee_hurt_cooldown: float = 0.0
var _dead: bool = false
var _radius: float = Config.tiles(Config.PLAYER_RADIUS_TILES)
var _aim_dir: Vector2 = Vector2.RIGHT


func setup_from_snapshot(snapshot: Dictionary, map_bounds: Rect2) -> void:
	if progress == null:
		progress = GameState
	bounds = map_bounds
	max_hp = Config.DOPPELGANGER_MAX_HP
	hp = max_hp
	_spells.clear()
	var raw_spells: Array = snapshot.get("spells", [])
	for s in raw_spells:
		if s is Dictionary:
			_spells.append((s as Dictionary).duplicate(true))
	_aug_levels = (snapshot.get("aug_levels", {}) as Dictionary).duplicate()
	_homing_copied = bool(snapshot.get("homing", false))
	_speed_tiles = float(snapshot.get("speed_tiles", Config.PLAYER_SPEED_TILES))
	_regen_per_10s = int(snapshot.get("health_regen", 0))
	_cooldowns.clear()
	for _i in _spells.size():
		_cooldowns.append(0.0)


func _ready() -> void:
	if progress == null:
		progress = GameState
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("doppelgangers")
	collision_layer = Config.LAYER_PLAYER
	collision_mask = Config.LAYER_WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	if _dead:
		return

	var player: Player
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is Player and (node as Player).progress == progress:
			player = node as Player
			break
	if player != null and not player.is_dead():
		var follow_offset := Vector2(-Config.tiles(1.6), Config.tiles(1.1))
		var desired_pos: Vector2 = player.global_position + follow_offset
		var to_desired: Vector2 = desired_pos - global_position
		var dist: float = to_desired.length()
		if dist > Config.tiles(0.25):
			var speed_factor: float = clampf(dist / Config.tiles(1.5), 0.35, 1.25)
			velocity = to_desired.normalized() * Config.tiles(_speed_tiles) * speed_factor
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		if bounds.has_area():
			global_position = global_position.clamp(
				bounds.position + Vector2.ONE * _radius,
				bounds.end - Vector2.ONE * _radius
			)

	# Copied health regen (capped at 5 max HP; never has a shield)
	if _regen_per_10s > 0 and hp < max_hp:
		_regen_timer += delta
		if _regen_timer >= Config.HEALTH_REGEN_INTERVAL_SEC:
			_regen_timer -= Config.HEALTH_REGEN_INTERVAL_SEC
			hp = mini(max_hp, hp + _regen_per_10s)
	else:
		_regen_timer = 0.0

	if _iframes > 0.0:
		_iframes -= delta
	if _melee_hurt_cooldown > 0.0:
		_melee_hurt_cooldown -= delta
	else:
		_check_enemy_contact_damage()

	_update_weapons(delta)
	queue_redraw()


func _check_enemy_contact_damage() -> void:
	if _dead or _iframes > 0.0:
		return
	for node in get_tree().get_nodes_in_group("monsters"):
		var m := node as Monster
		if m == null or m.is_queued_for_deletion() or m.stats == null:
			continue
		var reach: float = _radius + m.get_hit_radius() + 4.0
		if global_position.distance_to(m.global_position) <= reach:
			take_damage(m.stats.damage)
			_melee_hurt_cooldown = Config.MONSTER_ATTACK_COOLDOWN_SEC
			return
	for node in get_tree().get_nodes_in_group("bosses"):
		var b := node as NestBoss
		if b == null or b.is_queued_for_deletion():
			continue
		var reach: float = _radius + b.get_hit_radius() + 4.0
		if global_position.distance_to(b.global_position) <= reach:
			take_damage(Config.BOSS_MELEE_DAMAGE)
			_melee_hurt_cooldown = Config.MONSTER_ATTACK_COOLDOWN_SEC
			return


func _update_weapons(delta: float) -> void:
	var manual_click: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_viewport().gui_get_hovered_control() == null
	var mouse_world: Vector2 = get_global_mouse_position()

	for i in _spells.size():
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
		if _cooldowns[i] > 0.0:
			continue
		var spell: Dictionary = _spells[i]
		var max_range: float = Config.tiles(float(spell["range_tiles"]))
		var base_rate: float = maxf(0.05, float(spell["fire_rate"]))

		var dir: Vector2 = global_position.direction_to(mouse_world)
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		_aim_dir = dir
		if manual_click:
			_fire_spell(spell, dir, max_range)
			_cooldowns[i] = 1.0 / base_rate
		else:
			_fire_spell(spell, dir, max_range)
			var auto_rate: float = maxf(0.05, base_rate * Config.AUTO_SHOOT_FIRE_RATE_MULT)
			_cooldowns[i] = 1.0 / auto_rate


func _find_target(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist: float = max_range
	for node in get_tree().get_nodes_in_group("targets"):
		var n := node as Node2D
		if n == null or n.is_queued_for_deletion():
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d <= best_dist:
			best_dist = d
			best = n
	return best


func _fire_spell(spell: Dictionary, dir: Vector2, max_range: float) -> void:
	var p: Projectile = ProjectileScene.instantiate()
	p.source_state = progress
	var dmg: float = float(spell["damage"])
	var can_use_aug: bool = bool(spell.get("uses_augments", true))
	p.setup(
		dir,
		Config.tiles(float(spell["speed_tiles"])),
		dmg,
		true,
		(spell["color"] as Color).lightened(0.15),
		Config.tiles(float(spell["radius_tiles"])),
		max_range,
		_homing_copied and progress.is_homing_active(),
		Projectile.ProjKind.INITIAL,
		null,
		can_use_aug,
		_aug_levels
	)
	p.global_position = global_position + Config.get_staff_gem_offset(_radius, dir)
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_tree().current_scene
	container.add_child(p)


## Doppelganger has 5 max HP and can never have a shield.
func take_damage(amount: float) -> void:
	if _dead or _iframes > 0.0 or amount <= 0.0:
		return
	var dmg: int = maxi(1, int(round(amount)))
	hp = maxi(0, hp - dmg)
	_iframes = Config.PLAYER_IFRAMES_SEC
	queue_redraw()
	if hp <= 0:
		_dead = true
		progress.on_doppelganger_died()
		died.emit()
		queue_free()


func _draw() -> void:
	var alpha: float = 0.45 if (_iframes > 0.0 and int(_iframes * 20.0) % 2 == 0) else 0.85
	Config.draw_ground_shadow(self, _radius, _radius * 0.72, 0.32 * alpha, Color(0.25, 0.05, 0.45))

	var staff_dir: Vector2 = _aim_dir if _aim_dir != Vector2.ZERO else Vector2.RIGHT

	# Spectral twin sprite centered on (0, 0) hitbox (never has a shield aura)
	draw_circle(Vector2.ZERO, _radius * 1.12, Color(0.55, 0.25, 0.95, alpha * 0.22))
	var tex: Texture2D = Config.get_tex("res://assets/sprites/player/player_mage.png")
	if tex != null:
		Config.draw_sprite_centered(
			self,
			tex,
			Vector2.ZERO,
			Vector2(_radius * 2.5, _radius * 2.5),
			Color(0.75, 0.48, 1.0, alpha),
			staff_dir.x < -0.05
		)
	else:
		draw_circle(Vector2.ZERO, _radius, Color(0.45, 0.22, 0.82, alpha))
		var hat := PackedVector2Array([
			Vector2(-_radius * 0.9, -_radius * 0.3),
			Vector2(_radius * 0.9, -_radius * 0.3),
			Vector2(_radius * 0.2, -_radius * 1.8),
		])
		draw_colored_polygon(hat, Color(0.28, 0.12, 0.58, alpha))

	Config.draw_mage_loadout(self, Vector2.ZERO, _radius, staff_dir, 0.0, true, alpha)

	# HP bar (5 max HP, no shield bar)
	var w: float = _radius * 2.2
	var top: Vector2 = Vector2(-w * 0.5, -_radius - 13.0)
	draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(top, Vector2(w * float(hp) / float(max_hp), 4)), Color(0.75, 0.38, 1.0))


