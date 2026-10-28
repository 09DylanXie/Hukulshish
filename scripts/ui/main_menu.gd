extends Control
## Main Menu: Start, Quit Game (§3). Quit is hidden on the web build (quit() does nothing there).


func _ready() -> void:
	var box: VBoxContainer = UIKit.make_centered_menu(self, "Hukulshish", "Defend the kingdom. Destroy the four nests.")
	var start: Button = UIKit.make_button("Start", func() -> void: SceneRouter.goto(SceneRouter.MAP_SIZE_SELECT))
	box.add_child(start)
	if OS.has_feature("web"):
		box.add_child(UIKit.make_label("Thanks for playing!", 18, Color(0.7, 0.7, 0.8)))
	else:
		box.add_child(UIKit.make_button("Quit Game", func() -> void: get_tree().quit()))
	box.add_child(UIKit.make_label("WASD to move • left-click to shoot • walk into the castle to shop & upgrade", 16, Color(0.6, 0.6, 0.7)))
