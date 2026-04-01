# Implementation Plan: Mobile Responsive UI

## Overview

This implementation plan converts the mobile responsive UI design into actionable coding tasks. The approach follows an incremental strategy: first establishing the core MobileUIManager autoload and configuration system, then implementing scaling and layout components, integrating with existing TouchInputManager, adding performance optimizations, and finally wiring everything together with scene integration and testing.

## Tasks

- [x] 1. Set up MobileUIManager autoload and configuration system
  - [x] 1.1 Create MobileUIManager autoload script with platform detection
    - Create `res://autoload/MobileUIManager.gd` with signals, configuration exports, and state variables
    - Implement `_ready()` to detect platform (OS.get_name() for Android/iOS) and viewport size (<800px)
    - Implement public interface methods: `is_mobile_platform()`, `get_ui_scale()`, `get_font_scale()`, etc.
    - Add debug flag support with `enable_debug_mobile_mode(enabled: bool)`
    - _Requirements: 1.1, 1.4, 10.1, 10.2_
  
  - [ ]* 1.2 Write property test for platform detection
    - **Property 36: Debug Mobile Mode Simulation**
    - **Validates: Requirements 10.1, 10.2**
  
  - [x] 1.3 Create MobileConfig data model for configuration management
    - Create `res://scripts/mobile/MobileConfig.gd` class with all scaling factors and thresholds
    - Implement `load_from_file(path: String)` using ConfigFile API
    - Implement `save_to_file(path: String)` for persistence
    - Add default configuration values matching design specifications
    - _Requirements: 10.5, 10.6_
  
  - [x] 1.4 Create SafeAreaInfo data model for device safe area handling
    - Create `res://scripts/mobile/SafeAreaInfo.gd` class
    - Implement `from_display_safe_area()` using DisplayServer.get_display_safe_area()
    - Implement `to_dictionary()` for easy access to margins
    - Add error handling for invalid safe area data
    - _Requirements: 5.4, 1.6_
  
  - [ ]* 1.5 Write unit tests for configuration loading and safe area calculation
    - Test config file loading with valid and invalid data
    - Test safe area calculation with various device configurations
    - Test fallback to defaults when config is missing
    - _Requirements: 10.5, 5.4_

- [x] 2. Implement UI scaling components
  - [x] 2.1 Create UIScaler helper class for Control node scaling
    - Create `res://scripts/mobile/UIScaler.gd` with static methods
    - Implement `scale_control_node(node: Control, scale_factor: float)` preserving aspect ratio
    - Implement `scale_font(label: Label, scale_factor: float)` for font size scaling
    - Implement `ensure_minimum_size(node: Control, min_size: Vector2)` for touch target requirements
    - _Requirements: 1.1, 1.2, 1.3, 1.5_
  
  - [ ]* 2.2 Write property test for UI scaling consistency
    - **Property 1: Mobile UI Scaling Consistency**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
  
  - [ ]* 2.3 Write property test for aspect ratio preservation
    - **Property 2: Aspect Ratio Preservation**
    - **Validates: Requirements 1.5**
  
  - [x] 2.4 Implement button-specific scaling in MobileUIManager
    - Add `apply_mobile_scaling(node: Control)` method to MobileUIManager
    - Ensure buttons meet minimum size of 100x60 pixels
    - Add 10-pixel expanded hit detection area for buttons
    - Apply font scaling to button labels
    - _Requirements: 2.1, 2.4, 1.3_
  
  - [ ]* 2.5 Write property test for button minimum size
    - **Property 4: Button Minimum Size**
    - **Validates: Requirements 2.1**
  
  - [x] 2.6 Implement game object scaling method
    - Add `apply_game_object_scaling(node: Node2D)` to MobileUIManager
    - Scale interactive objects by 1.4x and collectibles by 1.3x
    - Ensure draggable objects have minimum 120x120 pixel area
    - Preserve collision shapes during scaling
    - _Requirements: 3.1, 3.2, 3.3, 3.5_
  
  - [ ]* 2.7 Write property test for game object scaling
    - **Property 8: Game Object Scaling**
    - **Validates: Requirements 3.1, 3.3**
  
  - [ ]* 2.8 Write property test for collision detection invariant
    - **Property 11: Collision Detection Invariant**
    - **Validates: Requirements 3.5**

- [x] 3. Implement layout management and orientation handling
  - [x] 3.1 Create LayoutManager helper class
    - Create `res://scripts/mobile/LayoutManager.gd` with static methods
    - Implement `reorganize_for_orientation(container: Container, is_portrait: bool)`
    - Implement `apply_safe_area_margins(node: Control, margins: Dictionary)`
    - Implement button spacing methods for vertical and horizontal layouts
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.6, 2.2, 2.3_
  
  - [x] 3.2 Add orientation detection to MobileUIManager
    - Implement viewport size monitoring in `_process(delta)`
    - Detect orientation changes (portrait vs landscape)
    - Emit `orientation_changed` signal when orientation changes
    - Trigger layout reorganization within 0.5 seconds
    - _Requirements: 5.1, 5.2, 5.3_
  
  - [ ]* 3.3 Write property test for orientation-based layout adaptation
    - **Property 14: Orientation-Based Layout Adaptation**
    - **Validates: Requirements 5.1, 5.2, 5.3**
  
  - [x] 3.3 Implement safe area margin application
    - Calculate safe area margins on initialization using SafeAreaInfo
    - Emit `safe_area_changed` signal with margin dictionary
    - Apply 20-pixel minimum margin from safe area boundaries
    - _Requirements: 5.4, 5.6, 1.6_
  
  - [ ]* 3.4 Write property test for safe area boundary compliance
    - **Property 3: Safe Area Boundary Compliance**
    - **Validates: Requirements 1.6, 5.4, 5.6**
  
  - [ ]* 3.5 Write property test for button spacing
    - **Property 5: Button Spacing**
    - **Validates: Requirements 2.2, 2.3**

- [x] 4. Checkpoint - Ensure core scaling and layout systems work
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Integrate with TouchInputManager for mobile input optimization
  - [x] 5.1 Add haptic feedback to TouchInputManager for button presses
    - Modify `res://autoload/TouchInputManager.gd` to detect mobile platform
    - Add `Input.vibrate_handheld(50)` call on button press events
    - Ensure haptic feedback only triggers on mobile platforms
    - _Requirements: 2.5_
  
  - [ ]* 5.2 Write property test for haptic feedback
    - **Property 7: Haptic Feedback on Button Press**
    - **Validates: Requirements 2.5**
  
  - [x] 5.3 Implement expanded hit detection for touch targets
    - Add 10-pixel expansion to button touch areas in TouchInputManager
    - Modify touch event processing to check expanded bounds
    - _Requirements: 2.4_
  
  - [ ]* 5.4 Write property test for expanded hit detection
    - **Property 6: Expanded Hit Detection**
    - **Validates: Requirements 2.4**
  
  - [x] 5.5 Add edge dead zone to TouchInputManager
    - Implement 15-pixel dead zone from screen edges
    - Filter touch events within dead zone
    - _Requirements: 6.6_
  
  - [ ]* 5.6 Write property test for edge dead zone
    - **Property 21: Edge Dead Zone**
    - **Validates: Requirements 6.6**
  
  - [x] 5.7 Verify existing gesture detection meets requirements
    - Confirm swipe detection emits direction and velocity data
    - Confirm hold detection (>0.5s) emits hold signal
    - Confirm multi-touch support for simultaneous touches
    - Confirm touch disambiguation prioritizes larger/closer targets
    - _Requirements: 6.2, 6.3, 6.4, 6.5_
  
  - [ ]* 5.8 Write property tests for gesture detection
    - **Property 17: Gesture Detection**
    - **Property 18: Hold Gesture Detection**
    - **Property 19: Multi-touch Support**
    - **Property 20: Touch Disambiguation**
    - **Validates: Requirements 6.2, 6.3, 6.4, 6.5**
  
  - [ ]* 5.9 Write property test for touch input latency
    - **Property 16: Touch Input Latency**
    - **Validates: Requirements 6.1**

- [-] 6. Implement performance optimization components
  - [x] 6.1 Create PerformanceManager helper class
    - Create `res://scripts/mobile/PerformanceManager.gd` with static methods
    - Implement `reduce_particles(particle_system: GPUParticles2D, reduction_factor: float)`
    - Implement `limit_active_tweens(max_tweens: int)` with tween tracking
    - Implement `optimize_textures_for_mobile()` to verify ETC2/ASTC compression
    - _Requirements: 7.2, 7.6, 7.4_
  
  - [ ]* 6.2 Write property test for particle reduction
    - **Property 23: Particle Reduction**
    - **Validates: Requirements 7.2**
  
  - [ ]* 6.3 Write property test for tween animation limiting
    - **Property 27: Tween Animation Limiting**
    - **Validates: Requirements 7.6**
  
  - [x] 6.2 Add frame rate monitoring to MobileUIManager
    - Track FPS in `_process(delta)` using Engine.get_frames_per_second()
    - Log warnings when FPS drops below 30 on mobile
    - Automatically trigger additional optimizations if FPS is low
    - _Requirements: 7.1_
  
  - [-] 6.3 Implement background CPU reduction
    - Connect to SceneTree notification for app pause/resume
    - Pause all animations when app goes to background
    - Reduce process priority and disable unnecessary updates
    - _Requirements: 7.5_
  
  - [ ]* 6.4 Write property test for background CPU reduction
    - **Property 26: Background CPU Reduction**
    - **Validates: Requirements 7.5**

- [x] 7. Implement text readability enhancements
  - [x] 7.1 Add text scaling and contrast methods to UIScaler
    - Implement `ensure_minimum_font_size(label: Label, min_size: int)` for 24px minimum
    - Implement `add_text_outline(label: Label, thickness: int)` for 4px outline
    - Implement `add_text_backdrop(label: Label)` for semi-transparent background
    - Implement `check_contrast_ratio(text_color: Color, bg_color: Color)` for 4.5:1 ratio
    - _Requirements: 8.1, 8.2, 8.3, 8.5_
  
  - [ ]* 7.2 Write property test for text minimum font size
    - **Property 28: Text Minimum Font Size**
    - **Validates: Requirements 8.1**
  
  - [ ]* 7.3 Write property test for text contrast enhancement
    - **Property 29: Text Contrast Enhancement**
    - **Validates: Requirements 8.2, 8.3, 8.5**
  
  - [x] 7.2 Implement text wrapping for long instruction text
    - Add automatic word wrapping detection for labels exceeding viewport width
    - Adjust container height to accommodate wrapped text
    - _Requirements: 8.4_
  
  - [ ]* 7.4 Write property test for text wrapping
    - **Property 30: Text Wrapping**
    - **Validates: Requirements 8.4**

- [ ] 8. Implement demo button visibility controller
  - [x] 8.1 Create DemoButtonController helper class
    - Create `res://scripts/mobile/DemoButtonController.gd` with static methods
    - Implement `should_show_demo_buttons()` checking platform, build config, and debug flags
    - Implement `hide_demo_buttons(root: Node)` to find and hide demo buttons
    - Implement `_find_demo_buttons(root: Node)` to locate buttons by name or group
    - _Requirements: 4.1, 4.2, 4.4, 4.5_
  
  - [ ]* 8.2 Write property test for demo button visibility control
    - **Property 12: Demo Button Visibility Control**
    - **Validates: Requirements 4.1, 4.4, 4.5**
  
  - [x] 8.2 Integrate demo button controller with main menu
    - Modify main menu scene to call DemoButtonController on ready
    - Ensure layout spacing is maintained after button removal
    - _Requirements: 4.3_
  
  - [ ]* 8.3 Write property test for layout spacing after button removal
    - **Property 13: Layout Spacing After Button Removal**
    - **Validates: Requirements 4.3**

- [ ] 9. Checkpoint - Ensure all helper components are functional
  - Ensure all tests pass, ask the user if questions arise.

- [-] 10. Implement mobile-specific game adjustments
  - [x] 10.1 Add game speed reduction to MobileUIManager
    - Implement `get_mobile_game_speed_multiplier()` returning 0.85 (15% reduction)
    - Provide method for game scenes to query and apply speed adjustment
    - _Requirements: 9.1_
  
  - [ ]* 10.2 Write property test for mobile game speed reduction
    - **Property 31: Mobile Game Speed Reduction**
    - **Validates: Requirements 9.1**
  
  - [-] 10.2 Add drag smoothing configuration
    - Implement `get_mobile_drag_smoothing_factor()` for increased smoothing
    - Provide integration point for game scenes using drag controls
    - _Requirements: 9.2_
  
  - [ ]* 10.3 Write property test for drag smoothing
    - **Property 32: Drag Smoothing**
    - **Validates: Requirements 9.2**
  
  - [x] 10.3 Add timing window and spawn rate adjustments
    - Implement `get_mobile_timing_window_multiplier()` returning 1.2 (20% increase)
    - Implement `get_mobile_spawn_rate_multiplier()` returning 0.9 (10% reduction)
    - _Requirements: 9.3, 9.4_
  
  - [ ]* 10.4 Write property tests for timing and spawn rate adjustments
    - **Property 33: Timing Window Increase**
    - **Property 34: Spawn Rate Reduction**
    - **Validates: Requirements 9.3, 9.4**
  
  - [x] 10.4 Implement visual indicator scaling for touch zones
    - Add method to scale visual indicators 30% larger than interactive areas
    - Provide helper for game scenes to create touch zone indicators
    - _Requirements: 9.5_
  
  - [ ]* 10.5 Write property test for visual indicator sizing
    - **Property 35: Visual Indicator Sizing**
    - **Validates: Requirements 9.5**

- [-] 11. Integrate mobile UI system with existing game scenes
  - [x] 11.1 Modify main menu scene for mobile responsiveness
    - Add MobileUIManager initialization call in main menu `_ready()`
    - Apply mobile scaling to all buttons and UI elements
    - Integrate DemoButtonController to hide demo buttons on mobile
    - Apply safe area margins to main container
    - Test orientation changes and layout reorganization
    - _Requirements: 1.1, 1.2, 2.1, 4.1, 5.4_
  
  - [x] 11.2 Create base minigame script with mobile support
    - Create `res://scripts/mobile/MobileGameBase.gd` extending Node
    - Add `_ready()` override to apply mobile scaling to game objects
    - Add methods to query mobile adjustments (speed, timing, spawn rate)
    - Provide drag visual feedback implementation
    - _Requirements: 3.1, 3.4, 9.1, 9.2, 9.3, 9.4_
  
  - [x] 11.3 Update CatchTheRain minigame for mobile
    - Extend MobileGameBase in CatchTheRain scene script
    - Apply game object scaling to drum and raindrops
    - Apply mobile speed reduction and spawn rate adjustment
    - Add visual indicators for touch zones
    - Test collision detection after scaling
    - _Requirements: 3.1, 3.3, 3.5, 9.1, 9.4, 9.5_
  
  - [x] 11.4 Update drag-based minigames for mobile
    - Apply draggable object minimum size (120x120px)
    - Implement drag visual feedback (highlight, shadow, or scale effect)
    - Apply drag smoothing factor for reduced jitter
    - Test drag accuracy and responsiveness
    - _Requirements: 3.2, 3.4, 9.2_
  
  - [-] 11.5 Update timing-based minigames for mobile
    - Apply timing window increase (20%) for success detection
    - Test gameplay balance on mobile
    - _Requirements: 9.3_
  
  - [ ]* 11.6 Write property test for drag visual feedback
    - **Property 10: Drag Visual Feedback**
    - **Validates: Requirements 3.4**
  
  - [ ]* 11.7 Write integration tests for scene loading
    - Test mobile scene loads with proper scaling applied
    - Test demo buttons hidden on mobile in main menu
    - Test all buttons meet minimum size requirements
    - _Requirements: 1.1, 2.1, 4.1_

- [x] 12. Implement debug and testing support
  - [x] 12.1 Add debug visualization for safe area boundaries
    - Create debug overlay showing safe area margins as colored rectangles
    - Toggle visibility with debug flag
    - _Requirements: 10.3_
  
  - [x] 12.2 Add debug logging for scaling operations
    - Log all scaling operations with node name, original size, and final size
    - Log layout reorganization events with timing
    - Log performance metrics (FPS, particle counts, active tweens)
    - Enable/disable with debug logging flag
    - _Requirements: 10.4_
  
  - [ ]* 12.3 Write property test for debug logging
    - **Property 37: Debug Logging**
    - **Validates: Requirements 10.4**
  
  - [x] 12.3 Create default mobile configuration file
    - Create `res://mobile_config.cfg` with all default values
    - Document each configuration option with comments
    - Test hot-reload functionality
    - _Requirements: 10.5, 10.6_
  
  - [ ]* 12.4 Write property test for configuration file support
    - **Property 38: Configuration File Support**
    - **Validates: Requirements 10.5, 10.6**

- [x] 13. Add MobileUIManager to project autoload configuration
  - [x] 13.1 Register MobileUIManager as autoload singleton
    - Open Project Settings > Autoload
    - Add `res://autoload/MobileUIManager.gd` as "MobileUIManager"
    - Ensure it loads before scene tree initialization
    - _Requirements: 1.1_

- [-] 14. Final checkpoint - Comprehensive testing and validation
  - [ ] 14.1 Run all property-based tests
    - Execute all 38 property tests with 100+ iterations each
    - Verify all properties hold across randomized inputs
    - Fix any property violations discovered
  
  - [ ] 14.2 Run all unit tests
    - Execute platform detection tests
    - Execute scaling and layout tests
    - Execute performance optimization tests
    - Execute integration tests
  
  - [x] 14.3 Manual testing on desktop with debug mobile mode
    - Enable debug mobile mode flag
    - Test main menu with mobile scaling
    - Test multiple minigames with mobile adjustments
    - Test orientation changes
    - Verify safe area visualization
    - Test configuration file hot-reload
    - _Requirements: 10.1, 10.2, 10.3_
  
  - [x] 14.4 Final validation
    - Ensure all tests pass
    - Verify no performance regressions on desktop
    - Confirm all requirements are covered by implementation
    - Ask the user if questions arise or if ready for mobile device testing

## Notes

- Tasks marked with `*` are optional testing tasks and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical breakpoints
- Property tests validate universal correctness properties across all inputs
- Unit tests validate specific examples, edge cases, and integration points
- The implementation follows a bottom-up approach: core components first, then integration
- Manual testing on actual mobile devices is recommended after completing all tasks
- GDScript is used throughout as specified in the design document
