# 🎮 MULTIPLAYER TESTING GUIDE
**WaterWise - Testing Multiplayer Features in Godot**

---

## 📋 TABLE OF CONTENTS

1. [Quick Start](#quick-start)
2. [Method 1: Debug Menu (Recommended)](#method-1-debug-menu-recommended)
3. [Method 2: Multiple Godot Instances](#method-2-multiple-godot-instances)
4. [Method 3: Exported Builds](#method-3-exported-builds)
5. [Testing Checklist](#testing-checklist)
6. [Troubleshooting](#troubleshooting)

---

## 🚀 QUICK START

### **Network Configuration:**
- **Default Port:** `7777`
- **Protocol:** ENet (UDP)
- **Players:** 2 (Host + 1 Client)
- **Host IP:** `127.0.0.1` (localhost for same PC testing)

---

## 🎯 METHOD 1: DEBUG MENU (Recommended)

I'll create a debug menu scene that you can use to quickly test multiplayer.

### **Step 1: Create Debug Menu Scene**

1. Create a new scene: `res://scenes/ui/DebugMultiplayer.tscn`
2. Add the following nodes:
   ```
   Control (DebugMultiplayer)
   ├── ColorRect (Background)
   ├── VBoxContainer (CenterContainer)
   │   ├── Label (Title)
   │   ├── Button (HostButton)
   │   ├── Button (JoinButton)
   │   ├── LineEdit (IPInput)
   │   └── Label (StatusLabel)
   ```

### **Step 2: Use the Debug Menu**

Run the debug menu scene twice:
- **Window 1:** Click "Host Game" → Becomes Player 1 (Collector)
- **Window 2:** Enter IP `127.0.0.1` → Click "Join Game" → Becomes Player 2 (Destroyer)

---

## 🖥️ METHOD 2: MULTIPLE GODOT INSTANCES

### **Option A: Run from Editor (Easiest)**

**Step 1: Enable Remote Debugging**
1. Go to `Editor → Editor Settings`
2. Search for "Remote Port"
3. Note the default port (usually 6007)

**Step 2: Launch First Instance (Host)**
1. Click `▶ Run Project` (F5) in Godot
2. This becomes your HOST

**Step 3: Launch Second Instance (Client)**
1. Open a NEW Godot instance (launch Godot.exe again)
2. Open the SAME project
3. Click `▶ Run Project` (F5)
4. This becomes your CLIENT

**Step 4: Connect**
- In HOST window: Navigate to multiplayer lobby → Click "Host Game"
- In CLIENT window: Enter IP `127.0.0.1` → Click "Join Game"

### **Option B: Using Command Line**

Open **2 separate terminals** in your project folder:

**Terminal 1 (Host):**
```powershell
# Run Godot with custom port for debugging
& "C:\Program Files\Godot\Godot_v4.x.exe" --path . --remote-debug tcp://127.0.0.1:6007
```

**Terminal 2 (Client):**
```powershell
# Run second instance with different debug port
& "C:\Program Files\Godot\Godot_v4.x.exe" --path . --remote-debug tcp://127.0.0.1:6008
```

---

## 📦 METHOD 3: EXPORTED BUILDS (Most Realistic)

### **Step 1: Export the Game**
1. Go to `Project → Export`
2. Add "Windows Desktop" preset (or your OS)
3. Export to: `builds/WaterWise_v1.exe`

### **Step 2: Run Multiple Instances**

**Terminal 1 (Host):**
```powershell
cd builds
.\WaterWise_v1.exe
```

**Terminal 2 (Client):**
```powershell
cd builds
.\WaterWise_v1.exe
```

### **Step 3: Connect**
- Window 1: Host game
- Window 2: Join with `127.0.0.1`

---

## ✅ TESTING CHECKLIST

### **Pre-Test Verification:**
- [ ] Port 7777 is not blocked by firewall
- [ ] No other app is using port 7777
- [ ] Both instances can see "Multiplayer Lobby" screen

### **G-Counter CRDT Testing:**

**Test 1: Score Synchronization**
- [ ] Host catches 3 drops → Global score = 3
- [ ] Client destroys 2 leaves → Global score = 5
- [ ] Both windows show same global score
- [ ] Console shows: `G-Counter state: {1: 3, 2: 2}`

**Test 2: Win Condition**
- [ ] Play until global score reaches 20
- [ ] Both players see "🏆 TEAM WINS!" at same time
- [ ] Console shows: `GlobalScore = Σ(PlayerInput_i) = 20`

**Test 3: Network Resilience**
- [ ] Disconnect client mid-game
- [ ] Reconnect client
- [ ] Scores still accurate (G-Counter properties hold)

### **Rolling Window Adaptive Difficulty Testing:**

**Test 4: Single Round Completion**
- [ ] Complete first multiplayer round quickly (< 15s)
- [ ] Check HOST console for: `📊 [Rolling Window] Round completed in Xs`
- [ ] Verify round time was recorded

**Test 5: Difficulty Increase (3 Rounds)**
- [ ] Complete Round 1 in ~10 seconds
- [ ] Complete Round 2 in ~10 seconds
- [ ] Complete Round 3 in ~10 seconds
- [ ] After Round 3, console shows: `⬆️ Increasing difficulty - Multiplier: 1.2`
- [ ] Round 4 spawns items **faster** (observe spawn rate)

**Test 6: Uncapped Scaling**
- [ ] Complete 9 rounds quickly (< 15s average each 3)
- [ ] After Round 9, difficulty_multiplier should be ~1.6 or higher
- [ ] Continue playing - verify NO CEILING (can go above 2.0)
- [ ] Console shows: "Multiplier: 2.2", "2.4", "2.6", etc.

**Test 7: Difficulty Sync to Client**
- [ ] Host completes 3 fast rounds
- [ ] Check CLIENT console for: `📡 Difficulty synced: 1.2`
- [ ] Client also experiences faster spawns

### **Team Lives System Testing:**

**Test 8: Life Loss**
- [ ] Miss a water drop (Host)
- [ ] Console shows: `💔 Team lost a life! Remaining: 2`
- [ ] Both windows show `❤️❤️` (2 hearts)
- [ ] Lives synced across network

**Test 9: Game Over**
- [ ] Miss 3 items total
- [ ] Both players see: `💀 GAME OVER`
- [ ] Console shows: `☠️ Game Over! Team ran out of lives!`

---

## 🔍 CONSOLE OUTPUT GUIDE

### **What to Look For:**

**HOST Console (Player 1):**
```
✅ Server created on port 7777
🎮 You are Player 1 (Host)
✅ Player connected: 2
📡 Game state synced from host

--- During Gameplay ---
💧 Player 1 scored 1 points
   G-Counter state: {1: 1}
🎯 Global Score: 1 / 20

💧 Player 2 scored 1 points
   G-Counter state: {1: 1, 2: 1}
🎯 Global Score: 2 / 20

--- After 3 Rounds ---
📊 Rolling Window: [12.5, 10.3, 9.8]
📈 Average Round Time: 10.87s
⬆️ Increasing difficulty (too fast) - Multiplier: 1.20

--- Victory ---
🎉 TEAM WINS!
🏆 Victory! Team reached quota!
📊 [Rolling Window] Round completed in 14.50s
```

**CLIENT Console (Player 2):**
```
🔄 Connecting to 127.0.0.1:7777
✅ Connected to server!
📡 Game state synced from host

--- During Gameplay ---
💧 Player 2 scored 1 points
   G-Counter state: {2: 1}

📡 Difficulty synced: 1.20

--- Victory ---
🎉 TEAM WINS!
🏆 Victory! Team reached quota!
```

---

## 🐛 TROUBLESHOOTING

### **Problem: "Failed to create server"**
**Cause:** Port 7777 is in use or blocked

**Solutions:**
1. Check Windows Firewall:
   ```powershell
   # Run as Administrator
   netsh advfirewall firewall add rule name="Godot Port 7777" dir=in action=allow protocol=UDP localport=7777
   ```

2. Check if port is in use:
   ```powershell
   netstat -ano | findstr :7777
   ```

3. Change port in `GameManager.gd`:
   ```gdscript
   const DEFAULT_PORT: int = 8888  # Try different port
   ```

---

### **Problem: "Connection failed"**
**Cause:** Can't reach host

**Solutions:**
1. Verify both instances are running
2. Use `127.0.0.1` for localhost (same PC)
3. Check IP is correct:
   ```powershell
   ipconfig
   # Look for IPv4 Address
   ```
4. Try `localhost` instead of `127.0.0.1`

---

### **Problem: "Scores not syncing"**
**Cause:** RPC calls not working

**Solutions:**
1. Check console for errors
2. Verify `@rpc` annotations are correct
3. Ensure `multiplayer.multiplayer_peer` is set
4. Check if `submit_score()` is being called:
   ```gdscript
   # Add debug print in GameManager.gd
   func submit_score(points: int) -> void:
       print("🔍 [DEBUG] submit_score called by peer: ", multiplayer.get_remote_sender_id())
       # ... rest of function
   ```

---

### **Problem: "Difficulty not increasing"**
**Cause:** Rolling window not being updated

**Solutions:**
1. Check HOST console for: `📊 [Rolling Window] Round completed`
2. Verify you're winning rounds (reaching 20 points)
3. Check if `_on_team_won()` is being called:
   ```gdscript
   # Add debug in MiniGame_Rain.gd
   func _on_team_won() -> void:
       print("🔍 [DEBUG] _on_team_won called!")
       # ... rest of function
   ```
4. Ensure you complete **3 rounds** before difficulty adjusts

---

### **Problem: "Second Godot instance won't launch"**
**Cause:** Editor settings conflict

**Solutions:**
1. Use exported builds instead
2. Or run from command line with different debug ports:
   ```powershell
   # Instance 1
   godot.exe --path . --remote-debug tcp://127.0.0.1:6007
   
   # Instance 2
   godot.exe --path . --remote-debug tcp://127.0.0.1:6008
   ```

---

## 📊 PERFORMANCE METRICS TO TRACK

### **G-Counter Metrics:**
- ✅ Score increments: Should be instant (< 100ms)
- ✅ Global score accuracy: Always equals Σ(peer_scores)
- ✅ Network messages: Check "Remote" tab in debugger

### **Rolling Window Metrics:**
- ✅ Round times: Should be recorded in seconds
- ✅ Window size: Always 3 (check array length)
- ✅ Difficulty adjustment: Every 3 rounds
- ✅ Spawn rate decrease: Visible in gameplay (items spawn faster)

### **Network Metrics:**
- ✅ Latency: < 50ms for localhost
- ✅ Packet loss: 0% for localhost
- ✅ Synchronization delay: < 200ms

---

## 🎮 RECOMMENDED TEST SEQUENCE

### **5-Minute Quick Test:**
1. Launch 2 instances (2 min)
2. Host creates game (30 sec)
3. Client joins (30 sec)
4. Play 1 round to completion (1 min)
5. Check consoles for G-Counter output (30 sec)

### **15-Minute Full Test:**
1. Launch 2 instances
2. Complete 3 rounds quickly (< 15s each)
3. Verify difficulty increases to 1.2×
4. Complete 3 more rounds
5. Verify difficulty increases to 1.4×
6. Intentionally miss items to test life system
7. Verify game over at 0 lives

### **30-Minute Stress Test:**
1. Complete 15 rounds
2. Track difficulty_multiplier progression
3. Verify uncapped scaling (should reach 2.0+)
4. Test disconnect/reconnect scenarios
5. Monitor console for errors
6. Check memory usage in Task Manager

---

## 🔧 DEBUG TOOLS

### **Add Debug Overlay to Game:**

Create a simple debug display:

```gdscript
# Add to your HUD
@onready var debug_label: Label = $DebugLabel

func _process(_delta: float) -> void:
    if GameManager:
        var debug_text = """
        🎮 Player: %s
        🏆 Global Score: %d / %d
        💪 Difficulty: %.2f×
        ❤️ Lives: %d
        📊 Window: %s
        """ % [
            "HOST (P1)" if GameManager.is_host else "CLIENT (P2)",
            GameManager.get_global_score(),
            GameManager.LEVEL_QUOTA,
            GameManager.difficulty_multiplier,
            GameManager.team_lives,
            str(GameManager.rolling_window)
        ]
        debug_label.text = debug_text
```

### **Enable Verbose Logging:**

```gdscript
# In GameManager.gd _ready():
func _ready() -> void:
    # ... existing code ...
    
    # Enable debug mode
    OS.set_environment("GODOT_DEBUG", "1")
    print("🐛 DEBUG MODE ENABLED")
```

---

## ✅ SUCCESS CRITERIA

Your multiplayer is working correctly if:

1. ✅ Both players can connect
2. ✅ Scores sync in real-time (both windows show same total)
3. ✅ Win condition triggers at 20 points for both players
4. ✅ Lives decrease on both windows when items are missed
5. ✅ After 3 fast rounds, difficulty increases (console shows 1.2×)
6. ✅ Spawn rate visibly increases in subsequent rounds
7. ✅ Difficulty can exceed 2.0× (uncapped)
8. ✅ No errors in console during gameplay

---

## 📚 ADDITIONAL RESOURCES

### **Godot Multiplayer Docs:**
- High-level multiplayer: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- ENet: https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html

### **Debug Commands:**
```gdscript
# Print all connected peers
print("Connected peers: ", multiplayer.get_peers())

# Print your peer ID
print("My peer ID: ", multiplayer.get_unique_id())

# Check if you're the server
print("Am I server? ", multiplayer.is_server())
```

---

**Happy Testing! 🎉**

If you encounter any issues not covered here, check the console output first - it will tell you exactly what's happening with the G-Counter and Rolling Window systems.
