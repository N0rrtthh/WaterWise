extends MultiplayerMiniGameBase

## ═══════════════════════════════════════════════════════════════════
## MP_FilterWater - Player 2 Game
## ═══════════════════════════════════════════════════════════════════
## Player 2 filters water that Player 1 collected
## Receives water from P1 and must click dirt particles to filter
## ═══════════════════════════════════════════════════════════════════

const DIRT_SPEED: float = 150.0
const PARTICLES_PER_WATER: int = 3

var water_queue: Array = []  # Water units received from P1
var filtered_count: int = 0
var dirt_particles: Array = []

func _on_multiplayer_ready() -> void:
	"""Setup game when multiplayer is ready"""
	game_name = "Filter Water"
	connection_type = "resource_transfer"
	
	_log("Game ready - Filter water sent by partner!")

func _on_game_start() -> void:
	"""Called when game starts (after countdown)"""
	_log("Filtering started - waiting for water from partner...")

func _on_resource_received(from_player: int, resource_type: String, amount: int, quality: float) -> void:
	"""Receive water from Player 1"""
	if resource_type == "clean_water":
		water_queue.append({
			"amount": amount,
			"quality": quality
		})
		
		_log("📥 Received %d water units (quality: %.1f) - Queue: %d" % [amount, quality, water_queue.size()])
		
		# Spawn dirt particles to filter
		_spawn_dirt_particles(amount * PARTICLES_PER_WATER)

func _spawn_dirt_particles(count: int) -> void:
	"""Spawn dirt particles that need to be clicked"""
	for i in range(count):
		var particle = Area2D.new()
		particle.position = Vector2(
			randf_range(100, get_viewport_rect().size.x - 100),
			randf_range(100, get_viewport_rect().size.y - 100)
		)
		add_child(particle)
		
		# Collision
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 20
		collision.shape = shape
		particle.add_child(collision)
		
		# Visual
		var sprite = ColorRect.new()
		sprite.size = Vector2(40, 40)
		sprite.color = Color(0.4, 0.3, 0.2, 0.8)
		sprite.position = Vector2(-20, -20)
		particle.add_child(sprite)
		
		# Make clickable
		particle.input_event.connect(_on_particle_clicked.bind(particle))
		particle.set_meta("type", "dirt")
		particle.set_meta("velocity", Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * DIRT_SPEED)
		
		dirt_particles.append(particle)

func _on_particle_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, particle: Area2D) -> void:
	"""Particle clicked - filter it!"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if particle.has_meta("type") and particle.get_meta("type") == "dirt":
			_filter_particle(particle)

func _filter_particle(particle: Area2D) -> void:
	"""Filter a dirt particle"""
	filtered_count += 1
	add_score(5)
	
	# Visual feedback
	_play_filter_effect(particle.global_position)
	
	dirt_particles.erase(particle)
	particle.queue_free()
	
	_log("✨ Filtered particle! Total: %d" % filtered_count)
	
	# Check if water unit is complete
	_check_water_unit_complete()

func _check_water_unit_complete() -> void:
	"""Check if enough particles filtered to complete a water unit"""
	if water_queue.is_empty():
		return
	
	# Safely access first element
	var first_unit = water_queue[0]
	var particles_needed = first_unit["amount"] * PARTICLES_PER_WATER
	
	if filtered_count >= particles_needed:
		# Water unit filtered!
		var _water_unit = water_queue.pop_front()
		add_score(20)  # Bonus for completing unit
		
		_log("💧 Water unit filtered! Bonus +20 points")
		
		# Reset counter for next unit
		filtered_count = 0

func _process(delta: float) -> void:
	if not game_active:
		return
	
	# Move dirt particles
	for particle in dirt_particles:
		if is_instance_valid(particle) and particle.has_meta("velocity"):
			var velocity = particle.get_meta("velocity") as Vector2
			particle.position += velocity * delta
			
			# Bounce off edges
			var screen_size = get_viewport_rect().size
			if particle.position.x < 50 or particle.position.x > screen_size.x - 50:
				velocity.x *= -1
				particle.set_meta("velocity", velocity)
			if particle.position.y < 50 or particle.position.y > screen_size.y - 50:
				velocity.y *= -1
				particle.set_meta("velocity", velocity)

func _play_filter_effect(pos: Vector2) -> void:
	"""Show filter effect"""
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.amount = 15
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 5.0
	particles.direction = Vector2(0, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.gravity = Vector2(0, 0)
	particles.color = Color(0.8, 0.9, 1.0)
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(0.5).timeout
	particles.queue_free()

func _on_game_over() -> void:
	"""Game over handling"""
	_log("Game over! Filtered: %d units" % filtered_count)
