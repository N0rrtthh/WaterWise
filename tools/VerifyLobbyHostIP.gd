extends Node

## ═══════════════════════════════════════════════════════════════════
## LOBBY-IP-AFTER-HOST-RESOLUTION HARNESS
## ═══════════════════════════════════════════════════════════════════
## The phone-reported failure: "in the host after disconnecting an going in to the
## lobby the ip address is not even displayed and needs to create another
## multiplayer session to display it".
##
## The host branch of NetworkManager._resolve_lost_peer() deliberately keeps the
## server socket alive behind the lobby (so the partner can re-dial it), but the
## lobby's _ready() treated any existing connection as "returning from a live
## session" and showed "player connected" — a status that is wrong (the partner is
## GONE) and carries no IP, so the host had to press Create all over again before
## the other phone had anything to join.
##
## What is under test: after a host-side resolution, the lobby shows the
## waiting-for-player panel WITH the local IP, and the Create button is not needed.
##
## HOW IT IS DRIVEN, AND WHY THAT IS HONEST
##   GameManager.host_game() really binds a server; NetworkManager.game_in_progress
##   is set and _resolve_lost_peer(true) is called directly — the same function the
##   hold-expiry path calls, with the same argument shape. No second process is
##   needed because nothing under test depends on the partner's behaviour: the
##   partner is absent, which is the point.
##
## Usage:
##   godot --headless --path . res://tools/VerifyLobbyHostIP.tscn
## ═══════════════════════════════════════════════════════════════════

const PORT: int = 7819
const LOBBY_PATH: String = "res://scenes/ui/MultiplayerLobby.tscn"

var _pass: int = 0
var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  ✓ %s" % label)
	else:
		_fail += 1
		print("  ✗ %s" % label)
	if detail != "":
		print("          %s" % detail)


func _state() -> String:
	var lobby := get_tree().current_scene
	var status := "(no lobby)"
	var panel := "-"
	if lobby != null and lobby.scene_file_path == LOBBY_PATH:
		var sl: Label = lobby.get_node_or_null(
			"MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/StatusLabel")
		status = sl.text if sl != null else "(no label)"
		var msp := lobby.get_node_or_null("MarginContainer/VBoxContainer/ModeSelectionPanel")
		var wp := lobby.get_node_or_null("MarginContainer/VBoxContainer/WaitingPanel")
		panel = "mode=%s waiting=%s" % [
			str(msp.visible if msp != null else null),
			str(wp.visible if wp != null else null)]
	return "panel: %s | status: %s" % [panel, status]


func _get_local_ip() -> String:
	# The lobby's own selection logic, duplicated because it is private: it prefers
	# 192.168./10./172. ranges, and this machine's first non-loopback adapter is
	# NOT one of those — asserting on a different adapter's address than the one
	# the label actually shows made the first run of this check fail while the IP
	# was sitting right there on the label's second line.
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"


func _ready() -> void:
	# The resolution routes through change_scene_to_file(), which frees
	# get_tree().current_scene — this node. Same trap as VerifyGracePeriodLifecycle:
	# hand the current_scene role to a throwaway anchor first.
	await get_tree().process_frame
	var anchor := Node.new()
	anchor.name = "LobbyIPProbeAnchor"
	get_tree().root.add_child(anchor)
	get_tree().current_scene = anchor
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== LOBBY-IP-AFTER-HOST-RESOLUTION ===")
	var nm := get_node_or_null("/root/NetworkManager")
	var gm := get_node_or_null("/root/GameManager")
	if nm == null or gm == null:
		print("  FAIL: autoload missing")
		get_tree().quit(1)
		return

	# A real host session, as the lobby's Create button starts it.
	_check("GameManager.host_game() bound port %d" % PORT, gm.host_game(PORT))

	# The state a partner-expiry leaves behind: a round was in progress and the
	# hold expired with nobody back. _resolve_lost_peer(true) is exactly what
	# _end_reconnect_hold(false) calls on the host.
	nm.game_in_progress = true
	nm._resolve_lost_peer(true)

	# The routing is deferred (call_deferred change_scene_to_file).
	var lobby_up := false
	for _i in range(150):
		var cs := get_tree().current_scene
		if cs != null and is_instance_valid(cs) and cs.scene_file_path == LOBBY_PATH:
			lobby_up = true
			break
		await get_tree().create_timer(0.1).timeout
	_check("the host landed in the lobby", lobby_up, _state())

	if lobby_up:
		await get_tree().create_timer(0.5).timeout  # let _ready() finish its build-out
		var lobby := get_tree().current_scene
		var wp := lobby.get_node_or_null("MarginContainer/VBoxContainer/WaitingPanel")
		var msp := lobby.get_node_or_null("MarginContainer/VBoxContainer/ModeSelectionPanel")
		var sl: Label = lobby.get_node_or_null(
			"MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/StatusLabel")
		_check("the waiting panel is up (no Create needed)", wp != null and wp.visible, _state())
		_check("the mode-selection panel is not", msp == null or not msp.visible, _state())
		var ip := _get_local_ip()
		_check("the status shows the waiting-for-player message with the IP",
			sl != null and ip != "" and ip in sl.text,
			_state())
		# The server must STILL be listening behind the lobby — the whole reason
		# the host branch routes raw. If the teardown killed it, showing the IP
		# would be a lie.
		_check("the server is still listening behind the lobby",
			nm.network != null and nm.connection_active, _state())

	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	print("")
	get_tree().paused = false
	get_tree().quit(1 if _fail > 0 else 0)
