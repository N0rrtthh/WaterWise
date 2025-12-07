extends Control

@onready var language_label = $CenterContainer/PanelCard/MarginContainer/VBoxContainer/GridContainer/LanguageLabel
@onready var language_button = $CenterContainer/PanelCard/MarginContainer/VBoxContainer/GridContainer/LanguageButton
@onready var volume_label = $CenterContainer/PanelCard/MarginContainer/VBoxContainer/GridContainer/VolumeLabel
@onready var fullscreen_check = $CenterContainer/PanelCard/MarginContainer/VBoxContainer/GridContainer/FullscreenCheck
@onready var theme_button = $CenterContainer/PanelCard/MarginContainer/VBoxContainer/GridContainer/ThemeButton
@onready var back_button = $CenterContainer/PanelCard/MarginContainer/VBoxContainer/BackButton
@onready var exit_button = $CenterContainer/PanelCard/MarginContainer/VBoxContainer/ExitButton
@onready var title_label = $CenterContainer/PanelCard/MarginContainer/VBoxContainer/Title
@onready var panel_card = $CenterContainer/PanelCard
@onready var background_rect = $Background
@onready var fullscreen_label = $CenterContainer/PanelCard/MarginContainer/VBoxContainer/GridContainer/FullscreenLabel

const ProceduralBackground = preload("res://scripts/ProceduralBackground.gd")

# Accessibility controls (dynamically added)
var accessibility_section: VBoxContainer
var colorblind_check: CheckBox
var large_targets_check: CheckBox
var audio_cues_check: CheckBox
var screen_shake_check: CheckBox
var particles_check: CheckBox

func _ready() -> void:
	# Add procedural background
	var background = ProceduralBackground.new()
	add_child(background)
	move_child(background, 0)
	
	# Hide the old boring background
	if background_rect:
		background_rect.visible = false

	await get_tree().process_frame
	_setup_accessibility_section()
	_update_translations()
	_update_language_button()
	_update_theme_button()
	_apply_theme()
	
	if Localization:
		Localization.language_changed.connect(_on_language_changed)
	
	# Connect to ThemeManager
	var theme_mgr = get_node_or_null("/root/ThemeManager")
	if theme_mgr:
		theme_mgr.theme_changed.connect(_on_theme_changed)

func _setup_accessibility_section() -> void:
	"""Add accessibility options to settings"""
	var vbox = $CenterContainer/PanelCard/MarginContainer/VBoxContainer
	if not vbox:
		return
	
	# Find GridContainer to insert after
	var grid = vbox.get_node_or_null("GridContainer")
	if not grid:
		return
	
	# Create separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 15)
	vbox.add_child(sep)
	vbox.move_child(sep, grid.get_index() + 1)
	
	# Create accessibility header
	var header = Label.new()
	header.text = "♿ Accessibility / Accessibility"
	header.add_theme_font_size_override("font_size", 24)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)
	vbox.move_child(header, sep.get_index() + 1)
	
	# Create grid for accessibility options
	var acc_grid = GridContainer.new()
	acc_grid.columns = 2
	acc_grid.add_theme_constant_override("h_separation", 20)
	acc_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(acc_grid)
	vbox.move_child(acc_grid, header.get_index() + 1)
	
	# Colorblind mode
	var cb_label = Label.new()
	cb_label.text = "🎨 Colorblind Mode"
	cb_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(cb_label)
	
	colorblind_check = CheckBox.new()
	colorblind_check.text = "Enable"
	colorblind_check.button_pressed = _get_accessibility_setting("colorblind_mode")
	colorblind_check.toggled.connect(_on_colorblind_toggled)
	acc_grid.add_child(colorblind_check)
	
	# Large touch targets
	var lt_label = Label.new()
	lt_label.text = "👆 Large Touch Targets"
	lt_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(lt_label)
	
	large_targets_check = CheckBox.new()
	large_targets_check.text = "Enable"
	large_targets_check.button_pressed = _get_accessibility_setting("large_touch_targets")
	large_targets_check.toggled.connect(_on_large_targets_toggled)
	acc_grid.add_child(large_targets_check)
	
	# Audio cues
	var ac_label = Label.new()
	ac_label.text = "🔊 Audio Cues"
	ac_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(ac_label)
	
	audio_cues_check = CheckBox.new()
	audio_cues_check.text = "Enable"
	audio_cues_check.button_pressed = _get_accessibility_setting("audio_cues", true)
	audio_cues_check.toggled.connect(_on_audio_cues_toggled)
	acc_grid.add_child(audio_cues_check)
	
	# Screen shake
	var ss_label = Label.new()
	ss_label.text = "📳 Screen Shake"
	ss_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(ss_label)
	
	screen_shake_check = CheckBox.new()
	screen_shake_check.text = "Enable"
	screen_shake_check.button_pressed = _get_accessibility_setting("screen_shake", true)
	screen_shake_check.toggled.connect(_on_screen_shake_toggled)
	acc_grid.add_child(screen_shake_check)
	
	# Particles
	var pt_label = Label.new()
	pt_label.text = "✨ Particles/Effects"
	pt_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(pt_label)
	
	particles_check = CheckBox.new()
	particles_check.text = "Enable"
	particles_check.button_pressed = _get_accessibility_setting("particles", true)
	particles_check.toggled.connect(_on_particles_toggled)
	acc_grid.add_child(particles_check)

func _get_accessibility_setting(key: String, default_val: bool = false) -> bool:
	var acc_mgr = get_node_or_null("/root/AccessibilityManager")
	if acc_mgr:
		return acc_mgr.settings.get(key, default_val) if acc_mgr.get("settings") else default_val
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		return save_mgr.get_setting(key, default_val)
	return default_val

func _on_colorblind_toggled(pressed: bool) -> void:
	var acc_mgr = get_node_or_null("/root/AccessibilityManager")
	if acc_mgr:
		acc_mgr.set_colorblind_mode(pressed)
	else:
		var save_mgr = get_node_or_null("/root/SaveManager")
		if save_mgr:
			save_mgr.set_setting("colorblind_mode", pressed)

func _on_large_targets_toggled(pressed: bool) -> void:
	var acc_mgr = get_node_or_null("/root/AccessibilityManager")
	if acc_mgr:
		acc_mgr.set_large_touch_targets(pressed)
	else:
		var save_mgr = get_node_or_null("/root/SaveManager")
		if save_mgr:
			save_mgr.set_setting("large_touch_targets", pressed)

func _on_audio_cues_toggled(pressed: bool) -> void:
	var acc_mgr = get_node_or_null("/root/AccessibilityManager")
	if acc_mgr:
		acc_mgr.set_audio_cues_enabled(pressed)
	else:
		var save_mgr = get_node_or_null("/root/SaveManager")
		if save_mgr:
			save_mgr.set_setting("audio_cues", pressed)

func _on_screen_shake_toggled(pressed: bool) -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.set_setting("screen_shake", pressed)

func _on_particles_toggled(pressed: bool) -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.set_setting("particles", pressed)

func _update_translations() -> void:
	if not Localization:
		return
	
	title_label.text = Localization.get_text("settings")
	language_label.text = Localization.get_text("language")
	volume_label.text = Localization.get_text("volume")
	fullscreen_check.text = Localization.get_text("fullscreen")
	back_button.text = Localization.get_text("back")
	if exit_button:
		exit_button.text = "EXIT"

func _update_language_button() -> void:
	if not Localization:
		return
	
	if Localization.is_filipino():
		language_button.text = "Filipino"
	else:
		language_button.text = "English"

func _update_theme_button() -> void:
	var is_dark: bool = GameManager.dark_mode_enabled if GameManager else false
	var theme_text: String = Localization.get_text("dark_mode") if Localization else "Dark"
	var light_text: String = Localization.get_text("light_mode") if Localization else "Light"
	theme_button.text = "Theme: " + (theme_text if is_dark else light_text)

func _on_theme_changed(_is_dark: bool) -> void:
	_update_theme_button()
	_apply_theme()

func _on_language_changed(_new_lang: String) -> void:
	_update_translations()
	_update_language_button()

func _on_language_button_pressed() -> void:
	if Localization:
		Localization.toggle_language()

func _on_theme_button_pressed() -> void:
	# Use ThemeManager to toggle
	var theme_mgr = get_node_or_null("/root/ThemeManager")
	if theme_mgr:
		theme_mgr.toggle_theme()
	else:
		# Fallback
		if GameManager:
			GameManager.dark_mode_enabled = not GameManager.dark_mode_enabled
		_update_theme_button()
		_apply_theme()

func _apply_theme() -> void:
	var is_dark: bool = GameManager.dark_mode_enabled if GameManager else false
	var panel_style = panel_card.get_theme_stylebox("panel").duplicate()
	
	if is_dark:
		# Dark Mode Colors
		panel_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
		title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		language_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		volume_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		if fullscreen_label:
			fullscreen_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			
	else:
		# Light Mode Colors
		panel_style.bg_color = Color(0.95, 0.92, 0.85, 1)
		title_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		language_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		volume_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		if fullscreen_label:
			fullscreen_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))

	panel_card.add_theme_stylebox_override("panel", panel_style)

func _on_back_pressed() -> void:
	# No need to modify welcome popup - it only shows on first_launch
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
