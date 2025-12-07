# 💧 WaterWise - Comprehensive Technical Documentation

## Table of Contents
1. [System Overview](#1-system-overview)
2. [System Architecture](#2-system-architecture)
3. [IPO (Input-Process-Output) Model](#3-ipo-input-process-output-model)
4. [Use Case Diagrams](#4-use-case-diagrams)
5. [Algorithm Formulas](#5-algorithm-formulas)
6. [Pseudocode](#6-pseudocode)
7. [Scope and Limitations](#7-scope-and-limitations)
8. [Methodology](#8-methodology)
9. [Data Dictionary](#9-data-dictionary)
10. [Complete Feature List](#10-complete-feature-list)

---

## 1. System Overview

### 1.1 Project Description
**WaterWise** is an educational mobile/desktop game designed to teach children (ages 6-12) about water conservation through interactive mini-games. The game employs adaptive difficulty algorithms to personalize the learning experience and supports 2-player cooperative multiplayer.

### 1.2 Technology Stack
| Component | Technology |
|-----------|------------|
| Game Engine | Godot 4.5 |
| Programming Language | GDScript |
| Rendering | Forward+ / GL Compatibility |
| Networking | UDP (ENet-based) |
| Data Storage | ConfigFile (.cfg) |
| Audio | Procedural Generation |

### 1.3 Target Platform
- Desktop (Windows, macOS, Linux)
- Mobile-ready (Android, iOS)
- Resolution: 1920x1080 (responsive scaling)

---

## 2. System Architecture

### 2.1 Layered Architecture Overview

WaterWise follows a **4-tier layered architecture** with clear separation of concerns:

```
┌═══════════════════════════════════════════════════════════════════════════┐
│                    WATERWISE - LAYERED ARCHITECTURE                        │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │  LAYER 1: PRESENTATION LAYER (UI/UX)                               │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │   │
│  │  │ MainMenu │  │ Settings │  │ GameSel. │  │ Results  │          │   │
│  │  │  .tscn   │  │  .tscn   │  │  .tscn   │  │  .tscn   │          │   │
│  │  └─────┬────┘  └─────┬────┘  └─────┬────┘  └─────┬────┘          │   │
│  │        └──────────────┴──────────────┴─────────────┘               │   │
│  │                           │                                         │   │
│  │                  [Input Events: Touch/Click/Keyboard]              │   │
│  │                           ▼                                         │   │
│  │                  ┌──────────────────┐                              │   │
│  │                  │  UI Controller   │                              │   │
│  │                  │  - Event Router  │                              │   │
│  │                  │  - View Manager  │                              │   │
│  │                  └────────┬─────────┘                              │   │
│  └─────────────────────────┬┬┴───────────────────────────────────────┘   │
│                             ││                                            │
│  ═══════════════════════════╪╪════════════════════════════════════════   │
│                             ││                                            │
│  ┌─────────────────────────┴┴┬───────────────────────────────────────┐   │
│  │  LAYER 2: BUSINESS LOGIC LAYER (Game Engine Core)                 │   │
│  │                            │                                        │   │
│  │  ┌─────────────────────────▼──────────────────────────┐            │   │
│  │  │         MiniGameBase (Abstract Base Class)         │            │   │
│  │  │  ┌─────────────────────────────────────────────┐   │            │   │
│  │  │  │ Core Game Loop:                             │   │            │   │
│  │  │  │  • _ready() → Initialize                    │   │            │   │
│  │  │  │  • _process(Δt) → Update State              │   │            │   │
│  │  │  │  • record_action(success) → Track           │   │            │   │
│  │  │  │  • end_game(victory) → Finalize             │   │            │   │
│  │  │  └─────────────────────────────────────────────┘   │            │   │
│  │  └─────────────────────┬───────────────────────────────┘            │   │
│  │                        │                                             │   │
│  │  ┌─────────────┬───────┴──────┬─────────────┬───────────┐          │   │
│  │  │             │              │             │           │          │   │
│  │  ▼             ▼              ▼             ▼           ▼          │   │
│  │ ┌───────┐  ┌────────┐  ┌─────────┐  ┌──────────┐  ┌──────────┐   │   │
│  │ │Catch  │  │Bucket  │  │FixLeak  │  │Greywater │  │ MudPie   │   │   │
│  │ │ Rain  │  │Brigade │  │         │  │ Sorter   │  │  Maker   │   │   │
│  │ └───┬───┘  └───┬────┘  └────┬────┘  └────┬─────┘  └────┬─────┘   │   │
│  │     │          │            │            │             │          │   │
│  │     └──────────┴────────────┴────────────┴─────────────┘          │   │
│  │                            │                                        │   │
│  │  [Game State: active, paused, ended]                               │   │
│  │  [Score Calculation: points + time_bonus + accuracy_bonus]         │   │
│  └────────────────────────────┬───────────────────────────────────────┘   │
│                                │                                           │
│  ══════════════════════════════╪═══════════════════════════════════════   │
│                                │                                           │
│  ┌────────────────────────────┴──────────────────────────────────────┐   │
│  │  LAYER 3: SERVICE LAYER (Autoload Managers)                       │   │
│  │                                                                     │   │
│  │  ┌──────────────────────────────────────────────────────────────┐ │   │
│  │  │  ADAPTIVE DIFFICULTY ENGINE                                  │ │   │
│  │  │  ┌────────────────────┐    ┌────────────────────────┐        │ │   │
│  │  │  │  G-Counter CRDT    │    │  Rolling Window Queue  │        │ │   │
│  │  │  │ ┌────────────────┐ │    │ ┌────────────────────┐ │        │ │   │
│  │  │  │ │success_count++│ │    │ │actions[0..9]       │ │        │ │   │
│  │  │  │ │failure_count++│ │    │ │enqueue(success)    │ │        │ │   │
│  │  │  │ │lifetime_ratio │ │    │ │ratio = Σ/10        │ │        │ │   │
│  │  │  │ └────────────────┘ │    │ └────────────────────┘ │        │ │   │
│  │  │  │        │           │    │         │              │        │ │   │
│  │  │  │        ▼           │    │         ▼              │        │ │   │
│  │  │  │  Easy/Med/Hard     │    │  multiplier: 0.7-1.3   │        │ │   │
│  │  │  └────────┬───────────┘    └─────────┬──────────────┘        │ │   │
│  │  │           └──────────────┬────────────┘                       │ │   │
│  │  │                          ▼                                    │ │   │
│  │  │           ┌──────────────────────────────┐                   │ │   │
│  │  │           │  Difficulty Parameters       │                   │ │   │
│  │  │           │  • speed *= multiplier       │                   │ │   │
│  │  │           │  • spawn_rate /= multiplier  │                   │ │   │
│  │  │           │  • target *= multiplier      │                   │ │   │
│  │  │           └──────────────────────────────┘                   │ │   │
│  │  └──────────────────────────────────────────────────────────────┘ │   │
│  │                                                                     │   │
│  │  ┌──────────────────────────────────────────────────────────────┐ │   │
│  │  │  COOPERATIVE ADAPTATION (Multiplayer Load Balancing)         │ │   │
│  │  │  ┌────────────────┐           ┌────────────────┐             │ │   │
│  │  │  │  Player 1      │           │  Player 2      │             │ │   │
│  │  │  │  accuracy: 0.9 │           │  accuracy: 0.6 │             │ │   │
│  │  │  └────────┬───────┘           └────────┬───────┘             │ │   │
│  │  │           └────────────┬────────────────┘                     │ │   │
│  │  │                        ▼                                      │ │   │
│  │  │           ┌──────────────────────────┐                       │ │   │
│  │  │           │  diff = |P1 - P2| = 0.3  │                       │ │   │
│  │  │           └────────────┬─────────────┘                       │ │   │
│  │  │                        ▼                                      │ │   │
│  │  │           ┌──────────────────────────┐                       │ │   │
│  │  │           │  Adjustment:             │                       │ │   │
│  │  │           │  P1: 1.1x (harder)       │                       │ │   │
│  │  │           │  P2: 0.8x (easier)       │                       │ │   │
│  │  │           └──────────────────────────┘                       │ │   │
│  │  └──────────────────────────────────────────────────────────────┘ │   │
│  │                                                                     │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐    │   │
│  │  │SaveManager   │  │Localization  │  │ AccessibilityManager │    │   │
│  │  │• save()      │  │• translate() │  │ • colorblind_mode    │    │   │
│  │  │• load()      │  │• EN/TL dict  │  │ • audio_cues         │    │   │
│  │  │• achievements│  └──────────────┘  │ • large_targets      │    │   │
│  │  └──────────────┘                    └──────────────────────┘    │   │
│  │                                                                     │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │   │
│  │  │NetworkManager│  │AudioManager  │  │TutorialMgr   │            │   │
│  │  │• UDP/ENet    │  │• Procedural  │  │• First-time  │            │   │
│  │  │• Discovery   │  │• SFX Gen     │  │• Per-game    │            │   │
│  │  │• Sync        │  │• Tones       │  │• Popups      │            │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘            │   │
│  └─────────────────────────────┬───────────────────────────────────┘   │
│                                 │                                        │
│  ═══════════════════════════════╪════════════════════════════════════   │
│                                 │                                        │
│  ┌─────────────────────────────┴──────────────────────────────────────┐ │
│  │  LAYER 4: DATA PERSISTENCE LAYER                                   │ │
│  │                                                                      │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  waterwise.cfg (ConfigFile - INI-like format)              │   │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────────────┐    │   │ │
│  │  │  │[game]      │  │[settings]  │  │[achievements]      │    │   │ │
│  │  │  │high_score  │  │language=en │  │first_game=true     │    │   │ │
│  │  │  │droplets=50 │  │volume=0.8  │  │water_saver=false   │    │   │ │
│  │  │  └────────────┘  └────────────┘  └────────────────────┘    │   │ │
│  │  │                                                               │   │ │
│  │  │  File Path: user://waterwise_save.cfg                        │   │ │
│  │  │  Format: Key=Value pairs in sections                         │   │ │
│  │  │  Operations: load() on startup, save() after each game       │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └──────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└══════════════════════════════════════════════════════════════════════════┘
```

### 2.2 Algorithm Integration Architecture

This diagram shows how algorithms flow through the system:

```
┌═══════════════════════════════════════════════════════════════════════════┐
│              ALGORITHM FLOW IN WATERWISE ARCHITECTURE                      │
├═══════════════════════════════════════════════════════════════════════════┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  PLAYER ACTION (Input Event)                                        │  │
│  │  Examples: Tap bucket, Swipe left, Drag plug                        │  │
│  └────────────────────────────┬────────────────────────────────────────┘  │
│                                │                                           │
│                                ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  GAME LOGIC PROCESSING                                              │  │
│  │  ┌─────────────────────────────────────────────────────────────┐    │  │
│  │  │  MiniGameBase::record_action(success: bool)                 │    │  │
│  │  │                                                               │    │  │
│  │  │  IF success:                                                 │    │  │
│  │  │    score += calculate_points()  ◄─── SCORING ALGORITHM       │    │  │
│  │  │    show_success_feedback()                                   │    │  │
│  │  │  ELSE:                                                        │    │  │
│  │  │    lives -= 1                                                │    │  │
│  │  │    show_failure_feedback()                                   │    │  │
│  │  │                                                               │    │  │
│  │  │  // Update Adaptive Difficulty                               │    │  │
│  │  │  AdaptiveDifficulty.record_action(success) ──┐               │    │  │
│  │  └───────────────────────────────────────────────┼───────────────┘    │  │
│  └────────────────────────────────────────────────┬─┘                     │  │
│                                                    │                       │  │
│                   ┌────────────────────────────────┼─────────┐             │  │
│                   │                                │         │             │  │
│                   ▼                                ▼         ▼             │  │
│  ┌───────────────────────────┐    ┌──────────────────────────────────┐    │  │
│  │  ROLLING WINDOW ALGORITHM │    │  G-COUNTER ALGORITHM             │    │  │
│  │  (Real-time Adjustment)   │    │  (Long-term Tracking)            │    │  │
│  │                           │    │                                  │    │  │
│  │  Queue<bool> window       │    │  success_counter: int           │    │  │
│  │  window.size() = 10       │    │  failure_counter: int           │    │  │
│  │                           │    │                                  │    │  │
│  │  ENQUEUE(success):        │    │  INCREMENT:                      │    │  │
│  │    IF size >= 10:         │    │    IF success:                   │    │  │
│  │      dequeue()            │    │      success_counter += 1        │    │  │
│  │    enqueue(success)       │    │    ELSE:                         │    │  │
│  │                           │    │      failure_counter += 1        │    │  │
│  │  CALCULATE RATIO:         │    │                                  │    │  │
│  │    count_success = 0      │    │  LIFETIME RATIO:                 │    │  │
│  │    FOR each in window:    │    │    total = success + failure     │    │  │
│  │      IF value == true:    │    │    ratio = success / total       │    │  │
│  │        count_success++    │    │                                  │    │  │
│  │    ratio = count / 10     │    │  RECOMMENDATION:                 │    │  │
│  │                           │    │    IF ratio > 0.8: "Hard"        │    │  │
│  │  DIFFICULTY MULTIPLIER:   │    │    ELIF ratio > 0.5: "Medium"    │    │  │
│  │    multiplier =           │    │    ELSE: "Easy"                  │    │  │
│  │      lerp(0.7, 1.3, ratio)│    │                                  │    │  │
│  │                           │    │  PERSIST TO DISK:                │    │  │
│  │    // 70% easier          │    │    SaveManager.save_counters()   │    │  │
│  │    // 130% harder         │    │                                  │    │  │
│  └──────────┬────────────────┘    └──────────────┬───────────────────┘    │  │
│             │                                    │                        │  │
│             └────────────────┬───────────────────┘                        │  │
│                              ▼                                            │  │
│  ┌──────────────────────────────────────────────────────────────────┐    │  │
│  │  APPLY DIFFICULTY ADJUSTMENTS                                    │    │  │
│  │                                                                   │    │  │
│  │  Game Parameters Modified:                                       │    │  │
│  │  ┌────────────────────────────────────────────────────────────┐  │    │  │
│  │  │  spawn_interval = base_interval / multiplier               │  │    │  │
│  │  │  object_speed = base_speed × multiplier                    │  │    │  │
│  │  │  target_count = base_target × multiplier                   │  │    │  │
│  │  │  bucket_width = base_width / multiplier                    │  │    │  │
│  │  │  time_limit = base_time / (multiplier × 0.5)               │  │    │  │
│  │  └────────────────────────────────────────────────────────────┘  │    │  │
│  │                                                                   │    │  │
│  │  Example (ratio = 0.8, multiplier = 1.24):                      │    │  │
│  │    spawn_interval: 2.0s → 1.61s (faster spawning)              │    │  │
│  │    object_speed: 200px/s → 248px/s (faster movement)           │    │  │
│  │    bucket_width: 100px → 81px (smaller bucket)                 │    │  │
│  └──────────────────────────────────────────────────────────────────┘    │  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────┐    │  │
│  │  MULTIPLAYER COOPERATIVE ADAPTATION (If 2 Players)              │    │  │
│  │                                                                   │    │  │
│  │  ┌─────────────┐                            ┌─────────────┐      │    │  │
│  │  │  Player 1   │                            │  Player 2   │      │    │  │
│  │  │  Local Game │◄────── UDP Packets ───────►│  Local Game │      │    │  │
│  │  └──────┬──────┘                            └──────┬──────┘      │    │  │
│  │         │                                          │             │    │  │
│  │         └──────────────┬───────────────────────────┘             │    │  │
│  │                        ▼                                         │    │  │
│  │         ┌─────────────────────────────────┐                      │    │  │
│  │         │  CoopAdaptation.update()        │                      │    │  │
│  │         │                                 │                      │    │  │
│  │         │  p1_accuracy = 0.85             │                      │    │  │
│  │         │  p2_accuracy = 0.60             │                      │    │  │
│  │         │  diff = |0.85 - 0.60| = 0.25    │                      │    │  │
│  │         │                                 │                      │    │  │
│  │         │  IF diff > 0.20:                │                      │    │  │
│  │         │    weaker_adjustment = 0.85     │                      │    │  │
│  │         │    stronger_adjustment = 1.08   │                      │    │  │
│  │         │                                 │                      │    │  │
│  │         │  Apply to each player's game    │                      │    │  │
│  │         └─────────────────────────────────┘                      │    │  │
│  └──────────────────────────────────────────────────────────────────┘    │  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────┐    │  │
│  │  SCORE CALCULATION ALGORITHM                                     │    │  │
│  │                                                                   │    │  │
│  │  calculate_final_score():                                        │    │  │
│  │    ┌─────────────────────────────────────────────────────────┐   │    │  │
│  │    │  base_points = correct_actions × action_value           │   │    │  │
│  │    │              = 15 × 10 = 150                            │   │    │  │
│  │    │                                                          │   │    │  │
│  │    │  time_bonus = max(0, (time_limit - time_used) × 5)     │   │    │  │
│  │    │              = max(0, (30 - 18) × 5) = 60              │   │    │  │
│  │    │                                                          │   │    │  │
│  │    │  accuracy = correct / total                             │   │    │  │
│  │    │           = 15 / 17 = 0.88                              │   │    │  │
│  │    │  accuracy_bonus = accuracy × 100                        │   │    │  │
│  │    │                 = 88                                    │   │    │  │
│  │    │                                                          │   │    │  │
│  │    │  combo_bonus = combo_count × 5                          │   │    │  │
│  │    │              = 3 × 5 = 15                               │   │    │  │
│  │    │                                                          │   │    │  │
│  │    │  final_score = 150 + 60 + 88 + 15 = 313                │   │    │  │
│  │    │                                                          │   │    │  │
│  │    │  stars_earned:                                          │   │    │  │
│  │    │    IF accuracy >= 0.9: 3 stars                          │   │    │  │
│  │    │    ELIF accuracy >= 0.7: 2 stars  ◄── Result: 2 stars  │   │    │  │
│  │    │    ELIF accuracy >= 0.5: 1 star                         │   │    │  │
│  │    └─────────────────────────────────────────────────────────┘   │    │  │
│  └──────────────────────────────────────────────────────────────────┘    │  │
│                                                                             │
└═════════════════════════════════════════════════════════════════════════════┘
```

### 2.3 Data Flow Architecture

```
┌═══════════════════════════════════════════════════════════════════════════┐
│                    DATA FLOW THROUGH SYSTEM                                │
├═══════════════════════════════════════════════════════════════════════════┤
│                                                                             │
│  APP LAUNCH:                                                                │
│  ───────────                                                                │
│  [1] GameManager._ready()                                                   │
│       │                                                                      │
│       ├─► Load ConfigFile from disk                                         │
│       │   └─► Parse [game], [settings], [achievements] sections            │
│       │                                                                      │
│       ├─► Initialize AdaptiveDifficulty                                     │
│       │   ├─► Load G-Counter values (success/failure)                       │
│       │   └─► Initialize empty Rolling Window                               │
│       │                                                                      │
│       ├─► Initialize SaveManager                                            │
│       │   └─► Sync with ConfigFile data                                     │
│       │                                                                      │
│       └─► Load main menu scene                                              │
│           └─► InitialScreen.tscn displayed                                  │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────     │
│                                                                             │
│  GAME SESSION:                                                              │
│  ─────────────                                                              │
│  [2] Player selects mini-game                                               │
│       │                                                                      │
│       ├─► GameManager.start_next_minigame()                                 │
│       │   ├─► Get recommended difficulty from G-Counter                     │
│       │   └─► Load game scene (e.g., CatchTheRain.tscn)                     │
│       │                                                                      │
│       ▼                                                                      │
│  [3] MiniGame._ready()                                                      │
│       │                                                                      │
│       ├─► apply_difficulty_settings()                                       │
│       │   ├─► Set base parameters (easy/medium/hard)                        │
│       │   └─► Get multiplier from Rolling Window                            │
│       │       └─► Adjust speed, spawn_rate, target                          │
│       │                                                                      │
│       ├─► TutorialManager.should_show_tutorial()?                           │
│       │   ├─► IF first_time: Show tutorial popup                            │
│       │   └─► ELSE: Skip directly to game                                   │
│       │                                                                      │
│       └─► Start countdown (3, 2, 1, GO!)                                    │
│           └─► game_active = true                                            │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────     │
│                                                                             │
│  GAME LOOP (60 FPS):                                                        │
│  ───────────────────                                                        │
│  [4] MiniGame._process(delta)                                               │
│       │                                                                      │
│       ├─► Update timer: time_remaining -= delta                             │
│       ├─► Update game objects: objects[i].position += velocity * delta      │
│       ├─► Check collisions: bucket.overlaps_area(drop)                      │
│       │   └─► IF collision: record_action(true/false)                       │
│       │                                                                      │
│       └─► Check win/lose conditions                                         │
│           ├─► IF score >= target: end_game(true)                            │
│           ├─► IF lives <= 0: end_game(false)                                │
│           └─► IF time <= 0: end_game(false)                                 │
│                                                                             │
│  [5] record_action(success: bool)                                           │
│       │                                                                      │
│       ├─► Update local game state                                           │
│       │   ├─► IF success: score += points                                   │
│       │   └─► ELSE: lives -= 1                                              │
│       │                                                                      │
│       ├─► Send to AdaptiveDifficulty                                        │
│       │   ├─► Rolling Window: enqueue(success)                              │
│       │   │   └─► Recalculate multiplier (0.7 - 1.3)                        │
│       │   │                                                                  │
│       │   └─► G-Counter: increment success/failure                          │
│       │       └─► Update lifetime ratio                                     │
│       │                                                                      │
│       └─► IF multiplayer: NetworkManager.sync_performance()                 │
│           └─► Send UDP packet to partner                                    │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────     │
│                                                                             │
│  GAME END:                                                                  │
│  ─────────                                                                  │
│  [6] end_game(victory: bool)                                                │
│       │                                                                      │
│       ├─► calculate_final_score()                                           │
│       │   └─► base + time_bonus + accuracy_bonus + combo_bonus              │
│       │                                                                      │
│       ├─► SaveManager.update_progress()                                     │
│       │   ├─► Check if new high score                                       │
│       │   ├─► Update games_played counter                                   │
│       │   └─► Check achievement unlock conditions                           │
│       │                                                                      │
│       ├─► SaveManager.save_to_disk()                                        │
│       │   └─► Write ConfigFile to user://waterwise_save.cfg                 │
│       │                                                                      │
│       └─► Show results screen                                               │
│           ├─► Display score, stars, achievements                            │
│           └─► Show "Continue" button → Return to game selection             │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────     │
│                                                                             │
│  MULTIPLAYER DATA FLOW:                                                     │
│  ──────────────────────                                                     │
│  [7] NetworkManager (UDP/ENet)                                              │
│       │                                                                      │
│       ├─► HOST MODE:                                                        │
│       │   ├─► Create UDP server on port 7777                                │
│       │   ├─► Broadcast discovery packets                                   │
│       │   └─► Wait for client connection                                    │
│       │                                                                      │
│       └─► CLIENT MODE:                                                      │
│           ├─► Listen for discovery broadcasts                               │
│           ├─► Display available games                                       │
│           └─► Connect to selected host                                      │
│                                                                             │
│  [8] During Multiplayer Game:                                               │
│       │                                                                      │
│       ├─► Every action: sync_performance()                                  │
│       │   └─► Send packet: {score, accuracy, time, player_id}               │
│       │                                                                      │
│       ├─► On receive: partner_data_received signal                          │
│       │   └─► CoopAdaptation.update_metrics(partner_data)                   │
│       │       └─► Adjust difficulty for load balancing                      │
│       │                                                                      │
│       └─► Game end: both players finish                                     │
│           ├─► Exchange final scores                                         │
│           ├─► Calculate team_score = (P1 + P2) / 2                          │
│           └─► Show team results screen                                      │
│                                                                             │
└═════════════════════════════════════════════════════════════════════════════┘
```

### 2.3 Class Hierarchy

```
Node
├── Control (UI Screens)
│   ├── MainMenu
│   ├── InitialScreen
│   ├── Settings
│   ├── GameSelection
│   ├── MultiplayerLobby
│   ├── UnlockablesScreen
│   └── Instructions
│
├── Node2D (Game Scenes)
│   └── MiniGameBase (Abstract)
│       ├── CatchTheRain
│       ├── BucketBrigade
│       ├── FixTheLeak
│       ├── GreywaterSorter
│       ├── MudPieMaker
│       ├── QuickShower
│       ├── SpotTheSpeck
│       ├── TimingTap
│       ├── TurnOffTap
│       └── SwipeTheSoap
│
└── Node (Autoloads/Singletons)
    ├── GameManager
    ├── AdaptiveDifficulty
    ├── Localization
    ├── NetworkManager
    ├── CoopAdaptation
    ├── ThemeManager
    ├── SaveManager
    ├── TutorialManager
    ├── AccessibilityManager
    └── AudioManager
```

---

## 3. IPO (Input-Process-Output) Model

### 3.1 System-Level IPO

```
┌─────────────────────────────────────────────────────────────────┐
│                      WATERWISE IPO MODEL                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐      │
│  │   INPUTS    │ ───► │  PROCESSES  │ ───► │   OUTPUTS   │      │
│  └─────────────┘      └─────────────┘      └─────────────┘      │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

#### INPUTS
| Category | Input Type | Description |
|----------|------------|-------------|
| **User Interaction** | Touch/Click | Tap, swipe, drag gestures |
| | Keyboard | Menu navigation, shortcuts |
| | Mouse | Desktop pointer control |
| **System Data** | Saved Progress | Previous scores, achievements |
| | Settings | Language, volume, accessibility |
| **Network** | Multiplayer Data | Partner performance, sync signals |
| **Time** | System Clock | Session duration, timestamps |

#### PROCESSES
| Process | Description | Algorithm Used |
|---------|-------------|----------------|
| **Difficulty Adjustment** | Adapt game parameters | G-Counter + Rolling Window |
| **Score Calculation** | Compute points earned | Weighted scoring formula |
| **Progress Tracking** | Update player stats | Increment counters |
| **Achievement Check** | Unlock achievements | Condition matching |
| **Localization** | Translate text | Dictionary lookup |
| **Accessibility** | Apply A11y features | Color transformation |
| **Network Sync** | Exchange multiplayer data | UDP packet handling |

#### OUTPUTS
| Category | Output Type | Description |
|----------|-------------|-------------|
| **Visual** | Game Graphics | Sprites, animations, effects |
| | UI Elements | Buttons, labels, progress bars |
| | Feedback | Score popups, celebrations |
| **Audio** | Sound Effects | Success, failure, click sounds |
| | Background Music | Ambient procedural audio |
| **Data** | Save File | Persistent player data |
| | Network Packets | Multiplayer sync data |
| **Educational** | Water Facts | Conservation tips displayed |

### 3.2 Mini-Game IPO (Example: Catch The Rain)

```
┌─────────────────────────────────────────────────────────────────┐
│               CATCH THE RAIN - IPO MODEL                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  INPUTS:                     PROCESSES:                          │
│  ┌────────────────┐         ┌────────────────────────────┐      │
│  │ • Touch/Mouse  │         │ 1. Spawn raindrops         │      │
│  │   position     │────────►│ 2. Move bucket to position │      │
│  │ • Time delta   │         │ 3. Detect collision        │      │
│  │ • Difficulty   │         │ 4. Update score            │      │
│  │   parameters   │         │ 5. Adjust difficulty       │      │
│  └────────────────┘         └────────────┬───────────────┘      │
│                                          │                       │
│                                          ▼                       │
│                              ┌────────────────────────────┐      │
│                              │ OUTPUTS:                   │      │
│                              │ • Bucket movement          │      │
│                              │ • Catch/miss animation     │      │
│                              │ • Score display            │      │
│                              │ • Sound effects            │      │
│                              │ • Progress update          │      │
│                              └────────────────────────────┘      │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Detailed IPO Tables

#### Main Menu IPO
| Input | Process | Output |
|-------|---------|--------|
| Play button tap | Load game session | Navigate to InitialScreen |
| Settings button tap | Load settings screen | Navigate to Settings |
| Multiplayer button tap | Initialize network | Navigate to MultiplayerLobby |

#### Adaptive Difficulty IPO
| Input | Process | Output |
|-------|---------|--------|
| Player action (success/fail) | Update rolling window | New difficulty multiplier |
| Session completion | Update G-Counter | Adjusted base difficulty |
| Performance history | Calculate recommendation | Easy/Medium/Hard setting |

#### Save System IPO
| Input | Process | Output |
|-------|---------|--------|
| Game completion | Serialize game state | Updated .cfg file |
| App launch | Deserialize saved data | Restored player progress |
| Achievement trigger | Check unlock conditions | Achievement notification |

---

## 4. Use Case Diagrams

### 4.1 Main Use Case Diagram

```
                         ┌─────────────────────────────────────────┐
                         │           WATERWISE SYSTEM              │
                         │                                         │
    ┌──────┐            │   ┌─────────────────────────────┐      │
    │Player│────────────┼──►│     Play Mini-Games         │      │
    └──┬───┘            │   └─────────────────────────────┘      │
       │                │                 │                       │
       │                │   ┌─────────────┴─────────────┐        │
       │                │   │                           │        │
       │                │   ▼                           ▼        │
       │                │ ┌───────────┐           ┌───────────┐  │
       │                │ │Catch Rain │           │Bucket Brig│  │
       │                │ └───────────┘           └───────────┘  │
       │                │                                         │
       │                │   ┌─────────────────────────────┐      │
       ├────────────────┼──►│     Adjust Settings         │      │
       │                │   └─────────────────────────────┘      │
       │                │                 │                       │
       │                │   ┌─────────────┼─────────────┐        │
       │                │   ▼             ▼             ▼        │
       │                │ ┌─────┐    ┌────────┐   ┌──────────┐  │
       │                │ │Lang.│    │Volume  │   │Accessib. │  │
       │                │ └─────┘    └────────┘   └──────────┘  │
       │                │                                         │
       │                │   ┌─────────────────────────────┐      │
       ├────────────────┼──►│     View Progress           │      │
       │                │   └─────────────────────────────┘      │
       │                │                 │                       │
       │                │   ┌─────────────┼─────────────┐        │
       │                │   ▼             ▼             ▼        │
       │                │ ┌─────┐    ┌────────┐   ┌──────────┐  │
       │                │ │Score│    │Achieve.│   │Unlocks   │  │
       │                │ └─────┘    └────────┘   └──────────┘  │
       │                │                                         │
       │                │   ┌─────────────────────────────┐      │
       └────────────────┼──►│     Play Multiplayer        │      │
                        │   └─────────────────────────────┘      │
                        │                 │                       │
    ┌──────┐            │   ┌─────────────┼─────────────┐        │
    │Player│────────────┼──►│             │             │        │
    │  2   │            │   ▼             ▼             ▼        │
    └──────┘            │ ┌─────┐    ┌────────┐   ┌──────────┐  │
                        │ │Host │    │Join    │   │Co-op Game│  │
                        │ └─────┘    └────────┘   └──────────┘  │
                        │                                         │
                        └─────────────────────────────────────────┘
```

### 4.2 Actor Descriptions

| Actor | Description | Primary Goals |
|-------|-------------|---------------|
| **Player (Primary)** | Child user (ages 6-12) | Learn about water conservation through gameplay |
| **Player 2 (Secondary)** | Second player in multiplayer | Cooperate with Player 1 |
| **System (Timer)** | Internal game clock | Trigger timed events |
| **Network** | LAN connection | Sync multiplayer data |

### 4.3 Use Case Specifications

#### UC-01: Play Mini-Game
| Field | Description |
|-------|-------------|
| **Use Case ID** | UC-01 |
| **Use Case Name** | Play Mini-Game |
| **Actor** | Player |
| **Precondition** | Player is on game selection screen |
| **Postcondition** | Game completed, score recorded |
| **Main Flow** | 1. Player selects mini-game<br>2. System shows tutorial (first time)<br>3. Countdown begins<br>4. Player performs game actions<br>5. System calculates score<br>6. Results displayed |
| **Alternate Flow** | 4a. Player runs out of lives → Game ends early |
| **Exception Flow** | System error → Return to main menu |

#### UC-02: Adjust Difficulty
| Field | Description |
|-------|-------------|
| **Use Case ID** | UC-02 |
| **Use Case Name** | Automatic Difficulty Adjustment |
| **Actor** | System |
| **Precondition** | Player action recorded |
| **Postcondition** | Difficulty parameters updated |
| **Main Flow** | 1. Player performs action<br>2. System records success/failure<br>3. Rolling Window updated<br>4. New difficulty calculated<br>5. Game parameters adjusted |

#### UC-03: Host Multiplayer Game
| Field | Description |
|-------|-------------|
| **Use Case ID** | UC-03 |
| **Use Case Name** | Host Multiplayer Game |
| **Actor** | Player (Host) |
| **Precondition** | On multiplayer lobby screen |
| **Postcondition** | Game session created, waiting for Player 2 |
| **Main Flow** | 1. Player taps "Host Game"<br>2. System creates UDP server<br>3. System broadcasts availability<br>4. Waiting screen displayed<br>5. Player 2 connects<br>6. Game begins |

---

## 5. Algorithm Formulas

### 5.1 G-Counter Algorithm (Grow-Only Counter)

The G-Counter is a **CRDT (Conflict-free Replicated Data Type)** used for tracking cumulative performance across sessions.

#### Formula:
```
G-Counter State:
  counters = {node_id: count, ...}

Increment:
  counters[local_id] += 1

Value:
  value() = Σ counters[i] for all i

Merge:
  for each node_id in (local ∪ remote):
    counters[node_id] = max(local[node_id], remote[node_id])
```

#### Implementation Variables:
| Variable | Description | Formula |
|----------|-------------|---------|
| `success_counter` | Total successful actions | `+1` per success |
| `failure_counter` | Total failed actions | `+1` per failure |
| `total_actions` | Combined total | `success + failure` |
| `lifetime_ratio` | Overall success rate | `success / total_actions` |

#### Difficulty Calculation:
```
base_difficulty = lifetime_ratio × difficulty_weight

if lifetime_ratio > 0.8:
    recommendation = "Hard"
elif lifetime_ratio > 0.5:
    recommendation = "Medium"
else:
    recommendation = "Easy"
```

### 5.2 Rolling Window Algorithm

The Rolling Window tracks the **last N actions** for real-time difficulty adjustment.

#### Formula:
```
Window State:
  window = Queue(max_size=10)  # Last 10 actions

Record Action:
  if window.size() >= max_size:
    window.dequeue()
  window.enqueue(success: bool)

Calculate Ratio:
  success_count = count(window where success=true)
  ratio = success_count / window.size()

Difficulty Multiplier:
  multiplier = lerp(0.7, 1.3, ratio)
  # 0.7 = easier (70% of normal)
  # 1.3 = harder (130% of normal)
```

#### Applied Parameters:
```
speed_multiplier = base_speed × difficulty_multiplier
spawn_interval = base_interval / difficulty_multiplier
target_count = base_target × difficulty_multiplier
```

### 5.3 Score Calculation Formula

```
Base Score:
  base_points = action_value × multiplier

Time Bonus:
  time_bonus = max(0, (time_limit - time_taken) × time_factor)

Accuracy Bonus:
  accuracy = correct_actions / total_actions
  accuracy_bonus = accuracy × accuracy_weight

Combo Bonus:
  combo_bonus = combo_count × combo_multiplier

Final Score:
  final_score = base_points + time_bonus + accuracy_bonus + combo_bonus

Stars Earned:
  if accuracy >= 0.9: stars = 3
  elif accuracy >= 0.7: stars = 2
  elif accuracy >= 0.5: stars = 1
  else: stars = 0
```

### 5.4 Cooperative Load Balancing Formula

```
Performance Difference:
  diff = |P1_accuracy - P2_accuracy|

Adjustment Factor:
  if diff > 0.3:
    weaker_player_adjustment = 0.8  # Easier
    stronger_player_adjustment = 1.1  # Slightly harder
  elif diff > 0.15:
    weaker_player_adjustment = 0.9
    stronger_player_adjustment = 1.05
  else:
    both_adjustments = 1.0  # Balanced

Team Score:
  team_score = (P1_score + P2_score) / 2 × cooperation_bonus
  cooperation_bonus = 1.0 + (0.1 × sync_actions)
```

### 5.5 Colorblind Color Transformation

```
Standard Colors:
  good = RGB(51, 204, 77)    # Green
  bad = RGB(230, 51, 51)     # Red

Deuteranopia-Safe Transform:
  good → RGB(0, 115, 178)    # Blue
  bad → RGB(230, 153, 0)     # Orange

Formula (Simplified):
  if colorblind_mode:
    color = colorblind_palette[color_key]
  else:
    color = standard_palette[color_key]
```

---

## 6. Pseudocode

### 6.1 Main Game Loop

```pseudocode
PROGRAM WaterWise

FUNCTION main():
    initialize_autoloads()
    load_saved_data()
    show_main_menu()
    
    WHILE game_running:
        process_input()
        update_game_state()
        render_frame()
        
    save_game_data()
    cleanup()
END FUNCTION
```

### 6.2 Mini-Game Base Flow

```pseudocode
CLASS MiniGameBase:
    
    VARIABLES:
        game_active: boolean = false
        score: integer = 0
        lives: integer = 3
        time_remaining: float
        difficulty_multiplier: float
    
    FUNCTION _ready():
        apply_difficulty_settings()
        setup_ui()
        show_tutorial_if_first_time()
        start_countdown()
    END FUNCTION
    
    FUNCTION start_countdown():
        FOR i FROM 3 TO 1:
            show_number(i)
            wait(1 second)
        END FOR
        game_active = true
        start_timer()
    END FUNCTION
    
    FUNCTION _process(delta):
        IF NOT game_active:
            RETURN
        END IF
        
        update_timer(delta)
        update_game_logic(delta)
        check_win_conditions()
        check_lose_conditions()
    END FUNCTION
    
    FUNCTION record_action(success: boolean):
        IF success:
            score += calculate_points()
            show_success_feedback()
        ELSE:
            lives -= 1
            show_failure_feedback()
            IF lives <= 0:
                end_game(false)
            END IF
        END IF
        
        // Update adaptive difficulty
        AdaptiveDifficulty.record_action(success)
    END FUNCTION
    
    FUNCTION end_game(victory: boolean):
        game_active = false
        calculate_final_score()
        save_progress()
        show_results_screen()
    END FUNCTION
END CLASS
```

### 6.3 Adaptive Difficulty Algorithm

```pseudocode
CLASS AdaptiveDifficulty:
    
    CONSTANTS:
        WINDOW_SIZE = 10
        DIFFICULTY_WEIGHT = 0.3
    
    VARIABLES:
        rolling_window: Queue[boolean]
        g_counter_success: integer = 0
        g_counter_failure: integer = 0
    
    FUNCTION record_action(success: boolean):
        // Update Rolling Window
        IF rolling_window.size() >= WINDOW_SIZE:
            rolling_window.dequeue()
        END IF
        rolling_window.enqueue(success)
        
        // Update G-Counter
        IF success:
            g_counter_success += 1
        ELSE:
            g_counter_failure += 1
        END IF
    END FUNCTION
    
    FUNCTION get_difficulty_multiplier() -> float:
        IF rolling_window.is_empty():
            RETURN 1.0
        END IF
        
        success_count = count(rolling_window WHERE value = true)
        ratio = success_count / rolling_window.size()
        
        // Interpolate between 0.7 (easy) and 1.3 (hard)
        multiplier = lerp(0.7, 1.3, ratio)
        RETURN multiplier
    END FUNCTION
    
    FUNCTION get_recommended_difficulty() -> string:
        total = g_counter_success + g_counter_failure
        IF total = 0:
            RETURN "Medium"
        END IF
        
        lifetime_ratio = g_counter_success / total
        
        IF lifetime_ratio > 0.8:
            RETURN "Hard"
        ELSE IF lifetime_ratio > 0.5:
            RETURN "Medium"
        ELSE:
            RETURN "Easy"
        END IF
    END FUNCTION
END CLASS
```

### 6.4 Catch The Rain Game Logic

```pseudocode
CLASS CatchTheRain EXTENDS MiniGameBase:
    
    VARIABLES:
        bucket_position: Vector2
        raindrops: Array[Raindrop]
        spawn_timer: float
        drops_caught: integer = 0
        target_drops: integer = 15
    
    FUNCTION _ready():
        SUPER._ready()
        create_bucket()
        create_background()
    END FUNCTION
    
    FUNCTION _process(delta):
        SUPER._process(delta)
        IF NOT game_active:
            RETURN
        END IF
        
        // Move bucket to follow input
        target_x = get_input_position().x
        bucket_position.x = lerp(bucket_position.x, target_x, 10 * delta)
        
        // Spawn raindrops
        spawn_timer -= delta
        IF spawn_timer <= 0:
            spawn_raindrop()
            spawn_timer = spawn_interval / difficulty_multiplier
        END IF
        
        // Update raindrops
        FOR EACH drop IN raindrops:
            drop.position.y += drop_speed * difficulty_multiplier * delta
            
            // Check collision with bucket
            IF drop.overlaps(bucket):
                IF drop.is_good:
                    drops_caught += 1
                    record_action(true)
                    IF drops_caught >= target_drops:
                        end_game(true)
                    END IF
                ELSE:
                    record_action(false)
                END IF
                remove_drop(drop)
            
            // Check if fell off screen
            ELSE IF drop.position.y > screen_height:
                IF drop.is_good:
                    record_action(false)
                END IF
                remove_drop(drop)
            END IF
        END FOR
    END FUNCTION
    
    FUNCTION spawn_raindrop():
        drop = new Raindrop()
        drop.position.x = random(100, screen_width - 100)
        drop.position.y = -50
        drop.is_good = random() > 0.2  // 80% good drops
        raindrops.append(drop)
    END FUNCTION
END CLASS
```

### 6.5 Save System

```pseudocode
CLASS SaveManager:
    
    CONSTANTS:
        SAVE_PATH = "user://waterwise_save.cfg"
    
    VARIABLES:
        progress: Dictionary
        achievements: Dictionary
        settings: Dictionary
    
    FUNCTION save_progress():
        config = new ConfigFile()
        
        // Save progress data
        config.set_value("progress", "games_played", progress.games_played)
        config.set_value("progress", "total_score", progress.total_score)
        config.set_value("progress", "water_saved", progress.water_saved)
        
        // Save high scores per game
        FOR EACH game_id, high_score IN progress.high_scores:
            config.set_value("high_scores", game_id, high_score)
        END FOR
        
        // Save achievements
        FOR EACH achievement_id, unlocked IN achievements:
            config.set_value("achievements", achievement_id, unlocked)
        END FOR
        
        // Save settings
        FOR EACH key, value IN settings:
            config.set_value("settings", key, value)
        END FOR
        
        error = config.save(SAVE_PATH)
        IF error != OK:
            print_error("Failed to save: ", error)
        END IF
    END FUNCTION
    
    FUNCTION load_progress():
        config = new ConfigFile()
        error = config.load(SAVE_PATH)
        
        IF error != OK:
            // First launch - use defaults
            initialize_defaults()
            RETURN
        END IF
        
        // Load all sections
        progress.games_played = config.get_value("progress", "games_played", 0)
        progress.total_score = config.get_value("progress", "total_score", 0)
        // ... load other values
    END FUNCTION
    
    FUNCTION unlock_achievement(achievement_id: string):
        IF NOT achievements.has(achievement_id):
            RETURN
        END IF
        
        IF achievements[achievement_id] = false:
            achievements[achievement_id] = true
            save_progress()
            show_achievement_popup(achievement_id)
        END IF
    END FUNCTION
END CLASS
```

### 6.6 Multiplayer Network Sync

```pseudocode
CLASS NetworkManager:
    
    VARIABLES:
        is_host: boolean
        peer_id: integer
        connection_active: boolean
    
    FUNCTION host_game():
        peer = new ENetMultiplayerPeer()
        error = peer.create_server(PORT)
        
        IF error != OK:
            show_error("Failed to host")
            RETURN
        END IF
        
        multiplayer.set_multiplayer_peer(peer)
        is_host = true
        connection_active = true
        start_discovery_broadcast()
    END FUNCTION
    
    FUNCTION join_game(host_ip: string):
        peer = new ENetMultiplayerPeer()
        error = peer.create_client(host_ip, PORT)
        
        IF error != OK:
            show_error("Failed to connect")
            RETURN
        END IF
        
        multiplayer.set_multiplayer_peer(peer)
        is_host = false
        connection_active = true
    END FUNCTION
    
    @rpc("any_peer", "reliable")
    FUNCTION sync_performance(data: Dictionary):
        sender_id = multiplayer.get_remote_sender_id()
        
        // Store partner's performance
        partner_performance = data
        
        // Notify game of partner update
        emit_signal("partner_data_received", data)
        
        // Update cooperative adaptation
        CoopAdaptation.update_partner_metrics(data)
    END FUNCTION
    
    FUNCTION send_my_performance(score, accuracy, time):
        data = {
            "score": score,
            "accuracy": accuracy,
            "completion_time": time
        }
        
        // Send to all peers
        rpc("sync_performance", data)
    END FUNCTION
END CLASS
```

---

## 7. Scope and Limitations

### 7.1 Scope by System Architecture Modules

This section defines what each architectural layer/module includes and excludes, mapped to the 4-tier system architecture.

---

#### 7.1.1 LAYER 1: Presentation Layer (UI/UX)

**IN SCOPE:**

| **Module/Component**      | **Features Included**                                                                 |
|---------------------------|---------------------------------------------------------------------------------------|
| **Main Menu**             | Title screen, game selection grid, settings button, multiplayer mode toggle           |
| **Game Selection Screen** | 10 mini-game cards with icons, high scores, star ratings, locked/unlocked states      |
| **Settings Panel**        | Language toggle (EN/TL), volume slider, colorblind mode, tutorial reset               |
| **Results Screen**        | Final score, stars earned (1-3), achievements unlocked, retry/continue buttons        |
| **Tutorial Popups**       | First-time instructions, swipe/tap demos, visual hints with arrows                    |
| **HUD (In-Game)**         | Score counter, timer, lives/progress bar, pause button, combo streak indicator        |
| **Accessibility UI**      | Large touch targets (80-100px), high-contrast mode, audio cue indicators              |

**OUT OF SCOPE:**

- User profiles with avatars
- Customizable themes/skins
- Animated video tutorials (text + static images only)
- Chat/messaging system (multiplayer is cooperative, not competitive)
- In-game store or currency shop

**LIMITATIONS:**

- **Screen Size**: Optimized for 720x1280 minimum; may have layout issues on tablets >10"
- **Resolution**: No dynamic UI scaling beyond 1920x1080 (may appear pixelated on 4K displays)
- **Responsiveness**: 60 FPS target; UI updates may lag on devices <2GB RAM

---

#### 7.1.2 LAYER 2: Business Logic Layer (Game Engine Core)

**IN SCOPE:**

| **Module/Component**      | **Features Included**                                                                 |
|---------------------------|---------------------------------------------------------------------------------------|
| **MiniGameBase Class**    | Abstract game loop (`_ready`, `_process`, `record_action`, `end_game`)                |
| **10 Mini-Games**         | CatchTheRain, BucketBrigade, FixTheLeak, GreywaterSorter, MudPieMaker, QuickShower, SpotTheSpeck, TimingTap, TurnOffTheTap, SwipeSoap |
| **Game Mechanics**        | Collision detection, drag-and-drop, tap timing, swipe recognition, object pooling     |
| **Scoring System**        | Base points + time bonus + accuracy bonus + combo multiplier                          |
| **Win/Lose Conditions**   | Target-based (reach score), time-based (finish before timer), lives-based (avoid 0)   |
| **Difficulty Modes**      | Easy (0.7x), Medium (1.0x), Hard (1.3x) with adaptive adjustment                      |

**OUT OF SCOPE:**

- More than 10 mini-games in initial release
- Boss battles or special event games
- Procedurally generated game levels (all hand-designed)
- Physics simulations (realistic water flow, gravity—simplified for performance)
- AI opponents (cooperative only, no competitive AI)

**LIMITATIONS:**

- **Frame Rate Dependency**: Physics tied to `_process(delta)`, may behave differently at <30 FPS
- **Collision Precision**: Uses Area2D overlap (not raycasting), small fast objects may tunnel through
- **Difficulty Granularity**: Only 3 base levels (easy/medium/hard), multiplier adjusts in 0.1 increments
- **Game Length**: Fixed 30-60 second durations, no endless modes

---

#### 7.1.3 LAYER 3: Service Layer (Autoload Managers)

##### **AdaptiveDifficulty Module**

**IN SCOPE:**
- G-Counter CRDT (success/failure counters, lifetime ratio calculation)
- Rolling Window Queue (last 10 actions, real-time ratio)
- Difficulty multiplier calculation (`lerp(0.7, 1.3, ratio)`)
- Persistent storage of counters via SaveManager

**OUT OF SCOPE:**
- Machine learning-based difficulty prediction
- Player skill profiling (e.g., reaction time, pattern recognition)
- Adaptive tutorials based on failure points

**LIMITATIONS:**
- **History Length**: Rolling Window fixed at 10 actions (no configurable size)
- **Adjustment Speed**: Updates every action (can cause jitter if player is inconsistent)
- **G-Counter Monotonicity**: Counters only increase, cannot reset without deleting save file
- **Single Dimension**: Only tracks success rate, not time, combo, or other metrics

##### **NetworkManager Module**

**IN SCOPE:**
- UDP/ENet-based LAN discovery (broadcast on port 7777)
- Host/Client architecture (1 host, 1 client max)
- Real-time score/accuracy sync during multiplayer games
- Connection state tracking (connected, disconnected, error)

**OUT OF SCOPE:**
- Internet-based matchmaking (LAN only)
- NAT traversal (requires port forwarding for cross-subnet play)
- More than 2 players (no team games with 3+ participants)
- Peer-to-peer architecture (always host-client model)
- Encryption or anti-cheat (trusted LAN environment assumed)

**LIMITATIONS:**
- **Network Latency**: Designed for <50ms LAN; >100ms causes visible sync lag
- **Packet Loss**: No retry mechanism (lost packets = desynced scores)
- **Discovery Timeout**: 5-second window to find hosts; manual IP entry if fails
- **Bandwidth**: ~1 KB/s per player (may struggle on congested networks)

##### **SaveManager Module**

**IN SCOPE:**
- ConfigFile-based local storage (`user://waterwise_save.cfg`)
- Save data: high scores, achievements, settings, G-Counter values
- Auto-save after each game, manual save on setting changes
- Load on app startup

**OUT OF SCOPE:**
- Cloud save synchronization (e.g., Google Drive, iCloud)
- Multiple save slots (single profile per device)
- Save file encryption (plain text ConfigFile)
- Import/export save data

**LIMITATIONS:**
- **Storage Location**: `user://` folder (deleted if app cache cleared on Android)
- **File Size**: ~10 KB (no compression needed)
- **Save Frequency**: Only on game end (crash during game = lost progress)
- **Data Validation**: No checksum or corruption detection

##### **Localization Module**

**IN SCOPE:**
- English (EN) and Filipino/Tagalog (TL) translations
- Runtime language switching (no app restart required)
- String dictionary in CSV format
- UI text, button labels, tutorial messages

**OUT OF SCOPE:**
- Right-to-left (RTL) language support (e.g., Arabic, Hebrew)
- Additional languages beyond EN/TL
- Context-sensitive translations (same word always translates identically)
- Audio/voice localization

**LIMITATIONS:**
- **Character Sets**: Latin alphabet only (no Chinese, Japanese, Korean support)
- **Translation Quality**: Community-translated (no professional localization)
- **UI Space**: Fixed UI layout may cause text overflow in verbose translations

##### **Other Managers**

| **Manager**               | **In Scope**                              | **Out of Scope**                       | **Limitations**                          |
|---------------------------|-------------------------------------------|----------------------------------------|------------------------------------------|
| **AccessibilityManager**  | Colorblind mode, large targets, audio cues| Screen reader support, voice control   | No dyslexia font, no motion sickness mode|
| **AudioManager**          | Procedural SFX, looping BGM               | Licensed music, voice acting           | No spatial audio, mono output only       |
| **TutorialManager**       | First-time popups, per-game hints         | Interactive tutorials, video guides    | Text + static images only                |
| **CoopAdaptation**        | 2-player load balancing (0.8x-1.1x adjust)| 3+ player support, skill matchmaking   | Only balances accuracy, not playstyle    |

---

#### 7.1.4 LAYER 4: Data Persistence Layer

**IN SCOPE:**

| **Data Category**         | **Stored Information**                                                                |
|---------------------------|---------------------------------------------------------------------------------------|
| **Game Progress**         | High scores per mini-game, total droplets collected, games played counter             |
| **Achievements**          | 15+ unlockable badges (first game, water saver, perfect round, etc.)                  |
| **Settings**              | Language preference, volume level, colorblind mode enabled                            |
| **Adaptive Difficulty**   | G-Counter values (success/failure counts), recommended difficulty level               |
| **Tutorial State**        | Flags for which tutorials have been shown (`tutorial_shown_catch_rain: true`)         |

**OUT OF SCOPE:**
- Session replays or game recordings
- Detailed play history (e.g., scores by date, performance graphs)
- User analytics or telemetry data
- Social features (friends, sharing, leaderboards)

**LIMITATIONS:**
- **Data Loss Risk**: Save file in app cache folder (cleared if user clears storage on Android)
- **No Backup**: Single save file, no automatic backups or recovery
- **Format**: ConfigFile (INI-like), manual editing can corrupt data
- **Size Cap**: Unlimited technically, but designed for <50 KB total data

---

### 7.2 Technical Limitations by Architecture Layer

#### 7.2.1 Hardware Requirements

| **Requirement**       | **Minimum**                    | **Recommended**              | **Architecture Impact**                  |
|-----------------------|--------------------------------|------------------------------|------------------------------------------|
| **Processor**         | Dual-core 1.2 GHz              | Quad-core 1.5 GHz            | Game logic layer may drop frames on min  |
| **RAM**               | 2 GB                           | 4 GB                         | Asset pooling limited to 50 objects      |
| **Storage**           | 50 MB free space               | 100 MB free space            | Affects save file writes                 |
| **Screen**            | 720x1280 (HD)                  | 1080x1920 (FHD)              | UI scaling breaks on <720p               |
| **OS Version**        | Android 5.0 (Lollipop)         | Android 8.0 (Oreo) or newer  | Network APIs require API 21+             |
| **Network** (MP only) | WiFi 802.11n                   | WiFi 802.11ac                | UDP discovery needs LAN broadcast        |

#### 7.2.2 Performance Constraints by Module

| **Module**               | **Constraint**                                      | **Impact if Exceeded**                          |
|--------------------------|-----------------------------------------------------|-------------------------------------------------|
| **Game Loop (_process)** | 60 FPS target (16.67ms per frame)                   | Stuttering, input lag, incorrect physics        |
| **Rolling Window**       | 10 actions stored in queue                          | Memory overflow if queue size increased         |
| **Network Sync**         | <50ms LAN latency                                   | Desynced scores, frustrating multiplayer        |
| **Save Manager**         | ~10ms to write ConfigFile                           | Frame drop on auto-save if writing large data   |
| **UI Rendering**         | ~500 nodes max in scene tree                        | UI lag if too many animated elements            |

#### 7.2.3 Algorithm-Specific Limitations

| **Algorithm**               | **Limitation**                                      | **Module Affected**                | **Workaround**                            |
|-----------------------------|-----------------------------------------------------|------------------------------------|-------------------------------------------|
| **G-Counter**               | Monotonic increases only (no decrements)            | AdaptiveDifficulty                 | Delete save file to reset counters        |
| **Rolling Window**          | Fixed size (10), no weighted history                | AdaptiveDifficulty                 | Use G-Counter for long-term trends        |
| **Difficulty Multiplier**   | Linear interpolation (lerp 0.7-1.3)                 | MiniGameBase, AdaptiveDifficulty   | Clamp extreme values to prevent unfairness|
| **Load Balancing**          | Only compares 2 players (no 3+ support)             | CoopAdaptation                     | Design excludes team games for now        |
| **Score Calculation**       | Linear formula, no exponential scaling              | MiniGameBase                       | Combo bonuses add small non-linearity     |

---

### 7.3 Design Constraints

#### 7.3.1 Educational Requirements

- **Age Appropriateness**: Mechanics must be understandable by 6-year-olds (affects Layer 2: Game Logic)
- **Game Length**: Each mini-game must complete in <2 minutes to maintain attention (affects Layer 2)
- **Failure Tolerance**: Must not punish failure harshly (affects Layer 3: AdaptiveDifficulty)
- **Visual Clarity**: UI elements must have >4.5:1 contrast ratio (affects Layer 1: UI/UX)

#### 7.3.2 Cultural Considerations

- **Language Parity**: English and Filipino versions must have equal quality (affects Layer 3: Localization)
- **Local Context**: Water conservation scenarios relevant to Philippines (affects Layer 2: Game Content)
- **Color Symbolism**: Avoid red-green only indicators (affects Layer 1: AccessibilityManager)

#### 7.3.3 Platform Constraints

- **Android APK Size**: Target <50 MB (affects asset choices in all layers)
- **Godot 4.x**: Engine version locked (affects all layers, cannot use Godot 3 features)
- **GDScript Only**: No C# or C++ modules (affects performance optimizations in Layer 2)

---

### 7.4 Known Bugs and Limitations

| **Issue**                          | **Severity** | **Affected Module**            | **Workaround**                                      |
|------------------------------------|--------------|--------------------------------|-----------------------------------------------------|
| Welcome popup not showing          | Low          | Layer 1 (UI), Layer 4 (Save)   | Delete `user://waterwise_save.cfg` manually         |
| Unused signal warnings             | Cosmetic     | Layer 2 (MiniGameBase)         | Intentional API design, ignore warnings             |
| Multiplayer discovery timeout      | Medium       | Layer 3 (NetworkManager)       | Manually enter host IP if auto-discovery fails      |
| Rare collision detection miss      | Low          | Layer 2 (Game Logic)           | Objects moving too fast; increase collision checks  |
| Save file corruption on crash      | Medium       | Layer 4 (SaveManager)          | No fix; implement backup system in future update    |

---

## 8. Methodology

### 8.1 Development Methodology: Agile with Iterative Prototyping

WaterWise was developed using an **Agile methodology** with 2-week sprints, combined with **Iterative Prototyping** for game mechanics. The development process was structured around the **4-layer system architecture** (Presentation → Business Logic → Service → Data) to ensure proper separation of concerns and testability.

```
┌═══════════════════════════════════════════════════════════════════════════┐
│                        DEVELOPMENT LIFECYCLE                               │
├═══════════════════════════════════════════════════════════════════════════┤
│                                                                             │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                │
│   │  SPRINT N    │───►│  SPRINT N+1  │───►│  SPRINT N+2  │───► ...        │
│   │  (2 weeks)   │    │  (2 weeks)   │    │  (2 weeks)   │                │
│   └──────┬───────┘    └──────────────┘    └──────────────┘                │
│          │                                                                  │
│          ▼                                                                  │
│   ┌─────────────────────────────────────────────────────────────────┐     │
│   │  SPRINT WORKFLOW (Architecture-Driven)                          │     │
│   │                                                                  │     │
│   │  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐ │     │
│   │  │ Planning │───►│  Design  │───►│  Develop │───►│  Test    │ │     │
│   │  │ (Layer   │    │ (API     │    │ (Bottom  │    │ (Unit +  │ │     │
│   │  │ Priority)│    │  Design) │    │  Up)     │    │  Integ.) │ │     │
│   │  └──────────┘    └──────────┘    └──────────┘    └─────┬────┘ │     │
│   │                                                          │       │     │
│   │  ┌──────────┐    ┌──────────┐                           │       │     │
│   │  │  Deploy  │◄───│  Review  │◄──────────────────────────┘       │     │
│   │  │ (Merge)  │    │ (Retro)  │                                   │     │
│   │  └──────────┘    └──────────┘                                   │     │
│   └─────────────────────────────────────────────────────────────────┘     │
│                                                                             │
└═════════════════════════════════════════════════════════════════════════════┘
```

### 8.2 Architecture-Based Development Workflow

Development followed a **bottom-up approach** aligned with the system architecture layers:

```
┌═══════════════════════════════════════════════════════════════════════════┐
│              LAYER-BY-LAYER IMPLEMENTATION STRATEGY                        │
├═══════════════════════════════════════════════════════════════════════════┤
│                                                                             │
│  PHASE 1: Data Layer Foundation (Week 1-2)                                 │
│  ┌────────────────────────────────────────────────────────────────┐        │
│  │  ✅ Setup ConfigFile save system                               │        │
│  │  ✅ Define save data schema ([game], [settings], [achievements])│       │
│  │  ✅ Implement save/load functions                               │        │
│  │  ✅ Create test data for development                            │        │
│  │  ✅ Version control: .gitignore user:// folder                  │        │
│  └────────────────────────────────────────────────────────────────┘        │
│                                                                             │
│  PHASE 2: Service Layer (Week 3-6)                                         │
│  ┌────────────────────────────────────────────────────────────────┐        │
│  │  ✅ Create Autoload managers (GameManager, SaveManager, etc.)   │        │
│  │  ✅ Implement G-Counter algorithm (success/failure tracking)    │        │
│  │  ✅ Implement Rolling Window (10-action queue)                  │        │
│  │  ✅ Test AdaptiveDifficulty in isolation (unit tests)           │        │
│  │  ✅ Setup NetworkManager (UDP discovery, host/client)           │        │
│  │  ✅ Implement Localization system (EN/TL dictionaries)          │        │
│  │  ✅ Create AccessibilityManager (colorblind, large targets)     │        │
│  │                                                                  │        │
│  │  Key Deliverable: All managers functional and testable          │        │
│  └────────────────────────────────────────────────────────────────┘        │
│                                                                             │
│  PHASE 3: Business Logic Layer (Week 7-12)                                 │
│  ┌────────────────────────────────────────────────────────────────┐        │
│  │  ✅ Create MiniGameBase abstract class                          │        │
│  │     ├─ Core game loop: _ready(), _process(), end_game()        │        │
│  │     ├─ Difficulty integration: apply_difficulty_settings()     │        │
│  │     └─ Scoring: calculate_final_score()                        │        │
│  │                                                                  │        │
│  │  ✅ Implement 10 mini-games (iterative prototyping):            │        │
│  │     Week 7:  Catch The Rain (prototype mechanics)              │        │
│  │     Week 8:  Bucket Brigade (test difficulty scaling)          │        │
│  │     Week 9:  Fix The Leak (drag-drop mechanics)                │        │
│  │     Week 10: Greywater Sorter, Mud Pie Maker                   │        │
│  │     Week 11: Quick Shower, Spot The Speck, Timing Tap          │        │
│  │     Week 12: Turn Off The Tap, Swipe Soap                      │        │
│  │                                                                  │        │
│  │  ✅ Integrate adaptive difficulty (test multiplier effects)     │        │
│  │  ✅ Multiplayer sync (test network performance)                 │        │
│  │                                                                  │        │
│  │  Key Deliverable: All 10 games playable and balanced            │        │
│  └────────────────────────────────────────────────────────────────┘        │
│                                                                             │
│  PHASE 4: Presentation Layer (Week 13-15)                                  │
│  ┌────────────────────────────────────────────────────────────────┐        │
│  │  ✅ Design UI/UX wireframes (Figma mockups)                     │        │
│  │  ✅ Implement MainMenu.tscn (title, settings, game selection)   │        │
│  │  ✅ Implement GameSelection.tscn (grid of 10 mini-games)        │        │
│  │  ✅ Implement Settings.tscn (language, volume, accessibility)   │        │
│  │  ✅ Implement Results.tscn (score, stars, achievements)         │        │
│  │  ✅ Add tutorial popups (first-time user guidance)              │        │
│  │  ✅ Visual polish: animations, transitions, juice effects       │        │
│  │                                                                  │        │
│  │  Key Deliverable: Complete UI flow from launch to game end      │        │
│  └────────────────────────────────────────────────────────────────┘        │
│                                                                             │
│  PHASE 5: Integration & Testing (Week 16-18)                               │
│  ┌────────────────────────────────────────────────────────────────┐        │
│  │  ✅ Cross-layer integration testing                             │        │
│  │     ├─ Layer 1 ↔ Layer 2: UI triggers game logic correctly     │        │
│  │     ├─ Layer 2 ↔ Layer 3: Games call Autoload managers         │        │
│  │     └─ Layer 3 ↔ Layer 4: Managers persist data correctly      │        │
│  │                                                                  │        │
│  │  ✅ Playtesting with target audience (kids 6-12 years old)      │        │
│  │  ✅ Performance optimization (frame rate, memory)               │        │
│  │  ✅ Accessibility validation (colorblind simulators)            │        │
│  │  ✅ Multiplayer stress testing (LAN with 2 devices)             │        │
│  │  ✅ Bug fixing and polish                                       │        │
│  │                                                                  │        │
│  │  Key Deliverable: Production-ready build                        │        │
│  └────────────────────────────────────────────────────────────────┘        │
│                                                                             │
└═════════════════════════════════════════════════════════════════════════════┘
```

### 8.3 Development Phases with Architectural Mapping

#### Phase 1: Requirements Analysis

| **Activity**                  | **Deliverable**                  | **Architecture Reference**              |
|-------------------------------|----------------------------------|-----------------------------------------|
| Stakeholder interviews        | User requirements document       | Defines Layer 1 UI needs                |
| Educational content research  | Water conservation facts list    | Defines Layer 2 game content            |
| Target audience analysis      | Child-friendly design guidelines | Affects Layer 1 UI/UX, Layer 3 Accessibility |
| Technical feasibility study   | Technology stack selection       | Godot 4.x → determines all layers       |
| Algorithm research            | G-Counter + Rolling Window specs | Defines Layer 3 AdaptiveDifficulty      |

#### Phase 2: System Design

| **Activity**                  | **Deliverable**                  | **Architecture Reference**              |
|-------------------------------|----------------------------------|-----------------------------------------|
| Architecture design           | 4-layer architecture diagram     | **Section 2: System Architecture**      |
| Data modeling                 | Save file schema (ConfigFile)    | Layer 4: Data Persistence               |
| API design                    | Autoload manager interfaces      | Layer 3: Service Layer                  |
| Game mechanics design         | MiniGameBase class specification | Layer 2: Business Logic                 |
| UI/UX wireframes              | Screen mockups (Figma)           | Layer 1: Presentation                   |
| Algorithm pseudocode          | G-Counter, Rolling Window, Score | **Section 6: Pseudocode**               |

#### Phase 3: Implementation (Bottom-Up)

| **Sprint** | **Focus**                        | **Layers Affected**          | **Integration Points**                    |
|------------|----------------------------------|------------------------------|-------------------------------------------|
| Sprint 1   | Data layer + SaveManager         | Layer 4 → Layer 3            | SaveManager reads/writes ConfigFile       |
| Sprint 2   | AdaptiveDifficulty (algorithms)  | Layer 3                      | Uses SaveManager to persist G-Counter     |
| Sprint 3   | NetworkManager (LAN setup)       | Layer 3                      | Independent module (no dependencies yet)  |
| Sprint 4   | MiniGameBase abstract class      | Layer 2                      | Calls AdaptiveDifficulty.record_action()  |
| Sprint 5   | First 2 mini-games (prototypes)  | Layer 2                      | Extends MiniGameBase                      |
| Sprint 6   | Remaining 8 mini-games           | Layer 2                      | Parallel development of game logic        |
| Sprint 7   | MainMenu + GameSelection UI      | Layer 1 → Layer 2            | UI buttons call GameManager.start_game()  |
| Sprint 8   | Settings + Results UI            | Layer 1 → Layer 3            | UI updates Autoload managers              |
| Sprint 9   | Multiplayer integration          | Layer 2 ↔ Layer 3            | Games sync via NetworkManager             |

#### Phase 4: Testing (Top-Down)

| **Test Type**           | **Scope**                          | **Architecture Focus**                   |
|-------------------------|------------------------------------|------------------------------------------|
| **Unit Testing**        | Individual functions/classes       | Layer 3 (Autoload managers tested first) |
| **Integration Testing** | Cross-layer interactions           | Layer 1 → Layer 2 → Layer 3 → Layer 4    |
| **System Testing**      | End-to-end game flow               | All layers (launch → play → save → quit) |
| **Playtesting**         | User experience evaluation         | Layer 1 (UI/UX), Layer 2 (game balance)  |
| **Performance Testing** | Frame rate, memory, network lag    | Layer 2 (game loop), Layer 3 (network)   |
| **Accessibility Testing** | Colorblind mode, touch targets    | Layer 1 (UI), Layer 3 (AccessibilityMgr) |

#### Phase 5: Deployment

| **Activity**           | **Deliverable**                  | **Architecture Reference**              |
|------------------------|----------------------------------|-----------------------------------------|
| Build generation       | Android APK, Windows .exe        | Export all layers via Godot build system|
| Documentation          | Technical docs (this file!)      | **Complete architecture documentation** |
| User guide             | How to play, troubleshooting     | Layer 1 (UI flow), multiplayer setup    |
| Release                | Published application            | Full 4-layer stack deployed             |

---

### 8.4 Testing Methodology

#### 8.4.1 Testing Strategy by Architecture Layer

```
┌═══════════════════════════════════════════════════════════════════════════┐
│                    TESTING PYRAMID (Bottom-Up)                             │
├═══════════════════════════════════════════════════════════════════════════┤
│                                                                             │
│                              ┌─────────────┐                               │
│                              │  Manual E2E │  ← Layer 1: UI/UX Flow        │
│                              │  Testing    │    (Human testers)            │
│                              └─────────────┘                               │
│                         ┌───────────────────────┐                          │
│                         │  Integration Testing  │  ← Layer 1 ↔ Layer 2    │
│                         │  (Cross-layer)        │    (Automated + Manual) │
│                         └───────────────────────┘                          │
│                  ┌─────────────────────────────────────┐                   │
│                  │  Component Testing                  │  ← Layer 2        │
│                  │  (MiniGameBase, individual games)   │    (Unit tests)   │
│                  └─────────────────────────────────────┘                   │
│           ┌─────────────────────────────────────────────────────┐          │
│           │  Service Testing (Autoload Managers)                │  ← Layer 3│
│           │  (AdaptiveDifficulty, NetworkManager, SaveManager)  │  (Unit)   │
│           └─────────────────────────────────────────────────────┘          │
│    ┌────────────────────────────────────────────────────────────────────┐  │
│    │  Data Layer Testing (ConfigFile read/write)                        │  │
│    │  (SaveManager persistence, G-Counter serialization)                │  │
│    └────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ▲                                                                          │
│  │  Test Volume: 70% Unit (Layer 3-4), 20% Integration, 10% E2E           │
│  │  Priority: Bottom-up (test foundations before building on top)         │
│                                                                             │
└═════════════════════════════════════════════════════════════════════════════┘
```

#### 8.4.2 Testing Types Applied

| **Test Type**           | **Description**                          | **Tools**                | **Layer Focus**          |
|-------------------------|------------------------------------------|--------------------------|--------------------------|
| **Unit Testing**        | Test individual functions/classes        | GDScript asserts, GUT    | Layer 3 (Autoloads)      |
| **Integration Testing** | Test cross-layer interactions            | Manual + scripted tests  | Layer 2 ↔ Layer 3        |
| **Playtesting**         | User experience evaluation               | Child testers (6-12 yrs) | Layer 1 (UI/UX)          |
| **Performance Testing** | Frame rate, memory profiling             | Godot Profiler           | Layer 2 (game loop)      |
| **Accessibility Testing** | Colorblind mode, touch target size     | Colorblind simulators    | Layer 1 + Layer 3        |
| **Network Testing**     | Multiplayer sync, latency handling       | 2-device LAN setup       | Layer 3 (NetworkManager) |

#### 8.4.3 Test Cases Example (Layer-Specific)

| **Test ID** | **Test Case**                     | **Expected Result**                  | **Layer** | **Status** |
|-------------|-----------------------------------|--------------------------------------|-----------|------------|
| **TC-L4-01**| Save ConfigFile to disk           | File created at `user://`            | Layer 4   | ✅         |
| **TC-L4-02**| Load ConfigFile on startup        | Data parsed correctly                | Layer 4   | ✅         |
| **TC-L3-01**| G-Counter increments on success   | success_count += 1                   | Layer 3   | ✅         |
| **TC-L3-02**| Rolling Window enqueue/dequeue    | Queue size stays ≤ 10                | Layer 3   | ✅         |
| **TC-L3-03**| NetworkManager UDP discovery      | Host found within 5 seconds          | Layer 3   | ✅         |
| **TC-L2-01**| MiniGame applies difficulty       | speed *= multiplier                  | Layer 2   | ✅         |
| **TC-L2-02**| CatchTheRain win condition        | score >= target → end_game(true)     | Layer 2   | ✅         |
| **TC-L2-03**| BucketBrigade kid-friendly        | No falling buckets, large tap targets| Layer 2   | ✅         |
| **TC-I1-01**| UI button starts game             | Layer 1 → Layer 2 transition         | L1↔L2     | ✅         |
| **TC-I2-01**| Game saves progress on end        | Layer 2 → Layer 3 → Layer 4          | L2↔L3↔L4  | ✅         |
| **TC-E2E-01**| Launch → Play → Save → Quit       | Complete flow works                  | All       | ✅         |

---

### 8.5 Version Control and Collaboration

- **Git Branching Strategy**: Gitflow (main, develop, feature/* branches)
- **Commit Convention**: `[Layer] Feature: description`  
  - Example: `[L3] AdaptiveDifficulty: Implement G-Counter persistence`
- **Code Review**: All commits to `develop` require peer review
- **CI/CD**: Automated builds on push (GitHub Actions for exports)

---

### 8.6 Documentation Strategy

| **Document**                   | **Architecture Reference**                | **Audience**                |
|--------------------------------|-------------------------------------------|-----------------------------|
| **WATERWISE_DOCUMENTATION.md** | Complete system architecture (this file!) | Developers, researchers     |
| **DEVELOPER_GUIDE.md**         | Layer 2 (game development API)            | Game designers              |
| **ARCHITECTURE.md**            | Layer-by-layer design decisions           | System architects           |
| **README.md**                  | User-facing installation guide            | Players, educators          |

---

### 8.7 Key Development Principles

1. **Separation of Concerns**: Each layer has a single, well-defined responsibility  
   - Layer 1: Render UI, capture input  
   - Layer 2: Game logic, scoring, win conditions  
   - Layer 3: Global state, algorithms, services  
   - Layer 4: Data persistence only  

2. **Dependency Direction**: Always top-down (no circular dependencies)  
   - Layer 1 depends on → Layer 2  
   - Layer 2 depends on → Layer 3  
   - Layer 3 depends on → Layer 4  
   - Layer 4 depends on → nothing (standalone)

3. **Testability**: Build from bottom up, test from bottom up  
   - Layer 4 tested first (data operations)  
   - Layer 3 tested with mocked Layer 4  
   - Layer 2 tested with real Layer 3  
   - Layer 1 tested manually (UI/UX)

4. **Modularity**: Each Autoload manager is independent  
   - AdaptiveDifficulty can be disabled without breaking games  
   - NetworkManager only loads for multiplayer mode  
   - Localization can add new languages without code changes
| TC-06 | Join multiplayer | Client connects | ✅ |
| TC-07 | Change language | UI updates to new language | ✅ |
| TC-08 | Enable colorblind mode | Colors transformed | ✅ |

### 8.4 Quality Assurance

```
┌─────────────────────────────────────────────────────────────────┐
│                    QA CHECKPOINTS                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐                                                 │
│  │ Code Review │ ─── Every commit reviewed for:                 │
│  └─────────────┘     • GDScript style compliance                │
│        │             • Performance considerations                │
│        ▼             • Error handling                            │
│  ┌─────────────┐                                                 │
│  │ Functional  │ ─── Each feature verified:                     │
│  │   Testing   │     • Works as specified                       │
│  └─────────────┘     • No regressions                           │
│        │                                                         │
│        ▼                                                         │
│  ┌─────────────┐                                                 │
│  │ Playtest    │ ─── Child-friendly validation:                 │
│  │  Sessions   │     • Easy to understand                       │
│  └─────────────┘     • Engaging gameplay                        │
│        │             • Educational value                         │
│        ▼                                                         │
│  ┌─────────────┐                                                 │
│  │   Release   │ ─── Final checklist:                           │
│  │   Approval  │     • All tests passed                         │
│  └─────────────┘     • Performance acceptable                   │
│                      • Documentation complete                    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Data Dictionary

### 9.1 Global Variables (GameManager)

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `current_game_index` | int | Index in shuffled game list | 0 |
| `water_droplets` | int | Currency/points collected | 0 |
| `high_score` | int | Highest single-game score | 0 |
| `games_played` | int | Total games completed | 0 |
| `total_score` | int | Cumulative all-time score | 0 |
| `first_launch` | bool | Is this first app launch? | true |
| `dark_mode_enabled` | bool | Dark theme active | false |

### 9.2 Adaptive Difficulty Variables

| Variable | Type | Description | Range |
|----------|------|-------------|-------|
| `rolling_window` | Array[bool] | Last 10 action results | 0-10 items |
| `g_success_counter` | int | Lifetime successes | 0+ |
| `g_failure_counter` | int | Lifetime failures | 0+ |
| `difficulty_multiplier` | float | Current adjustment | 0.7 - 1.3 |
| `current_difficulty` | String | Easy/Medium/Hard | Enum |

### 9.3 Mini-Game Base Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `game_name` | String | Display name | "" |
| `game_active` | bool | Is game running? | false |
| `game_duration` | float | Time limit (seconds) | 30.0 |
| `time_remaining` | float | Current time left | game_duration |
| `score` | int | Current game score | 0 |
| `lives` | int | Remaining lives | 3 |
| `current_difficulty` | String | Applied difficulty | "Medium" |

### 9.4 Save Data Structure

```
waterwise.cfg
├── [game]
│   ├── water_droplets: int
│   ├── high_score: int
│   ├── games_played: int
│   ├── total_score: int
│   └── first_launch: bool
│
├── [settings]
│   ├── language: String ("en" | "tl")
│   ├── music_volume: float (0.0-1.0)
│   ├── sfx_volume: float (0.0-1.0)
│   ├── colorblind_mode: bool
│   ├── large_touch_targets: bool
│   └── dark_mode: bool
│
├── [high_scores]
│   ├── CatchTheRain: int
│   ├── BucketBrigade: int
│   ├── FixTheLeak: int
│   └── ... (per game)
│
├── [achievements]
│   ├── first_game: bool
│   ├── water_saver: bool
│   ├── speed_demon: bool
│   └── ...
│
└── [adaptive]
    ├── g_success: int
    ├── g_failure: int
    └── recommended_difficulty: String
```

### 9.5 Network Packet Structure

```
Performance Sync Packet:
{
    "player_id": int,          // 1 or 2
    "score": int,              // Current score
    "accuracy": float,         // 0.0 - 1.0
    "completion_time": float,  // Seconds
    "game_id": String,         // Mini-game name
    "timestamp": int           // Unix timestamp
}

Discovery Broadcast:
{
    "game": "WaterWise",
    "version": "1.0",
    "host_name": String,
    "port": int
}
```

---

## 10. Complete Feature List

### 10.1 Mini-Games (10 Total)

| # | Game Name | Mechanic | Educational Goal |
|---|-----------|----------|------------------|
| 1 | **Catch The Rain** | Move bucket to catch drops | Rainwater harvesting |
| 2 | **Bucket Brigade** | Tap to pass buckets | Community water sharing |
| 3 | **Fix The Leak** | Drag plugs to holes | Preventing water waste |
| 4 | **Greywater Sorter** | Swipe items up/down | Water recycling |
| 5 | **Mud Pie Maker** | Tap to add water carefully | Water measurement |
| 6 | **Quick Shower** | Tap body parts quickly | Efficient showering |
| 7 | **Spot The Speck** | Find dirty dishes | Water quality awareness |
| 8 | **Timing Tap** | Tap in green zone | Turning off taps |
| 9 | **Turn Off Tap** | Find open faucets | Stopping leaks |
| 10 | **Swipe The Soap** | Swipe in patterns | Handwashing efficiency |

### 10.2 System Features

| Category | Feature | Description |
|----------|---------|-------------|
| **Adaptive AI** | G-Counter | Lifetime performance tracking |
| | Rolling Window | Real-time difficulty adjustment |
| | Load Balancing | Multiplayer fairness |
| **Multiplayer** | LAN Co-op | 2-player local network |
| | UDP Discovery | Auto-find games |
| | Performance Sync | Share scores |
| **Persistence** | Auto-Save | Progress saved automatically |
| | High Scores | Per-game records |
| | Achievements | Unlockable milestones |
| **Localization** | English | Full UI + tutorials |
| | Filipino | Complete translation |
| **Accessibility** | Colorblind Mode | Alternative palette |
| | Large Targets | 80px touch areas |
| | Audio Cues | Sound feedback |
| | Reduced Motion | Simpler animations |
| **Audio** | Procedural SFX | Generated sounds |
| | Background Music | Ambient audio |
| **Tutorials** | First-Time | Per-game instructions |
| | Contextual Hints | In-game tips |
| **Theming** | Dark Mode | Dark UI option |
| | Light Mode | Default bright UI |

### 10.3 UI Screens

| Screen | Purpose | Key Elements |
|--------|---------|--------------|
| **MainMenu** | Entry point | Play, Settings, Multiplayer buttons |
| **InitialScreen** | Game hub | Waterpark scene, play button |
| **WelcomePopup** | First launch | Game introduction |
| **Settings** | Configuration | Language, volume, accessibility |
| **GameSelection** | Choose game | Grid of mini-games |
| **Instructions** | How to play | General guidance |
| **MultiplayerLobby** | Network setup | Host/Join options |
| **Results** | Post-game | Score, stars, continue |
| **UnlockablesScreen** | Achievements | Progress display |

### 10.4 Educational Content

| Topic | Games Teaching It | Key Lesson |
|-------|------------------|------------|
| **Rainwater Harvesting** | Catch Rain, Bucket Brigade | Collect natural water |
| **Leak Prevention** | Fix Leak, Turn Off Tap | Stop water waste |
| **Water Recycling** | Greywater Sorter | Reuse grey water |
| **Efficient Usage** | Quick Shower, Mud Pie | Use only what's needed |
| **Cleanliness** | Spot Speck, Swipe Soap | Water for hygiene |
| **Timing/Awareness** | Timing Tap | Don't leave water running |

---

## Appendix A: File Structure

```
waterwise/
├── project.godot              # Godot project configuration
├── icon.svg                   # App icon
├── README.md                  # Project readme
├── WATERWISE_DOCUMENTATION.md # This document
│
├── autoload/                  # Global singleton managers
│   ├── GameManager.gd
│   ├── AdaptiveDifficulty.gd
│   ├── Localization.gd
│   ├── NetworkManager.gd
│   ├── CoopAdaptation.gd
│   ├── ThemeManager.gd
│   ├── SaveManager.gd
│   ├── TutorialManager.gd
│   ├── AccessibilityManager.gd
│   └── AudioManager.gd
│
├── scenes/
│   ├── ui/                    # UI screens
│   │   ├── MainMenu.tscn/.gd
│   │   ├── InitialScreen.tscn/.gd
│   │   ├── Settings.tscn/.gd
│   │   ├── GameSelection.tscn/.gd
│   │   ├── MultiplayerLobby.tscn/.gd
│   │   ├── Instructions.tscn/.gd
│   │   └── UnlockablesScreen.tscn/.gd
│   │
│   └── minigames/             # Game scenes
│       ├── CatchTheRain.gd
│       ├── BucketBrigade.gd
│       ├── FixTheLeak.gd
│       ├── GreywaterSorter.gd
│       ├── MudPieMaker.gd
│       ├── QuickShower.gd
│       ├── SpotTheSpeck.gd
│       ├── TimingTap.gd
│       ├── TurnOffTap.gd
│       └── SwipeTheSoap.gd
│
├── scripts/
│   ├── MiniGameBase.gd        # Abstract base class
│   ├── JuiceEffects.gd        # Visual polish
│   ├── Bobbing.gd             # Animation helper
│   └── multiplayer/           # MP-specific scripts
│
├── shaders/                   # Visual shaders
│   ├── wave.gdshader
│   └── grid.gdshader
│
└── fonts/                     # Custom fonts
    ├── Cubao_Free_Wide.otf
    └── NTBrickSans.otf
```

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| **G-Counter** | Grow-only counter CRDT for distributed counting |
| **CRDT** | Conflict-free Replicated Data Type |
| **Rolling Window** | Fixed-size queue of recent events |
| **Autoload** | Godot singleton pattern for global managers |
| **GDScript** | Python-like scripting language for Godot |
| **ENet** | UDP networking library used by Godot |
| **ConfigFile** | Godot's INI-like data storage format |
| **Greywater** | Wastewater that can be recycled (not sewage) |

---

*Document Version: 1.0*  
*Last Updated: December 2025*  
*Engine Version: Godot 4.5*
