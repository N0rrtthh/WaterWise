extends Control

const SETTINGS_VBOX_PATH := (
	"CenterContainer/PanelCard/MarginContainer/ScrollContainer/VBoxContainer"
)
const GRID_PATH := SETTINGS_VBOX_PATH + "/GridContainer"

@onready var language_label = get_node(GRID_PATH + "/LanguageLabel")
@onready var language_button = get_node(GRID_PATH + "/LanguageButton")
@onready var volume_label = get_node(GRID_PATH + "/VolumeLabel")
@onready var fullscreen_check = get_node(GRID_PATH + "/FullscreenCheck")
@onready var theme_button = get_node(GRID_PATH + "/ThemeButton")
@onready var back_button = get_node(SETTINGS_VBOX_PATH + "/BackButton")
@onready var exit_button = get_node(SETTINGS_VBOX_PATH + "/ExitButton")
@onready var title_label = get_node(SETTINGS_VBOX_PATH + "/Title")
@onready var panel_card = $CenterContainer/PanelCard
@onready var background_rect = $Background
@onready var fullscreen_label = get_node(GRID_PATH + "/FullscreenLabel")
@onready var settings_scroll = $CenterContainer/PanelCard/MarginContainer/ScrollContainer

const ProceduralBackground = preload("res://scripts/ProceduralBackground.gd")

# Accessibility controls (dynamically added)
var accessibility_section: VBoxContainer
var colorblind_check: CheckBox
var large_targets_check: CheckBox
var audio_cues_check: CheckBox
var haptics_check: CheckBox
var screen_shake_check: CheckBox
var particles_check: CheckBox

# Dev-mode controls (for thesis monitoring)
var dev_mode_check: CheckBox
var dev_profiler_check: CheckBox
var dev_algorithm_check: CheckBox

func _ready() -> void:
	# Add procedural background
	var background = ProceduralBackground.new()
	add_child(background)
	move_child(background, 0)
	
	# Hide the old boring background
	if background_rect:
		background_rect.visible = false

	_configure_scroll_bounds()
	if not resized.is_connected(_on_viewport_resized):
		resized.connect(_on_viewport_resized)

	await get_tree().process_frame
	_setup_accessibility_section()
	_setup_dev_mode_section()
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

	_sync_dev_overlay_state()
	_reparent_action_buttons()

	# Entrance popup animation for the whole center column
	var center_cont = get_node_or_null("CenterContainer")
	if center_cont:
		center_cont.pivot_offset = center_cont.size * 0.5
		center_cont.modulate.a = 0.0
		center_cont.scale = Vector2(0.85, 0.85)
		var entrance_tw = create_tween()
		entrance_tw.tween_property(
			center_cont, "modulate:a", 1.0, 0.25
		)
		entrance_tw.parallel().tween_property(
			center_cont, "scale", Vector2(1.0, 1.0), 0.3
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reparent_action_buttons() -> void:
	# Move Back/Exit buttons outside the scroll area
	# so they stay fixed below the settings card.
	var settings_vbox = get_node_or_null(SETTINGS_VBOX_PATH)
	if not settings_vbox or not back_button or not exit_button:
		return

	# Remove HSeparator2 above buttons
	var sep2 = settings_vbox.get_node_or_null("HSeparator2")
	if sep2:
		sep2.queue_free()

	# Reparent buttons to a new row under PanelCard
	var center_cont = get_node_or_null("CenterContainer")
	if not center_cont:
		return

	# Wrap PanelCard + button row in a VBox
	var outer_vbox = VBoxContainer.new()
	outer_vbox.name = "OuterVBox"
	outer_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	outer_vbox.add_theme_constant_override("separation", 16)
	outer_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Move PanelCard into the outer VBox
	var panel = panel_card
	panel.get_parent().remove_child(panel)
	outer_vbox.add_child(panel)

	# Create horizontal button row
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	outer_vbox.add_child(btn_row)

	# Move buttons out of scroll and into the row
	back_button.get_parent().remove_child(back_button)
	exit_button.get_parent().remove_child(exit_button)
	btn_row.add_child(back_button)
	btn_row.add_child(exit_button)

	center_cont.add_child(outer_vbox)


func _on_viewport_resized() -> void:
	_configure_scroll_bounds()


func _configure_scroll_bounds() -> void:
	if not settings_scroll:
		return

	var viewport_size = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return

	var target_width = clamp(viewport_size.x - 120.0, 340.0, 980.0)
	var target_height = clamp(viewport_size.y - 120.0, 320.0, 760.0)
	settings_scroll.custom_minimum_size = Vector2(target_width, target_height)
	settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _get_settings_vbox() -> VBoxContainer:
	var direct_vbox = get_node_or_null(SETTINGS_VBOX_PATH)
	if direct_vbox and direct_vbox is VBoxContainer:
		return direct_vbox as VBoxContainer

	# Legacy fallback for older scene snapshots.
	var legacy_vbox = get_node_or_null(
		"CenterContainer/PanelCard/MarginContainer/VBoxContainer"
	)
	if legacy_vbox and legacy_vbox is VBoxContainer:
		return legacy_vbox as VBoxContainer

	return null

func _setup_accessibility_section() -> void:
	# Add accessibility options to settings
	var vbox = _get_settings_vbox()
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

	# Haptics
	var hp_label = Label.new()
	hp_label.text = "📳 Haptic Feedback"
	hp_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(hp_label)

	haptics_check = CheckBox.new()
	haptics_check.text = "Enable"
	haptics_check.button_pressed = _get_accessibility_setting("haptics_enabled", true)
	haptics_check.toggled.connect(_on_haptics_toggled)
	acc_grid.add_child(haptics_check)
	
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

func _setup_dev_mode_section() -> void:
	var vbox = _get_settings_vbox()
	if not vbox:
		return

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 15)
	vbox.add_child(sep)

	var header = Label.new()
	header.text = "🛠 Dev Mode / Thesis Monitoring"
	header.add_theme_font_size_override("font_size", 24)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var dev_grid = GridContainer.new()
	dev_grid.columns = 2
	dev_grid.add_theme_constant_override("h_separation", 20)
	dev_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(dev_grid)

	var dev_mode_enabled = bool(_get_dev_setting("dev_mode", false))

	var dm_label = Label.new()
	dm_label.text = "Enable Dev Mode"
	dm_label.add_theme_font_size_override("font_size", 18)
	dev_grid.add_child(dm_label)

	dev_mode_check = CheckBox.new()
	dev_mode_check.text = "Enable"
	dev_mode_check.button_pressed = dev_mode_enabled
	dev_mode_check.toggled.connect(_on_dev_mode_toggled)
	dev_grid.add_child(dev_mode_check)

	var profiler_label = Label.new()
	profiler_label.text = "Show ISO Profiler (F11)"
	profiler_label.add_theme_font_size_override("font_size", 18)
	dev_grid.add_child(profiler_label)

	dev_profiler_check = CheckBox.new()
	dev_profiler_check.text = "Show"
	dev_profiler_check.button_pressed = bool(
		_get_dev_setting("dev_show_profiler", false)
	)
	dev_profiler_check.toggled.connect(_on_dev_profiler_toggled)
	dev_grid.add_child(dev_profiler_check)

	var algo_label = Label.new()
	algo_label.text = "Show Algorithm Overlay (F12)"
	algo_label.add_theme_font_size_override("font_size", 18)
	dev_grid.add_child(algo_label)

	dev_algorithm_check = CheckBox.new()
	dev_algorithm_check.text = "Show"
	dev_algorithm_check.button_pressed = bool(
		_get_dev_setting("dev_show_algorithm_overlay", false)
	)
	dev_algorithm_check.toggled.connect(_on_dev_algorithm_toggled)
	dev_grid.add_child(dev_algorithm_check)

	var note = Label.new()
	note.text = "Use toggles on mobile (same as F11/F12 on PC)."
	note.add_theme_font_size_override("font_size", 14)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(note)

	_apply_dev_mode_visibility(dev_mode_enabled)

func _get_accessibility_setting(key: String, default_val: bool = false) -> bool:
	var acc_mgr = get_node_or_null("/root/AccessibilityManager")
	if acc_mgr:
		return acc_mgr.settings.get(key, default_val) if acc_mgr.get("settings") else default_val
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		return save_mgr.get_setting(key, default_val)
	return default_val

func _on_colorblind_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()
	var acc_mgr = get_node_or_null("/root/AccessibilityManager")
	if acc_mgr:
		acc_mgr.set_colorblind_mode(pressed)
	else:
		var save_mgr = get_node_or_null("/root/SaveManager")
		if save_mgr:
			save_mgr.set_setting("colorblind_mode", pressed)

func _on_large_targets_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()
	var acc_mgr = get_node_or_null("/root/AccessibilityManager")
	if acc_mgr:
		acc_mgr.set_large_touch_targets(pressed)
	else:
		var save_mgr = get_node_or_null("/root/SaveManager")
		if save_mgr:
			save_mgr.set_setting("large_touch_targets", pressed)

func _on_audio_cues_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()
	var acc_mgr = get_node_or_null("/root/AccessibilityManager")
	if acc_mgr:
		acc_mgr.set_audio_cues_enabled(pressed)
	else:
		var save_mgr = get_node_or_null("/root/SaveManager")
		if save_mgr:
			save_mgr.set_setting("audio_cues", pressed)

func _on_haptics_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.set_setting("haptics_enabled", pressed)

func _on_screen_shake_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.set_setting("screen_shake", pressed)

func _on_particles_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.set_setting("particles", pressed)

func _get_dev_setting(key: String, default_val: bool = false) -> bool:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		return bool(save_mgr.get_setting(key, default_val))
	return default_val

func _set_dev_setting(key: String, value: bool) -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.set_setting(key, value)

func _apply_dev_mode_visibility(enabled: bool) -> void:
	if dev_profiler_check:
		dev_profiler_check.disabled = not enabled
	if dev_algorithm_check:
		dev_algorithm_check.disabled = not enabled

func _sync_dev_overlay_state() -> void:
	var dev_mode_enabled = _get_dev_setting("dev_mode", false)
	var show_profiler = dev_mode_enabled and _get_dev_setting("dev_show_profiler", false)
	var show_overlay = dev_mode_enabled and _get_dev_setting("dev_show_algorithm_overlay", false)

	if PerformanceProfiler and PerformanceProfiler.has_method("set_overlay_visible"):
		PerformanceProfiler.set_overlay_visible(show_profiler)

	if AlgorithmOverlay and AlgorithmOverlay.has_method("set_overlay_visible"):
		AlgorithmOverlay.set_overlay_visible(show_overlay)

func _on_dev_mode_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()

	_set_dev_setting("dev_mode", pressed)
	_apply_dev_mode_visibility(pressed)

	if not pressed:
		_set_dev_setting("dev_show_profiler", false)
		_set_dev_setting("dev_show_algorithm_overlay", false)
		if dev_profiler_check:
			dev_profiler_check.set_pressed_no_signal(false)
		if dev_algorithm_check:
			dev_algorithm_check.set_pressed_no_signal(false)

	_sync_dev_overlay_state()

func _on_dev_profiler_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()

	if not _get_dev_setting("dev_mode", false):
		if dev_profiler_check:
			dev_profiler_check.set_pressed_no_signal(false)
		return

	_set_dev_setting("dev_show_profiler", pressed)
	_sync_dev_overlay_state()

func _on_dev_algorithm_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()

	if not _get_dev_setting("dev_mode", false):
		if dev_algorithm_check:
			dev_algorithm_check.set_pressed_no_signal(false)
		return

	_set_dev_setting("dev_show_algorithm_overlay", pressed)
	_sync_dev_overlay_state()

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
	if AudioManager:
		AudioManager.play_click()
	if Localization:
		Localization.toggle_language()

func _on_theme_button_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
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
	if AudioManager:
		AudioManager.play_click()
	if GameManager and GameManager.has_method("transition_to_scene"):
		GameManager.transition_to_scene("res://scenes/ui/InitialScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

func _on_exit_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if GameManager and GameManager.has_method("transition_to_scene"):
		GameManager.transition_to_scene("res://scenes/ui/MainMenu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
