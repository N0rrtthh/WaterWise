# UIScaler Usage Examples

## Overview

The `UIScaler` class provides static utility methods for scaling UI elements on mobile platforms. It handles Control node scaling, font scaling, and minimum size enforcement while preserving aspect ratios and meeting touch target requirements.

## Basic Usage

### 1. Scale a Control Node

```gdscript
# Scale a button for mobile (1.5x)
var button = Button.new()
UIScaler.scale_control_node(button, 1.5)
```

This applies uniform scaling to both X and Y axes, preserving the aspect ratio.

### 2. Scale Font Size

```gdscript
# Scale a label's font for mobile (1.4x)
var label = Label.new()
label.add_theme_font_size_override("font_size", 16)
UIScaler.scale_font(label, 1.4)  # Results in 22px font
```

### 3. Enforce Minimum Size

```gdscript
# Ensure a button meets minimum touch target size
var button = Button.new()
button.size = Vector2(50, 30)  # Too small for mobile
UIScaler.ensure_minimum_size(button, Vector2(100, 60))
```

## Complete Mobile Transformation

Here's how to apply all mobile transformations to a UI element:

```gdscript
func apply_mobile_scaling_to_button(button: Button) -> void:
	# Get scaling factors from MobileUIManager
	var ui_scale = MobileUIManager.get_ui_scale()
	var font_scale = MobileUIManager.get_font_scale()
	var min_button_size = MobileUIManager.get_button_min_size()
	
	# Apply transformations
	UIScaler.scale_control_node(button, ui_scale)
	UIScaler.scale_font(button, font_scale)
	UIScaler.ensure_minimum_size(button, min_button_size)
```

## Integration with MobileUIManager

The UIScaler is designed to work with MobileUIManager's configuration:

```gdscript
func _ready() -> void:
	if MobileUIManager.is_mobile_platform():
		# Scale all UI elements
		for child in get_children():
			if child is Control:
				UIScaler.scale_control_node(child, MobileUIManager.get_ui_scale())
			
			if child is Label:
				UIScaler.scale_font(child, MobileUIManager.get_font_scale())
			
			if child is Button:
				UIScaler.ensure_minimum_size(child, MobileUIManager.get_button_min_size())
```

## Scene-Level Usage

For applying mobile scaling to an entire scene:

```gdscript
extends Control

func _ready() -> void:
	if MobileUIManager.is_mobile_platform():
		_apply_mobile_scaling_recursive(self)

func _apply_mobile_scaling_recursive(node: Node) -> void:
	# Scale the node if it's a Control
	if node is Control:
		UIScaler.scale_control_node(node, MobileUIManager.get_ui_scale())
		
		# Ensure minimum size for interactive elements
		if node is Button or node is TextureButton:
			UIScaler.ensure_minimum_size(node, MobileUIManager.get_button_min_size())
		elif node is Control:
			UIScaler.ensure_minimum_size(node, MobileUIManager.get_touch_target_min_size())
	
	# Scale fonts for labels
	if node is Label:
		UIScaler.scale_font(node, MobileUIManager.get_font_scale())
	
	# Recursively apply to children
	for child in node.get_children():
		_apply_mobile_scaling_recursive(child)
```

## Requirements Validation

The UIScaler class validates the following requirements:

- **Requirement 1.1**: UI elements scaled to at least 1.5x on mobile
- **Requirement 1.2**: Touch targets have minimum size of 80x80 pixels
- **Requirement 1.3**: Font sizes scaled by 1.3x to 1.5x
- **Requirement 1.5**: Aspect ratios preserved during scaling

## Error Handling

The UIScaler methods include validation:

```gdscript
# Handles null nodes gracefully
UIScaler.scale_control_node(null, 1.5)  # Logs warning, doesn't crash

# Rejects invalid scale factors
UIScaler.scale_control_node(button, 0.0)  # Logs warning, no change
UIScaler.scale_control_node(button, -1.5)  # Logs warning, no change

# Rejects invalid minimum sizes
UIScaler.ensure_minimum_size(button, Vector2(-10, -10))  # Logs warning, no change
```

## Testing

Unit tests are available in `test/UIScalerTest.gd`. To run:

1. Open `test/UIScalerTest.tscn` in Godot Editor
2. Press F6 to run the scene
3. Check console output for test results

## Performance Considerations

- All methods are static - no instance creation overhead
- Scaling operations are applied once during initialization
- No runtime performance impact after initial scaling

## Best Practices

1. **Apply scaling during _ready()**: Scale UI elements once when the scene loads
2. **Use MobileUIManager for configuration**: Don't hardcode scale factors
3. **Test on actual devices**: Verify touch target sizes on real mobile devices
4. **Consider safe areas**: Combine with safe area margins for notched devices
5. **Scale recursively**: Apply to entire scene trees for consistency
