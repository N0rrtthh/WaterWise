# Haptic Feedback Usage Guide

## Overview

The TouchInputManager provides haptic feedback functionality for button presses on mobile platforms. This feature enhances the user experience by providing tactile feedback when users interact with UI elements.

## Requirements

- **Requirement 2.5**: WHEN a button is pressed on Mobile_Platform, THE Touch_Handler SHALL provide haptic feedback

## Features

- Automatic haptic feedback on button presses (mobile only)
- Multiple vibration patterns (light, medium, heavy, success, error)
- Scene-wide haptic enablement
- Desktop-safe (no vibration on desktop platforms)

## Basic Usage

### Enable Haptics for a Single Button

```gdscript
extends Control

func _ready():
    var my_button = $MyButton
    TouchInputManager.enable_button_haptics(my_button)
```

### Enable Haptics for All Buttons in a Scene

```gdscript
extends Control

func _ready():
    # Automatically enable haptics for all buttons in the scene tree
    TouchInputManager.enable_haptics_for_scene(self)
```

### Manual Vibration Patterns

```gdscript
# Light vibration (50ms) - for button presses
TouchInputManager.vibrate_light()

# Medium vibration (100ms) - for notifications
TouchInputManager.vibrate_medium()

# Heavy vibration (200ms) - for important events
TouchInputManager.vibrate_heavy()

# Success pattern (short-short-long)
TouchInputManager.vibrate_success()

# Error pattern (long-long)
TouchInputManager.vibrate_error()

# Button press vibration (50ms) - same as vibrate_light()
TouchInputManager.vibrate_button_press()
```

## Implementation Details

### Platform Detection

The haptic feedback system automatically detects the platform:
- **Mobile**: Android and iOS devices
- **Desktop**: Windows, macOS, Linux (no vibration)

Vibration only occurs on mobile platforms. Desktop platforms ignore vibration calls.

### Signal Connection

When you call `enable_button_haptics(button)`, the system:
1. Checks if the platform is mobile
2. Connects the button's `pressed` signal to `vibrate_button_press()`
3. Prevents duplicate connections

### Scene-Wide Enablement

The `enable_haptics_for_scene(root)` method:
1. Recursively traverses the scene tree
2. Finds all `BaseButton` nodes (Button, TextureButton, etc.)
3. Enables haptics for each button found

## Best Practices

### 1. Enable Haptics in _ready()

```gdscript
func _ready():
    # Enable haptics after UI is fully initialized
    TouchInputManager.enable_haptics_for_scene(self)
```

### 2. Use Scene-Wide Enablement for Menus

```gdscript
# Main menu scene
extends Control

func _ready():
    # Enable haptics for all menu buttons at once
    TouchInputManager.enable_haptics_for_scene(self)
```

### 3. Use Manual Vibration for Game Events

```gdscript
# Game scene
extends Node2D

func _on_player_collected_item():
    TouchInputManager.vibrate_light()

func _on_player_completed_level():
    TouchInputManager.vibrate_success()

func _on_player_failed():
    TouchInputManager.vibrate_error()
```

### 4. Don't Worry About Desktop

The system automatically handles platform detection. You don't need to check `is_mobile` before calling vibration methods.

```gdscript
# This is safe on all platforms
TouchInputManager.vibrate_button_press()
```

## Testing

### Unit Tests

Run the haptic feedback test suite:
```bash
# Load the test scene in Godot editor
res://test/TouchInputHapticsTest.tscn
```

### Manual Testing

1. Enable debug mobile mode on desktop:
```gdscript
MobileUIManager.enable_debug_mobile_mode(true)
```

2. Test on actual mobile device:
   - Export to Android/iOS
   - Test button presses
   - Verify vibration occurs

## Integration with MobileUIManager

The haptic feedback system works seamlessly with MobileUIManager:

```gdscript
extends Control

func _ready():
    # Apply mobile scaling
    if MobileUIManager.is_mobile_platform():
        MobileUIManager.apply_mobile_scaling(self)
    
    # Enable haptics for all buttons
    TouchInputManager.enable_haptics_for_scene(self)
```

## Troubleshooting

### Vibration Not Working on Mobile

1. **Check Platform Detection**:
```gdscript
print("Is mobile: ", TouchInputManager.is_mobile)
```

2. **Verify Button Connection**:
```gdscript
var button = $MyButton
print("Haptics connected: ", button.pressed.is_connected(TouchInputManager.vibrate_button_press))
```

3. **Check Device Settings**:
   - Ensure device vibration is enabled in system settings
   - Some devices have vibration disabled in power-saving mode

### Duplicate Connections

The system automatically prevents duplicate connections. Calling `enable_button_haptics()` multiple times on the same button is safe.

## Performance Considerations

- Haptic feedback has minimal performance impact
- Vibration calls are non-blocking
- Pattern vibrations (success, error) use async timers
- No overhead on desktop platforms (early return)

## Accessibility

Haptic feedback improves accessibility by:
- Providing tactile confirmation of button presses
- Helping users with visual impairments
- Reducing accidental taps through feedback

Users can disable vibration in their device settings if desired.

## Related Documentation

- [Mobile UI Manager Usage](./INTEGRATION_EXAMPLE.md)
- [Touch Input Manager](../../autoload/TouchInputManager.gd)
- [Requirements Document](../../.kiro/specs/mobile-responsive-ui/requirements.md)
