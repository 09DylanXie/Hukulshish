extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.add_child(load("res://tests/audio/effects_preferences_suite.gd").new())
