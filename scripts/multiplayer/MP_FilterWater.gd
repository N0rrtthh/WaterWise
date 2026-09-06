extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## ═══════════════════════════════════════════════════════════════════
## MP_FilterWater - Player 2 Game
## ═══════════════════════════════════════════════════════════════════
## Player 2 filters water that Player 1 collected
## Receives water from P1 and must click dirt particles to filter
## ═══════════════════════════════════════════════════════════════════

const DIRT_SPEED: float = 150.0
const PARTICLES_PER_WATER: int = 2   # was 3 — fewer particles = less work per water unit
## WHAT FILTERING PAYS, AND THE TEAM TOTAL THAT ENDS THE ROUND
##
## The bonus for finishing a unit was 20 on top of PARTICLES_PER_WATER * 5 for the specks — 30
## team points for one unit of water, three times what the partner earns for catching the drop
## that carried it, and enough that the old 50-point "team quota" (declared here and read by
## nothing) would have been passed by the second drop of the round. A 5-point bonus keeps the
## shape — finishing a unit is worth more than one more speck — while leaving a unit worth 15,
## so a drop caught here and filtered there is 20 team points and TEAM_TARGET is ten of them.
##
## PARTICLES_PER_WATER taps per unit is what makes this the demanding half of the pair: ten
## units is 20 taps inside a 30-second round, so the target needs the round rather than filling
## itself from the partner's supply.
const POINTS_PER_PARTICLE: int = 5
const BONUS_PER_UNIT: int = 5
const TEAM_TARGET: int = 200  # matches MP_CatchTheRain's TEAM_TARGET
const AQUARIUM_WIDTH: float = 320.0
const AQUARIUM_HEIGHT: float = 160.0
const AQUARIUM_CAPACITY: int = 12
const DIRT_MARGIN: float = 100.0
## Dirt is kept out of the bottom strip the aquarium occupies (it sits 170px above the visible
## bottom and stands 160px tall) so a particle never hides behind the glass.
const DIRT_MARGIN_BOTTOM: float = 280.0
## HOW BIG THE DIRT SPECK A FINGER HAS TO LAND ON IS
##
## 74 units of radius is a 148-unit target, which clears the 48dp Android/WCAG floor on the
## densest profile this game ships to (WVGA 4.5in, 217.7dpi -> 147 canvas units). The old radius
## of 20 gave a 40-unit target - 13dp, barely a quarter of the floor. Nothing grows an Area2D
## collision shape: MobileUIManager._on_node_added() only reaches Controls, so unlike a Button
## this number is the number the player gets and it has to be right here.
const DIRT_HIT_RADIUS: float = 74.0
## The art stays much smaller than the target, deliberately. Android sizes the TARGET at 48dp and
## lets the glyph inside it be smaller; a 148-unit blob would read as a boulder, not a speck of
## dirt, and the game is about noticing specks. Generated once at DIRT_TEX_RADIUS and scaled on
## the Sprite2D rather than drawn at display size, because MiniGameAssets.create_dirt_texture()
## is a per-pixel GDScript loop and drawing 60x60 instead of 40x40 would cost 2.25x per particle
## on a phone that spawns them mid-round.
const DIRT_ART_RADIUS: float = 30.0
const DIRT_TEX_RADIUS: int = 20

var water_queue: Array = []  # Water units received from P1
var filtered_count: int = 0
var dirt_particles: Array = []
var aquarium: Node2D
var aquarium_water: Polygon2D
var aquarium_fill_units: int = 0
var _layout_ready: bool = false

func get_instructions() -> String:
	return Localization.get_text("mp_filter_water_instructions") % [POINTS_PER_PARTICLE, PARTICLES_PER_WATER, BONUS_PER_UNIT, TEAM_TARGET]

func get_controls_text() -> String:
	return Localization.get_text("mp_filter_water_controls")

func _on_multiplayer_ready() -> void:
	# Setup game when multiplayer is ready
	game_name = "Filter Water"
	title_key = "mp_title_filter_water"
	connection_type = "resource_transfer"
	_connect_viewport_resize()
	_create_aquarium()
	win_quota = TEAM_TARGET # a TEAM total — the partner catching the rain pays into it too
	
	_log("Game ready - Filter water sent by partner!")

func _on_game_start() -> void:
	# Called when game starts (after countdown)
	_log("Filtering started - waiting for water from partner...")
	# Give P2 a small starter batch so they have something to do right away
	# while waiting for P1 to catch the first real drops.
	_spawn_dirt_particles(PARTICLES_PER_WATER * 2)
	aquarium_fill_units = min(AQUARIUM_CAPACITY, aquarium_fill_units + 2)

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
	aquarium = Node2D.new()
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
	var view := playfield_rect()
	if view.size.x <= 1.0:
		return
	aquarium.position = Vector2(view.get_center().x, view.end.y - 170.0)
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
	# Spawn dirt particles that need to be tapped
	var view := playfield_rect()
	if view.size.x <= 1.0:
		return
	for i in range(count):
		var particle = Area2D.new()
		# Inside the VISIBLE rect. The old band was world x[100, 1820] y[100, 1820] - viewport
		# size read as world extent - so on this camera a large share of the dirt spawned past
		# the right edge or below the bottom one, unclickable, and the round could not be
		# cleared: the queue P1 keeps filling only drains when a particle is tapped.
		particle.position = Vector2(
			randf_range(view.position.x + DIRT_MARGIN, view.end.x - DIRT_MARGIN),
			randf_range(view.position.y + DIRT_MARGIN, view.end.y - DIRT_MARGIN_BOTTOM)
		)
		add_child(particle)
		
		# Collision
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = DIRT_HIT_RADIUS
		collision.shape = shape
		particle.add_child(collision)
		
		# Visual
		var sprite = Sprite2D.new()
		sprite.texture = MiniGameAssets.create_dirt_texture(DIRT_TEX_RADIUS)
		sprite.scale = Vector2.ONE * (DIRT_ART_RADIUS / float(DIRT_TEX_RADIUS))
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
	add_score(POINTS_PER_PARTICLE)
	
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
		add_score(BONUS_PER_UNIT, false, aquarium)  # Bonus for completing a whole unit
		
		_log("💧 Water unit filtered! Bonus +%d points" % BONUS_PER_UNIT)
		
		# Reset counter for next unit
		filtered_count = 0

func _process(delta: float) -> void:
	if not game_active:
		return
	if not _layout_ready:
		_update_aquarium_layout()
	var view := playfield_rect()
	if view.size.x <= 1.0:
		return
	
	# Move dirt particles
	for particle in dirt_particles:
		if is_instance_valid(particle) and particle.has_meta("velocity"):
			var velocity = particle.get_meta("velocity") as Vector2
			particle.position += velocity * delta
			
			# Bounce off the edges of what the player can SEE. These walls used to stand at
			# world x=1870/y=1030 (viewport size again), i.e. outside the frame, so a drifting
			# particle wandered off-screen and bounced around out there untappable.
			# The wall is the HIT radius, not a round number: at 50 a particle could sit with a
			# quarter of its 148-unit tap area clipped off the frame, which is exactly the part
			# a thumb reaching in from the edge would land on.
			if particle.position.x < view.position.x + DIRT_HIT_RADIUS or particle.position.x > view.end.x - DIRT_HIT_RADIUS:
				velocity.x *= -1
				particle.set_meta("velocity", velocity)
				particle.position.x = clampf(
					particle.position.x, view.position.x + DIRT_HIT_RADIUS, view.end.x - DIRT_HIT_RADIUS)
			if particle.position.y < view.position.y + DIRT_HIT_RADIUS or particle.position.y > view.end.y - DIRT_HIT_RADIUS:
				velocity.y *= -1
				particle.set_meta("velocity", velocity)
				particle.position.y = clampf(
					particle.position.y, view.position.y + DIRT_HIT_RADIUS, view.end.y - DIRT_HIT_RADIUS)

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
