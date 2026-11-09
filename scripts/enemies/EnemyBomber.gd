class_name EnemyBomber
extends EnemyBase
## Tougher enemy that flies down the screen in a left-right sine-wave zigzag.
##
## Speed is in viewport pixels per second, the same unit as the wave config
## "speed" field. Movement is worked out in screen space and projected onto the
## gameplay plane, so it doesn't depend on the camera's orthographic size.

## Downward speed, in viewport pixels per second.
@export var speed: float = 100.0
## Zigzag half-width, as a fraction of viewport width.
@export var zigzag_amplitude: float = 0.15
## Zigzag cycles per second.
@export var zigzag_frequency_hz: float = 1.5
## How far below the bottom edge (in pixels) the bomber goes before it is removed.
@export var offscreen_margin_px: float = 64.0
## Points awarded when this bomber is destroyed.
@export var score_value: int = 30
## Seconds between shots, counted from the moment the bomber is fully on screen.
@export var fire_interval: float = 2.0

var _fire_timer: Timer

## Centre line of the zigzag, in screen space. Set on the first physics frame,
## after the spawner has positioned the node.
var _path_pos := Vector2.ZERO
var _path_ready := false
var _time := 0.0


func _ready() -> void:
	max_health = 3
	super()  # EnemyBase._ready() sets health; Godot 4 doesn't call it automatically.
	died.connect(GameState.add_score.bind(score_value))

	# Created here but only started once the bomber is on screen.
	_fire_timer = Timer.new()
	_fire_timer.wait_time = fire_interval
	_fire_timer.one_shot = false
	_fire_timer.timeout.connect(_fire)
	add_child(_fire_timer)


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var screen_pos := camera.unproject_position(global_position)
	var view_rect := get_viewport().get_visible_rect()
	if not _path_ready:
		_path_pos = screen_pos
		_path_ready = true

	# Bombers spawn above the top edge; start firing once they have come into view.
	if _fire_timer.is_stopped() and screen_pos.y >= view_rect.position.y:
		_fire_timer.start()

	# Only the bottom edge counts as leaving.
	if screen_pos.y > view_rect.end.y + offscreen_margin_px:
		left_screen.emit()
		queue_free()
		return

	_time += delta
	_path_pos.y += speed * delta
	var offset_x := zigzag_amplitude * view_rect.size.x * sin(TAU * zigzag_frequency_hz * _time)
	var next_screen_pos := Vector2(_path_pos.x + offset_x, _path_pos.y)

	var plane := Plane(camera.global_basis.z.normalized(), global_position)
	var target: Variant = plane.intersects_ray(
		camera.project_ray_origin(next_screen_pos),
		camera.project_ray_normal(next_screen_pos)
	)
	if target == null:
		return
	velocity = ((target as Vector3) - global_position) / delta
	move_and_slide()


## Fires one bullet straight down the screen from the bomber's current position.
func _fire() -> void:
	if EnemyBulletPool.instance == null:
		return
	# direction = Vector3.ZERO tells EnemyBullet to fly straight down the screen.
	EnemyBulletPool.instance.fire(global_position, Vector3.ZERO, 200.0, 1)
