extends SceneTree
## Load the suite after project autoloads have been initialized.
## Run with: Godot --headless --path . --script res://tests/spells/unique_spells_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var suite: Node = load("res://tests/spells/unique_spells_suite.gd").new()
	root.add_child(suite)
