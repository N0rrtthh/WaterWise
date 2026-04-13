extends MultiplayerMiniGameBase

## Bundle 2: Shower Water Collection
## P1 collects shower water in buckets

const BUCKET_CAPACITY: int = 3
const MAX_OVERFLOW: int = 5

var water_collected: int = 0
var overflows: int = 0
var buckets: Array = []
var spawn_timer: Timer
var dragging_bucket: Area2D = null

func get_instructions() -> String:
	return "🚿 COLLECT SHOWER WATER\n\nCatch falling water drops in your 4 buckets!\nCatch 10 drops to win.\nEach bucket holds 3 drops before sending to partner.\n\n⚠️ Let 5 drops overflow and lose 1 life!\n🎯 Drag buckets under falling drops"

func get_controls_text() -> String:
	return "🖱️ Drag buckets\n🪣 Catch drops\n💧 Fill & send"

func _on_multiplayer_ready() -> void:
	game_name = "Collect Shower Water"
	win_quota = 50 # 10 drops * 5 points
	set_process_input(true)
	
	_create_buckets()
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.5
	spawn_timer.timeout.connect(_spawn_water_drop)
	add_child(spawn_timer)
	
	_log("🚿 Catch shower water! Overflow %d times = lose 1 life" % MAX_OVERFLOW)

func _on_game_start() -> void:
	spawn_timer.start()

func _create_buckets() -> void:
	for i in range(4):
		var bucket = Area2D.new()
		bucket.position = Vector2(200 + i * 220, 450)
		bucket.set_meta("water_level", 0)
		add_child(bucket)
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(100, 120)
		collision.shape = shape
		bucket.add_child(collision)
		
		var visual = Sprite2D.new()
		visual.name = "Visual"
		visual.texture = MiniGameAssets.create_bucket_texture(100, 120, Color(0.8, 0.8, 0.8)) # Metal bucket
		bucket.add_child(visual)
		
		var label = Label.new()
		label.name = "Label"
		label.text = "0/%d" % BUCKET_CAPACITY
		label.position = Vector2(-20, -80)
		label.add_theme_font_size_override("font_size", 20)
		bucket.add_child(label)
		
		bucket.input_event.connect(_on_bucket_input.bind(bucket))
		buckets.append(bucket)

func _on_bucket_input(_viewport: Node, event: InputEvent, _shape_idx: int, bucket: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_bucket = bucket

func _input(event: InputEvent) -> void:
	if not game_active:
		return
	
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_bucket = null
	
	if event is InputEventMouseMotion and dragging_bucket:
		dragging_bucket.position.x = get_global_mouse_position().x
		dragging_bucket.position.x = clamp(dragging_bucket.position.x, 50, get_viewport_rect().size.x - 50)

func _spawn_water_drop() -> void:
	var drop = Area2D.new()
	drop.position = Vector2(randf_range(100, 1000), -50)
	drop.set_meta("velocity", Vector2(0, 200))
	add_child(drop)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15
	collision.shape = shape
	drop.add_child(collision)
	
	var visual = ColorRect.new()
	visual.size = Vector2(30, 30)
	visual.position = Vector2(-15, -15)
	visual.color = Color(0.5, 0.7, 1.0)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.add_child(visual)
	
	drop.area_entered.connect(_on_drop_hit_bucket.bind(drop))

func _process(delta: float) -> void:
	if not game_active:
		return
	
	for child in get_children():
		if child is Area2D and child.has_meta("velocity"):
			child.position += child.get_meta("velocity") * delta
			
			if child.position.y > 700:
				overflows += 1
				_log("💧 Overflow! (%d/%d)" % [overflows, MAX_OVERFLOW])
				child.queue_free()
				
				if overflows >= MAX_OVERFLOW:
					overflows = 0
					if NetworkManager:
						NetworkManager.lose_life()

func _on_drop_hit_bucket(area: Area2D, drop: Area2D) -> void:
	if not area.has_meta("water_level"):
		return
	
	var level = area.get_meta("water_level", 0)
	if level >= BUCKET_CAPACITY:
		return  # Bucket full
	
	level += 1
	area.set_meta("water_level", level)
	area.get_node("Label").text = "%d/%d" % [level, BUCKET_CAPACITY]
	
	var visual = area.get_node("Visual")
	visual.modulate = Color(0.3, 0.6, 1.0, 0.3 + level * 0.2)
	
	water_collected += 1
	add_score(5)
	
	drop.queue_free()
	
	if level >= BUCKET_CAPACITY:
		_empty_bucket(area)

func _empty_bucket(bucket: Area2D) -> void:
	_log("🪣 Bucket full! Sending to partner")
	send_resource_to_partner("shower_water", BUCKET_CAPACITY, 1.0)
	
	bucket.set_meta("water_level", 0)
	bucket.get_node("Label").text = "0/%d" % BUCKET_CAPACITY
	bucket.get_node("Visual").modulate = Color(0.4, 0.4, 0.4, 0.3)

func _on_game_over() -> void:
	spawn_timer.stop()
	super._on_game_over()
