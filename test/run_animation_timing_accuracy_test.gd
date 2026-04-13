extends SceneTree

## Runner script for Animation Timing Accuracy Property Test
## Usage: godot --headless --script test/run_animation_timing_accuracy_test.gd

func _init():
	# Load and run the test
	var test_scene = preload("res://test/AnimationTimingAccuracyPropertyTest.gd").new()
	root.add_child(test_scene)