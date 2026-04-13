extends MiniGameBase

var drums: Array = []
var mosquitoes: Array = []
var spawn_timer: float = 0.0
var mosquito_speed: float = 120.0
var mosquitoes_entered: int = 0
var max_allowed_in: int = 5  # Fail if this many get in
var spawn_interval_min: float = 0.8
var spawn_interval_max: float = 1.5

func _apply_difficulty_settings() -> void:
	# Apply difficulty-based scaling
	match current_difficulty:
		"Easy":
			mosquito_speed = 90.0
			max_allowed_in = 5
			spawn_interval_min = 1.0
			spawn_interval_max = 1.8
			game_duration = 10.0
		"Medium":
			mosquito_speed = 150.0
			max_allowed_in = 3
			spawn_interval_min = 0.5
			spawn_interval_max = 1.0
			game_duration = 12.0
		"Hard":
			mosquito_speed = 220.0
			max_allowed_in = 2
			spawn_interval_min = 0.3
			spawn_interval_max = 0.6
			game_duration = 15.0

func _ready():
	game_name = "Cover The Drum"
	game_instruction_text = "TAP drums to cover them!\nDon't let mosquitoes in! 🦟"
	game_duration = 25.0
	game_mode = "survival"  # Win if timer runs out with quota unfilled
	show_quota = false  # No blocked counter
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.25, 0.2, 0.35)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Stars
	for i in range(20):
		var star = Label.new()
		star.text = "✦"
		star.add_theme_font_size_override("font_size", randi_range(10, 20))
		star.modulate = Color(1, 1, 0.8, randf_range(0.3, 0.7))
		star.position = Vector2(randf() * screen_size.x, randf() * screen_size.y * 0.5)
		star.z_index = -9
		add_child(star)
	
	# Moon
	var moon = Label.new()
	moon.text = "🌙"
	moon.add_theme_font_size_override("font_size", 60)
	moon.position = Vector2(screen_size.x * 0.85, screen_size.y * 0.15)
	moon.z_index = -8
	add_child(moon)
	
	# Ground
	var ground = ColorRect.new()
	ground.color = Color(0.25, 0.2, 0.15)
	ground.position = Vector2(0, screen_size.y * 0.75)
	ground.size = Vector2(screen_size.x, screen_size.y * 0.25)
	ground.z_index = -5
	add_child(ground)
	
	# Drums
	var positions = [
		Vector2(screen_size.x * 0.2, screen_size.y * 0.6),
		Vector2(screen_size.x * 0.5, screen_size.y * 0.6),
		Vector2(screen_size.x * 0.8, screen_size.y * 0.6)
	]
	
	for pos in positions:
		_create_drum(pos)
	
	# Mosquitoes entered display
	var entered_label = Label.new()
	entered_label.name = "EnteredLabel"
	entered_label.text = "🦟 Inside: 0 / %d" % max_allowed_in
	entered_label.add_theme_font_size_override("font_size", 28)
	entered_label.add_theme_color_override("font_color", Color(1, 0.7, 0.7))
	entered_label.add_theme_color_override("font_outline_color", Color.BLACK)
	entered_label.add_theme_constant_override("outline_size", 4)
	entered_label.position = Vector2(screen_size.x / 2 - 100, 120)
	add_child(entered_label)

func _create_drum(pos: Vector2):
	var drum = Node2D.new()
	drum.position = pos
	drum.set_meta("covered", false)
	drum.set_meta("cover_timer", 0.0)
	add_child(drum)
	
	# Shadow
	var shadow = Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-70, 85), Vector2(70, 85),
		Vector2(60, 95), Vector2(-60, 95)
	])
	shadow.color = Color(0, 0, 0, 0.3)
	drum.add_child(shadow)
	
	# Body
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-60, -90), Vector2(60, -90),
		Vector2(65, -70), Vector2(65, 70),
		Vector2(60, 90), Vector2(-60, 90),
		Vector2(-65, 70), Vector2(-65, -70)
	])
	body.color = Color(0.2, 0.4, 0.65)
	drum.add_child(body)
	
	# Water
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-55, -85), Vector2(55, -85),
		Vector2(55, -65), Vector2(-55, -65)
	])
	water.color = Color(0.3, 0.6, 1.0, 0.8)
	water.name = "Water"
	drum.add_child(water)
	
	# Lid
	var lid = Node2D.new()
	lid.name = "LidContainer"
	lid.visible = false
	drum.add_child(lid)
	
	var lid_main = Polygon2D.new()
	var lid_points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16
		lid_points.append(Vector2(cos(angle) * 65, -90 + sin(angle) * 12))
	lid_main.polygon = lid_points
	lid_main.color = Color(0.55, 0.35, 0.2)
	lid.add_child(lid_main)
	
	# Status
	var status = Label.new()
	status.text = "⚠️ OPEN"
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	status.add_theme_constant_override("outline_size", 3)
	status.position = Vector2(-40, -130)
	status.name = "Status"
	drum.add_child(status)
	
	drums.append(drum)

func _cover_drum(drum: Node2D):
	if drum.get_meta("covered"): return
	
	drum.set_meta("covered", true)
	drum.set_meta("cover_timer", 4.0)
	
	var lid = drum.get_node("LidContainer")
	lid.visible = true
	drum.get_node("Water").visible = false
	drum.get_node("Status").text = "✓ SAFE"
	drum.get_node("Status").add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	
	var tween = create_tween()
	lid.scale = Vector2(0.5, 0.5)
	tween.tween_property(lid, "scale", Vector2(1.0, 1.0), 0.15)

func _uncover_drum(drum: Node2D):
	drum.set_meta("covered", false)
	
	var lid = drum.get_node("LidContainer")
	lid.visible = false
	drum.get_node("Water").visible = true
	drum.get_node("Status").text = "⚠️ OPEN"
	drum.get_node("Status").add_theme_color_override("font_color", Color(1, 0.4, 0.4))

func _input(event):
	if not game_active: return
	
	var tap_pos = Vector2.ZERO
	var is_tap = false
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
		is_tap = true
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
		is_tap = true
	
	if is_tap:
		for drum in drums:
			if tap_pos.distance_to(drum.position) < 100:
				_cover_drum(drum)
				break

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	# Update cover timers
	for drum in drums:
		if drum.get_meta("covered"):
			var timer_val = drum.get_meta("cover_timer") - delta
			drum.set_meta("cover_timer", timer_val)
			if timer_val <= 0:
				_uncover_drum(drum)
	
	# Spawn mosquitoes
	spawn_timer -= delta
	if spawn_timer <= 0:
		_spawn_mosquito()
		spawn_timer = randf_range(spawn_interval_min, spawn_interval_max)
	
	# Move mosquitoes
	var to_remove = []
	for mosq in mosquitoes:
		if not is_instance_valid(mosq):
			to_remove.append(mosq)
			continue
			
		var target = mosq.get_meta("target")
		if not is_instance_valid(target):
			to_remove.append(mosq)
			mosq.queue_free()
			continue
		
		var dir = (target.position - mosq.position).normalized()
		var wiggle = Vector2(sin(Time.get_ticks_msec() * 0.01 + mosq.get_instance_id()) * 30, 0)
		mosq.position += (dir * mosquito_speed + wiggle * 0.5) * delta
		mosq.rotation = sin(Time.get_ticks_msec() * 0.03) * 0.2
		
		# Reached drum
		if mosq.position.distance_to(target.position) < 40:
			if target.get_meta("covered"):
				# BLOCKED!
				record_action(true)
				
				var bounce_dir = -dir * 150
				var blocked_label = Label.new()
				blocked_label.text = "✗"
				blocked_label.add_theme_font_size_override("font_size", 40)
				blocked_label.add_theme_color_override("font_color", Color.GREEN)
				blocked_label.position = mosq.position + Vector2(-15, -30)
				add_child(blocked_label)
				
				var label_tween = create_tween()
				label_tween.tween_property(blocked_label, "modulate:a", 0.0, 0.5)
				label_tween.tween_callback(blocked_label.queue_free)
				
				var tween = create_tween()
				tween.tween_property(mosq, "position", mosq.position + bounce_dir, 0.3)
				tween.parallel().tween_property(mosq, "modulate:a", 0.0, 0.3)
				tween.tween_callback(mosq.queue_free)
			else:
				# GOT IN - Show red flash instead of timer penalty
				mosquitoes_entered += 1
				get_node("EnteredLabel").text = "🦟 Inside: %d / %d" % [mosquitoes_entered, max_allowed_in]
				
				# RED FLASH EFFECT
				_show_hit_effect()
				
				var tween = create_tween()
				tween.tween_property(mosq, "position", target.position + Vector2(0, -60), 0.2)
				tween.tween_property(mosq, "scale", Vector2(0.3, 0.3), 0.15)
				tween.tween_callback(mosq.queue_free)
				
				# Fail if too many got in
				if mosquitoes_entered >= max_allowed_in:
					end_game(false)
			
			to_remove.append(mosq)
	
	for m in to_remove:
		mosquitoes.erase(m)

func _show_hit_effect():
	# Red screen flash
	var flash = ColorRect.new()
	flash.color = Color(1, 0, 0, 0.4)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.z_index = 50
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)

func _spawn_mosquito():
	var target = drums.pick_random()
	
	var mosq = Node2D.new()
	var spawn_side = randi() % 4
	var screen = get_viewport_rect().size
	match spawn_side:
		0: mosq.position = Vector2(randf() * screen.x, -50)
		1: mosq.position = Vector2(randf() * screen.x, screen.y * 0.4)
		2: mosq.position = Vector2(-50, randf() * screen.y * 0.4)
		3: mosq.position = Vector2(screen.x + 50, randf() * screen.y * 0.4)
	
	mosq.set_meta("target", target)
	add_child(mosq)
	
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-10, -8), Vector2(10, -8),
		Vector2(8, 8), Vector2(-8, 8)
	])
	body.color = Color(0.15, 0.15, 0.15)
	mosq.add_child(body)
	
	var head = Polygon2D.new()
	var head_points = PackedVector2Array()
	for i in range(6):
		var angle = i * TAU / 6
		head_points.append(Vector2(cos(angle) * 6, -12 + sin(angle) * 4))
	head.polygon = head_points
	head.color = Color(0.2, 0.2, 0.2)
	mosq.add_child(head)
	
	var wing1 = Polygon2D.new()
	wing1.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(-20, -8), Vector2(-18, 8), Vector2(-5, 5)
	])
	wing1.color = Color(0.6, 0.6, 0.7, 0.5)
	mosq.add_child(wing1)
	
	var wing2 = Polygon2D.new()
	wing2.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(20, -8), Vector2(18, 8), Vector2(5, 5)
	])
	wing2.color = Color(0.6, 0.6, 0.7, 0.5)
	mosq.add_child(wing2)
	
	mosquitoes.append(mosq)
