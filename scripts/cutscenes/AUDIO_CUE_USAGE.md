# Audio Cue System Usage Guide

## Quick Start

Audio cues allow you to synchronize sound effects with cutscene animations. They are defined in cutscene configuration files and automatically played at specified times.

## Basic Usage

### Adding Audio Cues to a Cutscene Configuration

```json
{
  "version": "1.0",
  "minigame_key": "YourMinigame",
  "cutscene_type": "win",
  "duration": 2.5,
  "audio_cues": [
    {
      "time": 0.0,
      "sound": "success"
    },
    {
      "time": 0.5,
      "sound": "water_splash"
    }
  ]
}
```

### Audio Cue Properties

- **time** (float): When to play the sound (in seconds from cutscene start)
- **sound** (string): Name of the sound to play (see Available Sounds below)

## Available Sounds

### Success Sounds (Win Cutscenes)
- `success` - Success chime
- `bonus` - Bonus/collect sound
- `water_splash` - Water splash effect

### Failure Sounds (Fail Cutscenes)
- `failure` - Failure sound
- `damage` - Impact/damage sound
- `warning` - Warning alert

### Intro Sounds
- `whoosh` - Swoosh/movement sound
- `ready` - Ready/countdown sound
- `game_start` - Game start fanfare

### Water Sounds
- `water_splash` - Large water splash
- `water_drop` - Single water drop

### UI Sounds
- `click` - Button click
- `game_end` - Game end sound

## Examples

### Example 1: Win Cutscene with Celebration

```json
{
  "cutscene_type": "win",
  "duration": 2.5,
  "keyframes": [
    {
      "time": 0.0,
      "transforms": [{"type": "scale", "value": [0.3, 0.3]}]
    },
    {
      "time": 0.5,
      "transforms": [{"type": "scale", "value": [1.2, 1.2]}]
    }
  ],
  "audio_cues": [
    {
      "time": 0.0,
      "sound": "success"
    },
    {
      "time": 0.5,
      "sound": "water_splash"
    },
    {
      "time": 1.0,
      "sound": "bonus"
    }
  ]
}
```

### Example 2: Fail Cutscene with Impact

```json
{
  "cutscene_type": "fail",
  "duration": 2.5,
  "keyframes": [
    {
      "time": 0.0,
      "transforms": [{"type": "position", "value": [0, -50], "relative": true}]
    },
    {
      "time": 0.5,
      "transforms": [{"type": "position", "value": [0, 0], "relative": false}]
    }
  ],
  "audio_cues": [
    {
      "time": 0.0,
      "sound": "failure"
    },
    {
      "time": 0.5,
      "sound": "damage"
    }
  ]
}
```

### Example 3: Intro Cutscene with Entrance

```json
{
  "cutscene_type": "intro",
  "duration": 2.0,
  "keyframes": [
    {
      "time": 0.0,
      "transforms": [{"type": "position", "value": [-100, 0], "relative": true}]
    },
    {
      "time": 1.0,
      "transforms": [{"type": "position", "value": [0, 0], "relative": false}]
    }
  ],
  "audio_cues": [
    {
      "time": 0.0,
      "sound": "whoosh"
    },
    {
      "time": 1.0,
      "sound": "ready"
    }
  ]
}
```

## Programmatic Usage

### Creating Audio Cues in Code

```gdscript
# Create a cutscene configuration
var config = CutsceneDataModels.CutsceneConfig.new()
config.minigame_key = "MyMinigame"
config.cutscene_type = CutsceneTypes.CutsceneType.WIN
config.duration = 2.0

# Add audio cues
var audio1 = CutsceneDataModels.AudioCue.new(0.0, "success")
var audio2 = CutsceneDataModels.AudioCue.new(0.5, "water_splash")

config.add_audio_cue(audio1)
config.add_audio_cue(audio2)

# Play the cutscene
var player = AnimatedCutscenePlayer.new()
add_child(player)
await player.play_cutscene("MyMinigame", CutsceneTypes.CutsceneType.WIN)
player.queue_free()
```

## Best Practices

### 1. Synchronize with Animation

Match audio cue times with keyframe times for better synchronization:

```json
{
  "keyframes": [
    {"time": 0.0, "transforms": [...]},
    {"time": 0.5, "transforms": [...]}
  ],
  "audio_cues": [
    {"time": 0.0, "sound": "success"},
    {"time": 0.5, "sound": "water_splash"}
  ]
}
```

### 2. Use Contextually Appropriate Sounds

- **Win cutscenes**: Use success, bonus, water_splash
- **Fail cutscenes**: Use failure, damage, warning
- **Intro cutscenes**: Use whoosh, ready, game_start

### 3. Don't Overdo It

Limit audio cues to 2-3 per cutscene to avoid audio clutter:

```json
// Good - Clear and focused
"audio_cues": [
  {"time": 0.0, "sound": "success"},
  {"time": 0.5, "sound": "water_splash"}
]

// Bad - Too many sounds
"audio_cues": [
  {"time": 0.0, "sound": "success"},
  {"time": 0.2, "sound": "click"},
  {"time": 0.4, "sound": "bonus"},
  {"time": 0.6, "sound": "water_splash"},
  {"time": 0.8, "sound": "collect"}
]
```

### 4. Consider Timing

- Place first audio cue at `time: 0.0` for immediate feedback
- Space subsequent cues at least 0.3-0.5 seconds apart
- Align major audio cues with visual peaks (bounce, impact, etc.)

## Troubleshooting

### Audio Not Playing

1. **Check AudioManager**: Ensure AudioManager autoload is available
2. **Check Sound Name**: Verify the sound name is spelled correctly
3. **Check Timing**: Ensure audio cue time is within cutscene duration
4. **Check Volume**: Verify AudioManager volume settings are not muted

### Audio Out of Sync

1. **Frame Timing**: Audio timing is subject to frame rate variance
2. **Timer Precision**: Use `get_tree().create_timer()` for consistent timing
3. **Keyframe Alignment**: Align audio cue times with keyframe times

### Unknown Sound Warning

If you see a warning like:
```
[AnimatedCutscenePlayer] Unknown sound name: my_sound, attempting generic playback
```

This means the sound name is not recognized. Check the Available Sounds section and use a valid sound name.

## Technical Details

### How Audio Cues Work

1. **Parsing**: Audio cues are parsed from JSON configuration files by CutsceneParser
2. **Scheduling**: Each audio cue is scheduled using `get_tree().create_timer(audio.time)`
3. **Mapping**: Sound names are mapped to AudioManager methods in `_play_audio_by_name()`
4. **Playback**: AudioManager plays the sound using procedural audio generation

### Audio Timing

Audio cues use Godot's timer system for scheduling:

```gdscript
func _schedule_audio_cue(audio: CutsceneDataModels.AudioCue) -> void:
    await get_tree().create_timer(audio.time).timeout
    _play_audio_by_name(audio.sound)
```

This provides consistent timing across all cutscenes, independent of animation tweens.

### Sound Name Mapping

Sound names are mapped to AudioManager methods:

```gdscript
func _play_audio_by_name(sound_name: String) -> void:
    match sound_name.to_lower():
        "success", "success_chime", "chime":
            AudioManager.play_success()
        "water_splash", "splash":
            AudioManager.play_water_splash()
        # ... more mappings
```

## Related Documentation

- [AnimatedCutscenePlayer Usage](ANIMATED_CUTSCENE_PLAYER_USAGE.md)
- [Cutscene Parser Usage](CUTSCENE_PARSER_USAGE.md)
- [Task 8.1 Implementation Summary](TASK_8.1_IMPLEMENTATION_SUMMARY.md)

## Support

For questions or issues with audio cues:
1. Check this usage guide
2. Review the implementation summary
3. Examine the test suite in `test/AudioCueIntegrationTest.gd`
4. Check AudioManager documentation in `autoload/AudioManager.gd`
