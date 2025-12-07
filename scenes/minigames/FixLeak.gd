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

func _ready() -> void:
	game_name = Localization.tr("fix_leak")
	super._ready()

func _apply_difficulty_settings() -> void:
	super._apply_difficulty_settings()
	
	num_leaks = difficulty_settings.get("item_count", 3)
	drip_speed = difficulty_settings.get("speed_multiplier", 1.0)
	show_hints = difficulty_settings.get("visual_guidance", false)

func _on_game_start() -> void:
	_spawn_leaks()
	_create_tools()

func _spawn_leaks() -> void:
	var viewport_size = get_viewport_rect().size
	
	for i in range(num_leaks):
		var leak = _create_leak()
		leak.position = Vector2(
			randf_range(100, viewport_size.x - 100),
			randf_range(200, viewport_size.y - 300)
		)
		leaks.append(leak)
		add_child(leak)

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
	
	# Click area
	var button = Button.new()
	button.custom_minimum_size = Vector2(80, 80)
	button.position = Vector2(-40, -40)
	button.text = "🔧" if show_hints else ""
	button.pressed.connect(func(): _on_leak_clicked(leak_node))
	leak_node.add_child(button)
	
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
	label.text = "🔧 Fix the leaks!"
	label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(label)
	
	if show_hints:
		var hint = Label.new()
		hint.text = "Click on leaking pipes"
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
		if water_wasted > 100:
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
	
	# Change button appearance
	for child in leak.get_children():
		if child is Button:
			child.text = "✅"
			child.disabled = true
			child.modulate = Color.GREEN
	
	# Record as correct action
	record_action(true)
	
	# Juice effects
	JuiceEffects.bounce_scale(leak, 1.3, 0.3)
	JuiceEffects.particle_burst(self, leak.position, Color.GREEN, 15)

func _check_win_condition() -> void:
	if fixed_leaks >= num_leaks:
		end_game(true)
