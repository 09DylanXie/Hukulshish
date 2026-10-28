# Prototype Notes

Playable prototype of Normal mode (built for **Godot 4.7.2** at **1920×1080**).
All visuals are placeholder shapes drawn in code (`_draw()`), so no art assets are needed yet.

## How to play

- **Start → Map Size → Difficulty**, then the run begins on a freshly generated spacious maze map.
- **WASD / arrow keys** to move (`3.0` tiles/sec).
- **Left-click** in the world to shoot toward your cursor (respecting each spell's cooldown and mana cost: **1 mana** for Base Spell, **2 mana** per Boss Spell). Spells move at **2× player speed (`6.0` tiles/sec)**.
- **Pause:** click the **⏸ Pause** button in the top-right corner (or press `Esc` / `P`).
- **HP, Shield & Mana Bars + Bottom Hotbar:**
  - Your blue **Shield Bar** (capped at `5`) absorbs incoming damage before your HP.
  - Your purple **Mana Bar** starts at `10` max mana (upgradable up to `29` via Mana Pool) and regenerates at `1.0/sec` base (+`0.5/sec` per Mana Regen level).
  - Click the circular hotbar icons at the bottom of the screen (or press `1`, `2`, `3`) to use:
    1. **Magic Shield (`[1]`):** adds `+1` shield point (up to 5).
    2. **Healing Potion (`[2]`):** restores `+3 HP` (30 s timer).
    3. **2× Damage Boost Potion (`[3]`):** doubles spell damage for **30 seconds**.
- **Gold Mines:** 2 gold mines spawn in random regions of the map, each generating **7.5 gold/sec** up to **333 gold**. Walk over a mine to collect its stored gold.
- **Castle Shop & Heal:** walk out of and back into the castle to heal up to **7/10 of max HP** (never above 7/10) and open the upgrade & shop menu (pauses the game):
  - **Base Spell Upgrade:** spend Gold to level up the Base Spell (Lv 1–9).
  - **Spell Mods:** spend **Spell Scrolls** (1/7 drop from monsters, or bought in the Gold Shop) to upgrade **Damage** (`+0.1×`/lv), **Mana Regen** (`+0.5/s`/lv), **Mana Pool** (`+1` max mana until 15, then `+2` until 29), or **Range** (`+0.1×`/lv). Costs `1, 2, 3, 4`, then `8, 16, 32, …` Spell Scrolls.
  - **Augmentations (Demon Drops):** Demons have a **1/5 chance** to drop an **Augmentation Scroll** (and possess a 1-hit bubble shield). Each augmentation can be upgraded up to **3 times** (costing `1`, `2`, `3` Augmentation Scrolls):
    - **Split Spell:** splits player spell on enemy contact into `2 / 3 / 4` shots at `30°` angles (or homing if Homing is unlocked), each dealing `1/2` damage.
    - **Bombspell:** creates a medium fire zone on target impact for `3s` dealing `3 / 5 / 7` dmg/s (applies on final split spells when Split is active; 1 fire tick breaks a Demon's bubble shield).
    - **Sniper:** on initial player spell impact with an enemy, fires a `5×` speed homing shot at the nearest enemy for `2× / 3× / 4×` damage (does not trigger other augmentations or repeat).
  - **Gold Shop:**
    - **Spell Scroll:** `100` gold for the 1st, then `+100` per scroll up to 10 (`100..1000`).
    - **Magic Shield (+1 Shield):** `200` gold.
    - **3 HP Healing Potion (30s):** `100` gold.
    - **2× Damage Boost Potion (30s):** `100` gold.
    - **Magnet:** `100` gold (pulls dropped Spell Scrolls, Augmentation Scrolls, and Boss Spell pickups toward the player).
    - **Unlock Auto-Shooting:** `1000` gold (automatically aims and shoots at the nearest target within range).
    - **Unlock Homing:** `1500` gold (curves spells toward the closest enemy).
- **Enemy Scaling, Nests & Bosses:**
  - After **3 minutes**, enemy HP scales every **30 seconds**: unchanged on **Easy**, `+5 HP` linearly on **Medium**, `×1.2` exponentially on **Hard**, and `×1.5` exponentially on **Extreme**.
  - All 4 corner nests have **70 HP**, spawn monsters directly from their center hole, and take damage from player spells via swept-segment hit detection.
  - Each destroyed nest immediately spawns a **Nest Boss** (**80 HP**, **1000 gold** + **1/3 chance** to drop a **Boss Spell**).
  - Destroying all 4 nests awakens the **Mega Boss** (**2000 HP**, spawns a boss every 50 s and normal monsters at their regular intervals). Defeating the Mega Boss wins the run.
