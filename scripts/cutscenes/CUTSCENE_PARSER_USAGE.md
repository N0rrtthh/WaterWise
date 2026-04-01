# CutsceneParser Usage Guide

## Overview

The `CutsceneParser` is a static utility class that reads, validates, and pretty-prints cutscene configuration files. It supports both JSON and GDScript resource formats, providing comprehensive validation with descriptive error messages.

## Features

- ✅ Parse JSON configuration files
- ✅ Parse GDScript resource files (.tres, .res)
- ✅ Parse configuration dictionaries
- ✅ Comprehensive validation with detailed error messages
- ✅ Pretty-print configurations for debugging
- ✅ Round-trip serialization support

## Basic Usage

### Parsing from File

```gdscript
# Parse a JSON configuration file
var config = CutsceneParser.parse_config("res://data/cutscenes/CatchTheRain/win.json")

if config:
    print("Loaded cutscene: " + config.minigame_key)
    print("Duration: " + str(config.duration) + "s")
else:
    print("Failed to load cutscene configuration")
```

### Parsing from Dictionary

```gdscript
var config_dict = {
    "version": "1.0",
    "minigame_key": "TestGame",
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
                {
                    "type": "scale",
                    "value": [0.5, 0.5],
                    "relative": false
                }
            ],
            "easing": "ease_out"
        }
    ],
    "particles": [],
    "audio_cues": []
}

var config = CutsceneParser.parse_dict(config_dict)
```

### Validating Configuration

```gdscript
var config = CutsceneParser.parse_config("res://data/cutscenes/MyGame/win.json")

if config:
    var validation = CutsceneParser.validate_config(config)
    
    if validation.is_valid:
        print("✓ Configuration is valid!")
    else:
        print("✗ Configuration has errors:")
        for error in validation.errors:
            print("  - " + error)
```

### Pretty Printing

```gdscript
var config = CutsceneParser.parse_config("res://data/cutscenes/CatchTheRain/win.json")

if config:
    var output = CutsceneParser.pretty_print(config)
    print(output)
```

**Example Output:**
```
=== Cutscene Configuration ===
Version: 1.0
Minigame: CatchTheRain
Type: WIN
Duration: 2.5s

Character:
  Expression: HAPPY
  Deformation Enabled: true

Background Color: #0a1e0f

Keyframes (2):
  [0] Time: 0.0s, Easing: EASE_OUT
    - SCALE: (0.5, 0.5) (absolute)
  [1] Time: 1.0s, Easing: BOUNCE
    - SCALE: (1.0, 1.0) (absolute)

Particles (1):
  - Time: 0.5s, Type: SPARKLES, Duration: 1.5s, Density: medium

Audio Cues (1):
  - Time: 0.0s, Sound: success_chime

==============================
```

## Supported File Formats

### JSON Format

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
        {
          "type": "scale",
          "value": [0.5, 0.5],
          "relative": false
        }
      ],
      "easing": "ease_out"
    }
  ],
  "particles": [],
  "audio_cues": []
}
```

### GDScript Resource Format

```gdscript
# Save as .tres or .res file
var config = CutsceneDataModels.CutsceneConfig.new()
config.minigame_key = "CatchTheRain"
config.cutscene_type = CutsceneTypes.CutsceneType.WIN
config.duration = 2.5

# Add keyframes, particles, etc.

ResourceSaver.save(config, "res://data/cutscenes/CatchTheRain/win.tres")
```

## Validation Rules

The parser validates the following:

### Duration
- Must be greater than 0
- Must be between 1.5s and 4.0s
- Intro cutscenes: 1.5s - 2.5s
- Win/Fail cutscenes: 2.0s - 3.0s

### Minigame Key
- Cannot be empty

### Keyframes
- Must have at least one keyframe
- Times must be non-negative
- Times must not exceed cutscene duration
- Times must be in chronological order
- Each keyframe must have at least one transform

### Transforms
- Position transforms must have Vector2 values
- Rotation transforms must have numeric values
- Scale transforms must have Vector2 values with positive components

### Particles
- Times must be non-negative
- Times must not exceed cutscene duration
- Duration must be positive
- Density must be "low", "medium", or "high"

### Audio Cues
- Times must be non-negative
- Times must not exceed cutscene duration
- Sound name cannot be empty

## Error Handling

The parser provides descriptive error messages for all validation failures:

```gdscript
var config = CutsceneParser.parse_config("res://data/cutscenes/invalid.json")

if not config:
    # File not found, invalid JSON, or unsupported format
    print("Failed to parse configuration file")
else:
    var validation = CutsceneParser.validate_config(config)
    
    if not validation.is_valid:
        print("Validation errors:")
        for error in validation.errors:
            print("  - " + error)
        
        # Example errors:
        # - Duration is too short (minimum: 1.5s, got: 1.0s)
        # - Keyframe 2 time (3.5s) exceeds cutscene duration (2.5s)
        # - Keyframe 1 scale transform must have positive values
```

## Round-Trip Serialization

The parser supports round-trip serialization (parse → modify → serialize → parse):

```gdscript
# Load configuration
var config = CutsceneParser.parse_config("res://data/cutscenes/original.json")

# Modify configuration
config.duration = 3.0
config.character.expression = CutsceneTypes.Expression.EXCITED

# Convert back to dictionary
var config_dict = config.to_dict()

# Save to new file
var json_string = JSON.stringify(config_dict, "\t")
var file = FileAccess.open("res://data/cutscenes/modified.json", FileAccess.WRITE)
file.store_string(json_string)
file.close()

# Parse again
var reloaded_config = CutsceneParser.parse_config("res://data/cutscenes/modified.json")

# Verify data preserved
assert(reloaded_config.duration == 3.0)
assert(reloaded_config.character.expression == CutsceneTypes.Expression.EXCITED)
```

## Integration with AnimatedCutscenePlayer

The `AnimatedCutscenePlayer` uses `CutsceneParser` internally:

```gdscript
# In AnimatedCutscenePlayer.gd
func _load_cutscene_config(minigame_key: String, cutscene_type: CutsceneTypes.CutsceneType) -> CutsceneDataModels.CutsceneConfig:
    var config_path = _get_config_path(minigame_key, cutscene_type)
    
    var config = CutsceneParser.parse_config(config_path)
    
    if not config:
        push_warning("[AnimatedCutscenePlayer] Failed to load config: " + config_path)
        return _get_default_config(cutscene_type)
    
    var validation = CutsceneParser.validate_config(config)
    
    if not validation.is_valid:
        push_warning("[AnimatedCutscenePlayer] Invalid config: " + config_path)
        push_warning(validation.get_error_message())
        return _get_default_config(cutscene_type)
    
    return config
```

## Testing

Run the test suite to verify parser functionality:

```bash
# In Godot editor
# Open test/CutsceneParserTest.tscn
# Press F6 to run the scene
```

The test suite validates:
- ✅ Parsing valid configurations
- ✅ Handling missing files
- ✅ Handling invalid JSON
- ✅ Validation rules
- ✅ Pretty printing
- ✅ Round-trip serialization

## Best Practices

1. **Always validate** configurations after parsing
2. **Provide fallbacks** for missing or invalid configurations
3. **Use descriptive error messages** when logging validation failures
4. **Test configurations** with the pretty printer before deployment
5. **Version your configurations** to support future format changes

## See Also

- `CutsceneDataModels.gd` - Data model classes
- `CutsceneTypes.gd` - Enum definitions
- `AnimatedCutscenePlayer.gd` - Cutscene playback system
- `.kiro/specs/animated-cutscenes/design.md` - System design document
