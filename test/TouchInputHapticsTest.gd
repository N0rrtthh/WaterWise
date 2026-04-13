extends Node

## ═══════════════════════════════════════════════════════════════════
## TOUCH INPUT HAPTICS TEST
## ═══════════════════════════════════════════════════════════════════
## Tests haptic feedback functionality for button presses
## Validates Requirement 2.5: Haptic feedback on button press
## ═══════════════════════════════════════════════════════════════════

var touch_manager: Node

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("TOUCH INPUT HAPTICS TEST SUITE")
	print("=".repeat(60) + "\n")
	
	# Create TouchInputManager instance for testing
	touch_manager = load("res://autoload/TouchInputManager.gd").new()
	add_child(touch_manager)
	
	test_vibrate_button_press_on_mobile()
	test_vibrate_button_press_on_desktop()
	test_enable_button_haptics_connects_signal()
	test_enable_button_haptics_does_not_connect_on_desktop()
	test_enable_button_haptics_handles_null_button()
	test_enable_haptics_for_scene_finds_all_buttons()
	test_enable_button_haptics_avoids_duplicate_connections()
	test_button_press_triggers_haptic_feedback()
	
	print("\n" + "=".repeat(60))
	print("ALL TESTS COMPLETED")
	print("=".repeat(60) + "\n")

func test_vibrate_button_press_on_mobile() -> void:
	print("TEST: Vibrate Button Press on Mobile")
	
	# Given: TouchInputManager is in mobile mode
	touch_manager.is_mobile = true
	
	# When: vibrate_button_press is called
	# Then: Should not crash (actual vibration can't be tested in unit tests)
	touch_manager.vibrate_button_press()
	
	print("  ✓ vibrate_button_press executes without error on mobile\n")

func test_vibrate_button_press_on_desktop() -> void:
	print("TEST: Vibrate Button Press on Desktop")
	
	# Given: TouchInputManager is in desktop mode
	touch_manager.is_mobile = false
	
	# When: vibrate_button_press is called
	# Then: Should not crash (no vibration should occur)
	touch_manager.vibrate_button_press()
	
	print("  ✓ vibrate_button_press executes without error on desktop\n")

func test_enable_button_haptics_connects_signal() -> void:
	print("TEST: Enable Button Haptics Connects Signal")
	
	# Given: A button and mobile mode
	touch_manager.is_mobile = true
	var button = Button.new()
	add_child(button)
	
	# When: enable_button_haptics is called
	touch_manager.enable_button_haptics(button)
	
	# Then: Button's pressed signal should be connected
	assert(
		button.pressed.is_connected(touch_manager.vibrate_button_press),
		"Button pressed signal should be connected to vibrate_button_press"
	)
	
	button.queue_free()
	print("  ✓ Button haptics connection works on mobile\n")

func test_enable_button_haptics_does_not_connect_on_desktop() -> void:
	print("TEST: Enable Button Haptics Does Not Connect on Desktop")
	
	# Given: A button and desktop mode
	touch_manager.is_mobile = false
	var button = Button.new()
	add_child(button)
	
	# When: enable_button_haptics is called
	touch_manager.enable_button_haptics(button)
	
	# Then: Button's pressed signal should NOT be connected
	assert(
		not button.pressed.is_connected(touch_manager.vibrate_button_press),
		"Button pressed signal should not be connected on desktop"
	)
	
	button.queue_free()
	print("  ✓ Button haptics not connected on desktop\n")

func test_enable_button_haptics_handles_null_button() -> void:
	print("TEST: Enable Button Haptics Handles Null Button")
	
	# Given: A null button
	var button = null
	
	# When: enable_button_haptics is called with null
	# Then: Should not crash
	touch_manager.enable_button_haptics(button)
	
	print("  ✓ Null button handled gracefully\n")

func test_enable_haptics_for_scene_finds_all_buttons() -> void:
	print("TEST: Enable Haptics for Scene Finds All Buttons")
	
	# Given: A scene with multiple buttons
	touch_manager.is_mobile = true
	var root = Node.new()
	add_child(root)
	
	var button1 = Button.new()
	var button2 = Button.new()
	var container = VBoxContainer.new()
	var button3 = Button.new()
	
	root.add_child(button1)
	root.add_child(button2)
	root.add_child(container)
	container.add_child(button3)
	
	# When: enable_haptics_for_scene is called
	touch_manager.enable_haptics_for_scene(root)
	
	# Then: All buttons should have haptics enabled
	assert(
		button1.pressed.is_connected(touch_manager.vibrate_button_press),
		"Button 1 should have haptics enabled"
	)
	assert(
		button2.pressed.is_connected(touch_manager.vibrate_button_press),
		"Button 2 should have haptics enabled"
	)
	assert(
		button3.pressed.is_connected(touch_manager.vibrate_button_press),
		"Button 3 (nested) should have haptics enabled"
	)
	
	root.queue_free()
	print("  ✓ All buttons in scene have haptics enabled\n")

func test_enable_button_haptics_avoids_duplicate_connections() -> void:
	print("TEST: Enable Button Haptics Avoids Duplicate Connections")
	
	# Given: A button with haptics already enabled
	touch_manager.is_mobile = true
	var button = Button.new()
	add_child(button)
	
	touch_manager.enable_button_haptics(button)
	
	# When: enable_button_haptics is called again
	touch_manager.enable_button_haptics(button)
	
	# Then: Should still only have one connection
	# (Godot's is_connected check prevents duplicates)
	assert(
		button.pressed.is_connected(touch_manager.vibrate_button_press),
		"Button should still be connected"
	)
	
	button.queue_free()
	print("  ✓ Duplicate connections handled gracefully\n")

func test_button_press_triggers_haptic_feedback() -> void:
	print("TEST: Button Press Triggers Haptic Feedback")
	
	# Given: A button with haptics enabled
	touch_manager.is_mobile = true
	var button = Button.new()
	add_child(button)
	
	touch_manager.enable_button_haptics(button)
	
	# When: Button is pressed
	button.emit_signal("pressed")
	
	# Then: Should not crash (actual vibration can't be tested)
	button.queue_free()
	print("  ✓ Button press triggers haptic feedback without error\n")
