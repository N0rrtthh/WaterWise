extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## FILTER BUILDER - Drag layers to build a water filter
## ═══════════════════════════════════════════════════════════════════

var filter_layers: Array = []
var placed_layers: Array = []
var correct_order: Array = ["cloth", "charcoal", "sand", "gravel"]
var current_drag: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO
var filters_built: int = 0
var target_filters: int = 3
var snap_radius: float = 90.0
var show_solution_guide: bool = true
var touch_active: bool = false
var touch_pos: Vector2 = Vector2.ZERO
var undo_button: Button = null

func _apply_difficulty_settings() -> void:
	super._apply_difficulty_settings()

	var complexity = int(difficulty_settings.get("task_complexity", 2))
	var base_time = float(difficulty_settings.get("time_limit", game_duration))

	target_filters = clamp(complexity, 1, 3)
	game_duration = base_time + float(target_filters) * 5.0
	show_solution_guide = bool(difficulty_settings.get("visual_guidance", true))

	match current_difficulty:
		"Easy":
			snap_radius = 130.0
		"Medium":
			snap_radius = 100.0
		"Hard":
			snap_radius = 70.0
			target_filters = max(target_filters, 3)
			game_duration = max(base_time + 9.0, 17.0)
		_:
			snap_radius = 90.0

func _ready():
	game_name = "Filter Builder"
	game_instruction_text = (
		Localization.get_text("filter_builder_instructions")
		if Localization
		else "DRAG layers in correct order!\nCloth → Charcoal → Sand → Gravel 🧱"
	)
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

	_create_solution_guides(bottle)
	
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

	undo_button = Button.new()
	undo_button.name = "UndoButton"
	undo_button.text = "Undo Last"
	undo_button.custom_minimum_size = Vector2(170, 54)
	undo_button.position = Vector2(screen_size.x * 0.45, 170)
	undo_button.pressed.connect(_undo_last_placement)
	add_child(undo_button)
	_refresh_undo_button()
	
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

	# Keep the right answer visible in the bottle as a learning scaffold.
	if show_solution_guide:
		_update_solution_guides()
	_refresh_undo_button()
	
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

func _create_solution_guides(bottle: Node2D) -> void:
	var guide_labels = ["1) Cloth", "2) Charcoal", "3) Sand", "4) Gravel"]
	var guide_colors = [
		Color(0.9, 0.9, 0.85, 0.28),
		Color(0.2, 0.2, 0.2, 0.28),
		Color(0.9, 0.8, 0.6, 0.28),
		Color(0.5, 0.5, 0.5, 0.28)
	]

	for i in range(4):
		var zone = bottle.get_node("Zone_%d" % i) as ColorRect
		if not zone:
			continue

		zone.color = guide_colors[i] if show_solution_guide else Color(0.5, 0.5, 0.5, 0.3)

		var guide = Label.new()
		guide.name = "GuideLabel"
		guide.text = guide_labels[i]
		guide.add_theme_font_size_override("font_size", 16)
		guide.add_theme_color_override("font_color", Color(0.1, 0.15, 0.2, 0.75))
		guide.position = Vector2(8, 18)
		guide.visible = show_solution_guide
		zone.add_child(guide)

func _update_solution_guides() -> void:
	var bottle = get_node("Bottle")
	for i in range(4):
		var zone = bottle.get_node_or_null("Zone_%d" % i) as ColorRect
		if not zone:
			continue
		var guide = zone.get_node_or_null("GuideLabel") as Label
		if guide:
			guide.visible = show_solution_guide and not zone.get_meta("filled", false)

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event = event as InputEventScreenTouch
		touch_active = touch_event.pressed
		touch_pos = touch_event.position
	elif event is InputEventScreenDrag:
		var drag_event = event as InputEventScreenDrag
		touch_active = true
		touch_pos = drag_event.position

func _is_primary_pressing() -> bool:
	return touch_active or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _get_pointer_position() -> Vector2:
	return touch_pos if touch_active else get_viewport().get_mouse_position()

func _handle_drag():
	var pointer_pos = _get_pointer_position()
	
	if _is_primary_pressing():
		if current_drag == null:
			# Try to pick up a layer
			for layer in filter_layers:
				if not is_instance_valid(layer): continue
				
				var layer_rect = Rect2(layer.position - Vector2(60, 25), Vector2(120, 50))
				if layer_rect.has_point(pointer_pos):
					if layer.get_meta("placed", false):
						# Undo placement: free the old zone before re-dragging this layer.
						var previous_zone = int(layer.get_meta("zone_index", -1))
						if previous_zone >= 0:
							var bottle = get_node("Bottle")
							var prev_zone_node = bottle.get_node_or_null("Zone_%d" % previous_zone)
							if prev_zone_node:
								prev_zone_node.set_meta("filled", false)
						layer.set_meta("placed", false)
						layer.set_meta("zone_index", -1)
						placed_layers = placed_layers.filter(func(item):
							return item["type"] != layer.get_meta("type")
						)
						_update_solution_guides()
						_refresh_undo_button()

					current_drag = layer
					drag_offset = layer.position - pointer_pos
					layer.z_index = 10
					break
		else:
			# Move the layer
			current_drag.position = pointer_pos + drag_offset
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
				
				var zone_center = bottle.position + zone.position + (zone.size * 0.5)
				if (
					zone_rect.has_point(current_drag.position)
					or current_drag.position.distance_to(zone_center) <= snap_radius
				):
					var layer_type = current_drag.get_meta("type")
					placed_layers = placed_layers.filter(func(item):
						return item["type"] != layer_type
					)

					# Place in zone
					current_drag.position = bottle.position + zone.position + Vector2(70, 30)
					current_drag.set_meta("placed", true)
					current_drag.set_meta("zone_index", i)
					zone.set_meta("filled", true)
					_update_solution_guides()
					placed_layers.append({"type": layer_type, "index": i})
					_refresh_undo_button()
					dropped = true
					
					# Check if filter is complete
					if placed_layers.size() == 4:
						_check_filter()
					break
			
			if not dropped:
				# Return to original position
				current_drag.set_meta("placed", false)
				current_drag.set_meta("zone_index", -1)
				_update_solution_guides()
				_refresh_undo_button()
				var tw = create_tween()
				tw.tween_property(
					current_drag,
					"position",
					current_drag.get_meta("original_pos"),
					0.2
				)
			
			current_drag.z_index = 0
			current_drag = null

func _check_filter():
	# Sort by zone index
	placed_layers.sort_custom(func(a, b): return a["index"] < b["index"])
	
	# Check order from top to bottom: cloth(0), charcoal(1), sand(2), gravel(3)
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

func _undo_last_placement() -> void:
	if not game_active:
		return
	if current_drag != null:
		return
	if placed_layers.is_empty():
		return

	var last = placed_layers.pop_back()
	var zone_index = int(last.get("index", -1))
	var material_type = str(last.get("type", ""))

	if zone_index >= 0:
		var bottle = get_node("Bottle")
		var zone = bottle.get_node_or_null("Zone_%d" % zone_index)
		if zone:
			zone.set_meta("filled", false)

	for layer in filter_layers:
		if not is_instance_valid(layer):
			continue
		if str(layer.get_meta("type", "")) != material_type:
			continue

		layer.set_meta("placed", false)
		layer.set_meta("zone_index", -1)
		layer.z_index = 0
		var tw = create_tween()
		tw.tween_property(
			layer,
			"position",
			layer.get_meta("original_pos"),
			0.18
		)
		break

	_update_solution_guides()
	_refresh_undo_button()

func _refresh_undo_button() -> void:
	if undo_button:
		undo_button.disabled = placed_layers.is_empty()
