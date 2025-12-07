extends Node2D

## ═══════════════════════════════════════════════════════════════════
## JUICE EFFECTS MANAGER
## Handles all game feel enhancements and chaos effects
## ═══════════════════════════════════════════════════════════════════

class_name JuiceEffects

## Helper to get AccessibilityManager from static context
static func _get_accessibility_manager() -> Node:
	var tree = Engine.get_main_loop()
	if tree and tree is SceneTree:
		return tree.root.get_node_or_null("AccessibilityManager")
	return null

## Screen shake effect
static func screen_shake(camera: Camera2D, intensity: float, duration: float = 0.5) -> void:
	if not camera:
		return
	
	var original_offset = camera.offset
	var shake_tween = camera.create_tween()
	
	var num_shakes = int(duration / 0.05)
	for i in range(num_shakes):
		shake_tween.tween_property(camera, "offset", original_offset + Vector2(
			randf_range(-intensity * 10, intensity * 10),
			randf_range(-intensity * 10, intensity * 10)
		), 0.05)
	
	shake_tween.tween_property(camera, "offset", original_offset, 0.05)

## Flash screen with color
static func flash_screen(node: Node, color: Color, duration: float = 0.3) -> void:
	var viewport = node.get_viewport()
	if not viewport:
		return
	
	var flash = ColorRect.new()
	flash.color = color
	flash.size = viewport.get_visible_rect().size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 100
	node.add_child(flash)
	
	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.finished.connect(flash.queue_free)

## Bounce scale effect
static func bounce_scale(node: Node2D, scale_amount: float = 1.2, duration: float = 0.3) -> void:
	var original_scale = node.scale
	
	var tween = node.create_tween()
	tween.tween_property(node, "scale", original_scale * scale_amount, duration * 0.5)
	tween.tween_property(node, "scale", original_scale, duration * 0.5).set_trans(Tween.TRANS_BACK)

## Rotate wobble effect
static func wobble(node: Node2D, angle: float = 15.0, duration: float = 0.5) -> void:
	var original_rotation = node.rotation_degrees
	
	var tween = node.create_tween()
	tween.tween_property(node, "rotation_degrees", original_rotation + angle, duration * 0.25)
	tween.tween_property(node, "rotation_degrees", original_rotation - angle, duration * 0.25)
	tween.tween_property(node, "rotation_degrees", original_rotation, duration * 0.5).set_trans(Tween.TRANS_ELASTIC)

## Spawn particle burst
static func particle_burst(node: Node, pos: Vector2, color: Color, count: int = 20) -> void:
	for i in range(count):
		var particle = ColorRect.new()
		particle.color = color
		particle.size = Vector2(randf_range(3, 8), randf_range(3, 8))
		particle.position = pos
		node.add_child(particle)
		
		# Animate outward
		var angle = randf() * TAU
		var distance = randf_range(30, 100)
		var target_pos = pos + Vector2(cos(angle), sin(angle)) * distance
		
		var tween = particle.create_tween().set_parallel(true)
		tween.tween_property(particle, "position", target_pos, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.finished.connect(particle.queue_free)

## Slide in from side
static func slide_in(node: Control, from_direction: String = "left", duration: float = 0.5) -> void:
	var viewport_size = node.get_viewport_rect().size
	var original_pos = node.position
	
	match from_direction:
		"left":
			node.position.x = -node.size.x
		"right":
			node.position.x = viewport_size.x
		"top":
			node.position.y = -node.size.y
		"bottom":
			node.position.y = viewport_size.y
	
	var tween = node.create_tween()
	tween.tween_property(node, "position", original_pos, duration).set_trans(Tween.TRANS_BACK)

## Fade in
static func fade_in(node: CanvasItem, duration: float = 0.5) -> void:
	node.modulate.a = 0.0
	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)

## Fade out
static func fade_out(node: CanvasItem, duration: float = 0.5) -> void:
	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.finished.connect(node.queue_free)

## Pulse effect (continuous)
static func pulse(node: Node2D, scale_amount: float = 1.1, duration: float = 1.0) -> void:
	var original_scale = node.scale
	
	var tween = node.create_tween().set_loops()
	tween.tween_property(node, "scale", original_scale * scale_amount, duration * 0.5)
	tween.tween_property(node, "scale", original_scale, duration * 0.5)

## Text pop-up animation
static func text_popup(text: String, pos: Vector2, parent: Node, color: Color = Color.WHITE, font_size: int = 32) -> void:
	var label = Label.new()
	label.text = text
	label.position = pos
	label.modulate = color
	label.add_theme_font_size_override("font_size", font_size)
	label.z_index = 100
	parent.add_child(label)
	
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 50, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.finished.connect(label.queue_free)

## Success celebration
static func celebrate_success(node: Node, camera: Camera2D = null) -> void:
	# Flash screen green
	flash_screen(node, Color(0.3, 1.0, 0.3, 0.4), 0.4)
	
	# Particle burst
	var center = node.get_viewport_rect().size / 2
	particle_burst(node, center, Color(1, 0.9, 0.3), 30)
	
	# Screen shake
	if camera:
		screen_shake(camera, 0.3, 0.3)

## Failure effect
static func show_failure(node: Node, camera: Camera2D = null) -> void:
	# Check accessibility settings
	var acc_mgr = _get_accessibility_manager()
	if acc_mgr and acc_mgr.has_method("is_screen_shake_enabled") and not acc_mgr.is_screen_shake_enabled():
		flash_screen(node, Color(1.0, 0.3, 0.3, 0.5), 0.5)
		return
	
	# Flash screen red
	flash_screen(node, Color(1.0, 0.3, 0.3, 0.5), 0.5)
	
	# Screen shake
	if camera:
		screen_shake(camera, 0.8, 0.5)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WATER-SPECIFIC EFFECTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Water splash effect
static func water_splash(node: Node, pos: Vector2, size: float = 1.0) -> void:
	var acc_mgr = _get_accessibility_manager()
	if acc_mgr and acc_mgr.has_method("should_show_particles") and not acc_mgr.should_show_particles():
		return
	
	var splash_color = Color(0.3, 0.7, 1.0, 0.8)
	var particle_count = int(15 * size)
	
	for i in range(particle_count):
		var drop = Polygon2D.new()
		# Droplet shape
		drop.polygon = PackedVector2Array([
			Vector2(0, -8),
			Vector2(-4, 0),
			Vector2(-3, 5),
			Vector2(0, 7),
			Vector2(3, 5),
			Vector2(4, 0)
		])
		drop.color = splash_color
		drop.scale = Vector2(0.5, 0.5) * randf_range(0.5, 1.5)
		drop.position = pos
		node.add_child(drop)
		
		# Animate outward and up (splash)
		var angle = -PI/2 + randf_range(-PI/3, PI/3)  # Upward arc
		var distance = randf_range(30, 80) * size
		var target_pos = pos + Vector2(cos(angle), sin(angle)) * distance
		
		# Gravity effect
		var tween = drop.create_tween()
		tween.set_parallel(true)
		tween.tween_property(drop, "position", target_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(drop, "rotation", randf_range(-PI, PI), 0.5)
		tween.set_parallel(false)
		tween.tween_property(drop, "position:y", target_pos.y + 50, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(drop, "modulate:a", 0.0, 0.2)
		tween.tween_callback(drop.queue_free)

## Water ripple effect
static func water_ripple(node: Node, pos: Vector2, color: Color = Color(0.3, 0.7, 1.0, 0.6)) -> void:
	var acc_mgr = _get_accessibility_manager()
	if acc_mgr and acc_mgr.has_method("should_show_particles") and not acc_mgr.should_show_particles():
		return
	
	for i in range(3):
		var ripple = _create_circle(30, color)
		ripple.position = pos
		ripple.scale = Vector2.ZERO
		node.add_child(ripple)
		
		var delay = i * 0.15
		var tween = ripple.create_tween()
		tween.tween_interval(delay)
		tween.set_parallel(true)
		tween.tween_property(ripple, "scale", Vector2(3, 3), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ripple, "modulate:a", 0.0, 0.6)
		tween.set_parallel(false)
		tween.tween_callback(ripple.queue_free)

static func _create_circle(radius: float, color: Color) -> Polygon2D:
	var circle = Polygon2D.new()
	var points: PackedVector2Array = []
	for i in range(24):
		var angle = i * TAU / 24
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	circle.polygon = points
	circle.color = color
	return circle

## Water drip effect (continuous dripping)
static func create_drip_emitter(parent: Node, pos: Vector2, rate: float = 1.0) -> Node2D:
	var emitter = Node2D.new()
	emitter.position = pos
	parent.add_child(emitter)
	
	var timer = Timer.new()
	timer.wait_time = 1.0 / rate
	timer.autostart = true
	emitter.add_child(timer)
	
	timer.timeout.connect(func():
		_spawn_drip(parent, pos)
	)
	
	return emitter

static func _spawn_drip(parent: Node, pos: Vector2) -> void:
	var drip = Polygon2D.new()
	drip.polygon = PackedVector2Array([
		Vector2(0, -6), Vector2(-3, 0), Vector2(-2, 4),
		Vector2(0, 6), Vector2(2, 4), Vector2(3, 0)
	])
	drip.color = Color(0.3, 0.7, 1.0, 0.9)
	drip.position = pos
	parent.add_child(drip)
	
	var tween = drip.create_tween()
	tween.tween_property(drip, "position:y", pos.y + 200, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		water_splash(parent, drip.position, 0.5)
		drip.queue_free()
	)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SCORE EFFECTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Score increment animation
static func score_increment(node: Node, pos: Vector2, amount: int, is_positive: bool = true) -> void:
	var color = Color(0.3, 1.0, 0.5) if is_positive else Color(1.0, 0.3, 0.3)
	var prefix = "+" if is_positive else ""
	text_popup(prefix + str(amount), pos, node, color, 28)
	
	# Play audio cue
	var acc_mgr = _get_accessibility_manager()
	if acc_mgr:
		if is_positive:
			acc_mgr.play_success_cue()
		else:
			acc_mgr.play_failure_cue()

## Combo counter effect
static func combo_effect(node: Node, pos: Vector2, combo_count: int) -> void:
	var size = mini(24 + combo_count * 4, 48)
	var color = Color.from_hsv(float(combo_count % 10) / 10.0, 0.8, 1.0)
	
	var label = Label.new()
	label.text = "COMBO x" + str(combo_count) + "!"
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.z_index = 100
	node.add_child(label)
	
	# Punch scale animation
	var tween = label.create_tween()
	label.scale = Vector2(1.5, 1.5)
	tween.tween_property(label, "scale", Vector2(1, 1), 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TIMER EFFECTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Timer urgency effect (last 10 seconds)
static func timer_urgency(label: Label, time_remaining: float) -> void:
	if time_remaining <= 10 and time_remaining > 0:
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		
		# Pulse on each second
		if abs(time_remaining - round(time_remaining)) < 0.1:
			var tween = label.create_tween()
			tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
			tween.tween_property(label, "scale", Vector2(1, 1), 0.1)
			
			# Audio countdown
			var acc_mgr = _get_accessibility_manager()
			if acc_mgr:
				acc_mgr.play_audio_cue("countdown")
	else:
		label.add_theme_color_override("font_color", Color.WHITE)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUTTON EFFECTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Button hover effect
static func button_hover_enter(btn: Button) -> void:
	var tween = btn.create_tween()
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD)

static func button_hover_exit(btn: Button) -> void:
	var tween = btn.create_tween()
	tween.tween_property(btn, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_QUAD)

## Button press effect
static func button_press(btn: Button) -> void:
	var tween = btn.create_tween()
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "scale", Vector2(1, 1), 0.1)
	
	var acc_mgr = _get_accessibility_manager()
	if acc_mgr:
		acc_mgr.play_click_cue()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME STATE EFFECTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Level complete celebration
static func level_complete(node: Node, camera: Camera2D = null) -> void:
	# Multiple bursts
	var viewport_size = node.get_viewport_rect().size
	for i in range(5):
		var pos = Vector2(
			randf_range(100, viewport_size.x - 100),
			randf_range(100, viewport_size.y - 100)
		)
		var delay = i * 0.2
		node.get_tree().create_timer(delay).timeout.connect(func():
			particle_burst(node, pos, Color.from_hsv(randf(), 0.8, 1.0), 25)
		)
	
	# Flash and shake
	flash_screen(node, Color(1, 1, 0.8, 0.4), 0.5)
	var acc_mgr = _get_accessibility_manager()
	if camera and (not acc_mgr or not acc_mgr.has_method("is_screen_shake_enabled") or acc_mgr.is_screen_shake_enabled()):
		screen_shake(camera, 0.5, 0.4)
	
	# Audio
	if acc_mgr:
		acc_mgr.play_bonus_cue()

## Game over effect
static func game_over(node: Node, is_victory: bool) -> void:
	if is_victory:
		level_complete(node)
	else:
		# Desaturate effect
		var overlay = ColorRect.new()
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.color = Color(0.2, 0.2, 0.2, 0.0)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = 50
		node.add_child(overlay)
		
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "color:a", 0.5, 1.0)
		
		var acc_mgr = _get_accessibility_manager()
		if acc_mgr:
			acc_mgr.play_failure_cue()
