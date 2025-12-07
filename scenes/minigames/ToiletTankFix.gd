extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## TOILET TANK FIX - Hold to stop flow, tap to adjust float
## ═══════════════════════════════════════════════════════════════════

var water_level: float = 0.0
var target_level: float = 70.0
var tolerance: float = 10.0
var fill_rate: float = 30.0
var is_holding: bool = false
var tanks_fixed: int = 0
var target_tanks: int = 4

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			target_tanks = 3
			tolerance = 15.0
			fill_rate = 20.0
			game_duration = 30.0
		"Medium":
			target_tanks = 4
			tolerance = 10.0
			fill_rate = 30.0
			game_duration = 25.0
		"Hard":
			target_tanks = 5
			tolerance = 5.0
			fill_rate = 45.0
			game_duration = 20.0

func _ready():
	game_name = "Toilet Tank Fix"
	game_instruction_text = Localization.get_text("toilet_tank_instructions") if Localization else "HOLD to fill tank!\nRelease when water reaches the LINE! 🚽"
	game_duration = 25.0
	game_mode = "quota"
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background - Bathroom
	var bg = ColorRect.new()
	bg.color = Color(0.9, 0.9, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Toilet tank
	var tank = Node2D.new()
	tank.name = "Tank"
	tank.position = Vector2(screen_size.x / 2, screen_size.y * 0.5)
	add_child(tank)
	
	# Tank body
	var tank_body = Polygon2D.new()
	tank_body.polygon = PackedVector2Array([
		Vector2(-100, -120), Vector2(100, -120),
		Vector2(100, 120), Vector2(-100, 120)
	])
	tank_body.color = Color(0.95, 0.95, 0.95)
	tank.add_child(tank_body)
	
	# Tank outline
	var outline = Line2D.new()
	outline.points = PackedVector2Array([
		Vector2(-100, -120), Vector2(100, -120),
		Vector2(100, 120), Vector2(-100, 120), Vector2(-100, -120)
	])
	outline.width = 4
	outline.default_color = Color(0.7, 0.7, 0.7)
	tank.add_child(outline)
	
	# Water fill
	var water = Polygon2D.new()
	water.name = "Water"
	water.polygon = PackedVector2Array([
		Vector2(-95, 115), Vector2(95, 115),
		Vector2(95, 115), Vector2(-95, 115)
	])
	water.color = Color(0.3, 0.6, 0.9, 0.7)
	tank.add_child(water)
	
	# Target line
	var target_line = Line2D.new()
	target_line.name = "TargetLine"
	target_line.points = PackedVector2Array([Vector2(-100, 0), Vector2(100, 0)])
	target_line.width = 4
	target_line.default_color = Color(0.2, 0.8, 0.2)
	tank.add_child(target_line)
	
	# Target zone indicator
	var zone_label = Label.new()
	zone_label.text = "← TARGET"
	zone_label.add_theme_font_size_override("font_size", 18)
	zone_label.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
	zone_label.position = Vector2(105, -15)
	tank.add_child(zone_label)
	
	# Float mechanism
	var float_ball = Label.new()
	float_ball.name = "Float"
	float_ball.text = "⚪"
	float_ball.add_theme_font_size_override("font_size", 40)
	float_ball.position = Vector2(50, 100)
	tank.add_child(float_ball)
	
	# Instructions
	var hold_label = Label.new()
	hold_label.name = "HoldLabel"
	hold_label.text = "👆 HOLD TO FILL"
	hold_label.add_theme_font_size_override("font_size", 28)
	hold_label.add_theme_color_override("font_color", Color.WHITE)
	hold_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hold_label.add_theme_constant_override("outline_size", 4)
	hold_label.position = Vector2(screen_size.x / 2 - 100, screen_size.y * 0.85)
	add_child(hold_label)
	
	# Score display
	var score_display = Label.new()
	score_display.name = "ScoreDisplay"
	score_display.text = "🚽 0 / %d" % target_tanks
	score_display.add_theme_font_size_override("font_size", 28)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(screen_size.x / 2 - 60, 120)
	add_child(score_display)
	
	_setup_tank()

func _setup_tank():
	water_level = 0.0
	target_level = randf_range(50.0, 80.0)
	
	# Update target line position
	var tank = get_node("Tank")
	var target_line = tank.get_node("TargetLine")
	var y_pos = 115 - (target_level / 100.0 * 230)
	target_line.points = PackedVector2Array([Vector2(-100, y_pos), Vector2(100, y_pos)])

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	var was_holding = is_holding
	is_holding = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	var tank = get_node("Tank")
	var water = tank.get_node("Water")
	var float_ball = tank.get_node("Float")
	
	if is_holding:
		# Fill tank
		water_level = min(100.0, water_level + fill_rate * delta)
		get_node("HoldLabel").text = "💧 FILLING..."
		get_node("HoldLabel").modulate = Color(0.5, 0.8, 1.0)
	else:
		get_node("HoldLabel").text = "👆 HOLD TO FILL"
		get_node("HoldLabel").modulate = Color.WHITE
	
	# Update water visual
	var water_height = (water_level / 100.0) * 230
	var y_top = 115 - water_height
	water.polygon = PackedVector2Array([
		Vector2(-95, 115), Vector2(95, 115),
		Vector2(95, y_top), Vector2(-95, y_top)
	])
	
	# Update float position
	float_ball.position.y = y_top - 20
	
	# Check if released after holding
	if was_holding and not is_holding and water_level > 0:
		_check_level()

func _check_level():
	var diff = abs(water_level - target_level)
	
	if diff <= tolerance:
		# Success!
		tanks_fixed += 1
		record_action(true)
		get_node("ScoreDisplay").text = "🚽 %d / %d" % [tanks_fixed, target_tanks]
		
		# Success animation
		var flash = ColorRect.new()
		flash.color = Color(0, 1, 0, 0.3)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var tw = create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.3)
		tw.tween_callback(flash.queue_free)
		
		if tanks_fixed >= target_tanks:
			end_game(true)
		else:
			await get_tree().create_timer(0.8).timeout
			if game_active:
				_setup_tank()
	else:
		# Failed - overflow or underfill
		record_action(false)
		
		var flash = ColorRect.new()
		flash.color = Color(1, 0, 0, 0.3)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var tw = create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.3)
		tw.tween_callback(flash.queue_free)
		
		# Show feedback
		var feedback = Label.new()
		if water_level > target_level:
			feedback.text = "TOO MUCH! 💦"
		else:
			feedback.text = "NOT ENOUGH! ⬆️"
		feedback.add_theme_font_size_override("font_size", 36)
		feedback.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		feedback.position = get_node("Tank").position + Vector2(-80, -150)
		add_child(feedback)
		
		var tw2 = create_tween()
		tw2.tween_property(feedback, "modulate:a", 0.0, 0.5)
		tw2.tween_callback(feedback.queue_free)
		
		await get_tree().create_timer(0.5).timeout
		if game_active:
			_setup_tank()
