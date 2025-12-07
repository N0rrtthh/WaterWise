extends Node2D
class_name MiniGame_Rain

## ═══════════════════════════════════════════════════════════════════
## MINIGAME RAIN - ASYMMETRIC 2-PLAYER CO-OP TEMPLATE
## ═══════════════════════════════════════════════════════════════════
## P1 (Host/Collector): Catches water drops → +1 point
## P2 (Client/User): Destroys leaves → +1 point
## Miss a drop/leaf → Team loses 1 life
## Goal: Reach LEVEL_QUOTA (20 points) before lives run out
## 
## Spawn Rate Formula: Timer.wait_time = BASE_SPAWN_INTERVAL / difficulty_multiplier
## ═══════════════════════════════════════════════════════════════════

signal round_completed(success: bool)
signal score_updated(new_score: int)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONSTANTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const BASE_SPAWN_INTERVAL: float = 2.0  # seconds
const DROP_SCENE: String = "res://scenes/minigames/objects/Drop.tscn"
const LEAF_SCENE: String = "res://scenes/minigames/objects/Leaf.tscn"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NODES (assign in scene or via @onready)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@onready var spawn_timer: Timer = $SpawnTimer
@onready var drop_container: Node2D = $DropContainer
@onready var leaf_container: Node2D = $LeafContainer
@onready var score_label: Label = $UI/ScoreLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var role_label: Label = $UI/RoleLabel

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var local_score: int = 0
var round_start_time: float = 0.0
var is_game_active: bool = false
var drop_scene: PackedScene = null
var leaf_scene: PackedScene = null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	# Load scenes
	if ResourceLoader.exists(DROP_SCENE):
		drop_scene = load(DROP_SCENE)
	if ResourceLoader.exists(LEAF_SCENE):
		leaf_scene = load(LEAF_SCENE)
	
	# Connect signals
	if spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	GameManager.team_won.connect(_on_team_won)
	GameManager.team_lost.connect(_on_team_lost)
	GameManager.team_life_lost.connect(_on_life_lost)
	
	# Display player role
	_update_role_display()
	
	# Start game
	_start_round()

func _update_role_display() -> void:
	"""Show player's role based on host/client status"""
	if role_label:
		if GameManager.is_host:
			role_label.text = "🌧️ Collector - Catch the Drops!"
		else:
			role_label.text = "🍃 User - Destroy the Leaves!"

func _start_round() -> void:
	"""Initialize and start the game round"""
	local_score = 0
	round_start_time = Time.get_ticks_msec()
	is_game_active = true
	
	# Calculate spawn interval based on difficulty
	# Formula: Timer.wait_time = BASE_SPAWN_INTERVAL / difficulty_multiplier
	var spawn_interval: float = GameManager.get_spawn_interval(BASE_SPAWN_INTERVAL)
	
	if spawn_timer:
		spawn_timer.wait_time = spawn_interval
		spawn_timer.start()
	
	_update_ui()
	
	print("🎮 Rain Minigame started!")
	print("   Role: ", "Host (Collector)" if GameManager.is_host else "Client (User)")
	print("   Spawn interval: ", spawn_interval, "s")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SPAWNING LOGIC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_spawn_timer_timeout() -> void:
	"""Spawn objects based on player role"""
	if not is_game_active:
		return
	
	# Only host spawns objects and syncs to clients
	if GameManager.is_host:
		_spawn_objects_as_host()

func _spawn_objects_as_host() -> void:
	"""Host spawns both Drops and Leaves, syncs to clients"""
	var screen_width: float = get_viewport_rect().size.x
	
	# Spawn a Drop (for Host to catch)
	var drop_x: float = randf_range(50.0, screen_width - 50.0)
	rpc("_spawn_drop", drop_x)
	
	# Spawn a Leaf (for Client to destroy)
	var leaf_x: float = randf_range(50.0, screen_width - 50.0)
	rpc("_spawn_leaf", leaf_x)

@rpc("authority", "call_local", "reliable")
func _spawn_drop(x_pos: float) -> void:
	"""Spawn a water drop at given x position"""
	if not drop_scene:
		print("⚠️ Drop scene not loaded!")
		return
	
	var drop: Node2D = drop_scene.instantiate()
	drop.position = Vector2(x_pos, -50.0)  # Start above screen
	drop.name = "Drop_" + str(Time.get_ticks_msec())
	
	# Connect signals
	if drop.has_signal("collected"):
		drop.collected.connect(_on_drop_collected)
	if drop.has_signal("missed"):
		drop.missed.connect(_on_drop_missed)
	
	if drop_container:
		drop_container.add_child(drop)
	else:
		add_child(drop)
	
	print("💧 Drop spawned at x=", x_pos)

@rpc("authority", "call_local", "reliable")
func _spawn_leaf(x_pos: float) -> void:
	"""Spawn a leaf at given x position"""
	if not leaf_scene:
		print("⚠️ Leaf scene not loaded!")
		return
	
	var leaf: Node2D = leaf_scene.instantiate()
	leaf.position = Vector2(x_pos, -50.0)  # Start above screen
	leaf.name = "Leaf_" + str(Time.get_ticks_msec())
	
	# Connect signals
	if leaf.has_signal("destroyed"):
		leaf.destroyed.connect(_on_leaf_destroyed)
	if leaf.has_signal("missed"):
		leaf.missed.connect(_on_leaf_missed)
	
	if leaf_container:
		leaf_container.add_child(leaf)
	else:
		add_child(leaf)
	
	print("🍃 Leaf spawned at x=", x_pos)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INPUT HANDLING (Asymmetric)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _input(event: InputEvent) -> void:
	if not is_game_active:
		return
	
	# Handle touch/click
	if event is InputEventMouseButton and event.pressed:
		_handle_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)

func _handle_tap(tap_position: Vector2) -> void:
	"""Process tap based on player role"""
	if GameManager.is_host:
		# Host tries to catch drops
		_try_catch_drop(tap_position)
	else:
		# Client tries to destroy leaves
		_try_destroy_leaf(tap_position)

func _try_catch_drop(tap_pos: Vector2) -> void:
	"""Host attempts to catch a water drop"""
	var drops: Array = drop_container.get_children() if drop_container else get_tree().get_nodes_in_group("drops")
	
	for drop in drops:
		if not is_instance_valid(drop):
			continue
		
		# Check if tap is within drop's area (simple radius check)
		var distance: float = tap_pos.distance_to(drop.global_position)
		if distance < 60.0:  # 60 pixel radius
			# Caught the drop!
			_on_drop_collected(drop)
			drop.queue_free()
			return

func _try_destroy_leaf(tap_pos: Vector2) -> void:
	"""Client attempts to destroy a leaf"""
	var leaves: Array = leaf_container.get_children() if leaf_container else get_tree().get_nodes_in_group("leaves")
	
	for leaf in leaves:
		if not is_instance_valid(leaf):
			continue
		
		# Check if tap is within leaf's area
		var distance: float = tap_pos.distance_to(leaf.global_position)
		if distance < 60.0:
			# Destroyed the leaf!
			_on_leaf_destroyed(leaf)
			leaf.queue_free()
			return

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SCORING & DAMAGE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_drop_collected(_drop: Node = null) -> void:
	"""Host caught a drop - add to G-Counter"""
	if not GameManager.is_host:
		return  # Only host handles drop collection
	
	local_score += 1
	GameManager.submit_score.rpc(1)  # G-Counter increment
	score_updated.emit(GameManager.get_global_score())
	_update_ui()
	
	print("💧 Drop caught! Local: ", local_score)

func _on_leaf_destroyed(_leaf: Node = null) -> void:
	"""Client destroyed a leaf - add to G-Counter"""
	if GameManager.is_host:
		return  # Only client handles leaf destruction
	
	local_score += 1
	GameManager.submit_score.rpc(1)  # G-Counter increment
	score_updated.emit(GameManager.get_global_score())
	_update_ui()
	
	print("🍃 Leaf destroyed! Local: ", local_score)

func _on_drop_missed(_drop: Node = null) -> void:
	"""A drop was missed - team loses life"""
	if GameManager.is_host:
		GameManager.report_damage.rpc()  # Only host reports damage
	print("❌ Drop missed!")

func _on_leaf_missed(_leaf: Node = null) -> void:
	"""A leaf was missed - team loses life"""
	if not GameManager.is_host:
		GameManager.report_damage.rpc()  # Client reports their miss
	print("❌ Leaf missed!")

func _on_life_lost(remaining: int) -> void:
	"""Update UI when team loses a life"""
	_update_ui()
	
	# Visual feedback
	if has_node("AnimationPlayer"):
		get_node("AnimationPlayer").play("life_lost")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WIN/LOSE CONDITIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_team_won() -> void:
	"""Team reached the quota!"""
	is_game_active = false
	spawn_timer.stop()
	
	# Calculate round time for Rolling Window
	var round_time: float = (Time.get_ticks_msec() - round_start_time) / 1000.0
	
	print("🎉 Team Won! Round time: ", round_time, "s")
	
	round_completed.emit(true)
	
	# Show victory screen
	_show_result(true)

func _on_team_lost() -> void:
	"""Team ran out of lives!"""
	is_game_active = false
	spawn_timer.stop()
	
	print("💀 Team Lost!")
	
	round_completed.emit(false)
	
	# Show defeat screen
	_show_result(false)

func _show_result(is_victory: bool) -> void:
	"""Display end-of-round result"""
	# Clear remaining objects
	for child in drop_container.get_children():
		child.queue_free()
	for child in leaf_container.get_children():
		child.queue_free()
	
	# Show result popup/screen
	if has_node("UI/ResultPanel"):
		var panel: Control = get_node("UI/ResultPanel")
		panel.visible = true
		
		var title_label: Label = panel.get_node_or_null("Title")
		if title_label:
			title_label.text = "🎉 Victory!" if is_victory else "💀 Game Over"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UI UPDATES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _update_ui() -> void:
	"""Refresh all UI elements"""
	if score_label:
		var global_score: int = GameManager.get_global_score()
		score_label.text = "Score: %d / %d" % [global_score, GameManager.LEVEL_QUOTA]
	
	if lives_label:
		lives_label.text = "Lives: " + "❤️".repeat(GameManager.team_lives) + "🖤".repeat(GameManager.MAX_TEAM_LIVES - GameManager.team_lives)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLEANUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _exit_tree() -> void:
	"""Disconnect signals when scene is removed"""
	if GameManager.team_won.is_connected(_on_team_won):
		GameManager.team_won.disconnect(_on_team_won)
	if GameManager.team_lost.is_connected(_on_team_lost):
		GameManager.team_lost.disconnect(_on_team_lost)
	if GameManager.team_life_lost.is_connected(_on_life_lost):
		GameManager.team_life_lost.disconnect(_on_life_lost)
