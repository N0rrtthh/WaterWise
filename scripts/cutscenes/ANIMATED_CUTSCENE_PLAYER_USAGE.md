# AnimatedCutscenePlayer Usage Guide

## Overview

`AnimatedCutscenePlayer` is the main orchestrator for animated cutscene playback. It coordinates all cutscene elements including configuration loading, character lifecycle management, animation playback, and completion signaling.

## Basic Usage

### Playing a Cutscene

```gdscript
# Create and add the cutscene player
var cutscene_player = AnimatedCutscenePlayer.new()
add_child(cutscene_player)

# Play a win cutscene for CatchTheRain minigame
await cutscene_player.play_cutscene(
    "CatchTheRain",
    CutsceneTypes.CutsceneType.WIN
)

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

## Public Interface

### Methods

#### `play_cutscene(minigame_key: String, cutscene_type: CutsceneTypes.CutsceneType, options: Dictionary = {}) -> void`

Plays a cutscene for a specific minigame and outcome. This method is async and should be awaited.

**Parameters:**
- `minigame_key`: Unique identifier for the minigame (e.g., "CatchTheRain", "FixLeak")
- `cutscene_type`: Type of cutscene (INTRO, WIN, or FAIL)
- `options`: Optional parameters (currently unused, reserved for future expansion)

**Example:**
```gdscript
await cutscene_player.play_cutscene("WaterPlant", CutsceneTypes.CutsceneType.WIN)
```

#### `preload_cutscene(minigame_key: String) -> void`

Preloads cutscene assets for a minigame. Call this during game initialization to avoid loading delays during gameplay.

**Parameters:**
- `minigame_key`: Unique identifier for the minigame

**Example:**
```gdscript
# In GameManager._ready()
cutscene_player.preload_cutscene("CatchTheRain")
cutscene_player.preload_cutscene("FixLeak")
cutscene_player.preload_cutscene("WaterPlant")
```

#### `has_custom_cutscene(minigame_key: String, cutscene_type: CutsceneTypes.CutsceneType) -> bool`

Checks if a custom cutscene configuration exists for a specific minigame and type.

**Parameters:**
- `minigame_key`: Unique identifier for the minigame
- `cutscene_type`: Type of cutscene to check

**Returns:** `true` if custom cutscene exists, `false` otherwise

**Example:**
```gdscript
if cutscene_player.has_custom_cutscene("CatchTheRain", CutsceneTypes.CutsceneType.WIN):
    print("Custom win cutscene available!")
```

### Signals

#### `cutscene_finished()`

Emitted when a cutscene completes playback (including cleanup).

**Example:**
```gdscript
cutscene_player.cutscene_finished.connect(_on_cutscene_finished)

func _on_cutscene_finished():
    print("Cutscene complete, resuming game")
```

## Configuration Loading

The player uses a fallback hierarchy for loading configurations:

1. **Custom minigame-specific configuration**: `res://data/cutscenes/{minigame_key}/{type}.json`
2. **Default configuration**: `res://data/cutscenes/default/{type}.json`
3. **Minimal hardcoded configuration**: Created programmatically if no files exist

### Configuration File Structure

Place configuration files in:
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

## Character Lifecycle

The player automatically manages the character lifecycle:

1. **Instantiation**: Character is created from `WaterDropletCharacter.tscn`
2. **Setup**: Expression and deformation settings applied
3. **Animation**: Character animated through keyframes
4. **Cleanup**: Character freed after cutscene completes

## Animation Coordination

The player coordinates multiple animation elements:

- **Main animation**: Character transformations via AnimationEngine
- **Particle effects**: Spawned at specified times
- **Audio cues**: Triggered at specified times
- **Background**: Color set from configuration

All elements are synchronized to the cutscene timeline.

## Error Handling

The player implements robust error handling:

- **Missing configuration**: Falls back to default or minimal config
- **Invalid configuration**: Logs error and uses minimal config
- **Animation failure**: Logs error and completes cutscene immediately
- **Missing AudioManager**: Skips audio cues with warning

Game progression is never blocked by cutscene errors.

## Performance Considerations

- **Preloading**: Use `preload_cutscene()` during initialization
- **Resource cleanup**: Character and tweens automatically freed
- **Validation**: Configuration validated before playback
- **Caching**: ResourceLoader caches loaded configurations

## Example: Complete Integration

```gdscript
extends Node2D

var cutscene_player: AnimatedCutscenePlayer

func _ready():
    # Create cutscene player
    cutscene_player = AnimatedCutscenePlayer.new()
    add_child(cutscene_player)
    
    # Preload assets
    cutscene_player.preload_cutscene("CatchTheRain")
    
    # Connect signal
    cutscene_player.cutscene_finished.connect(_on_cutscene_finished)

func play_intro():
    await cutscene_player.play_cutscene("CatchTheRain", CutsceneTypes.CutsceneType.INTRO)

func play_win():
    await cutscene_player.play_cutscene("CatchTheRain", CutsceneTypes.CutsceneType.WIN)

func play_fail():
    await cutscene_player.play_cutscene("CatchTheRain", CutsceneTypes.CutsceneType.FAIL)

func _on_cutscene_finished():
    print("Cutscene complete!")
```

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
