extends Node

## Does the Fix-the-Leak water-waste economy exist, or is it decoration?
##
## WHICH SCRIPT IS UNDER TEST
##   FixLeak.tscn runs res://scripts/minigames_v2/FixLeakV2.gd (MicrogameShell ->
##   MiniGameBase), NOT scenes/minigames/FixLeak.gd. That second file is an orphan
##   left over from the v2 rebuild -- nothing loads it, exactly like the
##   CatchTheRain.gd the repo already deleted -- so an edit there changes nothing
##   that runs. This harness instantiates the SCENE for that reason.
##
## WHAT WAS THERE
##   A fail condition (water_wasted > max_water_wasted) and a red "pressure"
##   polygon that rises up the wall to show it. The accumulation was
##   `water_wasted += delta * drip_speed * 0.1 * unfixed` against a threshold of
##   `55 + num_leaks * 15`: at Easy, 85 units at 0.16/s = 531 seconds, inside a
##   25-second round. Every tier is off by an order of magnitude, so the waste fail
##   path was unreachable and the readout climbed ~4% in a whole round. The one
##   thing the game exists to teach -- an unfixed leak keeps costing you -- had no
##   consequence and no visible slope.
##
##   The drip did not drip either: position.y = 16 + sin(t*9)*6 (a 12px bob) with
##   alpha on a SECOND sine of period 12 carrying no per-leak offset, both driven
##   off Time.get_ticks_msec(), so every leak blinked in unison, none of them fell,
##   and the phase jumped whenever the game had been paused.
##
## WHAT IS ASSERTED
##   [1] leaving every leak unfixed fills the bar INSIDE the round, at each tier,
##       without filling so fast the round is unplayable
##   [2] the readout climbs while leaks drip
##   [3] the drip travels, restarts at the crack, and stretches as it falls
##   [4] separate leaks are out of phase
##   [5] fixing leaks reduces the measured waste rate
##   [6] idling ends the round on the water, before the clock
##   [7] MudPieMaker: holding the green zone scores and feeds the difficulty window
##   [8] and outside the band nothing accrues
##
## Usage:
##   godot --headless --path <project> res://tools/VerifyLeakWaste.tscn

const FIX_LEAK: String = "res://scenes/minigames/FixLeak.tscn"
const TIERS: Array = ["Easy", "Medium", "Hard"]

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
		await get_tree().process_frame


func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


## Measured units of water wasted per real second. Uses the wall clock, not a frame
## count: headless does not run at 60fps.
func _waste_rate(game: Node, seconds: float) -> float:
	var t0 := Time.get_ticks_msec()
	var w0: float = float(game.water_wasted)
	await _wait_real(seconds)
	var dt: float = float(Time.get_ticks_msec() - t0) / 1000.0
	if dt <= 0.0:
		return 0.0
	return (float(game.water_wasted) - w0) / dt


func _live_round(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await _frames(30)
	for _attempt in range(120):
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = get_tree().root.get_visible_rect().size * 0.5
		Input.parse_input_event(down)
		await get_tree().process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = down.position
		Input.parse_input_event(up)
		await get_tree().process_frame
		if inst.get("game_active") == true:
			break
	return inst


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════")
	print("  FIX LEAK WASTE ECONOMY + MUD PIE ZONE SCORING")
	print("═══════════════════════════════════════════════════════")

	await _tier_table()
	await _live_checks()
	await _mud_pie_checks()

	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## The threshold and the clock, per tier, from the difficulty table the game runs.
##
## Forcing a tier takes BOTH halves: current_difficulty drives the game's own "Hard"
## branch, but every number it reads comes out of difficulty_settings, which
## _load_difficulty_settings() filled once at _ready() from whatever tier was live
## then. Setting only current_difficulty (this harness's first pass) left the Easy
## settings in place and printed one identical row per tier.
func _tier_table() -> void:
	print("")
	print("── [1] is the threshold reachable inside the round? ──")
	var scene := load(FIX_LEAK) as PackedScene
	var game: Node = scene.instantiate()
	add_child(game)
	await _frames(2)

	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	for tier in TIERS:
		if ad:
			ad.current_difficulty = tier
			ad.progressive_level = 0
			game.difficulty_settings = ad.get_difficulty_settings()
		game.current_difficulty = tier
		game._apply_difficulty_settings()
		var leaks: int = int(game.num_leaks)
		var thresh: float = float(game.max_water_wasted)
		var round_len: float = float(game.game_duration)
		# Read the rate out of the game rather than re-deriving it here, so a later
		# change to the formula is picked up instead of silently diverging.
		var rate: float = 0.0
		if "waste_per_leak" in game:
			rate = float(leaks) * float(game.waste_per_leak)
		else:
			_check("%s: the game exposes waste_per_leak" % tier, false,
				"field missing -- falling back to the legacy drip_speed * 0.1 model")
			rate = float(leaks) * float(game.drip_speed) * 0.1
		var to_fail: float = (thresh / rate) if rate > 0.0 else INF
		var detail: String = "%d leaks, threshold %.0f, rate %.3f/s -> fills at %.1fs of a %.0fs round"
		_check("%s: idling fills the waste bar before the clock runs out" % tier,
			to_fail < round_len,
			detail % [leaks, thresh, rate, to_fail, round_len])
		# A bar that fills the instant the round starts is as broken as one that never
		# fills: the player has to have time to work.
		_check("%s: but not so fast the round is unplayable" % tier,
			to_fail > round_len * 0.4,
			"fills at %.0f%% of the round" % [100.0 * to_fail / maxf(round_len, 0.001)])

	game.queue_free()
	await _frames(2)


## The live leaks: V2 pools LEAK_POOL_SIZE nodes and shows num_leaks of them, so
## `leaks` always holds 5 entries and `visible` says who is in this round.
func _active_leaks(game: Node) -> Array:
	var out: Array = []
	for leak in game.leaks:
		if leak != null and leak.visible and not leak.get_meta("fixed", false):
			out.append(leak)
	return out


func _live_checks() -> void:
	print("")
	print("── a live round with nobody fixing anything ──")
	var game: Node = await _live_round(FIX_LEAK)
	if game.get("game_active") != true:
		_check("the round started", false, "game_active never became true")
		return

	var leaks: Array = _active_leaks(game)
	_check("leaks spawned", leaks.size() >= 2, "%d active leak(s)" % leaks.size())
	if leaks.size() < 2:
		return

	# [3] the drip falls: sample one drip's y and stretch across several drops.
	var drip: ColorRect = leaks[0].get_node("Drip") as ColorRect
	var lo: float = 1e9
	var hi: float = -1e9
	var sy_lo: float = 1e9
	var sy_hi: float = -1e9
	var last: float = drip.position.y
	var reset_seen: bool = false
	var until := Time.get_ticks_msec() + 1600
	while Time.get_ticks_msec() < until:
		var y: float = drip.position.y
		if y < last - 4.0:
			reset_seen = true
		lo = minf(lo, y)
		hi = maxf(hi, y)
		sy_lo = minf(sy_lo, drip.scale.y)
		sy_hi = maxf(sy_hi, drip.scale.y)
		last = y
		await get_tree().process_frame
	_check("[3] the drip travels a readable distance", (hi - lo) > 20.0,
		"drip.position.y ranged %.1f .. %.1f (travel %.1f px)" % [lo, hi, hi - lo])
	_check("[3b] and starts over at the crack instead of easing back up", reset_seen,
		"snap-back to the spout seen: %s" % str(reset_seen))
	_check("[3c] and stretches as it accelerates", (sy_hi - sy_lo) > 0.2,
		"scale.y ranged %.2f .. %.2f" % [sy_lo, sy_hi])

	# [4] leaks are not in lockstep.
	var d2: ColorRect = leaks[1].get_node("Drip") as ColorRect
	var spread: float = absf(drip.position.y - d2.position.y)
	var alpha_spread: float = absf(drip.modulate.a - d2.modulate.a)
	_check("[4] two leaks are out of phase", spread > 2.0 or alpha_spread > 0.05,
		"y gap %.1f px, alpha gap %.2f" % [spread, alpha_spread])

	# [2] the readout moves. V2 shows waste as a red polygon rising up the wall, so
	# the assertion is on the thing the player actually sees.
	var fill_before: float = float(game.waste_fill.scale.y)
	await _wait_real(1.5)
	var fill_after: float = float(game.waste_fill.scale.y)
	var rise: float = fill_after - fill_before
	_check("[2] the waste readout climbs while leaks drip", rise > 0.01,
		"fill %.4f -> %.4f in 1.5s (+%.1f%% of the wall)" % [
			fill_before, fill_after, rise * 100.0])

	# [5] fixing leaks slows the bleed.
	var rate_all: float = await _waste_rate(game, 1.2)
	var active: Array = _active_leaks(game)
	for i in range(active.size() - 1):
		game._on_leak_clicked(active[i])
	await _frames(2)
	var rate_one: float = await _waste_rate(game, 1.2)
	_check("[5] fixing leaks reduces the waste rate", rate_one < rate_all * 0.9,
		"%.3f/s with %d leaking -> %.3f/s with 1 leaking"
			 % [rate_all, active.size(), rate_one])

	game.queue_free()
	await _frames(2)

	# [6] a player who does nothing loses to the water, not to the clock.
	print("")
	print("── [6] idling to the threshold ──")
	var g2: Node = await _live_round(FIX_LEAK)
	if g2.get("game_active") != true:
		_check("[6] the second round started", false, "game_active never became true")
		return
	var thresh: float = float(g2.max_water_wasted)
	var round_len: float = float(g2.game_duration)
	var t0 := Time.get_ticks_msec()
	var deadline := t0 + int(round_len * 1000.0) + 1500
	while Time.get_ticks_msec() < deadline and g2.get("game_active") == true:
		await get_tree().process_frame
	var elapsed: float = float(Time.get_ticks_msec() - t0) / 1000.0
	var wasted: float = float(g2.water_wasted)
	_check("[6] idling reaches the waste threshold", wasted >= thresh,
		"wasted %.1f of %.0f by the time the round closed" % [wasted, thresh])
	_check("[6b] and the water ends the round before the clock does",
		elapsed < round_len,
		"round closed after %.1fs of a %.0fs clock" % [elapsed, round_len])
	if is_instance_valid(g2):
		g2.queue_free()
	await _frames(2)

## ── MudPieMaker: does holding the green zone pay anything? ──
##
## The game sets game_mode = "survival", so MiniGameBase._on_timer_timeout() already
## ends a survived round as a WIN -- that part was never broken. What was broken is
## that the round had no score and no heartbeat: `var _in_zone = ...` was computed
## every frame and discarded, there was no record_action(true) anywhere in the file,
## and the only sample the difficulty algorithm ever received from this game was the
## single record_action(false) fired when the level hit 0 or 100. A perfectly played
## round therefore banked 0 points, played no success cue and never moved the combo.
func _mud_pie_checks() -> void:
	print("")
	print("── MudPieMaker: in-zone time pays ──")
	var game: Node = await _live_round("res://scenes/minigames/MudPieMaker.tscn")
	if game.get("game_active") != true:
		_check("[7] MudPieMaker round started", false, "game_active never became true")
		return

	# Hold the level in the middle of the band. water_level is what pouring drives, so
	# pinning it exercises the real scoring branch rather than replacing it.
	var mid: float = (float(game.target_min) + float(game.target_max)) * 0.5
	var score_before: int = int(game.current_score)
	var correct_before: int = int(game.correct_actions)
	var until := Time.get_ticks_msec() + 2600
	while Time.get_ticks_msec() < until and game.get("game_active") == true:
		game.water_level = mid
		await get_tree().process_frame
	var score_after: int = int(game.current_score)
	var correct_after: int = int(game.correct_actions)
	_check("[7] holding the green zone scores", score_after > score_before,
		"score %d -> %d over ~2.6s in band" % [score_before, score_after])
	_check("[7b] and feeds the difficulty window a success sample",
		correct_after > correct_before,
		"correct_actions %d -> %d" % [correct_before, correct_after])

	# Out of the band the ticks must stop entirely.
	var s0: int = int(game.current_score)
	var out_of_band: float = maxf(float(game.target_min) - 10.0, 1.0)
	until = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until and game.get("game_active") == true:
		game.water_level = out_of_band
		await get_tree().process_frame
	_check("[8] outside the band nothing accrues", int(game.current_score) == s0,
		"score held at %d (was %d) while dry at %.0f" % [int(game.current_score), s0, out_of_band])
	if game.get("game_active") == true:
		game.queue_free()
	await _frames(2)
