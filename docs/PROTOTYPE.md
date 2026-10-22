# Prototype Notes

Playable prototype of Normal mode (built for **Godot 4.7.2** at **1920×1080**).
All visuals are placeholder shapes drawn in code (`_draw()`), so no art assets are needed yet.

## How to play

- **Start → Map Size → Difficulty**, then the run begins on a freshly generated spacious maze map.
- **WASD / arrow keys** to move (`3.0` tiles/sec).
- **Left-click** in the world to shoot toward your cursor (respecting each spell's fire rate cooldown). Spells move at **2× player speed (`6.0` tiles/sec)**.
- **Pause:** click the **⏸ Pause** button in the top-right corner (or press `Esc` / `P`).
- **Shield Bar & Bottom Hotbar:**
  - Your blue **Shield Bar** (capped at `5`) absorbs incoming damage before your HP.
  - Click the circular hotbar icons at the bottom of the screen (or press `1`, `2`, `3`) to use:
    1. **Magic Shield (`[1]`):** adds `+1` shield point (up to 5).
    2. **Healing Potion (`[2]`):** restores `+3 HP` (30 s timer).
    3. **2× Damage Boost Potion (`[3]`):** doubles spell damage for **30 seconds**.
- **Gold Mines:** 2 gold mines spawn in random regions of the map, each generating **7.5 gold/sec** up to **333 gold**. Walk over a mine to collect its stored gold.
- **Castle Shop & Heal:** walk out of and back into the castle to heal up to **7/10 of max HP** (never above 7/10) and open the upgrade & shop menu (pauses the game):
  - **Base Spell Upgrade:** spend Gold to level up the Base Spell (Lv 1–9).
  - **Spell Mods:** spend Mod Parts (1/7 drop from monsters, or bought in the Gold Shop) to upgrade **Damage**, **Fire Rate**, **Spell Speed**, or **Range** (`+0.1×` per level; costs `1, 2, 3, 4`, then `8, 16, 32, …`).
  - **Gold Shop:**
    - **Mod Part:** `100` gold for the 1st, then `+100` per part up to 10 (`100..1000`).
    - **Magic Shield (+1 Shield):** `200` gold.
    - **3 HP Healing Potion (30s):** `100` gold.
    - **2× Damage Boost Potion (30s):** `100` gold.
    - **Unlock Auto-Shooting:** `1500` gold (automatically aims and shoots at the nearest target within range).
- **Nests & Bosses:**
  - All 4 corner nests have **70 HP**, spawn monsters directly from their center hole, and take damage from player spells via swept-segment hit detection.
  - Each destroyed nest spawns a **Nest Boss** 20 s later (**1000 gold** + **1/3 chance** to drop a **Boss Spell**).
  - Destroying all 4 nests awakens the **Mega Boss** (**1000 HP**, spawns a boss every 50 s and normal monsters at their regular intervals). Defeating the Mega Boss wins the run.
