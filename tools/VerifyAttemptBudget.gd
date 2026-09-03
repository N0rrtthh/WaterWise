extends Node

## Gate: proves the attempt-budget fail mode is REAL, and that it did not leak into
## the games that are supposed to stay on the clock.
##
## Run:
##   godot --headless --path . res://tools/VerifyAttemptBudget.tscn
##
## WHAT WAS WRONG
##   AdaptiveDifficulty's published table gives the HARDER tiers LESS time (Easy 20 /
##   Medium 15 / Hard 10), and get_difficulty_settings() divides that again by the
##   progressive ramp down to a 3 s floor. For a reflex game that is the whole point.
##   For a think-first game it inverted the thing being measured: in WaterMemory the
##   player who remembered where the pair was still lost, because remembering takes
##   longer than swiping. Two of the games in this list already carried hand-written
##   floors (_min_completable_duration, _flawless_run_seconds) whose only job was to
##   stop the clock making the round arithmetically impossible - the clock was the
##   wrong pressure, and those floors were the symptom.
##
## WHAT THIS MEASURES
##   Not that use_attempt_budget() was called - a grep would show that. It measures
##   the four behaviours the change is supposed to produce, on live rounds started
##   through the real tap-to-start prompt:
##     1. Medium/Hard of a converted game reports fail_mode "attempts", hides the
##        clock, and shows a tries readout instead.
##     2. Spending the budget ENDS the round, as a loss.
##     3. Running past the tier's authored duration does NOT end the round any more.
##     4. Easy is unchanged: still clock-based, and a mistake still shortens it.
##   Plus two things that must NOT have changed: the survival games refuse the budget
##   outright, and every unconverted minigame still reports fail_mode "clock" at every
##   tier.
##
## THESIS SAFETY
##   The attempts ceiling overwrites MiniGameBase.game_duration, never
##   AdaptiveDifficulty.DIFFICULTY_SETTINGS.time_limit - which is what
##   calculate_raw_game_score() reads for t_max_ms, and what the paper publishes.
##   The last check re-reads those three numbers to prove it.

const TIERS: Array[String] = ["Easy", "Medium", "Hard"]

## The games converted to attempt-based Medium/Hard, and why each is a think-first
## task rather than a reflex one.
const CONVERTED := {
	"TracePipePath": "accuracy tracing",
	"WaterMemory": "recall",
	"SpotTheSpeck": "perception",
	"ToiletTankFix": "precision hold",
	"FilterBuilder": "ordering from memory",
}

## Published in the paper's Table 6. The ceiling must not have moved them.
const PAPER_TIME_LIMIT := {"Easy": 20, "Medium": 15, "Hard": 10}

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
		await get_tree().process_frame


## A minigame parked on its tap-to-start prompt: difficulty applied, HUD built,
## nothing played yet. Returns null when the scene cannot be used.
func _park(scene_name: String, tier: String) -> Node:
	var path := "res://scenes/minigames/%s.tscn" % scene_name
	if not ResourceLoader.exists(path):
		return null
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if ad:
		ad.current_difficulty = tier
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	# Same exclusion the other difficulty gates use: RainwaterHarvesting is a
	# multiplayer Node2D that swaps the scene out from under the harness in _ready().
	if not inst.has_method("_apply_sp_time_penalty"):
		inst.free()
		return null
	get_tree().root.add_child(inst)
	await _frames(6)
	return inst


## A LIVE round, started through the real prompt rather than by poking game_active.
func _live(scene_name: String, tier: String) -> Node:
	var inst: Node = await _park(scene_name, tier)
	if inst == null:
		return null
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


func _drop(inst: Node) -> void:
	if inst != null and is_instance_valid(inst):
		inst.queue_free()
	await _frames(4)


func _ready() -> void:
	print("=== ATTEMPT BUDGET GATE ===")
	await _frames(2)

	await _check_a_static()
	await _check_b_budget_ends_round()
	await _check_c_clock_no_longer_fails()
	await _check_d_easy_still_shortens()
	await _check_e_survival_refuses()
	await _check_f_unconverted_untouched()
	_check_g_thesis_constants()

	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## A. Per tier, the mode the tier is supposed to be in - and the HUD that goes with it.
func _check_a_static() -> void:
	print("")
	print("--- A. tier wiring (5 converted games x 3 tiers) ---")
	for game_name in CONVERTED.keys():
		for tier in TIERS:
			var inst: Node = await _park(game_name, tier)
			if inst == null:
				_check("%s %s instantiable" % [game_name, tier], false,
					"scene missing or not a MiniGameBase")
				continue
			var mode: String = str(inst.get("fail_mode"))
			var budget: int = int(inst.get("attempts_max"))
			var dur: float = float(inst.get("game_duration"))
			var nominal: float = float(inst.call("nominal_round_seconds"))
			var t_label: Label = inst.get("timer_label")
			var a_label: Label = inst.get("attempts_label")
			var bar: ProgressBar = inst.get("timer_bar")
			var t_vis := "null" if t_label == null else str(t_label.visible)
			var a_vis := "null" if a_label == null else str(a_label.visible)
			var b_vis := "null" if bar == null else str(bar.visible)

			if tier == "Easy":
				# The user's spec: Easy stays on the clock in every game.
				_check("%s Easy is clock-based" % game_name,
					mode == "clock" and budget == 0,
					"fail_mode=%s attempts_max=%d" % [mode, budget])
				_check("%s Easy shows the clock" % game_name,
					t_label != null and t_label.visible
						and (a_label == null or not a_label.visible),
					"timer_label=%s attempts_label=%s" % [t_vis, a_vis])
			else:
				_check("%s %s is attempt-based" % [game_name, tier],
					mode == "attempts" and budget > 0,
					"fail_mode=%s attempts_max=%d" % [mode, budget])
				_check("%s %s starts with a full budget" % [game_name, tier],
					budget > 0 and int(inst.get("attempts_left")) == budget,
					"attempts_left=%d of %d" % [int(inst.get("attempts_left")), budget])
				# The clock survives only as an anti-hang ceiling: 4x the authored
				# length, floored at 45 s. At the authored length the round would
				# fail on time before the budget could ever be spent.
				var want_ceiling: float = maxf(45.0, nominal * 4.0)
				_check("%s %s clock became a ceiling" % [game_name, tier],
					absf(dur - want_ceiling) < 0.01 and dur > nominal,
					"game_duration=%.1f nominal=%.1f expected=%.1f" % [dur, nominal, want_ceiling])
				_check("%s %s hides the clock, shows tries" % [game_name, tier],
					(t_label == null or not t_label.visible)
						and (bar == null or not bar.visible)
						and a_label != null and a_label.visible,
					"timer_label=%s bar=%s attempts_label=%s text=%s" % [
						t_vis, b_vis, a_vis, "" if a_label == null else a_label.text])
			await _drop(inst)


## B. Spending the budget is what ends the round now. Asserted synchronously, before
## the outro coroutine can advance the scene out from under the harness.
func _check_b_budget_ends_round() -> void:
	print("")
	print("--- B. spending the budget ends the round (WaterMemory Medium) ---")
	var inst: Node = await _live("WaterMemory", "Medium")
	if inst == null or inst.get("game_active") != true:
		_check("WaterMemory Medium round started", false,
			"game_active=%s" % ("no instance" if inst == null else str(inst.get("game_active"))))
		await _drop(inst)
		return
	_check("WaterMemory Medium round started", true)

	var budget: int = int(inst.get("attempts_max"))
	var mid_left: int = -1
	var mid_penalty: float = -1.0
	for i in range(budget):
		inst.call("record_action", false)
		if i == 0:
			mid_left = int(inst.get("attempts_left"))
			mid_penalty = float(inst.get("_time_penalty_total"))

	var ended: bool = inst.get("_round_ended") == true
	var still_active: bool = inst.get("game_active") == true
	var penalty: float = float(inst.get("_time_penalty_total"))
	var left: int = int(inst.get("attempts_left"))
	await _drop(inst)

	_check("one mistake spends one try", mid_left == budget - 1,
		"attempts_left=%d after 1 of %d" % [mid_left, budget])
	_check("a mistake costs a try, not seconds", mid_penalty == 0.0 and penalty == 0.0,
		"_time_penalty_total=%.2f after 1, %.2f after %d" % [mid_penalty, penalty, budget])
	_check("budget exhausted ends the round", ended and not still_active,
		"_round_ended=%s game_active=%s attempts_left=%d" % [ended, still_active, left])


## C. Three things about the clock in attempts mode.
##   C1 - the tier's AUTHORED duration no longer fails the round. That is the whole
##        complaint: under the old behaviour this is exactly where _process() called
##        _on_timeout() and spent a life.
##   C2 - the hidden clock comes BACK for the last few seconds, so the ceiling is
##        never a surprise. Asserted as hidden-then-visible, not just visible.
##   C3 - the ceiling still ends the round. It is a backstop against a round nobody
##        is playing, and a backstop that does not fire is not a backstop.
func _check_c_clock_no_longer_fails() -> void:
	print("")
	print("--- C. the clock in attempts mode (TracePipePath Medium) ---")
	var inst: Node = await _live("TracePipePath", "Medium")
	if inst == null or inst.get("game_active") != true:
		_check("TracePipePath Medium round started", false,
			"game_active=%s" % ("no instance" if inst == null else str(inst.get("game_active"))))
		await _drop(inst)
		return
	_check("TracePipePath Medium round started", true)

	var nominal: float = float(inst.call("nominal_round_seconds"))
	var dur: float = float(inst.get("game_duration"))
	var warn: float = float(inst.get("ATTEMPT_CEILING_WARN_SEC"))
	var t_label: Label = inst.get("timer_label")
	var hidden_before: bool = t_label != null and not t_label.visible

	# C1: age the round past the tier's authored length.
	_age(inst, nominal * 1.5)
	await _frames(8)
	var survived: bool = inst.get("game_active") == true and inst.get("_round_ended") == false
	_check("past the authored duration, round is still playable", survived,
		"aged %.1fs past a %.1fs round: game_active=%s _round_ended=%s" % [
			nominal * 1.5, nominal, inst.get("game_active"), inst.get("_round_ended")])

	# C2: age into the warning window; the clock that A proved hidden must return.
	_age(inst, dur - warn * 0.5)
	await _frames(8)
	var revealed: bool = t_label != null and t_label.visible
	var alive: bool = inst.get("game_active") == true
	_check("ceiling reveals the clock before it lands", hidden_before and revealed and alive,
		"timer_label.visible %s -> %s, game_active=%s (%.1fs left of %.1fs ceiling)" % [
			str(not hidden_before), str(revealed), alive, warn * 0.5, dur])

	# C3: age past the ceiling itself. Read synchronously - end_game() starts the
	# outro, which changes scene and would take this harness with it.
	_age(inst, dur + 1.0)
	await _frames(4)
	var ended: bool = inst.get("_round_ended") == true
	var active: bool = inst.get("game_active") == true
	var unspent: int = int(inst.get("attempts_left"))
	await _drop(inst)
	_check("ceiling still ends an abandoned round", ended and not active,
		"_round_ended=%s game_active=%s with %d tries unspent" % [ended, active, unspent])


## Rewind game_start_time so elapsed_play_seconds() reports `seconds`. Paused time is
## added back because elapsed_play_seconds() subtracts it.
func _age(inst: Node, seconds: float) -> void:
	inst.set("game_start_time",
		Time.get_ticks_msec() - int(seconds * 1000.0) + int(inst.get("_paused_ms_total")))


## D. Easy is untouched: still a clock, and a wrong trace still shortens it.
func _check_d_easy_still_shortens() -> void:
	print("")
	print("--- D. Easy still shortens on a mistake (TracePipePath Easy) ---")
	var inst: Node = await _live("TracePipePath", "Easy")
	if inst == null or inst.get("game_active") != true:
		_check("TracePipePath Easy round started", false,
			"game_active=%s" % ("no instance" if inst == null else str(inst.get("game_active"))))
		await _drop(inst)
		return
	_check("TracePipePath Easy round started", true)

	var before: float = float(inst.get("_time_penalty_total"))
	inst.call("record_action", false)
	var after: float = float(inst.get("_time_penalty_total"))
	var mode: String = str(inst.get("fail_mode"))
	var ended: bool = inst.get("_round_ended") == true
	await _drop(inst)
	_check("Easy mistake shortens the clock", after > before and mode == "clock",
		"_time_penalty_total %.2f -> %.2f (fail_mode=%s)" % [before, after, mode])
	_check("Easy mistake does not end the round", not ended, "_round_ended=%s" % ended)


## E. Survival games refuse the budget: there, outlasting the clock IS the win, so a
## budget would replace the win condition rather than the failure condition.
func _check_e_survival_refuses() -> void:
	print("")
	print("--- E. survival games refuse the budget (WaterPlant Hard) ---")
	var inst: Node = await _park("WaterPlant", "Hard")
	if inst == null:
		_check("WaterPlant instantiable", false, "scene missing")
		return
	var mode_was: String = str(inst.get("game_mode"))
	inst.call("use_attempt_budget", 0, 3, 3)
	var mode: String = str(inst.get("fail_mode"))
	var budget: int = int(inst.get("attempts_max"))
	await _drop(inst)
	_check("WaterPlant is a survival game", mode_was == "survival", "game_mode=%s" % mode_was)
	_check("use_attempt_budget() refused on survival", mode == "clock" and budget == 0,
		"fail_mode=%s attempts_max=%d" % [mode, budget])


## F. Nothing leaked. Every game NOT in CONVERTED must still be clock-based at every
## tier - the reflex, rhythm and catching games, where the clock IS the challenge.
func _check_f_unconverted_untouched() -> void:
	print("")
	print("--- F. unconverted games still clock-based ---")
	var dir := DirAccess.open("res://scenes/minigames")
	if dir == null:
		_check("minigame folder readable", false, "DirAccess.open failed")
		return
	var names: Array[String] = []
	for f in dir.get_files():
		var base := f.get_basename()
		if f.get_extension() == "tscn" and not CONVERTED.has(base):
			names.append(base)
	names.sort()
	var checked := 0
	var leaked: Array[String] = []
	for game_name in names:
		for tier in ["Medium", "Hard"]:
			var inst: Node = await _park(game_name, tier)
			if inst == null:
				continue
			checked += 1
			if str(inst.get("fail_mode")) != "clock":
				leaked.append("%s %s" % [game_name, tier])
			await _drop(inst)
	_check("no budget leaked into unconverted games", leaked.is_empty(),
		"%d tier-instances checked; leaked: %s" % [checked, str(leaked)])
	_check("enough unconverted games were reachable", checked >= 20,
		"%d of %d expected tier-instances" % [checked, names.size() * 2])


## G. The published table is untouched. The ceiling moved MiniGameBase.game_duration;
## calculate_raw_game_score() reads DIFFICULTY_SETTINGS.time_limit for t_max_ms, and
## that is the number in the paper.
func _check_g_thesis_constants() -> void:
	print("")
	print("--- G. thesis constants intact ---")
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if ad == null:
		_check("AdaptiveDifficulty autoload present", false, "/root/AdaptiveDifficulty missing")
		return
	var settings: Dictionary = ad.get("DIFFICULTY_SETTINGS")
	for tier in TIERS:
		var got: int = -1
		if settings.has(tier) and settings[tier].has("time_limit"):
			got = int(settings[tier]["time_limit"])
		_check("DIFFICULTY_SETTINGS[%s].time_limit == %d" % [tier, PAPER_TIME_LIMIT[tier]],
			got == PAPER_TIME_LIMIT[tier], "got %d" % got)
