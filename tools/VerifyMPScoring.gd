extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS MP SCORING / ACCURACY VERIFICATION HARNESS
## ═══════════════════════════════════════════════════════════════════
## FIX 27 and FIX 28 both live in MultiplayerMiniGameBase, and both need a REAL
## minigame scene running on TWO connected peers: MultiplayerMiniGameBase._ready()
## hard-requires NetworkManager.is_multiplayer_connected() and returns to the lobby
## otherwise, and the two defects are about the difference between this peer's own
## points and the team's — a difference that does not exist in one process.
##
##   FIX 27  win_quota is a TEAM point total, not this peer's share: MP_CatchRainAquarium
##           and the partner filling the aquarium both read the same shared G-Counter sum.
##           add_score()'s early-win check and _on_time_up()'s verdict compared it against
##           local_score. A round split evenly met the quota on the scoreboard both players
##           were watching and was still recorded as a LOSS by both peers, feeding a false
##           failure into CoopAdaptation.
##
##   FIX 28  record_mp_action() existed for child games to call and had ZERO call
##           sites across all 12 MP games, so total_actions was always 0 and
##           end_game() fell through to accuracy = local_score / win_quota. Against
##           a shared team quota that makes two players who played completely
##           differently report nearly the same number: |Φ1 - Φ2| stayed near zero,
##           never crossed CoopAdaptation.SKILL_GAP_THRESHOLD (0.15), and the
##           asymmetric co-adaptation branch could effectively never run.
##
## Run (host first, it binds the port):
##   godot --headless --path . res://tools/VerifyMPScoring.tscn -- host
##   godot --headless --path . res://tools/VerifyMPScoring.tscn -- client
##
## The two peers play deliberately UNEQUAL rounds that still add up to the quota. The split
## is derived from the game at runtime (see _derive_from_game) and printed at startup; with
## the shipping numbers — a 100-point team target at 5 points a catch — it comes out as:
##   host   10 scoring events, 0 misses  -> 50 pts, accuracy 10/10 = 1.000
##   client 10 scoring events, 20 misses -> 50 pts, accuracy 10/30 = 0.333
## Team total 100 = win_quota, so the round is a win for both; the proficiency gap is 0.667.
## Pre-FIX-28 both peers report 50/100 = 0.500 and the gap is exactly 0.000, which is the
## state that made the thesis's asymmetric branch dead code.
## ═══════════════════════════════════════════════════════════════════

const HOST_IP: String = "127.0.0.1"
const HOST_PORT: int = 7788
const CONNECT_TIMEOUT: float = 30.0

## The game FIX 27 was found in: its win_quota comment is the one that documents the
## quota as a team target.
const GAME_PATH: String = "res://scenes/multiplayer/MP_CatchRainAquarium.tscn"
const GAME_SCRIPT: String = "res://scripts/multiplayer/MP_CatchRainAquarium.gd"

## The round the two peers play, derived from the GAME'S OWN constants rather than hardcoded.
## FIX 27's claim is "a round split down the middle meets a TEAM quota", not "25 and 25 meet
## 50" — and that target has since been retuned (50 → 100, to agree with the other half of
## the bundle, MP_FillAquarium, which reads the very same shared total). Hardcoding the split
## made this harness fail on a product change that was not a regression, which is the
## opposite of what a regression test is for. _derive_from_game() fills these in before
## either role starts, and prints what it settled on.
var EXPECT_QUOTA: int = 50
var POINTS_PER_HIT: int = 5
var HOST_HITS: int = 5
var CLIENT_HITS: int = 5
var CLIENT_MISSES: int = 10


## Reads the team quota and the per-catch award straight off the game's script, then splits
## the quota evenly between the two peers so their halves add up to it exactly. Misses stay
## at twice this peer's hits, so the client's action accuracy is the same 1/3 at any scale
## and stays well clear of the score/quota figure FIX 28 was about.
func _derive_from_game() -> void:
	var sc: GDScript = load(GAME_SCRIPT) as GDScript
	if sc == null:
		push_error("[MPS] could not read %s — keeping the built-in split" % GAME_SCRIPT)
		return
	var c: Dictionary = sc.get_script_constant_map()
	POINTS_PER_HIT = int(c.get("POINTS_PER_DROP", POINTS_PER_HIT))
	EXPECT_QUOTA = int(c.get("TEAM_TARGET", EXPECT_QUOTA))
	HOST_HITS = EXPECT_QUOTA / (POINTS_PER_HIT * 2)
	CLIENT_HITS = (EXPECT_QUOTA - HOST_HITS * POINTS_PER_HIT) / POINTS_PER_HIT
	CLIENT_MISSES = CLIENT_HITS * 2
	print("  [MPS] quota %d at %d a catch -> host %d hits / client %d hits, %d misses"
		% [EXPECT_QUOTA, POINTS_PER_HIT, HOST_HITS, CLIENT_HITS, CLIENT_MISSES])

## Mirrors CoopAdaptation.SKILL_GAP_THRESHOLD (a const on an autoload is not
## readable through the singleton instance from GDScript).
const SKILL_GAP_THRESHOLD: float = 0.15


func _ready() -> void:
	var role := _resolve_role()
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE MP SCORING VERIFICATION — role: %s" % role.to_upper())
	print("═══════════════════════════════════════════════════════════")
	await get_tree().process_frame
	_derive_from_game()
	await get_tree().process_frame
	match role:
		"host":
			await _run_host()
		"client":
			await _run_client()
		_:
			push_error("[MPS] unknown role '%s' — pass 'host' or 'client' after --" % role)
			get_tree().quit(1)


func _resolve_role() -> String:
	for arg in OS.get_cmdline_user_args():
		var a := arg.strip_edges().to_lower()
		if a == "host" or a == "client":
			return a
	return "host"


## Recorder and finisher are lambdas over a plain Array for the reason documented in
## VerifyMultiplayer: the host's NetworkManager transitions to the next round two
## seconds after both peers report, which frees this node. A captured Array is
## refcounted and outlives the scene; a method on self would not.
func _make_recorder(results: Array) -> Callable:
	return func(label: String, ok: bool, detail: String = "") -> void:
		results.append({"ok": ok, "label": label})
		var mark := "✓" if ok else "✗"
		if detail == "":
			print("  %s %s" % [mark, label])
		else:
			print("  %s %s  — %s" % [mark, label, detail])


func _make_finisher(results: Array, role: String) -> Callable:
	return func() -> void:
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
		Engine.get_main_loop().quit(1 if failed > 0 else 0)


func _make_eventually(check: Callable) -> Callable:
	return func(label: String, cond: Callable, timeout_s: float = 4.0,
			detail: Callable = Callable()) -> void:
		var tree := Engine.get_main_loop() as SceneTree
		var waited := 0.0
		while waited < timeout_s and not cond.call():
			await tree.create_timer(0.1).timeout
			waited += 0.1
		var ok: bool = cond.call()
		var text := ""
		if detail.is_valid():
			text = str(detail.call())
		if ok and waited > 0.0:
			text = ("%s (after %.1fs)" % [text, waited]).strip_edges()
		check.call(label, ok, text)


## Spin up the real minigame scene as a CHILD of this node rather than as the scene
## root, so the harness survives to report. Its _ready() awaits one frame and then
## needs a live connection, which is why this is only ever called after the anchor.
func _spawn_game() -> Node:
	var packed: PackedScene = load(GAME_PATH)
	var game: Node = packed.instantiate()
	add_child(game)
	return game


## Silence the game's own raindrop spawner immediately after start_game().
##
## MP_CatchRainAquarium spawns drops on a Timer and reports a miss for every drop
## that reaches the floor uncaught — with no input driving the bucket that is a
## stream of misses arriving at an unpredictable rate, and every assertion below is
## an EXACT action count. The spawner is stopped rather than the counters reset, so
## the numbers are the ones the scoring path itself produced.
func _quiet_spawner(game: Node) -> void:
	if game.get("spawn_timer") != null:
		(game.spawn_timer as Timer).stop()
	for child in game.get_children():
		if child is Area2D and child.has_meta("type"):
			child.queue_free()


# ── HOST ────────────────────────────────────────────────────────────

func _run_host() -> void:
	var results: Array = []
	var check := _make_recorder(results)
	var eventually := _make_eventually(check)
	var finish := _make_finisher(results, "host")
	var tree := get_tree()
	var nm := NetworkManager

	check.call("create_server() succeeded", nm.create_server(HOST_PORT))

	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
		if not anchored[0]:
			check.call("client connected within %ds" % int(CONNECT_TIMEOUT), false)
			finish.call()
	)
	await nm.player_connected
	anchored[0] = true
	print("  [host] client registered — starting timeline")

	var game := [null]
	var verdict := [null]

	# Snapshot both completion reports the moment the round closes, and assert from
	# the snapshot. Signal-driven rather than clock-driven because the host's
	# NetworkManager starts a round transition 2 s later, and because the client's
	# report arrives whenever the wire delivers it.
	nm.both_players_completed.connect(func(_p1s: bool, _p2s: bool, _p1: int, _p2: int) -> void:
		var status: Dictionary = nm.round_completion_status.duplicate(true)
		var my_id: int = multiplayer.get_unique_id()
		var mine: Dictionary = status.get(my_id, {})
		var theirs: Dictionary = {}
		for pid in status:
			if pid != my_id:
				theirs = status[pid]
		var my_acc: float = float(mine.get("accuracy", -1.0))
		var their_acc: float = float(theirs.get("accuracy", -1.0))
		print("  [host] round closed — my acc=%.4f, partner acc=%.4f" % [my_acc, their_acc])
		check.call("[FIX 28] this peer's accuracy came from its actions, not score/quota",
			is_equal_approx(snappedf(my_acc, 0.0001), 1.0),
			"accuracy=%.4f expected 1.0000 (%d/%d actions; score/quota would be %.4f)"
				% [my_acc, HOST_HITS, HOST_HITS,
				float(HOST_HITS * POINTS_PER_HIT) / float(EXPECT_QUOTA)])
		check.call("[FIX 28] the partner's accuracy is different from this peer's",
			absf(my_acc - their_acc) > 0.0001,
			"host=%.4f partner=%.4f" % [my_acc, their_acc])
		check.call("[FIX 28] the proficiency gap crosses SKILL_GAP_THRESHOLD",
			absf(my_acc - their_acc) > SKILL_GAP_THRESHOLD,
			"|%.4f - %.4f| = %.4f, threshold %.2f"
				% [my_acc, their_acc, absf(my_acc - their_acc), SKILL_GAP_THRESHOLD])
	, CONNECT_ONE_SHOT)

	# ── t=2.0  the real scene, on a real connection ──
	tree.create_timer(2.0).timeout.connect(func() -> void:
		game[0] = _spawn_game()
		print("  [host] instantiated %s" % GAME_PATH)
	)

	# ── t=3.5  start the round and take the preconditions ──
	tree.create_timer(3.5).timeout.connect(func() -> void:
		var g: Node = game[0]
		check.call("the MP scene came up on a live connection",
			g != null and g.get("my_player_num") == 1,
			"player_num=%s" % str(g.get("my_player_num") if g else "<no scene>"))
		check.call("the game declares a TEAM quota of %d" % EXPECT_QUOTA,
			int(g.get("win_quota")) == EXPECT_QUOTA,
			"win_quota=%s" % str(g.get("win_quota")))
		g.game_completed.connect(func(success: bool) -> void:
			verdict[0] = success
			print("  [host] game_completed(%s)" % str(success))
		, CONNECT_ONE_SHOT)
		g.start_game()
		_quiet_spawner(g)
		check.call("the round is active", bool(g.get("game_active")))
	)

	# ── t=4.5  play a clean round: every action correct ──
	tree.create_timer(4.5).timeout.connect(func() -> void:
		var g: Node = game[0]
		for _i in HOST_HITS:
			g.add_score(POINTS_PER_HIT)
		check.call("[FIX 28] scoring events were counted as player actions",
			int(g.get("total_actions")) == HOST_HITS
				and int(g.get("correct_actions")) == HOST_HITS,
			"total=%s correct=%s expected %d/%d" % [str(g.get("total_actions")),
				str(g.get("correct_actions")), HOST_HITS, HOST_HITS])
		check.call("this peer's own share is only half the quota",
			int(g.get("local_score")) == HOST_HITS * POINTS_PER_HIT,
			"local_score=%s" % str(g.get("local_score")))
	)

	# ── t=7.0  the wire delivered the partner's half ──
	# Read through NetworkManager directly, NOT through the method under test, so
	# "the team really reached 50" and "the game can see that it did" stay separate
	# claims. Pre-FIX-27 the first passes and the second fails.
	tree.create_timer(7.0).timeout.connect(func() -> void:
		await eventually.call("both halves of the quota reached this replica",
			func() -> bool: return nm.get_total_score() >= EXPECT_QUOTA, 5.0,
			func() -> String: return "team total=%d, own share=%s" % [nm.get_total_score(), str((game[0] as Node).get("local_score"))])
		var g: Node = game[0]
		check.call("[FIX 27] the game measures the TEAM total, not its own share",
			int(g.team_score()) == nm.get_total_score()
				and int(g.team_score()) != int(g.get("local_score")),
			"team_score()=%d, NetworkManager total=%d, local_score=%s"
				% [int(g.team_score()), nm.get_total_score(), str(g.get("local_score"))])
	)

	# ── t=9.0  time-up on a round the two peers split evenly ──
	# The exact defect: the scoreboard both players watched said 50/50 and this verdict
	# still said LOSS, because it read local_score.
	tree.create_timer(9.0).timeout.connect(func() -> void:
		var g: Node = game[0]
		print("  [host] time-up with local=%s team=%d quota=%d"
			% [str(g.get("local_score")), int(g.team_score()), EXPECT_QUOTA])
		g._on_time_up()
		await tree.create_timer(0.3).timeout
		check.call("[FIX 27] a %d/%d split against a quota of %d is a WIN at time-up"
			% [HOST_HITS * POINTS_PER_HIT, CLIENT_HITS * POINTS_PER_HIT, EXPECT_QUOTA],
			verdict[0] == true, "game_completed reported %s" % str(verdict[0]))
	)

	tree.create_timer(13.5).timeout.connect(finish)


# ── CLIENT ──────────────────────────────────────────────────────────

func _run_client() -> void:
	var results: Array = []
	var check := _make_recorder(results)
	var finish := _make_finisher(results, "client")
	var tree := get_tree()
	var nm := NetworkManager

	check.call("join_server() accepted", nm.join_server(HOST_IP, HOST_PORT))

	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
		if not anchored[0]:
			check.call("connected to host within %ds" % int(CONNECT_TIMEOUT), false)
			finish.call()
	)
	await nm.connection_succeeded
	anchored[0] = true
	print("  [client] connected — starting timeline")

	var game := [null]
	var verdict := [null]

	# ── t=2.0 / t=3.5  same bring-up as the host ──
	tree.create_timer(2.0).timeout.connect(func() -> void:
		game[0] = _spawn_game()
		print("  [client] instantiated %s" % GAME_PATH)
	)

	tree.create_timer(3.5).timeout.connect(func() -> void:
		var g: Node = game[0]
		check.call("the MP scene came up on a live connection",
			g != null and int(g.get("my_player_num")) == 2,
			"player_num=%s" % str(g.get("my_player_num") if g else "<no scene>"))
		g.game_completed.connect(func(success: bool) -> void:
			verdict[0] = success
			print("  [client] game_completed(%s)" % str(success))
		, CONNECT_ONE_SHOT)
		g.start_game()
		_quiet_spawner(g)
	)

	# ── t=4.5  a messy round: ten misses BEFORE any points ──
	# Misses first so the accuracy this peer reports is the accuracy of the whole
	# round: the fifth scoring event below completes the team quota and ends the game
	# from inside add_score(), which is the correct post-FIX-27 behaviour.
	#
	# GameManager.report_damage() returns early unless GameManager.is_host, and this
	# harness deliberately never sets it, so the miss path is exercised without
	# draining team lives — the assertion here is about action accounting and the
	# clock, not about lives.
	tree.create_timer(4.5).timeout.connect(func() -> void:
		var g: Node = game[0]
		var clock_before: float = float(g.get("_time_penalty_total"))
		for _i in CLIENT_MISSES:
			g.report_miss_to_host()
		check.call("[FIX 28] misses were counted as player actions",
			int(g.get("total_actions")) == CLIENT_MISSES
				and int(g.get("correct_actions")) == 0,
			"total=%s correct=%s expected %d/0" % [str(g.get("total_actions")),
				str(g.get("correct_actions")), CLIENT_MISSES])
		# Non-regression guard, not a pre-fix reproduction: a miss already costs the
		# team a shared life, so counting it must NOT also take seconds off the clock.
		# The MP clock penalty stays reachable only through record_mp_action().
		check.call("reporting a miss applied no clock penalty",
			is_equal_approx(float(g.get("_time_penalty_total")), clock_before),
			"penalty total %.1f -> %.1f" % [clock_before, float(g.get("_time_penalty_total"))])
	)
	# ── t=6.0  this peer's half of the quota, paid in one burst ──
	# ── t=6.0  five scoring events; the fifth completes the team quota ──
	tree.create_timer(6.0).timeout.connect(func() -> void:
		var g: Node = game[0]
		for _i in CLIENT_HITS:
			g.add_score(POINTS_PER_HIT)
		var want_total: int = CLIENT_MISSES + CLIENT_HITS
		check.call("[FIX 28] hits and misses landed in the same action counters",
			int(g.get("total_actions")) == want_total
				and int(g.get("correct_actions")) == CLIENT_HITS,
			"total=%s correct=%s expected %d/%d" % [str(g.get("total_actions")),
				str(g.get("correct_actions")), want_total, CLIENT_HITS])
	)

	# ── t=7.5  time-up, in case the quota did not already end the round ──
	# Post-fix this is a no-op: add_score() ended the round the moment the team total
	# hit 50. Pre-FIX-27 nothing ended it, and this is the call that produces the
	# verdict the check below reads — so the check reports the same claim either way
	# instead of failing for the accidental reason that nothing ended the game.
	tree.create_timer(7.5).timeout.connect(func() -> void:
		var g: Node = game[0]
		g._on_time_up()
	)

	# ── t=9.0  this peer's verdict and the accuracy it reported ──
	tree.create_timer(9.0).timeout.connect(func() -> void:
		var g: Node = game[0]
		check.call("[FIX 27] the round this peer half-carried is a WIN for it too",
			verdict[0] == true, "game_completed reported %s" % str(verdict[0]))
		var my_id: int = multiplayer.get_unique_id()
		var mine: Dictionary = nm.round_completion_status.get(my_id, {})
		var acc: float = float(mine.get("accuracy", -1.0))
		var want: float = float(CLIENT_HITS) / float(CLIENT_MISSES + CLIENT_HITS)
		var fallback: float = float(CLIENT_HITS * POINTS_PER_HIT) / float(EXPECT_QUOTA)
		check.call("[FIX 28] the reported accuracy is actions-based, not score/quota",
			absf(acc - want) < 0.001 and absf(acc - fallback) > 0.001,
			"accuracy=%.4f expected %.4f (%d/%d actions); score/quota would be %.4f"
				% [acc, want, CLIENT_HITS, CLIENT_MISSES + CLIENT_HITS, fallback])
	)

	tree.create_timer(12.5).timeout.connect(finish)
