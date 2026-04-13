extends MultiplayerMiniGameBase

## Bundle 2: Flush Toilet with Shower Water
## P2 uses P1's shower water to flush toilet

const MAX_UNFLUSHED: int = 3

var available_water: int = 0
var toilets_flushed: int = 0
var unflushed_count: int = 0
var toilets: Array = []
var spawn_timer: Timer

func get_instructions() -> String:
	return "🚽 FLUSH TOILETS\n\nClick on dirty toilets to flush them with shower water!\nToilets get dirty every 8 seconds.\n\n⚠️ Leave 3 toilets unflushed and lose 1 life!\n💧 Need water from partner to flush"

func get_controls_text() -> String:
	return "🖱️ Click toilets\n🚽 Flush them\n💧 Use water"

func _on_multiplayer_ready() -> void:
	game_name = "Flush Toilets"
	set_process_input(true)
	
	_create_water_indicator()
	_create_toilets()
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 8.0
	spawn_timer.timeout.connect(_mark_toilet_dirty)
	add_child(spawn_timer)
	
	_log("🚽 Flush toilets with shower water! %d unflushed = lose 1 life" % MAX_UNFLUSHED)

func _on_game_start() -> void:
	spawn_timer.start()

func _create_water_indicator() -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(20, 100)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Shower Water:"
	vbox.add_child(title)
	
	var label = Label.new()
	label.name = "WaterLabel"
	label.text = "💧 x 0"
	label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(label)

func _create_toilets() -> void:
	for i in range(6):
		var toilet = Area2D.new()
		var row = floori(i / 3.0)
		var col = i % 3
		toilet.position = Vector2(350 + col * 250, 200 + row * 250)
		toilet.set_meta("needs_flush", false)
		add_child(toilet)
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(120, 140)
		collision.shape = shape
		toilet.add_child(collision)
		
		var visual = Sprite2D.new()
		visual.name = "Visual"
		visual.texture = MiniGameAssets.create_toilet_texture(120, 140)
		toilet.add_child(visual)
		
		var label = Label.new()
		label.name = "Label"
		label.text = "🚽 Clean"
		label.position = Vector2(-40, -90)
		label.add_theme_font_size_override("font_size", 20)
		toilet.add_child(label)
		
		toilet.input_event.connect(_on_toilet_clicked.bind(toilet))
		toilets.append(toilet)

func _mark_toilet_dirty() -> void:
	var clean_toilets = toilets.filter(func(t): return not t.get_meta("needs_flush", false))
	if clean_toilets.is_empty():
		return
	
	var toilet = clean_toilets[randi() % clean_toilets.size()]
	toilet.set_meta("needs_flush", true)
	toilet.get_node("Visual").modulate = Color(0.8, 0.7, 0.4)
	toilet.get_node("Label").text = "🚽 Dirty"
	
	unflushed_count += 1
	_log("💩 Toilet dirty! (%d/%d)" % [unflushed_count, MAX_UNFLUSHED])
	
	if unflushed_count >= MAX_UNFLUSHED:
		unflushed_count = 0
		if NetworkManager:
			NetworkManager.lose_life()

func _on_toilet_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, toilet: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_flush(toilet)

func _try_flush(toilet: Area2D) -> void:
	if not game_active:
		return
	
	if not toilet.get_meta("needs_flush", false):
		return
	
	if available_water <= 0:
		_log("⚠️ No water! Wait for partner")
		return
	
	available_water -= 1
	_update_water_display()
	
	toilet.set_meta("needs_flush", false)
	toilet.get_node("Visual").modulate = Color(1.0, 1.0, 1.0)
	toilet.get_node("Label").text = "🚽 Clean"
	
	toilets_flushed += 1
	unflushed_count = max(0, unflushed_count - 1)
	add_score(10)
	_log("✨ Flushed toilet! Total: %d" % toilets_flushed)

func _on_resource_received(_from_player: int, resource_type: String, amount: int, _quality: float) -> void:
	if resource_type == "shower_water":
		available_water += amount
		_update_water_display()
		_log("📥 Received %d shower water (Total: %d)" % [amount, available_water])

func _update_water_display() -> void:
	var label = get_node_or_null("PanelContainer/VBoxContainer/WaterLabel")
	if label:
		label.text = "💧 x %d" % available_water

func _on_game_over() -> void:
	spawn_timer.stop()
	super._on_game_over()
