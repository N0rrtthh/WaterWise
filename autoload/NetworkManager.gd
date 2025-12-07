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

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 2
const RECONNECT_GRACE_PERIOD: float = 30.0  # 30 seconds

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

# Game session
var current_scenario_id: String = ""
var game_in_progress: bool = false

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
	
	_log("NetworkManager initialized")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HOST/SERVER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func create_server(port: int = DEFAULT_PORT) -> bool:
	"""Create a server (host) for LAN multiplayer"""
	if connection_active:
		_log("❌ Server already running or connected to another server")
		return false
	
	network = ENetMultiplayerPeer.new()
	var error = network.create_server(port, MAX_PLAYERS - 1)  # -1 because host counts as one player
	
	if error != OK:
		_log("❌ Failed to create server: " + str(error))
		connection_failed.emit()
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
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	_log("✅ Server created on port " + str(port))
	_log("🎮 You are Player 1 (Collector)")
	connection_succeeded.emit()
	return true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLIENT FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func join_server(ip: String, port: int = DEFAULT_PORT) -> bool:
	"""Join an existing server (client)"""
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
	"""Called when client successfully connects to server"""
	_log("✅ Connected to server!")
	_log("🎮 You are Player 2 (User)")
	
	# Register self with server
	rpc_id(1, "_register_player", multiplayer.get_unique_id(), "Player 2 (Client)")
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	"""Called when client fails to connect"""
	_log("❌ Connection failed!")
	connection_active = false
	connection_failed.emit()

func _on_server_disconnected() -> void:
	"""Called when server disconnects (client side)"""
	_log("⚠️ Server disconnected!")
	_start_grace_period()
	server_disconnected.emit()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONNECTION MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_player_connected(peer_id: int) -> void:
	"""Called on server when a player connects"""
	if players.size() >= MAX_PLAYERS:
		_log("❌ Max players reached, rejecting connection")
		network.disconnect_peer(peer_id)
		return
	
	remote_player_id = peer_id
	_log("✅ Player connected (Peer ID: " + str(peer_id) + ")")

@rpc("any_peer", "reliable")
func _register_player(peer_id: int, player_name: String) -> void:
	"""Register a new player (called by client, executed on server)"""
	if not is_host:
		return
	
	players[peer_id] = {
		"player_num": 2,
		"ready": false,
		"name": player_name
	}
	
	# Sync player list to all clients
	rpc("_sync_player_list", players)
	player_connected.emit(peer_id, 2)

@rpc("authority", "reliable")
func _sync_player_list(updated_players: Dictionary) -> void:
	"""Sync player list from server to clients"""
	players = updated_players
	_log("Player list synced: " + str(players.size()) + " players")

func _on_player_disconnected(peer_id: int) -> void:
	"""Called when a player disconnects"""
	_log("⚠️ Player disconnected (Peer ID: " + str(peer_id) + ")")
	
	if players.has(peer_id):
		var _player_num = players[peer_id]["player_num"]
		players.erase(peer_id)
		player_disconnected.emit(peer_id)
		
		# Start grace period if game is in progress
		if game_in_progress:
			_start_grace_period()

func _start_grace_period() -> void:
	"""Start reconnection grace period"""
	if grace_period_active:
		return
	
	grace_period_active = true
	disconnection_timer.start()
	_log("⏱️ Reconnection grace period started (" + str(RECONNECT_GRACE_PERIOD) + " seconds)")

func _on_grace_period_timeout() -> void:
	"""Called when grace period expires"""
	grace_period_active = false
	_log("⏰ Grace period expired - game failed")
	
	if game_in_progress:
		# Auto-fail the game
		game_in_progress = false
		# Trigger game failure (implement in game scene)

func disconnect_multiplayer() -> void:
	"""Disconnect from multiplayer session"""
	if not connection_active:
		return
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	
	network = null
	is_host = false
	connection_active = false
	players.clear()
	game_in_progress = false
	
	_log("🔌 Disconnected from multiplayer")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# READY SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func set_ready(is_ready: bool) -> void:
	"""Set local player ready status"""
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
	"""Sync ready status across network"""
	if players.has(peer_id):
		players[peer_id]["ready"] = is_ready
		
		# Emit signal so UI can update
		player_ready_changed.emit(peer_id, is_ready)
		
		# If host, broadcast to all clients
		if is_host:
			rpc("_sync_ready_status", peer_id, is_ready)
		
		_check_all_ready()

func _check_all_ready() -> void:
	"""Check if all players are ready"""
	if players.size() < MAX_PLAYERS:
		return
	
	for player_data in players.values():
		if not player_data["ready"]:
			return
	
	_log("✅ All players ready!")
	both_players_ready.emit()

func are_all_players_ready() -> bool:
	"""Check if all players are ready"""
	if players.size() < MAX_PLAYERS:
		return false
	
	for player_data in players.values():
		if not player_data["ready"]:
			return false
	
	return true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME SESSION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func start_game(scenario_id: String) -> void:
	"""Start cooperative game session (host only)"""
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
	"""Start multiplayer game and load scene on all clients (host only)"""
	if not is_host:
		_log("❌ Only host can start the game")
		return
	
	if not are_all_players_ready():
		_log("❌ Not all players are ready")
		return
	
	game_in_progress = true
	
	# Load scene on all clients (including host with call_local)
	rpc("_load_game_scene", scene_path)
	_log("🎮 Loading game scene on all players: " + scene_path)

@rpc("authority", "call_local", "reliable")
func _load_game_scene(scene_path: String) -> void:
	"""Load game scene on this peer"""
	_log("📥 Loading game scene: " + scene_path)
	
	var packed_scene = load(scene_path)
	if packed_scene == null:
		_log("❌ Failed to load scene: " + scene_path)
		return
	
	var result = get_tree().change_scene_to_packed(packed_scene)
	if result != OK:
		_log("❌ Failed to change scene, error code: " + str(result))

@rpc("authority", "reliable")
func _receive_game_start(scenario_id: String, roles: Dictionary) -> void:
	"""Receive game start signal (client side)"""
	current_scenario_id = scenario_id
	game_in_progress = true
	player_roles = roles
	
	_log("🎮 Game started: " + scenario_id)
	game_started.emit(scenario_id, roles)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# G-COUNTER IMPLEMENTATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func reset_g_counter() -> void:
	"""Reset G-Counter for new game session"""
	g_counter.clear()
	var my_id = multiplayer.get_unique_id()
	g_counter[my_id] = 0
	_log("🔄 G-Counter reset")

func increment_local(amount: int) -> void:
	"""
	Increment local player's counter (CRDT operation)
	Each player only increments their own counter
	"""
	var my_id = multiplayer.get_unique_id()
	g_counter[my_id] = g_counter.get(my_id, 0) + amount
	
	_log("💧 Local score +%d → G-Counter[%d] = %d" % [amount, my_id, g_counter[my_id]])
	
	# Broadcast merge to all peers
	rpc("_merge_counter", my_id, g_counter[my_id])
	
	# Emit signal for UI update
	team_score_updated.emit(get_total_score())

@rpc("any_peer", "reliable")
func _merge_counter(peer_id: int, value: int) -> void:
	"""
	Merge counter value from remote peer (CRDT merge operation)
	Takes MAX of existing and new value to ensure monotonic growth
	"""
	var old_value = g_counter.get(peer_id, 0)
	g_counter[peer_id] = max(old_value, value)
	
	if g_counter[peer_id] > old_value:
		_log("📡 Merged counter[%d]: %d → %d" % [peer_id, old_value, g_counter[peer_id]])
		team_score_updated.emit(get_total_score())

func get_total_score() -> int:
	"""Calculate global score = sum of all peer counters"""
	var total = 0
	for count in g_counter.values():
		total += count
	return total

func get_player_score(peer_id: int) -> int:
	"""Get individual player's score"""
	return g_counter.get(peer_id, 0)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SHARED LIVES SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func reset_team_lives() -> void:
	"""Reset team lives for new game session (host only)"""
	if not is_host:
		return
	
	team_lives = START_TEAM_LIVES
	rounds_survived = 0
	_log("❤️ Team lives reset to %d" % team_lives)
	
	# Sync to all clients
	rpc("_sync_team_lives", team_lives)

func lose_life() -> void:
	"""
	Team loses a life (called by any player when they fail)
	Only host has authority to modify lives
	"""
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
	"""Client requests host to deduct a life"""
	if is_host:
		lose_life()

@rpc("authority", "call_local", "reliable")
func _sync_team_lives(lives: int) -> void:
	"""Sync team lives from host to all clients"""
	team_lives = lives
	team_lives_updated.emit(team_lives)
	_log("📡 Team lives synced: %d" % lives)

@rpc("authority", "call_local", "reliable")
func _execute_game_over() -> void:
	"""Execute game over sequence on all clients"""
	game_in_progress = false
	_log("🏁 GAME OVER - Rounds survived: %d, Final score: %d" % [rounds_survived, get_total_score()])
	# Game will handle showing game over screen

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RPC FUNCTIONS - GAME EVENTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "reliable")
func send_game_event(event_type: String, data: Dictionary) -> void:
	"""Send a game event to the partner"""
	var _sender_id = multiplayer.get_remote_sender_id()
	
	# If host, broadcast to other client
	if is_host:
		rpc("_receive_game_event", event_type, data)
	else:
		# If client, send to host to broadcast
		rpc_id(1, "_relay_game_event", event_type, data)

@rpc("any_peer", "reliable")
func _relay_game_event(event_type: String, data: Dictionary) -> void:
	"""Host relays event from client to other clients (if we had >2 players) or processes it"""
	# For 2 players, host just receives it and broadcasts to itself (handled by local call) 
	# or broadcasts to others.
	# Since we are 2 players, if client sends to host, host receives it.
	# We need to make sure the host's local game instance gets it.
	_receive_game_event(event_type, data)

@rpc("any_peer", "reliable")
func _receive_game_event(event_type: String, data: Dictionary) -> void:
	"""Receive game event"""
	# Find the current active minigame and notify it
	var current_scene = get_tree().current_scene
	if current_scene.has_method("on_partner_event"):
		current_scene.on_partner_event(event_type, data)

func return_to_lobby() -> void:
	"""Return all players to lobby"""
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
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RPC FUNCTIONS - PERFORMANCE DATA
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "reliable")
func send_performance_data(performance: Dictionary) -> void:
	"""Send player performance data to all peers"""
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
	"""Broadcast performance data to all clients (from host)"""
	performance_data_received.emit(player_num, performance)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RPC FUNCTIONS - GAME STATE SYNC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "reliable")
func sync_game_state(state: Dictionary) -> void:
	"""Sync game state across network"""
	_log("🔄 Game state synced")
	game_state_synced.emit(state)
	
	# If host, broadcast to all clients
	if is_host:
		var sender_id = multiplayer.get_remote_sender_id()
		if sender_id != 0:
			rpc("_broadcast_game_state", state)

@rpc("authority", "reliable")
func _broadcast_game_state(state: Dictionary) -> void:
	"""Broadcast game state to all clients (from host)"""
	game_state_synced.emit(state)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RPC FUNCTIONS - GAME END
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "reliable")
func notify_game_end(team_result: Dictionary) -> void:
	"""Notify all players that game has ended"""
	game_in_progress = false
	_log("🏁 Game ended - Team " + ("Success" if team_result.get("success", false) else "Failed"))
	
	# If host, broadcast to all clients
	if is_host:
		rpc("_broadcast_game_end", team_result)

@rpc("authority", "reliable")
func _broadcast_game_end(team_result: Dictionary) -> void:
	"""Broadcast game end to all clients (from host)"""
	game_in_progress = false
	_log("🏁 Game ended - Team " + ("Success" if team_result.get("success", false) else "Failed"))

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_player_count() -> int:
	"""Get current number of connected players"""
	return players.size()

func get_local_player_num() -> int:
	"""Get local player number (1 or 2)"""
	return local_player_id

func get_player_role(player_num: int) -> String:
	"""Get role for specific player"""
	return player_roles.get(player_num, "Unknown")

func is_multiplayer_connected() -> bool:
	"""Check if currently connected to multiplayer session"""
	return connection_active

func is_server() -> bool:
	"""Check if this instance is the server/host"""
	return is_host

func _log(message: String) -> void:
	"""Internal logging function"""
	print("[NetworkManager] " + message)

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
	"""Reset the producer-consumer state for a new game"""
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
	"""
	Player 1 produces a water unit after completing their task.
	Returns false if buffer is full (game over condition).
	"""
	if water_queue.size() >= BUFFER_MAX_SIZE:
		_log("❌ Buffer OVERFLOW! Queue full (%d/%d)" % [water_queue.size(), BUFFER_MAX_SIZE])
		buffer_overflow.emit()
		total_wasted += 1
		
		# Notify via RPC if multiplayer
		if connection_active:
			rpc("_notify_buffer_overflow")
		return false
	
	var water_data = {
		"type": water_type,        # "clean", "dirty", "soapy"
		"quality": quality,         # 0.0 - 1.0 (affects P2's task)
		"timestamp": Time.get_ticks_msec(),
		"producer_id": local_player_id
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
	"""Create a timer for water transfer (visual delay between P1 and P2)"""
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = current_flow_speed
	timer.timeout.connect(func(): _on_water_arrives(water_data))
	add_child(timer)
	transfer_timers.append(timer)
	timer.start()
	
	_log("⏱️ Water transfer started (%.1fs)" % current_flow_speed)

func _on_water_arrives(water_data: Dictionary) -> void:
	"""Called when water arrives at Player 2's station"""
	_log("🚿 Water ARRIVED at Consumer station")
	
	# Notify Player 2 (Consumer) that they have water to process
	if connection_active:
		rpc("_notify_water_arrived", water_data)
	else:
		# Local testing
		_receive_water_for_consumption(water_data)

@rpc("authority", "reliable")
func _notify_water_arrived(water_data: Dictionary) -> void:
	"""RPC: Notify consumer that water has arrived"""
	if local_player_id == 2:  # Only consumer receives this
		_receive_water_for_consumption(water_data)

func _receive_water_for_consumption(water_data: Dictionary) -> void:
	"""Consumer receives water to process"""
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("on_water_received"):
		current_scene.on_water_received(water_data)

## CONSUMER FUNCTIONS (Player 2 - Pipe Manager/Water User)

func consume_water(success: bool) -> Dictionary:
	"""
	Player 2 consumes a water unit from the queue.
	Returns the water data that was consumed.
	"""
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

@rpc("any_peer", "reliable")
func _sync_water_produced(water_data: Dictionary) -> void:
	"""RPC: Sync water production to other player"""
	if local_player_id != water_data.producer_id:
		water_queue.append(water_data)
		water_produced.emit(water_data)
		_log("📡 Received water production sync")

@rpc("any_peer", "reliable")
func _sync_water_consumed(water_data: Dictionary, success: bool) -> void:
	"""RPC: Sync water consumption to other player"""
	# Remove from queue if we have it
	for i in range(water_queue.size()):
		if water_queue[i].timestamp == water_data.timestamp:
			water_queue.remove_at(i)
			break
	
	water_data["consumed_success"] = success
	water_consumed.emit(water_data)
	_log("📡 Received water consumption sync")

@rpc("any_peer", "reliable")
func _notify_buffer_overflow() -> void:
	"""RPC: Notify all players of buffer overflow"""
	buffer_overflow.emit()
	_log("📡 Buffer overflow notification received")

## ROLLING WINDOW INTEGRATION (Difficulty Adjustment)

func update_flow_speed(new_speed: float) -> void:
	"""Update the transfer speed based on Rolling Window algorithm"""
	current_flow_speed = clampf(new_speed, 0.5, 5.0)
	_log("🌊 Flow speed updated: %.2fs" % current_flow_speed)
	
	# Sync to network
	if connection_active and is_host:
		rpc("_sync_flow_speed", current_flow_speed)

@rpc("authority", "reliable")
func _sync_flow_speed(speed: float) -> void:
	"""RPC: Sync flow speed from host"""
	current_flow_speed = speed
	_log("📡 Flow speed synced: %.2fs" % speed)

func update_player_efficiency(player_num: int, efficiency: float) -> void:
	"""Update a player's efficiency rating (0.0-1.0)"""
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
	"""
	Rolling Window: Calculate difficulty adjustment based on team performance.
	Returns multiplier for flow_speed (lower = harder, faster flow)
	"""
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
	"""Get current buffer status for UI display"""
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

func request_pause() -> void:
	"""Request game pause (either player can pause)"""
	_log("⏸️ Pause requested by Player %d" % local_player_id)
	rpc("_execute_pause")

@rpc("any_peer", "call_local", "reliable")
func _execute_pause() -> void:
	"""Execute pause on all clients"""
	get_tree().paused = true
	_log("⏸️ Game paused")
	
	# Notify current scene
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("_on_remote_pause"):
		current_scene._on_remote_pause()

func request_resume() -> void:
	"""Request game resume (either player can resume, but host has priority)"""
	if is_host:
		_log("▶️ Resume requested by host")
		rpc("_execute_resume")
	else:
		_log("▶️ Resume requested by Player %d" % local_player_id)
		rpc_id(1, "_request_resume_from_client")

@rpc("any_peer", "reliable")
func _request_resume_from_client() -> void:
	"""Client requests host to resume"""
	if is_host:
		rpc("_execute_resume")

@rpc("any_peer", "call_local", "reliable")
func _execute_resume() -> void:
	"""Execute resume on all clients"""
	get_tree().paused = false
	_log("▶️ Game resumed")
	
	# Notify current scene
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("_on_remote_resume"):
		current_scene._on_remote_resume()

@rpc("any_peer", "call_local", "reliable")
func sync_pause_state(paused: bool) -> void:
	"""Synchronize pause state across all connected players (legacy support)"""
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:  # Local call
		sender_id = multiplayer.get_unique_id()
	
	_log("🔄 Pause state sync: " + ("PAUSED" if paused else "RESUMED") + " by peer " + str(sender_id))
	
	# Notify the current scene about remote pause
	var current_scene = get_tree().current_scene
	if current_scene:
		if paused and current_scene.has_method("_on_remote_pause"):
			current_scene._on_remote_pause()
		elif not paused and current_scene.has_method("_on_remote_resume"):
			current_scene._on_remote_resume()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SYNCHRONIZED COUNTDOWN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func start_countdown() -> void:
	"""Start synchronized countdown (3-2-1-GO!) before round (host only)"""
	if not is_host:
		return
	
	_log("⏱️ Starting countdown...")
	rpc("_execute_countdown", 3)

@rpc("authority", "call_local", "reliable")
func _execute_countdown(count: int) -> void:
	"""Execute countdown on all clients"""
	round_starting.emit(count)
	_log("⏱️ Countdown: %d" % count)
	
	if count > 0:
		await get_tree().create_timer(1.0).timeout
		if is_host:
			rpc("_execute_countdown", count - 1)
	else:
		_log("🎮 GO! Round started")
		# Signal game can start
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.has_method("_on_countdown_complete"):
			current_scene._on_countdown_complete()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ROUND MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func complete_round() -> void:
	"""Mark round as complete and show results (host only)"""
	if not is_host:
		return
	
	rounds_survived += 1
	
	# Get individual scores
	var p1_score = 0
	var p2_score = 0
	for peer_id in g_counter:
		if players.get(peer_id, {}).get("player_num", 0) == 1:
			p1_score = g_counter[peer_id]
		else:
			p2_score = g_counter[peer_id]
	
	var team_total = get_total_score()
	
	_log("🏁 Round %d complete! P1: %d | P2: %d | Total: %d" % [rounds_survived, p1_score, p2_score, team_total])
	
	# Broadcast round completion
	rpc("_show_round_results", p1_score, p2_score, team_total, rounds_survived)

@rpc("authority", "call_local", "reliable")
func _show_round_results(p1_score: int, p2_score: int, team_total: int, rounds: int) -> void:
	"""Show round results on all clients"""
	round_completed.emit(p1_score, p2_score, team_total)
	_log("📊 Round %d results - Your score: %d | Partner: %d | Team: %d" % [
		rounds,
		g_counter.get(multiplayer.get_unique_id(), 0),
		team_total - g_counter.get(multiplayer.get_unique_id(), 0),
		team_total
	])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTERCONNECTION SYSTEM (Resource Transfer)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal resource_sent(from_player: int, resource_type: String, amount: int, quality: float)
signal task_marked(from_player: int, task_id: int, position: Vector2)

func send_resource(resource_type: String, amount: int, quality: float = 1.0) -> void:
	"""Send resource to partner player (e.g., water, greywater)"""
	var my_player_num = _get_player_num(multiplayer.get_unique_id())
	_log("💧 Sending resource: %s (x%d, quality: %.1f) from P%d" % [resource_type, amount, quality, my_player_num])
	rpc("_receive_resource", my_player_num, resource_type, amount, quality)

@rpc("any_peer", "reliable")
func _receive_resource(from_player: int, resource_type: String, amount: int, quality: float) -> void:
	"""Receive resource from partner"""
	resource_sent.emit(from_player, resource_type, amount, quality)
	_log("📥 Received resource: %s (x%d) from P%d" % [resource_type, amount, from_player])

func mark_task(task_id: int, task_position: Vector2) -> void:
	"""Mark a task for partner to complete (e.g., leak spotted, tap found)"""
	var my_player_num = _get_player_num(multiplayer.get_unique_id())
	_log("🎯 Marking task #%d at %s for partner" % [task_id, task_position])
	rpc("_receive_task_mark", my_player_num, task_id, task_position)

@rpc("any_peer", "reliable")
func _receive_task_mark(from_player: int, task_id: int, position: Vector2) -> void:
	"""Receive task mark from partner"""
	task_marked.emit(from_player, task_id, position)
	_log("📍 Task #%d marked by P%d at %s" % [task_id, from_player, position])

func _get_player_num(peer_id: int) -> int:
	"""Helper to get player number from peer ID"""
	return players.get(peer_id, {}).get("player_num", 0)
