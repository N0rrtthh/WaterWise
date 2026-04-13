extends Node

## ═══════════════════════════════════════════════════════════════════
## WATER DROPLET CHARACTER TEST
## ═══════════════════════════════════════════════════════════════════
## Unit tests for WaterDropletCharacter
## Feature: animated-cutscenes
## Tests Requirements: 4.1, 4.2, 4.3, 4.5, 1.1
## ═══════════════════════════════════════════════════════════════════

var character: WaterDropletCharacter
var test_passed: int = 0
var test_failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("WATER DROPLET CHARACTER TEST SUITE")
	print("=".repeat(60) + "\n")
	
	# Load and instantiate character
	var character_scene = load("res://scenes/cutscenes/WaterDropletCharacter.tscn")
	if not character_scene:
		print("ERROR: Could not load WaterDropletCharacter scene")
		return
	
	character = character_scene.instantiate()
	add_child(character)
	
	# Wait for _ready
	await get_tree().process_frame
	
	# Run tests
	test_character_initializes_with_determined_expression()
	test_set_expression_changes_current_expression()
	test_all_expression_types()
	test_deformation_enabled_by_default()
	test_disable_deformation_resets_scale()
	test_squash_stretch_modifies_scale()
	test_stretch_modifies_scale()
	test_deformation_clamped()
	test_deformation_disabled_does_nothing()
	test_reset_restores_default_state()
	test_character_has_required_nodes()
	test_base_scale_stored()
	
	# Print summary
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("  Passed: " + str(test_passed))
	print("  Failed: " + str(test_failed))
	print("=".repeat(60) + "\n")
	
	# Cleanup
	character.queue_free()
	get_tree().quit()


func assert_test(condition: bool, message: String) -> void:
	if condition:
		test_passed += 1
		print("  ✓ " + message)
	else:
		test_failed += 1
		print("  ✗ FAILED: " + message)


func assert_eq(actual, expected, message: String) -> void:
	assert_test(actual == expected, message + " (expected: " + str(expected) + ", got: " + str(actual) + ")")


func assert_ne(actual, unexpected, message: String) -> void:
	assert_test(actual != unexpected, message)


func assert_lt(actual, threshold, message: String) -> void:
	assert_test(actual < threshold, message + " (" + str(actual) + " < " + str(threshold) + ")")


func assert_gt(actual, threshold, message: String) -> void:
	assert_test(actual > threshold, message + " (" + str(actual) + " > " + str(threshold) + ")")


func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	var diff = abs(actual - expected)
	assert_test(diff <= tolerance, message + " (diff: " + str(diff) + ", tolerance: " + str(tolerance) + ")")


func assert_not_null(value, message: String) -> void:
	assert_test(value != null, message)


func assert_true(condition: bool, message: String) -> void:
	assert_test(condition, message)


## Test: Character initializes with default expression
func test_character_initializes_with_determined_expression():
	print("\nTEST: Character initializes with DETERMINED expression")
	assert_eq(character.get_expression(), CutsceneTypes.CharacterExpression.DETERMINED,
		"Character should initialize with DETERMINED expression")


## Test: Setting expression changes current expression
func test_set_expression_changes_current_expression():
	print("\nTEST: Setting expression changes current expression")
	
	character.set_expression(CutsceneTypes.CharacterExpression.HAPPY)
	assert_eq(character.get_expression(), CutsceneTypes.CharacterExpression.HAPPY,
		"Expression should change to HAPPY")
	
	character.set_expression(CutsceneTypes.CharacterExpression.SAD)
	assert_eq(character.get_expression(), CutsceneTypes.CharacterExpression.SAD,
		"Expression should change to SAD")


## Test: All expression types can be set
func test_all_expression_types():
	print("\nTEST: All expression types can be set")
	
	var expressions = [
		CutsceneTypes.CharacterExpression.HAPPY,
		CutsceneTypes.CharacterExpression.SAD,
		CutsceneTypes.CharacterExpression.SURPRISED,
		CutsceneTypes.CharacterExpression.DETERMINED,
		CutsceneTypes.CharacterExpression.WORRIED,
		CutsceneTypes.CharacterExpression.EXCITED
	]
	
	for expr in expressions:
		character.set_expression(expr)
		assert_eq(character.get_expression(), expr,
			"Should be able to set expression: " + str(expr))


## Test: Deformation is enabled by default
func test_deformation_enabled_by_default():
	print("\nTEST: Deformation is enabled by default")
	assert_true(character.deformation_enabled,
		"Deformation should be enabled by default")


## Test: Disabling deformation resets scale
func test_disable_deformation_resets_scale():
	print("\nTEST: Disabling deformation resets scale")
	
	var original_scale = character.scale
	
	# Apply some deformation
	character.apply_squash_stretch(0.5, 1.5)
	
	# Verify scale changed
	assert_ne(character.scale, original_scale,
		"Scale should change after applying squash/stretch")
	
	# Disable deformation
	character.set_deformation_enabled(false)
	
	# Verify scale reset
	assert_almost_eq(character.scale.x, original_scale.x, 0.01,
		"Scale X should reset to original")
	assert_almost_eq(character.scale.y, original_scale.y, 0.01,
		"Scale Y should reset to original")


## Test: Squash and stretch modifies scale
func test_squash_stretch_modifies_scale():
	print("\nTEST: Squash modifies scale")
	
	# Reset to known state
	character.set_deformation_enabled(true)
	character.scale = Vector2.ONE
	character.base_scale = Vector2.ONE
	
	var original_scale = character.scale
	
	# Apply squash (compress vertically)
	character.apply_squash_stretch(0.5, 1.0)
	
	# Vertical scale should decrease, horizontal should increase
	assert_lt(character.scale.y, original_scale.y,
		"Squash should decrease vertical scale")
	assert_gt(character.scale.x, original_scale.x,
		"Squash should increase horizontal scale to preserve volume")


## Test: Stretch modifies scale
func test_stretch_modifies_scale():
	print("\nTEST: Stretch modifies scale")
	
	# Reset to known state
	character.set_deformation_enabled(true)
	character.scale = Vector2.ONE
	character.base_scale = Vector2.ONE
	
	var original_scale = character.scale
	
	# Apply stretch (extend vertically)
	character.apply_squash_stretch(1.0, 1.5)
	
	# Vertical scale should increase, horizontal should decrease
	assert_gt(character.scale.y, original_scale.y,
		"Stretch should increase vertical scale")
	assert_lt(character.scale.x, original_scale.x,
		"Stretch should decrease horizontal scale to preserve volume")


## Test: Deformation is clamped to reasonable values
func test_deformation_clamped():
	print("\nTEST: Deformation is clamped to reasonable values")
	
	# Reset to known state
	character.set_deformation_enabled(true)
	character.scale = Vector2.ONE
	character.base_scale = Vector2.ONE
	
	var original_scale = character.scale
	
	# Apply extreme squash
	character.apply_squash_stretch(0.01, 1.0)
	
	# Scale should be clamped, not go to near-zero
	assert_gt(character.scale.y, original_scale.y * 0.2,
		"Extreme squash should be clamped to reasonable minimum")
	
	# Reset
	character.scale = Vector2.ONE
	
	# Apply extreme stretch
	character.apply_squash_stretch(1.0, 10.0)
	
	# Scale should be clamped, not go to extreme values
	assert_lt(character.scale.y, original_scale.y * 3.0,
		"Extreme stretch should be clamped to reasonable maximum")


## Test: Deformation does nothing when disabled
func test_deformation_disabled_does_nothing():
	print("\nTEST: Deformation does nothing when disabled")
	
	character.set_deformation_enabled(false)
	var scale_before = character.scale
	
	character.apply_squash_stretch(0.5, 1.5)
	
	assert_eq(character.scale, scale_before,
		"Scale should not change when deformation is disabled")


## Test: Reset restores default state
func test_reset_restores_default_state():
	print("\nTEST: Reset restores default state")
	
	# Modify character state
	character.set_expression(CutsceneTypes.CharacterExpression.EXCITED)
	character.position = Vector2(100, 100)
	character.rotation = 1.5
	character.scale = Vector2(2.0, 2.0)
	
	# Reset
	character.reset()
	
	# Verify default state
	assert_eq(character.get_expression(), CutsceneTypes.CharacterExpression.DETERMINED,
		"Expression should reset to DETERMINED")
	assert_eq(character.position, Vector2.ZERO,
		"Position should reset to zero")
	assert_eq(character.rotation, 0.0,
		"Rotation should reset to zero")


## Test: Character has required child nodes
func test_character_has_required_nodes():
	print("\nTEST: Character has required child nodes")
	
	assert_not_null(character.body_sprite, "Character should have body_sprite")
	assert_not_null(character.expression_sprite, "Character should have expression_sprite")
	assert_not_null(character.particle_container, "Character should have particle_container")


## Test: Base scale is stored on ready
func test_base_scale_stored():
	print("\nTEST: Base scale is stored on ready")
	
	# The character should have stored its initial scale
	assert_not_null(character.base_scale, "Base scale should be stored")
