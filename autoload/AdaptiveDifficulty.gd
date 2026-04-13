extends Node

## ═══════════════════════════════════════════════════════════════════
## ADAPTIVE DIFFICULTY SYSTEM - ROLLING WINDOW ALGORITHM
## ═══════════════════════════════════════════════════════════════════
## Research-Validated Educational Game System
## Algorithm: Rule-Based Decision Tree with Rolling Window
## Proficiency Index (Φ) = Weighted Moving Average - Consistency Penalty
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS (Event-Driven Architecture)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Formative Assessment Signals
signal difficulty_changed(old_level: String, new_level: String, reason: String)
signal performance_added(accuracy: float, time: int, mistakes: int)
signal behavioral_milestone(milestone: String, data: Dictionary)
signal algorithm_update(metrics: Dictionary)

## Research Data Signals
signal session_data_ready(data: Dictionary)
signal case_study_exported(file_path: String)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Rolling Window Configuration
@export_category("Algorithm Settings")
@export var window_size: int = 5  # Rolling window keeps last 5 games (as per outline)
@export var adaptation_frequency: int = 1  # Every N games (Paper: evaluate each new game)
# Need full window before adapting (Paper: window_size = 5)
@export var min_games_before_adaptation: int = 5
@export var target_latency_ms: float = 100.0

## Behavioral Thresholds
@export_category("Rule-Based Thresholds")
@export var struggling_success_rate: float = 0.6
@export var struggling_max_errors: int = 5
@export var mastery_success_rate: float = 0.8
@export var mastery_max_time: float = 15.0
@export var mastery_max_mistakes: int = 2

## Logging
@export var enable_verbose_logging: bool = true
@export var enable_research_logging: bool = true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Session Management
var session_id: String = ""
var session_start_time: int = 0
var total_score: int = 0

## Current Difficulty State
var current_difficulty: String = "Easy"  # Paper: initial difficulty = Easy

## Performance Tracking (Formative Assessment)
var performance_window: Array[Dictionary] = []  # Last 5 games (FIFO)
var performance_history: Array[Dictionary] = []  # All games
var difficulty_changes: Array[Dictionary] = []  # Timeline of changes
var games_since_adaptation: int = 0

## Progressive Difficulty (No Ceiling)
var progressive_level: int = 0  # 0 = base difficulty, increases infinitely
var consecutive_successes: int = 0  # Track success streak for progression

## Raw Game Score Weights (Paper: Mathematical Formulation)
## S = w_a·A + w_s·(1 - T_r/T_max) - w_e·E
## Where: A = accuracy (0-1), T_r = reaction time, T_max = max time, E = errors (0-1)
const SCORE_WEIGHT_ACCURACY: float = 0.6   # w_a: Accuracy weight (dominant factor)
const SCORE_WEIGHT_SPEED: float = 0.3      # w_s: Speed weight (secondary factor)
const SCORE_WEIGHT_ERRORS: float = 0.1     # w_e: Error penalty weight (minor factor)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DIFFICULTY SETTINGS (CHAOS SYSTEM)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Difficulty settings now use shorter timers to make the game more challenging
# The difference between Easy and Hard is VERY noticeable for demonstration
const DIFFICULTY_SETTINGS = {
	"Easy": {  # Beginner level - Comfortable pace
		"speed_multiplier": 0.7,  # 30% slower than normal (Paper: 0.7)
		"time_limit": 20,  # Generous time (Paper: 20s)
		"task_complexity": 1,  # Simple tasks
		"hints": 3,  # Full hints
		"visual_guidance": true,  # Visual help enabled (Paper: TRUE)
		"distractors": 1,  # Minimal distractions
		"item_count": 3,  # Few items to manage
		"chaos_effects": []  # No chaos effects (Paper: NONE)
	},
	"Medium": {  # Standard level - Flow State
		"speed_multiplier": 1.0,  # Normal speed (Paper: 1.0)
		"time_limit": 15,  # Standard time (Paper: 15s)
		"task_complexity": 2,  # Moderate complexity
		"hints": 2,  # Limited hints
		"visual_guidance": false,  # No visual help (Paper: FALSE)
		"distractors": 2,  # Some distractions
		"item_count": 5,  # Moderate items (Paper: 5)
		"chaos_effects": ["screen_shake_mild"]  # Mild chaos (Paper: MILD)
	},
	"Hard": {  # Expert level - Mastery challenge
		"speed_multiplier": 1.5,  # 50% faster (Paper: 1.5)
		"time_limit": 10,  # Tight time (Paper: 10s)
		"task_complexity": 3,  # Complex tasks
		"hints": 0,  # No hints
		"visual_guidance": false,  # No help (Paper: FALSE)
		"distractors": 3,  # Many distractions
		"item_count": 8,  # Many items
		"chaos_effects": [  # ALL chaos effects!
			"screen_shake_heavy",
			"mud_splatters",
			"buzzing_fly",
			"control_reverse",
			"visual_obstruction"
		]
	}
}



# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RAW GAME SCORE (Paper: Mathematical Formulation)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## ═══════════════════════════════════════════════════════════════════════════
## RAW GAME SCORE FORMULA
## ═══════════════════════════════════════════════════════════════════════════
## S = w_a · A + w_s · (1 - T_r / T_max) - w_e · E
##
## Where:
##   S     = Raw Game Score (0.0 to 1.0, clamped)
##   A     = Accuracy ratio (correct / total, 0.0 to 1.0)
##   T_r   = Reaction time (ms) — how long the player took
##   T_max = Maximum allowed time (ms) — from difficulty time_limit
##   E     = Error ratio (mistakes / total_actions, 0.0 to 1.0)
##   w_a   = 0.6 (Accuracy weight — dominant factor)
##   w_s   = 0.3 (Speed weight — rewards finishing quickly)
##   w_e   = 0.1 (Error penalty — minor deduction for mistakes)
##
## Rationale (from paper):
##   Accuracy is weighted highest because the game's goal is educational.
##   Speed is rewarded to encourage flow state, but not so much that
##   players rush and sacrifice learning.
##   Errors are penalized lightly to encourage careful play without
##   making the scoring feel punitive.
## ═══════════════════════════════════════════════════════════════════════════
func calculate_raw_game_score(
	accuracy: float, reaction_time_ms: int, mistakes: int
) -> float:
	# Get T_max from current difficulty settings (seconds → ms)
	var settings = DIFFICULTY_SETTINGS.get(
		current_difficulty, DIFFICULTY_SETTINGS["Easy"]
	)
	var t_max_ms: float = settings["time_limit"] * 1000.0
	
	# acc = Accuracy (already 0.0 to 1.0)
	var acc: float = clamp(accuracy, 0.0, 1.0)
	
	# speed = 1 - T_r / T_max (faster = higher score)
	var speed: float = clamp(
		1.0 - (float(reaction_time_ms) / t_max_ms), 0.0, 1.0
	)
	
	# err = Error ratio
	var err: float
	if mistakes <= 0:
		err = clamp(1.0 - accuracy, 0.0, 1.0)
	else:
		err = clamp(
			float(mistakes) / max(float(mistakes) + 5.0, 1.0),
			0.0, 1.0
		)
	
	# S = w_a · A + w_s · (1 - T_r/T_max) - w_e · E
	var score: float = (
		SCORE_WEIGHT_ACCURACY * acc +
		SCORE_WEIGHT_SPEED * speed -
		SCORE_WEIGHT_ERRORS * err
	)
	
	score = clamp(score, 0.0, 1.0)
	
	if enable_verbose_logging:
		print("📊 Raw Score: S=%.3f (A=%.2f, Spd=%.2f, E=%.2f)" % [
			score, acc, speed, err
		])
		print("   %.1f×%.2f + %.1f×%.2f - %.1f×%.2f = %.3f" % [
			SCORE_WEIGHT_ACCURACY, acc,
			SCORE_WEIGHT_SPEED, speed,
			SCORE_WEIGHT_ERRORS, err, score
		])
	
	return score

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	_initialize_session()
	_log_system_start()

func _initialize_session() -> void:
	session_id = _generate_session_id()
	session_start_time = int(Time.get_unix_time_from_system())
	current_difficulty = "Easy"
	
	# Reset all tracking arrays
	performance_window.clear()
	performance_history.clear()
	difficulty_changes.clear()
	
	# Reset flags
	games_since_adaptation = 0
	total_score = 0

func _generate_session_id() -> String:
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % 10000
	return "WW_%d_%04d" % [timestamp, random_suffix]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FORMATIVE ASSESSMENT - PERFORMANCE TRACKING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## ═══════════════════════════════════════════════════════════════════════════
## ADD PERFORMANCE - Record player's game results into the Rolling Window
## ═══════════════════════════════════════════════════════════════════════════
## ELI5: Think of the Rolling Window like a notebook that only keeps the last
##      5 pages. When you write a 6th page, the oldest page gets removed.
##      This way, we always focus on RECENT performance, not old games from
##      hours ago. Recent games tell us more about the player's CURRENT skill.
## ═══════════════════════════════════════════════════════════════════════════
func add_performance(
	accuracy: float, reaction_time: int,
	mistakes: int, game_name: String = ""
) -> void:
	var start_time = Time.get_ticks_msec()

	# Instrument for ISO 25010 latency measurement
	var _lat_start = 0
	if PerformanceProfiler:
		_lat_start = PerformanceProfiler.begin_latency_measurement()
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 1: Package the performance data from this game
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: Create a "report card" for this game with the score, time, and mistakes
	var performance_data = {
		"accuracy": clamp(accuracy, 0.0, 1.0),       # How well they did (0% to 100%)
		"reaction_time": reaction_time,              # How long it took (in milliseconds)
		"mistakes": mistakes,                        # How many errors they made
		"timestamp": Time.get_unix_time_from_system(), # When this game happened
		"difficulty": current_difficulty,            # What difficulty level it was
		"game_name": game_name                       # Which game they played
	}
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 2: Save to complete history (for research data)
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: Like keeping ALL your report cards in a big folder forever
	performance_history.append(performance_data)
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 3: Add to ROLLING WINDOW (FIFO = First In, First Out)
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: This is the MAGIC PART! The Rolling Window only remembers the last
	#       5 games (window_size = 5). When we add a 6th game, the OLDEST game
	#       automatically gets removed. It's like a sliding window that moves
	#       forward through time, always showing the 5 most recent games.
	#
	# WHY? Because if a player struggled 10 games ago but is doing great now,
	#      we want the difficulty to match their CURRENT skill, not their old skill!
	performance_window.append(performance_data)
	if performance_window.size() > window_size:
		performance_window.pop_front()  # Remove the oldest game from the window
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 4: Calculate Raw Game Score (Paper: S = w_a·A + w_s·(1 - T_r/T_max) - w_e·E)
	# ────────────────────────────────────────────────────────────────────────
	var raw_score = calculate_raw_game_score(accuracy, reaction_time, mistakes)
	var difficulty_multiplier = 1.0
	if current_difficulty == "Medium":
		difficulty_multiplier = 1.5
	elif current_difficulty == "Hard":
		difficulty_multiplier = 2.0
	var points = int(raw_score * 100 * difficulty_multiplier)
	total_score += points
	
	# Emit signal
	performance_added.emit(accuracy, reaction_time, mistakes)
	
	# Check for behavioral milestones
	_check_behavioral_milestones()
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 5: Check if we should ADAPT THE DIFFICULTY
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: We wait for the FULL Rolling Window (5 games) before adapting.
	#       This is because the paper defines window_size = 5 as the
	#       empirically-validated balance (Lin et al., 2025).
	#       Once we have 5 games, we evaluate EVERY game from that point on,
	#       since the FIFO window naturally slides, always reflecting the
	#       5 most recent games.
	#
	# Example: Games 1-4: collecting data, no adaptation yet.
	#          Game 5: FIRST adaptation! Full window available.
	#          Games 6, 7, 8...: re-evaluate each game (window slides).
	games_since_adaptation += 1
	var ready_to_adapt = (
		games_since_adaptation >= adaptation_frequency
		and performance_window.size() >= min_games_before_adaptation)
	if ready_to_adapt:
		print("\n🔬 ALGORITHM TRIGGERED: Window full (%d/%d games). Evaluating Φ..." % [
			performance_window.size(), window_size])
		_adapt_difficulty()  # 🎯 THIS IS WHERE THE ALGORITHM RUNS!
		games_since_adaptation = 0
	else:
		if performance_window.size() < min_games_before_adaptation:
			print("⏳ Rolling Window: %d/%d games. Need %d more before algorithm activates." % [
				performance_window.size(), window_size,
				min_games_before_adaptation - performance_window.size()])
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 6: Track consecutive successes for PROGRESSIVE DIFFICULTY
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: If the player keeps succeeding at Hard difficulty, we increase
	#       the progressive level, making the game progressively harder with
	#       NO CEILING! The game can become infinitely difficult.
	if accuracy >= 0.8:  # 80%+ accuracy = success
		consecutive_successes += 1
		# Every 3 consecutive successes at Hard difficulty increases progressive level
		if current_difficulty == "Hard" and consecutive_successes >= 3:
			progressive_level += 1
			consecutive_successes = 0  # Reset counter
			print("🔥 PROGRESSIVE LEVEL UP! Now at level %d - Game gets HARDER!" % progressive_level)
	else:
		# Failure resets the streak but doesn't decrease progressive level
		consecutive_successes = 0
	
	# Performance logging
	var elapsed = Time.get_ticks_msec() - start_time
	if enable_verbose_logging:
		print("⚡ Performance Added (Latency: %dms)" % elapsed)
	
	# Emit algorithm metrics
	algorithm_update.emit(_get_window_metrics())

	# Record latency for ISO 25010 compliance
	if PerformanceProfiler and _lat_start > 0:
		PerformanceProfiler.end_latency_measurement(
			_lat_start, "AdaptiveDifficulty.add_performance"
		)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RULE-BASED ALGORITHM - ROLLING WINDOW DECISION TREE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## ═══════════════════════════════════════════════════════════════════════════
## ADAPT DIFFICULTY - The main algorithm runner
## ═══════════════════════════════════════════════════════════════════════════
## ELI5: This is where the magic happens! After collecting performance data,
##      this function runs the 3-step algorithm:
##      1. Calculate metrics (WMA, CP, Φ)
##      2. Evaluate decision tree (Φ < 0.5? 0.5-0.85? > 0.85?)
##      3. Apply new difficulty and notify the game
## ═══════════════════════════════════════════════════════════════════════════
func _adapt_difficulty() -> void:
	# ────────────────────────────────────────────────────────────────────────
	# SAFETY CHECK: Do we have enough data to make a decision?
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: We need a full rolling window (5 games) before we can adapt
	#       (min_games_before_adaptation = 5 = window_size, per paper).
	#       This gives us enough data to calculate reliable trends!
	if performance_window.size() < min_games_before_adaptation:
		return  # Not enough data yet, wait for more games
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 1: Save current difficulty (to compare if it changes)
	# ────────────────────────────────────────────────────────────────────────
	var old_difficulty = current_difficulty  # Remember what difficulty we're at now
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 2: Calculate window metrics (WMA, CP, Φ)
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: Run the math on the rolling window to get the Proficiency Index (Φ)
	#       This function returns: Φ, WMA, Penalty, σ, and other metrics
	var metrics = _calculate_window_metrics()
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 3: Evaluate decision tree (apply the 3 rules)
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: Feed Φ into the decision tree:
	#       - If Φ < 0.5 → Easy
	#       - If Φ > 0.85 → Hard
	#       - Otherwise → Medium
	var decision_tree = _evaluate_decision_tree(metrics)
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 4: Apply the new difficulty
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: Actually change the difficulty level that the game will use next
	current_difficulty = decision_tree["new_difficulty"]
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 5: Log this adaptation event (for research/analysis)
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: Create a "change report" with timestamp, old/new difficulty, and reason
	var change_data = {
		"timestamp": Time.get_unix_time_from_system(),  # When did this happen?
		"old_difficulty": old_difficulty,               # What was it before?
		"new_difficulty": current_difficulty,           # What is it now?
		"reason": decision_tree["reason"],              # Why did we change it?
		"metrics": metrics,                             # All the math (Φ, WMA, CP, σ)
		"decision_path": decision_tree["path"]          # Which rule was triggered?
	}
	difficulty_changes.append(change_data)  # Save to history for later analysis
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 6: Emit signal if difficulty changed
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: Tell other parts of the game "Hey! Difficulty changed from Easy to Medium!"
	#       This lets the game update UI, sound effects, visual feedback, etc.
	if old_difficulty != current_difficulty:
		# Only emit if it actually changed (not Medium → Medium)
		difficulty_changed.emit(old_difficulty, current_difficulty, decision_tree["reason"])
		
		# If research logging is enabled, save detailed CSV data
		if enable_research_logging:
			_log_difficulty_change(change_data)
	
	# ═══════════════════════════════════════════════════════════════════════
	# VISUAL ALGORITHM DEBUGGING (Always print, for research visibility)
	# ═══════════════════════════════════════════════════════════════════════
	# ELI5: Show a clean, easy-to-read output in the console proving the algorithm works
	_print_algorithm_debug(metrics, decision_tree, old_difficulty)

func _print_algorithm_debug(
	metrics: Dictionary, decision: Dictionary,
	old_difficulty: String
) -> void:
	# SIMPLIFIED OUTPUT for panelist demonstration
	# Shows key algorithm metrics in an easy-to-read format
	# Get the key values from the algorithm calculation
	var phi = metrics.get("proficiency_index", 0.0)  # Main metric: Proficiency Index
	var new_diff = decision.get("new_difficulty", "Medium")  # Result: New difficulty
	
	# Determine what happened with difficulty
	var change_icon = "➡️"  # Default: no change
	if old_difficulty != new_diff:
		var went_up = (
			(old_difficulty == "Easy" and new_diff == "Medium")
			or (old_difficulty == "Medium" and new_diff == "Hard"))
		if went_up:
			change_icon = "⬆️"  # Difficulty increased
		else:
			change_icon = "⬇️"  # Difficulty decreased
	
	# Simplified output - just difficulty and calculation
	print("🎮 Game #%d | Φ=%.3f | %s %s %s" % [
		performance_history.size(),
		phi,
		old_difficulty.to_upper(),
		change_icon,
		new_diff.to_upper()
	])

func _calculate_window_metrics() -> Dictionary:
	# ╔════════════════════════════════════════════════════════════════════════╗
	# ║ WEIGHTED PROFICIENCY INDEX WITH CONSISTENCY PENALTY                    ║
	# ║ Research-Based Mathematical Model for Adaptive Difficulty              ║
	# ╚════════════════════════════════════════════════════════════════════════╝
	#
	# This function implements a sophisticated weighted moving average algorithm
	# with consistency penalty to calculate player proficiency. Unlike simple
	# averaging, this approach:
	#
	# 1. Gives MORE WEIGHT to recent performance (recency bias)
	# 2. PENALIZES erratic/inconsistent timing (standard deviation)
	# 3. Produces a PROFICIENCY INDEX (Phi) that better predicts skill level
	#
	# Mathematical Foundation:
	# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	#
	# PART A: Weighted Accuracy (Recency Bias)
	# ─────────────────────────────────────────
	# Formula: WMA = Σ(w_i * x_i) / Σ(w_i)
	#
	# Where:
	# - w_i = weight for game i (linear: 1, 2, 3, 4, 5)
	# - x_i = accuracy for game i (0.0 to 1.0)
	# - Most recent game has highest weight
	#
	# Example (5 games):
	# Game 1 (oldest):  accuracy = 0.6, weight = 1
	# Game 2:           accuracy = 0.7, weight = 2
	# Game 3:           accuracy = 0.8, weight = 3
	# Game 4:           accuracy = 0.9, weight = 4
	# Game 5 (newest):  accuracy = 0.95, weight = 5
	#
	# WMA = (1×0.6 + 2×0.7 + 3×0.8 + 4×0.9 + 5×0.95) / (1+2+3+4+5)
	# = (0.6 + 1.4 + 2.4 + 3.6 + 4.75) / 15
	# = 12.75 / 15
	# = 0.85
	#
	# PART B: Consistency Penalty (Standard Deviation)
	# ─────────────────────────────────────────────────
	# Formula: σ = sqrt(Σ(x_i - μ)² / N)
	#
	# Where:
	# - σ (sigma) = standard deviation
	# - x_i = reaction time for game i
	# - μ (mu) = mean reaction time
	# - N = number of games
	#
	# Normalized Penalty = min(σ / 5000.0, 0.2)
	# - Dividing by 5000ms normalizes erratic timing
	# - Capped at 0.2 (20% maximum penalty)
	# - Erratic timing → high penalty → lower proficiency
	#
	# Example:
	# Times: [5000ms, 6000ms, 5500ms, 5200ms, 8000ms]
	# Mean: 5940ms
	# Deviations: [-940, 60, -440, -740, 2060]
	# Squared: [883600, 3600, 193600, 547600, 4243600]
	# Variance: (883600+3600+193600+547600+4243600) / 5 = 1174400
	# σ = sqrt(1174400) ≈ 1083.7ms
	# Penalty = min(1083.7 / 5000, 0.2) = 0.217 → clamped to 0.2
	#
	# PART C: Proficiency Index (Phi - Φ)
	# ────────────────────────────────────
	# Formula: Φ = WMA - Penalty
	#
	# Where:
	# - Φ (Phi) = Proficiency Index
	# - WMA = Weighted Moving Average of accuracy
	# - Penalty = Consistency Penalty
	#
	# Range: -0.2 to 1.0
	# - High Φ = Skilled + Consistent
	# - Low Φ = Struggling OR Erratic
	#
	# This index is used for adaptive difficulty decisions.
	# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	
	# Edge case: No data available
	if performance_window.is_empty():
		return {
			"proficiency_index": 0.0,
			"weighted_accuracy": 0.0,
			"success_rate": 0.0,
			"consistency_penalty": 0.0,
			"std_deviation": 0.0,
			"avg_time": 0.0,
			"avg_mistakes": 0.0,
			"total_errors": 0,
			"window_size": 0
		}
	
	var perf_window_size: int = performance_window.size()
	
	# ═══════════════════════════════════════════════════════════════════════
	# STEP 1: Calculate Weighted Moving Average (WMA) of Accuracy
	# ═══════════════════════════════════════════════════════════════════════
	# ELI5: Imagine grading a student, but recent tests matter MORE than old tests.
	#       If the window has 5 games:
	#         - Oldest game (Game 1) gets weight = 1
	#         - Game 2 gets weight = 2
	#         - Game 3 gets weight = 3
	#         - Game 4 gets weight = 4
	#         - Newest game (Game 5) gets weight = 5  ← This matters the MOST!
	#
	# Example:
	#   Game 1: 50% × weight 1 = 0.50
	#   Game 2: 60% × weight 2 = 1.20
	#   Game 3: 70% × weight 3 = 2.10
	#   Game 4: 80% × weight 4 = 3.20
	#   Game 5: 90% × weight 5 = 4.50
	#   ────────────────────────────────────────
	#   Total = 11.50
	#   Sum of weights = (1+2+3+4+5) = 15
	#   WMA = 11.50 / 15 = 0.767 (76.7%)
	#
	# Compare to simple average: (50%+60%+70%+80%+90%) / 5 = 70%
	# The WMA is higher because we give MORE CREDIT to the recent 90% game!
	# ═══════════════════════════════════════════════════════════════════════
	
	var weighted_sum: float = 0.0      # Σ(w_i * x_i) - Running total of weighted scores
	var weight_sum: float = 0.0        # Σ(w_i) - Total of all weights used
	
	for i in range(perf_window_size):
		var weight: float = float(i + 1)  # Linear weights: 1, 2, 3 (recent = higher)
		var accuracy: float = performance_window[i]["accuracy"]
		
		weighted_sum += weight * accuracy
		weight_sum += weight
	
	# Final calculation: Weighted Moving Average = Σ(w_i * x_i) / Σ(w_i)
	var weighted_accuracy: float = weighted_sum / weight_sum
	
	# ═══════════════════════════════════════════════════════════════════════
	# STEP 2: Calculate Standard Deviation (σ) of Reaction Time
	# ═══════════════════════════════════════════════════════════════════════
	# ELI5: Standard Deviation measures how "jumpy" or "stable" the player is.
	#       If their game times are very different, they might be:
	#         - Still learning (inconsistent)
	#         - Guessing randomly (erratic)
	#         - Getting distracted (unstable)
	#
	# Example:
	#   Player A: [10s, 11s, 10s] - Very consistent! Low σ
	#   Player B: [5s, 20s, 8s]  - All over the place! High σ
	#
	# We PENALIZE high σ because even if they have good average accuracy,
	# erratic timing suggests they don't truly understand the task yet.
	# ═══════════════════════════════════════════════════════════════════════
	
	# First, calculate mean (μ) of reaction times
	var total_time: float = 0.0
	for perf in performance_window:
		total_time += float(perf["reaction_time"])
	
	var mean_time: float = total_time / float(perf_window_size)  # Average time
	
	# Second, calculate variance (σ²)
	# Variance = Σ(x_i - μ)² / N
	# ELI5: For each game, see how far it is from the average, square it,
	#       then average all those squared differences.
	var variance: float = 0.0
	for perf in performance_window:
		var deviation: float = float(perf["reaction_time"]) - mean_time
		variance += deviation * deviation  # (x_i - μ)² - Square to make all positive
	
	variance /= float(perf_window_size)
	
	# Third, calculate standard deviation (σ)
	# σ = sqrt(variance)
	# ELI5: Take the square root to get back to original units (milliseconds)
	var std_deviation: float = sqrt(variance)
	
	# ═══════════════════════════════════════════════════════════════════════
	# STEP 3: Calculate Consistency Penalty
	# ═══════════════════════════════════════════════════════════════════════
	# ELI5: Convert the standard deviation into a penalty between 0.0 and 0.2
	#
	# Formula: penalty = min(σ / T_max_ms, 0.2)
	#
	# Why divide by T_max_ms? This normalizes σ RELATIVE to the game's time window.
	# A σ of 2000ms is normal variation in a 20s game, but very erratic in a 10s game.
	# Why cap at 0.2? We don't want to penalize TOO harshly (max 20% reduction).
	#
	# Example (Easy, T_max = 20000ms):
	#   σ = 2000ms → penalty = 2000/20000 = 0.10 (10% penalty)
	#   σ = 4000ms → penalty = 4000/20000 = 0.20 (20% penalty - capped)
	# Example (Hard, T_max = 10000ms):
	#   σ = 2000ms → penalty = 2000/10000 = 0.20 (20% penalty - harder to stay!)
	# ═══════════════════════════════════════════════════════════════════════
	
	# Normalize standard deviation to penalty range [0.0, 0.2]
	# High σ → High penalty (erratic timing)
	# Low σ → Low penalty (consistent timing)
	# Paper: CP = min(σ / normalizer, 0.2)
	# Normalizer scaled to current difficulty's time_limit so CP fairly
	# reflects timing variability RELATIVE to the available time window.
	# (e.g., σ=2s is very erratic in a 10s game, but normal in a 20s game)
	var time_limit_ms: float = float(DIFFICULTY_SETTINGS[current_difficulty]["time_limit"]) * 1000.0
	var consistency_penalty: float = min(std_deviation / time_limit_ms, 0.2)
	
	# ═══════════════════════════════════════════════════════════════════════
	# STEP 4: Calculate Proficiency Index (Φ - Greek letter Phi)
	# ═══════════════════════════════════════════════════════════════════════
	# ELI5: This is THE MAGIC NUMBER that determines difficulty!
	#
	# Formula: Φ = WMA - Penalty
	#
	# Translation: Player's TRUE skill = How well they do - How erratic they are
	#
	# Example 1: GOOD PLAYER
	#   WMA = 0.85 (85% average accuracy, recent games weighted higher)
	#   Penalty = 0.05 (very consistent timing)
	#   Φ = 0.85 - 0.05 = 0.80  ← High proficiency! Make it harder!
	#
	# Example 2: STRUGGLING PLAYER
	#   WMA = 0.50 (50% average accuracy)
	#   Penalty = 0.15 (erratic timing, still learning)
	#   Φ = 0.50 - 0.15 = 0.35  ← Low proficiency! Make it easier!
	#
	# Example 3: TRICKY CASE - "Lucky but Unstable"
	#   WMA = 0.70 (70% accuracy - looks okay)
	#   Penalty = 0.20 (VERY erratic - guessing?)
	#   Φ = 0.70 - 0.20 = 0.50  ← Borderline! Not truly proficient yet.
	#
	# This ONE NUMBER captures both skill AND consistency!
	# ═══════════════════════════════════════════════════════════════════════
	
	# Φ = WMA - Penalty
	# This is the primary metric for adaptive difficulty
	var proficiency_index: float = weighted_accuracy - consistency_penalty
	
	# ═══════════════════════════════════════════════════════════════════════
	# STEP 5: Calculate Supporting Metrics (for logging/analytics)
	# ═══════════════════════════════════════════════════════════════════════
	
	var total_mistakes: int = 0
	for perf in performance_window:
		total_mistakes += perf["mistakes"]
	
	var avg_mistakes: float = float(total_mistakes) / float(perf_window_size)
	var avg_time_seconds: float = mean_time / 1000.0  # Convert ms to seconds
	
	# ═══════════════════════════════════════════════════════════════════════
	# RETURN: Comprehensive metrics dictionary
	# ═══════════════════════════════════════════════════════════════════════
	
	return {
		# PRIMARY METRIC (Used in decision tree)
		"proficiency_index": proficiency_index,        # Φ (Phi) [-0.2 to 1.0]
		
		# COMPONENTS (For research analysis)
		"weighted_accuracy": weighted_accuracy,        # WMA [0.0 to 1.0]
		"success_rate": weighted_accuracy * 100.0,     # Success rate as percentage
		"consistency_penalty": consistency_penalty,    # Penalty [0.0 to 0.2]
		"std_deviation": std_deviation,                # σ (Sigma) in ms
		
		# SUPPORTING METRICS (Backwards compatibility)
		"avg_time": avg_time_seconds,                  # Mean time in seconds
		"avg_mistakes": avg_mistakes,                  # Mean mistakes per game
		"total_errors": total_mistakes,                # Sum of all mistakes
		"window_size": perf_window_size                     # Number of games in window
	}

func _evaluate_decision_tree(metrics: Dictionary) -> Dictionary:
	# ╔════════════════════════════════════════════════════════════════════════╗
	# ║ PROFICIENCY-BASED DECISION TREE                                        ║
	# ║ Mathematical Adaptive Difficulty Algorithm                             ║
	# ╚════════════════════════════════════════════════════════════════════════╝
	#
	# This function uses the Proficiency Index (Φ) to make difficulty decisions.
	# Unlike rule-based systems that check multiple conditions, this uses a
	# single robust metric that already encodes:
	# - Performance quality (weighted accuracy)
	# - Consistency (standard deviation penalty)
	#
	# Decision Tree Logic:
	# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	#
	# RULE 1: STRUGGLING / ERRATIC (Φ < 0.5)
	# ───────────────────────────────────────
	# Threshold: Proficiency Index < 0.5
	#
	# Interpretation:
	# - Low weighted accuracy (poor recent performance), OR
	# - High consistency penalty (erratic/unstable timing)
	#
	# Example Case 1 (Struggling):
	# WMA = 0.45, Penalty = 0.05 → Φ = 0.40
	# → Player is genuinely struggling, needs easier tasks
	#
	# Example Case 2 (Erratic):
	# WMA = 0.65, Penalty = 0.20 → Φ = 0.45
	# → Player has okay accuracy but very inconsistent timing
	# → Could indicate confusion, stress, or lack of understanding
	# → Easier difficulty helps stabilize performance
	#
	# Action: Set difficulty to "Easy"
	# Rationale: Provide scaffolding and support
	#
	# RULE 2: MASTERY + CONSISTENCY (Φ > 0.85)
	# ─────────────────────────────────────────
	# Threshold: Proficiency Index > 0.85
	#
	# Interpretation:
	# - High weighted accuracy (strong recent performance), AND
	# - Low consistency penalty (stable/consistent timing)
	#
	# Example Case:
	# WMA = 0.92, Penalty = 0.05 → Φ = 0.87
	# → Player consistently performs well
	# → Ready for challenge to maintain engagement
	#
	# Action: Set difficulty to "Hard"
	# Rationale: Prevent boredom, maintain flow state
	#
	# RULE 3: FLOW STATE (0.5 ≤ Φ ≤ 0.85)
	# ────────────────────────────────────
	# Threshold: 0.5 ≤ Proficiency Index ≤ 0.85
	#
	# Interpretation:
	# - Moderate performance with acceptable consistency
	# - Player is in optimal learning zone
	#
	# Example Cases:
	# WMA = 0.70, Penalty = 0.10 → Φ = 0.60 (Lower flow)
	# WMA = 0.82, Penalty = 0.08 → Φ = 0.74 (Upper flow)
	#
	# Action: Set difficulty to "Medium"
	# Rationale: Maintain engagement without frustration
	#
	# Mathematical Advantages:
	# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	# 1. Single robust metric (easier to tune/validate)
	# 2. Recency bias (recent performance matters more)
	# 3. Consistency enforcement (stable timing = higher proficiency)
	# 4. Clearer thresholds (no compound conditions)
	# 5. Better research documentation (formula-based)
	# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	
	# Extract the primary metric: Proficiency Index (Φ)
	var proficiency: float = metrics.get("proficiency_index", 0.0)
	
	# Extract supporting metrics for detailed reasoning
	var weighted_accuracy: float = metrics.get("weighted_accuracy", 0.0)
	var consistency_penalty: float = metrics.get("consistency_penalty", 0.0)
	var std_deviation: float = metrics.get("std_deviation", 0.0)
	var _total_errors: int = metrics.get("total_errors", 0)  # Reserved for future use
	
	var new_difficulty: String = "Medium"
	var reason: String = ""
	var path: Array[String] = []
	
	# ═══════════════════════════════════════════════════════════════════════
	# RULE 1: STRUGGLING / ERRATIC (Φ < 0.5) → Easy Difficulty
	# ═══════════════════════════════════════════════════════════════════════
	# ELI5: If Φ is below 0.5, the player needs help!
	#       This could mean:
	#       A) They're genuinely struggling (low accuracy)
	#       B) They're erratic/guessing (high inconsistency penalty)
	#       Either way → Make the game EASIER so they can learn
	# ═══════════════════════════════════════════════════════════════════════
	
	if proficiency < 0.5:
		new_difficulty = "Easy"
		
		# Detailed diagnostic reasoning
		if weighted_accuracy < 0.6:
			# Primary issue: Poor performance
			reason = (
				"Struggling (Φ=%.2f): Poor WMA (%.2f)"
				+ " indicates difficulty with tasks"
			) % [proficiency, weighted_accuracy]
		elif consistency_penalty > 0.15:
			# Primary issue: Erratic timing
			reason = (
				"Erratic (Φ=%.2f): High CP (%.2f,"
				+ " σ=%.0fms) unstable performance"
			) % [proficiency, consistency_penalty,
				std_deviation]
		else:
			# General struggling
			reason = (
				"Support needed - Φ=%.2f"
				+ " below threshold (0.5)"
			) % proficiency
		
		path.append("Rule 1: STRUGGLING/ERRATIC (Φ < 0.5) → Easy")
		path.append(
			"  └─ WMA: %.2f, Penalty: %.2f, σ: %.0fms"
			% [weighted_accuracy, consistency_penalty,
				std_deviation])
	
	# ═══════════════════════════════════════════════════════════════════════
	# RULE 2: MASTERY + CONSISTENCY (Φ > 0.85) → Hard Difficulty
	# ═══════════════════════════════════════════════════════════════════════
	# ELI5: If Φ is above 0.85, the player is doing GREAT!
	#       High Φ means:
	#       - High accuracy in recent games (weighted higher)
	#       - Consistent timing (low penalty)
	#       → Make the game HARDER to keep them challenged and engaged!
	# ═══════════════════════════════════════════════════════════════════════
	
	elif proficiency > 0.85:
		new_difficulty = "Hard"
		reason = (
			"Mastery (Φ=%.2f): Strong WMA (%.2f)"
			+ " with low penalty (%.2f)"
		) % [proficiency, weighted_accuracy,
			consistency_penalty]
		
		path.append("Rule 2: MASTERY+CONSISTENCY (Φ > 0.85) → Hard")
		path.append(
			"  └─ WMA: %.2f, Penalty: %.2f, σ: %.0fms"
			% [weighted_accuracy, consistency_penalty,
				std_deviation])
	
	# ═══════════════════════════════════════════════════════════════════════
	# RULE 3: FLOW STATE (0.5 ≤ Φ ≤ 0.85) → Medium Difficulty
	# ═══════════════════════════════════════════════════════════════════════
	# ELI5: If Φ is between 0.5 and 0.85, the player is in the SWEET SPOT!
	#       Not too easy, not too hard - this is called "Flow State"
	#       where learning happens best.
	#       → Keep difficulty at MEDIUM to maintain this optimal challenge
	# ═══════════════════════════════════════════════════════════════════════
	
	else:
		new_difficulty = "Medium"
		reason = (
			"Flow state (Φ=%.2f): Balanced"
			+ " performance in learning zone"
		) % proficiency
		
		path.append("Rule 3: FLOW STATE (0.5 ≤ Φ ≤ 0.85) → Medium")
		path.append(
			"  └─ WMA: %.2f, Penalty: %.2f, σ: %.0fms"
			% [weighted_accuracy, consistency_penalty,
				std_deviation])
	
	# ═══════════════════════════════════════════════════════════════════════
	# RETURN: Decision with detailed reasoning
	# ═══════════════════════════════════════════════════════════════════════
	
	return {
		"new_difficulty": new_difficulty,
		"reason": reason,
		"path": path,
		"proficiency_index": proficiency,         # Include for logging
		"weighted_accuracy": weighted_accuracy,
		"consistency_penalty": consistency_penalty
	}

func _get_window_metrics() -> Dictionary:
	return _calculate_window_metrics()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BEHAVIORAL METRICS (DERIVED FROM PERFORMANCE)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_behavioral_metrics() -> Dictionary:
	if performance_history.size() < 2:
		return {
			"learning_velocity": 0.0,
			"decision_quality": 0.0,
			"persistence": 0,
			"mastery_progression": []
		}
	
	# Learning Velocity (improvement rate)
	var half_idx = int(performance_history.size() / 2.0)
	var first_half = performance_history.slice(0, half_idx)
	var second_half = performance_history.slice(
		half_idx, performance_history.size())
	
	var first_avg = _calculate_avg_accuracy(first_half)
	var second_avg = _calculate_avg_accuracy(second_half)
	var learning_velocity = second_avg - first_avg
	
	# Decision Quality (accuracy / time ratio)
	var total_quality = 0.0
	for perf in performance_history:
		var time_seconds = max(perf["reaction_time"] / 1000.0, 0.1)
		total_quality += perf["accuracy"] / time_seconds
	var decision_quality = total_quality / performance_history.size()
	
	# Persistence (games played after failures)
	var persistence = 0
	for i in range(1, performance_history.size()):
		if performance_history[i - 1]["accuracy"] < 0.5:
			persistence += 1
	
	# Mastery Progression
	var mastery_progression = []
	for change in difficulty_changes:
		mastery_progression.append({
			"timestamp": change["timestamp"],
			"difficulty": change["new_difficulty"]
		})
	
	return {
		"learning_velocity": learning_velocity,
		"decision_quality": decision_quality,
		"persistence": persistence,
		"mastery_progression": mastery_progression,
		"total_games": performance_history.size(),
		"current_streak": _calculate_current_streak()
	}

func _calculate_avg_accuracy(perf_array: Array) -> float:
	if perf_array.is_empty():
		return 0.0
	var total = 0.0
	for perf in perf_array:
		total += perf["accuracy"]
	return total / perf_array.size()

func _calculate_current_streak() -> int:
	var streak = 0
	for i in range(performance_history.size() - 1, -1, -1):
		if performance_history[i]["accuracy"] >= 0.7:
			streak += 1
		else:
			break
	return streak

func _check_behavioral_milestones() -> void:
	var metrics = get_behavioral_metrics()
	
	# Mastery Achievement
	if metrics["learning_velocity"] > 0.3 and not _has_milestone("mastery_achieved"):
		behavioral_milestone.emit("mastery_achieved", metrics)
		_add_milestone("mastery_achieved")
	
	# Persistence Award
	if metrics["persistence"] >= 5 and not _has_milestone("persistence_award"):
		behavioral_milestone.emit("persistence_award", metrics)
		_add_milestone("persistence_award")
	
	# Speed Demon
	if metrics["decision_quality"] > 0.8 and not _has_milestone("speed_demon"):
		behavioral_milestone.emit("speed_demon", metrics)
		_add_milestone("speed_demon")

var _milestones_achieved: Array[String] = []

func _has_milestone(milestone: String) -> bool:
	return milestone in _milestones_achieved

func _add_milestone(milestone: String) -> void:
	_milestones_achieved.append(milestone)



# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DIFFICULTY SETTINGS ACCESS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_current_difficulty() -> String:
	return current_difficulty

func get_difficulty_settings() -> Dictionary:
	var base_settings = DIFFICULTY_SETTINGS[current_difficulty].duplicate()
	
	# Apply progressive difficulty multipliers (NO CEILING!)
	# The better the player performs, the harder it gets - infinitely!
	if progressive_level > 0:
		# Each progressive level makes the game harder
		var progression_multiplier = 1.0 + (progressive_level * 0.15)  # +15% per level
		
		# Speed increases exponentially
		base_settings["speed_multiplier"] *= progression_multiplier
		
		# Time limit decreases (minimum 3 seconds to keep it playable)
		var new_limit = int(
			base_settings["time_limit"] / progression_multiplier)
		base_settings["time_limit"] = max(3, new_limit)
		
		# Task complexity increases
		base_settings["task_complexity"] += progressive_level
		
		# Item count increases (more things to manage)
		base_settings["item_count"] += progressive_level * 2
		
		# Distractors increase
		base_settings["distractors"] += progressive_level
		
		# Add progressive level indicator
		base_settings["progressive_level"] = progressive_level
		base_settings["progression_bonus"] = int(
			(progression_multiplier - 1.0) * 100)
	else:
		base_settings["progressive_level"] = 0
		base_settings["progression_bonus"] = 0
	
	return base_settings

## ═══════════════════════════════════════════════════════════════════════
## GET ALGORITHM STATUS - For Panelist/Research Display
## ═══════════════════════════════════════════════════════════════════════
## ELI5: This function packages all the algorithm's current state into
##       a dictionary that can be displayed in the UI or logged for research.
##       Perfect for showing panelists "Here's what the algorithm is doing!"
## ═══════════════════════════════════════════════════════════════════════
func get_algorithm_status() -> Dictionary:
	# Returns comprehensive algorithm state for research/demo purposes.
	# Use this to display the algorithm's work to panelists or in debug UI.
	var metrics = _get_window_metrics() if performance_window.size() > 0 else {}
	
	var status = {
		# Current State
		"current_difficulty": current_difficulty,
		"games_in_window": performance_window.size(),
		"games_until_next_adaptation": max(0, adaptation_frequency - games_since_adaptation),
		"total_games_played": performance_history.size(),
		
		# Algorithm Metrics (if available)
		"proficiency_index": metrics.get("proficiency_index", 0.0),
		"weighted_accuracy": metrics.get("weighted_accuracy", 0.0),
		"consistency_penalty": metrics.get("consistency_penalty", 0.0),
		"std_deviation": metrics.get("std_deviation", 0.0),
		
		# Window Data (for visualization)
		"window_accuracies": [],
		"window_times": [],
		
		# Status Messages (human-readable)
		"status_message": "",
		"algorithm_active": performance_window.size() >= min_games_before_adaptation
	}
	
	# Populate window data for visualization
	for i in range(performance_window.size()):
		var perf = performance_window[i]
		status["window_accuracies"].append({
			"accuracy": perf["accuracy"],
			"weight": i + 1,
			"game_name": perf.get("game_name", "Game")
		})
		status["window_times"].append(perf["reaction_time"])
	
	# Generate status message
	if performance_window.size() < min_games_before_adaptation:
		var games_left = (
			min_games_before_adaptation
			- performance_window.size())
		status["status_message"] = (
			"Rolling Window: %d/5 games collected."
			+ " Play %d more to fill window and activate algorithm."
		) % [performance_window.size(), games_left]
	else:
		var phi = status["proficiency_index"]
		if phi < 0.5:
			status["status_message"] = (
				"Algorithm: STRUGGLING (Φ=%.2f)"
				+ " → Easy difficulty") % phi
		elif phi > 0.85:
			status["status_message"] = (
				"Algorithm: MASTERY (Φ=%.2f)"
				+ " → Hard difficulty") % phi
		else:
			status["status_message"] = (
				"Algorithm: FLOW STATE (Φ=%.2f)"
				+ " → Medium difficulty") % phi
	
	return status

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# JUICE SYSTEM (Game Feel)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func should_screen_shake() -> bool:
	var settings = get_difficulty_settings()
	var effects = settings["chaos_effects"]
	return "screen_shake_mild" in effects or "screen_shake_heavy" in effects

func get_screen_shake_intensity() -> float:
	var settings = get_difficulty_settings()
	var effects = settings["chaos_effects"]
	if "screen_shake_heavy" in effects:
		return 1.0
	if "screen_shake_mild" in effects:
		return 0.5
	return 0.0

func get_particle_intensity() -> float:
	match current_difficulty:
		"Easy":
			return 0.3
		"Medium":
			return 0.6
		"Hard":
			return 1.0
	return 0.5

func get_sound_pitch() -> float:
	# Faster pitch for higher difficulty
	var settings = get_difficulty_settings()
	return settings["speed_multiplier"]

func get_transition_speed() -> float:
	# Faster transitions for higher difficulty
	var settings = get_difficulty_settings()
	return settings["speed_multiplier"]

func has_chaos_effect(effect_name: String) -> bool:
	var settings = get_difficulty_settings()
	return effect_name in settings["chaos_effects"]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RESEARCH DATA EXPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func export_complete_session() -> Dictionary:
	var session_data = {
		"session_id": session_id,
		"timestamp": Time.get_unix_time_from_system(),
		"session_duration": Time.get_unix_time_from_system() - session_start_time,
		
		# Gameplay Data
		"gameplay": {
			"total_games_played": performance_history.size(),
			"total_score": total_score,
			"performance_history": performance_history,
			"difficulty_timeline": difficulty_changes,
			"behavioral_metrics": get_behavioral_metrics(),
			"final_difficulty": current_difficulty,
			"window_metrics": _get_window_metrics()
		},
		
		# Algorithm Performance
		"algorithm_stats": {
			"total_adaptations": difficulty_changes.size(),
			"avg_latency_ms": _calculate_avg_latency(),
			"window_size": window_size,
			"adaptation_frequency": adaptation_frequency
		}
	}
	
	session_data_ready.emit(session_data)
	return session_data

func export_to_json_file(file_path: String = "") -> void:
	if file_path.is_empty():
		file_path = "user://case_study_%s.json" % session_id
	
	var data = export_complete_session()
	var json_string = JSON.stringify(data, "\t")
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		
		case_study_exported.emit(file_path)
		
		if enable_verbose_logging:
			print("💾 Case study exported to: %s" % file_path)
	else:
		push_error("Failed to export case study to: %s" % file_path)

func get_case_study_data() -> Dictionary:
	return export_complete_session()

func _calculate_avg_latency() -> float:
	# This would require actual timing measurements during adaptation
	# For now, return target latency as estimate
	return target_latency_ms

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY METHODS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func reset() -> void:
	_initialize_session()
	if enable_verbose_logging:
		print("🔄 System Reset - New Session: %s" % session_id)

func get_total_score() -> int:
	return total_score

func get_games_played() -> int:
	return performance_history.size()

func get_performance_history() -> Array:
	return performance_history.duplicate()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOGGING SYSTEM (Research Documentation)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _log_system_start() -> void:
	if not enable_research_logging:
		return
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🎮 WATERWISE ADAPTIVE DIFFICULTY SYSTEM")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📋 Session ID: %s" % session_id)
	print("🕐 Started: %s" % Time.get_datetime_string_from_unix_time(session_start_time))
	print("🔬 Algorithm: Rule-Based Rolling Window")
	print("📏 Window Size: %d games" % window_size)
	print("⚡ Adaptation: Every %d games" % adaptation_frequency)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

func _log_difficulty_change(change_data: Dictionary) -> void:
	if not enable_research_logging:
		return
	
	var metrics = change_data["metrics"]
	
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📊 ADAPTIVE DIFFICULTY UPDATE (Formative)")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🔬 Algorithm: Rule-Based Rolling Window")
	print("📏 Window: %d/%d games" % [metrics["window_size"], window_size])
	print("")
	print("📈 Performance Metrics:")
	print("  • Success Rate: %.1f%%" % metrics["success_rate"])
	print("  • Avg Time: %.1fs" % metrics["avg_time"])
	print("  • Avg Mistakes: %.1f" % metrics["avg_mistakes"])
	print("  • Total Errors: %d" % metrics["total_errors"])
	print("")
	print("🌳 Decision Tree:")
	for path in change_data["decision_path"]:
		print("  %s" % path)
	print("")
	print("🎯 Difficulty: %s → %s" % [change_data["old_difficulty"], change_data["new_difficulty"]])
	print("💡 Reason: %s" % change_data["reason"])
	
	if change_data["new_difficulty"] == "Hard":
		var settings = DIFFICULTY_SETTINGS["Hard"]
		print("🎪 CHAOS EFFECTS: %s" % str(settings["chaos_effects"]))
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
