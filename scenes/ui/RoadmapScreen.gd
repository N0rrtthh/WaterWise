extends Control

## ═══════════════════════════════════════════════════════════════════
## ROADMAP SCREEN - SCROLLABLE WATER JOURNEY MAP
## ═══════════════════════════════════════════════════════════════════
## An interactive scrollable map showing water conservation journey
## Touch/drag to scroll through stages
## ═══════════════════════════════════════════════════════════════════

const STAGE_TEMPLATE: Array[Dictionary] = [
	{
		"unlock_id": "catch_rain",
		"name": "💧 Water Drop Village",
		"desc": "Learn the basics of water conservation",
		"minigames": ["CatchTheRain", "CoverTheDrum", "RiceWashRescue"]
	},
	{
		"unlock_id": "pipe_puzzle",
		"name": "🔧 Pipe Puzzle District",
		"desc": "Trace and repair the water network",
		"minigames": ["TracePipePath", "PlugTheLeak", "FixLeak", "ToiletTankFix", "TurnOffTap"]
	},
	{
		"unlock_id": "water_sorting",
		"name": "🧪 Water Sorting Lab",
		"desc": "Sort clean and reusable water correctly",
		"minigames": [
			"GreywaterSorter",
			"VegetableBath",
			"ScrubToSave",
			"FilterBuilder",
			"SpotTheSpeck"
		]
	},
	{
		"unlock_id": "leak_fix",
		"name": "🚿 Leak Fix Zone",
		"desc": "Stop waste in daily home routines",
		"minigames": ["WringItOut", "QuickShower", "SwipeTheSoap", "WaterPlant"]
	},
	{
		"unlock_id": "water_quiz",
		"name": "❓ Water Wisdom Corner",
		"desc": "Use quick thinking for water-saving choices",
		"minigames": ["ThirstyPlant", "MudPieMaker"]
	},
	{
		"unlock_id": "bucket_relay",
		"name": "🪣 Bucket Relay Park",
		"desc": "Teamwork and timing save every drop",
		"minigames": ["BucketBrigade", "TimingTap"]
	},
	{
		"unlock_id": "fun_games",
		"name": "🎉 Fun Games Pier",
		"desc": "Bonus challenges for mastery and memory",
		"minigames": ["CloudCatcher", "WaterMemory", "DropletDash"]
	},
	{
		"unlock_id": "master_path",
		"name": "🏆 Waterville Champion Path",
		"desc": "Combine all your water-saving skills",
		"minigames": ["CatchTheRain", "TracePipePath", "GreywaterSorter"]
	},
]

const MINIGAME_INSTRUCTION_KEYS: Dictionary = {
	"RiceWashRescue": ["rice_wash_rescue_instructions", "rice_wash_instruction"],
	"VegetableBath": ["vegetable_bath_instructions", "veggie_instruction"],
	"GreywaterSorter": ["greywater_sorter_instructions", "greywater_instruction"],
	"WringItOut": ["wring_it_out_instructions", "wring_instruction"],
	"ThirstyPlant": ["thirsty_plant_instructions", "plant_instruction"],
	"MudPieMaker": ["mud_pie_maker_instructions", "mud_instruction"],
	"CatchTheRain": ["catch_the_rain_instructions", "rain_instruction"],
	"CoverTheDrum": ["cover_the_drum_instructions", "drum_instruction"],
	"SpotTheSpeck": ["spot_the_speck_instructions", "speck_instruction"],
	"WaterPlant": ["water_plant_instructions", "water_plant_instruction", "plant_instruction"],
	"FixLeak": ["fix_leak_instructions", "fix_leak_instruction"],
	"PlugTheLeak": ["plug_the_leak_instructions", "fix_leak_instruction"],
	"SwipeTheSoap": ["swipe_the_soap_instructions", "swipe_soap_instructions"],
	"QuickShower": ["quick_shower_instructions"],
	"FilterBuilder": ["filter_builder_instructions"],
	"ToiletTankFix": ["toilet_tank_fix_instructions", "toilet_tank_instructions"],
	"TracePipePath": ["trace_pipe_path_instructions", "trace_pipe_instructions"],
	"ScrubToSave": ["scrub_to_save_instructions", "scrub_save_instructions"],
	"BucketBrigade": ["bucket_brigade_instructions"],
	"TimingTap": ["timing_tap_instructions"],
	"TurnOffTap": ["turn_off_tap_instructions"],
	"CloudCatcher": ["cloud_catcher_instructions"],
	"WaterMemory": ["water_memory_instructions"],
	"DropletDash": ["droplet_dash_instructions"],
}

const MINIGAME_PREVIEW_MODE: Dictionary = {
	"RiceWashRescue": "drag",
	"VegetableBath": "drag",
	"GreywaterSorter": "swipe",
	"WringItOut": "tap",
	"ThirstyPlant": "tap",
	"MudPieMaker": "swipe",
	"CatchTheRain": "drag",
	"CoverTheDrum": "tap",
	"SpotTheSpeck": "swipe",
	"WaterPlant": "tap",
	"FixLeak": "tap",
	"PlugTheLeak": "hold",
	"SwipeTheSoap": "swipe",
	"QuickShower": "timing",
	"FilterBuilder": "drag",
	"ToiletTankFix": "hold",
	"TracePipePath": "trace",
	"ScrubToSave": "swipe",
	"BucketBrigade": "timing",
	"TimingTap": "timing",
	"TurnOffTap": "tap",
	"CloudCatcher": "tap",
	"WaterMemory": "choice",
	"DropletDash": "swipe",
}

var stages: Array[Dictionary] = []

var screen_size: Vector2
var scroll_container: ScrollContainer
var map_content: Control
var total_map_height: float = 0.0
var is_dragging: bool = false
var drag_start_y: float = 0.0
var scroll_start: int = 0

# Touch scrolling
var touch_velocity: float = 0.0
var last_touch_y: float = 0.0
var touch_time: float = 0.0

func _ready():
	_sync_stages_from_progress()
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

	# Entrance popup animation
	if scroll_container:
		scroll_container.pivot_offset = (
			scroll_container.size * 0.5
		)
		scroll_container.modulate.a = 0.0
		scroll_container.scale = Vector2(0.85, 0.85)
		var tw = create_tween()
		tw.tween_property(
			scroll_container, "modulate:a", 1.0, 0.25
		)
		tw.parallel().tween_property(
			scroll_container, "scale",
			Vector2(1.0, 1.0), 0.3
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _sync_stages_from_progress() -> void:
	stages.clear()
	for stage in STAGE_TEMPLATE:
		var stage_entry: Dictionary = stage.duplicate(true)
		stage_entry["unlocked"] = false
		stage_entry["completed"] = false
		stage_entry["stars"] = 0
		stages.append(stage_entry)

	var unlocked_ids: Array = []
	var games_played := 0
	var droplets := 0

	if SaveManager:
		if SaveManager.unlocked_content is Dictionary:
			unlocked_ids = SaveManager.unlocked_content.get("minigames", [])
		if SaveManager.has_method("get_total_games_played"):
			games_played = int(SaveManager.get_total_games_played())
		if SaveManager.has_method("get_droplets"):
			droplets = int(SaveManager.get_droplets())

	var completed_count := clampi(int(floor(float(games_played) / 2.0)), 0, stages.size())

	for i in range(stages.size()):
		var unlock_id = str(stages[i].get("unlock_id", ""))
		var auto_unlock = (i == 0) or (i <= completed_count)
		var purchased_unlock = (unlock_id in unlocked_ids)
		var unlocked = auto_unlock or purchased_unlock

		if unlock_id == "master_path":
			unlocked = unlocked or completed_count >= stages.size() - 1

		var completed = unlocked and (i < completed_count)
		var stars := 0
		if completed:
			var star_seed = float(droplets + games_played * 15 - i * 20) / 220.0
			stars = clampi(1 + int(star_seed), 1, 3)
		elif unlocked and i == completed_count and games_played > 0:
			stars = 1

		stages[i]["unlocked"] = unlocked
		stages[i]["completed"] = completed
		stages[i]["stars"] = stars

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
	
	# Make interactive (info popup for both unlocked and locked stages)
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
	
	print("Stage %d pressed: %s" % [index + 1, stage.name])

	# Show stage info + tutorial preview popup.
	_show_stage_popup(stage, index)

func _show_stage_popup(stage: Dictionary, _index: int):
	# Full-screen dim overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.z_index = 100
	add_child(overlay)

	# Centered container keeps popup on-screen across resolutions.
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.z_index = 101
	overlay.add_child(center)

	var popup = PanelContainer.new()
	var vp = get_viewport_rect().size
	var popup_w = clamp(vp.x - 120.0, 360.0, 760.0)
	var popup_h = clamp(vp.y - 120.0, 360.0, 620.0)
	popup.custom_minimum_size = Vector2(popup_w, popup_h)
	center.add_child(popup)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.97, 1.0)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	popup.add_theme_stylebox_override("panel", style)

	var content = VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 20
	content.offset_top = 20
	content.offset_right = -20
	content.offset_bottom = -20
	content.add_theme_constant_override("separation", 12)
	popup.add_child(content)

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
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(desc)

	if not stage.unlocked:
		var lock_note = Label.new()
		lock_note.text = "🔒 This stage is still locked."
		lock_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_note.add_theme_font_size_override("font_size", 16)
		lock_note.add_theme_color_override("font_color", Color(0.65, 0.45, 0.25))
		content.add_child(lock_note)

	var games_header = Label.new()
	games_header.text = "Included mini-games"
	games_header.add_theme_font_size_override("font_size", 18)
	games_header.add_theme_color_override("font_color", Color(0.18, 0.32, 0.5))
	content.add_child(games_header)

	var games_list = Label.new()
	games_list.autowrap_mode = TextServer.AUTOWRAP_WORD
	games_list.add_theme_font_size_override("font_size", 14)
	games_list.add_theme_color_override("font_color", Color(0.25, 0.3, 0.35))
	games_list.text = ""
	if stage.has("minigames"):
		for game_name in stage.minigames:
			games_list.text += "• %s\n" % _get_localized_game_name(str(game_name))
	games_list.text = games_list.text.strip_edges()
	content.add_child(games_list)

	var tutorial_header = Label.new()
	tutorial_header.text = "How to play (animated preview)"
	tutorial_header.add_theme_font_size_override("font_size", 18)
	tutorial_header.add_theme_color_override("font_color", Color(0.18, 0.32, 0.5))
	content.add_child(tutorial_header)

	var preview_panel = PanelContainer.new()
	var preview_width = clamp(popup_w - 80.0, 300.0, 520.0)
	preview_panel.custom_minimum_size = Vector2(preview_width, 170)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.86, 0.93, 0.98)
	preview_style.corner_radius_top_left = 14
	preview_style.corner_radius_top_right = 14
	preview_style.corner_radius_bottom_left = 14
	preview_style.corner_radius_bottom_right = 14
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	content.add_child(preview_panel)

	var preview = Control.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_panel.add_child(preview)
	_build_how_to_play_preview(preview, stage, preview_width)

	var close_btn = Button.new()
	close_btn.text = "✕ CLOSE"
	close_btn.custom_minimum_size = Vector2(170, 44)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		if AudioManager:
			AudioManager.play_click()
		overlay.queue_free()
	)
	content.add_child(close_btn)

	# Click outside popup to close.
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if not popup.get_global_rect().has_point(event.position):
				overlay.queue_free()
	)


func _build_how_to_play_preview(preview: Control, stage: Dictionary, preview_width: float) -> void:
	var base = ColorRect.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.73, 0.86, 0.95)
	preview.add_child(base)

	var game_title = Label.new()
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_title.add_theme_font_size_override("font_size", 15)
	game_title.add_theme_color_override("font_color", Color(0.14, 0.28, 0.45))
	game_title.position = Vector2(0, 10)
	game_title.custom_minimum_size = Vector2(preview_width, 24)
	preview.add_child(game_title)

	var actor = Label.new()
	actor.text = "💧"
	actor.add_theme_font_size_override("font_size", 46)
	preview.add_child(actor)

	var target = Label.new()
	target.text = "🪣"
	target.add_theme_font_size_override("font_size", 42)
	preview.add_child(target)

	var arrow = Label.new()
	arrow.text = "↔"
	arrow.add_theme_font_size_override("font_size", 44)
	arrow.add_theme_color_override("font_color", Color(0.15, 0.35, 0.6, 0.8))
	preview.add_child(arrow)

	var hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.16, 0.28, 0.4))
	hint.position = Vector2(20, 126)
	hint.custom_minimum_size = Vector2(preview_width - 40.0, 40)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_child(hint)

	var left_x = 34.0
	var right_x = preview_width - 76.0
	var center_x = preview_width * 0.5 - 24.0
	actor.position = Vector2(left_x, 52)
	target.position = Vector2(right_x, 54)
	arrow.position = Vector2(center_x, 54)

	var games: Array[String] = []
	if stage.has("minigames"):
		for game_name in stage.minigames:
			games.append(str(game_name))

	if games.is_empty():
		game_title.text = "No mini-game data"
		hint.text = "No tutorial information available yet."
		return

	var state = {
		"preview": preview,
		"games": games,
		"index": 0,
		"game_title": game_title,
		"actor": actor,
		"target": target,
		"arrow": arrow,
		"hint": hint,
		"left_x": left_x,
		"right_x": right_x,
		"center_x": center_x,
		"anim": null,
	}

	_apply_preview_state(state)

	if games.size() > 1:
		var rotate_timer = Timer.new()
		rotate_timer.wait_time = 2.8
		rotate_timer.one_shot = false
		preview.add_child(rotate_timer)
		rotate_timer.timeout.connect(func():
			state["index"] = (int(state["index"]) + 1) % games.size()
			_apply_preview_state(state)
		)
		rotate_timer.start()


func _apply_preview_state(state: Dictionary) -> void:
	var games: Array[String] = state["games"]
	if games.is_empty():
		return

	var idx = int(state["index"])
	if idx < 0 or idx >= games.size():
		idx = 0
		state["index"] = 0

	var game_name = games[idx]
	var title_label = state["game_title"] as Label
	var actor = state["actor"] as Label
	var target = state["target"] as Label
	var arrow = state["arrow"] as Label
	var hint = state["hint"] as Label
	var left_x = float(state["left_x"])
	var right_x = float(state["right_x"])
	var center_x = float(state["center_x"])

	title_label.text = _get_localized_game_name(game_name)
	hint.text = _get_localized_instruction_hint(game_name)

	actor.text = "💧"
	actor.position = Vector2(left_x, 52)
	actor.scale = Vector2.ONE
	actor.modulate = Color.WHITE

	target.position = Vector2(right_x, 54)
	target.scale = Vector2.ONE
	target.modulate = Color.WHITE
	target.text = "🎯"

	arrow.text = "↔"
	arrow.modulate.a = 1.0
	arrow.position = Vector2(center_x, 54)

	var mode = _get_preview_mode(game_name)
	_start_preview_animation(state, mode)


func _start_preview_animation(state: Dictionary, mode: String) -> void:
	var preview = state["preview"] as Control
	var actor = state["actor"] as Label
	var target = state["target"] as Label
	var arrow = state["arrow"] as Label
	var left_x = float(state["left_x"])
	var right_x = float(state["right_x"])
	var center_x = float(state["center_x"])

	var old_anim = state.get("anim")
	if old_anim is Tween and old_anim.is_valid():
		old_anim.kill()

	var anim = preview.create_tween().set_loops()
	state["anim"] = anim

	match mode:
		"drag":
			target.text = "🪣"
			anim.tween_property(actor, "position:x", right_x - 46.0, 0.9)
			anim.tween_property(actor, "position:x", left_x, 0.9)
		"swipe":
			target.text = "🧪"
			anim.tween_property(actor, "position:x", center_x - 110.0, 0.35)
			anim.tween_property(actor, "position:x", center_x + 110.0, 0.35)
			anim.tween_property(actor, "position:x", center_x, 0.25)
			anim.parallel().tween_property(arrow, "modulate:a", 0.15, 0.5)
			anim.parallel().tween_property(arrow, "modulate:a", 1.0, 0.45)
		"tap":
			target.text = "🔧"
			actor.position.x = center_x
			target.position.x = center_x + 70.0
			anim.tween_property(actor, "scale", Vector2(1.26, 1.26), 0.18)
			anim.tween_property(actor, "scale", Vector2(1.0, 1.0), 0.22)
			anim.parallel().tween_property(target, "scale", Vector2(1.2, 1.2), 0.18)
			anim.parallel().tween_property(target, "scale", Vector2(1.0, 1.0), 0.22)
		"timing":
			target.text = "⏱️"
			target.position.x = right_x - 16.0
			anim.tween_property(actor, "position:x", right_x - 32.0, 0.55)
			anim.tween_property(actor, "position:x", left_x, 0.55)
			anim.parallel().tween_property(target, "modulate:a", 0.45, 0.25)
			anim.parallel().tween_property(target, "modulate:a", 1.0, 0.25)
		"choice":
			target.text = "❓"
			arrow.text = "✔  ✖"
			actor.position.x = center_x
			target.position.x = center_x + 88.0
			anim.tween_property(actor, "position:x", center_x - 72.0, 0.55)
			anim.tween_property(actor, "position:x", center_x + 72.0, 0.55)
			anim.tween_property(actor, "position:x", center_x, 0.3)
		"trace":
			target.text = "🛠️"
			arrow.text = "↘"
			actor.position = Vector2(left_x, 80)
			anim.tween_property(actor, "position", Vector2(center_x, 50), 0.5)
			anim.tween_property(actor, "position", Vector2(right_x - 20.0, 82), 0.6)
			anim.tween_property(actor, "position", Vector2(left_x, 80), 0.45)
		"hold":
			target.text = "🚰"
			actor.position.x = center_x
			target.position.x = center_x + 76.0
			anim.tween_property(actor, "scale", Vector2(1.3, 1.3), 0.45)
			anim.parallel().tween_property(target, "modulate:a", 0.55, 0.45)
			anim.tween_property(actor, "scale", Vector2(1.0, 1.0), 0.35)
			anim.parallel().tween_property(target, "modulate:a", 1.0, 0.35)
		_:
			target.text = "🏆"
			anim.tween_property(actor, "position:x", right_x - 58.0, 0.6)
			anim.tween_property(actor, "scale", Vector2(1.2, 1.2), 0.16)
			anim.tween_property(actor, "scale", Vector2(1.0, 1.0), 0.16)
			anim.tween_property(actor, "position:x", left_x, 0.6)


func _get_preview_mode(game_name: String) -> String:
	if MINIGAME_PREVIEW_MODE.has(game_name):
		return str(MINIGAME_PREVIEW_MODE[game_name])
	return "drag"


func _get_localized_instruction_hint(game_name: String) -> String:
	var candidates: Array[String] = []
	if MINIGAME_INSTRUCTION_KEYS.has(game_name):
		for key in MINIGAME_INSTRUCTION_KEYS[game_name]:
			candidates.append(str(key))

	var snake = _to_snake_case(game_name)
	candidates.append("%s_instructions" % snake)
	candidates.append("%s_instruction" % snake)

	for key in candidates:
		var text = _try_translate(key)
		if not text.is_empty():
			return text.replace("\n", " ")

	return "Follow on-screen controls to conserve water effectively."


func _get_localized_game_name(game_name: String) -> String:
	var key = _to_snake_case(game_name)
	var translated = _try_translate(key)
	if not translated.is_empty():
		return translated
	return _format_game_name(game_name)


func _try_translate(key: String) -> String:
	if not Localization:
		return ""
	if not (Localization.translations is Dictionary):
		return ""
	if not Localization.translations.has(key):
		return ""
	return Localization.get_text(key)


func _to_snake_case(value: String) -> String:
	var out = ""
	for i in range(value.length()):
		var ch = value.substr(i, 1)
		var is_upper = ch == ch.to_upper() and ch != ch.to_lower()
		if i > 0 and is_upper:
			var prev = value.substr(i - 1, 1)
			if prev != "_" and prev != " ":
				out += "_"
		if ch == " ":
			out += "_"
		else:
			out += ch.to_lower()
	return out


func _format_game_name(game_name: String) -> String:
	# Convert camel/pascal IDs into readable labels.
	var spaced = game_name.replace("_", " ")
	var out = ""
	for i in range(spaced.length()):
		var ch = spaced.substr(i, 1)
		var is_upper = ch == ch.to_upper() and ch != ch.to_lower()
		if i > 0 and is_upper:
			var prev = spaced.substr(i - 1, 1)
			if prev != " ":
				out += " "
		out += ch
	return out.strip_edges()

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
		var x = (
			randf_range(20, 80)
			if side == 0
			else randf_range(screen_size.x - 80, screen_size.x - 20)
		)
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
		if GameManager and GameManager.has_method("transition_to_scene"):
			GameManager.transition_to_scene("res://scenes/ui/InitialScreen.tscn")
		else:
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


func _get_first_existing_stage_scene(stage: Dictionary) -> String:
	if not stage.has("minigames"):
		return ""

	for game_name in stage.minigames:
		var scene_path = "res://scenes/minigames/%s.tscn" % game_name
		if ResourceLoader.exists(scene_path):
			return scene_path

	return ""

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
		scroll_container.scroll_vertical = int(scroll_start + int(delta))
		
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
