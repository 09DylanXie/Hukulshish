extends SceneTree
## One real player process in a co-op game over a local connection. Run three at once with
## tests/network/run_coop_live.sh, or see coop_live_suite.gd for what each one does.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var suite: Node = load("res://tests/network/coop_live_suite.gd").new()
	root.add_child(suite)
