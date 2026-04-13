# Mobile UI Testing Guide

## Overview

The mobile-responsive UI system has been implemented. This guide will help you test the implementation on desktop using debug mode before deploying to mobile devices.

## Quick Start - Desktop Testing

### 1. Enable Debug Mobile Mode

Add this code to any scene's `_ready()` function to test mobile mode on desktop:

```gdscript
func _ready():
	# Enable debug mobile mode for testing
	MobileUIManager.enable_debug_mobile_mode(true)
	MobileUIManager.enable_debug_visualization(true)
	MobileUIManager.enable_debug_logging(true)
```

### 2. Test Main Menu

Run the game and check:
- ✅ Buttons are larger (100x60 minimum)
- ✅ Demo buttons are hidden (Algorithm Demo, G-Counter Demo, Research Dashboard)
- ✅ Text is more readable (1.4x font scale)
- ✅ Safe area margins are visible (colored rectangles if debug visualization enabled)
- ✅ Layout adjusts when resizing window (orientation changes)

### 3. Test CatchTheRain Minigame

Play the CatchTheRain minigame and verify:
- ✅ Drum is larger and easier to see
- ✅ Raindrops are larger (1.3x scale for collectibles)
- ✅ Game speed is 15% slower (more manageable)
- ✅ Spawn rate is 10% slower (fewer drops)
- ✅ Touch targets are easier to hit

## Features Implemented

### Core Systems
- ✅ Platform detection (Android/iOS/small viewport)
- ✅ Orientation detection (portrait/landscape)
- ✅ Safe area handling (notched devices)
- ✅ Configuration file support (mobile_config.cfg)

### UI Scaling
- ✅ Control node scaling (1.5x)
- ✅ Font scaling (1.4x)
- ✅ Button minimum size (100x60px)
- ✅ Touch target minimum size (80x80px)
- ✅ Expanded hit detection (+10px)

### Game Object Scaling
- ✅ Interactive objects (1.4x)
- ✅ Collectibles (1.3x)
- ✅ Draggable minimum size (120x120px)
- ✅ Collision shape preservation

### Touch Input
- ✅ Gesture detection (tap, swipe, hold, drag)
- ✅ Multi-touch support
- ✅ Haptic feedback
- ✅ Edge dead zone (15px)
- ✅ Touch disambiguation

### Layout Management
- ✅ Orientation-based reorganization
- ✅ Safe area margins (20px minimum)
- ✅ Button spacing (20px vertical, 15px horizontal)

### Performance
- ✅ Particle reduction (40%)
- ✅ Tween limiting (max 10)
- ✅ Frame rate monitoring (30 FPS target)
- ✅ Background CPU reduction

### Text Readability
- ✅ Minimum font size (24px)
- ✅ Text outline (4px)
- ✅ Text backdrop (semi-transparent)
- ✅ Contrast ratio checking (4.5:1)
- ✅ Automatic text wrapping

### Demo Button Control
- ✅ Hide demo buttons on mobile
- ✅ Show in debug builds
- ✅ Layout spacing maintained

### Gameplay Adjustments
- ✅ Game speed reduction (15%)
- ✅ Timing window increase (20%)
- ✅ Spawn rate reduction (10%)
- ✅ Drag smoothing (1.5x)
- ✅ Touch zone indicators

### Debug Tools
- ✅ Debug mobile mode simulation
- ✅ Safe area visualization
- ✅ Debug logging
- ✅ FPS monitoring

## Configuration

Edit `mobile_config.cfg` to customize mobile behavior:

```cfg
[scaling]
ui_scale = 1.5          # UI elements 50% larger
font_scale = 1.4        # Fonts 40% larger
game_object_scale = 1.4 # Game objects 40% larger
collectible_scale = 1.3 # Collectibles 30% larger

[gameplay]
speed_reduction = 0.15         # 15% slower
timing_window_increase = 0.2   # 20% larger timing windows
spawn_rate_reduction = 0.1     # 10% slower spawning
drag_smoothing_increase = 1.5  # 50% more drag smoothing
```

## Testing Checklist

### Desktop Testing (Debug Mode)
- [ ] Enable debug mobile mode
- [ ] Enable debug visualization
- [ ] Test main menu scaling
- [ ] Verify demo buttons are hidden
- [ ] Test orientation changes (resize window)
- [ ] Test CatchTheRain minigame
- [ ] Check FPS monitoring logs
- [ ] Verify safe area margins

### Mobile Device Testing (Recommended)
- [ ] Export to Android/iOS
- [ ] Test on actual device
- [ ] Verify touch responsiveness
- [ ] Test haptic feedback
- [ ] Test orientation changes
- [ ] Test all minigames
- [ ] Check performance (30 FPS)
- [ ] Test on notched devices

## Troubleshooting

### Buttons Still Too Small
- Check if MobileUIManager is enabled: `MobileUIManager.is_mobile_platform()`
- Verify debug mode: `MobileUIManager.enable_debug_mobile_mode(true)`
- Check configuration: `mobile_config.cfg` scaling values

### Demo Buttons Still Visible
- Check build type: Demo buttons show in debug builds
- Verify platform detection: Should be hidden on mobile
- Check DemoButtonController logic in MainMenu.gd

### Performance Issues
- Check FPS: `MobileUIManager.get_average_fps()`
- Verify particle reduction is applied
- Check tween count: `PerformanceManager.get_active_tween_count()`
- Enable debug logging to see optimization details

### Layout Issues
- Enable safe area visualization
- Check orientation detection
- Verify LayoutManager is being called
- Check safe area margins in debug overlay

## Next Steps

1. Test on desktop with debug mode enabled
2. Export to mobile device for real-world testing
3. Gather user feedback on mobile experience
4. Adjust configuration values as needed
5. Test on various device sizes and aspect ratios

## API Reference

### MobileUIManager
```gdscript
# Platform detection
MobileUIManager.is_mobile_platform() -> bool
MobileUIManager.is_portrait_orientation() -> bool

# Scaling
MobileUIManager.apply_mobile_scaling(control: Control)
MobileUIManager.apply_game_object_scaling(node: Node2D)

# Debug
MobileUIManager.enable_debug_mobile_mode(enabled: bool)
MobileUIManager.enable_debug_visualization(enabled: bool)
MobileUIManager.enable_debug_logging(enabled: bool)

# Gameplay adjustments
MobileUIManager.get_game_speed_multiplier() -> float
MobileUIManager.get_timing_window_multiplier() -> float
MobileUIManager.get_spawn_rate_multiplier() -> float
```

### TouchInputManager
```gdscript
# Haptics
TouchInputManager.vibrate_button_press()
TouchInputManager.enable_button_haptics(button: BaseButton)
TouchInputManager.enable_haptics_for_scene(root: Node)

# Hit detection
TouchInputManager.is_touch_in_expanded_bounds(pos: Vector2, control: Control) -> bool
TouchInputManager.find_touch_target(pos: Vector2, root: Node) -> Control
```

### UIScaler
```gdscript
# Scaling
UIScaler.scale_control_node(node: Control, scale_factor: float)
UIScaler.scale_font(label: Label, scale_factor: float)
UIScaler.ensure_minimum_size(node: Control, min_size: Vector2)

# Text readability
UIScaler.ensure_minimum_font_size(label: Label, min_size: int)
UIScaler.add_text_outline(label: Label, thickness: int)
UIScaler.add_text_backdrop(label: Label, color: Color)
UIScaler.check_contrast_ratio(text_color: Color, bg_color: Color) -> bool
```

### LayoutManager
```gdscript
# Layout
LayoutManager.reorganize_for_orientation(container: Container, is_portrait: bool)
LayoutManager.apply_safe_area_margins(node: Control, margins: Dictionary)
LayoutManager.apply_button_spacing_vertical(container: VBoxContainer, spacing: float)
LayoutManager.apply_button_spacing_horizontal(container: HBoxContainer, spacing: float)
```

### PerformanceManager
```gdscript
# Performance
PerformanceManager.optimize_particle_system_for_mobile(particles: GPUParticles2D)
PerformanceManager.create_managed_tween(scene_tree: SceneTree) -> Tween
PerformanceManager.get_active_tween_count() -> int
```

### DemoButtonController
```gdscript
# Demo buttons
DemoButtonController.should_show_demo_buttons() -> bool
DemoButtonController.hide_demo_buttons(root: Node)
```

## Support

For issues or questions, check the implementation files:
- `autoload/MobileUIManager.gd` - Core system
- `autoload/TouchInputManager.gd` - Touch input handling
- `scripts/mobile/` - Helper classes
- `test/` - Test scenes and scripts
