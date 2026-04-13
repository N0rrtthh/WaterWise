extends MultiplayerMiniGameBase

## Bundle 5: Collect Dish Water
## P1 catches water from dishwashing

const MAX_SPILLS: int = 5

var water_collected: int = 0
var spills: int = 0
var buckets: Array = []
var spawn_timer: Timer
var dragging_bucket: Area2D = null

func get_instructions() -> String:
	return "🍽️ COLLECT DISH WATER\n\nCatch water drops from dishwashing in buckets!\nCatch 10 drops to win.\nSend collected water to your partner.\n\n⚠️ Spill 5 drops and lose 1 life!\n🎯 Drag buckets under falling drops"

func get_controls_text() -> String:
	return "🖱️ Drag buckets\n🪣 Catch drops\n💧 Send water"

func _on_multiplayer_ready() -> void:
	game_name = "Collect Dish Water"
	win_quota = 50 # 10 drops * 5 points
	set_process_input(true)
	
	_create_buckets()
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.8
	spawn_timer.timeout.connect(_spawn_water_drop)
	add_child(spawn_timer)
	
	_log("🍽️ Catch dish water! %d spills = lose 1 life" % MAX_SPILLS)

func _on_game_start() -> void:
	spawn_timer.start()

func _create_buckets() -> void:
	for i in range(3):
		var bucket = Area2D.new()
		bucket.position = Vector2(288 + i * 288, 450)
		add_child(bucket)
		
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 60
		collision.shape = shape
		bucket.add_child(collision)
		
		var visual = Sprite2D.new()
		visual.texture = MiniGameAssets.create_bucket_texture(120, 120, Color(0.6, 0.6, 0.6)) # Metal bowl
		bucket.add_child(visual)
		
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
	drop.position = Vector2(randf_range(150, 1002), -50)
	drop.set_meta("velocity", Vector2(0, 220))
	drop.set_meta("type", "dishwater")
	add_child(drop)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 18
	collision.shape = shape
	drop.add_child(collision)
	
	var visual = ColorRect.new()
	visual.size = Vector2(36, 36)
	visual.position = Vector2(-18, -18)
	visual.color = Color(0.7, 0.7, 0.6)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.add_child(visual)
	
	drop.area_entered.connect(_on_drop_caught.bind(drop))

func _process(delta: float) -> void:
	if not game_active:
		return
	
	for child in get_children():
		if child is Area2D and child.has_meta("velocity"):
			child.position += child.get_meta("velocity") * delta
			
			if child.position.y > 700:
				spills += 1
				_log("💦 Spilled! (%d/%d)" % [spills, MAX_SPILLS])
				child.queue_free()
				
				if spills >= MAX_SPILLS:
					spills = 0
					if NetworkManager:
						NetworkManager.lose_life()

func _on_drop_caught(area: Area2D, drop: Area2D) -> void:
	if not buckets.has(area):
		return
	
	water_collected += 1
	add_score(5)
	
	if water_collected % 3 == 0:  # Every 3 drops
		send_resource_to_partner("dishwater", 3, 1.0)
		_log("📤 Sent dish water!")
	
	drop.queue_free()

func _on_game_over() -> void:
	spawn_timer.stop()
	super._on_game_over()
