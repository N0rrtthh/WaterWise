class_name DemoButtonController

## ═══════════════════════════════════════════════════════════════════
## DEMO BUTTON CONTROLLER - VISIBILITY MANAGEMENT
## ═══════════════════════════════════════════════════════════════════
## Helper class for managing demo/debug button visibility based on
## platform, build configuration, and debug flags
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Determines if demo buttons should be visible based on platform and build config
## Returns true if demo buttons should be shown, false otherwise
## 
## Rules:
## - Hide on mobile platforms unless in debug build
## - Show on desktop in debug mode
## - Hide in production builds
## - Respect MobileUIManager configuration flags
##
## **Validates: Requirements 4.1, 4.2, 4.4, 4.5**
static func should_show_demo_buttons() -> bool:
	# Check if MobileUIManager exists
	if not Engine.has_singleton("MobileUIManager"):
		# Fallback: show only in debug builds
		return OS.is_debug_build()
	
	var mobile_ui_manager = Engine.get_singleton("MobileUIManager")
	var is_mobile = mobile_ui_manager.is_mobile_platform()
	var is_debug = OS.is_debug_build()
	
	# Hide on mobile unless in debug mode
	if is_mobile and not is_debug:
		return false
	
	# Show on desktop in debug mode
	if is_debug:
		return true
	
	# Hide in production builds
	return false

## Finds and hides all demo buttons in the scene tree
## Searches for buttons by name patterns and groups
## Removes buttons from the scene tree after hiding
##
## @param root: The root node to search from (typically the scene root)
##
## **Validates: Requirements 4.1, 4.3**
static func hide_demo_buttons(root: Node) -> void:
	if not root:
		push_warning("DemoButtonController.hide_demo_buttons: root is null")
		return
	
	var demo_buttons = find_demo_buttons(root)
	
	for button in demo_buttons:
		if button and is_instance_valid(button):
			button.visible = false
			button.queue_free()
	
	# Log the operation
	if demo_buttons.size() > 0:
		print("📱 DemoButtonController: Hidden %d demo buttons" % demo_buttons.size())

## Public wrapper used by tests and tools that should avoid private method access
static func find_demo_buttons(root: Node) -> Array[Button]:
	return _find_demo_buttons(root)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PRIVATE HELPERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Recursively finds all demo buttons in the scene tree
## Identifies buttons by name patterns and group membership
##
## @param root: The root node to search from
## @return: Array of Button nodes that are demo buttons
static func _find_demo_buttons(root: Node) -> Array[Button]:
	var demo_buttons: Array[Button] = []
	
	if not root:
		return demo_buttons
	
	# Check if current node is a demo button
	if root is Button:
		if _is_demo_button(root):
			demo_buttons.append(root)
	
	# Recursively search children
	for child in root.get_children():
		demo_buttons.append_array(_find_demo_buttons(child))
	
	return demo_buttons

## Checks if a button is a demo button based on name or group
##
## @param button: The button to check
## @return: True if the button is a demo button
static func _is_demo_button(button: Button) -> bool:
	if not button:
		return false
	
	var button_name = button.name.to_lower()
	
	# Check by name patterns
	var demo_name_patterns = [
		"algorithm_demo",
		"algorithmdemo",
		"gcounter_demo",
		"gcounterdemo",
		"research_dashboard",
		"researchdashboard",
		"demo_button",
		"demobutton",
		"algorithm demo",
		"g-counter",
		"gcounter",
		"research dashboard"
	]
	
	for pattern in demo_name_patterns:
		if pattern in button_name:
			return true
	
	# Check by group membership
	if button.is_in_group("demo_buttons"):
		return true
	if button.is_in_group("debug_buttons"):
		return true
	if button.is_in_group("thesis_demo"):
		return true
	
	# Check by button text content
	var button_text = button.text.to_lower()
	var demo_text_patterns = [
		"algorithm demo",
		"g-counter",
		"gcounter",
		"research dashboard",
		"crdt demo",
		"thesis",
		"panelist"
	]
	
	for pattern in demo_text_patterns:
		if pattern in button_text:
			return true
	
	return false
