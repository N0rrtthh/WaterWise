extends SceneTree

## ═══════════════════════════════════════════════════════════════════
## TEST SCRIPT CHECK — instantiate every test/*.gd inside a real boot
## ═══════════════════════════════════════════════════════════════════
## ParseCheckAll.gd loads each script with CACHE_MODE_IGNORE and in isolation,
## which makes any script that touches an autoload or a `class_name` from
## another file look broken. This tool runs with autoloads present and simply
## asks: can this script be instantiated?
##
## Usage:
##   Godot_console.exe --headless --path <project> --script tools/TestScriptCheck.gd

const TEST_DIR := "res://test"

func _initialize() -> void:
	var paths := _collect(TEST_DIR)
	paths.sort()

	print("=== TEST SCRIPT CHECK: %d scripts ===" % paths.size())

	var failures: PackedStringArray = PackedStringArray()
	var skipped: int = 0
	for path in paths:
		var script := load(path) as GDScript
		if script == null:
			failures.append("LOAD_FAILED     " + path)
			continue
		if not script.can_instantiate():
			failures.append("NO_INSTANTIATE  " + path)
			continue

		# Standalone `extends SceneTree` runners are verified by load +
		# can_instantiate() only. Calling new() on one is actively harmful here:
		# their _init() *is* the test suite, so it would run inside this
		# process, and the extra SceneTree owns viewport/canvas/scenario RIDs
		# that nothing in this harness can release (they are MainLoop, not
		# Node, so free() below never applied). That produced ~2.3 KB of
		# "RIDs were leaked" / "resources still in use at exit" stderr on every
		# run. Those suites have their own --script entry point.
		if _is_main_loop_script(script):
			skipped += 1
			continue

		var obj: Object = script.new()
		if obj == null:
			failures.append("NEW_RETURNED_NULL  " + path)
			continue
		if obj is RefCounted:
			pass  # Refcount drop at scope exit reclaims it.
		else:
			obj.free()

	if failures.is_empty():
		print("RESULT: OK — %d test scripts instantiate, %d standalone runners load-checked only" % [
			paths.size() - skipped, skipped
		])
	else:
		print("RESULT: %d FAILURE(S)" % failures.size())
		for line in failures:
			print("  " + line)

	quit(0 if failures.is_empty() else 1)

## True when the script derives from MainLoop (i.e. `extends SceneTree`).
##
## Walks the base-script chain so a runner that extends another runner is still
## caught, checking each link's native base type against MainLoop.
func _is_main_loop_script(script: GDScript) -> bool:
	var cursor: GDScript = script
	while cursor != null:
		if ClassDB.class_exists(cursor.get_instance_base_type()) \
				and ClassDB.is_parent_class(cursor.get_instance_base_type(), "MainLoop"):
			return true
		cursor = cursor.get_base_script() as GDScript
	return false

func _collect(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("TestScriptCheck: cannot open %s" % dir_path)
		return out

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_collect(dir_path + "/" + entry))
		elif entry.ends_with(".gd"):
			out.append(dir_path + "/" + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return out
