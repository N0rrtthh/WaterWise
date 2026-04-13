# Design Document: Animated Character Cutscenes

## Overview

This design implements "Dumb Ways to Die" style animated character cutscenes for the water conservation educational game. The system replaces the current emoji-based cutscenes with expressive, animated water droplet characters that appear during intro, win, and fail scenarios. Each minigame will have unique character animations that relate to the water conservation theme, creating engaging and humorous moments for kids.

The design follows a modular architecture with three core components:
1. **Animation Engine**: Handles character transformations, timing, and easing
2. **Cutscene Parser**: Reads and validates animation configuration data
3. **Cutscene Renderer**: Displays animations and integrates with game flow

The system integrates seamlessly with the existing `MiniGameBase.gd` cutscene methods (`_show_success_micro_cutscene`, `_show_failure_micro_cutscene`) and maintains backward compatibility with the current emoji-based fallback system.

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                      MiniGameBase.gd                        │
│  (_show_success_micro_cutscene, _show_failure_micro_cutscene)│
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              AnimatedCutscenePlayer.gd                      │
│  • Loads cutscene configurations                            │
│  • Orchestrates animation playback                          │
│  • Manages character lifecycle                              │
└────────────┬───────────────────────┬────────────────────────┘
             │                       │
             ▼                       ▼
┌────────────────────────┐  ┌──────────────────────────────┐
│  CutsceneParser.gd     │  │  AnimationEngine.gd          │
│  • Validates config    │  │  • Tween management          │
│  • Parses JSON/GDScript│  │  • Easing functions          │
│  • Error handling      │  │  • Transform composition     │
└────────────────────────┘  └──────────────────────────────┘
             │                       │
             ▼                       ▼
┌─────────────────────────────────────────────────────────────┐
│              WaterDropletCharacter.gd                       │
│  • Character sprite/scene                                   │
│  • Facial expressions (happy, sad, surprised, determined)   │
│  • Body deformation (squash, stretch)                       │
│  • Particle effects integration                             │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Cutscene Trigger**: `MiniGameBase` calls cutscene method with game outcome
2. **Configuration Loading**: `AnimatedCutscenePlayer` loads minigame-specific config
3. **Parsing**: `CutsceneParser` validates and converts config to animation data
4. **Character Setup**: `WaterDropletCharacter` is instantiated with initial state
5. **Animation Playback**: `AnimationEngine` applies transformations over time
6. **Completion**: Signal emitted, character cleaned up, game flow resumes

### Integration Points

- **MiniGameBase.gd**: Existing cutscene methods remain unchanged, new system plugs in
- **AudioManager**: Sound effects triggered at animation keyframes
- **GameManager**: No changes required, cutscene timing maintained
- **Resource System**: Cutscene configs stored in `res://data/cutscenes/`

## Components and Interfaces

### 1. AnimatedCutscenePlayer

**Purpose**: Main orchestrator for cutscene playback

**Public Interface**:
```gdscript
class_name AnimatedCutscenePlayer
extends Control

signal cutscene_finished()

# Play a cutscene for a specific minigame and outcome
func play_cutscene(
    minigame_key: String,
    cutscene_type: CutsceneType,
    options: Dictionary = {}
) -> void

# Preload cutscene assets for a minigame
func preload_cutscene(minigame_key: String) -> void

# Check if a custom cutscene exists for a minigame
func has_custom_cutscene(minigame_key: String, cutscene_type: CutsceneType) -> bool

enum CutsceneType {
    INTRO,
    WIN,
    FAIL
}
```

**Responsibilities**:
- Load cutscene configuration files
- Instantiate `WaterDropletCharacter`
- Coordinate `AnimationEngine` and `CutsceneParser`
- Handle fallback to emoji-based cutscenes
- Emit completion signals

### 2. CutsceneParser

**Purpose**: Parse and validate cutscene configuration data

**Public Interface**:
```gdscript
class_name CutsceneParser
extends RefCounted

# Parse cutscene configuration from file
static func parse_config(config_path: String) -> CutsceneConfig

# Parse cutscene configuration from dictionary
static func parse_dict(config_dict: Dictionary) -> CutsceneConfig

# Validate configuration structure
static func validate_config(config: CutsceneConfig) -> ValidationResult

# Pretty print configuration for debugging
static func pretty_print(config: CutsceneConfig) -> String

class CutsceneConfig:
    var duration: float
    var character_expression: String
    var keyframes: Array[Keyframe]
    var particles: Array[ParticleEffect]
    var audio_cues: Array[AudioCue]
    var background_color: Color

class Keyframe:
    var time: float
    var transforms: Array[Transform]
    var easing: String

class Transform:
    var type: TransformType  # POSITION, ROTATION, SCALE
    var value: Variant  # Vector2 for position/scale, float for rotation
    var relative: bool  # true = relative to current, false = absolute

class ValidationResult:
    var is_valid: bool
    var errors: Array[String]
```

**Responsibilities**:
- Read JSON or GDScript resource files
- Validate required fields and data types
- Convert timing values to engine-compatible formats
- Provide descriptive error messages
- Support round-trip serialization

### 3. AnimationEngine

**Purpose**: Apply transformations to character over time

**Public Interface**:
```gdscript
class_name AnimationEngine
extends RefCounted

# Create and start an animation sequence
static func animate(
    target: Node2D,
    keyframes: Array[Keyframe],
    duration: float
) -> Tween

# Apply a single transformation
static func apply_transform(
    target: Node2D,
    transform: Transform,
    duration: float,
    easing: String
) -> Tween

# Compose multiple transformations
static func compose_transforms(
    target: Node2D,
    transforms: Array[Transform],
    duration: float
) -> Tween

# Available easing functions
enum Easing {
    LINEAR,
    EASE_IN,
    EASE_OUT,
    EASE_IN_OUT,
    BOUNCE,
    ELASTIC,
    BACK
}
```

**Responsibilities**:
- Create and manage Godot Tween objects
- Apply position, rotation, and scale transformations
- Handle easing curves
- Support parallel and sequential animations
- Clean up tweens on completion

### 4. WaterDropletCharacter

**Purpose**: Animated character sprite with expressions

**Public Interface**:
```gdscript
class_name WaterDropletCharacter
extends Node2D

signal expression_changed(new_expression: String)

# Set character expression
func set_expression(expression: Expression) -> void

# Get current expression
func get_expression() -> Expression

# Enable/disable body deformation
func set_deformation_enabled(enabled: bool) -> void

# Apply squash and stretch effect
func apply_squash_stretch(squash: float, stretch: float) -> void

# Spawn particle effect
func spawn_particles(effect_type: ParticleType) -> void

enum Expression {
    HAPPY,
    SAD,
    SURPRISED,
    DETERMINED,
    WORRIED,
    EXCITED
}

enum ParticleType {
    SPARKLES,
    WATER_DROPS,
    STARS,
    SMOKE,
    SPLASH
}
```

**Responsibilities**:
- Render water droplet character sprite
- Manage facial expression states
- Apply body deformation for squash/stretch
- Integrate particle effects
- Maintain consistent visual style

## Data Models

### Cutscene Configuration Format

Cutscene configurations are stored as JSON files in `res://data/cutscenes/{minigame_key}/`:

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
          "value": [0.3, 0.3],
          "relative": false
        },
        {
          "type": "position",
          "value": [0, -50],
          "relative": true
        }
      ],
      "easing": "ease_out"
    },
    {
      "time": 0.5,
      "transforms": [
        {
          "type": "scale",
          "value": [1.2, 1.2],
          "relative": false
        },
        {
          "type": "rotation",
          "value": 0.3,
          "relative": false
        }
      ],
      "easing": "bounce"
    },
    {
      "time": 1.5,
      "transforms": [
        {
          "type": "scale",
          "value": [1.0, 1.0],
          "relative": false
        },
        {
          "type": "rotation",
          "value": 0.0,
          "relative": false
        }
      ],
      "easing": "ease_in_out"
    }
  ],
  "particles": [
    {
      "time": 0.5,
      "type": "sparkles",
      "duration": 1.0
    }
  ],
  "audio_cues": [
    {
      "time": 0.0,
      "sound": "success_chime"
    },
    {
      "time": 0.5,
      "sound": "water_splash"
    }
  ]
}
```

### Default Animation Profiles

The system provides default animation profiles for common scenarios:

**Win Cutscene Default**:
- Pop in from small scale (0.3) to overshoot (1.2) to normal (1.0)
- Slight rotation wobble for celebration
- Happy expression
- Sparkle particles
- Duration: 2.0-3.0 seconds

**Fail Cutscene Default**:
- Drop in from above with bounce
- Wobble/shake animation
- Sad or worried expression
- Smoke or splash particles
- Duration: 2.0-3.0 seconds

**Intro Cutscene Default**:
- Slide in from side with anticipation
- Determined expression
- No particles (keep it clean)
- Duration: 1.5-2.5 seconds

### Animation Variants

Each minigame can have up to 3 animation variants per cutscene type. The system randomly selects one, avoiding immediate repetition:

```
res://data/cutscenes/CatchTheRain/
  ├── win_variant_1.json
  ├── win_variant_2.json
  ├── win_variant_3.json
  ├── fail_variant_1.json
  ├── fail_variant_2.json
  └── intro.json
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*


### Property 1: Transform Application

*For any* character node and any valid transform (position, rotation, or scale), applying the transform through the AnimationEngine should result in the character's corresponding property being updated to the target value.

**Validates: Requirements 1.3, 1.4, 1.5**

### Property 2: Layered Transform Composition

*For any* character node and any set of transforms applied simultaneously, all transforms should be applied in parallel without interfering with each other.

**Validates: Requirements 1.6**

### Property 3: Animation Timing Accuracy

*For any* animation with a specified duration, the animation should complete within 5% of the specified duration (accounting for frame timing variance).

**Validates: Requirements 1.7, 6.7, 14.6**

### Property 4: Easing Function Interpolation

*For any* animation with an easing function, the interpolation between keyframes should follow the mathematical curve defined by that easing function.

**Validates: Requirements 1.8**

### Property 5: Cutscene Duration Bounds

*For any* cutscene, the total duration should be between 1.5 and 4.0 seconds (intro: 1.5-2.5s, win/fail: 2.0-3.0s).

**Validates: Requirements 2.7, 14.1, 14.2, 14.3**

### Property 6: Minigame-Specific Configuration Loading

*For any* minigame key, requesting a cutscene should load the configuration specific to that minigame if it exists, otherwise load the default configuration.

**Validates: Requirements 3.1, 3.2, 12.1**

### Property 7: Themed Visual Effects

*For any* water-themed minigame (containing "Rain", "Leak", "Tap", "Water", or "Pipe" in the key), the cutscene should include water-related particle effects.

**Validates: Requirements 3.3**

### Property 8: Character Consistency

*For any* cutscene, the character rendered should always be the Water_Droplet_Character.

**Validates: Requirements 4.1**

### Property 9: Expression State Changes

*For any* valid expression (happy, sad, surprised, determined, worried, excited), setting the character's expression should result in the character displaying that expression.

**Validates: Requirements 4.2**

### Property 10: Body Deformation

*For any* squash and stretch values, applying deformation to the character should result in the character's scale being modified accordingly.

**Validates: Requirements 4.3**

### Property 11: Configuration File Parsing

*For any* valid configuration file (JSON or GDScript resource), the CutsceneParser should successfully parse it and return a CutsceneConfig object.

**Validates: Requirements 5.1, 10.1**

### Property 12: Configuration Format Support

*For any* configuration containing keyframes, transforms, easing, expressions, and particles, the parser should preserve all these elements in the parsed CutsceneConfig.

**Validates: Requirements 5.2, 5.3, 5.4, 5.5, 5.6**

### Property 13: Configuration Validation

*For any* configuration with missing required fields, the CutsceneParser should return a validation error with a descriptive message.

**Validates: Requirements 5.7, 10.2, 10.3**

### Property 14: Invalid Data Fallback

*For any* invalid animation data, the system should log an error and use default animations without blocking game progression.

**Validates: Requirements 5.8, 12.3, 12.4, 12.5**

### Property 15: Configuration Round-Trip

*For any* valid cutscene configuration, parsing then serializing then parsing should produce an equivalent configuration (round-trip property).

**Validates: Requirements 10.6**

### Property 16: Pretty Printer Round-Trip

*For any* valid Animation_Profile object, parsing then pretty printing then parsing should produce an equivalent object (round-trip property).

**Validates: Requirements 11.5**

### Property 17: Pretty Printer Data Preservation

*For any* cutscene configuration, pretty printing should preserve all animation timing, transformation data, and produce properly indented, human-readable output.

**Validates: Requirements 11.1, 11.2, 11.3, 11.4**

### Property 18: Game Flow Pause and Resume

*For any* cutscene playback, game logic should be paused during playback and automatically resumed upon completion.

**Validates: Requirements 6.4, 6.5**

### Property 19: Async Completion Support

*For any* cutscene, awaiting the play_cutscene method should block execution until the cutscene completes, then continue.

**Validates: Requirements 6.6**

### Property 20: Particle Effect Support

*For any* particle type (sparkles, water drops, stars, smoke, splash), spawning that particle should result in the particle effect being visible.

**Validates: Requirements 7.1**

### Property 21: Background Color Transitions

*For any* two colors, transitioning the background from one to the other should result in a smooth color interpolation.

**Validates: Requirements 7.2**

### Property 22: Screen Shake Effect

*For any* screen shake trigger, the camera should oscillate for the duration of the shake effect.

**Validates: Requirements 7.3**

### Property 23: Contextual Particle Effects

*For any* win cutscene, celebratory particles should be displayed; for any fail cutscene, failure particles should be displayed.

**Validates: Requirements 7.4, 7.5**

### Property 24: Text Overlay Animation

*For any* text overlay with animation, the text should animate according to the specified animation parameters.

**Validates: Requirements 7.6**

### Property 25: Frame Rate Performance

*For any* cutscene playback, the average frame time should be less than or equal to 16.67ms (60 FPS).

**Validates: Requirements 7.7, 9.3**

### Property 26: Audio Synchronization

*For any* cutscene with audio cues, sound effects should play at the specified keyframe times (within 50ms tolerance).

**Validates: Requirements 8.1, 8.5, 8.6**

### Property 27: Contextual Audio

*For any* win cutscene, success sound effects should play; for any fail cutscene, failure sound effects should play.

**Validates: Requirements 8.3, 8.4**

### Property 28: Asset Preloading

*For any* minigame, preloading its cutscene assets should result in those assets being available in memory before first use.

**Validates: Requirements 9.1**

### Property 29: Animation Data Caching

*For any* animation loaded twice, the second load should retrieve the data from cache rather than re-parsing the file.

**Validates: Requirements 9.2**

### Property 30: Texture Atlas Support

*For any* character sprite using a texture atlas, the sprite should render correctly with the correct sub-region.

**Validates: Requirements 9.4**

### Property 31: Adaptive Particle Density

*For any* cutscene playing when memory usage exceeds 80%, particle effect density should be reduced compared to normal conditions.

**Validates: Requirements 9.5**

### Property 32: Resource Cleanup

*For any* cutscene completion, all animation resources (tweens, particles, temporary nodes) should be freed from memory.

**Validates: Requirements 9.6**

### Property 33: Nested Animation Sequences

*For any* configuration with nested animation sequences, the parser should correctly parse and preserve the nesting structure.

**Validates: Requirements 10.4**

### Property 34: Timing Format Conversion

*For any* timing value in the configuration, the parser should convert it to engine-compatible format (seconds as float).

**Validates: Requirements 10.5**

### Property 35: Asset Load Failure Fallback

*For any* character asset load failure, the system should fall back to the legacy emoji-based cutscene.

**Validates: Requirements 12.2**

### Property 36: Skip Functionality

*For any* cutscene with skip enabled, triggering skip should immediately end the cutscene and emit the completion signal.

**Validates: Requirements 14.4**

### Property 37: Adaptive Duration Reduction

*For any* cutscene played 3 or more times, the duration should be reduced by 30% compared to the first playback.

**Validates: Requirements 14.5**

### Property 38: Animation Variant Selection

*For any* minigame with multiple animation variants, requesting a cutscene should randomly select one of the available variants.

**Validates: Requirements 15.1**

### Property 39: Recent Animation Exclusion

*For any* cutscene selection, animations played in the last 2 attempts should be excluded from the random selection pool.

**Validates: Requirements 15.3, 15.4**

### Property 40: Animation Distribution Fairness

*For any* set of animation variants played 100 times, each variant should be selected between 20% and 40% of the time (allowing for randomness variance).

**Validates: Requirements 15.5**


## Error Handling

The cutscene system implements a robust error handling strategy that ensures game progression is never blocked by cutscene failures.

### Error Categories

1. **Configuration Errors**
   - Missing configuration files
   - Invalid JSON/GDScript syntax
   - Missing required fields
   - Invalid data types

2. **Asset Loading Errors**
   - Missing character sprites
   - Missing particle textures
   - Missing audio files
   - Corrupted asset files

3. **Runtime Errors**
   - Animation engine failures
   - Tween creation errors
   - Memory allocation failures
   - Performance degradation

### Error Handling Strategy

**Configuration Errors**:
- Parse errors: Log descriptive error message, use default configuration
- Validation errors: Log field-specific errors, use default values for missing fields
- Never block cutscene playback due to configuration issues

**Asset Loading Errors**:
- Character asset failure: Fall back to legacy emoji-based cutscene
- Particle texture failure: Disable particles for that cutscene
- Audio file failure: Play cutscene without audio
- Log all asset failures to debug console

**Runtime Errors**:
- Animation engine failure: Skip animation, show static character
- Tween creation failure: Use instant transitions instead of animated
- Memory allocation failure: Reduce particle density, simplify effects
- Performance degradation: Dynamically reduce visual complexity

### Fallback Hierarchy

```
1. Custom minigame-specific cutscene
   ↓ (if missing or fails)
2. Default cutscene for that type (intro/win/fail)
   ↓ (if fails)
3. Legacy emoji-based cutscene
   ↓ (if fails)
4. Skip cutscene entirely, continue game
```

### Error Logging

All errors are logged with the following format:
```
[AnimatedCutscene] ERROR: {component} - {error_message}
  Minigame: {minigame_key}
  Cutscene Type: {intro/win/fail}
  Fallback: {fallback_action}
```

Example:
```
[AnimatedCutscene] ERROR: CutsceneParser - Missing required field 'duration'
  Minigame: CatchTheRain
  Cutscene Type: win
  Fallback: Using default duration of 2.5 seconds
```


## Testing Strategy

The testing strategy employs both unit tests and property-based tests to ensure comprehensive coverage of the animated cutscene system.

### Dual Testing Approach

**Unit Tests**: Verify specific examples, edge cases, and integration points
- Specific cutscene configurations (CatchTheRain win, FixLeak fail, etc.)
- Integration with MiniGameBase methods
- AudioManager integration
- Edge cases (empty configs, missing files, corrupted data)

**Property-Based Tests**: Verify universal properties across all inputs
- Transform application correctness
- Configuration round-trip serialization
- Timing accuracy across random durations
- Animation variant distribution fairness
- Resource cleanup after completion

Together, these approaches provide comprehensive coverage: unit tests catch concrete bugs in specific scenarios, while property tests verify general correctness across the entire input space.

### Property-Based Testing Configuration

**Framework**: GDScript property-based testing will be implemented using a custom generator system (since Godot doesn't have a built-in PBT library).

**Test Configuration**:
- Minimum 100 iterations per property test
- Each test tagged with: `# Feature: animated-cutscenes, Property {number}: {property_text}`
- Random seed logged for reproducibility
- Shrinking on failure to find minimal failing case

**Example Property Test Structure**:
```gdscript
# Feature: animated-cutscenes, Property 1: Transform Application
func test_transform_application_property():
    for i in range(100):
        var character = WaterDropletCharacter.new()
        var transform_type = ["position", "rotation", "scale"].pick_random()
        var target_value = _generate_random_transform_value(transform_type)
        
        AnimationEngine.apply_transform(character, transform_type, target_value, 0.5, "linear")
        await get_tree().create_timer(0.6).timeout
        
        var actual_value = _get_character_property(character, transform_type)
        assert_approximately_equal(actual_value, target_value, 0.01)
        
        character.queue_free()
```

### Test Coverage by Component

**AnimatedCutscenePlayer**:
- Unit: Integration with MiniGameBase, fallback behavior, signal emission
- Property: Cutscene loading for all minigame keys, timing bounds

**CutsceneParser**:
- Unit: Specific valid/invalid configurations, error messages
- Property: Round-trip serialization, validation for all field combinations

**AnimationEngine**:
- Unit: Specific easing functions, edge cases (zero duration, negative values)
- Property: Transform application, timing accuracy, parallel composition

**WaterDropletCharacter**:
- Unit: Specific expressions, particle spawning, deformation
- Property: Expression changes, deformation values, particle types

### Test Data Generators

Custom generators for property-based testing:

```gdscript
# Generate random cutscene configurations
func generate_cutscene_config() -> Dictionary:
    return {
        "duration": randf_range(1.5, 4.0),
        "character": {
            "expression": ["happy", "sad", "surprised", "determined"].pick_random()
        },
        "keyframes": generate_keyframes(randi_range(2, 5)),
        "particles": generate_particles(randi_range(0, 3))
    }

# Generate random transforms
func generate_transform() -> Dictionary:
    var type = ["position", "rotation", "scale"].pick_random()
    var value
    match type:
        "position": value = Vector2(randf_range(-100, 100), randf_range(-100, 100))
        "rotation": value = randf_range(-PI, PI)
        "scale": value = Vector2(randf_range(0.5, 2.0), randf_range(0.5, 2.0))
    return {"type": type, "value": value, "relative": randbool()}

# Generate random minigame keys
func generate_minigame_key() -> String:
    var keys = [
        "CatchTheRain", "FixLeak", "WaterPlant", "ThirstyPlant",
        "FilterBuilder", "RiceWashRescue", "VegetableBath"
    ]
    return keys.pick_random()
```

### Integration Testing

Integration tests verify the system works correctly with existing game components:

1. **MiniGameBase Integration**
   - Test: Call `_show_success_micro_cutscene` and verify animated cutscene plays
   - Test: Call `_show_failure_micro_cutscene` and verify animated cutscene plays
   - Test: Verify game flow pauses during cutscene and resumes after

2. **AudioManager Integration**
   - Test: Verify AudioManager methods are called at correct times
   - Test: Verify success sounds play for win cutscenes
   - Test: Verify failure sounds play for fail cutscenes

3. **Resource System Integration**
   - Test: Verify cutscene configs load from `res://data/cutscenes/`
   - Test: Verify texture atlases load correctly
   - Test: Verify preloading works during game initialization

### Performance Testing

Performance tests ensure cutscenes meet frame rate and timing requirements:

1. **Frame Rate Test**
   - Measure average frame time during cutscene playback
   - Assert average frame time ≤ 16.67ms (60 FPS)
   - Test across different cutscene complexities

2. **Memory Usage Test**
   - Measure memory before and after cutscene
   - Assert memory is freed after cutscene completion
   - Test with 100 consecutive cutscenes

3. **Timing Accuracy Test**
   - Measure actual cutscene duration
   - Assert within 5% of specified duration
   - Test across different durations (1.5s to 4.0s)

### Edge Case Testing

Specific edge cases to test:

1. **Missing Assets**
   - Missing configuration file → use default
   - Missing character sprite → use emoji fallback
   - Missing audio file → play without audio

2. **Invalid Data**
   - Corrupted JSON → log error, use default
   - Negative duration → clamp to minimum (1.5s)
   - Invalid expression name → use default expression

3. **Boundary Conditions**
   - Zero keyframes → static character
   - Single keyframe → instant transition
   - 100 keyframes → verify performance

4. **Concurrent Cutscenes**
   - Attempt to play two cutscenes simultaneously → queue second
   - Skip during playback → verify cleanup

### Test Organization

Tests are organized by component:

```
test/
├── cutscenes/
│   ├── test_animated_cutscene_player.gd
│   ├── test_cutscene_parser.gd
│   ├── test_animation_engine.gd
│   ├── test_water_droplet_character.gd
│   ├── test_integration_minigame_base.gd
│   ├── test_integration_audio_manager.gd
│   ├── test_performance.gd
│   └── test_edge_cases.gd
```

Each test file includes both unit tests and property-based tests, clearly tagged with comments indicating which requirements and properties they validate.


## Implementation Examples

### Example 1: Playing a Win Cutscene

```gdscript
# In MiniGameBase.gd
func _show_success_micro_cutscene() -> void:
    var cutscene_player = AnimatedCutscenePlayer.new()
    hud_layer.add_child(cutscene_player)
    
    await cutscene_player.play_cutscene(
        _get_minigame_key(),
        AnimatedCutscenePlayer.CutsceneType.WIN
    )
    
    cutscene_player.queue_free()
```

### Example 2: Creating a Custom Cutscene Configuration

```json
{
  "version": "1.0",
  "minigame_key": "FixLeak",
  "cutscene_type": "win",
  "duration": 2.8,
  "character": {
    "expression": "excited",
    "deformation_enabled": true
  },
  "background_color": "#0a1e1f",
  "keyframes": [
    {
      "time": 0.0,
      "transforms": [
        {"type": "scale", "value": [0.2, 0.2], "relative": false},
        {"type": "position", "value": [0, 100], "relative": true}
      ],
      "easing": "ease_out"
    },
    {
      "time": 0.6,
      "transforms": [
        {"type": "scale", "value": [1.3, 1.3], "relative": false},
        {"type": "position", "value": [0, 0], "relative": true},
        {"type": "rotation", "value": 0.4, "relative": false}
      ],
      "easing": "bounce"
    },
    {
      "time": 1.8,
      "transforms": [
        {"type": "scale", "value": [1.0, 1.0], "relative": false},
        {"type": "rotation", "value": 0.0, "relative": false}
      ],
      "easing": "ease_in_out"
    }
  ],
  "particles": [
    {
      "time": 0.6,
      "type": "water_drops",
      "duration": 1.2,
      "density": "high"
    },
    {
      "time": 0.8,
      "type": "sparkles",
      "duration": 1.0,
      "density": "medium"
    }
  ],
  "audio_cues": [
    {
      "time": 0.0,
      "sound": "success_chime"
    },
    {
      "time": 0.6,
      "sound": "water_splash"
    }
  ]
}
```

### Example 3: Implementing a Custom Easing Function

```gdscript
# In AnimationEngine.gd
static func apply_easing(t: float, easing: String) -> float:
    match easing:
        "linear":
            return t
        "ease_in":
            return t * t
        "ease_out":
            return t * (2.0 - t)
        "ease_in_out":
            return t * t * (3.0 - 2.0 * t)
        "bounce":
            if t < 0.5:
                return 2.0 * t * t
            else:
                return 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
        "elastic":
            var c4 = (2.0 * PI) / 3.0
            if t == 0.0: return 0.0
            if t == 1.0: return 1.0
            return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0
        "back":
            var c1 = 1.70158
            var c3 = c1 + 1.0
            return c3 * t * t * t - c1 * t * t
        _:
            return t  # fallback to linear
```

### Example 4: Character Expression System

```gdscript
# In WaterDropletCharacter.gd
func set_expression(expression: Expression) -> void:
    current_expression = expression
    
    match expression:
        Expression.HAPPY:
            _set_face_sprite("res://assets/characters/droplet_happy.png")
            _set_eye_animation("blink_happy")
        Expression.SAD:
            _set_face_sprite("res://assets/characters/droplet_sad.png")
            _set_eye_animation("blink_sad")
        Expression.SURPRISED:
            _set_face_sprite("res://assets/characters/droplet_surprised.png")
            _set_eye_animation("wide_open")
        Expression.DETERMINED:
            _set_face_sprite("res://assets/characters/droplet_determined.png")
            _set_eye_animation("focused")
        Expression.WORRIED:
            _set_face_sprite("res://assets/characters/droplet_worried.png")
            _set_eye_animation("nervous")
        Expression.EXCITED:
            _set_face_sprite("res://assets/characters/droplet_excited.png")
            _set_eye_animation("sparkle")
    
    expression_changed.emit(expression)
```


## Animation Timing Diagrams

### Win Cutscene Timeline (2.5s)

```
Time:  0.0s    0.5s    1.0s    1.5s    2.0s    2.5s
       |-------|-------|-------|-------|-------|
Scale: 0.3 ──▶ 1.2 ──▶ 1.1 ──▶ 1.0 ──▶ 1.0 ──▶ 0.8
       [pop in] [bounce] [settle] [hold] [fade out]

Rot:   0.0 ──▶ 0.3 ──▶ -0.1 ─▶ 0.0 ──▶ 0.0 ──▶ 0.0
       [start]  [tilt]  [wobble] [stable]

Expr:  [determined] ──▶ [excited] ──────────▶ [happy]
       0.0s              0.5s                  1.0s

Parts: ────────────── [sparkles] ─────────────────▶
                      0.5s - 2.5s

Audio: [chime]        [splash]
       0.0s           0.5s
```

### Fail Cutscene Timeline (2.5s)

```
Time:  0.0s    0.5s    1.0s    1.5s    2.0s    2.5s
       |-------|-------|-------|-------|-------|
Scale: 0.4 ──▶ 1.2 ──▶ 0.9 ──▶ 1.1 ──▶ 1.0 ──▶ 0.5
       [drop]  [impact] [squash] [stretch] [fade]

Pos Y: -50 ──▶ 0 ───▶ 10 ───▶ -5 ───▶ 0 ────▶ 0
       [above] [land]  [bounce] [settle]

Rot:   0.0 ──▶ -0.2 ─▶ 0.15 ─▶ -0.08 ▶ 0.0 ──▶ 0.0
       [start] [wobble left] [wobble right] [stable]

Expr:  [worried] ──▶ [surprised] ──▶ [sad]
       0.0s          0.5s             1.0s

Parts: ────────────── [smoke] ──────────────────▶
                      0.5s - 2.0s

Audio: [warning]      [thud]
       0.0s           0.5s
```

### Intro Cutscene Timeline (2.0s)

```
Time:  0.0s    0.5s    1.0s    1.5s    2.0s
       |-------|-------|-------|-------|
Scale: 0.8 ──▶ 1.05 ─▶ 1.0 ──▶ 1.0 ──▶ 1.0
       [small] [pop]   [normal]

Pos X: -100 ─▶ 10 ───▶ 0 ────▶ 0 ────▶ 0
       [left]  [overshoot] [center]

Rot:   -0.2 ─▶ 0.1 ──▶ 0.0 ──▶ 0.0 ──▶ 0.0
       [tilt]  [counter] [straight]

Expr:  [determined] ──────────────────▶ [determined]
       0.0s                             2.0s

Audio: [whoosh]       [ready]
       0.0s           1.0s
```

## Character Asset Structure

### Water Droplet Character Sprite Sheets

```
res://assets/characters/
├── droplet_base.png              # Base body shape (512x512)
├── expressions/
│   ├── happy.png                 # Happy face overlay
│   ├── sad.png                   # Sad face overlay
│   ├── surprised.png             # Surprised face overlay
│   ├── determined.png            # Determined face overlay
│   ├── worried.png               # Worried face overlay
│   └── excited.png               # Excited face overlay
├── animations/
│   ├── blink_happy.tres          # Animation resource
│   ├── blink_sad.tres
│   ├── wide_open.tres
│   ├── focused.tres
│   ├── nervous.tres
│   └── sparkle.tres
└── atlas/
    └── droplet_atlas.png         # Texture atlas (2048x2048)
```

### Particle Effect Assets

```
res://assets/particles/
├── sparkles.png                  # Sparkle particle texture
├── water_drops.png               # Water drop particle texture
├── stars.png                     # Star particle texture
├── smoke.png                     # Smoke particle texture
└── splash.png                    # Splash particle texture
```

## Performance Optimization Strategies

### 1. Asset Preloading

Preload cutscene assets during game initialization to avoid loading delays:

```gdscript
# In GameManager._ready()
func _preload_cutscene_assets():
    var minigames = ["CatchTheRain", "FixLeak", "WaterPlant", ...]
    for key in minigames:
        AnimatedCutscenePlayer.preload_cutscene(key)
```

### 2. Texture Atlasing

Combine all character expressions into a single texture atlas to reduce draw calls:

```gdscript
# Character uses atlas regions instead of separate textures
var atlas = load("res://assets/characters/atlas/droplet_atlas.png")
var happy_region = Rect2(0, 0, 512, 512)
var sad_region = Rect2(512, 0, 512, 512)
```

### 3. Object Pooling

Reuse particle effect nodes instead of creating/destroying:

```gdscript
var particle_pool: Array[GPUParticles2D] = []

func get_particle_effect() -> GPUParticles2D:
    if particle_pool.is_empty():
        return GPUParticles2D.new()
    return particle_pool.pop_back()

func return_particle_effect(particles: GPUParticles2D):
    particles.emitting = false
    particle_pool.append(particles)
```

### 4. Adaptive Quality

Reduce visual complexity based on performance:

```gdscript
func _process(_delta):
    var fps = Engine.get_frames_per_second()
    if fps < 50:
        # Reduce particle density
        for particle in active_particles:
            particle.amount = particle.amount * 0.7
        # Disable some visual effects
        screen_shake_enabled = false
```

### 5. Memory Management

Aggressively clean up resources after cutscene completion:

```gdscript
func _cleanup_cutscene():
    # Free character node
    if character:
        character.queue_free()
        character = null
    
    # Stop and free all tweens
    for tween in active_tweens:
        tween.kill()
    active_tweens.clear()
    
    # Free particle effects
    for particle in active_particles:
        particle.queue_free()
    active_particles.clear()
    
    # Clear cached data if memory is high
    if OS.get_static_memory_usage() > memory_threshold:
        animation_cache.clear()
```

## Migration Path from Legacy System

### Phase 1: Parallel Implementation

1. Implement new animated cutscene system alongside existing emoji system
2. Add feature flag to toggle between systems
3. Test new system with subset of minigames

### Phase 2: Gradual Rollout

1. Enable animated cutscenes for 5 minigames
2. Monitor performance and gather feedback
3. Fix issues and optimize
4. Enable for 10 more minigames
5. Repeat until all minigames covered

### Phase 3: Legacy Deprecation

1. Keep emoji system as fallback for asset load failures
2. Remove feature flag, make animated cutscenes default
3. Document emoji system as emergency fallback only

### Backward Compatibility

The new system maintains backward compatibility:

```gdscript
# Old code continues to work
func _show_success_micro_cutscene() -> void:
    # If animated cutscene system available, use it
    if AnimatedCutscenePlayer:
        var player = AnimatedCutscenePlayer.new()
        hud_layer.add_child(player)
        await player.play_cutscene(_get_minigame_key(), CutsceneType.WIN)
        player.queue_free()
        return
    
    # Otherwise fall back to legacy emoji system
    _show_legacy_emoji_cutscene(true)
```

## Future Enhancements

### Potential Future Features

1. **Skeletal Animation Support**
   - Implement bone-based character animation
   - Allow more complex character movements
   - Support character accessories and props

2. **Cutscene Editor Tool**
   - Visual editor for creating cutscene configurations
   - Real-time preview of animations
   - Timeline-based keyframe editing

3. **Advanced Particle Systems**
   - Custom particle shaders
   - Particle collision and physics
   - Weather effects (rain, snow)

4. **Character Customization**
   - Player-selectable character skins
   - Unlockable expressions and animations
   - Seasonal/event-themed characters

5. **Multiplayer Cutscenes**
   - Show multiple characters in co-op mode
   - Synchronized animations across players
   - Competitive celebration animations

6. **Accessibility Features**
   - High contrast mode for characters
   - Reduced motion option
   - Audio descriptions of cutscenes

