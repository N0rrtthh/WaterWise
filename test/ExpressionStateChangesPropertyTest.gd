extends Node

## ═══════════════════════════════════════════════════════════════════
## EXPRESSION STATE CHANGES PROPERTY TEST
## ═══════════════════════════════════════════════════════════════════
## Property-based test for WaterDropletCharacter expression changes
## Feature: animated-cutscenes, Property 9: Expression State Changes
## **Validates: Requirements 4.2**
## ═══════════════════════════════════════════════════════════════════

var character: WaterDropletCharacter
var test_passed: int = 0
var test_failed: int = 0
var random_seed: int = 0


func _ready() -> void:
	# Set random seed for reproducibility
	random_seed = randi()
	seed(random_seed)
	
	print("\n" + "=".repeat(60))
	print("EXPRESSION STATE CHANGES PROPERTY TEST")
	print("Feature: animated-cutscenes, Property 9")
	print("Random Seed: " + str(random_seed))
	print("=".repeat(60) + "\n")
	
	# Load and instantiate character
	var character_scene = load("res://scenes/cutscenes/WaterDropletCharacter.tscn")
	if not character_scene:
		print("ERROR: Could not load WaterDropletCharacter scene")
		get_tree().quit()
		return
	
	character = character_scene.instantiate()
	add_child(character)
	
	# Wait for _ready
	await get_tree().process_frame
	
	# Run property test
	test_expression_state_changes_property()
	
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


func assert_eq(actual, expected, message: String) -> void:
	assert_test(actual == expected, message + " (expected: " + str(expected) + ", got: " + str(actual) + ")")


## Property Test: Expression State Changes
## For any valid expression, setting the character's expression should result
## in the character displaying that expression.
func test_expression_state_changes_property():
	print("\nPROPERTY TEST: Expression State Changes (100 iterations)")
	print("Testing that set_expression() correctly updates character expression\n")
	
	# All valid expressions from the Expression enum
	var all_expressions = [
		CutsceneTypes.CharacterExpression.HAPPY,
		CutsceneTypes.CharacterExpression.SAD,
		CutsceneTypes.CharacterExpression.SURPRISED,
		CutsceneTypes.CharacterExpression.DETERMINED,
		CutsceneTypes.CharacterExpression.WORRIED,
		CutsceneTypes.CharacterExpression.EXCITED
	]
	
	var expression_names = {
		CutsceneTypes.CharacterExpression.HAPPY: "HAPPY",
		CutsceneTypes.CharacterExpression.SAD: "SAD",
		CutsceneTypes.CharacterExpression.SURPRISED: "SURPRISED",
		CutsceneTypes.CharacterExpression.DETERMINED: "DETERMINED",
		CutsceneTypes.CharacterExpression.WORRIED: "WORRIED",
		CutsceneTypes.CharacterExpression.EXCITED: "EXCITED"
	}
	
	# Run 100 iterations with random expression selections
	for iteration in range(100):
		# Randomly select an expression
		var random_expression = all_expressions.pick_random()
		var expr_name = expression_names[random_expression]
		
		# Set the expression
		character.set_expression(random_expression)
		
		# Verify that get_expression() returns the correct expression
		var actual_expression = character.get_expression()
		
		assert_eq(
			actual_expression,
			random_expression,
			"Iteration " + str(iteration + 1) + ": Expression should be " + expr_name
		)
	
	print("\nProperty test completed: 100 iterations")
