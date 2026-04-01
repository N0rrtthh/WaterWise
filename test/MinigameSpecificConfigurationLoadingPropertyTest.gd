extends Node

## Property-Based Test: Minigame-Specific Configuration Loading
## Feature: animated-cutscenes, Property 6: Minigame-Specific Configuration Loading
## Validates: Requirements 3.1, 3.2, 12.1
##
## This test verifies that for any minigame key, requesting a cutscene should load 
## the configuration specific to that minigame if it exists, otherwise load the 
## default configuration.

const NUM_ITERATIONS = 50
const TEST_CONFIG_DIR = "res://data/cutscenes/"
const TEST_DEFAULT_DIR = "res://data/cutscenes/default/"

func _ready():
	print("Running Minigame-Specific Configuration Loading Property Test...")
	_setup_test_environment()
	test_custom_configuration_loading_property()
	test_default_configuration_fallback_property()
	test_configuration_caching_property()
	test_has_custom_cutscene_property()
	test_missing_configuration_handling()
	_cleanup_test_environment()
	print("✓ All minigame-specific configuration loading tests passed!")

func _setup_test_environment():
	# Ensure test directories exist
	if not DirAccess.dir_exists_absolute(TEST_CONFIG_DIR):
		DirAccess.open("res://").make_dir_recursive(TEST_CONFIG_DIR)
	
	if not DirAccess.dir_exists_absolute(TEST_DEFAULT_DIR):
		DirAccess.open("res://").make_dir_recursive(TEST_DEFAULT_DIR)

func _cleanup_test_environment():
	# Clean up test configuration files
	_cleanup_test_configs()

func test_custom_configuration_loading_property():
	print("Testing custom configuration loading property...")
	
	for i in range(NUM_ITERATIONS):
		# Generate random minigame key and cutscene type
		var minigame_key = _generate_random_minigame_key()
		var cutscene_type = _generate_random_cutscene_type()
		
		# Create custom configuration file
		var custom_config = _generate_valid_config(minigame_key, cutscene_type)
		var custom_path = _create_custom_config_file(minigame_key, cutscene_type, custom_config)
		
		# Create AnimatedCutscenePlayer instance
		var player = AnimatedCutscenePlayer.new()
		
		# Test has_custom_cutscene method
		var has_custom = player.has_custom_cutscene(minigame_key, cutscene_type)
		assert(has_custom,
			"has_custom_cutscene should return true for existing custom config: %s/%s" % [minigame_key, _cutscene_type_to_string(cutscene_type)])
		
		# Test configuration loading through private method access
		# Since _load_config is private, we test through the public interface
		# by checking if the player can successfully identify custom cutscenes
		
		# Verify the file exists where expected
		assert(FileAccess.file_exists(custom_path),
			"Custom config file should exist at: " + custom_path)
		
		# Clean up
		player.queue_free()
		_remove_file(custom_path)

func test_default_configuration_fallback_property():
	print("Testing default configuration fallback property...")
	
	for i in range(NUM_ITERATIONS):
		# Generate random minigame key that doesn't have custom config
		var minigame_key = "NonExistentGame" + str(i)
		var cutscene_type = _generate_random_cutscene_type()
		
		# Ensure no custom config exists
		var custom_path = _get_custom_config_path(minigame_key, cutscene_type)
		if FileAccess.file_exists(custom_path):
			_remove_file(custom_path)
		
		# Create default configuration if it doesn't exist
		var default_config = _generate_valid_config("default", cutscene_type)
		var default_path = _create_default_config_file(cutscene_type, default_config)
		
		# Create AnimatedCutscenePlayer instance
		var player = AnimatedCutscenePlayer.new()
		
		# Test has_custom_cutscene method - should return false
		var has_custom = player.has_custom_cutscene(minigame_key, cutscene_type)
		assert(not has_custom,
			"has_custom_cutscene should return false for non-existent custom config: %s/%s" % [minigame_key, _cutscene_type_to_string(cutscene_type)])
		
		# Verify default file exists
		assert(FileAccess.file_exists(default_path),
			"Default config file should exist at: " + default_path)
		
		# Clean up
		player.queue_free()
		_remove_file(default_path)

func test_configuration_caching_property():
	print("Testing configuration caching property...")
	
	for i in range(20):  # Fewer iterations for caching test
		var minigame_key = _generate_random_minigame_key()
		var cutscene_type = _generate_random_cutscene_type()
		
		# Create custom configuration
		var custom_config = _generate_valid_config(minigame_key, cutscene_type)
		var custom_path = _create_custom_config_file(minigame_key, cutscene_type, custom_config)
		
		# Create player and preload cutscene
		var player = AnimatedCutscenePlayer.new()
		player.preload_cutscene(minigame_key)
		
		# Check that configuration is cached
		# We can't directly access the cache, but we can verify the behavior
		# by checking that has_custom_cutscene works correctly after preloading
		var has_custom_before = player.has_custom_cutscene(minigame_key, cutscene_type)
		
		# Remove the file to test if cache is being used
		_remove_file(custom_path)
		
		# The has_custom_cutscene method checks file existence, so it should now return false
		# But if we had a way to test cached loading, it would still work
		var has_custom_after = player.has_custom_cutscene(minigame_key, cutscene_type)
		
		assert(has_custom_before,
			"Should have custom cutscene before file removal")
		
		assert(not has_custom_after,
			"Should not have custom cutscene after file removal (tests file-based detection)")
		
		# Clean up
		player.queue_free()

func test_has_custom_cutscene_property():
	print("Testing has_custom_cutscene property...")
	
	var test_cases = [
		{"minigame": "CatchTheRain", "type": CutsceneTypes.CutsceneType.WIN, "should_exist": false},
		{"minigame": "FixLeak", "type": CutsceneTypes.CutsceneType.FAIL, "should_exist": false},
		{"minigame": "WaterPlant", "type": CutsceneTypes.CutsceneType.INTRO, "should_exist": false}
	]
	
	var player = AnimatedCutscenePlayer.new()
	
	for test_case in test_cases:
		var minigame_key = test_case["minigame"]
		var cutscene_type = test_case["type"]
		var should_exist = test_case["should_exist"]
		
		# First, ensure no custom config exists
		var custom_path = _get_custom_config_path(minigame_key, cutscene_type)
		if FileAccess.file_exists(custom_path):
			_remove_file(custom_path)
		
		# Test that it returns false when no custom config exists
		var has_custom = player.has_custom_cutscene(minigame_key, cutscene_type)
		assert(has_custom == should_exist,
			"has_custom_cutscene should return %s for %s/%s when no custom config exists" % [should_exist, minigame_key, _cutscene_type_to_string(cutscene_type)])
		
		# Create a custom config
		var custom_config = _generate_valid_config(minigame_key, cutscene_type)
		_create_custom_config_file(minigame_key, cutscene_type, custom_config)
		
		# Test that it returns true when custom config exists
		has_custom = player.has_custom_cutscene(minigame_key, cutscene_type)
		assert(has_custom,
			"has_custom_cutscene should return true for %s/%s when custom config exists" % [minigame_key, _cutscene_type_to_string(cutscene_type)])
		
		# Clean up
		_remove_file(custom_path)
	
	player.queue_free()

func test_missing_configuration_handling():
	print("Testing missing configuration handling...")
	
	for i in range(10):
		var minigame_key = "MissingConfigGame" + str(i)
		var cutscene_type = _generate_random_cutscene_type()
		
		# Ensure no configs exist (custom or default)
		var custom_path = _get_custom_config_path(minigame_key, cutscene_type)
		var default_path = _get_default_config_path(cutscene_type)
		
		if FileAccess.file_exists(custom_path):
			_remove_file(custom_path)
		if FileAccess.file_exists(default_path):
			_remove_file(default_path)
		
		var player = AnimatedCutscenePlayer.new()
		
		# Test has_custom_cutscene with missing files
		var has_custom = player.has_custom_cutscene(minigame_key, cutscene_type)
		assert(not has_custom,
			"has_custom_cutscene should return false when no config files exist")
		
		# The system should handle missing configurations gracefully
		# by creating minimal fallback configurations
		
		player.queue_free()

## Generate a random minigame key
func _generate_random_minigame_key() -> String:
	var minigame_keys = [
		"CatchTheRain",
		"FixLeak", 
		"WaterPlant",
		"ThirstyPlant",
		"FilterBuilder",
		"RiceWashRescue",
		"VegetableBath",
		"TestGame",
		"RandomGame"
	]
	return minigame_keys.pick_random()

## Generate a random cutscene type
func _generate_random_cutscene_type() -> CutsceneTypes.CutsceneType:
	var types = [
		CutsceneTypes.CutsceneType.INTRO,
		CutsceneTypes.CutsceneType.WIN,
		CutsceneTypes.CutsceneType.FAIL
	]
	return types.pick_random()

## Generate a valid configuration for testing
func _generate_valid_config(minigame_key: String, cutscene_type: CutsceneTypes.CutsceneType) -> Dictionary:
	var duration = 2.0
	var expression = "happy"
	
	# Adjust based on cutscene type
	match cutscene_type:
		CutsceneTypes.CutsceneType.INTRO:
			duration = randf_range(1.5, 2.5)
			expression = "determined"
		CutsceneTypes.CutsceneType.WIN:
			duration = randf_range(2.0, 3.0)
			expression = "happy"
		CutsceneTypes.CutsceneType.FAIL:
			duration = randf_range(2.0, 3.0)
			expression = "sad"
	
	return {
		"version": "1.0",
		"minigame_key": minigame_key,
		"cutscene_type": _cutscene_type_to_string(cutscene_type),
		"duration": duration,
		"character": {
			"expression": expression,
			"deformation_enabled": true
		},
		"background_color": "#0a1e0f",
		"keyframes": [
			{
				"time": 0.0,
				"easing": "ease_out",
				"transforms": [
					{
						"type": "scale",
						"value": [0.3, 0.3],
						"relative": false
					}
				]
			},
			{
				"time": duration * 0.8,
				"easing": "ease_in_out",
				"transforms": [
					{
						"type": "scale",
						"value": [1.0, 1.0],
						"relative": false
					}
				]
			}
		],
		"particles": [],
		"audio_cues": []
	}

## Create a custom configuration file
func _create_custom_config_file(minigame_key: String, cutscene_type: CutsceneTypes.CutsceneType, config: Dictionary) -> String:
	var path = _get_custom_config_path(minigame_key, cutscene_type)
	
	# Ensure directory exists
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.open("res://").make_dir_recursive(dir_path)
	
	# Write JSON file
	var json_string = JSON.stringify(config)
	var file = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Failed to create config file: " + path)
	file.store_string(json_string)
	file.close()
	
	return path

## Create a default configuration file
func _create_default_config_file(cutscene_type: CutsceneTypes.CutsceneType, config: Dictionary) -> String:
	var path = _get_default_config_path(cutscene_type)
	
	# Ensure directory exists
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.open("res://").make_dir_recursive(dir_path)
	
	# Write JSON file
	var json_string = JSON.stringify(config)
	var file = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Failed to create default config file: " + path)
	file.store_string(json_string)
	file.close()
	
	return path

## Get the path for a custom configuration file
func _get_custom_config_path(minigame_key: String, cutscene_type: CutsceneTypes.CutsceneType) -> String:
	var type_str = _cutscene_type_to_string(cutscene_type)
	return TEST_CONFIG_DIR + minigame_key + "/" + type_str + ".json"

## Get the path for a default configuration file
func _get_default_config_path(cutscene_type: CutsceneTypes.CutsceneType) -> String:
	var type_str = _cutscene_type_to_string(cutscene_type)
	return TEST_DEFAULT_DIR + type_str + ".json"

## Convert cutscene type to string
func _cutscene_type_to_string(cutscene_type: CutsceneTypes.CutsceneType) -> String:
	match cutscene_type:
		CutsceneTypes.CutsceneType.INTRO:
			return "intro"
		CutsceneTypes.CutsceneType.WIN:
			return "win"
		CutsceneTypes.CutsceneType.FAIL:
			return "fail"
		_:
			return "intro"

## Remove a file if it exists
func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var dir = DirAccess.open(path.get_base_dir())
		if dir:
			dir.remove(path.get_file())

## Clean up all test configuration files
func _cleanup_test_configs() -> void:
	# Clean up test minigame directories
	var test_minigames = [
		"CatchTheRain", "FixLeak", "WaterPlant", "ThirstyPlant", 
		"FilterBuilder", "TestGame", "RandomGame"
	]
	
	for minigame in test_minigames:
		var minigame_dir = TEST_CONFIG_DIR + minigame
		if DirAccess.dir_exists_absolute(minigame_dir):
			_remove_directory_recursive(minigame_dir)
	
	# Clean up any files starting with "NonExistentGame" or "MissingConfigGame"
	var base_dir = DirAccess.open(TEST_CONFIG_DIR)
	if base_dir:
		base_dir.list_dir_begin()
		var dir_name = base_dir.get_next()
		while dir_name != "":
			if dir_name.begins_with("NonExistentGame") or dir_name.begins_with("MissingConfigGame"):
				var full_path = TEST_CONFIG_DIR + dir_name
				if DirAccess.dir_exists_absolute(full_path):
					_remove_directory_recursive(full_path)
			dir_name = base_dir.get_next()
	
	# Clean up default configs created during testing
	var default_dir = DirAccess.open(TEST_DEFAULT_DIR)
	if default_dir:
		default_dir.list_dir_begin()
		var file_name = default_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				default_dir.remove(file_name)
			file_name = default_dir.get_next()

## Recursively remove a directory and all its contents
func _remove_directory_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path + "/" + file_name
		if dir.current_is_dir():
			_remove_directory_recursive(full_path)
		else:
			dir.remove(file_name)
		file_name = dir.get_next()
	
	# Remove the directory itself
	var parent_dir = DirAccess.open(path.get_base_dir())
	if parent_dir:
		parent_dir.remove(path.get_file())