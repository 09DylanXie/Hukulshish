# Contributing — 2-Person Workflow

Read this before your first commit. The goal: **never lose work, never fight merge conflicts.**

## 0. One-time setup (each person)

1. Install the **exact same Godot version** (see `README.md` → *Godot version*). Mismatched versions rewrite `.tscn` / `project.godot` files and cause conflicts.
2. Set your Git identity:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```
3. Clone the repo, open `project.godot` in Godot once (it builds the local `.godot/` cache — that folder is git-ignored on purpose).

## 1. Branching — never commit directly to `main`

```
main            ← always playable, protected
 └─ feature/player-movement
 └─ feature/main-menu
 └─ fix/goblin-speed
```

Daily loop:
```bash
git checkout main
git pull                              # get partner's latest work
git checkout -b feature/short-name    # new branch per task
# ...work, commit often...
git add -A
git commit -m "Add WASD movement to player"
git push -u origin feature/short-name
```
Then open a **Pull Request** on GitHub → partner reviews → **Squash and merge** → delete the branch.

Before opening a PR, update your branch with the latest `main`:
```bash
git fetch origin
git merge origin/main     # resolve any conflicts locally, test, then push
```

## 2. Avoiding Godot merge conflicts (most important section)

`.tscn` scene files are text but **merge badly**. Two people editing the same scene at the same time = pain.

- **Claim before you edit.** Post in your chat / GitHub Issue: *"I'm working on `scenes/player/Player.tscn`."* Only one person edits a given `.tscn` at a time.
- **Small scenes.** Every feature is its own scene (Player, Goblin, Nest, HUD…). The main/world scene should mostly just *instance* other scenes, so it rarely needs editing.
- **Logic goes in `.gd` scripts, not in scene-embedded scripts.** Scripts merge much more cleanly than scenes.
- **Balance numbers go in `resources/*.tres`** (or the `Config` autoload), one file per monster/spell, so tuning one doesn't conflict with another.
- **`project.godot` is shared and fragile.** Changes to Input Map, autoloads, or project settings: do them in a small dedicated PR and tell your partner to pull right after.
- **Always commit `.import` and `.uid` files** together with their asset/script. Never delete them manually.
- **Moving/renaming files: do it inside Godot's FileSystem dock**, never in Explorer/Finder — Godot updates references. Commit the move on its own.
- If a `.tscn` conflict happens: don't hand-merge. Keep one version (`git checkout --theirs` or `--ours`), then re-apply the other person's changes in the editor.

## 3. Suggested ownership split

Agree on rough areas so you rarely touch the same files:

| Person A | Person B |
|---|---|
| Player, spells, castle upgrades | Monsters, nests, bosses, spawning |
| | UI / menus (shared — coordinate) |

Shared files needing coordination: `project.godot`, `scripts/autoload/*`, `scenes/main/*`, `scenes/world/*`, `AGENTS.md`.

## 4. Commit & PR rules

- Commit messages: imperative, short — `Add goblin spawner`, `Fix boss projectile speed`.
- One feature/fix per PR. Keep PRs small (easier to review, fewer conflicts).
- The game must **run without errors** before merging into `main`.
- Design changes (numbers, mechanics) → update `AGENTS.md` in the same PR.

## 5. Assets

- Put raw art/audio only under `assets/`. Use lowercase `snake_case` file names (no spaces — they break web exports on some servers).
- Source files (`.psd`, `.aseprite`) are fine to commit but keep them small. If the repo gets big, enable Git LFS (see `.gitattributes`).
