extends Node
class_name ResponsiveUI

## ═══════════════════════════════════════════════════════════════════
## RESPONSIVE UI HELPER
## ═══════════════════════════════════════════════════════════════════
## Automatically adjusts UI elements for different screen sizes
## Handles portrait/landscape, different aspect ratios, safe areas
## ═══════════════════════════════════════════════════════════════════

static var is_mobile: bool = false
static var screen_size: Vector2
static var safe_area: Rect2
static var is_portrait: bool = true
static var ui_scale: float = 1.0

static func _static_init() -> void:
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

## Initialize responsive UI system (call once at game start)
static func initialize() -> void:
	screen_size = DisplayServer.window_get_size()
	is_portrait = screen_size.y > screen_size.x
	
	# Calculate UI scale
	ui_scale = _calculate_ui_scale()
	
	# Get safe area (avoids notches, rounded corners, navigation bars)
	if is_mobile:
		var safe_rects = DisplayServer.get_display_safe_area()
		if safe_rects != Rect2():
			safe_area = safe_rects
		else:
			# Fallback: assume margins for notches/nav bars
			var top_margin = screen_size.y * 0.05  # 5% for notch
			var bottom_margin = screen_size.y * 0.08  # 8% for nav bar
			safe_area = Rect2(
				0, top_margin,
				screen_size.x, screen_size.y - top_margin - bottom_margin
			)
	else:
		safe_area = Rect2(Vector2.ZERO, screen_size)
	
	print("📱 ResponsiveUI initialized:")
	print("   Screen: %dx%d" % [screen_size.x, screen_size.y])
	print("   Orientation: %s" % ("Portrait" if is_portrait else "Landscape"))
	print("   UI Scale: %.2f" % ui_scale)
	print("   Safe Area: %s" % safe_area)

## Calculate UI scale factor based on screen size
static func _calculate_ui_scale() -> float:
	if not is_mobile:
		return 1.0
	
	# Base design size (portrait)
	var base_width = 1080.0
	var base_height = 1920.0
	
	# If landscape, swap dimensions
	if not is_portrait:
		var temp = base_width
		base_width = base_height
		base_height = temp
	
	# Calculate scale based on width (more important for mobile)
	var width_scale = screen_size.x / base_width
	var height_scale = screen_size.y / base_height
	
	# Use smaller scale to ensure everything fits
	return min(width_scale, height_scale)

## Make a Control node responsive (call in _ready())
static func make_responsive(control: Control) -> void:
	if not control:
		return
	
	# Set to full rect with proper anchors
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Reset offsets to 0 (anchors handle positioning)
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0

## Apply safe area margins to a MarginContainer
static func apply_safe_margins(margin_container: MarginContainer) -> void:
	if not margin_container or not is_mobile:
		return
	
	var margins = get_safe_margins()
	margin_container.add_theme_constant_override("margin_top", margins["top"])
	margin_container.add_theme_constant_override("margin_bottom", margins["bottom"])
	margin_container.add_theme_constant_override("margin_left", margins["left"])
	margin_container.add_theme_constant_override("margin_right", margins["right"])

## Get scale factor for UI elements
static func get_ui_scale() -> float:
	return ui_scale

## Adjust font size for screen
static func get_scaled_font_size(base_size: int) -> int:
	return max(int(base_size * ui_scale), 12)  # Minimum 12px

## Get safe margins for UI elements
static func get_safe_margins() -> Dictionary:
	return {
		"top": int(safe_area.position.y),
		"bottom": int(screen_size.y - safe_area.end.y),
		"left": int(safe_area.position.x),
		"right": int(screen_size.x - safe_area.end.x)
	}

## Check if screen is small (need to reduce UI complexity)
static func is_small_screen() -> bool:
	return screen_size.x < 720 or screen_size.y < 1280

## Get button size for current screen
static func get_button_size() -> Vector2:
	var base_size = Vector2(300, 80)
	return base_size * ui_scale

## Get minimum touch target size (44x44 points minimum for accessibility)
static func get_min_touch_size() -> Vector2:
	if is_mobile:
		return Vector2(88, 88)  # 44pt × 2 for pixel density
	return Vector2(44, 44)

## Scale a Vector2 size for current screen
static func scale_size(size: Vector2) -> Vector2:
	return size * ui_scale

## Scale a float value for current screen
static func scale_value(value: float) -> float:
	return value * ui_scale

## Get viewport rect adjusted for safe area
static func get_safe_viewport_rect() -> Rect2:
	return safe_area

## Center a control within safe area
static func center_in_safe_area(control: Control) -> void:
	if not control:
		return
	
	var safe_center = safe_area.get_center()
	control.position = safe_center - control.size / 2

## Adjust control for mobile (comprehensive setup)
static func setup_mobile_control(control: Control, apply_safe_area: bool = true) -> void:
	if not is_mobile:
		return
	
	# Make responsive
	make_responsive(control)
	
	# Apply safe area if requested
	if apply_safe_area:
		var margin = MarginContainer.new()
		margin.name = "SafeAreaMargin"
		
		# Reparent control's children to margin
		var children = control.get_children()
		for child in children:
			control.remove_child(child)
			margin.add_child(child)
		
		# Add margin to control
		control.add_child(margin)
		apply_safe_margins(margin)
		
		# Make margin fill parent
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)

## Get recommended spacing for current screen
static func get_spacing() -> int:
	return int(20 * ui_scale)

## Get recommended margin for current screen
static func get_margin() -> int:
	return int(16 * ui_scale)

## Check if device has notch (approximate)
static func has_notch() -> bool:
	if not is_mobile:
		return false
	
	# If safe area top margin is significant, likely has notch
	var top_margin = safe_area.position.y
	return top_margin > screen_size.y * 0.03  # More than 3% = notch

## Get status bar height (approximate)
static func get_status_bar_height() -> int:
	if not is_mobile:
		return 0
	return int(safe_area.position.y)

## Get navigation bar height (approximate)
static func get_nav_bar_height() -> int:
	if not is_mobile:
		return 0
	return int(screen_size.y - safe_area.end.y)

## Print debug info about current screen
static func print_debug_info() -> void:
	print("═══════════════════════════════════════")
	print("ResponsiveUI Debug Info")
	print("═══════════════════════════════════════")
	print("Platform: %s" % ("Mobile" if is_mobile else "Desktop"))
	print("Screen Size: %dx%d" % [screen_size.x, screen_size.y])
	print("Orientation: %s" % ("Portrait" if is_portrait else "Landscape"))
	print("UI Scale: %.2f" % ui_scale)
	print("Safe Area: %s" % safe_area)
	print("Has Notch: %s" % has_notch())
	print("Status Bar: %dpx" % get_status_bar_height())
	print("Nav Bar: %dpx" % get_nav_bar_height())
	print("Small Screen: %s" % is_small_screen())
	print("═══════════════════════════════════════")
