extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS MULTIPLAYER PAUSE-CLOCK HARNESS
## ═══════════════════════════════════════════════════════════════════
## The multiplayer arm of the same defect tools/VerifyPauseClock.tscn found in
## single player. MultiplayerMiniGameBase computes round time from
##
##     var elapsed := (Time.get_ticks_msec() - game_started_time) / 1000.0
##
## at FOUR sites - :758 (_update_timer_display), :830 (the reaction_time_ms
## reported to NetworkManager.report_player_completion), :873 (the penalty-path
## time-up check) and :1092 (the _process progress bar) - and
## Time.get_ticks_msec() is WALL CLOCK. Meanwhile ui_timer, the Timer child whose
## 1 s tick drives _update_timer_display, is added with add_child() and therefore
## inherits PAUSABLE: it stops when the tree pauses. Two clocks, one of which
## keeps running while the game is frozen.
##
## :758 is the load-bearing one, because _update_timer_display ENDS THE ROUND:
##
##     if remaining <= 0.0 and game_duration < 999999.0:
##         _on_time_up()
##
## So the first tick after a resume can find the round already over, having spent
## the pause out of the players' time.
##
## WHY THIS NEEDS TWO PROCESSES
##   The multiplayer pause is not a local flag. NetworkManager.request_pause()
##   (:1489) broadcasts rpc("_execute_pause"), and the handler at :1495 is what
##   sets get_tree().paused = true on EVERY peer. A single-process probe cannot
##   run that RPC, so it would have to set paused itself - and would then be
##   measuring a pause the game never takes. Both peers here take the real one.
##
##   Running it on two peers also answers a second question the single-player
##   harness could not ask: whether a reliable RPC is still delivered while the
##   tree is paused. If it were not, the CLIENT could never be resumed, because
##   the only way out is the host's _execute_resume broadcast. Case 2 measures
##   that on the client side rather than assuming it.
##
## HONESTY ABOUT WHAT IS COMPRESSED
##   * Each case calls game.start_game() directly after setting game_duration.
##     Both are production calls - start_game() is what the countdown path and
##     _ready()'s no-instructions branch invoke, and game_duration is what
##     _on_multiplayer_ready() sets - and only the NUMBER is chosen for test
##     speed. The instruction overlay's click-to-start is skipped; the timer
##     mechanism under test is untouched.
##   * Real seconds are really waited. A wall-clock defect cannot be reproduced
##     with simulated time.
##   * The ground truth for "how much time should be left" is arithmetic this
##     harness owns: it imposes the pause, so it knows its length by measuring
##     the interval between the two tree.paused transitions it observed itself.
##     The number it compares that against is production-computed, not
##     recomputed here - see _prod_remaining().
##
## Run BOTH processes (host first; it binds the port):
##   godot --headless --path . res://tools/VerifyMPPauseClock.tscn -- host
##   godot --headless --path . res://tools/VerifyMPPauseClock.tscn -- client

const HOST_IP: String = "127.0.0.1"
## Not 7777 (VerifyMultiplayer), 7778 (VerifyMultiplayerReconnect) or 7781/7782
## (VerifyReturnToLobby): a lingering socket from an aborted run of any of those
## would fail this harness's bind for a reason unrelated to what it measures.
const PORT: int = 7783
const CONNECT_TIMEOUT: float = 20.0
const GAME_PATH: String = "res://scenes/multiplayer/MP_CatchTheRain.tscn"

var role: String = "host"
var results: Array = []

## Set on the twin only. See _ready().
var _detached: bool = false

## The round under test, and when this harness saw it start.
var game: Node = null
var _round_start_ms: int = 0

## Pause interval bookkeeping the harness owns. _pause_total_ms is the ground
## truth the production clock is compared against, and it is MEASURED from the two
## tree.paused transitions this process observed - not taken from the sleep length
## requested, which would hide any latency in the RPC round trip.
var _pause_begin_ms: int = 0
var _pause_total_ms: int = 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _ready() -> void:
	if not _detached:
		# The timeline lives on a twin parented straight to /root, for two reasons.
		# One: current_scene is pointed at the minigame under test (see
		# _fresh_round), and a scene change frees current_scene - so the harness
		# must not be it. Two: PROCESS_MODE_ALWAYS, because this probe spends real
		# seconds with the tree paused and a PAUSABLE twin would freeze along with
		# the game it is supposed to be watching.
		var twin: Node = (get_script() as GDScript).new()
		twin.set("_detached", true)
		twin.name = "MPPauseClockProbe"
		twin.process_mode = Node.PROCESS_MODE_ALWAYS
		# Deferred: /root is still "busy setting up children" while the tool
		# scene's own _ready() runs, and a direct add_child() there fails outright.
		_tree().root.add_child.call_deferred(twin)
		return
	_boot()


func _boot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "client":
			role = "client"
		elif arg == "host":
			role = "host"
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  MP PAUSE-CLOCK HARNESS — role: %s   port: %d" % [role, PORT])
	print("  game: %s" % GAME_PATH)
	print("═══════════════════════════════════════════════════════════")
	if role == "host":
		if not GameManager.host_game(PORT):
			_check("GameManager.host_game() succeeded", false, "bind failed on %d" % PORT)
			_finish()
			return
		_check("GameManager.host_game() succeeded", true)
	else:
		if not GameManager.join_game(HOST_IP, PORT):
			_check("GameManager.join_game() succeeded", false)
			_finish()
			return
		_check("GameManager.join_game() succeeded", true)
	_await_connected()

# ── tally ───────────────────────────────────────────────────────────

func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _finish() -> void:
	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  %s RESULT: %d passed, %d failed"
		% [role.to_upper(), results.size() - failed, failed])
	if failed > 0:
		for r in results:
			if not r["ok"]:
				print("    ✗ %s" % r["label"])
	print("═══════════════════════════════════════════════════════════")
	print("")
	_tree().quit(1 if failed > 0 else 0)

# ── waiting ─────────────────────────────────────────────────────────

## Both create_timer() and the process_frame signal keep firing while the tree is
## paused (create_timer's process_always defaults to true, and process_frame is a
## SceneTree signal emitted every iteration regardless of pause), which is what
## lets this timeline spend real seconds inside a pause and still measure it.
func _secs(t: float) -> void:
	await _tree().create_timer(t).timeout


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


## Poll a condition another process has to make true. Two processes boot their
## autoloads at their own pace, so a fixed-instant assertion on a cross-process
## fact is a coin flip on skew.
func _until(cond: Callable, timeout_s: float) -> bool:
	var waited := 0.0
	while waited < timeout_s and not cond.call():
		await _secs(0.05)
		waited += 0.05
	return cond.call()


func _await_connected() -> void:
	var anchored := [false]
	_tree().create_timer(CONNECT_TIMEOUT).timeout.connect(
		func():
			if not anchored[0]:
				_check("peer connected within %ds" % int(CONNECT_TIMEOUT), false)
				_finish())
	if role == "host":
		var cid: int = await multiplayer.peer_connected
		print("  [host] client %d connected" % cid)
	else:
		await multiplayer.connected_to_server
		print("  [client] connected to host")
	anchored[0] = true
	# Let the other side finish its own connection bookkeeping (player numbers and
	# roles are assigned over the wire) before a round is built on top of it.
	# A one-line lambda body: a GDScript inline lambda ends at the newline, so the
	# condition cannot be wrapped onto a second line.
	var ready_ok: bool = await _until(func(): return NetworkManager.is_multiplayer_connected() and NetworkManager.get_local_player_num() > 0, 5.0)
	_check("session established (player num assigned)", ready_ok,
		"player %d, role '%s'" % [NetworkManager.get_local_player_num(),
			NetworkManager.get_player_role(NetworkManager.get_local_player_num())])
	if not ready_ok:
		_finish()
		return
	_run_timeline()

# ── the round under test ────────────────────────────────────────────

## Instantiate a real MP minigame, make it the current scene, and start a round of
## the requested length.
##
## current_scene is pointed at it deliberately: NetworkManager._execute_pause and
## _execute_resume both notify get_tree().current_scene, so with the harness left
## as current_scene the production notification would go to the probe instead of
## the game and that half of the pause path would never run.
func _fresh_round(duration: float) -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
		await _frames(3)
	var packed: PackedScene = load(GAME_PATH) as PackedScene
	game = packed.instantiate()
	_tree().root.add_child(game)
	_tree().current_scene = game
	# _ready() awaits a frame, then reads NetworkManager for the player number and
	# builds the whole HUD. Wait for the artefact the timer assertions depend on
	# rather than for a frame count.
	var built: bool = await _until(
		func(): return game.get("_timer_progress_bar") != null, 5.0)
	if not built:
		_check("round HUD built", false, "timer progress bar never appeared")
		return
	# game_duration is what _on_multiplayer_ready() sets; only the number differs.
	# The progress bar's max_value keeps the 30.0 the HUD was built with, which is
	# above every duration used here, so bar.value is never clamped.
	game.set("game_duration", duration)
	_pause_total_ms = 0
	_pause_begin_ms = 0
	game.start_game()
	_round_start_ms = Time.get_ticks_msec()
	await _frames(2)


## Seconds this round has ACTUALLY been played, by the harness's own reckoning:
## real time since start_game(), minus the pause intervals this process observed.
func _true_play_s() -> float:
	var paused_ms := _pause_total_ms
	if _pause_begin_ms > 0:
		paused_ms += Time.get_ticks_msec() - _pause_begin_ms
	return float(Time.get_ticks_msec() - _round_start_ms - paused_ms) / 1000.0


## The remaining time PRODUCTION computes, through the accessor the four
## production sites use.
##
## The first version of this read _timer_progress_bar.value, on the reasoning that
## the bar is written by production code and so needs no reimplementation here. It
## came back a CONSTANT 30.00 through a 20s round on both peers - and that turned
## out to be a real defect in the game rather than a bad probe: 13 of the 17 MP
## minigames declare their own _process() without calling super._process(), so the
## base's bar update never ran. See MultiplayerMiniGameBase._update_timer_bar().
## The bar is now asserted on its own, by _bar_value(), and the timing measurement
## uses the accessor instead.
##
## The wall-clock fallback is deliberate: without it a pre-fix build - which has no
## elapsed_play_seconds() - could not demonstrate the failure this harness exists
## to demonstrate. It is the exact expression the four sites used before.
func _prod_remaining() -> float:
	var elapsed: float
	if game.has_method("elapsed_play_seconds"):
		elapsed = float(game.call("elapsed_play_seconds"))
	else:
		elapsed = float(Time.get_ticks_msec() - int(game.get("game_started_time"))) / 1000.0
	var pen := float(game.get("_time_penalty_total"))
	return maxf(0.0, float(game.get("game_duration")) - elapsed - pen)


## The progress bar's current value. A separate observable from _prod_remaining()
## because a shadowed base method meant the bar and the arithmetic could disagree.
func _bar_value() -> float:
	var bar = game.get("_timer_progress_bar")
	if bar == null:
		return -1.0
	return float(bar.value)

## The number the PLAYER sees. int(ceil(remaining)) at a 1 s tick, so it is only
## good to about a second - which is why it is asserted with a 1.05 tolerance and
## the precise assertion is made on _prod_remaining() instead.
func _label_secs() -> float:
	var lbl = game.get("timer_label")
	if lbl == null:
		return -1.0
	return float(str(lbl.text).to_int())

# ── the real pause ──────────────────────────────────────────────────

## Take the production multiplayer pause for `hold` real seconds and measure it.
##
## The host drives it through NetworkManager.request_pause() /
## request_resume() - the same two calls MultiplayerMiniGameBase._on_pause_pressed
## (:975) and _on_resume_pressed (:987) make when the player uses the pause menu.
## The client does not touch either: it only watches its own tree.paused, so what
## it records is the pause the RPC actually delivered to it.
##
## Returns what was observed, so the caller can assert on it instead of on a print.
func _do_pause(hold: float) -> Dictionary:
	var out := {"paused_seen": false, "resumed_seen": false, "measured_s": 0.0}
	if role == "host":
		NetworkManager.request_pause()
	# Both sides wait for the flag rather than assuming it: on the host
	# _execute_pause arrives via call_local, on the client over the wire, and the
	# client's arrival time is one of the things being measured.
	out["paused_seen"] = await _until(func(): return _tree().paused, 6.0)
	if not out["paused_seen"]:
		return out
	_pause_begin_ms = Time.get_ticks_msec()
	if role == "host":
		await _secs(hold)
		NetworkManager.request_resume()
	# The client's exit from the pause depends on a reliable RPC being delivered
	# WHILE THE TREE IS PAUSED. If that did not happen the client would be stuck
	# here, which is why the timeout is generous and the result is asserted.
	out["resumed_seen"] = await _until(func(): return not _tree().paused, hold + 8.0)
	if out["resumed_seen"]:
		_pause_total_ms += Time.get_ticks_msec() - _pause_begin_ms
		out["measured_s"] = float(Time.get_ticks_msec() - _pause_begin_ms) / 1000.0
		_pause_begin_ms = 0
	# Two frames so _process() has run at least once on the unpaused tree and the
	# progress bar carries a post-resume value rather than its pre-pause one.
	await _frames(2)
	return out


## Whether the round is still live, tolerating the scene having been freed by a
## round-end fan-out (which is itself proof the round ended).
func _round_live() -> bool:
	if game == null or not is_instance_valid(game):
		return false
	return game.get("game_active") == true

# ── timeline ────────────────────────────────────────────────────────

func _run_timeline() -> void:
	# ── CASE 1: the clock drains. Anti-degeneracy control, first rather than
	#    last: every assertion below is of the form "the clock did NOT lose
	#    time", and a stopped clock would satisfy all of them. This is the check
	#    that fails if the fix is ever "stop counting".
	print("")
	print("  ── CASE 1: baseline drain, no pause ──")
	await _fresh_round(20.0)
	_check("round live after start_game()", _round_live(),
		"game_active=%s duration=%.1f" % [str(game.get("game_active")),
			float(game.get("game_duration"))])
	if not _round_live():
		_finish()
		return
	await _secs(2.0)
	var play1 := _true_play_s()
	var rem1 := _prod_remaining()
	var drift1: float = absf(rem1 - (20.0 - play1))
	_check("clock drains in real time", drift1 <= 0.30,
		"played %.2fs, production remaining %.2fs, expected %.2fs (drift %.2fs)"
			% [play1, rem1, 20.0 - play1, drift1])
	_check("remaining actually moved off the full duration", rem1 < 19.0,
		"remaining %.2fs of 20.0s" % rem1)
	# The timer BAR, separately from the arithmetic. It is initialised to
	# game_duration by _setup_multiplayer_ui() and was never written again in this
	# game, because MP_CatchTheRain overrides _process() without calling super - so
	# a bar still sitting at its 30.0 initial value two seconds into a 20s round is
	# the shadowed-method defect, not a rounding tolerance.
	_check("timer bar animates (base update not shadowed)", _bar_value() < 29.0,
		"bar %.2f, expected about %.2f" % [_bar_value(), 20.0 - play1])

	# ── CASE 2: a short pause must cost the players nothing.
	print("")
	print("  ── CASE 2: 2.5s production pause mid-round ──")
	var p2: Dictionary = await _do_pause(2.5)
	_check("tree.paused reached this peer", bool(p2["paused_seen"]),
		"NetworkManager._execute_pause")
	# The client's half of this is the interesting one: it proves a reliable RPC is
	# still delivered while the tree is paused, without which the client could
	# never be resumed at all.
	_check("resume RPC arrived while paused", bool(p2["resumed_seen"]),
		"pause lasted %.2fs" % float(p2["measured_s"]))
	if not p2["paused_seen"] or not p2["resumed_seen"]:
		_finish()
		return
	var play2 := _true_play_s()
	var rem2 := _prod_remaining()
	var expect2: float = 20.0 - play2
	var stolen2: float = expect2 - rem2
	_check("pause did not consume round time", absf(stolen2) <= 0.30,
		"paused %.2fs; played %.2fs; production remaining %.2fs, expected %.2fs → %+.2fs stolen"
			% [float(p2["measured_s"]), play2, rem2, expect2, stolen2])
	# The label is written by _update_timer_display() on ui_timer's 1 Hz tick, and
	# ui_timer is PAUSABLE - so immediately after a resume the label still holds its
	# PRE-PAUSE value. The first run of this harness read it there and the check
	# passed on that stale number while the underlying clock was 2.5s wrong. Both
	# values are recorded and the assertion is made on the fresh one.
	var label_stale := _label_secs()
	await _secs(1.2)
	var label_fresh := _label_secs()
	var play2b := _true_play_s()
	# ONE-SIDED, and not a loosened tolerance. The label is int(ceil(remaining))
	# written on a 1 Hz tick, so an arbitrary read is up to 1.0s stale and the ceil
	# adds up to another 1.0s: the honest band is
	#     0 <= label - true_remaining <= 2.0
	# A symmetric ±1.05 was simply the wrong description of a ceil-based
	# whole-second countdown, and it failed the client at +1.24 (host +0.22) purely
	# on where the tick happened to land.
	#
	# The band is STRICTER against the defect than the symmetric version was, not
	# looser: a clock that counts the pause makes the label read LOWER than the time
	# truly left, which the lower bound rejects. At this instant a pre-fix build
	# shows about 15 against 16.76 truly remaining - a lower-bound violation of
	# -1.77 - whereas the old symmetric check let the pre-fix run through at +1.02
	# because it read the stale pre-pause value.
	var label_err: float = label_fresh - (20.0 - play2b)
	_check("the number the player SEES agrees", label_err >= -0.05 and label_err <= 2.05,
		"label reads %.0f after a tick (%.0f immediately after resume, stale), true remaining %.2f → %+.2f (band 0..+2 for a 1Hz ceil)"
			% [label_fresh, label_stale, 20.0 - play2b, label_err])
	_check("bar did not lose the pause either",
		absf(_bar_value() - (20.0 - play2b)) <= 0.35,
		"bar %.2f, true remaining %.2f" % [_bar_value(), 20.0 - play2b])
	_check("round survived the pause", _round_live(),
		"game_active=%s" % str(game.get("game_active") if is_instance_valid(game) else "<freed>"))

	# ── CASE 3: a pause LONGER than the time remaining. This is the one that
	#    matters in play: on the wall clock the round is already over when the
	#    players come back, so _update_timer_display()'s first tick after the
	#    resume calls _on_time_up() before either of them can act. In co-op that
	#    fails the round for BOTH players, since the pause is broadcast.
	print("")
	print("  ── CASE 3: 6s pause on a 4s round (pause > remaining) ──")
	await _fresh_round(4.0)
	if not _round_live():
		_check("case 3 round started", false)
		_finish()
		return
	await _secs(1.0)
	var p3: Dictionary = await _do_pause(6.0)
	_check("case 3 pause took effect", bool(p3["paused_seen"]) and bool(p3["resumed_seen"]),
		"paused %.2fs" % float(p3["measured_s"]))
	# _on_time_up() is reached from ui_timer's 1 s tick, so give the resumed tree
	# more than one tick to end the round if it is going to.
	await _secs(1.5)
	var play3 := _true_play_s()
	var rem3 := _prod_remaining()
	_check("round NOT ended by the pause", _round_live(),
		"played %.2fs of 4.0s; production remaining %.2fs; game_active=%s"
			% [play3, rem3, str(game.get("game_active") if is_instance_valid(game) else "<freed>")])
	_check("time still remains after the interruption", rem3 > 0.5,
		"remaining %.2fs, expected %.2fs" % [rem3, 4.0 - play3])

	# ── CASE 4: the round must still be able to end by itself. The second
	#    anti-degeneracy control, and the one that cannot be satisfied by a
	#    frozen clock: nothing here pauses, so a 1.5s round has to time out on
	#    its own within 3s.
	print("")
	print("  ── CASE 4: a 1.5s round still times out on its own ──")
	await _fresh_round(1.5)
	if not _round_live():
		_check("case 4 round started", false)
		_finish()
		return
	var ended: bool = await _until(func(): return not _round_live(), 5.0)
	_check("unpaused round times out by itself", ended,
		"after %.2fs of play, game_active=%s"
			% [_true_play_s(), str(game.get("game_active") if is_instance_valid(game) else "<freed>")])

	print("")
	_finish()
