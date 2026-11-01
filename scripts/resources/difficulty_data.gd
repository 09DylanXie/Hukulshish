class_name DifficultyData
extends Resource
## One difficulty option (AGENTS.md §3).

@export var name: String = ""
@export var hp_mult: float = 1.0
## Monster and nest HP multiplier that compounds with every descent.
@export var hp_growth_per_layer: float = 1.5

