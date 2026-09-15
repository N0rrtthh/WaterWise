extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS COUNTDOWN-PHASE DISCONNECT HARNESS
## ═══════════════════════════════════════════════════════════════════
## The phone-reported failure: "when i disconnect during a countdown scene it just
## freezes on the countdown and will not reconnect after that it will go to the
## lobby". Two defects stacked:
##
##   1. The round scene's reconnect-hold guard was `if not game_active: return`,
##      and the countdown phase is exactly where game_active is false while the
##      session's round is live — so the hold opened with no overlay, no pause and
##      no abandon button: a frozen countdown number for 30 s, then the lobby.
##   2. Even a peer that re-dialled in time could never get its GO: the 3-2-1 chain
##      is host-driven RPCs, one chain per round (the one-countdown latch), so a
##      client that missed the ticks had NOTHING that could ever start its game.
##      The harnesses never saw this because their _await_round() helpers call
##      start_game() directly — papering over the only path production has.
##
## What is under test is the countdown-phase recovery:
##   PHASE 1  the host's round is LIVE, the client is still PRE-START (it missed the
##            GO). The client drops abruptly (own peer closed — wifi-off shape, no
##            disconnect notification; the heartbeat is what detects it on the host),
##            re-dials, and must come back to a round that STARTS ITSELF on this
##            side: the rejoin kick, not a countdown that cannot re-fire.
##   PHASE 2  round 2, both peers PRE-START, the host fires the countdown chain and
##            the client drops MID-CHAIN. Whichever way the race resolves on the
##            host (chain frozen by the hold's pause and resumed, or chain finished
##            and the host live with the client kicked), both peers must end up in
##            a live round.
##
## The pre-start state is driven directly (`_awaiting_round_start = true`, the state
## a scene reaches when its player has dismissed the instructions and is waiting for
## the GO) because headless nobody dismisses anything, and a real dismissal would
## start the host's partner-ready fallback timers, which is a different test.
##
## MEASUREMENT NOTES
##   - The overlay/pause assertions are SAMPLED, not polled: on loopback a client's
##     whole hold can open and resolve inside one 0.1 s poll interval (re-dial to
##     127.0.0.1 is instant), so a poll provably missed windows the log lines prove
##     existed. The sample is taken one frame after the hold-start signal — after
##     the round scene's own handler (connected later, so run later) has put the
##     overlay up and paused the tree.
##   - Round 2 goes through start_multiplayer_game_pair() again, which checks
##     are_all_players_ready(). A rejoined peer registers under a NEW id with
##     ready=false (production handles this through the lobby's ready buttons), so
##     both sides re-ready before round 2 — the same consent the lobby requires.
##   - The host does not quit until the client reports done: quitting first kills
##     the connection under the client's still-running checks and manufactures a
##     third drop nobody asked for.
##
## Run (host first; it binds the port):
##   godot --headless --path . res://tools/VerifyCountdownReconnect.tscn -- host
##   godot --headless --path . res://tools/VerifyCountdownReconnect.tscn -- client
## ═══════════════════════════════════════════════════════════════════

const HOST_IP: String = "127.0.0.1"
## Not shared with any other harness: a lingering socket from an aborted run of
## one of them would make this bind fail for reasons unrelated to the countdown.
const PORT: int = 7817
const LOBBY_PATH: String = "res://scenes/ui/MultiplayerLobby.tscn"
const CONNECT_TIMEOUT: float = 25.0


func _ready() -> void:
	var role := _resolve_role()
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE COUNTDOWN-RECONNECT VERIFICATION — role: %s" % role.to_upper())
	print("═══════════════════════════════════════════════════════════")
	await get_tree().process_frame
	if role != "host" and role != "client":
		push_error("[VCR] unknown role '%s' — pass host or client after --" % role)
		get_tree().quit(1)
		return
	var subject := Subject.new()
	# The name is the RPC address; both processes mount the Subject at the same
	# /root path so the coordination RPCs below resolve on the far side. It lives at
	# /root so it survives the round's own change_scene_to_packed().
	subject.name = "CountdownReconnectSubject"
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
## THE SUBJECT — lives at /root, so it survives the round's scene changes
## ═══════════════════════════════════════════════════════════════════
class Subject extends Node:

	var role: String = "host"
	var results: Array = []
	var game: Node = null

	## From the SIGNALS, not polled: a poll cannot tell "the hold never opened"
	## from "it opened and closed between two samples".
	var hold_starts: int = 0
	var hold_ends: Array = []            ## one bool per end: true = peer returned
	## Sampled INSIDE the hold-started callback, before other listeners run.
	var snap: Dictionary = {}
	## Sampled ONE FRAME AFTER the hold started: by then the round scene's own
	## handler (connected after ours, so run after ours) has put the overlay up and
	## paused the tree. This is what the player actually sees during the hold —
	## the thing the frozen-countdown defect removed.
	var snap_view: Dictionary = {}
	## MultiplayerLobby scene roots that appeared under /root: any appearance at
	## all is a failure — every phase here must recover, not route out.
	var lobby_roots: Array = []
	## Set by the client's done RPC; the host waits on it before quitting.
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
		get_tree().paused = false
		Engine.get_main_loop().quit(1 if failed > 0 else 0)


	func _state() -> String:
		return ("hold=%s in_progress=%s host=%s conn=%s paused=%s lobbies=%d live=%s"
			% [str(NetworkManager.is_reconnect_hold_active()),
				str(NetworkManager.game_in_progress), str(NetworkManager.is_host),
				str(NetworkManager.connection_active), str(get_tree().paused),
				lobby_roots.size(), str(_round_live())])


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
		_sample_hold_view()


	## One frame later, record what the hold actually looks like on screen. Not
	## polled: a loopback re-dial can resolve the whole hold inside one poll
	## interval, and the frozen-countdown defect is precisely about what the player
	## SEES while the hold is open.
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
		print("  [%s] hold #%d ended rejoined=%s — %s"
			% [role, hold_ends.size(), str(rejoined), _state()])


	## Client -> host: the client's checks are complete; the host may quit now.
	@rpc("any_peer", "reliable")
	func _client_done_rpc() -> void:
		_client_done = true


	## Host -> client: the host's copy of the round is live; drop now. A real wifi
	## drop takes both endpoints out, but on loopback the host's ENet would sit on a
	## dead socket for its full peer timeout — the client kills its own peer on this
	## cue instead. The engine still fires server_disconnected on it, so the recovery
	## path driven is the production one; only the death itself is synthetic.
	@rpc("any_peer", "reliable")
	func _host_live_drop_now() -> void:
		print("  [%s] host's round is live — dropping now (missed-GO simulation)" % role)
		_schedule_own_close(0.2)


	## Host -> client: the countdown chain is on the wire; drop mid-chain.
	@rpc("any_peer", "reliable")
	func _countdown_running_drop_now() -> void:
		print("  [%s] countdown chain running — dropping mid-chain" % role)
		_schedule_own_close(0.2)


	func _schedule_own_close(delay_s: float) -> void:
		get_tree().create_timer(delay_s).timeout.connect(func() -> void:
			if NetworkManager.network == null:
				return
			if NetworkManager.is_reconnect_hold_active():
				return
			if NetworkManager.network.get_connection_status() \
					!= MultiplayerPeer.CONNECTION_CONNECTED:
				return
			print("  [%s] closing own peer — wifi is off" % role)
			NetworkManager.network.close())


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


	func _pre_start() -> bool:
		return (game != null and is_instance_valid(game)
			and not bool(game.get("game_active"))
			and not bool(game.get("is_waiting_for_partner"))
			and bool(game.get("_awaiting_round_start")))


	## Wait for a round scene to appear. old_id (default 0) waits for a REPLACEMENT
	## scene rather than any round scene: between the host firing the next round and
	## this side's deferred scene swap, current_scene is still the previous round's,
	## and a bare "has start_game" poll would latch the OLD scene as the new one.
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


	## The rejoin outcome every phase shares: the hold must end as a REJOIN, this
	## peer's round must be live afterwards, and nothing may have routed to the
	## lobby. `who` names the phase in the check labels.
	func _await_rejoin(before_ends: int, who: String) -> void:
		await _eventually("%s: the hold ended with the peer back" % who,
			func() -> bool: return hold_ends.size() > before_ends, 25.0,
			func() -> String: return "ends=%s %s" % [str(hold_ends), _state()])
		_check("%s: the hold resolved as a REJOIN, not an expiry" % who,
			hold_ends.size() > before_ends and bool(hold_ends[before_ends]),
			"ends=%s" % str(hold_ends))
		_check("%s: no lobby transition happened across the rejoin" % who,
			lobby_roots.is_empty(), "lobbies=%d" % lobby_roots.size())
		_check("%s: the tree is not left paused" % who, not get_tree().paused, _state())


	func run() -> void:
		get_tree().node_added.connect(_on_any_node_added)
		NetworkManager.reconnect_hold_started.connect(_on_hold_started)
		NetworkManager.reconnect_hold_ended.connect(_on_hold_ended)
		match role:
			"host":
				await _run_host()
			_:
				await _run_client()


## ── HOST: opens the session, goes live while the client is pre-start, then fires a
##        real countdown chain the client drops out of ──

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
		print("  [host] client %d registered" % int(registered[0]))

		# ── the session bootstrap the lobby's start button sends ──
		await get_tree().create_timer(1.0).timeout
		GameManager.rpc("_begin_multiplayer_session_rpc")
		await get_tree().process_frame
		NetworkManager.set_ready(true)
		await _eventually("both players reported ready",
			func() -> bool: return NetworkManager.are_all_players_ready(), 8.0,
			func() -> String: return "players=%s" % str(NetworkManager.players))
		NetworkManager.set_mp_round_seconds(180.0)

		# ── PHASE 1: round 1 through the shipped pair-start, host LIVE, client PRE-START ──
		var set1: Dictionary = LevelSets.get_random_level_set()
		NetworkManager.start_multiplayer_game_pair(
			set1["player1_game"], set1["player2_game"], set1)
		_check("phase 1: the production round start reported a round in progress",
			NetworkManager.game_in_progress, _state())
		var ok1 := await _await_scene()
		_check("phase 1: the host's round scene loaded", ok1, _state())
		await get_tree().create_timer(1.0).timeout
		# The host plays the round. start_game() is the production entry the GO uses,
		# and it is what arms NetworkManager's round-went-live flag for the resync.
		game.start_game()
		await _eventually("phase 1: the host's round went live",
			func() -> bool: return _round_live(), 8.0,
			func() -> String: return _state())
		_quiet(game)
		# Tell the client to drop NOW — it is pre-start and about to miss the GO
		# that already happened on this side.
		rpc_id(NetworkManager.remote_player_id, "_host_live_drop_now")

		var before1: int = hold_ends.size()
		await _eventually("phase 1: a hold opened on the host",
			func() -> bool: return hold_starts > 0, 15.0,
			func() -> String: return _state())
		_check("phase 1: the hold opened while the host's round was still live",
			bool(snap.get("round_alive", false)) and bool(snap.get("in_progress", false)),
			"snapshot=%s" % str(snap))
		_check("phase 1: the host showed the reconnect overlay during the hold",
			bool(snap_view.get("overlay", false)), "view=%s" % str(snap_view))
		await _await_rejoin(before1, "phase 1")
		_check("phase 1: the host's round is still live after the rejoin",
			_round_live() and NetworkManager.game_in_progress, _state())

		# ── PHASE 2: round 2, both PRE-START, real countdown chain, client drops mid-chain ──
		# The rejoined peer registered under a NEW id with ready=false; the lobby's
		# ready buttons are what re-consent a round in production, so both sides
		# re-ready here before the pair-start will accept a second round.
		NetworkManager.set_ready(true)
		await _eventually("both players re-readied for round 2",
			func() -> bool: return NetworkManager.are_all_players_ready(), 12.0,
			func() -> String: return "players=%s" % str(NetworkManager.players))
		var set2: Dictionary = LevelSets.get_random_level_set()
		NetworkManager.start_multiplayer_game_pair(
			set2["player1_game"], set2["player2_game"], set2)
		var round1_id := game.get_instance_id()
		var ok2 := await _await_scene(round1_id)
		_check("phase 2: the host's round-2 scene loaded", ok2, _state())
		await get_tree().create_timer(1.0).timeout
		# The countdown chain: the production start route. The client drops as the
		# first tick lands.
		NetworkManager.start_countdown()
		rpc_id(NetworkManager.remote_player_id, "_countdown_running_drop_now")

		var before2: int = hold_ends.size()
		await _eventually("phase 2: a hold opened on the host",
			func() -> bool: return hold_starts > 1, 15.0,
			func() -> String: return _state())
		await _await_rejoin(before2, "phase 2")
		# Whichever way the race resolved - chain frozen by the hold and resumed, or
		# chain finished and this side live with the client kicked - the host must
		# end the phase in a live round 2.
		await _eventually("phase 2: the host is live in round 2",
			func() -> bool: return _round_live(), 20.0,
			func() -> String: return _state())
		_check("phase 2: the host's round 2 is still running",
			NetworkManager.game_in_progress, _state())

		_check("two countdown-phase drops, two recoveries, zero lobby transitions",
			hold_ends.size() >= 2 and bool(hold_ends[0]) and bool(hold_ends[1])
				and lobby_roots.is_empty(),
			"ends=%s lobbies=%d" % [str(hold_ends), lobby_roots.size()])
		# Do NOT quit before the client is finished: this side quitting would kill
		# the connection under the client's still-running checks and manufacture a
		# third drop nobody asked for.
		await _eventually("the client finished its checks",
			func() -> bool: return _client_done, 60.0)
		await get_tree().create_timer(1.0).timeout
		_finish()


## ── CLIENT: pre-start while the host is live, drops, must be STARTED by the rejoin;
##            then drops mid-chain and must end up live again ──

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
		_check("phase 1: the client's round scene loaded", ok1, _state())
		# The pre-start state a player reaches by dismissing the instructions:
		# waiting for a GO. Driven directly (headless nobody dismisses anything,
		# and a real dismissal would start the host's fallback timers instead).
		game.set("_awaiting_round_start", true)
		_check("phase 1: the client sat in the pre-start wait",
			_pre_start() and not _round_live(), _state())

		# ── PHASE 1: the host's drop cue arrives when its round is live; from there
		# this side's own waits carry the flow — the drop, the hold, the re-dial. ──
		var before1: int = hold_ends.size()
		await _eventually("phase 1: this peer opened a hold",
			func() -> bool: return hold_starts > 0, 25.0,
			func() -> String: return _state())
		# THE OVERLAY FIX, asserted from the one-frame sample rather than a poll:
		# during the countdown phase the scene must show the hold — the frozen-
		# countdown defect was this overlay (and the pause beneath it) never appearing.
		_check("phase 1: the reconnect overlay was up during the hold",
			bool(snap_view.get("overlay", false)), "view=%s" % str(snap_view))
		_check("phase 1: the tree was paused for the hold",
			bool(snap_view.get("paused", false)), "view=%s" % str(snap_view))
		await _await_rejoin(before1, "phase 1")
		# THE KICK: no countdown chain can re-fire for this round (the host's latch
		# is spent and this peer never saw the GO), so the only way this side goes
		# live is the rejoin kick. Nothing in this harness calls start_game() on it.
		await _eventually("phase 1: the rejoined round STARTED ITSELF on the client",
			func() -> bool: return _round_live(), 15.0,
			func() -> String: return _state())
		_check("phase 1: the client is in the same round the host is playing",
			NetworkManager.game_in_progress and not NetworkManager.is_reconnect_hold_active(),
			_state())

		# ── PHASE 2: round 2, pre-start again, drop as the chain fires ──
		# Re-ready for the second pair-start: the rejoin registered this peer under
		# a new id, and start_multiplayer_game_pair() checks readiness — in
		# production the lobby's ready buttons are this consent.
		NetworkManager.set_ready(true)
		var round1_id := game.get_instance_id()
		var ok2 := await _await_scene(round1_id, 20.0)
		_check("phase 2: the client's round-2 scene loaded", ok2, _state())
		await get_tree().create_timer(1.0).timeout
		game.set("_awaiting_round_start", true)
		_check("phase 2: the client sat in the pre-start wait again",
			_pre_start() and not _round_live(), _state())

		var before2: int = hold_ends.size()
		await _eventually("phase 2: this peer opened a hold",
			func() -> bool: return hold_starts > 1, 25.0,
			func() -> String: return _state())
		_check("phase 2: the reconnect overlay was up during the hold",
			bool(snap_view.get("overlay", false)), "view=%s" % str(snap_view))
		await _await_rejoin(before2, "phase 2")
		await _eventually("phase 2: the client ended up in a live round 2",
			func() -> bool: return _round_live(), 20.0,
			func() -> String: return _state())
		_check("phase 2: the client's round 2 is running with the session",
			NetworkManager.game_in_progress, _state())

		_check("two countdown-phase drops, two live rounds on the client",
			hold_ends.size() >= 2 and bool(hold_ends[0]) and bool(hold_ends[1]),
			"ends=%s" % str(hold_ends))
		rpc_id(1, "_client_done_rpc")
		await get_tree().create_timer(1.0).timeout
		_finish()


	## The reconnect overlay the round scene must show while its hold is open.
	func _overlay_up() -> bool:
		var cs := get_tree().current_scene
		if cs == null:
			return false
		var hud = cs.get("hud_layer")
		if hud == null:
			return false
		return hud.get_node_or_null("ReconnectOverlay") != null
