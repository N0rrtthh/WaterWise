extends Control

## ═══════════════════════════════════════════════════════════════════
## POST-TEST RESULTS SCREEN
## Displays correlation analysis and research validation
## ═══════════════════════════════════════════════════════════════════

@onready var score_display = $Panel/MarginContainer/VBoxContainer/ScoreDisplay
@onready var grade_label = $Panel/MarginContainer/VBoxContainer/GradeLabel

@onready var conceptual_score = $Panel/MarginContainer/VBoxContainer/Categories/Conceptual/Score
@onready var application_score = $Panel/MarginContainer/VBoxContainer/Categories/Application/Score
@onready var retention_score = $Panel/MarginContainer/VBoxContainer/Categories/Retention/Score
@onready var behavioral_score = $Panel/MarginContainer/VBoxContainer/Categories/Behavioral/Score

@onready var gameplay_perf_label = $Panel/MarginContainer/VBoxContainer/CorrelationData/GameplayPerf
@onready var test_score_label = $Panel/MarginContainer/VBoxContainer/CorrelationData/TestScore
@onready var correlation_label = $Panel/MarginContainer/VBoxContainer/CorrelationData/Correlation
@onready var interpretation_label = $Panel/MarginContainer/VBoxContainer/CorrelationData/Interpretation

func _ready() -> void:
	await get_tree().process_frame
	_display_results()
	_animate_entrance()

func _display_results() -> void:
	if not AdaptiveDifficulty:
		return
	
	# Get results from AdaptiveDifficulty
	var results = AdaptiveDifficulty.get_posttest_results()
	var correlation = AdaptiveDifficulty.calculate_correlation()
	
	# Display score
	score_display.text = "%d/%d (%d%%)" % [
		results["correct_answers"],
		results["total_questions"],
		int(results["percentage"])
	]
	
	# Display grade
	var grade = _calculate_grade(results["percentage"])
	grade_label.text = grade["emoji"] + " " + grade["text"]
	grade_label.modulate = grade["color"]
	
	# Display category breakdown
	var breakdown = results["category_breakdown"]
	
	if breakdown.has("conceptual"):
		conceptual_score.text = "%d%%" % int(breakdown["conceptual"])
		conceptual_score.modulate = _get_score_color(breakdown["conceptual"])
	
	if breakdown.has("application"):
		application_score.text = "%d%%" % int(breakdown["application"])
		application_score.modulate = _get_score_color(breakdown["application"])
	
	if breakdown.has("retention"):
		retention_score.text = "%d%%" % int(breakdown["retention"])
		retention_score.modulate = _get_score_color(breakdown["retention"])
	
	if breakdown.has("behavioral"):
		behavioral_score.text = "%d%%" % int(breakdown["behavioral"])
		behavioral_score.modulate = _get_score_color(breakdown["behavioral"])
	
	# Display correlation data
	gameplay_perf_label.text = "Gameplay Performance: %d%%" % int(correlation["gameplay_performance"])
	test_score_label.text = "Knowledge Score: %d%%" % int(correlation["posttest_knowledge"])
	correlation_label.text = "Correlation (r): " + str(correlation["correlation_coefficient"]).pad_decimals(2)
	
	# Interpretation
	interpretation_label.text = "[CHECK] " + correlation["interpretation"]
	
	# Color code correlation
	var r = correlation["correlation_coefficient"]
	if abs(r) >= 0.7:
		correlation_label.modulate = Color(0.3, 1.0, 0.6)  # Green - Strong
	elif abs(r) >= 0.4:
		correlation_label.modulate = Color(1.0, 0.9, 0.3)  # Yellow - Moderate
	else:
		correlation_label.modulate = Color(1.0, 0.5, 0.3)  # Orange - Weak

func _calculate_grade(percentage: float) -> Dictionary:
	if percentage >= 90:
		return {"text": "EXCELLENT!", "emoji": "***", "color": Color(0.3, 1.0, 0.3)}
	elif percentage >= 80:
		return {"text": "VERY GOOD!", "emoji": "**", "color": Color(0.5, 1.0, 0.5)}
	elif percentage >= 70:
		return {"text": "GOOD", "emoji": "*", "color": Color(1.0, 0.9, 0.3)}
	elif percentage >= 60:
		return {"text": "PASSING", "emoji": "[OK]", "color": Color(1.0, 0.7, 0.3)}
	else:
		return {"text": "NEEDS IMPROVEMENT", "emoji": "[!]", "color": Color(1.0, 0.5, 0.5)}

func _get_score_color(score: float) -> Color:
	if score >= 80:
		return Color(0.3, 1.0, 0.5)  # Green
	elif score >= 60:
		return Color(1.0, 0.9, 0.3)  # Yellow
	else:
		return Color(1.0, 0.5, 0.3)  # Orange

func _animate_entrance() -> void:
	# Fade in animation
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func _on_export_button_pressed() -> void:
	if AdaptiveDifficulty:
		AdaptiveDifficulty.export_to_json_file()
		
		# Show confirmation
		var label = Label.new()
		label.text = "✅ Data exported successfully!"
		label.position = Vector2(400, 50)
		label.modulate = Color(0.3, 1.0, 0.5)
		add_child(label)
		
		await get_tree().create_timer(2.0).timeout
		label.queue_free()

func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
