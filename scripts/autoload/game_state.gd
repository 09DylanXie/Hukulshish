extends Node
## Current run state (autoload "GameState").
## Systems listen to these signals instead of referencing each other.

## Emitted whenever anything the HUD / castle menu shows changes.
signal changed
signal mana_changed(mana: float, max_mana: int, regen: float)
signal endless_wave_started(wave: int)
signal victory
signal defeat

const TOTAL_NESTS: int = 4

var map_size: MapSizeData
var difficulty: DifficultyData
var endless_mode: bool = false
var endless_wave: int = 0
var endless_hp_mult: float = 1.0

var run_time: float = 0.0
var gold: int = 0
var spell_level: int = 1
## Spell Scrolls (formerly Mod Parts) dropped by monsters (1/7) or bought in the Gold Shop.
var mod_parts: int = 0
## How many Spell Scrolls have been purchased with gold in the Gold Shop (max 10).
var mod_parts_bought_with_gold: int = 0
## Mod id → level (see Config.MODS).
var mod_levels: Dictionary = {}

## Augmentation Scrolls dropped only by Demons (1/5 chance).
var aug_scrolls: int = 0
## Augmentation id → level (0..3, see Config.AUGMENTATIONS).
var aug_levels: Dictionary = {}

## Mana state
var mana: float = Config.BASE_MAX_MANA

## Spells dropped by bosses. Each is a frozen stat Dictionary (see make_spell_stats()).
var boss_spells: Array[Dictionary] = []

# --- Gold Shop unlocks & hotbar consumables ---
var magnet_unlocked: bool = false
var auto_shoot_unlocked: bool = false
var homing_unlocked: bool = false
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
	run_time = 0.0
	gold = 0
	spell_level = 1
	mod_parts = 0
	mod_parts_bought_with_gold = 0
	mod_levels.clear()
	for id in Config.MODS:
		mod_levels[id] = 0
	aug_scrolls = 0
	aug_levels.clear()
	for id in Config.AUGMENTATIONS:
		aug_levels[id] = 0
	mana = float(max_mana())
	boss_spells.clear()
	magnet_unlocked = false
	auto_shoot_unlocked = false
	homing_unlocked = false
	shield_items = 0
	heal_potions = 0
	damage_potions = 0
	heal_potion_timer = 0.0
	damage_boost_timer = 0.0
	nests_destroyed = 0
	bosses_defeated = 0
	mega_boss_spawned = false
	mega_boss_defeated = false
	endless_wave = 0
	endless_hp_mult = 1.0
	run_over = false
	changed.emit()
	mana_changed.emit(mana, max_mana(), mana_regen())


func _process(delta: float) -> void:
	if get_tree().paused or run_over:
		return
	run_time += delta

	# Mana regeneration
	var cap: float = float(max_mana())
	if mana < cap:
		mana = minf(cap, mana + mana_regen() * delta)
		mana_changed.emit(mana, max_mana(), mana_regen())

	var prev_dmg_active: bool = damage_boost_timer > 0.0
	var prev_heal_active: bool = heal_potion_timer > 0.0
	if damage_boost_timer > 0.0:
		damage_boost_timer = maxf(0.0, damage_boost_timer - delta)
	if heal_potion_timer > 0.0:
		heal_potion_timer = maxf(0.0, heal_potion_timer - delta)
	if (prev_dmg_active and damage_boost_timer <= 0.0) or (prev_heal_active and heal_potion_timer <= 0.0):
		changed.emit()


# --- Enemy HP scaling (difficulty + time after 3 minutes) ---

## Scales monster base HP by difficulty, 3-minute time scaling, and Endless Mode wave multiplier:
## - Easy: no time scaling
## - Medium: +5 HP per 30 s
## - Hard: ×1.2 per 30 s
## - Extreme: ×1.5 per 30 s
func scaled_monster_hp(base_hp: int) -> float:
	var mult: float = difficulty.hp_mult if difficulty != null else 1.0
	var hp: float = float(Config.scale_hp(base_hp, mult))
	if run_time >= Config.TIME_SCALE_START_SEC and difficulty != null:
		var steps: int = int(floor((run_time - Config.TIME_SCALE_START_SEC) / Config.TIME_SCALE_INTERVAL_SEC)) + 1
		match difficulty.name:
			"Medium":
				hp += Config.TIME_SCALE_MEDIUM_ADD * steps
			"Hard":
				hp *= pow(Config.TIME_SCALE_HARD_MULT, steps)
			"Extreme":
				hp *= pow(Config.TIME_SCALE_EXTREME_MULT, steps)
	return hp * endless_hp_mult


func scaled_nest_hp() -> float:
	var mult: float = difficulty.hp_mult if (Config.DIFFICULTY_SCALES_NESTS_AND_BOSSES and difficulty != null) else 1.0
	return float(Config.scale_hp(Config.NEST_HP, mult)) * endless_hp_mult


func scaled_boss_hp() -> float:
	var mult: float = difficulty.hp_mult if (Config.DIFFICULTY_SCALES_NESTS_AND_BOSSES and difficulty != null) else 1.0
	return float(Config.scale_hp(Config.BOSS_HP, mult)) * endless_hp_mult


func scaled_mega_boss_hp() -> float:
	var mult: float = difficulty.hp_mult if (Config.DIFFICULTY_SCALES_NESTS_AND_BOSSES and difficulty != null) else 1.0
	return float(Config.scale_hp(Config.MEGA_BOSS_HP, mult)) * endless_hp_mult


# --- Mana & Spell Mods ---

func max_mana() -> int:
	return Config.max_mana_for_level(int(mod_levels.get("mana_pool", 0)))


func is_mana_pool_maxed() -> bool:
	return int(mod_levels.get("mana_pool", 0)) >= Config.MANA_POOL_MAX_LEVEL


func mana_regen() -> float:
	return Config.BASE_MANA_REGEN + Config.MANA_REGEN_STEP * int(mod_levels.get("mana_regen", 0))


func try_spend_mana(cost: float) -> bool:
	if mana + 1e-4 < cost:
		return false
	mana = maxf(0.0, mana - cost)
	mana_changed.emit(mana, max_mana(), mana_regen())
	return true


# --- Spell stats ---

## Builds a spell stat Dictionary: { name, damage, fire_rate, speed_tiles, range_tiles, color, radius_tiles, mana_cost }.
static func make_spell_stats(data: SpellData, damage: float, fire_rate: float, speed_tiles: float, range_tiles: float, mana_cost: float) -> Dictionary:
	return {
		"name": data.name,
		"damage": damage,
		"fire_rate": fire_rate,
		"speed_tiles": speed_tiles,
		"range_tiles": range_tiles,
		"color": data.color,
		"radius_tiles": data.radius_tiles,
		"mana_cost": mana_cost,
	}


func mod_multiplier(id: String) -> float:
	return 1.0 + Config.MOD_STEP * int(mod_levels.get(id, 0))


func damage_boost_multiplier() -> float:
	return Config.DAMAGE_POTION_MULT if damage_boost_timer > 0.0 else 1.0


## Current base spell stats: level damage × damage mod, range × range mod, costs 1 mana.
func base_spell_stats() -> Dictionary:
	var b: SpellData = Config.BASE_SPELL
	return make_spell_stats(b,
		Config.spell_damage(spell_level) * mod_multiplier("damage"),
		b.fire_rate,
		b.speed_tiles,
		b.range_tiles * mod_multiplier("range"),
		Config.BASE_SPELL_MANA_COST)


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


# --- Spell Scrolls (Mods) ---

func add_mod_parts(amount: int) -> void:
	mod_parts += amount
	changed.emit()


func next_mod_cost(id: String) -> int:
	return Config.mod_cost(int(mod_levels.get(id, 0)))


func is_mod_maxed(id: String) -> bool:
	return id == "mana_pool" and is_mana_pool_maxed()


func try_buy_mod(id: String) -> bool:
	if not Config.MODS.has(id) or is_mod_maxed(id):
		return false
	var cost: int = next_mod_cost(id)
	if mod_parts < cost:
		return false
	var old_max: int = max_mana()
	mod_parts -= cost
	mod_levels[id] = int(mod_levels.get(id, 0)) + 1
	if id == "mana_pool":
		var gained: int = max_mana() - old_max
		mana = minf(float(max_mana()), mana + float(gained))
	mana_changed.emit(mana, max_mana(), mana_regen())
	changed.emit()
	return true


# --- Augmentation Scrolls & Augmentations ---

func add_aug_scrolls(amount: int) -> void:
	aug_scrolls += amount
	changed.emit()


func aug_level(id: String) -> int:
	return int(aug_levels.get(id, 0))


func is_aug_maxed(id: String) -> bool:
	return aug_level(id) >= Config.AUG_MAX_LEVEL


func next_aug_cost(id: String) -> int:
	return Config.aug_cost(aug_level(id))


func try_buy_aug(id: String) -> bool:
	if not Config.AUGMENTATIONS.has(id) or is_aug_maxed(id):
		return false
	var cost: int = next_aug_cost(id)
	if aug_scrolls < cost:
		return false
	aug_scrolls -= cost
	aug_levels[id] = aug_level(id) + 1
	changed.emit()
	return true


## Number of split projectiles when Split Spell triggers (Lv 1 → 2, Lv 2 → 3, Lv 3 → 4).
func split_count() -> int:
	var lvl: int = aug_level("split")
	return 0 if lvl <= 0 else lvl + 1


## Bombspell fire damage per second (Lv 1 → 3, Lv 2 → 5, Lv 3 → 7).
func bomb_dps() -> float:
	var lvl: int = aug_level("bomb")
	return 0.0 if lvl <= 0 else Config.BOMB_BASE_DPS + Config.BOMB_DPS_STEP * (lvl - 1)


## Sniper shot damage multiplier (Lv 1 → 2×, Lv 2 → 3×, Lv 3 → 4×).
func sniper_damage_mult() -> float:
	var lvl: int = aug_level("sniper")
	return 0.0 if lvl <= 0 else Config.SNIPER_BASE_DAMAGE_MULT + Config.SNIPER_DAMAGE_STEP * (lvl - 1)


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


func try_buy_magnet() -> bool:
	if magnet_unlocked or gold < Config.GOLD_SHOP_MAGNET_COST:
		return false
	gold -= Config.GOLD_SHOP_MAGNET_COST
	magnet_unlocked = true
	changed.emit()
	return true


func try_buy_auto_shoot() -> bool:
	if auto_shoot_unlocked or gold < Config.GOLD_SHOP_AUTO_SHOOT_COST:
		return false
	gold -= Config.GOLD_SHOP_AUTO_SHOOT_COST
	auto_shoot_unlocked = true
	changed.emit()
	return true


func try_buy_homing() -> bool:
	if homing_unlocked or gold < Config.GOLD_SHOP_HOMING_COST:
		return false
	gold -= Config.GOLD_SHOP_HOMING_COST
	homing_unlocked = true
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
## Costs 2 mana per cast.
func acquire_boss_spell() -> Dictionary:
	var base: Dictionary = base_spell_stats()
	var damage: float
	if boss_spells.is_empty():
		damage = base["damage"] * 2.0
	else:
		damage = 0.0
		for s in all_spells():
			damage += s["damage"]
	var spell: Dictionary = make_spell_stats(
		Config.BOSS_SPELL,
		damage,
		base["fire_rate"] * Config.BOSS_SPELL_FIRE_RATE_MULT,
		base["speed_tiles"],
		base["range_tiles"],
		Config.BOSS_SPELL_MANA_COST
	)
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


## Victory in Normal mode when the mega boss is defeated; in Endless mode, spawns 4 new spawners
## and doubles everything's HP (×2 per Mega Boss kill).
func on_mega_boss_defeated() -> void:
	if endless_mode:
		endless_wave += 1
		endless_hp_mult *= Config.ENDLESS_WAVE_HP_MULT
		nests_destroyed = 0
		mega_boss_spawned = false
		mega_boss_defeated = false
		changed.emit()
		endless_wave_started.emit(endless_wave)
		return
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
