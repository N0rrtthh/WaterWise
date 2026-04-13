extends Control

## ═══════════════════════════════════════════════════════════════════
## ROADMAP SCREEN - SCROLLABLE WATER JOURNEY MAP
## ═══════════════════════════════════════════════════════════════════
## An interactive scrollable map showing water conservation journey
## Touch/drag to scroll through stages
## ═══════════════════════════════════════════════════════════════════

var stages = [
	{
		"name": "💧 Water Drop Village", 
		"desc": "Learn the basics of water conservation",
		"unlocked": true, "completed": true, "stars": 3,
		"minigames": ["CatchTheRain", "ThirstyPlant"]
	},
	{
		"name": "🌧️ Rainy Day Challenge", 
		"desc": "Collect rainwater before it's wasted",
		"unlocked": true, "completed": true, "stars": 2,
		"minigames": ["CatchTheRain", "BucketRelay"]
	},
	{
		"name": "🚿 Shower Saver Zone", 
		"desc": "Quick showers save gallons!",
		"unlocked": true, "completed": false, "stars": 0,
		"minigames": ["QuickShower", "FixTheLeak"]
	},
	{
		"name": "🪥 Brushing Best", 
		"desc": "Turn off the tap while brushing",
		"unlocked": false, "completed": false, "stars": 0,
		"minigames": ["BrushingChallenge", "TapControl"]
	},
	{
		"name": "🌱 Garden Guardian", 
		"desc": "Water plants efficiently",
		"unlocked": false, "completed": false, "stars": 0,
		"minigames": ["WaterPlant", "DroughtDefense"]
	},
	{
		"name": "🍽️ Kitchen Keeper", 
		"desc": "Save water in the kitchen",
		"unlocked": false, "completed": false, "stars": 0,
		"minigames": ["DishwashingDash", "TapTamer"]
	},
	{
		"name": "🏠 Home Hero", 
		"desc": "Master water saving at home",
		"unlocked": false, "completed": false, "stars": 0,
		"minigames": ["LeakHunter", "MeterMaster"]
	},
	{
		"name": "🌊 Ocean Protector", 
		"desc": "Protect our water sources",
		"unlocked": false, "completed": false, "stars": 0,
		"minigames": ["PollutionPrevention", "RiverRescue"]
	},
	{
		"name": "🏆 Water Master", 
		"desc": "Ultimate water conservation champion!",
		"unlocked": false, "completed": false, "stars": 0,
		"minigames": ["MasterChallenge"]
	},
]

var screen_size: Vector2
var scroll_container: ScrollContainer
var map_content: Control
var total_map_height: float = 0.0
var is_dragging: bool = false
var drag_start_y: float = 0.0
var scroll_start: float = 0.0

# Touch scrolling
var touch_velocity: float = 0.0
var last_touch_y: float = 0.0
var touch_time: float = 0.0

func _ready():
	screen_size = get_viewport_rect().size
	total_map_height = max(1800, stages.size() * 200 + 400)
	
	_create_scroll_container()
	_create_background()
	_create_map_path()
	_create_stage_nodes()
	_create_decorations()
	_create_header()
	_create_back_button()
	_create_scroll_hint()
	
	# Start at top
	scroll_container.scroll_vertical = 0

func _create_scroll_container():
	# Main scroll container
	scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll_container)
	
	# Content container (taller than screen)
	map_content = Control.new()
	map_content.custom_minimum_size = Vector2(screen_size.x, total_map_height)
	scroll_container.add_child(map_content)

func _create_background():
	# Sky gradient background (extends full height)
	var sky = ColorRect.new()
	sky.custom_minimum_size = Vector2(screen_size.x, total_map_height)
	sky.color = Color(0.53, 0.81, 0.98)
	sky.z_index = -100
	map_content.add_child(sky)
	
	# Clouds at various heights
	for i in range(12):
		var cloud = _create_cloud()
		cloud.position = Vector2(
			randf_range(50, screen_size.x - 100),
			randf_range(50, total_map_height - 100)
		)
		cloud.z_index = -90
		map_content.add_child(cloud)
		
		# Gentle cloud drift
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(cloud, "position:x", cloud.position.x + 50, 8.0)
		tween.tween_property(cloud, "position:x", cloud.position.x, 8.0)
	
	# Rolling green terrain along the sides
	_create_terrain()

func _create_terrain():
	# Left terrain
	var left_terrain = Polygon2D.new()
	var left_points: Array[Vector2] = [Vector2(0, 0)]
	for y in range(0, int(total_map_height), 80):
		var x = 30 + sin(y * 0.01) * 40 + randf_range(-10, 10)
		left_points.append(Vector2(x, y))
	left_points.append(Vector2(0, total_map_height))
	left_terrain.polygon = PackedVector2Array(left_points)
	left_terrain.color = Color(0.4, 0.7, 0.4)
	left_terrain.z_index = -50
	map_content.add_child(left_terrain)
	
	# Right terrain
	var right_terrain = Polygon2D.new()
	var right_points: Array[Vector2] = [Vector2(screen_size.x, 0)]
	for y in range(0, int(total_map_height), 80):
		var x = screen_size.x - 30 - sin(y * 0.012 + 2) * 40 - randf_range(-10, 10)
		right_points.append(Vector2(x, y))
	right_points.append(Vector2(screen_size.x, total_map_height))
	right_terrain.polygon = PackedVector2Array(right_points)
	right_terrain.color = Color(0.45, 0.72, 0.45)
	right_terrain.z_index = -50
	map_content.add_child(right_terrain)

func _create_map_path():
	# Winding river/path through the map
	var river = Line2D.new()
	river.width = 60
	river.default_color = Color(0.4, 0.75, 0.95, 0.9)
	river.begin_cap_mode = Line2D.LINE_CAP_ROUND
	river.end_cap_mode = Line2D.LINE_CAP_ROUND
	river.antialiased = true
	
	var path_points: Array[Vector2] = []
	var stage_spacing = (total_map_height - 300) / stages.size()
	
	for i in range(stages.size() + 2):
		var y = 150 + i * stage_spacing
		var x_wave = sin(i * 0.7) * 100
		var x = screen_size.x / 2 + x_wave
		path_points.append(Vector2(x, y))
	
	river.points = PackedVector2Array(path_points)
	river.z_index = -30
	map_content.add_child(river)
	
	# River bank
	var bank = river.duplicate()
	bank.width = 75
	bank.default_color = Color(0.3, 0.6, 0.8, 0.7)
	bank.z_index = -31
	map_content.add_child(bank)
	
	# Dotted path line on river
	var path_line = Line2D.new()
	path_line.width = 8
	path_line.default_color = Color(1, 1, 1, 0.4)
	path_line.points = river.points
	path_line.z_index = -25
	map_content.add_child(path_line)

func _create_stage_nodes():
	var stage_spacing = (total_map_height - 300) / stages.size()
	
	for i in range(stages.size()):
		var stage = stages[i]
		var y = 180 + i * stage_spacing
		var x_wave = sin(i * 0.7) * 100
		var x = screen_size.x / 2 + x_wave
		
		var node = _create_stage_button(stage, i, Vector2(x, y))
		map_content.add_child(node)
		
		# Pop-in animation
		node.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_interval(i * 0.08)
		tween.tween_property(node, "scale", Vector2.ONE, 0.4) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_BACK)

func _create_stage_button(stage: Dictionary, index: int, pos: Vector2) -> Control:
	var container = Control.new()
	container.name = "Stage_%d" % index
	container.position = pos - Vector2(60, 60)
	container.custom_minimum_size = Vector2(120, 120)
	container.z_index = 10
	
	# Visual node
	var visual = Node2D.new()
	visual.position = Vector2(60, 60)
	container.add_child(visual)
	
	# Colors based on status
	var bg_color: Color
	var border_color: Color
	var icon_bg: Color
	
	if stage.completed:
		bg_color = Color(0.3, 0.85, 0.4)
		border_color = Color(0.2, 0.65, 0.3)
		icon_bg = Color(0.25, 0.75, 0.35)
	elif stage.unlocked:
		bg_color = Color(0.3, 0.7, 1.0)
		border_color = Color(0.2, 0.5, 0.8)
		icon_bg = Color(0.25, 0.6, 0.9)
	else:
		bg_color = Color(0.5, 0.5, 0.55)
		border_color = Color(0.4, 0.4, 0.45)
		icon_bg = Color(0.45, 0.45, 0.5)
	
	# Glow for current stage
	if stage.unlocked and not stage.completed:
		var glow = _create_circle(65, Color(1, 1, 0.5, 0.4))
		visual.add_child(glow)
		
		var pulse = create_tween().set_loops()
		pulse.tween_property(glow, "scale", Vector2(1.15, 1.15), 0.7) \
			.set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.7) \
			.set_ease(Tween.EASE_IN_OUT)
	
	# Main circle with border
	var border = _create_circle(55, border_color)
	visual.add_child(border)
	
	var main = _create_circle(48, bg_color)
	visual.add_child(main)
	
	# Inner circle for icon
	var inner = _create_circle(35, icon_bg)
	visual.add_child(inner)
	
	# Stage number or icon
	var icon = Label.new()
	if not stage.unlocked:
		icon.text = "🔒"
		icon.add_theme_font_size_override("font_size", 32)
	else:
		icon.text = str(index + 1)
		icon.add_theme_font_size_override("font_size", 36)
		icon.add_theme_color_override("font_color", Color.WHITE)
	icon.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	icon.add_theme_constant_override("outline_size", 3)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.position = Vector2(-15, -22) + Vector2(60, 60)
	container.add_child(icon)
	
	# Stars
	if stage.completed and stage.stars > 0:
		var stars = Label.new()
		stars.text = "⭐".repeat(stage.stars)
		stars.add_theme_font_size_override("font_size", 14)
		stars.position = Vector2(60 - stage.stars * 9, 100)
		container.add_child(stars)
	
	# Stage name panel (to the side)
	var name_panel = _create_name_panel(stage, index)
	if index % 2 == 0:
		name_panel.position = Vector2(130, 30)
	else:
		name_panel.position = Vector2(-180, 30)
	container.add_child(name_panel)
	
	# Make interactive
	if stage.unlocked:
		var btn = Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(120, 120)
		btn.pressed.connect(func(): _on_stage_pressed(index))
		btn.mouse_entered.connect(func(): _on_stage_hover(container, true))
		btn.mouse_exited.connect(func(): _on_stage_hover(container, false))
		container.add_child(btn)
	
	return container

func _create_name_panel(stage: Dictionary, _index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(160, 60)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 3
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	vbox.add_child(margin)
	
	var inner_vbox = VBoxContainer.new()
	margin.add_child(inner_vbox)
	
	var title = Label.new()
	title.text = stage.name
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.2, 0.3, 0.4))
	inner_vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = stage.desc
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	inner_vbox.add_child(desc)
	
	return panel

func _on_stage_pressed(index: int):
	var stage = stages[index]
	if not stage.unlocked:
		return
	
	print("Stage %d pressed: %s" % [index + 1, stage.name])
	
	# Show stage selection popup or start minigame
	_show_stage_popup(stage, index)

func _show_stage_popup(stage: Dictionary, _index: int):
	# Create popup overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.z_index = 100
	add_child(overlay)
	
	var popup = PanelContainer.new()
	popup.z_index = 101
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.custom_minimum_size = Vector2(350, 300)
	popup.position = screen_size / 2 - Vector2(175, 150)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.97, 1.0)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	popup.add_theme_stylebox_override("panel", style)
	add_child(popup)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	popup.add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	margin.add_child(content)
	
	var title = Label.new()
	title.text = stage.name
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.2, 0.4, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	
	var desc = Label.new()
	desc.text = stage.desc
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(desc)
	
	var play_btn = Button.new()
	play_btn.text = "▶️ PLAY STAGE"
	play_btn.custom_minimum_size = Vector2(200, 50)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.75, 0.4)
	btn_style.corner_radius_top_left = 15
	btn_style.corner_radius_top_right = 15
	btn_style.corner_radius_bottom_left = 15
	btn_style.corner_radius_bottom_right = 15
	play_btn.add_theme_stylebox_override("normal", btn_style)
	play_btn.add_theme_color_override("font_color", Color.WHITE)
	play_btn.add_theme_font_size_override("font_size", 20)
	play_btn.pressed.connect(func():
		if AudioManager:
			AudioManager.play_click()
		# Start the first minigame of this stage
		if stage.minigames.size() > 0:
			var minigame = stage.minigames[0]
			get_tree().change_scene_to_file("res://scenes/minigames/%s.tscn" % minigame)
	)
	content.add_child(play_btn)
	
	var close_btn = Button.new()
	close_btn.text = "✕ Close"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(func():
		if AudioManager:
			AudioManager.play_click()
		overlay.queue_free()
		popup.queue_free()
	)
	content.add_child(close_btn)
	
	# Click overlay to close
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
			popup.queue_free()
	)

func _on_stage_hover(container: Control, hovering: bool):
	var target_scale = Vector2(1.1, 1.1) if hovering else Vector2.ONE
	var tween = create_tween()
	tween.tween_property(container, "scale", target_scale, 0.15)

func _create_decorations():
	# Trees along the sides
	for i in range(15):
		var tree = _create_tree()
		var side = i % 2
		var y = 100 + i * (total_map_height / 15)
		var x = randf_range(20, 80) if side == 0 else randf_range(screen_size.x - 80, screen_size.x - 20)
		tree.position = Vector2(x, y)
		tree.z_index = -40
		map_content.add_child(tree)
	
	# Flowers scattered
	for i in range(25):
		var flower = _create_flower()
		flower.position = Vector2(
			randf_range(30, screen_size.x - 30),
			randf_range(100, total_map_height - 100)
		)
		flower.z_index = -35
		map_content.add_child(flower)

func _create_header():
	# Fixed header (not scrolling)
	var header = PanelContainer.new()
	header.z_index = 50
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.55, 0.85, 0.95)
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	header.add_theme_stylebox_override("panel", style)
	header.position = Vector2(screen_size.x / 2 - 150, 0)
	header.custom_minimum_size = Vector2(300, 60)
	add_child(header)
	
	var title = Label.new()
	title.text = "🗺️ WATER JOURNEY"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	header.add_child(title)
	
	# Progress indicator
	var completed = stages.filter(func(s): return s.completed).size()
	var progress_label = Label.new()
	progress_label.text = "%d/%d Completed" % [completed, stages.size()]
	progress_label.add_theme_font_size_override("font_size", 14)
	progress_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	progress_label.position = Vector2(screen_size.x / 2 - 50, 65)
	progress_label.z_index = 50
	add_child(progress_label)

func _create_back_button():
	var btn = Button.new()
	btn.text = "← Back"
	btn.custom_minimum_size = Vector2(100, 45)
	btn.position = Vector2(15, 10)
	btn.z_index = 100
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.4, 0.35)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 18)
	
	btn.pressed.connect(func():
		if AudioManager:
			AudioManager.play_click()
		get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")
	)
	add_child(btn)

func _create_scroll_hint():
	# Scroll hint at bottom
	var hint = Label.new()
	hint.text = "↕️ Scroll to explore"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	hint.add_theme_constant_override("outline_size", 2)
	hint.position = Vector2(screen_size.x / 2 - 80, screen_size.y - 35)
	hint.z_index = 50
	add_child(hint)
	
	# Fade hint after a few seconds
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(hint, "modulate:a", 0.0, 1.0)

func _input(event):
	# Touch scrolling with momentum
	if event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
			drag_start_y = event.position.y
			scroll_start = scroll_container.scroll_vertical
			touch_velocity = 0
			last_touch_y = event.position.y
			touch_time = Time.get_ticks_msec()
		else:
			is_dragging = false
	
	elif event is InputEventScreenDrag and is_dragging:
		var delta = drag_start_y - event.position.y
		scroll_container.scroll_vertical = scroll_start + int(delta)
		
		# Calculate velocity for momentum
		var now = Time.get_ticks_msec()
		var dt = (now - touch_time) / 1000.0
		if dt > 0:
			touch_velocity = (last_touch_y - event.position.y) / dt
		last_touch_y = event.position.y
		touch_time = now
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_container.scroll_vertical -= 60
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_container.scroll_vertical += 60

func _process(delta):
	# Apply momentum scrolling
	if not is_dragging and abs(touch_velocity) > 10:
		scroll_container.scroll_vertical += int(touch_velocity * delta)
		touch_velocity *= 0.92  # Friction

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _create_circle(radius: float, color: Color) -> Polygon2D:
	var circle = Polygon2D.new()
	var points: Array[Vector2] = []
	for i in range(24):
		var angle = i * TAU / 24
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	circle.polygon = PackedVector2Array(points)
	circle.color = color
	return circle

func _create_cloud() -> Node2D:
	var cloud = Node2D.new()
	var positions = [
		Vector2(0, 0), Vector2(25, -8), Vector2(50, 3),
		Vector2(18, 12), Vector2(40, 15)
	]
	for pos in positions:
		var puff = _create_circle(randf_range(15, 22), Color(1, 1, 1, 0.85))
		puff.position = pos
		cloud.add_child(puff)
	return cloud

func _create_tree() -> Node2D:
	var tree = Node2D.new()
	
	var trunk = Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(-6, 0), Vector2(6, 0),
		Vector2(5, -30), Vector2(-5, -30)
	])
	trunk.color = Color(0.5, 0.35, 0.25)
	tree.add_child(trunk)
	
	var sizes = [28, 22, 15]
	var y_offsets = [-38, -55, -68]
	var colors = [Color(0.25, 0.55, 0.3), Color(0.3, 0.6, 0.35), Color(0.35, 0.65, 0.4)]
	
	for i in range(3):
		var foliage = _create_circle(sizes[i], colors[i])
		foliage.position = Vector2(0, y_offsets[i])
		tree.add_child(foliage)
	
	return tree

func _create_flower() -> Node2D:
	var flower = Node2D.new()
	var petal_colors = [
		Color(1, 0.5, 0.55), Color(1, 0.85, 0.4),
		Color(0.85, 0.5, 1), Color(1, 0.65, 0.3)
	]
	var petal_color = petal_colors[randi() % petal_colors.size()]
	
	for i in range(5):
		var petal = _create_circle(5, petal_color)
		var angle = i * TAU / 5
		petal.position = Vector2(cos(angle) * 6, sin(angle) * 6)
		flower.add_child(petal)
	
	var center = _create_circle(4, Color(1, 0.95, 0.4))
	flower.add_child(center)
	
	return flower
