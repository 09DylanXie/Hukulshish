extends Node2D
## The Fireball's instant blast (§6.4). Purely visual: the damage is dealt by the projectile.

var radius: float = Config.tiles(Config.BOMB_RADIUS_TILES)

var _elapsed: float = 0.0


func _ready() -> void:
	z_index = -2
	GameState.request_shake(3.0, 0.12)
	AudioManager.play_at("bomb_explosion", global_position)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= Config.FIREBALL_FLASH_SEC:
		queue_free()


func _draw() -> void:
	var t: float = clampf(_elapsed / Config.FIREBALL_FLASH_SEC, 0.0, 1.0)
	var fade: float = 1.0 - t
	var r: float = radius * (0.55 + 0.45 * t)
	draw_circle(Vector2.ZERO, r, Color(0.95, 0.3, 0.05, 0.45 * fade))
	draw_circle(Vector2.ZERO, r * 0.65, Color(1.0, 0.65, 0.12, 0.6 * fade))
	draw_circle(Vector2.ZERO, r * 0.3, Color(1.0, 0.94, 0.5, 0.8 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(1.0, 0.7, 0.2, fade), 2.5)
