extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## PLUG THE LEAK - Hold to plug leaking pipes
## ═══════════════════════════════════════════════════════════════════

var pipes: Array = []
var water_wasted: float = 0.0
var max_water_waste: float = 100.0
var leak_rate: float = 8.0
var plug_rate: float = 15.0
var num_pipes: int = 3
var active_leak: Node2D = null

func _apply_difficulty_settings() -> void:
	super._apply_difficulty_settings()

	var complexity = int(difficulty_settings.get("task_complexity", 2))
	var speed_mult = float(difficulty_settings.get("speed_multiplier", 1.0))
	var base_time = float(difficulty_settings.get("time_limit", game_duration))

	num_pipes = clamp(complexity + 1, 2, 4)
	leak_rate = 8.0 * clamp(speed_mult, 0.8, 1.3)
	plug_rate = 17.0 / max(clamp(speed_mult, 0.8, 1.3), 0.8)

	# Keep challenge fair as count increases.
	max_water_waste = 80.0 + float(5 - num_pipes) * 15.0
	game_duration = base_time + float(num_pipes) * 2.5

	if current_difficulty == "Hard":
		leak_rate *= 1.12
		plug_rate *= 0.92
		max_water_waste = max(60.0, max_water_waste - 10.0)
		game_duration = max(14.0, game_duration - 1.5)

func _ready():
	game_name = "Plug The Leak"
	game_instruction_text = (
		Localization.get_text("plug_the_leak_instructions")
		if Localization
		else "HOLD on leaking pipes to plug them!\nDon't waste water! 🔧"
	)
	game_duration = 25.0
	game_mode = "survival"
	show_quota = false
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background - Bathroom wall
	var bg = ColorRect.new()
	bg.color = Color(0.85, 0.9, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Tile pattern
	for i in range(8):
		for j in range(6):
			var tile = ColorRect.new()
			tile.color = Color(0.8, 0.85, 0.8) if (i + j) % 2 == 0 else Color(0.75, 0.8, 0.75)
			tile.size = Vector2(screen_size.x / 8, screen_size.y / 6)
			tile.position = Vector2(i * tile.size.x, j * tile.size.y)
			tile.z_index = -9
			add_child(tile)
	
	# Water waste meter
	var waste_label = Label.new()
	waste_label.name = "WasteLabel"
	waste_label.text = "💧 Water Wasted: 0%"
	waste_label.add_theme_font_size_override("font_size", 28)
	waste_label.add_theme_color_override("font_color", Color.WHITE)
	waste_label.add_theme_color_override("font_outline_color", Color.BLACK)
	waste_label.add_theme_constant_override("outline_size", 4)
	waste_label.position = Vector2(screen_size.x / 2 - 120, 120)
	add_child(waste_label)
	
	# Create pipes
	var pipe_spacing = screen_size.x / (num_pipes + 1)
	for i in range(num_pipes):
		var pipe = _create_pipe(i)
		pipe.position = Vector2(pipe_spacing * (i + 1), screen_size.y * 0.5)
		add_child(pipe)
		pipes.append(pipe)

func _on_game_start() -> void:
	# Start first leak after delay
	await get_tree().create_timer(1.0).timeout
	if game_active:
		_start_random_leak()

func _create_pipe(index: int) -> Node2D:
	var pipe = Node2D.new()
	pipe.name = "Pipe_%d" % index
	
	# Vertical pipe
	var pipe_body = ColorRect.new()
	pipe_body.size = Vector2(60, 300)
	pipe_body.position = Vector2(-30, -150)
	pipe_body.color = Color(0.5, 0.5, 0.55)
	pipe.add_child(pipe_body)
	
	# Pipe joint (where leak happens)
	var joint = ColorRect.new()
	joint.name = "Joint"
	joint.size = Vector2(80, 40)
	joint.position = Vector2(-40, -20)
	joint.color = Color(0.4, 0.4, 0.45)
	pipe.add_child(joint)
	
	# Leak indicator (hidden initially)
	var leak = Node2D.new()
	leak.name = "Leak"
	leak.visible = false
	pipe.add_child(leak)
	
	# Water spray effect
	for j in range(5):
		var drop = Polygon2D.new()
		drop.polygon = PackedVector2Array([
			Vector2(0, -8), Vector2(5, 0), Vector2(0, 8), Vector2(-5, 0)
		])
		drop.color = Color(0.3, 0.6, 1.0, 0.8)
		drop.position = Vector2(40 + j * 10, randf_range(-15, 15))
		leak.add_child(drop)
	
	# Leak label
	var leak_label = Label.new()
	leak_label.text = "💦"
	leak_label.add_theme_font_size_override("font_size", 40)
	leak_label.position = Vector2(35, -25)
	leak.add_child(leak_label)
	
	# Progress bar for plugging
	var plug_bar = ProgressBar.new()
	plug_bar.name = "PlugBar"
	plug_bar.max_value = 100.0
	plug_bar.value = 0.0
	plug_bar.size = Vector2(80, 20)
	plug_bar.position = Vector2(-40, -80)
	plug_bar.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.7, 0.3)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	plug_bar.add_theme_stylebox_override("fill", style)
	pipe.add_child(plug_bar)
	
	pipe.set_meta("leaking", false)
	pipe.set_meta("plug_progress", 0.0)
	
	return pipe

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var is_holding = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	for pipe in pipes:
		if not is_instance_valid(pipe): continue
		
		var is_leaking = pipe.get_meta("leaking")
		var leak = pipe.get_node("Leak")
		var plug_bar = pipe.get_node("PlugBar")
		
		if is_leaking:
			# Check if player is holding on this pipe
			var pipe_rect = Rect2(pipe.position - Vector2(50, 50), Vector2(100, 100))
			
			if is_holding and pipe_rect.has_point(mouse_pos):
				# Plugging the leak
				var progress = pipe.get_meta("plug_progress") + plug_rate * delta
				pipe.set_meta("plug_progress", progress)
				plug_bar.value = progress
				plug_bar.visible = true
				
				# Animate pipe
				pipe.get_node("Joint").color = Color(0.3, 0.6, 0.4)
				
				if progress >= 100.0:
					# Leak fixed!
					pipe.set_meta("leaking", false)
					pipe.set_meta("plug_progress", 0.0)
					leak.visible = false
					plug_bar.visible = false
					pipe.get_node("Joint").color = Color(0.3, 0.7, 0.3)
					record_action(true)
					
					# Start new leak after delay
					await get_tree().create_timer(randf_range(0.5, 1.5)).timeout
					if game_active:
						_start_random_leak()
			else:
				# Not plugging - leak continues
				water_wasted += leak_rate * delta
				pipe.get_node("Joint").color = Color(0.6, 0.3, 0.3)
				
				# Animate leak spray
				for drop in leak.get_children():
					if drop is Polygon2D:
						drop.position.x += randf_range(0, 3)
						if drop.position.x > 80:
							drop.position.x = 40
	
	# Update waste display
	var waste_pct = (water_wasted / max_water_waste) * 100.0
	get_node("WasteLabel").text = "💧 Water Wasted: %.0f%%" % waste_pct
	
	# Check for failure
	if water_wasted >= max_water_waste:
		end_game(false)

func _start_random_leak():
	if not game_active: return
	
	# Find a non-leaking pipe
	var available = []
	for pipe in pipes:
		if not pipe.get_meta("leaking"):
			available.append(pipe)
	
	if available.is_empty():
		return
	
	var pipe = available[randi() % available.size()]
	pipe.set_meta("leaking", true)
	pipe.set_meta("plug_progress", 0.0)
	pipe.get_node("Leak").visible = true
	pipe.get_node("PlugBar").value = 0.0
	
	# Flash effect
	var flash = ColorRect.new()
	flash.color = Color(1, 0.3, 0.3, 0.5)
	flash.size = Vector2(100, 100)
	flash.position = pipe.position - Vector2(50, 50)
	add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)
