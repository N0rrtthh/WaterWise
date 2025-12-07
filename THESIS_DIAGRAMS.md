# WATERWISE EDUCATIONAL GAME - TECHNICAL DIAGRAMS
## Formal Documentation for Thesis Research

**Document Version:** 1.0  
**Date:** December 2024  
**System:** WaterWise - Adaptive Educational Game for Water Conservation  
**Engine:** Godot 4.x (GDScript)  

---

## TABLE OF CONTENTS

1. [System Architecture Diagram](#1-system-architecture-diagram)
2. [Adaptive Difficulty Algorithm Flowchart](#2-adaptive-difficulty-algorithm-flowchart)
3. [Data Flow Diagram (DFD)](#3-data-flow-diagram)
4. [Use Case Diagram](#4-use-case-diagram)
5. [Class Diagram](#5-class-diagram)
6. [Entity-Relationship Diagram](#6-entity-relationship-diagram)
7. [Sequence Diagram - Game Session](#7-sequence-diagram---game-session)
8. [State Machine Diagram](#8-state-machine-diagram)
9. [IPO Chart](#9-ipo-chart---input-process-output)
10. [Network Architecture (Multiplayer)](#10-network-architecture-diagram)

---

## 1. SYSTEM ARCHITECTURE DIAGRAM

### 1.1 Four-Module System Architecture

```mermaid
flowchart TB
    %% User at the top
    USER(("👤 USER"))
    USER2(("👤 USER 2<br/>(Co-op)"))
    
    %% Module 1: Presentation
    subgraph M1["MODULE 1: PRESENTATION"]
        M1_UI["UI Screens<br/>• InitialScreen<br/>• MainMenu<br/>• Settings<br/>• Instructions<br/>• CharacterCustomization"]
        M1_HUD["In-Game HUD<br/>• Timer Bar<br/>• Lives Display<br/>• Score Counter<br/>• Pause Button"]
        M1_RESULTS["Results Screens<br/>• MiniGameResults<br/>• FinalScore"]
        M1_MP["Multiplayer UI<br/>• MultiplayerMenu<br/>• MultiplayerLobby"]
    end
    
    %% Module 2: Business Logic
    subgraph M2["MODULE 2: BUSINESS LOGIC"]
        M2_BASE["MiniGameBase.gd<br/>Abstract Class"]
        M2_GAMES["19 Mini-Games<br/>• CatchTheRain<br/>• BucketBrigade<br/>• FixLeak<br/>• ThirstyPlant<br/>• + 15 more"]
        M2_LOGIC["Game Logic<br/>• Collision Detection<br/>• Score Calculation<br/>• Timer Management"]
    end
    
    %% Module 3: Service
    subgraph M3["MODULE 3: SERVICE"]
        M3_GM["GameManager.gd<br/>State Controller"]
        M3_AD["AdaptiveDifficulty.gd<br/>Φ = WMA - CP"]
        M3_LOC["Localization.gd<br/>EN / Filipino"]
        M3_NET["NetworkManager<br/>ENet UDP:7777"]
        M3_COOP["CoopAdaptation.gd<br/>Player Skill Balancing"]
        M3_GC["G-Counter CRDT<br/>Score Synchronization"]
    end
    
    %% Module 4: Data Persistence
    subgraph M4["MODULE 4: DATA PERSISTENCE"]
        M4_CONFIG[("ConfigFile<br/>waterwise_save.cfg")]
        M4_JSON[("JSON Export<br/>Session Data")]
    end
    
    %% Connections: User to Module 1
    USER -->|"1. Touch Input"| M1
    USER2 -->|"1b. LAN Input"| M1_MP
    
    %% Module 1 internal
    M1_UI --> M1_HUD
    M1_HUD --> M1_RESULTS
    M1_UI --> M1_MP
    
    %% Module 1 to Module 2
    M1 -->|"2. Game Events"| M2
    
    %% Module 2 internal
    M2_BASE --> M2_GAMES
    M2_GAMES --> M2_LOGIC
    
    %% Module 2 to Module 3
    M2 -->|"3. Performance Data"| M3
    
    %% Module 3 internal
    M3_GM --> M3_AD
    M3_GM --> M3_LOC
    M3_GM --> M3_NET
    M3_NET --> M3_COOP
    M3_NET --> M3_GC
    
    %% Module 3 to Module 4
    M3 -->|"4. Save/Load"| M4
    
    %% Module 4 internal
    M4_CONFIG --> M4_JSON
    
    %% Return flows
    M4 -.->|"5. Load Settings"| M3
    M3 -.->|"6. Difficulty Settings"| M2
    M2 -.->|"7. Update Display"| M1
    M1 -.->|"8. Visual Feedback"| USER
    
    %% Multiplayer sync
    M3_GC <-.->|"UDP Sync"| USER2
    
    %% Styling
    classDef userStyle fill:#E91E63,stroke:#880E4F,stroke-width:3px,color:#fff
    classDef module1 fill:#2196F3,stroke:#0D47A1,stroke-width:2px,color:#fff
    classDef module2 fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    classDef module3 fill:#FF9800,stroke:#E65100,stroke-width:2px,color:#fff
    classDef module4 fill:#9C27B0,stroke:#4A148C,stroke-width:2px,color:#fff
    
    class USER,USER2 userStyle
    class M1_UI,M1_HUD,M1_RESULTS,M1_MP module1
    class M2_BASE,M2_GAMES,M2_LOGIC module2
    class M3_GM,M3_AD,M3_LOC,M3_NET,M3_COOP,M3_GC module3
    class M4_CONFIG,M4_JSON module4
```

### 1.2 Component Interaction Diagram

```mermaid
flowchart LR
    subgraph PRESENTATION["Presentation Module"]
        UI[UI Controller]
        HUD[HUD Display]
        MP_UI[Multiplayer UI]
    end
    
    subgraph BUSINESS["Business Logic Module"]
        MGB[MiniGameBase]
        MG1[CatchTheRain]
        MG2[BucketBrigade]
        MG3[FixLeak]
    end
    
    subgraph SERVICE["Service Module"]
        GM[GameManager]
        AD[AdaptiveDifficulty]
        LOC[Localization]
        NET[NetworkManager]
        COOP[CoopAdaptation]
        GC[(G-Counter)]
    end
    
    subgraph DATA["Data Module"]
        CF[(ConfigFile)]
    end
    
    UI -->|"start_game()"| MGB
    MP_UI -->|"host_game() / join_game()"| NET
    MGB --> MG1
    MGB --> MG2
    MGB --> MG3
    MG1 -->|"complete_minigame()"| GM
    MG2 -->|"complete_minigame()"| GM
    MG3 -->|"complete_minigame()"| GM
    GM -->|"add_performance()"| AD
    GM -->|"save_data()"| CF
    GM -->|"submit_score()"| GC
    AD -->|"get_difficulty_settings()"| MGB
    LOC -->|"get_text()"| UI
    CF -->|"load_data()"| GM
    GM -->|"update_hud()"| HUD
    NET -->|"sync_scores()"| GC
    NET -->|"get_player_difficulty()"| COOP
    COOP -->|"skill_params"| AD
```

### 1.3 Mini-Game Flow Logic

```mermaid
flowchart TD
    START([Start Mini-Game]) --> LOAD[Load Difficulty Settings]
    LOAD --> INIT[Initialize Game Variables]
    INIT --> SHOW[Show Instructions]
    SHOW --> WAIT[Wait for Player Input]
    
    WAIT --> ACTION{Player Action?}
    ACTION -->|Yes| CHECK{Correct?}
    ACTION -->|No| TIMER{Timer = 0?}
    
    CHECK -->|Yes| SUCCESS_ACT[score += 10<br/>correct_actions++]
    CHECK -->|No| FAIL_ACT[mistakes++<br/>time -= 2s penalty]
    
    SUCCESS_ACT --> TIMER
    FAIL_ACT --> TIMER
    
    TIMER -->|No| WAIT
    TIMER -->|Yes| TARGET{Target Reached?}
    
    TARGET -->|Yes| WIN[SUCCESS<br/>Calculate Accuracy]
    TARGET -->|No| LOSE[FAIL<br/>lives -= 1]
    
    WIN --> REPORT[Report to GameManager]
    LOSE --> LIVES{lives > 0?}
    
    LIVES -->|Yes| REPORT
    LIVES -->|No| GAMEOVER[GAME OVER]
    
    REPORT --> ADAPT[AdaptiveDifficulty<br/>Update Φ]
    ADAPT --> NEXT[Next Mini-Game]
    GAMEOVER --> MENU[Return to Menu]
    
    %% Styling
    classDef startEnd fill:#9C27B0,stroke:#4A148C,color:#fff
    classDef process fill:#2196F3,stroke:#0D47A1,color:#fff
    classDef decision fill:#FFF176,stroke:#F57F17,color:#000
    classDef success fill:#81C784,stroke:#2E7D32,color:#000
    classDef fail fill:#E57373,stroke:#C62828,color:#fff
    
    class START,NEXT,MENU startEnd
    class LOAD,INIT,SHOW,WAIT,REPORT,ADAPT process
    class ACTION,CHECK,TIMER,TARGET,LIVES decision
    class SUCCESS_ACT,WIN success
    class FAIL_ACT,LOSE,GAMEOVER fail
```

### 1.4 Multiplayer Architecture

```mermaid
flowchart TB
    subgraph HOST["HOST (Player 1)"]
        H_GM[GameManager<br/>is_host = true]
        H_GC[(G-Counter)]
        H_GAME[MiniGame]
    end
    
    subgraph CLIENT["CLIENT (Player 2)"]
        C_GM[GameManager<br/>is_host = false]
        C_GC[(G-Counter Copy)]
        C_GAME[MiniGame]
    end
    
    subgraph NETWORK["LAN Network"]
        NET[ENet UDP<br/>Port 7777]
    end
    
    H_GM <-->|"RPC Calls"| NET
    C_GM <-->|"RPC Calls"| NET
    
    H_GC <-->|"Sync Scores"| C_GC
    
    H_GAME -->|"submit_score()"| H_GC
    C_GAME -->|"submit_score()"| C_GC
    
    %% Styling
    classDef hostStyle fill:#4CAF50,stroke:#1B5E20,stroke-width:2px,color:#fff
    classDef clientStyle fill:#2196F3,stroke:#0D47A1,stroke-width:2px,color:#fff
    classDef networkStyle fill:#FF9800,stroke:#E65100,stroke-width:2px,color:#fff
    
    class H_GM,H_GC,H_GAME hostStyle
    class C_GM,C_GC,C_GAME clientStyle
    class NET networkStyle
```

### 1.5 System Architecture Table

| Module | Components | Responsibility |
|--------|------------|----------------|
| **Module 1: Presentation** | UI Screens, HUD, Results, Multiplayer UI | User interface rendering, input capture, visual feedback, lobby management |
| **Module 2: Business Logic** | MiniGameBase, 19 Mini-Games | Game mechanics, collision detection, scoring logic |
| **Module 3: Service** | GameManager, AdaptiveDifficulty, Localization, NetworkManager, CoopAdaptation, G-Counter | State management, difficulty adaptation, translations, multiplayer sync, skill balancing |
| **Module 4: Data Persistence** | ConfigFile, JSON Export | Save/load progress, session data export |

---

## 2. ADAPTIVE DIFFICULTY ALGORITHM FLOWCHART

### 2.1 Weighted Proficiency Index (Φ) Algorithm

```mermaid
flowchart TD
    START([🎮 GAME COMPLETED])
    
    subgraph INPUT["<b>INPUT: Performance Data</b>"]
        I1["accuracy: float (0.0 - 1.0)"]
        I2["reaction_time: int (milliseconds)"]
        I3["mistakes: int"]
        I4["game_name: String"]
    end
    
    subgraph WINDOW["<b>ROLLING WINDOW (FIFO Queue)</b>"]
        W1["performance_window: Array&lt;Dictionary&gt;[3]"]
        W2{"window.size() >= 3?"}
        W3["window.pop_front()<br/>(Remove oldest)"]
        W4["window.append(new_data)"]
    end
    
    subgraph WMA["<b>STEP 1: WEIGHTED MOVING AVERAGE</b>"]
        WMA1["<b>Formula:</b><br/>WMA = Σ(wᵢ × xᵢ) / Σ(wᵢ)"]
        WMA2["<b>Weights (Linear):</b><br/>Game 1: w=1<br/>Game 2: w=2<br/>Game 3: w=3"]
        WMA3["<b>Example:</b><br/>[0.6, 0.7, 0.95]<br/>WMA = (1×0.6 + 2×0.7 + 3×0.95) / 6<br/>= 4.85 / 6 = <b>0.808</b>"]
    end
    
    subgraph STD["<b>STEP 2: STANDARD DEVIATION (σ)</b>"]
        STD1["<b>Mean:</b> μ = Σ(timeᵢ) / N"]
        STD2["<b>Variance:</b> σ² = Σ(timeᵢ - μ)² / N"]
        STD3["<b>Std Dev:</b> σ = √(σ²)"]
        STD4["<b>Example:</b><br/>[5000, 6000, 5500]ms<br/>μ = 5500ms<br/>σ = 408.2ms"]
    end
    
    subgraph CP["<b>STEP 3: CONSISTENCY PENALTY</b>"]
        CP1["<b>Formula:</b><br/>CP = min(σ / 5000, 0.2)"]
        CP2["<b>Example:</b><br/>CP = min(408.2 / 5000, 0.2)<br/>= min(0.0816, 0.2)<br/>= <b>0.0816</b>"]
    end
    
    subgraph PHI["<b>STEP 4: PROFICIENCY INDEX (Φ)</b>"]
        PHI1["<b>Formula:</b><br/>Φ = WMA - CP"]
        PHI2["<b>Example:</b><br/>Φ = 0.808 - 0.0816<br/>= <b>0.726</b>"]
        PHI3["<b>Range:</b> -0.2 to 1.0"]
    end
    
    subgraph TREE["<b>STEP 5: RULE-BASED DECISION TREE</b>"]
        RULE1{"Φ < 0.5?"}
        RULE2{"Φ > 0.85?"}
        EASY["🟢 <b>EASY</b><br/>Player struggling<br/>or erratic timing"]
        MEDIUM["🟡 <b>MEDIUM</b><br/>Flow state<br/>Optimal learning"]
        HARD["🔴 <b>HARD</b><br/>Mastery +<br/>Consistency"]
    end
    
    subgraph OUTPUT["<b>OUTPUT: DIFFICULTY SETTINGS</b>"]
        OUT_E["<b>EASY:</b><br/>speed_multiplier: 0.7<br/>time_limit: 20s<br/>hints: 3<br/>chaos_effects: []"]
        OUT_M["<b>MEDIUM:</b><br/>speed_multiplier: 1.0<br/>time_limit: 15s<br/>hints: 2<br/>chaos_effects: [shake_mild]"]
        OUT_H["<b>HARD:</b><br/>speed_multiplier: 1.5<br/>time_limit: 10s<br/>hints: 1<br/>chaos_effects: [shake, mud, fly, reverse]"]
    end
    
    APPLY["Apply to Next Mini-Game"]
    
    %% Flow
    START --> INPUT
    INPUT --> W1
    W1 --> W2
    W2 -->|Yes| W3
    W3 --> W4
    W2 -->|No| W4
    W4 --> WMA1
    WMA1 --> WMA2
    WMA2 --> WMA3
    WMA3 --> STD1
    STD1 --> STD2
    STD2 --> STD3
    STD3 --> STD4
    STD4 --> CP1
    CP1 --> CP2
    CP2 --> PHI1
    PHI1 --> PHI2
    PHI2 --> PHI3
    PHI3 --> RULE1
    RULE1 -->|Yes| EASY
    RULE1 -->|No| RULE2
    RULE2 -->|Yes| HARD
    RULE2 -->|No| MEDIUM
    EASY --> OUT_E
    MEDIUM --> OUT_M
    HARD --> OUT_H
    OUT_E --> APPLY
    OUT_M --> APPLY
    OUT_H --> APPLY

    %% Styling
    classDef inputStyle fill:#E8F4FD,stroke:#3498DB,stroke-width:2px
    classDef processStyle fill:#E8F8E8,stroke:#27AE60,stroke-width:2px
    classDef decisionStyle fill:#FFF3E0,stroke:#E67E22,stroke-width:2px
    classDef outputStyle fill:#F3E5F5,stroke:#8E44AD,stroke-width:2px
    
    class I1,I2,I3,I4 inputStyle
    class W1,W2,W3,W4,WMA1,WMA2,WMA3,STD1,STD2,STD3,STD4,CP1,CP2,PHI1,PHI2,PHI3 processStyle
    class RULE1,RULE2 decisionStyle
    class EASY,MEDIUM,HARD,OUT_E,OUT_M,OUT_H,APPLY outputStyle
```

---

## 3. DATA FLOW DIAGRAM

### 3.1 Level 0 - Context Diagram

```mermaid
flowchart LR
    PLAYER((👤 Player))
    
    subgraph SYSTEM["<b>WATERWISE GAME SYSTEM</b>"]
        CORE[("WaterWise<br/>Educational Game")]
    end
    
    STORAGE[(💾 Local Storage<br/>ConfigFile)]
    NETWORK((🌐 LAN Network<br/>Player 2))
    
    PLAYER -->|"Touch Input<br/>Game Selection<br/>Settings"| CORE
    CORE -->|"Visual Feedback<br/>Score Display<br/>Results"| PLAYER
    
    CORE <-->|"Save/Load<br/>Progress Data"| STORAGE
    CORE <-->|"Multiplayer<br/>UDP Packets"| NETWORK

    classDef external fill:#FCE4EC,stroke:#C2185B,stroke-width:2px
    classDef system fill:#E3F2FD,stroke:#1976D2,stroke-width:3px
    classDef storage fill:#FFF8E1,stroke:#FFA000,stroke-width:2px
    
    class PLAYER,NETWORK external
    class CORE system
    class STORAGE storage
```

### 3.2 Level 1 - Detailed Data Flow

```mermaid
flowchart TB
    subgraph EXTERNAL["External Entities"]
        P1((👤 Player 1))
        P2((👤 Player 2))
    end
    
    subgraph PROCESS["Processes"]
        P1_1["1.0<br/>UI Controller<br/><i>Handle Input</i>"]
        P1_2["2.0<br/>Game Logic<br/><i>MiniGameBase</i>"]
        P1_3["3.0<br/>Adaptive Difficulty<br/><i>Φ Algorithm</i>"]
        P1_4["4.0<br/>Network Sync<br/><i>G-Counter CRDT</i>"]
        P1_5["5.0<br/>Data Manager<br/><i>Persistence</i>"]
        P1_6["6.0<br/>Coop Adaptation<br/><i>Skill Balancing</i>"]
        P1_7["7.0<br/>Localization<br/><i>EN/Filipino</i>"]
    end
    
    subgraph STORAGE["Data Stores"]
        D1[(D1: Performance Window<br/>Array&lt;Dictionary&gt;[3])]
        D2[(D2: Game State<br/>current_difficulty, lives)]
        D3[(D3: ConfigFile<br/>user://waterwise_save.cfg)]
        D4[(D4: G-Counter<br/>peer_id → score)]
        D5[(D5: Player Skills<br/>player1_skill, player2_skill)]
    end
    
    %% Player 1 flows
    P1 -->|"touch_event"| P1_1
    P1_1 -->|"game_selected"| P1_2
    P1_2 -->|"accuracy, time, mistakes"| P1_3
    P1_3 -->|"store metrics"| D1
    D1 -->|"window_data"| P1_3
    P1_3 -->|"difficulty_settings"| D2
    D2 -->|"current_difficulty"| P1_2
    P1_2 -->|"score_update"| P1_5
    P1_5 <-->|"save/load"| D3
    
    %% Multiplayer flows
    P1_2 -->|"points_scored"| P1_4
    P1_4 <-->|"UDP sync"| D4
    P2 -->|"remote_action"| P1_4
    P1_4 -->|"global_score"| P1_2
    
    %% Coop adaptation flows
    P1_4 -->|"player_performance"| P1_6
    P1_6 <-->|"skill_data"| D5
    P1_6 -->|"load_ratio"| P1_3
    
    %% Localization flows
    P1_7 -->|"translated_text"| P1_1
    D3 -->|"language_setting"| P1_7

    classDef entity fill:#FFEBEE,stroke:#D32F2F,stroke-width:2px
    classDef process fill:#E8F5E9,stroke:#388E3C,stroke-width:2px,rx:50
    classDef store fill:#FFF3E0,stroke:#F57C00,stroke-width:2px
    
    class P1,P2 entity
    class P1_1,P1_2,P1_3,P1_4,P1_5,P1_6,P1_7 process
    class D1,D2,D3,D4,D5 store
```

---

## 4. USE CASE DIAGRAM

```mermaid
flowchart TB
    subgraph ACTORS["<b>Actors</b>"]
        PLAYER1((👤 Player 1<br/><i>Primary</i>))
        PLAYER2((👤 Player 2<br/><i>Co-op</i>))
        SYSTEM((⚙️ System<br/><i>AdaptiveDifficulty</i>))
        NETWORK((🌐 Network<br/><i>ENet</i>))
    end
    
    subgraph BOUNDARY["<b>WATERWISE GAME SYSTEM</b>"]
        UC1([UC-01: Start New Game])
        UC2([UC-02: Play Mini-Game])
        UC3([UC-03: View Progress])
        
        UC5([UC-05: Adjust Settings])
        UC6([UC-06: Host/Join Multiplayer])
        UC7([UC-07: Sync Score])
        UC8([UC-08: Adapt Difficulty])
        
        UC10([UC-10: Customize Character])
    end
    
    %% Player 1 connections
    PLAYER1 --- UC1
    PLAYER1 --- UC2
    PLAYER1 --- UC3
    
    PLAYER1 --- UC5
    PLAYER1 --- UC6
    PLAYER1 --- UC10
    
    %% Player 2 connections
    PLAYER2 --- UC6
    PLAYER2 --- UC2
    
    %% System connections
    SYSTEM --- UC8
    UC2 -.->|"<<include>>"| UC8
    
    
    %% Network connections
    NETWORK --- UC7
    UC6 -.->|"<<include>>"| UC7
    
    %% Include/Extend
    UC1 -.->|"<<include>>"| UC2
    

    classDef actor fill:#E1F5FE,stroke:#0288D1,stroke-width:2px
    classDef usecase fill:#FFFFFF,stroke:#333,stroke-width:2px,rx:30
    
    class PLAYER1,PLAYER2,SYSTEM,NETWORK actor
    class UC1,UC2,UC3,UC5,UC6,UC7,UC8,UC10 usecase
```

### 4.1 Use Case Descriptions

| ID | Use Case | Primary Actor | Description | Precondition | Postcondition |
|----|----------|---------------|-------------|--------------|---------------|
| UC-01 | Start New Game | Player 1 | Initialize game session | App launched | Session active |
| UC-02 | Play Mini-Game | Player 1/2 | Complete water conservation task | Game selected | Performance recorded |
| UC-03 | View Progress | Player 1 | Check scores, achievements | Session exists | Stats displayed |
| UC-05 | Adjust Settings | Player 1 | Language, volume, accessibility | In menu | Settings saved |
| UC-06 | Host/Join Multiplayer | Player 1/2 | LAN co-op connection | Network available | Peers connected |
| UC-07 | Sync Score | Network | G-Counter CRDT merge | Multiplayer active | Scores consistent |
| UC-08 | Adapt Difficulty | System | Calculate Φ, apply settings | ≥2 games completed | Difficulty adjusted |
| UC-10 | Customize Character | Player 1 | Avatar selection | In menu | Character saved |

---

## 5. CLASS DIAGRAM

```mermaid
classDiagram
    direction TB
    
    class MiniGameBase {
        <<abstract>>
        #game_name: String
        #game_duration: float
        #game_mode: String
        #game_active: bool
        #lives: int
        #current_score: int
        #mistakes_made: int
        #correct_actions: int
        #total_actions: int
        #difficulty_settings: Dictionary
        #chaos_effects_active: Array
        +start_game() void
        +end_game(success: bool) void
        +record_action(is_correct: bool) void
        #_calculate_accuracy() float
        #_load_difficulty_settings() void
        #_apply_difficulty_settings() void
        #_activate_chaos_effect(effect: String) void
        #_on_game_start()* void
        #_on_correct_action()* void
        #_on_mistake()* void
    }
    
    class CatchTheRain {
        -bucket_position: Vector2
        -drop_spawn_rate: float
        -target_catches: int
        +_spawn_raindrop() void
        +_on_drop_caught() void
    }
    
    class BucketBrigade {
        -bucket_chain: Array
        -water_level: float
        +_pass_bucket() void
        +_fill_container() void
    }
    
    class FixLeak {
        -leak_positions: Array
        -tools_available: Array
        +_identify_leak() void
        +_apply_fix() void
    }
    
    class GameManager {
        <<singleton>>
        +current_state: GameState
        +current_game_mode: GameMode
        +water_droplets: int
        +session_lives: int
        +session_score: int
        +g_counter: Dictionary
        +team_lives: int
        +difficulty_multiplier: float
        +available_minigames: Array
        +host_game(port: int) bool
        +join_game(ip: String, port: int) bool
        +submit_score(points: int) void
        +get_global_score() int
        +complete_minigame(name, acc, time, mistakes) void
        +start_next_minigame() void
    }
    
    class AdaptiveDifficulty {
        <<singleton>>
        +window_size: int = 3
        +adaptation_frequency: int = 2
        +current_difficulty: String
        +performance_window: Array~Dictionary~
        +performance_history: Array~Dictionary~
        +total_score: int
        -DIFFICULTY_SETTINGS: Dictionary
        +add_performance(acc, time, mistakes, game) void
        +get_difficulty_settings() Dictionary
        +get_current_difficulty() String
        -_adapt_difficulty() void
        -_calculate_window_metrics() Dictionary
        -_evaluate_decision_tree(metrics) Dictionary
        +export_session_data() Dictionary
    }
    
    class Localization {
        <<singleton>>
        +current_language: String
        -translations: Dictionary
        +get_text(key: String) String
        +set_language(lang: String) void
    }
    
    class NetworkManager {
        +peer: ENetMultiplayerPeer
        +is_host: bool
        +is_multiplayer_connected: bool
        +DEFAULT_PORT: int = 7777
        +MAX_PLAYERS: int = 2
    }
    
    class CoopAdaptation {
        <<singleton>>
        +player1_skill: float
        +player2_skill: float
        +get_player_difficulty(num: int) String
        +get_difficulty_params(num: int) Dictionary
        +add_game_result(p1, p2, success) void
    }
    
    class ConfigFile {
        <<godot>>
        +load(path: String) Error
        +save(path: String) Error
        +get_value(section, key, default) Variant
        +set_value(section, key, value) void
    }
    
    %% Inheritance
    MiniGameBase <|-- CatchTheRain
    MiniGameBase <|-- BucketBrigade
    MiniGameBase <|-- FixLeak
    
    %% Associations
    GameManager --> AdaptiveDifficulty : uses
    GameManager --> CoopAdaptation : uses
    GameManager --> NetworkManager : contains
    GameManager --> ConfigFile : saves to
    AdaptiveDifficulty --> ConfigFile : persists
    MiniGameBase --> AdaptiveDifficulty : queries
    MiniGameBase --> GameManager : reports to
    MiniGameBase --> Localization : uses
```

---

## 6. ENTITY-RELATIONSHIP DIAGRAM

```mermaid
erDiagram
    PLAYER_SESSION ||--o{ GAME_PERFORMANCE : "records"
    PLAYER_SESSION ||--o{ DIFFICULTY_CHANGE : "triggers"
    PLAYER_SESSION ||--o| MULTIPLAYER_SESSION : "joins"
    GAME_PERFORMANCE }o--|| MINI_GAME : "for"
    MULTIPLAYER_SESSION ||--o{ COOP_PERFORMANCE : "tracks"
    
    PLAYER_SESSION {
        string session_id PK "WW_timestamp_random"
        int session_start_time "Unix timestamp"
        int total_score "Accumulated points"
        string current_difficulty "Easy/Medium/Hard"
        int games_played "Count"
        string game_mode "single/multiplayer"
    }
    
    GAME_PERFORMANCE {
        int id PK "Auto-increment"
        string session_id FK "Reference"
        string game_name "Mini-game identifier"
        float accuracy "0.0 to 1.0"
        int reaction_time "Milliseconds"
        int mistakes "Error count"
        string difficulty "At time of play"
        int timestamp "Unix timestamp"
    }
    
    MINI_GAME {
        string game_name PK "Unique identifier"
        string game_mode "quota/survival"
        float base_duration "Seconds"
        string category "Conservation type"
    }
    
    DIFFICULTY_CHANGE {
        int id PK "Auto-increment"
        string session_id FK "Reference"
        string old_difficulty "Previous level"
        string new_difficulty "New level"
        float proficiency_index "Φ value"
        string reason "Decision explanation"
        int timestamp "Unix timestamp"
    }
    
    MULTIPLAYER_SESSION {
        string mp_session_id PK "MP_timestamp"
        string host_peer_id "Host identifier"
        string client_peer_id "Client identifier"
        int team_lives "Shared lives"
        int global_score "Combined score"
        string connection_status "connected/disconnected"
    }
    
    COOP_PERFORMANCE {
        int id PK "Auto-increment"
        string mp_session_id FK "Reference"
        string game_name "Mini-game identifier"
        float player1_accuracy "Host accuracy"
        float player2_accuracy "Client accuracy"
        float player1_skill "Current skill level"
        float player2_skill "Current skill level"
        int g_counter_p1 "P1 score contribution"
        int g_counter_p2 "P2 score contribution"
    }
    
    PLAYER_SETTINGS {
        string player_id PK "Device ID"
        string language "en/fil"
        float volume "0.0 to 1.0"
        bool colorblind_mode "Accessibility"
        bool dark_mode "Theme"
        int water_droplets "Currency"
        int high_score "All-time best"
    }
    
    ACHIEVEMENT {
        string achievement_id PK "Unique key"
        string name "Display name"
        string description "Unlock condition"
        bool unlocked "Status"
        int unlock_timestamp "When earned"
    }
    
    PLAYER_SESSION ||--o{ ACHIEVEMENT : "earns"
    PLAYER_SETTINGS ||--o{ PLAYER_SESSION : "has"
```

---

## 7. SEQUENCE DIAGRAM - GAME SESSION

### 7.1 Single Player Session

```mermaid
sequenceDiagram
    autonumber
    
    participant P as 👤 Player
    participant UI as 🖥️ UI Module
    participant GM as ⚙️ GameManager
    participant MG as 🎮 MiniGame
    participant AD as 📊 AdaptiveDifficulty
    participant CF as 💾 ConfigFile
    
    Note over P,CF: PHASE 1: SESSION INITIALIZATION
    
    P->>UI: Launch App
    UI->>GM: _ready()
    GM->>CF: load("user://waterwise_save.cfg")
    CF-->>GM: {high_score, water_droplets, settings}
    GM->>AD: reset()
    AD->>AD: _initialize_session()
    AD-->>GM: session_id generated
    
    P->>UI: Tap "Start Game"
    UI->>GM: start_new_session(SINGLE_PLAYER)
    GM->>GM: shuffle(available_minigames)
    
    Note over P,CF: PHASE 2: MINI-GAME LOOP
    
    loop For each mini-game (until lives = 0)
        GM->>MG: load_scene(game_name)
        MG->>AD: get_difficulty_settings()
        AD-->>MG: {speed_multiplier, time_limit, chaos_effects}
        MG->>MG: _apply_difficulty_settings()
        MG->>P: Show instruction overlay
        P->>MG: Tap to start
        MG->>MG: start_game()
        
        loop Game active
            P->>MG: Touch input (tap/swipe/drag)
            MG->>MG: record_action(is_correct)
            alt Correct action
                MG->>MG: current_score += 10
                MG->>P: ✅ Success feedback
            else Mistake
                MG->>MG: mistakes_made++
                MG->>P: ❌ Error feedback + shake
            end
        end
        
        MG->>MG: end_game(success)
        MG->>GM: complete_minigame(name, accuracy, time, mistakes)
        GM->>AD: add_performance(accuracy, time, mistakes, name)
        
        AD->>AD: _calculate_window_metrics()
        Note right of AD: WMA = Σ(wᵢ × accᵢ) / Σ(wᵢ)<br/>σ = √(variance)<br/>CP = min(σ/5000, 0.2)<br/>Φ = WMA - CP
        
        alt games_since_adaptation >= 2
            AD->>AD: _evaluate_decision_tree(metrics)
            AD->>AD: _adapt_difficulty()
            AD-->>GM: difficulty_changed signal
        end
        
        MG->>P: Show tally screen
        GM->>GM: start_next_minigame()
    end
    
    Note over P,CF: PHASE 3: SESSION END
    
    GM->>CF: save_data()
    GM->>UI: Show FinalScore.tscn
    UI->>P: Display results
```

### 7.2 Multiplayer Session

```mermaid
sequenceDiagram
    autonumber
    
    participant P1 as 👤 Player 1 (Host)
    participant P2 as 👤 Player 2 (Client)
    participant UI as 🖥️ UI Module
    participant GM as ⚙️ GameManager
    participant NET as 🌐 NetworkManager
    participant GC as 📊 G-Counter
    participant COOP as 🤝 CoopAdaptation
    participant MG as 🎮 MiniGame
    
    Note over P1,MG: PHASE 1: MULTIPLAYER CONNECTION
    
    P1->>UI: Select "Host Game"
    UI->>NET: host_game(7777)
    NET->>NET: create_server()
    NET-->>UI: Server started
    UI->>P1: Show lobby (waiting...)
    
    P2->>UI: Select "Join Game"
    UI->>NET: join_game(host_ip, 7777)
    NET->>NET: create_client()
    NET-->>GM: peer_connected signal
    GM->>GC: initialize({P1: 0, P2: 0})
    GM-->>UI: Both players ready
    
    Note over P1,MG: PHASE 2: COOPERATIVE GAMEPLAY
    
    GM->>COOP: get_player_difficulty(1)
    GM->>COOP: get_player_difficulty(2)
    COOP-->>GM: {P1: Medium, P2: Easy}
    
    GM->>MG: load_scene(game_name)
    MG->>P1: Show game
    MG->>P2: Show game
    
    par Player 1 Actions
        P1->>MG: catch_item()
        MG->>GC: submit_score(P1, 10)
        GC->>NET: @rpc sync_score()
    and Player 2 Actions
        P2->>MG: catch_item()
        MG->>GC: submit_score(P2, 10)
        GC->>NET: @rpc sync_score()
    end
    
    NET->>GC: merge_counters()
    GC-->>GM: GlobalScore = Σ(peer_scores)
    
    alt Any player misses
        MG->>NET: @rpc report_damage()
        NET->>GM: team_lives -= 1
        GM->>NET: @rpc _sync_team_lives()
    end
    
    Note over P1,MG: PHASE 3: RESULTS
    
    GM->>COOP: add_game_result(P1_acc, P2_acc, success)
    COOP->>COOP: update_skills()
    GM->>UI: Show team results
    UI->>P1: Display scores
    UI->>P2: Display scores
```

---

## 8. STATE MACHINE DIAGRAM

### 8.1 Single Player State Machine

```mermaid
stateDiagram-v2
    [*] --> MAIN_MENU: App Launch
    
    MAIN_MENU --> CHARACTER_CUSTOMIZATION: Customize
    CHARACTER_CUSTOMIZATION --> MAIN_MENU: Back
    
    MAIN_MENU --> SETTINGS: Settings
    SETTINGS --> MAIN_MENU: Back
    
    MAIN_MENU --> LOADING: Start Game
    
    LOADING --> INSTRUCTIONS: Scene Ready
    INSTRUCTIONS --> PLAYING_MINIGAME: Tap to Start
    
    state PLAYING_MINIGAME {
        [*] --> GameActive
        GameActive --> GameActive: record_action()
        GameActive --> Paused: Pause Button
        Paused --> GameActive: Resume
        Paused --> MAIN_MENU: Exit
        GameActive --> GameEnded: Timer=0 OR Target Reached
    }
    
    PLAYING_MINIGAME --> MINIGAME_RESULTS: Game Complete
    
    state MINIGAME_RESULTS {
        [*] --> ShowTally
        ShowTally --> CalculateScore
        CalculateScore --> UpdateDifficulty
        UpdateDifficulty --> [*]
    }
    
    MINIGAME_RESULTS --> LOADING: Next Game (lives > 0)
    MINIGAME_RESULTS --> FINAL_RESULTS: No Lives
    
    FINAL_RESULTS --> MAIN_MENU: Return
    
    note right of PLAYING_MINIGAME
        Difficulty Settings Applied:
        - Easy: speed×0.7, 20s
        - Medium: speed×1.0, 15s
        - Hard: speed×1.5, 10s + chaos
    end note
```

### 8.2 Multiplayer State Machine

```mermaid
stateDiagram-v2
    [*] --> MAIN_MENU: App Launch
    
    MAIN_MENU --> MULTIPLAYER_MENU: Multiplayer
    
    state MULTIPLAYER_MENU {
        [*] --> SelectMode
        SelectMode --> HostGame: Host
        SelectMode --> JoinGame: Join
        HostGame --> WaitingForPlayer: Server Created
        JoinGame --> Connecting: Enter IP
        Connecting --> Connected: Success
        Connecting --> SelectMode: Failed
        WaitingForPlayer --> Connected: Peer Joined
    }
    
    MULTIPLAYER_MENU --> MAIN_MENU: Cancel
    
    state Connected {
        [*] --> MULTIPLAYER_LOBBY
        MULTIPLAYER_LOBBY --> Ready: Both Ready
    }
    
    Connected --> COOP_LOADING: Start Game
    
    COOP_LOADING --> COOP_INSTRUCTIONS: Scene Synced
    COOP_INSTRUCTIONS --> COOP_PLAYING: Both Tap Start
    
    state COOP_PLAYING {
        [*] --> BothActive
        BothActive --> BothActive: Player Actions
        BothActive --> SyncScores: G-Counter Update
        SyncScores --> BothActive: Continue
        BothActive --> TeamDamage: Any Miss
        TeamDamage --> BothActive: team_lives > 0
        TeamDamage --> TeamGameOver: team_lives = 0
        BothActive --> TeamSuccess: Target Reached
    }
    
    COOP_PLAYING --> COOP_RESULTS: Game End
    
    state COOP_RESULTS {
        [*] --> ShowTeamTally
        ShowTeamTally --> UpdateCoopSkills
        UpdateCoopSkills --> SyncResults
        SyncResults --> [*]
    }
    
    COOP_RESULTS --> COOP_LOADING: Next Game
    COOP_RESULTS --> FINAL_RESULTS: Session End
    
    FINAL_RESULTS --> MAIN_MENU: Disconnect
    
    note right of COOP_PLAYING
        G-Counter CRDT:
        - Each player has own counter
        - GlobalScore = Σ counters
        - Team lives shared
    end note
```

---

## 9. IPO CHART - INPUT PROCESS OUTPUT

### 9.1 Main IPO Table

```mermaid
flowchart LR
    subgraph INPUT["<b>INPUT</b>"]
        direction TB
        I1["🎮 Touch Events<br/>(tap, swipe, drag)"]
        I2["⚙️ Settings<br/>(language, volume)"]
        I3["📊 Performance Metrics<br/>(accuracy, time, mistakes)"]
        I4["🌐 Network Packets<br/>(peer actions, scores)"]
        I5["💾 Saved Data<br/>(ConfigFile)"]
    end
    
    subgraph PROCESS["<b>PROCESS</b>"]
        direction TB
        P1["1️⃣ UI Event Handler<br/>Parse input type"]
        P2["2️⃣ Game Logic<br/>Collision, scoring"]
        P3["3️⃣ Adaptive Algorithm<br/>Φ = WMA - CP"]
        P4["4️⃣ Network Sync<br/>G-Counter merge"]
        P5["5️⃣ Persistence<br/>Save/Load state"]
    end
    
    subgraph OUTPUT["<b>OUTPUT</b>"]
        direction TB
        O1["🖥️ Visual Feedback<br/>(animations, particles)"]
        O2["🔊 Audio Feedback<br/>(SFX, music)"]
        O3["📈 Score Updates<br/>(HUD display)"]
        O4["⚡ Difficulty Change<br/>(game parameters)"]
        O5["💾 Saved Progress<br/>(ConfigFile)"]
    end
    
    INPUT --> PROCESS
    PROCESS --> OUTPUT
```

### 9.2 Detailed IPO Per Module

| Module | Input | Process | Output |
|--------|-------|---------|--------|
| **MiniGameBase** | Touch position, delta time | Collision detection, timer update | Score increment, visual feedback |
| **AdaptiveDifficulty** | accuracy, reaction_time, mistakes | WMA calculation, σ computation, Φ derivation | difficulty_settings Dictionary |
| **GameManager** | Game completion data | State transition, score accumulation | Next scene, saved data |
| **NetworkManager** | Remote peer packets, RPC calls | ENet connection, message routing | Peer status, synced state |
| **G-Counter** | Player scores, peer counters | Increment local, merge remote | GlobalScore = Σ counters |
| **CoopAdaptation** | Player 1 & 2 accuracy | Skill calculation, load balancing | Per-player difficulty params |
| **Localization** | Language key, current_language | Dictionary lookup | Translated text (EN/Filipino) |


### 9.3 Algorithm IPO

```mermaid
flowchart TB
    subgraph INPUT_ALG["<b>ALGORITHM INPUT</b>"]
        AI1["performance_window[3]:<br/>{accuracy, reaction_time, mistakes}"]
    end
    
    subgraph PROCESS_ALG["<b>ALGORITHM PROCESS</b>"]
        direction TB
        AP1["<b>Step 1:</b> Weighted Moving Average<br/>WMA = Σ(wᵢ × xᵢ) / Σ(wᵢ)<br/>Weights: [1, 2, 3]"]
        AP2["<b>Step 2:</b> Standard Deviation<br/>σ = √(Σ(tᵢ - μ)² / N)"]
        AP3["<b>Step 3:</b> Consistency Penalty<br/>CP = min(σ / 5000, 0.2)"]
        AP4["<b>Step 4:</b> Proficiency Index<br/>Φ = WMA - CP"]
        AP5["<b>Step 5:</b> Decision Tree<br/>IF Φ < 0.5 → Easy<br/>ELIF Φ > 0.85 → Hard<br/>ELSE → Medium"]
        
        AP1 --> AP2 --> AP3 --> AP4 --> AP5
    end
    
    subgraph OUTPUT_ALG["<b>ALGORITHM OUTPUT</b>"]
        AO1["DIFFICULTY_SETTINGS {<br/>  speed_multiplier: float<br/>  time_limit: int<br/>  hints: int<br/>  chaos_effects: Array<br/>}"]
    end
    
    INPUT_ALG --> PROCESS_ALG --> OUTPUT_ALG
```

---

## 10. NETWORK ARCHITECTURE DIAGRAM

### 10.1 Multiplayer LAN Architecture

```mermaid
flowchart TB
    subgraph LAN["<b>LOCAL AREA NETWORK (LAN)</b>"]
        subgraph HOST["<b>HOST (Player 1)</b><br/>192.168.x.x:7777"]
            H_GM["GameManager<br/>(is_host = true)"]
            H_GC[("G-Counter<br/>{peer_1: 0, peer_2: 0}")]
            H_AD["AdaptiveDifficulty"]
            H_COOP["CoopAdaptation"]
        end
        
        subgraph CLIENT["<b>CLIENT (Player 2)</b><br/>192.168.x.y"]
            C_GM["GameManager<br/>(is_host = false)"]
            C_GC[("G-Counter<br/>(synced copy)")]
            C_AD["AdaptiveDifficulty"]
        end
        
        H_GM <-->|"UDP/ENet<br/>Port 7777"| C_GM
    end
    
    subgraph PROTOCOL["<b>NETWORK PROTOCOL</b>"]
        direction LR
        RPC1["submit_score(points)<br/>@rpc any_peer, reliable"]
        RPC2["_sync_game_state(counters, lives, diff)<br/>@rpc authority, reliable"]
        RPC3["_sync_team_lives(lives)<br/>@rpc authority, reliable"]
        RPC4["_receive_client_performance(acc, time, mistakes)<br/>@rpc any_peer, reliable"]
    end
    
    H_GM -->|"GlobalScore = Σ(peer_scores)"| H_GC
    H_GC -->|"Sync on change"| C_GC
    H_COOP -->|"Load ratio = skill_A / (skill_A + skill_B)"| H_AD

    classDef hostStyle fill:#E8F5E9,stroke:#2E7D32,stroke-width:3px
    classDef clientStyle fill:#E3F2FD,stroke:#1565C0,stroke-width:3px
    classDef protocolStyle fill:#FFF3E0,stroke:#EF6C00,stroke-width:2px
    
    class H_GM,H_GC,H_AD,H_COOP hostStyle
    class C_GM,C_GC,C_AD clientStyle
    class RPC1,RPC2,RPC3,RPC4 protocolStyle
```

### 10.2 G-Counter CRDT Algorithm

```mermaid
flowchart LR
    subgraph GCOUNTER["<b>G-COUNTER (Conflict-Free Replicated Data Type)</b>"]
        direction TB
        
        subgraph PROPERTIES["<b>CRDT Properties</b>"]
            PROP1["✅ Commutative: Order doesn't matter"]
            PROP2["✅ Idempotent: Duplicates safe"]
            PROP3["✅ Monotonic: Only increments"]
            PROP4["✅ Eventually Consistent"]
        end
        
        subgraph OPERATIONS["<b>Operations</b>"]
            OP1["<b>Increment (Local):</b><br/>g_counter[my_id] += points"]
            OP2["<b>Query (Global):</b><br/>GlobalScore = Σ g_counter[peer_id]"]
            OP3["<b>Merge (Sync):</b><br/>for peer in received:<br/>  g_counter[peer] = max(local, received)"]
        end
        
        subgraph EXAMPLE["<b>Example Flow</b>"]
            E1["Initial: {P1: 0, P2: 0}"]
            E2["P1 catches 3: {P1: 3, P2: 0}"]
            E3["P2 catches 5: {P1: 3, P2: 5}"]
            E4["GlobalScore = 3 + 5 = 8"]
            E5{"GlobalScore ≥ 20?"}
            E6["🏆 TEAM WINS!"]
            
            E1 --> E2 --> E3 --> E4 --> E5
            E5 -->|Yes| E6
            E5 -->|No| E2
        end
    end
```

---

## APPENDIX A: FORMULAS SUMMARY

### A.1 Weighted Proficiency Index (Φ)

$$\Phi = WMA - CP$$

Where:
- **WMA (Weighted Moving Average):**
$$WMA = \frac{\sum_{i=1}^{n} w_i \cdot accuracy_i}{\sum_{i=1}^{n} w_i}$$

- **CP (Consistency Penalty):**
$$CP = \min\left(\frac{\sigma}{5000}, 0.2\right)$$

- **Standard Deviation (σ):**
$$\sigma = \sqrt{\frac{\sum_{i=1}^{n}(t_i - \mu)^2}{n}}$$

### A.2 G-Counter Global Score

$$GlobalScore = \sum_{i=1}^{n} g\_counter[peer_i]$$

### A.3 Coop Load Balancing

$$Load_{ratio} = \frac{Skill_A}{Skill_A + Skill_B}$$

$$Tasks_A = total\_tasks \times Load_{ratio}$$

---

## APPENDIX B: COLOR LEGEND

| Module/Component | Color | Hex Code |
|------------------|-------|----------|
| Presentation Module | Blue | #2196F3 |
| Business Logic Module | Green | #4CAF50 |
| Service Module | Orange | #FF9800 |
| Data Persistence Module | Purple | #9C27B0 |
| Easy Difficulty | Green | #27AE60 |
| Medium Difficulty | Yellow | #F1C40F |
| Hard Difficulty | Red | #E74C3C |
| Network/Multiplayer | Cyan | #00BCD4 |

---

## APPENDIX C: FILE STRUCTURE REFERENCE

```
waterwise/
├── autoload/
│   ├── AdaptiveDifficulty.gd    # Φ = WMA - CP algorithm
│   ├── GameManager.gd           # State controller, G-Counter, NetworkManager
│   ├── CoopAdaptation.gd        # Multiplayer skill balancing
│   └── Localization.gd          # EN/Filipino translations
├── scenes/
│   ├── minigames/               # 19 mini-games
│   │   ├── CatchTheRain.tscn
│   │   ├── BucketBrigade.tscn
│   │   ├── FixLeak.tscn
│   │   ├── ThirstyPlant.tscn
│   │   └── ... (15 more)
│   └── ui/                      # Interface screens
│       ├── InitialScreen.tscn
│       ├── MainMenu.tscn
│       ├── Settings.tscn
│       ├── CharacterCustomization.tscn
│       ├── Instructions.tscn
│       ├── MultiplayerMenu.tscn
│       ├── MultiplayerLobby.tscn
│       ├── MiniGameResults.tscn
│       └── FinalScore.tscn
├── scripts/
│   └── MiniGameBase.gd          # Abstract base class
└── project.godot                # Godot configuration
```

---

**Document End**

*Generated for WaterWise Educational Game Thesis Documentation*  
*All diagrams use Mermaid syntax for compatibility with Markdown renderers*
