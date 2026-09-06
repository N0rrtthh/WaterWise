extends Node

## ═══════════════════════════════════════════════════════════════════
## NETWORK MANAGER - WATERWISE LAN MULTIPLAYER
## ═══════════════════════════════════════════════════════════════════
## Local Area Network (LAN) peer-to-peer multiplayer system
## Supports 2 players maximum for cooperative water conservation gameplay
## Uses Godot's high-level NetworkedMultiplayerENet API
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal player_connected(peer_id: int, player_num: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()
## The reconnection window closed with the peer still absent. Distinct from
## server_disconnected, which fires the instant the link drops: this one means the
## grace period is over and the round cannot be resumed. See _cancel_grace_period().
signal reconnect_failed()
## A live round has been frozen because a peer dropped, and is being held open for
## `seconds` while that peer is given a chance to come back. The round scene shows the
## overlay and pauses the tree; the clock and the retries live here.
signal reconnect_hold_started(seconds: float)
## The hold closed. `rejoined` true means the peer is back and the round resumes;
## false means the round is over and the scene routes out as it always did.
signal reconnect_hold_ended(rejoined: bool)
signal both_players_ready()
signal player_ready_changed(peer_id: int, ready: bool)
signal game_started(scenario_id: String, roles: Dictionary)
signal performance_data_received(player_id: int, performance: Dictionary)
signal game_state_synced(state: Dictionary)
signal team_score_updated(total_score: int)
signal team_lives_updated(remaining_lives: int)
signal round_starting(countdown: int)
signal round_completed(p1_score: int, p2_score: int, team_total: int)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const DEFAULT_PORT: int = 7777  # UDP Port 7777 (Paper: P2P UDP Port 7777)
const MAX_PLAYERS: int = 2
## Seconds each of the 3-2-1 numbers stays on screen before the next one is broadcast.
## Was a bare 1.0 here, which with the 1.0 s hold on GO in MultiplayerMiniGameBase put four
## unconditional seconds between "both players tapped" and a playable round - 24 s across a
## six-round set, on top of two scene loads and two instruction screens. 0.6 s still shows
## each number for half a second longer than the 0.4 s scale animation that draws it, so the
## countdown is quicker to read rather than skipped. Host-paced: only the host chains the
## next tick, so this value alone sets the cadence both peers see.
const COUNTDOWN_TICK_SECONDS: float = 0.6
const RECONNECT_GRACE_PERIOD: float = 30.0  # 30 seconds
## How long a LIVE ROUND is held open for a peer that just dropped, before the round is
## resolved the way it always was (notice + lobby). Deliberately far shorter than the
## grace window above, which serves a peer rejoining from the lobby: a player staring at
## a frozen round needs an answer quickly, and tools/VerifyHostDeparture.tscn asserts the
## client is out of a dead round within 12 s, so the hold plus one scene load must fit
## inside that.
const RECONNECT_HOLD_SECONDS: float = 6.0
## Spacing of the client's rejoin attempts inside the hold: four tries, at 0.0 s (issued
## immediately), 1.5 s, 3.0 s and 4.5 s.
const RECONNECT_RETRY_INTERVAL: float = 1.5

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var network: ENetMultiplayerPeer = null
var is_host: bool = false
var local_player_id: int = 0
var remote_player_id: int = 0

# Player data
var players: Dictionary = {}  # {peer_id: {player_num: int, ready: bool, name: String}}
var player_roles: Dictionary = {}  # {1: "Collector", 2: "User"}

# Connection state
var connection_active: bool = false
var disconnection_timer: Timer = null
var grace_period_active: bool = false

# In-round reconnect hold. Distinct from the grace window above: this one freezes a
# round that is still on screen, the other one keeps a finished-with session claimable
# from the lobby.
var reconnect_hold_active: bool = false
var _reconnect_hold_timer: Timer = null
var _reconnect_retry_timer: Timer = null
var _reconnect_hold_as_host: bool = false
## The address this peer last joined, so a dropped client can dial the same host again.
## join_server() used to take these as arguments and forget them, which is why in-round
## reconnect could not be implemented without them.
var _last_join_ip: String = ""
var _last_join_port: int = DEFAULT_PORT

# Game session
var current_scenario_id: String = ""
var game_in_progress: bool = false
var _ready_signal_emitted: bool = false

## True from the moment start_countdown() puts a 3-2-1 chain on the wire until the
## next _reset_round_status(). Two independent callers ask for the round's countdown
## — _check_all_players_ready() on the normal "both ready" route, and
## MultiplayerMiniGameBase's 6 s "partner ready timeout" fallback — and only the
## first was guarded (`if _ready_signal_emitted: return`). The fallback's own guard
## is `if not game_active`, which cannot help, because game_active turns true a full
## second AFTER the GO tick (_on_countdown_tick(0) awaits 1.0 s before calling
## _on_countdown_complete()); a countdown that began 2–6 s after the host dismissed
## instructions has not reached start_game() when the fallback checks. Measured: the
## partner becoming ready inside that window produced two overlapping chains, 8
## round_starting emissions, two GO ticks, two start_game() calls and two live
## ui_timer children on the round node. tools/VerifyCountdownOnce.tscn locks this in.
var _countdown_started_this_round: bool = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# G-COUNTER CRDT (Conflict-Free Replicated Data Type)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Each peer maintains their own counter, global score = sum of all counters
# Grow-only property: counters only increment, never decrement
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var g_counter: Dictionary = {}  # {peer_id: local_count}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SHARED STATE (Team Lives, Score)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var team_lives: int = 3  # Shared life pool (only host has authority)
const MAX_TEAM_LIVES: int = 5
const START_TEAM_LIVES: int = 3
var rounds_survived: int = 0

# Session-cumulative per-player score accumulators (persist across rounds).
# Reset when a new multiplayer session starts.
var mp_session_p1_score: int = 0
var mp_session_p2_score: int = 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	# Setup disconnection grace period timer
	disconnection_timer = Timer.new()
	disconnection_timer.wait_time = RECONNECT_GRACE_PERIOD
	disconnection_timer.one_shot = true
	disconnection_timer.timeout.connect(_on_grace_period_timeout)
	add_child(disconnection_timer)

	# Both hold timers run while the tree is PAUSED, because the round scene pauses the
	# tree for the duration of the hold. A timer left on the inherited process mode
	# would freeze with it and the hold would never end.
	_reconnect_hold_timer = Timer.new()
	_reconnect_hold_timer.wait_time = RECONNECT_HOLD_SECONDS
	_reconnect_hold_timer.one_shot = true
	_reconnect_hold_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_reconnect_hold_timer.timeout.connect(_on_reconnect_hold_timeout)
	add_child(_reconnect_hold_timer)

	_reconnect_retry_timer = Timer.new()
	_reconnect_retry_timer.wait_time = RECONNECT_RETRY_INTERVAL
	_reconnect_retry_timer.one_shot = false
	_reconnect_retry_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_reconnect_retry_timer.timeout.connect(_attempt_rejoin)
	add_child(_reconnect_retry_timer)
	
	_log("NetworkManager initialized")

## Adopt a peer somebody else created, and remember where it dialled.
##
## `ip`/`port` are not decoration. GameManager.join_game() is the ONLY join path the
## shipped UI uses (scenes/ui/MultiplayerLobby.gd:394 and scenes/ui/DebugMultiplayer.gd:92
## both call it), and it builds its own ENetMultiplayerPeer and hands it here -
## join_server(), the function that used to be the only place _last_join_ip was written,
## is never reached in production. So without these two arguments _attempt_rejoin() read
## an empty _last_join_ip and returned on its first line, and the client half of the
## in-round reconnect was unreachable code in the real game while still passing any test
## that drove NetworkManager directly. Measured with tools/VerifyInRoundReconnect.tscn:
## the client logged no rejoin attempt at all and the host's hold expired as
## `ends=[false]`.
func adopt_existing_peer(as_host: bool, ip: String = "", port: int = 0) -> bool:
	# Adopt an already-created multiplayer peer (e.g. from GameManager).
	var existing_peer = multiplayer.multiplayer_peer
	if existing_peer == null:
		_log("⚠️ No existing multiplayer peer to adopt")
		return false

	if network == existing_peer and connection_active:
		return true

	network = existing_peer
	is_host = as_host
	local_player_id = 1 if as_host else 2
	if not as_host and ip != "":
		_last_join_ip = ip
		_last_join_port = port if port > 0 else DEFAULT_PORT

	# Server is active immediately; client will flip on connect signal.
	if not as_host and network.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		connection_active = true
	else:
		connection_active = as_host

	remote_player_id = 0
	_ready_signal_emitted = false
	_countdown_started_this_round = false

	# Ensure multiplayer signals are connected.
	if not multiplayer.peer_connected.is_connected(_on_player_connected):
		multiplayer.peer_connected.connect(_on_player_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_player_disconnected):
		multiplayer.peer_disconnected.connect(_on_player_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Bootstrap local player entry (skip if peer id is not assigned yet).
	players.clear()
	var my_peer_id = multiplayer.get_unique_id()
	if my_peer_id > 0:
		var my_label = "Player 1 (Host)" if as_host else "Player 2 (Client)"
		players[my_peer_id] = {
			"player_num": local_player_id,
			"ready": false,
			"name": my_label
		}

		# If peers are already connected, register them locally.
		for peer_id in multiplayer.get_peers():
			if peer_id == my_peer_id:
				continue
			var other_num = 2 if local_player_id == 1 else 1
			players[peer_id] = {
				"player_num": other_num,
				"ready": false,
				"name": "Player %d" % other_num
			}
			remote_player_id = peer_id

		if not g_counter.has(my_peer_id):
			g_counter[my_peer_id] = 0

	if player_roles.is_empty():
		player_roles = {1: "Collector", 2: "User"}

	_log("🔄 Adopted existing multiplayer peer")
	return true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HOST/SERVER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func create_server(port: int = DEFAULT_PORT) -> bool:
	# Create a server (host) for LAN multiplayer
	if connection_active:
		_log("❌ Server already running or connected to another server")
		return false
	
	# Create ENet peer
	network = ENetMultiplayerPeer.new()
	
	# Validate port range
	if port < 1024 or port > 65535:
		_log("❌ Invalid port: %d (must be 1024-65535)" % port)
		connection_failed.emit()
		return false
	
	# Create server with proper parameters
	_log("🔧 Attempting to create server on port %d..." % port)
	var error = network.create_server(port, MAX_PLAYERS - 1)  # -1 because host counts as one player
	
	if error != OK:
		_log("❌ Failed to create server on port %d: %s" % [port, error_string(error)])
		_log("   Possible causes:")
		_log("   - Port %d is already in use by another application" % port)
		_log("   - Firewall is blocking the connection")
		_log("   - ENet module not properly initialized")
		_log("   Try port 8888 or 9999 instead")
		connection_failed.emit()
		network = null
		return false
	
	# Verify network peer was created successfully
	var peer_connected = (
		network != null
		and network.get_connection_status()
		== MultiplayerPeer.CONNECTION_CONNECTED)
	if not peer_connected:
		_log("❌ Network peer creation failed - peer is null or not connected")
		connection_failed.emit()
		network = null
		return false
	
	multiplayer.multiplayer_peer = network
	is_host = true
	connection_active = true
	local_player_id = 1
	
	# Register host as Player 1
	players[multiplayer.get_unique_id()] = {
		"player_num": 1,
		"ready": false,
		"name": "Player 1 (Host)"
	}
	
	# Connect multiplayer signals
	if not multiplayer.peer_connected.is_connected(_on_player_connected):
		multiplayer.peer_connected.connect(_on_player_connected)
	
	if not multiplayer.peer_disconnected.is_connected(_on_player_disconnected):
		multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	_log("✅ Server created on port " + str(port))
	_log("🎮 You are Player 1 (Collector)")
	connection_succeeded.emit()
	return true

func set_local_player_ready() -> void:
	# Mark local player as ready and sync
	var my_id = multiplayer.get_unique_id()
	if players.has(my_id):
		players[my_id]["ready"] = true
		_log("✅ Local player ready")
		rpc("_sync_player_ready", my_id, true)
		_check_all_players_ready()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RPC SENDER IDENTITY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Reject an RPC whose identity argument does not belong to the caller.
##
## Six handlers in this file are declared @rpc("any_peer") and receive the peer they
## describe as a PARAMETER instead of deriving it from the transport. That is the
## ordinary Godot idiom right up to the point where the parameter is used as a
## dictionary KEY into shared state — which is exactly what these do, for lobby ready
## flags, G-Counter slots and per-round completion reports. Nothing checked that the
## sender and the claimed peer were the same peer, so peer 2 could write peer 1's
## record: mark the host ready and force start_countdown(), or file a completion
## report in the host's name that then feeds _apply_rolling_window_adjustment() and
## CoopAdaptation. On the G-Counter the damage is permanent, because merge takes MAX
## and an inflated slot can never be brought back down.
##
## Every one of the six is only ever CALLED with the sender's own id (see the rpc()
## call sites), so validating here changes no honest behaviour.
##
## Accepted callers:
##   sender == 0         local invocation — there is no remote identity to disagree.
##   sender == claimed   a peer describing itself; the normal and only real case.
##   sender == 1 and allow_host_relay
##                       the host forwarding a claim it already accepted.
##                       _sync_ready_status() re-broadcasts with the ORIGINAL peer id
##                       (see the rpc() inside it), so that one relay is legitimate
##                       and has to stay allowed. Opt-in rather than blanket: letting
##                       the host write any G-Counter slot would break the CRDT's
##                       one-writer-per-slot invariant for no benefit, since nothing
##                       relays counters.
func _sender_owns(claimed_peer_id: int, what: String, allow_host_relay: bool = false) -> bool:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0 or sender == claimed_peer_id:
		return true
	if allow_host_relay and sender == 1:
		return true
	# _log rather than push_warning: a rejected packet is a spoof or a stale relay,
	# not an engine error, and NetworkFaultSimulator deliberately injects duplicate
	# and invalid messages — routing those to the warning channel would bury real
	# warnings under simulated traffic.
	_log("🛑 %s rejected: peer %d claimed to be peer %d" % [what, sender, claimed_peer_id])
	return false


## Same check for the two RPCs that identify the player by player NUMBER (1/2)
## rather than by peer id — mark_task() and send_resource() both send
## _get_player_num(...), so the claim has to be mapped back through the player table
## before it can be compared to the sender.
##
## An unknown mapping is ACCEPTED, not rejected: _get_player_num() returns 0 for a
## peer this side has no entry for, which means the player table has not synced yet
## rather than that the sender lied. Both of these RPCs only emit a presentation
## signal, so dropping a legitimate task mark over a table race would cost more than
## the spoof it prevents. A sender with a KNOWN and different number is still
## rejected, which is the actual attack.
func _sender_is_player_num(claimed_num: int, what: String) -> bool:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		return true
	var actual := _get_player_num(sender)
	if actual == 0 or actual == claimed_num:
		return true
	_log("🛑 %s rejected: peer %d is player %d, not player %d"
		% [what, sender, actual, claimed_num])
	return false


@rpc("any_peer", "reliable")
func _sync_player_ready(peer_id: int, is_ready: bool) -> void:
	# Sync player ready status
	if not _sender_owns(peer_id, "_sync_player_ready"):
		return
	if players.has(peer_id):
		players[peer_id]["ready"] = is_ready
		player_ready_changed.emit(peer_id, is_ready)
		_log("✅ Player %d ready: %s" % [peer_id, is_ready])
		
		if is_host:
			_check_all_players_ready()

func _check_all_players_ready() -> void:
	# Check if all players are ready to start
	if not is_host:
		return
		
	var all_ready = true
	for p in players.values():
		if not p.get("ready", false):
			all_ready = false
			break
	
	if all_ready and players.size() >= MAX_PLAYERS:
		if _ready_signal_emitted:
			return
		_ready_signal_emitted = true
		_log("🚀 All players ready! Starting countdown...")
		both_players_ready.emit()
		start_countdown()



## STILL-READING FLAG — why the host needs one
##
## The first-play how-to-play beat (MultiplayerMiniGameBase._build_first_play_pages) pages
## through three taught steps before the every-round blurb, and only the LAST page signals
## readiness. That was deliberate: one thing to dismiss, one readiness signal. What it does
## NOT solve on its own is the host's force-start fallback. The host arms a six-second timer
## when IT finishes dismissing, and six seconds is nothing next to a first-timer reading
## three pages - so the common asymmetric case (host has played before and taps straight
## through, partner is new) force-started the reader into a running round, yanked the
## overlay off their screen mid-sentence, and spent the tutorial key permanently: the beat
## is marked shown at build time, so they never see it again.
##
## A peer that is part-way through the beat says so here. It carries no authority - the
## host still decides when the round starts - it only tells the host that the missing ready
## signal is a person reading rather than a lost packet, which are the two cases the
## fallback could not previously tell apart. Cleared when the beat is dismissed, when the
## round resets, and implicitly when the peer disconnects (the record leaves `players`).
func set_local_player_reading(is_reading: bool) -> void:
	var my_id: int = multiplayer.get_unique_id()
	if not players.has(my_id):
		return
	if bool(players[my_id].get("reading", false)) == is_reading:
		return
	players[my_id]["reading"] = is_reading
	# A client's rpc() reaches the server only, which is the peer that runs the fallback,
	# so no relay is needed. The host's own state is written on the line above.
	if is_multiplayer_connected():
		rpc("_sync_player_reading", my_id, is_reading)


@rpc("any_peer", "reliable")
func _sync_player_reading(peer_id: int, is_reading: bool) -> void:
	# Same identity check as every other any_peer handler here: the peer being described
	# arrives as a parameter and is used as a dictionary key, so it has to belong to the
	# sender. See _sender_owns().
	if not _sender_owns(peer_id, "_sync_player_reading"):
		return
	if players.has(peer_id):
		players[peer_id]["reading"] = is_reading


## True while any player is part-way through a first-play beat. Read by the host's
## force-start fallback; false for every round after the first, since the beat is not built
## at all once its tutorial key is spent.
func any_player_still_reading() -> bool:
	for p in players.values():
		if bool(p.get("reading", false)):
			return true
	return false
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-PLAY SYNC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "reliable")
func sync_mp_auto_play(enabled: bool) -> void:
	## Called on the REMOTE peer when a player toggles MP auto-play in the lobby.
	## Mirrors the state and, when enabling, also marks the local player as lobby-ready
	## so the host can detect that both are ready and auto-start.
	var ap = get_node_or_null("/root/AutoPlayManager")
	if ap and ap.has_method("set_mp_auto_play_enabled"):
		ap.set_mp_auto_play_enabled(enabled)
	_log("🤖 MP AutoPlay synced from partner: %s" % ("ON" if enabled else "OFF"))
	# When partner enables autoplay, mark self ready so host can auto-start
	if enabled and connection_active:
		set_ready(true)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLIENT FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func join_server(ip: String, port: int = DEFAULT_PORT) -> bool:
	# Join an existing server (client)
	if connection_active:
		_log("❌ Already connected to a server")
		return false
	
	network = ENetMultiplayerPeer.new()
	var error = network.create_client(ip, port)
	
	if error != OK:
		_log("❌ Failed to connect to server: " + str(error))
		connection_failed.emit()
		return false
	
	multiplayer.multiplayer_peer = network
	is_host = false
	connection_active = true
	local_player_id = 2
	# Remembered so _attempt_rejoin() can dial the same host again after a drop.
	_last_join_ip = ip
	_last_join_port = port
	
	# Disconnect existing signals to prevent duplicates
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	
	# Connect multiplayer signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	_log("🔄 Attempting to connect to " + ip + ":" + str(port))
	return true

func _on_connected_to_server() -> void:
	# Called when client successfully connects to server
	_log("✅ Connected to server!")
	_log("🎮 You are Player 2 (User)")
	connection_active = true
	
	# The peer came back. Close the window it opened, otherwise the timer that was
	# waiting for this reconnect fires 30 s later and clears game_in_progress on the
	# round now in progress.
	_cancel_grace_period("client reconnected")
	# ...and release the round if one was being held open for exactly this. The host
	# re-broadcasts _sync_game_state() from GameManager._on_peer_connected(), so the
	# score, lives and difficulty this side resumes with are the host's, merged with
	# element-wise max, not the stale locals from before the drop.
	_end_reconnect_hold(true)
	
	# Register self with server
	rpc_id(1, "_register_player", multiplayer.get_unique_id(), "Player 2 (Client)")
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	# Called when client fails to connect
	_log("❌ Connection failed!")
	connection_active = false
	if reconnect_hold_active:
		# One rejoin attempt inside the hold failing is expected, not a session error:
		# the retry timer tries again until the hold expires, and emitting here would
		# surface a "connection failed" dialog over a round that is still recoverable.
		return
	connection_failed.emit()

func _on_server_disconnected() -> void:
	# Called when server disconnects (client side)
	_log("⚠️ Server disconnected!")
	# Queue the reason BEFORE the teardown: the lobby this peer is about to be dropped into
	# reads it in its _ready(). A key, not a sentence — see GameManager.set_multiplayer_notice().
	#
	# Gated on game_in_progress so the DELIBERATE group return stays silent. Nobody needs to be
	# told the host left when they watched the host press the button: _execute_return_to_lobby()
	# clears the flag and changes scene first, and its deliberately deferred teardown can still
	# fault this handler a frame later, which would leave an unread notice to surface out of
	# context the next time the player opened multiplayer. On the involuntary path
	# _on_player_disconnected() has normally queued the same key ~30 ms earlier and first writer
	# wins; this is the fallback for a peer that only ever sees server_disconnected.
	# The notice is queued by _resolve_lost_peer() now, not here: it is only true once the
	# hold has expired with nobody back, and a notice queued on a drop that then RECOVERS
	# is exactly the unread-notice-out-of-context problem described above.
	_start_grace_period()
	_begin_reconnect_hold(false)
	server_disconnected.emit()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONNECTION MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_player_connected(peer_id: int) -> void:
	# Called on server when a player connects
	if players.size() >= MAX_PLAYERS:
		_log("❌ Max players reached, rejecting connection")
		network.disconnect_peer(peer_id)
		return
	
	# Host side of the same thing: the partner is back, so the window that was
	# counting down for their absence has to close, and a held round resumes.
	_cancel_grace_period("peer rejoined")
	_end_reconnect_hold(true)

	remote_player_id = peer_id
	_log("✅ Player connected (Peer ID: " + str(peer_id) + ")")

@rpc("any_peer", "reliable")
func _register_player(peer_id: int, player_name: String) -> void:
	# Register a new player (called by client, executed on server)
	if not is_host:
		return
	if not _sender_owns(peer_id, "_register_player"):
		return

	players[peer_id] = {
		"player_num": 2,
		"ready": false,
		"name": player_name
	}
	
	# Sync player list to all clients
	rpc("_sync_player_list", players)
	# The joiner has to arrive on the host's round clock rather than the shipped default:
	# the host can set it before anyone connects. Pushed from here, not from
	# _on_player_connected(), because this is the point at which the client is registered
	# and its NetworkManager is listening. See mp_round_seconds.
	rpc_id(peer_id, "_sync_mp_round_seconds", mp_round_seconds)
	player_connected.emit(peer_id, 2)

@rpc("authority", "reliable")
func _sync_player_list(updated_players: Dictionary) -> void:
	# Sync player list from server to clients
	players = updated_players
	_log("Player list synced: " + str(players.size()) + " players")

func _on_player_disconnected(peer_id: int) -> void:
	# Called when a player disconnects
	_log("⚠️ Player disconnected (Peer ID: " + str(peer_id) + ")")
	
	if players.has(peer_id):
		var _player_num = players[peer_id]["player_num"]
		players.erase(peer_id)
		
		# DECIDE FIRST, ANNOUNCE SECOND.
		#
		# A live round is held open for a bounded window instead of being emptied on the
		# spot; _resolve_lost_peer() below is what used to run here, and still runs, when
		# the hold expires with the peer still gone.
		#
		# This call has to precede the emit, and the first run of
		# tools/VerifyInRoundReconnect.tscn is why. With the emit first, the host's log read:
		#   ⚠️ Player disconnected (Peer ID: …)
		#   [Catch Rain for Aquarium P1]  Player left session - terminating for all players
		#   ⏳ Holding the round open for 6s for the peer to return
		# MultiplayerMiniGameBase._on_player_left_session() is connected to this signal, and
		# it asks is_reconnect_hold_active() before tearing the round down — which was still
		# false, because the hold had not been opened yet. It set game_active = false, showed
		# "session terminated" and routed to the lobby 2 s later, so the hold was protecting
		# a round that had already been ended by one of its own listeners.
		#
		# With no round in progress this is unchanged: _begin_reconnect_hold() falls straight
		# through to _resolve_lost_peer(), which returns without doing anything when
		# game_in_progress is false, and the scene change on the live path is deferred, so
		# every listener still runs in this frame either way.
		_begin_reconnect_hold(is_host)
		player_disconnected.emit(peer_id)

## True while a live round is frozen waiting for a dropped peer.
##
## Every other handler that used to empty the round on a disconnect checks this and
## stands down: GameManager._on_peer_disconnected(), MultiplayerMiniGameBase's
## _on_server_disconnected() and _on_player_left_session(). All of them fire in the same
## frame as _on_player_disconnected() and in an unspecified order, so the decision has to
## live in one place rather than in whichever handler happens to run first.
func is_reconnect_hold_active() -> bool:
	return reconnect_hold_active


## Freeze a live round for RECONNECT_HOLD_SECONDS and try to get the peer back.
##
## Before this existed, every disconnect path emptied the round immediately, so a client
## whose wifi blipped for two seconds lost the round outright — the case
## _on_grace_period_timeout() documents as "in-round reconnect is a gap". The host holds
## its authoritative round open and waits; the client also retries the join, because it is
## the side that has to dial back in. On expiry the round is resolved exactly as it was
## before, so the failure path is unchanged and only the success path is new.
func _begin_reconnect_hold(as_host: bool) -> void:
	if reconnect_hold_active:
		# Second handler for the same drop. The first one owns it.
		return
	if not game_in_progress:
		# No live round to hold open — resolve immediately, as before.
		_resolve_lost_peer(as_host)
		return
	reconnect_hold_active = true
	_reconnect_hold_as_host = as_host
	_reconnect_hold_timer.start()
	if not as_host:
		_reconnect_retry_timer.start()
		# DEFERRED, not called here. This runs inside the emission of
		# multiplayer.peer_disconnected, i.e. inside the ENet peer's own poll, and
		# _attempt_rejoin() closes that peer and replaces multiplayer_peer. Swapping the
		# object whose poll is currently on the stack is how you get a crash instead of a
		# reconnect; one frame later it is an ordinary call.
		call_deferred("_attempt_rejoin")
	_log("⏳ Holding the round open for %.0fs for the peer to return" % RECONNECT_HOLD_SECONDS)
	reconnect_hold_started.emit(RECONNECT_HOLD_SECONDS)


func _end_reconnect_hold(rejoined: bool) -> void:
	if not reconnect_hold_active:
		return
	reconnect_hold_active = false
	_reconnect_hold_timer.stop()
	_reconnect_retry_timer.stop()
	var as_host: bool = _reconnect_hold_as_host
	_log("⏳ Reconnect hold ended (%s)" % ("peer returned" if rejoined else "expired"))
	# Emitted BEFORE the round is resolved so the scene can drop its overlay and unpause
	# first: _resolve_lost_peer() changes scene, and a scene freed while still paused
	# leaves the tree paused behind the lobby.
	reconnect_hold_ended.emit(rejoined)
	if not rejoined:
		_resolve_lost_peer(as_host)


func _on_reconnect_hold_timeout() -> void:
	_end_reconnect_hold(false)


## One rejoin attempt. Client side only — the host has nothing to dial.
func _attempt_rejoin() -> void:
	if is_host or _last_join_ip == "":
		return
	# The dead peer has to go first: create_client() on a live multiplayer_peer would
	# leave two peers behind, and join_server()'s own connection_active guard would
	# refuse the call outright.
	if network:
		network.close()
		network = null
	multiplayer.multiplayer_peer = null
	connection_active = false
	_log("🔄 Rejoin attempt → %s:%d" % [_last_join_ip, _last_join_port])
	join_server(_last_join_ip, _last_join_port)


## End a round whose peer did not come back, and route this side out of it.
##
## This is verbatim what _on_player_disconnected() used to do inline, now reached only
## after _begin_reconnect_hold() has waited RECONNECT_HOLD_SECONDS, or immediately when
## there was no live round to hold. `had_round` reproduces the old `if game_in_progress:`
## gate: with no round in progress this is a deliberate teardown, which must not queue a
## notice and must not change scene.
func _resolve_lost_peer(as_host: bool) -> void:
	var had_round: bool = game_in_progress
	if not had_round:
		return
	var is_host_role: bool = as_host
	if not is_host_role:
		_log("🔌 Host disconnected during game, returning to lobby...")
		GameManager.set_multiplayer_notice("notice_host_left")
		# Route out through GameManager rather than changing scenes here.
		#
		# Raw change_scene_to_file() bypasses transition_to_scene()'s _is_transitioning
		# guard, and this is no longer the only handler that fires: peer_disconnected
		# reaches GameManager._on_peer_disconnected() (which already defers
		# return_to_multiplayer_lobby()) and MultiplayerMiniGameBase's own handler in the
		# same frame, ~30 ms before server_disconnected. Measured with
		# tools/VerifyHostDeparture.tscn. Two unguarded loads would also leave
		# NetworkManager's half of the session (players, connection_active, the peer)
		# populated behind a lobby that reads it as live; return_to_multiplayer_lobby()
		# unpauses, tears both halves down and transitions once.
		game_in_progress = false
		GameManager.call_deferred("return_to_multiplayer_lobby")
	else:
		# Host: the only other player is gone, so there is no round left to
		# finish. Nothing else resolved this — the results overlay in
		# MultiplayerMiniGameBase advances ONLY on both_players_completed,
		# which needs a second entry in round_completion_status that can now
		# never arrive, so the host sat on "waiting for partner" forever with
		# game_in_progress already false. _start_grace_period() is not wired
		# to this path either; it is only called from _on_server_disconnected,
		# which is the client side.
		#
		# Leaving for the lobby is the same resolution the client above gets
		# when the host vanishes, and the host is still the server so the
		# lobby stays valid for a reconnect. The alternative — force-completing
		# the round by marking the departed peer failed — was rejected: it
		# would feed a fabricated accuracy and reaction time for a player who
		# never played into _apply_rolling_window_adjustment() and
		# CoopAdaptation, corrupting the adaptive-difficulty window with
		# synthetic data.
		game_in_progress = false
		round_completion_status.clear()
		round_in_progress = false
		_log("🔌 Partner left during game, returning to lobby...")
		GameManager.set_multiplayer_notice("notice_partner_left")
		var host_lobby = "res://scenes/ui/MultiplayerLobby.tscn"
		# Unfreeze before leaving. This branch changes scene RAW - deliberately, because
		# unlike the client above the host is still the server and must keep listening so
		# the lobby stays claimable, which return_to_multiplayer_lobby() would tear down.
		# The cost of going raw is that nothing else clears get_tree().paused, and since
		# _begin_reconnect_hold() the round IS paused when this runs:
		# MultiplayerMiniGameBase._on_reconnect_hold_ended(false) deliberately leaves the
		# freeze in place because the round is about to be thrown away. `paused` lives on
		# the SceneTree, not on the scene, so it survives change_scene_to_file() -
		# measured with tools/VerifyInRoundReconnect.tscn, which found the host sitting in
		# a fully frozen lobby (paused=true, lobbies=1) with every button, tween and timer
		# in it dead.
		get_tree().paused = false
		clear_pause_state()
		get_tree().call_deferred(
			"change_scene_to_file", host_lobby)


func _start_grace_period() -> void:
	# Start reconnection grace period
	if grace_period_active:
		return
	
	grace_period_active = true
	disconnection_timer.start()
	_log("⏱️ Reconnection grace period started (" + str(RECONNECT_GRACE_PERIOD) + " seconds)")


## Close the reconnection window without treating it as an expiry.
##
## The window used to have no cancel path at all: "disconnection_timer.stop()" did
## not appear anywhere in this file, and grace_period_active was cleared only inside
## _on_grace_period_timeout(). A one_shot 30 s timer that nothing can stop outlives
## the session that opened it, and the timeout clears game_in_progress, so it landed
## on whatever session happened to be running 30 s later. Three ways that bit:
##   - teardown: the client leaves for the lobby immediately on server_disconnected,
##     so pressing HOST again inside 30 s marked the NEW round not-in-progress;
##   - reconnect: a peer back at t=5s was still torn down at t=30s by the very timer
##     that had been waiting for it - the one case the window exists to serve;
##   - a second disconnect inside the window hit the "already active" guard in
##     _start_grace_period() and inherited the remainder of a dead session window.
##
## Covered by tools/VerifyGracePeriodLifecycle.tscn (cases 2 to 6).
func _cancel_grace_period(reason: String) -> void:
	if not grace_period_active and disconnection_timer.is_stopped():
		return
	disconnection_timer.stop()
	grace_period_active = false
	_log("⏱️ Reconnection grace period cancelled (" + reason + ")")

func _on_grace_period_timeout() -> void:
	# The reconnection window closed with the peer still gone.
	grace_period_active = false
	_log("⏰ Grace period expired - peer did not return")
	
	if not game_in_progress:
		# Nothing left to resolve: the round already ended, or the session was torn
		# down and the window cancelled. Arriving here with no round is not an error.
		return
	
	# The round can no longer be finished, so it is ENDED rather than scored. The
	# results overlay in MultiplayerMiniGameBase advances only on
	# both_players_completed, and the second entry in round_completion_status can
	# never arrive from a peer that is gone.
	#
	# Deliberately NOT force-completing the round on behalf of the absent player:
	# that would feed a fabricated accuracy and reaction time for someone who never
	# played into _apply_rolling_window_adjustment() and CoopAdaptation, corrupting
	# the adaptive-difficulty window with synthetic data. This is the same trade-off
	# the partner-left branch of _on_player_disconnected() already rejected.
	game_in_progress = false
	# The window closed with nobody back, so the next multiplayer screen says so.
	GameManager.set_multiplayer_notice("notice_partner_no_return")
	round_completion_status.clear()
	round_in_progress = false
	# Routing is left to the scene rather than done here, matching how
	# server_disconnected is consumed (MultiplayerMiniGameBase connects it and calls
	# GameManager.return_to_multiplayer_lobby). An autoload that changes scenes on
	# its own would also free whatever is mid-transition.
	#
	# REACHABILITY, STATED PLAINLY: still not reached on the paths that ship, and now
	# for a different reason. In-round reconnect IS implemented — see
	# _begin_reconnect_hold() — but it holds the round for RECONNECT_HOLD_SECONDS (6 s),
	# not for this 30 s window, and on expiry it resolves the round itself and routes
	# out, whose teardown cancels this window. This handler remains the correct
	# resolution for any future scene that holds a session open for the full window.
	reconnect_failed.emit()

func disconnect_multiplayer() -> void:
	# Disconnect from multiplayer session
	# Ahead of the connection_active guard on purpose: a session being torn down must
	# never leave a live reconnection window behind it, and some callers reach here
	# with connection_active already false. _cancel_grace_period() is a no-op when no
	# window is open, so running it first costs nothing.
	_cancel_grace_period("session torn down")
	# Same reasoning for the in-round hold: its timers are PROCESS_MODE_ALWAYS, so one
	# left running would outlive the session that opened it and resolve a later round.
	if reconnect_hold_active:
		reconnect_hold_active = false
		_reconnect_hold_timer.stop()
		_reconnect_retry_timer.stop()
	
	if not connection_active:
		return
	
	# Close the network connection
	if network:
		network.close()
		network = null
	
	# Clear multiplayer peer
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	
	# Disconnect signals to prevent cross-session issues
	if multiplayer.peer_connected.is_connected(_on_player_connected):
		multiplayer.peer_connected.disconnect(_on_player_connected)
	if multiplayer.peer_disconnected.is_connected(_on_player_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_player_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	
	is_host = false
	connection_active = false
	players.clear()
	game_in_progress = false
	local_player_id = 0
	remote_player_id = 0
	_ready_signal_emitted = false
	_countdown_started_this_round = false
	
	_log("🔌 Disconnected from multiplayer")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# READY SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func set_ready(is_ready: bool) -> void:
	# Set local player ready status
	var my_peer_id = multiplayer.get_unique_id()
	
	if players.has(my_peer_id):
		players[my_peer_id]["ready"] = is_ready
		
		if is_host:
			# Sync to clients
			rpc("_sync_ready_status", my_peer_id, is_ready)
		else:
			# Send to host
			rpc_id(1, "_sync_ready_status", my_peer_id, is_ready)
		
		_log("Ready status: " + str(is_ready))
		_check_all_ready()

@rpc("any_peer", "reliable")
func _sync_ready_status(peer_id: int, is_ready: bool) -> void:
	# Sync ready status across network
	# Host relay allowed: the rpc() below re-broadcasts with the original peer id.
	if not _sender_owns(peer_id, "_sync_ready_status", true):
		return
	if players.has(peer_id):
		players[peer_id]["ready"] = is_ready
		
		# Emit signal so UI can update
		player_ready_changed.emit(peer_id, is_ready)
		
		# If host, broadcast to all clients
		if is_host:
			rpc("_sync_ready_status", peer_id, is_ready)
		
		_check_all_ready()

func _check_all_ready() -> void:
	# Check if all players are ready
	if players.size() < MAX_PLAYERS:
		return
	
	for player_data in players.values():
		if not player_data["ready"]:
			return
	
	_log("✅ All players ready!")
	if not _ready_signal_emitted:
		_ready_signal_emitted = true
		both_players_ready.emit()

func are_all_players_ready() -> bool:
	# Check if all players are ready
	if players.size() < MAX_PLAYERS:
		return false
	
	for player_data in players.values():
		if not player_data["ready"]:
			return false
	
	return true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME SESSION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ROUND LENGTH (host-authoritative)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Seconds a co-op round lasts, or 0 for "whatever each scene authored".
##
## The control that writes this lives on the Multiplayer page next to Ready / Auto Play /
## Start Game, not in Settings, and it is host-authoritative for the same reason the pause
## state is: two peers running different round clocks is the pause race again with a
## different symptom - one player's timer hits zero while the other is still playing, and
## the round resolves against a partner who never stopped. So the host writes and broadcasts;
## a client's own write is refused here AND the sync below is @rpc("authority"), so a
## client-sent copy is dropped by Godot before it reaches this file.
##
## 0 is the shipped default and means "do not touch game_duration at all", so a session that
## never opens the control gets byte-identical behaviour to before this control existed. All
## twelve MP scenes author 30 s today.
var mp_round_seconds: float = 0.0

## Bounds for the control. 10 s is the shortest round in which every one of the twelve games
## reaches its first spawn; 180 s is three minutes, past which the adaptive-difficulty ramp
## has nothing further to say. A hand-typed value outside this is pulled inside rather than
## rejected, so the two peers cannot end up disagreeing about whether it was legal.
const ROUND_SECONDS_MIN: float = 10.0
const ROUND_SECONDS_MAX: float = 180.0

signal mp_round_seconds_changed(seconds: float)


## Host entry point for the Multiplayer page's round-timer control.
func set_mp_round_seconds(seconds: float) -> void:
	if is_multiplayer_connected() and not is_server():
		_log("⚠️ Only the host sets the round timer")
		return
	var clamped: float = sanitize_round_seconds(seconds)
	if is_equal_approx(clamped, mp_round_seconds):
		return
	if is_multiplayer_connected() and is_server():
		# call_local, so the host's own copy is written by the same body the client runs.
		rpc("_sync_mp_round_seconds", clamped)
	else:
		# Solo on this device (lobby opened before anyone joined): apply directly. The value
		# is pushed to the joiner in _register_player().
		_sync_mp_round_seconds(clamped)


@rpc("authority", "call_local", "reliable")
func _sync_mp_round_seconds(seconds: float) -> void:
	# @rpc("authority") makes Godot drop a client-sent copy on the RECEIVING side, which is
	# only half the story: "call_local" means a client that called rpc() on this anyway would
	# still run the body on itself and end up alone on a clock the host never agreed to. So
	# the sender is checked here as well. 0 is a local call, 1 is the host.
	var sender: int = multiplayer.get_remote_sender_id() if is_multiplayer_connected() else 0
	if sender != 0 and sender != 1:
		_log("⚠️ Ignoring a round-timer sync from peer %d" % sender)
		return
	if sender == 0 and is_multiplayer_connected() and not is_server():
		_log("⚠️ Ignoring a local round-timer write on a client")
		return
	var clamped: float = sanitize_round_seconds(seconds)
	if is_equal_approx(clamped, mp_round_seconds):
		return
	mp_round_seconds = clamped
	mp_round_seconds_changed.emit(clamped)
	_log("⏱️ Round timer: %s" % ("scene default" if clamped <= 0.0 else "%.0fs" % clamped))


## 0 passes through as "scene default"; anything else is pulled inside the advertised range.
func sanitize_round_seconds(seconds: float) -> float:
	if seconds <= 0.0:
		return 0.0
	return clampf(seconds, ROUND_SECONDS_MIN, ROUND_SECONDS_MAX)


## What a round should actually run for, given the length its own scene authored.
## Called by MultiplayerMiniGameBase after _on_multiplayer_ready() has set game_duration.
func round_seconds_for(authored: float) -> float:
	return authored if mp_round_seconds <= 0.0 else mp_round_seconds

func start_game(scenario_id: String) -> void:
	# Start cooperative game session (host only)
	if not is_host:
		_log("❌ Only host can start the game")
		return
	
	if not are_all_players_ready():
		_log("❌ Not all players are ready")
		return
	
	current_scenario_id = scenario_id
	game_in_progress = true
	
	# Assign roles
	player_roles = {
		1: "Collector",
		2: "User"
	}
	
	# Broadcast game start to all clients
	rpc("_receive_game_start", scenario_id, player_roles)
	
	_log("🎮 Game started: " + scenario_id)
	game_started.emit(scenario_id, player_roles)

func start_multiplayer_game(scene_path: String) -> void:
	# Start multiplayer game and load scene on all clients (host only)
	if not is_host:
		_log("❌ Only host can start the game")
		return
	
	if not are_all_players_ready():
		_log("❌ Not all players are ready")
		return
	
	game_in_progress = true
	
	# Load scene on all clients (including host with call_local)
	rpc("_load_game_scene", scene_path, get_total_score())
	_log("🎮 Loading game scene on all players: " + scene_path)

@rpc("authority", "call_local", "reliable")
func _load_game_scene(scene_path: String, round_baseline: int = -1) -> void:
	# Load game scene on this peer
	# The first round needs a baseline as much as the later ones do: a session that starts in
	# the same process as a finished one (return to lobby, play again) inherits that session's
	# G-Counter, which cannot be cleared away - see round_score_baseline. -1 means "no baseline
	# supplied", which is how a harness that calls this directly keeps the one it set.
	if round_baseline >= 0:
		round_score_baseline = round_baseline
	_log("📥 Loading game scene: " + scene_path)
	
	var packed_scene = load(scene_path)
	if packed_scene == null:
		_log("❌ Failed to load scene: " + scene_path)
		return
	
	# Every peer that loads a round scene is in a round, INCLUDING the client.
	#
	# This flag used to be written only by the host, in start_multiplayer_game() and
	# start_multiplayer_game_pair(), plus by _receive_game_start() on the start_game()
	# scenario path. The pair path — the one MultiplayerLobby.gd:803 actually ships —
	# sends only _reset_round_status and _load_game_scene, neither of which touched it,
	# so a client played a whole round with game_in_progress == false. That made two
	# guards below read the wrong answer on the client: the host-vanished fallback in
	# _on_player_disconnected() and the round resolution in _on_grace_period_timeout().
	# Setting it here fixes both start paths on both sides at once, because this RPC is
	# the single call every peer runs to enter a round. Idempotent on the host, which
	# has already set it a few lines up.
	game_in_progress = true
	
	var result = get_tree().change_scene_to_packed(packed_scene)
	if result != OK:
		_log("❌ Failed to change scene, error code: " + str(result))

@rpc("authority", "call_local", "reliable")
func _reset_round_status() -> void:
	# Clear stale completion and in-game ready state before a new game loads.
	round_completion_status.clear()
	round_in_progress = false
	_ready_signal_emitted = false
	_countdown_started_this_round = false
	# Both per-round latches go with the round: a stale pause would swallow the first
	# press of the next one, and a stale shared-target flag would stop the next round
	# ever closing early.
	clear_pause_state()
	clear_shared_target()
	for peer_id in players.keys():
		players[peer_id]["ready"] = false
		# The still-reading flag is per-round too: a peer that was force-started out of its
		# beat must not carry a stale "still reading" into the next round and hold the
		# fallback there. See set_local_player_reading().
		players[peer_id]["reading"] = false
		player_ready_changed.emit(peer_id, false)
	_log("🔄 Round status reset")

## Public entry point for the per-round reset, for callers outside NetworkManager.
##
## The reset itself keeps its underscore name because it IS an @rpc: the existing
## rpc("_reset_round_status") broadcasts in start_multiplayer_game_pair() and
## _load_next_round() address it by that name, so renaming it would break them.
## GameManager's round advance is itself @rpc("call_local") and therefore already
## running on every peer, so what it needs is the LOCAL call rather than a second
## broadcast — this wrapper gives it one without reaching through the underscore.
func reset_round_status() -> void:
	_reset_round_status()

## The one place a round's roles are decided. LevelSets.get_random_level_set() has already
## swapped the pair for this round number, so the set is read as authored. Both round-start
## paths call this — the lobby hand-off below and the round-transition RPC body — which is
## what makes the two peers agree about who is holding the bucket.
func assign_round_roles(level_set: Dictionary) -> void:
	var p1: String = str(level_set.get("player1_role", "")).strip_edges()
	var p2: String = str(level_set.get("player2_role", "")).strip_edges()
	if p1 == "" or p2 == "":
		return
	player_roles = {1: p1, 2: p2}

## The lobby holds the level set and knows both role names; before FIX 75 it passed only the
## two scene paths, so round 1 ran on the {Collector, User} placeholder that connect() sets
## and all ten authored flavour names were unreachable. The set is optional so the two legacy
## callers below keep working unchanged.
func start_multiplayer_game_pair(p1_scene: String, p2_scene: String, level_set: Dictionary = {}) -> void:
	# Start multiplayer game with DIFFERENT scenes for each player (host only)
	if not is_host:
		_log("❌ Only host can start the game")
		return
	
	if not are_all_players_ready():
		_log("❌ Not all players are ready")
		return
	
	game_in_progress = true
	
	# Hand out this round's roles, then tell the client the same pair. _receive_game_start is
	# the function that already existed for exactly this and had no shipping caller: its own
	# assignment of player_roles is what makes the client agree with the host from round 1.
	if not level_set.is_empty():
		assign_round_roles(level_set)
		rpc("_receive_game_start", str(level_set.get("id", "")), player_roles)
	
	# Re-stated with the round it applies to, so "both peers time the same round" is a
	# property of the start broadcast rather than something inferred from an earlier sync.
	# Reliable RPCs on one channel are ordered, so this lands before the scene load below,
	# and _sync_mp_round_seconds() early-returns when the value is already what the peer has.
	rpc("_sync_mp_round_seconds", mp_round_seconds)

	# Reset round completion state on ALL peers before loading new scenes
	rpc("_reset_round_status")
	
	_log("🎮 Loading INTERCONNECTED games:")
	_log("   Player 1 (Host) → %s" % p1_scene)
	_log("   Player 2 (Client) → %s" % p2_scene)
	
	# One baseline for both halves of the pair, read once here so the host and the client
	# measure this round's quota from the same total (see round_score_baseline).
	var round_baseline: int = get_total_score()
	
	# Host loads P1 scene
	_load_game_scene(p1_scene, round_baseline)
	
	# Tell client to load P2 scene
	for peer_id in players.keys():
		if peer_id != multiplayer.get_unique_id():  # Not the host
			rpc_id(peer_id, "_load_game_scene", p2_scene, round_baseline)

@rpc("authority", "reliable")
func _receive_game_start(scenario_id: String, roles: Dictionary) -> void:
	# Receive game start signal (client side)
	current_scenario_id = scenario_id
	game_in_progress = true
	player_roles = roles
	
	_log("🎮 Game started: " + scenario_id)
	game_started.emit(scenario_id, roles)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# G-COUNTER IMPLEMENTATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## The G-Counter total at the moment the current round started.
##
## A G-Counter only ever grows - that is what makes it a CRDT - so a round's quota cannot be
## measured against its raw total: round 2 opens already holding round 1's points and wins on
## the first tap. The counter used to be reset between rounds instead, and that is worse than
## it looks. Reset is not one of the counter's operations, so the next merge (an element-wise
## max, by definition) restored the old values from the peer that had not reset: the host
## cleared its dictionary, the client's first sync put the numbers straight back, and the two
## peers disagreed about the score in between. Measured in tools/VerifyMPWashWater: a
## WaterPlants round whose team quota was 80 announced "Quota met! (90/80 team)" after one
## plant, on 10 points actually scored.
##
## So nothing is reset per round. The host records the total as the round starts and ships that
## integer to both peers inside the same call_local body that loads the round, which is what
## makes them agree on it - each peer deciding locally would let them differ by whatever was
## still in flight. Per-round score is total - baseline: still integers only, still monotone,
## still a G-Counter.
var round_score_baseline: int = 0

## The score THIS round has earned as a team - what a win_quota is measured against.
func get_round_score() -> int:
	return max(0, get_total_score() - round_score_baseline)

## For a genuinely new session only (a fresh lobby), never between rounds - see
## round_score_baseline for why a per-round reset cannot survive the next merge.
func reset_g_counter() -> void:
	# Reset G-Counter for new game session
	g_counter.clear()
	var my_id = multiplayer.get_unique_id()
	g_counter[my_id] = 0
	round_score_baseline = 0
	_log("🔄 G-Counter reset")

func increment_local(amount: int) -> void:
	# Increment local player's counter (CRDT operation)
	# Each player only increments their own counter
	var my_id = multiplayer.get_unique_id()
	g_counter[my_id] = g_counter.get(my_id, 0) + amount
	
	# Also update the dedicated GCounter singleton
	var gc = get_node_or_null("/root/GCounter")
	if gc:
		gc.increment(my_id, amount)
	
	_log("💧 Local score +%d → G-Counter[%d] = %d" % [amount, my_id, g_counter[my_id]])
	
	# Broadcast merge to all peers
	rpc("_merge_counter", my_id, g_counter[my_id])
	
	# Emit signal for UI update. The round score, not the session total: it is the number the
	# win quota is measured against, so it is the number the players have to be able to watch.
	team_score_updated.emit(get_round_score())

@rpc("any_peer", "reliable")
func _merge_counter(peer_id: int, value: int) -> void:
	# Merge counter value from remote peer (CRDT merge operation)
	# Takes MAX of existing and new value to ensure monotonic growth
	#
	# Identity is enforced here and nowhere else: a G-Counter is only correct while
	# each replica writes ONLY its own slot, and because merge is MAX an inflated slot
	# is permanent — no later message can bring it down. increment_local() is the sole
	# caller and always sends multiplayer.get_unique_id(), so the honest path is
	# unaffected. Host relay is deliberately NOT allowed: nothing forwards counters.
	if not _sender_owns(peer_id, "_merge_counter"):
		return
	var old_value = g_counter.get(peer_id, 0)
	g_counter[peer_id] = max(old_value, value)
	
	# Also merge into the dedicated GCounter singleton
	var gc = get_node_or_null("/root/GCounter")
	if gc:
		gc.merge({peer_id: value})
	
	if g_counter[peer_id] > old_value:
		_log("📡 Merged counter[%d]: %d → %d" % [peer_id, old_value, g_counter[peer_id]])
		team_score_updated.emit(get_round_score())

func get_total_score() -> int:
	# Calculate global score = sum of all peer counters
	var total = 0
	for count in g_counter.values():
		total += count
	return total

func get_player_score(peer_id: int) -> int:
	# Get individual player's score
	return g_counter.get(peer_id, 0)

func get_mp_session_scores() -> Dictionary:
	## Returns session-cumulative per-player and team totals.
	## Keyed as "p1_total", "p2_total", "team_total".
	return {
		"p1_total": mp_session_p1_score,
		"p2_total": mp_session_p2_score,
		"team_total": mp_session_p1_score + mp_session_p2_score
	}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SHARED LIVES SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func reset_team_lives() -> void:
	# Reset team lives for new game session (host only)
	if not is_host:
		return
	
	team_lives = START_TEAM_LIVES
	rounds_survived = 0
	mp_session_p1_score = 0
	mp_session_p2_score = 0
	_log("❤️ Team lives reset to %d" % team_lives)
	
	# Sync to all clients
	rpc("_sync_team_lives", team_lives)

func lose_life() -> void:
	# Team loses a life (called by any player when they fail)
	# Only host has authority to modify lives
	if is_host:
		team_lives = max(0, team_lives - 1)
		_log("💔 Team lost a life! Remaining: %d" % team_lives)
		
		# Broadcast to all clients
		rpc("_sync_team_lives", team_lives)
		team_lives_updated.emit(team_lives)
		
		if team_lives <= 0:
			_log("💀 GAME OVER - Team ran out of lives!")
			rpc("_execute_game_over")
	else:
		# Client requests host to deduct life
		rpc_id(1, "_request_lose_life")

@rpc("any_peer", "reliable")
func _request_lose_life() -> void:
	# Client requests host to deduct a life
	if is_host:
		lose_life()

@rpc("authority", "call_local", "reliable")
func _sync_team_lives(lives: int) -> void:
	# Sync team lives from host to all clients
	team_lives = lives
	team_lives_updated.emit(team_lives)
	_log("📡 Team lives synced: %d" % lives)

@rpc("authority", "call_local", "reliable")
func _execute_game_over() -> void:
	# Execute game over sequence on all clients
	game_in_progress = false
	_log("🏁 GAME OVER - Rounds: %d, Score: %d"
		% [rounds_survived, get_total_score()])
	# Game will handle showing game over screen

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RPC FUNCTIONS - GAME EVENTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "reliable")
func send_game_event(event_type: String, data: Dictionary) -> void:
	# Send a game event to the partner
	var _sender_id = multiplayer.get_remote_sender_id()
	
	# If host, broadcast to other client
	if is_host:
		rpc("_receive_game_event", event_type, data)
	else:
		# If client, send to host to broadcast
		rpc_id(1, "_relay_game_event", event_type, data)

@rpc("any_peer", "reliable")
func _relay_game_event(event_type: String, data: Dictionary) -> void:
	# Host relays event from client to other clients (if we had >2 players) or processes it
	# For 2 players, host just receives it and broadcasts to itself (handled by local call) 
	# or broadcasts to others.
	# Since we are 2 players, if client sends to host, host receives it.
	# We need to make sure the host's local game instance gets it.
	# Host-only by contract: this is the path a CLIENT uses to reach the host
	# (send_game_event does rpc_id(1, "_relay_game_event", ...)). It is annotated
	# any_peer, so without this check the host could push an event straight into a
	# client through the relay entry point instead of the broadcast one, bypassing
	# the single route every other peer sees. Nothing legitimate sends it downward.
	if not is_host:
		if multiplayer.get_remote_sender_id() != 0:
			_log("⚠️ _relay_game_event ignored: relay is a host-side entry point")
			return
	_receive_game_event(event_type, data)

@rpc("any_peer", "reliable")
func _receive_game_event(event_type: String, data: Dictionary) -> void:
	# Receive game event
	# Find the current active minigame and notify it
	var current_scene = get_tree().current_scene
	# current_scene is null for the window between change_scene_to_file() freeing the old
	# scene and the new one entering the tree — exactly when round-boundary events are
	# still in flight. This is @rpc("any_peer"), so the partner can land a call inside
	# that window. The five sibling handlers in this file (_receive_water_for_consumption,
	# _execute_pause, _execute_resume, sync_pause_state, _show_game_over) all guard it;
	# this one did not, and faulted with "Attempt to call has_method on a null instance".
	if current_scene and current_scene.has_method("on_partner_event"):
		current_scene.on_partner_event(event_type, data)

func return_to_lobby() -> void:
	# Return all players to lobby
	#
	# With no live session there is nobody to tell, and the RPC is not merely useless -
	# it ABORTS the call. Reached from MultiplayerGameOver's only button with the peer
	# already torn down (the partner left, or the server went away, which is exactly
	# when a game-over screen is most likely to be what the player is looking at), the
	# non-host branch became rpc_id(1, ...) addressed to itself and Godot rejected it:
	# "RPC '_request_return_to_lobby' on yourself is not allowed by selected mode".
	# Nothing after it ran, so the screen never changed and its Back button did
	# nothing at all. Measured by tools/VerifyPausedNavigation.tscn, which clicks that
	# button with no peer up.
	if not is_multiplayer_connected():
		_log("↩️ No live session - returning to the lobby locally")
		_execute_return_to_lobby()
		return
	if is_host:
		rpc("_execute_return_to_lobby")
	else:
		# Request host to return
		rpc_id(1, "_request_return_to_lobby")

@rpc("any_peer", "reliable")
func _request_return_to_lobby() -> void:
	if is_host:
		rpc("_execute_return_to_lobby")

@rpc("authority", "call_local", "reliable")
func _execute_return_to_lobby() -> void:
	# Change scene first, then tear down connection with call_deferred
	# so the lobby scene can initialize before the peer is destroyed
	game_in_progress = false
	if get_tree().paused:
		get_tree().paused = false
	# The authority's pause bookkeeping goes with the round. Left set, the next round
	# would open believing a pause was already in force and drop the first press.
	clear_pause_state()
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

	# The teardown stays DEFERRED, and the deferral is load-bearing: this method is
	# call_local, so on the host it runs inside the same call stack as the rpc()
	# that queued the message for the client. Closing the ENet peer there would
	# discard the still-queued reliable packet — ENetMultiplayerPeer::close()
	# disconnects each peer with enet_peer_disconnect_now(), whose first act is
	# enet_peer_reset_queues() — and the client would never be told to leave the
	# round; it would fall through to _on_server_disconnected() and sit in the
	# finished minigame for the whole 30 s grace period.
	# tools/VerifyReturnToLobby.tscn asserts from the CLIENT process that it really
	# does land in the lobby, so this ordering is measured, not assumed.
	#
	# Routed through GameManager rather than calling disconnect_multiplayer() on
	# this node: GameManager.disconnect_multiplayer() calls ours and additionally
	# clears the mirror the lobby UI actually reads — is_multiplayer_connected,
	# is_host, peer, g_counter, session_active, multiplayer_game_order and
	# multiplayer_game_index. Clearing only our half left GameManager believing a
	# session was still live, and because get_next_multiplayer_game() reshuffles
	# only when multiplayer_game_order is empty or exhausted, the NEXT hosted
	# session resumed the previous session's shuffle at its old index instead of
	# starting a fresh one. MultiplayerLobby._on_disconnect_pressed() already pairs
	# the two teardowns this way; this path was the one that did not.
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("disconnect_multiplayer"):
		gm.call_deferred("disconnect_multiplayer")
	else:
		call_deferred("disconnect_multiplayer")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RPC FUNCTIONS - PERFORMANCE DATA
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "reliable")
func send_performance_data(performance: Dictionary) -> void:
	# Send player performance data to all peers
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Determine player number from peer ID
	var player_num = 0
	if players.has(sender_id):
		player_num = players[sender_id]["player_num"]
	elif sender_id == 0:  # Local call
		player_num = local_player_id
	
	# Add player_id to performance data
	performance["player_id"] = player_num
	
	_log("📊 Performance received from Player " + str(player_num))
	performance_data_received.emit(player_num, performance)
	
	# If host, broadcast to all clients
	if is_host and sender_id != 0:
		rpc("_broadcast_performance", player_num, performance)

@rpc("authority", "reliable")
func _broadcast_performance(player_num: int, performance: Dictionary) -> void:
	# Broadcast performance data to all clients (from host)
	performance_data_received.emit(player_num, performance)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RPC FUNCTIONS - GAME STATE SYNC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "reliable")
func sync_game_state(state: Dictionary) -> void:
	# UNWIRED. game_state_synced has no listeners anywhere in the project (grep:
	# only the signal declaration and these two emits), so nothing consumes `state`
	# and there is no schema to validate it against. Left in place rather than
	# invented into: the relay discipline below is already correct — only the host
	# re-broadcasts, and only for a genuinely remote sender — and the payload stays
	# untrusted data that goes no further than an unheard signal. If a consumer is
	# ever added, it must validate the dictionary before reading it, exactly as
	# _water_payload_valid does for the water pipeline.
	_log("🔄 Game state synced")
	game_state_synced.emit(state)
	
	# If host, broadcast to all clients
	if is_host:
		var sender_id = multiplayer.get_remote_sender_id()
		if sender_id != 0:
			rpc("_broadcast_game_state", state)

@rpc("authority", "reliable")
func _broadcast_game_state(state: Dictionary) -> void:
	# Broadcast game state to all clients (from host)
	game_state_synced.emit(state)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RPC FUNCTIONS - GAME END
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "reliable")
func notify_game_end(team_result: Dictionary) -> void:
	# Ending the game is a HOST decision.
	#
	# This used to write `game_in_progress = false` on the FIRST line, before any
	# authority check, and it is @rpc("any_peer") — so any peer could end the round
	# for the whole team by calling it, and on the host that write also stopped the
	# host from broadcasting a later, legitimate end. A client reaching this handler
	# is making a REQUEST at most; it learns the outcome from _broadcast_game_end like
	# every other peer, which is @rpc("authority") and so is enforced by Godot itself.
	# A remote sender is refused outright rather than forwarded as a request: the live
	# end-of-round decision belongs to the host's own completion bookkeeping, and
	# forwarding would only relabel the same hole.
	#
	# The handler currently has no callers in the project (the live end-of-round path
	# is _sync_player_completion → _load_next_round / _show_game_over), but it is
	# network-reachable regardless of whether any local code calls it, which is
	# exactly why the guard belongs here and not at the call sites.
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0:
		_log("⚠️ notify_game_end ignored: ending the game is a local host decision,"
			+ " peer %d cannot request it" % sender_id)
		return
	if not is_host:
		_log("⚠️ notify_game_end ignored: only the host may end the game")
		return

	game_in_progress = false
	_log("🏁 Game ended - Team " + ("Success" if team_result.get("success", false) else "Failed"))
	rpc("_broadcast_game_end", team_result)

@rpc("authority", "reliable")
func _broadcast_game_end(team_result: Dictionary) -> void:
	# Broadcast game end to all clients (from host)
	game_in_progress = false
	_log("🏁 Game ended - Team " + ("Success" if team_result.get("success", false) else "Failed"))

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_player_count() -> int:
	# Get current number of connected players
	return players.size()

func get_local_player_num() -> int:
	# Get local player number (1 or 2)
	return local_player_id

func get_player_role(player_num: int) -> String:
	# Get role for specific player
	return player_roles.get(player_num, "Unknown")

func is_multiplayer_connected() -> bool:
	# Check if currently connected to multiplayer session
	return connection_active

func is_server() -> bool:
	# Check if this instance is the server/host
	return is_host

func _log(message: String) -> void:
	# Internal logging function
	print("[NetworkManager] " + message)
	if SessionLogger:
		SessionLogger.log_entry("NetworkManager", message)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PRODUCER-CONSUMER PATTERN (Bounded Buffer)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Classic concurrency pattern for water reuse gameplay
# Player 1 (Producer/Dishwasher) → Water Queue → Player 2 (Consumer/Pipe)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal water_produced(water_data: Dictionary)
signal water_consumed(water_data: Dictionary)
signal buffer_overflow()  # Game over condition
signal buffer_empty()     # Consumer waiting

# Bounded Buffer Configuration
const BUFFER_MAX_SIZE: int = 5  # Maximum water units in transit
const BASE_TRANSFER_TIME: float = 2.0  # Base time for water to travel

# Water Queue (The Bounded Buffer)
var water_queue: Array[Dictionary] = []
## Monotonic per-producer unit id. Time.get_ticks_msec() cannot identify a unit:
## the overflow probe produced five units inside the same millisecond, so two
## distinct units shared a timestamp and _sync_water_consumed would remove the
## wrong one. This counter is what (producer_id, seq) dedupe and removal key on.
var water_seq: int = 0
## Highest seq accepted from each remote producer. seq is monotonic per producer,
## so anything at or below the watermark is a re-delivery and is dropped. One entry
## per peer, so this cannot grow without bound, and it is deliberately NOT cleared
## by reset_producer_consumer(): water_seq is never reset either, so a packet still
## in flight when a round ends cannot collide with a new unit in the next round.
var water_seq_seen: Dictionary = {}
var transfer_timers: Array[Timer] = []

# Rolling Window Integration
var current_flow_speed: float = BASE_TRANSFER_TIME
var producer_efficiency: float = 1.0  # P1's success rate
var consumer_efficiency: float = 1.0  # P2's success rate
var combined_efficiency: float = 1.0

# Statistics for difficulty adjustment
var total_produced: int = 0
var total_consumed: int = 0
var total_wasted: int = 0  # Overflow or failed consumption

func reset_producer_consumer() -> void:
	# Reset the producer-consumer state for a new game
	water_queue.clear()
	for timer in transfer_timers:
		if is_instance_valid(timer):
			timer.queue_free()
	transfer_timers.clear()
	
	current_flow_speed = BASE_TRANSFER_TIME
	producer_efficiency = 1.0
	consumer_efficiency = 1.0
	combined_efficiency = 1.0
	total_produced = 0
	total_consumed = 0
	total_wasted = 0
	
	_log("🔄 Producer-Consumer system reset")

## PRODUCER FUNCTIONS (Player 1 - Dishwasher/Water Collector)

func produce_water(water_type: String, quality: float = 1.0) -> bool:
	# Player 1 produces a water unit after completing their task.
	# Returns false if buffer is full (game over condition).
	if water_queue.size() >= BUFFER_MAX_SIZE:
		_log("❌ Buffer OVERFLOW! Queue full (%d/%d)" % [water_queue.size(), BUFFER_MAX_SIZE])
		buffer_overflow.emit()
		total_wasted += 1
		
		# Notify via RPC if multiplayer
		if connection_active:
			rpc("_notify_buffer_overflow")
		return false
	
	water_seq += 1
	var water_data = {
		"type": water_type,        # "clean", "dirty", "soapy"
		"quality": quality,         # 0.0 - 1.0 (affects P2's task)
		"timestamp": Time.get_ticks_msec(),
		"producer_id": local_player_id,
		"seq": water_seq,
	}
	
	water_queue.append(water_data)
	total_produced += 1
	
	_log("💧 Water PRODUCED: %s (Quality: %.1f) - Queue: %d/%d" % [
		water_type, quality, water_queue.size(), BUFFER_MAX_SIZE
	])
	
	water_produced.emit(water_data)
	
	# Start transfer timer (water traveling through pipe)
	_start_transfer_timer(water_data)
	
	# Sync to network
	if connection_active:
		rpc("_sync_water_produced", water_data)
	
	return true

func _start_transfer_timer(water_data: Dictionary) -> void:
	# Create a timer for water transfer (visual delay between P1 and P2)
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = current_flow_speed
	timer.timeout.connect(func():
		transfer_timers.erase(timer)
		timer.queue_free()
		_on_water_arrives(water_data)
	)
	add_child(timer)
	transfer_timers.append(timer)
	timer.start()
	
	_log("⏱️ Water transfer started (%.1fs)" % current_flow_speed)

func _on_water_arrives(water_data: Dictionary) -> void:
	# Called when water arrives at Player 2's station
	_log("🚿 Water ARRIVED at Consumer station")
	
	# Notify Player 2 (Consumer) that they have water to process
	if connection_active:
		rpc("_notify_water_arrived", water_data)
	else:
		# Local testing
		_receive_water_for_consumption(water_data)

@rpc("any_peer", "reliable")
func _notify_water_arrived(water_data: Dictionary) -> void:
	# RPC: Notify consumer that water has arrived
	if local_player_id == 2:  # Only consumer receives this
		_receive_water_for_consumption(water_data)

func _receive_water_for_consumption(water_data: Dictionary) -> void:
	# Consumer receives water to process
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("on_water_received"):
		current_scene.on_water_received(water_data)

## CONSUMER FUNCTIONS (Player 2 - Pipe Manager/Water User)

func consume_water(success: bool) -> Dictionary:
	# Player 2 consumes a water unit from the queue.
	# Returns the water data that was consumed.
	if water_queue.is_empty():
		_log("⚠️ Buffer EMPTY! No water to consume")
		buffer_empty.emit()
		return {}
	
	var water_data = water_queue.pop_front()
	
	if success:
		total_consumed += 1
		_log("✅ Water CONSUMED successfully: %s" % water_data.type)
	else:
		total_wasted += 1
		_log("❌ Water WASTED: %s" % water_data.type)
	
	water_data["consumed_success"] = success
	water_consumed.emit(water_data)
	
	# Sync to network
	if connection_active:
		rpc("_sync_water_consumed", water_data, success)
	
	return water_data

## Shape check for a water unit arriving over the wire. Both sync handlers are
## @rpc("any_peer"), so the partner — or NetworkFaultSimulator's deliberate invalid
## message injection — can hand us anything. The old handlers read water_data.producer_id
## as a property, which on a Dictionary without that key is a hard runtime error, not a
## null: sending {} was enough to fault the other side. Validate, log, drop.
func _water_payload_valid(water_data: Dictionary, where: String) -> bool:
	for key in ["type", "quality", "producer_id", "seq"]:
		if not water_data.has(key):
			_log("⚠️ %s: dropped malformed water payload (missing '%s')" % [where, key])
			return false
	if typeof(water_data["producer_id"]) != TYPE_INT or typeof(water_data["seq"]) != TYPE_INT:
		_log("⚠️ %s: dropped water payload with non-integer identity" % where)
		return false
	return true

@rpc("any_peer", "reliable")
func _sync_water_produced(water_data: Dictionary) -> void:
	# RPC: Sync water production to other player
	if not _water_payload_valid(water_data, "_sync_water_produced"):
		return
	if local_player_id == water_data["producer_id"]:
		return  # our own unit echoing back; it is already in our queue
	# The G-Counter tolerates re-delivery because merge takes MAX. This queue APPENDS, so
	# it has no such property: a re-delivered production sync consumed a slot in the
	# 5-slot bounded buffer that the producer never filled, and overflow is a fail state,
	# so the duplicate could push the team into a loss they did not cause. Verified:
	# re-sending one identical sync took the consumer's queue from 1 to 2.
	var producer: int = water_data["producer_id"]
	var seq: int = water_data["seq"]
	if seq <= int(water_seq_seen.get(producer, 0)):
		_log("📡 Duplicate water production sync ignored (producer %d seq %d)" % [producer, seq])
		return
	water_seq_seen[producer] = seq
	water_queue.append(water_data)
	water_produced.emit(water_data)
	_log("📡 Received water production sync")

@rpc("any_peer", "reliable")
func _sync_water_consumed(water_data: Dictionary, success: bool) -> void:
	# RPC: Sync water consumption to other player
	if not _water_payload_valid(water_data, "_sync_water_consumed"):
		return
	# Remove from queue if we have it. Matched on (producer_id, seq), not timestamp:
	# Time.get_ticks_msec() is not unique — five units were observed sharing one
	# millisecond — so a timestamp match could remove a different unit than the one
	# actually consumed, silently corrupting the buffer contents.
	for i in range(water_queue.size()):
		var unit: Dictionary = water_queue[i]
		if unit.get("producer_id", -1) == water_data["producer_id"] \
				and unit.get("seq", -1) == water_data["seq"]:
			water_queue.remove_at(i)
			break
	
	water_data["consumed_success"] = success
	water_consumed.emit(water_data)
	_log("📡 Received water consumption sync")

@rpc("any_peer", "reliable")
func _notify_buffer_overflow() -> void:
	# RPC: Notify all players of buffer overflow
	buffer_overflow.emit()
	_log("📡 Buffer overflow notification received")

## ROLLING WINDOW INTEGRATION (Difficulty Adjustment)

func update_flow_speed(new_speed: float) -> void:
	# Update the transfer speed based on Rolling Window algorithm
	current_flow_speed = clampf(new_speed, 0.5, 5.0)
	_log("🌊 Flow speed updated: %.2fs" % current_flow_speed)
	
	# Sync to network
	if connection_active and is_host:
		rpc("_sync_flow_speed", current_flow_speed)

@rpc("authority", "reliable")
func _sync_flow_speed(speed: float) -> void:
	# RPC: Sync flow speed from host
	current_flow_speed = speed
	_log("📡 Flow speed synced: %.2fs" % speed)

func update_player_efficiency(player_num: int, efficiency: float) -> void:
	# Update a player's efficiency rating (0.0-1.0)
	if player_num == 1:
		producer_efficiency = clampf(efficiency, 0.0, 1.0)
	else:
		consumer_efficiency = clampf(efficiency, 0.0, 1.0)
	
	# Calculate combined team efficiency
	combined_efficiency = (producer_efficiency + consumer_efficiency) / 2.0
	
	_log("📊 Efficiency updated - P1: %.0f%%, P2: %.0f%%, Team: %.0f%%" % [
		producer_efficiency * 100, consumer_efficiency * 100, combined_efficiency * 100
	])

func calculate_difficulty_adjustment() -> float:
	# Rolling Window: Calculate difficulty adjustment based on team performance.
	# Returns multiplier for flow_speed (lower = harder, faster flow)
	# If team is doing well, speed up (decrease time)
	# If team is struggling, slow down (increase time)
	
	var success_rate = 0.0
	if total_produced > 0:
		success_rate = float(total_consumed) / float(total_produced)
	
	var adjustment = 1.0
	
	if success_rate > 0.9:
		adjustment = 0.85  # Speed up 15%
	elif success_rate > 0.75:
		adjustment = 0.95  # Speed up 5%
	elif success_rate < 0.5:
		adjustment = 1.15  # Slow down 15%
	elif success_rate < 0.65:
		adjustment = 1.05  # Slow down 5%
	
	return adjustment

func get_buffer_status() -> Dictionary:
	# Get current buffer status for UI display
	return {
		"current_size": water_queue.size(),
		"max_size": BUFFER_MAX_SIZE,
		"fill_percentage": float(water_queue.size()) / float(BUFFER_MAX_SIZE),
		"flow_speed": current_flow_speed,
		"total_produced": total_produced,
		"total_consumed": total_consumed,
		"total_wasted": total_wasted
	}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SYNCHRONIZED PAUSE SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## One authority, one state, idempotent transitions.
##
## The old design had three independent write paths - request_pause() rpc'ing
## _execute_pause to everyone, request_resume() taking a different route per peer, and
## a separate legacy sync_pause_state() used by five of the minigames - and none of them
## checked whether the state was already what they were about to set. Any repeat became
## another broadcast and another log line.
##
## Session log session_2026-09-05T00-27-36.json caught what that costs. Round 20
## (MP_CollectDishWater) logged Pause->Resume pairs every 100-300 ms for six seconds
## straight, plus "Game resumed" twice in a row with no pause between. Two things fed it:
##
##   1. AutoPlayManager._try_resume_from_pause() calls the round's _on_resume_pressed()
##      from _process() - which runs while the tree is paused, by design - and in
##      multiplayer that is NetworkManager.request_resume(). A resume is a network
##      round trip, so the tree stayed paused for several frames and the bot sent one
##      request per frame. That is where the duplicate "Game resumed" lines come from.
##   2. MultiplayerMiniGameBase's HUD pause button ships with text = "" (see
##      _create_hud), so it is an invisible 50-unit hit area in the top-right corner of
##      a tap-driven minigame. Gameplay taps landing on it re-paused as fast as the bot
##      un-paused.
##
## Both are fixed at their own site as well, but this is the layer that makes the class
## of bug impossible: the host owns `_pause_active`, a request that does not change it
## is dropped before it reaches the wire, and _apply_pause_state() returns early when
## the incoming state already matches. So one user action produces exactly one
## transition and exactly one log line, whatever the callers do.

## Whether the co-op round is currently paused. Host-authoritative: clients mirror it
## from _apply_pause_state() and never write it themselves.
var _pause_active: bool = false

## Who asked for the pause that is currently in force. "" when not paused.
## A DELIBERATE pause (a player pressing the pause glyph, either side) must survive
## AutoPlayManager's deadlock guard - that guard exists for pauses with no overlay to
## dismiss, not for a human deciding to stop. This is what makes autoplay pausable.
var _pause_source: String = ""

const PAUSE_SOURCE_PLAYER := "player"


func is_paused() -> bool:
	return _pause_active


## True while the pause in force came from an explicit player action, on either peer.
## AutoPlayManager reads this so the bot leaves a human's pause alone.
func is_pause_deliberate() -> bool:
	return _pause_active and _pause_source == PAUSE_SOURCE_PLAYER


func request_pause(source: String = PAUSE_SOURCE_PLAYER) -> void:
	# Either player may ask; the host decides. Dropped when already paused, so a
	# repeated press or a stray double-tap cannot produce a second transition.
	if _pause_active:
		return
	if is_host:
		_set_pause_authoritative(true, source)
	else:
		rpc_id(1, "_request_pause_state", true, source)


func request_resume() -> void:
	# Resume only ever originates from an explicit user action reaching this function.
	# Nothing in the pause broadcast path calls it, so a peer receiving a pause can no
	# longer answer with a resume.
	if not _pause_active:
		return
	if is_host:
		_set_pause_authoritative(false, "")
	else:
		rpc_id(1, "_request_pause_state", false, "")


## The host's decision point. The only place `_pause_active` changes on the authority.
func _set_pause_authoritative(paused: bool, source: String) -> void:
	if not is_host:
		return
	if _pause_active == paused:
		return
	_pause_source = source if paused else ""
	rpc("_apply_pause_state", paused, _pause_source)


@rpc("any_peer", "reliable")
func _request_pause_state(paused: bool, source: String) -> void:
	# Client -> host request. Guarded so a client cannot forge a state change for a
	# peer it does not own, and so a request that matches the current state is dropped
	# here rather than echoed back out to everyone.
	if not is_host:
		return
	_set_pause_authoritative(paused, source)


@rpc("authority", "call_local", "reliable")
func _apply_pause_state(paused: bool, source: String) -> void:
	# Idempotent by contract: a repeat of the state already in force is not a
	# transition, so it neither touches the tree, nor logs, nor notifies the scene.
	if _pause_active == paused:
		return
	_pause_active = paused
	_pause_source = source
	get_tree().paused = paused

	_log("⏸️ Game paused" if paused else "▶️ Game resumed")

	var current_scene = get_tree().current_scene
	if current_scene == null:
		return
	if paused and current_scene.has_method("_on_remote_pause"):
		current_scene.call("_on_remote_pause")
	elif not paused and current_scene.has_method("_on_remote_resume"):
		current_scene.call("_on_remote_resume")


## Legacy entry point kept for the five MiniGame_* co-op scripts that call
## `NetworkManager.rpc("sync_pause_state", bool)` directly. It used to be a second,
## parallel write path that set no state and only poked the scene; it now funnels into
## the one authority above so those scenes cannot diverge from it.
@rpc("any_peer", "call_local", "reliable")
func sync_pause_state(paused: bool) -> void:
	if paused:
		request_pause(PAUSE_SOURCE_PLAYER)
	else:
		request_resume()


## Clears the pause bookkeeping when a round or session ends, so a fresh round never
## starts holding a stale pause (and `is_pause_deliberate()` cannot report a pause that
## no longer exists).
func clear_pause_state() -> void:
	_pause_active = false
	_pause_source = ""


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SHARED-TARGET ROUND END
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Ends the round on BOTH peers the moment the shared objective is done.
##
## `win_quota` in MultiplayerMiniGameBase is a TEAM target measured against the G-Counter
## total, so once it is met the round's objective is finished for the pair - there is
## nothing left for the other player to accomplish. It was only ever acted on locally:
## the peer whose point crossed the line called end_game(true) and the partner kept
## playing until their own timer expired.
##
## session_2026-09-05T00-27-36.json, round 18 (MP_CollectDishWater): "Quota met!
## (50/50 team)" and "Player ... completed" at t=824.4s, the partner's completion at
## t=849.1s, "Round Complete" at t=849.1s. Twenty-five seconds in which both scores were
## already locked in and neither player could affect the result.
##
## Only the host decides, so the two peers cannot reach different verdicts from the same
## G-Counter reading, and `_shared_target_reached` makes it once-per-round.
var _shared_target_reached: bool = false


func report_shared_target_reached(success: bool) -> void:
	# Called by the peer that observed the team quota being met. Idempotent per round.
	if _shared_target_reached:
		return
	if is_host:
		_end_round_for_both(success)
	else:
		rpc_id(1, "_request_shared_target_end", success)


@rpc("any_peer", "reliable")
func _request_shared_target_end(success: bool) -> void:
	if not is_host:
		return
	_end_round_for_both(success)


func _end_round_for_both(success: bool) -> void:
	if not is_host or _shared_target_reached:
		return
	_shared_target_reached = true
	rpc("_apply_shared_target_end", success)


@rpc("authority", "call_local", "reliable")
func _apply_shared_target_end(success: bool) -> void:
	_shared_target_reached = true
	_log("🏁 Shared target reached — closing the round on both peers")
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("end_game"):
		# end_game() already no-ops when the round is not active, so the peer that
		# triggered this is not double-reported.
		current_scene.call("end_game", success)


func clear_shared_target() -> void:
	_shared_target_reached = false



# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SYNCHRONIZED COUNTDOWN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func start_countdown() -> void:
	# Start synchronized countdown (3-2-1-GO!) before round (host only)
	if not is_host:
		return

	# One chain per round. Both legitimate callers ask for the same countdown — the
	# "both players ready" route and MultiplayerMiniGameBase's 6 s partner-ready
	# timeout fallback — and the fallback cannot tell that the first already fired,
	# because it tests game_active, which only turns true a second after the GO tick.
	# Suppressing here rather than removing the fallback: the fallback still does its
	# job when the client's ready RPC really is lost, since nothing set this flag.
	# Cleared per round by _reset_round_status().
	if _countdown_started_this_round:
		_log("⏱️ Countdown already started for this round — duplicate request ignored")
		return
	_countdown_started_this_round = true

	_log("⏱️ Starting countdown...")
	rpc("_execute_countdown", 3)

@rpc("authority", "call_local", "reliable")
func _execute_countdown(count: int) -> void:
	# Execute countdown on all clients
	round_starting.emit(count)
	_log("⏱️ Countdown: %d" % count)
	
	if count > 0:
		await get_tree().create_timer(COUNTDOWN_TICK_SECONDS).timeout
		if is_host:
			rpc("_execute_countdown", count - 1)
	else:
		_log("🎮 GO! Round started")
		# The current scene already receives round_starting and handles GO locally.

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ROUND MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func complete_round() -> void:
	# Mark round as complete and show results (host only)
	if not is_host:
		return
	
	rounds_survived += 1
	
	# Get individual scores (handle only 2 players)
	var p1_score = 0
	var p2_score = 0
	for peer_id in g_counter:
		var player_num = players.get(peer_id, {}).get("player_num", 0)
		if player_num == 1:
			p1_score = g_counter[peer_id]
		elif player_num == 2:
			p2_score = g_counter[peer_id]
	
	var team_total = get_total_score()
	
	# Accumulate into session totals
	mp_session_p1_score += p1_score
	mp_session_p2_score += p2_score

	_log("🏁 Round %d done! P1:%d P2:%d Total:%d"
		% [rounds_survived, p1_score,
			p2_score, team_total])
	
	# Broadcast round completion (includes session totals so clients stay in sync)
	rpc("_show_round_results", p1_score, p2_score, team_total, rounds_survived,
		mp_session_p1_score, mp_session_p2_score)

@rpc("authority", "call_local", "reliable")
func _show_round_results(p1_score: int, p2_score: int, team_total: int, rounds: int,
		session_p1_total: int = 0, session_p2_total: int = 0) -> void:
	# Sync session accumulators on the client side
	mp_session_p1_score = session_p1_total
	mp_session_p2_score = session_p2_total
	# Show round results on all clients
	round_completed.emit(p1_score, p2_score, team_total)
	var my_total: int = g_counter.get(multiplayer.get_unique_id(), 0)
	_log(("📊 Round %d results - Your score: %d | Partner: %d | Team: %d"
			+ " | Session P1: %d | Session P2: %d") % [
		rounds,
		my_total,
		team_total - my_total,
		team_total,
		session_p1_total,
		session_p2_total
	])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTERCONNECTION SYSTEM (Resource Transfer)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal resource_sent(from_player: int, resource_type: String, amount: int, quality: float)
signal task_marked(from_player: int, task_id: int, position: Vector2)

func send_resource(resource_type: String, amount: int, quality: float = 1.0) -> void:
	# Send resource to partner player (e.g., water, greywater)
	var my_player_num = _get_player_num(multiplayer.get_unique_id())
	_log("💧 Sending: %s (x%d, q:%.1f) from P%d"
		% [resource_type, amount,
			quality, my_player_num])
	rpc("_receive_resource", my_player_num, resource_type, amount, quality)

@rpc("any_peer", "reliable")
func _receive_resource(
	from_player: int, resource_type: String,
	amount: int, quality: float
) -> void:
	# Receive resource from partner
	if not _sender_is_player_num(from_player, "_receive_resource"):
		return
	resource_sent.emit(from_player, resource_type, amount, quality)
	_log("📥 Received resource: %s (x%d) from P%d" % [resource_type, amount, from_player])

func mark_task(task_id: int, task_position: Vector2) -> void:
	# Mark a task for partner to complete (e.g., leak spotted, tap found)
	var my_player_num = _get_player_num(multiplayer.get_unique_id())
	_log("🎯 Marking task #%d at %s for partner" % [task_id, task_position])
	rpc("_receive_task_mark", my_player_num, task_id, task_position)

@rpc("any_peer", "reliable")
func _receive_task_mark(from_player: int, task_id: int, position: Vector2) -> void:
	# Receive task mark from partner
	if not _sender_is_player_num(from_player, "_receive_task_mark"):
		return
	task_marked.emit(from_player, task_id, position)
	_log("📍 Task #%d marked by P%d at %s" % [task_id, from_player, position])

func _get_player_num(peer_id: int) -> int:
	# Helper to get player number from peer ID
	return players.get(peer_id, {}).get("player_num", 0)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ROUND COMPLETION & COORDINATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal both_players_completed(p1_success: bool, p2_success: bool, p1_score: int, p2_score: int)

var round_completion_status: Dictionary = {} # {peer_id: {success: bool, score: int}}
var round_in_progress: bool = false

func start_round() -> void:
	# Mark round as started (host only)
	if not is_host:
		return
	
	round_in_progress = true
	round_completion_status.clear()
	_log("🎮 Round started")

func report_player_completion(success: bool, score: int, accuracy: float = -1.0,
		reaction_time_ms: int = -1) -> void:
	# Report that local player has completed their game
	if not round_in_progress:
		round_in_progress = true
	
	var my_id = multiplayer.get_unique_id()
	round_completion_status[my_id] = {
		"success": success,
		"score": score,
		"accuracy": accuracy,
		"reaction_time_ms": reaction_time_ms
	}
	
	var status_str = "Success" if success else "Failed"
	_log("✅ Player %d completed (%s, score: %d)"
		% [my_id, status_str, score])
	
	# Notify other players
	rpc("_sync_player_completion", my_id, success, score, accuracy, reaction_time_ms)
	
	# Check if both completed
	_check_both_completed()

@rpc("any_peer", "reliable")
func _sync_player_completion(peer_id: int, success: bool, score: int,
		accuracy: float = -1.0, reaction_time_ms: int = -1) -> void:
	# Receive completion report from remote player
	# Identity enforced: this dictionary is what _check_both_completed() reads to
	# decide life loss, and what feeds _apply_rolling_window_adjustment() and
	# CoopAdaptation. A report filed under someone else's peer id would corrupt the
	# adaptive-difficulty input with performance that player never produced.
	if not _sender_owns(peer_id, "_sync_player_completion"):
		return
	round_completion_status[peer_id] = {
		"success": success,
		"score": score,
		"accuracy": accuracy,
		"reaction_time_ms": reaction_time_ms
	}
	var status_str = "Success" if success else "Failed"
	_log("📡 Player %d completed (%s, score: %d)"
		% [peer_id, status_str, score])
	
	_check_both_completed()

func _check_both_completed() -> void:
	# Check if both players have completed their games
	if round_completion_status.size() < 2:
		return  # Still waiting for other player
	
	round_in_progress = false
	
	# Get results
	var p1_data = round_completion_status.get(1, {"success": false, "score": 0})
	var p2_data = round_completion_status.get(2, {"success": false, "score": 0})
	
	# Find peer IDs for each player
	for peer_id in round_completion_status:
		var player_num = players.get(peer_id, {}).get("player_num", 0)
		if player_num == 1:
			p1_data = round_completion_status[peer_id]
		elif player_num == 2:
			p2_data = round_completion_status[peer_id]
	
	var p1_success = p1_data.get("success", false)
	var p2_success = p2_data.get("success", false)
	var p1_score = p1_data.get("score", 0)
	var p2_score = p2_data.get("score", 0)
	
	_log("🏁 Both players completed - P1: %s (%d), P2: %s (%d)" % [
		"Win" if p1_success else "Fail", p1_score,
		"Win" if p2_success else "Fail", p2_score
	])
	
	# Handle life deduction (only host)
	if is_host:
		if not p1_success and not p2_success:
			# Both failed: deduct 1 life
			lose_life()
		elif not p1_success or not p2_success:
			# One failed: deduct 1 life
			lose_life()
		# Both succeeded: no life loss
		
		# Calculate difficulty adjustment with rolling window
		_apply_rolling_window_adjustment(p1_success, p2_success, p1_score, p2_score)
		
		# ── CoopAdaptation algorithm feed ──────────────────────────────
		# Resolve accuracy (use passed value, or fallback to score/100)
		var p1_acc: float = p1_data.get("accuracy", -1.0)
		var p2_acc: float = p2_data.get("accuracy", -1.0)
		if p1_acc < 0.0: p1_acc = clamp(float(p1_score) / 100.0, 0.0, 1.0)
		if p2_acc < 0.0: p2_acc = clamp(float(p2_score) / 100.0, 0.0, 1.0)
		# Resolve reaction time in seconds (fallback: 15s midpoint)
		var p1_rt_ms: int = p1_data.get("reaction_time_ms", -1)
		var p2_rt_ms: int = p2_data.get("reaction_time_ms", -1)
		var p1_time_s: float = float(p1_rt_ms) / 1000.0 if p1_rt_ms > 0 else 15.0
		var p2_time_s: float = float(p2_rt_ms) / 1000.0 if p2_rt_ms > 0 else 15.0
		var team_success: bool = p1_success and p2_success
		var coop = get_node_or_null("/root/CoopAdaptation")
		if coop and coop.has_method("add_game_result"):
			coop.add_game_result(
				{"accuracy": p1_acc, "time": p1_time_s, "errors": 0},
				{"accuracy": p2_acc, "time": p2_time_s, "errors": 0},
				team_success
			)
			_log("🧠 CoopAdaptation fed: P1 Φ(acc=%.2f, t=%.1fs) P2 Φ(acc=%.2f, t=%.1fs) team=%s"
				% [p1_acc, p1_time_s, p2_acc, p2_time_s, str(team_success)])
		# Increment rounds
		rounds_survived += 1
	
	# Award droplets to local player for MP round
	var save_mgr = get_node_or_null("/root/SaveManager")
	var gm = get_node_or_null("/root/GameManager")
	var my_id_check = multiplayer.get_unique_id()
	var my_data: Dictionary = {}
	for pid in round_completion_status:
		if pid == my_id_check:
			my_data = round_completion_status[pid]
			break
	var my_score: int = my_data.get("score", 0)
	if my_score > 0 and save_mgr and save_mgr.has_method("add_droplets"):
		var earned: int = int(max(1, my_score / 10.0))
		save_mgr.add_droplets(earned)
		if gm and gm.has_method("add_session_droplets"):
			gm.add_session_droplets(earned)
		_log("💧 MP droplets awarded: %d (from score %d)" % [earned, my_score])
	
	# Emit signal
	both_players_completed.emit(p1_success, p2_success, p1_score, p2_score)
	
	# Show round results
	if is_host:
		await get_tree().create_timer(2.0).timeout
		_transition_to_next_round()

func _apply_rolling_window_adjustment(
	p1_success: bool, p2_success: bool,
	_p1_score: int, _p2_score: int
) -> void:
	# Apply rolling window rule-based difficulty adjustment
	var team_success_rate = 0.0
	var success_count = 0
	
	if p1_success: success_count += 1
	if p2_success: success_count += 1
	
	team_success_rate = success_count / 2.0
	
	# Update efficiency metrics
	producer_efficiency = 1.0 if p1_success else 0.5
	consumer_efficiency = 1.0 if p2_success else 0.5
	combined_efficiency = (producer_efficiency + consumer_efficiency) / 2.0
	
	# Rule-based adjustment
	var _difficulty_change = "MAINTAIN"  # Prefixed with _ to indicate intentionally unused
	
	if team_success_rate >= 1.0:
		# Both succeeded - make harder
		_difficulty_change = "HARDER"
		current_flow_speed = max(0.5, current_flow_speed * 0.85)
		_log("📈 Difficulty increased! Both succeeded. Flow speed: %.2fs" % current_flow_speed)
	elif team_success_rate == 0.0:
		# Both failed - make easier
		_difficulty_change = "EASIER"
		current_flow_speed = min(5.0, current_flow_speed * 1.2)
		_log("📉 Difficulty decreased! Both failed. Flow speed: %.2fs" % current_flow_speed)
	else:
		# Mixed results - maintain
		_log("➡️ Difficulty maintained. Mixed results.")
	
	# Sync to clients
	rpc("_sync_difficulty", current_flow_speed, combined_efficiency)

@rpc("authority", "reliable")
func _sync_difficulty(flow_speed: float, efficiency: float) -> void:
	# Sync difficulty settings from host
	current_flow_speed = flow_speed
	combined_efficiency = efficiency
	_log("📡 Difficulty synced - Speed: %.2fs, Efficiency: %.0f%%" % [flow_speed, efficiency * 100])

func _transition_to_next_round() -> void:
	# Transition to next round (host only)
	if not is_host:
		return
	
	# Check if game over
	if team_lives <= 0:
		_log("💀 GAME OVER - Team ran out of lives!")
		rpc("_show_game_over")
		return
	
	# Load next level set
	if not LevelSets or not LevelSets.has_method("get_random_level_set"):
		push_error("LevelSets autoload not found!")
		return
	
	var level_set = LevelSets.get_random_level_set()
	
	# Roles are assigned inside the _load_next_round() body below instead of here: that body is
	# call_local, so the same assignment runs on the host and on the client from one place. The
	# host-only version this replaces left the client on the connect-time placeholder all session.
	
	# The G-Counter is NOT reset here any more (see round_score_baseline). What the next round
	# needs is the total it starts from, and the host is the one that decides it: the value
	# below travels with the round-load broadcast, so both peers measure the same quota against
	# the same baseline.
	# Re-stated with the round it applies to, so "both peers time the same round" is a
	# property of the start broadcast rather than something inferred from an earlier sync.
	# Reliable RPCs on one channel are ordered, so this lands before the scene load below,
	# and _sync_mp_round_seconds() early-returns when the value is already what the peer has.
	rpc("_sync_mp_round_seconds", mp_round_seconds)
	rpc("_load_next_round", level_set, get_total_score(), team_lives, rounds_survived)

@rpc("authority", "call_local", "reliable")
func _load_next_round(level_set: Dictionary, round_baseline: int, lives: int, rounds: int) -> void:
	# Load next round for all players
	# The host's total as this round begins. Both peers run this body, so both start the round
	# measuring from the same number; this parameter used to be received and thrown away.
	round_score_baseline = round_baseline
	# Clear stale round completion and ready state BEFORE changing scenes
	_reset_round_status()
	# Both peers run this body, so this is where the round's roles land — the host's own copy
	# included. LevelSets swapped the pair for this round number before it was broadcast.
	assign_round_roles(level_set)
	

	var my_player_num = get_local_player_num()
	var my_game_scene: String
	
	if my_player_num == 1:
		my_game_scene = level_set["player1_game"]
	else:
		my_game_scene = level_set["player2_game"]
	
	_log("🎮 Loading round %d: %s (Lives: %d)"
		% [rounds + 1, my_game_scene, lives])
	
	if ResourceLoader.exists(my_game_scene):
		get_tree().change_scene_to_file(my_game_scene)
	else:
		push_error("Game scene not found: " + my_game_scene)

@rpc("authority", "call_local", "reliable")
func _show_game_over() -> void:
	# Show game over on all clients
	_log("💀 GAME OVER - Rounds: %d, Score: %d" % [rounds_survived, get_total_score()])
	
	# The game scene will show the game over screen
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("_show_game_over_screen"):
		current_scene.call("_show_game_over_screen")
