extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## WATER PLANT MINI-GAME
## Teach proper watering techniques - use watering can, not hose
## Difficulty scales: more plants, faster wilting, distractors
## ═══════════════════════════════════════════════════════════════════

@export var plant_scene: PackedScene

var plants: Array[Node2D] = []
var watering_can_position: Vector2 = Vector2.ZERO
var using_hose: bool = false

## Difficulty-scaled parameters
var num_plants: int = 3
var wilt_speed: float = 1.0
var has_hose_temptation: bool = false

func _ready() -> void:
	game_name = Localization.tr("water_plant")
	super._ready()

func _apply_difficulty_settings() -> void:
	super._apply_difficulty_settings()
	
	# Scale based on difficulty
	num_plants = difficulty_settings.get("item_count", 3)
	wilt_speed = difficulty_settings.get("speed_multiplier", 1.0)
	
	# Add hose as distractor in higher difficulties
	var distractors = difficulty_settings.get("distractors", 0)
	has_hose_temptation = distractors > 0

func _on_game_start() -> void:
	_spawn_plants()
	_create_watering_tools()
	
	if has_hose_temptation:
		_add_hose_temptation()

func _spawn_plants() -> void:
	# Create plants in a row
	var spacing = get_viewport_rect().size.x / (num_plants + 1)
	
	for i in range(num_plants):
		var plant = _create_plant()
		plant.position = Vector2(spacing * (i + 1), get_viewport_rect().size.y - 200)
		plants.append(plant)
		add_child(plant)

func _create_plant() -> Node2D:
	# Simple plant representation
	var plant = Node2D.new()
	
	# Pot
	var pot = ColorRect.new()
	pot.color = Color(0.6, 0.3, 0.2)
	pot.size = Vector2(60, 40)
	pot.position = Vector2(-30, 0)
	plant.add_child(pot)
	
	# Plant sprite (simple green rectangle for prototype)
	var plant_sprite = ColorRect.new()
	plant_sprite.color = Color(0.2, 0.8, 0.3)
	plant_sprite.size = Vector2(30, 60)
	plant_sprite.position = Vector2(-15, -60)
	plant.add_child(plant_sprite)
	
	# Hydration level
	plant.set_meta("hydration", 0.5)
	plant.set_meta("sprite", plant_sprite)
	
	return plant

func _process(delta: float) -> void:
	super._process(delta)
	
	if game_active:
		_update_plants(delta)

func _update_plants(delta: float) -> void:
	for plant in plants:
		var hydration = plant.get_meta("hydration", 0.5)
		
		# Plants wilt over time
		hydration -= delta * 0.1 * wilt_speed
		hydration = clamp(hydration, 0.0, 1.0)
		
		plant.set_meta("hydration", hydration)
		
		# Update visual
		var sprite = plant.get_meta("sprite") as ColorRect
		if sprite:
			# Change color based on hydration
			if hydration > 0.7:
				sprite.color = Color(0.2, 0.9, 0.3)  # Healthy green
			elif hydration > 0.3:
				sprite.color = Color(0.7, 0.8, 0.3)  # Yellow-ish
			else:
				sprite.color = Color(0.6, 0.5, 0.3)  # Brown (wilted)
		
		# Game over if any plant dies
		if hydration <= 0:
			end_game(false)

func _create_watering_tools() -> void:
	# Watering Can (correct tool)
	var can = _create_tool("💧 Watering Can", Vector2(100, 100), true)
	can.pressed.connect(_on_watering_can_used)
	
	# Show hint for easy mode
	if difficulty_settings.get("visual_guidance", false):
		var hint = Label.new()
		hint.text = "👆 Use the watering can!"
		hint.position = Vector2(50, 150)
		hint.add_theme_font_size_override("font_size", 20)
		add_child(hint)

func _create_tool(label_text: String, pos: Vector2, is_correct: bool) -> Button:
	var btn = Button.new()
	btn.text = label_text
	btn.position = pos
	btn.custom_minimum_size = Vector2(150, 60)
	btn.set_meta("is_correct", is_correct)
	add_child(btn)
	return btn

func _add_hose_temptation() -> void:
	# Add hose as wrong option
	var hose = _create_tool("🚿 Hose (Fast!)", Vector2(300, 100), false)
	hose.pressed.connect(_on_hose_used)

func _on_watering_can_used() -> void:
	# Find nearest plant
	var nearest_plant = _find_nearest_thirsty_plant()
	
	if nearest_plant:
		var hydration = nearest_plant.get_meta("hydration", 0.0)
		hydration = min(1.0, hydration + 0.3)  # Water efficiently
		nearest_plant.set_meta("hydration", hydration)
		
		record_action(true)  # Correct action
		
		# Check if all plants are healthy
		if _all_plants_healthy():
			end_game(true)
	else:
		record_action(false)  # Watering when not needed

func _on_hose_used() -> void:
	# Using hose wastes water!
	record_action(false)
	mistakes_made += 2  # Extra penalty
	
	# Still waters the plant, but wrong method
	var nearest_plant = _find_nearest_thirsty_plant()
	if nearest_plant:
		var hydration = nearest_plant.get_meta("hydration", 0.0)
		hydration = min(1.0, hydration + 0.2)  # Less efficient
		nearest_plant.set_meta("hydration", hydration)

func _find_nearest_thirsty_plant() -> Node2D:
	var thirstiest: Node2D = null
	var lowest_hydration = 1.0
	
	for plant in plants:
		var hydration = plant.get_meta("hydration", 1.0)
		if hydration < lowest_hydration and hydration < 0.8:
			lowest_hydration = hydration
			thirstiest = plant
	
	return thirstiest

func _all_plants_healthy() -> bool:
	for plant in plants:
		var hydration = plant.get_meta("hydration", 0.0)
		if hydration < 0.7:
			return false
	return true
