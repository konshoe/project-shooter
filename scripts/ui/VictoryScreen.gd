extends CanvasLayer
## Shown when GameState.game_won fires (all levels cleared). Pauses the game and
## offers Play Again or Main Menu.
##
## Expects these nodes, marked "Access as Unique Name" in the scene:
## %ScoreLabel (Label), %PlayAgainButton (Button), %MainMenuButton (Button).

const GAME_SCENE := "res://scenes/game/GameWorld.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

@onready var _score_label: Label = %ScoreLabel
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	# Must keep running while the tree is paused, or the buttons wouldn't work.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameState.game_won.connect(_on_game_won)
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)


func _on_game_won() -> void:
	_score_label.text = "SCORE: %d" % GameState.score
	visible = true
	get_tree().paused = true
	_play_again_button.grab_focus()  # So Enter/Space works on keyboard.


func _on_play_again_pressed() -> void:
	_start_scene(GAME_SCENE)


func _on_main_menu_pressed() -> void:
	_start_scene(MAIN_MENU_SCENE)


## Pause state belongs to the SceneTree and would carry over, so unpause first.
func _start_scene(path: String) -> void:
	GameState.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
