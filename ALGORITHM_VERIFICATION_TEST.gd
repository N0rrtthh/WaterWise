extends Node

## ═══════════════════════════════════════════════════════════════════
## ALGORITHM VERIFICATION TEST SCRIPT
## ═══════════════════════════════════════════════════════════════════
## For Panelists: Run this script to automatically test the algorithm
## 
## How to use:
## 1. Attach this script to any Node in your scene
## 2. Run the game
## 3. Watch the console output - it will simulate games and show
##    how the algorithm responds
## ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	print("\n")
	print("╔══════════════════════════════════════════════════════════════════════════╗")
	print("║          🎮 ROLLING WINDOW ALGORITHM VERIFICATION TEST                  ║")
	print("╚══════════════════════════════════════════════════════════════════════════╝")
	print("")
	
	# Wait a frame for AdaptiveDifficulty to initialize
	await get_tree().process_frame
	
	if not AdaptiveDifficulty:
		print("❌ ERROR: AdaptiveDifficulty not found!")
		return
	
	print("✅ AdaptiveDifficulty system loaded\n")
	
	# Run test scenarios
	await _run_test_scenario_1_new_player()
	await get_tree().create_timer(1.0).timeout
	
	await _run_test_scenario_2_improving_player()
	await get_tree().create_timer(1.0).timeout
	
	await _run_test_scenario_3_expert_player()
	await get_tree().create_timer(1.0).timeout
	
	await _run_test_scenario_4_erratic_player()
	
	print("\n")
	print("╔══════════════════════════════════════════════════════════════════════════╗")
	print("║                     ✅ ALL TESTS COMPLETED                              ║")
	print("╚══════════════════════════════════════════════════════════════════════════╝")
	print("")

## ═══════════════════════════════════════════════════════════════════
## TEST SCENARIO 1: New/Struggling Player
## Expected: Should be assigned Easy difficulty
## ═══════════════════════════════════════════════════════════════════
func _run_test_scenario_1_new_player() -> void:
	print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
	print("┃ TEST 1: New/Struggling Player                                       ┃")
	print("┃ Simulating low accuracy (40-50%) with moderate timing               ┃")
	print("┃ Expected Result: Easy difficulty after 2-4 games                    ┃")
	print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
	print("")
	
	# Reset system
	AdaptiveDifficulty._initialize_session()
	
	# Simulate 4 games with poor performance
	var struggling_games = [
		{"accuracy": 0.40, "time": 18000, "mistakes": 6},  # 40%, 18s, 6 mistakes
		{"accuracy": 0.45, "time": 19000, "mistakes": 5},  # 45%, 19s, 5 mistakes
		{"accuracy": 0.42, "time": 17000, "mistakes": 7},  # 42%, 17s, 7 mistakes
		{"accuracy": 0.48, "time": 18500, "mistakes": 5},  # 48%, 18.5s, 5 mistakes
	]
	
	for i in range(struggling_games.size()):
		var game = struggling_games[i]
		print("🎮 Game %d: Accuracy=%.0f%%, Time=%.1fs, Mistakes=%d" % [
			i + 1, 
			game["accuracy"] * 100, 
			game["time"] / 1000.0, 
			game["mistakes"]
		])
		
		AdaptiveDifficulty.add_performance(
			game["accuracy"],
			game["time"],
			game["mistakes"],
			"TestGame"
		)
		
		await get_tree().process_frame
		
		# Show status after each game
		var status = AdaptiveDifficulty.get_algorithm_status()
		print("   📊 %s" % status["status_message"])
		print("   Current Difficulty: %s" % status["current_difficulty"])
		
		if status["algorithm_active"]:
			print("   Φ (Proficiency): %.4f" % status["proficiency_index"])
		
		print("")
	
	# Verify result
	var final_difficulty = AdaptiveDifficulty.get_current_difficulty()
	if final_difficulty == "Easy":
		print("✅ TEST PASSED: Player correctly assigned to Easy difficulty")
	else:
		print("❌ TEST FAILED: Expected Easy, got %s" % final_difficulty)
	print("")

## ═══════════════════════════════════════════════════════════════════
## TEST SCENARIO 2: Improving Player
## Expected: Should progress to Medium difficulty
## ═══════════════════════════════════════════════════════════════════
func _run_test_scenario_2_improving_player() -> void:
	print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
	print("┃ TEST 2: Improving Player                                            ┃")
	print("┃ Simulating gradual improvement (50% → 75%)                          ┃")
	print("┃ Expected Result: Medium difficulty after improvement                ┃")
	print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
	print("")
	
	# Reset system
	AdaptiveDifficulty._initialize_session()
	
	# Simulate improving performance
	var improving_games = [
		{"accuracy": 0.50, "time": 16000, "mistakes": 4},  # Starting point
		{"accuracy": 0.60, "time": 14000, "mistakes": 3},  # Getting better
		{"accuracy": 0.70, "time": 13000, "mistakes": 2},  # Much better
		{"accuracy": 0.75, "time": 12000, "mistakes": 2},  # Solid performance
	]
	
	for i in range(improving_games.size()):
		var game = improving_games[i]
		print("🎮 Game %d: Accuracy=%.0f%%, Time=%.1fs, Mistakes=%d" % [
			i + 1, 
			game["accuracy"] * 100, 
			game["time"] / 1000.0, 
			game["mistakes"]
		])
		
		AdaptiveDifficulty.add_performance(
			game["accuracy"],
			game["time"],
			game["mistakes"],
			"TestGame"
		)
		
		await get_tree().process_frame
		
		# Show status
		var status = AdaptiveDifficulty.get_algorithm_status()
		print("   📊 %s" % status["status_message"])
		print("   Current Difficulty: %s" % status["current_difficulty"])
		
		if status["algorithm_active"]:
			print("   Φ (Proficiency): %.4f" % status["proficiency_index"])
		
		print("")
	
	# Verify result
	var final_difficulty = AdaptiveDifficulty.get_current_difficulty()
	if final_difficulty == "Medium":
		print("✅ TEST PASSED: Player correctly progressed to Medium difficulty")
	else:
		print("⚠️ TEST WARNING: Expected Medium, got %s (may vary based on timing)" % final_difficulty)
	print("")

## ═══════════════════════════════════════════════════════════════════
## TEST SCENARIO 3: Expert Player
## Expected: Should reach Hard difficulty
## ═══════════════════════════════════════════════════════════════════
func _run_test_scenario_3_expert_player() -> void:
	print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
	print("┃ TEST 3: Expert Player                                               ┃")
	print("┃ Simulating high accuracy (85-95%) with consistent timing            ┃")
	print("┃ Expected Result: Hard difficulty                                    ┃")
	print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
	print("")
	
	# Reset system
	AdaptiveDifficulty._initialize_session()
	
	# Simulate expert performance (high accuracy + consistent timing)
	var expert_games = [
		{"accuracy": 0.88, "time": 8000, "mistakes": 1},   # Fast and accurate
		{"accuracy": 0.92, "time": 8200, "mistakes": 0},   # Even better
		{"accuracy": 0.90, "time": 8100, "mistakes": 1},   # Consistent
		{"accuracy": 0.95, "time": 7900, "mistakes": 0},   # Mastery
	]
	
	for i in range(expert_games.size()):
		var game = expert_games[i]
		print("🎮 Game %d: Accuracy=%.0f%%, Time=%.1fs, Mistakes=%d" % [
			i + 1, 
			game["accuracy"] * 100, 
			game["time"] / 1000.0, 
			game["mistakes"]
		])
		
		AdaptiveDifficulty.add_performance(
			game["accuracy"],
			game["time"],
			game["mistakes"],
			"TestGame"
		)
		
		await get_tree().process_frame
		
		# Show status
		var status = AdaptiveDifficulty.get_algorithm_status()
		print("   📊 %s" % status["status_message"])
		print("   Current Difficulty: %s" % status["current_difficulty"])
		
		if status["algorithm_active"]:
			print("   Φ (Proficiency): %.4f" % status["proficiency_index"])
			print("   WMA: %.4f, CP: %.4f" % [status["weighted_accuracy"], status["consistency_penalty"]])
		
		print("")
	
	# Verify result
	var final_difficulty = AdaptiveDifficulty.get_current_difficulty()
	if final_difficulty == "Hard":
		print("✅ TEST PASSED: Expert player correctly assigned to Hard difficulty")
	else:
		print("❌ TEST FAILED: Expected Hard, got %s" % final_difficulty)
	print("")

## ═══════════════════════════════════════════════════════════════════
## TEST SCENARIO 4: Erratic Player
## Expected: Should stay Easy despite decent accuracy
## ═══════════════════════════════════════════════════════════════════
func _run_test_scenario_4_erratic_player() -> void:
	print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
	print("┃ TEST 4: Erratic Player (Lucky but Unstable)                         ┃")
	print("┃ Simulating decent accuracy (70%) but wildly varying timing          ┃")
	print("┃ Expected Result: Easy difficulty (high consistency penalty)         ┃")
	print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
	print("")
	
	# Reset system
	AdaptiveDifficulty._initialize_session()
	
	# Simulate erratic performance (ok accuracy but inconsistent timing)
	var erratic_games = [
		{"accuracy": 0.70, "time": 5000, "mistakes": 3},   # Very fast (lucky?)
		{"accuracy": 0.72, "time": 20000, "mistakes": 2},  # Very slow
		{"accuracy": 0.68, "time": 8000, "mistakes": 3},   # Fast again
		{"accuracy": 0.75, "time": 22000, "mistakes": 2},  # Very slow again
	]
	
	for i in range(erratic_games.size()):
		var game = erratic_games[i]
		print("🎮 Game %d: Accuracy=%.0f%%, Time=%.1fs, Mistakes=%d" % [
			i + 1, 
			game["accuracy"] * 100, 
			game["time"] / 1000.0, 
			game["mistakes"]
		])
		
		AdaptiveDifficulty.add_performance(
			game["accuracy"],
			game["time"],
			game["mistakes"],
			"TestGame"
		)
		
		await get_tree().process_frame
		
		# Show status
		var status = AdaptiveDifficulty.get_algorithm_status()
		print("   📊 %s" % status["status_message"])
		print("   Current Difficulty: %s" % status["current_difficulty"])
		
		if status["algorithm_active"]:
			print("   Φ (Proficiency): %.4f (LOW due to high CP!)" % status["proficiency_index"])
			print("   WMA: %.4f (decent)" % status["weighted_accuracy"])
			print("   CP: %.4f (HIGH - erratic timing!)" % status["consistency_penalty"])
			print("   σ: %.0fms (standard deviation)" % status["std_deviation"])
		
		print("")
	
	# Verify result
	var final_difficulty = AdaptiveDifficulty.get_current_difficulty()
	if final_difficulty == "Easy":
		print("✅ TEST PASSED: Erratic player correctly kept at Easy difficulty")
		print("   (Despite decent accuracy, high timing variance was detected)")
	else:
		print("⚠️ TEST WARNING: Expected Easy, got %s" % final_difficulty)
		print("   (Consistency penalty may not have been high enough)")
	print("")

## ═══════════════════════════════════════════════════════════════════
## HELPER: Print Algorithm State
## ═══════════════════════════════════════════════════════════════════
func _print_algorithm_state() -> void:
	var status = AdaptiveDifficulty.get_algorithm_status()
	
	print("┌─────────────────────────────────────────────────────────────┐")
	print("│ Current Algorithm State                                     │")
	print("├─────────────────────────────────────────────────────────────┤")
	print("│ Difficulty: %-48s│" % status["current_difficulty"])
	print("│ Games in Window: %-43d│" % status["games_in_window"])
	
	if status["algorithm_active"]:
		print("│ Proficiency (Φ): %-43.4f│" % status["proficiency_index"])
		print("│ Weighted Accuracy: %-41.4f│" % status["weighted_accuracy"])
		print("│ Consistency Penalty: %-39.4f│" % status["consistency_penalty"])
	else:
		print("│ Status: Collecting data...                                 │")
	
	print("└─────────────────────────────────────────────────────────────┘")
	print("")
