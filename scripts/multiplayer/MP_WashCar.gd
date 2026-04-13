extends MultiplayerMiniGameBase

## Bundle 5: Wash Car with Dish Water
## P2 washes car sections using P1's dish water

const MAX_DIRTY_TIME: float = 25.0

var available_water: int = 0
var sections_washed: int = 0
var car_sections: Array = []
var dirty_timer: float = 0.0

func get_instructions() -> String:
	return "🚗 WASH CAR\n\nClick dirty car sections to wash them with dish water!\nSections get dirty over time.\n\n⚠️ Let a section stay dirty for 25 seconds and lose 1 life!\n💧 Need water from partner to wash"

func get_controls_text() -> String:
	return "🖱️ Click sections\n🚗 Wash car\n💧 Use water"

func _on_multiplayer_ready() -> void:
	game_name = "Wash Car"
	set_process_input(true)
	
	_create_water_indicator()
	_create_car()
	
	_log("🚗 Wash car sections! Dirty for %d sec = lose 1 life" % int(MAX_DIRTY_TIME))

func _on_game_start() -> void:
	_make_section_dirty()

func _create_water_indicator() -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(20, 100)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Dish Water:"
	vbox.add_child(title)
	
	var label = Label.new()
	label.name = "WaterLabel"
	label.text = "💧 x 0"
	label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(label)

func _create_car() -> void:
	var sections_data = [
		{"name": "Hood", "pos": Vector2(576, 250)},
		{"name": "Roof", "pos": Vector2(576, 350)},
		{"name": "Door L", "pos": Vector2(400, 350)},
		{"name": "Door R", "pos": Vector2(752, 350)},
		{"name": "Trunk", "pos": Vector2(576, 450)}
	]
	
	for data in sections_data:
		var section = Area2D.new()
		section.position = data["pos"]
		section.set_meta("dirty", false)
		section.set_meta("name", data["name"])
		add_child(section)
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(140, 80)
		collision.shape = shape
		section.add_child(collision)
		
		var visual = Sprite2D.new()
		visual.name = "Visual"
		visual.texture = MiniGameAssets.create_car_texture(140, 80, Color(0.8, 0.2, 0.2))
		section.add_child(visual)
		
		var label = Label.new()
		label.name = "Label"
		label.text = data["name"]
		label.position = Vector2(-40, -50)
		label.add_theme_font_size_override("font_size", 16)
		section.add_child(label)
		
		section.input_event.connect(_on_section_clicked.bind(section))
		car_sections.append(section)

func _make_section_dirty() -> void:
	var clean_sections = car_sections.filter(func(s): return not s.get_meta("dirty", false))
	if clean_sections.is_empty():
		return
	
	var section = clean_sections[randi() % clean_sections.size()]
	section.set_meta("dirty", true)
	section.set_meta("dirty_time", Time.get_ticks_msec())
	section.get_node("Visual").modulate = Color(0.5, 0.4, 0.3)  # Muddy

func _process(_delta: float) -> void:
	if not game_active:
		return
	
	# Check dirty sections
	for section in car_sections:
		if section.get_meta("dirty", false):
			var dirty_time = section.get_meta("dirty_time", Time.get_ticks_msec())
			var elapsed = (Time.get_ticks_msec() - dirty_time) / 1000.0
			
			if elapsed > MAX_DIRTY_TIME:
				_log("💩 Section too dirty - lose 1 life!")
				section.set_meta("dirty", false)
				section.get_node("Visual").modulate = Color(0.8, 0.2, 0.2)
				if NetworkManager:
					NetworkManager.lose_life()

func _on_section_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, section: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_wash(section)

func _try_wash(section: Area2D) -> void:
	if not game_active:
		return
	
	if not section.get_meta("dirty", false):
		return
	
	if available_water <= 0:
		_log("⚠️ No water! Wait for partner")
		return
	
	available_water -= 1
	_update_water_display()
	
	section.set_meta("dirty", false)
	section.get_node("Visual").modulate = Color(1.0, 1.0, 1.0)  # Clean
	
	sections_washed += 1
	add_score(15)
	_log("✨ Washed %s! Total: %d" % [section.get_meta("name"), sections_washed])
	
	# Make another section dirty
	await get_tree().create_timer(2.0).timeout
	_make_section_dirty()

func _on_resource_received(_from_player: int, resource_type: String, amount: int, _quality: float) -> void:
	if resource_type == "dishwater":
		available_water += amount
		_update_water_display()
		_log("📥 Received %d dish water (Total: %d)" % [amount, available_water])

func _update_water_display() -> void:
	var label = get_node_or_null("PanelContainer/VBoxContainer/WaterLabel")
	if label:
		label.text = "💧 x %d" % available_water

func _on_game_over() -> void:
	super._on_game_over()
