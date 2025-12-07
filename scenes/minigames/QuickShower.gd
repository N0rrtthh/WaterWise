extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## QUICK SHOWER - Tap at the right time to turn off shower
## ═══════════════════════════════════════════════════════════════════

var shower_running: bool = false
var water_used: float = 0.0
var max_water: float = 100.0
var target_zone_start: float = 0.0
var target_zone_end: float = 0.0
var showers_taken: int = 0
var target_showers: int = 5
var gauge_position: float = 0.0
var gauge_speed: float = 80.0
var gauge_direction: int = 1

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			target_showers = 3
			gauge_speed = 50.0
			game_duration = 25.0
		"Medium":
			target_showers = 5
			gauge_speed = 80.0
			game_duration = 20.0
		"Hard":
			target_showers = 7
			gauge_speed = 120.0
			game_duration = 18.0

func _ready():
	game_name = "Quick Shower"
	game_instruction_text = Localization.get_text("quick_shower_instructions") if Localization else "TAP when gauge is in GREEN zone!\nSave water with quick showers! 🚿"
	game_duration = 20.0
	game_mode = "quota"
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background - Bathroom
	var bg = ColorRect.new()
	bg.color = Color(0.85, 0.9, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Tiles
	for i in range(10):
		var tile = ColorRect.new()
		tile.color = Color(0.8, 0.85, 0.9) if i % 2 == 0 else Color(0.75, 0.8, 0.85)
		tile.size = Vector2(screen_size.x, 80)
		tile.position = Vector2(0, i * 80)
		tile.z_index = -9
		add_child(tile)
	
	# Shower head
	var shower = Label.new()
	shower.name = "Shower"
	shower.text = "🚿"
	shower.add_theme_font_size_override("font_size", 80)
	shower.position = Vector2(screen_size.x / 2 - 40, screen_size.y * 0.2)
	add_child(shower)
	
	# Water drops container
	var drops_container = Node2D.new()
	drops_container.name = "Drops"
	drops_container.position = Vector2(screen_size.x / 2, screen_size.y * 0.35)
	add_child(drops_container)
	
	# Gauge background
	var gauge_bg = ColorRect.new()
	gauge_bg.name = "GaugeBG"
	gauge_bg.size = Vector2(300, 40)
	gauge_bg.position = Vector2(screen_size.x / 2 - 150, screen_size.y * 0.75)
	gauge_bg.color = Color(0.3, 0.3, 0.3)
	add_child(gauge_bg)
	
	# Green zone (randomized each shower)
	var green_zone = ColorRect.new()
	green_zone.name = "GreenZone"
	green_zone.size = Vector2(60, 40)
	green_zone.color = Color(0.2, 0.8, 0.2)
	gauge_bg.add_child(green_zone)
	
	# Gauge indicator
	var indicator = ColorRect.new()
	indicator.name = "Indicator"
	indicator.size = Vector2(10, 50)
	indicator.position = Vector2(0, -5)
	indicator.color = Color(1, 1, 1)
	gauge_bg.add_child(indicator)
	
	# Score display
	var score_display = Label.new()
	score_display.name = "ScoreDisplay"
	score_display.text = "🚿 0 / %d" % target_showers
	score_display.add_theme_font_size_override("font_size", 32)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(screen_size.x / 2 - 60, 120)
	add_child(score_display)
	
	# Start first shower
	_start_shower()

func _start_shower():
	shower_running = true
	gauge_position = 0.0
	gauge_direction = 1
	
	# Randomize green zone position
	target_zone_start = randf_range(50, 200)
	target_zone_end = target_zone_start + 60
	
	var green_zone = get_node("GaugeBG/GreenZone")
	green_zone.position.x = target_zone_start
	
	# Show water drops
	_spawn_water_drops()

func _spawn_water_drops():
	var drops = get_node("Drops")
	
	# Clear old drops
	for child in drops.get_children():
		child.queue_free()
	
	# Spawn new drops
	for i in range(8):
		var drop = Label.new()
		drop.text = "💧"
		drop.add_theme_font_size_override("font_size", randi_range(20, 35))
		drop.position = Vector2(randf_range(-50, 50), randf_range(0, 150))
		drop.modulate.a = randf_range(0.5, 1.0)
		drops.add_child(drop)

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	if shower_running:
		# Move gauge
		gauge_position += gauge_speed * gauge_direction * delta
		
		# Bounce at edges
		if gauge_position >= 290:
			gauge_direction = -1
		elif gauge_position <= 0:
			gauge_direction = 1
		
		# Update indicator
		var indicator = get_node("GaugeBG/Indicator")
		indicator.position.x = gauge_position
		
		# Animate water drops
		var drops = get_node("Drops")
		for drop in drops.get_children():
			drop.position.y += 100 * delta
			if drop.position.y > 200:
				drop.position.y = 0
				drop.position.x = randf_range(-50, 50)
		
		# Check for tap
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_check_timing()

func _check_timing():
	shower_running = false
	
	# Check if in green zone
	if gauge_position >= target_zone_start and gauge_position <= target_zone_end:
		_good_timing()
	else:
		_bad_timing()

func _good_timing():
	showers_taken += 1
	record_action(true)
	get_node("ScoreDisplay").text = "🚿 %d / %d" % [showers_taken, target_showers]
	
	# Flash green
	var flash = ColorRect.new()
	flash.color = Color(0, 1, 0, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)
	
	# Clear drops
	var drops = get_node("Drops")
	for child in drops.get_children():
		child.queue_free()
	
	if showers_taken >= target_showers:
		end_game(true)
	else:
		await get_tree().create_timer(0.8).timeout
		if game_active:
			_start_shower()

func _bad_timing():
	record_action(false)
	
	# Flash red
	var flash = ColorRect.new()
	flash.color = Color(1, 0, 0, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)
	
	# Restart same shower
	await get_tree().create_timer(0.5).timeout
	if game_active:
		_start_shower()
