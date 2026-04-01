extends Control

# Unlockable characters data
var characters_data = [
	{
		"id": "droppy_blue", "name": "Droppy", "cost": 0,
		"unlocked": true, "color": Color(0.3, 0.6, 1.0)
	},
	{"id": "pinky", "name": "Pinky", "cost": 50, "unlocked": false, "color": Color(1.0, 0.6, 0.8)},
	{"id": "minty", "name": "Minty", "cost": 100, "unlocked": false, "color": Color(0.6, 1.0, 0.8)},
	{"id": "sunny", "name": "Sunny", "cost": 150, "unlocked": false, "color": Color(1.0, 0.9, 0.4)},
	{"id": "lavvy", "name": "Lavvy", "cost": 200, "unlocked": false, "color": Color(0.8, 0.6, 1.0)},
	{
		"id": "peachy", "name": "Peachy", "cost": 300,
		"unlocked": false, "color": Color(1.0, 0.8, 0.7)
	},
	{
		"id": "cyanny", "name": "Cyanny", "cost": 400,
		"unlocked": false, "color": Color(0.4, 1.0, 1.0)
	},
	{"id": "coral", "name": "Coral", "cost": 500, "unlocked": false, "color": Color(1.0, 0.5, 0.5)},
]

# Unlockable minigames data
var minigames_data = [
	{"id": "catch_rain", "name": "Catch Rain", "cost": 0, "unlocked": true, "icon": "🌧️"},
	{"id": "pipe_puzzle", "name": "Pipe Puzzle", "cost": 0, "unlocked": true, "icon": "🔧"},
	{"id": "water_sorting", "name": "Water Sort", "cost": 100, "unlocked": false, "icon": "🧪"},
	{"id": "leak_fix", "name": "Fix Leaks", "cost": 200, "unlocked": false, "icon": "💧"},
	{"id": "water_quiz", "name": "Water Quiz", "cost": 300, "unlocked": false, "icon": "❓"},
	{"id": "bucket_relay", "name": "Bucket Relay", "cost": 400, "unlocked": false, "icon": "🪣"},
]

var current_tab = "characters"
var waterpark_layer: Node2D
var grid_container: GridContainer
var tab_characters: Button
var tab_minigames: Button
var currency_label: Label

func _ready() -> void:
	_sync_from_save_manager()
	_setup_waterpark_background()
	_setup_ui()
	_update_display()
	
	if Localization:
		Localization.language_changed.connect(_on_language_changed)

func _sync_from_save_manager() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		return

	for i in range(characters_data.size()):
		if characters_data[i].cost == 0:
			characters_data[i].unlocked = true
		else:
			characters_data[i].unlocked = save_mgr.is_character_unlocked(characters_data[i].id)

	for i in range(minigames_data.size()):
		if minigames_data[i].cost == 0:
			minigames_data[i].unlocked = true
		else:
			minigames_data[i].unlocked = save_mgr.is_minigame_unlocked(minigames_data[i].id)

	if GameManager:
		GameManager.water_droplets = save_mgr.get_droplets()

func _setup_waterpark_background() -> void:
	# Sky gradient
	var sky = ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.color = Color(0.5, 0.85, 1.0)
	sky.z_index = -20
	add_child(sky)
	
	# Create waterpark layer
	waterpark_layer = Node2D.new()
	waterpark_layer.z_index = -10
	add_child(waterpark_layer)
	
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1920, 1080)
	
	_draw_pool_bg(viewport_size)
	_draw_decorations(viewport_size)

func _draw_pool_bg(screen_size: Vector2) -> void:
	# Ground
	var ground = Polygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2(0, screen_size.y * 0.7),
		Vector2(screen_size.x, screen_size.y * 0.7),
		Vector2(screen_size.x, screen_size.y),
		Vector2(0, screen_size.y)
	])
	ground.color = Color(0.6, 0.85, 0.5)
	waterpark_layer.add_child(ground)
	
	# Pool
	var pool = Polygon2D.new()
	var pool_points = []
	var pool_center = Vector2(screen_size.x * 0.5, screen_size.y * 0.82)
	for i in range(20):
		var angle = i * TAU / 20
		var rx = screen_size.x * 0.35
		var ry = screen_size.y * 0.12
		pool_points.append(pool_center + Vector2(cos(angle) * rx, sin(angle) * ry))
	pool.polygon = PackedVector2Array(pool_points)
	pool.color = Color(0.3, 0.7, 0.95, 0.8)
	waterpark_layer.add_child(pool)
	
	# Pool edge
	var pool_edge = Line2D.new()
	pool_edge.points = PackedVector2Array(pool_points + [pool_points[0]])
	pool_edge.width = 12
	pool_edge.default_color = Color(0.95, 0.9, 0.8)
	waterpark_layer.add_child(pool_edge)

func _draw_decorations(screen_size: Vector2) -> void:
	# Palm trees on sides
	_draw_palm_tree(Vector2(screen_size.x * 0.08, screen_size.y * 0.68))
	_draw_palm_tree(Vector2(screen_size.x * 0.92, screen_size.y * 0.68))
	
	# Umbrellas
	_draw_umbrella(Vector2(screen_size.x * 0.15, screen_size.y * 0.72), Color(1.0, 0.4, 0.4))
	_draw_umbrella(Vector2(screen_size.x * 0.85, screen_size.y * 0.72), Color(0.4, 0.8, 1.0))
	
	# Pool floats
	_draw_pool_float(Vector2(screen_size.x * 0.35, screen_size.y * 0.8), Color(1.0, 0.6, 0.8))
	_draw_pool_float(Vector2(screen_size.x * 0.65, screen_size.y * 0.83), Color(1.0, 0.9, 0.4))

func _draw_palm_tree(pos: Vector2) -> void:
	# Trunk
	var trunk = Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(-12, 0), Vector2(12, 0), Vector2(8, -120), Vector2(-8, -120)
	])
	trunk.color = Color(0.55, 0.35, 0.2)
	trunk.position = pos
	waterpark_layer.add_child(trunk)
	
	# Leaves
	for i in range(5):
		var leaf = Polygon2D.new()
		var angle = -PI/2 + (i - 2) * 0.5
		var leaf_points = []
		for j in range(8):
			var t = j / 7.0
			var lx = cos(angle) * t * 80
			var ly = sin(angle) * t * 80 - 120
			var wave = sin(t * PI * 2) * 8
			leaf_points.append(Vector2(lx + wave, ly))
		leaf_points.append(Vector2(0, -120))
		leaf.polygon = PackedVector2Array(leaf_points)
		leaf.color = Color(0.2, 0.7, 0.3)
		leaf.position = pos
		waterpark_layer.add_child(leaf)

func _draw_umbrella(pos: Vector2, color: Color) -> void:
	# Pole
	var pole = Line2D.new()
	pole.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -80)])
	pole.width = 6
	pole.default_color = Color(0.9, 0.9, 0.85)
	pole.position = pos
	waterpark_layer.add_child(pole)
	
	# Canopy
	var canopy = Polygon2D.new()
	var canopy_points = [Vector2(0, -80)]
	for i in range(9):
		var angle = PI + i * PI / 8
		canopy_points.append(Vector2(cos(angle) * 50, sin(angle) * 25 - 80))
	canopy.polygon = PackedVector2Array(canopy_points)
	canopy.color = color
	canopy.position = pos
	waterpark_layer.add_child(canopy)

func _draw_pool_float(pos: Vector2, color: Color) -> void:
	var float_ring = Polygon2D.new()
	var outer_points = []
	var inner_points = []
	for i in range(16):
		var angle = i * TAU / 16
		outer_points.append(Vector2(cos(angle) * 25, sin(angle) * 15))
		inner_points.insert(0, Vector2(cos(angle) * 12, sin(angle) * 8))
	float_ring.polygon = PackedVector2Array(outer_points)
	float_ring.color = color
	float_ring.position = pos
	waterpark_layer.add_child(float_ring)

func _setup_ui() -> void:
	# Main UI container with semi-transparent panel
	var main_panel = PanelContainer.new()
	main_panel.name = "MainPanel"
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(1, 1, 1, 0.85)
	panel_style.corner_radius_top_left = 30
	panel_style.corner_radius_top_right = 30
	panel_style.corner_radius_bottom_left = 30
	panel_style.corner_radius_bottom_right = 30
	panel_style.shadow_color = Color(0, 0, 0, 0.3)
	panel_style.shadow_size = 15
	main_panel.add_theme_stylebox_override("panel", panel_style)
	main_panel.custom_minimum_size = Vector2(800, 550)
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(main_panel)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	main_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Title row
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 20)
	vbox.add_child(title_row)
	
	var title = Label.new()
	title.text = "🎁 UNLOCKABLES"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.2, 0.2, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	
	# Currency display
	currency_label = Label.new()
	currency_label.text = "💧 " + str(GameManager.water_droplets if GameManager else 500)
	currency_label.add_theme_font_size_override("font_size", 32)
	currency_label.add_theme_color_override("font_color", Color(0.2, 0.5, 0.9))
	title_row.add_child(currency_label)
	
	# Tab buttons
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tab_row)
	
	tab_characters = _create_tab_button("👤 Characters", true)
	tab_characters.pressed.connect(_on_characters_tab)
	tab_row.add_child(tab_characters)
	
	tab_minigames = _create_tab_button("🎮 Minigames", false)
	tab_minigames.pressed.connect(_on_minigames_tab)
	tab_row.add_child(tab_minigames)
	
	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	vbox.add_child(sep)
	
	# Scrollable grid area
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	grid_container = GridContainer.new()
	grid_container.columns = 4
	grid_container.add_theme_constant_override("h_separation", 20)
	grid_container.add_theme_constant_override("v_separation", 20)
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid_container)
	
	# Back button
	var back_btn = Button.new()
	back_btn.text = "⬅️ BACK"
	back_btn.custom_minimum_size = Vector2(200, 60)
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color(0.2, 0.6, 0.95)
	back_style.corner_radius_top_left = 15
	back_style.corner_radius_top_right = 15
	back_style.corner_radius_bottom_left = 15
	back_style.corner_radius_bottom_right = 15
	back_style.border_width_bottom = 6
	back_style.border_color = Color(0.1, 0.4, 0.7)
	back_btn.add_theme_stylebox_override("normal", back_style)
	back_btn.add_theme_stylebox_override("hover", back_style)
	back_btn.add_theme_stylebox_override("pressed", back_style)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

func _create_tab_button(text: String, active: bool) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 50)
	btn.add_theme_font_size_override("font_size", 22)
	
	var style = StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.2, 0.6, 0.95)
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		style.bg_color = Color(0.9, 0.9, 0.9)
		btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	return btn

func _update_tab_styles() -> void:
	var active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.2, 0.6, 0.95)
	active_style.corner_radius_top_left = 12
	active_style.corner_radius_top_right = 12
	active_style.corner_radius_bottom_left = 12
	active_style.corner_radius_bottom_right = 12
	
	var inactive_style = StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.9, 0.9, 0.9)
	inactive_style.corner_radius_top_left = 12
	inactive_style.corner_radius_top_right = 12
	inactive_style.corner_radius_bottom_left = 12
	inactive_style.corner_radius_bottom_right = 12
	
	if current_tab == "characters":
		tab_characters.add_theme_stylebox_override("normal", active_style)
		tab_characters.add_theme_stylebox_override("hover", active_style)
		tab_characters.add_theme_color_override("font_color", Color.WHITE)
		tab_minigames.add_theme_stylebox_override("normal", inactive_style)
		tab_minigames.add_theme_stylebox_override("hover", inactive_style)
		tab_minigames.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	else:
		tab_minigames.add_theme_stylebox_override("normal", active_style)
		tab_minigames.add_theme_stylebox_override("hover", active_style)
		tab_minigames.add_theme_color_override("font_color", Color.WHITE)
		tab_characters.add_theme_stylebox_override("normal", inactive_style)
		tab_characters.add_theme_stylebox_override("hover", inactive_style)
		tab_characters.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))

func _update_display() -> void:
	# Clear existing items
	for child in grid_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if current_tab == "characters":
		_show_characters()
	else:
		_show_minigames()

func _show_characters() -> void:
	for char_data in characters_data:
		var card = _create_character_card(char_data)
		grid_container.add_child(card)

func _show_minigames() -> void:
	for game_data in minigames_data:
		var card = _create_minigame_card(game_data)
		grid_container.add_child(card)

func _create_character_card(data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 180)
	
	var card_style = StyleBoxFlat.new()
	if data.unlocked:
		card_style.bg_color = Color(0.95, 1.0, 0.95)
		card_style.border_color = Color(0.4, 0.8, 0.5)
	else:
		card_style.bg_color = Color(0.92, 0.92, 0.92)
		card_style.border_color = Color(0.7, 0.7, 0.7)
	card_style.corner_radius_top_left = 15
	card_style.corner_radius_top_right = 15
	card_style.corner_radius_bottom_left = 15
	card_style.corner_radius_bottom_right = 15
	card_style.border_width_left = 3
	card_style.border_width_right = 3
	card_style.border_width_top = 3
	card_style.border_width_bottom = 3
	card.add_theme_stylebox_override("panel", card_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)
	
	# Character preview (droplet shape)
	var preview = Control.new()
	preview.custom_minimum_size = Vector2(80, 80)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(preview)
	
	# Draw droplet character on preview
	var char_display = _create_mini_droplet(data.color, data.unlocked)
	char_display.position = Vector2(40, 45)
	preview.add_child(char_display)
	
	# Name
	var name_label = Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not data.unlocked:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(name_label)
	
	# Cost/Status
	if data.unlocked:
		var status = Label.new()
		status.text = "✅ OWNED"
		status.add_theme_font_size_override("font_size", 14)
		status.add_theme_color_override("font_color", Color(0.3, 0.7, 0.4))
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(status)
	else:
		var buy_btn = Button.new()
		buy_btn.text = "💧 " + str(data.cost)
		buy_btn.custom_minimum_size = Vector2(100, 35)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.3, 0.7, 1.0)
		btn_style.corner_radius_top_left = 8
		btn_style.corner_radius_top_right = 8
		btn_style.corner_radius_bottom_left = 8
		btn_style.corner_radius_bottom_right = 8
		buy_btn.add_theme_stylebox_override("normal", btn_style)
		buy_btn.add_theme_stylebox_override("hover", btn_style)
		buy_btn.add_theme_font_size_override("font_size", 16)
		buy_btn.add_theme_color_override("font_color", Color.WHITE)
		buy_btn.pressed.connect(_on_buy_character.bind(data.id))
		vbox.add_child(buy_btn)
	
	return card

func _create_mini_droplet(color: Color, unlocked: bool) -> Node2D:
	var droplet = Node2D.new()
	
	# Body
	var body = Polygon2D.new()
	var body_points = []
	# Droplet shape
	body_points.append(Vector2(0, -25))  # Top point
	for i in range(12):
		var angle = -PI/2 + PI * (i + 1) / 12
		body_points.append(Vector2(cos(angle) * 20, sin(angle) * 18 + 5))
	body.polygon = PackedVector2Array(body_points)
	body.color = color if unlocked else Color(0.6, 0.6, 0.6)
	droplet.add_child(body)
	
	# Eyes
	for i in [-1, 1]:
		var eye_white = Polygon2D.new()
		var eye_pts = []
		for j in range(8):
			var angle = j * TAU / 8
			eye_pts.append(Vector2(i * 7 + cos(angle) * 5, sin(angle) * 6))
		eye_white.polygon = PackedVector2Array(eye_pts)
		eye_white.color = Color.WHITE
		droplet.add_child(eye_white)
		
		var pupil = Polygon2D.new()
		var pupil_pts = []
		for j in range(8):
			var angle = j * TAU / 8
			pupil_pts.append(Vector2(i * 7 + cos(angle) * 2.5, sin(angle) * 3))
		pupil.polygon = PackedVector2Array(pupil_pts)
		pupil.color = Color(0.1, 0.1, 0.1)
		droplet.add_child(pupil)
	
	# Smile
	var smile = Line2D.new()
	var smile_pts = []
	for i in range(7):
		var t = i / 6.0 - 0.5
		smile_pts.append(Vector2(t * 12, 8 + t * t * 6))
	smile.points = PackedVector2Array(smile_pts)
	smile.width = 2
	smile.default_color = Color(0.2, 0.2, 0.2)
	droplet.add_child(smile)
	
	# Lock overlay if not unlocked
	if not unlocked:
		var lock = Label.new()
		lock.text = "🔒"
		lock.add_theme_font_size_override("font_size", 24)
		lock.position = Vector2(-12, -12)
		droplet.add_child(lock)
	
	return droplet

func _create_minigame_card(data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 180)
	
	var card_style = StyleBoxFlat.new()
	if data.unlocked:
		card_style.bg_color = Color(0.95, 0.98, 1.0)
		card_style.border_color = Color(0.4, 0.7, 0.9)
	else:
		card_style.bg_color = Color(0.92, 0.92, 0.92)
		card_style.border_color = Color(0.7, 0.7, 0.7)
	card_style.corner_radius_top_left = 15
	card_style.corner_radius_top_right = 15
	card_style.corner_radius_bottom_left = 15
	card_style.corner_radius_bottom_right = 15
	card_style.border_width_left = 3
	card_style.border_width_right = 3
	card_style.border_width_top = 3
	card_style.border_width_bottom = 3
	card.add_theme_stylebox_override("panel", card_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)
	
	# Icon
	var icon = Label.new()
	icon.text = data.icon if data.unlocked else "🔒"
	icon.add_theme_font_size_override("font_size", 48)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon)
	
	# Name
	var name_label = Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not data.unlocked:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(name_label)
	
	# Cost/Status
	if data.unlocked:
		var status = Label.new()
		status.text = "✅ UNLOCKED"
		status.add_theme_font_size_override("font_size", 14)
		status.add_theme_color_override("font_color", Color(0.3, 0.7, 0.4))
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(status)
	else:
		var buy_btn = Button.new()
		buy_btn.text = "💧 " + str(data.cost)
		buy_btn.custom_minimum_size = Vector2(100, 35)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.3, 0.7, 1.0)
		btn_style.corner_radius_top_left = 8
		btn_style.corner_radius_top_right = 8
		btn_style.corner_radius_bottom_left = 8
		btn_style.corner_radius_bottom_right = 8
		buy_btn.add_theme_stylebox_override("normal", btn_style)
		buy_btn.add_theme_stylebox_override("hover", btn_style)
		buy_btn.add_theme_font_size_override("font_size", 16)
		buy_btn.add_theme_color_override("font_color", Color.WHITE)
		buy_btn.pressed.connect(_on_buy_minigame.bind(data.id))
		vbox.add_child(buy_btn)
	
	return card

func _on_characters_tab() -> void:
	if AudioManager:
		AudioManager.play_click()
	current_tab = "characters"
	_update_tab_styles()
	_update_display()

func _on_minigames_tab() -> void:
	if AudioManager:
		AudioManager.play_click()
	current_tab = "minigames"
	_update_tab_styles()
	_update_display()

func _on_buy_character(char_id: String) -> void:
	if AudioManager:
		AudioManager.play_click()
	var save_mgr = get_node_or_null("/root/SaveManager")
	for i in range(characters_data.size()):
		if characters_data[i].id == char_id:
			var cost = characters_data[i].cost
			if save_mgr:
				if save_mgr.spend_droplets(cost):
					save_mgr.unlock_character(char_id)
					characters_data[i].unlocked = true
					if GameManager:
						GameManager.water_droplets = save_mgr.get_droplets()
				else:
					_show_insufficient_funds()
			else:
				var current_currency = GameManager.water_droplets if GameManager else 0
				if current_currency >= cost:
					if GameManager:
						GameManager.water_droplets -= cost
					characters_data[i].unlocked = true
				else:
					_show_insufficient_funds()
			_update_currency_display()
			_update_display()
			break

func _on_buy_minigame(game_id: String) -> void:
	if AudioManager:
		AudioManager.play_click()
	var save_mgr = get_node_or_null("/root/SaveManager")
	for i in range(minigames_data.size()):
		if minigames_data[i].id == game_id:
			var cost = minigames_data[i].cost
			if save_mgr:
				if save_mgr.spend_droplets(cost):
					save_mgr.unlock_minigame(game_id)
					minigames_data[i].unlocked = true
					if GameManager:
						GameManager.water_droplets = save_mgr.get_droplets()
					# Refresh available rotation immediately after unlock.
					if GameManager and GameManager.has_method("refresh_available_minigames"):
						GameManager.refresh_available_minigames()
				else:
					_show_insufficient_funds()
			else:
				var current_currency = GameManager.water_droplets if GameManager else 0
				if current_currency >= cost:
					if GameManager:
						GameManager.water_droplets -= cost
					minigames_data[i].unlocked = true
				else:
					_show_insufficient_funds()
			_update_currency_display()
			_update_display()
			break

func _update_currency_display() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	var current = 0
	if save_mgr:
		current = save_mgr.get_droplets()
	elif GameManager:
		current = GameManager.water_droplets
	currency_label.text = "💧 " + str(current)

func _show_insufficient_funds() -> void:
	# Create a quick popup
	var popup = Label.new()
	popup.text = "❌ Not enough drops!"
	popup.add_theme_font_size_override("font_size", 28)
	popup.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.position.y -= 50
	add_child(popup)
	
	var tween = create_tween()
	tween.tween_property(popup, "modulate:a", 0.0, 1.5)
	tween.tween_callback(popup.queue_free)

func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

func _on_language_changed(_new_lang: String) -> void:
	pass  # Add translations if needed
