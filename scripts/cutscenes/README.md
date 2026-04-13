# Animated Cutscene System

This directory contains the core components for the animated character cutscene system.

## Structure

```
scripts/cutscenes/
├── CutsceneTypes.gd          # Core enums and constants
├── CutsceneDataModels.gd     # Data model classes
├── CutsceneParser.gd         # Configuration parser (Task 4)
├── AnimationEngine.gd        # Animation engine (Task 3)
├── WaterDropletCharacter.gd  # Character component (Task 2)
└── AnimatedCutscenePlayer.gd # Main orchestrator (Task 6)
```

## Data Models

### CutsceneConfig
Main configuration object containing:
- `version`: Configuration format version
- `minigame_key`: Unique identifier for the minigame
- `cutscene_type`: INTRO, WIN, or FAIL
- `duration`: Total cutscene duration in seconds
- `character`: Character configuration (expression, deformation)
- `background_color`: Background color during cutscene
- `keyframes`: Array of animation keyframes
- `particles`: Array of particle effects
- `audio_cues`: Array of audio triggers

### Keyframe
Animation keyframe containing:
- `time`: Time offset in seconds
- `transforms`: Array of transformations to apply
- `easing`: Easing function for interpolation

### Transform
Single transformation containing:
- `type`: POSITION, ROTATION, or SCALE
- `value`: Target value (Vector2 or float)
- `relative`: Whether transform is relative to current state

### ValidationResult
Validation result containing:
- `is_valid`: Whether validation passed
- `errors`: Array of error messages

## Asset Directories

```
data/cutscenes/
├── default/              # Default cutscene configurations
│   ├── intro.json
│   ├── win.json
│   └── fail.json
└── {minigame_key}/       # Minigame-specific configurations
    ├── intro.json
    ├── win_variant_1.json
    ├── win_variant_2.json
    └── fail_variant_1.json

assets/characters/        # Character sprites and animations
assets/particles/         # Particle effect textures
```

## Usage Example

```gdscript
# Create a cutscene configuration
var config = CutsceneDataModels.CutsceneConfig.new()
config.minigame_key = "CatchTheRain"
config.cutscene_type = CutsceneTypes.CutsceneType.WIN
config.duration = 2.5

# Add a keyframe
var keyframe = CutsceneDataModels.Keyframe.new(0.5)
keyframe.easing = CutsceneTypes.Easing.BOUNCE

# Add a transform
var transform = CutsceneDataModels.Transform.new()
transform.type = CutsceneTypes.TransformType.SCALE
transform.value = Vector2(1.2, 1.2)
transform.relative = false

keyframe.add_transform(transform)
config.add_keyframe(keyframe)

# Convert to dictionary for JSON serialization
var dict = config.to_dict()
```

## Next Steps

- Task 2: Implement WaterDropletCharacter component
- Task 3: Implement AnimationEngine component
- Task 4: Implement CutsceneParser component
- Task 6: Implement AnimatedCutscenePlayer orchestrator
