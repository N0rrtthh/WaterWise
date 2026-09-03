extends Node2D

## ═══════════════════════════════════════════════════════════════════
## JUICE EFFECTS MANAGER
## Handles all game feel enhancements and chaos effects
##
## Every function below has at least one caller in the shipped game. Twenty did not:
## flash_screen, wobble, slide_in, fade_out, text_popup, celebrate_success, show_failure,
## water_splash, water_ripple, create_drip_emitter, score_increment, combo_effect,
## timer_urgency, button_hover_enter, button_hover_exit, button_press, level_complete,
## game_over, and the two private helpers only they used. They are gone rather than left
## as a menu of options: an effect nobody calls is an effect nobody maintains, and three
## of these still tweened a raw duration instead of routing it through _motion_time(), so
## reduced motion would have failed to shorten them the day somebody finally called one.
## ═══════════════════════════════════════════════════════════════════

class_name JuiceEffects

## Helper to get AccessibilityManager from static context
static func _get_accessibility_manager() -> Node:
	var tree = Engine.get_main_loop()
	if tree and tree is SceneTree:
		return tree.root.get_node_or_null("AccessibilityManager")
	return null

static func _get_save_manager() -> Node:
	var tree = Engine.get_main_loop()
	if tree and tree is SceneTree:
		return tree.root.get_node_or_null("SaveManager")
	return null

## Public form of the shake gate, for shakes this class does not itself drive.
## screen_shake() below only knows how to nudge a Camera2D; the multiplayer scenes
## shake their own root Node2D, and they must honour the same setting.
static func is_screen_shake_allowed() -> bool:
	return _is_screen_shake_allowed()

static func _is_screen_shake_allowed() -> bool:
	var acc_mgr = _get_accessibility_manager()
	if acc_mgr and acc_mgr.has_method("is_screen_shake_enabled"):
		return acc_mgr.is_screen_shake_enabled()

	var save_mgr = _get_save_manager()
	if save_mgr and save_mgr.has_method("is_screen_shake_enabled"):
		return save_mgr.is_screen_shake_enabled()

	return true

static func _should_show_particles() -> bool:
	var acc_mgr = _get_accessibility_manager()
	if acc_mgr and acc_mgr.has_method("should_show_particles"):
		return acc_mgr.should_show_particles()

	var save_mgr = _get_save_manager()
	if save_mgr and save_mgr.has_method("is_particles_enabled"):
		return save_mgr.is_particles_enabled()

	return true


## Motion-preference time scaling.
##
## AccessibilityManager.get_animation_speed() returns 3.0 while "reduced motion" is
## on and 1.0 otherwise, but it had ZERO call sites: the setting suppressed particles
## and screen shake and never shortened a single animation, so a player who turned it
## on still sat through every full-length transition. Dividing the requested duration
## by that multiplier is the intended reading — under reduced motion an animation gets
## out of the way quickly rather than playing slowly.
##
## Continuous effects are handled separately (see pulse): making a never-ending
## animation three times faster is the opposite of reducing motion.
static func _animation_speed() -> float:
	var acc_mgr = _get_accessibility_manager()
	if acc_mgr and acc_mgr.has_method("get_animation_speed"):
		var speed := float(acc_mgr.get_animation_speed())
		if speed > 0.0:
			return speed
	return 1.0

## Shrink a duration by the motion-preference multiplier. Clamped to one frame at
## 60 fps so a scaled duration is still a real tween rather than an instant jump —
## reduced motion should shorten an animation, not delete the feedback it carries.
static func _motion_time(seconds: float) -> float:
	if seconds <= 0.0:
		return seconds
	return max(seconds / _animation_speed(), 0.016)

## Public form of _motion_time() for tweens hand-written outside this file.
##
## The minigames that animate their own nodes -- WaterMemory's card flip, for one --
## need the same motion-preference scaling as the effects in here, and duplicating the
## AccessibilityManager lookup in each of them is how the two drift apart.
static func motion_time(seconds: float) -> float:
	return _motion_time(seconds)

static func _should_reduce_motion() -> bool:
	var acc_mgr = _get_accessibility_manager()
	if acc_mgr and acc_mgr.has_method("should_reduce_motion"):
		return bool(acc_mgr.should_reduce_motion())
	return false

## Screen shake effect
static func screen_shake(camera: Camera2D, intensity: float, duration: float = 0.5) -> void:
	if not camera:
		return
	if not _is_screen_shake_allowed():
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

## Bounce scale effect
static func bounce_scale(node: Node2D, scale_amount: float = 1.2, duration: float = 0.3) -> void:
	duration = _motion_time(duration)
	var original_scale = node.scale
	
	var tween = node.create_tween()
	tween.tween_property(node, "scale", original_scale * scale_amount, duration * 0.5)
	tween.tween_property(node, "scale", original_scale, duration * 0.5).set_trans(Tween.TRANS_BACK)

## Spawn particle burst
static func particle_burst(node: Node, pos: Vector2, color: Color, count: int = 20) -> void:
	if not _should_show_particles():
		return

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

## Fade in
static func fade_in(node: CanvasItem, duration: float = 0.5) -> void:
	duration = _motion_time(duration)
	node.modulate.a = 0.0
	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)

## Pulse effect (continuous)
##
## The one effect that must not be time-scaled: it loops forever, so running it three
## times faster under reduced motion would make the screen busier, not calmer. Reduced
## motion therefore drops the pulse entirely and leaves the node at rest.
static func pulse(node: Node2D, scale_amount: float = 1.1, duration: float = 1.0) -> void:
	if _should_reduce_motion():
		return

	var original_scale = node.scale

	if duration <= 0.0:
		duration = 1.0

	var tween = node.create_tween().set_loops()
	tween.tween_property(node, "scale", original_scale * scale_amount, duration * 0.5)
	tween.tween_property(node, "scale", original_scale, duration * 0.5)
