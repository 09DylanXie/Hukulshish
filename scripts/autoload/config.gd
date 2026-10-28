extends Node
## Global constants + data loaders (autoload "Config").
## Numbers that come straight from AGENTS.md are marked with the section they come from.
## Numbers that are NOT in the design doc are marked `# TODO(design)` — see AGENTS.md §9.

## Base unit for distance and speed (AGENTS.md §2 Conventions).
const TILE_SIZE: int = 32

# --- Player (§6.1) ---
const PLAYER_MAX_HP: int = 10
const PLAYER_MAX_SHIELD: int = 5
const PLAYER_SPEED_TILES: float = 3.0
const PLAYER_RADIUS_TILES: float = 0.4
# TODO(design): invulnerability frames after a hit are undefined (§9 Q7).
const PLAYER_IFRAMES_SEC: float = 0.5
## Entering the castle heals the player up to this fraction of max HP, never above it (§5).
const CASTLE_HEAL_FRACTION: float = 0.7

# --- Mana (§6.1–6.3) ---
const BASE_MAX_MANA: int = 10
const BASE_MANA_REGEN: float = 1.0
const MANA_REGEN_STEP: float = 0.5
const MANA_POOL_MAX: int = 29
const MANA_POOL_MAX_LEVEL: int = 12
const BASE_SPELL_MANA_COST: float = 2.0
const BOSS_SPELL_MANA_COST: float = 3.0

# --- Base spell (§6.2) ---
const SPELL_MAX_LEVEL: int = 9
const SPELL_DAMAGE_BY_LEVEL: Array = [1, 3, 5, 7, 9, 11, 13, 18, 23]
# TODO(design): upgrade cost is undecided (§9 Q1). cost = base * growth ^ (level - 1)
const SPELL_UPGRADE_BASE_COST: int = 5
const SPELL_UPGRADE_GROWTH: float = 2.0

# --- Spell mods (§6.3) — bought at the castle with Spell Scrolls ---
## Each level of damage/range adds +0.1× to its stat.
const MOD_STEP: float = 0.1
## Mod ids → display names. Each one has its own level and cost.
const MODS: Dictionary = {
	"damage": "Damage",
	"mana_regen": "Mana Regen",
	"mana_pool": "Mana Pool",
	"range": "Range",
}
## Cost is +1 scroll per upgrade for the first N upgrades (1, 2, 3, 4), then doubles (8, 16, 32 …).
const MOD_LINEAR_UPGRADES: int = 4
## Chance for a killed monster to drop a Spell Scroll.
const MOD_PART_DROP_CHANCE: float = 1.0 / 7.0

# --- Augmentations (§6.3) — bought with Augmentation Scrolls dropped by Demons (1/5 chance) ---
const AUG_SCROLL_DROP_CHANCE: float = 1.0 / 5.0
const AUG_MAX_LEVEL: int = 3
const AUGMENTATIONS: Dictionary = {
	"split": "Split Spell",
	"bomb": "Bombspell",
	"sniper": "Sniper",
}
const SPLIT_ANGLE_DEG: float = 30.0
const SPLIT_DAMAGE_MULT: float = 0.5
const BOMB_BASE_DPS: float = 3.0
const BOMB_DPS_STEP: float = 2.0
const BOMB_DURATION_SEC: float = 3.0
const BOMB_RADIUS_TILES: float = 2.2
const BOMB_TICK_SEC: float = 0.25
const SNIPER_SPEED_MULT: float = 5.0
const SNIPER_BASE_DAMAGE_MULT: float = 2.0
const SNIPER_DAMAGE_STEP: float = 1.0

# --- Gold Shop (§6.3) ---
const GOLD_SHOP_MOD_PART_BASE_COST: int = 100
const GOLD_SHOP_MOD_PART_MAX: int = 10
const GOLD_SHOP_SHIELD_COST: int = 200
const GOLD_SHOP_POTION_COST: int = 100
const GOLD_SHOP_MAGNET_COST: int = 100
const GOLD_SHOP_AUTO_SHOOT_COST: int = 1000
const GOLD_SHOP_HOMING_COST: int = 1500
const AUTO_SHOOT_FIRE_RATE_MULT: float = 0.5
const HOMING_TURN_SPEED: float = 16.0
const MAGNET_PULL_SPEED_TILES: float = 14.0
const POTION_DURATION_SEC: float = 30.0
const HEAL_POTION_AMOUNT: int = 3
const DAMAGE_POTION_MULT: float = 2.0
const SHIELD_ITEM_AMOUNT: int = 1

# --- Personal Shop (§6.3) — bought with Enhancers dropped by Goblins (1/3 chance) ---
const ENHANCER_DROP_CHANCE: float = 1.0 / 3.0
const PERSONAL_MAX_LEVEL: int = 3
const PERSONAL_UPGRADE_COSTS: Array[int] = [3, 5, 9]
const PERSONAL_SHOP: Dictionary = {
	"luck": "Luck",
	"move_speed": "Movement Speed",
	"health_regen": "Health Regen",
	"mine_capacity": "Capacity",
	"mine_rate": "Rate",
}
const LUCK_STEP: float = 0.20
const MOVE_SPEED_STEP: float = 0.05
const HEALTH_REGEN_HP_PER_10S_STEP: int = 1
const HEALTH_REGEN_INTERVAL_SEC: float = 10.0
const MINE_CAPACITY_STEP: float = 1.0 / 3.0
const MINE_RATE_STEP: float = 0.15

# --- Boss spells (§6.3) ---
## Chance for a nest boss to drop a new spell.
const BOSS_SPELL_DROP_CHANCE: float = 1.0 / 3.0
## Boss spells fire at this fraction of the base spell's rate (reduced by 1/3).
const BOSS_SPELL_FIRE_RATE_MULT: float = 2.0 / 3.0

# --- Nests (§6.4) ---
const NEST_HP: int = 70
const NEST_SPAWN_DELAY_SEC: float = 5.0
const NEST_BOSS_DELAY_SEC: float = 0.0
const NEST_RADIUS_TILES: float = 1.0
# TODO(design): per-nest alive cap, only here to keep the web build fast.
const NEST_MAX_ALIVE: int = 25

# --- Monsters & Time Scaling (§3, §6.5) ---
# TODO(design): melee attack cooldown is undefined (§9 Q7).
const MONSTER_ATTACK_COOLDOWN_SEC: float = 1.0
## Monster speed depends on size: speed = player speed × min(MAX_RATIO, SIZE_K / radius_tiles).
## Smaller monsters are faster, but never as fast as the player.
const MONSTER_SIZE_SPEED_K: float = 0.3
const MONSTER_MAX_SPEED_RATIO: float = 0.9
## After 3 minutes (180 s), enemy HP scales every 30 s on Medium (+5), Hard (×1.2), and Extreme (×1.5).
const TIME_SCALE_START_SEC: float = 180.0
const TIME_SCALE_INTERVAL_SEC: float = 30.0
const TIME_SCALE_MEDIUM_ADD: float = 5.0
const TIME_SCALE_HARD_MULT: float = 1.2
const TIME_SCALE_EXTREME_MULT: float = 1.5

# --- Nest boss (§6.6) — 4× previous HP (20 → 80) ---
const BOSS_HP: int = 80
const BOSS_MELEE_DAMAGE: int = 5
const BOSS_BOLT_DAMAGE: int = 1
const BOSS_BOLT_SPEED_TILES: float = 1.0
const BOSS_RADIUS_TILES: float = 0.8
const BOSS_GOLD: int = 1000
# TODO(design): boss speed, fire rate and aim are undefined (§9 Q8).
const BOSS_SPEED_MULT: float = 0.5
const BOSS_FIRE_INTERVAL_SEC: float = 2.0
const BOSS_FIRE_RANGE_TILES: float = 12.0

# --- Mega boss (§6.7) — 2× previous HP (1000 → 2000) ---
const MEGA_BOSS_HP: int = 2000
const MEGA_BOSS_SHIELD_HP: float = 100.0
const MEGA_BOSS_BOLT_SPEED_TILES: float = 6.0
const MEGA_BOSS_RADIUS_TILES: float = 1.5
const MEGA_BOSS_SPAWN_RATE_MULT: float = 2.0
const MEGA_BOSS_SPAWN_BOSS_SEC: float = 25.0
# TODO(design): cap on monsters the mega boss keeps alive (performance).
const MEGA_BOSS_MAX_MINIONS: int = 40

# --- Endless Mode (§3) ---
const ENDLESS_WAVE_HP_MULT: float = 2.0

# TODO(design): does the difficulty HP multiplier also scale nests + bosses? (§9 Q4). Assumed no.
const DIFFICULTY_SCALES_NESTS_AND_BOSSES: bool = false

# --- Castle (§5) ---
const CASTLE_SIZE_TILES: float = 4.0

# --- Gold mines (§6.8) ---
const GOLD_MINE_COUNT: int = 2
## Reduced by 1/4 from 10.0 → 7.5 gold/sec.
const GOLD_MINE_RATE: float = 7.5
## Reduced by 1/3 from 500 → 333 gold.
const GOLD_MINE_CAP: int = 333

# --- Maze walls (§6.9) ---
## Maze grid cell size in tiles (corridor width ≈ this minus wall thickness).
const MAZE_CELL_TILES: int = 5
const MAZE_WALL_THICKNESS_TILES: float = 0.5
## Walls only exist outside this fraction of the center→edge distance
## (i.e. they start 2/3 of the way in from the edge toward the castle).
const MAZE_CLEAR_CENTER_FRACTION: float = 1.0 / 3.0
## Chance to knock out each extra wall after carving, so the maze feels spacious with loops.
const MAZE_EXTRA_OPENING_CHANCE: float = 0.35

# --- Physics layers (bit values; names are set in project.godot) ---
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMIES: int = 4
const LAYER_PLAYER_PROJECTILES: int = 8
const LAYER_ENEMY_PROJECTILES: int = 16
const LAYER_NESTS: int = 32

# --- Data resources ---
## One entry per nest, in corner order: top-left, top-right, bottom-left, bottom-right.
## TODO(design): nest → monster mapping assumed one class per nest (§9 Q9).
const MONSTERS: Array = [
	preload("res://resources/monsters/goblin.tres"),
	preload("res://resources/monsters/undead.tres"),
	preload("res://resources/monsters/ogre.tres"),
	preload("res://resources/monsters/demon.tres"),
]
const DIFFICULTIES: Array = [
	preload("res://resources/difficulty/easy.tres"),
	preload("res://resources/difficulty/medium.tres"),
	preload("res://resources/difficulty/hard.tres"),
	preload("res://resources/difficulty/extreme.tres"),
]
const MAP_SIZES: Array = [
	preload("res://resources/maps/small.tres"),
	preload("res://resources/maps/medium.tres"),
	preload("res://resources/maps/large.tres"),
]
const BASE_SPELL: SpellData = preload("res://resources/spells/base_spell.tres")
## Visual template for spells dropped by bosses (stats are computed when picked up).
const BOSS_SPELL: SpellData = preload("res://resources/spells/boss_spell.tres")


## Converts tiles to pixels.
func tiles(amount: float) -> float:
	return amount * TILE_SIZE


## Base spell damage at a level (1..SPELL_MAX_LEVEL), before mods.
func spell_damage(level: int) -> int:
	var i: int = clampi(level, 1, SPELL_MAX_LEVEL) - 1
	return SPELL_DAMAGE_BY_LEVEL[i]


## Gold needed to go from `level` to `level + 1`.
func upgrade_cost(level: int) -> int:
	return int(round(SPELL_UPGRADE_BASE_COST * pow(SPELL_UPGRADE_GROWTH, level - 1)))


## Spell Scrolls needed to buy the next level of a mod that is currently at `level` (0-based).
## 1, 2, 3, 4, then 8, 16, 32 …
func mod_cost(level: int) -> int:
	var n: int = level + 1
	if n <= MOD_LINEAR_UPGRADES:
		return n
	return MOD_LINEAR_UPGRADES * int(pow(2, n - MOD_LINEAR_UPGRADES))


## Max mana for a given `mana_pool` upgrade level (0..12):
## +1 per level from 10 up to 15 (levels 1..5), then +2 per level from 15 up to 29 (levels 6..12).
func max_mana_for_level(pool_level: int) -> int:
	var lvl: int = clampi(pool_level, 0, MANA_POOL_MAX_LEVEL)
	if lvl <= 5:
		return BASE_MAX_MANA + lvl
	return 15 + (lvl - 5) * 2


## Augmentation Scroll cost for the next level of an augmentation currently at `level` (0..2): 1, 2, 3.
func aug_cost(level: int) -> int:
	return level + 1


## Enhancer cost for the next level of a Personal Shop upgrade currently at `level` (0..2): 3, 5, 9.
func personal_cost(level: int) -> int:
	var idx: int = clampi(level, 0, PERSONAL_UPGRADE_COSTS.size() - 1)
	return PERSONAL_UPGRADE_COSTS[idx]


## Gold cost for the next Spell Scroll in the Gold Shop (100, 200, ..., 1000).
func gold_mod_part_cost(bought_so_far: int) -> int:
	return (bought_so_far + 1) * GOLD_SHOP_MOD_PART_BASE_COST


## Monster speed in tiles/sec from its size.
func monster_speed_tiles(radius_tiles: float) -> float:
	return PLAYER_SPEED_TILES * minf(MONSTER_MAX_SPEED_RATIO, MONSTER_SIZE_SPEED_K / radius_tiles)


## Applies a difficulty multiplier to a base HP, rounding up (§9 Q4 assumption), minimum 1.
func scale_hp(base_hp: int, mult: float) -> int:
	return maxi(1, ceili(base_hp * mult))
