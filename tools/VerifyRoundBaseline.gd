extends Node

## Can a co-op round's quota be won by the round before it?
##
## The team quota is measured against the shared G-Counter, and a G-Counter only grows. That is
## the point of the structure - it is what makes merges commutative, associative and idempotent,
## which is the property this project's thesis actually claims. It also means the session total
## walks into round 2 already holding round 1's points, so a round whose quota is 80 is won
## before it starts.
##
## The code used to answer that by resetting the counter between rounds (host-only). Reset is
## not one of a G-Counter's operations, and merge is an element-wise max, so the first sync from
## the peer that had not reset put every old value straight back. This gate measures that: it
## resets the way the old code did, merges the peer's stale entry, and shows the total returning.
##
## The fix under test: nothing is reset. The host records the total as a round loads and ships
## that integer to both peers (NetworkManager._load_game_scene / _load_next_round), and the
## round's score is total - baseline.
##
## Run: Godot_v4.7.2 --headless --path . tools/VerifyRoundBaseline.tscn

const GAME := "res://scripts/multiplayer/MP_WaterPlants.gd"
const GAME_SCENE := "res://scenes/multiplayer/MP_WaterPlants.tscn"
## Free at the time of writing: no other tools/Verify*.gd binds it.
const PORT: int = 7812

var _pass := 0
var _fail := 0
var _totals: Array[int] = []

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s%s" % [label, "   " + detail if detail != "" else ""])
	else:
		_fail += 1
		print("  FAIL  %s%s" % [label, "   " + detail if detail != "" else ""])

func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame

func _note_total() -> int:
	var t: int = NetworkManager.get_total_score()
	_totals.append(t)
	return t

func _ready() -> void:
	await _frames(2)
	print("\n=== ROUND BASELINE: is round 2's quota already met when it opens? ===")

	if NetworkManager == null:
		print("  REFUSING: NetworkManager is not in the tree.")
		get_tree().quit(2)
		return
	if not NetworkManager.has_method("get_round_score"):
		_check("NetworkManager exposes get_round_score()", false, "the fix is not present")
		print("\n  RESULT: %d passed, %d failed" % [_pass, _fail])
		get_tree().quit(1)
		return

	# A single process, so "the other peer" is an entry in the counter dictionary. That is all a
	# peer ever is to a G-Counter - the merge does not care where the number came from.
	var me: int = multiplayer.get_unique_id()
	var partner: int = 2 if me != 2 else 1
	NetworkManager.g_counter.clear()
	NetworkManager.round_score_baseline = 0

	# ── round 1: both peers score ──
	NetworkManager.g_counter[me] = 50
	NetworkManager.g_counter[partner] = 40
	_check("round 1 ends on a real team total", _note_total() == 90, "90 points banked")

	# ── the old approach, measured ──
	var before_reset: int = NetworkManager.get_total_score()
	NetworkManager.g_counter.clear()
	NetworkManager.g_counter[me] = 0
	var after_reset: int = NetworkManager.get_total_score()
	# The partner's next sync arrives. _merge_counter takes max(old, incoming) per peer, which
	# is the whole reason a G-Counter converges - and the reason a reset does not survive.
	NetworkManager._merge_counter(partner, 40)
	await _frames(1)
	var after_merge: int = NetworkManager.get_total_score()
	_check("a per-round reset really does clear the total, briefly",
		before_reset == 90 and after_reset == 0, "%d -> %d" % [before_reset, after_reset])
	_check("and the very next merge puts the old points back",
		after_merge >= 40, "total back to %d after one stale merge" % after_merge)

	# ── the baseline approach ──
	NetworkManager.g_counter[me] = 50
	NetworkManager.g_counter[partner] = 40
	var session_total: int = _note_total()
	NetworkManager.round_score_baseline = session_total
	_check("round 2 opens with a round score of zero",
		NetworkManager.get_round_score() == 0,
		"session total %d, round score %d" % [session_total, NetworkManager.get_round_score()])
	_check("the session total is untouched, so the counter is still monotone",
		NetworkManager.get_total_score() == session_total, "%d" % session_total)

	NetworkManager.increment_local(10)
	await _frames(1)
	_check("a point scored in round 2 counts once, not twice",
		NetworkManager.get_round_score() == 10,
		"round %d, session %d" % [NetworkManager.get_round_score(),
			NetworkManager.get_total_score()])

	# The partner's round-2 points land through the merge path, not through this peer.
	NetworkManager._merge_counter(partner, 40 + 25)
	await _frames(1)
	_check("the partner's round-2 points are in the round score too",
		NetworkManager.get_round_score() == 35,
		"round %d = 10 mine + 25 theirs" % NetworkManager.get_round_score())

	# ── the round-load path is what a real session uses ──
	var probe: String = _make_probe_scene()
	if probe == "":
		_check("a scratch scene could be written for the round-load checks", false,
			"user:// is not writable, so the two plumbing checks below did not run")
	else:
		var was_in_progress: bool = bool(NetworkManager.game_in_progress)
		NetworkManager.round_score_baseline = -999
		await _shipped_load(probe, 12345)
		_check("_load_game_scene() applies the baseline the host sent",
			NetworkManager.round_score_baseline == 12345,
			"baseline = %d" % NetworkManager.round_score_baseline)
		NetworkManager.round_score_baseline = 777
		await _shipped_load(probe, -1)
		_check("and leaves it alone when no baseline is supplied",
			NetworkManager.round_score_baseline == 777,
			"still %d" % NetworkManager.round_score_baseline)
		# game_in_progress is a side effect of the shipped body, not of the round below.
		NetworkManager.game_in_progress = was_in_progress
		var d := DirAccess.open("user://")
		if d != null:
			d.remove("_round_baseline_probe.tscn")

	await _check_quota_not_prewon()

	_check("the G-Counter never went down across any of this except the reset under test",
		_totals == [90, 90], str(_totals))

	print("\n  RESULT: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

## An empty scene on disk, so the shipped loader has something real to load that does nothing
## once it arrives. What is under test is the baseline argument, which the body applies before
## it loads anything, so the scene itself only has to exist. Returns "" when it could not be
## written, and the caller reports that instead of quietly measuring nothing.
func _make_probe_scene() -> String:
	var n := Node.new()
	n.name = "RoundBaselineProbeScene"
	var ps := PackedScene.new()
	var packed_ok: bool = ps.pack(n) == OK
	n.free()
	if not packed_ok:
		return ""
	var path: String = "user://_round_baseline_probe.tscn"
	if ResourceSaver.save(ps, path) != OK:
		return ""
	return path


## One shipped round-load, run without letting it take this harness down with it.
##
## _load_game_scene() ends in change_scene_to_packed(), and that frees whatever the tree calls
## its current scene at the end of the frame - which is this node, since the harness IS the
## scene the process booted. The run would end mid-check with nothing reported. So a decoy is
## handed the current_scene slot first: the engine frees the decoy, and the harness carries on
## as an ordinary child of /root. The alternative - passing a path that fails to load, which
## returns early before the scene change - would have measured the same assignment while
## printing an engine error this gate would then have to explain.
func _shipped_load(path: String, baseline_arg: int) -> void:
	var decoy := Node.new()
	decoy.name = "RoundLoadDecoy"
	get_tree().root.add_child(decoy)
	get_tree().current_scene = decoy
	if baseline_arg >= 0:
		NetworkManager._load_game_scene(path, baseline_arg)
	else:
		# The default-argument form, which is what a caller that has no baseline to send uses.
		NetworkManager._load_game_scene(path)
	await _frames(2)


## The end-to-end version of the same question, on the real MP_WaterPlants: its quota is a TEAM
## target of 80 points, and a session that has already banked 200 is not unusual by round three.
## Both halves run here on purpose - the second is this gate's own negative control, because a
## check that cannot fail is not evidence. Without the baseline the round is over on the first
## plant; with it the round has to be played.
##
## The fixture is the one the sibling co-op gates use, and it is not optional here:
## MultiplayerMiniGameBase._ready() refuses to build a round unless
## NetworkManager.is_multiplayer_connected(), and its refusal branch calls
## GameManager.return_to_multiplayer_lobby() - a scene change that would have taken this
## harness down with it. So a host session is opened first. game_active is then written
## directly, because the shipped round opens behind an instruction overlay waiting for a
## tap headless cannot deliver, and end_game() returns early while game_active is false -
## the negative control below could not have observed the round ending without it.
func _check_quota_not_prewon() -> void:
	print("-- the real round: MP_WaterPlants, quota 80, session already holding 200 --")
	if not GameManager.host_game(PORT):
		_check("a host session could be opened for the real round", false,
			"port %d refused, so the end-to-end half did not run" % PORT)
		return
	await _frames(2)
	for with_baseline in [true, false]:
		NetworkManager.g_counter.clear()
		NetworkManager.g_counter[multiplayer.get_unique_id()] = 200
		NetworkManager.round_score_baseline = (
			NetworkManager.get_total_score() if with_baseline else 0
		)
		var packed := load(GAME_SCENE) as PackedScene
		if packed == null:
			_check("MP_WaterPlants.tscn loads", false, GAME_SCENE)
			return
		var game: Node = packed.instantiate()
		get_tree().root.add_child(game)
		# Built, not started: the plants are what _on_multiplayer_ready() spawns, and
		# win_quota is set in the same call, so a non-empty board is the signal that the
		# round this gate is about to score actually exists.
		var waited: float = 0.0
		while waited < 8.0 and (game.get("plants") as Array).is_empty():
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		if (game.get("plants") as Array).is_empty():
			_check("the round is built at all (baseline=%s)" % str(with_baseline), false,
				"no plants after %.1fs, so nothing below was measured" % waited)
			game.queue_free()
			await _frames(2)
			return
		game.set("game_active", true)
		await _frames(1)
		var quota: int = int(game.get("win_quota"))
		# One plant's worth of points, through the same call the game itself uses.
		game.call("add_score", 10)
		await _frames(3)
		var still_running: bool = bool(game.get("game_active"))
		if with_baseline:
			_check("one plant does NOT win a quota-80 round",
				still_running and quota == 80,
				"quota %d, round score %d, still running: %s"
					% [quota, NetworkManager.get_round_score(), str(still_running)])
		else:
			_check("without the baseline the same round is over on that one plant",
				not still_running,
				"quota %d, round score %d (= the session total), still running: %s"
					% [quota, NetworkManager.get_round_score(), str(still_running)])
		game.set("game_active", false)
		game.queue_free()
		await _frames(3)
