extends SceneTree
## Run with --headless --path . --script res://tests/network/lobby_smoke_test.gd
## Uses real autoloads and UI construction, without requiring a native WebRTC extension.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://scenes/ui/MainMenu.tscn")
	var menu: Control = scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.call("_open_multiplayer")
	await process_frame
	var lobby: Control = menu.get_node("WebRTCLobby")
	if lobby.get_node_or_null("Session") == null:
		push_error("Lobby did not create its session.")
		quit(1)
		return
	lobby.call("_on_joined", "LOCAL123", 1)
	await process_frame
	lobby.call("_leave")
	lobby.queue_free()
	await process_frame
	menu.call("_open_multiplayer")
	await process_frame
	if menu.get_node_or_null("WebRTCLobby") == null:
		push_error("Lobby could not reopen after leaving.")
		quit(1)
		return
	print("PASS: lobby opens, draws, leaves, and reopens with project autoloads")
	quit()
