extends MiniGameBase

var buckets: Array = []
var spawn_timer: float = 0.0
var spawn_interval: float = 0.8
var bucket_speed: float = 180.0
var sorted_correct: int = 0
var target_sort: int = 12
var max_buckets_on_screen: int = 5

var swipe_start: Vector2 = Vector2.ZERO
var is_swiping: bool = false
var current_bucket: Node2D = null

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			spawn_interval = 1.0
			bucket_speed = 150.0
			target_sort = 6
			max_buckets_on_screen = 3
			game_duration = 18.0
		"Medium":
			spawn_interval = 0.7
			bucket_speed = 220.0
			target_sort = 8
			max_buckets_on_screen = 4
			game_duration = 15.0
		"Hard":
			spawn_interval = 0.4
			bucket_speed = 320.0
			target_sort = 10
			max_buckets_on_screen = 5
			game_duration = 12.0

func _ready():
	game_name = "Greywater Sorter"
	game_instruction_text = Localization.get_text("greywater_sorter_instructions") if Localization else "SWIPE buckets left or right!\n🌿 Garden = Blue | 🚿 Drain = Brown"
	game_duration = 25.0
	game_mode = "quota"  # Must sort target amount before time runs out
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.85, 0.9, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Left zone - Garden
	var left_zone = ColorRect.new()
	left_zone.color = Color(0.3, 0.7, 0.3, 0.5)
	left_zone.size = Vector2(screen_size.x * 0.25, screen_size.y)
	left_zone.z_index = -5
	add_child(left_zone)
	
	var garden_label = Label.new()
	garden_label.text = "🌿\nGARDEN"
	garden_label.add_theme_font_size_override("font_size", 28)
	garden_label.add_theme_color_override("font_color", Color.WHITE)
	garden_label.add_theme_color_override("font_outline_color", Color(0.2, 0.5, 0.2))
	garden_label.add_theme_constant_override("outline_size", 4)
	garden_label.position = Vector2(screen_size.x * 0.08, screen_size.y * 0.4)
	add_child(garden_label)
	
	# Right zone - Drain
	var right_zone = ColorRect.new()
	right_zone.color = Color(0.5, 0.4, 0.4, 0.5)
	right_zone.size = Vector2(screen_size.x * 0.25, screen_size.y)
	right_zone.position = Vector2(screen_size.x * 0.75, 0)
	right_zone.z_index = -5
	add_child(right_zone)
	
	var drain_label = Label.new()
	drain_label.text = "🚿\nDRAIN"
	drain_label.add_theme_font_size_override("font_size", 28)
	drain_label.add_theme_color_override("font_color", Color.WHITE)
	drain_label.add_theme_color_override("font_outline_color", Color(0.4, 0.3, 0.3))
	drain_label.add_theme_constant_override("outline_size", 4)
	drain_label.position = Vector2(screen_size.x * 0.83, screen_size.y * 0.4)
	add_child(drain_label)
	
	# Score
	var local_score_label = Label.new()
	local_score_label.name = "ScoreLabel"
	local_score_label.text = "✓ Sorted: 0 / %d" % target_sort
	local_score_label.add_theme_font_size_override("font_size", 28)
	local_score_label.add_theme_color_override("font_color", Color.WHITE)
	local_score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	local_score_label.add_theme_constant_override("outline_size", 4)
	local_score_label.position = Vector2(screen_size.x / 2 - 100, 120)
	add_child(local_score_label)

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	# Spawn multiple buckets (limit based on difficulty)
	spawn_timer -= delta
	if spawn_timer <= 0 and buckets.size() < max_buckets_on_screen:
		_spawn_bucket()
		spawn_timer = spawn_interval
	
	# Move buckets down
	var to_remove = []
	for bucket in buckets:
		if not is_instance_valid(bucket):
			to_remove.append(bucket)
			continue
			
		if bucket != current_bucket:
			bucket.position.y += bucket_speed * delta
		
		# Missed - gone off screen (NOT a failure, just missed opportunity)
		if bucket.position.y > get_viewport_rect().size.y + 50:
			# Don't record as failure - bucket just went past
			to_remove.append(bucket)
			bucket.queue_free()
	
	for b in to_remove:
		buckets.erase(b)
	
	_handle_input()

func _handle_input():
	var mouse_pos = get_viewport().get_mouse_position()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_swiping:
			is_swiping = true
			swipe_start = mouse_pos
			
			for bucket in buckets:
				if is_instance_valid(bucket) and bucket.global_position.distance_to(mouse_pos) < 80:
					current_bucket = bucket
					bucket.scale = Vector2(1.15, 1.15)
					break
		
		elif current_bucket:
			current_bucket.position.x = mouse_pos.x
	else:
		if is_swiping and current_bucket:
			var screen_w = get_viewport_rect().size.x
			current_bucket.scale = Vector2(1.0, 1.0)
			
			if current_bucket.position.x < screen_w * 0.3:
				_sort_bucket(current_bucket, true)  # To garden
			elif current_bucket.position.x > screen_w * 0.7:
				_sort_bucket(current_bucket, false)  # To drain
			else:
				# WRONG: Remove bucket anyway (disappear)
				buckets.erase(current_bucket)
				var tw = create_tween()
				tw.tween_property(current_bucket, "modulate:a", 0.0, 0.2)
				tw.tween_callback(current_bucket.queue_free)
			
			current_bucket = null
		
		is_swiping = false

func _spawn_bucket():
	var is_safe = randf() > 0.5
	var screen_size = get_viewport_rect().size
	
	var bucket = Node2D.new()
	# Random horizontal position
	bucket.position = Vector2(randf_range(screen_size.x * 0.3, screen_size.x * 0.7), -80)
	bucket.set_meta("safe", is_safe)
	add_child(bucket)
	
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-45, -50), Vector2(45, -50),
		Vector2(40, 50), Vector2(-40, 50)
	])
	
	if is_safe:
		body.color = Color(0.3, 0.6, 0.9)  # Blue
	else:
		body.color = Color(0.55, 0.4, 0.3)  # Brown
	bucket.add_child(body)
	
	var rim = Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-48, -55), Vector2(48, -55),
		Vector2(48, -45), Vector2(-48, -45)
	])
	rim.color = body.color.darkened(0.2)
	bucket.add_child(rim)
	
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-40, -40), Vector2(40, -40),
		Vector2(35, 45), Vector2(-35, 45)
	])
	water.color = Color(0.4, 0.75, 1.0, 0.7) if is_safe else Color(0.5, 0.45, 0.4, 0.7)
	bucket.add_child(water)
	
	var lbl = Label.new()
	lbl.text = "💧" if is_safe else "🟤"
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.position = Vector2(-18, -25)
	bucket.add_child(lbl)
	
	buckets.append(bucket)

func _sort_bucket(bucket: Node2D, to_garden: bool):
	var is_safe = bucket.get_meta("safe")
	var correct = (is_safe and to_garden) or (not is_safe and not to_garden)
	
	var screen_w = get_viewport_rect().size.x
	var target_x = -100.0 if to_garden else screen_w + 100.0
	
	buckets.erase(bucket)
	
	var tween = create_tween()
	
	if correct:
		sorted_correct += 1
		record_action(true)
		get_node("ScoreLabel").text = "✓ Sorted: %d / %d" % [sorted_correct, target_sort]
		
		tween.tween_property(bucket, "position:x", target_x, 0.3)
		tween.tween_callback(bucket.queue_free)
		
		if sorted_correct >= target_sort:
			await get_tree().create_timer(0.4).timeout
			end_game(true)
	else:
		record_action(false)
		
		# Flash red and remove
		bucket.modulate = Color(1, 0.3, 0.3)
		tween.tween_property(bucket, "modulate:a", 0.0, 0.3)
		tween.tween_callback(bucket.queue_free)
