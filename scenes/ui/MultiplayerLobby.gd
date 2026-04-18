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
@onready var host_button = (
	$MarginContainer/VBoxContainer/ModeSelectionPanel/VBoxContainer/HostButton
)
@onready var join_button = (
	$MarginContainer/VBoxContainer/ModeSelectionPanel/VBoxContainer/JoinButton
)
@onready var back_button = (
	$MarginContainer/VBoxContainer/ModeSelectionPanel/VBoxContainer/BackButton
)

@onready var join_panel = $MarginContainer/VBoxContainer/JoinPanel
@onready var ip_input = $MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/IPInput
@onready var connect_button = (
	$MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/HBoxContainer/ConnectButton
)
@onready var cancel_button = (
	$MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/HBoxContainer/CancelButton
)

@onready var waiting_panel = $MarginContainer/VBoxContainer/WaitingPanel
@onready var status_label = $MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/StatusLabel
@onready var player_list_container = (
	$MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/PlayerListContainer
)
@onready var player1_label = (
	$MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/PlayerListContainer/Player1Label
)
@onready var player2_label = (
	$MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/PlayerListContainer/Player2Label
)
@onready var ready_checkbox = (
	$MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/ReadyCheckbox
)
@onready var start_game_button = (
	$MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/StartGameButton
)
@onready var disconnect_button = (
	$MarginContainer/VBoxContainer/WaitingPanel/VBoxContainer/DisconnectButton
)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var current_language: String = "en"  # "en" or "tl" (Tagalog)
var is_ready: bool = false
var ready_status_by_peer: Dictionary = {}

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
		"invalid_ip_format": "(Invalid IP format)",
		"connecting": "Connecting...",
		"ip_label": "IP",
		"need_two_players": "Need 2 players connected!",
		"both_players_ready": "Both players must be ready!",
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
		"invalid_ip_format": "(Maling format ng IP)",
		"connecting": "Kumokonekta...",
		"ip_label": "IP",
		"need_two_players": "Kailangan ng 2 maglalaro!",
		"both_players_ready": "Dapat handa ang parehong player!",
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
	_connect_button_signals()
	_connect_multiplayer_signals()

	# Check if already connected (returning from game)
	if _is_connected():
		_show_waiting_panel()
		status_label.text = _t("player_connected")
		_sync_local_ready(false)
	else:
		_show_mode_selection()

	_update_player_list()
	_update_start_button_state()
	
	# Get local IP for host
	var local_ip = _get_local_ip()
	print("💻 Your local IP: " + local_ip)

func _connect_button_signals() -> void:
	if not host_button.pressed.is_connected(_on_host_pressed):
		host_button.pressed.connect(_on_host_pressed)
	if not join_button.pressed.is_connected(_on_join_pressed):
		join_button.pressed.connect(_on_join_pressed)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if not connect_button.pressed.is_connected(_on_connect_pressed):
		connect_button.pressed.connect(_on_connect_pressed)
	if not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)
	if not ready_checkbox.toggled.is_connected(_on_ready_toggled):
		ready_checkbox.toggled.connect(_on_ready_toggled)
	if not start_game_button.pressed.is_connected(_on_start_game_pressed):
		start_game_button.pressed.connect(_on_start_game_pressed)
	if not disconnect_button.pressed.is_connected(_on_disconnect_pressed):
		disconnect_button.pressed.connect(_on_disconnect_pressed)

func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_player_connected):
		multiplayer.peer_connected.connect(_on_player_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_player_disconnected):
		multiplayer.peer_disconnected.connect(_on_player_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _is_connected() -> bool:
	return (
		GameManager
		and GameManager.is_multiplayer_connected
		and multiplayer.multiplayer_peer != null
	)

func _is_host() -> bool:
	return GameManager and GameManager.is_host

func _get_connected_peer_ids() -> Array[int]:
	if GameManager and GameManager.has_method("get_connected_multiplayer_peer_ids"):
		return GameManager.get_connected_multiplayer_peer_ids()
	return []

func _are_all_players_ready() -> bool:
	var peer_ids := _get_connected_peer_ids()
	if peer_ids.size() < 2:
		return false
	for peer_id in peer_ids:
		if not bool(ready_status_by_peer.get(peer_id, false)):
			return false
	return true

func _update_start_button_state() -> void:
	start_game_button.visible = _is_host()
	start_game_button.disabled = not _are_all_players_ready()

func _sync_local_ready(ready_value: bool) -> void:
	is_ready = ready_value
	ready_checkbox.button_pressed = ready_value
	if multiplayer.multiplayer_peer != null:
		var my_id := multiplayer.get_unique_id()
		ready_status_by_peer[my_id] = ready_value
		rpc("_sync_ready_state", my_id, ready_value)
	_update_player_list()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UI PANEL MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _show_mode_selection() -> void:
	mode_selection_panel.visible = true
	join_panel.visible = false
	waiting_panel.visible = false
	_update_start_button_state()

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
	_update_start_button_state()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUTTON HANDLERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_host_pressed() -> void:
	print("🏠 Creating server...")
	
	if GameManager and GameManager.host_game():
		ready_status_by_peer.clear()
		_show_waiting_panel()
		var local_ip = _get_local_ip()
		status_label.text = _t("waiting_for_player") + "\n" + _t("ip_label") + ": " + local_ip
		_sync_local_ready(false)
	else:
		_show_error(_t("connection_failed"))

func _on_join_pressed() -> void:
	_show_join_panel()

func _on_back_pressed() -> void:
	if _is_connected() and GameManager:
		GameManager.disconnect_multiplayer()
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

func _on_connect_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	
	if not _validate_ip(ip):
		_show_error(_t("connection_failed") + "\n" + _t("invalid_ip_format"))
		return
	
	print("🔌 Connecting to " + ip + "...")
	
	if GameManager and GameManager.join_game(ip):
		_show_waiting_panel()
		status_label.text = _t("connecting")
		start_game_button.visible = false  # Only host can start
	else:
		_show_error(_t("connection_failed"))

func _on_cancel_pressed() -> void:
	_show_mode_selection()

func _on_ready_toggled(toggled: bool) -> void:
	_sync_local_ready(toggled)

func _on_start_game_pressed() -> void:
	print("🔘 Start button pressed!")
	
	if not GameManager:
		print("❌ GameManager is null")
		return
	
	if not _is_host():
		print("❌ Not the server, peer_id: ", multiplayer.get_unique_id())
		return
	
	print("✅ Is server, checking ready status...")
	print("   Players ready: ", _are_all_players_ready())
	
	if _get_connected_peer_ids().size() < 2:
		_show_error(_t("need_two_players"))
		return

	if not _are_all_players_ready():
		_show_error(_t("both_players_ready"))
		return

	print("🎮 Starting GameManager multiplayer session flow...")
	GameManager.rpc("_begin_multiplayer_session_rpc")
	await get_tree().process_frame
	GameManager.rpc("_load_next_multiplayer_minigame")

func _on_disconnect_pressed() -> void:
	if GameManager:
		GameManager.disconnect_multiplayer()
	if NetworkManager and NetworkManager.connection_active:
		NetworkManager.disconnect_multiplayer()
	ready_status_by_peer.clear()
	is_ready = false
	ready_checkbox.button_pressed = false
	
	_show_mode_selection()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NETWORK CALLBACKS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_player_connected(peer_id: int) -> void:
	print("✅ Player connected: %d" % peer_id)
	status_label.text = _t("player_connected")
	if _is_host():
		ready_status_by_peer[peer_id] = false
		rpc_id(peer_id, "_sync_ready_map", ready_status_by_peer)
	_update_player_list()
	_update_start_button_state()

func _on_player_disconnected(peer_id: int) -> void:
	print("❌ Player disconnected: %d" % peer_id)
	ready_status_by_peer.erase(peer_id)
	status_label.text = _t("waiting_for_player")
	_update_player_list()
	_update_start_button_state()

func _on_connected_to_server() -> void:
	print("✅ Connection successful!")
	_show_waiting_panel()
	status_label.text = _t("player_connected")
	_sync_local_ready(false)
	_update_player_list()
	_update_start_button_state()

func _on_connection_failed() -> void:
	print("❌ Connection failed")
	if GameManager:
		GameManager.disconnect_multiplayer()
	_show_error(_t("connection_failed"))
	_show_mode_selection()

func _on_server_disconnected() -> void:
	print("⚠️ Server disconnected")
	if GameManager:
		GameManager.disconnect_multiplayer()
	_show_error(_t("connection_failed"))
	ready_status_by_peer.clear()
	_show_mode_selection()

@rpc("any_peer", "call_local", "reliable")
func _sync_ready_state(peer_id: int, ready_value: bool) -> void:
	ready_status_by_peer[peer_id] = ready_value
	_update_player_list()
	_update_start_button_state()

@rpc("authority", "reliable")
func _sync_ready_map(ready_map: Dictionary) -> void:
	ready_status_by_peer = ready_map.duplicate(true)
	_update_player_list()
	_update_start_button_state()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PLAYER LIST UPDATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _update_player_list() -> void:
	var peer_ids := _get_connected_peer_ids()
	var my_peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else -1

	if peer_ids.size() >= 1:
		var p1_peer_id := peer_ids[0]
		var p1_ready := bool(ready_status_by_peer.get(p1_peer_id, false))
		player1_label.text = _t("player1")
		if p1_peer_id == my_peer_id:
			player1_label.text += " [" + _t("you") + "]"
		player1_label.text += "\n" + (_t("ready") if p1_ready else _t("not_ready"))
		player1_label.modulate = Color.GREEN if p1_ready else Color.WHITE
	else:
		player1_label.text = _t("player1") + "\n" + _t("not_connected")
		player1_label.modulate = Color.GRAY

	if peer_ids.size() >= 2:
		var p2_peer_id := peer_ids[1]
		var p2_ready := bool(ready_status_by_peer.get(p2_peer_id, false))
		player2_label.text = _t("player2")
		if p2_peer_id == my_peer_id:
			player2_label.text += " [" + _t("you") + "]"
		player2_label.text += "\n" + (_t("ready") if p2_ready else _t("not_ready"))
		player2_label.modulate = Color.GREEN if p2_ready else Color.WHITE
	else:
		player2_label.text = _t("player2") + "\n" + _t("not_connected")
		player2_label.modulate = Color.GRAY

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _get_local_ip() -> String:
	# Get local IP address for LAN.
	var addresses = IP.get_local_addresses()
	
	# Find IPv4 address that's not localhost
	for ip in addresses:
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	
	return "Unknown"

func _validate_ip(ip: String) -> bool:
	# Validate IPv4 address format.
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
	# Show error message in the waiting panel area.
	status_label.text = message
	status_label.modulate = Color.RED
	
	# Reset color after 3 seconds
	await get_tree().create_timer(3.0).timeout
	status_label.modulate = Color.WHITE

func _t(key: String) -> String:
	# Get translated text.
	return translations[current_language].get(key, key)

func _update_translations() -> void:
	# Update all UI text based on current language.
	title_label.text = _t("title")
	host_button.text = _t("host")
	join_button.text = _t("join")
	back_button.text = _t("back")
	connect_button.text = _t("connect")
	cancel_button.text = _t("cancel")
	ready_checkbox.text = _t("ready_checkbox")
	start_game_button.text = _t("start_game")
	disconnect_button.text = _t("disconnect")
