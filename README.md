# Hukulshish

A 2D top-down survival / base-defense game made in **Godot 4**, published on **itch.io**.
Play as the mage Hukulshish, defend the kingdom castle, and destroy the four monster nests.

## Godot version

> **Both collaborators must use exactly: `Godot 4.x.x stable` (standard, not .NET)**
> ⚠️ Fill in the exact version (e.g. `4.5.1`) the first time you open the project, and only change it together.

## Getting started

```bash
git clone https://github.com/<owner>/hukulshish.git
```
Open Godot → **Import** → select `project.godot`.

## Docs

- [`AGENTS.md`](AGENTS.md) — game design source of truth + rules for AI coding agents
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — Git workflow for the two of us (read first!)

## Building for itch.io

Project → Export → **Web** → export to `export/web/index.html`, zip the contents of `export/web/`, upload to itch.io as an HTML project. (Build output is git-ignored.)
