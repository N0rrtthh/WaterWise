extends MiniGameBase

var drum_node: Node2D
var drops: Array = []
var drop_speed: float = 300.0
var spawn_timer: float = 0.0
var spawn_interval: float = 0.4
var score: int = 0
var target_score: int = 10
var score_label_game: Label

func _apply_difficulty_settings() -> void:
	# Apply difficulty-based scaling
	var speed_mult = get_difficulty_multiplier("speed_multiplier", 1.0)
	var item_count = int(get_difficulty_multiplier("item_count", 5))
	
	match current_difficulty:
		"Easy":
			drop_speed = 250.0
			spawn_interval = 0.5
			target_score = 6
			game_duration = 15.0
		"Medium":
			drop_speed = 350.0
			spawn_interval = 0.35
			target_score = 8
			game_duration = 10.0
		"Hard":
			drop_speed = 500.0 * speed_mult
			spawn_interval = 0.2
			target_score = 10 + item_count
			game_duration = 8.0

func _ready():
	game_name = "Catch The Rain"
	game_instruction_text = Localization.get_text("catch_the_rain_instructions") if Localization else "DRAG to move the drum!\nCatch BLUE drops! Avoid RED drops!"
	game_duration = 20.0
	game_mode = "quota"  # Must catch target before time runs out
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background - Sky
	var sky = ColorRect.new()
	sky.color = Color(0.4, 0.6, 0.9)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.z_index = -10
	add_child(sky)
	
	# Clouds
	for i in range(5):
		var cloud = _create_cloud()
		cloud.position = Vector2(randf() * screen_size.x, randf_range(50, 200))
		cloud.z_index = -5
		add_child(cloud)
	
	# Drum (Larger, more visible)
	drum_node = Node2D.new()
	drum_node.position = Vector2(screen_size.x * 0.5, screen_size.y - 120)
	add_child(drum_node)
	
	# Drum visual - Blue barrel style
	var drum_body = Polygon2D.new()
	drum_body.polygon = PackedVector2Array([
		Vector2(-60, -80), Vector2(60, -80),
		Vector2(70, 0), Vector2(60, 80),
		Vector2(-60, 80), Vector2(-70, 0)
	])
	drum_body.color = Color(0.2, 0.4, 0.8)
	drum_node.add_child(drum_body)
	
	# Drum rim
	var drum_rim = Polygon2D.new()
	drum_rim.polygon = PackedVector2Array([Vector2(-65, -85), Vector2(65, -85), Vector2(65, -75), Vector2(-65, -75)])
	drum_rim.color = Color(0.15, 0.3, 0.6)
	drum_node.add_child(drum_rim)
	
	# Water level indicator inside drum
	var water_inside = Polygon2D.new()
	water_inside.polygon = PackedVector2Array([Vector2(-55, 0), Vector2(55, 0), Vector2(55, 75), Vector2(-55, 75)])
	water_inside.color = Color(0.3, 0.7, 1.0, 0.6)
	water_inside.name = "WaterLevel"
	drum_node.add_child(water_inside)
	
	# Score display specific to this game
	score_label_game = Label.new()
	score_label_game.add_theme_font_size_override("font_size", 48)
	score_label_game.add_theme_color_override("font_color", Color.WHITE)
	score_label_game.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label_game.add_theme_constant_override("outline_size", 6)
	score_label_game.position = Vector2(screen_size.x / 2 - 80, screen_size.y - 220)
	score_label_game.text = "💧 0 / %d" % target_score
	add_child(score_label_game)

func _create_cloud() -> Node2D:
	var cloud = Node2D.new()
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-40, 0), Vector2(-30, -20), Vector2(0, -25),
		Vector2(30, -20), Vector2(40, 0), Vector2(30, 15),
		Vector2(-30, 15)
	])
	poly.color = Color(1, 1, 1, 0.8)
	poly.scale = Vector2(randf_range(1.5, 3.0), randf_range(1.0, 2.0))
	cloud.add_child(poly)
	return cloud

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	# Player Input - Follow mouse/touch
	var target_x = get_viewport().get_mouse_position().x
	target_x = clamp(target_x, 70.0, get_viewport_rect().size.x - 70.0)
	drum_node.position.x = lerp(drum_node.position.x, target_x, 12.0 * delta)
	
	# Spawn Drops
	spawn_timer -= delta
	if spawn_timer <= 0:
		_spawn_drop()
		spawn_timer = spawn_interval
	
	# Move Drops
	var drops_to_remove = []
	for drop in drops:
		if not is_instance_valid(drop):
			drops_to_remove.append(drop)
			continue
			
		drop.position.y += drop_speed * delta
		
		# Check collision with drum opening
		if drop.position.y > drum_node.position.y - 90 and drop.position.y < drum_node.position.y - 60:
			if abs(drop.position.x - drum_node.position.x) < 65:
				_catch_drop(drop)
				drops_to_remove.append(drop)
				continue
		
		# Remove if off screen (missed - no penalty, just missed opportunity)
		if drop.position.y > get_viewport_rect().size.y + 20:
			# Missed drops just disappear - no penalty for missing
			drops_to_remove.append(drop)
			drop.queue_free()
	
	for drop in drops_to_remove:
		drops.erase(drop)

func _spawn_drop():
	var is_good = randf() > 0.25 # 75% good drops
	var drop = Node2D.new()
	drop.position = Vector2(randf_range(50, get_viewport_rect().size.x - 50), -30)
	drop.set_meta("good", is_good)
	add_child(drop)
	
	# Raindrop shape (larger for visibility)
	var visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -20), Vector2(12, 0), Vector2(8, 15),
		Vector2(0, 20), Vector2(-8, 15), Vector2(-12, 0)
	])
	
	if is_good:
		visual.color = Color(0.2, 0.6, 1.0) # Blue = Good
	else:
		visual.color = Color(1.0, 0.3, 0.3) # Red = Bad (dirty water)
		# Add X mark on bad drops
		var x_mark = Label.new()
		x_mark.text = "✕"
		x_mark.add_theme_font_size_override("font_size", 24)
		x_mark.position = Vector2(-8, -12)
		drop.add_child(x_mark)
	
	drop.add_child(visual)
	drops.append(drop)

func _catch_drop(drop):
	var is_good = drop.get_meta("good")
	drop.queue_free()
	
	if is_good:
		score += 1
		record_action(true)
		score_label_game.text = "💧 %d / %d" % [score, target_score]
		
		# Update water level visual
		var water_level = drum_node.get_node("WaterLevel")
		var fill_pct = float(score) / float(target_score)
		water_level.polygon = PackedVector2Array([
			Vector2(-55, 75 - fill_pct * 150),
			Vector2(55, 75 - fill_pct * 150),
			Vector2(55, 75),
			Vector2(-55, 75)
		])
		
		# Flash green
		drum_node.modulate = Color(0.5, 1, 0.5)
		create_tween().tween_property(drum_node, "modulate", Color.WHITE, 0.15)
		
		if score >= target_score:
			end_game(true)
	else:
		# Caught dirty water - lose a point and flash red
		score = max(0, score - 1)
		record_action(false)  # Only catching bad drops counts as a mistake
		score_label_game.text = "💧 %d / %d" % [score, target_score]
		drum_node.modulate = Color(1, 0.5, 0.5)
		create_tween().tween_property(drum_node, "modulate", Color.WHITE, 0.2)
