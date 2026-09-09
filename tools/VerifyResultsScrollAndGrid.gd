extends Node

## ── RESULTS-SCREEN SCROLL + SHOP GRID BALANCE PROBE ────────────────────────
##
## Device-evidence follow-up (Moto E5 Plus session 2026-09-06):
##   • FinalScore: content taller than the viewport, TOP SCORES reachable
##     only by scrolling — asserts the scroll actually reaches it.
##   • UnlockablesScreen: item grid bunched left / overflowing right —
##     asserts the grid fits its scroll area and is horizontally balanced
##     on every tab, on both test-device window profiles.
##
## Run (WINDOWED, needs a real window like ProbeUnlockGrid):
##   godot --path . res://tools/VerifyResultsScrollAndGrid.tscn

const PROFILES := [
	{"name": "Moto E5 Plus", "w": 2160, "h": 1080, "diag": 6.0, "cut": {}},
	{"name": "Poco X3", "w": 2400, "h": 1080, "diag": 6.67, "cut": {}},
]
const TABS := ["characters", "minigames", "accessories", "decorations"]

var _fails := 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _pass(msg: String) -> void:
	print("    ✓ " + msg)


func _fail(msg: String) -> void:
	_fails += 1
	print("    ✗ " + msg)


## Frames with the tree kept running: MobileUIManager pauses the whole
## SceneTree when the window loses focus, freezing layout tweens.
func _frames(n: int) -> void:
	for _i in range(n):
		if _tree().paused:
			_tree().paused = false
		await _tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RESULTS SCROLL + SHOP GRID PROBE")
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
		print("  ── %s: window %dx%d, %.2f dpi ──"
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
		print("    canvas %.0fx%.0f | safe-area %s"
			% [canvas.x, canvas.y, str(mui.get_safe_area_margins())])
		await _check_shop(mui)
		await _check_final_score()

	print("")
	print("═══════════════════════════════════════════════════════════")
	if _fails == 0:
		print("  ALL LAYOUT CHECKS PASSED")
	else:
		print("  %d CHECK(S) FAILED" % _fails)
	print("═══════════════════════════════════════════════════════════")
	_tree().quit(1 if _fails > 0 else 0)


func _dpi(d: Dictionary) -> float:
	var w := float(d["w"])
	var h := float(d["h"])
	return sqrt(w * w + h * h) / float(d["diag"])


func _check_shop(mui) -> void:
	var inst = (load("res://scenes/ui/UnlockablesScreen.tscn") as PackedScene).instantiate()
	_tree().root.add_child(inst)
	mui.adapt_scene_for_mobile(inst)
	await _frames(45)
	var panel = inst.get_node_or_null("MainPanel")
	var sc = null
	for n in inst.find_children("*", "ScrollContainer", true, false):
		sc = n
		break
	if sc == null or panel == null:
		_fail("MainPanel/ScrollContainer not found")
		inst.queue_free()
		await _frames(3)
		return
	for tab in TABS:
		inst.current_tab = tab
		await inst._update_display()
		await _frames(10)
		var gc = null
		for n in inst.find_children("*", "GridContainer", true, false):
			if n.visible:
				gc = n
				break
		if gc == null:
			_fail("%s: no visible grid" % tab)
			continue
		var left: float = gc.position.x
		var right: float = sc.size.x - (gc.position.x + gc.size.x)
		var overflow: bool = gc.size.x > sc.size.x + 1.0
		var balanced: bool = absf(left - right) <= 8.0 or gc.size.x >= sc.size.x - 2.0
		print("    [%s] grid %dx%d at x=%.0f | scroll w=%.0f | cols=%d | gaps L=%.0f R=%.0f"
			% [tab, int(gc.size.x), int(gc.size.y), gc.position.x,
				sc.size.x, gc.columns, left, right])
		if overflow:
			_fail("%s: grid overflows its scroll area (%.0f > %.0f)"
				% [tab, gc.size.x, sc.size.x])
		elif not balanced:
			_fail("%s: grid lopsided (left gap %.0f vs right gap %.0f)" % [tab, left, right])
		else:
			_pass("%s: grid fits and is balanced" % tab)
	inst.queue_free()
	await _frames(3)


func _check_final_score() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var sm = get_node_or_null("/root/SaveManager")
	if gm == null or sm == null:
		_fail("GameManager/SaveManager missing")
		return
	# Seed session + leaderboard state (direct var writes; the saved file is
	# not touched and the leaderboard list is restored afterwards).
	var saved_scores: Array = sm.sp_session_scores.duplicate()
	sm.sp_session_scores = [980, 870, 760, 650, 540, 430, 320, 210]
	gm.sandbox_mode = false
	gm.current_game_mode = gm.GameMode.SINGLE_PLAYER
	gm.session_score = 420
	gm.session_lives = 2
	gm.round_scores = [
		{"game": "ToiletTankFix", "score": 90, "accuracy": 1.0, "mistakes": 0, "reaction_time": 4900},
		{"game": "CoverTheDrum", "score": 85, "accuracy": 1.0, "mistakes": 0, "reaction_time": 3200},
		{"game": "QuickShower", "score": 70, "accuracy": 1.0, "mistakes": 0, "reaction_time": 2600},
		{"game": "VegetableBath", "score": 0, "accuracy": 0.0, "mistakes": 0, "reaction_time": 18000},
		{"game": "RiceWashRescue", "score": 0, "accuracy": 0.0, "mistakes": 8, "reaction_time": 500},
		{"game": "CatchTheRain", "score": 0, "accuracy": 0.0, "mistakes": 0, "reaction_time": 15000},
	]
	var inst = (load("res://scenes/ui/FinalScore.tscn") as PackedScene).instantiate()
	_tree().root.add_child(inst)
	await _frames(60)
	var sc = null
	for n in inst.find_children("*", "ScrollContainer", true, false):
		sc = n
		break
	if sc == null:
		_fail("FinalScore: ScrollContainer missing")
		_restore_scores(sm, saved_scores)
		inst.queue_free()
		await _frames(3)
		return
	var vbox = sc.get_child(0)
	var bar = sc.get_v_scroll_bar()
	print("    [FinalScore] content h=%.0f | viewport h=%.0f | scroll max=%.0f"
		% [vbox.size.y, sc.size.y, bar.max_value])
	if vbox.size.y <= sc.size.y + 1.0:
		_fail("FinalScore: content fits without scrolling on this profile")
	else:
		if bar.max_value <= 0.0:
			_fail("FinalScore: content taller than viewport but scrollbar range is 0")
		else:
			_pass("FinalScore: content overflows and is scrollable (max=%.0f)" % bar.max_value)
		sc.scroll_vertical = int(bar.max_value)
		await _frames(15)
		var header = null
		var last = null
		for c in vbox.get_children():
			if c is Label and c.text.to_upper().contains("SCORES"):
				header = c
			last = c
		if header == null:
			_fail("FinalScore: TOP SCORES header not found")
		else:
			var srect: Rect2 = sc.get_global_rect()
			var hrect: Rect2 = header.get_global_rect()
			var lrect: Rect2 = last.get_global_rect()
			print("    [FinalScore] after scroll: header y=%.0f, last row bottom=%.0f, viewport bottom=%.0f"
				% [hrect.position.y, lrect.end.y, srect.end.y])
			if hrect.position.y >= srect.position.y - 1.0 and hrect.position.y < srect.end.y - 10.0:
				_pass("FinalScore: TOP SCORES header visible after scrolling")
			else:
				_fail("FinalScore: TOP SCORES header NOT visible after full scroll")
			if lrect.end.y <= srect.end.y + 4.0:
				_pass("FinalScore: last leaderboard row fully reachable")
			else:
				_fail("FinalScore: last row still cut off (bottom %.0f > %.0f)"
					% [lrect.end.y, srect.end.y])
	inst.queue_free()
	await _frames(3)
	_restore_scores(sm, saved_scores)


func _restore_scores(sm, saved_scores: Array) -> void:
	sm.sp_session_scores = saved_scores
