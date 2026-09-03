extends Node

## ═══════════════════════════════════════════════════════════════════
## "REDUCED MOTION ACTUALLY SHORTENS ANIMATIONS" HARNESS
## ═══════════════════════════════════════════════════════════════════
## AccessibilityManager.get_animation_speed() returns 3.0 while reduced motion is on
## and 1.0 otherwise — and had ZERO call sites anywhere in the project. Reduced motion
## suppressed particles (should_show_particles) and screen shake
## (is_screen_shake_enabled) and nothing else, so a player who turned it on because
## motion makes them ill still watched every fade, slide, bounce and pop-up at full
## length. The Settings toggle promised more than it did.
##
## JuiceEffects now routes its timed effects through _motion_time(), which divides the
## requested duration by that multiplier, and pulse() — which loops forever, and would
## become BUSIER if merely sped up — opts out entirely.
##
## This measures behaviour, not the presence of a call: it drives real tweens on real
## nodes and times when the animated property arrives.
##
##   [1] control: with reduced motion OFF a 0.45 s fade really takes ~0.45 s — i.e. the
##       harness can see tween timing at all.
##   [2] with reduced motion ON the same call completes in ~0.15 s (0.45 / 3.0), and at
##       least 2x faster than [1]. Completion time is polled per frame rather than
##       sampled at a fixed instant, because a headless frame hitch can shift a
##       fixed-instant sample far enough to fake the comparison.
##   [3] reduced motion SHORTENS the fade rather than cancelling it — alpha still 1.0.
##   [4] control: pulse() animates while reduced motion is OFF …
##   [5] … and leaves the node at rest while it is ON, rather than looping 3x faster.
##   [6] _motion_time() never collapses a duration to zero (one 60 fps frame floor),
##       passes 0 through, and is the identity while reduced motion is off.
##
## reduced_motion is written directly rather than through set_reduced_motion(), which
## would persist the flag into the player's settings file. It is restored at the end.
##
## Run:
##   godot --headless --path . res://tools/VerifyReducedMotion.tscn

## The duration under test: long enough that a full-speed run is unmistakable and a
## divided-by-three one is unmistakably shorter.
const FADE: float = 0.45
## Polling budget per fade — well past a full-speed one, so a fade that never
## completes is reported as such instead of spinning.
const BUDGET: float = 2.0
## Headroom for frame granularity and the odd headless hitch. Wide enough that
## timing noise cannot fail a correct build, narrow enough that 0.45s cannot pass
## as 0.15s (0.15 + 0.12 = 0.27 < 0.45).
const SLACK: float = 0.12
## The longest delta the engine will ever hand a tween in one frame:
## max_physics_steps_per_frame / physics_ticks_per_second, 8 / 60 by project default.
## A frame that takes longer than this in wall-clock terms still advances animations by
## only this much, so wall time and animation time diverge for as long as it lasts.
## Measured, not assumed - tools/ProbeTweenClock reported max_delta pinned at exactly
## 0.1333s while frames were running 160-230 ms long.
const DELTA_CLAMP: float = 8.0 / 60.0
## A frame time this far under the clamp means wall time and animation time agree, so a
## wall-clock stopwatch is a valid way to measure a tween again.
const SETTLED_DELTA: float = 0.05
## Consecutive settled frames wanted before the first measurement.
const SETTLED_RUN: int = 10

var results: Array = []
var original_reduced: bool = false


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  REDUCED-MOTION HARNESS")
	print("═══════════════════════════════════════════════════════════")
	original_reduced = bool(AccessibilityManager.reduced_motion)
	print("  reduced_motion at boot = %s | get_animation_speed() = %s"
		% [str(original_reduced), str(AccessibilityManager.get_animation_speed())])
	await _run()
	AccessibilityManager.reduced_motion = original_reduced
	_finish()


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


## A fresh Control per case: modulate.a is the animated property, so a node reused
## across cases would start each measurement from the previous case's end state.
func _fresh_target() -> Control:
	var c := Control.new()
	c.size = Vector2(64, 64)
	add_child(c)
	return c


## Time how long fade_in() actually takes to reach full alpha, by polling every frame
## until it lands. Sampling alpha at fixed wall-clock instants was the first design and
## it was too weak: the headless frame rate hitches (PerformanceProfiler's first thermal
## read landed between two cases), the timer fires on the first frame past its deadline,
## and a hitch therefore inflates the sampled alpha. On the pre-fix build that jitter
## alone made a "reduced is further along than full speed" comparison pass — 0.673 vs
## 0.333 at 0.20 s — while both fades were in fact the same 0.45 s. Measuring the
## completion time and demanding a factor-of-two separation cannot be faked by a hitch.
##
## Returns seconds, or -1.0 if it never completed inside the budget.
##
## Re-measures if the engine clamped a frame mid-fade. A stopwatch only measures a tween
## while wall time and animation time agree, and they stop agreeing the moment a frame
## runs longer than DELTA_CLAMP: the tween is handed 0.1333s of progress for 0.23s of
## wall clock, so the fade looks ~2x too slow while behaving perfectly. That is not
## hypothetical - it is what this harness reported for two windows. Cold, one frame after
## boot, a correct 0.45s fade completed in 4 frames and 1.013s of wall clock, and the
## harness called the divisor broken on the strength of it, while the ratio it printed on
## the very next line (3.09x) and _motion_time(0.45) = 0.4500 both said the divisor was
## fine. So: settle first, and if a clamped frame lands inside a measurement anyway,
## throw that sample away and take another rather than publish a number the stopwatch
## cannot support.
func _time_fade(reduced: bool) -> float:
	for attempt in range(3):
		await _settle()
		AccessibilityManager.reduced_motion = reduced
		var target := _fresh_target()
		JuiceEffects.fade_in(target, FADE)
		var start: int = Time.get_ticks_msec()
		var elapsed: float = 0.0
		var worst: float = 0.0
		while target.modulate.a < 1.0 and elapsed < BUDGET:
			await get_tree().process_frame
			worst = maxf(worst, get_process_delta_time())
			elapsed = (Time.get_ticks_msec() - start) / 1000.0
		var done: bool = target.modulate.a >= 1.0
		target.queue_free()
		var clamped: bool = worst >= DELTA_CLAMP - 0.001
		print("  [reduced_motion=%s] fade_in(%.2fs) reached full alpha in %.3fs%s%s"
			% [str(reduced), FADE, elapsed,
				"" if done else "  (NEVER COMPLETED)",
				"  (frame clamped at %.4fs - discarding sample)" % worst if clamped else ""])
		if not clamped:
			return elapsed if done else -1.0
	print("  [reduced_motion=%s] every attempt hit a clamped frame - unmeasurable here"
		% str(reduced))
	return -1.0


## Burn frames until the process is running fast enough for a wall-clock stopwatch to
## track a tween. Headless boot frames on this machine take 160-230 ms each - autoload
## init, the first resource loads, PerformanceProfiler's first thermal read - and settle
## to ~7 ms after about a dozen frames.
func _settle() -> void:
	var run: int = 0
	var burned: int = 0
	while run < SETTLED_RUN and burned < 600:
		await get_tree().process_frame
		burned += 1
		if get_process_delta_time() < SETTLED_DELTA:
			run += 1
		else:
			run = 0
	if run < SETTLED_RUN:
		print("  ! frame time never settled below %.3fs in %d frames (last %.4fs)"
			% [SETTLED_DELTA, burned, get_process_delta_time()])


## Returns the node's scale after letting a pulse() run for most of a cycle. pulse()
## grows the node over duration * 0.5, so sampling at 0.30 s of a 1.0 s pulse catches
## it mid-growth in either direction.
func _time_pulse(reduced: bool) -> float:
	# Same reason as _time_fade(): the 0.30s sampling timer and the pulse tween both run
	# on the clamped clock, so on a cold frame "0.30s in" is not 0.30s of animation.
	await _settle()
	AccessibilityManager.reduced_motion = reduced
	var target := Node2D.new()
	add_child(target)
	var before: Vector2 = target.scale
	JuiceEffects.pulse(target, 1.4, 1.0)
	await get_tree().create_timer(0.30).timeout
	var moved: float = absf(target.scale.x - before.x)
	target.queue_free()
	print("  [reduced_motion=%s] pulse(1.4, 1.0s): |scale.x - %.2f| = %.4f at 0.30s"
		% [str(reduced), before.x, moved])
	return moved


func _run() -> void:
	# ── control: full speed. Without this the reduced-motion case below proves nothing
	# — a fade that never ran at all would also "finish early".
	var off: float = await _time_fade(false)
	_check("control: at full speed the %.2fs fade takes about %.2fs" % [FADE, FADE],
		off >= FADE * 0.7 and off <= FADE + SLACK,
		"took %.3fs (window %.2f–%.2fs)" % [off, FADE * 0.7, FADE + SLACK])

	# ── the fix under test: get_animation_speed() is 3.0, so 0.45 / 3 = 0.15 s.
	var on: float = await _time_fade(true)
	_check("reduced motion finishes the same fade in about %.2fs (%.2f / 3.0)"
			% [FADE / 3.0, FADE],
		on >= 0.0 and on <= FADE / 3.0 + SLACK,
		"took %.3fs (limit %.2fs) — get_animation_speed() must divide the duration,"
			% [on, FADE / 3.0 + SLACK]
			+ " not go unread")
	_check("reduced motion shortens the fade, it does not cancel it (alpha still 1.0)",
		on > 0.0, "completion time %.3fs (-1 means it never reached full alpha)" % on)
	_check("reduced motion is at least 2x faster than full speed",
		on > 0.0 and off / on >= 2.0,
		"%.3fs vs %.3fs = %.2fx" % [off, on, (off / on) if on > 0.0 else 0.0])

	# ── pulse(): loops forever, so it opts out instead of tripling in speed.
	var pulse_off: float = await _time_pulse(false)
	_check("control: pulse() animates while reduced motion is off",
		pulse_off > 0.01, "scale moved %.4f" % pulse_off)
	var pulse_on: float = await _time_pulse(true)
	_check("reduced motion leaves pulse() at rest rather than looping 3x faster",
		is_zero_approx(pulse_on), "scale moved %.4f" % pulse_on)

	# ── the clamp: a scaled duration must still be a real tween, not an
	# instant jump. Guarded on existence and called dynamically (see
	# _motion_time below) so a build without the fix REPORTS instead of hanging.
	if not _has_static("_motion_time"):
		_check("JuiceEffects declares the motion-time scaler at all", false,
			"_motion_time() is not declared, so no duration is scaled anywhere")
		return
	AccessibilityManager.reduced_motion = true
	var tiny: float = _motion_time(0.03)
	_check("a tiny duration is clamped to at least one 60fps frame, not to zero",
		tiny >= 0.016, "_motion_time(0.03) = %.4f" % tiny)
	_check("a zero duration passes through untouched",
		is_zero_approx(_motion_time(0.0)), "_motion_time(0.0) = %.4f" % _motion_time(0.0))
	AccessibilityManager.reduced_motion = false
	_check("control: with reduced motion off _motion_time is the identity",
		is_equal_approx(_motion_time(FADE), FADE),
		"_motion_time(%.2f) = %.4f" % [FADE, _motion_time(FADE)])



func _finish() -> void:
	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("")
	print("  reduced_motion restored to %s" % str(AccessibilityManager.reduced_motion))
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [results.size() - failed, failed])
	if failed > 0:
		for r in results:
			if not r["ok"]:
				print("    ✗ %s" % r["label"])
	print("═══════════════════════════════════════════════════════════")
	print("")
	get_tree().quit(1 if failed > 0 else 0)


## Is `name` declared as a static on JuiceEffects? Asked of the script's own method
## list rather than by calling it, because the call is what aborts.
func _has_static(name: String) -> bool:
	var script: GDScript = JuiceEffects as GDScript
	for m in script.get_script_method_list():
		if String(m.get("name", "")) == name:
			return true
	return false


## Call JuiceEffects._motion_time() without naming it at parse time.
##
## `JuiceEffects._motion_time(x)` written literally is resolved when THIS script
## compiles, so against a build that lacks the fix the whole harness fails to load
## ("Parse Error: Static function _motion_time() not found") and the run then hangs
## with nothing reported — no script is left alive to reach quit(). Measured: a 60 s
## pre-fix run died on the timeout with an empty result section. Dispatching through
## the script object keeps the lookup dynamic, so a missing scaler is a FAIL line.
func _motion_time(seconds: float) -> float:
	return float((JuiceEffects as GDScript).call("_motion_time", seconds))
