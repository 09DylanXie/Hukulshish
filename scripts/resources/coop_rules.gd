class_name CoopRules
extends Resource
## Approved co-op balance data. The host owns all revive timers and purchases.

@export var player_count: int = 3
@export var monster_hp_multiplier: float = 2.0
@export var boss_hp_multiplier: float = 5.0
@export var revival_unlock_cost: int = 999
@export var revival_interaction_seconds: float = 3.0
@export var revival_respawn_seconds: float = 5.0
@export var revival_restored_hp: int = 5
