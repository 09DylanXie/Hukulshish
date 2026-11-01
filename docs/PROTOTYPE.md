# Playtest Notes

How to try the game quickly. `AGENTS.md` has the full rules.

## Running it

Open the project in **Godot 4.7.2** and press Play, or press F6 on `scenes/main/Game.tscn` to skip the menus (Medium map, Medium difficulty).

**Sandbox** on the Difficulty screen gives infinite gold, scrolls, Enhancers, mana and hotbar items, which is the fastest way to reach later layers.

## What to look at

- **Balance:** every number is a first pass. The most useful feedback is how much gold a full run earns against the `37,400` the Base Spell costs, and how far Augmentation Scrolls stretch.
- **Fire lines:** three burn ticks deal `9 HP`, enough to kill a player without a shield or Max HP upgrades.
- **Lava and darkness:** check that lava isn't too dense and that the Catacombs' vision radius (`7.5` tiles) feels fair.
- **Sound:** every effect is generated, so listen for anything harsh, especially full spell volleys and the fire lines.

## Automated tests

Run any of these headless. Each suite prints its failure count and exits non-zero on failure.

```powershell
& 'C:\path\Godot.exe' --headless --path . --script res://tests/layers/layer_flow_test.gd
```

| Script | Covers |
|---|---|
| `tests/load_order_test.gd` | Every preloaded scene loads when the game starts from the Main Menu |
| `tests/layers/layer_flow_test.gd` | The descent: nest, boss, drops, portal, next layer |
| `tests/layers/overworld_terrain_test.gd` | Overworld generation, rivers, spell blocking |
| `tests/layers/lower_layers_test.gd` | Maze layers, darkness, lava, demon shields |
| `tests/layers/abyss_test.gd` | The final fight, from crystal to white flash |
| `tests/layers/endless_test.gd` | Endless Mode |
| `tests/economy/economy_test.gd` | Upgrades, drops, shops, mines, spell selection, the Doppelganger, homing |
| `tests/spells/unique_spells_test.gd` | Unique spells and status effects |
| `tests/audio/audio_manager_test.gd` | Sound files and call sites |
| `tests/audio/effects_preferences_test.gd` | SFX and Screen Shake sliders |
| `tests/network/coop_mechanics_test.gd` | Co-op rules |
| `tests/network/lobby_smoke_test.gd` | The multiplayer lobby |
| `tests/network/run_coop_live.sh` | A real three-player game across three processes (run it with `bash`, passing the path to Godot) |

The audio and co-op suites can print `ObjectDB instances were leaked` at exit. That only means a sound was still playing when the test quit.
