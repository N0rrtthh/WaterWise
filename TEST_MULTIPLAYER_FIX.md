# 🧪 MULTIPLAYER FIX - TESTING GUIDE

## Quick Test Procedure

### Setup:
1. Build APK with the fix applied
2. Install on 2 Android devices
3. Connect via hotspot (Device 1 creates hotspot, Device 2 connects)

### Test Case 1: Game Ends When Quota Reached
**Expected:** Game ends with WIN screen

1. Device 1: Host game
2. Device 2: Join game  
3. Both: Ready up
4. Play game and reach quota (e.g., 50 points combined)
5. **VERIFY:** Game ends immediately when team score >= quota
6. **VERIFY:** Both devices show WIN screen
7. **VERIFY:** Next game loads after 3 seconds

**Pass Criteria:**
- ✅ Game ends when team score reaches quota
- ✅ Both players see WIN screen
- ✅ No freezing or infinite spawning
- ✅ Smooth transition to next game

---

### Test Case 2: Game Ends When Time Runs Out (Quota Met)
**Expected:** Game ends with WIN screen

1. Host game
2. Play until team score >= quota
3. Wait for timer to reach 0
4. **VERIFY:** Game ends with WIN
5. **VERIFY:** No freezing

**Pass Criteria:**
- ✅ Timer reaches 0
- ✅ Game ends with WIN (quota was met)
- ✅ Both devices synchronized

---

### Test Case 3: Game Ends When Time Runs Out (Quota NOT Met)
**Expected:** Game ends with FAIL screen

1. Host game
2. Play slowly, don't reach quota
3. Wait for timer to reach 0
4. **VERIFY:** Game ends with FAIL
5. **VERIFY:** Team loses a life
6. **VERIFY:** Next game loads

**Pass Criteria:**
- ✅ Timer reaches 0
- ✅ Game ends with FAIL (quota not met)
- ✅ Life deducted
- ✅ No freezing

---

### Test Case 4: Disconnection Handling
**Expected:** Other player returns to lobby

1. Start game
2. Mid-game: Device 2 closes app or disconnects WiFi
3. **VERIFY:** Device 1 shows "Player disconnected" message
4. **VERIFY:** Device 1 returns to lobby after 3 seconds
5. **VERIFY:** No crash or freeze

**Pass Criteria:**
- ✅ Disconnection detected
- ✅ Graceful return to lobby
- ✅ No crash

---

### Test Case 5: Score Distribution Check
**Expected:** Both players contribute to team score

1. Start game
2. Device 1: Catch 30 drops (30 points)
3. Device 2: Filter 25 water (25 points)
4. **VERIFY:** HUD shows team score = 55
5. **VERIFY:** Game ends with WIN (if quota <= 55)

**Pass Criteria:**
- ✅ Team score = sum of both players
- ✅ HUD updates in real-time
- ✅ Win condition checks team score

---

## Debug Checklist

### If Game Still Freezes:

**Check Console Logs:**
```bash
# Connect device via USB
adb logcat | grep "Godot\|WaterWise"
```

**Look for:**
- `⏰ Time up!` - Timer expired
- `📊 Final Score: Team=X, Local=Y, Quota=Z` - Score check
- `✅ TEAM WIN!` or `❌ TEAM FAIL!` - End game decision
- `game_active = false` - Game stopped

**If you see:**
- Timer reaches 0 but no "Time up!" → Timer not connected
- "Time up!" but no score log → Function not executing
- Score log but no WIN/FAIL → Logic error
- WIN/FAIL but game doesn't end → `end_game()` not called

---

### If Scores Don't Add Up:

**Check G-Counter:**
```bash
adb logcat | grep "G-Counter\|submit_score"
```

**Look for:**
- `💧 P1 scored X | Global: Y / Z` - Score submissions
- `G-Counter state: {1: X, 2: Y}` - Counter values
- `📡 Game state merged` - Synchronization

---

### If One Device Shows Different Result:

**Synchronization Issue:**
- Check network latency: `ping <other_device_ip>`
- Verify both devices have same APK version
- Check if RPC calls are reaching both devices

---

## Android File Export Testing

### Verify Files Are Saved:

```bash
# Connect device via USB
adb devices
adb shell

# Navigate to app directory
cd /data/data/com.waterwise.thesis/files/

# List files
ls -la

# Check specific logs
cat session_log_*.json
```

### Pull Files to Computer:

```bash
# Pull entire files directory
adb pull /data/data/com.waterwise.thesis/files/ ./android_files/

# Pull specific file
adb pull /data/data/com.waterwise.thesis/files/session_log_2026-05-03.json ./
```

### Expected Files:
- `waterwise_save.json` - Player progress
- `waterwise_settings.json` - Settings
- `session_logs/session_log_*.json` - Session logs (if dev mode enabled)
- `case_study_*.json` - Adaptive difficulty data

---

## Performance Testing

### Network Latency Test:
```bash
# From Device 1 (host), ping Device 2
ping <device2_ip>

# Good: < 50ms
# Acceptable: 50-100ms
# Poor: > 100ms (may cause desync)
```

### Frame Rate Check:
- Enable FPS counter in game
- Should maintain 60 FPS on both devices
- Drops below 30 FPS indicate performance issues

---

## Success Criteria

### ✅ All Tests Pass If:
1. Game ends properly when quota reached
2. Game ends properly when time runs out
3. Both devices show same result (WIN/FAIL)
4. No freezing or infinite spawning
5. Disconnection handled gracefully
6. Files saved to correct location
7. Smooth gameplay at 60 FPS

### ❌ Fail If:
1. Game freezes (assets spawn but don't move)
2. Timer reaches 0 but game continues
3. Devices show different results
4. Crash on disconnection
5. Files not saved
6. Severe lag or stuttering

---

## Rollback Plan

If fix doesn't work:
1. Revert `MultiplayerMiniGameBase.gd` changes
2. Check if issue is in specific game (e.g., MP_CatchTheRain)
3. Test with NetworkManager path vs GameManager path
4. Enable verbose logging and analyze

---

**Tester:** _____________  
**Date:** _____________  
**Result:** ⬜ PASS | ⬜ FAIL  
**Notes:** _____________________________________________
