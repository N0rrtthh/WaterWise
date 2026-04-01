extends Node

## Property-Based Test: Configuration Format Support
## Feature: animated-cutscenes, Property 12: Configuration Format Support
## Validates: Requirements 5.2, 5.3, 5.4, 5.5, 5.6
##
## This test verifies that for any configuration containing keyframes, transforms, 
## easing, expressions, and particles, the parser should preserve all these elements 
## in the parsed CutsceneConfig.

const NUM_ITERATIONS = 50

func _ready():
	print("Running Configuration Format Support Property Test...")
	test_keyframes_preservation_property()
	test_transforms_preservation_property()
	test_easing_preservation_property()
	test_expressions_preservation_property()
	test_particles_preservation_property()
	test_comprehensive_format_support()
	print("✓ All configuration format support tests passed!")

func test_keyframes_preservation_property():
	print("Testing keyframes preservation property...")
	
	for i in range(NUM_ITERATIONS):
		# Generate config with random keyframes
		var config_dict = _generate_config_with_keyframes()
		
		# Parse the configuration
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Failed to parse config with keyframes")
		
		# Verify keyframes are preserved
		assert(parsed_config.keyframes.size() == config_dict["keyframes"].size(),
			"Keyframes count mismatch. Expected: %d, Got: %d" % [config_dict["keyframes"].size(), parsed_config.keyframes.size()])
		
		# Verify keyframe details
		for j in range(parsed_config.keyframes.size()):
			var original_kf = config_dict["keyframes"][j]
			var parsed_kf = parsed_config.keyframes[j]
			
			assert(abs(parsed_kf.time - original_kf["time"]) < 0.001,
				"Keyframe %d time mismatch. Expected: %f, Got: %f" % [j, original_kf["time"], parsed_kf.time])
			
			assert(parsed_kf.transforms.size() == original_kf["transforms"].size(),
				"Keyframe %d transforms count mismatch. Expected: %d, Got: %d" % [j, original_kf["transforms"].size(), parsed_kf.transforms.size()])

func test_transforms_preservation_property():
	print("Testing transforms preservation property...")
	
	for i in range(NUM_ITERATIONS):
		# Generate config with various transform types
		var config_dict = _generate_config_with_transforms()
		
		# Parse the configuration
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Failed to parse config with transforms")
		
		# Verify all transform types are preserved
		var found_position = false
		var found_rotation = false
		var found_scale = false
		
		for keyframe in parsed_config.keyframes:
			for transform in keyframe.transforms:
				match transform.type:
					CutsceneTypes.TransformType.POSITION:
						found_position = true
						assert(transform.value is Vector2, "Position transform should have Vector2 value")
					CutsceneTypes.TransformType.ROTATION:
						found_rotation = true
						assert(transform.value is float or transform.value is int, "Rotation transform should have numeric value")
					CutsceneTypes.TransformType.SCALE:
						found_scale = true
						assert(transform.value is Vector2, "Scale transform should have Vector2 value")
		
		# Verify we tested all transform types in this iteration
		if config_dict["keyframes"].size() > 0:
			var has_position = false
			var has_rotation = false
			var has_scale = false
			
			for kf in config_dict["keyframes"]:
				for t in kf["transforms"]:
					match t["type"]:
						"position": has_position = true
						"rotation": has_rotation = true
						"scale": has_scale = true
			
			assert(found_position == has_position, "Position transform preservation mismatch")
			assert(found_rotation == has_rotation, "Rotation transform preservation mismatch")
			assert(found_scale == has_scale, "Scale transform preservation mismatch")

func test_easing_preservation_property():
	print("Testing easing preservation property...")
	
	var easing_types = ["linear", "ease_in", "ease_out", "ease_in_out", "bounce", "elastic", "back"]
	
	for easing_name in easing_types:
		# Generate config with specific easing
		var config_dict = _generate_config_with_easing(easing_name)
		
		# Parse the configuration
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Failed to parse config with easing: " + easing_name)
		
		# Verify easing is preserved
		var found_easing = false
		for keyframe in parsed_config.keyframes:
			var expected_easing = CutsceneTypes.string_to_easing(easing_name)
			if keyframe.easing == expected_easing:
				found_easing = true
				break
		
		assert(found_easing, "Easing type '%s' was not preserved in parsed config" % easing_name)

func test_expressions_preservation_property():
	print("Testing expressions preservation property...")
	
	var expressions = ["happy", "sad", "surprised", "determined", "worried", "excited"]
	
	for expression_name in expressions:
		# Generate config with specific expression
		var config_dict = _generate_config_with_expression(expression_name)
		
		# Parse the configuration
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Failed to parse config with expression: " + expression_name)
		
		# Verify expression is preserved
		var expected_expression = CutsceneTypes.string_to_expression(expression_name)
		assert(parsed_config.character.expression == expected_expression,
			"Expression '%s' was not preserved. Expected: %d, Got: %d" % [expression_name, expected_expression, parsed_config.character.expression])

func test_particles_preservation_property():
	print("Testing particles preservation property...")
	
	for i in range(NUM_ITERATIONS):
		# Generate config with random particles
		var config_dict = _generate_config_with_particles()
		
		# Parse the configuration
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Failed to parse config with particles")
		
		# Verify particles are preserved
		assert(parsed_config.particles.size() == config_dict["particles"].size(),
			"Particles count mismatch. Expected: %d, Got: %d" % [config_dict["particles"].size(), parsed_config.particles.size()])
		
		# Verify particle details
		for j in range(parsed_config.particles.size()):
			var original_particle = config_dict["particles"][j]
			var parsed_particle = parsed_config.particles[j]
			
			assert(abs(parsed_particle.time - original_particle["time"]) < 0.001,
				"Particle %d time mismatch. Expected: %f, Got: %f" % [j, original_particle["time"], parsed_particle.time])
			
			assert(abs(parsed_particle.duration - original_particle["duration"]) < 0.001,
				"Particle %d duration mismatch. Expected: %f, Got: %f" % [j, original_particle["duration"], parsed_particle.duration])
			
			assert(parsed_particle.density == original_particle["density"],
				"Particle %d density mismatch. Expected: %s, Got: %s" % [j, original_particle["density"], parsed_particle.density])

func test_comprehensive_format_support():
	print("Testing comprehensive format support...")
	
	for i in range(NUM_ITERATIONS):
		# Generate config with all supported elements
		var config_dict = _generate_comprehensive_config()
		
		# Parse the configuration
		var parsed_config = CutsceneParser.parse_dict(config_dict)
		assert(parsed_config != null, "Failed to parse comprehensive config")
		
		# Verify all elements are preserved
		assert(parsed_config.keyframes.size() > 0, "Keyframes should be preserved")
		assert(parsed_config.particles.size() > 0, "Particles should be preserved")
		assert(parsed_config.audio_cues.size() > 0, "Audio cues should be preserved")
		
		# Verify character configuration
		assert(parsed_config.character != null, "Character config should be preserved")
		assert(parsed_config.character.deformation_enabled == config_dict["character"]["deformation_enabled"],
			"Character deformation setting should be preserved")
		
		# Verify background color
		var original_color = Color(config_dict["background_color"])
		assert(parsed_config.background_color.is_equal_approx(original_color),
			"Background color should be preserved")

## Generate configuration with keyframes
func _generate_config_with_keyframes() -> Dictionary:
	var config = _generate_basic_config()
	
	# Generate 2-5 keyframes
	var num_keyframes = randi_range(2, 5)
	var keyframe_times = []
	
	for i in range(num_keyframes):
		keyframe_times.append(randf() * config["duration"])
	
	keyframe_times.sort()
	
	for i in range(num_keyframes):
		var keyframe = {
			"time": keyframe_times[i],
			"easing": "linear",
			"transforms": [
				{
					"type": "position",
					"value": [randf_range(-50, 50), randf_range(-50, 50)],
					"relative": false
				}
			]
		}
		config["keyframes"].append(keyframe)
	
	return config

## Generate configuration with all transform types
func _generate_config_with_transforms() -> Dictionary:
	var config = _generate_basic_config()
	
	var keyframe = {
		"time": 0.5,
		"easing": "linear",
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
	
	return config

## Generate configuration with specific easing
func _generate_config_with_easing(easing_name: String) -> Dictionary:
	var config = _generate_basic_config()
	
	var keyframe = {
		"time": 0.5,
		"easing": easing_name,
		"transforms": [
			{
				"type": "position",
				"value": [10.0, 20.0],
				"relative": false
			}
		]
	}
	config["keyframes"].append(keyframe)
	
	return config

## Generate configuration with specific expression
func _generate_config_with_expression(expression_name: String) -> Dictionary:
	var config = _generate_basic_config()
	config["character"]["expression"] = expression_name
	
	# Add a simple keyframe
	config["keyframes"].append({
		"time": 0.5,
		"easing": "linear",
		"transforms": [
			{
				"type": "position",
				"value": [0.0, 0.0],
				"relative": false
			}
		]
	})
	
	return config

## Generate configuration with particles
func _generate_config_with_particles() -> Dictionary:
	var config = _generate_basic_config()
	
	# Add keyframe
	config["keyframes"].append({
		"time": 0.5,
		"easing": "linear",
		"transforms": [
			{
				"type": "position",
				"value": [0.0, 0.0],
				"relative": false
			}
		]
	})
	
	# Generate 1-3 particles
	var particle_types = ["sparkles", "water_drops", "stars", "smoke", "splash"]
	var num_particles = randi_range(1, 3)
	
	for i in range(num_particles):
		var particle = {
			"time": randf() * config["duration"],
			"type": particle_types.pick_random(),
			"duration": randf_range(0.5, 2.0),
			"density": ["low", "medium", "high"].pick_random()
		}
		config["particles"].append(particle)
	
	return config

## Generate comprehensive configuration with all elements
func _generate_comprehensive_config() -> Dictionary:
	var config = _generate_basic_config()
	
	# Add keyframes with various transforms
	config["keyframes"].append({
		"time": 0.0,
		"easing": "ease_in",
		"transforms": [
			{
				"type": "position",
				"value": [0.0, 0.0],
				"relative": false
			},
			{
				"type": "scale",
				"value": [0.5, 0.5],
				"relative": false
			}
		]
	})
	
	config["keyframes"].append({
		"time": 1.0,
		"easing": "bounce",
		"transforms": [
			{
				"type": "position",
				"value": [50.0, -20.0],
				"relative": true
			},
			{
				"type": "rotation",
				"value": 0.5,
				"relative": false
			}
		]
	})
	
	# Add particles
	config["particles"].append({
		"time": 0.5,
		"type": "sparkles",
		"duration": 1.0,
		"density": "medium"
	})
	
	# Add audio cues
	config["audio_cues"].append({
		"time": 0.0,
		"sound": "intro_sound"
	})
	
	return config

## Generate basic configuration structure
func _generate_basic_config() -> Dictionary:
	return {
		"version": "1.0",
		"minigame_key": "TestGame",
		"cutscene_type": "win",
		"duration": 2.0,
		"character": {
			"expression": "happy",
			"deformation_enabled": true
		},
		"background_color": "#0a1e0f",
		"keyframes": [],
		"particles": [],
		"audio_cues": []
	}

## Generate a random boolean value
func randbool() -> bool:
	return randi() % 2 == 0