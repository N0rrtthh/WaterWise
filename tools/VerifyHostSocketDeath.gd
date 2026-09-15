extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS HOST-SOCKET-DEATH HARNESS
## ═══════════════════════════════════════════════════════════════════
## The real-phone failure this exists for (session_2026-09-14T01-49-22.json):
## a session's FIRST drop recovered, the second never did. The log showed why —
## Godot's SceneMultiplayer emits server_disconnected on ANY peer whose status
## drops from CONNECTED to DISCONNECTED, and ON THE HOST that transition is its
## own ENet server dying (wifi lost on the host phone). NetworkManager treated
## that signal as client-only and ran the CLIENT exit path on the host:
##   175.72s  ⚠️ Server disconnected!                    ← logged ON THE HOST
##   205.68s  Reconnect hold ended (expired)
##            Host disconnected during game, returning to lobby...   ← on the HOST
## The host tore its own server down, so the returning partner's re-dial had
## nothing to rejoin: "it is just successful one time then nothing".
##
## What is under test is the host's self-heal: on its own socket death the host
## must HOLD the round (as host, not client) and REBIND the port so the partner's
## retry dial can land, and this must work more than once per session.
##
## Three drops in one session, all through the production round flow:
##   PHASE 1  the host's socket dies mid-round (host closes its own ENet peer —
##            exactly what the engine's error path does on a lost interface).
##            The partner simulates the same shared-link death by closing its own
##            peer shortly after. Both must hold, the client must re-dial, the
##            host's re-listened server must accept it, and the SAME round resumes.
##   PHASE 2  the host drops the client (graceful disconnect_peer) — the second
##            drop of the session. Must recover the same way.
##   PHASE 3  the host's socket dies AGAIN — the third drop, and the second
##            host-side one. "One time then nothing" is the bug; twice must work.
##
## The round starts through start_multiplayer_game_pair(), the lobby's shipped
## path, so _current_round_ctx is populated the production way — the ctx-resync
## branch of _end_reconnect_hold() is exercised here for the first time
## (tools/VerifyInRoundReconnect.tscn starts rounds manually, so its ctx is empty
## and its rejoins always fall to the "both peers already in the round" branch).
##
## Run (host first; it binds the port):
##   godot --headless --path . res://tools/VerifyHostSocketDeath.tscn -- host
##   godot --headless --path . res://tools/VerifyHostSocketDeath.tscn -- client
## ═══════════════════════════════════════════════════════════════════

const HOST_IP: String = "127.0.0.1"
## Not shared with any other harness: a lingering socket from an aborted run of
## one of them would make this bind fail for a reason that has nothing to do
## with the host's self-heal.
const PORT: int = 7813
const LOBBY_PATH: String = "res://scenes/ui/MultiplayerLobby.tscn"
const CONNECT_TIMEOUT: float = 25.0

## Distinct primes, so any total names exactly which contributions are present:
## 7 = host only, 5 = client only, 12 = both.
const HOST_POINTS: int = 7
const CLIENT_POINTS: int = 5

## Non-default round state the host owns, so the client's post-rejoin values can
## only match by having been re-synchronised.
const ROUND_LIVES: int = 2
const ROUND_DIFF: float = 1.35

## Wrong-on-purpose values the CLIENT writes into its own copies between drops.
## Without them "lives match after the rejoin" would pass on a client that was
## simply never touched, since the defaults already agree.
const POISON_LIVES: int = 99
const POISON_DIFF: float = 9.0


func _ready() -> void:
	var role := _resolve_role()
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE HOST-SOCKET-DEATH VERIFICATION — role: %s" % role.to_upper())
	print("═══════════════════════════════════════════════════════════")
	await get_tree().process_frame
	if role != "host" and role != "client":
		push_error("[VHSD] unknown role '%s' — pass host or client after --" % role)
		get_tree().quit(1)
		return
	var subject := Subject.new()
	# The name is the RPC address. Both processes load this same scene and mount
	# the Subject at the same /root path, so the RPCs below resolve on the far
	# side — and it survives the round's own change_scene_to_packed().
	subject.name = "HostSocketDeathSubject"
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

	## Recorded from the SIGNALS, not polled: a poll cannot tell "the hold never
	## opened" from "it opened and closed between two samples".
	var hold_starts: int = 0
	var hold_ends: Array = []            ## one bool per end: true = peer returned
	## State sampled INSIDE the reconnect_hold_started callback, before any other
	## listener on that signal has run — the only honest moment to claim "the
	## round was held rather than ended".
	var snap: Dictionary = {}
	## MultiplayerLobby scene roots that appeared under /root, counted from
	## node_added rather than polled: "not even one" is the claim being made —
	## the old code routed the HOST to the lobby on its own socket death.
	var lobby_roots: Array = []
	## Filled on the host by the client's RPC reports. -1 = never reported.
	var reported_total: int = -1
	var reported_lives: int = -1
	var reported_diff: float = -1.0


	func _check(label: String, ok: bool, detail: String = "") -> void:
		results.append({"ok": ok, "label": label})
		var mark := "✓" if ok else "✗"
		if detail == "":
			print("  %s %s" % [mark, label])
		else:
			print("  %s %s  — %s" % [mark, label, detail])


	## Poll a condition the OTHER process has to make true. The two processes
	## boot their autoloads at their own pace, so a fixed-instant assertion on a
	## cross-process fact is a coin flip on skew.
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
		# Never leave the tree paused behind a finished run: the hold pauses it,
		# and a process that quits while paused can strand the other side.
		get_tree().paused = false
		Engine.get_main_loop().quit(1 if failed > 0 else 0)


	func _state() -> String:
		return ("hold=%s in_progress=%s host=%s conn=%s paused=%s lobbies=%d"
			% [str(NetworkManager.is_reconnect_hold_active()),
				str(NetworkManager.game_in_progress), str(NetworkManager.is_host),
				str(NetworkManager.connection_active), str(get_tree().paused),
				lobby_roots.size()])


	func _gm_total() -> int:
		var total := 0
		for pid in GameManager.g_counter:
			total += int(GameManager.g_counter[pid])
		return total


	func _on_any_node_added(n: Node) -> void:
		if n.scene_file_path == LOBBY_PATH and n.get_parent() == get_tree().root:
			lobby_roots.append(n.get_instance_id())
			print("  [%s] lobby root appeared (#%d) — %s"
				% [role, lobby_roots.size(), _state()])


	func _on_hold_started(_seconds: float) -> void:
		hold_starts += 1
		# Only the FIRST hold of each phase is snapshotted: snap is read by the
		# phase that is about to assert on it, before the next phase begins.
		snap = {
			"hold": NetworkManager.is_reconnect_hold_active(),
			"in_progress": NetworkManager.game_in_progress,
			"host": NetworkManager.is_host,
			"round_alive": _round_live(),
			"lobbies": lobby_roots.size(),
		}
		print("  [%s] hold #%d started — %s" % [role, hold_starts, _state()])


	func _on_hold_ended(rejoined: bool) -> void:
		hold_ends.append(rejoined)
		print("  [%s] hold #%d ended rejoined=%s — %s"
			% [role, hold_ends.size(), str(rejoined), _state()])


	## Client -> host, so one log can state whether the two replicas agree after
	## each rejoin.
	@rpc("any_peer", "reliable")
	func _report_replica(total: int, lives: int, diff: float) -> void:
		reported_total = total
		reported_lives = lives
		reported_diff = diff
		print("  [host] client reported total=%d lives=%d diff=%.2f" % [total, lives, diff])


	## Host -> client, ahead of a host-side socket death. A real wifi drop takes
	## BOTH endpoints out (the phones share the link), but on loopback the
	## client's ENet would otherwise sit on a dead socket for its full peer
	## timeout. The client kills its own peer on this schedule instead — the
	## engine still fires server_disconnected on it, so the recovery path driven
	## is the production one; only the death itself is synthetic.
	@rpc("any_peer", "reliable")
	func _prepare_socket_death(delay_s: float) -> void:
		print("  [%s] socket death scheduled in %.1fs (shared-link simulation)"
			% [role, delay_s])
		# Snapshot of the hold count AT SCHEDULE TIME: the host's close() flushes
		# a disconnect notification, so this peer may detect the drop and finish
		# its recovery BEFORE the timer below fires. Any hold opened since the
		# schedule was made means the drop already reached us — closing then
		# would kill the REJOINED peer, a second drop nobody asked for.
		var holds_at_schedule := hold_starts
		get_tree().create_timer(delay_s).timeout.connect(func() -> void:
			if NetworkManager.network == null:
				return
			if hold_starts > holds_at_schedule:
				print("  [%s] drop already detected — skipping scheduled close" % role)
				return
			if NetworkManager.is_reconnect_hold_active():
				return
			if NetworkManager.network.get_connection_status() \
					!= MultiplayerPeer.CONNECTION_CONNECTED:
				return
			print("  [%s] closing own peer — shared link is gone" % role)
			NetworkManager.network.close())


	## Stop the round spawning things: an uncaught drop costs a shared life, and
	# a stream of misses could end the round before the drop under test happens.
	func _quiet(g: Node) -> void:
		if g == null or not is_instance_valid(g):
			return
		if g.get("spawn_timer") != null:
			(g.spawn_timer as Timer).stop()
		for child in g.get_children():
			if child is Area2D and child.has_meta("type"):
				child.queue_free()


	func _round_live() -> bool:
		# Self-healing latch: if the round scene was replaced under us (a round
		# transition we did not ask for), re-find it rather than report a dead
		# reference forever.
		if game == null or not is_instance_valid(game):
			var cs := get_tree().current_scene
			if cs != null and cs != self and cs.has_method("start_game") \
					and cs.scene_file_path != LOBBY_PATH:
				game = cs
				_quiet(game)
		return game != null and is_instance_valid(game) and bool(game.get("game_active"))


	func _resynced() -> bool:
		return (GameManager.team_lives == ROUND_LIVES
			and abs(GameManager.difficulty_multiplier - ROUND_DIFF) < 0.001)


	func _poison_state() -> String:
		return "lives=%d diff=%.2f" % [GameManager.team_lives, GameManager.difficulty_multiplier]


	## A hold that opened AND ended between two 0.1 s samples still counts
	## through hold_starts, so the "a drop happened" poll checks both counters.
	func _hold_since(before_starts: int, before_ends: int) -> bool:
		return hold_starts > before_starts or hold_ends.size() > before_ends


	func run() -> void:
		get_tree().node_added.connect(_on_any_node_added)
		NetworkManager.reconnect_hold_started.connect(_on_hold_started)
		NetworkManager.reconnect_hold_ended.connect(_on_hold_ended)
		match role:
			"host":
				await _run_host()
			_:
				await _run_client()


	## Wait until the round's own scene change has landed and the round is live,
	## then quiet it. Both start paths load the round through
	## _load_game_scene()'s change_scene_to_packed(), which frees the tool scene
	## this Subject was launched from — expected, and why the Subject lives at
	## /root (see tools/VerifyInRoundReconnect.gd for the same arrangement).
	## start_game() is NOT called here: the production pair-start path already
	## starts the round when it loads the scene ("Multiplayer game starting"),
	## and starting it a second time would restart its countdown. game_active
	## only flips once that countdown runs out, so it is POLLED — a fixed wait
	## raced it and latched a round that was still counting down.
	func _await_round(timeout_s: float = 15.0) -> bool:
		var waited := 0.0
		while waited < timeout_s:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
			var cs := get_tree().current_scene
			if cs != null and cs != self and cs.has_method("start_game") \
					and cs.scene_file_path != LOBBY_PATH:
				game = cs
				break
		if game == null:
			return false
		# The shipped round start does not press READY for you: headless, with
		# nobody at either keyboard, the scene sits on its waiting-for-start
		# overlay until the partner-ready fallback force-starts it (and longer
		# still when the first-play instruction beat is showing). tools/
		# VerifyInRoundReconnect.gd starts its rounds the same way. start_game()
		# refuses a second entry, so this cannot double-start a round that the
		# production flow already began.
		await get_tree().create_timer(1.0).timeout
		if not bool(game.get("game_active")):
			game.start_game()
		var live := false
		waited = 0.0
		while waited < 12.0:
			if _round_live():
				live = true
				break
			await get_tree().create_timer(0.2).timeout
			waited += 0.2
		_quiet(game)
		return live


## ── HOST: opens the session, kills its own socket twice, drops the partner once ──

	func _run_host() -> void:
		_check("GameManager.host_game() bound port %d" % PORT, GameManager.host_game(PORT))
		var anchored := [false]
		get_tree().create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
			if not anchored[0]:
				_check("a client registered within %ds" % int(CONNECT_TIMEOUT), false, _state())
				_finish()
		)
		# player_connected carries (peer_id, player_num), so awaiting it yields
		# an ARRAY, not the id.
		var registered: Array = await NetworkManager.player_connected
		anchored[0] = true
		print("  [host] client %d registered" % int(registered[0]))

		# ── the session bootstrap the lobby's start button sends ──
		await get_tree().create_timer(1.0).timeout
		GameManager.rpc("_begin_multiplayer_session_rpc")
		await get_tree().process_frame
		_check("the co-op session is open on the host", GameManager.session_active, _state())

		# ── the PRODUCTION round start the lobby ships, so the round ctx exists ──
		NetworkManager.set_ready(true)
		await _eventually("both players reported ready",
			func() -> bool: return NetworkManager.are_all_players_ready(), 8.0,
			func() -> String: return "players=%s" % str(NetworkManager.players))
		# A shipped round runs 30 s; the three drops plus their holds need more
		# runway than that, or the round ends on the clock mid-phase and the
		# assertions start measuring a round that already completed. This is the
		# multiplayer page's own round-timer control, at its 180 s ceiling.
		NetworkManager.set_mp_round_seconds(180.0)
		var level_set: Dictionary = LevelSets.get_random_level_set()
		NetworkManager.start_multiplayer_game_pair(
			level_set["player1_game"], level_set["player2_game"], level_set)
		_check("the production round start reported a round in progress",
			NetworkManager.game_in_progress, _state())
		_check("the round ctx was recorded for the rejoin resync",
			not NetworkManager._current_round_ctx.is_empty(),
			"ctx=%s" % str(NetworkManager._current_round_ctx))
		var round_ok := await _await_round()
		_check("the host's round went live through the shipped scene load",
			round_ok, _state())

		# Round state the client cannot guess, so its post-rejoin copy proves a
		# re-sync. Written AFTER the round is live: start_multiplayer_game_pair()
		# resets team lives for the fresh session and would overwrite sentinels.
		GameManager.team_lives = ROUND_LIVES
		GameManager.difficulty_multiplier = ROUND_DIFF

		# ── score through the production RPC, so both replicas hold two slots ──
		await get_tree().create_timer(1.0).timeout
		GameManager.rpc("submit_score", HOST_POINTS)
		await _eventually("both contributions converged before the first drop",
			func() -> bool: return _gm_total() >= HOST_POINTS + CLIENT_POINTS, 8.0,
			func() -> String: return "total=%d %s" % [_gm_total(), str(GameManager.g_counter)])

		# ── PHASE 1: this host's own server socket dies mid-round ──
		await _host_socket_death_phase(1)
		await _replica_report_check(1)

		# ── PHASE 2: the host drops the CLIENT — second drop of the session ──
		var before_ends: int = hold_ends.size()
		var cid := NetworkManager.remote_player_id
		# force=false, so ENet actually delivers the disconnect (a force=true
		# zombie peer makes a reconnect test pass without a reconnect).
		multiplayer.multiplayer_peer.disconnect_peer(cid, false)
		print("  [host] phase 2: dropped client peer %d" % cid)
		await _await_rejoin(before_ends, 2)
		await _replica_report_check(2)

		# ── PHASE 3: the host's socket dies AGAIN — third drop, second self-heal ──
		await _host_socket_death_phase(3)
		await _replica_report_check(3)

		_check("three drops, three recoveries, zero lobby transitions",
			hold_ends.size() >= 3 and bool(hold_ends[0]) and bool(hold_ends[1])
				and bool(hold_ends[2]) and lobby_roots.is_empty(),
			"ends=%s lobbies=%d" % [str(hold_ends), lobby_roots.size()])
		_check("the session is still live after all three drops",
			NetworkManager.game_in_progress and NetworkManager.is_host
				and NetworkManager.connection_active and _round_live(),
			_state())
		await get_tree().create_timer(1.0).timeout
		_finish()


	## One host-side socket death: tell the client when to simulate the shared
	## link dying, kill OUR OWN server peer the way the engine's error path does,
	## then require hold + re-listen + rejoin.
	func _host_socket_death_phase(n: int) -> void:
		var before_starts: int = hold_starts
		var before_ends: int = hold_ends.size()
		rpc_id(NetworkManager.remote_player_id, "_prepare_socket_death", 1.1)
		await get_tree().create_timer(0.5).timeout
		var dead_peer := NetworkManager.network
		dead_peer.close()
		print("  [host] phase %d: closed own server socket (host socket death)" % n)

		await _eventually("phase %d: the host held the round instead of ending it"
			% n, func() -> bool: return hold_ends.size() == before_ends, 0.1)
		await _eventually("phase %d: a hold opened on the host" % n,
			func() -> bool: return hold_starts > before_starts, 5.0,
			func() -> String: return _state())
		_check("phase %d: the round was still live when the hold opened" % n,
			bool(snap.get("round_alive", false)) and bool(snap.get("in_progress", false)),
			"snapshot=%s" % str(snap))
		_check(("phase %d: the host did NOT run the client exit path (still the"
			+ " host, no lobby transition)") % n,
			bool(snap.get("host", false)) and int(snap.get("lobbies", -1)) == 0,
			"snapshot=%s lobbies=%d" % [str(snap), lobby_roots.size()])
		_check("phase %d: GameManager did not tear the session down" % n,
			GameManager.session_active, _state())

		# The self-heal itself: a fresh ENet server bound on the SAME port, in
		# place of the dead one, before the client's retry dial lands.
		await _eventually("phase %d: the host re-listened on port %d" % [n, PORT],
			func() -> bool: return (NetworkManager.network != null
				and NetworkManager.network != dead_peer
				and NetworkManager.network.get_connection_status()
					== MultiplayerPeer.CONNECTION_CONNECTED
				and multiplayer.multiplayer_peer == NetworkManager.network),
			5.0, func() -> String: return _state())

		await _await_rejoin(before_ends, n)
		_check("phase %d: the re-listened server is the one serving the session" % n,
			NetworkManager.network != null and NetworkManager.network != dead_peer
				and NetworkManager.connection_active,
			_state())


	## The phase's payoff: the hold must end as a REJOIN, the same round must
	## still be running, and nothing may have routed to the lobby.
	func _await_rejoin(before_ends: int, n: int) -> void:
		await _eventually("phase %d: the hold ended with the peer back" % n,
			func() -> bool: return hold_ends.size() > before_ends, 20.0,
			func() -> String: return "ends=%s %s" % [str(hold_ends), _state()])
		_check("phase %d: the hold resolved as a REJOIN, not an expiry" % n,
			hold_ends.size() > before_ends and bool(hold_ends[before_ends]),
			"ends=%s" % str(hold_ends))
		_check("phase %d: no lobby transition happened across the rejoin" % n,
			lobby_roots.is_empty(), "lobbies=%d" % lobby_roots.size())
		_check("phase %d: the same round is still running after the rejoin" % n,
			_round_live() and NetworkManager.game_in_progress, _state())
		_check("phase %d: the tree is not left paused" % n, not get_tree().paused, _state())


	## The client reports its replica after every rejoin; the host requires the
	## re-sync to have landed (sentinels, not defaults).
	func _replica_report_check(n: int) -> void:
		reported_total = -1
		await _eventually("phase %d: the client reported its replica" % n,
			func() -> bool: return reported_total >= 0, 8.0,
			func() -> String: return "reported total=%d" % reported_total)
		_check("phase %d: the replicas converged on the same total" % n,
			reported_total == _gm_total(),
			"client=%d host=%d %s" % [reported_total, _gm_total(), str(GameManager.g_counter)])
		_check(("phase %d: the client was re-synchronised to the host's lives"
			+ " and difficulty") % n,
			reported_lives == ROUND_LIVES and abs(reported_diff - ROUND_DIFF) < 0.001,
			"client lives=%d diff=%.2f, host lives=%d diff=%.2f"
				% [reported_lives, reported_diff, ROUND_LIVES, ROUND_DIFF])
		# Give the client time to poison its state and score BEFORE this side
		# triggers the next drop: a drop that lands mid-poison costs the phase
		# its resync evidence (the RPCs would fly into a dead connection).
		await get_tree().create_timer(2.5).timeout


## ── CLIENT: the peer that re-dials after every drop, and reports each replica ──

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
		await _eventually("the host started the round on this peer",
			func() -> bool: return NetworkManager.game_in_progress, 12.0,
			func() -> String: return _state())
		var round_ok := await _await_round()
		_check("the client's round went live through the shipped scene load",
			round_ok, _state())

		# Sentinels, written BEFORE the first drop and re-written after every
		# recovery, so every phase's rejoin has a fresh poison to overwrite.
		await _poison_and_score(1)

		# ── PHASE 1: the shared link dies (own peer closed on the host's cue) ──
		await _client_drop_phase(1)
		rpc_id(1, "_report_replica", _gm_total(), GameManager.team_lives,
			GameManager.difficulty_multiplier)

		# ── PHASE 2: the host drops this peer. Nothing is called here — the
		# graceful ENet disconnect reaches this side on its own. ──
		await get_tree().create_timer(0.5).timeout
		await _poison_and_score(2)
		await _client_drop_phase(2)
		rpc_id(1, "_report_replica", _gm_total(), GameManager.team_lives,
			GameManager.difficulty_multiplier)

		# ── PHASE 3: the shared link dies again ──
		await get_tree().create_timer(0.5).timeout
		await _poison_and_score(3)
		await _client_drop_phase(3)
		rpc_id(1, "_report_replica", _gm_total(), GameManager.team_lives,
			GameManager.difficulty_multiplier)

		_check("three drops, three recoveries on the client",
			hold_ends.size() >= 3 and bool(hold_ends[0]) and bool(hold_ends[1])
				and bool(hold_ends[2]),
			"ends=%s" % str(hold_ends))
		await get_tree().create_timer(1.0).timeout
		_finish()


	## Poison the local state so the next rejoin has something to disprove, then
	## keep the G-Counter non-trivial through the production RPC. If a drop from
	## the previous phase is still being recovered from, wait it out first: an
	## RPC fired into a dead connection is lost, not queued. Points are scored
	## ONCE, in phase 1: each drop re-dials on a fresh peer id, and a per-phase
	## submit would keep adding contributions until the 20-point team quota was
	## crossed mid-harness and the round completed on a victory nobody was
	## testing for.
	func _poison_and_score(n: int) -> void:
		await _eventually("phase %d: connection live before poisoning" % n,
			func() -> bool: return (NetworkManager.connection_active
				and not NetworkManager.is_reconnect_hold_active()), 25.0,
			func() -> String: return _state())
		GameManager.team_lives = POISON_LIVES
		GameManager.difficulty_multiplier = POISON_DIFF
		print("  [client] phase %d: poisoned local state to lives=%d diff=%.2f"
			% [n, POISON_LIVES, POISON_DIFF])
		if n == 1:
			await get_tree().create_timer(0.5).timeout
			GameManager.rpc("submit_score", CLIENT_POINTS)
		await _eventually("phase %d: both contributions converged before the drop" % n,
			func() -> bool: return _gm_total() >= HOST_POINTS + CLIENT_POINTS, 10.0,
			func() -> String: return "total=%d %s" % [_gm_total(), str(GameManager.g_counter)])


	## One drop from this side's point of view: the hold opens (either from the
	## host's graceful drop or from this peer's own socket death), the retry
	## timer re-dials, and the rejoined state must be the host's, not the poison.
	func _client_drop_phase(n: int) -> void:
		var before_starts: int = hold_starts
		var before_ends: int = hold_ends.size()
		await _eventually("phase %d: this peer opened a hold" % n,
			func() -> bool: return _hold_since(before_starts, before_ends), 25.0,
			func() -> String: return _state())
		# The 0.1 s no-op above exists because a hold that opened AND ended
		# between two samples still counts through hold_starts.
		await _eventually("phase %d: this peer got back in" % n,
			func() -> bool: return hold_ends.size() > before_ends, 20.0,
			func() -> String: return "ends=%s %s" % [str(hold_ends), _state()])
		_check("phase %d: the hold resolved as a REJOIN on the client too" % n,
			bool(hold_ends[before_ends]) if hold_ends.size() > before_ends else false,
			"ends=%s" % str(hold_ends))
		_check("phase %d: the connection is live again" % n,
			NetworkManager.connection_active, _state())
		_check("phase %d: the same round is still running after the rejoin" % n,
			_round_live() and NetworkManager.game_in_progress, _state())
		_check("phase %d: no lobby transition happened on the client" % n,
			lobby_roots.is_empty(), "lobbies=%d" % lobby_roots.size())
		await _eventually("phase %d: the host's state re-synchronised over the poison" % n,
			func() -> bool: return _resynced(), 8.0,
			func() -> String: return _poison_state())
		await get_tree().create_timer(1.0).timeout
