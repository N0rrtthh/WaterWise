extends Node

## ── WATERWISE MOBILE-PATH SWEEP ────────────────────────────────────────────
##
## MobileUIManager exposes a gameplay-accommodation API — get_game_speed_multiplier
## (0.85), get_spawn_rate_multiplier (0.9), get_timing_window_multiplier (1.2),
## get_drag_smoothing_multiplier (1.5) and apply_game_object_scaling (1.4x). It is
## pull-only, and across 25 minigames exactly ONE pulls it: CatchTheRainV2. So the
## mobile path is a code path that almost nothing exercises and nothing has ever
## measured. This sweep measures it.
##
## What it asserts, and why each one is a real risk rather than a formality:
##
##   1. The mobile path is actually ON. Every check below is conditional on
##      is_mobile, so without this control the whole sweep passes VACUOUSLY on a
##      desktop run — which is the only kind of run this project ever does.
##   2. The drum's catch geometry matches the drum the player SEES.
##      apply_game_object_scaling multiplies drum_node.scale, but the catch test in
##      _process reads the constant DRUM_HALF_WIDTH. Scale one and not the other and
##      the drum lies about its own hitbox — on the target platform only.
##   3. The drum stays on screen. DRUM_MARGIN clamps the drum's POSITION, not its
##      scaled extent, so a scaled drum can be clamped to a spot it overflows.
##   4. The catch band still sits in the drum's visible mouth. CATCH_BAND_BOTTOM is
##      a constant offset from drum_node.position.y; the rim it is meant to line up
##      with moves when the node is scaled.
##   5. Supply still clears the quota on the mobile path. Dividing spawn_interval by
##      0.9 SPREADS the drops out while target_score is untouched — the same shape
##      as the GreywaterSorter Easy-on-tablet defect, so it gets the same check.
##   6. The thesis score term is not silently moved. reaction_time in
##      MiniGameBase is round ELAPSED time and T_max is the tier's time_limit
##      (20/15/10 s), neither of which the mobile path scales — so slowing the
##      drops lengthens T_r against a fixed T_max and pushes 1 - T_r/T_max DOWN.
##      An accommodation that lowers the mobile player's raw score S is working
##      against its own intent, and it feeds the adaptive engine.
##
## Run:  godot --headless --path . res://tools/VerifyMobilePath.tscn

const SCENE_STEM: String = "CatchTheRain"
const DIFFS: Array[String] = ["Easy", "Medium", "Hard"]

## Tier time limits from AdaptiveDifficulty.difficulty_settings, used as T_max for
## the score-term check. Read from the autoload at run time, not trusted from here.
var _t_max: Dictionary = {}

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []
## Desktop-path readings, keyed by difficulty, so the mobile numbers have something
## to be compared against instead of being reported in isolation.
var _desktop: Dictionary = {}


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE MOBILE-PATH SWEEP")
	print("═══════════════════════════════════════════════════════════")

	for d in DIFFS:
		_t_max[d] = float(AdaptiveDifficulty.DIFFICULTY_SETTINGS[d]["time_limit"])

	# ── desktop baseline first, while is_mobile is still false ──
	print("")
	print("  ── desktop path (is_mobile = %s) ──" % str(MobileUIManager.is_mobile))
	for d in DIFFS:
		await _measure(d, false)

	# ── flip to the mobile path ──
	MobileUIManager.debug_mobile_mode = true
	MobileUIManager._detect_platform()
	print("")
	print("  ── mobile path (is_mobile = %s) ──" % str(MobileUIManager.is_mobile))
	_check("the mobile path is actually enabled (control)",
		MobileUIManager.is_mobile_platform(),
		"is_mobile=%s — every check below would pass vacuously" % str(MobileUIManager.is_mobile))
	_check("the speed multiplier changed with it (control)",
		not is_equal_approx(MobileUIManager.get_game_speed_multiplier(), 1.0),
		"speed=%.3f spawn=%.3f" % [
			MobileUIManager.get_game_speed_multiplier(),
			MobileUIManager.get_spawn_rate_multiplier(),
		])

	for d in DIFFS:
		await _measure(d, true)

	await _report_small_viewport_reachability()
	_summarise()


## Boot the game once on the current platform path and read what it built.
func _measure(diff: String, mobile: bool) -> void:
	var game := await _boot(SCENE_STEM, diff)
	if game == null:
		return

	var consts: Dictionary = game.get_script().get_script_constant_map()
	var half_w: float = float(consts["DRUM_HALF_WIDTH"])
	var margin: float = float(consts["DRUM_MARGIN"])
	var band_bottom_off: float = float(consts["CATCH_BAND_BOTTOM"])

	var drum: Node2D = game.drum_node
	if drum == null:
		_check("%s: the drum was built" % diff, false, "drum_node is null")
		await _teardown(game)
		return

	var node_scale: float = drum.scale.x
	# The widest authored point of the drum body polygon is x = ±70 (the shoulders);
	# the rim is ±66. Scaling the parent scales both, so the visible half-width the
	# player aims at is 70 * scale.
	var visual_half_w: float = 70.0 * node_scale
	var fall: float = game.fall_time
	var spawn: float = game.spawn_interval
	var quota: int = game.target_score
	var dur: float = game.game_duration

	# Earliest possible completion: the first drop has to fall, then one spawn
	# interval per further catch. Analytic, and an upper bound on the player's
	# favour — a real player is slower, never faster.
	var earliest: float = fall + float(quota - 1) * spawn
	# Supply: drops that can still reach the catch line before the round ends.
	var supply: float = 1.0 + maxf(0.0, dur - fall) / maxf(spawn, 0.01)
	var speed_term: float = clampf(1.0 - earliest / _t_max[diff], 0.0, 1.0)

	print("    %s%s  scale %.2f  visual_half %.0fpx (catch %.0fpx)  fall %.2fs  spawn %.3fs  quota %d/%.0fs  supply %.1f  1-T/Tmax %.3f" % [
		diff, "  [mobile]" if mobile else " [desktop]",
		node_scale, visual_half_w, half_w, fall, spawn, quota, dur, supply, speed_term,
	])

	if not mobile:
		_desktop[diff] = {"fall": fall, "spawn": spawn, "speed_term": speed_term}
		# The desktop path is the reference, but it still has to be self-consistent:
		# an unscaled drum must agree with its own catch constant, or the constant is
		# simply wrong and the mobile finding below would be misattributed.
		_check("%s: the unscaled drum's visuals match its catch width" % diff,
			is_equal_approx(visual_half_w, half_w),
			"visual %.1fpx vs catch %.1fpx" % [visual_half_w, half_w])
		await _teardown(game)
		return

	# ── 2. the drum must not lie about its hitbox ──
	_check("%s: the scaled drum's visuals match its catch width" % diff,
		is_equal_approx(visual_half_w, half_w),
		"drum is drawn %.0fpx wide either side but catches only %.0fpx — %.0fpx of visible drum does not catch"
			% [visual_half_w, half_w, visual_half_w - half_w])

	# ── 3. the drum must stay on screen at its clamp limit ──
	_check("%s: the drum stays on screen at its clamp limit" % diff,
		visual_half_w <= margin + 0.5,
		"visual half-width %.0fpx exceeds DRUM_MARGIN %.0fpx — overflows by %.0fpx"
			% [visual_half_w, margin, visual_half_w - margin])

	# ── 4. the catch band must stay in the drum's visible mouth ──
	# The rim's authored top is y = -86; the band's bottom lip is CATCH_BAND_BOTTOM.
	# Scaling moves the rim and leaves the lip, so the two can part company.
	var rim_top: float = -86.0 * node_scale
	_check("%s: the catch band still meets the drum's rim" % diff,
		band_bottom_off > rim_top,
		"band lip at y=%.0f but the rim is drawn at y=%.0f — the band no longer lines up with the mouth"
			% [band_bottom_off, rim_top])

	# ── 5. supply must still clear the quota ──
	_check("%s: supply still clears the quota on the mobile path" % diff,
		supply >= float(quota) * 1.25,
		"%.1f drops available for a quota of %d" % [supply, quota])

	# ── 6. the accommodation must not lower the thesis score term ──
	var dk: Dictionary = _desktop.get(diff, {})
	if dk.is_empty():
		_check("%s: a desktop baseline was captured to compare against" % diff, false)
	else:
		var d_term: float = float(dk["speed_term"])
		_check("%s: the mobile path does not lower the thesis speed term" % diff,
			speed_term >= d_term - 0.001,
			"1-T_r/T_max falls %.3f → %.3f (T_max %.0fs unchanged, earliest completion %.2fs → %.2fs)"
				% [d_term, speed_term, _t_max[diff],
					float(dk["fall"]) + float(game.target_score - 1) * float(dk["spawn"]), earliest])

	await _teardown(game)


## _detect_platform treats a viewport narrower than 800 px as a mobile device. Under
## project.godot's stretch mode "canvas_items" with aspect "expand" the visible rect
## is the 1920-wide base grown to fit, never shrunk below it, so that branch cannot
## fire however small the WINDOW gets. Reported rather than asserted: it is not a
## gameplay defect (is_mobile_os covers real Android), it is the reason nobody can
## exercise the mobile path on a desktop without debug_mobile_mode.
func _report_small_viewport_reachability() -> void:
	print("")
	print("  ── small-viewport detection ──")
	MobileUIManager.debug_mobile_mode = false
	DisplayServer.window_set_size(Vector2i(480, 320))
	get_window().size = Vector2i(480, 320)
	for _i in range(6):
		await get_tree().process_frame

	var win := DisplayServer.window_get_size()
	var vp := get_viewport().get_visible_rect().size
	MobileUIManager._detect_platform()
	print("    window %dx%d  →  visible rect %.0fx%.0f  →  is_mobile %s" % [
		win.x, win.y, vp.x, vp.y, str(MobileUIManager.is_mobile),
	])
	print("    'viewport_width < 800' is unreachable under aspect=expand: the visible")
	print("    rect is the %d-wide base grown to fit, so it never drops below it." % int(
		ProjectSettings.get_setting("display/window/size/viewport_width")))


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
		print("      ✓ %s" % label)
	else:
		_failed += 1
		var msg := label if detail == "" else "%s — %s" % [label, detail]
		_failures.append(msg)
		print("      ✗ %s  %s" % [label, detail])


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
