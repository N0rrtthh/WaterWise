extends Node

## ═══════════════════════════════════════════════════════════════════
## AUTO-PLAY MANAGER - Automated Testing Mode
## ═══════════════════════════════════════════════════════════════════
## Automatically plays mini-games for performance testing and data collection
## without human intervention.
##
## Purpose: Collect thermal throttling, battery drain, and performance stats
## during long automated testing sessions.
##
## Features:
## - Works in both Single-Player and Multiplayer modes
## - Adapts to different mini-game mechanics (tap, drag, swipe, timing)
## - Plays optimally to generate consistent performance data
## - Toggleable via dev_mode in Settings
##
## Usage:
## 1. Enable "Dev Mode" in Settings
## 2. Enable "Auto-Play Mode" toggle
## 3. Start playing - the AI will take over gameplay
## ═══════════════════════════════════════════════════════════════════

signal state_changed(is_enabled: bool)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-PLAY STATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var auto_play_enabled: bool = false
var mp_auto_play_enabled: bool = false  # Separate toggle for multiplayer only
var current_game: Node = null
var game_name: String = ""
var auto_play_strategy: String = ""  # tap, drag, swipe, timing, memory, trace
## How long a pause with nothing to dismiss is tolerated before the driver clears
## it. Long enough that a legitimate one-frame pause is not fought over, short
## enough that a soak loses seconds rather than the rest of the run.
const PAUSE_GRACE_SECONDS: float = 3.0
## Real seconds the tree has been paused with the bot running. Accumulated from
## _process's delta, which is real time because this autoload processes always.
var _paused_seconds: float = 0.0

# Duration settings (in seconds, 0 = unlimited)
var auto_play_duration: float = 0.0  # 0 = unlimited
var auto_play_start_time: int = 0
var auto_play_elapsed: float = 0.0

# MP-specific duration (mirrors SP duration concept)
var mp_auto_play_duration: float = 0.0  # 0 = unlimited
var mp_auto_play_start_time: int = 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-PLAY BEHAVIOR TIMERS & STATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var action_timer: float = 0.0
var action_interval: float = 0.3  # Default interval between actions
var drag_target: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var swipe_cooldown: float = 0.0
var tap_cooldown: float = 0.0
var memory_pairs: Array = []

# Navigation state (used when no game is active — clicks through menus)
var nav_timer: float = 0.0
var nav_interval: float = 2.5  # Seconds to wait before each menu action
var memory_first_card: Node = null
var trace_path_index: int = 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PERFORMANCE STATS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var games_played: int = 0
var total_score: int = 0
var average_accuracy: float = 0.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	# The bot must keep running while the tree is paused, because a pause is a
	# state it can enter by accident and cannot otherwise leave: get_tree().paused
	# stopped this _process, so the code that dismisses the overlay was frozen by
	# the overlay. Everything gameplay-related still returns early while paused —
	# see the guard in _process() — so this does not let the bot play through a
	# pause, only end one.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load saved auto-play preferences
	if SaveManager:
		auto_play_enabled = SaveManager.get_setting("auto_play_enabled", false)
		auto_play_duration = SaveManager.get_setting("auto_play_duration", 0.0)
	
	print("🤖 AutoPlayManager initialized (Auto-play: %s, Duration: %s)" % [
		"ON" if auto_play_enabled else "OFF",
		_format_duration(auto_play_duration) if auto_play_duration > 0 else "Unlimited"
	])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-PLAY CONTROL
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Turn auto-play on or off.
##
## `persist` exists for the soak harnesses in tools/, and it is not a convenience. They
## used to enable auto-play the way the Settings toggle does, which writes the flag into
## the player's real settings file - so a soak run killed rather than allowed to finish (a
## `timeout`, a Ctrl-C) never reached its restore and left auto_play_enabled=true behind in
## waterwise_settings.json. The next process to boot inherited an autoplayer:
## tools/VerifyStrayAudio spent three of its six cases watching AutoNav click Play on the
## hub, advance the story screen and finally navigate away from the round it was measuring
## ("Cannot call method 'get' on a previously freed instance"), and blamed its own fixture.
## A real play session started on that machine would have been hijacked the same way.
func set_auto_play_enabled(enabled: bool, persist: bool = true) -> void:
	auto_play_enabled = enabled
	
	if SaveManager and persist:
		SaveManager.set_setting("auto_play_enabled", enabled)
	
	if enabled:
		auto_play_start_time = Time.get_ticks_msec()
		auto_play_elapsed = 0.0
		games_played = 0
		total_score = 0
		nav_timer = -2.0  # Give 2-second grace before first nav action
		
		var duration_str = (
			_format_duration(auto_play_duration) 
			if auto_play_duration > 0 
			else "Unlimited"
		)
		print(
			"🤖 Auto-play ENABLED - AI will play games automatically (Duration: %s)" 
			% duration_str
		)
		state_changed.emit(true)
	else:
		_reset_state()
		print("🤖 Auto-play DISABLED (Played for %s)" % _format_duration(auto_play_elapsed))
		state_changed.emit(false)

func set_auto_play_duration(minutes: float) -> void:
	auto_play_duration = minutes * 60.0  # Convert to seconds
	
	if SaveManager:
		SaveManager.set_setting("auto_play_duration", auto_play_duration)
	
	var duration_str = (
		_format_duration(auto_play_duration) 
		if auto_play_duration > 0 
		else "Unlimited"
	)
	print("🤖 Auto-play duration set to: %s" % duration_str)

func get_auto_play_duration_minutes() -> float:
	return auto_play_duration / 60.0

func get_remaining_time() -> float:
	if auto_play_duration <= 0:
		return -1.0  # Unlimited
	
	var elapsed = (Time.get_ticks_msec() - auto_play_start_time) / 1000.0
	return max(0.0, auto_play_duration - elapsed)

func is_auto_play_enabled() -> bool:
	return auto_play_enabled

func set_mp_auto_play_enabled(enabled: bool) -> void:
	mp_auto_play_enabled = enabled
	if enabled:
		mp_auto_play_start_time = Time.get_ticks_msec()
		var dur_str = _format_duration(mp_auto_play_duration) if mp_auto_play_duration > 0 else "Unlimited"
		print("🤖 MP Auto-play ENABLED (Duration: %s)" % dur_str)
	else:
		mp_auto_play_start_time = 0
		print("🤖 MP Auto-play DISABLED")

func is_mp_auto_play_enabled() -> bool:
	return mp_auto_play_enabled

func set_mp_auto_play_duration(minutes: float) -> void:
	mp_auto_play_duration = minutes * 60.0
	var dur_str = _format_duration(mp_auto_play_duration) if mp_auto_play_duration > 0 else "Unlimited"
	print("🤖 MP Auto-play duration set to: %s" % dur_str)

func get_mp_auto_play_duration_minutes() -> float:
	return mp_auto_play_duration / 60.0

func get_mp_remaining_time() -> float:
	if mp_auto_play_duration <= 0:
		return -1.0  # Unlimited
	if mp_auto_play_start_time == 0:
		return mp_auto_play_duration
	var elapsed := (Time.get_ticks_msec() - mp_auto_play_start_time) / 1000.0
	return max(0.0, mp_auto_play_duration - elapsed)

func _reset_state() -> void:
	current_game = null
	game_name = ""
	auto_play_strategy = ""
	_paused_seconds = 0.0
	drag_target = Vector2.ZERO
	is_dragging = false
	swipe_cooldown = 0.0
	tap_cooldown = 0.0
	memory_pairs.clear()
	memory_first_card = null
	trace_path_index = 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME REGISTRATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func register_game(game: Node, game_type: String) -> void:
	if not auto_play_enabled:
		return

	current_game = game
	game_name = game_type
	auto_play_strategy = _determine_strategy(game_type)
	action_timer = 0.0

	print("🤖 Auto-play registered: %s (Strategy: %s)" % [game_type, auto_play_strategy])

func unregister_game() -> void:
	if current_game:
		games_played += 1
		print("🤖 Auto-play completed game #%d: %s" % [games_played, game_name])
	
	_reset_state()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STRATEGY DETERMINATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _determine_strategy(game_type: String) -> String:
	# Map game names to their input strategies
	var strategies := {
		# Tap-based games
		"Timing Tap": "timing_tap",
		"Turn Off Tap": "tap_targets",
		"Spot The Speck": "tap_targets",
		"Plug The Leak": "tap_targets",
		"Fix Leak": "fix_leak",
		"Fix the Leak": "fix_leak",
		"Thirsty Plant": "thirsty_plant",
		"Water Plant": "tap_targets",
		
		# Drag-based games
		"Catch The Rain": "drag_catcher",
		"Bucket Brigade": "drag_catcher",
		"Cloud Catcher": "cloud_catcher",
		"Droplet Dash": "drag_avoid",
		"Cover The Drum": "cover_the_drum",
		"Filter Builder": "drag_arrange",
		
		# Swipe-based games
		"Swipe The Soap": "swipe_direction",
		"Wring It Out": "swipe_direction",
		"Scrub To Save": "scrub_to_save",
		
		# Sorting/Selection games
		"Greywater Sorter": "tap_targets",
		"Rice Wash Rescue": "tap_targets",
		"Vegetable Bath": "tap_targets",
		
		# Memory/Pattern games
		"Water Memory": "memory_match",
		"Trace Pipe Path": "trace_path",
		
		# Special games
		"Quick Shower": "quick_shower",
		"Toilet Tank Fix": "toilet_tank_fix",
		"Mud Pie Maker": "mud_pie_maker",
		"Rainwater Harvesting": "tap_targets",
		
		# ═══════════════════════════════════════════════════════════════
		# MULTIPLAYER GAMES (Main 5)
		# ═══════════════════════════════════════════════════════════════
		"CoopMiniGame": "mp_dual_mode",  # Generic fallback
		"MiniGame_Rain": "mp_rain",
		"MiniGame_LeafSort": "mp_leaf_sort",
		"MiniGame_WaterHarvest": "mp_water_harvest",
		"MiniGame_GreywaterSort": "mp_greywater_sort",
		"MiniGame_BucketBrigade": "mp_bucket_brigade"
	}

	# Canonicalised so the scene id ("FixLeak"), the script basename ("MP_WashCar")
	# and the English titles above all reach the same row. Before this, a localized
	# title reached none of them and every game reported "tap_targets" — a real
	# strategy for eight of the games, which is why the fallback looked plausible
	# in the log.
	var want: String = _canon(game_type)
	for k in strategies:
		if _canon(str(k)) == want:
			return str(strategies[k])
	return "tap_targets"  # Default to tap strategy

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-PLAY PROCESS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _process(delta: float) -> void:
	# Elapsed FIRST, ahead of every early return. A frozen auto_play_elapsed used
	# to be the only visible symptom of the driver being stuck, and it froze
	# because the line that updates it sat behind three of them: a 420 s run
	# reported "Played for 25s" and no failures at all.
	if auto_play_enabled and auto_play_start_time > 0:
		auto_play_elapsed = (Time.get_ticks_msec() - auto_play_start_time) / 1000.0
		if auto_play_duration > 0 and auto_play_elapsed >= auto_play_duration:
			var dur_str = _format_duration(auto_play_duration)
			print("🤖 Auto-play duration reached (%s) - Stopping" % dur_str)
			set_auto_play_enabled(false)
			return

	# A paused tree is not a state the bot can play in, and it is a state the bot
	# can put itself into. Injecting input here would be dishonest anyway, so the
	# only action taken while paused is undoing the pause.
	if auto_play_enabled or mp_auto_play_enabled:
		if get_tree().paused:
			_paused_seconds += delta
			_try_resume_from_pause()
			return
		_paused_seconds = 0.0

	# MP auto-play: runs independently of the SP auto_play_enabled flag
	if mp_auto_play_enabled:
		_process_mp_auto_play(delta)
		# Also navigate UI if MP auto-play is on (results screens, lobby, etc.)
		if not current_game or not is_instance_valid(current_game):
			_navigate_ui(delta)

	if not auto_play_enabled:
		return

	# Dismiss StoryScreen overlay if it is showing (it overlays the scene,
	# so scene_file_path stays unchanged — we must handle it here first).
	if _try_advance_story_screen():
		return

	# If no active game, navigate menus autonomously.
	#
	# is_instance_valid() alone is not enough: change_scene_to_file() removes the
	# outgoing minigame from the tree and only memdeletes it at the end of the
	# frame, so for one frame the node is still VALID, still reports game_active
	# true, and gets driven by the strategy dispatch below. Any strategy that
	# touches the viewport then faults — measured as
	#   Condition "!is_inside_tree()" is true. Returning: Rect2()
	#   at get_viewport_rect ... [0] _shell_drag (CatchTheRainV2.gd:320)
	#         [1] _aim_catcher [2] _play_catcher [3] _dispatch_game_strategy
	# on every scene change that lands mid-drag. The reference is dropped so the
	# next scene re-registers cleanly instead of re-entering this branch forever.
	if current_game and is_instance_valid(current_game) \
			and not current_game.is_inside_tree():
		current_game = null
	if not current_game or not is_instance_valid(current_game):
		_navigate_ui(delta)
		return

	# Check if game is active
	var is_active := false
	if "game_active" in current_game:
		is_active = current_game.game_active
	elif "is_playing" in current_game:
		is_active = current_game.is_playing

	if not is_active:
		_navigate_ui(delta)
		return

	# Update cooldowns
	if swipe_cooldown > 0:
		swipe_cooldown -= delta
	if tap_cooldown > 0:
		tap_cooldown -= delta

	# Update action timer
	action_timer += delta

	# Execute game-specific AI strategy
	_dispatch_game_strategy(delta)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PAUSE RECOVERY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Undo a pause the bot did not ask for.
##
## Nothing else can: the pause overlay is dismissed by a human tapping RESUME, and
## an unattended run has no human. Before this, one stray press of the pause glyph
## ended the session — get_tree().paused stopped this autoload's own _process, so
## the code that would have dismissed the overlay was frozen by the thing it was
## meant to clear. The visible result was a soak that quietly stopped playing 25 s
## in and still reported zero failures, which is worse than a crash.
##
## The game's own resume path is preferred so its bookkeeping runs — MiniGameBase
## subtracts the paused span from played-seconds there, and clearing the flag
## behind its back would leave the overlay on screen and the round's duration wrong.
func _try_resume_from_pause() -> bool:
	var g := current_game
	if is_instance_valid(g) and g.has_method("_on_resume_pressed"):
		var overlay = g.get("pause_menu") if "pause_menu" in g else null
		if overlay == null or (is_instance_valid(overlay) and overlay.visible):
			g._on_resume_pressed()
			print("🤖 Auto-play dismissed a pause overlay it did not ask for")
			_paused_seconds = 0.0
			return true

	# Nothing recognisable to dismiss (a pause set by something with no overlay of
	# its own, e.g. an app-focus handler). Waiting it out is the deadlock, so the
	# flag is cleared once the grace period is up — loudly, because a pause the bot
	# cannot explain is itself a finding.
	if _paused_seconds >= PAUSE_GRACE_SECONDS:
		push_warning(
			"AutoPlayManager: tree paused %.1fs with no overlay to dismiss — clearing"
			% _paused_seconds
		)
		get_tree().paused = false
		_paused_seconds = 0.0
		return true
	return false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STORY SCREEN BYPASS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## StoryScreen is added as a CanvasLayer overlay — the scene_file_path
## never changes, so we must detect and advance it every frame ourselves.
## Returns true if a story screen was found and advanced (caller should return early).
func _try_advance_story_screen() -> bool:
	# Find any StoryScreen in the tree
	var story: Node = _find_story_screen_node(get_tree().root)
	if not story:
		return false
	# If it is still animating this page, wait
	if story.get("_is_animating"):
		return true
	# If it is finishing (fade-out), do nothing — just wait
	if story.get("_is_finishing"):
		return true
	# Advance to the next page / finish the story
	if story.has_method("advance_page"):
		print("🤖 AutoPlay: advancing StoryScreen page")
		story.advance_page()
	return true

func _find_story_screen_node(node: Node) -> Node:
	if node.scene_file_path == "res://scenes/ui/StoryScreen.tscn":
		return node
	for child in node.get_children():
		var found := _find_story_screen_node(child)
		if found:
			return found
	return null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTONOMOUS MENU NAVIGATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Called every frame when no game is active.
## Detects the current scene and clicks the appropriate button
## to autonomously navigate from Main Menu → game → results → repeat.
func _navigate_ui(delta: float) -> void:
	nav_timer += delta
	if nav_timer < nav_interval:
		return
	nav_timer = 0.0

	var scene: Node = get_tree().current_scene
	if not scene:
		return

	var path: String = scene.scene_file_path
	print("🤖 AutoNav: current scene = %s" % path)

	# ── Loading screen (auto-proceeds; nothing to click) ─────────
	if "LoadingScreen" in path:
		return

	# ── Main Menu ─────────────────────────────────────────────────
	if "MainMenu" in path:
		var btn: Button = scene.get_node_or_null("UI/VBoxContainer/PlayButton")
		if btn:
			print("🤖 AutoNav: clicking Play on MainMenu")
			btn.pressed.emit()
		return

	# ── Initial / Hub Screen ──────────────────────────────────────
	if "InitialScreen" in path:
		# Dismiss welcome popup if visible
		var popup: Node = scene.get_node_or_null("WelcomePopup")
		if popup and popup.visible:
			var close_btn: Button = popup.get_node_or_null("Panel/CloseButton")
			if close_btn:
				close_btn.pressed.emit()
				return
		# Always click single-player Play (multiplayer requires two devices)
		var play_btn: Button = scene.get_node_or_null("UI/ButtonContainer/PlayButton")
		if play_btn and not play_btn.disabled and play_btn.visible:
			print("🤖 AutoNav: clicking Play on InitialScreen")
			play_btn.pressed.emit()
		return

	# ── MiniGame intro bridge & animated cutscenes (auto-advance; no button needed) ─
	if (
		"MiniGameIntroBridge" in path
		or "MiniGameIntroCutscene" in path
		or "MiniGameOutroCutscene" in path
		or "MiniGameWinOutroCutscene" in path
		or "MiniGameLoseOutroCutscene" in path
		or "CharacterOutcomeNarrative" in path
		or "SimpleCutscenePlayer" in path
	):
		return  # These scenes animate automatically; nothing for AutoPlay to do

	# ── Instructions / Tutorial screens ───────────────────────────
	if "Instructions" in path or "StoryScreen" in path:
		var btn: Button = _find_button_recursive(scene, [
			"BackButton", "ContinueButton", "SkipButton",
			"NextButton", "CloseButton", "StartButton"
		])
		if btn:
			print("🤖 AutoNav: dismissing instruction/story screen")
			btn.pressed.emit()
		return

	# ── Result / Score / Transition screens ───────────────────────
	if (
		"MiniGameResults" in path or "FinalScore" in path
		or "RoundTransition" in path or "PostTest" in path
		or "PostTestResults" in path or "MultiplayerGameOver" in path
	):
		var btn: Button = _find_button_recursive(scene, [
			"ContinueButton", "NextButton", "RetryButton",
			"BackButton", "DoneButton", "HomeButton"
		])
		if btn:
			print("🤖 AutoNav: continuing from result screen")
			btn.pressed.emit()
		return

	# ── Multiplayer Lobby / Menu ───────────────────────────────────
	if "MultiplayerLobby" in path or "MultiplayerMenu" in path:
		# When MP auto-play is active the lobby is human-driven:
		# players connect manually, then the host presses Start (or
		# AutoPlay auto-starts once both are ready). Never navigate
		# away from the lobby or try to re-enter single-player here.
		if mp_auto_play_enabled:
			return

		# If a StartGameButton is present and enabled (2 players connected), start the game
		var start_btn: Button = _find_button_recursive(scene, ["StartGameButton"])
		if start_btn and not start_btn.disabled:
			print("🤖 AutoNav: starting multiplayer game")
			start_btn.pressed.emit()
			return
		# Single-device testing: back out gracefully since we can't host+join simultaneously
		var exit_btn: Button = _find_button_recursive(scene, ["BackButton", "DisconnectButton"])
		if exit_btn:
			print("🤖 AutoNav: exiting multiplayer lobby (no second player available)")
			exit_btn.pressed.emit()
		return

	# ── Character / Roadmap / Unlockables screens ─────────────────
	if (
		"CharacterCustomization" in path or "RoadmapScreen" in path
		or "UnlockablesScreen" in path
	):
		var btn: Button = _find_button_recursive(scene, [
			"BackButton", "CloseButton", "DoneButton"
		])
		if btn:
			print("🤖 AutoNav: backing out of non-game screen")
			btn.pressed.emit()
		return

## Search a node tree for the first enabled button matching any of the given names.
func _find_button_recursive(root: Node, names: Array) -> Button:
	for nm in names:
		var found: Node = root.find_child(nm, true, false)
		if found and found is Button:
			var btn := found as Button
			if not btn.disabled and btn.visible:
				return btn
	return null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STRATEGY IMPLEMENTATIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Dispatch to game-specific AI based on the registered game name.
## Canonical game key -> the method that plays it.
##
## This used to be a `match game_name:` over 66 English display titles. Two things
## made that unverifiable and, in Filipino, inert:
##   * MiniGameBase registers with its DISPLAY TITLE, and FixLeakV2 builds that
##     title from Localization, so "Ayusin ang Tagas" matched no case and the game
##     fell through to _play_generic_tap. Every single-player game reaches this
##     table through the same call, so any title that gets translated later loses
##     its ai silently.
##   * a typo in a `match` case is invisible — the case simply never fires. A
##     dictionary can be swept: tools/VerifyAutoPlayDrive.tscn [3] asserts every
##     roster id has an entry AND that has_method() finds what the entry names.
## Keys are _canon()'d: lower case, no spaces, no underscores, no trailing "V2".
## That accepts all three spellings that reach here — the scene id "FixLeak" from
## MiniGameBase, the script basename "MP_WashCar" from register_multiplayer_game(),
## and the older English titles — without a second table to keep in step.
const HANDLERS: Dictionary = {
	# ── Single-player roster (all 24) ──────────────────────────────
	"timingtap": "_play_timing_tap",
	"turnofftap": "_play_turn_off_tap",
	"spotthespeck": "_play_spot_the_speck",
	"plugtheleak": "_play_plug_the_leak",
	"fixleak": "_play_fix_leak",
	"fixtheleak": "_play_fix_leak",
	"thirstyplant": "_play_thirsty_plant",
	"waterplant": "_play_water_plant",
	"catchtherain": "_play_catcher",
	"bucketbrigade": "_play_bucket_brigade",
	"cloudcatcher": "_play_cloud_catcher",
	"dropletdash": "_play_droplet_dash",
	"coverthedrum": "_play_cover_the_drum",
	"filterbuilder": "_play_filter_builder",
	"swipethesoap": "_play_swipe_soap",
	"wringitout": "_play_wring_it_out",
	"scrubtosave": "_play_scrub_to_save",
	"greywatersorter": "_play_greywater_sorter",
	"ricewashrescue": "_play_rice_wash_rescue",
	"vegetablebath": "_play_vegetable_bath",
	"watermemory": "_play_water_memory",
	"tracepipepath": "_play_trace_pipe_path",
	"quickshower": "_play_quick_shower",
	"toilettankfix": "_play_toilet_tank_fix",
	"mudpiemaker": "_play_mud_pie_maker",
	# ── Two-player bundle games (MP_*.tscn) ────────────────────────
	"mpcatchtherain": "_play_catcher",
	"mpcatchrainaquarium": "_play_catcher",
	"mpcollectdishwater": "_play_mp_drag_collection",
	"mpcollectlaundrywater": "_play_mp_drag_collection",
	"mpcollectshowerwater": "_play_mp_drag_collection",
	"mpwashvegetables": "_play_mp_wash_vegetables",
	"mpwaterplants": "_play_mp_water_plants",
	"mpflushtoilets": "_play_mp_flush_toilets",
	"mpfillaquarium": "_play_mp_fill_aquarium",
	"mpfilterwater": "_play_mp_filter_water",
	"mpmopfloor": "_play_mp_mop_floor",
	"mpwashcar": "_play_mp_wash_car",
	# ── Co-op games (MiniGame_*.tscn) ──────────────────────────────
	"minigamerain": "_play_mp_rain",
	"minigameleafsort": "_play_mp_leaf_sort",
	"minigamewaterharvest": "_play_mp_water_harvest",
	"minigamegreywatersort": "_play_mp_greywater_sort",
	"minigamebucketbrigade": "_play_mp_bucket_brigade",
}


## One spelling for a game, whatever the caller had: the scene id, the script
## basename, or a display title in either language.
func _canon(raw: String) -> String:
	var out: String = raw.strip_edges().to_lower()
	out = out.replace(" ", "").replace("_", "").replace("-", "")
	if out.ends_with("v2"):
		out = out.substr(0, out.length() - 2)
	return out


func _dispatch_game_strategy(delta: float) -> void:
	var handler: String = str(HANDLERS.get(_canon(game_name), ""))
	if handler != "" and has_method(handler):
		call(handler, delta)
		return
	# Unknown game: fall back on the strategy string alone.
	if auto_play_strategy == "drag_catcher":
		_play_catcher(delta)
	elif auto_play_strategy == "click_target":
		_play_mp_click_target(delta)
	elif auto_play_strategy.begins_with("mp_"):
		_play_mp_generic(delta)
	else:
		_play_generic_tap(delta)

# ──────────────────────────────────────────────────────────────────
# MP CLICK_TARGET STRATEGY
# Finds the first visible, interactive node in the game scene and
# simulates a click on it. Used for Distributor-role MP games where
# the player taps aquariums, plants, dirty surfaces, etc.
# ──────────────────────────────────────────────────────────────────
func _play_mp_click_target(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	# Walk the tree looking for a visible, clickable Button or Area2D
	var candidates: Array[Node] = []
	_collect_clickable_nodes(g, candidates)
	if candidates.is_empty():
		tap_cooldown = 0.6
		return
	# Pick the first enabled candidate and simulate input
	var target: Node = candidates[0]
	if target is Button:
		target.emit_signal("pressed")
	elif target is Area2D:
		# Synthesise a click at the center of the area
		var vp: Viewport = get_viewport()
		if vp:
			var pos: Vector2 = (target as Node2D).global_position
			var ev_down := InputEventMouseButton.new()
			ev_down.button_index = MOUSE_BUTTON_LEFT
			ev_down.pressed = true
			ev_down.position = pos
			ev_down.global_position = pos
			vp.push_input(ev_down)
			var ev_up := ev_down.duplicate() as InputEventMouseButton
			ev_up.pressed = false
			vp.push_input(ev_up)
	tap_cooldown = 0.5

func _play_mp_drag_collection(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	var catcher := _get_mp_collection_catcher(g)
	if catcher == null or not is_instance_valid(catcher):
		return
	var target := _get_mp_falling_target(g)
	if target == null or not is_instance_valid(target):
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	catcher.position.x = clampf(target.position.x, 50.0, viewport_width - 50.0)

func _get_mp_collection_catcher(g: Node) -> Node2D:
	var catchers: Array = []
	if "containers" in g:
		catchers = g.containers
	elif "buckets" in g:
		catchers = g.buckets
	if catchers.is_empty():
		return null
	var best: Node2D = null
	var lowest_fill := INF
	for catcher in catchers:
		if not is_instance_valid(catcher):
			continue
		var fill := 0.0
		if catcher.has_meta("current"):
			fill = float(catcher.get_meta("current", 0))
		elif catcher.has_meta("water_level"):
			fill = float(catcher.get_meta("water_level", 0))
		if best == null or fill < lowest_fill:
			best = catcher
			lowest_fill = fill
	return best

func _get_mp_falling_target(g: Node) -> Area2D:
	var best: Area2D = null
	var best_y := -INF
	for child in g.get_children():
		if not child is Area2D:
			continue
		var area := child as Area2D
		if not is_instance_valid(area) or not area.has_meta("velocity"):
			continue
		if area.position.y > best_y:
			best = area
			best_y = area.position.y
	return best

func _play_mp_wash_vegetables(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var sink: Node2D = g.get("sink_area")
	var vegetables: Array = g.get("vegetables") if "vegetables" in g else []
	if sink == null or vegetables.is_empty() or not g.has_method("_check_wash_vegetable"):
		return
	for vegetable in vegetables:
		if not is_instance_valid(vegetable):
			continue
		g.dragging_vegetable = vegetable
		vegetable.position = sink.position
		g.call("_check_wash_vegetable")
		tap_cooldown = 0.15
		return

func _play_mp_water_plants(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_try_water_plant"):
		return
	if int(g.get("available_water")) <= 0:
		return
	for plant in g.get("plants"):
		if not is_instance_valid(plant):
			continue
		if plant.get_meta("watered", false):
			continue
		g.call("_try_water_plant", plant)
		tap_cooldown = 0.12
		return

func _play_mp_flush_toilets(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_try_flush"):
		return
	if int(g.get("available_water")) <= 0:
		return
	for toilet in g.get("toilets"):
		if not is_instance_valid(toilet):
			continue
		if not toilet.get_meta("needs_flush", false):
			continue
		g.call("_try_flush", toilet)
		tap_cooldown = 0.15
		return

func _play_mp_fill_aquarium(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_try_fill"):
		return
	if int(g.get("available_water")) <= 0:
		return
	var aquarium_level := float(g.get("aquarium_level"))
	var aquarium_max := float(g.get("aquarium_max"))
	if aquarium_level >= aquarium_max:
		return
	g.call("_try_fill")
	tap_cooldown = 0.15

func _play_mp_filter_water(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_filter_particle"):
		return
	for particle in g.get("dirt_particles"):
		if not is_instance_valid(particle):
			continue
		g.call("_filter_particle", particle)
		tap_cooldown = 0.08
		return

func _play_mp_mop_floor(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_try_mop"):
		return
	if int(g.get("available_water")) <= 0:
		return
	for tile in g.get("floor_tiles"):
		if not is_instance_valid(tile):
			continue
		if not tile.get_meta("dirty", false):
			continue
		g.call("_try_mop", tile)
		tap_cooldown = 0.15
		return

func _play_mp_wash_car(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_try_wash"):
		return
	if int(g.get("available_water")) <= 0:
		return
	for section in g.get("car_sections"):
		if not is_instance_valid(section):
			continue
		if not section.get_meta("dirty", false):
			continue
		g.call("_try_wash", section)
		tap_cooldown = 0.15
		return

func _collect_clickable_nodes(node: Node, out: Array[Node]) -> void:
	if out.size() >= 5:
		return
	# Skip HUD / overlay elements
	if node.name in ["ClickCatcher", "PauseButton", "ResumeButton", "QuitButton"]:
		return
	if node is CanvasLayer:
		return  # Don't recurse into HUD layers
	if node is Button:
		var btn := node as Button
		# is_visible_in_tree(), not visible: a control inside a hidden panel still
		# reports visible == true, and emitting `pressed` on it works, so the same
		# read used to hand the bot buttons the player could not see.
		if btn.is_visible_in_tree() and not btn.disabled and not _is_shell_button(btn):
			out.append(btn)
			return
	if node is Area2D:
		var a := node as Area2D
		# Skip bucket/catcher nodes — only collect tappable targets
		if a.is_visible_in_tree() and a.has_meta("type"):
			out.append(a)
	for child in node.get_children():
		_collect_clickable_nodes(child, out)

# ──────────────────────────────────────────────────────────────────
# FIX LEAK
# Iterate leaks[]; call _on_leak_clicked() on each unfixed leak.
# ──────────────────────────────────────────────────────────────────
func _play_fix_leak(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_on_leak_clicked"):
		return
	var leaks: Array = g.get("leaks") if "leaks" in g else []
	for leak in leaks:
		if not is_instance_valid(leak):
			continue
		if leak.get_meta("fixed", false):
			continue
		g.call("_on_leak_clicked", leak)
		tap_cooldown = 0.25
		return

# ──────────────────────────────────────────────────────────────────
# CLOUD CATCHER
# Tap the untapped cloud best aligned with a plant that still needs water.
# ──────────────────────────────────────────────────────────────────
## Autoplay taps the cloud best ALIGNED with a plant that still needs water, not simply the
## first untapped cloud in the array. The old loop ignored the plants entirely, and in this game
## alignment is the whole skill: a tap releases five drops in a 60-unit band around the cloud
## while the plants sit 213 units apart on Hard, so an unaimed tap waters a plant only by luck.
## Measured before the change with tools/VerifyCloudCatcherClearable.tscn's aiming bot as the
## reference - autoplay could not clear CloudCatcher at any difficulty, which matters because
## AutoPlayManager is what the demo/attract path and the unattended test runs play through.
##
## AIM_TOL is the horizontal error that still lands rain: drops spawn within +/-30 of the cloud
## and a plant tests at a 50-unit radius, so 40 keeps most of the five drops inside the plant.
const CLOUD_AIM_TOL: float = 40.0

func _play_cloud_catcher(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_on_cloud_tapped"):
		return
	var clouds: Array = g.get("clouds") if "clouds" in g else []
	var plants: Array = g.get("plants") if "plants" in g else []
	if clouds.is_empty() or plants.is_empty():
		return
	# Rain already on its way, so a cloud is not spent on a plant the last tap has covered.
	var falling: Array = []
	for child in g.get_children():
		if child is Label and child.has_meta("is_rain"):
			falling.append(child)
	var best_cloud: Node = null
	var best_err: float = CLOUD_AIM_TOL
	for plant in plants:
		if not is_instance_valid(plant) or plant.get_meta("watered", false):
			continue
		var have: float = float(plant.get_meta("water_amount", 0.0))
		var target: float = float(plant.get_meta("target_water", 1.0))
		# FIX 93 - each drop that lands adds half the target, so two drops finish a plant, and that
		# what this expression already yields. The "* 2" it used to carry double-booked the plant:
		# autoplay kept aiming clouds at a plant with two drops inbound and only moved on at four,
		# spending clouds the rest of the quota needed. committed below counts only drops already
		# within 50 units in x, and a drop's x is fixed at spawn, so a committed drop lands.
		var need: int = int(ceil((target - have) / (target * 0.5)))
		var committed: int = 0
		for drop in falling:
			if absf(drop.position.x - plant.position.x) <= 50.0 \
				and drop.position.y < plant.position.y:
				committed += 1
		if committed >= need:
			continue
		for cloud in clouds:
			if not is_instance_valid(cloud) or cloud.get_meta("tapped", false):
				continue
			var err: float = absf(cloud.position.x - plant.position.x)
			if err < best_err:
				best_err = err
				best_cloud = cloud
	if best_cloud == null:
		# Nothing is lined up this frame. Waiting is the correct move: the clouds drift, and a
		# tap now would consume one over empty ground.
		return
	g.call("_on_cloud_tapped", best_cloud)
	tap_cooldown = 0.3

# ──────────────────────────────────────────────────────────────────
# COVER THE DRUM
# Find first uncovered drum in drums[]; call _cover_drum().
# Re-covers drums as they uncover over time (4s timer).
# ──────────────────────────────────────────────────────────────────
func _play_cover_the_drum(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_cover_drum"):
		return
	var drums: Array = g.get("drums") if "drums" in g else []
	for drum in drums:
		if not is_instance_valid(drum):
			continue
		if not drum.get_meta("covered", false):
			g.call("_cover_drum", drum)
			tap_cooldown = 0.2
			return

# ──────────────────────────────────────────────────────────────────
# QUICK SHOWER
# Wait for gauge_position to enter [target_zone_start, target_zone_end],
# then call _check_timing() for a perfect tap.
# ──────────────────────────────────────────────────────────────────
func _play_quick_shower(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.get("shower_running"):
		return
	if not g.has_method("_check_timing"):
		return
	var gauge: float = float(g.get("gauge_position")) if "gauge_position" in g else -1.0
	var z_start: float = float(g.get("target_zone_start")) if "target_zone_start" in g else 0.0
	var z_end: float = float(g.get("target_zone_end")) if "target_zone_end" in g else 100.0
	if gauge >= z_start and gauge <= z_end:
		g.call("_check_timing")
		tap_cooldown = 1.2

# ──────────────────────────────────────────────────────────────────
# SCRUB TO SAVE
# Zero out dirt_level on current_dish and call _dish_cleaned().
# ──────────────────────────────────────────────────────────────────
func _play_scrub_to_save(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var dish: Node2D = g.get("current_dish")
	if dish == null or not is_instance_valid(dish):
		return
	if not g.has_method("_dish_cleaned"):
		return
	g.set("dirt_level", 0.0)
	g.call("_dish_cleaned")
	tap_cooldown = 1.5

# ──────────────────────────────────────────────────────────────────
# THIRSTY PLANT
# Wait for can_click (after shuffle phase); then call
# _on_bucket_pressed() on the bucket with is_correct meta.
# ──────────────────────────────────────────────────────────────────
func _play_thirsty_plant(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.get("can_click"):
		return
	if not g.has_method("_on_bucket_pressed"):
		return
	var buckets: Array = g.get("buckets") if "buckets" in g else []
	for bucket in buckets:
		if not is_instance_valid(bucket):
			continue
		if bucket.get_meta("is_correct", false):
			g.call("_on_bucket_pressed", bucket)
			tap_cooldown = 1.0
			return

# ──────────────────────────────────────────────────────────────────
# TOILET TANK FIX
# Snap water_level to target_level and call _check_level() to record
# a successful fill without waiting for real mouse-hold input.
# ──────────────────────────────────────────────────────────────────
func _play_toilet_tank_fix(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not "water_level" in g or not "target_level" in g:
		return
	var water_level: float = float(g.get("water_level"))
	var target: float = float(g.get("target_level"))
	var tol: float = float(g.get("tolerance")) if "tolerance" in g else 10.0
	if water_level < target - tol:
		g.set("water_level", target)
		if g.has_method("_check_level"):
			g.call("_check_level")
		tap_cooldown = 1.2

# ──────────────────────────────────────────────────────────────────
# MUD PIE MAKER
# Directly drive the pouring flag to keep water_level in the green
# zone [target_min, target_max] throughout the survival timer.
# ──────────────────────────────────────────────────────────────────
func _play_mud_pie_maker(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	if not "water_level" in g or not "pouring" in g:
		return
	var water_level: float = float(g.get("water_level"))
	var t_min: float = float(g.get("target_min")) if "target_min" in g else 35.0
	var t_max: float = float(g.get("target_max")) if "target_max" in g else 65.0
	var mid: float = (t_min + t_max) / 2.0
	if water_level < mid - 2.0:
		g.set("pouring", true)
	elif water_level >= t_min and water_level <= t_max:
		g.set("pouring", false)

# ──────────────────────────────────────────────────────────────────
# SWIPE THE SOAP
# Read the required direction from current_soap meta, then call
# _correct_swipe() directly — always wins every soap.
# ──────────────────────────────────────────────────────────────────
func _play_swipe_soap(_delta: float) -> void:
	if swipe_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var soap: Node2D = g.get("current_soap")
	if soap == null or not is_instance_valid(soap):
		return
	if g.has_method("_correct_swipe"):
		g.call("_correct_swipe")
	swipe_cooldown = 0.7

# ──────────────────────────────────────────────────────────────────
# WRING IT OUT
# Set tap_requested = true every frame; the game's _process() will
# consume it and call _on_tap() with its built-in 0.08s throttle.
# ──────────────────────────────────────────────────────────────────
func _play_wring_it_out(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	if "tap_requested" in g:
		g.tap_requested = true

# ──────────────────────────────────────────────────────────────────
# CATCH THE RAIN / BUCKET BRIGADE / CLOUD CATCHER / COVER THE DRUM
# Steer the catcher toward the nearest good (blue) falling drop.
# Legacy catchers lerp drum_node.position.x to the OS cursor in _process, so
# warping the mouse is enough for them. See _aim_catcher for why the v2 shell
# games need more than that.
# ──────────────────────────────────────────────────────────────────
func _play_catcher(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	var catcher: Node2D = g.get("drum_node")
	if catcher == null:
		catcher = g.get("bucket_node")
	if catcher == null:
		catcher = g.get("bucket")
	if catcher == null or not is_instance_valid(catcher):
		return
	var drops = g.get("drops")
	if drops == null or not drops is Array or drops.is_empty():
		drops = []
		var container: Node = g.get_node_or_null("GameLayer/ObjectsContainer")
		var search_root: Node = container if container != null else g
		for child in search_root.get_children():
			if not is_instance_valid(child):
				continue
			var is_drop := false
			if child.has_meta("type") and str(child.get_meta("type")) == "raindrop":
				is_drop = true
			if child.name.begins_with("Drop_") or child.name == "WaterDrop":
				is_drop = true
			if child is MPMovingObject:
				if child.object_type == MPMovingObject.ObjectType.WATER_DROP:
					is_drop = true
			if is_drop:
				drops.append(child)
	if drops.is_empty():
		_aim_catcher(g, catcher, catcher.position.x)
		return
	var screen_size := get_viewport().get_visible_rect().size
	var best_x: float = catcher.position.x
	var best_score: float = -INF
	# Find nearest good (blue) drop to chase.
	# `visible` is the liveness test, not an aesthetic one: the v2 games hand out
	# drops from a fixed EntityPool, and a released drop keeps the position it died
	# at — just off the bottom edge. That is the LARGEST y in the array, so it wins
	# the score below and the AI parks the drum under a drop that no longer exists.
	# Legacy catchers queue_free()d theirs, so the array only ever held live nodes.
	for drop in drops:
		if not is_instance_valid(drop):
			continue
		if not drop.visible:
			continue
		if drop is MPMovingObject and drop.is_special:
			continue
		if not drop.get_meta("good", true):
			continue
		var score: float = drop.position.y - absf(drop.position.x - catcher.position.x) * 0.3
		if score > best_score:
			best_score = score
			best_x = drop.position.x
	# Dodge any bad (red) drops near our target position — but only ones close
	# enough to the paddle to actually threaten this catch. The old test was
	# `position.y > 100.0`, written when the playfield was a small window; on a
	# 1920-tall portrait viewport the paddle sits near y=1790, so y>100 means
	# "anywhere below the top 5%" and EVERY red drop on screen counted, including
	# ones still 1500 px up that will not arrive for over a second. Each match
	# shoves best_x by 130 px — nearly twice DRUM_HALF_WIDTH — so the driver
	# repeatedly abandoned a good drop it was already lined up on to dodge a threat
	# that was not there yet.
	var threat_reach: float = catcher.position.y - screen_size.y * 0.18
	for drop in drops:
		if not is_instance_valid(drop):
			continue
		if not drop.visible:
			continue
		if drop is MPMovingObject and drop.is_special:
			continue
		if drop.get_meta("good", true):
			continue
		if drop.position.y < threat_reach:
			continue
		if absf(drop.position.x - best_x) < 80.0:
			best_x += 130.0 * signf(catcher.position.x - drop.position.x)
			best_x = clampf(best_x, 70.0, screen_size.x - 70.0)
	_aim_catcher(g, catcher, best_x)


## Point a catcher paddle at `x`.
##
## Warping the cursor steers a legacy catcher because its _process() lerps toward
## the mouse every frame. The v2 MicrogameShell does not poll: input arrives as
## events on the shell's Control, and the mouse-motion arm is gated behind
## `Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)` — a button this driver never
## holds. So a warp alone moved nothing, and the shell drum sat dead-centre for the
## whole round while the log still reported a played game. Call the handler
## directly instead, exactly as the other drivers here call _sort_bucket(),
## _on_leak_clicked() and _handle_tap().
##
## The position is passed in ALREADY MAPPED — _on_shell_gui_input is where
## _shell_map_drag applies — so control_reverse does not steer the AI into the
## wrong half. That matches every other driver in this file: they reach past the
## input layer, so no chaos effect handicaps them.
func _aim_catcher(g: Node, catcher: Node2D, x: float) -> void:
	var aim := Vector2(x, catcher.position.y)
	Input.warp_mouse(aim)
	if g.has_method("_shell_drag"):
		g.call("_shell_drag", aim)

# ──────────────────────────────────────────────────────────────────
# WATER MEMORY
# Omniscient strategy: read emoji from card meta to always pair
# correctly. Calls _on_card_pressed() directly.
# ──────────────────────────────────────────────────────────────────
func _play_water_memory(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.get("can_flip"):
		return
	if not g.has_method("_on_card_pressed"):
		return
	var cards: Array = g.get("cards")
	if cards == null or cards.is_empty():
		return
	var first_card: Node = g.get("first_card")
	if first_card == null:
		# Find a card that has at least one unmatched duplicate emoji
		for card in cards:
			if not is_instance_valid(card) or card.get_meta("matched", false):
				continue
			var my_emoji: String = card.get_meta("emoji", "")
			for other in cards:
				if not is_instance_valid(other) or other == card:
					continue
				if other.get_meta("matched", false):
					continue
				if other.get_meta("emoji", "") == my_emoji:
					g.call("_on_card_pressed", card)
					tap_cooldown = 0.5
					return
	else:
		# A card is already face-up — find its matching partner
		var target_emoji: String = first_card.get_meta("emoji", "")
		for card in cards:
			if not is_instance_valid(card) or card == first_card:
				continue
			if card.get_meta("matched", false):
				continue
			if card.get_meta("emoji", "") == target_emoji:
				g.call("_on_card_pressed", card)
				tap_cooldown = 0.5
				return

# ──────────────────────────────────────────────────────────────────
# TRACE PIPE PATH
# Directly populate path_points with densely sampled target_path data,
# then call _check_path() for an instant perfect trace.
# ──────────────────────────────────────────────────────────────────
func _play_trace_pipe_path(_delta: float) -> void:
	if swipe_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_check_path"):
		return
	var target_path: Array = g.get("target_path")
	if target_path == null or target_path.size() < 2:
		return
	var path_points: Array = g.get("path_points")
	if path_points == null:
		return
	path_points.clear()
	var canvas: Node = g.get_node_or_null("Canvas")
	var draw_line: Node = null
	if canvas:
		draw_line = canvas.get_node_or_null("DrawLine")
		if draw_line and draw_line.has_method("clear_points"):
			draw_line.clear_points()
	# Fill path_points with 20 interpolated points per segment
	for i in range(target_path.size() - 1):
		var p1: Vector2 = target_path[i]
		var p2: Vector2 = target_path[i + 1]
		for t in range(20):
			var pt: Vector2 = p1.lerp(p2, t / 20.0)
			path_points.append(pt)
			if draw_line and draw_line.has_method("add_point"):
				draw_line.add_point(pt)
	path_points.append(target_path[-1])
	g.set("is_drawing", false)
	g.call("_check_path")
	swipe_cooldown = 1.8  # Allow time for success animation + new path generation

# ──────────────────────────────────────────────────────────────────
# GREYWATER SORTER
# Read each bucket's "safe" meta (true = garden, false = drain),
# then call _sort_bucket() directly with the correct destination.
# ──────────────────────────────────────────────────────────────────
func _play_greywater_sorter(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_sort_bucket"):
		return
	var buckets: Array = g.get("buckets") if "buckets" in g else []
	if buckets == null or buckets.is_empty():
		return
	var current_bucket: Node = g.get("current_bucket")
	for bucket in buckets:
		if not is_instance_valid(bucket):
			continue
		if bucket == current_bucket:
			continue
		if bucket.get_meta("being_sorted", false):
			continue
		var is_safe: bool = bucket.get_meta("safe", true)
		bucket.set_meta("being_sorted", true)
		g.set("current_bucket", bucket)
		g.call("_sort_bucket", bucket, is_safe)
		g.set("current_bucket", null)
		g.set("is_swiping", false)
		tap_cooldown = 0.4
		return

# ──────────────────────────────────────────────────────────────────
# FILTER BUILDER
# Place each unplaced layer into its correct zone:
#   cloth=0, charcoal=1, sand=2, gravel=3
# Calls _check_filter() when all 4 layers are placed.
# ──────────────────────────────────────────────────────────────────
func _play_filter_builder(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var filter_layers: Array = g.get("filter_layers")
	if filter_layers == null:
		return
	var correct_order: Array = g.get("correct_order")
	if correct_order == null or correct_order.is_empty():
		correct_order = ["cloth", "charcoal", "sand", "gravel"]
	var bottle: Node = g.get_node_or_null("Bottle")
	if bottle == null:
		return
	for layer in filter_layers:
		if not is_instance_valid(layer):
			continue
		if layer.get_meta("placed", false):
			continue
		var ltype: String = layer.get_meta("type", "")
		var zone_idx: int = correct_order.find(ltype)
		if zone_idx < 0:
			continue
		var zone: Node = bottle.get_node_or_null("Zone_%d" % zone_idx)
		if zone == null or zone.get_meta("filled", false):
			continue
		# Snap layer to zone center
		layer.position = bottle.position + zone.position + Vector2(70.0, 30.0)
		layer.set_meta("placed", true)
		layer.set_meta("zone_index", zone_idx)
		zone.set_meta("filled", true)
		var placed: Array = g.get("placed_layers")
		if placed != null:
			placed.append({"type": ltype, "index": zone_idx})
			if placed.size() >= 4 and g.has_method("_check_filter"):
				g.call("_check_filter")
		tap_cooldown = 0.5
		return

# ──────────────────────────────────────────────────────────────────
# TIMING TAP / QUICK SHOWER
# Use _touch_holding to control fill level. Fill until just inside
# the target window, then release.
# ──────────────────────────────────────────────────────────────────
func _play_timing_tap(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	if not "container_fill" in g or not "target_fill" in g:
		return
	var fill: float = float(g.get("container_fill"))
	var target: float = float(g.get("target_fill"))
	var tolerance: float = float(g.get("fill_tolerance")) if "fill_tolerance" in g else 10.0
	# Hold until we reach just inside the lower edge of the tolerance window
	if fill < (target - tolerance + 1.0):
		g.set("_touch_holding", true)
	else:
		g.set("_touch_holding", false)

# ──────────────────────────────────────────────────────────────────
# TURN OFF TAP
# Iterate active_taps; call _on_tap_closed() on each running tap.
# ──────────────────────────────────────────────────────────────────
func _play_turn_off_tap(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_on_tap_closed"):
		return
	var active_taps: Array = g.get("active_taps")
	if active_taps == null:
		return
	for tap in active_taps:
		if not is_instance_valid(tap):
			continue
		if tap.get_meta("running", false):
			g.call("_on_tap_closed", tap)
			tap_cooldown = 0.12
			return

# ──────────────────────────────────────────────────────────────────
# PLUG THE LEAK / FIX LEAK
# Directly advance plug_progress each frame for leaking pipes.
# Calls _start_random_leak() after each fix to keep the game going.
# ──────────────────────────────────────────────────────────────────
func _play_plug_the_leak(delta: float) -> void:
	# Handle ALL leaking pipes per frame so water_wasted cannot accumulate
	# on unattended pipes while another is being plugged.
	var g := current_game
	if not is_instance_valid(g):
		return
	var pipes: Array = g.get("pipes")
	if pipes == null:
		return
	var plug_rate: float = float(g.get("plug_rate")) if "plug_rate" in g else 15.0
	var any_leaking := false
	for pipe in pipes:
		if not is_instance_valid(pipe):
			continue
		if not pipe.get_meta("leaking", false):
			continue
		any_leaking = true
		var progress: float = pipe.get_meta("plug_progress", 0.0) + plug_rate * delta * 3.0
		progress = minf(progress, 100.0)
		pipe.set_meta("plug_progress", progress)
		var plug_bar: Node = pipe.get_node_or_null("PlugBar")
		if plug_bar:
			if "value" in plug_bar:
				plug_bar.value = progress
			plug_bar.visible = true
		if progress >= 100.0:
			pipe.set_meta("leaking", false)
			pipe.set_meta("plug_progress", 0.0)
			var leak_node: Node = pipe.get_node_or_null("Leak")
			if leak_node:
				leak_node.visible = false
			if plug_bar:
				plug_bar.visible = false
			var joint: Node = pipe.get_node_or_null("Joint")
			if joint and "color" in joint:
				joint.color = Color(0.3, 0.7, 0.3)
			if g.has_method("record_action"):
				g.record_action(true)
			# Reduce water_wasted as reward for quick fix
			if "water_wasted" in g:
				g.set("water_wasted", maxf(float(g.get("water_wasted")) - 12.0, 0.0))
			if g.has_method("_start_random_leak"):
				g.call("_start_random_leak")
	if not any_leaking and pipes.size() > 0:
		var first_pipe = pipes[0]
		if is_instance_valid(first_pipe):
			Input.warp_mouse(first_pipe.position)

# ──────────────────────────────────────────────────────────────────
# BUCKET BRIGADE
# Read people[] and bucket_at_person[]; call _handle_tap() on any
# person currently holding a bucket to pass it along the chain.
# ──────────────────────────────────────────────────────────────────
func _play_bucket_brigade(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_handle_tap"):
		return
	var people: Array = g.get("people") if "people" in g else []
	var bucket_at: Array = g.get("bucket_at_person") if "bucket_at_person" in g else []
	for i in range(mini(people.size(), bucket_at.size())):
		if bucket_at[i] != null and is_instance_valid(bucket_at[i]):
			var person: Node2D = people[i]
			if is_instance_valid(person):
				g.call("_handle_tap", person.position)
				tap_cooldown = 0.35
				return

# ──────────────────────────────────────────────────────────────────
# RICE WASH RESCUE
# The basin follows the mouse X position. Warp mouse X to the pot's
# X position each frame so the basin tracks the moving pot perfectly.
# ──────────────────────────────────────────────────────────────────
func _play_rice_wash_rescue(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	var pot: Node2D = g.get("pot_node")
	if pot == null or not is_instance_valid(pot):
		return
	var mouse_y: float = get_viewport().get_mouse_position().y
	Input.warp_mouse(Vector2(pot.position.x, mouse_y))

# ──────────────────────────────────────────────────────────────────
# VEGETABLE BATH
# Two-step pipeline per veggie: move to wash_bowl → call
# _check_placement, then move to clean_basket → call _check_placement.
# ──────────────────────────────────────────────────────────────────
func _play_vegetable_bath(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_check_placement"):
		return
	var veggies: Array = g.get("veggies") if "veggies" in g else []
	var wash_bowl: Node2D = g.get("wash_bowl")
	var clean_basket: Node2D = g.get("clean_basket")
	if wash_bowl == null or clean_basket == null:
		return
	# Step 1: wash any unwashed veggie
	for veggie in veggies:
		if not is_instance_valid(veggie):
			continue
		if veggie.get_meta("done", false):
			continue
		if not veggie.get_meta("washed", false):
			veggie.position = wash_bowl.position
			g.call("_check_placement", veggie)
			tap_cooldown = 0.4
			return
	# Step 2: deliver washed veggies to clean basket
	for veggie in veggies:
		if not is_instance_valid(veggie):
			continue
		if veggie.get_meta("done", false):
			continue
		if veggie.get_meta("washed", false):
			veggie.position = clean_basket.position
			g.call("_check_placement", veggie)
			tap_cooldown = 0.4
			return

# ──────────────────────────────────────────────────────────────────
# SPOT THE SPECK
# Read current_glass dirty meta; call _judge_glass() with the correct
# answer to always identify glasses accurately.
# ──────────────────────────────────────────────────────────────────
func _play_spot_the_speck(_delta: float) -> void:
	if swipe_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_judge_glass"):
		return
	var glass: Node = g.get("current_glass")
	if glass == null or not is_instance_valid(glass):
		return
	var is_dirty: bool = glass.get_meta("dirty", false)
	g.call("_judge_glass", is_dirty)
	swipe_cooldown = 0.7

# ──────────────────────────────────────────────────────────────────
# WATER PLANT / THIRSTY PLANT
# Monitor plants[] hydration; call _on_plant_tapped(i) for the
# driest plant before it wilts.
# ──────────────────────────────────────────────────────────────────
func _play_water_plant(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_on_plant_tapped"):
		return
	var plants: Array = g.get("plants")
	if plants == null:
		return
	var driest_idx: int = -1
	var driest_hydration: float = INF
	for i in range(plants.size()):
		var plant = plants[i]
		if not plant is Dictionary:
			continue
		var h: float = float(plant.get("hydration", 1.0))
		if h < driest_hydration:
			driest_hydration = h
			driest_idx = i
	if driest_idx >= 0 and driest_hydration < 0.45:
		g.call("_on_plant_tapped", driest_idx)
		tap_cooldown = 0.25

# ──────────────────────────────────────────────────────────────────
# DROPLET DASH
# Score each lane by obstacle density; call _move_lane() to switch
# into the safest available lane.
# ──────────────────────────────────────────────────────────────────
func _play_droplet_dash(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_move_lane"):
		return
	var current_lane: int = int(g.get("current_lane")) if "current_lane" in g else 1
	var lane_count: int = int(g.get("lane_count")) if "lane_count" in g else 3
	var lane_width: float = float(g.get("lane_width")) if "lane_width" in g else 200.0
	var droplet: Node2D = g.get("droplet")
	if droplet == null or not is_instance_valid(droplet):
		return
	var obstacles: Array = g.get("obstacles")
	# Score each lane (higher = safer, fewer obstacles ahead)
	var lane_scores: Array = []
	for lane_index in range(lane_count):
		lane_scores.append(0.0)
	if obstacles != null:
		for obs in obstacles:
			if not is_instance_valid(obs):
				continue
			if obs.position.y > droplet.position.y + 30.0:
				continue
			var obs_lane: int = clamp(int(obs.position.x / lane_width), 0, lane_count - 1)
			for offset in [-1, 0, 1]:
				var affected: int = clamp(obs_lane + offset, 0, lane_count - 1)
				lane_scores[affected] -= 1.0 / float(absi(offset) + 1)
	# Find the best lane
	var best_lane: int = current_lane
	var best_score: float = lane_scores[current_lane]
	for i in range(lane_count):
		if lane_scores[i] > best_score:
			best_score = lane_scores[i]
			best_lane = i
	if best_lane != current_lane:
		g.call("_move_lane", sign(best_lane - current_lane))
		tap_cooldown = 0.18

# ──────────────────────────────────────────────────────────────────
# GENERIC TAP FALLBACK
# Find all visible, non-disabled game buttons; emit pressed on the
# best candidate. Skips common UI navigation buttons by name.
# ──────────────────────────────────────────────────────────────────
## Press one of the game's OWN buttons at random. Only reached for a game with no
## authored strategy — every roster entry has one (see HANDLERS).
func _play_generic_tap(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var game_btns := _collect_all_buttons(g)
	# No gameplay button to press is a legitimate answer: this game is driven by
	# drags or Area2D taps. Pressing whatever else is on screen instead is how the
	# bot used to press its own PAUSE and QUIT GAME.
	if game_btns.is_empty():
		return
	var chosen: Button = game_btns[randi() % game_btns.size()]
	chosen.pressed.emit()
	tap_cooldown = 0.3


## Words a player reads on a control that ENDS or SUSPENDS the round. Matched
## against the button's text, not only its name, because MiniGameBase builds its
## HUD and its pause overlay with Button.new() and never names any of it.
const SHELL_BUTTON_WORDS: Array[String] = [
	"back", "close", "skip", "menu", "pause", "undo", "home", "exit",
	"quit", "resume", "restart", "retry", "settings",
]
## The pause glyph carries no word at all — MiniGameBase draws it as "II".
const SHELL_BUTTON_GLYPHS: Array[String] = ["ii", "❚❚", "✕", "×"]


## Buttons the bot may legitimately press: on screen for real, enabled, part of
## the game rather than its shell.
##
## Three separate holes let the bot press its own way out of every round, measured
## across all 24 roster games by tools/VerifyAutoPlayDrive.tscn: the pause glyph
## was pressed in 24 of 24 and the hidden "✕ QUIT GAME" in 13 of 24.
##   * `visible` is true for a button inside a HIDDEN parent, so the whole pause
##     overlay (RESUME / QUIT GAME) and the tally screen were collected while
##     invisible. is_visible_in_tree() is the question that was meant.
##   * the skip list matched on `name`, but every one of these buttons is a bare
##     Button.new() whose name is "@Button@7", so no word in the list could match.
##     The TEXT is what a player sees, so it is what the filter reads.
##   * MiniGameBase's own pause_button_ref / pause_menu are exact answers where a
##     word list is a guess, so the subtree is excluded by reference as well.
## Pressing pause froze the tree, and the driver's _process froze with it, so
## nothing could ever resume — see _try_resume_from_pause().
func _collect_all_buttons(node: Node) -> Array:
	var out: Array = []
	_gather_playable_buttons(node, out, _shell_subtrees_of(current_game))
	return out


## Nodes whose entire subtree is shell, taken from the game itself.
func _shell_subtrees_of(g: Node) -> Array:
	var refs: Array = []
	if not is_instance_valid(g):
		return refs
	for prop in ["pause_menu", "pause_button_ref", "pause_button"]:
		if prop in g:
			var n = g.get(prop)
			if n is Node and is_instance_valid(n):
				refs.append(n)
	return refs


func _gather_playable_buttons(node: Node, out: Array, shell: Array) -> void:
	if node in shell:
		return
	if node is Button:
		var btn := node as Button
		if btn.is_visible_in_tree() and not btn.disabled and not _is_shell_button(btn):
			out.append(btn)
	for child in node.get_children():
		_gather_playable_buttons(child, out, shell)


func _is_shell_button(btn: Button) -> bool:
	var t: String = btn.text.strip_edges().to_lower()
	if t in SHELL_BUTTON_GLYPHS:
		return true
	var n: String = btn.name.to_lower()
	for w in SHELL_BUTTON_WORDS:
		if w in t or w in n:
			return true
	return false


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER MAIN GAMES (MiniGame_Rain, MiniGame_LeafSort, etc.)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _play_mp_rain(_delta: float) -> void:
	## MiniGame_Rain: Mode 1 = drag bucket, Mode 2 = click leaves
	var g := current_game
	if not is_instance_valid(g):
		return
	
	# Check player mode
	var my_mode = g.get("my_mode")
	if my_mode == null:
		return
	
	# Mode 1 (Collector): Move bucket to catch water drops
	if my_mode == 0:  # MODE_1_COLLECTOR
		_play_mp_rain_collector(g)
	# Mode 2 (Filter): Click on leaves
	else:  # MODE_2_FILTER
		_play_mp_rain_filter(g)

func _play_mp_rain_collector(g: Node) -> void:
	## Move bucket under falling water drops
	var bucket = g.get_node_or_null("GameLayer/Bucket")
	if not bucket:
		return
	
	# Find closest water drop
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	var closest_drop: Node2D = null
	var closest_dist: float = INF
	
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		var is_drop := false
		if child.name.begins_with("Drop_") or child.name == "WaterDrop":
			is_drop = true
		if child.has_meta("type") and str(child.get_meta("type")) == "raindrop":
			is_drop = true
		if child is MPMovingObject:
			if child.object_type == MPMovingObject.ObjectType.WATER_DROP:
				is_drop = true
			if child.is_special:
				is_drop = false
		if not is_drop:
			continue
		var dist = child.global_position.distance_to(bucket.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_drop = child
	
	# Move bucket toward closest drop
	if closest_drop:
		var target_x = closest_drop.global_position.x
		bucket.global_position.x = move_toward(bucket.global_position.x, target_x, 500.0 * get_process_delta_time())

func _play_mp_rain_filter(g: Node) -> void:
	## Click on leaves to remove them
	if tap_cooldown > 0.0:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	# Find clickable leaves
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.name.begins_with("Leaf") or child.name.begins_with("Dirt"):
			# Simulate click
			_simulate_click_on_node(child)
			tap_cooldown = 0.3
			return

func _play_mp_leaf_sort(_delta: float) -> void:
	## MiniGame_LeafSort: P1 = drag bucket, P2 = click leaves
	var g := current_game
	if not is_instance_valid(g):
		return
	
	var is_player_one = g.get("is_player_one")
	if is_player_one == null:
		return
	
	if is_player_one:
		# Player 1: Move bucket to catch clean leaves
		_play_mp_leaf_sort_p1(g)
	else:
		# Player 2: Click dirty leaves
		_play_mp_leaf_sort_p2(g)

func _play_mp_leaf_sort_p1(g: Node) -> void:
	## Move bucket under falling clean leaves
	var bucket = g.get_node_or_null("GameLayer/Bucket")
	if not bucket:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	var closest_leaf: Node2D = null
	var closest_dist: float = INF
	
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.name.begins_with("CleanLeaf"):
			var dist = child.global_position.distance_to(bucket.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_leaf = child
	
	if closest_leaf:
		var target_x = closest_leaf.global_position.x
		bucket.global_position.x = move_toward(bucket.global_position.x, target_x, 500.0 * get_process_delta_time())

func _play_mp_leaf_sort_p2(g: Node) -> void:
	## Click dirty leaves
	if tap_cooldown > 0.0:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.name.begins_with("DirtyLeaf"):
			_simulate_click_on_node(child)
			tap_cooldown = 0.3
			return

func _play_mp_water_harvest(_delta: float) -> void:
	## MiniGame_WaterHarvest: Mode 1 = drag bucket, Mode 2 = click dirt
	var g := current_game
	if not is_instance_valid(g):
		return
	
	var my_mode = g.get("my_mode")
	if my_mode == null:
		return
	
	if my_mode == 0:  # MODE_1_COLLECTOR
		_play_mp_rain_collector(g)  # Same as rain collector
	else:  # MODE_2_FILTER
		_play_mp_water_harvest_filter(g)

func _play_mp_water_harvest_filter(g: Node) -> void:
	## Click dirt particles
	if tap_cooldown > 0.0:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.name.begins_with("Dirt"):
			_simulate_click_on_node(child)
			tap_cooldown = 0.3
			return

func _play_mp_greywater_sort(_delta: float) -> void:
	## MiniGame_GreywaterSort: Mode 1 = drag water to tank, Mode 2 = click filters
	var g := current_game
	if not is_instance_valid(g):
		return
	
	var my_mode = g.get("my_mode")
	if my_mode == null:
		return
	
	if my_mode == 0:  # MODE_1_SORTER
		_play_mp_greywater_sorter(g)
	else:  # MODE_2_FILTER
		_play_mp_greywater_filter(g)

func _play_mp_greywater_sorter(g: Node) -> void:
	## Drag good water to tank
	if tap_cooldown > 0.0:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	# Find good water (not bad)
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.name.begins_with("Greywater"):
			var is_bad = child.get("is_bad")
			if is_bad == false:
				# Simulate drag to tank
				_simulate_click_on_node(child)
				tap_cooldown = 0.5
				return

func _play_mp_greywater_filter(g: Node) -> void:
	## Click filter icons
	if tap_cooldown > 0.0:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.name.begins_with("Filter"):
			_simulate_click_on_node(child)
			tap_cooldown = 0.4
			return

func _play_mp_bucket_brigade(_delta: float) -> void:
	## MiniGame_BucketBrigade: P1 = fill buckets, P2 = empty buckets
	var g := current_game
	if not is_instance_valid(g):
		return
	
	if tap_cooldown > 0.0:
		return
	
	var is_player_one = g.get("is_player_one")
	if is_player_one == null:
		return
	
	var buckets = g.get("buckets")
	if not buckets or buckets.is_empty():
		return
	
	# P1: Click empty buckets to fill
	# P2: Click full buckets to empty
	for bucket_data in buckets:
		var status = bucket_data.get("status", "")
		var bucket_node = bucket_data.get("node")
		
		if not is_instance_valid(bucket_node):
			continue
		
		if is_player_one and status == "empty":
			# Fill it
			_simulate_click_on_node(bucket_node)
			tap_cooldown = 0.5
			return
		elif not is_player_one and status == "full":
			# Empty it
			_simulate_click_on_node(bucket_node)
			tap_cooldown = 0.5
			return

func _play_mp_generic(_delta: float) -> void:
	## Generic multiplayer handler - tries to click on interactive objects
	if tap_cooldown > 0.0:
		return
	
	var g := current_game
	if not is_instance_valid(g):
		return
	
	# Try to find objects container
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		objects_container = g.get_node_or_null("ObjectsContainer")
	
	if not objects_container:
		return
	
	# Click first clickable child
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.has_method("_input_event") or child.get("input_pickable"):
			_simulate_click_on_node(child)
			tap_cooldown = 0.4
			return

func _simulate_click_on_node(node: Node) -> void:
	## Simulate a mouse click on a node
	if not is_instance_valid(node):
		return
	
	# Try input_event signal
	if node.has_signal("input_event"):
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = node.global_position if node is Node2D else Vector2.ZERO
		node.emit_signal("input_event", null, event, 0)
	
	# Try gui_input signal
	if node.has_signal("gui_input"):
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = Vector2.ZERO
		node.emit_signal("gui_input", event)
	
	# Try direct method calls
	if node.has_method("_on_clicked"):
		node.call("_on_clicked")
	elif node.has_method("_on_input_event"):
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		node.call("_on_input_event", null, event, 0)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _format_duration(_seconds: float) -> String:
	if _seconds <= 0:
		return "Unlimited"
	
	var hours = int(_seconds / 3600.0)
	var minutes = int((_seconds - hours * 3600) / 60.0)
	var secs = int(_seconds - hours * 3600 - minutes * 60)
	
	if hours > 0:
		return "%dh %dm %ds" % [hours, minutes, secs]
	if minutes > 0:
		return "%dm %ds" % [minutes, secs]
	return "%ds" % secs

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER SUPPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _process_mp_auto_play(delta: float) -> void:
	# Check MP duration limit
	if mp_auto_play_duration > 0 and mp_auto_play_start_time > 0:
		var mp_elapsed := (Time.get_ticks_msec() - mp_auto_play_start_time) / 1000.0
		if mp_elapsed >= mp_auto_play_duration:
			print("🤖 MP Auto-play duration reached (%s) — stopping" % _format_duration(mp_auto_play_duration))
			set_mp_auto_play_enabled(false)
			return

	# Drive the registered multiplayer game using the chosen strategy.
	if not current_game or not is_instance_valid(current_game):
		# No game registered — try to auto-dismiss instruction overlay
		_try_dismiss_mp_instruction_overlay()
		return
	var is_active := false
	if "game_active" in current_game:
		is_active = current_game.game_active
	elif "is_playing" in current_game:
		is_active = current_game.is_playing
	if not is_active:
		# Game exists but not started — dismiss instruction overlay if showing
		_try_dismiss_mp_instruction_overlay()
		return

	# ── Tick cooldowns (critical — without this the bot fires once then stalls) ──
	if swipe_cooldown > 0:
		swipe_cooldown -= delta
	if tap_cooldown > 0:
		tap_cooldown -= delta
	action_timer += delta

	# Reuse the existing strategy dispatch — the fallback branch handles
	# "drag_catcher" → _play_catcher and "click_target" → _play_mp_click_target.
	_dispatch_game_strategy(delta)

## Auto-dismiss instruction overlays so the MP bot can actually start playing.
func _try_dismiss_mp_instruction_overlay() -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	# Look for the InstructionOverlay's ClickCatcher button
	var overlay = scene.find_child("InstructionOverlay", true, false)
	if overlay and overlay.visible:
		var catcher = overlay.find_child("ClickCatcher", true, false)
		if catcher and catcher is Button:
			catcher.pressed.emit()
			print("🤖 MP AutoPlay: dismissed instruction overlay")


func register_multiplayer_game(game: Node, mode: String) -> void:
	if not mp_auto_play_enabled:
		return
	current_game = game
	game_name = game.get_script().resource_path.get_file().get_basename()
	# Collector-role games: move/drag a catcher to intercept falling objects
	const CATCHER_GAMES: Array[String] = [
		"MP_CatchTheRain", "MP_CatchRainAquarium",
		"MP_CollectDishWater", "MP_CollectLaundryWater", "MP_CollectShowerWater",
	]
	# Distributor-role games: click/tap interactive targets to use received water
	const TARGET_GAMES: Array[String] = [
		"MP_FillAquarium", "MP_WaterPlants", "MP_WashCar",
		"MP_MopFloor", "MP_FilterWater", "MP_FlushToilets", "MP_WashVegetables",
	]
	if game_name in CATCHER_GAMES:
		auto_play_strategy = "drag_catcher"
	elif game_name in TARGET_GAMES:
		auto_play_strategy = "click_target"
	else:
		auto_play_strategy = "tap"  # safe fallback
	action_timer = 0.0
	print(
		"🤖 Auto-play registered MP game: %s (role: %s, strategy: %s)"
		% [game_name, mode, auto_play_strategy]
	)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATS & REPORTING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Session figures for the auto-play run currently in progress.
##
## Anchored on auto_play_start_time, which set_auto_play_enabled() stamps at the
## same moment it zeroes games_played and total_score. The old anchor was a
## second field, session_start_time, that nothing ever assigned — it stayed 0, so
## the elapsed figure was the engine's whole uptime and games_per_minute was
## understated by however long the app had been open before auto-play began.
func get_session_stats() -> Dictionary:
	var elapsed_ms := Time.get_ticks_msec() - auto_play_start_time
	var elapsed_minutes := elapsed_ms / 60000.0
	
	return {
		"games_played": games_played,
		"total_score": total_score,
		"session_duration_min": elapsed_minutes,
		# float() first: two ints divide as an int, which truncated the mean.
		"average_score": float(total_score) / float(max(games_played, 1)),
		# The old max(..., 1.0) clamp did not guard a division, it rewrote the rate:
		# 5 games in 20 s reported as 5/min instead of 15/min. Zero elapsed time has
		# no rate, so it reports none.
		"games_per_minute": (float(games_played) / elapsed_minutes if elapsed_minutes > 0.0 else 0.0)
	}

func print_session_stats() -> void:
	var stats := get_session_stats()
	print("═══════════════════════════════════════════════════════")
	print("🤖 AUTO-PLAY SESSION STATS")
	print("═══════════════════════════════════════════════════════")
	print("  Games Played: %d" % stats.games_played)
	print("  Total Score: %d" % stats.total_score)
	print("  Average Score: %.1f" % stats.average_score)
	print("  Session Duration: %.1f minutes" % stats.session_duration_min)
	print("  Games/Minute: %.2f" % stats.games_per_minute)
	print("═══════════════════════════════════════════════════════")
