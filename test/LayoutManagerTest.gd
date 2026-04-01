extends Node

## ═══════════════════════════════════════════════════════════════════
## LAYOUT MANAGER TEST SUITE
## ═══════════════════════════════════════════════════════════════════
## Tests for LayoutManager helper class
## Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.6, 2.2, 2.3
## ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("LAYOUT MANAGER TEST SUITE")
	print("=".repeat(60) + "\n")
	
	# Orientation-based layout tests
	test_reorganize_for_portrait_orientation()
	test_reorganize_for_landscape_orientation()
	test_reorganize_vbox_container_for_portrait()
	test_reorganize_vbox_container_for_landscape()
	test_reorganize_grid_container_for_portrait()
	test_reorganize_grid_container_for_landscape()
	test_reorganize_handles_null_container()
	
	# Safe area margin tests
	test_apply_safe_area_margins_to_margin_container()
	test_apply_safe_area_margins_to_control()
	test_apply_safe_area_margins_with_all_margins()
	test_apply_safe_area_margins_with_partial_margins()
	test_apply_safe_area_margins_handles_null_node()
	test_apply_safe_area_margins_handles_null_margins()
	
	# Button spacing tests
	test_apply_button_spacing_vertical_default()
	test_apply_button_spacing_vertical_custom()
	test_apply_button_spacing_vertical_to_vbox()
	test_apply_button_spacing_vertical_to_grid()
	test_apply_button_spacing_vertical_handles_null()
	test_apply_button_spacing_vertical_handles_negative()
	
	test_apply_button_spacing_horizontal_default()
	test_apply_button_spacing_horizontal_custom()
	test_apply_button_spacing_horizontal_to_hbox()
	test_apply_button_spacing_horizontal_to_grid()
	test_apply_button_spacing_horizontal_handles_null()
	test_apply_button_spacing_horizontal_handles_negative()
	
	# Integration tests
	test_complete_portrait_layout_setup()
	test_complete_landscape_layout_setup()
	test_orientation_change_workflow()
	
	print("\n" + "=".repeat(60))
	print("ALL TESTS COMPLETED")
	print("=".repeat(60) + "\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ORIENTATION-BASED LAYOUT TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_reorganize_for_portrait_orientation() -> void:
	print("TEST: Reorganize for Portrait Orientation")
	var vbox = VBoxContainer.new()
	
	LayoutManager.reorganize_for_orientation(vbox, true)
	
	assert(vbox.vertical == true, "VBoxContainer should be vertical in portrait")
	
	vbox.free()
	print("  ✓ Portrait orientation applied\n")

func test_reorganize_for_landscape_orientation() -> void:
	print("TEST: Reorganize for Landscape Orientation")
	var vbox = VBoxContainer.new()
	
	LayoutManager.reorganize_for_orientation(vbox, false)
	
	assert(vbox.vertical == false, "VBoxContainer should be horizontal in landscape")
	
	vbox.free()
	print("  ✓ Landscape orientation applied\n")

func test_reorganize_vbox_container_for_portrait() -> void:
	print("TEST: Reorganize VBoxContainer for Portrait")
	var vbox = VBoxContainer.new()
	vbox.vertical = false  # Start horizontal
	
	LayoutManager.reorganize_for_orientation(vbox, true)
	
	assert(vbox.vertical == true, "VBoxContainer should switch to vertical")
	
	vbox.free()
	print("  ✓ VBoxContainer reorganized for portrait\n")

func test_reorganize_vbox_container_for_landscape() -> void:
	print("TEST: Reorganize VBoxContainer for Landscape")
	var vbox = VBoxContainer.new()
	vbox.vertical = true  # Start vertical
	
	LayoutManager.reorganize_for_orientation(vbox, false)
	
	assert(vbox.vertical == false, "VBoxContainer should switch to horizontal")
	
	vbox.free()
	print("  ✓ VBoxContainer reorganized for landscape\n")

func test_reorganize_grid_container_for_portrait() -> void:
	print("TEST: Reorganize GridContainer for Portrait")
	var grid = GridContainer.new()
	grid.columns = 3
	
	LayoutManager.reorganize_for_orientation(grid, true)
	
	assert(grid.columns == 1, "GridContainer should have 1 column in portrait")
	
	grid.free()
	print("  ✓ GridContainer reorganized for portrait\n")

func test_reorganize_grid_container_for_landscape() -> void:
	print("TEST: Reorganize GridContainer for Landscape")
	var grid = GridContainer.new()
	grid.columns = 1
	
	# Add some children to test column calculation
	for i in range(6):
		var button = Button.new()
		grid.add_child(button)
	
	LayoutManager.reorganize_for_orientation(grid, false)
	
	assert(grid.columns >= 2, "GridContainer should have 2+ columns in landscape")
	
	grid.free()
	print("  ✓ GridContainer reorganized for landscape\n")

func test_reorganize_handles_null_container() -> void:
	print("TEST: Reorganize - Null Container Handling")
	LayoutManager.reorganize_for_orientation(null, true)
	print("  ✓ Null container handled gracefully\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SAFE AREA MARGIN TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_apply_safe_area_margins_to_margin_container() -> void:
	print("TEST: Apply Safe Area Margins to MarginContainer")
	var margin_container = MarginContainer.new()
	var margins = {
		"top": 40.0,
		"bottom": 20.0,
		"left": 10.0,
		"right": 10.0
	}
	
	LayoutManager.apply_safe_area_margins(margin_container, margins)
	
	assert(margin_container.get_theme_constant("margin_top") == 40, "Top margin should be 40")
	assert(margin_container.get_theme_constant("margin_bottom") == 20, "Bottom margin should be 20")
	assert(margin_container.get_theme_constant("margin_left") == 10, "Left margin should be 10")
	assert(margin_container.get_theme_constant("margin_right") == 10, "Right margin should be 10")
	
	margin_container.free()
	print("  ✓ Safe area margins applied to MarginContainer\n")

func test_apply_safe_area_margins_to_control() -> void:
	print("TEST: Apply Safe Area Margins to Control")
	var control = Control.new()
	var margins = {
		"top": 30.0,
		"bottom": 15.0,
		"left": 5.0,
		"right": 5.0
	}
	
	LayoutManager.apply_safe_area_margins(control, margins)
	
	assert(control.offset_top == 30.0, "Top offset should be 30")
	assert(control.offset_bottom == -15.0, "Bottom offset should be -15")
	assert(control.offset_left == 5.0, "Left offset should be 5")
	assert(control.offset_right == -5.0, "Right offset should be -5")
	
	control.free()
	print("  ✓ Safe area margins applied to Control\n")

func test_apply_safe_area_margins_with_all_margins() -> void:
	print("TEST: Apply Safe Area Margins - All Margins")
	var margin_container = MarginContainer.new()
	var margins = {
		"top": 50.0,
		"bottom": 30.0,
		"left": 20.0,
		"right": 20.0
	}
	
	LayoutManager.apply_safe_area_margins(margin_container, margins)
	
	assert(margin_container.get_theme_constant("margin_top") == 50, "Top margin should be 50")
	assert(margin_container.get_theme_constant("margin_bottom") == 30, "Bottom margin should be 30")
	assert(margin_container.get_theme_constant("margin_left") == 20, "Left margin should be 20")
	assert(margin_container.get_theme_constant("margin_right") == 20, "Right margin should be 20")
	
	margin_container.free()
	print("  ✓ All margins applied correctly\n")

func test_apply_safe_area_margins_with_partial_margins() -> void:
	print("TEST: Apply Safe Area Margins - Partial Margins")
	var margin_container = MarginContainer.new()
	var margins = {
		"top": 40.0,
		"left": 10.0
		# bottom and right missing
	}
	
	LayoutManager.apply_safe_area_margins(margin_container, margins)
	
	assert(margin_container.get_theme_constant("margin_top") == 40, "Top margin should be 40")
	assert(margin_container.get_theme_constant("margin_bottom") == 0, "Bottom margin should default to 0")
	assert(margin_container.get_theme_constant("margin_left") == 10, "Left margin should be 10")
	assert(margin_container.get_theme_constant("margin_right") == 0, "Right margin should default to 0")
	
	margin_container.free()
	print("  ✓ Partial margins handled with defaults\n")

func test_apply_safe_area_margins_handles_null_node() -> void:
	print("TEST: Apply Safe Area Margins - Null Node Handling")
	var margins = {"top": 20.0, "bottom": 20.0, "left": 10.0, "right": 10.0}
	LayoutManager.apply_safe_area_margins(null, margins)
	print("  ✓ Null node handled gracefully\n")

func test_apply_safe_area_margins_handles_null_margins() -> void:
	print("TEST: Apply Safe Area Margins - Empty Margins Handling")
	var margin_container = MarginContainer.new()
	var empty_margins = {}
	LayoutManager.apply_safe_area_margins(margin_container, empty_margins)
	
	# Should apply default values (0) for all margins
	assert(margin_container.get_theme_constant("margin_top") == 0, "Top margin should default to 0")
	assert(margin_container.get_theme_constant("margin_bottom") == 0, "Bottom margin should default to 0")
	assert(margin_container.get_theme_constant("margin_left") == 0, "Left margin should default to 0")
	assert(margin_container.get_theme_constant("margin_right") == 0, "Right margin should default to 0")
	
	margin_container.free()
	print("  ✓ Empty margins handled gracefully\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUTTON SPACING TESTS - VERTICAL
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_apply_button_spacing_vertical_default() -> void:
	print("TEST: Apply Button Spacing Vertical - Default (20px)")
	var vbox = VBoxContainer.new()
	
	LayoutManager.apply_button_spacing_vertical(vbox)
	
	assert(vbox.get_theme_constant("separation") == 20, "Vertical spacing should be 20")
	
	vbox.free()
	print("  ✓ Default vertical spacing applied\n")

func test_apply_button_spacing_vertical_custom() -> void:
	print("TEST: Apply Button Spacing Vertical - Custom Value")
	var vbox = VBoxContainer.new()
	
	LayoutManager.apply_button_spacing_vertical(vbox, 30.0)
	
	assert(vbox.get_theme_constant("separation") == 30, "Vertical spacing should be 30")
	
	vbox.free()
	print("  ✓ Custom vertical spacing applied\n")

func test_apply_button_spacing_vertical_to_vbox() -> void:
	print("TEST: Apply Button Spacing Vertical to VBoxContainer")
	var vbox = VBoxContainer.new()
	
	LayoutManager.apply_button_spacing_vertical(vbox, 25.0)
	
	assert(vbox.get_theme_constant("separation") == 25, "VBox separation should be 25")
	
	vbox.free()
	print("  ✓ Vertical spacing applied to VBoxContainer\n")

func test_apply_button_spacing_vertical_to_grid() -> void:
	print("TEST: Apply Button Spacing Vertical to GridContainer")
	var grid = GridContainer.new()
	
	LayoutManager.apply_button_spacing_vertical(grid, 20.0)
	
	assert(grid.get_theme_constant("v_separation") == 20, "Grid v_separation should be 20")
	
	grid.free()
	print("  ✓ Vertical spacing applied to GridContainer\n")

func test_apply_button_spacing_vertical_handles_null() -> void:
	print("TEST: Apply Button Spacing Vertical - Null Container")
	LayoutManager.apply_button_spacing_vertical(null, 20.0)
	print("  ✓ Null container handled gracefully\n")

func test_apply_button_spacing_vertical_handles_negative() -> void:
	print("TEST: Apply Button Spacing Vertical - Negative Value")
	var vbox = VBoxContainer.new()
	var original_separation = vbox.get_theme_constant("separation")
	
	LayoutManager.apply_button_spacing_vertical(vbox, -10.0)
	
	# Should not apply negative spacing
	assert(vbox.get_theme_constant("separation") == original_separation, "Spacing should remain unchanged")
	
	vbox.free()
	print("  ✓ Negative spacing rejected\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUTTON SPACING TESTS - HORIZONTAL
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_apply_button_spacing_horizontal_default() -> void:
	print("TEST: Apply Button Spacing Horizontal - Default (15px)")
	var hbox = HBoxContainer.new()
	
	LayoutManager.apply_button_spacing_horizontal(hbox)
	
	assert(hbox.get_theme_constant("separation") == 15, "Horizontal spacing should be 15")
	
	hbox.free()
	print("  ✓ Default horizontal spacing applied\n")

func test_apply_button_spacing_horizontal_custom() -> void:
	print("TEST: Apply Button Spacing Horizontal - Custom Value")
	var hbox = HBoxContainer.new()
	
	LayoutManager.apply_button_spacing_horizontal(hbox, 25.0)
	
	assert(hbox.get_theme_constant("separation") == 25, "Horizontal spacing should be 25")
	
	hbox.free()
	print("  ✓ Custom horizontal spacing applied\n")

func test_apply_button_spacing_horizontal_to_hbox() -> void:
	print("TEST: Apply Button Spacing Horizontal to HBoxContainer")
	var hbox = HBoxContainer.new()
	
	LayoutManager.apply_button_spacing_horizontal(hbox, 20.0)
	
	assert(hbox.get_theme_constant("separation") == 20, "HBox separation should be 20")
	
	hbox.free()
	print("  ✓ Horizontal spacing applied to HBoxContainer\n")

func test_apply_button_spacing_horizontal_to_grid() -> void:
	print("TEST: Apply Button Spacing Horizontal to GridContainer")
	var grid = GridContainer.new()
	
	LayoutManager.apply_button_spacing_horizontal(grid, 15.0)
	
	assert(grid.get_theme_constant("h_separation") == 15, "Grid h_separation should be 15")
	
	grid.free()
	print("  ✓ Horizontal spacing applied to GridContainer\n")

func test_apply_button_spacing_horizontal_handles_null() -> void:
	print("TEST: Apply Button Spacing Horizontal - Null Container")
	LayoutManager.apply_button_spacing_horizontal(null, 15.0)
	print("  ✓ Null container handled gracefully\n")

func test_apply_button_spacing_horizontal_handles_negative() -> void:
	print("TEST: Apply Button Spacing Horizontal - Negative Value")
	var hbox = HBoxContainer.new()
	var original_separation = hbox.get_theme_constant("separation")
	
	LayoutManager.apply_button_spacing_horizontal(hbox, -10.0)
	
	# Should not apply negative spacing
	assert(hbox.get_theme_constant("separation") == original_separation, "Spacing should remain unchanged")
	
	hbox.free()
	print("  ✓ Negative spacing rejected\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTEGRATION TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_complete_portrait_layout_setup() -> void:
	print("TEST: Integration - Complete Portrait Layout Setup")
	var vbox = VBoxContainer.new()
	var margins = {"top": 40.0, "bottom": 20.0, "left": 10.0, "right": 10.0}
	
	# Apply portrait layout
	LayoutManager.reorganize_for_orientation(vbox, true)
	LayoutManager.apply_safe_area_margins(vbox, margins)
	
	assert(vbox.vertical == true, "Should be vertical layout")
	assert(vbox.get_theme_constant("separation") == 20, "Should have vertical spacing")
	
	vbox.free()
	print("  ✓ Complete portrait layout setup successful\n")

func test_complete_landscape_layout_setup() -> void:
	print("TEST: Integration - Complete Landscape Layout Setup")
	var hbox = HBoxContainer.new()
	var margins = {"top": 20.0, "bottom": 20.0, "left": 10.0, "right": 10.0}
	
	# Apply landscape layout
	LayoutManager.reorganize_for_orientation(hbox, false)
	LayoutManager.apply_safe_area_margins(hbox, margins)
	
	assert(hbox.vertical == false, "Should be horizontal layout")
	assert(hbox.get_theme_constant("separation") == 15, "Should have horizontal spacing")
	
	hbox.free()
	print("  ✓ Complete landscape layout setup successful\n")

func test_orientation_change_workflow() -> void:
	print("TEST: Integration - Orientation Change Workflow")
	var vbox = VBoxContainer.new()
	
	# Start in portrait
	LayoutManager.reorganize_for_orientation(vbox, true)
	assert(vbox.vertical == true, "Should start in vertical layout")
	assert(vbox.get_theme_constant("separation") == 20, "Should have vertical spacing")
	
	# Switch to landscape
	LayoutManager.reorganize_for_orientation(vbox, false)
	assert(vbox.vertical == false, "Should switch to horizontal layout")
	assert(vbox.get_theme_constant("separation") == 15, "Should have horizontal spacing")
	
	# Switch back to portrait
	LayoutManager.reorganize_for_orientation(vbox, true)
	assert(vbox.vertical == true, "Should switch back to vertical layout")
	assert(vbox.get_theme_constant("separation") == 20, "Should have vertical spacing again")
	
	vbox.free()
	print("  ✓ Orientation change workflow successful\n")
