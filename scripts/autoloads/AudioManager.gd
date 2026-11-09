extends Node
## Autoload: plays SFX by key and crossfades music.
##
## Creates its own AudioStreamPlayer nodes in _ready(). Missing audio files are
## not fatal: the first request for one logs a warning and is then ignored, so
## the game runs fine before the audio assets exist.
##
## Import settings (set in Godot's Import dock, per file):
##   assets/audio/sfx/*.ogg   -> Load (in memory)
##   assets/audio/music/*.ogg -> Stream

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_KEYS: Array[String] = ["shoot", "enemy_death", "player_hit", "boss_death", "shield_hit"]
## Per-key volume offset in dB for SFX that should be quieter (or louder) than
## the rest. Keys not listed play at 0 dB.
const SFX_VOLUME_DB := {
	"shoot": -10.0,
}
const MUSIC_KEYS: Array[String] = ["gameplay"]

## Simultaneous SFX voices. Auto-fire plus explosions overlap, so one player isn't enough.
const SFX_VOICES := 8
const SILENT_DB := -80.0
const DEFAULT_FADE_SEC := 1.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_voice := 0
## Two music players so one can fade out while the other fades in.
var _music_players: Array[AudioStreamPlayer] = []
var _active_music := 0
var _music_key := ""
var _music_tween: Tween

## key -> AudioStream, or null if the file was missing (so we only warn once).
var _sfx_cache: Dictionary = {}
var _music_cache: Dictionary = {}


func _ready() -> void:
	# Keep music running (and the pause menu / game over sounds working) while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		add_child(player)
		_sfx_players.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % i
		player.volume_db = SILENT_DB
		add_child(player)
		_music_players.append(player)


## Plays a one-shot sound effect. Unknown keys and missing files are ignored with a warning.
func play_sfx(key: String) -> void:
	var stream := _get_stream(key, SFX_KEYS, SFX_DIR, _sfx_cache)
	if stream == null:
		return
	var player := _sfx_players[_next_sfx_voice]
	_next_sfx_voice = (_next_sfx_voice + 1) % SFX_VOICES  # Round-robin; steals the oldest voice.
	player.stream = stream
	# Set every time: voices are shared round-robin, so a previous key's offset must not stick.
	player.volume_db = SFX_VOLUME_DB.get(key, 0.0)
	player.play()


## Crossfades to a looping music track. Does nothing if that track is already playing.
func play_music(key: String, fade_sec: float = DEFAULT_FADE_SEC) -> void:
	if key == _music_key and _music_players[_active_music].playing:
		return
	var stream := _get_stream(key, MUSIC_KEYS, MUSIC_DIR, _music_cache)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

	var outgoing := _music_players[_active_music]
	_active_music = 1 - _active_music
	var incoming := _music_players[_active_music]
	_music_key = key

	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()

	_restart_tween()
	_music_tween.tween_property(incoming, "volume_db", 0.0, fade_sec)
	_music_tween.tween_property(outgoing, "volume_db", SILENT_DB, fade_sec)
	_music_tween.chain().tween_callback(outgoing.stop)


## Fades out the current music, then stops it.
func stop_music(fade_sec: float = DEFAULT_FADE_SEC) -> void:
	_music_key = ""
	var current := _music_players[_active_music]
	if not current.playing:
		return
	_restart_tween()
	_music_tween.tween_property(current, "volume_db", SILENT_DB, fade_sec)
	_music_tween.tween_callback(current.stop)


func _restart_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)


## Returns the cached stream for `key`, loading it on first use. Returns null
## (after one warning) for unknown keys or missing files.
func _get_stream(key: String, valid_keys: Array[String], dir: String, cache: Dictionary) -> AudioStream:
	if cache.has(key):
		return cache[key]
	if not valid_keys.has(key):
		push_warning("AudioManager: unknown audio key '%s'." % key)
		return null
	var path := "%s%s.ogg" % [dir, key]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	else:
		push_warning("AudioManager: audio file '%s' not found; '%s' will be silent." % [path, key])
	cache[key] = stream
	return stream
