# How to Add Demo Button to Main Menu

## Quick Guide

### Option 1: Add in Godot Editor (Recommended)

1. Open `scenes/ui/InitialScreen.tscn` in Godot Editor
2. In the Scene tree, find `UI/ButtonContainer`
3. Right-click on `ButtonContainer` → Add Child Node → Select `Button`
4. Name it: `DemoButton`
5. In the Inspector, set:
   - **Text**: "🧪 DEMO MODE"
   - **Theme Overrides > Font Sizes > Font Size**: 28
   - **Layout > Transform > Size**: (400, 70)
6. Select the `DemoButton` node
7. Go to the **Node** tab (next to Inspector)
8. Find the `pressed()` signal
9. Double-click it → Connect to `InitialScreen` → Method: `_on_demo_button_pressed`
10. Save the scene

### Option 2: Run Directly (Temporary Access)

In Godot Editor:
1. Open `test/DemoLauncher.tscn`
2. Press **F6** (Run Current Scene)

This bypasses the main menu and goes straight to the demo.

### Option 3: Manual Scene File Edit

Add this after the MultiplayerButton node in `InitialScreen.tscn`:

```
[node name="DemoButton" type="Button" parent="UI/ButtonContainer"]
layout_mode = 2
custom_minimum_size = Vector2(400, 70)
theme_override_font_sizes/font_size = 28
text = "🧪 DEMO MODE"
```

And add this connection at the end of the file (in the connections section):

```
[connection signal="pressed" from="UI/ButtonContainer/DemoButton" to="." method="_on_demo_button_pressed"]
```

---

## What the Demo Button Does

When clicked, it navigates to:
- **`res://test/DemoLauncher.tscn`**

From there, you can access:
1. **Play Demo Game** - Playable minigame with live algorithm display
2. **Run Automated Test** - Automated test showing difficulty progression
3. **Test G-Counter** - Interactive multiplayer scoring demonstration
4. **Reset Algorithm** - Clear all data and start fresh

---

## Already Implemented

✅ Function `_on_demo_button_pressed()` added to `InitialScreen.gd`
✅ Button reference `@onready var demo_button` added
✅ Complete demo system in `test/` folder ready to use

You just need to add the button to the scene file using one of the options above!
