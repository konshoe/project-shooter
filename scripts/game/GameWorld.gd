extends Node3D
## Root of the game scene. Manages level sequencing via level_manifest.json.
##
## Level 1 is started by WaveSpawner's autostart (wave paths set in the scene
## Inspector). On level_complete, GameWorld reads level_manifest.json and feeds
## the next level's wave paths to WaveSpawner.load_level().

const LEVEL_MANIFEST_PATH := "res://resources/levels/level_manifest.json"

@export var bullet_pool: NodePath

@onready var _player: Player = $Player
@onready var _wave_spawner: WaveSpawner = $WaveSpawner
@onready var _upgrade_picker: UpgradePicker = $UpgradePicker

## Zero-based index of the level currently in play.
## Level 1 = 0, Level 2 = 1, etc.  Matches the manifest array index.
var _current_level_index := 0
var _waves_completed := 0
var _level_manifest: Array = []


func _ready() -> void:
	AudioManager.play_music("gameplay")
	var pool := get_node_or_null(bullet_pool) as BulletPool
	if pool == null:
		push_error("GameWorld: bullet_pool path doesn't point to a BulletPool node.")
		return
	_player.bullet_pool = pool

	_load_manifest()

	_wave_spawner.wave_complete.connect(_on_wave_complete)
	_wave_spawner.level_complete.connect(_on_level_complete)
	_upgrade_picker.picker_closed.connect(_wave_spawner.advance_to_next_wave)


func _load_manifest() -> void:
	var file := FileAccess.open(LEVEL_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("GameWorld: cannot open level manifest '%s' (error %d)." % [
			LEVEL_MANIFEST_PATH, FileAccess.get_open_error()])
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		_level_manifest = parsed
	else:
		push_error("GameWorld: level_manifest.json must be a JSON array.")


func _on_wave_complete() -> void:
	_waves_completed += 1
	if _waves_completed % _upgrade_picker.waves_between_picks == 0 \
			and not _wave_spawner.is_final_wave():
		_upgrade_picker.show_picker()  # Advances via picker_closed → advance_to_next_wave.
	else:
		_wave_spawner.advance_to_next_wave()


func _on_level_complete() -> void:
	_current_level_index += 1
	_waves_completed = 0  # Reset so upgrade-picker timing restarts cleanly.

	if _current_level_index >= _level_manifest.size():
		# All levels complete — placeholder until a Victory scene exists.
		print("VICTORY — all levels complete!")
		return

	var level_data: Variant = _level_manifest[_current_level_index]
	if not level_data is Dictionary:
		push_error("GameWorld: manifest entry %d is not an object." % _current_level_index)
		return

	var raw_paths: Variant = (level_data as Dictionary).get("waves", [])
	if not raw_paths is Array:
		push_error("GameWorld: manifest entry %d has no 'waves' array." % _current_level_index)
		return

	var paths: Array[String] = []
	for p: Variant in raw_paths:
		paths.append(str(p))

	if paths.is_empty():
		push_error("GameWorld: manifest entry %d has an empty waves list." % _current_level_index)
		return

	_wave_spawner.load_level(paths)
