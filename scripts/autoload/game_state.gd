extends Node
## Current run state (autoload "GameState").
## Systems listen to these signals instead of referencing each other.

signal gold_changed(gold: int)
signal spell_level_changed(level: int)
signal mods_changed
signal objectives_changed
signal victory
signal defeat

const TOTAL_NESTS: int = 4

var map_size: MapSizeData
var difficulty: DifficultyData

var gold: int = 0
var spell_level: int = 1
## Mods that dropped from a nest but haven't been applied at the castle yet.
var pending_mods: Array[SpellData] = []
## Applied mods. Each entry: { "data": SpellData, "damage": int } (damage frozen when applied, §6.3).
var active_mods: Array[Dictionary] = []
var nests_destroyed: int = 0
var bosses_defeated: int = 0
var run_over: bool = false


## Resets everything for a new run. Falls back to Medium/Medium if no menu selection was made
## (e.g. when running Game.tscn directly with F6).
func start_run() -> void:
	if map_size == null:
		map_size = Config.MAP_SIZES[1]
	if difficulty == null:
		difficulty = Config.DIFFICULTIES[1]
	gold = 0
	spell_level = 1
	pending_mods.clear()
	active_mods.clear()
	nests_destroyed = 0
	bosses_defeated = 0
	run_over = false
	gold_changed.emit(gold)
	spell_level_changed.emit(spell_level)
	mods_changed.emit()
	objectives_changed.emit()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func is_spell_maxed() -> bool:
	return spell_level >= Config.SPELL_MAX_LEVEL


func next_upgrade_cost() -> int:
	return Config.upgrade_cost(spell_level)


func try_upgrade_spell() -> bool:
	if is_spell_maxed():
		return false
	var cost: int = next_upgrade_cost()
	if gold < cost:
		return false
	gold -= cost
	spell_level += 1
	gold_changed.emit(gold)
	spell_level_changed.emit(spell_level)
	return true


func add_pending_mod(mod: SpellData) -> void:
	pending_mods.append(mod)
	mods_changed.emit()


## Applies a pending mod: it copies the base spell's CURRENT damage and keeps it forever (§6.3).
func apply_mod(index: int) -> void:
	if index < 0 or index >= pending_mods.size():
		return
	var mod: SpellData = pending_mods[index]
	pending_mods.remove_at(index)
	active_mods.append({"data": mod, "damage": Config.spell_damage(spell_level)})
	mods_changed.emit()


func on_nest_destroyed() -> void:
	nests_destroyed += 1
	objectives_changed.emit()
	_check_victory()


func on_boss_defeated() -> void:
	bosses_defeated += 1
	objectives_changed.emit()
	_check_victory()


func on_player_died() -> void:
	if run_over:
		return
	run_over = true
	defeat.emit()


## Victory: all 4 nests destroyed AND all 4 nest bosses defeated (§5).
func _check_victory() -> void:
	if run_over:
		return
	if nests_destroyed >= TOTAL_NESTS and bosses_defeated >= TOTAL_NESTS:
		run_over = true
		victory.emit()
