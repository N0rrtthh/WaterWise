extends Node

## ═══════════════════════════════════════════════════════════════════
## ADAPTIVE DIFFICULTY SYSTEM - DUAL ASSESSMENT MODE
## ═══════════════════════════════════════════════════════════════════
## Research-Validated Educational Game System
## Combines Formative (Gameplay) + Summative (Post-Test) Assessment
## Algorithm: Rule-Based Decision Tree with Rolling Window
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS (Event-Driven Architecture)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Formative Assessment Signals
signal difficulty_changed(old_level: String, new_level: String, reason: String)
signal performance_added(accuracy: float, time: int, mistakes: int)
signal behavioral_milestone(milestone: String, data: Dictionary)
signal algorithm_update(metrics: Dictionary)

## Summative Assessment Signals
signal posttest_unlocked()
signal posttest_question_answered(question_id: int, correct: bool, time_taken: float)
signal posttest_completed(score: int, total: int, percentage: float)
signal correlation_calculated(gameplay_perf: float, test_score: float, correlation: float)

## Research Data Signals
signal session_data_ready(data: Dictionary)
signal case_study_exported(file_path: String)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Rolling Window Configuration
@export_category("Algorithm Settings")
@export var window_size: int = 3  # Changed from 5 to 3 for faster adaptation
@export var adaptation_frequency: int = 2  # Every N games (adjusted for smaller window)
@export var min_games_before_adaptation: int = 2  # Adjusted for smaller window
@export var target_latency_ms: float = 100.0

## Post-Test Unlock Conditions
@export_category("Post-Test Settings")
@export var posttest_min_score: int = 1000
@export var posttest_min_games: int = 15
@export var total_posttest_questions: int = 15

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
var current_difficulty: String = "Easy"  # Easy, Medium, Hard

## Performance Tracking (Formative Assessment)
var performance_window: Array[Dictionary] = []  # Last 5 games (FIFO)
var performance_history: Array[Dictionary] = []  # All games
var difficulty_changes: Array[Dictionary] = []  # Timeline of changes
var games_since_adaptation: int = 0

## Post-Test Tracking (Summative Assessment)
var posttest_unlocked_flag: bool = false
var posttest_started: bool = false
var posttest_completed_flag: bool = false
var posttest_answers: Array[Dictionary] = []
var posttest_start_time: int = 0
var current_question_start_time: int = 0

## Correlation Data
var gameplay_performance_score: float = 0.0
var posttest_knowledge_score: float = 0.0
var correlation_coefficient: float = 0.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DIFFICULTY SETTINGS (CHAOS SYSTEM)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const DIFFICULTY_SETTINGS = {
	"Easy": {
		"speed_multiplier": 0.7,
		"time_limit": 20,
		"task_complexity": 1,
		"hints": 3,
		"visual_guidance": true,
		"distractors": 1,
		"item_count": 3,
		"chaos_effects": []
	},
	"Medium": {
		"speed_multiplier": 1.0,
		"time_limit": 15,
		"task_complexity": 2,
		"hints": 2,
		"visual_guidance": false,
		"distractors": 2,
		"item_count": 5,
		"chaos_effects": ["screen_shake_mild"]
	},
	"Hard": {
		"speed_multiplier": 1.5,
		"time_limit": 10,
		"task_complexity": 3,
		"hints": 1,
		"visual_guidance": false,
		"distractors": 3,
		"item_count": 8,
		"chaos_effects": [
			"screen_shake_heavy",
			"mud_splatters",
			"buzzing_fly",
			"control_reverse",
			"visual_obstruction"
		]
	}
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# POST-TEST QUESTION BANK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var posttest_questions = [
	{
		"id": 1,
		"category": "conceptual",
		"question": "Bakit importante ang pag-save ng tubig sa bahay?",
		"options": [
			"Para mabawasan lang ang water bill",
			"Para may tubig pa sa future generations",
			"Para hindi maubos ang tubig sa reservoir",
			"Lahat ng nabanggit"
		],
		"correct_answer": 3,
		"related_minigame": "WaterPlant",
		"difficulty": "easy"
	},
	{
		"id": 2,
		"category": "application",
		"question": "Ano ang TAMANG paraan ng pag-dilig ng halaman?",
		"options": [
			"Gumamit ng hose at bukas nang matagal",
			"Gumamit ng timba o watering can",
			"Hayaan lang ang ulan",
			"Diretso sa ugat gamit ang gripo"
		],
		"correct_answer": 1,
		"related_minigame": "WaterPlant",
		"difficulty": "easy"
	},
	{
		"id": 3,
		"category": "retention",
		"question": "Ilang balde ang DAPAT gamitin para makatipid ng tubig sa paglilinis?",
		"options": [
			"1 balde lang",
			"2-3 balde",
			"5 balde o higit pa",
			"Walang limitasyon"
		],
		"correct_answer": 1,
		"related_minigame": "BucketChallenge",
		"difficulty": "medium"
	},
	{
		"id": 4,
		"category": "conceptual",
		"question": "Ano ang epekto ng sobrang paggamit ng tubig sa kapaligiran?",
		"options": [
			"Walang epekto",
			"Nakakatulong sa ekonomiya",
			"Nauubos ang natural water sources",
			"Mas maraming ulan"
		],
		"correct_answer": 2,
		"related_minigame": "General",
		"difficulty": "medium"
	},
	{
		"id": 5,
		"category": "application",
		"question": "Nakakita ka ng tumutulo na gripo. Ano ang DAPAT mong gawin?",
		"options": [
			"Hayaan lang kasi konti lang naman",
			"Sabihin sa magulang/landlord agad",
			"Lagyan ng tali",
			"Wala akong pakialam"
		],
		"correct_answer": 1,
		"related_minigame": "FixLeak",
		"difficulty": "easy"
	},
	{
		"id": 6,
		"category": "retention",
		"question": "Sa laro, ano ang nangyari kapag masyadong maraming tubig ang ginamit?",
		"options": [
			"Nanalo ka",
			"Nabawasan ang score",
			"Walang nangyari",
			"Nag-level up"
		],
		"correct_answer": 1,
		"related_minigame": "General",
		"difficulty": "easy"
	},
	{
		"id": 7,
		"category": "application",
		"question": "Anong oras ang PINAKAMAINAM para magdilig ng halaman?",
		"options": [
			"Tanghali (12nn)",
			"Hapon (3pm)",
			"Umaga (6-8am) o gabi (6-8pm)",
			"Anumang oras"
		],
		"correct_answer": 2,
		"related_minigame": "WaterPlant",
		"difficulty": "hard"
	},
	{
		"id": 8,
		"category": "conceptual",
		"question": "Magkano ang average na nawawalang tubig sa isang tumutulo na gripo per day?",
		"options": [
			"1 litro",
			"5 litro",
			"20-30 litro",
			"100 litro"
		],
		"correct_answer": 2,
		"related_minigame": "FixLeak",
		"difficulty": "hard"
	},
	{
		"id": 9,
		"category": "behavioral",
		"question": "After ng laro, ano ang plano mong gawin sa bahay?",
		"options": [
			"Wala, laro lang ito",
			"Magtitipid ng tubig sa pagliligo",
			"Turuan ang pamilya tungkol sa water conservation",
			"Pareho ng B at C"
		],
		"correct_answer": 3,
		"related_minigame": "General",
		"difficulty": "medium"
	},
	{
		"id": 10,
		"category": "application",
		"question": "May nakita kang bukas na gripo na walang gumagamit. Ano ang gagawin mo?",
		"options": [
			"Pabayaan kasi hindi ko naman gripo",
			"Isara agad",
			"Maglaro sa tubig",
			"Kumuha ng picture"
		],
		"correct_answer": 1,
		"related_minigame": "FixLeak",
		"difficulty": "easy"
	},
	{
		"id": 11,
		"category": "retention",
		"question": "Sa mini-game, ano ang natutunan mo tungkol sa paggamit ng timba?",
		"options": [
			"Mas mahal ang timba kaysa hose",
			"Mas nakakatipid ng tubig ang timba",
			"Pareho lang",
			"Mas mabilis ang hose"
		],
		"correct_answer": 1,
		"related_minigame": "BucketChallenge",
		"difficulty": "medium"
	},
	{
		"id": 12,
		"category": "conceptual",
		"question": "Ano ang ibig sabihin ng 'sustainable water use'?",
		"options": [
			"Gumamit ng maraming tubig",
			"Gumamit ng sapat lang para sa pangangailangan",
			"Hindi gumamit ng tubig",
			"Gumamit ng tubig para sa negosyo"
		],
		"correct_answer": 1,
		"related_minigame": "General",
		"difficulty": "hard"
	},
	{
		"id": 13,
		"category": "application",
		"question": "Paano makakatipid ng tubig sa paglilinis ng bahay?",
		"options": [
			"Gumamit ng hose buong araw",
			"Gumamit ng basang basahan at timba",
			"Hindi na maglinis",
			"Gumamit ng maraming sabon"
		],
		"correct_answer": 1,
		"related_minigame": "BucketChallenge",
		"difficulty": "medium"
	},
	{
		"id": 14,
		"category": "behavioral",
		"question": "Ikaw ba ay magtutuloy sa pagtitipid ng tubig pagkatapos ng laro?",
		"options": [
			"Hindi, nakalimutan ko na",
			"Siguro, kapag may time",
			"Oo, simula ngayon",
			"Hindi ko alam"
		],
		"correct_answer": 2,
		"related_minigame": "General",
		"difficulty": "easy"
	},
	{
		"id": 15,
		"category": "conceptual",
		"question": "Ano ang PANGUNAHING mensahe ng laro?",
		"options": [
			"Maglaro nang mabilis",
			"Kumita ng mataas na score",
			"Magtipid ng tubig para sa kinabukasan",
			"Makakuha ng achievements"
		],
		"correct_answer": 2,
		"related_minigame": "General",
		"difficulty": "easy"
	}
]

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
	posttest_answers.clear()
	
	# Reset flags
	posttest_unlocked_flag = false
	posttest_started = false
	posttest_completed_flag = false
	games_since_adaptation = 0
	total_score = 0
	
	# Shuffle questions for variety
	posttest_questions.shuffle()

func _generate_session_id() -> String:
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % 10000
	return "WW_%d_%04d" % [timestamp, random_suffix]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FORMATIVE ASSESSMENT - PERFORMANCE TRACKING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Add performance data from a completed mini-game
func add_performance(accuracy: float, reaction_time: int, mistakes: int, game_name: String = "") -> void:
	var start_time = Time.get_ticks_msec()
	
	var performance_data = {
		"accuracy": clamp(accuracy, 0.0, 1.0),
		"reaction_time": reaction_time,
		"mistakes": mistakes,
		"timestamp": Time.get_unix_time_from_system(),
		"difficulty": current_difficulty,
		"game_name": game_name
	}
	
	# Add to history (complete record)
	performance_history.append(performance_data)
	
	# Add to rolling window (FIFO - max 5)
	performance_window.append(performance_data)
	if performance_window.size() > window_size:
		performance_window.pop_front()
	
	# Update total score
	var difficulty_multiplier = 1.0
	if current_difficulty == "Medium":
		difficulty_multiplier = 1.5
	elif current_difficulty == "Hard":
		difficulty_multiplier = 2.0
	var points = int(accuracy * 100 * difficulty_multiplier)
	total_score += points
	
	# Emit signal
	performance_added.emit(accuracy, reaction_time, mistakes)
	
	# Check for behavioral milestones
	_check_behavioral_milestones()
	
	# Adapt difficulty if needed
	games_since_adaptation += 1
	if games_since_adaptation >= adaptation_frequency and performance_window.size() >= min_games_before_adaptation:
		_adapt_difficulty()
		games_since_adaptation = 0
	
	# Check if post-test should be unlocked
	_check_posttest_unlock()
	
	# Performance logging
	var elapsed = Time.get_ticks_msec() - start_time
	if enable_verbose_logging:
		print("⚡ Performance Added (Latency: %dms)" % elapsed)
	
	# Emit algorithm metrics
	algorithm_update.emit(_get_window_metrics())

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RULE-BASED ALGORITHM - ROLLING WINDOW DECISION TREE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _adapt_difficulty() -> void:
	if performance_window.size() < min_games_before_adaptation:
		return
	
	var old_difficulty = current_difficulty
	var metrics = _calculate_window_metrics()
	var decision_tree = _evaluate_decision_tree(metrics)
	
	# Apply decision
	current_difficulty = decision_tree["new_difficulty"]
	
	# Log the change
	var change_data = {
		"timestamp": Time.get_unix_time_from_system(),
		"old_difficulty": old_difficulty,
		"new_difficulty": current_difficulty,
		"reason": decision_tree["reason"],
		"metrics": metrics,
		"decision_path": decision_tree["path"]
	}
	difficulty_changes.append(change_data)
	
	# Emit signal if changed
	if old_difficulty != current_difficulty:
		difficulty_changed.emit(old_difficulty, current_difficulty, decision_tree["reason"])
		
		if enable_research_logging:
			_log_difficulty_change(change_data)
	
	# ═══════════════════════════════════════════════════════════════════════
	# VISUAL ALGORITHM DEBUGGING (Always print, for research visibility)
	# ═══════════════════════════════════════════════════════════════════════
	_print_algorithm_debug(metrics, decision_tree, old_difficulty)

func _print_algorithm_debug(metrics: Dictionary, decision: Dictionary, old_difficulty: String) -> void:
	"""
	Prints a visual debug box showing the algorithm state after each adaptation.
	This helps researchers verify the algorithm is working correctly.
	"""
	var phi = metrics.get("proficiency_index", 0.0)
	var wma = metrics.get("weighted_accuracy", 0.0)
	var penalty = metrics.get("consistency_penalty", 0.0)
	var sigma = metrics.get("std_deviation", 0.0)
	var new_diff = decision.get("new_difficulty", "Medium")
	var reason = decision.get("reason", "")
	
	# Build window accuracy string
	var window_acc_str = ""
	for i in range(performance_window.size()):
		var acc = performance_window[i]["accuracy"]
		var weight = i + 1
		if i > 0:
			window_acc_str += ", "
		window_acc_str += "%.0f%% (w=%d)" % [acc * 100, weight]
	
	# Difficulty indicator
	var difficulty_arrow = ""
	if old_difficulty != new_diff:
		if (old_difficulty == "Easy" and new_diff == "Medium") or (old_difficulty == "Medium" and new_diff == "Hard"):
			difficulty_arrow = "  ⬆️ HARDER"
		elif (old_difficulty == "Hard" and new_diff == "Medium") or (old_difficulty == "Medium" and new_diff == "Easy"):
			difficulty_arrow = "  ⬇️ EASIER"
		else:
			difficulty_arrow = "  🔄 CHANGE"
	else:
		difficulty_arrow = "  ➡️ MAINTAIN"
	
	# Print the debug box
	print("")
	print("╔══════════════════════════════════════════════════════════════════════════╗")
	print("║        🎮 ADAPTIVE DIFFICULTY ALGORITHM - VISUAL DEBUG                  ║")
	print("╠══════════════════════════════════════════════════════════════════════════╣")
	print("║  Game Count: %d games in window (of %d max)                              ║" % [performance_window.size(), self.window_size])
	print("╠──────────────────────────────────────────────────────────────────────────╣")
	print("║  📊 ROLLING WINDOW ACCURACY (Weighted):                                  ║")
	print("║  [%s]" % window_acc_str)
	print("╠──────────────────────────────────────────────────────────────────────────╣")
	print("║  🧮 PROFICIENCY INDEX CALCULATION:                                       ║")
	print("║                                                                          ║")
	print("║     Φ (Phi) = WMA - CP                                                   ║")
	print("║                                                                          ║")
	print("║     WMA (Weighted Moving Average) = %.4f                                ║" % wma)
	print("║     σ (Standard Deviation)        = %.1f ms                             ║" % sigma)
	print("║     CP (Consistency Penalty)      = min(σ/5000, 0.2) = %.4f            ║" % penalty)
	print("║                                                                          ║")
	print("║     Φ = %.4f - %.4f = %.4f                                          ║" % [wma, penalty, phi])
	print("╠──────────────────────────────────────────────────────────────────────────╣")
	print("║  🎯 DECISION TREE:                                                       ║")
	print("║                                                                          ║")
	print("║     Φ < 0.50  → Easy   (Struggling/Erratic)                             ║")
	print("║     Φ > 0.85  → Hard   (Mastery)                                        ║")
	print("║     else      → Medium (Flow State)                                     ║")
	print("║                                                                          ║")
	print("║     Current Φ = %.4f                                                    ║" % phi)
	if phi < 0.5:
		print("║     [✓] Φ < 0.50 = TRUE  → EASY                                         ║")
	elif phi > 0.85:
		print("║     [✓] Φ > 0.85 = TRUE  → HARD                                         ║")
	else:
		print("║     [✓] 0.50 ≤ Φ ≤ 0.85  → MEDIUM                                       ║")
	print("╠──────────────────────────────────────────────────────────────────────────╣")
	print("║  📈 RESULT: %s → %s%s" % [old_difficulty.to_upper(), new_diff.to_upper(), difficulty_arrow])
	print("║                                                                          ║")
	print("║  💬 %s" % reason.substr(0, 60))
	if reason.length() > 60:
		print("║     %s" % reason.substr(60))
	print("╚══════════════════════════════════════════════════════════════════════════╝")
	print("")

func _calculate_window_metrics() -> Dictionary:
	"""
	╔════════════════════════════════════════════════════════════════════════╗
	║ WEIGHTED PROFICIENCY INDEX WITH CONSISTENCY PENALTY                    ║
	║ Research-Based Mathematical Model for Adaptive Difficulty              ║
	╚════════════════════════════════════════════════════════════════════════╝
	
	This function implements a sophisticated weighted moving average algorithm
	with consistency penalty to calculate player proficiency. Unlike simple
	averaging, this approach:
	
	1. Gives MORE WEIGHT to recent performance (recency bias)
	2. PENALIZES erratic/inconsistent timing (standard deviation)
	3. Produces a PROFICIENCY INDEX (Phi) that better predicts skill level
	
	Mathematical Foundation:
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	
	PART A: Weighted Accuracy (Recency Bias)
	─────────────────────────────────────────
	Formula: WMA = Σ(w_i * x_i) / Σ(w_i)
	
	Where:
	  - w_i = weight for game i (linear: 1, 2, 3, 4, 5)
	  - x_i = accuracy for game i (0.0 to 1.0)
	  - Most recent game has highest weight
	
	Example (5 games):
	  Game 1 (oldest):  accuracy = 0.6, weight = 1
	  Game 2:           accuracy = 0.7, weight = 2
	  Game 3:           accuracy = 0.8, weight = 3
	  Game 4:           accuracy = 0.9, weight = 4
	  Game 5 (newest):  accuracy = 0.95, weight = 5
	  
	  WMA = (1×0.6 + 2×0.7 + 3×0.8 + 4×0.9 + 5×0.95) / (1+2+3+4+5)
	      = (0.6 + 1.4 + 2.4 + 3.6 + 4.75) / 15
	      = 12.75 / 15
	      = 0.85
	
	PART B: Consistency Penalty (Standard Deviation)
	─────────────────────────────────────────────────
	Formula: σ = sqrt(Σ(x_i - μ)² / N)
	
	Where:
	  - σ (sigma) = standard deviation
	  - x_i = reaction time for game i
	  - μ (mu) = mean reaction time
	  - N = number of games
	
	Normalized Penalty = min(σ / 5000.0, 0.2)
	  - Dividing by 5000ms normalizes erratic timing
	  - Capped at 0.2 (20% maximum penalty)
	  - Erratic timing → high penalty → lower proficiency
	
	Example:
	  Times: [5000ms, 6000ms, 5500ms, 5200ms, 8000ms]
	  Mean: 5940ms
	  Deviations: [-940, 60, -440, -740, 2060]
	  Squared: [883600, 3600, 193600, 547600, 4243600]
	  Variance: (883600+3600+193600+547600+4243600) / 5 = 1174400
	  σ = sqrt(1174400) ≈ 1083.7ms
	  Penalty = min(1083.7 / 5000, 0.2) = 0.217 → clamped to 0.2
	
	PART C: Proficiency Index (Phi - Φ)
	────────────────────────────────────
	Formula: Φ = WMA - Penalty
	
	Where:
	  - Φ (Phi) = Proficiency Index
	  - WMA = Weighted Moving Average of accuracy
	  - Penalty = Consistency Penalty
	
	Range: -0.2 to 1.0
	  - High Φ = Skilled + Consistent
	  - Low Φ = Struggling OR Erratic
	
	This index is used for adaptive difficulty decisions.
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	"""
	
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
	
	var weighted_sum: float = 0.0      # Σ(w_i * x_i)
	var weight_sum: float = 0.0        # Σ(w_i)
	
	for i in range(perf_window_size):
		var weight: float = float(i + 1)  # Linear weights: 1, 2, 3, 4, 5
		var accuracy: float = performance_window[i]["accuracy"]
		
		weighted_sum += weight * accuracy
		weight_sum += weight
	
	# Weighted Moving Average = Σ(w_i * x_i) / Σ(w_i)
	var weighted_accuracy: float = weighted_sum / weight_sum
	
	# ═══════════════════════════════════════════════════════════════════════
	# STEP 2: Calculate Standard Deviation (σ) of Reaction Time
	# ═══════════════════════════════════════════════════════════════════════
	
	# First, calculate mean (μ) of reaction times
	var total_time: float = 0.0
	for perf in performance_window:
		total_time += float(perf["reaction_time"])
	
	var mean_time: float = total_time / float(perf_window_size)
	
	# Second, calculate variance (σ²)
	# Variance = Σ(x_i - μ)² / N
	var variance: float = 0.0
	for perf in performance_window:
		var deviation: float = float(perf["reaction_time"]) - mean_time
		variance += deviation * deviation  # (x_i - μ)²
	
	variance /= float(perf_window_size)
	
	# Third, calculate standard deviation (σ)
	# σ = sqrt(variance)
	var std_deviation: float = sqrt(variance)
	
	# ═══════════════════════════════════════════════════════════════════════
	# STEP 3: Calculate Consistency Penalty
	# ═══════════════════════════════════════════════════════════════════════
	
	# Normalize standard deviation to penalty range [0.0, 0.2]
	# High σ → High penalty (erratic timing)
	# Low σ → Low penalty (consistent timing)
	var consistency_penalty: float = min(std_deviation / 5000.0, 0.2)
	
	# ═══════════════════════════════════════════════════════════════════════
	# STEP 4: Calculate Proficiency Index (Φ)
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
	"""
	╔════════════════════════════════════════════════════════════════════════╗
	║ PROFICIENCY-BASED DECISION TREE                                        ║
	║ Mathematical Adaptive Difficulty Algorithm                             ║
	╚════════════════════════════════════════════════════════════════════════╝
	
	This function uses the Proficiency Index (Φ) to make difficulty decisions.
	Unlike rule-based systems that check multiple conditions, this uses a
	single robust metric that already encodes:
	  - Performance quality (weighted accuracy)
	  - Consistency (standard deviation penalty)
	
	Decision Tree Logic:
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	
	RULE 1: STRUGGLING / ERRATIC (Φ < 0.5)
	───────────────────────────────────────
	Threshold: Proficiency Index < 0.5
	
	Interpretation:
	  - Low weighted accuracy (poor recent performance), OR
	  - High consistency penalty (erratic/unstable timing)
	
	Example Case 1 (Struggling):
	  WMA = 0.45, Penalty = 0.05 → Φ = 0.40
	  → Player is genuinely struggling, needs easier tasks
	
	Example Case 2 (Erratic):
	  WMA = 0.65, Penalty = 0.20 → Φ = 0.45
	  → Player has okay accuracy but very inconsistent timing
	  → Could indicate confusion, stress, or lack of understanding
	  → Easier difficulty helps stabilize performance
	
	Action: Set difficulty to "Easy"
	Rationale: Provide scaffolding and support
	
	RULE 2: MASTERY + CONSISTENCY (Φ > 0.85)
	─────────────────────────────────────────
	Threshold: Proficiency Index > 0.85
	
	Interpretation:
	  - High weighted accuracy (strong recent performance), AND
	  - Low consistency penalty (stable/consistent timing)
	
	Example Case:
	  WMA = 0.92, Penalty = 0.05 → Φ = 0.87
	  → Player consistently performs well
	  → Ready for challenge to maintain engagement
	
	Action: Set difficulty to "Hard"
	Rationale: Prevent boredom, maintain flow state
	
	RULE 3: FLOW STATE (0.5 ≤ Φ ≤ 0.85)
	────────────────────────────────────
	Threshold: 0.5 ≤ Proficiency Index ≤ 0.85
	
	Interpretation:
	  - Moderate performance with acceptable consistency
	  - Player is in optimal learning zone
	
	Example Cases:
	  WMA = 0.70, Penalty = 0.10 → Φ = 0.60 (Lower flow)
	  WMA = 0.82, Penalty = 0.08 → Φ = 0.74 (Upper flow)
	
	Action: Set difficulty to "Medium"
	Rationale: Maintain engagement without frustration
	
	Mathematical Advantages:
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	1. Single robust metric (easier to tune/validate)
	2. Recency bias (recent performance matters more)
	3. Consistency enforcement (stable timing = higher proficiency)
	4. Clearer thresholds (no compound conditions)
	5. Better research documentation (formula-based)
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	"""
	
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
	# RULE 1: STRUGGLING / ERRATIC → Easy
	# ═══════════════════════════════════════════════════════════════════════
	
	if proficiency < 0.5:
		new_difficulty = "Easy"
		
		# Detailed diagnostic reasoning
		if weighted_accuracy < 0.6:
			# Primary issue: Poor performance
			reason = "Struggling - Low proficiency (Φ=%.2f): Poor weighted accuracy (%.2f) indicates difficulty understanding tasks" % [proficiency, weighted_accuracy]
		elif consistency_penalty > 0.15:
			# Primary issue: Erratic timing
			reason = "Erratic - Low proficiency (Φ=%.2f): High consistency penalty (%.2f, σ=%.0fms) indicates unstable performance" % [proficiency, consistency_penalty, std_deviation]
		else:
			# General struggling
			reason = "Support needed - Proficiency index (Φ=%.2f) below threshold (0.5)" % proficiency
		
		path.append("Rule 1: STRUGGLING/ERRATIC (Φ < 0.5) → Easy")
		path.append("  └─ WMA: %.2f, Penalty: %.2f, σ: %.0fms" % [weighted_accuracy, consistency_penalty, std_deviation])
	
	# ═══════════════════════════════════════════════════════════════════════
	# RULE 2: MASTERY + CONSISTENCY → Hard
	# ═══════════════════════════════════════════════════════════════════════
	
	elif proficiency > 0.85:
		new_difficulty = "Hard"
		reason = "Mastery - High proficiency (Φ=%.2f): Strong weighted accuracy (%.2f) with low penalty (%.2f) shows consistent excellence" % [proficiency, weighted_accuracy, consistency_penalty]
		
		path.append("Rule 2: MASTERY+CONSISTENCY (Φ > 0.85) → Hard")
		path.append("  └─ WMA: %.2f, Penalty: %.2f, σ: %.0fms" % [weighted_accuracy, consistency_penalty, std_deviation])
	
	# ═══════════════════════════════════════════════════════════════════════
	# RULE 3: FLOW STATE → Medium
	# ═══════════════════════════════════════════════════════════════════════
	
	else:
		new_difficulty = "Medium"
		reason = "Flow state - Optimal proficiency (Φ=%.2f): Balanced performance in learning zone" % proficiency
		
		path.append("Rule 3: FLOW STATE (0.5 ≤ Φ ≤ 0.85) → Medium")
		path.append("  └─ WMA: %.2f, Penalty: %.2f, σ: %.0fms" % [weighted_accuracy, consistency_penalty, std_deviation])
	
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
	var first_half = performance_history.slice(0, int(performance_history.size() / 2.0))
	var second_half = performance_history.slice(int(performance_history.size() / 2.0), performance_history.size())
	
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
# SUMMATIVE ASSESSMENT - POST-TEST SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _check_posttest_unlock() -> void:
	if posttest_unlocked_flag:
		return
	
	var games_played = performance_history.size()
	
	if total_score >= posttest_min_score or games_played >= posttest_min_games:
		posttest_unlocked_flag = true
		posttest_unlocked.emit()
		
		if enable_verbose_logging:
			print("🎓 POST-TEST UNLOCKED (Score: %d, Games: %d)" % [total_score, games_played])

func is_posttest_unlocked() -> bool:
	return posttest_unlocked_flag

func get_posttest_questions() -> Array:
	return posttest_questions

func start_posttest() -> void:
	if not posttest_unlocked_flag:
		push_warning("Post-test not unlocked yet!")
		return
	
	posttest_started = true
	posttest_start_time = int(Time.get_unix_time_from_system())
	current_question_start_time = int(Time.get_unix_time_from_system())
	posttest_answers.clear()
	
	if enable_verbose_logging:
		print("📝 POST-TEST STARTED")

func submit_posttest_answer(question_id: int, answer_index: int) -> void:
	if not posttest_started:
		push_warning("Post-test not started!")
		return
	
	var question = _get_question_by_id(question_id)
	if question == null:
		push_warning("Question not found: %d" % question_id)
		return
	
	var time_taken = Time.get_unix_time_from_system() - current_question_start_time
	var is_correct = (answer_index == question["correct_answer"])
	
	var answer_data = {
		"question_id": question_id,
		"category": question["category"],
		"answer_selected": answer_index,
		"correct_answer": question["correct_answer"],
		"is_correct": is_correct,
		"time_to_answer": time_taken,
		"related_minigame": question["related_minigame"],
		"timestamp": Time.get_unix_time_from_system()
	}
	
	posttest_answers.append(answer_data)
	
	# Emit signal
	posttest_question_answered.emit(question_id, is_correct, time_taken)
	
	# Reset timer for next question
	current_question_start_time = int(Time.get_unix_time_from_system())
	
	# Check if all questions answered
	if posttest_answers.size() >= total_posttest_questions:
		_complete_posttest()

func _get_question_by_id(id: int) -> Dictionary:
	for q in posttest_questions:
		if q["id"] == id:
			return q
	return {}

func _complete_posttest() -> void:
	posttest_completed_flag = true
	
	var results = get_posttest_results()
	var correct = results["correct_answers"]
	var total = results["total_questions"]
	var percentage = results["percentage"]
	
	# Calculate correlation
	var correlation_data = calculate_correlation()
	
	# Emit signals
	posttest_completed.emit(correct, total, percentage)
	correlation_calculated.emit(
		correlation_data["gameplay_performance"],
		correlation_data["posttest_knowledge"],
		correlation_data["correlation_coefficient"]
	)
	
	if enable_research_logging:
		_log_posttest_results(results, correlation_data)

func get_posttest_results() -> Dictionary:
	if posttest_answers.is_empty():
		return {
			"total_score": 0,
			"correct_answers": 0,
			"total_questions": 0,
			"percentage": 0.0,
			"category_breakdown": {},
			"avg_time_per_question": 0.0
		}
	
	var correct_count = 0
	var total_time = 0.0
	var category_stats = {}
	
	for answer in posttest_answers:
		if answer["is_correct"]:
			correct_count += 1
		
		total_time += answer["time_to_answer"]
		
		# Category breakdown
		var cat = answer["category"]
		if not category_stats.has(cat):
			category_stats[cat] = {"correct": 0, "total": 0}
		category_stats[cat]["total"] += 1
		if answer["is_correct"]:
			category_stats[cat]["correct"] += 1
	
	# Calculate category percentages
	var category_breakdown = {}
	for cat in category_stats:
		var stats = category_stats[cat]
		category_breakdown[cat] = (float(stats["correct"]) / stats["total"]) * 100.0
	
	var percentage = (float(correct_count) / posttest_answers.size()) * 100.0
	
	return {
		"total_score": int(percentage),
		"correct_answers": correct_count,
		"total_questions": posttest_answers.size(),
		"percentage": percentage,
		"category_breakdown": category_breakdown,
		"avg_time_per_question": total_time / posttest_answers.size()
	}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CORRELATION ANALYSIS (Research Validation)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func calculate_correlation() -> Dictionary:
	gameplay_performance_score = _calculate_overall_gameplay_performance()
	posttest_knowledge_score = _get_posttest_percentage()
	correlation_coefficient = _pearson_correlation()
	
	return {
		"gameplay_performance": gameplay_performance_score,
		"posttest_knowledge": posttest_knowledge_score,
		"correlation_coefficient": correlation_coefficient,
		"interpretation": _interpret_correlation(correlation_coefficient),
		"sample_size": performance_history.size(),
		"valid_correlation": performance_history.size() >= 10
	}

func _calculate_overall_gameplay_performance() -> float:
	if performance_history.is_empty():
		return 0.0
	
	var total_accuracy = 0.0
	for perf in performance_history:
		total_accuracy += perf["accuracy"]
	
	return (total_accuracy / performance_history.size()) * 100.0

func _get_posttest_percentage() -> float:
	var results = get_posttest_results()
	return results["percentage"]

func _pearson_correlation() -> float:
	# Simplified correlation: compare gameplay performance to post-test score
	# For proper Pearson correlation, we'd need paired data points
	# Here we're doing a basic comparison
	
	if performance_history.is_empty() or posttest_answers.is_empty():
		return 0.0
	
	# Calculate per-game correlation where possible
	var correlations = []
	
	for answer in posttest_answers:
		var related_game = answer["related_minigame"]
		var game_performance = _get_average_performance_for_game(related_game)
		var test_performance = 1.0 if answer["is_correct"] else 0.0
		
		correlations.append({
			"gameplay": game_performance,
			"test": test_performance
		})
	
	if correlations.is_empty():
		return 0.0
	
	# Calculate Pearson correlation coefficient
	var n = correlations.size()
	var sum_x = 0.0
	var sum_y = 0.0
	var sum_xy = 0.0
	var sum_x2 = 0.0
	var sum_y2 = 0.0
	
	for pair in correlations:
		var x = pair["gameplay"]
		var y = pair["test"]
		sum_x += x
		sum_y += y
		sum_xy += x * y
		sum_x2 += x * x
		sum_y2 += y * y
	
	var numerator = n * sum_xy - sum_x * sum_y
	var denominator = sqrt((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y))
	
	if denominator == 0:
		return 0.0
	
	return numerator / denominator

func _get_average_performance_for_game(game_name: String) -> float:
	var relevant_games = []
	for perf in performance_history:
		if perf.get("game_name", "") == game_name:
			relevant_games.append(perf)
	
	if relevant_games.is_empty():
		# Fallback to overall average
		return _calculate_overall_gameplay_performance() / 100.0
	
	var total = 0.0
	for game in relevant_games:
		total += game["accuracy"]
	
	return total / relevant_games.size()

func _interpret_correlation(r: float) -> String:
	var abs_r = abs(r)
	
	if abs_r >= 0.7:
		return "STRONG correlation - Algorithm successfully facilitated learning"
	elif abs_r >= 0.4:
		return "MODERATE correlation - Some learning transfer occurred"
	elif abs_r >= 0.2:
		return "WEAK correlation - Limited learning transfer"
	else:
		return "NO correlation - Gameplay did not translate to knowledge"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DIFFICULTY SETTINGS ACCESS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_current_difficulty() -> String:
	return current_difficulty

func get_difficulty_settings() -> Dictionary:
	return DIFFICULTY_SETTINGS[current_difficulty].duplicate()

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
	elif "screen_shake_mild" in effects:
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
		
		# Formative Data
		"gameplay": {
			"total_games_played": performance_history.size(),
			"total_score": total_score,
			"performance_history": performance_history,
			"difficulty_timeline": difficulty_changes,
			"behavioral_metrics": get_behavioral_metrics(),
			"final_difficulty": current_difficulty,
			"window_metrics": _get_window_metrics()
		},
		
		# Summative Data
		"posttest": {
			"unlocked": posttest_unlocked_flag,
			"completed": posttest_completed_flag,
			"score": get_posttest_results()["total_score"],
			"total_questions": total_posttest_questions,
			"answers": posttest_answers,
			"category_breakdown": get_posttest_results()["category_breakdown"],
			"avg_time_per_question": get_posttest_results()["avg_time_per_question"]
		},
		
		# Correlation Analysis
		"research_validation": calculate_correlation(),
		
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

func _log_posttest_results(results: Dictionary, correlation: Dictionary) -> void:
	if not enable_research_logging:
		return
	
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📝 POST-TEST RESULTS (Summative)")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📊 Score: %d/%d (%.1f%%)" % [results["correct_answers"], results["total_questions"], results["percentage"]])
	print("")
	print("📈 Category Breakdown:")
	for category in results["category_breakdown"]:
		var percentage = results["category_breakdown"][category]
		print("  • %s: %.1f%%" % [category.capitalize(), percentage])
	print("")
	print("⏱️  Avg Time Per Question: %.1fs" % results["avg_time_per_question"])
	print("")
	print("🔗 CORRELATION ANALYSIS:")
	print("  • Gameplay Performance: %.1f%%" % correlation["gameplay_performance"])
	print("  • Post-Test Knowledge: %.1f%%" % correlation["posttest_knowledge"])
	print("  • Correlation (r): %.2f" % correlation["correlation_coefficient"])
	print("")
	print("✅ VALIDATION: %s" % correlation["interpretation"])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
