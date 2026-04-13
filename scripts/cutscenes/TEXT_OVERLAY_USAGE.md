# Text Overlay Animation System - Usage Guide

## Overview

The text overlay animation system provides animated text overlays for cutscenes with various animation effects. Text overlays can display messages during cutscenes with fade, slide, or bounce animations, positioned at the top, center, or bottom of the screen.

## Components

### 1. TextOverlay Data Model

The `TextOverlay` class in `CutsceneDataModels.gd` defines the configuration for a text overlay:

```gdscript
var overlay = CutsceneDataModels.TextOverlay.new("Hello World!", 0.5)
overlay.animation_type = CutsceneTypes.TextAnimationType.FADE_IN
overlay.duration = 2.0
overlay.position = CutsceneTypes.TextPosition.CENTER
overlay.font_size = 48
overlay.color = Color.YELLOW
```

**Properties:**
- `text`: The text to display
- `time`: When to show the overlay (in seconds from cutscene start)
- `animation_type`: Animation effect (FADE_IN, SLIDE_IN, BOUNCE_IN)
- `duration`: How long the animation lasts (in seconds)
- `position`: Where to position the text (TOP, CENTER, BOTTOM)
- `font_size`: Font size in pixels (default: 32)
- `color`: Text color (default: WHITE)

### 2. AnimatedTextOverlay Component

The `AnimatedTextOverlay` class is a Label-based component that renders and animates text overlays.

**Animation Types:**

#### Fade In
Text fades in from transparent to opaque, holds, then fades out.

```gdscript
overlay.animation_type = CutsceneTypes.TextAnimationType.FADE_IN
```

#### Slide In
Text slides in from the left, holds, then slides out to the right.

```gdscript
overlay.animation_type = CutsceneTypes.TextAnimationType.SLIDE_IN
```

#### Bounce In
Text bounces in with a scale effect, holds, then fades out.

```gdscript
overlay.animation_type = CutsceneTypes.TextAnimationType.BOUNCE_IN
```

### 3. Integration with CutsceneConfig

Text overlays are added to cutscene configurations:

```gdscript
var config = CutsceneDataModels.CutsceneConfig.new()

var overlay = CutsceneDataModels.TextOverlay.new("Victory!", 0.5)
overlay.animation_type = CutsceneTypes.TextAnimationType.BOUNCE_IN
overlay.position = CutsceneTypes.TextPosition.CENTER
overlay.font_size = 64
overlay.color = Color.GOLD

config.add_text_overlay(overlay)
```

## JSON Configuration Format

Text overlays can be defined in cutscene JSON files:

```json
{
  "version": "1.0",
  "minigame_key": "CatchTheRain",
  "cutscene_type": "win",
  "duration": 2.5,
  "text_overlays": [
    {
      "text": "Great Job!",
      "time": 0.5,
      "animation_type": "bounce_in",
      "duration": 1.5,
      "position": "center",
      "font_size": 64,
      "color": "#ffff00"
    },
    {
      "text": "Water Saved!",
      "time": 1.5,
      "animation_type": "fade_in",
      "duration": 1.0,
      "position": "bottom",
      "font_size": 32,
      "color": "#00ffff"
    }
  ]
}
```

## Usage Examples

### Example 1: Simple Win Message

```gdscript
var overlay = CutsceneDataModels.TextOverlay.new("You Win!", 0.5)
overlay.animation_type = CutsceneTypes.TextAnimationType.BOUNCE_IN
overlay.font_size = 64
overlay.color = Color.GOLD
config.add_text_overlay(overlay)
```

### Example 2: Tutorial Hint

```gdscript
var hint = CutsceneDataModels.TextOverlay.new("Tap to collect water drops", 0.0)
hint.animation_type = CutsceneTypes.TextAnimationType.FADE_IN
hint.position = CutsceneTypes.TextPosition.TOP
hint.font_size = 24
hint.color = Color.WHITE
config.add_text_overlay(hint)
```

### Example 3: Multiple Overlays

```gdscript
# First message
var msg1 = CutsceneDataModels.TextOverlay.new("Level Complete!", 0.5)
msg1.animation_type = CutsceneTypes.TextAnimationType.BOUNCE_IN
msg1.position = CutsceneTypes.TextPosition.CENTER
msg1.font_size = 56
config.add_text_overlay(msg1)

# Second message
var msg2 = CutsceneDataModels.TextOverlay.new("100 Liters Saved", 1.5)
msg2.animation_type = CutsceneTypes.TextAnimationType.SLIDE_IN
msg2.position = CutsceneTypes.TextPosition.BOTTOM
msg2.font_size = 32
msg2.color = Color.CYAN
config.add_text_overlay(msg2)
```

### Example 4: Dramatic Emphasis

```gdscript
var emphasis = CutsceneDataModels.TextOverlay.new("PERFECT!", 0.8)
emphasis.animation_type = CutsceneTypes.TextAnimationType.BOUNCE_IN
emphasis.position = CutsceneTypes.TextPosition.CENTER
emphasis.font_size = 72
emphasis.color = Color(1.0, 0.8, 0.0)  # Gold
emphasis.duration = 2.0
config.add_text_overlay(emphasis)
```

## Positioning

Text overlays support three vertical positions:

- **TOP**: 10% from the top of the screen
- **CENTER**: Centered vertically
- **BOTTOM**: 80% from the top of the screen (20% from bottom)

```gdscript
overlay.position = CutsceneTypes.TextPosition.TOP
overlay.position = CutsceneTypes.TextPosition.CENTER
overlay.position = CutsceneTypes.TextPosition.BOTTOM
```

## Styling

### Font Size

```gdscript
overlay.font_size = 32  # Small
overlay.font_size = 48  # Medium
overlay.font_size = 64  # Large
overlay.font_size = 96  # Extra large
```

### Color

```gdscript
overlay.color = Color.WHITE
overlay.color = Color.YELLOW
overlay.color = Color.CYAN
overlay.color = Color(1.0, 0.5, 0.0)  # Orange
overlay.color = Color("#ff00ff")  # Magenta
```

## Animation Timing

The `duration` parameter controls the total animation time:

- **50%** of duration: Main animation (fade/slide/bounce in)
- **30%** of duration: Hold time
- **20%** of duration: Exit animation (fade/slide out)

```gdscript
overlay.duration = 1.0  # Quick (1 second total)
overlay.duration = 2.0  # Normal (2 seconds total)
overlay.duration = 3.0  # Slow (3 seconds total)
```

## Best Practices

### 1. Keep Text Short
Text overlays work best with short, punchy messages:
- ✅ "Great Job!"
- ✅ "Level Complete!"
- ❌ "Congratulations on completing this level and saving water!"

### 2. Use Appropriate Animation Types
- **Bounce In**: Celebratory messages, victories
- **Fade In**: Subtle hints, information
- **Slide In**: Sequential messages, announcements

### 3. Position for Context
- **Top**: Tutorial hints, instructions
- **Center**: Main messages, victories
- **Bottom**: Secondary information, scores

### 4. Timing Coordination
Space out multiple overlays to avoid overlap:

```gdscript
var msg1 = CutsceneDataModels.TextOverlay.new("First", 0.5)
msg1.duration = 1.0

var msg2 = CutsceneDataModels.TextOverlay.new("Second", 1.8)  # After first finishes
msg2.duration = 1.0
```

### 5. Color Contrast
Use colors that contrast with the background:
- Dark background → Light text (WHITE, YELLOW, CYAN)
- Light background → Dark text (BLACK, DARK_BLUE)

### 6. Font Size Guidelines
- **24-32px**: Small text, hints, secondary info
- **48-56px**: Normal messages
- **64-96px**: Emphasis, victories, important messages

## Visual Test

Run the visual test to see all animation types in action:

1. Open `test/TextOverlayVisualTest.tscn` in Godot
2. Press F5 to run
3. Press SPACE to cycle through animation types
4. Press P to cycle through positions
5. Press R to restart current animation
6. Press ESC to quit

## Integration with AnimatedCutscenePlayer

Text overlays are automatically scheduled and played by `AnimatedCutscenePlayer`:

```gdscript
# In your cutscene configuration
var config = CutsceneDataModels.CutsceneConfig.new()
config.add_text_overlay(overlay)

# AnimatedCutscenePlayer handles the rest
var player = AnimatedCutscenePlayer.new()
await player.play_cutscene("CatchTheRain", CutsceneTypes.CutsceneType.WIN)
```

The player will:
1. Wait for the specified `time`
2. Create an `AnimatedTextOverlay` node
3. Play the animation
4. Clean up when finished

## Accessibility

Text overlays include automatic features for readability:
- **Text outline**: 2px black outline for contrast
- **Centered alignment**: Easy to read
- **Full width**: Text wraps naturally
- **Smooth animations**: No jarring movements

## Performance

Text overlays are lightweight:
- Uses native Label nodes
- Tween-based animations (GPU accelerated)
- Automatic cleanup after animation
- No texture loading required

## Troubleshooting

### Text Not Appearing
- Check that `time` is within the cutscene `duration`
- Verify the text color contrasts with the background
- Ensure the overlay is added to the config: `config.add_text_overlay(overlay)`

### Text Cut Off
- Reduce `font_size` for long text
- Keep messages short and concise
- Text automatically wraps to fit width

### Animation Too Fast/Slow
- Adjust `duration` parameter
- Typical range: 1.0 to 3.0 seconds
- Shorter for quick messages, longer for emphasis

### Wrong Position
- Verify `position` enum value
- Check parent container size
- Ensure container is visible and sized correctly

## Requirements Validated

This implementation validates **Requirement 7.6**:
> THE Cutscene_System SHALL support text overlays with animated typography

Features implemented:
- ✅ Text overlay data model with serialization
- ✅ Three animation types (fade, slide, bounce)
- ✅ Three position options (top, center, bottom)
- ✅ Customizable styling (font size, color)
- ✅ Integration with AnimatedCutscenePlayer
- ✅ Automatic scheduling and cleanup
- ✅ JSON configuration support
