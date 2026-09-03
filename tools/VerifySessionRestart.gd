extends Node

## Repeated whole single-player sessions: does session N start as clean as session 1?
##
## WHAT THIS IS LOOKING FOR
##   A player who finishes a run and presses PLAY AGAIN does not restart the
##   process. Every autoload keeps whatever it was holding, so the second session
##   inherits the first one unless start_new_session() clears it. The failure modes
##   are quiet ones - a score that starts above zero, lives that start below three, a
##   rolling window still holding the previous run, a signal connected twice so one
##   round scores twice, orphaned nodes piling up per session - and none of them
##   raises an error. They just make the game wrong on the second play, which is
##   also the play a thesis demo is most likely to be watched on.
##
##   Six sessions, not two: one repeat cannot separate a one-time warmup cost from a
##   per-session leak. Session 1 pays for resource caches and lazily-built state, so
##   growth is judged from session 2 onward and session 1 is reported but excluded.
##
## WHAT IS DRIVEN, AND HOW HONESTLY
##   start_new_session() and complete_minigame() are the real production entry
##   points: complete_minigame() is what every SP minigame calls when it ends, and it
##   fans out to AdaptiveDifficulty.add_performance(), SaveManager.record_game_result(),
##   SessionLogger.record_sp_game() and PerformanceProfiler.log_event(). So a leak in
##   any of those is inside the measurement, not outside it.
##
##   Lives are written directly (session_lives = n). That is not a shortcut around a
##   production path: MiniGameBase.gd:1850 sets GameManager.session_lives the same
##   way, so a direct write IS the mechanism the game uses.
##
##   The accumulation assertion in the middle of each session is what stops this
##   harness from passing vacuously. If complete_minigame() silently did nothing,
##   every "starts clean" check would pass and the harness would be worthless, so
##   each session first proves the state genuinely moved, and only then that the next
##   start clears it.
##
## Usage:
##   godot --headless --path . res://tools/VerifySessionRestart.tscn

const SESSIONS: int = 6
const ROUNDS_PER_SESSION: int = 8

## Passes over the session-flow menu scenes in phase 2. Four, so pass 1 can be
## discarded as warmup and three comparable passes remain.
const THRASH_PASSES: int = 4

## Highest autoload-connection total seen while a menu scene was live, and which
## scene set it. Used to prove the drift check has something to detect.
var _thrash_peak: int = 0
var _thrash_peak_where: String = ""

## Autoload connections with no scene loaded, captured at the top of phase 2.
var _baseline_conn: int = 0

## The eight games a session plays here. Real registered names, so
## _refresh_available_minigames() and the SaveManager per-game records behave as
## they do in a real run.
const GAMES: Array = [
	"catch_rain", "fix_leak", "plug_the_leak", "cover_the_drum",
	"rice_wash_rescue", "trace_pipe_path", "toilet_tank_fix", "turn_off_tap",
]

var _pass: int = 0
var _fail: int = 0
var _snaps: Array = []


func _gm() -> Node:
	return get_node_or_null("/root/GameManager")


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


## Connection counts for every signal on every autoload.
##
## A signal connected once per session instead of once per process is the classic
## restart bug: the handler runs N times on the Nth session, so one round scores N
## times and nothing anywhere reports an error. Counting the connection list is that
## worry stated as a measurement.
##
## Scoped to ALL autoloads rather than GameManager alone, because GameManager turned
## out to be the wrong place to look: its signals are connected only by the five
## MiniGame_*.gd (reachable via DebugMultiplayer) and by DebugMultiplayer itself, so
## a GameManager-only count came to 1 connection across 20 signals and could not have
## caught anything. The scenes that ship call GameManager methods directly. The
## autoloads that DO get connected from scenes are NetworkManager, AudioManager,
## SaveManager and AdaptiveDifficulty, so those are the ones worth watching.
func _signal_counts() -> Dictionary:
	var out := {}
	for node in get_tree().root.get_children():
		if node == self or node == get_tree().current_scene:
			continue
		for s in node.get_signal_list():
			var n: String = str(s["name"])
			out["%s.%s" % [node.name, n]] = node.get_signal_connection_list(n).size()
	return out


func _snapshot(tag: String) -> Dictionary:
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	return {
		"tag": tag,
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"signals": _signal_counts(),
		"ad_window": (ad.performance_window.size() if ad != null else -1),
	}


## Every field start_new_session() is responsible for clearing, asserted on EVERY
## session rather than only the first.
func _assert_clean(gm: Node, n: int) -> void:
	var where := "session %d" % n
	_check("%s: session_score == 0" % where, gm.session_score == 0,
		"session_score = %d" % gm.session_score)
	_check("%s: round_scores is empty" % where, gm.round_scores.is_empty(),
		"round_scores holds %d entries" % gm.round_scores.size())
	_check("%s: session_lives == 3" % where, gm.session_lives == 3,
		"session_lives = %d" % gm.session_lives)
	_check("%s: completed_minigames is empty" % where, gm.completed_minigames.is_empty(),
		"completed_minigames holds %d" % gm.completed_minigames.size())
	_check("%s: current_minigame_index == 0" % where, gm.current_minigame_index == 0,
		"current_minigame_index = %d" % gm.current_minigame_index)
	_check("%s: minigames_played_this_session == 0" % where,
		gm.minigames_played_this_session == 0,
		"minigames_played_this_session = %d" % gm.minigames_played_this_session)
	_check("%s: session_active is true" % where, gm.session_active,
		"session_active = %s" % str(gm.session_active))
	_check("%s: the finalise latch was released" % where,
		not gm._session_finalized, "_session_finalized = %s" % str(gm._session_finalized))
	# A session must never begin paused. GameManager.start_new_session() does not
	# touch get_tree().paused, so anything that paused the tree and did not unpause
	# would soft-lock the new run behind an invisible pause.
	_check("%s: the tree is not paused at session start" % where,
		not get_tree().paused, "paused = %s" % str(get_tree().paused))
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if ad != null:
		_check("%s: the adaptive rolling window was cleared" % where,
			ad.performance_window.is_empty(),
			"performance_window holds %d entries" % ad.performance_window.size())


## Play a whole session through the real completion path, then spend the last life.
func _play_session(gm: Node, n: int) -> void:
	for i in range(ROUNDS_PER_SESSION):
		var acc: float = 0.35 + 0.07 * float(i % 8)
		var rt: int = 1500 - (i % 8) * 90
		var mistakes: int = (3 - i % 4)
		gm.complete_minigame(GAMES[i % GAMES.size()], acc, rt, mistakes, -1, i % 5,
			mistakes < 2)
		# Lives drain the way MiniGameBase drains them, one per failed round.
		if mistakes >= 2 and gm.session_lives > 0:
			gm.session_lives -= 1
		gm.current_minigame_index += 1
		await _frames(1)
	if gm.has_method("_finalize_session_for_logging"):
		gm._finalize_session_for_logging()
	await _frames(2)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== REPEATED SINGLE-PLAYER SESSION RESTART ===")
	var gm := _gm()
	if gm == null:
		print("  FAIL: GameManager autoload missing")
		get_tree().quit(1)
		return
	# Let every autoload settle so the baseline is not measuring AudioManager
	# prewarming its music cache one track per frame.
	await _frames(20)
	print("  %d sessions x %d rounds, through complete_minigame()"
		% [SESSIONS, ROUNDS_PER_SESSION])
	print("")

	for n in range(1, SESSIONS + 1):
		gm.start_new_session()
		await _frames(3)
		_assert_clean(gm, n)
		_snaps.append(_snapshot("session %d start" % n))

		await _play_session(gm, n)

		# Non-vacuity: the session must actually have moved, or every "starts clean"
		# check above proves nothing.
		var moved: bool = (gm.session_score > 0 and gm.round_scores.size() == ROUNDS_PER_SESSION
			and gm.minigames_played_this_session == ROUNDS_PER_SESSION)
		_check("session %d actually accumulated state before restart" % n, moved,
			"score=%d rounds=%d played=%d lives=%d" % [gm.session_score,
				gm.round_scores.size(), gm.minigames_played_this_session,
				gm.session_lives])
		var s := _snapshot("session %d end" % n)
		print("        session %d end: score=%d rounds=%d lives=%d orphans=%d objects=%d nodes=%d ad_window=%d"
			% [n, gm.session_score, gm.round_scores.size(), gm.session_lives,
				s["orphans"], s["objects"], s["nodes"], s["ad_window"]])
		_snaps.append(s)

	# ── CROSS-SESSION GROWTH ─────────────────────────────────────────────────
	# Judged from session 2 onward. Session 1 pays one-time costs (resource cache,
	# the first SaveManager write, the first SessionLogger record) that are not a
	# per-session leak, and counting them as one would make this harness cry wolf on
	# a healthy build.
	print("")
	print("  -- cross-session growth (session 1 excluded as warmup) --")
	var starts: Array = []
	for s in _snaps:
		if str(s["tag"]).ends_with("start"):
			starts.append(s)

	var base: Dictionary = starts[1]
	var last: Dictionary = starts[starts.size() - 1]
	for key in ["orphans", "objects", "nodes"]:
		var d: int = int(last[key]) - int(base[key])
		var line := "%s: session 2 = %d -> session %d = %d (delta %+d)" % [
			key, int(base[key]), starts.size(), int(last[key]), d]
		print("     %s" % line)
	# Orphans are the one that must be flat: an orphan is a Node with no parent and
	# no one holding it, so a per-session increase is a node the restart forgot.
	_check("orphaned nodes do not grow across sessions",
		int(last["orphans"]) <= int(base["orphans"]), 
		"session 2 = %d, session %d = %d" % [int(base["orphans"]), starts.size(),
			int(last["orphans"])])
	# Nodes are allowed to settle but not to climb once per session. A strictly
	# monotonic climb over four consecutive starts is the signature of a leak; a
	# single step is not.
	var climbs: int = 0
	for i in range(2, starts.size()):
		if int(starts[i]["nodes"]) > int(starts[i - 1]["nodes"]):
			climbs += 1
	_check("live node count does not climb on every restart", climbs < starts.size() - 3,
		"%d of %d consecutive starts increased" % [climbs, starts.size() - 2])

	# Signal connection counts must be IDENTICAL at every session boundary. This is
	# the double-scoring bug stated as a measurement rather than as a worry.
	var sig_drift: Array = []
	var base_sigs: Dictionary = base["signals"]
	for i in range(2, starts.size()):
		var cur: Dictionary = starts[i]["signals"]
		for k in base_sigs.keys():
			if int(cur.get(k, -1)) != int(base_sigs[k]):
				sig_drift.append("%s: %d -> %d at start %d" % [
					k, int(base_sigs[k]), int(cur.get(k, -1)), i + 1])
	_check("no autoload signal gained a connection across sessions",
		sig_drift.is_empty(),
		("drift: %s" % str(sig_drift)) if not sig_drift.is_empty()
			else "%d signals, all stable" % base_sigs.size())
	var connected: int = 0
	for k in base_sigs.keys():
		connected += int(base_sigs[k])
	print("     signals watched: %d, total connections at a session start: %d"
		% [base_sigs.size(), connected])


	# ── PHASE 2: MENU THRASH ─────────────────────────────────────────────────
	# The session loop above never loads a scene, so it cannot see the other half of
	# "state leaking between sessions": a scene that connects to an autoload on
	# _ready() and does not disconnect on exit. Between runs a player walks
	# InitialScreen -> MainMenu -> Settings -> Unlockables -> FinalScore repeatedly,
	# and each of those is instantiated fresh. If any of them leaves a connection or
	# an orphan behind, the count grows once per visit.
	print("")
	print("  -- phase 2: menu thrash, %d passes over the session-flow scenes --"
		% THRASH_PASSES)
	var thrash_scenes: Array = [
		"res://scenes/ui/InitialScreen.tscn",
		"res://scenes/ui/MainMenu.tscn",
		"res://scenes/ui/Settings.tscn",
		"res://scenes/ui/UnlockablesScreen.tscn",
		"res://scenes/ui/FinalScore.tscn",
	]
	var empty_sigs: Dictionary = _signal_counts()
	for k in empty_sigs.keys():
		_baseline_conn += int(empty_sigs[k])
	print("     baseline with no scene loaded: %d autoload connections" % _baseline_conn)
	var thrash_snaps: Array = []
	for p in range(1, THRASH_PASSES + 1):
		for path in thrash_scenes:
			if not ResourceLoader.exists(path):
				continue
			var inst: Node = (load(path) as PackedScene).instantiate()
			get_tree().root.add_child(inst)
			# Long enough for _ready(), the deferred builders and the entry tweens to
			# have run, so a connection made late still counts.
			await _frames(12)
			# NON-VACUITY: count connections while the scene is STILL LIVE. If no menu
			# scene ever connects to an autoload signal, the drift check below cannot
			# catch anything and would pass on an empty set - which is exactly how the
			# GameManager-only version of this harness came to be worthless. Recorded
			# and asserted, not assumed.
			var live_tot: int = 0
			var live_sigs: Dictionary = _signal_counts()
			for k in live_sigs.keys():
				live_tot += int(live_sigs[k])
			if live_tot > _thrash_peak:
				_thrash_peak = live_tot
				_thrash_peak_where = path.get_file().get_basename()
			inst.queue_free()
			await _frames(4)
		var s := _snapshot("thrash pass %d" % p)
		thrash_snaps.append(s)
		var tot: int = 0
		for k in s["signals"].keys():
			tot += int(s["signals"][k])
		print("     pass %d: orphans=%d objects=%d nodes=%d autoload connections=%d"
			% [p, s["orphans"], s["objects"], s["nodes"], tot])

	# Pass 1 is warmup for the same reason session 1 was: first load of each scene
	# pays for its resource cache and its font atlases.
	var tb: Dictionary = thrash_snaps[1]
	var tl: Dictionary = thrash_snaps[thrash_snaps.size() - 1]
	var tb_sigs: Dictionary = tb["signals"]
	var tl_sigs: Dictionary = tl["signals"]
	var t_drift: Array = []
	for k in tb_sigs.keys():
		if int(tl_sigs.get(k, -1)) != int(tb_sigs[k]):
			t_drift.append("%s: %d -> %d" % [k, int(tb_sigs[k]), int(tl_sigs.get(k, -1))])
	_check("no autoload signal gained a connection across menu passes",
		t_drift.is_empty(),
		("drift: %s" % str(t_drift)) if not t_drift.is_empty()
			else "%d signals stable from pass 2 to pass %d" % [tb_sigs.size(),
				thrash_snaps.size()])
	_check("menu scenes do connect to autoload signals while live (non-vacuity)",
		_thrash_peak > int(_baseline_conn),
		"baseline %d with no scene loaded, peak %d while %s was live"
			% [int(_baseline_conn), _thrash_peak, _thrash_peak_where])
	_check("orphaned nodes do not grow across menu passes",
		int(tl["orphans"]) <= int(tb["orphans"]),
		"pass 2 = %d, pass %d = %d" % [int(tb["orphans"]), thrash_snaps.size(),
			int(tl["orphans"])])
	# Node count after a full pass must return to where it started: every scene the
	# pass opened was freed before the snapshot.
	_check("live node count returns to its pass-2 level",
		int(tl["nodes"]) <= int(tb["nodes"]),
		"pass 2 = %d, pass %d = %d" % [int(tb["nodes"]), thrash_snaps.size(),
			int(tl["nodes"])])

	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	print("")
	get_tree().quit(1 if _fail > 0 else 0)
