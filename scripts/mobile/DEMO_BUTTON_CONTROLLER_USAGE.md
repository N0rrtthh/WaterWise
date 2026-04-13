# Demo Button Controller Usage Guide

## Overview

The `DemoButtonController` is a helper class that manages the visibility of demo/debug buttons based on platform, build configuration, and debug flags. It automatically hides thesis demonstration buttons (Algorithm Demo, G-Counter Demo, Research Dashboard) on mobile platforms and production builds.

## Requirements Addressed

- **Requirement 4.1**: Hide demo buttons on mobile platforms
- **Requirement 4.2**: Exclude demo button code in production builds
- **Requirement 4.4**: Show demo buttons on desktop in debug mode
- **Requirement 4.5**: Provide configuration flag for demo button visibility

## Quick Start

### Basic Usage

```gdscript
extends Control

func _ready() -> void:
    # Check if demo buttons should be shown
    if not DemoButtonController.should_show_demo_buttons():
        # Hide all demo buttons in the scene
        DemoButtonController.hide_demo_buttons(self)
```

### Integration with Main Menu

```gdscript
extends Control

@onready var algorithm_demo_btn: Button = null
@onready var gcounter_demo_btn: Button = null
@onready var research_dashboard_btn: Button = null

func _ready() -> void:
    _create_demo_buttons()
    
    # Hide demo buttons if not appropriate for current platform/build
    if not DemoButtonController.should_show_demo_buttons():
        DemoButtonController.hide_demo_buttons(self)

func _create_demo_buttons() -> void:
    # Create algorithm demo button
    algorithm_demo_btn = Button.new()
    algorithm_demo_btn.name = "algorithm_demo_btn"
    algorithm_demo_btn.text = "🔬 Algorithm Demo"
    add_child(algorithm_demo_btn)
    
    # Create other demo buttons...
```

## API Reference

### Static Methods

#### `should_show_demo_buttons() -> bool`

Determines if demo buttons should be visible based on platform and build configuration.

**Returns**: `true` if demo buttons should be shown, `false` otherwise

**Logic**:
- Returns `false` on mobile platforms unless in debug build
- Returns `true` on desktop in debug mode
- Returns `false` in production builds
- Respects MobileUIManager configuration flags

**Example**:
```gdscript
if DemoButtonController.should_show_demo_buttons():
    print("Demo buttons will be visible")
else:
    print("Demo buttons will be hidden")
```

#### `hide_demo_buttons(root: Node) -> void`

Finds and hides all demo buttons in the scene tree starting from the root node.

**Parameters**:
- `root`: The root node to search from (typically the scene root)

**Behavior**:
- Recursively searches the scene tree for demo buttons
- Identifies buttons by name patterns, group membership, or text content
- Sets `visible = false` on found buttons
- Calls `queue_free()` to remove buttons from the scene tree
- Logs the number of buttons hidden

**Example**:
```gdscript
func _ready() -> void:
    # Hide all demo buttons in this scene
    DemoButtonController.hide_demo_buttons(self)
    
    # Or hide demo buttons in a specific container
    var menu_container = $MenuContainer
    DemoButtonController.hide_demo_buttons(menu_container)
```

## Button Detection Patterns

The controller identifies demo buttons using multiple detection methods:

### 1. Name Patterns

Buttons with these name patterns are considered demo buttons:
- `algorithm_demo`, `algorithmdemo`
- `gcounter_demo`, `gcounterdemo`
- `research_dashboard`, `researchdashboard`
- `demo_button`, `demobutton`
- `algorithm demo`, `g-counter`, `gcounter`
- `research dashboard`

**Example**:
```gdscript
var btn = Button.new()
btn.name = "algorithm_demo_btn"  # Will be detected as demo button
```

### 2. Group Membership

Buttons in these groups are considered demo buttons:
- `demo_buttons`
- `debug_buttons`
- `thesis_demo`

**Example**:
```gdscript
var btn = Button.new()
btn.add_to_group("demo_buttons")  # Will be detected as demo button
```

### 3. Text Content

Buttons with these text patterns are considered demo buttons:
- `algorithm demo`
- `g-counter`, `gcounter`
- `research dashboard`
- `crdt demo`
- `thesis`
- `panelist`

**Example**:
```gdscript
var btn = Button.new()
btn.text = "🔬 Algorithm Demo"  # Will be detected as demo button
```

## Integration Examples

### Example 1: Main Menu Scene

```gdscript
extends Control

func _ready() -> void:
    # Create all UI elements including demo buttons
    _setup_ui()
    
    # Hide demo buttons on mobile/production
    if not DemoButtonController.should_show_demo_buttons():
        DemoButtonController.hide_demo_buttons(self)
        _adjust_layout_after_button_removal()

func _adjust_layout_after_button_removal() -> void:
    # Adjust spacing and layout after demo buttons are removed
    # This ensures no gaps or awkward spacing
    var button_container = $ButtonContainer
    button_container.queue_sort()
```

### Example 2: Conditional Button Creation

```gdscript
extends Control

func _ready() -> void:
    _create_standard_buttons()
    
    # Only create demo buttons if they should be shown
    if DemoButtonController.should_show_demo_buttons():
        _create_demo_buttons()

func _create_standard_buttons() -> void:
    # Create play, settings, quit buttons, etc.
    pass

func _create_demo_buttons() -> void:
    # Create algorithm demo, g-counter demo, research dashboard buttons
    pass
```

### Example 3: Dynamic Visibility Toggle

```gdscript
extends Control

var demo_buttons_visible: bool = false

func _ready() -> void:
    demo_buttons_visible = DemoButtonController.should_show_demo_buttons()
    _update_demo_button_visibility()

func _update_demo_button_visibility() -> void:
    if demo_buttons_visible:
        _show_demo_buttons()
    else:
        DemoButtonController.hide_demo_buttons(self)

func _show_demo_buttons() -> void:
    # Show demo buttons (if they exist)
    for child in get_children():
        if child is Button and _is_demo_button(child):
            child.visible = true
```

## Testing

Unit tests are available in `test/DemoButtonControllerTest.gd`. To run:

1. Open `test/DemoButtonControllerTest.tscn` in Godot Editor
2. Press F6 to run the current scene
3. Check the console output for test results

### Test Coverage

The test suite covers:
- ✅ Visibility logic based on platform and build config
- ✅ Finding demo buttons by name patterns
- ✅ Finding demo buttons by group membership
- ✅ Finding demo buttons by text content
- ✅ Hiding demo buttons and removing from scene tree
- ✅ Null safety and error handling

## Best Practices

### 1. Call Early in Scene Lifecycle

Hide demo buttons in `_ready()` before the scene becomes visible:

```gdscript
func _ready() -> void:
    # Hide demo buttons first
    if not DemoButtonController.should_show_demo_buttons():
        DemoButtonController.hide_demo_buttons(self)
    
    # Then continue with other initialization
    _setup_ui()
    _connect_signals()
```

### 2. Use Consistent Naming

Use consistent naming patterns for demo buttons to ensure they're detected:

```gdscript
# Good - will be detected
var algorithm_demo_btn = Button.new()
algorithm_demo_btn.name = "algorithm_demo_btn"

# Also good - will be detected
var research_btn = Button.new()
research_btn.name = "research_dashboard_btn"
```

### 3. Add to Groups for Clarity

Explicitly add demo buttons to the `demo_buttons` group:

```gdscript
var demo_btn = Button.new()
demo_btn.add_to_group("demo_buttons")  # Clear intent
```

### 4. Adjust Layout After Removal

Ensure proper spacing after demo buttons are removed:

```gdscript
func _ready() -> void:
    if not DemoButtonController.should_show_demo_buttons():
        DemoButtonController.hide_demo_buttons(self)
        
        # Adjust layout to fill the space
        var container = $ButtonContainer
        container.queue_sort()
```

## Troubleshooting

### Demo Buttons Not Being Hidden

**Problem**: Demo buttons are still visible on mobile

**Solutions**:
1. Check button naming matches detection patterns
2. Verify `DemoButtonController.hide_demo_buttons()` is called in `_ready()`
3. Ensure MobileUIManager is properly initialized
4. Check if debug mobile mode is enabled

### Demo Buttons Hidden on Desktop

**Problem**: Demo buttons are hidden on desktop during development

**Solutions**:
1. Verify you're running a debug build (`OS.is_debug_build()` returns `true`)
2. Check MobileUIManager debug flags
3. Ensure the button names/groups match detection patterns

### Layout Issues After Removal

**Problem**: Gaps or awkward spacing after demo buttons are removed

**Solutions**:
1. Call `queue_sort()` on parent container after removal
2. Adjust container spacing settings
3. Use `hide_demo_buttons()` before other UI initialization

## Related Documentation

- [MobileUIManager Usage](./INTEGRATION_EXAMPLE.md)
- [Mobile Config](./MobileConfig.gd)
- [Requirements Document](../../.kiro/specs/mobile-responsive-ui/requirements.md)

## Implementation Notes

### Platform Detection

The controller uses MobileUIManager for platform detection:
- Checks `MobileUIManager.is_mobile_platform()`
- Falls back to `OS.is_debug_build()` if MobileUIManager is unavailable

### Button Removal Strategy

Buttons are both hidden and queued for deletion:
1. `visible = false` - Immediate visual hiding
2. `queue_free()` - Deferred memory cleanup

This ensures buttons are removed from the scene tree and don't consume resources.

### Performance Considerations

- Button detection is recursive but efficient
- Only runs once during scene initialization
- No runtime overhead after initial hiding
- Minimal memory footprint

## Version History

- **v1.0** (Task 8.1): Initial implementation
  - Static helper methods for visibility control
  - Multiple detection patterns (name, group, text)
  - Integration with MobileUIManager
  - Comprehensive test coverage
