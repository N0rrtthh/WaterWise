extends MiniGameBase

var water_drops: Array = []
var drop_spawn_timer: float = 0.0
var drop_spawn_interval: float = 0.35
var drop_fall_speed: float = 450.0

var pot_node: Node2D
var basin_node: Node2D
var pot_direction: int = 1
var pot_speed: float = 150.0

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			pot_speed = 100.0
			drop_spawn_interval = 0.5
			drop_fall_speed = 350.0
			game_duration = 15.0
		"Medium":
			pot_speed = 150.0
			drop_spawn_interval = 0.35
			drop_fall_speed = 450.0
			game_duration = 18.0
		"Hard":
			pot_speed = 220.0
			drop_spawn_interval = 0.2
			drop_fall_speed = 550.0
			game_duration = 22.0

func _ready():
	game_name = "Rice Wash Rescue"
	game_instruction_text = Localization.get_text("rice_wash_rescue_instructions") if Localization else "FOLLOW the moving pot with the basin!\nCatch all the rice water! 🍚"
	game_duration = 18.0
	game_mode = "survival"  # Survive until timer ends - missed drops are OK
	show_quota = false  # No percentage display
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.9, 0.85, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Counter
	var counter = ColorRect.new()
	counter.color = Color(0.5, 0.35, 0.25)
	counter.position = Vector2(0, screen_size.y * 0.85)
	counter.size = Vector2(screen_size.x, screen_size.y * 0.15)
	counter.z_index = -5
	add_child(counter)
	
	# Simple catch counter (no percentage)
	var catch_label = Label.new()
	catch_label.name = "CatchLabel"
	catch_label.text = "💧 Catches: 0"
	catch_label.add_theme_font_size_override("font_size", 28)
	catch_label.add_theme_color_override("font_color", Color.WHITE)
	catch_label.add_theme_color_override("font_outline_color", Color.BLACK)
	catch_label.add_theme_constant_override("outline_size", 3)
	catch_label.position = Vector2(screen_size.x / 2 - 80, 120)
	add_child(catch_label)
	
	_create_pot(screen_size)
	_create_basin(screen_size)

func _create_pot(screen_size: Vector2):
	pot_node = Node2D.new()
	pot_node.position = Vector2(screen_size.x * 0.5, screen_size.y * 0.22)
	add_child(pot_node)
	
	var pot = Polygon2D.new()
	pot.polygon = PackedVector2Array([
		Vector2(-80, -60), Vector2(80, -60),
		Vector2(70, 50), Vector2(-70, 50)
	])
	pot.color = Color(0.35, 0.35, 0.4)
	pot_node.add_child(pot)
	
	var rim = Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-85, -65), Vector2(85, -65),
		Vector2(85, -55), Vector2(-85, -55)
	])
	rim.color = Color(0.45, 0.45, 0.5)
	pot_node.add_child(rim)
	
	var rice = Polygon2D.new()
	rice.polygon = PackedVector2Array([
		Vector2(-65, -20), Vector2(65, -20),
		Vector2(60, 45), Vector2(-60, 45)
	])
	rice.color = Color(0.95, 0.95, 0.9)
	pot_node.add_child(rice)
	
	# Spout indicator
	var spout = Label.new()
	spout.text = "⬇️"
	spout.add_theme_font_size_override("font_size", 32)
	spout.position = Vector2(-18, 50)
	spout.name = "Spout"
	pot_node.add_child(spout)

func _create_basin(screen_size: Vector2):
	basin_node = Node2D.new()
	basin_node.position = Vector2(screen_size.x * 0.5, screen_size.y * 0.72)
	add_child(basin_node)
	
	var basin = Polygon2D.new()
	basin.polygon = PackedVector2Array([
		Vector2(-90, -30), Vector2(90, -30),
		Vector2(70, 50), Vector2(-70, 50)
	])
	basin.color = Color(0.3, 0.5, 0.7)
	basin_node.add_child(basin)
	
	var rim = Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-95, -35), Vector2(95, -35),
		Vector2(95, -25), Vector2(-95, -25)
	])
	rim.color = Color(0.4, 0.6, 0.8)
	basin_node.add_child(rim)
	
	var indicator = Label.new()
	indicator.text = "← FOLLOW →"
	indicator.add_theme_font_size_override("font_size", 20)
	indicator.add_theme_color_override("font_color", Color.WHITE)
	indicator.position = Vector2(-60, 55)
	basin_node.add_child(indicator)

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	var screen_w = get_viewport_rect().size.x
	
	# Move pot horizontally
	pot_node.position.x += pot_direction * pot_speed * delta
	
	# Bounce off edges
	if pot_node.position.x > screen_w - 100:
		pot_direction = -1
	elif pot_node.position.x < 100:
		pot_direction = 1
	
	# Player controls basin
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_x = get_viewport().get_mouse_position().x
		basin_node.position.x = lerp(basin_node.position.x, mouse_x, 15.0 * delta)
	
	basin_node.position.x = clamp(basin_node.position.x, 100, screen_w - 100)
	
	# Spawn drops from pot
	drop_spawn_timer -= delta
	if drop_spawn_timer <= 0:
		_spawn_drop()
		drop_spawn_timer = drop_spawn_interval
	
	# Update drops
	var to_remove = []
	for drop in water_drops:
		if not is_instance_valid(drop):
			to_remove.append(drop)
			continue
		
		drop.position.y += drop_fall_speed * delta
		
		if drop.position.y >= basin_node.position.y - 30:
			if abs(drop.position.x - basin_node.position.x) < 85:
				record_action(true)
				_show_catch(drop.position)
			else:
				# Survival mode: missed drops are OK, just show visual feedback
				_show_miss(drop.position)
			
			to_remove.append(drop)
			drop.queue_free()
		elif drop.position.y > get_viewport_rect().size.y:
			to_remove.append(drop)
			drop.queue_free()
	
	for d in to_remove:
		water_drops.erase(d)
	
	# Update catch counter
	get_node("CatchLabel").text = "💧 Catches: %d" % correct_actions

func _spawn_drop():
	var drop = Node2D.new()
	drop.position = pot_node.position + Vector2(randf_range(-30, 30), 55)
	add_child(drop)
	
	var visual = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(8):
		var angle = i * TAU / 8
		points.append(Vector2(cos(angle) * 12, sin(angle) * 15))
	visual.polygon = points
	visual.color = Color(0.9, 0.9, 0.95, 0.8)
	drop.add_child(visual)
	
	water_drops.append(drop)

func _show_catch(pos: Vector2):
	var effect = Label.new()
	effect.text = "✓"
	effect.add_theme_font_size_override("font_size", 36)
	effect.add_theme_color_override("font_color", Color.GREEN)
	effect.position = pos + Vector2(-10, -30)
	add_child(effect)
	
	var tw = create_tween()
	tw.tween_property(effect, "position:y", effect.position.y - 30, 0.3)
	tw.parallel().tween_property(effect, "modulate:a", 0.0, 0.3)
	tw.tween_callback(effect.queue_free)

func _show_miss(pos: Vector2):
	var effect = Label.new()
	effect.text = "💦"
	effect.add_theme_font_size_override("font_size", 24)
	effect.position = pos
	add_child(effect)
	
	var tw = create_tween()
	tw.tween_property(effect, "modulate:a", 0.0, 0.4)
	tw.tween_callback(effect.queue_free)
