# Prototype Notes

Playable prototype of Normal mode (built for **Godot 4.7.2** at **1920×1080**).
All visuals are placeholder shapes drawn in code (`_draw()`), so no art assets are needed yet.

## How to play

- **Start → Map Size → Difficulty (with optional Endless Mode)**, then the run begins on a freshly generated spacious maze map.
- **WASD / arrow keys** to move (`3.0` tiles/sec).
- **Left-click** in the world to shoot toward your cursor (respecting each spell's cooldown — `2.0/sec` base, 2× faster — and mana cost: **2 mana** for Base Spell, **3 mana** per Boss Spell). Spells move at **2× player speed (`6.0` tiles/sec)**.
- **Pause:** click the **⏸ Pause** button in the top-right corner (or press `Esc` / `P`).
- **HP, Shield & Mana Bars + Bottom Hotbar:**
  - Your blue **Shield Bar** (capped at `5`) absorbs incoming damage before your HP.
  - Your purple **Mana Bar** starts at `10` max mana (upgradable up to `29` via Mana Pool) and regenerates at `1.0/sec` base (+`0.5/sec` per Mana Regen level).
  - Click the circular hotbar icons at the bottom of the screen (or press `1`, `2`, `3`) to use:
    1. **Magic Shield (`[1]`):** adds `+1` shield point (up to 5).
    2. **Healing Potion (`[2]`):** restores `+3 HP` (30 s timer).
    3. **2× Damage Boost Potion (`[3]`):** doubles spell damage for **30 seconds**.
- **Gold Mines:** 2 gold mines spawn in random regions of the map, each generating **7.5 gold/sec** up to **333 gold**. Walk over a mine to collect its stored gold.
- **Castle Shop & Heal:** walk out of and back into the castle to heal up to **3 HP** (never above 3 HP) and open the upgrade & shop menu (pauses the game):
  - **Base Spell Upgrade:** spend Gold to level up the Base Spell (Lv 1–9).
  - **Spell Mods:** spend **Spell Scrolls** (1/7 drop from monsters, or bought in the Gold Shop) to upgrade **Damage** (`+0.1×`/lv), **Mana Regen** (`+0.5/s`/lv), **Mana Pool** (`+1` max mana until 15, then `+2` until 29), or **Range** (`+0.1×`/lv). Costs `1, 2, 3, 4`, then `8, 16, 32, …` Spell Scrolls.
  - **Augmentations (Demon Drops):** Demons have a **1/5 chance** to drop an **Augmentation Scroll** (and possess a 1-hit bubble shield). Each augmentation can be upgraded up to **3 times** (costing `1`, `2`, `3` Augmentation Scrolls):
    - **Split Spell:** splits player spell on enemy contact into `2 / 3 / 4` shots at `45°` angles (Homing does not apply to Split Shots), each dealing `1/2` damage. **Lv 3 Unique:** chains lightning across hits, connecting the hit enemy with another enemy and zapping both for the split shot's damage.
	- **Bombspell:** creates a medium fire zone (`5%` smaller) on target impact for `3s` dealing `3 / 5 / 7` dmg/s (1 fire tick breaks a Demon's bubble shield). **Lv 3 Unique:** explodes on every hit whether split or not, and also explodes when the spell runs out of range.
	- **Sniper:** on initial player spell impact with an enemy, fires a `5×` speed homing shot at the nearest **monster or boss (never nests)** for `2× / 3× / 4×` damage. **Lv 3 Unique:** sniper shell explodes with the Bombspell explosion on hit.
  - **Personal Shop (Goblin & Undead Enhancers):** Goblins and Undead have a **1/4 chance** to drop an **Enhancer** (Undead also cast a 0-damage slow spell at half normal spell speed). All 6 upgrades max at **Level 3** and cost `3`, `5`, `9` Enhancers:
	- **Luck:** `+20%` drop rate per upgrade (non-cumulative).
	- **Movement Speed:** `+5%` player movement speed per upgrade (non-cumulative).
	- **Health Regen:** `+1 HP / 10 secs` per upgrade.
	- **Capacity:** `+1/3` gold mine capacity per upgrade (non-cumulative).
	- **Rate:** `+15%` gold mine gold generation per upgrade (non-cumulative).
	- **Income Multiplier:** `+50%` gold per upgrade from monsters and bosses only.
  - **Gold Shop:**
	- **Max HP Upgrade:** upgrades Max HP from `5 → 6 → 7 → 10` (`+1`, `+1`, `+3` on the final upgrade; does not instantly heal).
	- **Spell Scroll:** `100` gold for the 1st, then `+100` per scroll up to 10 (`100..1000`).
	- **Magic Shield (+1 Shield):** `200` gold.
	- **3 HP Healing Potion (30s):** `100` gold.
	- **2× Damage Boost Potion (30s):** `100` gold.
	- **Magnet:** `300` gold (pulls dropped Spell Scrolls, Augmentation Scrolls, Enhancers, and Boss Spell pickups toward the player).
	- **Unlock Auto-Shooting:** `1000` gold (auto-fires at `1/2` fire rate so you can still manually fire; press **`E`** to toggle on/off).
	- **Unlock Homing:** `1500` gold (curves spells toward the closest enemy; press **`F`** to toggle on/off).
	- **Doppelganger:** `5000` gold (copies current abilities, follows you until it dies, has `5` max HP and cannot have a shield).
- **Enemy Scaling, Nests & Bosses:**
  - After **3 minutes**, enemy HP scales every **30 seconds**: unchanged on **Easy**, `+5 HP` linearly on **Medium**, `×1.2` exponentially on **Hard**, and `×1.5` exponentially on **Extreme**.
  - All 4 corner nests have **70 HP**, spawn monsters directly from their center hole, and take damage from player spells via swept-segment hit detection.
  - Each destroyed nest immediately spawns a **Nest Boss** (**80 HP**, **1000 gold** + **1/3 chance** to drop a **Boss Spell**).
  - Destroying all 4 nests awakens the **Mega Boss** (**2000 HP**, **100 HP shield** that regenerates at each 1/4 of HP lost, fires spells at **player base spell speed (`6.0` tiles/sec)**, and spawns bosses every 25 s and normal monsters at **2× their regular rate**).
  - Defeating the Mega Boss wins the run in Normal mode, or in **Endless Mode** drops a **guaranteed 1/1 Mega Boss Spell** (combines all current spells + `1.5×` damage and copies the base spell's augments), spawns **4 new spawners**, and multiplies **everything's HP by 2×**.
