class_name SpellData
extends Resource
## Base stats + look for a player spell (AGENTS.md §6.2–6.3).
## Mods multiply these at runtime; unique spells copy the base spell when picked up (§6.4).

## What a spell does to the enemy it hits.
enum Effect {
	NONE,
	SLOW,
	STUN,
	POISON,
	EXPLODE,
	CORRUPTION,
}

@export var name: String = ""
@export var speed_tiles: float = 6.0
## Max travel distance (also the auto-aim range).
@export var range_tiles: float = 10.0
## Only used for spells with fixed damage. The base spell uses Config.SPELL_DAMAGE_BY_LEVEL.
@export var damage: int = 1
## Shots per second.
@export var fire_rate: float = 1.0
@export var color: Color = Color.WHITE
@export var radius_tiles: float = 0.2
## Unique spells only: multiplies the base spell's damage at pickup.
@export var damage_mult: float = 1.0
@export var effect: Effect = Effect.NONE
@export var can_home: bool = true
@export var cast_sound: String = "cast_base"
@export_file("*.png") var pickup_texture: String = ""
## Optional custom projectile scene. Leave empty to use the generic Projectile scene.
@export var projectile_scene: PackedScene
