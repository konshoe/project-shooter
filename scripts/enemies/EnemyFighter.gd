class_name EnemyFighter
extends EnemyBase
## Basic enemy that flies straight down the screen. No firing yet (Phase 2).
##
## Speed is in viewport pixels per second, the same unit as the wave config
## "speed" field. Movement is worked out in screen space and projected onto the
## gameplay plane, so it doesn't depend on the camera's orthographic size.

## Downward speed, in viewport pixels per second.
@export var speed: float = 120.0
## How far below the bottom edge (in pixels) the fighter goes before it is removed.
@export var offscreen_margin_px: float = 64.0
## Points awarded when this fighter is destroyed.
@export var score_value: int = 10


func _ready() -> void:
	super()  # EnemyBase._ready() sets health; Godot 4 doesn't call it automatically.
	died.connect(GameState.add_score.bind(score_value))


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var screen_pos := camera.unproject_position(global_position)
	# Fighters spawn above the top edge, so only the bottom edge counts as leaving.
	if screen_pos.y > get_viewport().get_visible_rect().end.y + offscreen_margin_px:
		left_screen.emit()
		queue_free()
		return

	var next_screen_pos := screen_pos + Vector2.DOWN * speed * delta
	var plane := Plane(camera.global_basis.z.normalized(), global_position)
	var target: Variant = plane.intersects_ray(
		camera.project_ray_origin(next_screen_pos),
		camera.project_ray_normal(next_screen_pos)
	)
	if target == null:
		return
	velocity = ((target as Vector3) - global_position) / delta
	move_and_slide()
