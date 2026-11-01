class_name DamageDummy
extends Node
## Stands in for an enemy in tests and adds up the damage it receives.

var damage: float = 0.0


func take_damage(amount: float) -> void:
	damage += amount
