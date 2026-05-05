extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## ═══════════════════════════════════════════════════════════════════
## MP_FilterWater - Player 2 Game
## ═══════════════════════════════════════════════════════════════════
## Player 2 filters water that Player 1 collected
## Receives water from P1 and must click dirt particles to filter
## ═══════════════════════════════════════════════════════════════════

const DIRT_SPEED: float = 150.0
const PARTICLES_PER_WATER: int = 3
const QUOTA: int = 50  # Team needs 50 points total (shared with P1)
const AQUARIUM_WIDTH: float = 320.0
const AQUARIUM_HEIGHT: float = 160.0
const AQUARIUM_CAPACITY: int = 12

var water_queue: Array = []  # Water units received from P1
var filtered_count: int = 0
var dirt_particles: Array = []
var aquarium: Node2D
var aquarium_water: Polygon2D
var aquarium_fill_units: int = 0
var _layout_ready: bool = false

func get_instructions() -> String:
	return "Wait for water from your partner.\nClick on dirt particles to filter the water!"

func get_controls_text() -> String:
	return "🖱️ Click particles\n💧 Filter water\n⏸ Pause game"

func _on_multiplayer_ready() -> void:
	# Setup game when multiplayer is ready
	game_name = "Filter Water"
	connection_type = "resource_transfer"
	_connect_viewport_resize()
	_create_aquarium()
	
	_log("Game ready - Filter water sent by partner!")

func _on_game_start() -> void:
	# Called when game starts (after countdown)
	_log("Filtering started - waiting for water from partner...")

func _on_resource_received(_from_player: int, resource_type: String, amount: int, quality: float) -> void:
	# Receive water from Player 1
	if resource_type == "clean_water":
		water_queue.append({
			"amount": amount,
			"quality": quality
		})
		
		_log("📥 Received %d water units (quality: %.1f) - Queue: %d" % [amount, quality, water_queue.size()])
		
		# Spawn dirt particles to filter
		_spawn_dirt_particles(amount * PARTICLES_PER_WATER)
		aquarium_fill_units = min(AQUARIUM_CAPACITY, aquarium_fill_units + amount)
		_update_aquarium_fill()

func _create_aquarium() -> void:
	var screen_size = get_viewport_rect().size
	aquarium = Node2D.new()
	aquarium.position = Vector2(screen_size.x * 0.5, screen_size.y - 170)
	aquarium.z_as_relative = false
	aquarium.z_index = 20
	add_child(aquarium)

	var glass = Polygon2D.new()
	glass.polygon = PackedVector2Array([
		Vector2(-AQUARIUM_WIDTH * 0.5, -AQUARIUM_HEIGHT * 0.5),
		Vector2(AQUARIUM_WIDTH * 0.5, -AQUARIUM_HEIGHT * 0.5),
		Vector2(AQUARIUM_WIDTH * 0.5, AQUARIUM_HEIGHT * 0.5),
		Vector2(-AQUARIUM_WIDTH * 0.5, AQUARIUM_HEIGHT * 0.5)
	])
	glass.color = Color(0.85, 0.95, 1.0, 0.22)
	aquarium.add_child(glass)

	aquarium_water = Polygon2D.new()
	aquarium_water.color = Color(0.4, 0.7, 1.0, 0.45)
	aquarium.add_child(aquarium_water)
	_update_aquarium_fill()

	var border = Line2D.new()
	border.width = 4.0
	border.closed = true
	border.points = PackedVector2Array([
		Vector2(-AQUARIUM_WIDTH * 0.5, -AQUARIUM_HEIGHT * 0.5),
		Vector2(AQUARIUM_WIDTH * 0.5, -AQUARIUM_HEIGHT * 0.5),
		Vector2(AQUARIUM_WIDTH * 0.5, AQUARIUM_HEIGHT * 0.5),
		Vector2(-AQUARIUM_WIDTH * 0.5, AQUARIUM_HEIGHT * 0.5)
	])
	border.default_color = Color(0.25, 0.45, 0.65, 0.9)
	aquarium.add_child(border)

	var base = Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(-AQUARIUM_WIDTH * 0.5 - 16.0, AQUARIUM_HEIGHT * 0.5),
		Vector2(AQUARIUM_WIDTH * 0.5 + 16.0, AQUARIUM_HEIGHT * 0.5),
		Vector2(AQUARIUM_WIDTH * 0.5 + 26.0, AQUARIUM_HEIGHT * 0.5 + 22.0),
		Vector2(-AQUARIUM_WIDTH * 0.5 - 26.0, AQUARIUM_HEIGHT * 0.5 + 22.0)
	])
	base.color = Color(0.3, 0.4, 0.5, 0.9)
	base.z_index = -1
	aquarium.add_child(base)
	_update_aquarium_layout()

func _connect_viewport_resize() -> void:
	var viewport = get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	_update_aquarium_layout()

func _update_aquarium_layout() -> void:
	if aquarium == null:
		return
	var rect = get_viewport_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var cam = get_viewport().get_camera_2d() if get_viewport() else null
	var top_left = Vector2.ZERO
	if cam:
		top_left = cam.global_position - rect.size * 0.5
	aquarium.position = top_left + Vector2(rect.size.x * 0.5, rect.size.y - 170.0)
	_layout_ready = true

func _update_aquarium_fill() -> void:
	if aquarium_water == null:
		return
	var fill_ratio = clamp(float(aquarium_fill_units) / float(AQUARIUM_CAPACITY), 0.0, 1.0)
	var fill_height = AQUARIUM_HEIGHT * fill_ratio
	aquarium_water.polygon = PackedVector2Array([
		Vector2(-AQUARIUM_WIDTH * 0.5 + 8.0, AQUARIUM_HEIGHT * 0.5 - fill_height),
		Vector2(AQUARIUM_WIDTH * 0.5 - 8.0, AQUARIUM_HEIGHT * 0.5 - fill_height),
		Vector2(AQUARIUM_WIDTH * 0.5 - 8.0, AQUARIUM_HEIGHT * 0.5 - 8.0),
		Vector2(-AQUARIUM_WIDTH * 0.5 + 8.0, AQUARIUM_HEIGHT * 0.5 - 8.0)
	])

func _spawn_dirt_particles(count: int) -> void:
	# Spawn dirt particles that need to be clicked
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
		var sprite = Sprite2D.new()
		sprite.texture = MiniGameAssets.create_dirt_texture(20)
		particle.add_child(sprite)
		
		# Make clickable
		particle.input_event.connect(_on_particle_clicked.bind(particle))
		particle.set_meta("type", "dirt")
		particle.set_meta("velocity", Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * DIRT_SPEED)
		
		dirt_particles.append(particle)

func _on_particle_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, particle: Area2D) -> void:
	# Particle clicked - filter it!
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if particle.has_meta("type") and particle.get_meta("type") == "dirt":
			_filter_particle(particle)

func _filter_particle(particle: Area2D) -> void:
	# Filter a dirt particle
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
	# Check if enough particles filtered to complete a water unit
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
	if not _layout_ready:
		_update_aquarium_layout()
	
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
	# Show filter effect
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
	# Game over handling
	_log("Game over! Filtered: %d units" % filtered_count)
	super._on_game_over()
