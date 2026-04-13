# LayoutManager Usage Examples

## Overview

The `LayoutManager` class provides static utility methods for managing responsive layouts on mobile platforms. It handles orientation-based layout reorganization, safe area margin application, and button spacing to optimize screen space usage and prevent overlap with device notches.

## Basic Usage

### 1. Reorganize Layout for Orientation

```gdscript
# Switch layout based on orientation
var container = VBoxContainer.new()
var is_portrait = MobileUIManager.is_portrait_orientation()

LayoutManager.reorganize_for_orientation(container, is_portrait)
```

This automatically switches between vertical layout (portrait) and horizontal/grid layout (landscape).

### 2. Apply Safe Area Margins

```gdscript
# Apply safe area margins to prevent overlap with notches
var margin_container = MarginContainer.new()
var margins = MobileUIManager.get_safe_area_margins()

LayoutManager.apply_safe_area_margins(margin_container, margins)
```

### 3. Apply Button Spacing

```gdscript
# Apply mobile-optimized button spacing
var vbox = VBoxContainer.new()

# For vertical layout (20px spacing)
LayoutManager.apply_button_spacing_vertical(vbox)

# For horizontal layout (15px spacing)
var hbox = HBoxContainer.new()
LayoutManager.apply_button_spacing_horizontal(hbox)
```

## Complete Mobile Layout Setup

Here's how to set up a complete mobile-responsive layout:

```gdscript
func setup_mobile_layout(container: Container) -> void:
	# Get orientation and safe area from MobileUIManager
	var is_portrait = MobileUIManager.is_portrait_orientation()
	var safe_margins = MobileUIManager.get_safe_area_margins()
	
	# Reorganize for current orientation
	LayoutManager.reorganize_for_orientation(container, is_portrait)
	
	# Apply safe area margins
	LayoutManager.apply_safe_area_margins(container, safe_margins)
```

## Handling Orientation Changes

Listen for orientation changes and reorganize layouts dynamically:

```gdscript
extends Control

func _ready() -> void:
	# Connect to orientation change signal
	MobileUIManager.orientation_changed.connect(_on_orientation_changed)
	
	# Apply initial layout
	_setup_layout()

func _on_orientation_changed(is_portrait: bool) -> void:
	# Reorganize all containers when orientation changes
	for container in _get_all_containers():
		LayoutManager.reorganize_for_orientation(container, is_portrait)

func _get_all_containers() -> Array:
	var containers = []
	_find_containers_recursive(self, containers)
	return containers

func _find_containers_recursive(node: Node, containers: Array) -> void:
	if node is Container:
		containers.append(node)
	
	for child in node.get_children():
		_find_containers_recursive(child, containers)
```

## Main Menu Example

Complete example for a mobile-responsive main menu:

```gdscript
extends Control

@onready var button_container = $MarginContainer/VBoxContainer

func _ready() -> void:
	if MobileUIManager.is_mobile_platform():
		_setup_mobile_layout()
		MobileUIManager.orientation_changed.connect(_on_orientation_changed)

func _setup_mobile_layout() -> void:
	# Get safe area margins
	var margins = MobileUIManager.get_safe_area_margins()
	
	# Apply safe area to margin container
	var margin_container = $MarginContainer
	LayoutManager.apply_safe_area_margins(margin_container, margins)
	
	# Set up button container for current orientation
	var is_portrait = MobileUIManager.is_portrait_orientation()
	LayoutManager.reorganize_for_orientation(button_container, is_portrait)

func _on_orientation_changed(is_portrait: bool) -> void:
	# Reorganize button layout
	LayoutManager.reorganize_for_orientation(button_container, is_portrait)
```

## GridContainer Example

Using GridContainer for adaptive layouts:

```gdscript
extends Control

@onready var grid = $GridContainer

func _ready() -> void:
	if MobileUIManager.is_mobile_platform():
		_setup_grid_layout()
		MobileUIManager.orientation_changed.connect(_on_orientation_changed)

func _setup_grid_layout() -> void:
	var is_portrait = MobileUIManager.is_portrait_orientation()
	
	# Reorganize grid for orientation
	LayoutManager.reorganize_for_orientation(grid, is_portrait)
	# Portrait: 1 column
	# Landscape: 2-3 columns based on child count

func _on_orientation_changed(is_portrait: bool) -> void:
	LayoutManager.reorganize_for_orientation(grid, is_portrait)
```

## Custom Spacing Example

Apply custom spacing values for specific layouts:

```gdscript
func setup_compact_layout(container: VBoxContainer) -> void:
	# Use tighter spacing for compact layouts
	LayoutManager.apply_button_spacing_vertical(container, 10.0)

func setup_spacious_layout(container: VBoxContainer) -> void:
	# Use larger spacing for spacious layouts
	LayoutManager.apply_button_spacing_vertical(container, 30.0)
```

## Safe Area with Minimum Margin

Combine safe area margins with minimum margin requirements:

```gdscript
func apply_safe_area_with_minimum(node: Control) -> void:
	var margins = MobileUIManager.get_safe_area_margins()
	var min_margin = MobileUIManager.get_safe_area_margin()  # 20px
	
	# Ensure minimum margin is applied
	margins["top"] = max(margins.get("top", 0.0), min_margin)
	margins["bottom"] = max(margins.get("bottom", 0.0), min_margin)
	margins["left"] = max(margins.get("left", 0.0), min_margin)
	margins["right"] = max(margins.get("right", 0.0), min_margin)
	
	LayoutManager.apply_safe_area_margins(node, margins)
```

## Requirements Validation

The LayoutManager class validates the following requirements:

- **Requirement 5.1**: Layout reorganizes within 0.5 seconds on orientation change
- **Requirement 5.2**: Vertical layout for portrait mode
- **Requirement 5.3**: Horizontal/grid layout for landscape mode
- **Requirement 5.4**: Respects safe area margins on devices with notches
- **Requirement 5.6**: Maintains 20px minimum margin from safe area boundaries
- **Requirement 2.2**: 20px vertical spacing between buttons
- **Requirement 2.3**: 15px horizontal spacing between buttons

## Error Handling

The LayoutManager methods include validation:

```gdscript
# Handles null containers gracefully
LayoutManager.reorganize_for_orientation(null, true)  # Logs warning, doesn't crash

# Handles empty margins dictionary
LayoutManager.apply_safe_area_margins(node, {})  # Applies default values (0)

# Rejects negative spacing
LayoutManager.apply_button_spacing_vertical(vbox, -10.0)  # Logs warning, no change
```

## Testing

Unit tests are available in `test/LayoutManagerTest.gd`. To run:

1. Open `test/LayoutManagerTest.tscn` in Godot Editor
2. Press F6 to run the scene
3. Check console output for test results

## Performance Considerations

- All methods are static - no instance creation overhead
- Layout reorganization is fast (completes in <0.5 seconds)
- Safe area margins are applied once during initialization
- Orientation changes trigger minimal layout recalculation

## Best Practices

1. **Listen for orientation changes**: Connect to `MobileUIManager.orientation_changed` signal
2. **Apply safe area margins early**: Set margins during `_ready()` before content loads
3. **Use appropriate container types**: VBoxContainer/HBoxContainer for simple layouts, GridContainer for complex grids
4. **Test on actual devices**: Verify safe area handling on devices with notches
5. **Combine with UIScaler**: Use both LayoutManager and UIScaler for complete mobile optimization
6. **Cache container references**: Store references to containers that need frequent reorganization

## Integration with MobileUIManager

LayoutManager is designed to work seamlessly with MobileUIManager:

```gdscript
func _ready() -> void:
	if MobileUIManager.is_mobile_platform():
		# Get configuration from MobileUIManager
		var is_portrait = MobileUIManager.is_portrait_orientation()
		var safe_margins = MobileUIManager.get_safe_area_margins()
		var vertical_spacing = MobileUIManager.get_button_spacing_vertical()
		var horizontal_spacing = MobileUIManager.get_button_spacing_horizontal()
		
		# Apply layout configuration
		LayoutManager.reorganize_for_orientation($Container, is_portrait)
		LayoutManager.apply_safe_area_margins($MarginContainer, safe_margins)
		LayoutManager.apply_button_spacing_vertical($VBoxContainer, vertical_spacing)
```

## Complete Scene Setup Example

```gdscript
extends Control

@onready var margin_container = $MarginContainer
@onready var button_container = $MarginContainer/VBoxContainer

func _ready() -> void:
	if MobileUIManager.is_mobile_platform():
		_setup_mobile_responsive_layout()
		_connect_signals()

func _setup_mobile_responsive_layout() -> void:
	# Apply safe area margins
	var margins = MobileUIManager.get_safe_area_margins()
	LayoutManager.apply_safe_area_margins(margin_container, margins)
	
	# Set up button layout for current orientation
	var is_portrait = MobileUIManager.is_portrait_orientation()
	LayoutManager.reorganize_for_orientation(button_container, is_portrait)

func _connect_signals() -> void:
	MobileUIManager.orientation_changed.connect(_on_orientation_changed)
	MobileUIManager.safe_area_changed.connect(_on_safe_area_changed)

func _on_orientation_changed(is_portrait: bool) -> void:
	LayoutManager.reorganize_for_orientation(button_container, is_portrait)

func _on_safe_area_changed(margins: Dictionary) -> void:
	LayoutManager.apply_safe_area_margins(margin_container, margins)
```
