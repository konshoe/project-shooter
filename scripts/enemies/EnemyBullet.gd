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
##
## Pooled: never queue_free() this node. Call return_to_pool() instead, or let
## EnemyBulletPool.fire() check out an inactive bullet via the active flag.

## Downward speed, in viewport pixels per second.
@export var speed: float = 200.0
## Damage passed to the player's take_damage().
@export var damage: int = 1
## How far beyond any edge (in pixels) the bullet travels before it is returned.
@export var offscreen_margin_px: float = 32.0

## World-space flight direction. Leave at zero to fly straight down the screen.
var direction := Vector3.ZERO
## False while the bullet is idle in the pool. The pool checks this to find a free slot.
var active: bool = false


func _ready() -> void:
	return_to_pool()


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	# Angled shots can leave through the sides, so check those edges as well as the bottom.
	var view_rect := get_viewport().get_visible_rect()
	var screen_pos := camera.unproject_position(global_position)
	if (
		screen_pos.y > view_rect.end.y + offscreen_margin_px
		or screen_pos.x < view_rect.position.x - offscreen_margin_px
		or screen_pos.x > view_rect.end.x + offscreen_margin_px
	):
		return_to_pool()
		return

	# Orthographic camera: `size` is world units across the viewport's height.
	var world_per_px := camera.size / view_rect.size.y
	var move_dir := direction if direction != Vector3.ZERO else -camera.global_basis.y.normalized()
	var hit := move_and_collide(move_dir * speed * world_per_px * delta)
	if hit != null:
		var target := hit.get_collider()
		if target != null and target.has_method("take_damage"):
			target.take_damage(damage)
		return_to_pool()


## Activate this bullet from the pool. Called by EnemyBulletPool.fire().
func launch(pos: Vector3, dir: Vector3, spd: float, dmg: int) -> void:
	direction = dir
	speed = spd
	damage = dmg
	global_position = pos
	active = true
	set_physics_process(true)


## Deactivate and park the bullet out of play. Never call queue_free() on this node.
func return_to_pool() -> void:
	active = false
	direction = Vector3.ZERO
	velocity = Vector3.ZERO
	# Park far off the gameplay plane so it cannot accidentally collide.
	global_position = Vector3(0.0, 0.0, -9999.0)
	set_physics_process(false)
