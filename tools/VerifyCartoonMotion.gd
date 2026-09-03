extends Node

## ═══════════════════════════════════════════════════════════════════
## VERIFY: THE CARTOON ACTOR'S MOTION PRIMITIVES
## ═══════════════════════════════════════════════════════════════════
## VerifyCartoonCutscenes already proves all 75 clips resolve and play. It says nothing
## about what the motion LOOKS like, and the primitives every one of those clips is built
## from re-read live values that a running tween may already have moved:
##
##   1. start_idle() captures bob_y = rig.position.y at call time and stop_idle() kills the
##      loop wherever it happens to be, restoring nothing. Every restart therefore adopts a
##      displaced rest line, and the character sinks a little each time. 76 beat scripts
##      call start_idle(); TracePipePathWinOutro calls it twice on the same cast.
##   2. shake() captures base_x = rig.position.x the same way, so a shake that lands while
##      an earlier shake is still running returns the rig to the earlier shake's midpoint
##      instead of to centre — a permanent sideways offset.
##   3. blink() captures open_y = lid_l.position.y. Fired while a blink is closing, that
##      reads the CLOSED value, and the eyes stay shut for the rest of the clip.
##   4. spin_stars() and drip_sweat() build looping tweens and have no matching stop. Two
##      calls leave two loops writing the same property, and _exit_tree() stops neither.
##
## Every number below is read off a live CartoonActor built the way MicrogameOutroBase
## stages one. Tween counts come from SceneTree.get_processed_tweens(), so "stopped" means
## the engine is no longer stepping it, not that a flag was set.
##
## Usage:
##   godot --headless --path <project> res://tools/VerifyCartoonMotion.tscn
## ═══════════════════════════════════════════════════════════════════

const REST_EPS: float = 0.75
const SQUASH_EPS: float = 0.04

var results: Array[bool] = []
var _actor: CartoonActor = null


func _ready() -> void:
	print("\n=== VerifyCartoonMotion ===")
	await get_tree().process_frame
	await _run()
	var failed: int = results.count(false)
	print("  RESULT: %d passed, %d failed" % [results.count(true), failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	print("  %s %s%s" % ["✓" if ok else "✗", label, "" if detail.is_empty() else "  — " + detail])


## Real seconds, sampled frame by frame. Headless spins the loop far faster than 60 fps, so a
## 0.2 s window still yields plenty of samples.
func _wait(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


## The actor, staged the way MicrogameOutroBase._stage_actor() stages one: added to the tree,
## positioned, then mark_rest() before anything animates it.
func _stage() -> CartoonActor:
	var a := CartoonActor.new()
	add_child(a)
	a.build()
	a.position = Vector2(400.0, 500.0)
	a.mark_rest()
	return a


## How many tweens the engine is stepping for this actor right now.
func _tween_count() -> int:
	var n: int = 0
	for tw in get_tree().get_processed_tweens():
		if tw != null and tw.is_valid():
			n += 1
	return n


func _run() -> void:
	_actor = _stage()
	await _wait(0.05)
	var rest_scale: Vector2 = _actor.rig.scale
	var rest_bob: float = _actor.rig.position.y
	var rest_x: float = _actor.rig.position.x
	var lid_open: float = _actor.lid_l.position.y
	_check("[1] premise: the actor builds and rests at its authored pose",
			_actor.rig != null and rest_scale.is_equal_approx(Vector2.ONE),
			"rig scale=%s bob_y=%.2f lid_y=%.2f" % [str(rest_scale), rest_bob, lid_open])

	# ── 1. the idle loop's rest line, across restarts ─────────────────
	# Each restart is cut mid-cycle, which is what a beat script does when it re-poses a cast
	# partway through a clip.
	for _i in range(6):
		_actor.start_idle()
		await _wait(0.42)
		_actor.stop_idle()
		await _wait(0.02)
	# Let the settle-back land, the way a clip ends. Pre-fix this changed nothing — stop_idle()
	# restored nothing at all — so it is not a softened bar.
	await _wait(0.3)
	var sink: float = absf(_actor.rig.position.y - rest_bob)
	var scale_drift: float = (_actor.rig.scale - rest_scale).length()
	_check("[2] restarting the idle loop does not walk the character off its rest line",
			sink <= REST_EPS,
			"bob_y %.2f -> %.2f after 6 restarts (%.2f px of drift)" % [rest_bob, _actor.rig.position.y, sink])
	_check("[3] stopping the idle loop leaves the body at its authored scale",
			scale_drift <= 0.02,
			"rig scale %s -> %s" % [str(rest_scale), str(_actor.rig.scale)])

	# ── 2. a shake that lands on top of a shake ───────────────────────
	_actor.rig.position.x = rest_x
	_actor.shake(10.0, 0.5)
	await _wait(0.2)
	_actor.shake(10.0, 0.5)
	await _wait(1.0)
	var off_x: float = absf(_actor.rig.position.x - rest_x)
	_check("[4] a second shake still returns the body to centre",
			off_x <= REST_EPS,
			"rig x %.2f -> %.2f (%.2f px off centre)" % [rest_x, _actor.rig.position.x, off_x])

	# ── 3. a blink that lands on top of a blink ───────────────────────
	_actor.blink()
	await _wait(0.05)
	_actor.blink()
	await _wait(0.6)
	var lid_off: float = absf(_actor.lid_l.position.y - lid_open)
	_check("[5] a second blink still opens the eyes again",
			lid_off <= REST_EPS,
			"lid y %.2f -> %.2f (%.2f px from open)" % [lid_open, _actor.lid_l.position.y, lid_off])

	# ── 4. the loops with no stop ─────────────────────────────────────
	_actor.stop_idle()
	_actor.stop_blinking()
	await _wait(0.35)   # the settle-back tween must finish before the baseline count
	var base_tweens: int = _tween_count()
	_actor.spin_stars(1.1)
	await _wait(0.05)
	var one_stars: int = _tween_count() - base_tweens
	_actor.spin_stars(1.1)
	_actor.spin_stars(1.1)
	await _wait(0.05)
	var three_stars: int = _tween_count() - base_tweens
	_check("[6] repeating the dizzy-stars gag replaces its loop instead of stacking another",
			one_stars >= 1 and three_stars == one_stars,
			"1 call -> %d loop(s), 3 calls -> %d" % [one_stars, three_stars])
	var stopped_stars: bool = _actor.has_method("stop_stars")
	if stopped_stars:
		_actor.call("stop_stars")
		await _wait(0.05)
	_check("[7] the dizzy-stars gag can be switched off again",
			stopped_stars and _tween_count() == base_tweens and not _actor.stars.visible,
			"stop_stars()=%s, tweens %d -> %d, stars visible=%s" % [
				str(stopped_stars), base_tweens, _tween_count(), str(_actor.stars.visible)])

	base_tweens = _tween_count()
	_actor.drip_sweat()
	await _wait(0.05)
	var one_sweat: int = _tween_count() - base_tweens
	_actor.drip_sweat()
	_actor.drip_sweat()
	await _wait(0.05)
	var three_sweat: int = _tween_count() - base_tweens
	_check("[8] repeating the sweat gag replaces its loops instead of stacking more",
			one_sweat >= 1 and three_sweat == one_sweat,
			"1 call -> %d loop(s), 3 calls -> %d" % [one_sweat, three_sweat])
	var stopped_sweat: bool = _actor.has_method("stop_sweat")
	if stopped_sweat:
		_actor.call("stop_sweat")
		await _wait(0.05)
	_check("[9] the sweat gag can be switched off again",
			stopped_sweat and _tween_count() == base_tweens and not _actor.sweat.visible,
			"stop_sweat()=%s, tweens %d -> %d, sweat visible=%s" % [
				str(stopped_sweat), base_tweens, _tween_count(), str(_actor.sweat.visible)])

	# ── 5. control: the sensors above must be watching real motion ─────
	# Without this, "no drift" and "eyes reopened" could both be passing because nothing
	# moved at all.
	_actor.start_idle()
	var bob: Array = await _sample(_actor.rig, "position:y", 1.0)
	_actor.stop_idle()
	await _wait(0.05)
	_actor.rig.position.x = rest_x
	_actor.shake(12.0, 0.6)
	var shk: Array = await _sample(_actor.rig, "position:x", 0.5)
	await _wait(0.5)
	_actor.blink()
	var lid: Array = await _sample(_actor.lid_l, "position:y", 0.2)
	await _wait(0.4)
	var bob_span: float = bob[1] - bob[0]
	var shake_span: float = shk[1] - shk[0]
	var lid_span: float = lid[1] - lid[0]
	_check("[10] control: the idle, shake and blink sensors see real movement",
			bob_span >= 3.0 and shake_span >= 3.0 and lid_span >= 3.0,
			"bob %.2f px / shake %.2f px / lid %.2f px (samples %d/%d/%d)" % [
				bob_span, shake_span, lid_span, int(bob[2]), int(shk[2]), int(lid[2])])

	# ── 6. does the breathing loop dampen an impact? measured, not assumed ──
	# Both loops write rig.scale, and so does squash(). Tween write order may already
	# favour the later-created tween, so this is read off the engine rather than argued.
	_actor.stop_idle()
	await _wait(0.25)   # let the settle-back land so only squash is writing rig.scale
	_actor.squash(0.5, 1.2)
	var solo: Array = await _sample(_actor.rig, "scale:x", 0.55)
	await _wait(1.0)
	_actor.start_idle()
	_actor.squash(0.5, 1.2)
	var with_idle: Array = await _sample(_actor.rig, "scale:x", 0.55)
	_actor.stop_idle()
	await _wait(1.0)
	var damp: float = absf(with_idle[1] - solo[1])
	_check("[11] an impact still reads at full strength while the breathing loop runs",
			damp <= SQUASH_EPS,
			"squash peak %.4f alone vs %.4f with idle (%.4f apart)" % [solo[1], with_idle[1], damp])


## Samples one float property frame by frame and reports [min, max, sample count]. The sample
## count is printed so a window that was too short to observe cannot pass unnoticed.
func _sample(target: Object, prop: String, seconds: float) -> Array:
	var lo: float = INF
	var hi: float = -INF
	var n: int = 0
	var t: float = 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		var v: float = float(target.get_indexed(prop))
		lo = minf(lo, v)
		hi = maxf(hi, v)
		n += 1
	return [lo, hi, n]
