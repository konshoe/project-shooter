extends Node3D
## Root of the game scene. Phase 1: wiring only, no gameplay logic.

@export var bullet_pool: NodePath

@onready var _player: Player = $Player
@onready var _wave_spawner: WaveSpawner = $WaveSpawner
@onready var _upgrade_picker: UpgradePicker = $UpgradePicker

var _waves_completed := 0


func _ready() -> void:
	var pool := get_node_or_null(bullet_pool) as BulletPool
	if pool == null:
		push_error("GameWorld: bullet_pool path doesn't point to a BulletPool node.")
		return
	_player.bullet_pool = pool

	_wave_spawner.level_complete.connect(func(): print("LEVEL COMPLETE"))
	_wave_spawner.wave_complete.connect(_on_wave_complete)
	_upgrade_picker.picker_closed.connect(_wave_spawner.advance_to_next_wave)


func _on_wave_complete() -> void:
	_waves_completed += 1
	if _waves_completed % _upgrade_picker.waves_between_picks == 0 and not _wave_spawner.is_final_wave():
		_upgrade_picker.show_picker()  # Advances via picker_closed.
	else:
		_wave_spawner.advance_to_next_wave()
