class_name WaveSpawner
extends Node3D
## Spawns a wave of enemies described by a JSON wave config
## (schema: see "Wave Config Schema" in CLAUDE.md).
##
## Talks to the rest of the game only through signals. It never references the
## player.
##
## Place this node on the gameplay plane (e.g. at the GameWorld origin). Spawn
## points are worked out in screen space and projected onto the plane through
## this node, facing the camera. Enemies are added as children of this node.

## Emitted once every enemy in the wave has been spawned and is dead or off-screen.
signal wave_complete
## Emitted when a wave begins. wave_number is 1-based.
signal wave_started(wave_number: int, wave_total: int)
## Emitted after the last wave config in the list has completed.
signal level_complete

## Maps the config's "type" string to its scene. Preloaded so nothing is loaded
## during gameplay. Add new enemy types here.
const ENEMY_SCENES := {
	"EnemyFighter": preload("res://scenes/enemies/EnemyFighter.tscn"),
	"EnemyBomber": preload("res://scenes/enemies/EnemyBomber.tscn"),
	"BossAlpha": preload("res://scenes/enemies/bosses/BossAlpha.tscn"),
}
## Horizontal gap between neighbouring formation slots (viewport width fraction).
const FORMATION_SPACING_X := 0.12
## Vertical gap between formation rows (viewport height fraction).
const FORMATION_SPACING_Y := 0.06
## Half-width of the "random" formation's spawn band (viewport width fraction).
const RANDOM_HALF_WIDTH := 0.3

## Ordered wave config JSONs for the level. Each starts when the previous completes.
@export_file("*.json") var wave_config_paths: Array[String] = []
## Deprecated: single-wave fallback, used only when wave_config_paths is empty.
@export_file("*.json") var wave_config_path: String = "res://resources/waves/level01_wave01.json"
## Start the wave automatically when the scene loads.
@export var autostart := true

## Every wave's enemies, created at load time (one entry per config, in order).
var _waves: Array = []
var _wave_index := -1
## Path of the config currently being parsed/played (for error messages).
var _current_path := ""
## Enemies of the current wave created at load time but not yet spawned. Each entry:
## { "enemy": EnemyBase, "screen_frac": Vector2, "delay_after": float }
var _pending: Array[Dictionary] = []
## Enemies currently in play. Kept as a set (enemy -> true) rather than a bare
## counter so an enemy that emits both left_screen and died is only counted once.
var _alive: Dictionary = {}
var _started := false

@onready var _spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_spawn_next)

	# Create every wave now, at scene load, so spawning during gameplay only
	# adds existing nodes to the tree. No instantiate() during gameplay.
	var paths: Array[String] = wave_config_paths
	if paths.is_empty() and wave_config_path != "":
		paths = [wave_config_path]
	for path in paths:
		_pending = []
		_load_config(path)
		_waves.append(_pending)
	_pending = []

	if autostart:
		start_wave.call_deferred()


func _notification(what: int) -> void:
	# Enemies that never got spawned aren't in the tree, so free them ourselves.
	if what == NOTIFICATION_PREDELETE:
		for wave: Array in _waves:
			for entry: Dictionary in wave:
				(entry["enemy"] as Node).free()
		_waves.clear()


func start_wave() -> void:
	if _started:
		return
	_started = true
	_begin_next_wave()


func _begin_next_wave() -> void:
	_wave_index += 1
	if _wave_index >= _waves.size():
		level_complete.emit()
		return
	wave_started.emit(_wave_index + 1, _waves.size())
	_pending.assign(_waves[_wave_index])
	_waves[_wave_index] = []  # Ownership passes to the spawn queue.
	if _pending.is_empty():
		# Nothing to spawn (bad or empty config) - don't leave the level hanging.
		_finish_wave()
		return
	_spawn_next()


## Emits wave_complete. Does not advance: whoever listens must call
## advance_to_next_wave() when ready (e.g. after an upgrade pick).
func _finish_wave() -> void:
	wave_complete.emit()


## True while the last wave in the list is the one in play.
func is_final_wave() -> bool:
	return _wave_index >= _waves.size() - 1


## Starts the next wave, or emits level_complete after the last one.
func advance_to_next_wave() -> void:
	_begin_next_wave()


## Clears the current wave set and loads a new list of wave configs.
## Frees every enemy that has not yet been spawned or is still alive on screen.
## Called by GameWorld between levels; score and upgrades are managed elsewhere.
func load_level(paths: Array[String]) -> void:
	# Stop any pending spawn delay.
	_spawn_timer.stop()

	# Free enemies waiting in unfired waves.
	for wave: Array in _waves:
		for entry: Dictionary in wave:
			(entry["enemy"] as Node).free()
	_waves.clear()

	# Free enemies pending in the active wave queue.
	for entry: Dictionary in _pending:
		(entry["enemy"] as Node).free()
	_pending.clear()

	# Remove live enemies from the tree. _on_enemy_gone will fire but _alive is
	# already cleared below, so it returns early without double-counting.
	for enemy: EnemyBase in _alive.keys():
		enemy.queue_free()
	_alive.clear()

	# Reset sequencing state.
	_wave_index = -1
	_started = false
	_current_path = ""

	# Pre-instantiate all enemies for the new level (same logic as _ready).
	for path in paths:
		_pending = []
		_load_config(path)
		_waves.append(_pending)
	_pending = []

	start_wave.call_deferred()


func _load_config(path: String) -> void:
	_current_path = path
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("WaveSpawner: cannot open wave config '%s' (error %d)." % [path, FileAccess.get_open_error()])
		return
	var config: Variant = JSON.parse_string(file.get_as_text())
	if not config is Dictionary or not (config as Dictionary).get("enemies") is Array:
		push_error("WaveSpawner: wave config '%s' is not valid (expected an object with an 'enemies' array)." % path)
		return

	for group: Variant in config["enemies"]:
		if group is Dictionary:
			_queue_group(group)


func _queue_group(group: Dictionary) -> void:
	var type: String = group.get("type", "")
	if not ENEMY_SCENES.has(type):
		push_error("WaveSpawner: unknown enemy type '%s' in '%s'." % [type, _current_path])
		return

	var count: int = int(group.get("count", 1))
	var center_x: float = group.get("spawn_x_center", 0.5)
	var spawn_y: float = group.get("spawn_y", -0.05)
	var speed: float = group.get("speed", -1.0)
	var delay: float = group.get("delay_between", 0.0)
	var formation: String = group.get("formation", "line")

	for i in count:
		var enemy := (ENEMY_SCENES[type] as PackedScene).instantiate() as EnemyBase
		if speed >= 0.0 and "speed" in enemy:
			enemy.set("speed", speed)
		_pending.append({
			"enemy": enemy,
			"screen_frac": _formation_slot(formation, i, count, center_x, spawn_y),
			# Gap before the next enemy; the last of a group also waits, so groups don't overlap.
			"delay_after": delay,
		})


## Returns the viewport-fraction spawn point for slot `i` of `count`.
func _formation_slot(formation: String, i: int, count: int, center_x: float, spawn_y: float) -> Vector2:
	var offset := float(i) - float(count - 1) / 2.0  # Signed distance from the middle slot.
	match formation:
		"V":
			# Tip of the V leads (lowest on screen); the wings trail further above it.
			return Vector2(
				center_x + offset * FORMATION_SPACING_X,
				spawn_y - absf(offset) * FORMATION_SPACING_Y
			)
		"grid":
			var cols := ceili(sqrt(float(count)))
			var col_offset := float(i % cols) - float(cols - 1) / 2.0
			return Vector2(
				center_x + col_offset * FORMATION_SPACING_X,
				spawn_y - floorf(i / float(cols)) * FORMATION_SPACING_Y
			)
		"random":
			return Vector2(center_x + randf_range(-RANDOM_HALF_WIDTH, RANDOM_HALF_WIDTH), spawn_y)
		_:  # "line" and anything unrecognised
			return Vector2(center_x + offset * FORMATION_SPACING_X, spawn_y)


func _spawn_next() -> void:
	if _pending.is_empty():
		return

	var entry: Dictionary = _pending.pop_front()
	var enemy: EnemyBase = entry["enemy"]

	enemy.died.connect(_on_enemy_gone.bind(enemy))
	enemy.left_screen.connect(_on_enemy_gone.bind(enemy))
	_alive[enemy] = true

	add_child(enemy)
	enemy.global_position = _spawn_position(entry["screen_frac"])

	if not _pending.is_empty():
		var delay: float = entry["delay_after"]
		if delay > 0.0:
			_spawn_timer.start(delay)
		else:
			_spawn_next()


func _on_enemy_gone(enemy: EnemyBase) -> void:
	if not _alive.erase(enemy):
		return  # Already counted (e.g. left the screen and was hit in the same frame).
	if _alive.is_empty() and _pending.is_empty():
		_finish_wave()


## Projects a viewport-fraction position (0-1 on both axes) onto the gameplay plane.
func _spawn_position(screen_frac: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("WaveSpawner: no active Camera3D; spawning at the spawner's position.")
		return global_position

	var rect := get_viewport().get_visible_rect()
	var screen_pos := rect.position + rect.size * screen_frac
	var plane := Plane(camera.global_basis.z.normalized(), global_position)
	var hit: Variant = plane.intersects_ray(
		camera.project_ray_origin(screen_pos),
		camera.project_ray_normal(screen_pos)
	)
	return hit if hit != null else global_position
