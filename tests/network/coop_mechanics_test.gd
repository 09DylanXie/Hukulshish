extends SceneTree
## Load the suite after project autoloads have been initialized.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var suite: Node = load("res://tests/network/coop_mechanics_suite.gd").new()
	root.add_child(suite)
