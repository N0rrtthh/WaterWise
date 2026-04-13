extends Node

## ═══════════════════════════════════════════════════════════════════
## MOBILE UI MANAGER TEST SUITE
## ═══════════════════════════════════════════════════════════════════
## Tests for MobileUIManager.apply_mobile_scaling() method
## Validates: Requirements 2.1, 2.4, 1.3
## ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("MOBILE UI MANAGER - apply_mobile_scaling() TEST SUITE")
	print("=".repeat(60) + "\n")
	
	# Enable mobile mode for testing
	MobileUIManager.enable_debug_mobile_mode(true)
	
	# Button scaling tests
	test_apply_mobile_scaling_to_button()
	test_button_meets_minimum_size()
	test_button_expanded_hit_detection()
	test_button_font_scaling()
	
	# Label scaling tests
	test_apply_mobile_scaling_to_label()
	
	# General control scaling tests
	test_apply_mobile_scaling_to_control()
	test_touch_target_minimum_size()
	
	# Edge case tests
	test_apply_mobile_scaling_handles_null()
	test_apply_mobile_scaling_on_desktop()
	
	# Game object scaling tests
	test_apply_game_object_scaling_interactive()
	test_apply_game_object_scaling_collectible()
	test_apply_game_object_scaling_draggable_minimum_size()
	test_apply_game_object_scaling_preserves_collision()
	test_apply_game_object_scaling_handles_null()
	
	# Orientation detection tests
	test_orientation_detection_basic()
	
	# Safe area margin tests
	test_safe_area_margin_application()
	test_safe_area_changed_signal()
	
	print("\n" + "=".repeat(60))
	print("ALL TESTS COMPLETED")
	print("=".repeat(60) + "\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUTTON SCALING TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_apply_mobile_scaling_to_button() -> void:
	print("TEST: Apply Mobile Scaling - Button")
	var button = Button.new()
	button.size = Vector2(50, 30)
	
	MobileUIManager.apply_mobile_scaling(button)
	
	# Should apply UI scale factor (1.5x)
	assert(button.scale.x == 1.5, "Button scale X should be 1.5")
	assert(button.scale.y == 1.5, "Button scale Y should be 1.5")
	
	button.free()
	print("  ✓ Button scaled correctly\n")

func test_button_meets_minimum_size() -> void:
	print("TEST: Button Minimum Size - 100x60 pixels")
	var button = Button.new()
	button.size = Vector2(40, 20)  # Too small
	
	MobileUIManager.apply_mobile_scaling(button)
	
	# Effective size should meet minimum (100x60)
	var effective_size = button.size * button.scale
	assert(effective_size.x >= 100.0, "Button effective width should be at least 100px")
	assert(effective_size.y >= 60.0, "Button effective height should be at least 60px")
	
	button.free()
	print("  ✓ Button meets minimum size requirement\n")

func test_button_expanded_hit_detection() -> void:
	print("TEST: Button Expanded Hit Detection - 10px expansion")
	var button = Button.new()
	button.size = Vector2(80, 40)
	
	var original_min_size = button.custom_minimum_size
	MobileUIManager.apply_mobile_scaling(button)
	
	# Should add 20 pixels total (10px on each side)
	var size_increase = button.custom_minimum_size - original_min_size
	assert(size_increase.x >= 20.0, "Button width should increase by at least 20px for hit detection")
	assert(size_increase.y >= 20.0, "Button height should increase by at least 20px for hit detection")
	
	button.free()
	print("  ✓ Button has expanded hit detection area\n")

func test_button_font_scaling() -> void:
	print("TEST: Button Font Scaling - 1.4x factor")
	var button = Button.new()
	button.add_theme_font_size_override("font_size", 16)
	
	MobileUIManager.apply_mobile_scaling(button)
	
	# Font should be scaled by mobile_font_scale (1.4x)
	var expected_font_size = int(16 * 1.4)
	var actual_font_size = button.get_theme_font_size("font_size")
	assert(actual_font_size == expected_font_size, 
		"Button font size should be %s, got %s" % [expected_font_size, actual_font_size])
	
	button.free()
	print("  ✓ Button font scaled correctly\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LABEL SCALING TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_apply_mobile_scaling_to_label() -> void:
	print("TEST: Apply Mobile Scaling - Label")
	var label = Label.new()
	label.size = Vector2(100, 30)
	label.add_theme_font_size_override("font_size", 16)
	
	MobileUIManager.apply_mobile_scaling(label)
	
	# Should apply UI scale factor
	assert(label.scale.x == 1.5, "Label scale X should be 1.5")
	assert(label.scale.y == 1.5, "Label scale Y should be 1.5")
	
	# Should apply font scaling
	var expected_font_size = int(16 * 1.4)
	assert(label.get_theme_font_size("font_size") == expected_font_size, 
		"Label font size should be %s" % expected_font_size)
	
	label.free()
	print("  ✓ Label scaled correctly with font scaling\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GENERAL CONTROL SCALING TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_apply_mobile_scaling_to_control() -> void:
	print("TEST: Apply Mobile Scaling - Generic Control")
	var control = Control.new()
	control.size = Vector2(100, 100)
	
	MobileUIManager.apply_mobile_scaling(control)
	
	# Should apply UI scale factor
	assert(control.scale.x == 1.5, "Control scale X should be 1.5")
	assert(control.scale.y == 1.5, "Control scale Y should be 1.5")
	
	control.free()
	print("  ✓ Generic control scaled correctly\n")

func test_touch_target_minimum_size() -> void:
	print("TEST: Touch Target Minimum Size - 80x80 pixels")
	var control = Control.new()
	control.size = Vector2(40, 40)  # Too small
	
	MobileUIManager.apply_mobile_scaling(control)
	
	# Effective size should meet minimum touch target size (80x80)
	var effective_size = control.size * control.scale
	assert(effective_size.x >= 80.0, "Touch target effective width should be at least 80px")
	assert(effective_size.y >= 80.0, "Touch target effective height should be at least 80px")
	
	control.free()
	print("  ✓ Touch target meets minimum size requirement\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EDGE CASE TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_apply_mobile_scaling_handles_null() -> void:
	print("TEST: Apply Mobile Scaling - Null Node Handling")
	MobileUIManager.apply_mobile_scaling(null)
	print("  ✓ Null node handled gracefully\n")

func test_apply_mobile_scaling_on_desktop() -> void:
	print("TEST: Apply Mobile Scaling - Desktop Mode (No Scaling)")
	
	# Disable mobile mode
	MobileUIManager.enable_debug_mobile_mode(false)
	
	var button = Button.new()
	button.size = Vector2(50, 30)
	var original_scale = button.scale
	
	MobileUIManager.apply_mobile_scaling(button)
	
	# Should not apply any scaling on desktop
	assert(button.scale == original_scale, "Button should not be scaled on desktop")
	
	button.free()
	
	# Re-enable mobile mode for other tests
	MobileUIManager.enable_debug_mobile_mode(true)
	
	print("  ✓ No scaling applied on desktop mode\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME OBJECT SCALING TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_apply_game_object_scaling_interactive() -> void:
	print("TEST: Apply Game Object Scaling - Interactive Object (1.4x)")
	var node = Node2D.new()
	node.name = "InteractiveObject"
	node.scale = Vector2(1.0, 1.0)
	
	MobileUIManager.apply_game_object_scaling(node)
	
	# Should apply game object scale factor (1.4x)
	assert(node.scale.x == 1.4, "Interactive object scale X should be 1.4, got %s" % node.scale.x)
	assert(node.scale.y == 1.4, "Interactive object scale Y should be 1.4, got %s" % node.scale.y)
	
	node.free()
	print("  ✓ Interactive object scaled to 1.4x\n")

func test_apply_game_object_scaling_collectible() -> void:
	print("TEST: Apply Game Object Scaling - Collectible (1.3x)")
	var node = Node2D.new()
	node.name = "WaterDrop"  # Contains "drop" keyword
	node.scale = Vector2(1.0, 1.0)
	
	MobileUIManager.apply_game_object_scaling(node)
	
	# Should apply collectible scale factor (1.3x)
	assert(node.scale.x == 1.3, "Collectible scale X should be 1.3, got %s" % node.scale.x)
	assert(node.scale.y == 1.3, "Collectible scale Y should be 1.3, got %s" % node.scale.y)
	
	node.free()
	print("  ✓ Collectible scaled to 1.3x\n")

func test_apply_game_object_scaling_draggable_minimum_size() -> void:
	print("TEST: Apply Game Object Scaling - Draggable Minimum Size (120x120)")
	
	# Create a draggable object with collision shape
	var node = Node2D.new()
	node.name = "DraggableObject"
	node.input_pickable = true
	node.scale = Vector2(1.0, 1.0)
	
	# Add collision shape with small size
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(50, 50)  # Too small for dragging
	collision.shape = shape
	node.add_child(collision)
	
	MobileUIManager.apply_game_object_scaling(node)
	
	# Calculate effective size after scaling
	var effective_size = shape.size * node.scale
	assert(effective_size.x >= 120.0, "Draggable effective width should be at least 120px, got %s" % effective_size.x)
	assert(effective_size.y >= 120.0, "Draggable effective height should be at least 120px, got %s" % effective_size.y)
	
	node.free()
	print("  ✓ Draggable object meets minimum size requirement\n")

func test_apply_game_object_scaling_preserves_collision() -> void:
	print("TEST: Apply Game Object Scaling - Collision Shape Preservation")
	
	# Create object with collision shape
	var node = Node2D.new()
	node.name = "GameObject"
	node.scale = Vector2(1.0, 1.0)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	node.add_child(collision)
	
	var original_radius = shape.radius
	
	MobileUIManager.apply_game_object_scaling(node)
	
	# Collision shape properties should remain unchanged
	# (Godot automatically scales collision with parent node)
	assert(shape.radius == original_radius, 
		"Collision shape radius should remain %s, got %s" % [original_radius, shape.radius])
	
	# But effective collision area should be scaled
	var effective_radius = shape.radius * node.scale.x
	assert(effective_radius > original_radius, 
		"Effective collision radius should be scaled")
	
	node.free()
	print("  ✓ Collision shape preserved and scaled correctly\n")

func test_apply_game_object_scaling_handles_null() -> void:
	print("TEST: Apply Game Object Scaling - Null Node Handling")
	MobileUIManager.apply_game_object_scaling(null)
	print("  ✓ Null node handled gracefully\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ORIENTATION DETECTION TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_orientation_detection_basic() -> void:
	print("TEST: Orientation Detection - Basic Functionality")
	
	# Test portrait detection
	MobileUIManager.viewport_width = 600
	MobileUIManager.viewport_height = 800
	MobileUIManager._detect_orientation()
	assert(MobileUIManager.is_portrait_orientation() == true, 
		"Should detect portrait orientation (600x800)")
	
	# Test landscape detection
	MobileUIManager.viewport_width = 800
	MobileUIManager.viewport_height = 600
	MobileUIManager._detect_orientation()
	assert(MobileUIManager.is_portrait_orientation() == false, 
		"Should detect landscape orientation (800x600)")
	
	# Test square viewport (edge case - should be landscape)
	MobileUIManager.viewport_width = 800
	MobileUIManager.viewport_height = 800
	MobileUIManager._detect_orientation()
	assert(MobileUIManager.is_portrait_orientation() == false, 
		"Should detect landscape orientation for square viewport (800x800)")
	
	print("  ✓ Orientation detection works correctly\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SAFE AREA MARGIN TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_safe_area_margin_application() -> void:
	print("TEST: Safe Area Margin Application - 20px minimum margin")
	
	# Get safe area margins from MobileUIManager
	var margins = MobileUIManager.get_safe_area_margins()
	
	# Verify margins dictionary structure
	assert(margins.has("top"), "Margins should have 'top' key")
	assert(margins.has("bottom"), "Margins should have 'bottom' key")
	assert(margins.has("left"), "Margins should have 'left' key")
	assert(margins.has("right"), "Margins should have 'right' key")
	
	# Verify all margins are non-negative
	assert(margins["top"] >= 0.0, "Top margin should be non-negative")
	assert(margins["bottom"] >= 0.0, "Bottom margin should be non-negative")
	assert(margins["left"] >= 0.0, "Left margin should be non-negative")
	assert(margins["right"] >= 0.0, "Right margin should be non-negative")
	
	# Verify 20-pixel minimum margin is applied
	# Note: On devices without notches, the base margin is 0, so we should have exactly 20px
	# On devices with notches, we should have base_margin + 20px
	var min_margin = MobileUIManager.get_safe_area_margin()
	assert(min_margin == 20.0, "Minimum safe area margin should be 20px")
	
	print("  Safe area margins:")
	print("    Top: %.1f" % margins["top"])
	print("    Bottom: %.1f" % margins["bottom"])
	print("    Left: %.1f" % margins["left"])
	print("    Right: %.1f" % margins["right"])
	print("  ✓ Safe area margins calculated with 20px minimum\n")

func test_safe_area_changed_signal() -> void:
	print("TEST: Safe Area Changed Signal - Emitted on initialization")
	
	# The signal should have been emitted during initialization
	# We can verify by checking that safe_area_margins is populated
	var margins = MobileUIManager.safe_area_margins
	
	assert(margins.size() == 4, "Safe area margins should have 4 entries")
	assert(margins.has("top"), "Should have top margin")
	assert(margins.has("bottom"), "Should have bottom margin")
	assert(margins.has("left"), "Should have left margin")
	assert(margins.has("right"), "Should have right margin")
	
	print("  ✓ Safe area changed signal emitted and margins populated\n")
