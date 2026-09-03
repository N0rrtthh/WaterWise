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
# Warmup games before adaptation starts (configured to 3-5 games)
@export_range(3, 5, 1) var min_games_before_adaptation: int = 3
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
## Research telemetry log of completed rounds.
##
## Distinct from performance_window: the paper's constant-memory guarantee is a
## claim about the n=5 rolling window, which genuinely never grows. This log
## exists only to export a session for analysis, and it used to be uncapped —
## on a <2GB device a long unbroken session grew it without limit, which
## contradicts the ΔRAM = 0 figure the evaluation reports.
##
## Capped at MAX_PERFORMANCE_HISTORY. The tail is what session analysis needs;
## exact operation totals live in total_games_recorded so nothing under-reports
## once trimming starts. The adaptive algorithm never reads this array, so
## trimming cannot affect a difficulty decision.
var performance_history: Array[Dictionary] = []
## Lifetime count of rounds fed to add_performance() this session.
##
## Stays exact after performance_history is trimmed. Every "games played" reader
## uses this, not performance_history.size(), which would silently under-report
## a long session once the cap is reached.
var total_games_recorded: int = 0
## Retention limit for the research log. ~500 rounds is roughly two hours of
## uninterrupted play, well past any single test session, at a worst-case
## footprint of a couple hundred KB. Matches GCounter.MAX_HISTORY_ENTRIES.
const MAX_PERFORMANCE_HISTORY: int = 500
var difficulty_changes: Array[Dictionary] = []  # Timeline of changes
var games_since_adaptation: int = 0

## Measured adaptation latency, in milliseconds (Paper: <100ms requirement).
## These are REAL wall-clock measurements of the decision pass taken from
## PerformanceProfiler, not estimates. Never substitute target_latency_ms here:
## the value is exported into the case-study JSON as evidence, so a placeholder
## would misreport a research result.
var adaptation_latencies_ms: Array[float] = []
var adaptation_latency_total_ms: float = 0.0
var adaptation_latency_samples: int = 0
var adaptation_latency_max_ms: float = 0.0

## Retained sample cap for the latency array. Running sum/count/max above stay
## exact regardless, so trimming never distorts the reported average.
const MAX_LATENCY_SAMPLES: int = 200

## Progressive Difficulty (No Ceiling)
var progressive_level: int = 0  # 0 = base difficulty; bounded by MAX_PROGRESSIVE_LEVEL

## Ceiling on the supplementary progression ramp.
##
## This layer used to be explicitly uncapped ("increases infinitely"), and every
## value it touches is consumed directly by gameplay:
##   speed_multiplier *= 1 + level*0.15   time_limit /= the same factor
##   item_count += level*2                distractors += level
## Left to grow, item_count becomes an unbounded entity count — a draw-call and
## memory problem on a <2GB device — while time_limit collapses toward its 3s floor
## against an ever-faster board, so rounds eventually cannot be won at all. An
## escalation with no ceiling always terminates in a guaranteed loss.
##
## At the cap the applied values are: speed ×2.4, time_limit 6s, item_count 16,
## distractors 7 (from Hard's 1.5 / 10 / 8 / 3). Reaching it takes 12 consecutive
## Hard rounds at 80%+ accuracy, so it stays a real mastery reward.
const MAX_PROGRESSIVE_LEVEL: int = 4
var consecutive_successes: int = 0  # Track success streak for progression

## Raw Game Score Weights (Paper: Mathematical Formulation)
## S = w_a·A + w_s·(1 - T_r/T_max) - w_e·E
## Where: A = accuracy (0-1), T_r = reaction time, T_max = max time, E = errors (0-1)
const SCORE_WEIGHT_ACCURACY: float = 0.6   # w_a: Accuracy weight (dominant factor)
const SCORE_WEIGHT_SPEED: float = 0.3      # w_s: Speed weight (secondary factor)
const SCORE_WEIGHT_ERRORS: float = 0.1     # w_e: Error penalty weight (minor factor)

## Consistency Penalty constants (Paper: CP = min(σ_ms / 5000, 0.2))
## Both values are FIXED by the thesis. The normalizer must not be derived
## from the active difficulty's time_limit: CP feeds Φ, and Φ selects the
## difficulty, so a difficulty-dependent divisor would make identical player
## performance produce different Φ values and break determinism.
const CONSISTENCY_PENALTY_NORMALIZER_MS: float = 5000.0
const CONSISTENCY_PENALTY_MAX: float = 0.2

## Decision-tree thresholds on Φ (Paper: Φ<0.5 Easy, 0.5-0.85 Medium, >0.85 Hard)
const PROFICIENCY_THRESHOLD_EASY: float = 0.5
const PROFICIENCY_THRESHOLD_HARD: float = 0.85

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
	
	# E = Error term, normalized to [0,1] so that S stays inside the paper's
	# documented 0..1 range (a raw error count would let 10 mistakes swing S by
	# a full 1.0 on its own, via w_e alone).
	#
	# The saturating ratio m/(m+5) is monotonically increasing in m and never
	# reaches 1, which is the property that matters: more errors must never
	# improve the score.
	#
	# Previously the mistakes==0 case returned (1.0 - accuracy), which inverted
	# exactly that property — at accuracy 0.40 a flawless run scored E=0.60
	# while a run with one mistake scored E=0.167, so committing a mistake
	# RAISED the score. Zero errors now contributes zero error penalty, and
	# low accuracy is already penalized by the w_a term.
	var err: float
	if mistakes <= 0:
		err = 0.0
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
		_log_verbose("📊 Raw Score: S=%.3f (A=%.2f, Spd=%.2f, E=%.2f)" % [
			score, acc, speed, err
		])
		_log_verbose("   %.1f×%.2f + %.1f×%.2f - %.1f×%.2f = %.3f" % [
			SCORE_WEIGHT_ACCURACY, acc,
			SCORE_WEIGHT_SPEED, speed,
			SCORE_WEIGHT_ERRORS, err, score
		])
	
	return score

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEFERRED VERBOSE LOGGING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Research/debug output is queued and flushed after the current frame's work.
##
## Why this exists: print() to a redirected or piped stdout costs tens of
## milliseconds per call. Emitting research logs from inside a measured
## algorithm region made every round report ~145ms against a 16ms budget, so
## the profiler warned on every single round — the log filled with warnings
## about the cost of writing to the log. Deferring keeps the thesis-visibility
## output intact while making the latency numbers describe the actual math.
var _pending_logs: PackedStringArray = PackedStringArray()
var _log_flush_queued: bool = false

## Queue a line for deferred printing, independent of any gate.
##
## Split out from _log_verbose so the research-logging paths
## (_log_difficulty_change, _print_algorithm_debug) can defer their I/O without
## being silenced when enable_verbose_logging is off. Those two are gated on
## enable_research_logging instead, and folding them into the verbose gate would
## have dropped thesis output whenever verbose logging was disabled.
func _queue_log(message: String) -> void:
	_pending_logs.append(message)
	if not _log_flush_queued:
		_log_flush_queued = true
		_flush_verbose_logs.call_deferred()

func _log_verbose(message: String) -> void:
	if not enable_verbose_logging:
		return
	_queue_log(message)

func _flush_verbose_logs() -> void:
	_log_flush_queued = false
	for line in _pending_logs:
		print(line)
	_pending_logs.clear()

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
	# Cleared alongside the log it counts — a stale total here would report games
	# from the previous session against the new session_id.
	total_games_recorded = 0
	difficulty_changes.clear()

	# Latency evidence is per-session; carrying samples across a reset would
	# attribute the previous session's measurements to the new one.
	adaptation_latencies_ms.clear()
	adaptation_latency_total_ms = 0.0
	adaptation_latency_samples = 0
	adaptation_latency_max_ms = 0.0

	# Reset flags
	games_since_adaptation = 0
	total_score = 0

	# The supplementary progression ramp is per-session, exactly like
	# current_difficulty above. Left standing, a new session opened in the same
	# process inherited the previous player's escalation and started at up to
	# speed ×2.4 / time_limit 6s / item_count 16 while still labelled "Easy".
	progressive_level = 0
	consecutive_successes = 0

	# Milestone latches are gated on get_behavioral_metrics(), which reads
	# performance_history — cleared just above. Keeping the latches meant the
	# awards could only ever be earned in the first session of a process, and
	# once all three had fired the early-out in _check_behavioral_milestones()
	# disabled milestone checking for every later session.
	_milestones_achieved.clear()

func _generate_session_id() -> String:
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % 10000
	return "WW_%d_%04d" % [timestamp, random_suffix]

func _get_effective_min_games() -> int:
	# Keep adaptation warmup in the 3-5 range while respecting window size.
	var max_allowed = max(1, min(window_size, 5))
	if max_allowed < 3:
		return max_allowed
	return clamp(min_games_before_adaptation, 3, max_allowed)

func _get_lifetime_games_played() -> int:
	# is_inside_tree() is a required precondition, not a defensive null check:
	# get_node_or_null() with an absolute path raises an engine error when called
	# from a detached node instead of returning null. That happens whenever this
	# instance is used outside a live scene tree (verification harnesses, unit
	# tests) or from a deferred callback that lands after a scene swap.
	if is_inside_tree():
		var save_mgr := get_node_or_null("/root/SaveManager")
		if save_mgr and save_mgr.has_method("get_total_games_played"):
			return int(save_mgr.get_total_games_played())
	return total_games_recorded

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
	# Game Lab: a round played to try a mechanic out is not evidence about the
	# player, and the rolling window is the thesis's measurement instrument. Letting
	# a sandbox round in would move the tier the next REAL round is played at.
	if GameManager and GameManager.sandbox_mode:
		return

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
	# STEP 2: Save to research history (bounded — see MAX_PERFORMANCE_HISTORY)
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: Like keeping your recent report cards in a folder, and a running
	#       tally of how many you've ever had so the count is never wrong.
	performance_history.append(performance_data)
	total_games_recorded += 1
	if performance_history.size() > MAX_PERFORMANCE_HISTORY:
		performance_history.pop_front()
	
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
	var required_games = _get_effective_min_games()
	games_since_adaptation += 1
	var ready_to_adapt = (
		games_since_adaptation >= adaptation_frequency
		and performance_window.size() >= required_games)

	# ────────────────────────────────────────────────────────────────────────
	# Close the latency span HERE, before any console logging.
	# ────────────────────────────────────────────────────────────────────────
	# The span used to wrap the whole function, including ~30 print() calls
	# (this function, _print_algorithm_debug, and _log_difficulty_change).
	# On a redirected stdout each print costs several milliseconds, so every
	# single round reported ~145 ms against a 16 ms budget and pushed a warning
	# — 50 of the 60 error/warning lines in a 150 s soak came from this one
	# line. The rolling-window math itself is O(window_size) and lands well
	# inside budget; _adapt_difficulty measures its own decision pass
	# separately, also excluding logging.
	if PerformanceProfiler and _lat_start > 0:
		PerformanceProfiler.end_latency_measurement(
			_lat_start, "AdaptiveDifficulty.add_performance"
		)
		_lat_start = 0

	if ready_to_adapt:
		_log_verbose("\n🔬 ALGORITHM TRIGGERED: Warmup met (%d/%d games). Evaluating Φ..." % [
			performance_window.size(), required_games])
		_adapt_difficulty()  # 🎯 THIS IS WHERE THE ALGORITHM RUNS!
		games_since_adaptation = 0
	else:
		if performance_window.size() < required_games:
			_log_verbose("⏳ Rolling Window: %d/%d games. Need %d more before algorithm activates." % [
				performance_window.size(), required_games,
				required_games - performance_window.size()])
	
	# ────────────────────────────────────────────────────────────────────────
	# STEP 6: Track consecutive successes for PROGRESSIVE DIFFICULTY
	# ────────────────────────────────────────────────────────────────────────
	# ELI5: If the player keeps succeeding at Hard difficulty, we increase the
	#       progressive level, making the game progressively harder — up to
	#       MAX_PROGRESSIVE_LEVEL, past which the round would stop being winnable.
	if accuracy >= 0.8:  # 80%+ accuracy = success
		consecutive_successes += 1
		# Every 3 consecutive successes at Hard difficulty increases progressive level
		var can_level_up: bool = (
			current_difficulty == "Hard"
			and consecutive_successes >= 3
			and progressive_level < MAX_PROGRESSIVE_LEVEL
		)
		if can_level_up:
			progressive_level += 1
			consecutive_successes = 0  # Reset counter
			_queue_log("🔥 PROGRESSIVE LEVEL UP! Now at level %d/%d - Game gets HARDER!" % [
				progressive_level, MAX_PROGRESSIVE_LEVEL])
	else:
		# Failure resets the streak but doesn't decrease progressive level
		consecutive_successes = 0
	
	# Performance logging
	# Wall-clock for this whole call, including signal listeners and the queuing
	# of deferred logs. Deliberately NOT labelled "latency": it is not the
	# adaptation latency the paper's <100 ms claim refers to, and a reader
	# comparing a 742 ms line against that claim would draw the wrong conclusion.
	# The algorithm's own spans are measured separately (see the two
	# end_latency_measurement calls) and surfaced via get_latency_report().
	var elapsed = Time.get_ticks_msec() - start_time
	var lat: Dictionary = get_latency_report()
	if lat["measured"]:
		_log_verbose(
			"⚡ Performance Added (call wall-clock: %dms"
			% elapsed
			+ " | measured adaptation: %.2fms avg, %.2fms max)"
			% [lat["avg_ms"], lat["max_ms"]])
	else:
		_log_verbose(
			"⚡ Performance Added (call wall-clock: %dms"
			% elapsed
			+ " | adaptation not yet measured)")
	
	# Emit algorithm metrics
	algorithm_update.emit(_get_window_metrics())

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
	# ELI5: We need enough warmup games before we can adapt (3-5 configurable).
	#       This gives us enough data to calculate reliable trends!
	var required_games = _get_effective_min_games()
	if performance_window.size() < required_games:
		return  # Not enough data yet, wait for more games

	# Latency span covers only the decision pass (metrics + decision tree +
	# apply), deliberately excluding the print-heavy research logging below.
	# See the note in add_performance(): console I/O dominated the old timing
	# and produced a false budget breach every single round.
	var _decision_lat_start: int = 0
	if PerformanceProfiler:
		_decision_lat_start = PerformanceProfiler.begin_latency_measurement()
	
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

	# Decision pass is complete — close the latency span before the logging
	# block so console I/O is never charged against the algorithm's budget.
	if PerformanceProfiler and _decision_lat_start > 0:
		var measured_ms: float = PerformanceProfiler.end_latency_measurement(
			_decision_lat_start, "AdaptiveDifficulty._adapt_difficulty"
		)
		_record_adaptation_latency(measured_ms)
	
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
	_queue_log("🎮 Session Game #%d (Lifetime: %d) | Φ=%.3f | %s %s %s" % [
		total_games_recorded,
		_get_lifetime_games_played(),
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
	# - 5000 is a FIXED normalization constant taken from the thesis
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
	# Penalty = min(1083.7 / 5000, 0.2) = min(0.217, 0.2) = 0.2 (capped)
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
	# Formula (thesis): CP = min(σ_ms / 5000, 0.2)
	#
	# 5000 is a FIXED normalization constant, NOT the current time limit.
	# It must stay fixed for two reasons:
	#   1. The thesis publishes a worked example (σ = 1140ms → CP = 0.2) that
	#      the artifact has to reproduce exactly.
	#   2. A difficulty-scaled divisor would make CP depend on
	#      current_difficulty, and current_difficulty is itself chosen from Φ.
	#      That feedback loop makes the same player performance yield different
	#      Φ values depending on which tier they happen to be in, which breaks
	#      the determinism the algorithm is supposed to guarantee.
	#
	# Why cap at 0.2? We don't want to penalize TOO harshly (max 20% reduction),
	# which also keeps Φ inside its documented [-0.2, 1.0] range.
	#
	# Example:
	#   σ =  500ms → CP = 500/5000  = 0.10 (10% penalty)
	#   σ = 1000ms → CP = 1000/5000 = 0.20 (20% penalty - at the cap)
	#   σ = 4000ms → CP = min(0.8, 0.2) = 0.20 (capped)
	# ═══════════════════════════════════════════════════════════════════════

	# Normalize standard deviation to penalty range [0.0, 0.2]
	# High σ → High penalty (erratic timing)
	# Low σ → Low penalty (consistent timing)
	var consistency_penalty: float = min(
		std_deviation / CONSISTENCY_PENALTY_NORMALIZER_MS,
		CONSISTENCY_PENALTY_MAX
	)
	
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
	
	if proficiency < PROFICIENCY_THRESHOLD_EASY:
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
	
	elif proficiency > PROFICIENCY_THRESHOLD_HARD:
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

## Public read-only view of the current rolling-window metrics
## (Φ, WMA, CP, σ, and supporting figures).
## Exposed so the algorithm overlay and the thesis verification harness can read
## the live numbers without reaching into private methods.
func get_window_metrics() -> Dictionary:
	return _calculate_window_metrics()

## Public, side-effect-free evaluation of the decision tree for given metrics.
## Returns which difficulty the rules select and why, WITHOUT applying it —
## useful for demonstrating the algorithm and for verification.
func evaluate_decision_tree(metrics: Dictionary) -> Dictionary:
	return _evaluate_decision_tree(metrics)

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

	# Single indexed pass over the retained history.
	#
	# This used to take two performance_history.slice() copies (one per half) and
	# then three more full passes, and it runs once per completed round from
	# _check_behavioral_milestones(). Because performance_history grows with the
	# session, the per-round cost — and the amount of garbage handed to the
	# collector — grew with it, right at the round-end transition.
	#
	# "Retained", not "whole session": past MAX_PERFORMANCE_HISTORY rounds the log
	# holds only the tail, so learning_velocity then compares the older half of
	# the retained window against the newer half rather than session start against
	# session end. That bound is ~500 rounds and every milestone here is a one-shot
	# latch, so in practice they have all fired long before trimming begins.
	var count: int = performance_history.size()
	var half_idx: int = int(count / 2.0)
	var first_sum: float = 0.0
	var second_sum: float = 0.0
	var total_quality: float = 0.0
	var persistence: int = 0

	for i in range(count):
		var perf: Dictionary = performance_history[i]
		var acc: float = perf["accuracy"]
		if i < half_idx:
			first_sum += acc
		else:
			second_sum += acc
		total_quality += acc / max(perf["reaction_time"] / 1000.0, 0.1)
		# Persistence = rounds played after a failure. The original counted i in
		# [1, count) whose predecessor failed, which is the same as counting
		# failures among the first count-1 entries.
		if i < count - 1 and acc < 0.5:
			persistence += 1

	var first_avg: float = first_sum / float(half_idx) if half_idx > 0 else 0.0
	var second_count: int = count - half_idx
	var second_avg: float = second_sum / float(second_count) if second_count > 0 else 0.0
	var learning_velocity: float = second_avg - first_avg
	var decision_quality: float = total_quality / float(count)

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
		"total_games": total_games_recorded,
		"current_streak": _calculate_current_streak()
	}

func _calculate_current_streak() -> int:
	var streak = 0
	for i in range(performance_history.size() - 1, -1, -1):
		if performance_history[i]["accuracy"] >= 0.7:
			streak += 1
		else:
			break
	return streak

## All behavioural milestones, each a one-shot latch.
##
## Listed so _check_behavioral_milestones() can tell when every one has fired and
## stop recomputing metrics it will never act on again.
const BEHAVIORAL_MILESTONES: Array[String] = [
	"mastery_achieved",
	"persistence_award",
	"speed_demon",
]

func _check_behavioral_milestones() -> void:
	# Every milestone below is a one-shot latch, so once all three have fired
	# there is no outcome this function can produce. It is called after every
	# completed round, and get_behavioral_metrics() walks the entire session
	# history — so without this early-out a long session pays a growing scan at
	# each round-end purely to re-derive numbers that are already spoken for.
	if _milestones_achieved.size() >= BEHAVIORAL_MILESTONES.size():
		return

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

## The paper's declared tier outputs for the current difficulty, with no
## progression layer applied.
##
## get_difficulty_settings() returns *applied* values — the tier settings after
## the supplementary progression ramp is folded in — which is what gameplay wants
## but is NOT what the paper's Output Specification table declares. Verification
## and defence demos should read this accessor, so the declared contract
## (speed_multiplier ∈ {0.7, 1.0, 1.5}, time_limit ∈ {10, 15, 20}) can be shown
## exactly as published without the ramp confusing the numbers.
func get_paper_difficulty_settings() -> Dictionary:
	return DIFFICULTY_SETTINGS[current_difficulty].duplicate(true)

## Tier settings with the supplementary progression ramp applied.
##
## The returned speed_multiplier/time_limit are deliberately NOT the paper's
## declared sets once progressive_level > 0 — see get_paper_difficulty_settings()
## for those. The ramp is an extra mastery reward layered on top of the algorithm,
## not part of it: it reads no window metrics and feeds nothing back into Φ or the
## tier decision.
func get_difficulty_settings() -> Dictionary:
	var base_settings = DIFFICULTY_SETTINGS[current_difficulty].duplicate()

	# Apply the supplementary progression ramp (bounded — see MAX_PROGRESSIVE_LEVEL)
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
	var required_games = _get_effective_min_games()
	var session_games = total_games_recorded
	var lifetime_games = _get_lifetime_games_played()
	
	var status = {
		# Current State
		"current_difficulty": current_difficulty,
		"games_in_window": performance_window.size(),
		"games_until_next_adaptation": max(0, adaptation_frequency - games_since_adaptation),
		"total_games_played": session_games,
		"session_games_played": session_games,
		"lifetime_games_played": lifetime_games,
		"min_games_before_adaptation": required_games,
		"games_until_algorithm_activation": max(0, required_games - performance_window.size()),
		
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
		"algorithm_active": performance_window.size() >= required_games
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
	if performance_window.size() < required_games:
		var games_left = required_games - performance_window.size()
		status["status_message"] = (
			"Rolling Window: %d/%d games collected."
			+ " Play %d more to fill window and activate algorithm."
		) % [performance_window.size(), required_games, games_left]
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

## Trajectory summary of every difficulty decision recorded this session.
##
## Pure aggregation of difficulty_changes, which _adapt_difficulty() appends to on
## every evaluation. Nothing here is recomputed, inferred or estimated.
##
## It exists because the two fields an examiner reads first - final_difficulty and
## window_metrics - are both INSTANTANEOUS samples of the last window, and a
## session that held Hard for forty consecutive games and then had the player
## abandon four rounds exports final_difficulty = "Easy". Measured over the 48
## case studies in user://: final_difficulty reads Easy in 38 and Medium in 10 and
## Hard in none, while the difficulty_timeline arrays inside those same 48 files
## contain 129 Hard decisions, including one unbroken 41-evaluation Hard streak.
## The export contradicted itself; this is the field that resolves it.
func get_difficulty_progression() -> Dictionary:
	var order: Array[String] = ["Easy", "Medium", "Hard"]
	var counts: Dictionary = {"Easy": 0, "Medium": 0, "Hard": 0}
	var longest: Dictionary = {"Easy": 0, "Medium": 0, "Hard": 0}
	var first_at: Dictionary = {"Easy": null, "Medium": null, "Hard": null}
	var sequence: PackedStringArray = PackedStringArray()
	var transitions: int = 0
	var phi_min: float = INF
	var phi_max: float = -INF
	var phi_above_hard: int = 0
	var run_tier: String = ""
	var run_len: int = 0

	for i in range(difficulty_changes.size()):
		var entry: Dictionary = difficulty_changes[i]
		var tier: String = str(entry.get("new_difficulty", ""))
		if not counts.has(tier):
			continue
		counts[tier] = int(counts[tier]) + 1
		if first_at[tier] == null:
			# 1-based index into the evaluation sequence: "reached on the Nth
			# evaluated game", which is the form a results chapter quotes.
			first_at[tier] = i + 1
		sequence.append(tier.substr(0, 1))
		if str(entry.get("old_difficulty", "")) != tier:
			transitions += 1
		if tier == run_tier:
			run_len += 1
		else:
			run_tier = tier
			run_len = 1
		if run_len > int(longest[tier]):
			longest[tier] = run_len
		var m: Dictionary = entry.get("metrics", {})
		if m.has("proficiency_index"):
			var phi: float = float(m["proficiency_index"])
			phi_min = minf(phi_min, phi)
			phi_max = maxf(phi_max, phi)
			if phi > PROFICIENCY_THRESHOLD_HARD:
				phi_above_hard += 1

	var reached: Array[String] = []
	var peak = null
	for t in order:
		if int(counts[t]) > 0:
			reached.append(t)
			peak = t

	var has_phi: bool = phi_max > -INF
	return {
		"evaluations": difficulty_changes.size(),
		"tiers_reached": reached,
		# The single claim a defence has to make about the decision tree.
		"all_three_tiers_reached": reached.size() == order.size(),
		"decisions_per_tier": counts,
		"longest_consecutive_per_tier": longest,
		"first_reached_at_evaluation": first_at,
		"peak_difficulty": peak,
		"tier_transitions": transitions,
		# Instantaneous, NOT a summary: the tier the last evaluated window landed on.
		"final_difficulty": current_difficulty,
		"tier_sequence": ">".join(sequence),
		# null, not 0.0, when no evaluation has run: an unmeasured range must not
		# read as a measured one.
		"phi_min": (phi_min if has_phi else null),
		"phi_max": (phi_max if has_phi else null),
		"phi_above_hard_threshold": phi_above_hard,
		"easy_threshold": PROFICIENCY_THRESHOLD_EASY,
		"hard_threshold": PROFICIENCY_THRESHOLD_HARD
	}


func export_complete_session() -> Dictionary:
	var session_data = {
		"session_id": session_id,
		"timestamp": Time.get_unix_time_from_system(),
		"session_duration": Time.get_unix_time_from_system() - session_start_time,
		
		# Gameplay Data
		"gameplay": {
			"total_games_played": total_games_recorded,
			"total_score": total_score,
			"performance_history": performance_history,
			# Flags whether the log above is the full session or only its tail, so
			# an analyst reading the export can never mistake a trimmed log for a
			# complete one.
			"performance_history_capped": (
				performance_history.size() >= MAX_PERFORMANCE_HISTORY
			),
			"performance_history_retained": performance_history.size(),
			"difficulty_timeline": difficulty_changes,
			"behavioral_metrics": get_behavioral_metrics(),
			"final_difficulty": current_difficulty,
			# final_difficulty above is one instantaneous sample. The trajectory it
			# came from is what actually evidences the three-tier decision tree.
			"difficulty_progression": get_difficulty_progression(),
			"window_metrics": _get_window_metrics()
		},
		
		# Algorithm Performance
		"algorithm_stats": {
			"total_adaptations": difficulty_changes.size(),
			# Measured, not estimated. -1.0 means no adaptation ran this
			# session, so there is nothing to report.
			"avg_latency_ms": _calculate_avg_latency(),
			"latency": get_latency_report(),
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
	# Mean of REAL measured adaptation-pass durations. Returns -1.0 when no
	# adaptation has run yet so consumers can tell "not measured" apart from
	# "measured as fast", rather than reading a fabricated 0 or target value.
	if adaptation_latency_samples <= 0:
		return -1.0
	return adaptation_latency_total_ms / float(adaptation_latency_samples)

## Record one measured adaptation-pass duration (milliseconds).
## Running sum/count/max are kept separately from the sample array so the
## reported statistics stay exact after the array is trimmed.
func _record_adaptation_latency(elapsed_ms: float) -> void:
	if elapsed_ms < 0.0:
		return
	adaptation_latency_total_ms += elapsed_ms
	adaptation_latency_samples += 1
	if elapsed_ms > adaptation_latency_max_ms:
		adaptation_latency_max_ms = elapsed_ms
	adaptation_latencies_ms.append(elapsed_ms)
	if adaptation_latencies_ms.size() > MAX_LATENCY_SAMPLES:
		adaptation_latencies_ms.pop_front()

## Honest latency report for the thesis. All figures are measured; the only
## declared value is the target the measurements are compared against.
func get_latency_report() -> Dictionary:
	var measured: bool = adaptation_latency_samples > 0
	var avg: float = _calculate_avg_latency()
	return {
		"measured": measured,
		"samples": adaptation_latency_samples,
		"avg_ms": avg,
		"max_ms": adaptation_latency_max_ms if measured else -1.0,
		"target_ms": target_latency_ms,
		# Only meaningful when measured; explicitly false otherwise so an
		# unmeasured session can never read as a passing result.
		"within_target": measured and avg >= 0.0 and avg < target_latency_ms
	}

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
	return total_games_recorded

func get_performance_history() -> Array:
	return performance_history.duplicate()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOGGING SYSTEM (Research Documentation)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _log_system_start() -> void:
	if not enable_research_logging:
		return
	
	var required_games = _get_effective_min_games()

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🎮 WATERWISE ADAPTIVE DIFFICULTY SYSTEM")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📋 Session ID: %s" % session_id)
	print("🕐 Started: %s" % Time.get_datetime_string_from_unix_time(session_start_time))
	print("🔬 Algorithm: Rule-Based Rolling Window")
	print("📏 Window Size: %d games" % window_size)
	print("🚀 Warmup Start: %d games" % required_games)
	print("⚡ Adaptation: Every %d games" % adaptation_frequency)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

func _log_difficulty_change(change_data: Dictionary) -> void:
	if not enable_research_logging:
		return

	var metrics = change_data["metrics"]

	# Deferred, not printed inline. This block runs only on a tier change, which
	# is exactly when the results screen is tearing down and the next minigame is
	# loading. ~20 synchronous print() calls there cost 464–754 ms of main-thread
	# time in a 150 s soak (measured), stalling the transition on the frame the
	# player is waiting on. The output is unchanged — it flushes after the frame.
	_queue_log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	_queue_log("📊 ADAPTIVE DIFFICULTY UPDATE (Formative)")
	_queue_log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	_queue_log("🔬 Algorithm: Rule-Based Rolling Window")
	_queue_log("📏 Window: %d/%d games" % [metrics["window_size"], window_size])
	_queue_log("")
	_queue_log("📈 Performance Metrics:")
	_queue_log("  • Success Rate: %.1f%%" % metrics["success_rate"])
	_queue_log("  • Avg Time: %.1fs" % metrics["avg_time"])
	_queue_log("  • Avg Mistakes: %.1f" % metrics["avg_mistakes"])
	_queue_log("  • Total Errors: %d" % metrics["total_errors"])
	_queue_log("")
	_queue_log("🌳 Decision Tree:")
	for path in change_data["decision_path"]:
		_queue_log("  %s" % path)
	_queue_log("")
	_queue_log("🎯 Difficulty: %s → %s" % [change_data["old_difficulty"], change_data["new_difficulty"]])
	_queue_log("💡 Reason: %s" % change_data["reason"])

	if change_data["new_difficulty"] == "Hard":
		var settings = DIFFICULTY_SETTINGS["Hard"]
		_queue_log("🎪 CHAOS EFFECTS: %s" % str(settings["chaos_effects"]))

	_queue_log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# POST-TEST (Summative Assessment)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var _posttest_active: bool = false
var _posttest_start_time: float = 0.0
var _posttest_answers: Dictionary = {}  # {question_id: answered_index}

const _POSTTEST_QUESTIONS: Array = [
	{
		"id": "q_leaking_tap",
		"category": "conceptual",
		"question": "How much water can a dripping tap waste per day?",
		"options": ["1 liter", "5 liters", "15 liters", "50 liters"],
		"correct_answer": 2
	},
	{
		"id": "q_best_bath",
		"category": "behavioral",
		"question": "What is the most water-efficient way to bathe?",
		"options": [
			"Long hot bath",
			"5-minute shower",
			"20-minute shower",
			"Filling the tub halfway"
		],
		"correct_answer": 1
	},
	{
		"id": "q_greywater",
		"category": "application",
		"question": "Which water is safe to reuse for watering plants?",
		"options": [
			"Toilet flush water",
			"Water from washing vegetables",
			"Water from sewage",
			"Water mixed with bleach"
		],
		"correct_answer": 1
	},
	{
		"id": "q_rainwater",
		"category": "application",
		"question": "How can rainwater best be collected for household use?",
		"options": [
			"Let it run into the drain",
			"Collect it in a covered barrel",
			"Mix it with saltwater",
			"Use it only for cooking"
		],
		"correct_answer": 1
	},
	{
		"id": "q_water_cycle",
		"category": "conceptual",
		"question": "What process returns evaporated water back to Earth as rain?",
		"options": ["Water cycle", "Water recycling", "Hydration loop", "Aquifer refill"],
		"correct_answer": 0
	},
	{
		"id": "q_brushing_teeth",
		"category": "behavioral",
		"question": "When should you turn off the tap while brushing your teeth?",
		"options": [
			"Never",
			"Only when done",
			"While brushing",
			"Only when applying toothpaste"
		],
		"correct_answer": 2
	},
	{
		"id": "q_dual_flush",
		"category": "application",
		"question": "Which toilet feature saves the most water per flush?",
		"options": [
			"Dual-flush button",
			"Older single-flush",
			"Flushing twice",
			"Not flushing at all"
		],
		"correct_answer": 0
	},
	{
		"id": "q_plant_watering",
		"category": "behavioral",
		"question": "When is the best time to water plants to reduce evaporation loss?",
		"options": [
			"Midday in direct sunlight",
			"Early morning or evening",
			"During heavy rain",
			"Midnight only"
		],
		"correct_answer": 1
	},
	{
		"id": "q_pipe_leak",
		"category": "retention",
		"question": "What should you do when you discover a leaking pipe at home?",
		"options": [
			"Ignore it",
			"Cover it with tape permanently",
			"Report and repair it promptly",
			"Open other taps wider"
		],
		"correct_answer": 2
	},
	{
		"id": "q_water_scarcity",
		"category": "retention",
		"question": "Why is water conservation important in the Philippines?",
		"options": [
			"Water is too expensive to waste",
			"Some communities lack clean water access",
			"Water makes floors slippery",
			"Water is only used for electricity"
		],
		"correct_answer": 1
	}
]

func start_posttest() -> void:
	_posttest_active = true
	_posttest_start_time = Time.get_unix_time_from_system()
	_posttest_answers.clear()

func get_posttest_questions() -> Array:
	return _POSTTEST_QUESTIONS.duplicate(true)

func submit_posttest_answer(question_id: String, answer_index: int) -> void:
	_posttest_answers[question_id] = answer_index

func get_posttest_results() -> Dictionary:
	var correct: int = 0
	var total: int = _POSTTEST_QUESTIONS.size()
	var categories: Dictionary = {
		"conceptual": {"correct": 0, "total": 0},
		"application": {"correct": 0, "total": 0},
		"retention": {"correct": 0, "total": 0},
		"behavioral": {"correct": 0, "total": 0}
	}

	for q in _POSTTEST_QUESTIONS:
		var cat: String = str(q.get("category", "conceptual"))
		if not categories.has(cat):
			categories[cat] = {"correct": 0, "total": 0}
		categories[cat]["total"] += 1
		if _posttest_answers.has(q["id"]):
			if _posttest_answers[q["id"]] == q["correct_answer"]:
				correct += 1
				categories[cat]["correct"] += 1

	var percentage := (float(correct) / float(total)) * 100.0 if total > 0 else 0.0

	var breakdown: Dictionary = {}
	for cat in categories:
		var cat_total: int = categories[cat]["total"]
		breakdown[cat] = (
			(float(categories[cat]["correct"]) / float(cat_total)) * 100.0
			if cat_total > 0 else 0.0
		)

	return {
		"correct_answers": correct,
		"total_questions": total,
		"percentage": percentage,
		"category_breakdown": breakdown
	}

## How closely this player's gameplay accuracy and posttest knowledge score agree.
##
## Deliberately NOT called a correlation, and deliberately not reported as Pearson r.
## Pearson r is defined over N paired observations across a sample; both of its
## variance terms are zero for a single participant, so r is undefined here — there
## is no sample to correlate, only one player's two scores. This screen used to print
## the value below as "Correlation (r)", which would not survive the first question
## about how it was computed.
##
## What it actually is: both scores are put on [0,1] and their gap is scaled so that
## identical scores give 1.0, a 50-point gap gives 0.0, and a 100-point gap gives
## -1.0. That is a legitimate agreement index for one learner's feedback screen —
## "did your play match what you retained" — and it is presented as exactly that.
##
## A real correlation for the study has to be computed across participants from the
## exported session data (see export_session_data()), not in-game from one session.
func calculate_knowledge_alignment() -> Dictionary:
	var gameplay_perf := 0.0
	if performance_history.size() > 0:
		var acc_sum := 0.0
		for p in performance_history:
			acc_sum += float(p.get("accuracy", 0.0))
		gameplay_perf = (acc_sum / float(performance_history.size())) * 100.0

	var results := get_posttest_results()
	var posttest_knowledge: float = results["percentage"]

	var gp_norm := gameplay_perf / 100.0
	var pk_norm := posttest_knowledge / 100.0
	var alignment := 0.0
	if gameplay_perf > 0.0 or posttest_knowledge > 0.0:
		alignment = clampf(1.0 - absf(gp_norm - pk_norm) * 2.0, -1.0, 1.0)

	# Signed, not absolute. The ladder used to test absf(alignment), which made the
	# worst possible result read as the best: 5% gameplay against a 95% posttest is a
	# 0.9 gap, i.e. alignment -0.8, and absf() promoted that to "Strong". A negative
	# alignment means the two measures disagree, which is its own finding and must
	# never be reported as agreement.
	var interpretation: String
	if alignment >= 0.7:
		interpretation = "Gameplay closely matches water conservation knowledge"
	elif alignment >= 0.4:
		interpretation = "Gameplay moderately matches knowledge"
	elif alignment >= 0.0:
		interpretation = "Gameplay and knowledge only loosely match — more practice recommended"
	else:
		interpretation = "Gameplay and knowledge scores disagree — worth reviewing both"

	return {
		"gameplay_performance": gameplay_perf,
		"posttest_knowledge": posttest_knowledge,
		"alignment_index": alignment,
		"interpretation": interpretation
	}
