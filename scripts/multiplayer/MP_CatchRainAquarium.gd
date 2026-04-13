extends MultiplayerMiniGameBase

## Bundle 3: Rain Collection for Aquarium
## P1 catches raindrops for aquarium

const MAX_MISSED: int = 5

var drops_caught: int = 0
var drops_missed: int = 0
var bucket: Area2D
var spawn_timer: Timer

func get_instructions() -> String:
	return "🌧️ CATCH RAIN\n\nMove your bucket left/right to catch falling raindrops!\nCatch 10 drops to win.\n\n⚠️ Miss 5 drops and lose 1 life!\n← → Use arrow keys or mouse to move bucket"

func get_controls_text() -> String:
	return "🖱️ Move mouse\n🪣 Catch rain\n💧 Fill aquarium"

func _on_multiplayer_ready() -> void:
	game_name = "Catch Rain for Aquarium"
	win_quota = 50 # 10 drops * 5 points
	
	_create_bucket()
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.2
	spawn_timer.timeout.connect(_spawn_raindrop)
	add_child(spawn_timer)
	
	_log("🌧️ Catch rain! Miss %d = lose 1 life" % MAX_MISSED)

func _on_game_start() -> void:
	spawn_timer.start()

func _create_bucket() -> void:
	bucket = Area2D.new()
	bucket.position = Vector2(576, 550)
	add_child(bucket)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(120, 40)
	collision.shape = shape
	bucket.add_child(collision)
	
	var visual = Sprite2D.new()
	visual.texture = MiniGameAssets.create_bucket_texture(120, 40, Color(0.3, 0.3, 0.3))
	bucket.add_child(visual)

func _spawn_raindrop() -> void:
	var drop = Area2D.new()
	drop.position = Vector2(randf_range(100, 1052), -50)
	drop.set_meta("velocity", Vector2(0, 250))
	drop.set_meta("type", "raindrop")
	add_child(drop)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12
	collision.shape = shape
	drop.add_child(collision)
	
	var visual = ColorRect.new()
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	visual.color = Color(0.4, 0.7, 1.0)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.add_child(visual)
	
	drop.area_entered.connect(_on_drop_hit.bind(drop))

func _process(delta: float) -> void:
	if not game_active:
		return
	
	# Move bucket with mouse
	if bucket:
		bucket.position.x = get_global_mouse_position().x
		bucket.position.x = clamp(bucket.position.x, 60, 1092)
	
	# Move drops
	for child in get_children():
		if child is Area2D and child.has_meta("velocity"):
			child.position += child.get_meta("velocity") * delta
			
			if child.position.y > 700:
				drops_missed += 1
				_log("❌ Missed! (%d/%d)" % [drops_missed, MAX_MISSED])
				child.queue_free()
				
				if drops_missed >= MAX_MISSED:
					drops_missed = 0
					if NetworkManager:
						NetworkManager.lose_life()

func _on_drop_hit(area: Area2D, drop: Area2D) -> void:
	if area != bucket:
		return
	
	drops_caught += 1
	add_score(5)
	
	send_resource_to_partner("rainwater", 1, 1.0)
	_log("💧 Caught drop! Total: %d" % drops_caught)
	
	drop.queue_free()

func _on_game_over() -> void:
	spawn_timer.stop()
	super._on_game_over()
