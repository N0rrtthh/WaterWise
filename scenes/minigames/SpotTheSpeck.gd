extends MiniGameBase

var glasses: Array = []
var current_glass: Node2D = null
var glasses_checked: int = 0
var correct_choices: int = 0
var target_correct: int = 6
var dirty_chance: float = 0.5
var num_specks_min: int = 5
var num_specks_max: int = 12

var swipe_start: Vector2 = Vector2.ZERO
var is_swiping: bool = false

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			target_correct = 4
			dirty_chance = 0.6  # More dirty = easier to spot
			num_specks_min = 8
			num_specks_max = 15  # Very visible specks
			game_duration = 18.0
		"Medium":
			target_correct = 5
			dirty_chance = 0.5
			num_specks_min = 5
			num_specks_max = 12
			game_duration = 15.0
		"Hard":
			target_correct = 6
			dirty_chance = 0.4  # Less dirty = harder to spot
			num_specks_min = 2
			num_specks_max = 6  # Subtle specks
			game_duration = 12.0

func _ready():
	game_name = "Spot The Speck"
	game_instruction_text = "Check the water glasses!\n⬆️ SWIPE UP = Clean (drink!) | ⬇️ SWIPE DOWN = Dirty (reject!)"
	game_duration = 20.0
	game_mode = "quota"  # Must check target number of glasses!
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.9, 0.95, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Table
	var table = ColorRect.new()
	table.color = Color(0.55, 0.35, 0.2)
	table.position = Vector2(0, screen_size.y * 0.7)
	table.size = Vector2(screen_size.x, screen_size.y * 0.3)
	table.z_index = -5
	add_child(table)
	
	# Score label
	var local_score_label = Label.new()
	local_score_label.name = "ScoreLabel"
	local_score_label.text = "✓ Correct: 0 / %d" % target_correct
	local_score_label.add_theme_font_size_override("font_size", 28)
	local_score_label.add_theme_color_override("font_color", Color.WHITE)
	local_score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	local_score_label.add_theme_constant_override("outline_size", 4)
	local_score_label.position = Vector2(screen_size.x / 2 - 100, 120)
	add_child(local_score_label)
	
	# Hint arrows
	var up_hint = Label.new()
	up_hint.text = "⬆️ CLEAN"
	up_hint.add_theme_font_size_override("font_size", 24)
	up_hint.add_theme_color_override("font_color", Color.GREEN)
	up_hint.position = Vector2(screen_size.x / 2 - 50, screen_size.y * 0.25)
	add_child(up_hint)
	
	var down_hint = Label.new()
	down_hint.text = "⬇️ DIRTY"
	down_hint.add_theme_font_size_override("font_size", 24)
	down_hint.add_theme_color_override("font_color", Color.RED)
	down_hint.position = Vector2(screen_size.x / 2 - 50, screen_size.y * 0.75)
	add_child(down_hint)
	
	# Spawn first glass
	_spawn_glass()

func _spawn_glass():
	var screen_size = get_viewport_rect().size
	var has_specks = randf() > 0.5
	
	current_glass = Node2D.new()
	current_glass.position = Vector2(screen_size.x / 2, screen_size.y * 0.5)
	current_glass.set_meta("dirty", has_specks)
	add_child(current_glass)
	
	# Glass body (transparent)
	var glass_body = Polygon2D.new()
	glass_body.polygon = PackedVector2Array([
		Vector2(-60, -100), Vector2(60, -100),
		Vector2(50, 100), Vector2(-50, 100)
	])
	glass_body.color = Color(0.8, 0.9, 1.0, 0.3)
	current_glass.add_child(glass_body)
	
	# Glass rim
	var rim = Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-62, -105), Vector2(62, -105),
		Vector2(62, -95), Vector2(-62, -95)
	])
	rim.color = Color(0.7, 0.8, 0.9, 0.5)
	current_glass.add_child(rim)
	
	# Water inside
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-55, -80), Vector2(55, -80),
		Vector2(45, 95), Vector2(-45, 95)
	])
	
	if has_specks:
		water.color = Color(0.4, 0.55, 0.7, 0.8)  # Slightly murky
	else:
		water.color = Color(0.4, 0.7, 0.95, 0.8)  # Clear blue
	current_glass.add_child(water)
	
	# Add specks if dirty
	if has_specks:
		var num_specks = randi_range(5, 12)
		for i in range(num_specks):
			var speck = Polygon2D.new()
			var speck_points = PackedVector2Array()
			var speck_size = randf_range(3, 8)
			for j in range(5):
				var angle = j * TAU / 5
				speck_points.append(Vector2(cos(angle) * speck_size, sin(angle) * speck_size))
			speck.polygon = speck_points
			speck.color = Color(0.3, 0.2, 0.1, 0.7)  # Brown specks
			speck.position = Vector2(randf_range(-40, 40), randf_range(-60, 80))
			current_glass.add_child(speck)
	
	# Glass highlights
	var highlight = Polygon2D.new()
	highlight.polygon = PackedVector2Array([
		Vector2(-50, -90), Vector2(-40, -90),
		Vector2(-35, 50), Vector2(-45, 50)
	])
	highlight.color = Color(1, 1, 1, 0.3)
	current_glass.add_child(highlight)
	
	# Entrance animation
	current_glass.modulate.a = 0
	current_glass.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(current_glass, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(current_glass, "scale", Vector2(1.0, 1.0), 0.3)
	
	glasses.append(current_glass)

func _process(delta):
	super._process(delta)
	if not game_active or not current_glass: return
	
	_handle_input()

func _handle_input():
	var mouse_pos = get_viewport().get_mouse_position()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_swiping:
			is_swiping = true
			swipe_start = mouse_pos
	else:
		if is_swiping:
			is_swiping = false
			var swipe_end = mouse_pos
			var direction = swipe_end - swipe_start
			
			if direction.length() > 60 and abs(direction.y) > abs(direction.x):
				if direction.y < 0:  # Swipe UP = Accept (clean)
					_judge_glass(false)  # Player thinks it's clean
				else:  # Swipe DOWN = Reject (dirty)
					_judge_glass(true)  # Player thinks it's dirty

func _judge_glass(player_says_dirty: bool):
	if not current_glass: return
	
	var is_actually_dirty = current_glass.get_meta("dirty")
	var correct = (player_says_dirty == is_actually_dirty)
	
	glasses_checked += 1
	
	var screen_size = get_viewport_rect().size
	var tween = create_tween()
	
	if correct:
		correct_choices += 1
		record_action(true)
		get_node("ScoreLabel").text = "✓ Correct: %d / %d" % [correct_choices, target_correct]
		
		# Success animation
		var result = Label.new()
		result.text = "✓ CORRECT!"
		result.add_theme_font_size_override("font_size", 36)
		result.add_theme_color_override("font_color", Color.GREEN)
		result.add_theme_color_override("font_outline_color", Color.BLACK)
		result.add_theme_constant_override("outline_size", 4)
		result.position = current_glass.position + Vector2(-80, -150)
		add_child(result)
		
		var result_tween = create_tween()
		result_tween.tween_property(result, "modulate:a", 0.0, 0.5)
		result_tween.tween_callback(result.queue_free)
		
		# Slide glass away
		var target_y = -200 if not player_says_dirty else screen_size.y + 200
		tween.tween_property(current_glass, "position:y", target_y, 0.3)
		tween.tween_callback(current_glass.queue_free)
		
		if correct_choices >= target_correct:
			current_glass = null
			await get_tree().create_timer(0.4).timeout
			end_game(true)
			return
	else:
		record_action(false)
		
		# Wrong animation
		var result = Label.new()
		result.text = "✗ WRONG!"
		result.add_theme_font_size_override("font_size", 36)
		result.add_theme_color_override("font_color", Color.RED)
		result.add_theme_color_override("font_outline_color", Color.BLACK)
		result.add_theme_constant_override("outline_size", 4)
		result.position = current_glass.position + Vector2(-60, -150)
		add_child(result)
		
		var result_tween = create_tween()
		result_tween.tween_property(result, "modulate:a", 0.0, 0.5)
		result_tween.tween_callback(result.queue_free)
		
		# Shake and remove
		current_glass.modulate = Color(1, 0.5, 0.5)
		tween.tween_property(current_glass, "position:x", current_glass.position.x + 20, 0.05)
		tween.tween_property(current_glass, "position:x", current_glass.position.x - 20, 0.05)
		tween.tween_property(current_glass, "position:x", current_glass.position.x, 0.05)
		tween.tween_property(current_glass, "modulate:a", 0.0, 0.2)
		tween.tween_callback(current_glass.queue_free)
	
	current_glass = null
	glasses.clear()
	
	# Spawn next glass
	await get_tree().create_timer(0.4).timeout
	if game_active:
		_spawn_glass()
