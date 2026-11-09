class_name Player
extends CharacterBody3D
## Player ship.
##
## All movement is worked out in screen space and then projected onto the
## gameplay plane (the plane through the ship, facing the camera). This works
## whatever the camera's orthographic size or orientation is, and keeps the
## speed and margin settings in viewport pixels.
##
## Touch drag, mouse and keyboard share one code path: each produces a target
## screen position, which is clamped to the bottom of the viewport. The ship
## then moves toward it.
##
## Pointer input is read in _unhandled_input, so full-screen HUD Controls should
## use MOUSE_FILTER_IGNORE or they will swallow the drag/mouse events.

const FLASH_INTERVAL := 0.1

@export var bullet_pool: BulletPool

@export_group("Movement")
## Base maximum ship speed, in viewport pixels per second (before upgrades).
## Kept low enough that the cap actually binds on big moves, so the
## Afterburner upgrade is noticeable.
@export var max_speed_px: float = 1200.0
## Base keyboard movement speed, in viewport pixels per second (before upgrades).
@export var keyboard_speed_px: float = 700.0
## Minimum distance kept from the viewport's left, right and bottom edges, in pixels.
@export var edge_margin_px: float = 32.0
## Top of the play zone, as a fraction of viewport height (2/3 = bottom third).
@export_range(0.0, 1.0) var play_zone_top: float = 2.0 / 3.0

@export_group("Firing")
## Base seconds between automatic shots (before upgrades).
@export var fire_interval: float = 0.2
## Base bullet speed in world units per second (before upgrades).
@export var bullet_speed: float = 20.0
## Angle between the centre bullet and each side bullet of Triple Shot, in degrees.
@export var triple_shot_angle_deg: float = 15.0
## How far ahead of the ship (toward the top of the screen) bullets spawn, in world units.
@export var muzzle_offset: float = 0.6

@export_group("Damage")
## Seconds the ship can't be hit again after losing a life.
@export var invincibility_sec: float = 1.5

var _pointer_target := Vector2.ZERO
var _has_pointer_target := false
var _fire_cooldown := 0.0
var _invincible_time_left := 0.0

## Detects enemies touching the ship (mask: layer 3, Enemy). It sits on no
## layer itself, and the ship's own body still collides with nothing.
@onready var _hurt_box: Area3D = $HurtBox
@onready var _mesh: MeshInstance3D = $PlaceholderMesh


func _ready() -> void:
	add_to_group("player")
	_hurt_box.body_entered.connect(_on_hurtbox_body_entered)
	# Deferred: a parent (e.g. GameWorld) assigns bullet_pool in its own _ready(),
	# which runs after this one.
	_warn_if_no_pool.call_deferred()


func _warn_if_no_pool() -> void:
	if bullet_pool == null:
		push_warning("Player: bullet_pool is not assigned; auto-fire is disabled.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		if event.index == 0:
			_set_pointer_target(event.position)
	elif event is InputEventScreenTouch:
		if event.index == 0 and event.pressed:
			_set_pointer_target(event.position)
	elif event is InputEventMouseMotion:
		_set_pointer_target(event.position)


func _physics_process(delta: float) -> void:
	_update_invincibility(delta)

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	_update_movement(camera, delta)
	_update_firing(camera, delta)


func _on_hurtbox_body_entered(body: Node3D) -> void:
	_take_hit()
	# Ramming destroys the enemy, even while the ship is invincible.
	if body.has_method("take_damage"):
		body.take_damage(999)


## Called by enemy bullets. Each hit costs one life, whatever [param _amount] is,
## and the invincibility window applies as it does for ramming.
func take_damage(_amount: int) -> void:
	_take_hit()


func _take_hit() -> void:
	if _invincible_time_left > 0.0:
		return
	if UpgradeManager.get_stat("shield_count", 0.0) > 0.0:
		# The shield absorbs the hit; the invincibility window stops one
		# collision from eating several shields.
		UpgradeManager.consume_shield()
		AudioManager.play_sfx("shield_hit")
		_begin_invincibility()
		return
	AudioManager.play_sfx("player_hit")
	GameState.lose_life()
	_begin_invincibility()


func _begin_invincibility() -> void:
	_invincible_time_left = invincibility_sec
	# Layer 1 is what enemy bullets (mask 1) collide with, so with it off they
	# pass straight through the ship instead of being pushed aside.
	set_collision_layer_value(1, false)


func _end_invincibility() -> void:
	_invincible_time_left = 0.0
	set_collision_layer_value(1, true)
	_mesh.visible = true


func _update_invincibility(delta: float) -> void:
	if _invincible_time_left <= 0.0:
		return
	_invincible_time_left -= delta
	if _invincible_time_left > 0.0:
		# Visible 0.1s, hidden 0.1s, ... counted from the hit.
		var elapsed := invincibility_sec - _invincible_time_left
		_mesh.visible = int(elapsed / FLASH_INTERVAL) % 2 == 0
		return
	_end_invincibility()
	# body_entered only fires when contact starts, so an enemy that is still
	# touching the ship when invincibility ends has to be checked for here.
	if _hurt_box.has_overlapping_bodies():
		_take_hit()


func _set_pointer_target(screen_pos: Vector2) -> void:
	_pointer_target = screen_pos
	_has_pointer_target = true


func _update_movement(camera: Camera3D, delta: float) -> void:
	var screen_pos := camera.unproject_position(global_position)
	var target := screen_pos

	var move_mult := 1.0 + UpgradeManager.get_stat("move_speed_multiplier", 0.0)
	var key_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if key_dir != Vector2.ZERO:
		# Keyboard takes over until the pointer moves again.
		_has_pointer_target = false
		target = screen_pos + key_dir * keyboard_speed_px * move_mult * delta
	elif _has_pointer_target:
		target = _pointer_target

	target = _clamp_to_play_zone(target)
	var step := (target - screen_pos).limit_length(max_speed_px * move_mult * delta)

	var world_target: Variant = _screen_to_plane(camera, screen_pos + step)
	if world_target == null:
		return
	velocity = ((world_target as Vector3) - global_position) / delta
	move_and_slide()


func _update_firing(camera: Camera3D, delta: float) -> void:
	_fire_cooldown -= delta
	if _fire_cooldown > 0.0:
		return
	# Carry the leftover time so the average rate stays at fire_interval.
	var interval := fire_interval / (1.0 + UpgradeManager.get_stat("fire_rate_multiplier", 0.0))
	_fire_cooldown = maxf(_fire_cooldown + interval, 0.0)

	if bullet_pool == null:
		return
	AudioManager.play_sfx("shoot")
	var speed := bullet_speed * (1.0 + UpgradeManager.get_stat("bullet_speed_multiplier", 0.0))
	var screen_up := camera.global_basis.y.normalized()
	var muzzle := global_position + screen_up * muzzle_offset
	bullet_pool.fire(muzzle, screen_up, speed)
	if UpgradeManager.get_stat("triple_shot_enabled", 0.0) > 0.0:
		# Rotate about the plane normal so the side shots stay on the gameplay plane.
		var axis := camera.global_basis.z.normalized()
		var angle := deg_to_rad(triple_shot_angle_deg)
		bullet_pool.fire(muzzle, screen_up.rotated(axis, angle), speed)
		bullet_pool.fire(muzzle, screen_up.rotated(axis, -angle), speed)


func _clamp_to_play_zone(screen_pos: Vector2) -> Vector2:
	var rect := get_viewport().get_visible_rect()
	var m := edge_margin_px
	return Vector2(
		clampf(screen_pos.x, rect.position.x + m, rect.end.x - m),
		clampf(screen_pos.y, rect.position.y + rect.size.y * play_zone_top, rect.end.y - m)
	)


## Returns the world point on the gameplay plane under [param screen_pos], or null.
func _screen_to_plane(camera: Camera3D, screen_pos: Vector2) -> Variant:
	var plane := Plane(camera.global_basis.z.normalized(), global_position)
	return plane.intersects_ray(
		camera.project_ray_origin(screen_pos),
		camera.project_ray_normal(screen_pos)
	)
