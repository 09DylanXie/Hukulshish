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
}

var kind: Kind = Kind.MOD_PART

var _t: float = 0.0


func _ready() -> void:
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
	if GameState.magnet_unlocked:
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null and not player.is_dead():
			var step: float = Config.tiles(Config.MAGNET_PULL_SPEED_TILES) * delta
			global_position = global_position.move_toward(player.global_position, step)
			if global_position.distance_to(player.global_position) <= Config.tiles(0.6):
				_collect()
				return
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_collect()


func _collect() -> void:
	if is_queued_for_deletion():
		return
	match kind:
		Kind.BOSS_SPELL:
			GameState.acquire_boss_spell()
		Kind.AUG_SCROLL:
			GameState.add_aug_scrolls(1)
		Kind.ENHANCER:
			GameState.add_enhancers(1)
		_:
			GameState.add_mod_parts(1)
	queue_free()


func _draw() -> void:
	match kind:
		Kind.BOSS_SPELL:
			var col := Color(1.0, 0.55, 0.15)
			var r: float = Config.tiles(0.45) * (1.0 + 0.15 * sin(_t * 5.0))
			draw_circle(Vector2.ZERO, r * 1.7, Color(col, 0.28))
			var pts1 := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.7, 0), Vector2(0, r), Vector2(-r * 0.7, 0)])
			var pts2 := PackedVector2Array([Vector2(-r * 0.6, -r * 0.6), Vector2(r * 0.6, -r * 0.6), Vector2(r * 0.6, r * 0.6), Vector2(-r * 0.6, r * 0.6)])
			draw_colored_polygon(pts2, col.darkened(0.2))
			draw_colored_polygon(pts1, col.lightened(0.25))
		Kind.AUG_SCROLL:
			var col := Color(1.0, 0.22, 0.38)
			var r: float = Config.tiles(0.38) * (1.0 + 0.14 * sin(_t * 4.5))
			draw_circle(Vector2.ZERO, r * 1.6, Color(col, 0.28))
			# Crimson scroll / diamond rune
			var diamond := PackedVector2Array([
				Vector2(0, -r * 1.1),
				Vector2(r * 0.9, 0),
				Vector2(0, r * 1.1),
				Vector2(-r * 0.9, 0),
			])
			draw_colored_polygon(diamond, col)
			draw_circle(Vector2.ZERO, r * 0.35, Color(1.0, 0.88, 0.3))
		Kind.ENHANCER:
			var col := Color(0.28, 0.95, 0.45)
			var r: float = Config.tiles(0.36) * (1.0 + 0.13 * sin(_t * 4.8))
			draw_circle(Vector2.ZERO, r * 1.55, Color(col, 0.28))
			# Emerald enhancer crystal
			var tri_up := PackedVector2Array([
				Vector2(0, -r * 1.05),
				Vector2(r * 0.9, r * 0.55),
				Vector2(-r * 0.9, r * 0.55),
			])
			var tri_down := PackedVector2Array([
				Vector2(0, r * 1.05),
				Vector2(r * 0.9, -r * 0.55),
				Vector2(-r * 0.9, -r * 0.55),
			])
			draw_colored_polygon(tri_down, col.darkened(0.2))
			draw_colored_polygon(tri_up, col.lightened(0.15))
		_:
			var col := Color(0.35, 0.9, 1.0)
			var r: float = Config.tiles(0.32) * (1.0 + 0.12 * sin(_t * 4.0))
			draw_circle(Vector2.ZERO, r * 1.5, Color(col, 0.25))
			var hex := PackedVector2Array([
				Vector2(0, -r),
				Vector2(r * 0.85, -r * 0.5),
				Vector2(r * 0.85, r * 0.5),
				Vector2(0, r),
				Vector2(-r * 0.85, r * 0.5),
				Vector2(-r * 0.85, -r * 0.5),
			])
			draw_colored_polygon(hex, col)
