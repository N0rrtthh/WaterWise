extends Node
##
## VerifySessionLogEvidence - does the EXPORTED session log tell the truth about the
## adaptive algorithm?
##
## The session log is the artifact a defence reads. Its sp_algorithm block was being
## filled in AFTER GameManager._finalize_session_for_logging() had already called
## AdaptiveDifficulty.reset(), so every field in it was an _initialize_session()
## default: final_difficulty "Easy", final_phi 0.0, difficulty_progression empty. The
## bug was invisible from inside the algorithm - the algorithm was right, the evidence
## export was wrong - and invisible from the log alone, because "Easy / 0.0" is a value
## a real session can legitimately produce.
##
## So this harness compares the file on disk against the live state that produced it:
##   1. start a session through the production entry point, assert it starts clean
##   2. drive rounds through GameManager.complete_minigame() - weak, then strong, then
##      middling - so the run genuinely visits Easy, Hard and Medium
##   3. snapshot the live algorithm immediately before finalizing
##   4. finalize, read the written file back off disk, and assert every exported field
##      equals the snapshot
##   5. assert the algorithm is STILL readable after finalize (FinalScore.gd reads it
##      there), and that the NEXT start_new_session() is what clears it - in both
##      SINGLE_PLAYER and MULTIPLAYER_COOP
##
## Run: Godot --headless --path . tools/VerifySessionLogEvidence.tscn
## Exit 0 = all assertions passed, 1 = at least one failed.

var _pass: int = 0
var _fail: int = 0

func _p(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s%s" % [name, ("  " + detail) if detail != "" else ""])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [name, ("  " + detail) if detail != "" else ""])

func _close(name: String, got: float, want: float, tol: float) -> void:
	_p(name, absf(got - want) <= tol, "got=%.4f want=%.4f" % [got, want])

func _summary() -> void:
	print("=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _ready() -> void:
	await get_tree().process_frame
	var gm: Node = get_node_or_null("/root/GameManager")
	var ad: Node = get_node_or_null("/root/AdaptiveDifficulty")
	var sl: Node = get_node_or_null("/root/SessionLogger")
	if gm == null or ad == null or sl == null:
		print("FATAL: GameManager/AdaptiveDifficulty/SessionLogger autoload missing")
		get_tree().quit(1)
		return

	print("=== SESSION LOG EVIDENCE ===")

	# 1. A session starts clean.
	gm.call("start_new_session", 0)  # GameMode.SINGLE_PLAYER
	await get_tree().process_frame
	var start_prog: Dictionary = ad.call("get_difficulty_progression")
	_p("session_starts_clean_tier", str(ad.call("get_current_difficulty")) == "Easy",
		"tier=%s" % str(ad.call("get_current_difficulty")))
	_p("session_starts_clean_evaluations", int(start_prog.get("evaluations", -1)) == 0,
		"evaluations=%d" % int(start_prog.get("evaluations", -1)))

	# 2. Drive real rounds through the production entry point.
	# Weak and jittery: low accuracy, wide reaction-time spread -> low WMA, high CP.
	for i in range(6):
		gm.call("complete_minigame", "HarnessWeak%d" % i, 0.25, 900 + (i % 3) * 1400, 4)
		await get_tree().process_frame
	var tier_after_weak: String = str(ad.call("get_current_difficulty"))

	# Strong and consistent: near-perfect accuracy, near-zero reaction-time spread, so
	# Phi = WMA - CP clears the 0.85 HARD threshold on the paper's own arithmetic.
	for i in range(6):
		gm.call("complete_minigame", "HarnessStrong%d" % i, 0.99, 700 + (i % 2) * 10, 0)
		await get_tree().process_frame
	var tier_after_strong: String = str(ad.call("get_current_difficulty"))

	# Middling: lands the run on MEDIUM, so the exported final_difficulty is compared
	# against something other than the peak the run reached.
	for i in range(5):
		gm.call("complete_minigame", "HarnessMid%d" % i, 0.72, 1000 + (i % 4) * 320, 1)
		await get_tree().process_frame
	var tier_final: String = str(ad.call("get_current_difficulty"))

	print("  tiers driven: weak=%s strong=%s final=%s" % [tier_after_weak, tier_after_strong, tier_final])
	_p("weak_play_reaches_easy", tier_after_weak == "Easy", "tier=%s" % tier_after_weak)
	_p("strong_play_reaches_hard", tier_after_strong == "Hard", "tier=%s" % tier_after_strong)

	# 3. Snapshot the live algorithm immediately BEFORE finalizing.
	var live_metrics: Dictionary = ad.call("get_window_metrics")
	var live_phi: float = float(live_metrics.get("proficiency_index", 0.0))
	var live_wma: float = float(live_metrics.get("weighted_accuracy", 0.0))
	var live_cp: float = float(live_metrics.get("consistency_penalty", 0.0))
	var live_level: int = int(ad.get("progressive_level"))
	var live_prog: Dictionary = ad.call("get_difficulty_progression")
	var live_evals: int = int(live_prog.get("evaluations", 0))
	var live_peak: String = str(live_prog.get("peak_difficulty", ""))
	var live_seq: String = str(live_prog.get("tier_sequence", ""))
	var rounds_driven: int = int(sl.get("sp_games_count"))

	_p("algorithm_actually_evaluated", live_evals > 0, "evaluations=%d" % live_evals)
	_p("all_three_tiers_visited", bool(live_prog.get("all_three_tiers_reached", false)),
		"sequence=%s" % live_seq)

	# 4. Finalize, then read the written file back off disk.
	gm.call("_finalize_session_for_logging")
	await get_tree().process_frame
	var path: String = str(sl.call("get_last_exported_path"))
	_p("session_log_written", path != "" and FileAccess.file_exists(path), path)
	if path == "" or not FileAccess.file_exists(path):
		_summary()
		return

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_p("session_log_parses", false, "not a JSON object")
		_summary()
		return
	_p("session_log_parses", true)
	var log_dict: Dictionary = parsed
	var algo: Dictionary = log_dict.get("sp_algorithm", {})
	var recs: Array = log_dict.get("sp_game_records", [])

	_p("records_survived_export", recs.size() == rounds_driven,
		"records=%d driven=%d" % [recs.size(), rounds_driven])

	# THE assertion this harness exists for: the file agrees with the live state.
	_p("exported_final_difficulty_is_live", str(algo.get("final_difficulty", "")) == tier_final,
		"exported=%s live=%s" % [str(algo.get("final_difficulty", "")), tier_final])
	_close("exported_final_phi_is_live", float(algo.get("final_phi", 0.0)), live_phi, 0.0002)
	_close("exported_final_wma_is_live", float(algo.get("final_wma", 0.0)), live_wma, 0.0002)
	_close("exported_final_cp_is_live", float(algo.get("final_cp", 0.0)), live_cp, 0.0002)
	_p("exported_progressive_level_is_live", int(algo.get("progressive_level", -1)) == live_level,
		"exported=%d live=%d" % [int(algo.get("progressive_level", -1)), live_level])

	# A defaulted zero is the exact shape of the bug, so it gets its own assertion: the
	# run above provably evaluated a window, so a 0.0 here can only be a wipe.
	_p("exported_final_phi_not_defaulted", absf(float(algo.get("final_phi", 0.0))) > 0.0001,
		"final_phi=%.4f" % float(algo.get("final_phi", 0.0)))

	# A cumulative log must say which session its sp_algorithm block describes, because
	# SessionLogger never resets: it accumulates for the whole process while GameManager
	# exports on every return to the menu.
	var algo_sid: String = str(algo.get("algo_session_id", ""))
	_p("exported_algo_session_id_present", algo_sid != "", "id=%s" % algo_sid)
	var stamped: int = 0
	for r in recs:
		if str((r as Dictionary).get("algo_session_id", "")) == algo_sid:
			stamped += 1
	_p("records_stamped_with_session", stamped == rounds_driven,
		"stamped=%d of %d" % [stamped, recs.size()])

	var xprog: Dictionary = algo.get("difficulty_progression", {})
	_p("exported_progression_present", not xprog.is_empty())
	_p("exported_progression_evaluations", int(xprog.get("evaluations", -1)) == live_evals,
		"exported=%d live=%d" % [int(xprog.get("evaluations", -1)), live_evals])
	_p("exported_progression_peak", str(xprog.get("peak_difficulty", "")) == live_peak,
		"exported=%s live=%s" % [str(xprog.get("peak_difficulty", "")), live_peak])
	_p("exported_progression_sequence", str(xprog.get("tier_sequence", "")) == live_seq,
		"exported=%s" % str(xprog.get("tier_sequence", "")))
	_p("exported_progression_proves_hard", str(xprog.get("peak_difficulty", "")) == "Hard",
		"peak=%s" % str(xprog.get("peak_difficulty", "")))

	# 4b. The case study is the OTHER artifact a defence reads, and a DIFFERENT function
	# writes it: AdaptiveDifficulty.export_to_json_file() builds its own copy of the
	# algorithm state, so every assertion above says nothing about it. It is exported
	# from _finalize_session_for_logging() too, at a deterministic path, so it can be
	# read back off disk and held to the same standard as the session log.
	var cs_path: String = "user://case_study_%s.json" % algo_sid
	_p("case_study_written", FileAccess.file_exists(cs_path), cs_path)
	if FileAccess.file_exists(cs_path):
		var cs_parsed = JSON.parse_string(FileAccess.get_file_as_string(cs_path))
		if typeof(cs_parsed) != TYPE_DICTIONARY:
			_p("case_study_parses", false, "not a JSON object")
		else:
			_p("case_study_parses", true)
			var gp: Dictionary = (cs_parsed as Dictionary).get("gameplay", {})
			var cs_prog: Dictionary = gp.get("difficulty_progression", {})
			var cs_wm: Dictionary = gp.get("window_metrics", {})
			_p("case_study_final_difficulty_is_live",
				str(gp.get("final_difficulty", "")) == tier_final,
				"exported=%s live=%s" % [str(gp.get("final_difficulty", "")), tier_final])
			_p("case_study_progression_present", not cs_prog.is_empty())
			_p("case_study_progression_evaluations",
				int(cs_prog.get("evaluations", -1)) == live_evals,
				"exported=%d live=%d" % [int(cs_prog.get("evaluations", -1)), live_evals])
			_p("case_study_progression_peak",
				str(cs_prog.get("peak_difficulty", "")) == live_peak,
				"exported=%s live=%s" % [str(cs_prog.get("peak_difficulty", "")), live_peak])
			_p("case_study_progression_sequence",
				str(cs_prog.get("tier_sequence", "")) == live_seq,
				"exported=%s" % str(cs_prog.get("tier_sequence", "")))
			_p("case_study_proves_all_three_tiers",
				bool(cs_prog.get("all_three_tiers_reached", false)),
				"peak=%s" % str(cs_prog.get("peak_difficulty", "")))
			_close("case_study_phi_is_live",
				float(cs_wm.get("proficiency_index", 0.0)), live_phi, 0.0002)
			_p("case_study_phi_not_defaulted",
				absf(float(cs_wm.get("proficiency_index", 0.0))) > 0.0001,
				"phi=%.4f" % float(cs_wm.get("proficiency_index", 0.0)))

	# 5. Still readable after finalize - FinalScore.gd prints this tier on the
	# end-of-session screen, and it runs after _finalize_session_for_logging().
	_p("algorithm_readable_after_finalize", str(ad.call("get_current_difficulty")) == tier_final,
		"tier=%s" % str(ad.call("get_current_difficulty")))
	var post: Dictionary = ad.call("get_difficulty_progression")
	_p("progression_readable_after_finalize", int(post.get("evaluations", 0)) == live_evals,
		"evaluations=%d" % int(post.get("evaluations", 0)))

	# 6. ...and the NEXT session start is what clears it, in BOTH modes.
	gm.call("start_new_session", 0)  # SINGLE_PLAYER
	await get_tree().process_frame
	var sp_prog: Dictionary = ad.call("get_difficulty_progression")
	_p("sp_session_start_clears_tier", str(ad.call("get_current_difficulty")) == "Easy",
		"tier=%s" % str(ad.call("get_current_difficulty")))
	_p("sp_session_start_clears_window", int(sp_prog.get("evaluations", -1)) == 0,
		"evaluations=%d" % int(sp_prog.get("evaluations", -1)))

	for i in range(4):
		gm.call("complete_minigame", "HarnessCarry%d" % i, 0.99, 700, 0)
		await get_tree().process_frame
	gm.call("start_new_session", 1)  # MULTIPLAYER_COOP
	await get_tree().process_frame
	var mp_prog: Dictionary = ad.call("get_difficulty_progression")
	_p("mp_session_start_clears_window", int(mp_prog.get("evaluations", -1)) == 0,
		"evaluations=%d" % int(mp_prog.get("evaluations", -1)))
	_p("mp_session_start_clears_tier", str(ad.call("get_current_difficulty")) == "Easy",
		"tier=%s" % str(ad.call("get_current_difficulty")))

	# 7. The co-op algorithm has the same session boundary. CoopAdaptation.reset_session()
	# shipped with zero callers, so a second match in the same process inherited the
	# previous team's per-player windows and skill gap. Drive real results through it,
	# then start a session and assert the windows are empty again.
	var ca: Node = get_node_or_null("/root/CoopAdaptation")
	if ca == null:
		_p("coop_autoload_present", false)
	else:
		for i in range(6):
			ca.call("add_game_result",
				{"accuracy": 0.98, "time": 6.0, "errors": 0},
				{"accuracy": 0.30, "time": 17.0, "errors": 5}, true)
			await get_tree().process_frame
		var w1: int = (ca.get("player1_window") as Array).size()
		var gap_before: float = float(ca.get("skill_gap"))
		_p("coop_ingested_results", w1 > 0 and gap_before > 0.0,
			"p1_window=%d skill_gap=%.3f" % [w1, gap_before])
		gm.call("start_new_session", 1)  # MULTIPLAYER_COOP
		await get_tree().process_frame
		_p("coop_session_start_clears_windows",
			(ca.get("player1_window") as Array).is_empty() and (ca.get("player2_window") as Array).is_empty(),
			"p1=%d p2=%d" % [(ca.get("player1_window") as Array).size(), (ca.get("player2_window") as Array).size()])
		_p("coop_session_start_clears_skill_gap", absf(float(ca.get("skill_gap"))) < 0.0001,
			"skill_gap=%.4f" % float(ca.get("skill_gap")))
		_p("coop_session_start_resets_totals", int(ca.get("total_games")) == 0,
			"total_games=%d" % int(ca.get("total_games")))

	# 8. An export with nothing in it is not evidence. GameManager finalizes on every
	# return to the menu, which filled session_logs/ with content-free files (31 of 97
	# when the guard was added), so the automatic path now skips a log with no rounds
	# of either kind while deliberate callers keep forcing one. Both halves are checked,
	# and the round arrays are restored afterwards so nothing above is invalidated.
	var saved_sp: Array = (sl.get("sp_games") as Array).duplicate()
	var saved_mp: Array = (sl.get("mp_rounds") as Array).duplicate()
	var dir_before: int = _count_session_logs()
	sl.set("sp_games", [])
	sl.set("mp_rounds", [])
	var skipped: String = str(sl.call("export_session"))
	_p("empty_export_skipped", skipped == "", "returned='%s'" % skipped)
	_p("empty_export_wrote_no_file", _count_session_logs() == dir_before,
		"before=%d after=%d" % [dir_before, _count_session_logs()])
	var forced: String = str(sl.call("export_session", true))
	_p("forced_empty_export_still_writes", forced != "" and FileAccess.file_exists(forced), forced)
	# That file exists only to prove the force path still writes; it is exactly the
	# content-free artifact the guard above exists to stop, so the harness removes it
	# rather than leaving one behind in the evidence folder.
	if forced != "" and FileAccess.file_exists(forced):
		var rm := DirAccess.remove_absolute(forced)
		_p("forced_empty_export_cleaned_up", rm == OK and not FileAccess.file_exists(forced),
			"err=%d" % rm)
	sl.set("sp_games", saved_sp)
	sl.set("mp_rounds", saved_mp)
	# Against saved_sp, not rounds_driven: phases 6-7 drove four more rounds through
	# complete_minigame() after finalize, so SessionLogger legitimately holds more by
	# now. The invariant being checked is that the swap put back what it took.
	_p("round_arrays_restored",
		(sl.get("sp_games") as Array).size() == saved_sp.size()
			and (sl.get("mp_rounds") as Array).size() == saved_mp.size(),
		"sp_games=%d saved=%d" % [(sl.get("sp_games") as Array).size(), saved_sp.size()])

	# The artifact must say which kind of run produced it: this one is headless, so a
	# reader must not be able to mistake its synthetic samples for gameplay.
	var rc: Dictionary = log_dict.get("run_context", {})
	_p("run_context_present", not rc.is_empty(), str(rc))
	_p("run_context_marks_synthetic", bool(rc.get("synthetic", false)),
		"headless=%s auto_play=%s" % [str(rc.get("headless")), str(rc.get("auto_play"))])

	_summary()

func _count_session_logs() -> int:
	var d := DirAccess.open("user://session_logs")
	if d == null:
		return 0
	return d.get_files().size()
