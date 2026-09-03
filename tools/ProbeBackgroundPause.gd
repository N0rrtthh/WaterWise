extends Node

## Does regaining focus cancel a pause the game took deliberately?
##
## MobileUIManager connects the ROOT WINDOW's focus signals to a background handler
## (autoload/MobileUIManager.gd:201-202) that sets get_tree().paused on the way out and
## clears it on the way back in. The clear is unconditional, and the project has
## fifteen other places that pause the tree on purpose: GameManager.pause_game(),
## NetworkManager._execute_pause(), MiniGameBase's pause menu, the pause handlers in
## all five MP minigames, and MultiplayerGameOver.
##
## So the question this probe answers is whether losing and regaining focus while one
## of those is up resumes the game underneath it. On Android that is an everyday
## gesture: open the pause menu, pull the notification shade down, dismiss it.
##
## Both directions are checked, because a fix that simply stops clearing the pause
## would break the ordinary background case it exists for.
##
## Usage:
##   godot --headless --path . res://tools/ProbeBackgroundPause.tscn

var _failed: int = 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _check(label: String, cond: bool, detail: String) -> void:
	if cond:
		print("  PASS  %-52s %s" % [label, detail])
	else:
		_failed += 1
		print("  FAIL  %-52s %s" % [label, detail])


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== PROBE: BACKGROUND PAUSE vs DELIBERATE PAUSE ===")
	var mui := get_node_or_null("/root/MobileUIManager")
	var gm := get_node_or_null("/root/GameManager")
	if mui == null or gm == null:
		print("  FAIL: MobileUIManager or GameManager autoload missing")
		_tree().quit(1)
		return

	# The handlers return early unless is_mobile, so the mobile path has to be on for
	# any of this to be exercised at all.
	mui.debug_mobile_mode = true
	if mui.has_method("_detect_platform"):
		mui._detect_platform()
	_check("mobile path is active (handlers are not no-ops)", bool(mui.is_mobile), "is_mobile=%s" % mui.is_mobile)

	# ── CASE 1: the ordinary background case the handler exists for ──
	_tree().paused = false
	await _frames(2)
	mui._on_app_focus_lost()
	await _frames(2)
	_check("case 1: backgrounding an unpaused game pauses it",
		_tree().paused, "paused=%s" % _tree().paused)
	mui._on_app_focus_gained()
	await _frames(2)
	_check("case 1: returning to foreground resumes it",
		not _tree().paused, "paused=%s" % _tree().paused)

	# ── CASE 2: a deliberate pause is already up ──
	# GameManager.pause_game() is the single-player pause menu path.
	gm.pause_game()
	await _frames(2)
	var pause_took: bool = _tree().paused
	_check("case 2: GameManager.pause_game() paused the tree",
		pause_took, "paused=%s" % _tree().paused)
	mui._on_app_focus_lost()
	await _frames(2)
	_check("case 2: still paused after backgrounding",
		_tree().paused, "paused=%s" % _tree().paused)
	mui._on_app_focus_gained()
	await _frames(2)
	# THE DEFECT. A pause menu is on screen; the tree must stay paused.
	_check("case 2: DELIBERATE pause survives the focus round-trip",
		_tree().paused, "paused=%s (expected true - a pause menu is up)" % _tree().paused)
	_tree().paused = false

	# ── CASE 3: the multiplayer game-over screen, which also pauses ──
	# Same shape as case 2 but reached from MultiplayerGameOver.gd:47, so it is worth
	# checking that the fix is about pause OWNERSHIP and not about one caller.
	_tree().paused = true
	await _frames(2)
	mui._on_app_focus_lost()
	await _frames(2)
	mui._on_app_focus_gained()
	await _frames(2)
	_check("case 3: an externally-set pause survives the round-trip",
		_tree().paused, "paused=%s" % _tree().paused)
	_tree().paused = false

	# ── CASE 4: two backgrounds in a row must not lose ownership ──
	# Android can deliver focus-out twice (shade, then a dialog on top of it) before a
	# single focus-in. If the second call forgot that the first one took the pause, the
	# game would stay frozen forever after returning.
	_tree().paused = false
	await _frames(2)
	mui._on_app_focus_lost()
	mui._on_app_focus_lost()
	await _frames(2)
	mui._on_app_focus_gained()
	await _frames(2)
	_check("case 4: double background then foreground still resumes",
		not _tree().paused, "paused=%s" % _tree().paused)

	print("")
	print("  RESULT: %d failed" % _failed)
	print("")
	_tree().quit(0)
