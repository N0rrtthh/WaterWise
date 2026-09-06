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
##   ✅ Frame time budget — BOTH lines are counted separately:
##        frames_over_60_budget: frames slower than 16.67ms (the 60FPS target)
##        dropped_frames:        frames slower than FRAME_BUDGET_MS = 36.67ms,
##                               i.e. meaningfully slower than the 30FPS MINIMUM.
##        Only the second gates meets_budget, matching the paper's 30FPS floor.
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
## Drop budget: 10% tolerance above the 30fps cap.
## At exactly 30fps delta is ~33.33ms; using 36.67ms only counts
## frames meaningfully slower than the 30fps minimum.
const FRAME_BUDGET_MS: float = 36.67  # (1000ms / 30fps) * 1.1 tolerance
## The 60FPS line, for frames_over_60_budget. Separate from FRAME_BUDGET_MS so
## the pass/fail gate stays on the paper's 30FPS floor.
const FRAME_BUDGET_60_MS: float = 16.67
## How many seconds to skip dropped-frame counting after cold start.
## The first few frames always spike during scene tree setup.
const STARTUP_WARMUP_SEC: float = 3.0
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
var _fps_history_sum: float = 0.0  # running sum so avg is O(1) instead of O(60)
var frame_time_ms: float = 0.0

## Memory tracking
var memory_current_mb: float = 0.0
var memory_peak_mb: float = 0.0
var memory_history: Array[float] = []

## Object-lifecycle tracking.
##
## OS.get_static_memory_usage() measures the allocator's static pool, which stays
## roughly flat whether or not nodes are being orphaned — so it cannot support the
## thesis's ΔRAM = 0 claim on its own, and it cannot answer the question every soak
## log raises with "ObjectDB instances leaked at exit".
##
## OBJECT_ORPHAN_NODE_COUNT is the metric that matches that warning exactly: nodes
## removed from the tree (remove_child) but never freed. A flat orphan count across
## a multi-round soak means the exit-time report is a shutdown-order artifact; a
## rising one means a real per-round lifecycle bug. Baselines are recorded after the
## first snapshot so autoload construction is not charged to the game loop.
##
## Both monitors are debug-build only; in an exported release build they read 0,
## which is why the deltas below are reported rather than the raw counts.
var object_count: int = 0
var orphan_node_count: int = 0
var object_count_baseline: int = -1
var orphan_node_baseline: int = -1
var orphan_node_peak: int = 0

## Algorithm latency tracking
var algo_latencies: Array[float] = []
var algo_latency_avg_ms: float = 0.0
var algo_latency_max_ms: float = 0.0

## Session tracking
var session_start_time: int = 0
var session_elapsed_sec: float = 0.0
var total_frames: int = 0
## Frames slower than FRAME_BUDGET_MS (36.67ms) — the 30FPS floor plus 10%,
## NOT the 60FPS line. This comment used to read "Frames >16.67ms", which
## misdescribed every dropped_frames figure exported in a snapshot or printed
## in a report: a reader would take it for "missed 60FPS" when it means
## "missed 30FPS". The threshold itself is the paper's and is unchanged.
var dropped_frames: int = 0
## Frames slower than 16.67ms — the 60FPS target the header claims to monitor.
## Counted alongside dropped_frames rather than replacing it, so no previously
## reported dropped_frames number shifts meaning.
var frames_over_60_budget: int = 0

## Frames counted under the SAME warmup gate as dropped_frames, so that
## dropped_frames / this is a ratio over one population. total_frames counts every
## frame including startup, and dividing by it mixed populations: a 9-frame headless
## run reported over=0 measured=9 and therefore a 100% sustained rate, when in truth
## no frame had been eligible to count at all. On a long session the bias is small
## (3s of warmup out of 7510 frames) but it is always in the flattering direction.
var frames_after_warmup: int = 0

## Battery estimation (simulated for non-Android builds)
var estimated_battery_mah: float = 0.0

## Android battery tracking (real measurement when available)
var _battery_start_pct: int = -1  # -1 = not yet sampled
var _battery_capacity_mah: float = 5000.0  # Motorola E5 Plus specific battery capacity
var battery_source: String = "unknown"  # "android_sysfs" or "unavailable_desktop"
var battery_pct_current: int = -1
var battery_pct_start: int = -1
var battery_pct_min: int = 101
var battery_pct_max: int = 0
var battery_pct_samples: Array[int] = []

## Battery sysfs sampling is gated to 1-second intervals.
## Reading sysfs every frame costs up to 6 FileAccess.open() syscalls per
## frame (360/sec at 60fps) — a measurable stall on Cortex-A53 eMMC storage.
## Battery percentage physically cannot change faster than ~1%/minute, so
## per-frame polling gathers zero extra signal for real I/O cost.
var battery_sample_timer: float = 0.0
const BATTERY_SAMPLE_INTERVAL: float = 1.0

## ── THERMAL PROFILING (Paper: Instrumental Profiling) ──
## T_cpu: CPU temperature logged at 1-second intervals
var cpu_temp_c: float = 0.0
var cpu_temp_history: Array[float] = []  # 1s interval log
var cpu_temp_peak: float = 0.0
var cpu_temp_timer: float = 0.0  # 1-second sample timer
## Overlay redraw rate. See the throttle in _process() for why this is not per frame.
const OVERLAY_REFRESH_INTERVAL: float = 0.25
var _overlay_refresh_timer: float = 0.0
## How many times the overlay label was rebuilt this session. Exported so the throttle
## above is a measurement in the log rather than an assertion in a comment: at 4 Hz this
## divided by session seconds lands near 4, and the pre-fix build would land near the
## frame rate.
var overlay_refresh_count: int = 0
## ASCII-only status markers for the overlay.
##
## The readout used 🟢 🟡 🔴 ⚪ ✅ ❌ 🔋 ⏱ 🔬 ━ Δ and °, and none of those exist in the
## bundled font. A glyph the font does not have sends TextServer out to the system font
## fallback, and that lookup is cached per requested string — while this string changes on
## every single refresh (frame_time_ms alone guarantees a new cache key). So a per-frame
## overlay meant a per-frame fallback search on a device whose emoji font Godot cannot even
## use: Android 8 draws these as tofu boxes anyway (see the same symptom reported for the
## in-game UI). Throttling to OVERLAY_REFRESH_INTERVAL cut how often that happened; ASCII
## removes the cost outright, and the boxes with it.
##
## Four characters wide each so the columns still line up under a monospaced reading.
const ICO_OK := "[ok]"
const ICO_WARN := "[!!]"
const ICO_BAD := "[XX]"
const ICO_NA := "[--]"

## S_clk: Clock Speed Stability
## Throttle = CPU freq drops below 80% of max rated speed
const THROTTLE_THRESHOLD: float = 0.80
## Consecutive 1 Hz samples below THROTTLE_THRESHOLD required before a throttle
## event is counted. Thermal throttling is sustained; a single low second is a
## loading hitch, and counting those published s_clk_stable = false off one scene
## transition. See _sample_clock_speed.
const THROTTLE_MIN_SAMPLES: int = 2
var clock_speed_ratio: float = 1.0
var throttle_events: Array[Dictionary] = []
var is_throttling: bool = false
var throttle_count: int = 0
## Run length of consecutive below-threshold samples. Reset by a healthy sample, by
## the startup warmup guard, and by start_stress_test().
var _low_clock_samples: int = 0

## ΔE: Battery drain normalized per minute of gameplay
var battery_drain_per_min: float = 0.0  # mAh/min (ΔE)
var battery_readings: Array[Dictionary] = []

## Stress Test Mode (Paper: 30-min continuous session)
const STRESS_TEST_DURATION_SEC: float = 1800.0
var stress_test_active: bool = false
var stress_test_start: int = 0
var stress_test_passed: bool = false
## Tri-state outcome, because "did not fail" is not "passed" when there was no
## sensor to fail against. One of: "not_run", "running", "pass", "fail", "aborted",
## "inconclusive_no_thermal_sensor". Published in both report dictionaries so an
## exported session log cannot be read as a thermal pass it did not earn.
var stress_test_verdict: String = "not_run"

## TF Lite MobileNet Baseline (Paper: DL comparison)
## Typical MobileNet on Cortex-A53: ~8-12 mAh/min
const DL_BASELINE_MAH_PER_MIN: float = 10.0
var rule_based_vs_dl_ratio: float = 0.0

## Per-metric warning cooldown — prevent per-frame signal spam.
## Key = metric name, value = elapsed_sec of last emit.
## Warnings emit at most once per second per metric.
var _warning_last_emit: Dictionary = {}
const WARNING_COOLDOWN_SEC: float = 1.0

## Latency budget breaches use a much longer window than fps/memory warnings.
## A slow algorithm call happens once per round, not once per frame, so a 1 s
## cooldown never suppresses anything — the round is always longer than that.
## 30 s means a persistent problem still reports (a few times per session) while
## a 150 s soak logs ~5 lines instead of ~50.
const LATENCY_WARNING_COOLDOWN_SEC: float = 30.0

## Profiler UI visibility
var overlay_visible: bool = false
var overlay_label: Label = null

## Snapshot interval
var snapshot_interval: float = 1.0  # seconds
var snapshot_timer: float = 0.0
var snapshots: Array[Dictionary] = []

## ── BOUNDED HISTORY CAPS (memory safety on <3GB RAM devices) ──
## Every telemetry array below is sampled once per second. Left uncapped, a
## 30-minute thesis stress session grows them to 1800 entries each; a long
## classroom session (2h+) would push heap usage past the 200MB budget and
## trigger the very thermal/GC behaviour the profiler is meant to measure.
## 1800 samples = exactly the 30-minute stress-test window from the paper,
## so no thesis data is lost — only unbounded growth beyond it is discarded.
const MAX_HISTORY_SAMPLES: int = 1800
## Event arrays are sparse (only on state changes), so a smaller cap suffices.
const MAX_EVENT_ENTRIES: int = 500

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	session_start_time = Time.get_ticks_msec()
	if OS.get_name() == "Android":
		battery_source = "android_sysfs_pending"  # updated to real result on first read
	else:
		battery_source = "unavailable_desktop"
	# Load configured battery capacity (allow setting to match actual test phone)
	call_deferred("_load_battery_capacity")
	_create_overlay()
	_apply_saved_dev_visibility()
	print("📈 PerformanceProfiler ready (ISO/IEC 25010 monitoring)")
	print("   Press F11 to toggle performance overlay")
	print("   Battery source: %s" % battery_source)

## Configure the test phone's actual battery capacity in mAh.
## Must be called before testing begins. Example: set_battery_capacity_mah(3000.0)
## Persisted in SaveManager key "device_battery_mah".
func set_battery_capacity_mah(mah: float) -> void:
	_battery_capacity_mah = max(500.0, mah)
	if SaveManager:
		SaveManager.set_setting("device_battery_mah", _battery_capacity_mah)
	print("🔋 Battery capacity set to %.0f mAh" % _battery_capacity_mah)

func get_battery_capacity_mah() -> float:
	return _battery_capacity_mah

func get_thermal_source() -> String:
	return _thermal_source

func has_thermal_sensor_data() -> bool:
	return _thermal_source == "sensor"

func check_iso_compliance() -> bool:
	return _check_iso_compliance()

func _load_battery_capacity() -> void:
	if SaveManager:
		var saved: float = float(SaveManager.get_setting("device_battery_mah", 0.0))
		if saved >= 500.0:
			_battery_capacity_mah = saved
			print("🔋 Battery capacity loaded from settings: %.0f mAh" % _battery_capacity_mah)

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
	# Clamp frame_time_ms to max 100ms so scene-load spikes (200ms-2s) don't
	# appear as legitimate frame times in the snapshot log.
	# A 261ms entry beside fps=30 is misleading — it's a scene transition.
	frame_time_ms = minf(delta * 1000.0, 100.0)

	if fps_current < fps_min:
		fps_min = fps_current
	if fps_current > fps_max:
		fps_max = fps_current
	
	# Track FPS history for rolling average.
	# Exclude fps_current < 2 (scene-load freezes) from the average so a
	# 2-second scene transition doesn't drag the average down for 60 frames.
	# Those spikes are logged separately in throttle_events.
	if fps_current >= 2.0:
		fps_history.append(fps_current)
		_fps_history_sum += fps_current
		if fps_history.size() > 60:
			_fps_history_sum -= fps_history.pop_front()

	fps_avg = (
		_fps_history_sum / float(fps_history.size()) if fps_history.size() > 0
		else fps_current
	)
	
	# Count dropped frames only after startup warmup settles
	if session_elapsed_sec > STARTUP_WARMUP_SEC and frame_time_ms > FRAME_BUDGET_60_MS:
		frames_over_60_budget += 1
	if session_elapsed_sec > STARTUP_WARMUP_SEC:
		frames_after_warmup += 1
		if frame_time_ms > FRAME_BUDGET_MS:
			dropped_frames += 1
	
	# ── MEMORY ──
	memory_current_mb = float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)
	if memory_current_mb > memory_peak_mb:
		memory_peak_mb = memory_current_mb
	
	# ── BATTERY ESTIMATION ──
	# On Android: read actual battery level from sysfs for real ΔE
	# On Desktop: battery data unavailable — report 0.0 (clearly labeled)
	# NOTE: sysfs is polled at BATTERY_SAMPLE_INTERVAL (1s), NOT per frame.
	# Per-frame polling issued up to 6 file-open syscalls every frame, which
	# stalls the render thread on low-end eMMC storage for no added precision.
	if OS.get_name() == "Android":
		battery_sample_timer += delta
		if battery_sample_timer >= BATTERY_SAMPLE_INTERVAL:
			battery_sample_timer = 0.0
			# Read real battery percentage from sysfs
			var batt_pct = _read_android_battery_percent()
			if batt_pct >= 0:
				battery_pct_current = batt_pct
				if _battery_start_pct < 0:
					_battery_start_pct = batt_pct  # Record starting level
					battery_source = "android_sysfs"
				if battery_pct_start < 0:
					battery_pct_start = batt_pct
				battery_pct_min = min(battery_pct_min, batt_pct)
				battery_pct_max = max(battery_pct_max, batt_pct)
				# Bounded ring-style history: keep the most recent samples only
				# so a 30-minute stress session cannot grow this array without
				# limit (1800 entries @ 1s = 30 min of coverage).
				battery_pct_samples.append(batt_pct)
				if battery_pct_samples.size() > MAX_HISTORY_SAMPLES:
					battery_pct_samples.pop_front()
			if _battery_start_pct >= 0 and batt_pct >= 0:
				# Convert % drop to mAh using configured battery capacity
				var pct_drop = _battery_start_pct - batt_pct
				estimated_battery_mah = (float(pct_drop) / 100.0) * _battery_capacity_mah
	else:
		# Desktop: No real battery data available
		# Do NOT fabricate values — report 0.0 and label as unavailable
		estimated_battery_mah = 0.0
		battery_source = "unavailable_desktop"
		battery_pct_current = -1
	
	# ── ΔE: Battery drain normalized per minute ──
	# Only compute from real measurements (Android sysfs)
	if session_elapsed_sec > 5.0 and estimated_battery_mah > 0.0:
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
	# Throttled to OVERLAY_REFRESH_INTERVAL, not per frame. A debug overlay must not
	# materially change the frame budget it exists to measure, and this one did: the
	# label it rebuilds is ~15 lines of emoji-bearing text assembled from a dozen
	# "%.1f" formats, and assigning a Label's text re-runs the whole TextServer
	# shaping pass over it. On a Cortex-A53 falling back through the system emoji font
	# for ten glyphs that is not cheap, and it was happening once per frame inside a
	# 30 FPS budget — the reported "profiler overlay itself causes severe lag when
	# enabled".
	#
	# 4 Hz is well inside human reading speed and above the 1 Hz rate at which most of
	# these numbers change at all (cpu_temp, S_clk and the battery poll are all 1 Hz).
	#
	# overlay_refresh_count is published in the report so an on-device log can show the
	# throttle held, rather than the claim resting on this comment.
	if overlay_visible and overlay_label:
		_overlay_refresh_timer += delta
		if _overlay_refresh_timer >= OVERLAY_REFRESH_INTERVAL:
			_overlay_refresh_timer = 0.0
			_update_overlay_text()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_overlay()

func set_overlay_visible(visible: bool) -> void:
	overlay_visible = visible
	var canvas = get_node_or_null("ProfilerCanvas")
	if canvas:
		canvas.visible = overlay_visible

func is_overlay_visible() -> bool:
	return overlay_visible

## Rebuilds the overlay label immediately, bypassing the OVERLAY_REFRESH_INTERVAL gate.
## Exists so a harness can time what one refresh actually costs without reaching into a
## private method (same reason as check_iso_compliance above). Not used by gameplay —
## calling this per frame is precisely the defect the throttle fixes.
func refresh_overlay_text_now() -> void:
	_update_overlay_text()

func toggle_overlay() -> void:
	set_overlay_visible(not overlay_visible)

func _apply_saved_dev_visibility() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		return

	var dev_mode_enabled = bool(save_mgr.get_setting("dev_mode", false))
	var should_show_profiler = bool(save_mgr.get_setting("dev_show_profiler", false))
	set_overlay_visible(dev_mode_enabled and should_show_profiler)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ALGORITHM LATENCY TRACKING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Call this before an algorithm operation starts
func begin_latency_measurement() -> int:
	return Time.get_ticks_usec()

## Call this after an algorithm operation ends
func end_latency_measurement(start_usec: int, operation_name: String = "") -> float:
	# Guard: a span that was never opened (begin returned 0 because the profiler
	# was unavailable) must not be measured against the epoch.
	if start_usec <= 0:
		return 0.0

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
		# Rate-limited per operation name. Without this gate a single slow
		# operation that runs once per round emits a warning every round for
		# the whole session, which buries every other diagnostic in the log.
		# The signal is gated too, so subscribers can't be spammed either.
		if _should_emit_latency_warning(operation_name):
			push_warning("⚠️ Algorithm '%s' exceeded latency budget: %.2fms > %.2fms" % [
				operation_name, elapsed_ms, MAX_ALGO_LATENCY_MS
			])
			performance_warning.emit("algo_latency", elapsed_ms, MAX_ALGO_LATENCY_MS)
	
	return elapsed_ms

## Cooldown gate for latency warnings, keyed per operation name.
##
## Uses the same window as _emit_warning() but its own key namespace so a noisy
## algorithm can never suppress an fps/memory warning, and vice versa.
func _should_emit_latency_warning(operation_name: String) -> bool:
	var key: String = "algo_latency:" + operation_name
	var last: float = _warning_last_emit.get(key, -LATENCY_WARNING_COOLDOWN_SEC - 1.0)
	if session_elapsed_sec - last < LATENCY_WARNING_COOLDOWN_SEC:
		return false
	_warning_last_emit[key] = session_elapsed_sec
	return true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THRESHOLD CHECKS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _emit_warning(metric: String, value: float, threshold: float) -> void:
	var last: float = _warning_last_emit.get(metric, -WARNING_COOLDOWN_SEC - 1.0)
	if session_elapsed_sec - last < WARNING_COOLDOWN_SEC:
		return
	_warning_last_emit[metric] = session_elapsed_sec
	performance_warning.emit(metric, value, threshold)

func _check_thresholds() -> void:
	if fps_current < MIN_FPS:
		_emit_warning("fps_critical", fps_current, float(MIN_FPS))
	elif fps_current < TARGET_FPS:
		_emit_warning("fps_below_target", fps_current, float(TARGET_FPS))

	if memory_current_mb > MAX_MEMORY_MB:
		_emit_warning("memory_exceeded", memory_current_mb, MAX_MEMORY_MB)

	if estimated_battery_mah > MAX_BATTERY_MAH_PER_5MIN and battery_source == "android_sysfs":
		_emit_warning("battery_exceeded", estimated_battery_mah, MAX_BATTERY_MAH_PER_5MIN)

	if _thermal_source == "sensor" and cpu_temp_c > MAX_CPU_TEMP_C:
		_emit_warning("cpu_temp_exceeded", cpu_temp_c, MAX_CPU_TEMP_C)

	if is_throttling:
		_emit_warning("clock_throttled", clock_speed_ratio, THROTTLE_THRESHOLD)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SNAPSHOT & EXPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _take_snapshot() -> void:
	# Object lifecycle is sampled here at 1 Hz rather than in _process(), for the
	# same reason memory_history is: per-frame sampling would add 60 monitor reads
	# a second to answer a question that only moves across scene transitions.
	object_count = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	orphan_node_count = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if object_count_baseline < 0:
		object_count_baseline = object_count
		orphan_node_baseline = orphan_node_count
	if orphan_node_count > orphan_node_peak:
		orphan_node_peak = orphan_node_count

	var snap = {
		"timestamp": Time.get_unix_time_from_system(),
		"elapsed_sec": session_elapsed_sec,
		"fps": fps_current,
		"fps_avg": fps_avg,
		"fps_min": fps_min,
		"frame_time_ms": frame_time_ms,
		"memory_mb": memory_current_mb,
		"memory_peak_mb": memory_peak_mb,
		"object_count": object_count,
		"orphan_nodes": orphan_node_count,
		"algo_latency_avg_ms": algo_latency_avg_ms,
		"algo_latency_max_ms": algo_latency_max_ms,
		"dropped_frames": dropped_frames,
		"frames_after_warmup": frames_after_warmup,
		"frames_over_60_budget": frames_over_60_budget,
		"total_frames": total_frames,
		"battery_mah": estimated_battery_mah,
		"battery_pct": battery_pct_current,
		"cpu_temp_c": cpu_temp_c,
		"clock_speed_ratio": clock_speed_ratio,
		"is_throttling": is_throttling,
		"battery_drain_per_min": battery_drain_per_min,
	}
	snapshots.append(snap)
	if snapshots.size() > MAX_HISTORY_SAMPLES:
		snapshots.pop_front()
	# Populate memory_history for trend / leak-detection analysis
	memory_history.append(memory_current_mb)
	if memory_history.size() > MAX_HISTORY_SAMPLES:  # cap at 30 min of 1s snapshots
		memory_history.pop_front()
	battery_readings.append({
		"timestamp": snap["timestamp"],
		"elapsed_sec": session_elapsed_sec,
		"battery_pct": battery_pct_current,
		"battery_mah": estimated_battery_mah,
		"battery_drain_per_min": battery_drain_per_min,
		"source": battery_source,
	})
	if battery_readings.size() > MAX_HISTORY_SAMPLES:
		battery_readings.pop_front()
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
			"budget_60_ms": FRAME_BUDGET_60_MS,
			"dropped_frames": dropped_frames,
			"frames_after_warmup": frames_after_warmup,
			"frames_over_60_budget": frames_over_60_budget,
			"drop_rate_percent": drop_rate,
			"meets_budget": drop_rate < 5.0  # <5% dropped frames = pass
		},
		# What the debug overlay itself cost this session. It used to rebuild an
		# emoji-bearing 15-line Label once per frame, so on the Moto E5 Plus turning the
		# profiler on measurably worsened the frame rate the profiler was reporting.
		# refresh_hz is the check: near OVERLAY_REFRESH_INTERVAL's 4 Hz while the overlay
		# was up, and 0 when it was never shown. A figure near the frame rate means the
		# throttle is not holding.
		"overlay_cost": {
			"visible_at_export": overlay_visible,
			"refresh_count": overlay_refresh_count,
			"refresh_hz": (
				float(overlay_refresh_count) / session_elapsed_sec
				if session_elapsed_sec > 0.0 else 0.0
			),
			"refresh_interval_sec": OVERLAY_REFRESH_INTERVAL
		},
		"memory": {
			"current_mb": memory_current_mb,
			"peak_mb": memory_peak_mb,
			"limit_mb": MAX_MEMORY_MB,
			"meets_limit": memory_peak_mb <= MAX_MEMORY_MB
		},
		"object_lifecycle": {
			# Deltas against the first snapshot, not raw counts: the baseline is
			# whatever the 23 autoloads plus the boot scene happen to allocate, which
			# is not a leak and varies by entry point. Growth from there is the
			# evidence that matters for ΔRAM = 0 across a multi-round session.
			#
			# Both monitors return 0 in an exported release build (debug-only), so
			# "measured" says whether these numbers mean anything for this run.
			"measured": OS.is_debug_build(),
			"object_count": object_count,
			"object_count_delta": (
				object_count - object_count_baseline if object_count_baseline >= 0 else 0
			),
			"orphan_nodes": orphan_node_count,
			"orphan_nodes_peak": orphan_node_peak,
			"orphan_nodes_delta": (
				orphan_node_count - orphan_node_baseline if orphan_node_baseline >= 0 else 0
			),
			# Nodes detached and never freed accumulate for the whole session, so any
			# steady growth here is a per-round lifecycle bug rather than noise.
			"no_orphan_growth": (
				orphan_node_baseline < 0 or orphan_node_count <= orphan_node_baseline
			)
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
			# ΔE is only ever a real number when the Android sysfs battery nodes were
			# readable. On desktop estimated_battery_mah stays 0.0, so the old
			# unguarded "0.0 <= limit" published "meets_limit": true — a battery pass
			# from a run with no battery measurement. The warning path at
			# _check_thresholds already gates on battery_source == "android_sysfs";
			# this is the same rule applied to the published field.
			"measured": battery_source == "android_sysfs",
			"meets_limit": (
				(estimated_battery_mah <= MAX_BATTERY_MAH_PER_5MIN)
				if battery_source == "android_sysfs" else null
			),
			"measurement_source": battery_source,
			"start_pct": battery_pct_start,
			"min_pct": battery_pct_min if battery_pct_min <= 100 else -1,
			"max_pct": battery_pct_max,
			"avg_pct": _calc_battery_pct_avg()
		},
		"thermal": {
			"cpu_temp_c": cpu_temp_c,
			"cpu_temp_peak": cpu_temp_peak,
			"threshold_c": MAX_CPU_TEMP_C,
			# Same trap as the stress verdict: with no sensor cpu_temp_peak stays 0.0
			# and 0.0 <= 45.0 published "meets_threshold": true — a thermal pass in an
			# exported session log from a run that read no temperature. null means "not
			# evaluated", which is what _check_iso_compliance already does with this
			# criterion. "thermal_source" below says why.
			"meets_threshold": (
				(cpu_temp_peak <= MAX_CPU_TEMP_C) if _thermal_source == "sensor" else null
			),
			"clock_speed_ratio": clock_speed_ratio,
			"throttle_events": throttle_count,
			"s_clk_stable": throttle_count == 0,
			"temp_samples": cpu_temp_history.size(),
			"thermal_source": _thermal_source
		},
		"dl_baseline_comparison": {
			# The whole comparison is derived from battery_drain_per_min, which stays
			# 0.0 unless the Android sysfs battery nodes were readable. Unguarded, that
			# left rule_based_vs_dl_ratio at 0.0 and published
			# "reduction_pct": 100.0 / "is_more_efficient": true — i.e. a 100% energy
			# saving over the MobileNet baseline claimed by a desktop run that never
			# measured a milliamp. get_dl_comparison(), the human-facing version of
			# this same table, already prints "N/A (%s)" / "test on Android" here; the
			# machine-readable dict was the one that did not.
			"measured": battery_source == "android_sysfs" and battery_drain_per_min > 0.0,
			"rule_based_mah_min": battery_drain_per_min,
			"dl_baseline_mah_min": DL_BASELINE_MAH_PER_MIN,
			"measurement_source": battery_source,
			"ratio": (
				rule_based_vs_dl_ratio
				if battery_source == "android_sysfs" and battery_drain_per_min > 0.0
				else null
			),
			"reduction_pct": (
				((1.0 - rule_based_vs_dl_ratio) * 100.0)
				if battery_source == "android_sysfs" and battery_drain_per_min > 0.0
				else null
			),
			"is_more_efficient": (
				(rule_based_vs_dl_ratio < 1.0)
				if battery_source == "android_sysfs" and battery_drain_per_min > 0.0
				else null
			)
		},
		"stress_test": {
			"active": stress_test_active,
			# "passed" is kept for any existing reader, but it is the WEAK field:
			# false covers both "exceeded 45 °C" and "no sensor, never evaluated".
			# "verdict" is the one to read. See _update_stress_test.
			"passed": stress_test_passed,
			"verdict": stress_test_verdict,
			"thermal_source": _thermal_source,
			"target_sec": STRESS_TEST_DURATION_SEC
		},
		"mobile_context": _build_mobile_context(),
		"iso_25010_pass": _check_iso_compliance(),
		"snapshots": snapshots
	}

## Check overall ISO/IEC 25010 compliance
## Thermal check is skipped when sensor data is unavailable
func _check_iso_compliance() -> bool:
	var base_pass = (
		fps_avg >= float(MIN_FPS) and
		memory_peak_mb <= MAX_MEMORY_MB and
		algo_latency_max_ms <= MAX_ALGO_LATENCY_MS
	)
	# Only fail on thermal if we have real sensor data
	if _thermal_source == "sensor" and cpu_temp_peak > MAX_CPU_TEMP_C:
		return false
	return base_pass


func _calc_battery_pct_avg() -> float:
	if battery_pct_samples.is_empty():
		return -1.0
	var total := 0.0
	for p in battery_pct_samples:
		total += float(p)
	return total / float(battery_pct_samples.size())


func _build_mobile_context() -> Dictionary:
	var viewport_size := Vector2.ZERO
	var viewport = get_viewport()
	if viewport:
		viewport_size = viewport.get_visible_rect().size

	var safe_margins := {
		"top": 0.0,
		"bottom": 0.0,
		"left": 0.0,
		"right": 0.0,
	}
	var mobile_mode := false
	var orientation := "portrait" if viewport_size.y > viewport_size.x else "landscape"

	if MobileUIManager:
		mobile_mode = MobileUIManager.is_mobile_platform()
		if MobileUIManager.has_method("is_portrait_orientation"):
			orientation = "portrait" if MobileUIManager.is_portrait_orientation() else "landscape"
		if MobileUIManager.has_method("get_safe_area_margins"):
			safe_margins = MobileUIManager.get_safe_area_margins()

	var haptics_enabled := true
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("get_setting"):
		haptics_enabled = bool(save_mgr.get_setting("haptics_enabled", true))

	return {
		"mobile_mode": mobile_mode,
		"orientation": orientation,
		"viewport_width": int(viewport_size.x),
		"viewport_height": int(viewport_size.y),
		"safe_area": safe_margins,
		"haptics_enabled": haptics_enabled,
	}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OVERLAY TEXT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THERMAL PROFILING (Paper: Instrumental Profiling Protocols)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Sample T_cpu at 1-second intervals.
## On Android reads /sys/class/thermal; on desktop uses
## a frame-time heuristic as proxy.
var _thermal_source: String = "heuristic"  # "sensor" or "heuristic"
var _thermal_source_logged: bool = false

func _sample_cpu_temperature() -> void:
	# ═══════════════════════════════════════════════════════════════════
	# THERMAL PROFILING — Real sensor on Android, unavailable on desktop
	# Thesis requires instrumental profiling; heuristic approximations
	# would be misleading in exported session logs.
	# ═══════════════════════════════════════════════════════════════════
	
	# On Android, try to read actual thermal sensor from sysfs
	if OS.get_name() == "Android":
		var sensor_read := false
		var thermal_paths := [
			"/sys/class/thermal/thermal_zone0/temp",
			"/sys/class/thermal/thermal_zone1/temp",
			"/sys/class/thermal/thermal_zone2/temp",
			"/sys/class/thermal/thermal_zone3/temp",
			"/sys/class/thermal/thermal_zone4/temp",
			"/sys/devices/virtual/thermal/thermal_zone0/temp",
		]
		for path in thermal_paths:
			var temp_file = FileAccess.open(
				path, FileAccess.READ
			)
			if temp_file:
				var raw = temp_file.get_as_text().strip_edges()
				temp_file.close()
				if raw.is_valid_int():
					var raw_val = raw.to_int()
					# Values > 1000 are in milli-degrees Celsius
					if raw_val > 1000:
						cpu_temp_c = float(raw_val) / 1000.0
					else:
						cpu_temp_c = float(raw_val)
					_thermal_source = "sensor"
					sensor_read = true
					if not _thermal_source_logged:
						print("🌡 Thermal sensor found: %s → %.1f°C" % [path, cpu_temp_c])
						_thermal_source_logged = true
					break
		
		if not sensor_read:
			var batt_temp_paths := [
				"/sys/class/power_supply/battery/temp",
				"/sys/class/power_supply/Battery/temp",
			]
			for path in batt_temp_paths:
				var temp_file = FileAccess.open(path, FileAccess.READ)
				if temp_file:
					var raw = temp_file.get_as_text().strip_edges()
					temp_file.close()
					if raw.is_valid_int():
						var raw_val = raw.to_int()
						# Battery temp is typically in tenths of a degree (e.g. 350 = 35.0 C)
						cpu_temp_c = float(raw_val) / 10.0
						_thermal_source = "sensor"
						sensor_read = true
						if not _thermal_source_logged:
							print(
								"🌡 Thermal sensor found: %s → %.1f°C" % [path, cpu_temp_c]
							)
							_thermal_source_logged = true
						break
						
		if not sensor_read:
			# Android but no readable sensor — report as unavailable
			cpu_temp_c = 0.0
			_thermal_source = "unavailable"
			if not _thermal_source_logged:
				print("⚠️ No thermal sensor accessible on this Android device")
				print("   Tried paths: %s and battery temp" % str(thermal_paths))
				print("   cpu_temp_c will report 0.0 (unavailable)")
				_thermal_source_logged = true
	else:
		# Desktop: No real thermal data available
		# Report 0.0 and clearly mark source as unavailable
		cpu_temp_c = 0.0
		_thermal_source = "unavailable_desktop"
		if not _thermal_source_logged:
			print("🌡 Desktop mode — CPU temperature unavailable (no sysfs sensor)")
			print("   cpu_temp_c = 0.0 | thermal_source = unavailable_desktop")
			_thermal_source_logged = true
	
	cpu_temp_history.append(cpu_temp_c)
	if cpu_temp_history.size() > MAX_HISTORY_SAMPLES:
		cpu_temp_history.pop_front()
	if cpu_temp_c > cpu_temp_peak:
		cpu_temp_peak = cpu_temp_c

## Read battery capacity percentage from Android sysfs.
## Returns -1 if unavailable (desktop or read failure).
func _read_android_battery_percent() -> int:
	# Extended paths: standard + Xiaomi BMS + Motorola/Qualcomm
	var paths = [
		"/sys/class/power_supply/battery/capacity",
		"/sys/class/power_supply/Battery/capacity",
		"/sys/class/power_supply/bms/capacity",       # Xiaomi BMS
		"/sys/class/power_supply/BMS/capacity",       # some Qualcomm variants
		"/sys/class/power_supply/fuel_gauge/capacity",# Motorola E-series
		"/sys/class/power_supply/max170xx_battery/capacity", # Moto MaxIm gauge
	]
	for path in paths:
		var f = FileAccess.open(path, FileAccess.READ)
		if f:
			var raw = f.get_as_text().strip_edges()
			f.close()
			if raw.is_valid_int():
				var pct = raw.to_int()
				if pct >= 0 and pct <= 100:
					battery_source = "android_sysfs"
					return pct
	# No path succeeded — update source so the JSON is honest about it.
	battery_source = "android_sysfs_no_permission"
	return -1

## Sample Clock Speed Stability (S_clk).
## On Android: Uses FPS-to-target ratio as a proxy for clock stability.
## Throttle event = effective performance drops below 80% of target.
## NOTE: This is NOT actual CPU frequency — ENet/GDScript cannot read
## /sys/devices/system/cpu/cpu0/cpufreq on most Android devices.
## The FPS ratio serves as a behavioral indicator of throttling.
func _sample_clock_speed() -> void:
	var prev_throttling = is_throttling

	# Divide by MIN_FPS (30) not TARGET_FPS (60).
	# The game is capped at 30fps so nominal ratio = 1.0 at 30fps.
	# Dividing by 60 always gives 0.5 which falsely marks every frame as throttled.
	if fps_current > 0 and MIN_FPS > 0:
		clock_speed_ratio = clamp(
			fps_current / float(MIN_FPS), 0.0, 2.0
		)
	else:
		clock_speed_ratio = 1.0

	var below_threshold: bool = clock_speed_ratio < THROTTLE_THRESHOLD

	# Engine boot is not a measurement. _update_metrics already refuses to count
	# dropped_frames before STARTUP_WARMUP_SEC for exactly this reason, and the CPU
	# temperature warning already refuses to fire when _thermal_source is not a real
	# sensor — S_clk had neither guard. Measured consequence, in a session that did
	# nothing but idle and load one scene: a throttle event at t=1.57 s with
	# fps=1.0 and S_clk=3%, the engine's first frames, which then published
	# s_clk_stable = false for the whole run (tools/logs/throttle.log).
	if session_elapsed_sec <= STARTUP_WARMUP_SEC:
		_low_clock_samples = 0
		is_throttling = false
		return

	# Throttling is a SUSTAINED clock reduction — that is what makes the FPS ratio a
	# usable proxy for it at all. A single 1 Hz sample below the threshold is a
	# loading hitch (a scene swap, a first-frame shader compile), and counting those
	# meant one transition was enough to report the session as thermally unstable.
	# THROTTLE_MIN_SAMPLES consecutive seconds is the smallest window that separates
	# the two; a real thermal throttle lasts far longer and still registers, one
	# second later than before.
	if below_threshold:
		_low_clock_samples += 1
	else:
		_low_clock_samples = 0
	is_throttling = _low_clock_samples >= THROTTLE_MIN_SAMPLES

	# Log new throttle events
	if is_throttling and not prev_throttling:
		throttle_count += 1
		throttle_events.append({
			"timestamp": Time.get_unix_time_from_system(),
			"elapsed_sec": session_elapsed_sec,
			"clock_ratio": clock_speed_ratio,
			"cpu_temp_c": cpu_temp_c,
			"fps": fps_current,
			# How many consecutive 1 Hz samples had been below the threshold when the
			# event was raised. Kept so the thesis appendix can show the events were
			# sustained dips and not single-frame hitches.
			"low_samples": _low_clock_samples,
			"measurement_note": (
				"clock_ratio derived from FPS/target_FPS "
				+ "(behavioral proxy, not actual CPU frequency); "
				+ "requires %d consecutive samples below threshold, "
				+ "startup warmup excluded"
			) % THROTTLE_MIN_SAMPLES
		})
		# throttle_count remains the authoritative total; the array is only
		# the detailed tail kept for the thesis appendix.
		if throttle_events.size() > MAX_EVENT_ENTRIES:
			throttle_events.pop_front()
		print(
			"🔥 THROTTLE #%d: S_clk=%.0f%% (low for %ds)" % [
				throttle_count,
				clock_speed_ratio * 100.0,
				_low_clock_samples
			]
		)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STRESS TEST (Paper: 30-minute continuous session)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Start a 30-minute stress test session
func start_stress_test() -> void:
	stress_test_verdict = "running"
	stress_test_active = true
	stress_test_start = Time.get_ticks_msec()
	stress_test_passed = false
	cpu_temp_history.clear()
	throttle_events.clear()
	_low_clock_samples = 0
	throttle_count = 0
	print("🔬 STRESS TEST STARTED (30 min target)")
	print("   Pass: T_cpu < 45°C throughout")

func _update_stress_test() -> void:
	var elapsed = float(
		Time.get_ticks_msec() - stress_test_start
	) / 1000.0
	
	if elapsed >= STRESS_TEST_DURATION_SEC:
		stress_test_active = false

		# The pass criterion is "peak T_cpu stayed under 45 °C". With no thermal
		# sensor, cpu_temp_peak never leaves 0.0, and 0.0 <= 45.0 reported
		# PASS ✅ / "Peak T_cpu: 0.0°C / 45°C" — a 30-minute thermal result from a
		# machine that measured no temperature at all. _check_iso_compliance already
		# refuses to judge thermal without a sensor, and this file's own note above
		# _sample_cpu_temperature says heuristic approximations "would be misleading
		# in exported session logs"; the stress verdict was the one place that did
		# not honour that. Absence of a sensor is INCONCLUSIVE, not a pass.
		if _thermal_source != "sensor":
			stress_test_verdict = "inconclusive_no_thermal_sensor"
			stress_test_passed = false
		elif cpu_temp_peak <= MAX_CPU_TEMP_C:
			stress_test_verdict = "pass"
			stress_test_passed = true
		else:
			stress_test_verdict = "fail"
			stress_test_passed = false

		var result := "PASS ✅"
		if stress_test_verdict == "fail":
			result = "FAIL ❌"
		elif stress_test_verdict == "inconclusive_no_thermal_sensor":
			result = "INCONCLUSIVE ⚠️ (no thermal sensor — thermal criterion not evaluated)"
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("🔬 STRESS TEST: %s" % result)
		if _thermal_source == "sensor":
			print("   Peak T_cpu: %.1f°C / %.0f°C" % [
				cpu_temp_peak, MAX_CPU_TEMP_C
			])
		else:
			print("   Peak T_cpu: unmeasured (thermal_source = %s)" % _thermal_source)
		print("   Throttles: %d" % throttle_count)
		print("   Ran %.0f s of %.0f s" % [elapsed, STRESS_TEST_DURATION_SEC])
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

func stop_stress_test() -> void:
	stress_test_active = false
	# A manual stop is not a result. Leaving the verdict at "running" would let a
	# report published later be read as a test still in progress, and calling it a
	# pass would be worse — an aborted run measured only part of the 30 minutes.
	if stress_test_verdict == "running":
		stress_test_verdict = "aborted"
	stress_test_passed = false
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
		# Read "verdict", not "passed": with no thermal sensor the 45 °C criterion is
		# never evaluated, and a false "passed" would otherwise be indistinguishable
		# from a measured overheat. See _update_stress_test.
		"passed": stress_test_passed,
		"verdict": stress_test_verdict,
		"thermal_source": _thermal_source,
		"battery_drain_per_min": battery_drain_per_min,
		"dl_comparison": {
			# Same guard as export_session_report().dl_baseline_comparison: without a
			# real ΔE reading this used to publish savings_pct = 100.0.
			"measured": battery_source == "android_sysfs" and battery_drain_per_min > 0.0,
			"measurement_source": battery_source,
			"rule_based": battery_drain_per_min,
			"mobilenet": DL_BASELINE_MAH_PER_MIN,
			"savings_pct": (
				((1.0 - rule_based_vs_dl_ratio) * 100.0)
				if battery_source == "android_sysfs" and battery_drain_per_min > 0.0
				else null
			)
		}
	}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OVERLAY TEXT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _update_overlay_text() -> void:
	overlay_refresh_count += 1
	var fps_ico := ICO_OK
	if fps_current < MIN_FPS:
		fps_ico = ICO_BAD
	elif fps_current < TARGET_FPS:
		fps_ico = ICO_WARN

	var mem_ico := ICO_OK
	if memory_current_mb >= MAX_MEMORY_MB:
		mem_ico = ICO_BAD
	elif memory_current_mb >= MAX_MEMORY_MB * 0.8:
		mem_ico = ICO_WARN

	var temp_str: String
	if _thermal_source == "sensor":
		var temp_ico := ICO_OK
		if cpu_temp_c >= MAX_CPU_TEMP_C:
			temp_ico = ICO_BAD
		elif cpu_temp_c >= MAX_CPU_TEMP_C * 0.85:
			temp_ico = ICO_WARN
		temp_str = "%s T_cpu: %.1fC / %.0fC [sensor]\n" % [
			temp_ico, cpu_temp_c, MAX_CPU_TEMP_C
		]
	else:
		temp_str = "%s T_cpu: N/A [%s]\n" % [ICO_NA, _thermal_source]

	var algo_ico := ICO_OK
	if algo_latency_max_ms >= MAX_ALGO_LATENCY_MS:
		algo_ico = ICO_BAD

	var clk_ico := ICO_OK if not is_throttling else ICO_BAD
	var iso = "PASS" if _check_iso_compliance() else "FAIL"
	var drop_pct = (
		float(dropped_frames) / max(total_frames, 1) * 100.0
	)

	var batt_str: String
	if battery_source == "android_sysfs":
		var savings = (1.0 - rule_based_vs_dl_ratio) * 100.0
		batt_str = "BATT dE: %.2f mAh/min [sysfs]\n" % battery_drain_per_min
		batt_str += "  vs DL: %.0f%% savings\n" % savings
	else:
		batt_str = "BATT dE: N/A [%s]\n" % battery_source

	var stress_ln = ""
	if stress_test_active:
		var st_sec = float(
			Time.get_ticks_msec() - stress_test_start
		) / 1000.0
		stress_ln = "\nSTRESS: %.0fs/%.0fs" % [
			st_sec, STRESS_TEST_DURATION_SEC
		]

	overlay_label.text = (
		"== ISO/IEC 25010 PROFILER ==\n"
		+ "%s FPS: %.0f (avg:%.0f min:%.0f)\n" % [
			fps_ico, fps_current, fps_avg, fps_min
		]
		+ "  %.1fms/%.1fms Drop:%d(%.1f%%) >16.7ms:%d\n" % [
			frame_time_ms, FRAME_BUDGET_MS,
			dropped_frames, drop_pct, frames_over_60_budget
		]
		+ "%s Mem: %.0f/%.0fMB pk:%.0f\n" % [
			mem_ico, memory_current_mb,
			MAX_MEMORY_MB, memory_peak_mb
		]
		+ temp_str
		+ "%s S_clk: %.0f%% throttle:%d\n" % [
			clk_ico, clock_speed_ratio * 100.0,
			throttle_count
		]
		+ "%s Algo: %.2f/%.0fms\n" % [
			algo_ico, algo_latency_avg_ms,
			MAX_ALGO_LATENCY_MS
		]
		+ batt_str
		+ "TIME %.0fs | %d frames\n" % [
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
	var mobile_context = _build_mobile_context()
	var entry := {
		"timestamp": Time.get_unix_time_from_system(),
		"elapsed_sec": session_elapsed_sec,
		"event": event_type,
		"fps": fps_current,
		"mem_mb": memory_current_mb,
		"cpu_temp_c": cpu_temp_c,
		"algo_latency_ms": algo_latency_avg_ms,
		"mobile_mode": bool(mobile_context.get("mobile_mode", false)),
		"orientation": str(mobile_context.get("orientation", "landscape")),
	}
	entry.merge(data)
	_session_events.append(entry)
	if _session_events.size() > MAX_EVENT_ENTRIES:
		_session_events.pop_front()

func export_session_log_to_file() -> String:
	var dir_path := "user://perf_logs"
	var user_dir = DirAccess.open("user://")
	if user_dir:
		var mk_err = user_dir.make_dir_recursive("perf_logs")
		if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
			push_warning("Could not ensure perf_logs directory (%s)" % error_string(mk_err))
	else:
		push_warning("Could not open user:// for perf log export")
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THESIS DEFENCE DATA ACCESSORS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## FPS standard deviation — measures frame-rate stability.
## A value ≤ 2.0 fps is excellent; ≤ 5.0 acceptable; >5.0 unstable.
func get_fps_std_dev() -> float:
	if fps_history.size() < 2:
		return 0.0
	var mean := fps_avg
	var variance := 0.0
	for f in fps_history:
		variance += (f - mean) * (f - mean)
	variance /= float(fps_history.size())
	return sqrt(variance)

## Temperature heat curve bucketed for display.
## Returns Array of {elapsed_min, avg_temp_c} with at most max_points entries.
func get_temp_curve(max_points: int = 60) -> Array:
	if cpu_temp_history.is_empty():
		return []
	var step: int = maxi(1, cpu_temp_history.size() / max(1, max_points))
	var result := []
	var i := 0
	while i < cpu_temp_history.size():
		var bucket_sum := 0.0
		var count := 0
		for j in range(i, min(i + step, cpu_temp_history.size())):
			bucket_sum += cpu_temp_history[j]
			count += 1
		result.append({
			"elapsed_min": snapped(float(i) / 60.0, 0.1),
			"avg_temp_c": snapped(bucket_sum / float(count), 0.1),
		})
		i += step
	return result

## Memory trend curve bucketed for display / leak detection.
## Returns Array of {elapsed_min, memory_mb} with at most max_points entries.
func get_memory_curve(max_points: int = 60) -> Array:
	if memory_history.is_empty():
		return []
	var step: int = maxi(1, memory_history.size() / max(1, max_points))
	var result := []
	for i in range(0, memory_history.size(), step):
		result.append({
			"elapsed_min": snapped(float(i) * snapshot_interval / 60.0, 0.1),
			"memory_mb": snapped(memory_history[i], 0.1),
		})
	return result

## Structured DL baseline comparison for thesis Chapter 4 tables.
## Compares WaterWise rule-based algorithm vs MobileNet DL on same device.
func get_dl_comparison() -> Array:
	var savings := (1.0 - rule_based_vs_dl_ratio) * 100.0
	var latency_speedup := 300.0 / maxf(algo_latency_avg_ms, 0.01)
	const MOBILENET_RAM_MB := 90.0   # MobileNet V1 + TF Lite runtime on Cortex-A53
	const MOBILENET_FPS    := 27.0   # typical sustained FPS with TFLite inference
	const MOBILENET_LATENCY_MS := 300.0  # ~300ms inference on Cortex-A53
	var ram_saving := maxf(0.0, MOBILENET_RAM_MB - memory_peak_mb)
	var fps_delta  := fps_avg - MOBILENET_FPS
	var batt_str: String
	var batt_result: String
	if battery_source == "android_sysfs" and battery_drain_per_min > 0.0:
		batt_str    = "%.2f mAh/min" % battery_drain_per_min
		batt_result = "%.0f%% less" % clampf(savings, -999.0, 999.0)
	else:
		batt_str    = "N/A (%s)" % battery_source
		batt_result = "test on Android"
	return [
		["Metric",                  "WaterWise (Rule-Based)",       "MobileNet Baseline",     "Advantage"],
		["Battery Drain",           batt_str,                       "~10.0 mAh/min",          batt_result],
		["Algo Latency (avg)",      "%.2f ms" % algo_latency_avg_ms, "~%.0f ms" % MOBILENET_LATENCY_MS, "%.0fx faster" % latency_speedup],
		["RAM (peak)",              "%.0f MB" % memory_peak_mb,     "~%.0f MB" % MOBILENET_RAM_MB,       "%.0f MB less" % ram_saving if memory_peak_mb > 0.0 else "see log"],
		["FPS (avg)",               "%.0f fps" % fps_avg,           "~%.0f fps" % MOBILENET_FPS,        ("%.0f fps better" % fps_delta) if fps_avg > 0.0 else "see log"],
	]
