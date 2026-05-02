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

# Duration settings (in seconds, 0 = unlimited)
var auto_play_duration: float = 0.0  # 0 = unlimited
var auto_play_start_time: int = 0
var auto_play_elapsed: float = 0.0

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
var session_start_time: int = 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
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

func set_auto_play_enabled(enabled: bool) -> void:
	auto_play_enabled = enabled
	
	if SaveManager:
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
	print("🤖 MP Auto-play %s" % ("ENABLED" if enabled else "DISABLED"))

func is_mp_auto_play_enabled() -> bool:
	return mp_auto_play_enabled

func _reset_state() -> void:
	current_game = null
	game_name = ""
	auto_play_strategy = ""
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
		"Rainwater Harvesting": "tap_targets"
	}
	
	return strategies.get(game_type, "tap_targets")  # Default to tap strategy

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-PLAY PROCESS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _process(delta: float) -> void:
	# MP auto-play: runs independently of the SP auto_play_enabled flag
	if mp_auto_play_enabled:
		_process_mp_auto_play(delta)
		# Also navigate UI if MP auto-play is on (results screens, lobby, etc.)
		if not current_game or not is_instance_valid(current_game):
			_navigate_ui(delta)
	
	if not auto_play_enabled:
		return

	# Update elapsed time and check duration
	if auto_play_start_time > 0:
		auto_play_elapsed = (Time.get_ticks_msec() - auto_play_start_time) / 1000.0
		if auto_play_duration > 0 and auto_play_elapsed >= auto_play_duration:
			var dur_str = _format_duration(auto_play_duration)
			print("🤖 Auto-play duration reached (%s) - Stopping" % dur_str)
			set_auto_play_enabled(false)
			return

	# Dismiss StoryScreen overlay if it is showing (it overlays the scene,
	# so scene_file_path stays unchanged — we must handle it here first).
	if _try_advance_story_screen():
		return

	# If no active game, navigate menus autonomously
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

	# ── MiniGame intro bridge (auto-proceeds; nothing for AI to do) ─
	if "MiniGameIntroBridge" in path:
		return

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
		# If a StartGameButton is present and enabled (2 players connected), start the game
		var start_btn: Button = _find_button_recursive(scene, ["StartGameButton"])
		if start_btn and not start_btn.disabled:
			print("🤖 AutoNav: starting multiplayer game")
			start_btn.pressed.emit()
			return
		# Single-device testing: back out gracefully since we can't host+join simultaneously
		var back_btn: Button = _find_button_recursive(scene, ["BackButton", "DisconnectButton"])
		if back_btn:
			print("🤖 AutoNav: exiting multiplayer lobby (no second player available)")
			back_btn.pressed.emit()
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
func _dispatch_game_strategy(delta: float) -> void:
	match game_name:
		"MP_CatchTheRain", "MP_CatchRainAquarium":
			_play_catcher(delta)
		"MP_CollectDishWater", "MP_CollectLaundryWater", "MP_CollectShowerWater":
			_play_mp_drag_collection(delta)
		"MP_WashVegetables":
			_play_mp_wash_vegetables(delta)
		"MP_WaterPlants":
			_play_mp_water_plants(delta)
		"MP_FlushToilets":
			_play_mp_flush_toilets(delta)
		"MP_FillAquarium":
			_play_mp_fill_aquarium(delta)
		"MP_FilterWater":
			_play_mp_filter_water(delta)
		"MP_MopFloor":
			_play_mp_mop_floor(delta)
		"MP_WashCar":
			_play_mp_wash_car(delta)
		"Swipe The Soap":
			_play_swipe_soap(delta)
		"Scrub To Save":
			_play_scrub_to_save(delta)
		"Wring It Out":
			_play_wring_it_out(delta)
		"Catch The Rain":
			_play_catcher(delta)
		"Cloud Catcher":
			_play_cloud_catcher(delta)
		"Cover The Drum":
			_play_cover_the_drum(delta)
		"Bucket Brigade":
			_play_bucket_brigade(delta)
		"Rice Wash Rescue":
			_play_rice_wash_rescue(delta)
		"Vegetable Bath":
			_play_vegetable_bath(delta)
		"Water Memory":
			_play_water_memory(delta)
		"Trace Pipe Path":
			_play_trace_pipe_path(delta)
		"Greywater Sorter":
			_play_greywater_sorter(delta)
		"Filter Builder":
			_play_filter_builder(delta)
		"Timing Tap":
			_play_timing_tap(delta)
		"Quick Shower":
			_play_quick_shower(delta)
		"Turn Off Tap":
			_play_turn_off_tap(delta)
		"Plug The Leak":
			_play_plug_the_leak(delta)
		"Fix Leak", "Fix the Leak":
			_play_fix_leak(delta)
		"Spot The Speck":
			_play_spot_the_speck(delta)
		"Water Plant":
			_play_water_plant(delta)
		"Thirsty Plant":
			_play_thirsty_plant(delta)
		"Toilet Tank Fix":
			_play_toilet_tank_fix(delta)
		"Mud Pie Maker":
			_play_mud_pie_maker(delta)
		"Droplet Dash":
			_play_droplet_dash(delta)
		_:
			# Fallback: dispatch on strategy string for MP games
			if auto_play_strategy == "drag_catcher":
				_play_catcher(delta)
			elif auto_play_strategy == "click_target":
				_play_mp_click_target(delta)
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
		if btn.visible and not btn.disabled:
			out.append(btn)
			return
	if node is Area2D:
		var a := node as Area2D
		# Skip bucket/catcher nodes — only collect tappable targets
		if a.visible and a.has_meta("type"):
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
# Find first untapped cloud in clouds[]; call _on_cloud_tapped().
# ──────────────────────────────────────────────────────────────────
func _play_cloud_catcher(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_on_cloud_tapped"):
		return
	var clouds: Array = g.get("clouds") if "clouds" in g else []
	for cloud in clouds:
		if not is_instance_valid(cloud):
			continue
		if cloud.get_meta("tapped", false):
			continue
		g.call("_on_cloud_tapped", cloud)
		tap_cooldown = 0.3
		return

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
# Warp the OS mouse cursor to the nearest good (blue) falling drop.
# The game's _process() lerps drum_node.position.x to mouse X every frame.
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
		Input.warp_mouse(Vector2(catcher.position.x, catcher.position.y))
		return
	var screen_size := get_viewport().get_visible_rect().size
	var best_x: float = catcher.position.x
	var best_score: float = -INF
	# Find nearest good (blue) drop to chase
	for drop in drops:
		if not is_instance_valid(drop):
			continue
		if not drop.get_meta("good", true):
			continue
		var score: float = drop.position.y - absf(drop.position.x - catcher.position.x) * 0.3
		if score > best_score:
			best_score = score
			best_x = drop.position.x
	# Dodge any bad (red) drops near our target position
	for drop in drops:
		if not is_instance_valid(drop):
			continue
		if drop.get_meta("good", true):
			continue
		if absf(drop.position.x - best_x) < 80.0 and drop.position.y > 100.0:
			best_x += 130.0 * signf(catcher.position.x - drop.position.x)
			best_x = clampf(best_x, 70.0, screen_size.x - 70.0)
	Input.warp_mouse(Vector2(best_x, catcher.position.y))

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
func _play_generic_tap(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var all_buttons := _collect_all_buttons(g)
	var skip_words := ["back", "close", "skip", "menu", "pause", "undo", "home", "exit"]
	var game_btns: Array = []
	for btn in all_buttons:
		if not is_instance_valid(btn) or (btn as Button).disabled or not (btn as Button).visible:
			continue
		var lower_name: String = (btn as Button).name.to_lower()
		var is_ui_btn := false
		for sw in skip_words:
			if sw in lower_name:
				is_ui_btn = true
				break
		if not is_ui_btn:
			game_btns.append(btn)
	if game_btns.is_empty():
		game_btns = all_buttons
	if game_btns.is_empty():
		return
	var chosen: Button = game_btns[randi() % game_btns.size()]
	chosen.pressed.emit()
	tap_cooldown = 0.3

func _collect_all_buttons(node: Node) -> Array:
	var result: Array = []
	if node is Button:
		var btn := node as Button
		if btn.visible and not btn.disabled:
			result.append(btn)
	for child in node.get_children():
		result.append_array(_collect_all_buttons(child))
	return result


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

func get_session_stats() -> Dictionary:
	var elapsed_ms := Time.get_ticks_msec() - session_start_time
	var elapsed_minutes := elapsed_ms / 60000.0
	
	return {
		"games_played": games_played,
		"total_score": total_score,
		"session_duration_min": elapsed_minutes,
		"average_score": total_score / max(games_played, 1),
		"games_per_minute": games_played / max(elapsed_minutes, 1.0)
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
