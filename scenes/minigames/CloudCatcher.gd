extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## CLOUD CATCHER - Tap clouds to release rain for thirsty plants
## ═══════════════════════════════════════════════════════════════════
## Kids tap moving clouds floating across the screen. Each tap releases
## rain drops that fall and water the plants below. Water enough plants
## before time runs out!

var clouds: Array = []
var plants: Array = []
var cloud_speed: float = 80.0
var cloud_spawn_timer: float = 0.0
var cloud_spawn_interval: float = 1.5
var plants_watered: int = 0
var target_plants: int = 8
var screen_size: Vector2

func _apply_difficulty_settings() -> void:
	var settings = AdaptiveDifficulty.get_difficulty_settings() if AdaptiveDifficulty else {}
	var progressive_level = settings.get("progressive_level", 0)

	match current_difficulty:
		"Easy":
			cloud_speed = 60.0
			cloud_spawn_interval = 1.8
			target_plants = 4
			game_duration = 20.0
		"Medium":
			cloud_speed = 80.0
			cloud_spawn_interval = 1.4
			target_plants = 6
			game_duration = 15.0
		"Hard":
			cloud_speed = 120.0
			cloud_spawn_interval = 1.0
			target_plants = 8
			game_duration = 10.0

	if progressive_level > 0:
		target_plants += progressive_level
		cloud_speed += progressive_level * 15.0
		cloud_spawn_interval = max(0.5, cloud_spawn_interval - progressive_level * 0.1)
		game_duration = settings.get("time_limit", game_duration)

func _ready():
	game_name = "Cloud Catcher"
	var fallback := "TAP clouds to release rain!\nWater the thirsty plants below! ☁️"
	game_instruction_text = (
		Localization.get_text("cloud_catcher_instructions")
		if Localization else fallback
	)
	game_duration = 25.0
	game_mode = "quota"

	super._ready()

	screen_size = get_viewport_rect().size

	# Sky background
	var bg = ColorRect.new()
	bg.color = Color(0.53, 0.81, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)

	# Ground
	var ground = ColorRect.new()
	ground.color = Color(0.36, 0.25, 0.14)
	ground.size = Vector2(screen_size.x, 120)
	ground.position = Vector2(0, screen_size.y - 120)
	ground.z_index = -5
	add_child(ground)

	# Grass strip
	var grass = ColorRect.new()
	grass.color = Color(0.3, 0.7, 0.2)
	grass.size = Vector2(screen_size.x, 30)
	grass.position = Vector2(0, screen_size.y - 120)
	grass.z_index = -4
	add_child(grass)

	# Spawn plants along the bottom
	var plant_count = 6
	for i in range(plant_count):
		var plant_x = (screen_size.x / (plant_count + 1)) * (i + 1)
		var plant_pos = Vector2(plant_x, screen_size.y - 140)
		var plant = _create_plant(plant_pos)
		add_child(plant)
		plants.append(plant)

	# Score display
	var score_display = Label.new()
	score_display.name = "PlantScore"
	score_display.text = "🌱 0 / %d watered" % target_plants
	score_display.add_theme_font_size_override("font_size", 26)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(20, 120)
	add_child(score_display)

func _create_plant(pos: Vector2) -> Node2D:
	var plant = Node2D.new()
	plant.position = pos
	plant.set_meta("watered", false)
	plant.set_meta("water_amount", 0.0)
	plant.set_meta("target_water", 1.0)

	var icon = Label.new()
	icon.name = "Icon"
	icon.text = "🌱"
	icon.add_theme_font_size_override("font_size", 48)
	icon.position = Vector2(-20, -30)
	plant.add_child(icon)

	# Thirst indicator
	var thirst_bg = ColorRect.new()
	thirst_bg.name = "ThirstBg"
	thirst_bg.color = Color(0.3, 0.3, 0.3, 0.6)
	thirst_bg.size = Vector2(40, 6)
	thirst_bg.position = Vector2(-16, -38)
	plant.add_child(thirst_bg)

	var thirst_bar = ColorRect.new()
	thirst_bar.name = "ThirstBar"
	thirst_bar.color = Color(0.3, 0.6, 1.0)
	thirst_bar.size = Vector2(0, 6)
	thirst_bar.position = Vector2(-16, -38)
	plant.add_child(thirst_bar)

	return plant

func _create_cloud(start_x: float) -> Node2D:
	var cloud = Node2D.new()
	cloud.position = Vector2(start_x, randf_range(80, screen_size.y * 0.35))
	cloud.set_meta("tapped", false)
	cloud.set_meta("speed", cloud_speed + randf_range(-20, 20))

	var btn = Button.new()
	btn.text = "☁️"
	btn.add_theme_font_size_override("font_size", 56)
	btn.flat = true
	btn.custom_minimum_size = Vector2(90, 70)
	btn.position = Vector2(-45, -35)
	btn.pressed.connect(_on_cloud_tapped.bind(cloud))
	cloud.add_child(btn)

	return cloud

func _on_cloud_tapped(cloud: Node2D) -> void:
	if not game_active or cloud.get_meta("tapped", false):
		return

	cloud.set_meta("tapped", true)
	record_action(true)

	# Spawn rain drops falling down
	_spawn_rain(cloud.position)

	# Shrink cloud away
	var tw = create_tween()
	tw.tween_property(cloud, "scale", Vector2(0.3, 0.3), 0.3)
	tw.parallel().tween_property(cloud, "modulate:a", 0.0, 0.3)
	tw.tween_callback(cloud.queue_free)

func _spawn_rain(from_pos: Vector2) -> void:
	for i in range(5):
		var drop = Label.new()
		drop.text = "💧"
		drop.add_theme_font_size_override("font_size", 22)
		drop.position = Vector2(from_pos.x + randf_range(-30, 30), from_pos.y)
		drop.set_meta("fall_speed", randf_range(300, 500))
		drop.set_meta("is_rain", true)
		add_child(drop)

func _process(delta):
	super._process(delta)
	if not game_active:
		return

	# Spawn clouds
	cloud_spawn_timer -= delta
	if cloud_spawn_timer <= 0:
		cloud_spawn_timer = cloud_spawn_interval + randf_range(-0.3, 0.3)
		var side = randi() % 2
		var start_x = -80.0 if side == 0 else screen_size.x + 80.0
		var cloud = _create_cloud(start_x)
		if side == 1:
			cloud.set_meta("speed", -cloud.get_meta("speed"))
		add_child(cloud)
		clouds.append(cloud)

	# Move clouds
	var to_remove: Array = []
	for cloud in clouds:
		if not is_instance_valid(cloud):
			to_remove.append(cloud)
			continue
		cloud.position.x += cloud.get_meta("speed") * delta
		if cloud.position.x < -120 or cloud.position.x > screen_size.x + 120:
			cloud.queue_free()
			to_remove.append(cloud)
	for c in to_remove:
		clouds.erase(c)

	# Move rain drops and check plant collisions
	for child in get_children():
		if child is Label and child.has_meta("is_rain"):
			child.position.y += child.get_meta("fall_speed") * delta
			# Check plant watering
			for plant in plants:
				if is_instance_valid(plant) and not plant.get_meta("watered", false):
					if child.position.distance_to(plant.position) < 50:
						_water_plant(plant, 0.5)
						child.queue_free()
						break
			# Remove if off-screen
			if child.position.y > screen_size.y:
				child.queue_free()

	# Update score display
	var display = get_node_or_null("PlantScore")
	if display:
		display.text = "🌱 %d / %d watered" % [plants_watered, target_plants]

	# Check win
	if plants_watered >= target_plants:
		end_game(true)

func _water_plant(plant: Node2D, amount: float) -> void:
	var current = plant.get_meta("water_amount", 0.0) + amount
	plant.set_meta("water_amount", current)

	var bar = plant.get_node_or_null("ThirstBar")
	if bar:
		var ratio = min(current / plant.get_meta("target_water", 1.0), 1.0)
		bar.size.x = ratio * 40

	if current >= plant.get_meta("target_water", 1.0) and not plant.get_meta("watered"):
		plant.set_meta("watered", true)
		plants_watered += 1
		var icon = plant.get_node_or_null("Icon")
		if icon:
			icon.text = "🌻"
			var tw = create_tween()
			tw.tween_property(plant, "scale", Vector2(1.3, 1.3), 0.15)
			tw.tween_property(plant, "scale", Vector2(1.0, 1.0), 0.15)

func _on_game_start() -> void:
	# Spawn a few initial clouds
	for i in range(3):
		var cloud = _create_cloud(randf_range(100, screen_size.x - 100))
		add_child(cloud)
		clouds.append(cloud)
