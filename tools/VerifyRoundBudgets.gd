extends Node

## ═══════════════════════════════════════════════════════════════════
## ROUND BUDGET / QUOTA VERIFICATION (headless, thesis-auditable)
## ═══════════════════════════════════════════════════════════════════
## Three defects found by the 300s SoakUnvisited run and the static audit that
## ran alongside it, each checked against the real scene in the real tree:
##
## 1. DROPLET DASH round length. distance_traveled accrues at
##    obstacle_speed * delta * 0.5, but target_distance was a hardcoded
##    300/500/700. Every difficulty therefore ended at the same ~4.5s mark
##    (soak evidence: Spawn Pacer Window [1.83, 1.322, 4.582, 4.681], four
##    rounds all scoring exactly 100), the timer was decorative, and adaptive
##    difficulty could not change round length at all. The check below computes
##    the round length the difficulty tables imply and asserts the three
##    difficulties actually differ.
##
## 2. TOILET TANK FIX Hard budget. The player must release while water_level is
##    within `tolerance` of target_level, so the window is (2*tolerance)/fill_rate
##    seconds wide — a distance only becomes a duration once divided by the fill
##    rate. Hard shipped 5% at 45%/s: a 0.22s window, narrower than a visual-motor
##    reaction. Its 4-tank quota also needed ~8.2s of an 8.0s round.
##
## 3. VEGETABLE BATH duplicate end_game. Every completion in the soak logged
##    `end_game(true) ignored — round already ended` from VegetableBath.gd:251.
##    total_actions is the discriminator: if the quota branch runs twice it files
##    an extra record_action(true) first, so the count exceeds the quota.
##
## Run:
##   Godot --headless --path <project> res://tools/VerifyRoundBudgets.tscn
## Exit code 0 = all passed, 1 = at least one failure.
## ═══════════════════════════════════════════════════════════════════

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

const DIFFICULTIES: PackedStringArray = ["Easy", "Medium", "Hard"]


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE ROUND BUDGET VERIFICATION")
	print("═══════════════════════════════════════════════════════════")

	await _verify_droplet_dash_pacing()
	await _verify_toilet_tank_budget()
	await _verify_vegetable_bath_quota()

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


## Hold for `seconds` of real frames.
func _hold(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


## Dismiss the "tap to start" overlay and wait for the round to go live.
##
## Mouse rather than ui_accept: MiniGameBase._wait_for_input() breaks on
## is_action_just_pressed("ui_accept"), true for one frame only, and the game's
## coroutine parked on process_frame before this one so it always polls first. The
## mouse branch compares level state (mouse_down and not mouse_was_down), which
## survives across frames.
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


## Instantiate a minigame, force a difficulty, and re-run its difficulty table.
##
## current_difficulty is what _apply_difficulty_settings() switches on, so setting
## it and calling that function again is exactly what the game does when the
## algorithm hands it a new difficulty — no stubbing, and the real per-difficulty
## numbers come back out.
func _tabulate(scene_path: String, label: String) -> Dictionary:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		_check("%s.tscn loads" % label, false, "load() returned null")
		return {}

	var game: Node = scene.instantiate()
	add_child(game)
	await get_tree().process_frame

	var rows: Dictionary = {}
	for diff in DIFFICULTIES:
		game.current_difficulty = diff
		game._apply_difficulty_settings()
		rows[diff] = {
			"game_duration": float(game.game_duration),
			"obstacle_speed": float(game.get("obstacle_speed")) if "obstacle_speed" in game else 0.0,
			"target_distance": float(game.get("target_distance")) if "target_distance" in game else 0.0,
			"fill_rate": float(game.get("fill_rate")) if "fill_rate" in game else 0.0,
			"tolerance": float(game.get("tolerance")) if "tolerance" in game else 0.0,
			"target_tanks": int(game.get("target_tanks")) if "target_tanks" in game else 0,
		}

	game.queue_free()
	await get_tree().process_frame
	return rows


func _verify_droplet_dash_pacing() -> void:
	print("")
	print("── Droplet Dash: the clock means something ──")

	var rows: Dictionary = await _tabulate(
		"res://scenes/minigames/DropletDash.tscn", "DropletDash"
	)
	if rows.is_empty():
		return

	var lengths: Array[float] = []
	for diff in DIFFICULTIES:
		var r: Dictionary = rows[diff]
		# Same arithmetic _process uses: distance_traveled += speed * delta * 0.5.
		var rate: float = r["obstacle_speed"] * 0.5
		var seconds: float = r["target_distance"] / maxf(rate, 0.001)
		var fraction: float = seconds / maxf(r["game_duration"], 0.001)
		lengths.append(seconds)
		print("    %-6s speed=%.0f rate=%.0f px/s target=%.0f → %.1fs of a %.1fs round (%.0f%%)"
			% [diff, r["obstacle_speed"], rate, r["target_distance"], seconds,
				r["game_duration"], fraction * 100.0])
		_check("%s: a clean run uses most of its clock" % diff,
			fraction >= 0.6 and fraction <= 1.0,
			"uses %.0f%% of the %.1fs round (%.1fs)"
				% [fraction * 100.0, r["game_duration"], seconds])

	# The defect's signature was three difficulties collapsing onto one round
	# length. Any two differing by under a second means difficulty is decorative.
	_check("difficulties produce different round lengths",
		absf(lengths[0] - lengths[1]) > 1.0 and absf(lengths[1] - lengths[2]) > 1.0,
		"Easy %.1fs / Medium %.1fs / Hard %.1fs" % [lengths[0], lengths[1], lengths[2]])
	_check("harder difficulty is not a longer round",
		lengths[0] > lengths[1] and lengths[1] > lengths[2],
		"Easy %.1fs / Medium %.1fs / Hard %.1fs" % [lengths[0], lengths[1], lengths[2]])


func _verify_toilet_tank_budget() -> void:
	print("")
	print("── Toilet Tank Fix: the quota fits the clock ──")

	var rows: Dictionary = await _tabulate(
		"res://scenes/minigames/ToiletTankFix.tscn", "ToiletTankFix"
	)
	if rows.is_empty():
		return

	# Mirrors ToiletTankFix's own constants; kept local so the harness fails if the
	# game quietly drops the floors rather than agreeing with itself.
	var avg_target: float = 65.0
	var min_window: float = 0.4
	var slop: float = 0.2

	for diff in DIFFICULTIES:
		var r: Dictionary = rows[diff]
		var window: float = (2.0 * r["tolerance"]) / maxf(r["fill_rate"], 0.001)
		var per_tank: float = avg_target / maxf(r["fill_rate"], 0.001) + slop
		var work: float = float(r["target_tanks"]) * per_tank
		var fraction: float = work / maxf(r["game_duration"], 0.001)
		print("    %-6s %d tanks, fill=%.0f%%/s, tol=%.1f%% → %.2fs release window;"
			% [diff, r["target_tanks"], r["fill_rate"], r["tolerance"], window]
			+ " %.1fs of fill in a %.1fs round (%.0f%%)"
				% [work, r["game_duration"], fraction * 100.0])
		_check("%s: the release window is humanly wide" % diff,
			window >= min_window,
			"only %.2fs wide (%.1f%% tolerance at %.0f%%/s)"
				% [window, r["tolerance"], r["fill_rate"]])
		_check("%s: a flawless run leaves margin for a mistake" % diff,
			fraction <= 0.85,
			"a flawless run already spends %.0f%% of the %.1fs round"
				% [fraction * 100.0, r["game_duration"]])


## Vegetable Bath: completing the quota must end the round exactly once.
##
## Driven the way AutoPlayManager._play_vegetable_bath() drives it — reposition the
## veggie and call _check_placement() — because that is the path that produced the
## warning in the soak, and because it is the same function the real drag/drop in
## _input() calls on release.
##
## total_actions is the discriminating counter. record_action(true) sits above the
## quota branch's await, so a second pass through that branch files a second
## success before it re-ends the round. Score cannot discriminate: the end-of-round
## bonus happens to equal one extra combo-tier action.
func _verify_vegetable_bath_quota() -> void:
	print("")
	print("── Vegetable Bath: the quota ends the round once ──")

	var scene := load("res://scenes/minigames/VegetableBath.tscn") as PackedScene
	if scene == null:
		_check("VegetableBath.tscn loads", false, "load() returned null")
		return

	var game: Node = scene.instantiate()
	add_child(game)
	if not await _start_round(game, "VegetableBath"):
		game.queue_free()
		return

	var quota: int = int(game.veggies_to_wash)
	_check("veggies_to_wash is set", quota > 0, "got %d" % quota)
	_check("a veggie exists per unit of quota", game.veggies.size() == quota,
		"%d veggies for a quota of %d" % [game.veggies.size(), quota])

	for veggie in game.veggies:
		if not is_instance_valid(veggie):
			continue
		veggie.position = game.wash_bowl.position
		game._check_placement(veggie)
		await _hold(0.1)

	for veggie in game.veggies:
		if not is_instance_valid(veggie):
			continue
		veggie.position = game.clean_basket.position
		game._check_placement(veggie)
		await _hold(0.1)
		print("    delivered → washed=%d/%d total_actions=%d score=%d active=%s"
			% [game.veggies_washed, quota, game.total_actions, game.current_score,
				game.game_active])

	# Past the 0.5s celebratory beat the quota branch awaits before end_game.
	await _hold(1.0)

	_check("veggies_washed equals the quota exactly",
		game.veggies_washed == quota,
		"got %d, expected %d" % [game.veggies_washed, quota])
	_check("total_actions equals the quota exactly",
		game.total_actions == quota,
		"got %d — the quota branch ran %d extra time(s) and re-ended the round"
			% [game.total_actions, game.total_actions - quota])
	_check("correct_actions equals the quota exactly",
		game.correct_actions == quota,
		"got %d, expected %d" % [game.correct_actions, quota])
	_check("the round ended", not game.game_active,
		"still active after the quota was met")

	game.queue_free()
	await get_tree().process_frame
