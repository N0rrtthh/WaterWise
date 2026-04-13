extends MiniGameBase

var water_level: float = 50.0  # Start in middle
var target_min: float = 35.0
var target_max: float = 65.0
var pouring: bool = false
var pour_speed: float = 40.0
var drain_speed: float = 25.0  # Gauge drains when not pouring
var game_ended: bool = false

var pot_node: Node2D
var mud_visual: Polygon2D
var gauge_node: Node2D
var fill_node: Polygon2D

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			target_min = 25.0
			target_max = 75.0  # Very wide green zone
			pour_speed = 30.0
			drain_speed = 15.0
			game_duration = 8.0
		"Medium":
			target_min = 35.0
			target_max = 65.0
			pour_speed = 45.0
			drain_speed = 28.0
			game_duration = 10.0
		"Hard":
			target_min = 42.0
			target_max = 58.0  # Very narrow green zone
			pour_speed = 60.0
			drain_speed = 40.0
			game_duration = 12.0

func _ready():
	game_name = "Mud Pie Maker"
	game_instruction_text = "HOLD to pour water!\nKeep the gauge in GREEN zone until time runs out! 💧"
	game_duration = 12.0
	game_mode = "survival"  # Survive by staying in green zone
	show_quota = false
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.55, 0.75, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Sun
	var sun = Label.new()
	sun.text = "☀️"
	sun.add_theme_font_size_override("font_size", 80)
	sun.position = Vector2(screen_size.x * 0.85, 50)
	sun.z_index = -8
	add_child(sun)
	
	# Ground
	var ground = ColorRect.new()
	ground.color = Color(0.45, 0.3, 0.18)
	ground.position = Vector2(0, screen_size.y * 0.72)
	ground.size = Vector2(screen_size.x, screen_size.y * 0.28)
	ground.z_index = -5
	add_child(ground)
	
	_create_pot(screen_size)
	_create_gauge(screen_size)
	
	# Hint
	var hint = Label.new()
	hint.name = "HintLabel"
	hint.text = "👆 HOLD to pour, release to drain!"
	hint.add_theme_font_size_override("font_size", 28)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 5)
	hint.position = Vector2(screen_size.x / 2 - 200, screen_size.y * 0.85)
	add_child(hint)

func _create_pot(screen_size: Vector2):
	pot_node = Node2D.new()
	pot_node.position = Vector2(screen_size.x * 0.35, screen_size.y * 0.5)
	add_child(pot_node)
	
	var pot = Polygon2D.new()
	pot.polygon = PackedVector2Array([
		Vector2(-90, -90), Vector2(90, -90),
		Vector2(80, 90), Vector2(-80, 90)
	])
	pot.color = Color(0.6, 0.35, 0.2)
	pot_node.add_child(pot)
	
	var rim = Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-95, -95), Vector2(95, -95),
		Vector2(95, -85), Vector2(-95, -85)
	])
	rim.color = Color(0.7, 0.45, 0.3)
	pot_node.add_child(rim)
	
	mud_visual = Polygon2D.new()
	mud_visual.polygon = PackedVector2Array([
		Vector2(-75, -80), Vector2(75, -80),
		Vector2(70, 85), Vector2(-70, 85)
	])
	mud_visual.color = Color(0.45, 0.25, 0.1)
	pot_node.add_child(mud_visual)
	
	var bucket = Node2D.new()
	bucket.position = Vector2(0, -180)
	bucket.name = "Bucket"
	pot_node.add_child(bucket)
	
	var bucket_body = Polygon2D.new()
	bucket_body.polygon = PackedVector2Array([
		Vector2(-45, -35), Vector2(45, -35),
		Vector2(40, 45), Vector2(-40, 45)
	])
	bucket_body.color = Color(0.3, 0.5, 0.7)
	bucket.add_child(bucket_body)
	
	var bucket_water = Polygon2D.new()
	bucket_water.polygon = PackedVector2Array([
		Vector2(-40, -25), Vector2(40, -25),
		Vector2(35, 40), Vector2(-35, 40)
	])
	bucket_water.color = Color(0.4, 0.7, 1.0, 0.8)
	bucket.add_child(bucket_water)
	
	var stream = Polygon2D.new()
	stream.name = "Stream"
	stream.polygon = PackedVector2Array([
		Vector2(-10, 0), Vector2(10, 0),
		Vector2(15, 120), Vector2(-15, 120)
	])
	stream.color = Color(0.4, 0.7, 1.0, 0.7)
	stream.position = Vector2(0, 45)
	stream.visible = false
	bucket.add_child(stream)

func _create_gauge(screen_size: Vector2):
	gauge_node = Node2D.new()
	gauge_node.position = Vector2(screen_size.x * 0.78, screen_size.y * 0.42)
	add_child(gauge_node)
	
	var gauge_height = 280.0
	var gauge_width = 60.0
	
	var border = Polygon2D.new()
	border.polygon = PackedVector2Array([
		Vector2(-gauge_width/2 - 5, -gauge_height/2 - 5),
		Vector2(gauge_width/2 + 5, -gauge_height/2 - 5),
		Vector2(gauge_width/2 + 5, gauge_height/2 + 5),
		Vector2(-gauge_width/2 - 5, gauge_height/2 + 5)
	])
	border.color = Color(0.3, 0.3, 0.3)
	gauge_node.add_child(border)
	
	var bg_inner = Polygon2D.new()
	bg_inner.polygon = PackedVector2Array([
		Vector2(-gauge_width/2, -gauge_height/2),
		Vector2(gauge_width/2, -gauge_height/2),
		Vector2(gauge_width/2, gauge_height/2),
		Vector2(-gauge_width/2, gauge_height/2)
	])
	bg_inner.color = Color(0.15, 0.15, 0.15)
	gauge_node.add_child(bg_inner)
	
	# Target zone
	var target_bottom = gauge_height/2 - (target_min / 100.0 * gauge_height)
	var target_top = gauge_height/2 - (target_max / 100.0 * gauge_height)
	var target_zone = Polygon2D.new()
	target_zone.polygon = PackedVector2Array([
		Vector2(-gauge_width/2 + 2, target_top),
		Vector2(gauge_width/2 - 2, target_top),
		Vector2(gauge_width/2 - 2, target_bottom),
		Vector2(-gauge_width/2 + 2, target_bottom)
	])
	target_zone.color = Color(0.2, 0.8, 0.2, 0.6)
	gauge_node.add_child(target_zone)
	
	fill_node = Polygon2D.new()
	fill_node.name = "Fill"
	fill_node.color = Color(0.4, 0.6, 0.9)
	gauge_node.add_child(fill_node)
	
	# Labels
	var too_wet = Label.new()
	too_wet.text = "🌊 WET"
	too_wet.add_theme_font_size_override("font_size", 18)
	too_wet.add_theme_color_override("font_color", Color.RED)
	too_wet.position = Vector2(40, -gauge_height/2 - 10)
	gauge_node.add_child(too_wet)
	
	var perfect = Label.new()
	perfect.text = "✓ OK"
	perfect.add_theme_font_size_override("font_size", 22)
	perfect.add_theme_color_override("font_color", Color.GREEN)
	perfect.position = Vector2(40, (target_top + target_bottom) / 2 - 15)
	gauge_node.add_child(perfect)
	
	var too_dry = Label.new()
	too_dry.text = "🏜️ DRY"
	too_dry.add_theme_font_size_override("font_size", 18)
	too_dry.add_theme_color_override("font_color", Color.ORANGE)
	too_dry.position = Vector2(40, gauge_height/2 - 25)
	gauge_node.add_child(too_dry)

func _input(event):
	if not game_active or game_ended: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pouring = event.pressed
	
	if event is InputEventScreenTouch:
		pouring = event.pressed

func _process(delta):
	super._process(delta)
	if not game_active or game_ended: return
	
	var bucket = pot_node.get_node("Bucket")
	var stream = bucket.get_node("Stream")
	var hint = get_node("HintLabel")
	
	if pouring:
		water_level = min(water_level + pour_speed * delta, 100.0)
		hint.text = "Pouring... 💧"
		stream.visible = true
		bucket.rotation = 0.3
		bucket.position.x = sin(Time.get_ticks_msec() * 0.02) * 3
	else:
		# DRAIN when not pouring
		water_level = max(water_level - drain_speed * delta, 0.0)
		hint.text = "Hold to pour!"
		stream.visible = false
		bucket.rotation = 0
		bucket.position.x = 0
	
	_update_gauge()
	
	# Update mud color
	var wetness = water_level / 100.0
	mud_visual.color = Color(0.45, 0.25, 0.1).lerp(Color(0.2, 0.12, 0.05), wetness)
	
	# Check if in zone
	var _in_zone = water_level >= target_min and water_level <= target_max
	
	# Fail if completely dry or overflowed
	if (water_level <= 0 or water_level >= 100) and not game_ended:
		game_ended = true
		record_action(false)
		
		var fail = Label.new()
		fail.text = "💦 Out of range!" if water_level >= 100 else "🏜️ Too dry!"
		fail.add_theme_font_size_override("font_size", 40)
		fail.add_theme_color_override("font_color", Color.RED)
		fail.position = pot_node.position + Vector2(-100, -250)
		add_child(fail)
		
		await get_tree().create_timer(0.5).timeout
		end_game(false)

func _update_gauge():
	if fill_node == null: return
	
	var gauge_height = 280.0
	var gauge_width = 60.0
	
	var fill_height = (water_level / 100.0) * (gauge_height - 6)
	var bottom_y = gauge_height/2 - 3
	var top_y = bottom_y - fill_height
	
	fill_node.polygon = PackedVector2Array([
		Vector2(-gauge_width/2 + 3, bottom_y),
		Vector2(gauge_width/2 - 3, bottom_y),
		Vector2(gauge_width/2 - 3, top_y),
		Vector2(-gauge_width/2 + 3, top_y)
	])
	
	if water_level < target_min:
		fill_node.color = Color(0.9, 0.6, 0.2)
	elif water_level <= target_max:
		fill_node.color = Color(0.2, 0.9, 0.3)
	else:
		fill_node.color = Color(0.9, 0.2, 0.2)
