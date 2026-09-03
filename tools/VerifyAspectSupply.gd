extends Node

## ═══════════════════════════════════════════════════════════════════
## ASPECT-RATIO SUPPLY HARNESS (headless, thesis-auditable)
## ═══════════════════════════════════════════════════════════════════
## CatchTheRain had a defect that no unit check could see: it authored its fall
## as px/s, so the time a drop took to become catchable was (screen height) /
## (speed), and on a tall viewport half the round was dead air. AutoPlay's
## omniscient driver lost every Medium round 7-of-8 with zero mistakes — the
## SUPPLY, not the aim, was the ceiling. The fix derives speed from an authored
## fall_time; VerifyShellV2 pins that.
##
## This harness asks the follow-up question: do the other three shell games share
## the same FORM of dependence, and if so does the real device range break them?
##
##   * GreywaterSorterV2 authors bucket_speed in px/s (150/220/320) and buckets
##     fall the whole height, so dwell time is screen-dependent.
##   * BucketBrigadeV2 authors BUCKET_SPEED = 700 px/s and the people row spans
##     0.18…0.82 of the WIDTH, so pipeline latency is screen-dependent.
##   * FixLeakV2 has no px/s quantity at all (drip_speed is a multiplier and
##     _find_slot is bounded to 20 attempts), so it is not swept here.
##
## The device range is not arbitrary. project.godot declares a 1920x1080 base
## with stretch mode "canvas_items" and aspect "expand", locked to
## sensor_landscape. Under expand the content scale is min(win.x/1920, win.y/1080)
## and the visible rect grows in whichever axis has room, so on real landscape
## Android the height spans 1080 (16:9 and taller phones) up to 1440 (4:3 tablet)
## and the width spans 1920 up to 2560 (21:9). Those three corners are what this
## sweeps — NOT the 1920x1920 the headless driver reports by default, which is a
## display-driver artifact with no device behind it.
##
## Supply is compared against quota x SUPPLY_MARGIN rather than against the quota
## itself: a round that is exactly clearable by a perfect player is not clearable
## by a child on a phone, and the thesis's difficulty is meant to come from the
## tiers, not from the panel the game happens to be running on.
##
## Run:
##   Godot --headless --path <project> res://tools/VerifyAspectSupply.tscn
## Exit code 0 = all passed, 1 = at least one failure.
##
## If the forced sizes do not take effect (some display drivers ignore
## window_set_size), every measurement would be taken at one size and every
## check would pass VACUOUSLY. The sweep therefore asserts up front that the
## visible rect actually differs across the three corners and refuses to report
## any pass if it does not.
## ═══════════════════════════════════════════════════════════════════

const DIFFICULTIES: PackedStringArray = ["Easy", "Medium", "Hard"]

## The three corners of the real landscape-Android range. See the header for why
## these and not the headless default.
const ASPECTS: Array = [
	{"name": "16:9  1920x1080 (design base)", "size": Vector2i(1920, 1080)},
	{"name": "21:9  2560x1080 (tall phone)",  "size": Vector2i(2560, 1080)},
	{"name": "4:3   1920x1440 (tablet)",      "size": Vector2i(1920, 1440)},
]

## Headroom a round must leave above its quota. 1.5 is the figure VerifyShellV2
## already holds CatchTheRain to; reusing it keeps the two harnesses comparable.
const SUPPLY_MARGIN: float = 1.5

## Headroom the DEGRADED path must leave. Lower than SUPPLY_MARGIN because a
## board left to fill is not the normal way to play — but not 1.0 either: at
## exactly 1.0 the Easy tier passed by 1.07x on the design base while being
## unwinnable on a tablet, so a bare >= quota check is what hid the defect.
const CLOG_MARGIN: float = 1.25

## Mirrors CatchTheRainV2's SPAWN_Y / CATCH_BAND_BOTTOM and the 0.72 good-drop
## rate in its _spawn_drop(). A const on the game class cannot be read through an
## instance, so the values are restated here.
const RAIN_SPAWN_Y: float = -30.0
const RAIN_BAND_BOTTOM: float = -55.0
const RAIN_GOOD_DROP_RATE: float = 0.72

## Mirrors GreywaterSorterV2: buckets are born at y = -90 and released past
## vp.y + 90, and a bucket is only tappable once it is on screen.
const SORTER_SPAWN_Y: float = -90.0
const SORTER_KILL_PAD: float = 90.0

## Mirrors BucketBrigadeV2: source at x = 84, garden at x = W - 84, BUCKET_SPEED.
const BRIGADE_END_INSET: float = 84.0
const BRIGADE_SPEED: float = 700.0

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []
var _seen_sizes: Array[Vector2] = []


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE ASPECT-RATIO SUPPLY SWEEP")
	print("═══════════════════════════════════════════════════════════")
	print("  base %sx%s  stretch=%s  aspect=%s  orientation=%s" % [
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"),
		ProjectSettings.get_setting("display/window/stretch/mode"),
		ProjectSettings.get_setting("display/window/stretch/aspect"),
		ProjectSettings.get_setting("display/window/handheld/orientation"),
	])

	for aspect in ASPECTS:
		var vp := await _force_size(aspect["size"])
		print("")
		print("── %s → visible rect %.0fx%.0f ──" % [aspect["name"], vp.x, vp.y])
		_seen_sizes.append(vp)
		for diff in DIFFICULTIES:
			await _measure_rain(diff, vp)
			await _measure_sorter(diff, vp)
			await _measure_brigade(diff, vp)

	_report_sweep_was_real()
	_summarise()


## Resize the window and let the content-scale machinery settle, then report what
## the games will actually read from get_viewport_rect(). Two frames is not
## enough on every driver, so six — the same settle count _boot() uses.
func _force_size(size: Vector2i) -> Vector2:
	DisplayServer.window_set_size(size)
	get_window().size = size
	for _i in range(6):
		await get_tree().process_frame
	return get_viewport().get_visible_rect().size


## The guard that stops this whole file from being decorative. If the driver
## ignored the resizes, every game was measured at one size and every margin
## check passed for a reason that has nothing to do with aspect ratio.
func _report_sweep_was_real() -> void:
	var distinct: Array[Vector2] = []
	for s in _seen_sizes:
		if not distinct.has(s):
			distinct.append(s)
	print("")
	print("── was the sweep real? ──")
	print("    distinct visible rects observed: %d of %d requested  %s"
		% [distinct.size(), ASPECTS.size(), str(_seen_sizes)])
	_check("the forced sizes actually reached the viewport",
		distinct.size() == ASPECTS.size(),
		"only %d distinct rect(s) — the driver ignored window_set_size, so every"
			% distinct.size()
			+ " margin above was measured at one size and proves nothing")


# ── per-game supply models ──────────────────────────────────────────────────

## CatchTheRain: speed is derived from fall_time in _shell_start(), so the fall
## should measure the authored seconds at EVERY aspect. This is the control for
## the whole sweep — the one game already fixed.
func _measure_rain(diff: String, vp: Vector2) -> void:
	var g: Node = await _boot("CatchTheRain", diff)
	if g == null:
		return
	g.call("_shell_start")
	var band_bottom: float = g.drum_node.position.y + RAIN_BAND_BOTTOM
	var speed: float = float(g.drop_speed)
	var fall: float = (band_bottom - RAIN_SPAWN_Y) / speed
	var dur: float = float(g.game_duration)
	var quota: int = int(g.target_score)
	var good: float = maxf(dur - fall, 0.0) / float(g.spawn_interval) * RAIN_GOOD_DROP_RATE

	print("    CatchTheRain     %-6s fall %.2fs (authored %.2f)  %.1f good drops / quota %d"
		% [diff, fall, float(g.fall_time), good, quota])
	_check("rain fall is the authored time, not a function of height (%s @ %.0fx%.0f)"
			% [diff, vp.x, vp.y],
		absf(fall - float(g.fall_time)) < 0.02,
		"measured %.3fs, authored %.3fs" % [fall, float(g.fall_time)])
	_check("rain quota is reachable with margin (%s @ %.0fx%.0f)" % [diff, vp.x, vp.y],
		good >= float(quota) * SUPPLY_MARGIN,
		"%.1f good drops for a quota of %d" % [good, quota])
	await _teardown(g)


## GreywaterSorter: bucket_speed IS authored in px/s, so both quantities below
## move with height. Two ceilings are reported because the game has two gates:
##   * spawn_interval — the rate for a player who sorts promptly, height-free;
##   * max_on_screen / dwell — the rate once buckets are left to fall, and dwell
##     is (vp.y + 180) / bucket_speed, so THIS one stretches with the screen. A
##     blocked spawn also still resets spawn_timer, so a clog costs a whole
##     interval rather than resuming the moment a slot frees.
## The quota is only in danger if the clogged ceiling falls under it, so both are
## checked and the clogged one is the interesting number.
func _measure_sorter(diff: String, vp: Vector2) -> void:
	var g: Node = await _boot("GreywaterSorter", diff)
	if g == null:
		return
	g.call("_shell_start")
	var speed: float = float(g.bucket_speed)
	var lead_in: float = absf(SORTER_SPAWN_Y) / speed
	var dwell: float = (vp.y + absf(SORTER_SPAWN_Y) + SORTER_KILL_PAD) / speed
	var dur: float = float(g.game_duration)
	var quota: int = int(g.target_sort)
	var prompt: float = maxf(dur - lead_in, 0.0) / float(g.spawn_interval)
	var clogged: float = dur * (float(g.max_on_screen) / dwell)

	print("    GreywaterSorter  %-6s dwell %.2fs  prompt %.1f / clogged %.1f buckets / quota %d"
		% [diff, dwell, prompt, clogged, quota])
	_check("sorter quota is reachable when buckets are sorted promptly (%s @ %.0fx%.0f)"
			% [diff, vp.x, vp.y],
		prompt >= float(quota) * SUPPLY_MARGIN,
		"%.1f buckets for a quota of %d" % [prompt, quota])
	_check("sorter quota survives a full screen of un-sorted buckets (%s @ %.0fx%.0f)"
			% [diff, vp.x, vp.y],
		clogged >= float(quota) * CLOG_MARGIN,
		"dwell %.2fs x %d slots yields only %.1f buckets in %.0fs for a quota of %d"
			% [dwell, int(g.max_on_screen), clogged, dur, quota])
	_check("a bucket is tappable well before it is lost (%s @ %.0fx%.0f)"
			% [diff, vp.x, vp.y],
		dwell - lead_in >= 1.0,
		"only %.2fs on screen" % (dwell - lead_in))
	await _teardown(g)


## BucketBrigade: BUCKET_SPEED is px/s and the whole relay spans the WIDTH
## (source at x=84, garden at x=W-84), so pipeline latency is a function of the
## wide axis rather than the tall one. Deliveries are gated at the head of the
## line — a new bucket only spawns when person 0 is free — so the ceiling is
## (duration - one full traverse) / spawn_interval.
func _measure_brigade(diff: String, vp: Vector2) -> void:
	var g: Node = await _boot("BucketBrigade", diff)
	if g == null:
		return
	var path: float = vp.x - BRIGADE_END_INSET * 2.0
	var latency: float = path / BRIGADE_SPEED
	var dur: float = float(g.game_duration)
	var quota: int = int(g.target_buckets)
	var deliveries: float = maxf(dur - latency, 0.0) / float(g.spawn_interval)

	print("    BucketBrigade    %-6s traverse %.2fs  %.1f deliveries / quota %d"
		% [diff, latency, deliveries, quota])
	_check("brigade quota is reachable with margin (%s @ %.0fx%.0f)" % [diff, vp.x, vp.y],
		deliveries >= float(quota) * SUPPLY_MARGIN,
		"%.1f deliveries for a quota of %d" % [deliveries, quota])
	_check("one traverse is a small fraction of the round (%s @ %.0fx%.0f)"
			% [diff, vp.x, vp.y],
		latency <= dur * 0.25,
		"traverse %.2fs of a %.0fs round — the pipeline fill dominates" % [latency, dur])
	await _teardown(g)


# ── scaffolding (same contract as VerifyShellV2) ────────────────────────────

## Boot a shell minigame with `diff` forced. Stops while the instruction overlay
## is still up: the board exists, the verb flash has not run, no round is live.
func _boot(stem: String, diff: String) -> Node:
	if AdaptiveDifficulty:
		AdaptiveDifficulty.current_difficulty = diff
		AdaptiveDifficulty.progressive_level = 0

	var scene := load("res://scenes/minigames/%s.tscn" % stem) as PackedScene
	if scene == null:
		_check("%s.tscn loads" % stem, false, "load() returned null")
		return null

	var game: Node = scene.instantiate()
	add_child(game)
	for _i in range(6):
		await get_tree().process_frame
	return game


func _teardown(game: Node) -> void:
	if game and is_instance_valid(game):
		game.queue_free()
	await get_tree().process_frame


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		var msg := label if detail == "" else "%s — %s" % [label, detail]
		_failures.append(msg)
		print("    ✗ %s  %s" % [label, detail])


func _summarise() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		print("")
		for f in _failures:
			print("  ✗ %s" % f)
	print("═══════════════════════════════════════════════════════════")
	get_tree().quit(1 if _failed > 0 else 0)
