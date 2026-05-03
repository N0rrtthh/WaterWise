extends Control

const UI_FONT := preload("res://fonts/NTBrickSans.otf")

var _list_box: VBoxContainer
var _back_button: Button


func _ready() -> void:
	_build_background()
	_build_layout()
	_populate_scores()


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


func _build_background() -> void:
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.12, 0.2)
	add_child(bg)


func _build_layout() -> void:
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 560)
	center.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.98, 1.0)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = _loc("leaderboard_title", "🏆 LEADERBOARD")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UI_FONT:
		title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.15, 0.18, 0.25))
	vbox.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_box)

	_back_button = Button.new()
	_back_button.text = _loc("back", "⬅️ BACK")
	_back_button.custom_minimum_size = Vector2(220, 56)
	_back_button.add_theme_font_size_override("font_size", 22)
	_back_button.pressed.connect(_on_back_pressed)
	vbox.add_child(_back_button)


func _populate_scores() -> void:
	if not _list_box:
		return
	for child in _list_box.get_children():
		child.queue_free()
	var scores: Array = []
	if SaveManager and SaveManager.has_method("get_sp_session_scores"):
		scores = SaveManager.get_sp_session_scores()

	if scores.is_empty():
		var empty_label = Label.new()
		empty_label.text = _loc("leaderboard_empty", "No scores yet.")
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UI_FONT:
			empty_label.add_theme_font_override("font", UI_FONT)
		empty_label.add_theme_font_size_override("font_size", 22)
		empty_label.add_theme_color_override("font_color", Color(0.3, 0.35, 0.45))
		_list_box.add_child(empty_label)
		return

	for i in range(scores.size()):
		var score_value = int(scores[i])
		var rank = _compute_rank(score_value)
		var row = Label.new()
		row.text = _fmt_loc(
			"leaderboard_score_row",
			"%d. %s - %d pts",
			[i + 1, rank, score_value]
		)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UI_FONT:
			row.add_theme_font_override("font", UI_FONT)
		row.add_theme_font_size_override("font_size", 22)
		row.add_theme_color_override("font_color", Color(0.25, 0.3, 0.4))
		_list_box.add_child(row)


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


func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if GameManager and GameManager.has_method("transition_to_scene"):
		GameManager.transition_to_scene("res://scenes/ui/InitialScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")
