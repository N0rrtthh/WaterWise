extends Node

## ═══════════════════════════════════════════════════════════════════
## TWO-PROCESS RETURN-TO-LOBBY / HOST-DEPARTURE HARNESS
## ═══════════════════════════════════════════════════════════════════
## NetworkManager.return_to_lobby() is the ONLY way out of a multiplayer round:
## every one of the five MP minigames calls it (MiniGame_BucketBrigade:481,573,
## MiniGame_GreywaterSort:669, MiniGame_LeafSort:734, MiniGame_Rain:1052,
## MiniGame_WaterHarvest:742), and so do MultiplayerCoordinator:180,
## MultiplayerMiniGameBase:1324 and the MultiplayerGameOver screen:97. Both a host
## and a client can press it. Nothing in this project had ever executed it at
## runtime, so the whole "host leaves / client leaves / session resets" branch of
## the directive's REQUIRED multiplayer testing was unmeasured.
##
## The first thing this harness measured is an ORDERING risk inside
##
##     @rpc("authority", "call_local", "reliable")
##     func _execute_return_to_lobby() -> void:
##         ...
##         get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
##         call_deferred("disconnect_multiplayer")
##
## The reliable RPC is queued into the ENet peer by rpc(); disconnect_multiplayer()
## calls network.close(), and ENetMultiplayerPeer::close() disconnects each peer
## with enet_peer_disconnect_now(), whose first act is enet_peer_reset_queues() —
## it DISCARDS everything still queued. Both happen in the same frame, so if the
## teardown won, the client would never be told to leave; it would fall through to
## _on_server_disconnected() -> _start_grace_period() and sit in the finished
## minigame for RECONNECT_GRACE_PERIOD = 30 s, after which
## _on_grace_period_timeout() only clears game_in_progress and does nothing else
## (its own body says "# Trigger game failure (implement in game scene)").
##
## MEASURED: it does NOT lose the race. With the teardown deferred, the client
## lands in the lobby on both routes (see check 3 below). That is why the deferral
## is documented as load-bearing at the call site — moving the teardown ahead of
## the scene change, or calling it directly, would reintroduce the discard. This
## harness is the regression test that keeps that ordering honest.
##
## What it DID find: the teardown cleared only NetworkManager's half of the
## session. GameManager still reported is_multiplayer_connected = true, is_host =
## true, a live peer, session_active = true and the finished session's shuffled
## multiplayer_game_order at its old index — and get_next_multiplayer_game()
## reshuffles only when that order is empty or exhausted (GameManager.gd:1041), so
## the next hosted session resumed the previous one's shuffle mid-way. Fixed by
## deferring to GameManager.disconnect_multiplayer(), which calls
## NetworkManager's and clears its own mirror; the same pairing
## MultiplayerLobby._on_disconnect_pressed() already used.
##
## Run BOTH scenarios (host first in each pair; it binds the port):
##   host-initiated:
##     godot --headless --path . res://tools/VerifyReturnToLobby.tscn -- host hostreturn
##     godot --headless --path . res://tools/VerifyReturnToLobby.tscn -- client hostreturn
##   client-initiated (exercises _request_return_to_lobby):
##     godot --headless --path . res://tools/VerifyReturnToLobby.tscn -- host clientreturn
##     godot --headless --path . res://tools/VerifyReturnToLobby.tscn -- client clientreturn
##
## Verifies, from the side that can actually see it:
##   1. A CLIENT cannot execute _execute_return_to_lobby on the host (authority).
##      The client's own probe is also shown to be locally inert, so "the host
##      stayed put" cannot be a false pass from the call never being made.
##   2. The host reaches the lobby (positive control for check 1: the same call
##      IS honoured on the legitimate route, so check 1 is a narrowed permission
##      and not a dead code path).
##   3. THE CLIENT reaches the lobby — i.e. the reliable RPC survived the peer
##      teardown that happens in the same frame.
##   4. The client is NOT left on the 30 s reconnect grace period.
##   5. Both sides clear game_in_progress and tear the connection down, and
##      GameManager's mirror is cleared too — including the finished session's
##      minigame order and index, which are armed to mid-session values first so
##      the assertion is not vacuous.
##
## Expect ONE Godot error on the host in each run:
##   "RPC '_execute_return_to_lobby' is not allowed on ... from: 2. Mode is 'Authority'"
## That error IS check 1 passing — it is Godot rejecting the client's probe.

const HOST_IP: String = "127.0.0.1"
## Neither 7777 (VerifyMultiplayer) nor 7778 (VerifyMultiplayerReconnect): a
## lingering socket from an aborted run of either would fail this harness's bind
## for a reason that has nothing to do with what it measures. The two scenarios
## also take separate ports, because scenario 1 deliberately ends with both
## processes closing a server socket.
const PORT_HOST_RETURN: int = 7781
const PORT_CLIENT_RETURN: int = 7782
const HOST_PEER_ID: int = 1
const CONNECT_TIMEOUT: float = 20.0
const LOBBY_PATH: String = "res://scenes/ui/MultiplayerLobby.tscn"

var role: String = "host"
var scenario: String = "hostreturn"
var results: Array = []

## Set on the twin only. See _ready().
var _detached: bool = false


func _ready() -> void:
	if not _detached:
		# This node IS the tool scene, i.e. get_tree().current_scene — and the code
		# path under test ends in change_scene_to_file(), which memdeletes
		# current_scene. Every assertion after that point would run on a freed
		# object. So the timeline lives on a twin parented straight to /root, which
		# a scene change leaves alone.
		var twin: Node = (get_script() as GDScript).new()
		twin.set("_detached", true)
		twin.name = "ReturnToLobbyProbe"
		# Deferred: /root is still "busy setting up children" while the tool scene's
		# own _ready() runs, and a direct add_child() there fails outright
		# ("Parent node is busy setting up children") — which left the twin never
		# added, no timeline, and a headless run that hung until the outer timeout.
		get_tree().root.add_child.call_deferred(twin)
		return
	_boot()


func _boot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "client":
			role = "client"
		elif arg == "host":
			role = "host"
		elif arg == "clientreturn":
			scenario = "clientreturn"
		elif arg == "hostreturn":
			scenario = "hostreturn"
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RETURN-TO-LOBBY HARNESS — role: %s  scenario: %s" % [role, scenario])
	print("  port: %d   initiator: %s" % [_port(),
		"host" if scenario == "hostreturn" else "client"])
	print("═══════════════════════════════════════════════════════════")
	if role == "host":
		_run_host()
	else:
		_run_client()


func _port() -> int:
	return PORT_HOST_RETURN if scenario == "hostreturn" else PORT_CLIENT_RETURN

# ── tally ───────────────────────────────────────────────────────────

func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _finish() -> void:
	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  %s/%s RESULT: %d passed, %d failed"
		% [role.to_upper(), scenario, results.size() - failed, failed])
	if failed > 0:
		for r in results:
			if not r["ok"]:
				print("    ✗ %s" % r["label"])
	print("═══════════════════════════════════════════════════════════")
	print("")
	Engine.get_main_loop().quit(1 if failed > 0 else 0)


## Poll a condition the OTHER process has to make true. Two processes boot 23
## autoloads at their own pace and anchor on their own connection events, so a
## fixed-instant assertion on a cross-process fact is a coin flip on skew. Used
## only for POSITIVE facts; the negative assertions below are deliberately
## sampled at a fixed instant, because polling "still absent" would pass on the
## first sample whether or not the message was ever sent.
func _eventually(label: String, cond: Callable, timeout_s: float = 3.0,
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
	_check(label, ok, text)

# ── observation helpers ─────────────────────────────────────────────

## The scene the process is actually sitting in. This is the observable that
## separates "was told to leave the round" from "lost the socket": only
## _execute_return_to_lobby changes it.
func _scene_path() -> String:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return "<null>"
	return tree.current_scene.scene_file_path


func _in_lobby() -> bool:
	return _scene_path() == LOBBY_PATH


func _state_line() -> String:
	return ("scene=%s game_in_progress=%s connection_active=%s grace=%s "
		+ "gm_connected=%s gm_host=%s") % [
			_scene_path(),
			str(NetworkManager.game_in_progress),
			str(NetworkManager.connection_active),
			str(NetworkManager.grace_period_active),
			str(GameManager.is_multiplayer_connected),
			str(GameManager.is_host)]

# ── HOST ────────────────────────────────────────────────────────────

func _run_host() -> void:
	var tree := get_tree()
	# The real game path: MultiplayerLobby._on_host_pressed calls
	# GameManager.host_game(), which adopts the peer into NetworkManager. Calling
	# NetworkManager.create_server() directly would skip GameManager's own
	# bookkeeping, and GameManager's state is part of what check 5 reads.
	_check("GameManager.host_game() succeeded", GameManager.host_game(_port()))

	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(
		_bail_unless.bind(anchored, "client connected within %ds" % int(CONNECT_TIMEOUT)))
	var client_id: int = await multiplayer.peer_connected
	anchored[0] = true
	print("  [host] client %d connected — starting timeline" % client_id)

	# ── t=1.0  model a round in progress, which is the state return_to_lobby
	#           exists to leave. Set directly rather than by starting a real
	#           round: this harness is about the exit path, and a real round
	#           would drag scenario selection and the countdown in with it.
	tree.create_timer(1.0).timeout.connect(_host_arm)

	# ── t=3.0  the client fired its authority probe at its t=2.0 ──
	tree.create_timer(3.0).timeout.connect(_host_assert_authority)

	# ── t=5.0  host-initiated exit (the other scenario lets the client ask) ──
	if scenario == "hostreturn":
		tree.create_timer(5.0).timeout.connect(_host_return)

	# ── t=8.0  where did this process end up? ──
	tree.create_timer(8.0).timeout.connect(_host_assert_landed)

	# 14 s, not 10: _host_assert_landed polls for up to 5 s, and a finisher firing
	# mid-poll would quit while an assertion it is tallying is still outstanding.
	tree.create_timer(14.0).timeout.connect(_finish)


func _bail_unless(anchored: Array, label: String) -> void:
	if anchored[0]:
		return
	_check(label, false)
	_finish()


func _host_arm() -> void:
	NetworkManager.game_in_progress = true
	_arm_session_remnants()
	print("  [host] armed: %s" % _state_line())


## Leave behind exactly the state a mid-session round leaves in GameManager, so the
## teardown assertion is not vacuous. Set directly rather than by playing a round:
## get_next_multiplayer_game() loads the minigame scene as its last act, so calling
## it would replace the harness with a minigame instead of populating state.
## The index matters — get_next_multiplayer_game() reshuffles ONLY when
## multiplayer_game_order is empty or the index has run past the end
## (GameManager.gd:1041), so a surviving mid-order index makes the NEXT session
## resume the previous session's shuffle.
func _arm_session_remnants() -> void:
	GameManager.session_active = true
	GameManager.multiplayer_game_order = ["MiniGame_Rain", "MiniGame_LeafSort",
		"MiniGame_BucketBrigade"]
	GameManager.multiplayer_game_index = 1
	GameManager.current_multiplayer_game_name = "MiniGame_LeafSort"


func _host_assert_authority() -> void:
	# Fixed instant, and a NEGATIVE assertion: the client sent
	# rpc_id(1, "_execute_return_to_lobby") at its t=2.0 and Godot must refuse it,
	# because the method is @rpc("authority") and a client is not the authority of
	# an autoload. If it were honoured, any client could yank the whole team out of
	# a round mid-play. The positive control is _host_assert_landed below: the same
	# call on the legitimate route DOES move this process to the lobby.
	_check("a CLIENT cannot execute _execute_return_to_lobby on the host",
		NetworkManager.game_in_progress and not _in_lobby(),
		_state_line())


func _host_return() -> void:
	print("  [host] calling NetworkManager.return_to_lobby()")
	NetworkManager.return_to_lobby()


func _host_assert_landed() -> void:
	await _eventually("host reached the lobby (positive control for authority)",
		_in_lobby, 5.0, _state_line)
	_check("host cleared game_in_progress", not NetworkManager.game_in_progress,
		_state_line())
	_check("host tore down its NetworkManager connection",
		not NetworkManager.connection_active, _state_line())
	# GameManager is what the lobby UI reads: _is_connected() is
	# GameManager.is_multiplayer_connected and _is_host() is GameManager.is_host.
	# NetworkManager.disconnect_multiplayer() clears only NetworkManager's copies,
	# so a stale mirror here leaves the lobby believing a session is still up.
	_check("GameManager's mirror of the session was cleared",
		not GameManager.is_multiplayer_connected and not GameManager.is_host,
		_state_line())
	_check("the finished session's minigame order did not survive into the lobby",
		GameManager.multiplayer_game_order.is_empty()
			and GameManager.multiplayer_game_index == 0
			and not GameManager.session_active,
		"order=%s index=%d session_active=%s" % [
			str(GameManager.multiplayer_game_order),
			GameManager.multiplayer_game_index,
			str(GameManager.session_active)])

# ── CLIENT ──────────────────────────────────────────────────────────

func _run_client() -> void:
	var tree := get_tree()
	_check("GameManager.join_game() succeeded",
		GameManager.join_game(HOST_IP, _port()))

	var anchored := [false]
	tree.create_timer(CONNECT_TIMEOUT).timeout.connect(
		_bail_unless.bind(anchored, "connected to host within %ds" % int(CONNECT_TIMEOUT)))
	await multiplayer.connected_to_server
	anchored[0] = true
	print("  [client] connected as peer %d — starting timeline"
		% multiplayer.get_unique_id())

	tree.create_timer(1.0).timeout.connect(_client_arm)
	tree.create_timer(2.0).timeout.connect(_client_probe_authority)
	tree.create_timer(4.0).timeout.connect(_client_assert_probe_inert)
	if scenario == "clientreturn":
		tree.create_timer(5.0).timeout.connect(_client_return)
	tree.create_timer(8.0).timeout.connect(_client_assert_landed)
	tree.create_timer(16.0).timeout.connect(_finish)


func _client_arm() -> void:
	NetworkManager.game_in_progress = true
	_arm_session_remnants()
	print("  [client] armed: %s" % _state_line())


func _client_probe_authority() -> void:
	if not GameManager.is_multiplayer_connected:
		_check("client was connected to probe _execute_return_to_lobby", false)
		return
	NetworkManager.rpc_id(HOST_PEER_ID, "_execute_return_to_lobby")
	print("  [client] sent _execute_return_to_lobby to the host (must be refused)")


func _client_assert_probe_inert() -> void:
	# Control for the host's negative assertion: rpc_id() has no call_local, so the
	# probe must not have moved THIS process either. If it had, "the host stayed
	# put" could be read as the call never having been made at all.
	_check("the client's own probe was locally inert (rpc_id, no call_local)",
		not _in_lobby(), _state_line())


func _client_return() -> void:
	# Client route: return_to_lobby() -> rpc_id(1, "_request_return_to_lobby"),
	# which the host honours only while is_host, then re-broadcasts downward.
	print("  [client] calling NetworkManager.return_to_lobby()")
	NetworkManager.return_to_lobby()


func _client_assert_landed() -> void:
	# THE assertion this harness was written for. 5 s is far longer than a
	# localhost reliable RPC needs; the failure mode is not slowness, it is the
	# packet being discarded by enet_peer_reset_queues() when the host closes its
	# peer in the same frame.
	await _eventually("the return-to-lobby RPC actually reached the client",
		_in_lobby, 5.0, _state_line)
	_check("the client was NOT left on the %ds reconnect grace period"
			% int(NetworkManager.RECONNECT_GRACE_PERIOD),
		not NetworkManager.grace_period_active, _state_line())
	_check("the client cleared game_in_progress",
		not NetworkManager.game_in_progress, _state_line())
	_check("the client tore down its NetworkManager connection",
		not NetworkManager.connection_active, _state_line())
	_check("GameManager's mirror of the session was cleared on the client",
		not GameManager.is_multiplayer_connected and not GameManager.is_host,
		_state_line())
	_check("the finished session's minigame order did not survive on the client",
		GameManager.multiplayer_game_order.is_empty()
			and GameManager.multiplayer_game_index == 0
			and not GameManager.session_active,
		"order=%s index=%d session_active=%s" % [
			str(GameManager.multiplayer_game_order),
			GameManager.multiplayer_game_index,
			str(GameManager.session_active)])
