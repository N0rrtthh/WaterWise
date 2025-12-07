extends Node2D

## ═══════════════════════════════════════════════════════════════════
## RAINWATER HARVESTING - COOPERATIVE MINI-GAME
## ═══════════════════════════════════════════════════════════════════
## Player 1 (Collector): Position rainwater collection containers
## Player 2 (User): Use collected rainwater for appropriate purposes
## Team success: Both must complete their interdependent tasks
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NODE REFERENCES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@onready var timer_label = $UI/TimerLabel
@onready var task_label = $UI/TaskLabel
@onready var accuracy_label = $UI/AccuracyLabel
@onready var partner_status_label = $UI/PartnerStatusLabel
@onready var countdown_label = $UI/CountdownLabel

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const COUNTDOWN_TIME: int = 3

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var local_player_num: int = 0
var player_role: String = ""
var difficulty_params: Dictionary = {}

# Game state
var game_started: bool = false
var game_ended: bool = false
var time_remaining: float = 0.0
var start_time: float = 0.0
var completion_time: float = 0.0

# Performance tracking
var total_tasks: int = 5
var completed_tasks: int = 0
var errors: int = 0
var accuracy: float = 0.0

# Partner tracking
var partner_completed: bool = false
var partner_accuracy: float = 0.0

# Player 1 (Collector) specific
var containers_to_place: int = 5
var containers_placed_correctly: int = 0
var placement_spots: Array = []  # {position: Vector2, occupied: bool, correct: bool}

# Player 2 (User) specific
var water_usage_scenarios: int = 5
var correct_usages: int = 0
var available_water_volume: float = 0.0  # Depends on Player 1's collection

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	if not is_instance_valid(NetworkManager) or not NetworkManager.is_multiplayer_connected():
		push_error("Not connected to multiplayer!")
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
		return
	
	# Get local player info
	local_player_num = NetworkManager.get_local_player_num()
	player_role = NetworkManager.get_player_role(local_player_num)
	
	# Get difficulty parameters from CoopAdaptation
	if is_instance_valid(CoopAdaptation):
		difficulty_params = CoopAdaptation.get_player_parameters(local_player_num)
		_apply_difficulty_parameters()
	
	# Connect NetworkManager signals
	NetworkManager.performance_data_received.connect(_on_partner_performance_received)
	
	# Show role-specific instructions
	_show_role_instructions()
	
	# Start countdown
	_start_countdown()

func _apply_difficulty_parameters() -> void:
	"""Apply difficulty parameters from CoopAdaptation"""
	time_remaining = difficulty_params.get("time_limit", 15)
	total_tasks = difficulty_params.get("task_count", 5)
	
	print("⚙️ Difficulty: %s | Time: %ds | Tasks: %d" % [
		difficulty_params.get("difficulty", "Medium"),
		time_remaining,
		total_tasks
	])
	
	# Apply role-specific parameters
	if player_role == "Collector":
		containers_to_place = total_tasks
	elif player_role == "User":
		water_usage_scenarios = total_tasks

func _show_role_instructions() -> void:
	"""Show instructions based on player role"""
	if player_role == "Collector":
		task_label.text = "YOUR TASK: Place rainwater containers under roof gutters\nKung saan dumadaloy ang tubig-ulan mula sa bubong"
	elif player_role == "User":
		task_label.text = "YOUR TASK: Use collected rainwater for toilet/plants\nGamitin ang tubig-ulan para sa inidoro at halaman"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COUNTDOWN AND GAME START
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _start_countdown() -> void:
	"""3-second countdown before game starts"""
	countdown_label.visible = true
	
	for i in range(COUNTDOWN_TIME, 0, -1):
		countdown_label.text = str(i)
		await get_tree().create_timer(1.0).timeout
	
	countdown_label.text = "GO! / SIMULAN!"
	await get_tree().create_timer(0.5).timeout
	countdown_label.visible = false
	
	_start_game()

func _start_game() -> void:
	"""Start the actual game"""
	game_started = true
	start_time = Time.get_ticks_msec() / 1000.0
	
	# Generate game elements based on role
	if player_role == "Collector":
		_generate_collector_game()
	elif player_role == "User":
		_generate_user_game()
	
	print("🎮 Game started - Role: " + player_role)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME LOOP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _process(delta: float) -> void:
	if not game_started or game_ended:
		return
	
	# Update timer
	time_remaining -= delta
	timer_label.text = "Time: %.1fs" % max(0, time_remaining)
	
	# Check time out
	if time_remaining <= 0:
		_end_game_timeout()
	
	# Update accuracy display
	if total_tasks > 0:
		accuracy = float(completed_tasks) / float(total_tasks)
		accuracy_label.text = "Completed: %d/%d (%.0f%%)" % [completed_tasks, total_tasks, accuracy * 100]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PLAYER 1 (COLLECTOR) GAME LOGIC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _generate_collector_game() -> void:
	"""Generate container placement game for Player 1"""
	# TODO: Create visual house with gutters
	# TODO: Generate placement spots (some correct, some incorrect)
	# TODO: Allow drag-and-drop of containers
	# For now, simplified version
	print("🪣 Collector game generated: Place %d containers" % containers_to_place)

func _on_container_placed(_position: Vector2, is_correct: bool) -> void:
	"""Called when Player 1 places a container"""
	completed_tasks += 1
	
	if is_correct:
		containers_placed_correctly += 1
	else:
		errors += 1
	
	# Check if all containers placed
	if completed_tasks >= containers_to_place:
		_complete_collector_task()

func _complete_collector_task() -> void:
	"""Player 1 completed their task"""
	completion_time = (Time.get_ticks_msec() / 1000.0) - start_time
	accuracy = float(containers_placed_correctly) / float(containers_to_place)
	
	# Calculate water volume collected (affects Player 2)
	available_water_volume = containers_placed_correctly * 10.0  # 10L per container
	
	_send_performance()
	_wait_for_partner()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PLAYER 2 (USER) GAME LOGIC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _generate_user_game() -> void:
	"""Generate water usage game for Player 2"""
	# TODO: Show water usage scenarios (toilet, plants, drinking?, cooking?)
	# TODO: Player must select correct uses (not drinking/cooking)
	# For now, simplified version
	print("💧 User game generated: %d water usage scenarios" % water_usage_scenarios)
	
	# Wait to receive water volume from Player 1
	partner_status_label.text = "Waiting for collector to gather water..."

func _on_water_usage_selected(_scenario: String, is_correct: bool) -> void:
	"""Called when Player 2 selects a water usage"""
	completed_tasks += 1
	
	if is_correct:
		correct_usages += 1
	else:
		errors += 1
	
	# Check if all scenarios completed
	if completed_tasks >= water_usage_scenarios:
		_complete_user_task()

func _complete_user_task() -> void:
	"""Player 2 completed their task"""
	completion_time = (Time.get_ticks_msec() / 1000.0) - start_time
	accuracy = float(correct_usages) / float(water_usage_scenarios)
	
	_send_performance()
	_wait_for_partner()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PERFORMANCE SUBMISSION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _send_performance() -> void:
	"""Send performance data to partner via network"""
	var performance = {
		"accuracy": accuracy,
		"time": completion_time,
		"errors": errors
	}
	
	if is_instance_valid(NetworkManager):
		NetworkManager.send_performance_data(performance)
	
	# Also submit to GameManager
	if is_instance_valid(GameManager):
		GameManager.submit_coop_performance(accuracy, completion_time, errors)
	
	print("📊 Performance sent - Accuracy: %.2f, Time: %.2fs, Errors: %d" % [accuracy, completion_time, errors])

func _on_partner_performance_received(player_id: int, performance: Dictionary) -> void:
	"""Receive partner's performance"""
	if player_id == local_player_num:
		return  # Ignore own performance
	
	partner_completed = true
	partner_accuracy = performance.get("accuracy", 0.0)
	
	print("✅ Partner completed - Accuracy: %.2f" % partner_accuracy)
	
	# Update partner status
	partner_status_label.text = "Partner: COMPLETED (%.0f%%)" % (partner_accuracy * 100)
	
	# Notify GameManager
	if is_instance_valid(GameManager):
		GameManager.receive_partner_performance(player_id, performance)
	
	# Check if both completed
	if game_ended:
		_show_team_results()

func _wait_for_partner() -> void:
	"""Wait for partner to complete"""
	game_ended = true
	partner_status_label.text = "Waiting for partner..."
	
	if partner_completed:
		_show_team_results()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME END
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _end_game_timeout() -> void:
	"""Game ended due to time out"""
	if game_ended:
		return
	
	game_ended = true
	
	# Calculate partial accuracy
	if total_tasks > 0:
		accuracy = float(completed_tasks) / float(total_tasks)
	completion_time = time_remaining  # Use full time as completion time
	
	_send_performance()
	_wait_for_partner()

func _show_team_results() -> void:
	"""Show results for both players"""
	# Determine team success
	var team_success = (accuracy > 0.5 and partner_accuracy > 0.5)
	
	# Get team metrics from CoopAdaptation
	var _team_metrics = CoopAdaptation.get_team_metrics() if is_instance_valid(CoopAdaptation) else {}
	
	print("🏁 TEAM RESULT: %s" % ("SUCCESS" if team_success else "FAILED"))
	print("   Your Accuracy: %.2f" % accuracy)
	print("   Partner Accuracy: %.2f" % partner_accuracy)
	
	# TODO: Show proper results screen
	await get_tree().create_timer(3.0).timeout
	
	# Return to lobby
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIMPLIFIED GAME CONTROLS (FOR DEMONSTRATION)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _input(event: InputEvent) -> void:
	"""Simplified input for testing (replace with proper UI)"""
	if not game_started or game_ended:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			# Simulate correct action
			completed_tasks += 1
			
			if player_role == "Collector":
				containers_placed_correctly += 1
				if completed_tasks >= containers_to_place:
					_complete_collector_task()
			
			elif player_role == "User":
				correct_usages += 1
				if completed_tasks >= water_usage_scenarios:
					_complete_user_task()
		
		elif event.keycode == KEY_E:
			# Simulate error
			completed_tasks += 1
			errors += 1
			
			if completed_tasks >= total_tasks:
				if player_role == "Collector":
					_complete_collector_task()
				elif player_role == "User":
					_complete_user_task()
