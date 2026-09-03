extends Node

## ═══════════════════════════════════════════════════════════════════
## SPOT-THE-SPECK DIFFICULTY + LEGIBILITY VERIFICATION
## ═══════════════════════════════════════════════════════════════════
## Two defects, both of which made the game's stated difficulty curve a fiction.
##
## DEAD KNOBS  _apply_difficulty_settings() set five members. Only two of them
##             (target_correct, game_duration) were ever read. _spawn_glass()
##             hardcoded `randf() > 0.5` and `randi_range(5, 12)` - the Medium
##             values - so dirty_chance, num_specks_min and num_specks_max were
##             written every round and read by nothing. Easy ("8-15 very visible
##             specks", 60% dirty) and Hard ("2-6 subtle specks", 40% dirty) both
##             played exactly as Medium: only the quota and the clock changed.
##             A swept check over all 25 single-player and 12 multiplayer scripts
##             found this scene to be the only one with write-only knobs.
##
## TOO SMALL   The glass polygons are authored at +/-60 x -105..100 and were drawn
##             at scale 1.0 on the 1920x1080 canvas the project ships: 5.7% of the
##             width. Every other element in the scene is screen-relative, so the
##             background scaled with the screen and the one thing the player has
##             to inspect did not. The specks inside it were 3-8 units in radius.
##
## WHY dp AND NOT UNITS, for the legibility claim
##   Same reasoning as tools/AuditMobileUI.gd: a canvas unit is not a pixel. The
##   project stretches a 1920-unit canvas (canvas_items / expand), so on the lowest
##   device profile that audit names - 854x480 - one canvas unit is 854/1920 =
##   0.445 device pixels. A speck's real width is
##       radius * 2 * glass_scale * 0.445
##   and a brown blob on blue water needs roughly 6 device pixels across before a
##   player can tell it is dirt. That product, not the authored radius, is what
##   this harness asserts.
##
## Difficulty is forced the way the algorithm forces it - by assigning
## AdaptiveDifficulty.current_difficulty - and every number below is read off a
## real booted scene. Nothing is stubbed and nothing is asserted from the source.
##
## Run:
##   Godot --headless --path <project> res://tools/VerifySpeckDifficulty.tscn
## Exit code 0 = all passed, 1 = at least one failure.
## ═══════════════════════════════════════════════════════════════════

const DIFFICULTIES: PackedStringArray = ["Easy", "Medium", "Hard"]

## Glasses sampled per difficulty. Sized by the SHARPEST claim below, which is not the
## per-difficulty tolerance but the ordering one: Easy > Medium > Hard on the dirty ratio
## compares two measured proportions 0.10 apart, whose difference carries a standard error
## of sqrt(p1(1-p1)/n + p2(1-p2)/n) ~ 0.7/sqrt(n). At n=200 that is 0.050 - the configured
## gap is only 2 sigma, so the ordering flakes, and it did: a run measured Easy 0.545 below
## Medium 0.555 while both were still inside their own tolerances. n=1500 puts the standard
## error at 0.018, so the gap is 5.5 sigma and the ordering is decidable rather than lucky.
## The per-difficulty tolerance is derived from SAMPLES, so it tightens with it.
const SAMPLES: int = 1500

## The lowest-end profile in tools/AuditMobileUI.gd DEVICES.
const LOW_END_W: float = 854.0
const CANVAS_W: float = 1920.0

## Minimum on-screen width, in device pixels on that profile, for a speck to read
## as dirt rather than as an artefact.
const MIN_SPECK_DEVICE_PX: float = 6.0

## The glass has to be a real subject, not an island: at least this share of the
## viewport height, and clear of the hint labels above and below it.
const MIN_GLASS_HEIGHT_SHARE: float = 0.30

var _pass: int = 0
var _fail: int = 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [ok]   %s%s" % [label, "" if detail.is_empty() else "  " + detail])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [label, "" if detail.is_empty() else "  " + detail])


## Boots the scene with `diff` forced and stops while the instruction overlay is
## still up, the same way tools/VerifyDifficultyInit.gd does.
func _boot(diff: String) -> Node:
	if AdaptiveDifficulty:
		AdaptiveDifficulty.current_difficulty = diff
		AdaptiveDifficulty.progressive_level = 0
	var packed := load("res://scenes/minigames/SpotTheSpeck.tscn") as PackedScene
	if packed == null:
		_check(false, "SpotTheSpeck.tscn loads")
		return null
	var game: Node = packed.instantiate()
	add_child(game)
	for _i in range(6):
		await get_tree().process_frame
	return game


## Everything measurable about one spawned glass, read off the live nodes.
func _measure_glass(game: Node) -> Dictionary:
	var glass = game.get("current_glass")
	if glass == null or not is_instance_valid(glass):
		return {}
	var g := glass as Node2D
	var specks: int = 0
	var min_r: float = 1e9
	var max_r: float = 0.0
	for c in g.get_children():
		var poly := c as Polygon2D
		if poly == null or poly.polygon.size() != 5:
			continue
		# The specks are the only 5-gons in the rig; the body, rim, water and
		# highlight are all 4-gons. Their radius is the vertex distance from centre.
		specks += 1
		var r: float = poly.polygon[0].length()
		min_r = minf(min_r, r)
		max_r = maxf(max_r, r)
	return {
		"dirty": bool(g.get_meta("dirty", false)),
		"specks": specks,
		"min_r": 0.0 if specks == 0 else min_r,
		"max_r": max_r,
		# The node's live scale is mid-entrance-tween (it starts at half the final size),
		# so the authoritative number is the member the scene resolved from the viewport.
		"scale": float(game.get("_glass_scale")),
	}


## Spawns SAMPLES glasses at one difficulty and aggregates what the scene produced.
func _sample(game: Node, _diff: String) -> Dictionary:
	var dirty: int = 0
	var counts: Array[int] = []
	var min_r: float = 1e9
	var glass_scale: float = 0.0
	var frames: int = 0
	for i in range(SAMPLES):
		# _spawn_glass() replaces current_glass and appends to `glasses`; freeing the
		# previous one keeps the sample from growing a 200-glass scene.
		var prev = game.get("current_glass")
		if prev != null and is_instance_valid(prev):
			(prev as Node2D).queue_free()
		game.call("_spawn_glass")
		var m := _measure_glass(game)
		if m.is_empty():
			continue
		if bool(m["dirty"]):
			dirty += 1
			counts.append(int(m["specks"]))
			min_r = minf(min_r, float(m["min_r"]))
		glass_scale = maxf(glass_scale, float(m["scale"]))
		# One frame every 20 spawns keeps queue_free() draining without making the
		# sample take 200 frames.
		if i % 20 == 19:
			frames += 1
			await get_tree().process_frame
	var lo: int = 1 << 30
	var hi: int = 0
	var sum: int = 0
	for c in counts:
		lo = mini(lo, c)
		hi = maxi(hi, c)
		sum += c
	return {
		"dirty_ratio": float(dirty) / float(SAMPLES),
		"n_dirty": dirty,
		"count_lo": 0 if counts.is_empty() else lo,
		"count_hi": hi,
		"count_mean": 0.0 if counts.is_empty() else float(sum) / float(counts.size()),
		"min_r": 0.0 if counts.is_empty() else min_r,
		"scale": glass_scale,
		"frames": frames,
	}


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== VerifySpeckDifficulty ===")
	# The headless DisplayServer opens a square-ish window, which is not an aspect any
	# device in tools/AuditMobileUI.gd DEVICES has, and the glass scale is resolved from
	# viewport HEIGHT. Measure at the canvas project.godot actually declares instead, so
	# the numbers below are the ones a player gets.
	var want := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 1080)))
	get_window().size = want
	await get_tree().process_frame
	var canvas_h: float = get_viewport().get_visible_rect().size.y
	var px_per_unit: float = LOW_END_W / CANVAS_W
	print("  %d glasses per difficulty; low-end profile %.0f px wide -> %.3f device px per canvas unit"
		% [SAMPLES, LOW_END_W, px_per_unit])

	var means: Array[float] = []
	var ratios: Array[float] = []
	for diff in DIFFICULTIES:
		var game := await _boot(diff)
		if game == null:
			continue
		var cfg_lo: int = int(game.get("num_specks_min"))
		var cfg_hi: int = int(game.get("num_specks_max"))
		var cfg_dirty: float = float(game.get("dirty_chance"))
		var s := await _sample(game, diff)
		print("-- %s (configured %d-%d specks, %.2f dirty) --" % [diff, cfg_lo, cfg_hi, cfg_dirty])

		# The knob is live only if what the scene PRODUCED sits inside what the
		# difficulty asked for. A hardcoded 5-12 fails this on Easy and on Hard.
		_check(int(s["count_lo"]) >= cfg_lo and int(s["count_hi"]) <= cfg_hi,
			"%s: speck count obeys num_specks_min/max" % diff,
			"produced %d-%d over %d dirty glasses" % [int(s["count_lo"]), int(s["count_hi"]), int(s["n_dirty"])])

		# 3-sigma on a binomial at n=SAMPLES. Wide enough never to flake, narrow
		# enough that 0.4, 0.5 and 0.6 are all outside each other's band.
		var tol: float = 3.0 * sqrt(cfg_dirty * (1.0 - cfg_dirty) / float(SAMPLES))
		_check(absf(float(s["dirty_ratio"]) - cfg_dirty) <= tol,
			"%s: dirty ratio obeys dirty_chance" % diff,
			"produced %.3f, configured %.2f, 3-sigma tolerance %.3f" % [float(s["dirty_ratio"]), cfg_dirty, tol])

		var speck_px: float = float(s["min_r"]) * 2.0 * float(s["scale"]) * px_per_unit
		_check(speck_px >= MIN_SPECK_DEVICE_PX,
			"%s: smallest speck still reads on an 854x480 screen" % diff,
			"radius %.2f units x scale %.2f -> %.2f device px (need %.1f)"
				% [float(s["min_r"]), float(s["scale"]), speck_px, MIN_SPECK_DEVICE_PX])

		var share: float = (205.0 * float(s["scale"])) / canvas_h
		_check(share >= MIN_GLASS_HEIGHT_SHARE,
			"%s: the glass is a subject, not an island" % diff,
			"%.1f%% of viewport height at scale %.2f (need %.0f%%)"
				% [share * 100.0, float(s["scale"]), MIN_GLASS_HEIGHT_SHARE * 100.0])

		# The scaled glass must not reach the CLEAN hint above (0.25 h) or the table
		# edge below (0.7 h); the glass is centred at 0.5 h.
		var half: float = 205.0 * float(s["scale"]) * 0.5
		_check(canvas_h * 0.5 - half > canvas_h * 0.25 + 30.0
			and canvas_h * 0.5 + half < canvas_h * 0.7,
			"%s: the scaled glass clears both hints and the table" % diff,
			"glass spans %.0f..%.0f of %.0f" % [canvas_h * 0.5 - half, canvas_h * 0.5 + half, canvas_h])

		means.append(float(s["count_mean"]))
		ratios.append(float(s["dirty_ratio"]))
		game.queue_free()
		await get_tree().process_frame

	print("-- the curve --")
	if means.size() == 3:
		# The author's design: Easy shows the most specks and the most dirty glasses,
		# Hard the fewest of both. Equal means are what a dead knob looks like.
		_check(means[0] > means[1] and means[1] > means[2],
			"speck count falls Easy > Medium > Hard",
			"means %.2f / %.2f / %.2f" % [means[0], means[1], means[2]])
		_check(ratios[0] > ratios[1] and ratios[1] > ratios[2],
			"dirty ratio falls Easy > Medium > Hard",
			"ratios %.3f / %.3f / %.3f" % [ratios[0], ratios[1], ratios[2]])
	else:
		_check(false, "all three difficulties booted", "%d of 3" % means.size())

	print("=== %d passed / %d failed ===" % [_pass, _fail])
	print("RESULT passed=%d failed=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
