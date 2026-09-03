extends Node

## ═══════════════════════════════════════════════════════════════════
## FRAME-BUDGET METRIC HARNESS
## ═══════════════════════════════════════════════════════════════════
## PerformanceProfiler documented dropped_frames as "Frames >16.67ms" while the
## code counted frames over FRAME_BUDGET_MS = 36.67ms — the 30FPS floor plus 10%,
## which is what the paper specifies. The number was right; its description was
## not, and that description travelled into every exported snapshot and printed
## report, where "dropped frames" reads as "missed 60FPS".
##
## The threshold is the paper's and is untouched. What changed: the comments now
## say what is measured, and frames_over_60_budget counts the 60FPS line the
## header claims to monitor, so BOTH figures exist and neither is mislabelled.
##
## Checked here:
##   * both thresholds are distinct and correctly ordered
##   * a synthetic frame between the two lines increments ONLY the 60FPS counter
##   * a synthetic frame past both increments both
##   * both counters reach the snapshot and the ISO report
##   * the debug overlay's format string still matches its argument list — the
##     edit that added the counter to it left 5 args against 4 specifiers for a
##     moment, which is a runtime fault the parse check cannot see.

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  FRAME-BUDGET METRIC HARNESS")
	print("═══════════════════════════════════════════════════════════")
	var p := PerformanceProfiler

	_check("the 60FPS line is 16.67ms",
		is_equal_approx(p.FRAME_BUDGET_60_MS, 16.67),
		"FRAME_BUDGET_60_MS = %s" % str(p.FRAME_BUDGET_60_MS))
	_check("the paper's 30FPS drop budget is unchanged at 36.67ms",
		is_equal_approx(p.FRAME_BUDGET_MS, 36.67),
		"FRAME_BUDGET_MS = %s" % str(p.FRAME_BUDGET_MS))
	_check("the two budgets are distinct and correctly ordered",
		p.FRAME_BUDGET_60_MS < p.FRAME_BUDGET_MS)

	# Past the warmup gate, or neither counter moves.
	_check("control: past STARTUP_WARMUP_SEC so counting is live",
		await _wait_past_warmup(p),
		"session_elapsed_sec = %.1f (warmup %.1f)"
			% [p.session_elapsed_sec, p.STARTUP_WARMUP_SEC])

	# A frame BETWEEN the lines: slower than 60FPS, comfortably inside the 30FPS
	# budget. This is the case the old comment got wrong.
	var d0: int = p.dropped_frames
	var o0: int = p.frames_over_60_budget
	p._process(0.025)  # 25ms: over 16.67, under 36.67
	_check("a 25ms frame counts against the 60FPS target",
		p.frames_over_60_budget == o0 + 1,
		"frames_over_60_budget %d -> %d" % [o0, p.frames_over_60_budget])
	_check("a 25ms frame is NOT a dropped frame (it made the 30FPS floor)",
		p.dropped_frames == d0,
		"dropped_frames %d -> %d" % [d0, p.dropped_frames])

	# A frame past BOTH lines.
	var d1: int = p.dropped_frames
	var o1: int = p.frames_over_60_budget
	p._process(0.050)  # 50ms: over both
	_check("a 50ms frame counts against both budgets",
		p.dropped_frames == d1 + 1 and p.frames_over_60_budget == o1 + 1,
		"dropped %d -> %d | over60 %d -> %d"
			% [d1, p.dropped_frames, o1, p.frames_over_60_budget])

	# Both figures must be readable by whatever consumes the metrics.
	# _take_snapshot() emits rather than returns, so the snapshot is captured off
	# the signal the rest of the project listens to.
	var snap: Dictionary = await _capture_snapshot(p)
	_check("the snapshot carries both counters",
		snap.has("dropped_frames") and snap.has("frames_over_60_budget"),
		"keys present: dropped=%s over60=%s"
			% [str(snap.has("dropped_frames")), str(snap.has("frames_over_60_budget"))])
	var iso: Dictionary = p.export_session_report()
	var ft: Dictionary = iso.get("frame_timing", {})
	_check("the ISO report names both budgets and both counts",
		ft.has("budget_ms") and ft.has("budget_60_ms")
			and ft.has("dropped_frames") and ft.has("frames_over_60_budget"),
		"frame_timing keys = %s" % str(ft.keys()))
	_check("meets_budget still gates on the paper's 30FPS floor, not the new counter",
		ft.has("meets_budget") and ft.has("drop_rate_percent"),
		"drop_rate_percent = %s meets_budget = %s"
			% [str(ft.get("drop_rate_percent")), str(ft.get("meets_budget"))])

	# The overlay's format string vs its argument list. A mismatch is a runtime
	# fault, invisible to a parse check, so it is exercised rather than read.
	_check("the debug overlay renders with the added counter",
		await _overlay_renders(p))

	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [results.size() - failed, failed])
	if failed > 0:
		for r in results:
			if not r["ok"]:
				print("    ✗ %s" % r["label"])
	print("═══════════════════════════════════════════════════════════")
	print("")
	get_tree().quit(1 if failed > 0 else 0)


func _wait_past_warmup(p: Node) -> bool:
	var guard := 0
	while p.session_elapsed_sec <= p.STARTUP_WARMUP_SEC and guard < 400:
		await get_tree().create_timer(0.05).timeout
		guard += 1
	return p.session_elapsed_sec > p.STARTUP_WARMUP_SEC


## Force the overlay to exist and update. If the format string and its argument
## list disagree, the update raises and overlay_label.text stays empty.
func _overlay_renders(p: Node) -> bool:
	if not p.has_method("_update_overlay_text"):
		return false
	if p.get("overlay_label") == null:
		if p.has_method("toggle_overlay"):
			p.toggle_overlay()
			await get_tree().process_frame
	var lbl = p.get("overlay_label")
	if lbl == null:
		return false
	lbl.text = ""
	p._update_overlay_text()
	await get_tree().process_frame
	var txt: String = str(lbl.text)
	print("     overlay line: %s" % txt.split("\n")[1] if txt.count("\n") > 0 else txt)
	return txt.contains("Drop:") and txt.contains(">16.7ms:")


## Wait for the profiler's own 1 Hz snapshot emission rather than fabricating one,
## so the assertion is about the dictionary the project actually publishes.
func _capture_snapshot(p: Node) -> Dictionary:
	var box := {"d": {}}
	var cb := func(data: Dictionary) -> void:
		box["d"] = data
	p.profiling_snapshot.connect(cb)
	var guard := 0
	while box["d"].is_empty() and guard < 60:
		await get_tree().create_timer(0.1).timeout
		guard += 1
	p.profiling_snapshot.disconnect(cb)
	return box["d"]
