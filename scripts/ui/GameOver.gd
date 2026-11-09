extends CanvasLayer
## Game over screen. Hidden until GameState.game_over fires; it then pauses the
## game. Restart resets GameState and reloads the scene.
##
## process_mode is ALWAYS (set in GameOver.tscn), so the Restart button still
## works while the rest of the game is paused.

@onready var _restart_button: Button = $Center/VBox/RestartButton


func _ready() -> void:
	hide()
	GameState.game_over.connect(_on_game_over)
	_restart_button.pressed.connect(_on_restart_pressed)


func _on_game_over() -> void:
	show()
	get_tree().paused = true
	_restart_button.grab_focus()  # So Enter/Space restarts on keyboard.


func _on_restart_pressed() -> void:
	# Unpause first: pause state belongs to the SceneTree, so it would carry
	# over into the reloaded scene.
	get_tree().paused = false
	GameState.reset()
	get_tree().reload_current_scene()
