class_name UIScaler

## ═══════════════════════════════════════════════════════════════════
## UI SCALER - HELPER CLASS FOR CONTROL NODE SCALING
## ═══════════════════════════════════════════════════════════════════
## Static utility methods for scaling UI elements on mobile platforms
## Handles Control node scaling, font scaling, and minimum size enforcement
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTROL NODE SCALING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Scale a Control node while preserving aspect ratio
## 
## This method applies uniform scaling to both X and Y axes to maintain
## the original aspect ratio of the control node.
##
## @param node: The Control node to scale
## @param scale_factor: The scaling factor to apply (e.g., 1.5 for 150%)
static func scale_control_node(node: Control, scale_factor: float) -> void:
	if not node:
		push_warning("UIScaler.scale_control_node: node is null")
		return
	
	if scale_factor <= 0.0:
		push_warning("UIScaler.scale_control_node: scale_factor must be positive, got %s" % scale_factor)
		return
	
	# Apply uniform scaling to preserve aspect ratio
	node.scale = Vector2(scale_factor, scale_factor)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FONT SCALING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Scale font size for a Label node
##
## This method scales the font size by the specified factor. It handles
## both theme font size overrides and default font sizes.
##
## @param label: The Label node to scale
## @param scale_factor: The scaling factor to apply (e.g., 1.4 for 140%)
static func scale_font(label: Label, scale_factor: float) -> void:
	if not label:
		push_warning("UIScaler.scale_font: label is null")
		return
	
	if scale_factor <= 0.0:
		push_warning("UIScaler.scale_font: scale_factor must be positive, got %s" % scale_factor)
		return
	
	# Get current font size (check for override first, then theme default)
	var current_size: int
	if label.has_theme_font_size_override("font_size"):
		current_size = label.get_theme_font_size("font_size")
	else:
		# Get default font size from theme or use fallback
		var theme_font_size = label.get_theme_font_size("font_size")
		current_size = theme_font_size if theme_font_size > 0 else 16
	
	# Calculate and apply new font size
	var new_size = int(current_size * scale_factor)
	label.add_theme_font_size_override("font_size", new_size)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MINIMUM SIZE ENFORCEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Ensure a Control node meets minimum size requirements
##
## This method enforces minimum size constraints for touch targets.
## If the node's current size is smaller than the minimum in either
## dimension, the custom_minimum_size is set to enforce the requirement.
##
## @param node: The Control node to check and adjust
## @param min_size: The minimum size required (e.g., Vector2(80, 80))
static func ensure_minimum_size(node: Control, min_size: Vector2) -> void:
	if not node:
		push_warning("UIScaler.ensure_minimum_size: node is null")
		return
	
	if min_size.x < 0.0 or min_size.y < 0.0:
		push_warning("UIScaler.ensure_minimum_size: min_size components must be non-negative, got %s" % min_size)
		return
	
	# Check if current size meets minimum requirements
	# Note: We need to account for the node's scale when checking effective size
	var effective_size = node.size * node.scale
	
	if effective_size.x < min_size.x or effective_size.y < min_size.y:
		# Calculate required minimum size accounting for current scale
		var required_min_size = Vector2(
			max(min_size.x / node.scale.x, node.custom_minimum_size.x),
			max(min_size.y / node.scale.y, node.custom_minimum_size.y)
		)
		node.custom_minimum_size = required_min_size

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEXT READABILITY ENHANCEMENTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Ensure label has minimum font size for readability
##
## Enforces a minimum font size (typically 24px for mobile) to ensure
## text remains readable on small screens.
##
## @param label: The Label node to check and adjust
## @param min_size: The minimum font size in pixels (default: 24)
static func ensure_minimum_font_size(label: Label, min_size: int = 24) -> void:
	if not label:
		push_warning("UIScaler.ensure_minimum_font_size: label is null")
		return
	
	if min_size < 1:
		push_warning("UIScaler.ensure_minimum_font_size: min_size must be positive, got %d" % min_size)
		return
	
	# Get current font size
	var current_size: int
	if label.has_theme_font_size_override("font_size"):
		current_size = label.get_theme_font_size("font_size")
	else:
		var theme_font_size = label.get_theme_font_size("font_size")
		current_size = theme_font_size if theme_font_size > 0 else 16
	
	# Apply minimum size if needed
	if current_size < min_size:
		label.add_theme_font_size_override("font_size", min_size)

## Add outline to label text for better contrast
##
## Adds a text outline to improve readability against varying backgrounds.
## Typical thickness is 4 pixels for mobile.
##
## @param label: The Label node to add outline to
## @param thickness: The outline thickness in pixels (default: 4)
## @param color: The outline color (default: black)
static func add_text_outline(label: Label, thickness: int = 4, color: Color = Color.BLACK) -> void:
	if not label:
		push_warning("UIScaler.add_text_outline: label is null")
		return
	
	if thickness < 0:
		push_warning("UIScaler.add_text_outline: thickness must be non-negative, got %d" % thickness)
		return
	
	# Add outline color and size overrides
	label.add_theme_constant_override("outline_size", thickness)
	label.add_theme_color_override("font_outline_color", color)

## Add semi-transparent backdrop to label for better readability
##
## Creates a ColorRect backdrop behind the label to improve text contrast
## against complex or varying backgrounds.
##
## @param label: The Label node to add backdrop to
## @param color: The backdrop color (default: semi-transparent black)
## @param padding: Padding around text in pixels (default: 8)
static func add_text_backdrop(label: Label, color: Color = Color(0, 0, 0, 0.6), padding: float = 8.0) -> void:
	if not label:
		push_warning("UIScaler.add_text_backdrop: label is null")
		return
	
	if padding < 0:
		push_warning("UIScaler.add_text_backdrop: padding must be non-negative, got %f" % padding)
		return
	
	# Check if backdrop already exists
	var backdrop_name = "_text_backdrop"
	var existing_backdrop = label.get_node_or_null(backdrop_name)
	if existing_backdrop:
		# Update existing backdrop
		if existing_backdrop is ColorRect:
			existing_backdrop.color = color
		return
	
	# Create ColorRect backdrop
	var backdrop = ColorRect.new()
	backdrop.name = backdrop_name
	backdrop.color = color
	backdrop.z_index = -1  # Behind the label
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	
	# Position backdrop behind label with padding
	backdrop.position = Vector2(-padding, -padding)
	backdrop.size = label.size + Vector2(padding * 2, padding * 2)
	
	# Add as child of label
	label.add_child(backdrop)
	
	# Connect to label size changes to update backdrop
	if not label.resized.is_connected(_on_label_resized.bind(label, backdrop, padding)):
		label.resized.connect(_on_label_resized.bind(label, backdrop, padding))

static func _on_label_resized(label: Label, backdrop: ColorRect, padding: float) -> void:
	"""Update backdrop size when label is resized"""
	if backdrop and is_instance_valid(backdrop):
		backdrop.size = label.size + Vector2(padding * 2, padding * 2)

## Check if text and background colors meet WCAG contrast ratio
##
## Calculates the contrast ratio between text and background colors
## and checks if it meets the WCAG AA standard (4.5:1 for normal text).
##
## @param text_color: The text color
## @param bg_color: The background color
## @return: True if contrast ratio meets 4.5:1 requirement
static func check_contrast_ratio(text_color: Color, bg_color: Color) -> bool:
	# Calculate relative luminance for each color
	var text_luminance = _calculate_relative_luminance(text_color)
	var bg_luminance = _calculate_relative_luminance(bg_color)
	
	# Calculate contrast ratio
	var lighter = max(text_luminance, bg_luminance)
	var darker = min(text_luminance, bg_luminance)
	var contrast_ratio = (lighter + 0.05) / (darker + 0.05)
	
	# WCAG AA requires 4.5:1 for normal text
	return contrast_ratio >= 4.5

static func _calculate_relative_luminance(color: Color) -> float:
	"""Calculate relative luminance according to WCAG formula"""
	# Convert sRGB to linear RGB
	var r = _srgb_to_linear(color.r)
	var g = _srgb_to_linear(color.g)
	var b = _srgb_to_linear(color.b)
	
	# Calculate relative luminance
	return 0.2126 * r + 0.7152 * g + 0.0722 * b

static func _srgb_to_linear(component: float) -> float:
	"""Convert sRGB component to linear RGB"""
	if component <= 0.03928:
		return component / 12.92
	else:
		return pow((component + 0.055) / 1.055, 2.4)

## Get contrast ratio between two colors
##
## @param text_color: The text color
## @param bg_color: The background color
## @return: The contrast ratio (e.g., 4.5 for 4.5:1)
static func get_contrast_ratio(text_color: Color, bg_color: Color) -> float:
	var text_luminance = _calculate_relative_luminance(text_color)
	var bg_luminance = _calculate_relative_luminance(bg_color)
	
	var lighter = max(text_luminance, bg_luminance)
	var darker = min(text_luminance, bg_luminance)
	
	return (lighter + 0.05) / (darker + 0.05)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEXT WRAPPING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Enable automatic text wrapping for long instruction text
##
## Enables word wrapping and adjusts container height to accommodate
## wrapped text. Prevents text from being cut off on narrow screens.
##
## @param label: The Label node to enable wrapping for
## @param max_width: Maximum width before wrapping (default: viewport width)
static func enable_text_wrapping(label: Label, max_width: float = -1.0) -> void:
	if not label:
		push_warning("UIScaler.enable_text_wrapping: label is null")
		return
	
	# Enable autowrap
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Set maximum width if specified
	if max_width > 0:
		label.custom_minimum_size.x = max_width
	
	# Ensure label can expand vertically
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL

## Adjust container height to fit wrapped text
##
## Calculates the required height for wrapped text and adjusts the
## parent container accordingly.
##
## @param label: The Label node with wrapped text
static func adjust_container_for_wrapped_text(label: Label) -> void:
	if not label:
		push_warning("UIScaler.adjust_container_for_wrapped_text: label is null")
		return
	
	# Force label to recalculate its size
	label.reset_size()
	
	# Get parent container
	var parent = label.get_parent()
	if not parent or not parent is Container:
		return
	
	# Container will automatically adjust based on label's new size
	# due to Godot's layout system, but we can force an update
	parent.queue_sort()
