class_name EnemyBullet
extends CharacterBody3D
## Bullet fired by enemies. Flies straight down the screen and damages the player.
##
## Collision: layer 4 (EnemyBullet), mask layer 1 (Player). Because the mask only
## contains the Player layer, any collision from move_and_collide() is a player hit.
##
## Speed is in viewport pixels per second, like enemy speeds. The camera is
## orthographic and looks along -Z at the gameplay plane (Z = 0), so "down the
## screen" is worked out from the camera rather than from world Z.

## Downward speed, in viewport pixels per second.
@export var speed: float = 200.0
## Damage passed to the player's take_damage().
@export var damage: int = 1
## How far below the bottom edge (in pixels) the bullet travels before it is freed.
@export var offscreen_margin_px: float = 32.0


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var view_rect := get_viewport().get_visible_rect()
	if camera.unproject_position(global_position).y > view_rect.end.y + offscreen_margin_px:
		queue_free()
		return

	# Orthographic camera: `size` is world units across the viewport's height.
	var world_per_px := camera.size / view_rect.size.y
	var screen_down := -camera.global_basis.y.normalized()
	var hit := move_and_collide(screen_down * speed * world_per_px * delta)
	if hit != null:
		var target := hit.get_collider()
		if target != null and target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
