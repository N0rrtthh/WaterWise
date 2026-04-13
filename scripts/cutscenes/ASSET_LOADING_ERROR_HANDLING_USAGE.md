# Asset Loading Error Handling Usage Guide

## Overview

The animated cutscene system implements comprehensive error handling for asset loading failures, ensuring that game progression is never blocked by missing or corrupted assets. This guide explains how the system handles various asset loading failures and provides examples of the fallback mechanisms.

## Error Handling Features

### 1. Character Asset Load Failure (Requirement 12.2)

**Behavior**: If the character scene fails to load, the system automatically falls back to a legacy emoji-based cutscene.

**Example**:
```gdscript
# In your game code
var cutscene_player = AnimatedCutscenePlayer.new()
hud_layer.add_child(cutscene_player)

# Even if character assets are missing, this will complete successfully
await cutscene_player.play_cutscene("CatchTheRain", CutsceneTypes.CutsceneType.WIN)

# The cutscene will either show:
# 1. Full animated character (if assets available)
# 2. Legacy emoji cutscene (if character assets missing)
```

**Fallback Display**:
- **WIN**: "🎉 Success! 💧"
- **FAIL**: "💦 Try Again! 💧"
- **INTRO**: "💧 Ready! 💧"

### 2. Missing Particle Textures (Requirement 12.4)

**Behavior**: If particle textures or scenes are missing, the system skips the particle effects and continues the cutscene without them.

**Example**:
```gdscript
# Configuration includes particles
var config = {
    "particles": [
        {
            "time": 0.5,
            "type": "sparkles",
            "duration": 1.0
        }
    ]
}

# If sparkles.tscn is missing:
# - Warning is logged: "Skipping particle effect due to missing texture/scene"
# - Cutscene continues without particles
# - No crash or blocking
```

**Error Messages**:
```
[AnimatedCutscenePlayer] Skipping particle effect due to missing texture/scene: SPARKLES. 
Continuing cutscene without particles.
```

### 3. Audio File Failure (Requirement 12.4)

**Behavior**: If audio files fail to load or AudioManager is unavailable, the system plays the cutscene without audio.

**Example**:
```gdscript
# Configuration includes audio cues
var config = {
    "audio_cues": [
        {
            "time": 0.0,
            "sound": "success_chime"
        }
    ]
}

# If AudioManager is unavailable or audio file is missing:
# - Warning is logged
# - Cutscene continues silently
# - No crash or blocking
```

**Error Messages**:
```
[AnimatedCutscenePlayer] AudioManager not available, skipping audio cue: success_chime. 
Continuing cutscene without audio.
```

## Error Handling Hierarchy

The system follows a fallback hierarchy to ensure cutscenes always complete:

```
1. Full animated cutscene with all assets
   ↓ (if character assets fail)
2. Legacy emoji-based cutscene
   ↓ (if emoji display fails)
3. Skip cutscene entirely, continue game
```

For individual asset types:

```
Particles:
1. Load particle scene from cache
   ↓ (if missing)
2. Try to load from disk
   ↓ (if fails)
3. Skip particle effect, continue cutscene

Audio:
1. Play audio through AudioManager
   ↓ (if AudioManager unavailable)
2. Check if method exists
   ↓ (if method missing)
3. Skip audio, continue cutscene silently
```

## Testing Asset Loading Errors

### Manual Testing

To test asset loading error handling manually:

1. **Test Character Asset Failure**:
   - Temporarily rename `res://scenes/cutscenes/WaterDropletCharacter.tscn`
   - Play any cutscene
   - Verify emoji fallback appears
   - Restore the file

2. **Test Particle Texture Failure**:
   - Temporarily rename a particle scene (e.g., `res://scenes/particles/Sparkles.tscn`)
   - Play a cutscene that uses that particle
   - Verify cutscene continues without particles
   - Check console for warning message
   - Restore the file

3. **Test Audio Failure**:
   - Temporarily disable AudioManager autoload
   - Play any cutscene
   - Verify cutscene plays silently
   - Check console for warning message
   - Re-enable AudioManager

### Automated Testing

Run the automated test suite:

```gdscript
# Open in Godot Editor
test/AssetLoadingErrorHandlingTest.tscn

# Press F6 to run tests
```

Tests validate:
- Character asset failure fallback
- Particle texture missing graceful degradation
- Audio file failure handling
- Multiple asset failures don't block progression

## Error Logging

All asset loading errors are logged with descriptive messages:

### Character Asset Errors
```
[AnimatedCutscenePlayer] Character scene not found at: res://scenes/cutscenes/WaterDropletCharacter.tscn. 
Will fall back to legacy emoji cutscenes.

[AnimatedCutscenePlayer] Character assets not available for CatchTheRain (type: win). 
Falling back to legacy emoji cutscene.
```

### Particle Asset Errors
```
[WaterDropletCharacter] Particle scene not found: res://scenes/particles/Sparkles.tscn. 
Skipping particle effect (Requirement 12.4: graceful degradation for missing particle textures).

[AnimatedCutscenePlayer] Skipping particle effect due to missing texture/scene: SPARKLES. 
Continuing cutscene without particles.
```

### Audio Asset Errors
```
[AnimatedCutscenePlayer] AudioManager not available, skipping audio cue: success_chime. 
Continuing cutscene without audio.

[AnimatedCutscenePlayer] AudioManager.play_success() not available

[AnimatedCutscenePlayer] Unknown sound name: invalid_sound. 
Skipping audio playback and continuing cutscene.
```

## Best Practices

### 1. Always Provide Default Assets

While the system handles missing assets gracefully, it's best to provide default assets:

```
res://data/cutscenes/default/
├── intro.json
├── win.json
└── fail.json
```

### 2. Test Asset Loading During Development

Regularly test with missing assets to ensure fallbacks work:

```gdscript
# Add to your test suite
func test_asset_loading_resilience():
    # Test with various missing assets
    for minigame in all_minigames:
        await cutscene_player.play_cutscene(minigame, CutsceneTypes.CutsceneType.WIN)
        assert_true(cutscene_completed, "Cutscene should complete")
```

### 3. Monitor Error Logs

Check console output for asset loading warnings during development:

```gdscript
# Enable verbose logging
push_info("[YourGame] Testing cutscene asset loading...")
await cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
# Check console for any warnings
```

### 4. Preload Critical Assets

Preload cutscene assets during game initialization to catch missing assets early:

```gdscript
# In GameManager._ready()
func _preload_cutscene_assets():
    var critical_minigames = ["CatchTheRain", "FixLeak", "WaterPlant"]
    for minigame in critical_minigames:
        AnimatedCutscenePlayer.preload_cutscene(minigame)
        # Check for any errors in console
```

## Integration with Existing Systems

### MiniGameBase Integration

The error handling is transparent to MiniGameBase:

```gdscript
# In MiniGameBase.gd
func _show_success_micro_cutscene() -> void:
    var cutscene_player = AnimatedCutscenePlayer.new()
    hud_layer.add_child(cutscene_player)
    
    # This will always complete, even with missing assets
    await cutscene_player.play_cutscene(
        _get_minigame_key(),
        CutsceneTypes.CutsceneType.WIN
    )
    
    cutscene_player.queue_free()
    # Game continues normally
```

### AudioManager Integration

Audio errors don't affect cutscene playback:

```gdscript
# Even if AudioManager is missing or audio files are unavailable,
# cutscenes will play silently without blocking
await cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
```

## Performance Considerations

### Memory Management

Asset loading errors don't cause memory leaks:

```gdscript
# Failed asset loads are cleaned up automatically
# No manual cleanup required
await cutscene_player.play_cutscene("TestMinigame", CutsceneTypes.CutsceneType.WIN)
# All resources freed, even if some assets failed to load
```

### Loading Time

Failed asset loads fail fast:

```gdscript
# ResourceLoader.exists() checks are fast (< 1ms)
# Failed loads don't cause long delays
# Fallback to emoji cutscene is immediate
```

## Troubleshooting

### Issue: Cutscene shows emoji instead of animation

**Cause**: Character scene failed to load

**Solution**:
1. Check if `res://scenes/cutscenes/WaterDropletCharacter.tscn` exists
2. Verify the scene is properly configured
3. Check console for error messages
4. Ensure the scene is included in export settings

### Issue: Cutscene plays without particles

**Cause**: Particle scenes failed to load

**Solution**:
1. Check if particle scenes exist in `res://scenes/particles/`
2. Verify scene paths in `WaterDropletCharacter.PARTICLE_SCENES`
3. Check console for warning messages
4. Ensure particle scenes are included in export settings

### Issue: Cutscene plays without audio

**Cause**: AudioManager unavailable or audio files missing

**Solution**:
1. Verify AudioManager is configured as autoload
2. Check if AudioManager methods exist
3. Verify audio files are present
4. Check console for warning messages

## Related Documentation

- [Animated Cutscene Player Usage](ANIMATED_CUTSCENE_PLAYER_USAGE.md)
- [Configuration Error Handling](TASK_11.1_IMPLEMENTATION_SUMMARY.md)
- [Resource Cleanup Usage](RESOURCE_CLEANUP_USAGE.md)
- [Asset Preloading Usage](ASSET_PRELOADING_USAGE.md)

## Requirements Validated

This implementation validates:
- **Requirement 12.2**: Fallback to legacy emoji cutscenes on asset load failure
- **Requirement 12.4**: Graceful degradation for missing particle textures
- **Requirement 12.4**: Audio file failure handling (play without audio)
- **Requirement 12.4**: Game progression never blocks on cutscene errors
