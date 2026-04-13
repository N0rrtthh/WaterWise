# WaterWise - Algorithm Documentation for Thesis Defense
## Adaptive Difficulty System Technical Reference

---

## 📊 Core Algorithms Implemented

### 1. Rule-Based Rolling Window Algorithm (Single-Player)
**Location:** `autoload/AdaptiveDifficulty.gd`

#### Mathematical Foundation
```
Proficiency Index (Φ) = Weighted Moving Average (WMA) - Consistency Penalty (CP)
```

#### Component Formulas

**Weighted Moving Average (WMA):**
```
WMA = Σ(w_i × x_i) / Σ(w_i)

Where:
- w_i = Linear weight (1, 2, 3, 4, 5) for position i
- x_i = Accuracy of game i (0.0 to 1.0)
- Recent games have higher weights (recency bias)
```

**Consistency Penalty (CP):**
```
CP = min(σ / 5000, 0.2)

Where:
- σ = Standard deviation of reaction times (ms)
- Capped at 0.2 (maximum 20% penalty)
```

**Decision Tree Rules:**
```
Rule 1: IF Φ < 0.5     → Difficulty = "Easy"    (Struggling/Erratic)
Rule 2: IF Φ > 0.85    → Difficulty = "Hard"    (Mastery + Consistency)
Rule 3: IF 0.5 ≤ Φ ≤ 0.85 → Difficulty = "Medium" (Flow State)
```

#### Key Code Lines (for panelist reference)
| Line | File | Description |
|------|------|-------------|
| 180-181 | AdaptiveDifficulty.gd | FIFO queue - Rolling window management |
| 443-448 | AdaptiveDifficulty.gd | WMA calculation with linear weights |
| 471-473 | AdaptiveDifficulty.gd | Consistency penalty + Φ calculation |
| 686-720 | AdaptiveDifficulty.gd | Decision tree rules evaluation |

---

### 2. G-Counter CRDT Algorithm (Multiplayer Scoring)
**Location:** `autoload/GameManager.gd` + `autoload/CoopAdaptation.gd`

#### What is G-Counter?
A **Grow-only Counter** is a Conflict-Free Replicated Data Type (CRDT) where:
- Each player maintains their OWN counter
- Counters can only INCREMENT (never decrement)
- Global score = Sum of all player counters
- No conflicts because each player only modifies their own value

#### Formula
```
GlobalScore = Σ(PlayerInput_i) for i = 1 to n

Where:
- Each peer_id has its own counter value
- Server sums all counters for global total
```

#### Synchronization Score (Co-op Mode)
```
Sync = max(0, 100 - (Δt × 5))

Where:
- Δt = |Player1_time - Player2_time| in seconds
- 5 = Penalty points per second of difference
- Good teamwork = finishing close together
```

#### Key Code Lines
| Line | File | Description |
|------|------|-------------|
| 60 | GameManager.gd | G-Counter dictionary structure |
| 392 | GameManager.gd | Global score sum calculation |
| 206-210 | CoopAdaptation.gd | Sync score with time difference penalty |

---

## 📱 Mobile Configuration

The game is configured for portrait mobile display:
- **Resolution:** 1080 x 1920 (9:16 portrait)
- **Touch:** Emulated from mouse for testing
- **Orientation:** Portrait mode
- **Stretch:** Canvas items with expand aspect

### Touch Input Features
- Tap detection
- Swipe gestures
- Hold detection
- Haptic feedback (vibration)

---

## 🔬 Demo Mode for Panelists

### How to Access Algorithm Demo:
1. Launch the game
2. Click **"🔬 Algorithm Demo"** button on Main Menu
3. Use simulation buttons to add fake game results
4. Watch the algorithm respond in real-time

### Demo Features:
- **Rolling Window Visualization:** Shows last 5 games with weights
- **Real-time Φ Calculation:** Updates after each simulated game
- **Decision Tree Highlighting:** Shows which rule is active
- **Step-by-Step Explanation:** Detailed breakdown of each calculation

### Simulation Options:
| Button | Simulates | Expected Result |
|--------|-----------|-----------------|
| 😓 Poor | 30% accuracy, slow | Φ drops, moves to Easy |
| 😊 Medium | 70% accuracy | Φ moderate, stays Medium |
| 🔥 Expert | 95% accuracy, fast | Φ high, moves to Hard |

---

## 🎮 Real-Time Algorithm Overlay

During actual gameplay, press **F12** to toggle the algorithm monitor overlay.

### Overlay Shows:
- Current difficulty level
- Proficiency Index (Φ) value
- Rolling window size (X/5 games)
- Active decision tree rule
- Total games played

---

## 📈 Research Data Export

The system can export session data for analysis:
```gdscript
AdaptiveDifficulty.export_to_json_file("user://session_data.json")
```

### Exported Data Includes:
- Session ID and timestamp
- All performance history
- Difficulty change timeline
- Behavioral metrics (learning velocity, persistence)
- Algorithm statistics (latency, adaptations)

---

## 🧪 Test Scripts

### Automated Algorithm Verification:
- **File:** `TEST_ALGORITHMS.gd`
- **File:** `ALGORITHM_VERIFICATION_TEST.gd`

Run these to automatically test:
1. Rolling Window behavior (FIFO)
2. WMA calculation accuracy
3. Decision tree rule triggering
4. G-Counter summation

---

## 📋 Difficulty Settings

| Setting | Easy | Medium | Hard |
|---------|------|--------|------|
| Speed Multiplier | 0.7x | 1.0x | 1.5x |
| Time Limit | 20s | 15s | 10s |
| Task Complexity | 1 | 2 | 3 |
| Hints | 3 | 2 | 0 |
| Visual Guidance | ✓ | ✗ | ✗ |
| Distractors | 1 | 2 | 3 |
| Item Count | 3 | 5 | 8 |
| Chaos Effects | None | Mild shake | All effects |

### Adaptation Trigger Rules
- **Window must be full (5 games)** before the first adaptation
- After game 5, the algorithm evaluates **every new game** (window slides)
- Consistency Penalty is normalized relative to the difficulty's time_limit
  - This ensures σ is judged fairly (2s variance is normal in a 20s game, but erratic in a 10s game)

### Chaos Effects (Hard Mode):
- Screen shake (heavy)
- Mud splatters
- Buzzing fly distraction
- Control reversal
- Visual obstruction

---

## 🔑 Key Takeaways for Thesis

1. **Rolling Window** provides recency-biased adaptation
2. **Linear weights** (1,2,3,4,5) prioritize recent performance
3. **Consistency penalty** catches erratic/guessing behavior
4. **Single Φ metric** simplifies decision making
5. **G-Counter CRDT** ensures conflict-free multiplayer scoring
6. **No difficulty ceiling** - game gets infinitely harder for experts

---

## File Structure Summary

```
autoload/
├── AdaptiveDifficulty.gd   # Main algorithm (Φ = WMA - CP)
├── CoopAdaptation.gd       # Multiplayer co-op algorithm
├── GameManager.gd          # G-Counter + game flow
├── TouchInputManager.gd    # Mobile touch handling
└── AlgorithmOverlay.gd     # Real-time HUD overlay

scenes/ui/
├── AlgorithmDemo.tscn      # Interactive demo for panelists
├── AnalyticsDashboard.tscn # Research data visualization
└── MainMenu.tscn           # Entry point with demo button

test/
├── TEST_ALGORITHMS.gd      # Automated algorithm tests
└── ALGORITHM_VERIFICATION_TEST.gd
```

---

## 🌐 Network Fault Simulation (Thesis Objective 3)

### New: NetworkFaultSimulator Autoload
**Location:** `autoload/NetworkFaultSimulator.gd`

Validates the thesis claim that the G-Counter CRDT achieves convergence <200ms even under 10%–90% packet loss with 100–500ms latency jitter.

#### Features:
- **Configurable packet loss rate:** 0%–100%
- **Random latency jitter:** 100ms–500ms (paper specification)
- **Convergence time measurement:** Microsecond precision
- **Automated sweep test:** Tests 9 loss rates × 20 trials = 180 tests
- **Application-level retransmits:** Mimics real UDP retry behavior

#### How to Access:
1. From Main Menu → **📊 G-Counter CRDT Demo**
2. Scroll to **🌐 NETWORK FAULT INJECTION TEST (Obj. 3)** panel
3. **Single Test:** Runs one convergence test at 20% loss
4. **Full Sweep:** Tests 10%–90% loss rates automatically

#### Sweep Output Table:
| Loss% | Conv% | Avg ms | Max ms | Pass? |
|-------|-------|--------|--------|-------|
| 10%   | 100%  | ~110ms | ~180ms | ✅    |
| 20%   | 100%  | ~120ms | ~200ms | ✅    |
| ...   | ...   | ...    | ...    | ...   |
| 90%   | 100%  | ~180ms | ~350ms | ⚠️    |

---

## 📋 Research Data Dashboard

### New: ResearchDashboard Scene
**Location:** `scenes/ui/ResearchDashboard.gd` + `ResearchDashboard.tscn`

One-stop panel aggregating ALL thesis metrics across all three objectives.

#### Sections:
1. **Objective 1 — Performance Efficiency:** FPS, frame budget, memory, algorithm latency, CPU temp, clock stability
2. **Objective 2 — Energy Efficiency:** Battery drain, measurement source (Android real / desktop estimate), DL baseline comparison
3. **Objective 3 — G-Counter Reliability:** CRDT output spec, property verification, packet loss sweep results
4. **Adaptive Difficulty Algorithm:** Current Φ, WMA, CP, window status

#### Export Options:
- **💾 Export JSON:** Full session data with all metrics → `user://waterwise_research_*.json`
- **📊 Export CSV:** Tabular metrics for Excel/Google Sheets → `user://waterwise_metrics_*.csv`

### How to Access:
From Main Menu → **📋 Research Dashboard** (green button)

---

## ⚡ Algorithm Latency Instrumentation

All core O(1) operations are now instrumented with `PerformanceProfiler` microsecond-precision timing:

| Operation | File | Instrumented? |
|-----------|------|---------------|
| `GCounter.increment()` | GCounter.gd | ✅ |
| `GCounter.merge()` | GCounter.gd | ✅ |
| `AdaptiveDifficulty.add_performance()` | AdaptiveDifficulty.gd | ✅ |

Results visible in:
- F11 overlay → "Algo" row
- Research Dashboard → Algorithm Latency section
- Exported JSON/CSV reports

---

## 🔋 Battery Measurement

| Platform | Method | Accuracy |
|----------|--------|----------|
| **Android** | `OS.get_power_percent_left()` → real % drop × battery capacity | Hardware-measured |
| **Desktop** | Workload-proportional heuristic (frame_time / budget × 1.5 mAh/min) | Estimated |

The `measurement_source` field in exports clearly labels whether data is `android_real` or `desktop_estimate`.

---

*Documentation generated for WaterWise Thesis Defense - February 2026*

