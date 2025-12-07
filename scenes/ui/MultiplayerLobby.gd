extends Control

## ═══════════════════════════════════════════════════════════════════
## MULTIPLAYER LOBBY - HOST/JOIN INTERFACE
## ═══════════════════════════════════════════════════════════════════
## Filipino-friendly bilingual interface for cooperative water conservation
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NODE REFERENCES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@onready var lobby_container = $MarginContainer/VBoxContainer
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var mode_selection_panel = $MarginContainer/VBoxContainer/ModeSelectionPanel
@onready var host_button = $MarginContainer/VBoxContainer/ModeSelectionPanel/VBoxContainer/HostButton
@onready var join_button = $MarginContainer/VBoxContainer/ModeSelectionPanel/VBoxContainer/JoinButton
@onready var back_button = $MarginContainer/VBoxContainer/ModeSelectionPanel/VBoxContainer/BackButton

@onready var join_panel = $MarginContainer/VBoxContainer/JoinPanel
@onready var ip_input = $MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/IPInput
@onready var connect_button = $MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/HBoxContainer/ConnectButton
@onready var cancel_button = $MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/HBoxContainer/CancelButton

@onready var waiting_panel = $MarginContainer/VBoxContainer/WaitingPanel
@onready var status_label = $MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/StatusLabel
@onready var player_list_container = $MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/PlayerListContainer
@onready var player1_label = $MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/PlayerListContainer/Player1Label
@onready var player2_label = $MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/PlayerListContainer/Player2Label
@onready var ready_checkbox = $MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/ReadyCheckbox
@onready var start_game_button = $MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/StartGameButton
@onready var disconnect_button = $MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/DisconnectButton

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var current_language: String = "en"  # "en" or "tl" (Tagalog)
var is_ready: bool = false

# Translations
var translations = {
	"en": {
		"title": "Multiplayer Co-op Mode\nWater Conservation Team",
		"host": "Create Game (Host)",
		"join": "Join Game",
		"back": "Back to Menu",
		"enter_ip": "Enter IP Address (ex: 192.168.1.5):",
		"connect": "Connect",
		"cancel": "Cancel",
		"waiting_for_player": "Waiting for another player...",
		"player_connected": "Player connected! Get ready!",
		"player1": "Player 1 (Collector)",
		"player2": "Player 2 (User)",
		"not_connected": "Not Connected",
		"ready": "Ready",
		"not_ready": "Not Ready",
		"ready_checkbox": "I'm Ready!",
		"start_game": "Start Game",
		"disconnect": "Disconnect",
		"connection_failed": "Connection failed. Please check IP address.",
		"you": "YOU",
		"your_role": "Your Role: %s"
	},
	"tl": {
		"title": "Multiplayer Co-op Mode\nPangkat sa Pagtitipid ng Tubig",
		"host": "Gumawa ng Laro (Host)",
		"join": "Sumali sa Laro",
		"back": "Bumalik sa Menu",
		"enter_ip": "Ilagay ang IP Address (hal: 192.168.1.5):",
		"connect": "Kumonekta",
		"cancel": "Kanselahin",
		"waiting_for_player": "Naghihintay ng kasama...",
		"player_connected": "May sumali na! Maghanda!",
		"player1": "Player 1 (Mang-ipon)",
		"player2": "Player 2 (Gumagamit)",
		"not_connected": "Hindi Konektado",
		"ready": "Handa",
		"not_ready": "Hindi Handa",
		"ready_checkbox": "Handa na ako!",
		"start_game": "Simulan ang Laro",
		"disconnect": "Putulin ang Koneksyon",
		"connection_failed": "Hindi kumonekta. Tingnan ang IP address.",
		"you": "IKAW",
		"your_role": "Iyong Papel: %s"
	}
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	# Load language preference
	if Localization:
		current_language = "tl" if Localization.get_language_code() == "tl" else "en"
	
	_update_translations()
	
	# Check if already connected (returning from game)
	if NetworkManager and NetworkManager.connection_active:
		_show_waiting_panel()
		status_label.text = _t("player_connected")
		if NetworkManager.is_host:
			start_game_button.visible = true
			# Reset ready status when returning to lobby
			NetworkManager.set_ready(false)
			ready_checkbox.button_pressed = false
		else:
			start_game_button.visible = false
			NetworkManager.set_ready(false)
			ready_checkbox.button_pressed = false
	else:
		_show_mode_selection()
	
	# Connect NetworkManager signals
	if NetworkManager:
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		NetworkManager.player_ready_changed.connect(_on_player_ready_changed)
		NetworkManager.both_players_ready.connect(_on_both_players_ready)
		NetworkManager.game_started.connect(_on_game_started)
	
	# Connect button signals
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	ready_checkbox.toggled.connect(_on_ready_toggled)
	start_game_button.pressed.connect(_on_start_game_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	
	# Get local IP for host
	var local_ip = _get_local_ip()
	print("💻 Your local IP: " + local_ip)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UI PANEL MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _show_mode_selection() -> void:
	mode_selection_panel.visible = true
	join_panel.visible = false
	waiting_panel.visible = false

func _show_join_panel() -> void:
	mode_selection_panel.visible = false
	join_panel.visible = true
	waiting_panel.visible = false
	ip_input.text = "192.168.1."
	ip_input.grab_focus()

func _show_waiting_panel() -> void:
	mode_selection_panel.visible = false
	join_panel.visible = false
	waiting_panel.visible = true
	_update_player_list()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUTTON HANDLERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_host_pressed() -> void:
	print("🏠 Creating server...")
	
	if NetworkManager and NetworkManager.create_server():
		_show_waiting_panel()
		var local_ip = _get_local_ip()
		status_label.text = _t("waiting_for_player") + "\n" + "IP: " + local_ip
		start_game_button.visible = true  # Only host can start
	else:
		_show_error(_t("connection_failed"))

func _on_join_pressed() -> void:
	_show_join_panel()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

func _on_connect_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	
	if not _validate_ip(ip):
		_show_error(_t("connection_failed") + "\n(Invalid IP format)")
		return
	
	print("🔌 Connecting to " + ip + "...")
	
	if NetworkManager and NetworkManager.join_server(ip):
		_show_waiting_panel()
		status_label.text = "Connecting..."
		start_game_button.visible = false  # Only host can start
	else:
		_show_error(_t("connection_failed"))

func _on_cancel_pressed() -> void:
	_show_mode_selection()

func _on_ready_toggled(toggled: bool) -> void:
	is_ready = toggled
	
	if NetworkManager:
		NetworkManager.set_ready(is_ready)
	
	_update_player_list()

func _on_start_game_pressed() -> void:
	print("🔘 Start button pressed!")
	
	if not NetworkManager:
		print("❌ NetworkManager is null")
		return
	
	if not NetworkManager.is_server():
		print("❌ Not the server, peer_id: ", multiplayer.get_unique_id())
		return
	
	print("✅ Is server, checking ready status...")
	print("   Players ready: ", NetworkManager.are_all_players_ready())
	
	if not NetworkManager.are_all_players_ready():
		_show_error("Both players must be ready!")
		return
	
	# Set GameManager to multiplayer mode and reset state
	if GameManager:
		GameManager.set_game_mode(GameManager.GameMode.MULTIPLAYER_COOP)
		GameManager.reset_multiplayer_game()  # Reset lives, score, difficulty
		
		# Start the continuous minigame loop by loading the first random game
		GameManager.rpc("_load_next_multiplayer_minigame")

func _on_disconnect_pressed() -> void:
	if NetworkManager:
		NetworkManager.disconnect_multiplayer()
	
	_show_mode_selection()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NETWORK CALLBACKS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_player_connected(_peer_id: int, player_num: int) -> void:
	print("✅ Player connected: " + str(player_num))
	status_label.text = _t("player_connected")
	_update_player_list()

func _on_player_disconnected(_peer_id: int) -> void:
	print("❌ Player disconnected")
	status_label.text = _t("waiting_for_player")
	_update_player_list()

func _on_connection_succeeded() -> void:
	print("✅ Connection successful!")
	status_label.text = _t("player_connected")
	_update_player_list()

func _on_connection_failed() -> void:
	print("❌ Connection failed")
	_show_error(_t("connection_failed"))
	_show_mode_selection()

func _on_player_ready_changed(_peer_id: int, ready_status: bool) -> void:
	"""Update UI when any player's ready status changes"""
	print("🔄 Player ready changed: ", _peer_id, " = ", ready_status)
	_update_player_list()

func _on_both_players_ready() -> void:
	print("✅ Both players ready!")
	
	if NetworkManager and NetworkManager.is_server():
		start_game_button.disabled = false

func _on_game_started(scenario_id: String, _roles: Dictionary) -> void:
	print("🎮 Navigating to game: " + scenario_id)
	# Navigate to the co-op game scene
	get_tree().change_scene_to_file("res://scenes/minigames/coop/" + scenario_id + ".tscn")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PLAYER LIST UPDATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _update_player_list() -> void:
	if not NetworkManager:
		return
	
	var local_player_num = NetworkManager.get_local_player_num()
	var player_count = NetworkManager.get_player_count()
	var player_data = NetworkManager.players
	
	# Player 1
	if player_count >= 1:
		var is_you = (local_player_num == 1)
		var p1_peer_id = 1  # Host is always peer ID 1
		var p1_ready = player_data.get(p1_peer_id, {}).get("ready", false)
		
		player1_label.text = _t("player1")
		if is_you:
			player1_label.text += " [" + _t("you") + "]"
		var status1 = _t("ready") if p1_ready else _t("not_ready")
		player1_label.text += "\n" + status1
		player1_label.modulate = Color.GREEN if p1_ready else Color.WHITE
	else:
		player1_label.text = _t("player1") + "\n" + _t("not_connected")
		player1_label.modulate = Color.GRAY
	
	# Player 2
	if player_count >= 2:
		var is_you = (local_player_num == 2)
		# Find peer ID for player 2 (not peer 1)
		var p2_peer_id = 0
		for peer_id in player_data:
			if peer_id != 1:
				p2_peer_id = peer_id
				break
		
		var p2_ready = player_data.get(p2_peer_id, {}).get("ready", false)
		
		player2_label.text = _t("player2")
		if is_you:
			player2_label.text += " [" + _t("you") + "]"
		var status2 = _t("ready") if p2_ready else _t("not_ready")
		player2_label.text += "\n" + status2
		player2_label.modulate = Color.GREEN if p2_ready else Color.WHITE
	else:
		player2_label.text = _t("player2") + "\n" + _t("not_connected")
		player2_label.modulate = Color.GRAY

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _get_local_ip() -> String:
	"""Get local IP address for LAN"""
	var addresses = IP.get_local_addresses()
	
	# Find IPv4 address that's not localhost
	for ip in addresses:
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	
	return "Unknown"

func _validate_ip(ip: String) -> bool:
	"""Validate IP address format"""
	var parts = ip.split(".")
	if parts.size() != 4:
		return false
	
	for part in parts:
		if not part.is_valid_int():
			return false
		var num = part.to_int()
		if num < 0 or num > 255:
			return false
	
	return true

func _show_error(message: String) -> void:
	"""Show error message (can be enhanced with popup)"""
	status_label.text = message
	status_label.modulate = Color.RED
	
	# Reset color after 3 seconds
	await get_tree().create_timer(3.0).timeout
	status_label.modulate = Color.WHITE

func _t(key: String) -> String:
	"""Get translated text"""
	return translations[current_language].get(key, key)

func _update_translations() -> void:
	"""Update all UI text based on current language"""
	title_label.text = _t("title")
	host_button.text = _t("host")
	join_button.text = _t("join")
	back_button.text = _t("back")
	connect_button.text = _t("connect")
	cancel_button.text = _t("cancel")
	ready_checkbox.text = _t("ready_checkbox")
	start_game_button.text = _t("start_game")
	disconnect_button.text = _t("disconnect")
