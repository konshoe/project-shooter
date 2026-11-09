class_name EnemyBulletPool
extends Node
## Fixed-size pool of EnemyBullet nodes.
##
## All MAX_BULLETS bullets are created once, in _ready(), and live as children
## of this node for the whole scene. fire() reuses an inactive bullet; it never
## calls instantiate() during gameplay, which would cause frame drops on mobile.
##
## Place this node directly under GameWorld (sibling of WaveSpawner). Enemies
## access the pool via the static EnemyBulletPool.instance reference — no
## inspector wiring needed.

## How many enemy bullets can be in flight simultaneously.
## Worst case at max content: BossAlpha (3 bullets × every 2s over ~6s flight) +
## 4 Bombers (1 bullet × every 2s over ~6s flight) ≈ 21 bullets. 32 is safe.
const MAX_BULLETS := 32
const BULLET_SCENE: PackedScene = preload("res://scenes/enemies/EnemyBullet.tscn")

## Static reference so enemy scripts can call EnemyBulletPool.instance.fire()
## without needing a reference passed in from the scene.
static var instance: EnemyBulletPool = null

var _bullets: Array[EnemyBullet] = []


func _ready() -> void:
	instance = self
	# The only place enemy bullets are ever created.
	for i in MAX_BULLETS:
		var bullet := BULLET_SCENE.instantiate() as EnemyBullet
		bullet.name = "EnemyBullet%02d" % i
		add_child(bullet)
		# return_to_pool() is called in EnemyBullet._ready(), but be explicit.
		bullet.return_to_pool()
		_bullets.append(bullet)


## Fire one bullet from [param position] in [param direction] at [param speed]
## (px/s) dealing [param damage]. If every bullet is already in flight, the shot
## is silently dropped. 32 slots should mean this never happens in practice.
func fire(position: Vector3, direction: Vector3, speed: float, damage: int) -> void:
	for bullet in _bullets:
		if not bullet.active:
			bullet.launch(position, direction, speed, damage)
			return


func _exit_tree() -> void:
	# Clear the static reference when this node leaves the scene tree, so a fresh
	# GameWorld load doesn't hold a stale pointer.
	if instance == self:
		instance = null
