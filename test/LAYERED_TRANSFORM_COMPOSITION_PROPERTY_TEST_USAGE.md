# Layered Transform Composition Property Test Usage

## Overview

This property-based test validates **Property 2: Layered Transform Composition** from the animated cutscenes design document. It ensures that when multiple transforms are applied simultaneously using `AnimationEngine.compose_transforms()`, all transforms are applied correctly without interfering with each other.

**Validates: Requirements 1.6**

## What This Test Validates

The test verifies that:

1. **Parallel Application**: Multiple transforms (position, rotation, scale) can be applied simultaneously
2. **Non-Interference**: Each transform type works independently without affecting others
3. **Consistency**: Parallel composition produces the same result as applying transforms individually
4. **Edge Cases**: Empty arrays, single transforms, and multiple same-type transforms are handled correctly

## Test Structure

### Main Property Tests

1. **`test_layered_transform_composition_property()`**
   - Generates 2-3 random transforms of different types
   - Applies them in parallel using `compose_transforms()`
   - Verifies each transform was applied correctly
   - Runs 100 iterations with random inputs

2. **`test_transform_independence_property()`**
   - Compares parallel vs. sequential application
   - Ensures both approaches produce equivalent results
   - Validates that transforms don't interfere with each other

3. **`test_compose_transforms_edge_cases_property()`**
   - Tests empty transform arrays (should return null)
   - Tests single transforms (should work like `apply_transform`)
   - Validates proper error handling

4. **`test_multiple_same_type_transforms_property()`**
   - Tests multiple transforms of the same type
   - Ensures system handles overwrites gracefully
   - Validates no crashes occur with unusual inputs

## Running the Test

### Command Line
```bash
# Run the specific property test
godot --headless --script test/run_layered_transform_composition_test.gd

# Run all animation engine tests
godot --headless --script test/run_animation_engine_tests.gd
```

### In Godot Editor
1. Open the project in Godot
2. Go to Project Settings > Plugins
3. Enable the GUT plugin
4. Run the test file: `test/LayeredTransformCompositionPropertyTest.gd`

## Expected Output

### Success Case
```
=== Layered Transform Composition Property Test ===
Testing Property 2: Layered Transform Composition
Validates: Requirements 1.6

Running test_layered_transform_composition_property...
✓ All 100 iterations passed
✓ Parallel transforms applied correctly
✓ No interference between transform types

Running test_transform_independence_property...
✓ All 50 iterations passed
✓ Parallel and sequential results match
✓ Transform independence verified

Running test_compose_transforms_edge_cases_property...
✓ All 20 iterations passed
✓ Edge cases handled correctly
✓ Proper error handling verified

Running test_multiple_same_type_transforms_property...
✓ All 30 iterations passed
✓ Multiple same-type transforms handled gracefully
✓ No crashes or invalid states

PASSED: 4/4 tests passed
```

### Failure Case
If the test fails, you'll see detailed information about which iteration failed and why:

```
FAILED: test_layered_transform_composition_property
Iteration 42: Parallel position X should match expected
Expected: 150.0, Actual: 75.0, Tolerance: 1.0

This indicates that position transforms are not being applied correctly
in parallel composition, possibly due to interference from other transforms.
```

## Test Data Generation

The test uses smart generators to create realistic test scenarios:

### Transform Generation
- **Position**: Random Vector2 in range (-200, 200)
- **Rotation**: Random float in range (-PI, PI)
- **Scale**: Random Vector2 in range (0.1, 3.0), clamped to (0.01, 10.0)
- **Relative Flag**: 50% chance of being relative vs. absolute

### Transform Combinations
- 2-3 different transform types per test
- Ensures all combinations are tested over multiple iterations
- Avoids duplicate types in main composition tests

## Integration with Animation Engine

This test directly validates the `AnimationEngine.compose_transforms()` method:

```gdscript
static func compose_transforms(
    target: Node2D,
    transforms: Array[CutsceneDataModels.Transform],
    duration: float
) -> Tween
```

The test ensures this method:
- Creates a parallel tween correctly
- Applies all transforms simultaneously
- Handles edge cases gracefully
- Maintains transform independence

## Debugging Failed Tests

If tests fail, check:

1. **AnimationEngine Implementation**: Ensure `compose_transforms()` sets `tween.set_parallel(true)`
2. **Transform Application**: Verify each transform type is handled correctly
3. **Timing Issues**: Ensure sufficient wait time for animations to complete
4. **Clamping Logic**: Check that scale clamping matches between test and implementation

## Property-Based Testing Benefits

This property-based approach provides:

- **Comprehensive Coverage**: Tests thousands of input combinations automatically
- **Edge Case Discovery**: Finds unusual scenarios that manual tests might miss
- **Regression Detection**: Catches when changes break existing functionality
- **Specification Validation**: Ensures the implementation matches the design requirements

## Related Files

- `scripts/cutscenes/AnimationEngine.gd` - Implementation being tested
- `test/TransformApplicationPropertyTest.gd` - Related property test for single transforms
- `test/AnimationEngineTest.gd` - Unit tests for specific scenarios
- `.kiro/specs/animated-cutscenes/design.md` - Property definitions and requirements