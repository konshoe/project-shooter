class_name EnemyBase
extends CharacterBody3D
## Shared base for every enemy: health, damage and lifecycle signals.
## Movement and attacks belong in the subclasses (EnemyFighter, EnemyBomber, ...).
##
## Collision: layer 3 (Enemy), mask 0. Enemies don't detect anything themselves;
## player bullets find them with move_and_collide() and call take_damage().

## Emitted once, when health reaches 0, just before the enemy is freed.
signal died
## Emitted when the enemy leaves the bottom of the screen without being killed.
# Emitted by subclasses (e.g. EnemyFighter), so it's unused in this file.
@warning_ignore("unused_signal")
signal left_screen

@export var max_health: int = 3

## SFX key played on death (see AudioManager). Subclasses can override it.
var death_sfx: String = "enemy_death"

var health: int


func _ready() -> void:
	health = max_health


func take_damage(amount: int) -> void:
	# Two bullets can hit in the same frame; only the first kill counts.
	if health <= 0:
		return
	health -= amount
	if health <= 0:
		AudioManager.play_sfx(death_sfx)
		died.emit()
		queue_free()
