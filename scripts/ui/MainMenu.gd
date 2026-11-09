extends CanvasLayer
## Title screen. PLAY starts the music first: that button press is the user
## gesture browsers require before they will play audio, so it has to happen
## here, not after the scene change.

const GAME_SCENE := "res://scenes/game/GameWorld.tscn"

@onready var _play_button: Button = $PlayButton


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_play_button.grab_focus()  # Enter/Space starts the game on keyboard.


func _on_play_pressed() -> void:
	AudioManager.play_music("gameplay")
	get_tree().change_scene_to_file(GAME_SCENE)
