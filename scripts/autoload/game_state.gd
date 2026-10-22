extends Node
## Current run state (autoload "GameState").
## Systems listen to these signals instead of referencing each other.

## Emitted whenever anything the HUD / castle menu shows changes.
signal changed
signal victory
signal defeat

const TOTAL_NESTS: int = 4

var map_size: MapSizeData
var difficulty: DifficultyData

var gold: int = 0
var spell_level: int = 1
var mod_parts: int = 0
## Mod id → level (see Config.MODS). Mods only affect the base spell.
var mod_levels: Dictionary = {}
## Spells dropped by bosses. Each is a frozen stat Dictionary (see make_spell_stats()).
var boss_spells: Array[Dictionary] = []
var nests_destroyed: int = 0
var bosses_defeated: int = 0
var mega_boss_spawned: bool = false
var mega_boss_defeated: bool = false
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
	mod_parts = 0
	mod_levels.clear()
	for id in Config.MODS:
		mod_levels[id] = 0
	boss_spells.clear()
	nests_destroyed = 0
	bosses_defeated = 0
	mega_boss_spawned = false
	mega_boss_defeated = false
	run_over = false
	changed.emit()


# --- Spell stats ---

## Builds a spell stat Dictionary: { name, damage, fire_rate, speed_tiles, range_tiles, color, radius_tiles }.
static func make_spell_stats(data: SpellData, damage: float, fire_rate: float, speed_tiles: float, range_tiles: float) -> Dictionary:
	return {
		"name": data.name,
		"damage": damage,
		"fire_rate": fire_rate,
		"speed_tiles": speed_tiles,
		"range_tiles": range_tiles,
		"color": data.color,
		"radius_tiles": data.radius_tiles,
	}


func mod_multiplier(id: String) -> float:
	return 1.0 + Config.MOD_STEP * int(mod_levels.get(id, 0))


## Current base spell stats: level damage × mods.
func base_spell_stats() -> Dictionary:
	var b: SpellData = Config.BASE_SPELL
	return make_spell_stats(b,
		Config.spell_damage(spell_level) * mod_multiplier("damage"),
		b.fire_rate * mod_multiplier("fire_rate"),
		b.speed_tiles * mod_multiplier("speed"),
		b.range_tiles * mod_multiplier("range"))


## Every spell the player fires: the base spell first, then boss spells.
func all_spells() -> Array[Dictionary]:
	var list: Array[Dictionary] = [base_spell_stats()]
	list.append_array(boss_spells)
	return list


# --- Gold / base spell level ---

func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()


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
	changed.emit()
	return true


# --- Mods ---

func add_mod_parts(amount: int) -> void:
	mod_parts += amount
	changed.emit()


func next_mod_cost(id: String) -> int:
	return Config.mod_cost(int(mod_levels.get(id, 0)))


func try_buy_mod(id: String) -> bool:
	if not Config.MODS.has(id):
		return false
	var cost: int = next_mod_cost(id)
	if mod_parts < cost:
		return false
	mod_parts -= cost
	mod_levels[id] = int(mod_levels.get(id, 0)) + 1
	changed.emit()
	return true


# --- Boss spells ---

## A boss spell copies the player's spells at pickup time and is frozen after that (can't be upgraded).
## - First boss spell: 2× the base spell's damage.
## - Later boss spells: the sum of every spell the player already has.
## Fire rate is always the base spell's rate × 2/3 (the 1/3 reduction is applied once, not stacked).
## Speed and range are copied from the base spell. Existing spells are kept.
func acquire_boss_spell() -> Dictionary:
	var base: Dictionary = base_spell_stats()
	var damage: float
	if boss_spells.is_empty():
		damage = base["damage"] * 2.0
	else:
		damage = 0.0
		for s in all_spells():
			damage += s["damage"]
	var spell: Dictionary = make_spell_stats(Config.BOSS_SPELL, damage,
		base["fire_rate"] * Config.BOSS_SPELL_FIRE_RATE_MULT, base["speed_tiles"], base["range_tiles"])
	spell["name"] = "%s %d" % [Config.BOSS_SPELL.name, boss_spells.size() + 1]
	boss_spells.append(spell)
	changed.emit()
	return spell


# --- Objectives ---

func on_nest_destroyed() -> void:
	nests_destroyed += 1
	changed.emit()


func on_boss_defeated() -> void:
	bosses_defeated += 1
	changed.emit()


func on_mega_boss_spawned() -> void:
	mega_boss_spawned = true
	changed.emit()


## Victory: the mega boss is defeated (it only appears after all 4 nests are destroyed).
func on_mega_boss_defeated() -> void:
	mega_boss_defeated = true
	changed.emit()
	if not run_over:
		run_over = true
		victory.emit()


func on_player_died() -> void:
	if run_over:
		return
	run_over = true
	defeat.emit()
