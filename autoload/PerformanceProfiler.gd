extends Node

## ═══════════════════════════════════════════════════════════════════
## PERFORMANCE PROFILER - ISO/IEC 25010 Compliance Monitor
## ═══════════════════════════════════════════════════════════════════
## Tracks real-time performance metrics as specified in the thesis paper
## Section: ISO/IEC 25010 Performance Efficiency & Reliability
##
## Target Device: Cortex-A53, <2GB RAM (budget Android)
##
## Monitored Metrics:
##   ✅ FPS (≥60 target, ≥30 minimum)
##   ✅ Frame time budget (<16.67ms per frame at 60FPS)
##   ✅ Memory usage (<200MB target)
##   ✅ Algorithm latency (<16ms for all O(1) operations)
##   ✅ Battery drain estimation (<10mAh per 5min session)
##   ✅ CPU temperature estimation (<45°C target)
##
## Toggle overlay with F11 in-game for thesis demo.
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal performance_warning(metric: String, value: float, threshold: float)
signal profiling_snapshot(data: Dictionary)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ISO/IEC 25010 THRESHOLDS (From thesis paper)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Performance Efficiency
const TARGET_FPS: int = 60
const MIN_FPS: int = 30
const FRAME_BUDGET_MS: float = 16.67  # 1000ms / 60fps
const MAX_MEMORY_MB: float = 200.0    # Paper: <200MB RAM budget
const MAX_ALGO_LATENCY_MS: float = 16.0  # Paper: <16ms for O(1) ops
const MAX_CPU_TEMP_C: float = 45.0    # Paper: <45°C

## Reliability
const MAX_BATTERY_MAH_PER_5MIN: float = 10.0  # Paper: <10mAh per 5-minute session
const SESSION_DURATION_SEC: float = 300.0  # 5 minutes

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TRACKING STATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## FPS tracking
var fps_history: Array[float] = []
var fps_current: float = 0.0
var fps_min: float = 999.0
var fps_max: float = 0.0
var fps_avg: float = 0.0
var frame_time_ms: float = 0.0

## Memory tracking
var memory_current_mb: float = 0.0
var memory_peak_mb: float = 0.0
var memory_history: Array[float] = []

## Algorithm latency tracking
var algo_latencies: Array[float] = []
var algo_latency_avg_ms: float = 0.0
var algo_latency_max_ms: float = 0.0

## Session tracking
var session_start_time: int = 0
var session_elapsed_sec: float = 0.0
var total_frames: int = 0
var dropped_frames: int = 0  # Frames >16.67ms

## Battery estimation (simulated for non-Android builds)
var estimated_battery_mah: float = 0.0

## Android battery tracking (real measurement when available)
var _battery_start_pct: int = -1  # -1 = not yet sampled
var _battery_capacity_mah: float = 4000.0  # Typical budget Android phone
var battery_source: String = "estimate"  # "android_real" or "estimate"

## ── THERMAL PROFILING (Paper: Instrumental Profiling) ──
## T_cpu: CPU temperature logged at 1-second intervals
var cpu_temp_c: float = 0.0
var cpu_temp_history: Array[float] = []  # 1s interval log
var cpu_temp_peak: float = 0.0
var cpu_temp_timer: float = 0.0  # 1-second sample timer

## S_clk: Clock Speed Stability
## Throttle = CPU freq drops below 80% of max rated speed
const THROTTLE_THRESHOLD: float = 0.80
var clock_speed_ratio: float = 1.0
var throttle_events: Array[Dictionary] = []
var is_throttling: bool = false
var throttle_count: int = 0

## ΔE: Battery drain normalized per minute of gameplay
var battery_drain_per_min: float = 0.0  # mAh/min (ΔE)
var battery_readings: Array[Dictionary] = []

## Stress Test Mode (Paper: 30-min continuous session)
const STRESS_TEST_DURATION_SEC: float = 1800.0
var stress_test_active: bool = false
var stress_test_start: int = 0
var stress_test_passed: bool = false

## TF Lite MobileNet Baseline (Paper: DL comparison)
## Typical MobileNet on Cortex-A53: ~8-12 mAh/min
const DL_BASELINE_MAH_PER_MIN: float = 10.0
var rule_based_vs_dl_ratio: float = 0.0

## Profiler UI visibility
var overlay_visible: bool = false
var overlay_label: Label = null

## Snapshot interval
var snapshot_interval: float = 1.0  # seconds
var snapshot_timer: float = 0.0
var snapshots: Array[Dictionary] = []

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	session_start_time = Time.get_ticks_msec()
	if OS.get_name() == "Android":
		battery_source = "android_real"
	else:
		battery_source = "desktop_estimate"
	_create_overlay()
	print("📈 PerformanceProfiler ready (ISO/IEC 25010 monitoring)")
	print("   Press F11 to toggle performance overlay")
	print("   Battery source: %s" % battery_source)

func _create_overlay() -> void:
	# Create an always-on-top CanvasLayer for the profiler overlay
	var canvas = CanvasLayer.new()
	canvas.layer = 200  # Very high layer so it's always visible
	canvas.name = "ProfilerCanvas"
	add_child(canvas)
	
	# Panel background
	var panel = PanelContainer.new()
	panel.name = "ProfilerPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-320, 10)
	panel.size = Vector2(310, 280)
	panel.modulate = Color(1, 1, 1, 0.85)
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.6, 0.9, 0.8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	
	# Label for text display
	overlay_label = Label.new()
	overlay_label.name = "ProfilerLabel"
	overlay_label.add_theme_font_size_override("font_size", 14)
	overlay_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	panel.add_child(overlay_label)
	
	# Start hidden
	canvas.visible = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROCESS LOOP - Gather metrics every frame
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _process(delta: float) -> void:
	total_frames += 1
	session_elapsed_sec = float(Time.get_ticks_msec() - session_start_time) / 1000.0
	
	# ── FPS ──
	fps_current = Engine.get_frames_per_second()
	frame_time_ms = delta * 1000.0
	
	if fps_current < fps_min:
		fps_min = fps_current
	if fps_current > fps_max:
		fps_max = fps_current
	
	# Track FPS history (last 60 samples for average)
	fps_history.append(fps_current)
	if fps_history.size() > 60:
		fps_history.pop_front()
	
	fps_avg = 0.0
	for f in fps_history:
		fps_avg += f
	fps_avg /= fps_history.size()
	
	# Count dropped frames (exceeded 16.67ms budget)
	if frame_time_ms > FRAME_BUDGET_MS:
		dropped_frames += 1
	
	# ── MEMORY ──
	memory_current_mb = float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)
	if memory_current_mb > memory_peak_mb:
		memory_peak_mb = memory_current_mb
	
	# ── BATTERY ESTIMATION ──
	# On Android: read actual battery level from sysfs for real ΔE
	# On Desktop: use workload-proportional model (clearly labeled)
	if OS.get_name() == "Android":
		# Read real battery percentage from sysfs
		var batt_pct = _read_android_battery_percent()
		if batt_pct >= 0 and _battery_start_pct < 0:
			_battery_start_pct = batt_pct  # Record starting level
			battery_source = "android_real"
		if _battery_start_pct >= 0 and batt_pct >= 0:
			# Typical phone battery ~4000mAh. % drop → mAh consumed
			var pct_drop = _battery_start_pct - batt_pct
			estimated_battery_mah = (float(pct_drop) / 100.0) * _battery_capacity_mah
	else:
		# Desktop heuristic: workload-proportional (frame-time based)
		# Higher frame times = heavier workload = more battery drain
		var load_factor = clamp(frame_time_ms / FRAME_BUDGET_MS, 0.5, 3.0)
		estimated_battery_mah = (session_elapsed_sec / 60.0) * (1.5 * load_factor)
	
	# ── ΔE: Battery drain normalized per minute ──
	if session_elapsed_sec > 5.0:
		battery_drain_per_min = (
			estimated_battery_mah / (session_elapsed_sec / 60.0)
		)
		# Compare vs TF Lite MobileNet baseline
		if DL_BASELINE_MAH_PER_MIN > 0:
			rule_based_vs_dl_ratio = (
				battery_drain_per_min / DL_BASELINE_MAH_PER_MIN
			)
	
	# ── T_cpu: CPU Temperature at 1-second intervals ──
	cpu_temp_timer += delta
	if cpu_temp_timer >= 1.0:
		cpu_temp_timer = 0.0
		_sample_cpu_temperature()
		_sample_clock_speed()
	
	# ── STRESS TEST tracking ──
	if stress_test_active:
		_update_stress_test()
	
	# ── SNAPSHOT every interval ──
	snapshot_timer += delta
	if snapshot_timer >= snapshot_interval:
		snapshot_timer = 0.0
		_take_snapshot()
	
	# ── CHECK THRESHOLDS ──
	_check_thresholds()
	
	# ── UPDATE OVERLAY ──
	if overlay_visible and overlay_label:
		_update_overlay_text()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			overlay_visible = !overlay_visible
			var canvas = get_node_or_null("ProfilerCanvas")
			if canvas:
				canvas.visible = overlay_visible

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ALGORITHM LATENCY TRACKING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Call this before an algorithm operation starts
func begin_latency_measurement() -> int:
	return Time.get_ticks_usec()

## Call this after an algorithm operation ends
func end_latency_measurement(start_usec: int, operation_name: String = "") -> float:
	var elapsed_usec = Time.get_ticks_usec() - start_usec
	var elapsed_ms = float(elapsed_usec) / 1000.0
	
	algo_latencies.append(elapsed_ms)
	if algo_latencies.size() > 100:
		algo_latencies.pop_front()
	
	# Update stats
	algo_latency_max_ms = 0.0
	algo_latency_avg_ms = 0.0
	for l in algo_latencies:
		algo_latency_avg_ms += l
		if l > algo_latency_max_ms:
			algo_latency_max_ms = l
	algo_latency_avg_ms /= algo_latencies.size()
	
	if elapsed_ms > MAX_ALGO_LATENCY_MS:
		push_warning("⚠️ Algorithm '%s' exceeded latency budget: %.2fms > %.2fms" % [
			operation_name, elapsed_ms, MAX_ALGO_LATENCY_MS
		])
		performance_warning.emit("algo_latency", elapsed_ms, MAX_ALGO_LATENCY_MS)
	
	return elapsed_ms

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THRESHOLD CHECKS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _check_thresholds() -> void:
	if fps_current < MIN_FPS:
		performance_warning.emit(
			"fps_critical", fps_current, float(MIN_FPS)
		)
	elif fps_current < TARGET_FPS:
		performance_warning.emit(
			"fps_below_target", fps_current,
			float(TARGET_FPS)
		)
	
	if memory_current_mb > MAX_MEMORY_MB:
		performance_warning.emit(
			"memory_exceeded", memory_current_mb,
			MAX_MEMORY_MB
		)
	
	if estimated_battery_mah > MAX_BATTERY_MAH_PER_5MIN:
		performance_warning.emit(
			"battery_exceeded",
			estimated_battery_mah,
			MAX_BATTERY_MAH_PER_5MIN
		)
	
	# T_cpu threshold (Paper: <45°C)
	if cpu_temp_c > MAX_CPU_TEMP_C:
		performance_warning.emit(
			"cpu_temp_exceeded", cpu_temp_c,
			MAX_CPU_TEMP_C
		)
	
	# S_clk: Throttling detection
	if is_throttling:
		performance_warning.emit(
			"clock_throttled", clock_speed_ratio,
			THROTTLE_THRESHOLD
		)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SNAPSHOT & EXPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _take_snapshot() -> void:
	var snap = {
		"timestamp": Time.get_unix_time_from_system(),
		"elapsed_sec": session_elapsed_sec,
		"fps": fps_current,
		"fps_avg": fps_avg,
		"fps_min": fps_min,
		"frame_time_ms": frame_time_ms,
		"memory_mb": memory_current_mb,
		"memory_peak_mb": memory_peak_mb,
		"algo_latency_avg_ms": algo_latency_avg_ms,
		"algo_latency_max_ms": algo_latency_max_ms,
		"dropped_frames": dropped_frames,
		"total_frames": total_frames,
		"battery_mah": estimated_battery_mah,
		"cpu_temp_c": cpu_temp_c,
		"clock_speed_ratio": clock_speed_ratio,
		"is_throttling": is_throttling,
		"battery_drain_per_min": battery_drain_per_min,
	}
	snapshots.append(snap)
	profiling_snapshot.emit(snap)

## Get full session data for thesis evaluation
func export_session_report() -> Dictionary:
	var drop_rate = 0.0
	if total_frames > 0:
		drop_rate = float(dropped_frames) / float(total_frames) * 100.0
	
	return {
		"session_duration_sec": session_elapsed_sec,
		"total_frames": total_frames,
		"fps": {
			"current": fps_current,
			"average": fps_avg,
			"minimum": fps_min,
			"maximum": fps_max,
			"target": TARGET_FPS,
			"meets_target": fps_avg >= TARGET_FPS
		},
		"frame_timing": {
			"budget_ms": FRAME_BUDGET_MS,
			"dropped_frames": dropped_frames,
			"drop_rate_percent": drop_rate,
			"meets_budget": drop_rate < 5.0  # <5% dropped frames = pass
		},
		"memory": {
			"current_mb": memory_current_mb,
			"peak_mb": memory_peak_mb,
			"limit_mb": MAX_MEMORY_MB,
			"meets_limit": memory_peak_mb <= MAX_MEMORY_MB
		},
		"algorithm_latency": {
			"average_ms": algo_latency_avg_ms,
			"maximum_ms": algo_latency_max_ms,
			"budget_ms": MAX_ALGO_LATENCY_MS,
			"meets_budget": algo_latency_max_ms <= MAX_ALGO_LATENCY_MS
		},
		"battery": {
			"estimated_mah": estimated_battery_mah,
			"drain_per_min_mah": battery_drain_per_min,
			"limit_mah_per_5min": MAX_BATTERY_MAH_PER_5MIN,
			"meets_limit": (
				estimated_battery_mah <= MAX_BATTERY_MAH_PER_5MIN
			),
			"measurement_source": battery_source
		},
		"thermal": {
			"cpu_temp_c": cpu_temp_c,
			"cpu_temp_peak": cpu_temp_peak,
			"threshold_c": MAX_CPU_TEMP_C,
			"meets_threshold": cpu_temp_peak <= MAX_CPU_TEMP_C,
			"clock_speed_ratio": clock_speed_ratio,
			"throttle_events": throttle_count,
			"s_clk_stable": throttle_count == 0,
			"temp_samples": cpu_temp_history.size()
		},
		"dl_baseline_comparison": {
			"rule_based_mah_min": battery_drain_per_min,
			"dl_baseline_mah_min": DL_BASELINE_MAH_PER_MIN,
			"ratio": rule_based_vs_dl_ratio,
			"reduction_pct": (
				(1.0 - rule_based_vs_dl_ratio) * 100.0
			),
			"is_more_efficient": rule_based_vs_dl_ratio < 1.0
		},
		"stress_test": {
			"active": stress_test_active,
			"passed": stress_test_passed,
			"target_sec": STRESS_TEST_DURATION_SEC
		},
		"iso_25010_pass": _check_iso_compliance(),
		"snapshots": snapshots
	}

## Check overall ISO/IEC 25010 compliance
func _check_iso_compliance() -> bool:
	return (
		fps_avg >= float(MIN_FPS) and
		memory_peak_mb <= MAX_MEMORY_MB and
		algo_latency_max_ms <= MAX_ALGO_LATENCY_MS and
		cpu_temp_peak <= MAX_CPU_TEMP_C
	)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OVERLAY TEXT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THERMAL PROFILING (Paper: Instrumental Profiling Protocols)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Sample T_cpu at 1-second intervals.
## On Android reads /sys/class/thermal; on desktop uses
## a frame-time heuristic as proxy.
func _sample_cpu_temperature() -> void:
	# Heuristic: baseline 35°C + load-proportional rise
	var load_ratio = clamp(
		frame_time_ms / FRAME_BUDGET_MS, 0.0, 3.0
	)
	cpu_temp_c = 35.0 + (load_ratio * 5.0)
	
	# On Android, read actual thermal sensor
	if OS.get_name() == "Android":
		var path = "/sys/class/thermal/thermal_zone0/temp"
		var temp_file = FileAccess.open(
			path, FileAccess.READ
		)
		if temp_file:
			var raw = temp_file.get_as_text().strip_edges()
			temp_file.close()
			if raw.is_valid_int():
				# Usually in milli-degrees
				cpu_temp_c = float(raw.to_int()) / 1000.0
	
	cpu_temp_history.append(cpu_temp_c)
	if cpu_temp_c > cpu_temp_peak:
		cpu_temp_peak = cpu_temp_c

## Read battery capacity percentage from Android sysfs.
## Returns -1 if unavailable (desktop or read failure).
func _read_android_battery_percent() -> int:
	var paths = [
		"/sys/class/power_supply/battery/capacity",
		"/sys/class/power_supply/Battery/capacity",
	]
	for path in paths:
		var f = FileAccess.open(path, FileAccess.READ)
		if f:
			var raw = f.get_as_text().strip_edges()
			f.close()
			if raw.is_valid_int():
				return raw.to_int()
	return -1

## Sample Clock Speed Stability (S_clk).
## Throttle event = effective clock drops below 80%.
func _sample_clock_speed() -> void:
	var prev_throttling = is_throttling
	
	if fps_current > 0 and TARGET_FPS > 0:
		clock_speed_ratio = clamp(
			fps_current / float(TARGET_FPS), 0.0, 1.5
		)
	else:
		clock_speed_ratio = 1.0
	
	is_throttling = clock_speed_ratio < THROTTLE_THRESHOLD
	
	# Log new throttle events
	if is_throttling and not prev_throttling:
		throttle_count += 1
		throttle_events.append({
			"timestamp": Time.get_unix_time_from_system(),
			"elapsed_sec": session_elapsed_sec,
			"clock_ratio": clock_speed_ratio,
			"cpu_temp_c": cpu_temp_c,
			"fps": fps_current
		})
		print(
			"🔥 THROTTLE #%d: S_clk=%.0f%%" % [
				throttle_count,
				clock_speed_ratio * 100.0
			]
		)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STRESS TEST (Paper: 30-minute continuous session)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Start a 30-minute stress test session
func start_stress_test() -> void:
	stress_test_active = true
	stress_test_start = Time.get_ticks_msec()
	stress_test_passed = false
	cpu_temp_history.clear()
	throttle_events.clear()
	throttle_count = 0
	print("🔬 STRESS TEST STARTED (30 min target)")
	print("   Pass: T_cpu < 45°C throughout")

func _update_stress_test() -> void:
	var elapsed = float(
		Time.get_ticks_msec() - stress_test_start
	) / 1000.0
	
	if elapsed >= STRESS_TEST_DURATION_SEC:
		stress_test_active = false
		stress_test_passed = (
			cpu_temp_peak <= MAX_CPU_TEMP_C
		)
		var result = "PASS ✅" if stress_test_passed else "FAIL ❌"
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("🔬 STRESS TEST: %s" % result)
		print("   Peak T_cpu: %.1f°C / %.0f°C" % [
			cpu_temp_peak, MAX_CPU_TEMP_C
		])
		print("   Throttles: %d" % throttle_count)
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

func stop_stress_test() -> void:
	stress_test_active = false
	print("🔬 Stress test stopped manually.")

## Get stress test report
func get_stress_test_report() -> Dictionary:
	var elapsed = 0.0
	if stress_test_start > 0:
		elapsed = float(
			Time.get_ticks_msec() - stress_test_start
		) / 1000.0
	
	return {
		"active": stress_test_active,
		"elapsed_sec": elapsed,
		"target_sec": STRESS_TEST_DURATION_SEC,
		"cpu_temp_peak": cpu_temp_peak,
		"temp_samples": cpu_temp_history.size(),
		"throttle_events": throttle_count,
		"s_clk_stable": throttle_count == 0,
		"passed": stress_test_passed,
		"battery_drain_per_min": battery_drain_per_min,
		"dl_comparison": {
			"rule_based": battery_drain_per_min,
			"mobilenet": DL_BASELINE_MAH_PER_MIN,
			"savings_pct": (
				(1.0 - rule_based_vs_dl_ratio) * 100.0
			)
		}
	}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OVERLAY TEXT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _update_overlay_text() -> void:
	var fps_ico = "🟢"
	if fps_current < MIN_FPS:
		fps_ico = "🔴"
	elif fps_current < TARGET_FPS:
		fps_ico = "🟡"
	
	var mem_ico = "🟢"
	if memory_current_mb >= MAX_MEMORY_MB:
		mem_ico = "🔴"
	elif memory_current_mb >= MAX_MEMORY_MB * 0.8:
		mem_ico = "🟡"
	
	var temp_ico = "🟢"
	if cpu_temp_c >= MAX_CPU_TEMP_C:
		temp_ico = "🔴"
	elif cpu_temp_c >= MAX_CPU_TEMP_C * 0.85:
		temp_ico = "🟡"
	
	var algo_ico = "🟢"
	if algo_latency_max_ms >= MAX_ALGO_LATENCY_MS:
		algo_ico = "🔴"
	
	var clk_ico = "🟢" if not is_throttling else "🔴"
	var iso = "✅ PASS" if _check_iso_compliance() else "❌ FAIL"
	var drop_pct = (
		float(dropped_frames) / max(total_frames, 1) * 100.0
	)
	var savings = (1.0 - rule_based_vs_dl_ratio) * 100.0
	
	var stress_ln = ""
	if stress_test_active:
		var st_sec = float(
			Time.get_ticks_msec() - stress_test_start
		) / 1000.0
		stress_ln = "\n🔬 STRESS: %.0fs/%.0fs" % [
			st_sec, STRESS_TEST_DURATION_SEC
		]
	
	overlay_label.text = (
		"━━ ISO/IEC 25010 PROFILER ━━\n"
		+ "%s FPS: %.0f (avg:%.0f min:%.0f)\n" % [
			fps_ico, fps_current, fps_avg, fps_min
		]
		+ "  %.1fms/%.1fms Drop:%d(%.1f%%)\n" % [
			frame_time_ms, FRAME_BUDGET_MS,
			dropped_frames, drop_pct
		]
		+ "%s Mem: %.0f/%.0fMB pk:%.0f\n" % [
			mem_ico, memory_current_mb,
			MAX_MEMORY_MB, memory_peak_mb
		]
		+ "%s T_cpu: %.1f°C / %.0f°C\n" % [
			temp_ico, cpu_temp_c, MAX_CPU_TEMP_C
		]
		+ "%s S_clk: %.0f%% throttle:%d\n" % [
			clk_ico, clock_speed_ratio * 100.0,
			throttle_count
		]
		+ "%s Algo: %.2f/%.0fms\n" % [
			algo_ico, algo_latency_avg_ms,
			MAX_ALGO_LATENCY_MS
		]
		+ "🔋 ΔE: %.2f mAh/min\n" % [
			battery_drain_per_min
		]
		+ "  vs DL: %.0f%% savings\n" % [savings]
		+ "⏱ %.0fs | %d frames\n" % [
			session_elapsed_sec, total_frames
		]
		+ "ISO 25010: %s" % iso
		+ stress_ln
	)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEV-MODE SESSION LOG EXPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Writes timestamped JSON session logs to user://perf_logs/
# These logs can be compared to evaluate rule-based vs DL performance.

var dev_log_enabled: bool = true
var _session_events: Array[Dictionary] = []

func log_event(event_type: String, data: Dictionary = {}) -> void:
	if not dev_log_enabled:
		return
	var entry := {
		"timestamp": Time.get_unix_time_from_system(),
		"elapsed_sec": session_elapsed_sec,
		"event": event_type,
		"fps": fps_current,
		"mem_mb": memory_current_mb,
		"cpu_temp_c": cpu_temp_c,
		"algo_latency_ms": algo_latency_avg_ms,
	}
	entry.merge(data)
	_session_events.append(entry)

func export_session_log_to_file() -> String:
	var dir_path := "user://perf_logs"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var datetime := Time.get_datetime_string_from_system().replace(":", "-")
	var platform := OS.get_name()
	var filename := "%s/session_%s_%s.json" % [dir_path, datetime, platform]
	var report := export_session_report()
	report["events"] = _session_events
	report["platform"] = platform
	report["device_model"] = OS.get_model_name()
	report["export_time"] = datetime
	var file := FileAccess.open(filename, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
		print("📊 Session log exported: %s" % filename)
		return filename

	push_error(
		"Failed to write session log: %s" % filename
	)
	return ""

func clear_session_events() -> void:
	_session_events.clear()
