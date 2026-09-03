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
## Both carry the SCENE BASENAME ("MudPieMaker"), so the pair is joinable: started
## always did, and completed used to emit the display title, which for FixLeakV2 was
## also language-dependent. results still carries "game_name" for display.
signal minigame_started(game_id: String)
signal minigame_completed(game_id: String, results: Dictionary)
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
var session_droplets_earned: int = 0
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
## True once the host has pushed the quota for the CURRENT round, so a client's
## own late local call cannot overwrite the value the host scores against.
## Cleared at the start of every multiplayer round (see set_minigame_quota).
var _quota_from_host: bool = false

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
## Win/loss flag per entry in rolling_window, kept index-aligned with it so the
## spawn pacer can tell a fast win from a fast loss.
var rolling_window_success: Array[bool] = []
const ROLLING_WINDOW_SIZE: int = 5  # Matches AdaptiveDifficulty and CoopAdaptation window size
var difficulty_multiplier: float = 1.0
const MIN_DIFFICULTY: float = 0.5
## Ceiling on the supplementary spawn pacer.
##
## This used to be unbounded ("game gets faster infinitely"), but the value is
## consumed as `spawn_rate = base_rate / difficulty_multiplier` and
## `fall_speed *= difficulty_multiplier`. Left to grow, the spawn interval tends
## to zero — an unbounded entity flood, which is a memory/draw-call problem on a
## <2 GB device — and falling objects eventually travel further per frame than
## the catcher is tall, so they cannot be caught at all and the round becomes
## unwinnable. 3.0 still gives a 6x span against MIN_DIFFICULTY and takes ten
## consecutive fast wins to reach, so escalation stays meaningful.
const MAX_DIFFICULTY: float = 3.0
const FAST_THRESHOLD: float = 15.0  # seconds
const SLOW_THRESHOLD: float = 30.0  # seconds

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEAM LIVES SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var team_lives: int = 3
const MAX_TEAM_LIVES: int = 3
const LEVEL_QUOTA: int = 20

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER (ENet)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_multiplayer_connected: bool = false
var _play_again_pending: bool = false  # Guard: prevents double-restart race condition
const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 2

# Multiplayer performance tracking for CoopAdaptation
var pending_mp_performance: Dictionary = {}  # {peer_id: {accuracy, time, errors}}
var mp_game_name: String = ""
var current_multiplayer_game_name: String = ""
var _recorded_multiplayer_round_game: String = ""

# Player progress tracking
var completed_minigames: Array = []
var current_minigame_index: int = 0
var minigame_random_bag: Array[String] = []
var pending_next_minigame_name: String = ""
## Scene basename of the round currently loaded, recorded by
## launch_pending_minigame(). replay_current_minigame() needs it because
## round_scores stores the human-readable display name instead.
var last_launched_minigame_name: String = ""
## false in production: the playable pool is gated by SaveManager unlock
## bundles (droplet purchases in UnlockablesScreen). Test tools may flip this
## back to true to exercise every game without a fully-unlocked save.
var force_full_singleplayer_pool: bool = false
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
var _session_finalized: bool = false

# Story chapter cadence: intro once, then every 5 completed minigames.
var _story_shown_at: Array[int] = []
var _story_transition_active: bool = false
const STORY_INTERVAL_GAMES: int = 5

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	_load_saved_data()
	_refresh_available_minigames()
	_setup_transition_overlay()
	_request_android_storage_permissions()
	
	# Android Back must not kill the app. SceneTree.quit_on_go_back defaults to true
	# and NOT ONE script in the project handled NOTIFICATION_WM_GO_BACK_REQUEST -
	# every hit for that constant was under .agents/skills/, which are reference
	# templates and not part of the game. Measured by tools/ProbeBackButton.tscn:
	# quit_on_go_back true, zero handlers. So the hardware/gesture Back button called
	# SceneTree.quit() from anywhere - mid-round, mid-cutscene, over the tally screen -
	# with no confirmation, no save of the round in progress and no way back.
	#
	# On a phone Back is the primary navigation gesture, so this was not an edge case:
	# it was the single most reachable way to lose a session.
	get_tree().quit_on_go_back = false
	
	# Connect signals from other autoloads
	if has_node("/root/AdaptiveDifficulty"):
		AdaptiveDifficulty.difficulty_changed.connect(_on_difficulty_changed)
	
	print("🎮 GameManager initialized")

func _request_android_storage_permissions() -> void:
	if OS.get_name() != "Android":
		return
	# Request all dangerous permissions declared in the manifest.
	# This shows the system permission dialog on first install. Subsequent
	# launches skip the dialog if the user already granted permissions.
	var granted := OS.get_granted_permissions()
	var needs_write := "android.permission.WRITE_EXTERNAL_STORAGE" not in granted
	var needs_read  := "android.permission.READ_EXTERNAL_STORAGE"  not in granted
	if needs_write or needs_read:
		# request_permissions() asks for all permissions listed in the manifest
		# at once — this is the standard Android runtime-permission flow.
		OS.request_permissions()
	print("   G-Counter ready for multiplayer scoring")
	print("   Rolling Window ready for difficulty adaptation")

# ── Scene Transition Overlay ─────────────────────────────────────
var _transition_layer: CanvasLayer
var _transition_rect: ColorRect
var _is_transitioning: bool = false

const LIGHT_TRANSITION_TINT := Color(0.16, 0.31, 0.46, 0.0)
const DARK_TRANSITION_TINT := Color(0.08, 0.14, 0.24, 0.0)

func _setup_transition_overlay() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.layer = 100  # Always on top
	add_child(_transition_layer)
	_transition_rect = ColorRect.new()
	_transition_rect.color = LIGHT_TRANSITION_TINT
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_layer.add_child(_transition_rect)


func _get_transition_tint() -> Color:
	if dark_mode_enabled:
		return DARK_TRANSITION_TINT
	return LIGHT_TRANSITION_TINT

func is_scene_transitioning() -> bool:
	return _is_transitioning

func transition_to_scene(scene_path: String, duration: float = 0.4) -> void:
	if _is_transitioning:
		return
	if not ResourceLoader.exists(scene_path):
		push_error("Cannot transition. Scene does not exist: %s" % scene_path)
		return
	if not _transition_rect or not is_instance_valid(_transition_rect):
		_setup_transition_overlay()

	var tint = _get_transition_tint()
	_transition_rect.color = Color(tint.r, tint.g, tint.b, _transition_rect.color.a)
	var fade_alpha = 0.95 if dark_mode_enabled else 0.90
	var fade_duration = max(duration, 0.18)
	var reveal_duration = max(duration * 0.88, 0.15)

	_is_transitioning = true
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	# Fade to themed tint.
	var fade_out = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(_transition_rect, "color:a", fade_alpha, fade_duration)
	await fade_out.finished
	# Change scene
	get_tree().change_scene_to_file(scene_path)
	# Wait a frame for the new scene to load
	await get_tree().process_frame
	await get_tree().process_frame
	# Fade from themed tint.
	var fade_in = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_in.tween_property(_transition_rect, "color:a", 0.0, reveal_duration)
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

	# Keep wallet synced with SaveManager (source of truth for currency/shop).
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("get_droplets"):
		water_droplets = int(save_mgr.get_droplets())

func _save_data() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "high_score", high_score)
	config.set_value("game", "water_droplets", water_droplets)
	config.set_value("game", "first_launch", first_launch)
	config.set_value("settings", "dark_mode", dark_mode_enabled)
	config.save("user://waterwise_save.cfg")

func save_persistent_data() -> void:
	_save_data()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER: HOST/JOIN (ENet)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func host_game(port: int = DEFAULT_PORT) -> bool:
	# Host a LAN multiplayer game
	if multiplayer.multiplayer_peer:
		disconnect_multiplayer()
	_disconnect_multiplayer_callbacks()
	peer = ENetMultiplayerPeer.new()
	var error: int = peer.create_server(port, MAX_PLAYERS - 1)
	
	if error != OK:
		print("❌ Failed to create server: ", error)
		peer = null
		return false
	
	multiplayer.multiplayer_peer = peer
	if NetworkManager:
		NetworkManager.adopt_existing_peer(true)
	is_host = true
	is_multiplayer_connected = true
	local_player_num = 1
	current_game_mode = GameMode.MULTIPLAYER_COOP
	
	# Initialize our counter in G-Counter
	g_counter.clear()
	g_counter[multiplayer.get_unique_id()] = 0
	
	# Connect signals
	_connect_multiplayer_callbacks()
	
	print("✅ Server created on port ", port)
	print("🎮 You are Player 1 (Host)")
	return true

func join_game(ip: String, port: int = DEFAULT_PORT) -> bool:
	# Join a LAN multiplayer game
	if multiplayer.multiplayer_peer:
		disconnect_multiplayer()
	_disconnect_multiplayer_callbacks()
	peer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(ip, port)
	
	if error != OK:
		print("❌ Failed to connect: ", error)
		peer = null
		return false
	
	multiplayer.multiplayer_peer = peer
	if NetworkManager:
		# The address goes with the peer. This is the only join path the shipped UI has,
		# so if it does not record where it dialled, NetworkManager._attempt_rejoin()
		# has nothing to dial back and an in-round drop can never recover.
		NetworkManager.adopt_existing_peer(false, ip, port)
	is_host = false
	local_player_num = 2
	current_game_mode = GameMode.MULTIPLAYER_COOP
	
	# Connect signals
	_connect_multiplayer_callbacks()
	
	print("🔄 Connecting to ", ip, ":", port)
	return true

func disconnect_multiplayer() -> void:
	# Disconnect from multiplayer session
	_disconnect_multiplayer_callbacks()
	if NetworkManager and NetworkManager.network:
		NetworkManager.disconnect_multiplayer()
	elif peer:
		peer.close()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	peer = null
	is_host = false
	is_multiplayer_connected = false
	local_player_num = 0
	session_active = false
	g_counter.clear()
	player_modes.clear()
	multiplayer_game_order.clear()
	multiplayer_game_index = 0
	current_multiplayer_game_name = ""
	_recorded_multiplayer_round_game = ""
	_quota_from_host = false
	print("🔌 Disconnected from multiplayer")

func _connect_multiplayer_callbacks() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _disconnect_multiplayer_callbacks() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

func _on_peer_connected(peer_id: int) -> void:
	print("✅ Player connected: ", peer_id)
	# Seed the slot ONLY if it is new. `g_counter[peer_id] = 0` is an unconditional
	# write, and on a slot that already holds a score that is a DOWNWARD write —
	# the one thing a grow-only counter may never do. It is reachable in ordinary
	# play, not just in edge cases: Godot delivers peer_connected to a joining
	# client for every peer already in the session, so on a rejoin the client ran
	# this line for the host and zeroed the host's accumulated contribution.
	# Measured before this guard existed (tools/logs/rj_client.log, first run):
	# the client's slot went 5 → 0 and the team total 12 → 0.
	if not g_counter.has(peer_id):
		g_counter[peer_id] = 0
	# Sync current state to new player (thesis Event 4: state re-synchronisation)
	if is_host:
		rpc_id(peer_id, "_sync_game_state", g_counter, team_lives, difficulty_multiplier)

func _on_peer_disconnected(peer_id: int) -> void:
	print("❌ Player disconnected: ", peer_id)
	# The departed player's slot is deliberately KEPT.
	#
	# This used to be `g_counter.erase(peer_id)`, which is the single operation a
	# G-Counter may never perform: the team total is a join over a grow-only
	# lattice, so removing a slot decreases the total by exactly that player's
	# contribution. Reproduced with tools/VerifyMultiplayerReconnect.tscn — the
	# host went from {1:7, C:5} = 12 to {1:7} = 7 the instant the partner left,
	# and because the host is the ONLY peer that evaluates _check_win_condition()
	# the team's quota progress silently rolled backwards ("Still need 8 more
	# points" → "Still need 13 more points").
	#
	# It also diverged the two replicas permanently. _sync_game_state merges with
	# element-wise MAX, so it can never restore a value the host has forgotten:
	# after the partner rejoined, the host held 7 and the client held 12 and no
	# further message could reconcile them. The standalone GCounter singleton has
	# no erase path at all and reported 12 throughout the same run, which is the
	# control proving the loss was this dictionary's and not the network's.
	#
	# Keeping the slot costs one integer per rejoin and makes the rejoin converge.
	if current_game_mode == GameMode.MULTIPLAYER_COOP and session_active:
		# Stand down while a live round is being held open for this same peer.
		#
		# This is a genuine race, not defensive padding: this handler and
		# NetworkManager._on_player_disconnected() are BOTH connected to
		# multiplayer.peer_disconnected, they run in the same frame, and the order
		# between them is not specified. Whichever runs first, only one of the two may
		# decide the round's fate, and the decision belongs to NetworkManager because
		# that is where the hold timers and the rejoin retry live. Routing to the lobby
		# from here would tear down the very round the hold exists to preserve, and
		# would do it before the peer has had a single retry.
		#
		# NetworkManager.game_in_progress is the discriminator, and it is checked rather
		# than is_reconnect_hold_active() so that this side stands down whichever handler
		# won the race: if NetworkManager has not opened its hold yet, the flag is still
		# true and it is about to. On a deliberate teardown game_in_progress is already
		# false, so the old immediate return still happens.
		if NetworkManager and NetworkManager.game_in_progress:
			print("  ...round is being held for a reconnect; NetworkManager owns the outcome")
			return
		session_active = false
		push_warning("Multiplayer peer disconnected during session. Returning to lobby.")
		call_deferred("return_to_multiplayer_lobby")

func _on_connected_to_server() -> void:
	print("✅ Connected to server!")
	is_multiplayer_connected = true
	# A rejoin inside a reconnect hold is dialled by NetworkManager.join_server(), which
	# owns the new ENetMultiplayerPeer. This side's `peer` was left null by whatever
	# handled the drop, so re-point it at the live peer instead of leaving the two halves
	# of the session disagreeing about which object is current.
	if peer == null and multiplayer.multiplayer_peer != null:
		peer = multiplayer.multiplayer_peer
	# Same grow-only guard as _on_peer_connected: seed the slot, never reset it.
	# A rejoin gets a fresh peer id so the honest path is unaffected, but a
	# re-delivered connected_to_server would otherwise zero this replica's own
	# accumulated contribution.
	var my_id: int = multiplayer.get_unique_id()
	if not g_counter.has(my_id):
		g_counter[my_id] = 0

func _on_connection_failed() -> void:
	print("❌ Connection failed!")
	is_multiplayer_connected = false
	if peer:
		peer.close()
	peer = null
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	print("⚠️ Server disconnected!")
	# Stand down while a live round is being held open for this same host, for the same
	# reason _on_peer_disconnected() does - and this handler had to learn it the hard
	# way. On a client BOTH multiplayer.peer_disconnected (for peer 1) and
	# multiplayer.server_disconnected arrive for one drop, so this ran ~one signal after
	# NetworkManager had already opened the hold, and it did three fatal things to it:
	# nulled multiplayer_peer out from under the pending rejoin, cleared session_active,
	# and deferred return_to_multiplayer_lobby() -> disconnect_multiplayer(), which
	# silently dropped the hold with no reconnect_hold_ended emitted. Measured with
	# tools/VerifyInRoundReconnect.tscn: the client reached the lobby 0.1 s into a 6 s
	# hold, its recorded hold ends were `[]`, and the host sat out the full window and
	# resolved as `ends=[false]`.
	#
	# game_in_progress is the discriminator rather than is_reconnect_hold_active() so
	# this side stands down whichever handler won the race to run first.
	if NetworkManager and NetworkManager.game_in_progress:
		print("  ...round is being held for a reconnect; NetworkManager owns the outcome")
		return
	is_multiplayer_connected = false
	peer = null
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	if current_game_mode == GameMode.MULTIPLAYER_COOP and session_active:
		session_active = false
		call_deferred("return_to_multiplayer_lobby")

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

	# A G-Counter is GROW-ONLY. This RPC is "any_peer", so a malformed or
	# hostile payload could otherwise drive a counter downward and break the
	# monotonicity the paper's convergence proof rests on. The GCounter
	# singleton already refuses negatives (GCounter.increment), so accepting
	# them here would also silently DIVERGE this dictionary from the singleton
	# that the thesis exports. Reject at the boundary instead.
	if points <= 0:
		push_warning(
			"GameManager.submit_score: rejected non-positive increment %d from peer %d"
			% [points, sender_id]
		)
		return

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
	## Set the quota for the current minigame.
	##
	## Both peers run the same minigame script and each calls this locally, so
	## the values normally agree. They can disagree when a peer's adaptive
	## settings drift, and only the host evaluates _check_win_condition() — so
	## the host's value is canonical and must not be overwritten by a client's
	## locally computed one arriving afterwards.
	var from_remote: bool = multiplayer.get_remote_sender_id() != 0

	if from_remote or is_host or not _quota_from_host:
		current_minigame_quota = quota
		if from_remote:
			_quota_from_host = true
		print("🎯 Minigame quota set to: ", quota)
	else:
		print("🎯 Minigame quota kept at host value %d (ignored local %d)"
			% [current_minigame_quota, quota])

	# Push the host's quota to every connected peer.
	#
	# This previously iterated g_counter.keys() while skipping the host's own
	# id. Immediately after reset_multiplayer_game()/_load_next_multiplayer_
	# minigame() those keys are the connected peer ids, but on the very first
	# round of a session g_counter holds only the host — so the loop broadcast
	# to nobody and the client was left running on whatever quota it computed
	# itself. multiplayer.get_peers() is the actual peer list.
	if is_host and not from_remote:
		for peer_id in multiplayer.get_peers():
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

	# Assign P1/P2 by SORTED peer id, not dictionary insertion order.
	# Insertion order here is "whoever reported first", so the same round could
	# label the same human P1 on one evaluation and P2 on the next, making
	# CoopAdaptation's per-player history non-reproducible run to run. Peer id
	# is stable for the whole session, so sorting makes the mapping fixed.
	var ordered_ids: Array = pending_mp_performance.keys()
	ordered_ids.sort()
	var p1_perf: Dictionary = pending_mp_performance[ordered_ids[0]]
	var p2_perf: Dictionary = pending_mp_performance[ordered_ids[1]]

	# Team success = the round's quota was actually met.
	#
	# This used to be `get_global_score() > 0`, which reports success as soon as
	# either player scores a single point — so a round that ended 1/20 fed
	# CoopAdaptation a win and the co-op difficulty could only ever ratchet up.
	# Matches the criterion _apply_multiplayer_round_result already uses.
	var team_success: bool = (
		current_minigame_quota <= 0 or get_global_score() >= current_minigame_quota
	)

	if CoopAdaptation:
		CoopAdaptation.add_game_result(p1_perf, p2_perf, team_success)
		print("🎮 [MP] CoopAdaptation updated (P%d/P%d, team_success=%s, %d/%d)" % [
			ordered_ids[0], ordered_ids[1], team_success,
			get_global_score(), current_minigame_quota
		])

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
# SUPPLEMENTARY SPAWN PACER (not the paper's Φ adaptive difficulty)
#
# The thesis algorithm — Rule-Based Rolling Window, Φ = WMA - CP, selecting
# Easy/Medium/Hard — lives in autoload/AdaptiveDifficulty.gd. Everything below
# only stretches or squeezes in-round spawn INTERVALS so a round feels paced.
# It never chooses a difficulty tier and is not reported as thesis output.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func add_round_time(round_time: float, was_successful: bool = true) -> void:
	## Add a round completion time to the rolling window.
	## Window size = 5, calculates average and adjusts difficulty.
	##
	## was_successful matters: a round that ended in 0.5s because the player
	## FAILED instantly is not evidence of speed. A real soak produced the window
	## [0.49, 12.04, 3.179, 25.114, 3.669] — average 8.9s, read as "too fast" —
	## and ratcheted spawn pacing up on a player who was losing.
	rolling_window.append(round_time)
	rolling_window_success.append(was_successful)

	# Keep only last 5 entries (both windows stay index-aligned)
	while rolling_window.size() > ROLLING_WINDOW_SIZE:
		rolling_window.pop_front()
	while rolling_window_success.size() > ROLLING_WINDOW_SIZE:
		rolling_window_success.pop_front()

	# Only adjust after we have enough data
	if rolling_window.size() >= ROLLING_WINDOW_SIZE:
		_calculate_difficulty_adjustment()

	print("📊 Spawn Pacer Window: ", rolling_window)
	print("   Spawn Pacer Multiplier: ", difficulty_multiplier)

func _calculate_difficulty_adjustment() -> void:
	## SUPPLEMENTARY speed scaler for spawn intervals (NOT the paper's Φ algorithm).
	## The paper's Rule-Based Rolling Window with Φ = WMA - CP lives in
	## AdaptiveDifficulty.gd, which determines Easy/Medium/Hard difficulty.
	##
	## This method only adjusts difficulty_multiplier for in-round spawn pacing:
	##   AvgTime < 15s AND player is winning → multiplier += 0.2 (speed up spawns)
	##   AvgTime > 30s OR player is losing   → multiplier -= 0.1 (slow down spawns)
	var sum: float = 0.0
	for time in rolling_window:
		sum += time

	var avg_time: float = sum / float(rolling_window.size())
	print("📈 Spawn Pacer: Average Round Time: ", avg_time, "s")

	# Count failures in the window. Speeding up is only justified when the fast
	# times came from wins.
	var failures: int = 0
	for ok in rolling_window_success:
		if not ok:
			failures += 1
	var mostly_winning: bool = failures <= 1

	if avg_time < FAST_THRESHOLD and mostly_winning:
		difficulty_multiplier += 0.2
		print("⬆️ Spawn Pacer: faster spawns (fast wins) - Multiplier: %.2f" % difficulty_multiplier)
	elif avg_time > SLOW_THRESHOLD or failures >= 2:
		difficulty_multiplier -= 0.1
		print("⬇️ Spawn Pacer: slower spawns (slow or losing) - Multiplier: %.2f" % difficulty_multiplier)

	difficulty_multiplier = clampf(difficulty_multiplier, MIN_DIFFICULTY, MAX_DIFFICULTY)

	# Sync to clients if host
	if is_host and is_multiplayer_connected:
		rpc("_sync_difficulty", difficulty_multiplier)

@rpc("authority", "call_local", "reliable")
func _sync_difficulty(new_multiplier: float) -> void:
	# Sync difficulty multiplier from host to clients
	difficulty_multiplier = new_multiplier
	print("📡 Spawn Pacer multiplier synced: ", difficulty_multiplier)

func get_spawn_interval(base_interval: float) -> float:
	# Get adjusted spawn interval: base_time / difficulty_multiplier
	return base_interval / difficulty_multiplier

func reset_spawn_pacer() -> void:
	## Clear the supplementary spawn pacer back to its cold-start state.
	##
	## rolling_window and rolling_window_success are index-aligned by contract
	## (see add_round_time). Clearing one without the other leaves _calculate_
	## difficulty_adjustment counting failures from the PREVIOUS session against
	## this session's times, so a new player can be pace-punished for rounds they
	## never played. Both windows and the multiplier must reset together.
	rolling_window.clear()
	rolling_window_success.clear()
	difficulty_multiplier = 1.0

func reset_multiplayer_game() -> void:
	# Reset state for a new multiplayer round
	g_counter.clear()
	if multiplayer.multiplayer_peer:
		g_counter[multiplayer.get_unique_id()] = 0
	team_lives = MAX_TEAM_LIVES
	session_lives = MAX_TEAM_LIVES
	reset_spawn_pacer()
	minigames_played_this_session = 0
	session_score = 0
	session_droplets_earned = 0
	completed_minigames.clear()
	round_scores.clear()
	multiplayer_game_order.clear()
	multiplayer_game_index = 0
	player_modes.clear()
	current_multiplayer_game_name = ""
	_recorded_multiplayer_round_game = ""
	_quota_from_host = false
	_play_again_pending = false
	
	if is_host:
		rpc("_sync_game_state", g_counter, team_lives, difficulty_multiplier)

func get_connected_multiplayer_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	if multiplayer.multiplayer_peer == null:
		return peer_ids
	peer_ids.append(multiplayer.get_unique_id())
	for peer_id in multiplayer.get_peers():
		peer_ids.append(peer_id)
	peer_ids.sort()
	return peer_ids

func is_multiplayer_session_ready() -> bool:
	return is_multiplayer_connected and get_connected_multiplayer_peer_ids().size() >= MAX_PLAYERS

@rpc("authority", "call_local", "reliable")
func _begin_multiplayer_session_rpc() -> void:
	start_new_session(GameMode.MULTIPLAYER_COOP)

@rpc("any_peer", "call_local", "reliable")
func _play_again_multiplayer_rpc() -> void:
	## Called by either player to restart the session without going to the lobby.
	## The 'any_peer' mode lets both host and client trigger a restart.
	## Guard prevents a race-condition when both players press at the same time.
	if _play_again_pending:
		return
	_play_again_pending = true
	print("🔄 [Multiplayer] Play Again — restarting session!")
	start_new_session(GameMode.MULTIPLAYER_COOP)
	advance_multiplayer_round()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER MINIGAME PROGRESSION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Multiplayer minigame pool (all cooperative water-themed games)
var multiplayer_minigames: Array[String] = [
	"MP_CatchRainAquarium",
	"MP_CatchTheRain",
	"MP_CollectDishWater",
	"MP_CollectLaundryWater",
	"MP_CollectShowerWater",
	"MP_FillAquarium",
	"MP_FilterWater",
	"MP_FlushToilets",
	"MP_MopFloor",
	"MP_WashCar",
	"MP_WashVegetables",
	"MP_WaterPlants"
]

var multiplayer_game_order: Array[String] = []
var multiplayer_game_index: int = 0

# Mode assignment for current game (randomized each game)
var player_modes: Dictionary = {}  # {peer_id: int (1 or 2)}

## Decide who plays which of the two co-op modes for the next round.
##
## Returns the mapping instead of writing player_modes directly, because the choice
## is RANDOM and must be made once, by the host, then shipped to every peer. See
## advance_multiplayer_round().
func _decide_player_modes() -> Dictionary:
	var modes: Dictionary = {}
	var peer_ids: Array[int] = get_connected_multiplayer_peer_ids()
	if peer_ids.is_empty():
		return modes

	# If only one peer is present (debug/testing), force mode 1.
	if peer_ids.size() == 1:
		modes[peer_ids[0]] = 1
		return modes

	# Shuffle and assign alternating roles
	peer_ids.shuffle()
	for i in range(peer_ids.size()):
		modes[peer_ids[i]] = (i % 2) + 1  # Alternates between 1 and 2

	return modes

## Host-only entry point for the multiplayer round advance. Decides WHICH game and
## WHICH mode assignment the next round uses, then broadcasts the decision.
##
## The decision has to be made exactly once, on one peer. It used to be made inside
## _load_next_multiplayer_minigame() itself — which runs on every peer via
## @rpc("call_local") — so each peer shuffled multiplayer_game_order with its own
## unseeded RNG and then indexed into a different list. Measured on the real network
## (tools/VerifyRoundAdvance.tscn): on the first round advance the host loaded
## MP_MopFloor while the client loaded MP_FillAquarium. The same applied to the
## random mode assignment, which decides each player's role inside the round.
##
## This is the pattern NetworkManager._load_next_round() already uses for the
## LevelSets path: the host picks, the pick travels as an RPC argument.
func advance_multiplayer_round() -> void:
	if not is_host:
		return

	# If we've played all games in current shuffle, reshuffle
	if multiplayer_game_order.is_empty() or multiplayer_game_index >= multiplayer_game_order.size():
		multiplayer_game_order = multiplayer_minigames.duplicate()
		multiplayer_game_order.shuffle()
		multiplayer_game_index = 0
		print("🔀 Shuffled multiplayer minigame order: ", multiplayer_game_order)

	var game_name: String = multiplayer_game_order[multiplayer_game_index]
	multiplayer_game_index += 1

	rpc("_load_next_multiplayer_minigame", game_name, _decide_player_modes())


func get_my_player_mode() -> int:
	# Get my assigned mode (1 or 2)
	var my_id = multiplayer.get_unique_id()
	return player_modes.get(my_id, 1)  # Default to mode 1

func record_multiplayer_round_result(
	game_name: String,
	round_time_seconds: float,
	victory: bool,
	mistakes: int = 0,
	best_combo: int = 0
) -> void:
	if not is_host:
		return
	var round_score: int = max(get_global_score(), 0)
	rpc(
		"_apply_multiplayer_round_result",
		game_name,
		round_time_seconds,
		round_score,
		victory,
		mistakes,
		best_combo
	)

@rpc("authority", "call_local", "reliable")
func _apply_multiplayer_round_result(
	game_name: String,
	round_time_seconds: float,
	round_score: int,
	victory: bool,
	mistakes: int,
	best_combo: int
) -> void:
	if not session_active:
		return

	var resolved_game_name := game_name
	if resolved_game_name.is_empty():
		resolved_game_name = current_multiplayer_game_name
	if resolved_game_name.is_empty():
		resolved_game_name = "MultiplayerRound"

	# Guard against duplicate result submissions for the same round.
	if _recorded_multiplayer_round_game == resolved_game_name:
		return
	_recorded_multiplayer_round_game = resolved_game_name

	var clamped_time: float = max(round_time_seconds, 0.0)
	var clamped_score: int = max(round_score, 0)
	var clamped_mistakes: int = max(mistakes, 0)
	var clamped_combo: int = max(best_combo, 0)
	var accuracy := 0.0
	if current_minigame_quota > 0:
		accuracy = clampf(float(clamped_score) / float(current_minigame_quota), 0.0, 1.0)

	# Quota met == the round was a win. With no quota declared there is nothing
	# to have failed, so the round counts as successful.
	var mp_successful: bool = current_minigame_quota <= 0 or clamped_score >= current_minigame_quota
	add_round_time(clamped_time, mp_successful)

	if not resolved_game_name in completed_minigames:
		completed_minigames.append(resolved_game_name)

	minigames_played_this_session += 1
	session_score += clamped_score
	session_lives = team_lives

	round_scores.append({
		"game": resolved_game_name,
		"score": clamped_score,
		"combo": clamped_combo,
		"accuracy": accuracy,
		"mistakes": clamped_mistakes,
		"reaction_time": int(clamped_time * 1000.0),
		"victory": victory
	})

	if PerformanceProfiler:
		PerformanceProfiler.log_event("multiplayer_round_complete", {
			"game_name": resolved_game_name,
			"victory": victory,
			"round_score": clamped_score,
			"session_score": session_score,
			"team_lives": team_lives,
			"round_time_s": clamped_time,
		})

@rpc("authority", "call_local", "reliable")
func _load_next_multiplayer_minigame(game_name: String, modes: Dictionary) -> void:
	# Load the next multiplayer minigame (loop until lives depleted).
	# `game_name` and `modes` are the host's decision — see advance_multiplayer_round().
	if multiplayer.multiplayer_peer == null or not is_multiplayer_connected:
		push_warning("Multiplayer connection is not active. Returning to lobby.")
		return_to_multiplayer_lobby()
		return

	if team_lives <= 0:
		_show_multiplayer_final_results()
		return

	if current_game_mode != GameMode.MULTIPLAYER_COOP:
		current_game_mode = GameMode.MULTIPLAYER_COOP
	if not session_active:
		session_active = true

	print("🎮 [Multiplayer] Loading next minigame...")
	
	# Reset G-Counter for next round (but keep lives and difficulty)
	g_counter.clear()
	for peer_id in get_connected_multiplayer_peer_ids():
		g_counter[peer_id] = 0
	
	# Reset quota to 0 so new game can set it
	current_minigame_quota = 0
	_quota_from_host = false
	_recorded_multiplayer_round_game = ""

	# Clear last round's performance reports. Only the host consumes these
	# (_check_both_players_done runs host-side), so on the client the entry it
	# stored for itself was never cleared and stayed live for the whole session.
	pending_mp_performance.clear()

	# Clear NetworkManager's per-round state too. This function IS the shipped round
	# advance and runs on every peer (@rpc "call_local"), but it used to reset only
	# GameManager's half: _ready_signal_emitted, _countdown_started_this_round and
	# players[peer]["ready"] stayed latched from round 1, so from round 2 on the
	# "both players ready" route returned early and the countdown arrived only via
	# MultiplayerMiniGameBase's 6 s fallback — a stall before every later round.
	# Called directly, not by rpc(): each peer is already executing this function
	# locally, so a broadcast here would fire the reset N times per round.
	if NetworkManager and NetworkManager.has_method("reset_round_status"):
		NetworkManager.reset_round_status()

	# Apply the host's mode assignment for this round. Every peer gets the same
	# dictionary, so get_my_player_mode() agrees across the session.
	player_modes = modes.duplicate()
	print("🎲 Mode assignments: ", player_modes)

	current_multiplayer_game_name = game_name

	print("🎯 Next game: ", game_name)
	print("❤️ Team Lives: ", team_lives)
	print("⚡ Difficulty Multiplier: %.2f" % difficulty_multiplier)
	
	# Load the scene
	var game_path: String = "res://scenes/multiplayer/%s.tscn" % game_name
	if ResourceLoader.exists(game_path):
		transition_to_scene(game_path, 0.25)
	else:
		push_error("❌ Multiplayer minigame scene not found: ", game_path)
		_show_multiplayer_final_results()

@rpc("authority", "call_local", "reliable")
func _show_multiplayer_final_results() -> void:
	# Use the shared final score flow so multiplayer mirrors single-player UX.
	print("🏁 Multiplayer session ended!")
	print("   Games Played: ", minigames_played_this_session)
	print("   Final Difficulty: %.2f" % difficulty_multiplier)
	print("   Session Score: ", session_score)

	all_minigames_completed.emit()
	_show_final_score()

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

func start_session(mode: GameMode = GameMode.SINGLE_PLAYER) -> void:
	# Backward-compatible API used by older menu scripts.
	start_new_session(mode)
	if mode == GameMode.SINGLE_PLAYER:
		start_next_minigame()

func start_new_session(mode: GameMode = GameMode.SINGLE_PLAYER) -> void:
	current_game_mode = mode
	session_active = true
	_session_finalized = false
	completed_minigames.clear()
	current_minigame_index = 0
	minigames_played_this_session = 0
	session_lives = 3
	session_score = 0
	session_droplets_earned = 0
	round_scores.clear()
	pending_next_minigame_name = ""
	_story_shown_at.clear()
	_story_transition_active = false
	var save_mgr = get_node_or_null("/root/SaveManager")
	
	# The adaptive algorithm is cleared when a session BEGINS, not when one ends.
	# It used to be cleared inside _finalize_session_for_logging() instead, two lines
	# above SessionLogger.export_session() - so every AdaptiveDifficulty-derived field
	# in every exported session log was read AFTER the wipe. Measured over the 54
	# session logs in user://: final_difficulty read "Easy" in 52 and "Medium" in 2 and
	# "Hard" in none (Hard was actually played in 9 of them), and final_phi read exactly
	# 0.0 in 49 - the _initialize_session() defaults, not measurements. FinalScore.gd:437
	# read it post-wipe too, so the end-of-session screen printed "Difficulty: Easy" no
	# matter how the session had gone. That is the artifact behind the report "many games
	# but I only got to Medium and it did not get harder".
	# Resetting here instead keeps the finished session's state readable by every
	# end-of-session consumer while still guaranteeing a clean start, and it now covers
	# BOTH modes: a co-op session opened after a single-player one used to inherit the
	# previous player's window because only the SINGLE_PLAYER branch reset it.
	if has_node("/root/AdaptiveDifficulty"):
		AdaptiveDifficulty.reset()
	# Same contract for the co-op algorithm, which had no session boundary at all:
	# CoopAdaptation.reset_session() existed and was called from nowhere in the
	# project, so a second co-op session in the same process kept the previous team's
	# per-player windows, proficiencies, sync history and skill_gap. A pair who had
	# just been classified Hard/Medium started their next match already there, and the
	# mp_algorithm block of the next session log reported the earlier team's numbers.
	if has_node("/root/CoopAdaptation") and CoopAdaptation.has_method("reset_session"):
		CoopAdaptation.reset_session()

	if mode == GameMode.SINGLE_PLAYER:
		# Hard reset any multiplayer remnants so single-player never hijacks flow.
		if is_multiplayer_connected or multiplayer.multiplayer_peer:
			disconnect_multiplayer()
			session_active = true  # Restore: disconnect_multiplayer() resets this flag
		if save_mgr and save_mgr.has_method("reset_session_stats"):
			save_mgr.reset_session_stats()
		reset_spawn_pacer()
		_refresh_available_minigames()
		_rebuild_minigame_random_bag()
		_load_saved_data()
		if save_mgr and save_mgr.has_method("get_droplets"):
			water_droplets = int(save_mgr.get_droplets())
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
	if _story_transition_active:
		return

	if current_game_mode == GameMode.MULTIPLAYER_COOP:
		if is_host:
			advance_multiplayer_round()
		return

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
	if minigames_played_this_session == 0:
		return 0 not in _story_shown_at
	if minigames_played_this_session % STORY_INTERVAL_GAMES != 0:
		return false
	return minigames_played_this_session not in _story_shown_at

func _show_story_then_continue() -> void:
	if _story_transition_active:
		return
	_story_transition_active = true
	_story_shown_at.append(minigames_played_this_session)
	var story_path := "res://scenes/ui/StoryScreen.tscn"
	if not ResourceLoader.exists(story_path):
		_story_transition_active = false
		_launch_next_minigame_internal()
		return
	var story_scene = load(story_path).instantiate()
	var scene_root := get_tree().current_scene
	if scene_root == null:
		_story_transition_active = false
		_launch_next_minigame_internal()
		return
	var story_layer := CanvasLayer.new()
	story_layer.name = "StoryScreenLayer"
	story_layer.layer = 200
	story_layer.add_child(story_scene)
	scene_root.add_child(story_layer)
	story_scene.story_finished.connect(func():
		if is_instance_valid(story_layer):
			story_layer.queue_free()
		_story_transition_active = false
		_launch_next_minigame_internal()
	, CONNECT_ONE_SHOT)
	story_scene.tree_exited.connect(func():
		_story_transition_active = false
	, CONNECT_ONE_SHOT)

func _launch_next_minigame_internal() -> void:
	_cleanup_stale_story_overlays()

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

func _cleanup_stale_story_overlays() -> void:
	var root := get_tree().root
	if root == null:
		return
	_cleanup_story_nodes_recursive(root)

func _cleanup_story_nodes_recursive(node: Node) -> void:
	for child in node.get_children():
		_cleanup_story_nodes_recursive(child)
		if child.scene_file_path == "res://scenes/ui/StoryScreen.tscn":
			child.queue_free()

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
		# Remember the SCENE basename, which is the only form that can be
		# reloaded. round_scores records the DISPLAY name ("Water Plant"),
		# so it cannot be used to build a scene path.
		last_launched_minigame_name = game_name
		get_tree().change_scene_to_file(game_path)
	else:
		push_warning("Mini-game not found: ", game_path)
		# Try the next one immediately if one entry is stale.
		start_next_minigame()

## Replay the round that is loaded right now, without advancing the roster.
##
## MiniGameResults RETRY has called this since that screen was authored and
## the method never existed anywhere in the project, so pressing RETRY raised
## "Invalid call. Nonexistent function 'replay_current_minigame' in base
## GameManager" and left the player on the results screen. Deliberately does
## NOT touch lives, session_score or the random bag: a replay repeats one
## round, it does not rewind the run.
func replay_current_minigame() -> void:
	if last_launched_minigame_name.is_empty():
		# Nothing has been launched through launch_pending_minigame() yet
		# (a round entered directly, e.g. from a tool). Advancing is the only
		# honest option; silently doing nothing would strand the player.
		start_next_minigame()
		return
	pending_next_minigame_name = last_launched_minigame_name
	launch_pending_minigame()

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
			elif unlock_id in ALL_SINGLEPLAYER_MINIGAMES:
				# Per-game store purchases use the minigame name as the id.
				if unlock_id not in filtered:
					filtered.append(unlock_id)

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
	# Rebuild the random bag so newly-purchased bundles enter the rotation
	# immediately instead of waiting for the stale bag to drain.
	_rebuild_minigame_random_bag()

## `game_name` is the DISPLAY title ("Mud Pie Maker", and for FixLeakV2 the title in
## whatever language is set), so it cannot be an identity. `game_id` is the scene
## basename MiniGameBase._get_minigame_key() returns ("MudPieMaker", "FixLeak"), and
## it is what everything that has to MATCH rows uses below: the completed set, the
## per-game high-score record (SaveManager's parameter is literally called game_id),
## the algorithm's log, the thesis export, and the minigame_completed signal — which
## pairs with minigame_started, and started has always carried the scene id, so the
## two were not joinable. A Filipino session used to log "Ayusin ang Tagas" and an
## English one "Fix Leak" for the same game, in the same save file.
## Defaults to the display title so the older 7-argument call form still works.
func complete_minigame(
	game_name: String, accuracy: float,
	reaction_time: int, mistakes: int,
	round_score_override: int = -1,
	best_combo: int = 0,
	was_successful: bool = true,
	game_id: String = ""
) -> void:
	var gid: String = game_id.strip_edges()
	if gid.is_empty():
		gid = game_name
	if not gid in completed_minigames:
		completed_minigames.append(gid)
	
	minigames_played_this_session += 1
	
	var round_score: int = int(accuracy * 100.0) - (mistakes * 10)
	round_score = max(0, round_score)
	if round_score_override >= 0:
		round_score = round_score_override
	session_score += round_score
	var round_time_seconds: float = float(reaction_time) / 1000.0
	round_scores.append({
		"game": game_name,
		"score": round_score,
		"combo": best_combo,
		"accuracy": accuracy,
		"mistakes": mistakes,
		"reaction_time": reaction_time
	})

	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("record_game_result"):
		save_mgr.record_game_result(gid, round_score, accuracy, round_time_seconds)
		# Note: droplets for SP games are awarded by MiniGameBase.end_game().
		# Droplets for MP games are awarded by NetworkManager._check_both_completed().
		if save_mgr.has_method("get_droplets"):
			water_droplets = int(save_mgr.get_droplets())
	
	# Add to rolling window for difficulty adjustment
	add_round_time(round_time_seconds, was_successful)
	
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
	#   2) After warmup, evaluates Φ on each completed game
	#   3) Uses the decision tree to adjust difficulty (Easy/Medium/Hard)
	#
	# The NEW difficulty then applies to the NEXT minigame the player starts!
	# ═══════════════════════════════════════════════════════════════════════
	if current_game_mode == GameMode.SINGLE_PLAYER:
		# Single-player uses AdaptiveDifficulty (Φ = WMA - CP algorithm)
		# This is the RULE-BASED ROLLING WINDOW ALGORITHM in action!
		if AdaptiveDifficulty:
			AdaptiveDifficulty.add_performance(accuracy, reaction_time, mistakes, gid)
		# Log SP game to SessionLogger for thesis defence export
		var _session_logger = get_node_or_null("/root/SessionLogger")
		if _session_logger and _session_logger.has_method("record_sp_game"):
			var _sp_diff = AdaptiveDifficulty.get_current_difficulty() if AdaptiveDifficulty else "Unknown"
			var _logged_droplets := int(_session_logger.get("total_droplets_earned"))
			var _droplets_this_round: int = max(0, session_droplets_earned - _logged_droplets)
			# reaction_time here is the value the ALGORITHM consumed (per-action
			# latency, or round duration when the round graded no discrete actions).
			# The log has to carry the same number the algorithm saw, or the exported
			# sigma cannot be recomputed from the log.
			_session_logger.record_sp_game(gid, round_score, accuracy, reaction_time, mistakes, _sp_diff, _droplets_this_round)
	else:
		# Multiplayer uses CoopAdaptation (per-player difficulty with sync scoring)
		# Note: In multiplayer, performance is tracked via submit_score RPC
		# CoopAdaptation.add_game_result() should be called after BOTH players complete
		if CoopAdaptation and is_host:
			# Store this player's performance temporarily
			_store_multiplayer_performance(gid, accuracy, reaction_time, mistakes)
	
	var results: Dictionary = {
		"game_name": game_name,
		"game_id": gid,
		"accuracy": accuracy,
		"reaction_time": reaction_time,
		"mistakes": mistakes,
		"difficulty": get_current_difficulty()
	}
	
	# Log event for dev-mode performance analysis
	if PerformanceProfiler:
		PerformanceProfiler.log_event("minigame_complete", {
			"game_name": game_name,
			"game_id": gid,
			"accuracy": accuracy,
			"reaction_time_ms": reaction_time,
			"mistakes": mistakes,
			"difficulty": get_current_difficulty(),
			"round_score": round_score,
			"session_score": session_score,
			"lives": session_lives,
			"difficulty_multiplier": difficulty_multiplier,
		})
	
	minigame_completed.emit(gid, results)
	change_state(GameState.MINIGAME_RESULTS)
	current_minigame_index += 1

func add_session_droplets(amount: int) -> void:
	if amount <= 0:
		return
	session_droplets_earned += amount

func _persist_singleplayer_session_results() -> void:
	if current_game_mode != GameMode.SINGLE_PLAYER:
		return

	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("record_sp_session_score"):
		save_mgr.record_sp_session_score(session_score)

	if session_score > high_score:
		high_score = session_score

	_save_data()

func get_current_difficulty() -> String:
	# Dynamic difficulty classification that works with uncapped values
	if difficulty_multiplier >= 2.0:
		return "Extreme"  # New tier for very high speeds
	if difficulty_multiplier >= 1.5:
		return "Hard"
	if difficulty_multiplier >= 1.0:
		return "Medium"
	return "Easy"

func return_to_main_menu() -> void:
	_finalize_session_for_logging()
	change_state(GameState.MAIN_MENU)
	get_tree().paused = false
	
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")


# ── Multiplayer departure notice ──────────────────────────────────────────────────
#
# Holds a LOCALIZATION KEY, never a sentence, so a language switch between the queueing
# and the reading still renders the right language — each consumer resolves it through
# its own translation table.
#
# This channel shipped with a consumer and no producer: scenes/ui/MultiplayerMenu.gd:12
# has always called consume_multiplayer_notice() behind a has_method() guard, and no such
# method existed anywhere in the project, so the guard swallowed it and a player yanked
# out of a round arrived at a screen that said nothing about why the round vanished. The
# producers are the three involuntary exits in NetworkManager: the server went away, the
# partner went away, and the reconnect window expired with nobody back.
var _multiplayer_notice: String = ""


## Queue a reason for the next multiplayer screen to show. FIRST writer wins.
##
## One departure fires several handlers in the same frame — peer_disconnected reaches
## NetworkManager._on_player_disconnected() about 30 ms before server_disconnected reaches
## _on_server_disconnected() (measured in tools/VerifyHostDeparture.gd) — and the earliest
## one describes the event most specifically, so later, vaguer writers must not overwrite it.
func set_multiplayer_notice(key: String) -> void:
	if _multiplayer_notice.is_empty():
		_multiplayer_notice = key


## Read and clear. Clearing on read is what stops a stale reason from surfacing two screens
## later, out of context, next time the player opens multiplayer.
func consume_multiplayer_notice() -> String:
	var key: String = _multiplayer_notice
	_multiplayer_notice = ""
	return key

func return_to_multiplayer_lobby() -> void:
	get_tree().paused = false
	disconnect_multiplayer()
	transition_to_scene("res://scenes/ui/MultiplayerLobby.tscn", 0.2)

func _show_final_score() -> void:
	print("🎉 Session complete! Showing final score...")
	change_state(GameState.FINAL_RESULTS)

	_finalize_session_for_logging()
	
	if ResourceLoader.exists("res://scenes/ui/FinalScore.tscn"):
		transition_to_scene("res://scenes/ui/FinalScore.tscn")
	else:
		transition_to_scene("res://scenes/ui/InitialScreen.tscn")

func _finalize_session_for_logging() -> void:
	if not session_active or _session_finalized:
		return

	_session_finalized = true
	_persist_singleplayer_session_results()
	session_active = false

	var adaptive_summary: Dictionary = {}
	if AdaptiveDifficulty and AdaptiveDifficulty.has_method("get_algorithm_status"):
		adaptive_summary = AdaptiveDifficulty.get_algorithm_status()

	# Export dev/thesis logs before resetting session counters.
	if PerformanceProfiler:
		PerformanceProfiler.log_event("session_end", {
			"total_score": session_score,
			"high_score": high_score,
			"games_played": minigames_played_this_session,
			"lives_remaining": session_lives,
			"session_droplets_earned": session_droplets_earned,
			"adaptive_session_games": int(adaptive_summary.get("session_games_played", 0)),
			"adaptive_lifetime_games": int(adaptive_summary.get("lifetime_games_played", 0)),
			"adaptive_phi": float(adaptive_summary.get("proficiency_index", 0.0)),
			"adaptive_difficulty": str(adaptive_summary.get("current_difficulty", "Easy")),
			"adaptive_window_size": int(adaptive_summary.get("games_in_window", 0)),
			"adaptive_min_games": int(adaptive_summary.get("min_games_before_adaptation", 0)),
		})
		PerformanceProfiler.export_session_log_to_file()

	if AdaptiveDifficulty:
		if AdaptiveDifficulty.has_method("export_to_json_file"):
			AdaptiveDifficulty.export_to_json_file()
		# No reset() here. This function is the session's LAST READER of the algorithm,
		# not its owner: the case study above, SessionLogger.export_session() below and
		# the FinalScore screen this call returns into all read the finished session's
		# tier, Phi, WMA, CP and progressive_level. Clearing them here silently zeroed
		# every one of those consumers - the ordering held only for whichever export
		# happened to sit above the call. The clear now happens in start_new_session(),
		# where a session actually begins.

	# Export SessionLogger data - ensures session is saved even if app is killed
	# via Home button on Android (NOTIFICATION_WM_CLOSE_REQUEST may not fire)
	var _sl = get_node_or_null("/root/SessionLogger")
	if _sl and _sl.has_method("export_session"):
		_sl.export_session()

	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("reset_session_stats"):
		save_mgr.reset_session_stats()

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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ANDROID BACK BUTTON
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Routed here because quit_on_go_back is turned off in _ready(). See there for what
## the behaviour was before: an unconditional SceneTree.quit() from any screen.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back_request()


## Where Back goes from the screen that is currently loaded.
##
## Deliberately NOT a path-to-path route table. A table has to be kept in step with
## every screen that is ever added and rots silently when it is not, and it cannot
## know that a minigame's Back means "pause" rather than "leave". Instead each screen
## that needs its own answer implements on_back_requested() and returns true to say
## it handled it; everything else falls through to the hub, which is never a dead end.
##
## Returns what it did, so tools/VerifyBackButton.tscn can assert on it rather than
## on a print.
func handle_back_request() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return "no_scene"

	# 1. The screen's own answer wins. MiniGameBase and MultiplayerMiniGameBase
	#    implement this as a pause toggle, because a round in progress must not be
	#    silently discarded by a stray gesture - the round has real score, lives and
	#    algorithm data attached to it.
	if scene.has_method("on_back_requested"):
		if scene.on_back_requested() == true:
			return "handled_by_scene"

	# 2. The title screen and the hub are the top of the stack. Back from the top of
	#    an Android activity stack closes the app, which is what a player expects
	#    there and nowhere else.
	var path: String = scene.scene_file_path
	if path == "res://scenes/ui/InitialScreen.tscn" \
			or path == "res://scenes/ui/MainMenu.tscn":
		get_tree().quit()
		return "quit_from_root"

	# 3. Anything else goes to the hub. A default rather than an enumeration, so a
	#    screen added later gets sane Back behaviour for free instead of inheriting
	#    "kill the app".
	return_to_main_menu()
	return "returned_to_hub"
