extends Node

## ═══════════════════════════════════════════════════════════════════
## DYNAMIC CO-ADAPTATION ALGORITHM - MULTIPLAYER COOPERATIVE MODE
## ═══════════════════════════════════════════════════════════════════
## Manages adaptive difficulty for TWO players simultaneously
## Accounts for skill differences while maintaining team-based challenges
## Uses same Proficiency Index formulas as single-player Rule-Based Rolling Window
## Novel algorithm for cooperative educational games
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal difficulty_adapted(p1_difficulty: String, p2_difficulty: String, skill_gap: float)
signal team_performance_added(p1_data: Dictionary, p2_data: Dictionary, team_success: bool)
signal synchronization_updated(sync_score: float)
# signal load_balancing_applied(
#     p1_adj: Dictionary, p2_adj: Dictionary)  # Unused

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const WINDOW_SIZE: int = 5  # Rolling window size (matches single-player)
const SKILL_GAP_THRESHOLD: float = 0.15  # 15% proficiency difference triggers asymmetric adjustment
const WEAKER_ADJUSTMENT_FACTOR: float = 0.3  # Reduce Φ by 30% of skill gap
const STRONGER_ADJUSTMENT_FACTOR: float = 0.2  # Increase Φ by 20% of skill gap
const LOAD_BALANCE_FACTOR: float = 0.2  # 20% task count adjustment

# Proficiency Index thresholds (same as single-player)
const PHI_EASY_THRESHOLD: float = 0.5
const PHI_HARD_THRESHOLD: float = 0.85

# Synchronization scoring
const SYNC_TIME_PENALTY: float = 5.0  # Points lost per second of time difference
const SYNC_EXCELLENT_THRESHOLD: float = 85.0
const SYNC_POOR_THRESHOLD: float = 60.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Player 1 tracking
var player1_window: Array[Dictionary] = []  # Last 5 games for Player 1
var player1_history: Array[Dictionary] = []  # All games
var player1_proficiency: float = 0.5  # Φ1 (starts at medium)
var player1_difficulty: String = "Medium"

# Player 2 tracking
var player2_window: Array[Dictionary] = []  # Last 5 games for Player 2
var player2_history: Array[Dictionary] = []  # All games
var player2_proficiency: float = 0.5  # Φ2 (starts at medium)
var player2_difficulty: String = "Medium"

# Team metrics
var team_success_rate: float = 0.0
var total_games: int = 0
var successful_games: int = 0
var synchronization_history: Array[float] = []
var current_sync_score: float = 100.0
var skill_gap: float = 0.0

# Adjustment mode
var is_asymmetric: bool = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DIFFICULTY PARAMETERS (PER PLAYER)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Base parameters (before load balancing)
const BASE_SETTINGS = {
	"Easy": {
		"time_limit": 20,
		"task_count": 4,
		"hints_enabled": true,
		"visual_guidance": true,
		"hint_frequency": "frequent",
		"complexity": "simple"
	},
	"Medium": {
		"time_limit": 15,
		"task_count": 5,
		"hints_enabled": false,
		"visual_guidance": false,  # Paper: Medium = no hints, no visual guidance
		"hint_frequency": "occasional",
		"complexity": "standard"
	},
	"Hard": {
		"time_limit": 10,
		"task_count": 6,
		"hints_enabled": false,
		"visual_guidance": false,
		"hint_frequency": "rare",
		"complexity": "complex"
	}
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	_log("CoopAdaptation initialized - Window Size: " + str(WINDOW_SIZE))

func reset_session() -> void:
	# Reset all tracking data for new multiplayer session
	player1_window.clear()
	player1_history.clear()
	player1_proficiency = 0.5
	player1_difficulty = "Medium"
	
	player2_window.clear()
	player2_history.clear()
	player2_proficiency = 0.5
	player2_difficulty = "Medium"
	
	team_success_rate = 0.0
	total_games = 0
	successful_games = 0
	synchronization_history.clear()
	current_sync_score = 100.0
	skill_gap = 0.0
	is_asymmetric = false
	
	_log("Session reset complete")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN ALGORITHM - ADD GAME RESULT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func add_game_result(
	p1_performance: Dictionary,
	p2_performance: Dictionary,
	team_success: bool
) -> void:
	# Add cooperative game result and update adaptive difficulty
	#
	# Parameters:
	# - p1_performance: {accuracy: float, time: float, errors: int}
	# - p2_performance: {accuracy: float, time: float, errors: int}
	# - team_success: bool (both players succeeded)
	
	# Validate input
	var p1_valid = _validate_performance_data(p1_performance)
	var p2_valid = _validate_performance_data(p2_performance)
	if not p1_valid or not p2_valid:
		_log("❌ Invalid performance data received")
		return
	
	# Add timestamp
	var timestamp = Time.get_unix_time_from_system()
	p1_performance["timestamp"] = timestamp
	p2_performance["timestamp"] = timestamp
	
	# Add to Player 1 tracking
	player1_history.append(p1_performance)
	player1_window.append(p1_performance)
	if player1_window.size() > WINDOW_SIZE:
		player1_window.pop_front()
	
	# Add to Player 2 tracking
	player2_history.append(p2_performance)
	player2_window.append(p2_performance)
	if player2_window.size() > WINDOW_SIZE:
		player2_window.pop_front()
	
	# ════════════════════════════════════════════════════════════════════════
	# UPDATE TEAM METRICS - Track overall team success
	# ════════════════════════════════════════════════════════════════════════
	# ELI5: Keep a running count of how many games the team has played and won
	total_games += 1  # Increment total games counter
	if team_success:
		successful_games += 1  # Increment wins counter if they succeeded
	# Calculate success rate as percentage: wins / total games
	team_success_rate = float(successful_games) / float(total_games)
	
	# ════════════════════════════════════════════════════════════════════════
	# SYNCHRONIZATION SCORE CALCULATION (G-Counter Algorithm)
	# ════════════════════════════════════════════════════════════════════════
	# ELI5: The "G-Counter" (Grow-only Counter) measures how well synchronized
	#       the two players are. Good teamwork = finishing close together in time!
	#
	# Formula: Sync = max(0, 100 - (time_diff × penalty))
	#
	# Example 1: Perfect Sync
	#   Player 1 finishes at 10.0 seconds
	#   Player 2 finishes at 10.5 seconds
	#   time_diff = |10.0 - 10.5| = 0.5 seconds
	#   Sync = 100 - (0.5 × 5.0) = 100 - 2.5 = 97.5% ← EXCELLENT!
	#
	# Example 2: Poor Sync
	#   Player 1 finishes at 8.0 seconds
	#   Player 2 finishes at 18.0 seconds
	#   time_diff = |8.0 - 18.0| = 10.0 seconds
	#   Sync = 100 - (10.0 × 5.0) = 100 - 50 = 50% ← NEEDS WORK
	#
	# Example 3: Very Poor Sync
	#   Player 1 finishes at 5.0 seconds
	#   Player 2 finishes at 25.0 seconds
	#   time_diff = |5.0 - 25.0| = 20.0 seconds
	#   Sync = 100 - (20.0 × 5.0) = 100 - 100 = 0% (clamped) ← NO COORDINATION
	#
	# WHY "G-Counter"? In distributed systems, a G-Counter is a CRDT (Conflict-free
	# Replicated Data Type) that only grows upward, never decreases. Similarly,
	# this sync score tracks the "growth" of team coordination over time.
	# As players learn to work together, their sync scores grow higher!
	# ════════════════════════════════════════════════════════════════════════
	
	# STEP 1: Calculate time difference between players
	var time_diff = abs(p1_performance["time"] - p2_performance["time"])
	
	# STEP 2: Apply penalty formula and clamp to [0, 100] range
	# Start at 100 (perfect), subtract (time_diff × 5 points per second)
	# Use max(0, ...) to prevent negative scores
	current_sync_score = max(0.0, 100.0 - (time_diff * SYNC_TIME_PENALTY))
	
	# STEP 3: Save to history for trend analysis
	synchronization_history.append(current_sync_score)
	
	var result_str = "Success" if team_success else "Failed"
	_log("📊 Game added - Team %s | Sync: %.1f%%"
		% [result_str, current_sync_score])
	
	# Emit signal
	team_performance_added.emit(p1_performance, p2_performance, team_success)
	synchronization_updated.emit(current_sync_score)
	
	# Adapt difficulty
	if player1_window.size() >= 3 and player2_window.size() >= 3:
		adjust_coop_difficulty()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROFICIENCY INDEX CALCULATION (SAME AS SINGLE-PLAYER)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## ═══════════════════════════════════════════════════════════════════════════
## CALCULATE PROFICIENCY INDEX (Φ) - PER PLAYER IN MULTIPLAYER
## ═══════════════════════════════════════════════════════════════════════════
## ELI5: Each player gets their OWN Proficiency Index (Φ) calculated independently
##      using the SAME MATH as single-player:
##      1. Weighted Moving Average (recent games matter more)
##      2. Consistency Penalty (punish erratic timing)
##      3. Φ = WMA - CP
##
## WHY? Because in multiplayer, one player might be skilled (Φ=0.9) while their
##      partner is learning (Φ=0.4). We need to track each person separately!
## ═══════════════════════════════════════════════════════════════════════════
func calculate_proficiency_index(rolling_window: Array[Dictionary]) -> float:
	# Calculate Proficiency Index (Φ) using EXACT formula from the paper:
	#
	# Formula: Φ = WMA - CP
	#
	# Where:
	# - WMA = Weighted Moving Average with linear weights [1,2,3,4,5]
	# - CP  = min(σ / 5000.0, 0.2) — standard deviation in ms, capped at 20%
	#
	# Identical to AdaptiveDifficulty._calculate_proficiency_index()
	#
	# Returns: Φ value between -0.2 and 1.0
	
	# ────────────────────────────────────────────────────────────────────────
	# EDGE CASE: No data yet for this player
	# ────────────────────────────────────────────────────────────────────────
	if rolling_window.is_empty():
		return 0.5  # Default to medium difficulty (Φ = 0.5)
	
	# Count how many games this player has in their window
	var window_size = rolling_window.size()
	
	# ════════════════════════════════════════════════════════════════════════
	# PART A: Weighted Moving Average (WMA) - Recency Bias
	# ════════════════════════════════════════════════════════════════════════
	# ELI5: Same as single-player! Recent games matter MORE than old games.
	#       If the window has 5 games:
	#         Game 1 (oldest) = weight 1
	#         Game 2 = weight 2
	#         Game 3 = weight 3
	#         Game 4 = weight 4
	#         Game 5 (newest) = weight 5  ← Most important!
	# ════════════════════════════════════════════════════════════════════════
	
	var weighted_sum: float = 0.0  # Σ(w_i * x_i) - Running total
	var weight_sum: float = 0.0    # Σ(w_i) - Sum of all weights
	
	# Loop through each game in the rolling window
	for i in range(window_size):
		var weight = float(i + 1)  # Linear weights: 1, 2, 3 (recent = higher)
		var accuracy = rolling_window[i]["accuracy"]  # How well they did (0.0 to 1.0)
		
		weighted_sum += weight * accuracy  # Multiply accuracy by its weight
		weight_sum += weight               # Add weight to total
	
	# Calculate Weighted Moving Average: WMA = Σ(w*x) / Σ(w)
	var wma: float = weighted_sum / weight_sum
	
	# ════════════════════════════════════════════════════════════════════════
	# PART B: Consistency Penalty (CP) - Standard Deviation of Time
	# ════════════════════════════════════════════════════════════════════════
	# ELI5: Measure how "jumpy" this player's timing is
	#       Player A: [10s, 11s, 10s] - Very consistent! Low penalty
	#       Player B: [5s, 20s, 8s]  - All over the place! High penalty
	# ════════════════════════════════════════════════════════════════════════
	
	# STEP 1: Calculate mean (average) time
	var total_time: float = 0.0
	for game in rolling_window:
		total_time += game["time"]  # Add up all game times
	
	var mean_time: float = total_time / float(window_size)  # Average time
	
	# STEP 2: Calculate variance (σ²)
	# Variance = Σ(x_i - μ)² / N
	# ELI5: For each game, see how far it is from average, square it, then average those
	var variance: float = 0.0
	for game in rolling_window:
		var diff = game["time"] - mean_time  # How far from average?
		variance += diff * diff              # Square it (makes all values positive)
	variance /= float(window_size)  # Average the squared differences
	
	# STEP 3: Calculate standard deviation (σ)
	# σ = sqrt(variance)
	# ELI5: Take square root to get back to original units (seconds)
	var std_dev: float = sqrt(variance)
	
	# STEP 4: Consistency Penalty — Paper formula: CP = min(σ / 5000, 0.2)
	# Times in rolling_window are in SECONDS, convert to ms (* 1000)
	# then apply the paper's normalization divisor of 5000
	var std_dev_ms: float = std_dev * 1000.0  # seconds → milliseconds
	var consistency_penalty: float = min(std_dev_ms / 5000.0, 0.2)
	
	# ─────────────────────────────────────────────────────────────────
	# FINAL: Φ = WMA - CP (Paper: exact formula, same as single-player)
	# ─────────────────────────────────────────────────────────────────
	var phi: float = wma - consistency_penalty
	
	# Clamp to valid range [-0.2, 1.0]
	phi = clamp(phi, -0.2, 1.0)
	
	return phi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DYNAMIC CO-ADAPTATION ALGORITHM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## ═══════════════════════════════════════════════════════════════════════════
## ADJUST COOPERATIVE DIFFICULTY - Main multiplayer algorithm
## ═══════════════════════════════════════════════════════════════════════════
## ELI5: This is the multiplayer version of _adapt_difficulty()!
##      It handles TWO players with potentially different skill levels.
##
## Algorithm Steps:
## 1. Calculate Φ1 and Φ2 (each player gets their own Proficiency Index)
## 2. Calculate skill gap: |Φ1 - Φ2| (how different are their skills?)
## 3. Choose strategy:
##    - BIG gap (>15%): ASYMMETRIC → Give each player different difficulty
##    - SMALL gap (≤15%): SYMMETRIC → Give both players same difficulty
## 4. Apply load balancing (redistribute tasks if asymmetric)
## 5. Apply synchronization adjustments (help with coordination)
## ═══════════════════════════════════════════════════════════════════════════
func adjust_coop_difficulty() -> void:
	# Main adaptive difficulty adjustment logic for cooperative mode
	#
	# Algorithm Steps:
	# 1. Calculate Φ1 and Φ2 using Proficiency Index formula
	# 2. Calculate skill gap: |Φ1 - Φ2|
	# 3. Apply adjustment strategy:
	# - Large gap (>0.15): ASYMMETRIC (different difficulties)
	# - Small gap (≤0.15): SYMMETRIC (same difficulty based on team average)
	# 4. Apply load balancing if asymmetric
	# 5. Consider synchronization for coordination adjustments
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 1: Calculate Proficiency Indexes for EACH player
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: Run the same WMA - CP formula on each player's rolling window
	#       Player 1 gets Φ1, Player 2 gets Φ2 (calculated independently!)
	player1_proficiency = calculate_proficiency_index(player1_window)
	player2_proficiency = calculate_proficiency_index(player2_window)
	
	# Log for debugging/demonstration
	_log("📈 Φ1 = %.3f | Φ2 = %.3f" % [player1_proficiency, player2_proficiency])
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 2: Calculate skill gap (absolute difference)
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: How different are these two players?
	#       Φ1 = 0.85, Φ2 = 0.40 → gap = |0.85 - 0.40| = 0.45 (BIG gap!)
	#       Φ1 = 0.60, Φ2 = 0.55 → gap = |0.60 - 0.55| = 0.05 (small gap)
	skill_gap = abs(player1_proficiency - player2_proficiency)
	
	# Log for debugging/demonstration
	_log("📊 Skill Gap = %.3f (%.1f%%)" % [skill_gap, skill_gap * 100])
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 3: Choose adjustment strategy based on skill gap
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: Decide: Should we give them DIFFERENT difficulties or the SAME?
	#
	# IF gap > 15% (0.15) → ASYMMETRIC
	#   Example: Φ1=0.85 (expert), Φ2=0.40 (beginner) → gap = 0.45
	#   Solution: Give Player 1 "Hard" and Player 2 "Easy"
	#   This keeps both players challenged appropriately!
	#
	# IF gap ≤ 15% (0.15) → SYMMETRIC
	#   Example: Φ1=0.62, Φ2=0.58 → gap = 0.04
	#   Solution: Give both players "Medium" (based on team average Φ)
	#   This keeps the team working together at similar pace!
	if skill_gap > SKILL_GAP_THRESHOLD:
		# Large gap → Different difficulties for each player
		_apply_asymmetric_adjustment()
	else:
		# Small gap → Same difficulty for both players
		_apply_symmetric_adjustment()
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 4: Emit signal to notify game of difficulty change
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: Tell the game "Player 1 is now on Hard, Player 2 is on Easy, gap = 0.45"
	difficulty_adapted.emit(player1_difficulty, player2_difficulty, skill_gap)
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 5: Apply synchronization adjustments (G-Counter based)
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: If their sync score is low, add coordination helpers
	#       If their sync score is high, add challenge for expert teams
	_apply_synchronization_adjustments()

func _apply_asymmetric_adjustment() -> void:
	# ASYMMETRIC adjustment for large skill gaps (>15%)
	#
	# Logic:
	# - Weaker player: Φ_adjusted = Φ_weaker - (skill_gap × 0.3)
	# - Stronger player: Φ_adjusted = Φ_stronger + (skill_gap × 0.2)
	# - Apply load balancing (task count, hints, time)
	is_asymmetric = true
	_log("⚖️ ASYMMETRIC adjustment (Large skill gap)")
	
	# Identify weaker and stronger players
	var weaker_phi: float
	var stronger_phi: float
	var weaker_is_p1: bool
	
	if player1_proficiency < player2_proficiency:
		weaker_phi = player1_proficiency
		stronger_phi = player2_proficiency
		weaker_is_p1 = true
	else:
		weaker_phi = player2_proficiency
		stronger_phi = player1_proficiency
		weaker_is_p1 = false
	
	# Adjust proficiencies
	var adjusted_weaker_phi = weaker_phi - (skill_gap * WEAKER_ADJUSTMENT_FACTOR)
	var adjusted_stronger_phi = stronger_phi + (skill_gap * STRONGER_ADJUSTMENT_FACTOR)
	
	# Clamp to valid range
	adjusted_weaker_phi = clamp(adjusted_weaker_phi, -0.2, 1.0)
	adjusted_stronger_phi = clamp(adjusted_stronger_phi, -0.2, 1.0)
	
	# Map to difficulty levels
	var weaker_difficulty = _phi_to_difficulty(adjusted_weaker_phi)
	var stronger_difficulty = _phi_to_difficulty(adjusted_stronger_phi)
	
	# Assign to players
	if weaker_is_p1:
		player1_difficulty = weaker_difficulty
		player2_difficulty = stronger_difficulty
		_log("👤 P1 (Weaker): %s | Φ: %.3f → %.3f"
			% [weaker_difficulty, weaker_phi,
				adjusted_weaker_phi])
		_log("👤 P2 (Stronger): %s | Φ: %.3f → %.3f"
			% [stronger_difficulty, stronger_phi,
				adjusted_stronger_phi])
	else:
		player1_difficulty = stronger_difficulty
		player2_difficulty = weaker_difficulty
		_log("👤 P1 (Stronger): %s | Φ: %.3f → %.3f"
			% [stronger_difficulty, stronger_phi,
				adjusted_stronger_phi])
		_log("👤 P2 (Weaker): %s | Φ: %.3f → %.3f"
			% [weaker_difficulty, weaker_phi,
				adjusted_weaker_phi])

func _apply_symmetric_adjustment() -> void:
	# SYMMETRIC adjustment for small skill gaps (≤15%)
	#
	# Logic:
	# - Team_Φ = (Φ1 + Φ2) / 2
	# - Both players get same difficulty based on Team_Φ
	# - No load balancing needed
	is_asymmetric = false
	_log("⚖️ SYMMETRIC adjustment (Small skill gap)")
	
	# Calculate team proficiency
	var team_phi = (player1_proficiency + player2_proficiency) / 2.0
	
	# Map to difficulty
	var team_difficulty = _phi_to_difficulty(team_phi)
	
	player1_difficulty = team_difficulty
	player2_difficulty = team_difficulty
	
	_log("👥 Team Φ = %.3f → Both players: %s" % [team_phi, team_difficulty])

func _phi_to_difficulty(phi: float) -> String:
	# Map Proficiency Index to difficulty level
	if phi < PHI_EASY_THRESHOLD:
		return "Easy"
	if phi <= PHI_HARD_THRESHOLD:
		return "Medium"
	return "Hard"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DIFFICULTY GETTERS (For MiniGameBase compatibility)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_player_difficulty(player_num: int) -> String:
	# Get the current difficulty level for a specific player
	if player_num == 1:
		return player1_difficulty
	return player2_difficulty

func get_difficulty_params(player_num: int) -> Dictionary:
	# Get difficulty params compatible with AdaptiveDifficulty format
	var params = get_player_parameters(player_num)
	
	# Convert to AdaptiveDifficulty-compatible format
	var speed_mult = 1.0
	var chaos = []
	
	match params.get("difficulty", "Medium"):
		"Easy":
			speed_mult = 0.7
			chaos = []
		"Medium":
			speed_mult = 1.0
			chaos = ["screen_shake_mild"]
		"Hard":
			speed_mult = 1.5
			chaos = ["screen_shake_heavy", "visual_obstruction"]
	
	return {
		"speed_multiplier": speed_mult,
		"time_limit": params.get("time_limit", 15),
		"task_complexity": (
			1 if params.get("complexity") == "simple"
			else (3 if params.get("complexity") == "complex"
				else 2)),
		"hints": 3 if params.get("hints_enabled", true) else 0,
		"visual_guidance": params.get("visual_guidance", false),
		"item_count": params.get("task_count", 5),
		"chaos_effects": chaos
	}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOAD BALANCING (ASYMMETRIC MODE ONLY)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_player_parameters(player_num: int) -> Dictionary:
	# Get difficulty parameters for specific player with load balancing
	#
	# Returns:
	# {
	# difficulty: String,
	# time_limit: int,
	# task_count: int,
	# hints_enabled: bool,
	# visual_guidance: bool,
	# hint_frequency: String,
	# complexity: String,
	# load_balanced: bool
	# }
	
	var difficulty = player1_difficulty if player_num == 1 else player2_difficulty
	var base_params = BASE_SETTINGS[difficulty].duplicate(true)
	
	# Apply load balancing if asymmetric and this player is weaker/stronger
	if is_asymmetric:
		var is_weaker = false
		
		# Determine if this player is weaker
		if player_num == 1:
			is_weaker = (player1_proficiency < player2_proficiency)
		else:
			is_weaker = (player2_proficiency < player1_proficiency)
		
		if is_weaker:
			# WEAKER PLAYER: Reduce load
			base_params["task_count"] = max(1, int(
				base_params["task_count"]
				* (1.0 - LOAD_BALANCE_FACTOR)))
			base_params["time_limit"] += 5  # +5 seconds
			base_params["hint_frequency"] = "frequent"
			base_params["visual_guidance"] = true
			base_params["hints_enabled"] = true
			_log("🔽 Load reduced for Player %d (Weaker)" % player_num)
		else:
			# STRONGER PLAYER: Increase load
			base_params["task_count"] = int(base_params["task_count"] * (1.0 + LOAD_BALANCE_FACTOR))
			base_params["time_limit"] = max(5, base_params["time_limit"] - 3)  # -3 seconds
			base_params["hint_frequency"] = "rare"
			_log("🔼 Load increased for Player %d (Stronger)" % player_num)
		
		base_params["load_balanced"] = true
	else:
		base_params["load_balanced"] = false
	
	base_params["difficulty"] = difficulty
	return base_params

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SYNCHRONIZATION ADJUSTMENTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _apply_synchronization_adjustments() -> void:
	# Apply coordination adjustments based on synchronization score
	#
	# Poor sync (<60%): Add coordination cues, slow initial pace
	# Excellent sync (>85%): Increase pace, add challenge elements
	
	if synchronization_history.is_empty():
		return
	
	# Calculate average sync score from last 5 games
	var start_idx = max(0, synchronization_history.size() - 5)
	var recent_syncs = synchronization_history.slice(
		start_idx, synchronization_history.size())
	var avg_sync = 0.0
	for sync in recent_syncs:
		avg_sync += sync
	avg_sync /= recent_syncs.size()
	
	if avg_sync < SYNC_POOR_THRESHOLD:
		_log("⚠️ Poor synchronization (%.1f%%) - Adding coordination support" % avg_sync)
		# Coordination cues will be enabled in game logic
	elif avg_sync > SYNC_EXCELLENT_THRESHOLD:
		_log("✨ Excellent synchronization (%.1f%%) - Adding challenge" % avg_sync)
		# Challenge elements will be enabled in game logic

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# METRICS AND REPORTING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_team_metrics() -> Dictionary:
	# Get comprehensive team performance metrics
	return {
		"total_games": total_games,
		"successful_games": successful_games,
		"team_success_rate": team_success_rate,
		"current_sync_score": current_sync_score,
		"avg_sync_score": _calculate_avg_sync(),
		"player1_proficiency": player1_proficiency,
		"player2_proficiency": player2_proficiency,
		"skill_gap": skill_gap,
		"is_asymmetric": is_asymmetric,
		"player1_difficulty": player1_difficulty,
		"player2_difficulty": player2_difficulty
	}

func _calculate_avg_sync() -> float:
	# Calculate average synchronization score
	if synchronization_history.is_empty():
		return 100.0
	
	var sum = 0.0
	for sync in synchronization_history:
		sum += sync
	return sum / synchronization_history.size()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _validate_performance_data(data: Dictionary) -> bool:
	# Validate performance data structure
	if not data.has("accuracy") or not data.has("time") or not data.has("errors"):
		return false
	
	if typeof(data["accuracy"]) != TYPE_FLOAT and typeof(data["accuracy"]) != TYPE_INT:
		return false
	
	if typeof(data["time"]) != TYPE_FLOAT and typeof(data["time"]) != TYPE_INT:
		return false
	
	if typeof(data["errors"]) != TYPE_INT:
		return false
	
	return true

func _log(message: String) -> void:
	# Internal logging function
	print("[CoopAdaptation] " + message)
