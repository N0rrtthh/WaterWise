class_name LayoutManager

## ═══════════════════════════════════════════════════════════════════
## LAYOUT MANAGER - HELPER CLASS FOR RESPONSIVE LAYOUTS
## ═══════════════════════════════════════════════════════════════════
## Static utility methods for managing responsive layouts on mobile
## Handles orientation changes, safe area margins, and button spacing
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ORIENTATION-BASED LAYOUT REORGANIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Reorganize container layout based on orientation
##
## Switches between vertical layout (portrait) and horizontal/grid layout
## (landscape) to optimize screen space usage.
##
## @param container: The Container node to reorganize
## @param is_portrait: True for portrait orientation, false for landscape
static func reorganize_for_orientation(container: Container, is_portrait: bool) -> void:
	if not container:
		push_warning("LayoutManager.reorganize_for_orientation: container is null")
		return
	
	if is_portrait:
		_apply_vertical_layout(container)
	else:
		_apply_horizontal_layout(container)

## Apply vertical layout for portrait orientation
static func _apply_vertical_layout(container: Container) -> void:
	# If container is a BoxContainer, set it to vertical
	if container is BoxContainer:
		container.vertical = true
	
	# If container is a GridContainer, set it to single column
	if container is GridContainer:
		container.columns = 1
	
	# Apply vertical button spacing
	apply_button_spacing_vertical(container)

## Apply horizontal or grid layout for landscape orientation
static func _apply_horizontal_layout(container: Container) -> void:
	# If container is a BoxContainer, set it to horizontal
	if container is BoxContainer:
		container.vertical = false
	
	# If container is a GridContainer, calculate optimal column count
	if container is GridContainer:
		var child_count = container.get_child_count()
		# Use 2-3 columns for landscape depending on child count
		if child_count <= 4:
			container.columns = 2
		else:
			container.columns = 3
	
	# Apply horizontal button spacing
	apply_button_spacing_horizontal(container)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SAFE AREA MARGIN APPLICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Apply safe area margins to prevent overlap with notches
##
## This method applies margins to a Control node to ensure content
## stays within the safe area on devices with notches or rounded corners.
##
## @param node: The Control node to apply margins to
## @param margins: Dictionary with keys "top", "bottom", "left", "right"
static func apply_safe_area_margins(node: Control, margins: Dictionary) -> void:
	if not node:
		push_warning("LayoutManager.apply_safe_area_margins: node is null")
		return
	
	if not margins:
		push_warning("LayoutManager.apply_safe_area_margins: margins dictionary is null")
		return
	
	# Extract margin values with defaults
	var top = margins.get("top", 0.0)
	var bottom = margins.get("bottom", 0.0)
	var left = margins.get("left", 0.0)
	var right = margins.get("right", 0.0)
	
	# Apply margins based on node type
	if node is MarginContainer:
		# MarginContainer uses theme constants for margins
		node.add_theme_constant_override("margin_top", int(top))
		node.add_theme_constant_override("margin_bottom", int(bottom))
		node.add_theme_constant_override("margin_left", int(left))
		node.add_theme_constant_override("margin_right", int(right))
	elif node is Control:
		# For other Control nodes, use offset properties
		node.offset_top = top
		node.offset_bottom = -bottom
		node.offset_left = left
		node.offset_right = -right

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUTTON SPACING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Apply vertical button spacing for mobile (20 pixels)
##
## Sets the separation between buttons in a vertical layout to meet
## mobile touch target spacing requirements.
##
## @param container: The Container node containing buttons
## @param spacing: The spacing value in pixels (default: 20.0)
static func apply_button_spacing_vertical(container: Container, spacing: float = 20.0) -> void:
	if not container:
		push_warning("LayoutManager.apply_button_spacing_vertical: container is null")
		return
	
	if spacing < 0.0:
		push_warning("LayoutManager.apply_button_spacing_vertical: spacing must be non-negative, got %s" % spacing)
		return
	
	# Apply spacing based on container type
	if container is BoxContainer:
		container.add_theme_constant_override("separation", int(spacing))
	elif container is GridContainer:
		# GridContainer uses v_separation for vertical spacing
		container.add_theme_constant_override("v_separation", int(spacing))

## Apply horizontal button spacing for mobile (15 pixels)
##
## Sets the separation between buttons in a horizontal layout to meet
## mobile touch target spacing requirements.
##
## @param container: The Container node containing buttons
## @param spacing: The spacing value in pixels (default: 15.0)
static func apply_button_spacing_horizontal(container: Container, spacing: float = 15.0) -> void:
	if not container:
		push_warning("LayoutManager.apply_button_spacing_horizontal: container is null")
		return
	
	if spacing < 0.0:
		push_warning("LayoutManager.apply_button_spacing_horizontal: spacing must be non-negative, got %s" % spacing)
		return
	
	# Apply spacing based on container type
	if container is BoxContainer:
		container.add_theme_constant_override("separation", int(spacing))
	elif container is GridContainer:
		# GridContainer uses h_separation for horizontal spacing
		container.add_theme_constant_override("h_separation", int(spacing))
