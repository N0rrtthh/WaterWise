extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## BUCKET BRIGADE - Pass buckets down a line to save water (Kid-Friendly!)
## ═══════════════════════════════════════════════════════════════════
## SIMPLIFIED MECHANICS:
## - Buckets WAIT at each person until tapped
## - Large, easy tap targets
## - No falling/dropping - buckets just wait patiently
## - Encouraging feedback for every tap
## ═══════════════════════════════════════════════════════════════════

var people: Array = []
var bucket_at_person: Array = []  # Which person has a bucket (-1 = none)
var active_buckets: Array = []
var buckets_delivered: int = 0
var target_buckets: int = 8
var spawn_timer: float = 0.0
var spawn_interval: float = 3.0
var screen_size: Vector2

# Animation
var bucket_move_speed: float = 700.0
var person_colors: Array = [
	Color(1.0, 0.8, 0.6),  # Light skin
	Color(0.9, 0.7, 0.5),  # Medium skin  
	Color(0.7, 0.5, 0.3),  # Darker skin
	Color(0.85, 0.75, 0.55)
]

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			target_buckets = 3
			spawn_interval = 1.5
			game_duration = 20.0
		"Medium":
			target_buckets = 4
			spawn_interval = 1.0
			game_duration = 20.0
		"Hard":
			target_buckets = 5
			spawn_interval = 0.8
			game_duration = 20.0

func _ready():
	game_name = "Bucket Brigade"
	game_instruction_text = Localization.get_text("bucket_brigade_instructions") if Localization else "TAP the person with the bucket\nto pass it along! 🪣➡️🌱"
	game_duration = 40.0
	game_mode = "quota"
	
	super._ready()
	
	screen_size = get_viewport_rect().size
	
	# Background - Sunny outdoor scene
	_create_background()
	
	# Create 4 people in a line
	_create_people()
	
	# Water source (left) and destination (right)
	_create_source_and_destination()
	
	# Score display
	_create_score_display()
	
	# Spawn first bucket after a short delay
	spawn_timer = 1.0

func _create_background() -> void:
	# Sky gradient
	var sky = ColorRect.new()
	sky.color = Color(0.5, 0.8, 1.0)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.z_index = -10
	add_child(sky)
	
	# Sun
	var sun = Label.new()
	sun.text = "☀️"
	sun.add_theme_font_size_override("font_size", 80)
	sun.position = Vector2(screen_size.x - 120, 30)
	sun.z_index = -9
	add_child(sun)
	
	# Ground - Green grass
	var grass = ColorRect.new()
	grass.color = Color(0.4, 0.7, 0.3)
	grass.size = Vector2(screen_size.x, 180)
	grass.position = Vector2(0, screen_size.y - 180)
	grass.z_index = -5
	add_child(grass)
	
	# Some grass decorations
	for i in range(10):
		var grass_blade = Label.new()
		grass_blade.text = "🌿"
		grass_blade.add_theme_font_size_override("font_size", 30)
		grass_blade.position = Vector2(randf() * screen_size.x, screen_size.y - 140 + randf() * 40)
		grass_blade.z_index = -4
		add_child(grass_blade)

func _create_people() -> void:
	var num_people = 4
	var start_x = screen_size.x * 0.2
	var end_x = screen_size.x * 0.8
	var spacing = (end_x - start_x) / (num_people - 1)
	
	for i in range(num_people):
		var person = Node2D.new()
		person.name = "Person_%d" % i
		person.position = Vector2(
			start_x + spacing * i,
			screen_size.y - 220
		)
		add_child(person)
		
		# Tap area (invisible but large!)
		var tap_area = Area2D.new()
		tap_area.name = "TapArea"
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 80  # Nice big tap target!
		collision.shape = shape
		collision.position = Vector2(0, 0)
		tap_area.add_child(collision)
		person.add_child(tap_area)
		
		# Person body (cute emoji person)
		var body = Label.new()
		body.name = "Body"
		body.text = ["👦", "👧", "👨", "👩"][i % 4]
		body.add_theme_font_size_override("font_size", 70)
		body.position = Vector2(-35, -50)
		person.add_child(body)
		
		# Hand indicator (shows when they can receive/pass)
		var hand = Label.new()
		hand.name = "Hand"
		hand.text = "🙌"
		hand.add_theme_font_size_override("font_size", 40)
		hand.position = Vector2(-25, -100)
		hand.visible = false
		person.add_child(hand)
		
		# Bucket holder position
		var bucket_pos = Node2D.new()
		bucket_pos.name = "BucketPos"
		bucket_pos.position = Vector2(0, -20)
		person.add_child(bucket_pos)
		
		# "Tap me!" hint that pulses
		var hint = Label.new()
		hint.name = "TapHint"
		hint.text = "👆 TAP!"
		hint.add_theme_font_size_override("font_size", 24)
		hint.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
		hint.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0))
		hint.add_theme_constant_override("outline_size", 3)
		hint.position = Vector2(-40, -160)
		hint.visible = false
		person.add_child(hint)
		
		people.append(person)
		bucket_at_person.append(null)  # No bucket yet

func _create_source_and_destination() -> void:
	# Water source (left) - Water tap/faucet
	var source_container = Node2D.new()
	source_container.name = "WaterSource"
	source_container.position = Vector2(60, screen_size.y - 250)
	add_child(source_container)
	
	var source = Label.new()
	source.text = "🚰"
	source.add_theme_font_size_override("font_size", 70)
	source.position = Vector2(-30, 0)
	source_container.add_child(source)
	
	var source_label = Label.new()
	source_label.text = "WATER"
	source_label.add_theme_font_size_override("font_size", 20)
	source_label.add_theme_color_override("font_color", Color(0.2, 0.5, 0.8))
	source_label.position = Vector2(-30, 60)
	source_container.add_child(source_label)
	
	# Destination (right) - Garden that needs water
	var dest_container = Node2D.new()
	dest_container.name = "Garden"
	dest_container.position = Vector2(screen_size.x - 80, screen_size.y - 250)
	add_child(dest_container)
	
	var dest = Label.new()
	dest.name = "GardenEmoji"
	dest.text = "🌱"
	dest.add_theme_font_size_override("font_size", 70)
	dest.position = Vector2(-30, 0)
	dest_container.add_child(dest)
	
	var dest_label = Label.new()
	dest_label.text = "GARDEN"
	dest_label.add_theme_font_size_override("font_size", 20)
	dest_label.add_theme_color_override("font_color", Color(0.3, 0.6, 0.2))
	dest_label.position = Vector2(-35, 60)
	dest_container.add_child(dest_label)

func _create_score_display() -> void:
	var score_display = Label.new()
	score_display.name = "ScoreDisplay"
	score_display.text = "🪣 Delivered: 0 / %d" % target_buckets
	score_display.add_theme_font_size_override("font_size", 32)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color(0.2, 0.3, 0.5))
	score_display.add_theme_constant_override("outline_size", 5)
	score_display.position = Vector2(screen_size.x / 2 - 120, 120)
	add_child(score_display)
	
	# Progress bar
	var progress_bg = ColorRect.new()
	progress_bg.name = "ProgressBG"
	progress_bg.color = Color(0.3, 0.3, 0.4, 0.8)
	progress_bg.size = Vector2(300, 25)
	progress_bg.position = Vector2(screen_size.x / 2 - 150, 165)
	add_child(progress_bg)
	
	var progress_fill = ColorRect.new()
	progress_fill.name = "ProgressFill"
	progress_fill.color = Color(0.3, 0.8, 0.4)
	progress_fill.size = Vector2(0, 21)
	progress_fill.position = Vector2(screen_size.x / 2 - 148, 167)
	add_child(progress_fill)

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	# Spawn new buckets
	spawn_timer -= delta
	if spawn_timer <= 0 and _can_spawn_bucket():
		_spawn_bucket_at_source()
		spawn_timer = spawn_interval
	
	# Animate moving buckets
	_update_moving_buckets(delta)
	
	# Update tap hints (pulse animation)
	_update_tap_hints(delta)

func _can_spawn_bucket() -> bool:
	# Don't spawn if first person already has a bucket
	return bucket_at_person[0] == null

func _spawn_bucket_at_source() -> void:
	var bucket = _create_bucket()
	bucket.position = Vector2(60, screen_size.y - 220)
	add_child(bucket)
	
	# Animate bucket moving to first person
	bucket.set_meta("moving", true)
	bucket.set_meta("target_person", 0)
	active_buckets.append(bucket)

func _create_bucket() -> Node2D:
	var bucket = Node2D.new()
	bucket.name = "Bucket"
	
	# Bucket body (trapezoid shape)
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-30, -35), Vector2(30, -35),
		Vector2(25, 30), Vector2(-25, 30)
	])
	body.color = Color(0.4, 0.5, 0.9)  # Blue bucket
	bucket.add_child(body)
	
	# Bucket rim (top)
	var rim = Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-32, -40), Vector2(32, -40),
		Vector2(30, -35), Vector2(-30, -35)
	])
	rim.color = Color(0.3, 0.4, 0.8)
	bucket.add_child(rim)
	
	# Handle
	var handle = Line2D.new()
	handle.points = PackedVector2Array([Vector2(-22, -40), Vector2(0, -55), Vector2(22, -40)])
	handle.width = 5
	handle.default_color = Color(0.5, 0.5, 0.6)
	bucket.add_child(handle)
	
	# Water inside (with wave pattern)
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-27, -25), Vector2(-15, -30), Vector2(0, -25), Vector2(15, -30), Vector2(27, -25),
		Vector2(23, 25), Vector2(-23, 25)
	])
	water.color = Color(0.4, 0.8, 1.0, 0.85)
	bucket.add_child(water)
	
	# Sparkle on water
	var sparkle = Label.new()
	sparkle.text = "✨"
	sparkle.add_theme_font_size_override("font_size", 20)
	sparkle.position = Vector2(-10, -25)
	bucket.add_child(sparkle)
	
	return bucket

func _update_moving_buckets(delta: float) -> void:
	var to_remove: Array = []
	
	for bucket in active_buckets:
		if not is_instance_valid(bucket):
			to_remove.append(bucket)
			continue
		
		if not bucket.get_meta("moving"):
			continue
		
		var target_person_idx = bucket.get_meta("target_person")
		var target_pos: Vector2
		
		if target_person_idx >= people.size():
			# Moving to garden (destination)
			target_pos = Vector2(screen_size.x - 80, screen_size.y - 220)
		else:
			target_pos = people[target_person_idx].position + Vector2(0, -20)
		
		# Move toward target
		var direction = (target_pos - bucket.position).normalized()
		var distance = bucket.position.distance_to(target_pos)
		
		if distance < 10:
			# Arrived!
			bucket.position = target_pos
			bucket.set_meta("moving", false)
			
			if target_person_idx >= people.size():
				# Delivered to garden!
				_bucket_delivered(bucket)
				to_remove.append(bucket)
			else:
				# Arrived at person
				bucket_at_person[target_person_idx] = bucket
				_show_tap_hint(target_person_idx)
		else:
			bucket.position += direction * bucket_move_speed * delta
			# Gentle bobbing animation
			bucket.rotation = sin(Time.get_ticks_msec() * 0.01) * 0.1
	
	for b in to_remove:
		active_buckets.erase(b)

func _show_tap_hint(person_idx: int) -> void:
	var person = people[person_idx]
	var hint = person.get_node("TapHint")
	var hand = person.get_node("Hand")
	
	hint.visible = true
	hand.visible = true
	
	# Bouncy appear animation
	hint.scale = Vector2(0, 0)
	var tween = create_tween()
	tween.tween_property(hint, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_property(hint, "scale", Vector2(1, 1), 0.1)

func _hide_tap_hint(person_idx: int) -> void:
	var person = people[person_idx]
	var hint = person.get_node("TapHint")
	var hand = person.get_node("Hand")
	
	hint.visible = false
	hand.visible = false

func _update_tap_hints(_delta: float) -> void:
	# Make tap hints pulse/bounce
	for i in range(people.size()):
		if bucket_at_person[i] != null:
			var hint = people[i].get_node("TapHint")
			if hint.visible:
				var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.15
				hint.scale = Vector2(pulse, pulse)

func _input(event: InputEvent) -> void:
	if not game_active:
		return
	
	# Handle touch/click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)

func _handle_tap(tap_pos: Vector2) -> void:
	# Check if tapping on a person who has a bucket
	for i in range(people.size()):
		var person = people[i]
		var bucket = bucket_at_person[i]
		
		if bucket == null:
			continue  # No bucket to pass
		
		# Check tap distance (generous hitbox!)
		var distance = tap_pos.distance_to(person.position)
		if distance < 100:  # Big tap area for kids!
			_pass_bucket(i)
			return
	
	# Missed tap - no punishment, just a gentle hint
	# (No negative feedback for kids!)

func _pass_bucket(person_idx: int) -> void:
	var bucket = bucket_at_person[person_idx]
	if bucket == null:
		return
	
	# Clear bucket from current person
	bucket_at_person[person_idx] = null
	_hide_tap_hint(person_idx)
	
	# Record successful action
	record_action(true)
	
	# Celebrate!
	_show_success_feedback(people[person_idx].position)
	
	# Animate person passing
	var person = people[person_idx]
	var body = person.get_node("Body")
	var tween = create_tween()
	tween.tween_property(body, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(body, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK)
	
	# Move bucket to next person (or garden if last person)
	var next_idx = person_idx + 1
	bucket.set_meta("moving", true)
	bucket.set_meta("target_person", next_idx)

func _show_success_feedback(pos: Vector2) -> void:
	# Show encouraging text
	var texts = ["Great! 👍", "Nice! ⭐", "Yay! 🎉", "Good job! 💧", "Awesome! 🌟"]
	var feedback = Label.new()
	feedback.text = texts[randi() % texts.size()]
	feedback.add_theme_font_size_override("font_size", 28)
	feedback.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	feedback.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0))
	feedback.add_theme_constant_override("outline_size", 3)
	feedback.position = pos + Vector2(-40, -180)
	feedback.z_index = 100
	add_child(feedback)
	
	# Float up and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(feedback, "position:y", feedback.position.y - 60, 0.8)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(feedback.queue_free)

func _bucket_delivered(bucket: Node2D) -> void:
	buckets_delivered += 1
	
	# Update score display
	get_node("ScoreDisplay").text = "🪣 Delivered: %d / %d" % [buckets_delivered, target_buckets]
	
	# Update progress bar
	var progress = float(buckets_delivered) / float(target_buckets)
	var fill = get_node("ProgressFill")
	var tween = create_tween()
	tween.tween_property(fill, "size:x", 296 * progress, 0.3).set_trans(Tween.TRANS_BACK)
	
	# Celebrate delivery!
	_show_delivery_celebration(bucket.position)
	
	# Make garden grow a bit
	var garden = get_node("Garden/GardenEmoji")
	var growth_stage = mini(buckets_delivered, 4)
	var garden_emojis = ["🌱", "🌿", "🪴", "🌳", "🌳"]
	garden.text = garden_emojis[growth_stage]
	
	# Bounce animation for garden
	var gtween = create_tween()
	gtween.tween_property(garden, "scale", Vector2(1.4, 1.4), 0.15)
	gtween.tween_property(garden, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)
	
	# Remove bucket with splash
	var splash_tween = create_tween()
	splash_tween.tween_property(bucket, "scale", Vector2(1.3, 1.3), 0.1)
	splash_tween.tween_property(bucket, "scale", Vector2(0, 0), 0.2)
	splash_tween.tween_callback(bucket.queue_free)
	
	# Check win condition
	if buckets_delivered >= target_buckets:
		end_game(true)

func _show_delivery_celebration(pos: Vector2) -> void:
	# Water droplet particles
	for i in range(8):
		var drop = Label.new()
		drop.text = "💧"
		drop.add_theme_font_size_override("font_size", 24)
		drop.position = pos
		drop.z_index = 50
		add_child(drop)
		
		var angle = (PI * 2 / 8) * i
		var target = pos + Vector2(cos(angle), sin(angle)) * 80
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(drop, "position", target, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.2)
		tween.tween_property(drop, "modulate:a", 0.0, 0.5)
		tween.set_parallel(false)
		tween.tween_callback(drop.queue_free)
	
	# Big success star
	var star = Label.new()
	star.text = "⭐"
	star.add_theme_font_size_override("font_size", 50)
	star.position = pos + Vector2(-25, -50)
	star.z_index = 100
	star.scale = Vector2(0, 0)
	add_child(star)
	
	var star_tween = create_tween()
	star_tween.tween_property(star, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BACK)
	star_tween.tween_interval(0.3)
	star_tween.tween_property(star, "scale", Vector2(0, 0), 0.3)
	star_tween.tween_callback(star.queue_free)
