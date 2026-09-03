extends Node

## Reconnect grace-period lifecycle: does the 30 s timer belong to the session that
## started it?
##
## THE DEFECT THIS WAS WRITTEN FOR
##   NetworkManager opens a reconnection grace period in exactly one place -
##   _on_server_disconnected() -> _start_grace_period() - which sets
##   grace_period_active = true and starts disconnection_timer (one_shot,
##   wait_time = RECONNECT_GRACE_PERIOD = 30.0). Before the fix, the text
##   "disconnection_timer.stop()" did not appear anywhere in the file, and
##   grace_period_active was cleared in exactly one place: inside the timeout
##   handler of that same timer. So once started, the window ALWAYS ran its full
##   30 s and ALWAYS fired, no matter what became of the session meanwhile.
##
##   Three consequences, all of them cross-session state leaks:
##
##   (a) CONTAMINATION. The abrupt-disconnect path on the client leaves for the
##       lobby immediately (MultiplayerMiniGameBase._on_server_disconnected ->
##       GameManager.return_to_multiplayer_lobby -> disconnect_multiplayer). That
##       teardown resets nine fields and none of them is the timer. Host or join a
##       new session inside 30 s - which is all it takes to press HOST on the lobby
##       screen you were just dropped onto - and the stale timeout fires into the
##       healthy new session and runs "if game_in_progress: game_in_progress =
##       false". The new round is silently marked not-in-progress.
##
##   (b) A SUCCESSFUL RECONNECT STILL FIRED THE FAILURE. Neither
##       _on_connected_to_server() (client side) nor _on_player_connected() (host
##       side) cancelled the window, so a peer that came back at t=5s still had its
##       round torn down at t=30s by the very timer that was waiting for it. That
##       is the one case a grace period exists to serve.
##
##   (c) A LATCHED FLAG. Because grace_period_active was cleared only by the
##       timeout, a second disconnect inside the window hit the guard
##       "if grace_period_active: return" at the top of _start_grace_period() and
##       got NO window of its own - it inherited whatever was left of the first
##       one, anchored to a disconnect belonging to a session already dead.
##
## HOW IT IS DRIVEN, AND WHY THAT IS HONEST
##   No second process. The defect lives entirely inside the flag and timer
##   bookkeeping of NetworkManager, and every trigger is a handler that ENet itself
##   invokes by signal - _on_server_disconnected(), _on_connected_to_server(),
##   _on_player_connected() - so calling them directly runs the same code the same
##   way. _sender_owns() accepts a local call (sender == 0), which is what makes
##   the host-side path reachable in-process.
##
##   TIME IS COMPRESSED, NOT FAKED. Cases that need the timeout to actually arrive
##   set disconnection_timer.wait_time to a fraction of a second BEFORE the window
##   opens, then await the real timeout of the real Timer, which runs the real
##   _on_grace_period_timeout(). Only the duration changes; the mechanism is
##   untouched. Cases that measure the WINDOW LENGTH restore the true 30.0 first,
##   because that number is the thing they assert on.
##
## Usage:
##   godot --headless --path . res://tools/VerifyGracePeriodLifecycle.tscn

var _pass: int = 0
var _fail: int = 0

## Timeouts observed by this probe, independently of NetworkManager. Connected
## AFTER the handler of NetworkManager (wired at line ~107), so by the time this
## runs the handler has already had its effect and the state is observable.
var _timeouts_seen: int = 0


func _nm() -> Node:
	return get_node_or_null("/root/NetworkManager")


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


func _state(nm: Node) -> String:
	var t: Timer = nm.disconnection_timer
	return ("grace=%s timer_stopped=%s time_left=%.2f game_in_progress=%s "
		+ "connection_active=%s timeouts_seen=%d") % [
			str(nm.grace_period_active), str(t.is_stopped()), t.time_left,
			str(nm.game_in_progress), str(nm.connection_active), _timeouts_seen]


## Put NetworkManager back to a known-clean state between cases.
##
## This is fixture setup, not part of anything under test: it writes the fields
## directly rather than going through a production path, precisely so that a case
## which then FAILS cannot be blamed on residue from the case before it.
func _reset(nm: Node) -> void:
	nm.disconnection_timer.stop()
	nm.disconnection_timer.wait_time = nm.RECONNECT_GRACE_PERIOD
	nm.grace_period_active = false
	nm.game_in_progress = false
	nm.connection_active = false
	nm.is_host = false
	nm.network = null
	nm.players.clear()
	_timeouts_seen = 0


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _on_timer_fired() -> void:
	_timeouts_seen += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== RECONNECT GRACE-PERIOD LIFECYCLE ===")
	var nm := _nm()
	if nm == null:
		print("  FAIL: NetworkManager autoload missing")
		get_tree().quit(1)
		return
	if nm.disconnection_timer == null:
		print("  FAIL: disconnection_timer was never created")
		get_tree().quit(1)
		return
	nm.disconnection_timer.timeout.connect(_on_timer_fired)
	print("  RECONNECT_GRACE_PERIOD = %.1fs, timer one_shot = %s"
		% [nm.RECONNECT_GRACE_PERIOD, str(nm.disconnection_timer.one_shot)])
	print("")
	# CASE 1: baseline. An abrupt server disconnect opens a real window.
	# If this fails nothing below means anything, so it is asserted, not assumed.
	print("  [1] abrupt server disconnect starts the grace period")
	_reset(nm)
	nm.connection_active = true
	nm.game_in_progress = true
	nm._on_server_disconnected()
	await _frames(2)
	_check("grace period is active", nm.grace_period_active, _state(nm))
	_check("timer is running", not nm.disconnection_timer.is_stopped(), _state(nm))
	_check("window is the full %.0fs" % nm.RECONNECT_GRACE_PERIOD,
		nm.disconnection_timer.time_left > nm.RECONNECT_GRACE_PERIOD - 1.0, _state(nm))

	# CASE 2: the teardown that follows it must cancel it.
	print("  [2] disconnect_multiplayer() cancels the window it left behind")
	nm.disconnect_multiplayer()
	await _frames(2)
	_check("teardown cleared grace_period_active", not nm.grace_period_active, _state(nm))
	_check("teardown stopped the timer", nm.disconnection_timer.is_stopped(), _state(nm))

	# CASE 3: the consequence. A stale window must not touch session 2.
	print("  [3] a stale window cannot clear game_in_progress on a NEW session")
	_reset(nm)
	nm.connection_active = true
	nm.game_in_progress = true
	# Compressed so the timeout actually arrives inside this probe. See header.
	nm.disconnection_timer.wait_time = 0.4
	nm._on_server_disconnected()
	await _frames(2)
	nm.disconnect_multiplayer()
	# Session 2 begins, well inside the old window.
	nm.connection_active = true
	nm.game_in_progress = true
	nm.is_host = true
	await get_tree().create_timer(0.9).timeout
	_check("no stale timeout fired at all", _timeouts_seen == 0, _state(nm))
	_check("session 2 still has game_in_progress = true", nm.game_in_progress, _state(nm))

	# CASE 4: a second disconnect gets its OWN full window.
	print("  [4] a later disconnect gets a FULL window, not the remainder")
	_reset(nm)
	nm.connection_active = true
	nm.game_in_progress = true
	nm._on_server_disconnected()
	await get_tree().create_timer(1.2).timeout
	var burned: float = nm.RECONNECT_GRACE_PERIOD - nm.disconnection_timer.time_left
	nm.disconnect_multiplayer()
	nm.connection_active = true
	nm.game_in_progress = true
	nm._on_server_disconnected()
	await _frames(2)
	_check("the window of session 2 is fresh, not the remainder of session 1",
		nm.disconnection_timer.time_left > nm.RECONNECT_GRACE_PERIOD - 0.6,
		"%s (session 1 had burned %.2fs)" % [_state(nm), burned])

	# CASE 5: a client that comes back cancels its own window.
	print("  [5] a successful client reconnect cancels the grace period")
	_reset(nm)
	nm.connection_active = true
	nm.game_in_progress = true
	nm._on_server_disconnected()
	await _frames(2)
	# _on_connected_to_server() calls multiplayer.get_unique_id() and rpc_id(1, ...).
	# Both need an assigned peer. In production there always is one by the time this
	# handler runs, and driving it without one produced two engine errors that were
	# artefacts of this harness rather than defects, so a real local ENet peer is
	# opened here and the handler runs intact.
	#
	# ONE artefact remains and is left visible rather than silenced: the handler then
	# calls rpc_id(1, "_register_player", ...), and because this probe peer IS peer 1
	# that is an any_peer RPC aimed at itself, which Godot rejects with "on yourself is
	# not allowed by selected mode". A real client is peer 2 or higher and rpc_id(1)
	# reaches the host, so production cannot hit it. The cancel under test happens
	# before that line, so the assertion below is unaffected.
	var probe_peer := ENetMultiplayerPeer.new()
	var perr: int = probe_peer.create_server(47771, 2)
	if perr != OK:
		print("          (probe peer could not be opened, err %d)" % perr)
	else:
		multiplayer.multiplayer_peer = probe_peer
	nm._on_connected_to_server()
	await _frames(2)
	_check("reconnect cleared grace_period_active", not nm.grace_period_active, _state(nm))
	_check("reconnect stopped the timer", nm.disconnection_timer.is_stopped(), _state(nm))
	# Closed again so the remaining cases run with the same bare-autoload conditions
	# as the ones before it.
	multiplayer.multiplayer_peer = null
	probe_peer.close()
	await _frames(2)

	# CASE 6: the host side, when the partner comes back.
	print("  [6] a peer rejoining cancels the grace period on the host")
	_reset(nm)
	nm.connection_active = true
	nm.game_in_progress = true
	nm.is_host = true
	nm._on_server_disconnected()
	await _frames(2)
	nm._on_player_connected(77)
	await _frames(2)
	_check("rejoin cleared grace_period_active", not nm.grace_period_active, _state(nm))
	_check("rejoin stopped the timer", nm.disconnection_timer.is_stopped(), _state(nm))

	# CASE 7: the fix must not turn the grace period into a no-op.
	# A window nobody cancels still has to expire and still has to resolve the
	# round. Without this case, "never start the timer" would pass cases 2 to 6.
	print("  [7] an UNcancelled window still expires and still resolves the round")
	_reset(nm)
	nm.connection_active = true
	nm.game_in_progress = true
	nm.disconnection_timer.wait_time = 0.4
	nm._on_server_disconnected()
	await get_tree().create_timer(0.9).timeout
	_check("the timeout did fire", _timeouts_seen == 1, _state(nm))
	_check("expiry cleared grace_period_active", not nm.grace_period_active, _state(nm))
	_check("expiry cleared game_in_progress", not nm.game_in_progress, _state(nm))

	_reset(nm)
	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	print("")
	get_tree().quit(1 if _fail > 0 else 0)
