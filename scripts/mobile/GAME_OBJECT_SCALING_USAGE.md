# Game Object Scaling Usage Guide

## Overview

The `apply_game_object_scaling()` method in MobileUIManager provides automatic scaling for game objects (Node2D) on mobile platforms. This ensures interactive elements are large enough for touch input while maintaining gameplay balance.

## Basic Usage

```gdscript
# In your game scene's _ready() function
func _ready():
    # Scale a game object for mobile
    MobileUIManager.apply_game_object_scaling(my_game_object)
```

## Scaling Rules

### Interactive Objects (1.4x)
By default, all Node2D objects are scaled by 1.4x on mobile platforms.

```gdscript
var player = Node2D.new()
player.name = "Player"
MobileUIManager.apply_game_object_scaling(player)
# Result: player.scale = Vector2(1.4, 1.4)
```

### Collectibles (1.3x)
Objects identified as collectibles are scaled by 1.3x. An object is considered a collectible if:
- Its name contains: "collectible", "drop", "coin", or "item" (case-insensitive)
- It belongs to the "collectibles" group

```gdscript
var water_drop = Node2D.new()
water_drop.name = "WaterDrop"
MobileUIManager.apply_game_object_scaling(water_drop)
# Result: water_drop.scale = Vector2(1.3, 1.3)

# Or using groups
var coin = Node2D.new()
coin.add_to_group("collectibles")
MobileUIManager.apply_game_object_scaling(coin)
# Result: coin.scale = Vector2(1.3, 1.3)
```

### Draggable Objects (Minimum 120x120px)
Objects identified as draggable have additional size enforcement. An object is considered draggable if:
- Its name contains "drag" (case-insensitive)
- It belongs to the "draggable" group
- It has `input_pickable = true`

The method ensures the effective size is at least 120x120 pixels after scaling.

```gdscript
var draggable_item = Node2D.new()
draggable_item.name = "DraggableBox"
draggable_item.input_pickable = true

# Add collision shape (50x50 - too small)
var collision = CollisionShape2D.new()
var shape = RectangleShape2D.new()
shape.size = Vector2(50, 50)
collision.shape = shape
draggable_item.add_child(collision)

MobileUIManager.apply_game_object_scaling(draggable_item)
# Result: Scaled beyond 1.4x to meet 120x120 minimum
# Effective size: shape.size * draggable_item.scale >= Vector2(120, 120)
```

## Collision Shape Preservation

Collision shapes are automatically scaled with their parent Node2D in Godot. The method preserves the shape's properties while the effective collision area scales with the node.

```gdscript
var enemy = Node2D.new()
var collision = CollisionShape2D.new()
var shape = CircleShape2D.new()
shape.radius = 20.0
collision.shape = shape
enemy.add_child(collision)

MobileUIManager.apply_game_object_scaling(enemy)

# Shape properties unchanged
print(shape.radius)  # Still 20.0

# But effective collision is scaled
var effective_radius = shape.radius * enemy.scale.x  # 20.0 * 1.4 = 28.0
```

## Aspect Ratio Preservation

The method preserves the original aspect ratio of objects, even if they have non-uniform scaling.

```gdscript
var stretched_object = Node2D.new()
stretched_object.scale = Vector2(2.0, 1.0)  # 2:1 aspect ratio

MobileUIManager.apply_game_object_scaling(stretched_object)

# Result: stretched_object.scale = Vector2(2.8, 1.4)
# Aspect ratio preserved: 2.8 / 1.4 = 2.0
```

## Desktop Behavior

On desktop platforms (or when mobile mode is disabled), the method does nothing.

```gdscript
MobileUIManager.enable_debug_mobile_mode(false)

var object = Node2D.new()
object.scale = Vector2(1.0, 1.0)

MobileUIManager.apply_game_object_scaling(object)

# Result: object.scale unchanged = Vector2(1.0, 1.0)
```

## Integration Example

```gdscript
extends Node2D

func _ready():
    # Apply mobile scaling to all game objects
    for child in get_children():
        if child is Node2D:
            MobileUIManager.apply_game_object_scaling(child)
    
    # Or scale specific objects
    MobileUIManager.apply_game_object_scaling($Player)
    MobileUIManager.apply_game_object_scaling($Enemy)
    
    # Collectibles
    for drop in get_tree().get_nodes_in_group("collectibles"):
        MobileUIManager.apply_game_object_scaling(drop)
```

## Configuration

Scaling factors can be customized in MobileUIManager:

```gdscript
# In MobileUIManager or via config file
MobileUIManager.mobile_game_object_scale = 1.5  # Default: 1.4
MobileUIManager.mobile_collectible_scale = 1.4  # Default: 1.3
```

## Testing

Run the validation scene to verify the implementation:
1. Open `res://test/validate_game_object_scaling.tscn` in Godot
2. Run the scene (F6)
3. Check the console output for validation results

Or run the comprehensive test suite:
1. Open `res://test/MobileUIManagerTest.tscn`
2. Run the scene
3. All tests should pass

## Requirements Validated

This implementation validates the following requirements:
- **3.1**: Interactive game objects scaled to 1.4x on mobile
- **3.2**: Draggable objects have minimum 120x120 pixel area
- **3.3**: Collectible items scaled to 1.3x on mobile
- **3.5**: Collision detection accuracy maintained after scaling
