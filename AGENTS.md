# AGENTS.md — Hukulshish

Instructions and design reference for AI coding agents working on this project.
**This file is the source of truth for game design.** If code and this file disagree, ask the user. Don't guess.

> **Status:** the five-layer redesign is built, and co-op works over LAN. Co-op over WebRTC (browsers)
> is written but has not been tested end to end. All balance numbers are first passes, to be tuned by playtest.

---

## 1. Project Overview

| Item | Value |
|---|---|
| Title (working) | Hukulshish |
| Genre | 2D top-down action dungeon descent: fight down five layers, each harder than the last |
| Visual style | 2D, multi-color pixel art, with a distinct look for every layer |
| Engine | **Godot 4.x** (GDScript) |
| Renderer | GL Compatibility (needed for the web export) |
| Target platform | **itch.io** HTML5/Web build for desktop browsers |
| Players | Single player, plus co-op for 2–3 players over LAN or WebRTC |
| Game modes | Normal descent (build this first), Endless (§6.13) |
| Music / OST | Pixabay tracks in `assets/audio/music/`, credited on the end screen. Sound effects are generated (`docs/AUDIO.md`). |

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
│   ├── castle/            # Castle.tscn (overworld landmark)
│   └── world/             # Map scenes (small/medium/large)
├── scripts/               # .gd files, matching the scenes/ structure
│   └── autoload/          # Singletons: GameState, Config, etc.
├── resources/             # .tres data resources (stats live here, not hardcoded)
│   ├── monsters/          # MonsterStats per class
│   ├── spells/            # SpellData per spell/mod
│   ├── difficulty/        # Difficulty multipliers
│   └── maps/              # Map size definitions
├── docs/                  # Extra design notes (AUDIO.md covers sound effects)
├── tools/                 # generate_sfx.py and generate_art.py create the generated assets
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
Main Menu ──► [Start] ──► Map Size Select ──► Difficulty Select ──► Overworld
          └─► [Quit Game] (on web, hide this or show a "thanks for playing" screen; get_tree().quit() does nothing in a browser)

Overworld ──portal──► Underworld ──portal──► Catacombs ──portal──► Pandemonium ──portal──► Abyss
                                                                                             │
                                  white flash ──► End Screen ──► Credits ◄── Dragon defeated ┘
                                  (Endless on: return to the Overworld instead, §6.13)
```

1. **Main Menu:** `Start`, `Rules & Guide` (interactive tabbed guide with visual diagrams for new players), `Quit Game`
2. **Map Size:** `Small` (40 tiles), `Medium` (60), `Large` (80). The size applies to every layer.
3. **Difficulty:** `Easy`, `Medium`, `Hard`, `Extreme`, plus **Endless Mode** (toggled on for any difficulty) and **Sandbox Mode** (infinite resources).
4. **Game:** the run starts on the Overworld and continues through the layers. Show Game Over on death.

### Difficulty and HP scaling
HP no longer grows with time. It grows each time the player descends, and the growth **compounds**.
`depth` is 0 on the Overworld and 4 in the Abyss.

| Difficulty | Base monster HP | Growth per descent | Total at Abyss (`depth` 4) |
|---|---|---|---|
| Easy | ×0.5 | ×1.25 | ×1.22 |
| Medium | ×1 | ×1.5 | ×5.06 |
| Hard | ×2 | ×2 | ×32 |
| Extreme | ×5 | ×3 | ×405 |

| Target | HP |
|---|---|
| Monsters | `base HP × difficulty base × growth ^ depth` |
| Nests | Same formula as monsters, from a base of 70 |
| Floor bosses | `480 × 1.5 ^ depth` on every difficulty: 480, 720, 1080, 1620 |
| Mega Boss | 8000 per phase, unaffected by difficulty or depth |

- Round HP **up** to a whole number.
- Co-op HP is in §9.

---

## 4. Controls

- The pause menu offers **SFX volume**, **Music volume** and **Screen shake** sliders from 0–100%.
  At 0%, that sound is muted or camera shake is disabled. All three preferences
  apply immediately, are saved locally, and persist across runs and relaunches.

| Platform | Movement |
|---|---|
| Desktop | `W` `A` `S` `D` (add them as Input Map actions: `move_up`, `move_down`, `move_left`, `move_right`) |

| Input | Action |
|---|---|
| Left click | Fire the selected spell toward the cursor |
| `1` `2` `3` `4` `5` `7` | Select a spell for left click: Base, Water, Earth, Death, Fireball, Abyssal Corruption. Spells not yet found are ignored. |
| `E` | Hold to fire every spell at once. **Undocumented on purpose:** keep it out of the Rules & Guide, the HUD and the README. |
| `F` | Toggle homing, once bought (§6.3) |
| `Z` `X` `C` `V` / click | Use a hotbar item |

- **Touch devices:** a joystick isn't planned, so phones can't move the player. `F` has an on-screen button, but nothing else is built for touch.
- Walk into a shop stall to open its menu, and into a portal to descend. Neither needs a button.

---

## 5. Story

- The player is a mage named **Hukulshish**.
- The run begins in the **center of the Overworld**, inside a **kingdom castle**. The castle is a landmark with no HP.
- Goal: descend through all five layers and defeat the Mega Boss.
- **Victory:** the Mega Boss's dragon form is defeated. The game ends with a white flash, then the end screen and credits.
- **Defeat:** the player dies in single player; all players are downed in co-op.

---

## 6. Mechanics

### 6.1 Player
| Stat | Value |
|---|---|
| Starting HP | 7 (upgradable in the Gold Shop to `8 → 9 → 12` Max HP via `+1`, `+1`, `+3` without instant healing) |
| Max Shield | 5 (absorbs damage before HP) |
| Starting Mana | 10 max (regenerates at 1.0/sec base) |
| Move speed | 3.0 tiles/sec |
| Weapon / Cursor | Holds an arcane wand/staff in the main hand and a floating magic catalyst in the offhand; cursor is a crosshair while in game |
| Starting spell | Base spell, level 1: 1 damage, fires at 2.0 shots/sec, costs 2 mana per cast, 10 tiles range |

### 6.2 Base Spell & Mana
- Every player spell moves at **2× player speed (6.0 tiles/sec)** unless modified (e.g., 5× speed Sniper shot, 1/2 speed Abyssal Corruption).
- Casting the **Base Spell** costs **2 mana**. Each **unique spell** costs **1 mana** when it fires alongside it.
- **Base spell levels:** 1 up to **17** (max). Bought at the Spell stall with gold.
- **Damage per level:** +2 per level until level 7, then +5 per level after that.

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Damage | 1 | 3 | 5 | 7 | 9 | 11 | 13 | 18 | 23 | 28 | 33 | 38 | 43 | 48 | 53 | 58 | 63 |

- **Upgrade cost:** going from level `L` to `L + 1` costs `25 × L²` gold: 25 for the first upgrade, 6,400 for the last, and 37,400 in total. All 5 mines earn 2,250 gold/min with the Auto Gold Collector, so about 25 minutes of play pays for the base spell and most of the Gold Shop, but not everything. Tune by playtest.

### 6.3 Shops
There is **no menu in the castle**. Each shop is a row of **5 stalls**, and each stall opens one part of the old castle menu:

| Stall | Sells | Paid with |
|---|---|---|
| Spell | Base spell levels | Gold |
| Spell Mods | Damage, Mana Regen, Mana Pool, Range | Spell Scrolls |
| Augmentations | Split Spell, Bombspell, Sniper | Augmentation Scrolls |
| Personal | Luck, Movement Speed, Health Regen, Capacity, Rate, Income Multiplier | Enhancers |
| Gold | Everything in the Gold Shop list below | Gold |

- **Placement:** on the Overworld, the row runs along the **left** of the castle. On the Underworld, Catacombs and Pandemonium, the same row is generated next to the player's spawn point.
- The **Abyss has no shop**, so the Pandemonium shop is the last chance to buy anything.
- **Healing:** entering a stall heals the player up to **75% of max HP**. It never lowers HP.

**Spell Mods** are capped at level 20, except Range. A level costs its own number in Spell Scrolls (level 1 costs 1, level 20 costs 20). Each mod to 20 totals 210 scrolls.

| Mod | Per level | At max |
|---|---|---|
| Damage | `+0.1×` | 3.0× at level 20 |
| Mana Regen | `+0.5/sec`, from 1.0/sec | 11/sec at level 20 |
| Mana Pool | `+1` for levels 1–5, then `+2` for levels 6–20, from 10 | 45 at level 20 |
| Range | `+0.5×` | 5× at level 8 (36 scrolls in total) |

**Augmentations:** each of the 3 can be upgraded **3 times**, costing **1**, then **2**, then **3** Augmentation Scrolls. Augmentations apply to the base spell only.

1. **Split Spell:** splits the player's spell into **2** projectiles upon contact with an enemy, separated by a **45°** angle from the point of splitting (**Homing does not work on Split Shots**), with each split dealing **1/2** the damage of the parent projectile. Upgrading allows each split projectile to **re-split into 2 again** when it hits another enemy: up to **1** split (Lv 1), **2** sequential splits (Lv 2), or **3** sequential splits (Lv 3). **Lv 3 Unique Ability:** electricity bounces between sibling split spells as they travel, while they are within 6 tiles of each other. Any monster or boss it crosses is zapped once by that arc for **1/2** the split's damage and stunned (bosses are immune to stun).
2. **Bombspell:** creates a medium-sized fire explosion (`2.09` tiles radius) upon hitting a target that lasts **3 seconds** and deals **3 dmg/sec** (Lv 1), **5 dmg/sec** (Lv 2), or **7 dmg/sec** (Lv 3). Applies on the **first impact only**, and **1 tick of fire damage breaks a Demon's bubble shield**. **Lv 3 Unique Ability:** explodes on **every hit**, including split hits, **and** explodes when the spell runs out of range.
3. **Sniper:** upon initial player spell contact with an enemy, fires a super-accurate **5× speed** shot that directly homes to the nearest **monster or boss (never targets nests)** and deals **2×** (Lv 1), **3×** (Lv 2), or **4×** (Lv 3) damage. Does not repeat, and sniper shot count does not change with split upgrades. **Lv 3 Unique Ability:** the sniper shell explodes with the Bombspell explosion upon impact.

**Personal upgrades** max out at **Level 3** and cost **3**, **5**, then **9** Enhancers:

1. **Luck:** multiplies the **number** of items in a drop. It does not change drop chance. Levels 0–3 give `×1, ×1, ×2, ×3`, so level 1 is a long-term investment. Luck does not affect Demon drops or boss Augmentation Scrolls.
2. **Movement Speed:** `+10%`, `+20%`, `+30%`.
3. **Health Regen:** `+1`, `+2`, `+3` HP every 10 seconds.
4. **Capacity:** Gold Mine capacity `+1/3`, `+2/3`, `+3/3`.
5. **Rate:** Gold Mine generation `+15%`, `+30%`, `+45%`.
6. **Income Multiplier:** gold from **monsters and bosses only** `+50%`, `+100%`, `+150%`.

**Gold Shop:**

- **Max HP Upgrade:** Max HP `7 → 8 → 9 → 12`. Does not instantly heal the player.
- **Spell Scroll:** `100` gold for the 1st, then `+100` gold for each additional scroll up to 10 (`100, 200, …, 1000`).
- **Magic Shield (`200` gold):** adds 1 shield item to the hotbar; using it adds `+1` shield point (up to the 5-shield cap).
- **3 HP Healing Potion (`100` gold):** adds 1 potion to the hotbar; using it heals `+3 HP` instantly.
- **2× Damage Boost Potion (`100` gold):** adds 1 potion to the hotbar; using it grants `2×` spell damage for **30 seconds**.
- **Magnet (`300` gold):** pulls dropped Spell Scrolls, Augmentation Scrolls and Enhancers toward the player. It does not pull unique spells or the hidden spell, which are meant to be found.
- **Shoot Through Walls (`500` gold):** player spells pass through walls.
- **Auto Gold Collector (`1000` gold):** collects stored gold from all 5 Gold Mines every **15 seconds**, from any layer (§6.11).
- **Homing Unlock (`1500` gold):** player spells (excluding Split Shots and Abyssal Corruption) home toward the closest mob within a **45° cone** of the direction they were fired. Mobs outside the cone are ignored. Press **`F`** to toggle.
- **Doppelganger (`5000` gold):** adds 1 item to the hotbar. Using it summons a companion that copies the player's abilities at that moment, follows the player until it dies, and fires the same spell at the point the player aimed at whenever they fire. It has a max HP of **5** and can never have a shield. Only one can be out at a time.
- **Nothing (`10000` gold):** the listing is titled exactly `Nothing`, with no description, and buying it gives no message or hint. It is the key that makes the hidden spell appear in the Abyss (§6.5).

### 6.4 Unique Spells
Unique spells replace Boss Spells. Bosses never drop them. One is **hidden on each of the first four layers**, at a random reachable spot anywhere on the map except close to the center.

| Layer | Spell | Damage (frozen at pickup) | Effect on hit |
|---|---|---|---|
| Overworld | Water | Base spell ×1 | Slows the mob by 20% for 3 seconds |
| Underworld | Earth | Base spell ×2 | Stuns the mob for 1 second |
| Catacombs | Death | Base spell ×3 | Poison: the mob loses 3 HP/sec for 3 seconds |
| Pandemonium | Fireball | Base spell ×4 | Explodes for the same damage across the Bombspell's area (`2.09` tiles radius) |

- Each one copies the base spell's stats at pickup and can't be upgraded afterwards. Multipliers apply to the base spell only, so unique spells never stack on each other.
- They are selected with the number keys (§4) and cost **1 mana** each.
- They are **not augmented**.
- They home if Homing is unlocked and on.
- They use the base spell's animation, colored to match their element.
- **Status effects:** a repeat hit refreshes slow or poison instead of stacking it. Slow and poison work on all bosses.
- **Stun:** bosses are immune. A stunned monster can't be stunned again for 2 seconds after it recovers. Without this, Earth's fire rate would freeze monsters permanently.

### 6.5 Hidden Spell: Abyssal Corruption
- Appears only if `Nothing` was bought, at the **top of the Abyss map**, once the crystal breaks. There are no hints.
- Selected with `7` and fired at 1 mana, like a unique spell.
- Moves at **1/2 the speed** of other spells (3.0 tiles/sec). It never homes, and it has no augments or effects.
- **One-shots anything** except the Mega Boss and the hidden boss, including nests and floor bosses.
- Against the **Mega Boss in either phase** and the **hidden boss**, it deals the combined damage of all the player's spells per hit.
- Replaces the old Mega Boss Spell, which is removed.

### 6.6 Layers
| # | Layer | Monsters | Floor | Terrain | Rule |
|---|---|---|---|---|---|
| 1 | **Overworld** | Goblins | Vibrant green grass | No walls. Trees, rocks, rivers and other natural features | Rivers slow anything inside them. Castle, shops and all Gold Mines are here. |
| 2 | **Underworld** | Ogres | Dry tan dirt | Rigid walls | None |
| 3 | **Catacombs** | Undead | Black and white graveyard | Maze of bone and iron-bar walls | Darkness until the boss dies |
| 4 | **Pandemonium** | Demons | Reddish-brown ground with lava cracks | Black iron-bar walls | Lava. Demon shields regenerate every 9 seconds. |
| 5 | **Abyss** | All four | Greyish-black ground | Large purple crystal in the center | No shop, no nest, no Gold Mines |

- **Spawning:** the player spawns in the **middle** of layers 1–4. In the Abyss they spawn at the **bottom** and follow a path to the center, moving at **60% speed** until the crystal breaks.
- **Layer flow (layers 1–4):** destroy both nests, defeat the boss, collect the rewards, then enter the portal that opens **where the last nest stood**.
- **Portals are one-way.** A layer can't be revisited, and anything left behind is lost.
- **Darkness (Catacombs):** visibility radius is halved, and enemies beyond it are unseen. Vision is restored when the boss dies.
- **Lava (Pandemonium):** thin, jagged, forking cracks. Standing on one deals **1 HP every 3 seconds** to the player unless they have an active shield. It doesn't consume shield points.
- **Rivers (Overworld):** the player, monsters and bosses move at **50% speed** while inside. Spells pass over them unaffected.
- **Obstacles:** trees, rocks, walls and iron bars all block movement and spells. Shoot Through Walls lets player spells pass through every one of them.

### 6.7 Nests
- Layers 1–4 each have **two nests**, placed at random near the **4 edges** of the map, at least 16 tiles apart.
- It spawns that layer's monster type directly from its center hole, starting **5 seconds** after the player arrives.
- Spawn rate rises each layer: **1×, 1.5×, 2×, 2.5×** the rates in §6.8. The Abyss keeps its own rates (§6.10).
- Nest base HP: **70** (§3), damaged by player spells via swept-segment hit detection.
- When the **last** nest is destroyed, that layer's **floor boss spawns immediately** at its spot.

### 6.8 Monsters (all melee)
| Class | HP | Damage | Radius (tiles) | Speed (from size) | Spawn interval | Gold drop | Special |
|---|---|---|---|---|---|---|---|
| Goblin | 3 | 1 | 0.35 | ~2.57 tiles/s | every 5 s | 1 | — |
| Ogre | 10 | 1 | 0.60 | ~1.50 tiles/s | every 7 s | 4 | — |
| Undead | 4 | 2 | 0.40 | ~2.25 tiles/s | every 8 s | 3 | Fires a white 0-damage slow spell at half normal spell speed (3.0 tiles/s) |
| Demon | 7 | 2 | 0.45 | ~2.00 tiles/s | every 16 s | 5 | Bubble shield: breaks after 1 spell hit or 1 Bombspell fire tick, then regenerates 9 seconds later |

- Monster speed varies inversely with theoretical size (`PLAYER_SPEED_TILES * min(0.9, 0.3 / radius_tiles)`), and is never faster than the player.
- Monsters chase the player around obstacles.

**Drops:**

| Class | Enhancer | Spell Scroll |
|---|---|---|
| Goblin | 1 in 4 | — |
| Ogre | 1 in 4 | 1 in 4 |
| Undead | 1 in 4, ×1.2 | 1 in 4, ×1.2 |
| Demon | Every kill drops **1–3 of one type**, chosen at random: Enhancers or Spell Scrolls | |

- Luck multiplies Goblin, Ogre and Undead drop counts (§6.3).
- Monsters no longer drop Augmentation Scrolls.
- Monsters in the Abyss drop nothing, not even gold, unless Endless Mode is on.

### 6.9 Floor Bosses
Each of layers 1–4 has one boss matching its monster: **Goblin, Ogre, Undead, Demon**.

| Stat | Value |
|---|---|
| HP | 480, 720, 1080, 1620 by layer (§3) |
| Melee damage | 5 |
| Ranged attack | Fires a 1-damage projectile at 1 tile/sec in a straight line |
| Spawn | Immediately after the layer's last nest is destroyed |
| Escort | Bosses from nests spawn **3 of their monster every 5 seconds** nearby, then stop after 30 in total. Bosses summoned by the Mega Boss don't. |
| Spawn protection | Takes 30% less incoming damage for the first 5 seconds after spawning, including fire/augmentation damage; applies to all boss summons |
| Drops | **1000 gold** + **3–5 Augmentation Scrolls** (random). Luck has no effect. Bosses summoned by the Mega Boss drop nothing. |
| On death | Opens the portal. In the Catacombs, also restores vision. |

**Augmentation supply:** bosses are the only source. Four bosses give 12–20 scrolls, about 16 on average, and maxing all three augmentations takes 18. A full set therefore takes good rolls, and most runs end one or two upgrades short.

### 6.10 Mega Boss (the Pit Boss)
**Trigger:** the crystal is an egg. Walking up and touching it breaks it open, and the Mega Boss emerges.

**Phase 1:**
- **HP:** 8000, with the same melee/ranged damage and movement speed as a floor boss. It no longer splits at 50% HP.
- **Spell speed:** projectiles move at the same speed as the player's base spell (`6.0` tiles/sec).
- **Regenerating shield:** starts with a **500 HP shield** that regenerates to 500 HP at 75%, 50% and 25% HP.
- **Cataclysms:** at 75%, 50% and 25% HP it starts a 20-second invulnerable phase: Meteor Storm, Shockwaves, then The Collapse. No hit can skip one, and monsters keep spawning throughout. They give the fight a minimum length, because player damage varies too much for HP alone to do that.
  - **Meteor Storm:** marked circles land after 1.6 seconds for 3 damage.
  - **Shockwaves:** rings expand from the boss every 2.6 seconds for 3 damage. Each has two gaps to stand in.
  - **The Collapse:** after a 3-second warning, everything outside a drifting safe circle burns for 2 damage per second.
- **Summons:** the floor bosses in order, at the HP they had on their own layers: Goblin at 75%, Ogre at 50%, Undead at 25%, Demon at 0%.
- **Monsters:** spawns every type, capped at **10 of each** alive at once:

| Class | Spawn rate |
|---|---|
| Goblin | 4 every 2 s |
| Ogre | 3 every 3 s |
| Undead | 2 every 4 s |
| Demon | 1 every 5 s |

**Transition:** at 0% HP the Mega Boss stays on the map as an inert, shielded body. Phase 2 starts once all four floor bosses are dead.

**Phase 2 (Dragon):**
- Revives to full HP and transforms into a dragon that moves around the map **over walls**.
- Stops spawning anything. Monsters already alive remain.
- **Cataclysms:** at 75% HP the Inferno (fire lines radiating from it, plus meteors), at 50% Dragon's Breath (3 fire beams sweeping around it for 3 damage, after a warning), and at 25% The Sky Falls (The Collapse plus meteors).
- It has **no shield** and **no melee**. Fire is its only attack.
- It moves at its phase 1 speed and stays near the player so it can be hit.
- **Fire lines:** 5 seconds after the previous line finishes, a line lights up on the ground for **3 seconds**, then fire engulfs it for **3 seconds**.
  - **Aim:** the line runs from the dragon's position through the player's position, both fixed when it lights up.
  - **Length:** the original base spell range (10 tiles), unaffected by upgrades.
  - **Width:** a normal boss spell (0.4 tiles).
  - **Damage:** the shield must break before HP is touched. Fire removes 1 shield point per second, then deals 3 HP per second once the shield is gone.
- **Defeating it** brings out the hidden boss.

**Hidden boss (keep it out of the Rules & Guide, README and `docs/PROTOTYPE.md`):**
- **Stats:** the Mega Boss's stats and 500 HP shield, with **2×** its HP (16000). It has its own sprite and the `hidden_boss` track.
- **Phases:** only two Cataclysms, Meteor Storm at 66% and Shockwaves at 33%. No summons and no monsters, because the player is low on items by now.
- **Abyssal Corruption** deals combined damage to it instead of one-shotting it.
- **Defeating it** gives Victory: a white flash, then the end screen and credits. With Endless on, see §6.13. Later Endless Mega Bosses don't bring one.

### 6.11 Gold Mines
- **5 gold mines**, only on the Overworld, placed next to the **right** side of the castle.
- Each mine produces **7.5 gold/sec**, capped at **333 gold**.
- Walk over a gold mine to collect its stored gold.
- Mines keep filling after the player descends. Below the Overworld there are no mine nodes, so estimate their contents from the time elapsed, the rate and the cap.
- The **Auto Gold Collector** collects that estimated gold from any layer, even if it is bought after descending. Without it, gold left in the mines can never be picked up, because portals are one-way.

### 6.12 Terrain Generation
- Every new run generates fresh terrain for each layer, keeping the center open around the player's spawn.
- **Overworld:** scattered natural features with rivers, and no walls.
- **Underworld:** rigid walls.
- **Catacombs:** a tighter maze.
- **Pandemonium:** black iron-bar walls, with lava cracks across the floor.
- **Abyss:** a fixed shape rather than random terrain. A 5-tile-wide corridor of jagged rock runs from the bottom edge to a circular arena around the crystal, with a radius of 35% of the map size. A second corridor runs from the top of the arena to the top of the map, where the hidden spell sits. The hidden spell appears when the crystal breaks, so reaching it means crossing the fight.
- Nests, unique spells and the path to them must always be reachable.

### 6.13 Endless Mode
With Endless on, defeating the dragon sends the player back to the **Overworld** instead of ending the game.

- It is a freshly generated Overworld with the castle, shops and Gold Mines working as normal. There is no nest, portal or unique spell.
- A new Mega Boss, with both phases, arrives every minute at a random point on the map edge. The first comes 60 seconds after the player arrives.
- **They never stack.** While one is alive the next can't spawn. Once it dies and the minute is up, the next one comes in.
- **HP:** the first has 1.5× Mega Boss HP, and each one after adds +0.5× (1.5×, 2×, 2.5×, …).
- **Monsters** spawn from anywhere around the map edge, at the Abyss rates and caps, with HP at `depth` 4. The Mega Boss doesn't spawn extra monsters of its own.
- **Monsters and bosses drop nothing**, including gold, so Gold Mines are the only income.

---

## 7. Technical Guidance

### Co-op architecture
- `Coop` (autoload) owns the connection, seats and all network messages. Seats (1–3) identify players, because ENet peer IDs are random.
- The host runs the only real simulation. `CoopHostSync` sends a snapshot of packed arrays 20 times a second.
- Guests draw snapshots through `CoopGuestView`, which uses the real scenes with their processing disabled. Each map is rebuilt from the host's seed and clear zones.
- A guest's `GameState` is a mirror (`is_mirror`). Shop purchases apply locally, then go to the host as requests, and the host's reply corrects them. Only `try_buy_*`, `try_upgrade_spell` and the toggles are accepted.
- Never preload `Projectile.tscn`. Use `Config.projectile_scene()`, because a preload forms a loop that leaves the scene empty when the game starts from the Main Menu.

### Suggested autoloads (`scripts/autoload/`)
- `Config`: constants (TILE_SIZE, base stats) and loaders for the resource files.
- `GameState`: the current run's settings (map size, difficulty), current layer, gold, spell level, owned mods. Emits `victory` / `defeat`.
- `SceneRouter` (optional): handles menu → game → end-screen transitions.
- `AudioManager`: plays sound effects. See `docs/AUDIO.md`.
- `Coop`: co-op sessions and networking. See `docs/MULTIPLAYER.md`.

### Suggested resources
- `MonsterStats` (`hp`, `damage`, `speed_mult`, `spawn_interval`, `gold`, `scene`)
- `SpellData` (`name`, `speed_tiles`, `damage`, `fire_rate`, `projectile_scene`)
- `DifficultyData` (`name`, `hp_mult`, `hp_growth_per_layer`)
- `MapSizeData` (`name`, `size_in_tiles`, `scene`)
- `LayerData` (`name`, `monster`, `boss`, `floor`, `terrain`, `unique_spell`, layer rules)

### itch.io / Web export
- Export with the **Web** preset into `export/web/`. Zip the folder contents with `index.html` at the zip root, then upload it to itch.io as an HTML game.
- On itch.io, turn on **SharedArrayBuffer support** if threads are enabled. Otherwise export **without threads** (easiest for Godot 4.3+).
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
- Keep the Rules & Guide free of `Nothing`, Abyssal Corruption, the hidden boss and the `E` key, because they are meant to stay secret. The same goes for the README and `docs/PROTOTYPE.md`.
- Don't invent balance numbers that aren't in this file. Use a placeholder in a resource file, mark it with a `# TODO(design)` comment, and add it to §9.
- After changing design-relevant code, update this file if the user approved the change.
- Keep each feature in its own scene + script pair so pieces can be tested in isolation (F6 in Godot).
- Include graphics and sound for every new feature. Generated assets are fine. Music comes from the user.
- Keep the `Rules & Guide` screen in step with these rules.

---

## 8. Milestones (redesign, in order)

1. **Layer framework (done):** `LayerData`, per-layer state, nest → boss → portal → descend, HP scaling, boss scroll drops. Until later milestones, every layer shares the old maze and uses the castle as its shop, and the Abyss still has the old Mega Boss.
2. **Overworld (done):** grass, trees, rocks, rivers, no walls.
3. **Economy (done):** shop stalls and heal, Gold Mines, drops, Luck, HP scaling, spell level 17, mods to 20, cone homing, new shop sounds.
4. **Unique spells (done):** Water, Earth, Death, Fireball.
5. **Underworld, Catacombs, Pandemonium (done):** one at a time, with their rules.
6. **Abyss (done):** crystal, Mega Boss phases, dragon, white flash, end screen, credits.
7. **Endless rework and Abyssal Corruption (done).**
8. **Multiplayer (done over LAN):** host-authoritative co-op. Left to do: test WebRTC in a real browser build, and deploy signaling and TURN for internet play (`docs/MULTIPLAYER.md`).

---

## 9. Open Design Questions (ask the user before implementing these)

### Multiplayer rules

- Online co-op: one player hosts and two players join using WebRTC.
- Each player has a separate inventory, gold, and upgrade materials.
- Only the player landing the killing blow receives monster or boss gold.
- Ground pickups belong to the first living player to collect them.
- Player starting HP is **7** in both modes. Normal enemies have **2× base HP**
  in co-op; all boss types have **5× base HP total**, including the Mega Boss.
  Nest, player, doppelganger and shield HP are not multiplied.
- **Each descent also multiplies HP by 2×**, on top of those rules and the difficulty.
- Nest boss base HP is **480**, giving **2400 HP** in co-op before difficulty.
- **Portals:** every player must enter to descend. Anyone who enters early waits in a
  **purgatory void layer** until the rest arrive. The same applies to a two-player game.
- **Darkness** applies to each player separately.
- The Gold Shop sells a **permanent Revival unlock for 999 gold**, per
  player for the current run. Buying it twice is not allowed; uses do not consume it.
- An unlocked living player stands over a teammate's body for **3 uninterrupted
  seconds**. Leaving the body's footprint resets the interaction. Multiple
  helpers do not stack progress. After completion, the teammate respawns at the
  castle **5 seconds later with 5 HP** and no shield.
- **All players downed ends the run immediately**, canceling any pending
  castle returns. A single death does not end co-op.
- See `docs/MULTIPLAYER.md` for the connection prototype, deployment requirements,
  and implementation milestones.
- Co-op menus block only the local player's controls; the shared simulation continues.
- Monsters chase the nearest living player. Players in the void can't be targeted.
- Gold Mines pay whoever walks over them. Below the Overworld, each player's Auto Gold
  Collector gets an equal share of what the mines earn. Mine upgrades use the host's levels.
- A unique spell goes to whoever collects it first, and there is one per layer.
- A guest who disconnects leaves the run, which continues without them. There is no rejoining.
  If the host leaves, the run ends for everyone.
- A revived player returns to the current layer's arrival point.
- The Mega Boss keeps its 5× co-op HP and doesn't double per descent.
- The host picks the map, difficulty and Endless Mode in the lobby. Sandbox is single player only.

### Single player

No design questions are open. All balance numbers in this file are first passes, to be tuned by playtest.
