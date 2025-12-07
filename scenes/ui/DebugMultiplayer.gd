extends Control

## ═══════════════════════════════════════════════════════════════════
## DEBUG MULTIPLAYER MENU - QUICK TESTING TOOL
## ═══════════════════════════════════════════════════════════════════
## Use this scene to quickly test multiplayer functionality
## Run 2 instances of this scene to test host/client connection
## ═══════════════════════════════════════════════════════════════════

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var ip_input: LineEdit = $VBoxContainer/IPInput
@onready var port_input: LineEdit = $VBoxContainer/PortInput
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var start_game_button: Button = $VBoxContainer/StartGameButton
@onready var debug_panel: Panel = $DebugPanel
@onready var debug_text: Label = $DebugPanel/DebugText

var update_timer: float = 0.0

func _ready() -> void:
	# Set default values
	ip_input.text = "127.0.0.1"
	port_input.text = "7777"
	start_game_button.visible = false
	debug_panel.visible = false
	
	# Connect signals
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	
	# Connect GameManager signals if available
	if GameManager:
		GameManager.game_state_changed.connect(_on_game_state_changed)
	
	_update_status("Ready to connect")

func _process(delta: float) -> void:
	# Update debug info every 0.5 seconds
	update_timer += delta
	if update_timer >= 0.5:
		update_timer = 0.0
		_update_debug_info()

func _on_host_pressed() -> void:
	var port: int = int(port_input.text)
	_update_status("Creating server on port " + str(port) + "...")
	
	if GameManager.host_game(port):
		_update_status("✅ Server created! Waiting for players...")
		host_button.disabled = true
		join_button.disabled = true
		start_game_button.visible = true
		debug_panel.visible = true
		
		# Listen for peer connections
		multiplayer.peer_connected.connect(_on_peer_connected_debug)
	else:
		_update_status("❌ Failed to create server! Check console.")

func _on_join_pressed() -> void:
	var ip: String = ip_input.text
	var port: int = int(port_input.text)
	_update_status("Connecting to " + ip + ":" + str(port) + "...")
	
	if GameManager.join_game(ip, port):
		_update_status("🔄 Connecting...")
		host_button.disabled = true
		join_button.disabled = true
		debug_panel.visible = true
		
		# Wait for connection success
		await get_tree().create_timer(1.0).timeout
		if GameManager.is_multiplayer_connected:
			_update_status("✅ Connected! Waiting for host to start...")
		else:
			_update_status("❌ Connection failed! Check IP/Port.")
	else:
		_update_status("❌ Failed to connect! Check console.")

func _on_peer_connected_debug(peer_id: int) -> void:
	_update_status("✅ Player 2 connected! Ready to start.")
	print("🎮 [DEBUG] Peer connected: ", peer_id)

func _on_start_game_pressed() -> void:
	_update_status("🎮 Starting multiplayer game...")
	
	# Set game mode to multiplayer
	GameManager.set_game_mode(GameManager.GameMode.MULTIPLAYER_COOP)
	
	# Load the multiplayer minigame
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scripts/multiplayer/MiniGame_Rain.tscn")

func _on_game_state_changed(new_state: String) -> void:
	print("🎮 [DEBUG] Game state changed to: ", new_state)

func _update_status(text: String) -> void:
	status_label.text = "Status: " + text
	print("📡 [DEBUG MENU] " + text)

func _update_debug_info() -> void:
	if not debug_panel.visible:
		return
	
	if not GameManager:
		return
	
	var info: String = ""
	info += "═══════════════════════════════════════\n"
	info += "        MULTIPLAYER DEBUG INFO\n"
	info += "═══════════════════════════════════════\n\n"
	
	info += "🌐 NETWORK STATUS:\n"
	info += "  Role: " + ("HOST (Player 1)" if GameManager.is_host else "CLIENT (Player 2)") + "\n"
	info += "  Connected: " + ("✅ Yes" if GameManager.is_multiplayer_connected else "❌ No") + "\n"
	info += "  Peer ID: " + str(multiplayer.get_unique_id()) + "\n"
	info += "  Connected Peers: " + str(multiplayer.get_peers()) + "\n\n"
	
	info += "🎯 G-COUNTER STATE:\n"
	info += "  G-Counter: " + str(GameManager.g_counter) + "\n"
	info += "  Global Score: " + str(GameManager.get_global_score()) + " / " + str(GameManager.LEVEL_QUOTA) + "\n"
	info += "  My Score: " + str(GameManager.g_counter.get(multiplayer.get_unique_id(), 0)) + "\n\n"
	
	info += "📊 ROLLING WINDOW:\n"
	info += "  Window: " + str(GameManager.rolling_window) + "\n"
	info += "  Difficulty Multiplier: %.2f×\n" % GameManager.difficulty_multiplier
	info += "  Current Difficulty: " + GameManager._get_current_difficulty() + "\n\n"
	
	info += "❤️ TEAM STATUS:\n"
	info += "  Lives: " + "❤️".repeat(GameManager.team_lives) + " (" + str(GameManager.team_lives) + ")\n"
	info += "  Game Mode: " + GameManager.GameMode.keys()[GameManager.current_game_mode] + "\n\n"
	
	info += "═══════════════════════════════════════\n"
	info += "Press F3 to copy debug info to clipboard\n"
	info += "═══════════════════════════════════════\n"
	
	debug_text.text = info

func _input(event: InputEvent) -> void:
	# Press F3 to copy debug info
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_F3):
		DisplayServer.clipboard_set(debug_text.text)
		_update_status("📋 Debug info copied to clipboard!")
