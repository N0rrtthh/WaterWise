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


func _loc(key: String, fallback: String) -> String:
	if Localization:
		var translated = Localization.get_text(key)
		if translated != key:
			return translated
	return fallback


func _fmt_loc(key: String, fallback: String, values: Array) -> String:
	var pattern = _loc(key, fallback)
	if values.is_empty():
		return pattern
	if values.size() == 1:
		return pattern % values[0]
	return pattern % values

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_results(
	p1_score: int,
	p2_score: int,
	team_total: int,
	lives: int,
	rounds: int,
	next_roles: Dictionary
) -> void:
	# Display round results and countdown to next round.
	visible = true
	if AudioManager:
		AudioManager.play_fanfare()
	
	# Update labels
	title_label.text = _fmt_loc(
		"round_transition_complete",
		"ROUND %d COMPLETE!",
		[rounds]
	)
	p1_score_label.text = _fmt_loc(
		"round_transition_p1_gain",
		"Player 1: +%d",
		[p1_score]
	)
	p2_score_label.text = _fmt_loc(
		"round_transition_p2_gain",
		"Player 2: +%d",
		[p2_score]
	)
	team_score_label.text = _fmt_loc(
		"round_transition_team_total",
		"Team Total: %d",
		[team_total]
	)
	lives_label.text = _fmt_loc(
		"round_transition_lives",
		"Lives: %s",
		["❤️".repeat(lives)]
	)
	rounds_label.text = _fmt_loc(
		"round_transition_rounds_survived",
		"Rounds Survived: %d",
		[rounds]
	)
	
	# Show next roles
	next_round_label.text = _fmt_loc(
		"round_transition_next_round",
		"Next Round:\nP1: %s | P2: %s",
		[
		next_roles.get(1, "Player 1"),
		next_roles.get(2, "Player 2")
		]
	)
	
	countdown = TRANSITION_TIME
	countdown_label.text = _fmt_loc(
		"round_transition_countdown",
		"Next round in %.0fs...",
		[countdown]
	)
	
	# Animate in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).from(0.0)

func _process(delta: float) -> void:
	if not visible:
		return
	
	countdown -= delta
	countdown_label.text = _fmt_loc(
		"round_transition_countdown",
		"Next round in %.0fs...",
		[max(0, countdown)]
	)
	
	if countdown <= 0:
		_transition_to_next_round()

func _transition_to_next_round() -> void:
	# Fade out and emit signal.
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	visible = false
	transition_complete.emit()
