extends Node

## ── MP + SHARED SCREENS LAYOUT AUDIT (Item 1 close-out) ────────────────────
##
## Closes the P3 layout items on the two test-device shapes, log-checkable:
##   1. MainMenu (title screen): the QUIT button is fully inside the viewport,
##      and the menu column's minimum height fits, so the CenterContainer
##      cannot overflow both edges.
##   2. MultiplayerMenu: every control inside the viewport.
##   3. MultiplayerLobby — mode selection: every control inside the viewport.
##   4. MultiplayerLobby — join: the IP input is fully inside the viewport with
##      no keyboard, and STAYS above a simulated soft keyboard (driven through
##      MultiplayerLobby._debug_keyboard_height_px, the same math the device
##      path uses), then the pan restores when the keyboard closes.
##   5. MultiplayerLobby — waiting room: the top status text starts on-screen
##      (the original clip), and the bottom rows are reachable through the
##      WaitingScroll. Also prints the reverted-scroll column minimum so the
##      stale reproduction control in VerifyWaitingRoomFit can be re-read.
##   6. MultiplayerGameOver: every label and the return button inside.
##
## Run (WINDOWED — needs real dpi like ProbeUnlockGrid):
##   godot --path . res://tools/VerifyMpScreensLayout.tscn

const PROFILES := [
	{"name": "Moto E5 Plus", "w": 2160, "h": 1080, "diag": 6.0, "cut": {}},
	{"name": "Poco X3", "w": 2400, "h": 1080, "diag": 6.67, "cut": {}},
]
## Window-pixel height driven into the keyboard-pan math. A soft keyboard on a
## 1080p phone occupies roughly half the screen; 420px (39%) leaves the IP
## field uncovered and the pan correctly stays at zero, which was measured —
## 560px is the realistic worst case where the field IS covered and the pan
## must lift it.
const SIM_KEYBOARD_PX: float = 560.0

var _fails := 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _pass(msg: String) -> void:
	print("    ✓ " + msg)


func _fail(msg: String) -> void:
	_fails += 1
	print("    ✗ " + msg)


func _frames(n: int) -> void:
	for _i in range(n):
		if _tree().paused:
			_tree().paused = false
		await _tree().process_frame


func _dpi(d: Dictionary) -> float:
	var w := float(d["w"])
	var h := float(d["h"])
	return sqrt(w * w + h * h) / float(d["diag"])


func _ready() -> void:
	_run.call_deferred()


func _inside(ctrl: Control) -> bool:
	var vp := _tree().root.get_visible_rect().size
	var r := ctrl.get_global_rect()
	return r.position.x >= -1.0 and r.position.y >= -1.0 \
		and r.end.x <= vp.x + 1.0 and r.end.y <= vp.y + 1.0


func _check_inside(ctrl: Control, label: String) -> void:
	var r := ctrl.get_global_rect()
	if _inside(ctrl):
		_pass("%s inside viewport (rect %s)" % [label, str(r)])
	else:
		_fail("%s CLIPPED (rect %s, viewport %s)"
			% [label, str(r), str(_tree().root.get_visible_rect().size)])


func _adapt_and_wait(mui, scene_path: String, frames: int) -> Control:
	var inst = (load(scene_path) as PackedScene).instantiate()
	_tree().root.add_child(inst)
	mui.adapt_scene_for_mobile(inst)
	await _frames(frames)
	return inst


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  MP + SHARED SCREENS LAYOUT AUDIT")
	print("═══════════════════════════════════════════════════════════")
	var mui = get_node_or_null("/root/MobileUIManager")
	if mui == null:
		_fail("MobileUIManager missing")
		_tree().quit(1)
		return
	mui.debug_mobile_mode = true
	mui._detect_platform()
	for d in PROFILES:
		print("")
		print("  ── %s: window %dx%d, %.1f dpi ──"
			% [d["name"], int(d["w"]), int(d["h"]), _dpi(d)])
		DisplayServer.window_set_size(Vector2i(int(d["w"]), int(d["h"])))
		await _frames(8)
		mui._detect_platform()
		mui.debug_dpi_override = _dpi(d)
		mui.debug_safe_area_px_override = d["cut"]
		if mui.has_method("invalidate_button_min_size_cache"):
			mui.invalidate_button_min_size_cache()
		mui._calculate_safe_area()
		var canvas := _tree().root.get_visible_rect().size
		print("    canvas %.0fx%.0f" % [canvas.x, canvas.y])
		await _check_main_menu(mui)
		await _check_mp_menu(mui)
		await _check_lobby(mui)
		await _check_game_over(mui)

	print("")
	print("═══════════════════════════════════════════════════════════")
	if _fails == 0:
		print("  ALL MP SCREEN LAYOUT CHECKS PASSED")
	else:
		print("  %d CHECK(S) FAILED" % _fails)
	print("═══════════════════════════════════════════════════════════")
	_tree().quit(1 if _fails > 0 else 0)


func _check_main_menu(mui) -> void:
	print("    [MainMenu]")
	var inst = await _adapt_and_wait(mui, "res://scenes/ui/MainMenu.tscn", 45)
	var play: Control = inst.get_node_or_null("UI/VBoxContainer/PlayButton")
	var quit: Control = inst.get_node_or_null("UI/VBoxContainer/QuitButton")
	var box: Control = inst.get_node_or_null("UI/VBoxContainer")
	if quit == null:
		_fail("QuitButton not found")
	else:
		_check_inside(quit, "QUIT button")
		if quit.is_visible_in_tree():
			_pass("QUIT button visible (not hidden)")
		else:
			_fail("QUIT button is hidden")
	if play:
		_check_inside(play, "Play button")
	if box:
		var vp := _tree().root.get_visible_rect().size
		var min_h: float = box.get_combined_minimum_size().y
		print("      menu column min height %.0f vs viewport %.0f" % [min_h, vp.y])
		if min_h <= vp.y:
			_pass("menu column fits, CenterContainer cannot overflow")
		else:
			_fail("menu column min height %.0f EXCEEDS viewport %.0f" % [min_h, vp.y])
	inst.queue_free()
	await _frames(3)


func _check_mp_menu(mui) -> void:
	print("    [MultiplayerMenu]")
	var inst = await _adapt_and_wait(mui, "res://scenes/ui/MultiplayerMenu.tscn", 45)
	for path in ["UI/VBoxContainer/TitleContainer/Title", "UI/VBoxContainer/HostButton",
			"UI/VBoxContainer/JoinButton", "UI/VBoxContainer/BackButton"]:
		var c: Control = inst.get_node_or_null(path)
		if c:
			_check_inside(c, path.get_file())
	inst.queue_free()
	await _frames(3)


func _check_game_over(mui) -> void:
	print("    [MultiplayerGameOver]")
	var inst = await _adapt_and_wait(mui, "res://scenes/ui/MultiplayerGameOver.tscn", 45)
	inst.show_game_over(120, 4, 70, 50)
	await _frames(10)
	for path in ["MarginContainer/VBoxContainer/TitleLabel",
			"MarginContainer/VBoxContainer/FinalScoreLabel",
			"MarginContainer/VBoxContainer/RoundsSurvivedLabel",
			"MarginContainer/VBoxContainer/ContributionsContainer/P1Label",
			"MarginContainer/VBoxContainer/ContributionsContainer/P2Label",
			"MarginContainer/VBoxContainer/ReturnButton"]:
		var c: Control = inst.get_node_or_null(path)
		if c:
			_check_inside(c, path.get_file())
	get_tree().paused = false
	inst.queue_free()
	await _frames(3)


func _check_lobby(mui) -> void:
	print("    [MultiplayerLobby]")
	var inst = await _adapt_and_wait(mui, "res://scenes/ui/MultiplayerLobby.tscn", 45)

	# ── mode selection ──
	inst._show_mode_selection()
	await _frames(5)
	for path in ["MarginContainer/VBoxContainer/ModeSelectionPanel/VBoxContainer/HostButton",
			"MarginContainer/VBoxContainer/ModeSelectionPanel/VBoxContainer/JoinButton",
			"MarginContainer/VBoxContainer/ModeSelectionPanel/VBoxContainer/BackButton"]:
		var c: Control = inst.get_node_or_null(path)
		if c:
			_check_inside(c, path.get_file())

	# ── join: IP field vs the soft keyboard ──
	inst._show_join_panel()
	await _frames(10)
	var ip: Control = inst.get_node_or_null("MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/IPInput")
	if ip == null:
		_fail("IPInput not found")
	else:
		_check_inside(ip, "IP input (keyboard closed)")
		var canvas := _tree().root.get_visible_rect().size
		var ledit := ip as LineEdit
		if ledit and not ledit.has_focus():
			ledit.grab_focus()
		await _frames(2)
		print("      ip_input.has_focus()=%s" % str(ledit.has_focus() if ledit else false))
		inst._debug_keyboard_height_px = SIM_KEYBOARD_PX
		inst._update_keyboard_pan()
		# Engagement read as STATE, before any frame can intervene: this probe's
		# window is not the OS-focused window, and viewport focus can be dropped
		# between frames - focus_exited fires, the pan correctly restores to 0
		# (the same path the restore check below exercises on purpose), and the
		# layout print would then show the restored shape, not the engaged one.
		# On the device the window IS focused while the keyboard is up, so the
		# pan holds; engagement here is asserted from the immediate value.
		var pan_immediate: float = inst._keyboard_pan_units
		print("      pan after direct call: %.0f units" % pan_immediate)
		if pan_immediate > 0.0:
			_pass("keyboard pan engages (%.0f units)" % pan_immediate)
		else:
			_fail("keyboard pan did not engage even with focus held (pan=0)")
		# Settle the layout with focus re-asserted each frame, the way the
		# device holds it while the keyboard is open.
		for _i in range(4):
			if ledit and not ledit.has_focus():
				ledit.grab_focus()
				inst._update_keyboard_pan()
			await _tree().process_frame
		var kb_units: float = SIM_KEYBOARD_PX * (canvas.y / maxf(float(DisplayServer.window_get_size().y), 1.0))
		var kb_top: float = canvas.y - kb_units
		var r := ip.get_global_rect()
		print("      keyboard sim %.0fpx -> %.0f units, keyboard top y=%.0f | field %s"
			% [SIM_KEYBOARD_PX, kb_units, kb_top, str(r)])
		if r.end.y <= kb_top - 1.0:
			_pass("IP input fully above the simulated keyboard (bottom %.0f < top %.0f)"
				% [r.end.y, kb_top])
		else:
			_fail("IP input still covered (bottom %.0f >= keyboard top %.0f)"
				% [r.end.y, kb_top])
		var join_panel: Control = inst.get_node_or_null("MarginContainer/VBoxContainer/JoinPanel")
		if join_panel:
			_check_inside(join_panel, "JoinPanel (keyboard open)")
		inst._debug_keyboard_height_px = -1.0
		inst._update_keyboard_pan()
		await _frames(5)
		if is_equal_approx(inst._keyboard_pan_units, 0.0) and inst.margin_root.offset_top == 0.0:
			_pass("pan restores to zero when the keyboard closes")
		else:
			_fail("pan did not restore (pan=%.1f offset_top=%.1f)"
				% [inst._keyboard_pan_units, inst.margin_root.offset_top])
		inst._show_mode_selection()
		await _frames(3)

	# ── waiting room ──
	inst._show_waiting_panel()
	await _frames(10)
	var status: Control = inst.get_node_or_null("MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/StatusLabel")
	var scroll: ScrollContainer = inst.get_node_or_null("MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll")
	var disc: Control = inst.get_node_or_null("MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer/DisconnectButton")
	if status:
		var sr := status.get_global_rect()
		print("      StatusLabel global y=%.0f h=%.0f" % [sr.position.y, sr.size.y])
		if sr.position.y >= -1.0 and sr.size.y > 0.0:
			_pass("waiting-room top text on-screen and visible")
		else:
			_fail("waiting-room top text clipped (y=%.0f h=%.0f)" % [sr.position.y, sr.size.y])
	if scroll and disc:
		var max_scroll: float = scroll.get_v_scroll_bar().max_value
		print("      WaitingScroll scroll max=%.0f" % max_scroll)
		if max_scroll > 0.0:
			scroll.scroll_vertical = int(max_scroll)
			await _frames(10)
			_check_inside(disc, "DisconnectButton after scroll to bottom")
		else:
			_check_inside(disc, "DisconnectButton (column fits, no scroll needed)")
	# Provenance for the stale VerifyWaitingRoomFit reproduction control:
	# with the scroll reverted, is there still overflow to reproduce? Printed,
	# not asserted.
	if scroll:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		await _frames(10)
		var mc: Control = inst.get_node_or_null("MarginContainer")
		var col: Control = inst.get_node_or_null("MarginContainer/VBoxContainer/WaitingPanel/WaitingScroll/VBoxContainer")
		if mc and col:
			print("      [revert-diag] column min h=%.0f | screen content h=%.0f | screen top y=%.0f | grow_v=%d"
				% [col.get_combined_minimum_size().y, mc.size.y,
					mc.get_global_rect().position.y, mc.grow_vertical])
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		await _frames(3)

	inst.queue_free()
	await _frames(3)
