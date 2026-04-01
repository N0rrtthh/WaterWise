# Animated Cutscene System

## Overview

The Animated Cutscene System provides "Dumb Ways to Die" style animated character cutscenes for the water conservation educational game. The system replaces basic emoji cutscenes with expressive, animated water droplet characters that appear during intro, win, and fail scenarios.

## Architecture

The system consists of four main components:

### 1. Core Components (Tasks 1-4)

#### WaterDropletCharacter
- **Location**: `scripts/cutscenes/WaterDropletCharacter.gd`, `scenes/cutscenes/WaterDropletCharacter.tscn`
- **Purpose**: Animated character with expressions and deformation
- **Features**: 6 expressions, squash/stretch, particle spawning
- **Status**: ✅ Complete (Task 2.1)

#### AnimationEngine
- **Location**: `scripts/cutscenes/AnimationEngine.gd`
- **Purpose**: Apply transformations with easing functions
- **Features**: Position/rotation/scale transforms, 7 easing functions, keyframe animation
- **Status**: ✅ Complete (Task 3.1)

#### CutsceneParser
- **Location**: `scripts/cutscenes/CutsceneParser.gd`
- **Purpose**: Parse and validate cutscene configurations
- **Features**: JSON/GDScript parsing, validation, pretty printing
- **Status**: ✅ Complete (Task 4.1)

#### CutsceneDataModels
- **Location**: `scripts/cutscenes/CutsceneDataModels.gd`
- **Purpose**: Data structures for cutscene configuration
- **Features**: CutsceneConfig, Keyframe, Transform, ParticleEffect, AudioCue
- **Status**: ✅ Complete (Task 1)

#### CutsceneTypes
- **Location**: `scripts/cutscenes/CutsceneTypes.gd`
- **Purpose**: Enums and constants for the cutscene system
- **Features**: CutsceneType, Expression, ParticleType, Easing, TransformType
- **Status**: ✅ Complete (Task 1)

### 2. Orchestrator (Task 6)

#### AnimatedCutscenePlayer
- **Location**: `scripts/cutscenes/AnimatedCutscenePlayer.gd`, `scenes/cutscenes/AnimatedCutscenePlayer.tscn`
- **Purpose**: Main orchestrator for cutscene playback
- **Features**: Configuration loading, character lifecycle, animation coordination
- **Status**: ✅ Complete (Task 6.1)

## Quick Start

### Playing a Cutscene

```gdscript
# Create cutscene player
var cutscene_player = AnimatedCutscenePlayer.new()
add_child(cutscene_player)

# Play a win cutscene
await cutscene_player.play_cutscene("CatchTheRain", CutsceneTypes.CutsceneType.WIN)

# Clean up
cutscene_player.queue_free()
```

### Using the Scene

```gdscript
# Load the scene
var cutscene_scene = load("res://scenes/cutscenes/AnimatedCutscenePlayer.tscn")
var cutscene_player = cutscene_scene.instantiate()
add_child(cutscene_player)

# Play cutscene
await cutscene_player.play_cutscene("FixLeak", CutsceneTypes.CutsceneType.FAIL)

cutscene_player.queue_free()
```

## Configuration System

### Configuration File Structure

Cutscene configurations are stored as JSON files:

```
res://data/cutscenes/
├── default/
│   ├── intro.json
│   ├── win.json
│   └── fail.json
├── CatchTheRain/
│   ├── intro.json
│   ├── win.json
│   └── fail.json
└── FixLeak/
    ├── intro.json
    ├── win.json
    └── fail.json
```

### Example Configuration

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
  "background_color": "#0a1e0f",
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
        {"type": "scale", "value": [1.0, 1.0], "relative": false}
      ],
      "easing": "ease_in_out"
    }
  ],
  "particles": [
    {
      "time": 0.5,
      "type": "sparkles",
      "duration": 1.0,
      "density": "medium"
    }
  ],
  "audio_cues": [
    {
      "time": 0.0,
      "sound": "success_chime"
    }
  ]
}
```

### Fallback Hierarchy

1. Custom minigame-specific: `res://data/cutscenes/{minigame_key}/{type}.json`
2. Default configuration: `res://data/cutscenes/default/{type}.json`
3. Minimal hardcoded: Created programmatically if no files exist

## Component Documentation

Each component has detailed usage documentation:

- **WaterDropletCharacter**: `WATER_DROPLET_CHARACTER_USAGE.md`
- **AnimationEngine**: `ANIMATION_ENGINE_USAGE.md`
- **CutsceneParser**: `CUTSCENE_PARSER_USAGE.md`
- **AnimatedCutscenePlayer**: `ANIMATED_CUTSCENE_PLAYER_USAGE.md`

## Testing

### Unit Tests

- `test/WaterDropletCharacterTest.gd` - Character functionality
- `test/AnimationEngineTest.gd` - Animation engine
- `test/CutsceneParserTest.gd` - Configuration parsing
- `test/AnimatedCutscenePlayerTest.gd` - Cutscene player

### Visual Tests

- `scenes/cutscenes/WaterDropletCharacterDemo.tscn` - Character demo
- `test/AnimationEngineVisualTest.tscn` - Animation engine demo
- `scenes/cutscenes/AnimatedCutscenePlayerDemo.tscn` - Cutscene player demo

## Integration with MiniGameBase

```gdscript
# In MiniGameBase.gd
func _show_success_micro_cutscene() -> void:
    var cutscene_player = AnimatedCutscenePlayer.new()
    hud_layer.add_child(cutscene_player)
    
    await cutscene_player.play_cutscene(
        _get_minigame_key(),
        CutsceneTypes.CutsceneType.WIN
    )
    
    cutscene_player.queue_free()

func _show_failure_micro_cutscene() -> void:
    var cutscene_player = AnimatedCutscenePlayer.new()
    hud_layer.add_child(cutscene_player)
    
    await cutscene_player.play_cutscene(
        _get_minigame_key(),
        CutsceneTypes.CutsceneType.FAIL
    )
    
    cutscene_player.queue_free()
```

## Available Enums

### CutsceneType
- `INTRO` - Shown before minigame starts
- `WIN` - Shown on successful completion
- `FAIL` - Shown on failure

### Expression
- `HAPPY` - Joyful expression
- `SAD` - Disappointed expression
- `SURPRISED` - Shocked expression
- `DETERMINED` - Focused expression
- `WORRIED` - Anxious expression
- `EXCITED` - Enthusiastic expression

### ParticleType
- `SPARKLES` - Celebratory sparkles
- `WATER_DROPS` - Water droplets
- `STARS` - Star particles
- `SMOKE` - Smoke effect
- `SPLASH` - Water splash

### Easing
- `LINEAR` - Constant speed
- `EASE_IN` - Slow start, fast end
- `EASE_OUT` - Fast start, slow end
- `EASE_IN_OUT` - Slow start and end
- `BOUNCE` - Bouncy effect
- `ELASTIC` - Elastic spring effect
- `BACK` - Overshoot and return

### TransformType
- `POSITION` - Move character (Vector2)
- `ROTATION` - Rotate character (float, radians)
- `SCALE` - Scale character (Vector2)

## Performance Considerations

- **Preloading**: Use `preload_cutscene()` during game initialization
- **Resource cleanup**: Automatic cleanup after cutscene completion
- **Validation**: Configuration validated before playback
- **Caching**: ResourceLoader caches loaded configurations
- **Minimal allocations**: Reuses nodes where possible

## Error Handling

The system implements robust error handling:

- **Missing configuration**: Falls back to default or minimal config
- **Invalid configuration**: Logs error and uses minimal config
- **Animation failure**: Logs error and completes immediately
- **Missing AudioManager**: Skips audio cues with warning
- **Concurrent playback**: Ignores second request with warning

**Game progression is never blocked by cutscene errors.**

## Implementation Status

### Completed (Tasks 1-6.1)
- ✅ Core data models and enums
- ✅ WaterDropletCharacter component
- ✅ AnimationEngine component
- ✅ CutsceneParser component
- ✅ AnimatedCutscenePlayer orchestrator
- ✅ Unit tests for all components
- ✅ Usage documentation
- ✅ Demo scenes

### Pending (Tasks 6.2-21)
- ⏳ Property-based tests
- ⏳ Visual effects (particles, background transitions, screen shake)
- ⏳ Audio integration
- ⏳ Performance optimizations
- ⏳ Error handling enhancements
- ⏳ Default animation profiles
- ⏳ Animation variant system
- ⏳ Adaptive timing and skip functionality
- ⏳ MiniGameBase integration
- ⏳ Minigame-specific configurations
- ⏳ Character and particle assets

## Next Steps

1. **Create default animation profiles** (Task 12)
   - Default win, fail, and intro configurations
   - Place in `res://data/cutscenes/default/`

2. **Integrate with MiniGameBase** (Task 16)
   - Update `_show_success_micro_cutscene()`
   - Update `_show_failure_micro_cutscene()`
   - Add fallback to legacy emoji system

3. **Create minigame-specific configurations** (Task 17)
   - CatchTheRain cutscenes
   - FixLeak cutscenes
   - WaterPlant cutscenes
   - etc.

4. **Add visual effects** (Task 7)
   - Particle effect system
   - Background color transitions
   - Screen shake effect
   - Text overlay animation

## Troubleshooting

### Cutscene doesn't play
- Check that configuration file exists or fallback is working
- Verify character scene path is correct
- Check console for error messages

### Character not visible
- Ensure AnimatedCutscenePlayer is added to scene tree
- Check that character is centered correctly
- Verify background color isn't hiding character

### Audio not playing
- Verify AudioManager autoload exists
- Check that audio cue sound names are correct
- Ensure AudioManager has `play_sound()` method

### Animation timing issues
- Validate configuration with CutsceneParser
- Check keyframe times are in chronological order
- Verify duration matches keyframe times

## Contributing

When adding new features:

1. Follow the existing code style
2. Add unit tests for new functionality
3. Update relevant documentation
4. Test with multiple minigames
5. Ensure error handling is robust

## License

Part of the Waterwise educational game project.
