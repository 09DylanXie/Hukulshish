extends Node
## Menu → game → end-screen transitions (autoload "SceneRouter").

const MAIN_MENU: String = "res://scenes/ui/MainMenu.tscn"
const MAP_SIZE_SELECT: String = "res://scenes/ui/MapSizeSelect.tscn"
const DIFFICULTY_SELECT: String = "res://scenes/ui/DifficultySelect.tscn"
const GAME: String = "res://scenes/main/Game.tscn"
const GAME_OVER: String = "res://scenes/ui/GameOver.tscn"
const VICTORY: String = "res://scenes/ui/Victory.tscn"


func goto(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)

