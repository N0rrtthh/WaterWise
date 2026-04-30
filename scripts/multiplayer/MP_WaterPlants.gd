extends MultiplayerMiniGameBase

## ═══════════════════════════════════════════════════════════════════
## MP_WaterPlants - Player 2 Game (Water Reuse Theme)
## ═══════════════════════════════════════════════════════════════════
## Player 2 waters plants using dirty water from Player 1
## Can only water when P1 sends dirty water
## Must complete quota: Water required number of plants
## ═══════════════════════════════════════════════════════════════════

const PLANT_SIZE: float = 80.0
const WATER_PER_PLANT: int = 1  # Each plant needs 1 unit of water
const MAX_WILTED: int = 5  # 5 plants wilt = lose 1 life
const QUOTA_P2: int = 12  # Water 12 plants to succeed

var plants_watered: int = 0
var plants_wilted: int = 0
var wilt_timer: Timer
var available_water: int = 0  # Water units received from P1
var plants: Array = []
var selected_plant: Area2D = null

var plant_types = [
	{"name": "🌻 Sunflower", "color": Color(1.0, 0.9, 0.2)},
	{"name": "🌹 Rose", "color": Color(1.0, 0.3, 0.4)},
	{"name": "🌿 Herb", "color": Color(0.3, 0.8, 0.3)},
	{"name": "🌺 Hibiscus", "color": Color(1.0, 0.4, 0.6)}
]

func get_instructions() -> String:
	return "🌱 WATER PLANTS\n\nWater %d plants before time runs out. Click plants using water sent by your partner.\nPlants wilt after 15s if ignored.\n\n⚠️ Let 5 plants wilt and you lose a life!\n💧 Wait for partner to send water, then click plants" % QUOTA_P2

func get_controls_text() -> String:
	return "🖱️ Click plants\n💧 Water them\n🌱 Keep alive"

func _on_multiplayer_ready() -> void:
	game_name = "Water Plants"
	connection_type = "resource_transfer"
	set_process_input(true)
	
	_create_water_indicator()
	_spawn_plants()
	
	# Wilt timer - plants wilt if not watered
	wilt_timer = Timer.new()
	wilt_timer.wait_time = 15.0  # Plants wilt after 15 seconds
	wilt_timer.timeout.connect(_check_wilted_plants)
	add_child(wilt_timer)
	
	_log("🌱 Endless mode: Water plants before they wilt! %d wilted = lose 1 life" % MAX_WILTED)

func _on_game_start() -> void:
	wilt_timer.start()
	_log("🚿 Waiting for water from partner...")

func _create_water_indicator() -> void:
	# Show available water from P1
	var panel = PanelContainer.new()
	panel.position = Vector2(20, 100)
	panel.size = Vector2(200, 100)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Available Water:"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	var water_label = Label.new()
	water_label.name = "WaterLabel"
	water_label.text = "💧 x 0"
	water_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(water_label)
	
	var info = Label.new()
	info.text = "Click plants to water"
	info.add_theme_font_size_override("font_size", 14)
	vbox.add_child(info)

func _update_water_display() -> void:
	var water_label = get_node_or_null("PanelContainer/VBoxContainer/WaterLabel")
	if water_label:
		water_label.text = "💧 x %d" % available_water

func _spawn_plants() -> void:
	# Spawn plants that need watering
	for i in range(12):  # Spawn 12 plants
		_spawn_plant()

func _spawn_plant() -> void:
	var plant_type = plant_types[randi() % plant_types.size()]
	
	var plant = Area2D.new()
	var row = plants.size() / 4.0
	var col = plants.size() % 4
	plant.position = Vector2(
		300 + col * 200,
		150 + row * 180
	)
	plant.set_meta("type", "plant")
	plant.set_meta("plant_data", plant_type)
	plant.set_meta("watered", false)
	plant.set_meta("spawn_time", Time.get_ticks_msec())
	add_child(plant)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = PLANT_SIZE / 2
	collision.shape = shape
	plant.add_child(collision)
	
	# Visual (dry plant)
	var visual = Sprite2D.new()
	visual.name = "Visual"
	visual.texture = MiniGameAssets.create_plant_texture(int(PLANT_SIZE), Color(0.5, 0.4, 0.3))
	visual.modulate = Color(0.7, 0.6, 0.5) # Dry look
	plant.add_child(visual)
	
	# Label
	var label = Label.new()
	label.name = "Label"
	label.text = "🥀 Dry"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-30, -60)
	label.add_theme_font_size_override("font_size", 18)
	plant.add_child(label)
	
	# Connect input
	plant.input_event.connect(_on_plant_clicked.bind(plant))
	
	plants.append(plant)

func _on_plant_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, plant: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_water_plant(plant)

func _try_water_plant(plant: Area2D) -> void:
	if not game_active:
		return
	
	if plant.get_meta("watered", false):
		_log("⚠️ Plant already watered!")
		return
	
	if available_water <= 0:
		_log("⚠️ No water available! Wait for partner to wash vegetables")
		return
	
	# Use water
	available_water -= WATER_PER_PLANT
	_update_water_display()
	
	# Water the plant
	plant.set_meta("watered", true)
	plants_watered += 1
	_log("💧 Watered plant! (%d/%d)" % [plants_watered, QUOTA_P2])

	# Check for win condition
	if plants_watered >= QUOTA_P2:
		end_game(true)
	
	# Score for P2 (G-Counter)
	add_score(1)
	
	# Update visual
	var visual = plant.get_node("Visual")
	var plant_data = plant.get_meta("plant_data")
	visual.modulate = plant_data["color"]  # Healthy color
	
	var label = plant.get_node("Label")
	label.text = plant_data["name"]
	
	# Visual effect
	_play_water_effect(plant.global_position)
	
	# Reset the plant after some time (endless spawning)
	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(plant):
		plant.set_meta("watered", false)
		plant.set_meta("spawn_time", Time.get_ticks_msec())
		visual = plant.get_node("Visual")
		visual.modulate = Color(0.7, 0.6, 0.5)  # Back to dry
		label = plant.get_node("Label")
		label.text = "🥀 Dry"

func _check_wilted_plants() -> void:
	# Check for plants that wilted (not watered in time)
	var current_time = Time.get_ticks_msec()
	for plant in plants:
		if not is_instance_valid(plant):
			continue
		
		if not plant.get_meta("watered", false):
			var spawn_time = plant.get_meta("spawn_time", current_time)
			var elapsed = (current_time - spawn_time) / 1000.0
			
			if elapsed > 15.0:  # Plant wilted
				plants_wilted += 1
				_log("💀 Plant wilted! (%d/%d)" % [plants_wilted, MAX_WILTED])
				plant.set_meta("watered", true)  # Mark to prevent re-counting
				plant.get_node("Visual").modulate = Color(0.3, 0.2, 0.1, 0.8)
				plant.get_node("Label").text = "💀 Dead"
				
				if plants_wilted >= MAX_WILTED:
					_log("💔 Too many wilted plants - lose 1 life!")
					plants_wilted = 0
					if NetworkManager:
						NetworkManager.lose_life()

func _on_resource_received(from_player: int, resource_type: String, amount: int, _quality: float) -> void:
	# Receive dirty water from Player 1
	if resource_type == "dirty_water":
		available_water += amount
		_update_water_display()
		_log("📥 Received %d dirty water from P%d (Total: %d)" % [amount, from_player, available_water])
		
		# Visual feedback
		var indicator = get_node_or_null("PanelContainer")
		if indicator:
			var tween = create_tween()
			tween.set_loops(1)
			tween.tween_property(indicator, "modulate", Color(0.5, 1.0, 1.0), 0.2)
			tween.tween_property(indicator, "modulate", Color.WHITE, 0.2)

func _play_water_effect(pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.amount = 25
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.direction = Vector2(0, -1)
	particles.spread = 30.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 80.0
	particles.gravity = Vector2(0, 200)
	particles.color = Color(0.3, 0.6, 1.0)
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _on_game_over() -> void:
	_log("Game over! Plants watered: %d" % plants_watered)
	super._on_game_over()
