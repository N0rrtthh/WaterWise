extends Node

## VerifyStressVerdict — the 30-minute thermal stress test must not report a result
## it never measured.
##
## Defect reproduced before this harness existed: _update_stress_test computed
##
##     stress_test_passed = (cpu_temp_peak <= MAX_CPU_TEMP_C)
##
## and on any machine without a thermal sensor cpu_temp_peak never leaves 0.0, so
## 0.0 <= 45.0 printed
##
##     🔬 STRESS TEST: PASS ✅
##        Peak T_cpu: 0.0°C / 45°C
##
## i.e. a 30-minute thermal pass from a run that read no temperature at all. The
## same expression also published "meets_threshold": true in the exported session
## report's thermal block. That is the prohibited "fake performance metric", and it
## contradicted this very file's _check_iso_compliance, which already carried
## "# Only fail on thermal if we have real sensor data".
##
## What is checked here:
##   1. Lifecycle states are honest: not_run -> running -> aborted on a manual stop.
##   2. On this (sensor-less) machine a COMPLETED stress test is INCONCLUSIVE, not a
##      pass, and stress_test_passed is false.
##   3. THE OLD EXPRESSION IS SHOWN TO BE TRUE at that same moment — proof the
##      defect was real and is now gone, not that the machine happens to be cool.
##   4. Positive control, because a criterion that can no longer say "pass" is not
##      fixed but disabled: with _thermal_source forced to "sensor" the verdict is
##      "pass" at 30 °C and "fail" at 60 °C. Both are restored afterwards.
##   5. Both report dictionaries publish "verdict" + "thermal_source", and the
##      thermal block's "meets_threshold" is null (not evaluated) without a sensor.
##
## Elapsed time is advanced by rewinding stress_test_start, NOT by faking any
## temperature: every number the verdict is computed from is the profiler's own.

var passed: int = 0
var failed: int = 0


func _ready() -> void:
	print("=== VERIFY STRESS TEST VERDICT ===")
	print("thermal_source on this machine: %s" % PerformanceProfiler.get_thermal_source())
	print("has_thermal_sensor_data(): %s" % str(PerformanceProfiler.has_thermal_sensor_data()))
	print("")

	await _check_lifecycle()
	await _check_completion_without_sensor()
	await _check_positive_control()
	_check_reports()

	print("")
	print("=== %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("  [PASS] %s" % label)
	else:
		failed += 1
		print("  [FAIL] %s" % label)
		if detail != "":
			print("      %s" % detail)

# ── 1. lifecycle ────────────────────────────────────────────────────────────

func _check_lifecycle() -> void:
	print("── lifecycle states ──")
	_check("a fresh session reports 'not_run'",
		PerformanceProfiler.stress_test_verdict == "not_run",
		"verdict = %s" % PerformanceProfiler.stress_test_verdict)

	PerformanceProfiler.start_stress_test()
	_check("a started test reports 'running'",
		PerformanceProfiler.stress_test_verdict == "running",
		"verdict = %s" % PerformanceProfiler.stress_test_verdict)
	_check("a started test does not yet claim passed",
		not PerformanceProfiler.stress_test_passed)

	PerformanceProfiler.stop_stress_test()
	_check("a manually stopped test reports 'aborted', not 'running' or a pass",
		PerformanceProfiler.stress_test_verdict == "aborted",
		"verdict = %s — a stale 'running' reads as still in progress"
			% PerformanceProfiler.stress_test_verdict)
	_check("an aborted test does not claim passed",
		not PerformanceProfiler.stress_test_passed)
	await get_tree().process_frame

# ── 2. completion with no sensor ────────────────────────────────────────────

func _check_completion_without_sensor() -> void:
	print("")
	print("── a COMPLETED 30-minute test on a machine with no thermal sensor ──")
	if PerformanceProfiler.has_thermal_sensor_data():
		print("  ... skipped: this machine HAS a thermal sensor, so the no-sensor path")
		print("    cannot be exercised honestly here.")
		return

	PerformanceProfiler.start_stress_test()
	# Advance the clock only. Rewinding the start stamp past the full duration is
	# what makes _update_stress_test finish on the next frame; no temperature,
	# frame time or throttle number is touched.
	var dur_ms: int = int(PerformanceProfiler.STRESS_TEST_DURATION_SEC * 1000.0) + 250
	PerformanceProfiler.stress_test_start -= dur_ms
	await get_tree().process_frame
	await get_tree().process_frame

	var v: String = PerformanceProfiler.stress_test_verdict
	_check("the test actually ran to completion (control)",
		not PerformanceProfiler.stress_test_active and v != "running",
		"active=%s verdict=%s — the checks below would be vacuous"
			% [str(PerformanceProfiler.stress_test_active), v])
	_check("the verdict is 'inconclusive_no_thermal_sensor'",
		v == "inconclusive_no_thermal_sensor",
		"verdict = %s (thermal_source = %s)"
			% [v, PerformanceProfiler.get_thermal_source()])
	_check("stress_test_passed is false, so no reader can see a pass",
		not PerformanceProfiler.stress_test_passed)

	# Proof the defect was real, evaluated at the same instant as the verdict above.
	var old_expr: bool = (
		PerformanceProfiler.cpu_temp_peak <= PerformanceProfiler.MAX_CPU_TEMP_C
	)
	_check("the OLD expression would have said PASS right here",
		old_expr,
		("cpu_temp_peak=%.1f MAX=%.1f — if this is false the machine is not "
			+ "reproducing the defect and the check above proves nothing")
			% [PerformanceProfiler.cpu_temp_peak, PerformanceProfiler.MAX_CPU_TEMP_C])
	print("    (cpu_temp_peak = %.1f C from %d samples, source = %s)" % [
		PerformanceProfiler.cpu_temp_peak,
		PerformanceProfiler.cpu_temp_history.size(),
		PerformanceProfiler.get_thermal_source()])

# ── 3. positive control ─────────────────────────────────────────────────────

func _check_positive_control() -> void:
	print("")
	print("── positive control: the 45 C criterion still decides when a sensor exists ──")
	var saved_source: String = PerformanceProfiler._thermal_source
	var saved_peak: float = PerformanceProfiler.cpu_temp_peak
	var cases: Array = [
		{"peak": 30.0, "want": "pass"},
		{"peak": 60.0, "want": "fail"},
	]

	for case in cases:
		PerformanceProfiler.start_stress_test()
		# start_stress_test clears the history but not the peak; set both AFTER it.
		PerformanceProfiler._thermal_source = "sensor"
		PerformanceProfiler.cpu_temp_peak = float(case["peak"])
		var dur_ms: int = int(PerformanceProfiler.STRESS_TEST_DURATION_SEC * 1000.0) + 250
		PerformanceProfiler.stress_test_start -= dur_ms
		await get_tree().process_frame
		await get_tree().process_frame
		var v: String = PerformanceProfiler.stress_test_verdict
		_check("peak %.0f C with a sensor -> '%s'" % [float(case["peak"]), case["want"]],
			v == case["want"],
			"verdict = %s — the guard disabled the criterion instead of narrowing it" % v)

	PerformanceProfiler._thermal_source = saved_source
	PerformanceProfiler.cpu_temp_peak = saved_peak

# ── 4. what the reports publish ─────────────────────────────────────────────

func _check_reports() -> void:
	print("")
	print("── published report fields ──")
	var st: Dictionary = PerformanceProfiler.get_stress_test_report()
	_check("get_stress_test_report() publishes 'verdict'", st.has("verdict"))
	_check("get_stress_test_report() publishes 'thermal_source'", st.has("thermal_source"))

	var rep: Dictionary = PerformanceProfiler.export_session_report()
	var s: Dictionary = rep.get("stress_test", {})
	_check("export_session_report().stress_test publishes 'verdict'", s.has("verdict"))
	_check("export_session_report().stress_test publishes 'thermal_source'",
		s.has("thermal_source"))

	var th: Dictionary = rep.get("thermal", {})
	if PerformanceProfiler.has_thermal_sensor_data():
		_check("thermal.meets_threshold is a bool when a sensor exists",
			typeof(th.get("meets_threshold")) == TYPE_BOOL)
	else:
		_check("thermal.meets_threshold is null (not evaluated) with no sensor",
			th.get("meets_threshold") == null,
			"meets_threshold = %s — 0.0 C <= 45 C published as a thermal pass"
				% str(th.get("meets_threshold")))
	print("    thermal block: peak=%.1f source=%s meets_threshold=%s" % [
		float(th.get("cpu_temp_peak", 0.0)),
		str(th.get("thermal_source", "?")),
		str(th.get("meets_threshold"))])

	# ── the same defect, in the other three published criteria ──
	#
	# Every one of these was a "0.0 <= limit" that read true on a machine that took
	# no measurement. They are checked here rather than in a separate harness
	# because they share one rule: a criterion nothing measured must publish null,
	# not a pass.
	var measured_batt: bool = PerformanceProfiler.battery_source == "android_sysfs"
	var bat: Dictionary = rep.get("battery", {})
	if measured_batt:
		_check("battery.meets_limit is a bool when sysfs was readable",
			typeof(bat.get("meets_limit")) == TYPE_BOOL)
	else:
		_check("battery.meets_limit is null with no battery measurement",
			bat.get("meets_limit") == null,
			"meets_limit = %s from estimated_mah = %s (source %s)" % [
				str(bat.get("meets_limit")), str(bat.get("estimated_mah")),
				str(bat.get("measurement_source"))])

	var dl: Dictionary = rep.get("dl_baseline_comparison", {})
	if measured_batt and PerformanceProfiler.battery_drain_per_min > 0.0:
		_check("dl_baseline_comparison.is_more_efficient is a bool when ΔE was measured",
			typeof(dl.get("is_more_efficient")) == TYPE_BOOL)
	else:
		_check("dl_baseline_comparison publishes no efficiency claim with no ΔE",
			dl.get("is_more_efficient") == null and dl.get("reduction_pct") == null,
			"is_more_efficient=%s reduction_pct=%s — a %s%% energy saving over"
				% [str(dl.get("is_more_efficient")), str(dl.get("reduction_pct")),
					str(dl.get("reduction_pct"))]
				+ " MobileNet from a run that measured no milliamp")
		_check("the OLD DL expression would have claimed a 100% saving here",
			is_equal_approx((1.0 - PerformanceProfiler.rule_based_vs_dl_ratio) * 100.0, 100.0),
			"ratio = %f — not reproducing the defect" % PerformanceProfiler.rule_based_vs_dl_ratio)

	# SessionLogger has no in-memory report accessor — export_session() builds the
	# dict and writes it. Reading the file back is the stronger check anyway: it is
	# the actual artifact a defence panel would open.
	var sl_path: String = ""
	if SessionLogger and SessionLogger.has_method("export_session"):
		sl_path = SessionLogger.export_session(true)
	var sl_rep: Dictionary = {}
	if sl_path != "":
		var f := FileAccess.open(sl_path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				sl_rep = parsed
	if sl_rep.is_empty():
		_check("the exported session log could be read back (control)", false,
			"path = '%s' — the SessionLogger checks below cannot run" % sl_path)
	else:
		print("    session log: %s" % sl_path)
		var sl_th: Dictionary = sl_rep.get("performance", {}).get("thermal", {})
		if PerformanceProfiler.has_thermal_sensor_data():
			_check("SessionLogger thermal.passed is a bool when a sensor exists",
				typeof(sl_th.get("passed")) == TYPE_BOOL)
		else:
			_check("SessionLogger thermal.passed is null with no sensor",
				sl_th.get("passed") == null,
				"passed = %s (peak_c = %s, source = %s)" % [
					str(sl_th.get("passed")), str(sl_th.get("peak_c")),
					str(sl_th.get("thermal_source"))])
			_check("SessionLogger still reports the measured S_clk half as a bool",
				typeof(sl_th.get("s_clk_stable")) == TYPE_BOOL,
				"s_clk_stable = %s — the guard removed a metric that IS measured"
					% str(sl_th.get("s_clk_stable")))

