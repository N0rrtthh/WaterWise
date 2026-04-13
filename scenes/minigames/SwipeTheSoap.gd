extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## SWIPE THE SOAP - Swipe in correct direction to save water
## ═══════════════════════════════════════════════════════════════════

var current_soap: Node2D = null
var soaps_cleaned: int = 0
var target_soaps: int = 8
var swipe_start: Vector2 = Vector2.ZERO
var is_swiping: bool = false
var spawn_delay: float = 0.8

func _ready():
	# Set game properties BEFORE calling super._ready()
	game_name = "Swipe The Soap"
	game_instruction_text = Localization.get_text("swipe_soap_instructions") if Localization else "SWIPE in the direction shown!\nQuick rinse saves water! 🧼"
	game_duration = 15.0  # Shorter default timer for challenge
	game_mode = "quota"
	
	# Call super._ready() which will load difficulty and call _apply_difficulty_settings()
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background - Bathroom
	var bg = ColorRect.new()
	bg.color = Color(0.9, 0.95, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Sink
	var sink = Polygon2D.new()
	sink.polygon = PackedVector2Array([
		Vector2(-150, 0), Vector2(150, 0),
		Vector2(130, 100), Vector2(-130, 100)
	])
	sink.color = Color(0.9, 0.9, 0.95)
	sink.position = Vector2(screen_size.x / 2, screen_size.y * 0.65)
	add_child(sink)
	
	# Faucet
	var faucet = Label.new()
	faucet.text = "🚿"
	faucet.add_theme_font_size_override("font_size", 60)
	faucet.position = Vector2(screen_size.x / 2 - 30, screen_size.y * 0.35)
	add_child(faucet)
	
	# Score display
	var score_display = Label.new()
	score_display.name = "ScoreDisplay"
	score_display.text = "🧼 0 / %d" % target_soaps
	score_display.add_theme_font_size_override("font_size", 32)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(screen_size.x / 2 - 60, 120)
	add_child(score_display)

func _apply_difficulty_settings() -> void:
	# Apply difficulty settings from AdaptiveDifficulty
	# This makes difficulty progression VERY noticeable
	super._apply_difficulty_settings()
	
	# Get progressive difficulty settings
	var settings = AdaptiveDifficulty.get_difficulty_settings() if AdaptiveDifficulty else {}
	var progressive_level = settings.get("progressive_level", 0)
	
	match current_difficulty:
		"Easy":  # Beginner - More time, fewer soaps, slower pace
			target_soaps = 5  # 18s / 5 = 3.6s per soap
			spawn_delay = 1.0
			game_duration = 18.0
		"Medium":  # Standard - Moderate challenge
			target_soaps = 6  # 12s / 6 = 2.0s per soap
			spawn_delay = 0.7
			game_duration = 12.0
		"Hard":  # Expert - Fast and furious!
			target_soaps = 7  # 10s / 7 = 1.43s per soap
			spawn_delay = 0.4
			game_duration = 10.0
	
	# Apply PROGRESSIVE DIFFICULTY (NO CEILING!)
	if progressive_level > 0:
		# Increase quotas progressively
		target_soaps += progressive_level  # +1 soap per progressive level
		
		# Speed up spawn rate (gets faster and faster!)
		spawn_delay = max(0.2, spawn_delay * (1.0 - progressive_level * 0.1))  # Min 0.2s
		
		# Use the time limit from settings (already adjusted)
		game_duration = settings.get("time_limit", game_duration)
		
		print("🔥 Progressive Lvl %d: %d soaps, %.2fs delay, %.1fs time" % [progressive_level, target_soaps, spawn_delay, game_duration])

func _on_game_start():
	# Called by MiniGameBase after game_active = true
	_spawn_soap()

func _spawn_soap():
	if not game_active: return
	
	var screen_size = get_viewport_rect().size
	
	current_soap = Node2D.new()
	current_soap.position = Vector2(screen_size.x / 2, screen_size.y * 0.5)
	add_child(current_soap)
	
	# Soap bar
	var soap = Polygon2D.new()
	soap.polygon = PackedVector2Array([
		Vector2(-50, -30), Vector2(50, -30),
		Vector2(45, 30), Vector2(-45, 30)
	])
	soap.color = Color(0.4, 0.8, 0.5)
	current_soap.add_child(soap)
	
	# Random direction
	var directions = ["UP", "DOWN", "LEFT", "RIGHT"]
	var dir = directions[randi() % directions.size()]
	current_soap.set_meta("direction", dir)
	
	# Direction arrow
	var arrow = Label.new()
	arrow.name = "Arrow"
	arrow.add_theme_font_size_override("font_size", 50)
	arrow.position = Vector2(-25, -30)
	
	match dir:
		"UP":
			arrow.text = "⬆️"
		"DOWN":
			arrow.text = "⬇️"
		"LEFT":
			arrow.text = "⬅️"
		"RIGHT":
			arrow.text = "➡️"
	
	current_soap.add_child(arrow)
	
	# Bubbles
	for i in range(5):
		var bubble = Label.new()
		bubble.text = "○"
		bubble.add_theme_font_size_override("font_size", randi_range(12, 24))
		bubble.modulate = Color(1, 1, 1, 0.7)
		bubble.position = Vector2(randf_range(-60, 60), randf_range(-40, 40))
		current_soap.add_child(bubble)
	
	# Pop-in animation
	current_soap.scale = Vector2.ZERO
	var tw = create_tween()
	tw.set_loops(1)  # Fix infinite loop error
	tw.tween_property(current_soap, "scale", Vector2(1, 1), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	_handle_swipe()

func _handle_swipe():
	if current_soap == null: return
	
	var mouse_pos = get_viewport().get_mouse_position()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_swiping:
			is_swiping = true
			swipe_start = mouse_pos
	else:
		if is_swiping:
			is_swiping = false
			var swipe_end = mouse_pos
			var swipe_delta = swipe_end - swipe_start
			
			if swipe_delta.length() > 50:
				var swiped_dir = ""
				
				if abs(swipe_delta.x) > abs(swipe_delta.y):
					swiped_dir = "RIGHT" if swipe_delta.x > 0 else "LEFT"
				else:
					swiped_dir = "DOWN" if swipe_delta.y > 0 else "UP"
				
				var required_dir = current_soap.get_meta("direction")
				
				if swiped_dir == required_dir:
					_correct_swipe()
				else:
					_wrong_swipe()

func _correct_swipe():
	soaps_cleaned += 1
	record_action(true)
	get_node("ScoreDisplay").text = "🧼 %d / %d" % [soaps_cleaned, target_soaps]
	
	# Animate soap flying off
	var dir = current_soap.get_meta("direction")
	var target_pos = current_soap.position
	match dir:
		"UP": target_pos.y -= 500
		"DOWN": target_pos.y += 500
		"LEFT": target_pos.x -= 500
		"RIGHT": target_pos.x += 500
	
	var tw = create_tween()
	tw.set_loops(1)  # Fix infinite loop error
	tw.tween_property(current_soap, "position", target_pos, 0.3)
	tw.parallel().tween_property(current_soap, "modulate:a", 0.0, 0.3)
	tw.tween_callback(current_soap.queue_free)
	
	current_soap = null
	
	if soaps_cleaned >= target_soaps:
		end_game(true)
	else:
		await get_tree().create_timer(spawn_delay).timeout
		if game_active:
			_spawn_soap()

func _wrong_swipe():
	record_action(false)
	
	# Shake soap
	var original_pos = current_soap.position
	var tw = create_tween()
	tw.set_loops(1)  # Fix infinite loop error
	tw.tween_property(current_soap, "position:x", original_pos.x + 20, 0.05)
	tw.tween_property(current_soap, "position:x", original_pos.x - 20, 0.05)
	tw.tween_property(current_soap, "position:x", original_pos.x, 0.05)
	
	# Flash red
	current_soap.modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.2).timeout
	if current_soap:
		current_soap.modulate = Color.WHITE
