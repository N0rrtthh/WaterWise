extends MultiplayerMiniGameBase

## Bundle 4: Mop Floor with Laundry Water
## P2 mops floors using P1's laundry water

const MAX_DIRTY_TILES: int = 10

var available_water: int = 0
var tiles_mopped: int = 0
var floor_tiles: Array = []
var dirty_timer: Timer

func get_instructions() -> String:
	return "🧹 MOP FLOOR\n\nClick dirty tiles to mop them with laundry water!\nTiles get dirty every 5 seconds.\n\n⚠️ Let 10 tiles stay dirty and lose 1 life!\n💧 Need water from partner to mop"

func get_controls_text() -> String:
	return "🖱️ Click tiles\n🧹 Mop floor\n💧 Use water"

func _on_multiplayer_ready() -> void:
	game_name = "Mop Floor"
	
	_create_water_indicator()
	_create_floor()
	
	dirty_timer = Timer.new()
	dirty_timer.wait_time = 5.0
	dirty_timer.timeout.connect(_make_tile_dirty)
	add_child(dirty_timer)
	
	_log("🧹 Mop dirty tiles! %d dirty tiles = lose 1 life" % MAX_DIRTY_TILES)

func _on_game_start() -> void:
	dirty_timer.start()

func _create_water_indicator() -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(20, 100)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Laundry Water:"
	vbox.add_child(title)
	
	var label = Label.new()
	label.name = "WaterLabel"
	label.text = "💧 x 0"
	label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(label)

func _create_floor() -> void:
	for row in range(4):
		for col in range(5):
			var tile = Area2D.new()
			tile.position = Vector2(300 + col * 140, 200 + row * 120)
			tile.set_meta("dirty", false)
			add_child(tile)
			
			var collision = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = Vector2(120, 100)
			collision.shape = shape
			tile.add_child(collision)
			
			var visual = ColorRect.new()
			visual.name = "Visual"
			visual.size = Vector2(120, 100)
			visual.position = Vector2(-60, -50)
			visual.color = Color(0.9, 0.9, 0.9)
			visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(visual)
			
			# Add tile texture
			var texture_rect = TextureRect.new()
			texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			texture_rect.modulate = Color(0, 0, 0, 0.1) # Subtle pattern
			visual.add_child(texture_rect)
			
			tile.input_event.connect(_on_tile_clicked.bind(tile))
			floor_tiles.append(tile)

func _make_tile_dirty() -> void:
	var clean_tiles = floor_tiles.filter(func(t): return not t.get_meta("dirty", false))
	if clean_tiles.is_empty():
		return
	
	var tile = clean_tiles[randi() % clean_tiles.size()]
	tile.set_meta("dirty", true)
	tile.get_node("Visual").color = Color(0.5, 0.4, 0.3)
	
	var dirty_count = floor_tiles.filter(func(t): return t.get_meta("dirty", false)).size()
	if dirty_count >= MAX_DIRTY_TILES:
		_log("💩 Too many dirty tiles - lose 1 life!")
		if NetworkManager:
			NetworkManager.lose_life()
		_clean_all_tiles()

func _clean_all_tiles() -> void:
	for tile in floor_tiles:
		tile.set_meta("dirty", false)
		tile.get_node("Visual").color = Color(0.9, 0.9, 0.9)

func _on_tile_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, tile: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_mop(tile)

func _try_mop(tile: Area2D) -> void:
	if not game_active:
		return
	
	if not tile.get_meta("dirty", false):
		return
	
	if available_water <= 0:
		_log("⚠️ No water! Wait for partner")
		return
	
	available_water -= 1
	_update_water_display()
	
	tile.set_meta("dirty", false)
	tile.get_node("Visual").color = Color(0.9, 0.9, 0.9)
	
	tiles_mopped += 1
	add_score(10)
	_log("✨ Mopped tile! Total: %d" % tiles_mopped)

func _on_resource_received(_from_player: int, resource_type: String, amount: int, _quality: float) -> void:
	if resource_type == "laundry_water":
		available_water += amount
		_update_water_display()
		_log("📥 Received %d laundry water (Total: %d)" % [amount, available_water])

func _update_water_display() -> void:
	var label = get_node_or_null("PanelContainer/VBoxContainer/WaterLabel")
	if label:
		label.text = "💧 x %d" % available_water

func _on_game_over() -> void:
	dirty_timer.stop()
	super._on_game_over()
