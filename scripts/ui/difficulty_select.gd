extends Control
## Difficulty Select: Easy, Medium, Hard, Extreme, plus Endless Mode (§3).
## In Endless Mode, defeating the Mega Boss spawns 4 new spawners and multiplies everything's HP by 2×.

var _endless_toggle: Button


func _ready() -> void:
	GameState.endless_mode = false
	var box: VBoxContainer = UIKit.make_centered_menu(self, "Difficulty")
	for d in Config.DIFFICULTIES:
		var data: DifficultyData = d
		var b: Button = UIKit.make_button("%s  (monster HP ×%s)" % [data.name, str(data.hp_mult)], _choose.bind(data, false))
		box.add_child(b)

	var endless_btn: Button = UIKit.make_button(
		"Endless  (4 new spawners + ×2 HP per Mega Boss)",
		_choose.bind(Config.DIFFICULTIES[1], true)
	)
	box.add_child(endless_btn)

	_endless_toggle = UIKit.make_button("", _toggle_endless, 18)
	_refresh_toggle_text()
	box.add_child(_endless_toggle)

	box.add_child(UIKit.make_button("Back", func() -> void: SceneRouter.goto(SceneRouter.MAP_SIZE_SELECT), 20))


func _toggle_endless() -> void:
	GameState.endless_mode = not GameState.endless_mode
	_refresh_toggle_text()


func _refresh_toggle_text() -> void:
	if _endless_toggle == null:
		return
	var state_str: String = "ON (4 new spawners + ×2 HP after Mega Boss)" if GameState.endless_mode else "OFF"
	_endless_toggle.text = "Endless Mode Modifier: %s" % state_str


func _choose(data: DifficultyData, force_endless: bool) -> void:
	GameState.difficulty = data
	if force_endless:
		GameState.endless_mode = true
	SceneRouter.goto(SceneRouter.GAME)
