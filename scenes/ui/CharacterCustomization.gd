extends Control

@onready var background = $Background
@onready var root_vbox = $CenterContainer/VBoxContainer

const UI_FONT = preload("res://fonts/NTBrickSans.otf")

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


func _ready() -> void:
	await get_tree().process_frame
	_load_state()
	_build_runtime_ui()
	_update_carousel(0)
	_update_accessory_buttons()
	_update_translations()
	if Localization:
		Localization.language_changed.connect(_on_language_changed)
	# Entrance popup animation
	if root_vbox:
		root_vbox.pivot_offset = root_vbox.size * 0.5
		root_vbox.modulate.a = 0.0
		root_vbox.scale = Vector2(0.85, 0.85)
		var tw = create_tween()
		tw.tween_property(root_vbox, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(root_vbox, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _load_state() -> void:
	if SaveManager and SaveManager.has_method("get_selected_character"):
		var sel_id = str(SaveManager.get_selected_character())
		for i in range(CHARACTER_PRESETS.size()):
			if CHARACTER_PRESETS[i].id == sel_id:
				_carousel_index = i
				break


func _build_runtime_ui() -> void:
	background.color = Color(0.10, 0.18, 0.30)
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
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
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
	ps.bg_color = Color(0.92, 0.96, 1.0, 0.95)
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
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	root_vbox.add_child(_name_label)

	# Accessory label
	_acc_label = Label.new()
	_acc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_acc_label.add_theme_font_override("font", UI_FONT)
	_acc_label.add_theme_font_size_override("font_size", 20)
	_acc_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
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
		btn.text = "%s %s" % [acc.icon, acc.name]
		btn.custom_minimum_size = Vector2(100, 46)
		btn.toggle_mode = true
		btn.add_theme_font_override("font", UI_FONT)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_on_accessory_pressed.bind(str(acc.id)))
		_accessory_grid.add_child(btn)
		_accessory_buttons[str(acc.id)] = btn

	# Status label
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_override("font", UI_FONT)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_status_label.text = "Pick a character, equip accessories, then apply."
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
	_save_button.text = "APPLY LOOK"
	_save_button.pressed.connect(_on_apply_pressed)
	action_row.add_child(_save_button)

	_back_button = Button.new()
	_back_button.custom_minimum_size = Vector2(200, 50)
	_back_button.add_theme_font_override("font", UI_FONT)
	_back_button.add_theme_font_size_override("font_size", 20)
	_back_button.text = "← BACK"
	_back_button.pressed.connect(_on_back_pressed)
	action_row.add_child(_back_button)


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
		slide_tw.tween_property(_preview_node, "position:x", center.x, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		slide_tw.parallel().tween_property(_preview_node, "modulate:a", 1.0 if unlocked else 0.7, 0.15)
		if old_node and is_instance_valid(old_node):
			var exit_tw = create_tween()
			exit_tw.tween_property(old_node, "position:x", center.x - slide_offset, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			exit_tw.parallel().tween_property(old_node, "modulate:a", 0.0, 0.12)
			exit_tw.tween_callback(old_node.queue_free)
		slide_tw.tween_callback(func(): _is_sliding = false)
	else:
		if old_node and is_instance_valid(old_node):
			old_node.queue_free()
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_preview_node, "position:y", center.y - 5, 0.7).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_preview_node, "position:y", center.y, 0.7).set_trans(Tween.TRANS_SINE)
	_name_label.text = "%s %s" % [preset.hat, preset.name]
	var equipped_acc = _get_current_accessory(char_id)
	var acc_name = "Default"
	for a in ACCESSORIES:
		if str(a.id) == equipped_acc:
			acc_name = "%s %s" % [a.icon, a.name]
			break
	if unlocked:
		_acc_label.text = "%s's Accessory: %s" % [preset.name, acc_name]
		_status_label.text = "%s - Ready to customise" % preset.name
		_save_button.disabled = false
	else:
		_acc_label.text = "Unlock %s in the Shop first" % preset.name
		_status_label.text = "%s - Locked (buy in Shop first)" % preset.name
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
		_status_label.text = "Unlock %s first!" % preset.name
		_update_accessory_buttons()
		return
	if not _is_accessory_unlocked(acc_id):
		_status_label.text = "Buy this accessory in the Shop first!"
		_update_accessory_buttons()
		return
	if SaveManager and SaveManager.has_method("set_character_accessory"):
		SaveManager.set_character_accessory(char_id, acc_id)
	_status_label.text = "%s now wears %s!" % [preset.name, _get_accessory_display(acc_id)]
	_update_accessory_buttons()
	_update_carousel(0)


func _get_accessory_display(acc_id: String) -> String:
	for a in ACCESSORIES:
		if str(a.id) == acc_id:
			return "%s %s" % [a.icon, a.name]
	return "Default"


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
		_status_label.text = "Character is locked. Buy it in the Shop first."
		return
	if SaveManager:
		if SaveManager.has_method("set_selected_character"):
			SaveManager.set_selected_character(char_id)
		var acc = _get_current_accessory(char_id)
		if SaveManager.has_method("set_selected_accessory"):
			SaveManager.set_selected_accessory(acc)
		if SaveManager.has_method("save_all_data"):
			SaveManager.save_all_data()
	_status_label.text = "Saved! %s will appear on the main screen." % preset.name


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
		_save_button.text = "APPLY LOOK"
	if _back_button:
		_back_button.text = (
			"← " + Localization.get_text("back")
			if Localization
			else "← BACK"
		)


func _on_language_changed(_new_lang: String) -> void:
	_update_translations()
