extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS REJOIN-THEN-NEXT-ROUND-READY HARNESS
## ═══════════════════════════════════════════════════════════════════
## The phone-reported failure (both devices, 2026-09-13/14 logs): after a
## disconnect + successful rejoin MID-ROUND, the round that was live resumes and
## completes fine — but the NEXT round never starts. The rejoined client's log
## shows "Rejoined into a round already in progress - starting now (the GO was
## missed while away)" for a round that loaded AFTER the rejoin: the client
## kicks itself live without readying, the host sits in its force-start hold
## ("waiting for partner") for up to READING_GRACE_SECONDS = 60 s, and the
## players quit to the lobby.
##
## Root cause: a rejoin into a round the peer was ALREADY playing arms
## _pending_live_rejoin_kick and pokes the scene; the poke returns false
## (game_active) and the flag stays armed; the next round's fresh scene consumes
## the STALE kick at instruction-dismiss and skips set_local_player_ready().
##
## What this harness proves, through the REAL production flow (instruction
## dismiss -> ready -> countdown -> GO — no direct start_game() anywhere, that
## bypass is exactly what hid this from VerifyCompletionRejoin):
##   round 1  both peers ready + countdown + live (baseline).
##   round 2  the host drops the client MID-ROUND (the round is live on both),
##            the client rejoins, both complete, round 2 resolves.
##   round 3  THE CASE: the client dismisses round 3's instructions the way a
##            player does. It must READY — not consume a stale kick. The kick
##            path sets game_active synchronously inside the dismissal, so
##            "game_active is still false right after the dismissal" is a sharp,
##            race-free discriminator. The host must then see the ready, run the
##            countdown, and go live itself.
##
##   - Rejoins are awaited by hold INDEX (the hold pauses the tree, which freezes
##     create_timer sleeps: a "before" snapshot is read only after the hold has
##     already closed — see VerifyCompletionRejoin for the post-mortem of that).
##   - Ready observations come from the player_ready_changed SIGNAL, not polls.
##   - The host does not quit until the client reports done.
##
## Run (host first; it binds the port):
##   godot --headless --path . res://tools/VerifyRejoinRoundStart.tscn -- host
##   godot --headless --path . res://tools/VerifyRejoinRoundStart.tscn -- client
## ═══════════════════════════════════════════════════════════════════

const HOST_IP: String = "127.0.0.1"
## Not shared with any other harness: a lingering socket from an aborted run of one
## of them would make this bind fail for a reason that has nothing to do with the
## ready handshake.
const PORT: int = 7822
const LOBBY_PATH: String = "res://scenes/ui/MultiplayerLobby.tscn"
const CONNECT_TIMEOUT: float = 25.0

## Distinct primes, so a default-primed resolution can never pose as a real one.
const HOST_R1_SCORE: int = 11
const CLIENT_R1_SCORE: int = 13
const HOST_R2_SCORE: int = 17
const CLIENT_R2_SCORE: int = 19
const HOST_R3_SCORE: int = 23
const CLIENT_R3_SCORE: int = 29


func _ready() -> void:
	var role := _resolve_role()
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE REJOIN-NEXT-ROUND-READY VERIFICATION — role: %s" % role.to_upper())
	print("═══════════════════════════════════════════════════════════")
	await get_tree().process_frame
	if role != "host" and role != "client":
		push_error("[VRR] unknown role '%s' — pass host or client after --" % role)
		get_tree().quit(1)
		return
	var subject := Subject.new()
	# The name is the RPC address; /root so it survives the rounds' scene changes.
	subject.name = "RejoinRoundStartSubject"
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

	## From the SIGNAL, not polled: readiness claims are about a remote fact.
	var ready_events: Array = []        ## every (peer_id, ready) pair, in order
	var resolutions: int = 0
	## Countdown ticks from the round_starting SIGNAL.
	var round_start_ticks: int = 0
	## From the reconnect-hold SIGNALS.
	var hold_starts: int = 0
	var hold_ends: Array = []           ## one bool per end: true = peer returned
	## MultiplayerLobby scene roots under /root: this whole run must RECOVER, so
	## any appearance at all is a failure.
	var lobby_roots: Array = []
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
		return ("hold=%s in_progress=%s conn=%s paused=%s live=%s resolved=%d ticks=%d lobbies=%d"
			% [str(NetworkManager.is_reconnect_hold_active()),
				str(NetworkManager.game_in_progress), str(NetworkManager.connection_active),
				str(get_tree().paused), str(_round_live()), resolutions,
				round_start_ticks, lobby_roots.size()])


	func _on_any_node_added(n: Node) -> void:
		if n.scene_file_path == LOBBY_PATH and n.get_parent() == get_tree().root:
			lobby_roots.append(n.get_instance_id())
			print("  [%s] lobby root appeared (#%d) — %s"
				% [role, lobby_roots.size(), _state()])


	func _on_hold_started(_seconds: float) -> void:
		hold_starts += 1
		print("  [%s] hold #%d started — %s" % [role, hold_starts, _state()])


	func _on_hold_ended(rejoined: bool) -> void:
		hold_ends.append(rejoined)
		print("  [%s] hold #%d ended rejoined=%s — %s"
			% [role, hold_ends.size(), str(rejoined), _state()])


	func _on_both_completed(_p1s: bool, _p2s: bool, _p1: int, _p2: int) -> void:
		resolutions += 1
		print("  [%s] round RESOLVED (#%d)" % [role, resolutions])


	func _on_player_ready(peer_id: int, ready: bool) -> void:
		ready_events.append([peer_id, ready])


	func _on_round_starting(countdown: int) -> void:
		round_start_ticks += 1


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
	## scene rather than any round scene — rounds here share score baselines.
	func _await_scene(old_id: int = 0, timeout_s: float = 20.0) -> bool:
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


	## Dismiss the instruction overlay the way a tap does — the REAL production
	## entry point. Retries across time: the overlay is raised by the scene's own
	## setup, which can land a few frames after the scene becomes current_scene,
	## and a tap before it is visible is a no-op (_on_instruction_dismissed
	## returns early). The tap budget is PER ATTEMPT: taps aimed at an invisible
	## overlay are no-ops, so a single shared budget would be spent by attempt #1
	## before the overlay ever appeared and no later attempt could tap at all.
	func _dismiss(tag: String) -> void:
		if game == null or not is_instance_valid(game):
			_check("%s: the round scene was up to dismiss instructions on" % tag, false, _state())
			return
		var attempts := 0
		var total_taps := 0
		while attempts < 20 and not bool(game.get("_instruction_dismissed")):
			var taps := 0
			while taps < 8 and not bool(game.get("_instruction_dismissed")):
				game.call("_on_instruction_dismissed")
				taps += 1
			total_taps += taps
			if bool(game.get("_instruction_dismissed")):
				break
			await get_tree().create_timer(0.25).timeout
			attempts += 1
		_check("%s: the instruction overlay was dismissed" % tag,
			bool(game.get("_instruction_dismissed")),
			"%d tap(s) over %d attempt(s)" % [total_taps, attempts + 1])


	## Await the rejoin outcome for hold #hold_index (1-based): it must end as a
	## REJOIN and nothing may have routed to the lobby.
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
		NetworkManager.player_ready_changed.connect(_on_player_ready)
		NetworkManager.round_starting.connect(_on_round_starting)
		match role:
			"host":
				await _run_host()
			_:
				await _run_client()


## ── HOST: drops the client mid-round-2; round 3 must then start through the
##        real ready handshake ──

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

		# ── round 1 through the shipped pair-start, then the REAL flow ──
		var set1: Dictionary = LevelSets.get_random_level_set()
		NetworkManager.start_multiplayer_game_pair(
			set1["player1_game"], set1["player2_game"], set1)
		var ok1 := await _await_scene()
		_check("round 1: the host's round scene loaded", ok1, _state())
		_dismiss("round 1 host")
		await _eventually("round 1: the round went live through the countdown",
			func() -> bool: return _round_live(), 15.0,
			func() -> String: return _state())
		var round1_id := game.get_instance_id()

		NetworkManager.report_player_completion(true, HOST_R1_SCORE, 0.8, 9000)
		var ok2 := await _await_scene(round1_id)
		_check("round 2: the host's round-2 scene loaded", ok2, _state())
		_dismiss("round 2 host")
		await _eventually("round 2: the round went live",
			func() -> bool: return _round_live(), 15.0,
			func() -> String: return _state())
		if not _round_live():
			# The drop below is timed for MID-ROUND; with the round never started
			# the rest of the run would only produce cascade failures that say
			# nothing about the rejoin. The missed check above is the real result.
			_finish()
			return
		var round2_id := game.get_instance_id()
		var client_r2_id := NetworkManager.remote_player_id

		# ── THE DROP: mid-round-2, while the round is live on both peers ──
		# force=false so ENet delivers the disconnect (force=true leaves a zombie
		# peer and the test passes without a reconnect).
		multiplayer.multiplayer_peer.disconnect_peer(client_r2_id, false)
		await _eventually("the host opened a hold after the drop",
			func() -> bool: return hold_starts > 0, 15.0,
			func() -> String: return _state())
		await _await_rejoin(1, "the rejoin")

		# Both complete round 2; the host's transition loads round 3.
		NetworkManager.report_player_completion(true, HOST_R2_SCORE, 0.7, 11000)
		await _eventually("round 2 resolved on both peers",
			func() -> bool: return resolutions >= 1, 15.0,
			func() -> String: return _state())
		var ok3 := await _await_scene(round2_id)
		_check("round 3: the host's round-3 scene loaded", ok3, _state())

		# ── ROUND 3, THE CASE: the host readies; the CLIENT's ready must arrive ──
		var ticks_before: int = round_start_ticks
		var ready_events_before: int = ready_events.size()
		_dismiss("round 3 host")

		# THE DISCRIMINATOR: with the stale-kick bug the client never readies —
		# it kicks itself live and the host waits out the 60 s reading grace.
		await _eventually("round 3: the REJOINED client's ready signal arrived",
			func() -> bool: return _remote_ready_seen(ready_events_before), 15.0,
			func() -> String: return _ready_events_detail(ready_events_before))
		await _eventually("round 3: the countdown ran",
			func() -> bool: return round_start_ticks > ticks_before, 15.0,
			func() -> String: return "ticks=%d" % round_start_ticks)
		await _eventually("round 3: the host's round went live",
			func() -> bool: return _round_live(), 15.0,
			func() -> String: return _state())

		NetworkManager.report_player_completion(true, HOST_R3_SCORE, 0.75, 12000)
		await _eventually("round 3 resolved on both peers",
			func() -> bool: return resolutions >= 2, 15.0,
			func() -> String: return _state())
		_check("the whole run recovered — zero lobby transitions",
			lobby_roots.is_empty(), "lobbies=%d" % lobby_roots.size())
		_check("the tree is not left paused", not get_tree().paused, _state())
		# Do NOT quit before the client is finished: this side quitting would kill
		# the connection under the client's still-running checks.
		await _eventually("the client finished its checks",
			func() -> bool: return _client_done, 60.0)
		await get_tree().create_timer(1.0).timeout
		_finish()


	## A ready=True event for a NON-host peer among the events since `from_index`.
	## The host's own dismissal readies the host; only the remote's ready proves
	## the handshake survived the rejoin.
	func _remote_ready_seen(from_index: int) -> bool:
		for i in range(from_index, ready_events.size()):
			if int(ready_events[i][0]) != 1 and bool(ready_events[i][1]):
				return true
		return false


	## Detail string for the ready check — a method, not an inline lambda, because
	## a one-line lambda body cannot continue onto the next line in GDScript.
	func _ready_events_detail(from_index: int) -> String:
		return "events=%s players=%s" % [str(ready_events.slice(from_index)),
			str(NetworkManager.players)]


## ── CLIENT: gets dropped mid-round-2; round 3 must start through the real
##            ready handshake, not a stale kick ──

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
		_dismiss("round 1 client")
		await _eventually("round 1: the round went live through the countdown",
			func() -> bool: return _round_live(), 15.0,
			func() -> String: return _state())
		var round1_id := game.get_instance_id()

		NetworkManager.report_player_completion(true, CLIENT_R1_SCORE, 0.9, 8000)
		var ok2 := await _await_scene(round1_id)
		_check("round 2: the client's round-2 scene loaded", ok2, _state())
		_dismiss("round 2 client")
		await _eventually("round 2: the round went live",
			func() -> bool: return _round_live(), 15.0,
			func() -> String: return _state())
		var round2_id := game.get_instance_id()

		# ── THE DROP lands here; nothing is called while away ──
		await _eventually("this peer opened a hold after the drop",
			func() -> bool: return hold_starts > 0, 25.0,
			func() -> String: return _state())
		await _await_rejoin(1, "the rejoin")
		await _eventually("round 2 resumed live after the rejoin",
			func() -> bool: return _round_live(), 10.0,
			func() -> String: return _state())

		NetworkManager.report_player_completion(true, CLIENT_R2_SCORE, 0.85, 9500)
		var ok3 := await _await_scene(round2_id)
		_check("round 3: the client's round-3 scene loaded", ok3, _state())

		# ── ROUND 3, THE CASE: dismiss the instructions the way a player does. ──
		# The stale-kick bug fires HERE: the kick path calls start_game()
		# synchronously inside the dismissal, so game_active would be true the
		# instant _dismiss returns. Through the ready path it cannot be — the
		# countdown alone takes ~4 s.
		_dismiss("round 3 client")
		_check("round 3: the dismissal READIED this peer, it did not kick itself live",
			not _round_live(),
			"game_active=%s immediately after the dismissal — the stale kick path "
			% str(_round_live()))
		await _eventually("round 3: this peer's own ready flag is set",
			func() -> bool: return _my_ready(), 5.0,
			func() -> String: return "players=%s" % str(NetworkManager.players))
		await _eventually("round 3: the countdown reached this peer",
			func() -> bool: return round_start_ticks > 0, 15.0,
			func() -> String: return "ticks=%d" % round_start_ticks)
		await _eventually("round 3: the round went live through the countdown",
			func() -> bool: return _round_live(), 15.0,
			func() -> String: return _state())

		NetworkManager.report_player_completion(true, CLIENT_R3_SCORE, 0.8, 10500)
		await _eventually("round 3 resolved on both peers",
			func() -> bool: return resolutions >= 2, 15.0,
			func() -> String: return _state())
		_check("the whole run recovered on the client — zero lobby transitions",
			lobby_roots.is_empty(), "lobbies=%d" % lobby_roots.size())
		rpc_id(1, "_client_done_rpc")
		await get_tree().create_timer(1.0).timeout
		_finish()


	## This peer's own ready flag, as set by set_local_player_ready().
	func _my_ready() -> bool:
		var my_id := multiplayer.get_unique_id()
		return NetworkManager.players.has(my_id) \
			and bool(NetworkManager.players[my_id].get("ready", false))
