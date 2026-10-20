class_name MonsterStats
extends Resource
## Stats for one monster class (AGENTS.md §6.5).

@export var name: String = ""
@export var hp: int = 1
@export var damage: int = 1
## Speed as a multiple of the player's speed.
@export var speed_mult: float = 1.0
@export var spawn_interval: float = 5.0
@export var gold: int = 1
## Prototype visuals (placeholder until real art exists).
@export var color: Color = Color.WHITE
@export var radius_tiles: float = 0.4
## Optional custom scene. Leave empty to use the generic Monster scene.
@export var scene: PackedScene
