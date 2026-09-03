extends Node

## Proves the three-tier decision tree is REACHABLE, and that the reaction-time
## signal the Consistency Penalty is defined over is the player's response
## latency rather than the length of whichever minigame was drawn.
##
## Why this harness exists
## -----------------------
## The reported symptom was "many games played, only ever reached Medium". The
## measured cause is not the formula - _calculate_window_metrics() transcribes
## the thesis exactly - but its INPUT. add_performance()'s reaction_time was fed
## int(elapsed_play_seconds() * 1000) by MiniGameBase.end_game(), i.e. the round
## DURATION. Over the 594 real single-player rounds in user://session_logs, 71%
## of that quantity's variance is between minigames rather than within them, and
## the per-game medians span 1.4 s to 25 s. Sigma was therefore largely measuring
## which game was drawn. With CP = min(sigma / 5000, 0.2) and Phi = WMA - CP,
## Phi > 0.85 needs sigma < 750 ms; 292 of the 522 real windows sat at the 0.2
## cap outright.
##
## Every assertion below is written so it CAN fail: each states a number the
## build has to produce, and the tier checks drive the real autoload with real
## samples rather than asserting over a table of constants.

const OUT := "user://verify_tier_reachability.txt"

var _pass: int = 0
var _fail: int = 0
var _lines: PackedStringArray = PackedStringArray()

func _ready() -> void:
	_run()
	_finish()

func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		_pass += 1
		_lines.append("  PASS  %s  %s" % [name, detail])
	else:
		_fail += 1
		_lines.append("  FAIL  %s  %s" % [name, detail])

func _ad() -> Node:
	return get_node_or_null("/root/AdaptiveDifficulty")

func _feed(accuracies: Array, latencies: Array) -> Node:
	var ad := _ad()
	ad.call("reset")
	for i in range(accuracies.size()):
		ad.call("add_performance", float(accuracies[i]), int(latencies[i]), 0, "Harness")
	return ad

func _tier_for(accuracies: Array, latencies: Array) -> String:
	return str(_feed(accuracies, latencies).call("get_current_difficulty"))

func _phi_for(accuracies: Array, latencies: Array) -> float:
	var ad := _feed(accuracies, latencies)
	var st: Dictionary = ad.call("get_algorithm_status")
	# proficiency_index is a TOP-LEVEL field of get_algorithm_status(); there is no
	# "metrics" sub-dictionary. Guard on algorithm_active first, because the status
	# defaults phi to 0.0 when the window is too short to have measured one, and a
	# defaulted 0.0 must never be read as a measured Phi.
	if not bool(st.get("algorithm_active", false)):
		return -99.0
	return float(st.get("proficiency_index", -99.0))

func _run() -> void:
	var ad := _ad()
	if ad == null:
		_check("autoload_present", false, "/root/AdaptiveDifficulty missing")
		return

	_lines.append("--- 1. all three tiers reachable from real inputs ---")

	var hard_tier := _tier_for([1.0, 1.0, 1.0, 1.0, 1.0], [820, 790, 850, 810, 800])
	_check("hard_reachable", hard_tier == "Hard",
		"consistent expert (acc 1.00, latency 790-850ms) -> %s" % hard_tier)

	var med_tier := _tier_for([0.60, 0.65, 0.75, 0.85, 0.90], [8000, 7500, 6500, 5500, 5000])
	var med_phi := _phi_for([0.60, 0.65, 0.75, 0.85, 0.90], [8000, 7500, 6500, 5500, 5000])
	_check("thesis_table5_medium", med_tier == "Medium",
		"Table 5 worked example -> %s (paper: MEDIUM)" % med_tier)
	_check("thesis_table5_phi", abs(med_phi - 0.603) < 0.005,
		"Phi=%.4f vs paper 0.603" % med_phi)

	var easy_tier := _tier_for([0.30, 0.25, 0.40, 0.20, 0.35], [4000, 9000, 3000, 11000, 5000])
	_check("easy_reachable", easy_tier == "Easy",
		"struggling and erratic -> %s" % easy_tier)

	_lines.append("--- 2. HARD requires consistency, not accuracy alone ---")
	var erratic := _tier_for([1.0, 1.0, 1.0, 1.0, 1.0], [400, 5200, 900, 6100, 1200])
	_check("erratic_expert_not_hard", erratic != "Hard",
		"acc 1.00 but latency 400-6100ms -> %s" % erratic)

	_lines.append("--- 3. the sigma the penalty sees is response latency ---")
	var mgb := load("res://scripts/MiniGameBase.gd")
	var probe: Node = mgb.new()
	add_child(probe)
	var has_helper: bool = probe.has_method("representative_reaction_time_ms")
	_check("minigamebase_exposes_helper", has_helper,
		"representative_reaction_time_ms() present: %s" % str(has_helper))
	if has_helper:
		var src_empty := str(probe.call("report_reaction_time_source"))
		_check("fallback_declared_not_faked", src_empty == "round_duration",
			"no graded actions -> source reported as %s" % src_empty)
		probe.set("action_latencies_ms", PackedInt32Array([280, 310, 300, 2400]))
		var rep: int = int(probe.call("representative_reaction_time_ms"))
		var src_full := str(probe.call("report_reaction_time_source"))
		_check("median_of_action_latencies", rep == 305,
			"latencies 280/310/300/2400 -> %dms (median; mean would be 822)" % rep)
		_check("source_declared_per_action", src_full == "per_action",
			"source reported as %s" % src_full)
	probe.queue_free()

	_lines.append("--- 4. the export carries the trajectory, not just a sample ---")
	var base := _ad()
	base.call("reset")
	var climb := [
		[0.20, 9000], [0.25, 3000], [0.30, 8000], [0.35, 2500], [0.30, 9500],
		[0.70, 1200], [0.75, 1150], [0.80, 1250], [0.78, 1180], [0.82, 1210],
		[1.00, 800], [1.00, 830], [1.00, 810], [1.00, 790], [1.00, 820],
	]
	for row in climb:
		base.call("add_performance", float(row[0]), int(row[1]), 0, "Harness")
	var prog: Dictionary = base.call("get_difficulty_progression")
	_check("progression_field_present", not prog.is_empty(),
		"get_difficulty_progression() returned data")
	_check("all_three_tiers_in_timeline", bool(prog.get("all_three_tiers_reached", false)),
		"tiers_reached=%s sequence=%s" % [str(prog.get("tiers_reached")), str(prog.get("tier_sequence"))])
	_check("peak_is_hard", str(prog.get("peak_difficulty", "")) == "Hard",
		"peak_difficulty=%s" % str(prog.get("peak_difficulty")))
	var ev: int = int(prog.get("evaluations", 0))
	_check("one_evaluation_per_game_after_warmup", ev == climb.size() - 2,
		"%d evaluations for %d games (warmup 3)" % [ev, climb.size()])
	var session: Dictionary = base.call("export_complete_session")
	var gp: Dictionary = session.get("gameplay", {})
	_check("export_includes_progression", gp.has("difficulty_progression"),
		"gameplay.difficulty_progression present in export")

	_lines.append("--- 5. unmeasured stays unmeasured ---")
	base.call("reset")
	var fresh: Dictionary = base.call("get_difficulty_progression")
	_check("fresh_phi_min_is_null", fresh.get("phi_min") == null,
		"phi_min with 0 evaluations = %s" % str(fresh.get("phi_min")))
	_check("fresh_not_all_tiers", not bool(fresh.get("all_three_tiers_reached", true)),
		"all_three_tiers_reached=%s with 0 evaluations" % str(fresh.get("all_three_tiers_reached")))

func _finish() -> void:
	var head := "=== VerifyTierReachability ==="
	print(head)
	for l in _lines:
		print(l)
	print("=== SUMMARY: %d passed, %d failed ===" % [_pass, _fail])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f:
		f.store_string(head + "\n" + "\n".join(_lines) + "\n")
		f.close()
	get_tree().quit(0 if _fail == 0 else 1)
