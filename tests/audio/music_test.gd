extends SceneTree
## Run with: Godot --headless --path . --script res://tests/audio/music_test.gd

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(passed: bool, message: String) -> void:
	if not passed:
		_failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	var music: Node = audio.music
	_check_every_track_loads(music)
	_check_bus(audio, music)
	_check_looping(audio, music)
	await _check_crossfade(audio, music)
	_check_endless_chain(audio, music)
	print("music test: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


func _check_every_track_loads(music: Node) -> void:
	for track: String in music.TRACKS:
		var settings: Dictionary = music.TRACKS[track]
		var files: Array[String] = [String(settings.get("file", track))]
		if settings.has("then"):
			files.append(String(settings["then"]))
		for file: String in files:
			var stream: AudioStreamMP3 = music._load(file)
			_check(stream != null and stream.get_length() > 0.0, "%s failed to load" % file)
			if stream != null:
				print("%s: %d sec" % [file, roundi(stream.get_length())])


func _check_bus(audio: Node, music: Node) -> void:
	var config: Node = root.get_node("Config")
	var bus: int = AudioServer.get_bus_index(music.MUSIC_BUS)
	_check(bus >= 0, "The Music bus must exist")
	var sfx_before: float = config.sfx_volume
	config.music_volume = 0.25
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.25), "Music bus must follow its slider")
	_check(is_equal_approx(config.sfx_volume, sfx_before), "The Music slider must leave SFX alone")
	config.music_volume = 0.0
	_check(AudioServer.is_bus_mute(bus), "Music at 0% must be muted")
	config.music_volume = 1.0
	_check(not AudioServer.is_bus_mute(bus), "Music must unmute")
	audio.play_music("menu")


func _active(music: Node) -> AudioStreamPlayer:
	return music._players[music._active]


func _check_looping(audio: Node, music: Node) -> void:
	audio.play_music("overworld")
	_check((_active(music).stream as AudioStreamMP3).loop, "Layer tracks must loop")
	var stream: AudioStream = _active(music).stream
	audio.play_music("overworld")
	_check(_active(music).stream == stream, "The same track must not restart")
	audio.play_music("victory")
	_check(not (_active(music).stream as AudioStreamMP3).loop, "Victory plays once")
	audio.play_music("game_over")
	_check(not (_active(music).stream as AudioStreamMP3).loop, "Game Over plays once")


func _check_crossfade(audio: Node, music: Node) -> void:
	audio.play_music("catacombs")
	var outgoing: AudioStreamPlayer = music._players[1 - music._active]
	await create_timer(music.FADE_SEC + 0.3).timeout
	_check(not outgoing.playing, "The old track must stop after the fade")
	_check(is_equal_approx(_active(music).volume_db, music.DEFAULT_DB), "The new track must reach full level")
	# A fade cut off by another request must still finish properly.
	audio.play_music("abyss")
	audio.play_music("dragon")
	await create_timer(music.FADE_SEC + 0.3).timeout
	_check(_active(music).playing and (_active(music).stream as AudioStreamMP3).resource_path.ends_with("dragon.mp3"), "The latest request must win")
	_check(not music._players[1 - music._active].playing, "Only one track may be left playing")


func _check_endless_chain(audio: Node, music: Node) -> void:
	audio.play_music("endless")
	var first: AudioStreamMP3 = _active(music).stream
	_check(first.resource_path.ends_with("endless_1.mp3") and not first.loop, "Endless must open with endless_1, once")
	music._on_finished(music._active)
	var second: AudioStreamMP3 = _active(music).stream
	_check(second.resource_path.ends_with("endless_2.mp3") and second.loop, "endless_2 must follow and loop")
	audio.play_music("endless")
	_check(_active(music).stream == second, "Asking for Endless again must not go back to endless_1")
	music._on_finished(music._active)
	_check(_active(music).stream == second, "endless_2 must keep repeating")
