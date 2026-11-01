# Hukulshish

A 2D top-down action dungeon descent made in **Godot 4.7.2**, playable at **1920×1080** in desktop browsers through **itch.io** (HTML5/Web).
Play as the mage **Hukulshish**: fight down through five layers, each harder than the last, and slay the dragon at the bottom.

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

## Gameplay Overview

### Controls
- **`W` `A` `S` `D` / Arrow Keys:** Move (`3.0` tiles/sec base).
- **Left-Click:** Shoot the selected spell toward the cursor.
- **`1` to `5`:** Select a spell: Base, Water, Earth, Death, Fireball.
- **`F` (once Homing is bought):** Toggle homing, which curves spells toward the closest enemy within a `45°` cone of your shot.
- **`Z` / `X` / `C` / `V` (or click the bottom hotbar):** Magic Shield (`+1`, max `5`), Healing Potion (`+3 HP`), 2× Damage Potion (`30s`), Doppelganger.
- **`Esc` or `P`:** Pause, with SFX, Music and Screen Shake sliders.
- **Main Menu → Rules & Guide:** An illustrated guide to everything below.

### The Five Layers
On each of the first four layers, destroy the two nests near the map edge, defeat the crowned boss and the monsters it brings, then enter the portal where the last nest stood. Portals are one-way.

| # | Layer | Monsters | What makes it different |
|---|---|---|---|
| 1 | **Overworld** | Goblins | Grass, trees and rocks. Rivers halve speed. The castle, shops and 5 Gold Mines are here. |
| 2 | **Underworld** | Ogres | Dry dirt and rigid walls. |
| 3 | **Catacombs** | Undead | A tight maze of bone and iron bars. Darkness halves your vision until the boss dies. |
| 4 | **Pandemonium** | Demons | Iron bars and lava. Lava burns `1 HP` every `3s` unless you have a shield. |
| 5 | **Abyss** | All of them | No shop. A slow path leads to a purple crystal. Touch it to wake the Mega Boss inside. |

**Monster and nest HP** compounds with every descent: `×1.25` Easy, `×1.5` Medium, `×2` Hard, `×3` Extreme, on top of each difficulty's base (`×0.5`, `×1`, `×2`, `×5`). **Floor bosses** have `480`, `720`, `1080` and `1620 HP`.

### Shops
Every layer but the last has a row of five stalls. Walking into one heals you up to `75%` of max HP.

- **Spell (Gold):** Base Spell levels `1–17`, up to `63` damage.
- **Spell Mods (Spell Scrolls):** Damage, Mana Regen, Mana Pool and Range. A level costs its own number in scrolls.
- **Augmentations (Augmentation Scrolls, from floor bosses):** Split Spell, Bombspell and Sniper, each with a Level 3 unique ability.
- **Personal (Enhancers):** Luck, Movement Speed, Health Regen, Mine Capacity, Mine Rate and Income.
- **Gold:** Max HP, Spell Scrolls, Magnet, Shoot Through Walls, Shield and Potions, Auto Gold Collector, Homing and a Doppelganger.

### Co-op
Two or three players can play together: open **Multiplayer** from the Main Menu. On a local network, one player hosts and the others join with the host's address. To try it alone, use Godot's **Debug → Customize Run Instances** to launch three copies. Monsters have more HP, each player has their own gold and upgrades, and everyone must reach the portal to descend. See [`docs/MULTIPLAYER.md`](docs/MULTIPLAYER.md).

### Unique Spells
One is hidden on each of the first four layers. Each copies your Base Spell when found. Select one with the number keys to fire it for `1` mana.

- **Water:** Slows the mob hit by `20%` for `3s`.
- **Earth:** `×2` damage, and stuns for `1s`.
- **Death:** `×3` damage, and poisons for `3 HP/s` over `3s`.
- **Fireball:** `×4` damage, and explodes across the Bombspell's area.

### The Final Fight
- **Mega Boss (`8000 HP`):** A shield that regenerates at `75%`, `50%` and `25%` HP, floor boss summons at each of those points and at `0%`, and waves of every monster. At each of those points it also becomes invulnerable for `20s` and unleashes a Cataclysm on the arena.
- **Dragon:** Once the summons are dead, it rises at full HP and flies over walls, attacking with fire lines that glow for `3s` and burn for `3s`, and three Cataclysms of its own.
- **Endless Mode:** After the dragon, you return to the Overworld, where a Mega Boss arrives every minute with growing HP. Nothing drops, so only your mines earn gold.

---

## Docs

- [`AGENTS.md`](AGENTS.md) — game design source of truth + rules for AI coding agents
- [`docs/PROTOTYPE.md`](docs/PROTOTYPE.md) — quick playtest notes
- [`docs/AUDIO.md`](docs/AUDIO.md) — regenerating and replacing sound effects
- [`docs/MULTIPLAYER.md`](docs/MULTIPLAYER.md) — co-op rules and connection setup
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — Git workflow for the two of us (read first!)

## Building for itch.io

Project → Export → **Web** → export to `export/web/index.html`, zip the contents of `export/web/`, upload to itch.io as an HTML project. (Build output is git-ignored.)
