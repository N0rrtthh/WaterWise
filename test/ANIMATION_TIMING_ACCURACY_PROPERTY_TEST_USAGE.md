# Animation Timing Accuracy Property Test Usage Guide

## Overview

This document describes the property-based test for animation timing accuracy in the AnimationEngine component, implementing **Property 3: Animation Timing Accuracy** which validates **Requirements 1.7, 6.7, 14.6**.

## Property Definition

**Property 3: Animation Timing Accuracy**
> For any animation with a specified duration, the animation should complete within 5% of the specified duration (accounting for frame timing variance).

## Test Files

- **Main Test**: `test/AnimationTimingAccuracyPropertyTest.gd` - Standalone property test
- **Runner**: `test/run_animation_timing_accuracy_test.gd` - Headless test runner
- **Usage Guide**: `test/ANIMATION_TIMING_ACCURACY_PROPERTY_TEST_USAGE.md` - This file

## Running the Tests

### Option 1: Standalone Runner (Recommended)
```bash
# Run headless test (requires Godot in PATH)
godot --headless --script test/run_animation_timing_accuracy_test.gd
```

### Option 2: Manual Verification
The test logic can be verified by examining the timing calculations in the standalone runner.

## Test Coverage

### 1. Single Transform Timing Accuracy Test
- **Iterations**: 100 random test cases
- **Duration Range**: 0.1s to 5.0s
- **Transform Types**: Position, Rotation, Scale (random)
- **Easing Functions**: All 7 easing types (random)
- **Validation**: Actual duration within 5% of expected duration

### 2. Parallel Transform Timing Accuracy Test
- **Iterations**: 50 test cases with multiple transforms
- **Duration Range**: 0.2s to 3.0s
- **Transforms**: 2-3 simultaneous transforms of different types
- **Validation**: Parallel execution doesn't affect timing accuracy

### 3. Keyframe Sequence Timing Accuracy Test
- **Iterations**: 30 test cases with full sequences
- **Duration Range**: 1.5s to 4.0s (cutscene bounds per Requirement 14.6)
- **Keyframes**: 2-5 keyframes per sequence
- **Transforms**: 1-2 transforms per keyframe
- **Validation**: Total sequence duration matches expected

### 4. Easing Timing Consistency Test
- **Coverage**: All 7 easing functions individually
- **Iterations**: 10 per easing function
- **Duration Range**: 0.5s to 2.0s
- **Validation**: Easing curves don't affect total duration

### 5. Frame Timing Variance Test
- **Scenarios**: Normal, light, and medium computational load
- **Iterations**: 10 per scenario
- **Duration Range**: 0.5s to 1.5s
- **Validation**: Consistent timing across different frame rates

## Timing Measurement

### High-Precision Timing
```gdscript
# Uses system time for millisecond precision
var start_time = Time.get_time_dict_from_system()
var start_msec = start_time.hour * 3600000 + start_time.minute * 60000 + 
                 start_time.second * 1000 + start_time.millisecond

# ... animation execution ...

var end_time = Time.get_time_dict_from_system()
var end_msec = end_time.hour * 3600000 + end_time.minute * 60000 + 
               end_time.second * 1000 + end_time.millisecond
var actual_duration = (end_msec - start_msec) / 1000.0
```

### Tolerance Calculation
```gdscript
func assert_timing_accuracy(actual: float, expected: float, tolerance_percent: float):
    var tolerance = expected * (tolerance_percent / 100.0)
    var diff = abs(actual - expected)
    var within_tolerance = diff <= tolerance
```

## Test Generators

### Random Transform Generator
```gdscript
func _generate_random_transform() -> CutsceneDataModels.Transform:
    # Generates random position, rotation, or scale transforms
    # Includes both absolute and relative modes
    # Used for timing tests (values don't affect timing)
```

### Random Easing Generator
```gdscript
func _generate_random_easing() -> CutsceneTypes.Easing:
    # Randomly selects from all 7 easing functions
    # Tests that easing curves don't affect total duration
```

### Keyframe Sequence Generator
```gdscript
# Generates 2-5 keyframes with evenly distributed timing
# Each keyframe gets 1-2 random transforms
# Total duration matches expected sequence length
```

## Requirements Validation

### Requirement 1.7: Timing Controls for Animation Speed and Duration
✅ **Validated** - Tests verify that specified durations are respected within 5% tolerance across all animation types and easing functions.

### Requirement 6.7: Cutscene Timing Maintenance
✅ **Validated** - Tests verify that cutscene sequences complete within expected timing bounds (1.5s to 4.0s) regardless of complexity.

### Requirement 14.6: Consistent Frame Timing Across All Devices
✅ **Validated** - Tests verify that timing remains consistent even under different computational loads that simulate varying frame rates.

## Tolerance Specifications

### Standard Tolerance: 5%
- **Single Transforms**: 5% tolerance for individual animations
- **Parallel Transforms**: 5% tolerance for simultaneous animations
- **Keyframe Sequences**: 5% tolerance for full cutscene sequences
- **Easing Functions**: 5% tolerance regardless of easing curve

### Frame Variance Tolerance: 8%
- **Different Loads**: 8% tolerance when simulating frame rate variance
- **Accounts For**: System scheduling, garbage collection, frame drops
- **Still Strict**: Ensures timing doesn't degrade significantly

## Edge Cases Tested

1. **Very Short Durations**: 0.1s minimum duration
2. **Long Durations**: Up to 5.0s for stress testing
3. **Cutscene Bounds**: 1.5s to 4.0s as per requirements
4. **Complex Sequences**: Multiple keyframes with multiple transforms
5. **Computational Load**: Simulated frame rate variations
6. **Day Rollover**: Handles midnight time rollover (rare but possible)

## Expected Results

When the test passes, it confirms:
- Animation durations are accurate within 5% tolerance
- Parallel transforms don't affect timing
- Keyframe sequences maintain total duration accuracy
- Easing functions don't alter total animation time
- Timing remains consistent across different frame rates
- System meets cutscene timing requirements (1.7, 6.7, 14.6)

## Performance Implications

### Timing Accuracy Benefits
- **Predictable UX**: Players know how long cutscenes will take
- **Audio Sync**: Sound effects can be precisely timed
- **Game Flow**: Consistent pacing across all devices
- **Skip Functionality**: Accurate duration for skip timing

### Frame Rate Independence
- **60 FPS Target**: Animations complete on time regardless of frame rate
- **Low-End Devices**: Timing accuracy maintained even with frame drops
- **Consistent Experience**: Same timing on all supported hardware

## Troubleshooting

### Common Issues
1. **System Clock Changes**: Can affect timing measurements
   - Solution: Tests handle day rollover automatically
2. **High System Load**: May cause timing variance
   - Solution: 8% tolerance for frame variance scenarios
3. **Tween Creation Failures**: Invalid parameters
   - Solution: Null checks and error handling

### Debug Output
The test provides detailed output including:
- Timing measurements for each iteration
- Tolerance calculations and pass/fail status
- Summary statistics across all test scenarios
- Performance under different load conditions

## Integration Notes

This property test integrates with:
- **AnimationEngine.gd**: Core animation timing logic
- **Tween System**: Godot's built-in animation system
- **CutsceneDataModels.gd**: Keyframe and transform structures
- **System Time**: High-precision timing measurement

The test validates that the AnimationEngine provides accurate timing control as specified in the requirements, ensuring predictable and consistent animation behavior across all supported devices and scenarios.

## Mathematical Foundation

### Timing Accuracy Formula
```
tolerance = expected_duration × (tolerance_percent / 100.0)
is_accurate = |actual_duration - expected_duration| ≤ tolerance
```

### Frame Rate Independence
The test verifies that animation timing is independent of frame rate by:
1. Testing under different computational loads
2. Measuring wall-clock time rather than frame count
3. Ensuring Godot's Tween system maintains accuracy

This mathematical approach ensures that **Property 3: Animation Timing Accuracy** holds true across all valid inputs and system conditions.