# WaterWise Algorithm Demonstration

## For Panelists Review

This folder contains interactive demonstrations of the game's adaptive difficulty algorithms.

---

## 📁 Contents

### 1. **DemoLauncher.tscn** (START HERE)
Main menu for all demonstrations.
- Launch demo minigame
- Run automated tests
- Test G-Counter algorithm
- Reset system

### 2. **DemoMinigame.tscn**
Playable minigame showing real-time algorithm operation:
- Click water droplets to collect them
- **Live algorithm display** shows:
  - Window size (5 games)
  - Games played
  - Proficiency Index (Φ)
  - Current difficulty
- Difficulty adapts based on performance

### 3. **AutomatedTest.tscn**
Automated test suite showing:
- Poor performance → Easy difficulty
- Improved performance → Medium difficulty
- Expert performance → Hard difficulty
- Real-time console output

### 4. **GCounterTest.tscn**
Interactive G-Counter demonstration:
- Two player buttons (simulate multiplayer)
- Visual formula: Player1 + Player2 = Global Score
- Quota tracking
- Shows conflict-free score synchronization

---

## 🎮 How to Use

### In Godot Editor:
1. Open Godot project
2. Navigate to `test/DemoLauncher.tscn`
3. Press **F6** (Run Current Scene)
4. Choose demonstration from menu

### From Main Game:
You can add a "Demo Mode" button to the main menu that links to:
```
res://test/DemoLauncher.tscn
```

---

## 📊 What Panelists Will See

### Rolling Window Algorithm (Single-Player)
- **Window Size**: 5 games
- **Adaptation Frequency**: Every 2 games
- **Formula**: Φ = WMA - CP
  - WMA = Weighted Moving Average (recent games matter more)
  - CP = Consistency Penalty (punishes erratic timing)
- **Thresholds**:
  - Φ < 0.50 → Easy
  - 0.50 ≤ Φ ≤ 0.85 → Medium
  - Φ > 0.85 → Hard

### G-Counter Algorithm (Multiplayer)
- **Formula**: GlobalScore = Σ(PlayerInput_i)
- **Properties**:
  - Conflict-free (each player has own counter)
  - Monotonic (scores only increase)
  - Eventually consistent (all players converge to same total)
- **Win Condition**: Global Score ≥ Quota

---

## 🧪 Testing Scenarios

### Demo Minigame
1. Play poorly (miss targets) → See difficulty drop to Easy
2. Improve performance → See difficulty rise to Medium
3. Play perfectly → See difficulty rise to Hard
4. Watch live Φ calculation update

### Automated Test
- Runs 13 simulated games automatically
- Shows algorithm responding to different player skills
- Completes in ~10 seconds

### G-Counter Test
- Click buttons to add points for each player
- Watch global score update in real-time
- See quota progress
- Demonstrates multiplayer scoring

---

## 📝 Algorithm Details

### Rolling Window (5 Games)
```
Game 1 (oldest)   → Weight: 1
Game 2            → Weight: 2  
Game 3            → Weight: 3
Game 4            → Weight: 4
Game 5 (newest)   → Weight: 5 ← Most Important!
```

### Proficiency Index
```
Φ = WMA - CP

WMA = Σ(accuracy_i × weight_i) / Σ(weight_i)
CP = σ(time) / mean(time)

Where:
- accuracy_i = % correct in game i
- weight_i = recency weight (1-5)
- σ(time) = standard deviation of completion times
- mean(time) = average completion time
```

### G-Counter
```
Player 1: 5 points
Player 2: 7 points
──────────────────
Global:   12 points = 5 + 7

Each player only increments their own counter.
Server sums all counters to get global score.
```

---

## 🎯 Key Points for Panelists

1. **Adaptive**: Difficulty responds to player skill in real-time
2. **Fair**: Weighted average prevents lucky/unlucky streaks from dominating
3. **Consistent**: Rewards stable performance, not just high scores
4. **Scalable**: Works with any number of minigames
5. **Multiplayer**: G-Counter ensures fair team scoring without conflicts

---

## 🔧 Technical Notes

- All demonstrations use the **same algorithm code** as the main game
- No hardcoded values - all calculations are live
- Reset button clears algorithm state for fresh testing
- Console output shows detailed calculations

---

## 📞 Support

If panelists have questions, they can:
1. Check console output (shows detailed algorithm steps)
2. Review the live display in Demo Minigame
3. Run Automated Test to see algorithm behavior
4. Play multiple rounds to see adaptation in action
