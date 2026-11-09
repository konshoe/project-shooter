extends Node3D
## Root of the game scene. Phase 1: wiring only, no gameplay logic.

## The BulletPool node the Player fires through. It's a sibling of the Player,
## so bullets don't move with the ship.
@export var bullet_pool: NodePath

@onready var _player: Player = $Player


func _ready() -> void:
	var pool := get_node_or_null(bullet_pool) as BulletPool
	if pool == null:
		push_error("GameWorld: bullet_pool path doesn't point to a BulletPool node.")
		return
	_player.bullet_pool = pool
