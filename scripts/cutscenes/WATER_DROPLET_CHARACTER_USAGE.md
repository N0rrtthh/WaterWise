# WaterDropletCharacter Usage Guide

## Overview

The WaterDropletCharacter is the animated mascot used in all cutscenes. It supports expressions, body deformation, and particle effects.

## Quick Start

### Loading the Character

```gdscript
# Load the character scene
var character_scene = load("res://scenes/cutscenes/WaterDropletCharacter.tscn")
var character = character_scene.instantiate()
add_child(character)

# Position the character
character.position = Vector2(640, 360)
character.scale = Vector2(2.0, 2.0)  # Make it bigger
```

### Changing Expressions

```gdscript
# Set expression
character.set_expression(CutsceneTypes.Expression.HAPPY)

# Get current expression
var current = character.get_expression()

# Listen for expression changes
character.expression_changed.connect(_on_expression_changed)

func _on_expression_changed(new_expression: CutsceneTypes.Expression):
    print("Expression changed to: ", new_expression)
```

### Available Expressions

- `CutsceneTypes.Expression.HAPPY` - Smiling, cheerful
- `CutsceneTypes.Expression.SAD` - Downturned mouth, droopy eyes
- `CutsceneTypes.Expression.SURPRISED` - Wide eyes and mouth
- `CutsceneTypes.Expression.DETERMINED` - Focused, concentrated (default)
- `CutsceneTypes.Expression.WORRIED` - Nervous, uncertain
- `CutsceneTypes.Expression.EXCITED` - Wide smile, sparkling eyes

### Body Deformation

```gdscript
# Enable/disable deformation
character.set_deformation_enabled(true)

# Apply squash (compress vertically)
character.apply_squash_stretch(0.5, 1.0)

# Apply stretch (extend vertically)
character.apply_squash_stretch(1.0, 1.5)

# Combined squash and stretch
character.apply_squash_stretch(0.8, 1.2)

# Reset to normal
character.set_deformation_enabled(false)  # Resets scale
```

#### Deformation Parameters

- **squash**: Vertical compression factor
  - `1.0` = normal height
  - `0.5` = half height (squashed)
  - `2.0` = double height (stretched)

- **stretch**: Vertical extension factor
  - `1.0` = normal height
  - `1.5` = 1.5x height (stretched)
  - `0.5` = half height (compressed)

The horizontal scale automatically adjusts to preserve visual volume.

### Spawning Particles

```gdscript
# Spawn particles that emit for 2 seconds
character.spawn_particles(CutsceneTypes.ParticleType.SPARKLES, 2.0)

# Spawn one-shot particles (instant burst)
character.spawn_particles(CutsceneTypes.ParticleType.SPLASH, 0.0)

# Get reference to spawned particles
var particles = character.spawn_particles(CutsceneTypes.ParticleType.STARS, 1.5)
if particles:
    # Modify particle properties
    particles.modulate = Color.RED
```

#### Available Particle Types

- `SPARKLES` - Celebratory sparkles (upward, yellow)
- `WATER_DROPS` - Water droplets (downward, blue)
- `STARS` - Star particles (upward, yellow-white)
- `SMOKE` - Smoke puffs (upward, gray)
- `SPLASH` - Water splash (outward burst, blue)

### Resetting the Character

```gdscript
# Reset to default state
character.reset()

# This will:
# - Set expression to DETERMINED
# - Reset position to (0, 0)
# - Reset rotation to 0
# - Reset scale to base_scale
# - Clear all active particles
```

## Animation Integration

The character is designed to work with the AnimationEngine:

```gdscript
# Example: Bounce animation with expression change
character.set_expression(CutsceneTypes.Expression.EXCITED)

# Animate position
var tween = create_tween()
tween.tween_property(character, "position", Vector2(640, 300), 0.3)
tween.tween_property(character, "position", Vector2(640, 360), 0.2)

# Apply squash on landing
await tween.finished
character.apply_squash_stretch(0.7, 1.0)
await get_tree().create_timer(0.1).timeout
character.apply_squash_stretch(1.0, 1.0)

# Spawn celebration particles
character.spawn_particles(CutsceneTypes.ParticleType.SPARKLES, 1.5)
```

## Common Patterns

### Win Cutscene

```gdscript
func play_win_cutscene():
    character.set_expression(CutsceneTypes.Expression.EXCITED)
    
    # Pop in animation
    character.scale = Vector2(0.3, 0.3)
    var tween = create_tween()
    tween.tween_property(character, "scale", Vector2(2.5, 2.5), 0.3)
    tween.tween_property(character, "scale", Vector2(2.0, 2.0), 0.2)
    
    # Spawn particles
    await get_tree().create_timer(0.3).timeout
    character.spawn_particles(CutsceneTypes.ParticleType.SPARKLES, 2.0)
    
    # Change to happy
    await get_tree().create_timer(0.5).timeout
    character.set_expression(CutsceneTypes.Expression.HAPPY)
```

### Fail Cutscene

```gdscript
func play_fail_cutscene():
    character.set_expression(CutsceneTypes.Expression.WORRIED)
    
    # Drop from above
    character.position.y = -100
    var tween = create_tween()
    tween.tween_property(character, "position:y", 360, 0.5)
    
    # Impact squash
    await tween.finished
    character.apply_squash_stretch(0.6, 1.0)
    character.spawn_particles(CutsceneTypes.ParticleType.SMOKE, 1.0)
    
    # Wobble and recover
    await get_tree().create_timer(0.1).timeout
    character.apply_squash_stretch(1.0, 1.2)
    await get_tree().create_timer(0.1).timeout
    character.apply_squash_stretch(1.0, 1.0)
    
    # Change to sad
    character.set_expression(CutsceneTypes.Expression.SAD)
```

### Intro Cutscene

```gdscript
func play_intro_cutscene():
    character.set_expression(CutsceneTypes.Expression.DETERMINED)
    
    # Slide in from left
    character.position.x = -100
    var tween = create_tween()
    tween.tween_property(character, "position:x", 640, 0.8)
    tween.set_ease(Tween.EASE_OUT)
    tween.set_trans(Tween.TRANS_BACK)
    
    # Slight bounce on arrival
    await tween.finished
    character.apply_squash_stretch(1.0, 1.1)
    await get_tree().create_timer(0.1).timeout
    character.apply_squash_stretch(1.0, 1.0)
```

## Testing

### Interactive Demo

Run the demo scene to test the character interactively:

```
res://scenes/cutscenes/WaterDropletCharacterDemo.tscn
```

Controls:
- `1-6`: Change expression
- `Q`: Apply squash
- `W`: Apply stretch
- `E`: Reset character
- `Space`: Spawn particles (cycles through types)

### Unit Tests

Run the unit tests:

```
res://test/WaterDropletCharacterTest.gd
```

## Asset Requirements

The character requires these assets to display properly:

### Required Files
- `res://assets/characters/droplet_base.png` - Base body sprite
- `res://assets/characters/expressions/happy.png`
- `res://assets/characters/expressions/sad.png`
- `res://assets/characters/expressions/surprised.png`
- `res://assets/characters/expressions/determined.png`
- `res://assets/characters/expressions/worried.png`
- `res://assets/characters/expressions/excited.png`

### Generating Placeholders

If assets don't exist, run the placeholder generator:

1. Open Godot editor
2. Go to File > Run
3. Select `res://scripts/cutscenes/generate_placeholder_assets.gd`
4. Click Run

This will create simple placeholder sprites for testing.

## Troubleshooting

### Expression texture not found warning

```
[WaterDropletCharacter] Expression texture not found: res://assets/characters/expressions/happy.png
```

**Solution**: Create the expression textures or run the placeholder generator script.

### Particle scene not found warning

```
[WaterDropletCharacter] Particle scene not found: res://scenes/particles/Sparkles.tscn
```

**Solution**: The particle scenes should already exist. Check that they're in the correct location.

### Deformation not working

**Check**:
1. Is deformation enabled? `character.deformation_enabled == true`
2. Are you applying reasonable values? (0.3 to 2.5 range)
3. Is something else modifying the scale?

### Particles not appearing

**Check**:
1. Is the particle container visible? `character.particle_container.visible == true`
2. Are the particle scenes valid?
3. Is the duration > 0 for continuous emission?

## Performance Tips

1. **Reuse character instances** - Don't create/destroy for every cutscene
2. **Limit active particles** - Only spawn particles when needed
3. **Use one-shot particles** - For instant effects, use duration = 0
4. **Reset after use** - Always call `reset()` after cutscene completion

## Next Steps

- Integrate with AnimationEngine (Task 3)
- Create custom character sprites
- Add more particle effects
- Implement expression transition animations
