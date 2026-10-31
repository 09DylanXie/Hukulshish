extends Node

var _failures: int = 0


func _check(passed: bool, message: String) -> void:
	if not passed:
		_failures += 1
		push_error(message)


func _ready() -> void:
	var original_path: String = Config._preferences_path
	var original_volume: float = Config.sfx_volume
	var original_shake: float = Config.screen_shake_strength
	Config._preferences_path = "res://.godot/effects_preferences_test.cfg"
	var hud: HUD = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child(hud)
	hud.call("_set_paused", true)
	var volume: HSlider = hud.find_child("SFXVolume", true, false) as HSlider
	var shake: HSlider = hud.find_child("ScreenShake", true, false) as HSlider
	_check(volume != null and shake != null, "Pause menu must expose both sliders")
	volume.value = 37.0
	var bus: int = AudioServer.get_bus_index(&"SFX")
	_check(is_equal_approx(Config.sfx_volume, 0.37), "Paused slider did not update SFX volume")
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.37), "SFX bus gain does not match slider")
	AudioManager.start_loop("fire_loop")
	for player: AudioStreamPlayer in AudioManager._pool:
		_check(player.bus == &"SFX", "A one-shot bypasses the SFX volume control")
	_check((AudioManager._loop_players["fire_loop"] as AudioStreamPlayer).bus == &"SFX", "Fire loop bypasses SFX volume")
	volume.value = 0.0
	_check(AudioServer.is_bus_mute(bus), "Zero volume must fully mute active SFX")
	volume.value = 37.0
	_check(not AudioServer.is_bus_mute(bus), "Raising volume must unmute SFX")
	var player: Player = load("res://scenes/player/Player.tscn").instantiate()
	add_child(player)
	player.call("_on_screen_shake_requested", 10.0, 1.0)
	var camera: Camera2D = player.get("_camera")
	camera.offset = Vector2(6.0, 6.0)
	shake.value = 0.0
	_check(camera.offset == Vector2.ZERO and float(player.get("_shake_timer")) == 0.0, "Disabling shake while paused must clear the current effect")
	player.call("_on_screen_shake_requested", 10.0, 1.0)
	_check(float(player.get("_shake_timer")) == 0.0, "Disabled shake must ignore new fire/hit effects")
	shake.value = 25.0
	Config.sfx_volume = 1.0
	Config.screen_shake_strength = 1.0
	Config.load_preferences()
	_check(is_equal_approx(Config.sfx_volume, 0.37) and is_equal_approx(Config.screen_shake_strength, 0.25), "Saved preferences must survive reloading")
	GameState.start_run()
	_check(is_equal_approx(Config.sfx_volume, 0.37) and is_equal_approx(Config.screen_shake_strength, 0.25), "Restarting a run must preserve player preferences")
	AudioManager.stop_loop("fire_loop")
	hud.call("_set_paused", false)
	Config._preferences_path = original_path
	Config.sfx_volume = original_volume
	Config.screen_shake_strength = original_shake
	hud.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("Effects preferences: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
