class_name MonsterWaves
extends RefCounted
## Spawns every monster class on its own timer, up to a cap of each alive at once (§6.10).
## Used by the Mega Boss and by Endless Mode.

const MonsterScene: PackedScene = preload("res://scenes/monsters/Monster.tscn")

## Alive count per monster class, same order as Config.MONSTERS.
var alive: Array[int] = []

var _timers: Array[float] = []


func _init() -> void:
	for stats: MonsterStats in Config.MONSTERS:
		_timers.append(stats.mega_spawn_interval)
		alive.append(0)


## Advances the timers. `place` receives each new monster and must add it to the tree.
func advance(delta: float, place: Callable) -> void:
	for i in _timers.size():
		_timers[i] -= delta
		if _timers[i] > 0.0:
			continue
		var stats: MonsterStats = Config.MONSTERS[i]
		_timers[i] = stats.mega_spawn_interval
		for _count in stats.mega_spawn_count:
			if alive[i] >= Config.MEGA_BOSS_MINION_CAP:
				break
			place.call(_make_monster(i, stats))


func _make_monster(index: int, stats: MonsterStats) -> Monster:
	var scene: PackedScene = stats.scene if stats.scene != null else MonsterScene
	var monster: Monster = scene.instantiate()
	monster.setup(stats, 1.0)
	alive[index] += 1
	monster.tree_exited.connect(_on_monster_gone.bind(index))
	return monster


func _on_monster_gone(index: int) -> void:
	alive[index] -= 1
