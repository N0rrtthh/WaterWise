# Multiplayer Minigame System - Implementation Guide

## Available Multiplayer Minigames

### 1. **Rain Harvest** 🌧️ (`MiniGame_Rain.tscn`)
- **P1**: Catches water drops, avoids acid drops
- **P2**: Clicks leaves to destroy them
- **G-Counter**: Both players submit scores independently
- **Scene**: `res://scripts/multiplayer/MiniGame_Rain.tscn`

### 2. **Leaf Sort** 🍃 (`MiniGame_LeafSort.tscn`)
- **P1**: Catches clean (green) leaves with bucket
- **P2**: Swipes dirty (brown) leaves down
- **G-Counter**: Both players submit scores independently
- **Scene**: `res://scripts/multiplayer/MiniGame_LeafSort.tscn`

### 3. **Bucket Brigade** 🪣 (`MiniGame_BucketBrigade.tscn`)
- **P1**: Fills buckets by clicking
- **P2**: Empties full buckets by clicking
- **G-Counter**: P2 scores when successfully emptying
- **Scene**: `res://scripts/multiplayer/MiniGame_BucketBrigade.tscn`

## How to Add Minigame Selection

### Option 1: Random Selection (Simple)

Update `MultiplayerLobby.gd`:

```gdscript
func _on_start_game_pressed() -> void:
	# ... existing checks ...
	
	# Randomly select a minigame
	var minigames = [
		"res://scripts/multiplayer/MiniGame_Rain.tscn",
		"res://scripts/multiplayer/MiniGame_LeafSort.tscn",
		"res://scripts/multiplayer/MiniGame_BucketBrigade.tscn"
	]
	
	var selected_game = minigames[randi() % minigames.size()]
	print("🎮 Selected minigame: ", selected_game)
	
	# Use NetworkManager's RPC to load scene on all clients
	NetworkManager.start_multiplayer_game(selected_game)
```

### Option 2: Host Selection (Better)

Add a dropdown to `MultiplayerLobby.tscn`:

```gdscript
# In MultiplayerLobby.gd

@onready var minigame_selector: OptionButton = $MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/MinigameSelector

var minigame_options = {
	0: "res://scripts/multiplayer/MiniGame_Rain.tscn",
	1: "res://scripts/multiplayer/MiniGame_LeafSort.tscn",
	2: "res://scripts/multiplayer/MiniGame_BucketBrigade.tscn"
}

func _ready() -> void:
	# ... existing code ...
	
	# Setup minigame selector (only for host)
	if minigame_selector and NetworkManager.is_server():
		minigame_selector.add_item("Rain Harvest 🌧️", 0)
		minigame_selector.add_item("Leaf Sort 🍃", 1)
		minigame_selector.add_item("Bucket Brigade 🪣", 2)
		minigame_selector.selected = 0
	elif minigame_selector:
		minigame_selector.visible = false  # Hide for client

func _on_start_game_pressed() -> void:
	# ... existing checks ...
	
	var selected_index = minigame_selector.selected if minigame_selector else 0
	var scene_path = minigame_options[selected_index]
	
	print("🎮 Starting minigame: ", scene_path)
	NetworkManager.start_multiplayer_game(scene_path)
```

### Option 3: Round Robin (Progressive)

```gdscript
# In NetworkManager or GameManager

var current_minigame_index: int = 0
var multiplayer_minigames: Array = [
	"res://scripts/multiplayer/MiniGame_Rain.tscn",
	"res://scripts/multiplayer/MiniGame_LeafSort.tscn",
	"res://scripts/multiplayer/MiniGame_BucketBrigade.tscn"
]

func start_next_minigame() -> void:
	var scene_path = multiplayer_minigames[current_minigame_index]
	current_minigame_index = (current_minigame_index + 1) % multiplayer_minigames.size()
	
	start_multiplayer_game(scene_path)
```

## G-Counter Integration

All minigames use the same G-Counter pattern:

```gdscript
# In any minigame, when player scores:
if GameManager:
	GameManager.rpc("submit_score", points)

# GameManager automatically:
# 1. Adds to player's individual counter
# 2. Calculates global score
# 3. Checks win condition
# 4. Broadcasts victory if quota reached
```

## Testing Different Minigames

1. **Start multiplayer lobby**
2. **Host selects a game** (or random selection)
3. **Both players start** the selected game
4. **G-Counter syncs** scores between players
5. **Game ends** when quota reached or time runs out
6. **Return to lobby** to select next game

## Adding More Minigames

Template for new minigame:

```gdscript
class_name MiniGameYourName
extends Node2D

# Copy structure from MiniGame_Rain.gd
# Key elements:
# - G-Counter: GameManager.rpc("submit_score", points)
# - Team lives: GameManager.rpc("report_damage")
# - Victory: GameManager.rpc("_announce_team_won")
# - Pause system
# - Timer (60 seconds)
# - Role-based gameplay (P1 vs P2)
```

## Summary

✅ **3 Minigames Created**:
- Rain Harvest (drops + leaves)
- Leaf Sort (clean + dirty leaves)
- Bucket Brigade (fill + empty)

✅ **G-Counter Working**: All games use `submit_score()` RPC

✅ **Synchronized**: Pause, timer, lives, victory

✅ **Easy to Add More**: Copy template structure
