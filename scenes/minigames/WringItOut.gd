extends MiniGameBase

var progress: float = 0.0
var decay_rate: float = 0.2
var tap_gain: float = 8.0
var target_progress: float = 100.0
var clothes_node: Node2D
var progress_bar: ProgressBar
var water_drops: Array = []
var last_tap_time: float = 0.0
var tap_requested: bool = false

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			decay_rate = 0.3
			tap_gain = 10.0
			game_duration = 12.0
		"Medium":
			decay_rate = 0.5
			tap_gain = 8.0
			game_duration = 10.0
		"Hard":
			decay_rate = 0.8
			tap_gain = 6.0
			game_duration = 8.0

func _ready():
	game_name = "Wring It Out"
	game_instruction_text = "TAP FAST to wring out the clothes!\nSave the water!"
	game_duration = 12.0
	game_mode = "quota"  # Must fill progress bar!
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.9, 0.95, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Clothesline
	var line = Line2D.new()
	line.points = PackedVector2Array([Vector2(100, 200), Vector2(screen_size.x - 100, 200)])
	line.width = 5
	line.default_color = Color(0.4, 0.3, 0.2)
	add_child(line)
	
	# Clothes (T-Shirt shape)
	clothes_node = Node2D.new()
	clothes_node.position = Vector2(screen_size.x * 0.5, screen_size.y * 0.45)
	add_child(clothes_node)
	
	var shirt = Polygon2D.new()
	shirt.polygon = PackedVector2Array([
		Vector2(-80, -100), Vector2(-40, -100), Vector2(-40, -60), Vector2(40, -60),
		Vector2(40, -100), Vector2(80, -100), Vector2(80, -40), Vector2(50, -40),
		Vector2(50, 100), Vector2(-50, 100), Vector2(-50, -40), Vector2(-80, -40)
	])
	shirt.color = Color(0.3, 0.5, 0.9)
	shirt.name = "Shirt"
	clothes_node.add_child(shirt)
	
	# Water dripping effect area
	var drip_indicator = Label.new()
	drip_indicator.text = "💧💧💧"
	drip_indicator.add_theme_font_size_override("font_size", 32)
	drip_indicator.position = Vector2(-50, 110)
	drip_indicator.name = "DripIndicator"
	clothes_node.add_child(drip_indicator)
	
	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(400, 40)
	progress_bar.max_value = target_progress
	progress_bar.value = 0
	progress_bar.position = Vector2(screen_size.x / 2 - 200, screen_size.y - 180)
	
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.3, 0.7, 0.3)
	bar_style.corner_radius_top_left = 10
	bar_style.corner_radius_top_right = 10
	bar_style.corner_radius_bottom_left = 10
	bar_style.corner_radius_bottom_right = 10
	progress_bar.add_theme_stylebox_override("fill", bar_style)
	add_child(progress_bar)
	
	# Tap instruction
	var tap_label = Label.new()
	tap_label.text = "👆 TAP ANYWHERE! 👆"
	tap_label.add_theme_font_size_override("font_size", 36)
	tap_label.add_theme_color_override("font_color", Color(0.2, 0.5, 0.8))
	tap_label.position = Vector2(screen_size.x / 2 - 180, screen_size.y - 130)
	add_child(tap_label)
	
	# Basin to catch water
	var basin = Polygon2D.new()
	basin.polygon = PackedVector2Array([
		Vector2(-100, 0), Vector2(100, 0),
		Vector2(80, 60), Vector2(-80, 60)
	])
	basin.color = Color(0.6, 0.4, 0.2)
	basin.position = Vector2(screen_size.x / 2, screen_size.y - 250)
	add_child(basin)

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	# Decay progress slowly
	progress = max(0, progress - decay_rate * delta * 5)
	progress_bar.value = progress
	
	# Check for tap/click
	if tap_requested:
		tap_requested = false
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_tap_time > 0.08: # Prevent too fast tapping
			last_tap_time = current_time
			_on_tap()
	
	# Update visuals based on progress
	var wetness = 1.0 - (progress / target_progress)
	var drip = clothes_node.get_node("DripIndicator")
	if wetness > 0.7:
		drip.text = "💧💧💧"
	elif wetness > 0.4:
		drip.text = "💧💧"
	elif wetness > 0.1:
		drip.text = "💧"
	else:
		drip.text = "✨"
	
	# Shirt color gets lighter as it dries
	var shirt = clothes_node.get_node("Shirt")
	shirt.color = Color(0.3, 0.5, 0.9).lerp(Color(0.5, 0.7, 1.0), progress / target_progress)
	
	if progress >= target_progress:
		end_game(true)


func _input(event):
	if not game_active:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_requested = true
	elif event is InputEventScreenTouch and event.pressed:
		tap_requested = true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		tap_requested = true

func _on_tap():
	progress += tap_gain
	record_action(true)
	
	# Squeeze animation
	var tween = create_tween()
	tween.tween_property(clothes_node, "scale", Vector2(0.85, 1.15), 0.05)
	tween.tween_property(clothes_node, "scale", Vector2(1.0, 1.0), 0.05)
	
	# Spawn water drop
	_spawn_water_drop()

func _spawn_water_drop():
	var drop = Polygon2D.new()
	drop.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(6, 0),
		Vector2(0, 8), Vector2(-6, 0)
	])
	drop.color = Color(0.3, 0.6, 1.0, 0.8)
	drop.position = clothes_node.position + Vector2(randf_range(-30, 30), 100)
	add_child(drop)
	
	var tween = create_tween()
	tween.tween_property(drop, "position:y", get_viewport_rect().size.y - 250, 0.4)
	tween.parallel().tween_property(drop, "modulate:a", 0.0, 0.4)
	tween.tween_callback(drop.queue_free)
