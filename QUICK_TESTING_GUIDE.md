# ⚡ QUICK TESTING GUIDE - 5 MINUTE CHECKLIST

**Use this for rapid testing on devices**

---

## 🎯 5-MINUTE SMOKE TEST

### 1. Multiplayer Test (2 minutes)
```
Device 1: Host game
Device 2: Join game
Play until quota reached
✅ Game ends with WIN screen
✅ No freezing
```

### 2. Blue Screen Test (1 minute)
```
Play 3 single-player games in a row
✅ No blue screen after game #2
✅ Games continue smoothly
```

### 3. Performance Test (1 minute)
```
Play 1 game, watch cutscene
✅ Smooth 60 FPS gameplay
✅ No lag during cutscene
✅ Smooth scene transition
```

### 4. Touch Test (1 minute)
```
Tap 10 falling objects
✅ All taps register
✅ Visual feedback appears
✅ No missed taps
```

---

## 🚨 CRITICAL ISSUES TO WATCH FOR

### ❌ FAIL if you see:
- Multiplayer game freezes (assets spawn but don't move)
- Blue screen after 2 games
- FPS drops below 30 during gameplay
- Scene transitions freeze for >200ms
- Touch inputs miss frequently (>10%)
- Memory usage exceeds 300MB
- App crashes

### ✅ PASS if you see:
- Multiplayer game ends properly
- No blue screen at any point
- Smooth 60 FPS gameplay
- Instant scene transitions
- All touches register
- Memory stays under 250MB
- No crashes

---

## 📱 DEVICE INFO TO COLLECT

```
Device Model: _____________
Android Version: _____________
RAM: _____________
Screen Size: _____________
Test Result: PASS / FAIL
Notes: _____________
```

---

## 🐛 IF SOMETHING FAILS

### Multiplayer Freezes:
```bash
adb logcat | grep "Time up\|Final Score"
# Look for: "⏰ Time up!" and "📊 Final Score"
```

### Blue Screen:
```bash
adb logcat | grep "Story\|mobile"
# Look for: "📱 Mobile mode" and story screen messages
```

### Performance Issues:
```bash
adb logcat | grep "FPS\|particle"
# Look for: Particle count and FPS warnings
```

### Memory Issues:
```bash
adb shell dumpsys meminfo com.waterwise.thesis
# Check: Total PSS should be <250MB
```

---

## ✅ QUICK PASS/FAIL CHECKLIST

- [ ] Multiplayer works (no freezing)
- [ ] No blue screen (play 5+ games)
- [ ] Smooth 60 FPS gameplay
- [ ] Fast scene transitions
- [ ] Touch input responsive
- [ ] Memory stable (<250MB)
- [ ] No crashes (30 min play)

**If all checked:** ✅ READY FOR PRODUCTION  
**If any unchecked:** ❌ NEEDS MORE WORK

---

**Test Date:** _____________  
**Tester:** _____________  
**Result:** ⬜ PASS | ⬜ FAIL

