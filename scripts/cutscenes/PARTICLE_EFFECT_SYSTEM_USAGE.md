# Particle Effect System Usage Guide

## Overview

The particle effect system provides contextual particle selection and adaptive density management for animated cutscenes. It automatically selects appropriate particle effects based on cutscene type and adjusts particle density based on performance.

## Components

### ParticleEffectManager

Static utility class that manages particle effect selection and optimization.

**Key Features:**
- Contextual particle selection (celebratory for wins, failure for fails)
- Water-themed minigame detection
- Adaptive particle density based on performance
- Integration with PerformanceManager

### Particle Scenes

Five particle effect scenes are available:

1. **Sparkles** - Celebratory golden sparkles (40 particles)
2. **Stars** - Celebratory stars with rotation (30 particles)
3. **Water Drops** - Water-themed droplets (55 particles)
4. **Smoke** - Failure smoke effect (25 particles)
5. **Splash** - One-shot water splash (50 particles)

All particle scenes are configured with:
- Fixed FPS (60) for consistent performance
- Appropriate colors and physics
- Optimized particle counts

## Usage Examples

### Basic Particle Selection

```gdscript
# Select appropriate particle for a win cutscene
var particle_type = ParticleEffectManager.select_contextual_particle(
    CutsceneTypes.CutsceneType.WIN,
    "CatchTheRain"
)
# Returns: SPARKLES or STARS (celebratory)

# Select appropriate particle for a fail cutscene
var particle_type = ParticleEffectManager.select_contextual_particle(
    CutsceneTypes.CutsceneType.FAIL,
    "FixLeak"
)
# Returns: SMOKE or SPLASH (failure)

# Select appropriate particle for a water-themed intro
var particle_type = ParticleEffectManager.select_contextual_particle(
    CutsceneTypes.CutsceneType.INTRO,
    "CatchTheRain"
)
# Returns: WATER_DROPS or SPLASH (water-themed)
```

### Creating Particle Effects

```gdscript
# Create a default particle effect for a cutscene
var particle = ParticleEffectManager.create_default_particle_effect(
    CutsceneTypes.CutsceneType.WIN,
    "CatchTheRain",
    0.5,  # time (seconds)
    1.5   # duration (seconds)
)

# Add to cutscene config
config.add_particle(particle)
```

### Adaptive Density

```gdscript
# Spawn particles with adaptive density
var particles = character.spawn_particles(
    CutsceneTypes.ParticleType.SPARKLES,
    1.0
)

# Apply adaptive density based on current performance
ParticleEffectManager.apply_adaptive_density(particles)
# Automatically reduces particle count if:
# - Memory usage > 80%
# - FPS < 45
```

### Manual Density Control

```gdscript
# Get current density factor
var density = ParticleEffectManager.get_adaptive_density_factor()
# Returns: 1.0 (normal), 0.6 (reduced), or 0.3 (minimal)

# Manually reduce particles
PerformanceManager.reduce_particles(particles, 0.5)  # 50% reduction
```

## Contextual Selection Rules

### Win Cutscenes
- **Particle Types:** Sparkles, Stars
- **Purpose:** Celebratory effects
- **Behavior:** Random selection between celebratory types

### Fail Cutscenes
- **Particle Types:** Smoke, Splash
- **Purpose:** Failure indication
- **Behavior:** Random selection between failure types

### Intro Cutscenes
- **Water-themed minigames:** Water Drops, Splash
- **Other minigames:** No particles (clean intro)
- **Detection:** Checks for keywords: Rain, Leak, Tap, Water, Pipe, Shower, Aquarium

## Performance Optimization

### Adaptive Density Thresholds

```gdscript
# Memory threshold
MEMORY_THRESHOLD_HIGH = 0.8  # 80% memory usage

# FPS threshold
FPS_THRESHOLD_LOW = 45  # Below 45 FPS

# Density factors
DENSITY_NORMAL = 1.0    # Full particle count
DENSITY_REDUCED = 0.6   # 60% of particles
DENSITY_MINIMAL = 0.3   # 30% of particles
```

### Automatic Optimization

The system automatically:
1. Monitors memory usage and FPS
2. Reduces particle density when performance is poor
3. Maintains visual quality when performance is good
4. Integrates with PerformanceManager for consistent optimization

## Integration with AnimatedCutscenePlayer

The AnimatedCutscenePlayer automatically uses ParticleEffectManager:

```gdscript
# In AnimatedCutscenePlayer._schedule_particle_effect()
func _schedule_particle_effect(particle: CutsceneDataModels.ParticleEffect) -> void:
    await get_tree().create_timer(particle.time).timeout
    
    if is_instance_valid(_current_character):
        var particle_node = _current_character.spawn_particles(
            particle.type,
            particle.duration
        )
        
        # Adaptive density is applied automatically
        if particle_node and particle_node is GPUParticles2D:
            ParticleEffectManager.apply_adaptive_density(particle_node)
```

## Water-Themed Minigame Detection

The system automatically detects water-themed minigames:

```gdscript
# Detected as water-themed:
- CatchTheRain
- FixLeak
- WaterPlant
- QuickShower
- FillAquarium
- CollectShowerWater
- CatchRainAquarium

# Not detected as water-themed:
- FilterBuilder
- MudPieMaker
- SpotTheSpeck
```

## Particle Scene Configuration

All particle scenes follow this structure:

```gdscript
[node name="ParticleName" type="GPUParticles2D"]
amount = 40                    # Particle count
lifetime = 1.2                 # Particle lifetime
one_shot = false               # Continuous emission
explosiveness = 0.3            # Emission pattern
randomness = 0.6               # Variation
fixed_fps = 60                 # Consistent performance

[sub_resource type="ParticleProcessMaterial"]
emission_shape = 1             # Sphere
emission_sphere_radius = 40.0  # Spawn area
direction = Vector3(0, -1, 0)  # Movement direction
spread = 60.0                  # Angle spread
gravity = Vector3(0, -30, 0)   # Gravity effect
initial_velocity_min = 60.0    # Speed range
initial_velocity_max = 120.0
scale_min = 0.6                # Size range
scale_max = 1.8
color = Color(1, 0.95, 0.4, 1) # Particle color
```

## Best Practices

1. **Use Contextual Selection:** Let ParticleEffectManager choose appropriate particles
2. **Enable Adaptive Density:** Always apply adaptive density for performance
3. **Test on Low-End Devices:** Verify particle effects work on target hardware
4. **Monitor Performance:** Check FPS and memory usage with particles active
5. **Use Fixed FPS:** All particle scenes should have fixed_fps set
6. **Limit Particle Count:** Keep particle amounts reasonable (20-60 particles)
7. **One-Shot for Bursts:** Use one_shot=true for splash/impact effects

## Troubleshooting

### Particles Not Appearing
- Check that particle scene path exists
- Verify particle_container exists in WaterDropletCharacter
- Ensure particles.emitting is true

### Poor Performance
- Reduce particle amounts in scene files
- Lower fixed_fps from 60 to 30
- Increase adaptive density thresholds
- Disable expensive particle features (turbulence, collision)

### Wrong Particle Type
- Verify cutscene_type is correct
- Check minigame_key for water-themed detection
- Review contextual selection logic

## Requirements Validated

This system validates the following requirements:

- **7.1:** Particle effect support (sparkles, water drops, stars, smoke, splash)
- **7.4:** Contextual particle selection (celebratory for win, failure for fail)
- **7.5:** Themed visual effects for water-related minigames
- **9.5:** Adaptive particle density based on performance

## See Also

- `WaterDropletCharacter.gd` - Character particle spawning
- `AnimatedCutscenePlayer.gd` - Cutscene orchestration
- `PerformanceManager.gd` - Performance optimization utilities
- `CutsceneDataModels.gd` - Particle effect data structures
