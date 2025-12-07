extends MiniGameBase

var buckets: Array = []
var correct_bucket: Node2D = null
var shuffled: bool = false
var shuffle_timer: float = 0.0
var shuffle_swaps: int = 0
var max_swaps: int = 4
var shuffle_speed: float = 0.8
var can_click: bool = false
var plant_node: Node2D

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			max_swaps = 2
			shuffle_speed = 1.2  # Slower shuffle
			game_duration = 15.0
		"Medium":
			max_swaps = 4
			shuffle_speed = 0.8
			game_duration = 10.0
		"Hard":
			max_swaps = 7
			shuffle_speed = 0.4  # Fast shuffle
			game_duration = 8.0

func _ready():
	game_name = "Thirsty Plant"
	game_instruction_text = "Watch the GREEN bucket!\nTap it after shuffling!"
	game_duration = 10.0
	game_mode = "quota"
	timer_starts_paused = true  # Timer starts AFTER shuffle
	show_timer = false  # Hide timer during shuffle phase
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.6, 0.8, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Ground
	var ground = ColorRect.new()
	ground.color = Color(0.5, 0.35, 0.2)
	ground.position = Vector2(0, screen_size.y * 0.8)
	ground.size = Vector2(screen_size.x, screen_size.y * 0.2)
	ground.z_index = -5
	add_child(ground)
	
	# Plant
	plant_node = Node2D.new()
	plant_node.position = Vector2(screen_size.x * 0.5, screen_size.y * 0.35)
	add_child(plant_node)
	
	var pot = Polygon2D.new()
	pot.polygon = PackedVector2Array([
		Vector2(-50, 0), Vector2(50, 0),
		Vector2(40, 80), Vector2(-40, 80)
	])
	pot.color = Color(0.7, 0.4, 0.2)
	plant_node.add_child(pot)
	
	var stem = Line2D.new()
	stem.points = PackedVector2Array([Vector2(0, 0), Vector2(-10, -60), Vector2(0, -100)])
	stem.width = 8
	stem.default_color = Color(0.3, 0.5, 0.2)
	plant_node.add_child(stem)
	
	var leaf1 = Polygon2D.new()
	leaf1.polygon = PackedVector2Array([Vector2(0, 0), Vector2(-50, -20), Vector2(-40, 10)])
	leaf1.color = Color(0.5, 0.6, 0.3)
	leaf1.position = Vector2(-10, -60)
	plant_node.add_child(leaf1)
	
	var bubble = Label.new()
	bubble.text = "💧?"
	bubble.add_theme_font_size_override("font_size", 48)
	bubble.position = Vector2(60, -120)
	plant_node.add_child(bubble)
	
	# Buckets
	var positions = [
		Vector2(screen_size.x * 0.25, screen_size.y * 0.7),
		Vector2(screen_size.x * 0.5, screen_size.y * 0.7),
		Vector2(screen_size.x * 0.75, screen_size.y * 0.7)
	]
	
	for i in range(3):
		var is_correct = (i == 0)
		var bucket = _create_bucket(positions[i], is_correct)
		buckets.append(bucket)
		if is_correct:
			correct_bucket = bucket
	
	# Status
	var status = Label.new()
	status.text = "👀 Watch the GREEN bucket!"
	status.add_theme_font_size_override("font_size", 32)
	status.add_theme_color_override("font_color", Color.WHITE)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	status.add_theme_constant_override("outline_size", 4)
	status.position = Vector2(screen_size.x / 2 - 200, screen_size.y - 100)
	status.name = "StatusLabel"
	add_child(status)

func _create_bucket(pos: Vector2, is_correct: bool) -> Node2D:
	var bucket = Node2D.new()
	bucket.position = pos
	bucket.set_meta("is_correct", is_correct)
	add_child(bucket)
	
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-50, -60), Vector2(50, -60),
		Vector2(40, 60), Vector2(-40, 60)
	])
	body.color = Color(0.2, 0.8, 0.3) if is_correct else Color(0.3, 0.4, 0.8)
	body.name = "Body"
	bucket.add_child(body)
	
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-45, -30), Vector2(45, -30),
		Vector2(38, 55), Vector2(-38, 55)
	])
	water.color = Color(0.3, 0.6, 1.0, 0.7)
	bucket.add_child(water)
	
	return bucket

func _input(event):
	if not game_active or not can_click: return
	
	var tap_pos = Vector2.ZERO
	var is_tap = false
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
		is_tap = true
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
		is_tap = true
	
	if is_tap:
		for bucket in buckets:
			if tap_pos.distance_to(bucket.position) < 80:
				_on_bucket_pressed(bucket)
				break

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	var status = get_node("StatusLabel")
	
	# Shuffling phase
	if not shuffled:
		shuffle_timer += delta
		if shuffle_timer > shuffle_speed and shuffle_swaps < max_swaps:
			shuffle_timer = 0
			_swap_random_buckets()
			shuffle_swaps += 1
			status.text = "🔀 Shuffling... (%d/%d)" % [shuffle_swaps, max_swaps]
		elif shuffle_swaps >= max_swaps:
			shuffled = true
			can_click = true
			status.text = "👆 TAP the water bucket!"
			
			# Hide all bucket colors
			for bucket in buckets:
				bucket.get_node("Body").color = Color(0.3, 0.4, 0.8)
			
			# NOW start the timer
			show_timer = true
			start_timer_now()
			if timer_bar:
				timer_bar.visible = true

func _swap_random_buckets():
	var idx1 = randi() % buckets.size()
	var idx2 = (idx1 + 1 + randi() % (buckets.size() - 1)) % buckets.size()
	
	var b1 = buckets[idx1]
	var b2 = buckets[idx2]
	
	var pos1 = b1.position
	var pos2 = b2.position
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(b1, "position", pos2, 0.3).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(b2, "position", pos1, 0.3).set_trans(Tween.TRANS_QUAD)

func _on_bucket_pressed(bucket: Node2D):
	if not game_active or not can_click: return
	can_click = false
	
	var is_correct = bucket.get_meta("is_correct")
	
	if is_correct:
		record_action(true)
		bucket.get_node("Body").color = Color(0.2, 0.9, 0.3)
		
		var tween = create_tween()
		tween.tween_property(bucket, "position:y", plant_node.position.y, 0.5)
		tween.tween_callback(func(): _water_plant())
	else:
		record_action(false)
		bucket.get_node("Body").color = Color(0.9, 0.3, 0.3)
		correct_bucket.get_node("Body").color = Color(0.2, 0.9, 0.3)
		
		await get_tree().create_timer(1.0).timeout
		end_game(false)

func _water_plant():
	for child in plant_node.get_children():
		if child is Polygon2D and child.color.g < 0.7:
			child.color = Color(0.3, 0.8, 0.3)
	
	await get_tree().create_timer(0.5).timeout
	end_game(true)
