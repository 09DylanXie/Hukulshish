class_name SpellData
extends Resource
## One player spell or spell mod (AGENTS.md §6.2–6.3).

@export var name: String = ""
@export var speed_tiles: float = 1.0
## Only used for spells with fixed damage. The base spell uses Config.SPELL_DAMAGE_BY_LEVEL,
## and mods copy the base damage when applied.
@export var damage: int = 1
## Shots per second.
@export var fire_rate: float = 1.0
@export var color: Color = Color.WHITE
@export var radius_tiles: float = 0.2
## Optional custom projectile scene. Leave empty to use the generic Projectile scene.
@export var projectile_scene: PackedScene
