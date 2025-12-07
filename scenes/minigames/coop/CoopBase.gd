extends Node2D
class_name CoopScenarioBase

## ═══════════════════════════════════════════════════════════════════
## CO-OP SCENARIO BASE
## Base class for 2-player cooperative scenarios
## ═══════════════════════════════════════════════════════════════════

signal game_completed(success: bool)

var local_player_num: int = 0
var game_active: bool = false
var time_remaining: float = 60.0
var current_minigame: Node = null

# UI References
var timer_label: Label
var status_label: Label
var partner_status_label: Label

func _ready() -> void:
	# Get local player number from NetworkManager
	if NetworkManager:
		local_player_num = NetworkManager.get_local_player_num()
	else:
		local_player_num = 1 # Fallback for testing
	
	_setup_ui()
	_start_scenario()

func _process(delta: float) -> void:
	if not game_active: return
	
	time_remaining -= delta
	if timer_label:
		timer_label.text = "⏱️ %.0fs" % max(0, time_remaining)
	
	if time_remaining <= 0:
		_on_timeout()

func _start_scenario() -> void:
	game_active = true
	
	# Instantiate the correct minigame based on player number
	if local_player_num == 1:
		_setup_player1_game()
	else:
		_setup_player2_game()

func _setup_player1_game() -> void:
	# Override in child class
	pass

func _setup_player2_game() -> void:
	# Override in child class
	pass

func _on_timeout() -> void:
	game_active = false
	# Check win condition (usually handled by child class)
	_fail_game("Time's up!")

func _fail_game(reason: String) -> void:
	game_active = false
	status_label.text = "❌ FAILED: " + reason
	status_label.modulate = Color.RED
	
	# Notify partner
	if NetworkManager:
		NetworkManager.send_game_event("fail", {"reason": reason})
	
	await get_tree().create_timer(3.0).timeout
	_return_to_lobby()

func _win_game() -> void:
	game_active = false
	status_label.text = "✅ SUCCESS!"
	status_label.modulate = Color.GREEN
	
	# Notify partner
	if NetworkManager:
		NetworkManager.send_game_event("win", {})
	
	await get_tree().create_timer(3.0).timeout
	_return_to_lobby()

func _return_to_lobby() -> void:
	if NetworkManager:
		NetworkManager.return_to_lobby()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	canvas.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Top Bar
	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)
	
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 32)
	timer_label.text = "⏱️ 60s"
	top_hbox.add_child(timer_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)
	
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.text = "Playing..."
	top_hbox.add_child(status_label)
	
	# Partner Status
	partner_status_label = Label.new()
	partner_status_label.add_theme_font_size_override("font_size", 18)
	partner_status_label.text = "Partner: Active"
	partner_status_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(partner_status_label)

# Network Event Handlers (called by NetworkManager)
func on_partner_event(event_type: String, data: Dictionary) -> void:
	match event_type:
		"fail":
			_fail_game("Partner Failed!")
		"win":
			_win_game()
		"progress":
			# Update partner progress UI if needed
			pass
