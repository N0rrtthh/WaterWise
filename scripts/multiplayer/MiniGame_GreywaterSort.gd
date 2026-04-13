class_name MiniGameGreywaterSort
extends Node2D

## ═══════════════════════════════════════════════════════════════════
## GREYWATER SORTING - Dual-Mode Water Reuse Game
## ═══════════════════════════════════════════════════════════════════
## Theme: "Greywater Collection & Reuse" 🚿♻️
## 
## DUAL-MODE GAMEPLAY (Random Assignment):
## - MODE 1 (Collector): Sort REUSABLE greywater by dragging to tank
##   → Bath water, dishwater = GOOD (green) → +1 point
##   → Toilet water = BAD (brown) → Lose life
## - MODE 2 (Processor): Treat collected greywater by clicking filters
##   → Click floating filters to activate → +1 point per filter
##
## Random mode assignment each game!
## ═══════════════════════════════════════════════════════════════════

enum PlayerMode { MODE_1_COLLECTOR, MODE_2_PROCESSOR }

const DIFFICULTY_SETTINGS: Dictionary = {
	"Easy": {
		"quota": 15,
		"mode1_spawn_rate": 2.5,
		"mode1_water_speed": 180.0,
		"mode1_bad_chance": 0.2,
		"mode2_spawn_rate": 3.0,
		"mode2_filter_speed": 100.0
	},
	"Medium": {
		"quota": 25,
		"mode1_spawn_rate": 1.8,
		"mode1_water_speed": 250.0,
		"mode1_bad_chance": 0.3,
		"mode2_spawn_rate": 2.2,
		"mode2_filter_speed": 150.0
	},
	"Hard": {
		"quota": 40,
		"mode1_spawn_rate": 1.0,
		"mode1_water_speed": 350.0,
		"mode1_bad_chance": 0.4,
		"mode2_spawn_rate": 1.5,
		"mode2_filter_speed": 220.0
	}
}

@onready var spawn_timer: Timer = $SpawnTimer
@onready var tank: Area2D = $GameLayer/GreywaterTank
@onready var objects_container: Node2D = $GameLayer/ObjectsContainer
@onready var hud: CanvasLayer = $UI
@onready var score_label: Label = $UI/TopBar/ScoreLabel
@onready var lives_label: Label = $UI/TopBar/LivesLabel
@onready var timer_label: Label = $UI/TopBar/TimerLabel
@onready var role_label: Label = $UI/RoleLabel
@onready var quota_bar: ProgressBar = $UI/QuotaBar

var my_mode: PlayerMode
var current_difficulty: String = "Easy"
var current_settings: Dictionary = {}
var game_active: bool = false
var round_start_time: int = 0
var screen_size: Vector2
var game_timer: float = 60.0
var dragging_water: Area2D = null
var drag_offset: Vector2 = Vector2.ZERO
var timer_sync_timer: Timer = null

func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	# Verify multiplayer is active
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		push_error("❌ Multiplayer not active! Returning to lobby...")
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
		return
	
	my_mode = _get_assigned_mode()
	_load_difficulty()
	_setup_ui()
	
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	if GameManager:
		GameManager.team_won.connect(_on_team_won)
		GameManager.team_lost.connect(_on_team_lost)
		GameManager.team_life_lost.connect(_on_life_lost)
	
	# Connect NetworkManager resource transfer signal for interconnected gameplay
	if NetworkManager and NetworkManager.has_signal("resource_sent"):
		NetworkManager.resource_sent.connect(_on_resource_received)

	# Timer sync keeps countdown consistent for both modes
	timer_sync_timer = Timer.new()
	timer_sync_timer.wait_time = 0.25
	timer_sync_timer.one_shot = false
	timer_sync_timer.autostart = false
	add_child(timer_sync_timer)
	timer_sync_timer.timeout.connect(_on_timer_sync_timeout)
	
	_start_game()

func _get_assigned_mode() -> PlayerMode:
	if GameManager and GameManager.has_method("get_my_player_mode"):
		return PlayerMode.MODE_1_COLLECTOR if GameManager.get_my_player_mode() == 1 else PlayerMode.MODE_2_PROCESSOR
	return PlayerMode.MODE_1_COLLECTOR if _is_host() else PlayerMode.MODE_2_PROCESSOR

func _is_host() -> bool:
	return multiplayer.get_unique_id() == 1

func _load_difficulty() -> void:
	if GameManager:
		var mult = GameManager.difficulty_multiplier
		current_difficulty = "Hard" if mult >= 1.5 else ("Medium" if mult >= 1.0 else "Easy")
	current_settings = DIFFICULTY_SETTINGS[current_difficulty].duplicate()
	if GameManager:
		current_settings["mode1_spawn_rate"] /= GameManager.difficulty_multiplier
		current_settings["mode2_spawn_rate"] /= GameManager.difficulty_multiplier

func _setup_ui() -> void:
	if tank:
		tank.visible = (my_mode == PlayerMode.MODE_1_COLLECTOR)
		tank.position = Vector2(screen_size.x / 2, screen_size.y - 100)
	
	var instruction_panel = PanelContainer.new()
	instruction_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	instruction_panel.offset_top = 120
	instruction_panel.offset_bottom = 220
	instruction_panel.offset_left = 20
	instruction_panel.offset_right = -20
	
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.7)
	bg.set_corner_radius_all(10)
	instruction_panel.add_theme_stylebox_override("panel", bg)
	
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
		role_label.text = "🚿 MODE 1: GREYWATER SORTER"
		title.text = "Sort Reusable Water!"
		controls.text = "🕹️ Drag GREEN water to tank | AVOID brown wastewater!"
	else:
		role_label.text = "⚙️ MODE 2: WATER PROCESSOR"
		title.text = "Treat Collected Greywater!"
		controls.text = "🕹️ Click on filter icons to activate"
	
	vbox.add_child(title)
	vbox.add_child(controls)
	hud.add_child(instruction_panel)
	
	await get_tree().create_timer(5.0).timeout
	if instruction_panel and is_instance_valid(instruction_panel):
		var tween = create_tween()
		tween.tween_property(instruction_panel, "modulate:a", 0.0, 1.0)
		tween.tween_callback(instruction_panel.queue_free)
	
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
	
	if GameManager:
		GameManager.set_minigame_quota(current_settings["quota"])
	
	spawn_timer.wait_time = current_settings["mode1_spawn_rate"] if my_mode == PlayerMode.MODE_1_COLLECTOR else current_settings["mode2_spawn_rate"]
	spawn_timer.start()
	_update_score_display()

func _process(delta: float) -> void:
	if not game_active:
		return
	
	if _is_host():
		game_timer = max(game_timer - delta, 0.0)
	timer_label.text = "⏱️ %d" % int(ceil(game_timer))

	if _is_host() and game_timer <= 0:
		game_active = false
		spawn_timer.stop()
		if timer_sync_timer:
			timer_sync_timer.stop()
		if GameManager:
			var score = GameManager.get_global_score()
			if score >= current_settings["quota"]:
				if _is_host():
					GameManager.rpc("_announce_team_won")
			else:
				if _is_host():
					GameManager.rpc("_announce_team_lost")

func _on_timer_sync_timeout() -> void:
	if not _is_host() or not game_active:
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
		_spawn_greywater()
	else:
		_spawn_filter()

func _spawn_greywater() -> void:
	var water = Area2D.new()
	water.name = "Greywater"
	water.input_pickable = true
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 60)
	collision.shape = shape
	water.add_child(collision)
	
	# Determine if good or bad water
	var is_bad = randf() < current_settings["mode1_bad_chance"]
	water.set_meta("is_bad", is_bad)
	
	var visual = ColorRect.new()
	visual.size = Vector2(40, 60)
	visual.position = Vector2(-20, -30)
	visual.color = Color(0.4, 0.3, 0.1, 0.9) if is_bad else Color(0.6, 0.8, 0.6, 0.9)
	water.add_child(visual)
	
	var label = Label.new()
	label.text = "🚽" if is_bad else "🚿"
	label.add_theme_font_size_override("font_size", 24)
	label.position = Vector2(-10, -15)
	water.add_child(label)
	
	water.position = Vector2(randf_range(50, screen_size.x - 50), -80)
	water.set_meta("fall_speed", current_settings["mode1_water_speed"])
	
	# Connect drag signals
	water.input_event.connect(func(_viewport, event, _shape_idx):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_start_dragging_water(water)
	)
	
	objects_container.add_child(water)
	
	# Movement in _physics_process
	water.set_physics_process(true)
	water.set_script(preload("res://scripts/multiplayer/FallingObject.gd"))

func _spawn_filter() -> void:
	var filter = Area2D.new()
	filter.name = "Filter"
	filter.input_pickable = true
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 25.0
	collision.shape = shape
	filter.add_child(collision)
	
	var visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-25, 0), Vector2(-15, -20), Vector2(0, -25),
		Vector2(15, -20), Vector2(25, 0), Vector2(15, 20),
		Vector2(0, 25), Vector2(-15, 20)
	])
	visual.color = Color(0.8, 0.8, 0.9, 1.0)
	filter.add_child(visual)
	
	var label = Label.new()
	label.text = "⚙️"
	label.add_theme_font_size_override("font_size", 20)
	label.position = Vector2(-10, -12)
	filter.add_child(label)
	
	var start_y = randf_range(100, screen_size.y - 200)
	filter.position = Vector2(-50, start_y)
	filter.set_meta("horizontal_speed", current_settings["mode2_filter_speed"])
	
	filter.input_event.connect(func(_viewport, event, _idx):
		if event is InputEventMouseButton and event.pressed:
			_on_filter_activated(filter)
	)
	
	objects_container.add_child(filter)
	filter.set_physics_process(true)
	filter.set_script(preload("res://scripts/multiplayer/HorizontalObject.gd"))

func _start_dragging_water(water: Area2D) -> void:
	if my_mode != PlayerMode.MODE_1_COLLECTOR:
		return
	dragging_water = water
	drag_offset = water.position - get_global_mouse_position()
	# Stop physics while dragging
	water.set_physics_process(false)

func _input(event: InputEvent) -> void:
	if not game_active or my_mode != PlayerMode.MODE_1_COLLECTOR:
		return
	
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dragging_water:
			_drop_water()
	
	if event is InputEventMouseMotion and dragging_water:
		dragging_water.position = get_global_mouse_position() + drag_offset

func _drop_water() -> void:
	if not dragging_water or not is_instance_valid(dragging_water):
		dragging_water = null
		return
	
	var is_bad = dragging_water.get_meta("is_bad", false)
	
	# Check if dropped in tank
	var dropped_in_tank = false
	if tank and tank.visible:
		var tank_rect = Rect2(tank.global_position - Vector2(50, 50), Vector2(100, 100))
		if tank_rect.has_point(dragging_water.global_position):
			dropped_in_tank = true
	
	if dropped_in_tank:
		if is_bad:
			print("☠️ Sorted BAD water into tank!")
			if GameManager:
				GameManager.rpc("report_damage")
		else:
			print("♻️ Sorted GOOD water!")
			if GameManager:
				GameManager.rpc("submit_score", 1)
				_update_score_display()
			
			# RESOURCE TRANSFER: Send sorted greywater to partner
			if NetworkManager and NetworkManager.has_method("send_resource"):
				NetworkManager.send_resource("sorted_greywater", 1, 1.0)
				print("📤 Sent sorted greywater to partner")
		
		dragging_water.queue_free()
	else:
		# Resume falling
		dragging_water.set_physics_process(true)
	
	dragging_water = null

func _on_filter_activated(filter: Area2D) -> void:
	print("⚙️ Filter activated!")
	if GameManager:
		GameManager.rpc("submit_score", 1)
		_update_score_display()
	filter.queue_free()

func _on_resource_received(from_player: int, resource_type: String, amount: int, _quality: float) -> void:
	"""Receive resources from partner - creates interconnected gameplay"""
	if resource_type == "sorted_greywater":
		print("📥 Received %d sorted greywater from P%d - partner is helping!" % [amount, from_player])
		# Partner's sorted water could provide bonus or reduce filter load

func _update_score_display() -> void:
	var score = GameManager.get_global_score() if GameManager else 0
	score_label.text = "♻️ Treated: %d / %d" % [score, current_settings["quota"]]
	quota_bar.value = score
	
	# Check if quota reached (host only)
	if _is_host() and game_active and score >= current_settings["quota"]:
		print("🎯 Quota reached! Score: %d >= %d" % [score, current_settings["quota"]])
		game_active = false
		spawn_timer.stop()
		if timer_sync_timer:
			timer_sync_timer.stop()
		if GameManager:
			GameManager.rpc("_announce_team_won")

func _update_lives_display() -> void:
	lives_label.text = "❤️".repeat(GameManager.team_lives if GameManager else 3)

func _on_life_lost(_remaining: int) -> void:
	_update_lives_display()

func _on_team_won() -> void:
	game_active = false
	spawn_timer.stop()
	if timer_sync_timer:
		timer_sync_timer.stop()
	if _is_host() and GameManager:
		var time_sec = float(Time.get_ticks_msec() - round_start_time) / 1000.0
		GameManager.add_round_time(time_sec)
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
