extends Node

## ═══════════════════════════════════════════════════════════════════
## MULTIPLAYER COORDINATOR
## ═══════════════════════════════════════════════════════════════════
## Coordinates round flow, transitions, and game over in multiplayer
## Add this as a child node to multiplayer minigames
## ═══════════════════════════════════════════════════════════════════

signal both_players_completed()

var players_completed: Dictionary = {}  # {peer_id: bool}
var round_active: bool = false
var round_transition_scene: PackedScene = null
var game_over_scene: PackedScene = null

func _ready() -> void:
	# Connect NetworkManager signals
	if NetworkManager:
		NetworkManager.round_completed.connect(_on_round_completed)
		NetworkManager.team_lives_updated.connect(_on_team_lives_updated)
	
	# Preload scenes
	if ResourceLoader.exists("res://scenes/ui/RoundTransition.tscn"):
		round_transition_scene = load("res://scenes/ui/RoundTransition.tscn")
	
	if ResourceLoader.exists("res://scenes/ui/MultiplayerGameOver.tscn"):
		game_over_scene = load("res://scenes/ui/MultiplayerGameOver.tscn")

func start_round() -> void:
	# Mark round as started
	round_active = true
	players_completed.clear()
	print("[Coordinator] Round started")

func report_completion(success: bool) -> void:
	# Report that local player has completed their task
	if not round_active:
		return
	
	var my_id = multiplayer.get_unique_id()
	players_completed[my_id] = success
	
	print("[Coordinator] Player %d completed (%s)" % [my_id, "Success" if success else "Failed"])
	
	# Notify other players
	rpc("_report_completion_remote", my_id, success)
	
	# Check if both completed
	_check_both_completed()

@rpc("any_peer", "reliable")
func _report_completion_remote(peer_id: int, success: bool) -> void:
	# Receive completion report from remote player
	players_completed[peer_id] = success
	print("[Coordinator] Player %d completed remotely (%s)" % [peer_id, "Success" if success else "Failed"])
	
	_check_both_completed()

func _check_both_completed() -> void:
	# Check if both players have completed
	if players_completed.size() < 2:
		return  # Still waiting for other player
	
	# Both players completed
	round_active = false
	
	# Check if both succeeded
	var both_succeeded = true
	for success in players_completed.values():
		if not success:
			both_succeeded = false
			break
	
	print("[Coordinator] Both players completed - %s" % ("Both succeeded" if both_succeeded else "At least one failed"))
	
	# If someone failed, deduct life (only host does this)
	if not both_succeeded and NetworkManager.is_server():
		NetworkManager.lose_life()
	
	# Emit signal
	both_players_completed.emit()
	
	# Host completes the round
	if NetworkManager.is_server():
		await get_tree().create_timer(1.0).timeout
		NetworkManager.complete_round()

func _on_round_completed(p1_score: int, p2_score: int, team_total: int) -> void:
	# Round completed - show transition or game over
	print("[Coordinator] Round results: P1=%d, P2=%d, Total=%d" % [p1_score, p2_score, team_total])
	
	# Check if game over
	if NetworkManager.team_lives <= 0:
		_show_game_over(team_total, NetworkManager.rounds_survived, p1_score, p2_score)
	else:
		_show_round_transition(p1_score, p2_score, team_total)

func _show_round_transition(p1_score: int, p2_score: int, team_total: int) -> void:
	# Show transition screen between rounds
	if not round_transition_scene:
		_load_next_round()
		return
	
	var transition = round_transition_scene.instantiate()
	get_tree().current_scene.add_child(transition)
	
	# Get next level set info
	var next_set = LevelSets.get_random_level_set() if LevelSets else {}
	var next_roles = {
		1: next_set.get("player1_role", "Player 1"),
		2: next_set.get("player2_role", "Player 2")
	}
	
	transition.show_results(
		p1_score,
		p2_score,
		team_total,
		NetworkManager.team_lives,
		NetworkManager.rounds_survived,
		next_roles
	)
	
	# Wait for transition complete
	await transition.transition_complete
	transition.queue_free()
	
	# Load next round
	_load_next_round()

func _load_next_round() -> void:
	# Load next random level set (host only)
	if not NetworkManager.is_server():
		return
	
	# Reset G-Counter for next round
	NetworkManager.reset_g_counter()
	
	# Validate LevelSets availability
	if not LevelSets or LevelSets.get_all_level_sets().is_empty():
		push_error("LevelSets not available or has no level sets!")
		return
	
	var level_set = LevelSets.get_random_level_set()
	
	# Update roles
	NetworkManager.player_roles = {
		1: level_set["player1_role"],
		2: level_set["player2_role"]
	}
	
	print("[Coordinator] Loading next round: %s" % level_set["name"])
	
	# Load appropriate scene for each player
	rpc("_load_level_set_games", level_set)

@rpc("authority", "call_local", "reliable")
func _load_level_set_games(level_set: Dictionary) -> void:
	# Load the correct game scene for each player
	var my_player_num = NetworkManager.get_local_player_num()
	var my_game_scene: String
	
	if my_player_num == 1:
		my_game_scene = level_set["player1_game"]
	else:
		my_game_scene = level_set["player2_game"]
	
	print("[Coordinator] Loading game: %s" % my_game_scene)
	
	if ResourceLoader.exists(my_game_scene):
		get_tree().change_scene_to_file(my_game_scene)
	else:
		push_error("Game scene not found: " + my_game_scene)

func _show_game_over(final_score: int, rounds: int, p1_score: int, p2_score: int) -> void:
	# Show game over screen
	if not game_over_scene:
		# Fallback: return to lobby
		if NetworkManager:
			NetworkManager.return_to_lobby()
		return
	
	var game_over = game_over_scene.instantiate()
	get_tree().current_scene.add_child(game_over)
	game_over.show_game_over(final_score, rounds, p1_score, p2_score)

func _on_team_lives_updated(remaining_lives: int) -> void:
	# Team lives updated
	if remaining_lives <= 0:
		print("[Coordinator] GAME OVER - Team ran out of lives!")
		# Game over will be shown when round completes
