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
var _disconnect_handled: bool = false

# Performance tracking for CoopAdaptation
var mistakes_made: int = 0
var correct_actions: int = 0
var total_actions: int = 0

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

	# Accept connection from either NetworkManager (join_server path) or
	# GameManager (host_game / join_game path). Blue-screen bug: if only
	# GameManager was used NetworkManager.connection_active is false, so we
	# must not bail out here.
	var gm_connected: bool = GameManager != null and GameManager.is_multiplayer_connected
	var nm_connected: bool = NetworkManager != null and NetworkManager.is_multiplayer_connected()
	if not gm_connected and not nm_connected:
		push_error("MultiplayerMiniGameBase: Not connected to multiplayer")
		return

	# Get player number — prefer GameManager's authoritative local_player_num,
	# fall back to NetworkManager for backwards-compatibility.
	if GameManager and GameManager.local_player_num > 0:
		my_player_num = GameManager.local_player_num
	elif NetworkManager:
		my_player_num = NetworkManager.get_local_player_num()
	else:
		my_player_num = 1

	# Resolve role.  NetworkManager may have "Collector"/"Distributor" labels if
	# it managed the connection.  For the GameManager path, derive from mode assignment.
	var _nm_has_role: bool = NetworkManager != null and NetworkManager.is_multiplayer_connected()
	if _nm_has_role:
		my_role = NetworkManager.get_player_role(my_player_num)
	elif GameManager:
		var _mode: int = GameManager.player_modes.get(
			multiplayer.get_unique_id(), my_player_num
		)
		my_role = "Collector" if _mode == 1 else "Distributor"
	else:
		my_role = "Player %d" % my_player_num
	
	# Load CoopAdaptation difficulty and sync to GameManager.difficulty_multiplier
	# so child games that read difficulty_multiplier get the correct adaptive value
	var coop = get_node_or_null("/root/CoopAdaptation")
	if coop and coop.has_method("get_difficulty_params") and GameManager:
		var params: Dictionary = coop.get_difficulty_params(my_player_num)
		GameManager.difficulty_multiplier = params.get("speed_multiplier", 1.0)
		_log("🎯 CoopAdaptation difficulty loaded: %s (mult=%.2f)" % [
			coop.get_player_difficulty(my_player_num),
			GameManager.difficulty_multiplier
		])
	
	_log(" Multiplayer game starting - Player %d (%s)" % [my_player_num, my_role])
	
	# Initialize game-specific setup FIRST (sets game_name and game_duration)
	_on_multiplayer_ready()
	
	# Create background
	_create_background()
	
	# Setup UI AFTER game settings are configured
	_setup_multiplayer_ui()
	
	# Connect NetworkManager signals (NM path)
	if NetworkManager:
		if not NetworkManager.team_score_updated.is_connected(_on_team_score_updated):
			NetworkManager.team_score_updated.connect(_on_team_score_updated)
		if not NetworkManager.team_lives_updated.is_connected(_on_team_lives_updated):
			NetworkManager.team_lives_updated.connect(_on_team_lives_updated)
		if not NetworkManager.round_starting.is_connected(_on_countdown_tick):
			NetworkManager.round_starting.connect(_on_countdown_tick)
		if not NetworkManager.resource_sent.is_connected(_on_resource_received):
			NetworkManager.resource_sent.connect(_on_resource_received)
		if not NetworkManager.task_marked.is_connected(_on_task_marked):
			NetworkManager.task_marked.connect(_on_task_marked)
		if not NetworkManager.player_disconnected.is_connected(_on_player_left_session):
			NetworkManager.player_disconnected.connect(_on_player_left_session)
		if not NetworkManager.server_disconnected.is_connected(_on_server_disconnected):
			NetworkManager.server_disconnected.connect(_on_server_disconnected)
	# Also listen for MultiplayerAPI disconnects (GameManager path fallback)
	if not multiplayer.peer_disconnected.is_connected(_on_player_left_session):
		multiplayer.peer_disconnected.connect(_on_player_left_session)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	# Connect GameManager resource-pass signal (GM path)
	if GameManager and not _nm_has_role:
		if not GameManager.gm_resource_received.is_connected(_on_resource_received):
			GameManager.gm_resource_received.connect(_on_resource_received)
		if not GameManager.team_life_lost.is_connected(_on_team_lives_updated):
			GameManager.team_life_lost.connect(_on_team_lives_updated)
	
	# Show instructions (override get_instructions() in child class)
	var instructions_text = get_instructions()
	if instructions_text != "":
		show_instructions(instructions_text)
	else:
		# No instructions — start immediately with countdown
		if requires_countdown:
			if NetworkManager and NetworkManager.is_multiplayer_connected():
				var i_am_host: bool = (GameManager != null and GameManager.is_host) \
					or (NetworkManager != null and NetworkManager.is_server())
				if i_am_host and NetworkManager.has_method("start_countdown"):
					NetworkManager.start_countdown()
				_show_countdown_overlay()
			else:
				# GameManager path
				_run_local_countdown()
		else:
			start_game()

func _create_background() -> void:
	# ── Themed background matching single-player style ──
	var theme := _resolve_mp_theme()

	var bg_layer = CanvasLayer.new()
	bg_layer.name = "_ThemeLayer"
	bg_layer.layer = -120
	add_child(bg_layer)

	# Primary full-screen backdrop
	var primary_rect = ColorRect.new()
	primary_rect.name = "PrimaryBackdrop"
	primary_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	primary_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	primary_rect.color = theme.get("bg_primary", Color(0.73, 0.90, 0.99, 1.0))
	bg_layer.add_child(primary_rect)

	# Secondary glow (bottom half)
	var secondary_rect = ColorRect.new()
	secondary_rect.name = "SecondaryGlow"
	secondary_rect.anchor_left = 0.0
	secondary_rect.anchor_top = 0.42
	secondary_rect.anchor_right = 1.0
	secondary_rect.anchor_bottom = 1.0
	secondary_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sec_color: Color = theme.get("bg_secondary", Color(0.56, 0.79, 0.95, 1.0))
	sec_color.a = 0.33
	secondary_rect.color = sec_color
	bg_layer.add_child(secondary_rect)

	# Top wash overlay
	var wash_rect = ColorRect.new()
	wash_rect.name = "TopWash"
	wash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash_rect.color = theme.get("bg_wash", Color(0.86, 0.95, 1.0, 0.32))
	bg_layer.add_child(wash_rect)

	RenderingServer.set_default_clear_color(
		theme.get("bg_primary", Color(0.73, 0.90, 0.99, 1.0))
	)

func _resolve_mp_theme() -> Dictionary:
	# Use ThemeManager if available, otherwise sensible water-themed defaults
	if ThemeManager and ThemeManager.has_method("get_minigame_theme_for_name"):
		return ThemeManager.get_minigame_theme_for_name(game_name if game_name else "CoopMiniGame")
	return {
		"bg_primary": Color(0.73, 0.90, 0.99, 1.0),
		"bg_secondary": Color(0.56, 0.79, 0.95, 1.0),
		"bg_wash": Color(0.86, 0.95, 1.0, 0.32),
	}

func _setup_multiplayer_ui() -> void:
	# ══════════════════════════════════════════════════════════════════
	# SP-MATCHING PILL-STYLE HUD — Warm, rounded, kid-friendly design
	# ══════════════════════════════════════════════════════════════════
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 100
	add_child(hud_layer)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	hud_layer.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# ── Top Row: Name | Timer | Lives | Score | Role | Pause ──
	var top_row = HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	# -- Shared pill style (warm cream, matching SP) --
	var pill_style = StyleBoxFlat.new()
	pill_style.bg_color = Color(0.96, 0.93, 0.86, 0.92)
	pill_style.corner_radius_top_left = 20
	pill_style.corner_radius_top_right = 20
	pill_style.corner_radius_bottom_left = 20
	pill_style.corner_radius_bottom_right = 20
	pill_style.border_width_left = 2
	pill_style.border_width_right = 2
	pill_style.border_width_top = 2
	pill_style.border_width_bottom = 2
	pill_style.border_color = Color(0.85, 0.8, 0.7, 0.6)
	pill_style.shadow_size = 3
	pill_style.shadow_offset = Vector2(0, 2)
	pill_style.shadow_color = Color(0, 0, 0, 0.12)

	# -- Game Name (left) --
	var name_pill = PanelContainer.new()
	name_pill.add_theme_stylebox_override("panel", pill_style.duplicate())
	top_row.add_child(name_pill)

	var name_inner = MarginContainer.new()
	name_inner.add_theme_constant_override("margin_left", 14)
	name_inner.add_theme_constant_override("margin_right", 14)
	name_inner.add_theme_constant_override("margin_top", 6)
	name_inner.add_theme_constant_override("margin_bottom", 6)
	name_pill.add_child(name_inner)

	var hud_name_label = Label.new()
	hud_name_label.text = game_name if game_name else "Co-op"
	hud_name_label.add_theme_font_size_override("font_size", 22)
	hud_name_label.add_theme_color_override("font_color", Color(0.25, 0.22, 0.18))
	name_inner.add_child(hud_name_label)

	# -- Spacer --
	var spacer_l = Control.new()
	spacer_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer_l)

	# -- Timer Pill (center) --
	var timer_pill = PanelContainer.new()
	timer_pill.add_theme_stylebox_override("panel", pill_style.duplicate())
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
	timer_label.name = "TimerLabel"
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.add_theme_color_override("font_color", Color(0.3, 0.28, 0.22))
	timer_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	timer_label.add_theme_constant_override("outline_size", 2)
	if game_duration >= 999999.0:
		timer_label.text = "ENDLESS"
	else:
		timer_label.text = "%.0fs" % game_duration
	timer_hbox.add_child(timer_label)

	# -- Spacer --
	var spacer_r = Control.new()
	spacer_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer_r)

	# -- Lives Pill --
	var lives_pill = PanelContainer.new()
	lives_pill.add_theme_stylebox_override("panel", pill_style.duplicate())
	top_row.add_child(lives_pill)

	var lives_inner = MarginContainer.new()
	lives_inner.add_theme_constant_override("margin_left", 14)
	lives_inner.add_theme_constant_override("margin_right", 14)
	lives_inner.add_theme_constant_override("margin_top", 6)
	lives_inner.add_theme_constant_override("margin_bottom", 6)
	lives_pill.add_child(lives_inner)

	var lives_hbox = HBoxContainer.new()
	lives_hbox.add_theme_constant_override("separation", 6)
	lives_inner.add_child(lives_hbox)

	var lives_icon = Label.new()
	lives_icon.text = "❤"
	lives_icon.add_theme_font_size_override("font_size", 22)
	lives_icon.add_theme_color_override("font_color", Color(0.9, 0.25, 0.3))
	lives_hbox.add_child(lives_icon)

	var _nm_ok := NetworkManager != null and NetworkManager.is_multiplayer_connected()
	var _lives_val: int = NetworkManager.team_lives if _nm_ok \
		else (GameManager.team_lives if GameManager else 3)
	var lives_label = Label.new()
	lives_label.name = "LivesLabel"
	lives_label.text = "x%d" % _lives_val
	lives_label.add_theme_font_size_override("font_size", 22)
	lives_label.add_theme_color_override("font_color", Color(0.45, 0.2, 0.2))
	lives_label.pivot_offset = Vector2(20, 12)
	lives_hbox.add_child(lives_label)

	# -- Score + Combo Pill --
	var score_pill = PanelContainer.new()
	score_pill.add_theme_stylebox_override("panel", pill_style.duplicate())
	top_row.add_child(score_pill)

	var score_inner = MarginContainer.new()
	score_inner.add_theme_constant_override("margin_left", 14)
	score_inner.add_theme_constant_override("margin_right", 14)
	score_inner.add_theme_constant_override("margin_top", 6)
	score_inner.add_theme_constant_override("margin_bottom", 6)
	score_pill.add_child(score_inner)

	var score_hbox = HBoxContainer.new()
	score_hbox.add_theme_constant_override("separation", 6)
	score_inner.add_child(score_hbox)

	var score_icon = Label.new()
	score_icon.text = "⭐"
	score_icon.add_theme_font_size_override("font_size", 22)
	score_hbox.add_child(score_icon)

	var _has_gm_score := GameManager != null and GameManager.has_method("get_global_score")
	var _score_val: int = NetworkManager.get_total_score() if _nm_ok \
		else (GameManager.get_global_score() if _has_gm_score else 0)
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = str(_score_val)
	score_label.add_theme_font_size_override("font_size", 22)
	score_label.add_theme_color_override("font_color", Color(0.45, 0.38, 0.2))
	score_label.pivot_offset = Vector2(20, 12)
	score_hbox.add_child(score_label)

	# -- Role Pill --
	var role_pill = PanelContainer.new()
	var role_style = pill_style.duplicate() as StyleBoxFlat
	role_style.bg_color = Color(0.88, 0.95, 0.88, 0.92)
	role_style.border_color = Color(0.5, 0.8, 0.5, 0.5)
	role_pill.add_theme_stylebox_override("panel", role_style)
	top_row.add_child(role_pill)

	var role_inner = MarginContainer.new()
	role_inner.add_theme_constant_override("margin_left", 12)
	role_inner.add_theme_constant_override("margin_right", 12)
	role_inner.add_theme_constant_override("margin_top", 4)
	role_inner.add_theme_constant_override("margin_bottom", 4)
	role_pill.add_child(role_inner)

	var role_vbox = VBoxContainer.new()
	role_vbox.add_theme_constant_override("separation", 2)
	role_inner.add_child(role_vbox)

	var role_label = Label.new()
	role_label.name = "RoleLabel"
	role_label.text = "YOU: %s" % my_role
	role_label.add_theme_font_size_override("font_size", 14)
	role_label.add_theme_color_override("font_color", Color(0.15, 0.45, 0.15))
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_vbox.add_child(role_label)

	# Partner Role
	var partner_num: int = 2 if my_player_num == 1 else 1
	var partner_role_name: String
	var _nm_ok_hud: bool = NetworkManager != null and NetworkManager.is_multiplayer_connected()
	if _nm_ok_hud:
		partner_role_name = NetworkManager.get_player_role(partner_num)
	elif GameManager:
		var _peer_ids: Array = GameManager.get_connected_multiplayer_peer_ids()
		var _partner_id: int = 0
		for pid in _peer_ids:
			if pid != multiplayer.get_unique_id():
				_partner_id = pid
				break
		var _pmode: int = GameManager.player_modes.get(_partner_id, partner_num)
		partner_role_name = "Collector" if _pmode == 1 else "Distributor"
	else:
		partner_role_name = "Player %d" % partner_num
	var partner_label = Label.new()
	partner_label.name = "PartnerLabel"
	partner_label.text = "P2: %s" % partner_role_name
	partner_label.add_theme_font_size_override("font_size", 12)
	partner_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.25))
	partner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_vbox.add_child(partner_label)

	# -- Pause Button (matching SP style) --
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
	pause_btn.focus_mode = Control.FOCUS_NONE
	top_row.add_child(pause_btn)

	# ── Timer Progress Bar (thin bar below top row, matching SP) ──
	var timer_bar = ProgressBar.new()
	timer_bar.name = "TimerProgress"
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

	vbox.add_child(timer_bar)

	# Create overlays
	_create_pause_menu()
	_create_waiting_overlay()
	_create_countdown_overlay()
	_create_instruction_overlay()
	_create_controls_panel()
	_setup_cutscene_player()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CUTSCENE SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var cutscene_player: Node = null

func _setup_cutscene_player() -> void:
	## Initialize SimpleCutscenePlayer for win/fail animations
	var simple_cutscene_script = load("res://scripts/cutscenes/SimpleCutscenePlayer.gd")
	if simple_cutscene_script:
		cutscene_player = simple_cutscene_script.new()
		cutscene_player.visible = false
		cutscene_player.set_anchors_preset(Control.PRESET_FULL_RECT)
		hud_layer.add_child(cutscene_player)

func _show_success_cutscene() -> void:
	## Show animated success cutscene
	if AudioManager:
		AudioManager.play_music("outcome_win", 0.18)
	
	if cutscene_player and cutscene_player.has_method("play_cutscene"):
		cutscene_player.visible = true
		cutscene_player.play_cutscene(game_name, 0)  # 0 = win
		await cutscene_player.cutscene_finished
		cutscene_player.visible = false

func _show_failure_cutscene() -> void:
	## Show animated failure cutscene
	if AudioManager:
		AudioManager.play_music("outcome_fail", 0.18)
	
	if cutscene_player and cutscene_player.has_method("play_cutscene"):
		cutscene_player.visible = true
		cutscene_player.play_cutscene(game_name, 1)  # 1 = fail
		await cutscene_player.cutscene_finished
		cutscene_player.visible = false

func _show_scoring_page(success: bool) -> void:
	## Show scoring/tally page with shared lives (like single-player)
	var scoring_overlay = Control.new()
	scoring_overlay.name = "ScoringOverlay"
	scoring_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(scoring_overlay)
	
	# Frosted backdrop
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.08, 0.14, 0.92)
	scoring_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scoring_overlay.add_child(center)
	
	# Card panel
	var panel = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.96, 0.93, 0.87, 0.98)
	card_style.corner_radius_top_left = 32
	card_style.corner_radius_top_right = 32
	card_style.corner_radius_bottom_left = 32
	card_style.corner_radius_bottom_right = 32
	card_style.border_width_left = 3
	card_style.border_width_right = 3
	card_style.border_width_top = 3
	card_style.border_width_bottom = 3
	card_style.border_color = Color(0.4, 0.72, 0.9, 0.6)
	card_style.shadow_size = 12
	card_style.shadow_color = Color(0, 0, 0, 0.25)
	card_style.content_margin_left = 60
	card_style.content_margin_right = 60
	card_style.content_margin_top = 48
	card_style.content_margin_bottom = 48
	panel.add_theme_stylebox_override("panel", card_style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.custom_minimum_size = Vector2(600, 0)
	panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "VICTORY!" if success else "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override(
			"font_color",
			Color(0.3, 0.8, 0.4) if success else Color(0.9, 0.3, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)
	
	# Separator
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# ═══════════════════════════════════════════════════════════════════
	# SHARED LIVES DISPLAY (Key difference from single-player)
	# ═══════════════════════════════════════════════════════════════════
	var lives_box = HBoxContainer.new()
	lives_box.alignment = BoxContainer.ALIGNMENT_CENTER
	lives_box.add_theme_constant_override("separation", 12)
	vbox.add_child(lives_box)
	
	var lives_icon = Label.new()
	lives_icon.text = "❤️"
	lives_icon.add_theme_font_size_override("font_size", 36)
	lives_box.add_child(lives_icon)
	
	var lives_label = Label.new()
	var team_lives = 3
	if GameManager:
		team_lives = GameManager.team_lives
	elif NetworkManager:
		team_lives = NetworkManager.team_lives
	lives_label.text = "SHARED LIVES: %d" % team_lives
	lives_label.add_theme_font_size_override("font_size", 32)
	lives_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	lives_box.add_child(lives_label)
	
	# Score display
	var score_box = HBoxContainer.new()
	score_box.alignment = BoxContainer.ALIGNMENT_CENTER
	score_box.add_theme_constant_override("separation", 12)
	vbox.add_child(score_box)
	
	var score_icon = Label.new()
	score_icon.text = "⭐"
	score_icon.add_theme_font_size_override("font_size", 36)
	score_box.add_child(score_icon)
	
	var score_label = Label.new()
	var global_score = 0
	if GameManager and GameManager.has_method("get_global_score"):
		global_score = GameManager.get_global_score()
	elif NetworkManager and NetworkManager.has_method("get_total_score"):
		global_score = NetworkManager.get_total_score()
	score_label.text = "TEAM SCORE: %d" % global_score
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_color", Color(0.45, 0.38, 0.2))
	score_box.add_child(score_label)
	
	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Continue message
	var continue_label = Label.new()
	continue_label.text = "Waiting for next game..." if success else "Better luck next time!"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_size_override("font_size", 24)
	continue_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(continue_label)
	
	# Animate entrance
	scoring_overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(scoring_overlay, "modulate:a", 1.0, 0.5)
	
	# Wait 3 seconds
	await get_tree().create_timer(3.0).timeout
	
	# Animate exit
	var exit_tween = create_tween()
	exit_tween.tween_property(scoring_overlay, "modulate:a", 0.0, 0.5)
	await exit_tween.finished
	
	scoring_overlay.queue_free()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME OVERLAYS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


func _create_pause_menu() -> void:
	# ── Frosted glass pause overlay (matching SP style) ──
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(pause_menu)

	# Frosted backdrop
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.08, 0.14, 0.82)
	pause_menu.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)

	# ── Main card panel ──
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.14, 0.22, 0.92)
	card_style.corner_radius_top_left = 32
	card_style.corner_radius_top_right = 32
	card_style.corner_radius_bottom_left = 32
	card_style.corner_radius_bottom_right = 32
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_color = Color(0.3, 0.65, 0.9, 0.4)
	card_style.shadow_color = Color(0, 0, 0, 0.35)
	card_style.shadow_size = 12
	card_style.content_margin_left = 60
	card_style.content_margin_right = 60
	card_style.content_margin_top = 44
	card_style.content_margin_bottom = 44
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# ── Water drop icon ──
	var drop_icon = Label.new()
	drop_icon.text = "💧"
	drop_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop_icon.add_theme_font_size_override("font_size", 56)
	vbox.add_child(drop_icon)

	# Gentle pulse
	var pulse = drop_icon.create_tween().set_loops()
	pulse.tween_property(drop_icon, "modulate", Color(0.8, 0.9, 1.2), 0.8)\
		.set_trans(Tween.TRANS_SINE)
	pulse.tween_property(drop_icon, "modulate", Color.WHITE, 0.8)\
		.set_trans(Tween.TRANS_SINE)

	# ── Title ──
	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.35, 0.6))
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)

	# ── Score + Role display ──
	var _nm_ok_pm: bool = NetworkManager != null and NetworkManager.is_multiplayer_connected()
	var _pm_lives: int = (NetworkManager.team_lives if _nm_ok_pm
		else (GameManager.team_lives if GameManager else 3))
	var _pm_score: int = 0
	if _nm_ok_pm and NetworkManager.has_method("get_total_score"):
		_pm_score = NetworkManager.get_total_score()
	elif GameManager and GameManager.has_method("get_global_score"):
		_pm_score = GameManager.get_global_score()

	var score_info = Label.new()
	score_info.text = "❤ %d   ⭐ %d   Role: %s" % [_pm_lives, _pm_score, my_role]
	score_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_info.add_theme_font_size_override("font_size", 20)
	score_info.add_theme_color_override("font_color", Color(0.6, 0.75, 0.88))
	vbox.add_child(score_info)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	# ── RESUME Button ──
	var resume_btn = Button.new()
	resume_btn.text = "▶  RESUME"
	resume_btn.custom_minimum_size = Vector2(260, 64)
	var resume_style = StyleBoxFlat.new()
	resume_style.bg_color = Color(0.2, 0.6, 0.4, 0.92)
	resume_style.corner_radius_top_left = 32
	resume_style.corner_radius_top_right = 32
	resume_style.corner_radius_bottom_left = 32
	resume_style.corner_radius_bottom_right = 32
	resume_style.border_width_top = 2
	resume_style.border_width_bottom = 2
	resume_style.border_width_left = 2
	resume_style.border_width_right = 2
	resume_style.border_color = Color(0.35, 0.85, 0.55, 0.5)
	resume_btn.add_theme_stylebox_override("normal", resume_style)
	var resume_hover = resume_style.duplicate()
	resume_hover.bg_color = Color(0.25, 0.7, 0.48, 0.95)
	resume_btn.add_theme_stylebox_override("hover", resume_hover)
	resume_btn.add_theme_font_size_override("font_size", 24)
	resume_btn.add_theme_color_override("font_color", Color.WHITE)
	resume_btn.focus_mode = Control.FOCUS_NONE
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)

	# ── QUIT Button ──
	var quit_btn = Button.new()
	quit_btn.text = "✕  QUIT SESSION"
	quit_btn.custom_minimum_size = Vector2(260, 56)
	var quit_style = StyleBoxFlat.new()
	quit_style.bg_color = Color(0.55, 0.15, 0.15, 0.9)
	quit_style.corner_radius_top_left = 32
	quit_style.corner_radius_top_right = 32
	quit_style.corner_radius_bottom_left = 32
	quit_style.corner_radius_bottom_right = 32
	quit_style.border_width_top = 2
	quit_style.border_width_bottom = 2
	quit_style.border_width_left = 2
	quit_style.border_width_right = 2
	quit_style.border_color = Color(0.9, 0.3, 0.3, 0.4)
	quit_btn.add_theme_stylebox_override("normal", quit_style)
	quit_btn.add_theme_font_size_override("font_size", 22)
	quit_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	quit_btn.focus_mode = Control.FOCUS_NONE
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
	# ── SP-matching animated instruction overlay ──
	instruction_overlay = Control.new()
	instruction_overlay.name = "InstructionOverlay"
	instruction_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	instruction_overlay.visible = false
	instruction_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(instruction_overlay)

	# Frosted backdrop
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.08, 0.14, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction_overlay.add_child(bg)

	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	instruction_overlay.add_child(center)

	# ── Card with soft glow border ──
	var panel = PanelContainer.new()
	panel.name = "PanelContainer"
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.96, 0.93, 0.87, 0.95)
	card_style.corner_radius_top_left = 28
	card_style.corner_radius_top_right = 28
	card_style.corner_radius_bottom_left = 28
	card_style.corner_radius_bottom_right = 28
	card_style.border_width_left = 3
	card_style.border_width_right = 3
	card_style.border_width_top = 3
	card_style.border_width_bottom = 3
	card_style.border_color = Color(0.4, 0.72, 0.9, 0.55)
	card_style.shadow_size = 10
	card_style.shadow_color = Color(0, 0, 0, 0.2)
	card_style.content_margin_left = 48
	card_style.content_margin_right = 48
	card_style.content_margin_top = 36
	card_style.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", card_style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(520, 0)
	panel.add_child(vbox)

	# ── Game Name (large, with entrance animation) ──
	var title = Label.new()
	title.name = "Title"
	title.text = game_name if game_name else "Co-op"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.2, 0.35, 0.5))
	title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	title.add_theme_constant_override("outline_size", 3)
	title.pivot_offset = Vector2(260, 28)
	title.scale = Vector2(0.5, 0.5)
	title.modulate.a = 0.0
	vbox.add_child(title)

	# Entrance tween for title
	var title_enter = create_tween()
	title_enter.tween_property(title, "scale", Vector2.ONE, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_enter.parallel().tween_property(title, "modulate:a", 1.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC)

	# ── Role badge (green pill) ──
	var role_box = HBoxContainer.new()
	role_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(role_box)

	var role_panel = PanelContainer.new()
	var role_style = StyleBoxFlat.new()
	role_style.bg_color = Color(0.82, 0.95, 0.82, 0.9)
	role_style.corner_radius_top_left = 14
	role_style.corner_radius_top_right = 14
	role_style.corner_radius_bottom_left = 14
	role_style.corner_radius_bottom_right = 14
	role_style.content_margin_left = 16
	role_style.content_margin_right = 16
	role_style.content_margin_top = 6
	role_style.content_margin_bottom = 6
	role_panel.add_theme_stylebox_override("panel", role_style)
	role_box.add_child(role_panel)

	var role = Label.new()
	role.name = "Role"
	role.text = "YOUR ROLE: %s" % my_role.to_upper()
	role.add_theme_font_size_override("font_size", 20)
	role.add_theme_color_override("font_color", Color(0.15, 0.4, 0.15))
	role_panel.add_child(role)

	# ── Separator ──
	var separator = HSeparator.new()
	separator.add_theme_stylebox_override("separator", StyleBoxLine.new())
	vbox.add_child(separator)

	# ── Instructions text ──
	var instructions = Label.new()
	instructions.name = "Instructions"
	instructions.text = "Instructions will appear here"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 22)
	instructions.add_theme_color_override("font_color", Color(0.3, 0.28, 0.22))
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(instructions)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	# ── TAP TO START (blinking) ──
	var start_label = Label.new()
	start_label.text = "TAP TO START"
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_label.add_theme_font_size_override("font_size", 22)
	start_label.add_theme_color_override("font_color", Color(0.35, 0.6, 0.85))
	vbox.add_child(start_label)

	var blink = start_label.create_tween().set_loops()
	blink.tween_property(start_label, "modulate:a", 0.25, 0.7)\
		.set_trans(Tween.TRANS_SINE)
	blink.tween_property(start_label, "modulate:a", 1.0, 0.7)\
		.set_trans(Tween.TRANS_SINE)

	# Full-screen transparent button to catch ANY click/tap anywhere on the overlay.
	var click_catcher = Button.new()
	click_catcher.name = "ClickCatcher"
	click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catcher.flat = true
	click_catcher.focus_mode = Control.FOCUS_NONE
	var empty_style = StyleBoxEmpty.new()
	click_catcher.add_theme_stylebox_override("normal", empty_style)
	click_catcher.add_theme_stylebox_override("hover", empty_style)
	click_catcher.add_theme_stylebox_override("pressed", empty_style)
	click_catcher.pressed.connect(_on_instruction_clicked_btn)
	instruction_overlay.add_child(click_catcher)


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
		# ClickCatcher button handles the dismiss; no gui_input connection needed.

func _on_instruction_clicked_btn() -> void:
	# Called by the full-screen ClickCatcher button on the instruction overlay.
	if not instruction_overlay or not instruction_overlay.visible:
		return
	# Disable catcher so it can't be clicked twice
	var catcher = instruction_overlay.get_node_or_null("ClickCatcher")
	if catcher:
		catcher.disabled = true
	
	# Fade out instructions
	var tween = create_tween()
	tween.tween_property(instruction_overlay, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		instruction_overlay.visible = false
		instruction_overlay.modulate.a = 1.0
	)
	
	# Start the game: GameManager path uses a local countdown; NetworkManager path
	# waits for partner readiness before starting.
	if NetworkManager and NetworkManager.is_multiplayer_connected():
		_show_waiting_for_start()
		if NetworkManager.has_method("set_local_player_ready"):
			NetworkManager.set_local_player_ready()
		else:
			var i_am_host: bool = (GameManager != null and GameManager.is_host) \
				or NetworkManager.is_server()
			if i_am_host:
				NetworkManager.start_countdown()
			_show_countdown_overlay()
	else:
		_run_local_countdown()

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
			# Animate the number
			var tween = create_tween()
			tween.set_loops(1)
			var sc := Vector2(1.5, 1.5)
			tween.tween_property(countdown_label, "scale", sc, 0.2).from(Vector2.ZERO)
			tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.2)
		else:
			countdown_label.text = "GO!"
			# Animate GO! then start game
			var tween = create_tween()
			tween.set_loops(1)
			var sc2 := Vector2(1.5, 1.5)
			tween.tween_property(countdown_label, "scale", sc2, 0.2).from(Vector2.ZERO)
			tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.2)
			await get_tree().create_timer(1.0).timeout
			_on_countdown_complete()

# 
# GAME FLOW
# 

## Local countdown used when GameManager (not NetworkManager) manages the session.
## Runs entirely on this device — no RPC required.
func _run_local_countdown() -> void:
	_show_countdown_overlay()
	for n in [3, 2, 1, 0]:
		_on_countdown_tick(n)
		await get_tree().create_timer(1.0).timeout

func start_game() -> void:
	# Start the game (called after countdown or immediately)
	game_active = true
	game_started_time = Time.get_ticks_msec()
	game_started.emit()
	
	# Register with AutoPlayManager if MP auto-play is enabled (separate toggle from SP)
	if AutoPlayManager and AutoPlayManager.is_mp_auto_play_enabled():
		AutoPlayManager.register_multiplayer_game(self, my_role)
	
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
	
	# Update progress bar (find dynamically since it's created in code)
	var progress_bar = hud_layer.find_child("TimerProgress", true, false)
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
	_log("⏰ Time up!")
	
	# ═══════════════════════════════════════════════════════════════════
	# BUG FIX: Check GLOBAL/TEAM score, not just local_score
	# In multiplayer, scores are distributed via G-Counter across players
	# ═══════════════════════════════════════════════════════════════════
	var team_score: int = local_score  # Fallback to local if no manager
	
	# Get global score from GameManager (G-Counter) or NetworkManager
	if GameManager and GameManager.has_method("get_global_score"):
		team_score = GameManager.get_global_score()
	elif NetworkManager and NetworkManager.has_method("get_total_score"):
		team_score = NetworkManager.get_total_score()
	
	_log("📊 Final Score: Team=%d, Local=%d, Quota=%d" % [team_score, local_score, win_quota])
	
	# Check win condition based on TEAM score
	if win_quota > 0:
		if team_score >= win_quota:
			_log("✅ TEAM WIN! Score %d >= Quota %d" % [team_score, win_quota])
			end_game(true)
		else:
			_log("❌ TEAM FAIL! Score %d < Quota %d" % [team_score, win_quota])
			end_game(false)
	else:
		# No quota = survival mode, reaching time limit is success
		end_game(true)

func _on_countdown_complete() -> void:
	# Called when countdown reaches GO
	_hide_countdown_overlay()
	start_game()

func end_game(success: bool) -> void:
	# End the game and report results
	if not game_active:
		return
	
	game_active = false
	
	# Unregister from AutoPlayManager
	if AutoPlayManager and (
		AutoPlayManager.is_auto_play_enabled()
		or AutoPlayManager.is_mp_auto_play_enabled()
	):
		AutoPlayManager.unregister_game()
	
	_log(" Game ended - %s" % ("Success" if success else "Failed"))
	
	# ═══════════════════════════════════════════════════════════════════
	# RECORD PER-DEVICE METRICS TO SESSION LOGGER
	# ═══════════════════════════════════════════════════════════════════
	if SessionLogger and SessionLogger.has_method("record_mp_local_round"):
		# Calculate local performance metrics
		var my_accuracy: float = 0.0
		if total_actions > 0:
			my_accuracy = clamp(float(correct_actions) / float(total_actions), 0.0, 1.0)
		elif win_quota > 0:
			my_accuracy = clamp(float(local_score) / float(win_quota), 0.0, 1.0)
		else:
			my_accuracy = 1.0 if success else 0.0
		
		var my_reaction_time_ms: int = Time.get_ticks_msec() - game_started_time
		if my_reaction_time_ms < 0:
			my_reaction_time_ms = 0
		
		# Get local difficulty and Φ
		var my_difficulty: String = "Medium"
		var my_phi: float = 0.0
		if CoopAdaptation:
			my_difficulty = CoopAdaptation.get_player_difficulty(my_player_num)
			var metrics = CoopAdaptation.get_team_metrics()
			if my_player_num == 1:
				my_phi = float(metrics.get("player1_proficiency", 0.0))
			else:
				my_phi = float(metrics.get("player2_proficiency", 0.0))
		
		# Get partner score (from G-Counter or NetworkManager)
		var partner_score: int = 0
		if GameManager and GameManager.has_method("get_global_score"):
			var total_score = GameManager.get_global_score()
			partner_score = max(0, total_score - local_score)
		elif NetworkManager and NetworkManager.has_method("get_total_score"):
			var total_score = NetworkManager.get_total_score()
			partner_score = max(0, total_score - local_score)
		
		# Connection quality metrics are not exposed by ENetMultiplayerPeer's GDScript API.
		# Latency and packet loss are logged at 0.0 as intentional placeholders;
		# they do not affect gameplay or adaptive difficulty calculations.
		var latency_ms: float = 0.0
		var packet_loss_pct: float = 0.0
		
		# Get round number
		var round_num: int = 1
		if SessionLogger and SessionLogger.has_method("record_mp_local_round"):
			round_num = int(SessionLogger.mp_rounds_count) + 1
		elif NetworkManager:
			round_num = NetworkManager.rounds_played + 1
		
		# Record to SessionLogger
		SessionLogger.record_mp_local_round(
			round_num,
			game_name,
			local_score,
			my_accuracy,
			my_reaction_time_ms,
			mistakes_made,
			my_difficulty,
			my_phi,
			partner_score,
			success,
			latency_ms,
			packet_loss_pct
		)
		
		_log("📊 Recorded per-device metrics: Score=%d, Acc=%.1f%%, RT=%dms" % [
			local_score, my_accuracy * 100.0, my_reaction_time_ms
		])
	
	# ═══════════════════════════════════════════════════════════════════
	# SHOW CUTSCENE (like single-player)
	# ═══════════════════════════════════════════════════════════════════
	if success:
		await _show_success_cutscene()
	else:
		await _show_failure_cutscene()
	
	# ═══════════════════════════════════════════════════════════════════
	# SHOW SCORING PAGE (like single-player)
	# ═══════════════════════════════════════════════════════════════════
	await _show_scoring_page(success)
	
	# Show results/waiting overlay
	_show_results_screen(success)
	
	game_completed.emit(success)
	
	# Report completion — route to whichever manager owns the connection.
	var _nm_active: bool = NetworkManager != null and NetworkManager.is_multiplayer_connected()
	if _nm_active:
		# NetworkManager path: it orchestrates the next round via its own RPC system.
		var reaction_time_ms: int = Time.get_ticks_msec() - game_started_time
		var accuracy: float
		if total_actions > 0:
			accuracy = clamp(float(correct_actions) / float(total_actions), 0.0, 1.0)
		elif win_quota > 0:
			accuracy = clamp(float(local_score) / float(win_quota), 0.0, 1.0)
		else:
			accuracy = 1.0 if success else 0.0
		NetworkManager.report_player_completion(
			success, local_score, accuracy, reaction_time_ms
		)
	elif GameManager and GameManager.is_multiplayer_connected:
		# GameManager path: host will collect both reports and load next game.
		GameManager.rpc("complete_mp_round", success, local_score)

func record_mp_action(correct: bool) -> void:
	## Record a player action for CoopAdaptation accuracy tracking.
	## Call this from child games when the player makes a correct or incorrect move.
	total_actions += 1
	if correct:
		correct_actions += 1
	else:
		mistakes_made += 1

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
	# Pause both players — broadcast via whichever manager owns the session.
	if NetworkManager and NetworkManager.is_multiplayer_connected():
		NetworkManager.request_pause()
	elif multiplayer.multiplayer_peer != null:
		# GameManager path — broadcast pause RPC directly so the partner pauses too.
		GameManager.rpc("_mp_sync_pause", true)
	else:
		# Offline/solo fallback
		get_tree().paused = true
		if pause_menu:
			pause_menu.visible = true

func _on_resume_pressed() -> void:
	# Resume both players.
	if NetworkManager and NetworkManager.is_multiplayer_connected():
		NetworkManager.request_resume()
	elif multiplayer.multiplayer_peer != null:
		GameManager.rpc("_mp_sync_pause", false)
	else:
		get_tree().paused = false
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
	if _disconnect_handled:
		return
	_disconnect_handled = true
	_log(" Player left session - terminating for all players")
	
	# Record network event to SessionLogger
	if SessionLogger and SessionLogger.has_method("record_mp_network_event"):
		SessionLogger.record_mp_network_event("peer_disconnected", {"peer_id": _peer_id})
	
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
	if _disconnect_handled:
		return
	_disconnect_handled = true
	_log(" Server disconnected - terminating session")
	
	# Record network event to SessionLogger
	if SessionLogger and SessionLogger.has_method("record_mp_network_event"):
		SessionLogger.record_mp_network_event("server_disconnected", {})
	
	# Don't call _on_player_left_session to avoid duplicate UI
	if NetworkManager:
		NetworkManager.disconnect_multiplayer()
	
	var tree = get_tree()
	if tree and is_inside_tree():
		tree.change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

# 
# MAIN LOOP
# 
# NOTE: Timer display and end-game trigger are handled by _update_timer_display()
# via the ui_timer (started in start_game()). Do NOT duplicate that logic here
# — it causes a double end_game() race condition crash.

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
	# Send resource to partner player — uses whichever manager owns the connection.
	var _nm_active: bool = NetworkManager != null and NetworkManager.is_multiplayer_connected()
	if _nm_active:
		NetworkManager.send_resource(resource_type, amount, quality)
	elif GameManager and GameManager.is_multiplayer_connected:
		GameManager.rpc("send_resource_rpc", resource_type, amount, quality)

func mark_task_for_partner(task_id: int, task_position: Vector2) -> void:
	# Mark a task for partner to complete
	if NetworkManager:
		NetworkManager.mark_task(task_id, task_position)

func report_miss_to_host() -> void:
	## Call this when the local player misses enough items to cost a life.
	## Routes to whichever manager owns the connection.
	var _nm_active: bool = NetworkManager != null and NetworkManager.is_multiplayer_connected()
	if _nm_active:
		NetworkManager.lose_life()
	elif GameManager and GameManager.is_multiplayer_connected:
		GameManager.rpc("lose_life_rpc")

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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VISUAL FEEDBACK & ANIMATIONS (Matching Single-Player Style)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func play_success_effect() -> void:
	## Flash screen green for correct action
	_flash_screen(Color(0.3, 1.0, 0.3, 0.3))
	
	# Play success sound
	if AudioManager:
		AudioManager.play_collect()

func play_mistake_effect() -> void:
	## Flash screen red for mistake
	_flash_screen(Color(1.0, 0.3, 0.3, 0.3))
	
	# Play damage sound
	if AudioManager:
		AudioManager.play_damage()
	
	# Screen shake (if enabled)
	_shake_camera(0.5)

func play_score_popup(amount: int, popup_position: Vector2) -> void:
	## Show animated score popup at position
	var popup = Label.new()
	popup.text = "+%d" % amount
	popup.add_theme_font_size_override("font_size", 32)
	popup.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	popup.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	popup.add_theme_constant_override("outline_size", 4)
	popup.position = popup_position
	popup.z_index = 100
	add_child(popup)
	
	# Animate: float up and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup_position.y - 80, 0.8)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(popup, "modulate:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_IN)
	tween.tween_property(popup, "scale", Vector2(1.5, 1.5), 0.3)\
		.set_ease(Tween.EASE_OUT)
	tween.finished.connect(popup.queue_free)

func animate_score_label() -> void:
	## Bounce animation for score label when score increases
	var score_lbl = hud_layer.get_node_or_null(
			"MarginContainer/VBoxContainer/HBoxContainer"
			+ "/PanelContainer3/MarginContainer/HBoxContainer/ScoreLabel")
	if not score_lbl:
		return
	
	var original_scale = score_lbl.scale
	var tween = create_tween()
	tween.tween_property(score_lbl, "scale", Vector2(1.3, 1.3), 0.1)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(score_lbl, "scale", original_scale, 0.15)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)

func animate_life_lost() -> void:
	## Shake and pulse animation for lives label when life is lost
	var lives_lbl = hud_layer.get_node_or_null(
			"MarginContainer/VBoxContainer/HBoxContainer"
			+ "/PanelContainer2/MarginContainer/HBoxContainer/LivesLabel")
	if not lives_lbl:
		return
	
	# Pulse red
	var tween = create_tween()
	tween.tween_property(lives_lbl, "modulate", Color(2.0, 0.3, 0.3), 0.1)
	tween.tween_property(lives_lbl, "modulate", Color.WHITE, 0.3)
	
	# Scale pulse
	var original_scale = lives_lbl.scale
	tween.parallel().tween_property(lives_lbl, "scale", Vector2(1.4, 1.4), 0.1)
	tween.tween_property(lives_lbl, "scale", original_scale, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func animate_timer_warning() -> void:
	## Flash timer red when time is running low
	var timer_lbl = hud_layer.get_node_or_null(
			"MarginContainer/VBoxContainer/HBoxContainer"
			+ "/PanelContainer/MarginContainer/HBoxContainer/TimerLabel")
	if not timer_lbl:
		return
	
	var tween = create_tween()
	tween.tween_property(timer_lbl, "modulate", Color(2.0, 0.3, 0.3), 0.2)
	tween.tween_property(timer_lbl, "modulate", Color.WHITE, 0.2)

func _flash_screen(color: Color) -> void:
	## Create a full-screen flash effect
	var flash = ColorRect.new()
	flash.color = color
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 90
	
	# Add to HUD layer if available, otherwise add to scene
	if hud_layer:
		hud_layer.add_child(flash)
	else:
		add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.finished.connect(flash.queue_free)

func _shake_camera(intensity: float) -> void:
	## Shake the camera for impact feedback
	# Check if screen shake is enabled
	if AccessibilityManager and AccessibilityManager.has_method("is_screen_shake_enabled"):
		if not AccessibilityManager.is_screen_shake_enabled():
			return
	elif SaveManager and SaveManager.has_method("is_screen_shake_enabled"):
		if not SaveManager.is_screen_shake_enabled():
			return
	
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var original_offset = camera.offset
	var tween = create_tween()
	
	for i in range(5):
		tween.tween_property(camera, "offset", original_offset + Vector2(
			randf_range(-intensity * 10, intensity * 10),
			randf_range(-intensity * 10, intensity * 10)
		), 0.05)
	
	tween.tween_property(camera, "offset", original_offset, 0.05)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOGGING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
	# ── Styled game over screen (matching SP quality) ──
	var overlay = Control.new()
	overlay.name = "GameOverOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(overlay)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.02, 0.02, 0.92)
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	# Card panel
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.08, 0.08, 0.95)
	card_style.corner_radius_top_left = 32
	card_style.corner_radius_top_right = 32
	card_style.corner_radius_bottom_left = 32
	card_style.corner_radius_bottom_right = 32
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_color = Color(0.9, 0.3, 0.3, 0.4)
	card_style.shadow_size = 16
	card_style.shadow_color = Color(0, 0, 0, 0.4)
	card_style.content_margin_left = 64
	card_style.content_margin_right = 64
	card_style.content_margin_top = 48
	card_style.content_margin_bottom = 48
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Icon
	var icon = Label.new()
	icon.text = "💔"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 64)
	vbox.add_child(icon)

	var title = Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	title.add_theme_color_override("font_outline_color", Color(0.3, 0.05, 0.05, 0.8))
	title.add_theme_constant_override("outline_size", 5)
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "The team ran out of lives!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.8, 0.65, 0.65))
	vbox.add_child(sub)

	# Score
	var _go_score: int = 0
	var _go_rounds: int = 0
	var _nm_ok_go: bool = NetworkManager != null and NetworkManager.is_multiplayer_connected()
	if _nm_ok_go:
		_go_score = (
			NetworkManager.get_total_score()
			if NetworkManager.has_method("get_total_score")
			else 0
		)
		_go_rounds = NetworkManager.rounds_survived if "rounds_survived" in NetworkManager else 0
	elif GameManager:
		_go_score = (
			GameManager.get_global_score()
			if GameManager.has_method("get_global_score")
			else local_score
		)
		_go_rounds = 0
	var score_label = Label.new()
	score_label.text = "Final Score: %d\nRounds Survived: %d" % [_go_score, _go_rounds]
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vbox.add_child(score_label)

	# Return button
	var btn = Button.new()
	btn.text = "Return to Lobby"
	btn.custom_minimum_size = Vector2(240, 60)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.5, 0.7, 0.9)
	btn_style.corner_radius_top_left = 30
	btn_style.corner_radius_top_right = 30
	btn_style.corner_radius_bottom_left = 30
	btn_style.corner_radius_bottom_right = 30
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(func():
		if NetworkManager and NetworkManager.has_method("return_to_lobby"):
			NetworkManager.return_to_lobby()
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
	)
	var btn_container = CenterContainer.new()
	btn_container.add_child(btn)
	vbox.add_child(btn_container)


func _show_results_screen(success: bool) -> void:
	# Remove any existing results overlay to prevent duplicates
	var existing = hud_layer.get_node_or_null("ResultsOverlay")
	if existing:
		existing.queue_free()

	# ── Styled results screen ──
	var overlay = Control.new()
	overlay.name = "ResultsOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(overlay)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.1, 0.88)
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	# Card
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.96, 0.93, 0.87, 0.95) if success \
		else Color(0.14, 0.1, 0.1, 0.95)
	card_style.corner_radius_top_left = 32
	card_style.corner_radius_top_right = 32
	card_style.corner_radius_bottom_left = 32
	card_style.corner_radius_bottom_right = 32
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_color = Color(0.4, 0.85, 0.5, 0.5) if success \
		else Color(0.85, 0.3, 0.3, 0.4)
	card_style.shadow_size = 12
	card_style.shadow_color = Color(0, 0, 0, 0.3)
	card_style.content_margin_left = 56
	card_style.content_margin_right = 56
	card_style.content_margin_top = 40
	card_style.content_margin_bottom = 40
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Icon
	var icon = Label.new()
	icon.text = "🎉" if success else "💧"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 56)
	vbox.add_child(icon)

	# Title
	var title = Label.new()
	title.text = "LEVEL COMPLETE!" if success else "TIME'S UP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override(
		"font_color",
		Color(0.2, 0.55, 0.25) if success else Color(0.9, 0.35, 0.35)
	)
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override(
		"font_outline_color",
		Color(1, 1, 1, 0.3) if success else Color(0.2, 0.05, 0.05, 0.6)
	)
	vbox.add_child(title)

	# Subtitle
	var sub = Label.new()
	var _nm_active_rs: bool = NetworkManager != null and NetworkManager.is_multiplayer_connected()
	sub.text = "Waiting for partner..." if _nm_active_rs else "Next game loading in 3..."
	sub.name = "SubLabel"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override(
		"font_color",
		Color(0.4, 0.38, 0.3) if success else Color(0.7, 0.6, 0.6)
	)
	vbox.add_child(sub)

	# Score
	var score_label = Label.new()
	score_label.text = "⭐ Score: %d" % local_score
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_color_override(
		"font_color",
		Color(0.5, 0.42, 0.2) if success else Color(1.0, 0.85, 0.35)
	)
	vbox.add_child(score_label)

	is_waiting_for_partner = true

	# Connect to NetworkManager signal for round transition
	if (
		NetworkManager
		and not NetworkManager.both_players_completed.is_connected(_on_both_players_completed)
	):
		NetworkManager.both_players_completed.connect(_on_both_players_completed)

	# GameManager path: run a visible countdown label so players know a new game is coming.
	if not _nm_active_rs and is_instance_valid(vbox):
		_run_results_countdown(vbox)


func _run_results_countdown(container: VBoxContainer) -> void:
	## Shows "Next game in X..." countdown inside the results overlay.
	## Used only when GameManager owns the connection.
	var cd_label := Label.new()
	cd_label.name = "CDLabel"
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.add_theme_font_size_override("font_size", 28)
	cd_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	if is_instance_valid(container):
		container.add_child(cd_label)
	for i in range(3, 0, -1):
		if not is_instance_valid(cd_label):
			return
		cd_label.text = "Next game in %d..." % i
		await get_tree().create_timer(1.0).timeout
	if is_instance_valid(cd_label):
		cd_label.text = "Loading..."

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
	# ── Styled round summary ──
	var overlay = hud_layer.get_node_or_null("ResultsOverlay")
	if not overlay:
		return

	for child in overlay.get_children():
		child.queue_free()

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.1, 0.9)
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	# Card
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.96, 0.93, 0.87, 0.95)
	card_style.corner_radius_top_left = 32
	card_style.corner_radius_top_right = 32
	card_style.corner_radius_bottom_left = 32
	card_style.corner_radius_bottom_right = 32
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_color = Color(0.4, 0.72, 0.9, 0.45)
	card_style.shadow_size = 12
	card_style.shadow_color = Color(0, 0, 0, 0.25)
	card_style.content_margin_left = 56
	card_style.content_margin_right = 56
	card_style.content_margin_top = 36
	card_style.content_margin_bottom = 36
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var title = Label.new()
	title.text = "ROUND COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.2, 0.4, 0.55))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	vbox.add_child(title)

	# Player 1
	var p1_label = Label.new()
	p1_label.text = "P1: %s — %d pts" % [
		"✅ WIN" if p1_success else "❌ FAIL", p1_score
	]
	p1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1_label.add_theme_font_size_override("font_size", 24)
	p1_label.add_theme_color_override(
		"font_color",
		Color(0.15, 0.5, 0.2) if p1_success else Color(0.7, 0.2, 0.2)
	)
	vbox.add_child(p1_label)

	# Player 2
	var p2_label = Label.new()
	p2_label.text = "P2: %s — %d pts" % [
		"✅ WIN" if p2_success else "❌ FAIL", p2_score
	]
	p2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2_label.add_theme_font_size_override("font_size", 24)
	p2_label.add_theme_color_override(
		"font_color",
		Color(0.15, 0.5, 0.2) if p2_success else Color(0.7, 0.2, 0.2)
	)
	vbox.add_child(p2_label)

	# Team totals
	var _nm_ok_rs2: bool = NetworkManager != null and NetworkManager.is_multiplayer_connected()
	var _rs_lives: int = (
		NetworkManager.team_lives
		if _nm_ok_rs2
		else (GameManager.team_lives if GameManager else 0)
	)
	var _rs_rounds: int = (
		NetworkManager.rounds_survived
		if (_nm_ok_rs2 and "rounds_survived" in NetworkManager)
		else 0
	)
	var total_label = Label.new()
	total_label.text = "⭐ Team: %d   ❤ x%d   Rounds: %d" % [
		p1_score + p2_score, _rs_lives, _rs_rounds
	]
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 22)
	total_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.25))
	vbox.add_child(total_label)

	# Life deduction notice
	if not p1_success or not p2_success:
		var life_notice = Label.new()
		life_notice.text = "💔 Life Lost!"
		life_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		life_notice.add_theme_font_size_override("font_size", 28)
		life_notice.add_theme_color_override("font_color", Color(0.85, 0.25, 0.25))
		vbox.add_child(life_notice)

	# Next round notice
	var next_label = Label.new()
	next_label.text = "Loading next round..."
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.add_theme_font_size_override("font_size", 18)
	next_label.add_theme_color_override("font_color", Color(0.5, 0.48, 0.4))
	vbox.add_child(next_label)
