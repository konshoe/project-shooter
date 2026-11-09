extends Node
## Autoload: score, lives and run state for the current run.
## Other systems change these only through the methods below, and react to the
## signals rather than polling.

signal score_changed(score: int)
signal life_lost(lives: int)
signal game_over
## Emitted by reset(), so displays can refresh both score and lives.
signal run_reset

const STARTING_LIVES := 3

var score: int = 0
var lives: int = STARTING_LIVES


func add_score(points: int) -> void:
	score += int(points * (1.0 + UpgradeManager.get_stat("score_multiplier", 0.0)))
	score_changed.emit(score)


func lose_life() -> void:
	if lives <= 0:
		return  # Already game over; ignore extra hits.
	lives -= 1
	life_lost.emit(lives)
	if lives == 0:
		game_over.emit()


func reset() -> void:
	score = 0
	lives = STARTING_LIVES
	UpgradeManager.reset()
	run_reset.emit()
