class_name ModPickup
extends Area2D
## Ground pickup for:
## - a Spell Scroll (1/7 drop from monsters, spent at the castle to upgrade Spell Mods),
## - an Augmentation Scroll (1/5 drop from Demons only, spent at the castle on Augmentations), or
## - a Boss Spell (1/3 drop from nest bosses, immediately grants a new spell).
## When Magnet is unlocked in the Gold Shop, pickups automatically fly toward the player.

enum Kind {
	MOD_PART,
	AUG_SCROLL,
	ENHANCER,
	BOSS_SPELL,
	MEGA_BOSS_SPELL,
}

var kind: Kind = Kind.MOD_PART

var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("pickups")
	collision_layer = 0
	collision_mask = Config.LAYER_PLAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Config.tiles(0.55)
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_t += delta
	var nearest: Player
	var nearest_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player: Player = node as Player
		if player == null or player.is_dead() or not player.progress.magnet_unlocked:
			continue
		var distance: float = global_position.distance_squared_to(player.global_position)
		if distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	if nearest != null:
		var step: float = Config.tiles(Config.MAGNET_PULL_SPEED_TILES) * delta
		global_position = global_position.move_toward(nearest.global_position, step)
		if global_position.distance_to(nearest.global_position) <= Config.tiles(0.6):
			_collect(nearest.progress)
			return
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Player and not (body as Player).is_dead():
		_collect((body as Player).progress)


func _collect(progress: RunState) -> void:
	if is_queued_for_deletion():
		return
	match kind:
		Kind.MEGA_BOSS_SPELL:
			progress.acquire_mega_boss_spell()
			GameState.spawn_floating_text(global_position + Vector2(0, -16), "MEGA SPELL!", Color(1.0, 0.25, 0.25))
		Kind.BOSS_SPELL:
			progress.acquire_boss_spell()
			GameState.spawn_floating_text(global_position + Vector2(0, -16), "BOSS SPELL!", Color(1.0, 0.65, 0.2))
		Kind.AUG_SCROLL:
			progress.add_aug_scrolls(1)
			GameState.spawn_floating_text(global_position + Vector2(0, -14), "+1 Aug Scroll", Color(1.0, 0.35, 0.52))
		Kind.ENHANCER:
			progress.add_enhancers(1)
			GameState.spawn_floating_text(global_position + Vector2(0, -14), "+1 Enhancer", Color(0.35, 0.98, 0.55))
		_:
			progress.add_mod_parts(1)
			GameState.spawn_floating_text(global_position + Vector2(0, -14), "+1 Spell Scroll", Color(0.45, 0.92, 1.0))
	queue_free()


func _draw() -> void:
	var bob: float = sin(_t * 4.5) * 3.0
	var pulse: float = 1.0 + 0.12 * sin(_t * 5.0)
	draw_circle(Vector2(0, 8), 8.0, Color(0, 0, 0, 0.35))

	var tex_path: String = "res://assets/sprites/spells/spell_scroll.png"
	var glow_col := Color(0.35, 0.9, 1.0)
	var icon_sz: float = 26.0
	match kind:
		Kind.MEGA_BOSS_SPELL:
			tex_path = "res://assets/sprites/spells/mega_spell.png"
			glow_col = Color(1.0, 0.15, 0.15)
			icon_sz = 34.0
		Kind.BOSS_SPELL:
			tex_path = "res://assets/sprites/spells/boss_spell.png"
			glow_col = Color(1.0, 0.55, 0.15)
			icon_sz = 30.0
		Kind.AUG_SCROLL:
			tex_path = "res://assets/sprites/spells/aug_scroll.png"
			glow_col = Color(1.0, 0.22, 0.38)
			icon_sz = 28.0
		Kind.ENHANCER:
			tex_path = "res://assets/sprites/spells/enhancer.png"
			glow_col = Color(0.28, 0.95, 0.45)
			icon_sz = 26.0

	draw_circle(Vector2(0, bob), icon_sz * 0.68 * pulse, Color(glow_col, 0.26))
	draw_arc(Vector2(0, bob), icon_sz * 0.65 * pulse, 0.0, TAU, 24, Color(glow_col.lightened(0.25), 0.72), 1.6)
	var tex: Texture2D = Config.get_tex(tex_path)
	if tex != null:
		Config.draw_sprite_centered(self, tex, Vector2(0, bob), Vector2(icon_sz, icon_sz))
	else:
		draw_circle(Vector2(0, bob), icon_sz * 0.4, glow_col)

