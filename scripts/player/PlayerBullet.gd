class_name PlayerBullet
extends CharacterBody3D
## A pooled player bullet. BulletPool creates every instance once in its
## _ready(); after that bullets are only reused through launch() and
## return_to_pool(), never instantiated or freed.
##
## Collision: layer 2 (PlayerBullet), mask layer 3 (Enemy). Because the mask
## only contains the Enemy layer, any collision from move_and_collide() is an
## enemy hit.

## Damage passed to the enemy's take_damage() method, if it has one.
@export var damage: int = 1
## How far past the viewport edge (in pixels) the bullet travels before it
## returns to the pool, so it doesn't vanish while still partly on screen.
@export var offscreen_margin_px: float = 32.0

## True while the bullet is in flight. BulletPool only reuses inactive bullets.
var active := false


## Places the bullet at [param at] and starts it moving. Called by BulletPool.fire().
func launch(at: Vector3, direction: Vector3, speed: float) -> void:
	# Move before re-enabling, so the body re-enters the physics space at its new
	# position rather than where it was last deactivated.
	global_position = at
	velocity = direction.normalized() * speed
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


## Deactivates the bullet so BulletPool can reuse it. Disabling processing also
## removes the body from the physics space, so an idle bullet can't hit anything.
func return_to_pool() -> void:
	active = false
	velocity = Vector3.ZERO
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	var hit := move_and_collide(velocity * delta)
	if hit != null:
		var enemy := hit.get_collider()
		if enemy != null and enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		return_to_pool()
		return

	if _is_off_screen():
		return_to_pool()


func _is_off_screen() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var visible_rect := get_viewport().get_visible_rect().grow(offscreen_margin_px)
	return not visible_rect.has_point(camera.unproject_position(global_position))
