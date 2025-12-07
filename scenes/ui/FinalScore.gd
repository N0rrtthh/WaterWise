extends Control

@onready var total_score_label = $CenterContainer/VBoxContainer/TotalScoreLabel
@onready var high_score_label = $CenterContainer/VBoxContainer/HighScoreLabel
@onready var new_record_label = $CenterContainer/VBoxContainer/NewRecordLabel
@onready var continue_btn = $CenterContainer/VBoxContainer/ContinueButton

func _ready():
	# Get scores from GameManager
	var total_score = GameManager.session_score if GameManager else 0
	var high_score = GameManager.high_score if GameManager else 0
	var is_new_record = total_score > high_score and total_score > 0
	
	# Display scores
	total_score_label.text = "%s: %d" % [Localization.tr("total_score") if Localization else "TOTAL SCORE", total_score]
	high_score_label.text = "%s: %d" % [Localization.tr("high_score") if Localization else "HIGH SCORE", high_score]
	
	# Show new record message
	if is_new_record:
		new_record_label.visible = true
		new_record_label.text = Localization.tr("new_high_score") if Localization else "🎉 NEW HIGH SCORE! 🎉"
		# Animate
		var tween = create_tween().set_loops()
		tween.tween_property(new_record_label, "scale", Vector2(1.2, 1.2), 0.5)
		tween.tween_property(new_record_label, "scale", Vector2(1.0, 1.0), 0.5)
	else:
		new_record_label.visible = false
	
	# Connect button
	continue_btn.pressed.connect(_on_continue_pressed)

func _on_continue_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")
