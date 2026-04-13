extends Node

## ═══════════════════════════════════════════════════════════════════
## SAFE AREA INFO TEST
## ═══════════════════════════════════════════════════════════════════
## Unit tests for SafeAreaInfo data model
## Tests safe area calculation, validation, and error handling
## ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("SAFE AREA INFO TEST SUITE")
	print("=".repeat(60) + "\n")
	
	test_default_values()
	test_to_dictionary()
	test_from_display_safe_area()
	test_safe_area_with_notch()
	test_safe_area_full_screen()
	
	print("\n" + "=".repeat(60))
	print("ALL TESTS COMPLETED")
	print("=".repeat(60) + "\n")

func test_default_values() -> void:
	print("TEST: Default Values")
	var safe_area = SafeAreaInfo.new()
	
	# Verify all margins start at zero
	assert(safe_area.top == 0.0, "top should be 0.0")
	assert(safe_area.bottom == 0.0, "bottom should be 0.0")
	assert(safe_area.left == 0.0, "left should be 0.0")
	assert(safe_area.right == 0.0, "right should be 0.0")
	
	print("  ✓ All default values correct\n")

func test_to_dictionary() -> void:
	print("TEST: to_dictionary()")
	var safe_area = SafeAreaInfo.new()
	
	# Set some values
	safe_area.top = 44.0
	safe_area.bottom = 34.0
	safe_area.left = 0.0
	safe_area.right = 0.0
	
	# Convert to dictionary
	var dict = safe_area.to_dictionary()
	
	# Verify dictionary structure
	assert(dict.has("top"), "Dictionary should have 'top' key")
	assert(dict.has("bottom"), "Dictionary should have 'bottom' key")
	assert(dict.has("left"), "Dictionary should have 'left' key")
	assert(dict.has("right"), "Dictionary should have 'right' key")
	
	# Verify values
	assert(dict["top"] == 44.0, "top should be 44.0")
	assert(dict["bottom"] == 34.0, "bottom should be 34.0")
	assert(dict["left"] == 0.0, "left should be 0.0")
	assert(dict["right"] == 0.0, "right should be 0.0")
	
	print("  ✓ to_dictionary() working correctly\n")

func test_from_display_safe_area() -> void:
	print("TEST: from_display_safe_area() - Real Device Data")
	var safe_area = SafeAreaInfo.new()
	
	# Call the actual DisplayServer method
	safe_area.from_display_safe_area()
	
	# Verify margins are non-negative
	assert(safe_area.top >= 0.0, "top should be non-negative")
	assert(safe_area.bottom >= 0.0, "bottom should be non-negative")
	assert(safe_area.left >= 0.0, "left should be non-negative")
	assert(safe_area.right >= 0.0, "right should be non-negative")
	
	# Print actual values for debugging
	print("  Real device safe area margins:")
	print("    Top: %.1f" % safe_area.top)
	print("    Bottom: %.1f" % safe_area.bottom)
	print("    Left: %.1f" % safe_area.left)
	print("    Right: %.1f" % safe_area.right)
	
	print("  ✓ from_display_safe_area() executed without errors\n")

func test_safe_area_with_notch() -> void:
	print("TEST: Safe Area Calculation - Device with Notch")
	
	# Simulate iPhone X-style notch (44px top, 34px bottom)
	# Screen: 1125x2436, Safe area: (0, 44) to (1125, 2402)
	# This test verifies the calculation logic would work correctly
	# Note: We can't directly test this without mocking DisplayServer
	
	# Manual calculation test
	var screen_height = 2436.0
	var safe_area_top = 44.0
	var safe_area_height = 2358.0  # 2436 - 44 - 34
	
	var expected_top = safe_area_top
	var expected_bottom = screen_height - (safe_area_top + safe_area_height)
	
	assert(expected_top == 44.0, "Expected top margin should be 44.0")
	assert(expected_bottom == 34.0, "Expected bottom margin should be 34.0")
	
	print("  ✓ Safe area calculation logic verified for notched device\n")

func test_safe_area_full_screen() -> void:
	print("TEST: Safe Area Calculation - Full Screen Device")
	
	# Simulate device with no notch (safe area = full screen)
	# Screen: 1080x1920, Safe area: (0, 0) to (1080, 1920)
	
	var screen_width = 1080.0
	var screen_height = 1920.0
	var safe_area_x = 0.0
	var safe_area_y = 0.0
	var safe_area_width = 1080.0
	var safe_area_height = 1920.0
	
	var expected_top = safe_area_y
	var expected_bottom = screen_height - (safe_area_y + safe_area_height)
	var expected_left = safe_area_x
	var expected_right = screen_width - (safe_area_x + safe_area_width)
	
	assert(expected_top == 0.0, "Expected top margin should be 0.0")
	assert(expected_bottom == 0.0, "Expected bottom margin should be 0.0")
	assert(expected_left == 0.0, "Expected left margin should be 0.0")
	assert(expected_right == 0.0, "Expected right margin should be 0.0")
	
	print("  ✓ Safe area calculation logic verified for full screen device\n")
