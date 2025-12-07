extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## SCRUB TO SAVE - Rub/swipe to clean dishes efficiently
## ═══════════════════════════════════════════════════════════════════

var current_dish: Node2D = null
var dishes_cleaned: int = 0
var target_dishes: int = 5
var dirt_level: float = 100.0
var scrub_power: float = 15.0
var last_scrub_pos: Vector2 = Vector2.ZERO

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			target_dishes = 3
			scrub_power = 20.0
			game_duration = 30.0
		"Medium":
			target_dishes = 5
			scrub_power = 15.0
			game_duration = 25.0
		"Hard":
			target_dishes = 7
			scrub_power = 10.0
			game_duration = 20.0

func _ready():
	game_name = "Scrub To Save"
	game_instruction_text = Localization.get_text("scrub_save_instructions") if Localization else "RUB the dish to clean it!\nUse water wisely! 🍽️"
	game_duration = 25.0
	game_mode = "quota"
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background - Kitchen
	var bg = ColorRect.new()
	bg.color = Color(0.95, 0.92, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Sink
	var sink = Polygon2D.new()
	sink.polygon = PackedVector2Array([
		Vector2(-180, -100), Vector2(180, -100),
		Vector2(160, 100), Vector2(-160, 100)
	])
	sink.color = Color(0.85, 0.85, 0.9)
	sink.position = Vector2(screen_size.x / 2, screen_size.y * 0.55)
	add_child(sink)
	
	# Sink rim
	var rim = Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-190, -110), Vector2(190, -110),
		Vector2(190, -100), Vector2(-190, -100)
	])
	rim.color = Color(0.7, 0.7, 0.75)
	rim.position = Vector2(screen_size.x / 2, screen_size.y * 0.55)
	add_child(rim)
	
	# Progress display
	var progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.text = "Dirt: 100%"
	progress_label.add_theme_font_size_override("font_size", 28)
	progress_label.add_theme_color_override("font_color", Color.WHITE)
	progress_label.add_theme_color_override("font_outline_color", Color.BLACK)
	progress_label.add_theme_constant_override("outline_size", 4)
	progress_label.position = Vector2(screen_size.x / 2 - 60, screen_size.y * 0.78)
	add_child(progress_label)
	
	# Score display
	var score_display = Label.new()
	score_display.name = "ScoreDisplay"
	score_display.text = "🍽️ 0 / %d" % target_dishes
	score_display.add_theme_font_size_override("font_size", 28)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(screen_size.x / 2 - 60, 120)
	add_child(score_display)
	
	# Sponge indicator
	var sponge = Label.new()
	sponge.name = "Sponge"
	sponge.text = "🧽"
	sponge.add_theme_font_size_override("font_size", 50)
	sponge.visible = false
	add_child(sponge)
	
	_spawn_dish()

func _spawn_dish():
	var screen_size = get_viewport_rect().size
	
	if current_dish:
		current_dish.queue_free()
	
	dirt_level = 100.0
	
	current_dish = Node2D.new()
	current_dish.position = Vector2(screen_size.x / 2, screen_size.y * 0.5)
	add_child(current_dish)
	
	# Random dish type
	var dish_types = ["🍽️", "🥣", "🍲", "🥤", "🍳"]
	var dish_emoji = dish_types[randi() % dish_types.size()]
	
	# Plate base
	var plate = Polygon2D.new()
	plate.name = "Plate"
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32
		points.append(Vector2(cos(angle) * 80, sin(angle) * 80))
	plate.polygon = points
	plate.color = Color(0.95, 0.95, 0.98)
	current_dish.add_child(plate)
	
	# Dish icon
	var icon = Label.new()
	icon.text = dish_emoji
	icon.add_theme_font_size_override("font_size", 60)
	icon.position = Vector2(-30, -35)
	current_dish.add_child(icon)
	
	# Dirt overlay
	var dirt = Node2D.new()
	dirt.name = "Dirt"
	current_dish.add_child(dirt)
	
	# Spawn dirt spots
	for i in range(12):
		var spot = Polygon2D.new()
		var spot_points = PackedVector2Array()
		var size = randf_range(15, 35)
		for j in range(8):
			var angle = j * TAU / 8 + randf_range(-0.3, 0.3)
			spot_points.append(Vector2(cos(angle) * size, sin(angle) * size))
		spot.polygon = spot_points
		spot.color = Color(0.4, 0.3, 0.2, 0.7)
		spot.position = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		dirt.add_child(spot)
	
	# Pop-in animation
	current_dish.scale = Vector2.ZERO
	var tw = create_tween()
	tw.tween_property(current_dish, "scale", Vector2(1, 1), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	_handle_scrubbing()
	_update_dirt_visual()

func _handle_scrubbing():
	var mouse_pos = get_viewport().get_mouse_position()
	var sponge = get_node("Sponge")
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		sponge.visible = true
		sponge.position = mouse_pos - Vector2(25, 25)
		
		# Check if over dish
		if current_dish and mouse_pos.distance_to(current_dish.position) < 100:
			# Calculate scrub distance
			if last_scrub_pos != Vector2.ZERO:
				var scrub_dist = mouse_pos.distance_to(last_scrub_pos)
				if scrub_dist > 5:  # Minimum movement
					dirt_level -= scrub_power * (scrub_dist / 50.0) * get_process_delta_time() * 60
					dirt_level = max(0, dirt_level)
					
					# Scrub effect
					_spawn_bubbles(mouse_pos)
					
					# Shake dish slightly
					current_dish.rotation = randf_range(-0.02, 0.02)
		
		last_scrub_pos = mouse_pos
	else:
		sponge.visible = false
		last_scrub_pos = Vector2.ZERO
		if current_dish:
			current_dish.rotation = 0
	
	# Update progress
	get_node("ProgressLabel").text = "Dirt: %.0f%%" % dirt_level
	
	# Check if clean
	if dirt_level <= 0:
		_dish_cleaned()

func _update_dirt_visual():
	if not current_dish: return
	
	var dirt = current_dish.get_node("Dirt")
	var alpha = dirt_level / 100.0
	
	for spot in dirt.get_children():
		spot.modulate.a = alpha

func _spawn_bubbles(pos: Vector2):
	for i in range(2):
		var bubble = Label.new()
		bubble.text = "○"
		bubble.add_theme_font_size_override("font_size", randi_range(10, 20))
		bubble.modulate = Color(1, 1, 1, 0.8)
		bubble.position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		add_child(bubble)
		
		var tw = create_tween()
		tw.tween_property(bubble, "position:y", bubble.position.y - 30, 0.5)
		tw.parallel().tween_property(bubble, "modulate:a", 0.0, 0.5)
		tw.tween_callback(bubble.queue_free)

func _dish_cleaned():
	dishes_cleaned += 1
	record_action(true)
	get_node("ScoreDisplay").text = "🍽️ %d / %d" % [dishes_cleaned, target_dishes]
	
	# Success animation
	var tw = create_tween()
	tw.tween_property(current_dish, "scale", Vector2(1.2, 1.2), 0.1)
	tw.tween_property(current_dish, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_property(current_dish, "modulate:a", 0.0, 0.2)
	
	var flash = ColorRect.new()
	flash.color = Color(0, 1, 0, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var ftw = create_tween()
	ftw.tween_property(flash, "modulate:a", 0.0, 0.3)
	ftw.tween_callback(flash.queue_free)
	
	if dishes_cleaned >= target_dishes:
		await get_tree().create_timer(0.3).timeout
		end_game(true)
	else:
		await get_tree().create_timer(0.5).timeout
		if game_active:
			_spawn_dish()
