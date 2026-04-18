extends Control

@onready var background = $Background
@onready var root_vbox = $CenterContainer/VBoxContainer

const UI_FONT = preload("res://fonts/NTBrickSans.otf")
const BG_HILLS = preload("res://assets/bg_layers/hills.png")
const BG_HOUSE = preload("res://assets/bg_layers/house.png")
const BG_PLATFORM = preload("res://assets/bg_layers/platform.png")
const BG_WAVES_1 = preload("res://assets/bg_layers/waves_1.png")
const BG_WAVES_2 = preload("res://assets/bg_layers/waves_2.png")
const BG_WAVES_3 = preload("res://assets/bg_layers/waves_3.png")

const CHARACTER_PRESETS: Array[Dictionary] = [
	{"id": "droppy_blue", "name": "Droppy", "hat": "💧", "color": Color(0.3, 0.6, 1.0)},
	{"id": "pinky", "name": "Pinky", "hat": "🎀", "color": Color(1.0, 0.6, 0.8)},
	{"id": "minty", "name": "Minty", "hat": "🧢", "color": Color(0.6, 1.0, 0.8)},
	{"id": "sunny", "name": "Sunny", "hat": "☀️", "color": Color(1.0, 0.9, 0.4)},
	{"id": "lavvy", "name": "Lavvy", "hat": "✨", "color": Color(0.8, 0.6, 1.0)},
	{"id": "peachy", "name": "Peachy", "hat": "🍑", "color": Color(1.0, 0.8, 0.7)},
	{"id": "cyanny", "name": "Cyanny", "hat": "🌊", "color": Color(0.4, 1.0, 1.0)},
	{"id": "coral", "name": "Coral", "hat": "🪸", "color": Color(1.0, 0.5, 0.5)},
]

const ACCESSORIES: Array[Dictionary] = [
	{"id": "character_default", "name": "Default", "icon": "💧"},
	{"id": "sun_hat", "name": "Sun Hat", "icon": "👒"},
	{"id": "cool_shades", "name": "Cool Shades", "icon": "🕶️"},
	{"id": "party_cap", "name": "Party Cap", "icon": "🎉"},
	{"id": "leaf_crown", "name": "Leaf Crown", "icon": "🍃"},
	{"id": "bow", "name": "Bow", "icon": "🎀"},
	{"id": "safety_helmet", "name": "Helmet", "icon": "⛑️"},
]

const ACCESSORY_NAME_KEYS: Dictionary = {
	"character_default": "accessory_default",
	"sun_hat": "accessory_sun_hat",
	"cool_shades": "accessory_cool_shades",
	"party_cap": "accessory_party_cap",
	"leaf_crown": "accessory_leaf_crown",
	"bow": "accessory_bow",
	"safety_helmet": "accessory_safety_helmet",
}

var _carousel_index: int = 0
var _is_sliding: bool = false
var _preview_holder: Control
var _preview_node: Node2D
var _name_label: Label
var _status_label: Label
var _title_label: Label
var _acc_label: Label
var _save_button: Button
var _back_button: Button
var _left_arrow: Button
var _right_arrow: Button
var _accessory_grid: HBoxContainer
var _accessory_buttons: Dictionary = {}
var _bob_tween: Tween
var _bg_layers: Control
var _bg_tint: ColorRect
var _wave_layers: Array[TextureRect] = []
var _ambient_layer_tweens: Array[Tween] = []
var _feedback_tweens: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	_load_state()
	_setup_waterville_background()
	_build_runtime_ui()
	_update_carousel(0)
	_update_accessory_buttons()
	_update_translations()
	_apply_ui_theme()
	var theme_mgr = get_node_or_null("/root/ThemeManager")
	if theme_mgr and theme_mgr.has_signal("theme_changed"):
		var cb := Callable(self, "_on_theme_changed")
		if not theme_mgr.is_connected("theme_changed", cb):
			theme_mgr.connect("theme_changed", cb)
	_setup_interaction_feedback()
	if Localization:
		Localization.language_changed.connect(_on_language_changed)
	# Entrance popup animation
	if root_vbox:
		root_vbox.pivot_offset = root_vbox.size * 0.5
		root_vbox.modulate.a = 0.0
		root_vbox.scale = Vector2(0.85, 0.85)
		var tw = create_tween()
		tw.tween_property(root_vbox, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(
			root_vbox, "scale", Vector2(1.0, 1.0), 0.3
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _load_state() -> void:
	if SaveManager and SaveManager.has_method("get_selected_character"):
		var sel_id = str(SaveManager.get_selected_character())
		for i in range(CHARACTER_PRESETS.size()):
			if CHARACTER_PRESETS[i].id == sel_id:
				_carousel_index = i
				break


func _setup_waterville_background() -> void:
	if background:
		background.z_index = -30

	if _bg_layers and is_instance_valid(_bg_layers):
		_apply_background_theme()
		_start_waterville_ambient_motion()
		return

	_bg_layers = Control.new()
	_bg_layers.name = "WatervilleLayers"
	_bg_layers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_layers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_layers.z_index = -20
	add_child(_bg_layers)
	move_child(_bg_layers, 0)

	var hills = _add_waterville_layer("Hills", BG_HILLS, Color(1, 1, 1, 0.90))
	hills.rotation_degrees = -0.8
	hills.position = Vector2(-6, -105)

	var platform = _add_waterville_layer("Platform", BG_PLATFORM, Color(1, 1, 1, 0.93))
	platform.rotation_degrees = 0.5
	platform.position = Vector2(10, -94)

	var house = _add_waterville_layer("House", BG_HOUSE, Color(1, 1, 1, 0.95))
	house.rotation_degrees = -0.4
	house.position = Vector2(16, -98)

	var waves3 = _add_waterville_layer("Waves3", BG_WAVES_3, Color(1, 1, 1, 0.78))
	waves3.rotation_degrees = -0.6
	waves3.position = Vector2(-20, -118)

	var waves2 = _add_waterville_layer("Waves2", BG_WAVES_2, Color(1, 1, 1, 0.72))
	waves2.rotation_degrees = 0.3
	waves2.position = Vector2(-14, -110)

	var waves1 = _add_waterville_layer("Waves1", BG_WAVES_1, Color(1, 1, 1, 0.66))
	waves1.rotation_degrees = 0.8
	waves1.position = Vector2(-6, -102)
	_wave_layers = [waves1, waves2, waves3]

	_bg_tint = ColorRect.new()
	_bg_tint.name = "BackgroundTint"
	_bg_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_tint.z_index = 10
	_bg_layers.add_child(_bg_tint)

	_apply_background_theme()
	_start_waterville_ambient_motion()


func _add_waterville_layer(layer_name: String, tex: Texture2D, tint: Color) -> TextureRect:
	var layer = TextureRect.new()
	layer.name = layer_name
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.texture = tex
	layer.modulate = tint
	_bg_layers.add_child(layer)
	return layer


func _start_waterville_ambient_motion() -> void:
	for tw in _ambient_layer_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_ambient_layer_tweens.clear()

	for wave in _wave_layers:
		if wave and is_instance_valid(wave):
			_animate_layer_loop(wave, Vector2(10, 1.8), 5.8)

	var house = _bg_layers.get_node_or_null("House") as TextureRect
	var platform = _bg_layers.get_node_or_null("Platform") as TextureRect
	if house:
		_animate_layer_loop(house, Vector2(2.5, -1.2), 8.4)
	if platform:
		_animate_layer_loop(platform, Vector2(-2.0, 1.0), 9.2)


func _animate_layer_loop(layer: TextureRect, offset: Vector2, duration: float) -> void:
	if not layer:
		return
	if not layer.has_meta("_base_pos"):
		layer.set_meta("_base_pos", layer.position)

	var base_pos: Vector2 = layer.get_meta("_base_pos")
	var tw = create_tween().set_loops()
	tw.tween_property(layer, "position", base_pos + offset, duration).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(layer, "position", base_pos, duration).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	_ambient_layer_tweens.append(tw)


func _setup_interaction_feedback() -> void:
	var controls: Array[Control] = [_save_button, _back_button, _left_arrow, _right_arrow]
	for acc_btn in _accessory_buttons.values():
		if acc_btn is Control:
			controls.append(acc_btn as Control)

	for ctrl in controls:
		if ctrl:
			var hover_scale := 1.02
			if ctrl == _save_button or ctrl == _back_button:
				hover_scale = 1.04
			_bind_feedback(ctrl, hover_scale)


func _bind_feedback(control: Control, hover_scale: float) -> void:
	if not control:
		return
	if bool(control.get_meta("_feedback_bound", false)):
		return

	control.set_meta("_feedback_bound", true)
	control.pivot_offset = control.size * 0.5
	control.mouse_entered.connect(_on_feedback_hover_entered.bind(control, hover_scale))
	control.mouse_exited.connect(_on_feedback_hover_exited.bind(control))

	if control is BaseButton:
		var btn := control as BaseButton
		btn.button_down.connect(_on_feedback_pressed.bind(control))
		btn.button_up.connect(_on_feedback_released.bind(control, hover_scale))


func _on_feedback_hover_entered(control: Control, hover_scale: float) -> void:
	_animate_feedback_scale(control, Vector2(hover_scale, hover_scale), 0.11)


func _on_feedback_hover_exited(control: Control) -> void:
	_animate_feedback_scale(control, Vector2.ONE, 0.11)


func _on_feedback_pressed(control: Control) -> void:
	_animate_feedback_scale(control, Vector2(0.97, 0.97), 0.06)


func _on_feedback_released(control: Control, hover_scale: float) -> void:
	if not control:
		return
	var target := Vector2.ONE
	if control.get_global_rect().has_point(get_global_mouse_position()):
		target = Vector2(hover_scale, hover_scale)
	_animate_feedback_scale(control, target, 0.1)


func _animate_feedback_scale(control: Control, target_scale: Vector2, duration: float) -> void:
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


func _is_dark_mode_enabled() -> bool:
	if ThemeManager and ThemeManager.has_method("is_dark_mode"):
		return ThemeManager.is_dark_mode()
	if GameManager:
		return bool(GameManager.dark_mode_enabled)
	return false


func _apply_background_theme() -> void:
	var is_dark = _is_dark_mode_enabled()
	if background:
		background.color = (
			Color(0.73, 0.90, 0.98, 1.0)
			if not is_dark
			else Color(0.64, 0.79, 0.91, 1.0)
		)
	if _bg_tint:
		_bg_tint.color = (
			Color(1.0, 1.0, 1.0, 0.06)
			if not is_dark
			else Color(0.18, 0.30, 0.45, 0.18)
		)


func _apply_ui_theme() -> void:
	var is_dark = _is_dark_mode_enabled()
	var text_primary = (
		Color(0.12, 0.24, 0.35, 1.0)
		if not is_dark
		else Color(0.94, 0.97, 1.0, 1.0)
	)
	var text_secondary = (
		Color(0.22, 0.36, 0.50, 1.0)
		if not is_dark
		else Color(0.84, 0.91, 0.98, 1.0)
	)
	var panel_bg = (
		Color(0.96, 0.98, 1.0, 0.95)
		if not is_dark
		else Color(0.20, 0.31, 0.46, 0.92)
	)
	var arrow_bg = (
		Color(0.14, 0.32, 0.48, 0.92)
		if not is_dark
		else Color(0.18, 0.38, 0.56, 0.95)
	)

	if _title_label:
		_title_label.add_theme_color_override("font_color", text_primary)
	if _name_label:
		_name_label.add_theme_color_override("font_color", text_primary)
	if _acc_label:
		_acc_label.add_theme_color_override("font_color", text_secondary)
	if _status_label:
		_status_label.add_theme_color_override("font_color", text_secondary)

	for arrow_btn in [_left_arrow, _right_arrow]:
		if not arrow_btn:
			continue
		var style = StyleBoxFlat.new()
		style.bg_color = arrow_bg
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		arrow_btn.add_theme_stylebox_override("normal", style)
		arrow_btn.add_theme_stylebox_override("hover", style)
		arrow_btn.add_theme_stylebox_override("pressed", style)
		arrow_btn.add_theme_color_override("font_color", Color.WHITE)

	if _preview_holder and _preview_holder.get_parent():
		for child in _preview_holder.get_parent().get_children():
			if child is PanelContainer:
				var panel = child as PanelContainer
				var ps = StyleBoxFlat.new()
				ps.bg_color = panel_bg
				ps.corner_radius_top_left = 18
				ps.corner_radius_top_right = 18
				ps.corner_radius_bottom_left = 18
				ps.corner_radius_bottom_right = 18
				panel.add_theme_stylebox_override("panel", ps)


func _build_runtime_ui() -> void:
	_apply_background_theme()
	root_vbox.add_theme_constant_override("separation", 12)
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in root_vbox.get_children():
		root_vbox.remove_child(child)
		child.queue_free()
	var vp = get_viewport_rect().size

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", UI_FONT)
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color(0.12, 0.24, 0.35))
	root_vbox.add_child(_title_label)

	# Carousel row
	var carousel_row = HBoxContainer.new()
	carousel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	carousel_row.add_theme_constant_override("separation", 12)
	root_vbox.add_child(carousel_row)

	_left_arrow = _make_arrow_button("◀")
	_left_arrow.pressed.connect(_on_prev_character)
	carousel_row.add_child(_left_arrow)

	var preview_panel = PanelContainer.new()
	var preview_w = clamp(vp.x * 0.45, 280.0, 500.0)
	var preview_h = clamp(vp.y * 0.35, 220.0, 360.0)
	preview_panel.custom_minimum_size = Vector2(preview_w, preview_h)
	preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.96, 0.98, 1.0, 0.95)
	ps.corner_radius_top_left = 18
	ps.corner_radius_top_right = 18
	ps.corner_radius_bottom_left = 18
	ps.corner_radius_bottom_right = 18
	preview_panel.add_theme_stylebox_override("panel", ps)
	carousel_row.add_child(preview_panel)

	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(preview_w, preview_h)
	_preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_holder.clip_contents = false
	preview_panel.add_child(_preview_holder)

	_right_arrow = _make_arrow_button("▶")
	_right_arrow.pressed.connect(_on_next_character)
	carousel_row.add_child(_right_arrow)

	# Character name
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_override("font", UI_FONT)
	_name_label.add_theme_font_size_override("font_size", 30)
	_name_label.add_theme_color_override("font_color", Color(0.16, 0.28, 0.42))
	root_vbox.add_child(_name_label)

	# Accessory label
	_acc_label = Label.new()
	_acc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_acc_label.add_theme_font_override("font", UI_FONT)
	_acc_label.add_theme_font_size_override("font_size", 20)
	_acc_label.add_theme_color_override("font_color", Color(0.24, 0.36, 0.52))
	root_vbox.add_child(_acc_label)

	# Accessory scroll
	var acc_scroll = ScrollContainer.new()
	acc_scroll.custom_minimum_size = Vector2(0, 60)
	acc_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	acc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(acc_scroll)

	_accessory_grid = HBoxContainer.new()
	_accessory_grid.add_theme_constant_override("separation", 8)
	_accessory_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	acc_scroll.add_child(_accessory_grid)

	for acc in ACCESSORIES:
		var btn = Button.new()
		var acc_id := str(acc.id)
		btn.text = "%s %s" % [acc.icon, _get_accessory_name(acc_id, str(acc.name))]
		btn.custom_minimum_size = Vector2(100, 46)
		btn.toggle_mode = true
		btn.add_theme_font_override("font", UI_FONT)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_on_accessory_pressed.bind(acc_id))
		_accessory_grid.add_child(btn)
		_accessory_buttons[acc_id] = btn

	# Status label
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_override("font", UI_FONT)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.26, 0.38, 0.54))
	_status_label.text = _loc(
		"character_status_pick_apply",
		"Pick a character, equip accessories, then apply."
	)
	root_vbox.add_child(_status_label)

	# Action buttons
	var action_row = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 14)
	root_vbox.add_child(action_row)

	_save_button = Button.new()
	_save_button.custom_minimum_size = Vector2(200, 50)
	_save_button.add_theme_font_override("font", UI_FONT)
	_save_button.add_theme_font_size_override("font_size", 20)
	_save_button.text = _loc("apply_look", "APPLY LOOK")
	_save_button.pressed.connect(_on_apply_pressed)
	action_row.add_child(_save_button)

	_back_button = Button.new()
	_back_button.custom_minimum_size = Vector2(200, 50)
	_back_button.add_theme_font_override("font", UI_FONT)
	_back_button.add_theme_font_size_override("font_size", 20)
	_back_button.text = _loc("back", "← BACK")
	_back_button.pressed.connect(_on_back_pressed)
	action_row.add_child(_back_button)

	_setup_interaction_feedback()
	_apply_ui_theme()


func _make_arrow_button(symbol: String) -> Button:
	var btn = Button.new()
	btn.text = symbol
	btn.custom_minimum_size = Vector2(56, 56)
	btn.add_theme_font_override("font", UI_FONT)
	btn.add_theme_font_size_override("font_size", 32)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.25, 0.40, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn


func _on_prev_character() -> void:
	if _is_sliding:
		return
	if AudioManager:
		AudioManager.play_click()
	_carousel_index = (
		(_carousel_index - 1 + CHARACTER_PRESETS.size())
		% CHARACTER_PRESETS.size()
	)
	_update_carousel(-1)


func _on_next_character() -> void:
	if _is_sliding:
		return
	if AudioManager:
		AudioManager.play_click()
	_carousel_index = (_carousel_index + 1) % CHARACTER_PRESETS.size()
	_update_carousel(1)


func _update_carousel(direction: int) -> void:
	var preset = CHARACTER_PRESETS[_carousel_index]
	var char_id = str(preset.id)
	var unlocked = _is_unlocked(char_id)
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
	var holder_size = _preview_holder.size
	if holder_size == Vector2.ZERO:
		holder_size = _preview_holder.custom_minimum_size
	var center = Vector2(holder_size.x * 0.5, holder_size.y * 0.5)
	var acc_id = _get_current_accessory(char_id)
	var hat_str = str(preset.hat) if unlocked else ""
	if acc_id != "character_default" and acc_id != "":
		var icon = _get_accessory_icon(acc_id)
		if icon != "":
			hat_str = icon
	var old_node = _preview_node
	_preview_node = _build_procedural_droplet(preset.color, hat_str, unlocked)
	_preview_node.position = center
	_preview_node.scale = Vector2(2.2, 2.2)
	if not unlocked:
		_preview_node.modulate = Color(0.5, 0.5, 0.5, 0.7)
	_preview_holder.add_child(_preview_node)
	if direction != 0:
		_is_sliding = true
		var slide_offset = 220.0 * sign(direction)
		_preview_node.position.x = center.x + slide_offset
		_preview_node.modulate.a = 0.0
		var slide_tw = create_tween()
		slide_tw.tween_property(
			_preview_node, "position:x", center.x, 0.22
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		slide_tw.parallel().tween_property(
			_preview_node, "modulate:a", 1.0 if unlocked else 0.7, 0.15
		)
		if old_node and is_instance_valid(old_node):
			var exit_tw = create_tween()
			exit_tw.tween_property(
				old_node, "position:x", center.x - slide_offset, 0.18
			).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			exit_tw.parallel().tween_property(old_node, "modulate:a", 0.0, 0.12)
			exit_tw.tween_callback(old_node.queue_free)
		slide_tw.tween_callback(func(): _is_sliding = false)
	else:
		if old_node and is_instance_valid(old_node):
			old_node.queue_free()
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(
		_preview_node, "position:y", center.y - 5, 0.7
	).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(
		_preview_node, "position:y", center.y, 0.7
	).set_trans(Tween.TRANS_SINE)
	_name_label.text = "%s %s" % [preset.hat, preset.name]
	var equipped_acc = _get_current_accessory(char_id)
	var acc_name = _loc("accessory_default", "Default")
	for a in ACCESSORIES:
		if str(a.id) == equipped_acc:
			acc_name = "%s %s" % [a.icon, _get_accessory_name(str(a.id), str(a.name))]
			break
	if unlocked:
		_acc_label.text = _fmt_loc(
			"character_accessory_of",
			"%s's Accessory: %s",
			[preset.name, acc_name]
		)
		_status_label.text = _fmt_loc(
			"character_ready_customize",
			"%s - Ready to customise",
			[preset.name]
		)
		_save_button.disabled = false
	else:
		_acc_label.text = _fmt_loc(
			"character_unlock_in_shop",
			"Unlock %s in the Shop first",
			[preset.name]
		)
		_status_label.text = _fmt_loc(
			"character_locked_buy_shop",
			"%s - Locked (buy in Shop first)",
			[preset.name]
		)
		_save_button.disabled = true
	_update_accessory_buttons()


func _get_current_accessory(char_id: String) -> String:
	if SaveManager and SaveManager.has_method("get_character_accessory"):
		return str(SaveManager.get_character_accessory(char_id))
	return "character_default"


func _on_accessory_pressed(acc_id: String) -> void:
	if AudioManager:
		AudioManager.play_click()
	var preset = CHARACTER_PRESETS[_carousel_index]
	var char_id = str(preset.id)
	if not _is_unlocked(char_id):
		_status_label.text = _fmt_loc(
			"character_unlock_first",
			"Unlock %s first!",
			[preset.name]
		)
		_update_accessory_buttons()
		return
	if not _is_accessory_unlocked(acc_id):
		_status_label.text = _loc(
			"character_buy_accessory_first",
			"Buy this accessory in the Shop first!"
		)
		_update_accessory_buttons()
		return
	if SaveManager and SaveManager.has_method("set_character_accessory"):
		SaveManager.set_character_accessory(char_id, acc_id)
	_status_label.text = _fmt_loc(
		"character_now_wears",
		"%s now wears %s!",
		[preset.name, _get_accessory_display(acc_id)]
	)
	_update_accessory_buttons()
	_update_carousel(0)


func _get_accessory_display(acc_id: String) -> String:
	for a in ACCESSORIES:
		if str(a.id) == acc_id:
			return "%s %s" % [a.icon, _get_accessory_name(str(a.id), str(a.name))]
	return _loc("accessory_default", "Default")


func _update_accessory_buttons() -> void:
	var preset = CHARACTER_PRESETS[_carousel_index]
	var char_id = str(preset.id)
	var current_acc = _get_current_accessory(char_id)
	for acc_id in _accessory_buttons:
		var btn = _accessory_buttons[acc_id] as Button
		var owned = _is_accessory_unlocked(acc_id)
		btn.disabled = not owned
		btn.button_pressed = (acc_id == current_acc)
		if owned:
			btn.modulate = Color(1, 1, 1, 1)
		else:
			btn.modulate = Color(0.6, 0.6, 0.6, 0.8)


func _is_accessory_unlocked(acc_id: String) -> bool:
	if acc_id == "character_default":
		return true
	if SaveManager and SaveManager.has_method("is_accessory_unlocked"):
		return SaveManager.is_accessory_unlocked(acc_id)
	return false


func _on_apply_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	var preset = CHARACTER_PRESETS[_carousel_index]
	var char_id = str(preset.id)
	if not _is_unlocked(char_id):
		_status_label.text = _loc(
			"character_locked_buy_first",
			"Character is locked. Buy it in the Shop first."
		)
		return
	if SaveManager:
		if SaveManager.has_method("set_selected_character"):
			SaveManager.set_selected_character(char_id)
		var acc = _get_current_accessory(char_id)
		if SaveManager.has_method("set_selected_accessory"):
			SaveManager.set_selected_accessory(acc)
		if SaveManager.has_method("save_all_data"):
			SaveManager.save_all_data()
	_status_label.text = _fmt_loc(
		"character_saved_main",
		"Saved! %s will appear on the main screen.",
		[preset.name]
	)


func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if GameManager and GameManager.has_method("transition_to_scene"):
		GameManager.transition_to_scene("res://scenes/ui/InitialScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")


func _build_procedural_droplet(color: Color, hat: String, _unlocked: bool) -> Node2D:
	var root = Node2D.new()
	var body = Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(0, -40), Vector2(18, -26),
		Vector2(26, -4), Vector2(22, 14),
		Vector2(12, 28), Vector2(0, 32),
		Vector2(-12, 28), Vector2(-22, 14),
		Vector2(-26, -4), Vector2(-18, -26),
	])
	body.color = color
	root.add_child(body)
	var hl = Polygon2D.new()
	hl.polygon = PackedVector2Array([
		Vector2(-10, -30), Vector2(-6, -22), Vector2(-14, -18),
	])
	hl.color = Color(1, 1, 1, 0.35)
	root.add_child(hl)
	for xoff in [-9, 9]:
		var ew = Polygon2D.new()
		ew.polygon = _oval(5.5, 6, 8)
		ew.position = Vector2(xoff, -6)
		ew.color = Color.WHITE
		root.add_child(ew)
		var pupil = Polygon2D.new()
		pupil.polygon = _oval(2.8, 3, 6)
		pupil.position = Vector2(xoff, -5)
		pupil.color = Color.BLACK
		root.add_child(pupil)
	var smile = Line2D.new()
	smile.points = PackedVector2Array([
		Vector2(-8, 6), Vector2(-3, 12), Vector2(3, 12), Vector2(8, 6),
	])
	smile.width = 2.0
	smile.default_color = Color(0.15, 0.15, 0.15)
	root.add_child(smile)
	for side in [-1, 1]:
		var arm = Line2D.new()
		arm.name = "LeftArm" if side < 0 else "RightArm"
		arm.points = PackedVector2Array([
			Vector2(side * 24, -2),
			Vector2(side * 36, -14),
			Vector2(side * 40, -18),
		])
		arm.width = 4.0
		arm.default_color = color.darkened(0.15)
		arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arm.end_cap_mode = Line2D.LINE_CAP_ROUND
		root.add_child(arm)
	for side in [-1, 1]:
		var leg = Line2D.new()
		leg.name = "LeftLeg" if side < 0 else "RightLeg"
		leg.points = PackedVector2Array([
			Vector2(side * 8, 30),
			Vector2(side * 12, 44),
			Vector2(side * 14, 50),
		])
		leg.width = 4.0
		leg.default_color = color.darkened(0.15)
		leg.begin_cap_mode = Line2D.LINE_CAP_ROUND
		leg.end_cap_mode = Line2D.LINE_CAP_ROUND
		root.add_child(leg)
	if hat != "":
		var hat_lbl = Label.new()
		hat_lbl.name = "HatLabel"
		hat_lbl.text = hat
		hat_lbl.position = Vector2(-14, -66)
		hat_lbl.add_theme_font_size_override("font_size", 26)
		root.add_child(hat_lbl)
	return root


func _get_accessory_icon(acc_id: String) -> String:
	if SaveManager and SaveManager.has_method("get_accessory_icon"):
		return str(SaveManager.get_accessory_icon(acc_id))
	for acc in ACCESSORIES:
		if str(acc.id) == acc_id:
			return str(acc.icon)
	return ""


func _oval(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in range(segments):
		var angle = i * TAU / segments
		pts.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return pts


func _is_unlocked(char_id: String) -> bool:
	if char_id == "droppy_blue":
		return true
	if SaveManager and SaveManager.has_method("is_character_unlocked"):
		return SaveManager.is_character_unlocked(char_id)
	return false


func _update_translations() -> void:
	if _title_label:
		_title_label.text = (
			Localization.get_text("character_customization")
			if Localization
			else "Character Customization"
		)
	if _save_button:
		_save_button.text = _loc("apply_look", "APPLY LOOK")
	if _back_button:
		_back_button.text = _loc("back", "← BACK")
	_refresh_accessory_button_texts()


func _on_language_changed(_new_lang: String) -> void:
	_update_translations()
	_update_carousel(0)


func _loc(key: String, fallback: String) -> String:
	if Localization:
		var translated = Localization.get_text(key)
		if translated != key:
			return translated
	return fallback


func _fmt_loc(key: String, fallback: String, values: Array) -> String:
	var pattern = _loc(key, fallback)
	if values.is_empty():
		return pattern
	if values.size() == 1:
		return pattern % values[0]
	return pattern % values


func _get_accessory_name(acc_id: String, fallback: String) -> String:
	var key := str(ACCESSORY_NAME_KEYS.get(acc_id, ""))
	if key.is_empty():
		return fallback
	return _loc(key, fallback)


func _refresh_accessory_button_texts() -> void:
	for acc in ACCESSORIES:
		var acc_id := str(acc.id)
		if not _accessory_buttons.has(acc_id):
			continue
		var btn := _accessory_buttons[acc_id] as Button
		if not btn:
			continue
		btn.text = "%s %s" % [str(acc.icon), _get_accessory_name(acc_id, str(acc.name))]


func _on_theme_changed(_is_dark: bool) -> void:
	_apply_background_theme()
	_apply_ui_theme()
