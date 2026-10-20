extends Control
## Difficulty Select: Easy, Medium, Hard, Extreme (§3). Multiplies monster HP.


func _ready() -> void:
	var box: VBoxContainer = UIKit.make_centered_menu(self, "Difficulty")
	var first: Button = null
	for d in Config.DIFFICULTIES:
		var data: DifficultyData = d
		var b: Button = UIKit.make_button("%s  (monster HP ×%s)" % [data.name, str(data.hp_mult)], _choose.bind(data))
		box.add_child(b)
		if first == null:
			first = b
	box.add_child(UIKit.make_button("Back", func() -> void: SceneRouter.goto(SceneRouter.MAP_SIZE_SELECT), 20))
	first.grab_focus.call_deferred()


func _choose(data: DifficultyData) -> void:
	GameState.difficulty = data
	SceneRouter.goto(SceneRouter.GAME)
