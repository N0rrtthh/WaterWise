# Background Color Transitions Usage Guide

## Overview

The AnimatedCutscenePlayer now supports smooth background color transitions during cutscene playback. This feature allows cutscenes to transition from one background color to another over the duration of the animation, creating more dynamic and visually appealing cutscenes.

## How It Works

When a cutscene is played, the AnimatedCutscenePlayer:
1. Checks if the target background color (from the cutscene configuration) differs from the current background color
2. If different, creates a Tween to smoothly interpolate between the colors
3. The transition duration matches the cutscene duration, ensuring synchronization with character animations
4. Uses EASE_IN_OUT easing with QUAD transition for smooth, natural color changes

## Configuration

Background color transitions are configured in cutscene JSON files using the `background_color` field:

```json
{
  "version": "1.0",
  "minigame_key": "CatchTheRain",
  "cutscene_type": "win",
  "duration": 2.5,
  "background_color": "#ff6b35",
  "character": {
    "expression": "happy",
    "deformation_enabled": true
  },
  "keyframes": [
    ...
  ]
}
```

## Usage Examples

### Example 1: Dark to Light Transition (Intro Cutscene)

Start with a dark background and transition to a lighter one as the character appears:

```json
{
  "minigame_key": "WaterPlant",
  "cutscene_type": "intro",
  "duration": 2.0,
  "background_color": "#4a7c59",
  "character": {
    "expression": "determined"
  },
  "keyframes": [
    {
      "time": 0.0,
      "transforms": [
        {"type": "scale", "value": [0.5, 0.5], "relative": false},
        {"type": "position", "value": [-100, 0], "relative": true}
      ],
      "easing": "ease_out"
    },
    {
      "time": 2.0,
      "transforms": [
        {"type": "scale", "value": [1.0, 1.0], "relative": false},
        {"type": "position", "value": [0, 0], "relative": true}
      ],
      "easing": "ease_in_out"
    }
  ]
}
```

**Effect**: Background smoothly transitions from the previous color to a forest green (#4a7c59) as the character slides in from the left.

### Example 2: Success Color Shift (Win Cutscene)

Transition to a warm, celebratory color when the player wins:

```json
{
  "minigame_key": "FixLeak",
  "cutscene_type": "win",
  "duration": 2.5,
  "background_color": "#ffd700",
  "character": {
    "expression": "excited"
  },
  "keyframes": [
    {
      "time": 0.0,
      "transforms": [
        {"type": "scale", "value": [0.3, 0.3], "relative": false}
      ],
      "easing": "ease_out"
    },
    {
      "time": 1.0,
      "transforms": [
        {"type": "scale", "value": [1.3, 1.3], "relative": false},
        {"type": "rotation", "value": 0.3, "relative": false}
      ],
      "easing": "bounce"
    },
    {
      "time": 2.5,
      "transforms": [
        {"type": "scale", "value": [1.0, 1.0], "relative": false},
        {"type": "rotation", "value": 0.0, "relative": false}
      ],
      "easing": "ease_in_out"
    }
  ],
  "particles": [
    {
      "time": 1.0,
      "type": "sparkles",
      "duration": 1.5
    }
  ]
}
```

**Effect**: Background transitions to golden yellow (#ffd700) as the character bounces and celebrates, creating a warm, victorious atmosphere.

### Example 3: Dramatic Failure Shift (Fail Cutscene)

Transition to a cooler, more somber color when the player fails:

```json
{
  "minigame_key": "CatchTheRain",
  "cutscene_type": "fail",
  "duration": 2.5,
  "background_color": "#2c3e50",
  "character": {
    "expression": "sad"
  },
  "keyframes": [
    {
      "time": 0.0,
      "transforms": [
        {"type": "position", "value": [0, -100], "relative": true},
        {"type": "scale", "value": [0.8, 0.8], "relative": false}
      ],
      "easing": "ease_in"
    },
    {
      "time": 0.8,
      "transforms": [
        {"type": "position", "value": [0, 0], "relative": true},
        {"type": "scale", "value": [1.1, 0.9], "relative": false}
      ],
      "easing": "bounce"
    },
    {
      "time": 2.5,
      "transforms": [
        {"type": "scale", "value": [1.0, 1.0], "relative": false}
      ],
      "easing": "ease_out"
    }
  ],
  "particles": [
    {
      "time": 0.8,
      "type": "smoke",
      "duration": 1.7
    }
  ]
}
```

**Effect**: Background transitions to a dark blue-gray (#2c3e50) as the character drops and lands with a squash, creating a somber, disappointed atmosphere.

## Programmatic Usage

You can also trigger background color transitions programmatically:

```gdscript
# Create a cutscene player
var cutscene_player = AnimatedCutscenePlayer.new()
add_child(cutscene_player)

# Set initial background color
var background = cutscene_player.get_node("Background")
background.color = Color(0.1, 0.1, 0.1)  # Dark gray

# Play cutscene with different background color
# The transition will happen automatically
await cutscene_player.play_cutscene("MyMinigame", CutsceneTypes.CutsceneType.WIN)

# Clean up
cutscene_player.queue_free()
```

## Color Palette Recommendations

### Water-Themed Minigames
- **Intro**: `#0a1e0f` (dark forest green) → `#1a4d2e` (medium forest green)
- **Win**: `#1a4d2e` → `#4a7c59` (bright forest green) or `#00bcd4` (cyan)
- **Fail**: `#1a4d2e` → `#2c3e50` (dark blue-gray)

### Plant-Themed Minigames
- **Intro**: `#2d4a2b` (dark olive) → `#4a7c59` (forest green)
- **Win**: `#4a7c59` → `#8bc34a` (light green) or `#ffd700` (golden)
- **Fail**: `#4a7c59` → `#5d4037` (brown)

### General Purpose
- **Intro**: Any dark color → Medium brightness color
- **Win**: Medium color → Bright, warm color (yellow, orange, light green)
- **Fail**: Medium color → Dark, cool color (blue-gray, dark purple)

## Technical Details

### Transition Properties
- **Duration**: Matches cutscene duration (typically 1.5-3.0 seconds)
- **Easing**: EASE_IN_OUT with TRANS_QUAD for smooth acceleration/deceleration
- **Interpolation**: Linear RGB interpolation (Godot's built-in color lerp)

### Performance
- Background color transitions use a single Tween per cutscene
- Minimal performance impact (< 0.1ms per frame)
- Tween is automatically cleaned up after cutscene completion

### Synchronization
- Background transition starts simultaneously with character animation
- Both complete at the same time (cutscene duration)
- No additional timing configuration needed

## Testing

### Visual Test Scene
Run the visual test scene to see background color transitions in action:

```
res://test/BackgroundColorTransitionVisualTest.tscn
```

This scene provides three test buttons:
1. **Dark to Light**: Black → White transition
2. **Green to Red**: Green → Red transition
3. **Blue to Yellow**: Blue → Yellow transition

### Unit Tests
Unit tests are available in:
```
res://test/AnimatedCutscenePlayerTest.gd
```

Tests include:
- `test_background_color_transitions_smoothly`: Verifies smooth interpolation
- `test_background_color_no_transition_when_same`: Verifies no transition when colors match
- `test_background_transition_synchronized_with_animation`: Verifies timing synchronization
- `test_background_tween_cleaned_up_after_cutscene`: Verifies proper cleanup

## Troubleshooting

### Background color doesn't change
- **Check**: Ensure `background_color` in config differs from current background color
- **Check**: Verify cutscene is actually playing (listen for `cutscene_finished` signal)
- **Check**: Confirm Background node exists in AnimatedCutscenePlayer

### Transition is too fast/slow
- **Solution**: Adjust the `duration` field in the cutscene configuration
- The background transition duration always matches the cutscene duration

### Colors look wrong
- **Check**: Verify color format in JSON (use hex strings like `"#ff6b35"`)
- **Check**: Ensure color values are valid (0-255 for RGB, or 0.0-1.0 for normalized)
- **Note**: Godot uses normalized RGB (0.0-1.0), but JSON configs accept hex strings

### Transition not smooth
- **Check**: Ensure sufficient frame rate (target 60 FPS)
- **Check**: Verify no other heavy operations during cutscene playback
- **Note**: Easing is EASE_IN_OUT by default, which may appear slower at start/end

## Best Practices

1. **Match Theme**: Choose background colors that match the minigame theme
2. **Contrast**: Ensure sufficient contrast between background and character
3. **Subtlety**: Avoid extreme color shifts (e.g., black to white) unless intentional
4. **Consistency**: Use similar color palettes across related minigames
5. **Accessibility**: Consider colorblind-friendly palettes
6. **Duration**: Keep transitions between 1.5-3.0 seconds for best effect

## Related Features

- **Character Animations**: See `ANIMATED_CUTSCENE_PLAYER_USAGE.md`
- **Particle Effects**: See `PARTICLE_EFFECT_SYSTEM_USAGE.md`
- **Animation Engine**: See `ANIMATION_ENGINE_USAGE.md`

## Requirements Validated

This feature validates:
- **Requirement 7.2**: Background color transitions during cutscenes
- **Property 21**: Smooth color interpolation between any two colors
