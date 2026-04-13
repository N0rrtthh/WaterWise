# MobileConfig and SafeAreaInfo Integration Example

## Overview

The mobile responsive UI system includes two data models:
- **MobileConfig**: Stores all mobile UI configuration settings (scaling, spacing, performance)
- **SafeAreaInfo**: Handles device safe area information (notches, rounded corners)

Both can be integrated with `MobileUIManager` to enable runtime configuration and safe area handling.

## SafeAreaInfo Usage

### Calculating Safe Area in MobileUIManager

```gdscript
# In MobileUIManager.gd

var safe_area_info: SafeAreaInfo = null

func _calculate_safe_area() -> void:
    """Calculate safe area margins for devices with notches"""
    safe_area_info = SafeAreaInfo.new()
    safe_area_info.from_display_safe_area()
    
    # Get margins as dictionary for easy access
    safe_area_margins = safe_area_info.to_dictionary()
    
    # Emit signal for UI elements to update
    safe_area_changed.emit(safe_area_margins)
    
    print("📱 Safe area margins calculated:")
    print("   Top: %.1f, Bottom: %.1f, Left: %.1f, Right: %.1f" % [
        safe_area_info.top,
        safe_area_info.bottom,
        safe_area_info.left,
        safe_area_info.right
    ])
```

### Applying Safe Area to UI Elements

```gdscript
# In a scene script

func _ready() -> void:
    # Connect to safe area changes
    MobileUIManager.safe_area_changed.connect(_on_safe_area_changed)
    
    # Apply initial safe area
    _apply_safe_area(MobileUIManager.get_safe_area_margins())

func _on_safe_area_changed(margins: Dictionary) -> void:
    """Handle safe area changes (orientation, device change)"""
    _apply_safe_area(margins)

func _apply_safe_area(margins: Dictionary) -> void:
    """Apply safe area margins to UI container"""
    var container = $MarginContainer
    
    # Add safe area margins plus additional padding
    var padding = MobileUIManager.get_safe_area_margin()  # 20px
    
    container.add_theme_constant_override("margin_top", margins["top"] + padding)
    container.add_theme_constant_override("margin_bottom", margins["bottom"] + padding)
    container.add_theme_constant_override("margin_left", margins["left"] + padding)
    container.add_theme_constant_override("margin_right", margins["right"] + padding)
```

### Error Handling

SafeAreaInfo includes validation for invalid data:

```gdscript
# SafeAreaInfo automatically handles errors:
# - Invalid screen size (zero or negative)
# - Invalid safe area position (negative)
# - Invalid safe area size (zero or negative)
# - Safe area extending beyond screen bounds

# If validation fails, margins are set to zero (full screen)
# Warnings are logged to help with debugging
```

## MobileConfig Usage

### Loading Configuration in MobileUIManager

```gdscript
# In MobileUIManager.gd

var mobile_config: MobileConfig = null

func _ready() -> void:
    # Load configuration
    mobile_config = MobileConfig.new()
    var config_path = "user://mobile_ui_config.cfg"
    
    if FileAccess.file_exists(config_path):
        if mobile_config.load_from_file(config_path):
            _apply_config_to_manager()
        else:
            push_warning("Failed to load config, using defaults")
    else:
        # Save default config for future use
        mobile_config.save_to_file(config_path)

func _apply_config_to_manager() -> void:
    """Apply loaded config values to manager properties"""
    mobile_ui_scale = mobile_config.ui_scale
    mobile_font_scale = mobile_config.font_scale
    mobile_game_object_scale = mobile_config.game_object_scale
    mobile_collectible_scale = mobile_config.collectible_scale
    mobile_button_min_size = mobile_config.button_min_size
    mobile_touch_target_min_size = mobile_config.touch_target_min_size
    mobile_button_spacing_vertical = mobile_config.button_spacing_vertical
    mobile_button_spacing_horizontal = mobile_config.button_spacing_horizontal
    mobile_safe_area_margin = mobile_config.safe_area_margin
    mobile_edge_dead_zone = mobile_config.edge_dead_zone
    mobile_particle_reduction = mobile_config.particle_reduction
    mobile_max_tweens = mobile_config.max_tweens
    mobile_target_fps = mobile_config.target_fps
    mobile_game_speed_reduction = mobile_config.game_speed_reduction
    mobile_timing_window_increase = mobile_config.timing_window_increase
    mobile_spawn_rate_reduction = mobile_config.spawn_rate_reduction
    mobile_drag_smoothing_increase = mobile_config.drag_smoothing_increase
```

### Runtime Configuration Reload

```gdscript
# In MobileUIManager.gd

func reload_config() -> void:
    """Reload configuration from file without restarting game"""
    var config_path = "user://mobile_ui_config.cfg"
    
    if mobile_config.load_from_file(config_path):
        _apply_config_to_manager()
        mobile_mode_changed.emit(is_mobile)
        print("📱 Configuration reloaded successfully")
    else:
        push_error("Failed to reload configuration")
```

### Saving Modified Configuration

```gdscript
# In MobileUIManager.gd

func save_current_config() -> void:
    """Save current manager settings to config file"""
    # Update config object with current values
    mobile_config.ui_scale = mobile_ui_scale
    mobile_config.font_scale = mobile_font_scale
    mobile_config.game_object_scale = mobile_game_object_scale
    # ... update other values
    
    var config_path = "user://mobile_ui_config.cfg"
    if mobile_config.save_to_file(config_path):
        print("📱 Configuration saved successfully")
    else:
        push_error("Failed to save configuration")
```

## Configuration File Format

The configuration file uses Godot's ConfigFile format (.cfg):

```ini
[scaling]
ui_scale=1.5
font_scale=1.4
game_object_scale=1.4
collectible_scale=1.3

[sizes]
button_min_size=Vector2(100, 60)
touch_target_min_size=Vector2(80, 80)

[spacing]
button_vertical=20.0
button_horizontal=15.0
safe_area_margin=20.0
edge_dead_zone=15.0

[performance]
particle_reduction=0.4
max_tweens=10
target_fps=30

[gameplay]
speed_reduction=0.15
timing_window_increase=0.2
spawn_rate_reduction=0.1
drag_smoothing_increase=1.5
visual_indicator_scale=1.3
```

## Testing

### MobileConfig Tests
See `test/MobileConfigTest.gd` for comprehensive unit tests covering:
- Default values
- Save and load operations
- Error handling for missing files
- Partial configuration files

### SafeAreaInfo Tests
See `test/SafeAreaInfoTest.gd` for comprehensive unit tests covering:
- Default values
- Dictionary conversion
- Safe area calculation from DisplayServer
- Validation logic for notched devices
- Full screen device handling

## Benefits

1. **Separation of Concerns**: Configuration data is separate from manager logic
2. **Reusability**: MobileConfig and SafeAreaInfo can be used by other systems
3. **Testability**: Easy to test configuration and safe area handling independently
4. **Flexibility**: Users can customize settings by editing the config file
5. **Runtime Reload**: Configuration can be reloaded without restarting the game
6. **Error Handling**: Robust validation prevents crashes from invalid safe area data
