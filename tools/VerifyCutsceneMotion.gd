extends Node

## ═══════════════════════════════════════════════════════════════════
## "REDUCED MOTION SHORTENS THE CUTSCENES" HARNESS
## ═══════════════════════════════════════════════════════════════════
## Companion to tools/VerifyReducedMotion.tscn, which proved the setting now reaches
## JuiceEffects. That fix turned out to cover almost nothing on its own: JuiceEffects
## has exactly TWO call sites in the whole project (both in FixLeak.gd), while the
## animation a player actually waits through is the intro/outro cutscene in front of
## every round — 1101 create_tween() sites live outside JuiceEffects entirely.
##
## Every cutscene in the live path already expresses its runtime as a duration DIVIDED
## by a speed number (MiniGameIntroCutscene: `length = 4.0 / speed`; the outro: 5.0;
## CartoonStage and the authored beat clips: `speed_scale`), and that number was
## computed independently at six sites from ONE input — whether the device is missing
## frames. The player's "reduced motion" preference was not an input anywhere.
##
## The fix folds AccessibilityManager.get_animation_speed() into all six, multiplying
## rather than replacing so a weak device and a motion-averse player compose.
##
## Measured here:
##   [1] control: with reduced motion OFF, MiniGameBase._motion_speed() is 1.0 and the
##       authored profiles keep their per-game pacing (1.15/0.95/1.05 …) untouched.
##   [2] with it ON, _motion_speed() is 3.0 and every profile's "speed" is exactly 3x
##       its authored value — the per-game pacing survives, it is not overwritten.
##   [3] the same for MiniGameIntroBridge, which is a separate script on the path that
##       runs before a minigame exists.
##   [4] "distance" and "pop" are NOT touched: reduced motion is about duration, and
##       flattening the poses would change what the cutscene depicts.
##   [5] CartoonStage accepts the composed number as its divisor (speed_scale).
##   [6] END TO END: the real intro cutscene scene, configured exactly the way
##       MiniGameBase now configures it, reaches cutscene_finished about 3x sooner with
##       reduced motion on — with the full-speed run beside it as the control.
##   [7] the same, end to end, for the real win-outro scene.
##
## [1]-[5] are cheap reads; [6]-[7] are four real cutscene playbacks (~12 s total).
##
## reduced_motion is written directly, never through set_reduced_motion(), which would
## persist the flag into the player's settings file. It is restored at the end.
##
## Run:
##   godot --headless --path . res://tools/VerifyCutsceneMotion.tscn

const INTRO_SCENE: String = "res://scenes/ui/cutscenes/intro/FixLeakIntro.tscn"
const OUTRO_SCENE: String = "res://scenes/ui/cutscenes/MiniGameWinOutroCutscene.tscn"
## Authored lengths inside those two scenes, before any speed divisor.
const INTRO_LEN: float = 4.0
const OUTRO_LEN: float = 5.0
## get_animation_speed() while reduced motion is on.
const EXPECTED_FACTOR: float = 3.0
## Timing tolerance, RELATIVE (25%) with a 0.15 s floor rather than one absolute
## window for every clip: a fixed 0.55 s was fine against the 4 s intro but would
## have let the 1.38 s beat clip's full-length run pass as its 0.46 s reduced one.
## Cutscenes spawn dozens of Polygon2D props, so the first frame of one is slow and
## a real run lands a little late; 25% absorbs that and still cannot absorb 3x.
## MicrogameIntroBase timeline at speed_scale 1.0: SETUP 0.35 + IMPACT HOLD 0.18 +
## PAYOFF 0.60 + SNAP 0.25.
const BEAT_LEN: float = 1.38
const BEAT_SCENE: String = "res://scenes/ui/cutscenes/beats/FixLeakIntro.tscn"
## A cutscene that never reports finished must be called out, not waited on forever.
const BUDGET: float = 20.0

var results: Array = []
var original_reduced: bool = false


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  CUTSCENE REDUCED-MOTION HARNESS")
	print("═══════════════════════════════════════════════════════════")
	original_reduced = bool(AccessibilityManager.reduced_motion)
	# A build without the fix has neither helper. Calling a missing method through
	# .call() returns null, and null then flows into float() and into a
	# Dictionary-typed argument, which aborts the calling function mid-await and hangs
	# the run instead of reporting — measured on the JuiceEffects harness, where a
	# pre-fix run died on its timeout with an empty result section. So the absence is
	# a measured FAIL and the harness stops there.
	if not _has_fix():
		_check("the cutscene speed helpers exist at all", false,
			"MiniGameBase._motion_speed()/_with_motion_speed() are not declared, so no"
			+ " cutscene reads the reduced-motion setting")
		AccessibilityManager.reduced_motion = original_reduced
		_finish()
		return
	_check_helpers()
	await _check_end_to_end()
	AccessibilityManager.reduced_motion = original_reduced
	_finish()


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


## The two scripts that compute cutscene speed, instantiated WITHOUT being added to the
## tree. Both helpers read only autoloads, and keeping the nodes out of the tree stops
## MiniGameBase._ready() from starting a round and the bridge's _ready() from launching
## a minigame — this measures the arithmetic, not the flow.
func _speed_sources() -> Array:
	var mgb: Node = (load("res://scripts/MiniGameBase.gd") as GDScript).new()
	var bridge: Node = (load("res://scenes/ui/cutscenes/MiniGameIntroBridge.gd")
		as GDScript).new()
	return [mgb, bridge]


func _check_helpers() -> void:
	var src := _speed_sources()
	var mgb: Node = src[0]
	var bridge: Node = src[1]

	# ── control: reduced motion off changes nothing at all.
	AccessibilityManager.reduced_motion = false
	var base_factor: float = float(mgb.call("_motion_speed"))
	var base_outro: Dictionary = mgb.call("_with_motion_speed",
		mgb.call("_get_outro_anim_profile", true))
	var base_authored: Dictionary = mgb.call("_get_outro_anim_profile", true)
	var base_bridge: Dictionary = bridge.call("_with_motion_speed",
		bridge.call("_get_intro_anim_profile", "FixLeak"))
	var base_bridge_authored: Dictionary = bridge.call("_get_intro_anim_profile", "FixLeak")
	var base_cartoon: float = float((mgb.call("_get_cartoon_speed") as Dictionary)["speed"])
	_check("control: with reduced motion off the motion factor is exactly 1.0",
		is_equal_approx(base_factor, 1.0), "_motion_speed() = %.3f" % base_factor)
	_check("control: with it off an authored outro profile is passed through unchanged",
		is_equal_approx(float(base_outro["speed"]), float(base_authored["speed"])),
		"speed %.3f vs authored %.3f"
			% [float(base_outro["speed"]), float(base_authored["speed"])])
	_check("control: with it off the bridge's intro profile is unchanged",
		is_equal_approx(float(base_bridge["speed"]), float(base_bridge_authored["speed"])),
		"speed %.3f vs authored %.3f"
			% [float(base_bridge["speed"]), float(base_bridge_authored["speed"])])
	_check("control: with it off _get_cartoon_speed() is the plain device value",
		is_equal_approx(base_cartoon, 1.0),
		"speed = %.3f (headless desktop is not low-end)" % base_cartoon)

	# ── reduced motion on: every speed number is multiplied, none is overwritten.
	AccessibilityManager.reduced_motion = true
	var factor: float = float(mgb.call("_motion_speed"))
	_check("reduced motion makes MiniGameBase._motion_speed() report %.1f" % EXPECTED_FACTOR,
		is_equal_approx(factor, EXPECTED_FACTOR), "_motion_speed() = %.3f" % factor)

	var outro: Dictionary = mgb.call("_with_motion_speed",
		mgb.call("_get_outro_anim_profile", true))
	_check("the outro profile's speed is exactly %.1fx its authored value" % EXPECTED_FACTOR,
		is_equal_approx(float(outro["speed"]), float(base_authored["speed"]) * EXPECTED_FACTOR),
		"%.3f, authored %.3f" % [float(outro["speed"]), float(base_authored["speed"])])
	_check("the outro profile keeps its authored distance and pop (duration only)",
		is_equal_approx(float(outro["distance"]), float(base_authored["distance"]))
			and is_equal_approx(float(outro["pop"]), float(base_authored["pop"])),
		"distance %.2f/%.2f pop %.2f/%.2f" % [float(outro["distance"]),
			float(base_authored["distance"]), float(outro["pop"]),
			float(base_authored["pop"])])

	var bridge_profile: Dictionary = bridge.call("_with_motion_speed",
		bridge.call("_get_intro_anim_profile", "FixLeak"))
	_check("the bridge's intro profile is multiplied too (separate script, same path)",
		is_equal_approx(float(bridge_profile["speed"]),
			float(base_bridge_authored["speed"]) * EXPECTED_FACTOR),
		"%.3f, authored %.3f"
			% [float(bridge_profile["speed"]), float(base_bridge_authored["speed"])])

	var cartoon: float = float((mgb.call("_get_cartoon_speed") as Dictionary)["speed"])
	_check("_get_cartoon_speed() carries the factor to CartoonStage and the beat clips",
		is_equal_approx(cartoon, EXPECTED_FACTOR),
		"speed = %.3f" % cartoon)

	# CartoonStage divides every one of its durations by speed_scale, so proving the
	# composed number lands in that field proves the whole clip shortens with it.
	var stage: Node = CartoonStage.new()
	stage.call("configure", CartoonStage.Kind.CAUSE, "FixLeak", {"speed": cartoon})
	var landed: float = float(stage.get("speed_scale"))
	_check("CartoonStage adopts the composed number as its duration divisor",
		is_equal_approx(landed, EXPECTED_FACTOR), "speed_scale = %.3f" % landed)
	stage.free()

	AccessibilityManager.reduced_motion = false
	mgb.free()
	bridge.free()


## Play a real cutscene scene and return the wall-clock seconds until it reports
## cutscene_finished, or -1.0 if it never did inside BUDGET.
func _play(scene_path: String, reduced: bool, is_outro: bool) -> float:
	AccessibilityManager.reduced_motion = reduced
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		_check("the cutscene scene %s loaded" % scene_path, false, "load() returned null")
		return -1.0
	var clip: Node = packed.instantiate()
	add_child(clip)

	# Configured exactly the way the shipped code now configures it, so the numbers
	# under test are the ones the game will use rather than harness-chosen constants.
	var mgb: Node = (load("res://scripts/MiniGameBase.gd") as GDScript).new()
	if is_outro:
		clip.call("configure", true, "Nice save!", 120, 3, 3,
			mgb.call("_with_motion_speed", mgb.call("_get_outro_anim_profile", true)))
	else:
		clip.call("configure", "FixLeak", "Get ready...",
			{"speed": mgb.call("_motion_speed")})
	mgb.free()

	var finished := [false]
	clip.connect("cutscene_finished", func() -> void: finished[0] = true)
	var start: int = Time.get_ticks_msec()
	clip.call("play_cutscene")
	var elapsed: float = 0.0
	while not finished[0] and elapsed < BUDGET:
		await get_tree().process_frame
		elapsed = (Time.get_ticks_msec() - start) / 1000.0
	if is_instance_valid(clip):
		clip.queue_free()
	print("  [reduced_motion=%s] %s finished in %.2fs%s"
		% [str(reduced), scene_path.get_file(), elapsed,
			"" if finished[0] else "  (NEVER EMITTED cutscene_finished)"])
	return elapsed if finished[0] else -1.0


## 25% of the expected value, never less than 0.15 s.
func _tol(expected: float) -> float:
	return max(0.15, expected * 0.25)


## `factor` is how much faster reduced motion is expected to make THIS family. It is not always
## EXPECTED_FACTOR: an authored beat clip caps the compression it accepts at
## _payoff_sec() / SKIP_PAYOFF_HOLD_SEC so the punchline frame stays readable, so asking a clip for
## 3.0x and measuring 3.0x would be asserting a bug. The call site passes the cap it derives from
## the class itself, so this stays true if the beat lengths are re-timed.
func _check_pair(name: String, authored: float, full: float, reduced: float,
		factor: float = EXPECTED_FACTOR) -> void:
	# The control comes first: without evidence that the full-speed run really takes the
	# authored time, a short reduced run proves nothing — a cutscene that silently
	# collapsed to nothing would "pass" the fast case.
	_check("control: %s at full speed runs its authored ~%.1fs" % [name, authored],
		full > 0.0 and absf(full - authored) <= _tol(authored),
		"took %.2fs (authored %.1fs, tolerance %.2fs)" % [full, authored, _tol(authored)])
	var target: float = authored / factor
	_check("%s under reduced motion runs ~%.2fs instead" % [name, target],
		reduced > 0.0 and absf(reduced - target) <= _tol(target),
		"took %.2fs (target %.2fs, tolerance %.2fs, factor %.2fx)" % [reduced, target, _tol(target), factor])
	_check("%s still reports cutscene_finished under reduced motion (shortened, not"
			% name + " broken)",
		reduced > 0.0, "completion time %.2fs (-1 means the signal never came)" % reduced)
	var floor_ratio: float = maxf(factor * 0.66, 1.2)
	_check("%s is at least %.2fx faster under reduced motion" % [name, floor_ratio],
		reduced > 0.0 and full / reduced >= floor_ratio,
		"%.2fs vs %.2fs = %.2fx" % [full, reduced, (full / reduced) if reduced > 0.0 else 0.0])


func _check_end_to_end() -> void:
	var intro_full: float = await _play(INTRO_SCENE, false, false)
	var intro_reduced: float = await _play(INTRO_SCENE, true, false)
	_check_pair("the intro cutscene", INTRO_LEN, intro_full, intro_reduced)

	# The authored beat clips are the third family on this path. They divide their
	# 4-beat timeline (0.35 + 0.18 + 0.60 + 0.25 = 1.38 s) by speed_scale, which
	# MiniGameIntroBridge now multiplies by the motion factor - but only up to the cap the clip
	# itself enforces, read here off the class rather than written in as a number.
	var beat_probe: Node = (load("res://scripts/cutscenes/MicrogameIntroBase.gd") as GDScript).new()
	var beat_cap: float = minf(EXPECTED_FACTOR, float(beat_probe.call("_max_speed")))
	beat_probe.free()
	var beat_full: float = await _play_beat(false)
	var beat_reduced: float = await _play_beat(true)
	_check_pair("the authored beat intro clip", BEAT_LEN, beat_full, beat_reduced, beat_cap)

	var outro_full: float = await _play(OUTRO_SCENE, false, true)
	var outro_reduced: float = await _play(OUTRO_SCENE, true, true)
	# The outro's authored 5 s is additionally scaled by the per-game profile (1.05 for a
	# win on this key), so the control window is centred on that, not on a bare 5 s.
	var mgb: Node = (load("res://scripts/MiniGameBase.gd") as GDScript).new()
	var authored_speed: float = float((mgb.call("_get_outro_anim_profile", true)
		as Dictionary)["speed"])
	mgb.free()
	_check_pair("the win-outro cutscene", OUTRO_LEN / authored_speed, outro_full,
		outro_reduced)


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


## Are both speed helpers declared on both scripts on the cutscene path?
func _has_fix() -> bool:
	var src := _speed_sources()
	var ok: bool = src[0].has_method("_motion_speed") \
		and src[0].has_method("_with_motion_speed") \
		and src[1].has_method("_motion_speed") \
		and src[1].has_method("_with_motion_speed")
	src[0].free()
	src[1].free()
	return ok


## Play an authored beat clip the way MiniGameIntroBridge plays it — set speed_scale
## from the composed factor, await outro_finished — and time it.
func _play_beat(reduced: bool) -> float:
	AccessibilityManager.reduced_motion = reduced
	var packed: PackedScene = load(BEAT_SCENE) as PackedScene
	if packed == null:
		_check("the beat clip %s loaded" % BEAT_SCENE, false, "load() returned null")
		return -1.0
	var clip: Node = packed.instantiate()
	var bridge: Node = (load("res://scenes/ui/cutscenes/MiniGameIntroBridge.gd")
		as GDScript).new()
	# 1.0 stands in for the bridge's device term (headless desktop is not low-end), so
	# what is being measured here is the motion factor alone.
	clip.set("speed_scale", 1.0 * float(bridge.call("_motion_speed")))
	bridge.free()
	add_child(clip)

	var finished := [false]
	clip.connect("outro_finished", func() -> void: finished[0] = true)
	var start: int = Time.get_ticks_msec()
	clip.call("play_cutscene")
	var elapsed: float = 0.0
	while not finished[0] and elapsed < BUDGET:
		await get_tree().process_frame
		elapsed = (Time.get_ticks_msec() - start) / 1000.0
	if is_instance_valid(clip):
		clip.queue_free()
	print("  [reduced_motion=%s] %s finished in %.2fs%s"
		% [str(reduced), BEAT_SCENE.get_file(), elapsed,
			"" if finished[0] else "  (NEVER EMITTED outro_finished)"])
	return elapsed if finished[0] else -1.0
