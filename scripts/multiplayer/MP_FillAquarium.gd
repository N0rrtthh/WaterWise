extends MultiplayerMiniGameBase

## Bundle 3: Fill Aquarium with Rain
## P2 fills aquarium with P1's rainwater

const MAX_EMPTY_TIME: float = 20.0

var available_water: int = 0
var aquarium_level: float = 0.0
var aquarium_max: float = 100.0
var empty_timer: float = 0.0
var aquarium_visual: ColorRect

func get_instructions() -> String:
	return "🐟 FILL AQUARIUM\n\nClick aquarium to add rainwater from your partner!\nFill to 100% to win.\nWater evaporates slowly - keep it above 5%.\n\n⚠️ Let aquarium stay empty for 20 seconds and lose 1 life!\n💧 Wait for partner to catch rain"

func get_controls_text() -> String:
	return "🖱️ Click aquarium\n💧 Add water\n🐟 Keep full"

func _on_multiplayer_ready() -> void:
	game_name = "Fill Aquarium"
	win_quota = 100 # 10 adds * 10 points
	
	_create_water_indicator()
	_create_aquarium()
	
	_log("🐟 Fill aquarium with rain! Empty for %d sec = lose 1 life" % int(MAX_EMPTY_TIME))

func _on_game_start() -> void:
	_log("💧 Waiting for rainwater...")

func _create_water_indicator() -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(20, 100)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Rainwater:"
	vbox.add_child(title)
	
	var label = Label.new()
	label.name = "WaterLabel"
	label.text = "💧 x 0"
	label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(label)
	
	var info = Label.new()
	info.text = "Click aquarium to fill"
	vbox.add_child(info)

func _create_aquarium() -> void:
	var aquarium = Area2D.new()
	aquarium.position = Vector2(576, 350)
	add_child(aquarium)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(300, 400)
	collision.shape = shape
	aquarium.add_child(collision)
	
	# Tank outline
	var outline = ColorRect.new()
	outline.size = Vector2(300, 400)
	outline.position = Vector2(-150, -200)
	outline.color = Color(0.5, 0.7, 1.0, 0.2)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aquarium.add_child(outline)
	
	# Water level
	aquarium_visual = ColorRect.new()
	aquarium_visual.name = "Water"
	aquarium_visual.size = Vector2(300, 0)
	aquarium_visual.position = Vector2(-150, 200)
	aquarium_visual.color = Color(0.3, 0.6, 1.0, 0.7)
	aquarium_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aquarium.add_child(aquarium_visual)
	
	var label = Label.new()
	label.name = "Label"
	label.text = "🐟 AQUARIUM\n0%"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-80, -240)
	label.add_theme_font_size_override("font_size", 24)
	aquarium.add_child(label)
	
	aquarium.input_event.connect(_on_aquarium_clicked)

func _on_aquarium_clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_fill()

func _try_fill() -> void:
	if not game_active:
		return
	
	if available_water <= 0:
		_log("⚠️ No water! Wait for partner to catch rain")
		return
	
	available_water -= 1
	_update_water_display()
	
	aquarium_level = min(aquarium_max, aquarium_level + 10.0)
	_update_aquarium()
	
	add_score(10)
	empty_timer = 0.0  # Reset empty timer
	_log("💧 Added water! Level: %.1f%%" % (aquarium_level / aquarium_max * 100))

func _process(delta: float) -> void:
	if not game_active:
		return
	
	# Water evaporates
	aquarium_level = max(0, aquarium_level - delta * 2.0)
	_update_aquarium()
	
	# Check if empty too long
	if aquarium_level <= 5.0:
		empty_timer += delta
		if empty_timer >= MAX_EMPTY_TIME:
			_log("💀 Aquarium empty too long - lose 1 life!")
			empty_timer = 0
			if NetworkManager:
				NetworkManager.lose_life()

func _update_aquarium() -> void:
	if aquarium_visual:
		var height = (aquarium_level / aquarium_max) * 400
		aquarium_visual.size.y = height
		aquarium_visual.position.y = 200 - height
	
	var label = get_node_or_null("Area2D/Label")
	if label:
		label.text = "🐟 AQUARIUM\n%.0f%%" % (aquarium_level / aquarium_max * 100)

func _on_resource_received(_from_player: int, resource_type: String, amount: int, _quality: float) -> void:
	if resource_type == "rainwater":
		available_water += amount
		_update_water_display()
		_log("📥 Received %d rainwater (Total: %d)" % [amount, available_water])

func _update_water_display() -> void:
	var label = get_node_or_null("PanelContainer/VBoxContainer/WaterLabel")
	if label:
		label.text = "💧 x %d" % available_water

func _on_game_over() -> void:
	super._on_game_over()
