extends Control

@onready var result_title = $CenterContainer/VBoxContainer/ResultTitle
@onready var accuracy_label = $CenterContainer/VBoxContainer/Stats/Accuracy
@onready var time_label = $CenterContainer/VBoxContainer/Stats/Time
@onready var mistakes_label = $CenterContainer/VBoxContainer/Stats/Mistakes
@onready var difficulty_label = $CenterContainer/VBoxContainer/Stats/Difficulty

var current_accuracy: float = 0.0

func _ready() -> void:
	await get_tree().process_frame
	_display_results()
	_animate_entrance()

func _display_results() -> void:
	if not GameManager:
		return
	
	# Get last completed game results from AdaptiveDifficulty
	if AdaptiveDifficulty and AdaptiveDifficulty.performance_history.size() > 0:
		var last_perf = AdaptiveDifficulty.performance_history[-1]
		
		current_accuracy = last_perf["accuracy"]
		var time_ms = last_perf["reaction_time"]
		var mistakes = last_perf["mistakes"]
		var difficulty = last_perf["difficulty"]
		
		# Display stats
		accuracy_label.text = "Accuracy: %.0f%%" % (current_accuracy * 100)
		time_label.text = "Time: %.1fs" % (time_ms / 1000.0)
		mistakes_label.text = "Mistakes: %d" % mistakes
		difficulty_label.text = "Difficulty: %s" % difficulty
		
		# Update title based on performance
		if current_accuracy >= 0.9:
			result_title.text = "🌟 PERFECT!"
			result_title.modulate = Color(1, 0.9, 0.3)
		elif current_accuracy >= 0.7:
			result_title.text = "🎉 SUCCESS!"
			result_title.modulate = Color(0.3, 1, 0.5)
		else:
			result_title.text = "✅ COMPLETE"
			result_title.modulate = Color(0.7, 0.9, 1)

func _animate_entrance() -> void:
	modulate.a = 0
	scale = Vector2(0.8, 0.8)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK)

func _on_continue_pressed() -> void:
	if GameManager:
		GameManager.start_next_minigame()

func _on_retry_pressed() -> void:
	if GameManager:
		GameManager.replay_current_minigame()
