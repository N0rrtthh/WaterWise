extends Node

## ═══════════════════════════════════════════════════════════════════
## QUOTA OVERSHOOT VERIFICATION (headless, thesis-auditable)
## ═══════════════════════════════════════════════════════════════════
## A quota minigame ends when the player reaches a target count. If the condition
## that detects "one unit done" is a level test rather than an edge, and the
## function it calls awaits before the level is reset, then _process re-enters
## that function on every frame of the await. Each re-entry counts another unit
## and files another record_action(true) — and record_action is what feeds the
## accuracy window the adaptive-difficulty algorithm reads, so the corruption
## does not stay inside the minigame.
##
## ScrubToSave had exactly that shape. dirt_level is only reset by _spawn_dish(),
## so after the last dish `dirt_level <= 0` stayed true across the 0.3s await
## before end_game(true). The 480s full-pool soak caught it the first time the
## game was ever reached: 43 "end_game(true) ignored — round already ended"
## warnings from one round, and Score:2185 / Acc:100% where every other quota
## game in the same run scored 20-605, because record_action's combo bonus
## compounded across the phantom successes.
##
## This harness drives the real scene in the real tree — no stubs, no copy of the
## game's logic — by forcing dirt_level to 0 the way a finished scrub would, then
## holding for longer than the longest await inside _dish_cleaned() so a re-entry
## has time to happen. It asserts the counters that the adaptive-difficulty
## algorithm actually consumes.
##
## The second check covers the same defect reached from the other direction: an
## `await` written directly inside `_process`. PlugTheLeak parked its pipe loop on
## a 0.5-1.5s respawn timer, so overlapping instances of _process shared the same
## members. That one is caught by proving _process reaches its own last line in a
## single synchronous pass.
##
## Run:
##   Godot --headless --path <project> res://tools/VerifyQuotaOvershoot.tscn
## Exit code 0 = all passed, 1 = at least one failure.
## ═══════════════════════════════════════════════════════════════════

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE QUOTA OVERSHOOT VERIFICATION")
	print("═══════════════════════════════════════════════════════════")

	await _verify_scrub_to_save()
	await _verify_plug_the_leak()

	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		for f in _failures:
			print("    ✗ %s" % f)
	print("═══════════════════════════════════════════════════════════")
	print("")

	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		var msg := label if detail == "" else "%s — %s" % [label, detail]
		_failures.append(msg)
		print("  ✗ %s  %s" % [label, detail])


## Dismiss the "tap to start" overlay and wait for the round to go live.
##
## MiniGameBase._ready() parks in _wait_for_input(), which only self-dismisses
## when AutoPlayManager is driving. Enabling autoplay here would also hand scene
## navigation to AutoNav, which frees the game node out from under the harness, so
## the prompt is dismissed the way a player dismisses it.
##
## It has to be the mouse, not ui_accept. _wait_for_input() breaks on
## is_action_just_pressed("ui_accept"), true for exactly the frame the press
## arrives, and the game's coroutine parked on process_frame before the harness's
## did — so it resumes first every frame and always polls before the harness has
## pressed anything. The mouse branch compares level state
## (`mouse_down and not mouse_was_down`), which survives across frames, so a held
## button is seen whenever the game next looks.
func _start_round(game: Node, label: String) -> bool:
	await get_tree().process_frame
	await get_tree().process_frame

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)

	var waited: float = 0.0
	while not game.game_active and waited < 10.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame

	_check("%s: round became active" % label, game.game_active,
		"still inactive after %.1fs" % waited)
	return game.game_active


## Hold for `seconds` of real frames.
func _hold(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _verify_scrub_to_save() -> void:
	print("")
	print("── ScrubToSave: quota is not overshot ──")

	var scene := load("res://scenes/minigames/ScrubToSave.tscn") as PackedScene
	if scene == null:
		_check("ScrubToSave.tscn loads", false, "load() returned null")
		return

	var game: Node = scene.instantiate()
	add_child(game)
	if not await _start_round(game, "ScrubToSave"):
		game.queue_free()
		return

	var target: int = game.target_dishes
	_check("target_dishes is set", target > 0, "got %d" % target)

	# Finish each dish the way a completed scrub does: drive dirt to zero and let
	# the game's own _process notice. Then hold past the 0.5s respawn await (and
	# past the 0.3s end-of-round await on the final dish), which is the window the
	# re-entry bug lived in.
	for dish in range(target):
		game.dirt_level = 0.0
		await _hold(0.8)
		print("    dish %d/%d → dishes_cleaned=%d correct_actions=%d combo=%d score=%d"
			% [dish + 1, target, game.dishes_cleaned, game.correct_actions,
				game.max_combo, game.current_score])

	# One extra hold so any queued re-entry has resolved before we read counters.
	await _hold(0.6)

	_check("dishes_cleaned equals the quota exactly",
		game.dishes_cleaned == target,
		"got %d, expected %d" % [game.dishes_cleaned, target])

	# The counters below are the ones AdaptiveDifficulty consumes as accuracy.
	_check("correct_actions equals the quota exactly",
		game.correct_actions == target,
		"got %d phantom successes in the accuracy window, expected %d"
			% [game.correct_actions, target])
	_check("total_actions equals the quota exactly",
		game.total_actions == target,
		"got %d, expected %d" % [game.total_actions, target])
	_check("max_combo equals the quota exactly",
		game.max_combo == target,
		"got %d, expected %d" % [game.max_combo, target])

	# record_action(true) awards 10 + floor(streak/3)*5, so the honest ceiling for
	# a perfect run is computable. 2185 was logged before the fix.
	var expected_actions_score: int = 0
	for streak in range(1, target + 1):
		expected_actions_score += 10 + int(floor(float(streak) / 3.0)) * 5
	_check("score is not inflated beyond a perfect run",
		game.current_score <= expected_actions_score + _completion_bonus_headroom(),
		"got %d, a perfect run scores %d from actions"
			% [game.current_score, expected_actions_score])

	game.queue_free()
	await get_tree().process_frame


## Slack for whatever end_game() adds on top of the per-action score.
##
## The assertion above is a ceiling test, not an equality test: the base class may
## add a time or completion bonus and that is legitimate. 500 is far above any
## such bonus and far below the 2185 the bug produced, so the check still fails
## loudly on a regression without pinning the harness to the bonus formula.
func _completion_bonus_headroom() -> int:
	return 500


## Count pipes currently flagged as leaking.
func _count_leaks(game: Node) -> int:
	var n: int = 0
	for pipe in game.pipes:
		if is_instance_valid(pipe) and bool(pipe.get_meta("leaking")):
			n += 1
	return n


## Block until _on_game_start()'s 1s delay produces the first leak.
func _await_first_leak(game: Node, timeout: float = 6.0) -> Node2D:
	var waited: float = 0.0
	while waited < timeout:
		for pipe in game.pipes:
			if is_instance_valid(pipe) and bool(pipe.get_meta("leaking")):
				return pipe
		await get_tree().process_frame
		waited += get_process_delta_time()
	return null


## PlugTheLeak: _process must finish its pipe loop in one pass.
##
## PlugTheLeak awaited a 0.5-1.5s respawn timer from inside `for pipe in pipes`,
## so that call sat parked mid-iteration while fresh _process calls kept starting
## from the top — several instances of the same function overlapping on the same
## members. When the parked one resumed it finished its loop with the delta,
## is_holding and hold_pos it had read a second earlier, adding a stale frame of
## wasted water to every pipe after the one it plugged and re-running the
## round-failure test at the bottom.
##
## The discriminating assertion is the sentinel below. The tail of _process (the
## WasteLabel write) sits after the await, so if the function yields on plug
## completion the sentinel survives the call; if it runs straight through, the
## sentinel is overwritten. The rest of the checks would pass either way and are
## here because FIX 44 replaced a working respawn path with a new one.
func _verify_plug_the_leak() -> void:
	print("")
	print("── PlugTheLeak: _process does not yield mid-loop ──")

	var scene := load("res://scenes/minigames/PlugTheLeak.tscn") as PackedScene
	if scene == null:
		_check("PlugTheLeak.tscn loads", false, "load() returned null")
		return

	var game: Node = scene.instantiate()
	add_child(game)
	if not await _start_round(game, "PlugTheLeak"):
		game.queue_free()
		return
	var leaking: Node2D = await _await_first_leak(game)
	_check("a leak starts on its own", leaking != null,
		"no pipe reported leaking within 6s")
	if leaking == null:
		game.queue_free()
		return

	# Hold on the leaking pipe through the touch path a phone actually uses.
	# water_wasted is sampled at the moment the finger lands rather than assumed
	# to be 0: the leak may have run for the single frame between the respawn
	# timer firing and this coroutine resuming.
	var waste_at_grab: float = game.water_wasted
	game._touch_index = 0
	game._touch_position = leaking.position
	game._touch_active = true
	await _hold(0.5)

	_check("plug progress accumulates while the pipe is held",
		float(leaking.get_meta("plug_progress")) > 0.0,
		"plug_progress=%.1f" % float(leaking.get_meta("plug_progress")))
	_check("no further water is wasted while the leak is held",
		game.water_wasted - waste_at_grab < 0.01,
		"wasted %.2f more" % (game.water_wasted - waste_at_grab))
	# Drive plug_progress to the completion boundary and run exactly one _process
	# by hand, with the engine's own call switched off so nothing else can advance
	# the state in between. 99.9 rather than 100 so the game still has to add its
	# own plug_rate * delta increment to cross the line — the same way
	# _verify_scrub_to_save() sets dirt_level to 0 and lets the game notice.
	game.set_process(false)
	leaking.set_meta("plug_progress", 99.9)
	var sentinel := "<_process never reached its tail>"
	game.get_node("WasteLabel").text = sentinel
	var before_correct: int = game.correct_actions
	var before_total: int = game.total_actions
	game._process(0.1)
	var reached_tail: bool = game.get_node("WasteLabel").text != sentinel
	var counted: int = game.correct_actions - before_correct
	game.set_process(true)

	_check("the plug registered in that single pass", counted == 1,
		"record_action fired %d time(s)" % counted)
	_check("the pipe stopped leaking", not bool(leaking.get_meta("leaking")))
	_check("_process reached its tail without yielding", reached_tail,
		"an await parked the pipe loop mid-iteration, so the WasteLabel write"
		+ " and the round-failure test below it were skipped for that frame")

	# Let go and ride out the full 0.5-1.5s respawn window.
	game._touch_active = false
	game._touch_index = -1
	await _hold(2.2)

	_check("the plug is still counted exactly once",
		game.correct_actions == before_correct + 1,
		"got %d, expected %d" % [game.correct_actions, before_correct + 1])
	_check("total_actions matches the single plug",
		game.total_actions == before_total + 1,
		"got %d, expected %d" % [game.total_actions, before_total + 1])
	_check("a replacement leak appeared", _count_leaks(game) == 1,
		"got %d leaking pipes" % _count_leaks(game))
	_check("the round is still live", game.game_active,
		"round ended early — water_wasted=%.1f / %.1f"
			% [game.water_wasted, game.max_water_waste])

	game.queue_free()
	await get_tree().process_frame
