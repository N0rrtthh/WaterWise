extends Node

## Does pausing steal time from the round, or end it outright?
##
## THE DEFECT UNDER TEST
##   MiniGameBase runs TWO clocks that are supposed to agree:
##     - _game_timer, a Timer node child of the minigame (:840). Process mode is
##       inherited, so it STOPS while the tree is paused.
##     - _process() at :1811, which computes
##         elapsed = (Time.get_ticks_msec() - game_start_time) / 1000.0
##       Time.get_ticks_msec() is WALL CLOCK. It keeps advancing while the tree is
##       paused, so on the first frame after a resume the elapsed jumps by the whole
##       length of the pause.
##   And :1867 does not merely display that value - it ends the round from it:
##       if effective_time_left <= 0: _on_timeout()
##   which in quota mode is game_failed.emit() + end_game(false), costing a life.
##
## WHY THIS IS NOT AN EDGE CASE ON THE TARGET PLATFORM
##   MobileUIManager._on_app_focus_lost() sets get_tree().paused = true when the app
##   goes to background (autoload/MobileUIManager.gd:1339). So on Android an incoming
##   call, a notification pulled down, or the home button - anything that backgrounds
##   the app for longer than the time left in the round - fails the round the instant
##   the player comes back, before they can touch anything. A shorter interruption
##   steals exactly its own duration off the clock. The pause MENU is the same defect
##   by the same route, just less frequent.
##
## HONESTY ABOUT WHAT IS COMPRESSED
##   Case 3 needs a pause LONGER than the time remaining. Rather than wait out
##   CatchTheRain's full round, it sets game_duration and calls _start_timer() - both
##   production calls, and exactly what _apply_difficulty_settings() + start_game() do
##   with a difficulty-chosen duration. Only the number is chosen for test speed; the
##   mechanism is untouched. Real seconds are then really waited, because a wall-clock
##   defect cannot be reproduced with simulated time.
##
## Usage:
##   godot --headless --path . res://tools/VerifyPauseClock.tscn

const ROUND: String = "res://scenes/minigames/CatchTheRain.tscn"

var _pass: int = 0
var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


## Frames that leave the pause state alone. The other harnesses clear a stray
## background pause each frame; this one is measuring what a pause does, so clearing
## it would erase the thing under test.
func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


## Real seconds, while the tree stays paused. process_frame still fires when the tree
## is paused, so this is a genuine wall-clock wait with the game frozen - which is the
## exact condition a backgrounded app is in.
func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


## A live round, started through the real tap-to-start prompt at MiniGameBase:221.
func _live_round() -> Node:
	var inst: Node = (load(ROUND) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	for _i in range(30):
		await get_tree().process_frame
	for attempt in range(120):
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = get_tree().root.get_visible_rect().size * 0.5
		Input.parse_input_event(down)
		await get_tree().process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = down.position
		Input.parse_input_event(up)
		await get_tree().process_frame
		if inst.get("game_active") == true:
			print("          (round went live after %d taps)" % (attempt + 1))
			break
	return inst


## What the round thinks is left, read the way _process() computes it, so the probe
## and the product cannot disagree about the number under test.
func _time_left(g: Node) -> float:
	# elapsed_play_seconds() is the accessor the fix introduces as the single source of
	# truth. Before the fix it does not exist, so the pre-fix run falls back to the
	# wall-clock expression _process() used at :1811 - which is the defect itself, and
	# is exactly what has to be measured to show the failure.
	var elapsed: float
	if g.has_method("elapsed_play_seconds"):
		elapsed = g.elapsed_play_seconds()
	else:
		elapsed = float(Time.get_ticks_msec() - int(g.get("game_start_time"))) / 1000.0
	return maxf(0.0, float(g.game_duration) - elapsed - float(g.get("_time_penalty_total")))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== DOES PAUSING STEAL THE ROUND CLOCK? ===")
	print("  accessor present: %s"
		% str((load(ROUND) as PackedScene).can_instantiate()))

	# ---- CASE 1: a short pause must not move the clock -----------------------
	# The direct measurement. 2 real seconds of pause; the round's own remaining time
	# is read before and after, and must be the same within a frame or two of noise.
	var g1: Node = await _live_round()
	_check("[1] fixture: the round is live",
		g1.get("game_active") == true,
		"game_active=%s game_duration=%.1f" % [str(g1.get("game_active")), g1.game_duration])
	await _frames(4)
	var before1: float = _time_left(g1)
	get_tree().paused = true
	await _wait_real(2.0)
	get_tree().paused = false
	await _frames(3)
	var after1: float = _time_left(g1)
	var stolen1: float = before1 - after1
	_check("[1] a 2s pause does not take 2s off the round",
		stolen1 < 0.6,
		"time left %.2fs -> %.2fs, so the pause cost %.2fs of play"
			% [before1, after1, stolen1])
	_check("[1] the round survived the pause",
		g1.get("game_active") == true and not g1.get("_round_ended"),
		"game_active=%s _round_ended=%s"
			% [str(g1.get("game_active")), str(g1.get("_round_ended"))])
	get_tree().paused = false
	g1.queue_free()
	await _frames(4)

	# ---- CASE 2: the two clocks must agree ------------------------------------
	# _game_timer stops while paused and _process()'s wall clock did not, so after a
	# pause they disagree by the length of the pause. This compares them directly,
	# because a fix that only patched the display would leave the round ending at a
	# time the HUD never showed.
	var g2: Node = await _live_round()
	await _frames(4)
	get_tree().paused = true
	await _wait_real(2.0)
	get_tree().paused = false
	await _frames(3)
	var shown2: float = _time_left(g2)
	var timer_node: Timer = g2.get("_game_timer")
	var real2: float = timer_node.time_left if timer_node else -1.0
	_check("[2] the displayed clock and the Timer that ends the round agree",
		absf(shown2 - real2) < 0.6,
		"displayed %.2fs vs _game_timer.time_left %.2fs (gap %.2fs after a 2s pause)"
			% [shown2, real2, absf(shown2 - real2)])
	get_tree().paused = false
	g2.queue_free()
	await _frames(4)

	# ---- CASE 3: backgrounding must not fail the round ------------------------
	# The mobile case, and the one that costs a life. game_duration is set short and
	# _start_timer() re-armed - both production calls, see the header - so a pause
	# LONGER than the time remaining can be waited out in real seconds.
	var g3: Node = await _live_round()
	g3.game_duration = 4.0
	g3._start_timer()
	await _frames(3)
	var lives_before: int = int(g3.get("lives"))
	print("          (armed a %.0fs round, then backgrounded for 6s; lives=%d)"
		% [g3.game_duration, lives_before])
	# The real production trigger, not a bare paused=true: this is what Android
	# backgrounding runs. Guarded because it is is_mobile-gated.
	var mui := get_node_or_null("/root/MobileUIManager")
	var used_mui := false
	if mui and mui.has_method("_on_app_focus_lost"):
		mui.debug_mobile_mode = true
		if mui.has_method("_detect_platform"):
			mui._detect_platform()
		mui._on_app_focus_lost()
		used_mui = get_tree().paused
	if not used_mui:
		get_tree().paused = true
	print("          (pause taken via %s)"
		% ("MobileUIManager._on_app_focus_lost()" if used_mui else "get_tree().paused"))
	await _wait_real(6.0)
	if used_mui and mui.has_method("_on_app_focus_gained"):
		mui._on_app_focus_gained()
	else:
		get_tree().paused = false
	await _frames(5)
	_check("[3] a 6s background on a 4s round does not instantly fail it",
		g3.get("game_active") == true and not g3.get("_round_ended"),
		"game_active=%s _round_ended=%s lives %d -> %d, time left %.2fs"
			% [str(g3.get("game_active")), str(g3.get("_round_ended")),
				lives_before, int(g3.get("lives")), _time_left(g3)])
	_check("[3] no life was spent for being interrupted",
		int(g3.get("lives")) == lives_before,
		"lives %d -> %d" % [lives_before, int(g3.get("lives"))])
	get_tree().paused = false
	g3.queue_free()
	await _frames(4)

	# ---- CASE 4: the clock must still actually run -----------------------------
	# The guard against the fix degenerating into "stop the clock". A round whose
	# timer never advances can never time out, which would be a worse defect than the
	# one being fixed and would pass every check above.
	var g4: Node = await _live_round()
	await _frames(4)
	var t_a: float = _time_left(g4)
	await _wait_real(1.5)
	var t_b: float = _time_left(g4)
	_check("[4] unpaused play still drains the clock",
		t_a - t_b > 0.8,
		"time left %.2fs -> %.2fs over 1.5s of real play (drained %.2fs)"
			% [t_a, t_b, t_a - t_b])

	# And it must still reach zero and end the round on its own.
	g4.game_duration = 1.0
	g4._start_timer()
	await _wait_real(2.5)
	await _frames(5)
	_check("[4] a 1s round still times out and ends by itself",
		g4.get("_round_ended") == true,
		"_round_ended=%s game_active=%s"
			% [str(g4.get("_round_ended")), str(g4.get("game_active"))])
	g4.queue_free()
	await _frames(4)

	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	print("")
	get_tree().quit(1 if _fail > 0 else 0)
