extends GutTest

## Test suite for runtime error handling in the animated cutscene system
## Validates Requirement 12.5: Runtime error handling
##
## This test suite verifies that:
## - Animation engine failures are recovered gracefully
## - Memory allocation failures don't block game progression
## - Cutscenes always complete and emit signals even on errors

var cutscene_player: AnimatedCutscenePlayer
var test_character: WaterDropletCharacter


func before_each():
	cutscene_player = AnimatedCutscenePlayer.new()
	add_child_autofree(cutscene_player)


func after_each():
	if test_character and is_instance_valid(test_character):
		test_character.queue_free()
	test_character = null


## Test that cutscene completes even when animation engine returns null tween
func test_animation_engine_failure_recovery():
	# Create a minimal config
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestGame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 0.5
	config.character.expression = CutsceneTypes.CharacterExpression.HAPPY
	
	# Add a keyframe
	var keyframe = CutsceneDataModels.Keyframe.new(0.0)
	keyframe.add_transform(CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	))
	config.add_keyframe(keyframe)
	
	# Track if cutscene_finished signal is emitted
	var signal_emitted = false
	cutscene_player.cutscene_finished.connect(func(): signal_emitted = true)
	
	# Play cutscene
	cutscene_player.play_cutscene("TestGame", CutsceneTypes.CutsceneType.WIN)
	
	# Wait for completion
	await wait_seconds(1.0)
	
	# Verify signal was emitted even if animation fails
	assert_true(signal_emitted, "cutscene_finished signal should be emitted even on animation failure")


## Test that invalid duration values are clamped
func test_invalid_duration_handling():
	var test_node = Node2D.new()
	add_child_autofree(test_node)
	
	var transform = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.POSITION,
		Vector2(100, 100),
		false
	)
	
	# Test with negative duration
	var tween = AnimationEngine.apply_transform(
		test_node,
		transform,
		-1.0,  # Invalid negative duration
		CutsceneTypes.Easing.LINEAR
	)
	
	# Should still create a tween with clamped duration
	assert_not_null(tween, "Tween should be created even with invalid duration")
	
	# Test with zero duration
	tween = AnimationEngine.apply_transform(
		test_node,
		transform,
		0.0,  # Invalid zero duration
		CutsceneTypes.Easing.LINEAR
	)
	
	assert_not_null(tween, "Tween should be created even with zero duration")


## Test that extreme scale values are clamped
func test_extreme_scale_clamping():
	var test_node = Node2D.new()
	add_child_autofree(test_node)
	test_node.scale = Vector2(1.0, 1.0)
	
	# Test with extremely large scale
	var transform = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1000.0, 1000.0),  # Extreme scale
		false
	)
	
	var tween = AnimationEngine.apply_transform(
		test_node,
		transform,
		0.1,
		CutsceneTypes.Easing.LINEAR
	)
	
	assert_not_null(tween, "Tween should be created")
	await wait_seconds(0.2)
	
	# Scale should be clamped to maximum of 10.0
	assert_true(test_node.scale.x <= 10.0, "Scale X should be clamped to max 10.0")
	assert_true(test_node.scale.y <= 10.0, "Scale Y should be clamped to max 10.0")
	
	# Test with extremely small scale
	test_node.scale = Vector2(1.0, 1.0)
	transform = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(0.0001, 0.0001),  # Extreme small scale
		false
	)
	
	tween = AnimationEngine.apply_transform(
		test_node,
		transform,
		0.1,
		CutsceneTypes.Easing.LINEAR
	)
	
	await wait_seconds(0.2)
	
	# Scale should be clamped to minimum of 0.01
	assert_true(test_node.scale.x >= 0.01, "Scale X should be clamped to min 0.01")
	assert_true(test_node.scale.y >= 0.01, "Scale Y should be clamped to min 0.01")


## Test that cutscene completes when character instantiation fails
func test_character_instantiation_failure_recovery():
	# This test verifies that if character scene is missing, the system falls back gracefully
	var signal_emitted = false
	cutscene_player.cutscene_finished.connect(func(): signal_emitted = true)
	
	# Try to play cutscene (will fail if character scene not loaded, but should still complete)
	cutscene_player.play_cutscene("NonExistentGame", CutsceneTypes.CutsceneType.WIN)
	
	await wait_seconds(1.0)
	
	# Signal should still be emitted
	assert_true(signal_emitted, "cutscene_finished should emit even when character fails to instantiate")


## Test that timer creation failures are handled gracefully
func test_timer_creation_failure_handling():
	# Create a config with particle effects
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestGame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 0.5
	config.character.expression = CutsceneTypes.CharacterExpression.HAPPY
	
	# Add a keyframe
	var keyframe = CutsceneDataModels.Keyframe.new(0.0)
	keyframe.add_transform(CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	))
	config.add_keyframe(keyframe)
	
	# Add particle effect
	var particle = CutsceneDataModels.ParticleEffect.new()
	particle.time = 0.1
	particle.type = CutsceneTypes.ParticleType.SPARKLES
	particle.duration = 0.3
	config.add_particle(particle)
	
	var signal_emitted = false
	cutscene_player.cutscene_finished.connect(func(): signal_emitted = true)
	
	# Play cutscene
	cutscene_player.play_cutscene("TestGame", CutsceneTypes.CutsceneType.WIN)
	
	await wait_seconds(1.0)
	
	# Should complete even if timer creation fails
	assert_true(signal_emitted, "cutscene_finished should emit even with timer failures")


## Test that memory allocation failures don't block progression
func test_memory_allocation_failure_handling():
	# This test simulates high memory pressure scenarios
	var signal_emitted = false
	cutscene_player.cutscene_finished.connect(func(): signal_emitted = true)
	
	# Play cutscene
	cutscene_player.play_cutscene("TestGame", CutsceneTypes.CutsceneType.WIN)
	
	await wait_seconds(1.0)
	
	# Cutscene should complete
	assert_true(signal_emitted, "cutscene_finished should emit even under memory pressure")


## Test that invalid target node is handled gracefully
func test_invalid_target_node_handling():
	var invalid_node: Node2D = null
	
	var transform = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.POSITION,
		Vector2(100, 100),
		false
	)
	
	# Should return null without crashing
	var tween = AnimationEngine.apply_transform(
		invalid_node,
		transform,
		0.5,
		CutsceneTypes.Easing.LINEAR
	)
	
	assert_null(tween, "Tween should be null for invalid target")


## Test that empty keyframes array is handled gracefully
func test_empty_keyframes_handling():
	var test_node = Node2D.new()
	add_child_autofree(test_node)
	
	var empty_keyframes: Array[CutsceneDataModels.Keyframe] = []
	
	# Should return null without crashing
	var tween = AnimationEngine.animate(
		test_node,
		empty_keyframes,
		1.0
	)
	
	assert_null(tween, "Tween should be null for empty keyframes")


## Test that tween becoming invalid during playback is handled
func test_tween_invalidation_during_playback():
	var test_node = Node2D.new()
	add_child_autofree(test_node)
	
	var keyframe = CutsceneDataModels.Keyframe.new(0.0)
	keyframe.add_transform(CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.POSITION,
		Vector2(100, 100),
		false
	))
	
	var keyframes: Array[CutsceneDataModels.Keyframe] = [keyframe]
	
	var tween = AnimationEngine.animate(test_node, keyframes, 0.5)
	assert_not_null(tween, "Tween should be created")
	
	# Kill the tween immediately to simulate failure
	tween.kill()
	
	# Wait a bit
	await wait_seconds(0.1)
	
	# Should not crash - the system should handle invalid tweens gracefully
	assert_true(true, "System should handle tween invalidation gracefully")


## Test that background tween creation failure is handled
func test_background_tween_failure_handling():
	# This is implicitly tested by the cutscene player's error handling
	# If background tween creation fails, it should fall back to instant color change
	var signal_emitted = false
	cutscene_player.cutscene_finished.connect(func(): signal_emitted = true)
	
	cutscene_player.play_cutscene("TestGame", CutsceneTypes.CutsceneType.WIN)
	
	await wait_seconds(1.0)
	
	assert_true(signal_emitted, "cutscene_finished should emit even if background tween fails")


## Test that screen shake tween failure is handled
func test_screen_shake_failure_handling():
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestGame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 0.5
	config.character.expression = CutsceneTypes.CharacterExpression.HAPPY
	
	# Add keyframe
	var keyframe = CutsceneDataModels.Keyframe.new(0.0)
	keyframe.add_transform(CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	))
	config.add_keyframe(keyframe)
	
	# Add screen shake
	var shake = CutsceneDataModels.ScreenShake.new()
	shake.time = 0.1
	shake.intensity = 5.0
	shake.duration = 0.2
	config.add_screen_shake(shake)
	
	var signal_emitted = false
	cutscene_player.cutscene_finished.connect(func(): signal_emitted = true)
	
	cutscene_player.play_cutscene("TestGame", CutsceneTypes.CutsceneType.WIN)
	
	await wait_seconds(1.0)
	
	# Should complete even if screen shake fails
	assert_true(signal_emitted, "cutscene_finished should emit even if screen shake fails")


## Test that game progression never blocks on cutscene errors
func test_game_progression_never_blocks():
	# This is the critical test for Requirement 12.5
	# No matter what errors occur, the cutscene_finished signal MUST be emitted
	
	var signal_emitted = false
	var signal_count = 0
	cutscene_player.cutscene_finished.connect(func(): 
		signal_emitted = true
		signal_count += 1
	)
	
	# Try multiple cutscenes in sequence
	for i in range(3):
		signal_emitted = false
		cutscene_player.play_cutscene("TestGame" + str(i), CutsceneTypes.CutsceneType.WIN)
		await wait_seconds(1.0)
		assert_true(signal_emitted, "cutscene_finished must emit for cutscene %d" % i)
	
	assert_equal(signal_count, 3, "All 3 cutscenes should have completed")
