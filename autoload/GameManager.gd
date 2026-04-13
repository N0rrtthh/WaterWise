extends Node

## ═══════════════════════════════════════════════════════════════════
## GAME MANAGER - CORE FLOW CONTROLLER
## ═══════════════════════════════════════════════════════════════════
## Manages game state, mini-game progression, and screen transitions
## Supports both Single-Player and Multiplayer Co-op modes
## 
## ALGORITHMS IMPLEMENTED:
## 1. G-Counter (Conflict-Free Replicated Counting) - For score sync
## 2. Rule-Based Rolling Window - For adaptive difficulty
## ═══════════════════════════════════════════════════════════════════

signal game_state_changed(new_state: String)
signal minigame_started(game_name: String)
signal minigame_completed(game_name: String, results: Dictionary)
signal all_minigames_completed()
signal team_life_lost(remaining_lives: int)
signal team_won()
signal team_lost()

enum GameState {
	MAIN_MENU,
	MULTIPLAYER_LOBBY,
	LOADING,
	CHARACTER_CUSTOMIZATION,
	INSTRUCTIONS,
	PLAYING_MINIGAME,
	PAUSED,
	MINIGAME_RESULTS,
	POST_TEST,
	FINAL_RESULTS,
	SETTINGS,
	POST_TEST_RESULTS
}

enum GameMode {
	SINGLE_PLAYER,
	MULTIPLAYER_COOP
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CORE STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var current_state: GameState = GameState.MAIN_MENU
var current_game_mode: GameMode = GameMode.SINGLE_PLAYER
var water_droplets: int = 0
var first_launch: bool = true  # For welcome popup (only show on FIRST EVER launch)
var dark_mode_enabled: bool = false
var session_lives: int = 3
var session_score: int = 0
var high_score: int = 0
var round_scores: Array = []

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# G-COUNTER (Conflict-Free Replicated Counting)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Formula: GlobalScore = Σ(PlayerInput_i) for i = 1 to n
# Each peer maintains their own counter, server sums them
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var g_counter: Dictionary = {}  # { peer_id: int_score }
var current_minigame_quota: int = 20  # Points needed to win current minigame (set by each game)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SUPPLEMENTARY SPAWN-SPEED SCALER (NOT the paper's Φ algorithm)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# The paper's Rule-Based Rolling Window (Φ = WMA - CP) lives in
# AdaptiveDifficulty.gd. This section is a SUPPLEMENTARY in-round
# spawn-pacing scaler only:
# If AvgTime < 15s → difficulty_multiplier += 0.2 (NO CEILING!)
# If AvgTime > 30s → difficulty_multiplier -= 0.1 (min: 0.5)
# Timer.wait_time = base_time / difficulty_multiplier
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var rolling_window: Array[float] = []  # Last 5 round times
const ROLLING_WINDOW_SIZE: int = 5  # Matches AdaptiveDifficulty and CoopAdaptation window size
var difficulty_multiplier: float = 1.0
const MIN_DIFFICULTY: float = 0.5
# NO MAX_DIFFICULTY - Game gets faster infinitely!
const FAST_THRESHOLD: float = 15.0  # seconds
const SLOW_THRESHOLD: float = 30.0  # seconds

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEAM LIVES SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var team_lives: int = 3
const MAX_TEAM_LIVES: int = 3

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER (ENet)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_multiplayer_connected: bool = false
const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 2

# Multiplayer performance tracking for CoopAdaptation
var pending_mp_performance: Dictionary = {}  # {peer_id: {accuracy, time, errors}}
var mp_game_name: String = ""

# Player progress tracking
var completed_minigames: Array = []
var current_minigame_index: int = 0
var minigame_random_bag: Array[String] = []
var pending_next_minigame_name: String = ""
var force_full_singleplayer_pool: bool = true
const ALL_SINGLEPLAYER_MINIGAMES: Array = [
	"RiceWashRescue",
	"VegetableBath",
	"GreywaterSorter",
	"WringItOut",
	"ThirstyPlant",
	"MudPieMaker",
	"CatchTheRain",
	"CoverTheDrum",
	"SpotTheSpeck",
	"FixLeak",
	"WaterPlant",
	"PlugTheLeak",
	"SwipeTheSoap",
	"QuickShower",
	"FilterBuilder",
	"ToiletTankFix",
	"TracePipePath",
	"ScrubToSave",
	"BucketBrigade",
	"TimingTap",
	"TurnOffTap",
	"CloudCatcher",
	"WaterMemory",
	"DropletDash"
]
var available_minigames: Array = []

const UNLOCK_ID_TO_MINIGAMES: Dictionary = {
	"catch_rain": ["CatchTheRain", "CoverTheDrum", "RiceWashRescue"],
	"pipe_puzzle": ["TracePipePath", "PlugTheLeak", "FixLeak", "ToiletTankFix", "TurnOffTap"],
	"water_sorting": [
		"GreywaterSorter",
		"VegetableBath",
		"ScrubToSave",
		"FilterBuilder",
		"SpotTheSpeck"
	],
	"leak_fix": ["WringItOut", "QuickShower", "SwipeTheSoap", "WaterPlant"],
	"water_quiz": ["ThirstyPlant", "MudPieMaker"],
	"bucket_relay": ["BucketBrigade", "TimingTap"],
	"fun_games": ["CloudCatcher", "WaterMemory", "DropletDash"]
}

var session_active: bool = false
var minigames_played_this_session: int = 0
var local_player_num: int = 0

# Story chapter thresholds (show story at these game counts)
var _story_shown_at: Array[int] = []
const STORY_THRESHOLDS: Array = [0, 3, 6, 9, 12, 15]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	_load_saved_data()
	_refresh_available_minigames()
	_setup_transition_overlay()
	
	# Connect signals from other autoloads
	if has_node("/root/AdaptiveDifficulty"):
		AdaptiveDifficulty.difficulty_changed.connect(_on_difficulty_changed)
	
	print("🎮 GameManager initialized")
	print("   G-Counter ready for multiplayer scoring")
	print("   Rolling Window ready for difficulty adaptation")

# ── Scene Transition Overlay ─────────────────────────────────────
var _transition_layer: CanvasLayer
var _transition_rect: ColorRect
var _is_transitioning: bool = false

func _setup_transition_overlay() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.layer = 100  # Always on top
	add_child(_transition_layer)
	_transition_rect = ColorRect.new()
	_transition_rect.color = Color(0, 0, 0, 0)
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_layer.add_child(_transition_rect)

func transition_to_scene(scene_path: String, duration: float = 0.4) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	# Fade to black
	var fade_out = create_tween()
	fade_out.tween_property(_transition_rect, "color:a", 1.0, duration)
	await fade_out.finished
	# Change scene
	get_tree().change_scene_to_file(scene_path)
	# Wait a frame for the new scene to load
	await get_tree().process_frame
	await get_tree().process_frame
	# Fade from black
	var fade_in = create_tween()
	fade_in.tween_property(_transition_rect, "color:a", 0.0, duration)
	await fade_in.finished
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false


func _load_saved_data() -> void:
	var config := ConfigFile.new()
	var err := config.load("user://waterwise_save.cfg")
	if err == OK:
		high_score = config.get_value("game", "high_score", 0)
		water_droplets = config.get_value("game", "water_droplets", 0)
		first_launch = config.get_value("game", "first_launch", true)
		dark_mode_enabled = config.get_value("settings", "dark_mode", false)
	else:
		# First time launching - will show welcome popup
		first_launch = true

func _save_data() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "high_score", high_score)
	config.set_value("game", "water_droplets", water_droplets)
	config.set_value("game", "first_launch", first_launch)
	config.set_value("settings", "dark_mode", dark_mode_enabled)
	config.save("user://waterwise_save.cfg")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER: HOST/JOIN (ENet)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func host_game(port: int = DEFAULT_PORT) -> bool:
	# Host a LAN multiplayer game
	peer = ENetMultiplayerPeer.new()
	var error: int = peer.create_server(port, MAX_PLAYERS - 1)
	
	if error != OK:
		print("❌ Failed to create server: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_multiplayer_connected = true
	local_player_num = 1
	
	# Initialize our counter in G-Counter
	g_counter[multiplayer.get_unique_id()] = 0
	
	# Connect signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	print("✅ Server created on port ", port)
	print("🎮 You are Player 1 (Host)")
	return true

func join_game(ip: String, port: int = DEFAULT_PORT) -> bool:
	# Join a LAN multiplayer game
	peer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(ip, port)
	
	if error != OK:
		print("❌ Failed to connect: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	local_player_num = 2
	
	# Connect signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	print("🔄 Connecting to ", ip, ":", port)
	return true

func disconnect_multiplayer() -> void:
	# Disconnect from multiplayer session
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	peer = null
	is_host = false
	is_multiplayer_connected = false
	g_counter.clear()
	print("🔌 Disconnected from multiplayer")

func _on_peer_connected(peer_id: int) -> void:
	print("✅ Player connected: ", peer_id)
	# Initialize their counter
	g_counter[peer_id] = 0
	# Sync current state to new player
	if is_host:
		rpc_id(peer_id, "_sync_game_state", g_counter, team_lives, difficulty_multiplier)

func _on_peer_disconnected(peer_id: int) -> void:
	print("❌ Player disconnected: ", peer_id)
	g_counter.erase(peer_id)

func _on_connected_to_server() -> void:
	print("✅ Connected to server!")
	is_multiplayer_connected = true
	# Initialize our counter
	g_counter[multiplayer.get_unique_id()] = 0

func _on_connection_failed() -> void:
	print("❌ Connection failed!")
	is_multiplayer_connected = false

func _on_server_disconnected() -> void:
	print("⚠️ Server disconnected!")
	is_multiplayer_connected = false

@rpc("authority", "reliable", "call_local")
func _sync_game_state(counters: Dictionary, lives: int, diff_mult: float) -> void:
	# Sync game state using G-Counter CRDT merge: element-wise max (Paper §4)
	# G-Counter merge rule: for each peer, keep the MAXIMUM count
	for pid in counters:
		if g_counter.has(pid):
			g_counter[pid] = max(g_counter[pid], counters[pid])
		else:
			g_counter[pid] = counters[pid]
	# Also merge into the dedicated GCounter singleton if present
	var gc = get_node_or_null("/root/GCounter")
	if gc:
		gc.merge(counters)
	team_lives = lives
	difficulty_multiplier = diff_mult
	print("📡 Game state merged (G-Counter element-wise max)")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# G-COUNTER: SCORE SUBMISSION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "call_local", "reliable")
func submit_score(points: int) -> void:
	## G-Counter increment: Each peer adds to their own counter.
	## Server calculates global sum and checks win condition.
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	
	# Increment sender's counter (G-Counter only increments)
	if not g_counter.has(sender_id):
		g_counter[sender_id] = 0
	g_counter[sender_id] += points
	
	# Also update the dedicated GCounter singleton for CRDT compliance
	var gc = get_node_or_null("/root/GCounter")
	if gc:
		gc.increment(sender_id, points)
	
	var global_score = get_global_score()
	print("💧 P%d scored %d | Global: %d / %d" % [
		sender_id, points,
		global_score, current_minigame_quota])
	print("   G-Counter state: ", g_counter)
	
	# Only host checks win condition
	if is_host and current_minigame_quota > 0:
		_check_win_condition()

func get_global_score() -> int:
	# Calculate GlobalScore = Σ(PlayerInput_i)
	var total: int = 0
	for peer_id in g_counter:
		total += g_counter[peer_id]
	return total

func _check_win_condition() -> void:
	# Check if team has reached the current minigame quota
	var global_score: int = get_global_score()
	print("🎯 Win Condition: %d / %d"
		% [global_score, current_minigame_quota])
	
	if current_minigame_quota <= 0:
		print("⚠️ Warning: Quota is %d (should be > 0)" % current_minigame_quota)
		return
	
	if global_score >= current_minigame_quota:
		print("🎉 TEAM WINS! (%d >= %d)" % [global_score, current_minigame_quota])
		rpc("_announce_team_won")
	else:
		print("   Still need %d more points" % (current_minigame_quota - global_score))

@rpc("authority", "call_local", "reliable")
func _announce_team_won() -> void:
	# Broadcast team victory to all players
	team_won.emit()
	print("🏆 Victory! Team reached quota!")

@rpc("any_peer", "call_local", "reliable")
func set_minigame_quota(quota: int) -> void:
	# Set the quota for current minigame (synced to clients)
	current_minigame_quota = quota
	print("🎯 Minigame quota set to: ", quota)
	
	# If we're the caller, broadcast to all clients
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:  # Local call
		# Broadcast to all clients
		if is_host:
			for peer_id in g_counter.keys():
				if peer_id != multiplayer.get_unique_id():
					rpc_id(peer_id, "set_minigame_quota", quota)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER PERFORMANCE TRACKING (For CoopAdaptation)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _store_multiplayer_performance(
	game_name: String, accuracy: float,
	reaction_time: int, mistakes: int
) -> void:
	# Store local player's performance and check if both reported
	var my_id = multiplayer.get_unique_id()
	mp_game_name = game_name
	
	pending_mp_performance[my_id] = {
		"accuracy": accuracy,
		"time": float(reaction_time) / 1000.0,
		"errors": mistakes
	}
	
	print("📊 [MP] P%d stored: acc=%.2f, "
		% [my_id, accuracy]
		+ "time=%.1fs, errors=%d"
		% [reaction_time / 1000.0, mistakes])
	
	# Notify host about this player's performance
	if not is_host:
		rpc_id(1, "_receive_client_performance", accuracy, reaction_time, mistakes)
	else:
		_check_both_players_done()

@rpc("any_peer", "reliable")
func _receive_client_performance(accuracy: float, reaction_time: int, mistakes: int) -> void:
	# Host receives performance from client
	var sender_id = multiplayer.get_remote_sender_id()
	
	pending_mp_performance[sender_id] = {
		"accuracy": accuracy,
		"time": float(reaction_time) / 1000.0,
		"errors": mistakes
	}
	
	print("📊 [MP] Received Player %d performance" % sender_id)
	_check_both_players_done()

func _check_both_players_done() -> void:
	# Check if both players submitted, then apply CoopAdaptation
	if pending_mp_performance.size() < 2:
		return
	
	# Both players have reported - apply CoopAdaptation algorithm
	var p1_perf: Dictionary = {}
	var p2_perf: Dictionary = {}
	var idx = 0
	
	for peer_id in pending_mp_performance:
		if idx == 0:
			p1_perf = pending_mp_performance[peer_id]
		else:
			p2_perf = pending_mp_performance[peer_id]
		idx += 1
	
	# Determine team success (both players succeeded if global score increased)
	var team_success = get_global_score() > 0
	
	if CoopAdaptation:
		CoopAdaptation.add_game_result(p1_perf, p2_perf, team_success)
		print("🎮 [MP] CoopAdaptation updated with both players' performance")
	
	# Clear for next game
	pending_mp_performance.clear()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEAM LIVES: DAMAGE REPORTING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "call_local", "reliable")
func report_damage() -> void:
	# Called when a player misses a Drop/Leaf
	if not is_host:
		return  # Only host manages lives
	
	team_lives -= 1
	print("💔 Team lost a life! Remaining: ", team_lives)
	
	# Broadcast to all clients
	rpc("_sync_team_lives", team_lives)
	
	if team_lives <= 0:
		print("💀 TEAM LOSES!")
		rpc("_announce_team_lost")

@rpc("authority", "call_local", "reliable")
func _sync_team_lives(lives: int) -> void:
	# Sync team lives from host to all clients
	team_lives = lives
	team_life_lost.emit(team_lives)

@rpc("authority", "call_local", "reliable")
func _announce_team_lost() -> void:
	# Broadcast team defeat to all players
	team_lost.emit()
	print("☠️ Game Over! Team ran out of lives!")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ROLLING WINDOW: ADAPTIVE DIFFICULTY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func add_round_time(round_time: float) -> void:
	## Add a round completion time to the rolling window.
	## Window size = 5, calculates average and adjusts difficulty.
	rolling_window.append(round_time)
	
	# Keep only last 5 entries
	while rolling_window.size() > ROLLING_WINDOW_SIZE:
		rolling_window.pop_front()
	
	# Only adjust after we have enough data
	if rolling_window.size() >= ROLLING_WINDOW_SIZE:
		_calculate_difficulty_adjustment()
	
	print("📊 Rolling Window: ", rolling_window)
	print("   Difficulty Multiplier: ", difficulty_multiplier)

func _calculate_difficulty_adjustment() -> void:
	## SUPPLEMENTARY speed scaler for spawn intervals (NOT the paper's Φ algorithm).
	## The paper's Rule-Based Rolling Window with Φ = WMA - CP lives in
	## AdaptiveDifficulty.gd, which determines Easy/Medium/Hard difficulty.
	##
	## This method only adjusts difficulty_multiplier for in-round spawn pacing:
	##   AvgTime < 15s → multiplier += 0.2 (speed up spawns)
	##   AvgTime > 30s → multiplier -= 0.1 (slow down spawns)
	var sum: float = 0.0
	for time in rolling_window:
		sum += time
	
	var avg_time: float = sum / float(ROLLING_WINDOW_SIZE)
	print("📈 Average Round Time: ", avg_time, "s")
	
	if avg_time < FAST_THRESHOLD:
		# Too fast - make it harder (NO CEILING!)
		difficulty_multiplier += 0.2
		print("⬆️ Increasing difficulty (too fast) - Multiplier: %.2f" % difficulty_multiplier)
	elif avg_time > SLOW_THRESHOLD:
		# Too slow - make it easier (but keep minimum)
		difficulty_multiplier -= 0.1
		print("⬇️ Decreasing difficulty (too slow) - Multiplier: %.2f" % difficulty_multiplier)
	
	# Only enforce minimum difficulty (no maximum!)
	difficulty_multiplier = max(difficulty_multiplier, MIN_DIFFICULTY)
	
	# Sync to clients if host
	if is_host and is_multiplayer_connected:
		rpc("_sync_difficulty", difficulty_multiplier)

@rpc("authority", "call_local", "reliable")
func _sync_difficulty(new_multiplier: float) -> void:
	# Sync difficulty multiplier from host to clients
	difficulty_multiplier = new_multiplier
	print("📡 Difficulty synced: ", difficulty_multiplier)

func get_spawn_interval(base_interval: float) -> float:
	# Get adjusted spawn interval: base_time / difficulty_multiplier
	return base_interval / difficulty_multiplier

func reset_multiplayer_game() -> void:
	# Reset state for a new multiplayer round
	g_counter.clear()
	g_counter[multiplayer.get_unique_id()] = 0
	team_lives = MAX_TEAM_LIVES
	rolling_window.clear()
	difficulty_multiplier = 1.0
	minigames_played_this_session = 0
	completed_minigames.clear()
	
	if is_host:
		rpc("_sync_game_state", g_counter, team_lives, difficulty_multiplier)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER MINIGAME PROGRESSION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Multiplayer minigame pool (3 dual-mode co-op games)
var multiplayer_minigames: Array[String] = [
	"MiniGame_WaterHarvest",
	"MiniGame_GreywaterSort",
	"MiniGame_LeafSort"
]

var multiplayer_game_order: Array[String] = []
var multiplayer_game_index: int = 0

# Mode assignment for current game (randomized each game)
var player_modes: Dictionary = {}  # {peer_id: int (1 or 2)}

func assign_random_modes() -> void:
	# Randomly assign Mode 1 or Mode 2 to each player
	player_modes.clear()
	
	# Get peer IDs and convert to regular Array for shuffling
	var peer_ids: Array = []
	for peer_id in multiplayer.get_peers():
		peer_ids.append(peer_id)
	peer_ids.append(multiplayer.get_unique_id())  # Include self
	
	# Shuffle the peer IDs
	peer_ids.shuffle()
	
	# Assign modes alternating
	for i in range(peer_ids.size()):
		player_modes[peer_ids[i]] = (i % 2) + 1  # Alternates between 1 and 2
	
	print("🎲 Mode assignments: ", player_modes)

func get_my_player_mode() -> int:
	# Get my assigned mode (1 or 2)
	var my_id = multiplayer.get_unique_id()
	return player_modes.get(my_id, 1)  # Default to mode 1

@rpc("authority", "call_local", "reliable")
func _load_next_multiplayer_minigame() -> void:
	# Load next random multiplayer minigame (loop until lives depleted)
	print("🎮 [Multiplayer] Loading next minigame...")
	
	# Reset G-Counter for next round (but keep lives and difficulty)
	g_counter.clear()
	for peer_id in multiplayer.get_peers():
		g_counter[peer_id] = 0
	g_counter[multiplayer.get_unique_id()] = 0
	
	# Reset quota to 0 so new game can set it
	current_minigame_quota = 0
	
	# Randomly assign modes for the next game
	assign_random_modes()
	
	# If we've played all games in current shuffle, reshuffle
	if multiplayer_game_order.is_empty() or multiplayer_game_index >= multiplayer_game_order.size():
		multiplayer_game_order = multiplayer_minigames.duplicate()
		multiplayer_game_order.shuffle()
		multiplayer_game_index = 0
		print("🔀 Shuffled multiplayer minigame order: ", multiplayer_game_order)
	
	# Get next game
	var game_name: String = multiplayer_game_order[multiplayer_game_index]
	multiplayer_game_index += 1
	
	print("🎯 Next game: ", game_name)
	print("❤️ Team Lives: ", team_lives)
	print("⚡ Difficulty Multiplier: %.2f" % difficulty_multiplier)
	
	# Load the scene
	var game_path: String = "res://scripts/multiplayer/%s.tscn" % game_name
	if ResourceLoader.exists(game_path):
		get_tree().change_scene_to_file(game_path)
	else:
		push_error("❌ Multiplayer minigame scene not found: ", game_path)

@rpc("authority", "call_local", "reliable")
func _show_multiplayer_final_results() -> void:
	# Show final game over screen for multiplayer session
	print("🏁 Multiplayer session ended!")
	print("   Games Played: ", minigames_played_this_session)
	print("   Final Difficulty: %.2f" % difficulty_multiplier)
	print("   Total Score: ", get_global_score())
	
	# Create a simple results overlay
	var tree = get_tree()
	if not tree:
		return
	
	var root = tree.root
	var results_screen = Control.new()
	results_screen.name = "MultiplayerResults"
	results_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_screen.z_index = 100
	
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.1, 0.2, 0.95)
	results_screen.add_child(bg)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_screen.add_child(center)
	
	# VBox for results
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🏁 SESSION COMPLETE!"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Stats
	var stats = Label.new()
	stats.text = "Games Played: %d\nFinal Score: %d\nDifficulty: %.1fx" % [
		minigames_played_this_session,
		get_global_score(),
		difficulty_multiplier
	]
	stats.add_theme_font_size_override("font_size", 36)
	stats.add_theme_color_override("font_color", Color(1, 1, 1))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)
	
	# Return button
	var return_btn = Button.new()
	return_btn.text = "Return to Lobby"
	return_btn.custom_minimum_size = Vector2(300, 80)
	return_btn.add_theme_font_size_override("font_size", 28)
	return_btn.pressed.connect(func():
		results_screen.queue_free()
		tree.change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
	)
	vbox.add_child(return_btn)
	
	root.add_child(results_screen)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME STATE MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func change_state(new_state: GameState) -> void:
	var old_state := current_state
	current_state = new_state
	game_state_changed.emit(GameState.keys()[new_state])
	print("🎮 Game State: ", GameState.keys()[old_state], " → ", GameState.keys()[new_state])

func set_game_mode(mode: GameMode) -> void:
	current_game_mode = mode
	print("🎮 Game mode set to: ", GameMode.keys()[mode])

func start_new_session(mode: GameMode = GameMode.SINGLE_PLAYER) -> void:
	current_game_mode = mode
	session_active = true
	completed_minigames.clear()
	current_minigame_index = 0
	minigames_played_this_session = 0
	session_lives = 3
	session_score = 0
	round_scores.clear()
	pending_next_minigame_name = ""
	_story_shown_at.clear()
	
	if mode == GameMode.SINGLE_PLAYER:
		# Hard reset any multiplayer remnants so single-player never hijacks flow.
		if is_multiplayer_connected or multiplayer.multiplayer_peer:
			disconnect_multiplayer()
		_refresh_available_minigames()
		_rebuild_minigame_random_bag()
		_load_saved_data()
		if has_node("/root/AdaptiveDifficulty"):
			AdaptiveDifficulty.reset()
		if PerformanceProfiler:
			PerformanceProfiler.clear_session_events()
			PerformanceProfiler.log_event("session_start", {"mode": "single_player"})
		print("🎯 New SINGLE-PLAYER session started")
	else:
		reset_multiplayer_game()
		if PerformanceProfiler:
			PerformanceProfiler.clear_session_events()
			PerformanceProfiler.log_event("session_start", {"mode": "multiplayer_coop"})
		print("🎯 New MULTIPLAYER CO-OP session started")

func start_next_minigame() -> void:
	if current_game_mode != GameMode.SINGLE_PLAYER:
		push_warning(
			"start_next_minigame called outside single-player mode; forcing single-player."
		)
		current_game_mode = GameMode.SINGLE_PLAYER

	if session_lives <= 0:
		all_minigames_completed.emit()
		_show_final_score()
		return

	# Check if a story chapter should play
	if _should_show_story():
		_show_story_then_continue()
		return

	_launch_next_minigame_internal()

func _should_show_story() -> bool:
	for threshold in STORY_THRESHOLDS:
		if minigames_played_this_session == threshold and threshold not in _story_shown_at:
			return true
	return false

func _show_story_then_continue() -> void:
	_story_shown_at.append(minigames_played_this_session)
	var story_path := "res://scenes/ui/StoryScreen.tscn"
	if not ResourceLoader.exists(story_path):
		_launch_next_minigame_internal()
		return
	var story_scene = load(story_path).instantiate()
	get_tree().current_scene.add_child(story_scene)
	story_scene.story_finished.connect(func():
		story_scene.queue_free()
		_launch_next_minigame_internal()
	)

func _launch_next_minigame_internal() -> void:
	if available_minigames.is_empty():
		_refresh_available_minigames()
		_rebuild_minigame_random_bag()
		if available_minigames.is_empty():
			push_warning("No minigames available. Returning to main menu.")
			return_to_main_menu()
			return

	if minigame_random_bag.is_empty():
		_rebuild_minigame_random_bag()

	if minigame_random_bag.is_empty():
		push_warning("Random bag is empty. Returning to main menu.")
		return_to_main_menu()
		return

	var pick_index = randi() % minigame_random_bag.size()
	var game_name: String = minigame_random_bag[pick_index]
	minigame_random_bag.remove_at(pick_index)

	change_state(GameState.PLAYING_MINIGAME)
	minigame_started.emit(game_name)
	_start_intro_cutscene_for_game(game_name)

func _start_intro_cutscene_for_game(game_name: String) -> void:
	pending_next_minigame_name = game_name
	var bridge_path := "res://scenes/ui/cutscenes/MiniGameIntroBridge.tscn"
	if ResourceLoader.exists(bridge_path):
		get_tree().change_scene_to_file(bridge_path)
		return

	# Fallback for safety: if bridge scene is missing, go straight to minigame.
	launch_pending_minigame()

func launch_pending_minigame() -> void:
	if pending_next_minigame_name.is_empty():
		push_warning("No pending minigame set. Selecting next minigame.")
		start_next_minigame()
		return

	var game_name := pending_next_minigame_name
	pending_next_minigame_name = ""
	var game_path: String = "res://scenes/minigames/%s.tscn" % game_name
	if ResourceLoader.exists(game_path):
		get_tree().change_scene_to_file(game_path)
	else:
		push_warning("Mini-game not found: ", game_path)
		# Try the next one immediately if one entry is stale.
		start_next_minigame()

func _refresh_available_minigames() -> void:
	# Build single-player pool from SaveManager unlock bundles.
	var save_mgr = get_node_or_null("/root/SaveManager")
	var unlocked_ids: Array = []
	var filtered: Array = []

	if save_mgr and save_mgr.unlocked_content is Dictionary:
		unlocked_ids = save_mgr.unlocked_content.get("minigames", [])

	if force_full_singleplayer_pool:
		filtered = ALL_SINGLEPLAYER_MINIGAMES.duplicate()
	elif unlocked_ids.is_empty():
		filtered = ALL_SINGLEPLAYER_MINIGAMES.duplicate()
	else:
		for unlock_id in unlocked_ids:
			if UNLOCK_ID_TO_MINIGAMES.has(unlock_id):
				for game_name in UNLOCK_ID_TO_MINIGAMES[unlock_id]:
					if game_name not in filtered:
						filtered.append(game_name)

	# Keep only scenes that exist to prevent runtime scene load errors.
	available_minigames.clear()
	for game_name in filtered:
		if ResourceLoader.exists("res://scenes/minigames/%s.tscn" % game_name):
			available_minigames.append(game_name)

	if available_minigames.is_empty():
		available_minigames = ["CatchTheRain"]

func _rebuild_minigame_random_bag() -> void:
	minigame_random_bag.clear()
	for game_name in available_minigames:
		minigame_random_bag.append(game_name)

func refresh_available_minigames() -> void:
	_refresh_available_minigames()

func complete_minigame(
	game_name: String, accuracy: float,
	reaction_time: int, mistakes: int,
	round_score_override: int = -1,
	best_combo: int = 0
) -> void:
	if not game_name in completed_minigames:
		completed_minigames.append(game_name)
	
	minigames_played_this_session += 1
	
	var round_score: int = int(accuracy * 100.0) - (mistakes * 10)
	round_score = max(0, round_score)
	if round_score_override >= 0:
		round_score = round_score_override
	session_score += round_score
	round_scores.append({
		"game": game_name,
		"score": round_score,
		"combo": best_combo,
		"accuracy": accuracy,
		"mistakes": mistakes,
		"reaction_time": reaction_time
	})
	
	# Add to rolling window for difficulty adjustment
	var round_time_seconds: float = float(reaction_time) / 1000.0
	add_round_time(round_time_seconds)
	
	# ═══════════════════════════════════════════════════════════════════════
	# Apply adaptive difficulty algorithms based on game mode
	# ═══════════════════════════════════════════════════════════════════════
	# ELI5: This is the CONNECTION POINT between minigames and the algorithm!
	#
	# When a single-player minigame ends, it calls GameManager.complete_minigame()
	# with the player's accuracy, reaction_time, and mistakes.
	#
	# GameManager then forwards this data to AdaptiveDifficulty.add_performance()
	# which:
	#   1) Adds it to the Rolling Window (last 5 games)
	#   2) Every 2 games, calculates Φ (Proficiency Index)
	#   3) Uses the decision tree to adjust difficulty (Easy/Medium/Hard)
	#
	# The NEW difficulty then applies to the NEXT minigame the player starts!
	# ═══════════════════════════════════════════════════════════════════════
	if current_game_mode == GameMode.SINGLE_PLAYER:
		# Single-player uses AdaptiveDifficulty (Φ = WMA - CP algorithm)
		# This is the RULE-BASED ROLLING WINDOW ALGORITHM in action!
		if AdaptiveDifficulty:
			AdaptiveDifficulty.add_performance(accuracy, reaction_time, mistakes, game_name)
	else:
		# Multiplayer uses CoopAdaptation (per-player difficulty with sync scoring)
		# Note: In multiplayer, performance is tracked via submit_score RPC
		# CoopAdaptation.add_game_result() should be called after BOTH players complete
		if CoopAdaptation and is_host:
			# Store this player's performance temporarily
			_store_multiplayer_performance(game_name, accuracy, reaction_time, mistakes)
	
	var results: Dictionary = {
		"game_name": game_name,
		"accuracy": accuracy,
		"reaction_time": reaction_time,
		"mistakes": mistakes,
		"difficulty": _get_current_difficulty()
	}
	
	# Log event for dev-mode performance analysis
	if PerformanceProfiler:
		PerformanceProfiler.log_event("minigame_complete", {
			"game_name": game_name,
			"accuracy": accuracy,
			"reaction_time_ms": reaction_time,
			"mistakes": mistakes,
			"difficulty": _get_current_difficulty(),
			"round_score": round_score,
			"session_score": session_score,
			"lives": session_lives,
			"difficulty_multiplier": difficulty_multiplier,
		})
	
	minigame_completed.emit(game_name, results)
	change_state(GameState.MINIGAME_RESULTS)
	current_minigame_index += 1

func _get_current_difficulty() -> String:
	# Dynamic difficulty classification that works with uncapped values
	if difficulty_multiplier >= 2.0:
		return "Extreme"  # New tier for very high speeds
	if difficulty_multiplier >= 1.5:
		return "Hard"
	if difficulty_multiplier >= 1.0:
		return "Medium"
	return "Easy"

func return_to_main_menu() -> void:
	change_state(GameState.MAIN_MENU)
	get_tree().paused = false
	
	if session_score > high_score:
		high_score = session_score
		_save_data()
	
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

func _show_final_score() -> void:
	print("🎉 Session complete! Showing final score...")
	change_state(GameState.FINAL_RESULTS)
	
	# Update high score before showing FinalScore so the screen can compare
	if session_score > high_score:
		high_score = session_score
	_save_data()
	
	# Export dev-mode performance log
	if PerformanceProfiler:
		PerformanceProfiler.log_event("session_end", {
			"total_score": session_score,
			"high_score": high_score,
			"games_played": minigames_played_this_session,
			"lives_remaining": session_lives,
		})
		PerformanceProfiler.export_session_log_to_file()
	
	if ResourceLoader.exists("res://scenes/ui/FinalScore.tscn"):
		transition_to_scene("res://scenes/ui/FinalScore.tscn")
	else:
		transition_to_scene("res://scenes/ui/InitialScreen.tscn")

func pause_game() -> void:
	get_tree().paused = true
	change_state(GameState.PAUSED)

func resume_game() -> void:
	get_tree().paused = false
	change_state(GameState.PLAYING_MINIGAME)

func _on_difficulty_changed(old_level: String, new_level: String, reason: String) -> void:
	print("⚡ Difficulty changed: ", old_level, " → ", new_level, " (", reason, ")")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WELCOME POPUP MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func should_show_welcome_popup() -> bool:
	# Returns true only on the FIRST EVER game launch
	return first_launch

func mark_welcome_shown() -> void:
	# Mark that welcome popup has been shown - never show again
	first_launch = false
	_save_data()

func reset_welcome_popup() -> void:
	# Reset to show welcome popup again (for testing)
	first_launch = true
	_save_data()

func reset_all_data() -> void:
	# Reset all saved data to defaults (fresh start)
	high_score = 0
	water_droplets = 0
	first_launch = true
	dark_mode_enabled = false
	
	# Delete the save file
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("waterwise_save.cfg"):
		dir.remove("waterwise_save.cfg")
	
	# Also reset SaveManager if available
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("reset_all"):
		save_mgr.reset_all()
	
	print("🔄 All data reset to defaults")
