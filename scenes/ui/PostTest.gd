extends Control

## ═══════════════════════════════════════════════════════════════════
## POST-TEST UI CONTROLLER
## Summative Assessment System
## ═══════════════════════════════════════════════════════════════════

signal test_completed(results: Dictionary)

@onready var title_label = $Panel/MarginContainer/VBoxContainer/Title
@onready var question_number_label = $Panel/MarginContainer/VBoxContainer/QuestionNumber
@onready var question_text_label = $Panel/MarginContainer/VBoxContainer/QuestionText
@onready var option_a_button = $Panel/MarginContainer/VBoxContainer/OptionsList/OptionA
@onready var option_b_button = $Panel/MarginContainer/VBoxContainer/OptionsList/OptionB
@onready var option_c_button = $Panel/MarginContainer/VBoxContainer/OptionsList/OptionC
@onready var option_d_button = $Panel/MarginContainer/VBoxContainer/OptionsList/OptionD
@onready var progress_bar = $Panel/MarginContainer/VBoxContainer/ProgressBar
@onready var timer_label = $Panel/MarginContainer/VBoxContainer/Timer

var questions: Array = []
var current_question_index: int = 0
var start_time: float = 0.0
var option_buttons: Array[Button] = []

func _ready() -> void:
	await get_tree().process_frame
	option_buttons = [option_a_button, option_b_button, option_c_button, option_d_button]
	
	# Get questions from AdaptiveDifficulty
	if AdaptiveDifficulty:
		questions = AdaptiveDifficulty.get_posttest_questions()
		AdaptiveDifficulty.start_posttest()
	
	if questions.is_empty():
		push_error("No questions loaded!")
		return
	
	start_time = Time.get_unix_time_from_system()
	_display_question(0)

func _process(_delta: float) -> void:
	_update_timer()

func _display_question(index: int) -> void:
	if index >= questions.size():
		_finish_test()
		return
	
	current_question_index = index
	var question = questions[index]
	
	# Update UI
	question_number_label.text = "Question %d of %d" % [index + 1, questions.size()]
	question_text_label.text = question["question"]
	
	# Set options
	var options = question["options"]
	var labels = ["A", "B", "C", "D"]
	for i in range(min(4, options.size())):
		if i < option_buttons.size():
			option_buttons[i].text = "%s) %s" % [labels[i], options[i]]
			option_buttons[i].disabled = false
			option_buttons[i].modulate = Color.WHITE
	
	# Update progress
	progress_bar.value = index

func _on_option_selected(option_index: int) -> void:
	# Disable all buttons to prevent double-clicking
	for btn in option_buttons:
		btn.disabled = true
	
	var question = questions[current_question_index]
	var is_correct = (option_index == question["correct_answer"])
	
	# Visual feedback
	if is_correct:
		option_buttons[option_index].modulate = Color.GREEN
		_play_correct_sound()
	else:
		option_buttons[option_index].modulate = Color.RED
		option_buttons[question["correct_answer"]].modulate = Color.GREEN
		_play_wrong_sound()
	
	# Submit to AdaptiveDifficulty
	if AdaptiveDifficulty:
		AdaptiveDifficulty.submit_posttest_answer(question["id"], option_index)
	
	# Wait before next question
	await get_tree().create_timer(1.5).timeout
	_display_question(current_question_index + 1)

func _finish_test() -> void:
	if AdaptiveDifficulty:
		var results = AdaptiveDifficulty.get_posttest_results()
		test_completed.emit(results)
		
		# Navigate to results screen
		get_tree().change_scene_to_file("res://scenes/ui/PostTestResults.tscn")

func _update_timer() -> void:
	var elapsed = Time.get_unix_time_from_system() - start_time
	var minutes = int(elapsed / 60)
	var seconds = int(elapsed) % 60
	timer_label.text = "⏱️ Time: %d:%02d" % [minutes, seconds]

func _play_correct_sound() -> void:
	if AudioManager:
		AudioManager.play_success()

func _play_wrong_sound() -> void:
	if AudioManager:
		AudioManager.play_damage()
