class_name Player
extends CharacterBody2D
## The mage Hukulshish. WASD movement; click to shoot (or auto-aim once unlocked in the Gold Shop).
## Starts with 5 max HP (upgradable in the shop to 6 → 7 → 10 without instant heal); castle heals up to 3 HP.

signal hp_changed(hp: int, max_hp: int)
signal shield_changed(shield: int, max_shield: int)
signal died

const SpellCasterScript: GDScript = preload("res://scripts/spells/spell_caster.gd")

var max_hp: int = Config.PLAYER_MAX_HP
var hp: int = Config.PLAYER_MAX_HP
var max_shield: int = Config.PLAYER_MAX_SHIELD
var shield: int = 0
## Map area the player is kept inside. Set by Game; empty = unlimited.
var bounds: Rect2 = Rect2()

var _iframes: float = 0.0
var _regen_timer: float = 0.0
var _slow_timer: float = 0.0
var _dead: bool = false
var _radius: float = Config.tiles(Config.PLAYER_RADIUS_TILES)
var _facing: Vector2 = Vector2.RIGHT
var _aim_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	add_to_group("player")
	collision_layer = Config.LAYER_PLAYER
	collision_mask = Config.LAYER_WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)

	var camera := Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = true
	if bounds.has_area():
		camera.limit_left = int(bounds.position.x)
		camera.limit_top = int(bounds.position.y)
		camera.limit_right = int(bounds.end.x)
		camera.limit_bottom = int(bounds.end.y)
	add_child(camera)

	var caster: Node2D = SpellCasterScript.new()
	caster.name = "SpellCaster"
	add_child(caster)

	max_hp = GameState.player_max_hp()
	hp = max_hp
	GameState.changed.connect(_on_game_state_changed)
	hp_changed.emit(hp, max_hp)
	shield_changed.emit(shield, max_shield)


func _on_game_state_changed() -> void:
	var new_max: int = GameState.player_max_hp()
	if new_max != max_hp:
		# Buying Max HP increases the cap (5 → 6 → 7 → 10) without instantly healing current HP.
		max_hp = new_max
		hp = mini(hp, max_hp)
		hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		_aim_dir = to_mouse.normalized()

	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		_facing = input.normalized()

	if _slow_timer > 0.0:
		_slow_timer = maxf(0.0, _slow_timer - delta)
	var slow_mult: float = Config.UNDEAD_SLOW_SPEED_MULT if _slow_timer > 0.0 else 1.0

	velocity = input * Config.tiles(GameState.player_speed_tiles() * slow_mult)
	move_and_slide()
	if bounds.has_area():
		global_position = global_position.clamp(bounds.position + Vector2.ONE * _radius, bounds.end - Vector2.ONE * _radius)

	# Personal Shop Health Regen: +1 HP / 10 secs per upgrade
	var regen_hp: int = GameState.health_regen_per_10s()
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
	return global_position + d * (_radius * 2.15)


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
	_iframes = Config.PLAYER_IFRAMES_SEC
	queue_redraw()
	if hp <= 0:
		_dead = true
		died.emit()
		GameState.on_player_died()


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


func _draw() -> void:
	# Frost aura when slowed by Undead slow spell
	if _slow_timer > 0.0:
		draw_circle(Vector2.ZERO, _radius * 1.45, Color(0.35, 0.9, 1.0, 0.25))
		draw_arc(Vector2.ZERO, _radius * 1.45, 0.0, TAU, 28, Color(0.55, 0.95, 1.0, 0.9), 2.0)
	# Magic shield aura when shield > 0
	if shield > 0:
		draw_circle(Vector2.ZERO, _radius * 1.35, Color(0.2, 0.7, 1.0, 0.22))
		draw_arc(Vector2.ZERO, _radius * 1.35, 0.0, TAU, 28, Color(0.3, 0.85, 1.0, 0.85), 2.0)

	# Wand / Staff extending out from the mage's main hand toward cursor aim direction
	var staff_dir: Vector2 = _aim_dir if _aim_dir != Vector2.ZERO else _facing
	var perp: Vector2 = Vector2(-staff_dir.y, staff_dir.x)
	var hand_offset: Vector2 = perp * (_radius * 0.35)
	var staff_base: Vector2 = hand_offset + staff_dir * (_radius * 0.35)
	var staff_tip: Vector2 = hand_offset + staff_dir * (_radius * 2.05)
	draw_line(staff_base, staff_tip, Color(0.48, 0.30, 0.14), 4.0)
	draw_line(staff_tip - staff_dir * 4.5, staff_tip, Color(0.95, 0.82, 0.28), 5.0)
	draw_circle(staff_tip + staff_dir * 2.5, _radius * 0.32, Color(0.35, 0.85, 1.0, 0.38))
	draw_circle(staff_tip + staff_dir * 2.5, _radius * 0.20, Color(0.65, 0.95, 1.0))

	# Offhand Magic Catalyst (arcane focus crystal + orbiting rune ring on the opposite hand)
	var offhand_pos: Vector2 = -perp * (_radius * 0.95) + staff_dir * (_radius * 0.65)
	draw_circle(offhand_pos, _radius * 0.44, Color(0.68, 0.28, 1.0, 0.28))
	draw_arc(offhand_pos, _radius * 0.42, 0.0, TAU, 20, Color(0.95, 0.8, 0.32, 0.9), 1.6)
	var cat_pts := PackedVector2Array([
		offhand_pos + staff_dir * (_radius * 0.34),
		offhand_pos + perp * (_radius * 0.24),
		offhand_pos - staff_dir * (_radius * 0.34),
		offhand_pos - perp * (_radius * 0.24),
	])
	draw_colored_polygon(cat_pts, Color(0.75, 0.38, 1.0))
	draw_circle(offhand_pos, _radius * 0.13, Color(1.0, 0.95, 0.75))

	# Robe
	draw_circle(Vector2.ZERO, _radius, Color(0.25, 0.3, 0.85))
	# Hat
	var hat := PackedVector2Array([
		Vector2(-_radius * 0.9, -_radius * 0.3),
		Vector2(_radius * 0.9, -_radius * 0.3),
		Vector2(_radius * 0.2, -_radius * 1.8),
	])
	draw_colored_polygon(hat, Color(0.45, 0.2, 0.75))
	# Facing indicator
	draw_circle(staff_dir * _radius * 0.55, _radius * 0.22, Color(1, 0.95, 0.6))
