extends CoopScenarioBase

## ═══════════════════════════════════════════════════════════════════
## KITCHEN CO-OP SCENARIO
## Player 1: Washes dishes (generates water)
## Player 2: Catches water (saves water)
## ═══════════════════════════════════════════════════════════════════

var dishes_cleaned: int = 0
var water_caught: int = 0
var water_missed: int = 0
var target_dishes: int = 10
var max_missed_water: int = 5

func _ready() -> void:
	super._ready()
	time_remaining = 45.0 # 45 seconds to finish

func _setup_player1_game() -> void:
	status_label.text = "ROLE: DISH WASHER\nScrub the dishes!"
	
	# Create Dish Washing Minigame
	var game = Node2D.new()
	game.name = "DishWasherGame"
	add_child(game)
	current_minigame = game
	
	# Visuals
	var sink = ColorRect.new()
	sink.color = Color(0.8, 0.8, 0.8)
	sink.size = Vector2(600, 400)
	sink.position = Vector2(get_viewport_rect().size.x/2 - 300, get_viewport_rect().size.y/2 - 200)
	game.add_child(sink)
	
	var dish = Sprite2D.new()
	# Placeholder for dish
	var dish_poly = Polygon2D.new()
	dish_poly.polygon = PackedVector2Array([Vector2(-50, -50), Vector2(50, -50), Vector2(50, 50), Vector2(-50, 50)])
	dish_poly.color = Color(0.9, 0.9, 0.9)
	dish.add_child(dish_poly)
	dish.position = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2)
	game.add_child(dish)
	
	# Interaction
	var button = Button.new()
	button.text = "SCRUB!"
	button.custom_minimum_size = Vector2(200, 100)
	button.position = Vector2(get_viewport_rect().size.x/2 - 100, get_viewport_rect().size.y - 150)
	button.pressed.connect(_on_scrub_pressed)
	game.add_child(button)

func _setup_player2_game() -> void:
	status_label.text = "ROLE: WATER CATCHER\nCatch the runoff!"
	
	# Create Water Catching Minigame
	var game = Node2D.new()
	game.name = "WaterCatcherGame"
	add_child(game)
	current_minigame = game
	
	# Visuals
	var pipe = ColorRect.new()
	pipe.color = Color(0.5, 0.5, 0.5)
	pipe.size = Vector2(40, 100)
	pipe.position = Vector2(get_viewport_rect().size.x/2 - 20, 50)
	game.add_child(pipe)
	
	# Bucket (Player controlled)
	var bucket = Node2D.new()
	bucket.name = "Bucket"
	bucket.position = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y - 100)
	game.add_child(bucket)
	
	var bucket_poly = Polygon2D.new()
	bucket_poly.polygon = PackedVector2Array([Vector2(-40, -40), Vector2(40, -40), Vector2(30, 40), Vector2(-30, 40)])
	bucket_poly.color = Color(0.8, 0.4, 0.2)
	bucket.add_child(bucket_poly)

func _process(delta: float) -> void:
	super._process(delta)
	
	if not game_active: return
	
	if local_player_num == 2:
		_process_catcher(delta)

func _on_scrub_pressed() -> void:
	dishes_cleaned += 1
	status_label.text = "Dishes: %d/%d" % [dishes_cleaned, target_dishes]
	
	# Send "water drop" event to partner
	if NetworkManager:
		NetworkManager.send_game_event("spawn_drop", {})
	
	if dishes_cleaned >= target_dishes:
		_win_game()

func _process_catcher(delta: float) -> void:
	var bucket = current_minigame.get_node("Bucket")
	if bucket:
		bucket.position.x = get_viewport().get_mouse_position().x

# Handle events from partner
func on_partner_event(event_type: String, data: Dictionary) -> void:
	super.on_partner_event(event_type, data)
	
	if event_type == "spawn_drop" and local_player_num == 2:
		_spawn_water_drop()

func _spawn_water_drop() -> void:
	var drop = Node2D.new()
	drop.position = Vector2(get_viewport_rect().size.x/2 + randf_range(-50, 50), 150)
	current_minigame.add_child(drop)
	
	var drop_poly = Polygon2D.new()
	drop_poly.polygon = PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(0, 10)])
	drop_poly.color = Color(0.2, 0.6, 1.0)
	drop.add_child(drop_poly)
	
	# Animate drop falling
	var tween = create_tween()
	tween.tween_property(drop, "position:y", get_viewport_rect().size.y - 100, 1.0)
	tween.tween_callback(func(): _check_catch(drop))

func _check_catch(drop: Node2D) -> void:
	var bucket = current_minigame.get_node("Bucket")
	if abs(drop.position.x - bucket.position.x) < 50:
		water_caught += 1
		status_label.text = "Caught: %d" % water_caught
		# Flash green
		bucket.modulate = Color.GREEN
		create_tween().tween_property(bucket, "modulate", Color.WHITE, 0.2)
	else:
		water_missed += 1
		status_label.text = "Missed: %d/%d" % [water_missed, max_missed_water]
		# Flash red
		bucket.modulate = Color.RED
		create_tween().tween_property(bucket, "modulate", Color.WHITE, 0.2)
		
		if water_missed >= max_missed_water:
			_fail_game("Too much water wasted!")
	
	drop.queue_free()
