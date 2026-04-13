extends Control

## ═══════════════════════════════════════════════════════════════════
## ALGORITHM DEMO SCENE - THESIS PRESENTATION MODE
## ═══════════════════════════════════════════════════════════════════
## Interactive demonstration of the Rolling Window Adaptive Difficulty
## algorithm for thesis defense. Shows:
## 1. Real-time Φ (Proficiency Index) calculation
## 2. Visual rolling window with weighted bars
## 3. Decision tree path highlighting
## 4. Step-by-step algorithm explanation
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SCENE REFERENCES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# These will be created dynamically in _ready()
var title_label: Label
var difficulty_label: Label
var phi_label: Label
var wma_label: Label
var penalty_label: Label
var window_container: VBoxContainer
var decision_tree_container: VBoxContainer
var formula_label: RichTextLabel
var simulate_poor_btn: Button
var simulate_medium_btn: Button
var simulate_expert_btn: Button
var reset_btn: Button
var play_game_btn: Button
var back_btn: Button
var step_explanation: RichTextLabel

# Algorithm visualization
var window_bars: Array[ProgressBar] = []
var current_step: int = 0
var animation_timer: Timer

# Colors for visualization
const COLOR_EASY = Color(0.2, 0.8, 0.2)      # Green
const COLOR_MEDIUM = Color(0.9, 0.7, 0.1)    # Yellow/Orange
const COLOR_HARD = Color(0.9, 0.2, 0.2)      # Red
const COLOR_HIGHLIGHT = Color(0.3, 0.7, 1.0) # Blue highlight

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_update_display()
	
	if AdaptiveDifficulty:
		AdaptiveDifficulty.algorithm_update.connect(_on_algorithm_update)
		AdaptiveDifficulty.difficulty_changed.connect(_on_difficulty_changed)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UI CONSTRUCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _build_ui() -> void:
	# Set up the main container
	var main_margin = MarginContainer.new()
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_top", 20)
	main_margin.add_theme_constant_override("margin_bottom", 20)
	main_margin.add_theme_constant_override("margin_left", 20)
	main_margin.add_theme_constant_override("margin_right", 20)
	add_child(main_margin)
	
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_child(scroll)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 15)
	scroll.add_child(main_vbox)
	
	# ═══════════════════════════════════════════════════════════════════
	# HEADER SECTION
	# ═══════════════════════════════════════════════════════════════════
	
	title_label = Label.new()
	title_label.text = "🎮 ADAPTIVE DIFFICULTY ALGORITHM DEMO"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	main_vbox.add_child(title_label)
	
	var subtitle = Label.new()
	subtitle.text = "Rule-Based Rolling Window with Proficiency Index (Φ)"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.modulate = Color(0.7, 0.7, 0.7)
	main_vbox.add_child(subtitle)
	
	main_vbox.add_child(HSeparator.new())
	
	# ═══════════════════════════════════════════════════════════════════
	# CURRENT STATE PANEL
	# ═══════════════════════════════════════════════════════════════════
	
	var state_panel = _create_panel("📊 CURRENT ALGORITHM STATE")
	main_vbox.add_child(state_panel)
	
	var state_grid = GridContainer.new()
	state_grid.columns = 2
	state_grid.add_theme_constant_override("h_separation", 30)
	state_grid.add_theme_constant_override("v_separation", 10)
	state_panel.get_child(0).add_child(state_grid)
	
	# Difficulty
	state_grid.add_child(_create_label("Current Difficulty:"))
	difficulty_label = _create_value_label("MEDIUM", COLOR_MEDIUM)
	state_grid.add_child(difficulty_label)
	
	# Phi
	state_grid.add_child(_create_label("Proficiency Index (Φ):"))
	phi_label = _create_value_label("0.000", Color.WHITE)
	state_grid.add_child(phi_label)
	
	# WMA
	state_grid.add_child(_create_label("Weighted Moving Avg:"))
	wma_label = _create_value_label("0.000", Color.WHITE)
	state_grid.add_child(wma_label)
	
	# Penalty
	state_grid.add_child(_create_label("Consistency Penalty:"))
	penalty_label = _create_value_label("0.000", Color.WHITE)
	state_grid.add_child(penalty_label)
	
	# ═══════════════════════════════════════════════════════════════════
	# ROLLING WINDOW VISUALIZATION
	# ═══════════════════════════════════════════════════════════════════
	
	var window_panel = _create_panel("📏 ROLLING WINDOW (Last 5 Games)")
	main_vbox.add_child(window_panel)
	
	window_container = VBoxContainer.new()
	window_container.add_theme_constant_override("separation", 8)
	window_panel.get_child(0).add_child(window_container)
	
	# Create 5 window slots
	for i in range(5):
		var slot_hbox = HBoxContainer.new()
		slot_hbox.add_theme_constant_override("separation", 10)
		
		var weight_label = Label.new()
		weight_label.text = "w=%d" % (i + 1)
		weight_label.custom_minimum_size.x = 50
		weight_label.add_theme_font_size_override("font_size", 14)
		slot_hbox.add_child(weight_label)
		
		var bar = ProgressBar.new()
		bar.max_value = 100
		bar.value = 0
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 30
		bar.show_percentage = true
		window_bars.append(bar)
		slot_hbox.add_child(bar)
		
		var game_label = Label.new()
		game_label.text = "(empty)"
		game_label.custom_minimum_size.x = 80
		game_label.add_theme_font_size_override("font_size", 12)
		game_label.modulate = Color(0.6, 0.6, 0.6)
		slot_hbox.add_child(game_label)
		
		window_container.add_child(slot_hbox)
	
	# ═══════════════════════════════════════════════════════════════════
	# FORMULA PANEL
	# ═══════════════════════════════════════════════════════════════════
	
	var formula_panel = _create_panel("🔬 ALGORITHM FORMULA")
	main_vbox.add_child(formula_panel)
	
	formula_label = RichTextLabel.new()
	formula_label.bbcode_enabled = true
	formula_label.fit_content = true
	formula_label.custom_minimum_size.y = 120
	formula_label.text = _get_formula_bbcode()
	formula_panel.get_child(0).add_child(formula_label)
	
	# ═══════════════════════════════════════════════════════════════════
	# DECISION TREE PANEL
	# ═══════════════════════════════════════════════════════════════════
	
	var tree_panel = _create_panel("🌳 DECISION TREE RULES")
	main_vbox.add_child(tree_panel)
	
	decision_tree_container = VBoxContainer.new()
	decision_tree_container.add_theme_constant_override("separation", 10)
	tree_panel.get_child(0).add_child(decision_tree_container)
	
	_build_decision_tree()
	
	# ═══════════════════════════════════════════════════════════════════
	# SIMULATION BUTTONS
	# ═══════════════════════════════════════════════════════════════════
	
	var sim_panel = _create_panel("🎮 SIMULATE PERFORMANCE")
	main_vbox.add_child(sim_panel)
	
	var btn_grid = GridContainer.new()
	btn_grid.columns = 2
	btn_grid.add_theme_constant_override("h_separation", 10)
	btn_grid.add_theme_constant_override("v_separation", 10)
	sim_panel.get_child(0).add_child(btn_grid)
	
	simulate_poor_btn = _create_button("😓 Simulate POOR\n(30% accuracy)", COLOR_EASY)
	simulate_poor_btn.pressed.connect(_simulate_poor_performance)
	btn_grid.add_child(simulate_poor_btn)
	
	simulate_medium_btn = _create_button("😊 Simulate MEDIUM\n(70% accuracy)", COLOR_MEDIUM)
	simulate_medium_btn.pressed.connect(_simulate_medium_performance)
	btn_grid.add_child(simulate_medium_btn)
	
	simulate_expert_btn = _create_button("🔥 Simulate EXPERT\n(95% accuracy)", COLOR_HARD)
	simulate_expert_btn.pressed.connect(_simulate_expert_performance)
	btn_grid.add_child(simulate_expert_btn)
	
	reset_btn = _create_button("🔄 RESET\nAlgorithm", Color(0.5, 0.5, 0.5))
	reset_btn.pressed.connect(_reset_algorithm)
	btn_grid.add_child(reset_btn)
	
	# ═══════════════════════════════════════════════════════════════════
	# STEP-BY-STEP EXPLANATION
	# ═══════════════════════════════════════════════════════════════════
	
	var explanation_panel = _create_panel("📝 STEP-BY-STEP EXPLANATION")
	main_vbox.add_child(explanation_panel)
	
	step_explanation = RichTextLabel.new()
	step_explanation.bbcode_enabled = true
	step_explanation.fit_content = true
	step_explanation.custom_minimum_size.y = 150
	step_explanation.text = "[i]Simulate a game performance to see the algorithm in action![/i]"
	explanation_panel.get_child(0).add_child(step_explanation)
	
	# ═══════════════════════════════════════════════════════════════════
	# NAVIGATION BUTTONS
	# ═══════════════════════════════════════════════════════════════════
	
	main_vbox.add_child(HSeparator.new())
	
	var nav_hbox = HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 20)
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(nav_hbox)
	
	back_btn = _create_button("← Back to Menu", Color(0.4, 0.4, 0.4))
	back_btn.pressed.connect(_go_back)
	nav_hbox.add_child(back_btn)
	
	play_game_btn = _create_button("▶ Play Real Game", COLOR_HIGHLIGHT)
	play_game_btn.pressed.connect(_play_game)
	nav_hbox.add_child(play_game_btn)

func _create_panel(title: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_lbl)
	
	return panel

func _create_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	return lbl

func _create_value_label(text: String, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.modulate = color
	return lbl

func _create_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 70)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.modulate = color
	return btn

func _get_formula_bbcode() -> String:
	return """[center][b]PROFICIENCY INDEX FORMULA[/b][/center]

[color=cyan]Φ = WMA - CP[/color]

Where:
• [color=yellow]WMA[/color] = Weighted Moving Average = Σ(w_i × accuracy_i) / Σ(w_i)
• [color=yellow]CP[/color] = Consistency Penalty = min(σ / 5000, 0.2)
• [color=yellow]σ[/color] = Standard Deviation of reaction times

[b]Weights:[/b] Linear (1, 2, 3, 4, 5) - Recent games matter MORE!"""

func _build_decision_tree() -> void:
	var rules = [
		{
			"condition": "Φ < 0.5",
			"result": "EASY", "color": COLOR_EASY,
			"desc": "Player struggling or erratic"
		},
		{
			"condition": "Φ > 0.85",
			"result": "HARD", "color": COLOR_HARD,
			"desc": "Player mastering content"
		},
		{
			"condition": "0.5 ≤ Φ ≤ 0.85",
			"result": "MEDIUM", "color": COLOR_MEDIUM,
			"desc": "Optimal learning zone (Flow)"
		}
	]
	
	for rule in rules:
		var rule_hbox = HBoxContainer.new()
		rule_hbox.add_theme_constant_override("separation", 10)
		
		var condition_lbl = Label.new()
		condition_lbl.text = "IF %s →" % rule["condition"]
		condition_lbl.custom_minimum_size.x = 150
		condition_lbl.add_theme_font_size_override("font_size", 14)
		rule_hbox.add_child(condition_lbl)
		
		var result_lbl = Label.new()
		result_lbl.text = rule["result"]
		result_lbl.custom_minimum_size.x = 80
		result_lbl.modulate = rule["color"]
		result_lbl.add_theme_font_size_override("font_size", 16)
		rule_hbox.add_child(result_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = "(%s)" % rule["desc"]
		desc_lbl.modulate = Color(0.6, 0.6, 0.6)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		rule_hbox.add_child(desc_lbl)
		
		decision_tree_container.add_child(rule_hbox)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIMULATION FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _simulate_poor_performance() -> void:
	if AdaptiveDifficulty:
		# Simulate poor performance: low accuracy, slow time, many mistakes
		var accuracy = randf_range(0.25, 0.40)
		var time = randi_range(15000, 20000)  # 15-20 seconds (slow)
		var mistakes = randi_range(4, 7)
		
		AdaptiveDifficulty.add_performance(accuracy, time, mistakes, "SimulatedGame")
		_show_simulation_step("POOR", accuracy, time, mistakes)
		_update_display()

func _simulate_medium_performance() -> void:
	if AdaptiveDifficulty:
		# Simulate medium performance: decent accuracy, moderate time
		var accuracy = randf_range(0.65, 0.75)
		var time = randi_range(8000, 12000)  # 8-12 seconds
		var mistakes = randi_range(1, 3)
		
		AdaptiveDifficulty.add_performance(accuracy, time, mistakes, "SimulatedGame")
		_show_simulation_step("MEDIUM", accuracy, time, mistakes)
		_update_display()

func _simulate_expert_performance() -> void:
	if AdaptiveDifficulty:
		# Simulate expert performance: high accuracy, fast time, no mistakes
		var accuracy = randf_range(0.90, 0.98)
		var time = randi_range(4000, 7000)  # 4-7 seconds (fast!)
		var mistakes = randi_range(0, 1)
		
		AdaptiveDifficulty.add_performance(accuracy, time, mistakes, "SimulatedGame")
		_show_simulation_step("EXPERT", accuracy, time, mistakes)
		_update_display()

func _show_simulation_step(
	performance_type: String, accuracy: float,
	time: int, mistakes: int
) -> void:
	var status = AdaptiveDifficulty.get_algorithm_status()
	var phi = status["proficiency_index"]
	var wma = status["weighted_accuracy"]
	var cp = status["consistency_penalty"]
	
	var explanation = """[b]📥 NEW GAME ADDED: %s Performance[/b]

[color=yellow]Input:[/color]
• Accuracy: %.0f%%
• Reaction Time: %.1f seconds
• Mistakes: %d

[color=cyan]Algorithm Calculation:[/color]
1️⃣ Added to Rolling Window (FIFO - oldest removed if window full)
2️⃣ Calculated WMA = %.3f (recent games weighted 1→5)
3️⃣ Calculated Penalty = %.3f (based on time variance)
4️⃣ [b]Φ = WMA - Penalty = %.3f[/b]

[color=lime]Decision:[/color]
""" % [performance_type, accuracy * 100, time / 1000.0, mistakes, wma, cp, phi]
	
	# Add decision explanation
	if phi < 0.5:
		explanation += "• Φ (%.3f) < 0.5 → [color=green]EASY[/color] difficulty assigned" % phi
	elif phi > 0.85:
		explanation += "• Φ (%.3f) > 0.85 → [color=red]HARD[/color] difficulty assigned" % phi
	else:
		explanation += "• 0.5 ≤ Φ (%.3f) ≤ 0.85 → [color=yellow]MEDIUM[/color] difficulty" % phi
	
	step_explanation.text = explanation

func _reset_algorithm() -> void:
	if AdaptiveDifficulty:
		AdaptiveDifficulty.reset()
		_update_display()
		step_explanation.text = "[i]Algorithm reset! Simulate games to see it adapt.[/i]"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DISPLAY UPDATES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _update_display() -> void:
	if not AdaptiveDifficulty:
		return
	
	var status = AdaptiveDifficulty.get_algorithm_status()
	
	# Update difficulty label
	var diff = status["current_difficulty"]
	difficulty_label.text = diff.to_upper()
	match diff:
		"Easy":
			difficulty_label.modulate = COLOR_EASY
		"Medium":
			difficulty_label.modulate = COLOR_MEDIUM
		"Hard":
			difficulty_label.modulate = COLOR_HARD
	
	# Update metrics
	phi_label.text = "%.3f" % status["proficiency_index"]
	wma_label.text = "%.3f" % status["weighted_accuracy"]
	penalty_label.text = "%.3f" % status["consistency_penalty"]
	
	# Color code phi based on threshold
	var phi = status["proficiency_index"]
	if phi < 0.5:
		phi_label.modulate = COLOR_EASY
	elif phi > 0.85:
		phi_label.modulate = COLOR_HARD
	else:
		phi_label.modulate = COLOR_MEDIUM
	
	# Update window bars
	var window_data = status["window_accuracies"]
	for i in range(5):
		if i < window_data.size():
			var data = window_data[i]
			window_bars[i].value = data["accuracy"] * 100
			
			# Color based on accuracy
			if data["accuracy"] < 0.5:
				window_bars[i].modulate = COLOR_EASY
			elif data["accuracy"] > 0.85:
				window_bars[i].modulate = COLOR_HARD
			else:
				window_bars[i].modulate = COLOR_MEDIUM
			
			# Update label
			var game_label = window_container.get_child(i).get_child(2) as Label
			game_label.text = "%.0f%%" % (data["accuracy"] * 100)
			game_label.modulate = Color.WHITE
		else:
			window_bars[i].value = 0
			window_bars[i].modulate = Color(0.3, 0.3, 0.3)
			
			var game_label = window_container.get_child(i).get_child(2) as Label
			game_label.text = "(empty)"
			game_label.modulate = Color(0.5, 0.5, 0.5)
	
	# Highlight active decision tree rule
	_highlight_active_rule(phi)

func _highlight_active_rule(phi: float) -> void:
	for i in range(decision_tree_container.get_child_count()):
		var rule_hbox = decision_tree_container.get_child(i)
		var is_active = false
		
		if i == 0 and phi < 0.5:
			is_active = true
		elif i == 1 and phi > 0.85:
			is_active = true
		elif i == 2 and phi >= 0.5 and phi <= 0.85:
			is_active = true
		
		# Highlight active rule
		if is_active:
			rule_hbox.modulate = Color(1.2, 1.2, 1.2)
			var condition_lbl = rule_hbox.get_child(0) as Label
			condition_lbl.text = "✓ IF " + ["Φ < 0.5", "Φ > 0.85", "0.5 ≤ Φ ≤ 0.85"][i] + " →"
		else:
			rule_hbox.modulate = Color(0.6, 0.6, 0.6)
			var condition_lbl = rule_hbox.get_child(0) as Label
			condition_lbl.text = "IF " + ["Φ < 0.5", "Φ > 0.85", "0.5 ≤ Φ ≤ 0.85"][i] + " →"

func _connect_signals() -> void:
	pass

func _on_algorithm_update(_metrics: Dictionary) -> void:
	_update_display()

func _on_difficulty_changed(_old: String, _new: String, _reason: String) -> void:
	_update_display()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NAVIGATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _play_game() -> void:
	if GameManager:
		GameManager.start_new_session()
		GameManager.start_next_minigame()
