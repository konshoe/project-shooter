class_name BulletPool
extends Node
## Fixed-size pool of PlayerBullet nodes.
##
## All MAX_BULLETS bullets are created once, in _ready(), and live as children
## of this node for the whole scene. fire() reuses an inactive bullet and never
## creates one: instantiate() during gameplay causes frame drops on mobile.
##
## Keep this node outside the Player (e.g. directly under GameWorld) so bullets
## don't move with the ship after they're fired.

const MAX_BULLETS := 64
const BULLET_SCENE: PackedScene = preload("res://scenes/player/PlayerBullet.tscn")

var _bullets: Array[PlayerBullet] = []


func _ready() -> void:
	# The only place bullets are ever created.
	for i in MAX_BULLETS:
		var bullet := BULLET_SCENE.instantiate() as PlayerBullet
		bullet.name = "PlayerBullet%02d" % i
		add_child(bullet)
		bullet.return_to_pool()
		_bullets.append(bullet)


## Launches the first inactive bullet from [param position], travelling along
## [param direction] (world space) at [param speed] world units per second.
## If every bullet is already in flight, the shot is dropped.
func fire(position: Vector3, direction: Vector3, speed: float) -> void:
	for bullet in _bullets:
		if not bullet.active:
			bullet.launch(position, direction, speed)
			return
