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
const MAX_ALLOWED_MISSES: int = 3
const QUOTA: int = 50  # Team needs 50 points total to win

var bucket: Area2D
var spawn_timer: Timer
var drops_caught: int = 0
var drops_missed: int = 0

func get_instructions() -> String:
	return "Move the bucket with LEFT/RIGHT keys to catch raindrops.\nAvoid missing drops!"

func get_controls_text() -> String:
	return "⬅️ ➡️ Arrows or Mouse\n🪣 Move bucket\n💧 Catch raindrops"

func _on_multiplayer_ready() -> void:
	"""Setup game when multiplayer is ready"""
	game_name = "Catch the Rain"
	connection_type = "resource_transfer"
	
	# Set quota for this round (use Rolling Window from GameManager)
	if GameManager:
		var difficulty_mult = GameManager.difficulty_multiplier
		var adjusted_quota = int(QUOTA * difficulty_mult)
		GameManager.set_minigame_quota(adjusted_quota)
		_log("🎯 Team quota set to: %d (base: %d, mult: %.2f)" % [adjusted_quota, QUOTA, difficulty_mult])
	
	# Create bucket
	_create_bucket()
	
	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = SPAWN_INTERVAL / max(1.0, GameManager.difficulty_multiplier if GameManager else 1.0)
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
	
	# Visual (Sprite)
	var sprite = Sprite2D.new()
	sprite.texture = MiniGameAssets.create_bucket_texture(100, 40, Color(1.0, 0.6, 0.2)) # Orange bucket
	sprite.position = Vector2(0, 0)
	bucket.add_child(sprite)
	
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
	sprite.texture = MiniGameAssets.create_drop_texture(15, Color(0.3, 0.7, 1.0))
	drop.add_child(sprite)
	
	# Add to moving group
	drop.set_meta("velocity", Vector2(0, DROP_SPEED))
	drop.set_meta("type", "raindrop")

func _process(delta: float) -> void:
	if not game_active:
		return
	
	# Move bucket with input (Keyboard or Mouse)
	if bucket:
		var input_dir = Input.get_axis("ui_left", "ui_right")
		if input_dir != 0:
			bucket.position.x += input_dir * BUCKET_SPEED * delta
		else:
			# Mouse control fallback
			var mouse_x = get_global_mouse_position().x
			# Only move if mouse is inside window horizontally
			if mouse_x > 0 and mouse_x < get_viewport_rect().size.x:
				# Smoothly move towards mouse
				bucket.position.x = lerp(bucket.position.x, mouse_x, 10 * delta)
		
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
	if drops_missed >= MAX_ALLOWED_MISSES:
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
	super._on_game_over()
