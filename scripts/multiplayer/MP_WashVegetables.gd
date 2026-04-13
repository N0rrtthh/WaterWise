extends MultiplayerMiniGameBase

## ═══════════════════════════════════════════════════════════════════
## MP_WashVegetables - Player 1 Game (Water Reuse Theme)
## ═══════════════════════════════════════════════════════════════════
## Player 1 washes vegetables by dragging them to the sink
## Dirty water is sent to Player 2 for watering plants
## Must complete quota: Wash required number of vegetables
## ═══════════════════════════════════════════════════════════════════

const VEGETABLE_SIZE: float = 60.0
const DIRTY_WATER_PER_VEGGIE: int = 1  # Each vegetable produces 1 unit of water
const MAX_MISSES: int = 5  # Miss 5 vegetables = lose 1 life
const QUOTA_P1: int = 12  # Wash 12 veggies to succeed

var vegetables_washed: int = 0
var vegetables_missed: int = 0
var spawn_timer: Timer
var vegetables: Array = []
var dragging_vegetable: Area2D = null
var sink_area: Area2D = null

var vegetable_types = [
	{"name": "🥕 Carrot", "color": Color(1.0, 0.5, 0.2)},
	{"name": "🥬 Lettuce", "color": Color(0.3, 0.8, 0.3)},
	{"name": "🍅 Tomato", "color": Color(1.0, 0.3, 0.3)},
	{"name": "🥒 Cucumber", "color": Color(0.2, 0.7, 0.3)}
]

func get_instructions() -> String:
	return "🥬 WASH VEGETABLES\n\nWash %d veggies before time runs out. Drag them to the sink to clean and send dirty water to your partner.\n\n⚠️ Miss 5 veggies and you lose a life!\n🎯 Click and drag vegetables into the sink" % QUOTA_P1

func get_controls_text() -> String:
	return "🖱️ Click & drag\n🥬 To the sink\n💧 Send water"

func _on_multiplayer_ready() -> void:
	game_name = "Wash Vegetables"
	connection_type = "resource_transfer"
	set_process_input(true)
	
	_create_sink()
	
	# Create spawn timer for endless spawning
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 2.0
	spawn_timer.timeout.connect(_spawn_vegetable)
	add_child(spawn_timer)
	
	_log("🥕 Endless mode: Wash vegetables! Miss %d = lose 1 life" % MAX_MISSES)

func _on_game_start() -> void:
	spawn_timer.start()
	_log("🚿 Start washing!")

func _create_sink() -> void:
	"""Create sink area where vegetables are washed"""
	sink_area = Area2D.new()
	sink_area.position = Vector2(576, 500)
	add_child(sink_area)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(200, 150)
	collision.shape = shape
	sink_area.add_child(collision)
	
	# Visual sink
	var sink_visual = ColorRect.new()
	sink_visual.size = Vector2(200, 150)
	sink_visual.position = -Vector2(100, 75)
	sink_visual.color = Color(0.6, 0.8, 1.0, 0.3)
	sink_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sink_area.add_child(sink_visual)
	
	# Label
	var label = Label.new()
	label.text = "SINK\n🚰"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -50)
	label.add_theme_font_size_override("font_size", 24)
	sink_area.add_child(label)

func _spawn_vegetables() -> void:
	"""Initial spawn"""
	for i in range(3):
		_spawn_vegetable()

func _spawn_vegetable() -> void:
	var veggie_type = vegetable_types[randi() % vegetable_types.size()]
	
	var veggie = Area2D.new()
	veggie.position = Vector2(
		randf_range(100, 1052),
		randf_range(100, 300)
	)
	veggie.set_meta("type", "vegetable")
	veggie.set_meta("veggie_data", veggie_type)
	add_child(veggie)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = VEGETABLE_SIZE / 2
	collision.shape = shape
	veggie.add_child(collision)
	
	# Visual
	var visual = Sprite2D.new()
	visual.texture = MiniGameAssets.create_drop_texture(int(VEGETABLE_SIZE/2), veggie_type["color"]) # Reuse drop shape for simple veggie
	veggie.add_child(visual)
	
	# Label
	var label = Label.new()
	label.text = veggie_type["name"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-30, -50)
	label.add_theme_font_size_override("font_size", 20)
	veggie.add_child(label)
	
	# Connect input
	veggie.input_event.connect(_on_veggie_input.bind(veggie))
	
	vegetables.append(veggie)

func _on_veggie_input(_viewport: Node, event: InputEvent, _shape_idx: int, veggie: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_vegetable = veggie

func _input(event: InputEvent) -> void:
	if not game_active:
		return
	
	if event is InputEventMouseMotion and dragging_vegetable:
		dragging_vegetable.position = get_global_mouse_position()
	
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dragging_vegetable:
			_check_wash_vegetable()
			dragging_vegetable = null

func _check_wash_vegetable() -> void:
	if not dragging_vegetable or not sink_area:
		return
	
	# Check if vegetable is in sink
	var distance = dragging_vegetable.global_position.distance_to(sink_area.global_position)
	if distance < 100:
		_wash_vegetable()

func _wash_vegetable() -> void:
	if not dragging_vegetable:
		return
	
	vegetables_washed += 1
	_log("🚿 Washed vegetable! Total: %d" % vegetables_washed)

	# Check for win condition
	if vegetables_washed >= QUOTA_P1:
		end_game(true)
	
	# Score for P1 (G-Counter)
	add_score(10)
	
	# Send dirty water to P2
	send_resource_to_partner("dirty_water", DIRTY_WATER_PER_VEGGIE, 1.0)
	
	# Visual effect
	_play_wash_effect(dragging_vegetable.global_position)
	
	# Remove vegetable
	vegetables.erase(dragging_vegetable)
	dragging_vegetable.queue_free()
	dragging_vegetable = null

func _on_vegetable_missed() -> void:
	"""Vegetable fell off screen or timeout"""
	vegetables_missed += 1
	_log("❌ Missed vegetable! (%d/%d)" % [vegetables_missed, MAX_MISSES])
	
	if vegetables_missed >= MAX_MISSES:
		_log("💔 Too many misses - lose 1 life!")
		vegetables_missed = 0  # Reset counter
		if NetworkManager:
			NetworkManager.lose_life()  # Lose shared life

func _play_wash_effect(pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.amount = 30
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.direction = Vector2(0, 1)
	particles.spread = 45.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 120.0
	particles.gravity = Vector2(0, 300)
	particles.color = Color(0.5, 0.7, 1.0)
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _on_game_over() -> void:
	_log("Game over! Vegetables washed: %d" % vegetables_washed)
	super._on_game_over()
