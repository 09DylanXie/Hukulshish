extends SceneTree
## Loads the game the way a real launch does, from the Main Menu, then checks every scene that
## scripts keep in a constant. A preload loop leaves those scenes empty, and instantiate() then
## returns null the first time the game uses one, which no error points to at load time.
## Run with: Godot --headless --path . --script res://tests/load_order_test.gd

var _failures: int = 0
var _checked: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	load("res://scenes/ui/MainMenu.tscn")
	load("res://scenes/main/Game.tscn")
	_check_folder("res://scripts")
	if _checked < 5:
		_failures += 1
		printerr("FAIL: only found %d scene constants" % _checked)
	print("load order test: %d failures (%d scenes checked)" % [_failures, _checked])
	quit(1 if _failures > 0 else 0)


func _check_folder(path: String) -> void:
	for folder: String in DirAccess.get_directories_at(path):
		_check_folder(path.path_join(folder))
	for file_name: String in DirAccess.get_files_at(path):
		if file_name.ends_with(".gd"):
			_check_script(path.path_join(file_name))


func _check_script(path: String) -> void:
	var script: GDScript = load(path)
	var constants: Dictionary = script.get_script_constant_map()
	for constant_name: String in constants:
		if not constants[constant_name] is PackedScene:
			continue
		var scene: PackedScene = constants[constant_name]
		_checked += 1
		if not scene.can_instantiate():
			_failures += 1
			printerr("FAIL: %s.%s is empty" % [path, constant_name])
