extends Node

## ═══════════════════════════════════════════════════════════════════
## ORIENTATION DETECTION TEST SUITE
## ═══════════════════════════════════════════════════════════════════
## Tests for MobileUIManager orientation detection in _process()
## Validates: Requirements 5.1, 5.2, 5.3
## ═══════════════════════════════════════════════════════════════════

var test_passed: bool = false
var orientation_signal_received: bool = false
var signal_orientation: bool = false

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("ORIENTATION DETECTION TEST SUITE")
	print("=".repeat(60) + "\n")
	
	# Enable mobile mode for testing
	MobileUIManager.enable_debug_mobile_mode(true)
	
	# Run tests
	await test_orientation_detection_portrait_to_landscape()
	await test_orientation_detection_landscape_to_portrait()
	await test_orientation_signal_emission()
	await test_orientation_change_timing()
	
	print("\n" + "=".repeat(60))
	print("ALL TESTS COMPLETED")
	print("=".repeat(60) + "\n")
	
	# Exit after tests
	get_tree().quit()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ORIENTATION DETECTION TESTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func test_orientation_detection_portrait_to_landscape() -> void:
	print("TEST: Orientation Detection - Portrait to Landscape")
	
	# Set viewport to portrait (600x800)
	get_viewport().size = Vector2i(600, 800)
	await get_tree().create_timer(0.6).timeout  # Wait for orientation change timer
	
	var initial_orientation = MobileUIManager.is_portrait_orientation()
	assert(initial_orientation == true, "Initial orientation should be portrait")
	
	# Change to landscape (800x600)
	get_viewport().size = Vector2i(800, 600)
	await get_tree().create_timer(0.6).timeout  # Wait for orientation change timer
	
	var new_orientation = MobileUIManager.is_portrait_orientation()
	assert(new_orientation == false, "New orientation should be landscape")
	
	print("  ✓ Orientation changed from portrait to landscape\n")

func test_orientation_detection_landscape_to_portrait() -> void:
	print("TEST: Orientation Detection - Landscape to Portrait")
	
	# Set viewport to landscape (800x600)
	get_viewport().size = Vector2i(800, 600)
	await get_tree().create_timer(0.6).timeout  # Wait for orientation change timer
	
	var initial_orientation = MobileUIManager.is_portrait_orientation()
	assert(initial_orientation == false, "Initial orientation should be landscape")
	
	# Change to portrait (600x800)
	get_viewport().size = Vector2i(600, 800)
	await get_tree().create_timer(0.6).timeout  # Wait for orientation change timer
	
	var new_orientation = MobileUIManager.is_portrait_orientation()
	assert(new_orientation == true, "New orientation should be portrait")
	
	print("  ✓ Orientation changed from landscape to portrait\n")

func test_orientation_signal_emission() -> void:
	print("TEST: Orientation Signal Emission")
	
	# Reset signal tracking
	orientation_signal_received = false
	signal_orientation = false
	
	# Connect to orientation_changed signal
	if not MobileUIManager.orientation_changed.is_connected(_on_orientation_changed):
		MobileUIManager.orientation_changed.connect(_on_orientation_changed)
	
	# Set viewport to portrait
	get_viewport().size = Vector2i(600, 800)
	await get_tree().create_timer(0.6).timeout
	
	# Change to landscape
	get_viewport().size = Vector2i(800, 600)
	await get_tree().create_timer(0.6).timeout
	
	assert(orientation_signal_received == true, "orientation_changed signal should be emitted")
	assert(signal_orientation == false, "Signal should indicate landscape orientation")
	
	print("  ✓ orientation_changed signal emitted correctly\n")

func test_orientation_change_timing() -> void:
	print("TEST: Orientation Change Timing - Within 0.5 seconds")
	
	# Reset signal tracking
	orientation_signal_received = false
	var start_time = Time.get_ticks_msec()
	
	# Set viewport to portrait
	get_viewport().size = Vector2i(600, 800)
	await get_tree().create_timer(0.6).timeout
	
	# Change to landscape and measure time
	start_time = Time.get_ticks_msec()
	get_viewport().size = Vector2i(800, 600)
	
	# Wait for signal
	while not orientation_signal_received and (Time.get_ticks_msec() - start_time) < 1000:
		await get_tree().process_frame
	
	var elapsed_time = Time.get_ticks_msec() - start_time
	
	assert(orientation_signal_received == true, "orientation_changed signal should be emitted")
	assert(elapsed_time <= 600, "Orientation change should occur within 0.5 seconds (600ms with buffer), got %sms" % elapsed_time)
	
	print("  ✓ Orientation change triggered within 0.5 seconds (%sms)\n" % elapsed_time)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNAL HANDLERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_orientation_changed(is_portrait: bool) -> void:
	orientation_signal_received = true
	signal_orientation = is_portrait
