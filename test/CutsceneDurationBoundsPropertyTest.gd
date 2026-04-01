extends Node

## Property-Based Test: Cutscene Duration Bounds
## Feature: animated-cutscenes, Property 5: Cutscene Duration Bounds
## Validates: Requirements 2.7, 14.1, 14.2, 14.3
##
## This test verifies that for any cutscene, the total duration should be between 
## 1.5 and 4.0 seconds (intro: 1.5-2.5s, win/fail: 2.0-3.0s).

const NUM_ITERATIONS = 100
const TOLERANCE = 0.1  # Allow 100ms tolerance for timing variance

func _ready():
	print("Running Cutscene Duration Bounds Property Test...")
	test_intro_cutscene_duration_bounds()
	test_win_cutscene_duration_bounds()
	test_fail_cutscene_duration_bounds()
	test_general_duration_bounds()
	test_duration_validation_in_parser()
	print("✓ All cutscene duration bounds tests passed!")

func test_intro_cutscene_duration_bounds():
	print("Testing intro cutscene duration bounds (1.5-2.5s)...")
	
	for i in range(NUM_ITERATIONS):
		# Generate intro cutscene configuration
		var config_dict = _generate_intro_cutscene_config()
		
		# Parse the configuration
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Failed to parse intro cutscene config")
		
		# Verify duration is within bounds
		assert(parsed_config.duration >= 1.5 - TOLERANCE,
			"Intro cutscene duration too short: %.2fs (minimum: 1.5s)" % parsed_config.duration)
		
		assert(parsed_config.duration <= 2.5 + TOLERANCE,
			"Intro cutscene duration too long: %.2fs (maximum: 2.5s)" % parsed_config.duration)
		
		# Verify cutscene type is correct
		assert(parsed_config.cutscene_type == CutsceneTypes.CutsceneType.INTRO,
			"Expected INTRO cutscene type, got: %d" % parsed_config.cutscene_type)

func test_win_cutscene_duration_bounds():
	print("Testing win cutscene duration bounds (2.0-3.0s)...")
	
	for i in range(NUM_ITERATIONS):
		# Generate win cutscene configuration
		var config_dict = _generate_win_cutscene_config()
		
		# Parse the configuration
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Failed to parse win cutscene config")
		
		# Verify duration is within bounds
		assert(parsed_config.duration >= 2.0 - TOLERANCE,
			"Win cutscene duration too short: %.2fs (minimum: 2.0s)" % parsed_config.duration)
		
		assert(parsed_config.duration <= 3.0 + TOLERANCE,
			"Win cutscene duration too long: %.2fs (maximum: 3.0s)" % parsed_config.duration)
		
		# Verify cutscene type is correct
		assert(parsed_config.cutscene_type == CutsceneTypes.CutsceneType.WIN,
			"Expected WIN cutscene type, got: %d" % parsed_config.cutscene_type)

func test_fail_cutscene_duration_bounds():
	print("Testing fail cutscene duration bounds (2.0-3.0s)...")
	
	for i in range(NUM_ITERATIONS):
		# Generate fail cutscene configuration
		var config_dict = _generate_fail_cutscene_config()
		
		# Parse the configuration
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Failed to parse fail cutscene config")
		
		# Verify duration is within bounds
		assert(parsed_config.duration >= 2.0 - TOLERANCE,
			"Fail cutscene duration too short: %.2fs (minimum: 2.0s)" % parsed_config.duration)
		
		assert(parsed_config.duration <= 3.0 + TOLERANCE,
			"Fail cutscene duration too long: %.2fs (maximum: 3.0s)" % parsed_config.duration)
		
		# Verify cutscene type is correct
		assert(parsed_config.cutscene_type == CutsceneTypes.CutsceneType.FAIL,
			"Expected FAIL cutscene type, got: %d" % parsed_config.cutscene_type)

func test_general_duration_bounds():
	print("Testing general duration bounds (1.5-4.0s)...")
	
	for i in range(NUM_ITERATIONS):
		# Generate random cutscene configuration
		var config_dict = _generate_random_cutscene_config()
		
		# Parse the configuration
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Failed to parse random cutscene config")
		
		# Verify duration is within general bounds
		assert(parsed_config.duration >= 1.5 - TOLERANCE,
			"Cutscene duration too short: %.2fs (minimum: 1.5s)" % parsed_config.duration)
		
		assert(parsed_config.duration <= 4.0 + TOLERANCE,
			"Cutscene duration too long: %.2fs (maximum: 4.0s)" % parsed_config.duration)

func test_duration_validation_in_parser():
	print("Testing duration validation in parser...")
	
	# Test configurations with durations outside bounds
	var invalid_durations = [
		{"duration": 1.0, "type": "intro", "should_fail": true},   # Too short for intro
		{"duration": 3.0, "type": "intro", "should_fail": true},   # Too long for intro
		{"duration": 1.5, "type": "win", "should_fail": true},     # Too short for win
		{"duration": 3.5, "type": "win", "should_fail": true},     # Too long for win
		{"duration": 1.5, "type": "fail", "should_fail": true},    # Too short for fail
		{"duration": 3.5, "type": "fail", "should_fail": true},    # Too long for fail
		{"duration": 0.5, "type": "intro", "should_fail": true},   # Way too short
		{"duration": 5.0, "type": "win", "should_fail": true},     # Way too long
		{"duration": 2.0, "type": "intro", "should_fail": false},  # Valid intro
		{"duration": 2.5, "type": "win", "should_fail": false},    # Valid win
		{"duration": 2.5, "type": "fail", "should_fail": false}    # Valid fail
	]
	
	for test_case in invalid_durations:
		var config_dict = _generate_basic_config()
		config_dict["duration"] = test_case["duration"]
		config_dict["cutscene_type"] = test_case["type"]
		
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		
		if parsed_config != null:
			var validation_result = CutsceneParser.validate_config(parsed_config)
			
			if test_case["should_fail"]:
				assert(validation_result.has_errors(),
					"Duration %.1fs for %s cutscene should trigger validation error" % [test_case["duration"], test_case["type"]])
			else:
				assert(not validation_result.has_errors(),
					"Duration %.1fs for %s cutscene should be valid. Errors: %s" % [test_case["duration"], test_case["type"], validation_result.get_error_message()])

## Generate intro cutscene configuration with appropriate duration
func _generate_intro_cutscene_config() -> Dictionary:
	var config = _generate_basic_config()
	config["cutscene_type"] = "intro"
	config["duration"] = randf_range(1.5, 2.5)  # Intro bounds
	
	# Add appropriate keyframes within the duration
	config["keyframes"] = [
		{
			"time": 0.0,
			"easing": "ease_in",
			"transforms": [
				{
					"type": "position",
					"value": [randf_range(-50, 50), randf_range(-50, 50)],
					"relative": false
				}
			]
		},
		{
			"time": config["duration"] * 0.8,  # Near the end
			"easing": "ease_out",
			"transforms": [
				{
					"type": "scale",
					"value": [randf_range(0.8, 1.2), randf_range(0.8, 1.2)],
					"relative": false
				}
			]
		}
	]
	
	return config

## Generate win cutscene configuration with appropriate duration
func _generate_win_cutscene_config() -> Dictionary:
	var config = _generate_basic_config()
	config["cutscene_type"] = "win"
	config["duration"] = randf_range(2.0, 3.0)  # Win bounds
	config["character"]["expression"] = "happy"
	
	# Add celebratory keyframes
	config["keyframes"] = [
		{
			"time": 0.0,
			"easing": "bounce",
			"transforms": [
				{
					"type": "scale",
					"value": [0.5, 0.5],
					"relative": false
				}
			]
		},
		{
			"time": config["duration"] * 0.3,
			"easing": "elastic",
			"transforms": [
				{
					"type": "scale",
					"value": [1.2, 1.2],
					"relative": false
				}
			]
		},
		{
			"time": config["duration"] * 0.8,
			"easing": "ease_out",
			"transforms": [
				{
					"type": "scale",
					"value": [1.0, 1.0],
					"relative": false
				}
			]
		}
	]
	
	# Add celebratory particles
	config["particles"] = [
		{
			"time": config["duration"] * 0.2,
			"type": "sparkles",
			"duration": config["duration"] * 0.6,
			"density": "high"
		}
	]
	
	return config

## Generate fail cutscene configuration with appropriate duration
func _generate_fail_cutscene_config() -> Dictionary:
	var config = _generate_basic_config()
	config["cutscene_type"] = "fail"
	config["duration"] = randf_range(2.0, 3.0)  # Fail bounds
	config["character"]["expression"] = "sad"
	
	# Add failure-themed keyframes
	config["keyframes"] = [
		{
			"time": 0.0,
			"easing": "ease_in",
			"transforms": [
				{
					"type": "position",
					"value": [0.0, -100.0],
					"relative": true
				}
			]
		},
		{
			"time": config["duration"] * 0.4,
			"easing": "bounce",
			"transforms": [
				{
					"type": "position",
					"value": [0.0, 0.0],
					"relative": false
				},
				{
					"type": "rotation",
					"value": randf_range(-0.3, 0.3),
					"relative": false
				}
			]
		},
		{
			"time": config["duration"] * 0.9,
			"easing": "ease_out",
			"transforms": [
				{
					"type": "rotation",
					"value": 0.0,
					"relative": false
				}
			]
		}
	]
	
	# Add failure particles
	config["particles"] = [
		{
			"time": config["duration"] * 0.3,
			"type": "smoke",
			"duration": config["duration"] * 0.4,
			"density": "medium"
		}
	]
	
	return config

## Generate random cutscene configuration with valid duration
func _generate_random_cutscene_config() -> Dictionary:
	var cutscene_types = ["intro", "win", "fail"]
	var selected_type = cutscene_types.pick_random()
	
	match selected_type:
		"intro":
			return _generate_intro_cutscene_config()
		"win":
			return _generate_win_cutscene_config()
		"fail":
			return _generate_fail_cutscene_config()
		_:
			return _generate_intro_cutscene_config()

## Generate basic configuration structure
func _generate_basic_config() -> Dictionary:
	var minigame_keys = ["CatchTheRain", "FixLeak", "WaterPlant", "ThirstyPlant"]
	var expressions = ["happy", "sad", "surprised", "determined", "worried", "excited"]
	
	return {
		"version": "1.0",
		"minigame_key": minigame_keys.pick_random(),
		"cutscene_type": "intro",  # Will be overridden
		"duration": 2.0,  # Will be overridden
		"character": {
			"expression": expressions.pick_random(),
			"deformation_enabled": randbool()
		},
		"background_color": "#%02x%02x%02x" % [randi() % 256, randi() % 256, randi() % 256],
		"keyframes": [],
		"particles": [],
		"audio_cues": []
	}

## Generate a random boolean value
func randbool() -> bool:
	return randi() % 2 == 0