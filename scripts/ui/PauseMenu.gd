extends CanvasLayer
## Pause overlay, toggled with Escape or the Android back button.
##
## process_mode is ALWAYS (set in PauseMenu.tscn) so it keeps receiving input
## while the tree is paused.

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

@onready var _resume_button: Button = $Buttons/ResumeButton
@onready var _main_menu_button: Button = $Buttons/MainMenuButton


func _ready() -> void:
	hide()
	_resume_button.pressed.connect(_resume)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# KEY_BACK is the Android back button.
	if event.keycode != KEY_ESCAPE and event.keycode != KEY_BACK:
		return
	get_viewport().set_input_as_handled()
	if visible:
		_resume()
	elif not get_tree().paused:
		# Only pause when nothing else has (upgrade picker, game over).
		_pause()


func _pause() -> void:
	show()
	get_tree().paused = true
	_resume_button.grab_focus()  # So Enter/Space works on keyboard.


func _resume() -> void:
	hide()
	get_tree().paused = false


func _on_main_menu_pressed() -> void:
	# Unpause first: pause state belongs to the SceneTree and would carry over
	# into the next scene.
	get_tree().paused = false
	AudioManager.stop_music()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
