# 💧 WATERWISE - Adaptive Difficulty Educational Game System

## 🎓 Research-Validated Water Conservation Game
**Godot 4.x Implementation**

---

## 📋 TABLE OF CONTENTS

1. [System Overview](#system-overview)
2. [Dual Assessment Framework](#dual-assessment-framework)
3. [Adaptive Algorithm](#adaptive-algorithm)
4. [File Structure](#file-structure)
5. [Setup Instructions](#setup-instructions)
6. [Creating Mini-Games](#creating-mini-games)
7. [Research Data Export](#research-data-export)
8. [API Reference](#api-reference)

---

## 🎯 SYSTEM OVERVIEW

**WATERWISE** is an educational game that teaches water conservation through a "Dumb Ways to Die" style fast-paced mini-game format. The system implements a **hybrid assessment model** combining:

1. **Formative Assessment** - Real-time performance tracking during gameplay
2. **Summative Assessment** - Post-test knowledge evaluation
3. **Rule-Based Adaptive Difficulty** - Rolling window algorithm for personalized challenge

### 🔬 Research Innovation

This system validates learning through **correlation analysis** between:
- Behavioral performance (gameplay decisions)
- Conceptual knowledge (post-test scores)

**Research Questions:**
- SOP 1: Does the Weighted Proficiency Index correlate with post-test scores?
- SOP 2: Can behavioral patterns predict knowledge retention?
- SOP 3: Does the Rolling Window algorithm maintain optimal engagement?

### 🎮 Platform Features
- ✅ **Mobile Touch Controls** - Automatic touch input handling for phone gameplay
- ✅ **Instruction Overlays** - Pre-game instructions with localized text
- ✅ **Bilingual Support** - English/Tagalog (Filipino) localization
- ✅ **Session Scoring** - Tally screens after each round with high score tracking
- ✅ **Game Randomization** - Shuffled mini-game order every session

---

## 📊 DUAL ASSESSMENT FRAMEWORK

### PHASE 1: Formative Assessment (Gameplay)

**What it measures:**
- Behavioral learning through gameplay decisions
- Real-time performance metrics
- Adaptive difficulty progression

**Data Collected:**
```gdscript
{
	"accuracy": 0.85,          # 0-1 scale (85% success rate)
	"reaction_time": 12500,    # milliseconds
	"mistakes": 2,             # error count
	"difficulty": "Medium"     # current difficulty level
}
```

**Rolling Window Algorithm:**
- Tracks last 5 games (FIFO queue)
- Adapts difficulty every 2-3 games
- Decision tree with 3 rules

### PHASE 2: Summative Assessment (Post-Test)

**What it measures:**
- Conceptual understanding (not just task completion)
- Knowledge retention
- Application ability

**Unlock Conditions:**
- Score ≥ 1000 OR
- Games Played ≥ 15

**Question Categories:**
1. **Conceptual** - Understanding water conservation principles
2. **Application** - Real-world scenario responses
3. **Retention** - Remembering techniques from gameplay
4. **Behavioral** - Intent to apply learning

### PHASE 3: Correlation Analysis

**Statistical Validation:**
```gdscript
{
	"gameplay_performance": 78.0,     # % (formative)
	"posttest_knowledge": 80.0,       # % (summative)
	"correlation_coefficient": 0.85,   # Pearson r
	"interpretation": "STRONG - Algorithm successfully facilitated learning"
}
```

**Correlation Interpretation:**
- `r ≥ 0.7` = STRONG (Algorithm effective)
- `0.4 ≤ r < 0.7` = MODERATE (Some learning)
- `r < 0.4` = WEAK (Limited transfer)

---

## 🧠 ADAPTIVE ALGORITHM

### Weighted Proficiency Index with Consistency Penalty

```
INPUT: Rolling Window (last 5 games)
COMPUTE: Proficiency Index (Φ)

FORMULA:
  WMA = Σ(weight_i × accuracy_i) / Σ(weight_i)  # Weights: 1,2,3,4,5
  σ = sqrt(Σ(time - μ)² / N)                     # Standard deviation
  CP = min(σ / 5000.0, 0.2)                      # Consistency penalty
  Φ = WMA - CP                                    # Proficiency Index

RULE 1 (Struggling/Erratic):
IF Φ < 0.5:
	→ difficulty = "Easy"
	→ Low skill OR erratic performance

RULE 2 (Mastery+Consistency):
IF Φ > 0.85:
	→ difficulty = "Hard"
	→ High accuracy AND stable timing

RULE 3 (Flow State):
ELSE (0.5 ≤ Φ ≤ 0.85):
	→ difficulty = "Medium"
	→ Optimal learning zone
```

### Difficulty Settings

#### Easy Mode (Safety Net)
```gdscript
{
	"speed_multiplier": 0.7,
	"time_limit": 20,
	"task_complexity": 1,
	"hints": 3,
	"visual_guidance": true,
	"distractors": 1,
	"item_count": 3,
	"chaos_effects": []
}
```

#### Medium Mode (Flow State)
```gdscript
{
	"speed_multiplier": 1.0,
	"time_limit": 15,
	"task_complexity": 2,
	"hints": 2,
	"visual_guidance": false,
	"distractors": 2,
	"item_count": 5,
	"chaos_effects": ["screen_shake_mild"]
}
```

#### Hard Mode (Chaos Unleashed)
```gdscript
{
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
```

### Performance Tracking

**Per-Game Metrics:**
- Accuracy (0-1)
- Reaction Time (ms)
- Mistakes Count
- Timestamp

**Behavioral Metrics (Derived):**
- Learning Velocity (improvement rate)
- Decision Quality (accuracy/time ratio)
- Persistence (games after failures)
- Mastery Progression (difficulty timeline)

---

## 📁 FILE STRUCTURE

```
waterwise/
├── autoload/
│   ├── AdaptiveDifficulty.gd      # Core algorithm (900+ lines)
│   └── GameManager.gd              # Game flow controller
│
├── scenes/
│   ├── ui/
│   │   ├── MainMenu.tscn/gd       # Main menu
│   │   ├── LoadingScreen.tscn/gd  # Loading screen
│   │   ├── PostTest.tscn/gd       # Post-test quiz UI
│   │   ├── PostTestResults.tscn/gd # Results + correlation
│   │   ├── MiniGameResults.tscn/gd # Per-game results
│   │   └── AnalyticsDashboard.tscn/gd # Research dashboard
│   │
│   └── minigames/
│       ├── WaterPlant.tscn/gd     # Sample mini-game
│       ├── FixLeak.tscn/gd        # (Create more)
│       └── BucketChallenge.tscn/gd
│
├── scripts/
│   ├── MiniGameBase.gd            # Template for all mini-games
│   └── JuiceEffects.gd            # Game feel / polish effects
│
├── characters/                     # Your existing assets
│   ├── Main Menu Screen.png
│   ├── Loading.png
│   └── main char.gltf
│
└── project.godot                   # Godot project config
```

---

## 🚀 SETUP INSTRUCTIONS

### 1. Open Project in Godot 4.x

```bash
# Open Godot 4.3 or later
# File → Open Project → Select waterwise folder
```

### 2. Verify Autoloads

Go to **Project → Project Settings → Autoload**

Should see:
- `AdaptiveDifficulty` - `res://autoload/AdaptiveDifficulty.gd`
- `GameManager` - `res://autoload/GameManager.gd`

### 3. Run the Game

Press **F5** or click **Run Project**

Main Menu should appear with:
- ▶️ MAGLARO (Play)
- 👤 CHARACTER
- 📖 PAANO MAGLARO (Instructions)
- ⚙️ SETTINGS
- 🚪 UMALIS (Quit)

### 4. Test the Flow

1. Click **MAGLARO**
2. Loading screen appears
3. First mini-game starts (WaterPlant)
4. Complete the game
5. Results screen shows
6. Continue to next game
7. After 15 games, post-test unlocks
8. Complete post-test
9. View correlation analysis

---

## 🎮 CREATING MINI-GAMES

### Step 1: Extend MiniGameBase

```gdscript
# scenes/minigames/YourGame.gd
extends MiniGameBase

func _ready() -> void:
	game_name = "YourGame"
	super._ready()

func _on_game_start() -> void:
	# Initialize your game logic
	_spawn_objects()
	_setup_controls()

func _apply_difficulty_settings() -> void:
	super._apply_difficulty_settings()
	
	# Apply difficulty to your game
	var num_items = difficulty_settings.get("item_count", 3)
	var speed = difficulty_settings.get("speed_multiplier", 1.0)
	
	# Adjust your game based on difficulty
```

### Step 2: Track Actions

```gdscript
func _on_player_action(is_correct: bool) -> void:
	record_action(is_correct)
	
	if is_correct:
		# Player did the right thing!
		_give_positive_feedback()
	else:
		# Player made a mistake
		_show_correction()
```

### Step 3: End Game

```gdscript
func _check_win_condition() -> void:
	if all_objectives_complete():
		end_game(true)  # Success!
	elif time_expired():
		end_game(false) # Failed
```

### Step 4: Register in GameManager

```gdscript
# In GameManager.gd
var available_minigames: Array[String] = [
	"WaterPlant",
	"FixLeak",
	"BucketChallenge",
	"YourGame"  # Add your game here
]
```

---

## 📤 RESEARCH DATA EXPORT

### Accessing Analytics Dashboard

From PostTestResults screen, click **💾 Export Data**

Or programmatically:
```gdscript
# Get session data
var data = AdaptiveDifficulty.export_complete_session()

# Export to JSON
AdaptiveDifficulty.export_to_json_file()
# Saves to: user://case_study_WW_TIMESTAMP_ID.json
```

### JSON Export Structure

```json
{
	"session_id": "WW_1732406400_1234",
	"timestamp": 1732406400,
	"session_duration": 932,
	
	"gameplay": {
		"total_games_played": 18,
		"performance_history": [...],
		"difficulty_timeline": [...],
		"behavioral_metrics": {...},
		"final_difficulty": "Hard"
	},
	
	"posttest": {
		"score": 12,
		"total_questions": 15,
		"answers": [...],
		"category_breakdown": {
			"conceptual": 90.0,
			"application": 75.0,
			"retention": 80.0
		}
	},
	
	"research_validation": {
		"gameplay_performance": 78.0,
		"knowledge_retention": 80.0,
		"correlation_coefficient": 0.85,
		"interpretation": "STRONG correlation"
	}
}
```

### CSV Export

Click **📊 Export CSV** in Analytics Dashboard

Generates two tables:
1. **Performance History** (per-game data)
2. **Post-Test Answers** (per-question data)

---

## 🔧 API REFERENCE

### AdaptiveDifficulty Singleton

#### Formative Assessment

```gdscript
# Add performance data after each mini-game
AdaptiveDifficulty.add_performance(
	accuracy: float,        # 0.0 - 1.0
	reaction_time: int,     # milliseconds
	mistakes: int,          # error count
	game_name: String       # optional
)

# Get current difficulty level
var difficulty = AdaptiveDifficulty.get_current_difficulty()
# Returns: "Easy", "Medium", or "Hard"

# Get difficulty settings
var settings = AdaptiveDifficulty.get_difficulty_settings()
# Returns: Dictionary with all parameters

# Get behavioral metrics
var metrics = AdaptiveDifficulty.get_behavioral_metrics()
# Returns: {learning_velocity, decision_quality, persistence, etc.}
```

#### Summative Assessment

```gdscript
# Check if post-test is unlocked
if AdaptiveDifficulty.is_posttest_unlocked():
	# Show post-test button

# Start post-test
AdaptiveDifficulty.start_posttest()

# Submit answer
AdaptiveDifficulty.submit_posttest_answer(
	question_id: int,
	answer_index: int
)

# Get results
var results = AdaptiveDifficulty.get_posttest_results()
```

#### Correlation & Research

```gdscript
# Calculate correlation
var correlation = AdaptiveDifficulty.calculate_correlation()
# Returns: {
#   gameplay_performance: float,
#   posttest_knowledge: float,
#   correlation_coefficient: float,
#   interpretation: String
# }

# Export complete session
var data = AdaptiveDifficulty.export_complete_session()

# Export to file
AdaptiveDifficulty.export_to_json_file()
```

#### Signals

```gdscript
# Listen for difficulty changes
AdaptiveDifficulty.difficulty_changed.connect(
	func(old: String, new: String, reason: String):
		print("Difficulty: %s → %s" % [old, new])
)

# Listen for post-test unlock
AdaptiveDifficulty.posttest_unlocked.connect(
	func():
		print("Post-test now available!")
)

# Listen for correlation calculation
AdaptiveDifficulty.correlation_calculated.connect(
	func(gameplay: float, test: float, r: float):
		print("Correlation: %.2f" % r)
)
```

### GameManager Singleton

```gdscript
# Start new session
GameManager.start_new_session()

# Start next mini-game
GameManager.start_next_minigame()

# Complete current mini-game
GameManager.complete_minigame(
	game_name: String,
	accuracy: float,
	reaction_time: int,
	mistakes: int
)

# Pause/Resume
GameManager.pause_game()
GameManager.resume_game()

# Get progress
var progress = GameManager.get_progress_percentage()
```

### JuiceEffects (Game Feel)

```gdscript
# Screen shake
JuiceEffects.screen_shake(camera, intensity, duration)

# Flash screen
JuiceEffects.flash_screen(node, color, duration)

# Bounce animation
JuiceEffects.bounce_scale(node, scale_amount, duration)

# Particle burst
JuiceEffects.particle_burst(node, position, color, count)

# Success celebration
JuiceEffects.celebrate_success(node, camera)

# Failure effect
JuiceEffects.show_failure(node, camera)
```

---

## 📈 RESEARCH LOGGING

The system automatically logs algorithm decisions in the console:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 ADAPTIVE DIFFICULTY UPDATE (Formative)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔬 Algorithm: Rule-Based Rolling Window
📏 Window: 5/5 games

📈 Performance Metrics:
  • Success Rate: 85.0%
  • Avg Time: 12.3s
  • Learning Velocity: +15% (improving)

🌳 Decision Tree:
  Rule 1: SR < 60%? ❌ FALSE
  Rule 2: SR ≥ 80%? ✅ TRUE → HARD

🎯 Difficulty: Medium → Hard
🎪 CHAOS: [screen_shake, buzzing_fly]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

After post-test:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 POST-TEST RESULTS (Summative)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Score: 12/15 (80%)

📈 Category Breakdown:
  • Conceptual: 90%
  • Application: 75%
  • Retention: 80%

🔗 CORRELATION ANALYSIS:
  • Gameplay Performance: 78%
  • Post-Test Knowledge: 80%
  • Correlation (r): 0.85 (STRONG)

✅ VALIDATION: Algorithm successfully facilitated learning
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🎨 CUSTOMIZATION

### Modify Algorithm Thresholds

In `AdaptiveDifficulty.gd`:

```gdscript
@export var STRUGGLING_SUCCESS_RATE: float = 0.6  # Lower = harder to drop to Easy
@export var MASTERY_SUCCESS_RATE: float = 0.8     # Higher = harder to reach Hard
@export var WINDOW_SIZE: int = 5                  # Change rolling window size
```

### Add More Post-Test Questions

In `AdaptiveDifficulty.gd`, find `POSTTEST_QUESTIONS` array and add:

```gdscript
{
	"id": 16,
	"category": "application",
	"question": "Your question here?",
	"options": ["A", "B", "C", "D"],
	"correct_answer": 2,  # Index (0-3)
	"related_minigame": "WaterPlant",
	"difficulty": "medium"
}
```

### Adjust Difficulty Settings

Modify `DIFFICULTY_SETTINGS` dictionary in `AdaptiveDifficulty.gd`

---

## 🐛 TROUBLESHOOTING

### Post-test not unlocking
- Check score: `AdaptiveDifficulty.get_total_score()`
- Check games played: `AdaptiveDifficulty.get_games_played()`
- Minimum required: 1000 score OR 15 games

### Difficulty not adapting
- Ensure you're calling `add_performance()` after each game
- Check window size: Need at least 3 games in window
- Enable verbose logging: `ENABLE_VERBOSE_LOGGING = true`

### Data not exporting
- Check user:// directory location
- On Windows: `%APPDATA%\Godot\app_userdata\Waterwise\`
- Enable export logging: `ENABLE_RESEARCH_LOGGING = true`

---

## 📚 THESIS DEFENSE TIPS

### Key Points to Emphasize:

1. **Dual Assessment Innovation**
   - Formative (behavioral) + Summative (conceptual)
   - Validates learning transfer, not just completion

2. **Algorithm Transparency**
   - Rule-based (explainable AI)
   - Clear decision tree with 3 rules
   - Real-time adaptation (<100ms)

3. **Research Validation**
   - Pearson correlation coefficient
   - Statistical interpretation
   - Case study data export

4. **Practical Application**
   - Godot 4.x open-source
   - Scalable to other educational topics
   - Complete data pipeline for analysis

### Questions to Prepare For:

**Q: Why rule-based instead of machine learning?**
A: Transparency, interpretability, and educational validity. Teachers/researchers can understand exactly why difficulty changed.

**Q: How do you validate the correlation is meaningful?**
A: Multiple measures - not just r-value, but also category breakdown showing transfer to specific knowledge domains.

**Q: What if gameplay and test scores don't correlate?**
A: That's still valuable data! It suggests the game mechanics didn't translate to conceptual learning, informing design improvements.

---

## 📞 SUPPORT & CONTRIBUTION

This is a research prototype for thesis validation.

**For Questions:**
- Review this README
- Check inline code documentation
- Enable verbose logging for debugging

**Data Files Location:**
- JSON exports: `user://case_study_*.json`
- CSV exports: `user://research_data_*.csv`

**Windows Path:**
```
C:\Users\[USERNAME]\AppData\Roaming\Godot\app_userdata\Waterwise\
```

---

## 📜 LICENSE

Educational/Research Use
Developed for thesis: "Adaptive Difficulty in Educational Games"

---

## ✅ NEXT STEPS

1. ✅ System is complete and ready to use
2. 🎮 Create remaining mini-games (FixLeak, BucketChallenge, etc.)
3. 🎨 Replace placeholder graphics with your assets
4. 🔊 Add sound effects and music
5. 📝 Conduct user testing and collect data
6. 📊 Analyze correlation results
7. 🎓 Present findings in thesis

**Good luck with your research! 🚀**
