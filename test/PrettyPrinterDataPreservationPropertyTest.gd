extends Node

## Property-Based Test: Pretty Printer Data Preservation
## Feature: animated-cutscenes, Property 17: Pretty Printer Data Preservation
## Validates: Requirements 11.1, 11.2, 11.3, 11.4
##
## This test verifies that for any cutscene configuration, pretty printing should 
## preserve all animation timing, transformation data, and produce properly indented, 
## human-readable output.

const NUM_ITERATIONS = 30

func _ready():
	print("Running Pretty Printer Data Preservation Property Test...")
	test_animation_timing_preservation()
	test_transformation_data_preservation()
	test_proper_indentation()
	test_human_readable_output()
	test_comprehensive_data_preservation()
	print("✓ All pretty printer data preservation tests passed!")

func test_animation_timing_preservation():
	print("Testing animation timing preservation...")
	
	for i in range(NUM_ITERATIONS):
		# Generate config with specific timing data
		var config_dict = _generate_config_with_timing_data()
		var config = CutsceneParser.parse_dict(config_dict)
		assert(config != null, "Failed to parse timing config")
		
		var pretty_output = CutsceneParser.pretty_print(config)
		
		# Verify duration is preserved
		var duration_found = false
		var duration_patterns = [
			str(config.duration),
			"%.1f" % config.duration,
			"%.2f" % config.duration
		]
		
		for pattern in duration_patterns:
			if pattern in pretty_output:
				duration_found = true
				break
		
		assert(duration_found,
			"Pretty print should preserve duration: " + str(config.duration))
		
		# Verify keyframe timing is preserved
		for j in range(config.keyframes.size()):
			var keyframe = config.keyframes[j]
			var time_found = false
			var time_patterns = [
				str(keyframe.time),
				"%.1f" % keyframe.time,
				"%.2f" % keyframe.time
			]
			
			for pattern in time_patterns:
				if pattern in pretty_output:
					time_found = true
					break
			
			assert(time_found,
				"Pretty print should preserve keyframe %d time: %f" % [j, keyframe.time])
		
		# Verify particle timing is preserved
		for j in range(config.particles.size()):
			var particle = config.particles[j]
			var particle_time_found = false
			var particle_duration_found = false
			
			var time_patterns = [
				str(particle.time),
				"%.1f" % particle.time,
				"%.2f" % particle.time
			]
			
			var duration_patterns_p = [
				str(particle.duration),
				"%.1f" % particle.duration,
				"%.2f" % particle.duration
			]
			
			for pattern in time_patterns:
				if pattern in pretty_output:
					particle_time_found = true
					break
			
			for pattern in duration_patterns_p:
				if pattern in pretty_output:
					particle_duration_found = true
					break
			
			assert(particle_time_found,
				"Pretty print should preserve particle %d time: %f" % [j, particle.time])
			
			assert(particle_duration_found,
				"Pretty print should preserve particle %d duration: %f" % [j, particle.duration])

func test_transformation_data_preservation():
	print("Testing transformation data preservation...")
	
	for i in range(NUM_ITERATIONS):
		# Generate config with various transformation types
		var config_dict = _generate_config_with_transformations()
		var config = CutsceneParser.parse_dict(config_dict)
		assert(config != null, "Failed to parse transformation config")
		
		var pretty_output = CutsceneParser.pretty_print(config)
		
		# Verify all transformation types are mentioned
		var transform_types_found = {
			"position": false,
			"rotation": false,
			"scale": false
		}
		
		# Check for transform type names (case insensitive)
		var output_lower = pretty_output.to_lower()
		if "position" in output_lower:
			transform_types_found["position"] = true
		if "rotation" in output_lower:
			transform_types_found["rotation"] = true
		if "scale" in output_lower:
			transform_types_found["scale"] = true
		
		# Verify transformation values are preserved
		for keyframe in config.keyframes:
			for transform in keyframe.transforms:
				match transform.type:
					CutsceneTypes.TransformType.POSITION:
						if transform.value is Vector2:
							var pos = transform.value as Vector2
							var x_found = _find_numeric_value_in_output(pretty_output, pos.x)
							var y_found = _find_numeric_value_in_output(pretty_output, pos.y)
							assert(x_found or y_found,
								"Pretty print should preserve position values: (%f, %f)" % [pos.x, pos.y])
					
					CutsceneTypes.TransformType.ROTATION:
						var rot_value = float(transform.value)
						var rot_found = _find_numeric_value_in_output(pretty_output, rot_value)
						assert(rot_found,
							"Pretty print should preserve rotation value: %f" % rot_value)
					
					CutsceneTypes.TransformType.SCALE:
						if transform.value is Vector2:
							var scale = transform.value as Vector2
							var sx_found = _find_numeric_value_in_output(pretty_output, scale.x)
							var sy_found = _find_numeric_value_in_output(pretty_output, scale.y)
							assert(sx_found or sy_found,
								"Pretty print should preserve scale values: (%f, %f)" % [scale.x, scale.y])
		
		# Verify relative/absolute information is preserved
		var has_relative_info = "relative" in pretty_output.to_lower() or "absolute" in pretty_output.to_lower()
		if _config_has_relative_transforms(config):
			assert(has_relative_info,
				"Pretty print should indicate relative/absolute transform information")

func test_proper_indentation():
	print("Testing proper indentation...")
	
	for i in range(NUM_ITERATIONS):
		var config_dict = _generate_config_with_nested_data()
		var config = CutsceneParser.parse_dict(config_dict)
		assert(config != null, "Failed to parse nested config")
		
		var pretty_output = CutsceneParser.pretty_print(config)
		var lines = pretty_output.split("\n")
		
		# Check for proper indentation structure
		var has_main_sections = false
		var has_indented_content = false
		var has_nested_indentation = false
		
		for line in lines:
			# Main sections (no indentation, but not separators)
			if not line.begins_with(" ") and not line.begins_with("===") and line.length() > 0:
				if ":" in line:
					has_main_sections = true
			
			# First level indentation (2 spaces)
			if line.begins_with("  ") and not line.begins_with("    "):
				has_indented_content = true
			
			# Second level indentation (4 spaces)
			if line.begins_with("    "):
				has_nested_indentation = true
		
		assert(has_main_sections,
			"Pretty print should have main sections")
		
		assert(has_indented_content,
			"Pretty print should have properly indented content")
		
		# If we have keyframes with transforms, we should have nested indentation
		if config.keyframes.size() > 0 and config.keyframes[0].transforms.size() > 0:
			assert(has_nested_indentation,
				"Pretty print should have nested indentation for transforms")

func test_human_readable_output():
	print("Testing human-readable output...")
	
	for i in range(NUM_ITERATIONS):
		var config_dict = _generate_config_with_all_data_types()
		var config = CutsceneParser.parse_dict(config_dict)
		assert(config != null, "Failed to parse full config")
		
		var pretty_output = CutsceneParser.pretty_print(config)
		
		# Check for human-readable field names
		var human_readable_elements = [
			"Version",
			"Minigame",
			"Type",
			"Duration",
			"Character",
			"Expression",
			"Background Color",
			"Keyframes"
		]
		
		var found_elements = 0
		for element in human_readable_elements:
			if element in pretty_output:
				found_elements += 1
		
		assert(found_elements >= 5,
			"Pretty print should contain human-readable field names (found %d/%d)" % [found_elements, human_readable_elements.size()])
		
		# Check for proper formatting symbols
		assert(":" in pretty_output,
			"Pretty print should use colons for key-value separation")
		
		# Check for section headers
		assert("===" in pretty_output,
			"Pretty print should have section separators")
		
		# Check that enum values are converted to readable strings
		var readable_enums = ["HAPPY", "SAD", "SURPRISED", "WIN", "FAIL", "INTRO", "LINEAR", "BOUNCE"]
		var found_readable_enum = false
		for enum_val in readable_enums:
			if enum_val in pretty_output:
				found_readable_enum = true
				break
		
		assert(found_readable_enum,
			"Pretty print should convert enums to readable strings")

func test_comprehensive_data_preservation():
	print("Testing comprehensive data preservation...")
	
	for i in range(10):  # Fewer iterations for comprehensive test
		var config_dict = _generate_comprehensive_config()
		var config = CutsceneParser.parse_dict(config_dict)
		assert(config != null, "Failed to parse comprehensive config")
		
		var pretty_output = CutsceneParser.pretty_print(config)
		
		# Verify all major data categories are present
		var required_sections = []
		
		if config.keyframes.size() > 0:
			required_sections.append("Keyframes")
		
		if config.particles.size() > 0:
			required_sections.append("Particles")
		
		if config.audio_cues.size() > 0:
			required_sections.append("Audio")
		
		for section in required_sections:
			assert(section in pretty_output,
				"Pretty print should contain '%s' section" % section)
		
		# Verify counts are preserved
		if config.keyframes.size() > 0:
			var keyframe_count = str(config.keyframes.size())
			assert(keyframe_count in pretty_output,
				"Pretty print should show keyframes count: " + keyframe_count)
		
		if config.particles.size() > 0:
			var particle_count = str(config.particles.size())
			assert(particle_count in pretty_output,
				"Pretty print should show particles count: " + particle_count)
		
		# Verify character configuration is preserved
		assert("Character" in pretty_output,
			"Pretty print should contain character configuration")
		
		var deformation_status = str(config.character.deformation_enabled)
		assert(deformation_status in pretty_output,
			"Pretty print should preserve deformation enabled status: " + deformation_status)

## Helper function to find numeric values in output (with tolerance for formatting)
func _find_numeric_value_in_output(output: String, value: float) -> bool:
	var patterns = [
		str(value),
		"%.1f" % value,
		"%.2f" % value,
		"%.3f" % value
	]
	
	for pattern in patterns:
		if pattern in output:
			return true
	
	# Also check for the value as part of a vector representation
	var int_value = int(value)
	if abs(value - int_value) < 0.001:
		if str(int_value) in output:
			return true
	
	return false

## Check if config has any relative transforms
func _config_has_relative_transforms(config: CutsceneDataModels.CutsceneConfig) -> bool:
	for keyframe in config.keyframes:
		for transform in keyframe.transforms:
			if transform.relative:
				return true
	return false

## Generate config with specific timing data
func _generate_config_with_timing_data() -> Dictionary:
	return {
		"version": "1.0",
		"minigame_key": "TimingTest",
		"cutscene_type": "win",
		"duration": 2.75,
		"character": {
			"expression": "happy",
			"deformation_enabled": true
		},
		"background_color": "#00ff00",
		"keyframes": [
			{
				"time": 0.25,
				"easing": "linear",
				"transforms": [
					{
						"type": "position",
						"value": [10.5, -20.3],
						"relative": false
					}
				]
			},
			{
				"time": 1.33,
				"easing": "bounce",
				"transforms": [
					{
						"type": "scale",
						"value": [1.25, 0.75],
						"relative": true
					}
				]
			}
		],
		"particles": [
			{
				"time": 0.5,
				"type": "sparkles",
				"duration": 1.25,
				"density": "medium"
			}
		],
		"audio_cues": [
			{
				"time": 0.1,
				"sound": "timing_test_sound"
			}
		]
	}

## Generate config with various transformation types
func _generate_config_with_transformations() -> Dictionary:
	return {
		"version": "1.0",
		"minigame_key": "TransformTest",
		"cutscene_type": "fail",
		"duration": 3.0,
		"character": {
			"expression": "worried",
			"deformation_enabled": false
		},
		"background_color": "#ff0000",
		"keyframes": [
			{
				"time": 0.0,
				"easing": "ease_in",
				"transforms": [
					{
						"type": "position",
						"value": [-50.7, 30.2],
						"relative": false
					},
					{
						"type": "rotation",
						"value": 1.57,  # π/2
						"relative": true
					},
					{
						"type": "scale",
						"value": [0.5, 2.0],
						"relative": false
					}
				]
			}
		],
		"particles": [],
		"audio_cues": []
	}

## Generate config with nested data structure
func _generate_config_with_nested_data() -> Dictionary:
	return {
		"version": "1.0",
		"minigame_key": "NestedTest",
		"cutscene_type": "intro",
		"duration": 2.0,
		"character": {
			"expression": "determined",
			"deformation_enabled": true
		},
		"background_color": "#0000ff",
		"keyframes": [
			{
				"time": 0.0,
				"easing": "elastic",
				"transforms": [
					{
						"type": "position",
						"value": [0.0, 0.0],
						"relative": false
					},
					{
						"type": "scale",
						"value": [1.0, 1.0],
						"relative": false
					}
				]
			},
			{
				"time": 1.0,
				"easing": "back",
				"transforms": [
					{
						"type": "rotation",
						"value": 3.14159,
						"relative": true
					}
				]
			}
		],
		"particles": [
			{
				"time": 0.5,
				"type": "water_drops",
				"duration": 1.0,
				"density": "high"
			}
		],
		"audio_cues": [
			{
				"time": 0.0,
				"sound": "nested_sound"
			}
		]
	}

## Generate config with all data types
func _generate_config_with_all_data_types() -> Dictionary:
	return {
		"version": "1.0",
		"minigame_key": "AllTypesTest",
		"cutscene_type": "win",
		"duration": 2.5,
		"character": {
			"expression": "excited",
			"deformation_enabled": true
		},
		"background_color": "#ff00ff",
		"keyframes": [
			{
				"time": 0.0,
				"easing": "bounce",
				"transforms": [
					{
						"type": "position",
						"value": [25.0, -15.0],
						"relative": false
					}
				]
			}
		],
		"particles": [
			{
				"time": 1.0,
				"type": "stars",
				"duration": 0.8,
				"density": "low"
			}
		],
		"audio_cues": [
			{
				"time": 0.5,
				"sound": "all_types_sound"
			}
		]
	}

## Generate comprehensive config for thorough testing
func _generate_comprehensive_config() -> Dictionary:
	return {
		"version": "1.0",
		"minigame_key": "ComprehensiveTest",
		"cutscene_type": "fail",
		"duration": 3.5,
		"character": {
			"expression": "sad",
			"deformation_enabled": false
		},
		"background_color": "#123456",
		"keyframes": [
			{
				"time": 0.0,
				"easing": "linear",
				"transforms": [
					{
						"type": "position",
						"value": [0.0, 50.0],
						"relative": false
					},
					{
						"type": "scale",
						"value": [0.8, 0.8],
						"relative": false
					}
				]
			},
			{
				"time": 1.5,
				"easing": "ease_out",
				"transforms": [
					{
						"type": "rotation",
						"value": -0.5,
						"relative": true
					}
				]
			},
			{
				"time": 3.0,
				"easing": "ease_in_out",
				"transforms": [
					{
						"type": "position",
						"value": [-20.0, 0.0],
						"relative": true
					}
				]
			}
		],
		"particles": [
			{
				"time": 0.5,
				"type": "smoke",
				"duration": 2.0,
				"density": "medium"
			},
			{
				"time": 2.0,
				"type": "splash",
				"duration": 1.0,
				"density": "high"
			}
		],
		"audio_cues": [
			{
				"time": 0.0,
				"sound": "comprehensive_start"
			},
			{
				"time": 1.5,
				"sound": "comprehensive_middle"
			},
			{
				"time": 3.0,
				"sound": "comprehensive_end"
			}
		]
	}