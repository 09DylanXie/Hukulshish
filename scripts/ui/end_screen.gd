extends Control
## Shared Victory / Game Over screen. `is_victory` is set in each scene.

@export var is_victory: bool = false


func _ready() -> void:
	var title: String = "Victory!" if is_victory else "Game Over"
	var sub: String = "The kingdom is safe." if is_victory else "Hukulshish has fallen."
	var box: VBoxContainer = UIKit.make_centered_menu(self, title, sub)
	box.add_child(UIKit.make_label("Nests destroyed: %d / 4    Bosses defeated: %d / 4" % [GameState.nests_destroyed, GameState.bosses_defeated], 18))
	box.add_child(UIKit.make_label("Spell level: %d    Gold: %d" % [GameState.spell_level, GameState.gold], 18))
	var again: Button = UIKit.make_button("Play Again", func() -> void: SceneRouter.goto(SceneRouter.MAP_SIZE_SELECT))
	box.add_child(again)
	box.add_child(UIKit.make_button("Main Menu", func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU)))
	again.grab_focus.call_deferred()
