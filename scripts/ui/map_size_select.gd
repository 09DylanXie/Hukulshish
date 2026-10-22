extends Control
## Map Size Select: Small, Medium, Large (§3).


func _ready() -> void:
	var box: VBoxContainer = UIKit.make_centered_menu(self, "Map Size")
	var first: Button = null
	for map in Config.MAP_SIZES:
		var data: MapSizeData = map
		var b: Button = UIKit.make_button("%s  (%d×%d)" % [data.name, data.size_in_tiles, data.size_in_tiles], _choose.bind(data))
		box.add_child(b)
		if first == null:
			first = b
	box.add_child(UIKit.make_button("Back", func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU), 20))
	first.grab_focus.call_deferred()


func _choose(data: MapSizeData) -> void:
	GameState.map_size = data
	SceneRouter.goto(SceneRouter.DIFFICULTY_SELECT)

