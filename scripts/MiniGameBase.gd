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
var combo_streak: int = 0
var max_combo: int = 0
var game_instruction_text: String = "TAP TO START!"

## Difficulty Settings (from AdaptiveDifficulty)
var difficulty_settings: Dictionary = {}
var current_difficulty: String = "Medium"

## Chaos Effects
var chaos_effects_active: Array = []

## Audio Timer
var _last_tick_second: int = -1

## Internal timer reference (so we can stop it in end_game)
var _game_timer: Timer

## Chaos effect timer references (stopped on game end to prevent leaks)
var _chaos_timers: Array[Timer] = []

## Control reverse flag — child classes check this to invert input
var controls_reversed: bool = false

## UI References
var timer_label: Label
var score_label: Label
var combo_label: Label
var mistakes_label: Label
var hud_layer: CanvasLayer
var timer_bar: ProgressBar
var pause_menu: Control
var instruction_overlay: Control
var animated_cutscene_player: SimpleCutscenePlayer  # Simple animated cutscene system

func _ready() -> void:
	await get_tree().process_frame
	
	# Load session lives from GameManager
	if GameManager:
		lives = GameManager.session_lives
	
	_load_difficulty_settings()
	_apply_difficulty_settings()
	_setup_ui()
	_setup_animated_cutscene_player()  # Initialize animated cutscene system
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
	var is_multiplayer = (
		GameManager
		and GameManager.current_game_mode == GameManager.GameMode.MULTIPLAYER_COOP
	)
	
	if is_multiplayer and CoopAdaptation:
		# Multiplayer: Use CoopAdaptation for per-player difficulty
		var my_player_num = GameManager.local_player_num if GameManager else 1
		current_difficulty = CoopAdaptation.get_player_difficulty(my_player_num)
		difficulty_settings = CoopAdaptation.get_difficulty_params(my_player_num)
		chaos_effects_active = difficulty_settings.get("chaos_effects", [])
		
		print("🎮 [MP] %s | P%d: %s" % [game_name, my_player_num, current_difficulty])
	elif AdaptiveDifficulty:
		# ────────────────────────────────────────────────────────────────────────
		# Single-player: Use AdaptiveDifficulty (Φ = WMA - CP algorithm)
		# ────────────────────────────────────────────────────────────────────────
		# ELI5: When a minigame starts, it asks AdaptiveDifficulty:
		#       "What difficulty should I use for this player?"
		#
		# AdaptiveDifficulty looks at the current_difficulty (Easy/Medium/Hard)
		# which was calculated by the Rolling Window Algorithm, and returns
		# the appropriate settings:
		#
		# Easy:   speed_multiplier = 0.7,  time_limit = 20s, chaos_effects = []
		# Medium: speed_multiplier = 1.0,  time_limit = 15s, chaos_effects = [shake]
		# Hard:   speed_multiplier = 1.5,  time_limit = 10s, chaos_effects = [shake, mud, fly]
		#
		# The minigame then uses these settings to adjust gameplay!
		# ────────────────────────────────────────────────────────────────────────
		difficulty_settings = AdaptiveDifficulty.get_difficulty_settings()
		current_difficulty = AdaptiveDifficulty.get_current_difficulty()
		chaos_effects_active = difficulty_settings.get("chaos_effects", [])
		
		print("🎮 %s | Difficulty: %s" % [game_name, current_difficulty])
	else:
		# Fallback defaults when no difficulty system is available
		difficulty_settings = {
			"speed_multiplier": 1.0,
			"time_limit": 15,
			"chaos_effects": [],
			"task_complexity": 1,
			"item_count": 3,
			"distractors": 0,
			"progressive_level": 0,
			"progression_bonus": 0
		}
		current_difficulty = "Medium"
		print("🎮 %s | Difficulty: %s (fallback)" % [game_name, current_difficulty])

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
	
	# Play game start sound and gameplay music
	if AudioManager:
		AudioManager.play_game_start()
		AudioManager.play_music("gameplay", 0.5)
	
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
	
	# Stop the game timer so it can't double-trigger
	if _game_timer and is_instance_valid(_game_timer):
		_game_timer.stop()
	
	# Stop all chaos effect timers to prevent memory leaks
	for t in _chaos_timers:
		if is_instance_valid(t):
			t.stop()
			t.queue_free()
	_chaos_timers.clear()
	controls_reversed = false
	
	# Stop gameplay music
	if AudioManager:
		AudioManager.stop_music(0.5)
	
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
			if reaction_time < game_duration * 1000: droplets_earned += 5 # Speed bonus
			GameManager.water_droplets += droplets_earned
		
		# Always complete minigame (records performance for algorithm)
		GameManager.complete_minigame(
			game_name,
			accuracy,
			reaction_time,
			mistakes_made,
			current_score,
			max_combo
		)

	if success:
		await _show_success_micro_cutscene()
	else:
		await _show_failure_micro_cutscene()
	
	game_completed.emit(accuracy, reaction_time, mistakes_made)
	
	# Show tally screen with score
	await _show_tally_screen(success, accuracy, reaction_time)
	await _show_round_score_page(success, accuracy, reaction_time)
	
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
		combo_streak += 1
		max_combo = max(max_combo, combo_streak)
		correct_actions += 1
		var combo_bonus = int(floor(float(combo_streak) / 3.0)) * 5
		current_score += 10 + combo_bonus
		if score_label:
			score_label.text = "⭐ " + str(current_score)
		if combo_label:
			combo_label.text = "x%d" % combo_streak
			combo_label.visible = combo_streak >= 2
		# Audio: correct action + combo milestone
		if AudioManager:
			AudioManager.play_collect()
			if combo_streak > 0 and combo_streak % 3 == 0:
				AudioManager.play_combo()
		_on_correct_action()
	else:
		combo_streak = 0
		mistakes_made += 1
		if combo_label:
			combo_label.text = "x0"
			combo_label.visible = false
		# Audio: mistake
		if AudioManager:
			AudioManager.play_damage()
		
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
	if _game_timer:
		_game_timer.stop()
		_game_timer.queue_free()
	_game_timer = Timer.new()
	_game_timer.wait_time = game_duration
	_game_timer.one_shot = true
	_game_timer.timeout.connect(_on_timer_timeout)
	add_child(_game_timer)
	_game_timer.start()

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
			else:
				camera.offset = Vector2.ZERO
		)
		add_child(shake_timer)
		shake_timer.start()
		_chaos_timers.append(shake_timer)

func _spawn_mud_splatters() -> void:
	# Create random mud splatter sprites
	var splatter_timer = Timer.new()
	splatter_timer.wait_time = 2.0
	splatter_timer.timeout.connect(_create_mud_splatter)
	add_child(splatter_timer)
	splatter_timer.start()
	_chaos_timers.append(splatter_timer)

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
	_chaos_timers.append(move_timer)

func _activate_control_reverse() -> void:
	# Set flag — child classes should check controls_reversed to invert input
	controls_reversed = true

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

	# ══════════════════════════════════════════════════════════════════
	# DWTD-STYLE GAME HUD — Clean, warm, rounded pill design
	# ══════════════════════════════════════════════════════════════════

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	hud_layer.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# ── Top Row: Lives | Timer | Score | Pause ────────────────────
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	# -- Lives Pill (left) --
	var lives_pill = PanelContainer.new()
	var lives_style = StyleBoxFlat.new()
	lives_style.bg_color = Color(0.96, 0.93, 0.86, 0.92)
	lives_style.corner_radius_top_left = 20
	lives_style.corner_radius_top_right = 20
	lives_style.corner_radius_bottom_left = 20
	lives_style.corner_radius_bottom_right = 20
	lives_style.border_width_left = 2
	lives_style.border_width_right = 2
	lives_style.border_width_top = 2
	lives_style.border_width_bottom = 2
	lives_style.border_color = Color(0.85, 0.8, 0.7, 0.6)
	lives_style.shadow_size = 3
	lives_style.shadow_offset = Vector2(0, 2)
	lives_style.shadow_color = Color(0, 0, 0, 0.12)
	lives_pill.add_theme_stylebox_override("panel", lives_style)
	top_row.add_child(lives_pill)

	var lives_inner = MarginContainer.new()
	lives_inner.add_theme_constant_override("margin_left", 14)
	lives_inner.add_theme_constant_override("margin_right", 14)
	lives_inner.add_theme_constant_override("margin_top", 6)
	lives_inner.add_theme_constant_override("margin_bottom", 6)
	lives_pill.add_child(lives_inner)

	var lives_hbox = HBoxContainer.new()
	lives_hbox.add_theme_constant_override("separation", 4)
	lives_inner.add_child(lives_hbox)

	# Show hearts as individual emojis
	for i in range(lives):
		var heart = Label.new()
		heart.text = "❤️"
		heart.add_theme_font_size_override("font_size", 22)
		lives_hbox.add_child(heart)

	var lives_count = Label.new()
	lives_count.add_theme_font_size_override("font_size", 22)
	lives_count.add_theme_color_override("font_color", Color(0.35, 0.3, 0.25))
	lives_count.text = "x" + str(lives)
	lives_count.name = "LivesLabel"
	lives_hbox.add_child(lives_count)

	# -- Spacer (push timer to center) --
	var spacer_l = Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer_l)

	# -- Timer Pill (center) --
	var timer_pill = PanelContainer.new()
	var timer_style = StyleBoxFlat.new()
	timer_style.bg_color = Color(0.96, 0.93, 0.86, 0.92)
	timer_style.corner_radius_top_left = 20
	timer_style.corner_radius_top_right = 20
	timer_style.corner_radius_bottom_left = 20
	timer_style.corner_radius_bottom_right = 20
	timer_style.border_width_left = 2
	timer_style.border_width_right = 2
	timer_style.border_width_top = 2
	timer_style.border_width_bottom = 2
	timer_style.border_color = Color(0.85, 0.8, 0.7, 0.6)
	timer_style.shadow_size = 3
	timer_style.shadow_offset = Vector2(0, 2)
	timer_style.shadow_color = Color(0, 0, 0, 0.12)
	timer_pill.add_theme_stylebox_override("panel", timer_style)
	top_row.add_child(timer_pill)

	var timer_inner = MarginContainer.new()
	timer_inner.add_theme_constant_override("margin_left", 14)
	timer_inner.add_theme_constant_override("margin_right", 14)
	timer_inner.add_theme_constant_override("margin_top", 6)
	timer_inner.add_theme_constant_override("margin_bottom", 6)
	timer_pill.add_child(timer_inner)

	var timer_hbox = HBoxContainer.new()
	timer_hbox.add_theme_constant_override("separation", 8)
	timer_inner.add_child(timer_hbox)

	var timer_icon = Label.new()
	timer_icon.text = "⏱"
	timer_icon.add_theme_font_size_override("font_size", 22)
	timer_hbox.add_child(timer_icon)

	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.add_theme_color_override("font_color", Color(0.3, 0.28, 0.22))
	timer_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	timer_label.add_theme_constant_override("outline_size", 2)
	timer_label.text = "%.0fs" % game_duration
	timer_hbox.add_child(timer_label)

	# -- Spacer (push score/pause to right) --
	var spacer_r = Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer_r)

	# -- Score + Combo Pill (right) --
	var score_pill = PanelContainer.new()
	score_pill.add_theme_stylebox_override("panel", lives_style.duplicate())
	score_pill.visible = show_quota
	top_row.add_child(score_pill)

	var score_inner = MarginContainer.new()
	score_inner.add_theme_constant_override("margin_left", 14)
	score_inner.add_theme_constant_override("margin_right", 14)
	score_inner.add_theme_constant_override("margin_top", 6)
	score_inner.add_theme_constant_override("margin_bottom", 6)
	score_pill.add_child(score_inner)

	var score_hbox = HBoxContainer.new()
	score_hbox.add_theme_constant_override("separation", 10)
	score_inner.add_child(score_hbox)

	var score_icon = Label.new()
	score_icon.add_theme_font_size_override("font_size", 22)
	score_icon.text = "⭐"
	score_hbox.add_child(score_icon)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 22)
	score_label.add_theme_color_override("font_color", Color(0.45, 0.38, 0.2))
	score_label.text = "0"
	score_hbox.add_child(score_label)

	# Combo display (inline, appears when streak >= 2)
	var combo_sep = Label.new()
	combo_sep.text = "·"
	combo_sep.add_theme_font_size_override("font_size", 22)
	combo_sep.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	score_hbox.add_child(combo_sep)

	var combo_icon = Label.new()
	combo_icon.add_theme_font_size_override("font_size", 22)
	combo_icon.text = "🔥"
	score_hbox.add_child(combo_icon)

	combo_label = Label.new()
	combo_label.add_theme_font_size_override("font_size", 20)
	combo_label.add_theme_color_override("font_color", Color(0.85, 0.45, 0.15))
	combo_label.text = "x0"
	combo_label.visible = false
	score_hbox.add_child(combo_label)

	# -- Pause Button --
	var pause_btn = Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(44, 44)
	pause_btn.add_theme_font_size_override("font_size", 20)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.96, 0.93, 0.86, 0.92)
	btn_normal.corner_radius_top_left = 22
	btn_normal.corner_radius_top_right = 22
	btn_normal.corner_radius_bottom_right = 22
	btn_normal.corner_radius_bottom_left = 22
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(0.85, 0.8, 0.7, 0.6)

	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.88, 0.84, 0.76, 0.95)

	pause_btn.add_theme_stylebox_override("normal", btn_normal)
	pause_btn.add_theme_stylebox_override("pressed", btn_pressed)
	pause_btn.add_theme_stylebox_override("hover", btn_normal)
	pause_btn.add_theme_color_override("font_color", Color(0.35, 0.3, 0.25))

	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.pressed.connect(_on_pause_pressed)
	top_row.add_child(pause_btn)

	# ── Timer Progress Bar (thin bar below top row) ───────────────
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(0, 8)
	timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_bar.show_percentage = false
	timer_bar.max_value = game_duration
	timer_bar.value = game_duration

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.88, 0.84, 0.76, 0.5)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_right = 4
	bar_bg.corner_radius_bottom_left = 4
	timer_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.4, 0.82, 0.45)
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_right = 4
	bar_fill.corner_radius_bottom_left = 4
	timer_bar.add_theme_stylebox_override("fill", bar_fill)

	timer_bar.visible = show_timer
	vbox.add_child(timer_bar)

	# ── Progressive Level Indicator (only when above base difficulty) ──
	if AdaptiveDifficulty:
		var settings = AdaptiveDifficulty.get_difficulty_settings()
		var progressive_level = settings.get("progressive_level", 0)
		if progressive_level > 0:
			var prog_pill = PanelContainer.new()
			var prog_style = StyleBoxFlat.new()
			prog_style.bg_color = Color(1.0, 0.35, 0.15, 0.88)
			prog_style.corner_radius_top_left = 14
			prog_style.corner_radius_top_right = 14
			prog_style.corner_radius_bottom_left = 14
			prog_style.corner_radius_bottom_right = 14
			prog_style.border_width_left = 2
			prog_style.border_width_right = 2
			prog_style.border_width_top = 2
			prog_style.border_width_bottom = 2
			prog_style.border_color = Color(1, 0.85, 0.2, 0.8)
			prog_pill.add_theme_stylebox_override("panel", prog_style)

			var prog_inner = MarginContainer.new()
			prog_inner.add_theme_constant_override("margin_left", 12)
			prog_inner.add_theme_constant_override("margin_right", 12)
			prog_inner.add_theme_constant_override("margin_top", 4)
			prog_inner.add_theme_constant_override("margin_bottom", 4)
			prog_pill.add_child(prog_inner)

			var prog_hbox = HBoxContainer.new()
			prog_hbox.add_theme_constant_override("separation", 6)
			prog_inner.add_child(prog_hbox)

			var prog_icon = Label.new()
			prog_icon.add_theme_font_size_override("font_size", 20)
			prog_icon.text = "🔥"
			prog_hbox.add_child(prog_icon)

			var prog_label = Label.new()
			prog_label.add_theme_font_size_override("font_size", 20)
			prog_label.add_theme_color_override("font_color", Color(1, 1, 0.85))
			prog_label.text = "LVL " + str(progressive_level)
			prog_hbox.add_child(prog_label)

			# Place it at top-right, after the timer bar
			prog_pill.size_flags_horizontal = Control.SIZE_SHRINK_END
			vbox.add_child(prog_pill)
	
	# Create Pause Menu (Hidden)
	_create_pause_menu()

func _setup_animated_cutscene_player() -> void:
	# Initialize the SimpleCutscenePlayer for win/fail cutscenes
	animated_cutscene_player = SimpleCutscenePlayer.new()
	animated_cutscene_player.visible = false
	animated_cutscene_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	animated_cutscene_player.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(animated_cutscene_player)

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
	tap_label.text = (
		Localization.get_text("tap_to_start")
		if Localization
		else "TAP ANYWHERE TO START"
	)
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
		var touch_pressed = false
		if InputMap.has_action("touch"):
			touch_pressed = Input.is_action_just_pressed("touch")

		if (
			Input.is_action_just_pressed("ui_accept")
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			or touch_pressed
		):
			break

func _play_intro_animation() -> void:
	var scene = _resolve_cutscene_scene("intro")
	if scene:
		var intro = scene.instantiate()
		hud_layer.add_child(intro)
		if intro.has_method("configure"):
			intro.configure(game_name, "Get ready...")
		if intro.has_method("play_cutscene"):
			await intro.play_cutscene()
		else:
			await get_tree().create_timer(1.1).timeout
		intro.queue_free()
		return

	# Fallback if cutscene scene is missing
	await get_tree().create_timer(0.45).timeout

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
	if AudioManager:
		AudioManager.play_pause()

func _on_resume_pressed():
	get_tree().paused = false
	pause_menu.visible = false
	if AudioManager:
		AudioManager.play_resume()

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
				# Tick urgency sound every second when time is low
				var sec = int(effective_time_left)
				if sec != _last_tick_second and sec <= 5 and sec > 0 and AudioManager:
					_last_tick_second = sec
					AudioManager.play_timer_tick()
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
	
	# Audio: life lost
	if AudioManager:
		AudioManager.play_life_lost()
	
	# Use find_child to locate LivesLabel regardless of nested container structure
	var lives_lbl = hud_layer.find_child("LivesLabel", true, false) if hud_layer else null
	if lives_lbl:
		lives_lbl.text = "x" + str(lives)
		# Flash red
		var tween = create_tween()
		tween.tween_property(lives_lbl, "modulate", Color(2, 0.5, 0.5), 0.15)
		tween.tween_property(lives_lbl, "modulate", Color.WHITE, 0.15)
	# Note: Game over is handled by GameManager.start_next_minigame() which
	# checks session_lives <= 0 and shows the final score screen properly.

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
	success_label.position = Vector2(
		get_viewport_rect().size.x / 2 - 200,
		get_viewport_rect().size.y / 2
	)
	hud_layer.add_child(success_label)
	
	var tween = create_tween()
	tween.tween_property(success_label, "scale", Vector2(1.5, 1.5), 0.3).from(Vector2.ZERO)
	tween.tween_interval(0.5)
	tween.tween_property(success_label, "modulate:a", 0.0, 0.5)
	
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
	var reaction = _get_result_reaction(success)
	var score_this_round = 0
	if GameManager and GameManager.round_scores.size() > 0:
		score_this_round = GameManager.round_scores[-1]["score"]

	var scene = _resolve_narrative_outro_scene(success)
	if not scene:
		print("⚠️ No narrative scene found, trying text-based outro...")
		scene = _resolve_outro_cutscene_scene(success)
	
	if scene:
		print("▶️ LOADING OUTRO: %s" % scene.resource_path)
		var outro = scene.instantiate()
		hud_layer.add_child(outro)
		var use_narrative = scene.resource_path.contains("CharacterOutcomeNarrative")
		if outro.has_method("configure"):
			if use_narrative:
				print("🎭 Configuring NARRATIVE cutscene")
				outro.configure(
					success,
					_get_minigame_key(),
					_get_outro_anim_profile(success)
				)
			else:
				print("📝 Configuring TEXT-BASED outro")
				outro.configure(
					success,
					reaction["line"],
					score_this_round,
					max_combo,
					lives,
					_get_outro_anim_profile(success)
				)
		if outro.has_method("play_cutscene"):
			print("▶️ Playing cutscene...")
			await outro.play_cutscene()
		else:
			print("⏱️ Generic wait instead of cutscene playback")
			await get_tree().create_timer(1.25).timeout
		outro.queue_free()
		return

	# Fallback if cutscene scene is missing
	print("❌ No outro cutscene found at all")
	await get_tree().create_timer(0.55).timeout

func _resolve_narrative_outro_scene(_success: bool) -> PackedScene:
	var key = _get_minigame_key()

	# Try to use generic narrative scene (shows character outcome animation)
	var fallback_narrative_path = "res://scenes/ui/cutscenes/CharacterOutcomeNarrative.tscn"
	if ResourceLoader.exists(fallback_narrative_path):
		return load(fallback_narrative_path) as PackedScene

	return null

func _resolve_outro_cutscene_scene(success: bool) -> PackedScene:
	var key = _get_minigame_key()
	var suffix = "Win" if success else "Lose"

	var specific_status_path = "res://scenes/ui/cutscenes/outro/%s%sOutro.tscn" % [
		key,
		suffix
	]
	var generic_status_path = "res://scenes/ui/cutscenes/MiniGame%sOutroCutscene.tscn" % suffix
	var legacy_specific_path = "res://scenes/ui/cutscenes/outro/%sOutro.tscn" % key
	var legacy_generic_path = "res://scenes/ui/cutscenes/MiniGameOutroCutscene.tscn"

	if ResourceLoader.exists(specific_status_path):
		return load(specific_status_path) as PackedScene
	if ResourceLoader.exists(generic_status_path):
		return load(generic_status_path) as PackedScene
	if ResourceLoader.exists(legacy_specific_path):
		return load(legacy_specific_path) as PackedScene
	if ResourceLoader.exists(legacy_generic_path):
		return load(legacy_generic_path) as PackedScene
	return null

func _get_outro_anim_profile(success: bool) -> Dictionary:
	var key = _get_minigame_key()

	if (
		"Rain" in key
		or "Leak" in key
		or "Tap" in key
		or "Pipe" in key
	):
		return {
			"speed": 1.15 if success else 1.0,
			"distance": 1.2,
			"pop": 1.1 if success else 0.95
		}

	if (
		"Plant" in key
		or "Scrub" in key
		or "Filter" in key
		or "Vegetable" in key
	):
		return {
			"speed": 0.95 if success else 0.9,
			"distance": 0.9,
			"pop": 1.25 if success else 1.0
		}

	return {
		"speed": 1.05 if success else 0.95,
		"distance": 1.0,
		"pop": 1.05 if success else 0.95
	}

func _show_round_score_page(success: bool, accuracy: float, _reaction_time: int) -> void:
	# ═══════════════════════════════════════════════════════════════════════
	# DWTD-STYLE SCORING PAGE  — Water Drop Characters + Evaporation
	# ═══════════════════════════════════════════════════════════════════════
	var max_lives := 3
	var current_lives := lives  # already decremented by _deduct_life() if failed
	var accent: Color = Color(0.35, 0.85, 0.55) if success else Color(1.0, 0.45, 0.3)

	var round_score := 0
	if GameManager and GameManager.round_scores.size() > 0:
		round_score = int(GameManager.round_scores[-1].get("score", 0))
	var session_total := GameManager.session_score if GameManager else 0
	var flavor_line := _get_result_line_for_key(success, _get_minigame_key())

	# ── Full-screen page ──────────────────────────────────────────────────
	var page = Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.process_mode = Node.PROCESS_MODE_ALWAYS
	page.modulate.a = 0.0
	hud_layer.add_child(page)

	# Warm cream/beige background (DWTD style)
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.96, 0.93, 0.86, 0.97)
	page.add_child(bg)

	# Subtle top accent bar
	var accent_bar = ColorRect.new()
	accent_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	accent_bar.custom_minimum_size.y = 6
	accent_bar.color = accent
	page.add_child(accent_bar)

	# ── Main layout ───────────────────────────────────────────────────────
	var outer_margin = MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 48)
	outer_margin.add_theme_constant_override("margin_right", 48)
	outer_margin.add_theme_constant_override("margin_top", 36)
	outer_margin.add_theme_constant_override("margin_bottom", 36)
	page.add_child(outer_margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	outer_margin.add_child(vbox)

	# ── Title ─────────────────────────────────────────────────────────────
	var title = Label.new()
	title.text = "ROUND COMPLETE" if success else "ROUND FAILED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.22, 0.22, 0.22))
	title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	title.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title)

	# ── Water Drop Characters (DWTD Lives Row) ───────────────────────────
	var drops_row = HBoxContainer.new()
	drops_row.alignment = BoxContainer.ALIGNMENT_CENTER
	drops_row.add_theme_constant_override("separation", 32)
	vbox.add_child(drops_row)

	var drop_labels: Array[Label] = []
	for i in range(max_lives):
		var drop = Label.new()
		drop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		drop.add_theme_font_size_override("font_size", 72)
		if i < current_lives:
			drop.text = "💧"
		else:
			drop.text = "💧"
			drop.modulate = Color(0.5, 0.5, 0.5, 0.7)
		drop.modulate.a = 0.0  # start invisible for staggered entrance
		drops_row.add_child(drop)
		drop_labels.append(drop)

	# ── Flavor text ───────────────────────────────────────────────────────
	var flavor = Label.new()
	flavor.text = flavor_line
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.add_theme_font_size_override("font_size", 22)
	flavor.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.modulate.a = 0.0
	vbox.add_child(flavor)

	# ── Big Score Number ──────────────────────────────────────────────────
	var score_display = Label.new()
	score_display.text = "0"
	score_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_display.add_theme_font_size_override("font_size", 80)
	score_display.add_theme_color_override("font_color", Color(0.18, 0.18, 0.18))
	score_display.modulate.a = 0.0
	vbox.add_child(score_display)

	var score_caption = Label.new()
	score_caption.text = "POINTS EARNED"
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_caption.add_theme_font_size_override("font_size", 16)
	score_caption.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
	score_caption.modulate.a = 0.0
	vbox.add_child(score_caption)

	# ── Stat Pills (accuracy / combo / time) ─────────────────────────────
	var pills_row = HBoxContainer.new()
	pills_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pills_row.add_theme_constant_override("separation", 16)
	vbox.add_child(pills_row)

	var accuracy_pct := int(round(accuracy * 100.0))
	var pill_data := [
		["🎯 %d%%" % accuracy_pct, "Accuracy"],
		["🔥 x%d" % max_combo, "Best Combo"],
		["💧 %d" % (GameManager.water_droplets if GameManager else 0), "Droplets"],
	]
	var pill_nodes: Array[Control] = []

	for pd in pill_data:
		var pill = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.92, 0.89, 0.82)
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
		style.corner_radius_bottom_left = 16
		style.corner_radius_bottom_right = 16
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		pill.add_theme_stylebox_override("panel", style)
		pill.modulate.a = 0.0

		var pill_vbox = VBoxContainer.new()
		pill_vbox.add_theme_constant_override("separation", 2)
		pill.add_child(pill_vbox)

		var val_lbl = Label.new()
		val_lbl.text = pd[0]
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 22)
		val_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		pill_vbox.add_child(val_lbl)

		var cap_lbl = Label.new()
		cap_lbl.text = pd[1]
		cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap_lbl.add_theme_font_size_override("font_size", 13)
		cap_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
		pill_vbox.add_child(cap_lbl)

		pills_row.add_child(pill)
		pill_nodes.append(pill)

	# ── Session total bar ─────────────────────────────────────────────────
	var session_bar = PanelContainer.new()
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = accent.lerp(Color.WHITE, 0.7)
	sb_style.corner_radius_top_left = 12
	sb_style.corner_radius_top_right = 12
	sb_style.corner_radius_bottom_left = 12
	sb_style.corner_radius_bottom_right = 12
	sb_style.content_margin_left = 24
	sb_style.content_margin_right = 24
	sb_style.content_margin_top = 8
	sb_style.content_margin_bottom = 8
	session_bar.add_theme_stylebox_override("panel", sb_style)
	session_bar.modulate.a = 0.0
	vbox.add_child(session_bar)

	var session_hbox = HBoxContainer.new()
	session_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	session_hbox.add_theme_constant_override("separation", 12)
	session_bar.add_child(session_hbox)

	var sess_label = Label.new()
	sess_label.text = "Session Total"
	sess_label.add_theme_font_size_override("font_size", 18)
	sess_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	session_hbox.add_child(sess_label)

	var sess_val = Label.new()
	sess_val.text = "%d pts" % session_total
	sess_val.add_theme_font_size_override("font_size", 22)
	sess_val.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	session_hbox.add_child(sess_val)

	# ══════════════════════════════════════════════════════════════════════
	#  ANIMATION SEQUENCE
	# ══════════════════════════════════════════════════════════════════════

	# 1. Fade in entire page
	var fade_in = create_tween()
	fade_in.tween_property(page, "modulate:a", 1.0, 0.3)
	await fade_in.finished

	# 2. Stagger water drops entrance (bounce in one-by-one)
	for i in range(drop_labels.size()):
		var dl: Label = drop_labels[i]
		var is_alive := (i < current_lives)
		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(dl, "modulate:a", 1.0 if is_alive else 0.7, 0.2)
		tw.tween_property(dl, "scale", Vector2(1.0, 1.0), 0.25).from(Vector2(0.2, 0.2))
		if AudioManager and is_alive:
			AudioManager.play_collect()
		await get_tree().create_timer(0.18).timeout

	# 3. Evaporate dead drops (float upward + fade out)
	for i in range(drop_labels.size()):
		if i >= current_lives:
			var dl: Label = drop_labels[i]
			var evap = create_tween()
			evap.set_parallel(true)
			evap.tween_property(dl, "position:y", dl.position.y - 40, 0.6)
			evap.tween_property(dl, "modulate:a", 0.15, 0.6)
			evap.tween_property(dl, "scale", Vector2(0.6, 1.3), 0.6)
			if AudioManager:
				AudioManager.play_damage()

	# 4. Show flavor text
	await get_tree().create_timer(0.2).timeout
	var flav_tw = create_tween()
	flav_tw.tween_property(flavor, "modulate:a", 1.0, 0.25)

	# 5. Score count-up
	await get_tree().create_timer(0.15).timeout
	score_display.modulate.a = 1.0
	score_caption.modulate.a = 1.0
	var count_steps := mini(round_score, 30)
	if count_steps > 0:
		for step in range(count_steps + 1):
			var val = int(lerp(0.0, float(round_score), float(step) / float(count_steps)))
			score_display.text = str(val)
			if AudioManager and step % 3 == 0:
				AudioManager.play_score_tick()
			await get_tree().create_timer(0.03).timeout
	score_display.text = str(round_score)

	# Pop the final number
	var pop_tw = create_tween()
	pop_tw.tween_property(score_display, "scale", Vector2(1.15, 1.15), 0.1)
	pop_tw.tween_property(score_display, "scale", Vector2(1.0, 1.0), 0.1)
	if AudioManager:
		AudioManager.play_bonus()

	# 6. Cascade stat pills
	await get_tree().create_timer(0.2).timeout
	for pill in pill_nodes:
		var ptw = create_tween()
		ptw.set_parallel(true)
		ptw.tween_property(pill, "modulate:a", 1.0, 0.2)
		ptw.tween_property(pill, "scale", Vector2(1.0, 1.0), 0.2).from(Vector2(0.85, 0.85))
		await get_tree().create_timer(0.12).timeout

	# 7. Session total bar
	await get_tree().create_timer(0.15).timeout
	var stw = create_tween()
	stw.tween_property(session_bar, "modulate:a", 1.0, 0.25)

	# 8. Idle bounce on alive drops while user views the page
	for i in range(mini(current_lives, drop_labels.size())):
		var dl: Label = drop_labels[i]
		var bounce = create_tween().set_loops(4)
		bounce.tween_property(dl, "position:y", dl.position.y - 6, 0.25).set_delay(i * 0.12)
		bounce.tween_property(dl, "position:y", dl.position.y, 0.25)

	# Hold for viewing
	await get_tree().create_timer(2.5).timeout

	# 9. Fade out
	var out_tw = create_tween()
	out_tw.tween_property(page, "modulate:a", 0.0, 0.35)
	await out_tw.finished
	page.queue_free()

func _resolve_cutscene_scene(kind: String) -> PackedScene:
	var key = _get_minigame_key()
	var specific_path = ""
	var generic_path = ""

	if kind == "intro":
		specific_path = "res://scenes/ui/cutscenes/intro/%sIntro.tscn" % key
		generic_path = "res://scenes/ui/cutscenes/MiniGameIntroCutscene.tscn"
	else:
		specific_path = "res://scenes/ui/cutscenes/outro/%sOutro.tscn" % key
		generic_path = "res://scenes/ui/cutscenes/MiniGameOutroCutscene.tscn"

	if ResourceLoader.exists(specific_path):
		return load(specific_path) as PackedScene
	if ResourceLoader.exists(generic_path):
		return load(generic_path) as PackedScene
	return null

func _get_result_reaction(success: bool) -> Dictionary:
	var key = _get_minigame_key()
	var line = _get_result_line_for_key(success, key)

	if success:
		return {
			"character": "😎",
			"line": line,
			"color": Color(0.45, 1.0, 0.55)
		}
	return {
		"character": "😵",
		"line": line,
		"color": Color(1.0, 0.5, 0.3)
	}

func _get_result_line_for_key(success: bool, key: String) -> String:
	var success_lines := {
		"RiceWashRescue": "Rice water saved. Smart kitchen move!",
		"VegetableBath": "Veggies cleaned with one smart rinse!",
		"GreywaterSorter": "Greywater routed to the right use!",
		"WringItOut": "Nice squeeze. Every drop counted!",
		"ThirstyPlant": "Plant hydrated with just enough water!",
		"MudPieMaker": "Mud mix perfect. Zero waste vibes!",
		"CatchTheRain": "Rain caught clean. Tanks up!",
		"CoverTheDrum": "Drum covered in time. Great reflex!",
		"SpotTheSpeck": "All impurities spotted. Crystal clear!",
		"FixLeak": "Leak fixed fast. Flow restored!",
		"RainwaterHarvesting": "Harvest complete. Rain put to work!",
		"WaterPlant": "Perfect pour. Happy roots!",
		"PlugTheLeak": "Pipe plugged. Waste stopped cold!",
		"SwipeTheSoap": "Soap swipe efficiency unlocked!",
		"QuickShower": "Quick shower run. Big water saved!",
		"FilterBuilder": "Filter stack built like a pro!",
		"ToiletTankFix": "Tank tuned right. No excess flush!",
		"TracePipePath": "Path traced clean. Nice routing!",
		"ScrubToSave": "Scrub done water-wise. Spotless!",
		"BucketBrigade": "Relay complete. Team flow secured!",
		"TimingTap": "Tap timing nailed. Zero extra drip!",
		"TurnOffTap": "Tap shut off right on cue!"
	}

	var fail_lines := {
		"RiceWashRescue": "Rice water spilled. Retry!",
		"VegetableBath": "Too much rinse. One-pass next!",
		"GreywaterSorter": "Wrong route. Sort cleaner!",
		"WringItOut": "Still dripping. Wring harder!",
		"ThirstyPlant": "Watering off-balance. Re-aim!",
		"MudPieMaker": "Mix missed. Steady hands!",
		"CatchTheRain": "Rain got away. Track drops!",
		"CoverTheDrum": "Drum stayed open. Cover faster!",
		"SpotTheSpeck": "Speck missed. Scan sharper!",
		"FixLeak": "Leak still live. Seal now!",
		"RainwaterHarvesting": "Harvest missed. Reposition!",
		"WaterPlant": "Watering off. Find the sweet spot!",
		"PlugTheLeak": "Plug missed. Line it up!",
		"SwipeTheSoap": "Swipe too slow. Clean cut!",
		"QuickShower": "Shower too long. Speed run!",
		"FilterBuilder": "Wrong layer stack. Rebuild!",
		"ToiletTankFix": "Tank unstable. Retune it!",
		"TracePipePath": "Route drifted. Follow flow!",
		"ScrubToSave": "Scrub wasted water. Stay tight!",
		"BucketBrigade": "Relay broke pace. Move!",
		"TimingTap": "Timing off. Tap on beat!",
		"TurnOffTap": "Tap stayed on. Cut early!"
	}

	if success and success_lines.has(key):
		return success_lines[key]
	if not success and fail_lines.has(key):
		return fail_lines[key]

	return (
		"Clean save! Keep it flowing!"
		if success
		else "Oops! Try a faster rescue next round!"
	)

func _show_failure_micro_cutscene() -> void:
	# Try to use SimpleCutscenePlayer
	if animated_cutscene_player and animated_cutscene_player.has_method("play_cutscene"):
		animated_cutscene_player.visible = true
		animated_cutscene_player.play_cutscene(_get_minigame_key(), 1)  # 1 = FAIL
		await animated_cutscene_player.cutscene_finished
		animated_cutscene_player.visible = false
		return
	
	# Fallback to legacy emoji cutscene (only if SimpleCutscenePlayer not available)
	var data = _get_failure_cutscene_data()
	var cutscene = Control.new()
	cutscene.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(cutscene)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = data.get("bg", Color(0, 0, 0, 0.75))
	cutscene.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var icon = Label.new()
	icon.text = data.get("icon", "💥")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 110)
	vbox.add_child(icon)

	var line = Label.new()
	line.text = data.get("line", "That was close!")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 40)
	line.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	line.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_theme_constant_override("outline_size", 8)
	vbox.add_child(line)

	_play_cutscene_sfx("failure", str(data.get("anim", "wobble")), _get_minigame_key())

	_animate_failure_icon(icon, str(data.get("anim", "wobble")))

	var tw = create_tween()
	tw.tween_interval(float(data.get("hold", 0.55)))
	tw.tween_property(cutscene, "modulate:a", 0.0, 0.2)
	await tw.finished
	cutscene.queue_free()

func _show_success_micro_cutscene() -> void:
	# Try to use SimpleCutscenePlayer
	if animated_cutscene_player and animated_cutscene_player.has_method("play_cutscene"):
		animated_cutscene_player.visible = true
		animated_cutscene_player.play_cutscene(_get_minigame_key(), 0)  # 0 = WIN
		await animated_cutscene_player.cutscene_finished
		animated_cutscene_player.visible = false
		return
	
	# Fallback to legacy emoji cutscene (only if SimpleCutscenePlayer not available)
	var data = _get_success_cutscene_data()
	var cutscene = Control.new()
	cutscene.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(cutscene)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = data.get("bg", Color(0.02, 0.12, 0.06, 0.72))
	cutscene.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var icon = Label.new()
	icon.text = data.get("icon", "✨")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 110)
	vbox.add_child(icon)

	var line = Label.new()
	line.text = data.get("line", "Great save!")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 40)
	line.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	line.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_theme_constant_override("outline_size", 8)
	vbox.add_child(line)

	_play_cutscene_sfx("success", str(data.get("anim", "pop")), _get_minigame_key())

	_animate_success_icon(icon, str(data.get("anim", "pop")))

	var tw = create_tween()
	tw.tween_interval(float(data.get("hold", 0.48)))
	tw.tween_property(cutscene, "modulate:a", 0.0, 0.2)
	await tw.finished
	cutscene.queue_free()

func _get_success_cutscene_data() -> Dictionary:
	var key = _get_minigame_key()
	var presets = _get_success_cutscene_presets()
	if presets.has(key):
		return presets[key]

	return {
		"icon": "✨",
		"line": "Clean save!",
		"anim": "pop",
		"bg": Color(0.02, 0.12, 0.06, 0.72),
		"hold": 0.48
	}

func _get_success_cutscene_presets() -> Dictionary:
	return {
		"RiceWashRescue": {
			"icon": "🍚",
			"line": "Rice water rescued!",
			"anim": "pop",
			"bg": Color(0.09, 0.12, 0.05, 0.72)
		},
		"VegetableBath": {
			"icon": "🥬",
			"line": "Veggies cleaned with less water!",
			"anim": "bounce",
			"bg": Color(0.04, 0.12, 0.05, 0.72)
		},
		"GreywaterSorter": {
			"icon": "🛢",
			"line": "Greywater sorted perfectly!",
			"anim": "spin",
			"bg": Color(0.05, 0.1, 0.1, 0.72)
		},
		"WringItOut": {
			"icon": "🧽",
			"line": "Every drop squeezed back!",
			"anim": "pop",
			"bg": Color(0.03, 0.11, 0.09, 0.72)
		},
		"ThirstyPlant": {
			"icon": "🌱",
			"line": "Plant watered just right!",
			"anim": "bounce",
			"bg": Color(0.02, 0.12, 0.05, 0.72)
		},
		"MudPieMaker": {
			"icon": "🥧",
			"line": "Mud mix nailed!",
			"anim": "spin",
			"bg": Color(0.1, 0.08, 0.04, 0.72)
		},
		"CatchTheRain": {
			"icon": "🌧",
			"line": "Rain captured cleanly!",
			"anim": "drop",
			"bg": Color(0.02, 0.1, 0.13, 0.74)
		},
		"CoverTheDrum": {
			"icon": "🛢",
			"line": "Drum protected in time!",
			"anim": "pop",
			"bg": Color(0.03, 0.1, 0.12, 0.74)
		},
		"SpotTheSpeck": {
			"icon": "🔍",
			"line": "All specks detected!",
			"anim": "spin",
			"bg": Color(0.03, 0.11, 0.11, 0.72)
		},
		"FixLeak": {
			"icon": "🔧",
			"line": "Leak sealed!",
			"anim": "pop",
			"bg": Color(0.02, 0.1, 0.12, 0.74)
		},
		"RainwaterHarvesting": {
			"icon": "☔",
			"line": "Rainwater harvest complete!",
			"anim": "drop",
			"bg": Color(0.02, 0.1, 0.13, 0.74)
		},
		"WaterPlant": {
			"icon": "🌿",
			"line": "Healthy watering rhythm!",
			"anim": "bounce",
			"bg": Color(0.02, 0.12, 0.05, 0.72)
		},
		"PlugTheLeak": {
			"icon": "🔩",
			"line": "Pipe patched under pressure!",
			"anim": "pop",
			"bg": Color(0.02, 0.1, 0.12, 0.74)
		},
		"SwipeTheSoap": {
			"icon": "🧼",
			"line": "Soap swipe efficiency!",
			"anim": "spin",
			"bg": Color(0.03, 0.11, 0.12, 0.72)
		},
		"QuickShower": {
			"icon": "🚿",
			"line": "Quick shower master!",
			"anim": "bounce",
			"bg": Color(0.03, 0.1, 0.13, 0.74)
		},
		"FilterBuilder": {
			"icon": "🧪",
			"line": "Perfect filter stack!",
			"anim": "spin",
			"bg": Color(0.03, 0.11, 0.1, 0.72)
		},
		"ToiletTankFix": {
			"icon": "🚽",
			"line": "Tank tuned and sealed!",
			"anim": "pop",
			"bg": Color(0.04, 0.1, 0.12, 0.72)
		},
		"TracePipePath": {
			"icon": "🧭",
			"line": "Pipe path traced cleanly!",
			"anim": "spin",
			"bg": Color(0.03, 0.09, 0.12, 0.72)
		},
		"ScrubToSave": {
			"icon": "🫧",
			"line": "Spotless and water-wise!",
			"anim": "bounce",
			"bg": Color(0.03, 0.11, 0.12, 0.72)
		},
		"BucketBrigade": {
			"icon": "🪣",
			"line": "Relay run delivered!",
			"anim": "drop",
			"bg": Color(0.03, 0.1, 0.12, 0.72)
		},
		"TimingTap": {
			"icon": "🎯",
			"line": "Tap timing on point!",
			"anim": "pop",
			"bg": Color(0.04, 0.09, 0.12, 0.72)
		},
		"TurnOffTap": {
			"icon": "🚰",
			"line": "Tap turned off right on cue!",
			"anim": "bounce",
			"bg": Color(0.02, 0.1, 0.13, 0.72)
		}
	}

func _animate_success_icon(icon: Label, anim: String) -> void:
	var tw = create_tween()
	match anim:
		"spin":
			tw.tween_property(icon, "rotation", TAU, 0.32).from(0.0)
		"bounce":
			tw.tween_property(icon, "position:y", icon.position.y - 20, 0.10)
			tw.tween_property(icon, "position:y", icon.position.y + 8, 0.10)
			tw.tween_property(icon, "position:y", icon.position.y, 0.09)
		"drop":
			tw.tween_property(icon, "position:y", icon.position.y + 18, 0.10)
			tw.tween_property(icon, "position:y", icon.position.y, 0.10)
		_:
			tw.tween_property(icon, "scale", Vector2(1.15, 1.15), 0.11)
			tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.11)

func _play_cutscene_sfx(kind: String, anim: String, key: String) -> void:
	if not AudioManager:
		return

	if kind == "success":
		AudioManager.play_success()
		match anim:
			"spin":
				AudioManager.play_bonus()
			"drop":
				AudioManager.play_water_drop()
			"bounce":
				AudioManager.play_collect()
			_:
				AudioManager.play_click()

		# Water-themed wins get an extra splash accent.
		if (
			"Rain" in key
			or "Leak" in key
			or "Water" in key
			or "Tap" in key
		):
			AudioManager.play_water_splash()
		return

	# Failure branch
	AudioManager.play_failure()
	match anim:
		"shake":
			AudioManager.play_damage()
		"drop":
			AudioManager.play_water_drop()
		"spin":
			AudioManager.play_warning()
		_:
			AudioManager.play_click()

	if (
		"Rain" in key
		or "Leak" in key
		or "Water" in key
		or "Tap" in key
	):
		AudioManager.play_water_drop()

func _get_failure_cutscene_data() -> Dictionary:
	var key = _get_minigame_key()
	var presets = _get_failure_cutscene_presets()
	if presets.has(key):
		return presets[key]

	return {
		"icon": "💥",
		"line": "Mission failed. Retry incoming!",
		"anim": "wobble",
		"bg": Color(0, 0, 0, 0.75),
		"hold": 0.55
	}

func _get_minigame_key() -> String:
	if get_script() and get_script().resource_path != "":
		var file_name = get_script().resource_path.get_file()
		var base_name = file_name.trim_suffix(".gd")
		if base_name != "":
			return base_name
	return game_name.replace(" ", "")

func _get_failure_cutscene_presets() -> Dictionary:
	return {
		"RiceWashRescue": {
			"icon": "🍚",
			"line": "Rice water spilled away!",
			"anim": "drop",
			"bg": Color(0.08, 0.05, 0.02, 0.8)
		},
		"VegetableBath": {
			"icon": "🥬",
			"line": "Veggies wasted the wash water!",
			"anim": "spin",
			"bg": Color(0.03, 0.08, 0.03, 0.8)
		},
		"GreywaterSorter": {
			"icon": "🛢",
			"line": "Greywater got contaminated!",
			"anim": "shake",
			"bg": Color(0.06, 0.06, 0.08, 0.8)
		},
		"WringItOut": {
			"icon": "🧽",
			"line": "Still dripping! Wring tighter!",
			"anim": "wobble",
			"bg": Color(0.04, 0.07, 0.09, 0.8)
		},
		"ThirstyPlant": {
			"icon": "🌱",
			"line": "Plant stayed thirsty this round!",
			"anim": "drop",
			"bg": Color(0.03, 0.09, 0.04, 0.8)
		},
		"MudPieMaker": {
			"icon": "🥧",
			"line": "Too much water in the mud mix!",
			"anim": "spin",
			"bg": Color(0.09, 0.06, 0.03, 0.8)
		},
		"CatchTheRain": {
			"icon": "🌧",
			"line": "Rain escaped the bucket!",
			"anim": "drop",
			"bg": Color(0.02, 0.05, 0.1, 0.82)
		},
		"CoverTheDrum": {
			"icon": "🛢",
			"line": "Drum left open in the rain!",
			"anim": "shake",
			"bg": Color(0.03, 0.06, 0.1, 0.82)
		},
		"SpotTheSpeck": {
			"icon": "🔍",
			"line": "Missed particles in the water!",
			"anim": "wobble",
			"bg": Color(0.03, 0.07, 0.09, 0.8)
		},
		"FixLeak": {
			"icon": "💧",
			"line": "Leak burst! Water escaped!",
			"anim": "drop",
			"bg": Color(0.02, 0.05, 0.09, 0.82)
		},
		"RainwaterHarvesting": {
			"icon": "🌧",
			"line": "Harvest missed the downpour!",
			"anim": "drop",
			"bg": Color(0.02, 0.05, 0.1, 0.82)
		},
		"WaterPlant": {
			"icon": "🌿",
			"line": "Plant got the wrong amount!",
			"anim": "wobble",
			"bg": Color(0.03, 0.08, 0.04, 0.8)
		},
		"PlugTheLeak": {
			"icon": "🔧",
			"line": "Pipe pressure won this time!",
			"anim": "shake",
			"bg": Color(0.03, 0.05, 0.09, 0.82)
		},
		"SwipeTheSoap": {
			"icon": "🧼",
			"line": "Soap slipped and water ran!",
			"anim": "spin",
			"bg": Color(0.04, 0.08, 0.1, 0.8)
		},
		"QuickShower": {
			"icon": "🚿",
			"line": "Shower time exceeded target!",
			"anim": "shake",
			"bg": Color(0.03, 0.06, 0.1, 0.82)
		},
		"FilterBuilder": {
			"icon": "🧪",
			"line": "Wrong filter stack!",
			"anim": "spin",
			"bg": Color(0.04, 0.07, 0.09, 0.8)
		},
		"ToiletTankFix": {
			"icon": "🚽",
			"line": "Tank setup leaked again!",
			"anim": "wobble",
			"bg": Color(0.04, 0.06, 0.09, 0.8)
		},
		"TracePipePath": {
			"icon": "🧭",
			"line": "Pipe route got crossed!",
			"anim": "spin",
			"bg": Color(0.04, 0.05, 0.08, 0.8)
		},
		"ScrubToSave": {
			"icon": "🧼",
			"line": "Scrub wasted too much water!",
			"anim": "shake",
			"bg": Color(0.05, 0.07, 0.09, 0.8)
		},
		"BucketBrigade": {
			"icon": "🪣",
			"line": "Bucket relay broke down!",
			"anim": "drop",
			"bg": Color(0.04, 0.06, 0.09, 0.82)
		},
		"TimingTap": {
			"icon": "⏱",
			"line": "Tap timing missed the beat!",
			"anim": "wobble",
			"bg": Color(0.04, 0.05, 0.08, 0.8)
		},
		"TurnOffTap": {
			"icon": "🚰",
			"line": "Tap stayed on too long!",
			"anim": "shake",
			"bg": Color(0.03, 0.06, 0.1, 0.82)
		}
	}

func _animate_failure_icon(icon: Label, anim: String) -> void:
	var tw = create_tween()
	match anim:
		"spin":
			tw.tween_property(icon, "rotation", TAU, 0.35).from(0.0)
		"shake":
			tw.tween_property(icon, "position:x", icon.position.x + 22, 0.06)
			tw.tween_property(icon, "position:x", icon.position.x - 22, 0.06)
			tw.tween_property(icon, "position:x", icon.position.x + 14, 0.06)
			tw.tween_property(icon, "position:x", icon.position.x, 0.06)
		"drop":
			tw.tween_property(icon, "position:y", icon.position.y + 24, 0.14)
			tw.tween_property(icon, "position:y", icon.position.y, 0.14)
		_:
			tw.tween_property(icon, "rotation", 0.12, 0.08).from(-0.12)
			tw.tween_property(icon, "rotation", -0.08, 0.08)
			tw.tween_property(icon, "rotation", 0.04, 0.08)
			tw.tween_property(icon, "rotation", 0.0, 0.08)

func _show_game_over() -> void:
	game_active = false
	# Show game over screen
	var gameover_label = Label.new()
	gameover_label.text = "GAME OVER!"
	gameover_label.add_theme_font_size_override("font_size", 80)
	gameover_label.add_theme_color_override("font_color", Color(1, 0, 0))
	gameover_label.add_theme_color_override("font_outline_color", Color.BLACK)
	gameover_label.add_theme_constant_override("outline_size", 15)
	gameover_label.position = Vector2(
		get_viewport_rect().size.x / 2 - 250,
		get_viewport_rect().size.y / 2
	)
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
