# Hukulshish

A 2D top-down survival / base-defense game made in **Godot 4.7.2**, playable at **1920×1080** on desktop and exportable to **itch.io** (HTML5/Web).
Play as the mage **Hukulshish** (wielding an arcane wand and offhand magic catalyst), navigate a procedural spacious maze, upgrade your spells across three distinct shops inside the Kingdom Castle, destroy the four monster nests, and defeat the **Mega Boss** — or test how many waves you can survive in **Endless Mode**!

---

## Godot Version

> **Both collaborators must use exactly: `Godot 4.7.2 stable` (standard, not .NET)**
> ⚠️ Only change this version together.

## Getting Started

```bash
git clone https://github.com/09DylanXie/Hukulshish.git
```
Open Godot → **Import** → select `project.godot`.

---

## Gameplay & Mechanics Overview

### Controls
- **`W` `A` `S` `D` / Arrow Keys:** Move around the map (`3.0` tiles/sec base).
- **Left-Click (Crosshair Cursor):** Shoot spells from your wand toward the cursor.
- **`E` Key (once Auto-Shooting is unlocked):** Toggle Auto-Fire ON/OFF (auto-fires at `½` fire rate so you can still manually fire).
- **`F` Key (once Homing is unlocked):** Toggle Homing ON/OFF (curves spells toward the closest enemy; does not affect Split Shots).
- **`1` / `2` / `3` Keys (or click the bottom hotbar circles):**
  1. **Magic Shield (`[1]`):** Adds `+1` Shield (up to `5` max shield; absorbs damage before HP).
  2. **Healing Potion (`[2]`):** Restores `+3 HP` (`30s` effect timer).
  3. **2× Damage Boost Potion (`[3]`):** Doubles spell damage for `30` seconds.
- **`Esc` or `P`:** Pause the game.
- **Main Menu → Rules & Guide:** Opens an interactive, illustrated 3-tab guide explaining all mechanics and Level 3 Augmentation abilities.

### Player, Mana & Castle Healing
- **Starting Max HP:** `5` (upgradable in the Gold Shop to `6 → 7 → 10` via `+1`, `+1`, `+3` without instant healing).
- **Castle Heal:** Walking into the Kingdom Castle restores HP up to **`3 HP`** (never above `3 HP`) and opens the Castle Upgrade & Shop menu.
- **Mana Bar:** Starts at `10` max mana with `1.0/sec` base regeneration. Casting the **Base Spell** costs `2` mana (`2.0` shots/sec base fire rate); casting each **Boss Spell** costs `3` mana.

### The Three Castle Shops
1. **Spell Mods (Cyan Spell Scrolls — `1/7` drop from all monsters, or up to 10 in the Gold Shop):**
   - **Damage:** `+0.1×` damage multiplier per level.
   - **Mana Regen:** `+0.5/sec` mana regeneration per level.
   - **Mana Pool:** `+1` max mana per level from `10` to `15`, then `+2` per level up to `29` max mana.
   - **Range:** `+0.1×` spell travel range per level.
   - *Costs:* `1, 2, 3, 4`, then exponential (`8, 16, 32, …`) Spell Scrolls.
2. **Augmentations (Crimson Augmentation Scrolls — `1/5` drop from Demons only; max Level 3, costing `1, 2, 3` Scrolls):**
   - **Split Spell:** Splits the player's spell on enemy contact into `2 / 3 / 4` shots at **`45°` angles** dealing `½` damage (Homing does not apply to Split Shots). **Level 3 Unique — Chain Lightning:** Split hits arc lightning to a second nearby enemy, zapping both enemies alongside each other for the split shot's damage.
   - **Bombspell:** Creates a burning fire zone (`5%` smaller radius) on target impact for `3s` dealing `3 / 5 / 7` fire dmg/sec (`1` tick breaks a Demon's bubble shield). **Level 3 Unique — Total Detonation:** Explodes on **every hit** (even initial hits before splitting) **and** explodes when the spell runs out of range.
   - **Sniper:** On initial hit against an enemy, fires a `5×` speed homing shot at the nearest **Monster or Boss (never Nests)** for `2× / 3× / 4×` damage. **Level 3 Unique — Explosive Shell:** The Sniper shell detonates with a Bombspell fire explosion on impact.
3. **Personal Shop (Emerald Enhancers — `1/4` drop from Goblins & Undead; max Level 3, costing `3, 5, 9` Enhancers):**
   - **Luck:** `+20%` item drop rate per upgrade (non-cumulative).
   - **Movement Speed:** `+5%` player movement speed per upgrade (non-cumulative).
   - **Health Regen:** `+1 HP / 10 secs` per upgrade.
   - **Capacity:** `+1/3` Gold Mine capacity per upgrade (non-cumulative).
   - **Rate:** `+15%` Gold Mine generation rate per upgrade (non-cumulative).
   - **Income Multiplier:** `+50%` gold per upgrade from **monsters and bosses only**.
4. **Gold Shop:**
   - **Max HP Upgrade (`200 / 400 / 800` gold):** Upgrades Max HP `5 → 6 → 7 → 10` (`+1`, `+1`, `+3` on the final upgrade; no instant heal).
   - **Spell Scroll (`100..1000` gold, max 10)**
   - **Magnet (`300` gold):** Pulls all dropped Scrolls, Enhancers, and Boss Spells toward the player.
   - **Magic Shield (`200` gold)**, **3 HP Healing Potion (`100` gold)**, **2× Damage Boost Potion (`100` gold)**
   - **Auto-Shooting (`1000` gold, toggle with `E`)** & **Homing (`1500` gold, toggle with `F`)**
   - **Doppelganger (`5000` gold):** Summons a `5 HP` twin (cannot have a shield) that copies your current abilities and fights alongside you until it dies.

### Enemies, Bosses, Scaling & Endless Mode
- **Goblin:** Fast melee monster (`1/4` Enhancer drop).
- **Undead:** Fires a **white 0-damage Slow Spell** moving at `½` normal spell speed (`3.0` tiles/sec) that slows the player on hit (`1/4` Enhancer drop).
- **Demon:** Protected by a **1-hit Cyan Bubble Shield** (`1/5` Augmentation Scroll drop).
- **Ogre:** High-HP melee bruiser.
- **3-Minute Enemy HP Scaling:** After 3 minutes, monster HP scales every 30 seconds by `+5 HP` linearly on **Medium**, `×1.2` exponentially on **Hard**, and `×1.5` exponentially on **Extreme** (unchanged on **Easy**).
- **Nests (`70 HP`) & Nest Bosses (`80 HP`):** Destroying a corner Nest immediately spawns a Nest Boss (`1000` gold + `1/3` chance to drop an **Orange Boss Spell**).
- **Mega Boss (`2000 HP`):** Awakens when all 4 Nests are destroyed. Fires bolts at player base spell speed (`6.0` tiles/sec), spawns bosses and monsters at `2×` rate, and has a **`100 HP` Shield** that regenerates after each `¼` of its max HP is lost (`75%`, `50%`, `25%`).
- **Endless Mode:** Defeating the Mega Boss drops a guaranteed `1/1` **Red Mega Boss Spell** (combines all current spells `× 1.5` damage and copies & uses your Base Spell's augmentations), spawns **4 new corner spawners**, and multiplies **everything's HP by `2×`**!

---

## Docs

- [`AGENTS.md`](AGENTS.md) — game design source of truth + rules for AI coding agents
- [`docs/PROTOTYPE.md`](docs/PROTOTYPE.md) — quick playtest notes
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — Git workflow for the two of us (read first!)

## Building for itch.io

Project → Export → **Web** → export to `export/web/index.html`, zip the contents of `export/web/`, upload to itch.io as an HTML project. (Build output is git-ignored.)
