extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS UNGRACEFUL HOST-DEPARTURE VERIFICATION HARNESS
## ═══════════════════════════════════════════════════════════════════
## The last uncovered Phase 5 multiplayer case: the host VANISHES mid-round without
## pressing anything. The two existing harnesses cover the neighbours, not this:
## tools/VerifyReturnToLobby.gd is the DELIBERATE press (an RPC announces the teardown
## before the socket goes, so both peers walk out in step) and
## tools/VerifyMultiplayerReconnect.gd is the CLIENT dropping and rejoining. A killed or
## force-quit host announces nothing, and on the client that is a different code path:
##
##   multiplayer.server_disconnected
##     ├─ NetworkManager._on_server_disconnected()   opens a 30 s grace window, re-emits
##     │    └─ MultiplayerMiniGameBase._on_server_disconnected()   (the 12 MP_* games)
##     │         └─ GameManager.return_to_multiplayer_lobby()
##     └─ GameManager._on_server_disconnected()      nulls the peer, and routes out only
##                                                   when COOP *and* session_active
##
## The five co-op MiniGame_* games extend MultiplayerMiniGameEffects, not the base, and
## connect NOTHING to server_disconnected (zero hits across all five), so their only route
## out of a dead round is GameManager's session_active branch. That is why there are two
## client roles against one host driver: `client` puts a base-family game on the wire and
## `coop` puts a co-op-family game on it, and both are asked the same questions.
##
## Run (host first, it binds the port) — twice, once per client role:
##   godot --headless --path . res://tools/VerifyHostDeparture.tscn -- host
##   godot --headless --path . res://tools/VerifyHostDeparture.tscn -- client
##   godot --headless --path . res://tools/VerifyHostDeparture.tscn -- host
##   godot --headless --path . res://tools/VerifyHostDeparture.tscn -- coop
##
## Connection goes through the PRODUCTION entry points GameManager.host_game() and
## GameManager.join_game(), not NetworkManager.create_server(): both autoloads hold half
## of the session state, only these two wire both halves, and they fix the order the two
## server_disconnected handlers run in (join_game adopts the peer into NetworkManager
## BEFORE connecting GameManager's own callbacks, so NetworkManager's handler — the one
## that opens the grace window — runs first). That order is load-bearing, so the harness
## must not bypass it.
##
## The departure is `multiplayer.multiplayer_peer.close()` on the host with no
## disconnect_multiplayer() and no return_to_lobby(), followed by the host process
## exiting. Nothing is broadcast; the client's only notice is the engine's.
##
## Every assertion lives on a SUBJECT node parented to /root rather than on this scene
## root, because the behaviour under test ENDS in change_scene_to_file(), which frees the
## current scene — this node. The minigame stays a child of this node on purpose, so the
## transition frees it exactly as production does, and "the dead round was really torn
## down" becomes observable as `not is_instance_valid(...)` instead of an assumption.
## ═══════════════════════════════════════════════════════════════════

const HOST_IP: String = "127.0.0.1"
const PORT: int = 7800
## A second port for the "can this peer start a fresh session at once" check. Re-binding
## the SAME port would pass even with a leaked socket on some stacks; a different port
## would pass even with a leaked one on all of them. The check is about the peer's own
## state, so it uses a clean port and says so.
const REHOST_PORT: int = 7801
const CONNECT_TIMEOUT: float = 30.0

const BASE_GAME: String = "res://scenes/multiplayer/MP_CatchRainAquarium.tscn"
const COOP_GAME: String = "res://scripts/multiplayer/MiniGame_Rain.tscn"
const LOBBY_PATH: String = "res://scenes/ui/MultiplayerLobby.tscn"

## GameManager.GameMode.MULTIPLAYER_COOP. Mirrored as a plain int because a const or enum
## on an autoload is not readable through the singleton instance from GDScript.
const MODE_COOP: int = 1

## Deliberately small, and deliberately unequal so each slot is identifiable. The team
## total has to stay UNDER GameManager.current_minigame_quota (20 for this pairing) or the
## host announces a win through _check_win_condition() and both rounds close before the
## host can leave — the first run of this harness scored 15+10 and measured a departure
## that landed on an already-finished round, which is a different case entirely.
const HOST_POINTS: int = 5
const CLIENT_POINTS: int = 4

## Host-local seconds between the round converging and the socket closing. The client never
## waits on this clock — every post-departure assertion below is eventual, because the two
## processes share a wire, not a clock.
const DROP_AT: float = 1.0

## Mirrors NetworkManager.RECONNECT_GRACE_PERIOD, for the printed detail only. A const on
## an autoload is not readable through the singleton instance from GDScript, so the harness
## carries its own copy rather than pretending to read the real one.
const GRACE_PERIOD_S: float = 30.0


func _ready() -> void:
	var role := _resolve_role()
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE UNGRACEFUL HOST-DEPARTURE VERIFICATION — role: %s" % role.to_upper())
	print("═══════════════════════════════════════════════════════════")
	await get_tree().process_frame
	if role != "host" and role != "client" and role != "coop":
		push_error("[VHD] unknown role '%s' — pass host, client or coop after --" % role)
		get_tree().quit(1)
		return
	var subject := Subject.new()
	subject.name = "HostDepartureSubject"
	subject.role = role
	subject.stage = self
	get_tree().root.add_child(subject)
	subject.run()


func _resolve_role() -> String:
	for arg in OS.get_cmdline_user_args():
		var a := arg.strip_edges().to_lower()
		if a == "host" or a == "client" or a == "coop":
			return a
	return "host"


## ═══════════════════════════════════════════════════════════════════
## THE SUBJECT — lives at /root, so it survives the scene change it is measuring
## ═══════════════════════════════════════════════════════════════════
class Subject extends Node:

	var role: String = "host"
	## The freeable stand-in for the running round: the harness's scene root. The minigame
	## is parented here, so GameManager's transition frees both together.
	var stage: Node = null
	var results: Array = []
	var game: Node = null
	var drop_seen: bool = false
	var drop_at_msec: int = 0
	## NetworkManager/GameManager state sampled INSIDE the server_disconnected callback,
	## before any handler further down the chain has run. Asserting from a snapshot is the
	## only honest way to claim "the grace window opened": the teardown that follows cancels
	## it a few frames later, so a poll would find it already closed and could not tell the
	## involuntary path from the deliberate one.
	var snap: Dictionary = {}
	## The same idea one signal earlier. multiplayer.peer_disconnected is what actually reaches
	## the client first, and the round is still live at that instant, so this is the snapshot the
	## mid-round claim is read from; `snap` above stays the source for the grace-window claim,
	## which only exists on server_disconnected.
	var first_snap: Dictionary = {}
	var first_at_msec: int = 0
	## Instance ids of MultiplayerLobby scene roots that appeared under /root. Counted from
	## node_added rather than polled, because two transitions landing in the same frame would
	## be invisible to a poll — and "exactly one transition" is the claim being made.
	var lobby_roots: Array = []


	func _check(label: String, ok: bool, detail: String = "") -> void:
		results.append({"ok": ok, "label": label})
		var mark := "✓" if ok else "✗"
		if detail == "":
			print("  %s %s" % [mark, label])
		else:
			print("  %s %s  — %s" % [mark, label, detail])


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
		get_tree().quit(1 if failed > 0 else 0)


	func _gm_total() -> int:
		var t := 0
		for pid in GameManager.g_counter:
			t += int(GameManager.g_counter[pid])
		return t


	func _state() -> String:
		var scene_path := "<none>"
		var cs := get_tree().current_scene
		if cs != null and is_instance_valid(cs):
			scene_path = cs.scene_file_path
		return ("scene=%s peer=%s NM[active=%s in_progress=%s grace=%s players=%d] "
			+ "GM[conn=%s session=%s counter=%s order=%d] paused=%s")% [
			scene_path.get_file(),
			"null" if multiplayer.multiplayer_peer == null else "live",
			str(NetworkManager.connection_active), str(NetworkManager.game_in_progress),
			str(NetworkManager.grace_period_active), NetworkManager.players.size(),
			str(GameManager.is_multiplayer_connected), str(GameManager.session_active),
			str(GameManager.g_counter), GameManager.multiplayer_game_order.size(),
			str(get_tree().paused)]


	func _on_any_node_added(n: Node) -> void:
		if n.scene_file_path == LOBBY_PATH and n.get_parent() == get_tree().root:
			lobby_roots.append(n.get_instance_id())


	func _on_server_disconnected_seen() -> void:
		drop_seen = true
		drop_at_msec = Time.get_ticks_msec()
		snap = {
			"grace_active": NetworkManager.grace_period_active,
			"time_left": NetworkManager.disconnection_timer.time_left,
			"connection_active": NetworkManager.connection_active,
			"game_in_progress": NetworkManager.game_in_progress,
			"gm_session": GameManager.session_active,
			"gm_mode": int(GameManager.current_game_mode),
			"counter": GameManager.g_counter.duplicate(),
			"round_live": game != null and is_instance_valid(game) and bool(game.get("game_active")),
		}
		print("  [%s] server_disconnected seen — %s" % [role, _state()])

	## Snapshot at the FIRST signal that carries the drop. Peer id 1 is always the server in
	## ENet, and this fires ahead of both server_disconnected and the round's own teardown.
	func _on_peer_disconnected_seen(id: int) -> void:
		if id != 1 or not first_snap.is_empty():
			return
		first_at_msec = Time.get_ticks_msec()
		first_snap = {
			"round_live": game != null and is_instance_valid(game) and bool(game.get("game_active")),
			"counter": GameManager.g_counter.duplicate(),
			"gm_session": GameManager.session_active,
		}
		print("  [%s] peer_disconnected(%d) seen first — round_live=%s"
			% [role, id, str(first_snap["round_live"])])


	func run() -> void:
		get_tree().node_added.connect(_on_any_node_added)
		match role:
			"host":
				await _run_host()
			_:
				await _run_client(role == "coop")


	## The round, parented to the freeable stage rather than to this node. Instantiated as a
	## child instead of loaded as the scene because MultiplayerMiniGameBase._ready() bails to
	## the lobby unless the connection is already live, and because the harness has to outlive
	## the round it is watching.
	func _spawn(path: String) -> Node:
		var packed: PackedScene = load(path)
		var g: Node = packed.instantiate()
		stage.add_child(g)
		return g


	## Stop the game spawning things at us. Both families report a miss for every object that
	## reaches the floor uncaught, and a miss costs the team a shared life — with no input
	## driving the bucket that is a stream of misses at an unpredictable rate, which could end
	## the round before the host ever leaves and turn this into a test of nothing.
	func _quiet(g: Node) -> void:
		if g.get("spawn_timer") != null:
			(g.spawn_timer as Timer).stop()
		for child in g.get_children():
			# The meta filter is the base family's: MP_CatchRainAquarium tags its drops
			# with it, and a bare `child is Area2D` would also free the player's bucket.
			# The co-op family needs no filtering here — only its host spawns, and the host
			# in this harness is running a base-family game.
			if child is Area2D and child.has_meta("type"):
				child.queue_free()


## ── HOST: the driver. Opens a real session, plays a real round, then vanishes. ──

	func _run_host() -> void:
		_check("GameManager.host_game() bound port %d" % PORT, GameManager.host_game(PORT), _state())
		var anchored := [false]
		get_tree().create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
			if not anchored[0]:
				_check("a client connected within %ds" % int(CONNECT_TIMEOUT), false, _state())
				_finish()
		)
		# While the two processes have not met yet, say so once a second. The first run of
		# this harness failed here with the client reporting a completed handshake and the
		# host's multiplayer.get_peers() staying empty for the full 30 s window, and a
		# silent log could not tell "the client never launched" from "the client connected
		# to something that was not this server". It goes quiet the moment they pair.
		var hb := Timer.new()
		hb.wait_time = 1.0
		add_child(hb)
		hb.timeout.connect(func() -> void:
			if anchored[0]:
				hb.stop()
				return
			print("  [host] waiting — uid=%d peers=%s players=%s" % [multiplayer.get_unique_id(), str(multiplayer.get_peers()), str(NetworkManager.players.keys())])
		)
		hb.start()
		await NetworkManager.player_connected
		anchored[0] = true
		print("  [host] client registered — starting timeline")

		# ── t=1.0  the session bootstrap the lobby's start button sends ──
		await get_tree().create_timer(1.0).timeout
		GameManager.rpc("_begin_multiplayer_session_rpc")
		await get_tree().process_frame
		_check("the co-op session is open on the host",
			GameManager.session_active and int(GameManager.current_game_mode) == MODE_COOP,
			_state())

		# ── t=2.0  a real round on a real connection ──
		await get_tree().create_timer(1.0).timeout
		game = _spawn(BASE_GAME)
		await get_tree().create_timer(1.5).timeout
		if game.has_method("start_game"):
			game.start_game()
		_quiet(game)
		_check("the host's round is live", bool(game.get("game_active")), _state())

		# ── t=4.5  score through the production RPC, so both replicas hold two slots ──
		await get_tree().create_timer(1.0).timeout
		GameManager.rpc("submit_score", HOST_POINTS)
		await _eventually("the partner's contribution reached this replica",
			func() -> bool: return _gm_total() >= HOST_POINTS + CLIENT_POINTS, 6.0,
			func() -> String: return "team total=%d, counter=%s" % [_gm_total(), str(GameManager.g_counter)])

		# ── the drop: vanish, announcing nothing ──
		await get_tree().create_timer(DROP_AT).timeout
		# `game_active` is the round's own flag and the honest observable here.
		# NetworkManager.game_in_progress is NOT asserted: it is set by NetworkManager's
		# round-start API (start_game / start_multiplayer_game*), and this harness starts
		# rounds by instantiating the scene as a child instead — the only way for the
		# harness to outlive the round it is watching. The flag is printed rather than
		# claimed, and the client's copy of it is a real product asymmetry noted separately.
		_check("the host is still mid-round at the moment it leaves",
			bool(game.get("game_active")),
			"game_active=%s, NM.game_in_progress=%s (harness-started round) %s"
				% [str(game.get("game_active")), str(NetworkManager.game_in_progress), _state()])
		# The discriminator against tools/VerifyReturnToLobby.gd: THAT case calls
		# return_to_lobby(), which RPCs the partner and then tears both halves down in order.
		# Here nothing is called — the socket simply closes under a session that is still open
		# on this side, which is what a killed app or a lost radio looks like from the client.
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.close()
		print("  [host] socket closed with the session still open — %s" % _state())
		_check("the departure was ungraceful: no teardown ran on the host first",
			GameManager.session_active and GameManager.is_multiplayer_connected
				and NetworkManager.connection_active,
			_state())
		await get_tree().create_timer(1.5).timeout
		_finish()


## ── CLIENT: the subject. Plays a real round and then has the host yanked away. ──

	## Does the ROUND itself listen for the host's departure, or only the autoloads? This is
	## the structural half of the two-family claim in the header, measured rather than grepped:
	## the base family connects its own handler in _ready(), the co-op family connects nothing
	## and depends entirely on GameManager's session_active branch.
	func _game_listens() -> bool:
		for c in NetworkManager.server_disconnected.get_connections():
			var cb: Callable = c["callable"]
			if cb.get_object() == game:
				return true
		return false


	func _lobby_panel(node_name: String) -> Control:
		var cs := get_tree().current_scene
		if cs == null or not is_instance_valid(cs):
			return null
		return cs.get_node_or_null("MarginContainer/VBoxContainer/" + node_name) as Control


	func _run_client(coop: bool) -> void:
		# Hook the re-emitted signal BEFORE the round exists. Callbacks run in connection order
		# and MultiplayerMiniGameBase connects its own in _ready(), so this snapshot is taken
		# ahead of the teardown the round starts — which is the only moment the grace window is
		# still observable.
		NetworkManager.server_disconnected.connect(_on_server_disconnected_seen)
		# multiplayer.peer_disconnected arrives BEFORE server_disconnected and before the round's
		# own teardown, so "was it mid-round" can only be answered from there. Connected here, ahead
		# of join_game, so this is the first observer in the process: signals fire in connection
		# order and NetworkManager adopts the peer (and connects its own) inside join_game.
		multiplayer.peer_disconnected.connect(_on_peer_disconnected_seen)
		_check("GameManager.join_game() started a client",
			GameManager.join_game(HOST_IP, PORT), _state())
		var anchored := [false]
		get_tree().create_timer(CONNECT_TIMEOUT).timeout.connect(func() -> void:
			if not anchored[0]:
				_check("connected to the host within %ds" % int(CONNECT_TIMEOUT), false, _state())
				_finish()
		)
		await NetworkManager.connection_succeeded
		anchored[0] = true
		print("  [%s] connected — starting timeline" % role)

		_check("this peer is the client of a co-op session",
			not GameManager.is_host and GameManager.local_player_num == 2
				and int(GameManager.current_game_mode) == MODE_COOP, _state())
		await _eventually("the host's session bootstrap arrived",
			func() -> bool: return GameManager.session_active, 6.0,
			func() -> String: return _state())

		# ── the round ──
		await get_tree().create_timer(1.0).timeout
		game = _spawn(COOP_GAME if coop else BASE_GAME)
		await get_tree().create_timer(1.5).timeout
		if not coop and game.has_method("start_game"):
			game.start_game()
		_quiet(game)
		_check("the %s round is live on the client" % ("co-op-family" if coop else "base-family"),
			bool(game.get("game_active")),
			"%s game_active=%s" % [(COOP_GAME if coop else BASE_GAME).get_file(),
				str(game.get("game_active"))])
		if coop:
			_check("the co-op round listens for NOTHING: its only route out is GameManager's",
				not _game_listens(),
				"%d listener(s) on NetworkManager.server_disconnected, none of them the round"
					% NetworkManager.server_disconnected.get_connections().size())
		else:
			_check("the base round listens for the host's departure itself",
				_game_listens(),
				"%d listener(s) on NetworkManager.server_disconnected"
					% NetworkManager.server_disconnected.get_connections().size())

		# ── score through the production RPC so both slots are populated here too ──
		await get_tree().create_timer(1.0).timeout
		GameManager.rpc("submit_score", CLIENT_POINTS)
		await _eventually("the team's two contributions are both on this replica",
			func() -> bool: return _gm_total() >= HOST_POINTS + CLIENT_POINTS, 8.0,
			func() -> String: return "team total=%d, counter=%s" % [_gm_total(), str(GameManager.g_counter)])

		# ── the host vanishes ──
		var noticed := await _eventually("the client noticed the host's departure",
			func() -> bool: return drop_seen, 25.0,
			func() -> String: return _state())
		if not noticed:
			_check("[!] nothing further can be measured: the departure never arrived", false,
				"the host closes its socket ~%.1fs after the round converges; if that never "
					% DROP_AT + "reaches this peer the run below would assert against a live session")
			_finish()
			return

		# Everything from here is read off the snapshot taken inside the callback, because the
		# teardown that follows erases the evidence within a few frames.
		_check("a reconnect grace window opened, so this really was the involuntary path",
			bool(snap.get("grace_active", false)) and float(snap.get("time_left", 0.0)) > 0.0,
			"grace=%s time_left=%.1fs of %ds"
				% [str(snap.get("grace_active")), float(snap.get("time_left", 0.0)),
				int(GRACE_PERIOD_S)])
		# Anchored on the FIRST observation of the drop, not on server_disconnected. Run 3
		# measured the real order on the client: multiplayer.peer_disconnected arrives first, the
		# base family's own handler for it already ends the round ("Player left session -
		# terminating for all players"), and by the time server_disconnected re-emits, the round's
		# game_active is legitimately false. Reading mid-round off the later snapshot blamed the
		# harness for a product ordering that is correct.
		_check("the departure landed MID-ROUND, not after it",
			bool(first_snap.get("round_live", false)),
			"at first notice (peer_disconnected): round_live=%s | %dms later at server_disconnected: round_live=%s, NM.game_in_progress=%s"
				% [str(first_snap.get("round_live")),
				(drop_at_msec - first_at_msec) if first_at_msec > 0 else -1,
				str(snap.get("round_live")), str(snap.get("game_in_progress"))])
		var snap_total := 0
		for pid in snap.get("counter", {}):
			snap_total += int(snap["counter"][pid])
		_check("the vanishing peer's contribution was NOT erased from this replica",
			snap_total >= HOST_POINTS + CLIENT_POINTS
				and (snap["counter"] as Dictionary).size() >= 2,
			"counter=%s (sum %d, expected >= %d over 2 slots)"
				% [str(snap.get("counter")), snap_total, HOST_POINTS + CLIENT_POINTS])

		# ── the route out ──
		await _eventually("the client leaves the dead round instead of soft-locking in it",
			func() -> bool: return lobby_roots.size() > 0, 12.0,
			func() -> String: return _state())
		# Let the double invocation land if it is going to: the base family routes out from the
		# round AND GameManager routes out from its own handler, and one of the two is deferred.
		await get_tree().create_timer(1.5).timeout

		_check("exactly one lobby was loaded, not one per handler",
			lobby_roots.size() == 1, "%d MultiplayerLobby root(s) entered the tree"
				% lobby_roots.size())
		_check("the dead round was freed, not left running underneath",
			not is_instance_valid(game) and not is_instance_valid(stage),
			"round valid=%s, its scene root valid=%s"
				% [str(is_instance_valid(game)), str(is_instance_valid(stage))])
		var cs := get_tree().current_scene
		_check("the current scene is the multiplayer lobby",
			cs != null and is_instance_valid(cs) and cs.scene_file_path == LOBBY_PATH,
			_state())

		# ── both halves of the session state ──
		_check("NetworkManager's half is clear",
			not NetworkManager.connection_active and not NetworkManager.game_in_progress
				and not NetworkManager.is_host and NetworkManager.players.is_empty(),
			_state())
		_check("no reconnect window is still ticking behind the lobby",
			not NetworkManager.grace_period_active
				and NetworkManager.disconnection_timer.is_stopped(),
			"grace=%s timer_stopped=%s time_left=%.1f"
				% [str(NetworkManager.grace_period_active),
				str(NetworkManager.disconnection_timer.is_stopped()),
				NetworkManager.disconnection_timer.time_left])
		_check("GameManager's half is clear",
			not GameManager.is_multiplayer_connected and not GameManager.session_active
				and GameManager.g_counter.is_empty()
				and GameManager.multiplayer_game_order.is_empty(),
			_state())
		_check("the multiplayer peer was released",
			multiplayer.multiplayer_peer == null, _state())

		# ── is the lobby actually usable? ──
		_check("the tree is not left paused under the lobby",
			not get_tree().paused, "paused=%s" % str(get_tree().paused))
		var mode_panel := _lobby_panel("ModeSelectionPanel")
		var waiting_panel := _lobby_panel("WaitingPanel")
		_check("the lobby offers mode selection instead of a stuck waiting panel",
			mode_panel != null and mode_panel.visible
				and waiting_panel != null and not waiting_panel.visible,
			"mode_selection.visible=%s waiting.visible=%s"
				% [str(mode_panel.visible) if mode_panel else "<missing>",
				str(waiting_panel.visible) if waiting_panel else "<missing>"])
		# What the lobby SAYS is verified in tools/VerifyRoundFlagOnClient.gd, not here. This
		# harness instantiates the round itself, so NetworkManager.game_in_progress is false on
		# this peer, which deliberately gates BOTH client-side producers of the notice: a "round
		# cancelled" line would be a false statement about a round NetworkManager never started.
		# The honest claim available here is therefore the gate itself — the channel stays silent.
		var subtitle := _lobby_panel("SubtitleLabel") as Label
		var notice_text: String = "" if subtitle == null else subtitle.text
		print("  [%s] lobby subtitle after departure: \"%s\"" % [role, notice_text])
		_check("no departure notice is queued for a round NetworkManager never started",
			GameManager.consume_multiplayer_notice().is_empty(),
			"consume_multiplayer_notice() is empty; game_in_progress was false on this peer")
		# Whatever it shows, it must have passed through a translation table on the way.
		_check("the subtitle is a rendered string, never a raw localization key",
			not notice_text.is_empty() and not notice_text.begins_with("notice_")
				and not notice_text.begins_with("subtitle"),
			"SubtitleLabel=\"%s\"" % notice_text)
		_check("no scene transition is left half-finished, so the lobby's buttons still work",
			not GameManager._is_transitioning,
			"_is_transitioning=%s" % str(GameManager._is_transitioning))
		# The state check with teeth: a leaked socket or a half-closed peer makes this fail even
		# when every flag above reads correctly. Fresh port, because re-binding the old one would
		# be testing the OS rather than this peer.
		var rehosted: bool = GameManager.host_game(REHOST_PORT)
		_check("this peer can immediately open a new session",
			rehosted, "host_game(%d)=%s %s" % [REHOST_PORT, str(rehosted), _state()])
		if rehosted:
			GameManager.disconnect_multiplayer()
			await get_tree().process_frame
		_finish()
