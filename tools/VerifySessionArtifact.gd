extends Node
##
## VerifySessionArtifact - is ONE app-open-to-app-close really ONE artifact, and does
## that artifact describe the run it came from?
##
## A test phone produced FOUR session_*.json files from one play session (at 282s, 483s,
## 821s and 1129s), each a superset of the last. Cause: export_session() picked a fresh
## timestamped filename on every call, and GameManager._finalize_session_for_logging()
## calls it on EVERY return to the main menu. Nothing was wrong inside any of the four
## files - each was internally consistent - so no harness that reads a single log could
## see it. The defect only exists in the relationship between calls.
##
## Four adjacent defects in the same artifact are checked here for the same reason:
##   - game_log[].elapsed_sec held a raw Unix epoch for entries logged before
##     SessionLogger._ready() ran (autoloads above it log from their own _ready())
##   - scenes_visited was permanently [] because record_scene_visit() had no caller in
##     the shipped game
##   - mp_leaderboard carried a round_num -1 "team_success: true" row in sessions that
##     played zero multiplayer rounds
##   - iso_25010_compliant was PerformanceProfiler's rolling-60-frame verdict printed
##     beside this file's whole-session FPS, so a log could say fps.passed false and
##     iso_25010_compliant true in the same block
##   - run_context was computed from a live auto-play read at export time, so one
##     session_id exported as HUMAN three times and synthetic once
##
## Plus the two export-surface defects: session logs must land in Downloads/waterwise
## (flat - deep folders are unreachable on a non-rooted phone), and the Dev Stats screen
## must not carry a second export entry point.
##
## Run: Godot --headless --path . tools/VerifySessionArtifact.tscn
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

func _summary() -> void:
	print("=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _count_logs() -> int:
	var d := DirAccess.open("user://session_logs")
	return 0 if d == null else d.get_files().size()

func _read_json(abs_path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(abs_path)
	var parsed = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _ready() -> void:
	await get_tree().process_frame
	var gm: Node = get_node_or_null("/root/GameManager")
	var sl: Node = get_node_or_null("/root/SessionLogger")
	if gm == null or sl == null:
		print("FATAL: GameManager/SessionLogger autoload missing")
		get_tree().quit(1)
		return

	print("=== SESSION ARTIFACT ===")

	# 0. The clock. NetworkManager is declared above SessionLogger in project.godot and
	# logs from its own _ready(), so that entry exists before SessionLogger._ready() can
	# run. With session_start_unix assigned in _ready() its elapsed_sec was now - 0.0 -
	# a raw epoch (1788442502.25 on the phone) in a column every other row measures in
	# seconds since launch. Property initialisers run at instantiation, early enough.
	var glog: Array = sl.get("game_log")
	var worst_elapsed: float = 0.0
	var worst_src: String = ""
	for e in glog:
		var v: float = float((e as Dictionary).get("elapsed_sec", 0.0))
		if v > worst_elapsed:
			worst_elapsed = v
			worst_src = str((e as Dictionary).get("source", "?"))
	_p("game_log_elapsed_is_session_relative", glog.size() > 0 and worst_elapsed < 3600.0,
		"entries=%d worst=%.2fs from=%s" % [glog.size(), worst_elapsed, worst_src])

	# 1. Real rounds, so the export is not the empty-skip path.
	gm.call("start_new_session", 0)  # SINGLE_PLAYER
	await get_tree().process_frame
	for i in range(4):
		gm.call("complete_minigame", "ArtifactRound%d" % i, 0.8, 800 + i * 30, 1)
		await get_tree().process_frame

	# 2. Scene tracking. The tree's current scene is swapped rather than changed with
	# change_scene_to_file(), because this harness IS the current scene and changing it
	# frees the node holding the assertions.
	var visits_before: int = (sl.get("scenes_visited") as Array).size()
	var fake := Node.new()
	fake.name = "ArtifactSceneProbe"
	get_tree().root.add_child(fake)
	var real_scene: Node = get_tree().current_scene
	get_tree().current_scene = fake
	await get_tree().process_frame
	await get_tree().process_frame
	var visits: Array = sl.get("scenes_visited")
	var saw_probe: bool = false
	for v in visits:
		if str((v as Dictionary).get("scene", "")) == "ArtifactSceneProbe":
			saw_probe = true
	get_tree().current_scene = real_scene
	await get_tree().process_frame
	fake.queue_free()
	_p("scene_visit_recorded_without_manual_call", saw_probe and visits.size() > visits_before,
		"before=%d after=%d" % [visits_before, visits.size()])

	# 3. Zero multiplayer rounds must not produce a leaderboard row.
	var mp_rounds: Array = sl.get("mp_rounds")
	var lb: Array = sl.call("get_mp_leaderboard")
	_p("no_mp_rounds_no_leaderboard_row", mp_rounds.is_empty() and lb.is_empty(),
		"mp_rounds=%d leaderboard_rows=%d" % [mp_rounds.size(), lb.size()])

	# 4. THE defect: two exports in one session, one file.
	var logs_before: int = _count_logs()
	var count_before: int = int(sl.get("_export_count"))
	var path_a: String = str(sl.call("export_session"))
	await get_tree().process_frame
	var path_b: String = str(sl.call("export_session"))
	var logs_after: int = _count_logs()
	_p("both_exports_wrote", path_a != "" and path_b != "" and FileAccess.file_exists(path_b),
		"a=%s" % path_a.get_file())
	_p("repeat_export_same_path", path_a == path_b,
		"a=%s b=%s" % [path_a.get_file(), path_b.get_file()])
	_p("repeat_export_added_one_file", logs_after == logs_before + 1,
		"before=%d after=%d (+%d)" % [logs_before, logs_after, logs_after - logs_before])
	_p("export_count_advanced", int(sl.get("_export_count")) == count_before + 2,
		"before=%d after=%d" % [count_before, int(sl.get("_export_count"))])

	var d: Dictionary = _read_json(path_b)
	_p("artifact_parses", not d.is_empty(), "keys=%d" % d.size())
	_p("export_count_reported", int(d.get("export_count", -1)) == count_before + 2,
		"export_count=%s" % str(d.get("export_count")))

	_check_device_identifies_os(d)

	# The file must say the same thing about itself that the live logger does.
	var gp: Dictionary = d.get("gameplay_summary", {})
	var file_visits: Array = d.get("scenes_visited", [])
	_p("artifact_scenes_visited_not_empty",
		file_visits.size() > 0
			and int(gp.get("scenes_visited_count", 0)) == file_visits.size(),
		"scenes=%d count=%s" % [file_visits.size(), str(gp.get("scenes_visited_count"))])
	_p("artifact_leaderboard_empty_with_zero_rounds",
		int(gp.get("mp_rounds_played", -1)) == 0
			and (gp.get("mp_leaderboard", []) as Array).is_empty(),
		"rounds=%s rows=%d" % [str(gp.get("mp_rounds_played")),
			(gp.get("mp_leaderboard", []) as Array).size()])

	# 5. The compliance verdict must follow from the criteria printed beside it.
	var perf: Dictionary = d.get("performance", {})
	var crit: Dictionary = perf.get("iso_criteria", {})
	var fps_blk: Dictionary = perf.get("fps", {})
	var mem_blk: Dictionary = perf.get("memory", {})
	var lat_blk: Dictionary = perf.get("algorithm_latency", {})
	_p("iso_criteria_block_present", crit.size() >= 5, "keys=%s" % str(crit.keys()))
	# Each criterion agrees with the sub-block that reports its numbers.
	_p("iso_criteria_match_subblocks",
		crit.get("fps_passed") == fps_blk.get("passed")
			and bool(crit.get("memory_passed")) == bool(mem_blk.get("passed"))
			and bool(crit.get("algorithm_latency_passed")) == bool(lat_blk.get("passed")),
		"fps=%s mem=%s lat=%s" % [str(crit.get("fps_passed")), str(crit.get("memory_passed")),
			str(crit.get("algorithm_latency_passed"))])
	var expect_iso: bool = (
		crit.get("fps_passed", false) != false
		and bool(crit.get("memory_passed", false))
		and bool(crit.get("algorithm_latency_passed", false))
		and crit.get("thermal_passed", null) != false
	)
	_p("iso_verdict_derivable_from_criteria",
		bool(perf.get("iso_25010_compliant", not expect_iso)) == expect_iso,
		"published=%s derived=%s" % [str(perf.get("iso_25010_compliant")), str(expect_iso)])
	# Unmeasured thermal publishes null, not a pass.
	var th_eval: bool = bool(crit.get("thermal_evaluated", true))
	_p("unmeasured_thermal_is_null",
		th_eval or crit.get("thermal_passed", true) == null,
		"evaluated=%s passed=%s" % [str(th_eval), str(crit.get("thermal_passed"))])
	_p("fps_average_matches_live_calc",
		absf(float(fps_blk.get("average_observed", -1.0)) - float(sl.call("_calc_fps_avg"))) < 0.05,
		"file=%s live=%.1f" % [str(fps_blk.get("average_observed")), float(sl.call("_calc_fps_avg"))])
	_check_fps_block_is_self_consistent(fps_blk)

	# 6. Provenance is sticky. A session auto-play touched at any point is not a
	# human-played artifact, and must not be able to export as one later.
	var rc: Dictionary = d.get("run_context", {})
	_p("run_context_present_before_latch", not rc.is_empty(), str(rc))
	sl.set("_auto_play_ever", true)
	var path_c: String = str(sl.call("export_session"))
	var rc2: Dictionary = _read_json(path_c).get("run_context", {})
	_p("latched_auto_play_exports_synthetic",
		bool(rc2.get("auto_play", false)) and bool(rc2.get("synthetic", false)),
		"auto_play=%s synthetic=%s" % [str(rc2.get("auto_play")), str(rc2.get("synthetic"))])
	_p("latch_did_not_add_a_file", path_c == path_a and _count_logs() == logs_after,
		"path=%s logs=%d" % [path_c.get_file(), _count_logs()])
	sl.set("_auto_play_ever", false)

	# This harness is synthetic and its file is not evidence; leave the folder as found.
	# Deleting the file is not enough on its own: SessionLogger exports again on
	# NOTIFICATION_WM_CLOSE_REQUEST, which fires when this harness quits, so the rounds
	# are cleared too and that final export takes the documented empty-skip path. Every
	# assertion above has already read the file by this point.
	if FileAccess.file_exists(path_a):
		DirAccess.remove_absolute(path_a)
	sl.set("sp_games", [])
	sl.set("mp_rounds", [])
	_p("harness_artifact_cleaned_up", _count_logs() == logs_before,
		"logs=%d expected=%d" % [_count_logs(), logs_before])

	_check_export_surface()
	await _check_dev_stats_has_no_export()
	_summary()

## Defect: the phone could not reach the exported files. They were written to
## Downloads/WaterwiseExports/session_logs/<file> - a mixed-case folder the user has to
## guess plus a subfolder, when the instruction on screen said Downloads/waterwise.
## The device block recorded model and platform but no OS version, and that is the one
## field a platform question needs. Android changes its storage rules at API 29, 30 and
## 33, so the phone log that reported a failed Downloads export ("moto e5 plus",
## "Android") could not say which of three causes it was, and the answer had to be
## reasoned out from the model name instead of read off the file.
##
## Asserted against the live OS calls rather than against a hard-coded string, so this
## keeps working on whatever machine runs it - the point is that the export carries the
## same OS identity the engine reports, not that it equals any particular value.
## Every one of these is a CONSISTENCY assertion, never "the device was fast enough":
## a headless run misses the frame budget on purpose and must still satisfy all of
## them. The point is that the published numbers cannot contradict each other or the
## verdict printed beside them, which is what a defence panel reads the block for.
func _check_fps_block_is_self_consistent(f: Dictionary) -> void:
	var lo := float(f.get("minimum_observed", -1.0))
	var av := float(f.get("average_observed", -1.0))
	var hi := float(f.get("maximum_observed", -1.0))
	# This ordering was violated by real exported evidence before the fps block was
	# taken from one series: session_2026-09-03T20-10-53.json published min=1.0,
	# max=1.0 and average=5.7, because min/max came from instantaneous samples while
	# the average came from the profiler's rolling means.
	_p("fps_min_le_avg_le_max", lo <= av + 0.05 and av <= hi + 0.05,
		"min=%.1f avg=%.1f max=%.1f" % [lo, av, hi])
	# The ceiling the average is bounded by. Asserted against the live engine value so
	# it stays true on a capped mobile build (30) and an uncapped desktop one (0).
	_p("fps_publishes_engine_ceiling",
		f.has("engine_max_fps") and int(f.get("engine_max_fps", -1)) == Engine.max_fps,
		"file=%s engine=%d" % [str(f.get("engine_max_fps", "<missing>")), Engine.max_fps])
	_p("fps_budget_is_the_30fps_floor",
		absf(float(f.get("budget_ms", -1.0)) - PerformanceProfiler.FRAME_BUDGET_MS) < 0.01,
		"file=%s const=%.2f" % [str(f.get("budget_ms")), PerformanceProfiler.FRAME_BUDGET_MS])
	var measured := int(f.get("frames_measured", -1))
	var over := int(f.get("frames_over_budget", -1))
	var pct := float(f.get("sustained_at_floor_pct", -1.0))
	_p("fps_frame_counters_present", measured >= 0 and over >= 0 and over <= measured,
		"measured=%d over=%d" % [measured, over])
	var expect_pct := (100.0 * (1.0 - float(over) / float(measured))) if measured > 0 else 0.0
	_p("fps_sustained_rate_matches_counters", absf(pct - expect_pct) < 0.02,
		"published=%.2f%% derived=%.2f%%" % [pct, expect_pct])
	# The verdict follows from the two numbers printed next to it, and from nothing
	# else. It is deliberately NOT the mean test any more - a mean cannot reach 30.0
	# when 30 is the engine cap - but the mean test is still published, so a reader can
	# see both answers.
	var req := float(f.get("sustained_required_pct", -1.0))
	var min_fr := int(f.get("minimum_frames_for_verdict", 0))
	var evaluated: bool = bool(f.get("evaluated", true))
	_p("fps_evaluated_flag_matches_sample_size", evaluated == (measured >= min_fr),
		"evaluated=%s measured=%d minimum=%d" % [str(evaluated), measured, min_fr])
	# Unmeasured publishes null, never true - the same rule thermal follows. A 9-frame
	# headless export used to report 100%% sustained and passed=true at an actual 3FPS.
	var expect_verdict = (pct >= req) if evaluated else null
	_p("fps_verdict_derivable_from_sustained_rate",
		f.get("passed", "<missing>") == expect_verdict,
		"published=%s derived=%s (%.2f%% vs %.2f%%, n=%d)" % [str(f.get("passed")),
			str(expect_verdict), pct, req, measured])
	_p("fps_warmup_split_published",
		int(f.get("frames_total_including_warmup", -1)) >= measured,
		"total=%s post_warmup=%d" % [str(f.get("frames_total_including_warmup")), measured])
	_p("fps_still_publishes_the_mean_test",
		f.has("mean_at_or_above_floor")
			and bool(f.get("mean_at_or_above_floor")) == (av >= float(f.get("minimum_required", 30))),
		"mean_pass=%s avg=%.1f floor=%s" % [str(f.get("mean_at_or_above_floor")), av,
			str(f.get("minimum_required"))])
	_p("fps_keeps_instantaneous_extremes",
		f.has("instantaneous_minimum") and f.has("instantaneous_maximum"),
		"inst_min=%s inst_max=%s" % [str(f.get("instantaneous_minimum", "<missing>")),
			str(f.get("instantaneous_maximum", "<missing>"))])

func _check_device_identifies_os(d: Dictionary) -> void:
	var dev: Dictionary = d.get("device", {})
	_p("artifact_has_device_block", not dev.is_empty(), "keys=%d" % dev.size())
	_p("schema_version_declares_os_fields", str(d.get("schema_version", "")) == "2.2",
		"schema_version=%s" % str(d.get("schema_version")))
	for key in ["os_version", "os_version_alias", "os_distribution"]:
		_p("device.%s recorded" % key,
			dev.has(key) and str(dev.get(key, "")).strip_edges() != "",
			"value='%s'" % str(dev.get(key, "<missing>")))
	_p("device.os_version matches the engine",
		str(dev.get("os_version", "")) == OS.get_version(),
		"file='%s' live='%s'" % [str(dev.get("os_version", "")), OS.get_version()])
	_p("device.os_distribution matches the engine",
		str(dev.get("os_distribution", "")) == OS.get_distribution_name(),
		"file='%s' live='%s'" % [str(dev.get("os_distribution", "")),
			OS.get_distribution_name()])
	# Provenance is only useful if the model/platform half still lands too.
	_p("device still records platform and model",
		str(dev.get("platform", "")) != "" and dev.has("model"),
		"platform='%s' model='%s'" % [str(dev.get("platform", "")),
			str(dev.get("model", "<missing>"))])

func _check_export_surface() -> void:
	_p("export_folder_is_lowercase_waterwise", FileExporter.EXPORT_FOLDER_NAME == "waterwise",
		"folder='%s'" % FileExporter.EXPORT_FOLDER_NAME)
	if not FileExporter.is_external_storage_available():
		_p("export_lands_flat_in_downloads_waterwise", false, "no Downloads dir on this host")
		return
	var base: String = FileExporter._get_external_base_path()
	_p("export_base_path_ends_with_waterwise", base.to_lower().ends_with("/waterwise"), base)

	# Which files were already there, so cleanup removes only what this run wrote.
	var pd := DirAccess.open(base)
	var existed: bool = pd != null
	var pre: Array = [] if pd == null else Array(pd.get_files())

	var res: Dictionary = FileExporter.export_session_data_only()
	_p("export_session_data_only_succeeded", bool(res.get("success", false)),
		"files=%s err=%s" % [str(res.get("files_exported")), str(res.get("error"))])
	_p("export_reports_flat_folder", str(res.get("path", "")).to_lower().ends_with("/waterwise"),
		str(res.get("path")))
	var d2 := DirAccess.open(base)
	var post: Array = [] if d2 == null else Array(d2.get_files())
	# Content, not folder growth. The old assertion here was post.size() > pre.size(),
	# which can only be true the FIRST time a machine exports: the copy overwrites the
	# same filenames, so a second export leaves the count unchanged and a completely
	# correct export reported a failure. Measured - it fired as before=137 after=137 on
	# a folder an earlier export had already filled. What the export actually has to
	# guarantee is that every source log is present in the flat folder with the same
	# bytes, and that is true whether the file is new or overwritten.
	var src_dir := DirAccess.open("user://session_logs")
	var srcs: Array = [] if src_dir == null else Array(src_dir.get_files())
	var missing: Array = []
	var mismatched: Array = []
	for f in srcs:
		var dst: String = base + "/" + str(f)
		if not FileAccess.file_exists(dst):
			missing.append(f)
		elif (FileAccess.get_file_as_bytes(dst)
				!= FileAccess.get_file_as_bytes("user://session_logs/" + str(f))):
			mismatched.append(f)
	_p("every_log_present_flat_in_waterwise",
		srcs.size() > 0 and missing.is_empty() and mismatched.is_empty(),
		"srcs=%d missing=%d mismatched=%d folder_delta=%+d" % [srcs.size(),
			missing.size(), mismatched.size(), post.size() - pre.size()])
	_p("export_reported_every_source_log",
		int(res.get("files_exported", -1)) == srcs.size(),
		"reported=%s srcs=%d" % [str(res.get("files_exported")), srcs.size()])
	_p("no_session_logs_subfolder_created",
		not DirAccess.dir_exists_absolute(base + "/session_logs"),
		base + "/session_logs")

	# Remove only the files this run added, and the folder itself if it was not there.
	var added: int = post.size() - pre.size()
	var removed: int = 0
	for f in post:
		if not pre.has(f):
			if DirAccess.remove_absolute(base + "/" + f) == OK:
				removed += 1
	if not existed:
		DirAccess.remove_absolute(base)
	_p("export_surface_cleaned_up", removed == added,
		"removed=%d added=%d" % [removed, added])

## Defect: exporting had two entry points with different outcomes. Settings ->
## "Export Session Logs" copies to Downloads; the Dev Stats screen's own button called
## export_session(force=true), which wrote only to internal storage. Same words, no copy.
func _check_dev_stats_has_no_export() -> void:
	var ps: PackedScene = load("res://scenes/ui/DevStats.tscn")
	if ps == null:
		_p("dev_stats_scene_loads", false, "res://scenes/ui/DevStats.tscn")
		return
	var inst: Node = ps.instantiate()
	add_child(inst)
	await get_tree().process_frame
	var buttons: Array = []
	_collect_buttons(inst, buttons)
	var export_buttons: Array = []
	for b in buttons:
		if "EXPORT" in str((b as Button).text).to_upper():
			export_buttons.append(str((b as Button).text))
	_p("dev_stats_has_no_export_button", export_buttons.is_empty(),
		"buttons=%d export-labelled=%s" % [buttons.size(), str(export_buttons)])
	var has_back: bool = false
	for b in buttons:
		if "BACK" in str((b as Button).text).to_upper():
			has_back = true
	_p("dev_stats_still_has_back", has_back, "buttons=%d" % buttons.size())
	# The count it used to defer to the export file for is now shown on screen.
	var labels: Array = []
	_collect_labels(inst, labels)
	var scenes_row: String = ""
	for i in range(labels.size()):
		if str((labels[i] as Label).text) == "Scenes Visited:" and i + 1 < labels.size():
			scenes_row = str((labels[i + 1] as Label).text)
	_p("dev_stats_shows_scene_count", scenes_row != "" and scenes_row.is_valid_int(),
		"value='%s'" % scenes_row)

	# The on-screen ISO list scored thermal as a pass on any device with no thermal
	# sensor (cpu_temp_peak 0.0, and 0.0 <= 45.0), counting it toward "N/N checks
	# passed". This host has no sensor, so both thermal rows must read "not measured"
	# and the tally must say how many were measured.
	var sl2: Node = get_node_or_null("/root/SessionLogger")
	var thermal_src: String = str((sl2.call("get_current_summary") as Dictionary)
		.get("thermal_source", "missing"))
	_p("summary_publishes_thermal_source", thermal_src != "missing", "source=%s" % thermal_src)
	if thermal_src != "sensor":
		var iso_lines: Array = []
		for l in labels:
			var t2: String = str((l as Label).text)
			if "CPU Temp" in t2 or "Throttle" in t2 or "ISO/IEC 25010:" in t2:
				iso_lines.append(t2)
		var temp_row: String = ""
		var throttle_row: String = ""
		var tally_row: String = ""
		for t3 in iso_lines:
			if "CPU Temp" in t3:
				temp_row = t3
			elif "Throttle" in t3:
				throttle_row = t3
			elif "ISO/IEC 25010:" in t3:
				tally_row = t3
		_p("unmeasured_thermal_not_ticked_on_screen",
			"not measured" in temp_row and "not measured" in throttle_row
				and not ("✅" in temp_row) and not ("✅" in throttle_row),
			"temp='%s' throttle='%s'" % [temp_row, throttle_row])
		_p("iso_tally_counts_measured_only",
			"measured checks passed" in tally_row and "not measured" in tally_row,
			"tally='%s'" % tally_row)
	inst.queue_free()

func _collect_buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_collect_buttons(c, out)

func _collect_labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append(n)
	for c in n.get_children():
		_collect_labels(c, out)
