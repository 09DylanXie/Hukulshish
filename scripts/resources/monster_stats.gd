class_name MonsterStats
extends Resource
## Stats for one monster class (AGENTS.md §6.5).
## Speed isn't stored here: it's derived from size (Config.monster_speed_tiles).

@export var name: String = ""
@export var hp: int = 1
@export var damage: int = 1
@export var spawn_interval: float = 5.0
@export var gold: int = 1
## Size in tiles. Bigger = slower.
@export var radius_tiles: float = 0.4
## Prototype visuals (placeholder until real art exists).
@export var color: Color = Color.WHITE
## Optional custom scene. Leave empty to use the generic Monster scene.
@export var scene: PackedScene
