# How to Test the New Cutscene System

## Quick Test (Recommended)

1. **Open Godot 4.5**
2. **Run any minigame scene** (e.g., `scenes/minigames/WringItOut.tscn`)
3. **Play the minigame** until it ends (win or fail)
4. **Watch for the cutscene**:
   - You should see a background fade in
   - An animated water droplet character should appear
   - It should bounce (win) or wobble (fail)
   - After ~1 second, it fades out
   - Game continues to score screen

## What to Look For

### Success Indicators ✅
- Console shows: `🎬 SimpleCutscenePlayer: Starting cutscene for [MinigameName] (type: 0 or 1)`
- Background appears (green for win, brown for fail)
- Water droplet character is visible
- Character animates smoothly
- Console shows: `✅ SimpleCutscenePlayer: Cutscene finished`
- Game continues to score screen

### Failure Indicators ❌
- No cutscene appears (just freeze then score screen)
- Console shows errors about SimpleCutscenePlayer
- Character doesn't animate
- Game gets stuck

## Detailed Testing Steps

### Test 1: Win Cutscene
1. Run a minigame
2. Complete it successfully
3. Verify:
   - Green-tinted background appears
   - Water droplet pops in with bounce
   - Droplet has happy smile (curved up)
   - Animation lasts ~1.3 seconds
   - Fades out smoothly

### Test 2: Fail Cutscene
1. Run a minigame
2. Let it fail (run out of time or make mistakes)
3. Verify:
   - Brown-tinted background appears
   - Water droplet drops in with wobble
   - Droplet has sad frown (curved down)
   - Animation lasts ~1.2 seconds
   - Fades out smoothly

### Test 3: Multiple Minigames
1. Play through 3-4 minigames in a row
2. Verify cutscene appears after each one
3. Check that there are no memory leaks (game doesn't slow down)

### Test 4: Fallback System
1. Temporarily rename `SimpleCutscenePlayer.gd` to break it
2. Run a minigame
3. Verify the old emoji system still works as fallback
4. Rename the file back

## Console Output Examples

### Normal Operation
```
🎮 Game State: PLAYING_MINIGAME → MINIGAME_RESULTS
🎬 SimpleCutscenePlayer: Starting cutscene for WringItOut (type: 0)
✅ SimpleCutscenePlayer: Cutscene finished
```

### If Something Goes Wrong
```
🎮 Game State: PLAYING_MINIGAME → MINIGAME_RESULTS
E 0:00:10:123   SimpleCutscenePlayer.gd:XX @ play_cutscene(): [Error message]
[Falls back to emoji system]
```

## Troubleshooting

### Problem: No cutscene appears at all
**Solution**: Check that `SimpleCutscenePlayer.gd` exists in `scripts/cutscenes/`

### Problem: Cutscene appears but doesn't animate
**Solution**: Check console for Tween errors. Verify Godot version is 4.5+

### Problem: Character looks wrong
**Solution**: This is expected - it's a simple programmatic drawing. You can enhance it later.

### Problem: Game freezes during cutscene
**Solution**: Check that `cutscene_finished` signal is being emitted. Add debug print before `emit()`.

### Problem: Cutscene is too fast/slow
**Solution**: Adjust timing values in `_animate_droplet()` function:
- Change `await get_tree().create_timer(0.6).timeout` to longer/shorter
- Adjust Tween durations (0.2, 0.15, etc.)

## Performance Check

The cutscene should:
- Start within 50ms of minigame ending
- Run at 60 FPS throughout
- Use less than 10MB of memory
- Clean up completely after finishing

## Next Steps After Testing

If cutscenes work:
1. ✅ Mark this as complete
2. Consider adding sound effects
3. Consider adding particle effects
4. Consider creating minigame-specific variants

If cutscenes don't work:
1. Check console for errors
2. Verify file paths are correct
3. Check that MiniGameBase is calling the right methods
4. Try the fallback emoji system

## Files to Check

- `scripts/cutscenes/SimpleCutscenePlayer.gd` - Main cutscene player
- `scripts/MiniGameBase.gd` - Integration point (lines 54, 623-630, 1346, 1360)
- Console output - Debug messages

## Expected Behavior Summary

```
Minigame ends
    ↓
_show_success_micro_cutscene() or _show_failure_micro_cutscene() called
    ↓
SimpleCutscenePlayer.visible = true
    ↓
play_cutscene(minigame_key, 0 or 1) called
    ↓
Background fades in (0.2s)
    ↓
Character appears and animates (0.5-0.8s)
    ↓
Hold (0.5-0.6s)
    ↓
Fade out (0.2s)
    ↓
cutscene_finished signal emitted
    ↓
SimpleCutscenePlayer.visible = false
    ↓
Game continues to score screen
```

Total time: ~1.2-1.5 seconds per cutscene

## Success Criteria

- ✅ Cutscene appears after every minigame
- ✅ Animation is smooth and visible
- ✅ Character has correct expression (happy/sad)
- ✅ Game flow is not interrupted
- ✅ No errors in console
- ✅ No memory leaks
- ✅ Works for all minigames

If all criteria are met, the system is working correctly! 🎉
