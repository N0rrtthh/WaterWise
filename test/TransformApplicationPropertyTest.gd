extends Node

## Property-Based Test for Transform Application
## **Validates: Requirements 1.3, 1.4, 1.5**
##
## Property 1: Transform Application
## For any character node and any valid transform (position, rotation, or scale), 
## applying the transform through the AnimationEngine should result in the 
## character's corresponding property being updated to the target value.

const NUM_ITERATIONS = 100
var test_character: Node2D
var test_passed: int = 0
var test_failed: int = 0

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("TRANSFORM APPLICATION PROPERTY TEST")
	print("Feature: animated-cutscenes, Property 1")
	print("**Validates: Requirements 1.3, 1.4, 1.5**")
	print("=".repeat(60) + "\n")
	
	# Run the property tests
	await test_transform_application_property()
	await test_parallel_transform_composition_property()
	await test_easing_function_consistency_property()
	
	# Print summary
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("  Passed: " + str(test_passed))
	print("  Failed: " + str(test_failed))
	if test_failed == 0:
		print("  Result: ✅ ALL TESTS PASSED")
		print("  Property 1 (Transform Application) VALIDATED")
	else:
		print("  Result: ❌ SOME TESTS FAILED")
	print("=".repeat(60) + "\n")
	
	get_tree().quit()

func setup_test_character():
	if test_character:
		test_character.queue_free()
	test_character = Node2D.new()
	add_child(test_character)
	# Reset to known state
	test_character.position = Vector2.ZERO
	test_character.rotation = 0.0
	test_character.scale = Vector2.ONE

func assert_test(condition: bool, message: String) -> void:
	if condition:
		test_passed += 1
		print("  ✓ " + message)
	else:
		test_failed += 1
		print("  ✗ FAILED: " + message)

func assert_not_null(value, message: String) -> void:
	assert_test(value != null, message)

func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	var diff = abs(actual - expected)
	assert_test(diff <= tolerance, message + " (expected: " + str(expected) + ", got: " + str(actual) + ", diff: " + str(diff) + ")")

func assert_true(condition: bool, message: String) -> void:
	assert_test(condition, message)

## Property Test: Transform Application
## Tests that any valid transform is correctly applied to the character
func test_transform_application_property():
	print("Running test_transform_application_property...")
	
	for i in range(NUM_ITERATIONS):
		setup_test_character()
		
		# Generate random transform
		var transform_data = _generate_random_transform()
		var transform = transform_data.transform
		var expected_value = transform_data.expected_value
		
		# Store initial values for relative transforms
		var initial_pos = test_character.position
		var initial_rot = test_character.rotation
		var initial_scale = test_character.scale
		
		# Apply the transform
		var tween = AnimationEngine.apply_transform(
			test_character,
			transform,
			0.1,  # Short duration for fast testing
			CutsceneTypes.Easing.LINEAR
		)
		
		# Verify tween was created
		assert_not_null(tween, "Tween should be created for iteration %d" % i)
		
		# Wait for animation to complete
		await get_tree().create_timer(0.15).timeout
		
		# Verify the transform was applied correctly
		match transform.type:
			CutsceneTypes.TransformType.POSITION:
				var actual_pos = test_character.position
				assert_almost_eq(
					actual_pos.x, expected_value.x, 1.0,
					"Position X should match expected value (iteration %d)" % i
				)
				assert_almost_eq(
					actual_pos.y, expected_value.y, 1.0,
					"Position Y should match expected value (iteration %d)" % i
				)
			
			CutsceneTypes.TransformType.ROTATION:
				var actual_rot = test_character.rotation
				assert_almost_eq(
					actual_rot, expected_value, 0.01,
					"Rotation should match expected value (iteration %d)" % i
				)
			
			CutsceneTypes.TransformType.SCALE:
				var actual_scale = test_character.scale
				assert_almost_eq(
					actual_scale.x, expected_value.x, 0.01,
					"Scale X should match expected value (iteration %d)" % i
				)
				assert_almost_eq(
					actual_scale.y, expected_value.y, 0.01,
					"Scale Y should match expected value (iteration %d)" % i
				)

## Property Test: Parallel Transform Composition
## Tests that multiple transforms applied simultaneously don't interfere
func test_parallel_transform_composition_property():
	print("Running test_parallel_transform_composition_property...")
	
	for i in range(50):  # Fewer iterations due to complexity
		setup_test_character()
		
		# Generate 2-4 random transforms of different types
		var transforms: Array[CutsceneDataModels.Transform] = []
		var expected_values = {}
		
		var transform_types = [
			CutsceneTypes.TransformType.POSITION,
			CutsceneTypes.TransformType.ROTATION,
			CutsceneTypes.TransformType.SCALE
		]
		transform_types.shuffle()
		
		var num_transforms = randi_range(2, 3)
		for j in range(num_transforms):
			var transform_data = _generate_specific_transform(transform_types[j])
			transforms.append(transform_data.transform)
			expected_values[transform_types[j]] = transform_data.expected_value
		
		# Apply all transforms in parallel
		var tween = AnimationEngine.compose_transforms(test_character, transforms, 0.1)
		
		assert_not_null(tween, "Tween should be created for parallel composition (iteration %d)" % i)
		
		# Wait for animation to complete
		await get_tree().create_timer(0.15).timeout
		
		# Verify all transforms were applied correctly
		for transform_type in expected_values:
			var expected = expected_values[transform_type]
			match transform_type:
				CutsceneTypes.TransformType.POSITION:
					assert_almost_eq(
						test_character.position.x, expected.x, 1.0,
						"Parallel position X should match (iteration %d)" % i
					)
					assert_almost_eq(
						test_character.position.y, expected.y, 1.0,
						"Parallel position Y should match (iteration %d)" % i
					)
				
				CutsceneTypes.TransformType.ROTATION:
					assert_almost_eq(
						test_character.rotation, expected, 0.01,
						"Parallel rotation should match (iteration %d)" % i
					)
				
				CutsceneTypes.TransformType.SCALE:
					assert_almost_eq(
						test_character.scale.x, expected.x, 0.01,
						"Parallel scale X should match (iteration %d)" % i
					)
					assert_almost_eq(
						test_character.scale.y, expected.y, 0.01,
						"Parallel scale Y should match (iteration %d)" % i
					)

## Property Test: Easing Function Consistency
## Tests that all easing functions produce valid interpolation curves
func test_easing_function_consistency_property():
	print("Running test_easing_function_consistency_property...")
	
	var easing_types = [
		CutsceneTypes.Easing.LINEAR,
		CutsceneTypes.Easing.EASE_IN,
		CutsceneTypes.Easing.EASE_OUT,
		CutsceneTypes.Easing.EASE_IN_OUT,
		CutsceneTypes.Easing.BOUNCE,
		CutsceneTypes.Easing.ELASTIC,
		CutsceneTypes.Easing.BACK
	]
	
	for easing in easing_types:
		for i in range(10):  # Test each easing function multiple times
			setup_test_character()
			
			# Test mathematical easing function
			var t_values = [0.0, 0.25, 0.5, 0.75, 1.0]
			for t in t_values:
				var result = AnimationEngine.apply_easing(t, easing)
				
				# Verify bounds: easing should always return values in valid range
				assert_true(
					result >= -0.5 and result <= 1.5,  # Allow slight overshoot for some easing types
					"Easing %s at t=%f should return reasonable value, got %f" % [easing, t, result]
				)
				
				# Verify endpoints
				if t == 0.0:
					assert_almost_eq(
						result, 0.0, 0.1,
						"Easing %s should start near 0" % easing
					)
				elif t == 1.0:
					assert_almost_eq(
						result, 1.0, 0.1,
						"Easing %s should end near 1" % easing
					)
			
			# Test with actual transform
			var transform = CutsceneDataModels.Transform.new()
			transform.type = CutsceneTypes.TransformType.POSITION
			transform.value = Vector2(100, 100)
			transform.relative = false
			
			var tween = AnimationEngine.apply_transform(
				test_character,
				transform,
				0.1,
				easing
			)
			
			assert_not_null(tween, "Tween should be created for easing %s" % easing)
			
			await get_tree().create_timer(0.15).timeout
			
			# Should reach target regardless of easing function
			assert_almost_eq(
				test_character.position.x, 100.0, 2.0,
				"Should reach target with easing %s" % easing
			)

## Generate a random transform with expected result
func _generate_random_transform() -> Dictionary:
	var transform_types = [
		CutsceneTypes.TransformType.POSITION,
		CutsceneTypes.TransformType.ROTATION,
		CutsceneTypes.TransformType.SCALE
	]
	
	var transform_type = transform_types.pick_random()
	return _generate_specific_transform(transform_type)

## Generate a specific type of transform
func _generate_specific_transform(transform_type: CutsceneTypes.TransformType) -> Dictionary:
	var transform = CutsceneDataModels.Transform.new()
	transform.type = transform_type
	transform.relative = randf() < 0.5  # 50% chance of relative
	
	var expected_value
	
	match transform_type:
		CutsceneTypes.TransformType.POSITION:
			var target_pos = Vector2(
				randf_range(-200, 200),
				randf_range(-200, 200)
			)
			transform.value = target_pos
			
			if transform.relative:
				expected_value = test_character.position + target_pos
			else:
				expected_value = target_pos
		
		CutsceneTypes.TransformType.ROTATION:
			var target_rot = randf_range(-PI, PI)
			transform.value = target_rot
			
			if transform.relative:
				expected_value = test_character.rotation + target_rot
			else:
				expected_value = target_rot
		
		CutsceneTypes.TransformType.SCALE:
			var target_scale = Vector2(
				randf_range(0.1, 3.0),
				randf_range(0.1, 3.0)
			)
			transform.value = target_scale
			
			if transform.relative:
				expected_value = test_character.scale * target_scale
			else:
				expected_value = target_scale
			
			# Clamp expected value to match AnimationEngine's clamping
			expected_value.x = clamp(expected_value.x, 0.01, 10.0)
			expected_value.y = clamp(expected_value.y, 0.01, 10.0)
	
	return {
		"transform": transform,
		"expected_value": expected_value
	}