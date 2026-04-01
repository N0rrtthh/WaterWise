# AnimationEngine Usage Guide

## Overview

The AnimationEngine provides static methods for applying transformations to Node2D objects over time using Godot's Tween system. It supports all easing functions required by the animated cutscene system.

## Features

- **7 Easing Functions**: linear, ease_in, ease_out, ease_in_out, bounce, elastic, back
- **3 Transform Types**: position, rotation, scale
- **Parallel Composition**: Apply multiple transforms simultaneously
- **Keyframe Sequences**: Animate through multiple keyframes with different easing
- **Relative/Absolute Transforms**: Support for both relative and absolute transformations

## Basic Usage

### Apply Single Transform

```gdscript
# Create a transform
var transform = CutsceneDataModels.Transform.new()
transform.type = CutsceneTypes.TransformType.POSITION
transform.value = Vector2(100, 50)
transform.relative = false  # Absolute position

# Apply to character
var tween = AnimationEngine.apply_transform(
    character,
    transform,
    1.0,  # Duration in seconds
    CutsceneTypes.Easing.EASE_OUT
)

# Wait for completion
await tween.finished
```

### Compose Multiple Transforms

Apply position, rotation, and scale simultaneously:

```gdscript
var transforms: Array[CutsceneDataModels.Transform] = []

# Position
var pos_transform = CutsceneDataModels.Transform.new()
pos_transform.type = CutsceneTypes.TransformType.POSITION
pos_transform.value = Vector2(200, 100)
transforms.append(pos_transform)

# Rotation
var rot_transform = CutsceneDataModels.Transform.new()
rot_transform.type = CutsceneTypes.TransformType.ROTATION
rot_transform.value = PI / 4  # 45 degrees
transforms.append(rot_transform)

# Scale
var scale_transform = CutsceneDataModels.Transform.new()
scale_transform.type = CutsceneTypes.TransformType.SCALE
scale_transform.value = Vector2(1.5, 1.5)
transforms.append(scale_transform)

# Apply all at once
var tween = AnimationEngine.compose_transforms(character, transforms, 1.0)
await tween.finished
```

### Animate Through Keyframes

Create a complete animation sequence:

```gdscript
var keyframes: Array[CutsceneDataModels.Keyframe] = []

# Keyframe 1: Pop in (time 0.0)
var kf1 = CutsceneDataModels.Keyframe.new(0.0)
var kf1_scale = CutsceneDataModels.Transform.new()
kf1_scale.type = CutsceneTypes.TransformType.SCALE
kf1_scale.value = Vector2(0.3, 0.3)
kf1.add_transform(kf1_scale)
kf1.easing = CutsceneTypes.Easing.EASE_OUT
keyframes.append(kf1)

# Keyframe 2: Bounce (time 0.5)
var kf2 = CutsceneDataModels.Keyframe.new(0.5)
var kf2_scale = CutsceneDataModels.Transform.new()
kf2_scale.type = CutsceneTypes.TransformType.SCALE
kf2_scale.value = Vector2(1.2, 1.2)
kf2.add_transform(kf2_scale)
kf2.easing = CutsceneTypes.Easing.BOUNCE
keyframes.append(kf2)

# Keyframe 3: Settle (time 1.0)
var kf3 = CutsceneDataModels.Keyframe.new(1.0)
var kf3_scale = CutsceneDataModels.Transform.new()
kf3_scale.type = CutsceneTypes.TransformType.SCALE
kf3_scale.value = Vector2(1.0, 1.0)
kf3.add_transform(kf3_scale)
kf3.easing = CutsceneTypes.Easing.EASE_IN_OUT
keyframes.append(kf3)

# Animate through all keyframes
var tween = AnimationEngine.animate(character, keyframes, 1.0)
await tween.finished
```

## Easing Functions

### Linear
Constant speed throughout the animation.
```gdscript
CutsceneTypes.Easing.LINEAR
```

### Ease In
Starts slow, accelerates toward the end.
```gdscript
CutsceneTypes.Easing.EASE_IN
```

### Ease Out
Starts fast, decelerates toward the end.
```gdscript
CutsceneTypes.Easing.EASE_OUT
```

### Ease In Out
Starts slow, speeds up in the middle, slows down at the end.
```gdscript
CutsceneTypes.Easing.EASE_IN_OUT
```

### Bounce
Creates a bouncing effect at the end of the animation.
```gdscript
CutsceneTypes.Easing.BOUNCE
```

### Elastic
Creates an elastic/spring effect.
```gdscript
CutsceneTypes.Easing.ELASTIC
```

### Back
Overshoots the target, then comes back.
```gdscript
CutsceneTypes.Easing.BACK
```

## Transform Types

### Position Transform
```gdscript
var transform = CutsceneDataModels.Transform.new()
transform.type = CutsceneTypes.TransformType.POSITION
transform.value = Vector2(100, 50)  # Target position
transform.relative = false  # false = absolute, true = relative to current
```

### Rotation Transform
```gdscript
var transform = CutsceneDataModels.Transform.new()
transform.type = CutsceneTypes.TransformType.ROTATION
transform.value = PI / 2  # Target rotation in radians
transform.relative = false  # false = absolute, true = relative to current
```

### Scale Transform
```gdscript
var transform = CutsceneDataModels.Transform.new()
transform.type = CutsceneTypes.TransformType.SCALE
transform.value = Vector2(2.0, 2.0)  # Target scale
transform.relative = false  # false = absolute, true = relative to current
```

## Relative vs Absolute Transforms

### Absolute Transform
Sets the property to an exact value:
```gdscript
transform.relative = false
transform.value = Vector2(100, 50)
# Result: position = (100, 50) regardless of current position
```

### Relative Transform
Adds to the current value:
```gdscript
transform.relative = true
transform.value = Vector2(50, 25)
# Result: position = current_position + (50, 25)
```

## Mathematical Easing Function

For advanced use cases, you can use the mathematical easing function directly:

```gdscript
# Get eased value for any t (0.0 to 1.0)
var t = 0.5  # Halfway through animation
var eased_t = AnimationEngine.apply_easing(t, CutsceneTypes.Easing.BOUNCE)

# Use for custom interpolation
var start_pos = Vector2(0, 0)
var end_pos = Vector2(100, 100)
var current_pos = start_pos.lerp(end_pos, eased_t)
```

## Complete Example: Win Cutscene Animation

```gdscript
func play_win_animation(character: WaterDropletCharacter) -> void:
    # Set happy expression
    character.set_expression(CutsceneTypes.Expression.HAPPY)
    
    # Create keyframe sequence
    var keyframes: Array[CutsceneDataModels.Keyframe] = []
    
    # Start small and above
    var kf1 = CutsceneDataModels.Keyframe.new(0.0)
    var kf1_scale = CutsceneDataModels.Transform.new()
    kf1_scale.type = CutsceneTypes.TransformType.SCALE
    kf1_scale.value = Vector2(0.3, 0.3)
    kf1.add_transform(kf1_scale)
    var kf1_pos = CutsceneDataModels.Transform.new()
    kf1_pos.type = CutsceneTypes.TransformType.POSITION
    kf1_pos.value = Vector2(0, -50)
    kf1_pos.relative = true
    kf1.add_transform(kf1_pos)
    kf1.easing = CutsceneTypes.Easing.EASE_OUT
    keyframes.append(kf1)
    
    # Pop in with bounce
    var kf2 = CutsceneDataModels.Keyframe.new(0.5)
    var kf2_scale = CutsceneDataModels.Transform.new()
    kf2_scale.type = CutsceneTypes.TransformType.SCALE
    kf2_scale.value = Vector2(1.2, 1.2)
    kf2.add_transform(kf2_scale)
    var kf2_rot = CutsceneDataModels.Transform.new()
    kf2_rot.type = CutsceneTypes.TransformType.ROTATION
    kf2_rot.value = 0.3
    kf2.add_transform(kf2_rot)
    kf2.easing = CutsceneTypes.Easing.BOUNCE
    keyframes.append(kf2)
    
    # Settle to normal
    var kf3 = CutsceneDataModels.Keyframe.new(1.5)
    var kf3_scale = CutsceneDataModels.Transform.new()
    kf3_scale.type = CutsceneTypes.TransformType.SCALE
    kf3_scale.value = Vector2(1.0, 1.0)
    kf3.add_transform(kf3_scale)
    var kf3_rot = CutsceneDataModels.Transform.new()
    kf3_rot.type = CutsceneTypes.TransformType.ROTATION
    kf3_rot.value = 0.0
    kf3.add_transform(kf3_rot)
    kf3.easing = CutsceneTypes.Easing.EASE_IN_OUT
    keyframes.append(kf3)
    
    # Animate
    var tween = AnimationEngine.animate(character, keyframes, 2.0)
    
    # Spawn particles at bounce
    await get_tree().create_timer(0.5).timeout
    character.spawn_particles(CutsceneTypes.ParticleType.SPARKLES, 1.5)
    
    # Wait for animation to complete
    await tween.finished
```

## Error Handling

The AnimationEngine handles errors gracefully:

- **Invalid target node**: Returns null, logs error
- **Empty transforms array**: Returns null, logs warning
- **Empty keyframes array**: Returns null, logs warning
- **Unknown easing type**: Falls back to LINEAR, logs warning

Always check if the returned tween is valid:

```gdscript
var tween = AnimationEngine.apply_transform(character, transform, 1.0, easing)
if tween:
    await tween.finished
else:
    push_error("Failed to create animation")
```

## Performance Tips

1. **Reuse Transforms**: Create transform objects once and reuse them
2. **Kill Unused Tweens**: Call `tween.kill()` if you need to stop an animation early
3. **Avoid Excessive Keyframes**: Keep keyframe count reasonable (< 20 per animation)
4. **Use Parallel Composition**: `compose_transforms` is more efficient than multiple `apply_transform` calls

## Integration with WaterDropletCharacter

The AnimationEngine works seamlessly with WaterDropletCharacter:

```gdscript
# Load character
var character_scene = load("res://scenes/cutscenes/WaterDropletCharacter.tscn")
var character = character_scene.instantiate()
add_child(character)

# Set expression
character.set_expression(CutsceneTypes.Expression.EXCITED)

# Animate with bounce
var transform = CutsceneDataModels.Transform.new()
transform.type = CutsceneTypes.TransformType.SCALE
transform.value = Vector2(1.5, 1.5)

var tween = AnimationEngine.apply_transform(
    character,
    transform,
    0.5,
    CutsceneTypes.Easing.BOUNCE
)

await tween.finished

# Spawn particles
character.spawn_particles(CutsceneTypes.ParticleType.SPARKLES, 1.0)
```

## Requirements Validated

- ✅ **Requirement 1.3**: Position transformations
- ✅ **Requirement 1.4**: Rotation transformations
- ✅ **Requirement 1.5**: Scale transformations
- ✅ **Requirement 1.6**: Layered animations (parallel composition)
- ✅ **Requirement 1.7**: Timing controls
- ✅ **Requirement 1.8**: Easing functions

## Next Steps

1. **Implement CutsceneParser (Task 4.1)**: Parse animation data from JSON files
2. **Implement AnimatedCutscenePlayer (Task 6.1)**: Orchestrate animations
3. **Create Default Animations (Task 12)**: Define win/fail/intro animation profiles
4. **Property Tests (Tasks 3.2-3.5)**: Validate animation properties

