extends Node

## ═══════════════════════════════════════════════════════════════════
## BODY DEFORMATION PROPERTY TEST
## ═══════════════════════════════════════════════════════════════════
## Property-based test for WaterDropletCharacter body deformation
## Feature: animated-cutscenes, Property 10: Body Deformation
## **Validates: Requirements 4.3**
## ═══════════════════════════════════════════════════════════════════

var character  # WaterDropletCharacter instance
var test_passed: int = 0
var test_failed: int = 0
var random_seed: int = 0


func _ready() -> void:
	# Set random seed for reproducibility
	random_seed = randi()
	seed(random_seed)
	
	print("\n" + "=".repeat(60))
	print("BODY DEFORMATION PROPERTY TEST")
	print("Feature: animated-cutscenes, Property 10")
	print("Random Seed: " + str(random_seed))
	print("=".repeat(60) + "\n")
	
	# Create character directly without scene file (for testing)
	character = WaterDropletCharacter.new()
	add_child(character)
	
	# Initialize character properties manually since we're not using the scene
	character.base_scale = Vector2.ONE
	character.scale = Vector2.ONE
	character.deformation_enabled = true
	
	# Wait for _ready
	await get_tree().process_frame
	
	# Run property test
	test_body_deformation_property()
	
	# Print summary
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("  Passed: " + str(test_passed))
	print("  Failed: " + str(test_failed))
	print("  Random Seed: " + str(random_seed))
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


func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	var diff = abs(actual - expected)
	assert_test(diff <= tolerance, message + " (expected: " + str(expected) + ", got: " + str(actual) + ", diff: " + str(diff) + ")")


func assert_gt(actual: float, threshold: float, message: String) -> void:
	assert_test(actual > threshold, message + " (" + str(actual) + " > " + str(threshold) + ")")


func assert_lt(actual: float, threshold: float, message: String) -> void:
	assert_test(actual < threshold, message + " (" + str(actual) + " < " + str(threshold) + ")")


## Property Test: Body Deformation
## For any squash and stretch values, applying deformation to the character
## should result in the character's scale being modified accordingly.
func test_body_deformation_property():
	print("\nPROPERTY TEST: Body Deformation (100 iterations)")
	print("Testing that apply_squash_stretch() correctly modifies character scale\n")
	
	# Run 100 iterations with random squash and stretch values
	for iteration in range(100):
		# Reset character to known state
		character.set_deformation_enabled(true)
		character.scale = Vector2.ONE
		character.base_scale = Vector2.ONE
		
		# Generate random squash and stretch values in reasonable ranges
		# Squash: 0.3 to 1.5 (compression factor)
		# Stretch: 0.5 to 2.0 (extension factor)
		var squash = randf_range(0.3, 1.5)
		var stretch = randf_range(0.5, 2.0)
		
		# Store original scale
		var original_scale = character.scale
		
		# Apply deformation
		character.apply_squash_stretch(squash, stretch)
		
		# Calculate expected scale based on the deformation formula
		# From WaterDropletCharacter.gd:
		# vertical_scale = base_scale.y * squash * stretch
		# horizontal_scale = base_scale.x / (squash * stretch)
		# Both clamped to [base * 0.3, base * 2.5]
		
		var expected_vertical = character.base_scale.y * squash * stretch
		var expected_horizontal = character.base_scale.x / (squash * stretch)
		
		# Apply clamping as done in the implementation
		expected_vertical = clamp(expected_vertical, character.base_scale.y * 0.3, character.base_scale.y * 2.5)
		expected_horizontal = clamp(expected_horizontal, character.base_scale.x * 0.3, character.base_scale.x * 2.5)
		
		# Verify scale was modified correctly
		assert_almost_eq(
			character.scale.y,
			expected_vertical,
			0.01,
			"Iteration " + str(iteration + 1) + ": Vertical scale (squash=" + str(squash) + ", stretch=" + str(stretch) + ")"
		)
		
		assert_almost_eq(
			character.scale.x,
			expected_horizontal,
			0.01,
			"Iteration " + str(iteration + 1) + ": Horizontal scale (squash=" + str(squash) + ", stretch=" + str(stretch) + ")"
		)
		
		# Additional property: Scale should be modified from original (unless both squash and stretch are 1.0)
		if not (is_equal_approx(squash, 1.0) and is_equal_approx(stretch, 1.0)):
			var scale_changed = not (is_equal_approx(character.scale.x, original_scale.x) and is_equal_approx(character.scale.y, original_scale.y))
			assert_test(
				scale_changed,
				"Iteration " + str(iteration + 1) + ": Scale should change when squash/stretch != 1.0"
			)
	
	print("\nProperty test completed: 100 iterations")
	
	# Additional test: Verify deformation can be disabled
	print("\nTesting deformation disable property...")
	character.scale = Vector2.ONE
	character.base_scale = Vector2.ONE
	var scale_before_disable = character.scale
	
	character.set_deformation_enabled(false)
	character.apply_squash_stretch(0.5, 1.5)
	
	assert_almost_eq(
		character.scale.x,
		scale_before_disable.x,
		0.01,
		"Scale X should not change when deformation is disabled"
	)
	
	assert_almost_eq(
		character.scale.y,
		scale_before_disable.y,
		0.01,
		"Scale Y should not change when deformation is disabled"
	)
