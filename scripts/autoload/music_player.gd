class_name MusicPlayer
extends Node
## Plays one soundtrack at a time and crossfades between them. Owned by AudioManager, so callers
## use AudioManager.play_music(). Asking for the track already playing does nothing, which lets the
## game request the right track every frame. Missing files fade to silence.

const MUSIC_DIR: String = "res://assets/audio/music/"
const MUSIC_BUS: StringName = &"Music"
const FADE_SEC: float = 1.5
## Music sits under the sound effects unless a track sets its own db.
const DEFAULT_DB: float = -8.0

## file = name in MUSIC_DIR if it isn't the track's name, once = don't loop, then = the file to
## loop after this one ends, db = volume trim.
const TRACKS: Dictionary = {
	"menu": {},
	"overworld": {},
	"underworld": {},
	"catacombs": {},
	"pandemonium": {},
	"abyss": {},
	"floor_boss": {},
	"mega_boss": {},
	"dragon": {},
	"hidden_boss": {},
	"endless": {"file": "endless_1", "then": "endless_2"},
	"victory": {"once": true},
	"game_over": {"once": true},
}

var current: String = ""

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _fade: Tween


func _ready() -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = MUSIC_BUS
		player.finished.connect(_on_finished.bind(i))
		add_child(player)
		_players.append(player)


func play(track: String) -> void:
	if track == current:
		return
	current = track
	var settings: Dictionary = TRACKS.get(track, {})
	var loops: bool = not settings.get("once", false) and not settings.has("then")
	_start(String(settings.get("file", track)), loops, FADE_SEC)


func stop() -> void:
	current = ""
	_start("", false, FADE_SEC)


func _start(file: String, loops: bool, fade_sec: float) -> void:
	var outgoing: AudioStreamPlayer = _players[_active]
	_active = 1 - _active
	var incoming: AudioStreamPlayer = _players[_active]
	if _fade != null:
		_fade.kill()
	incoming.stop()
	_fade = create_tween().set_parallel()
	_fade.tween_property(outgoing, "volume_linear", 0.0, fade_sec)
	var stream: AudioStreamMP3 = _load(file)
	if stream != null:
		stream.loop = loops
		incoming.stream = stream
		incoming.volume_linear = 0.0
		incoming.play()
		var trim: float = float(TRACKS.get(current, {}).get("db", DEFAULT_DB))
		_fade.tween_property(incoming, "volume_linear", db_to_linear(trim), fade_sec)
	_fade.chain().tween_callback(outgoing.stop)


func _load(file: String) -> AudioStreamMP3:
	var path: String = "%s%s.mp3" % [MUSIC_DIR, file]
	if file.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStreamMP3


func _on_finished(index: int) -> void:
	if index != _active:
		return
	var then: String = String(TRACKS.get(current, {}).get("then", ""))
	if not then.is_empty():
		_start(then, true, 0.0)
