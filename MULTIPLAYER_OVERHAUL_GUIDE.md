# Multiplayer Overhaul - Complete Implementation Guide

## Overview

This document describes the complete multiplayer overhaul implementing true cooperative gameplay with interconnected minigames, shared state (lives, score), and survival-based progression.

## Architecture

### Core Components

#### 1. NetworkManager (Enhanced)
**Location:** `autoload/NetworkManager.gd`

**New Features:**
- **G-Counter CRDT** - Conflict-free replicated score counter
- **Shared Lives System** - Team life pool with host authority
- **Synchronized Pause/Resume** - Either player can pause both games
- **Synchronized Countdown** - 3-2-1-GO countdown before rounds
- **Resource Transfer** - Send resources between players
- **Task Marking** - Mark tasks for partner to complete

**Key Functions:**
```gdscript
# G-Counter operations
increment_local(amount: int)  # Add to local score
get_total_score() -> int      # Get combined team score

# Lives management
lose_life()                    # Deduct shared life (host authority)
reset_team_lives()            # Reset to starting lives

# Game flow
start_countdown()             # Start 3-2-1-GO countdown
complete_round()              # End round and show results

# Interconnection
send_resource(type, amount, quality)  # Send to partner
mark_task(task_id, position)          # Mark for partner
```

#### 2. LevelSets
**Location:** `scripts/multiplayer/LevelSets.gd`

Defines interconnected minigame pairs:

```gdscript
{
    "id": "water_collection_chain",
    "name": "Water Collection Chain",
    "player1_game": "res://scenes/minigames/CatchTheRain.tscn",
    "player2_game": "res://scenes/minigames/FilterBuilder.tscn",
    "player1_role": "Rain Catcher",
    "player2_role": "Water Filter",
    "connection_type": "resource_transfer"
}
```

**4 Defined Level Sets:**
1. **Water Collection Chain** - P1 catches rain → P2 filters water
2. **Pipe Repair Team** - P1 spots leaks → P2 plugs them
3. **Garden Conservation** - P1 collects greywater → P2 waters plants
4. **Household Savings** - P1 turns off taps | P2 covers drums (combined)

**Key Functions:**
```gdscript
get_random_level_set() -> Dictionary  # Get next random set (with role swap)
get_difficulty_params(set, difficulty) -> Dictionary
```

#### 3. MultiplayerMiniGameBase
**Location:** `scripts/multiplayer/MultiplayerMiniGameBase.gd`

Base class for all multiplayer minigames. Provides:
- Built-in HUD with shared lives/score display
- Automatic pause/resume handling
- Countdown overlay
- "Waiting for partner" overlay
- G-Counter score integration
- Resource transfer helpers

**Usage:**
```gdscript
extends MultiplayerMiniGameBase

func _on_multiplayer_ready():
    # Setup game
    
func _on_game_start():
    # Start gameplay after countdown

func add_score(points: int):
    # Automatically syncs via G-Counter

func send_resource_to_partner(type, amount, quality):
    # Send to connected player

func _on_resource_received(from_player, type, amount, quality):
    # Override to handle incoming resources
```

#### 4. MultiplayerCoordinator
**Location:** `scripts/multiplayer/MultiplayerCoordinator.gd`

Manages round flow and transitions:
- Tracks when both players complete
- Shows round transition screens
- Loads next random level set
- Shows game over when lives depleted

**Usage:**
Add as child node to multiplayer games:
```gdscript
# In game scene
var coordinator = preload("res://scripts/multiplayer/MultiplayerCoordinator.gd").new()
add_child(coordinator)

# Report completion
coordinator.report_completion(success)
```

#### 5. UI Components

**RoundTransition.gd**
Shows between-round results:
- Individual player scores
- Team total
- Lives remaining
- Next roles preview
- 5-second countdown

**MultiplayerGameOver.gd**
Shows final team results:
- Final combined score
- Rounds survived
- Individual contributions (percentage)
- Return to lobby button

## Game Flow

```
LOBBY (MultiplayerLobby)
  ├─ Both players connect
  ├─ Both click "Ready"
  └─ Host clicks "Start"
      ↓
INITIALIZATION
  ├─ Reset G-Counter
  ├─ Reset team lives (3)
  ├─ Select random level set
  └─ Assign roles
      ↓
LOAD GAMES
  ├─ P1 loads their game scene
  └─ P2 loads their game scene
      ↓
COUNTDOWN (3-2-1-GO!)
  └─ Synchronized across both players
      ↓
GAMEPLAY
  ├─ Both play simultaneously
  ├─ Resources transfer between players
  ├─ Scores add via G-Counter
  └─ Either can pause both
      ↓
ROUND END
  ├─ Both complete → Round succeeds
  ├─ Either fails → Lose 1 life
  └─ Coordinator detects both done
      ↓
TRANSITION
  ├─ Show combined scores
  ├─ Show lives remaining
  ├─ Preview next roles
  └─ 5-second countdown
      ↓
NEXT ROUND
  ├─ Reset G-Counter
  ├─ Select new random level set
  └─ Load new games (roles may swap)
      ↓
[Loop COUNTDOWN → GAMEPLAY → ROUND END → TRANSITION]
      ↓
GAME OVER (when lives = 0)
  ├─ Show final team score
  ├─ Show rounds survived
  ├─ Show contributions
  └─ Return to lobby button
```

## Creating Interconnected Minigames

### Example: Water Collection Chain

**Player 1: MP_CatchTheRain.gd**
```gdscript
extends MultiplayerMiniGameBase

func _on_bucket_collision(area: Area2D):
    # Raindrop caught
    add_score(10)
    
    # Send water to partner
    send_resource_to_partner("clean_water", 1, 1.0)
```

**Player 2: MP_FilterWater.gd**
```gdscript
extends MultiplayerMiniGameBase

func _on_resource_received(from_player, type, amount, quality):
    if type == "clean_water":
        # Spawn dirt particles to filter
        _spawn_dirt_particles(amount * 3)
```

### Connection Types

1. **resource_transfer**
   - P1 produces → P2 consumes
   - Example: Rain → Filter, Greywater → Plants

2. **task_marking**
   - P1 identifies → P2 completes
   - Example: Spot leak → Plug leak

3. **combined_efficiency**
   - Both complete separate tasks
   - Score = combined efficiency
   - Example: Turn off taps | Cover drums

## Integration Steps

### 1. Update Existing Minigame to Use New System

```gdscript
# Old approach (MiniGameBase)
extends Node2D

# New approach (MultiplayerMiniGameBase)
extends MultiplayerMiniGameBase

func _ready():
    # Remove manual initialization
    # Base class handles it
    pass

func _on_multiplayer_ready():
    # Setup specific to this game
    _create_game_objects()

func _on_game_start():
    # Start spawning, timers, etc.
    spawn_timer.start()

# Replace manual score sync
func _on_object_caught():
    # Old: NetworkManager.increment_local(10)
    # New: 
    add_score(10)  # Automatically syncs
```

### 2. Add to Level Set

Update `LevelSets.gd`:
```gdscript
{
    "id": "my_new_set",
    "name": "My New Set",
    "player1_game": "res://scenes/minigames/MyP1Game.tscn",
    "player2_game": "res://scenes/minigames/MyP2Game.tscn",
    "player1_role": "Collector",
    "player2_role": "User",
    "connection_type": "resource_transfer",
    "difficulty_easy": { ... },
    "difficulty_medium": { ... },
    "difficulty_hard": { ... }
}
```

### 3. Scene Setup

**P1 Game Scene (MyP1Game.tscn):**
```
Node2D (MyP1Game.gd extends MultiplayerMiniGameBase)
├─ Camera2D
├─ GameLayer (Node2D)
│  ├─ Player objects
│  └─ Spawned objects
└─ MultiplayerCoordinator
```

**P2 Game Scene (MyP2Game.tscn):**
```
Node2D (MyP2Game.gd extends MultiplayerMiniGameBase)
├─ Camera2D
├─ GameLayer (Node2D)
│  ├─ Player objects
│  └─ Spawned objects
└─ MultiplayerCoordinator
```

## G-Counter Algorithm

The G-Counter (Grow-only Counter) is a CRDT (Conflict-Free Replicated Data Type) that ensures eventual consistency across peers.

**Properties:**
- Each peer maintains their own counter
- Counters only grow (monotonic)
- Global score = Σ(all peer counters)
- Merge operation: MAX(local, remote)

**Why This Works:**
- No race conditions - each peer owns their counter
- Network delays don't cause conflicts
- Always converges to correct total
- Works even with packet loss (eventually consistent)

**Formula:**
```
GlobalScore = Σ(PlayerInput_i) for i = 1 to n

Merge(Counter_i, remote_value):
    Counter_i = MAX(Counter_i, remote_value)
```

**Example:**
```
Initial: P1 = {1: 0}, P2 = {2: 0}

P1 catches drop: P1 = {1: 10}, broadcasts to P2
P2 receives: P2 = {1: 10, 2: 0}

P2 filters water: P2 = {1: 10, 2: 5}, broadcasts to P1
P1 receives: P1 = {1: 10, 2: 5}

Both agree: Total = 10 + 5 = 15 ✓
```

## Shared Lives System

**Authority:** Host only can modify lives
**Flow:**
1. Client detects failure
2. Client calls `NetworkManager.lose_life()`
3. Client sends RPC to host
4. Host decrements lives
5. Host broadcasts new value to all
6. All clients update UI

**Why Host Authority:**
- Prevents cheating (client can't fake lives)
- Single source of truth
- Consistent across all peers

## Testing Checklist

### Basic Connectivity
- [ ] Two players can connect via LAN
- [ ] Ready system works for both players
- [ ] Disconnection shows error gracefully

### G-Counter
- [ ] P1 score increases locally
- [ ] P2 receives P1's score update
- [ ] Combined score = P1 + P2
- [ ] Score persists across network delays

### Shared Lives
- [ ] Lives display on both screens
- [ ] P1 failure decreases team lives
- [ ] P2 failure decreases team lives
- [ ] Lives = 0 triggers game over on both

### Pause System
- [ ] P1 pause affects both screens
- [ ] P2 pause affects both screens
- [ ] Either can resume
- [ ] Pause menu visible on both

### Countdown
- [ ] 3-2-1-GO synced on both screens
- [ ] Games start simultaneously after GO
- [ ] Countdown visible clearly

### Interconnection
- [ ] P1 catches rain → P2 receives water
- [ ] Resource quantity is correct
- [ ] Resources appear at right time

### Round Flow
- [ ] Both complete → Transition screen
- [ ] Transition shows correct scores
- [ ] Next round loads correctly
- [ ] Roles can swap between rounds

### Game Over
- [ ] Lives = 0 → Game over on both
- [ ] Final score is correct sum
- [ ] Rounds survived is accurate
- [ ] Return to lobby works

## Known Limitations

1. **Max 2 Players** - Architecture designed for pairs
2. **LAN Only** - No internet/relay server support
3. **Host Required** - Host disconnection ends game
4. **Scene Files** - Example games need .tscn files created
5. **Assets** - Visual assets not included (using procedural shapes)

## Future Enhancements

1. **More Level Sets** - Add remaining minigame pairs
2. **Dynamic Difficulty** - Integrate CoopAdaptation per-player difficulty
3. **Reconnection** - Grace period reconnection support
4. **Spectator Mode** - Allow third player to watch
5. **Replay System** - Record and replay sessions
6. **Leaderboards** - Track high scores and longest survival

## Troubleshooting

### "G-Counter not syncing"
- Check NetworkManager signals are connected
- Verify RPC annotations are correct
- Ensure multiplayer peer is set

### "Lives not updating"
- Confirm host has authority
- Check `is_host` flag
- Verify RPC is reaching host

### "Countdown not showing"
- Check `requires_countdown` is true
- Verify overlay is visible
- Check Z-index of HUD layer

### "Resources not transferring"
- Verify `connection_type` matches
- Check `_on_resource_received` is overridden
- Confirm RPC is being called

## API Reference

### NetworkManager

```gdscript
# G-Counter
increment_local(amount: int) -> void
get_total_score() -> int
get_player_score(peer_id: int) -> int
reset_g_counter() -> void

# Lives
lose_life() -> void
reset_team_lives() -> void

# Pause
request_pause() -> void
request_resume() -> void

# Countdown
start_countdown() -> void  # Host only

# Round
complete_round() -> void   # Host only

# Interconnection
send_resource(type: String, amount: int, quality: float) -> void
mark_task(task_id: int, position: Vector2) -> void

# Signals
signal team_score_updated(total_score: int)
signal team_lives_updated(remaining_lives: int)
signal round_starting(countdown: int)
signal round_completed(p1_score, p2_score, team_total)
signal resource_sent(from_player, type, amount, quality)
signal task_marked(from_player, task_id, position)
```

### MultiplayerMiniGameBase

```gdscript
# Override in child
func _on_multiplayer_ready() -> void
func _on_game_start() -> void
func _on_resource_received(from, type, amount, quality) -> void
func _on_task_marked(from, task_id, position) -> void
func _on_game_over() -> void

# Call from child
add_score(points: int) -> void
end_game(success: bool) -> void
show_waiting_overlay() -> void
send_resource_to_partner(type, amount, quality) -> void
mark_task_for_partner(task_id, position) -> void

# Properties
var my_player_num: int       # 1 or 2
var my_role: String          # "Rain Catcher", etc.
var game_active: bool
var local_score: int
```

### LevelSets

```gdscript
get_random_level_set() -> Dictionary
get_level_set_by_id(id: String) -> Dictionary
get_difficulty_params(set: Dictionary, difficulty: String) -> Dictionary
reset() -> void
```

### MultiplayerCoordinator

```gdscript
start_round() -> void
report_completion(success: bool) -> void

# Signals
signal both_players_completed()
```

## Credits

Implemented by: GitHub Copilot Agent
Architecture: G-Counter CRDT + Host Authority + Resource Transfer
Algorithms: WMA-CP (AdaptiveDifficulty) + CoopAdaptation
