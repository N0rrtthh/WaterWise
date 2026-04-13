extends Node

## ═══════════════════════════════════════════════════════════════════
## CUTSCENE PARSER TEST
## ═══════════════════════════════════════════════════════════════════
## Unit tests for CutsceneParser
## Feature: animated-cutscenes
## Tests Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 10.1, 10.2, 10.3, 10.4, 10.5
## ═══════════════════════════════════════════════════════════════════

var test_config_dir = "user://test_cutscenes/"
var test_passed: int = 0
var test_failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("CUTSCENE PARSER TEST SUITE")
	print("=".repeat(60) + "\n")
	
	# Create test data directory
	DirAccess.make_dir_recursive_absolute(test_config_dir)
	
	# Run all tests
	test_parse_dict_with_valid_config()
	test_parse_dict_with_empty_dictionary()
	test_parse_config_with_missing_file()
	test_parse_config_with_invalid_extension()
	test_parse_json_file_with_valid_config()
	test_parse_json_file_with_invalid_json()
	test_validate_config_with_valid_config()
	test_validate_config_with_null_config()
	test_validate_config_with_negative_duration()
	test_validate_config_with_duration_too_short()
	test_validate_config_with_duration_too_long()
	test_validate_config_intro_duration_bounds()
	test_validate_config_win_duration_bounds()
	test_validate_config_with_empty_minigame_key()
	test_validate_config_with_no_keyframes()
	test_validate_config_with_keyframe_negative_time()
	test_validate_config_with_keyframe_exceeding_duration()
	test_validate_config_with_keyframes_out_of_order()
	test_validate_config_with_keyframe_no_transforms()
	test_validate_config_with_invalid_position_transform()
	test_validate_config_with_invalid_scale_transform()
	test_validate_config_with_particle_negative_time()
	test_validate_config_with_particle_exceeding_duration()
	test_validate_config_with_invalid_particle_density()
	test_validate_config_with_audio_cue_negative_time()
	test_validate_config_with_audio_cue_empty_sound()
	test_pretty_print_with_valid_config()
	test_pretty_print_with_null_config()
	test_pretty_print_preserves_all_data()
	test_round_trip_parse_dict_to_dict()
	
	# Clean up test files
	_cleanup_test_files()
	
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


func assert_eq(actual, expected, message: String) -> void:
	assert_test(actual == expected, message + " (expected: " + str(expected) + ", got: " + str(actual) + ")")


func assert_ne(actual, unexpected, message: String) -> void:
	assert_test(actual != unexpected, message)


func assert_not_null(value, message: String) -> void:
	assert_test(value != null, message)


func assert_null(value, message: String) -> void:
	assert_test(value == null, message)


func assert_true(condition: bool, message: String) -> void:
	assert_test(condition, message)


func assert_false(condition: bool, message: String) -> void:
	assert_test(not condition, message)


# ============================================================================
# TEST METHODS
# ============================================================================

func test_parse_dict_with_valid_config():
	print("\nTEST: Parse dictionary with valid config")
	var config_dict = _create_valid_config_dict()
	var config = CutsceneParser.parse_dict(config_dict)
	
	assert_not_null(config, "Should parse valid dictionary")
	assert_eq(config.minigame_key, "TestGame", "Should preserve minigame key")
	assert_eq(config.duration, 2.5, "Should preserve duration")
	assert_eq(config.cutscene_type, CutsceneTypes.CutsceneType.WIN, "Should parse cutscene type")
	assert_eq(config.keyframes.size(), 2, "Should parse all keyframes")


func test_parse_dict_with_empty_dictionary():
	print("\nTEST: Parse empty dictionary")
	var config = CutsceneParser.parse_dict({})
	
	assert_null(config, "Should return null for empty dictionary")


func test_parse_config_with_missing_file():
	print("\nTEST: Parse config with missing file")
	var config = CutsceneParser.parse_config("res://nonexistent/file.json")
	
	assert_null(config, "Should return null for missing file")


func test_parse_config_with_invalid_extension():
	print("\nTEST: Parse config with invalid extension")
	var config = CutsceneParser.parse_config("res://test/file.txt")
	
	assert_null(config, "Should return null for unsupported file extension")


func test_parse_json_file_with_valid_config():
	print("\nTEST: Parse JSON file with valid config")
	var json_path = test_config_dir + "valid_config.json"
	_create_test_json_file(json_path, _create_valid_config_dict())
	
	var config = CutsceneParser.parse_config(json_path)
	
	assert_not_null(config, "Should parse valid JSON file")
	assert_eq(config.minigame_key, "TestGame", "Should preserve minigame key")
	assert_eq(config.duration, 2.5, "Should preserve duration")


func test_parse_json_file_with_invalid_json():
	print("\nTEST: Parse JSON file with invalid JSON")
	var json_path = test_config_dir + "invalid.json"
	_create_invalid_json_file(json_path)
	
	var config = CutsceneParser.parse_config(json_path)
	
	assert_null(config, "Should return null for invalid JSON")


func test_validate_config_with_valid_config():
	print("\nTEST: Validate config with valid config")
	var config = _create_valid_cutscene_config()
	var result = CutsceneParser.validate_config(config)
	
	assert_true(result.is_valid, "Valid config should pass validation")
	assert_eq(result.errors.size(), 0, "Valid config should have no errors")


func test_validate_config_with_null_config():
	print("\nTEST: Validate null config")
	var result = CutsceneParser.validate_config(null)
	
	assert_false(result.is_valid, "Null config should fail validation")
	assert_true(result.errors.size() > 0, "Should have error messages")


func test_validate_config_with_negative_duration():
	print("\nTEST: Validate config with negative duration")
	var config = _create_valid_cutscene_config()
	config.duration = -1.0
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Negative duration should fail validation")
	assert_true(_has_error_containing(result, "Duration must be greater than 0"), "Should have duration error")


func test_validate_config_with_duration_too_short():
	print("\nTEST: Validate config with duration too short")
	var config = _create_valid_cutscene_config()
	config.duration = 1.0
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Duration below minimum should fail validation")
	assert_true(_has_error_containing(result, "too short"), "Should have duration too short error")


func test_validate_config_with_duration_too_long():
	print("\nTEST: Validate config with duration too long")
	var config = _create_valid_cutscene_config()
	config.duration = 5.0
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Duration above maximum should fail validation")
	assert_true(_has_error_containing(result, "too long"), "Should have duration too long error")


func test_validate_config_intro_duration_bounds():
	print("\nTEST: Validate intro cutscene duration bounds")
	var config = _create_valid_cutscene_config()
	config.cutscene_type = CutsceneTypes.CutsceneType.INTRO
	config.duration = 3.0  # Outside 1.5-2.5s range
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Intro duration outside bounds should fail")
	assert_true(_has_error_containing(result, "1.5-2.5s"), "Should mention intro duration bounds")


func test_validate_config_win_duration_bounds():
	print("\nTEST: Validate win cutscene duration bounds")
	var config = _create_valid_cutscene_config()
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 1.8  # Outside 2.0-3.0s range
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Win duration outside bounds should fail")
	assert_true(_has_error_containing(result, "2.0-3.0s"), "Should mention win duration bounds")


func test_validate_config_with_empty_minigame_key():
	print("\nTEST: Validate config with empty minigame key")
	var config = _create_valid_cutscene_config()
	config.minigame_key = ""
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Empty minigame key should fail validation")
	assert_true(_has_error_containing(result, "Minigame key"), "Should have minigame key error")


func test_validate_config_with_no_keyframes():
	print("\nTEST: Validate config with no keyframes")
	var config = _create_valid_cutscene_config()
	config.keyframes.clear()
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Config without keyframes should fail validation")
	assert_true(_has_error_containing(result, "at least one keyframe"), "Should have keyframe error")


func test_validate_config_with_keyframe_negative_time():
	print("\nTEST: Validate config with keyframe negative time")
	var config = _create_valid_cutscene_config()
	config.keyframes[0].time = -0.5
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Negative keyframe time should fail validation")
	assert_true(_has_error_containing(result, "negative time"), "Should have negative time error")


func test_validate_config_with_keyframe_exceeding_duration():
	print("\nTEST: Validate config with keyframe exceeding duration")
	var config = _create_valid_cutscene_config()
	config.keyframes[1].time = 5.0  # Exceeds duration of 2.5s
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Keyframe exceeding duration should fail validation")
	assert_true(_has_error_containing(result, "exceeds cutscene duration"), "Should have duration exceeded error")


func test_validate_config_with_keyframes_out_of_order():
	print("\nTEST: Validate config with keyframes out of order")
	var config = _create_valid_cutscene_config()
	config.keyframes[0].time = 2.0
	config.keyframes[1].time = 1.0  # Out of order
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Out of order keyframes should fail validation")
	assert_true(_has_error_containing(result, "chronological order"), "Should have ordering error")


func test_validate_config_with_keyframe_no_transforms():
	print("\nTEST: Validate config with keyframe no transforms")
	var config = _create_valid_cutscene_config()
	config.keyframes[0].transforms.clear()
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Keyframe without transforms should fail validation")
	assert_true(_has_error_containing(result, "no transforms"), "Should have no transforms error")


func test_validate_config_with_invalid_position_transform():
	print("\nTEST: Validate config with invalid position transform")
	var config = _create_valid_cutscene_config()
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.POSITION
	transform.value = 123  # Should be Vector2
	config.keyframes[0].transforms[0] = transform
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Invalid position transform should fail validation")
	assert_true(_has_error_containing(result, "Vector2"), "Should mention Vector2 requirement")


func test_validate_config_with_invalid_scale_transform():
	print("\nTEST: Validate config with invalid scale transform")
	var config = _create_valid_cutscene_config()
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.SCALE
	transform.value = Vector2(-1.0, 1.0)  # Negative scale
	config.keyframes[0].transforms.append(transform)
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Negative scale should fail validation")
	assert_true(_has_error_containing(result, "positive values"), "Should mention positive values requirement")


func test_validate_config_with_particle_negative_time():
	print("\nTEST: Validate config with particle negative time")
	var config = _create_valid_cutscene_config()
	var particle = CutsceneDataModels.ParticleEffect.new()
	particle.time = -0.5
	config.particles.append(particle)
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Particle with negative time should fail validation")


func test_validate_config_with_particle_exceeding_duration():
	print("\nTEST: Validate config with particle exceeding duration")
	var config = _create_valid_cutscene_config()
	var particle = CutsceneDataModels.ParticleEffect.new()
	particle.time = 5.0
	config.particles.append(particle)
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Particle exceeding duration should fail validation")


func test_validate_config_with_invalid_particle_density():
	print("\nTEST: Validate config with invalid particle density")
	var config = _create_valid_cutscene_config()
	var particle = CutsceneDataModels.ParticleEffect.new()
	particle.time = 1.0
	particle.density = "invalid"
	config.particles.append(particle)
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Invalid particle density should fail validation")
	assert_true(_has_error_containing(result, "low"), "Should mention valid density values")


func test_validate_config_with_audio_cue_negative_time():
	print("\nTEST: Validate config with audio cue negative time")
	var config = _create_valid_cutscene_config()
	var audio = CutsceneDataModels.AudioCue.new()
	audio.time = -0.5
	audio.sound = "test_sound"
	config.audio_cues.append(audio)
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Audio cue with negative time should fail validation")


func test_validate_config_with_audio_cue_empty_sound():
	print("\nTEST: Validate config with audio cue empty sound")
	var config = _create_valid_cutscene_config()
	var audio = CutsceneDataModels.AudioCue.new()
	audio.time = 1.0
	audio.sound = ""
	config.audio_cues.append(audio)
	
	var result = CutsceneParser.validate_config(config)
	
	assert_false(result.is_valid, "Audio cue with empty sound should fail validation")
	assert_true(_has_error_containing(result, "empty sound"), "Should mention empty sound error")


func test_pretty_print_with_valid_config():
	print("\nTEST: Pretty print with valid config")
	var config = _create_valid_cutscene_config()
	var output = CutsceneParser.pretty_print(config)
	
	assert_true(output.contains("Cutscene Configuration"), "Should have header")
	assert_true(output.contains("TestGame"), "Should include minigame key")
	assert_true(output.contains("2.5s"), "Should include duration")
	assert_true(output.contains("WIN"), "Should include cutscene type")
	assert_true(output.contains("Keyframes"), "Should include keyframes section")


func test_pretty_print_with_null_config():
	print("\nTEST: Pretty print with null config")
	var output = CutsceneParser.pretty_print(null)
	
	assert_true(output.contains("null"), "Should handle null config gracefully")


func test_pretty_print_preserves_all_data():
	print("\nTEST: Pretty print preserves all data")
	var config = _create_valid_cutscene_config()
	
	# Add particle and audio cue
	var particle = CutsceneDataModels.ParticleEffect.new()
	particle.time = 1.0
	particle.type = CutsceneTypes.ParticleType.SPARKLES
	particle.duration = 1.5
	particle.density = "medium"
	config.particles.append(particle)
	
	var audio = CutsceneDataModels.AudioCue.new()
	audio.time = 0.5
	audio.sound = "test_sound"
	config.audio_cues.append(audio)
	
	var output = CutsceneParser.pretty_print(config)
	
	assert_true(output.contains("Particles"), "Should include particles section")
	assert_true(output.contains("SPARKLES"), "Should include particle type")
	assert_true(output.contains("Audio Cues"), "Should include audio section")
	assert_true(output.contains("test_sound"), "Should include sound name")


func test_round_trip_parse_dict_to_dict():
	print("\nTEST: Round trip parse dict to dict")
	var original_dict = _create_valid_config_dict()
	var config = CutsceneParser.parse_dict(original_dict)
	var result_dict = config.to_dict()
	
	assert_eq(result_dict["minigame_key"], original_dict["minigame_key"], "Should preserve minigame key")
	assert_eq(result_dict["duration"], original_dict["duration"], "Should preserve duration")
	assert_eq(result_dict["cutscene_type"], original_dict["cutscene_type"], "Should preserve cutscene type")


# ============================================================================
# HELPER METHODS
# ============================================================================

func _create_valid_config_dict() -> Dictionary:
	return {
		"version": "1.0",
		"minigame_key": "TestGame",
		"cutscene_type": "win",
		"duration": 2.5,
		"character": {
			"expression": "happy",
			"deformation_enabled": true
		},
		"background_color": "#0a1e0f",
		"keyframes": [
			{
				"time": 0.0,
				"transforms": [
					{
						"type": "scale",
						"value": [0.5, 0.5],
						"relative": false
					}
				],
				"easing": "ease_out"
			},
			{
				"time": 1.0,
				"transforms": [
					{
						"type": "scale",
						"value": [1.0, 1.0],
						"relative": false
					}
				],
				"easing": "bounce"
			}
		],
		"particles": [],
		"audio_cues": []
	}


func _create_valid_cutscene_config() -> CutsceneDataModels.CutsceneConfig:
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestGame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 2.5
	
	# Add keyframes
	var kf1 = CutsceneDataModels.Keyframe.new(0.0)
	var transform1 = CutsceneDataModels.Transform.new()
	transform1.type = CutsceneTypes.TransformType.SCALE
	transform1.value = Vector2(0.5, 0.5)
	kf1.add_transform(transform1)
	config.add_keyframe(kf1)
	
	var kf2 = CutsceneDataModels.Keyframe.new(1.0)
	var transform2 = CutsceneDataModels.Transform.new()
	transform2.type = CutsceneTypes.TransformType.SCALE
	transform2.value = Vector2(1.0, 1.0)
	kf2.add_transform(transform2)
	config.add_keyframe(kf2)
	
	return config


func _create_test_json_file(path: String, data: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _create_invalid_json_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("{invalid json content")
		file.close()


func _cleanup_test_files() -> void:
	var dir = DirAccess.open(test_config_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()


func _has_error_containing(result: CutsceneDataModels.ValidationResult, text: String) -> bool:
	for error in result.errors:
		if error.to_lower().contains(text.to_lower()):
			return true
	return false
