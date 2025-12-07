extends Node

## ═══════════════════════════════════════════════════════════════════
## LEVEL SETS - Interconnected Cooperative Minigames
## ═══════════════════════════════════════════════════════════════════
## Defines paired minigames where Player 1 and Player 2 have 
## complementary roles that connect to each other
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LEVEL SET DEFINITIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const LEVEL_SETS = [
	{
		"id": "water_collection_chain",
		"name": "Water Collection Chain",
		"description": "Catch rain and filter it for use",
		"player1_game": "res://scripts/multiplayer/MiniGame_Rain.tscn",
		"player2_game": "res://scripts/multiplayer/MiniGame_Rain.tscn",  # Both play same game with different modes
		"player1_role": "Rain Catcher",
		"player2_role": "Water Filter",
		"connection_type": "resource_transfer",
		"connection_description": "P1's caught water feeds into P2's filter",
		"difficulty_easy": {
			"p1_spawn_rate": 2.0,
			"p2_filter_capacity": 10
		},
		"difficulty_medium": {
			"p1_spawn_rate": 1.5,
			"p2_filter_capacity": 15
		},
		"difficulty_hard": {
			"p1_spawn_rate": 1.0,
			"p2_filter_capacity": 20
		}
	},
	{
		"id": "pipe_repair_team",
		"name": "Pipe Repair Team",
		"description": "Spot leaks and plug them",
		"player1_game": "res://scripts/multiplayer/MiniGame_LeafSort.tscn",
		"player2_game": "res://scripts/multiplayer/MiniGame_LeafSort.tscn",  # Using existing game
		"player1_role": "Leak Spotter",
		"player2_role": "Leak Plugger",
		"connection_type": "task_marking",
		"connection_description": "P1 marks leaks, P2 sees and repairs them",
		"difficulty_easy": {
			"p1_leak_count": 3,
			"p2_time_per_leak": 5.0
		},
		"difficulty_medium": {
			"p1_leak_count": 5,
			"p2_time_per_leak": 4.0
		},
		"difficulty_hard": {
			"p1_leak_count": 7,
			"p2_time_per_leak": 3.0
		}
	},
	{
		"id": "garden_conservation",
		"name": "Garden Conservation",
		"description": "Collect greywater and water plants",
		"player1_game": "res://scripts/multiplayer/MiniGame_GreywaterSort.tscn",
		"player2_game": "res://scripts/multiplayer/MiniGame_GreywaterSort.tscn",  # Using existing game
		"player1_role": "Greywater Collector",
		"player2_role": "Plant Waterer",
		"connection_type": "resource_transfer",
		"connection_description": "P2 can only water with what P1 collected",
		"difficulty_easy": {
			"p1_collection_target": 5,
			"p2_plant_count": 3
		},
		"difficulty_medium": {
			"p1_collection_target": 8,
			"p2_plant_count": 5
		},
		"difficulty_hard": {
			"p1_collection_target": 12,
			"p2_plant_count": 7
		}
	},
	{
		"id": "household_savings",
		"name": "Household Savings",
		"description": "Turn off taps and cover water drums",
		"player1_game": "res://scripts/multiplayer/MiniGame_BucketBrigade.tscn",
		"player2_game": "res://scripts/multiplayer/MiniGame_BucketBrigade.tscn",  # Using existing game
		"player1_role": "Tap Turner",
		"player2_role": "Drum Coverer",
		"connection_type": "combined_efficiency",
		"connection_description": "Both must complete tasks to save water",
		"difficulty_easy": {
			"p1_tap_count": 3,
			"p2_drum_count": 3
		},
		"difficulty_medium": {
			"p1_tap_count": 5,
			"p2_drum_count": 5
		},
		"difficulty_hard": {
			"p1_tap_count": 7,
			"p2_drum_count": 7
		}
	}
]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LEVEL SET SELECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var available_sets: Array = []
var current_set_index: int = 0
var roles_swapped: bool = false

func _ready() -> void:
	# Initialize available sets with all level sets
	available_sets = LEVEL_SETS.duplicate()
	available_sets.shuffle()
	print("🎮 LevelSets initialized with %d sets" % available_sets.size())

func get_random_level_set() -> Dictionary:
	"""Get a random level set (without replacement until all played)"""
	if available_sets.is_empty():
		# All sets played, reshuffle
		available_sets = LEVEL_SETS.duplicate()
		available_sets.shuffle()
		print("🔄 Reshuffling level sets")
	
	var level_set = available_sets.pop_front()
	
	# Randomly decide if roles should be swapped
	roles_swapped = randf() > 0.5
	
	if roles_swapped:
		print("🔀 Swapping roles for this round")
		var temp_game = level_set["player1_game"]
		var temp_role = level_set["player1_role"]
		level_set = level_set.duplicate()
		level_set["player1_game"] = level_set["player2_game"]
		level_set["player1_role"] = level_set["player2_role"]
		level_set["player2_game"] = temp_game
		level_set["player2_role"] = temp_role
	
	print("🎯 Selected level set: %s" % level_set["name"])
	return level_set

func get_level_set_by_id(set_id: String) -> Dictionary:
	"""Get a specific level set by ID"""
	for level_set in LEVEL_SETS:
		if level_set["id"] == set_id:
			return level_set
	
	push_warning("Level set not found: " + set_id)
	return {}

func get_difficulty_params(level_set: Dictionary, difficulty: String) -> Dictionary:
	"""Get difficulty parameters for a level set"""
	var key = "difficulty_" + difficulty.to_lower()
	return level_set.get(key, level_set.get("difficulty_medium", {}))

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_all_level_sets() -> Array:
	"""Get all available level sets"""
	return LEVEL_SETS.duplicate()

func reset() -> void:
	"""Reset level set selection"""
	available_sets = LEVEL_SETS.duplicate()
	available_sets.shuffle()
	current_set_index = 0
	roles_swapped = false
	print("🔄 LevelSets reset")
