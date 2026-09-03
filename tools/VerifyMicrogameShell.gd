extends SceneTree

## Focused check for the v2 microgame foundation (thesis rehaul):
##   1. EntityPool — pre-allocation, O(1) acquire/release, exhaustion,
##      double-release guard, and ZERO allocation after setup.
##   2. Juice — pop/squash cache base scales (no compounding), shake settles
##      exactly home, punch/pulse never touch layout.
##   3. MicrogameShell — class loads, static hit_test is fat and correct.
##
## Usage:
##   Godot_console.exe --headless --path <project> --script tools/VerifyMicrogameShell.gd

func _initialize() -> void:
	var failures: PackedStringArray = PackedStringArray()
	failures.append_array(_check_pool())
	failures.append_array(_check_pool_no_alloc())
	failures.append_array(await _check_juice())
	failures.append_array(_check_shell_statics())

	if failures.is_empty():
		print("RESULT: OK — microgame shell checks passed")
	else:
		print("RESULT: %d FAILURE(S)" % failures.size())
		for line in failures:
			print("  " + line)

	quit(0 if failures.is_empty() else 1)

# ── EntityPool ──────────────────────────────────────────────────────────────

func _make_factory() -> Callable:
	return func(_idx: int) -> Node2D:
		var n := Node2D.new()
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(0, 8)])
		n.add_child(p)
		return n


func _check_pool() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var pool := EntityPool.new()
	var holder := Node2D.new()
	root.add_child(holder)
	pool.setup(_make_factory(), 3, holder)

	if pool.capacity != 3:
		out.append("pool capacity != 3")
	if holder.get_child_count() != 3:
		out.append("pool did not pre-build 3 nodes")

	var a := pool.acquire()
	var b := pool.acquire()
	var c := pool.acquire()
	if a == null or b == null or c == null:
		out.append("acquire returned null before exhaustion")
	if pool.active_count != 3:
		out.append("active_count != 3 after 3 acquires")
	if not (a.visible and b.visible and c.visible):
		out.append("acquired nodes must be visible")

	var d := pool.acquire()
	if d != null:
		out.append("acquire must return null when exhausted")

	pool.release(b)
	if b.visible:
		out.append("released node must be hidden")
	if pool.active_count != 2:
		out.append("active_count != 2 after release")
	var b2 := pool.acquire()
	if b2 != b:
		out.append("re-acquire must return the same pooled node")

	pool.release(b)
	pool.release(b)
	if pool.active_count != 2:
		out.append("double release corrupted active_count")

	pool.release_all()
	if pool.active_count != 0:
		out.append("release_all left actives")
	for child in holder.get_children():
		if child.visible:
			out.append("release_all left a node visible")
		if not child.has_meta("_pool_idx"):
			out.append("pool node missing _pool_idx meta")
	return out


func _check_pool_no_alloc() -> PackedStringArray:
	# Static memory can only grow, so the assertion is: after setup, churning
	# acquire/release 200x must not grow it beyond a tiny epsilon.
	var out: PackedStringArray = PackedStringArray()
	var pool := EntityPool.new()
	var holder := Node2D.new()
	root.add_child(holder)
	pool.setup(_make_factory(), 16, holder)

	for i in range(4):
		pool.acquire()
	var before: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	for cycle in range(200):
		var n := pool.acquire()
		if n == null:
			pool.release_all()
			n = pool.acquire()
		n.position = Vector2(cycle % 7, cycle % 5)
		pool.release(n)
	var after: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	if after > before + 4096:
		out.append("pool churn grew static memory by %d bytes (expected ~0)" % (after - before))
	return out

# ── Juice ───────────────────────────────────────────────────────────────────

func _check_juice() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var node := Node2D.new()
	root.add_child(node)

	var base := Vector2(2.0, 2.0)
	node.scale = base
	Juice.pop(node, 1.5)
	if Juice.base_scale(node) != base:
		out.append("pop did not capture base scale")
	Juice.pop(node, 1.5)
	if not node.scale.is_equal_approx(base * 1.5):
		out.append("second pop compounded instead of resetting (scale=%s)" % node.scale)

	Juice.squash(node, Vector2(0, 1), 0.4)
	Juice.squash(node, Vector2(0, 1), 0.4)
	var expected := base * Vector2(1.0 + 0.4 * 0.5, 1.0 - 0.4)
	if not node.scale.is_equal_approx(expected):
		out.append("squash scale wrong/compounded (scale=%s)" % node.scale)

	# shake(): node must settle exactly home once the tween finishes.
	node.position = Vector2(120.0, 80.0)
	Juice.shake(node, 20.0, 0.2)
	await create_timer(0.5).timeout
	if not node.position.is_equal_approx(Vector2(120.0, 80.0)):
		out.append("shake did not settle home (pos=%s)" % node.position)

	var label := Label.new()
	label.text = "7"
	label.size = Vector2(100, 40)
	root.add_child(label)
	Juice.punch_label(label, 1.5)
	if label.pivot_offset != Vector2(50, 20):
		out.append("punch_label did not centre pivot")
	Juice.punch_label(label, 1.5)
	if not label.scale.is_equal_approx(Vector2.ONE * 1.5):
		out.append("punch_label compounded (scale=%s)" % label.scale)

	# Null/invalid safety: none of these may crash.
	Juice.pop(null)
	Juice.shake(null)
	Juice.punch_label(null)
	Juice.squash(null)
	Juice.flash(null, Color.RED)
	return out

# ── MicrogameShell statics ─────────────────────────────────────────────────

func _check_shell_statics() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	# Load at runtime, NOT as a compile-time symbol: a -s main script compiles
	# before autoloads register, and MicrogameShell references AudioManager, so
	# a static reference here fails with "Identifier not found" and the whole
	# main script is initially rejected (it recovers on the post-boot reload,
	# but the log noise is not worth it).
	var shell_script: GDScript = load("res://scripts/minigames_v2/MicrogameShell.gd")
	if shell_script == null or not shell_script.can_instantiate():
		out.append("MicrogameShell failed to compile")
		return out
	var shell: Node = shell_script.new()
	if shell == null:
		out.append("MicrogameShell failed to instantiate")
	else:
		shell.free()

	var centre := Vector2(100, 100)
	if not shell_script.hit_test(centre + Vector2(20, 0), centre, 10.0):
		out.append("hit_test rejected an in-radius tap")
	if shell_script.hit_test(centre + Vector2(60, 0), centre, 10.0):
		out.append("hit_test accepted an out-of-radius tap")
	if not shell_script.hit_test(centre + Vector2(36, 0), centre, 10.0):
		out.append("hit_test boundary (radius+fudge) misbehaves")
	return out
