class_name EndlessDirector
extends Node
## Runs Endless Mode after the dragon falls (§6.13): monsters around the map edge, and a new
## Mega Boss every minute. Mega Bosses never stack, so a late one waits for the last to die.

## Receives each new monster and must add it to the tree.
var place_monster: Callable
var spawn_mega_boss: Callable

var _waves: MonsterWaves = MonsterWaves.new()
var _mega_timer: float = Config.ENDLESS_MEGA_INTERVAL_SEC


func _physics_process(delta: float) -> void:
	if GameState.run_over:
		return
	_waves.advance(delta, place_monster)
	_mega_timer = maxf(0.0, _mega_timer - delta)
	GameState.endless_next_boss_sec = _mega_timer
	if _mega_timer <= 0.0 and get_tree().get_nodes_in_group("mega_boss").is_empty():
		_mega_timer = Config.ENDLESS_MEGA_INTERVAL_SEC
		spawn_mega_boss.call()
