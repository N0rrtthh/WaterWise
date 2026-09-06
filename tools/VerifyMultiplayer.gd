extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS MULTIPLAYER VERIFICATION HARNESS
## ═══════════════════════════════════════════════════════════════════
## Every other harness in tools/ runs in a single process, so none of them can
## reach a line of code that requires a second peer — which is most of
## NetworkManager. Nothing here had ever exercised create_server()/join_server()
## at runtime: the multiplayer fixes in this project were verified by reading and
## by parse-checking only, and an @rpc handler that trusts the wrong argument
## parses perfectly.
##
## This harness runs as two processes talking over 127.0.0.1:7777 and asserts on
## real ENet traffic. Both roles come from one script so the timeline stays in one
## place; the role is chosen on the command line.
##
## Run (host must be started first, it binds the port):
##   godot --headless --path . res://tools/VerifyMultiplayer.tscn -- host
##   godot --headless --path . res://tools/VerifyMultiplayer.tscn -- client
##
## Exit code 0 = all passed, 1 = at least one failure. Each process reports its
## own checks, so read both logs.
##
## Verifies:
##   1. Host/client connect, both see a 2-entry player table
##   2. A legitimate ready flag propagates
##   3. A peer CANNOT mark another peer ready (and so cannot force the countdown)
##   4. A legitimate G-Counter increment converges to both peers
##   5. A peer CANNOT write another peer's G-Counter slot
##   6. Re-sending an identical merge changes nothing (idempotence, over the wire)
##   7. A peer CANNOT file a completion report under another peer's id
##   8. A mid-round disconnect freezes the round in a BOUNDED reconnect hold
##      rather than either emptying it or waiting forever (the expiry that then
##      resolves it is tools/VerifyInRoundReconnect.tscn PHASE 2)
##   9. Concurrent increments on both peers converge (thesis CRDT Events 3–4)
##  10. A client's life request is applied once, by the host, not locally
##  11. Either player may pause; only the host resumes, via a round-trip
##  12. A client game event reaches the host's live scene
##  13. A partner event arriving mid scene-change does not fault
##  14. The bounded water buffer syncs, and a DUPLICATE sync does not grow it
##  15. A malformed water payload is dropped rather than read blindly
##  16. Buffer overflow reaches the partner
##  17. A merge payload is integer-only, constant-size in the value, and fits one
##      small datagram (measured; the "smaller than JSON" wording does not hold at
##      two peers — see the t=22.2 block)
##  18. A client's non-positive submit_score() over the wire cannot decrease the
##      host's G-Counter, and cannot diverge it from the GCounter singleton (FIX 7)
##  19. The host's first-round quota reaches the client even though g_counter then
##      holds only the host (FIX 8)
##  20. A client's later locally computed quota does not overwrite the host's (FIX 9)
##
## Checks 3, 5, 7 and 8 are regression tests for defects that were live in this
## file: the identity parameters were taken on trust, and the host had no
## resolution path for a partner leaving mid-round.
## ═══════════════════════════════════════════════════════════════════

const HOST_IP: String = "127.0.0.1"
const HOST_PORT: int = 7777

## Peer id the host always has under ENet, and the id the spoof tests claim.
const HOST_PEER_ID: int = 1

## How long each side waits for its partner before failing the run.
##
## The two timelines are anchored on the connection event rather than on each
## process's own boot, because the processes are launched seconds apart and each
## boots 23 autoloads at its own pace. A wall-clock schedule shared between them
## drifts by whole seconds: the first run of this harness reported eight failures
## that were purely the host checking a step before the client had reached it.
const CONNECT_TIMEOUT: float = 30.0


## Mirrors NetworkManager.BUFFER_MAX_SIZE. A const on an autoload is not readable
## through the singleton instance from GDScript, so it is restated here; if the
## bounded buffer is ever resized this has to follow.
const BUFFER_MAX: int = 5

## Quotas for the FIX 8/9 phase. HOST_QUOTA is deliberately neither GameManager's
## default nor a number a minigame would compute, so "the client is showing 37"
## can only mean the host's broadcast arrived. DEFAULT_QUOTA mirrors
## GameManager.current_minigame_quota's declared default: pre-FIX-8 the client sat
## on that number for the whole first round.
const HOST_QUOTA: int = 37
const CLIENT_LOCAL_QUOTA: int = 11
const DEFAULT_QUOTA: int = 20

## Filled by the scene-side callbacks at the bottom of this file. NetworkManager
## delivers partner events and water arrivals by calling methods on
## get_tree().current_scene — which, for this harness, is this node — so the real
## delivery path is what populates these, not a test double.
var partner_events: Array = []
var water_arrivals: Array = []
var overflow_seen: Array = [false]

## Latched by _on_remote_pause() / _on_remote_resume() at the bottom of this file, which
## NetworkManager._execute_pause()/_execute_resume() call on get_tree().current_scene.
##
## Latched rather than sampled because a pause is TRANSIENT. The pause check used to poll
## get_tree().paused inside a 2 s window opened by the host's own clock, and the client
## sends its resume 1 s after its pause: when the client timeline ran even 0.4 s ahead -
## which it does, since the client anchors on connection_succeeded and the host on
## player_connected one RTT later - both had already been applied before the host's
## window opened, and the host reported "paused=false" for behaviour its own log showed
## working two lines earlier. Also records whether the tree really was paused at the
## instant of the notification, so the original claim (the pause is synchronous, not just
## announced) is still asserted, at a moment that cannot drift.
var pause_notices: Array = []
var resume_notices: Array = []

func _ready() -> void:
	var role := _resolve_role()
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE MULTIPLAYER VERIFICATION — role: %s" % role.to_upper())
	print("═══════════════════════════════════════════════════════════")

	# Let all autoloads finish _ready() before touching the network.
	await get_tree().process_frame
	await get_tree().process_frame

	match role:
		"host":
			await _run_host()
		"client":
			await _run_client()
		_:
			push_error("[MP] unknown role '%s' — pass 'host' or 'client' after --" % role)
			get_tree().quit(1)


func _resolve_role() -> String:
	for arg in OS.get_cmdline_user_args():
		var a := arg.strip_edges().to_lower()
		if a == "host" or a == "client":
			return a
	return "host"


## Build the shared result recorder.
##
## Returned as a lambda over a plain Array rather than as a method on this node,
## because every step below is scheduled on a SceneTree timer and one of the
## behaviours under test (the mid-round disconnect fix) calls
## change_scene_to_file(), which frees this node. A lambda that touched `self`
## after that point would crash the very check meant to prove the fix works; a
## captured Array is refcounted and outlives the scene.
func _make_recorder(results: Array) -> Callable:
	return func(label: String, ok: bool, detail: String = "") -> void:
		results.append({"ok": ok, "label": label})
		var mark := "✓" if ok else "✗"
		if detail == "":
			print("  %s %s" % [mark, label])
		else:
			print("  %s %s  — %s" % [mark, label, detail])


## Print the tally and exit with the CI-meaningful code.
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


## Assert a condition that a REMOTE process has to make true. Polls until the
## deadline instead of sampling one instant, then records the outcome.
##
## Every clock-anchored arrival check in this harness produced a false failure at least
## once, and always the same way: the log line proving correct behaviour printed on the
## very next line after the ✗. Two examples from the run that motivated this helper —
## "producer's water sync reached the consumer's buffer — queue=0" immediately followed by
## "📡 Received water production sync", and "buffer_overflow never fired" immediately
## followed by two "buffer_overflow received". Nothing was wrong with the game; the
## assertion was simply made too early.
##
## The reason a fixed timer cannot be made safe by adding margin: the two processes anchor
## their timelines on their own connection events (player_connected on the host,
## connection_succeeded on the client, which fires about one RTT earlier), they boot 23
## autoloads at their own pace, and the offset accumulates over a 27 s run. "Eventually,
## within a bound" is the only assertion an asynchronous channel actually supports, and it
## is also the stronger one: it still fails if the message never arrives.
func _make_eventually(check: Callable) -> Callable:
	return func(label: String, cond: Callable, timeout_s: float = 3.0,
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


# ── HOST ────────────────────────────────────────────────────────────

func _run_host() -> void:
	var results: Array = []
	var check := _make_recorder(results)
	var eventually := _make_eventually(check)
	var finish := _make_finisher(results, "host")
	var tree := get_tree()
	var nm := NetworkManager

	check.call("create_server() succeeded", nm.create_server(HOST_PORT))
	check.call("host registered itself as player 1",
		nm.players.get(HOST_PEER_ID, {}).get("player_num", 0) == 1)

	# Observe the consequence of the ready spoof rather than only the flag it
	# would set: pre-fix, a client claiming to be peer 1 completed the ready set
	# and the host emitted this and started the countdown on its own.
	var countdown_box := [false]
	nm.both_players_ready.connect(func() -> void:
		countdown_box[0] = true
		print("  [host] both_players_ready fired")
	)

	# Anchor the timeline on the client's registration, not on this process's boot.
	# player_connected is emitted from _register_player(), so by the time it fires the
	# player table is already populated — which is what every step below reads.
	var anchored := [false]
	get_tree().create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
		if not anchored[0]:
			check.call("client connected within %ds" % int(CONNECT_TIMEOUT), false)
			finish.call()
	)
	await nm.player_connected
	anchored[0] = true
	print("  [host] client registered — starting timeline")

	# ── t=1.5  connection established ──
	tree.create_timer(1.5).timeout.connect(func() -> void:
		check.call("client connected (player table has 2 entries)",
			nm.players.size() == 2, "size=%d" % nm.players.size())
		check.call("remote peer id recorded", nm.remote_player_id != 0,
			"remote_player_id=%d" % nm.remote_player_id)
	)

	# ── t=2.5  legitimate ready flag arrived (client sent it at t=2.0) ──
	tree.create_timer(2.5).timeout.connect(func() -> void:
		var client_ready := false
		for pid in nm.players:
			if pid != HOST_PEER_ID:
				client_ready = nm.players[pid].get("ready", false)
		check.call("client's own ready flag propagated to host", client_ready)
	)

	# ── t=3.5  the ready spoof was rejected (client sent it at t=3.0) ──
	# Pre-fix this wrote players[1]["ready"] = true, which made every player ready
	# and drove _check_all_players_ready() into start_countdown().
	tree.create_timer(3.5).timeout.connect(func() -> void:
		var host_ready: bool = nm.players.get(HOST_PEER_ID, {}).get("ready", false)
		check.call("client CANNOT set the host's ready flag", not host_ready)
		check.call("client CANNOT force the round to start", not countdown_box[0])
	)

	# ── t=4.5  legitimate increment converged (client sent 5 at t=4.0) ──
	tree.create_timer(4.5).timeout.connect(func() -> void:
		var client_slot := 0
		for pid in nm.g_counter:
			if pid != HOST_PEER_ID:
				client_slot = nm.g_counter[pid]
		check.call("client's G-Counter increment reached the host",
			client_slot == 5, "slot=%d expected 5" % client_slot)
	)

	# ── t=5.5  the counter spoof was rejected (client sent it at t=5.0) ──
	# The worst of the identity defects: merge takes MAX, so a slot inflated by
	# another peer could never be brought back down for the rest of the session.
	tree.create_timer(5.5).timeout.connect(func() -> void:
		var host_slot: int = nm.g_counter.get(HOST_PEER_ID, 0)
		check.call("client CANNOT write the host's G-Counter slot",
			host_slot != 9999, "host slot=%d" % host_slot)
	)

	# ── t=6.0  host contributes its own 3 ──
	tree.create_timer(6.0).timeout.connect(func() -> void:
		nm.increment_local(3)
	)

	# ── t=6.7  convergence: 5 (client) + 3 (host) on the host's replica ──
	tree.create_timer(6.7).timeout.connect(func() -> void:
		check.call("host replica converged to 8",
			nm.get_total_score() == 8, "total=%d" % nm.get_total_score())
	)

	# ── t=7.7  idempotence over the wire (client re-sent its merge at t=7.0) ──
	tree.create_timer(7.7).timeout.connect(func() -> void:
		await eventually.call("duplicate merge left the total unchanged",
			func() -> bool: return nm.get_total_score() == 8, 2.0,
			func() -> String: return "total=%d" % nm.get_total_score())
	)

	# ── t=8.6  the completion spoof was rejected (client sent it at t=8.0) ──
	# round_completion_status is what decides life loss and what feeds
	# _apply_rolling_window_adjustment() and CoopAdaptation, so a report filed under
	# the host's id would put performance the host never produced into the adaptive
	# difficulty window.
	tree.create_timer(8.6).timeout.connect(func() -> void:
		check.call("client CANNOT file a completion report as the host",
			not nm.round_completion_status.has(HOST_PEER_ID),
			"status keys=%s" % str(nm.round_completion_status.keys()))
	)

	# ── t=9.0  concurrent writes: both peers raise their own slot in the same tick ──
	# Thesis §CRDT Events 3–4: two players act with no coordination and the replicas
	# reconcile by element-wise max. Every counter check above moved one slot at a
	# time, which a one-way sync would also pass. This moves both at once over real
	# ENet, so the totals can only agree if each side merges what it receives.
	tree.create_timer(9.0).timeout.connect(func() -> void:
		nm.increment_local(4)
		print("  [host] concurrent +4 (own slot → 7)")
	)

	# ── t=10.0  order independence: host 3+4=7, client 5+4=9, total 16 either way ──
	tree.create_timer(10.0).timeout.connect(func() -> void:
		await eventually.call("concurrent increments converged on the host replica",
			func() -> bool: return nm.get_total_score() == 16, 3.0,
			func() -> String: return "total=%d expected 16" % nm.get_total_score())
		check.call("host slot holds only the host's own contributions",
			nm.g_counter.get(HOST_PEER_ID, 0) == 7,
			"host slot=%d expected 7" % nm.g_counter.get(HOST_PEER_ID, 0))
	)

	# ── t=11.8  the client's life request was applied ONCE, by the host ──
	# lose_life() is host-authoritative: a client call must travel out as
	# _request_lose_life and come back as _sync_team_lives. Two decrements would mean
	# the client also applied it locally; none would mean the request never landed.
	#
	# The baseline is captured at t=2.0, not 0.2 s before the remote call. Capturing it
	# at t=10.6 produced "lives 2 → 2": the client's request had already been applied
	# before the host's own timer sampled the "before" value, so the baseline WAS the
	# after-value. Anything sampled by the clock close to a remote event is a coin flip
	# on skew — take the baseline long before, and assert the outcome eventually.
	var lives_before := [0]
	tree.create_timer(2.0).timeout.connect(func() -> void:
		lives_before[0] = nm.team_lives
	)
	tree.create_timer(11.8).timeout.connect(func() -> void:
		await eventually.call("client's life request cost the team exactly one life",
			func() -> bool: return nm.team_lives == lives_before[0] - 1, 3.0,
			func() -> String: return "lives %d → %d" % [lives_before[0], nm.team_lives])
	)

	# ── t=12.6  either player may pause, and the pause is synchronous ──
	# Also proves RPC delivery survives get_tree().paused: if the MultiplayerAPI
	# stopped being polled while paused, a paused co-op game could never be resumed
	# by the player who paused it.
	tree.create_timer(12.6).timeout.connect(func() -> void:
		await eventually.call("client's pause request paused the host too",
			func() -> bool: return (pause_notices.size() >= 1
				and bool(pause_notices[0])), 2.0,
			func() -> String: return ("notices=%d tree_was_paused=%s paused_now=%s"
				% [pause_notices.size(),
					str(pause_notices[0]) if pause_notices.size() > 0 else "-",
					str(tree.paused)]))
	)

	# ── t=13.6  only the host resumes; the client's request round-tripped ──
	# Bounded at 2.5 s so it cannot outlast the pause phase it is meant to end.
	tree.create_timer(13.6).timeout.connect(func() -> void:
		await eventually.call("client's resume request round-tripped through the host",
			func() -> bool: return resume_notices.size() >= 1 and not tree.paused, 2.5,
			func() -> String: return "notices=%d paused=%s" % [
				resume_notices.size(), str(tree.paused)])
	)

	# ── t=14.6  a client game event reached the host's live scene ──
	# send_game_event → _relay_game_event → _receive_game_event → current_scene.
	# on_partner_event() is defined at the bottom of this script, and this harness
	# scene IS current_scene, so the whole relay is exercised end to end.
	tree.create_timer(14.6).timeout.connect(func() -> void:
		await eventually.call("client's game event reached the host's current scene",
			func() -> bool: return partner_events.size() == 1, 2.0,
			func() -> String: return "events=%s" % str(partner_events))
	)

	# ── t=15.0  a partner event arriving mid scene-change must not fault ──
	# _receive_game_event read get_tree().current_scene and called has_method() on it
	# without a null check, unlike the four sibling handlers in the same file
	# (_receive_water_for_consumption, _execute_pause, _execute_resume,
	# sync_pause_state) which all guard it. current_scene is null for the window
	# between change_scene_to_file() freeing the old scene and the new one entering
	# the tree — which is exactly when round-boundary events are still in flight.
	# The restore rides on its own timer so that a fault here cannot strand
	# current_scene at null for the rest of the run.
	var saved_scene := [null]
	tree.create_timer(15.0).timeout.connect(func() -> void:
		saved_scene[0] = tree.current_scene
		tree.current_scene = null
		nm._receive_game_event("during_transition", {})
	)
	tree.create_timer(15.2).timeout.connect(func() -> void:
		if tree.current_scene == null:
			tree.current_scene = saved_scene[0]
	)
	tree.create_timer(15.4).timeout.connect(func() -> void:
		check.call("a partner event during a scene change was survivable",
			tree.current_scene != null and partner_events.size() == 1,
			"scene=%s events=%d" % [str(tree.current_scene), partner_events.size()])
	)

	# ── t=16.0  producer side of the bounded buffer ──
	var produced := [{}]
	tree.create_timer(16.0).timeout.connect(func() -> void:
		nm.produce_water("greywater", 0.8)
		if not nm.water_queue.is_empty():
			produced[0] = nm.water_queue[0].duplicate()
		print("  [host] produced 1 unit, queue=%d" % nm.water_queue.size())
	)

	# ── t=17.2  DUPLICATE: re-send the identical production sync ──
	# The G-Counter is idempotent because merge takes MAX. The water queue has no such
	# property — it appends — so a re-delivered or double-called production sync is the
	# one place where "the same message twice" can change state.
	tree.create_timer(17.2).timeout.connect(func() -> void:
		nm.rpc("_sync_water_produced", produced[0])
		print("  [host] re-sent identical production sync (duplicate probe)")
	)

	# ── t=18.4  INVALID: a payload with none of the fields the handler reads ──
	tree.create_timer(18.4).timeout.connect(func() -> void:
		nm.rpc("_sync_water_produced", {})
		print("  [host] sent malformed production sync (invalid-message probe)")
	)

	# ── t=20.4  the consumer's report removed the unit from the producer's queue ──
	var still_here := func() -> bool:
		for w in nm.water_queue:
			if w.get("seq", -1) == produced[0].get("seq", -2):
				return true
		return false
	tree.create_timer(20.4).timeout.connect(func() -> void:
		await eventually.call("consumer's report cleared the unit from the producer's queue",
			func() -> bool: return not still_here.call(), 3.0,
			func() -> String: return "queue=%d" % nm.water_queue.size())
	)

	# ── t=20.8  overflow the bounded buffer ──
	tree.create_timer(20.8).timeout.connect(func() -> void:
		for i in range(BUFFER_MAX + 2):
			nm.produce_water("greywater", 1.0)
		print("  [host] pushed %d units into a %d-slot buffer" % [BUFFER_MAX + 2, BUFFER_MAX])
	)

	# ── t=22.2  measured payload of one G-Counter merge ──
	# The thesis claims an "Integer-Only Payload Optimization (Binary Protocol)" in place
	# of "standard JSON serialization". Measuring it honestly: at this replica size the
	# byte count is NOT the win. var_to_bytes([peer_id, value]) is 24 B — a 4 B type tag
	# and 4 B length for the array, then 8 B per int — while JSON.stringify of the entire
	# two-peer g_counter is 21 B. Two earlier versions of this check asserted "smaller
	# than JSON" against two different baselines and failed against both (23 B, then
	# 21 B); the number that keeps changing is the baseline, and the claim as literally
	# worded does not hold for two peers. Reported as-is rather than tuned until it
	# passes — the report says so too.
	#
	# What the encoding does buy, and what is asserted here instead:
	#   * integer-only — no strings, floats or nested containers in the payload, so the
	#     receiver does no tokenizing and no allocation to read it;
	#   * constant size — the encoding does not grow with the magnitude of the value,
	#     where JSON gains a byte per decimal digit. That is the property that actually
	#     matters for a counter that climbs all round, and it is measured below by
	#     encoding a small value and a large one;
	#   * bounded — one merge fits a single datagram with room to spare.
	tree.create_timer(22.2).timeout.connect(func() -> void:
		var args := [HOST_PEER_ID, nm.g_counter.get(HOST_PEER_ID, 0)]
		var all_ints := true
		for a in args:
			if typeof(a) != TYPE_INT:
				all_ints = false
		var packed := var_to_bytes(args).size()
		var json_state := JSON.stringify(nm.g_counter).to_utf8_buffer().size()
		var packed_big := var_to_bytes([HOST_PEER_ID, 999_999_999]).size()
		var json_big := JSON.stringify({str(HOST_PEER_ID): 999_999_999}).to_utf8_buffer().size()
		var json_small := JSON.stringify({str(HOST_PEER_ID): 7}).to_utf8_buffer().size()
		print("  [host] merge: %d B packed | whole-state JSON: %d B" % [packed, json_state])
		print("  [host] value 7 vs 999999999 — packed %d→%d B, JSON %d→%d B" % [
			packed, packed_big, json_small, json_big
		])
		check.call("a merge payload carries integers only, no serialized text",
			all_ints, "args=%s" % str(args))
		check.call("a merge payload fits a single small datagram", packed <= 64,
			"%d B" % packed)
		check.call("merge size is constant in the counter value, unlike JSON",
			packed_big == packed and json_big > json_small,
			"packed %d→%d B, JSON %d→%d B" % [packed, packed_big, json_small, json_big])
	)


	# ══ t=25.0  FIX 7/8/9: the GameManager side of the wire ═════════════
	# Everything above this line exercises NetworkManager. GameManager keeps its OWN
	# g_counter and its own quota, reached by two more @rpc("any_peer") handlers, and
	# neither had ever been touched by a second process: FIX 7, 8 and 9 were verified
	# by reading and by parse only. All three are boundary bugs that are invisible in
	# one process — get_remote_sender_id() returns 0 locally, and a broadcast to an
	# empty peer list is indistinguishable from a delivered one.
	#
	# This phase does NOT create a second peer. It adopts the one NetworkManager
	# already owns by setting the same fields GameManager.create_server() sets besides
	# creating the peer, so the RPC boundary under test is the real one.
	# Boxed, not plain locals: GDScript lambdas capture locals BY VALUE at creation,
	# so a value written by one step would be invisible to the next.
	var client_id := [0]
	var gc_base := [0]
	tree.create_timer(25.0).timeout.connect(func() -> void:
		var gm := GameManager
		client_id[0] = multiplayer.get_peers()[0] if multiplayer.get_peers().size() > 0 else 0
		gm.is_host = true
		gm.is_multiplayer_connected = true
		gm.local_player_num = 1
		gm.current_game_mode = GameManager.GameMode.MULTIPLAYER_COOP
		gm._quota_from_host = false
		gm.current_minigame_quota = 20
		# THE precondition for FIX 8, and the reason it has to be re-established here:
		# the steps above added the client to NetworkManager's replica, but on the very
		# first round of a real session GameManager.g_counter holds ONLY the host —
		# create_server() seeds exactly one slot. The old broadcast walked
		# g_counter.keys() and skipped the host's own id, so on that first round it
		# iterated an empty list and the client never heard the quota.
		gm.g_counter.clear()
		gm.g_counter[multiplayer.get_unique_id()] = 0
		gc_base[0] = GCounter.get_player_score(client_id[0]) if GCounter else 0
		check.call("[FIX 8] precondition: the host's G-Counter holds only the host",
			gm.g_counter.size() == 1 and gm.g_counter.has(multiplayer.get_unique_id()),
			"g_counter=%s" % str(gm.g_counter))
		gm.set_minigame_quota(HOST_QUOTA)
		print("  [host] broadcast quota %d to peers %s" % [HOST_QUOTA, str(multiplayer.get_peers())])
	)

	# ── t=28.6  a legitimate remote increment converged (client sent 5 at t=28.0) ──
	tree.create_timer(28.6).timeout.connect(func() -> void:
		await eventually.call("[FIX 7] a legitimate remote increment reached the host",
			func() -> bool: return GameManager.g_counter.get(client_id[0], 0) == 5, 3.0,
			func() -> String: return "peer %d slot=%d" % [client_id[0], GameManager.g_counter.get(client_id[0], 0)])
	)

	# ── t=30.5  the non-positive increments changed nothing (client sent them at t=29.0) ──
	# A G-Counter is grow-only, so submit_score() refuses points <= 0 at the RPC
	# boundary. Pre-fix a client sending -3 drove the host's slot DOWN, which breaks
	# the monotonicity the thesis's convergence argument rests on and also silently
	# diverged this dictionary from the GCounter singleton the thesis exports —
	# GCounter.increment() has always refused negatives.
	tree.create_timer(30.5).timeout.connect(func() -> void:
		var slot: int = GameManager.g_counter.get(client_id[0], 0)
		check.call("[FIX 7] a remote -3 did not decrease the host's counter",
			slot == 5, "peer %d slot=%d expected 5" % [client_id[0], slot])
		check.call("[FIX 7] the global score is still the sum of the honest increments",
			GameManager.get_global_score() == 5,
			"global=%d expected 5" % GameManager.get_global_score())
		var gc_now: int = GCounter.get_player_score(client_id[0]) if GCounter else -1
		# Compared against GameManager's own slot, not only against 5. GCounter.increment()
		# has always refused negatives on its own, so a check that only asserted "the
		# singleton grew by 5" would have passed even with the guard removed — while the two
		# stores the thesis presents as one silently held 5 and 2. The divergence is the
		# defect, so the divergence is what is asserted.
		check.call("[FIX 7] the GCounter singleton and GameManager's replica did not diverge",
			gc_now - gc_base[0] == 5 and gc_now - gc_base[0] == slot,
			"singleton delta=%d vs GameManager slot=%d (both must be 5)" % [gc_now - gc_base[0], slot])
		check.call("[FIX 9] the host's own quota was never overwritten by the client",
			GameManager.current_minigame_quota == HOST_QUOTA,
			"quota=%d expected %d" % [GameManager.current_minigame_quota, HOST_QUOTA])
	)
	# ── t=31.0  arm the mid-round disconnect case ──
	# Stand in for "host finished its game and is waiting on its partner": one
	# completion recorded, round open, game in progress. The client leaves at t=33.0.
	#
	# The arm used to sit at t=25.0, 0.5 s before the client's departure, and the checks
	# on a fixed t=26.6 timer. That failed on cross-process skew, not on behaviour: the
	# host log showed "⚠️ Player disconnected" printing BEFORE "[host] armed", so the arm
	# re-created state the disconnect handler had already resolved and then asserted it
	# had been resolved again. Each side anchors its timeline on its own connection event
	# and the two processes boot 23 autoloads seconds apart, so by t≈25 the accumulated
	# skew exceeded that 0.5 s margin. Two changes make the phase ordering-independent:
	# the margin is now 2.0 s (host arms at 31.0, client leaves at 33.0, each on its own
	# clock), and the assertions run off the player_disconnected signal
	# instead of the clock, so they observe the handler's result whenever it happens.
	var armed := [false]
	tree.create_timer(31.0).timeout.connect(func() -> void:
		nm.game_in_progress = true
		nm.round_in_progress = true
		nm.round_completion_status[HOST_PEER_ID] = {
			"success": true, "score": 10, "accuracy": 1.0, "reaction_time_ms": 900
		}
		armed[0] = true
		print("  [host] armed: waiting on partner with 1/2 completions")
	)

	# ── on player_disconnected  the round is HELD, not thrown away ──
	# Two behaviours have lived here, and this block asserts the one that ships.
	#
	# Pre-fix the host only set game_in_progress = false and stayed in the minigame: the
	# results overlay advances solely on both_players_completed, which needs a second
	# completion entry that could no longer arrive, so the host waited forever. The fix for
	# that resolved the round immediately - and that is what this block used to assert.
	#
	# Immediate resolution is no longer the contract. _begin_reconnect_hold() freezes a live
	# round for RECONNECT_HOLD_SECONDS first, because a client whose wifi blips for two
	# seconds should not lose the round; only when the hold expires unrejoined does
	# _resolve_lost_peer() clear the completion, close the round and leave for the lobby.
	# So asserting an empty round_completion_status 0.6s after the drop was asserting the
	# absence of the hold: three failures against a game that is doing the right thing.
	#
	# What is measured here is the hold itself, and it has teeth - delete the hold and every
	# line below fails. The other half, the expiry that resolves the round, is
	# tools/VerifyInRoundReconnect.tscn PHASE 2, which times it off the hold's own signals
	# instead of a poll, and does not need this 35s timeline extended past a scene change
	# that would free this harness.
	nm.player_disconnected.connect(func(_peer_id: int) -> void:
		if not armed[0]:
			# Skew large enough to invert the 2.0 s margin would mean the two processes
			# drifted by seconds; say so plainly rather than reporting four bogus
			# behavioural failures, which is what the fixed-timer version did.
			print("  [host] SKEW: partner left before the arm — disconnect phase not exercised")
			return
		# The hold opens inside the same frame as the drop, across a deferred call; settle.
		await tree.create_timer(0.6).timeout
		check.call("a partner leaving mid-round opens the reconnect hold",
			nm.is_reconnect_hold_active(),
			"hold=%s" % str(nm.is_reconnect_hold_active()))
		check.call("the held round keeps the completion it already has",
			nm.round_completion_status.has(HOST_PEER_ID),
			"status=%s" % str(nm.round_completion_status))
		check.call("the held round stays open, so a returning peer has one to return to",
			nm.round_in_progress and nm.game_in_progress,
			"round=%s game=%s" % [str(nm.round_in_progress), str(nm.game_in_progress)])
		# Bounded, not indefinite - the whole point of the pre-fix defect was a wait with no
		# end. The expiry's effect is VerifyInRoundReconnect's; that it is COMING is here.
		check.call("the hold is bounded by a running timer, not an indefinite wait",
			NetworkManager.RECONNECT_HOLD_SECONDS > 0.0
				and nm._reconnect_hold_timer.time_left > 0.0,
			"%.1fs cap, %.1fs left" % [NetworkManager.RECONNECT_HOLD_SECONDS,
				nm._reconnect_hold_timer.time_left])
		check.call("player table dropped the departed peer",
			nm.players.size() == 1, "size=%d" % nm.players.size())
	, CONNECT_ONE_SHOT)

	tree.create_timer(35.5).timeout.connect(finish)


# ── CLIENT ──────────────────────────────────────────────────────────

func _run_client() -> void:
	var results: Array = []
	var check := _make_recorder(results)
	var eventually := _make_eventually(check)
	var finish := _make_finisher(results, "client")
	var tree := get_tree()
	var nm := NetworkManager

	nm.buffer_overflow.connect(func() -> void:
		overflow_seen[0] = true
		print("  [client] buffer_overflow received")
	)

	check.call("join_server() accepted", nm.join_server(HOST_IP, HOST_PORT))

	# Anchor on the actual connection, same reason as the host side. This fires ~1 RTT
	# BEFORE the host's anchor (connection_succeeded is emitted right after the
	# register RPC is sent, player_connected once it has been handled), so every
	# client action lands slightly ahead of the host check that inspects it — the safe
	# direction for the schedule below.
	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
		if not anchored[0]:
			check.call("connected to host within %ds" % int(CONNECT_TIMEOUT), false)
			finish.call()
	)
	await nm.connection_succeeded
	anchored[0] = true
	print("  [client] connected — starting timeline")

	# ── t=1.5  connection established, player list synced from the host ──
	tree.create_timer(1.5).timeout.connect(func() -> void:
		check.call("connected to host", nm.connection_active and not nm.is_host)
		check.call("player list synced from host (2 entries)",
			nm.players.size() == 2, "size=%d" % nm.players.size())
		check.call("own peer id is not the host's",
			multiplayer.get_unique_id() != HOST_PEER_ID,
			"id=%d" % multiplayer.get_unique_id())
	)

	# ── t=2.0  legitimate: mark MYSELF ready ──
	tree.create_timer(2.0).timeout.connect(func() -> void:
		nm.set_local_player_ready()
		print("  [client] sent own ready flag")
	)

	# ── t=3.0  SPOOF: claim to be the host and mark IT ready ──
	# This is the original defect, reproduced deliberately. _sync_player_ready takes
	# the peer id as a parameter, so nothing but the new sender check stands between
	# this line and the host starting the round on a client's say-so.
	tree.create_timer(3.0).timeout.connect(func() -> void:
		nm.rpc("_sync_player_ready", HOST_PEER_ID, true)
		print("  [client] sent SPOOFED ready for peer %d" % HOST_PEER_ID)
	)

	# ── t=4.0  legitimate: increment my own counter by 5 ──
	tree.create_timer(4.0).timeout.connect(func() -> void:
		nm.increment_local(5)
		print("  [client] incremented own G-Counter slot by 5")
	)

	# ── t=5.0  SPOOF: write the host's G-Counter slot ──
	tree.create_timer(5.0).timeout.connect(func() -> void:
		nm.rpc("_merge_counter", HOST_PEER_ID, 9999)
		print("  [client] sent SPOOFED merge for peer %d = 9999" % HOST_PEER_ID)
	)

	# ── t=6.7  convergence on THIS replica too (A→B→A) ──
	# The host's own +3 has to come back to the client for the two replicas to agree;
	# checking only the host would pass on a one-way sync.
	tree.create_timer(6.7).timeout.connect(func() -> void:
		check.call("client replica converged to 8",
			nm.get_total_score() == 8, "total=%d" % nm.get_total_score())
		check.call("own slot survived the rejected spoof",
			nm.get_player_score(multiplayer.get_unique_id()) == 5,
			"own slot=%d" % nm.get_player_score(multiplayer.get_unique_id()))
	)

	# ── t=7.0  re-send an identical merge (idempotence) ──
	tree.create_timer(7.0).timeout.connect(func() -> void:
		nm.rpc("_merge_counter", multiplayer.get_unique_id(), 5)
		print("  [client] re-sent identical merge (idempotence probe)")
	)

	# ── t=8.0  SPOOF: file a completion report as the host ──
	tree.create_timer(8.0).timeout.connect(func() -> void:
		nm.rpc("_sync_player_completion", HOST_PEER_ID, true, 999, 1.0, 1)
		print("  [client] sent SPOOFED completion for peer %d" % HOST_PEER_ID)
	)

	# ── t=9.0  concurrent write, same tick as the host's ──
	tree.create_timer(9.0).timeout.connect(func() -> void:
		nm.increment_local(4)
		print("  [client] concurrent +4 (own slot → 9)")
	)

	# ── t=10.0  the same total must appear on this replica too (A→B→A) ──
	tree.create_timer(10.0).timeout.connect(func() -> void:
		check.call("concurrent increments converged on the client replica",
			nm.get_total_score() == 16, "total=%d expected 16" % nm.get_total_score())
		check.call("client slot holds only the client's own contributions",
			nm.get_player_score(multiplayer.get_unique_id()) == 9,
			"own slot=%d expected 9" % nm.get_player_score(multiplayer.get_unique_id()))
	)

	# ── t=10.8  ask the host for a life deduction (client has no authority) ──
	# The non-deduction assertion is made in THIS lambda, immediately after the call,
	# not on a later timer. An earlier version checked at t=11.0 and failed reporting
	# "lives=2 expected 3" — by then the host's entirely legitimate _sync_team_lives(2)
	# had already landed over loopback, so the check was racing the correct behaviour
	# rather than testing it. Godot delivers RPCs only when the MultiplayerAPI is polled,
	# never re-entrantly inside a call, so the frame that calls lose_life() is the only
	# place where "did the client change team_lives by itself?" is answerable at all.
	var lives_before := [0]
	tree.create_timer(10.8).timeout.connect(func() -> void:
		lives_before[0] = nm.team_lives
		nm.lose_life()
		print("  [client] called lose_life() (routes to _request_lose_life)")
		check.call("client did not deduct the life locally",
			nm.team_lives == lives_before[0],
			"lives=%d expected %d" % [nm.team_lives, lives_before[0]])
	)

	# ── t=11.8  the host's authoritative value came back ──
	tree.create_timer(11.8).timeout.connect(func() -> void:
		check.call("host's life deduction synced back to the client",
			nm.team_lives == lives_before[0] - 1,
			"lives %d → %d" % [lives_before[0], nm.team_lives])
	)

	# ── t=12.0  the non-host player pauses ──
	tree.create_timer(12.0).timeout.connect(func() -> void:
		nm.request_pause()
		print("  [client] requested pause")
	)

	tree.create_timer(12.6).timeout.connect(func() -> void:
		check.call("client's own pause took effect locally", tree.paused)
	)

	# ── t=12.9  the non-host player asks to resume ──
	tree.create_timer(12.9).timeout.connect(func() -> void:
		nm.request_resume()
		print("  [client] requested resume (routes to _request_resume_from_client)")
	)

	tree.create_timer(13.6).timeout.connect(func() -> void:
		check.call("client's resume request unpaused this side", not tree.paused)
	)

	# ── t=14.0  send a game event to the partner ──
	tree.create_timer(14.0).timeout.connect(func() -> void:
		nm.send_game_event("client_evt", {"n": 7})
		print("  [client] sent game event")
	)

	# ── t=16.8  the producer's unit reached the consumer's buffer ──
	# Eventual, not instantaneous: this asserts something the OTHER process has to
	# do. Sampled at a fixed t=16.8 it read queue=0 and failed, and the next line in
	# the log was "📡 Received water production sync" — the packet was in flight, not
	# missing. See _make_eventually().
	tree.create_timer(16.8).timeout.connect(func() -> void:
		await eventually.call("producer's water sync reached the consumer's buffer",
			func() -> bool: return nm.water_queue.size() == 1, 3.0,
			func() -> String: return "queue=%d" % nm.water_queue.size())
	)

	# ── t=18.0  a re-delivered production sync must not create a second unit ──
	# The buffer is bounded at BUFFER_MAX_SIZE and overflow is a fail state, so a
	# duplicate that appends is not cosmetic: it consumes a slot the producer never
	# filled and can push the team into an overflow they did not cause.
	var dup_size := [0]
	tree.create_timer(18.0).timeout.connect(func() -> void:
		dup_size[0] = nm.water_queue.size()
		check.call("duplicate production sync left the buffer unchanged",
			nm.water_queue.size() == 1, "queue=%d expected 1" % nm.water_queue.size())
	)

	# ── t=19.0  a malformed payload must be dropped, not read blindly ──
	# _sync_water_produced read water_data.producer_id as a PROPERTY. On a Dictionary
	# missing that key that is a hard runtime error, not a null, and the handler is
	# @rpc("any_peer") — so any peer could fault the other side by sending {}. Confirmed
	# before the fix: "Invalid access to property or key 'producer_id' on a base object
	# of type 'Dictionary'." It now shape-checks the payload and drops what it cannot use.
	tree.create_timer(19.0).timeout.connect(func() -> void:
		check.call("malformed production sync changed nothing",
			nm.water_queue.size() == dup_size[0],
			"queue=%d expected %d" % [nm.water_queue.size(), dup_size[0]])
	)

	# ── t=19.4  the transfer timer delivered the unit to the consumer's scene ──
	tree.create_timer(19.4).timeout.connect(func() -> void:
		check.call("water arrival notified the consumer's scene",
			water_arrivals.size() >= 1, "arrivals=%d" % water_arrivals.size())
	)

	# ── t=19.8  consume it and report back ──
	tree.create_timer(19.8).timeout.connect(func() -> void:
		var consumed: Dictionary = nm.consume_water(true)
		print("  [client] consumed a unit: %s" % str(consumed.get("type", "<none>")))
	)

	# ── t=21.6  the producer's overflow reached this side ──
	# Eventual for the same reason as the arrival check above: sampled at a fixed instant
	# it reported "buffer_overflow never fired on the client" and the log then printed
	# "[client] buffer_overflow received" twice — once per unit the full buffer rejected.
	tree.create_timer(21.6).timeout.connect(func() -> void:
		await eventually.call("producer's buffer overflow notified the consumer",
			func() -> bool: return overflow_seen[0], 3.0,
			func() -> String: return "buffer_overflow fired=%s" % str(overflow_seen[0]))
	)

	# ══ t=24.5  FIX 7/8/9: the GameManager side of the wire ═════════════
	# Adopt NetworkManager's peer into GameManager's multiplayer state, setting the
	# same fields join_server() sets besides creating the peer. Deliberately left at
	# the DEFAULT quota and with _quota_from_host false, because that is the state a
	# client is in before the host's first broadcast — and pre-FIX-8 it stayed there.
	var gc_base := [0]
	var own_id := [0]
	tree.create_timer(24.5).timeout.connect(func() -> void:
		var gm := GameManager
		own_id[0] = multiplayer.get_unique_id()
		gm.is_host = false
		gm.is_multiplayer_connected = true
		gm.local_player_num = 2
		gm.current_game_mode = GameManager.GameMode.MULTIPLAYER_COOP
		gm._quota_from_host = false
		gm.current_minigame_quota = DEFAULT_QUOTA
		gm.g_counter.clear()
		gm.g_counter[own_id[0]] = 0
		gc_base[0] = GCounter.get_player_score(own_id[0]) if GCounter else 0
		print("  [client] adopted peer as GameManager client, quota=%d" % gm.current_minigame_quota)
	)

	# ── t=26.0  FIX 8: the host's first-round quota actually arrived ──
	# The host set it at t=25.0 with only its own id in g_counter. Eventual rather than
	# a sampled instant for the usual reason, and the failure mode it has to catch is
	# "the value never changes from DEFAULT_QUOTA" — pre-fix the client played the whole
	# first round against its own locally computed number while the host evaluated the
	# win condition against a different one.
	tree.create_timer(26.0).timeout.connect(func() -> void:
		await eventually.call("[FIX 8] the host's first-round quota reached the client",
			func() -> bool: return GameManager.current_minigame_quota == HOST_QUOTA, 4.0,
			func() -> String: return "quota=%d expected %d" % [GameManager.current_minigame_quota, HOST_QUOTA])
		check.call("[FIX 8] the client recorded the quota as host-owned",
			GameManager._quota_from_host,
			"_quota_from_host=%s" % str(GameManager._quota_from_host))
	)

	# ── t=27.5  FIX 9: a later local computation must not overwrite the host's value ──
	# Both peers run the same minigame script and each calls set_minigame_quota() with
	# its own adaptive settings (MiniGame_Rain.gd:389 and four siblings). Only the host
	# evaluates _check_win_condition(), so the host's number is the canonical one; a
	# client whose difficulty drifted used to clobber it locally and then disagree with
	# the host about whether the round had been won.
	tree.create_timer(27.5).timeout.connect(func() -> void:
		GameManager.set_minigame_quota(CLIENT_LOCAL_QUOTA)
		check.call("[FIX 9] a client's own quota did not overwrite the host's",
			GameManager.current_minigame_quota == HOST_QUOTA,
			"quota=%d expected %d after local set(%d)" % [GameManager.current_minigame_quota, HOST_QUOTA, CLIENT_LOCAL_QUOTA])
	)

	# ── t=28.0  FIX 7: a legitimate increment, sent over the wire ──
	tree.create_timer(28.0).timeout.connect(func() -> void:
		GameManager.rpc("submit_score", 5)
		print("  [client] submit_score(5)")
	)

	# ── t=29.0  FIX 7: the hostile increments ──
	# submit_score is @rpc("any_peer"), so either peer can call it with anything. -3
	# would have driven the sender's own slot down on BOTH replicas (call_local), and 0
	# is the boundary the guard is written as <= 0 to cover.
	tree.create_timer(29.0).timeout.connect(func() -> void:
		GameManager.rpc("submit_score", -3)
		GameManager.rpc("submit_score", 0)
		print("  [client] submit_score(-3) and submit_score(0)")
	)

	# ── t=30.5  the local (call_local) side rejected them too ──
	tree.create_timer(30.5).timeout.connect(func() -> void:
		var slot: int = GameManager.g_counter.get(own_id[0], 0)
		check.call("[FIX 7] the sender's own replica did not decrease either",
			slot == 5, "own slot=%d expected 5" % slot)
		var gc_now: int = GCounter.get_player_score(own_id[0]) if GCounter else -1
		# Both stores, not just the singleton: GCounter refuses negatives by itself, so
		# asserting only its delta would pass with the boundary guard deleted.
		check.call("[FIX 7] the sender's two G-Counter stores did not diverge",
			gc_now - gc_base[0] == 5 and gc_now - gc_base[0] == slot,
			"singleton delta=%d vs GameManager slot=%d (both must be 5)" % [gc_now - gc_base[0], slot])
	)

	# ── t=33.0  leave mid-round so the host has an open round to hold ──
	# quit() after finish() has already printed this side's tally at t=33.5 would be
	# too late, so the disconnect rides on its own timer just before it.
	tree.create_timer(33.0).timeout.connect(func() -> void:
		print("  [client] leaving mid-round")
		nm.disconnect_multiplayer()
	)

	tree.create_timer(33.5).timeout.connect(finish)


# ── Scene-side callbacks NetworkManager looks for ────────────────────
# Both of these are the real delivery target: NetworkManager reaches the game by
# calling methods on get_tree().current_scene, and for this harness that node is
# this script. Defining them here is what makes the relay observable end to end
# instead of quietly doing nothing on a scene that lacks the method.

func on_partner_event(event_type: String, data: Dictionary) -> void:
	partner_events.append({"type": event_type, "data": data})
	print("  [scene] on_partner_event(%s, %s)" % [event_type, str(data)])


func on_water_received(water_data: Dictionary) -> void:
	water_arrivals.append(water_data)
	print("  [scene] on_water_received(%s)" % str(water_data.get("type", "?")))


func _on_remote_pause() -> void:
	# What a real round uses to raise its pause overlay, so defining it here tests the
	# notification as well as the pause. The recorded value is the tree state AT the
	# notification: NetworkManager sets get_tree().paused = true immediately above this
	# call, so a false here would mean the pause was announced without being applied.
	pause_notices.append(get_tree().paused)
	print("  [scene] _on_remote_pause(tree.paused=%s)" % str(get_tree().paused))


func _on_remote_resume() -> void:
	resume_notices.append(get_tree().paused)
	print("  [scene] _on_remote_resume(tree.paused=%s)" % str(get_tree().paused))
