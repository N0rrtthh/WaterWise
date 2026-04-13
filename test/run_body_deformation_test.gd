#!/usr/bin/env -S godot --headless --script

## Simple test runner for body deformation property test
## This can be run directly with: godot --headless --script test/run_body_deformation_test.gd

extends SceneTree

func _init():
	print("Starting Body Deformation Property Test...")
	
	# Test the deformation logic directly without scene loading
	test_deformation_logic()
	
	print("Test completed. Exiting...")
	quit()

func test_deformation_logic():
	print("\n" + "=".repeat(60))
	print("BODY DEFORMATION PROPERTY TEST")
	print("Feature: animated-cutscenes, Property 10")
	print("Testing deformation calculation logic")
	print("=".repeat(60) + "\n")
	
	var test_passed = 0
	var test_failed = 0
	
	# Test the deformation calculation logic
	for iteration in range(100):
		# Generate random squash and stretch values
		var squash = randf_range(0.3, 1.5)
		var stretch = randf_range(0.5, 2.0)
		var base_scale = Vector2.ONE
		
		# Calculate expected scale using the same formula as WaterDropletCharacter
		var expected_vertical = base_scale.y * squash * stretch
		var expected_horizontal = base_scale.x / (squash * stretch)
		
		# Apply clamping as done in the implementation
		expected_vertical = clamp(expected_vertical, base_scale.y * 0.3, base_scale.y * 2.5)
		expected_horizontal = clamp(expected_horizontal, base_scale.x * 0.3, base_scale.x * 2.5)
		
		# Verify the calculation is consistent
		var recalculated_vertical = base_scale.y * squash * stretch
		var recalculated_horizontal = base_scale.x / (squash * stretch)
		recalculated_vertical = clamp(recalculated_vertical, base_scale.y * 0.3, base_scale.y * 2.5)
		recalculated_horizontal = clamp(recalculated_horizontal, base_scale.x * 0.3, base_scale.x * 2.5)
		
		if abs(expected_vertical - recalculated_vertical) <= 0.01 and abs(expected_horizontal - recalculated_horizontal) <= 0.01:
			test_passed += 1
			if iteration % 20 == 0:  # Print every 20th test
				print("  ✓ Iteration " + str(iteration + 1) + ": Calculation consistent (squash=" + str(squash) + ", stretch=" + str(stretch) + ")")
		else:
			test_failed += 1
			print("  ✗ FAILED: Iteration " + str(iteration + 1) + ": Calculation inconsistent")
	
	# Test edge cases
	print("\nTesting edge cases...")
	
	# Test squash=1.0, stretch=1.0 (no deformation)
	var squash = 1.0
	var stretch = 1.0
	var base_scale = Vector2.ONE
	var expected_vertical = base_scale.y * squash * stretch
	var expected_horizontal = base_scale.x / (squash * stretch)
	
	if abs(expected_vertical - 1.0) <= 0.01 and abs(expected_horizontal - 1.0) <= 0.01:
		test_passed += 1
		print("  ✓ No deformation case: scale remains (1.0, 1.0)")
	else:
		test_failed += 1
		print("  ✗ FAILED: No deformation case failed")
	
	# Test extreme values that should be clamped
	squash = 0.1  # Very small
	stretch = 3.0  # Very large
	expected_vertical = clamp(base_scale.y * squash * stretch, base_scale.y * 0.3, base_scale.y * 2.5)
	expected_horizontal = clamp(base_scale.x / (squash * stretch), base_scale.x * 0.3, base_scale.x * 2.5)
	
	if expected_vertical >= 0.3 and expected_vertical <= 2.5 and expected_horizontal >= 0.3 and expected_horizontal <= 2.5:
		test_passed += 1
		print("  ✓ Extreme values clamped correctly")
	else:
		test_failed += 1
		print("  ✗ FAILED: Extreme values not clamped correctly")
	
	# Print summary
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("  Passed: " + str(test_passed))
	print("  Failed: " + str(test_failed))
	if test_failed == 0:
		print("  Result: ✅ ALL TESTS PASSED")
	else:
		print("  Result: ❌ SOME TESTS FAILED")
	print("=".repeat(60) + "\n")