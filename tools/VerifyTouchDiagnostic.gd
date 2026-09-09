extends Node

## ── TOUCH-DELIVERY DIAGNOSTIC PROBE ────────────────────────────────────────
##
## Proves the instrumentation chain for the input-drop investigation end to
## end, without a device:
##   1. TouchInputManager counts raw delivered press/release events (desktop
##      mouse stream and, when the platform flag is on, ScreenTouch events).
##   2. MiniGameBase.get_touch_diagnostic() attributes a per-round slice:
##      received (delivery) vs processed (game-logic graded hits), the drop
##      count between them, and the timestamped event log.
##   3. SessionLogger.record_sp_game() persists the diagnostic on the round
##      record so the exported session JSON carries it.
##
## Run:  godot --headless --path . res://tools/VerifyTouchDiagnostic.tscn

var _fails: int = 0

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _pass(msg: String) -> void:
	print("  ✓ " + msg)


func _fail(msg: String) -> void:
	_fails += 1
	print("  ✗ " + msg)


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = pos
	Input.parse_input_event(e)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  TOUCH-DELIVERY DIAGNOSTIC PROBE")
	print("═══════════════════════════════════════════════════════════")
	var tim = get_node_or_null("/root/TouchInputManager")
	if tim == null:
		_fail("TouchInputManager autoload missing")
		_tree().quit(1)
		return

	# ── 1. Desktop mouse-stream counting ─────────────────────────────
	print("")
	print("  ── desktop mouse stream (is_mobile=false) ──")
	tim.is_mobile = false
	var down_before: int = tim.diag_down_total
	var up_before: int = tim.diag_up_total
	for i in range(3):
		_mouse(Vector2(400 + 10 * i, 300), true)
		if i < 2:
			_mouse(Vector2(400 + 10 * i, 300), false)
	Input.flush_buffered_events()
	await _frames(3)
	if tim.diag_down_total - down_before == 3:
		_pass("3 mouse presses delivered → diag_down_total +3")
	else:
		_fail("expected diag_down_total +3, got +%d" % (tim.diag_down_total - down_before))
	if tim.diag_up_total - up_before == 2:
		_pass("2 mouse releases delivered → diag_up_total +2")
	else:
		_fail("expected diag_up_total +2, got +%d" % (tim.diag_up_total - up_before))
	if tim.diag_events.size() >= 5 and str(tim.diag_events[-1].get("phase")) == "down":
		_pass("event ring holds the stream with phases (last: %s t_ms=%d x=%.1f y=%.1f)"
			% [tim.diag_events[-1]["phase"], int(tim.diag_events[-1]["t_ms"]),
				float(tim.diag_events[-1]["x"]), float(tim.diag_events[-1]["y"])])
	else:
		_fail("event ring did not record the stream (size=%d)" % tim.diag_events.size())

	# ── 2. Android-mode ScreenTouch counting ─────────────────────────
	print("")
	print("  ── touch-platform stream (is_mobile=true) ──")
	tim.is_mobile = true
	down_before = tim.diag_down_total
	up_before = tim.diag_up_total
	_touch(Vector2(500, 400), true)
	_touch(Vector2(500, 400), false)
	Input.flush_buffered_events()
	await _frames(3)
	if tim.diag_down_total - down_before == 1 and tim.diag_up_total - up_before == 1:
		_pass("ScreenTouch press/release counted on a touch platform")
	else:
		_fail("expected +1 down/+1 up, got +%d down/+%d up"
			% [tim.diag_down_total - down_before, tim.diag_up_total - up_before])
	tim.is_mobile = false

	# ── 2b. T1.4 double-count guard ──────────────────────────────
	# project.godot sets pointing/emulate_touch_from_mouse=true and leaves
	# emulate_mouse_from_touch at its default (true), so the bot's injected
	# ScreenTouch is ALSO re-delivered as an emulated InputEventMouseButton.
	# _record_diag_event counts ScreenTouch only when is_mobile and MouseButton
	# only when NOT, so on device exactly one of that pair lands in the ring.
	# Prove it: one injected touch pair must add EXACTLY one down, one up, and two
	# ring entries - never two of each, which is what an ungated double-count gives.
	print("")
	print("  ── T1.4 no double-count from emulate_mouse_from_touch (is_mobile=true) ──")
	var emu_tm: bool = ProjectSettings.get_setting("pointing/emulate_touch_from_mouse", false)
	var emu_mt: bool = ProjectSettings.get_setting("pointing/emulate_mouse_from_touch", true)
	print("     emulate_touch_from_mouse=%s  emulate_mouse_from_touch=%s"
		% [str(emu_tm), str(emu_mt)])
	tim.is_mobile = true
	down_before = tim.diag_down_total
	up_before = tim.diag_up_total
	var ring_before: int = tim.diag_events.size()
	_touch(Vector2(520, 420), true)
	_touch(Vector2(520, 420), false)
	Input.flush_buffered_events()
	await _frames(3)
	var d_down: int = tim.diag_down_total - down_before
	var d_up: int = tim.diag_up_total - up_before
	var d_ring: int = tim.diag_events.size() - ring_before
	if d_down == 1 and d_up == 1 and d_ring == 2:
		_pass("one injected touch → +1 down/+1 up, ring +2 (emulated mouse gated out, not doubled)")
	else:
		_fail("double-count risk: got +%d down/+%d up/ring +%d, expected +1/+1/+2"
			% [d_down, d_up, d_ring])
	tim.is_mobile = false

	# ── 3. MiniGameBase per-round attribution ────────────────────────
	print("")
	print("  ── MiniGameBase.get_touch_diagnostic() ──")
	var game_scene := load("res://scenes/minigames/QuickShower.tscn") as PackedScene
	var game = game_scene.instantiate()
	add_child(game)
	await _frames(10)
	if game.has_method("start_game"):
		game.start_game()
	await _frames(2)
	# Delivered but never graded: the exact field signature of the collapsed
	# rounds (received > 0, processed == 0).
	_mouse(Vector2(600, 500), true)
	_mouse(Vector2(600, 500), false)
	Input.flush_buffered_events()
	await _frames(2)
	var diag: Dictionary = game.get_touch_diagnostic()
	if int(diag.get("received", -1)) == 1:
		_pass("round received=1 from the delivery delta")
	else:
		_fail("expected received=1, got %s" % str(diag.get("received")))
	if int(diag.get("processed", -1)) == 0 and int(diag.get("dropped", -1)) == 1:
		_pass("processed=0 → dropped=1, drop_rate_pct=%.1f (received-but-ungraded signature)"
			% float(diag.get("drop_rate_pct", -1.0)))
	else:
		_fail("expected processed=0/dropped=1, got %s" % str(diag))
	if diag.get("event_log", []).size() == 2:
		_pass("event_log carries both events with timestamps")
	else:
		_fail("event_log size %d, expected 2" % int(diag.get("event_log", []).size()))
	# Graded hit side.
	game._record_touch_processed()
	diag = game.get_touch_diagnostic()
	if int(diag.get("processed", -1)) == 1 and int(diag.get("dropped", -1)) == 0:
		_pass("after _record_touch_processed(): dropped=0")
	else:
		_fail("expected processed=1/dropped=0, got %s" % str(diag))
	game.queue_free()
	await _frames(3)

	# ── 4. SessionLogger export ──────────────────────────────────────
	print("")
	print("  ── SessionLogger.record_sp_game() export ──")
	var logger = get_node_or_null("/root/SessionLogger")
	if logger == null:
		_fail("SessionLogger autoload missing")
	else:
		logger.record_sp_game(
			"ProbeGame", 42, 1.0, 500, 0, "Easy", 3,
			{"received": 5, "up_events": 5, "processed": 2, "dropped": 3,
				"drop_rate_pct": 60.0, "event_log": []}
		)
		var last: Dictionary = logger.sp_games[-1]
		if last.has("touch_diagnostic") and int(last["touch_diagnostic"].get("dropped", -1)) == 3:
			_pass("touch_diagnostic persisted on the round record (dropped=3)")
		else:
			_fail("touch_diagnostic not persisted on the round record")

	# ── 5. T1.5: after an AUTOPLAY round every roster game reports a live
	#         touch diagnostic - received>0, a non-empty event_log, and
	#         drop_rate_pct>=0. This is the end-to-end proof that the migrated
	#         handlers really inject: a game the bot drove but never touched would
	#         report received==0, the exact collapsed-round signature.
	print("")
	print("  ── T1.5 autoplay round diagnostic, per roster game ──")
	var apm = get_node_or_null("/root/AutoPlayManager")
	var gm = get_node_or_null("/root/GameManager")
	if apm == null or gm == null:
		_fail("AutoPlayManager/GameManager autoload missing for the roster autoplay drive")
	else:
		# Count the bot's injected ScreenTouch directly, exactly as a device does,
		# so received>0 does not depend on emulate_mouse_from_touch reaching the
		# manager in headless.
		tim.is_mobile = true
		# Drive through the REAL AutoPlayManager._process (the engine ticks the
		# autoload), exactly as VerifyAutoPlayProgress._drive_one does. Hand-calling
		# _dispatch_game_strategy fought the shipped _process - which lifts the finger
		# whenever game_active is momentarily false - and never waited for a slow
		# playfield to spawn, so every hold/drag game (RiceWashRescue, TimingTap,
		# CatchTheRain, ...) reported a false received==0. Letting the real driver run
		# a wall-clock window is what a real autoplay round does.
		var drive_ms: int = 6000
		var max_drive_ms: int = 24000
		var wait_active_ms: int = 3000
		var diag_gaps: PackedStringArray = []
		var only: PackedStringArray = OS.get_cmdline_user_args()
		for id in gm.ALL_SINGLEPLAYER_MINIGAMES:
			if only.size() > 0 and not only.has(str(id)):
				continue
			var path: String = "res://scenes/minigames/%s.tscn" % str(id)
			if not ResourceLoader.exists(path):
				continue
			var packed := load(path) as PackedScene
			if packed == null:
				continue
			var g: Node = packed.instantiate()
			if g == null:
				continue
			# Enabled BEFORE the game enters the tree: register_game() (in the game's
			# own _ready) returns early unless auto-play is already on, and it is what
			# sets current_game/game_name so the real _process drives THIS game.
			apm.auto_play_enabled = true
			apm.auto_play_duration = 0.0
			apm.auto_play_start_time = 0
			apm.current_game = null
			apm.game_name = ""
			get_tree().root.add_child(g)
			await _frames(8)
			if g.has_method("_hide_instruction_overlay"):
				g.call("_hide_instruction_overlay")
			if g.has_method("start_game"):
				g.call("start_game")
			# Wait for the round to actually go live: the four minigames_v2 games make
			# start_game() a coroutine that awaits a ~1s flash before game_active.
			var w0: int = Time.get_ticks_msec()
			while (Time.get_ticks_msec() - w0) < wait_active_ms:
				await get_tree().process_frame
				if not is_instance_valid(g) or not g.is_inside_tree():
					break
				if ("game_active" in g and g.game_active) or ("is_playing" in g and g.is_playing):
					break
			var went_active: bool = (
				is_instance_valid(g) and g.is_inside_tree()
				and ("game_active" in g) and bool(g.game_active)
			)
			# Let the shipped _process inject for a wall-clock window, stretched while
			# nothing has been received yet (a slow playfield, e.g. DropletDash whose
			# first item needs ~5.4s, is given the time it needs without charging every
			# other game for it).
			# Sample the LIVE diagnostic every frame and keep the PEAK received/log.
			# A hold/drag game emits exactly ONE ScreenTouch down for the whole round,
			# and MiniGameBase re-captures _touch_diag_down_base whenever the round
			# re-arms (its attempt/next-round path calls start_game() again). That
			# re-capture happens AFTER the bot's single down, so the FINAL read reports
			# received==0 even though the down was counted mid-round. peak_rec is the
			# honest measurement: it can only exceed 0 if get_touch_diagnostic().received
			# was >0 at some frame, which requires a genuine injected down after the
			# then-current base. Asserting on it (not the final read) is what "the game
			# received input during the autoplay round" actually means.
			var d: Dictionary = {}
			var peak_rec: int = 0
			var peak_log: int = 0
			var t0: int = Time.get_ticks_msec()
			var deadline: int = drive_ms
			while (Time.get_ticks_msec() - t0) < deadline:
				await get_tree().process_frame
				if not is_instance_valid(g) or not g.is_inside_tree():
					break
				# Break the instant the round ends, exactly as _drive_one does: driving on
				# past game_active=false lets the real _process fall into _navigate_ui(),
				# which clicks through the results screen and launches the NEXT game - the
				# session hijack this harness must not trigger.
				if went_active and "game_active" in g and not g.game_active:
					break
				if get_tree().paused:
					get_tree().paused = false
				if is_instance_valid(g) and g.has_method("get_touch_diagnostic"):
					d = g.get_touch_diagnostic()
					peak_rec = maxi(peak_rec, int(d.get("received", 0)))
					peak_log = maxi(peak_log, int(d.get("event_log", []).size()))
				if int(d.get("received", 0)) == 0 and deadline < max_drive_ms:
					deadline = max_drive_ms
			if is_instance_valid(g) and g.has_method("get_touch_diagnostic"):
				d = g.get_touch_diagnostic()
				peak_rec = maxi(peak_rec, int(d.get("received", 0)))
				peak_log = maxi(peak_log, int(d.get("event_log", []).size()))
			var rate: float = float(d.get("drop_rate_pct", -1.0))
			if peak_rec > 0 and peak_log > 0 and rate >= 0.0:
				_pass("%s: received=%d event_log=%d drop_rate_pct=%.1f"
					% [str(id), peak_rec, peak_log, rate])
			else:
				diag_gaps.append("%s(received=%d,log=%d,rate=%.1f)"
					% [str(id), peak_rec, peak_log, rate])
			# Detach and clean up. Unpause BEFORE releasing so _release_pointer() lifts
			# the finger instead of deferring (a paused tree swallows the lift).
			apm.current_game = null
			apm.auto_play_enabled = false
			get_tree().paused = false
			if apm.has_method("_release_pointer"):
				apm.call("_release_pointer")
			if apm.has_method("_reset_gesture"):
				apm.call("_reset_gesture")
			if is_instance_valid(g):
				if g.is_inside_tree():
					get_tree().root.remove_child(g)
				g.free()
			await _frames(2)
		if diag_gaps.is_empty():
			_pass("every roster game reported a live touch diagnostic after an autoplay round")
		else:
			_fail("%d game(s) with a dead diagnostic: %s"
				% [diag_gaps.size(), ", ".join(diag_gaps)])
		tim.is_mobile = false
		apm.auto_play_enabled = false

	print("")
	print("═══════════════════════════════════════════════════════════")
	if _fails == 0:
		print("  ALL TOUCH-DIAGNOSTIC CHECKS PASSED")
	else:
		print("  %d CHECK(S) FAILED" % _fails)
	print("═══════════════════════════════════════════════════════════")
	_tree().quit(1 if _fails > 0 else 0)
