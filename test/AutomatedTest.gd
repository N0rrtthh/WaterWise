extends Control

## ═══════════════════════════════════════════════════════════════════
## AUTOMATED TEST SCENE - Visual Test Runner
## ═══════════════════════════════════════════════════════════════════
## Runs automated tests and shows results in real-time
## ═══════════════════════════════════════════════════════════════════

var output_label: RichTextLabel = null
var test_running: bool = false

func _ready() -> void:
	var _screen_size = get_viewport_rect().size  # Prefix unused variable
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Main container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🧪 AUTOMATED ALGORITHM TEST"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Output panel
	var output_panel = PanelContainer.new()
	output_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.8)
	panel_style.border_color = Color(0.3, 0.6, 1.0)
	panel_style.set_border_width_all(2)
	output_panel.add_theme_stylebox_override("panel", panel_style)
	vbox.add_child(output_panel)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_panel.add_child(scroll)
	
	output_label = RichTextLabel.new()
	output_label.bbcode_enabled = true
	output_label.fit_content = true
	output_label.scroll_following = true
	output_label.add_theme_font_size_override("normal_font_size", 18)
	output_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
	scroll.add_child(output_label)
	
	# Back button
	var back_btn = Button.new()
	back_btn.text = "← BACK TO LAUNCHER"
	back_btn.custom_minimum_size = Vector2(0, 60)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(_on_back)
	vbox.add_child(back_btn)
	
	# Start tests (deferred to ensure UI is ready)
	call_deferred("_kickoff_tests")

func _kickoff_tests() -> void:
	_log("[color=orange]⏳ Bootstrapping automated test...[/color]")
	_run_tests()

func _log(text: String) -> void:
	# Add text to output
	output_label.text += text + "\n"
	print(text)

func _run_tests() -> void:
	# Run all automated tests
	test_running = true
	
	# Validate autoload
	if not has_node("/root/AdaptiveDifficulty"):
		_log("[color=red]❌ ERROR: AdaptiveDifficulty autoload not found! Enable it in Project Settings > Autoload.[/color]")
		test_running = false
		return

	_log("[color=cyan]📡 AdaptiveDifficulty detected. Starting runs...[/color]")

	print("🧪 AutomatedTest: _run_tests() called")
	_log("[color=cyan]╔════════════════════════════════════════════════╗[/color]")
	_log("[color=cyan]║  ROLLING WINDOW ALGORITHM VERIFICATION TEST    ║[/color]")
	_log("[color=cyan]╚════════════════════════════════════════════════╝[/color]")
	_log("")
	_log("[color=yellow]Initializing tests...[/color]")
	
	await get_tree().create_timer(0.5).timeout
	
	# Test 1: Poor Performance → Easy
	await _test_poor_performance()
	await get_tree().create_timer(1.0).timeout
	
	# Test 2: Improved Performance → Medium
	await _test_improved_performance()
	await get_tree().create_timer(1.0).timeout
	
	# Test 3: Expert Performance → Hard
	await _test_expert_performance()
	await get_tree().create_timer(1.0).timeout
	
	_log("")
	_log("[color=lime]╔════════════════════════════════════════════════╗[/color]")
	_log("[color=lime]║           ✅ ALL TESTS COMPLETE                ║[/color]")
	_log("[color=lime]╚════════════════════════════════════════════════╝[/color]")
	
	test_running = false

func _test_poor_performance() -> void:
	# Test: Poor performance should lead to Easy difficulty
	_log("[color=yellow]━━━ TEST 1: Poor Performance ━━━[/color]")
	_log("Simulating 3 games with low accuracy...")
	_log("")
	
	# Check if AdaptiveDifficulty autoload exists
	if not has_node("/root/AdaptiveDifficulty"):
		_log("[color=red]❌ ERROR: AdaptiveDifficulty autoload not found![/color]")
		_log("[color=orange]Make sure AdaptiveDifficulty is enabled in Project Settings > Autoload[/color]")
		return
	
	var adaptive_difficulty = get_node("/root/AdaptiveDifficulty")
	adaptive_difficulty.reset()
	_log("[color=cyan]🔄 Reset algorithm[/color]")
	
	for i in range(3):
		adaptive_difficulty.add_performance(0.3, 8000, 5, "TestGame")
		_log("  Game %d: 30%% accuracy, 8s, 5 mistakes" % (i + 1))
		await get_tree().create_timer(0.3).timeout
	
	var difficulty = adaptive_difficulty.get_current_difficulty()
	if difficulty == "Easy":
		_log("[color=lime]✅ PASS: Moved to Easy difficulty[/color]")
	else:
		_log("[color=red]❌ FAIL: Expected Easy, got %s[/color]" % difficulty)
	_log("")

func _test_improved_performance() -> void:
	# Test: Improved performance should lead to Medium difficulty
	_log("[color=yellow]━━━ TEST 2: Improved Performance ━━━[/color]")
	_log("Simulating 5 games with moderate accuracy...")
	_log("")
	
	var adaptive_difficulty = get_node("/root/AdaptiveDifficulty")
	
	for i in range(5):
		adaptive_difficulty.add_performance(0.7, 6000, 2, "TestGame")
		_log("  Game %d: 70%% accuracy, 6s, 2 mistakes" % (i + 1))
		await get_tree().create_timer(0.3).timeout
	
	var difficulty = adaptive_difficulty.get_current_difficulty()
	if difficulty == "Medium":
		_log("[color=lime]✅ PASS: Moved to Medium difficulty[/color]")
	else:
		_log("[color=red]❌ FAIL: Expected Medium, got %s[/color]" % difficulty)
	_log("")

func _test_expert_performance() -> void:
	# Test: Expert performance should lead to Hard difficulty
	_log("[color=yellow]━━━ TEST 3: Expert Performance ━━━[/color]")
	_log("Simulating 5 games with high accuracy...")
	_log("")
	
	var adaptive_difficulty = get_node("/root/AdaptiveDifficulty")
	
	for i in range(5):
		adaptive_difficulty.add_performance(0.95, 4000, 0, "TestGame")
		_log("  Game %d: 95%% accuracy, 4s, 0 mistakes" % (i + 1))
		await get_tree().create_timer(0.3).timeout
	
	var difficulty = adaptive_difficulty.get_current_difficulty()
	if difficulty == "Hard":
		_log("[color=lime]✅ PASS: Moved to Hard difficulty[/color]")
	else:
		_log("[color=red]❌ FAIL: Expected Hard, got %s[/color]" % difficulty)
	_log("")

func _on_back() -> void:
	# Return to launcher
	if not test_running:
		get_tree().change_scene_to_file("res://test/DemoLauncher.tscn")
