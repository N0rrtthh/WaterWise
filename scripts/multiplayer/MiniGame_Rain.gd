class_name MiniGameRain
extends Node2D

## 
## MINIGAME_RAIN.GD - Dual-Mode Water Reuse Game
## 
## Theme: "Rainwater Harvesting & Filtration" 
## 
## DUAL-MODE GAMEPLAY (Random Assignment Each Game):
## - MODE 1 (Collector): Catch falling CLEAN water drops with bucket
##    Adds to shared water tank
## - MODE 2 (Filter): Remove DIRTY particles from collected water by tapping
##    Cleans the water tank for points
##
## Each player gets a RANDOM mode at the start of each game!
##
## ALGORITHMS USED:
## 1. G-Counter: Both modes submit_score() when completing tasks
## 2. Rolling Window: Adaptive difficulty based on team performance
##
## SHARED GOAL: Collect & filter enough clean water to reach quota
## FAIL STATE: Miss items  Lose team life
## 

signal game_won()
signal game_lost()
signal score_updated(new_score: int)

# 
# DIFFICULTY PARAMETERS (Controlled by Rolling Window)
# 

const DIFFICULTY_SETTINGS: Dictionary = {
	"Easy": {
		"quota": 20,
		"mode1_spawn_rate": 2.5,      # Collector: Seconds between water drops (slower = easier)
		"mode1_drop_speed": 180.0,    # Drop falling speed (slower = easier)
		"mode2_spawn_rate": 3.0,      # Filter: Seconds between dirt particles (slower = easier)
		"mode2_dirt_speed": 120.0,    # Dirt floating speed (slower = easier)
		"mode2_dirt_count": 1         # Number of dirt particles at once
	},
	"Medium": {
		"quota": 30,
		"mode1_spawn_rate": 1.8,
		"mode1_drop_speed": 250.0,
		"mode2_spawn_rate": 2.2,
		"mode2_dirt_speed": 180.0,
		"mode2_dirt_count": 2
	},
	"Hard": {
		"quota": 45,
		"mode1_spawn_rate": 1.2,
		"mode1_drop_speed": 350.0,
		"mode2_spawn_rate": 1.5,
		"mode2_dirt_speed": 250.0,
		"mode2_dirt_count": 3
	}
}

const MOVING_OBJECT_SCRIPT: GDScript = preload("res://scripts/multiplayer/MovingObject.gd")

# 
# NODE REFERENCES
# 

@onready var spawn_timer: Timer = $SpawnTimer
@onready var bucket: Area2D = $GameLayer/Bucket  # P1's catch area (nested under GameLayer)
# Container for spawned objects.
@onready var objects_container: Node2D = $GameLayer/ObjectsContainer
@onready var hud: CanvasLayer = $UI  # UI CanvasLayer
@onready var score_label: Label = $UI/TopBar/ScoreLabel
@onready var lives_label: Label = $UI/TopBar/LivesLabel
@onready var timer_label: Label = $UI/TopBar/TimerLabel
@onready var role_label: Label = $UI/RoleLabel
@onready var quota_bar: ProgressBar = $UI/QuotaBar
@onready var game_over_panel: PanelContainer = $UI/GameOverPanel

# Pause menu (created dynamically)
var pause_menu: Control = null
var pause_button: Button = null

# 
# GAME STATE
# 

# Player mode assignment (randomly assigned each game)
enum PlayerMode {
	MODE_1_COLLECTOR,  # Catch water drops
	MODE_2_FILTER      # Remove dirt particles
}

var my_mode: PlayerMode = PlayerMode.MODE_1_COLLECTOR
var partner_mode: PlayerMode = PlayerMode.MODE_2_FILTER
var current_difficulty: String = "Easy"
var current_settings: Dictionary = {}
var game_active: bool = false
var local_score: int = 0
var round_start_time: int = 0
var screen_size: Vector2 = Vector2.ZERO
var game_timer: float = 60.0
var time_limit: float = 60.0
var is_paused: bool = false
var timer_sync_timer: Timer = null

# Preloaded scenes
var drop_scene: PackedScene = null
var dirt_scene: PackedScene = null

# 
# INITIALIZATION
# 

func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	# Verify multiplayer is active
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		push_error(" Multiplayer not active! Returning to lobby...")
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
		return
	
	# Get random mode assignment from GameManager
	if GameManager and GameManager.has_method("get_my_player_mode"):
		var mode_num = GameManager.get_my_player_mode()
		my_mode = PlayerMode.MODE_1_COLLECTOR if mode_num == 1 else PlayerMode.MODE_2_FILTER
		partner_mode = (
			PlayerMode.MODE_2_FILTER
			if my_mode == PlayerMode.MODE_1_COLLECTOR
			else PlayerMode.MODE_1_COLLECTOR
		)
	else:
		# Fallback: host gets mode 1, client gets mode 2
		var is_host = (multiplayer.get_unique_id() == 1)
		my_mode = PlayerMode.MODE_1_COLLECTOR if is_host else PlayerMode.MODE_2_FILTER
		partner_mode = PlayerMode.MODE_2_FILTER if is_host else PlayerMode.MODE_1_COLLECTOR
	
	print(
		" My Mode: ",
		"MODE 1 (Collector)" if my_mode == PlayerMode.MODE_1_COLLECTOR else "MODE 2 (Filter)"
	)
	
	# Load difficulty from GameManager's Rolling Window
	_load_difficulty()
	
	# Setup UI based on assigned mode
	_setup_role_ui()
	
	# Preload object scenes
	_preload_scenes()
	
	# Connect signals
	if spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	if bucket and bucket.has_signal("object_caught"):
		bucket.object_caught.connect(_on_drop_caught)
	
	if GameManager:
		GameManager.team_won.connect(_on_team_won)
		GameManager.team_lost.connect(_on_team_lost)
		GameManager.team_life_lost.connect(_on_life_lost)
	
	# Create pause menu and button
	_create_pause_ui()

	# Timer sync ensures both peers share the same countdown
	timer_sync_timer = Timer.new()
	timer_sync_timer.wait_time = 0.25
	timer_sync_timer.one_shot = false
	timer_sync_timer.autostart = false
	add_child(timer_sync_timer)
	timer_sync_timer.timeout.connect(_on_timer_sync_timeout)
	
	# Start the game
	_start_game()

func _preload_scenes() -> void:
	# Preload the spawnable object scenes.
	# Use the generic MovingObject scene for all spawnable items
	var moving_obj_path := "res://scripts/multiplayer/MovingObject.tscn"
	
	if ResourceLoader.exists(moving_obj_path):
		drop_scene = load(moving_obj_path)
		dirt_scene = load(moving_obj_path)
	else:
		# Scenes not found - will create dynamically
		print(" MovingObject.tscn not found - will create objects dynamically")
		drop_scene = null
		dirt_scene = null

func _is_mode_1() -> bool:
	# Helper: check if this player is Mode 1 (Collector).
	return my_mode == PlayerMode.MODE_1_COLLECTOR

func _is_host() -> bool:
	# Helper: check if this player is the host.
	return multiplayer.get_unique_id() == 1

func _load_difficulty() -> void:
	# Load difficulty based on GameManager's difficulty_multiplier.
	# Formula: spawn_rate = base_rate / difficulty_multiplier.
	# Supports uncapped difficulty scaling.
	if GameManager:
		var mult: float = GameManager.difficulty_multiplier
		
		# Map multiplier to difficulty level (uncapped support)
		if mult >= 2.0:
			current_difficulty = "Extreme"
		elif mult >= 1.5:
			current_difficulty = "Hard"
		elif mult >= 1.0:
			current_difficulty = "Medium"
		else:
			current_difficulty = "Easy"
		
		# Fallback to Hard settings if Extreme not defined
		if current_difficulty == "Extreme" and not DIFFICULTY_SETTINGS.has("Extreme"):
			current_difficulty = "Hard"
	
	current_settings = DIFFICULTY_SETTINGS[current_difficulty].duplicate()
	
	# Apply Rolling Window adjustment to spawn rates
	if GameManager:
		var mult: float = GameManager.difficulty_multiplier
		current_settings["mode1_spawn_rate"] /= mult
		current_settings["mode2_spawn_rate"] /= mult

	print(
		" [MiniGame_Rain] Difficulty: ",
		current_difficulty,
		" (multiplier: %.2f" % GameManager.difficulty_multiplier
	)
	print("   Mode 1 Spawn Rate: %.3fs" % current_settings["mode1_spawn_rate"])
	print("   Mode 2 Spawn Rate: %.3fs" % current_settings["mode2_spawn_rate"])

func _setup_role_ui() -> void:
	# Setup UI elements based on player role.
	# Create instruction panel
	var instruction_panel = PanelContainer.new()
	instruction_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	instruction_panel.offset_top = 120
	instruction_panel.offset_bottom = 220
	instruction_panel.offset_left = 20
	instruction_panel.offset_right = -20
	
	var instruction_bg = StyleBoxFlat.new()
	instruction_bg.bg_color = Color(0, 0, 0, 0.7)
	instruction_bg.corner_radius_top_left = 10
	instruction_bg.corner_radius_top_right = 10
	instruction_bg.corner_radius_bottom_left = 10
	instruction_bg.corner_radius_bottom_right = 10
	instruction_panel.add_theme_stylebox_override("panel", instruction_bg)
	
	var instruction_vbox = VBoxContainer.new()
	instruction_vbox.add_theme_constant_override("separation", 10)
	instruction_panel.add_child(instruction_vbox)
	
	var title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	
	var controls_label = Label.new()
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.add_theme_font_size_override("font_size", 20)
	
	if _is_mode_1():
		role_label.text = " MODE 1: COLLECTOR"
		title_label.text = "YOUR ROLE: Catch Clean Water Drops!"
		controls_label.text = " CONTROLS: Move mouse to move bucket"
		bucket.visible = true
		bucket.position = Vector2(screen_size.x / 2, screen_size.y - 100)
	else:
		role_label.text = " MODE 2: FILTER"
		title_label.text = "YOUR ROLE: Remove Dirt Particles!"
		controls_label.text = " CONTROLS: Click on dirt particles"
		bucket.visible = false
	
	instruction_vbox.add_child(title_label)
	instruction_vbox.add_child(controls_label)
	hud.add_child(instruction_panel)
	
	# Hide instructions after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if instruction_panel:
		var fade_tween = create_tween()
		fade_tween.set_loops(1)
		fade_tween.tween_property(instruction_panel, "modulate:a", 0.0, 1.0)
		fade_tween.tween_callback(instruction_panel.queue_free)
	
	# Setup quota bar
	quota_bar.max_value = current_settings["quota"]
	quota_bar.value = 0
	
	# Update lives display
	_update_lives_display()

func _update_lives_display() -> void:
	# Update the lives display from GameManager.
	if GameManager:
		lives_label.text = "".repeat(GameManager.team_lives)
	else:
		lives_label.text = ""

func _update_quota_bar() -> void:
	# Update the quota progress bar.
	if quota_bar and GameManager:
		var global_score: int = GameManager.get_global_score()
		quota_bar.max_value = current_settings["quota"]
		quota_bar.value = global_score

# 
# GAME FLOW
# 

func _start_game() -> void:
	# Start the mini-game.
	game_active = true
	local_score = 0
	round_start_time = Time.get_ticks_msec()  # Record start time for rolling window
	
	# Set the quota in GameManager so it knows when to trigger victory
	if GameManager:
		GameManager.set_minigame_quota(current_settings["quota"])
	
	# Reset game timer
	time_limit = 60.0  # 60 seconds per round
	game_timer = time_limit

	if timer_sync_timer:
		if _is_host():
			timer_sync_timer.start()
			rpc("_sync_timer", game_timer)
		else:
			timer_sync_timer.stop()
	
	# Initialize lives display
	_update_lives_display()
	_update_score_display()
	_update_quota_bar()
	
	# Configure spawn timer based on mode
	# Formula: wait_time = base_spawn_rate / difficulty_multiplier
	if _is_mode_1():
		spawn_timer.wait_time = current_settings["mode1_spawn_rate"]
	else:
		spawn_timer.wait_time = current_settings["mode2_spawn_rate"]
	
	spawn_timer.start()
	print(" Game started! Mode: ", "Mode 1 (Collector)" if _is_mode_1() else "Mode 2 (Filter)")
	print(" Team Lives: ", GameManager.team_lives if GameManager else 3)
	print(" Quota: ", current_settings["quota"])

func _on_spawn_timer_timeout() -> void:
	# Spawn objects based on player mode. Host only spawns and syncs.
	if not game_active:
		return
	
	# Only host spawns objects to ensure synchronization
	if not _is_host():
		return
	
	# Spawn for both modes and sync to clients
	_spawn_drop_synced()
	_spawn_dirt_synced()

func _spawn_drop_synced() -> void:
	# HOST: spawn a water drop and sync to all clients.
	if not _is_host():
		return
	
	# Generate spawn parameters
	var spawn_x: float = randf_range(50, screen_size.x - 50)
	var spawn_id: int = Time.get_ticks_msec()  # Unique ID for this drop
	var is_acid: bool = randf() < 0.15  # 15% chance of acid drop
	
	# Spawn locally
	_create_drop_at(spawn_x, spawn_id, is_acid)
	
	# Sync to all clients
	rpc("_create_drop_at", spawn_x, spawn_id, is_acid)

@rpc("authority", "call_local", "reliable")
func _create_drop_at(spawn_x: float, spawn_id: int, is_acid: bool) -> void:
	# Create a drop at a specified position (called on all clients).
	# Only Mode 1 players see and interact with drops
	if not _is_mode_1():
		return
	
	var drop: Area2D
	
	if drop_scene:
		drop = drop_scene.instantiate()
	else:
		drop = _create_dynamic_drop(is_acid)
	
	drop.position = Vector2(spawn_x, -50)
	drop.name = "Drop_" + str(spawn_id)
	
	# Set movement properties
	if drop.has_method("setup"):
		drop.setup(
			Vector2.DOWN,
			current_settings["mode1_drop_speed"],
			is_acid
		)
	
	# Connect signals
	if drop.has_signal("missed"):
		drop.missed.connect(_on_drop_missed)
	
	# Add to container
	if objects_container:
		objects_container.add_child(drop)
	else:
		add_child(drop)

func _spawn_dirt_synced() -> void:
	# HOST: spawn dirt particles and sync to all clients.
	if not _is_host():
		return
	
	# Generate spawn parameters
	var spawn_y: float = randf_range(100, screen_size.y - 200)
	var spawn_id: int = Time.get_ticks_msec() + 1000  # Offset to avoid collision with drops
	
	# Spawn locally
	_create_dirt_at(spawn_y, spawn_id)
	
	# Sync to all clients
	rpc("_create_dirt_at", spawn_y, spawn_id)

@rpc("authority", "call_local", "reliable")
func _create_dirt_at(spawn_y: float, spawn_id: int) -> void:
	# Create a dirt particle at a specified position (called on all clients).
	# Only Mode 2 players see and interact with dirt
	if _is_mode_1():
		return
	
	var leaf: Area2D
	
	if dirt_scene:
		leaf = dirt_scene.instantiate()
	else:
		leaf = _create_dynamic_leaf()
	
	leaf.position = Vector2(-50, spawn_y)
	leaf.name = "Dirt_" + str(spawn_id)
	
	# Set movement properties
	if leaf.has_method("setup"):
		leaf.setup(
			Vector2.RIGHT,
			current_settings["mode2_dirt_speed"],
			true  # Enable spin
		)
	
	# Connect signals
	if leaf.has_signal("destroyed"):
		leaf.destroyed.connect(_on_leaf_destroyed)
	if leaf.has_signal("missed"):
		leaf.missed.connect(_on_leaf_missed)
	
	# Add to container
	if objects_container:
		objects_container.add_child(leaf)
	else:
		add_child(leaf)

func _create_dynamic_drop(is_acid: bool) -> Area2D:
	# Create a drop dynamically if scene not found.
	var drop: Area2D = Area2D.new()
	drop.name = "AcidDrop" if is_acid else "WaterDrop"
	
	# Add collision shape
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	drop.add_child(collision)
	
	# Add visual (colored circle)
	var visual: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var angle: float = i * TAU / 16
		points.append(Vector2(cos(angle) * 20, sin(angle) * 25))
	visual.polygon = points
	visual.color = Color(1.0, 0.2, 0.2) if is_acid else Color(0.3, 0.6, 1.0)
	drop.add_child(visual)
	
	# Add the MovingObject script
	if MOVING_OBJECT_SCRIPT:
		drop.set_script(MOVING_OBJECT_SCRIPT)
		# Set object type
		if is_acid:
			drop.object_type = 1  # ACID_DROP
			drop.is_special = true
		else:
			drop.object_type = 0  # WATER_DROP
			drop.is_special = false
	
	return drop

func _on_drop_caught(drop: Area2D, is_acid: bool) -> void:
	# Called when P1 catches a drop.
	if is_acid:
		# Caught acid - that's bad!
		print(" Caught acid drop!")
		if GameManager:
			GameManager.rpc("report_damage")
	else:
		# Caught water - score!
		local_score += 1
		print(" Caught water drop! Score: ", local_score)
		
		# G-Counter: Submit score to server (this syncs automatically)
		if GameManager:
			GameManager.rpc("submit_score", 1)
		
		# Update displays on all clients
		rpc("_sync_score_update")
	
	drop.queue_free()

func _on_drop_missed(drop: Area2D, is_special: bool) -> void:
	# Called when P1 misses a drop.
	if is_special:
		# Missed acid - that's good!
		print(" Avoided acid drop!")
	else:
		# Missed water - damage!
		print(" Missed water drop!")
		if GameManager:
			GameManager.rpc("report_damage")
	
	drop.queue_free()

# 
# PLAYER 2: DIRT PARTICLE INTERACTION
# 

func _create_dynamic_leaf() -> Area2D:
	# Create a leaf dynamically if scene not found.
	var leaf: Area2D = Area2D.new()
	leaf.name = "Leaf"
	leaf.input_pickable = true  # Enable click detection
	
	# Add collision shape (larger for easier clicking)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 25.0
	collision.shape = shape
	leaf.add_child(collision)
	
	# Add visual (realistic dirty leaf shape)
	var visual: Polygon2D = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-25, 0),
		Vector2(-15, -12),
		Vector2(0, -15),
		Vector2(15, -12),
		Vector2(25, 0),
		Vector2(15, 12),
		Vector2(0, 15),
		Vector2(-15, 12)
	])
	# Dirty brown color
	visual.color = Color(0.4, 0.3, 0.1, 1.0)
	leaf.add_child(visual)
	
	# Add dirt spots
	var spot1: Polygon2D = Polygon2D.new()
	spot1.polygon = PackedVector2Array([
		Vector2(-5, -5),
		Vector2(0, -8),
		Vector2(5, -5),
		Vector2(0, -2)
	])
	spot1.color = Color(0.2, 0.15, 0.05, 1.0)
	leaf.add_child(spot1)
	
	# Add the MovingObject script
	if MOVING_OBJECT_SCRIPT:
		leaf.set_script(MOVING_OBJECT_SCRIPT)
		# Set object type
		leaf.object_type = 2  # LEAF
	
	return leaf

func _on_leaf_destroyed(leaf: Area2D) -> void:
	# Called when P2 destroys a leaf by clicking.
	local_score += 1
	print(" Destroyed leaf! Score: ", local_score)
	
	# G-Counter: Submit score to server (this syncs automatically)
	if GameManager:
		GameManager.rpc("submit_score", 1)
	
	# Update displays on all clients
	rpc("_sync_score_update")
	
	leaf.queue_free()

func _on_leaf_missed(leaf: Area2D, _is_special: bool) -> void:
	# Called when P2 misses a leaf (exits screen).
	print(" Missed leaf!")
	if GameManager:
		GameManager.rpc("report_damage")
	
	leaf.queue_free()

# 
# INPUT HANDLING
# 

func _process(delta: float) -> void:
	if not game_active:
		return
	if is_paused:
		return
	
	# Update game timer (host authoritative)
	if _is_host():
		game_timer = max(game_timer - delta, 0.0)
	
	# Update timer display for all players
	if timer_label:
		timer_label.text = " " + str(int(max(0, game_timer)))
	
	# Check if time ran out (host drives win/lose)
	if _is_host() and game_timer <= 0 and game_active:
		game_active = false
		spawn_timer.stop()
		if timer_sync_timer:
			timer_sync_timer.stop()
		print(" Time's up!")
		
		# Check if quota was met
		var global_score: int = GameManager.get_global_score() if GameManager else local_score
		if global_score >= current_settings["quota"]:
			# Met quota, consider it a win
			if GameManager and _is_host():
				GameManager.rpc("_announce_team_won")
		else:
			# Didn't meet quota, it's a loss
			if GameManager and _is_host():
				GameManager.rpc("_announce_team_lost")
		return
	
	# Mode 1: Move bucket with mouse X position (smooth interpolation)
	if _is_mode_1() and bucket:
		var mouse_x: float = get_viewport().get_mouse_position().x
		var target_x: float = clampf(mouse_x, 50, screen_size.x - 50)
		# Smooth movement instead of instant snap
		bucket.position.x = lerp(bucket.position.x, target_x, delta * 15.0)

func _on_timer_sync_timeout() -> void:
	if not _is_host() or not game_active:
		return
	
	# Sync timer to all clients every 0.25 seconds
	# Broadcast remaining time so clients stay aligned
	rpc("_sync_timer", game_timer)

@rpc("authority", "call_local", "unreliable")
func _sync_timer(remaining_time: float) -> void:
	if _is_host():
		return
	game_timer = remaining_time

# Note: Input handling is done by MovingObject script's _on_input_event
# P2 clicks are automatically detected when clicking on leaf Area2D nodes

# 
# UI UPDATES
# 

func _update_score_display() -> void:
	# Update the score and quota bar.
	var global_score: int = GameManager.get_global_score() if GameManager else local_score
	score_label.text = "Score: %d / %d" % [global_score, current_settings["quota"]]
	quota_bar.value = global_score
	score_updated.emit(global_score)
	
	# Check if quota reached (host only, prevents duplicate checks)
	if _is_host() and game_active and global_score >= current_settings["quota"]:
		print(" Quota reached! Score: %d >= %d" % [global_score, current_settings["quota"]])
		game_active = false
		spawn_timer.stop()
		if timer_sync_timer:
			timer_sync_timer.stop()
		# Trigger win through GameManager
		if GameManager:
			GameManager.rpc("_announce_team_won")

@rpc("any_peer", "call_local", "reliable")
func _sync_score_update() -> void:
	_update_score_display()

# 
# GAME END CONDITIONS
# 

func _on_team_won() -> void:
	# Called when team reaches the quota.
	game_active = false
	spawn_timer.stop()
	if timer_sync_timer:
		timer_sync_timer.stop()
	game_won.emit()
	print(" VICTORY! Team reached the quota!")
	
	# Calculate round time and update rolling window for adaptive difficulty
	# Only host updates the rolling window to avoid duplicate entries
	if GameManager and _is_host():
		var round_time_ms: int = Time.get_ticks_msec() - round_start_time
		var round_time_sec: float = float(round_time_ms) / 1000.0
		GameManager.add_round_time(round_time_sec)
		GameManager.minigames_played_this_session += 1
		print(" [Rolling Window] Round completed in %.2fs" % round_time_sec)
	
	# Show victory screen
	_show_result_screen(true)
	await get_tree().create_timer(2.0).timeout
	
	# Only host initiates next minigame load
	if GameManager and GameManager.is_host:
		GameManager.rpc("_load_next_multiplayer_minigame")

func _on_team_lost() -> void:
	# Called when team runs out of lives.
	game_active = false
	spawn_timer.stop()
	if timer_sync_timer:
		timer_sync_timer.stop()
	game_lost.emit()
	print(" DEFEAT! Team ran out of lives!")
	
	# Show defeat screen
	_show_result_screen(false)
	await get_tree().create_timer(2.0).timeout
	
	# Check if lives remain for next game
	if GameManager and GameManager.is_host:
		if GameManager.team_lives > 0:
			# Continue to next minigame
			GameManager.rpc("_load_next_multiplayer_minigame")
		else:
			# Game over - show final results
			GameManager.rpc("_show_multiplayer_final_results")

func _on_life_lost(_remaining: int) -> void:
	# Called when team loses a life.
	_update_lives_display()
	
	# Screen shake effect
	var tween: Tween = create_tween()
	tween.set_loops(1)
	tween.tween_property(self, "position", Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", Vector2(-10, 0), 0.05)
	tween.tween_property(self, "position", Vector2.ZERO, 0.05)

func _show_result_screen(victory: bool) -> void:
	# Show the result overlay
	var result: Control = Control.new()
	result.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0.5, 0, 0.8) if victory else Color(0.5, 0, 0, 0.8)
	result.add_child(bg)
	
	var label: Label = Label.new()
	label.text = " TEAM WINS!" if victory else " GAME OVER"
	label.add_theme_font_size_override("font_size", 72)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	result.add_child(label)
	
	hud.add_child(result)
	
	# Don't auto-return - let GameManager handle next minigame or final results

# PAUSE SYSTEM (SYNCHRONIZED FOR MULTIPLAYER)

func _create_pause_ui() -> void:
	# Create pause button and pause menu
	pause_button = Button.new()
	pause_button.text = ""
	pause_button.custom_minimum_size = Vector2(50, 50)
	pause_button.add_theme_font_size_override("font_size", 32)
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.2, 0.3, 0.4, 0.8)
	btn_normal.corner_radius_top_left = 10
	btn_normal.corner_radius_top_right = 10
	btn_normal.corner_radius_bottom_left = 10
	btn_normal.corner_radius_bottom_right = 10
	
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.3, 0.5, 0.7, 0.9)
	btn_pressed.corner_radius_top_left = 10
	btn_pressed.corner_radius_top_right = 10
	btn_pressed.corner_radius_bottom_left = 10
	btn_pressed.corner_radius_bottom_right = 10
	
	pause_button.add_theme_stylebox_override("normal", btn_normal)
	pause_button.add_theme_stylebox_override("pressed", btn_pressed)
	pause_button.add_theme_stylebox_override("hover", btn_normal)
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_on_pause_button_pressed)
	
	var top_bar = $UI/TopBar
	if top_bar:
		top_bar.add_child(pause_button)
	
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(pause_menu)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	pause_menu.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var label = Label.new()
	label.text = "PAUSED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(label)
	
	var resume_btn = Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(200, 60)
	resume_btn.add_theme_font_size_override("font_size", 24)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)
	
	var exit_btn = Button.new()
	exit_btn.text = "EXIT TO LOBBY"
	exit_btn.custom_minimum_size = Vector2(200, 60)
	exit_btn.add_theme_font_size_override("font_size", 24)
	exit_btn.pressed.connect(_on_exit_pressed)
	vbox.add_child(exit_btn)

func _on_pause_button_pressed() -> void:
	if is_paused:
		return
	is_paused = true
	get_tree().paused = true
	pause_menu.visible = true
	pause_button.text = ""
	# Sync pause to all players
	if NetworkManager:
		NetworkManager.rpc("sync_pause_state", true)
	print(" Game paused by local player")

func _on_resume_pressed() -> void:
	if not is_paused:
		return
	is_paused = false
	get_tree().paused = false
	pause_menu.visible = false
	pause_button.text = ""
	# Sync resume to all players
	if NetworkManager:
		NetworkManager.rpc("sync_pause_state", false)
	print(" Game resumed by local player")

func _on_exit_pressed() -> void:
	get_tree().paused = false
	is_paused = false
	game_active = false
	if spawn_timer:
		spawn_timer.stop()
	if NetworkManager:
		NetworkManager.return_to_lobby()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _on_remote_pause() -> void:
	is_paused = true
	get_tree().paused = true
	if pause_menu:
		pause_menu.visible = true
	if pause_button:
		pause_button.text = ""
	print(" Game paused by remote player")

func _on_remote_resume() -> void:
	is_paused = false
	get_tree().paused = false
	if pause_menu:
		pause_menu.visible = false
	if pause_button:
		pause_button.text = ""
	print(" Game resumed by remote player")
