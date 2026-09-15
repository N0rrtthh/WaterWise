extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS ROUND-COMPLETION-ACROSS-REJOIN HARNESS
## ═══════════════════════════════════════════════════════════════════
## The phone-reported failure: "when the player disconnects the remaining player
## will be stuck when he finished the round — waiting for player; also
## reconnecting has stuck the other player on waiting for partner."
##
## A round completion is a reliable RPC (_sync_player_completion), and a reliable
## RPC aimed at a peer that is gone is LOST, not queued. On top of that, a
## rejoining ENet client arrives on a NEW peer id, so even a report that did
## arrive is keyed by an id nobody owns any more. Put together, three deadlocks:
##   1. the client finished, then dropped before the report landed → the host
##      that finishes next sits on "waiting for partner" forever;
##   2. the host finished while the client was away → the rejoined client never
##      learns the round is half-resolved → both sides wait forever;
##   3. the stale pre-drop entry plus the re-filed one read as "size 2" to a raw
##      count, resolving a round on DEFAULT (both-failed) data.
##
## What is under test is the repair:
##   PHASE 1  the host drops the client mid-round and finishes WHILE IT IS AWAY
##            (the report RPC has no peer to go to — a genuine loss). The client
##            rejoins and must be handed the host's completion through the
##            re-delivery push, then its own report must resolve the round on
##            BOTH sides with BOTH real payloads.
##   PHASE 2  round 2: the client finishes and "loses" its report (see the
##            injection note below), the host finishes alone and must NOT
##            resolve, and after a second drop+rejoin the client's RE-FILED
##            completion must resolve round 2 on the host — exactly once, with
##            the real payload.
##
## MEASUREMENT NOTES
##   - Resolution is counted from the both_players_completed SIGNAL, never
##     polled from state: the claim is "it fired once, with these payloads",
##     which only a connected counter can make.
##   - The host's phase-1 report is fired FROM THE HOLD-STARTED SIGNAL (deferred
##     one frame), not from the main timeline: a 0.1 s poll after the hold opens
##     is already enough time for a loopback re-dial to land, which would turn
##     the "lost report" into a delivered one and make the phase vacuous.
##   - The overlay/pause assertions are SAMPLED one frame after the hold-start
##     signal (after the round scene's own handler has run), not polled — on
##     loopback a hold can open and resolve inside one 0.1 s poll interval.
##   - ONE documented injection, phase 2, host side: after the client's round-2
##     report is received, the host ERASES that entry from its
##     round_completion_status. This stands in for "the packet never arrived",
##     which cannot be induced deterministically from GDScript — a drop racing
##     a reliable send is a coin flip. Everything else drives production APIs:
##     the erase removes state, it does not add any.
##   - Round 2's arrival is detected by SCENE REPLACEMENT, not by the round
##     baseline: nobody submits score in this harness, so both rounds share
##     baseline 0 and a baseline comparison could not tell them apart.
##   - The client resolves round 2 EARLY, as soon as the host's report reaches
##     it — that is correct (only the HOST lost the client's entry), and the
##     client-side checks are labelled accordingly.
##   - The host does not quit until the client reports done: quitting first
##     kills the connection under the client's still-running checks.
##
## Run (host first; it binds the port):
##   godot --headless --path . res://tools/VerifyCompletionRejoin.tscn -- host
##   godot --headless --path . res://tools/VerifyCompletionRejoin.tscn -- client
## ═══════════════════════════════════════════════════════════════════

const HOST_IP: String = "127.0.0.1"
## Not shared with any other harness: a lingering socket from an aborted run of one
## of them would make this bind fail for a reason that has nothing to do with the
## completion handshake.
const PORT: int = 7821
const LOBBY_PATH: String = "res://scenes/ui/MultiplayerLobby.tscn"
const CONNECT_TIMEOUT: float = 25.0

## Real payloads with distinct primes, so a default-primed resolution
## (score 0 / both-failed) can never masquerade as a real one.
const HOST_R1_SCORE: int = 41
const CLIENT_R1_SCORE: int = 43
const HOST_R2_SCORE: int = 47
const CLIENT_R2_SCORE: int = 53


func _ready() -> void:
	var role := _resolve_role()
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE COMPLETION-REJOIN VERIFICATION — role: %s" % role.to_upper())
	print("═══════════════════════════════════════════════════════════")
	await get_tree().process_frame
	if role != "host" and role != "client":
		push_error("[VCJ] unknown role '%s' — pass host or client after --" % role)
		get_tree().quit(1)
		return
	var subject := Subject.new()
	# The name is the RPC address; both processes mount the Subject at the same
	# /root path so the coordination RPCs below resolve on the far side. It lives
	# at /root so it survives the rounds' own change_scene calls.
	subject.name = "CompletionRejoinSubject"
	subject.role = role
	get_tree().root.add_child(subject)
	subject.run()


func _resolve_role() -> String:
	for arg in OS.get_cmdline_user_args():
		var a := arg.strip_edges().to_lower()
		if a == "host" or a == "client":
			return a
	return "host"


## ═══════════════════════════════════════════════════════════════════
## THE SUBJECT — lives at /root, so it survives the rounds' scene changes
## ═══════════════════════════════════════════════════════════════════
class Subject extends Node:

	var role: String = "host"
	var results: Array = []
	var game: Node = null

	## From the SIGNAL, not polled: "resolved once, with these payloads" is a
	## claim only a connected counter can make.
	var resolutions: int = 0
	var last_resolution: Array = []
	## From the reconnect-hold SIGNALS.
	var hold_starts: int = 0
	var hold_ends: Array = []            ## one bool per end: true = peer returned
	## Resolution state (signal counter + latch) at each hold's end — see
	## _on_hold_ended for why this cannot be sampled from the coroutines.
	var hold_end_snaps: Array = []
	var snap: Dictionary = {}
	## Sampled ONE FRAME AFTER the hold started, when the round scene's own
	## handler (connected after ours, so run after ours) has already put the
	## overlay up and paused the tree.
	var snap_view: Dictionary = {}
	## MultiplayerLobby scene roots under /root: every phase here must RECOVER,
	## so any appearance at all is a failure.
	var lobby_roots: Array = []
	## Set by the client's coordination RPCs; see their own doc comments.
	var _client_reported_r2: bool = false
	var _client_done: bool = false


	func _check(label: String, ok: bool, detail: String = "") -> void:
		results.append({"ok": ok, "label": label})
		var mark := "✓" if ok else "✗"
		if detail == "":
			print("  %s %s" % [mark, label])
		else:
			print("  %s %s  — %s" % [mark, label, detail])


	## Poll a condition the OTHER process has to make true; the two processes boot
	## their autoloads at their own pace, so fixed-instant assertions on
	## cross-process facts are a coin flip on skew.
	func _eventually(label: String, cond: Callable, timeout_s: float = 5.0,
			detail: Callable = Callable()) -> bool:
		var waited := 0.0
		while waited < timeout_s and not cond.call():
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		var ok: bool = cond.call()
		var text := ""
		if detail.is_valid():
			text = str(detail.call())
		if waited > 0.0:
			text = ("%s (after %.1fs)" % [text, waited]).strip_edges()
		_check(label, ok, text)
		return ok


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
		# Never leave the tree paused behind a finished run.
		get_tree().paused = false
		Engine.get_main_loop().quit(1 if failed > 0 else 0)


	func _state() -> String:
		return ("hold=%s in_progress=%s conn=%s paused=%s resolved=%d lobbies=%d live=%s"
			% [str(NetworkManager.is_reconnect_hold_active()),
				str(NetworkManager.game_in_progress), str(NetworkManager.connection_active),
				str(get_tree().paused), resolutions, lobby_roots.size(), str(_round_live())])


	func _on_any_node_added(n: Node) -> void:
		if n.scene_file_path == LOBBY_PATH and n.get_parent() == get_tree().root:
			lobby_roots.append(n.get_instance_id())
			print("  [%s] lobby root appeared (#%d) — %s"
				% [role, lobby_roots.size(), _state()])


	func _on_hold_started(_seconds: float) -> void:
		hold_starts += 1
		snap = {
			"hold": NetworkManager.is_reconnect_hold_active(),
			"in_progress": NetworkManager.game_in_progress,
			"round_alive": _round_live(),
			"lobbies": lobby_roots.size(),
		}
		print("  [%s] hold #%d started — %s" % [role, hold_starts, _state()])
		if role == "host" and hold_starts == 1:
			# The host finishes the round NOW, one frame into its own hold: the
			# client's peer is gone, so the report RPC has nowhere to go and is
			# genuinely lost — the exact loss the re-delivery push repairs. Fired
			# from the signal (deferred) rather than the main timeline so a fast
			# loopback re-dial cannot land first and deliver it after all.
			call_deferred("_host_finish_round1")
		_sample_hold_view()


	## The phase-1 completion report, filed while the partner is away.
	func _host_finish_round1() -> void:
		print("  [host] finishing round 1 while the partner is away — report is lost")
		NetworkManager.report_player_completion(true, HOST_R1_SCORE, 0.8, 9000)


	## One frame later, record what the hold actually looks like on screen. Not
	## polled: a loopback re-dial can resolve the whole hold inside one poll
	## interval.
	func _sample_hold_view() -> void:
		var index := hold_starts
		await get_tree().process_frame
		if index != hold_starts:
			return  # a newer hold superseded this one; its own sample wins
		snap_view = {"overlay": _overlay_up(), "paused": get_tree().paused}
		print("  [%s] hold #%d view — overlay=%s paused=%s"
			% [role, index, str(snap_view["overlay"]), str(snap_view["paused"])])


	func _on_hold_ended(rejoined: bool) -> void:
		hold_ends.append(rejoined)
		# Resolution state AT THE MOMENT the hold ended. Signal handlers run even
		# while the tree is paused, unlike the polling coroutines — this is the
		# only race-free place to observe "did the lost report resolve the round
		# while the partner was away".
		hold_end_snaps.append({
			"resolutions": resolutions,
			"latch": NetworkManager._round_resolution_emitted,
		})
		print("  [%s] hold #%d ended rejoined=%s — %s"
			% [role, hold_ends.size(), str(rejoined), _state()])


	func _on_both_completed(p1_success: bool, p2_success: bool,
			p1_score: int, p2_score: int) -> void:
		resolutions += 1
		last_resolution = [p1_success, p2_success, p1_score, p2_score]
		print("  [%s] round RESOLVED (#%d): P1 %s/%d P2 %s/%d"
			% [role, resolutions, str(p1_success), p1_score, str(p2_success), p2_score])


	## Client -> host: the client's round-2 completion report is on the wire.
	## Reliable RPCs on one channel are ordered, so when this arrives the report
	## RPC ahead of it has already been processed here — which is what makes the
	## "lost packet" erase below race-free.
	@rpc("any_peer", "reliable")
	func _client_reported_r2_rpc() -> void:
		_client_reported_r2 = true


	## Client -> host: the client's checks are complete; the host may quit now.
	@rpc("any_peer", "reliable")
	func _client_done_rpc() -> void:
		_client_done = true


	## Stop the round spawning things: an uncaught miss costs a shared life, and a
	## stream of misses could end the round before the phase's drop lands.
	func _quiet(g: Node) -> void:
		if g == null or not is_instance_valid(g):
			return
		if g.get("spawn_timer") != null:
			(g.spawn_timer as Timer).stop()
		for child in g.get_children():
			if child is Area2D and child.has_meta("type"):
				child.queue_free()


	func _round_live() -> bool:
		if game == null or not is_instance_valid(game):
			var cs := get_tree().current_scene
			if cs != null and cs != self and cs.has_method("start_game") \
					and cs.scene_file_path != LOBBY_PATH:
				game = cs
				_quiet(game)
		return game != null and is_instance_valid(game) and bool(game.get("game_active"))


	## Wait for a round scene to appear. old_id (default 0) waits for a REPLACEMENT
	## scene rather than any round scene.
	func _await_scene(old_id: int = 0, timeout_s: float = 15.0) -> bool:
		var waited := 0.0
		while waited < timeout_s:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
			var cs := get_tree().current_scene
			if cs != null and cs != self and cs.has_method("start_game") \
					and cs.scene_file_path != LOBBY_PATH \
					and cs.get_instance_id() != old_id:
				game = cs
				_quiet(game)
				return true
		return false


	## The rejoin outcome every phase shares: hold #hold_index (1-based) must end
	## as a REJOIN and nothing may have routed to the lobby. Awaited by hold
	## INDEX, not by a pre-drop snapshot: the hold pauses the tree, which freezes
	## the create_timer(0.1) sleeps this coroutine polls with, so a snapshot
	## taken "before" a hold can be read only after that hold has already opened
	## AND closed — the snapshot would then include the very end it is waiting
	## for and time out.
	func _await_rejoin(hold_index: int, who: String) -> void:
		await _eventually("%s: the hold ended with the peer back" % who,
			func() -> bool: return hold_ends.size() >= hold_index, 25.0,
			func() -> String: return "ends=%s %s" % [str(hold_ends), _state()])
		_check("%s: the hold resolved as a REJOIN, not an expiry" % who,
			hold_ends.size() >= hold_index and bool(hold_ends[hold_index - 1]),
			"ends=%s" % str(hold_ends))
		_check("%s: no lobby transition happened across the rejoin" % who,
			lobby_roots.is_empty(), "lobbies=%d" % lobby_roots.size())


	func run() -> void:
		get_tree().node_added.connect(_on_any_node_added)
		NetworkManager.reconnect_hold_started.connect(_on_hold_started)
		NetworkManager.reconnect_hold_ended.connect(_on_hold_ended)
		NetworkManager.both_players_completed.connect(_on_both_completed)
		match role:
			"host":
				await _run_host()
			_:
				await _run_client()


	## The reconnect overlay the round scene must show while its hold is open.
	func _overlay_up() -> bool:
		var cs := get_tree().current_scene
		if cs == null:
			return false
		var hud = cs.get("hud_layer")
		if hud == null:
			return false
		return hud.get_node_or_null("ReconnectOverlay") != null


	## The host's phase-1 completion, as seen from the client after the rejoin:
	## present under the host's peer id (1) and carrying the real round-1 score.
	## A method, not an inline lambda, because a one-line lambda body cannot
	## continue onto the next line in GDScript.
	func _host_r1_pushed() -> bool:
		if not NetworkManager.round_completion_status.has(1):
			return false
		return int(NetworkManager.round_completion_status[1].get("score", 0)) == HOST_R1_SCORE


## ── HOST: drops the partner twice; finishes once while it is away and once
##        after its report was "lost" ──

	func _run_host() -> void:
		_check("GameManager.host_game() bound port %d" % PORT, GameManager.host_game(PORT))
		var anchored := [false]
		get_tree().create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
			if not anchored[0]:
				_check("a client registered within %ds" % int(CONNECT_TIMEOUT), false, _state())
				_finish()
		)
		var registered: Array = await NetworkManager.player_connected
		anchored[0] = true
		var client_r1_id := int(registered[0])
		print("  [host] client %d registered" % client_r1_id)

		# ── the session bootstrap the lobby's start button sends ──
		await get_tree().create_timer(1.0).timeout
		GameManager.rpc("_begin_multiplayer_session_rpc")
		await get_tree().process_frame
		NetworkManager.set_ready(true)
		await _eventually("both players reported ready",
			func() -> bool: return NetworkManager.are_all_players_ready(), 8.0,
			func() -> String: return "players=%s" % str(NetworkManager.players))
		NetworkManager.set_mp_round_seconds(180.0)

		# ── round 1 through the shipped pair-start (records the resync ctx) ──
		var set1: Dictionary = LevelSets.get_random_level_set()
		NetworkManager.start_multiplayer_game_pair(
			set1["player1_game"], set1["player2_game"], set1)
		_check("round 1: the production round start reported a round in progress",
			NetworkManager.game_in_progress, _state())
		var ok1 := await _await_scene()
		_check("round 1: the host's round scene loaded", ok1, _state())
		await get_tree().create_timer(1.0).timeout
		game.start_game()
		await _eventually("round 1: the host's round went live",
			func() -> bool: return _round_live(), 8.0,
			func() -> String: return _state())
		_quiet(game)
		var round1_id := game.get_instance_id()

		# ── PHASE 1: drop the partner, then finish ALONE while it is away ──
		# force=false so ENet delivers the disconnect (force=true leaves a zombie
		# peer and the test passes without a reconnect).
		multiplayer.multiplayer_peer.disconnect_peer(client_r1_id, false)
		await _eventually("phase 1: the host opened a hold",
			func() -> bool: return hold_starts > 0, 15.0,
			func() -> String: return _state())
		_check("phase 1: the hold opened while the host's round was still live",
			bool(snap.get("round_alive", false)) and bool(snap.get("in_progress", false)),
			"snapshot=%s" % str(snap))
		_check("phase 1: the reconnect overlay was up during the hold",
			bool(snap_view.get("overlay", false)), "view=%s" % str(snap_view))
		# The report was filed from the hold-started signal, one frame in. With no
		# peer to carry it, the round must NOT resolve from it. Judged from the
		# hold-end SNAPSHOT, not from here: the rejoin that ends the hold is also
		# what unfreezes this coroutine, so "now" is already after the rejoin.
		await _eventually("phase 1: the hold ended",
			func() -> bool: return hold_end_snaps.size() >= 1, 25.0,
			func() -> String: return _state())
		_check("phase 1: finishing alone did NOT resolve the round (the report was lost)",
			int(hold_end_snaps[0]["resolutions"]) == 0
				and not bool(hold_end_snaps[0]["latch"]),
			"at hold end: %s" % str(hold_end_snaps[0]))

		# The client rejoins on its own retry timer, is handed the pushed
		# completion, and files its own — the resolution must land here.
		await _await_rejoin(1, "phase 1")
		await _eventually("phase 1: the round RESOLVED after the client came back and finished",
			func() -> bool: return resolutions >= 1, 15.0,
			func() -> String: return _state())
		_check("phase 1: the resolution carried BOTH real payloads, not defaults",
			resolutions >= 1 and last_resolution.size() == 4
				and bool(last_resolution[0]) and bool(last_resolution[1])
				and int(last_resolution[2]) == HOST_R1_SCORE
				and int(last_resolution[3]) == CLIENT_R1_SCORE,
			"last=%s (want P1 %d / P2 %d, both success)"
				% [str(last_resolution), HOST_R1_SCORE, CLIENT_R1_SCORE])

		# ── round 2: the host's post-resolution transition loads it (detected by
		# scene replacement — both rounds share baseline 0 here) ──
		var ok2 := await _await_scene(round1_id, 20.0)
		_check("round 2: the host advanced to the next round", ok2, _state())
		_check("round 2: the resolution fired exactly once (no double advance)",
			resolutions == 1, "resolutions=%d" % resolutions)

		# ── PHASE 2: the client's report is "lost", the host finishes alone ──
		await _eventually("phase 2: the client's round-2 report arrived",
			func() -> bool: return _client_reported_r2, 15.0,
			func() -> String: return _state())
		# THE ONE INJECTION (see the harness header): erasing the received entry
		# stands in for "the packet never arrived", which cannot be induced
		# deterministically from GDScript. Ordered after the client's cue RPC,
		# so the report it erases has provably already landed.
		var client_r2_id := NetworkManager.remote_player_id
		NetworkManager.round_completion_status.erase(client_r2_id)
		print("  [host] erased client %d's round-2 entry — the packet is now 'lost'"
			% client_r2_id)
		NetworkManager.report_player_completion(true, HOST_R2_SCORE, 0.7, 11000)
		await get_tree().create_timer(0.5).timeout
		_check("phase 2: the host finishing after the lost report did NOT resolve the round",
			resolutions == 1,
			"resolutions=%d table=%s" % [resolutions,
				str(NetworkManager.round_completion_status)])

		# Second drop, second rejoin — and this time the CLIENT's re-filed
		# completion is what has to resolve the round.
		multiplayer.multiplayer_peer.disconnect_peer(client_r2_id, false)
		await _eventually("phase 2: the host opened a second hold",
			func() -> bool: return hold_starts > 1, 15.0,
			func() -> String: return _state())
		await _await_rejoin(2, "phase 2")
		await _eventually("phase 2: the RE-FILED completion resolved round 2",
			func() -> bool: return resolutions >= 2, 15.0,
			func() -> String: return _state())
		_check("phase 2: the re-filed resolution carried the client's real payload",
			resolutions >= 2 and last_resolution.size() == 4
				and int(last_resolution[3]) == CLIENT_R2_SCORE
				and int(last_resolution[2]) == HOST_R2_SCORE,
			"last=%s (want P1 %d / P2 %d)"
				% [str(last_resolution), HOST_R2_SCORE, CLIENT_R2_SCORE])
		await get_tree().create_timer(1.0).timeout
		_check("the whole run recovered — zero lobby transitions",
			lobby_roots.is_empty(), "lobbies=%d" % lobby_roots.size())
		_check("the tree is not left paused", not get_tree().paused, _state())
		# Do NOT quit before the client is finished: this side quitting would kill
		# the connection under the client's still-running checks.
		await _eventually("the client finished its checks",
			func() -> bool: return _client_done, 60.0)
		await get_tree().create_timer(1.0).timeout
		_finish()


## ── CLIENT: gets dropped twice; must be handed the host's completion once and
##            re-file its own once ──

	func _run_client() -> void:
		_check("GameManager.join_game() started a client", GameManager.join_game(HOST_IP, PORT))
		var anchored := [false]
		get_tree().create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
			if not anchored[0]:
				_check("connected to the host within %ds" % int(CONNECT_TIMEOUT), false, _state())
				_finish()
		)
		await NetworkManager.connection_succeeded
		anchored[0] = true
		print("  [client] connected — uid=%d" % multiplayer.get_unique_id())

		NetworkManager.set_ready(true)
		await _eventually("the host started round 1 on this peer",
			func() -> bool: return NetworkManager.game_in_progress, 12.0,
			func() -> String: return _state())
		var ok1 := await _await_scene()
		_check("round 1: the client's round scene loaded", ok1, _state())
		await get_tree().create_timer(1.0).timeout
		game.start_game()
		await _eventually("round 1: the client's round went live",
			func() -> bool: return _round_live(), 8.0,
			func() -> String: return _state())
		_quiet(game)
		var round1_id := game.get_instance_id()

		# ── PHASE 1: the host drops this peer mid-round; nothing is called here ──
		await _eventually("phase 1: this peer opened a hold",
			func() -> bool: return hold_starts > 0, 25.0,
			func() -> String: return _state())
		_check("phase 1: the reconnect overlay was up during the hold",
			bool(snap_view.get("overlay", false)), "view=%s" % str(snap_view))
		_check("phase 1: the tree was paused for the hold",
			bool(snap_view.get("paused", false)), "view=%s" % str(snap_view))
		await _await_rejoin(1, "phase 1")

		# THE PUSH: the host finished while this peer was gone, so the report it
		# lost has to arrive through the re-delivery, or this side never learns
		# the round is half-resolved and both sides wait forever.
		await _eventually("phase 1: the host's lost completion was re-delivered after the rejoin",
			func() -> bool: return _host_r1_pushed(), 15.0,
			func() -> String: return "table=%s" % str(NetworkManager.round_completion_status))
		# Now this side finishes the round it resumed into.
		NetworkManager.report_player_completion(true, CLIENT_R1_SCORE, 0.9, 8000)
		await _eventually("phase 1: the round resolved on the client too",
			func() -> bool: return resolutions >= 1, 15.0,
			func() -> String: return _state())
		_check("phase 1: the client's resolution carried both real payloads",
			resolutions >= 1 and last_resolution.size() == 4
				and int(last_resolution[2]) == HOST_R1_SCORE
				and int(last_resolution[3]) == CLIENT_R1_SCORE,
			"last=%s" % str(last_resolution))

		# ── round 2: the host's transition loads it on this side too ──
		var ok2 := await _await_scene(round1_id, 20.0)
		_check("round 2: the client's round-2 scene loaded", ok2, _state())

		# ── PHASE 2: finish round 2, "lose" the report, drop, rejoin ──
		NetworkManager.report_player_completion(true, CLIENT_R2_SCORE, 0.75, 7000)
		# Ordered after the report on the same reliable channel: when the host
		# sees this cue, the report has already landed there.
		rpc_id(1, "_client_reported_r2_rpc")
		# The client still holds BOTH entries (it only lost nothing — the loss was
		# host-side), so the host's report completes the pair HERE as soon as it
		# arrives. That is the correct behaviour, not a defect.
		await _eventually("phase 2: round 2 resolved on the client when the host's report arrived",
			func() -> bool: return resolutions >= 2, 15.0,
			func() -> String: return _state())
		_check("phase 2: the client's resolution carried the real payloads",
			resolutions >= 2 and last_resolution.size() == 4
				and int(last_resolution[2]) == HOST_R2_SCORE
				and int(last_resolution[3]) == CLIENT_R2_SCORE,
			"last=%s" % str(last_resolution))

		await _eventually("phase 2: this peer opened a second hold",
			func() -> bool: return hold_starts > 1, 25.0,
			func() -> String: return _state())
		_check("phase 2: the reconnect overlay was up during the second hold",
			bool(snap_view.get("overlay", false)), "view=%s" % str(snap_view))
		await _await_rejoin(2, "phase 2")
		# THE RE-FILE: this peer finished BEFORE the drop, so nothing it can do
		# now produces a report — only the automatic re-file under the new peer
		# id can resolve the round on the host. Nothing in this harness calls
		# report_player_completion() after the drop; the entry under the CURRENT
		# peer id below can only exist because the re-file put it there.
		await _eventually("phase 2: the completion was re-filed under the new peer id",
			func() -> bool: return NetworkManager.round_completion_status.has(
				multiplayer.get_unique_id()), 15.0,
			func() -> String: return "uid=%d table=%s" % [multiplayer.get_unique_id(),
				str(NetworkManager.round_completion_status)])
		_check("the whole run recovered on the client — zero lobby transitions",
			lobby_roots.is_empty(), "lobbies=%d" % lobby_roots.size())
		rpc_id(1, "_client_done_rpc")
		await get_tree().create_timer(1.0).timeout
		_finish()
