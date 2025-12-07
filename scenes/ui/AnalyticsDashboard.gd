extends Control

## ═══════════════════════════════════════════════════════════════════
## ANALYTICS DASHBOARD
## Research data visualization and export interface
## ═══════════════════════════════════════════════════════════════════

@onready var session_id_label = $ScrollContainer/VBoxContainer/SessionInfo/VBox/SessionID
@onready var duration_label = $ScrollContainer/VBoxContainer/SessionInfo/VBox/Duration
@onready var games_played_label = $ScrollContainer/VBoxContainer/SessionInfo/VBox/GamesPlayed

@onready var avg_accuracy_label = $ScrollContainer/VBoxContainer/FormativeData/VBox/AvgAccuracy
@onready var avg_time_label = $ScrollContainer/VBoxContainer/FormativeData/VBox/AvgTime
@onready var total_mistakes_label = $ScrollContainer/VBoxContainer/FormativeData/VBox/TotalMistakes
@onready var difficulty_progression_label = $ScrollContainer/VBoxContainer/FormativeData/VBox/DifficultyProgression

@onready var posttest_score_label = $ScrollContainer/VBoxContainer/SummativeData/VBox/Score
@onready var conceptual_label = $ScrollContainer/VBoxContainer/SummativeData/VBox/Conceptual
@onready var application_label = $ScrollContainer/VBoxContainer/SummativeData/VBox/Application
@onready var retention_label = $ScrollContainer/VBoxContainer/SummativeData/VBox/Retention

@onready var gameplay_perf_label = $ScrollContainer/VBoxContainer/CorrelationPanel/VBox/GameplayPerf
@onready var test_score_label = $ScrollContainer/VBoxContainer/CorrelationPanel/VBox/TestScore
@onready var correlation_label = $ScrollContainer/VBoxContainer/CorrelationPanel/VBox/Correlation
@onready var interpretation_label = $ScrollContainer/VBoxContainer/CorrelationPanel/VBox/Interpretation

@onready var adaptations_label = $ScrollContainer/VBoxContainer/AlgorithmStats/VBox/Adaptations
@onready var window_size_label = $ScrollContainer/VBoxContainer/AlgorithmStats/VBox/WindowSize
@onready var avg_latency_label = $ScrollContainer/VBoxContainer/AlgorithmStats/VBox/AvgLatency

var session_data: Dictionary = {}

func _ready() -> void:
	_load_analytics_data()
	_populate_dashboard()

func _load_analytics_data() -> void:
	if not AdaptiveDifficulty:
		return
	
	session_data = AdaptiveDifficulty.export_complete_session()

func _populate_dashboard() -> void:
	if session_data.is_empty():
		return
	
	# Session Info
	session_id_label.text = "Session ID: %s" % session_data.get("session_id", "N/A")
	
	var duration_seconds = session_data.get("session_duration", 0)
	var minutes = int(duration_seconds / 60)
	var seconds = int(duration_seconds) % 60
	duration_label.text = "Duration: %d:%02d" % [minutes, seconds]
	
	var gameplay = session_data.get("gameplay", {})
	games_played_label.text = "Games Played: %d" % gameplay.get("total_games_played", 0)
	
	# Formative Assessment
	var perf_history = gameplay.get("performance_history", [])
	if perf_history.size() > 0:
		var total_accuracy = 0.0
		var total_time = 0.0
		var total_mistakes = 0
		
		for perf in perf_history:
			total_accuracy += perf.get("accuracy", 0.0)
			total_time += perf.get("reaction_time", 0) / 1000.0
			total_mistakes += perf.get("mistakes", 0)
		
		avg_accuracy_label.text = "Average Accuracy: %.0f%%" % ((total_accuracy / perf_history.size()) * 100)
		avg_time_label.text = "Average Reaction Time: %.1fs" % (total_time / perf_history.size())
		total_mistakes_label.text = "Total Mistakes: %d" % total_mistakes
	
	# Difficulty Progression
	var difficulty_changes = gameplay.get("difficulty_timeline", [])
	if difficulty_changes.size() > 0:
		var progression = ""
		for change in difficulty_changes:
			if not progression.is_empty():
				progression += " → "
			progression += change.get("new_difficulty", "?")
		difficulty_progression_label.text = "Difficulty Progression: %s" % progression
	
	# Summative Assessment
	var posttest = session_data.get("posttest", {})
	var score = posttest.get("score", 0)
	var total_questions = posttest.get("total_questions", 15)
	var percentage = (float(score) / total_questions) * 100 if total_questions > 0 else 0
	posttest_score_label.text = "Post-Test Score: %d/%d (%.0f%%)" % [score, total_questions, percentage]
	
	var breakdown = posttest.get("category_breakdown", {})
	conceptual_label.text = "  Conceptual: %.0f%%" % breakdown.get("conceptual", 0.0)
	application_label.text = "  Application: %.0f%%" % breakdown.get("application", 0.0)
	retention_label.text = "  Retention: %.0f%%" % breakdown.get("retention", 0.0)
	
	# Correlation Analysis
	var research = session_data.get("research_validation", {})
	var gameplay_perf = research.get("gameplay_performance", 0.0)
	var knowledge_score = research.get("knowledge_retention", 0.0)
	var correlation = research.get("correlation_coefficient", 0.0)
	
	gameplay_perf_label.text = "Gameplay Performance: %.1f%%" % gameplay_perf
	test_score_label.text = "Knowledge Retention: %.1f%%" % knowledge_score
	correlation_label.text = "Correlation (r): %.2f" % correlation
	
	# Color code correlation
	if abs(correlation) >= 0.7:
		correlation_label.modulate = Color(0.3, 1.0, 0.6)
		interpretation_label.text = "✅ STRONG correlation - Algorithm successfully facilitated learning transfer."
	elif abs(correlation) >= 0.4:
		correlation_label.modulate = Color(1.0, 0.9, 0.3)
		interpretation_label.text = "⚠️ MODERATE correlation - Some learning transfer occurred."
	else:
		correlation_label.modulate = Color(1.0, 0.5, 0.3)
		interpretation_label.text = "❌ WEAK correlation - Limited learning transfer detected."
	
	# Algorithm Stats
	var algo_stats = session_data.get("algorithm_stats", {})
	adaptations_label.text = "Total Adaptations: %d" % algo_stats.get("total_adaptations", 0)
	window_size_label.text = "Rolling Window Size: %d games" % algo_stats.get("window_size", 5)
	avg_latency_label.text = "Average Latency: %.0fms" % algo_stats.get("avg_latency_ms", 0)

func _on_export_json_pressed() -> void:
	if AdaptiveDifficulty:
		AdaptiveDifficulty.export_to_json_file()
		_show_notification("✅ JSON data exported to user://")

func _on_export_csv_pressed() -> void:
	_export_to_csv()
	_show_notification("✅ CSV data exported to user://")

func _on_view_raw_pressed() -> void:
	# Show raw data in a popup
	var popup = Window.new()
	popup.title = "Raw Session Data"
	popup.size = Vector2i(800, 600)
	
	var text_edit = TextEdit.new()
	text_edit.text = JSON.stringify(session_data, "\t")
	text_edit.editable = false
	text_edit.anchors_preset = Control.PRESET_FULL_RECT
	
	popup.add_child(text_edit)
	add_child(popup)
	popup.popup_centered()

func _on_close_pressed() -> void:
	queue_free()

func _export_to_csv() -> void:
	if not AdaptiveDifficulty:
		return
	
	var csv_content = "# WATERWISE RESEARCH DATA EXPORT\n"
	csv_content += "# Session ID: %s\n\n" % session_data.get("session_id", "N/A")
	
	# Performance History
	csv_content += "## PERFORMANCE HISTORY\n"
	csv_content += "Game_Number,Accuracy,Reaction_Time_MS,Mistakes,Difficulty,Timestamp\n"
	
	var gameplay = session_data.get("gameplay", {})
	var perf_history = gameplay.get("performance_history", [])
	
	for i in range(perf_history.size()):
		var perf = perf_history[i]
		csv_content += "%d,%.2f,%d,%d,%s,%d\n" % [
			i + 1,
			perf.get("accuracy", 0.0),
			perf.get("reaction_time", 0),
			perf.get("mistakes", 0),
			perf.get("difficulty", ""),
			perf.get("timestamp", 0)
		]
	
	# Post-Test Answers
	csv_content += "\n## POST-TEST ANSWERS\n"
	csv_content += "Question_ID,Category,Selected_Answer,Correct_Answer,Is_Correct,Time_Taken\n"
	
	var posttest = session_data.get("posttest", {})
	var answers = posttest.get("answers", [])
	
	for answer in answers:
		csv_content += "%d,%s,%d,%d,%s,%.2f\n" % [
			answer.get("question_id", 0),
			answer.get("category", ""),
			answer.get("answer_selected", 0),
			answer.get("correct_answer", 0),
			"TRUE" if answer.get("is_correct", false) else "FALSE",
			answer.get("time_to_answer", 0.0)
		]
	
	# Save to file
	var file_path = "user://research_data_%s.csv" % session_data.get("session_id", "export")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(csv_content)
		file.close()
		print("CSV exported to: %s" % file_path)

func _show_notification(message: String) -> void:
	var label = Label.new()
	label.text = message
	label.position = Vector2(get_viewport_rect().size.x / 2 - 150, 50)
	label.modulate = Color(0.3, 1.0, 0.5)
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)
	
	await get_tree().create_timer(3.0).timeout
	label.queue_free()
