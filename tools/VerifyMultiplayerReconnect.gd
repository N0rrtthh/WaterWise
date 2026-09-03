extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS RECONNECT / CRDT-DURABILITY HARNESS
## ═══════════════════════════════════════════════════════════════════
## VerifyMultiplayer.tscn covers a session that connects once and stays up. It
## deliberately never tears the link down mid-run, because a disconnect ends the
## session it is measuring. So nothing in this project had ever executed the
## thesis's Event 4 — "peer drops and rejoins, state is re-synchronised" — at
## runtime, and the code that runs on that path is where the G-Counter's
## monotonicity is actually at risk.
##
## This harness drives the REAL game path (GameManager.host_game / join_game,
## which adopt the peer into NetworkManager), scores on both peers through
## GameManager.rpc("submit_score", n) — the call the five MP minigames use — then
## has the host forcibly drop the client and the client rejoin.
##
## Run (host first; it binds the port):
##   godot --headless --path . res://tools/VerifyMultiplayerReconnect.tscn -- host
##   godot --headless --path . res://tools/VerifyMultiplayerReconnect.tscn -- client
##
## Verifies:
##   1. Both peers converge on the same total before the drop (7 + 5 = 12)
##   2. A partner leaving does NOT shrink the team total (grow-only)
##   3. A partner leaving does NOT remove its G-Counter slot
##   4. The GCounter singleton replica stays whole across the drop
##   5. The client's own replica survives the drop
##   6. A rejoining partner is given a slot
##   7. Host and client replicas CONVERGE after the rejoin
##   8. Neither replica's total ever decreases (monotonicity, both sides)
##   9. A CLIENT cannot end the round for the team (notify_game_end authority)
##  10. The host-side relay entry point is not honoured downward, while the
##      legitimate broadcast route still is (positive control)
##
## Checks 9 and 10 are regression tests for two authority defects in
## NetworkManager: notify_game_end wrote game_in_progress = false before any
## check on an any_peer handler, and _relay_game_event had no is_host guard.
##
## Checks 2, 3 and 7 are regression tests for a live defect:
## GameManager._on_peer_disconnected called g_counter.erase(peer_id), which is
## the one operation a grow-only counter may never perform.
## ═══════════════════════════════════════════════════════════════════

const HOST_IP: String = "127.0.0.1"
## Deliberately not 7777: VerifyMultiplayer uses that, and a lingering socket
## from an aborted run of it would make this harness's bind fail for a reason
## that has nothing to do with what it measures.
const HOST_PORT: int = 7778
const HOST_PEER_ID: int = 1

## Points each side contributes. Distinct primes so any total identifies exactly
## which contributions are present: 7 = host only, 5 = client only, 12 = both.
const HOST_POINTS: int = 7
const CLIENT_POINTS: int = 5

const CONNECT_TIMEOUT: float = 20.0

## Event types NetworkManager delivered into this scene via on_partner_event.
## Used by the client to tell the two downward routes apart: the legitimate
## broadcast (_receive_game_event) must land, the host-side relay entry point
## (_relay_game_event) must not.
var partner_events: Array[String] = []

## Filled on the host by the client's RPC report. -1 = never reported.
var reported_client_total: int = -1
var reported_client_slots: int = -1


func _ready() -> void:
	var role := "host"
	for arg in OS.get_cmdline_user_args():
		if arg == "client":
			role = "client"
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RECONNECT / CRDT DURABILITY HARNESS — role: %s" % role)
	print("═══════════════════════════════════════════════════════════")
	if role == "host":
		_run_host()
	else:
		_run_client()


# ── Shared helpers (same contracts as VerifyMultiplayer) ────────────

## Recorder over a captured Array so the tally outlives any scene change.
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


## Poll a condition a REMOTE process has to make true, rather than sampling one
## instant. The two processes anchor on their own connection events and boot 23
## autoloads at their own pace, so a fixed-instant assertion on a cross-process
## fact is a coin flip on skew — and the skew drifts in both directions between
## runs. See the same helper in VerifyMultiplayer.gd for the failure log that
## motivated it.
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


## Team total held by GameManager's replica — the one the host's win condition
## reads, and the one this harness is about.
func _gm_total() -> int:
	var total := 0
	for pid in GameManager.g_counter:
		total += int(GameManager.g_counter[pid])
	return total


## Team total held by the standalone GCounter singleton. Both GameManager and
## NetworkManager mirror into it, and it has no erase path at all, so it is the
## control: if it stays whole while GameManager's copy shrinks, the loss is
## GameManager's and not the network's.
func _singleton_total() -> int:
	var gc := get_node_or_null("/root/GCounter")
	if gc == null:
		return -1
	return int(gc.query())


## Client → host report of the client's own replica, so one log can state whether
## the two replicas converged. Both processes load this same scene, so the node
## path matches on both sides and the RPC resolves.
@rpc("any_peer", "reliable")
func _report_replica(total: int, slots: int) -> void:
	reported_client_total = total
	reported_client_slots = slots
	print("  [host] client reported replica total=%d slots=%d" % [total, slots])

## NetworkManager._receive_game_event dispatches into get_tree().current_scene,
## which for a --path-launched tool scene is THIS node. So the harness can observe
## exactly what a minigame would have been handed, with no instrumentation inside
## the autoload.
func on_partner_event(event_type: String, _data: Dictionary) -> void:
	partner_events.append(event_type)
	print("  [client] on_partner_event: %s" % event_type)

# ── HOST ────────────────────────────────────────────────────────────

func _run_host() -> void:
	var results: Array = []
	var check := _make_recorder(results)
	var eventually := _make_eventually(check)
	var finish := _make_finisher(results, "host")
	var tree := get_tree()

	# The real game path: MultiplayerLobby.gd:344 calls GameManager.host_game(),
	# which creates the ENet server and then adopts it into NetworkManager. Calling
	# NetworkManager.create_server() directly would skip GameManager's own
	# g_counter bookkeeping — which is precisely the code under test.
	check.call("GameManager.host_game() succeeded", GameManager.host_game(HOST_PORT))
	check.call("host is flagged as host", GameManager.is_host)

	var first_client := [0]
	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
		if not anchored[0]:
			check.call("client connected within %ds" % int(CONNECT_TIMEOUT), false)
			finish.call()
	)
	# Anchor on the engine signal rather than NetworkManager's registration
	# handshake: this harness is about GameManager's counter, and it must not fail
	# for a reason that belongs to a different subsystem.
	first_client[0] = await multiplayer.peer_connected
	anchored[0] = true
	print("  [host] client %d connected — starting timeline" % first_client[0])

	# ── t=1.0  both slots exist and start empty ──
	tree.create_timer(1.0).timeout.connect(func() -> void:
		check.call("host slot exists", GameManager.g_counter.has(HOST_PEER_ID))
		check.call("client slot created on connect",
			GameManager.g_counter.has(first_client[0]),
			"g_counter=%s" % str(GameManager.g_counter))
		check.call("both slots start at zero", _gm_total() == 0,
			"total=%d" % _gm_total())
	)

	# ── t=2.0  host scores through the same call the MP minigames use ──
	tree.create_timer(2.0).timeout.connect(func() -> void:
		GameManager.rpc("submit_score", HOST_POINTS)
		print("  [host] submitted %d" % HOST_POINTS)
	)

	# ── t=4.0  both contributions present on this replica (client sent 5 at 3.0) ──
	var want_total := HOST_POINTS + CLIENT_POINTS
	tree.create_timer(4.0).timeout.connect(func() -> void:
		await eventually.call("both contributions converged on the host before the drop",
			func() -> bool: return _gm_total() == want_total, 4.0,
			func() -> String: return "total=%d expected %d  %s" % [_gm_total(), want_total, str(GameManager.g_counter)])
	)

	# ── t=6.0  force the partner out, then measure what the drop cost ──
	# disconnect_peer() from the server is what the client sees as
	# server_disconnected — the same path a crashed or backgrounded phone takes,
	# and the one the thesis's Event 4 begins with.
	var before := [0, 0, 0]        # [gm_total, gm_slots, singleton_total]
	tree.create_timer(6.0).timeout.connect(func() -> void:
		before[0] = _gm_total()
		before[1] = GameManager.g_counter.size()
		before[2] = _singleton_total()
		print("  [host] pre-drop replica: total=%d slots=%d singleton=%d  %s"
			% [before[0], before[1], before[2], str(GameManager.g_counter)])
		# force = FALSE deliberately. With force = true ENet tears the socket down
		# without the disconnect handshake, so the SERVER never receives the event and
		# keeps a zombie peer: the first run of this harness produced "Invalid target
		# peer", "Max players reached, rejecting connection" and a second drop, none of
		# which a real disconnect causes. A graceful disconnect is also the honest model
		# of what the thesis Event 4 describes — the peer goes away and both sides are
		# told, which is what a backgrounded Android app or a closed lobby actually does.
		GameManager.peer.disconnect_peer(first_client[0], false)
		print("  [host] force-dropped peer %d" % first_client[0])
	)

	# ── t=7.4  the monotonicity assertions ──
	# A G-Counter is grow-only: the total is a join over a lattice, so it may never
	# decrease and a slot may never be withdrawn. The host is also the only peer
	# that evaluates _check_win_condition(), so a shrink here silently rolls back
	# the team's quota progress by exactly the departed player's contribution.
	tree.create_timer(7.4).timeout.connect(func() -> void:
		check.call("partner leaving did not shrink the team G-Counter total",
			_gm_total() >= before[0],
			"total %d → %d  %s" % [before[0], _gm_total(), str(GameManager.g_counter)])
		check.call("partner leaving did not withdraw its G-Counter slot",
			GameManager.g_counter.has(first_client[0]),
			"slots %d → %d" % [before[1], GameManager.g_counter.size()])
		check.call("the GCounter singleton replica kept the full total",
			_singleton_total() >= before[2],
			"singleton %d → %d" % [before[2], _singleton_total()])
	)

	# ── t=11.0  the rejoin landed (client rejoins at its t=10.0) ──
	tree.create_timer(11.0).timeout.connect(func() -> void:
		await eventually.call("rejoining partner was given a G-Counter slot",
			_has_third_slot.bind(first_client[0]), 8.0,
			func() -> String: return "g_counter=%s" % str(GameManager.g_counter))
	)

	# ── t=12.0  probe two authority boundaries on the rejoined link ──
	# The relay probe needs a positive control beside it, or "the client ignored it"
	# is indistinguishable from "the link was dead": _receive_game_event is the
	# legitimate downward route and must arrive, _relay_game_event is the host-side
	# entry point a client uses to reach the host and must NOT be honoured downward.
	tree.create_timer(12.0).timeout.connect(func() -> void:
		NetworkManager.game_in_progress = true
		var peers := multiplayer.get_peers()
		if peers.is_empty():
			check.call("a peer was connected to probe the authority boundaries", false)
			return
		var target: int = peers[0]
		NetworkManager.rpc_id(target, "_receive_game_event", "LEGIT_PROBE", {})
		NetworkManager.rpc_id(target, "_relay_game_event", "RELAY_PROBE", {})
		print("  [host] sent LEGIT_PROBE and RELAY_PROBE to peer %d" % target)
	)

	# ── t=15.0  a client CANNOT end the game for the team ──
	# Deliberately a fixed instant, not eventually(): this asserts a NEGATIVE, and
	# polling for "still true" would pass the moment it is sampled regardless of
	# whether the message ever landed. The client fires at its t=13.0, so 2 s of
	# localhost reliable-RPC slack sits in front of this read.
	tree.create_timer(15.0).timeout.connect(func() -> void:
		check.call("a client CANNOT end the game for the team",
			NetworkManager.game_in_progress,
			"game_in_progress=%s" % str(NetworkManager.game_in_progress))
	)

	# ── t=18.0  did the two replicas converge? (client reports at its t=19.0) ──
	tree.create_timer(18.0).timeout.connect(func() -> void:
		await eventually.call("client reported its replica",
			func() -> bool: return reported_client_total >= 0, 6.0,
			func() -> String: return "total=%d" % reported_client_total)
		check.call("host and client replicas converged after the rejoin",
			_gm_total() == reported_client_total,
			"host=%d client=%d  host_state=%s"
				% [_gm_total(), reported_client_total, str(GameManager.g_counter)])
		check.call("the converged total still contains both contributions",
			_gm_total() >= want_total,
			"total=%d expected >= %d" % [_gm_total(), want_total])
	)

	# 26 s, not 20: the convergence block at t=18 polls for up to 6 s, and a finisher
	# that fires mid-poll would quit the process while the assertion it is tallying
	# is still outstanding — reporting a pass count that omits it.
	tree.create_timer(26.0).timeout.connect(finish)


# ── CLIENT ──────────────────────────────────────────────────────────

func _run_client() -> void:
	var results: Array = []
	var check := _make_recorder(results)
	var eventually := _make_eventually(check)
	var finish := _make_finisher(results, "client")
	var tree := get_tree()

	check.call("GameManager.join_game() succeeded",
		GameManager.join_game(HOST_IP, HOST_PORT))

	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
		if not anchored[0]:
			check.call("connected to host within %ds" % int(CONNECT_TIMEOUT), false)
			finish.call()
	)
	await multiplayer.connected_to_server
	anchored[0] = true
	var first_id := multiplayer.get_unique_id()
	print("  [client] connected as peer %d — starting timeline" % first_id)

	# ── t=1.0 ──
	tree.create_timer(1.0).timeout.connect(func() -> void:
		check.call("client's own slot was created on connect",
			GameManager.g_counter.has(first_id),
			"g_counter=%s" % str(GameManager.g_counter))
	)

	# ── t=3.0  client scores ──
	tree.create_timer(3.0).timeout.connect(func() -> void:
		GameManager.rpc("submit_score", CLIENT_POINTS)
		print("  [client] submitted %d" % CLIENT_POINTS)
	)

	# ── t=4.5  submit_score is call_local + any_peer, so both replicas see both ──
	var want_total := HOST_POINTS + CLIENT_POINTS
	tree.create_timer(4.5).timeout.connect(func() -> void:
		await eventually.call("both contributions converged on the client",
			func() -> bool: return _gm_total() == want_total, 4.0,
			func() -> String: return "total=%d expected %d  %s" % [_gm_total(), want_total, str(GameManager.g_counter)])
	)

	# ── t=7.4  the host dropped us at its t=6.0 ──
	tree.create_timer(7.4).timeout.connect(func() -> void:
		await eventually.call("client observed the server dropping it",
			func() -> bool: return not GameManager.is_multiplayer_connected, 4.0,
			func() -> String: return "is_multiplayer_connected=%s" % str(GameManager.is_multiplayer_connected))
		check.call("client's own replica survived the drop intact",
			_gm_total() >= want_total,
			"total=%d expected >= %d  %s" % [_gm_total(), want_total,
				str(GameManager.g_counter)])
	)

	# ── t=10.0  rejoin — thesis Event 4 ──
	tree.create_timer(10.0).timeout.connect(func() -> void:
		print("  [client] rejoining…")
		var ok: bool = GameManager.join_game(HOST_IP, HOST_PORT)
		check.call("rejoin call accepted", ok)
		await eventually.call("client reconnected to the host",
			func() -> bool: return GameManager.is_multiplayer_connected, 8.0,
			func() -> String: return "peer=%d" % multiplayer.get_unique_id())
	)

	# ── t=13.0  try to end the round for the whole team from a client ──
	# notify_game_end is @rpc("any_peer") and used to write game_in_progress = false
	# on its first line, before any check. This is the attack it allowed, sent through
	# the real network so the guard is exercised where it lives, not called locally.
	tree.create_timer(13.0).timeout.connect(func() -> void:
		if not GameManager.is_multiplayer_connected:
			check.call("client was connected to probe notify_game_end", false)
			return
		NetworkManager.rpc_id(HOST_PEER_ID, "notify_game_end", {"success": true})
		print("  [client] sent notify_game_end to the host")
	)

	# ── t=16.0  the host's two probes: one must land, one must not ──
	# Fixed instant, not eventually(): the relay half is a NEGATIVE assertion, and
	# polling "still absent" would pass on the first sample whether or not the
	# message was ever sent. LEGIT_PROBE is the positive control that makes the
	# absence of RELAY_PROBE mean something — without it, "nothing arrived" would
	# also be the reading for a dead link.
	tree.create_timer(16.0).timeout.connect(func() -> void:
		check.call("the legitimate broadcast route still reaches the client",
			"LEGIT_PROBE" in partner_events,
			"events=%s" % str(partner_events))
		check.call("the host CANNOT push an event through the host-side relay",
			not ("RELAY_PROBE" in partner_events),
			"events=%s" % str(partner_events))
	)

	# ── t=19.0  report this replica to the host so one log holds both ──
	tree.create_timer(19.0).timeout.connect(func() -> void:
		var total := _gm_total()
		check.call("client's replica is monotone across the rejoin",
			total >= want_total,
			"total=%d expected >= %d  %s" % [total, want_total,
				str(GameManager.g_counter)])
		if GameManager.is_multiplayer_connected:
			rpc_id(HOST_PEER_ID, "_report_replica", total,
				GameManager.g_counter.size())
			print("  [client] reported total=%d slots=%d"
				% [total, GameManager.g_counter.size()])
		else:
			check.call("client was still connected to report its replica", false)
	)

	tree.create_timer(21.0).timeout.connect(finish)


## True once GameManager holds a slot that is neither the host's nor the peer id
## the partner used before it was dropped — i.e. the rejoin was registered.
## A named method rather than a multi-line lambda argument: an inline lambda body
## ends at the newline, so the multi-line version parsed as an unterminated call.
func _has_third_slot(old_client_id: int) -> bool:
	for pid in GameManager.g_counter:
		if pid != HOST_PEER_ID and pid != old_client_id:
			return true
	return false
