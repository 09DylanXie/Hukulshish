class_name RunState
extends Node
## Current run state (autoload "GameState").
## Systems listen to these signals instead of referencing each other.

## Emitted whenever anything the HUD / castle menu shows changes.
signal changed
signal mana_changed(mana: float, max_mana: int, regen: float)
signal endless_started
signal layer_entered(layer: LayerData)
signal doppelganger_spawn_requested(snapshot: Dictionary)
signal screen_shake_requested(intensity: float, duration: float)
signal floating_text_requested(world_pos: Vector2, text: String, col: Color)
signal victory
signal defeat

## What a guest's copy of the run receives from the host.
const NET_FIELDS: Array[String] = [
	"gold", "spell_level", "mod_parts", "mod_parts_bought_with_gold", "mod_levels", "aug_scrolls", "aug_levels",
	"enhancers", "personal_levels", "max_hp_level", "doppelganger_alive", "revival_unlocked", "magnet_unlocked",
	"auto_collector_unlocked", "mine_gold_estimate", "mines_left_behind", "wall_pierce_unlocked",
	"nothing_unlocked", "doppelganger_items", "homing_unlocked", "homing_enabled", "shield_items", "heal_potions",
	"damage_potions", "damage_boost_timer",
]

## What the player has to do next on the current layer.
enum LayerStage {
	NEST,
	BOSS,
	PORTAL,
}


var map_size: MapSizeData
var difficulty: DifficultyData
var endless_mode: bool = false
var sandbox_mode: bool = false
var coop_mode: bool = false
## True on a guest, whose GameState only mirrors what the host says.
var is_mirror: bool = false
var revival_unlocked: bool = false
var castle_menu_open: bool = false
var pause_menu_open: bool = false
## True once the dragon has fallen and Endless Mode has taken over.
var endless_active: bool = false
var endless_megas_defeated: int = 0
var endless_next_boss_sec: float = 0.0

## Index into Config.LAYERS, which is also how many times the player has descended.
var layer_index: int = 0
var layer_stage: LayerStage = LayerStage.NEST

var gold: int = 0
var spell_level: int = 1
## Spell Scrolls (formerly Mod Parts) dropped by monsters or bought in the Gold Shop.
var mod_parts: int = 0
## How many Spell Scrolls have been purchased with gold in the Gold Shop (max 10).
var mod_parts_bought_with_gold: int = 0
## Mod id → level (see Config.MODS).
var mod_levels: Dictionary = {}

## Augmentation Scrolls dropped only by floor bosses.
var aug_scrolls: int = 0
## Augmentation id → level (0..3, see Config.AUGMENTATIONS).
var aug_levels: Dictionary = {}

## Enhancers dropped by monsters, spent in the Personal Shop.
var enhancers: int = 0
## Personal Shop id → level (0..3, see Config.PERSONAL_SHOP).
var personal_levels: Dictionary = {}

## Mana state
var mana: float = Config.BASE_MAX_MANA

## Spells found on the layers. Each is a frozen stat Dictionary (see make_spell_stats()).
var unique_spells: Array[Dictionary] = []
## The spell left-click fires, by SpellData.Effect. Each player's own, so it isn't sent to guests.
var selected_effect: int = SpellData.Effect.NONE

# --- Gold Shop unlocks & hotbar consumables ---
var max_hp_level: int = 0
var doppelganger_alive: bool = false
var doppelganger_items: int = 0
var magnet_unlocked: bool = false
var auto_collector_unlocked: bool = false
var auto_collector_timer: float = 0.0
## Below the Overworld there are no mine nodes, so their total stored gold is estimated here.
var mines_left_behind: bool = false
var mine_gold_estimate: float = 0.0
## This player's share of the mines while below them, since co-op teams split the gold.
var mine_share: float = 1.0
var wall_pierce_unlocked: bool = false
var nothing_unlocked: bool = false
var homing_unlocked: bool = false
var homing_enabled: bool = false
var shield_items: int = 0
var heal_potions: int = 0
var damage_potions: int = 0
var damage_boost_timer: float = 0.0

var nests_destroyed: int = 0
## Nests still standing on this layer. The boss comes when this reaches 0.
var layer_nests_left: int = 0
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
	layer_index = 0
	layer_stage = LayerStage.NEST
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
	enhancers = 0
	personal_levels.clear()
	for id in Config.PERSONAL_SHOP:
		personal_levels[id] = 0
	mana = float(max_mana())
	unique_spells.clear()
	selected_effect = SpellData.Effect.NONE
	max_hp_level = 0
	doppelganger_alive = false
	doppelganger_items = 0
	revival_unlocked = false
	castle_menu_open = false
	pause_menu_open = false
	magnet_unlocked = false
	auto_collector_unlocked = false
	auto_collector_timer = 0.0
	mines_left_behind = false
	mine_gold_estimate = 0.0
	wall_pierce_unlocked = false
	nothing_unlocked = false
	homing_unlocked = false
	homing_enabled = false
	shield_items = 0
	heal_potions = 0
	damage_potions = 0
	damage_boost_timer = 0.0
	nests_destroyed = 0
	layer_nests_left = 0
	bosses_defeated = 0
	mega_boss_spawned = false
	mega_boss_defeated = false
	endless_active = false
	endless_megas_defeated = 0
	endless_next_boss_sec = 0.0
	run_over = false
	if sandbox_mode:
		_refill_sandbox_resources()
	changed.emit()
	mana_changed.emit(mana, max_mana(), mana_regen())


func _refill_sandbox_resources() -> void:
	if not sandbox_mode:
		return
	gold = 999999
	mod_parts = 9999
	aug_scrolls = 999
	enhancers = 999
	mana = float(max_mana())
	shield_items = maxi(shield_items, 99)
	heal_potions = maxi(heal_potions, 99)
	damage_potions = maxi(damage_potions, 99)
	doppelganger_items = maxi(doppelganger_items, 99)


func _process(delta: float) -> void:
	if get_tree().paused or run_over or is_mirror:
		return

	# Mana regeneration
	var cap: float = float(max_mana())
	if sandbox_mode:
		if mana < cap:
			mana = cap
			mana_changed.emit(mana, max_mana(), mana_regen())
	elif mana < cap:
		mana = minf(cap, mana + mana_regen() * delta)
		mana_changed.emit(mana, max_mana(), mana_regen())

	if mines_left_behind:
		mine_gold_estimate = minf(mine_gold_capacity(), mine_gold_estimate + gold_mine_rate() * Config.GOLD_MINE_COUNT * mine_share * delta)

	# Auto Gold Collector: collects stored gold from all mines on a timer
	if auto_collector_unlocked:
		auto_collector_timer -= delta
		if auto_collector_timer <= 0.0:
			auto_collector_timer += Config.AUTO_COLLECTOR_INTERVAL_SEC
			collect_all_gold_mines()

	var prev_dmg_active: bool = damage_boost_timer > 0.0
	if damage_boost_timer > 0.0:
		damage_boost_timer = maxf(0.0, damage_boost_timer - delta)
	if prev_dmg_active and damage_boost_timer <= 0.0:
		changed.emit()


# --- Layers (§6.6) ---

func current_layer() -> LayerData:
	return Config.LAYERS[layer_index]


## How much faster this layer's nests spawn (§6.7).
func spawn_rate_mult() -> float:
	return 1.0 + Config.SPAWN_RATE_STEP_PER_LAYER * layer_index


## The slow walk down to the crystal, before the fight starts.
func in_abyss_approach() -> bool:
	return current_layer().is_final and not mega_boss_spawned and not endless_active


## Moves to the next layer. Portals are one-way, so there is no way back up.
func descend() -> bool:
	if layer_index >= Config.LAYERS.size() - 1:
		return false
	layer_index += 1
	layer_stage = LayerStage.NEST
	changed.emit()
	layer_entered.emit(current_layer())
	return true


# --- Enemy HP scaling (§3) ---

## How deep monsters scale. Endless returns to the Overworld but keeps the Abyss's strength.
func _hp_depth() -> int:
	return Config.LAYERS.size() - 1 if endless_active else layer_index


func _coop_descent_mult() -> float:
	return pow(Config.COOP_HP_MULT_PER_DESCENT, _hp_depth())


func _difficulty_hp_mult() -> float:
	return difficulty.hp_mult * pow(difficulty.hp_growth_per_layer, _hp_depth())


## Base HP × difficulty × compounding growth per descent.
func scaled_monster_hp(base_hp: int) -> float:
	var coop_mult: float = Config.COOP_RULES.monster_hp_multiplier * _coop_descent_mult() if coop_mode else 1.0
	return float(Config.scale_hp(int(round(base_hp * coop_mult)), _difficulty_hp_mult()))


## Nests scale like monsters, but co-op doesn't multiply them.
func scaled_nest_hp() -> float:
	return float(Config.scale_hp(Config.NEST_HP, _difficulty_hp_mult()))


## Floor bosses ignore difficulty and grow by a fixed step per descent.
func scaled_boss_hp() -> float:
	return boss_hp_on_layer(layer_index)


func boss_hp_on_layer(index: int) -> float:
	var coop_mult: float = Config.COOP_RULES.boss_hp_multiplier * pow(Config.COOP_HP_MULT_PER_DESCENT, index) if coop_mode else 1.0
	var growth: float = pow(Config.BOSS_HP_GROWTH_PER_LAYER, index)
	return float(Config.scale_hp(int(round(Config.BOSS_HP * coop_mult)), growth))


## The Mega Boss ignores difficulty and depth.
func scaled_mega_boss_hp() -> float:
	var coop_mult: float = Config.COOP_RULES.boss_hp_multiplier if coop_mode else 1.0
	return float(Config.scale_hp(Config.MEGA_BOSS_HP, coop_mult))


## The next Endless Mega Boss's HP multiplier: 1.5×, 2×, 2.5× …
func endless_mega_hp_mult() -> float:
	return Config.ENDLESS_MEGA_HP_BASE_MULT + Config.ENDLESS_MEGA_HP_STEP * endless_megas_defeated


# --- Mana & Spell Mods ---

func max_mana() -> int:
	return Config.max_mana_for_level(int(mod_levels.get("mana_pool", 0)))


func is_mana_pool_maxed() -> bool:
	return int(mod_levels.get("mana_pool", 0)) >= Config.MANA_POOL_MAX_LEVEL


func mana_regen() -> float:
	return Config.BASE_MANA_REGEN + Config.MANA_REGEN_STEP * int(mod_levels.get("mana_regen", 0))


func try_spend_mana(cost: float) -> bool:
	if sandbox_mode:
		mana = float(max_mana())
		mana_changed.emit(mana, max_mana(), mana_regen())
		return true
	if mana + 1e-4 < cost:
		return false
	mana = maxf(0.0, mana - cost)
	mana_changed.emit(mana, max_mana(), mana_regen())
	return true


# --- Spell stats ---

## Builds a spell stat Dictionary: { name, damage, fire_rate, speed_tiles, range_tiles, color, radius_tiles, mana_cost, uses_augments, aug_levels, effect, cast_sound }.
static func make_spell_stats(
	data: SpellData,
	damage: float,
	fire_rate: float,
	speed_tiles: float,
	range_tiles: float,
	mana_cost: float,
	uses_augments: bool = false,
	aug_snapshot: Dictionary = {}
) -> Dictionary:
	return {
		"name": data.name,
		"damage": damage,
		"fire_rate": fire_rate,
		"speed_tiles": speed_tiles,
		"range_tiles": range_tiles,
		"color": data.color,
		"radius_tiles": data.radius_tiles,
		"mana_cost": mana_cost,
		"uses_augments": uses_augments,
		"aug_levels": aug_snapshot,
		"effect": data.effect,
		"cast_sound": data.cast_sound,
		"can_home": data.can_home,
	}


func mod_multiplier(id: String) -> float:
	var step: float = Config.RANGE_MOD_STEP if id == "range" else Config.MOD_STEP
	return 1.0 + step * int(mod_levels.get(id, 0))


func damage_boost_multiplier() -> float:
	return Config.DAMAGE_POTION_MULT if damage_boost_timer > 0.0 else 1.0


## Current base spell stats: level damage × damage mod, range × range mod, costs 2 mana, uses augments.
func base_spell_stats() -> Dictionary:
	var b: SpellData = Config.BASE_SPELL
	return make_spell_stats(b,
		Config.spell_damage(spell_level) * mod_multiplier("damage"),
		b.fire_rate,
		b.speed_tiles,
		b.range_tiles * mod_multiplier("range"),
		Config.BASE_SPELL_MANA_COST,
		true)


## What Abyssal Corruption deals to the Mega Boss: every spell's damage added together.
func combined_spell_damage() -> float:
	var total: float = 0.0
	for spell: Dictionary in all_spells():
		total += float(spell["damage"])
	return total * damage_boost_multiplier()


## Every spell the player fires: the base spell first, then the spells that fire alongside it.
func all_spells() -> Array[Dictionary]:
	var list: Array[Dictionary] = [base_spell_stats()]
	list.append_array(unique_spells)
	return list


## Picks what left-click fires. Spells the player doesn't have are ignored.
func select_spell(effect: int) -> bool:
	if effect == selected_effect:
		return true
	for spell: Dictionary in all_spells():
		if int(spell["effect"]) == effect:
			selected_effect = effect
			changed.emit()
			return true
	return false


func selected_spell() -> Dictionary:
	var spells: Array[Dictionary] = all_spells()
	for spell: Dictionary in spells:
		if int(spell["effect"]) == selected_effect:
			return spell
	return spells[0]


# --- Gold / base spell level ---

func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()


## Adds gold dropped by monsters and bosses, scaled by the Personal Shop Income Multiplier (+50% per level).
func add_combat_gold(base_gold: int) -> void:
	if base_gold <= 0:
		return
	var scaled: int = maxi(1, int(round(float(base_gold) * income_multiplier())))
	add_gold(scaled)


## The host calls this once per death. A co-op kill never pays the host by default.
func award_kill_gold(base_gold: int, killer: RunState) -> void:
	if coop_mode:
		if is_instance_valid(killer):
			killer.add_combat_gold(base_gold)
	else:
		add_combat_gold(base_gold)


## Player-owned attacks retain their owner through splits, fire and chain hits.
func deal_damage(target: Node, amount: float) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	if target.has_method("take_player_damage"):
		target.call("take_player_damage", amount, self)
	else:
		target.call("take_damage", amount)


func is_spell_maxed() -> bool:
	return spell_level >= Config.SPELL_MAX_LEVEL


func next_upgrade_cost() -> int:
	return Config.upgrade_cost(spell_level)


func try_upgrade_spell() -> bool:
	if is_spell_maxed():
		return false
	var cost: int = next_upgrade_cost()
	if not sandbox_mode and gold < cost:
		return false
	if not sandbox_mode:
		gold -= cost
	spell_level += 1
	_refill_sandbox_resources()
	changed.emit()
	return true


# --- Spell Scrolls (Mods) ---

func add_mod_parts(amount: int) -> void:
	mod_parts += amount
	changed.emit()


func next_mod_cost(id: String) -> int:
	return Config.mod_cost(int(mod_levels.get(id, 0)))


func is_mod_maxed(id: String) -> bool:
	return int(mod_levels.get(id, 0)) >= Config.mod_max_level(id)


func try_buy_mod(id: String) -> bool:
	if not Config.MODS.has(id) or is_mod_maxed(id):
		return false
	var cost: int = next_mod_cost(id)
	if not sandbox_mode and mod_parts < cost:
		return false
	var old_max: int = max_mana()
	if not sandbox_mode:
		mod_parts -= cost
	mod_levels[id] = int(mod_levels.get(id, 0)) + 1
	if id == "mana_pool":
		var gained: int = max_mana() - old_max
		mana = minf(float(max_mana()), mana + float(gained))
	_refill_sandbox_resources()
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
	if not sandbox_mode and aug_scrolls < cost:
		return false
	if not sandbox_mode:
		aug_scrolls -= cost
	aug_levels[id] = aug_level(id) + 1
	_refill_sandbox_resources()
	changed.emit()
	return true


## Maximum number of sequential chain-splits when Split Spell triggers (Lv 1 → 1, Lv 2 → 2, Lv 3 → 3).
func max_split_depth() -> int:
	return aug_level("split")


## Each split always produces 2 projectiles when Split Spell is unlocked.
func split_count() -> int:
	return Config.SPLIT_PROJECTILES_PER_HIT if aug_level("split") > 0 else 0


## Bombspell fire damage per second (Lv 1 → 3, Lv 2 → 5, Lv 3 → 7).
func bomb_dps() -> float:
	var lvl: int = aug_level("bomb")
	return 0.0 if lvl <= 0 else Config.BOMB_BASE_DPS + Config.BOMB_DPS_STEP * (lvl - 1)


## Sniper shot damage multiplier (Lv 1 → 2×, Lv 2 → 3×, Lv 3 → 4×).
func sniper_damage_mult() -> float:
	var lvl: int = aug_level("sniper")
	return 0.0 if lvl <= 0 else Config.SNIPER_BASE_DAMAGE_MULT + Config.SNIPER_DAMAGE_STEP * (lvl - 1)


# --- Personal Shop (Goblin Enhancers) ---

func add_enhancers(amount: int) -> void:
	enhancers += amount
	changed.emit()


func personal_level(id: String) -> int:
	return int(personal_levels.get(id, 0))


func is_personal_maxed(id: String) -> bool:
	return personal_level(id) >= Config.PERSONAL_MAX_LEVEL


func next_personal_cost(id: String) -> int:
	return Config.personal_cost(personal_level(id))


func try_buy_personal(id: String) -> bool:
	if not Config.PERSONAL_SHOP.has(id) or is_personal_maxed(id):
		return false
	var cost: int = next_personal_cost(id)
	if not sandbox_mode and enhancers < cost:
		return false
	if not sandbox_mode:
		enhancers -= cost
	personal_levels[id] = personal_level(id) + 1
	_refill_sandbox_resources()
	changed.emit()
	return true


## Luck multiplies how many items a drop gives (levels 0..3: ×1, ×1, ×2, ×3).
func luck_multiplier() -> int:
	return Config.LUCK_DROP_MULT_BY_LEVEL[personal_level("luck")]


## Movement Speed: +10% player movement speed per upgrade (non-cumulative: 1.0, 1.1, 1.2, 1.3).
func player_speed_tiles() -> float:
	return Config.PLAYER_SPEED_TILES * (1.0 + Config.MOVE_SPEED_STEP * personal_level("move_speed"))


## Health Regen: +1 HP / 10 secs per upgrade (0, 1, 2, 3 HP per 10s).
func health_regen_per_10s() -> int:
	return Config.HEALTH_REGEN_HP_PER_10S_STEP * personal_level("health_regen")


## Capacity: +1/3 gold mine capacity per upgrade (non-cumulative: ×1, ×4/3, ×5/3, ×2).
func gold_mine_cap() -> int:
	return int(round(float(Config.GOLD_MINE_CAP) * (1.0 + Config.MINE_CAPACITY_STEP * personal_level("mine_capacity"))))


## Rate: +15% gold mine generation rate per upgrade (non-cumulative: 1.0, 1.15, 1.30, 1.45).
func gold_mine_rate() -> float:
	return Config.GOLD_MINE_RATE * (1.0 + Config.MINE_RATE_STEP * personal_level("mine_rate"))


## Income Multiplier: +50% gold from monsters and bosses per upgrade (1.0, 1.5, 2.0, 2.5).
func income_multiplier() -> float:
	return 1.0 + Config.INCOME_STEP * personal_level("income")


# --- Player Max HP Upgrades (7 → 8 → 9 → 12; does not instantly heal the player) ---

func player_max_hp() -> int:
	return Config.player_max_hp_for_level(max_hp_level)


func is_max_hp_maxed() -> bool:
	return max_hp_level >= Config.PLAYER_MAX_HP_MAX_LEVEL


func next_gold_max_hp_cost() -> int:
	return Config.gold_max_hp_cost(max_hp_level)


func try_buy_max_hp_gold() -> bool:
	if is_max_hp_maxed():
		return false
	var cost: int = next_gold_max_hp_cost()
	if not sandbox_mode and gold < cost:
		return false
	if not sandbox_mode:
		gold -= cost
	max_hp_level += 1
	_refill_sandbox_resources()
	changed.emit()
	return true


# --- Gold Shop purchases ---

func try_buy_revival_unlock() -> bool:
	if not coop_mode or run_over or revival_unlocked:
		return false
	var cost: int = Config.COOP_RULES.revival_unlock_cost
	if not sandbox_mode and gold < cost:
		return false
	if not sandbox_mode:
		gold -= cost
	revival_unlocked = true
	changed.emit()
	return true


func can_buy_gold_mod_part() -> bool:
	return sandbox_mode or mod_parts_bought_with_gold < Config.GOLD_SHOP_MOD_PART_MAX


func next_gold_mod_part_cost() -> int:
	return Config.gold_mod_part_cost(mod_parts_bought_with_gold)


func try_buy_gold_mod_part() -> bool:
	if not can_buy_gold_mod_part():
		return false
	var cost: int = next_gold_mod_part_cost()
	if not sandbox_mode and gold < cost:
		return false
	if not sandbox_mode:
		gold -= cost
	mod_parts_bought_with_gold += 1
	mod_parts += 1
	_refill_sandbox_resources()
	changed.emit()
	return true


func try_buy_shield_item() -> bool:
	if not sandbox_mode and gold < Config.GOLD_SHOP_SHIELD_COST:
		return false
	if not sandbox_mode:
		gold -= Config.GOLD_SHOP_SHIELD_COST
	shield_items += 1
	_refill_sandbox_resources()
	changed.emit()
	return true


func try_buy_heal_potion() -> bool:
	if not sandbox_mode and gold < Config.GOLD_SHOP_POTION_COST:
		return false
	if not sandbox_mode:
		gold -= Config.GOLD_SHOP_POTION_COST
	heal_potions += 1
	_refill_sandbox_resources()
	changed.emit()
	return true


func try_buy_damage_potion() -> bool:
	if not sandbox_mode and gold < Config.GOLD_SHOP_POTION_COST:
		return false
	if not sandbox_mode:
		gold -= Config.GOLD_SHOP_POTION_COST
	damage_potions += 1
	_refill_sandbox_resources()
	changed.emit()
	return true


func try_buy_magnet() -> bool:
	if magnet_unlocked or (not sandbox_mode and gold < Config.GOLD_SHOP_MAGNET_COST):
		return false
	if not sandbox_mode:
		gold -= Config.GOLD_SHOP_MAGNET_COST
	magnet_unlocked = true
	_refill_sandbox_resources()
	changed.emit()
	return true


func try_buy_auto_collector() -> bool:
	if auto_collector_unlocked or (not sandbox_mode and gold < Config.GOLD_SHOP_AUTO_COLLECTOR_COST):
		return false
	if not sandbox_mode:
		gold -= Config.GOLD_SHOP_AUTO_COLLECTOR_COST
	auto_collector_unlocked = true
	auto_collector_timer = Config.AUTO_COLLECTOR_INTERVAL_SEC
	collect_all_gold_mines()
	_refill_sandbox_resources()
	changed.emit()
	return true


func collect_all_gold_mines() -> void:
	for node in get_tree().get_nodes_in_group("gold_mines"):
		if node != null and not node.is_queued_for_deletion() and node.has_method("collect"):
			node.call("collect", self)
	var whole: int = floori(mine_gold_estimate)
	if whole > 0:
		mine_gold_estimate -= whole
		add_gold(whole)
		if whole >= GoldMine.MIN_GOLD_FOR_SOUND:
			AudioManager.play("gold_mine_collect")


## The mines stay on the Overworld and keep filling after the player descends.
func leave_mines_behind(stored_gold: int) -> void:
	mines_left_behind = true
	mine_gold_estimate = float(stored_gold) * mine_share


## Hands back the estimate when the player returns to the mines.
func take_mine_gold() -> float:
	var stored: float = mine_gold_estimate
	mines_left_behind = false
	mine_gold_estimate = 0.0
	return stored


func mine_gold_capacity() -> float:
	return float(gold_mine_cap() * Config.GOLD_MINE_COUNT) * mine_share


func try_buy_wall_pierce() -> bool:
	if wall_pierce_unlocked or (not sandbox_mode and gold < Config.GOLD_SHOP_WALL_PIERCE_COST):
		return false
	if not sandbox_mode:
		gold -= Config.GOLD_SHOP_WALL_PIERCE_COST
	wall_pierce_unlocked = true
	_refill_sandbox_resources()
	changed.emit()
	return true


func try_buy_nothing() -> bool:
	if nothing_unlocked or (not sandbox_mode and gold < Config.GOLD_SHOP_NOTHING_COST):
		return false
	if not sandbox_mode:
		gold -= Config.GOLD_SHOP_NOTHING_COST
	nothing_unlocked = true
	_refill_sandbox_resources()
	changed.emit()
	return true


func try_buy_homing() -> bool:
	if homing_unlocked or (not sandbox_mode and gold < Config.GOLD_SHOP_HOMING_COST):
		return false
	if not sandbox_mode:
		gold -= Config.GOLD_SHOP_HOMING_COST
	homing_unlocked = true
	homing_enabled = true
	_refill_sandbox_resources()
	changed.emit()
	return true


func try_buy_doppelganger() -> bool:
	if not sandbox_mode and gold < Config.GOLD_SHOP_DOPPELGANGER_COST:
		return false
	if not sandbox_mode:
		gold -= Config.GOLD_SHOP_DOPPELGANGER_COST
	doppelganger_items += 1
	_refill_sandbox_resources()
	changed.emit()
	return true


func on_doppelganger_died() -> void:
	doppelganger_alive = false
	changed.emit()


func is_homing_active() -> bool:
	return homing_unlocked and homing_enabled


func toggle_homing() -> bool:
	if not homing_unlocked:
		return false
	homing_enabled = not homing_enabled
	changed.emit()
	return true


# --- Co-op ---

func to_net() -> Dictionary:
	var state: Dictionary = {"mana": mana, "spells": unique_spells}
	for field: String in NET_FIELDS:
		state[field] = get(field)
	return state


## Mana changes constantly, so only the rest refreshes the shop, which rebuilds its buttons.
func apply_net(state: Dictionary) -> void:
	var before: Dictionary = to_net()
	before.erase("mana")
	for field: String in NET_FIELDS:
		set(field, state[field])
	unique_spells.assign(state["spells"])
	mana = float(state["mana"])
	mana_changed.emit(mana, max_mana(), mana_regen())
	var after: Dictionary = to_net()
	after.erase("mana")
	if after.hash() != before.hash():
		changed.emit()


## A guest follows the host down.
func enter_net_layer(index: int, endless: bool) -> void:
	var arrived: bool = index != layer_index
	layer_index = index
	endless_active = endless
	layer_stage = LayerStage.NEST
	mega_boss_spawned = false
	changed.emit()
	if arrived:
		layer_entered.emit(current_layer())


func finish_mirrored_run(won: bool) -> void:
	if run_over:
		return
	run_over = true
	if won:
		mega_boss_defeated = true
		victory.emit()
	else:
		defeat.emit()


# --- Using hotbar items ---

## Uses a hotbar slot: 0 shield, 1 healing potion, 2 damage potion, 3 doppelganger.
func use_slot(index: int, player: Node) -> bool:
	match index:
		0:
			return try_use_shield_item(player)
		1:
			return try_use_heal_potion(player)
		2:
			return try_use_damage_potion()
		3:
			return try_use_doppelganger()
	return false



func try_use_shield_item(player: Node) -> bool:
	if (not sandbox_mode and shield_items <= 0) or player == null or not player.has_method("add_shield"):
		return false
	if not player.add_shield(Config.SHIELD_ITEM_AMOUNT):
		return false
	if not sandbox_mode:
		shield_items -= 1
	_refill_sandbox_resources()
	changed.emit()
	return true


func try_use_heal_potion(player: Node) -> bool:
	if (not sandbox_mode and heal_potions <= 0) or player == null or not player.has_method("heal_amount"):
		return false
	if not player.heal_amount(Config.HEAL_POTION_AMOUNT):
		return false
	if not sandbox_mode:
		heal_potions -= 1
	_refill_sandbox_resources()
	changed.emit()
	return true


func try_use_damage_potion() -> bool:
	if not sandbox_mode and damage_potions <= 0:
		return false
	if not sandbox_mode:
		damage_potions -= 1
	damage_boost_timer = Config.POTION_DURATION_SEC
	_refill_sandbox_resources()
	changed.emit()
	return true


## Summons the twin, which copies the player's abilities as they are now. One at a time.
func try_use_doppelganger() -> bool:
	if doppelganger_alive or (not sandbox_mode and doppelganger_items <= 0):
		return false
	if not sandbox_mode:
		doppelganger_items -= 1
	doppelganger_alive = true
	var snapshot: Dictionary = {
		"spells": all_spells().duplicate(true),
		"aug_levels": aug_levels.duplicate(),
		"homing": homing_unlocked,
		"speed_tiles": player_speed_tiles(),
		"health_regen": health_regen_per_10s(),
	}
	doppelganger_spawn_requested.emit(snapshot)
	_refill_sandbox_resources()
	changed.emit()
	return true


# --- Unique spells ---

## A unique spell copies the base spell at pickup, multiplies its damage, and is frozen after that (§6.4).
func acquire_unique_spell(data: SpellData) -> Dictionary:
	var base: Dictionary = base_spell_stats()
	var spell: Dictionary = make_spell_stats(
		data,
		float(base["damage"]) * data.damage_mult,
		base["fire_rate"],
		data.speed_tiles,
		base["range_tiles"],
		Config.UNIQUE_SPELL_MANA_COST
	)
	unique_spells.append(spell)
	changed.emit()
	return spell


# --- Objectives ---

func set_layer_nests(count: int) -> void:
	layer_nests_left = count
	changed.emit()


func on_nest_destroyed() -> void:
	nests_destroyed += 1
	layer_nests_left -= 1
	if layer_nests_left <= 0:
		layer_stage = LayerStage.BOSS
	changed.emit()


func on_boss_defeated() -> void:
	bosses_defeated += 1
	changed.emit()


func on_layer_boss_defeated() -> void:
	layer_stage = LayerStage.PORTAL
	changed.emit()


func on_mega_boss_spawned() -> void:
	mega_boss_spawned = true
	changed.emit()


## Victory, unless Endless Mode is on, which returns the player to the Overworld instead.
func on_mega_boss_defeated() -> void:
	mega_boss_spawned = false
	if endless_active:
		endless_megas_defeated += 1
		changed.emit()
		return
	if endless_mode:
		changed.emit()
		endless_started.emit()
		return
	mega_boss_defeated = true
	changed.emit()
	if not run_over:
		run_over = true
		victory.emit()


func start_endless() -> void:
	endless_active = true
	layer_index = 0
	changed.emit()


func on_player_died() -> void:
	if coop_mode:
		return # The co-op life controller decides when the entire team is defeated.
	end_run_in_defeat()


func end_run_in_defeat() -> void:
	if run_over:
		return
	run_over = true
	defeat.emit()


func request_shake(intensity: float, duration: float = 0.18) -> void:
	if self == GameState:
		Coop.share_shake(intensity, duration)
	screen_shake_requested.emit(intensity, duration)


func spawn_floating_text(world_pos: Vector2, text: String, col: Color = Color.WHITE) -> void:
	floating_text_requested.emit(world_pos, text, col)

