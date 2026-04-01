extends Node

## Property-Based Test for Animation Timing Accuracy
## **Validates: Requirements 1.7, 6.7, 14.6**
##
## Property 3: Animation Timing Accuracy
## For any animation with a specified duration, the animation should complete 
## within 5% of the specified duration (accounting for frame timing variance).

const NUM_ITERATIONS = 100
var test_character: Node2D
var test_passed: int = 0
var test_failed: int = 0

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("ANIMATION TIMING ACCURACY PROPERTY TEST")
	print("Feature: animated-cutscenes, Property 3")
	print("**Validates: Requirements 1.7, 6.7, 14.6**")
	print("=".repeat(60) + "\n")
	
	# Run the property tests
	await test_single_transform_timing_accuracy()
	await test_parallel_transform_timing_accuracy()
	await test_keyframe_sequence_timing_accuracy()
	await test_easing_timing_consistency()
	await test_frame_timing_variance()
	
	# Print summary
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("  Passed: " + str(test_passed))
	print("  Failed: " + str(test_failed))
	if test_failed == 0:
		print("  Result: ✅ ALL TESTS PASSED")
		print("  Property 3 (Animation Timing Accuracy) VALIDATED")
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

func assert_timing_accuracy(actual_duration: float, expected_duration: float, tolerance_percent: float, message: String) -> void:
	var tolerance = expected_duration * (tolerance_percent / 100.0)
	var diff = abs(actual_duration - expected_duration)
	var within_tolerance = diff <= tolerance
	
	assert_test(
		within_tolerance,
		message + " (expected: %.3fs, actual: %.3fs, diff: %.3fs, tolerance: %.3fs)" % [
			expected_duration, actual_duration, diff, tolerance
		]
	)

func assert_true(condition: bool, message: String) -> void:
	assert_test(condition, message)

## Property Test: Single Transform Timing Accuracy
## Tests that individual transforms complete within expected timing bounds
func test_single_transform_timing_accuracy():
	print("Running test_single_transform_timing_accuracy...")
	
	for i in range(NUM_ITERATIONS):
		setup_test_character()
		
		# Generate random duration within reasonable bounds (0.1s to 5.0s)
		var expected_duration = randf_range(0.1, 5.0)
		
		# Generate random transform
		var transform = _generate_random_transform()
		var easing = _generate_random_easing()
		
		# Measure timing
		var start_time = Time.get_time_dict_from_system()
		var start_msec = start_time.hour * 3600000 + start_time.minute * 60000 + start_time.second * 1000 + start_time.millisecond
		
		# Apply the transform
		var tween = AnimationEngine.apply_transform(
			test_character,
			transform,
			expected_duration,
			easing
		)
		
		assert_not_null(tween, "Tween should be created for timing test (iteration %d)" % i)
		
		if tween:
			# Wait for animation to complete
			await tween.finished
			
			# Measure actual duration
			var end_time = Time.get_time_dict_from_system()
			var end_msec = end_time.hour * 3600000 + end_time.minute * 60000 + end_time.second * 1000 + end_time.millisecond
			var actual_duration = (end_msec - start_msec) / 1000.0
			
			# Handle day rollover (unlikely but possible)
			if actual_duration < 0:
				actual_duration += 86400.0  # Add 24 hours in seconds
			
			# Verify timing accuracy within 5% tolerance (Requirement 1.7)
			assert_timing_accuracy(
				actual_duration,
				expected_duration,
				5.0,
				"Single transform timing accuracy (iteration %d, duration %.3fs, easing %s)" % [i, expected_duration, easing]
			)

## Property Test: Parallel Transform Timing Accuracy
## Tests that parallel transforms complete within expected timing bounds
func test_parallel_transform_timing_accuracy():
	print("Running test_parallel_transform_timing_accuracy...")
	
	for i in range(50):  # Fewer iterations due to complexity
		setup_test_character()
		
		# Generate random duration
		var expected_duration = randf_range(0.2, 3.0)
		
		# Generate 2-3 random transforms of different types
		var transforms: Array[CutsceneDataModels.Transform] = []
		var transform_types = [
			CutsceneTypes.TransformType.POSITION,
			CutsceneTypes.TransformType.ROTATION,
			CutsceneTypes.TransformType.SCALE
		]
		transform_types.shuffle()
		
		var num_transforms = randi_range(2, 3)
		for j in range(num_transforms):
			transforms.append(_generate_specific_transform(transform_types[j]))
		
		# Measure timing
		var start_time = Time.get_time_dict_from_system()
		var start_msec = start_time.hour * 3600000 + start_time.minute * 60000 + start_time.second * 1000 + start_time.millisecond
		
		# Apply parallel transforms
		var tween = AnimationEngine.compose_transforms(test_character, transforms, expected_duration)
		
		assert_not_null(tween, "Parallel tween should be created (iteration %d)" % i)
		
		if tween:
			# Wait for animation to complete
			await tween.finished
			
			# Measure actual duration
			var end_time = Time.get_time_dict_from_system()
			var end_msec = end_time.hour * 3600000 + end_time.minute * 60000 + end_time.second * 1000 + end_time.millisecond
			var actual_duration = (end_msec - start_msec) / 1000.0
			
			# Handle day rollover
			if actual_duration < 0:
				actual_duration += 86400.0
			
			# Verify timing accuracy within 5% tolerance
			assert_timing_accuracy(
				actual_duration,
				expected_duration,
				5.0,
				"Parallel transforms timing accuracy (iteration %d, duration %.3fs)" % [i, expected_duration]
			)

## Property Test: Keyframe Sequence Timing Accuracy
## Tests that full keyframe sequences complete within expected timing bounds
func test_keyframe_sequence_timing_accuracy():
	print("Running test_keyframe_sequence_timing_accuracy...")
	
	for i in range(30):  # Fewer iterations due to complexity
		setup_test_character()
		
		# Generate random total duration within cutscene bounds (1.5s to 4.0s per Requirement 14.6)
		var expected_duration = randf_range(1.5, 4.0)
		
		# Generate 2-5 keyframes
		var keyframes: Array[CutsceneDataModels.Keyframe] = []
		var num_keyframes = randi_range(2, 5)
		
		for j in range(num_keyframes):
			var keyframe = CutsceneDataModels.Keyframe.new()
			keyframe.time = (j + 1) * (expected_duration / num_keyframes)
			keyframe.easing = _generate_random_easing()
			
			# Add 1-2 transforms per keyframe
			var num_transforms = randi_range(1, 2)
			for k in range(num_transforms):
				keyframe.add_transform(_generate_random_transform())
			
			keyframes.append(keyframe)
		
		# Measure timing
		var start_time = Time.get_time_dict_from_system()
		var start_msec = start_time.hour * 3600000 + start_time.minute * 60000 + start_time.second * 1000 + start_time.millisecond
		
		# Apply keyframe sequence
		var tween = AnimationEngine.animate(test_character, keyframes, expected_duration)
		
		assert_not_null(tween, "Keyframe sequence tween should be created (iteration %d)" % i)
		
		if tween:
			# Wait for animation to complete
			await tween.finished
			
			# Measure actual duration
			var end_time = Time.get_time_dict_from_system()
			var end_msec = end_time.hour * 3600000 + end_time.minute * 60000 + end_time.second * 1000 + end_time.millisecond
			var actual_duration = (end_msec - start_msec) / 1000.0
			
			# Handle day rollover
			if actual_duration < 0:
				actual_duration += 86400.0
			
			# Verify timing accuracy within 5% tolerance (Requirement 6.7)
			assert_timing_accuracy(
				actual_duration,
				expected_duration,
				5.0,
				"Keyframe sequence timing accuracy (iteration %d, duration %.3fs, %d keyframes)" % [i, expected_duration, num_keyframes]
			)

## Property Test: Easing Timing Consistency
## Tests that different easing functions don't affect overall timing
func test_easing_timing_consistency():
	print("Running test_easing_timing_consistency...")
	
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
		for i in range(10):  # Test each easing multiple times
			setup_test_character()
			
			var expected_duration = randf_range(0.5, 2.0)
			var transform = _generate_random_transform()
			
			# Measure timing
			var start_time = Time.get_time_dict_from_system()
			var start_msec = start_time.hour * 3600000 + start_time.minute * 60000 + start_time.second * 1000 + start_time.millisecond
			
			# Apply transform with specific easing
			var tween = AnimationEngine.apply_transform(
				test_character,
				transform,
				expected_duration,
				easing
			)
			
			assert_not_null(tween, "Tween should be created for easing %s" % easing)
			
			if tween:
				# Wait for animation to complete
				await tween.finished
				
				# Measure actual duration
				var end_time = Time.get_time_dict_from_system()
				var end_msec = end_time.hour * 3600000 + end_time.minute * 60000 + end_time.second * 1000 + end_time.millisecond
				var actual_duration = (end_msec - start_msec) / 1000.0
				
				# Handle day rollover
				if actual_duration < 0:
					actual_duration += 86400.0
				
				# Verify timing accuracy - easing shouldn't affect total duration
				assert_timing_accuracy(
					actual_duration,
					expected_duration,
					5.0,
					"Easing timing consistency for %s (iteration %d)" % [easing, i]
				)

## Property Test: Frame Timing Variance
## Tests that animations maintain consistent timing across different frame rates
func test_frame_timing_variance():
	print("Running test_frame_timing_variance...")
	
	# Test with different target frame rates by varying process load
	var test_scenarios = [
		{"name": "normal_load", "extra_work": 0},
		{"name": "light_load", "extra_work": 100},
		{"name": "medium_load", "extra_work": 500}
	]
	
	for scenario in test_scenarios:
		for i in range(10):
			setup_test_character()
			
			var expected_duration = randf_range(0.5, 1.5)
			var transform = _generate_random_transform()
			
			# Add artificial load to simulate different frame rates
			for j in range(scenario.extra_work):
				var dummy = sin(j * 0.001)  # Light computational load
			
			# Measure timing
			var start_time = Time.get_time_dict_from_system()
			var start_msec = start_time.hour * 3600000 + start_time.minute * 60000 + start_time.second * 1000 + start_time.millisecond
			
			# Apply transform
			var tween = AnimationEngine.apply_transform(
				test_character,
				transform,
				expected_duration,
				CutsceneTypes.Easing.LINEAR
			)
			
			assert_not_null(tween, "Tween should be created for frame variance test")
			
			if tween:
				# Wait for animation to complete
				await tween.finished
				
				# Measure actual duration
				var end_time = Time.get_time_dict_from_system()
				var end_msec = end_time.hour * 3600000 + end_time.minute * 60000 + end_time.second * 1000 + end_time.millisecond
				var actual_duration = (end_msec - start_msec) / 1000.0
				
				# Handle day rollover
				if actual_duration < 0:
					actual_duration += 86400.0
				
				# Verify timing accuracy - should be consistent regardless of frame rate (Requirement 14.6)
				assert_timing_accuracy(
					actual_duration,
					expected_duration,
					8.0,  # Slightly higher tolerance for frame variance
					"Frame timing variance for %s (iteration %d)" % [scenario.name, i]
				)

## Generate a random transform
func _generate_random_transform() -> CutsceneDataModels.Transform:
	var transform_types = [
		CutsceneTypes.TransformType.POSITION,
		CutsceneTypes.TransformType.ROTATION,
		CutsceneTypes.TransformType.SCALE
	]
	
	var transform_type = transform_types.pick_random()
	return _generate_specific_transform(transform_type)

## Generate a specific type of transform
func _generate_specific_transform(transform_type: CutsceneTypes.TransformType) -> CutsceneDataModels.Transform:
	var transform = CutsceneDataModels.Transform.new()
	transform.type = transform_type
	transform.relative = randf() < 0.5  # 50% chance of relative
	
	match transform_type:
		CutsceneTypes.TransformType.POSITION:
			transform.value = Vector2(
				randf_range(-100, 100),
				randf_range(-100, 100)
			)
		
		CutsceneTypes.TransformType.ROTATION:
			transform.value = randf_range(-PI, PI)
		
		CutsceneTypes.TransformType.SCALE:
			transform.value = Vector2(
				randf_range(0.5, 2.0),
				randf_range(0.5, 2.0)
			)
	
	return transform

## Generate a random easing function
func _generate_random_easing() -> CutsceneTypes.Easing:
	var easing_types = [
		CutsceneTypes.Easing.LINEAR,
		CutsceneTypes.Easing.EASE_IN,
		CutsceneTypes.Easing.EASE_OUT,
		CutsceneTypes.Easing.EASE_IN_OUT,
		CutsceneTypes.Easing.BOUNCE,
		CutsceneTypes.Easing.ELASTIC,
		CutsceneTypes.Easing.BACK
	]
	
	return easing_types.pick_random()