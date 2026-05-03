extends Control

@onready var title_label: Label = $Margin/Panel/VBox/Title
@onready var summary_label: Label = $Margin/Panel/VBox/Summary
@onready var list_container: VBoxContainer = $Margin/Panel/VBox/Scroll/Rows
@onready var back_button: Button = $Margin/Panel/VBox/BackButton

func _ready() -> void:
	title_label.text = _loc("leaderboard_title", "SINGLE-PLAYER LEADERBOARD")
	back_button.text = _loc("back", "BACK")
	back_button.pressed.connect(_on_back_pressed)
	_populate_rows()

func _loc(key: String, fallback: String) -> String:
	if Localization:
		var translated = Localization.get_text(key)
		if translated != key:
			return translated
	return fallback

func _populate_rows() -> void:
	for child in list_container.get_children():
		child.queue_free()

	var leaderboard: Array = []
	if SaveManager and SaveManager.has_method("get_sp_session_leaderboard"):
		leaderboard = SaveManager.get_sp_session_leaderboard()

	if leaderboard.is_empty():
		summary_label.text = _loc("leaderboard_empty", "No single-player scores yet.")
		return

	var best_score := int(leaderboard[0].get("score", 0))
	summary_label.text = _loc(
		"leaderboard_summary",
		"Best score: %d | Runs saved: %d"
	) % [best_score, leaderboard.size()]

	for entry in leaderboard:
		var score_value := int(entry.get("score", 0))
		var rank := _compute_rank(score_value)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var pos_label = Label.new()
		pos_label.text = "#%d" % int(entry.get("position", 0))
		pos_label.custom_minimum_size = Vector2(56, 0)
		pos_label.add_theme_font_size_override("font_size", 22)
		pos_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
		row.add_child(pos_label)

		var tier_label = Label.new()
		tier_label.text = "Tier %s" % rank
		tier_label.custom_minimum_size = Vector2(90, 0)
		tier_label.add_theme_font_size_override("font_size", 22)
		tier_label.add_theme_color_override("font_color", _rank_color(rank))
		row.add_child(tier_label)

		var score_label = Label.new()
		score_label.text = "%d pts" % score_value
		score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.add_theme_font_size_override("font_size", 22)
		score_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
		row.add_child(score_label)

		list_container.add_child(row)

		var divider = ColorRect.new()
		divider.custom_minimum_size = Vector2(0, 2)
		divider.color = Color(1.0, 1.0, 1.0, 0.08)
		list_container.add_child(divider)

func _compute_rank(score: int) -> String:
	if score >= 900:
		return "S"
	if score >= 700:
		return "A"
	if score >= 500:
		return "B"
	if score >= 300:
		return "C"
	return "D"

func _rank_color(rank: String) -> Color:
	match rank:
		"S": return Color(1.0, 0.85, 0.1)
		"A": return Color(0.3, 1.0, 0.5)
		"B": return Color(0.5, 0.85, 1.0)
		"C": return Color(0.9, 0.7, 0.4)
		_:
			return Color(0.8, 0.62, 0.62)

func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if GameManager and GameManager.has_method("transition_to_scene"):
		GameManager.transition_to_scene("res://scenes/ui/InitialScreen.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")
