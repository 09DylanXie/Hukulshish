extends Control
## Difficulty Select: Easy, Medium, Hard, Extreme, plus Endless Mode & Sandbox Mode (§3).
## In Endless Mode, defeating the Mega Boss spawns 4 new spawners and multiplies everything's HP by 2×.
## In Sandbox Mode, all resources (Gold, Spell Scrolls, Augmentation Scrolls, Enhancers, Mana, Shields & Potions) are infinite.

var _endless_toggle: Button


func _ready() -> void:
	GameState.endless_mode = false
	GameState.sandbox_mode = false
	var box: VBoxContainer = UIKit.make_centered_menu(self, "Difficulty")
	for d in Config.DIFFICULTIES:
		var data: DifficultyData = d
		var b: Button = UIKit.make_button("%s  (monster HP ×%s)" % [data.name, str(data.hp_mult)], _choose.bind(data, false, false))
		box.add_child(b)

	var endless_btn: Button = UIKit.make_button(
		"Endless  (4 new spawners + ×2 HP per Mega Boss)",
		_choose.bind(Config.DIFFICULTIES[1], true, false)
	)
	box.add_child(endless_btn)

	var sandbox_btn: Button = UIKit.make_button(
		"Sandbox  (All Resources Infinite)",
		_choose.bind(Config.DIFFICULTIES[1], false, true)
	)
	box.add_child(sandbox_btn)

	_endless_toggle = UIKit.make_button("", _toggle_endless, 18)
	box.add_child(_endless_toggle)
	_refresh_toggle_text()

	box.add_child(UIKit.make_button("Back", func() -> void: SceneRouter.goto(SceneRouter.MAP_SIZE_SELECT), 20))


func _toggle_endless() -> void:
	GameState.endless_mode = not GameState.endless_mode
	_refresh_toggle_text()


func _refresh_toggle_text() -> void:
	if _endless_toggle != null:
		var state_str: String = "ON (4 new spawners + ×2 HP after Mega Boss)" if GameState.endless_mode else "OFF"
		_endless_toggle.text = "Endless Mode Modifier: %s" % state_str


func _choose(data: DifficultyData, force_endless: bool, force_sandbox: bool) -> void:
	GameState.difficulty = data
	if force_endless:
		GameState.endless_mode = true
	GameState.sandbox_mode = force_sandbox
	SceneRouter.goto(SceneRouter.GAME)
