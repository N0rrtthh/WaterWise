# Requirements Document

## Introduction

This document specifies the requirements for making the Waterwise Godot game mobile-friendly. The game currently exports to mobile platforms but suffers from poor usability due to UI elements (buttons, text, game objects) being too small for phone screens. Additionally, the demo mode buttons intended for thesis defense should be removed from the production mobile build, and gameplay mechanics need optimization for touch-based interaction to ensure games remain enjoyable on mobile devices.

## Glossary

- **UI_System**: The user interface rendering and layout system in Godot
- **Touch_Handler**: The TouchInputManager autoload that processes touch input and gestures
- **Viewport**: The game's display area that renders content at a specific resolution
- **Control_Node**: Any Godot UI element (Button, Label, Panel, etc.) that inherits from Control
- **Game_Scene**: Any minigame scene that contains interactive gameplay elements
- **Demo_Button**: The algorithm demo, G-Counter demo, and research dashboard buttons on the main menu
- **Safe_Area**: The device screen area excluding notches, rounded corners, and system UI
- **Touch_Target**: An interactive UI element that responds to touch input
- **Responsive_Layout**: A UI layout that adapts to different screen sizes and orientations
- **Mobile_Platform**: Android or iOS operating systems
- **Desktop_Platform**: Windows, macOS, or Linux operating systems

## Requirements

### Requirement 1: Responsive UI Scaling

**User Story:** As a mobile player, I want UI elements to be appropriately sized for my phone screen, so that I can easily read text and tap buttons without frustration.

#### Acceptance Criteria

1. WHEN the game runs on a Mobile_Platform, THE UI_System SHALL scale all Control_Nodes to be at least 1.5x their desktop size
2. WHEN the game runs on a Mobile_Platform, THE UI_System SHALL ensure all Touch_Targets have a minimum size of 80x80 pixels
3. WHEN the game runs on a Mobile_Platform, THE UI_System SHALL scale font sizes by a factor of 1.3x to 1.5x for improved readability
4. WHEN the Viewport width is less than 800 pixels, THE UI_System SHALL apply mobile scaling regardless of platform
5. THE UI_System SHALL maintain aspect ratios of visual elements during scaling operations
6. WHEN a Control_Node is scaled for mobile, THE UI_System SHALL ensure the element remains within the Safe_Area boundaries

### Requirement 2: Touch-Optimized Button Sizing

**User Story:** As a mobile player, I want buttons to be large enough to tap accurately, so that I don't accidentally miss or hit the wrong button.

#### Acceptance Criteria

1. WHEN the game runs on a Mobile_Platform, THE UI_System SHALL ensure all Button nodes have a minimum size of 100x60 pixels
2. WHEN multiple buttons are displayed vertically, THE UI_System SHALL maintain a minimum spacing of 20 pixels between Touch_Targets
3. WHEN multiple buttons are displayed horizontally, THE UI_System SHALL maintain a minimum spacing of 15 pixels between Touch_Targets
4. THE UI_System SHALL increase the hit detection area of buttons by 10 pixels beyond their visual boundaries on Mobile_Platform
5. WHEN a button is pressed on Mobile_Platform, THE Touch_Handler SHALL provide haptic feedback

### Requirement 3: Game Object Scaling for Mobile

**User Story:** As a mobile player, I want game objects (like the drum in Catch The Rain) to be large enough to interact with easily, so that gameplay feels responsive and enjoyable.

#### Acceptance Criteria

1. WHEN a Game_Scene loads on Mobile_Platform, THE Game_Scene SHALL scale interactive game objects to be at least 1.4x their desktop size
2. WHEN a Game_Scene contains draggable objects, THE Game_Scene SHALL ensure the draggable area is at least 120x120 pixels
3. WHEN a Game_Scene contains collectible items (like raindrops), THE Game_Scene SHALL scale them to be at least 1.3x their desktop size
4. WHEN a player drags an object on Mobile_Platform, THE Touch_Handler SHALL provide visual feedback showing the drag is active
5. THE Game_Scene SHALL maintain collision detection accuracy after scaling operations

### Requirement 4: Demo Button Removal

**User Story:** As a mobile player, I want a clean main menu without development/testing buttons, so that the interface is not cluttered with options I don't need.

#### Acceptance Criteria

1. WHEN the game runs on Mobile_Platform, THE UI_System SHALL hide all Demo_Button instances from the main menu
2. WHEN the game is built with a production export preset, THE UI_System SHALL exclude Demo_Button creation code from execution
3. THE UI_System SHALL maintain proper layout spacing after Demo_Button removal
4. WHEN the game runs on Desktop_Platform in debug mode, THE UI_System SHALL display Demo_Button instances
5. THE UI_System SHALL provide a configuration flag to control Demo_Button visibility independent of platform

### Requirement 5: Adaptive Layout System

**User Story:** As a mobile player, I want the UI to adapt to my device's screen orientation and size, so that the game looks good whether I hold my phone vertically or horizontally.

#### Acceptance Criteria

1. WHEN the device orientation changes, THE UI_System SHALL reorganize Control_Nodes within 0.5 seconds
2. WHEN the Viewport is in portrait mode, THE UI_System SHALL use a vertical layout for menu buttons
3. WHEN the Viewport is in landscape mode, THE UI_System SHALL use a horizontal or grid layout for menu buttons
4. THE UI_System SHALL respect the Safe_Area margins on devices with notches or rounded corners
5. WHEN the screen size changes, THE Responsive_Layout SHALL recalculate element positions without visual glitches
6. THE UI_System SHALL maintain a minimum margin of 20 pixels from Safe_Area boundaries for all interactive elements

### Requirement 6: Touch Input Optimization

**User Story:** As a mobile player, I want touch controls to feel natural and responsive, so that I can play games smoothly without lag or missed inputs.

#### Acceptance Criteria

1. WHEN a player touches the screen, THE Touch_Handler SHALL register the input within 16 milliseconds
2. WHEN a player performs a swipe gesture, THE Touch_Handler SHALL detect the direction and emit a signal with velocity data
3. WHEN a player holds a touch for more than 0.5 seconds, THE Touch_Handler SHALL emit a hold signal
4. THE Touch_Handler SHALL support multi-touch input for games that require simultaneous touches
5. WHEN a touch input is ambiguous between two Touch_Targets, THE Touch_Handler SHALL prioritize the larger or closer target
6. THE Touch_Handler SHALL prevent accidental touches near screen edges by implementing a 15-pixel dead zone

### Requirement 7: Performance Optimization for Mobile

**User Story:** As a mobile player, I want the game to run smoothly on my phone, so that I can enjoy gameplay without stuttering or battery drain.

#### Acceptance Criteria

1. WHEN the game runs on Mobile_Platform, THE UI_System SHALL maintain a frame rate of at least 30 FPS during gameplay
2. WHEN the game runs on Mobile_Platform, THE UI_System SHALL reduce particle effects by 40% compared to desktop
3. WHEN a Game_Scene loads on Mobile_Platform, THE Game_Scene SHALL complete loading within 3 seconds
4. THE UI_System SHALL use texture compression appropriate for Mobile_Platform (ETC2/ASTC)
5. WHEN the game is in the background on Mobile_Platform, THE UI_System SHALL pause all animations and reduce CPU usage by at least 80%
6. THE UI_System SHALL limit simultaneous tween animations to 10 or fewer on Mobile_Platform

### Requirement 8: Text Readability Enhancement

**User Story:** As a mobile player, I want all text to be clear and readable on my small screen, so that I can understand instructions and game information without straining my eyes.

#### Acceptance Criteria

1. WHEN the game runs on Mobile_Platform, THE UI_System SHALL ensure all Label nodes use a minimum font size of 24 pixels
2. WHEN text is displayed over game backgrounds, THE UI_System SHALL add a semi-transparent backdrop or outline for contrast
3. THE UI_System SHALL increase text outline thickness to at least 4 pixels on Mobile_Platform for improved visibility
4. WHEN instruction text exceeds the Viewport width, THE UI_System SHALL enable word wrapping and adjust layout height
5. THE UI_System SHALL use high-contrast color combinations (contrast ratio of at least 4.5:1) for all text on Mobile_Platform

### Requirement 9: Mobile-Specific Game Adjustments

**User Story:** As a mobile player, I want games to be balanced for touch controls, so that they remain fun and not frustratingly difficult on mobile.

#### Acceptance Criteria

1. WHEN a Game_Scene loads on Mobile_Platform, THE Game_Scene SHALL reduce game speed by 15% compared to desktop
2. WHEN a Game_Scene uses drag controls on Mobile_Platform, THE Game_Scene SHALL increase the drag smoothing factor to reduce jitter
3. WHEN a Game_Scene requires precise timing on Mobile_Platform, THE Game_Scene SHALL increase the success window by 20%
4. WHEN a Game_Scene spawns collectible items on Mobile_Platform, THE Game_Scene SHALL reduce spawn rate by 10% to account for touch input latency
5. THE Game_Scene SHALL provide visual indicators for touch zones that are at least 30% larger than the actual interactive area

### Requirement 10: Configuration and Testing Support

**User Story:** As a developer, I want to test mobile responsiveness on desktop, so that I can iterate quickly without deploying to a physical device.

#### Acceptance Criteria

1. THE UI_System SHALL provide a debug flag to simulate Mobile_Platform behavior on Desktop_Platform
2. WHEN the debug flag is enabled, THE UI_System SHALL apply all mobile scaling and layout rules
3. THE UI_System SHALL display on-screen indicators showing Safe_Area boundaries when in debug mode
4. THE UI_System SHALL log all scaling operations and layout changes when debug logging is enabled
5. THE UI_System SHALL provide a configuration file to customize mobile scaling factors without code changes
6. WHEN the configuration file is modified, THE UI_System SHALL reload settings without requiring a game restart
