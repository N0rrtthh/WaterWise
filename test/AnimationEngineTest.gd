extends GutTest

## Unit tests for AnimationEngine
## Validates: Requirements 1.3, 1.4, 1.5, 1.6, 1.7, 1.8

var test_character: Node2D


func before_each():
	test_character = Node2D.new()
	add_child_autofree(test_character)
	test_character.position = Vector2.ZERO
	test_character.rotation = 0.0
	test_character.scale = Vector2.ONE


func after_each():
	# Cleanup is handled by add_child_autofree
	pass


## Test: Apply position transform (absolute)
func test_apply_position_transform_absolute():
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.POSITION
	transform.value = Vector2(100, 50)
	transform.relative = false
	
	var tween = AnimationEngine.apply_transform(
		test_character,
		transform,
		0.1,
		CutsceneTypes.Easing.LINEAR
	)
	
	assert_not_null(tween, "Tween should be created")
	
	# Wait for animation to complete
	await wait_seconds(0.15)
	
	assert_almost_eq(test_character.position.x, 100.0, 1.0, "Position X should be 100")
	assert_almost_eq(test_character.position.y, 50.0, 1.0, "Position Y should be 50")


## Test: Apply position transform (relative)
func test_apply_position_transform_relative():
	test_character.position = Vector2(50, 25)
	
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.POSITION
	transform.value = Vector2(30, 20)
	transform.relative = true
	
	var tween = AnimationEngine.apply_transform(
		test_character,
		transform,
		0.1,
		CutsceneTypes.Easing.LINEAR
	)
	
	assert_not_null(tween, "Tween should be created")
	
	await wait_seconds(0.15)
	
	assert_almost_eq(test_character.position.x, 80.0, 1.0, "Position X should be 80 (50+30)")
	assert_almost_eq(test_character.position.y, 45.0, 1.0, "Position Y should be 45 (25+20)")


## Test: Apply rotation transform (absolute)
func test_apply_rotation_transform_absolute():
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.ROTATION
	transform.value = PI / 4  # 45 degrees
	transform.relative = false
	
	var tween = AnimationEngine.apply_transform(
		test_character,
		transform,
		0.1,
		CutsceneTypes.Easing.LINEAR
	)
	
	assert_not_null(tween, "Tween should be created")
	
	await wait_seconds(0.15)
	
	assert_almost_eq(test_character.rotation, PI / 4, 0.01, "Rotation should be PI/4")


## Test: Apply rotation transform (relative)
func test_apply_rotation_transform_relative():
	test_character.rotation = PI / 6  # 30 degrees
	
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.ROTATION
	transform.value = PI / 6  # Add another 30 degrees
	transform.relative = true
	
	var tween = AnimationEngine.apply_transform(
		test_character,
		transform,
		0.1,
		CutsceneTypes.Easing.LINEAR
	)
	
	assert_not_null(tween, "Tween should be created")
	
	await wait_seconds(0.15)
	
	assert_almost_eq(test_character.rotation, PI / 3, 0.01, "Rotation should be PI/3 (60 degrees)")


## Test: Apply scale transform (absolute)
func test_apply_scale_transform_absolute():
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.SCALE
	transform.value = Vector2(2.0, 1.5)
	transform.relative = false
	
	var tween = AnimationEngine.apply_transform(
		test_character,
		transform,
		0.1,
		CutsceneTypes.Easing.LINEAR
	)
	
	assert_not_null(tween, "Tween should be created")
	
	await wait_seconds(0.15)
	
	assert_almost_eq(test_character.scale.x, 2.0, 0.01, "Scale X should be 2.0")
	assert_almost_eq(test_character.scale.y, 1.5, 0.01, "Scale Y should be 1.5")


## Test: Apply scale transform (relative)
func test_apply_scale_transform_relative():
	test_character.scale = Vector2(2.0, 2.0)
	
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.SCALE
	transform.value = Vector2(0.5, 1.5)
	transform.relative = true
	
	var tween = AnimationEngine.apply_transform(
		test_character,
		transform,
		0.1,
		CutsceneTypes.Easing.LINEAR
	)
	
	assert_not_null(tween, "Tween should be created")
	
	await wait_seconds(0.15)
	
	assert_almost_eq(test_character.scale.x, 1.0, 0.01, "Scale X should be 1.0 (2.0*0.5)")
	assert_almost_eq(test_character.scale.y, 3.0, 0.01, "Scale Y should be 3.0 (2.0*1.5)")


## Test: Compose multiple transforms in parallel
func test_compose_transforms_parallel():
	var transforms: Array[CutsceneDataModels.Transform] = []
	
	# Position transform
	var pos_transform = CutsceneDataModels.Transform.new()
	pos_transform.type = CutsceneTypes.TransformType.POSITION
	pos_transform.value = Vector2(100, 100)
	pos_transform.relative = false
	transforms.append(pos_transform)
	
	# Rotation transform
	var rot_transform = CutsceneDataModels.Transform.new()
	rot_transform.type = CutsceneTypes.TransformType.ROTATION
	rot_transform.value = PI / 2
	rot_transform.relative = false
	transforms.append(rot_transform)
	
	# Scale transform
	var scale_transform = CutsceneDataModels.Transform.new()
	scale_transform.type = CutsceneTypes.TransformType.SCALE
	scale_transform.value = Vector2(2.0, 2.0)
	scale_transform.relative = false
	transforms.append(scale_transform)
	
	var tween = AnimationEngine.compose_transforms(test_character, transforms, 0.1)
	
	assert_not_null(tween, "Tween should be created")
	
	await wait_seconds(0.15)
	
	# All transforms should be applied
	assert_almost_eq(test_character.position.x, 100.0, 1.0, "Position X should be 100")
	assert_almost_eq(test_character.position.y, 100.0, 1.0, "Position Y should be 100")
	assert_almost_eq(test_character.rotation, PI / 2, 0.01, "Rotation should be PI/2")
	assert_almost_eq(test_character.scale.x, 2.0, 0.01, "Scale X should be 2.0")
	assert_almost_eq(test_character.scale.y, 2.0, 0.01, "Scale Y should be 2.0")


## Test: Animate through keyframe sequence
func test_animate_keyframe_sequence():
	var keyframes: Array[CutsceneDataModels.Keyframe] = []
	
	# Keyframe 1: Move to (50, 50) at time 0.0
	var kf1 = CutsceneDataModels.Keyframe.new(0.0)
	var kf1_transform = CutsceneDataModels.Transform.new()
	kf1_transform.type = CutsceneTypes.TransformType.POSITION
	kf1_transform.value = Vector2(50, 50)
	kf1_transform.relative = false
	kf1.add_transform(kf1_transform)
	kf1.easing = CutsceneTypes.Easing.LINEAR
	keyframes.append(kf1)
	
	# Keyframe 2: Move to (100, 100) at time 0.1
	var kf2 = CutsceneDataModels.Keyframe.new(0.1)
	var kf2_transform = CutsceneDataModels.Transform.new()
	kf2_transform.type = CutsceneTypes.TransformType.POSITION
	kf2_transform.value = Vector2(100, 100)
	kf2_transform.relative = false
	kf2.add_transform(kf2_transform)
	kf2.easing = CutsceneTypes.Easing.LINEAR
	keyframes.append(kf2)
	
	var tween = AnimationEngine.animate(test_character, keyframes, 0.2)
	
	assert_not_null(tween, "Tween should be created")
	
	await wait_seconds(0.25)
	
	assert_almost_eq(test_character.position.x, 100.0, 2.0, "Final position X should be 100")
	assert_almost_eq(test_character.position.y, 100.0, 2.0, "Final position Y should be 100")


## Test: All easing functions are accessible
func test_all_easing_functions():
	var easings = [
		CutsceneTypes.Easing.LINEAR,
		CutsceneTypes.Easing.EASE_IN,
		CutsceneTypes.Easing.EASE_OUT,
		CutsceneTypes.Easing.EASE_IN_OUT,
		CutsceneTypes.Easing.BOUNCE,
		CutsceneTypes.Easing.ELASTIC,
		CutsceneTypes.Easing.BACK
	]
	
	for easing in easings:
		var transform = CutsceneDataModels.Transform.new()
		transform.type = CutsceneTypes.TransformType.POSITION
		transform.value = Vector2(100, 100)
		transform.relative = false
		
		var tween = AnimationEngine.apply_transform(
			test_character,
			transform,
			0.05,
			easing
		)
		
		assert_not_null(tween, "Tween should be created for easing: " + str(easing))
		
		# Kill the tween to avoid interference
		if tween:
			tween.kill()
		
		# Reset position
		test_character.position = Vector2.ZERO


## Test: Apply easing mathematical function
func test_apply_easing_mathematical():
	# Test linear easing
	assert_almost_eq(AnimationEngine.apply_easing(0.0, CutsceneTypes.Easing.LINEAR), 0.0, 0.01)
	assert_almost_eq(AnimationEngine.apply_easing(0.5, CutsceneTypes.Easing.LINEAR), 0.5, 0.01)
	assert_almost_eq(AnimationEngine.apply_easing(1.0, CutsceneTypes.Easing.LINEAR), 1.0, 0.01)
	
	# Test ease_in (should be slower at start)
	var ease_in_mid = AnimationEngine.apply_easing(0.5, CutsceneTypes.Easing.EASE_IN)
	assert_true(ease_in_mid < 0.5, "Ease in should be slower at midpoint")
	
	# Test ease_out (should be faster at start)
	var ease_out_mid = AnimationEngine.apply_easing(0.5, CutsceneTypes.Easing.EASE_OUT)
	assert_true(ease_out_mid > 0.5, "Ease out should be faster at midpoint")
	
	# Test bounds
	assert_almost_eq(AnimationEngine.apply_easing(0.0, CutsceneTypes.Easing.BOUNCE), 0.0, 0.01)
	assert_almost_eq(AnimationEngine.apply_easing(1.0, CutsceneTypes.Easing.BOUNCE), 1.0, 0.01)


## Test: Invalid target node handling
func test_invalid_target_node():
	var invalid_node: Node2D = null
	
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.POSITION
	transform.value = Vector2(100, 100)
	
	var tween = AnimationEngine.apply_transform(
		invalid_node,
		transform,
		0.1,
		CutsceneTypes.Easing.LINEAR
	)
	
	assert_null(tween, "Tween should be null for invalid target")


## Test: Empty transforms array
func test_empty_transforms_array():
	var transforms: Array[CutsceneDataModels.Transform] = []
	
	var tween = AnimationEngine.compose_transforms(test_character, transforms, 0.1)
	
	assert_null(tween, "Tween should be null for empty transforms")


## Test: Empty keyframes array
func test_empty_keyframes_array():
	var keyframes: Array[CutsceneDataModels.Keyframe] = []
	
	var tween = AnimationEngine.animate(test_character, keyframes, 0.1)
	
	assert_null(tween, "Tween should be null for empty keyframes")


## Test: Keyframes are sorted by time
func test_keyframes_sorted_by_time():
	var keyframes: Array[CutsceneDataModels.Keyframe] = []
	
	# Add keyframes out of order
	var kf2 = CutsceneDataModels.Keyframe.new(0.2)
	var kf2_transform = CutsceneDataModels.Transform.new()
	kf2_transform.type = CutsceneTypes.TransformType.POSITION
	kf2_transform.value = Vector2(200, 200)
	kf2.add_transform(kf2_transform)
	keyframes.append(kf2)
	
	var kf1 = CutsceneDataModels.Keyframe.new(0.1)
	var kf1_transform = CutsceneDataModels.Transform.new()
	kf1_transform.type = CutsceneTypes.TransformType.POSITION
	kf1_transform.value = Vector2(100, 100)
	kf1.add_transform(kf1_transform)
	keyframes.append(kf1)
	
	var kf0 = CutsceneDataModels.Keyframe.new(0.0)
	var kf0_transform = CutsceneDataModels.Transform.new()
	kf0_transform.type = CutsceneTypes.TransformType.POSITION
	kf0_transform.value = Vector2(50, 50)
	kf0.add_transform(kf0_transform)
	keyframes.append(kf0)
	
	var tween = AnimationEngine.animate(test_character, keyframes, 0.3)
	
	assert_not_null(tween, "Tween should be created even with unsorted keyframes")
	
	await wait_seconds(0.35)
	
	# Should end at the final keyframe position
	assert_almost_eq(test_character.position.x, 200.0, 2.0, "Final position X should be 200")
	assert_almost_eq(test_character.position.y, 200.0, 2.0, "Final position Y should be 200")
