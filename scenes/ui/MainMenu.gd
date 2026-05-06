extends Control

## ═══════════════════════════════════════════════════════════════════
## MAIN MENU CONTROLLER
## ═══════════════════════════════════════════════════════════════════

@onready var title_label = $UI/VBoxContainer/TitleContainer/Title
@onready var subtitle_label = $UI/VBoxContainer/TitleContainer/Subtitle
@onready var play_button = $UI/VBoxContainer/PlayButton
@onready var quit_button = $UI/VBoxContainer/QuitButton
@onready var loading_container = $UI/VBoxContainer/LoadingContainer
@onready var progress_bar = $UI/VBoxContainer/LoadingContainer/ProgressBar
@onready var loading_label = $UI/VBoxContainer/LoadingContainer/LoadingLabel
@onready var character = $Decorations/Character

const INITIAL_SCREEN_PATH := "res://scenes/ui/InitialScreen.tscn"
const MIN_LOADING_VISIBLE_MS: int = 450

var _is_loading_scene: bool = false
var _loading_text_timer: Timer
var _character_tweens: Array[Tween] = []
var _loading_started_ms: int = 0

var loading_messages_en = [
	"Fetching watering can...",
	"Planting seeds...",
	"Setting up adaptive difficulty...",
	"Waiting for water...",
	"Analyzing water conservation..."
]

var loading_messages_tl = [
	"Naglalako ng watering can...",
	"Tinatanim ang halaman...",
	"Ini-set up ang adaptive difficulty...",
	"Hinihintay ang tubig...",
	"Sinusuri ang water conservation..."
]

func _ready() -> void:
	_ensure_fullscreen_backdrop()
	await get_tree().process_frame
	_update_translations()
	_animate_entrance()
	_place_main_character_in_view()
	if character:
		# Disable the legacy bobbing script so runtime hero animation remains deterministic.
		character.set_process(false)
	_start_character_animation()

	# Start menu music
	if AudioManager:
		AudioManager.play_music("menu")
	
	# Apply mobile UI scaling if on mobile platform
	if MobileUIManager and MobileUIManager.is_mobile_platform():
		_apply_mobile_ui_scaling()

	# Keep layout stable on any phone viewport and orientation updates.
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	
	# Connect to language changes
	if Localization:
		Localization.language_changed.connect(_on_language_changed)

	# Connect button hover/press signals for smooth animations
	if play_button:
		var cb_enter = Callable(self, "_on_button_mouse_entered")
		play_button.connect("mouse_entered",
			cb_enter.bind(play_button))
		var cb_exit = Callable(self, "_on_button_mouse_exited")
		play_button.connect("mouse_exited",
			cb_exit.bind(play_button))
		play_button.connect("pressed",
			Callable(self, "_on_button_pressed_anim")
			.bind(play_button))

	if quit_button:
		var cb_enter = Callable(self, "_on_button_mouse_entered")
		quit_button.connect("mouse_entered",
			cb_enter.bind(quit_button))
		var cb_exit = Callable(self, "_on_button_mouse_exited")
		quit_button.connect("mouse_exited",
			cb_exit.bind(quit_button))
		quit_button.connect("pressed",
			Callable(self, "_on_button_pressed_anim")
			.bind(quit_button))

	# Auto-play toggle — only visible when dev mode is enabled
	var _sm = get_node_or_null("/root/SaveManager")
	if _sm and bool(_sm.get_setting("dev_mode", false)):
		_create_autoplay_toggle()

	set_process(false)

## Creates the AutoPlay toggle button overlay in the bottom-left of the main menu.
## Pressing it toggles AutoPlayManager.auto_play_enabled for the next single-player session.
func _create_autoplay_toggle() -> void:
	# Container anchored bottom-left
	var container := HBoxContainer.new()
	container.name = "AutoPlayToggleContainer"
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.position = Vector2(24, -60)
	container.add_theme_constant_override("separation", 10)
	add_child(container)

	# Indicator dot
	var dot := Label.new()
	dot.name = "AutoPlayDot"
	var is_on: bool = AutoPlayManager.is_auto_play_enabled() if AutoPlayManager else false
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 18)
	dot.add_theme_color_override("font_color",
		Color(0.2, 0.9, 0.3) if is_on else Color(0.55, 0.55, 0.55))
	container.add_child(dot)

	# Toggle button
	var btn := Button.new()
	btn.name = "AutoPlayToggleBtn"
	btn.text = "🤖 Auto-Play: %s" % ("ON" if is_on else "OFF")
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(190, 40)
	btn.tooltip_text = "Enable automated gameplay for single-player performance testing"
	container.add_child(btn)

	btn.pressed.connect(func():
		if not AutoPlayManager:
			return
		var enabled: bool = not AutoPlayManager.is_auto_play_enabled()
		AutoPlayManager.set_auto_play_enabled(enabled)
		btn.text = "🤖 Auto-Play: %s" % ("ON" if enabled else "OFF")
		dot.add_theme_color_override("font_color",
			Color(0.2, 0.9, 0.3) if enabled else Color(0.55, 0.55, 0.55))
		if AudioManager:
			AudioManager.play_click()
	)

func _ensure_fullscreen_backdrop() -> void:
	var backdrop = get_node_or_null("RuntimeBackdrop") as ColorRect
	if backdrop:
		RenderingServer.set_default_clear_color(backdrop.color)
		return

	backdrop = ColorRect.new()
	backdrop.name = "RuntimeBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.231373, 0.321569, 0.462745, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -100
	add_child(backdrop)
	move_child(backdrop, 0)

	# Keep uncovered viewport regions from showing default gray.
	RenderingServer.set_default_clear_color(backdrop.color)

func _update_translations() -> void:
	if not Localization:
		return
	
	title_label.text = Localization.get_text("title")
	subtitle_label.text = Localization.get_text("subtitle")
	play_button.text = Localization.get_text("play")
	quit_button.text = Localization.get_text("quit")

func _on_language_changed(_new_lang: String) -> void:
	_update_translations()

func _animate_entrance() -> void:
	# Fade in only the UI panel — background/waves stay solid the whole time
	# so no colored "lines" flash before the dark background appears.
	var ui_node = get_node_or_null("UI")
	if ui_node:
		ui_node.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(ui_node, "modulate:a", 1.0, 0.6)


func _place_main_character_in_view() -> void:
	if not character:
		return

	var vp = get_viewport_rect().size
	if vp == Vector2.ZERO:
		return

	character.position = Vector2(vp.x * 0.82, vp.y * 0.70)
	var scale_factor = clamp(min(vp.x / 1920.0, vp.y / 1080.0), 0.72, 1.15)
	character.scale = Vector2.ONE * (2.05 * scale_factor)
	character.rotation = deg_to_rad(18.0)
 

func _kill_character_tweens() -> void:
	for tw in _character_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_character_tweens.clear()

func _start_character_animation() -> void:
	if not character:
		return

	_kill_character_tweens()

	var base_rotation = deg_to_rad(18.0)
	character.rotation = base_rotation

	var is_mobile := MobileUIManager and MobileUIManager.is_mobile_platform()
	var move_amp := 15.0 if not is_mobile else 8.0
	var arm_wave_enabled := not is_mobile

	# ROTATION - separate looping tween
	var rotation_tween = create_tween().set_loops()
	_character_tweens.append(rotation_tween)
	var rt1 = rotation_tween.tween_property(
		character, "rotation", base_rotation + deg_to_rad(7.0), 1.0)
	rt1.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var rt2 = rotation_tween.tween_property(
		character, "rotation", base_rotation - deg_to_rad(6.0), 1.0)
	rt2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# UP / DOWN MOVEMENT (Y axis) - separate looping tween
	var base_y = character.position.y
	var position_tween = create_tween().set_loops()
	_character_tweens.append(position_tween)
	var pt1 = position_tween.tween_property(
		character, "position:y", base_y - move_amp, 1.0)
	pt1.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pt2 = position_tween.tween_property(
		character, "position:y", base_y + move_amp, 1.0)
	pt2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ARM WAVE animation
	var left_arm = character.get_node_or_null("LeftArm")
	var right_arm = character.get_node_or_null("RightArm")
	if arm_wave_enabled and left_arm:
		var la_base_rot = left_arm.rotation
		var arm_tw_l = create_tween().set_loops()
		_character_tweens.append(arm_tw_l)
		arm_tw_l.tween_property(
			left_arm, "rotation", la_base_rot + deg_to_rad(15.0), 0.6
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		arm_tw_l.tween_property(
			left_arm, "rotation", la_base_rot - deg_to_rad(10.0), 0.6
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if arm_wave_enabled and right_arm:
		var ra_base_rot = right_arm.rotation
		var arm_tw_r = create_tween().set_loops()
		_character_tweens.append(arm_tw_r)
		arm_tw_r.tween_property(
			right_arm, "rotation", ra_base_rot - deg_to_rad(15.0), 0.7
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		arm_tw_r.tween_property(
			right_arm, "rotation", ra_base_rot + deg_to_rad(10.0), 0.7
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)



func _on_button_mouse_entered(btn: Button) -> void:
	var t = create_tween()
	var tw = t.tween_property(
		btn, "scale", Vector2(1.03, 1.03), 0.18)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_button_mouse_exited(btn: Button) -> void:
	var t = create_tween()
	var tw = t.tween_property(
		btn, "scale", Vector2(1, 1), 0.18)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_button_pressed_anim(btn: Button) -> void:
	# quick press down then recover
	var t = create_tween()
	var tw1 = t.tween_property(
		btn, "scale", Vector2(0.98, 0.98), 0.06)
	tw1.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var tw2 = t.tween_property(
		btn, "scale", Vector2(1.03, 1.03), 0.12)
	tw2.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_play_button_pressed() -> void:
	if _is_loading_scene:
		return

	_play_button_sound()
	_sync_wallet_from_save()
	
	# Switch to loading state within Main Menu
	play_button.hide()
	quit_button.hide()
	loading_container.show()
	progress_bar.value = 0.0
	_is_loading_scene = true
	_loading_started_ms = Time.get_ticks_msec()
	_start_loading_text_updates()
	
	var request_err := ResourceLoader.load_threaded_request(
		INITIAL_SCREEN_PATH,
		"PackedScene",
		false
	)
	if request_err != OK:
		push_warning(
			"Threaded load request failed (%d). "
			+ "Falling back to direct scene change." % request_err
		)
		_complete_loading(null)
		return

	set_process(true)


func _process(_delta: float) -> void:
	if not _is_loading_scene:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(INITIAL_SCREEN_PATH, progress)

	if not progress.is_empty():
		progress_bar.value = clamp(float(progress[0]) * 100.0, 0.0, 100.0)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var loaded_resource := ResourceLoader.load_threaded_get(INITIAL_SCREEN_PATH)
		_complete_loading(loaded_resource)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("Threaded load failed for %s" % INITIAL_SCREEN_PATH)
		_complete_loading(null)
	elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("Threaded load invalid resource for %s" % INITIAL_SCREEN_PATH)
		_complete_loading(null)


func _start_loading_text_updates() -> void:
	if _loading_text_timer and is_instance_valid(_loading_text_timer):
		_loading_text_timer.queue_free()

	_loading_text_timer = Timer.new()
	_loading_text_timer.wait_time = 0.7
	_loading_text_timer.one_shot = false
	add_child(_loading_text_timer)
	_loading_text_timer.timeout.connect(_update_loading_text)
	_loading_text_timer.start()
	_update_loading_text()


func _stop_loading_text_updates() -> void:
	if _loading_text_timer and is_instance_valid(_loading_text_timer):
		_loading_text_timer.stop()
		_loading_text_timer.queue_free()
	_loading_text_timer = null


func _complete_loading(loaded_resource: Resource) -> void:
	_is_loading_scene = false
	set_process(false)
	_stop_loading_text_updates()
	progress_bar.value = 100.0

	var elapsed_ms = Time.get_ticks_msec() - _loading_started_ms
	if elapsed_ms < MIN_LOADING_VISIBLE_MS:
		var wait_time = float(MIN_LOADING_VISIBLE_MS - elapsed_ms) / 1000.0
		await get_tree().create_timer(wait_time).timeout

	_loading_started_ms = 0

	if loaded_resource is PackedScene:
		get_tree().change_scene_to_packed(loaded_resource as PackedScene)
		return

	if GameManager:
		GameManager.transition_to_scene(INITIAL_SCREEN_PATH)
	else:
		get_tree().change_scene_to_file(INITIAL_SCREEN_PATH)

func _update_loading_text() -> void:
	var progress_value: float = float(progress_bar.value)
	var use_english: bool = Localization and Localization.is_english()
	var messages = loading_messages_en if use_english else loading_messages_tl

	if progress_value < 25.0:
		loading_label.text = messages[0]
	elif progress_value < 50.0:
		loading_label.text = messages[1]
	elif progress_value < 75.0:
		loading_label.text = messages[2]
	elif progress_value < 95.0:
		loading_label.text = messages[3]
	else:
		loading_label.text = messages[4]

func _on_quit_button_pressed() -> void:
	_play_button_sound()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _play_button_sound() -> void:
	if AudioManager:
		AudioManager.play_click()


func _sync_wallet_from_save() -> void:
	if not SaveManager:
		return

	if GameManager:
		GameManager.water_droplets = SaveManager.get_droplets()


func _exit_tree() -> void:
	_kill_character_tweens()

# ═══════════════════════════════════════════════════════════════════
# MOBILE UI SCALING
# ═══════════════════════════════════════════════════════════════════

func _apply_mobile_ui_scaling() -> void:
	# Apply mobile-specific UI scaling to all UI elements.
	# Scale main UI container
	var ui_container = $UI/VBoxContainer
	if ui_container:
		MobileUIManager.apply_mobile_scaling(ui_container)
	
	# Scale individual buttons
	if play_button:
		MobileUIManager.apply_mobile_scaling(play_button)
	if quit_button:
		MobileUIManager.apply_mobile_scaling(quit_button)
	
	# Scale labels
	if title_label:
		MobileUIManager.apply_mobile_scaling(title_label)
	if subtitle_label:
		MobileUIManager.apply_mobile_scaling(subtitle_label)
	
	# Apply safe area margins to root UI container.
	# IMPORTANT: On a fullscreen game with immersive_mode, the nav bar is
	# hidden/overlaid so we must NOT inset the CenterContainer based on the
	# nav-bar safe-area margin — that would shift the center LEFT (when Android
	# places the nav bar on the right in landscape) and break the layout.
	# Only inset for actual hardware display cutouts (notch top margin).
	var ui_root = get_node_or_null("UI") as Control
	if ui_root:
		var safe := MobileUIManager.get_safe_area_margins()
		# Use hardware-cutout top margin only; everything else stays at 0 so the
		# CenterContainer always has a symmetric bounding box and its child
		# content is pixel-perfect center on any landscape screen.
		var cutout_top := maxf(0.0, float(safe.get("top", 0.0)) - MobileUIManager.mobile_safe_area_margin)
		ui_root.offset_left   = 0.0
		ui_root.offset_right  = 0.0
		ui_root.offset_bottom = 0.0
		ui_root.offset_top    = cutout_top
	
	# Enable haptic feedback for buttons
	if TouchInputManager:
		TouchInputManager.enable_haptics_for_scene(self)
	
	print("📱 Mobile UI scaling applied to MainMenu")


func _on_viewport_resized() -> void:
	_place_main_character_in_view()
	if MobileUIManager and MobileUIManager.is_mobile_platform():
		_apply_mobile_ui_scaling()

	# Reposition autoplay dev toggle above bottom safe area.
	var toggle = get_node_or_null("AutoPlayToggleContainer") as Control
	if toggle:
		var safe_bottom := 0.0
		if MobileUIManager and MobileUIManager.has_method("get_safe_area_margins"):
			safe_bottom = float(MobileUIManager.get_safe_area_margins().get("bottom", 0.0))
		toggle.position = Vector2(24, -60 - safe_bottom)
