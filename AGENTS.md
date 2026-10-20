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

1. **Main Menu:** `Start`, `Quit Game`
2. **Map Size:** `Small`, `Medium`, `Large`
3. **Difficulty:** `Easy`, `Medium`, `Hard`, `Extreme`
4. **Game:** the run starts. Show the Victory or Game Over screen at the end.

### Difficulty (monster HP multiplier)
| Difficulty | Monster HP |
|---|---|
| Easy | ×0.5 |
| Medium | ×1 |
| Hard | ×2 |
| Extreme | ×5 |

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
- **Victory:** all 4 nests destroyed **and** all nest bosses defeated.
- **Defeat:** the player dies. *(The castle is only a plot point. It has no HP and can't be destroyed.)*
- The castle is where you **upgrade the base spell** and **add new spells** (mods).

---

## 6. Mechanics

### 6.1 Player
| Stat | Value |
|---|---|
| Starting HP | 10 |
| Move speed | 1 tile/sec |
| Starting spell | Base spell, level 1: auto-aims at the nearest monster, 1 damage |

### 6.2 Spells
- Every player spell moves at **1 tile/sec** unless its definition says otherwise.
- **Base spell levels:** 1 (base) up to 9 (max). You upgrade it **at the castle** with gold.
- **Damage per level:** +2 per level until level 7, then +5 per level after that.

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| Damage | 1 | 3 | 5 | 7 | 9 | 11 | 13 | 18 | 23 |

> Assumption: level 7 is still a +2 step and levels 8–9 are +5. Confirm with the user (§9).

- **Upgrade cost:** grows exponentially with each level. **The level 1→2 cost and the growth rate haven't been decided yet** (§9). Keep the formula in data: `cost = base_cost * growth ^ (level - 1)`.

### 6.3 Spell Mods
- A spell mod **copies the base spell's damage at the moment you apply it**. That value is frozen; later base-spell upgrades don't change it.
- The mod becomes a **new spell that fires alongside** the base spell.
- Spell mods **only drop from nests**.
- Known mods:
  - **Magic Missile:** 2 tiles/sec, *(the rest of this line was cut off in the manuscript; see §9)*
  - *More TBD*

### 6.4 Nests
- There are **4 nests**, one hidden in each **corner** of the map.
- Each nest spawns its own monster type (suggested: one class per nest, i.e. Goblin / Undead / Ogre / Demon; confirm).
- Spawning starts **5 seconds** after the run begins.
- Nest HP: **30**
- When destroyed: **1 in 3 chance** to drop a spell mod.
- When destroyed: a **boss spawns 20 seconds later** (at the nest's spot unless the user says otherwise).
- Open: does a destroyed nest stop spawning? (Almost certainly yes.)

### 6.5 Monsters (all melee)
| Class | HP | Damage | Speed (× player) | Spawn interval | Gold drop |
|---|---|---|---|---|---|
| Goblin | 3 | 1 | 1.5× | every 5 s | 1 |
| Undead | 4 | 2 | 0.5× | every 8 s | 3 |
| Ogre | 10 | 1 | 0.5× | every 7 s | 4 |
| Demon | 7 | 2 | 1.0× | every 16 s | 5 |

- HP is multiplied by the difficulty multiplier (§3).
- Monsters chase the player.
- Open: the melee attack cooldown and the player's invulnerability frames after taking a hit aren't defined yet (§9).

### 6.6 Nest Bosses
| Stat | Value |
|---|---|
| HP | 20 |
| Melee damage | 5 |
| Ranged attack | Fires a 1-damage projectile at 1 tile/sec in a straight line |
| Spawn | 20 s after its nest is destroyed |

- Open: the boss's move speed, fire rate, aim (at the player or a fixed pattern), gold/mod drops, and whether difficulty scales it (§9).

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
