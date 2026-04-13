extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## TRACE PIPE PATH - Draw/trace to connect water pipes
## ═══════════════════════════════════════════════════════════════════

var path_points: Array = []
var target_path: Array = []
var is_drawing: bool = false
var paths_completed: int = 0
var target_paths: int = 4
var path_tolerance: float = 40.0

func _apply_difficulty_settings() -> void:
	# Get progressive difficulty settings
	var settings = AdaptiveDifficulty.get_difficulty_settings() if AdaptiveDifficulty else {}
	var progressive_level = settings.get("progressive_level", 0)
	
	match current_difficulty:
		"Easy":
			target_paths = 2  # 25s / 2 = 12.5s per path
			path_tolerance = 50.0
			game_duration = 25.0
		"Medium":
			target_paths = 3  # 25s / 3 = 8.3s per path
			path_tolerance = 40.0
			game_duration = 25.0
		"Hard":
			target_paths = 3  # 18s / 3 = 6.0s per path
			path_tolerance = 25.0
			game_duration = 18.0
	
	# Apply PROGRESSIVE DIFFICULTY (NO CEILING!)
	if progressive_level > 0:
		target_paths += mini(progressive_level, 2)  # +1 path per level, max +2
		path_tolerance = max(15.0, path_tolerance - progressive_level * 2.0)  # Stricter accuracy
		game_duration += progressive_level * 3.0  # Give more time for extra paths
		if settings.has("time_limit"):
			game_duration = max(game_duration, settings.get("time_limit", game_duration))
		print("🔥 Progressive Lvl %d: %d paths, %.1f tolerance" % [progressive_level, target_paths, path_tolerance])

func _ready():
	game_name = "Trace Pipe Path"
	game_instruction_text = Localization.get_text("trace_pipe_instructions") if Localization else "DRAW along the pipe to connect water!\nFollow the dotted line! 🔧"
	game_duration = 30.0
	game_mode = "quota"
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.85, 0.85, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Drawing canvas
	var canvas = Node2D.new()
	canvas.name = "Canvas"
	add_child(canvas)
	
	# Player's drawn line
	var player_line = Line2D.new()
	player_line.name = "DrawLine"
	player_line.width = 15
	player_line.default_color = Color(0.3, 0.5, 0.8)
	player_line.joint_mode = Line2D.LINE_JOINT_ROUND
	player_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	player_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	canvas.add_child(player_line)
	
	# Target pipe line (dotted)
	var target_line = Line2D.new()
	target_line.name = "TargetLine"
	target_line.width = 20
	target_line.default_color = Color(0.5, 0.5, 0.5, 0.5)
	canvas.add_child(target_line)
	
	# Score display
	var score_display = Label.new()
	score_display.name = "ScoreDisplay"
	score_display.text = "🔧 0 / %d" % target_paths
	score_display.add_theme_font_size_override("font_size", 28)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(screen_size.x / 2 - 60, 120)
	add_child(score_display)
	
	# Start indicator
	var start_marker = Label.new()
	start_marker.name = "StartMarker"
	start_marker.text = "🚰"
	start_marker.add_theme_font_size_override("font_size", 50)
	add_child(start_marker)
	
	# End indicator
	var end_marker = Label.new()
	end_marker.name = "EndMarker"
	end_marker.text = "🌱"
	end_marker.add_theme_font_size_override("font_size", 50)
	add_child(end_marker)
	
	_generate_path()

func _generate_path():
	var screen_size = get_viewport_rect().size
	path_points.clear()
	target_path.clear()
	
	# Clear drawn line
	var canvas = get_node("Canvas")
	var player_line = canvas.get_node("DrawLine")
	player_line.clear_points()
	
	# Generate random curved path
	var start = Vector2(100, screen_size.y * 0.5)
	var end = Vector2(screen_size.x - 100, screen_size.y * 0.5)
	
	# Add control points for curve
	target_path.append(start)
	
	var num_segments = randi_range(2, 4)
	for i in range(num_segments):
		var t = float(i + 1) / float(num_segments + 1)
		var mid_x = lerp(start.x, end.x, t)
		var mid_y = screen_size.y * 0.5 + randf_range(-150, 150)
		target_path.append(Vector2(mid_x, mid_y))
	
	target_path.append(end)
	
	# Draw target line
	var target_line = canvas.get_node("TargetLine")
	target_line.clear_points()
	
	# Create smooth curve through points
	for i in range(target_path.size() - 1):
		var p1 = target_path[i]
		var p2 = target_path[i + 1]
		for t in range(10):
			var point = p1.lerp(p2, t / 10.0)
			target_line.add_point(point)
	target_line.add_point(target_path[-1])
	
	# Position markers
	get_node("StartMarker").position = start - Vector2(25, 25)
	get_node("EndMarker").position = end - Vector2(25, 25)

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	_handle_drawing()

func _handle_drawing():
	var mouse_pos = get_viewport().get_mouse_position()
	var canvas = get_node("Canvas")
	var player_line = canvas.get_node("DrawLine")
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_drawing:
			# Start drawing - must be near start point
			if mouse_pos.distance_to(target_path[0]) < 60:
				is_drawing = true
				path_points.clear()
				player_line.clear_points()
		
		if is_drawing:
			# Add point if moved enough
			if path_points.is_empty() or mouse_pos.distance_to(path_points[-1]) > 10:
				path_points.append(mouse_pos)
				player_line.add_point(mouse_pos)
	else:
		if is_drawing:
			is_drawing = false
			_check_path()

func _check_path():
	if path_points.size() < 5:
		_fail_path()
		return
	
	# Check if reached end point
	if path_points[-1].distance_to(target_path[-1]) > 60:
		_fail_path()
		return
	
	# Check if path followed target closely enough
	var total_deviation = 0.0
	var check_count = 0
	
	for point in path_points:
		var min_dist = INF
		for target_point in target_path:
			min_dist = min(min_dist, point.distance_to(target_point))
		# Also check against interpolated points
		var canvas = get_node("Canvas")
		var target_line = canvas.get_node("TargetLine")
		for i in range(target_line.get_point_count()):
			min_dist = min(min_dist, point.distance_to(target_line.get_point_position(i)))
		
		total_deviation += min_dist
		check_count += 1
	
	var avg_deviation = total_deviation / check_count
	
	if avg_deviation <= path_tolerance:
		_complete_path()
	else:
		_fail_path()

func _complete_path():
	paths_completed += 1
	record_action(true)
	get_node("ScoreDisplay").text = "🔧 %d / %d" % [paths_completed, target_paths]
	
	# Success effect - water flows
	var canvas = get_node("Canvas")
	var player_line = canvas.get_node("DrawLine")
	player_line.default_color = Color(0.2, 0.7, 0.9)
	
	var flash = ColorRect.new()
	flash.color = Color(0, 1, 0, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)
	
	if paths_completed >= target_paths:
		end_game(true)
	else:
		await get_tree().create_timer(0.8).timeout
		if game_active:
			_generate_path()

func _fail_path():
	record_action(false)
	
	var canvas = get_node("Canvas")
	var player_line = canvas.get_node("DrawLine")
	player_line.default_color = Color(0.9, 0.3, 0.3)
	
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
		player_line.default_color = Color(0.3, 0.5, 0.8)
		player_line.clear_points()
		path_points.clear()
