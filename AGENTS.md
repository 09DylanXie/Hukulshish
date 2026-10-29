# AGENTS.md — Hukulshish

Instructions and design reference for AI coding agents working on this project.
**This file is the source of truth for game design.** If code and this file disagree, ask the user. Don't guess.

---

## 1. Project Overview

| Item | Value |
|---|---|
| Title (working) | Hukulshish |
| Genre | 2D top-down auto-attack survival / base defense (in the style of Vampire Survivors) |
| Visual style | 2D, multi-color |
| Engine | **Godot 4.x** (GDScript) |
| Renderer | GL Compatibility (needed for the web export) |
| Target platform | **itch.io** HTML5/Web build, playable on desktop and mobile browsers |
| Players | Single player only (multiplayer may come later; don't build for it now) |
| Game modes | Normal (build this first), Infinite (later), TBD |
| Music / OST | TBD |

---

## 2. Directory Layout

```
hukulshish/
├── AGENTS.md              # This file
├── README.md              # Setup + pinned Godot version
├── CONTRIBUTING.md        # 2-person Git workflow (read first)
├── .gitignore / .gitattributes / .editorconfig
├── .github/               # PR template
├── project.godot          # Godot project config (shared — edit carefully)
├── assets/                # Raw art/audio (no logic)
│   ├── sprites/{player,monsters,bosses,spells,nests,ui}/
│   ├── tilesets/
│   ├── fonts/
│   └── audio/{music,sfx}/
├── scenes/                # .tscn files, grouped by feature
│   ├── main/              # Main.tscn (root/game flow)
│   ├── ui/                # MainMenu, MapSizeSelect, DifficultySelect, HUD, CastleMenu, GameOver, Victory
│   ├── player/            # Player.tscn
│   ├── monsters/          # Goblin, Undead, Ogre, Demon
│   ├── bosses/            # NestBoss.tscn
│   ├── nests/             # Nest.tscn
│   ├── spells/            # Projectile scenes (base spell, mods, boss bolt)
│   ├── castle/            # Castle.tscn (upgrade interaction)
│   └── world/             # Map scenes (small/medium/large)
├── scripts/               # .gd files, matching the scenes/ structure
│   └── autoload/          # Singletons: GameState, Config, etc.
├── resources/             # .tres data resources (stats live here, not hardcoded)
│   ├── monsters/          # MonsterStats per class
│   ├── spells/            # SpellData per spell/mod
│   ├── difficulty/        # Difficulty multipliers
│   └── maps/              # Map size definitions
├── docs/                  # Extra design notes
└── export/web/            # itch.io HTML5 export output (git-ignored)
```

### Conventions
- **Files:** `snake_case.gd`, `PascalCase.tscn`. **Classes:** `class_name PascalCase`.
- **Variables/functions:** `snake_case`. **Constants:** `UPPER_SNAKE_CASE`. **Signals:** past tense (`died`, `nest_destroyed`).
- Use static typing everywhere (`var hp: int = 10`, `func take_damage(amount: int) -> void`).
- **Keep balance numbers out of the code.** Put them in `Resource` files (`resources/`) or in the `Config` autoload so they can be tuned without code changes.
- Let systems talk through **signals**, not hard references to each other (e.g. a monster emits `died(gold_value)` and a listener gives the gold).
- Use **1 tile** as the base unit for distance and speed. Define `TILE_SIZE` once in `Config` (default **32 px**). Every speed is in tiles/sec × `TILE_SIZE`.

---

## 3. Game Flow / Menus

```
Main Menu ──► [Start] ──► Map Size Select ──► Difficulty Select ──► Game
          └─► [Quit Game] (on web, hide this or show a "thanks for playing" screen; get_tree().quit() does nothing in a browser)
```

1. **Main Menu:** `Start`, `Rules & Guide` (interactive tabbed guide with visual diagrams for new players), `Quit Game`
2. **Map Size:** `Small`, `Medium`, `Large`
3. **Difficulty:** `Easy`, `Medium`, `Hard`, `Extreme`, plus **Endless Mode** (either chosen directly or toggled on for any difficulty; when the Mega Boss dies, 4 new spawners appear and everything's HP goes up by `2×`).
4. **Game:** the run starts. Show the Victory or Game Over screen at the end.

### Difficulty (monster HP multiplier & 3-minute time scaling)
| Difficulty | Base Monster HP | After 3 Minutes (every 30s) |
|---|---|---|
| Easy | ×0.5 | No additional scaling |
| Medium | ×1 | `+5 HP` linearly every 30s |
| Hard | ×2 | `×1.2` exponentially every 30s |
| Extreme | ×5 | `×1.5` exponentially every 30s |

> Open: does the multiplier also apply to **nests and bosses**? Should HP be rounded up (e.g. Goblin 3 × 0.5 = 1.5 → 2)? See §9.

---

## 4. Controls

| Platform | Movement |
|---|---|
| Desktop | `W` `A` `S` `D` (add them as Input Map actions: `move_up`, `move_down`, `move_left`, `move_right`) |
| Mobile (browser) | On-screen virtual joystick. **Only show it on touch devices** (`DisplayServer.is_touchscreen_available()` or `OS.has_feature("web_android") / ("web_ios")`) |

- Attacking is **automatic** (it aims for you). There is no attack button.
- The player needs a way to **interact with the castle** (e.g. walk into its area to open the upgrade menu). That keeps it mobile-friendly.

---

## 5. Story

- The player is a mage named **Hukulshish**.
- The player spawns in the **center of a preset map**, inside a **kingdom castle**.
- Goal: defend the castle from monsters.
- **Victory:** all 4 nests destroyed **and** the Mega Boss defeated.
- **Defeat:** the player dies. *(The castle is only a plot point. It has no HP and can't be destroyed.)*
- Entering the castle **heals the player up to 3 HP** (never above 3 HP) and opens the upgrade menu for **base spell levels**, **spell mods**, **augmentations**, **personal shop**, and **gold shop**.

---

## 6. Mechanics

### 6.1 Player
| Stat | Value |
|---|---|
| Starting HP | 5 (upgradable in the Gold Shop to `6 → 7 → 10` Max HP via `+1`, `+1`, `+3` without instant healing) |
| Max Shield | 5 (absorbs damage before HP) |
| Starting Mana | 10 max (regenerates at 1.0/sec base) |
| Move speed | 3.0 tiles/sec |
| Weapon / Cursor | Holds an arcane wand/staff in the main hand and a floating magic catalyst in the offhand; cursor is a crosshair while in game |
| Starting spell | Base spell, level 1: left-click to shoot toward cursor (or auto-aim once unlocked for 1000 gold), 1 damage, fires at 2.0 shots/sec, costs 2 mana per cast |

### 6.2 Spells & Mana
- Every player spell moves at **2× player speed (6.0 tiles/sec)** unless modified (e.g., 5× speed Sniper shot).
- **Fire Rate & Mana Consumption:** player spells fire **2× faster** (`2.0/sec` base for Base Spell). Casting the **Base Spell** costs **2 mana**; casting each **Boss Spell** costs **3 mana** (+1 mana per cast across all spells).
- **Base spell levels:** 1 (base) up to 9 (max). You upgrade it **at the castle** with gold.
- **Damage per level:** +2 per level until level 7, then +5 per level after that.

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| Damage | 1 | 3 | 5 | 7 | 9 | 11 | 13 | 18 | 23 |

> Assumption: level 7 is still a +2 step and levels 8–9 are +5. Confirm with the user (§9).

- **Upgrade cost:** grows exponentially with each level (`cost = base_cost * growth ^ (level - 1)`).

### 6.3 Spell Mods ("Spell Scrolls"), Augmentations, Personal Shop, Gold Shop & Boss Spells
- **Spell Scrolls (formerly Mod Parts):** killing any monster has a **1 in 7 chance** (scaled by Luck) to drop a Spell Scroll pickup.
- **Spell Mods (at the castle):** Spell Scrolls can be spent on 4 independent upgrades for the base spell:
  - **Damage:** `+0.1×` (+10%) damage multiplier per level.
  - **Mana Regen** (replaces Fire Rate): starts at `1.0/sec` and increases by **`+0.5/sec`** each upgrade.
  - **Mana Pool** (replaces Spell Speed): increases max mana from `10` by **`+1` per level until `15`** (levels 1–5), then by **`+2` per level until `29`** (levels 6–12), maxing out at a mana bar of **29**.
  - **Range:** `+0.1×` (+10%) range multiplier per level.
- **Spell Mod cost:** costs `+1` Spell Scroll per upgrade for the first 4 upgrades (`1, 2, 3, 4`), then grows exponentially (`8, 16, 32, …`).
- **Augmentations & Augmentation Scrolls (at the bottom of the Spell Mod menu):**
  - **Augmentation Scrolls** drop **only from Demons** with a **1 in 5 chance** (scaled by Luck).
  - Each of the 3 Augmentations can be upgraded a maximum of **3 times**, costing **1**, then **2**, then **3** Augmentation Scrolls:
    1. **Split Spell:** splits the player's spell into **2** projectiles upon contact with an enemy, separated by a **45°** angle from the point of splitting (**Homing does not work on Split Shots**), with each split dealing **1/2** the damage of the parent projectile. Upgrading allows each split projectile to **re-split into 2 again** when it hits another enemy: up to **1** split (Lv 1), **2** sequential splits (Lv 2), or **3** sequential splits (Lv 3). **Lv 3 Unique Ability:** chains lightning across its hits so the enemy hit is connected with another enemy and both get zapped alongside each other for the same damage as the split shot.
    2. **Bombspell:** creates a medium-sized fire explosion (`2.09` tiles radius, 5% smaller) upon hitting a target that lasts **3 seconds** and deals **3 dmg/sec** (Lv 1), **5 dmg/sec** (Lv 2), or **7 dmg/sec** (Lv 3) (+2 dmg/sec per upgrade). Normally applies on final split spells (not initial split impact when Split Spell is active), and **1 tick of fire damage breaks a Demon's bubble shield**. **Lv 3 Unique Ability:** explodes on **every hit** regardless of whether the spell splits or not, **and** explodes when the spell runs out of range.
    3. **Sniper:** upon initial player spell contact with an enemy, fires a super-accurate **5× speed** shot that directly homes to the nearest **monster or boss (never targets nests)** and deals **2×** (Lv 1), **3×** (Lv 2), or **4×** (Lv 3) damage (+1× per upgrade). Does not repeat, and sniper shot count does not change with split upgrades (only initial first impact of player spell on an enemy). **Lv 3 Unique Ability:** the sniper shell explodes with the Bombspell explosion augmentation upon impact.
- **Personal Shop & Enhancers (Goblin & Undead Drops):**
  - **Enhancers** drop from **Goblins and Undead** with a **1 in 4 chance** (scaled by Luck).
  - All 6 Personal Shop upgrades max out at **Level 3** and cost **3** Enhancers for the 1st upgrade, **5** for the 2nd, and **9** for the 3rd:
    1. **Luck:** increases drop rate by **+20% per upgrade** (non-cumulative: `+20%`, `+40%`, `+60%`).
    2. **Movement Speed:** increases player movement speed by **+5% per upgrade** (non-cumulative: `+5%`, `+10%`, `+15%`).
    3. **Health Regen:** regenerates **+1 HP / 10 secs per upgrade** (`+1`, `+2`, `+3` HP every 10 seconds).
    4. **Capacity:** increases Gold Mine capacity by **+1/3 per upgrade** (non-cumulative: `+1/3`, `+2/3`, `+3/3`).
    5. **Rate:** increases Gold Mine gold generation rate by **+15% per upgrade** (non-cumulative: `+15%`, `+30%`, `+45%`).
    6. **Income Multiplier:** increases gold received from **monsters and bosses only** by **+50% per upgrade** (non-cumulative: `+50%`, `+100%`, `+150%`).
- **Gold Shop (at the castle):**
  - **Max HP Upgrade:** increases Max HP from `5 → 6 → 7 → 10` (`+1` for 1st and 2nd, `+3` on the final 3rd upgrade; does not instantly heal the player).
  - **Spell Scroll:** `100` gold for the 1st, then `+100` gold for each additional scroll up to 10 (`100, 200, …, 1000`).
  - **Magic Shield (`200` gold):** adds 1 shield item to the bottom circular hotbar; using it adds `+1` shield point (up to the 5-shield cap).
  - **3 HP Healing Potion (`100` gold):** adds 1 healing potion to the bottom circular hotbar; using it heals `+3 HP` (30 s effect timer).
  - **2× Damage Boost Potion (`100` gold):** adds 1 damage potion to the bottom circular hotbar; using it grants `2×` spell damage for **30 seconds**.
  - **Magnet (`300` gold):** automatically pulls dropped Spell Scrolls, Augmentation Scrolls, Enhancers, and Boss Spell pickups on the map toward the player.
  - **Auto Gold Collector (`500` gold):** automatically collects stored gold from all 3 Gold Mines every **30 seconds**.
  - **Auto-Shooting Unlock (`1000` gold):** unlocks automatic targeting and firing at **1/2 of the spell's fire rate** so players can still manually fire; press **`E`** to toggle auto-fire on/off once unlocked.
  - **Homing Unlock (`1500` gold):** makes player spells (excluding Split Shots) home toward the closest enemy; press **`F`** to toggle homing on/off once unlocked.
  - **Doppelganger (`5000` gold):** spawns a companion that copies the player's current abilities at purchase time, follows the player around until it dies, has a max HP of **5**, and can never have a shield.
- **Boss & Mega Boss Spells:**
  - **Nest Boss Spells (1/3 drop):** costs **3 mana** per cast and cannot be upgraded once acquired (stats are frozen on pickup). First boss spell copies the base spell's stats, **doubles its damage**, and **reduces fire rate by 1/3** (`× 2/3`); subsequent boss spells add the damage of all existing player spells together without reducing fire rate by 1/3 again.
  - **Mega Boss Spell (guaranteed 1/1 drop in Endless Mode):** every time the Mega Boss is defeated in Endless Mode, it drops a guaranteed bright-red Mega Boss Spell (`Color(1.0, 0.15, 0.15)`) that **combines all current spells together and multiplies damage by 1.5×**, and **copies the base spell's augments and uses them**.

### 6.4 Nests
- There are **4 nests**, one hidden in each **corner** of the map.
- Each nest spawns its own monster type (Goblin / Undead / Ogre / Demon) directly from its center hole.
- Spawning starts **5 seconds** after the run begins.
- Nest HP: **70** (damaged by player spells via swept-segment hit detection).
- When destroyed: a **nest boss spawns immediately** at the nest's spot.
- Once **all 4 nests are destroyed**, the **Mega Boss** spawns.

### 6.5 Monsters (all melee)
| Class | HP | Damage | Radius (tiles) | Speed (from size) | Spawn interval | Gold drop | Special |
|---|---|---|---|---|---|---|---|
| Goblin | 3 | 1 | 0.35 | ~2.57 tiles/s | every 5 s | 1 | 1/4 chance to drop an Enhancer |
| Undead | 4 | 2 | 0.40 | ~2.25 tiles/s | every 8 s | 3 | Fires a white 0-damage slow spell at half normal spell speed (3.0 tiles/s); 1/4 chance to drop an Enhancer |
| Demon | 7 | 2 | 0.45 | ~2.00 tiles/s | every 16 s | 5 | Bubble shield (breaks after 1 spell hit or 1 Bombspell fire tick); 1/5 chance to drop an Augmentation Scroll |
| Ogre | 10 | 1 | 0.60 | ~1.50 tiles/s | every 7 s | 4 | — |

- Monster speed varies inversely with theoretical size (`PLAYER_SPEED_TILES * min(0.9, 0.3 / radius_tiles)`), and is never faster than the player.
- HP is multiplied by the difficulty multiplier and scales over time after 3 minutes (§3).
- Monsters chase the player around maze walls and have a **1 in 7 chance** to drop a Spell Scroll on death (Demons also roll a **1 in 5 chance** to drop an Augmentation Scroll).

### 6.6 Nest Bosses
| Stat | Value |
|---|---|
| HP | 80 (increased 4× from 20) |
| Melee damage | 5 |
| Ranged attack | Fires a 1-damage projectile at 1 tile/sec in a straight line |
| Spawn | Immediately after its nest is destroyed |
| Drops | **1000 gold** + **1 in 3 chance** to drop a new Boss Spell |

### 6.7 Mega Boss
- Spawns once all 4 nests are destroyed.
- **HP:** 2000 (increased 2× from 1000; same melee/ranged damage and movement speed stats as a Nest Boss).
- **Spell Speed:** Fires projectiles at the **same speed as the player's base spell (`6.0` tiles/sec)**.
- **Regenerating Shield:** Starts with a **100 HP shield** that **regenerates to 100 HP after each 1/4 of its max HP is lost** (at 75%, 50%, and 25% HP).
- **Spawn Rates (2×):** Spawns a **Nest Boss every 25 seconds** (2× rate from 50 s) and spawns **normal monsters at 2× their normal rate**.
- **Defeating the Mega Boss** ends the game in Victory in Normal mode, or in **Endless Mode** spawns **4 new spawners** and increases **everything's HP by 2×**.

### 6.8 Gold Mines
- **3 gold mines** spawn in random regions of the map each run.
- Each mine produces **7.5 gold/sec** (reduced by 1/4 from 10), capped at **333 gold** (reduced by 1/3 from 500).
- Walk over a gold mine to collect its stored gold (or unlock the **Auto Gold Collector** in the Gold Shop for 500 gold to auto-collect all mines every 30 seconds).

### 6.9 Random Maze Walls
- Every new run generates a **spacious random maze** of walls across the outer map, starting **2/3 of the way in from the edge toward the castle** (leaving the inner 1/3 around the castle open).

---

## 7. Technical Guidance

### Suggested autoloads (`scripts/autoload/`)
- `Config`: constants (TILE_SIZE, base stats) and loaders for the resource files.
- `GameState`: the current run's settings (map size, difficulty), gold, spell level, owned mods, nests left, bosses left. Emits `victory` / `defeat`.
- `SceneRouter` (optional): handles menu → game → end-screen transitions.

### Suggested resources
- `MonsterStats` (`hp`, `damage`, `speed_mult`, `spawn_interval`, `gold`, `scene`)
- `SpellData` (`name`, `speed_tiles`, `damage`, `fire_rate`, `projectile_scene`)
- `DifficultyData` (`name`, `hp_mult`)
- `MapSizeData` (`name`, `size_in_tiles`, `scene`)

### itch.io / Web export
- Export with the **Web** preset into `export/web/`. Zip the folder contents with `index.html` at the zip root, then upload it to itch.io as an HTML game.
- On itch.io, turn on **SharedArrayBuffer support** if threads are enabled. Otherwise export **without threads** (easiest for Godot 4.3+).
- Test on a mobile browser for touch input and performance.
- Keep the number of active nodes reasonable. Use object pooling for projectiles and monsters if performance drops.

### Collaboration rules (2 humans + agents, GitHub)
Full workflow is in [`CONTRIBUTING.md`](CONTRIBUTING.md). Agents MUST follow these:
- **Never commit to `main`.** Work on a `feature/*` or `fix/*` branch; never force-push shared branches.
- **Never edit a `.tscn` the user hasn't said they own** in this task. Prefer putting logic in `.gd` files and data in `.tres` files — they merge cleanly; scenes don't.
- **Don't touch `project.godot`** (Input Map, autoloads, settings) unless the task requires it — and call it out explicitly in your summary, since it affects the other developer.
- **Never hand-write or change `uid://` values** in `.tscn`/`.tres`, and never delete `.import` / `.uid` files. Let Godot generate them.
- **Rename/move files only via Godot** (or update every reference). Don't rename assets with spaces or capitals — use `snake_case`.
- Don't change the pinned Godot version, `.gitignore`, `.gitattributes`, or `.editorconfig` without asking.
- GDScript uses **tabs** (see `.editorconfig`), LF line endings.

### Agent rules
- Build **Normal mode first**. Leave Infinite mode and later modes alone until the user asks for them.
- Don't invent balance numbers that aren't in this file. Use a placeholder in a resource file, mark it with a `# TODO(design)` comment, and add it to §9.
- After changing design-relevant code, update this file if the user approved the change.
- Keep each feature in its own scene + script pair so pieces can be tested in isolation (F6 in Godot).

---

## 8. Milestones (suggested order)

1. Project setup: Input Map, autoloads, `Config`, Web export preset
2. Main menu → map size → difficulty flow
3. Player movement (WASD + mobile joystick) + camera
4. Base spell with auto-aim + projectile
5. One monster type + health/damage + gold drop
6. Nest spawner (all 4 types), difficulty HP scaling
7. Castle upgrade menu (spell levels 1–9)
8. Nest destruction → spell mod drop → boss spawn
9. Win/lose conditions + end screens
10. Map sizes (small/medium/large), polish, itch.io build

---

## 9. Open Design Questions (ask the user before implementing these)

1. **Spell upgrade cost:** what does level 1→2 cost, and how fast does it grow? (That line was cut off in the manuscript.)
2. **Spell Mods list:** the Magic Missile entry was cut off ("2 tiles/sec, 3…"). What are its full stats, and what other mods exist?
3. **Damage at level 7:** is reaching level 7 a +2 or +5 step? (Assumed +2, giving 13/18/23.)
4. **Difficulty scope:** does the HP multiplier also apply to nests and bosses? How should fractional HP be rounded?
5. **Map sizes:** how many tiles across is Small, Medium, and Large?
6. **Fire rates:** how often does the base spell fire? Do mods fire at the same rate? What's the boss's fire rate?
7. **Melee:** what's the monster attack cooldown, and does the player get invulnerability frames after a hit?
8. **Bosses:** what are their speed, aim behavior, and drops?
9. **Nest-to-monster mapping:** does each nest spawn one class, or a mix?
10. **Castle interaction:** walk into it, or press a key/button?
11. **"Add new spells" at the castle:** is that only for applying dropped mods, or can players buy new spells there too?
12. **Infinite mode rules:** TBD.
13. **OST / art direction:** TBD.
