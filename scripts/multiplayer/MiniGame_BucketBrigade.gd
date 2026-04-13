class_name MiniGameBucketBrigade
extends Node2D

## ═══════════════════════════════════════════════════════════════════
## MINIGAME_BUCKET_BRIGADE.GD - Multiplayer Bucket Passing Game
## ═══════════════════════════════════════════════════════════════════
## Theme: "Bucket Brigade" 🪣
## 
## ASYMMETRIC GAMEPLAY:
## - Player 1 (Host): Fills buckets from tap by clicking
## - Player 2 (Client): Empties buckets into tank by clicking
##
## G-Counter: Score when P2 successfully empties a full bucket
## ═══════════════════════════════════════════════════════════════════

signal game_won()
signal game_lost()
signal score_updated(new_score: int)

const DIFFICULTY_SETTINGS: Dictionary = {
	"Easy": {
		"quota": 12,
		"fill_time": 3.0,
		"empty_time": 2.0,
		"bucket_count": 3
	},
	"Medium": {
		"quota": 20,
		"fill_time": 2.0,
		"empty_time": 1.5,
		"bucket_count": 4
	},
	"Hard": {
		"quota": 30,
		"fill_time": 1.5,
		"empty_time": 1.0,
		"bucket_count": 5
	}
}

@onready var hud: CanvasLayer = $UI
@onready var score_label: Label = $UI/TopBar/ScoreLabel
@onready var lives_label: Label = $UI/TopBar/LivesLabel
@onready var timer_label: Label = $UI/TopBar/TimerLabel
@onready var role_label: Label = $UI/RoleLabel
@onready var quota_bar: ProgressBar = $UI/QuotaBar
@onready var buckets_container: Node2D = $BucketsLayer

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

var buckets: Array[Dictionary] = []  # {node: Control, fill_level: float, status: String}

func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	# Verify multiplayer is active
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		push_error("❌ Multiplayer not active! Returning to lobby...")
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
		return
	
	is_player_one = (multiplayer.get_unique_id() == 1)
	
	_load_difficulty()
	_setup_role_ui()
	_create_buckets()
	
	if GameManager:
		GameManager.team_won.connect(_on_team_won)
		GameManager.team_lost.connect(_on_team_lost)
		GameManager.team_life_lost.connect(_on_life_lost)
	
	# Connect NetworkManager resource transfer signal for interconnected gameplay
	if NetworkManager and NetworkManager.has_signal("resource_sent"):
		NetworkManager.resource_sent.connect(_on_resource_received)
	
	_create_pause_ui()
	_start_game()

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
		role_label.text = "🚠 PLAYER 1: FILLER"
		title_label.text = "YOUR ROLE: Fill Empty Buckets!"
		controls_label.text = "🕹️ CONTROLS: Click on EMPTY buckets to fill them with water"
	else:
		role_label.text = "🪣 PLAYER 2: EMPTIER"
		title_label.text = "YOUR ROLE: Empty Full Buckets!"
		controls_label.text = "🕹️ CONTROLS: Click on FULL buckets to empty them and score points"
	
	instruction_vbox.add_child(title_label)
	instruction_vbox.add_child(controls_label)
	hud.add_child(instruction_panel)
	
	# Hide instructions after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if instruction_panel:
		var fade_tween = create_tween()
		fade_tween.tween_property(instruction_panel, "modulate:a", 0.0, 1.0)
		fade_tween.tween_callback(instruction_panel.queue_free)
	
	quota_bar.max_value = current_settings["quota"]
	quota_bar.value = 0
	_update_lives_display()

func _create_buckets() -> void:
	var bucket_count: int = current_settings["bucket_count"]
	var spacing: float = screen_size.x / (bucket_count + 1)
	
	for i in range(bucket_count):
		var bucket_control = Control.new()
		bucket_control.custom_minimum_size = Vector2(80, 100)
		bucket_control.position = Vector2(spacing * (i + 1) - 40, screen_size.y / 2)
		
		var bucket_visual = ColorRect.new()
		bucket_visual.color = Color(0.3, 0.3, 0.3)
		bucket_visual.size = Vector2(80, 100)
		bucket_control.add_child(bucket_visual)
		
		var fill_rect = ColorRect.new()
		fill_rect.color = Color(0.3, 0.6, 1.0)
		fill_rect.size = Vector2(76, 0)
		fill_rect.position = Vector2(2, 98)
		fill_rect.name = "Fill"
		bucket_visual.add_child(fill_rect)
		
		var status_label = Label.new()
		status_label.text = "Empty"
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		status_label.add_theme_color_override("font_outline_color", Color.BLACK)
		status_label.add_theme_constant_override("outline_size", 4)
		bucket_control.add_child(status_label)
		
		var button = Button.new()
		button.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.flat = true
		button.pressed.connect(_on_bucket_clicked.bind(i))
		bucket_control.add_child(button)
		
		buckets_container.add_child(bucket_control)
		
		buckets.append({
			"node": bucket_control,
			"fill_level": 0.0,
			"status": "empty",
			"visual": fill_rect,
			"label": status_label
		})

func _on_bucket_clicked(index: int) -> void:
	if not game_active or is_paused:
		return
	
	var bucket = buckets[index]
	
	if is_player_one:
		# P1 fills empty buckets
		if bucket["status"] == "empty":
			bucket["status"] = "filling"
			# Sync to all clients
			rpc("_start_fill_bucket", index)
	else:
		# P2 empties full buckets
		if bucket["status"] == "full":
			bucket["status"] = "emptying"
			# Sync to host and all clients
			rpc("_start_empty_bucket", index)

@rpc("any_peer", "call_local", "reliable")
func _start_fill_bucket(index: int) -> void:
	if index >= buckets.size():
		return
	buckets[index]["status"] = "filling"
	# RESOURCE TRANSFER: P1 starts filling, notify P2
	if is_player_one and NetworkManager and NetworkManager.has_method("send_resource"):
		NetworkManager.send_resource("filled_bucket", 1, 1.0)
		print("📤 Notified partner of bucket filling")
	_fill_bucket_over_time(index)

func _fill_bucket_over_time(index: int) -> void:
	var bucket = buckets[index]
	var fill_time = current_settings["fill_time"]
	
	var tween = create_tween()
	tween.tween_method(func(val): bucket["fill_level"] = val, bucket["fill_level"], 1.0, fill_time)
	tween.tween_callback(func():
		bucket["status"] = "full"
		rpc("_sync_bucket_state", index, "full", 1.0)
	)

@rpc("any_peer", "call_local", "reliable")
func _start_empty_bucket(index: int) -> void:
	if index >= buckets.size():
		return
	buckets[index]["status"] = "emptying"
	_empty_bucket_over_time(index)

func _empty_bucket_over_time(index: int) -> void:
	var bucket = buckets[index]
	var empty_time = current_settings["empty_time"]
	
	var tween = create_tween()
	tween.tween_method(func(val): bucket["fill_level"] = val, bucket["fill_level"], 0.0, empty_time)
	tween.tween_callback(func():
		bucket["status"] = "empty"
		rpc("_sync_bucket_state", index, "empty", 0.0)
		
		# Score point for successful emptying
		local_score += 1
		if GameManager:
			GameManager.rpc("submit_score", 1)
		rpc("_sync_score_update")
	)

@rpc("any_peer", "call_local", "reliable")
func _sync_bucket_state(index: int, status: String, fill_level: float) -> void:
	if index < buckets.size():
		buckets[index]["status"] = status
		buckets[index]["fill_level"] = fill_level

func _on_resource_received(from_player: int, resource_type: String, _amount: int, _quality: float) -> void:
	"""Receive resources from partner - creates interconnected gameplay"""
	if resource_type == "filled_bucket" and not is_player_one:
		# P2 receives notification when P1 fills buckets
		print("📥 Received filled bucket notification from P%d" % from_player)
		# Visual feedback could be added here

@rpc("any_peer", "call_local", "reliable")
func _sync_score_update() -> void:
	_update_score_display()

func _process(delta: float) -> void:
	if not game_active or is_paused:
		return
	
	# Update bucket visuals
	for bucket in buckets:
		var fill_rect = bucket["visual"]
		var target_height = bucket["fill_level"] * 96.0
		fill_rect.size.y = target_height
		fill_rect.position.y = 98.0 - target_height
		
		if bucket.has("label"):
			var status = bucket["status"]
			if status == "filling":
				bucket["label"].text = "Filling\n%d%%" % (bucket["fill_level"] * 100)
			elif status == "emptying":
				bucket["label"].text = "Emptying\n%d%%" % (bucket["fill_level"] * 100)
			elif status == "full":
				bucket["label"].text = "FULL!"
			else:
				bucket["label"].text = "Empty"
	
	game_timer -= delta
	if timer_label:
		timer_label.text = "⏱️ " + str(int(max(0, game_timer)))
	
	if game_timer <= 0 and game_active:
		game_active = false
		var global_score: int = GameManager.get_global_score() if GameManager else local_score
		if global_score >= current_settings["quota"]:
			if GameManager and is_player_one:
				GameManager.rpc("_announce_team_won")
		else:
			if GameManager and is_player_one:
				GameManager.rpc("_announce_team_lost")

func _update_lives_display() -> void:
	if GameManager:
		lives_label.text = "❤️".repeat(GameManager.team_lives)

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

func _update_score_display() -> void:
	var global_score: int = GameManager.get_global_score() if GameManager else local_score
	score_label.text = "🪣 Score: %d / %d" % [global_score, current_settings["quota"]]
	quota_bar.value = global_score
	score_updated.emit(global_score)
	
	# Check if quota reached (host only)
	if is_player_one and game_active and global_score >= current_settings["quota"]:
		print("🎯 Quota reached! Score: %d >= %d" % [global_score, current_settings["quota"]])
		game_active = false
		if GameManager:
			GameManager.rpc("_announce_team_won")

func _on_team_won() -> void:
	game_active = false
	game_won.emit()
	
	# Record round time for rolling window (only host)
	if GameManager and is_player_one:
		var round_time_ms: int = Time.get_ticks_msec() - round_start_time
		var round_time_sec: float = float(round_time_ms) / 1000.0
		GameManager.add_round_time(round_time_sec)
		GameManager.minigames_played_this_session += 1
		print("📊 [Rolling Window] Round completed in %.2fs" % round_time_sec)
	
	_show_result_screen(true)
	await get_tree().create_timer(2.0).timeout
	
	if GameManager and GameManager.is_host:
		GameManager.rpc("_load_next_multiplayer_minigame")

func _on_team_lost() -> void:
	game_active = false
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
	label.text = "🏆 TEAM WINS!" if victory else "💀 GAME OVER"
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
	pause_button.text = "⏸"
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
	pause_button.text = "▶"
	if NetworkManager:
		NetworkManager.rpc("sync_pause_state", true)
	print("⏸ Game paused by local player")

func _on_resume_pressed() -> void:
	if not is_paused:
		return
	is_paused = false
	get_tree().paused = false
	pause_menu.visible = false
	pause_button.text = "⏸"
	if NetworkManager:
		NetworkManager.rpc("sync_pause_state", false)
	print("▶ Game resumed by local player")

func _on_exit_pressed() -> void:
	get_tree().paused = false
	is_paused = false
	game_active = false
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
		pause_button.text = "▶"
	print("⏸ Game paused by remote player")

func _on_remote_resume() -> void:
	is_paused = false
	get_tree().paused = false
	if pause_menu:
		pause_menu.visible = false
	if pause_button:
		pause_button.text = "⏸"
	print("▶ Game resumed by remote player")
