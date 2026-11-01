extends SceneTree
## Run with: Godot --headless --path . --script res://tests/audio/audio_manager_test.gd

const SCRIPT_DIRS: Array[String] = [
	"res://scripts/bosses", "res://scripts/main", "res://scripts/monsters", "res://scripts/nests",
	"res://scripts/player", "res://scripts/spells", "res://scripts/ui", "res://scripts/world",
]

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(passed: bool, message: String) -> void:
	if not passed:
		_failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	_check_every_sound_loaded(audio)
	_check_fire_loop(audio)
	_check_hook_names(audio)
	_check_monster_death_sounds(audio)
	_check_rate_limit(audio)
	_check_loop_sharing(audio)
	print("audio test: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


func _check_every_sound_loaded(audio: Node) -> void:
	for sound_name: String in audio.SOUNDS:
		var expected: int = int(audio.SOUNDS[sound_name].get("variants", 1))
		var streams: Array = audio._streams[sound_name]
		_check(streams.size() == expected, "%s loaded %d of %d files" % [sound_name, streams.size(), expected])
		for stream: AudioStream in streams:
			_check(stream != null and stream.get_length() > 0.0, "%s has an empty stream" % sound_name)


func _check_fire_loop(audio: Node) -> void:
	var stream: AudioStreamWAV = audio._streams["fire_loop"][0]
	_check(stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "fire_loop imported without looping")


## A typo in a sound name would otherwise fail silently, so every call site is checked.
func _check_hook_names(audio: Node) -> void:
	var call_pattern := RegEx.create_from_string("AudioManager\\.(?:play|play_at|start_loop|stop_loop)\\(\"(\\w+)\"")
	var ternary_pattern := RegEx.create_from_string("AudioManager\\.play(?:_at)?\\(\"(\\w+)\" if \\w+ else \"(\\w+)\"")
	var found: int = 0
	for dir_path: String in SCRIPT_DIRS:
		for file_name: String in DirAccess.get_files_at(dir_path):
			if not file_name.ends_with(".gd"):
				continue
			var source: String = FileAccess.get_file_as_string(dir_path.path_join(file_name))
			for pattern: RegEx in [call_pattern, ternary_pattern]:
				for result: RegExMatch in pattern.search_all(source):
					for group: int in range(1, result.get_group_count() + 1):
						found += 1
						_check(audio.SOUNDS.has(result.get_string(group)), "%s uses unknown sound %s" % [file_name, result.get_string(group)])
	_check(found > 30, "only found %d sound call sites" % found)


func _check_monster_death_sounds(audio: Node) -> void:
	for stats: MonsterStats in Config.MONSTERS:
		_check(audio.SOUNDS.has(stats.name.to_lower() + "_death"), "%s has no death sound" % stats.name)


func _check_rate_limit(audio: Node) -> void:
	audio._last_played_ms.clear()
	audio.play("boss_hit")
	var busy_before: int = _busy_players(audio)
	audio.play("boss_hit")
	_check(_busy_players(audio) == busy_before, "boss_hit ignored its minimum gap")


func _check_loop_sharing(audio: Node) -> void:
	audio.start_loop("fire_loop")
	audio.start_loop("fire_loop")
	audio.stop_loop("fire_loop")
	_check(audio._loop_players["fire_loop"].playing, "loop stopped while still in use")
	audio.stop_loop("fire_loop")
	_check(not audio._loop_players["fire_loop"].playing, "loop kept playing after its last user stopped")
	audio.stop_loop("fire_loop")
	_check(int(audio._loop_users["fire_loop"]) == 0, "extra stop_loop made the user count negative")


func _busy_players(audio: Node) -> int:
	var busy: int = 0
	for player: AudioStreamPlayer in audio._pool:
		if player.playing:
			busy += 1
	return busy
