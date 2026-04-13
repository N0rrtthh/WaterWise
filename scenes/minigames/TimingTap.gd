extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## TIMING TAP - Tap at the right moment to collect water efficiently
## ═══════════════════════════════════════════════════════════════════

var faucet_node: Node2D
var container_node: Node2D
var water_flow: bool = false
var container_fill: float = 0.0
var target_fill: float = 80.0
var fill_tolerance: float = 10.0
var containers_filled: int = 0
var target_containers: int = 5
var fill_rate: float = 50.0
var is_holding: bool = false

func _apply_difficulty_settings() -> void:
	# Get progressive difficulty settings
	var settings = AdaptiveDifficulty.get_difficulty_settings() if AdaptiveDifficulty else {}
	var progressive_level = settings.get("progressive_level", 0)
	
	match current_difficulty:
		"Easy":
			target_containers = 2  # Achievable in 18s
			fill_tolerance = 15.0
			fill_rate = 35.0
			game_duration = 18.0
		"Medium":
			target_containers = 3  # Achievable in 12s
			fill_tolerance = 10.0
			fill_rate = 50.0
			game_duration = 12.0
		"Hard":
			target_containers = 4  # Achievable in 8s
			fill_tolerance = 5.0
			fill_rate = 70.0
			game_duration = 8.0
	
	# Apply PROGRESSIVE DIFFICULTY (NO CEILING!)
	if progressive_level > 0:
		target_containers += mini(progressive_level, 2)  # +1 container per level, max +2
		fill_rate += progressive_level * 8.0  # Faster filling = harder timing
		fill_tolerance = max(4.0, fill_tolerance - progressive_level * 0.5)  # Smaller target, floor at 4%
		game_duration += progressive_level * 2.0  # Give more time for extra containers
		if settings.has("time_limit"):
			game_duration = max(game_duration, settings.get("time_limit", game_duration))
		print("🔥 Progressive Lvl %d: %d containers, %.1f fill rate" % [progressive_level, target_containers, fill_rate])

func _ready():
	game_name = "Timing Tap"
	game_instruction_text = Localization.get_text("timing_tap_instructions") if Localization else "HOLD to fill container!\nStop at the TARGET line! 💧"
	game_duration = 25.0
	game_mode = "quota"
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background - Kitchen
	var bg = ColorRect.new()
	bg.color = Color(0.9, 0.88, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Counter
	var counter = ColorRect.new()
	counter.color = Color(0.45, 0.35, 0.25)
	counter.size = Vector2(screen_size.x, 150)
	counter.position = Vector2(0, screen_size.y - 150)
	counter.z_index = -5
	add_child(counter)
	
	# Faucet
	faucet_node = Node2D.new()
	faucet_node.position = Vector2(screen_size.x / 2, screen_size.y * 0.25)
	add_child(faucet_node)
	
	var faucet_icon = Label.new()
	faucet_icon.text = "🚰"
	faucet_icon.add_theme_font_size_override("font_size", 80)
	faucet_icon.position = Vector2(-40, -50)
	faucet_node.add_child(faucet_icon)
	
	# Water stream (hidden when not flowing)
	var stream = Node2D.new()
	stream.name = "Stream"
	stream.visible = false
	faucet_node.add_child(stream)
	
	for i in range(8):
		var drop = Label.new()
		drop.text = "💧"
		drop.add_theme_font_size_override("font_size", 25)
		drop.position = Vector2(randf_range(-10, 10), 50 + i * 30)
		stream.add_child(drop)
	
	# Container
	container_node = Node2D.new()
	container_node.position = Vector2(screen_size.x / 2, screen_size.y * 0.6)
	add_child(container_node)
	
	# Glass/Container body
	var glass_body = Polygon2D.new()
	glass_body.polygon = PackedVector2Array([
		Vector2(-50, -80), Vector2(50, -80),
		Vector2(45, 80), Vector2(-45, 80)
	])
	glass_body.color = Color(0.9, 0.95, 1.0, 0.5)
	container_node.add_child(glass_body)
	
	# Glass outline
	var glass_outline = Line2D.new()
	glass_outline.points = PackedVector2Array([
		Vector2(-50, -80), Vector2(50, -80),
		Vector2(45, 80), Vector2(-45, 80), Vector2(-50, -80)
	])
	glass_outline.width = 3
	glass_outline.default_color = Color(0.7, 0.8, 0.9)
	container_node.add_child(glass_outline)
	
	# Water fill
	var water = Polygon2D.new()
	water.name = "Water"
	water.polygon = PackedVector2Array([
		Vector2(-43, 78), Vector2(43, 78),
		Vector2(43, 78), Vector2(-43, 78)
	])
	water.color = Color(0.3, 0.6, 0.9, 0.7)
	container_node.add_child(water)
	
	# Target line
	var target_line = Line2D.new()
	target_line.name = "TargetLine"
	target_line.width = 3
	target_line.default_color = Color(0.2, 0.8, 0.2)
	container_node.add_child(target_line)
	
	# Target label
	var target_label = Label.new()
	target_label.name = "TargetLabel"
	target_label.text = "← TARGET"
	target_label.add_theme_font_size_override("font_size", 18)
	target_label.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
	container_node.add_child(target_label)
	
	# Instructions
	var hold_label = Label.new()
	hold_label.name = "HoldLabel"
	hold_label.text = "👆 HOLD TO FILL"
	hold_label.add_theme_font_size_override("font_size", 32)
	hold_label.add_theme_color_override("font_color", Color.WHITE)
	hold_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hold_label.add_theme_constant_override("outline_size", 4)
	hold_label.position = Vector2(screen_size.x / 2 - 120, screen_size.y - 130)
	add_child(hold_label)
	
	# Score display
	var score_display = Label.new()
	score_display.name = "ScoreDisplay"
	score_display.text = "💧 0 / %d" % target_containers
	score_display.add_theme_font_size_override("font_size", 28)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(screen_size.x / 2 - 60, 120)
	add_child(score_display)
	
	_setup_container()

func _setup_container():
	container_fill = 0.0
	target_fill = randf_range(60.0, 90.0)
	
	# Update target line position
	var y_pos = 78 - (target_fill / 100.0 * 156)
	var target_line = container_node.get_node("TargetLine")
	target_line.points = PackedVector2Array([Vector2(-55, y_pos), Vector2(55, y_pos)])
	
	var target_label = container_node.get_node("TargetLabel")
	target_label.position = Vector2(58, y_pos - 12)

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	var was_holding = is_holding
	is_holding = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	var stream = faucet_node.get_node("Stream")
	
	if is_holding:
		stream.visible = true
		get_node("HoldLabel").text = "💧 FILLING..."
		get_node("HoldLabel").modulate = Color(0.5, 0.8, 1.0)
		
		# Fill container
		container_fill = min(100.0, container_fill + fill_rate * delta)
		
		# Animate water drops
		for drop in stream.get_children():
			drop.position.y += 200 * delta
			if drop.position.y > 250:
				drop.position.y = 50
	else:
		stream.visible = false
		get_node("HoldLabel").text = "👆 HOLD TO FILL"
		get_node("HoldLabel").modulate = Color.WHITE
	
	# Update water visual
	var water = container_node.get_node("Water")
	var fill_height = (container_fill / 100.0) * 156
	var y_top = 78 - fill_height
	water.polygon = PackedVector2Array([
		Vector2(-43, 78), Vector2(43, 78),
		Vector2(43 - (2 * (1 - container_fill/100.0)), y_top), 
		Vector2(-43 + (2 * (1 - container_fill/100.0)), y_top)
	])
	
	# Check if released after filling
	if was_holding and not is_holding and container_fill > 0:
		_check_fill()

func _check_fill():
	var diff = abs(container_fill - target_fill)
	
	if diff <= fill_tolerance:
		# Perfect!
		containers_filled += 1
		record_action(true)
		get_node("ScoreDisplay").text = "💧 %d / %d" % [containers_filled, target_containers]
		
		# Success animation
		var flash = ColorRect.new()
		flash.color = Color(0, 1, 0, 0.3)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var tw = create_tween()
		tw.set_loops(1)
		tw.tween_property(flash, "modulate:a", 0.0, 0.3)
		tw.tween_callback(flash.queue_free)
		
		if containers_filled >= target_containers:
			end_game(true)
		else:
			await get_tree().create_timer(0.8).timeout
			if game_active:
				_setup_container()
	else:
		# Failed
		record_action(false)
		
		var flash = ColorRect.new()
		flash.color = Color(1, 0, 0, 0.3)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var tw = create_tween()
		tw.set_loops(1)
		tw.tween_property(flash, "modulate:a", 0.0, 0.3)
		tw.tween_callback(flash.queue_free)
		
		# Feedback
		var feedback = Label.new()
		if container_fill > target_fill:
			feedback.text = "OVERFLOW! 💦"
		else:
			feedback.text = "NOT ENOUGH! ⬆️"
		feedback.add_theme_font_size_override("font_size", 32)
		feedback.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		feedback.position = container_node.position + Vector2(-70, -120)
		add_child(feedback)
		
		var tw2 = create_tween()
		tw2.set_loops(1)
		tw2.tween_property(feedback, "modulate:a", 0.0, 0.5)
		tw2.tween_callback(feedback.queue_free)
		
		await get_tree().create_timer(0.5).timeout
		if game_active:
			_setup_container()
