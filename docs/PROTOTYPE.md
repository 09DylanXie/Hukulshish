# Prototype Notes

First playable prototype of Normal mode (milestones 1–9 from `AGENTS.md` §8), built for **Godot 4.7.2**.
All visuals are placeholder shapes drawn in code (`_draw()`), so no art assets are needed yet.

## How to play

- **Start → Map Size → Difficulty**, then the run begins.
- **WASD / arrow keys** to move. On touch devices, drag on the left half of the screen (virtual joystick).
- Spells fire automatically at the nearest monster, boss or nest in range.
- Walk **out of and back into the castle** to open the upgrade menu (the game pauses). `Esc` or *Leave Castle* closes it.
- Destroyed nests have a 1-in-3 chance to drop a spell mod (glowing diamond). Pick it up, then apply it at the castle.
- Win by destroying all 4 nests **and** the 4 bosses that appear 20 s later. Lose if your HP reaches 0.

## Code map

| Piece | Scene | Script |
|---|---|---|
| Autoloads | — | `scripts/autoload/config.gd`, `game_state.gd`, `scene_router.gd` |
| Data classes | — | `scripts/resources/*.gd` (`MonsterStats`, `SpellData`, `DifficultyData`, `MapSizeData`) |
| Balance data | — | `resources/{monsters,spells,difficulty,maps}/*.tres` |
| Menus | `scenes/ui/MainMenu.tscn`, `MapSizeSelect`, `DifficultySelect`, `GameOver`, `Victory` | `scripts/ui/*.gd` (built with `UIKit`) |
| Run root | `scenes/main/Game.tscn` | `scripts/main/game.gd` |
| Map | `scenes/world/World.tscn` | `scripts/world/world.gd` |
| Player | `scenes/player/Player.tscn` | `scripts/player/player.gd`, `scripts/spells/spell_caster.gd` |
| Spells | `scenes/spells/Projectile.tscn`, `ModPickup.tscn` | `scripts/spells/*.gd` |
| Monsters / nests / bosses | `scenes/monsters/Monster.tscn`, `scenes/nests/Nest.tscn`, `scenes/bosses/NestBoss.tscn` | matching `scripts/` folders |
| Castle | `scenes/castle/Castle.tscn` | `scripts/castle/castle.gd` |
| HUD / castle menu / joystick | `scenes/ui/HUD.tscn`, `CastleMenu.tscn`, `VirtualJoystick.tscn` | `scripts/ui/*.gd` |

Scenes are just a root node + script; children (collision shapes, camera, UI) are built in code so the
`.tscn` files almost never change → fewer merge conflicts.

## Placeholder values (answers needed — AGENTS.md §9)

Every one of these is a `# TODO(design)` constant in `scripts/autoload/config.gd` or a `.tres` file.

| Question | Placeholder used |
|---|---|
| Q1 Upgrade cost | `5 × 2^(level−1)` gold (5, 10, 20, 40 …) |
| Q2 Magic Missile stats | 2 tiles/sec, 1 shot/sec, copies base damage |
| Q3 Level 7 damage | +2 step (1, 3, 5, 7, 9, 11, 13, 18, 23) |
| Q4 Difficulty scope / rounding | Monsters only; HP rounded **up** |
| Q5 Map sizes | Small 40, Medium 60, Large 80 tiles |
| Q6 Fire rates | Base spell & mods 1 shot/sec; boss bolt every 2 s |
| Q7 Melee / i-frames | Monster attack cooldown 1 s; player i-frames 0.5 s |
| Q8 Boss | 0.5× player speed, aims at player, drops 10 gold |
| Q9 Nest → monster | One class per nest (TL Goblin, TR Undead, BL Ogre, BR Demon) |
| Q10 Castle interaction | Walk in (after leaving once) |
| — Auto-aim range | 10 tiles (nests are valid targets too) |
| — Projectile lifetime | 12 s |
| — Max alive per nest | 25 (performance cap) |
| — Camera zoom | 2× |

> Note: the spec's speeds (player and spells 1 tile/sec) feel quite slow in play. They're kept as written —
> tune `PLAYER_SPEED_TILES` / spell `speed_tiles` if you want a faster pace.
