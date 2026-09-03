extends Node

## Is the gauge in QuickShower an instrument the player can actually read, and does the bar
## the player SEES still mean exactly what _check_timing() CHECKS?
##
## The bar was authored at a fixed 300x40 with a fixed 60-wide green zone and a fixed
## 10-wide indicator, while everything around it (shower head, drop column, score readout)
## is screen-relative. On the 1920x1080 canvas the project ships that is 15.6% of the width;
## on the 854x480 profile in tools/AuditMobileUI.gd DEVICES, where 1 canvas unit is
## 854/1920 = 0.445 device px, the indicator is 4.4 device px and the green zone 27.
##
## The gauge is now DRAWN scaled and still COMPUTED in its authored 0..290 logical space,
## because those numbers are the difficulty: gauge_speed is 60/100/150 units per second
## against a 60-wide zone, so the window is 1.00 / 0.60 / 0.40 s. The whole risk of that
## kind of fix is the two spaces drifting apart - a green zone drawn somewhere the code does
## not accept, which reads to a player as an unresponsive game. So the central claim here is
## agreement: for every position along the sweep, "the indicator looks like it is in the
## green" and "_check_timing() would score it" must give the same answer.
##
## Everything is measured off the real booted scene. Difficulty is forced the way the
## algorithm forces it (tools/VerifyDifficultyInit.gd), never stubbed.

const GAME_PATH := "res://scenes/minigames/QuickShower.tscn"
const DIFFICULTIES: PackedStringArray = ["Easy", "Medium", "Hard"]

## Authored logical sweep space. _process() bounces gauge_position between these and
## _start_shower() places a 60-wide zone from randf_range(50, 200) inside it.
const SWEEP_MAX: float = 290.0
const ZONE_W: float = 60.0

## Lowest device profile in tools/AuditMobileUI.gd DEVICES: 854x480 on a 1920-unit canvas.
const LOW_END_W: float = 854.0
const CANVAS_W: float = 1920.0

## The indicator is the thing the player tracks with their eye and times a tap against; it
## needs to read as a distinct line, not a shimmer. Same 6 device px threshold that
## tools/VerifySpeckDifficulty.gd argues for the specks.
const MIN_INDICATOR_PX: float = 6.0
## The target has to look like a target from arm's length.
const MIN_ZONE_PX: float = 20.0
## Below this the bar is an ornament rather than the instrument the game is about.
const MIN_BAR_WIDTH_SHARE: float = 0.35

## Expected green-zone crossing time per difficulty, in seconds: ZONE_W / gauge_speed.
## These are the numbers the fix must NOT move.
const EXPECTED_WINDOW: Dictionary = {"Easy": 1.0, "Medium": 0.6, "Hard": 0.4}

## Half-width of the indeterminate band around a zone edge, in logical units. 0.0017 device
## px on the low-end profile, which is not a thing a finger can express.
const EDGE_DEADBAND: float = 0.05

var _pass: int = 0
var _fail: int = 0

func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [ok]   %s%s" % [label, "" if detail.is_empty() else "  " + detail])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [label, "" if detail.is_empty() else "  " + detail])

func _ready() -> void:
	# The headless DisplayServer opens a square-ish window, which is not an aspect any device
	# in DEVICES has, and the gauge scale is resolved from viewport WIDTH. Measure at the
	# canvas project.godot declares so these numbers are the ones a player gets.
	var want := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 1080)))
	get_window().size = want
	await get_tree().process_frame
	await get_tree().process_frame
	var px_per_unit: float = LOW_END_W / CANVAS_W
	print("\n=== VerifyQuickShowerGauge ===")
	print("  viewport %dx%d; low-end profile %d px wide -> %.3f device px per canvas unit"
		% [want.x, want.y, int(LOW_END_W), px_per_unit])
	for diff in DIFFICULTIES:
		await _one(diff)
	print("=== %d passed / %d failed ===" % [_pass, _fail])
	print("RESULT passed=%d failed=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

## Boots the real scene at a forced difficulty, exactly the way the algorithm sets it.
func _boot(diff: String) -> Node:
	AdaptiveDifficulty.current_difficulty = diff
	AdaptiveDifficulty.progressive_level = 0
	var packed: PackedScene = load(GAME_PATH)
	if packed == null:
		_check(false, "%s: scene loads" % diff)
		return null
	var game := packed.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game

## Measures one difficulty end to end.
func _one(diff: String) -> void:
	var game := await _boot(diff)
	if game == null:
		return
	game.call("start_game")
	await get_tree().process_frame
	var bar := game.get_node_or_null("GaugeBG") as ColorRect
	var zone := game.get_node_or_null("GaugeBG/GreenZone") as ColorRect
	var pip := game.get_node_or_null("GaugeBG/Indicator") as ColorRect
	if bar == null or zone == null or pip == null:
		_check(false, "%s: gauge rig is present" % diff, "bar/zone/indicator lookup failed")
		game.queue_free()
		return
	var view: Vector2 = game.get_viewport_rect().size
	var sx: float = bar.scale.x
	var px: float = LOW_END_W / CANVAS_W
	var bar_w: float = bar.size.x * sx
	var bar_h: float = bar.size.y * bar.scale.y
	var left: float = bar.global_position.x
	var top: float = bar.global_position.y
	var speed: float = float(game.get("gauge_speed"))
	var label: String = diff

	# --- the bar is an instrument, not an ornament ---
	_check(bar_w / view.x >= MIN_BAR_WIDTH_SHARE, "%s: gauge is a readable instrument" % label,
		"%.0f units = %.1f%% of viewport width at scale %.2f (need %.0f%%)"
		% [bar_w, 100.0 * bar_w / view.x, sx, 100.0 * MIN_BAR_WIDTH_SHARE])
	_check(pip.size.x * sx * px >= MIN_INDICATOR_PX, "%s: indicator reads on an 854x480 screen" % label,
		"%.1f units wide -> %.2f device px (need %.1f)" % [pip.size.x * sx, pip.size.x * sx * px, MIN_INDICATOR_PX])
	_check(zone.size.x * sx * px >= MIN_ZONE_PX, "%s: green zone reads on an 854x480 screen" % label,
		"%.1f units wide -> %.2f device px (need %.1f)" % [zone.size.x * sx, zone.size.x * sx * px, MIN_ZONE_PX])
	_check(left >= 0.0 and left + bar_w <= view.x + 0.5 and top + bar_h <= view.y,
		"%s: scaled gauge stays fully on screen" % label,
		"spans x %.0f..%.0f of %.0f, y %.0f..%.0f of %.0f" % [left, left + bar_w, view.x, top, top + bar_h, view.y])
	_check(absf((left + bar_w * 0.5) - view.x * 0.5) <= 1.0, "%s: scaled gauge stays centred" % label,
		"centre %.1f vs screen centre %.1f" % [left + bar_w * 0.5, view.x * 0.5])

	# --- the difficulty did not move ---
	var window: float = ZONE_W / speed
	var want_window: float = float(EXPECTED_WINDOW[diff])
	_check(absf(window - want_window) <= 0.001, "%s: green-zone window is unchanged" % label,
		"%.0f logical units / %.0f units per second = %.3f s (authored %.2f)" % [ZONE_W, speed, window, want_window])

	# --- what the player sees is what the code checks ---
	# The zone is placed by randf_range(50, 200) each shower, so sample many placements and,
	# for each, walk the whole sweep comparing the two spaces. A single scale applied to the
	# wrong node, or a zone offset multiplied twice, shows up here as a mismatch.
	var mismatch: int = 0
	var worst: float = 0.0
	var skipped: int = 0
	var zone_overflow: int = 0
	var samples: int = 0
	for shower in range(40):
		game.call("_start_shower")
		var zs: float = float(game.get("target_zone_start"))
		var ze: float = float(game.get("target_zone_end"))
		if ze > SWEEP_MAX:
			zone_overflow += 1
		var zl: float = left + zone.position.x * sx
		var zr: float = zl + zone.size.x * sx
		for step in range(0, 291, 5):
			var p: float = float(step)
			game.set("gauge_position", p)
			pip.position.x = p
			# A sample sitting on the edge of the band cannot be classified: the two spaces
			# reach it through different float chains (a direct compare against zs/ze here, a
			# transform multiply by the scale there), so they can disagree by an ULP. Skip the
			# edge and say how many were skipped. The drift this test exists to catch is a
			# whole scale factor - tens of units - not a millionth of one.
			if absf(p - zs) <= EDGE_DEADBAND or absf(p - ze) <= EDGE_DEADBAND:
				skipped += 1
				continue
			var code_good: bool = p >= zs and p <= ze
			var seen_x: float = pip.global_position.x
			var seen_good: bool = seen_x >= zl and seen_x <= zr
			samples += 1
			if code_good != seen_good:
				mismatch += 1
				worst = maxf(worst, minf(absf(seen_x - zl), absf(seen_x - zr)) / sx)
	_check(mismatch == 0, "%s: the green the player sees is the green the code scores" % label,
		"%d disagreements over %d samples across 40 zone placements (%d edge samples skipped)%s"
		% [mismatch, samples, skipped, "" if mismatch == 0 else ", worst %.3f logical units off" % worst])
	_check(zone_overflow == 0, "%s: the zone is always reachable inside the sweep" % label,
		"%d of 40 placements ran past %.0f" % [zone_overflow, SWEEP_MAX])

	# --- the sweep still bounces in the authored space ---
	# Driven by the scene's own _process, not by the harness stepping the number, so the
	# bounce bounds and the speed are the real ones.
	game.call("_start_shower")
	pip.position.x = 0.0
	Engine.time_scale = 4.0
	var lo: float = 1e9
	var hi: float = -1e9
	var flips: int = 0
	var dir: int = int(game.get("gauge_direction"))
	var t0: float = Time.get_ticks_msec() / 1000.0
	while flips < 2 and Time.get_ticks_msec() / 1000.0 - t0 < 20.0:
		await get_tree().process_frame
		if not bool(game.get("game_active")) or not bool(game.get("shower_running")):
			break
		var p: float = float(game.get("gauge_position"))
		lo = minf(lo, p)
		hi = maxf(hi, p)
		var d: int = int(game.get("gauge_direction"))
		if d != dir:
			flips += 1
			dir = d
	Engine.time_scale = 1.0
	_check(flips >= 2 and hi >= SWEEP_MAX - 6.0 and hi <= SWEEP_MAX + 6.0 and lo <= 6.0,
		"%s: sweep still bounces across the authored 0..%.0f space" % [label, SWEEP_MAX],
		"reached %.1f..%.1f over %d direction flips at %.0f units per second" % [lo, hi, flips, speed])

	# --- and a tap is still judged by that space ---
	var before: int = int(game.get("showers_taken"))
	game.call("_start_shower")
	var mid: float = (float(game.get("target_zone_start")) + float(game.get("target_zone_end"))) * 0.5
	game.set("gauge_position", mid)
	game.call("_check_timing")
	await get_tree().process_frame
	var scored: int = int(game.get("showers_taken"))
	_check(scored == before + 1, "%s: a tap inside the zone still scores" % label,
		"gauge at %.1f in %.1f..%.1f -> showers %d to %d"
		% [mid, float(game.get("target_zone_start")), float(game.get("target_zone_end")), before, scored])
	game.call("_start_shower")
	var out: float = fmod(float(game.get("target_zone_end")) + 20.0, SWEEP_MAX)
	game.set("gauge_position", out)
	game.call("_check_timing")
	await get_tree().process_frame
	_check(int(game.get("showers_taken")) == scored, "%s: a tap outside the zone still misses" % label,
		"gauge at %.1f -> showers stayed %d" % [out, int(game.get("showers_taken"))])
	game.queue_free()
	await get_tree().process_frame
