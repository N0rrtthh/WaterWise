extends Node
class_name MobileInputHelper

## ═══════════════════════════════════════════════════════════════════
## MOBILE INPUT HELPER
## ═══════════════════════════════════════════════════════════════════
## Unified touch/mouse input handling with mobile optimizations
## - Enlarged touch areas for finger-friendly tapping
## - Visual feedback for touch events
## - Consistent input handling across all games
## ═══════════════════════════════════════════════════════════════════

const MOBILE_TOUCH_AREA_MULTIPLIER: float = 1.5  # 50% larger touch areas
const TOUCH_FEEDBACK_DURATION: float = 0.15

static var is_mobile: bool = false

static func _static_init() -> void:
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

## Check if an input event is a tap/click (unified for mouse and touch)
static func is_tap_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		return event.pressed
	return false

## Check if an input event is a drag (unified for mouse and touch)
static func is_drag_event(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		return true
	elif event is InputEventScreenDrag:
		return true
	return false

## Get position from any input event
static func get_event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return event.position
	elif event is InputEventScreenTouch:
		return event.position
	elif event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO

## Enlarge collision shape for mobile touch
static func optimize_touch_area(area: Area2D) -> void:
	if not is_mobile:
		return
	
	for child in area.get_children():
		if child is CollisionShape2D:
			var shape = child.shape
			if shape is CircleShape2D:
				shape.radius *= MOBILE_TOUCH_AREA_MULTIPLIER
			elif shape is RectangleShape2D:
				shape.size *= MOBILE_TOUCH_AREA_MULTIPLIER
			elif shape is CapsuleShape2D:
				shape.radius *= MOBILE_TOUCH_AREA_MULTIPLIER
				shape.height *= MOBILE_TOUCH_AREA_MULTIPLIER

## Show visual feedback for touch event
static func show_touch_feedback(node: Node, position: Vector2) -> void:
	if not is_mobile:
		return
	
	var feedback = ColorRect.new()
	feedback.size = Vector2(60, 60)
	feedback.position = position - feedback.size / 2
	feedback.color = Color(1, 1, 1, 0.5)
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it circular
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.5)
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.size = Vector2(60, 60)
	panel.position = position - panel.size / 2
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.6
	
	# Add to scene
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 1000  # Always on top
	node.add_child(canvas_layer)
	canvas_layer.add_child(panel)
	
	# Animate
	var tween = node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2(1.5, 1.5), TOUCH_FEEDBACK_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, TOUCH_FEEDBACK_DURATION)
	tween.finished.connect(func():
		canvas_layer.queue_free()
	)

## Check if device is low-end (for performance adjustments)
static func is_low_end_device() -> bool:
	if not is_mobile:
		return false
	
	# Check available memory (rough heuristic)
	var mem_info = OS.get_memory_info()
	var available_mb = mem_info.get("available", 0) / 1024 / 1024
	
	# Less than 2GB available = low-end
	return available_mb < 2048

## Get recommended particle count multiplier based on device
static func get_particle_multiplier() -> float:
	if not is_mobile:
		return 1.0
	
	if is_low_end_device():
		return 0.3  # 30% particles on low-end
	else:
		return 0.5  # 50% particles on mid-range

## Get recommended animation complexity (0=minimal, 1=reduced, 2=full)
static func get_animation_complexity() -> int:
	if not is_mobile:
		return 2  # Full animations on desktop
	
	if is_low_end_device():
		return 0  # Minimal animations on low-end
	else:
		return 1  # Reduced animations on mid-range
