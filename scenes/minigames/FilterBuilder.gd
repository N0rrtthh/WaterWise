extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## FILTER BUILDER - Drag layers to build a water filter
## ═══════════════════════════════════════════════════════════════════

var filter_layers: Array = []
var placed_layers: Array = []
var correct_order: Array = ["gravel", "sand", "charcoal", "cloth"]
var current_drag: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO
var filters_built: int = 0
var target_filters: int = 3

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			target_filters = 2
			game_duration = 35.0
		"Medium":
			target_filters = 3
			game_duration = 30.0
		"Hard":
			target_filters = 4
			game_duration = 25.0

func _ready():
	game_name = "Filter Builder"
	game_instruction_text = Localization.get_text("filter_builder_instructions") if Localization else "DRAG layers in correct order!\nCloth → Charcoal → Sand → Gravel 🧱"
	game_duration = 30.0
	game_mode = "quota"
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.7, 0.85, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Filter container (bottle shape)
	var bottle = Node2D.new()
	bottle.name = "Bottle"
	bottle.position = Vector2(screen_size.x * 0.7, screen_size.y * 0.5)
	add_child(bottle)
	
	var bottle_body = Polygon2D.new()
	bottle_body.polygon = PackedVector2Array([
		Vector2(-60, -150), Vector2(60, -150),
		Vector2(80, 150), Vector2(-80, 150)
	])
	bottle_body.color = Color(0.8, 0.9, 1.0, 0.5)
	bottle.add_child(bottle_body)
	
	var bottle_outline = Line2D.new()
	bottle_outline.points = PackedVector2Array([
		Vector2(-60, -150), Vector2(60, -150),
		Vector2(80, 150), Vector2(-80, 150), Vector2(-60, -150)
	])
	bottle_outline.width = 4
	bottle_outline.default_color = Color(0.4, 0.5, 0.6)
	bottle.add_child(bottle_outline)
	
	# Drop zones
	for i in range(4):
		var zone = ColorRect.new()
		zone.name = "Zone_%d" % i
		zone.size = Vector2(140, 60)
		zone.position = Vector2(-70, -120 + i * 70)
		zone.color = Color(0.5, 0.5, 0.5, 0.3)
		zone.set_meta("index", i)
		bottle.add_child(zone)
	
	# Score display
	var score_display = Label.new()
	score_display.name = "ScoreDisplay"
	score_display.text = "🧱 0 / %d filters" % target_filters
	score_display.add_theme_font_size_override("font_size", 28)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(screen_size.x / 2 - 80, 120)
	add_child(score_display)
	
	# Spawn filter materials
	_spawn_materials()

func _spawn_materials():
	var screen_size = get_viewport_rect().size
	
	# Clear old materials
	for layer in filter_layers:
		if is_instance_valid(layer):
			layer.queue_free()
	filter_layers.clear()
	placed_layers.clear()
	
	# Reset drop zones
	var bottle = get_node("Bottle")
	for i in range(4):
		var zone = bottle.get_node("Zone_%d" % i)
		zone.set_meta("filled", false)
		zone.color = Color(0.5, 0.5, 0.5, 0.3)
	
	# Material definitions
	var materials = [
		{"type": "cloth", "color": Color(0.9, 0.9, 0.85), "label": "🧻 Cloth"},
		{"type": "charcoal", "color": Color(0.2, 0.2, 0.2), "label": "⬛ Charcoal"},
		{"type": "sand", "color": Color(0.9, 0.8, 0.6), "label": "🟨 Sand"},
		{"type": "gravel", "color": Color(0.5, 0.5, 0.5), "label": "🪨 Gravel"}
	]
	
	# Shuffle positions
	var positions = [
		Vector2(screen_size.x * 0.15, screen_size.y * 0.3),
		Vector2(screen_size.x * 0.15, screen_size.y * 0.45),
		Vector2(screen_size.x * 0.15, screen_size.y * 0.6),
		Vector2(screen_size.x * 0.15, screen_size.y * 0.75)
	]
	positions.shuffle()
	
	for i in range(4):
		var mat = materials[i]
		var layer = _create_layer(mat)
		layer.position = positions[i]
		layer.set_meta("original_pos", positions[i])
		add_child(layer)
		filter_layers.append(layer)

func _create_layer(mat: Dictionary) -> Node2D:
	var layer = Node2D.new()
	layer.set_meta("type", mat["type"])
	
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-60, -25), Vector2(60, -25),
		Vector2(60, 25), Vector2(-60, 25)
	])
	body.color = mat["color"]
	layer.add_child(body)
	
	var label = Label.new()
	label.text = mat["label"]
	label.add_theme_font_size_override("font_size", 22)
	label.position = Vector2(-50, -15)
	layer.add_child(label)
	
	return layer

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	_handle_drag()

func _handle_drag():
	var mouse_pos = get_viewport().get_mouse_position()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if current_drag == null:
			# Try to pick up a layer
			for layer in filter_layers:
				if not is_instance_valid(layer): continue
				if layer.get_meta("placed", false): continue
				
				var layer_rect = Rect2(layer.position - Vector2(60, 25), Vector2(120, 50))
				if layer_rect.has_point(mouse_pos):
					current_drag = layer
					drag_offset = layer.position - mouse_pos
					layer.z_index = 10
					break
		else:
			# Move the layer
			current_drag.position = mouse_pos + drag_offset
	else:
		if current_drag != null:
			# Check if dropped on a zone
			var bottle = get_node("Bottle")
			var dropped = false
			
			for i in range(4):
				var zone = bottle.get_node("Zone_%d" % i)
				if zone.get_meta("filled", false): continue
				
				var zone_rect = Rect2(
					bottle.position + zone.position,
					zone.size
				)
				
				if zone_rect.has_point(current_drag.position):
					# Place in zone
					current_drag.position = bottle.position + zone.position + Vector2(70, 30)
					current_drag.set_meta("placed", true)
					current_drag.set_meta("zone_index", i)
					zone.set_meta("filled", true)
					placed_layers.append({"type": current_drag.get_meta("type"), "index": i})
					dropped = true
					
					# Check if filter is complete
					if placed_layers.size() == 4:
						_check_filter()
					break
			
			if not dropped:
				# Return to original position
				var tw = create_tween()
				tw.tween_property(current_drag, "position", current_drag.get_meta("original_pos"), 0.2)
			
			current_drag.z_index = 0
			current_drag = null

func _check_filter():
	# Sort by zone index
	placed_layers.sort_custom(func(a, b): return a["index"] < b["index"])
	
	# Check order: cloth(0), charcoal(1), sand(2), gravel(3)
	var correct = true
	for i in range(4):
		if placed_layers[i]["type"] != correct_order[i]:
			correct = false
			break
	
	if correct:
		filters_built += 1
		record_action(true)
		get_node("ScoreDisplay").text = "🧱 %d / %d filters" % [filters_built, target_filters]
		
		# Success animation
		var flash = ColorRect.new()
		flash.color = Color(0, 1, 0, 0.3)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var tw = create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.3)
		tw.tween_callback(flash.queue_free)
		
		if filters_built >= target_filters:
			end_game(true)
		else:
			await get_tree().create_timer(0.8).timeout
			if game_active:
				_spawn_materials()
	else:
		record_action(false)
		
		# Failure - reset
		var flash = ColorRect.new()
		flash.color = Color(1, 0, 0, 0.3)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var tw = create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.3)
		tw.tween_callback(flash.queue_free)
		
		await get_tree().create_timer(0.5).timeout
		if game_active:
			_spawn_materials()
