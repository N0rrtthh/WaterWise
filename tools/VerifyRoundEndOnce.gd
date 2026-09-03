extends Node

## Can one round be recorded to the algorithm more than once?
##
## THE ASYMMETRY UNDER TEST
##   MiniGameBase has TWO call sites for GameManager.complete_minigame():
##     - end_game()          scripts/MiniGameBase.gd:695   guarded by _round_ended
##     - _on_exit_pressed()  scripts/MiniGameBase.gd:1598   NOT guarded at all
##   _on_exit_pressed() neither checks _round_ended nor sets it, so the guard that
##   makes end_game() exactly-once does not cover the quit path in either direction.
##
## WHY THAT MATTERS RATHER THAN BEING TIDINESS
##   complete_minigame() is the algorithm's only input. Every extra call appends a
##   sample to AdaptiveDifficulty.performance_window (window_size 5, so two extra
##   samples displace 40% of the evidence a difficulty decision is made from),
##   appends a round to GameManager.round_scores, spends a life, banks droplets and
##   writes a SessionLogger row. A round recorded twice is not a cosmetic duplicate:
##   it is fabricated performance data in a thesis measurement.
##
## HOW A SECOND CALL IS REACHED IN PLAY
##   _on_exit_pressed() clears game_active and stops _game_timer, then awaits
##   _show_quit_tally_screen() for several seconds. Of the 66 end_game() call sites
##   across the minigames, 2 are gated on game_active - so a pending await or an
##   already-queued signal in the derived game resumes inside that window and calls
##   end_game(), which finds _round_ended still false and records the round again.
##
## HONESTY: no Android device and no human hand are involved. Each case calls the
## same methods a Button press and a Back gesture route to, on a real minigame scene
## instantiated from its own .tscn, and counts real GameManager/AdaptiveDifficulty
## state. Nothing is stubbed.
##
## Usage:
##   godot --headless --path . res://tools/VerifyRoundEndOnce.tscn

const SCENE: String = "res://scenes/minigames/CatchTheRain.tscn"

var _pass: int = 0
var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


func _frames(n: int) -> void:
	for _i in range(n):
		if get_tree().paused:
			get_tree().paused = false
		await get_tree().process_frame


## Fresh GameManager + AdaptiveDifficulty state, so a case cannot inherit rounds
## another case recorded. This is fixture setup, not the thing under test.
func _reset() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if gm:
		gm.start_new_session()
	if ad and "performance_window" in ad:
		ad.performance_window.clear()


## How many times the round has been recorded, measured three independent ways so a
## single field being reset by something else cannot make a defect invisible.
func _recorded() -> Dictionary:
	var gm := get_node_or_null("/root/GameManager")
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	return {
		"rounds": gm.round_scores.size() if gm else -1,
		"played": int(gm.minigames_played_this_session) if gm else -1,
		"window": ad.performance_window.size() if (ad and "performance_window" in ad) else -1,
	}


func _fmt(r: Dictionary) -> String:
	return "round_scores=%d played=%d ad_window=%d" % [r["rounds"], r["played"], r["window"]]


## A live minigame mid-round: instantiated from its real .tscn, in the tree, with
## _ready() and the intro overlay finished so game_active is true.
##
## start_game() is not forced: MiniGameBase runs its own intro and sets game_active
## itself, and forcing it would test a state the player never reaches. Instead the
## probe waits for game_active and reports if it never arrives, rather than pressing
## on and measuring a scene that was never playing.
func _live_round() -> Node:
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	# The round does not start on its own, and that is correct: MiniGameBase awaits
	# _wait_for_input() at :221 for a real tap-to-start before calling start_game().
	# The first version of this probe waited 240 frames for game_active and reported
	# a fixture failure - which was this harness expecting the product to skip its
	# own prompt, not a defect.
	#
	# So a real press is delivered through the real input pipeline with
	# Input.parse_input_event, which is what _wait_for_input() polls
	# (Input.is_mouse_button_pressed / the "touch" action). Nothing about the intro is
	# bypassed.
	for _i in range(30):
		await get_tree().process_frame
		if get_tree().paused:
			get_tree().paused = false
	for attempt in range(90):
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = get_tree().root.get_visible_rect().size * 0.5
		Input.parse_input_event(down)
		await get_tree().process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = down.position
		Input.parse_input_event(up)
		await get_tree().process_frame
		if get_tree().paused:
			get_tree().paused = false
		if inst.get("game_active") == true:
			print("          (round went live after %d simulated taps)" % (attempt + 1))
			break
	return inst


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== ROUND RECORDED EXACTLY ONCE? ===")
	print("  scene under test: %s" % SCENE)
	print("")

	# ---- CASE 1: end_game() twice -------------------------------------------
	# The baseline. _round_ended exists for this, and it is asserted rather than
	# taken on trust, because every later case is only meaningful if the guard it
	# is compared against actually works.
	_reset()
	var g1: Node = await _live_round()
	_check("[1] scene reached a live round (fixture is valid)",
		g1.get("game_active") == true,
		"game_active=%s" % str(g1.get("game_active")))
	var before1: Dictionary = _recorded()
	g1.end_game(true)
	await _frames(2)
	var mid1: Dictionary = _recorded()
	g1.end_game(true)
	await _frames(2)
	var after1: Dictionary = _recorded()
	_check("[1] end_game() records the round once",
		int(mid1["rounds"]) - int(before1["rounds"]) == 1,
		"before %s -> after first call %s" % [_fmt(before1), _fmt(mid1)])
	_check("[1] a second end_game() records nothing more",
		int(after1["rounds"]) == int(mid1["rounds"])
			and int(after1["window"]) == int(mid1["window"]),
		"after second call %s" % _fmt(after1))
	g1.queue_free()
	await _frames(4)

	# ---- CASE 2: quit, then a pending await lands ----------------------------
	# The live path. _on_exit_pressed() records the round and then awaits its quit
	# tally for seconds; anything still pending in the derived game resumes inside
	# that window and calls end_game(), which finds _round_ended false.
	#
	# _on_exit_pressed() is not awaited: it awaits its own tally screen and then
	# navigates, and the point of the case is what happens WHILE that is on screen.
	_reset()
	var g2: Node = await _live_round()
	var before2: Dictionary = _recorded()
	g2._on_exit_pressed()
	await _frames(2)
	var mid2: Dictionary = _recorded()
	_check("[2] quitting mid-round records the round once",
		int(mid2["rounds"]) - int(before2["rounds"]) == 1,
		"before %s -> after quit %s" % [_fmt(before2), _fmt(mid2)])
	g2.end_game(false)
	await _frames(2)
	var after2: Dictionary = _recorded()
	_check("[2] end_game() after a quit does NOT record a second time",
		int(after2["rounds"]) == int(mid2["rounds"])
			and int(after2["window"]) == int(mid2["window"]),
		"after end_game() %s  (_round_ended=%s)"
			% [_fmt(after2), str(g2.get("_round_ended"))])
	g2.queue_free()
	await _frames(4)

	# ---- CASE 3: round ends, then the quit path runs -------------------------
	# The other direction. end_game() hides both pause buttons, and
	# _on_pause_pressed() refuses once game_active is false, so this needs an input
	# that was already queued or a Back gesture routed straight at the exit action.
	# The guard has to hold on the method, because that is what any such route calls.
	_reset()
	var g3: Node = await _live_round()
	var before3: Dictionary = _recorded()
	g3.end_game(true)
	await _frames(2)
	var mid3: Dictionary = _recorded()
	g3._on_exit_pressed()
	await _frames(2)
	var after3: Dictionary = _recorded()
	_check("[3] quitting after the round ended does NOT record a second time",
		int(after3["rounds"]) == int(mid3["rounds"])
			and int(after3["window"]) == int(mid3["window"]),
		"after end_game %s -> after quit %s" % [_fmt(mid3), _fmt(after3)])
	g3.queue_free()
	await _frames(4)

	# ---- CASE 4: the quit button spammed -------------------------------------
	# Input spam, which is the item this harness was opened for. A tap on mobile can
	# repeat before the first press has navigated anywhere, and the exit Button is
	# not disabled when pressed.
	_reset()
	var g4: Node = await _live_round()
	var before4: Dictionary = _recorded()
	g4._on_exit_pressed()
	g4._on_exit_pressed()
	g4._on_exit_pressed()
	await _frames(2)
	var after4: Dictionary = _recorded()
	_check("[4] three quit presses record the round once, not three times",
		int(after4["rounds"]) - int(before4["rounds"]) == 1,
		"before %s -> after 3 presses %s" % [_fmt(before4), _fmt(after4)])
	g4.queue_free()
	await _frames(4)

	# ---- CASE 5: the algorithm window is not padded --------------------------
	# The consequence, stated as a measurement. AdaptiveDifficulty.window_size is 5,
	# so this checks the quantity a difficulty decision is actually made from rather
	# than only the bookkeeping fields above.
	_reset()
	var g5: Node = await _live_round()
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	var w_before: int = ad.performance_window.size() if ad else -1
	g5._on_exit_pressed()
	await _frames(2)
	g5.end_game(false)
	g5._on_exit_pressed()
	await _frames(2)
	var w_after: int = ad.performance_window.size() if ad else -1
	_check("[5] one abandoned round contributes one sample to the rolling window",
		w_after - w_before == 1,
		"window %d -> %d (window_size=%s)"
			% [w_before, w_after, str(ad.window_size) if ad else "?"])
	g5.queue_free()
	await _frames(4)

	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	print("")
	get_tree().quit(1 if _fail > 0 else 0)
