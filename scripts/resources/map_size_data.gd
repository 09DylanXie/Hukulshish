class_name MapSizeData
extends Resource
## One map size option (AGENTS.md §3). The map is square.

@export var name: String = ""
## TODO(design): tile counts per size are undefined (§9 Q5).
@export var size_in_tiles: int = 60
## Optional hand-made map scene. Leave empty to use the generated prototype map.
@export var scene: PackedScene
