extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS IN-ROUND RECONNECT HARNESS
## ═══════════════════════════════════════════════════════════════════
## Until now every disconnect path emptied a live round on the spot. A client whose
## radio blipped for two seconds lost the round outright, and
## NetworkManager._on_grace_period_timeout() said so in its own comment: "in-round
## reconnect is a gap ... Waiting the window out behind a 'reconnecting' overlay, and
## retrying the join, is NOT implemented". The 30 s RECONNECT_GRACE_PERIOD served a peer
## rejoining FROM THE LOBBY, which is a different case: by then the round is already gone.
##
## What is under test is the bounded hold: NetworkManager freezes a round that is still on
## screen for RECONNECT_HOLD_SECONDS, the client re-dials on RECONNECT_RETRY_INTERVAL, and
## if the peer comes back the round resumes with the host's authoritative state. If nobody
## comes back, the round must resolve EXACTLY as it did before this existed — same notice,
## one lobby transition, inside the 12 s bound tools/VerifyHostDeparture.gd asserts.
##
## Both outcomes are measured in one run, in order:
##   PHASE 1  host drops the client mid-round -> both sides hold, freeze and unfreeze,
##            the client rejoins on its own retry timer, state is re-synchronised.
##   PHASE 2  the client leaves for good -> the hold expires and resolves the round.
##
## Run (host first; it binds the port):
##   godot --headless --path . res://tools/VerifyInRoundReconnect.tscn -- host
##   godot --headless --path . res://tools/VerifyInRoundReconnect.tscn -- client
##
## Why the round is a CHILD of this tool scene instead of the loaded scene: the expiry
## path ends in change_scene_to_file(), which frees current_scene — the harness itself on
## a --path launch. The timeline therefore runs on a Subject parented to /root, and the
## round is parented to the tool scene root so the transition frees it the way it frees a
## real round. NetworkManager.game_in_progress is still set through a production API
## (start_game(), the co-op scenario path) because the hold is gated on that flag; only the
## scene ownership is the harness's.
## ═══════════════════════════════════════════════════════════════════

const HOST_IP: String = "127.0.0.1"
## Not shared with any other harness: a lingering socket from an aborted run of one of
## them would make this bind fail for a reason that has nothing to do with reconnect.
const PORT: int = 7807
const HOST_GAME: String = "res://scenes/multiplayer/MP_CatchRainAquarium.tscn"
const CLIENT_GAME: String = "res://scenes/multiplayer/MP_CatchTheRain.tscn"
const LOBBY_PATH: String = "res://scenes/ui/MultiplayerLobby.tscn"
const CONNECT_TIMEOUT: float = 25.0

## Distinct primes, so any total names exactly which contributions are present:
## 7 = host only, 5 = client only, 12 = both.
const HOST_POINTS: int = 7
const CLIENT_POINTS: int = 5

## Non-default round state the host owns, so the client's post-rejoin values can only match
## by having been re-synchronised.
const ROUND_LIVES: int = 2
const ROUND_DIFF: float = 1.35

## Wrong-on-purpose values written into the CLIENT's own copies while it is disconnected.
## Without them "lives match after the rejoin" would pass on a client that was simply never
## touched, since 3 == 3 by default.
const POISON_LIVES: int = 99
const POISON_DIFF: float = 9.0


func _ready() -> void:
	var role := _resolve_role()
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE IN-ROUND RECONNECT VERIFICATION — role: %s" % role.to_upper())
	print("═══════════════════════════════════════════════════════════")
	await get_tree().process_frame
	if role != "host" and role != "client":
		push_error("[VIRR] unknown role '%s' — pass host or client after --" % role)
		get_tree().quit(1)
		return
	var subject := Subject.new()
	# The name is the RPC address. Both processes load this same scene and mount the
	# Subject at the same /root path, so _report_replica() below resolves on the far side.
	subject.name = "InRoundReconnectSubject"
	subject.role = role
	subject.stage = self
	get_tree().root.add_child(subject)
	subject.run()


func _resolve_role() -> String:
	for arg in OS.get_cmdline_user_args():
		var a := arg.strip_edges().to_lower()
		if a == "host" or a == "client":
			return a
	return "host"


## ═══════════════════════════════════════════════════════════════════
## THE SUBJECT — lives at /root, so it survives the transition it is measuring
## ═══════════════════════════════════════════════════════════════════
class Subject extends Node:

	var role: String = "host"
	## The freeable stand-in for the running round: the harness's scene root.
	var stage: Node = null
	var results: Array = []
	var game: Node = null

	## Everything about the hold is recorded from the SIGNALS, not polled. A poll cannot
	## tell "the hold never opened" from "the hold opened and closed between two samples",
	## and phase 1's whole claim is that it opened and then closed the right way.
	var hold_starts: int = 0
	var hold_ends: Array = []            ## one bool per end: true = peer returned
	var hold_started_ms: int = 0
	var hold_ended_ms: int = 0
	## State sampled INSIDE the reconnect_hold_started callback, before any other handler
	## on that signal has run. The round is still on screen at that instant and nothing
	## downstream has had a chance to tear it down, which is the only honest moment to
	## claim "the round was held rather than ended".
	var snap: Dictionary = {}
	## The same instant, one call_deferred later - i.e. still inside the frame the hold
	## opened, but after every other listener on reconnect_hold_started has run.
	##
	## `snap` above CANNOT carry the freeze or the overlay. Both are put in place by
	## MultiplayerMiniGameBase._on_reconnect_hold_started(), which is a second listener on
	## the same signal, and this Subject connects first (it is built before the round is
	## spawned), so at `snap` time the round has not been frozen yet and reading
	## get_tree().paused there would report false every time.
	##
	## Polling for them afterwards does not work either, and that is measured, not
	## assumed: on loopback the whole hold lasted 66 ms on the host and 56 ms on the
	## client, so _eventually() opened its first sample after the round had already
	## resumed and reported "the round froze during the hold — paused=false" against a
	## round that did freeze. A deferred read is the one moment that is both after the
	## round's own handler and before any rejoin can land, since the rejoin needs a
	## network round trip and this needs a call_deferred.
	var frozen_snap: Dictionary = {}
	## Play-clock vs wall-clock across the SECOND hold, the one that runs its full
	## RECONNECT_HOLD_SECONDS. The first hold is unusable for this: 66 ms of freeze is
	## inside the sampling noise of elapsed_play_seconds() and the run reported
	## "played 0.09s of 0.15s wall" as a failure of a clock that was working correctly.
	var clock_play_at_freeze: float = -1.0
	var clock_wall_at_freeze: int = 0
	var clock_play_at_thaw: float = -1.0
	var clock_wall_at_thaw: int = 0
	## MultiplayerLobby scene roots that appeared under /root, counted from node_added
	## rather than polled: two transitions landing in the same frame would be invisible to
	## a poll, and "exactly one" / "not even one" are the claims being made.
	var lobby_roots: Array = []
	## Filled on the host by the client's RPC report. -1 = never reported.
	var reported_total: int = -1
	var reported_lives: int = -1
	var reported_diff: float = -1.0
	var client_peer_id: int = 0


	func _check(label: String, ok: bool, detail: String = "") -> void:
		results.append({"ok": ok, "label": label})
		var mark := "✓" if ok else "✗"
		if detail == "":
			print("  %s %s" % [mark, label])
		else:
			print("  %s %s  — %s" % [mark, label, detail])


	## Poll a condition the OTHER process has to make true. The two processes boot 23
	## autoloads at their own pace and anchor on their own connection events, so a
	## fixed-instant assertion on a cross-process fact is a coin flip on skew.
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
		# Never leave the tree paused behind a finished run: the hold pauses it, and a
		# process that quits while paused can strand the other side waiting on RPCs.
		get_tree().paused = false
		Engine.get_main_loop().quit(1 if failed > 0 else 0)


	func _state() -> String:
		return ("hold=%s in_progress=%s session=%s paused=%s lobbies=%d"
			% [str(NetworkManager.is_reconnect_hold_active()),
				str(NetworkManager.game_in_progress), str(GameManager.session_active),
				str(get_tree().paused), lobby_roots.size()])


	func _gm_total() -> int:
		var total := 0
		for pid in GameManager.g_counter:
			total += int(GameManager.g_counter[pid])
		return total


	## The overlay MultiplayerMiniGameBase puts up for the hold. Looked up by node name on
	## the round's own hud_layer, which is where a player would see it.
	func _overlay() -> Node:
		if game == null or not is_instance_valid(game):
			return null
		var layer = game.get("hud_layer")
		if layer == null or not is_instance_valid(layer):
			return null
		return layer.get_node_or_null("ReconnectOverlay")


	func _on_any_node_added(n: Node) -> void:
		if n.scene_file_path == LOBBY_PATH and n.get_parent() == get_tree().root:
			lobby_roots.append(n.get_instance_id())
			print("  [%s] lobby root appeared (#%d)" % [role, lobby_roots.size()])


	func _on_hold_started(seconds: float) -> void:
		hold_starts += 1
		hold_started_ms = Time.get_ticks_msec()
		if hold_starts == 1:
			snap = {
				"hold": NetworkManager.is_reconnect_hold_active(),
				"in_progress": NetworkManager.game_in_progress,
				"session": GameManager.session_active,
				"round_alive": game != null and is_instance_valid(game),
				"game_active": game != null and is_instance_valid(game)
					and bool(game.get("game_active")),
				"lobbies": lobby_roots.size(),
				"seconds": seconds,
			}
		if hold_starts == 2:
			clock_play_at_freeze = _played()
			clock_wall_at_freeze = Time.get_ticks_msec()
		print("  [%s] hold #%d started (%.0fs) — %s" % [role, hold_starts, seconds, _state()])
		call_deferred("_snapshot_frozen")


	## See frozen_snap. Runs in the same frame as the hold opening, after the round's own
	## handler has frozen the tree and mounted the overlay.
	func _snapshot_frozen() -> void:
		if not frozen_snap.is_empty():
			return
		frozen_snap = {
			"paused": get_tree().paused,
			"overlay": _overlay() != null,
			"hold": NetworkManager.is_reconnect_hold_active(),
			"round_alive": game != null and is_instance_valid(game),
		}
		print("  [%s] frozen-frame snapshot — %s" % [role, str(frozen_snap)])


	## elapsed_play_seconds() off the live round, or -1.0 when there is no round to ask.
	func _played() -> float:
		if game == null or not is_instance_valid(game):
			return -1.0
		if not game.has_method("elapsed_play_seconds"):
			return -1.0
		return float(game.call("elapsed_play_seconds"))


	func _on_hold_ended(rejoined: bool) -> void:
		hold_ends.append(rejoined)
		hold_ended_ms = Time.get_ticks_msec()
		if hold_ends.size() == 2:
			# Sampled here and not later because _resolve_lost_peer() runs immediately
			# after this signal and frees the round.
			clock_play_at_thaw = _played()
			clock_wall_at_thaw = Time.get_ticks_msec()
		print("  [%s] hold #%d ended rejoined=%s after %d ms — %s"
			% [role, hold_ends.size(), str(rejoined),
				hold_ended_ms - hold_started_ms, _state()])


	## Client -> host, so one log can state whether the two replicas agree after the rejoin.
	@rpc("any_peer", "reliable")
	func _report_replica(total: int, lives: int, diff: float) -> void:
		reported_total = total
		reported_lives = lives
		reported_diff = diff
		print("  [host] client reported total=%d lives=%d diff=%.2f" % [total, lives, diff])


	## Stop the round spawning things at us: an uncaught drop costs a shared life, and with
	## nothing driving the bucket that is a stream of misses that could end the round before
	## the drop under test ever happens.
	func _quiet(g: Node) -> void:
		if g.get("spawn_timer") != null:
			(g.spawn_timer as Timer).stop()
		for child in g.get_children():
			if child is Area2D and child.has_meta("type"):
				child.queue_free()


	## The two values _sync_game_state() has to have restored, as a named function so the
	## caller's lambda stays one line.
	func _resynced() -> bool:
		return (GameManager.team_lives == ROUND_LIVES
			and abs(GameManager.difficulty_multiplier - ROUND_DIFF) < 0.001)


	## The lobby's own subtitle line, which is where a queued notice ends up rendered.
	func _lobby_subtitle() -> Label:
		var cs := get_tree().current_scene
		if cs == null or not is_instance_valid(cs):
			return null
		return cs.get_node_or_null("MarginContainer/VBoxContainer/SubtitleLabel") as Label


	func _spawn(path: String) -> Node:
		var packed: PackedScene = load(path)
		var g: Node = packed.instantiate()
		stage.add_child(g)
		return g


	func run() -> void:
		get_tree().node_added.connect(_on_any_node_added)
		NetworkManager.reconnect_hold_started.connect(_on_hold_started)
		NetworkManager.reconnect_hold_ended.connect(_on_hold_ended)
		match role:
			"host":
				await _run_host()
			_:
				await _run_client()


## ── HOST: opens the session, drops the partner, then watches both outcomes ──

	func _run_host() -> void:
		_check("GameManager.host_game() bound port %d" % PORT, GameManager.host_game(PORT))
		var anchored := [false]
		get_tree().create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
			if not anchored[0]:
				_check("a client registered within %ds" % int(CONNECT_TIMEOUT), false, _state())
				_finish()
		)
		# player_connected carries (peer_id, player_num), so awaiting it yields an ARRAY,
		# not the id. Taking element 0 rather than the whole thing.
		var registered: Array = await NetworkManager.player_connected
		client_peer_id = int(registered[0])
		anchored[0] = true
		print("  [host] client %d registered" % client_peer_id)

		# ── the session bootstrap the lobby's start button sends ──
		await get_tree().create_timer(1.0).timeout
		GameManager.rpc("_begin_multiplayer_session_rpc")
		await get_tree().process_frame
		_check("the co-op session is open on the host", GameManager.session_active, _state())

		# ── the production round-start API, so game_in_progress is set the shipped way ──
		NetworkManager.set_ready(true)
		await _eventually("both players reported ready",
			func() -> bool: return NetworkManager.are_all_players_ready(), 8.0,
			func() -> String: return "players=%s" % str(NetworkManager.players))
		NetworkManager.start_game("in_round_reconnect_probe")
		await get_tree().process_frame
		_check("NetworkManager reports a round in progress",
			NetworkManager.game_in_progress, _state())

		# ── a real round on a real connection ──
		game = _spawn(HOST_GAME)
		await get_tree().create_timer(1.5).timeout
		if game.has_method("start_game"):
			game.start_game()
		_quiet(game)
		_check("the host's round is live", bool(game.get("game_active")), _state())

		# Round state the client cannot guess, so its post-rejoin copy proves a re-sync.
		GameManager.team_lives = ROUND_LIVES
		GameManager.difficulty_multiplier = ROUND_DIFF

		# ── score through the production RPC, so both replicas hold two slots ──
		await get_tree().create_timer(1.0).timeout
		GameManager.rpc("submit_score", HOST_POINTS)
		await _eventually("both contributions converged before the drop",
			func() -> bool: return _gm_total() >= HOST_POINTS + CLIENT_POINTS, 8.0,
			func() -> String: return "total=%d %s" % [_gm_total(), str(GameManager.g_counter)])

		# ── PHASE 1: drop the partner mid-round ──
		var play_before: float = float(game.call("elapsed_play_seconds"))
		var wall_before: int = Time.get_ticks_msec()
		# force=false, so ENet actually delivers the disconnect. force=true leaves the peer
		# in place on this side and the client never learns it was dropped, which makes a
		# reconnect test pass without a reconnect.
		multiplayer.multiplayer_peer.disconnect_peer(client_peer_id, false)
		print("  [host] dropped peer %d (graceful close, session still open)" % client_peer_id)

		await _eventually("the host opened a hold instead of ending the round",
			func() -> bool: return hold_starts >= 1, 3.0, func() -> String: return _state())
		_check("the round was still live when the hold opened",
			bool(snap.get("round_alive", false)) and bool(snap.get("game_active", false)),
			"snapshot=%s" % str(snap))
		_check("game_in_progress was still true when the hold opened",
			bool(snap.get("in_progress", false)), "snapshot=%s" % str(snap))
		_check("GameManager did not tear the session down (it stood down for the hold)",
			bool(snap.get("session", false)) and GameManager.session_active, _state())
		_check("no lobby transition happened when the hold opened",
			int(snap.get("lobbies", -1)) == 0, "lobbies=%s" % str(snap.get("lobbies", -1)))
		_check("the hold announced RECONNECT_HOLD_SECONDS",
			abs(float(snap.get("seconds", 0.0)) - NetworkManager.RECONNECT_HOLD_SECONDS) < 0.01,
			"announced=%s const=%s" % [str(snap.get("seconds", 0.0)),
				str(NetworkManager.RECONNECT_HOLD_SECONDS)])
		await get_tree().process_frame
		# Both read off frozen_snap, not off the tree as it is now. See frozen_snap: the
		# hold is over in ~66 ms on loopback, so by the time these lines run the round has
		# legitimately resumed, and a live read reports a freeze that did happen as one
		# that did not.
		_check("the round froze during the hold",
			bool(frozen_snap.get("paused", false)), str(frozen_snap))
		_check("the reconnecting overlay went up on the round's HUD",
			bool(frozen_snap.get("overlay", false)), str(frozen_snap))

		# ── the client dials back in on its own retry timer ──
		await _eventually("the hold ended with the peer back",
			func() -> bool: return hold_ends.size() >= 1, 10.0,
			func() -> String: return "ends=%s %s" % [str(hold_ends), _state()])
		_check("the first hold resolved as a REJOIN, not an expiry",
			hold_ends.size() >= 1 and bool(hold_ends[0]),
			"ends=%s" % str(hold_ends))
		# Guarded on the hold having actually ended. The first run of this harness passed
		# this line with "-8805 ms of 6000 ms": hold_ended_ms was still 0, so the
		# subtraction was negative and the comparison was true for the wrong reason.
		_check("the hold ended before RECONNECT_HOLD_SECONDS elapsed",
			hold_ends.size() >= 1 and hold_ended_ms > hold_started_ms
				and hold_ended_ms - hold_started_ms
					< int(NetworkManager.RECONNECT_HOLD_SECONDS * 1000.0),
			"%d ms of %d ms" % [hold_ended_ms - hold_started_ms,
				int(NetworkManager.RECONNECT_HOLD_SECONDS * 1000.0)])
		await get_tree().process_frame
		_check("the round unfroze", not get_tree().paused, _state())
		_check("the reconnecting overlay came down", _overlay() == null, _state())
		_check("the same round is still running after the rejoin",
			is_instance_valid(game) and bool(game.get("game_active")), _state())
		_check("no lobby transition happened across the whole rejoin",
			lobby_roots.is_empty(), "lobbies=%d" % lobby_roots.size())
		_check("game_in_progress survived the rejoin", NetworkManager.game_in_progress, _state())

		# ── the clock came through the rejoin intact ──
		# Guarded: if the round did not survive, no clock claim can be made at all — and
		# calling into a freed instance crashed the timeline on the first run.
		if not is_instance_valid(game):
			_check("the round clock survived the rejoin", false,
				"the round was freed, so no clock could be sampled")
			await get_tree().create_timer(1.0).timeout
			_finish()
			return
		var play_after: float = float(game.call("elapsed_play_seconds"))
		var wall_after: int = Time.get_ticks_msec()
		var d_play: float = play_after - play_before
		var d_wall: float = float(wall_after - wall_before) / 1000.0
		# Deliberately NOT "the frozen interval was excluded". That claim needs a frozen
		# interval big enough to see and this hold is 66 ms; the run duly reported
		# "played 0.09s of 0.15s wall" as a failure of a clock that was working correctly.
		# The exclusion is asserted below instead, across the hold that runs its full 6 s.
		# What 66 ms DOES support: the clock kept advancing and did not run past the wall
		# clock, i.e. the pause accounting did not corrupt it on the way through.
		_check("the round clock survived the rejoin",
			d_play > 0.0 and d_play <= d_wall + 0.05,
			"played %.2fs of %.2fs wall" % [d_play, d_wall])

		# ── the two replicas have to agree again ──
		await _eventually("the client reported its replica after the rejoin",
			func() -> bool: return reported_total >= 0, 8.0,
			func() -> String: return "reported total=%d" % reported_total)
		_check("the replicas converged on the same total after the rejoin",
			reported_total == _gm_total(),
			"client=%d host=%d %s" % [reported_total, _gm_total(), str(GameManager.g_counter)])
		_check("the client was re-synchronised to the host's lives and difficulty",
			reported_lives == ROUND_LIVES and abs(reported_diff - ROUND_DIFF) < 0.001,
			"client lives=%d diff=%.2f, host lives=%d diff=%.2f"
				% [reported_lives, reported_diff, ROUND_LIVES, ROUND_DIFF])

		# ── PHASE 2: the client leaves for good and the hold must EXPIRE ──
		# Nothing is called here. The client closes its own peer on its own schedule, which
		# is what a player force-quitting the app looks like from this side.
		var before_ends: int = hold_ends.size()
		await _eventually("a second hold opened when the partner left for good",
			func() -> bool: return hold_starts >= 2, 20.0,
			func() -> String: return _state())
		var drop2_ms: int = Time.get_ticks_msec()
		await _eventually("the second hold expired on its own timer",
			func() -> bool: return hold_ends.size() > before_ends,
			NetworkManager.RECONNECT_HOLD_SECONDS + 4.0,
			func() -> String: return "ends=%s %s" % [str(hold_ends), _state()])
		_check("the expiry resolved as NOT rejoined",
			hold_ends.size() > before_ends and not bool(hold_ends[before_ends]),
			"ends=%s" % str(hold_ends))
		# The failure path has to behave exactly as it did before the hold existed:
		# VerifyHostDeparture asserts a dead round is left within 12 s, and the hold now
		# spends 6 of those, so the transition still has to land inside the bound.
		await _eventually("the round resolved to exactly one lobby transition",
			func() -> bool: return lobby_roots.size() == 1, 6.0,
			func() -> String: return "lobbies=%d %s" % [lobby_roots.size(), _state()])
		var out_ms: int = Time.get_ticks_msec() - drop2_ms
		_check("hold + transition fit inside VerifyHostDeparture's 12 s bound",
			out_ms < 12000, "%d ms from drop to lobby" % out_ms)
		# ── the frozen seconds must not be charged to the players ──
		# Measured across the SECOND hold: nobody rejoins it, so it runs the whole
		# RECONNECT_HOLD_SECONDS with the tree paused, which is a window big enough to
		# measure. Both samples are taken inside the signal handlers
		# (_on_hold_started / _on_hold_ended) because _resolve_lost_peer() frees the round
		# in the same frame as the second signal.
		var frozen_wall: float = float(clock_wall_at_thaw - clock_wall_at_freeze) / 1000.0
		var frozen_play: float = clock_play_at_thaw - clock_play_at_freeze
		if clock_play_at_freeze < 0.0 or clock_play_at_thaw < 0.0:
			_check("the round clock excluded the frozen interval", false,
				"no clock sample: play_at_freeze=%.2f play_at_thaw=%.2f"
					% [clock_play_at_freeze, clock_play_at_thaw])
		else:
			_check("the round clock excluded the frozen interval",
				frozen_wall > 4.0 and frozen_play < 0.5,
				"%.2fs of wall clock passed frozen, of which the round charged %.2fs"
					% [frozen_wall, frozen_play])
		_check("the round was cleared on expiry", not NetworkManager.game_in_progress, _state())
		_check("the dead round scene was freed",
			game == null or not is_instance_valid(game), _state())
		# Read off the LOBBY, not off GameManager: consume_multiplayer_notice() clears on
		# read and the lobby's _ready() has already read it by now, so the queued key is
		# gone and the rendered subtitle is the only remaining evidence. Asserting it is
		# not still a raw "notice_" key also catches a missing translation row.
		await get_tree().create_timer(0.5).timeout
		var subtitle := _lobby_subtitle()
		var notice_text: String = "" if subtitle == null else subtitle.text
		_check("the lobby explains why the round ended",
			not notice_text.is_empty() and not notice_text.begins_with("notice_"),
			"SubtitleLabel=\"%s\"" % notice_text)
		_check("the tree is not left paused behind the lobby", not get_tree().paused, _state())
		await get_tree().create_timer(1.0).timeout
		_finish()


## ── CLIENT: the peer that gets dropped, re-dials, and then leaves for good ──

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

		game = _spawn(CLIENT_GAME)
		await get_tree().create_timer(1.5).timeout
		if game.has_method("start_game"):
			game.start_game()
		_quiet(game)
		_check("the client's round is live", bool(game.get("game_active")), _state())

		# Sentinels. Without them "lives and difficulty match after the rejoin" would pass
		# on a client that was never written to at all, because the two sides' defaults
		# already agree.
		#
		# Written HERE, before the drop, and not inside the hold where it reads more
		# naturally. The hold lasts 56 ms on loopback: the previous version wrote the
		# sentinels after two _eventually() calls had each burned a full timeout inside the
		# hold, so by then the rejoin and the host's _sync_game_state had already landed and
		# the poison overwrote the very re-sync it was supposed to prove. The host's log
		# ordering showed it plainly - "Game state merged" printed, THEN "poisoned local
		# state", and the client duly reported lives=99 back. Nothing broadcasts
		# _sync_game_state during a round (GameManager only sends it from
		# _on_peer_connected() and from reset_multiplayer_game() between rounds), so these
		# values survive untouched until the rejoin, which is exactly the window wanted.
		GameManager.team_lives = POISON_LIVES
		GameManager.difficulty_multiplier = POISON_DIFF
		print("  [client] poisoned local state to lives=%d diff=%.2f" % [POISON_LIVES, POISON_DIFF])

		await get_tree().create_timer(0.5).timeout
		GameManager.rpc("submit_score", CLIENT_POINTS)
		await _eventually("both contributions converged before the drop",
			func() -> bool: return _gm_total() >= HOST_POINTS + CLIENT_POINTS, 10.0,
			func() -> String: return "total=%d %s" % [_gm_total(), str(GameManager.g_counter)])

		# ── PHASE 1: the host drops this peer. Nothing is called here either. ──
		await _eventually("this peer opened a hold instead of leaving the round",
			func() -> bool: return hold_starts >= 1, 25.0,
			func() -> String: return _state())
		_check("the round was still live when the hold opened",
			bool(snap.get("round_alive", false)) and bool(snap.get("game_active", false)),
			"snapshot=%s" % str(snap))
		_check("game_in_progress was still true when the hold opened",
			bool(snap.get("in_progress", false)), "snapshot=%s" % str(snap))
		_check("_on_server_disconnected did not route this peer out",
			int(snap.get("lobbies", -1)) == 0, "lobbies=%s" % str(snap.get("lobbies", -1)))
		await get_tree().process_frame
		# Both read off frozen_snap, not off the tree as it is now. See frozen_snap: the
		# hold is over in ~66 ms on loopback, so by the time these lines run the round has
		# legitimately resumed, and a live read reports a freeze that did happen as one
		# that did not.
		_check("the round froze during the hold",
			bool(frozen_snap.get("paused", false)), str(frozen_snap))
		_check("the reconnecting overlay went up on the round's HUD",
			bool(frozen_snap.get("overlay", false)), str(frozen_snap))

		# ── the retry timer inside NetworkManager is what dials; the harness only watches ──
		await _eventually("this peer got back in before the hold expired",
			func() -> bool: return hold_ends.size() >= 1, 10.0,
			func() -> String: return "ends=%s %s" % [str(hold_ends), _state()])
		_check("the hold resolved as a REJOIN on the client too",
			hold_ends.size() >= 1 and bool(hold_ends[0]), "ends=%s" % str(hold_ends))
		_check("the connection is live again", NetworkManager.connection_active, _state())
		await get_tree().process_frame
		_check("the round unfroze", not get_tree().paused, _state())
		_check("the reconnecting overlay came down", _overlay() == null, _state())
		_check("the same round is still running after the rejoin",
			is_instance_valid(game) and bool(game.get("game_active")), _state())
		_check("no lobby transition happened on the client",
			lobby_roots.is_empty(), "lobbies=%d" % lobby_roots.size())

		# ── the host's re-sync has to overwrite the sentinels ──
		# Both lambdas are one line each on purpose: a GDScript inline lambda body ENDS at
		# the newline, so a continuation line is a parse error, not a longer body.
		await _eventually("the host's state re-synchronised over the sentinels",
			func() -> bool: return _resynced(), 8.0,
			func() -> String: return "lives=%d diff=%.2f" % [GameManager.team_lives, GameManager.difficulty_multiplier])
		_check("the G-Counter total survived the drop and rejoin",
			_gm_total() >= HOST_POINTS + CLIENT_POINTS,
			"total=%d %s" % [_gm_total(), str(GameManager.g_counter)])
		rpc_id(1, "_report_replica", _gm_total(), GameManager.team_lives,
			GameManager.difficulty_multiplier)

		# ── PHASE 2: leave for good, so the host's next hold has to expire ──
		await get_tree().create_timer(2.0).timeout
		print("  [client] leaving for good — closing the peer")
		NetworkManager.disconnect_multiplayer()
		await get_tree().process_frame
		_check("a deliberate teardown left no hold running on this side",
			not NetworkManager.is_reconnect_hold_active(), _state())
		await get_tree().create_timer(1.0).timeout
		_finish()
