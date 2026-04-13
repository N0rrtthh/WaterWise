extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## DEMO: ONE-CLICK ALGORITHM SANDBOX
## Tap green/red bubbles to simulate wins/losses and watch Φ update
## ═══════════════════════════════════════════════════════════════════

const MAX_HISTORY := 5

# UI
var ui_layer: CanvasLayer
var algo_display: Label
var history_rows: Array = []
var status_label: Label

# State
var games_simulated: int = 0
var history: Array = []

func _apply_difficulty_settings() -> void:
	super._apply_difficulty_settings()
	# Keep short sessions; timer stays paused because we simulate instantly
	match current_difficulty:
		"Easy":
			game_duration = 18.0
		"Medium":
			game_duration = 12.0
		"Hard":
			game_duration = 8.0

func _ready():
	game_name = "Demo: Algorithm Sandbox"
	game_instruction_text = "Tap GREEN to simulate a win, RED for a loss. Run five quick games to see Φ evolve."
	game_mode = "simulation"
	show_timer = false
	show_quota = false
	timer_starts_paused = true

	super._ready()
	
	# Hide base class HUD
	if hud_layer:
		hud_layer.hide()

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100  # Put on top
	add_child(ui_layer)

	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.2, 0.32)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse
	ui_layer.add_child(bg)

	_create_layout()
	_update_algorithm_display()
	_refresh_history_ui()
	
	# Enable game immediately so buttons work
	game_active = true
	game_start_time = Time.get_ticks_msec()

# Override to skip instruction overlay wait
func _wait_for_input():
	return

func _create_layout() -> void:
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_bottom = 1
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 24
	root.offset_bottom = -24
	root.add_theme_constant_override("separation", 16)
	root.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow mouse through
	ui_layer.add_child(root)

	status_label = Label.new()
	status_label.text = "Games simulated: 0"
	status_label.add_theme_font_size_override("font_size", 22)
	root.add_child(status_label)

	# Algorithm panel
	var algo_panel = PanelContainer.new()
	algo_panel.custom_minimum_size = Vector2(0, 180)
	root.add_child(algo_panel)

	var algo_style = StyleBoxFlat.new()
	algo_style.bg_color = Color(0, 0, 0, 0.78)
	algo_style.border_color = Color(0.35, 0.7, 1.0)
	algo_style.border_width_left = 3
	algo_style.border_width_right = 3
	algo_style.border_width_top = 3
	algo_style.border_width_bottom = 3
	algo_style.corner_radius_top_left = 10
	algo_style.corner_radius_top_right = 10
	algo_style.corner_radius_bottom_left = 10
	algo_style.corner_radius_bottom_right = 10
	algo_panel.add_theme_stylebox_override("panel", algo_style)

	var algo_margin = MarginContainer.new()
	algo_margin.add_theme_constant_override("margin_left", 14)
	algo_margin.add_theme_constant_override("margin_right", 14)
	algo_margin.add_theme_constant_override("margin_top", 14)
	algo_margin.add_theme_constant_override("margin_bottom", 14)
	algo_panel.add_child(algo_margin)

	algo_display = Label.new()
	algo_display.add_theme_font_size_override("font_size", 16)
	algo_display.add_theme_color_override("font_color", Color.WHITE)
	algo_display.autowrap_mode = TextServer.AUTOWRAP_WORD
	algo_margin.add_child(algo_display)

	# History chart
	var history_panel = PanelContainer.new()
	history_panel.custom_minimum_size = Vector2(0, 220)
	root.add_child(history_panel)

	var history_style = StyleBoxFlat.new()
	history_style.bg_color = Color(0, 0, 0, 0.6)
	history_style.corner_radius_top_left = 10
	history_style.corner_radius_top_right = 10
	history_style.corner_radius_bottom_left = 10
	history_style.corner_radius_bottom_right = 10
	history_panel.add_theme_stylebox_override("panel", history_style)

	var history_margin = MarginContainer.new()
	history_margin.add_theme_constant_override("margin_left", 12)
	history_margin.add_theme_constant_override("margin_right", 12)
	history_margin.add_theme_constant_override("margin_top", 12)
	history_margin.add_theme_constant_override("margin_bottom", 12)
	history_panel.add_child(history_margin)

	var history_box = VBoxContainer.new()
	history_box.add_theme_constant_override("separation", 10)
	history_margin.add_child(history_box)

	var history_title = Label.new()
	history_title.text = "Last 5 simulated games"
	history_title.add_theme_font_size_override("font_size", 18)
	history_box.add_child(history_title)

	for i in range(MAX_HISTORY):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		history_box.add_child(row)

		var label = Label.new()
		label.text = "Game %d: -" % (i + 1)
		label.custom_minimum_size = Vector2(130, 0)
		row.add_child(label)

		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 1
		bar.step = 0.001
		bar.custom_minimum_size = Vector2(260, 26)
		bar.show_percentage = false
		row.add_child(bar)

		history_rows.append({"label": label, "bar": bar})

	# Bubble buttons
	var bubble_row = HBoxContainer.new()
	bubble_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bubble_row.anchor_left = 0.25
	bubble_row.anchor_right = 0.75
	bubble_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bubble_row.add_theme_constant_override("separation", 30)
	root.add_child(bubble_row)

	var win_btn = _create_bubble_button("💧 Win (Green)", Color(0.2, 0.8, 0.45, 0.95))
	win_btn.pressed.connect(func(): _simulate_game(true))
	bubble_row.add_child(win_btn)

	var lose_btn = _create_bubble_button("🔴 Lose (Red)", Color(0.9, 0.25, 0.25, 0.95))
	lose_btn.pressed.connect(func(): _simulate_game(false))
	bubble_row.add_child(lose_btn)

	var exit_btn = Button.new()
	exit_btn.text = "Back to Demo Launcher"
	exit_btn.custom_minimum_size = Vector2(260, 50)
	exit_btn.add_theme_font_size_override("font_size", 20)
	exit_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://test/DemoLauncher.tscn"))
	root.add_child(exit_btn)

func _create_bubble_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 90)
	btn.add_theme_font_size_override("font_size", 24)

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

	return btn

func _simulate_game(win: bool) -> void:
	var ad = null
	if has_node("/root/AdaptiveDifficulty"):
		ad = get_node("/root/AdaptiveDifficulty")
	games_simulated += 1

	if win:
		correct_actions = 1
		mistakes_made = 0
	else:
		correct_actions = 0
		mistakes_made = 1
	total_actions = 1
	var accuracy = 1.0 if win else 0.0
	var reaction_time = 600

	if ad:
		ad.add_performance(accuracy, reaction_time, mistakes_made, game_name)

	var status = ad.get_algorithm_status() if ad else {
		"proficiency_index": accuracy,
		"current_difficulty": "-",
		"games_in_window": min(games_simulated, MAX_HISTORY),
		"total_games_played": games_simulated,
		"algorithm_active": games_simulated >= 5
	}
	var entry = {
		"index": games_simulated,
		"win": win,
		"phi": status.get("proficiency_index", accuracy),
		"difficulty": status.get("current_difficulty", "-")
	}
	history.append(entry)
	if history.size() > MAX_HISTORY:
		history.remove_at(0)

	status_label.text = "Games simulated: %d (showing last %d)" % [games_simulated, min(games_simulated, MAX_HISTORY)]
	_update_algorithm_display()
	_refresh_history_ui()

func _update_algorithm_display() -> void:
	if not algo_display:
		return

	var has_ad = has_node("/root/AdaptiveDifficulty")
	var adaptive_difficulty = null
	if has_ad:
		adaptive_difficulty = get_node("/root/AdaptiveDifficulty")
	var status = adaptive_difficulty.get_algorithm_status() if has_ad else {
		"proficiency_index": history.back().get("phi", 0.0) if history.size() > 0 else 0.0,
		"current_difficulty": history.back().get("difficulty", "-") if history.size() > 0 else "-",
		"games_in_window": min(games_simulated, MAX_HISTORY),
		"total_games_played": games_simulated,
		"algorithm_active": games_simulated >= 5,
		"weighted_accuracy": history.back().get("phi", 0.0) if history.size() > 0 else 0.0,
		"consistency_penalty": 0.0
	}

	var text = "🧮 ROLLING WINDOW ALGORITHM\n"
	text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
	text += "📊 Window Size: 5 games\n"
	text += "🎮 Games Played: %d\n" % status.get("total_games_played", 0)
	text += "📏 Games in Window: %d/5\n" % status.get("games_in_window", 0)
	text += "\n"

	if status.get("algorithm_active", false):
		text += "✅ ALGORITHM ACTIVE\n"
		text += "Φ (Proficiency): %.4f\n" % status.get("proficiency_index", 0.0)
		text += "  = WMA (%.4f) - CP (%.4f)\n" % [status.get("weighted_accuracy", 0.0), status.get("consistency_penalty", 0.0)]
		text += "\n"
		var phi = status.get("proficiency_index", 0.0)
		if phi < 0.5:
			text += "📍 Φ < 0.50 → EASY\n"
		elif phi > 0.85:
			text += "📍 Φ > 0.85 → HARD\n"
		else:
			text += "📍 0.50 ≤ Φ ≤ 0.85 → MEDIUM\n"
	else:
		if has_ad:
			text += "⏳ Collecting data...\n"
		else:
			text += "ℹ️ AdaptiveDifficulty not found; showing local simulation.\n"
		var remaining = max(0, (adaptive_difficulty.min_games_before_adaptation if has_ad else 5) - status.get("games_in_window", 0))
		text += "Need %d more game(s)\n" % remaining

	text += "\n"
	text += "🎯 Current: %s" % status.get("current_difficulty", "-")

	algo_display.text = text

func _refresh_history_ui() -> void:
	for i in range(history_rows.size()):
		var label: Label = history_rows[i]["label"]
		var bar: ProgressBar = history_rows[i]["bar"]

		if i >= history.size():
			label.text = "Game %d: -" % (i + 1)
			bar.value = 0
			bar.add_theme_stylebox_override("fill", StyleBoxFlat.new())
			continue

		var entry = history[i]
		var phi: float = entry.get("phi", 0.0)
		var win: bool = entry.get("win", false)
		var difficulty: String = entry.get("difficulty", "-")
		var game_number: int = entry.get("index", i + 1)

		var outcome_text = "WIN" if win else "LOSE"
		label.text = "Game %d: %s | Φ=%.2f | %s" % [game_number, outcome_text, phi, difficulty]
		bar.value = clamp(phi, 0.0, 1.0)

		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(0.2, 0.8, 0.45, 0.9) if win else Color(0.9, 0.25, 0.25, 0.9)
		fill.corner_radius_top_left = 6
		fill.corner_radius_top_right = 6
		fill.corner_radius_bottom_left = 6
		fill.corner_radius_bottom_right = 6
		bar.add_theme_stylebox_override("fill", fill)

func _process(_delta: float) -> void:
	if algo_display:
		_update_algorithm_display()
