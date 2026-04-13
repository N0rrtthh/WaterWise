extends Control

## ═══════════════════════════════════════════════════════════════════
## MULTIPLAYER GAME OVER SCREEN
## ═══════════════════════════════════════════════════════════════════
## Shows final team results when lives run out
## ═══════════════════════════════════════════════════════════════════

signal return_to_lobby_pressed()

@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var final_score_label = $MarginContainer/VBoxContainer/FinalScoreLabel
@onready var rounds_survived_label = $MarginContainer/VBoxContainer/RoundsSurvivedLabel
@onready var p1_contribution_label = $MarginContainer/VBoxContainer/ContributionsContainer/P1Label
@onready var p2_contribution_label = $MarginContainer/VBoxContainer/ContributionsContainer/P2Label
@onready var return_button = $MarginContainer/VBoxContainer/ReturnButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if return_button:
		return_button.pressed.connect(_on_return_button_pressed)

func show_game_over(final_score: int, rounds: int, p1_score: int, p2_score: int) -> void:
	# Display game over screen with team stats
	visible = true
	get_tree().paused = true
	
	# Update labels
	title_label.text = "GAME OVER"
	subtitle_label.text = "TEAM EFFORT!"
	final_score_label.text = "Final Score: %d" % final_score
	rounds_survived_label.text = "Rounds Survived: %d" % rounds
	
	# Show contributions
	var p1_percent = 0.0
	var p2_percent = 0.0
	if final_score > 0:
		p1_percent = (float(p1_score) / float(final_score)) * 100.0
		p2_percent = (float(p2_score) / float(final_score)) * 100.0
	
	p1_contribution_label.text = "Player 1: %d points (%.1f%%)" % [p1_score, p1_percent]
	p2_contribution_label.text = "Player 2: %d points (%.1f%%)" % [p2_score, p2_percent]
	
	# Animate in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).from(0.0)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2(0.5, 0.5)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _on_return_button_pressed() -> void:
	# Return to multiplayer lobby
	get_tree().paused = false
	return_to_lobby_pressed.emit()
	
	if NetworkManager:
		NetworkManager.return_to_lobby()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
