# Prototype Notes

Playable prototype of Normal mode (built for **Godot 4.7.2**).
All visuals are placeholder shapes drawn in code (`_draw()`), so no art assets are needed yet.

## How to play

- **Start → Map Size → Difficulty**, then the run begins on a freshly generated spacious maze map.
- **WASD / arrow keys** to move (`2.5` tiles/sec). On touch devices, drag on the left half of the screen (virtual joystick).
- Spells move at **2× player speed (`5.0` tiles/sec)** and fire automatically at the nearest monster, boss, or nest in range.
- **Gold Mines:** 2 gold mines spawn in random regions of the map, each generating **10 gold/sec** up to **500 gold**. Walk over a mine to collect its stored gold.
- **Castle Shop & Heal:** walk out of and back into the castle to heal up to **7/10 of max HP** (never above 7/10) and open the upgrade menu (pauses the game).
  - Spend **Gold** to upgrade the Base Spell level (Lv 1–9).
  - Spend **Mod Parts** (1/7 drop from monsters) to upgrade Base Spell **Damage**, **Fire Rate**, **Spell Speed**, or **Range** (+0.1× per level; costs `1, 2, 3, 4`, then `8, 16, 32, …`).
- **Nests & Bosses:**
  - All 4 corner nests have **20 HP** and can be targeted and destroyed by player spells.
  - Each destroyed nest spawns a **Nest Boss** 20 s later, which drops **1000 gold** and has a **1/3 chance** to drop a **Boss Spell** pickup (first boss spell doubles base spell damage at 2/3 fire rate; subsequent boss spells sum the damage of all existing player spells without reducing fire rate by 1/3 again).
  - Destroying all 4 nests awakens the **Mega Boss** (**1000 HP**, spawns a boss every 50 s and normal monsters at their regular intervals). Defeating the Mega Boss wins the run.

## Code map

| Piece | Scene | Script |
|---|---|---|
| Autoloads | — | `scripts/autoload/config.gd`, `game_state.gd`, `scene_router.gd` |
| Data classes | — | `scripts/resources/*.gd` (`MonsterStats`, `SpellData`, `DifficultyData`, `MapSizeData`) |
| Balance data | — | `resources/{monsters,spells,difficulty,maps}/*.tres` |
| Menus | `scenes/ui/MainMenu.tscn`, `MapSizeSelect`, `DifficultySelect`, `GameOver`, `Victory` | `scripts/ui/*.gd` (built with `UIKit`) |
| Run root | `scenes/main/Game.tscn` | `scripts/main/game.gd` |
| Map + Maze + Mines | `scenes/world/World.tscn`, `GoldMine.tscn` | `scripts/world/world.gd`, `gold_mine.gd` |
| Player | `scenes/player/Player.tscn` | `scripts/player/player.gd`, `scripts/spells/spell_caster.gd` |
| Spells & Pickups | `scenes/spells/Projectile.tscn`, `ModPickup.tscn` | `scripts/spells/*.gd` |
| Monsters / Nests / Bosses | `scenes/monsters/Monster.tscn`, `scenes/nests/Nest.tscn`, `scenes/bosses/NestBoss.tscn`, `MegaBoss.tscn` | matching `scripts/` folders |
| Castle | `scenes/castle/Castle.tscn` | `scripts/castle/castle.gd` |
| HUD / Castle Menu / Joystick | `scenes/ui/HUD.tscn`, `CastleMenu.tscn`, `VirtualJoystick.tscn` | `scripts/ui/*.gd` |
