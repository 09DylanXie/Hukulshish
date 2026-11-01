extends Node
## Global constants + data loaders (autoload "Config").
## Numbers that come straight from AGENTS.md are marked with the section they come from.
## Numbers that are NOT in the design doc are marked `# TODO(design)`.

signal preferences_changed

## Local presentation settings, independent of run progress and multiplayer state.
var sfx_volume: float = 1.0:
	set(value):
		if not is_finite(value):
			return
		sfx_volume = clampf(value, 0.0, 1.0)
		preferences_changed.emit()
var music_volume: float = 1.0:
	set(value):
		if not is_finite(value):
			return
		music_volume = clampf(value, 0.0, 1.0)
		preferences_changed.emit()
var screen_shake_strength: float = 1.0:
	set(value):
		if not is_finite(value):
			return
		screen_shake_strength = clampf(value, 0.0, 1.0)
		preferences_changed.emit()
var _preferences_path: String = "user://preferences.cfg"


func _ready() -> void:
	load_preferences()


## One more nest on each layer below the Overworld (§6.7): 2, 3, 4, 5.
func nests_on_layer(index: int) -> int:
	return 0 if index >= LAYERS.size() - 1 else FIRST_LAYER_NESTS + index


func total_nests() -> int:
	var total: int = 0
	for index in LAYERS.size():
		total += nests_on_layer(index)
	return total


func load_preferences() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(_preferences_path) != OK:
		return
	var volume: Variant = settings.get_value("effects", "sfx_volume", 1.0)
	var music: Variant = settings.get_value("effects", "music_volume", 1.0)
	var shake: Variant = settings.get_value("effects", "screen_shake_strength", 1.0)
	if volume is float or volume is int:
		sfx_volume = float(volume)
	if music is float or music is int:
		music_volume = float(music)
	if shake is float or shake is int:
		screen_shake_strength = float(shake)


func save_preferences() -> Error:
	var settings: ConfigFile = ConfigFile.new()
	settings.set_value("effects", "sfx_volume", sfx_volume)
	settings.set_value("effects", "music_volume", music_volume)
	settings.set_value("effects", "screen_shake_strength", screen_shake_strength)
	return settings.save(_preferences_path)

## Base unit for distance and speed (AGENTS.md §2 Conventions).
const TILE_SIZE: int = 32

## Three-player Normal co-op. Player, nest, companion and shield HP are unchanged.
const COOP_RULES: Resource = preload("res://resources/multiplayer/coop_rules.tres")

# --- Player (§6.1) ---
const PLAYER_MAX_HP: int = 7
const PLAYER_MAX_HP_BY_LEVEL: Array[int] = [7, 8, 9, 12]
const PLAYER_MAX_HP_MAX_LEVEL: int = 3
const PLAYER_MAX_SHIELD: int = 5
const PLAYER_SPEED_TILES: float = 3.0
const PLAYER_RADIUS_TILES: float = 0.4
# TODO(design): invulnerability frames after a hit aren't in the design doc.
const PLAYER_IFRAMES_SEC: float = 0.5
## Entering a shop stall heals the player up to this share of max HP, and never lowers HP (§6.3).
const SHOP_HEAL_FRACTION: float = 0.75

# --- Mana (§6.1–6.3) ---
const BASE_MAX_MANA: int = 10
const BASE_MANA_REGEN: float = 1.0
const MANA_REGEN_STEP: float = 0.5
const MANA_POOL_MAX: int = 45
const MANA_POOL_MAX_LEVEL: int = 20
const BASE_SPELL_MANA_COST: float = 2.0
const UNIQUE_SPELL_MANA_COST: float = 1.0

# --- Base spell (§6.2) ---
const SPELL_MAX_LEVEL: int = 17
const SPELL_DAMAGE_BY_LEVEL: Array = [1, 3, 5, 7, 9, 11, 13, 18, 23, 28, 33, 38, 43, 48, 53, 58, 63]
## Going from level L to L + 1 costs this × L² gold.
const SPELL_UPGRADE_COST_FACTOR: int = 25

# --- Spell mods (§6.3) — bought at the castle with Spell Scrolls ---
## Each level of damage adds +0.1×, and each level of range adds +0.5×.
const MOD_STEP: float = 0.1
const RANGE_MOD_STEP: float = 0.5
const MOD_MAX_LEVEL: int = 20
## Range stops at 5×.
const RANGE_MOD_MAX_LEVEL: int = 8
## Mod ids → display names. Each one has its own level and cost.
const MODS: Dictionary = {
	"damage": "Damage",
	"mana_regen": "Mana Regen",
	"mana_pool": "Mana Pool",
	"range": "Range",
}

# --- Augmentations (§6.3) — bought with Augmentation Scrolls dropped by floor bosses ---
const AUG_MAX_LEVEL: int = 3
const AUGMENTATIONS: Dictionary = {
	"split": "Split Spell",
	"bomb": "Bombspell",
	"sniper": "Sniper",
}
const SPLIT_ANGLE_DEG: float = 45.0
const SPLIT_PROJECTILES_PER_HIT: int = 2
const SPLIT_DAMAGE_MULT: float = 0.5
## Split Spell Lv 3: lightning joins sibling splits while they're this close.
const SPLIT_ARC_MAX_TILES: float = 6.0
const SPLIT_ARC_DAMAGE_MULT: float = 0.5
const BOMB_BASE_DPS: float = 3.0
const BOMB_DPS_STEP: float = 2.0
const BOMB_DURATION_SEC: float = 3.0
## 5% smaller than previous 2.2 tiles (2.2 × 0.95 = 2.09).
const BOMB_RADIUS_TILES: float = 2.09
const BOMB_TICK_SEC: float = 0.25
const SNIPER_SPEED_MULT: float = 5.0
const SNIPER_BASE_DAMAGE_MULT: float = 2.0
const SNIPER_DAMAGE_STEP: float = 1.0

# --- Gold Shop (§6.3) ---
const GOLD_SHOP_MOD_PART_BASE_COST: int = 100
const GOLD_SHOP_MOD_PART_MAX: int = 10
const GOLD_SHOP_MAX_HP_COSTS: Array[int] = [200, 400, 800]
const GOLD_SHOP_SHIELD_COST: int = 200
const GOLD_SHOP_POTION_COST: int = 100
const GOLD_SHOP_MAGNET_COST: int = 300
const GOLD_SHOP_AUTO_COLLECTOR_COST: int = 1000
const GOLD_SHOP_WALL_PIERCE_COST: int = 500
const AUTO_COLLECTOR_INTERVAL_SEC: float = 15.0
const GOLD_SHOP_HOMING_COST: int = 1500
const GOLD_SHOP_DOPPELGANGER_COST: int = 5000
const GOLD_SHOP_NOTHING_COST: int = 10000
const DOPPELGANGER_MAX_HP: int = 5
const HOMING_TURN_SPEED: float = 16.0
## Homing spells only chase targets inside a cone this wide around the direction they were fired.
const HOMING_CONE_DEG: float = 45.0
const MAGNET_PULL_SPEED_TILES: float = 14.0
const POTION_DURATION_SEC: float = 30.0
const HEAL_POTION_AMOUNT: int = 3
const DAMAGE_POTION_MULT: float = 2.0
const SHIELD_ITEM_AMOUNT: int = 1

# --- Personal Shop (§6.3) — bought with Enhancers ---
const PERSONAL_MAX_LEVEL: int = 3
const PERSONAL_UPGRADE_COSTS: Array[int] = [3, 5, 9]
const PERSONAL_SHOP: Dictionary = {
	"luck": "Luck",
	"move_speed": "Movement Speed",
	"health_regen": "Health Regen",
	"mine_capacity": "Capacity",
	"mine_rate": "Rate",
	"income": "Income Multiplier",
}
## Drop amount multiplier for Luck levels 0..3.
const LUCK_DROP_MULT_BY_LEVEL: Array[int] = [1, 1, 2, 3]
const MOVE_SPEED_STEP: float = 0.1
const HEALTH_REGEN_HP_PER_10S_STEP: int = 1
const HEALTH_REGEN_INTERVAL_SEC: float = 10.0
const MINE_CAPACITY_STEP: float = 1.0 / 3.0
const MINE_RATE_STEP: float = 0.15
const INCOME_STEP: float = 0.50

# --- Layer rules (§6.6) ---
const DARKNESS_RADIUS_TILES: float = 7.5
const DARKNESS_SOFTNESS_TILES: float = 1.5
## Above characters and effects. The HUD is on its own canvas layer, so it stays visible.
const DARKNESS_Z_INDEX: int = 30
const LAVA_DAMAGE: int = 1
const LAVA_DAMAGE_INTERVAL_SEC: float = 3.0
## One crack per this many map tiles along an edge.
const LAVA_TILES_PER_CRACK: int = 2
const LAVA_CRACK_MIN_LENGTH: int = 10
const LAVA_CRACK_MAX_LENGTH: int = 26
const LAVA_CRACK_WIDTH: float = 13.0
const LAVA_CRACK_FORK_CHANCE: float = 0.14
## Lava burns this close to a crack, so a player's feet don't need to be exactly on it.
const LAVA_TOUCH_MARGIN_PX: float = 3.0
## Dry floor cracks, per map tile along an edge.
const DRY_CRACK_WIDTH: float = 3.0
## A Demon's bubble comes back this long after it breaks (§6.8).
const DEMON_SHIELD_REGEN_SEC: float = 9.0

# --- Unique spells (§6.4) ---
## Hidden at least this far from the map center, as a fraction of half the map size.
const UNIQUE_SPELL_MIN_CENTER_FRACTION: float = 0.5
const WATER_SLOW_SPEED_MULT: float = 0.8
const WATER_SLOW_SEC: float = 3.0
const EARTH_STUN_SEC: float = 1.0
## Stops Earth's fire rate from freezing a monster forever.
const EARTH_STUN_COOLDOWN_SEC: float = 2.0
const DEATH_POISON_DPS: float = 3.0
const DEATH_POISON_SEC: float = 3.0
const DEATH_POISON_TICK_SEC: float = 1.0
const FIREBALL_FLASH_SEC: float = 0.3

# --- Shops (§6.3) ---
## Shop stalls and gold mines stand in rows this far left and right of the map center.
const CASTLE_COLUMN_OFFSET_TILES: float = 5.0
const CASTLE_COLUMN_SPACING_TILES: float = 3.1
const SHOP_STALL_RADIUS_TILES: float = 1.0

# --- Co-op (§9) ---
## Every descent multiplies monster and floor boss HP again, on top of the co-op rules.
const COOP_HP_MULT_PER_DESCENT: float = 2.0

# --- Layers (§6.6) ---
## The player's arrival point on the final layer, measured up from the bottom edge.
const FINAL_LAYER_SPAWN_INSET_TILES: float = 3.0
const PORTAL_RADIUS_TILES: float = 1.4
## How long a new portal ignores players, so the boss's drops can be collected first.
const PORTAL_ARM_SEC: float = 1.5
const LAYER_BANNER_SEC: float = 4.0

# --- Overworld terrain (§6.6, §6.12) ---
const RIVER_SPEED_MULT: float = 0.5
const RIVER_WIDTH_TILES: int = 3
const RIVER_RIPPLES_PER_TILE: int = 3
## How far rivers run from the map center, as a fraction of the map size.
const RIVER_MIN_OFFSET: float = 0.3
const RIVER_MAX_OFFSET: float = 0.42
## One tree or rock per this many tiles of map.
const TILES_PER_OBSTACLE: int = 26
const OBSTACLE_SIZE_TILES: float = 0.9
const OBSTACLE_SPACING_TILES: float = 4.0
const OBSTACLE_TREE_CHANCE: float = 0.7

# --- Nests (§6.4) ---
const NEST_HP: int = 70
const NEST_SPAWN_DELAY_SEC: float = 5.0
const NEST_BOSS_DELAY_SEC: float = 0.0
const NEST_RADIUS_TILES: float = 1.0
const FIRST_LAYER_NESTS: int = 2
## Nests on one layer stay at least this far apart, in tiles.
const NEST_MIN_SPACING_TILES: float = 16.0
## How far inside the map edge nests sit, in tiles.
const NEST_EDGE_INSET_TILES: float = 4.0
# TODO(design): per-nest alive cap, only here to keep the web build fast.
const NEST_MAX_ALIVE: int = 25
## Nests spawn this much faster per layer below the Overworld: 1×, 1.5×, 2×, 2.5×.
const SPAWN_RATE_STEP_PER_LAYER: float = 0.5

# --- Monsters (§6.8) ---
# TODO(design): melee attack cooldown isn't in the design doc.
const MONSTER_ATTACK_COOLDOWN_SEC: float = 1.0
## Monster speed depends on size: speed = player speed × min(MAX_RATIO, SIZE_K / radius_tiles).
## Smaller monsters are faster, but never as fast as the player.
const MONSTER_SIZE_SPEED_K: float = 0.3
const MONSTER_MAX_SPEED_RATIO: float = 0.9
## Undead slow spell: 0 damage, moves at half the speed of a normal spell (3.0 tiles/sec), slows player on hit.
const UNDEAD_SLOW_BOLT_SPEED_TILES: float = 3.0
const UNDEAD_SLOW_FIRE_INTERVAL_SEC: float = 3.5
const UNDEAD_SLOW_RANGE_TILES: float = 9.0
const UNDEAD_SLOW_SPEED_MULT: float = 0.5
const UNDEAD_SLOW_DURATION_SEC: float = 2.5

# --- Nest boss (§6.6) ---
const BOSS_HP: int = 480
const BOSS_HP_GROWTH_PER_LAYER: float = 1.5
const BOSS_AUG_SCROLL_DROP_MIN: int = 3
const BOSS_AUG_SCROLL_DROP_MAX: int = 5
## Bosses from nests bring this many of their monster every few seconds (§6.9).
const BOSS_ESCORT_COUNT: int = 3
const BOSS_ESCORT_INTERVAL_SEC: float = 5.0
## A boss stops calling escorts after this many in total.
const BOSS_ESCORT_MAX_TOTAL: int = 30
## How many pickups a guaranteed drop gives (§6.8).
const GUARANTEED_DROP_MIN: int = 1
const GUARANTEED_DROP_MAX: int = 3
const BOSS_SPAWN_PROTECTION_SEC: float = 5.0
const BOSS_SPAWN_DAMAGE_REDUCTION: float = 0.30
const BOSS_MELEE_DAMAGE: int = 5
const BOSS_BOLT_DAMAGE: int = 1
const BOSS_BOLT_SPEED_TILES: float = 1.0
const BOSS_RADIUS_TILES: float = 0.8
const BOSS_GOLD: int = 1000
# TODO(design): boss speed, fire rate and aim aren't in the design doc.
const BOSS_SPEED_MULT: float = 0.5
const BOSS_FIRE_INTERVAL_SEC: float = 2.0
const BOSS_FIRE_RANGE_TILES: float = 12.0

# --- Mega boss (§6.10) ---
## Per phase: the dragon revives to this much too.
const MEGA_BOSS_HP: int = 8000
const MEGA_BOSS_SHIELD_HP: float = 500.0
const MEGA_BOSS_BOLT_SPEED_TILES: float = 6.0
const MEGA_BOSS_RADIUS_TILES: float = 1.5
const HIDDEN_BOSS_HP_MULT: float = 2.0
## The Mega Boss keeps at most this many of each monster class alive.
const MEGA_BOSS_MINION_CAP: int = 10

# --- Cataclysms, the Mega Boss's invulnerable phases (§6.10) ---
const CATACLYSM_DURATION_SEC: float = 20.0
const METEOR_INTERVAL_SEC: float = 0.9
## Meteors per player in each volley, on top of the one aimed right at them.
const METEORS_PER_VOLLEY: int = 3
const METEOR_SCATTER_TILES: float = 7.0
const METEOR_FUSE_SEC: float = 1.6
const METEOR_RADIUS_TILES: float = 1.8
const METEOR_DAMAGE: int = 3
const SHOCKWAVE_INTERVAL_SEC: float = 2.6
const SHOCKWAVE_SPEED_TILES: float = 5.7
const SHOCKWAVE_MAX_RADIUS_TILES: float = 34.0
const SHOCKWAVE_GAP_DEG: float = 50.0
const SHOCKWAVE_DAMAGE: int = 3
const COLLAPSE_WARNING_SEC: float = 3.0
const COLLAPSE_SAFE_RADIUS_TILES: float = 5.0
const COLLAPSE_DRIFT_TILES: float = 9.0
const COLLAPSE_DRIFT_SPEED_TILES: float = 2.0
const COLLAPSE_TICK_SEC: float = 1.0
const COLLAPSE_DAMAGE: int = 2
const INFERNO_LINES: int = 8
const INFERNO_LINE_INTERVAL_SEC: float = 3.5

# --- Dragon, the Mega Boss's second phase (§6.10) ---
const BREATH_BEAMS: int = 3
const BREATH_TURN_SPEED: float = 0.45
const BREATH_LENGTH_TILES: float = 16.0
const BREATH_WIDTH_TILES: float = 1.0
const BREATH_WARNING_SEC: float = 2.5
const BREATH_DAMAGE: int = 3
const HATCHLING_HP: float = 500.0
const HATCHLING_SHIELD_HP: float = 300.0
const HATCHLING_SPAWN_COUNT: int = 3
const HATCHLING_SPAWN_INTERVAL_SEC: float = 5.0
const HATCHLING_RADIUS_TILES: float = 0.7
const HATCHLING_SPEED_TILES: float = 2.0
const HATCHLING_KEEP_AWAY_TILES: float = 4.0
const HATCHLING_FIRE_INTERVAL_SEC: float = 2.5
const HATCHLING_BOLT_DAMAGE: float = 1.0
const HATCHLING_BOLT_SPEED_TILES: float = 4.0
const HATCHLING_BOLT_RADIUS_TILES: float = 0.15
const HATCHLING_BOLT_RANGE_TILES: float = 12.0
const DRAGON_RADIUS_TILES: float = 2.0
## It circles the player at this distance, in tiles, so it can always be hit.
const DRAGON_ORBIT_TILES: float = 6.0
const DRAGON_ORBIT_SPEED: float = 0.4
const DRAGON_FIRE_INTERVAL_SEC: float = 5.0
const DRAGON_FIRE_WARNING_SEC: float = 3.0
const DRAGON_FIRE_BURN_SEC: float = 3.0
const DRAGON_FIRE_TICK_SEC: float = 1.0
const DRAGON_FIRE_WIDTH_TILES: float = 0.4
const DRAGON_FIRE_SHIELD_DAMAGE: int = 1
const DRAGON_FIRE_HP_DAMAGE: int = 3

# --- Abyss (§6.12) ---
const ABYSS_ARENA_RADIUS_FRACTION: float = 0.35
const ABYSS_CORRIDOR_HALF_WIDTH_TILES: float = 2.5
const CRYSTAL_SHATTER_SEC: float = 0.8
## How close a player must get to break the crystal open.
const CRYSTAL_TOUCH_RADIUS_TILES: float = 2.2
## The walk to the crystal is slower than the rest of the game.
const ABYSS_APPROACH_SPEED_MULT: float = 0.6
## How long the white flash takes to fill the screen after the final boss dies.
const VICTORY_FLASH_SEC: float = 1.2
## Shown under the Victory screen.
const CREDITS: Array[String] = [
	"Hukulshish",
	"Made with the Godot Engine",
	"Thank you for playing!",
]
## Artist - track, as supplied from Pixabay.
const MUSIC_CREDITS: Array[String] = [
	"Icsilviu - Fantasy Ambient Song",
	"The_Mountain - Fantasy Ambient",
	"DarkScores - Forest of Sirens",
	"leberch - Mystery",
	"NastelBom - Fantasy",
	"NastelBom - Dark Epic",
	"Ancient_Echoes - Dominion",
	"ONECinematicStudio - The Dragon's Breath",
	"Ancient_Echoes - The Unbidden One",
	"NickPanek - Wrath of Mars",
	"Cyberwave-Orchestra - Glorious Return",
	"libertybeats - Echoes of the End",
	"OpenMindAudio - Epic Fantasy Trailer",
]

# --- Endless Mode (§6.13) ---
const ENDLESS_MEGA_INTERVAL_SEC: float = 60.0
## The first Mega Boss has this multiple of its HP, and each one after adds the step.
const ENDLESS_MEGA_HP_BASE_MULT: float = 1.5
const ENDLESS_MEGA_HP_STEP: float = 0.5

# --- Castle (§5) ---
const CASTLE_SIZE_TILES: float = 4.0

# --- Gold mines (§6.8) ---
const GOLD_MINE_COUNT: int = 5
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
const LAYERS: Array = [
	preload("res://resources/layers/overworld.tres"),
	preload("res://resources/layers/underworld.tres"),
	preload("res://resources/layers/catacombs.tres"),
	preload("res://resources/layers/pandemonium.tres"),
	preload("res://resources/layers/abyss.tres"),
]
const MAP_SIZES: Array = [
	preload("res://resources/maps/small.tres"),
	preload("res://resources/maps/medium.tres"),
	preload("res://resources/maps/large.tres"),
]
const BASE_SPELL: SpellData = preload("res://resources/spells/base_spell.tres")
const ABYSSAL_CORRUPTION: SpellData = preload("res://resources/spells/abyssal_corruption.tres")


## True on phones and tablets, which have no cursor or keyboard.
func is_touch_device() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Fetched when needed rather than preloaded: projectile.gd refers to enemy classes, and a preload
## from any of them forms a loop that leaves this scene empty.
func projectile_scene() -> PackedScene:
	return load("res://scenes/spells/Projectile.tscn")


## A unique spell's position in the list guests and the host share, or -1 for none.
func unique_spell_index(spell: SpellData) -> int:
	if spell == null:
		return -1
	if spell == ABYSSAL_CORRUPTION:
		return LAYERS.size()
	for i in LAYERS.size():
		if LAYERS[i].unique_spell == spell:
			return i
	return -1


func unique_spell_at(index: int) -> SpellData:
	if index == LAYERS.size():
		return ABYSSAL_CORRUPTION
	return LAYERS[index].unique_spell if index >= 0 else null


## Converts tiles to pixels.
func tiles(amount: float) -> float:
	return amount * TILE_SIZE


## Base spell damage at a level (1..SPELL_MAX_LEVEL), before mods.
func spell_damage(level: int) -> int:
	var i: int = clampi(level, 1, SPELL_MAX_LEVEL) - 1
	return SPELL_DAMAGE_BY_LEVEL[i]


## Gold needed to go from `level` to `level + 1`.
func upgrade_cost(level: int) -> int:
	return SPELL_UPGRADE_COST_FACTOR * level * level


## Spell Scrolls needed to buy the next level of a mod that is currently at `level` (0-based).
## A level costs its own number: 1, 2, 3 … 20.
func mod_cost(level: int) -> int:
	return level + 1


func mod_max_level(id: String) -> int:
	return RANGE_MOD_MAX_LEVEL if id == "range" else MOD_MAX_LEVEL


## Max mana for a given `mana_pool` upgrade level (0..20):
## +1 per level from 10 up to 15 (levels 1..5), then +2 per level from 15 up to 45 (levels 6..20).
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


## Player max HP for a given `max_hp_level` (0..3): 5 → 6 → 7 → 10 (+1, +1, +3).
func player_max_hp_for_level(level: int) -> int:
	var idx: int = clampi(level, 0, PLAYER_MAX_HP_MAX_LEVEL)
	return PLAYER_MAX_HP_BY_LEVEL[idx]


## Gold cost for the next Max HP upgrade in the Gold Shop (200, 400, 800).
func gold_max_hp_cost(level: int) -> int:
	var idx: int = clampi(level, 0, GOLD_SHOP_MAX_HP_COSTS.size() - 1)
	return GOLD_SHOP_MAX_HP_COSTS[idx]


## Gold cost for the next Spell Scroll in the Gold Shop (100, 200, ..., 1000).
func gold_mod_part_cost(bought_so_far: int) -> int:
	return (bought_so_far + 1) * GOLD_SHOP_MOD_PART_BASE_COST


## Monster speed in tiles/sec from its size.
func monster_speed_tiles(radius_tiles: float) -> float:
	return PLAYER_SPEED_TILES * minf(MONSTER_MAX_SPEED_RATIO, MONSTER_SIZE_SPEED_K / radius_tiles)


## Applies a difficulty multiplier to a base HP, rounding up, minimum 1.
func scale_hp(base_hp: int, mult: float) -> int:
	return maxi(1, ceili(base_hp * mult))


# --- Sprite / Texture helpers ---
var _tex_cache: Dictionary = {}


## Loads and caches a Texture2D from `res://assets/...` (works both with imported resources and raw files in dev).
func get_tex(res_path: String) -> Texture2D:
	if _tex_cache.has(res_path):
		return _tex_cache[res_path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		tex = ResourceLoader.load(res_path) as Texture2D
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img: Image = Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_tex_cache[res_path] = tex
	return tex


## Draws `tex` centered at `pos` fitting inside `max_size` (preserving aspect ratio), with optional horizontal flip.
func draw_sprite_centered(
	canvas: CanvasItem,
	tex: Texture2D,
	pos: Vector2,
	max_size: Vector2,
	modulate_col: Color = Color.WHITE,
	flip_h: bool = false
) -> void:
	if tex == null:
		return
	var ts: Vector2 = tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var scale_f: float = minf(max_size.x / ts.x, max_size.y / ts.y)
	var draw_sz: Vector2 = ts * scale_f
	# In Godot 4, negative rect.size.x flips horizontally in-place within [rect.position.x, rect.position.x + draw_sz.x].
	var rect := Rect2(pos - draw_sz * 0.5, Vector2(-draw_sz.x if flip_h else draw_sz.x, draw_sz.y))
	canvas.draw_texture_rect(tex, rect, false, modulate_col)


## Draws a flat elliptical ground shadow directly beneath an entity's feet so it never looks like a separate target.
func draw_ground_shadow(
	canvas: CanvasItem,
	radius: float,
	y_offset: float,
	alpha: float = 0.32,
	tint: Color = Color.BLACK
) -> void:
	canvas.draw_set_transform(Vector2(0.0, y_offset), 0.0, Vector2(1.0, 0.42))
	canvas.draw_circle(Vector2.ZERO, radius * 0.88, Color(tint.r, tint.g, tint.b, alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Returns the local offset of the sapphire rhombus gem at the tip of the mage's staff.
func get_staff_gem_offset(radius: float, aim_dir: Vector2) -> Vector2:
	var dir: Vector2 = aim_dir.normalized() if aim_dir != Vector2.ZERO else Vector2.RIGHT
	var facing_sign: float = -1.0 if dir.x < -0.05 else 1.0
	var s: float = radius / 12.8
	var main_hand := Vector2(facing_sign * radius * 0.62, radius * 0.08)
	return main_hand + dir * (radius * 1.18 + 3.6 * s)


## Draws the mage's offhand small open magic tome/book and main-hand staff with a small sapphire rhombus gem tip.
func draw_mage_loadout(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	aim_dir: Vector2,
	bob: float = 0.0,
	spectral: bool = false,
	alpha: float = 1.0
) -> void:
	var dir: Vector2 = aim_dir.normalized() if aim_dir != Vector2.ZERO else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var facing_sign: float = -1.0 if dir.x < -0.05 else 1.0
	var s: float = radius / 12.8

	# 1. Offhand: Small Open Magic Tome / Book
	var b: Vector2 = center + Vector2(-facing_sign * radius * 0.64, radius * 0.14 + bob * 0.65)
	var aura_col := Color(0.55, 0.30, 1.0, 0.22 * alpha) if spectral else Color(0.18, 0.55, 1.0, 0.20 * alpha)
	var cover_col := Color(0.32, 0.14, 0.52, alpha) if spectral else Color(0.20, 0.14, 0.36, alpha)
	var trim_col := Color(0.82, 0.62, 1.0, alpha) if spectral else Color(0.90, 0.74, 0.28, alpha)
	var page_left := Color(0.88, 0.80, 1.0, alpha) if spectral else Color(0.96, 0.92, 0.80, alpha)
	var page_right := Color(0.80, 0.70, 0.96, alpha) if spectral else Color(0.89, 0.84, 0.71, alpha)
	var rune_col := Color(0.62, 0.28, 1.0, 0.92 * alpha) if spectral else Color(0.14, 0.50, 0.95, 0.92 * alpha)

	canvas.draw_circle(b, 5.2 * s, aura_col)
	# Leather cover with 1px dark outline
	var cover_out := PackedVector2Array([
		b + Vector2(-5.3 * s, -3.0 * s),
		b + Vector2(0.0, -1.9 * s),
		b + Vector2(5.3 * s, -3.0 * s),
		b + Vector2(5.3 * s, 3.4 * s),
		b + Vector2(0.0, 4.4 * s),
		b + Vector2(-5.3 * s, 3.4 * s),
	])
	canvas.draw_colored_polygon(cover_out, Color(0.07, 0.04, 0.10, 0.95 * alpha))
	var cover_pts := PackedVector2Array([
		b + Vector2(-4.6 * s, -2.4 * s),
		b + Vector2(0.0, -1.4 * s),
		b + Vector2(4.6 * s, -2.4 * s),
		b + Vector2(4.6 * s, 2.8 * s),
		b + Vector2(0.0, 3.8 * s),
		b + Vector2(-4.6 * s, 2.8 * s),
	])
	canvas.draw_colored_polygon(cover_pts, cover_col)
	# Open left & right parchment pages
	canvas.draw_colored_polygon(PackedVector2Array([
		b + Vector2(-3.8 * s, -1.9 * s),
		b + Vector2(-0.35 * s, -1.0 * s),
		b + Vector2(-0.35 * s, 3.0 * s),
		b + Vector2(-3.8 * s, 2.1 * s),
	]), page_left)
	canvas.draw_colored_polygon(PackedVector2Array([
		b + Vector2(0.35 * s, -1.0 * s),
		b + Vector2(3.8 * s, -1.9 * s),
		b + Vector2(3.8 * s, 2.1 * s),
		b + Vector2(0.35 * s, 3.0 * s),
	]), page_right)
	# Center spine & glowing arcane rune lines on the pages
	canvas.draw_line(b + Vector2(0.0, -1.3 * s), b + Vector2(0.0, 3.6 * s), trim_col, maxf(1.0, 1.1 * s))
	canvas.draw_line(b + Vector2(-3.1 * s, -0.5 * s), b + Vector2(-1.0 * s, 0.0), rune_col, maxf(1.0, 0.95 * s))
	canvas.draw_line(b + Vector2(-3.1 * s, 1.0 * s), b + Vector2(-1.0 * s, 1.5 * s), rune_col, maxf(1.0, 0.95 * s))
	canvas.draw_line(b + Vector2(1.0 * s, 0.0), b + Vector2(3.1 * s, -0.5 * s), rune_col, maxf(1.0, 0.95 * s))
	canvas.draw_line(b + Vector2(1.0 * s, 1.5 * s), b + Vector2(3.1 * s, 1.0 * s), rune_col, maxf(1.0, 0.95 * s))

	# 2. Main Hand: Staff with Small Sapphire Rhombus Gem at the Tip
	var main_hand: Vector2 = center + Vector2(facing_sign * radius * 0.62, radius * 0.08 + bob * 0.85)
	var staff_butt: Vector2 = main_hand - dir * (radius * 0.62)
	var staff_head: Vector2 = main_hand + dir * (radius * 1.18)
	var shaft_col := Color(0.38, 0.22, 0.54, alpha) if spectral else Color(0.42, 0.25, 0.13, alpha)

	# Dark pixel outline + sleek carved wooden shaft + gold ferrule & butt cap
	canvas.draw_line(staff_butt, staff_head, Color(0.07, 0.04, 0.10, 0.92 * alpha), 3.8 * s)
	canvas.draw_line(staff_butt, staff_head, shaft_col, 2.2 * s)
	canvas.draw_line(staff_butt, staff_butt + dir * (1.8 * s), trim_col, 2.6 * s)
	canvas.draw_line(staff_head - dir * (2.2 * s), staff_head + dir * (0.6 * s), trim_col, 3.2 * s)

	# Small Sapphire Rhombus Gem at the tip
	var gem_pos: Vector2 = staff_head + dir * (3.6 * s)
	var gem_glow := Color(0.58, 0.28, 1.0, 0.30 * alpha) if spectral else Color(0.10, 0.50, 1.0, 0.30 * alpha)
	var gem_body := Color(0.56, 0.28, 0.98, alpha) if spectral else Color(0.08, 0.42, 0.96, alpha)
	var gem_core := Color(0.90, 0.78, 1.0, alpha) if spectral else Color(0.68, 0.92, 1.0, alpha)

	canvas.draw_circle(gem_pos, 4.2 * s, gem_glow)
	# Outer dark border rhombus
	canvas.draw_colored_polygon(PackedVector2Array([
		gem_pos + dir * (3.9 * s),
		gem_pos + perp * (2.4 * s),
		gem_pos - dir * (3.7 * s),
		gem_pos - perp * (2.4 * s),
	]), Color(0.05, 0.08, 0.20, 0.95 * alpha))
	# Sapphire rhombus body
	canvas.draw_colored_polygon(PackedVector2Array([
		gem_pos + dir * (3.1 * s),
		gem_pos + perp * (1.75 * s),
		gem_pos - dir * (2.9 * s),
		gem_pos - perp * (1.75 * s),
	]), gem_body)
	# Bright inner sapphire facet
	canvas.draw_colored_polygon(PackedVector2Array([
		gem_pos + dir * (1.6 * s),
		gem_pos + perp * (0.85 * s),
		gem_pos - dir * (1.3 * s),
		gem_pos - perp * (0.85 * s),
	]), gem_core)


