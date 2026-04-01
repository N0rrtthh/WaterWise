# Safe Area Margin Implementation

## Overview

Task 3.3 implements safe area margin application in the MobileUIManager. This ensures that UI elements maintain a minimum 20-pixel margin from device safe area boundaries (notches, rounded corners, system UI).

## Implementation Details

### Changes Made

1. **Updated `_calculate_safe_area()` method** in `autoload/MobileUIManager.gd`:
   - Now uses `SafeAreaInfo` class to calculate base margins from DisplayServer
   - Applies 20-pixel minimum margin to all sides (top, bottom, left, right)
   - Emits `safe_area_changed` signal with the calculated margins
   - Properly documented with requirements references

2. **Updated `_on_viewport_size_changed()` handler**:
   - Removed duplicate signal emission (now handled by `_calculate_safe_area()`)
   - Maintains proper signal flow for viewport changes

3. **Added tests** in `test/MobileUIManagerTest.gd`:
   - `test_safe_area_margin_application()`: Verifies 20px minimum margin is applied
   - `test_safe_area_changed_signal()`: Verifies signal emission and margin population

## Requirements Validated

- **Requirement 5.4**: THE UI_System SHALL respect the Safe_Area margins on devices with notches or rounded corners
- **Requirement 5.6**: THE UI_System SHALL maintain a minimum margin of 20 pixels from Safe_Area boundaries for all interactive elements
- **Requirement 1.6**: WHEN a Control_Node is scaled for mobile, THE UI_System SHALL ensure the element remains within the Safe_Area boundaries

## How It Works

```gdscript
# 1. SafeAreaInfo calculates base margins from DisplayServer
var safe_area_info = SafeAreaInfo.new()
safe_area_info.from_display_safe_area()
var base_margins = safe_area_info.to_dictionary()

# 2. Apply 20-pixel minimum margin to all sides
safe_area_margins = {
    "top": base_margins["top"] + 20.0,
    "bottom": base_margins["bottom"] + 20.0,
    "left": base_margins["left"] + 20.0,
    "right": base_margins["right"] + 20.0
}

# 3. Emit signal for listeners
safe_area_changed.emit(safe_area_margins)
```

## Usage Example

```gdscript
# In a scene script, listen for safe area changes
func _ready():
    MobileUIManager.safe_area_changed.connect(_on_safe_area_changed)
    
    # Get current safe area margins
    var margins = MobileUIManager.get_safe_area_margins()
    _apply_margins_to_ui(margins)

func _on_safe_area_changed(margins: Dictionary):
    # Update UI when safe area changes (e.g., orientation change)
    _apply_margins_to_ui(margins)

func _apply_margins_to_ui(margins: Dictionary):
    # Apply margins to a MarginContainer
    if $MarginContainer:
        $MarginContainer.add_theme_constant_override("margin_top", margins["top"])
        $MarginContainer.add_theme_constant_override("margin_bottom", margins["bottom"])
        $MarginContainer.add_theme_constant_override("margin_left", margins["left"])
        $MarginContainer.add_theme_constant_override("margin_right", margins["right"])
```

## Testing

Run the test scene to verify the implementation:

1. Open `test/MobileUIManagerTest.tscn` in Godot Editor
2. Press F6 to run the scene
3. Check console output for test results

Expected output:
```
TEST: Safe Area Margin Application - 20px minimum margin
  Safe area margins:
    Top: 20.0 (or higher on notched devices)
    Bottom: 20.0 (or higher on notched devices)
    Left: 20.0 (or higher on notched devices)
    Right: 20.0 (or higher on notched devices)
  ✓ Safe area margins calculated with 20px minimum

TEST: Safe Area Changed Signal - Emitted on initialization
  ✓ Safe area changed signal emitted and margins populated
```

## Integration with LayoutManager

The LayoutManager component (task 3.1) provides helper methods to apply these margins to UI containers:

```gdscript
# Apply safe area margins to a container
var margins = MobileUIManager.get_safe_area_margins()
LayoutManager.apply_safe_area_margins($MarginContainer, margins)
```

## Notes

- On devices without notches (full-screen), base margins are 0, so total margin is exactly 20px
- On devices with notches, total margin is base_margin + 20px
- Margins are recalculated on viewport size changes (orientation changes)
- The `safe_area_changed` signal is emitted both on initialization and viewport changes
