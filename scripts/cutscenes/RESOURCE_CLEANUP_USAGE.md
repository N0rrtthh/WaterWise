# Resource Cleanup System Usage Guide

## Overview

Task 9.2 implements a comprehensive resource cleanup system for the animated cutscene player. This system ensures that all temporary resources (tweens, particles, nodes) are properly freed after cutscene playback, preventing memory leaks and improving performance.

## Features

### 1. Automatic Resource Cleanup

The `AnimatedCutscenePlayer` automatically cleans up all resources after each cutscene:

- **Tweens**: All active tweens are killed and freed
- **Particles**: Particle effects are stopped and returned to object pool
- **Text Overlays**: Temporary text overlay nodes are removed
- **Character**: The character node is freed
- **Timers**: References to scheduled timers are cleared

```gdscript
# Cleanup happens automatically after cutscene completion
await cutscene_player.play_cutscene("CatchTheRain", CutsceneTypes.CutsceneType.WIN)
# All resources are now cleaned up
```

### 2. Object Pooling for Particles

Particle effects are reused through an object pool to reduce allocation overhead:

```gdscript
# Get a particle from the pool (creates new if pool is empty)
var particle = AnimatedCutscenePlayer._get_pooled_particle(CutsceneTypes.ParticleType.SPARKLES)

# Use the particle...
particle.emitting = true

# Return to pool for reuse
AnimatedCutscenePlayer._return_pooled_particle(particle, CutsceneTypes.ParticleType.SPARKLES)
```

**Pool Configuration**:
- Maximum 5 particles per type in the pool
- Particles beyond the limit are freed instead of pooled
- Pooled particles have their state reset before reuse

### 3. Memory Monitoring

The system monitors memory usage and automatically clears caches when memory is high:

```gdscript
# Get current memory statistics
var stats = AnimatedCutscenePlayer.get_memory_stats()
print("Memory usage: %.1f%%" % (stats["memory_ratio"] * 100))
print("Cached animations: %d" % stats["cached_animations"])
print("Pooled particles: %d" % stats["pooled_particles"])
```

**Memory Statistics**:
- `static_memory_mb`: Current memory usage in MB
- `peak_memory_mb`: Peak memory usage in MB
- `memory_ratio`: Memory usage as ratio (0.0 to 1.0)
- `cached_animations`: Number of cached animation configs
- `cached_textures`: Number of cached textures
- `cached_particle_scenes`: Number of cached particle scenes
- `pooled_particles`: Total particles in all pools

### 4. Adaptive Quality Reduction

When memory usage exceeds 80%, the system automatically:
- Clears animation configuration cache
- Clears texture cache
- Clears particle scene cache
- Frees all pooled particles

```gdscript
# This happens automatically during cleanup
# But you can also manually trigger it:
AnimatedCutscenePlayer.clear_caches()
```

### 5. Manual Cache Management

You can manually clear caches when needed:

```gdscript
# Clear all caches and free pooled particles
AnimatedCutscenePlayer.clear_caches()

# This is useful:
# - Before loading a new level
# - After completing a game session
# - When memory usage is high
```

## Implementation Details

### Cleanup Process

The `_cleanup_cutscene()` method performs cleanup in this order:

1. **Kill Tweens**: Stop and free all animation tweens
2. **Stop Particles**: Stop emission and return to pool
3. **Remove Overlays**: Free all text overlay nodes
4. **Clear Timers**: Clear scheduled timer references
5. **Free Character**: Remove and free the character node
6. **Check Memory**: If memory > 80%, clear all caches

### Object Pool Management

The object pool uses a dictionary structure:

```gdscript
_particle_pool = {
    ParticleType.SPARKLES: [particle1, particle2, ...],
    ParticleType.WATER_DROPS: [particle3, particle4, ...],
    ...
}
```

**Pool Operations**:
- `_get_pooled_particle()`: Get from pool or create new
- `_return_pooled_particle()`: Return to pool or free if full
- Pool size limited to `MAX_POOL_SIZE_PER_TYPE` (5) per type

### Memory Monitoring

Memory monitoring uses `ParticleEffectManager._get_memory_usage_ratio()`:

```gdscript
var memory_ratio = OS.get_static_memory_usage() / OS.get_static_memory_peak_usage()
if memory_ratio > 0.8:
    # High memory usage - clear caches
    clear_caches()
```

## Performance Benefits

### Before Resource Cleanup System

- Memory leaks from unreleased tweens
- Particle nodes accumulating in scene tree
- Texture cache growing unbounded
- Performance degradation over time

### After Resource Cleanup System

- All resources properly freed after use
- Particle reuse reduces allocation overhead
- Memory usage stays bounded
- Consistent performance across sessions

## Best Practices

### 1. Let Automatic Cleanup Handle Resources

Don't manually free resources - let the cleanup system handle it:

```gdscript
# ❌ DON'T DO THIS
await cutscene_player.play_cutscene("CatchTheRain", CutsceneTypes.CutsceneType.WIN)
cutscene_player._current_character.queue_free()  # Already freed by cleanup!

# ✅ DO THIS
await cutscene_player.play_cutscene("CatchTheRain", CutsceneTypes.CutsceneType.WIN)
# Cleanup happens automatically
```

### 2. Clear Caches at Scene Transitions

Clear caches when transitioning between major scenes:

```gdscript
func _on_level_complete():
    # Clear cutscene caches before loading next level
    AnimatedCutscenePlayer.clear_caches()
    get_tree().change_scene_to_file("res://scenes/NextLevel.tscn")
```

### 3. Monitor Memory in Development

Use memory stats during development to identify issues:

```gdscript
func _ready():
    if OS.is_debug_build():
        # Print memory stats every 5 seconds
        var timer = Timer.new()
        add_child(timer)
        timer.timeout.connect(_print_memory_stats)
        timer.start(5.0)

func _print_memory_stats():
    var stats = AnimatedCutscenePlayer.get_memory_stats()
    print("Cutscene Memory: %.1f MB (%.1f%%)" % [
        stats["static_memory_mb"],
        stats["memory_ratio"] * 100
    ])
```

### 4. Preload Assets at Game Start

Preload cutscene assets during initialization to avoid loading delays:

```gdscript
func _ready():
    # Preload all minigame cutscenes
    var minigames = ["CatchTheRain", "FixLeak", "WaterPlant"]
    for key in minigames:
        AnimatedCutscenePlayer.preload_cutscene(key)
```

## Testing

The resource cleanup system includes comprehensive tests in `test/ResourceCleanupTest.gd`:

- **Cleanup Tests**: Verify all resources are freed
- **Memory Tests**: Verify memory monitoring works
- **Pooling Tests**: Verify object pool reuses instances
- **Adaptive Tests**: Verify quality reduction on low performance

Run tests with:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/ResourceCleanupTest.gd
```

## Requirements Validation

This implementation satisfies:

- **Requirement 9.5**: Adaptive particle density based on memory usage
- **Requirement 9.6**: Resource cleanup after cutscene completion

The system ensures:
- ✅ All tweens are killed and freed
- ✅ All particles are stopped and pooled/freed
- ✅ All temporary nodes are removed
- ✅ Memory is monitored and caches cleared when high
- ✅ Object pooling reduces allocation overhead
- ✅ Performance remains consistent over time

## Troubleshooting

### High Memory Usage

If memory usage remains high after cleanup:

1. Check for external references to cutscene resources
2. Verify particles are being returned to pool correctly
3. Manually clear caches: `AnimatedCutscenePlayer.clear_caches()`

### Particles Not Reusing

If particles aren't being reused from pool:

1. Check particle type identification in `_identify_particle_type()`
2. Verify particle scene paths match `WaterDropletCharacter.PARTICLE_SCENES`
3. Check pool isn't full (max 5 per type)

### Memory Stats Showing Zero

If memory stats show zero or invalid values:

1. Verify `OS.get_static_memory_usage()` is supported on your platform
2. Check `ParticleEffectManager._get_memory_usage_ratio()` implementation
3. Use alternative memory monitoring if needed

## Future Enhancements

Potential improvements for the resource cleanup system:

1. **Configurable Pool Sizes**: Allow adjusting `MAX_POOL_SIZE_PER_TYPE` per game
2. **Memory Pressure Callbacks**: Notify game when memory is high
3. **Resource Usage Profiling**: Track which cutscenes use most resources
4. **Automatic Pool Warming**: Pre-populate pools at game start
5. **Cache Eviction Policies**: LRU cache for animation configs
