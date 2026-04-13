# Implementation Plan: Animated Character Cutscenes

## Overview

This implementation plan breaks down the "Dumb Ways to Die" style animated cutscenes feature into discrete coding tasks. The system will replace emoji-based cutscenes with expressive, animated water droplet characters that appear during intro, win, and fail scenarios. The implementation follows a bottom-up approach: core components first (character, animation engine, parser), then integration layer (cutscene player), and finally wiring with existing game systems.

## Tasks

- [x] 1. Set up project structure and core data models
  - Create directory structure for cutscene system
  - Define core enums and constants (CutsceneType, Expression, ParticleType, Easing)
  - Create data model classes (CutsceneConfig, Keyframe, Transform, ValidationResult)
  - Set up cutscene asset directories (res://data/cutscenes/, res://assets/characters/, res://assets/particles/)
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [~] 2. Implement WaterDropletCharacter component
  - [x] 2.1 Create WaterDropletCharacter scene and script
    - Create Node2D-based character scene with sprite nodes
    - Implement expression system with facial overlays
    - Add body deformation support (squash/stretch via scale modulation)
    - Implement particle effect spawning integration
    - _Requirements: 4.1, 4.2, 4.3, 4.5, 1.1_

  - [x] 2.2 Write property test for expression state changes
    - **Property 9: Expression State Changes**
    - **Validates: Requirements 4.2**

  - [x] 2.3 Write property test for body deformation
    - **Property 10: Body Deformation**
    - **Validates: Requirements 4.3**


- [~] 3. Implement AnimationEngine component
  - [x] 3.1 Create AnimationEngine script with easing functions
    - Implement all easing functions (linear, ease_in, ease_out, ease_in_out, bounce, elastic, back)
    - Create apply_transform method for single transformations
    - Create compose_transforms method for parallel transformations
    - Implement animate method for full keyframe sequences
    - Add Tween management and cleanup
    - _Requirements: 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

  - [x] 3.2 Write property test for transform application
    - **Property 1: Transform Application**
    - **Validates: Requirements 1.3, 1.4, 1.5**

  - [x] 3.3 Write property test for layered transform composition
    - **Property 2: Layered Transform Composition**
    - **Validates: Requirements 1.6**

  - [x] 3.4 Write property test for animation timing accuracy
    - **Property 3: Animation Timing Accuracy**
    - **Validates: Requirements 1.7, 6.7, 14.6**

  - [x] 3.5 Write property test for easing function interpolation
    - **Property 4: Easing Function Interpolation**
    - **Validates: Requirements 1.8**

- [~] 4. Implement CutsceneParser component
  - [x] 4.1 Create CutsceneParser script with validation
    - Implement parse_config method for loading from file paths
    - Implement parse_dict method for loading from dictionaries
    - Create validate_config method with comprehensive validation rules
    - Implement pretty_print method for debugging output
    - Add error handling with descriptive messages
    - Support both JSON and GDScript resource formats
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 4.2 Write property test for configuration file parsing
    - **Property 11: Configuration File Parsing**
    - **Validates: Requirements 5.1, 10.1**

  - [x] 4.3 Write property test for configuration format support
    - **Property 12: Configuration Format Support**
    - **Validates: Requirements 5.2, 5.3, 5.4, 5.5, 5.6**

  - [x] 4.4 Write property test for configuration validation
    - **Property 13: Configuration Validation**
    - **Validates: Requirements 5.7, 10.2, 10.3**

  - [x] 4.5 Write property test for configuration round-trip
    - **Property 15: Configuration Round-Trip**
    - **Validates: Requirements 10.6**

  - [x] 4.6 Write property test for pretty printer round-trip
    - **Property 16: Pretty Printer Round-Trip**
    - **Validates: Requirements 11.5**

  - [x] 4.7 Write property test for pretty printer data preservation
    - **Property 17: Pretty Printer Data Preservation**
    - **Validates: Requirements 11.1, 11.2, 11.3, 11.4**


- [~] 5. Checkpoint - Core components complete
  - Ensure all tests pass, ask the user if questions arise.

- [~] 6. Implement AnimatedCutscenePlayer orchestrator
  - [x] 6.1 Create AnimatedCutscenePlayer scene and script
    - Create Control-based scene for cutscene rendering
    - Implement play_cutscene method with minigame_key and cutscene_type parameters
    - Add preload_cutscene method for asset preloading
    - Implement has_custom_cutscene method for checking custom animations
    - Add configuration loading logic with fallback hierarchy
    - Implement character lifecycle management (instantiation, cleanup)
    - Coordinate AnimationEngine and CutsceneParser
    - Add cutscene_finished signal emission
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 3.1, 3.2, 12.1_

  - [x] 6.2 Write property test for cutscene duration bounds
    - **Property 5: Cutscene Duration Bounds**
    - **Validates: Requirements 2.7, 14.1, 14.2, 14.3**

  - [-] 6.3 Write property test for minigame-specific configuration loading
    - **Property 6: Minigame-Specific Configuration Loading**
    - **Validates: Requirements 3.1, 3.2, 12.1**

  - [~] 6.4 Write property test for themed visual effects
    - **Property 7: Themed Visual Effects**
    - **Validates: Requirements 3.3**

  - [~] 6.5 Write property test for character consistency
    - **Property 8: Character Consistency**
    - **Validates: Requirements 4.1**

  - [~] 6.6 Write property test for game flow pause and resume
    - **Property 18: Game Flow Pause and Resume**
    - **Validates: Requirements 6.4, 6.5**

  - [~] 6.7 Write property test for async completion support
    - **Property 19: Async Completion Support**
    - **Validates: Requirements 6.6**

- [~] 7. Implement visual effects and polish
  - [x] 7.1 Add particle effect system
    - Create particle effect scenes for each type (sparkles, water_drops, stars, smoke, splash)
    - Implement particle spawning at keyframe times
    - Add contextual particle selection (celebratory for win, failure for fail)
    - Implement adaptive particle density based on performance
    - _Requirements: 7.1, 7.4, 7.5, 9.5_

  - [x] 7.2 Add background color transitions
    - Implement background color tween system
    - Add smooth color interpolation between cutscene states
    - _Requirements: 7.2_

  - [x] 7.3 Add screen shake effect
    - Implement camera shake with configurable intensity and duration
    - Add screen shake triggers at dramatic keyframes
    - _Requirements: 7.3_

  - [x] 7.4 Add text overlay animation system
    - Create animated text overlay component
    - Implement text animation parameters (fade, slide, bounce)
    - _Requirements: 7.6_

  - [~] 7.5 Write property test for particle effect support
    - **Property 20: Particle Effect Support**
    - **Validates: Requirements 7.1**

  - [~] 7.6 Write property test for background color transitions
    - **Property 21: Background Color Transitions**
    - **Validates: Requirements 7.2**

  - [~] 7.7 Write property test for screen shake effect
    - **Property 22: Screen Shake Effect**
    - **Validates: Requirements 7.3**

  - [~] 7.8 Write property test for contextual particle effects
    - **Property 23: Contextual Particle Effects**
    - **Validates: Requirements 7.4, 7.5**

  - [~] 7.9 Write property test for text overlay animation
    - **Property 24: Text Overlay Animation**
    - **Validates: Requirements 7.6**


- [~] 8. Implement audio integration
  - [x] 8.1 Add audio cue system to AnimatedCutscenePlayer
    - Integrate with existing AudioManager
    - Implement audio cue triggering at keyframe times
    - Add contextual sound selection (success sounds for win, failure sounds for fail)
    - Implement audio synchronization with animation timing
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

  - [~] 8.2 Write property test for audio synchronization
    - **Property 26: Audio Synchronization**
    - **Validates: Requirements 8.1, 8.5, 8.6**

  - [~] 8.3 Write property test for contextual audio
    - **Property 27: Contextual Audio**
    - **Validates: Requirements 8.3, 8.4**

- [~] 9. Implement performance optimizations
  - [x] 9.1 Add asset preloading system
    - Implement preload_cutscene method for loading assets during initialization
    - Create animation data caching system
    - Add texture atlas support for character sprites
    - _Requirements: 9.1, 9.2, 9.4_

  - [x] 9.2 Add resource cleanup system
    - Implement cleanup method to free tweens, particles, and temporary nodes
    - Add memory monitoring and adaptive quality reduction
    - Implement object pooling for particle effects
    - _Requirements: 9.5, 9.6_

  - [~] 9.3 Write property test for frame rate performance
    - **Property 25: Frame Rate Performance**
    - **Validates: Requirements 7.7, 9.3**

  - [~] 9.4 Write property test for asset preloading
    - **Property 28: Asset Preloading**
    - **Validates: Requirements 9.1**

  - [~] 9.5 Write property test for animation data caching
    - **Property 29: Animation Data Caching**
    - **Validates: Requirements 9.2**

  - [~] 9.6 Write property test for texture atlas support
    - **Property 30: Texture Atlas Support**
    - **Validates: Requirements 9.4**

  - [~] 9.7 Write property test for adaptive particle density
    - **Property 31: Adaptive Particle Density**
    - **Validates: Requirements 9.5**

  - [~] 9.8 Write property test for resource cleanup
    - **Property 32: Resource Cleanup**
    - **Validates: Requirements 9.6**

- [x] 10. Checkpoint - Core system complete
  - Ensure all tests pass, ask the user if questions arise.


- [~] 11. Implement error handling and fallback system
  - [x] 11.1 Add configuration error handling
    - Implement error handling for missing configuration files
    - Add validation error handling with default value fallback
    - Implement descriptive error logging
    - _Requirements: 5.7, 5.8, 10.2, 10.3, 12.3_

  - [x] 11.2 Add asset loading error handling
    - Implement fallback to legacy emoji cutscenes on asset load failure
    - Add graceful degradation for missing particle textures
    - Implement audio file failure handling (play without audio)
    - _Requirements: 12.2, 12.4_

  - [x] 11.3 Add runtime error handling
    - Implement animation engine failure recovery
    - Add memory allocation failure handling
    - Ensure game progression never blocks on cutscene errors
    - _Requirements: 12.5_

  - [~] 11.4 Write property test for invalid data fallback
    - **Property 14: Invalid Data Fallback**
    - **Validates: Requirements 5.8, 12.3, 12.4, 12.5**

  - [~] 11.5 Write property test for asset load failure fallback
    - **Property 35: Asset Load Failure Fallback**
    - **Validates: Requirements 12.2**

- [~] 12. Create default animation profiles
  - [x] 12.1 Create default win cutscene configuration
    - Define default win animation with pop-in, bounce, and settle
    - Set happy expression and sparkle particles
    - Configure success audio cues
    - Save as res://data/cutscenes/default/win.json
    - _Requirements: 2.2, 2.5, 3.2_

  - [~] 12.2 Create default fail cutscene configuration
    - Define default fail animation with drop, impact, and wobble
    - Set sad expression and smoke particles
    - Configure failure audio cues
    - Save as res://data/cutscenes/default/fail.json
    - _Requirements: 2.3, 2.6, 3.2_

  - [~] 12.3 Create default intro cutscene configuration
    - Define default intro animation with slide-in and anticipation
    - Set determined expression with no particles
    - Configure intro audio cues
    - Save as res://data/cutscenes/default/intro.json
    - _Requirements: 2.1, 2.4, 3.2_

- [~] 13. Implement animation variant system
  - [~] 13.1 Add variant selection logic
    - Implement random variant selection from available animations
    - Add recent animation tracking to avoid immediate repetition
    - Implement exclusion of animations played in last 2 attempts
    - Add even distribution logic for variant selection
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5_

  - [~] 13.2 Write property test for animation variant selection
    - **Property 38: Animation Variant Selection**
    - **Validates: Requirements 15.1**

  - [~] 13.3 Write property test for recent animation exclusion
    - **Property 39: Recent Animation Exclusion**
    - **Validates: Requirements 15.3, 15.4**

  - [~] 13.4 Write property test for animation distribution fairness
    - **Property 40: Animation Distribution Fairness**
    - **Validates: Requirements 15.5**


- [~] 14. Implement adaptive timing and skip functionality
  - [~] 14.1 Add skip functionality
    - Implement skip trigger detection (tap/click during cutscene)
    - Add immediate cutscene termination on skip
    - Ensure completion signal emits on skip
    - _Requirements: 14.4_

  - [~] 14.2 Add adaptive duration reduction
    - Track cutscene play count per minigame
    - Implement 30% duration reduction after 3 plays
    - Maintain timing accuracy with reduced duration
    - _Requirements: 14.5_

  - [~] 14.3 Write property test for skip functionality
    - **Property 36: Skip Functionality**
    - **Validates: Requirements 14.4**

  - [~] 14.4 Write property test for adaptive duration reduction
    - **Property 37: Adaptive Duration Reduction**
    - **Validates: Requirements 14.5**

- [~] 15. Checkpoint - Advanced features complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 16. Integrate with MiniGameBase
  - [x] 16.1 Modify MiniGameBase cutscene methods
    - Update _show_success_micro_cutscene to use AnimatedCutscenePlayer
    - Update _show_failure_micro_cutscene to use AnimatedCutscenePlayer
    - Add fallback to legacy emoji system if animated system unavailable
    - Ensure backward compatibility with existing minigames
    - _Requirements: 6.1, 6.2, 6.3, 12.2_

  - [~] 16.2 Write integration tests for MiniGameBase
    - Test _show_success_micro_cutscene integration
    - Test _show_failure_micro_cutscene integration
    - Test game flow pause and resume
    - Test fallback to legacy emoji system

- [~] 17. Create minigame-specific cutscene configurations
  - [~] 17.1 Create CatchTheRain cutscenes
    - Create win_variant_1.json, win_variant_2.json, win_variant_3.json
    - Create fail_variant_1.json, fail_variant_2.json
    - Create intro.json
    - Include water-related particle effects and animations
    - _Requirements: 3.1, 3.3, 15.1, 15.2_

  - [~] 17.2 Create FixLeak cutscenes
    - Create win and fail variants with leak-themed animations
    - Include water drop particles and pipe-related visual elements
    - _Requirements: 3.1, 3.3_

  - [~] 17.3 Create WaterPlant cutscenes
    - Create win and fail variants with plant-themed animations
    - Include plant growth visual elements
    - _Requirements: 3.1, 3.4_

  - [~] 17.4 Create ThirstyPlant cutscenes
    - Create win and fail variants with plant watering animations
    - Include water and plant visual elements
    - _Requirements: 3.1, 3.4_

  - [~] 17.5 Create FilterBuilder cutscenes
    - Create win and fail variants with filter construction animations
    - Include water filtration visual effects
    - _Requirements: 3.1, 3.3_


- [~] 18. Create character and particle assets
  - [~] 18.1 Create water droplet character sprites
    - Create base droplet body sprite (512x512)
    - Create expression overlays (happy, sad, surprised, determined, worried, excited)
    - Create texture atlas combining all expressions (2048x2048)
    - Ensure kid-friendly, approachable design with bright colors
    - _Requirements: 4.1, 4.2, 4.4, 9.4, 13.1, 13.4_

  - [~] 18.2 Create particle effect textures
    - Create sparkles particle texture
    - Create water drops particle texture
    - Create stars particle texture
    - Create smoke particle texture
    - Create splash particle texture
    - _Requirements: 7.1_

  - [~] 18.3 Create particle effect scenes
    - Create GPUParticles2D scenes for each particle type
    - Configure particle properties (lifetime, velocity, color)
    - Optimize particle count for performance
    - _Requirements: 7.1, 7.7, 9.5_

- [~] 19. Implement preloading during game initialization
  - [~] 19.1 Add cutscene preloading to GameManager
    - Call AnimatedCutscenePlayer.preload_cutscene for all minigames during _ready
    - Preload character assets and particle textures
    - Cache default animation configurations
    - _Requirements: 9.1, 9.2_

- [~] 20. Final integration and testing
  - [~] 20.1 Test all minigames with animated cutscenes
    - Verify cutscenes play correctly for all minigames
    - Test intro, win, and fail cutscenes for each minigame
    - Verify audio synchronization
    - Test skip functionality
    - Test adaptive duration reduction
    - _Requirements: All_

  - [~] 20.2 Performance testing
    - Measure frame rate during cutscene playback
    - Verify memory cleanup after cutscenes
    - Test on low-end devices
    - Optimize as needed
    - _Requirements: 7.7, 9.3, 9.6_

  - [~] 20.3 Write edge case tests
    - Test missing configuration files
    - Test corrupted JSON data
    - Test missing character assets
    - Test concurrent cutscene attempts
    - Test zero/single keyframe configurations

- [~] 21. Final checkpoint - Complete system verification
  - Ensure all tests pass, ask the user if questions arise.


## Notes

- Tasks marked with `*` are optional property-based tests and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation and provide opportunities for user feedback
- Property tests validate universal correctness properties across all inputs
- Unit tests (in integration and edge case tasks) validate specific examples and scenarios
- The implementation follows a bottom-up approach: core components → orchestration → integration → content
- Default animations ensure the system works immediately, with minigame-specific animations added incrementally
- Error handling and fallback systems ensure game progression is never blocked
- Performance optimizations are integrated throughout rather than added as an afterthought

## Implementation Strategy

The task list is organized to enable incremental progress with early validation:

1. **Phase 1 (Tasks 1-5)**: Build core components in isolation - character, animation engine, parser
2. **Phase 2 (Tasks 6-10)**: Integrate components into the cutscene player orchestrator
3. **Phase 3 (Tasks 11-15)**: Add robustness features - error handling, defaults, variants, adaptive timing
4. **Phase 4 (Tasks 16-19)**: Wire into existing game systems and create content
5. **Phase 5 (Tasks 20-21)**: Final testing and verification

Each phase ends with a checkpoint to ensure quality and gather feedback before proceeding.
