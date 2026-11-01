extends Control
## Shared Victory / Game Over screen. `is_victory` is set in each scene.

@export var is_victory: bool = false


func _ready() -> void:
	AudioManager.play_music("victory" if is_victory else "game_over")
	var title: String = "Victory!" if is_victory else "Game Over"
	var sub: String = "The dragon is slain and the kingdom is safe." if is_victory else "Hukulshish has fallen."
	var box: VBoxContainer = UIKit.make_centered_menu(self, title, sub)
	box.add_child(UIKit.make_label("Nests destroyed: %d / %d    Bosses defeated: %d" % [GameState.nests_destroyed, Config.NESTS_PER_LAYER * (Config.LAYERS.size() - 1), GameState.bosses_defeated], 18))
	box.add_child(UIKit.make_label("Spell level: %d    Unique spells: %d    Gold: %d" % [GameState.spell_level, GameState.unique_spells.size(), GameState.gold], 18))
	if is_victory:
		for line: String in Config.CREDITS:
			box.add_child(UIKit.make_label(line, 16, Color(0.85, 0.82, 0.95)))
		box.add_child(UIKit.make_label("Music", 16, Color(0.95, 0.8, 0.3)))
		var music_credits := GridContainer.new()
		music_credits.columns = 2
		music_credits.add_theme_constant_override("h_separation", 32)
		for line: String in Config.MUSIC_CREDITS:
			music_credits.add_child(UIKit.make_label(line, 14, Color(0.85, 0.82, 0.95)))
		box.add_child(music_credits)
	if not Coop.in_run:
		box.add_child(UIKit.make_button("Play Again", func() -> void: SceneRouter.goto(SceneRouter.MAP_SIZE_SELECT)))
	box.add_child(UIKit.make_button("Main Menu", func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU)))
