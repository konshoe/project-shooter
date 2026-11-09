extends CanvasLayer
## Phase 1 HUD: score (top-left) and lives (top-right). Display only — it reads
## from GameState and never changes it.

@onready var _score_label: Label = $ScoreLabel
@onready var _lives_label: Label = $LivesLabel


func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.life_lost.connect(_on_lives_changed)
	GameState.run_reset.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_on_score_changed(GameState.score)
	_on_lives_changed(GameState.lives)


func _on_score_changed(score: int) -> void:
	_score_label.text = "Score: %d" % score


func _on_lives_changed(lives: int) -> void:
	_lives_label.text = "Lives: %d" % lives
