extends Node

## ═══════════════════════════════════════════════════════════════════
## MOBILE CONFIG TEST
## ═══════════════════════════════════════════════════════════════════
## Unit tests for MobileConfig data model
## Tests loading, saving, and default values
## ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("MOBILE CONFIG TEST SUITE")
	print("=".repeat(60) + "\n")
	
	test_default_values()
	test_save_and_load()
	test_load_nonexistent_file()
	test_partial_config_file()
	
	print("\n" + "=".repeat(60))
	print("ALL TESTS COMPLETED")
	print("=".repeat(60) + "\n")

func test_default_values() -> void:
	print("TEST: Default Values")
	var config = MobileConfig.new()
	
	# Verify scaling factors
	assert(config.ui_scale == 1.5, "ui_scale should be 1.5")
	assert(config.font_scale == 1.4, "font_scale should be 1.4")
	assert(config.game_object_scale == 1.4, "game_object_scale should be 1.4")
	assert(config.collectible_scale == 1.3, "collectible_scale should be 1.3")
	
	# Verify minimum sizes
	assert(config.button_min_size == Vector2(100, 60), "button_min_size should be 100x60")
	assert(config.touch_target_min_size == Vector2(80, 80), "touch_target_min_size should be 80x80")
	
	# Verify spacing
	assert(config.button_spacing_vertical == 20.0, "button_spacing_vertical should be 20.0")
	assert(config.button_spacing_horizontal == 15.0, "button_spacing_horizontal should be 15.0")
	assert(config.safe_area_margin == 20.0, "safe_area_margin should be 20.0")
	assert(config.edge_dead_zone == 15.0, "edge_dead_zone should be 15.0")
	
	# Verify performance settings
	assert(config.particle_reduction == 0.4, "particle_reduction should be 0.4")
	assert(config.max_tweens == 10, "max_tweens should be 10")
	assert(config.target_fps == 30, "target_fps should be 30")
	
	# Verify gameplay adjustments
	assert(config.game_speed_reduction == 0.15, "game_speed_reduction should be 0.15")
	assert(config.timing_window_increase == 0.2, "timing_window_increase should be 0.2")
	assert(config.spawn_rate_reduction == 0.1, "spawn_rate_reduction should be 0.1")
	assert(config.drag_smoothing_increase == 1.5, "drag_smoothing_increase should be 1.5")
	assert(config.visual_indicator_scale == 1.3, "visual_indicator_scale should be 1.3")
	
	print("  ✓ All default values correct\n")

func test_save_and_load() -> void:
	print("TEST: Save and Load")
	var config1 = MobileConfig.new()
	
	# Modify some values
	config1.ui_scale = 2.0
	config1.font_scale = 1.8
	config1.button_min_size = Vector2(120, 80)
	config1.max_tweens = 15
	config1.game_speed_reduction = 0.2
	
	# Save to file
	var test_path = "user://test_mobile_config.cfg"
	var save_result = config1.save_to_file(test_path)
	assert(save_result == true, "Save should succeed")
	
	# Load into new config
	var config2 = MobileConfig.new()
	var load_result = config2.load_from_file(test_path)
	assert(load_result == true, "Load should succeed")
	
	# Verify loaded values match saved values
	assert(config2.ui_scale == 2.0, "ui_scale should be 2.0")
	assert(config2.font_scale == 1.8, "font_scale should be 1.8")
	assert(config2.button_min_size == Vector2(120, 80), "button_min_size should be 120x80")
	assert(config2.max_tweens == 15, "max_tweens should be 15")
	assert(config2.game_speed_reduction == 0.2, "game_speed_reduction should be 0.2")
	
	# Verify unmodified values remain at defaults
	assert(config2.collectible_scale == 1.3, "collectible_scale should remain 1.3")
	assert(config2.edge_dead_zone == 15.0, "edge_dead_zone should remain 15.0")
	
	# Clean up
	DirAccess.remove_absolute(test_path)
	
	print("  ✓ Save and load working correctly\n")

func test_load_nonexistent_file() -> void:
	print("TEST: Load Nonexistent File")
	var config = MobileConfig.new()
	
	var load_result = config.load_from_file("user://nonexistent_file.cfg")
	assert(load_result == false, "Load should fail for nonexistent file")
	
	# Verify defaults are preserved
	assert(config.ui_scale == 1.5, "ui_scale should remain at default")
	assert(config.font_scale == 1.4, "font_scale should remain at default")
	
	print("  ✓ Gracefully handles nonexistent files\n")

func test_partial_config_file() -> void:
	print("TEST: Partial Config File")
	
	# Create a config file with only some values
	var partial_config = ConfigFile.new()
	partial_config.set_value("scaling", "ui_scale", 1.8)
	partial_config.set_value("performance", "target_fps", 60)
	
	var test_path = "user://test_partial_config.cfg"
	partial_config.save(test_path)
	
	# Load into MobileConfig
	var config = MobileConfig.new()
	var load_result = config.load_from_file(test_path)
	assert(load_result == true, "Load should succeed")
	
	# Verify specified values are loaded
	assert(config.ui_scale == 1.8, "ui_scale should be 1.8")
	assert(config.target_fps == 60, "target_fps should be 60")
	
	# Verify unspecified values remain at defaults
	assert(config.font_scale == 1.4, "font_scale should remain at default")
	assert(config.max_tweens == 10, "max_tweens should remain at default")
	assert(config.button_min_size == Vector2(100, 60), "button_min_size should remain at default")
	
	# Clean up
	DirAccess.remove_absolute(test_path)
	
	print("  ✓ Partial config files handled correctly\n")
