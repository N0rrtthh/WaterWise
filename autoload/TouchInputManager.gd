extends Node

## ═══════════════════════════════════════════════════════════════════
## TOUCH INPUT MANAGER - MOBILE OPTIMIZATION
## ═══════════════════════════════════════════════════════════════════
## Handles touch input for mobile devices
## Provides gesture detection and haptic feedback
## ═══════════════════════════════════════════════════════════════════

signal touch_tap(position: Vector2)
signal touch_swipe(direction: Vector2, velocity: float)
signal touch_hold(position: Vector2, duration: float)
signal touch_drag(from: Vector2, to: Vector2)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Touch thresholds
@export var tap_threshold: float = 0.3  # Max time for tap (seconds)
@export var hold_threshold: float = 0.5  # Min time for hold (seconds)
@export var swipe_threshold: float = 50.0  # Min distance for swipe (pixels)
@export var swipe_velocity_threshold: float = 200.0  # Min velocity for swipe

## UI Scaling for mobile
@export var mobile_button_min_size: Vector2 = Vector2(80, 80)  # Minimum touch target size
@export var mobile_font_scale: float = 1.2  # Font scaling for mobile readability

## Hit detection expansion
@export var hit_expansion: float = 10.0  # Pixels to expand hit area for touch targets

## Edge dead zone
@export var edge_dead_zone: float = 15.0  # Pixels from screen edge to ignore touches

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var is_mobile: bool = false
var touch_start_position: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var is_touching: bool = false
var active_touches: Dictionary = {}  # Track multi-touch

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	_detect_platform()
	print("📱 TouchInputManager initialized - Mobile: %s" % is_mobile)

func _detect_platform() -> void:
	# Detect if running on mobile
	var os_name = OS.get_name()
	is_mobile = os_name in ["Android", "iOS"]
	
	# Also check if display is in portrait mode (likely mobile)
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.y > viewport_size.x:
		is_mobile = true
	
	# Apply mobile-specific settings
	if is_mobile:
		_apply_mobile_settings()

func _apply_mobile_settings() -> void:
	# Prevent screen from sleeping during gameplay
	DisplayServer.screen_set_keep_on(true)
	
	print("📱 Mobile settings applied:")
	print("   - Screen keep on: enabled")
	print("   - Touch emulation: enabled")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INPUT HANDLING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _input(event: InputEvent) -> void:
	# Handle touch input
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	# Filter touches in edge dead zone
	if _is_in_edge_dead_zone(event.position):
		return
	
	if event.pressed:
		# Touch started
		active_touches[event.index] = {
			"start_position": event.position,
			"start_time": Time.get_ticks_msec() / 1000.0,
			"current_position": event.position
		}
		
		if event.index == 0:  # Primary touch
			touch_start_position = event.position
			touch_start_time = Time.get_ticks_msec() / 1000.0
			is_touching = true
	else:
		# Touch ended
		if active_touches.has(event.index):
			var touch_data = active_touches[event.index]
			var duration = (Time.get_ticks_msec() / 1000.0) - touch_data["start_time"]
			var distance = event.position.distance_to(touch_data["start_position"])
			var direction = (event.position - touch_data["start_position"]).normalized()
			var velocity = distance / max(duration, 0.001)
			
			if event.index == 0:  # Primary touch
				# Determine gesture type
				if duration < tap_threshold and distance < swipe_threshold:
					# TAP
					touch_tap.emit(event.position)
				elif duration >= hold_threshold and distance < swipe_threshold:
					# HOLD
					touch_hold.emit(touch_data["start_position"], duration)
				elif distance >= swipe_threshold and velocity >= swipe_velocity_threshold:
					# SWIPE
					touch_swipe.emit(direction, velocity)
				
				is_touching = false
			
			active_touches.erase(event.index)

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if active_touches.has(event.index):
		var old_position = active_touches[event.index]["current_position"]
		active_touches[event.index]["current_position"] = event.position
		
		if event.index == 0:  # Primary touch
			touch_drag.emit(old_position, event.position)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HAPTIC FEEDBACK (Mobile Only)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func vibrate_light() -> void:
	if is_mobile:
		Input.vibrate_handheld(50)  # 50ms light vibration

func vibrate_medium() -> void:
	if is_mobile:
		Input.vibrate_handheld(100)  # 100ms medium vibration

func vibrate_heavy() -> void:
	if is_mobile:
		Input.vibrate_handheld(200)  # 200ms heavy vibration

func vibrate_success() -> void:
	# Pattern: short-short-long
	if is_mobile:
		Input.vibrate_handheld(50)
		await get_tree().create_timer(0.1).timeout
		Input.vibrate_handheld(50)
		await get_tree().create_timer(0.1).timeout
		Input.vibrate_handheld(150)

func vibrate_error() -> void:
	# Pattern: long-long
	if is_mobile:
		Input.vibrate_handheld(150)
		await get_tree().create_timer(0.1).timeout
		Input.vibrate_handheld(150)

func vibrate_button_press() -> void:
	"""Provide haptic feedback for button presses on mobile platforms
	
	This method should be called when a button is pressed to provide
	tactile feedback to the user. Only triggers on mobile platforms.
	Requirement 2.5: Haptic feedback on button press
	"""
	if is_mobile:
		Input.vibrate_handheld(50)  # 50ms light vibration for button press

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UI HELPERS FOR MOBILE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_scaled_font_size(base_size: int) -> int:
	if is_mobile:
		return int(base_size * mobile_font_scale)
	return base_size

func get_minimum_touch_size() -> Vector2:
	if is_mobile:
		return mobile_button_min_size
	return Vector2(44, 44)  # Standard accessible button size

func is_touch_target_valid(control: Control) -> bool:
	var min_size = get_minimum_touch_size()
	return control.size.x >= min_size.x and control.size.y >= min_size.y

func get_safe_area_margins() -> Dictionary:
	# Get device safe area (for notched phones)
	var safe_area = DisplayServer.get_display_safe_area()
	var screen_size = DisplayServer.screen_get_size()
	
	return {
		"top": safe_area.position.y,
		"bottom": screen_size.y - (safe_area.position.y + safe_area.size.y),
		"left": safe_area.position.x,
		"right": screen_size.x - (safe_area.position.x + safe_area.size.x)
	}

func enable_button_haptics(button: BaseButton) -> void:
	"""Enable haptic feedback for a button on mobile platforms
	
	Connects the button's pressed signal to trigger haptic feedback.
	This should be called for all interactive buttons in the UI.
	
	@param button: The button to enable haptics for
	"""
	if not button:
		push_warning("TouchInputManager.enable_button_haptics: button is null")
		return
	
	# Only connect if on mobile platform
	if is_mobile:
		# Check if already connected to avoid duplicate connections
		if not button.pressed.is_connected(vibrate_button_press):
			button.pressed.connect(vibrate_button_press)

func enable_haptics_for_scene(root: Node) -> void:
	"""Recursively enable haptic feedback for all buttons in a scene
	
	Traverses the scene tree and enables haptics for all BaseButton nodes.
	This is a convenience method for enabling haptics across an entire scene.
	
	@param root: The root node to start traversal from
	"""
	if not root:
		return
	
	# Enable haptics for this node if it's a button
	if root is BaseButton:
		enable_button_haptics(root)
	
	# Recursively process children
	for child in root.get_children():
		enable_haptics_for_scene(child)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GESTURE UTILITIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_swipe_direction_name(direction: Vector2) -> String:
	# Convert direction vector to readable name
	if abs(direction.x) > abs(direction.y):
		return "right" if direction.x > 0 else "left"
	return "down" if direction.y > 0 else "up"

func get_touch_count() -> int:
	return active_touches.size()

func is_multi_touch() -> bool:
	return active_touches.size() > 1

func get_pinch_distance() -> float:
	# Calculate distance between two touches for pinch gesture
	if active_touches.size() < 2:
		return 0.0
	
	var positions = []
	for touch in active_touches.values():
		positions.append(touch["current_position"])
	
	return positions[0].distance_to(positions[1])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HIT DETECTION EXPANSION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func is_touch_in_expanded_bounds(touch_pos: Vector2, control: Control) -> bool:
	"""Check if touch position is within expanded bounds of a control node
	
	Expands the hit area by hit_expansion pixels on all sides to make
	touch targets easier to hit on mobile devices.
	
	@param touch_pos: The touch position in screen coordinates
	@param control: The control node to check against
	@return: True if touch is within expanded bounds
	"""
	if not control or not control.is_visible_in_tree():
		return false
	
	var global_rect = control.get_global_rect()
	var expanded_rect = global_rect.grow(hit_expansion)
	
	return expanded_rect.has_point(touch_pos)

func find_touch_target(touch_pos: Vector2, root: Node) -> Control:
	"""Find the best touch target at the given position with expanded hit detection
	
	Searches for Control nodes that contain the touch position, considering
	expanded hit areas. Prioritizes smaller/closer targets for disambiguation.
	
	@param touch_pos: The touch position in screen coordinates
	@param root: The root node to start searching from
	@return: The best matching Control node, or null if none found
	"""
	var candidates = []
	_find_touch_candidates(touch_pos, root, candidates)
	
	if candidates.is_empty():
		return null
	
	# Disambiguate by choosing smallest area (most specific target)
	candidates.sort_custom(func(a, b): return a.size.x * a.size.y < b.size.x * b.size.y)
	return candidates[0]

func _find_touch_candidates(touch_pos: Vector2, node: Node, candidates: Array) -> void:
	"""Recursively find all Control nodes that could be touch targets"""
	if node is Control and is_touch_in_expanded_bounds(touch_pos, node):
		# Only consider interactive controls
		if node is BaseButton or node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			candidates.append(node)
	
	for child in node.get_children():
		_find_touch_candidates(touch_pos, child, candidates)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EDGE DEAD ZONE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _is_in_edge_dead_zone(position: Vector2) -> bool:
	"""Check if touch position is within edge dead zone
	
	Filters accidental touches near screen edges by ignoring touches
	within edge_dead_zone pixels from any screen edge.
	
	@param position: The touch position in screen coordinates
	@return: True if position is in dead zone (should be ignored)
	"""
	if not is_mobile:
		return false
	
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Check all four edges
	if position.x < edge_dead_zone or position.x > viewport_size.x - edge_dead_zone:
		return true
	if position.y < edge_dead_zone or position.y > viewport_size.y - edge_dead_zone:
		return true
	
	return false
