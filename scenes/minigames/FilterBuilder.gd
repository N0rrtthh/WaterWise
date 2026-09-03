extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## FILTER BUILDER - Drag layers to build a water filter
## ═══════════════════════════════════════════════════════════════════

## Half-extent of a layer's grab box. 75 makes it a 150-unit square, clearing the 48dp
## touch floor (147 canvas units on WVGA 4.5in, the densest profile shipped) in both axes.
## The authored box was 120x50 - 16dp tall - which tools/VerifyTouchTargets.tscn measured
## as the smallest grab target in the single-player set. The layer art stays strip-shaped;
## the extra reach is hit area only, which is why the pick resolves to the nearest layer.
const LAYER_GRAB_HALF: Vector2 = Vector2(75.0, 75.0)

## The four materials, in the order the filter must be stacked. The layer chips and the
## faint solution guides have to name them identically, and both used to carry their own
## English literal ("🧻 Cloth" on the chip, "1) Cloth" on the guide), so the Filipino build
## showed English on the only two labels this game has. One table, one key per material:
## the emoji stays out of the key so the guide can print the plain name.
const MATERIALS: Array[Dictionary] = [
	{"type": "cloth", "emoji": "🧻", "key": "material_cloth", "label": "Cloth"},
	{"type": "charcoal", "emoji": "⬛", "key": "material_charcoal", "label": "Charcoal"},
	{"type": "sand", "emoji": "🟨", "key": "material_sand", "label": "Sand"},
	{"type": "gravel", "emoji": "⛰️", "key": "material_gravel", "label": "Gravel"},
]

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
## Which contact owns the carry. touch_active used to be assigned from ANY
## contact's pressed flag, so a second finger lifting dropped the layer still held
## under the first, and touch_pos followed whichever finger moved last - teleporting
## the carried layer across the screen. Mouse events carry no index of their own.
const NO_TOUCH_INDEX: int = -1
var _touch_index: int = NO_TOUCH_INDEX
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

	# Medium and Hard end on wrong placements, not on the clock.
	#
	# The stack order (cloth -> charcoal -> sand -> gravel) is knowledge, and Hard
	# turns visual_guidance off, so at that tier the player is recalling it rather
	# than reading it. 3 filters x 4 layers is 12 drags inside ~17 s once the guide
	# is gone: about 1.4 s each to remember, pick up and snap. There is an undo
	# button, which only makes sense if thinking is what the game rewards.
	use_attempt_budget(0, 5, 4)

func _ready():
	# Localized: the title stayed English above the Filipino objective FIX 58
	# authored. _loc() keeps the English literal as the fallback for the case
	# where the table is not up yet (tools/SceneLoadCheck instantiates that way).
	game_name = _loc("filter_builder", "Filter Builder")
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
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
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
	score_display.text = _loc("hud_filters_built", "🧱 %d / %d filters") % [0, target_filters]
	score_display.add_theme_font_size_override("font_size", 28)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(screen_size.x / 2 - 80, 120)
	add_child(score_display)

	undo_button = Button.new()
	undo_button.name = "UndoButton"
	undo_button.text = _loc("hud_undo_last", "Undo Last")
	undo_button.custom_minimum_size = Vector2(170, 54)
	undo_button.position = Vector2(screen_size.x * 0.45, 170)
	undo_button.pressed.connect(_undo_last_placement)
	MiniGameAssets.outline_text(undo_button)
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
		{"type": "cloth", "color": Color(0.9, 0.9, 0.85)},
		{"type": "charcoal", "color": Color(0.2, 0.2, 0.2)},
		{"type": "sand", "color": Color(0.9, 0.8, 0.6)},
		{"type": "gravel", "color": Color(0.5, 0.5, 0.5)}
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
		guide.text = "%d) %s" % [i + 1, _loc(str(MATERIALS[i]["key"]), str(MATERIALS[i]["label"]))]
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

## Chip caption for one material: the emoji stays outside the translation table (it is
## language-neutral) and the name comes from it, so the Filipino build reads
## "🧻 Tela" instead of the English literal this used to carry inline.
func _material_caption(mat_type: String) -> String:
	for m in MATERIALS:
		if str(m["type"]) == mat_type:
			return "%s %s" % [str(m["emoji"]), _loc(str(m["key"]), str(m["label"]))]
	return mat_type

func _create_layer(mat: Dictionary) -> Node2D:
	var layer = Node2D.new()
	layer.set_meta("type", mat["type"])
	
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-66, -33), Vector2(66, -33),
		Vector2(66, 33), Vector2(-66, 33)
	])
	body.color = mat["color"]
	layer.add_child(body)
	
	var label = Label.new()
	label.text = _material_caption(str(mat["type"]))
	label.add_theme_font_size_override("font_size", 22)
	label.position = Vector2(-50, -15)
	MiniGameAssets.outline_text(label)
	layer.add_child(label)
	
	return layer

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	_handle_drag()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event = event as InputEventScreenTouch
		if touch_event.pressed:
			if _touch_index == NO_TOUCH_INDEX:
				_touch_index = touch_event.index
			if touch_event.index != _touch_index:
				return
			touch_active = true
			touch_pos = touch_event.position
		elif touch_event.index == _touch_index:
			touch_active = false
			_touch_index = NO_TOUCH_INDEX
	elif event is InputEventScreenDrag:
		var drag_event = event as InputEventScreenDrag
		if _touch_index == NO_TOUCH_INDEX:
			_touch_index = drag_event.index
		if drag_event.index != _touch_index:
			return
		touch_active = true
		touch_pos = drag_event.position

func _is_primary_pressing() -> bool:
	return touch_active or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _get_pointer_position() -> Vector2:
	if touch_active:
		return touch_pos
	var viewport = get_viewport()
	return viewport.get_mouse_position() if viewport else Vector2.ZERO

func _handle_drag():
	var pointer_pos = _get_pointer_position()
	
	if _is_primary_pressing():
		if current_drag == null:
			# Nearest layer under the pointer, not the first in the list. The grab box is the
			# 48dp floor square (150 units) while a PLACED layer sits in a bottle zone only 70
			# units from its neighbour, so up to three share one finger - and first-match handed
			# back whichever was authored earliest instead of the one being pointed at.
			var pick: Node2D = null
			var pick_d: float = INF
			for candidate in filter_layers:
				if not is_instance_valid(candidate): continue
				var cand_rect := Rect2(candidate.position - LAYER_GRAB_HALF, LAYER_GRAB_HALF * 2.0)
				if not cand_rect.has_point(pointer_pos): continue
				var cand_d: float = pointer_pos.distance_squared_to(candidate.position)
				if cand_d < pick_d:
					pick_d = cand_d
					pick = candidate as Node2D
			if pick != null:
				var layer: Node2D = pick
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
		get_node("ScoreDisplay").text = _loc("hud_filters_built", "🧱 %d / %d filters") % [filters_built, target_filters]
		
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
			await round_delay(0.8)
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
		
		await round_delay(0.5)
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
