class_name MultiplayerMiniGameBase
extends Node2D

## 
## MULTIPLAYER MINIGAME BASE CLASS
## 
## Base template for all multiplayer cooperative mini-games
## Handles G-Counter scoring, shared lives, pause sync, and resource transfer
## 

signal game_started()
signal game_completed(success: bool)
signal countdown_tick(count: int)

# 
# GAME CONFIGURATION
# 

@export var game_name: String = "CoopMiniGame"
@export var game_duration: float = 30.0
@export var requires_countdown: bool = true  # Show 3-2-1-GO before starting
@export var connection_type: String = "resource_transfer"
# Options: resource_transfer, task_marking, combined_efficiency.
@export var win_quota: int = 0 # If > 0, reaching this score triggers win

const FONT_TITLE: Font = preload("res://fonts/Cubao_Free_Wide.otf")
const FONT_BODY: Font = preload("res://fonts/NTBrickSans.otf")

# 
# STATE VARIABLES
# 

var game_active: bool = false
var game_started_time: int = 0
var ui_timer: Timer
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
var instruction_overlay: Control
var timer_label: Label

# 
# INITIALIZATION
# 

func _ready() -> void:
	await get_tree().process_frame
	
	if not NetworkManager or not NetworkManager.is_multiplayer_connected():
		push_error(" MultiplayerMiniGameBase: Not connected to multiplayer")
		return
	
	# Get player info
	my_player_num = NetworkManager.get_local_player_num()
	my_role = NetworkManager.get_player_role(my_player_num)
	
	_log(" Multiplayer game starting - Player %d (%s)" % [my_player_num, my_role])
	
	# Initialize game-specific setup FIRST (sets game_name and game_duration)
	_on_multiplayer_ready()
	
	# Create background
	_create_background()
	
	# Setup UI AFTER game settings are configured
	_setup_multiplayer_ui()
	
	# Connect NetworkManager signals
	if NetworkManager:
		NetworkManager.team_score_updated.connect(_on_team_score_updated)
		NetworkManager.team_lives_updated.connect(_on_team_lives_updated)
		NetworkManager.round_starting.connect(_on_countdown_tick)
		NetworkManager.resource_sent.connect(_on_resource_received)
		NetworkManager.task_marked.connect(_on_task_marked)
		NetworkManager.player_disconnected.connect(_on_player_left_session)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	# Show instructions (override get_instructions() in child class)
	var instructions_text = get_instructions()
	if instructions_text != "":
		show_instructions(instructions_text)
	else:
		# No instructions, start immediately
		if requires_countdown:
			if NetworkManager.is_server():
				NetworkManager.start_countdown()
			_show_countdown_overlay()
		else:
			start_game()

func _create_background() -> void:
	# Create procedural background for the game
	# Create a TextureRect instead of ColorRect for gradient support
	var bg = TextureRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	
	# Gradient background
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.1, 0.3, 0.5))  # Dark blue
	gradient.set_color(1, Color(0.3, 0.5, 0.7))  # Light blue
	
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(0, 1)
	
	bg.texture = gradient_texture
	add_child(bg)
	bg.z_index = -100

func _setup_multiplayer_ui() -> void:
	# Setup HUD for multiplayer game
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 100  # Above game elements
	add_child(hud_layer)
	
	# Load fonts.
	var font_title = FONT_TITLE
	var font_body = FONT_BODY
	
	# Top Bar Background
	var top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.expand_margin_bottom = 10
	top_bar.add_theme_stylebox_override("panel", style)
	
	hud_layer.add_child(top_bar)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 40)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)
	
	# --- LEFT SECTION: STATUS ---
	var left_box = HBoxContainer.new()
	left_box.add_theme_constant_override("separation", 20)
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.size_flags_stretch_ratio = 1.0
	hbox.add_child(left_box)
	
	# Lives
	var lives_container = HBoxContainer.new()
	var lives_label = Label.new()
	lives_label.name = "LivesLabel"
	lives_label.text = " x%d" % NetworkManager.team_lives
	if font_title: lives_label.add_theme_font_override("font", font_title)
	lives_label.add_theme_font_size_override("font_size", 32)
	lives_label.add_theme_color_override("font_outline_color", Color.BLACK)
	lives_label.add_theme_constant_override("outline_size", 4)
	lives_label.pivot_offset = Vector2(50, 20)
	lives_container.add_child(lives_label)
	left_box.add_child(lives_container)
	
	# Score
	var score_container = HBoxContainer.new()
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = " %d" % NetworkManager.get_total_score()
	if font_title: score_label.add_theme_font_override("font", font_title)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label.add_theme_constant_override("outline_size", 4)
	score_label.pivot_offset = Vector2(50, 20)
	score_container.add_child(score_label)
	left_box.add_child(score_container)
	
	# --- CENTER SECTION: GAME INFO ---
	var center_box = VBoxContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.size_flags_stretch_ratio = 1.0
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(center_box)
	
	# Game Name
	var game_label = Label.new()
	game_label.name = "GameLabel"
	game_label.text = game_name if game_name else "Multiplayer Game"
	if font_body: game_label.add_theme_font_override("font", font_body)
	game_label.add_theme_font_size_override("font_size", 18)
	game_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
	game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(game_label)
	
	# Timer (Progress Bar Style)
	var timer_container = VBoxContainer.new()
	timer_container.custom_minimum_size = Vector2(300, 0)
	center_box.add_child(timer_container)
	
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	if game_duration >= 999999.0:
		timer_label.text = "ENDLESS"
	else:
		timer_label.text = "%.0f" % game_duration
	if font_title: timer_label.add_theme_font_override("font", font_title)
	timer_label.add_theme_font_size_override("font_size", 36)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	timer_label.add_theme_constant_override("outline_size", 4)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_container.add_child(timer_label)
	
	# Timer Progress Bar
	var timer_progress = ProgressBar.new()
	timer_progress.name = "TimerProgress"
	timer_progress.custom_minimum_size = Vector2(300, 20)
	timer_progress.max_value = game_duration
	timer_progress.value = game_duration
	timer_progress.show_percentage = false
	
	var progress_style = StyleBoxFlat.new()
	progress_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	progress_style.corner_radius_top_left = 10
	progress_style.corner_radius_top_right = 10
	progress_style.corner_radius_bottom_left = 10
	progress_style.corner_radius_bottom_right = 10
	timer_progress.add_theme_stylebox_override("background", progress_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.8, 1.0)
	fill_style.corner_radius_top_left = 10
	fill_style.corner_radius_top_right = 10
	fill_style.corner_radius_bottom_left = 10
	fill_style.corner_radius_bottom_right = 10
	timer_progress.add_theme_stylebox_override("fill", fill_style)
	
	timer_container.add_child(timer_progress)
	
	# --- RIGHT SECTION: ROLES & PAUSE ---
	var right_box = HBoxContainer.new()
	right_box.add_theme_constant_override("separation", 20)
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.size_flags_stretch_ratio = 1.0
	right_box.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_child(right_box)
	
	# Roles Container
	var roles_vbox = VBoxContainer.new()
	roles_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_box.add_child(roles_vbox)
	
	# Your Role
	var role_label = Label.new()
	role_label.name = "RoleLabel"
	role_label.text = "YOU: %s" % my_role
	if font_body: role_label.add_theme_font_override("font", font_body)
	role_label.add_theme_font_size_override("font_size", 20)
	role_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	role_label.add_theme_color_override("font_outline_color", Color.BLACK)
	role_label.add_theme_constant_override("outline_size", 2)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	roles_vbox.add_child(role_label)
	
	# Partner Role
	var partner_num = 2 if my_player_num == 1 else 1
	var partner_role_name = NetworkManager.get_player_role(partner_num)
	var partner_label = Label.new()
	partner_label.name = "PartnerLabel"
	partner_label.text = "PARTNER: %s" % partner_role_name
	if font_body: partner_label.add_theme_font_override("font", font_body)
	partner_label.add_theme_font_size_override("font_size", 16)
	partner_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	partner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	partner_label.add_theme_constant_override("outline_size", 2)
	partner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	roles_vbox.add_child(partner_label)
	
	# Pause button
	var pause_btn = Button.new()
	pause_btn.text = ""
	pause_btn.custom_minimum_size = Vector2(50, 50)
	pause_btn.add_theme_font_size_override("font_size", 24)
	pause_btn.pressed.connect(_on_pause_pressed)
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.focus_mode = Control.FOCUS_NONE
	right_box.add_child(pause_btn)
	
	# Create overlays
	_create_pause_menu()
	_create_waiting_overlay()
	_create_countdown_overlay()
	_create_instruction_overlay()
	_create_controls_panel()

func _create_pause_menu() -> void:
	# Create pause menu overlay
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
	
	var quit_btn = Button.new()
	quit_btn.text = "QUIT SESSION"
	quit_btn.custom_minimum_size = Vector2(200, 60)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

func _create_waiting_overlay() -> void:
	# Create 'Waiting for partner' overlay
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
	# Create countdown overlay (3-2-1-GO!)
	var countdown_overlay = Control.new()
	countdown_overlay.name = "CountdownOverlay"
	countdown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_overlay.visible = false
	hud_layer.add_child(countdown_overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.4)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_overlay.add_child(center)
	
	countdown_label = Label.new()
	countdown_label.text = "3"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var font_title = FONT_TITLE
	if font_title: countdown_label.add_theme_font_override("font", font_title)
	
	countdown_label.add_theme_font_size_override("font_size", 160)
	countdown_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	countdown_label.add_theme_constant_override("outline_size", 10)
	countdown_label.pivot_offset = Vector2(0, 80) # Approximate center
	center.add_child(countdown_label)

func _show_countdown_overlay() -> void:
	# Show countdown overlay
	var overlay = hud_layer.get_node_or_null("CountdownOverlay")
	if overlay:
		overlay.visible = true

func _hide_countdown_overlay() -> void:
	# Hide countdown overlay
	var overlay = hud_layer.get_node_or_null("CountdownOverlay")
	if overlay:
		overlay.visible = false

func _create_instruction_overlay() -> void:
	# Create instruction overlay shown before game starts
	instruction_overlay = Control.new()
	instruction_overlay.name = "InstructionOverlay"
	instruction_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	instruction_overlay.visible = false
	# Ensure it does not block input when hidden/fading.
	instruction_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(instruction_overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	instruction_overlay.add_child(center)
	
	var panel = PanelContainer.new()
	panel.name = "PanelContainer"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.3, 0.6, 1.0)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.expand_margin_left = 20
	style.expand_margin_right = 20
	style.expand_margin_top = 20
	style.expand_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 20)
	vbox.custom_minimum_size = Vector2(600, 0)
	panel.add_child(vbox)
	
	var font_title = FONT_TITLE
	var font_body = FONT_BODY
	
	var title = Label.new()
	title.name = "Title"
	title.text = game_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_title: title.add_theme_font_override("font", font_title)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)
	
	var role = Label.new()
	role.name = "Role"
	role.text = "Your Role: " + my_role
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_body: role.add_theme_font_override("font", font_body)
	role.add_theme_font_size_override("font_size", 32)
	role.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(role)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	var instructions = Label.new()
	instructions.name = "Instructions"
	instructions.text = "Instructions will appear here"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_body: instructions.add_theme_font_override("font", font_body)
	instructions.add_theme_font_size_override("font_size", 24)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(instructions)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	var start_label = Label.new()
	start_label.text = "Click anywhere to start"
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_label.add_theme_font_size_override("font_size", 20)
	start_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	vbox.add_child(start_label)
	
	# Pulse animation for "Click to start"
	var tween = create_tween().set_loops()
	tween.tween_property(start_label, "modulate:a", 0.3, 0.8)
	tween.tween_property(start_label, "modulate:a", 1.0, 0.8)

func show_instructions(instructions_text: String) -> void:
	# Show instruction overlay with custom text
	if instruction_overlay:
		var instructions_label = instruction_overlay.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/Instructions"
		)
		if instructions_label:
			instructions_label.text = instructions_text
		
		var title_label = instruction_overlay.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/Title"
		)
		if title_label:
			title_label.text = game_name
		
		var role_label = instruction_overlay.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/Role"
		)
		if role_label:
			role_label.text = "Your Role: " + my_role
		
		instruction_overlay.visible = true
		instruction_overlay.mouse_filter = Control.MOUSE_FILTER_STOP # Block input until clicked
		
		# Wait for click to dismiss
		instruction_overlay.gui_input.connect(_on_instruction_clicked)

func _on_instruction_clicked(event: InputEvent) -> void:
	# Handle click on instruction overlay
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if instruction_overlay and instruction_overlay.visible:
			instruction_overlay.gui_input.disconnect(_on_instruction_clicked)
			
			# Fade out instructions
			var tween = create_tween()
			tween.set_loops(1)
			tween.tween_property(instruction_overlay, "modulate:a", 0.0, 0.5)
			tween.tween_callback(func(): 
				instruction_overlay.visible = false
				instruction_overlay.modulate.a = 1.0
			)
			
			# Show waiting overlay and notify readiness
			_show_waiting_for_start()
			if NetworkManager.has_method("set_local_player_ready"):
				NetworkManager.set_local_player_ready()
			else:
				# Fallback for older NetworkManager versions
				if NetworkManager.is_server():
					NetworkManager.start_countdown()
				_show_countdown_overlay()

func _show_waiting_for_start() -> void:
	# Show waiting message while waiting for partner to click ready
	if not hud_layer: return
	
	var overlay = Control.new()
	overlay.name = "WaitingStartOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	overlay.add_child(bg)
	
	var label = Label.new()
	label.text = "Waiting for partner..."
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 32)
	overlay.add_child(label)

func _on_countdown_tick(count: int) -> void:
	# Countdown tick received
	# Remove waiting overlay if exists
	var waiting = hud_layer.get_node_or_null("WaitingStartOverlay")
	if waiting: waiting.queue_free()
	
	_show_countdown_overlay() # Ensure countdown is visible
	
	countdown_tick.emit(count)
	
	if countdown_label:
		if count > 0:
			countdown_label.text = str(count)
		else:
			countdown_label.text = "GO!"
			# When countdown reaches 0 (GO!), start the game after animation
			await get_tree().create_timer(1.0).timeout
			_on_countdown_complete()
		
		# Animate
		var tween = create_tween()
		tween.set_loops(1)
		tween.tween_property(countdown_label, "scale", Vector2(1.5, 1.5), 0.2).from(Vector2.ZERO)
		tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.2)

# 
# GAME FLOW
# 

func start_game() -> void:
	# Start the game (called after countdown or immediately)
	game_active = true
	game_started_time = Time.get_ticks_msec()
	game_started.emit()
	
	# Start UI timer
	ui_timer = Timer.new()
	ui_timer.wait_time = 0.1
	ui_timer.timeout.connect(_update_timer_display)
	add_child(ui_timer)
	ui_timer.start()
	
	_log(" Game started! Duration: %.0fs | Inputs enabled" % game_duration)
	_log(" Player %d (%s) - Ready to play!" % [my_player_num, my_role])
	_on_game_start()

func _update_timer_display() -> void:
	# Update timer label and progress bar
	if not game_active:
		ui_timer.stop()
		return
		
	var elapsed = (Time.get_ticks_msec() - game_started_time) / 1000.0
	var remaining = max(0.0, game_duration - elapsed)
	
	if timer_label:
		if game_duration >= 999999.0:
			timer_label.text = "ENDLESS"
		else:
			timer_label.text = "%.0f" % remaining
			
			# Change color based on time remaining
			if remaining <= 5:
				timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			elif remaining <= 10:
				timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	
	# Update progress bar
	var progress_bar = hud_layer.get_node_or_null(
		"PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/VBoxContainer/TimerProgress"
	)
	if progress_bar and game_duration < 999999.0:
		progress_bar.value = remaining
		
		# Change bar color based on time
		var fill_style = progress_bar.get_theme_stylebox("fill")
		if fill_style is StyleBoxFlat:
			if remaining <= 5:
				fill_style.bg_color = Color(1.0, 0.3, 0.3)
			elif remaining <= 10:
				fill_style.bg_color = Color(1.0, 0.9, 0.3)
			else:
				fill_style.bg_color = Color(0.3, 0.8, 1.0)
	
	if remaining <= 0 and game_duration < 999999.0:
		_on_time_up()

func _on_time_up() -> void:
	# Called when time runs out
	_log(" Time up!")
	# Default behavior: If quota exists and not met, fail. Else success.
	if win_quota > 0:
		if local_score >= win_quota:
			end_game(true)
		else:
			_log(" Quota not met (%d/%d)" % [local_score, win_quota])
			end_game(false)
	else:
		end_game(true) # Survival success

func _on_countdown_complete() -> void:
	# Called when countdown reaches GO
	_hide_countdown_overlay()
	start_game()

func end_game(success: bool) -> void:
	# End the game and report results
	if not game_active:
		return
	
	game_active = false
	
	_log(" Game ended - %s" % ("Success" if success else "Failed"))
	
	# Show results/waiting overlay
	_show_results_screen(success)
	
	game_completed.emit(success)
	
	# Report completion to NetworkManager with scores
	if NetworkManager:
		NetworkManager.report_player_completion(success, local_score)

func show_waiting_overlay() -> void:
	# Show waiting for partner overlay
	is_waiting_for_partner = true
	# waiting_overlay is now handled by _show_results_screen(true)
	_log(" Waiting for partner...")

func hide_waiting_overlay() -> void:
	# Hide waiting overlay
	is_waiting_for_partner = false
	var results = hud_layer.get_node_or_null("ResultsOverlay")
	if results:
		results.visible = false

# 
# SCORING (G-Counter)
# 

func add_score(points: int) -> void:
	# Add points to local score and sync via G-Counter
	local_score += points
	
	if NetworkManager:
		NetworkManager.increment_local(points)
	
	_log(" +%d points (Local: %d)" % [points, local_score])
	
	# Check quota
	if win_quota > 0 and local_score >= win_quota:
		_log(" Quota met! (%d/%d)" % [local_score, win_quota])
		end_game(true)

# 
# PAUSE HANDLING
# 

func _on_pause_pressed() -> void:
	# Local player pressed pause
	if NetworkManager:
		NetworkManager.request_pause()
	
	if pause_menu:
		pause_menu.visible = true

func _on_resume_pressed() -> void:
	# Local player pressed resume
	if NetworkManager:
		NetworkManager.request_resume()
	
	if pause_menu:
		pause_menu.visible = false

func _on_quit_pressed() -> void:
	# Quit button pressed - terminate session for both players
	if pause_menu:
		pause_menu.visible = false
	
	_log(" Player quitting session")
	
	if NetworkManager:
		# Disconnect and return both players to lobby
		NetworkManager.disconnect_multiplayer()
	
	# Return to lobby
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _on_remote_pause() -> void:
	# Partner paused the game
	if pause_menu:
		pause_menu.visible = true

func _on_remote_resume() -> void:
	# Partner resumed the game
	if pause_menu:
		pause_menu.visible = false

func _on_player_left_session(_peer_id: int) -> void:
	# Handle when any player leaves - terminate session for both players
	_log(" Player left session - terminating for all players")
	
	game_active = false
	
	# Show disconnect message
	var disconnect_overlay = Control.new()
	disconnect_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(disconnect_overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	disconnect_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	disconnect_overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "Player Disconnected"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	vbox.add_child(title)
	
	var message = Label.new()
	message.text = "Session terminated. Returning to lobby..."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 24)
	vbox.add_child(message)
	
	# Wait 2 seconds then return to lobby
	var tree = get_tree()
	if tree:
		await tree.create_timer(2.0).timeout
		
		if NetworkManager:
			NetworkManager.disconnect_multiplayer()
		
		if is_inside_tree():
			tree.change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _on_server_disconnected() -> void:
	# Handle when server disconnects (Host quits)
	_log(" Server disconnected - terminating session")
	
	# Don't call _on_player_left_session to avoid duplicate UI
	if NetworkManager:
		NetworkManager.disconnect_multiplayer()
	
	var tree = get_tree()
	if tree and is_inside_tree():
		tree.change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

# 
# MAIN LOOP
# 

func _process(_delta: float) -> void:
	# Update timer display with countdown colors
	if not game_active or not timer_label:
		return
	
	var elapsed = (Time.get_ticks_msec() - game_started_time) / 1000.0
	
	# Endless mode - show elapsed time
	if game_duration >= 999999.0:
		var minutes = int(elapsed / 60)
		var seconds = int(elapsed) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
		timer_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		# Timed mode - show countdown
		var time_left = game_duration - elapsed
		
		if time_left > 0:
			timer_label.text = "%.1f" % time_left
			
			# Color coding and animation
			if time_left <= 10.0:
				timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red
				# Pulse animation
				var pulse = (sin(elapsed * 10.0) + 1.0) * 0.1 + 1.0
				timer_label.scale = Vector2(pulse, pulse)
				# Ensure pivot is set for scaling from center
				if timer_label.pivot_offset == Vector2.ZERO:
					timer_label.pivot_offset = timer_label.size / 2
			elif time_left <= 20.0:
				timer_label.add_theme_color_override("font_color", Color(1, 1, 0.3))  # Yellow
				timer_label.scale = Vector2.ONE
			else:
				timer_label.add_theme_color_override("font_color", Color.WHITE)
				timer_label.scale = Vector2.ONE
		else:
			timer_label.text = "0.0"
			timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			end_game(false)

# 
# NETWORK CALLBACKS
# 

func _on_team_score_updated(total_score: int) -> void:
	# Team score updated via G-Counter
	var score_label = hud_layer.find_child("ScoreLabel", true, false)
	if score_label:
		score_label.text = " %d" % total_score
		
		# Pop animation
		var tween = create_tween()
		tween.set_loops(1)
		tween.tween_property(score_label, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.1)

func _on_team_lives_updated(remaining_lives: int) -> void:
	# Team lives updated
	var lives_label = hud_layer.find_child("LivesLabel", true, false)
	if lives_label:
		lives_label.text = " x%d" % remaining_lives
		
		# Flash red and shake if life lost
		var tween = create_tween()
		tween.set_loops(1)
		tween.tween_property(lives_label, "modulate", Color(2, 0.5, 0.5), 0.1)
		tween.tween_property(lives_label, "position:x", lives_label.position.x + 5, 0.05)
		tween.tween_property(lives_label, "position:x", lives_label.position.x - 5, 0.05)
		tween.tween_property(lives_label, "position:x", lives_label.position.x + 5, 0.05)
		tween.tween_property(lives_label, "position:x", lives_label.position.x - 5, 0.05)
		tween.tween_property(lives_label, "position:x", lives_label.position.x, 0.05)
		tween.tween_property(lives_label, "modulate", Color.WHITE, 0.1)
	
	# Check for game over
	if remaining_lives <= 0:
		_on_game_over()

func _on_resource_received(
	from_player: int,
	resource_type: String,
	amount: int,
	quality: float
) -> void:
	# Resource received from partner
	# Override in child class to handle resource
	_log(
		" Received %s x%d (quality: %.1f) from P%d" % [
			resource_type,
			amount,
			quality,
			from_player
		]
	)

func _on_task_marked(from_player: int, task_id: int, pos: Vector2) -> void:
	# Task marked by partner
	# Override in child class to handle task marking
	_log(" Task #%d marked by P%d at %s" % [task_id, from_player, pos])

# 
# HELPER FUNCTIONS
# 

func send_resource_to_partner(resource_type: String, amount: int, quality: float = 1.0) -> void:
	# Send resource to partner player
	if NetworkManager:
		NetworkManager.send_resource(resource_type, amount, quality)

func mark_task_for_partner(task_id: int, task_position: Vector2) -> void:
	# Mark a task for partner to complete
	if NetworkManager:
		NetworkManager.mark_task(task_id, task_position)

func _create_controls_panel() -> void:
	# Create persistent controls panel at bottom right
	var panel = PanelContainer.new()
	panel.name = "ControlsPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -280
	panel.offset_top = -180
	panel.offset_right = -20
	panel.offset_bottom = -20
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	
	hud_layer.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	vbox.add_child(margin)
	
	var controls_vbox = VBoxContainer.new()
	controls_vbox.add_theme_constant_override("separation", 5)
	margin.add_child(controls_vbox)
	
	var title = Label.new()
	title.text = "CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	controls_vbox.add_child(title)
	
	var separator = HSeparator.new()
	controls_vbox.add_child(separator)
	
	# Add controls based on game
	var controls_text = get_controls_text()
	var controls_label = Label.new()
	controls_label.text = controls_text
	controls_label.add_theme_font_size_override("font_size", 14)
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.custom_minimum_size = Vector2(220, 0)
	controls_vbox.add_child(controls_label)

func get_controls_text() -> String:
	# Override this to provide game-specific controls
	return "  Arrow Keys\n Click to interact\n Pause button"

func _log(message: String) -> void:
	# Internal logging
	print("[%s P%d] %s" % [game_name, my_player_num, message])

# 
# OVERRIDE THESE IN CHILD CLASSES
# 

func get_instructions() -> String:
	# Override: Return instruction text for this game
	return ""

func _on_multiplayer_ready() -> void:
	# Override: Called when multiplayer setup is complete
	pass

func _on_game_start() -> void:
	# Override: Called when game actually starts
	pass

func _on_game_over() -> void:
	# Override: Called when team runs out of lives
	_log(" GAME OVER")
	_show_results_screen(false)



func _show_game_over_screen() -> void:
	# Show game over screen when lives are depleted
	var overlay = Control.new()
	overlay.name = "GameOverOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.9)
	overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(title)
	
	var sub = Label.new()
	sub.text = "The team ran out of lives!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 32)
	vbox.add_child(sub)
	
	var score_label = Label.new()
	score_label.text = "Final Score: %d\nRounds Survived: %d" % [
		NetworkManager.get_total_score(),
		NetworkManager.rounds_survived
	]
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(score_label)
	
	var btn = Button.new()
	btn.text = "Return to Lobby"
	btn.custom_minimum_size = Vector2(200, 60)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func(): 
		if NetworkManager and NetworkManager.has_method("return_to_lobby"):
			NetworkManager.return_to_lobby()
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
	)
	
	var btn_container = CenterContainer.new()
	btn_container.add_child(btn)
	vbox.add_child(btn_container)

func _show_results_screen(success: bool) -> void:
	# Show Game Over or Success screen
	var overlay = Control.new()
	overlay.name = "ResultsOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "LEVEL COMPLETE!" if success else "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override(
		"font_color",
		Color(0.4, 1.0, 0.4) if success else Color(1.0, 0.3, 0.3)
	)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(title)
	
	var sub = Label.new()
	sub.text = "Waiting for partner..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 32)
	vbox.add_child(sub)
	
	# Add your score
	var score_label = Label.new()
	score_label.text = "Your Score: %d" % local_score
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(score_label)
	
	is_waiting_for_partner = true
	
	# Connect to NetworkManager signal for round transition
	if (
		NetworkManager
		and not NetworkManager.both_players_completed.is_connected(_on_both_players_completed)
	):
		NetworkManager.both_players_completed.connect(_on_both_players_completed)

func _on_both_players_completed(
	p1_success: bool,
	p2_success: bool,
	p1_score: int,
	p2_score: int
) -> void:
	# Called when both players complete their games
	_log(" Round Complete - P1: %s (%d), P2: %s (%d)" % [
		"Win" if p1_success else "Fail", p1_score,
		"Win" if p2_success else "Fail", p2_score
	])
	
	# Update results screen
	_show_round_summary(p1_success, p2_success, p1_score, p2_score)

func _show_round_summary(
	p1_success: bool,
	p2_success: bool,
	p1_score: int,
	p2_score: int
) -> void:
	# Show detailed round summary
	var overlay = hud_layer.get_node_or_null("ResultsOverlay")
	if not overlay:
		return
	
	# Clear and rebuild with full results
	for child in overlay.get_children():
		child.queue_free()
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.9)
	overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "ROUND COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	vbox.add_child(title)
	
	# Player 1 results
	var p1_label = Label.new()
	p1_label.text = "Player 1: %s - %d points" % [
		" WIN" if p1_success else " FAIL",
		p1_score
	]
	p1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1_label.add_theme_font_size_override("font_size", 32)
	p1_label.add_theme_color_override(
		"font_color",
		Color(0.4, 1.0, 0.4) if p1_success else Color(1.0, 0.4, 0.4)
	)
	vbox.add_child(p1_label)
	
	# Player 2 results
	var p2_label = Label.new()
	p2_label.text = "Player 2: %s - %d points" % [
		" WIN" if p2_success else " FAIL",
		p2_score
	]
	p2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2_label.add_theme_font_size_override("font_size", 32)
	p2_label.add_theme_color_override(
		"font_color",
		Color(0.4, 1.0, 0.4) if p2_success else Color(1.0, 0.4, 0.4)
	)
	vbox.add_child(p2_label)
	
	# Team totals
	var total_label = Label.new()
	total_label.text = "Team Score: %d\nLives:  x%d\nRounds: %d" % [
		p1_score + p2_score,
		NetworkManager.team_lives,
		NetworkManager.rounds_survived
	]
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 28)
	total_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(total_label)
	
	# Life deduction notice
	if not p1_success or not p2_success:
		var life_notice = Label.new()
		life_notice.text = " Life Lost!"
		life_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		life_notice.add_theme_font_size_override("font_size", 36)
		life_notice.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		vbox.add_child(life_notice)
	
	# Next round notice
	var next_label = Label.new()
	next_label.text = "Loading next round..."
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.add_theme_font_size_override("font_size", 24)
	next_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	vbox.add_child(next_label)
