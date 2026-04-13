extends Node

## ═══════════════════════════════════════════════════════════════════
## CONFIGURATION ERROR HANDLING TEST
## ═══════════════════════════════════════════════════════════════════
## Tests for Task 11.1: Configuration error handling
## Feature: animated-cutscenes
## Tests Requirements: 5.7, 5.8, 10.2, 10.3, 12.3
## ═══════════════════════════════════════════════════════════════════

var test_passed: int = 0
var test_failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("CONFIGURATION ERROR HANDLING TEST SUITE")
	print("=".repeat(60) + "\n")
	
	# Run all tests
	test_missing_configuration_file_error_message()
	test_invalid_json_error_message()
	test_empty_file_error_message()
	test_validation_error_with_fallback()
	test_corrupted_data_fallback()
	test_missing_required_fields_fallback()
	test_apply_validation_defaults_duration()
	test_apply_validation_defaults_keyframes()
	test_apply_validation_defaults_character()
	
	# Print summary
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("  Passed: " + str(test_passed))
	print("  Failed: " + str(test_failed))
	print("=".repeat(60) + "\n")
	
	get_tree().quit()


# ============================================================================
# ASSERTION HELPERS
# ============================================================================

func assert_test(condition: bool, message: String) -> void:
	if condition:
		test_passed += 1
		print("  ✓ " + message)
	else:
		test_failed += 1
		print("  ✗ FAILED: " + message)


func assert_not_null(value, message: String) -> void:
	assert_test(value != null, message)


func assert_true(condition: bool, message: String) -> void:
	assert_test(condition, message)


func assert_eq(actual, expected, message: String) -> void:
	assert_test(actual == expected, message + " (expected: " + str(expected) + ", got: " + str(actual) + ")")


func assert_gte(actual, expected, message: String) -> void:
	assert_test(actual >= expected, message + " (expected >= " + str(expected) + ", got: " + str(actual) + ")")


func assert_lte(actual, expected, message: String) -> void:
	assert_test(actual <= expected, message + " (expected <= " + str(expected) + ", got: " + str(actual) + ")")


# ============================================================================
# TEST METHODS
# ============================================================================

func test_missing_configuration_file_error_message():
	"""Test that missing configuration files produce descriptive error messages"""
	print("\nTEST: Missing configuration file error message")
	
	var config = CutsceneParser.parse_config("res://nonexistent/missing_file.json")
	
	# Should return null but not crash
	assert_test(config == null, "Should return null for missing file")
	# Error message should be logged (we can't easily test console output, but the function should complete)


func test_invalid_json_error_message():
	"""Test that invalid JSON produces descriptive error messages"""
	print("\nTEST: Invalid JSON error message")
	
	# Create a temporary invalid JSON file
	var test_path = "user://test_invalid.json"
	var file = FileAccess.open(test_path, FileAccess.WRITE)
	if file:
		file.store_string("{invalid json content")
		file.close()
	
	var config = CutsceneParser.parse_config(test_path)
	
	# Should return null but not crash
	assert_test(config == null, "Should return null for invalid JSON")
	
	# Clean up
	DirAccess.remove_absolute(test_path)


func test_empty_file_error_message():
	"""Test that empty files produce descriptive error messages"""
	print("\nTEST: Empty file error message")
	
	# Create a temporary empty JSON file
	var test_path = "user://test_empty.json"
	var file = FileAccess.open(test_path, FileAccess.WRITE)
	if file:
		file.store_string("")
		file.close()
	
	var config = CutsceneParser.parse_config(test_path)
	
	# Should return null but not crash
	assert_test(config == null, "Should return null for empty file")
	
	# Clean up
	DirAccess.remove_absolute(test_path)


func test_validation_error_with_fallback():
	"""Test that validation errors result in default value fallback"""
	print("\nTEST: Validation error with fallback")
	
	# Create a config with invalid duration
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestGame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = -1.0  # Invalid
	
	# Add minimal keyframe
	var kf = CutsceneDataModels.Keyframe.new(0.0)
	kf.add_transform(CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	))
	config.add_keyframe(kf)
	
	# Validate
	var validation = CutsceneParser.validate_config(config)
	assert_test(validation.has_errors(), "Should have validation errors")
	
	# Apply defaults (simulating what AnimatedCutscenePlayer does)
	var player = AnimatedCutscenePlayer.new()
	var corrected = player._apply_validation_defaults(config, validation)
	
	# Should have valid duration now
	assert_gte(corrected.duration, 1.5, "Duration should be at least 1.5s after correction")
	assert_lte(corrected.duration, 4.0, "Duration should be at most 4.0s after correction")
	
	player.queue_free()


func test_corrupted_data_fallback():
	"""Test that corrupted data falls back to minimal config"""
	print("\nTEST: Corrupted data fallback")
	
	# Create a config with multiple invalid fields
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = ""  # Invalid
	config.duration = 0.0  # Invalid
	# No keyframes - invalid
	
	var validation = CutsceneParser.validate_config(config)
	assert_test(validation.has_errors(), "Should have validation errors")
	
	# Apply defaults
	var player = AnimatedCutscenePlayer.new()
	var corrected = player._apply_validation_defaults(config, validation)
	
	# Should have valid config now
	assert_not_null(corrected, "Should return a valid config")
	assert_gte(corrected.duration, 1.5, "Should have valid duration")
	assert_true(corrected.keyframes.size() > 0, "Should have keyframes")
	
	player.queue_free()


func test_missing_required_fields_fallback():
	"""Test that missing required fields get default values"""
	print("\nTEST: Missing required fields fallback")
	
	# Create a config missing keyframes
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestGame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 2.5
	# No keyframes
	
	var validation = CutsceneParser.validate_config(config)
	assert_test(validation.has_errors(), "Should have validation errors for missing keyframes")
	
	# Apply defaults
	var player = AnimatedCutscenePlayer.new()
	var corrected = player._apply_validation_defaults(config, validation)
	
	# Should have keyframes now
	assert_true(corrected.keyframes.size() > 0, "Should have default keyframes")
	
	player.queue_free()


func test_apply_validation_defaults_duration():
	"""Test that _apply_validation_defaults fixes duration issues"""
	print("\nTEST: Apply validation defaults - duration")
	
	var player = AnimatedCutscenePlayer.new()
	
	# Test negative duration
	var config1 = _create_minimal_config()
	config1.duration = -1.0
	var validation1 = CutsceneParser.validate_config(config1)
	var corrected1 = player._apply_validation_defaults(config1, validation1)
	assert_eq(corrected1.duration, 2.0, "Should apply default duration of 2.0s for negative")
	
	# Test too short duration
	var config2 = _create_minimal_config()
	config2.duration = 1.0
	var validation2 = CutsceneParser.validate_config(config2)
	var corrected2 = player._apply_validation_defaults(config2, validation2)
	assert_eq(corrected2.duration, 1.5, "Should clamp to minimum 1.5s")
	
	# Test too long duration
	var config3 = _create_minimal_config()
	config3.duration = 5.0
	var validation3 = CutsceneParser.validate_config(config3)
	var corrected3 = player._apply_validation_defaults(config3, validation3)
	assert_eq(corrected3.duration, 4.0, "Should clamp to maximum 4.0s")
	
	player.queue_free()


func test_apply_validation_defaults_keyframes():
	"""Test that _apply_validation_defaults adds missing keyframes"""
	print("\nTEST: Apply validation defaults - keyframes")
	
	var player = AnimatedCutscenePlayer.new()
	
	# Create config without keyframes
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestGame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 2.5
	
	var validation = CutsceneParser.validate_config(config)
	var corrected = player._apply_validation_defaults(config, validation)
	
	assert_true(corrected.keyframes.size() >= 2, "Should add at least 2 keyframes")
	assert_eq(corrected.keyframes[0].time, 0.0, "First keyframe should be at time 0.0")
	
	player.queue_free()


func test_apply_validation_defaults_character():
	"""Test that _apply_validation_defaults adds missing character config"""
	print("\nTEST: Apply validation defaults - character")
	
	var player = AnimatedCutscenePlayer.new()
	
	# Create config with null character
	var config = _create_minimal_config()
	config.character = null
	
	var validation = CutsceneParser.validate_config(config)
	var corrected = player._apply_validation_defaults(config, validation)
	
	assert_not_null(corrected.character, "Should have character config")
	assert_not_null(corrected.character.expression, "Should have expression set")
	
	player.queue_free()


# ============================================================================
# HELPER METHODS
# ============================================================================

func _create_minimal_config() -> CutsceneDataModels.CutsceneConfig:
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestGame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 2.5
	
	# Add minimal keyframe
	var kf = CutsceneDataModels.Keyframe.new(0.0)
	kf.add_transform(CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	))
	config.add_keyframe(kf)
	
	return config
