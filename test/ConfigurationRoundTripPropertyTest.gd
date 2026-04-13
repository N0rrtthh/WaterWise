extends Node

## Property-Based Test: Configuration Round-Trip
## Feature: animated-cutscenes, Property 15: Configuration Round-Trip
## Validates: Requirements 10.6
##
## This test verifies that for any valid cutscene configuration, 
## parsing then serializing then parsing should produce an equivalent configuration 
## (round-trip property).

const NUM_ITERATIONS = 50
const TOLERANCE = 0.001

func _ready():
	print("Running Configuration Round-Trip Property Test...")
	test_dictionary_round_trip_property()
	test_json_round_trip_property()
	test_complex_configuration_round_trip()
	test_edge_cases_round_trip()
	print("✓ All configuration round-trip tests passed!")

func test_dictionary_round_trip_property():
	print("Testing dictionary round-trip property...")
	
	for i in range(NUM_ITERATIONS):
		# Generate original configuration
		var original_dict = _generate_random_config()
		
		# Parse to CutsceneConfig
		var parsed_config = CutsceneParser.parse_dict(original_dict)
		assert(parsed_config != null, "Failed to parse original config")
		
		# Serialize back to dictionary
		var serialized_dict = parsed_config.to_dict()
		
		# Parse again
		var reparsed_config = CutsceneParser.parse_dict(serialized_dict)
		assert(reparsed_config != null, "Failed to parse serialized config")
		
		# Verify equivalence
		_assert_configs_equivalent(parsed_config, reparsed_config, "Dictionary round-trip")

func test_json_round_trip_property():
	print("Testing JSON round-trip property...")
	
	for i in range(NUM_ITERATIONS):
		# Generate original configuration
		var original_dict = _generate_random_config()
		
		# Parse to CutsceneConfig
		var parsed_config = CutsceneParser.parse_dict(original_dict)
		assert(parsed_config != null, "Failed to parse original config")
		
		# Serialize to dictionary then JSON
		var serialized_dict = parsed_config.to_dict()
		var json_string = JSON.stringify(serialized_dict)
		
		# Parse JSON back to dictionary
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		assert(parse_result == OK, "Failed to parse JSON: " + json.get_error_message())
		
		var json_dict = json.get_data()
		
		# Parse dictionary to CutsceneConfig
		var reparsed_config = CutsceneParser.parse_dict(json_dict)
		assert(reparsed_config != null, "Failed to parse JSON-derived config")
		
		# Verify equivalence
		_assert_configs_equivalent(parsed_config, reparsed_config, "JSON round-trip")

func test_complex_configuration_round_trip():
	print("Testing complex configuration round-trip...")
	
	for i in range(20):  # Fewer iterations for complex configs
		# Generate complex configuration with all features
		var original_dict = _generate_complex_config()
		
		# Parse to CutsceneConfig
		var parsed_config = CutsceneParser.parse_dict(original_dict)
		assert(parsed_config != null, "Failed to parse complex config")
		
		# Serialize back to dictionary
		var serialized_dict = parsed_config.to_dict()
		
		# Parse again
		var reparsed_config = CutsceneParser.parse_dict(serialized_dict)
		assert(reparsed_config != null, "Failed to parse serialized complex config")
		
		# Verify equivalence with detailed checking
		_assert_configs_equivalent(parsed_config, reparsed_config, "Complex round-trip")
		
		# Additional checks for complex features
		_assert_keyframes_equivalent(parsed_config.keyframes, reparsed_config.keyframes)
		_assert_particles_equivalent(parsed_config.particles, reparsed_config.particles)
		_assert_audio_cues_equivalent(parsed_config.audio_cues, reparsed_config.audio_cues)

func test_edge_cases_round_trip():
	print("Testing edge cases round-trip...")
	
	# Test minimal configuration
	var minimal_config = {
		"version": "1.0",
		"minigame_key": "Test",
		"cutscene_type": "win",
		"duration": 2.0,
		"character": {
			"expression": "happy",
			"deformation_enabled": true
		},
		"background_color": "#ffffff",
		"keyframes": [
			{
				"time": 0.0,
				"easing": "linear",
				"transforms": [
					{
						"type": "position",
						"value": [0.0, 0.0],
						"relative": false
					}
				]
			}
		],
		"particles": [],
		"audio_cues": []
	}
	
	_test_single_round_trip(minimal_config, "Minimal config")
	
	# Test configuration with extreme values
	var extreme_config = {
		"version": "1.0",
		"minigame_key": "ExtremeTest",
		"cutscene_type": "fail",
		"duration": 4.0,  # Maximum duration
		"character": {
			"expression": "worried",
			"deformation_enabled": false
		},
		"background_color": "#000000",
		"keyframes": [
			{
				"time": 0.0,
				"easing": "elastic",
				"transforms": [
					{
						"type": "scale",
						"value": [0.01, 0.01],  # Minimum scale
						"relative": false
					}
				]
			},
			{
				"time": 3.99,  # Near maximum time
				"easing": "back",
				"transforms": [
					{
						"type": "rotation",
						"value": 6.28,  # 2*PI
						"relative": true
					}
				]
			}
		],
		"particles": [],
		"audio_cues": []
	}
	
	_test_single_round_trip(extreme_config, "Extreme values config")

## Test a single configuration round-trip
func _test_single_round_trip(config_dict: Dictionary, test_name: String):
	var parsed_config = CutsceneParser.parse_dict(config_dict)
	assert(parsed_config != null, "Failed to parse %s" % test_name)
	
	var serialized_dict = parsed_config.to_dict()
	var reparsed_config = CutsceneParser.parse_dict(serialized_dict)
	assert(reparsed_config != null, "Failed to reparse %s" % test_name)
	
	_assert_configs_equivalent(parsed_config, reparsed_config, test_name)

## Assert that two CutsceneConfig objects are equivalent
func _assert_configs_equivalent(config1: CutsceneDataModels.CutsceneConfig, config2: CutsceneDataModels.CutsceneConfig, context: String):
	# Basic properties
	assert(config1.version == config2.version,
		"%s: Version mismatch. Expected: %s, Got: %s" % [context, config1.version, config2.version])
	
	assert(config1.minigame_key == config2.minigame_key,
		"%s: Minigame key mismatch. Expected: %s, Got: %s" % [context, config1.minigame_key, config2.minigame_key])
	
	assert(config1.cutscene_type == config2.cutscene_type,
		"%s: Cutscene type mismatch. Expected: %d, Got: %d" % [context, config1.cutscene_type, config2.cutscene_type])
	
	assert(abs(config1.duration - config2.duration) < TOLERANCE,
		"%s: Duration mismatch. Expected: %f, Got: %f" % [context, config1.duration, config2.duration])
	
	# Character configuration
	assert(config1.character.expression == config2.character.expression,
		"%s: Character expression mismatch. Expected: %d, Got: %d" % [context, config1.character.expression, config2.character.expression])
	
	assert(config1.character.deformation_enabled == config2.character.deformation_enabled,
		"%s: Character deformation mismatch. Expected: %s, Got: %s" % [context, config1.character.deformation_enabled, config2.character.deformation_enabled])
	
	# Background color (with tolerance for color conversion)
	assert(config1.background_color.is_equal_approx(config2.background_color),
		"%s: Background color mismatch. Expected: %s, Got: %s" % [context, config1.background_color, config2.background_color])
	
	# Array sizes
	assert(config1.keyframes.size() == config2.keyframes.size(),
		"%s: Keyframes count mismatch. Expected: %d, Got: %d" % [context, config1.keyframes.size(), config2.keyframes.size()])
	
	assert(config1.particles.size() == config2.particles.size(),
		"%s: Particles count mismatch. Expected: %d, Got: %d" % [context, config1.particles.size(), config2.particles.size()])
	
	assert(config1.audio_cues.size() == config2.audio_cues.size(),
		"%s: Audio cues count mismatch. Expected: %d, Got: %d" % [context, config1.audio_cues.size(), config2.audio_cues.size()])

## Assert that keyframes arrays are equivalent
func _assert_keyframes_equivalent(keyframes1: Array, keyframes2: Array):
	assert(keyframes1.size() == keyframes2.size(), "Keyframes count mismatch")
	
	for i in range(keyframes1.size()):
		var kf1 = keyframes1[i]
		var kf2 = keyframes2[i]
		
		assert(abs(kf1.time - kf2.time) < TOLERANCE,
			"Keyframe %d time mismatch. Expected: %f, Got: %f" % [i, kf1.time, kf2.time])
		
		assert(kf1.easing == kf2.easing,
			"Keyframe %d easing mismatch. Expected: %d, Got: %d" % [i, kf1.easing, kf2.easing])
		
		assert(kf1.transforms.size() == kf2.transforms.size(),
			"Keyframe %d transforms count mismatch. Expected: %d, Got: %d" % [i, kf1.transforms.size(), kf2.transforms.size()])
		
		for j in range(kf1.transforms.size()):
			var t1 = kf1.transforms[j]
			var t2 = kf2.transforms[j]
			
			assert(t1.type == t2.type,
				"Transform %d type mismatch. Expected: %d, Got: %d" % [j, t1.type, t2.type])
			
			assert(t1.relative == t2.relative,
				"Transform %d relative mismatch. Expected: %s, Got: %s" % [j, t1.relative, t2.relative])
			
			# Value comparison depends on type
			if t1.value is Vector2 and t2.value is Vector2:
				assert(t1.value.is_equal_approx(t2.value),
					"Transform %d Vector2 value mismatch. Expected: %s, Got: %s" % [j, t1.value, t2.value])
			else:
				assert(abs(float(t1.value) - float(t2.value)) < TOLERANCE,
					"Transform %d numeric value mismatch. Expected: %f, Got: %f" % [j, float(t1.value), float(t2.value)])

## Assert that particles arrays are equivalent
func _assert_particles_equivalent(particles1: Array, particles2: Array):
	assert(particles1.size() == particles2.size(), "Particles count mismatch")
	
	for i in range(particles1.size()):
		var p1 = particles1[i]
		var p2 = particles2[i]
		
		assert(abs(p1.time - p2.time) < TOLERANCE,
			"Particle %d time mismatch. Expected: %f, Got: %f" % [i, p1.time, p2.time])
		
		assert(p1.type == p2.type,
			"Particle %d type mismatch. Expected: %d, Got: %d" % [i, p1.type, p2.type])
		
		assert(abs(p1.duration - p2.duration) < TOLERANCE,
			"Particle %d duration mismatch. Expected: %f, Got: %f" % [i, p1.duration, p2.duration])
		
		assert(p1.density == p2.density,
			"Particle %d density mismatch. Expected: %s, Got: %s" % [i, p1.density, p2.density])

## Assert that audio cues arrays are equivalent
func _assert_audio_cues_equivalent(audio1: Array, audio2: Array):
	assert(audio1.size() == audio2.size(), "Audio cues count mismatch")
	
	for i in range(audio1.size()):
		var a1 = audio1[i]
		var a2 = audio2[i]
		
		assert(abs(a1.time - a2.time) < TOLERANCE,
			"Audio cue %d time mismatch. Expected: %f, Got: %f" % [i, a1.time, a2.time])
		
		assert(a1.sound == a2.sound,
			"Audio cue %d sound mismatch. Expected: %s, Got: %s" % [i, a1.sound, a2.sound])

## Generate a random configuration for testing
func _generate_random_config() -> Dictionary:
	var minigame_keys = ["CatchTheRain", "FixLeak", "WaterPlant", "ThirstyPlant"]
	var cutscene_types = ["intro", "win", "fail"]
	var expressions = ["happy", "sad", "surprised", "determined", "worried", "excited"]
	var easing_types = ["linear", "ease_in", "ease_out", "ease_in_out", "bounce", "elastic", "back"]
	
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
	
	# Generate 1-3 keyframes
	var num_keyframes = randi_range(1, 3)
	for i in range(num_keyframes):
		var keyframe = {
			"time": randf() * config["duration"],
			"easing": easing_types.pick_random(),
			"transforms": [
				{
					"type": ["position", "rotation", "scale"].pick_random(),
					"value": _generate_transform_value(),
					"relative": randbool()
				}
			]
		}
		config["keyframes"].append(keyframe)
	
	return config

## Generate a complex configuration with all features
func _generate_complex_config() -> Dictionary:
	var config = _generate_random_config()
	
	# Add more keyframes with multiple transforms
	config["keyframes"] = []
	for i in range(3):
		var keyframe = {
			"time": i * (config["duration"] / 3.0),
			"easing": ["linear", "ease_in", "ease_out", "bounce"].pick_random(),
			"transforms": [
				{
					"type": "position",
					"value": [randf_range(-100, 100), randf_range(-100, 100)],
					"relative": randbool()
				},
				{
					"type": "rotation",
					"value": randf_range(-PI, PI),
					"relative": randbool()
				},
				{
					"type": "scale",
					"value": [randf_range(0.5, 2.0), randf_range(0.5, 2.0)],
					"relative": randbool()
				}
			]
		}
		config["keyframes"].append(keyframe)
	
	# Add particles
	config["particles"] = [
		{
			"time": randf() * config["duration"],
			"type": "sparkles",
			"duration": randf_range(0.5, 2.0),
			"density": "medium"
		}
	]
	
	# Add audio cues
	config["audio_cues"] = [
		{
			"time": randf() * config["duration"],
			"sound": "test_sound"
		}
	]
	
	return config

## Generate a transform value based on random type
func _generate_transform_value() -> Variant:
	var types = ["position", "rotation", "scale"]
	var type = types.pick_random()
	
	match type:
		"position":
			return [randf_range(-100, 100), randf_range(-100, 100)]
		"rotation":
			return randf_range(-PI, PI)
		"scale":
			return [randf_range(0.5, 2.0), randf_range(0.5, 2.0)]
		_:
			return [0.0, 0.0]

## Generate a random boolean value
func randbool() -> bool:
	return randi() % 2 == 0