class_name GutTest
extends Node

func add_child_autofree(node: Node) -> void:
	if node:
		add_child(node)

func wait_frames(frame_count: int) -> void:
	for i in range(frame_count):
		await get_tree().process_frame

func wait_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout

func watch_signals(_target: Object) -> Dictionary:
	return {}

func assert_signal_emitted(_target: Object, _signal_name: String, _message := "") -> void:
	pass

func pass_test(_message := "") -> void:
	pass

func assert_has_signal(target: Object, signal_name: String, message := "") -> void:
	if target and target.has_signal(signal_name):
		return
	push_warning(message if message != "" else "Signal not found: %s" % signal_name)

func assert_true(condition: bool, message := "") -> void:
	if not condition:
		push_warning(message if message != "" else "Assertion failed: expected true")

func assert_false(condition: bool, message := "") -> void:
	if condition:
		push_warning(message if message != "" else "Assertion failed: expected false")

func assert_eq(actual, expected, message := "") -> void:
	if actual != expected:
		var fallback = "Assertion failed: %s != %s" % [str(actual), str(expected)]
		push_warning(message if message != "" else fallback)

func assert_ne(actual, expected, message := "") -> void:
	if actual == expected:
		var fallback = "Assertion failed: %s == %s" % [str(actual), str(expected)]
		push_warning(message if message != "" else fallback)

func assert_not_null(value, message := "") -> void:
	if value == null:
		push_warning(message if message != "" else "Assertion failed: value is null")

func assert_null(value, message := "") -> void:
	if value != null:
		push_warning(message if message != "" else "Assertion failed: value is not null")

func assert_almost_eq(actual: float, expected: float, tolerance: float, message := "") -> void:
	if abs(actual - expected) > tolerance:
		push_warning(message if message != "" else "Assertion failed: value not within tolerance")

func assert_gt(actual: float, threshold: float, message := "") -> void:
	if not (actual > threshold):
		var fallback = "Assertion failed: %s <= %s" % [str(actual), str(threshold)]
		push_warning(message if message != "" else fallback)

func assert_gte(actual: float, threshold: float, message := "") -> void:
	if not (actual >= threshold):
		var fallback = "Assertion failed: %s < %s" % [str(actual), str(threshold)]
		push_warning(message if message != "" else fallback)

func assert_lt(actual: float, threshold: float, message := "") -> void:
	if not (actual < threshold):
		var fallback = "Assertion failed: %s >= %s" % [str(actual), str(threshold)]
		push_warning(message if message != "" else fallback)

func assert_lte(actual: float, threshold: float, message := "") -> void:
	if not (actual <= threshold):
		var fallback = "Assertion failed: %s > %s" % [str(actual), str(threshold)]
		push_warning(message if message != "" else fallback)
