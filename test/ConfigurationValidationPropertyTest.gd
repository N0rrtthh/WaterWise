extends Node

## Property-Based Test: Configuration Validation
## Feature: animated-cutscenes, Property 13: Configuration Validation
## Validates: Requirements 5.7, 10.2, 10.3
##
## This test verifies that for any configuration with missing required fields,
## the CutsceneParser should return a validation error with a descriptive message.

const NUM_ITERATIONS = 50

func _ready():
	print("Running Configuration Validation Property Test...")
	test_missing_required_fields_property()
	test_invalid_duration_validation()
	test_invalid_keyframes_validation()
	test_invalid_transforms_validation()
	test_invalid_particles_validation()
	test_invalid_audio_cues_validation()
	test_valid_configuration_passes()
	print("✓ All configuration validation tests passed!")

func test_missing_required_fields_property():
	print("Testing missing required fields property...")
	
	var required_fields = ["minigame_key", "cutscene_type", "duration", "keyframes"]
	
	for field_name in required_fields:
		for i in range(10):  # Test each missing field multiple times
			# Generate valid config then remove required field
			var config_dict = _generate_valid_config()
			config_dict.erase(field_name)
			
			# Parse and validate
			var parsed_config = CutsceneParser.parse_dict(config_dict)
			
			if parsed_config != null:
				var validation_result = CutsceneParser.validate_config(parsed_config)
				
				# Should have validation errors
				assert(validation_result.has_errors(),
					"Configuration missing '%s' should have validation errors" % field_name)
				
				# Error message should be descriptive
				var error_message = validation_result.get_error_message()
				assert(error_message.length() > 0,
					"Validation error message should not be empty for missing '%s'" % field_name)
				
				print("  ✓ Missing '%s' properly detected: %s" % [field_name, error_message.split("\n")[0]])

func test_invalid_duration_validation():
	print("Testing invalid duration validation...")
	
	var invalid_durations = [0.0, -1.0, -5.5, 0.5, 5.0, 10.0]  # Too short, negative, or too long
	
	for duration in invalid_durations:
		var config_dict = _generate_valid_config()
		config_dict["duration"] = duration
		
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Should parse config with invalid duration")
		
		var validation_result = CutsceneParser.validate_config(parsed_config)
		
		# Should have validation errors for invalid duration
		assert(validation_result.has_errors(),
			"Duration %.1f should trigger validation error" % duration)
		
		var error_message = validation_result.get_error_message()
		assert("duration" in error_message.to_lower() or "Duration" in error_message,
			"Error message should mention duration for value %.1f: %s" % [duration, error_message])

func test_invalid_keyframes_validation():
	print("Testing invalid keyframes validation...")
	
	# Test empty keyframes
	var config_dict = _generate_valid_config()
	config_dict["keyframes"] = []
	
	var parsed_config = CutsceneParser.parse_dict(config_dict)
	var validation_result = CutsceneParser.validate_config(parsed_config)
	
	assert(validation_result.has_errors(),
		"Empty keyframes should trigger validation error")
	
	# Test keyframes with invalid times
	for i in range(10):
		config_dict = _generate_valid_config()
		
		# Add keyframe with time outside duration
		var invalid_time = config_dict["duration"] + randf_range(0.1, 2.0)
		config_dict["keyframes"].append({
			"time": invalid_time,
			"easing": "linear",
			"transforms": [
				{
					"type": "position",
					"value": [0.0, 0.0],
					"relative": false
				}
			]
		})
		
		parsed_config = CutsceneParser.parse_dict(config_dict)
		validation_result = CutsceneParser.validate_config(parsed_config)
		
		assert(validation_result.has_errors(),
			"Keyframe time %.2f exceeding duration %.2f should trigger validation error" % [invalid_time, config_dict["duration"]])

func test_invalid_transforms_validation():
	print("Testing invalid transforms validation...")
	
	# Test keyframe with no transforms
	var config_dict = _generate_valid_config()
	config_dict["keyframes"] = [
		{
			"time": 0.5,
			"easing": "linear",
			"transforms": []  # Empty transforms
		}
	]
	
	var parsed_config = CutsceneParser.parse_dict(config_dict)
	var validation_result = CutsceneParser.validate_config(parsed_config)
	
	assert(validation_result.has_errors(),
		"Keyframe with no transforms should trigger validation error")
	
	# Test invalid scale values (negative or zero)
	for i in range(5):
		config_dict = _generate_valid_config()
		config_dict["keyframes"] = [
			{
				"time": 0.5,
				"easing": "linear",
				"transforms": [
					{
						"type": "scale",
						"value": [randf_range(-2.0, 0.0), randf_range(-2.0, 0.0)],  # Invalid scale
						"relative": false
					}
				]
			}
		]
		
		parsed_config = CutsceneParser.parse_dict(config_dict)
		validation_result = CutsceneParser.validate_config(parsed_config)
		
		assert(validation_result.has_errors(),
			"Invalid scale values should trigger validation error")

func test_invalid_particles_validation():
	print("Testing invalid particles validation...")
	
	# Test particle with time outside duration
	for i in range(10):
		var config_dict = _generate_valid_config()
		var invalid_time = config_dict["duration"] + randf_range(0.1, 2.0)
		
		config_dict["particles"] = [
			{
				"time": invalid_time,
				"type": "sparkles",
				"duration": 1.0,
				"density": "medium"
			}
		]
		
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		var validation_result = CutsceneParser.validate_config(parsed_config)
		
		assert(validation_result.has_errors(),
			"Particle time %.2f exceeding duration %.2f should trigger validation error" % [invalid_time, config_dict["duration"]])
	
	# Test particle with invalid density
	var config_dict = _generate_valid_config()
	config_dict["particles"] = [
		{
			"time": 0.5,
			"type": "sparkles",
			"duration": 1.0,
			"density": "invalid_density"
		}
	]
	
	var parsed_config = CutsceneParser.parse_dict(config_dict)
	var validation_result = CutsceneParser.validate_config(parsed_config)
	
	assert(validation_result.has_errors(),
		"Invalid particle density should trigger validation error")

func test_invalid_audio_cues_validation():
	print("Testing invalid audio cues validation...")
	
	# Test audio cue with time outside duration
	for i in range(10):
		var config_dict = _generate_valid_config()
		var invalid_time = config_dict["duration"] + randf_range(0.1, 2.0)
		
		config_dict["audio_cues"] = [
			{
				"time": invalid_time,
				"sound": "test_sound"
			}
		]
		
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		var validation_result = CutsceneParser.validate_config(parsed_config)
		
		assert(validation_result.has_errors(),
			"Audio cue time %.2f exceeding duration %.2f should trigger validation error" % [invalid_time, config_dict["duration"]])
	
	# Test audio cue with empty sound name
	var config_dict = _generate_valid_config()
	config_dict["audio_cues"] = [
		{
			"time": 0.5,
			"sound": ""  # Empty sound name
		}
	]
	
	var parsed_config = CutsceneParser.parse_dict(config_dict)
	var validation_result = CutsceneParser.validate_config(parsed_config)
	
	assert(validation_result.has_errors(),
		"Empty audio cue sound name should trigger validation error")

func test_valid_configuration_passes():
	print("Testing valid configuration passes validation...")
	
	for i in range(NUM_ITERATIONS):
		# Generate completely valid configuration
		var config_dict = _generate_valid_config()
		
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Valid config should parse successfully")
		
		var validation_result = CutsceneParser.validate_config(parsed_config)
		
		# Should pass validation
		assert(not validation_result.has_errors(),
			"Valid configuration should pass validation. Errors: %s" % validation_result.get_error_message())
		
		assert(validation_result.is_valid,
			"Valid configuration should have is_valid = true")

## Generate a valid cutscene configuration
func _generate_valid_config() -> Dictionary:
	var minigame_keys = ["CatchTheRain", "FixLeak", "WaterPlant", "ThirstyPlant"]
	var cutscene_types = ["intro", "win", "fail"]
	var expressions = ["happy", "sad", "surprised", "determined", "worried", "excited"]
	
	# Generate appropriate duration based on cutscene type
	var cutscene_type = cutscene_types.pick_random()
	var duration: float
	
	match cutscene_type:
		"intro":
			duration = randf_range(1.5, 2.5)
		"win", "fail":
			duration = randf_range(2.0, 3.0)
		_:
			duration = randf_range(1.5, 4.0)
	
	var config = {
		"version": "1.0",
		"minigame_key": minigame_keys.pick_random(),
		"cutscene_type": cutscene_type,
		"duration": duration,
		"character": {
			"expression": expressions.pick_random(),
			"deformation_enabled": randbool()
		},
		"background_color": "#0a1e0f",
		"keyframes": [],
		"particles": [],
		"audio_cues": []
	}
	
	# Generate valid keyframes (1-3 keyframes within duration)
	var num_keyframes = randi_range(1, 3)
	var keyframe_times = []
	
	for i in range(num_keyframes):
		keyframe_times.append(randf() * duration * 0.9)  # Keep within 90% of duration for safety
	
	keyframe_times.sort()
	
	for i in range(num_keyframes):
		var keyframe = {
			"time": keyframe_times[i],
			"easing": ["linear", "ease_in", "ease_out", "ease_in_out"].pick_random(),
			"transforms": [
				{
					"type": "position",
					"value": [randf_range(-50, 50), randf_range(-50, 50)],
					"relative": randbool()
				},
				{
					"type": "scale",
					"value": [randf_range(0.5, 2.0), randf_range(0.5, 2.0)],  # Valid positive scale
					"relative": false
				}
			]
		}
		config["keyframes"].append(keyframe)
	
	# Generate valid particles (0-2 particles within duration)
	var num_particles = randi_range(0, 2)
	for i in range(num_particles):
		var particle = {
			"time": randf() * duration * 0.8,  # Keep well within duration
			"type": ["sparkles", "water_drops", "stars"].pick_random(),
			"duration": randf_range(0.5, 1.5),
			"density": ["low", "medium", "high"].pick_random()
		}
		config["particles"].append(particle)
	
	# Generate valid audio cues (0-2 audio cues within duration)
	var num_audio = randi_range(0, 2)
	for i in range(num_audio):
		var audio = {
			"time": randf() * duration * 0.8,  # Keep well within duration
			"sound": ["success_sound", "water_splash", "intro_music"].pick_random()
		}
		config["audio_cues"].append(audio)
	
	return config

## Generate a random boolean value
func randbool() -> bool:
	return randi() % 2 == 0