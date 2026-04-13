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
		"id": "water_reuse_vegetables",
		"name": "Water Reuse: Vegetable Washing",
		"description": "P1 washes vegetables, P2 reuses water for plants",
		"player1_game": "res://scenes/multiplayer/MP_WashVegetables.tscn",
		"player2_game": "res://scenes/multiplayer/MP_WaterPlants.tscn",
		"player1_role": "Vegetable Washer",
		"player2_role": "Plant Waterer",
		"connection_type": "resource_transfer",
		"connection_description": "P1's dirty water from washing → P2 waters plants"
	},
	{
		"id": "shower_water_reuse",
		"name": "Shower Water Reuse",
		"description": "P1 collects shower water, P2 flushes toilets",
		"player1_game": "res://scenes/multiplayer/MP_CollectShowerWater.tscn",
		"player2_game": "res://scenes/multiplayer/MP_FlushToilets.tscn",
		"player1_role": "Shower Water Collector",
		"player2_role": "Toilet Flusher",
		"connection_type": "resource_transfer",
		"connection_description": "P1's shower water → P2 flushes toilets"
	},
	{
		"id": "rain_aquarium",
		"name": "Rain Collection for Aquarium",
		"description": "P1 catches rain, P2 fills aquarium",
		"player1_game": "res://scenes/multiplayer/MP_CatchRainAquarium.tscn",
		"player2_game": "res://scenes/multiplayer/MP_FillAquarium.tscn",
		"player1_role": "Rain Catcher",
		"player2_role": "Aquarium Keeper",
		"connection_type": "resource_transfer",
		"connection_description": "P1's rainwater → P2 fills aquarium"
	},
	{
		"id": "laundry_water_reuse",
		"name": "Laundry Water Reuse",
		"description": "P1 collects laundry water, P2 mops floors",
		"player1_game": "res://scenes/multiplayer/MP_CollectLaundryWater.tscn",
		"player2_game": "res://scenes/multiplayer/MP_MopFloor.tscn",
		"player1_role": "Laundry Water Collector",
		"player2_role": "Floor Mopper",
		"connection_type": "resource_transfer",
		"connection_description": "P1's laundry water → P2 mops floors"
	},
	{
		"id": "dishwater_car_wash",
		"name": "Dish Water Car Wash",
		"description": "P1 collects dish water, P2 washes car",
		"player1_game": "res://scenes/multiplayer/MP_CollectDishWater.tscn",
		"player2_game": "res://scenes/multiplayer/MP_WashCar.tscn",
		"player1_role": "Dish Water Collector",
		"player2_role": "Car Washer",
		"connection_type": "resource_transfer",
		"connection_description": "P1's dish water → P2 washes car"
	}
]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LEVEL SET SELECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var available_sets: Array = []
var current_set_index: int = 0
var roles_swapped: bool = false
var rounds_played: int = 0

func _ready() -> void:
	# Initialize available sets with all level sets
	available_sets = LEVEL_SETS.duplicate()
	available_sets.shuffle()
	print("🎮 LevelSets initialized with %d sets" % available_sets.size())

func get_random_level_set() -> Dictionary:
	"""Get a random level set with role swapping every round"""
	if available_sets.is_empty():
		# All sets played, reshuffle
		available_sets = LEVEL_SETS.duplicate()
		available_sets.shuffle()
		print("🔄 Reshuffling level sets")
	
	var level_set = available_sets.pop_front().duplicate(true)
	
	# Swap roles every round (P1↔P2 alternates)
	rounds_played += 1
	roles_swapped = (rounds_played % 2 == 0)
	
	if roles_swapped:
		print("🔀 Round %d: Swapping roles - P1 becomes P2, P2 becomes P1" % rounds_played)
		var temp_game = level_set["player1_game"]
		var temp_role = level_set["player1_role"]
		level_set["player1_game"] = level_set["player2_game"]
		level_set["player1_role"] = level_set["player2_role"]
		level_set["player2_game"] = temp_game
		level_set["player2_role"] = temp_role
	else:
		print("➡️ Round %d: Normal roles - P1=%s, P2=%s" % [rounds_played, level_set["player1_role"], level_set["player2_role"]])
	
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
	rounds_played = 0
	print("🔄 LevelSets reset")
