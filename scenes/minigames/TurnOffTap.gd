extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## TURN OFF TAP - Quick reaction game to close running taps
## ═══════════════════════════════════════════════════════════════════

var tap_positions: Array = []
var active_taps: Array = []
var tap_spawn_timer: float = 0.0
var tap_spawn_interval: float = 1.2
var water_wasted: float = 0.0
var max_water_waste: float = 100.0
var taps_closed: int = 0
var target_taps: int = 15
var water_waste_rate: float = 15.0

func _apply_difficulty_settings() -> void:
	# Get progressive difficulty settings
	var settings = AdaptiveDifficulty.get_difficulty_settings() if AdaptiveDifficulty else {}
	var progressive_level = settings.get("progressive_level", 0)
	
	match current_difficulty:
		"Easy":
			tap_spawn_interval = 1.8
			water_waste_rate = 10.0
			max_water_waste = 150.0
			target_taps = 6  # Achievable in 18s
			game_duration = 18.0
		"Medium":
			tap_spawn_interval = 1.2
			water_waste_rate = 15.0
			max_water_waste = 100.0
			target_taps = 8  # Achievable in 12s
			game_duration = 12.0
		"Hard":
			tap_spawn_interval = 0.8
			water_waste_rate = 25.0
			max_water_waste = 60.0
			target_taps = 7  # Achievable in 8s with ~1.1s per tap
			game_duration = 8.0
	
	# Apply PROGRESSIVE DIFFICULTY (NO CEILING!)
	if progressive_level > 0:
		target_taps += progressive_level * 2  # +2 taps per level
		tap_spawn_interval = max(0.3, tap_spawn_interval * (1.0 - progressive_level * 0.08))  # Faster spawning
		water_waste_rate += progressive_level * 5.0  # More waste pressure
		game_duration = settings.get("time_limit", game_duration)
		print("🔥 Progressive Lvl %d: %d taps, %.2fs interval" % [progressive_level, target_taps, tap_spawn_interval])

func _ready():
	game_name = "Turn Off Tap"
	game_instruction_text = Localization.get_text("turn_off_tap_instructions") if Localization else "TAP running faucets to turn them off!\nDon't waste water! 🚿"
	game_duration = 25.0
	game_mode = "quota"
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background - Bathroom
	var bg = ColorRect.new()
	bg.color = Color(0.85, 0.9, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Tile pattern
	for row in range(8):
		for col in range(6):
			var tile = ColorRect.new()
			tile.size = Vector2(screen_size.x / 6, screen_size.y / 8)
			tile.position = Vector2(col * tile.size.x, row * tile.size.y)
			tile.color = Color(0.82, 0.87, 0.89) if (row + col) % 2 == 0 else Color(0.85, 0.9, 0.92)
			tile.z_index = -9
			add_child(tile)
	
	# Generate tap positions (3x2 grid)
	var margin_x = 100
	var margin_y = 180
	var spacing_x = (screen_size.x - margin_x * 2) / 2
	var spacing_y = (screen_size.y - margin_y * 2) / 2
	
	for row in range(2):
		for col in range(3):
			var pos = Vector2(
				margin_x + col * spacing_x,
				margin_y + row * spacing_y
			)
			tap_positions.append(pos)
	
	# Create tap fixtures at each position
	for pos in tap_positions:
		var fixture = _create_tap_fixture(pos)
		add_child(fixture)
	
	# Score display
	var score_display = Label.new()
	score_display.name = "ScoreDisplay"
	score_display.text = "🚰 0 / %d closed" % target_taps
	score_display.add_theme_font_size_override("font_size", 26)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(20, 120)
	add_child(score_display)
	
	# Water waste bar
	var waste_bg = ColorRect.new()
	waste_bg.name = "WasteBg"
	waste_bg.color = Color(0.3, 0.3, 0.3, 0.8)
	waste_bg.size = Vector2(200, 25)
	waste_bg.position = Vector2(screen_size.x - 220, 120)
	add_child(waste_bg)
	
	var waste_bar = ColorRect.new()
	waste_bar.name = "WasteBar"
	waste_bar.color = Color(0.3, 0.5, 0.9)
	waste_bar.size = Vector2(0, 25)
	waste_bar.position = Vector2(screen_size.x - 220, 120)
	add_child(waste_bar)
	
	var waste_label = Label.new()
	waste_label.name = "WasteLabel"
	waste_label.text = "💧 Water: OK"
	waste_label.add_theme_font_size_override("font_size", 18)
	waste_label.add_theme_color_override("font_color", Color.WHITE)
	waste_label.position = Vector2(screen_size.x - 220, 148)
	add_child(waste_label)

func _create_tap_fixture(pos: Vector2) -> Node2D:
	var fixture = Node2D.new()
	fixture.position = pos
	
	# Faucet base (always visible)
	var faucet = Label.new()
	faucet.name = "Faucet"
	faucet.text = "🚰"
	faucet.add_theme_font_size_override("font_size", 60)
	faucet.position = Vector2(-30, -40)
	faucet.modulate = Color(0.7, 0.7, 0.7)  # Grey = off
	fixture.add_child(faucet)
	
	return fixture

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	# Spawn new running taps
	tap_spawn_timer -= delta
	if tap_spawn_timer <= 0:
		tap_spawn_timer = tap_spawn_interval + randf_range(-0.3, 0.3)
		_spawn_running_tap()
	
	# Update active taps and water waste
	for tap in active_taps:
		if is_instance_valid(tap) and tap.get_meta("running", false):
			water_wasted += water_waste_rate * delta
			
			# Animate water drops
			var stream = tap.get_node_or_null("Stream")
			if stream:
				for drop in stream.get_children():
					drop.position.y += 150 * delta
					if drop.position.y > 60:
						drop.position.y = 0
						drop.position.x = randf_range(-5, 5)
	
	# Update waste bar
	var waste_bar = get_node("WasteBar")
	var waste_ratio = water_wasted / max_water_waste
	waste_bar.size.x = waste_ratio * 200
	
	var waste_label = get_node("WasteLabel")
	if waste_ratio < 0.5:
		waste_bar.color = Color(0.3, 0.5, 0.9)
		waste_label.text = "💧 Water: OK"
	elif waste_ratio < 0.8:
		waste_bar.color = Color(0.9, 0.7, 0.2)
		waste_label.text = "💧 Water: Caution!"
	else:
		waste_bar.color = Color(0.9, 0.3, 0.2)
		waste_label.text = "💧 Water: CRITICAL!"
	
	# Check failure
	if water_wasted >= max_water_waste:
		end_game(false)

func _spawn_running_tap():
	# Find an inactive tap position
	var available_positions = []
	for i in range(tap_positions.size()):
		var is_active = false
		for tap in active_taps:
			if is_instance_valid(tap) and tap.position == tap_positions[i]:
				is_active = true
				break
		if not is_active:
			available_positions.append(i)
	
	if available_positions.is_empty():
		return
	
	var pos_idx = available_positions[randi() % available_positions.size()]
	var pos = tap_positions[pos_idx]
	
	# Create running tap
	var tap = Node2D.new()
	tap.position = pos
	tap.set_meta("running", true)
	
	# Faucet icon (blue = running)
	var faucet = Label.new()
	faucet.name = "Faucet"
	faucet.text = "🚰"
	faucet.add_theme_font_size_override("font_size", 60)
	faucet.position = Vector2(-30, -40)
	faucet.modulate = Color(0.3, 0.6, 1.0)  # Blue = on
	tap.add_child(faucet)
	
	# Water stream
	var stream = Node2D.new()
	stream.name = "Stream"
	tap.add_child(stream)
	
	for i in range(4):
		var drop = Label.new()
		drop.text = "💧"
		drop.add_theme_font_size_override("font_size", 18)
		drop.position = Vector2(randf_range(-5, 5), i * 15)
		stream.add_child(drop)
	
	# Tap button
	var button = Button.new()
	button.name = "TapButton"
	button.custom_minimum_size = Vector2(100, 100)
	button.position = Vector2(-50, -50)
	button.modulate.a = 0.0  # Invisible
	button.pressed.connect(_on_tap_closed.bind(tap))
	tap.add_child(button)
	
	# Alert indicator
	var alert = Label.new()
	alert.name = "Alert"
	alert.text = "❗"
	alert.add_theme_font_size_override("font_size", 30)
	alert.position = Vector2(25, -50)
	tap.add_child(alert)
	
	# Pulse animation - loops indefinitely while tap is active
	var tw = create_tween().set_loops(0)  # 0 = infinite loop (will stop when tap is removed)
	tw.tween_property(alert, "scale", Vector2(1.3, 1.3), 0.3)
	tw.tween_property(alert, "scale", Vector2(1.0, 1.0), 0.3)
	
	add_child(tap)
	active_taps.append(tap)

func _on_tap_closed(tap: Node2D):
	if not game_active or not is_instance_valid(tap):
		return
	
	if not tap.get_meta("running", false):
		return
	
	tap.set_meta("running", false)
	taps_closed += 1
	record_action(true)
	
	# Update score
	get_node("ScoreDisplay").text = "🚰 %d / %d closed" % [taps_closed, target_taps]
	
	# Visual feedback
	var faucet = tap.get_node("Faucet")
	faucet.modulate = Color(0.5, 0.8, 0.5)  # Green briefly
	
	var stream = tap.get_node("Stream")
	stream.visible = false
	
	var alert = tap.get_node("Alert")
	alert.text = "✓"
	alert.add_theme_color_override("font_color", Color.GREEN)
	
	# Remove after brief delay
	var tw = create_tween()
	tw.tween_property(tap, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		active_taps.erase(tap)
		tap.queue_free()
	)
	
	# Check win
	if taps_closed >= target_taps:
		end_game(true)

func _input(event):
	if not game_active: return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if clicked on any active tap
		for tap in active_taps:
			if is_instance_valid(tap) and tap.get_meta("running", false):
				var distance = event.position.distance_to(tap.position)
				if distance < 60:
					_on_tap_closed(tap)
					break
