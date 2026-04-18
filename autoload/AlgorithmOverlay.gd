extends CanvasLayer

## ═══════════════════════════════════════════════════════════════════
## ALGORITHM OVERLAY - REAL-TIME VISUALIZATION HUD
## ═══════════════════════════════════════════════════════════════════
## Shows the algorithm working in real-time during gameplay
## Perfect for thesis demonstration to panelists
## Toggle with F12 key or settings
## ═══════════════════════════════════════════════════════════════════

# Configuration
@export var show_by_default: bool = false
@export var overlay_opacity: float = 0.85
@export var compact_mode: bool = true

# State
var is_visible_overlay: bool = false
var update_timer: Timer

# UI Elements
var overlay_panel: PanelContainer
var phi_display: Label
var difficulty_display: Label
var window_display: Label
var rule_display: Label
var games_display: Label

func _ready() -> void:
	layer = 100  # On top of everything
	_build_overlay()
	is_visible_overlay = show_by_default
	overlay_panel.visible = is_visible_overlay
	
	# Connect to AdaptiveDifficulty signals
	if AdaptiveDifficulty:
		AdaptiveDifficulty.algorithm_update.connect(_on_algorithm_update)
		AdaptiveDifficulty.difficulty_changed.connect(_on_difficulty_changed)
	
	# Create update timer
	update_timer = Timer.new()
	update_timer.wait_time = 0.5
	update_timer.timeout.connect(_update_overlay)
	add_child(update_timer)
	update_timer.start()
	_apply_saved_dev_visibility()

func _input(event: InputEvent) -> void:
	# Toggle overlay with F12
	var is_f12 = (event is InputEventKey
		and event.keycode == KEY_F12 and event.pressed)
	if event.is_action_pressed("ui_end") or is_f12:
		toggle_overlay()

func _build_overlay() -> void:
	overlay_panel = PanelContainer.new()
	overlay_panel.modulate.a = overlay_opacity
	add_child(overlay_panel)
	
	# Position in top-right corner
	overlay_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	overlay_panel.offset_left = -320
	overlay_panel.offset_right = -10
	overlay_panel.offset_top = 10
	overlay_panel.offset_bottom = 200
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_color = Color(0.3, 0.6, 1.0, 0.8)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.content_margin_left = 15
	style.content_margin_right = 15
	overlay_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	overlay_panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🔬 ALGORITHM MONITOR"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Difficulty Display
	var diff_hbox = HBoxContainer.new()
	vbox.add_child(diff_hbox)
	
	var diff_label = Label.new()
	diff_label.text = "Difficulty: "
	diff_label.add_theme_font_size_override("font_size", 16)
	diff_hbox.add_child(diff_label)
	
	difficulty_display = Label.new()
	difficulty_display.text = "MEDIUM"
	difficulty_display.add_theme_font_size_override("font_size", 18)
	difficulty_display.modulate = Color(0.9, 0.7, 0.1)
	diff_hbox.add_child(difficulty_display)
	
	# Phi Display
	var phi_hbox = HBoxContainer.new()
	vbox.add_child(phi_hbox)
	
	var phi_label = Label.new()
	phi_label.text = "Φ (Proficiency): "
	phi_label.add_theme_font_size_override("font_size", 14)
	phi_hbox.add_child(phi_label)
	
	phi_display = Label.new()
	phi_display.text = "0.000"
	phi_display.add_theme_font_size_override("font_size", 16)
	phi_hbox.add_child(phi_display)
	
	# Window Display
	window_display = Label.new()
	window_display.text = "Window: [0/5 games]"
	window_display.add_theme_font_size_override("font_size", 12)
	window_display.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(window_display)
	
	# Active Rule Display
	rule_display = Label.new()
	rule_display.text = "Rule: Collecting data..."
	rule_display.add_theme_font_size_override("font_size", 12)
	rule_display.modulate = Color(0.5, 0.8, 1.0)
	vbox.add_child(rule_display)
	
	# Games Counter
	games_display = Label.new()
	games_display.text = "Total: 0 games played"
	games_display.add_theme_font_size_override("font_size", 11)
	games_display.modulate = Color(0.6, 0.6, 0.6)
	vbox.add_child(games_display)
	
	vbox.add_child(HSeparator.new())
	
	# Hint
	var hint = Label.new()
	hint.text = "[F12 or Dev Mode settings]"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.5, 0.5, 0.5)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

func set_overlay_visible(is_enabled: bool) -> void:
	is_visible_overlay = is_enabled
	overlay_panel.visible = is_visible_overlay

func is_overlay_visible() -> bool:
	return is_visible_overlay

func toggle_overlay() -> void:
	set_overlay_visible(not is_visible_overlay)
	print("🔬 Algorithm Overlay: %s" % ("ON" if is_visible_overlay else "OFF"))

func show_overlay() -> void:
	set_overlay_visible(true)

func hide_overlay() -> void:
	set_overlay_visible(false)

func _apply_saved_dev_visibility() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		return

	var dev_mode_enabled = bool(save_mgr.get_setting("dev_mode", false))
	var should_show_overlay = bool(save_mgr.get_setting("dev_show_algorithm_overlay", false))
	set_overlay_visible(dev_mode_enabled and should_show_overlay)

func _update_overlay() -> void:
	if not is_visible_overlay or not AdaptiveDifficulty:
		return
	
	var status = AdaptiveDifficulty.get_algorithm_status()
	
	# Update difficulty
	var diff = status["current_difficulty"]
	difficulty_display.text = diff.to_upper()
	match diff:
		"Easy":
			difficulty_display.modulate = Color(0.2, 0.9, 0.2)
		"Medium":
			difficulty_display.modulate = Color(0.9, 0.7, 0.1)
		"Hard":
			difficulty_display.modulate = Color(0.9, 0.2, 0.2)
	
	# Update Phi
	var phi = status["proficiency_index"]
	phi_display.text = "%.3f" % phi
	
	# Color code phi
	if phi < 0.5:
		phi_display.modulate = Color(0.2, 0.9, 0.2)
	elif phi > 0.85:
		phi_display.modulate = Color(0.9, 0.2, 0.2)
	else:
		phi_display.modulate = Color(0.9, 0.7, 0.1)
	
	# Update window info
	var window_size = status["games_in_window"]
	window_display.text = "Window: [%d/5 games]" % window_size
	
	# Update active rule
	if not status["algorithm_active"]:
		var games_left = int(status.get("games_until_algorithm_activation", 0))
		rule_display.text = "⏳ Collecting data... (%d more games)" % games_left
	elif phi < 0.5:
		rule_display.text = "📋 Rule 1: Φ<0.5 → EASY"
	elif phi > 0.85:
		rule_display.text = "📋 Rule 2: Φ>0.85 → HARD"
	else:
		rule_display.text = "📋 Rule 3: 0.5≤Φ≤0.85 → MEDIUM"
	
	# Update games counter
	var session_games = int(status.get("session_games_played", status.get("total_games_played", 0)))
	var lifetime_games = int(status.get("lifetime_games_played", session_games))
	games_display.text = "Session: %d | Lifetime: %d" % [session_games, lifetime_games]

func _on_algorithm_update(_metrics: Dictionary) -> void:
	_update_overlay()

func _on_difficulty_changed(old: String, new: String, _reason: String) -> void:
	# Flash the overlay when difficulty changes
	if is_visible_overlay:
		var tween = create_tween()
		tween.tween_property(overlay_panel, "modulate:a", 1.0, 0.1)
		tween.tween_property(overlay_panel, "modulate:a", overlay_opacity, 0.3)
		
		print("🎮 Difficulty: %s → %s" % [old, new])
