class_name MiniGameLeafSort
extends Node2D

## 
## MINIGAME_LEAF_SORT.GD - Multiplayer Leaf Sorting Game
## 
## Theme: "Sort the Leaves" 
## 
## ASYMMETRIC GAMEPLAY:
## - Player 1 (Host): Catches CLEAN leaves (green) with bucket
## - Player 2 (Client): Swipes DIRTY leaves (brown) down to remove
##
## G-Counter: Both players submit scores independently
## 

signal game_won()
signal game_lost()
signal score_updated(new_score: int)

# Use same structure as Rain game
const DIFFICULTY_SETTINGS: Dictionary = {
	"Easy": {
		"quota": 20,
		"p1_spawn_rate": 2.5,
		"p1_leaf_speed": 180.0,
		"p2_spawn_rate": 2.8,
		"p2_leaf_speed": 140.0
	},
	"Medium": {
		"quota": 30,
		"p1_spawn_rate": 1.8,
		"p1_leaf_speed": 250.0,
		"p2_spawn_rate": 2.0,
		"p2_leaf_speed": 190.0
	},
	"Hard": {
		"quota": 45,
		"p1_spawn_rate": 1.2,
		"p1_leaf_speed": 350.0,
		"p2_spawn_rate": 1.4,
		"p2_leaf_speed": 260.0
	}
}

@onready var spawn_timer: Timer = $SpawnTimer
@onready var bucket: Area2D = $GameLayer/Bucket
@onready var objects_container: Node2D = $GameLayer/ObjectsContainer
@onready var hud: CanvasLayer = $UI
@onready var score_label: Label = $UI/TopBar/ScoreLabel
@onready var lives_label: Label = $UI/TopBar/LivesLabel
@onready var timer_label: Label = $UI/TopBar/TimerLabel
@onready var role_label: Label = $UI/RoleLabel
@onready var quota_bar: ProgressBar = $UI/QuotaBar

var pause_menu: Control = null
var pause_button: Button = null

var is_player_one: bool = false
var current_difficulty: String = "Easy"
var current_settings: Dictionary = {}
var game_active: bool = false
var local_score: int = 0
var round_start_time: int = 0
var screen_size: Vector2 = Vector2.ZERO
var game_timer: float = 60.0
var time_limit: float = 60.0
var is_paused: bool = false

var leaf_scene: PackedScene = null

func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	# Verify multiplayer is active
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		push_error(" Multiplayer not active! Returning to lobby...")
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
		return
	
	is_player_one = (multiplayer.get_unique_id() == 1)
	
	_load_difficulty()
	_setup_role_ui()
	_preload_scenes()
	
	if spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	if bucket and bucket.has_signal("object_caught"):
		bucket.object_caught.connect(_on_leaf_caught)
	
	if GameManager:
		GameManager.team_won.connect(_on_team_won)
		GameManager.team_lost.connect(_on_team_lost)
		GameManager.team_life_lost.connect(_on_life_lost)
	
	# Connect NetworkManager resource transfer signal for interconnected gameplay
	if NetworkManager and NetworkManager.has_signal("resource_sent"):
		NetworkManager.resource_sent.connect(_on_resource_received)
	
	_create_pause_ui()
	_start_game()

func _is_host() -> bool:
	# Helper: Check if this player is the host
	return multiplayer.get_unique_id() == 1

func _preload_scenes() -> void:
	var moving_obj_path := "res://scripts/multiplayer/MovingObject.tscn"
	if ResourceLoader.exists(moving_obj_path):
		leaf_scene = load(moving_obj_path)

func _load_difficulty() -> void:
	if GameManager:
		var mult: float = GameManager.difficulty_multiplier
		if mult >= 1.5:
			current_difficulty = "Hard"
		elif mult >= 1.0:
			current_difficulty = "Medium"
		else:
			current_difficulty = "Easy"
	
	current_settings = DIFFICULTY_SETTINGS[current_difficulty].duplicate()
	
	if GameManager:
		var mult: float = GameManager.difficulty_multiplier
		current_settings["p1_spawn_rate"] /= mult
		current_settings["p2_spawn_rate"] /= mult

func _setup_role_ui() -> void:
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
	
	if is_player_one:
		role_label.text = " PLAYER 1: COLLECTOR"
		title_label.text = "YOUR ROLE: Catch Clean Green Leaves!"
		controls_label.text = " CONTROLS: Move mouse to move bucket | Catch GREEN leaves only!"
		bucket.visible = true
	else:
		role_label.text = " PLAYER 2: CLEANER"
		title_label.text = "YOUR ROLE: Remove Dirty Brown Leaves!"
		controls_label.text = " CONTROLS: SWIPE DOWN on brown leaves to remove them"
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
	
	quota_bar.max_value = current_settings["quota"]
	quota_bar.value = 0
	_update_lives_display()

func _update_lives_display() -> void:
	if GameManager:
		lives_label.text = "".repeat(GameManager.team_lives)

func _update_quota_bar() -> void:
	if quota_bar and GameManager:
		var global_score: int = GameManager.get_global_score()
		quota_bar.value = global_score

func _start_game() -> void:
	game_active = true
	local_score = 0
	round_start_time = Time.get_ticks_msec()
	
	# Set the quota in GameManager
	if GameManager:
		GameManager.set_minigame_quota(current_settings["quota"])
	
	time_limit = 60.0
	game_timer = time_limit
	
	_update_lives_display()
	_update_score_display()
	_update_quota_bar()
	
	if is_player_one:
		spawn_timer.wait_time = current_settings["p1_spawn_rate"]
	else:
		spawn_timer.wait_time = current_settings["p2_spawn_rate"]
	
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if not game_active:
		return
	
	# Only host spawns to ensure synchronization
	if not is_player_one:
		return
	
	# Spawn both types and sync
	_spawn_clean_leaf_synced()
	_spawn_dirty_leaf_synced()

func _spawn_clean_leaf_synced() -> void:
	# HOST: Spawn clean leaf and sync
	if not _is_host():
		return
	
	var spawn_x: float = randf_range(50, screen_size.x - 50)
	var spawn_id: int = Time.get_ticks_msec()
	
	rpc("_create_clean_leaf_at", spawn_x, spawn_id)

@rpc("authority", "call_local", "reliable")
func _create_clean_leaf_at(spawn_x: float, spawn_id: int) -> void:
	# Create clean leaf (P1 only)
	if not is_player_one:
		return
	
	var leaf: Area2D
	if leaf_scene:
		leaf = leaf_scene.instantiate()
	else:
		leaf = _create_dynamic_leaf(false)
	
	leaf.position = Vector2(spawn_x, -50)
	leaf.name = "CleanLeaf_" + str(spawn_id)
	
	if leaf.has_method("setup"):
		leaf.setup(Vector2.DOWN, current_settings["p1_leaf_speed"], false)
	
	if leaf.has_signal("missed"):
		leaf.missed.connect(_on_leaf_missed)
	
	if objects_container:
		objects_container.add_child(leaf)
	else:
		add_child(leaf)

func _spawn_dirty_leaf_synced() -> void:
	# HOST: Spawn dirty leaf and sync
	if not _is_host():
		return
	
	var spawn_y: float = randf_range(100, screen_size.y - 200)
	var spawn_id: int = Time.get_ticks_msec() + 1000
	
	rpc("_create_dirty_leaf_at", spawn_y, spawn_id)

@rpc("authority", "call_local", "reliable")
func _create_dirty_leaf_at(spawn_y: float, spawn_id: int) -> void:
	# Create dirty leaf (P2 only)
	if is_player_one:
		return
	
	var leaf: Area2D
	if leaf_scene:
		leaf = leaf_scene.instantiate()
	else:
		leaf = _create_dynamic_leaf(true)
	
	leaf.position = Vector2(-50, spawn_y)
	leaf.name = "DirtyLeaf_" + str(spawn_id)
	
	if leaf.has_method("setup"):
		leaf.setup(Vector2.RIGHT, current_settings["p2_leaf_speed"], true)
	
	if leaf.has_signal("destroyed"):
		leaf.destroyed.connect(_on_leaf_destroyed)
	if leaf.has_signal("swiped_down"):
		leaf.swiped_down.connect(_on_leaf_destroyed)
	if leaf.has_signal("missed"):
		leaf.missed.connect(_on_dirty_leaf_missed)
	
	# Ensure object type is set to LEAF so it can be swiped
	if "object_type" in leaf:
		leaf.object_type = 2 # LEAF
		
	# Add visual hint for Player 2
	if not is_player_one:
		var hint_label = Label.new()
		hint_label.text = ""
		hint_label.add_theme_font_size_override("font_size", 24)
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint_label.position = Vector2(-15, -40)
		leaf.add_child(hint_label)
		
		# Pulse animation - use finite loops to avoid infinite loop error
		var pulse_tween = create_tween()
		pulse_tween.set_loops(10)  # Limited to 10 loops instead of infinite
		pulse_tween.tween_property(hint_label, "scale", Vector2(1.3, 1.3), 0.5)
		pulse_tween.tween_property(hint_label, "scale", Vector2(1.0, 1.0), 0.5)
	
	if objects_container:
		objects_container.add_child(leaf)
	else:
		add_child(leaf)

func _create_dynamic_leaf(is_dirty: bool) -> Area2D:
	var leaf: Area2D = Area2D.new()
	leaf.name = "DirtyLeaf" if is_dirty else "CleanLeaf"
	leaf.input_pickable = is_dirty
	
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 25.0
	collision.shape = shape
	leaf.add_child(collision)
	
	var visual: Polygon2D = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-25, 0), Vector2(-15, -15),
		Vector2(0, -10), Vector2(15, -15),
		Vector2(25, 0), Vector2(15, 15),
		Vector2(0, 10), Vector2(-15, 15)
	])
	visual.color = Color(0.4, 0.2, 0.1) if is_dirty else Color(0.2, 0.7, 0.3)
	leaf.add_child(visual)
	
	var script: GDScript = load("res://scripts/multiplayer/MovingObject.gd")
	if script:
		leaf.set_script(script)
		leaf.object_type = 2
	
	return leaf

func _on_leaf_caught(leaf: Area2D, _is_special: bool) -> void:
	local_score += 1
	if GameManager:
		GameManager.rpc("submit_score", 1)
		# Also update display immediately
		_update_score_display()
	
	# RESOURCE TRANSFER: P1 sends clean leaves to P2 as a "dirty leaf task"
	if NetworkManager and NetworkManager.has_method("send_resource"):
		NetworkManager.send_resource("clean_leaf", 1, 1.0)
		print(" Sent clean leaf signal to partner")
	
	# Sync to other players
	if is_player_one:
		rpc("_sync_score_update")
	leaf.queue_free()

func _on_leaf_missed(leaf: Area2D, _is_special: bool) -> void:
	if GameManager:
		GameManager.rpc("report_damage")
	leaf.queue_free()

func _on_leaf_destroyed(leaf: Area2D) -> void:
	local_score += 1
	if GameManager:
		GameManager.rpc("submit_score", 1)
		# Also update display immediately
		_update_score_display()
	
	# Sync to other players
	if not is_player_one:
		rpc("_sync_score_update")
	
	# Visual feedback for swipe
	if leaf.has_method("flash"):
		leaf.flash(Color.GREEN, 0.2)
	
	# Animate out
	var tween = create_tween()
	tween.tween_property(leaf, "scale", Vector2(0, 0), 0.2)
	tween.tween_callback(leaf.queue_free)

func _on_dirty_leaf_missed(leaf: Area2D, _is_special: bool) -> void:
	if GameManager:
		GameManager.rpc("report_damage")
	leaf.queue_free()

func _on_resource_received(
	from_player: int, resource_type: String, amount: int, _quality: float
) -> void:
	# Receive resources from partner - creates interconnected gameplay
	if resource_type == "clean_leaf" and not is_player_one:
		# P2 receives clean leaf signal from P1 and spawns a dirty leaf to clean
		print(
			"Received %d clean leaf from P%d - spawning dirty leaves to clean"
			% [amount, from_player]
		)
		for i in range(amount):
			var spawn_y: float = randf_range(100, screen_size.y - 200)
			_create_dirty_leaf_at(spawn_y, Time.get_ticks_msec() + i)

func _process(delta: float) -> void:
	if not game_active or is_paused:
		return
	
	game_timer -= delta
	if timer_label:
		timer_label.text = " " + str(int(max(0, game_timer)))
	
	if game_timer <= 0 and game_active:
		game_active = false
		spawn_timer.stop()
		var global_score: int = GameManager.get_global_score() if GameManager else local_score
		if global_score >= current_settings["quota"]:
			if GameManager and is_player_one:
				GameManager.rpc("_announce_team_won")
		else:
			if GameManager and is_player_one:
				GameManager.rpc("_announce_team_lost")
		return
	
	if is_player_one and bucket:
		var mouse_x: float = get_viewport().get_mouse_position().x
		bucket.position.x = clampf(mouse_x, 50, screen_size.x - 50)

func _update_score_display() -> void:
	var global_score: int = GameManager.get_global_score() if GameManager else local_score
	score_label.text = " Score: %d / %d" % [global_score, current_settings["quota"]]
	quota_bar.value = global_score
	score_updated.emit(global_score)
	
	# Check if quota reached (host only)
	if is_player_one and game_active and global_score >= current_settings["quota"]:
		print(" Quota reached! Score: %d >= %d" % [global_score, current_settings["quota"]])
		game_active = false
		spawn_timer.stop()
		if GameManager:
			GameManager.rpc("_announce_team_won")

@rpc("any_peer", "call_local", "reliable")
func _sync_score_update() -> void:
	_update_score_display()

func _on_team_won() -> void:
	game_active = false
	spawn_timer.stop()
	game_won.emit()
	
	# Record round time for rolling window (only host)
	if GameManager and is_player_one:
		var round_time_ms: int = Time.get_ticks_msec() - round_start_time
		var round_time_sec: float = float(round_time_ms) / 1000.0
		GameManager.add_round_time(round_time_sec)
		GameManager.minigames_played_this_session += 1
		print(" [Rolling Window] Round completed in %.2fs" % round_time_sec)
	
	_show_result_screen(true)
	await get_tree().create_timer(2.0).timeout
	
	if GameManager and GameManager.is_host:
		GameManager.rpc("_load_next_multiplayer_minigame")

func _on_team_lost() -> void:
	game_active = false
	spawn_timer.stop()
	game_lost.emit()
	
	_show_result_screen(false)
	await get_tree().create_timer(2.0).timeout
	
	if GameManager and GameManager.is_host:
		if GameManager.team_lives > 0:
			GameManager.rpc("_load_next_multiplayer_minigame")
		else:
			GameManager.rpc("_show_multiplayer_final_results")

func _on_life_lost(_remaining: int) -> void:
	_update_lives_display()

func _show_result_screen(victory: bool) -> void:
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
	
	await get_tree().create_timer(3.0).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if NetworkManager:
		NetworkManager.return_to_lobby()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _create_pause_ui() -> void:
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
	
	pause_button.add_theme_stylebox_override("normal", btn_normal)
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_on_pause_button_pressed)
	
	var top_bar = $UI/TopBar
	if top_bar:
		top_bar.add_child(pause_button)
	
	# Create pause menu
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

