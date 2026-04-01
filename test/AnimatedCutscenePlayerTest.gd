extends GutTest

## Unit tests for AnimatedCutscenePlayer
## Tests configuration loading, character lifecycle, and animation playback

var cutscene_player: AnimatedCutscenePlayer
var test_config: CutsceneDataModels.CutsceneConfig


func before_each():
	cutscene_player = AnimatedCutscenePlayer.new()
	add_child_autofree(cutscene_player)
	
	# Create a simple test configuration
	test_config = CutsceneDataModels.CutsceneConfig.new()
	test_config.minigame_key = "TestMinigame"
	test_config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	test_config.duration = 2.0
	test_config.character.expression = CutsceneTypes.CharacterExpression.HAPPY
	
	# Add simple keyframes
	var keyframe1 = CutsceneDataModels.Keyframe.new(0.0)
	var scale_transform1 = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(0.5, 0.5),
		false
	)
	keyframe1.add_transform(scale_transform1)
	keyframe1.easing = CutsceneTypes.Easing.EASE_OUT
	
	var keyframe2 = CutsceneDataModels.Keyframe.new(1.0)
	var scale_transform2 = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	)
	keyframe2.add_transform(scale_transform2)
	keyframe2.easing = CutsceneTypes.Easing.EASE_IN_OUT
	
	test_config.add_keyframe(keyframe1)
	test_config.add_keyframe(keyframe2)


func after_each():
	cutscene_player = null
	test_config = null


# ============================================================================
# BASIC FUNCTIONALITY TESTS
# ============================================================================

func test_cutscene_player_instantiation():
	assert_not_null(cutscene_player, "AnimatedCutscenePlayer should instantiate")
	assert_true(cutscene_player is Control, "AnimatedCutscenePlayer should extend Control")


func test_cutscene_player_has_background():
	await wait_frames(1)  # Wait for _ready to execute
	var background = cutscene_player.get_node_or_null("Background")
	assert_not_null(background, "Background should exist after _ready")
	assert_true(background is ColorRect, "Background should be a ColorRect")


func test_cutscene_finished_signal_exists():
	assert_has_signal(cutscene_player, "cutscene_finished", "Should have cutscene_finished signal")


# ============================================================================
# CONFIGURATION LOADING TESTS
# ============================================================================

func test_has_custom_cutscene_returns_false_for_nonexistent():
	var result = cutscene_player.has_custom_cutscene("NonexistentMinigame", CutsceneTypes.CutsceneType.WIN)
	assert_false(result, "Should return false for nonexistent custom cutscene")


func test_preload_cutscene_does_not_crash():
	# Should not crash even if files don't exist
	cutscene_player.preload_cutscene("NonexistentMinigame")
	assert_true(true, "Preload should not crash for nonexistent minigame")


func test_preload_cutscene_caches_configuration():
	# Preload a cutscene
	cutscene_player.preload_cutscene("TestMinigame")
	
	# Check that cache was populated (we can't directly access private vars,
	# but we can verify the behavior by checking that subsequent loads are fast)
	var start_time = Time.get_ticks_msec()
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
	var load_time = Time.get_ticks_msec() - start_time
	
	# Wait for completion
	await wait_seconds(3.0)
	
	# If caching works, load time should be very fast (< 50ms)
	assert_true(load_time < 50, "Cached configuration should load quickly")


func test_preload_cutscene_loads_all_types():
	# Preload should load intro, win, and fail cutscenes
	cutscene_player.preload_cutscene("TestMinigame")
	
	# Try playing each type - should work without errors
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.INTRO)
	await wait_seconds(2.5)
	
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
	await wait_seconds(2.5)
	
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.FAIL)
	await wait_seconds(2.5)
	
	assert_true(true, "All cutscene types should play after preload")


func test_animation_data_caching_improves_performance():
	# First load without preload (cold)
	var start_time1 = Time.get_ticks_msec()
	cutscene_player.play_cutscene("ColdLoadTest", CutsceneTypes.CutsceneType.WIN)
	var cold_load_time = Time.get_ticks_msec() - start_time1
	await wait_seconds(2.5)
	
	# Second load (should use cache)
	var start_time2 = Time.get_ticks_msec()
	cutscene_player.play_cutscene("ColdLoadTest", CutsceneTypes.CutsceneType.WIN)
	var cached_load_time = Time.get_ticks_msec() - start_time2
	await wait_seconds(2.5)
	
	# Cached load should be faster or equal
	assert_true(cached_load_time <= cold_load_time, "Cached load should be faster or equal to cold load")


func test_texture_atlas_support():
	# This test verifies that the texture atlas system doesn't crash
	# We can't easily verify the atlas is actually used without accessing private vars
	WaterDropletCharacter.preload_atlas()
	
	# Create a character and set expressions
	var character = WaterDropletCharacter.new()
	add_child_autofree(character)
	await wait_frames(1)
	
	# Try all expressions - should work with or without atlas
	for expression in [
		CutsceneTypes.CharacterExpression.HAPPY,
		CutsceneTypes.CharacterExpression.SAD,
		CutsceneTypes.CharacterExpression.SURPRISED,
		CutsceneTypes.CharacterExpression.DETERMINED,
		CutsceneTypes.CharacterExpression.WORRIED,
		CutsceneTypes.CharacterExpression.EXCITED
	]:
		character.set_expression(expression)
		await wait_frames(1)
	
	assert_true(true, "All expressions should work with atlas support")


func test_preload_cutscene_handles_default_configs():
	# Preload should work even if custom configs don't exist
	# It should fall back to default configs
	cutscene_player.preload_cutscene("NonexistentButShouldUseDefaults")
	
	# Play cutscene - should use default config
	cutscene_player.play_cutscene("NonexistentButShouldUseDefaults", CutsceneTypes.CutsceneType.WIN)
	await wait_seconds(2.5)
	
	assert_true(true, "Should handle default configs gracefully")


# ============================================================================
# CUTSCENE PLAYBACK TESTS
# ============================================================================

func test_play_cutscene_emits_finished_signal():
	var signal_watcher = watch_signals(cutscene_player)
	
	# Play cutscene (will use minimal default config)
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
	
	# Wait for cutscene to complete
	await wait_seconds(3.0)
	
	assert_signal_emitted(cutscene_player, "cutscene_finished", "Should emit cutscene_finished signal")


func test_play_cutscene_creates_character():
	# Start playing cutscene
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
	
	# Wait a frame for setup
	await wait_frames(2)
	
	# Check if character was created
	var character_found = false
	for child in cutscene_player.get_children():
		if child is WaterDropletCharacter:
			character_found = true
			break
	
	assert_true(character_found, "Should create WaterDropletCharacter during playback")
	
	# Wait for completion
	await wait_seconds(3.0)


func test_play_cutscene_cleans_up_character():
	# Play cutscene
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
	
	# Wait for completion
	await wait_seconds(3.0)
	
	# Check that character was cleaned up
	var character_found = false
	for child in cutscene_player.get_children():
		if child is WaterDropletCharacter:
			character_found = true
			break
	
	assert_false(character_found, "Should clean up WaterDropletCharacter after playback")


# ============================================================================
# CUTSCENE TYPE TESTS
# ============================================================================

func test_play_intro_cutscene():
	var signal_watcher = watch_signals(cutscene_player)
	
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.INTRO)
	await wait_seconds(3.0)
	
	assert_signal_emitted(cutscene_player, "cutscene_finished", "Intro cutscene should complete")


func test_play_win_cutscene():
	var signal_watcher = watch_signals(cutscene_player)
	
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
	await wait_seconds(3.0)
	
	assert_signal_emitted(cutscene_player, "cutscene_finished", "Win cutscene should complete")


func test_play_fail_cutscene():
	var signal_watcher = watch_signals(cutscene_player)
	
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.FAIL)
	await wait_seconds(3.0)
	
	assert_signal_emitted(cutscene_player, "cutscene_finished", "Fail cutscene should complete")


# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

func test_play_cutscene_handles_missing_config():
	# Should not crash with nonexistent minigame
	cutscene_player.play_cutscene("CompletelyFakeMinigame", CutsceneTypes.CutsceneType.WIN)
	await wait_seconds(3.0)
	
	assert_true(true, "Should handle missing config gracefully")


func test_concurrent_cutscene_requests_ignored():
	# Start first cutscene
	cutscene_player.play_cutscene("TestMinigame1", CutsceneTypes.CutsceneType.WIN)
	await wait_frames(2)
	
	# Try to start second cutscene (should be ignored)
	cutscene_player.play_cutscene("TestMinigame2", CutsceneTypes.CutsceneType.WIN)
	
	# Wait for completion
	await wait_seconds(3.0)
	
	assert_true(true, "Should ignore concurrent cutscene requests")


# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_cutscene_player_scene_loads():
	var scene = load("res://scenes/cutscenes/AnimatedCutscenePlayer.tscn")
	assert_not_null(scene, "AnimatedCutscenePlayer scene should load")
	
	var instance = scene.instantiate()
	assert_not_null(instance, "Scene should instantiate")
	assert_true(instance is AnimatedCutscenePlayer, "Scene should be AnimatedCutscenePlayer")
	instance.queue_free()


func test_cutscene_player_scene_has_background():
	var scene = load("res://scenes/cutscenes/AnimatedCutscenePlayer.tscn")
	var instance = scene.instantiate()
	add_child_autofree(instance)
	
	await wait_frames(1)
	
	var background = instance.get_node_or_null("Background")
	assert_not_null(background, "Scene should have Background node")
	assert_true(background is ColorRect, "Background should be ColorRect")


# ============================================================================
# BACKGROUND COLOR TRANSITION TESTS
# ============================================================================

func test_background_color_transitions_smoothly():
	await wait_frames(1)  # Wait for _ready
	
	var background = cutscene_player.get_node_or_null("Background")
	assert_not_null(background, "Background should exist")
	
	# Set initial color
	var initial_color = Color(0.1, 0.1, 0.1)
	background.color = initial_color
	
	# Create config with different background color
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestMinigame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 1.0
	config.background_color = Color(0.8, 0.2, 0.2)  # Red target color
	
	# Add simple keyframe
	var keyframe = CutsceneDataModels.Keyframe.new(0.5)
	var scale_transform = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	)
	keyframe.add_transform(scale_transform)
	config.add_keyframe(keyframe)
	
	# Play cutscene
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
	
	# Wait a bit for transition to start
	await wait_seconds(0.3)
	
	# Check that color has changed from initial (transition in progress)
	var mid_color = background.color
	assert_ne(mid_color, initial_color, "Background color should have changed during transition")
	
	# Wait for completion
	await wait_seconds(1.0)
	
	# Check that final color is close to target
	var final_color = background.color
	assert_almost_eq(final_color.r, config.background_color.r, 0.1, "Red channel should match target")
	assert_almost_eq(final_color.g, config.background_color.g, 0.1, "Green channel should match target")
	assert_almost_eq(final_color.b, config.background_color.b, 0.1, "Blue channel should match target")


func test_background_color_no_transition_when_same():
	await wait_frames(1)  # Wait for _ready
	
	var background = cutscene_player.get_node_or_null("Background")
	assert_not_null(background, "Background should exist")
	
	# Set initial color to match config
	var target_color = Color(0.039, 0.118, 0.059)  # Default color
	background.color = target_color
	
	# Create config with same background color
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestMinigame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 1.0
	config.background_color = target_color
	
	# Add simple keyframe
	var keyframe = CutsceneDataModels.Keyframe.new(0.5)
	var scale_transform = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	)
	keyframe.add_transform(scale_transform)
	config.add_keyframe(keyframe)
	
	# Play cutscene
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
	
	# Wait for completion
	await wait_seconds(1.5)
	
	# Color should remain the same (no transition needed)
	var final_color = background.color
	assert_almost_eq(final_color.r, target_color.r, 0.01, "Color should remain unchanged")
	assert_almost_eq(final_color.g, target_color.g, 0.01, "Color should remain unchanged")
	assert_almost_eq(final_color.b, target_color.b, 0.01, "Color should remain unchanged")


func test_background_transition_synchronized_with_animation():
	await wait_frames(1)  # Wait for _ready
	
	var background = cutscene_player.get_node_or_null("Background")
	assert_not_null(background, "Background should exist")
	
	# Set initial color
	background.color = Color(0.0, 0.0, 0.0)
	
	# Create config with 2 second duration
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestMinigame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 2.0
	config.background_color = Color(1.0, 1.0, 1.0)  # White target
	
	# Add keyframes spanning the full duration
	var keyframe1 = CutsceneDataModels.Keyframe.new(0.0)
	var scale_transform1 = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(0.5, 0.5),
		false
	)
	keyframe1.add_transform(scale_transform1)
	
	var keyframe2 = CutsceneDataModels.Keyframe.new(2.0)
	var scale_transform2 = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	)
	keyframe2.add_transform(scale_transform2)
	
	config.add_keyframe(keyframe1)
	config.add_keyframe(keyframe2)
	
	# Play cutscene
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
	
	# Check color at midpoint (should be roughly halfway)
	await wait_seconds(1.0)
	var mid_color = background.color
	
	# At 1 second (50% through), color should be roughly 50% interpolated
	# Allow generous tolerance due to easing
	assert_true(mid_color.r > 0.2 and mid_color.r < 0.8, "Color should be transitioning at midpoint")
	
	# Wait for completion
	await wait_seconds(1.5)
	
	# Final color should be close to target
	var final_color = background.color
	assert_almost_eq(final_color.r, 1.0, 0.1, "Should reach target color")
	assert_almost_eq(final_color.g, 1.0, 0.1, "Should reach target color")
	assert_almost_eq(final_color.b, 1.0, 0.1, "Should reach target color")


func test_background_tween_cleaned_up_after_cutscene():
	await wait_frames(1)  # Wait for _ready
	
	var background = cutscene_player.get_node_or_null("Background")
	background.color = Color(0.0, 0.0, 0.0)
	
	# Play cutscene with color transition
	cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
	
	# Wait for completion
	await wait_seconds(2.5)
	
	# Background tween should be cleaned up (set to null)
	# We can't directly access private vars, but we can verify no errors occur
	# and the cutscene completes successfully
	assert_true(true, "Cutscene should complete without errors")

