extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## TURN OFF TAP - Quick reaction game to close running taps
## ═══════════════════════════════════════════════════════════════════

var tap_positions: Array = []
var active_taps: Array = []
## The six static faucet fixtures, kept so a viewport change can move them with
## tap_positions instead of leaving them behind at the old margins.
var _tap_fixtures: Array = []
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
	# Localized: the title stayed English above the Filipino objective FIX 58
	# authored. _loc() keeps the English literal as the fallback for the case
	# where the table is not up yet (tools/SceneLoadCheck instantiates that way).
	game_name = _loc("turn_off_tap", "Turn Off Tap")
	game_instruction_text = Localization.get_text("turn_off_tap_instructions") if Localization else "TAP running faucets to turn them off!\nDon't waste water! 🚿"
	game_duration = 25.0
	game_mode = "quota"
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background - Bathroom
	var bg = ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color(0.85, 0.9, 0.92)
	bg.position = Vector2.ZERO
	bg.size = screen_size
	bg.z_index = -10
	add_child(bg)
	
	# Tile pattern
	_build_tiles(screen_size)
	# Generate tap positions (3 columns x 2 rows)
	tap_positions = _tap_layout(screen_size)
	
	# Create tap fixtures at each position
	for pos in tap_positions:
		var fixture = _create_tap_fixture(pos)
		add_child(fixture)
		_tap_fixtures.append(fixture)
	
	# Score display
	var score_display = Label.new()
	score_display.name = "ScoreDisplay"
	score_display.text = _loc("hud_taps_closed", "🚰 %d / %d closed") % [0, target_taps]
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
	waste_label.text = _loc("hud_water_ok", "💧 Water: OK")
	waste_label.add_theme_font_size_override("font_size", 18)
	waste_label.add_theme_color_override("font_color", Color.WHITE)
	waste_label.position = Vector2(screen_size.x - 220, 148)
	add_child(waste_label)
	
	_connect_viewport_resize()

func _connect_viewport_resize() -> void:
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.connect(_on_viewport_size_changed)


## Re-lay out after a viewport change (device rotation, window resize, split view).
##
## Every position in _ready() came from a single get_viewport_rect() read, so a rotation
## left the backdrop and the checkerboard at the old size, pushed the three right-anchored
## waste widgets off-screen (they are placed at x - 220), and left the six taps clustered
## in the old margins. Same pattern as MP_CatchRainAquarium._on_viewport_size_changed().
##
## The taps already on screen move in step with tap_positions, matched on their OLD
## position, because _spawn_tap() decides whether a slot is occupied with an exact
## `tap.position == tap_positions[i]` compare: renumbering the slots without moving what
## stands on them would make every occupied slot read as free.
func _on_viewport_size_changed() -> void:
	if not is_inside_tree():
		return
	var screen_size: Vector2 = get_viewport_rect().size
	var new_positions: Array = _tap_layout(screen_size)
	if new_positions.size() == tap_positions.size():
		for i in range(tap_positions.size()):
			var old_pos: Vector2 = tap_positions[i]
			var new_pos: Vector2 = new_positions[i]
			for tap in active_taps:
				if is_instance_valid(tap) and tap.position == old_pos:
					tap.position = new_pos
			for fixture in _tap_fixtures:
				if is_instance_valid(fixture) and fixture.position == old_pos:
					fixture.position = new_pos
		tap_positions = new_positions
	var bg = get_node_or_null("Backdrop")
	if bg:
		bg.size = screen_size
	_build_tiles(screen_size)
	for hud_name in ["WasteBg", "WasteBar", "WasteLabel"]:
		var hud_node = get_node_or_null(hud_name)
		if hud_node == null:
			continue
		hud_node.position = Vector2(
			screen_size.x - 220.0,
			148.0 if hud_name == "WasteLabel" else 120.0
		)


## Where the six taps sit for a given viewport (3 columns x 2 rows).
##
## The step between rows and columns is (span / (count - 1)), because the first and last
## positions sit ON the margins. It used to divide both spans by a literal 2, which is
## (count - 1) for the 3 columns and NOT for the 2 rows: the second row landed at
## margin_y + (h - 2*margin_y)/2, the vertical CENTRE of the screen, so every tap was in
## the top half and the bottom 50% of the playfield was dead space. Measured at 1920x1080:
## rows at y=180 and y=540 with nothing below 590.
##
## margin_y also has to clear the HUD band, which the base and this scene fill down to
## about y=180 (waste bar at y=120..145, its label at y=148..178, score readout at y=120).
## The top row's 100x100 tap button is drawn from margin_y - 50, so a 180 margin put the
## top-right tap UNDER the "Water: OK" readout - a tappable target with HUD text over it.
func _tap_layout(screen_size: Vector2) -> Array:
	var tap_cols: int = 3
	var tap_rows: int = 2
	var margin_x: float = 100.0
	var margin_y: float = 240.0
	var spacing_x: float = (screen_size.x - margin_x * 2.0) / float(maxi(tap_cols - 1, 1))
	var spacing_y: float = (screen_size.y - margin_y * 2.0) / float(maxi(tap_rows - 1, 1))
	var out: Array = []
	for row in range(tap_rows):
		for col in range(tap_cols):
			out.append(Vector2(
				margin_x + col * spacing_x,
				margin_y + row * spacing_y
			))
	return out


## (Re)build the bathroom checkerboard for a given viewport.
##
## remove_child() runs BEFORE queue_free() so the name "TileGrid" is free again in the
## same frame: a queued-but-not-yet-freed sibling keeps its name, the replacement would
## silently become "@Node2D@2", and the get_node_or_null() above would then miss it on
## every later resize and leak one 48-tile grid per event.
func _build_tiles(screen_size: Vector2) -> void:
	var old_grid: Node = get_node_or_null("TileGrid")
	if old_grid:
		remove_child(old_grid)
		old_grid.queue_free()
	var grid := Node2D.new()
	grid.name = "TileGrid"
	grid.z_index = -9
	add_child(grid)
	for row in range(8):
		for col in range(6):
			var tile = ColorRect.new()
			tile.size = Vector2(screen_size.x / 6, screen_size.y / 8)
			tile.position = Vector2(col * tile.size.x, row * tile.size.y)
			tile.color = Color(0.82, 0.87, 0.89) if (row + col) % 2 == 0 else Color(0.85, 0.9, 0.92)
			grid.add_child(tile)


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
		waste_label.text = _loc("hud_water_ok", "💧 Water: OK")
	elif waste_ratio < 0.8:
		waste_bar.color = Color(0.9, 0.7, 0.2)
		waste_label.text = _loc("hud_water_caution", "💧 Water: Caution!")
	else:
		waste_bar.color = Color(0.9, 0.3, 0.2)
		waste_label.text = _loc("hud_water_critical", "💧 Water: CRITICAL!")
	
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
	button.modulate.a = 0.0  # Invisible
	button.pressed.connect(_on_tap_closed.bind(tap))
	tap.add_child(button)
	# Centred after growth, not at the authored offset: the 48dp floor enlarges this button.
	centre_hit_control(button)
	
	# Alert indicator
	var alert = Label.new()
	alert.name = "Alert"
	alert.text = "❗"
	alert.add_theme_font_size_override("font_size", 30)
	alert.position = Vector2(25, -50)
	tap.add_child(alert)
	
	# Pulse animation - loops indefinitely while tap is active
	var tw = alert.create_tween().set_loops()
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
	get_node("ScoreDisplay").text = _loc("hud_taps_closed", "🚰 %d / %d closed") % [taps_closed, target_taps]
	
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
				if distance < 74:
					_on_tap_closed(tap)
					break
