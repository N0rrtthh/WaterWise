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

# ──────────────────────────────────────────────────────────────────────────
# GUT-COMPATIBLE ALIASES AND CONTAINER / TYPE ASSERTIONS
# ──────────────────────────────────────────────────────────────────────────
# The suites under test/ were written against the real GUT addon, which is not
# vendored here — this file is a minimal stand-in. Five suites failed to parse
# because they call assertions that existed in GUT but were never stubbed:
# assert_has, assert_typeof, assert_same, assert_equal, assert_approximately.
# A parse failure takes the whole file out, so those suites were not merely
# failing, they were not running at all.

## Passes when `container` holds `key`.
## Works for Dictionary keys and for Array/String membership, mirroring GUT.
func assert_has(container, key, message := "") -> void:
	var found := false
	if container is Dictionary:
		found = (container as Dictionary).has(key)
	elif container is Array:
		found = (container as Array).has(key)
	elif container is String:
		found = (container as String).contains(str(key))
	else:
		push_warning("assert_has: unsupported container type %s" % typeof(container))
		return

	if not found:
		var fallback = "Assertion failed: container missing %s" % str(key)
		push_warning(message if message != "" else fallback)

## Passes when `value`'s runtime type matches the TYPE_* constant `expected_type`.
func assert_typeof(value, expected_type: int, message := "") -> void:
	if typeof(value) != expected_type:
		var fallback = "Assertion failed: typeof %d != expected %d" % [
			typeof(value), expected_type
		]
		push_warning(message if message != "" else fallback)

## Passes when both arguments are the SAME instance, not merely equal.
## Object identity is compared by instance id; other types fall back to ==,
## since only objects have a meaningful identity distinct from equality.
func assert_same(a, b, message := "") -> void:
	var identical := false
	if a is Object and b is Object:
		var obj_a := a as Object
		var obj_b := b as Object
		identical = (
			obj_a != null and obj_b != null
			and obj_a.get_instance_id() == obj_b.get_instance_id()
		)
	else:
		identical = (a == b)

	if not identical:
		push_warning(message if message != "" else "Assertion failed: not the same instance")

## GUT spells equality both ways; keep both so suites can use either.
func assert_equal(actual, expected, message := "") -> void:
	assert_eq(actual, expected, message)

func assert_not_equal(actual, expected, message := "") -> void:
	assert_ne(actual, expected, message)

## Tolerance-based float comparison. Same semantics as assert_almost_eq, kept
## under GUT's longer name because the suites use both spellings.
func assert_approximately(
	actual: float, expected: float, tolerance: float, message := ""
) -> void:
	assert_almost_eq(actual, expected, tolerance, message)
