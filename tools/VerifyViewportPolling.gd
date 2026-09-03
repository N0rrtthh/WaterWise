extends Node

## ═══════════════════════════════════════════════════════════════════
## "THE PER-FRAME VIEWPORT POLL IS UNREACHABLE" HARNESS
## ═══════════════════════════════════════════════════════════════════
## MobileUIManager tracks viewport size TWICE, by two mechanisms that were added
## at different times and now race:
##
##   1. _ready() connects the root Viewport's size_changed to
##      _on_viewport_size_changed(), which writes viewport_width/viewport_height,
##      re-runs _detect_platform/_detect_orientation/_calculate_safe_area and
##      emits orientation_changed — synchronously, inside the resize.
##
##   2. _process() polls get_viewport().get_visible_rect().size every frame and
##      compares it against viewport_width/viewport_height; on a difference it
##      arms a 0.5 s debounce (_pending_orientation_change) whose stated job is to
##      "trigger layout reorganization within 0.5 seconds".
##
## Mechanism 1 always wins. It has already overwritten viewport_width/height by
## the time any frame boundary is reached, so the poll's `!=` is false forever:
## _pending_orientation_change never becomes true, the debounce never runs, and
## _process() costs a per-frame script callback on every platform to compute a
## comparison that cannot change anything. On the thesis's low-end Android target
## that callback is pure overhead, and the debounce the code documents does not
## exist — orientation_changed is emitted immediately by mechanism 1 instead.
##
## What this measures, per flip (landscape -> portrait -> landscape):
##   * control: the visible rect really flipped, so nothing below is vacuous
##   * control: orientation_changed fired at all (the flip WAS detected)
##   * viewport_width matched the new width SYNCHRONOUSLY (mechanism 1 ran)
##   * the emission landed within SYNC_WINDOW of the resize, not at ~0.5 s
##     (so it came from mechanism 1, not from the debounce)
##   * _pending_orientation_change was never true across ~1.5 s of frames
##     (so mechanism 2's branch never armed)
##
## The last check is the fix under test: with the dead poll removed, MobileUIManager
## must not run _process() at all on a non-mobile platform.
##
## Run:
##   godot --headless --path . res://tools/VerifyViewportPolling.tscn

## Root-window sizes. The project stretches content, so these are pre-stretch
## window sizes chosen for their ASPECT: the visible rect that MobileUIManager
## reads flips orientation with them. Measured headless: (100,100) -> 1920x1920,
## (600,1000) -> 1920x3199 (portrait), (1000,600) -> landscape.
const PORTRAIT_SIZE: Vector2i = Vector2i(600, 1000)
const LANDSCAPE_SIZE: Vector2i = Vector2i(1000, 500)
## An emission this close to the resize came from the synchronous signal handler.
## The debounce would land at ~0.5 s, so 0.15 s separates the two cleanly.
const SYNC_WINDOW: float = 0.15
## Long enough to cover the 0.5 s debounce plus slack, sampled every frame.
const OBSERVE: float = 1.5

var results: Array = []
var orientation_events: Array = []      ## {is_portrait, t}
var pending_ever_true: bool = false
var pending_samples: int = 0
var t_resize: float = 0.0
var original_size: Vector2i = Vector2i.ZERO
var processing_at_start: bool = false
var mobile_at_start: bool = false

## Whether the debounce field is still declared at all. After the poll was removed
## it is not, and get() on a missing property would read as false — which would
## make the "never armed" check pass for the wrong reason. Printed either way.
var pending_prop_exists: bool = false
var _pending_prop_checked: bool = false

var flips: Array = []                   ## one record per flip, filled by _do_flip


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  VIEWPORT-POLL REACHABILITY HARNESS")
	print("═══════════════════════════════════════════════════════════")
	original_size = get_tree().root.size
	mobile_at_start = MobileUIManager.is_mobile
	processing_at_start = MobileUIManager.is_processing()
	print("  root window size = %s  visible = %s  is_mobile = %s  is_processing = %s"
		% [str(original_size), str(get_viewport().get_visible_rect().size),
			str(mobile_at_start), str(processing_at_start)])
	MobileUIManager.orientation_changed.connect(_on_orientation_changed)
	_run()


## Sampled every frame: the poll's debounce flag. MobileUIManager is an autoload
## added to /root before this scene, so its _process runs first each frame — if the
## poll ever armed the flag this sampler sees it in the same frame.
func _process(_delta: float) -> void:
	pending_samples += 1
	if not _pending_prop_checked:
		_pending_prop_checked = true
		for p in MobileUIManager.get_property_list():
			if String(p.get("name", "")) == "_pending_orientation_change":
				pending_prop_exists = true
		print("    _pending_orientation_change still declared: %s" % str(pending_prop_exists))
	# `== true` rather than bool(...): once the field is gone, get() returns null and
	# bool(null) is not a valid GDScript conversion — it raises "Nonexistent 'bool'
	# constructor" every frame, which both spams the log and stalls the sampler
	# (measured: 307 sampled frames became 12).
	if MobileUIManager.get("_pending_orientation_change") == true:
		pending_ever_true = true


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _on_orientation_changed(is_portrait: bool) -> void:
	orientation_events.append({"is_portrait": is_portrait, "t": _now()})
	print("    orientation_changed(is_portrait=%s) at t=%.3fs"
		% [str(is_portrait), _now() - t_resize])


## Resize, then read MobileUIManager's mirrored size in the very next statement.
## Nothing has yielded, so anything already updated was updated synchronously by
## the size_changed handler — mechanism 1.
func _do_flip(tag: String, size: Vector2i, expect_portrait: bool) -> Dictionary:
	orientation_events.clear()
	pending_ever_true = false
	pending_samples = 0
	t_resize = _now()
	get_tree().root.size = size
	var vis := get_viewport().get_visible_rect().size
	var rec := {
		"tag": tag,
		"expect_portrait": expect_portrait,
		"visible": vis,
		"really_flipped": (vis.y > vis.x) == expect_portrait,
		"mirrored_sync": (MobileUIManager.viewport_width == int(vis.x)
			and MobileUIManager.viewport_height == int(vis.y)),
		"mirror": Vector2i(MobileUIManager.viewport_width, MobileUIManager.viewport_height),
		"is_portrait_sync": MobileUIManager.is_portrait,
	}
	print("  [%s] root=%s visible=%s  MobileUIManager mirror=%s is_portrait=%s"
		% [tag, str(size), str(vis), str(rec["mirror"]), str(rec["is_portrait_sync"])])
	return rec


func _run() -> void:
	# Two flips, each observed for OBSERVE seconds of real frames.
	await _observe_flip("landscape -> portrait", PORTRAIT_SIZE, true)
	await _observe_flip("portrait -> landscape", LANDSCAPE_SIZE, false)
	_assert_process_cost()
	_assert_mobile_path()
	get_tree().root.size = original_size
	_finish()


func _observe_flip(tag: String, size: Vector2i, expect_portrait: bool) -> void:
	var rec := _do_flip(tag, size, expect_portrait)
	await get_tree().create_timer(OBSERVE).timeout
	rec["pending_ever_true"] = pending_ever_true
	rec["pending_samples"] = pending_samples
	rec["events"] = orientation_events.duplicate(true)
	flips.append(rec)
	_assert_flip(rec)


func _assert_flip(rec: Dictionary) -> void:
	var tag: String = rec["tag"]
	var events: Array = rec["events"]

	# Controls. Without these two, every negative reading below is vacuous.
	_check("%s: control — the visible rect really flipped" % tag,
		bool(rec["really_flipped"]),
		"visible = %s (wanted portrait = %s)"
			% [str(rec["visible"]), str(rec["expect_portrait"])])
	_check("%s: control — orientation_changed fired, so the flip WAS detected" % tag,
		events.size() > 0, "%d emissions" % events.size())
	_check("%s: control — frames actually elapsed while observing" % tag,
		int(rec["pending_samples"]) > 30,
		"%d sampled frames over %.1fs" % [int(rec["pending_samples"]), OBSERVE])

	# Mechanism 1 got there first.
	_check("%s: the size_changed handler mirrored the new size synchronously" % tag,
		bool(rec["mirrored_sync"]),
		"mirror = %s, visible = %s — read in the statement after the resize"
			% [str(rec["mirror"]), str(rec["visible"])])
	_check("%s: is_portrait was already correct synchronously" % tag,
		bool(rec["is_portrait_sync"]) == bool(rec["expect_portrait"]),
		"is_portrait = %s immediately after the resize"
			% str(rec["is_portrait_sync"]))

	var first_delay := -1.0
	if not events.is_empty():
		first_delay = float(events[0]["t"]) - t_resize
	_check("%s: the emission came from the handler, not the 0.5s debounce" % tag,
		first_delay >= 0.0 and first_delay < SYNC_WINDOW,
		"first emission %.3fs after the resize (debounce would be ~0.500s)"
			% first_delay)
	_check("%s: exactly one orientation_changed for one flip" % tag,
		events.size() == 1, "%d emissions" % events.size())

	# Mechanism 2 never armed — the point of the harness.
	_check("%s: _process's viewport poll never armed its debounce" % tag,
		not bool(rec["pending_ever_true"]),
		("_pending_orientation_change true at least once = %s across %d frames"
			+ " (field still declared: %s)")
			% [str(rec["pending_ever_true"]), int(rec["pending_samples"]),
				str(pending_prop_exists)])


## The fix under test. Nothing in _process() can do useful work on a desktop
## build: the poll branch is unreachable (proved above) and _monitor_frame_rate is
## gated on `is_mobile`. A per-frame callback that cannot act is cost with no
## product, so MobileUIManager must not be processing here.
func _assert_process_cost() -> void:
	_check("control — this run really is a non-mobile platform",
		not mobile_at_start,
		"is_mobile = %s on %s" % [str(mobile_at_start), OS.get_name()])
	_check("MobileUIManager does not run _process() when it has nothing to poll",
		not MobileUIManager.is_processing(),
		("is_processing() = %s (was %s at start) — the only two bodies in _process are"
			+ " the unreachable viewport poll and the is_mobile-gated FPS monitor")
			% [str(MobileUIManager.is_processing()), str(processing_at_start)])
	# Whatever the processing decision is, the size mirror must still be correct —
	# a fix that switches _process off must not take size tracking down with it.
	var vis := get_viewport().get_visible_rect().size
	_check("size tracking still works with _process off",
		MobileUIManager.viewport_width == int(vis.x)
			and MobileUIManager.viewport_height == int(vis.y),
		"mirror = %dx%d, visible = %s"
			% [MobileUIManager.viewport_width, MobileUIManager.viewport_height, str(vis)])




## The regression guard for the other half of the change. Switching _process off on
## desktop must not cost the mobile FPS sampler its callback, so drive is_mobile
## through the one entry point that can flip it at runtime (the debug override, which
## routes through _detect_platform like a real platform detection does) and require
## the callback to come back.
func _assert_mobile_path() -> void:
	var was_debug: bool = MobileUIManager.is_debug_mode()
	MobileUIManager.enable_debug_mobile_mode(true)
	var on_when_mobile: bool = MobileUIManager.is_processing()
	var mobile_flag: bool = MobileUIManager.is_mobile
	MobileUIManager.enable_debug_mobile_mode(was_debug)
	var off_again: bool = MobileUIManager.is_processing()

	_check("control — the debug override really flipped is_mobile",
		mobile_flag, "is_mobile = %s while the override was on" % str(mobile_flag))
	_check("_process comes back when the platform is mobile (FPS sampler intact)",
		on_when_mobile,
		"is_processing() = %s with is_mobile = true" % str(on_when_mobile))
	_check("and goes away again when the override is dropped",
		not off_again, "is_processing() = %s" % str(off_again))

func _finish() -> void:
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
