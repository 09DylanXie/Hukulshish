class_name SpellData
extends Resource
## Base stats + look for a player spell (AGENTS.md §6.2–6.3).
## Mods multiply these at runtime; boss spells copy the base spell when picked up.

@export var name: String = ""
@export var speed_tiles: float = 5.0
## Max travel distance (also the auto-aim range).
@export var range_tiles: float = 10.0
## Only used for spells with fixed damage. The base spell uses Config.SPELL_DAMAGE_BY_LEVEL.
@export var damage: int = 1
## Shots per second.
@export var fire_rate: float = 1.0
@export var color: Color = Color.WHITE
@export var radius_tiles: float = 0.2
## Optional custom projectile scene. Leave empty to use the generic Projectile scene.
@export var projectile_scene: PackedScene
