class_name LayerData
extends Resource
## One floor of the descent (AGENTS.md §6.6). Layers are listed in order in Config.LAYERS.

enum Terrain {
	MAZE,
	WILDS,
	ABYSS,
}

@export var name: String = ""
@export var terrain: Terrain = Terrain.MAZE
## The class spawned by this layer's nest. Empty on the final layer, which has no nest.
@export var monster: MonsterStats
## The unique spell hidden somewhere on this layer.
@export var unique_spell: SpellData
@export_file("*.png") var floor_texture: String = "res://assets/tilesets/ground_tile.png"
## Walls cycle through these textures.
@export var wall_textures: Array[String] = ["res://assets/tilesets/wall_tile.png"]
## Fills the void outside the map.
@export var backdrop_color: Color = Color(0.1, 0.15, 0.09)
@export var maze_cell_tiles: int = 5
## How many maze walls are knocked out to make loops. Lower feels more like a labyrinth.
@export var maze_opening_chance: float = 0.35
@export var has_graves: bool = false
@export var has_lava: bool = false
## Harmless cracks drawn across the floor. Fully transparent means none.
@export var floor_crack_color: Color = Color.TRANSPARENT
@export var has_darkness: bool = false
@export var has_castle: bool = false
@export var has_gold_mines: bool = false
@export var has_shop: bool = true
## The final layer: the player spawns at the bottom and the Mega Boss waits at the center.
@export var is_final: bool = false
