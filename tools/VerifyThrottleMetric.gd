extends Node

## ── WATERWISE S_clk THROTTLE-METRIC PROBE ──────────────────────────────────
##
## PerformanceProfiler reports S_clk (clock-speed stability) and publishes
## "s_clk_stable": throttle_count == 0 into the thesis performance JSON. A throttle
## event is counted whenever fps_current / MIN_FPS drops below 0.80 in a 1 Hz sample.
##
## Two things make that count something other than throttling, and this probe
## measures both rather than asserting them from reading:
##
##   1. No warmup guard. The same file already refuses to count dropped_frames
##      before STARTUP_WARMUP_SEC (3 s) because startup frames are not a
##      measurement — _sample_clock_speed has no such guard, so engine boot and the
##      first scene load are eligible to be logged as thermal throttling.
##   2. No persistence requirement. Thermal throttling is a SUSTAINED clock
##      reduction; a single one-second dip is a loading hitch. One transition
##      hitch is enough to publish s_clk_stable = false for the whole session.
##
## The probe deliberately does nothing but idle and load one scene, so any event it
## records cannot be thermal — there is no sustained load to heat anything.
##
## Run:  godot --headless --path . res://tools/VerifyThrottleMetric.tscn

func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  S_clk THROTTLE-METRIC PROBE")
	print("═══════════════════════════════════════════════════════════")
	print("  MIN_FPS=%d  THROTTLE_THRESHOLD=%.2f  STARTUP_WARMUP_SEC=%.1f" % [
		PerformanceProfiler.MIN_FPS,
		PerformanceProfiler.THROTTLE_THRESHOLD,
		PerformanceProfiler.STARTUP_WARMUP_SEC,
	])

	# Idle through the warmup window, then load one minigame — the two cheapest
	# things a session can do. Neither is a thermal load.
	await get_tree().create_timer(4.0).timeout
	var early: int = PerformanceProfiler.throttle_count
	print("  after 4 s of idling: throttle_count = %d" % early)

	var scene := load("res://scenes/minigames/CatchTheRain.tscn") as PackedScene
	var game: Node = scene.instantiate()
	add_child(game)
	await get_tree().create_timer(3.0).timeout
	game.queue_free()
	await get_tree().create_timer(3.0).timeout
	print("  after one scene load:  throttle_count = %d" % PerformanceProfiler.throttle_count)
	print("")
	print("  recorded events:")
	var bad_warmup: int = 0
	var bad_transient: int = 0
	for e in PerformanceProfiler.throttle_events:
		var t: float = float(e["elapsed_sec"])
		var runlen: int = int(e.get("low_samples", 0))
		var in_warmup: bool = t <= PerformanceProfiler.STARTUP_WARMUP_SEC
		if in_warmup:
			bad_warmup += 1
		if runlen < PerformanceProfiler.THROTTLE_MIN_SAMPLES:
			bad_transient += 1
		print("    t=%6.2fs  fps=%5.1f  S_clk=%.0f%%  cpu_temp=%.1f  low_for=%ds  (%s)" % [
			t, float(e["fps"]), float(e["clock_ratio"]) * 100.0,
			float(e["cpu_temp_c"]), runlen,
			"INSIDE the warmup window" if in_warmup else "after warmup",
		])
	if PerformanceProfiler.throttle_events.is_empty():
		print("    (none)")

	var failed: int = 0
	print("")
	# An idle session that loads one scene generates no heat, so any event at all is
	# a measurement artifact. Both assertions are about provenance, not about the
	# count being zero for its own sake.
	if bad_warmup > 0:
		print("  ✗ %d event(s) logged inside the %.1fs startup warmup window"
			% [bad_warmup, PerformanceProfiler.STARTUP_WARMUP_SEC])
		failed += 1
	else:
		print("  ✓ no throttle event logged inside the startup warmup window")
	if bad_transient > 0:
		print("  ✗ %d event(s) raised from fewer than %d consecutive low samples"
			% [bad_transient, PerformanceProfiler.THROTTLE_MIN_SAMPLES])
		failed += 1
	else:
		print("  ✓ every recorded event was a sustained dip, not a single-sample hitch")


	# ── positive control: a real sustained collapse MUST still be caught ──
	print("")
	print("  ── positive control: sustained sub-threshold load ──")
	var before: int = PerformanceProfiler.throttle_count
	_burn = true
	await get_tree().create_timer(5.0).timeout
	_burn = false
	var raised: int = PerformanceProfiler.throttle_count - before
	if raised > 0:
		print("  ✓ a sustained frame-rate collapse is still detected (%d event(s), S_clk=%.0f%%)"
			% [raised, PerformanceProfiler.clock_speed_ratio * 100.0])
	else:
		print("  ✗ a sustained frame-rate collapse was NOT detected — the metric is now inert")
		failed += 1
	for e in PerformanceProfiler.throttle_events:
		print("    t=%6.2fs  fps=%5.1f  S_clk=%.0f%%  low_for=%ds" % [
			float(e["elapsed_sec"]), float(e["fps"]),
			float(e["clock_ratio"]) * 100.0, int(e.get("low_samples", 0)),
		])

	print("")
	print("  s_clk_stable now reads %s — expected, the control deliberately collapsed it"
		% str(PerformanceProfiler.throttle_count == 0))
	print("═══════════════════════════════════════════════════════════")
	get_tree().quit(1 if failed > 0 else 0)

## Set while the positive control is running. Without this control the two checks
## above would also pass on a metric that had simply been switched off — "no events"
## and "cannot raise events" are the same reading. This makes the difference visible.
var _burn: bool = false


func _process(_delta: float) -> void:
	if not _burn:
		return
	# Busy-wait ~60 ms, holding the frame rate near 16 FPS — under the 24 FPS the
	# 0.80 threshold works out to, and held long enough to clear
	# THROTTLE_MIN_SAMPLES. This is a real sustained frame-rate collapse, which is
	# the only thing the S_clk proxy claims to detect.
	var until := Time.get_ticks_msec() + 60
	while Time.get_ticks_msec() < until:
		pass
