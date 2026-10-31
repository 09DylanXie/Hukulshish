class_name Player
extends CharacterBody2D
## The mage Hukulshish. WASD movement; click to shoot (or auto-aim once unlocked in the Gold Shop).
## Starts with 7 max HP (upgradable in the shop to 8 → 9 → 12 without instant heal); castle heals up to 3 HP.

signal hp_changed(hp: int, max_hp: int)
signal shield_changed(shield: int, max_shield: int)
signal died
signal revived

const SpellCasterScript: GDScript = preload("res://scripts/spells/spell_caster.gd")

var max_hp: int = Config.PLAYER_MAX_HP
var hp: int = Config.PLAYER_MAX_HP
var max_shield: int = Config.PLAYER_MAX_SHIELD
var shield: int = 0
## Map area the player is kept inside. Set by Game; empty = unlimited.
var bounds: Rect2 = Rect2()
## Assigned before entering the tree. Null keeps the single-player GameState behavior.
var progress: RunState
var accepts_local_input: bool = true
var respawn_pending: bool = false
var remote_move_direction: Vector2 = Vector2.ZERO
var remote_aim_position: Vector2 = Vector2.ZERO
var remote_fire_pressed: bool = false

var _iframes: float = 0.0
var _regen_timer: float = 0.0
var _slow_timer: float = 0.0
var _dead: bool = false
var _radius: float = Config.tiles(Config.PLAYER_RADIUS_TILES)
var _facing: Vector2 = Vector2.RIGHT
var _aim_dir: Vector2 = Vector2.RIGHT
var _walk_t: float = 0.0
var _camera: Camera2D
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0


func _ready() -> void:
	if progress == null:
		progress = GameState
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("player")
	collision_layer = Config.LAYER_PLAYER
	collision_mask = Config.LAYER_WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)

	_camera = Camera2D.new()
	_camera.enabled = accepts_local_input
	_camera.zoom = Vector2(2, 2)
	_camera.position_smoothing_enabled = true
	if bounds.has_area():
		_camera.limit_left = int(bounds.position.x)
		_camera.limit_top = int(bounds.position.y)
		_camera.limit_right = int(bounds.end.x)
		_camera.limit_bottom = int(bounds.end.y)
	add_child(_camera)

	var caster: Node2D = SpellCasterScript.new()
	caster.name = "SpellCaster"
	add_child(caster)

	max_hp = progress.player_max_hp()
	hp = max_hp
	progress.changed.connect(_on_game_state_changed)
	progress.screen_shake_requested.connect(_on_screen_shake_requested)
	hp_changed.emit(hp, max_hp)
	shield_changed.emit(shield, max_shield)


func _on_screen_shake_requested(intensity: float, duration: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_timer = maxf(_shake_timer, duration)


func _on_game_state_changed() -> void:
	var new_max: int = progress.player_max_hp()
	if new_max != max_hp:
		# Buying Max HP increases the cap (7 → 8 → 9 → 12) without instantly healing current HP.
		max_hp = new_max
		hp = mini(hp, max_hp)
		hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var to_mouse: Vector2 = (get_global_mouse_position() if accepts_local_input else remote_aim_position) - global_position
	if to_mouse.length_squared() > 1.0:
		_aim_dir = to_mouse.normalized()

	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down") if accepts_local_input else remote_move_direction.limit_length(1.0)
	if progress.coop_mode and (progress.castle_menu_open or progress.pause_menu_open):
		input = Vector2.ZERO
	if input != Vector2.ZERO:
		_facing = input.normalized()
		_walk_t += delta * 12.0
	else:
		_walk_t += delta * 2.5

	if _shake_timer > 0.0 and _camera != null:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_intensity
		if _shake_timer <= 0.0:
			_shake_intensity = 0.0
			_camera.offset = Vector2.ZERO

	if _slow_timer > 0.0:
		_slow_timer = maxf(0.0, _slow_timer - delta)
	var slow_mult: float = Config.UNDEAD_SLOW_SPEED_MULT if _slow_timer > 0.0 else 1.0

	velocity = input * Config.tiles(progress.player_speed_tiles() * slow_mult)
	move_and_slide()
	if bounds.has_area():
		global_position = global_position.clamp(bounds.position + Vector2.ONE * _radius, bounds.end - Vector2.ONE * _radius)

	# Personal Shop Health Regen: +1 HP / 10 secs per upgrade
	var regen_hp: int = progress.health_regen_per_10s()
	if regen_hp > 0 and hp < max_hp:
		_regen_timer += delta
		if _regen_timer >= Config.HEALTH_REGEN_INTERVAL_SEC:
			_regen_timer -= Config.HEALTH_REGEN_INTERVAL_SEC
			heal_amount(regen_hp)
	else:
		_regen_timer = 0.0

	if _iframes > 0.0:
		_iframes -= delta
		modulate.a = 0.4 if int(_iframes * 20.0) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0
	queue_redraw()


## Applies the Undead 0-damage slow spell effect to the player.
func apply_slow(duration: float) -> void:
	if _dead:
		return
	_slow_timer = maxf(_slow_timer, duration)
	queue_redraw()


func get_wand_tip_global(dir_override: Vector2 = Vector2.ZERO) -> Vector2:
	var d: Vector2 = dir_override.normalized() if dir_override != Vector2.ZERO else _aim_dir
	return global_position + Config.get_staff_gem_offset(_radius, d)


func take_damage(amount: float) -> void:
	if _dead or _iframes > 0.0 or amount <= 0.0:
		return
	var dmg: int = maxi(1, int(round(amount)))
	if shield > 0:
		var absorbed: int = mini(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
		shield_changed.emit(shield, max_shield)
	if dmg > 0:
		hp = maxi(0, hp - dmg)
		hp_changed.emit(hp, max_hp)
	progress.request_shake(5.0, 0.2)
	_iframes = Config.PLAYER_IFRAMES_SEC
	queue_redraw()
	if hp <= 0:
		_dead = true
		velocity = Vector2.ZERO
		modulate.a = 1.0
		died.emit()
		progress.on_player_died()


## Called by the authoritative co-op controller after its castle respawn timer.
func revive_at_castle(castle_position: Vector2) -> bool:
	if progress == null or not progress.coop_mode or progress.run_over or not _dead:
		return false
	global_position = castle_position
	velocity = Vector2.ZERO
	hp = mini(max_hp, int(Config.COOP_RULES.revival_restored_hp))
	shield = 0
	_dead = false
	respawn_pending = false
	_iframes = 0.0
	_slow_timer = 0.0
	_regen_timer = 0.0
	modulate.a = 1.0
	hp_changed.emit(hp, max_hp)
	shield_changed.emit(shield, max_shield)
	revived.emit()
	queue_redraw()
	return true


## Adds shield points up to `max_shield` (5). Returns false if already full.
func add_shield(amount: int) -> bool:
	if _dead or shield >= max_shield:
		return false
	shield = mini(max_shield, shield + amount)
	shield_changed.emit(shield, max_shield)
	queue_redraw()
	return true


## Heals the player by `amount` up to `max_hp` (used by 3 HP healing potions and Health Regen).
func heal_amount(amount: int) -> bool:
	if _dead or hp >= max_hp:
		return false
	hp = mini(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)
	return true


## Heals the player up to 3 HP when entering the castle shop (§5).
## Never reduces HP if the player is already above 3 HP.
func heal_at_castle() -> void:
	if _dead:
		return
	var cap: int = mini(max_hp, Config.CASTLE_HEAL_MAX_HP)
	if hp < cap:
		hp = cap
		hp_changed.emit(hp, max_hp)


func is_dead() -> bool:
	return _dead


## Preserve the current chase order, skipping bodies until a teammate returns.
static func first_living_player(tree: SceneTree) -> Player:
	for node: Node in tree.get_nodes_in_group("player"):
		var player: Player = node as Player
		if player != null and not player.is_dead():
			return player
	return null


func _draw() -> void:
	if _dead and progress != null and progress.coop_mode:
		draw_circle(Vector2.ZERO, _radius, Color(0.35, 0.18, 0.25, 0.8))
		draw_line(Vector2(-_radius, -_radius), Vector2(_radius, _radius), Color.LIGHT_CORAL, 3.0)
		draw_line(Vector2(-_radius, _radius), Vector2(_radius, -_radius), Color.LIGHT_CORAL, 3.0)
		var caption: String = "Returning to castle" if respawn_pending else "Downed"
		draw_string(ThemeDB.fallback_font, Vector2(-_radius * 2.0, -_radius * 1.5), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		return
	# Flat elliptical ground shadow right under the mage's feet
	Config.draw_ground_shadow(self, _radius, _radius * 0.72, 0.34)

	# Frost aura when slowed by Undead slow spell
	if _slow_timer > 0.0:
		draw_circle(Vector2.ZERO, _radius * 1.48, Color(0.35, 0.9, 1.0, 0.25))
		draw_arc(Vector2.ZERO, _radius * 1.48, 0.0, TAU, 28, Color(0.55, 0.95, 1.0, 0.9), 2.0)
	# Magic shield aura when shield > 0
	if shield > 0:
		draw_circle(Vector2.ZERO, _radius * 1.38, Color(0.2, 0.7, 1.0, 0.22))
		draw_arc(Vector2.ZERO, _radius * 1.38, 0.0, TAU, 28, Color(0.3, 0.85, 1.0, 0.85), 2.0)

	var staff_dir: Vector2 = _aim_dir if _aim_dir != Vector2.ZERO else _facing
	var bob: float = sin(_walk_t) * 1.4 if velocity.length_squared() > 4.0 else sin(_walk_t) * 0.5

	# Mage pixel-art sprite centered squarely on the (0, 0) hitbox
	var tex: Texture2D = Config.get_tex("res://assets/sprites/player/player_mage.png")
	if tex != null:
		var flip_left: bool = staff_dir.x < -0.05
		Config.draw_sprite_centered(
			self,
			tex,
			Vector2(0, bob),
			Vector2(_radius * 2.55, _radius * 2.55),
			Color.WHITE,
			flip_left
		)
	else:
		draw_circle(Vector2.ZERO, _radius, Color(0.25, 0.3, 0.85))
		var hat := PackedVector2Array([
			Vector2(-_radius * 0.9, -_radius * 0.3),
			Vector2(_radius * 0.9, -_radius * 0.3),
			Vector2(_radius * 0.2, -_radius * 1.8),
		])
		draw_colored_polygon(hat, Color(0.45, 0.2, 0.75))

	# Main-hand Sapphire Rhombus Staff + Offhand Open Magic Tome
	Config.draw_mage_loadout(self, Vector2.ZERO, _radius, staff_dir, bob, false, 1.0)

