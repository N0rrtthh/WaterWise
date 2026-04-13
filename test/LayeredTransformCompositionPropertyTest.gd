extends GutTest

## Property-Based Test for Layered Transform Composition
## **Validates: Requirements 1.6**
##
## Property 2: Layered Transform Composition
## For any character node and any set of transforms applied simultaneously, 
## all transforms should be applied in parallel without interfering with each other.

const NUM_ITERATIONS = 100
var test_character: Node2D


func before_each():
	test_character = Node2D.new()
	add_child_autofree(test_character)
	# Reset to known state
	test_character.position = Vector2.ZERO
	test_character.rotation = 0.0
	test_character.scale = Vector2.ONE


func after_each():
	# Cleanup is handled by add_child_autofree
	pass


## Property Test: Layered Transform Composition
## Tests that multiple transforms applied simultaneously don't interfere with each other
func test_layered_transform_composition_property():
	for i in range(NUM_ITERATIONS):
		# Generate 2-4 random transforms of different types
		var transforms: Array[CutsceneDataModels.Transform] = []
		var expected_values = {}
		
		# Ensure we test different combinations of transform types
		var available_types = [
			CutsceneTypes.TransformType.POSITION,
			CutsceneTypes.TransformType.ROTATION,
			CutsceneTypes.TransformType.SCALE
		]
		available_types.shuffle()
		
		# Use 2-3 different transform types per test
		var num_transforms = randi_range(2, 3)
		for j in range(num_transforms):
			var transform_type = available_types[j]
			var transform_data = _generate_specific_transform(transform_type)
			transforms.append(transform_data.transform)
			expected_values[transform_type] = transform_data.expected_value
		
		# Store initial values for verification
		var initial_pos = test_character.position
		var initial_rot = test_character.rotation
		var initial_scale = test_character.scale
		
		# Apply all transforms in parallel using compose_transforms
		var tween = AnimationEngine.compose_transforms(test_character, transforms, 0.1)
		
		assert_not_null(tween, "Tween should be created for parallel composition (iteration %d)" % i)
		
		# Wait for animation to complete
		await wait_seconds(0.15)
		
		# Verify all transforms were applied correctly and independently
		for transform_type in expected_values:
			var expected = expected_values[transform_type]
			match transform_type:
				CutsceneTypes.TransformType.POSITION:
					assert_almost_eq(
						test_character.position.x, expected.x, 1.0,
						"Parallel position X should match expected (iteration %d)" % i
					)
					assert_almost_eq(
						test_character.position.y, expected.y, 1.0,
						"Parallel position Y should match expected (iteration %d)" % i
					)
				
				CutsceneTypes.TransformType.ROTATION:
					assert_almost_eq(
						test_character.rotation, expected, 0.01,
						"Parallel rotation should match expected (iteration %d)" % i
					)
				
				CutsceneTypes.TransformType.SCALE:
					assert_almost_eq(
						test_character.scale.x, expected.x, 0.01,
						"Parallel scale X should match expected (iteration %d)" % i
					)
					assert_almost_eq(
						test_character.scale.y, expected.y, 0.01,
						"Parallel scale Y should match expected (iteration %d)" % i
					)
		
		# Reset character for next iteration
		test_character.position = Vector2.ZERO
		test_character.rotation = 0.0
		test_character.scale = Vector2.ONE


## Property Test: Transform Independence
## Tests that applying the same transforms individually vs. in parallel produces the same result
func test_transform_independence_property():
	for i in range(50):  # Fewer iterations due to complexity
		# Generate 2-3 transforms of different types
		var transforms: Array[CutsceneDataModels.Transform] = []
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
		
		# Test 1: Apply transforms in parallel
		var parallel_character = Node2D.new()
		add_child_autofree(parallel_character)
		parallel_character.position = Vector2.ZERO
		parallel_character.rotation = 0.0
		parallel_character.scale = Vector2.ONE
		
		var parallel_tween = AnimationEngine.compose_transforms(parallel_character, transforms, 0.1)
		assert_not_null(parallel_tween, "Parallel tween should be created (iteration %d)" % i)
		await wait_seconds(0.15)
		
		# Store parallel results
		var parallel_pos = parallel_character.position
		var parallel_rot = parallel_character.rotation
		var parallel_scale = parallel_character.scale
		
		# Test 2: Apply transforms individually (sequentially but instantly)
		var sequential_character = Node2D.new()
		add_child_autofree(sequential_character)
		sequential_character.position = Vector2.ZERO
		sequential_character.rotation = 0.0
		sequential_character.scale = Vector2.ONE
		
		# Apply each transform instantly to simulate the final result
		for transform in transforms:
			match transform.type:
				CutsceneTypes.TransformType.POSITION:
					var target_pos = transform.value as Vector2
					if transform.relative:
						sequential_character.position += target_pos
					else:
						sequential_character.position = target_pos
				
				CutsceneTypes.TransformType.ROTATION:
					var target_rot = transform.value as float
					if transform.relative:
						sequential_character.rotation += target_rot
					else:
						sequential_character.rotation = target_rot
				
				CutsceneTypes.TransformType.SCALE:
					var target_scale = transform.value as Vector2
					if transform.relative:
						sequential_character.scale *= target_scale
					else:
						sequential_character.scale = target_scale
					
					# Apply same clamping as AnimationEngine
					sequential_character.scale.x = clamp(sequential_character.scale.x, 0.01, 10.0)
					sequential_character.scale.y = clamp(sequential_character.scale.y, 0.01, 10.0)
		
		# Compare results - parallel and sequential should be equivalent
		assert_almost_eq(
			parallel_pos.x, sequential_character.position.x, 1.0,
			"Parallel and sequential position X should match (iteration %d)" % i
		)
		assert_almost_eq(
			parallel_pos.y, sequential_character.position.y, 1.0,
			"Parallel and sequential position Y should match (iteration %d)" % i
		)
		assert_almost_eq(
			parallel_rot, sequential_character.rotation, 0.01,
			"Parallel and sequential rotation should match (iteration %d)" % i
		)
		assert_almost_eq(
			parallel_scale.x, sequential_character.scale.x, 0.01,
			"Parallel and sequential scale X should match (iteration %d)" % i
		)
		assert_almost_eq(
			parallel_scale.y, sequential_character.scale.y, 0.01,
			"Parallel and sequential scale Y should match (iteration %d)" % i
		)


## Property Test: Empty and Single Transform Edge Cases
## Tests edge cases for compose_transforms method
func test_compose_transforms_edge_cases_property():
	for i in range(20):
		# Test empty transforms array
		var empty_transforms: Array[CutsceneDataModels.Transform] = []
		var empty_tween = AnimationEngine.compose_transforms(test_character, empty_transforms, 0.1)
		assert_null(empty_tween, "Empty transforms should return null tween (iteration %d)" % i)
		
		# Test single transform (should work same as apply_transform)
		var single_transform_data = _generate_random_transform()
		var single_transforms: Array[CutsceneDataModels.Transform] = [single_transform_data.transform]
		
		# Store initial state
		var initial_pos = test_character.position
		var initial_rot = test_character.rotation
		var initial_scale = test_character.scale
		
		var single_tween = AnimationEngine.compose_transforms(test_character, single_transforms, 0.1)
		assert_not_null(single_tween, "Single transform should create tween (iteration %d)" % i)
		
		await wait_seconds(0.15)
		
		# Verify the single transform was applied correctly
		var expected = single_transform_data.expected_value
		match single_transform_data.transform.type:
			CutsceneTypes.TransformType.POSITION:
				assert_almost_eq(
					test_character.position.x, expected.x, 1.0,
					"Single transform position X should match (iteration %d)" % i
				)
				assert_almost_eq(
					test_character.position.y, expected.y, 1.0,
					"Single transform position Y should match (iteration %d)" % i
				)
			
			CutsceneTypes.TransformType.ROTATION:
				assert_almost_eq(
					test_character.rotation, expected, 0.01,
					"Single transform rotation should match (iteration %d)" % i
				)
			
			CutsceneTypes.TransformType.SCALE:
				assert_almost_eq(
					test_character.scale.x, expected.x, 0.01,
					"Single transform scale X should match (iteration %d)" % i
				)
				assert_almost_eq(
					test_character.scale.y, expected.y, 0.01,
					"Single transform scale Y should match (iteration %d)" % i
				)
		
		# Reset for next iteration
		test_character.position = Vector2.ZERO
		test_character.rotation = 0.0
		test_character.scale = Vector2.ONE


## Property Test: Multiple Transforms of Same Type
## Tests that multiple transforms of the same type can be composed (though this may not be typical usage)
func test_multiple_same_type_transforms_property():
	for i in range(30):
		# Generate 2-3 transforms of the same type
		var transform_type = [
			CutsceneTypes.TransformType.POSITION,
			CutsceneTypes.TransformType.ROTATION,
			CutsceneTypes.TransformType.SCALE
		].pick_random()
		
		var transforms: Array[CutsceneDataModels.Transform] = []
		var num_transforms = randi_range(2, 3)
		
		for j in range(num_transforms):
			var transform_data = _generate_specific_transform(transform_type)
			transforms.append(transform_data.transform)
		
		# Apply all transforms
		var tween = AnimationEngine.compose_transforms(test_character, transforms, 0.1)
		assert_not_null(tween, "Multiple same-type transforms should create tween (iteration %d)" % i)
		
		await wait_seconds(0.15)
		
		# The result should be the last transform applied (since they overwrite each other)
		# This tests that the system handles this case gracefully without crashing
		match transform_type:
			CutsceneTypes.TransformType.POSITION:
				# Position should be some valid Vector2
				assert_true(
					test_character.position.x >= -1000 and test_character.position.x <= 1000,
					"Position X should be in reasonable range (iteration %d)" % i
				)
				assert_true(
					test_character.position.y >= -1000 and test_character.position.y <= 1000,
					"Position Y should be in reasonable range (iteration %d)" % i
				)
			
			CutsceneTypes.TransformType.ROTATION:
				# Rotation should be some valid float
				assert_true(
					test_character.rotation >= -4 * PI and test_character.rotation <= 4 * PI,
					"Rotation should be in reasonable range (iteration %d)" % i
				)
			
			CutsceneTypes.TransformType.SCALE:
				# Scale should be clamped to AnimationEngine's limits
				assert_true(
					test_character.scale.x >= 0.01 and test_character.scale.x <= 10.0,
					"Scale X should be in clamped range (iteration %d)" % i
				)
				assert_true(
					test_character.scale.y >= 0.01 and test_character.scale.y <= 10.0,
					"Scale Y should be in clamped range (iteration %d)" % i
				)
		
		# Reset for next iteration
		test_character.position = Vector2.ZERO
		test_character.rotation = 0.0
		test_character.scale = Vector2.ONE


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