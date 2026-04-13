extends Control

## ═══════════════════════════════════════════════════════════════════
## ROUND TRANSITION SCREEN
## ═══════════════════════════════════════════════════════════════════
## Shows results between rounds in multiplayer mode
## ═══════════════════════════════════════════════════════════════════

signal transition_complete()

@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var p1_score_label = $MarginContainer/VBoxContainer/ScoresContainer/P1ScoreLabel
@onready var p2_score_label = $MarginContainer/VBoxContainer/ScoresContainer/P2ScoreLabel
@onready var team_score_label = $MarginContainer/VBoxContainer/TeamScoreLabel
@onready var lives_label = $MarginContainer/VBoxContainer/LivesLabel
@onready var rounds_label = $MarginContainer/VBoxContainer/RoundsLabel
@onready var next_round_label = $MarginContainer/VBoxContainer/NextRoundLabel
@onready var countdown_label = $MarginContainer/VBoxContainer/CountdownLabel

const TRANSITION_TIME: float = 5.0  # Seconds to show transition screen

var countdown: float = TRANSITION_TIME

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_results(p1_score: int, p2_score: int, team_total: int, lives: int, rounds: int, next_roles: Dictionary) -> void:
	"""Display round results and countdown to next round"""
	visible = true
	if AudioManager:
		AudioManager.play_fanfare()
	
	# Update labels
	title_label.text = "ROUND %d COMPLETE!" % rounds
	p1_score_label.text = "Player 1: +%d" % p1_score
	p2_score_label.text = "Player 2: +%d" % p2_score
	team_score_label.text = "Team Total: %d" % team_total
	lives_label.text = "Lives: " + "❤️".repeat(lives)
	rounds_label.text = "Rounds Survived: %d" % rounds
	
	# Show next roles
	next_round_label.text = "Next Round:\nP1: %s | P2: %s" % [
		next_roles.get(1, "Player 1"),
		next_roles.get(2, "Player 2")
	]
	
	countdown = TRANSITION_TIME
	countdown_label.text = "Next round in %.0fs..." % countdown
	
	# Animate in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).from(0.0)

func _process(delta: float) -> void:
	if not visible:
		return
	
	countdown -= delta
	countdown_label.text = "Next round in %.0fs..." % max(0, countdown)
	
	if countdown <= 0:
		_transition_to_next_round()

func _transition_to_next_round() -> void:
	"""Fade out and emit signal"""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	visible = false
	transition_complete.emit()
