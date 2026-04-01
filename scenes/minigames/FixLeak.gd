extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## FIX LEAK MINI-GAME
## Teach importance of fixing water leaks immediately
## Difficulty scales: more leaks, faster drips, visual obstructions
## ═══════════════════════════════════════════════════════════════════

var leaks: Array[Node2D] = []
var fixed_leaks: int = 0
var water_wasted: float = 0.0

var num_leaks: int = 3
var drip_speed: float = 1.0
var show_hints: bool = true
var max_water_wasted: float = 100.0

func _ready() -> void:
	game_name = Localization.tr("fix_leak")
	super._ready()

func _apply_difficulty_settings() -> void:
	super._apply_difficulty_settings()

	# Keep difficulty adaptive but realistically playable by humans.
	var complexity = int(difficulty_settings.get("task_complexity", 2))
	var speed_mult = float(difficulty_settings.get("speed_multiplier", 1.0))
	var base_time = float(difficulty_settings.get("time_limit", game_duration))

	num_leaks = clamp(complexity + 1, 2, 5)
	drip_speed = clamp(speed_mult, 0.8, 1.3)
	show_hints = bool(difficulty_settings.get("visual_guidance", true))

	# More leaks require additional reaction time.
	game_duration = base_time + float(num_leaks) * 2.5
	max_water_wasted = 55.0 + float(num_leaks) * 15.0

	if current_difficulty == "Hard":
		drip_speed = min(drip_speed * 1.15, 1.45)
		max_water_wasted = max(70.0, max_water_wasted * 0.85)
		game_duration = max(14.0, game_duration - 2.0)
		show_hints = false

func _on_game_start() -> void:
	_spawn_leaks()
	_create_tools()

func _spawn_leaks() -> void:
	var viewport_size = get_viewport_rect().size
	var placed_positions: Array[Vector2] = []
	
	for i in range(num_leaks):
		var leak = _create_leak()
		leak.position = _get_non_overlapping_leak_pos(viewport_size, placed_positions)
		placed_positions.append(leak.position)
		leaks.append(leak)
		add_child(leak)

func _get_non_overlapping_leak_pos(
	viewport_size: Vector2,
	placed_positions: Array[Vector2]
) -> Vector2:
	var min_distance = 140.0
	for attempt in range(20):
		var candidate = Vector2(
			randf_range(100, viewport_size.x - 100),
			randf_range(200, viewport_size.y - 300)
		)
		var overlaps = false
		for pos in placed_positions:
			if candidate.distance_to(pos) < min_distance:
				overlaps = true
				break
		if not overlaps:
			return candidate

	# Fallback if we failed to find a perfect gap.
	return Vector2(
		randf_range(100, viewport_size.x - 100),
		randf_range(200, viewport_size.y - 300)
	)

func _create_leak() -> Node2D:
	var leak_node = Node2D.new()
	
	# Pipe (broken)
	var pipe = ColorRect.new()
	pipe.color = Color(0.5, 0.5, 0.5)
	pipe.size = Vector2(60, 20)
	pipe.position = Vector2(-30, -10)
	leak_node.add_child(pipe)
	
	# Water drip indicator
	var drip = ColorRect.new()
	drip.color = Color(0.2, 0.6, 1.0, 0.8)
	drip.size = Vector2(10, 10)
	drip.position = Vector2(-5, 10)
	leak_node.add_child(drip)
	
	# Click area (Area2D is more reliable than embedded Control here)
	var click_area = Area2D.new()
	click_area.input_pickable = true
	leak_node.add_child(click_area)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 46.0
	shape.shape = circle
	click_area.add_child(shape)

	click_area.input_event.connect(func(_viewport, event, _shape_idx):
		if event is InputEventMouseButton:
			var mb = event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_on_leak_clicked(leak_node)
		elif event is InputEventScreenTouch:
			var touch = event as InputEventScreenTouch
			if touch.pressed:
				_on_leak_clicked(leak_node)
	)

	# Visual interaction marker
	var icon = Label.new()
	icon.name = "LeakIcon"
	icon.text = "🔧" if show_hints else ""
	icon.add_theme_font_size_override("font_size", 28)
	icon.position = Vector2(-18, -52)
	leak_node.add_child(icon)
	
	# Metadata
	leak_node.set_meta("fixed", false)
	leak_node.set_meta("water_wasted", 0.0)
	leak_node.set_meta("drip", drip)
	
	return leak_node

func _create_tools() -> void:
	# Tool selector
	var tool_panel = PanelContainer.new()
	tool_panel.position = Vector2(20, 120)
	add_child(tool_panel)
	
	var vbox = VBoxContainer.new()
	tool_panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "🔧 Fix the leaks! (%d leaks)" % num_leaks
	label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(label)
	
	if show_hints:
		var hint = Label.new()
		hint.text = "Click each leaking pipe before water reaches %.0f" % max_water_wasted
		hint.add_theme_font_size_override("font_size", 16)
		vbox.add_child(hint)

func _process(delta: float) -> void:
	super._process(delta)
	
	if game_active:
		_update_leaks(delta)
		_check_win_condition()

func _update_leaks(delta: float) -> void:
	for leak in leaks:
		if leak.get_meta("fixed", false):
			continue
		
		# Accumulate wasted water
		var wasted = leak.get_meta("water_wasted", 0.0)
		wasted += delta * drip_speed * 10.0
		leak.set_meta("water_wasted", wasted)
		
		# Animate drip
		var drip = leak.get_meta("drip") as ColorRect
		if drip:
			drip.position.y = 10 + sin(Time.get_ticks_msec() * 0.005) * 5
			drip.modulate.a = 0.5 + sin(Time.get_ticks_msec() * 0.01) * 0.5
		
		# Total water wasted
		water_wasted += delta * drip_speed * 0.1
		
		# Failure condition - too much water wasted
		if water_wasted > max_water_wasted:
			end_game(false)

func _on_leak_clicked(leak: Node2D) -> void:
	if leak.get_meta("fixed", false):
		return
	
	# Fix the leak!
	leak.set_meta("fixed", true)
	fixed_leaks += 1
	
	# Visual feedback
	var drip = leak.get_meta("drip") as ColorRect
	if drip:
		drip.visible = false
	
	# Change icon and disable further clicks
	var icon = leak.get_node_or_null("LeakIcon") as Label
	if icon:
		icon.text = "✅"
		icon.modulate = Color(0.6, 1.0, 0.6)

	var click_area = leak.get_node_or_null("Area2D") as Area2D
	if click_area:
		click_area.input_pickable = false
	
	# Record as correct action
	record_action(true)
	
	# Juice effects
	JuiceEffects.bounce_scale(leak, 1.3, 0.3)
	JuiceEffects.particle_burst(self, leak.position, Color.GREEN, 15)

func _check_win_condition() -> void:
	if fixed_leaks >= num_leaks:
		end_game(true)
