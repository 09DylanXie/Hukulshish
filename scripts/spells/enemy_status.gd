class_name EnemyStatus
extends RefCounted
## Slow, stun and poison on one enemy (§6.4). Monsters and bosses each own one and call update().
## A repeat hit refreshes an effect instead of stacking it.

## Bosses are immune to stun.
var immune_to_stun: bool = false

var _slow_left: float = 0.0
var _stun_left: float = 0.0
var _stun_cooldown_left: float = 0.0
var _poison_ticks_left: int = 0
var _poison_tick_left: float = 0.0
var _poison_source: RunState


func apply_slow() -> void:
	_slow_left = Config.WATER_SLOW_SEC


## Earth fires faster than a stun lasts, so a recovering monster can't be stunned again straight away.
func apply_stun() -> void:
	if immune_to_stun or _stun_left > 0.0 or _stun_cooldown_left > 0.0:
		return
	_stun_left = Config.EARTH_STUN_SEC


func apply_poison(source: RunState) -> void:
	if _poison_ticks_left <= 0:
		_poison_tick_left = Config.DEATH_POISON_TICK_SEC
	_poison_ticks_left = roundi(Config.DEATH_POISON_SEC / Config.DEATH_POISON_TICK_SEC)
	_poison_source = source


func is_stunned() -> bool:
	return _stun_left > 0.0


func speed_mult() -> float:
	return Config.WATER_SLOW_SPEED_MULT if _slow_left > 0.0 else 1.0


## Advances every timer. Poison can kill `target`, so callers must check for death afterwards.
func update(delta: float, target: Node) -> void:
	_slow_left = maxf(0.0, _slow_left - delta)
	_stun_cooldown_left = maxf(0.0, _stun_cooldown_left - delta)
	if _stun_left > 0.0:
		_stun_left -= delta
		if _stun_left <= 0.0:
			_stun_left = 0.0
			_stun_cooldown_left = Config.EARTH_STUN_COOLDOWN_SEC
	if _poison_ticks_left > 0:
		_poison_tick_left -= delta
		if _poison_tick_left <= 0.0:
			_poison_tick_left += Config.DEATH_POISON_TICK_SEC
			_poison_ticks_left -= 1
			_deal_poison(target)


func _deal_poison(target: Node) -> void:
	var amount: float = Config.DEATH_POISON_DPS * Config.DEATH_POISON_TICK_SEC
	if is_instance_valid(_poison_source):
		_poison_source.deal_damage(target, amount)
	else:
		target.call("take_damage", amount)


## Rings around the enemy that show which effects are active.
func draw(canvas: CanvasItem, radius: float) -> void:
	if _slow_left > 0.0:
		canvas.draw_arc(Vector2.ZERO, radius * 1.2, 0.0, TAU, 24, Color(0.35, 0.7, 1.0, 0.85), 1.5)
	if _poison_ticks_left > 0:
		canvas.draw_arc(Vector2.ZERO, radius * 1.35, 0.0, TAU, 24, Color(0.72, 0.3, 1.0, 0.85), 1.5)
	if _stun_left > 0.0:
		for i in 3:
			var star: Vector2 = Vector2.from_angle(float(i) * TAU / 3.0 + _stun_left * 8.0) * radius
			canvas.draw_circle(star + Vector2(0.0, -radius), 2.2, Color(1.0, 0.9, 0.4))
