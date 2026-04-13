extends Node

## ═══════════════════════════════════════════════════════════════════
## DEMO BUTTON CONTROLLER TEST
## ═══════════════════════════════════════════════════════════════════
## Unit tests for DemoButtonController helper class
## Tests button visibility logic and button finding functionality
## ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("DEMO BUTTON CONTROLLER TEST SUITE")
	print("=".repeat(60) + "\n")
	
	test_should_show_demo_buttons()
	test_find_demo_buttons_by_name()
	test_find_demo_buttons_by_group()
	test_find_demo_buttons_by_text()
	test_hide_demo_buttons()
	test_hide_demo_buttons_with_null_root()
	
	print("\n" + "=".repeat(60))
	print("ALL TESTS COMPLETED")
	print("=".repeat(60) + "\n")

func test_should_show_demo_buttons() -> void:
	print("TEST: Should Show Demo Buttons Logic")
	
	# Note: This test verifies the logic structure
	# Actual behavior depends on OS.is_debug_build() and MobileUIManager state
	var should_show = DemoButtonController.should_show_demo_buttons()
	
	# In debug builds, should typically return true
	# In production builds on mobile, should return false
	print("  Current should_show_demo_buttons: %s" % should_show)
	print("  Debug build: %s" % OS.is_debug_build())
	
	# Verify the method returns a boolean
	assert(typeof(should_show) == TYPE_BOOL, "should_show_demo_buttons should return bool")
	
	print("  ✓ Method returns boolean value\n")

func test_find_demo_buttons_by_name() -> void:
	print("TEST: Find Demo Buttons by Name")
	
	# Create test scene with demo buttons
	var root = Node.new()
	
	var algo_btn = Button.new()
	algo_btn.name = "algorithm_demo_btn"
	algo_btn.text = "Algorithm Demo"
	root.add_child(algo_btn)
	
	var gcounter_btn = Button.new()
	gcounter_btn.name = "gcounter_demo_btn"
	gcounter_btn.text = "G-Counter Demo"
	root.add_child(gcounter_btn)
	
	var research_btn = Button.new()
	research_btn.name = "research_dashboard_btn"
	research_btn.text = "Research Dashboard"
	root.add_child(research_btn)
	
	var normal_btn = Button.new()
	normal_btn.name = "play_button"
	normal_btn.text = "Play Game"
	root.add_child(normal_btn)
	
	# Find demo buttons
	var demo_buttons = DemoButtonController.find_demo_buttons(root)
	
	# Verify correct buttons found
	assert(demo_buttons.size() == 3, "Should find 3 demo buttons")
	assert(algo_btn in demo_buttons, "Should find algorithm demo button")
	assert(gcounter_btn in demo_buttons, "Should find gcounter demo button")
	assert(research_btn in demo_buttons, "Should find research dashboard button")
	assert(normal_btn not in demo_buttons, "Should not find normal play button")
	
	# Clean up
	root.queue_free()
	
	print("  ✓ Demo buttons found by name patterns\n")

func test_find_demo_buttons_by_group() -> void:
	print("TEST: Find Demo Buttons by Group")
	
	var root = Node.new()
	
	var demo_btn1 = Button.new()
	demo_btn1.name = "special_button_1"
	demo_btn1.text = "Special Feature"
	demo_btn1.add_to_group("demo_buttons")
	root.add_child(demo_btn1)
	
	var demo_btn2 = Button.new()
	demo_btn2.name = "special_button_2"
	demo_btn2.text = "Debug Feature"
	demo_btn2.add_to_group("debug_buttons")
	root.add_child(demo_btn2)
	
	var demo_btn3 = Button.new()
	demo_btn3.name = "special_button_3"
	demo_btn3.text = "Thesis Feature"
	demo_btn3.add_to_group("thesis_demo")
	root.add_child(demo_btn3)
	
	var normal_btn = Button.new()
	normal_btn.name = "normal_button"
	normal_btn.text = "Normal Button"
	root.add_child(normal_btn)
	
	# Find demo buttons
	var demo_buttons = DemoButtonController.find_demo_buttons(root)
	
	# Verify correct buttons found
	assert(demo_buttons.size() == 3, "Should find 3 demo buttons")
	assert(demo_btn1 in demo_buttons, "Should find button in demo_buttons group")
	assert(demo_btn2 in demo_buttons, "Should find button in debug_buttons group")
	assert(demo_btn3 in demo_buttons, "Should find button in thesis_demo group")
	assert(normal_btn not in demo_buttons, "Should not find normal button")
	
	# Clean up
	root.queue_free()
	
	print("  ✓ Demo buttons found by group membership\n")

func test_find_demo_buttons_by_text() -> void:
	print("TEST: Find Demo Buttons by Text Content")
	
	var root = Node.new()
	
	var btn1 = Button.new()
	btn1.name = "btn_1"
	btn1.text = "🔬 Algorithm Demo"
	root.add_child(btn1)
	
	var btn2 = Button.new()
	btn2.name = "btn_2"
	btn2.text = "📊 G-Counter CRDT Demo"
	root.add_child(btn2)
	
	var btn3 = Button.new()
	btn3.name = "btn_3"
	btn3.text = "📋 Research Dashboard"
	root.add_child(btn3)
	
	var btn4 = Button.new()
	btn4.name = "btn_4"
	btn4.text = "For Panelist Review"
	root.add_child(btn4)
	
	var normal_btn = Button.new()
	normal_btn.name = "play_btn"
	normal_btn.text = "Start Playing"
	root.add_child(normal_btn)
	
	# Find demo buttons
	var demo_buttons = DemoButtonController.find_demo_buttons(root)
	
	# Verify correct buttons found
	assert(demo_buttons.size() == 4, "Should find 4 demo buttons")
	assert(btn1 in demo_buttons, "Should find algorithm demo by text")
	assert(btn2 in demo_buttons, "Should find g-counter by text")
	assert(btn3 in demo_buttons, "Should find research dashboard by text")
	assert(btn4 in demo_buttons, "Should find panelist button by text")
	assert(normal_btn not in demo_buttons, "Should not find normal button")
	
	# Clean up
	root.queue_free()
	
	print("  ✓ Demo buttons found by text content\n")

func test_hide_demo_buttons() -> void:
	print("TEST: Hide Demo Buttons")
	
	var root = Node.new()
	add_child(root)  # Add to scene tree so queue_free works
	
	var demo_btn = Button.new()
	demo_btn.name = "algorithm_demo_btn"
	demo_btn.text = "Algorithm Demo"
	demo_btn.visible = true
	root.add_child(demo_btn)
	
	var normal_btn = Button.new()
	normal_btn.name = "play_button"
	normal_btn.text = "Play"
	normal_btn.visible = true
	root.add_child(normal_btn)
	
	# Hide demo buttons
	DemoButtonController.hide_demo_buttons(root)
	
	# Process frame to allow queue_free to execute
	await get_tree().process_frame
	
	# Verify demo button is hidden and queued for deletion
	assert(demo_btn.visible == false, "Demo button should be hidden")
	
	# Verify normal button is still visible
	assert(normal_btn.visible == true, "Normal button should remain visible")
	
	# Clean up
	root.queue_free()
	
	print("  ✓ Demo buttons hidden correctly\n")

func test_hide_demo_buttons_with_null_root() -> void:
	print("TEST: Hide Demo Buttons with Null Root")
	
	# Should not crash with null root
	DemoButtonController.hide_demo_buttons(null)
	
	print("  ✓ Handles null root gracefully\n")
