# 🐛 CRITICAL BUGS FIXED

**Date:** May 3, 2026  
**Status:** FIXED

---

## 🔴 BUG 1: Single Player Redirects to Multiplayer

### Problem:
After playing single player games, the game redirects to multiplayer lobby/menu instead of returning to main menu.

### Root Cause:
`current_game_mode` in GameManager was not being reset when returning to main menu, so it stayed as MULTIPLAYER_COOP from a previous session.

### Fix Applied:
Added game mode reset in `return_to_main_menu()`:

```gdscript
func return_to_main_menu() -> void:
    _finalize_session_for_logging()
    change_state(GameState.MAIN_MENU)
    get_tree().paused = false
    
    # Reset game mode to prevent multiplayer redirect bug
    current_game_mode = GameMode.SINGLE_PLAYER  # ← ADDED THIS
    
    if session_score > high_score:
        high_score = session_score
        _save_data()
    
    get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")
```

### Testing:
- [x] Code fixed
- [ ] Test: Play single player → Finish → Should go to InitialScreen
- [ ] Test: Play multiplayer → Finish → Should go to MultiplayerLobby
- [ ] Test: Switch between modes → Should not mix up

---

## 🔴 BUG 2: UI Layout Not Filling Screen

### Problem:
Game UI elements are too small and don't fill the screen on mobile. Lots of empty black space.

### Root Cause:
Viewport stretch mode was set to "canvas_items" which doesn't scale the viewport itself, only individual canvas items.

### Fix Applied:
Changed stretch mode in `project.godot`:

```ini
# BEFORE (Wrong):
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

# AFTER (Correct):
window/stretch/mode="viewport"
window/stretch/aspect="expand"
window/stretch/scale=1.0
```

### What This Does:
- **viewport mode**: Scales the entire 1920x1080 viewport to fit the screen
- **expand aspect**: Fills the screen completely (may crop edges slightly)
- **scale=1.0**: Base scale factor

### Testing:
- [x] Code fixed
- [ ] **IMPORTANT: Restart Godot editor** (required for stretch mode changes)
- [ ] Rebuild APK
- [ ] Test on phone: UI should fill entire screen
- [ ] Test on phone: No black bars or empty spaces
- [ ] Test on phone: Buttons properly sized for touch

---

## 🔴 BUG 3: Missing Assets (Garbled Emoji)

### Problem:
PlugTheLeak finish animation shows garbled emoji for missing assets.

### Root Cause:
Missing texture/sprite files or incorrect file paths in the outro scene.

### Investigation Needed:
The missing asset needs to be identified. Possible causes:
1. Texture file deleted or moved
2. Incorrect path in .tscn file
3. Font file missing (if it's text)
4. Asset not exported with APK

### How to Fix:
1. **Find the missing asset:**
   - Open `scenes/ui/cutscenes/outro/PlugTheLeakOutro.tscn` in Godot
   - Look for red "!" icons indicating missing resources
   - Check the Output/Debugger for "Failed to load" errors

2. **Fix the path:**
   - If asset exists but path is wrong, update the path
   - If asset is missing, add it back or use a placeholder

3. **Verify export:**
   - Check `export_presets.cfg` to ensure assets are included
   - Make sure the asset folder is not in `.gitignore`

### Temporary Workaround:
If the asset is not critical, you can:
- Hide the node that's missing the asset
- Replace with a simple colored rectangle
- Use a fallback texture

---

## 📋 TESTING CHECKLIST

### Bug 1: Multiplayer Redirect
- [ ] Play 3 single player games
- [ ] Finish session
- [ ] Verify: Goes to InitialScreen (NOT MultiplayerLobby)
- [ ] Play multiplayer game
- [ ] Finish session
- [ ] Verify: Goes to MultiplayerLobby (correct)

### Bug 2: UI Layout
- [ ] **Restart Godot editor first!**
- [ ] Export APK
- [ ] Install on phone
- [ ] Check Main Menu: Should fill screen
- [ ] Check InitialScreen: Should fill screen
- [ ] Check Game screens: Should fill screen
- [ ] Check Animations: Should fill screen
- [ ] No black bars or empty spaces

### Bug 3: Missing Assets
- [ ] Open PlugTheLeakOutro.tscn in Godot
- [ ] Identify missing resources (red "!" icons)
- [ ] Fix paths or add missing files
- [ ] Test outro animation in editor
- [ ] Export APK and test on phone

---

## 🚨 IMPORTANT NOTES

### Viewport Stretch Mode:
**You MUST restart Godot editor after changing stretch mode!**

The stretch mode is cached and won't update until you:
1. Close Godot completely
2. Reopen the project
3. Rebuild the APK

### Game Mode Tracking:
The `current_game_mode` variable is critical for routing:
- `SINGLE_PLAYER` → InitialScreen
- `MULTIPLAYER_COOP` → MultiplayerLobby

Always reset it when returning to menus!

### Missing Assets:
Missing assets will show as:
- Garbled emoji (�)
- Pink/magenta placeholder
- Empty space
- Console errors

Always check the Output tab for "Failed to load" messages.

---

## 📊 SUMMARY

| Bug | Status | Priority | Fix Applied |
|-----|--------|----------|-------------|
| Multiplayer Redirect | ✅ FIXED | HIGH | Reset game mode in return_to_main_menu() |
| UI Layout | ✅ FIXED | HIGH | Changed stretch mode to "viewport" |
| Missing Assets | ⚠️ NEEDS INVESTIGATION | MEDIUM | Identify and fix missing files |

**Next Steps:**
1. Restart Godot editor
2. Rebuild APK
3. Test all three bugs on device
4. Investigate missing asset in PlugTheLeakOutro
