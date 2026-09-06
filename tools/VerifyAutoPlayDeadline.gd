extends Node
##
## VerifyAutoPlayDeadline - does the configured auto-play duration actually END the
## session, and can a tester actually configure that duration?
##
## WHY THIS EXISTS
##   Two reports out of the same Android run:
##     "i've seen that autoplay doesnt really sop on the given time, it should stop all
##      activities even in mid game when the time runs out"
##     "setting time can be anything as iv'e seen that the lowest can set is 5 ,10, 15 etc"
##
##   Both reproduced before the fix, and neither was visible to the existing autoplay
##   harnesses, which measure that the bot STARTS (VerifyAutoPlayDrive: every roster game
##   registers under an id the dispatch table knows) and that it PLAYS
##   (VerifyAutoPlayProgress: the game's own counters move). Nothing measured that it
##   stops.
##
##   Deadline: the branch in AutoPlayManager._process cleared auto_play_enabled and
##   nothing else. That stops the synthetic finger and stops nothing else - the round
##   already on screen kept its own clock and ended on its own schedule, so an
##   unattended run did not end at its configured duration; it ended whenever the round
##   it had already entered happened to finish. The attempt-budget rounds from the
##   fairness rework overrun the furthest: the clock is not their opponent, so with
##   nobody left to tap one of those runs all the way to the anti-hang ceiling
##   (4x nominal, never under 45s) before anything ends it.
##
##   Duration boxes: they shipped with step = 5 (Settings) and step = 1 (lobby), and
##   Range.step is a SNAP, not an arrow increment. Measured on this engine build before
##   the fix: a typed 7 became 5 and a typed 12 became 10, so 5 minutes really was the
##   shortest run a tester could ask for.
##
## WHAT IS ASSERTED
##   [1] a live TIMED single-player round is ended BY the deadline, mid-round, through
##       that round's own quit handler: recorded exactly once, timers stopped, driver
##       reset, and the app actually leaves the round.
##   [2] the same for an ATTEMPT-BUDGET round - the family the clock does not end.
##   [3] every round script the deadline can pick up is classified into a family whose
##       handler exists: all 24 single-player scenes, the 12 live MP scenes and the 5
##       legacy co-op scenes, checked on the script the SCENE really loads.
##   [4] the separate MULTIPLAYER deadline ends its round too, and resets the driver -
##       which set_mp_auto_play_enabled(false) never did, so current_game, the strategy
##       and a half-finished drag used to survive the stop.
##   [5] a round the deadline cannot end is REPORTED, and the stop still happens.
##   [6] both duration boxes keep what is typed - 7, 12, 2.5, 0.5, 0 - still clamp at
##       their advertised ceiling, and still reach the code that stores the value.
##
##   Every round case carries its own negative control: the round is held with the
##   duration unlimited and asserted to be still alive and still driven first, so a pass
##   cannot come from a round that was going to end by itself anyway.
##
## Run: godot --headless --path . tools/VerifyAutoPlayDeadline.tscn
## Exit 0 = the duration is both settable and enforced.

const SP_TIMED_SCENE: String = "res://scenes/minigames/CatchTheRain.tscn"
## SpotTheSpeck calls use_attempt_budget(), so its round is not decided by a clock.
## Before the fix this is the shape that overran the furthest: the deadline took the
## finger away and left the round running to its anti-hang ceiling.
const SP_BUDGET_SCENE: String = "res://scenes/minigames/SpotTheSpeck.tscn"
const MP_SCENE: String = "res://scenes/multiplayer/MP_CatchTheRain.tscn"
const SETTINGS_SCENE: String = "res://scenes/ui/Settings.tscn"
const LOBBY_SCENE: String = "res://scenes/ui/MultiplayerLobby.tscn"
const SP_SCENE_FMT: String = "res://scenes/minigames/%s.tscn"

## Seconds a round is held ALIVE before the deadline is brought forward - the control
## half of each round case.
const HOLD_SECONDS: float = 2.5
## Ceiling on a round becoming live. The bot has to dismiss an instruction overlay first
## and the minigames_v2 shells flash a verb for 1.0s inside a coroutine start_game().
const ACTIVE_TIMEOUT: float = 8.0
## Ceiling on the abort. One _process frame reaches the deadline; the handler then runs
## inline, so this is generous by an order of magnitude on purpose.
const ABORT_TIMEOUT: float = 4.0
## Ceiling on leaving the round: MiniGameBase._on_exit_pressed awaits a tally screen
## (fade in, 2.8s, fade out) before it navigates, and the MP path fades for 0.2s.
const LEAVE_TIMEOUT: float = 16.0
## Duration the deadline is moved to when a case wants it to fire on the next frame.
## In MINUTES, because that is the unit the public setter takes - the same unit the
## SpinBox feeds it.
## Not 7777: a stray dev host left running on the default port would make create_server()
## fail and turn this case into a reported failure for an unrelated reason.
const MP_HARNESS_PORT: int = 8912
## Overlay dismissal + the host's 6 s partner-ready fallback + a 3-2-1 countdown.
const MP_ACTIVE_TIMEOUT: float = 22.0
const IMMINENT_MINUTES: float = 0.05 / 60.0

var _pass: int = 0
var _fail: int = 0

func _p(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s%s" % [name, ("  " + detail) if detail != "" else ""])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [name, ("  " + detail) if detail != "" else ""])

func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame

## Real seconds, not frames: headless runs the loop as fast as it can, so a frame count
## is not a duration here and the thing under test is a wall clock.
func _wait_ms(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await get_tree().process_frame

func _wait_until(c: Callable, seconds: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		if bool(c.call()):
			return true
		await get_tree().process_frame
	return bool(c.call())

## Hand the scene under test the current_scene slot.
##
## Not cosmetic: these rounds end by navigating, and change_scene_to_file() frees
## whatever current_scene is. Left alone, the round's own exit chain would delete THIS
## HARNESS mid-await and the run would end with no verdict at all.
func _as_current(n: Node) -> void:
	get_tree().current_scene = n

## Commit a value the way a tester does - typed into the box - not the way code does.
##
## sb.value = x goes through Range.set_value(), and so does the snap, so an assignment
## measures the same rounding a human would hit. What does NOT work is emitting
## LineEdit.text_submitted: SpinBox does not listen to it, and a first probe built that
## way reported 0.000 for every case and nearly cleared the defect.
func _typed(sb: SpinBox, txt: String) -> float:
	sb.get_line_edit().text = txt
	sb.apply()
	return sb.value


func _ready() -> void:
	await get_tree().process_frame
	var apm: Node = get_node_or_null("/root/AutoPlayManager")
	if apm == null:
		print("FATAL: AutoPlayManager autoload missing")
		get_tree().quit(1)
		return

	print("=== AUTOPLAY DEADLINE (%s) ===" % DisplayServer.get_name())
	# The boxes first: cheap, and nothing they do navigates.
	await _case_boxes(apm)
	_case_families()
	await _case_sp(apm, "[1] timed", SP_TIMED_SCENE, 2500)
	# Medium, and a shorter hold: the budget is 5 wrong glasses and the bot is tapping,
	# so a long control window is a window in which the bot can spend the budget and end
	# the round itself - which would measure the budget, not the deadline.
	await _case_sp(apm, "[2] attempt-budget", SP_BUDGET_SCENE, 1500, "Medium")
	await _case_mp(apm)
	await _case_no_handler(apm)

	print("=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## [3] The dispatch in _abort_round() classifies by script inheritance. This is the other
## half of that claim: that every round the autoplayer can actually be holding falls into
## one of those families AND carries the handler the family is dispatched to. A family
## that matched but had no handler would only be discovered by an unattended run that
## failed to end.
##
## Measured on the script the SCENE loads, never on a same-named .gd next to it: a scene
## is free to point at a different script, and a file-name survey would then report a
## handler that the running round does not have.
##
## instantiate() without adding to the tree runs _init and builds the children but not
## _ready, which is what makes this cheap and side-effect free - it is also the only way
## to reach the legacy co-op rounds at all offline, since MiniGame_Rain._ready()
## push_error()s and navigates away without a live peer.
func _case_families() -> void:
	var paths: PackedStringArray = PackedStringArray()
	for id in GameManager.ALL_SINGLEPLAYER_MINIGAMES:
		paths.append(SP_SCENE_FMT % str(id))
	for f in _list("res://scenes/multiplayer", "MP_", ".tscn"):
		paths.append(f)
	for f in _list("res://scripts/multiplayer", "MiniGame_", ".tscn"):
		paths.append(f)

	for path in paths:
		if not ResourceLoader.exists(path):
			_p("[3] %s" % path.get_file(), false, "scene missing")
			continue
		var packed := load(path) as PackedScene
		var inst: Node = packed.instantiate() if packed != null else null
		if inst == null:
			_p("[3] %s" % path.get_file(), false, "instantiate failed")
			continue
		var family: String = ""
		var method: String = ""
		if inst is MiniGameBase:
			family = "MiniGameBase"
			method = "_on_exit_pressed"
		elif inst is MultiplayerMiniGameEffects:
			family = "MultiplayerMiniGameEffects"
			method = "_on_exit_pressed"
		elif inst is MultiplayerMiniGameBase:
			family = "MultiplayerMiniGameBase"
			method = "_on_quit_pressed"
		var script_file: String = ""
		if inst.get_script() != null:
			script_file = str(inst.get_script().resource_path).get_file()
		_p("[3] %s: a family the deadline can end" % path.get_file(),
			family != "" and inst.has_method(method),
			"script=%s family=%s handler=%s" % [
				script_file,
				family if family != "" else "<unclassified>",
				method if method != "" and inst.has_method(method) else "<missing>"])
		inst.free()

func _list(dir_path: String, prefix: String, suffix: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		var name: String = f.trim_suffix(".remap")
		if name.begins_with(prefix) and name.ends_with(suffix):
			out.append("%s/%s" % [dir_path, name])
	out.sort()
	return out


## [1] and [2] - the single-player deadline, end to end, on a round that is demonstrably
## still running when the deadline arrives.
##
## force_diff exists for the attempt-budget half: SpotTheSpeck's budget is
## use_attempt_budget(0, 5, 4), and 0 means "keep the clock", so on Easy - the tier a
## fresh AdaptiveDifficulty starts on - it is an ordinary timed round and would measure
## the same thing case [1] already does. The tier is restored afterwards.
func _case_sp(apm: Node, tag: String, scene_path: String, hold_ms: int = 2500,
		force_diff: String = "") -> void:
	if not ResourceLoader.exists(scene_path):
		_p("%s: scene present" % tag, false, scene_path)
		return
	var gm: Node = get_node_or_null("/root/GameManager")
	var ad: Node = get_node_or_null("/root/AdaptiveDifficulty")
	var diff0: String = ""
	if force_diff != "" and ad != null:
		diff0 = str(ad.current_difficulty)
		ad.current_difficulty = force_diff

	# Unlimited to begin with: nothing may end this round except the deadline this case
	# introduces later, and a duration set now would race the round's own setup.
	apm.set_auto_play_duration(0.0)
	apm.set_auto_play_enabled(true, false)

	var g: Node = (load(scene_path) as PackedScene).instantiate()
	get_tree().root.add_child(g)
	_as_current(g)
	var registered: bool = await _wait_until(
		func(): return is_instance_valid(g) and apm.current_game == g, 4.0)
	# Read once, into a local, at the moment the wait resolved. Reading apm.current_game
	# again while building the message reports whatever it is by then, which is how the
	# first run of this harness printed "current_game=<null>" next to a PASS.
	var held: String = str(apm.current_game.name) if apm.current_game != null else "<null>"
	_p("%s: the autoplayer is holding this round" % tag, registered,
		"current_game=%s" % held)
	if not registered:
		apm.set_auto_play_enabled(false, false)
		if is_instance_valid(g):
			g.queue_free()
		if diff0 != "" and ad != null:
			ad.current_difficulty = diff0
		return

	# is_instance_valid() inside the lambda, not around the await: a round that frees
	# itself mid-wait used to reach the capture and print "Lambda capture at index 1 was
	# freed" - an engine error raised by the harness, in a run whose whole point is that
	# the log is clean.
	var active: bool = await _wait_until(
		func(): return is_instance_valid(g) and bool(g.game_active), ACTIVE_TIMEOUT)
	_p("%s: the round is live before the deadline is touched" % tag, active,
		"game_active=%s fail_mode=%s show_timer=%s duration=%.0fs" % [
			str(g.game_active), str(g.fail_mode), str(g.show_timer),
			float(g.game_duration)])

	# ── control half ────────────────────────────────────────────────────────────────
	# Hold it with the duration unlimited. Whatever the deadline is credited with below,
	# this round has to be demonstrably alive and demonstrably still being driven first,
	# or the pass would just be a round that was going to end anyway.
	await _wait_ms(hold_ms)
	var alive: bool = (is_instance_valid(g) and g.is_inside_tree()
		and get_tree().current_scene == g and bool(g.game_active)
		and not bool(g._quitting))
	_p("%s: unlimited means the round keeps running" % tag, alive,
		"valid=%s active=%s quitting=%s driven=%s elapsed=%.1fs" % [
			str(is_instance_valid(g)),
			str(g.game_active) if is_instance_valid(g) else "n/a",
			str(g._quitting) if is_instance_valid(g) else "n/a",
			str(apm.is_auto_play_enabled()), float(apm.auto_play_elapsed)])
	if not alive:
		apm.set_auto_play_enabled(false, false)
		if is_instance_valid(g):
			g.queue_free()
		if diff0 != "" and ad != null:
			ad.current_difficulty = diff0
		return

	# ── the deadline ────────────────────────────────────────────────────────────────
	var rs0: int = int(gm.round_scores.size())
	var played0: int = int(gm.minigames_played_this_session)
	var win0: int = int(ad.performance_window.size()) if ad != null else -1
	var cap: int = int(ad.window_size) if ad != null else 0
	# Brought forward through the public setter rather than by poking the field, because
	# that setter is what the SpinBox in case [6] calls: a tester lowering the duration
	# below the time already played is the same event.
	apm.set_auto_play_duration(IMMINENT_MINUTES)
	var stopped: bool = await _wait_until(func(): return not apm.is_auto_play_enabled(), ABORT_TIMEOUT)
	_p("%s: the deadline stops the autoplayer" % tag, stopped,
		"enabled=%s" % str(apm.is_auto_play_enabled()))

	# The round's own quit handler ran, and ran once: _quitting is set by
	# MiniGameBase._on_exit_pressed() before its first await, so it is already visible on
	# the frame the flag cleared.
	var ended: bool = (is_instance_valid(g) and bool(g._quitting)
		and not bool(g.game_active) and not bool(g.timer_running))
	_p("%s: and ends the round in progress, mid-round" % tag, ended,
		"quitting=%s active=%s timer_running=%s" % [
			str(g._quitting) if is_instance_valid(g) else "freed",
			str(g.game_active) if is_instance_valid(g) else "freed",
			str(g.timer_running) if is_instance_valid(g) else "freed"])
	_p("%s: the driver is reset, not left holding the round" % tag,
		apm.current_game == null,
		"current_game=%s strategy='%s'" % [
			str(apm.current_game), str(apm.auto_play_strategy)])

	# Recorded exactly once. A deadline that ended the round without reporting it would
	# lose a round out of the session, and one that reported it twice would put two
	# samples of one abandoned round into the thesis window.
	var rs1: int = int(gm.round_scores.size())
	var played1: int = int(gm.minigames_played_this_session)
	var win1: int = int(ad.performance_window.size()) if ad != null else -1
	var win_expect: int = min(win0 + 1, cap) if ad != null else -1
	_p("%s: the aborted round is recorded exactly once" % tag,
		rs1 == rs0 + 1 and played1 == played0 + 1 and win1 == win_expect,
		"round_scores %d->%d played %d->%d window %d->%d (expect %d, cap %d)" % [
			rs0, rs1, played0, played1, win0, win1, win_expect, cap])
	if rs1 > rs0:
		var last: Dictionary = gm.round_scores[rs1 - 1]
		# A quit is not a completed objective: MiniGameBase._on_exit_pressed reports
		# _report_accuracy(false), so a full 1.00 here would mean the abort was recorded
		# as a flawless round.
		_p("%s: recorded as an abandoned round, not a perfect one" % tag,
			float(last.get("accuracy", 1.0)) < 1.0,
			"game='%s' accuracy=%.3f score=%d" % [
				str(last.get("game", "?")), float(last.get("accuracy", -1.0)),
				int(last.get("score", -1))])

	# ── and the app actually leaves ──────────────────────────────────────────────────
	var left: bool = await _wait_until(
		func(): return not is_instance_valid(g) or get_tree().current_scene != g,
		LEAVE_TIMEOUT)
	var now: Node = get_tree().current_scene
	_p("%s: the app leaves the round after the tally" % tag, left,
		"current_scene=%s valid=%s" % [
			str(now.scene_file_path) if now != null else "<none>",
			str(is_instance_valid(g))])

	apm.set_auto_play_enabled(false, false)
	if is_instance_valid(g):
		g.queue_free()
		await _frames(2)
	if diff0 != "" and ad != null:
		ad.current_difficulty = diff0


## [4] The multiplayer deadline is a separate branch with a separate flag, and it had the
## SP hole plus one of its own: set_mp_auto_play_enabled(false) never reset the driver, so
## current_game, the chosen strategy and a half-finished drag survived the stop for the
## next session to inherit. Both halves are measured here.
##
## The round is stood up offline - no peer - which is how the 12 MP scenes are already
## exercised by tools/VerifyMPPlayfieldBounds. Offline it never starts (start_game is a
## network event), and that is exactly the reported shape: a round sitting on screen with
## nobody left to play it.
func _case_mp(apm: Node) -> void:
	if not ResourceLoader.exists(MP_SCENE):
		_p("[4] MP scene present", false, MP_SCENE)
		return
	var gm: Node = get_node_or_null("/root/GameManager")
	var nm: Node = get_node_or_null("/root/NetworkManager")

	# A REAL one-sided host session first. MultiplayerMiniGameBase._ready() gates on
	# NetworkManager.is_multiplayer_connected() and, without it, push_error()s and
	# navigates straight to the lobby - so the first version of this case measured a
	# round that had destroyed itself before any deadline existed, and its "back to the
	# lobby" assertion passed for the wrong reason. A host holding a round with nobody
	# attached is not a contrivance either: it is the state the 6 s partner-ready
	# fallback in _on_instruction_dismissed() is written for.
	var hosted: bool = false
	if nm != null and not bool(nm.is_multiplayer_connected()):
		hosted = bool(nm.create_server(MP_HARNESS_PORT))
	elif nm != null:
		hosted = true
	_p("[4] MP: a live host session for the round to live in", hosted,
		"port=%d connected=%s is_host=%s local_player=%s" % [
			MP_HARNESS_PORT,
			str(nm.is_multiplayer_connected()) if nm != null else "<no NetworkManager>",
			str(nm.is_server()) if nm != null else "-",
			str(nm.get_local_player_num()) if nm != null else "-"])
	if not hosted:
		_p("[4] MP: cannot measure the MP deadline without a session", false,
			"create_server(%d) failed - port busy?" % MP_HARNESS_PORT)
		return

	apm.set_mp_auto_play_duration(0.0)
	apm.set_mp_auto_play_enabled(true)

	var g: Node = (load(MP_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(g)
	_as_current(g)
	var registered: bool = await _wait_until(
		func(): return is_instance_valid(g) and apm.current_game == g, 6.0)
	var held: String = str(apm.current_game.name) if apm.current_game != null else "<null>"
	_p("[4] MP: the autoplayer is holding this round", registered,
		"current_game=%s strategy='%s' role='%s'" % [
			held, str(apm.auto_play_strategy),
			str(g.my_role) if is_instance_valid(g) else "-"])
	if not registered:
		apm.set_mp_auto_play_enabled(false)
		if is_instance_valid(g):
			g.queue_free()
		await _teardown_host(nm)
		return

	# The MP bot dismisses the instruction overlay, the host's partner-ready fallback
	# force-starts the countdown 6 s later, and start_game() lands about 3 s after that -
	# hence a much longer window here than the single-player cases need. Waiting for
	# game_active rather than a fixed sleep is the point: "even in mid game" is only
	# tested if the round really is mid-game when the deadline arrives.
	var active: bool = await _wait_until(
		func(): return is_instance_valid(g) and bool(g.game_active), MP_ACTIVE_TIMEOUT)
	_p("[4] MP: the round reaches live play (countdown done, clock running)", active,
		"game_active=%s elapsed=%ss duration=%ss" % [
			str(g.game_active) if is_instance_valid(g) else "<freed>",
			str(snapped(float(g.elapsed_play_seconds()), 0.1)) if (is_instance_valid(g)
				and g.has_method("elapsed_play_seconds")) else "-",
			str(g.game_duration) if is_instance_valid(g) else "-"])

	await _wait_ms(1500)
	var alive: bool = (is_instance_valid(g) and g.is_inside_tree()
		and get_tree().current_scene == g and bool(g.game_active))
	_p("[4] MP: unlimited leaves the round playing", alive,
		"valid=%s current_scene=%s active=%s" % [str(is_instance_valid(g)),
			str(get_tree().current_scene.name) if get_tree().current_scene != null else "<none>",
			str(g.game_active) if is_instance_valid(g) else "<freed>"])

	# Deliberately dirtied so the reset is measurable rather than assumed: a stop that
	# leaves is_dragging true hands the next session a finger that is already down.
	apm.is_dragging = true
	apm.drag_target = Vector2(111.0, 222.0)

	apm.set_mp_auto_play_duration(IMMINENT_MINUTES)
	var stopped: bool = await _wait_until(
		func(): return not apm.is_mp_auto_play_enabled(), ABORT_TIMEOUT)
	_p("[4] MP: the deadline stops the MP autoplayer", stopped,
		"mp_enabled=%s" % str(apm.is_mp_auto_play_enabled()))
	_p("[4] MP: and resets the driver instead of leaking it into the next session",
		apm.current_game == null and not bool(apm.is_dragging)
			and str(apm.auto_play_strategy) == "",
		"current_game=%s dragging=%s strategy='%s' drag_target=%s" % [
			str(apm.current_game), str(apm.is_dragging), str(apm.auto_play_strategy),
			str(apm.drag_target)])
	# Measured, not assumed: how long the abandoned round kept playing after the
	# deadline. Sampled every frame, because the answer the first run gave was "still
	# playing" and the useful part of that answer is how long for.
	var t0: int = Time.get_ticks_msec()
	var e0: float = float(g.elapsed_play_seconds()) if (is_instance_valid(g)
		and g.has_method("elapsed_play_seconds")) else -1.0
	var live_frames: int = 0
	while (is_instance_valid(g) and bool(g.game_active)
			and Time.get_ticks_msec() - t0 < 4000):
		live_frames += 1
		await get_tree().process_frame
	var live_ms: int = Time.get_ticks_msec() - t0
	var e1: float = float(g.elapsed_play_seconds()) if (is_instance_valid(g)
		and g.has_method("elapsed_play_seconds")) else -1.0
	_p("[4] MP: the live round is stopped, not left playing behind the tally",
		live_frames == 0,
		"kept playing %d frames / %d ms, round clock %.2fs -> %.2fs" % [
			live_frames, live_ms if live_frames > 0 else 0, e0, e1])

	# The only route from here to the lobby is MultiplayerMiniGameBase._on_quit_pressed()
	# -> GameManager.return_to_multiplayer_lobby(), so arriving there IS the evidence that
	# the round's own handler ran rather than the node being quietly discarded.
	var guard: int = 0
	while gm != null and gm.is_scene_transitioning() and guard < 2000:
		guard += 1
		await get_tree().process_frame
	var reached: bool = await _wait_until(
		func(): return (get_tree().current_scene != null
			and str(get_tree().current_scene.scene_file_path) == LOBBY_SCENE),
		LEAVE_TIMEOUT)
	var now: Node = get_tree().current_scene
	_p("[4] MP: the round ends through its own quit handler (back to the lobby)", reached,
		"current_scene=%s paused=%s" % [
			str(now.scene_file_path) if now != null else "<none>",
			str(get_tree().paused)])

	# Quitting an MP round is supposed to close the ENet peer, which is what tells the
	# partner the session is over instead of leaving them on a stale connection. If the
	# deadline ended the round but left the socket open, "stop all activities" is only
	# half true - so this is asserted, not assumed.
	_p("[4] MP: the session itself is closed, not left open",
		nm != null and not bool(nm.is_multiplayer_connected()),
		"connected=%s peer=%s" % [
			str(nm.is_multiplayer_connected()) if nm != null else "-",
			str(multiplayer.multiplayer_peer != null)])

	if is_instance_valid(g):
		g.queue_free()
		await _frames(2)
	await _teardown_host(nm)


## Leaves no socket behind for the next case or the next harness in the serial run.
## A no-op when the round's own quit handler already closed it, which is the pass case.
func _teardown_host(nm: Node) -> void:
	if nm != null and bool(nm.is_multiplayer_connected()):
		if nm.has_method("disconnect_multiplayer"):
			nm.disconnect_multiplayer()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	await _frames(2)


## [5] Honesty check on the failure mode. A round the dispatch cannot classify must not be
## silently skipped: the stop still has to happen, and the round left behind has to be
## reported. The WARNING printed by this case is the assertion, not a defect.
func _case_no_handler(apm: Node) -> void:
	var probe := Node.new()
	probe.name = "NotARound"
	get_tree().root.add_child(probe)
	await get_tree().process_frame

	apm.set_auto_play_duration(IMMINENT_MINUTES)
	apm.set_auto_play_enabled(true, false)
	# Back-dated so the very first _process frame is the deadline frame. Without this the
	# bare probe would spend a few frames as current_game with a real strategy pointed at
	# it, and the case would be measuring the strategy guards instead.
	apm.auto_play_start_time -= 5000
	apm.register_game(probe, "NotARound")
	print("  (expect one WARNING on the next line - that IS the assertion)")

	var stopped: bool = await _wait_until(func(): return not apm.is_auto_play_enabled(), ABORT_TIMEOUT)
	_p("[5] a round with no quit handler still stops the autoplayer",
		stopped and apm.current_game == null,
		"enabled=%s current_game=%s" % [str(apm.is_auto_play_enabled()), str(apm.current_game)])
	_p("[5] and the node is left alone rather than force-freed",
		is_instance_valid(probe) and probe.is_inside_tree(),
		"valid=%s in_tree=%s" % [str(is_instance_valid(probe)),
			str(probe.is_inside_tree() if is_instance_valid(probe) else false)])
	if is_instance_valid(probe):
		probe.queue_free()
		await _frames(2)


## [6] The two duration boxes. The defect was not the arrows - it was Range.step, which
## snaps whatever arrives, typed values included.
func _case_boxes(apm: Node) -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	var had_dev: bool = false
	var dev0: Variant = false
	if sm != null:
		had_dev = sm.settings.has("dev_mode")
		dev0 = sm.settings.get("dev_mode", false)
		# In memory only, and restored below. SaveManager.set_setting() would write
		# waterwise_settings.json, and a harness that leaves dev_mode on for the next
		# process is exactly the leak AutoPlayManager._may_persist() exists to prevent.
		sm.settings["dev_mode"] = true

	if ResourceLoader.exists(SETTINGS_SCENE):
		var s: Node = (load(SETTINGS_SCENE) as PackedScene).instantiate()
		get_tree().root.add_child(s)
		_as_current(s)
		# _ready() awaits a frame before _setup_dev_mode_section() builds the box.
		await _frames(8)
		var sb: SpinBox = s.autoplay_duration_spinbox
		_check_box("[6] settings", sb, "_on_auto_play_duration_changed", 180.0)
		if sb != null:
			# End to end, with the dev gate open the way a tester's phone has it: the
			# handler is gated on dev_mode, and a value that stops at the box would look
			# identical to a value that took.
			apm.set_auto_play_duration(0.0)
			var got: float = _typed(sb, "7")
			await get_tree().process_frame
			_p("[6] settings: 7 typed in the box is 7 minutes in the autoplayer",
				is_equal_approx(got, 7.0)
					and is_equal_approx(float(apm.get_auto_play_duration_minutes()), 7.0),
				"box=%s autoplayer=%s min" % [str(got),
					str(apm.get_auto_play_duration_minutes())])
		s.queue_free()
		await _frames(2)
	else:
		_p("[6] settings: scene present", false, SETTINGS_SCENE)

	if ResourceLoader.exists(LOBBY_SCENE):
		var l: Node = (load(LOBBY_SCENE) as PackedScene).instantiate()
		get_tree().root.add_child(l)
		_as_current(l)
		await _frames(8)
		var mb: SpinBox = l.mp_duration_spinbox
		_check_box("[6] lobby", mb, "_on_mp_duration_changed", 120.0)
		if mb != null:
			apm.set_mp_auto_play_duration(0.0)
			var got: float = _typed(mb, "7")
			await get_tree().process_frame
			_p("[6] lobby: 7 typed in the box is 7 minutes in the autoplayer",
				is_equal_approx(got, 7.0)
					and is_equal_approx(float(apm.get_mp_auto_play_duration_minutes()), 7.0),
				"box=%s autoplayer=%s min" % [str(got),
					str(apm.get_mp_auto_play_duration_minutes())])
		l.queue_free()
		await _frames(2)
	else:
		_p("[6] lobby: scene present", false, LOBBY_SCENE)

	# Left as the round cases expect to find it, and nothing of the tester's kept.
	apm.set_auto_play_duration(0.0)
	apm.set_mp_auto_play_duration(0.0)
	if sm != null:
		if had_dev:
			sm.settings["dev_mode"] = dev0
		else:
			sm.settings.erase("dev_mode")

## The numbers a tester actually types. 7 and 12 are the two the report named; 2.5 and 0.5
## are there because a thesis run wants a short measured session, and 0 is the "until I
## stop it" setting both hints advertise.
func _check_box(tag: String, sb: SpinBox, handler: String, ceiling: float) -> void:
	if sb == null:
		_p("%s: the duration box exists" % tag, false, "member is null")
		return
	_p("%s: the duration box exists" % tag, true,
		"min=%s max=%s step=%s arrow=%s editable=%s" % [
			str(sb.min_value), str(sb.max_value), str(sb.step),
			str(sb.custom_arrow_step), str(sb.editable)])
	_p("%s: step does not snap what is typed" % tag, is_zero_approx(sb.step),
		"step=%s" % str(sb.step))
	_p("%s: the +/- arrows still move at a 0 step" % tag, sb.custom_arrow_step > 0.0,
		"custom_arrow_step=%s" % str(sb.custom_arrow_step))
	_p("%s: the advertised ceiling is the one being clamped to" % tag,
		is_equal_approx(sb.max_value, ceiling),
		"max_value=%s expected=%s" % [str(sb.max_value), str(ceiling)])
	for want in [7.0, 12.0, 2.5, 0.5]:
		var got: float = _typed(sb, str(want))
		_p("%s: typing %s keeps %s" % [tag, str(want), str(want)],
			is_equal_approx(got, float(want)), "value=%s" % str(got))
	var over: float = _typed(sb, "999")
	_p("%s: over the ceiling still clamps" % tag, is_equal_approx(over, ceiling),
		"999 -> %s" % str(over))
	var zero: float = _typed(sb, "0")
	_p("%s: 0 survives as the unlimited setting" % tag, is_zero_approx(zero),
		"0 -> %s" % str(zero))
	var wired: bool = false
	for c in sb.value_changed.get_connections():
		var cb: Callable = c["callable"]
		if str(cb.get_method()) == handler:
			wired = true
	_p("%s: value_changed reaches %s()" % [tag, handler], wired,
		"connections=%d" % sb.value_changed.get_connections().size())
