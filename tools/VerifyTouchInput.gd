extends Node

## ═══════════════════════════════════════════════════════════════════
## TOUCH INPUT VERIFICATION HARNESS (headless, thesis-auditable)
## ═══════════════════════════════════════════════════════════════════
## The thesis requires the game to be playable with touch only, on a phone, with
## no mouse or keyboard. TouchInputManager is the single place that turns raw
## InputEventScreenTouch/Drag into the tap/hold/swipe/drag the minigames consume,
## and nothing verified it.
##
## The defect this harness was written for: _handle_screen_touch() applied the
## edge dead zone to EVERY touch event, including releases. A finger that pressed
## mid-screen and lifted within edge_dead_zone pixels of an edge had its release
## discarded, so its entry stayed in active_touches forever. get_touch_count()
## then reported a finger that was no longer down, and RiceWashRescue._process
## steers its basin to get_touch_position(0) whenever that count is non-zero —
## the basin locks to the finger's last position and the round is unplayable.
## Sliding a thumb off the bottom edge is the ordinary way a touch ends on a
## phone, so this was reachable in normal play, not a corner case.
##
## Every check drives TouchInputManager's real handlers with real
## InputEventScreenTouch/InputEventScreenDrag objects. Nothing is stubbed, so a
## regression in the handler fails the harness rather than a copy of its logic.
##
## Verifies:
##   1. A press that starts inside the dead zone is still rejected
##   2. A press that starts outside it is tracked
##   3. A release inside the dead zone still retires a tracked finger
##   4. A release inside the dead zone clears is_touching
##   5. A second finger released at the edge does not strand multi-touch state
##   6. Drag updates the tracked position and emits touch_drag
##   7. Gesture classification: tap / hold / swipe
##   8. Losing application focus mid-drag clears every tracked finger
##   9. Releasing an untracked index is a no-op (no error, no phantom entry)
##
## Run:
##   Godot --headless --path <project> res://tools/VerifyTouchInput.tscn
## Exit code 0 = all passed, 1 = at least one failure.
## ═══════════════════════════════════════════════════════════════════

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

## Captured signal payloads, so gesture checks assert on what was emitted.
var _taps: Array[Vector2] = []
var _holds: Array = []
var _swipes: Array = []
var _drags: Array = []


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE TOUCH INPUT VERIFICATION")
	print("═══════════════════════════════════════════════════════════")

	# is_mobile gates the dead zone, and under --headless the dummy display is
	# landscape so _detect_platform() leaves it false. Force it on: the phone is
	# the platform under test.
	TouchInputManager.is_mobile = true
	TouchInputManager.touch_tap.connect(func(p): _taps.append(p))
	TouchInputManager.touch_hold.connect(func(p, d): _holds.append([p, d]))
	TouchInputManager.touch_swipe.connect(func(dir, v): _swipes.append([dir, v]))
	TouchInputManager.touch_drag.connect(func(a, b): _drags.append([a, b]))

	_verify_dead_zone_still_rejects_presses()
	_verify_release_at_edge_retires_finger()
	_verify_multitouch_not_stranded()
	_verify_drag_tracking()
	_verify_gesture_classification()
	_verify_focus_loss_clears_touches()
	_verify_untracked_release_is_noop()

	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		for f in _failures:
			print("    ✗ %s" % f)
	print("═══════════════════════════════════════════════════════════")
	print("")

	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		var msg := label if detail == "" else "%s — %s" % [label, detail]
		_failures.append(msg)
		print("  ✗ %s  %s" % [label, detail])


## Reset TouchInputManager to a known clean state between checks.
##
## Each check must start with no fingers down, otherwise a stranded entry from an
## earlier check would make a later one pass for the wrong reason.
func _reset() -> void:
	TouchInputManager.active_touches.clear()
	TouchInputManager.is_touching = false
	_taps.clear()
	_holds.clear()
	_swipes.clear()
	_drags.clear()


func _press(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = true
	TouchInputManager._handle_screen_touch(ev)


func _release(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = false
	TouchInputManager._handle_screen_touch(ev)


func _drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	TouchInputManager._handle_screen_drag(ev)


## The dead zone must keep doing its job: a press against the bezel is an
## accidental grip touch and is not a game input.
func _verify_dead_zone_still_rejects_presses() -> void:
	print("")
	print("── Dead zone rejects accidental presses ──")

	var dz: float = TouchInputManager.edge_dead_zone
	_check("edge_dead_zone is configured", dz > 0.0, "got %.1f" % dz)

	_reset()
	_press(0, Vector2(dz * 0.5, 400.0))
	_check("press inside left dead zone rejected",
		TouchInputManager.get_touch_count() == 0,
		"count=%d" % TouchInputManager.get_touch_count())
	_check("rejected press leaves is_touching false",
		not TouchInputManager.is_touching)

	_reset()
	_press(0, Vector2(400.0, 400.0))
	_check("press outside dead zone tracked",
		TouchInputManager.get_touch_count() == 1,
		"count=%d" % TouchInputManager.get_touch_count())
	_check("tracked press sets is_touching",
		TouchInputManager.is_touching)


## The regression this harness exists for.
func _verify_release_at_edge_retires_finger() -> void:
	print("")
	print("── Release at edge retires the finger ──")

	var dz: float = TouchInputManager.edge_dead_zone

	_reset()
	# Thumb presses mid-screen, slides to the left bezel, lifts there.
	_press(0, Vector2(400.0, 800.0))
	_drag(0, Vector2(200.0, 800.0))
	_drag(0, Vector2(dz * 0.3, 800.0))
	_release(0, Vector2(dz * 0.3, 800.0))

	_check("finger released inside dead zone is untracked",
		TouchInputManager.get_touch_count() == 0,
		"count=%d — phantom finger, get_touch_position(0) returns a stale point"
			% TouchInputManager.get_touch_count())
	_check("is_touching cleared after edge release",
		not TouchInputManager.is_touching)

	# The consumer that the phantom finger breaks: RiceWashRescue only reads the
	# touch position when the count is non-zero, so assert the count is what
	# gates it back to the mouse/AutoPlay path.
	_check("get_touch_position(0) no longer reports a live finger",
		TouchInputManager.get_touch_position(0) == Vector2.ZERO,
		"got %s" % TouchInputManager.get_touch_position(0))

	# Same defect through the bottom edge, which is where a thumb actually leaves
	# the screen on a portrait phone.
	_reset()
	var vp_h: float = get_viewport().get_visible_rect().size.y
	_press(0, Vector2(400.0, vp_h * 0.5))
	_release(0, Vector2(400.0, vp_h - dz * 0.3))
	_check("finger released at bottom edge is untracked",
		TouchInputManager.get_touch_count() == 0,
		"count=%d" % TouchInputManager.get_touch_count())


## A stranded non-primary finger is worse than a stranded primary one: index 0 is
## overwritten by the next press, index 1 is not, so is_multi_touch() and
## get_pinch_distance() stay wrong indefinitely.
func _verify_multitouch_not_stranded() -> void:
	print("")
	print("── Multi-touch state not stranded ──")

	var dz: float = TouchInputManager.edge_dead_zone

	_reset()
	_press(0, Vector2(300.0, 600.0))
	_press(1, Vector2(700.0, 600.0))
	_check("two fingers tracked", TouchInputManager.is_multi_touch(),
		"count=%d" % TouchInputManager.get_touch_count())

	_release(1, Vector2(700.0, dz * 0.4))
	_check("second finger released at edge is untracked",
		not TouchInputManager.is_multi_touch(),
		"count=%d" % TouchInputManager.get_touch_count())
	_check("primary finger still tracked",
		TouchInputManager.get_touch_count() == 1,
		"count=%d" % TouchInputManager.get_touch_count())
	_check("pinch distance reports no pinch with one finger",
		is_equal_approx(TouchInputManager.get_pinch_distance(), 0.0))


func _verify_drag_tracking() -> void:
	print("")
	print("── Drag tracking ──")

	_reset()
	_press(0, Vector2(400.0, 400.0))
	_drag(0, Vector2(450.0, 410.0))
	_check("drag updates tracked position",
		TouchInputManager.get_touch_position(0) == Vector2(450.0, 410.0),
		"got %s" % TouchInputManager.get_touch_position(0))
	_check("drag emitted touch_drag", _drags.size() == 1,
		"emitted %d" % _drags.size())
	if _drags.size() == 1:
		_check("touch_drag carries from → to",
			_drags[0][0] == Vector2(400.0, 400.0) and _drags[0][1] == Vector2(450.0, 410.0),
			"got %s → %s" % [_drags[0][0], _drags[0][1]])

	# A drag for a finger that was never tracked (its press was rejected at the
	# bezel) must not create an entry.
	_reset()
	_drag(3, Vector2(500.0, 500.0))
	_check("drag for untracked index creates no entry",
		TouchInputManager.get_touch_count() == 0,
		"count=%d" % TouchInputManager.get_touch_count())


## Tap / hold / swipe must be distinguishable, since every minigame's controls
## are built on exactly these three.
func _verify_gesture_classification() -> void:
	print("")
	print("── Gesture classification ──")

	# TAP: short duration, small distance. start_time is read from the dict, so
	# rewriting it is how a duration is imposed without sleeping in a harness.
	_reset()
	_press(0, Vector2(400.0, 400.0))
	TouchInputManager.active_touches[0]["start_time"] = _now() - 0.05
	_release(0, Vector2(403.0, 402.0))
	_check("short press near origin classified as tap",
		_taps.size() == 1 and _swipes.is_empty() and _holds.is_empty(),
		"taps=%d holds=%d swipes=%d" % [_taps.size(), _holds.size(), _swipes.size()])

	# HOLD: long duration, small distance.
	_reset()
	_press(0, Vector2(400.0, 400.0))
	TouchInputManager.active_touches[0]["start_time"] = _now() - 1.0
	_release(0, Vector2(402.0, 401.0))
	_check("long press near origin classified as hold",
		_holds.size() == 1 and _taps.is_empty() and _swipes.is_empty(),
		"taps=%d holds=%d swipes=%d" % [_taps.size(), _holds.size(), _swipes.size()])
	if _holds.size() == 1:
		_check("hold reports the press origin, not the release point",
			_holds[0][0] == Vector2(400.0, 400.0),
			"got %s" % _holds[0][0])

	# SWIPE: far enough and fast enough. 300px in 0.1s = 3000px/s, well over
	# swipe_velocity_threshold.
	_reset()
	_press(0, Vector2(400.0, 400.0))
	TouchInputManager.active_touches[0]["start_time"] = _now() - 0.1
	_release(0, Vector2(700.0, 400.0))
	_check("fast long press classified as swipe",
		_swipes.size() == 1 and _taps.is_empty() and _holds.is_empty(),
		"taps=%d holds=%d swipes=%d" % [_taps.size(), _holds.size(), _swipes.size()])
	if _swipes.size() == 1:
		_check("swipe direction resolves to right",
			TouchInputManager.get_swipe_direction_name(_swipes[0][0]) == "right",
			"got %s" % TouchInputManager.get_swipe_direction_name(_swipes[0][0]))

	_check("every gesture path leaves no finger tracked",
		TouchInputManager.get_touch_count() == 0,
		"count=%d" % TouchInputManager.get_touch_count())


## Android delivers no release when the app is backgrounded mid-drag.
func _verify_focus_loss_clears_touches() -> void:
	print("")
	print("── Focus loss clears tracked fingers ──")

	_reset()
	_press(0, Vector2(400.0, 400.0))
	_press(1, Vector2(600.0, 400.0))
	_drag(0, Vector2(420.0, 405.0))
	_check("two fingers down before backgrounding",
		TouchInputManager.get_touch_count() == 2,
		"count=%d" % TouchInputManager.get_touch_count())

	TouchInputManager._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check("focus-out clears every tracked finger",
		TouchInputManager.get_touch_count() == 0,
		"count=%d — controls would stay locked after resuming"
			% TouchInputManager.get_touch_count())
	_check("focus-out clears is_touching",
		not TouchInputManager.is_touching)

	# And input still works after resuming.
	_press(0, Vector2(500.0, 500.0))
	_check("touch tracked again after resume",
		TouchInputManager.get_touch_count() == 1,
		"count=%d" % TouchInputManager.get_touch_count())


func _verify_untracked_release_is_noop() -> void:
	print("")
	print("── Untracked release is a no-op ──")

	_reset()
	_release(2, Vector2(400.0, 400.0))
	_check("release without a matching press adds nothing",
		TouchInputManager.get_touch_count() == 0,
		"count=%d" % TouchInputManager.get_touch_count())
	_check("release without a matching press emits no gesture",
		_taps.is_empty() and _holds.is_empty() and _swipes.is_empty(),
		"taps=%d holds=%d swipes=%d" % [_taps.size(), _holds.size(), _swipes.size()])

	# A press rejected at the bezel followed by its release: the pair must cancel
	# out, which is the case that made the original bug survivable for index 0.
	_reset()
	_press(0, Vector2(TouchInputManager.edge_dead_zone * 0.5, 400.0))
	_release(0, Vector2(TouchInputManager.edge_dead_zone * 0.5, 400.0))
	_check("rejected press + its release leaves clean state",
		TouchInputManager.get_touch_count() == 0 and not TouchInputManager.is_touching,
		"count=%d touching=%s"
			% [TouchInputManager.get_touch_count(), TouchInputManager.is_touching])


## Seconds since boot, matching how the handler stamps start_time.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
