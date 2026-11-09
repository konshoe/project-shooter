class_name HUD
extends CanvasLayer
## HUD: score (top-left), level/wave (top-centre), lives (top-right). Display
## only — it never changes game state.

const LIFE_ICON := "♥"  # U+2665
const LIFE_LOST_ALPHA := 0.25

@onready var _score_label: Label = $ScoreLabel
@onready var _progress_label: Label = $ProgressLabel
@onready var _lives_row: HBoxContainer = $LivesRow

var _life_icons: Array[Label] = []


func _ready() -> void:
	for i in GameState.STARTING_LIVES:
		var icon := Label.new()
		icon.text = LIFE_ICON
		icon.add_theme_font_size_override("font_size", 28)
		icon.add_theme_color_override("font_color", Color(1.0, 0.3, 0.35))
		_lives_row.add_child(icon)
		_life_icons.append(icon)

	GameState.score_changed.connect(_on_score_changed)
	GameState.life_lost.connect(_on_lives_changed)
	GameState.run_reset.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_on_score_changed(GameState.score)
	_on_lives_changed(GameState.lives)


## Called by GameWorld at the start of each wave.
func set_progress(level: int, wave: int, wave_total: int) -> void:
	_progress_label.text = "LV%d  WAVE %d/%d" % [level, wave, wave_total]


func _on_score_changed(score: int) -> void:
	_score_label.text = "Score: %s" % _format_score(score)


func _on_lives_changed(lives: int) -> void:
	for i in _life_icons.size():
		_life_icons[i].modulate.a = 1.0 if i < lives else LIFE_LOST_ALPHA


## 10000 -> "10,000"
func _format_score(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		if (digits.length() - i) % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
