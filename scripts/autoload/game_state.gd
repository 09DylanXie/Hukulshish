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
## How many mod parts have been purchased with gold in the Gold Shop (max 10).
var mod_parts_bought_with_gold: int = 0
## Mod id → level (see Config.MODS). Mods only affect the base spell.
var mod_levels: Dictionary = {}
## Spells dropped by bosses. Each is a frozen stat Dictionary (see make_spell_stats()).
var boss_spells: Array[Dictionary] = []

# --- Gold Shop unlocks & hotbar consumables ---
var auto_shoot_unlocked: bool = false
var shield_items: int = 0
var heal_potions: int = 0
var damage_potions: int = 0
var heal_potion_timer: float = 0.0
var damage_boost_timer: float = 0.0

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
	mod_parts_bought_with_gold = 0
	mod_levels.clear()
	for id in Config.MODS:
		mod_levels[id] = 0
	boss_spells.clear()
	auto_shoot_unlocked = false
	shield_items = 0
	heal_potions = 0
	damage_potions = 0
	heal_potion_timer = 0.0
	damage_boost_timer = 0.0
	nests_destroyed = 0
	bosses_defeated = 0
	mega_boss_spawned = false
	mega_boss_defeated = false
	run_over = false
	changed.emit()


func _process(delta: float) -> void:
	if get_tree().paused or run_over:
		return
	var prev_dmg_active: bool = damage_boost_timer > 0.0
	var prev_heal_active: bool = heal_potion_timer > 0.0
	if damage_boost_timer > 0.0:
		damage_boost_timer = maxf(0.0, damage_boost_timer - delta)
	if heal_potion_timer > 0.0:
		heal_potion_timer = maxf(0.0, heal_potion_timer - delta)
	if (prev_dmg_active and damage_boost_timer <= 0.0) or (prev_heal_active and heal_potion_timer <= 0.0):
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


func damage_boost_multiplier() -> float:
	return Config.DAMAGE_POTION_MULT if damage_boost_timer > 0.0 else 1.0


## Current base spell stats: level damage × mods (before temporary potion boost).
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


# --- Gold Shop purchases ---

func can_buy_gold_mod_part() -> bool:
	return mod_parts_bought_with_gold < Config.GOLD_SHOP_MOD_PART_MAX


func next_gold_mod_part_cost() -> int:
	return Config.gold_mod_part_cost(mod_parts_bought_with_gold)


func try_buy_gold_mod_part() -> bool:
	if not can_buy_gold_mod_part():
		return false
	var cost: int = next_gold_mod_part_cost()
	if gold < cost:
		return false
	gold -= cost
	mod_parts_bought_with_gold += 1
	mod_parts += 1
	changed.emit()
	return true


func try_buy_shield_item() -> bool:
	if gold < Config.GOLD_SHOP_SHIELD_COST:
		return false
	gold -= Config.GOLD_SHOP_SHIELD_COST
	shield_items += 1
	changed.emit()
	return true


func try_buy_heal_potion() -> bool:
	if gold < Config.GOLD_SHOP_POTION_COST:
		return false
	gold -= Config.GOLD_SHOP_POTION_COST
	heal_potions += 1
	changed.emit()
	return true


func try_buy_damage_potion() -> bool:
	if gold < Config.GOLD_SHOP_POTION_COST:
		return false
	gold -= Config.GOLD_SHOP_POTION_COST
	damage_potions += 1
	changed.emit()
	return true


func try_buy_auto_shoot() -> bool:
	if auto_shoot_unlocked or gold < Config.GOLD_SHOP_AUTO_SHOOT_COST:
		return false
	gold -= Config.GOLD_SHOP_AUTO_SHOOT_COST
	auto_shoot_unlocked = true
	changed.emit()
	return true


# --- Using hotbar items ---

func try_use_shield_item(player: Node) -> bool:
	if shield_items <= 0 or player == null or not player.has_method("add_shield"):
		return false
	if not player.add_shield(Config.SHIELD_ITEM_AMOUNT):
		return false
	shield_items -= 1
	changed.emit()
	return true


func try_use_heal_potion(player: Node) -> bool:
	if heal_potions <= 0 or player == null or not player.has_method("heal_amount"):
		return false
	if not player.heal_amount(Config.HEAL_POTION_AMOUNT):
		return false
	heal_potions -= 1
	heal_potion_timer = Config.POTION_DURATION_SEC
	changed.emit()
	return true


func try_use_damage_potion() -> bool:
	if damage_potions <= 0:
		return false
	damage_potions -= 1
	damage_boost_timer = Config.POTION_DURATION_SEC
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
