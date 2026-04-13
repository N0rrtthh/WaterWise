# Orientation Detection Usage Guide

## Overview

The MobileUIManager now includes automatic orientation detection that monitors viewport size changes and emits signals when the device orientation changes. This allows UI layouts to adapt dynamically to portrait and landscape orientations.

## Features

- **Automatic Detection**: Continuously monitors viewport size in `_process(delta)`
- **Orientation Signal**: Emits `orientation_changed` signal when orientation changes
- **Timing Control**: Triggers layout reorganization within 0.5 seconds of orientation change
- **Portrait/Landscape Detection**: Determines orientation based on viewport dimensions (height > width = portrait)

## How It Works

### 1. Viewport Monitoring

The `_process(delta)` method continuously checks the viewport size:

```gdscript
func _process(delta: float) -> void:
    var viewport = get_viewport()
    var viewport_size = viewport.get_visible_rect().size
    var current_width = int(viewport_size.x)
    var current_height = int(viewport_size.y)
    
    # Detect size changes and orientation
    if current_width != viewport_width or current_height != viewport_height:
        # Update viewport dimensions
        # Detect new orientation
        # Start orientation change timer
```

### 2. Orientation Change Detection

When viewport dimensions change, the system:
1. Calculates new orientation (portrait if height > width)
2. Compares with current orientation
3. If different, starts a 0.5-second timer
4. After timer expires, emits `orientation_changed` signal

### 3. Signal Emission

```gdscript
# After 0.5 seconds
if _orientation_change_timer >= 0.5:
    is_portrait = _new_orientation
    orientation_changed.emit(is_portrait)
```

## Usage Examples

### Example 1: Listen for Orientation Changes

```gdscript
extends Control

func _ready() -> void:
    # Connect to orientation change signal
    MobileUIManager.orientation_changed.connect(_on_orientation_changed)

func _on_orientation_changed(is_portrait: bool) -> void:
    if is_portrait:
        print("Device is now in portrait mode")
        _apply_portrait_layout()
    else:
        print("Device is now in landscape mode")
        _apply_landscape_layout()

func _apply_portrait_layout() -> void:
    # Reorganize UI for portrait
    # Use vertical layouts, single column grids, etc.
    pass

func _apply_landscape_layout() -> void:
    # Reorganize UI for landscape
    # Use horizontal layouts, multi-column grids, etc.
    pass
```

### Example 2: Integrate with LayoutManager

```gdscript
extends Control

@onready var button_container = $ButtonContainer

func _ready() -> void:
    # Connect to orientation change signal
    MobileUIManager.orientation_changed.connect(_on_orientation_changed)
    
    # Apply initial layout
    var is_portrait = MobileUIManager.is_portrait_orientation()
    LayoutManager.reorganize_for_orientation(button_container, is_portrait)

func _on_orientation_changed(is_portrait: bool) -> void:
    # Automatically reorganize layout when orientation changes
    LayoutManager.reorganize_for_orientation(button_container, is_portrait)
```

### Example 3: Check Current Orientation

```gdscript
extends Node2D

func _ready() -> void:
    # Check current orientation
    if MobileUIManager.is_portrait_orientation():
        print("Starting in portrait mode")
        _setup_portrait_game()
    else:
        print("Starting in landscape mode")
        _setup_landscape_game()

func _setup_portrait_game() -> void:
    # Configure game for portrait orientation
    pass

func _setup_landscape_game() -> void:
    # Configure game for landscape orientation
    pass
```

### Example 4: Responsive Menu System

```gdscript
extends Control

@onready var menu_container = $MenuContainer
@onready var button_grid = $MenuContainer/ButtonGrid

func _ready() -> void:
    # Connect to orientation change
    MobileUIManager.orientation_changed.connect(_on_orientation_changed)
    
    # Apply initial layout
    _update_layout(MobileUIManager.is_portrait_orientation())

func _on_orientation_changed(is_portrait: bool) -> void:
    # Update layout with animation
    var tween = create_tween()
    tween.tween_property(menu_container, "modulate:a", 0.0, 0.2)
    tween.tween_callback(func(): _update_layout(is_portrait))
    tween.tween_property(menu_container, "modulate:a", 1.0, 0.2)

func _update_layout(is_portrait: bool) -> void:
    if is_portrait:
        # Portrait: Single column, vertical layout
        button_grid.columns = 1
        LayoutManager.apply_button_spacing_vertical(button_grid, 20.0)
    else:
        # Landscape: Multi-column, grid layout
        var button_count = button_grid.get_child_count()
        button_grid.columns = 3 if button_count > 4 else 2
        LayoutManager.apply_button_spacing_horizontal(button_grid, 15.0)
```

## API Reference

### Properties

- `is_portrait: bool` - Current orientation state (true = portrait, false = landscape)
- `viewport_width: int` - Current viewport width in pixels
- `viewport_height: int` - Current viewport height in pixels

### Methods

- `is_portrait_orientation() -> bool` - Returns true if in portrait mode
- `is_landscape_orientation() -> bool` - Returns true if in landscape mode

### Signals

- `orientation_changed(is_portrait: bool)` - Emitted when orientation changes
  - `is_portrait`: true for portrait, false for landscape
  - Emitted 0.5 seconds after orientation change is detected

## Timing Behavior

The orientation change has a built-in 0.5-second delay to:
1. Prevent rapid signal emissions during viewport resizing
2. Allow smooth transitions between orientations
3. Meet the requirement of "trigger layout reorganization within 0.5 seconds"

This means:
- Orientation change detected at T=0
- Signal emitted at T=0.5 seconds
- Your layout update code runs immediately after signal emission

## Testing

### Unit Tests

Basic orientation detection tests are included in `test/MobileUIManagerTest.gd`:

```gdscript
func test_orientation_detection_basic() -> void:
    # Test portrait detection
    MobileUIManager.viewport_width = 600
    MobileUIManager.viewport_height = 800
    MobileUIManager._detect_orientation()
    assert(MobileUIManager.is_portrait_orientation() == true)
    
    # Test landscape detection
    MobileUIManager.viewport_width = 800
    MobileUIManager.viewport_height = 600
    MobileUIManager._detect_orientation()
    assert(MobileUIManager.is_portrait_orientation() == false)
```

### Integration Tests

Comprehensive orientation change tests are in `test/OrientationDetectionTest.gd`:

```gdscript
func test_orientation_detection_portrait_to_landscape() -> void:
    # Set viewport to portrait
    get_viewport().size = Vector2i(600, 800)
    await get_tree().create_timer(0.6).timeout
    
    # Change to landscape
    get_viewport().size = Vector2i(800, 600)
    await get_tree().create_timer(0.6).timeout
    
    # Verify orientation changed
    assert(MobileUIManager.is_portrait_orientation() == false)
```

To run tests:
1. Open `test/OrientationDetectionTest.tscn` in Godot Editor
2. Run the scene (F6)
3. Check console output for test results

## Requirements Validation

This implementation validates the following requirements:

- **Requirement 5.1**: Layout reorganizes within 0.5 seconds on orientation change
- **Requirement 5.2**: Vertical layout for portrait mode
- **Requirement 5.3**: Horizontal/grid layout for landscape mode

## Best Practices

1. **Always connect to the signal in `_ready()`** to ensure you don't miss orientation changes
2. **Check initial orientation** when your scene loads to set up the correct layout
3. **Use LayoutManager helpers** for consistent layout reorganization
4. **Add smooth transitions** when changing layouts to improve user experience
5. **Test both orientations** during development to ensure layouts work correctly

## Common Patterns

### Pattern 1: Responsive Container

```gdscript
extends Container

func _ready() -> void:
    MobileUIManager.orientation_changed.connect(_reorganize)
    _reorganize(MobileUIManager.is_portrait_orientation())

func _reorganize(is_portrait: bool) -> void:
    LayoutManager.reorganize_for_orientation(self, is_portrait)
```

### Pattern 2: Conditional UI Elements

```gdscript
extends Control

@onready var sidebar = $Sidebar
@onready var main_content = $MainContent

func _ready() -> void:
    MobileUIManager.orientation_changed.connect(_update_visibility)
    _update_visibility(MobileUIManager.is_portrait_orientation())

func _update_visibility(is_portrait: bool) -> void:
    # Hide sidebar in portrait, show in landscape
    sidebar.visible = not is_portrait
    
    # Adjust main content width
    if is_portrait:
        main_content.anchor_right = 1.0
    else:
        main_content.anchor_right = 0.7
```

### Pattern 3: Game Camera Adjustment

```gdscript
extends Camera2D

func _ready() -> void:
    MobileUIManager.orientation_changed.connect(_adjust_camera)
    _adjust_camera(MobileUIManager.is_portrait_orientation())

func _adjust_camera(is_portrait: bool) -> void:
    if is_portrait:
        # Zoom out more in portrait to show more vertical space
        zoom = Vector2(0.8, 0.8)
    else:
        # Standard zoom in landscape
        zoom = Vector2(1.0, 1.0)
```

## Troubleshooting

### Signal Not Firing

- Ensure MobileUIManager is loaded as an autoload
- Check that viewport size is actually changing
- Verify you're waiting at least 0.5 seconds for the signal

### Incorrect Orientation Detection

- Check viewport dimensions with `MobileUIManager.viewport_width` and `viewport_height`
- Verify the orientation logic (portrait = height > width)
- Test with different viewport sizes

### Layout Not Updating

- Ensure you're connected to the `orientation_changed` signal
- Check that your layout update code is being called
- Verify LayoutManager methods are working correctly

## Performance Considerations

- The `_process(delta)` method runs every frame but only performs calculations when viewport size changes
- Orientation change detection is lightweight and has minimal performance impact
- The 0.5-second delay prevents excessive signal emissions during rapid viewport changes
