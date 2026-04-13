extends Control

## ═══════════════════════════════════════════════════════════════════
## DEMONSTRATION LAUNCHER - For Panelist Testing
## ═══════════════════════════════════════════════════════════════════
## Main menu for testing the adaptive difficulty algorithms
## Shows both Single-Player and Multiplayer demonstrations
## ═══════════════════════════════════════════════════════════════════

var games_played: int = 0
var info_label: Label = null

func _ready() -> void:
	# Reset adaptive difficulty system
	if has_node("/root/AdaptiveDifficulty"):
		var adaptive_difficulty = get_node("/root/AdaptiveDifficulty")
		adaptive_difficulty.reset()
	
	var _screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.15, 0.25)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Main VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🎮 WATERWISE ALGORITHM DEMO\nFor Panelist Review"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Rule-Based Rolling Window Algorithm\nWindow Size: 5 Games | Adapts Every 2 Games"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	
	vbox.add_child(HSeparator.new())
	
	# Info panel
	var info_panel = PanelContainer.new()
	var info_style = StyleBoxFlat.new()
	info_style.bg_color = Color(0, 0, 0, 0.5)
	info_style.border_color = Color(0.3, 0.6, 1.0)
	info_style.set_border_width_all(2)
	info_style.set_corner_radius_all(10)
	info_panel.add_theme_stylebox_override("panel", info_style)
	vbox.add_child(info_panel)
	
	var info_margin = MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 30)
	info_margin.add_theme_constant_override("margin_right", 30)
	info_margin.add_theme_constant_override("margin_top", 20)
	info_margin.add_theme_constant_override("margin_bottom", 20)
	info_panel.add_child(info_margin)
	
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 20)
	info_label.add_theme_color_override("font_color", Color.WHITE)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_margin.add_child(info_label)
	_update_info()
	
	vbox.add_child(HSeparator.new())
	
	# Button: Play Demo Game
	var play_btn = _create_button("▶️ PLAY DEMO GAME", Color(0.2, 0.8, 0.3))
	play_btn.pressed.connect(_on_play_demo)
	vbox.add_child(play_btn)
	
	# Button: Run Automated Test
	var test_btn = _create_button("🧪 RUN AUTOMATED TEST", Color(0.8, 0.6, 0.2))
	test_btn.pressed.connect(_on_run_test)
	vbox.add_child(test_btn)
	
	# Button: Test G-Counter (Multiplayer)
	var gcounter_btn = _create_button("🔢 TEST G-COUNTER (Multiplayer)", Color(0.6, 0.3, 0.9))
	gcounter_btn.pressed.connect(_on_test_gcounter)
	vbox.add_child(gcounter_btn)
	
	vbox.add_child(HSeparator.new())
	
	# Button: Reset System
	var reset_btn = _create_button("🔄 RESET ALGORITHM", Color(0.7, 0.2, 0.2))
	reset_btn.pressed.connect(_on_reset)
	vbox.add_child(reset_btn)
	
	# Button: Return to Main Game
	var back_btn = _create_button("← BACK TO MAIN GAME", Color(0.4, 0.4, 0.4))
	back_btn.pressed.connect(_on_back)
	vbox.add_child(back_btn)

func _create_button(text: String, color: Color) -> Button:
	"""Create a styled button"""
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(500, 70)
	btn.add_theme_font_size_override("font_size", 24)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.2)
	hover_style.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	return btn

func _update_info() -> void:
	"""Update the info display"""
	if not info_label or not has_node("/root/AdaptiveDifficulty"):
		return
	
	var adaptive_difficulty = get_node("/root/AdaptiveDifficulty")
	var status = adaptive_difficulty.get_algorithm_status()
	
	var text = "📊 CURRENT STATUS\n\n"
	text += "Games Played: %d\n" % status["total_games_played"]
	text += "Window: %d/5 games\n" % status["games_in_window"]
	text += "Difficulty: %s\n" % status["current_difficulty"]
	
	if status["algorithm_active"]:
		text += "Φ (Proficiency): %.4f" % status["proficiency_index"]
	else:
		text += "Status: Collecting initial data..."
	
	info_label.text = text

func _on_play_demo() -> void:
	"""Start the demo minigame"""
	print("🎮 Starting Demo Game...")
	get_tree().change_scene_to_file("res://test/DemoMinigame.tscn")

func _on_run_test() -> void:
	"""Run automated algorithm test"""
	print("🧪 Starting Automated Test...")
	get_tree().change_scene_to_file("res://test/AutomatedTest.tscn")

func _on_test_gcounter() -> void:
	"""Test G-Counter algorithm"""
	print("🔢 Starting G-Counter Test...")
	get_tree().change_scene_to_file("res://test/GCounterTest.tscn")

func _on_reset() -> void:
	"""Reset the adaptive difficulty system"""
	if AdaptiveDifficulty:
		AdaptiveDifficulty.reset()
		print("🔄 Algorithm Reset")
		_update_info()

func _on_back() -> void:
	"""Return to main game"""
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

func _process(_delta: float) -> void:
	# Update info every frame
	_update_info()
