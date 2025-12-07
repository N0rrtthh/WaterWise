class_name MiniGameWaterHarvest
extends Node2D

## ═══════════════════════════════════════════════════════════════════
## WATER HARVESTING - Dual-Mode Multiplayer Water Reuse Game
## ═══════════════════════════════════════════════════════════════════
## Theme: "Rainwater Collection & Filtration" 🌧️💧
## 
## DUAL-MODE GAMEPLAY (Random Assignment Each Game):
## - MODE 1 (Collector): Catch falling clean water drops with bucket
##   → Adds to shared water tank (+1 point per drop)
## - MODE 2 (Filter): Tap dirt particles floating in collected water
##   → Cleans the water for points (+1 point per dirt removed)
##
## Each player gets a RANDOM mode at the start of each game!
## Modes shuffle every new game for variety!
##
## SHARED GOAL: Collect & filter enough water to reach quota
## FAIL STATE: Miss items → Lose team life
## ═══════════════════════════════════════════════════════════════════

# Player modes
enum PlayerMode {
	MODE_1_COLLECTOR,  # Catch water drops
	MODE_2_FILTER      # Remove dirt particles
}

# Difficulty settings
const DIFFICULTY_SETTINGS: Dictionary = {
	"Easy": {
		"quota": 15,
		"mode1_spawn_rate": 2.0,
		"mode1_drop_speed": 200.0,
		"mode2_spawn_rate": 2.5,
		"mode2_dirt_speed": 150.0
	},
	"Medium": {
		"quota": 25,
		"mode1_spawn_rate": 1.5,
		"mode1_drop_speed": 300.0,
		"mode2_spawn_rate": 2.0,
		"mode2_dirt_speed": 200.0
	},
	"Hard": {
		"quota": 40,
		"mode1_spawn_rate": 0.8,
		"mode1_drop_speed": 400.0,
		"mode2_spawn_rate": 1.2,
		"mode2_dirt_speed": 280.0
	}
}

# Node references
@onready var spawn_timer: Timer = $SpawnTimer
@onready var bucket: Area2D = $GameLayer/Bucket
@onready var objects_container: Node2D = $GameLayer/ObjectsContainer
@onready var hud: CanvasLayer = $UI
@onready var score_label: Label = $UI/TopBar/ScoreLabel
@onready var lives_label: Label = $UI/TopBar/LivesLabel
@onready var timer_label: Label = $UI/TopBar/TimerLabel
@onready var role_label: Label = $UI/RoleLabel
@onready var quota_bar: ProgressBar = $UI/QuotaBar

# State variables
var my_mode: PlayerMode
var current_difficulty: String = "Easy"
var current_settings: Dictionary = {}
var game_active: bool = false
var round_start_time: int = 0
var screen_size: Vector2
var game_timer: float = 60.0
var is_paused: bool = false
var timer_sync_timer: Timer = null

# Scenes
var moving_object_scene: PackedScene

func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	# Get random mode assignment from GameManager
	my_mode = _get_assigned_mode()
	print("🎮 Assigned Mode: ", "MODE 1 (Collector)" if my_mode == PlayerMode.MODE_1_COLLECTOR else "MODE 2 (Filter)")
	
	# Load difficulty
	_load_difficulty()
	
	# Setup UI
	_setup_ui()
	
	# Preload scenes
	if ResourceLoader.exists("res://scripts/multiplayer/MovingObject.tscn"):
		moving_object_scene = load("res://scripts/multiplayer/MovingObject.tscn")
	
	# Connect signals
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	if bucket and bucket.has_signal("object_caught"):
		bucket.object_caught.connect(_on_object_caught)
	
	if GameManager:
		GameManager.team_won.connect(_on_team_won)
		GameManager.team_lost.connect(_on_team_lost)
		GameManager.team_life_lost.connect(_on_life_lost)
	
	# Timer sync keeps countdown aligned across peers
	timer_sync_timer = Timer.new()
	timer_sync_timer.wait_time = 0.25
	timer_sync_timer.one_shot = false
	timer_sync_timer.autostart = false
	add_child(timer_sync_timer)
	timer_sync_timer.timeout.connect(_on_timer_sync_timeout)

	# Start game
	_start_game()

func _get_assigned_mode() -> PlayerMode:
	"""Get the randomly assigned mode for this player"""
	if GameManager and GameManager.has_method("get_my_player_mode"):
		var mode_num = GameManager.get_my_player_mode()
		return PlayerMode.MODE_1_COLLECTOR if mode_num == 1 else PlayerMode.MODE_2_FILTER
	else:
		# Fallback: host gets mode 1
		return PlayerMode.MODE_1_COLLECTOR if _is_host() else PlayerMode.MODE_2_FILTER

func _is_host() -> bool:
	return multiplayer.get_unique_id() == 1

func _load_difficulty() -> void:
	if GameManager:
		var mult: float = GameManager.difficulty_multiplier
		if mult >= 2.0:
			current_difficulty = "Extreme"
		elif mult >= 1.5:
			current_difficulty = "Hard"
		elif mult >= 1.0:
			current_difficulty = "Medium"
		else:
			current_difficulty = "Easy"
		
		if current_difficulty == "Extreme":
			current_difficulty = "Hard"
	
	current_settings = DIFFICULTY_SETTINGS[current_difficulty].duplicate()
	
	# Apply rolling window multiplier
	if GameManager:
		var mult: float = GameManager.difficulty_multiplier
		current_settings["mode1_spawn_rate"] /= mult
		current_settings["mode2_spawn_rate"] /= mult

func _setup_ui() -> void:
	# Set bucket visibility based on mode
	if bucket:
		bucket.visible = (my_mode == PlayerMode.MODE_1_COLLECTOR)
		if bucket.visible:
			bucket.position = Vector2(screen_size.x / 2, screen_size.y - 100)
	
	# Create instruction panel
	var instruction_panel = PanelContainer.new()
	instruction_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	instruction_panel.offset_top = 120
	instruction_panel.offset_bottom = 220
	instruction_panel.offset_left = 20
	instruction_panel.offset_right = -20
	
	var instruction_bg = StyleBoxFlat.new()
	instruction_bg.bg_color = Color(0, 0, 0, 0.7)
	instruction_bg.set_corner_radius_all(10)
	instruction_panel.add_theme_stylebox_override("panel", instruction_bg)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	instruction_panel.add_child(vbox)
	
	var title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	
	var controls = Label.new()
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 20)
	
	if my_mode == PlayerMode.MODE_1_COLLECTOR:
		role_label.text = "💧 MODE 1: WATER COLLECTOR"
		title.text = "Catch Clean Water Drops!"
		controls.text = "🕹️ Move mouse to position bucket"
	else:
		role_label.text = "🧹 MODE 2: WATER FILTER"
		title.text = "Remove Dirt from Water!"
		controls.text = "🕹️ Click on brown dirt particles"
	
	vbox.add_child(title)
	vbox.add_child(controls)
	hud.add_child(instruction_panel)
	
	# Hide instructions after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if instruction_panel and is_instance_valid(instruction_panel):
		var tween = create_tween()
		tween.tween_property(instruction_panel, "modulate:a", 0.0, 1.0)
		tween.tween_callback(instruction_panel.queue_free)
	
	# Setup quota bar
	quota_bar.max_value = current_settings["quota"]
	quota_bar.value = 0
	
	_update_lives_display()

func _start_game() -> void:
	game_active = true
	round_start_time = Time.get_ticks_msec()
	game_timer = 60.0

	if timer_sync_timer:
		if _is_host():
			timer_sync_timer.start()
			rpc("_sync_timer", game_timer)
		else:
			timer_sync_timer.stop()
	
	# Set quota in GameManager
	if GameManager:
		GameManager.set_minigame_quota(current_settings["quota"])
	
	# Configure spawn timer based on mode
	if my_mode == PlayerMode.MODE_1_COLLECTOR:
		spawn_timer.wait_time = current_settings["mode1_spawn_rate"]
	else:
		spawn_timer.wait_time = current_settings["mode2_spawn_rate"]
	
	spawn_timer.start()
	_update_score_display()
	
	print("🎮 Water Harvest started! Mode: ", "Collector" if my_mode == PlayerMode.MODE_1_COLLECTOR else "Filter")

func _process(delta: float) -> void:
	if not game_active or is_paused:
		return
	
	# Update timer (host keeps source of truth)
	if _is_host():
		game_timer = max(game_timer - delta, 0.0)
	if timer_label:
		timer_label.text = "⏱️ %d" % int(ceil(game_timer))
	
	# Check time limit
	if _is_host() and game_timer <= 0:
		game_active = false
		spawn_timer.stop()
		if timer_sync_timer:
			timer_sync_timer.stop()
		# Check quota
		if GameManager:
			var score = GameManager.get_global_score()
			if score >= current_settings["quota"]:
				if _is_host():
					GameManager.rpc("_announce_team_won")
			else:
				if _is_host():
					GameManager.rpc("_announce_team_lost")
		return
	
	# Mode 1: Move bucket with mouse
	if my_mode == PlayerMode.MODE_1_COLLECTOR and bucket:
		var mouse_x = get_viewport().get_mouse_position().x
		bucket.position.x = clampf(mouse_x, 50, screen_size.x - 50)

func _on_timer_sync_timeout() -> void:
	if not _is_host() or not game_active or is_paused:
		return
	rpc("_sync_timer", game_timer)

@rpc("authority", "call_local", "unreliable")
func _sync_timer(remaining_time: float) -> void:
	if _is_host():
		return
	game_timer = remaining_time

func _on_spawn_timer_timeout() -> void:
	if not game_active:
		return
	
	if my_mode == PlayerMode.MODE_1_COLLECTOR:
		_spawn_water_drop()
	else:
		_spawn_dirt_particle()

func _spawn_water_drop() -> void:
	var drop: Area2D
	
	if moving_object_scene:
		drop = moving_object_scene.instantiate()
		drop.object_type = 0  # WATER_DROP
	else:
		drop = _create_dynamic_drop()
	
	# Random X position
	drop.position = Vector2(randf_range(50, screen_size.x - 50), -50)
	
	# Set speed
	drop.fall_speed = current_settings["mode1_drop_speed"]
	
	# Connect signals
	if drop.has_signal("caught"):
		drop.caught.connect(_on_water_caught.bind(drop))
	if drop.has_signal("missed"):
		drop.missed.connect(_on_water_missed.bind(drop))
	
	if objects_container:
		objects_container.add_child(drop)
	else:
		add_child(drop)

func _spawn_dirt_particle() -> void:
	var dirt: Area2D
	
	if moving_object_scene:
		dirt = moving_object_scene.instantiate()
		dirt.object_type = 1  # DIRT
	else:
		dirt = _create_dynamic_dirt()
	
	# Random position (floating from left to right)
	var start_y = randf_range(100, screen_size.y - 200)
	dirt.position = Vector2(-50, start_y)
	
	# Set horizontal movement speed
	dirt.horizontal_speed = current_settings["mode2_dirt_speed"]
	dirt.fall_speed = 0.0  # No falling, just horizontal
	
	# Connect signals
	if dirt.has_signal("destroyed"):
		dirt.destroyed.connect(_on_dirt_removed.bind(dirt))
	if dirt.has_signal("missed"):
		dirt.missed.connect(_on_dirt_missed.bind(dirt))
	
	if objects_container:
		objects_container.add_child(dirt)
	else:
		add_child(dirt)

func _create_dynamic_drop() -> Area2D:
	var drop = Area2D.new()
	drop.name = "WaterDrop"
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	drop.add_child(collision)
	
	var visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -20), Vector2(15, -5), Vector2(15, 10),
		Vector2(0, 20), Vector2(-15, 10), Vector2(-15, -5)
	])
	visual.color = Color(0.3, 0.6, 1.0, 0.9)  # Blue water
	drop.add_child(visual)
	
	# Add script properties
	drop.set_meta("fall_speed", current_settings["mode1_drop_speed"])
	drop.set_meta("object_type", 0)
	
	return drop

func _create_dynamic_dirt() -> Area2D:
	var dirt = Area2D.new()
	dirt.name = "Dirt"
	dirt.input_pickable = true
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15.0
	collision.shape = shape
	dirt.add_child(collision)
	
	var visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-15, -10), Vector2(-5, -15), Vector2(10, -10),
		Vector2(15, 0), Vector2(10, 12), Vector2(-5, 15), Vector2(-15, 8)
	])
	visual.color = Color(0.4, 0.3, 0.1, 1.0)  # Brown dirt
	dirt.add_child(visual)
	
	dirt.set_meta("horizontal_speed", current_settings["mode2_dirt_speed"])
	dirt.set_meta("object_type", 1)
	
	# Enable click detection
	dirt.input_event.connect(func(_viewport, event, _shape_idx):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_dirt_removed(dirt)
	)
	
	return dirt

func _on_object_caught(obj: Area2D) -> void:
	"""Called when bucket catches a water drop"""
	_on_water_caught(obj)

func _on_water_caught(drop: Area2D) -> void:
	print("💧 Water drop caught!")
	if GameManager:
		GameManager.rpc("submit_score", 1)
		_update_score_display()
	drop.queue_free()

func _on_water_missed(drop: Area2D) -> void:
	print("💔 Missed water drop!")
	if GameManager:
		GameManager.rpc("report_damage")
	drop.queue_free()

func _on_dirt_removed(dirt: Area2D) -> void:
	print("🧹 Dirt particle removed!")
	if GameManager:
		GameManager.rpc("submit_score", 1)
		_update_score_display()
	dirt.queue_free()

func _on_dirt_missed(dirt: Area2D) -> void:
	print("💔 Missed dirt particle!")
	if GameManager:
		GameManager.rpc("report_damage")
	dirt.queue_free()

func _update_score_display() -> void:
	var global_score = GameManager.get_global_score() if GameManager else 0
	score_label.text = "💧 Water: %d / %d" % [global_score, current_settings["quota"]]
	quota_bar.value = global_score

func _update_lives_display() -> void:
	if GameManager:
		lives_label.text = "❤️".repeat(GameManager.team_lives)

func _on_life_lost(_remaining: int) -> void:
	_update_lives_display()

func _on_team_won() -> void:
	game_active = false
	spawn_timer.stop()
	if timer_sync_timer:
		timer_sync_timer.stop()
	
	# Record round time (only host)
	if _is_host() and GameManager:
		var round_time_sec = float(Time.get_ticks_msec() - round_start_time) / 1000.0
		GameManager.add_round_time(round_time_sec)
		GameManager.minigames_played_this_session += 1
	
	_show_result_screen(true)
	await get_tree().create_timer(2.0).timeout
	
	if GameManager and _is_host():
		GameManager.rpc("_load_next_multiplayer_minigame")

func _on_team_lost() -> void:
	game_active = false
	spawn_timer.stop()
	if timer_sync_timer:
		timer_sync_timer.stop()
	
	_show_result_screen(false)
	await get_tree().create_timer(2.0).timeout
	
	if GameManager and _is_host():
		if GameManager.team_lives > 0:
			GameManager.rpc("_load_next_multiplayer_minigame")
		else:
			GameManager.rpc("_show_multiplayer_final_results")

func _show_result_screen(victory: bool) -> void:
	var result = Control.new()
	result.set_anchors_preset(Control.PRESET_FULL_RECT)
	result.z_index = 100
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0.5, 0, 0.8) if victory else Color(0.5, 0, 0, 0.8)
	result.add_child(bg)
	
	var label = Label.new()
	label.text = "🏆 TEAM WINS!" if victory else "💀 GAME OVER"
	label.add_theme_font_size_override("font_size", 72)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	result.add_child(label)
	
	hud.add_child(result)
