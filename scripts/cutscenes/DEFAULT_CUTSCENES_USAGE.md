# Default Cutscenes Usage Guide

## Overview

The default cutscene configurations provide fallback animations for win, fail, and intro scenarios when minigame-specific cutscenes don't exist. These animations are designed to work universally across all minigames while maintaining the game's visual style and pacing.

## File Locations

```
data/cutscenes/default/
├── win.json      # Default win cutscene (2.5s, happy, sparkles)
├── fail.json     # Default fail cutscene (2.5s, sad, smoke)
└── intro.json    # Default intro cutscene (2.0s, determined, no particles)
```

## Quick Reference

### Win Cutscene
- **Duration**: 2.5 seconds
- **Expression**: Happy
- **Animation**: Pop-in → Bounce → Settle → Fade
- **Particles**: Sparkles (high density)
- **Audio**: success_chime, water_splash
- **Use Case**: Celebrating successful minigame completion

### Fail Cutscene
- **Duration**: 2.5 seconds
- **Expression**: Sad
- **Animation**: Drop → Impact → Wobble → Settle → Fade
- **Particles**: Smoke (medium density)
- **Audio**: warning, thud
- **Use Case**: Humorous failure feedback

### Intro Cutscene
- **Duration**: 2.0 seconds
- **Expression**: Determined
- **Animation**: Slide-in → Overshoot → Settle → Ready
- **Particles**: None
- **Audio**: whoosh, ready
- **Use Case**: Introducing minigame before gameplay starts

## Loading Default Cutscenes

### Method 1: Automatic Fallback (Recommended)

The AnimatedCutscenePlayer automatically falls back to default cutscenes:

```gdscript
# In your minigame
func _show_success_micro_cutscene() -> void:
    var player = AnimatedCutscenePlayer.new()
    hud_layer.add_child(player)
    
    # Automatically uses default if minigame-specific doesn't exist
    await player.play_cutscene(
        _get_minigame_key(),
        AnimatedCutscenePlayer.CutsceneType.WIN
    )
    
    player.queue_free()
```

### Method 2: Explicit Default Loading

Load default cutscenes explicitly:

```gdscript
# Load default win cutscene
var config = CutsceneParser.parse_config("res://data/cutscenes/default/win.json")

# Load default fail cutscene
var config = CutsceneParser.parse_config("res://data/cutscenes/default/fail.json")

# Load default intro cutscene
var config = CutsceneParser.parse_config("res://data/cutscenes/default/intro.json")
```

## Animation Timelines

### Win Cutscene Timeline (2.5s)

```
Time:  0.0s    0.5s    1.0s    1.5s    2.0s    2.5s
       |-------|-------|-------|-------|-------|
Scale: 0.3 ──▶ 1.2 ──▶ 1.1 ──▶ 1.0 ──▶ 1.0 ──▶ 0.8
       [pop]   [bounce][settle][hold]  [fade]

Rot:   0.0 ──▶ 0.3 ──▶ -0.1 ─▶ 0.0 ──▶ 0.0 ──▶ 0.0
       [start] [tilt]  [wobble][stable]

Expr:  [happy] ──────────────────────────────▶
       0.0s

Parts: ────────────── [sparkles] ─────────────▶
                      0.5s - 2.5s

Audio: [chime]        [splash]
       0.0s           0.5s
```

### Fail Cutscene Timeline (2.5s)

```
Time:  0.0s    0.5s    1.0s    1.5s    2.0s    2.5s
       |-------|-------|-------|-------|-------|
Scale: 0.4 ──▶ 1.2 ──▶ 0.9 ──▶ 1.1 ──▶ 1.0 ──▶ 0.5
       [drop]  [impact][squash][stretch][fade]

Pos Y: -50 ──▶ 0 ───▶ +10 ──▶ -5 ───▶ 0 ────▶ 0
       [above] [land]  [bounce][settle]

Rot:   0.0 ──▶ -0.2 ─▶ 0.15 ─▶ -0.08 ▶ 0.0 ──▶ 0.0
       [start] [wobble][wobble][stable]

Expr:  [sad] ────────────────────────────────▶
       0.0s

Parts: ────────────── [smoke] ────────────────▶
                      0.5s - 2.0s

Audio: [warning]      [thud]
       0.0s           0.5s
```

### Intro Cutscene Timeline (2.0s)

```
Time:  0.0s    0.5s    1.0s    1.5s    2.0s
       |-------|-------|-------|-------|
Scale: 0.8 ──▶ 1.05 ─▶ 1.0 ──▶ 1.0 ──▶ 1.0
       [small] [pop]   [normal][hold]

Pos X: -100 ─▶ +10 ──▶ 0 ────▶ 0 ────▶ 0
       [left]  [over]  [center]

Rot:   -0.2 ─▶ 0.1 ──▶ 0.0 ──▶ 0.0 ──▶ 0.0
       [tilt]  [counter][straight]

Expr:  [determined] ──────────────────▶
       0.0s

Parts: [none]

Audio: [whoosh]       [ready]
       0.0s           1.0s
```

## Customization

### Creating Minigame-Specific Variants

To override defaults for a specific minigame:

1. Create directory: `data/cutscenes/{MinigameKey}/`
2. Copy a default JSON file as template
3. Modify animations, expressions, particles, audio
4. Save as `win.json`, `fail.json`, or `intro.json`

Example:
```
data/cutscenes/CatchTheRain/
├── win.json      # Custom win animation with water drops
├── fail.json     # Custom fail animation with splash
└── intro.json    # Custom intro with rain theme
```

### Modifying Default Animations

To change the default animations:

1. Edit the JSON files in `data/cutscenes/default/`
2. Maintain the required structure (see Data Format below)
3. Validate with `test/ValidateDefaultCutscenes.tscn`
4. Test in-game

## Data Format

All cutscene configurations follow this structure:

```json
{
  "version": "1.0",
  "minigame_key": "default",
  "cutscene_type": "win|fail|intro",
  "duration": 2.5,
  "character": {
    "expression": "happy|sad|determined|surprised|worried|excited",
    "deformation_enabled": true
  },
  "background_color": "#0a1e0f",
  "keyframes": [
    {
      "time": 0.0,
      "transforms": [
        {
          "type": "position|rotation|scale",
          "value": [x, y] or float,
          "relative": false
        }
      ],
      "easing": "linear|ease_in|ease_out|ease_in_out|bounce|elastic|back"
    }
  ],
  "particles": [
    {
      "time": 0.5,
      "type": "sparkles|water_drops|stars|smoke|splash",
      "duration": 2.0,
      "density": "low|medium|high"
    }
  ],
  "audio_cues": [
    {
      "time": 0.0,
      "sound": "sound_name"
    }
  ]
}
```

## Validation

### Automatic Validation

The CutsceneParser automatically validates:
- Duration bounds (1.5-4.0s)
- Cutscene type-specific bounds (intro: 1.5-2.5s, win/fail: 2.0-3.0s)
- Keyframe chronological order
- Transform value types
- Particle and audio timing

### Manual Validation

Run the validation test:

```gdscript
# In Godot Editor
# 1. Open test/ValidateDefaultCutscenes.tscn
# 2. Run scene (F6)
# 3. Check console output
```

Or validate programmatically:

```gdscript
var config = CutsceneParser.parse_config("res://data/cutscenes/default/win.json")
var validation = CutsceneParser.validate_config(config)

if validation.has_errors():
    print("Validation failed:")
    for error in validation.errors:
        print("  - " + error)
else:
    print("Configuration is valid!")
```

## Best Practices

### Duration Guidelines
- **Intro**: 1.5-2.5s (keep it snappy)
- **Win**: 2.0-3.0s (celebrate but don't drag)
- **Fail**: 2.0-3.0s (humorous but brief)

### Expression Guidelines
- **Win**: happy, excited
- **Fail**: sad, worried (never angry or scary)
- **Intro**: determined, focused

### Particle Guidelines
- **Win**: sparkles, stars (celebratory)
- **Fail**: smoke, splash (comedic)
- **Intro**: none or minimal (keep focus on character)

### Audio Guidelines
- Sync audio with key animation moments
- Use 2-3 audio cues maximum
- First cue at animation start (0.0s)
- Additional cues at dramatic moments (0.5s, 1.0s)

### Animation Guidelines
- Start with anticipation (small scale, offset position)
- Peak with overshoot (1.1-1.2 scale)
- Settle to normal (1.0 scale, 0.0 rotation)
- End with fade or hold

## Troubleshooting

### Configuration Won't Load
- Check JSON syntax (use a JSON validator)
- Verify file path is correct
- Check file permissions

### Validation Errors
- Review error messages from CutsceneParser
- Check duration bounds
- Verify keyframe times are in order
- Ensure transform values match types

### Animation Looks Wrong
- Check keyframe timing
- Verify easing functions
- Review transform values (scale should be positive)
- Test with pretty_print for debugging

### Performance Issues
- Reduce particle density
- Simplify keyframe count
- Use simpler easing functions
- Check for memory leaks

## Examples

### Example 1: Loading and Playing Default Win Cutscene

```gdscript
func show_victory():
    var player = AnimatedCutscenePlayer.new()
    add_child(player)
    
    # This will use default/win.json if minigame-specific doesn't exist
    await player.play_cutscene("MyMinigame", AnimatedCutscenePlayer.CutsceneType.WIN)
    
    player.queue_free()
    _continue_to_next_level()
```

### Example 2: Checking if Default Will Be Used

```gdscript
func check_cutscene_availability():
    var player = AnimatedCutscenePlayer.new()
    
    if player.has_custom_cutscene("MyMinigame", AnimatedCutscenePlayer.CutsceneType.WIN):
        print("Using custom cutscene")
    else:
        print("Will fall back to default cutscene")
```

### Example 3: Preloading Defaults

```gdscript
func _ready():
    # Preload default cutscenes during initialization
    var player = AnimatedCutscenePlayer.new()
    player.preload_cutscene("default")
```

## Related Documentation

- **Design Document**: `.kiro/specs/animated-cutscenes/design.md`
- **Requirements**: `.kiro/specs/animated-cutscenes/requirements.md`
- **Implementation Summary**: `scripts/cutscenes/TASK_12_IMPLEMENTATION_SUMMARY.md`
- **CutsceneParser Usage**: `scripts/cutscenes/CUTSCENE_PARSER_USAGE.md`
- **AnimatedCutscenePlayer Usage**: `scripts/cutscenes/ANIMATED_CUTSCENE_PLAYER_USAGE.md`

## Support

For issues or questions:
1. Check validation output for specific errors
2. Review the design document for animation guidelines
3. Test with ValidateDefaultCutscenes.tscn
4. Use CutsceneParser.pretty_print() for debugging
