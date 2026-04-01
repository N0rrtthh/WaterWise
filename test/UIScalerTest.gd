extends Node

## ═══════════════════════════════════════════════════════════════════
## UI SCALER TEST SUITE
## ═══════════════════════════════════════════════════════════════════
## Tests for UIScaler helper class
## Validates: Requirements 1.1, 1.2, 1.3, 1.5
## ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("UI SCALER TEST SUITE")
	print("=".repeat(60) + "\n")
	
	# Control node scaling tests
	test_scale_control_node_applies_uniform_scaling()
	test_scale_control_node_preserves_aspect_ratio()
	test_scale_control_node_with_different_scale_factors()
	test_scale_control_node_handles_null_node()
	test_scale_control_node_handles_zero_scale_factor()
	test_scale_control_node_handles_negative_scale_factor()
	
	# Font scaling tests
	test_scale_font_increases_font_size()
	test_scale_font_with_default_font_size()
	test_scale_font_with_various_scale_factors()
	test_scale_font_handles_null_label()
	test_scale_font_handles_zero_scale_factor()
	test_scale_font_handles_negative_scale_factor()
	
	# Minimum size enforcement tests
	test_ensure_minimum_size_enforces_minimum()
	test_ensure_minimum_size_respects_existing_size()
	test_ensure_minimum_size_accounts_for_scale()
	test_ensure_minimum_size_with_button_requirements()
	test_ensure_minimum_size_with_touch_target_requirements()
	test_ensure_minimum_size_handles_null_node()
	test_ensure_minimum_size_handles_negative_min_size()
	test_ensure_minimum_size_handles_zero_min_size()
	
	# Integration tests
	test_combined_scaling_and_minimum_size()
	test_scaling_with_font_and_size_enforcement()
	
	print("\n" + "=".repeat(60))
	print("ALL TESTS COMPLETED")
	print("=".repeat(60) + "\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTROL NODE SCALING TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_scale_control_node_applies_uniform_scaling() -> void:
	print("TEST: Scale Control Node - Uniform Scaling")
	var control = Control.new()
	control.size = Vector2(100, 100)
	var scale_factor = 1.5
	
	UIScaler.scale_control_node(control, scale_factor)
	
	assert(control.scale.x == scale_factor, "Scale X should be %s" % scale_factor)
	assert(control.scale.y == scale_factor, "Scale Y should be %s" % scale_factor)
	
	control.free()
	print("  ✓ Uniform scaling applied correctly\n")

func test_scale_control_node_preserves_aspect_ratio() -> void:
	print("TEST: Scale Control Node - Aspect Ratio Preservation")
	var control = Control.new()
	control.size = Vector2(200, 100)  # 2:1 aspect ratio
	var original_ratio = control.size.x / control.size.y
	var scale_factor = 1.5
	
	UIScaler.scale_control_node(control, scale_factor)
	
	var scaled_size = control.size * control.scale
	var new_ratio = scaled_size.x / scaled_size.y
	assert(abs(new_ratio - original_ratio) < 0.001, "Aspect ratio should be preserved")
	
	control.free()
	print("  ✓ Aspect ratio preserved\n")

func test_scale_control_node_with_different_scale_factors() -> void:
	print("TEST: Scale Control Node - Various Scale Factors")
	var test_cases = [1.0, 1.3, 1.5, 2.0, 0.5]
	
	for scale_factor in test_cases:
		var control = Control.new()
		control.size = Vector2(100, 100)
		
		UIScaler.scale_control_node(control, scale_factor)
		
		assert(control.scale.x == scale_factor, "Scale X should be %s" % scale_factor)
		assert(control.scale.y == scale_factor, "Scale Y should be %s" % scale_factor)
		
		control.free()
	
	print("  ✓ All scale factors applied correctly\n")

func test_scale_control_node_handles_null_node() -> void:
	print("TEST: Scale Control Node - Null Node Handling")
	UIScaler.scale_control_node(null, 1.5)
	print("  ✓ Null node handled gracefully\n")

func test_scale_control_node_handles_zero_scale_factor() -> void:
	print("TEST: Scale Control Node - Zero Scale Factor")
	var control = Control.new()
	var original_scale = control.scale
	
	UIScaler.scale_control_node(control, 0.0)
	
	assert(control.scale == original_scale, "Scale should remain unchanged")
	
	control.free()
	print("  ✓ Zero scale factor rejected\n")

func test_scale_control_node_handles_negative_scale_factor() -> void:
	print("TEST: Scale Control Node - Negative Scale Factor")
	var control = Control.new()
	var original_scale = control.scale
	
	UIScaler.scale_control_node(control, -1.5)
	
	assert(control.scale == original_scale, "Scale should remain unchanged")
	
	control.free()
	print("  ✓ Negative scale factor rejected\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FONT SCALING TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_scale_font_increases_font_size() -> void:
	print("TEST: Scale Font - Increases Font Size")
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 16)
	var scale_factor = 1.4
	
	UIScaler.scale_font(label, scale_factor)
	
	var expected_size = int(16 * scale_factor)
	assert(label.get_theme_font_size("font_size") == expected_size, "Font size should be %s" % expected_size)
	
	label.free()
	print("  ✓ Font size scaled correctly\n")

func test_scale_font_with_default_font_size() -> void:
	print("TEST: Scale Font - Default Font Size")
	var label = Label.new()
	var scale_factor = 1.5
	
	UIScaler.scale_font(label, scale_factor)
	
	var font_size = label.get_theme_font_size("font_size")
	assert(font_size > 0, "Font size should be positive")
	
	label.free()
	print("  ✓ Default font size handled\n")

func test_scale_font_with_various_scale_factors() -> void:
	print("TEST: Scale Font - Various Scale Factors")
	var test_cases = [
		{"initial": 16, "factor": 1.3, "expected": 20},
		{"initial": 16, "factor": 1.4, "expected": 22},
		{"initial": 16, "factor": 1.5, "expected": 24},
		{"initial": 24, "factor": 1.5, "expected": 36},
	]
	
	for test_case in test_cases:
		var label = Label.new()
		label.add_theme_font_size_override("font_size", test_case.initial)
		
		UIScaler.scale_font(label, test_case.factor)
		
		assert(label.get_theme_font_size("font_size") == test_case.expected, 
			"Font size should be %s" % test_case.expected)
		
		label.free()
	
	print("  ✓ All font scale factors applied correctly\n")

func test_scale_font_handles_null_label() -> void:
	print("TEST: Scale Font - Null Label Handling")
	UIScaler.scale_font(null, 1.4)
	print("  ✓ Null label handled gracefully\n")

func test_scale_font_handles_zero_scale_factor() -> void:
	print("TEST: Scale Font - Zero Scale Factor")
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 16)
	
	UIScaler.scale_font(label, 0.0)
	
	assert(label.get_theme_font_size("font_size") == 16, "Font size should remain unchanged")
	
	label.free()
	print("  ✓ Zero scale factor rejected\n")

func test_scale_font_handles_negative_scale_factor() -> void:
	print("TEST: Scale Font - Negative Scale Factor")
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 16)
	
	UIScaler.scale_font(label, -1.4)
	
	assert(label.get_theme_font_size("font_size") == 16, "Font size should remain unchanged")
	
	label.free()
	print("  ✓ Negative scale factor rejected\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MINIMUM SIZE ENFORCEMENT TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_ensure_minimum_size_enforces_minimum() -> void:
	print("TEST: Ensure Minimum Size - Enforces Minimum")
	var control = Control.new()
	control.size = Vector2(50, 30)  # Too small
	var min_size = Vector2(80, 80)
	
	UIScaler.ensure_minimum_size(control, min_size)
	
	assert(control.custom_minimum_size.x >= min_size.x, "Custom minimum width should be at least %s" % min_size.x)
	assert(control.custom_minimum_size.y >= min_size.y, "Custom minimum height should be at least %s" % min_size.y)
	
	control.free()
	print("  ✓ Minimum size enforced\n")

func test_ensure_minimum_size_respects_existing_size() -> void:
	print("TEST: Ensure Minimum Size - Respects Existing Size")
	var control = Control.new()
	control.size = Vector2(100, 100)  # Already large enough
	var min_size = Vector2(80, 80)
	
	UIScaler.ensure_minimum_size(control, min_size)
	
	var effective_size = control.size * control.scale
	assert(effective_size.x >= min_size.x, "Effective width should be at least %s" % min_size.x)
	assert(effective_size.y >= min_size.y, "Effective height should be at least %s" % min_size.y)
	
	control.free()
	print("  ✓ Existing size respected\n")

func test_ensure_minimum_size_accounts_for_scale() -> void:
	print("TEST: Ensure Minimum Size - Accounts for Scale")
	var control = Control.new()
	control.size = Vector2(60, 60)
	control.scale = Vector2(1.5, 1.5)  # Effective size is 90x90
	var min_size = Vector2(80, 80)
	
	UIScaler.ensure_minimum_size(control, min_size)
	
	var effective_size = control.size * control.scale
	assert(effective_size.x >= min_size.x, "Effective width should be at least %s" % min_size.x)
	assert(effective_size.y >= min_size.y, "Effective height should be at least %s" % min_size.y)
	
	control.free()
	print("  ✓ Scale accounted for\n")

func test_ensure_minimum_size_with_button_requirements() -> void:
	print("TEST: Ensure Minimum Size - Button Requirements")
	var button = Button.new()
	button.size = Vector2(50, 30)
	var min_size = Vector2(100, 60)
	
	UIScaler.ensure_minimum_size(button, min_size)
	
	var effective_size = button.size * button.scale
	assert(effective_size.x >= min_size.x, "Button width should be at least %s" % min_size.x)
	assert(effective_size.y >= min_size.y, "Button height should be at least %s" % min_size.y)
	
	button.free()
	print("  ✓ Button requirements met\n")

func test_ensure_minimum_size_with_touch_target_requirements() -> void:
	print("TEST: Ensure Minimum Size - Touch Target Requirements")
	var control = Control.new()
	control.size = Vector2(40, 40)
	var min_size = Vector2(80, 80)
	
	UIScaler.ensure_minimum_size(control, min_size)
	
	var effective_size = control.size * control.scale
	assert(effective_size.x >= min_size.x, "Touch target width should be at least %s" % min_size.x)
	assert(effective_size.y >= min_size.y, "Touch target height should be at least %s" % min_size.y)
	
	control.free()
	print("  ✓ Touch target requirements met\n")

func test_ensure_minimum_size_handles_null_node() -> void:
	print("TEST: Ensure Minimum Size - Null Node Handling")
	UIScaler.ensure_minimum_size(null, Vector2(80, 80))
	print("  ✓ Null node handled gracefully\n")

func test_ensure_minimum_size_handles_negative_min_size() -> void:
	print("TEST: Ensure Minimum Size - Negative Min Size")
	var control = Control.new()
	var original_custom_min = control.custom_minimum_size
	
	UIScaler.ensure_minimum_size(control, Vector2(-10, -10))
	
	assert(control.custom_minimum_size == original_custom_min, "Custom minimum size should remain unchanged")
	
	control.free()
	print("  ✓ Negative min size rejected\n")

func test_ensure_minimum_size_handles_zero_min_size() -> void:
	print("TEST: Ensure Minimum Size - Zero Min Size")
	var control = Control.new()
	control.size = Vector2(50, 50)
	
	UIScaler.ensure_minimum_size(control, Vector2(0, 0))
	
	assert(control.custom_minimum_size == Vector2(0, 0), "Zero minimum should not enforce any constraint")
	
	control.free()
	print("  ✓ Zero min size handled\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTEGRATION TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_combined_scaling_and_minimum_size() -> void:
	print("TEST: Integration - Combined Scaling and Minimum Size")
	var button = Button.new()
	button.size = Vector2(50, 30)
	
	UIScaler.scale_control_node(button, 1.5)
	UIScaler.ensure_minimum_size(button, Vector2(100, 60))
	
	assert(button.scale.x == 1.5, "Scale X should be 1.5")
	assert(button.scale.y == 1.5, "Scale Y should be 1.5")
	
	var effective_size = button.size * button.scale
	assert(effective_size.x >= 100.0, "Effective width should be at least 100")
	assert(effective_size.y >= 60.0, "Effective height should be at least 60")
	
	button.free()
	print("  ✓ Combined operations work correctly\n")

func test_scaling_with_font_and_size_enforcement() -> void:
	print("TEST: Integration - Complete Mobile Transformation")
	var label = Label.new()
	label.size = Vector2(40, 20)
	label.add_theme_font_size_override("font_size", 16)
	
	UIScaler.scale_control_node(label, 1.5)
	UIScaler.scale_font(label, 1.4)
	UIScaler.ensure_minimum_size(label, Vector2(80, 80))
	
	assert(label.scale.x == 1.5, "Scale should be 1.5")
	assert(label.get_theme_font_size("font_size") == 22, "Font size should be 22")
	
	var effective_size = label.size * label.scale
	assert(effective_size.x >= 80.0, "Effective width should be at least 80")
	assert(effective_size.y >= 80.0, "Effective height should be at least 80")
	
	label.free()
	print("  ✓ Complete mobile transformation successful\n")

