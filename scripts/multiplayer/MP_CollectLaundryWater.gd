extends MultiplayerMiniGameBase

## Bundle 4: Collect Laundry Water
## P1 collects water from washing machine

const MAX_MISSED: int = 5

var water_collected: int = 0
var water_missed: int = 0
var containers: Array = []
var spawn_timer: Timer
var dragging_container: Area2D = null

func get_instructions() -> String:
	return "🧺 COLLECT LAUNDRY WATER\n\nCatch water streams from the washing machine!\nCatch 10 streams to win.\nFill containers to send water to your partner.\n\n⚠️ Miss 5 water streams and lose 1 life!\n🎯 Position containers under water streams"

func get_controls_text() -> String:
	return "🖱️ Drag containers\n🧺 Catch water\n💧 Fill & send"

func _on_multiplayer_ready() -> void:
	game_name = "Collect Laundry Water"
	win_quota = 50 # 10 streams * 5 points
	set_process_input(true)
	
	_create_containers()
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 2.0
	spawn_timer.timeout.connect(_spawn_water_stream)
	add_child(spawn_timer)
	
	_log("🧺 Catch laundry water! Miss %d = lose 1 life" % MAX_MISSED)

func _on_game_start() -> void:
	spawn_timer.start()

func _create_containers() -> void:
	for i in range(3):
		var container = Area2D.new()
		container.position = Vector2(288 + i * 288, 500)
		container.set_meta("capacity", 5)
		container.set_meta("current", 0)
		add_child(container)
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(150, 100)
		collision.shape = shape
		container.add_child(collision)
		
		var visual = Sprite2D.new()
		visual.name = "Visual"
		visual.texture = MiniGameAssets.create_bucket_texture(150, 100, Color(0.9, 0.9, 0.9)) # White container
		container.add_child(visual)
		
		var label = Label.new()
		label.name = "Label"
		label.text = "0/5"
		label.position = Vector2(-20, -70)
		label.add_theme_font_size_override("font_size", 24)
		container.add_child(label)
		
		container.input_event.connect(_on_container_input.bind(container))
		containers.append(container)

func _on_container_input(_viewport: Node, event: InputEvent, _shape_idx: int, container: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_container = container

func _input(event: InputEvent) -> void:
	if not game_active:
		return
	
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_container = null
	
	if event is InputEventMouseMotion and dragging_container:
		dragging_container.position.x = get_global_mouse_position().x
		dragging_container.position.x = clamp(dragging_container.position.x, 75, get_viewport_rect().size.x - 75)

func _spawn_water_stream() -> void:
	var stream = Area2D.new()
	stream.position = Vector2(randf_range(200, 952), -50)
	stream.set_meta("velocity", Vector2(0, 180))
	stream.set_meta("type", "water")
	add_child(stream)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	collision.shape = shape
	stream.add_child(collision)
	
	var visual = ColorRect.new()
	visual.size = Vector2(40, 40)
	visual.position = Vector2(-20, -20)
	visual.color = Color(0.6, 0.6, 0.8)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stream.add_child(visual)
	
	stream.area_entered.connect(_on_water_caught.bind(stream))

func _process(delta: float) -> void:
	if not game_active:
		return
	
	for child in get_children():
		if child is Area2D and child.has_meta("velocity"):
			child.position += child.get_meta("velocity") * delta
			
			if child.position.y > 700:
				water_missed += 1
				_log("❌ Missed water! (%d/%d)" % [water_missed, MAX_MISSED])
				child.queue_free()
				
				if water_missed >= MAX_MISSED:
					water_missed = 0
					if NetworkManager:
						NetworkManager.lose_life()

func _on_water_caught(area: Area2D, stream: Area2D) -> void:
	if not area.has_meta("capacity"):
		return
	
	var current = area.get_meta("current", 0)
	var capacity = area.get_meta("capacity", 5)
	
	if current >= capacity:
		return
	
	current += 1
	area.set_meta("current", current)
	area.get_node("Label").text = "%d/%d" % [current, capacity]
	
	var visual = area.get_node("Visual")
	visual.modulate = Color(0.6, 0.7, 0.9, 0.3 + current * 0.1)
	
	water_collected += 1
	add_score(5)
	stream.queue_free()
	
	if current >= capacity:
		_send_container(area)

func _send_container(container: Area2D) -> void:
	var amount = container.get_meta("capacity", 5)
	send_resource_to_partner("laundry_water", amount, 1.0)
	_log("📤 Sent laundry water!")
	
	container.set_meta("current", 0)
	container.get_node("Label").text = "0/%d" % amount
	container.get_node("Visual").color = Color(0.5, 0.5, 0.5, 0.3)

func _on_game_over() -> void:
	spawn_timer.stop()
	super._on_game_over()
