class_name BossAlpha
extends EnemyBase
## Level 1 boss. Descends from above the screen, stops at a set height, then
## alternates between a three-bullet spread and a shot aimed at the player.
## No phase transitions and no drops.
##
## Speed is in viewport pixels per second, the same unit as the wave config
## "speed" field. Movement is worked out in screen space and projected onto the
## gameplay plane, so it doesn't depend on the camera's orthographic size.

## Entry speed, in viewport pixels per second.
@export var speed: float = 60.0
## The boss stops once its screen Y reaches this fraction of the viewport height.
@export_range(0.0, 1.0) var stop_y_fraction: float = 0.20
## Points awarded when the boss is destroyed.
@export var score_value: int = 500
## Seconds between attacks once the boss has stopped.
@export var attack_pause_sec: float = 2.0
## Speed of the boss's bullets, in viewport pixels per second.
@export var bullet_speed: float = 220.0
## Angle of the outer bullets in the spread shot, in degrees.
@export var spread_angle_deg: float = 15.0

var _in_position := false
## Alternates each attack: false = spread shot next, true = aimed shot next.
var _aimed_next := false
var _attack_timer: Timer


func _ready() -> void:
	max_health = 20
	super()  # EnemyBase._ready() sets health; Godot 4 doesn't call it automatically.
	death_sfx = "boss_death"
	died.connect(GameState.add_score.bind(score_value))

	_attack_timer = Timer.new()
	_attack_timer.wait_time = attack_pause_sec
	_attack_timer.one_shot = false
	_attack_timer.timeout.connect(_attack)
	add_child(_attack_timer)


func _physics_process(delta: float) -> void:
	if _in_position:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var screen_pos := camera.unproject_position(global_position)
	var view_rect := get_viewport().get_visible_rect()
	if screen_pos.y >= view_rect.position.y + view_rect.size.y * stop_y_fraction:
		_in_position = true
		velocity = Vector3.ZERO
		_attack_timer.start()
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


func _attack() -> void:
	if _aimed_next:
		_fire_aimed()
	else:
		_fire_spread()
	_aimed_next = not _aimed_next


## Three bullets: straight down, and spread_angle_deg to each side.
func _fire_spread() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var screen_down := -camera.global_basis.y.normalized()
	var axis := camera.global_basis.z.normalized()  # Rotates within the screen plane.
	var angle := deg_to_rad(spread_angle_deg)
	_fire_bullet(screen_down)
	_fire_bullet(screen_down.rotated(axis, angle))
	_fire_bullet(screen_down.rotated(axis, -angle))


## One bullet toward where the player is right now.
func _fire_aimed() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var to_player := player.global_position - global_position
	if to_player.is_zero_approx():
		return
	_fire_bullet(to_player.normalized())


## Fires one bullet in the given world-space direction via the enemy bullet pool.
func _fire_bullet(direction: Vector3) -> void:
	if EnemyBulletPool.instance == null:
		return
	EnemyBulletPool.instance.fire(global_position, direction, bullet_speed, 1)
