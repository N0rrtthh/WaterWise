class_name MultiplayerMiniGameBase
extends Node2D

## ═══════════════════════════════════════════════════════════════════
## MULTIPLAYER MINIGAME BASE CLASS
## ═══════════════════════════════════════════════════════════════════
## Base template for all multiplayer cooperative mini-games
## Handles G-Counter scoring, shared lives, pause sync, and resource transfer
## ═══════════════════════════════════════════════════════════════════

signal game_started()
signal game_completed(success: bool)
signal player_ready()
signal countdown_tick(count: int)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@export var game_name: String = "CoopMiniGame"
@export var game_duration: float = 60.0
@export var requires_countdown: bool = true  # Show 3-2-1-GO before starting
@export var connection_type: String = "resource_transfer"  # or "task_marking" or "combined_efficiency"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var game_active: bool = false
var game_started_time: int = 0
var my_player_num: int = 1
var my_role: String = ""
var partner_role: String = ""
var local_score: int = 0
var is_waiting_for_partner: bool = false

# UI References
var hud_layer: CanvasLayer
var countdown_label: Label
var waiting_overlay: Control
var pause_menu: Control

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	await get_tree().process_frame
	
	if not NetworkManager or not NetworkManager.is_multiplayer_connected():
		push_error("❌ MultiplayerMiniGameBase: Not connected to multiplayer")
		return
	
	# Get player info
	my_player_num = NetworkManager.get_local_player_num()
	my_role = NetworkManager.get_player_role(my_player_num)
	
	_log("🎮 Multiplayer game starting - Player %d (%s)" % [my_player_num, my_role])
	
	# Setup UI
	_setup_multiplayer_ui()
	
	# Connect NetworkManager signals
	if NetworkManager:
		NetworkManager.team_score_updated.connect(_on_team_score_updated)
		NetworkManager.team_lives_updated.connect(_on_team_lives_updated)
		NetworkManager.round_starting.connect(_on_countdown_tick)
		NetworkManager.resource_sent.connect(_on_resource_received)
		NetworkManager.task_marked.connect(_on_task_marked)
	
	# Initialize game-specific setup
	_on_multiplayer_ready()
	
	# Start countdown if required
	if requires_countdown:
		if NetworkManager.is_server():
			NetworkManager.start_countdown()
		_show_countdown_overlay()
	else:
		start_game()

func _setup_multiplayer_ui() -> void:
	"""Setup HUD for multiplayer game"""
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	
	# Top bar with shared state
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.custom_minimum_size = Vector2(0, 80)
	hud_layer.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)
	
	# Lives
	var lives_label = Label.new()
	lives_label.name = "LivesLabel"
	lives_label.text = "❤️ x%d" % NetworkManager.team_lives
	lives_label.add_theme_font_size_override("font_size", 32)
	hbox.add_child(lives_label)
	
	# Score
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "⭐ %d" % NetworkManager.get_total_score()
	score_label.add_theme_font_size_override("font_size", 32)
	hbox.add_child(score_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# Role indicator
	var role_label = Label.new()
	role_label.name = "RoleLabel"
	role_label.text = "You: %s" % my_role
	role_label.add_theme_font_size_override("font_size", 28)
	role_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	hbox.add_child(role_label)
	
	# Pause button
	var pause_btn = Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(60, 60)
	pause_btn.add_theme_font_size_override("font_size", 32)
	pause_btn.pressed.connect(_on_pause_pressed)
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	hbox.add_child(pause_btn)
	
	# Create pause menu (hidden)
	_create_pause_menu()
	
	# Create waiting overlay (hidden)
	_create_waiting_overlay()
	
	# Create countdown overlay (hidden)
	_create_countdown_overlay()

func _create_pause_menu() -> void:
	"""Create pause menu overlay"""
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
	label.add_theme_font_size_override("font_size", 64)
	vbox.add_child(label)
	
	var resume_btn = Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(200, 60)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)

func _create_waiting_overlay() -> void:
	"""Create 'Waiting for partner' overlay"""
	waiting_overlay = Control.new()
	waiting_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	waiting_overlay.visible = false
	hud_layer.add_child(waiting_overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	waiting_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	waiting_overlay.add_child(center)
	
	var label = Label.new()
	label.text = "Waiting for partner..."
	label.add_theme_font_size_override("font_size", 48)
	center.add_child(label)

func _create_countdown_overlay() -> void:
	"""Create countdown overlay (3-2-1-GO!)"""
	var countdown_overlay = Control.new()
	countdown_overlay.name = "CountdownOverlay"
	countdown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_overlay.visible = false
	hud_layer.add_child(countdown_overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	countdown_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_overlay.add_child(center)
	
	countdown_label = Label.new()
	countdown_label.text = "3"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 128)
	countdown_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	center.add_child(countdown_label)

func _show_countdown_overlay() -> void:
	"""Show countdown overlay"""
	var overlay = hud_layer.get_node_or_null("CountdownOverlay")
	if overlay:
		overlay.visible = true

func _hide_countdown_overlay() -> void:
	"""Hide countdown overlay"""
	var overlay = hud_layer.get_node_or_null("CountdownOverlay")
	if overlay:
		overlay.visible = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME FLOW
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func start_game() -> void:
	"""Start the game (called after countdown or immediately)"""
	game_active = true
	game_started_time = Time.get_ticks_msec()
	game_started.emit()
	
	_log("🎮 Game started!")
	_on_game_start()

func _on_countdown_complete() -> void:
	"""Called when countdown reaches GO"""
	_hide_countdown_overlay()
	start_game()

func end_game(success: bool) -> void:
	"""End the game and report results"""
	if not game_active:
		return
	
	game_active = false
	
	_log("🏁 Game ended - %s" % ("Success" if success else "Failed"))
	
	# Show waiting overlay if partner hasn't finished
	if success:
		show_waiting_overlay()
	
	game_completed.emit(success)
	
	# Report failure to NetworkManager (deducts life)
	if not success and NetworkManager:
		NetworkManager.lose_life()

func show_waiting_overlay() -> void:
	"""Show waiting for partner overlay"""
	is_waiting_for_partner = true
	if waiting_overlay:
		waiting_overlay.visible = true
	_log("⏳ Waiting for partner...")

func hide_waiting_overlay() -> void:
	"""Hide waiting overlay"""
	is_waiting_for_partner = false
	if waiting_overlay:
		waiting_overlay.visible = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SCORING (G-Counter)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func add_score(points: int) -> void:
	"""Add points to local score and sync via G-Counter"""
	local_score += points
	
	if NetworkManager:
		NetworkManager.increment_local(points)
	
	_log("⭐ +%d points (Local: %d)" % [points, local_score])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PAUSE HANDLING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_pause_pressed() -> void:
	"""Local player pressed pause"""
	if NetworkManager:
		NetworkManager.request_pause()
	
	if pause_menu:
		pause_menu.visible = true

func _on_resume_pressed() -> void:
	"""Local player pressed resume"""
	if NetworkManager:
		NetworkManager.request_resume()
	
	if pause_menu:
		pause_menu.visible = false

func _on_remote_pause() -> void:
	"""Partner paused the game"""
	if pause_menu:
		pause_menu.visible = true

func _on_remote_resume() -> void:
	"""Partner resumed the game"""
	if pause_menu:
		pause_menu.visible = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NETWORK CALLBACKS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_team_score_updated(total_score: int) -> void:
	"""Team score updated via G-Counter"""
	var score_label = hud_layer.get_node_or_null("MarginContainer/HBoxContainer/ScoreLabel")
	if score_label:
		score_label.text = "⭐ %d" % total_score

func _on_team_lives_updated(remaining_lives: int) -> void:
	"""Team lives updated"""
	var lives_label = hud_layer.get_node_or_null("MarginContainer/HBoxContainer/LivesLabel")
	if lives_label:
		lives_label.text = "❤️ x%d" % remaining_lives
		
		# Flash red if life lost
		var tween = create_tween()
		tween.tween_property(lives_label, "modulate", Color(2, 0.5, 0.5), 0.2)
		tween.tween_property(lives_label, "modulate", Color.WHITE, 0.2)
	
	# Check for game over
	if remaining_lives <= 0:
		_on_game_over()

func _on_countdown_tick(count: int) -> void:
	"""Countdown tick received"""
	countdown_tick.emit(count)
	
	if countdown_label:
		if count > 0:
			countdown_label.text = str(count)
		else:
			countdown_label.text = "GO!"
		
		# Animate
		var tween = create_tween()
		tween.tween_property(countdown_label, "scale", Vector2(1.5, 1.5), 0.2).from(Vector2.ZERO)
		tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.2)

func _on_resource_received(from_player: int, resource_type: String, amount: int, quality: float) -> void:
	"""Resource received from partner"""
	# Override in child class to handle resource
	_log("📥 Received %s x%d (quality: %.1f) from P%d" % [resource_type, amount, quality, from_player])

func _on_task_marked(from_player: int, task_id: int, position: Vector2) -> void:
	"""Task marked by partner"""
	# Override in child class to handle task marking
	_log("📍 Task #%d marked by P%d at %s" % [task_id, from_player, position])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func send_resource_to_partner(resource_type: String, amount: int, quality: float = 1.0) -> void:
	"""Send resource to partner player"""
	if NetworkManager:
		NetworkManager.send_resource(resource_type, amount, quality)

func mark_task_for_partner(task_id: int, task_position: Vector2) -> void:
	"""Mark a task for partner to complete"""
	if NetworkManager:
		NetworkManager.mark_task(task_id, task_position)

func _log(message: String) -> void:
	"""Internal logging"""
	print("[%s P%d] %s" % [game_name, my_player_num, message])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OVERRIDE THESE IN CHILD CLASSES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_multiplayer_ready() -> void:
	"""Override: Called when multiplayer setup is complete"""
	pass

func _on_game_start() -> void:
	"""Override: Called when game actually starts"""
	pass

func _on_game_over() -> void:
	"""Override: Called when team runs out of lives"""
	_log("💀 GAME OVER")
	# Return to lobby
	if NetworkManager:
		NetworkManager.return_to_lobby()
