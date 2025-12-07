class_name MiniGameBase
extends Node2D

## ═══════════════════════════════════════════════════════════════════
## MINI-GAME BASE CLASS
## Template for all water conservation mini-games
## Handles difficulty scaling, performance tracking, and chaos effects
## ═══════════════════════════════════════════════════════════════════

signal game_started()
signal game_completed(accuracy: float, time: int, mistakes: int)
signal game_failed()

## Game Settings
@export var game_name: String = "MiniGame"
@export var game_duration: float = 30.0  # Default duration in seconds

## Game Mode: "quota" = must complete target before time, "survival" = survive until timer ends
@export var game_mode: String = "quota"

## UI Visibility Options
@export var show_timer: bool = true
@export var show_quota: bool = true
@export var timer_starts_paused: bool = false  # For games that start timer after setup

## Performance Tracking
var game_start_time: int = 0
var mistakes_made: int = 0
var correct_actions: int = 0
var total_actions: int = 0
var game_active: bool = false
var timer_running: bool = false  # True when timer has actually started
var lives: int = 3
var current_score: int = 0
var game_instruction_text: String = "TAP TO START!"

## Difficulty Settings (from AdaptiveDifficulty)
var difficulty_settings: Dictionary = {}
var current_difficulty: String = "Medium"

## Chaos Effects
var chaos_effects_active: Array = []

## UI References
var timer_label: Label
var score_label: Label
var mistakes_label: Label
var hud_layer: CanvasLayer
var timer_bar: ProgressBar
var pause_menu: Control
var instruction_overlay: Control

func _ready() -> void:
	await get_tree().process_frame
	
	# Load session lives from GameManager
	if GameManager:
		lives = GameManager.session_lives
	
	_load_difficulty_settings()
	_apply_difficulty_settings()
	_setup_ui()
	_create_instruction_overlay()
	
	# Show instruction overlay, wait for tap to start
	instruction_overlay.visible = true
	await _wait_for_input()
	instruction_overlay.visible = false
	
	# Start game
	start_game()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DIFFICULTY MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _load_difficulty_settings() -> void:
	# Check if we're in multiplayer mode
	var is_multiplayer = GameManager and GameManager.current_game_mode == GameManager.GameMode.MULTIPLAYER_COOP
	
	if is_multiplayer and CoopAdaptation:
		# Multiplayer: Use CoopAdaptation for per-player difficulty
		var my_player_num = GameManager.local_player_num if GameManager else 1
		current_difficulty = CoopAdaptation.get_player_difficulty(my_player_num)
		difficulty_settings = CoopAdaptation.get_difficulty_params(my_player_num)
		chaos_effects_active = difficulty_settings.get("chaos_effects", [])
		
		print("═══════════════════════════════════════════════════════════")
		print("🎮 [MULTIPLAYER] %s - Player %d Difficulty: %s" % [game_name, my_player_num, current_difficulty])
		print("   Speed Multiplier: %.2f" % difficulty_settings.get("speed_multiplier", 1.0))
		print("   Chaos Effects: %s" % str(chaos_effects_active))
		print("═══════════════════════════════════════════════════════════")
	elif AdaptiveDifficulty:
		# Single-player: Use AdaptiveDifficulty (Φ = WMA - CP algorithm)
		difficulty_settings = AdaptiveDifficulty.get_difficulty_settings()
		current_difficulty = AdaptiveDifficulty.get_current_difficulty()
		chaos_effects_active = difficulty_settings.get("chaos_effects", [])
		
		print("═══════════════════════════════════════════════════════════")
		print("🎮 [SINGLE-PLAYER] %s - Difficulty: %s" % [game_name, current_difficulty])
		print("   Speed Multiplier: %.2f" % difficulty_settings.get("speed_multiplier", 1.0))
		print("   Time Limit: %s" % str(difficulty_settings.get("time_limit", "N/A")))
		print("   Chaos Effects: %s" % str(chaos_effects_active))
		print("═══════════════════════════════════════════════════════════")

func _apply_difficulty_settings() -> void:
	# Override this in child classes to apply specific settings
	# Example: adjust spawn rates, timer speeds, etc.
	
	# Apply speed multiplier to game duration
	if difficulty_settings.has("time_limit"):
		game_duration = difficulty_settings["time_limit"]
	
	# Activate chaos effects
	for effect in chaos_effects_active:
		_activate_chaos_effect(effect)

func get_difficulty_multiplier(setting_name: String, default_value: float = 1.0) -> float:
	return difficulty_settings.get(setting_name, default_value)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME FLOW
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func start_game() -> void:
	game_active = true
	game_started.emit()
	
	# Start game timer (unless paused for setup phase)
	if not timer_starts_paused:
		game_start_time = Time.get_ticks_msec()
		timer_running = true
		_start_timer()
	
	# Override this in child classes for specific game logic
	_on_game_start()

## Call this from child class when ready to start the timer
func start_timer_now() -> void:
	game_start_time = Time.get_ticks_msec()
	timer_running = true
	_start_timer()
	
	# Show timer if it was hidden during setup
	if timer_bar:
		timer_bar.visible = show_timer

func end_game(success: bool = true) -> void:
	game_active = false
	timer_running = false
	get_tree().paused = false
	
	# Deduct life if game failed
	if not success:
		_deduct_life()
	
	var reaction_time = Time.get_ticks_msec() - game_start_time
	var accuracy = _calculate_accuracy()
	
	# Always send performance data to algorithm (success or fail)
	if GameManager:
		var droplets_earned = 0
		if success:
			droplets_earned = 10 # Base reward
			if accuracy > 0.9: droplets_earned += 5 # Perfect bonus
			if reaction_time < game_duration * 500: droplets_earned += 5 # Speed bonus
			GameManager.water_droplets += droplets_earned
		
		# Always complete minigame (records performance for algorithm)
		GameManager.complete_minigame(game_name, accuracy, reaction_time, mistakes_made)
	
	game_completed.emit(accuracy, reaction_time, mistakes_made)
	
	# Show tally screen with score
	await _show_tally_screen(success, accuracy, reaction_time)
	
	# Continue to next game
	if GameManager:
		GameManager.start_next_minigame()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

func _calculate_accuracy() -> float:
	if total_actions == 0:
		return 0.0
	return float(correct_actions) / float(total_actions)

func record_action(is_correct: bool) -> void:
	total_actions += 1
	
	if is_correct:
		correct_actions += 1
		current_score += 10
		if score_label:
			score_label.text = "⭐ " + str(current_score)
		_on_correct_action()
	else:
		mistakes_made += 1
		
		# Flash timer red to show time penalty (actual penalty applied in _process)
		if timer_bar:
			var tween = create_tween()
			tween.tween_property(timer_bar, "modulate", Color(2, 0.3, 0.3), 0.15)
			tween.tween_property(timer_bar, "modulate", Color.WHITE, 0.15)
			
			# Also shake the timer
			var original_pos = timer_bar.position
			tween.parallel().tween_property(timer_bar, "position:x", original_pos.x + 10, 0.05)
			tween.tween_property(timer_bar, "position:x", original_pos.x - 10, 0.05)
			tween.tween_property(timer_bar, "position:x", original_pos.x, 0.05)
		
		_on_mistake()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TIMER MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _start_timer() -> void:
	var timer = Timer.new()
	timer.wait_time = game_duration
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	timer.start()

func _on_timer_timeout() -> void:
	if game_active:
		# Survival mode: timer runs out = SUCCESS (you survived!)
		# Quota mode: timer runs out = FAIL (didn't meet target)
		if game_mode == "survival":
			end_game(true)
		else:
			end_game(false)

func get_remaining_time() -> float:
	var elapsed = (Time.get_ticks_msec() - game_start_time) / 1000.0
	return max(0.0, game_duration - elapsed)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CHAOS EFFECTS SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _activate_chaos_effect(effect_name: String) -> void:
	match effect_name:
		"screen_shake_mild":
			_start_screen_shake(0.5)
		"screen_shake_heavy":
			_start_screen_shake(1.0)
		"mud_splatters":
			_spawn_mud_splatters()
		"buzzing_fly":
			_spawn_buzzing_fly()
		"control_reverse":
			_activate_control_reverse()
		"visual_obstruction":
			_create_visual_obstruction()

func _start_screen_shake(intensity: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		var shake_timer = Timer.new()
		shake_timer.wait_time = 0.05
		shake_timer.timeout.connect(func():
			if game_active:
				camera.offset = Vector2(
					randf_range(-intensity * 5, intensity * 5),
					randf_range(-intensity * 5, intensity * 5)
				)
		)
		add_child(shake_timer)
		shake_timer.start()

func _spawn_mud_splatters() -> void:
	# Create random mud splatter sprites
	var splatter_timer = Timer.new()
	splatter_timer.wait_time = 2.0
	splatter_timer.timeout.connect(_create_mud_splatter)
	add_child(splatter_timer)
	splatter_timer.start()

func _create_mud_splatter() -> void:
	var splatter = ColorRect.new()
	splatter.color = Color(0.3, 0.2, 0.1, 0.7)
	splatter.size = Vector2(randf_range(30, 80), randf_range(30, 80))
	splatter.position = Vector2(
		randf_range(0, get_viewport_rect().size.x),
		randf_range(0, get_viewport_rect().size.y)
	)
	add_child(splatter)
	
	# Fade out after some time
	await get_tree().create_timer(5.0).timeout
	var tween = create_tween()
	tween.tween_property(splatter, "modulate:a", 0.0, 1.0)
	tween.finished.connect(splatter.queue_free)

func _spawn_buzzing_fly() -> void:
	# Create an annoying fly that moves around
	var fly = Sprite2D.new()
	fly.modulate = Color.BLACK
	# Would use actual fly sprite
	add_child(fly)
	
	var move_timer = Timer.new()
	move_timer.wait_time = 0.5
	move_timer.timeout.connect(func():
		if game_active:
			var target = Vector2(
				randf_range(50, get_viewport_rect().size.x - 50),
				randf_range(50, get_viewport_rect().size.y - 50)
			)
			var tween = create_tween()
			tween.tween_property(fly, "position", target, 0.5)
	)
	add_child(move_timer)
	move_timer.start()

func _activate_control_reverse() -> void:
	# This would be implemented per-game basis
	# Flag that controls should be reversed
	pass

func _create_visual_obstruction() -> void:
	# Create semi-transparent overlays
	var obstruction = ColorRect.new()
	obstruction.color = Color(0, 0, 0, 0.3)
	obstruction.size = get_viewport_rect().size
	obstruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(obstruction)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UI MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _setup_ui() -> void:
	# Create HUD Layer
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	hud_layer.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Top Bar Container with Background
	var top_bar_panel = PanelContainer.new()
	var top_bar_style = StyleBoxFlat.new()
	top_bar_style.bg_color = Color(0.2, 0.6, 0.8, 0.9)
	top_bar_style.corner_radius_bottom_left = 20
	top_bar_style.corner_radius_bottom_right = 20
	top_bar_style.shadow_size = 5
	top_bar_style.shadow_offset = Vector2(0, 2)
	top_bar_panel.add_theme_stylebox_override("panel", top_bar_style)
	vbox.add_child(top_bar_panel)
	
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 15)
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	margin_container.add_child(top_hbox)
	top_bar_panel.add_child(margin_container)
	
	# Timer Icon
	var timer_icon = Label.new()
	timer_icon.text = "⏱️"
	timer_icon.add_theme_font_size_override("font_size", 32)
	top_hbox.add_child(timer_icon)
	
	# Timer Bar
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(300, 40)
	timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timer_bar.show_percentage = false
	timer_bar.max_value = game_duration
	timer_bar.value = game_duration
	
	# Style the timer bar (Kid Friendly)
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.2, 0.3, 0.5)
	style_bg.corner_radius_top_left = 20
	style_bg.corner_radius_top_right = 20
	style_bg.corner_radius_bottom_right = 20
	style_bg.corner_radius_bottom_left = 20
	style_bg.border_width_left = 4
	style_bg.border_width_right = 4
	style_bg.border_width_top = 4
	style_bg.border_width_bottom = 4
	style_bg.border_color = Color(1, 1, 1, 0.8)
	timer_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.4, 0.9, 0.4, 1.0) # Bright Green
	style_fill.corner_radius_top_left = 16
	style_fill.corner_radius_top_right = 16
	style_fill.corner_radius_bottom_right = 16
	style_fill.corner_radius_bottom_left = 16
	timer_bar.add_theme_stylebox_override("fill", style_fill)
	
	# Hide timer if not needed
	timer_bar.visible = show_timer
	
	top_hbox.add_child(timer_bar)
	
	# Timer Label
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	timer_label.add_theme_constant_override("outline_size", 4)
	timer_label.text = "%.0fs" % game_duration
	top_hbox.add_child(timer_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(30, 1)
	top_hbox.add_child(spacer)
	
	# Lives Display (with background)
	var lives_panel = PanelContainer.new()
	var lives_style = StyleBoxFlat.new()
	lives_style.bg_color = Color(1, 1, 1, 0.2)
	lives_style.corner_radius_top_left = 15
	lives_style.corner_radius_top_right = 15
	lives_style.corner_radius_bottom_right = 15
	lives_style.corner_radius_bottom_left = 15
	lives_panel.add_theme_stylebox_override("panel", lives_style)
	
	var lives_hbox = HBoxContainer.new()
	lives_hbox.add_theme_constant_override("separation", 5)
	var lives_margin = MarginContainer.new()
	lives_margin.add_theme_constant_override("margin_left", 10)
	lives_margin.add_theme_constant_override("margin_right", 10)
	lives_margin.add_child(lives_hbox)
	lives_panel.add_child(lives_margin)
	
	var lives_label = Label.new()
	lives_label.add_theme_font_size_override("font_size", 28)
	lives_label.text = "❤️"
	lives_hbox.add_child(lives_label)
	
	var lives_count = Label.new()
	lives_count.add_theme_font_size_override("font_size", 28)
	lives_count.add_theme_color_override("font_color", Color.WHITE)
	lives_count.text = "x" + str(lives)
	lives_count.name = "LivesLabel"
	lives_hbox.add_child(lives_count)
	
	top_hbox.add_child(lives_panel)
	
	# Score Display (with background)
	var score_panel = PanelContainer.new()
	score_panel.add_theme_stylebox_override("panel", lives_style) # Reuse style
	score_panel.visible = show_quota  # Hide for survival games
	
	var score_hbox = HBoxContainer.new()
	score_hbox.add_theme_constant_override("separation", 5)
	var score_margin = MarginContainer.new()
	score_margin.add_theme_constant_override("margin_left", 10)
	score_margin.add_theme_constant_override("margin_right", 10)
	score_margin.add_child(score_hbox)
	score_panel.add_child(score_margin)
	
	var score_icon = Label.new()
	score_icon.add_theme_font_size_override("font_size", 28)
	score_icon.text = "⭐"
	score_hbox.add_child(score_icon)
	
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	score_label.text = "0"
	score_hbox.add_child(score_label)
	
	top_hbox.add_child(score_panel)
	
	# Pause Button (Styled)
	var pause_btn = Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(50, 50)
	pause_btn.add_theme_font_size_override("font_size", 24)
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.9, 0.6, 0.2)
	btn_normal.corner_radius_top_left = 25
	btn_normal.corner_radius_top_right = 25
	btn_normal.corner_radius_bottom_right = 25
	btn_normal.corner_radius_bottom_left = 25
	btn_normal.border_width_bottom = 4
	btn_normal.border_color = Color(0.7, 0.4, 0.1)
	
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.7, 0.4, 0.1)
	btn_pressed.corner_radius_top_left = 25
	btn_pressed.corner_radius_top_right = 25
	btn_pressed.corner_radius_bottom_right = 25
	btn_pressed.corner_radius_bottom_left = 25
	
	pause_btn.add_theme_stylebox_override("normal", btn_normal)
	pause_btn.add_theme_stylebox_override("pressed", btn_pressed)
	pause_btn.add_theme_stylebox_override("hover", btn_normal)
	
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.pressed.connect(_on_pause_pressed)
	top_hbox.add_child(pause_btn)
	
	# Create Pause Menu (Hidden)
	_create_pause_menu()

func _create_instruction_overlay():
	instruction_overlay = Control.new()
	instruction_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	instruction_overlay.visible = false
	instruction_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(instruction_overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	instruction_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	instruction_overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	
	# Game name with bounce animation
	var name_label = Label.new()
	name_label.text = game_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 64)
	name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 12)
	vbox.add_child(name_label)
	
	# Bounce animation
	var bounce = create_tween().set_loops()
	bounce.tween_property(name_label, "scale", Vector2(1.1, 1.1), 0.5)
	bounce.tween_property(name_label, "scale", Vector2(1.0, 1.0), 0.5)
	
	# Instruction
	var instruction_label = Label.new()
	instruction_label.text = game_instruction_text
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 40)
	instruction_label.add_theme_color_override("font_color", Color.WHITE)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	instruction_label.add_theme_constant_override("outline_size", 8)
	vbox.add_child(instruction_label)
	
	# Tap to start (blinking)
	var tap_label = Label.new()
	tap_label.text = Localization.get_text("tap_to_start") if Localization else "TAP ANYWHERE TO START"
	tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_label.add_theme_font_size_override("font_size", 32)
	tap_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	tap_label.add_theme_color_override("font_outline_color", Color.BLACK)
	tap_label.add_theme_constant_override("outline_size", 6)
	tap_label.name = "TapLabel"
	vbox.add_child(tap_label)
	
	# Blinking animation
	var tween = create_tween().set_loops()
	tween.tween_property(tap_label, "modulate:a", 0.3, 0.5)
	tween.tween_property(tap_label, "modulate:a", 1.0, 0.5)

func _wait_for_input() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break

func _create_pause_menu():
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(pause_menu)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	pause_menu.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var label = Label.new()
	label.text = "PAUSED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(label)
	
	var resume_btn = Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(200, 60)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)
	
	var exit_btn = Button.new()
	exit_btn.text = "EXIT"
	exit_btn.custom_minimum_size = Vector2(200, 60)
	exit_btn.pressed.connect(_on_exit_pressed)
	vbox.add_child(exit_btn)

func _on_pause_pressed():
	get_tree().paused = true
	pause_menu.visible = true

func _on_resume_pressed():
	get_tree().paused = false
	pause_menu.visible = false

func _on_exit_pressed():
	get_tree().paused = false
	if GameManager:
		GameManager.mark_welcome_shown()
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

func _process(_delta):
	if not game_active: return
	
	# Skip timer logic if timer hasn't started yet (for games with setup phases)
	if not timer_running: return
	
	# Update Timer - ALWAYS update even if no timer_bar reference
	var elapsed = (Time.get_ticks_msec() - game_start_time) / 1000.0
	var time_left = max(0.0, game_duration - elapsed)
	
	# Note: Removed mistake penalty - timer should run at normal speed
	# Mistakes affect score, not time remaining
	var effective_time_left = time_left
	
	if timer_bar:
		timer_bar.value = effective_time_left
		
		# Update timer label
		if timer_label:
			timer_label.text = "%.1fs" % effective_time_left
		
		# Change color based on time left ratio
		var time_ratio = effective_time_left / game_duration
		var fill_style = timer_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if time_ratio < 0.3:
				fill_style.bg_color = Color(0.9, 0.2, 0.2)  # Red
				if timer_label:
					timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			elif time_ratio < 0.6:
				fill_style.bg_color = Color(0.9, 0.8, 0.2)  # Yellow
				if timer_label:
					timer_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
			else:
				fill_style.bg_color = Color(0.4, 0.9, 0.4)  # Green
				if timer_label:
					timer_label.add_theme_color_override("font_color", Color.WHITE)
	
	if effective_time_left <= 0:
		_on_timeout()

func _on_timeout():
	if not game_active: return
	
	# Survival mode: timer running out = SUCCESS (you survived!)
	if game_mode == "survival":
		end_game(true)
	else:
		# Quota mode: timer running out = FAIL (didn't meet target)
		game_failed.emit()
		end_game(false)

func _deduct_life():
	lives -= 1
	
	# Save lives to GameManager
	if GameManager:
		GameManager.session_lives = lives
	
	var lives_label = hud_layer.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/LivesLabel")
	if lives_label:
		lives_label.text = "x" + str(lives)
		# Flash red
		var tween = create_tween()
		tween.tween_property(lives_label, "modulate", Color(2, 0.5, 0.5), 0.15)
		tween.tween_property(lives_label, "modulate", Color.WHITE, 0.15)
	
	if lives <= 0:
		# Game Over - end session
		_show_game_over()

func _update_ui() -> void:
	if timer_label:
		timer_label.text = "⏱️ Time: %.1f" % get_remaining_time()
	
	if score_label:
		score_label.text = "✅ Correct: %d" % correct_actions
	
	if mistakes_label:
		mistakes_label.text = "❌ Mistakes: %d" % mistakes_made

func _show_results(_accuracy: float, _reaction_time: int) -> void:
	# Show success animation
	var success_label = Label.new()
	success_label.text = "SUCCESS!"
	success_label.add_theme_font_size_override("font_size", 72)
	success_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))
	success_label.add_theme_color_override("font_outline_color", Color.BLACK)
	success_label.add_theme_constant_override("outline_size", 12)
	success_label.position = Vector2(get_viewport_rect().size.x/2 - 200, get_viewport_rect().size.y/2)
	hud_layer.add_child(success_label)
	
	var tween = create_tween()
	tween.tween_property(success_label, "scale", Vector2(1.5, 1.5), 0.3).from(Vector2.ZERO)
	tween.tween_property(success_label, "modulate:a", 0.0, 0.5).set_delay(0.5)
	
	await get_tree().create_timer(1.5).timeout
	# Next game automatically
	if GameManager:
		GameManager.start_next_minigame()

func _show_failure() -> void:
	# Show failure animation
	var fail_label = Label.new()
	fail_label.text = "OOPS!"
	fail_label.add_theme_font_size_override("font_size", 72)
	fail_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	fail_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fail_label.add_theme_constant_override("outline_size", 12)
	fail_label.position = Vector2(get_viewport_rect().size.x/2 - 150, get_viewport_rect().size.y/2)
	hud_layer.add_child(fail_label)
	
	var tween = create_tween()
	tween.tween_property(fail_label, "rotation", PI * 2, 0.5).from(0.0)
	tween.tween_property(fail_label, "scale", Vector2(2, 2), 0.3)
	tween.tween_property(fail_label, "modulate:a", 0.0, 0.3)
	
	await get_tree().create_timer(1.5).timeout
	# Go to next game (like DWTD)
	if GameManager:
		GameManager.start_next_minigame()

func _show_tally_screen(success: bool, _accuracy: float, _reaction_time: int):
	# Create tally overlay (like DWTD)
	var tally = Control.new()
	tally.set_anchors_preset(Control.PRESET_FULL_RECT)
	tally.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(tally)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.9)
	tally.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	tally.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	# Result text
	var result_label = Label.new()
	result_label.text = Localization.get_text("success") if success else Localization.get_text("game_over") if Localization else ("SUCCESS!" if success else "FAILED!")
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 72)
	result_label.add_theme_color_override("font_color", Color(0, 1, 0) if success else Color(1, 0.5, 0))
	result_label.add_theme_color_override("font_outline_color", Color.BLACK)
	result_label.add_theme_constant_override("outline_size", 12)
	vbox.add_child(result_label)
	
	# Score for this round
	var score_this_round = GameManager.round_scores[-1]["score"] if GameManager and GameManager.round_scores.size() > 0 else 0
	var round_score_label = Label.new()
	round_score_label.text = "+ %d points" % score_this_round
	round_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_score_label.add_theme_font_size_override("font_size", 48)
	round_score_label.add_theme_color_override("font_color", Color(1, 1, 0))
	round_score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	round_score_label.add_theme_constant_override("outline_size", 8)
	vbox.add_child(round_score_label)
	
	# Lives remaining
	var lives_label = Label.new()
	lives_label.text = "Lives: " + "❤️".repeat(lives)
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lives_label.add_theme_font_size_override("font_size", 40)
	vbox.add_child(lives_label)
	
	# Animate in
	var tween = create_tween()
	tween.tween_property(result_label, "scale", Vector2(1.0, 1.0), 0.5).from(Vector2.ZERO).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	await tween.finished
	
	await get_tree().create_timer(1.5).timeout
	tally.queue_free()

func _show_game_over() -> void:
	game_active = false
	# Show game over screen
	var gameover_label = Label.new()
	gameover_label.text = "GAME OVER!"
	gameover_label.add_theme_font_size_override("font_size", 80)
	gameover_label.add_theme_color_override("font_color", Color(1, 0, 0))
	gameover_label.add_theme_color_override("font_outline_color", Color.BLACK)
	gameover_label.add_theme_constant_override("outline_size", 15)
	gameover_label.position = Vector2(get_viewport_rect().size.x/2 - 250, get_viewport_rect().size.y/2)
	hud_layer.add_child(gameover_label)
	
	var tween = create_tween()
	tween.tween_property(gameover_label, "scale", Vector2(1.2, 1.2), 0.5).from(Vector2.ZERO)
	
	await get_tree().create_timer(2.0).timeout
	# Return to initial screen
	if GameManager:
		GameManager.mark_welcome_shown()
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OVERRIDE THESE IN CHILD CLASSES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_game_start() -> void:
	# Override: Initialize game-specific logic
	pass

func _on_correct_action() -> void:
	# Override: Handle correct action feedback
	_play_success_effect()

func _on_mistake() -> void:
	# Override: Handle mistake feedback
	_play_mistake_effect()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# JUICE/POLISH EFFECTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _play_success_effect() -> void:
	# Screen flash
	_flash_screen(Color(0.3, 1.0, 0.3, 0.3))
	# Would play sound here

func _play_mistake_effect() -> void:
	# Screen flash
	_flash_screen(Color(1.0, 0.3, 0.3, 0.3))
	# Would play sound here
	
	# Screen shake
	if AdaptiveDifficulty:
		var shake_intensity = AdaptiveDifficulty.get_screen_shake_intensity()
		if shake_intensity > 0:
			_shake_camera(shake_intensity)

func _flash_screen(color: Color) -> void:
	var flash = ColorRect.new()
	flash.color = color
	flash.size = get_viewport_rect().size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.finished.connect(flash.queue_free)

func _shake_camera(intensity: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		var original_offset = camera.offset
		
		var tween = create_tween()
		for i in range(5):
			tween.tween_property(camera, "offset", original_offset + Vector2(
				randf_range(-intensity * 10, intensity * 10),
				randf_range(-intensity * 10, intensity * 10)
			), 0.05)
		tween.tween_property(camera, "offset", original_offset, 0.05)
