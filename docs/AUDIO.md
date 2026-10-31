# Audio

Every sound effect in `assets/audio/sfx/` is synthesized by `tools/generate_sfx.py`,
so they are original to this project and carry no third-party license. There is no music yet.

## Regenerating sounds

Requires Python 3 and nothing else.

```powershell
python tools/generate_sfx.py            # everything
python tools/generate_sfx.py boss_hit   # one sound
python tools/generate_sfx.py --report   # also print length and level statistics
```

Open the project in Godot afterwards so the files are re-imported.

## Replacing a sound

Overwrite the `.wav` with one of the same name, then open Godot. If the new file is
quieter or louder than its neighbors, change its `db` in the `SOUNDS` table in
`scripts/autoload/audio_manager.gd`.

A replaced file is lost the next time every sound is regenerated, so run the generator
with specific names once any sound in the folder has been swapped for an external one.
Record the source and license of external sounds in this file.

## Adding a sound

1. Add a recipe to `tools/generate_sfx.py`, or drop a `.wav` into `assets/audio/sfx/`.
2. Add its name to `SOUNDS` in `audio_manager.gd`.
3. Call it from gameplay code:
   - `AudioManager.play("name")` for things the player should always hear.
   - `AudioManager.play_at("name", global_position)` for things in the world.
     It gets quieter with distance from the camera.

`tests/audio/audio_manager_test.gd` fails on a misspelled sound name or a missing file:

```powershell
& 'C:\path\Godot.exe' --headless --path . --script res://tests/audio/audio_manager_test.gd
```

## Good to know

- The pause menu's **SFX volume** slider controls the runtime `SFX` audio bus,
  including active one-shots and fire loops. Zero fully mutes the bus. The
  **Screen shake** slider controls camera movement from fire, damage and other
  effects. Both settings are saved in `user://preferences.cfg` and survive runs.

- Files named `<sound>_1.wav`, `<sound>_2.wav` are variants, and one is picked at random.
- `gap` in `SOUNDS` limits how often a sound can repeat. It stops rapid fire and burn
  ticks from stacking into a single loud noise.
- `fire_loop.wav` stores its loop points inside the file, and Godot's importer reads them.
  An editor that drops the `smpl` chunk will stop it looping.
- Co-op sound only runs on the host for now, because guests do not simulate the world yet.
  Once snapshots reach guests, they will need to trigger sounds from those events.
