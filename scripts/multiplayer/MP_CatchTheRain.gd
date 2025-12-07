extends MultiplayerMiniGameBase

## ═══════════════════════════════════════════════════════════════════
## MP_CatchTheRain - Player 1 Game
## ═══════════════════════════════════════════════════════════════════
## Player 1 catches falling raindrops with a bucket
## Caught water is sent to Player 2 for filtering
## ═══════════════════════════════════════════════════════════════════

const DROP_SPEED: float = 200.0
const SPAWN_INTERVAL: float = 1.5
const BUCKET_SPEED: float = 400.0

var bucket: Area2D
var spawn_timer: Timer
var drops_caught: int = 0
var drops_missed: int = 0

func _on_multiplayer_ready() -> void:
	"""Setup game when multiplayer is ready"""
	game_name = "Catch the Rain"
	connection_type = "resource_transfer"
	
	# Create bucket
	_create_bucket()
	
	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = SPAWN_INTERVAL
	spawn_timer.timeout.connect(_spawn_raindrop)
	add_child(spawn_timer)
	
	_log("Game ready - Catch raindrops to send water to partner!")

func _on_game_start() -> void:
	"""Called when game starts (after countdown)"""
	spawn_timer.start()
	_log("Catching rain started!")

func _create_bucket() -> void:
	"""Create the player's bucket"""
	bucket = Area2D.new()
	bucket.position = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y - 100)
	add_child(bucket)
	
	# Collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 30)
	collision.shape = shape
	bucket.add_child(collision)
	
	# Visual (simple rect)
	var rect = ColorRect.new()
	rect.size = Vector2(100, 30)
	rect.color = Color(0.4, 0.6, 0.8)
	rect.position = Vector2(-50, -15)
	bucket.add_child(rect)
	
	# Connect collision
	bucket.area_entered.connect(_on_bucket_collision)

func _spawn_raindrop() -> void:
	"""Spawn a falling raindrop"""
	if not game_active:
		return
	
	var drop = Area2D.new()
	drop.position = Vector2(randf_range(50, get_viewport_rect().size.x - 50), -20)
	add_child(drop)
	
	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15
	collision.shape = shape
	drop.add_child(collision)
	
	# Visual
	var sprite = Sprite2D.new()
	sprite.texture = _create_drop_texture()
	drop.add_child(sprite)
	
	# Add to moving group
	drop.set_meta("velocity", Vector2(0, DROP_SPEED))
	drop.set_meta("type", "raindrop")

func _create_drop_texture() -> ImageTexture:
	"""Create a simple water drop texture"""
	var image = Image.create(30, 30, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Draw circle
	for x in range(30):
		for y in range(30):
			var dist = Vector2(x - 15, y - 15).length()
			if dist < 12:
				image.set_pixel(x, y, Color(0.3, 0.7, 1.0, 0.8))
	
	return ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
	if not game_active:
		return
	
	# Move bucket with input
	var input_dir = Input.get_axis("ui_left", "ui_right")
	if input_dir != 0 and bucket:
		bucket.position.x += input_dir * BUCKET_SPEED * delta
		bucket.position.x = clamp(bucket.position.x, 50, get_viewport_rect().size.x - 50)
	
	# Move all drops
	for child in get_children():
		if child is Area2D and child.has_meta("velocity"):
			var velocity = child.get_meta("velocity") as Vector2
			child.position += velocity * delta
			
			# Remove if off screen
			if child.position.y > get_viewport_rect().size.y + 50:
				_on_drop_missed()
				child.queue_free()

func _on_bucket_collision(area: Area2D) -> void:
	"""Raindrop caught!"""
	if not area.has_meta("type"):
		return
	
	if area.get_meta("type") == "raindrop":
		drops_caught += 1
		add_score(10)
		
		# Send water resource to partner
		send_resource_to_partner("clean_water", 1, 1.0)
		
		# Visual feedback
		_play_catch_effect(area.global_position)
		
		area.queue_free()
		_log("💧 Caught raindrop! Total: %d" % drops_caught)

func _on_drop_missed() -> void:
	"""Raindrop missed!"""
	drops_missed += 1
	_log("❌ Missed raindrop! Missed: %d" % drops_missed)
	
	# Fail if too many misses
	if drops_missed >= 3:
		_log("💔 Too many misses - game failed!")
		end_game(false)

func _play_catch_effect(pos: Vector2) -> void:
	"""Show catch effect"""
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 5.0
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.gravity = Vector2(0, 200)
	particles.color = Color(0.3, 0.7, 1.0)
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _on_game_over() -> void:
	"""Game over handling"""
	spawn_timer.stop()
	_log("Game over! Caught: %d, Missed: %d" % [drops_caught, drops_missed])
