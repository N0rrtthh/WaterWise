extends Node

## Do the in-round delays keep counting while the game is paused?
##
## THE DEFECT UNDER TEST
##   SceneTree.create_timer(time_sec, process_always = true, ...) - the second
##   parameter DEFAULTS TO TRUE, meaning "keep processing even when the tree is
##   paused". Every in-round delay in the minigames is written as the bare
##       await get_tree().create_timer(0.4).timeout
##   so all of them are pause-blind. A scan of scenes/minigames/*.gd found 27 such
##   sites across 17 games and not one of them opts out.
##
##   The rest of the round is NOT pause-blind: MiniGameBase._on_pause_pressed()
##   (:1684) sets get_tree().paused = true, which freezes _process, the round Timer
##   node and every tween. So a pause stops the game but not its delays.
##
## WHAT THE PLAYER SEES
##   Tap the right answer, then pause. Behind the pause overlay the 0.4s respawn
##   fires and the next target spawns; resume and it is already there, mid-frame,
##   with its spawn animation over. On the quota-completing tap it is worse:
##   SpotTheSpeck:244 is `await create_timer(0.4); end_game(true)` with no guard, so
##   end_game() - lives, droplets, the score page, and one sample into the
##   adaptive-difficulty window - all run while the game is paused, and the score
##   page comes up underneath the still-visible pause menu.
##
## WHY THIS IS NOT AN EDGE CASE ON ANDROID
##   MobileUIManager._on_app_focus_lost() sets get_tree().paused = true when the app
##   is backgrounded (autoload/MobileUIManager.gd:1339). A notification pulled down
##   during the 0.4s window is enough.
##
## WHAT IS DELIBERATELY LEFT PAUSE-BLIND
##   Delays that are not part of play: the post-round hand-off in
##   RainwaterHarvesting._show_team_results() ends in a scene change, and the score
##   page / intro / cutscene waits in MiniGameBase are outside the window where the
##   pause button exists. Check [8] allowlists them BY ENCLOSING FUNCTION rather than
##   by line number, so it keeps working when the files move.
##
## Usage:
##   godot --headless --path . res://tools/VerifyPausedDelay.tscn

const SPECK: String = "res://scenes/minigames/SpotTheSpeck.tscn"
const MEMORY: String = "res://scenes/minigames/WaterMemory.tscn"
const SHELL_GAME: String = "res://scenes/minigames/FixLeak.tscn"
## Every directory whose scripts run inside a single-player round.
## scripts/minigames_v2 holds MicrogameShell (-> MiniGameBase) and the four v2
## rebuilds that FixLeak/CatchTheRain/GreywaterSorter/BucketBrigade actually run;
## the FIX-42 sweep looked only at scenes/minigames and so never saw the verb-flash
## hold in the shell. scripts/multiplayer is deliberately absent -- those delays are
## pause-blind by an earlier decision, because a paused client must not stall the
## host's round.
const SCAN_DIRS: Array = ["res://scenes/minigames", "res://scripts/minigames_v2"]
## Line-1 banner marking a script that no scene loads (see VerifyScriptOwnership).
const ORPHAN_MARK: String = "## ORPHAN:"

## Raw get_tree().create_timer() is legitimate in these - see the header.
const POST_ROUND_FUNCS: Array = ["_show_team_results"]

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


## Frames that leave the pause state alone - the pause IS the thing under test.
func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


## Real seconds of wall clock, with the tree free to stay paused. process_frame
## still fires while paused, so this is a genuine wait with the game frozen.
func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


## A live round, started through the real tap-to-start prompt.
func _live_round(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await _frames(30)
	for _attempt in range(120):
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
		if inst.get("game_active") == true:
			break
	return inst


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== DO IN-ROUND DELAYS KEEP COUNTING WHILE PAUSED? ===")
	print("")

	# ── [1..3] The mechanism itself, before any game is involved. ──
	# If create_timer's default really is process_always = true, the first of these two
	# fires while the tree is paused and the second does not. Everything below is a
	# consequence of that one default.
	get_tree().paused = true
	var blind: Dictionary = {"fired": false}
	var aware: Dictionary = {"fired": false}
	get_tree().create_timer(0.15).timeout.connect(func() -> void: blind["fired"] = true)
	get_tree().create_timer(0.15, false).timeout.connect(func() -> void: aware["fired"] = true)
	await _wait_real(0.9)
	_check("[1] a bare create_timer() FIRES while the tree is paused",
		blind["fired"] == true,
		"this is the default nobody asked for: process_always = true")
	_check("[2] create_timer(t, false) does not fire while the tree is paused",
		aware["fired"] == false,
		"pause-aware form held for 0.9s of real time")
	get_tree().paused = false
	await _wait_real(0.6)
	_check("[3] the pause-aware timer is only deferred, not lost",
		aware["fired"] == true,
		"fired after the resume")

	# ── [4..5] The respawn path: SpotTheSpeck, correct answer, then pause. ──
	var g: Node = await _live_round(SPECK)
	if g.get("current_glass") == null:
		g.call("_spawn_glass")
		await _frames(2)
	var ok_setup: bool = g.get("current_glass") != null
	if not ok_setup:
		_check("[4] setup: a glass is on screen", false, "could not get a glass to judge")
	else:
		# Keep the quota out of reach so this is the respawn path, not the win path.
		g.set("target_correct", 99)
		g.set("correct_choices", 0)
		var dirty: bool = bool(g.get("current_glass").get_meta("dirty"))
		g.call("_judge_glass", dirty)  # correct answer -> arms the respawn delay
		get_tree().paused = true       # same frame: the whole window is paused
		await _wait_real(1.2)
		_check("[4] no target respawns behind the pause overlay",
			g.get("current_glass") == null,
			"current_glass after 1.2s paused: %s" % str(g.get("current_glass")))
		get_tree().paused = false
		await _wait_real(0.9)
		_check("[5] the respawn still happens once play resumes",
			g.get("current_glass") != null,
			"current_glass after the resume: %s" % str(g.get("current_glass")))
	g.queue_free()
	await _frames(4)

	# ── [6] The win path: end_game() itself must not run while paused. ──
	# SpotTheSpeck:244 is `await create_timer(0.4); end_game(true)` on the
	# quota-completing tap. end_game() banks score, spends a life on failure, feeds the
	# adaptive-difficulty window and raises the score page - none of which may happen
	# with the pause menu still up.
	var g2: Node = await _live_round(SPECK)
	if g2.get("current_glass") == null:
		g2.call("_spawn_glass")
		await _frames(2)
	if g2.get("current_glass") != null:
		g2.set("target_correct", 2)
		g2.set("correct_choices", 1)  # this tap completes the quota
		var dirty2: bool = bool(g2.get("current_glass").get_meta("dirty"))
		g2.call("_judge_glass", dirty2)
		get_tree().paused = true
		await _wait_real(1.2)
		_check("[6] end_game() does not fire while the game is paused",
			g2.get("_round_ended") == false and g2.get("game_active") == true,
			"_round_ended=%s game_active=%s after 1.2s paused"
				% [str(g2.get("_round_ended")), str(g2.get("game_active"))])
		get_tree().paused = false
		await _wait_real(1.0)
		await _frames(4)
		_check("[6b] and it does fire once play resumes",
			g2.get("_round_ended") == true,
			"_round_ended=%s after the resume" % str(g2.get("_round_ended")))
	else:
		_check("[6] setup: a glass is on screen", false, "could not get a glass to judge")
	g2.queue_free()
	await _frames(4)

	# ── [7] WaterMemory: a resolve that lands after the round is over. ──
	# _on_card_pressed() arms _check_match() 0.6s later, and _check_match() has no
	# game_active guard - so a round that ends inside that window (timer expiry, a lost
	# life, the player quitting) still gets a pair scored and a record_action(true) fed
	# into the difficulty window after the fact.
	var m: Node = await _live_round(MEMORY)
	var cards: Array = m.get("cards")
	var pair: Array = []
	for a in cards:
		for b in cards:
			if a != b and str(a.get_meta("emoji", "")) == str(b.get_meta("emoji", "?")):
				pair = [a, b]
				break
		if not pair.is_empty():
			break
	if pair.size() == 2:
		m.call("_on_card_pressed", pair[0])
		m.call("_on_card_pressed", pair[1])  # arms the 0.6s resolve
		var before: int = int(m.get("pairs_found"))
		m.call("end_game", false)            # the round ends inside the window
		await _wait_real(1.2)
		await _frames(4)
		_check("[7] a match resolving after the round ended does not score",
			int(m.get("pairs_found")) == before,
			"pairs_found %d -> %d across the round end"
				% [before, int(m.get("pairs_found"))])
	else:
		_check("[7] setup: two cards share an emoji", false,
			"found %d cards, no pair" % cards.size())
	m.queue_free()
	await _frames(4)

	# ── [8] Nothing in-round is still pause-blind. ──
	var raw: Array = []
	for scan_dir in SCAN_DIRS:
		var dir: DirAccess = DirAccess.open(scan_dir)
		if dir == null:
			_check("[8] %s is readable" % scan_dir, false, "cannot open it")
			continue
		for f in dir.get_files():
			if not f.ends_with(".gd"):
				continue
			var path: String = "%s/%s" % [scan_dir, f]
			var txt: String = FileAccess.get_file_as_string(path)
			# An orphan cannot run, so a pause-blind delay inside one is not a live
			# defect -- but it has to SAY it is an orphan, or the next person edits it
			# believing they are fixing the game (which is exactly what happened with
			# scenes/minigames/FixLeak.gd). VerifyScriptOwnership enforces the banner;
			# this check only honours it.
			if txt.contains(ORPHAN_MARK):
				continue
			var fn: String = ""
			var ln: int = 0
			for line in txt.split("\n"):
				ln += 1
				var t: String = line.strip_edges()
				if t.begins_with("func ") and t.find("(") > 5:
					fn = t.substr(5, t.find("(") - 5)
				if t.begins_with("#"):
					continue
				if not line.contains("get_tree().create_timer("):
					continue
				# The explicit pause-aware form is the point of the fix, not a violation.
				# RainwaterHarvesting extends Node2D and has no round_delay(), so it spells
				# the second argument out instead; that is still correct.
				if line.contains(", false"):
					continue
				if POST_ROUND_FUNCS.has(fn):
					continue
				raw.append("%s:%d (%s)" % [f, ln, fn])
	_check("[8] no in-round delay is left pause-blind",
		raw.is_empty(),
		"%d pause-blind site(s): %s"
			% [raw.size(), ", ".join(raw) if raw.size() <= 6
				else ", ".join(raw.slice(0, 6)) + ", ..."])

	# ── [9] The shared helper exists and is itself pause-aware. ──
	# One helper on MiniGameBase is what makes [8] enforceable: 27 call sites cannot each
	# be trusted to remember a positional bool.
	var base: Object = load("res://scripts/MiniGameBase.gd").new()
	if not base.has_method("round_delay"):
		_check("[9] MiniGameBase.round_delay() exists", false,
			"no shared pause-aware delay - each call site is on its own")
	else:
		get_tree().root.add_child(base)
		await _frames(2)
		var helper: Dictionary = {"fired": false}
		get_tree().paused = true
		base.call("round_delay", 0.15).connect(func() -> void: helper["fired"] = true)
		await _wait_real(0.9)
		_check("[9] round_delay() holds while the tree is paused",
			helper["fired"] == false, "held for 0.9s of real time")
		get_tree().paused = false
		await _wait_real(0.6)
		_check("[9b] round_delay() fires on resume",
			helper["fired"] == true, "deferred, not dropped")
		base.queue_free()
		await _frames(2)

	# ── [10] The one-second verb card cannot be consumed by a pause. ──
	# MicrogameShell.start_game() shows the DWTD-style verb word, holds it, then arms
	# the round. The hold used to be a bare create_timer(hold, true, false, true), so a
	# pause during the card (MobileUIManager pauses the tree on focus loss) ran the hold
	# out behind the overlay: on resume the player got the 0.1s fade and nothing else,
	# and the "instructions flash for exactly one second" pillar was silently skipped.
	# The card stays on screen either way, so `visible` is not the discriminator —
	# UNPAUSED time is. Measured here as the delay between the resume and game_active.
	var shell: Node = (load(SHELL_GAME) as PackedScene).instantiate()
	get_tree().root.add_child(shell)
	await _frames(30)
	var overlay: Node = shell.get("shell_verb_overlay")
	if overlay == null:
		_check("[10] setup: %s runs MicrogameShell" % SHELL_GAME, false,
			"no shell_verb_overlay - wrong script family, nothing to test")
	else:
		# Tap until the card appears; the loop ends on the frame the flash begins, which
		# is what makes the pause below land inside the hold.
		var t_card: int = 0
		for _attempt in range(180):
			var d := InputEventMouseButton.new()
			d.button_index = MOUSE_BUTTON_LEFT
			d.pressed = true
			d.position = get_tree().root.get_visible_rect().size * 0.5
			Input.parse_input_event(d)
			await get_tree().process_frame
			var u := InputEventMouseButton.new()
			u.button_index = MOUSE_BUTTON_LEFT
			u.pressed = false
			u.position = d.position
			Input.parse_input_event(u)
			await get_tree().process_frame
			if overlay.visible:
				t_card = Time.get_ticks_msec()
				break
		if t_card == 0:
			_check("[10] setup: the verb card comes up on tap", false,
				"overlay never became visible")
		else:
			get_tree().paused = true
			var shown_before: int = Time.get_ticks_msec() - t_card
			await _wait_real(1.2)
			_check("[10] the round does not arm itself behind the pause",
				shell.get("game_active") == false and overlay.visible,
				"card held, game_active=%s after 1.2s paused"
					% str(shell.get("game_active")))
			var t_resume: int = Time.get_ticks_msec()
			get_tree().paused = false
			for _i in range(400):
				await get_tree().process_frame
				if shell.get("game_active") == true:
					break
			var after: int = Time.get_ticks_msec() - t_resume
			_check("[10b] the rest of the hold plays AFTER the resume",
				after >= 450,
				"%d ms shown before the pause, %d ms of card left after it (fade alone is ~100 ms)"
					% [shown_before, after])
			_check("[10c] the card still totals about one unpaused second",
				shown_before + after >= 850,
				"%d ms of unpaused card across a 1.2s pause (VERB_FLASH_SEC = 1.0)"
					% [shown_before + after])
	get_tree().paused = false
	shell.queue_free()
	await _frames(4)

	get_tree().paused = false
	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	print("")
	get_tree().quit(1 if _fail > 0 else 0)
