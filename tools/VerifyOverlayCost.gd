extends Node

## Does the ISO profiler overlay still change the frame budget it is measuring?
##
## THE DEFECT
##   Reported as "the ISO profiler overlay itself causes severe lag when enabled". Two
##   things were true at once. PerformanceProfiler._process() called
##   _update_overlay_text() unconditionally, once per frame; and that function assembled
##   its ~15 lines using 🟢 🟡 🔴 ⚪ ✅ ❌ 🔋 ⏱ 🔬 ━ Δ °, none of which the bundled font
##   carries. Assigning a Label's text re-runs the TextServer shaping pass, and any glyph
##   the font is missing triggers a system-font-fallback lookup that is cached per
##   requested string - so a string containing a live frame_time_ms could never hit that
##   cache. A debug readout was spending a fallback search per frame, on a Cortex-A53, on
##   markers Android 8 then drew as tofu boxes, inside the exact 33ms budget it existed to
##   report. The fix throttles the rate AND removes the fallback trigger.
##
## WHAT IS MEASURED HERE
##   1. the refresh RATE with the overlay up - must sit near OVERLAY_REFRESH_INTERVAL's
##      4 Hz, not near the frame rate. This is device-independent.
##   2. zero refreshes while the overlay is hidden, so the cost is not merely throttled
##      but absent when the overlay is off.
##   3. that the readout is pure ASCII. This is the root cause rather than the rate: a
##      glyph the bundled font lacks sends TextServer to the system font fallback, that
##      lookup is cached per requested string, and this string changes every refresh - so
##      the old overlay paid a fallback search per refresh for markers Android 8 could not
##      draw anyway. Also device-independent.
##   4. the per-refresh CPU cost in µs, and from it the cost per second before and after
##      the throttle. This number is from THIS machine's TextServer, so it is a lower
##      bound for the Moto E5 Plus, not a prediction for it - a desktop x86 build with a
##      warm font cache is the friendliest case. It is printed, not asserted.
##   5. emoji markers vs ASCII markers, same layout, same changing number, to show which
##      way the swap in 3 actually moves the cost.
##   6. that the overlay still shows current numbers - a throttle that froze the readout
##      would pass everything above and be useless.
##
## Usage:
##   godot --headless --path . res://tools/VerifyOverlayCost.tscn

const SAMPLE_SEC: float = 3.0
const REFRESH_SAMPLES: int = 200

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
		if get_tree().paused:
			get_tree().paused = false
		await get_tree().process_frame


func _pp() -> Node:
	return get_node_or_null("/root/PerformanceProfiler")


## The integer the overlay prints in its "Drop:<n>(" field, or -1 if that field is not
## on screen at all - which is itself a failure worth telling apart from a frozen one.
func _drop_shown(text: String) -> int:
	var at: int = text.find("Drop:")
	if at < 0:
		return -1
	var open: int = text.find("(", at)
	if open < 0:
		return -1
	return int(text.substr(at + 5, open - at - 5))


## The first character the bundled font is not guaranteed to carry, or "" if the string is
## pure ASCII. A missing glyph is what sends TextServer out to the system font fallback.
func _first_non_ascii(text: String) -> String:
	for i in range(text.length()):
		var cp: int = text.unicode_at(i)
		if cp > 127:
			return "U+%04X '%s'" % [cp, text[i]]
	return ""


## Cost of one Label text assignment plus its shaping pass, averaged. The interpolated
## value changes every iteration on purpose: that is what defeats both set_text's
## unchanged-string early-out and TextServer's per-string shaping cache, and it is exactly
## what the real overlay does (frame_time_ms alone differs every refresh). get_minimum_size()
## forces the shape now instead of leaving it for the next draw, so the number is real.
func _shape_cost_us(sample: Label, template: String) -> float:
	var t0: int = Time.get_ticks_usec()
	for i in range(REFRESH_SAMPLES):
		sample.text = template % (float(i) * 0.017)
		sample.get_minimum_size()
	return float(Time.get_ticks_usec() - t0) / float(REFRESH_SAMPLES)


## Same loop, same emoji, but the string never changes. Separates "this label contains an
## emoji" from "this label re-shapes an emoji", which is the difference between a one-time
## cost and a per-frame one.
func _restate_cost_us(sample: Label, fixed: String) -> float:
	sample.text = fixed
	sample.get_minimum_size()
	var t0: int = Time.get_ticks_usec()
	for _i in range(REFRESH_SAMPLES):
		sample.text = fixed
		sample.get_minimum_size()
	return float(Time.get_ticks_usec() - t0) / float(REFRESH_SAMPLES)


## Wall-clock seconds and refresh count over the same window, so the rate is measured
## rather than inferred from a frame count.
func _sample_rate(seconds: float) -> Dictionary:
	var pp := _pp()
	var c0: int = pp.overlay_refresh_count
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await _frames(1)
	var elapsed: float = float(Time.get_ticks_msec() - t0) / 1000.0
	return {
		"refreshes": pp.overlay_refresh_count - c0,
		"seconds": elapsed,
		"hz": float(pp.overlay_refresh_count - c0) / maxf(elapsed, 0.001),
		"frames": Engine.get_frames_drawn(),
	}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== ISO overlay: cost of the instrument ===")

	var pp := _pp()
	if pp == null:
		print("  FAIL  PerformanceProfiler autoload missing")
		get_tree().quit(1)
		return

	# --- 1. hidden overlay must cost nothing at all -------------------------------
	pp.set_overlay_visible(false)
	await _frames(10)
	var hidden := await _sample_rate(1.0)
	_check(
		"a hidden overlay refreshes zero times",
		int(hidden["refreshes"]) == 0,
		"%d refreshes in %.2fs" % [int(hidden["refreshes"]), float(hidden["seconds"])]
	)

	# --- 2. visible overlay is throttled, not per-frame ---------------------------
	pp.set_overlay_visible(true)
	# The overlay Label only exists once the canvas has been built; without it the
	# throttle block is skipped entirely and this harness would measure nothing and
	# call it a pass.
	await _frames(10)
	if pp.overlay_label == null:
		_check(
			"the overlay label exists so there is something to measure",
			false,
			"overlay_label is null — headless build never created the ProfilerCanvas"
		)
	else:
		_check("the overlay label exists so there is something to measure", true)

	var shown := await _sample_rate(SAMPLE_SEC)
	var hz: float = float(shown["hz"])
	var expected_hz: float = 1.0 / float(pp.OVERLAY_REFRESH_INTERVAL)
	_check(
		"the visible overlay refreshes at the throttled rate, not per frame",
		hz > 0.0 and hz <= expected_hz * 1.5,
		"%.2f Hz measured over %.2fs (%d refreshes); interval %.2fs => %.1f Hz expected"
			% [hz, float(shown["seconds"]), int(shown["refreshes"]),
				float(pp.OVERLAY_REFRESH_INTERVAL), expected_hz]
	)
	# The rate has to be low AND non-zero: a broken throttle that never fires would
	# leave a frozen readout, which is worse than the cost it saves.
	_check(
		"the throttle still lets the readout update",
		int(shown["refreshes"]) >= 2,
		"%d refreshes in %.2fs" % [int(shown["refreshes"]), float(shown["seconds"])]
	)
	_check(
		"the refresh rate is far below the frame rate",
		hz < Engine.get_frames_per_second() * 0.5 or Engine.get_frames_per_second() <= 8.0,
		"overlay %.2f Hz vs engine %.0f FPS" % [hz, Engine.get_frames_per_second()]
	)

	# --- 3. the readout carries no glyph the bundled font lacks -------------------
	# Device-independent, and the actual root cause: a missing glyph sends TextServer to
	# the system font fallback, that lookup is cached per requested string, and this string
	# changes every refresh — so the pre-fix overlay paid a fallback search per refresh for
	# markers Android 8 then drew as tofu boxes anyway.
	if pp.overlay_label != null:
		var offender: String = _first_non_ascii(String(pp.overlay_label.text))
		_check(
			"the overlay emits no glyph outside ASCII",
			offender == "",
			"first offender: %s" % offender if offender != "" else "all codepoints < 128"
		)
		# A 4-character marker is wider than the 1-glyph emoji it replaced, and the panel
		# is placed 320px in from the right edge and sizes itself to its content — so a
		# marker that made the widest line grow would push a dev overlay off the screen it
		# is meant to be read on. Cheap to check, expensive to discover on a phone.
		var panel := pp.overlay_label.get_parent() as Control
		var reserved := 320.0
		if panel != null:
			await _frames(2)
			_check(
				"the ASCII markers did not widen the panel past its reserved %dpx"
					% int(reserved),
				panel.size.x <= reserved,
				"panel %.0f x %.0f px; label min %.0f px wide"
					% [panel.size.x, panel.size.y, pp.overlay_label.get_minimum_size().x]
			)

	# --- 4. what one refresh actually costs on this machine -----------------------
	# Measured, not modelled: the same rebuild the throttle gates, timed in a tight loop.
	var t0: int = Time.get_ticks_usec()
	for _i in range(REFRESH_SAMPLES):
		pp.refresh_overlay_text_now()
	var per_refresh_us: float = float(Time.get_ticks_usec() - t0) / float(REFRESH_SAMPLES)
	var fps_assumed := 30.0
	print("")
	print("  -- measured cost (THIS machine's TextServer; a lower bound for a Cortex-A53) --")
	print("     one refresh                     : %.1f us" % per_refresh_us)
	print("     per second, per-frame at 30 FPS : %.2f ms/s"
		% (per_refresh_us * fps_assumed / 1000.0))
	print("     per second, throttled to %.0f Hz  : %.2f ms/s"
		% [1.0 / float(pp.OVERLAY_REFRESH_INTERVAL),
			per_refresh_us * (1.0 / float(pp.OVERLAY_REFRESH_INTERVAL)) / 1000.0])
	print("     share of a 33.3ms frame saved   : %.2f%% of the budget, per frame"
		% (per_refresh_us / 1000.0 / 33.3 * 100.0))

	# --- 5. emoji vs ASCII, same layout, same changing number ---------------------
	# Why the markers were replaced rather than only throttled. Windows resolves the emoji
	# through DirectWrite, so this is the CHEAP end of the fallback path; the Moto E5 Plus
	# has to search /system/fonts and still cannot draw them. Direction is the evidence,
	# magnitude is not transferable.
	var scratch := Label.new()
	scratch.visible = false
	add_child(scratch)
	var emoji_us: float = _shape_cost_us(
		scratch, "🟢 FPS: %.1f\n🔴 Mem: 120/300MB\n🔋 ΔE: N/A\n✅ PASS"
	)
	var ascii_us: float = _shape_cost_us(
		scratch, "[ok] FPS: %.1f\n[XX] Mem: 120/300MB\nBATT dE: N/A\nPASS"
	)
	# The same emoji, restated instead of changed. This is what the game's own HUDs do:
	# 26 per-frame label writes in the single-player minigames carry an emoji, but almost
	# all of them assign a CONSTANT string ("💧 FILLING..."), and the ones with a format
	# interpolate an int that steps 0..100 rather than a float that moves every frame. If
	# restating is free, those are a one-time cost, not a per-frame one - and the overlay
	# was the outlier because its string carried a live %.1fms.
	var restate_us: float = _restate_cost_us(
		scratch, "🟢 FPS: 30.0\n🔴 Mem: 120/300MB\n🔋 ΔE: N/A\n✅ PASS"
	)
	scratch.queue_free()
	print("")
	print("  -- same layout, same changing number, markers swapped --")
	print("     emoji markers : %.1f us per assignment" % emoji_us)
	print("     ASCII markers : %.1f us per assignment" % ascii_us)
	print("     ratio         : %.2fx" % (emoji_us / maxf(ascii_us, 0.001)))
	print("     emoji, restated unchanged : %.2f us per assignment" % restate_us)
	# Asserted loosely on purpose: the direction cannot flake, a tight threshold on a
	# warm-cache desktop would.
	_check(
		"ASCII markers are not more expensive to shape than emoji",
		ascii_us <= emoji_us * 1.2,
		"ascii %.1f us vs emoji %.1f us" % [ascii_us, emoji_us]
	)
	# Load-bearing for the paragraph above: if a future engine drops Label::set_text's
	# unchanged-string early-out, every constant-emoji HUD label in the project silently
	# becomes a per-frame reshape and this check is where that shows up.
	_check(
		"restating an unchanged emoji string is far cheaper than changing one",
		restate_us < emoji_us * 0.1,
		"restate %.2f us vs change %.1f us (%.0fx cheaper)"
			% [restate_us, emoji_us, emoji_us / maxf(restate_us, 0.001)]
	)

	# --- 6. the readout is live, not frozen --------------------------------------
	if pp.overlay_label != null:
		# Not "did any character change": the readout is full of numbers that move on
		# their own (frame_time_ms alone differs every refresh), so a change-detect would
		# pass even if the throttle had frozen this particular field. The check is that a
		# specific metric's PRINTED value follows the variable behind it.
		await _frames(1)
		var t_warm: int = Time.get_ticks_msec()
		while float(Time.get_ticks_msec() - t_warm) / 1000.0 \
				< float(pp.OVERLAY_REFRESH_INTERVAL) * 2.0:
			await _frames(1)
		var shown_before: int = _drop_shown(String(pp.overlay_label.text))
		pp.dropped_frames += 7
		var t1: int = Time.get_ticks_msec()
		while float(Time.get_ticks_msec() - t1) / 1000.0 \
				< float(pp.OVERLAY_REFRESH_INTERVAL) * 2.0:
			await _frames(1)
		var shown_after: int = _drop_shown(String(pp.overlay_label.text))
		_check(
			"the overlay prints the dropped-frame counter at all",
			shown_before >= 0 and shown_after >= 0,
			"parsed Drop: field before=%d after=%d (-1 = field not found)"
				% [shown_before, shown_after]
		)
		_check(
			"the throttled overlay still reflects a changed metric",
			shown_after - shown_before >= 7,
			"Drop: %d -> %d after +7, within two refresh windows"
				% [shown_before, shown_after]
		)
		pp.dropped_frames -= 7

	pp.set_overlay_visible(false)
	await _frames(4)

	print("")
	print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
