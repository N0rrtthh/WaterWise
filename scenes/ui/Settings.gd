extends Control

const SETTINGS_VBOX_PATH := (
	"CenterContainer/PanelCard/MarginContainer/ScrollContainer/VBoxContainer"
)
const SETTINGS_OUTER_VBOX_PATH := "CenterContainer/OuterVBox"
const ACTION_BAR_PATH := "ActionButtonsSafeArea"
const ACTION_BAR_BASE_BOTTOM_MARGIN := 20.0
const ACTION_BAR_BASE_SIDE_MARGIN := 24.0
const ACTION_BAR_RESERVED_HEIGHT := 130.0
const ACTION_BAR_MIN_GAP := 14.0
const ACTION_BAR_MIN_GAP_MOBILE := 32.0
const GRID_PATH := SETTINGS_VBOX_PATH + "/GridContainer"

@onready var language_label = get_node(GRID_PATH + "/LanguageLabel")
@onready var language_button = get_node(GRID_PATH + "/LanguageButton")
@onready var volume_label = get_node(GRID_PATH + "/VolumeLabel")
@onready var volume_slider = get_node_or_null(GRID_PATH + "/VolumeSlider") as HSlider
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

var _feedback_tweens: Dictionary = {}
var _panel_ambient_tween: Tween
var _localized_dynamic_texts: Array[Dictionary] = []

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
	_wire_runtime_setting_controls()
	_sync_runtime_setting_controls()
	_apply_theme()
	
	if Localization:
		Localization.language_changed.connect(_on_language_changed)
	
	# Connect to ThemeManager
	var theme_mgr = get_node_or_null("/root/ThemeManager")
	if theme_mgr:
		theme_mgr.theme_changed.connect(_on_theme_changed)

	_sync_dev_overlay_state()
	_reparent_action_buttons()
	_update_action_button_bar_layout()
	call_deferred("_setup_interaction_polish")
	_start_panel_ambient_motion()

	# Entrance animation: animate only content group, not full viewport container.
	var entrance_target = get_node_or_null(SETTINGS_OUTER_VBOX_PATH) as Control
	if not entrance_target:
		entrance_target = panel_card
	if entrance_target:
		entrance_target.pivot_offset = entrance_target.size * 0.5
		entrance_target.modulate.a = 0.0
		entrance_target.scale = Vector2(0.96, 0.96)
		var entrance_tw = create_tween()
		entrance_tw.tween_property(
			entrance_target, "modulate:a", 1.0, 0.2
		)
		entrance_tw.parallel().tween_property(
			entrance_target, "scale", Vector2(1.0, 1.0), 0.22
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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

	# Reparent buttons to a fixed safe-area row.
	var center_cont = get_node_or_null("CenterContainer")
	if not center_cont:
		return

	# Wrap PanelCard in a center VBox if needed.
	var outer_vbox = center_cont.get_node_or_null("OuterVBox") as VBoxContainer
	if not outer_vbox:
		outer_vbox = VBoxContainer.new()
		outer_vbox.name = "OuterVBox"
		outer_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		outer_vbox.add_theme_constant_override("separation", 16)
		outer_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		outer_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		center_cont.add_child(outer_vbox)

	# Move PanelCard into the outer VBox
	var panel = panel_card
	if panel.get_parent() != outer_vbox:
		panel.get_parent().remove_child(panel)
		outer_vbox.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	# Create or reuse bottom-safe action bar.
	var action_bar = get_node_or_null(ACTION_BAR_PATH) as MarginContainer
	if not action_bar:
		action_bar = MarginContainer.new()
		action_bar.name = "ActionButtonsSafeArea"
		action_bar.layout_mode = 1
		action_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_bar.z_index = 20
		add_child(action_bar)

	var btn_row = action_bar.get_node_or_null("ButtonRow") as HBoxContainer
	if not btn_row:
		btn_row = HBoxContainer.new()
		btn_row.name = "ButtonRow"
		btn_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_theme_constant_override("separation", 20)
		action_bar.add_child(btn_row)

	# Move buttons out of scroll and into the row
	if back_button.get_parent() != btn_row:
		back_button.get_parent().remove_child(back_button)
		btn_row.add_child(back_button)
	if exit_button.get_parent() != btn_row:
		exit_button.get_parent().remove_child(exit_button)
		btn_row.add_child(exit_button)

	move_child(action_bar, get_child_count() - 1)
	_update_action_button_bar_layout()


func _on_viewport_resized() -> void:
	_configure_scroll_bounds()
	_update_action_button_bar_layout()


func _configure_scroll_bounds() -> void:
	if not settings_scroll:
		return

	var viewport_size = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	var content_height = viewport_size.y
	var center_cont = get_node_or_null("CenterContainer") as Control
	if center_cont and center_cont.size.y > 0.0:
		content_height = center_cont.size.y

	var target_width = clamp(viewport_size.x - 120.0, 340.0, 980.0)
	var target_height = clamp(content_height - 90.0, 240.0, 760.0)
	settings_scroll.custom_minimum_size = Vector2(target_width, target_height)
	settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _get_safe_area_margins() -> Dictionary:
	if MobileUIManager and MobileUIManager.has_method("get_safe_area_margins"):
		var margins = MobileUIManager.get_safe_area_margins()
		if margins is Dictionary:
			return margins
	return {}


func _get_safe_bottom_margin() -> float:
	var margins = _get_safe_area_margins()
	return float(margins.get("bottom", 0.0))


func _get_action_bar_gap() -> float:
	if _is_mobile_platform():
		return ACTION_BAR_MIN_GAP_MOBILE
	return ACTION_BAR_MIN_GAP


func _update_action_button_bar_layout() -> void:
	var action_bar = get_node_or_null(ACTION_BAR_PATH) as MarginContainer
	if not action_bar:
		return

	var safe = _get_safe_area_margins()
	var left_margin = ACTION_BAR_BASE_SIDE_MARGIN + float(safe.get("left", 0.0))
	var right_margin = ACTION_BAR_BASE_SIDE_MARGIN + float(safe.get("right", 0.0))
	var bottom_margin = ACTION_BAR_BASE_BOTTOM_MARGIN + float(safe.get("bottom", 0.0))
	action_bar.add_theme_constant_override("margin_left", int(left_margin))
	action_bar.add_theme_constant_override("margin_right", int(right_margin))
	action_bar.add_theme_constant_override("margin_bottom", int(bottom_margin))

	var btn_row = action_bar.get_node_or_null("ButtonRow") as HBoxContainer
	if not btn_row:
		return

	var row_height = ACTION_BAR_RESERVED_HEIGHT
	if back_button:
		row_height = max(row_height, back_button.custom_minimum_size.y)
	if exit_button:
		row_height = max(row_height, exit_button.custom_minimum_size.y)
	btn_row.offset_top = -row_height
	btn_row.offset_bottom = 0.0

	# Keep panel content in a dedicated safe zone above the fixed action bar.
	var center_cont = get_node_or_null("CenterContainer") as Control
	if center_cont:
		center_cont.offset_left = left_margin
		center_cont.offset_right = -right_margin
		center_cont.offset_top = 16.0 + float(safe.get("top", 0.0))
		center_cont.offset_bottom = -(bottom_margin + row_height + _get_action_bar_gap())

	# Recompute scroll sizing against the updated safe zone.
	_configure_scroll_bounds()


func _loc(key: String, fallback: String) -> String:
	if Localization:
		var translated = Localization.get_text(key)
		if translated != key:
			return translated
	return fallback


func _register_localized_text_control(
	control: Control,
	key: String,
	fallback: String
) -> void:
	if not control:
		return

	_localized_dynamic_texts.append({
		"node": control,
		"key": key,
		"fallback": fallback,
	})
	_apply_localized_text_to_control(control, key, fallback)


func _apply_localized_text_to_control(
	control: Control,
	key: String,
	fallback: String
) -> void:
	var value = _loc(key, fallback)
	if control is Label:
		(control as Label).text = value
	elif control is BaseButton:
		(control as BaseButton).text = value


func _refresh_dynamic_localized_texts() -> void:
	var refreshed: Array[Dictionary] = []
	for entry in _localized_dynamic_texts:
		var node = entry.get("node")
		if node and is_instance_valid(node):
			_apply_localized_text_to_control(
				node,
				str(entry.get("key", "")),
				str(entry.get("fallback", ""))
			)
			refreshed.append(entry)
	_localized_dynamic_texts = refreshed


func _setup_interaction_polish() -> void:
	var controls: Array[Control] = [
		language_button,
		theme_button,
		back_button,
		exit_button,
		fullscreen_check,
		colorblind_check,
		large_targets_check,
		audio_cues_check,
		haptics_check,
		screen_shake_check,
		particles_check,
		dev_mode_check,
		dev_profiler_check,
		dev_algorithm_check,
		volume_slider,
	]

	for ctrl in controls:
		if ctrl:
			var hover_scale := 1.02
			if ctrl is Button:
				hover_scale = 1.035
			_attach_feedback(ctrl, hover_scale)


func _attach_feedback(control: Control, hover_scale: float) -> void:
	if not control:
		return
	if bool(control.get_meta("_polish_feedback_bound", false)):
		return

	control.pivot_offset = control.size * 0.5
	control.set_meta("_polish_feedback_bound", true)

	control.mouse_entered.connect(_on_control_hover_entered.bind(control, hover_scale))
	control.mouse_exited.connect(_on_control_hover_exited.bind(control))
	control.focus_entered.connect(_on_control_hover_entered.bind(control, hover_scale))
	control.focus_exited.connect(_on_control_hover_exited.bind(control))

	if control is BaseButton:
		var base_btn := control as BaseButton
		base_btn.button_down.connect(_on_control_pressed.bind(control))
		base_btn.button_up.connect(_on_control_released.bind(control, hover_scale))
	elif control is HSlider:
		var slider := control as HSlider
		slider.drag_started.connect(_on_control_pressed.bind(control))
		slider.drag_ended.connect(_on_slider_drag_ended.bind(control, hover_scale))


func _on_control_hover_entered(control: Control, hover_scale: float) -> void:
	_animate_control_scale(control, Vector2(hover_scale, hover_scale), 0.11)


func _on_control_hover_exited(control: Control) -> void:
	_animate_control_scale(control, Vector2.ONE, 0.11)


func _on_control_pressed(control: Control) -> void:
	_animate_control_scale(control, Vector2(0.97, 0.97), 0.06)


func _on_control_released(control: Control, hover_scale: float) -> void:
	if not control:
		return
	var target := Vector2.ONE
	if control.get_global_rect().has_point(get_global_mouse_position()):
		target = Vector2(hover_scale, hover_scale)
	_animate_control_scale(control, target, 0.10)


func _on_slider_drag_ended(_changed: bool, control: Control, hover_scale: float) -> void:
	_on_control_released(control, hover_scale)


func _animate_control_scale(control: Control, target_scale: Vector2, duration: float) -> void:
	if not control or not is_instance_valid(control):
		return

	var key = control.get_instance_id()
	if _feedback_tweens.has(key):
		var prev = _feedback_tweens[key] as Tween
		if prev and prev.is_valid():
			prev.kill()

	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(control, "scale", target_scale, duration)
	_feedback_tweens[key] = tw


func _start_panel_ambient_motion() -> void:
	if _panel_ambient_tween and _panel_ambient_tween.is_valid():
		_panel_ambient_tween.kill()
	# Keep action buttons unobstructed: avoid vertical panel bobbing in Settings.
	# The entrance animation still provides motion feedback.


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
	_register_localized_text_control(
		header,
		"settings_accessibility_header",
		"♿ Accessibility / Accessibility"
	)
	header.add_theme_font_size_override("font_size", 24)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)
	vbox.move_child(header, sep.get_index() + 1)
	
	# Create grid for accessibility options
	var acc_grid = GridContainer.new()
	acc_grid.columns = 2
	acc_grid.add_theme_constant_override("h_separation", 20)
	acc_grid.add_theme_constant_override("v_separation", 10)
	accessibility_section = acc_grid
	vbox.add_child(acc_grid)
	vbox.move_child(acc_grid, header.get_index() + 1)
	
	# Colorblind mode
	var cb_label = Label.new()
	_register_localized_text_control(
		cb_label,
		"settings_colorblind_mode",
		"🎨 Colorblind Mode"
	)
	cb_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(cb_label)
	
	colorblind_check = CheckBox.new()
	_register_localized_text_control(
		colorblind_check,
		"settings_enable",
		"Enable"
	)
	colorblind_check.button_pressed = _get_accessibility_setting("colorblind_mode")
	colorblind_check.toggled.connect(_on_colorblind_toggled)
	acc_grid.add_child(colorblind_check)
	
	# Large touch targets
	var lt_label = Label.new()
	_register_localized_text_control(
		lt_label,
		"settings_large_touch_targets",
		"👆 Large Touch Targets"
	)
	lt_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(lt_label)
	
	large_targets_check = CheckBox.new()
	_register_localized_text_control(
		large_targets_check,
		"settings_enable",
		"Enable"
	)
	large_targets_check.button_pressed = _get_accessibility_setting("large_touch_targets")
	large_targets_check.toggled.connect(_on_large_targets_toggled)
	acc_grid.add_child(large_targets_check)
	
	# Audio cues
	var ac_label = Label.new()
	_register_localized_text_control(
		ac_label,
		"settings_audio_cues",
		"🔊 Audio Cues"
	)
	ac_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(ac_label)
	
	audio_cues_check = CheckBox.new()
	_register_localized_text_control(
		audio_cues_check,
		"settings_enable",
		"Enable"
	)
	audio_cues_check.button_pressed = _get_accessibility_setting("audio_cues", true)
	audio_cues_check.toggled.connect(_on_audio_cues_toggled)
	acc_grid.add_child(audio_cues_check)

	# Haptics
	var hp_label = Label.new()
	_register_localized_text_control(
		hp_label,
		"settings_haptic_feedback",
		"📳 Haptic Feedback"
	)
	hp_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(hp_label)

	haptics_check = CheckBox.new()
	_register_localized_text_control(
		haptics_check,
		"settings_enable",
		"Enable"
	)
	haptics_check.button_pressed = _get_accessibility_setting("haptics_enabled", true)
	haptics_check.toggled.connect(_on_haptics_toggled)
	acc_grid.add_child(haptics_check)
	
	# Screen shake
	var ss_label = Label.new()
	_register_localized_text_control(
		ss_label,
		"settings_screen_shake",
		"📳 Screen Shake"
	)
	ss_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(ss_label)
	
	screen_shake_check = CheckBox.new()
	_register_localized_text_control(
		screen_shake_check,
		"settings_enable",
		"Enable"
	)
	screen_shake_check.button_pressed = _get_accessibility_setting("screen_shake", true)
	screen_shake_check.toggled.connect(_on_screen_shake_toggled)
	acc_grid.add_child(screen_shake_check)
	
	# Particles
	var pt_label = Label.new()
	_register_localized_text_control(
		pt_label,
		"settings_particles_effects",
		"✨ Particles/Effects"
	)
	pt_label.add_theme_font_size_override("font_size", 18)
	acc_grid.add_child(pt_label)
	
	particles_check = CheckBox.new()
	_register_localized_text_control(
		particles_check,
		"settings_enable",
		"Enable"
	)
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
	_register_localized_text_control(
		header,
		"settings_dev_mode_header",
		"🛠 Dev Mode / Thesis Monitoring"
	)
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
	_register_localized_text_control(
		dm_label,
		"settings_enable_dev_mode",
		"Enable Dev Mode"
	)
	dm_label.add_theme_font_size_override("font_size", 18)
	dev_grid.add_child(dm_label)

	dev_mode_check = CheckBox.new()
	_register_localized_text_control(
		dev_mode_check,
		"settings_enable",
		"Enable"
	)
	dev_mode_check.button_pressed = dev_mode_enabled
	dev_mode_check.toggled.connect(_on_dev_mode_toggled)
	dev_grid.add_child(dev_mode_check)

	var profiler_label = Label.new()
	_register_localized_text_control(
		profiler_label,
		"settings_show_iso_profiler",
		"Show ISO Profiler (F11)"
	)
	profiler_label.add_theme_font_size_override("font_size", 18)
	dev_grid.add_child(profiler_label)

	dev_profiler_check = CheckBox.new()
	_register_localized_text_control(
		dev_profiler_check,
		"settings_show",
		"Show"
	)
	dev_profiler_check.button_pressed = bool(
		_get_dev_setting("dev_show_profiler", false)
	)
	dev_profiler_check.toggled.connect(_on_dev_profiler_toggled)
	dev_grid.add_child(dev_profiler_check)

	var algo_label = Label.new()
	_register_localized_text_control(
		algo_label,
		"settings_show_algorithm_overlay",
		"Show Algorithm Overlay (F12)"
	)
	algo_label.add_theme_font_size_override("font_size", 18)
	dev_grid.add_child(algo_label)

	dev_algorithm_check = CheckBox.new()
	_register_localized_text_control(
		dev_algorithm_check,
		"settings_show",
		"Show"
	)
	dev_algorithm_check.button_pressed = bool(
		_get_dev_setting("dev_show_algorithm_overlay", false)
	)
	dev_algorithm_check.toggled.connect(_on_dev_algorithm_toggled)
	dev_grid.add_child(dev_algorithm_check)

	var note = Label.new()
	_register_localized_text_control(
		note,
		"settings_dev_note",
		"Use toggles on mobile (same as F11/F12 on PC)."
	)
	note.add_theme_font_size_override("font_size", 14)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = Color(1, 1, 1, 1)
	vbox.add_child(note)

	_apply_dev_mode_visibility(dev_mode_enabled)

func _get_accessibility_setting(key: String, default_val: bool = false) -> bool:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		return bool(save_mgr.get_setting(key, default_val))
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

	if MobileUIManager and MobileUIManager.has_method("adapt_scene_for_mobile"):
		var current_scene = get_tree().current_scene
		if current_scene:
			MobileUIManager.adapt_scene_for_mobile(current_scene)

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
	if TouchInputManager:
		TouchInputManager.haptics_enabled = pressed

func _on_screen_shake_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()
	var acc_mgr = get_node_or_null("/root/AccessibilityManager")
	if acc_mgr and acc_mgr.has_method("set_screen_shake_enabled"):
		acc_mgr.set_screen_shake_enabled(pressed)
	else:
		var save_mgr = get_node_or_null("/root/SaveManager")
		if save_mgr:
			save_mgr.set_setting("screen_shake", pressed)

func _on_particles_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()
	var acc_mgr = get_node_or_null("/root/AccessibilityManager")
	if acc_mgr and acc_mgr.has_method("set_particles_enabled"):
		acc_mgr.set_particles_enabled(pressed)
	else:
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
	title_label.text = _loc("settings", "⚙️ SETTINGS")
	language_label.text = _loc("language", "Language / Wika")
	volume_label.text = _loc("volume", "Volume")
	if fullscreen_label:
		fullscreen_label.text = _loc("fullscreen", "Fullscreen")
	# The row already has a left-side label, so keep toggle text empty.
	fullscreen_check.text = ""
	back_button.text = _loc("back", "⬅️ BACK")
	if exit_button:
		exit_button.text = _loc("exit", "EXIT")

	_refresh_dynamic_localized_texts()

func _update_language_button() -> void:
	if Localization and Localization.is_filipino():
		language_button.text = _loc("filipino", "Filipino")
	else:
		language_button.text = _loc("english", "English")

func _update_theme_button() -> void:
	var is_dark: bool = GameManager.dark_mode_enabled if GameManager else false
	var theme_text := _loc("dark_mode", "Dark")
	var light_text := _loc("light_mode", "Light")
	var prefix := _loc("theme", "Theme")
	theme_button.text = "%s: %s" % [prefix, theme_text if is_dark else light_text]

func _on_theme_changed(_is_dark: bool) -> void:
	_update_theme_button()
	_apply_theme()

func _on_language_changed(_new_lang: String) -> void:
	_update_translations()
	_update_language_button()
	_update_theme_button()

func _on_language_button_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if Localization:
		Localization.toggle_language()


func _wire_runtime_setting_controls() -> void:
	if volume_slider and not volume_slider.value_changed.is_connected(
		_on_volume_slider_value_changed
	):
		volume_slider.value_changed.connect(_on_volume_slider_value_changed)

	if fullscreen_check and not fullscreen_check.toggled.is_connected(_on_fullscreen_check_toggled):
		fullscreen_check.toggled.connect(_on_fullscreen_check_toggled)


func _sync_runtime_setting_controls() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")

	if volume_slider:
		var volume_linear := 1.0
		if save_mgr:
			volume_linear = float(save_mgr.get_setting("music_volume", 0.8))
		elif AudioManager:
			volume_linear = float(AudioManager.music_volume)
		volume_slider.set_value_no_signal(clampf(volume_linear, 0.0, 1.0) * 100.0)

	if fullscreen_check:
		if _is_mobile_platform():
			fullscreen_check.set_pressed_no_signal(true)
			fullscreen_check.disabled = true
		else:
			var default_fullscreen = _is_window_fullscreen()
			var want_fullscreen = bool(
				save_mgr.get_setting("fullscreen", default_fullscreen)
			) if save_mgr else default_fullscreen
			fullscreen_check.set_pressed_no_signal(want_fullscreen)
			_apply_fullscreen_mode(want_fullscreen, false)


func _is_mobile_platform() -> bool:
	if MobileUIManager and MobileUIManager.has_method("is_mobile_platform"):
		return MobileUIManager.is_mobile_platform()
	return OS.get_name() in ["Android", "iOS"]


func _is_window_fullscreen() -> bool:
	var mode = DisplayServer.window_get_mode()
	return (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


func _apply_fullscreen_mode(enabled: bool, persist: bool = true) -> void:
	if _is_mobile_platform():
		return

	if enabled:
		if not _is_window_fullscreen():
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if _is_window_fullscreen():
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if persist:
		var save_mgr = get_node_or_null("/root/SaveManager")
		if save_mgr:
			save_mgr.set_setting("fullscreen", enabled)


func _on_volume_slider_value_changed(value: float) -> void:
	var linear_volume = clampf(value / 100.0, 0.0, 1.0)
	if AudioManager:
		if AudioManager.has_method("set_music_volume"):
			AudioManager.set_music_volume(linear_volume)
		if AudioManager.has_method("set_sfx_volume"):
			AudioManager.set_sfx_volume(linear_volume)
	else:
		var save_mgr = get_node_or_null("/root/SaveManager")
		if save_mgr:
			save_mgr.set_setting("music_volume", linear_volume)
			save_mgr.set_setting("sfx_volume", linear_volume)


func _on_fullscreen_check_toggled(pressed: bool) -> void:
	if AudioManager:
		AudioManager.play_click()
	_apply_fullscreen_mode(pressed)

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
	var theme_mgr = get_node_or_null("/root/ThemeManager")
	var is_dark := false
	var panel_color := Color(0.95, 0.92, 0.85, 1.0)
	var panel_border := Color(0.75, 0.75, 0.75, 1.0)
	var text_primary := Color(0.12, 0.12, 0.12, 1.0)
	var text_secondary := Color(0.20, 0.20, 0.20, 1.0)

	if theme_mgr:
		if theme_mgr.has_method("is_dark_mode"):
			is_dark = bool(theme_mgr.is_dark_mode())
		panel_color = theme_mgr.get_color("panel")
		panel_border = theme_mgr.get_color("panel_border")
		text_primary = theme_mgr.get_color("text_primary")
		text_secondary = theme_mgr.get_color("text_secondary")

	if not is_dark:
		# Strengthen contrast in light mode for better readability on small text.
		text_primary = Color(0.12, 0.12, 0.12, 1.0)
		text_secondary = Color(0.20, 0.20, 0.20, 1.0)

	var panel_style = panel_card.get_theme_stylebox("panel").duplicate()
	if panel_style is StyleBoxFlat:
		(panel_style as StyleBoxFlat).bg_color = panel_color
		(panel_style as StyleBoxFlat).border_color = panel_border
	panel_card.add_theme_stylebox_override("panel", panel_style)

	title_label.add_theme_color_override("font_color", text_primary)
	language_label.add_theme_color_override("font_color", text_secondary)
	volume_label.add_theme_color_override("font_color", text_secondary)
	if fullscreen_label:
		fullscreen_label.add_theme_color_override("font_color", text_secondary)
	if settings_scroll:
		_apply_text_color_recursive(
			settings_scroll,
			text_primary,
			text_secondary,
			is_dark
		)
		# Preserve stronger title contrast after recursive recolor pass.
		title_label.add_theme_color_override("font_color", text_primary)

	var secondary_bg := Color(0.97, 0.97, 0.97, 1.0)
	var secondary_border := Color(0.74, 0.74, 0.74, 1.0)
	var secondary_text := Color(0.14, 0.14, 0.14, 1.0)
	if is_dark:
		secondary_bg = Color(0.90, 0.94, 0.99, 1.0)
		secondary_border = Color(0.66, 0.76, 0.88, 1.0)
		secondary_text = Color(0.18, 0.22, 0.30, 1.0)

	var primary_bg := Color(0.2, 0.6, 0.95, 1.0)
	var primary_border := Color(0.06, 0.32, 0.6, 1.0)
	if is_dark:
		primary_bg = Color(0.23, 0.65, 0.95, 1.0)
		primary_border = Color(0.10, 0.40, 0.72, 1.0)

	var danger_bg := Color(0.85, 0.3, 0.3, 1.0)
	var danger_border := Color(0.6, 0.2, 0.2, 1.0)
	if is_dark:
		danger_bg = Color(0.90, 0.36, 0.36, 1.0)
		danger_border = Color(0.68, 0.24, 0.24, 1.0)

	var slider_track := Color(0.74, 0.74, 0.74, 1.0)
	var slider_fill := Color(0.20, 0.60, 0.95, 1.0)
	var slider_border := Color(0.52, 0.52, 0.52, 1.0)
	if is_dark:
		slider_track = Color(0.52, 0.60, 0.72, 1.0)
		slider_fill = Color(0.33, 0.72, 1.0, 1.0)
		slider_border = Color(0.38, 0.47, 0.62, 1.0)

	_apply_button_style_set(
		language_button,
		secondary_bg,
		secondary_border,
		secondary_text,
		secondary_bg.darkened(0.04),
		secondary_bg.darkened(0.10),
		6,
		false
	)
	_apply_button_style_set(
		theme_button,
		secondary_bg,
		secondary_border,
		secondary_text,
		secondary_bg.darkened(0.04),
		secondary_bg.darkened(0.10),
		6,
		false
	)
	_apply_button_style_set(
		back_button,
		primary_bg,
		primary_border,
		Color.WHITE,
		primary_bg.lightened(0.06),
		primary_bg.darkened(0.12),
		8,
		true
	)
	_apply_button_style_set(
		exit_button,
		danger_bg,
		danger_border,
		Color.WHITE,
		danger_bg.lightened(0.06),
		danger_bg.darkened(0.12),
		8,
		true
	)

	if language_button:
		language_button.disabled = false
		language_button.modulate = Color.WHITE
	if theme_button:
		theme_button.disabled = false
		theme_button.modulate = Color.WHITE

	var toggle_col = text_secondary if is_dark else text_primary
	if fullscreen_check:
		fullscreen_check.add_theme_color_override("font_color", toggle_col)
		fullscreen_check.add_theme_color_override("font_hover_color", toggle_col)
		fullscreen_check.add_theme_color_override("font_disabled_color", toggle_col)
	if colorblind_check:
		colorblind_check.add_theme_color_override("font_disabled_color", toggle_col)
	if large_targets_check:
		large_targets_check.add_theme_color_override("font_disabled_color", toggle_col)
	if audio_cues_check:
		audio_cues_check.add_theme_color_override("font_disabled_color", toggle_col)
	if haptics_check:
		haptics_check.add_theme_color_override("font_disabled_color", toggle_col)
	if screen_shake_check:
		screen_shake_check.add_theme_color_override("font_disabled_color", toggle_col)
	if particles_check:
		particles_check.add_theme_color_override("font_disabled_color", toggle_col)
	if dev_mode_check:
		dev_mode_check.add_theme_color_override("font_disabled_color", toggle_col)
	if dev_profiler_check:
		dev_profiler_check.add_theme_color_override("font_disabled_color", toggle_col)
	if dev_algorithm_check:
		dev_algorithm_check.add_theme_color_override("font_disabled_color", toggle_col)

	_apply_slider_theme(slider_track, slider_fill, slider_border)


func _apply_text_color_recursive(
	root: Node,
	text_primary: Color,
	text_secondary: Color,
	is_dark: bool
) -> void:
	if not root:
		return

	for child in root.get_children():
		if child == title_label:
			_apply_text_color_recursive(
				child,
				text_primary,
				text_secondary,
				is_dark
			)
			continue

		if child is Label:
			var lbl := child as Label
			var fs := lbl.get_theme_font_size("font_size")
			var label_color := text_secondary
			if fs >= 24:
				label_color = text_primary
			elif not is_dark and fs <= 18:
				label_color = text_secondary.darkened(0.08)
			lbl.add_theme_color_override("font_color", label_color)
			if not is_dark:
				lbl.modulate = Color(1, 1, 1, 1)
		elif child is CheckBox or child is CheckButton:
			var check_col := text_secondary if is_dark else text_primary
			(child as Control).add_theme_color_override("font_color", check_col)
			(child as Control).add_theme_color_override(
				"font_disabled_color",
				check_col.darkened(0.25)
			)
		elif child is HSeparator:
			var sep_alpha = 0.50 if not is_dark else 0.38
			(child as HSeparator).modulate = Color(1, 1, 1, sep_alpha)

		_apply_text_color_recursive(
			child,
			text_primary,
			text_secondary,
			is_dark
		)


func _apply_slider_theme(track_col: Color, fill_col: Color, border_col: Color) -> void:
	if not volume_slider:
		return

	var track := StyleBoxFlat.new()
	track.bg_color = track_col
	track.border_color = border_col
	track.border_width_left = 1
	track.border_width_right = 1
	track.corner_radius_top_left = 4
	track.corner_radius_top_right = 4
	track.corner_radius_bottom_left = 4
	track.corner_radius_bottom_right = 4
	track.content_margin_top = 3
	track.content_margin_bottom = 3

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3

	volume_slider.add_theme_stylebox_override("slider", track)
	volume_slider.add_theme_stylebox_override("grabber_area", fill)
	volume_slider.add_theme_stylebox_override("grabber_area_highlight", fill)


func _apply_button_style_set(
	button: Button,
	base_bg: Color,
	border_color: Color,
	text_color: Color,
	hover_bg: Color,
	pressed_bg: Color,
	border_bottom: int,
	use_shadow: bool
) -> void:
	if not button:
		return

	var normal := StyleBoxFlat.new()
	normal.bg_color = base_bg
	normal.border_width_bottom = border_bottom
	normal.border_color = border_color
	normal.corner_radius_top_left = 15
	normal.corner_radius_top_right = 15
	normal.corner_radius_bottom_right = 15
	normal.corner_radius_bottom_left = 15

	if use_shadow:
		normal.shadow_color = Color(0, 0, 0, 0.2)
		normal.shadow_size = 4
		normal.shadow_offset = Vector2(0, 4)

	var hover := normal.duplicate()
	if hover is StyleBoxFlat:
		(hover as StyleBoxFlat).bg_color = hover_bg

	var pressed := normal.duplicate()
	if pressed is StyleBoxFlat:
		(pressed as StyleBoxFlat).bg_color = pressed_bg

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color)
	button.modulate = Color.WHITE

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
