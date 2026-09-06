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
@onready var subtitle_label = $MarginContainer/VBoxContainer/SubtitleLabel
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
## The waiting room's column lives inside a ScrollContainer, and that is load-bearing rather
## than cosmetic. Seven rows stack here - status, player list, ready, auto play, start,
## disconnect, leaderboard - and on mobile five of them are raised to the 48dp touch floor,
## which is density-dependent: 121 units at 402 dpi, 168 at 560. The column's minimum height
## reached 1114 units on a 1080-unit screen (measured, Moto E5 Plus shape as host), and
## because a Control clamps its size UP to its own minimum, that minimum propagated out to
## the full-rect MarginContainer, whose grow_vertical is GROW_DIRECTION_BOTH - so the
## overflow was split across BOTH edges and the title and status text at the top were cut
## off with nothing to scroll. Scrolling vertically drops this column's contributed minimum
## height to zero, so the screen stops growing past its edges, and the rows that do not fit
## become reachable instead of lost. horizontal_scroll_mode is DISABLED so the column still
## publishes its minimum WIDTH; the inner VBox expands in both axes so the authored centre
## alignment still centres whenever there is room. Measured in tools/VerifyWaitingRoomFit.tscn.
@onready var waiting_scroll = $MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll
@onready var status_label = $MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/StatusLabel
@onready var player_list_container = (
	$MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/PlayerListContainer
)
@onready var player1_label = (
	$MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/PlayerListContainer/Player1Label
)
@onready var player2_label = (
	$MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/PlayerListContainer/Player2Label
)
@onready var ready_checkbox = (
	$MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/ReadyCheckbox
)
@onready var auto_play_button = (
	$MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/AutoPlayButton
)
@onready var start_game_button = (
	$MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/StartGameButton
)
@onready var disconnect_button = (
	$MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/DisconnectButton
)

# Dynamically created after AutoPlayButton
var mp_duration_row: HBoxContainer = null
var mp_duration_spinbox: SpinBox = null
## The round-timer control that P5 asked for, sitting with the other three session controls
## (Ready / Auto Play / Start Game) rather than in Settings, because a round clock only means
## anything while a session exists and both peers have to agree on it.
##
## A cycling Button, not a SpinBox. Three reasons, in order of weight:
##   1. MobileUIManager._on_node_added() raises every BaseButton to the 48dp touch floor as
##      it enters the tree. A SpinBox is not a BaseButton, so it would need its own sizing
##      and would still be a 40-unit-tall target on the phones that reported P3.
##   2. Typing on this screen is the P3 defect: the soft keyboard covers the field. One tap
##      per step needs no keyboard at all.
##   3. The values worth having are a short list, and a list rules out the "typed 7, got 5"
##      snapping trap that both existing SpinBoxes on this project carry comments about.
##
## Not persisted, like the auto-play duration above it: the round clock is a per-session
## choice, and the shipped default (0 = each scene's authored 30 s) is the one a fresh launch
## should get.
const ROUND_TIMER_STEPS: Array[float] = [0.0, 15.0, 30.0, 45.0, 60.0, 90.0, 120.0, 180.0]

var round_timer_button: Button = null

var leaderboard_button: Button = null
var leaderboard_panel: Control = null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var current_language: String = "en"  # "en" or "tl" (Tagalog)
## A localization KEY queued by NetworkManager through GameManager.set_multiplayer_notice(),
## empty when the last round ended normally. Rendered through _t() like the rest of this
## screen so a language switch re-renders it.
var _pending_notice_key: String = ""
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
		"your_role": "Your Role: %s",
		# The tagline the scene hardcoded in English on SubtitleLabel, now translated like
		# everything else on this screen — and the fallback the departure notices replace.
		"subtitle": "Team up to save water together!",
		# Rendered from the key NetworkManager queues through GameManager.set_multiplayer_notice().
		# Duplicated from autoload/Localization.gd on purpose: this screen has always carried its
		# own table (see "host"/"join"/"back" above) and _t() reads only from here.
		"notice_host_left": "The host left the game. Round cancelled.",
		"notice_partner_left": "Your partner left the game. Round cancelled.",
		"notice_partner_no_return": "Your partner never came back. Round cancelled."
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
		"your_role": "Iyong Papel: %s",
		"subtitle": "Sabay tayong magtipid ng tubig!",
		"notice_host_left": "Umalis ang host. Kanselado ang round.",
		"notice_partner_left": "Umalis ang kapareha mo. Kanselado ang round.",
		"notice_partner_no_return": "Hindi na bumalik ang kapareha mo. Kanselado ang round."
	}
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	# Load language preference
	if Localization:
		current_language = "tl" if Localization.get_language_code() == "tl" else "en"
	
	# Why the reason is read HERE and not only on MultiplayerMenu: every involuntary exit lands
	# in this scene, not that one (GameManager.return_to_multiplayer_lobby()), so a notice read
	# only by the menu would go unseen and then surface out of context on some later visit.
	# Reading it clears it, so whichever screen comes up first is the one that explains.
	_pending_notice_key = GameManager.consume_multiplayer_notice()
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

	# Build MP AutoPlay duration row (placed after AutoPlayButton)
	_create_mp_duration_row()
	# P5: the round timer belongs with the session controls, not in Settings.
	_create_round_timer_row()
	# Build leaderboard button in waiting panel
	_create_leaderboard_button()

func _create_leaderboard_button() -> void:
	# Add a "📊 Session Leaderboard" button to the WaitingPanel VBox
	var vbox = auto_play_button.get_parent()
	if not vbox:
		return
	leaderboard_button = Button.new()
	leaderboard_button.name = "LeaderboardButton"
	leaderboard_button.text = Localization.get_text("mp_session_leaderboard")
	leaderboard_button.custom_minimum_size = Vector2(0, 50)
	leaderboard_button.add_theme_font_size_override("font_size", 18)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	vbox.add_child(leaderboard_button)

func _create_mp_duration_row() -> void:
	# Create a HBox row [Label] [SpinBox] inserted after AutoPlayButton in WaitingPanel's VBox
	var vbox = auto_play_button.get_parent()
	if not vbox:
		return
	mp_duration_row = HBoxContainer.new()
	mp_duration_row.name = "MPDurationRow"
	mp_duration_row.add_theme_constant_override("separation", 8)
	mp_duration_row.visible = false  # Hidden until AutoPlay is enabled

	var lbl = Label.new()
	lbl.text = Localization.get_text("mp_duration_label")
	lbl.add_theme_font_size_override("font_size", 18)
	mp_duration_row.add_child(lbl)

	mp_duration_spinbox = SpinBox.new()
	mp_duration_spinbox.min_value = 0
	mp_duration_spinbox.max_value = 120
	# Same reason as the single-player box in Settings.gd: step is a SNAP, not just
	# an arrow increment, so a whole-minute step made every fractional duration
	# unreachable. Both boxes now keep what is typed and step by a minute on the
	# arrows. The value is broadcast to the partner by _on_mp_duration_changed().
	mp_duration_spinbox.step = 0
	mp_duration_spinbox.custom_arrow_step = 1.0
	mp_duration_spinbox.suffix = " min  (0=∞)"
	mp_duration_spinbox.custom_minimum_size = Vector2(160, 40)
	mp_duration_spinbox.allow_greater = false
	mp_duration_spinbox.allow_lesser = false
	if AutoPlayManager:
		mp_duration_spinbox.value = AutoPlayManager.get_mp_auto_play_duration_minutes()
	mp_duration_spinbox.value_changed.connect(_on_mp_duration_changed)
	mp_duration_row.add_child(mp_duration_spinbox)

	# Insert right after AutoPlayButton
	var ap_idx := auto_play_button.get_index()
	vbox.add_child(mp_duration_row)
	vbox.move_child(mp_duration_row, ap_idx + 1)


func _create_round_timer_row() -> void:
	var vbox = auto_play_button.get_parent()
	if not vbox:
		return
	round_timer_button = Button.new()
	round_timer_button.name = "RoundTimerButton"
	round_timer_button.custom_minimum_size = Vector2(0, 50)
	round_timer_button.add_theme_font_size_override("font_size", 18)
	round_timer_button.pressed.connect(_on_round_timer_pressed)
	# Below the auto-play duration row and above Start Game, so the reading order is
	# "who is playing, how, for how long, go".
	var after: Node = mp_duration_row if mp_duration_row else auto_play_button
	vbox.add_child(round_timer_button)
	vbox.move_child(round_timer_button, after.get_index() + 1)
	if NetworkManager and not NetworkManager.mp_round_seconds_changed.is_connected(
			_on_round_seconds_changed):
		NetworkManager.mp_round_seconds_changed.connect(_on_round_seconds_changed)
	_refresh_round_timer_button()


## Only the host may change it, and the client is told so by the control instead of finding
## out when its tap does nothing: NetworkManager.set_mp_round_seconds() refuses a client's
## write and the sync RPC is @rpc("authority"), so a disabled button here is the truth about
## what the network layer will accept, not merely a suggestion.
func _refresh_round_timer_button() -> void:
	if round_timer_button == null:
		return
	var seconds: float = NetworkManager.mp_round_seconds if NetworkManager else 0.0
	var value_text: String = (
		Localization.get_text("mp_round_timer_default") if seconds <= 0.0
		else "%ds" % int(round(seconds))
	)
	round_timer_button.text = "%s %s" % [
		Localization.get_text("mp_round_timer"), value_text
	]
	var host_side: bool = (not _is_connected()) or _is_host()
	round_timer_button.disabled = not host_side
	round_timer_button.tooltip_text = (
		"" if host_side else Localization.get_text("mp_round_timer_host_only")
	)


func _on_round_timer_pressed() -> void:
	if not NetworkManager:
		return
	if _is_connected() and not _is_host():
		return
	var current: float = NetworkManager.mp_round_seconds
	var idx: int = 0
	for i in range(ROUND_TIMER_STEPS.size()):
		if is_equal_approx(ROUND_TIMER_STEPS[i], current):
			idx = i
			break
	var next: float = ROUND_TIMER_STEPS[(idx + 1) % ROUND_TIMER_STEPS.size()]
	if AudioManager:
		AudioManager.play_click()
	# The button's own caption is refreshed by _on_round_seconds_changed(), which fires for
	# the host too because the sync is call_local - one code path writes the label whether
	# the change started here or arrived from the partner's host.
	NetworkManager.set_mp_round_seconds(next)


func _on_round_seconds_changed(_seconds: float) -> void:
	_refresh_round_timer_button()

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
	if not auto_play_button.pressed.is_connected(_on_auto_play_pressed):
		auto_play_button.pressed.connect(_on_auto_play_pressed)
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

	# Also listen to NetworkManager autoload signals if available to keep ready state authoritative
	if NetworkManager:
		if not NetworkManager.player_ready_changed.is_connected(_on_network_player_ready_changed):
			NetworkManager.player_ready_changed.connect(_on_network_player_ready_changed)
		if not NetworkManager.player_connected.is_connected(_on_network_player_connected):
			NetworkManager.player_connected.connect(_on_network_player_connected)
		if not NetworkManager.player_disconnected.is_connected(_on_network_player_disconnected):
			NetworkManager.player_disconnected.connect(_on_network_player_disconnected)
		if not NetworkManager.both_players_ready.is_connected(_on_both_players_ready):
			NetworkManager.both_players_ready.connect(_on_both_players_ready)
		if not NetworkManager.game_started.is_connected(_on_game_started):
			NetworkManager.game_started.connect(_on_game_started)

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
	var all_ready := _are_all_players_ready()
	if _is_host():
		start_game_button.visible = true
		start_game_button.disabled = not all_ready
		start_game_button.text = _t("start_game")
	else:
		# Client: show a disabled status indicator so they know the host must press Start
		start_game_button.visible = true
		start_game_button.disabled = true
		start_game_button.text = "⏳ " + (
			Localization.get_text("mp_waiting_host_start") if all_ready
			else Localization.get_text("mp_waiting_all_players")
		)

func _sync_local_ready(ready_value: bool) -> void:
	# Guard: peer may have been cleared by a preceding disconnect call
	if multiplayer.multiplayer_peer == null:
		return
	is_ready = ready_value
	# Use set_pressed_no_signal so we don't re-enter _on_ready_toggled
	ready_checkbox.set_pressed_no_signal(ready_value)
	# Keep NetworkManager's authoritative ready state in sync with the lobby UI.
	if NetworkManager:
		NetworkManager.set_ready(ready_value)
	# Sync via the lobby's own RPC (call_local so our dict updates too).
	# NOTE: NetworkManager.players may be empty because the lobby uses
	# GameManager.host_game(), not NetworkManager.create_server().
	# The lobby _sync_ready_state RPC (any_peer, call_local, reliable)
	# is the authoritative ready-sync path.
	var my_id := multiplayer.get_unique_id()
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
	_pull_network_ready_map()
	_update_player_list()
	_update_start_button_state()
	# Which side of the session this peer is on is only known once one exists, and the
	# round timer is host-only - so its enabled state is re-derived on entry rather than
	# at build time, when _is_host() is still false on a host that has not pressed Create.
	_refresh_round_timer_button()

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


func _on_auto_play_pressed() -> void:
	var enabling: bool = auto_play_button.button_pressed
	# Sync to partner WITH call_local so both sides run the same setup.
	# If not yet connected (single-device test), apply locally without rpc.
	if _is_connected():
		rpc("_sync_auto_play_state", enabling)
	else:
		_sync_auto_play_state(enabling)

@rpc("any_peer", "call_local", "reliable")
func _sync_auto_play_state(enabled: bool) -> void:
	if AutoPlayManager:
		AutoPlayManager.set_mp_auto_play_enabled(enabled)
	if auto_play_button:
		auto_play_button.set_pressed_no_signal(enabled)
		if enabled:
			auto_play_button.text = Localization.get_text("mp_auto_play_on")
			auto_play_button.modulate = Color(1.2, 1.0, 0.4)
		else:
			auto_play_button.text = Localization.get_text("mp_auto_play")
			auto_play_button.modulate = Color.WHITE
	if mp_duration_row:
		mp_duration_row.visible = enabled
	if enabled:
		# Auto mark self as ready
		if _is_connected() and not is_ready:
			_sync_local_ready(true)
		# Auto-start if host and all players are already ready
		if _is_host() and _are_all_players_ready():
			_do_start_game()

@rpc("any_peer", "call_local", "reliable")
func _sync_mp_duration(minutes: float) -> void:
	if AutoPlayManager:
		AutoPlayManager.set_mp_auto_play_duration(minutes)
	if mp_duration_spinbox:
		mp_duration_spinbox.set_value_no_signal(minutes)

func _on_mp_duration_changed(value: float) -> void:
	rpc("_sync_mp_duration", value)


func _on_network_player_ready_changed(peer_id: int, ready_state: bool) -> void:
	# Update local map when NetworkManager reports a ready change
	ready_status_by_peer[peer_id] = ready_state
	_update_player_list()
	_update_start_button_state()
	# If host and autoplay is on, auto-start the moment all players become ready
	if _is_host() and ready_state and _are_all_players_ready():
		if AutoPlayManager and AutoPlayManager.is_mp_auto_play_enabled():
			_do_start_game()


func _on_network_player_connected(peer_id: int, _player_num: int) -> void:
	# Ensure new peer entry exists
	if not ready_status_by_peer.has(peer_id):
		ready_status_by_peer[peer_id] = false
	_update_player_list()
	_update_start_button_state()


func _on_network_player_disconnected(peer_id: int) -> void:
	if ready_status_by_peer.has(peer_id):
		ready_status_by_peer.erase(peer_id)
	_update_player_list()
	_update_start_button_state()

func _on_start_game_pressed() -> void:
	_do_start_game()

func _do_start_game() -> void:
	if not GameManager:
		print("❌ GameManager is null")
		return
	
	if not _is_host():
		print("❌ Not the host — only the host can start")
		return
	
	if _get_connected_peer_ids().size() < 2:
		_show_error(_t("need_two_players"))
		return

	if not _are_all_players_ready():
		_show_error(_t("both_players_ready"))
		return

	print("🎮 Starting GameManager multiplayer session flow...")
	GameManager.rpc("_begin_multiplayer_session_rpc")
	await get_tree().process_frame
	# Use LevelSets so P1 and P2 get paired complementary tasks
	if not LevelSets:
		push_error("❌ LevelSets not available!")
		return
	var level_set = LevelSets.get_random_level_set()
	_load_level_set_games(level_set)

func _on_disconnect_pressed() -> void:
	if GameManager:
		GameManager.disconnect_multiplayer()
	if NetworkManager and NetworkManager.connection_active:
		NetworkManager.disconnect_multiplayer()
	if AutoPlayManager:
		AutoPlayManager.set_mp_auto_play_enabled(false)
	ready_status_by_peer.clear()
	is_ready = false
	# set_pressed_no_signal prevents triggering _on_ready_toggled after the peer is gone
	ready_checkbox.set_pressed_no_signal(false)
	if auto_play_button:
		auto_play_button.button_pressed = false
		auto_play_button.text = Localization.get_text("mp_auto_play")
		auto_play_button.modulate = Color.WHITE
	if mp_duration_row:
		mp_duration_row.visible = false
	
	_show_mode_selection()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LEADERBOARD
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_leaderboard_pressed() -> void:
	# Toggle leaderboard panel visibility
	if leaderboard_panel and is_instance_valid(leaderboard_panel):
		leaderboard_panel.visible = not leaderboard_panel.visible
		if leaderboard_panel.visible:
			_refresh_leaderboard_panel()
		return
	_build_leaderboard_panel()

func _build_leaderboard_panel() -> void:
	# Build a floating leaderboard overlay on top of the lobby
	if leaderboard_panel and is_instance_valid(leaderboard_panel):
		leaderboard_panel.queue_free()

	leaderboard_panel = Control.new()
	leaderboard_panel.name = "LeaderboardPanel"
	leaderboard_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	leaderboard_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(leaderboard_panel)

	# Dark semi-transparent backdrop
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.80)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaderboard_panel.add_child(bg)

	# Centered card
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	leaderboard_panel.add_child(center)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 0)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.12, 0.18, 0.97)
	card_style.border_color = Color(0.3, 0.7, 1.0)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# ── Header ───────────────────────────────────────────────────────
	var hdr_hbox = HBoxContainer.new()
	vbox.add_child(hdr_hbox)

	var hdr_lbl = Label.new()
	hdr_lbl.name = "LeaderboardTitle"
	hdr_lbl.text = Localization.get_text("mp_session_leaderboard")
	hdr_lbl.add_theme_font_size_override("font_size", 28)
	hdr_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hbox.add_child(hdr_lbl)

	var close_btn = Button.new()
	close_btn.text = "✖"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func(): leaderboard_panel.visible = false)
	close_btn.focus_mode = Control.FOCUS_NONE
	hdr_hbox.add_child(close_btn)

	var sep0 = HSeparator.new()
	vbox.add_child(sep0)

	# ── Column headers ────────────────────────────────────────────────
	var col_hdr = HBoxContainer.new()
	col_hdr.add_theme_constant_override("separation", 0)
	vbox.add_child(col_hdr)

	# Header captions come from the shared table like the rest of this panel (the screen's
	# own translations dict covers the connect/ready chrome above, not the leaderboard).
	for col in [
		[Localization.get_text("round"), 80],
		[Localization.get_text("mp_lb_col_p1"), 130],
		[Localization.get_text("mp_lb_col_p2"), 130],
		[Localization.get_text("mp_lb_col_team"), 110],
		[Localization.get_text("mp_lb_col_result"), 80]
	]:
		var lbl = Label.new()
		lbl.text = col[0]
		lbl.custom_minimum_size = Vector2(col[1], 0)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col_hdr.add_child(lbl)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# ── Round rows (populated by _refresh_leaderboard_panel) ─────────
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "LeaderboardScroll"
	vbox.add_child(scroll)

	var rows_vbox = VBoxContainer.new()
	rows_vbox.name = "RowsVBox"
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(rows_vbox)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# ── Totals row ────────────────────────────────────────────────────
	var totals_hbox = HBoxContainer.new()
	totals_hbox.name = "TotalsRow"
	totals_hbox.add_theme_constant_override("separation", 0)
	vbox.add_child(totals_hbox)

	var export_note = Label.new()
	export_note.name = "ExportNote"
	export_note.text = Localization.get_text("mp_session_log_note")
	export_note.add_theme_font_size_override("font_size", 13)
	export_note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	export_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	export_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(export_note)

	_refresh_leaderboard_panel()

func _refresh_leaderboard_panel() -> void:
	if not leaderboard_panel or not is_instance_valid(leaderboard_panel):
		return
	var rows_vbox = leaderboard_panel.find_child("RowsVBox", true, false)
	var totals_hbox = leaderboard_panel.find_child("TotalsRow", true, false)
	if not rows_vbox:
		return

	# Clear previous rows
	for c in rows_vbox.get_children():
		c.queue_free()
	if totals_hbox:
		for c in totals_hbox.get_children():
			c.queue_free()

	var leaderboard: Array = []
	if SessionLogger and SessionLogger.has_method("get_mp_leaderboard"):
		leaderboard = SessionLogger.get_mp_leaderboard()

	if leaderboard.is_empty() or (leaderboard.size() == 1 and leaderboard[0].get("round_num", 0) == -1):
		var empty_lbl = Label.new()
		empty_lbl.text = Localization.get_text("mp_no_rounds_yet")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		rows_vbox.add_child(empty_lbl)
		return

	# Separate data rows from totals sentinel
	var data_rows: Array = []
	var totals_data: Dictionary = {}
	for row in leaderboard:
		if row.get("round_num", 0) == -1:
			totals_data = row
		else:
			data_rows.append(row)

	# Build one HBoxContainer per round
	for row in data_rows:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 0)
		rows_vbox.add_child(hbox)

		var success: bool = row.get("team_success", false)
		var row_color := Color(0.9, 1.0, 0.9) if success else Color(1.0, 0.8, 0.8)

		var pts := Localization.get_text("score_points")
		for col in [
			[Localization.get_text("mp_lb_round_num") % row.get("round_num", 0), 80],
			[pts % row.get("p1_score", 0), 130],
			[pts % row.get("p2_score", 0), 130],
			[pts % row.get("team_score", 0), 110],
			["✅" if success else "❌", 80]
		]:
			var lbl = Label.new()
			lbl.text = col[0]
			lbl.custom_minimum_size = Vector2(col[1], 0)
			lbl.add_theme_font_size_override("font_size", 17)
			lbl.add_theme_color_override("font_color", row_color)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hbox.add_child(lbl)

	# Totals row
	if totals_hbox and not totals_data.is_empty():
		var pts_fmt := Localization.get_text("score_points")
		for col in [
			[Localization.get_text("mp_lb_total"), 80],
			[pts_fmt % totals_data.get("p1_score", 0), 130],
			[pts_fmt % totals_data.get("p2_score", 0), 130],
			[pts_fmt % totals_data.get("team_score", 0), 110],
			["", 80]
		]:
			var lbl = Label.new()
			lbl.text = col[0]
			lbl.custom_minimum_size = Vector2(col[1], 0)
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_constant_override("outline_size", 2)
			totals_hbox.add_child(lbl)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NETWORK CALLBACKS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_player_connected(peer_id: int) -> void:
	print("✅ Player connected: %d" % peer_id)
	status_label.text = _t("player_connected")
	if _is_host():
		ready_status_by_peer[peer_id] = false
		rpc_id(peer_id, "_sync_ready_map", ready_status_by_peer)
		# Resync AutoPlay + duration to the newly-connected partner so they
		# immediately see the correct state even if host toggled before they joined.
		if AutoPlayManager and AutoPlayManager.is_mp_auto_play_enabled():
			rpc_id(peer_id, "_sync_auto_play_state", true)
			rpc_id(peer_id, "_sync_mp_duration", AutoPlayManager.get_mp_auto_play_duration_minutes())
	_pull_network_ready_map()
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
	_pull_network_ready_map()
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

func _on_both_players_ready() -> void:
	print("✅ Both players ready!")
	
	if _is_host():
		start_game_button.disabled = false
		# When AutoPlay is active on the host, start automatically
		if AutoPlayManager and AutoPlayManager.is_mp_auto_play_enabled():
			_do_start_game()

func _load_level_set_games(level_set: Dictionary) -> void:
	# Load the correct game scene for EACH PLAYER based on level set
	# P1 and P2 load DIFFERENT scenes with interconnected gameplay
	var p1_scene: String = level_set["player1_game"]
	var p2_scene: String = level_set["player2_game"]
	
	print("🎮 Loading INTERCONNECTED multiplayer games:")
	print("   P1 (%s): %s" % [level_set["player1_role"], p1_scene])
	print("   P2 (%s): %s" % [level_set["player2_role"], p2_scene])
	
	# Validate both scenes exist
	if not ResourceLoader.exists(p1_scene):
		push_error("❌ P1 game scene not found: " + p1_scene)
		_show_error("P1 game scene not found!")
		return
	
	if not ResourceLoader.exists(p2_scene):
		push_error("❌ P2 game scene not found: " + p2_scene)
		_show_error("P2 game scene not found!")
		return
	
	# The set travels with the two scene paths: it is what names the pair of roles the HUD
	# shows, and passing only the paths is what left round 1 on the placeholder pair.
	if NetworkManager:
		NetworkManager.start_multiplayer_game_pair(p1_scene, p2_scene, level_set)
	else:
		push_error("❌ NetworkManager not available!")
		_show_error("Network error!")

func _on_game_started(scenario_id: String, _roles: Dictionary) -> void:
	print("🎮 Game started: " + scenario_id)
	# Scene change is handled by NetworkManager via RPC
	pass

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


func _pull_network_ready_map() -> void:
	# If NetworkManager is present, populate local ready map from its authoritative player data
	if NetworkManager and typeof(NetworkManager.players) == TYPE_DICTIONARY:
		# NetworkManager stores player info in `players` dictionary
		for peer_id in NetworkManager.players.keys():
			var pdata = NetworkManager.players[peer_id]
			ready_status_by_peer[peer_id] = bool(pdata.get("ready", false))
	elif GameManager and GameManager.has_method("get_connected_multiplayer_peer_ids"):
		# Fallback: initialize map with peer ids from GameManager
		var peers = GameManager.get_connected_multiplayer_peer_ids()
		for id in peers:
			if not ready_status_by_peer.has(id):
				ready_status_by_peer[id] = false

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
	# Both halves of the round-timer caption come from Localization, so a language switch
	# has to re-render it like the authored labels above. Null-guarded because
	# _update_translations() runs early in _ready(), before the row is built.
	if round_timer_button:
		_refresh_round_timer_button()
	disconnect_button.text = _t("disconnect")
	# The subtitle carries either the tagline or the reason the last round ended. It sits above
	# all three panels, so it is the one label that is visible on the mode-selection view a
	# dropped-out player actually lands on — the waiting panel's StatusLabel is hidden there.
	if _pending_notice_key.is_empty():
		subtitle_label.text = _t("subtitle")
		subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
	else:
		subtitle_label.text = _t(_pending_notice_key)
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42, 1.0))
