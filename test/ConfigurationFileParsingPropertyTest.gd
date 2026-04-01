extends Node

## Property-Based Test: Configuration File Parsing
## Feature: animated-cutscenes, Property 11: Configuration File Parsing
## Validates: Requirements 5.1, 10.1
##
## This test verifies that for any valid configuration file (JSON or GDScript resource),
## the CutsceneParser should successfully parse it and return a CutsceneConfig object.

const NUM_ITERATIONS = 50
const TEST_CONFIG_DIR = "res://test/temp_configs/"

func _ready():
	print("Running Configuration File Parsing Property Test...")
	_setup_test_directory()
	test_json_file_parsing_property()
	test_dictionary_parsing_property()
	test_invalid_file_handling()
	test_missing_file_handling()
	_cleanup_test_directory()
	print("✓ All configuration file parsing tests passed!")

func _setup_test_directory():
	# Create temporary directory for test files
	if not DirAccess.dir_exists_absolute(TEST_CONFIG_DIR):
		DirAccess.open("res://").make_dir_recursive(TEST_CONFIG_DIR)

func _cleanup_test_directory():
	# Clean up temporary test files
	var dir = DirAccess.open(TEST_CONFIG_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				dir.remove(file_name)
			file_name = dir.get_next()

func test_json_file_parsing_property():
	print("Testing JSON file parsing property...")
	
	for i in range(NUM_ITERATIONS):
		# Generate a random valid configuration
		var config_dict = _generate_random_valid_config()
		
		# Write it to a JSON file
		var file_path = TEST_CONFIG_DIR + "test_config_" + str(i) + ".json"
		var json_string = JSON.stringify(config_dict)
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		assert(file != null, "Failed to create test JSON file: " + file_path)
		file.store_string(json_string)
		file.close()
		
		# Parse the file
		var parsed_config = CutsceneParser.parse_config(file_path)
		
		# Verify parsing succeeded
		assert(parsed_config != null, "Failed to parse valid JSON config file: " + file_path)
		
		# Verify basic properties are preserved
		assert(parsed_config.minigame_key == config_dict["minigame_key"], 
			"Minigame key mismatch. Expected: %s, Got: %s" % [config_dict["minigame_key"], parsed_config.minigame_key])
		
		assert(abs(parsed_config.duration - config_dict["duration"]) < 0.001,
			"Duration mismatch. Expected: %f, Got: %f" % [config_dict["duration"], parsed_config.duration])
		
		assert(parsed_config.keyframes.size() == config_dict["keyframes"].size(),
			"Keyframes count mismatch. Expected: %d, Got: %d" % [config_dict["keyframes"].size(), parsed_config.keyframes.size()])

func test_dictionary_parsing_property():
	print("Testing dictionary parsing property...")
	
	for i in range(NUM_ITERATIONS):
		# Generate a random valid configuration dictionary
		var config_dict = _generate_random_valid_config()
		
		# Parse the dictionary directly
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		
		# Verify parsing succeeded
		assert(parsed_config != null, "Failed to parse valid config dictionary")
		
		# Verify basic properties are preserved
		assert(parsed_config.minigame_key == config_dict["minigame_key"], 
			"Minigame key mismatch. Expected: %s, Got: %s" % [config_dict["minigame_key"], parsed_config.minigame_key])
		
		assert(abs(parsed_config.duration - config_dict["duration"]) < 0.001,
			"Duration mismatch. Expected: %f, Got: %f" % [config_dict["duration"], parsed_config.duration])
		
		# Verify keyframes are parsed correctly
		assert(parsed_config.keyframes.size() == config_dict["keyframes"].size(),
			"Keyframes count mismatch. Expected: %d, Got: %d" % [config_dict["keyframes"].size(), parsed_config.keyframes.size()])
		
		# Verify particles are parsed correctly
		assert(parsed_config.particles.size() == config_dict["particles"].size(),
			"Particles count mismatch. Expected: %d, Got: %d" % [config_dict["particles"].size(), parsed_config.particles.size()])
		
		# Verify audio cues are parsed correctly
		assert(parsed_config.audio_cues.size() == config_dict["audio_cues"].size(),
			"Audio cues count mismatch. Expected: %d, Got: %d" % [config_dict["audio_cues"].size(), parsed_config.audio_cues.size()])

func test_invalid_file_handling():
	print("Testing invalid file handling...")
	
	# Test invalid JSON syntax
	var invalid_json_path = TEST_CONFIG_DIR + "invalid.json"
	var file = FileAccess.open(invalid_json_path, FileAccess.WRITE)
	file.store_string('{"invalid": json, syntax}')  # Missing quotes around 'json'
	file.close()
	
	var result = CutsceneParser.parse_config(invalid_json_path)
	assert(result == null, "Parser should return null for invalid JSON")
	
	# Test empty JSON file
	var empty_json_path = TEST_CONFIG_DIR + "empty.json"
	file = FileAccess.open(empty_json_path, FileAccess.WRITE)
	file.store_string("")
	file.close()
	
	result = CutsceneParser.parse_config(empty_json_path)
	assert(result == null, "Parser should return null for empty JSON file")
	
	# Test unsupported file extension
	var unsupported_path = TEST_CONFIG_DIR + "config.txt"
	file = FileAccess.open(unsupported_path, FileAccess.WRITE)
	file.store_string("some text")
	file.close()
	
	result = CutsceneParser.parse_config(unsupported_path)
	assert(result == null, "Parser should return null for unsupported file extension")

func test_missing_file_handling():
	print("Testing missing file handling...")
	
	# Test non-existent file
	var missing_path = TEST_CONFIG_DIR + "does_not_exist.json"
	var result = CutsceneParser.parse_config(missing_path)
	assert(result == null, "Parser should return null for missing file")
	
	# Test empty dictionary
	result = CutsceneParser.parse_dict({})
	assert(result == null, "Parser should return null for empty dictionary")

## Generate a random valid cutscene configuration dictionary
func _generate_random_valid_config() -> Dictionary:
	var minigame_keys = ["CatchTheRain", "FixLeak", "WaterPlant", "ThirstyPlant", "FilterBuilder"]
	var cutscene_types = ["intro", "win", "fail"]
	var expressions = ["happy", "sad", "surprised", "determined", "worried", "excited"]
	var easing_types = ["linear", "ease_in", "ease_out", "ease_in_out", "bounce", "elastic", "back"]
	var particle_types = ["sparkles", "water_drops", "stars", "smoke", "splash"]
	
	# Generate basic config
	var config = {
		"version": "1.0",
		"minigame_key": minigame_keys.pick_random(),
		"cutscene_type": cutscene_types.pick_random(),
		"duration": randf_range(1.5, 4.0),
		"character": {
			"expression": expressions.pick_random(),
			"deformation_enabled": randbool()
		},
		"background_color": "#%02x%02x%02x" % [randi() % 256, randi() % 256, randi() % 256],
		"keyframes": [],
		"particles": [],
		"audio_cues": []
	}
	
	# Generate keyframes (1-5 keyframes)
	var num_keyframes = randi_range(1, 5)
	var keyframe_times = []
	
	for i in range(num_keyframes):
		keyframe_times.append(randf() * config["duration"])
	
	keyframe_times.sort()
	
	for i in range(num_keyframes):
		var keyframe = {
			"time": keyframe_times[i],
			"easing": easing_types.pick_random(),
			"transforms": []
		}
		
		# Generate 1-3 transforms per keyframe
		var num_transforms = randi_range(1, 3)
		for j in range(num_transforms):
			var transform_type = ["position", "rotation", "scale"].pick_random()
			var transform = {
				"type": transform_type,
				"relative": randbool()
			}
			
			match transform_type:
				"position":
					transform["value"] = [randf_range(-100, 100), randf_range(-100, 100)]
				"rotation":
					transform["value"] = randf_range(-PI, PI)
				"scale":
					transform["value"] = [randf_range(0.5, 2.0), randf_range(0.5, 2.0)]
			
			keyframe["transforms"].append(transform)
		
		config["keyframes"].append(keyframe)
	
	# Generate particles (0-3 particles)
	var num_particles = randi_range(0, 3)
	for i in range(num_particles):
		var particle = {
			"time": randf() * config["duration"],
			"type": particle_types.pick_random(),
			"duration": randf_range(0.5, 2.0),
			"density": ["low", "medium", "high"].pick_random()
		}
		config["particles"].append(particle)
	
	# Generate audio cues (0-3 audio cues)
	var num_audio = randi_range(0, 3)
	var sound_names = ["success_chime", "water_splash", "bounce_sound", "failure_sound", "intro_music"]
	for i in range(num_audio):
		var audio = {
			"time": randf() * config["duration"],
			"sound": sound_names.pick_random()
		}
		config["audio_cues"].append(audio)
	
	return config

## Generate a random boolean value
func randbool() -> bool:
	return randi() % 2 == 0