# Screen Shake Effect Usage Guide

## Overview

The screen shake effect adds dramatic impact to animated cutscenes by oscillating the camera at specific keyframe times. This feature is part of the animated cutscene system and integrates seamlessly with other visual effects like particles and background color transitions.

## Features

- **Configurable Intensity**: Control the strength of the shake effect (0.0 to 2.0+)
- **Configurable Duration**: Set how long the shake lasts (0.1s to 1.0s+)
- **Precise Timing**: Trigger shakes at specific keyframe times
- **Accessibility Support**: Respects user accessibility settings for screen shake
- **Multiple Shakes**: Support for multiple shake effects in a single cutscene

## Data Model

### ScreenShake Class

```gdscript
class ScreenShake:
    var time: float = 0.0        # When to trigger (seconds from cutscene start)
    var intensity: float = 0.5   # Shake strength (0.0 = none, 1.0 = strong)
    var duration: float = 0.3    # How long to shake (seconds)
```

## Usage in Cutscene Configurations

### JSON Configuration

Add screen shakes to your cutscene JSON configuration:

```json
{
  "version": "1.0",
  "minigame_key": "CatchTheRain",
  "cutscene_type": "win",
  "duration": 2.5,
  "character": {
    "expression": "happy",
    "deformation_enabled": true
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
      "time": 0.5,
      "transforms": [
        {"type": "scale", "value": [1.2, 1.2], "relative": false}
      ],
      "easing": "bounce"
    }
  ],
  "screen_shakes": [
    {
      "time": 0.5,
      "intensity": 0.8,
      "duration": 0.3
    },
    {
      "time": 1.5,
      "intensity": 0.5,
      "duration": 0.2
    }
  ]
}
```

### GDScript Configuration

Create screen shakes programmatically:

```gdscript
# Create a cutscene configuration
var config = CutsceneDataModels.CutsceneConfig.new()
config.minigame_key = "FixLeak"
config.cutscene_type = CutsceneTypes.CutsceneType.FAIL
config.duration = 2.0

# Add keyframes for animation
var keyframe = CutsceneDataModels.Keyframe.new(0.0)
var transform = CutsceneDataModels.Transform.new(
    CutsceneTypes.TransformType.POSITION,
    Vector2(0, -50),
    true
)
keyframe.add_transform(transform)
config.add_keyframe(keyframe)

# Add screen shake at impact moment (0.5 seconds)
var shake = CutsceneDataModels.ScreenShake.new(0.5, 0.9, 0.4)
config.add_screen_shake(shake)

# Add another shake for wobble effect (1.0 seconds)
var shake2 = CutsceneDataModels.ScreenShake.new(1.0, 0.6, 0.3)
config.add_screen_shake(shake2)
```

## Intensity Guidelines

Choose intensity values based on the dramatic effect you want:

| Intensity | Effect | Use Case |
|-----------|--------|----------|
| 0.1 - 0.3 | Subtle vibration | Gentle landing, small impact |
| 0.4 - 0.6 | Moderate shake | Character bounce, medium impact |
| 0.7 - 0.9 | Strong shake | Heavy landing, dramatic moment |
| 1.0+ | Intense shake | Explosion, major impact, failure |

## Duration Guidelines

Choose duration values based on the moment:

| Duration | Effect | Use Case |
|----------|--------|----------|
| 0.1 - 0.2s | Quick jolt | Instant impact, snap |
| 0.3 - 0.4s | Standard shake | Normal impact, bounce |
| 0.5 - 0.7s | Extended shake | Wobble, sustained impact |
| 0.8s+ | Long shake | Earthquake, major event |

## Common Patterns

### Win Cutscene - Celebration Shake

```gdscript
# Moderate shake when character lands after celebration jump
var shake = CutsceneDataModels.ScreenShake.new(0.5, 0.6, 0.3)
config.add_screen_shake(shake)
```

### Fail Cutscene - Impact Shake

```gdscript
# Strong shake when character hits the ground
var impact_shake = CutsceneDataModels.ScreenShake.new(0.5, 0.9, 0.4)
config.add_screen_shake(impact_shake)

# Lighter shake for bounce
var bounce_shake = CutsceneDataModels.ScreenShake.new(1.0, 0.5, 0.2)
config.add_screen_shake(bounce_shake)
```

### Multiple Shakes - Wobble Effect

```gdscript
# Create a wobble effect with decreasing intensity
config.add_screen_shake(CutsceneDataModels.ScreenShake.new(0.5, 0.8, 0.2))
config.add_screen_shake(CutsceneDataModels.ScreenShake.new(0.8, 0.6, 0.2))
config.add_screen_shake(CutsceneDataModels.ScreenShake.new(1.1, 0.4, 0.2))
```

## Accessibility

The screen shake effect automatically respects user accessibility settings:

```gdscript
# In SaveManager or accessibility settings
func is_screen_shake_enabled() -> bool:
    return settings.screen_shake  # User preference
```

If the user has disabled screen shake in accessibility settings, the effect will be skipped automatically. No additional code is required in your cutscene configurations.

## Integration with Other Effects

Screen shake works seamlessly with other cutscene effects:

```json
{
  "keyframes": [...],
  "particles": [
    {
      "time": 0.5,
      "type": "splash",
      "duration": 1.0
    }
  ],
  "audio_cues": [
    {
      "time": 0.5,
      "sound": "impact_sound"
    }
  ],
  "screen_shakes": [
    {
      "time": 0.5,
      "intensity": 0.8,
      "duration": 0.3
    }
  ]
}
```

All effects at the same time (0.5s in this example) will trigger simultaneously for maximum impact.

## Technical Details

### Camera Offset Method

The screen shake effect uses camera offset rather than position to avoid interfering with other camera movements:

```gdscript
# Shake oscillates the camera offset
camera.offset = original_offset + random_offset
```

### Shake Algorithm

The shake effect creates a series of random offsets over the duration:

1. Store original camera offset
2. For each shake iteration (every 0.05s):
   - Apply random offset based on intensity
   - Tween to that offset
3. Return to original offset smoothly

### Performance

Screen shake is lightweight and has minimal performance impact:
- Uses Godot's built-in Tween system
- No additional nodes created
- Automatically cleaned up after completion

## Troubleshooting

### Shake Not Visible

**Problem**: Screen shake doesn't appear to work

**Solutions**:
1. Check if user has disabled screen shake in accessibility settings
2. Verify a Camera2D exists in the viewport
3. Ensure intensity is high enough to be visible (try 0.8+)
4. Check that the shake time is within the cutscene duration

### Shake Too Subtle

**Problem**: Shake effect is barely noticeable

**Solutions**:
1. Increase intensity (try 0.8 or higher)
2. Increase duration (try 0.4s or longer)
3. Combine with audio and particle effects for more impact

### Shake Too Intense

**Problem**: Shake is too jarring or uncomfortable

**Solutions**:
1. Reduce intensity (try 0.5 or lower)
2. Reduce duration (try 0.2s or shorter)
3. Consider user accessibility preferences

## Examples

### Example 1: Simple Impact Shake

```gdscript
var config = CutsceneDataModels.CutsceneConfig.new()
config.duration = 2.0

# Character drops and lands at 0.5s
var shake = CutsceneDataModels.ScreenShake.new(0.5, 0.7, 0.3)
config.add_screen_shake(shake)
```

### Example 2: Multiple Shakes for Wobble

```gdscript
var config = CutsceneDataModels.CutsceneConfig.new()
config.duration = 2.5

# Impact at 0.5s
config.add_screen_shake(CutsceneDataModels.ScreenShake.new(0.5, 0.9, 0.3))

# First bounce at 0.9s
config.add_screen_shake(CutsceneDataModels.ScreenShake.new(0.9, 0.6, 0.2))

# Second bounce at 1.2s
config.add_screen_shake(CutsceneDataModels.ScreenShake.new(1.2, 0.4, 0.2))
```

### Example 3: Synchronized with Particles and Audio

```gdscript
var config = CutsceneDataModels.CutsceneConfig.new()
config.duration = 2.0

# All effects trigger at 0.5s for maximum impact
var impact_time = 0.5

# Screen shake
config.add_screen_shake(CutsceneDataModels.ScreenShake.new(impact_time, 0.8, 0.3))

# Particle effect
var particle = CutsceneDataModels.ParticleEffect.new(impact_time, CutsceneTypes.ParticleType.SPLASH)
particle.duration = 1.0
config.add_particle(particle)

# Audio cue
var audio = CutsceneDataModels.AudioCue.new(impact_time, "water_splash")
config.add_audio_cue(audio)
```

## Best Practices

1. **Use Sparingly**: Too many shakes can be disorienting. 1-3 shakes per cutscene is usually enough.

2. **Match the Moment**: Shake intensity should match the visual action (bigger impact = stronger shake).

3. **Combine Effects**: Screen shake is most effective when combined with particles, audio, and animation.

4. **Test Accessibility**: Always test with screen shake disabled to ensure the cutscene is still clear.

5. **Timing is Key**: Shake should trigger exactly when the visual impact occurs (character landing, object hitting, etc.).

6. **Decreasing Intensity**: For wobble effects, use decreasing intensity to feel natural.

## Related Documentation

- [Animated Cutscene Player Usage](ANIMATED_CUTSCENE_PLAYER_USAGE.md)
- [Particle Effect System Usage](PARTICLE_EFFECT_SYSTEM_USAGE.md)
- [Background Color Transitions Usage](BACKGROUND_COLOR_TRANSITIONS_USAGE.md)
- [Animation Engine Usage](ANIMATION_ENGINE_USAGE.md)
