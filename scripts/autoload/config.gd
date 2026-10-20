extends Node
## Global constants + data loaders (autoload "Config").
## Numbers that come straight from AGENTS.md are marked with the section they come from.
## Numbers that are NOT in the design doc are marked `# TODO(design)` — see AGENTS.md §9.

## Base unit for distance and speed (AGENTS.md §2 Conventions).
const TILE_SIZE: int = 32

# --- Player (§6.1) ---
const PLAYER_MAX_HP: int = 10
const PLAYER_SPEED_TILES: float = 1.0
const PLAYER_RADIUS_TILES: float = 0.4
# TODO(design): invulnerability frames after a hit are undefined (§9 Q7).
const PLAYER_IFRAMES_SEC: float = 0.5

# --- Base spell (§6.2) ---
const SPELL_MAX_LEVEL: int = 9
const SPELL_DAMAGE_BY_LEVEL: Array = [1, 3, 5, 7, 9, 11, 13, 18, 23]
# TODO(design): upgrade cost is undecided (§9 Q1). cost = base * growth ^ (level - 1)
const SPELL_UPGRADE_BASE_COST: int = 5
const SPELL_UPGRADE_GROWTH: float = 2.0
# TODO(design): auto-aim range and projectile lifetime are not in the spec.
const SPELL_TARGET_RANGE_TILES: float = 10.0
const SPELL_LIFETIME_SEC: float = 12.0

# --- Nests (§6.4) ---
const NEST_HP: int = 30
const NEST_SPAWN_DELAY_SEC: float = 5.0
const NEST_MOD_DROP_CHANCE: float = 1.0 / 3.0
const NEST_BOSS_DELAY_SEC: float = 20.0
const NEST_RADIUS_TILES: float = 1.0
# TODO(design): per-nest alive cap, only here to keep the web build fast.
const NEST_MAX_ALIVE: int = 25

# --- Monsters (§6.5) ---
# TODO(design): melee attack cooldown is undefined (§9 Q7).
const MONSTER_ATTACK_COOLDOWN_SEC: float = 1.0

# --- Nest boss (§6.6) ---
const BOSS_HP: int = 20
const BOSS_MELEE_DAMAGE: int = 5
const BOSS_BOLT_DAMAGE: int = 1
const BOSS_BOLT_SPEED_TILES: float = 1.0
const BOSS_RADIUS_TILES: float = 0.8
# TODO(design): boss speed, fire rate, aim and drops are undefined (§9 Q8).
const BOSS_SPEED_MULT: float = 0.5
const BOSS_FIRE_INTERVAL_SEC: float = 2.0
const BOSS_GOLD: int = 10

# TODO(design): does the difficulty HP multiplier also scale nests + bosses? (§9 Q4). Assumed no.
const DIFFICULTY_SCALES_NESTS_AND_BOSSES: bool = false

# --- Castle (§5) ---
const CASTLE_SIZE_TILES: float = 4.0

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
## Mods that can drop from nests.
const SPELL_MODS: Array = [
	preload("res://resources/spells/magic_missile.tres"),
]


## Converts tiles to pixels.
func tiles(amount: float) -> float:
	return amount * TILE_SIZE


## Base spell damage at a level (1..SPELL_MAX_LEVEL).
func spell_damage(level: int) -> int:
	var i: int = clampi(level, 1, SPELL_MAX_LEVEL) - 1
	return SPELL_DAMAGE_BY_LEVEL[i]


## Gold needed to go from `level` to `level + 1`.
func upgrade_cost(level: int) -> int:
	return int(round(SPELL_UPGRADE_BASE_COST * pow(SPELL_UPGRADE_GROWTH, level - 1)))


## Applies a difficulty multiplier to a base HP, rounding up (§9 Q4 assumption), minimum 1.
func scale_hp(base_hp: int, mult: float) -> int:
	return maxi(1, ceili(base_hp * mult))
