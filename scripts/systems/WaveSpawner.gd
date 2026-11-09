class_name WaveSpawner
extends Node3D
## Phase 1 wave spawner: one hard-coded wave of EnemyFighters.
## (Phase 2 replaces the constants below with JSON wave configs.)
##
## Talks to the rest of the game only through signals. It never references the
## player.
##
## Place this node on the gameplay plane (e.g. at the GameWorld origin). Spawn
## points are worked out in screen space and projected onto the plane through
## this node, facing the camera. Enemies are added as children of this node.

## Emitted once every enemy in the wave has been spawned and is dead or off-screen.
signal wave_complete

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/EnemyFighter.tscn")
const ENEMY_COUNT := 4
const SPAWN_INTERVAL_SEC := 1.0
## Spawn height as a fraction of viewport height (negative = just above the top edge).
const SPAWN_Y := -0.05

## Start the wave automatically when the scene loads.
@export var autostart := true

## Enemies created at load time but not yet spawned into the scene.
var _pending: Array[EnemyBase] = []
## Enemies currently in play. Kept as a set (enemy -> true) rather than a bare
## counter so an enemy that emits both left_screen and died is only counted once.
var _alive: Dictionary = {}
var _spawned_count := 0
var _started := false

@onready var _spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	# Create the whole wave now, at scene load, so spawning during gameplay only
	# adds existing nodes to the tree. No instantiate() during gameplay.
	for i in ENEMY_COUNT:
		_pending.append(ENEMY_SCENE.instantiate() as EnemyBase)

	_spawn_timer.wait_time = SPAWN_INTERVAL_SEC
	_spawn_timer.timeout.connect(_spawn_next)

	if autostart:
		start_wave.call_deferred()


func _notification(what: int) -> void:
	# Enemies that never got spawned aren't in the tree, so free them ourselves.
	if what == NOTIFICATION_PREDELETE:
		for enemy in _pending:
			enemy.free()
		_pending.clear()


func start_wave() -> void:
	if _started:
		return
	_started = true
	_spawn_next()
	_spawn_timer.start()


func _spawn_next() -> void:
	if _pending.is_empty():
		_spawn_timer.stop()
		return

	var enemy: EnemyBase = _pending.pop_front()
	var index := _spawned_count
	_spawned_count += 1
	if _pending.is_empty():
		_spawn_timer.stop()

	enemy.died.connect(_on_enemy_gone.bind(enemy))
	enemy.left_screen.connect(_on_enemy_gone.bind(enemy))
	_alive[enemy] = true

	add_child(enemy)
	enemy.global_position = _spawn_position(index)


func _on_enemy_gone(enemy: EnemyBase) -> void:
	if not _alive.erase(enemy):
		return  # Already counted (e.g. left the screen and was hit in the same frame).
	if _alive.is_empty() and _pending.is_empty():
		wave_complete.emit()


## Spreads ENEMY_COUNT spawn points evenly across the width, just above the top edge.
func _spawn_position(index: int) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_error("WaveSpawner: no active Camera3D; spawning at the spawner's position.")
		return global_position

	var rect := get_viewport().get_visible_rect()
	var screen_pos := Vector2(
		rect.position.x + rect.size.x * float(index + 1) / float(ENEMY_COUNT + 1),
		rect.position.y + rect.size.y * SPAWN_Y
	)
	var plane := Plane(camera.global_basis.z.normalized(), global_position)
	var hit: Variant = plane.intersects_ray(
		camera.project_ray_origin(screen_pos),
		camera.project_ray_normal(screen_pos)
	)
	return hit if hit != null else global_position
