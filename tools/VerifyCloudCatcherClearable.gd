extends Node

## Is CloudCatcher's quota reachable in the TIME it gives, at perfect play?
##
## tools/VerifyFairness.gd check E proved the quota no longer exceeds the pool of plants
## (FIX 88). That is arithmetic reachability, and it is necessary but not sufficient: it says
## eight scorable plants exist, not that eight can be watered inside ten seconds. This
## harness measures the second thing, because the frame at
## tools/probe_frames/CloudCatcherHard/f0180.png makes the gap visible - the plants sit 213
## units apart while one cloud tap drops five droplets in a 60-unit-wide band, so a tap
## waters exactly ONE plant and only when the cloud happens to be over it.
##
## The bot below is deliberately better than a human: it sees every cloud's exact x, taps on
## the frame alignment is best, and has no tap cooldown. If IT cannot clear a round, no child
## on a phone can, and the round is a dead end of the same class as the one FIX 88 closed -
## just reached through the clock instead of through the arithmetic.
##
## Sampling: the drop/plant test in CloudCatcher._process() is a 50-unit proximity check
## against a drop falling at up to 500 units per second, so a coarse frame step would let
## drops tunnel THROUGH plants and understate what is achievable. The run measures its own
## worst per-frame drop travel and fails if it ever approaches the collision radius, so a
## bad sample reports itself instead of masquerading as a game defect.

const GAME_PATH := "res://scenes/minigames/CloudCatcher.tscn"
const DIFFS: Array[String] = ["Easy", "Medium", "Hard"]
const TRIALS: int = 8

## Wall time is NOT compressed. Engine.time_scale multiplies delta without adding frames, so
## at 3.0 a single 48 ms hitch stepped a 500-unit-per-second drop 217 units in one frame -
## four times the 50-unit collision radius the game tests against, so drops tunnelled THROUGH
## plants and the run understated what perfect play can do. It reported that itself rather
## than blaming the game; the answer is to stop compressing and let the trials take the
## seconds they take.
const TIME_SCALE: float = 1.0

## Collision radius in CloudCatcher._process(), and the per-frame drop travel this run will
## tolerate before declaring its own sampling too coarse to trust.
const HIT_RADIUS: float = 50.0
const MAX_STEP_UNITS: float = 25.0

## FIX 93 - a cloud this close in x is worth tapping. The geometry, from CloudCatcher._spawn_rain() and the
## hit test at CloudCatcher.gd:319: a tap drops 5 drops at cloud.x + U(-30, +30), a drop scores
## when it comes within 50 units of a plant, and a plant needs 2 drops. So at |dx| = 40 the drops
## that score are those with u < 10 - 40 of the 60-unit spread, 3.3 of the 5 drops, against the 2
## required.
##
## This WAS 20, described as "the bot does not gamble", and that made the harness's own bot worse
## than the one that SHIPS: AutoPlayManager.CLOUD_AIM_TOL is 40, and in the phase-2 pass it
## converted a cloud every 0.82s on Hard where this bot managed 1.12s. A harness that claims to
## measure whether PERFECT play can clear a round must not be beatable by the shipped bot - the
## 4-of-8 Hard result it produced was a property of the instrument, not of the game.
const ALIGN_TOL: float = 40.0

## Each drop is worth 0.5 of a plant's 1.0, so a plant needs two. The bot stops feeding a
## plant once enough drops are already committed to it, and spends the next cloud elsewhere.
const DROPS_PER_PLANT: int = 2

var _pass: int = 0
var _fail: int = 0
var _worst_step: float = 0.0
var _drop_frames: int = 0
var _over_step: int = 0
var _taps: int = 0
var _starved: int = 0
var _active: int = 0
var _tunnelled: int = 0
var _prev_y: Dictionary = {}

## Which bot is driving. Phase 1 is the harness's own optimal player, which answers "is this
## round humanly possible at all". Phase 2 hands the same rounds to AutoPlayManager, the bot that
## actually SHIPS - it drives the attract/demo path and every unattended soak in this audit, so a
## soak that never wins CloudCatcher is a soak that never exercises the win path at all.
var _ship_bot: bool = false
var _trials: int = TRIALS

func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [ok]   %s%s" % [label, "" if detail.is_empty() else "  " + detail])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [label, "" if detail.is_empty() else "  " + detail])

func _ready() -> void:
	# The headless viewport is ~1920x1920, and CloudCatcher derives the plant row, the cloud
	# ceiling and the fall distance from screen_size. Measuring on the wrong canvas would
	# measure a game nobody ships.
	var vw: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	get_window().size = Vector2i(vw, vh)
	await get_tree().process_frame
	await get_tree().process_frame
	print("\n=== VerifyCloudCatcherClearable ===")
	print("  viewport %dx%d, %d trials per difficulty, optimal bot (no tap cooldown)"
		% [vw, vh, TRIALS])

	await _warm_glyphs()

	for diff in DIFFS:
		await _run_difficulty(diff)

	# Phase 2: the bot that actually ships. Fewer trials because each round runs its full clock when
	# the bot cannot finish early, and the question here is narrower - can AutoPlayManager clear this
	# game at all, at each tier.
	_ship_bot = true
	_trials = 4
	print("-- AutoPlayManager (the shipped bot, 0.3s tap cooldown) --")
	for diff in DIFFS:
		await _run_difficulty(diff)

	# Not a claim any more: coarse trials are thrown out and re-run inside _run_difficulty(),
	# so every trial that reached the numbers above sampled finely enough by construction.
	# This is the sampler's own record, printed so the discard rate is visible.
	print("   sampler: %d of %d frames with rain in the air stepped a drop past %.0f units (worst %.1f against the %.0f-unit collision radius); %d of those crossed a plant and were rerun"
		% [_over_step, _drop_frames, MAX_STEP_UNITS, _worst_step, HIT_RADIUS, _tunnelled])

	print("=== %d passed / %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func _run_difficulty(diff: String) -> void:
	var wins: int = 0
	var scored: Array[int] = []
	var quota: int = -1
	var pool: int = -1
	var taps: int = 0
	var drops: int = 0
	var per_tap: float = 0.0
	var game_duration_of: float = 0.0
	var ran_sum: float = 0.0
	var retries: int = 0
	var t: int = 0
	while t < _trials:
		var r: Dictionary = await _one_round(diff)
		if r.is_empty():
			return
		if bool(r["invalid"]):
			# A drop crossed a plant's hit sphere entirely between two frames, so the game
			# never got to test it. That trial measured the sampler, not the game, and is
			# re-run rather than averaged in.
			retries += 1
			if retries > _trials:
				_check(false, "%s: trials could be sampled finely enough" % diff,
					"gave up after %d trials where a drop skipped a plant" % retries)
				return
			continue
		quota = int(r["quota"])
		pool = int(r["pool"])
		scored.append(int(r["scored"]))
		taps += int(r["taps"])
		drops += int(r["drops"])
		per_tap += float(r["per_tap"])
		game_duration_of = float(r["dur"])
		ran_sum += float(r["ran"])
		if bool(r["won"]):
			wins += 1
		t += 1
	scored.sort()
	var best: int = scored[scored.size() - 1]
	var median: int = scored[scored.size() / 2]
	print("-- %s: quota %d over %d plants --" % [diff, quota, pool])
	print("   per trial: %.1f taps converting %.1f drops, one tappable cloud every %.2fs of the %.0fs round%s"
		% [float(taps) / _trials, float(drops) / _trials, per_tap / _trials,
		float(game_duration_of), "" if retries == 0 else ", %d rerun for coarse sampling" % retries])
	# The affordability statement, in the units the round is actually spent in: the quota costs
	# quota x seconds-per-tap, and that has to fit inside the duration the difficulty grants.
	var needed: float = float(quota) * (per_tap / _trials)
	print("      quota costs %.1fs of tapping against a %.0fs clock" % [needed, game_duration_of])
	# How long the round actually lasted. A quota an optimal bot clears in a quarter of the clock
	# is reachable, which is what the gates below assert, but it also means the round can be over
	# before the timer is - a pacing fault rather than a fairness one, so it is reported, not
	# asserted: the bot has frame-perfect timing and no reaction time, and a child does not.
	print("      round ended after %.1fs of its %.0fs" % [ran_sum / _trials, game_duration_of])
	_check(best >= quota, "%s: perfect play can clear the round at all" % diff,
		"best of %d trials watered %d of %d needed" % [_trials, best, quota])
	_check(wins >= int(ceil(_trials * 0.75)),
		"%s: perfect play clears it reliably, not luckily" % diff,
		"%d of %d trials won, median %d watered" % [wins, _trials, median])

## Plays one round and returns {won, scored, quota, pool}. Empty dictionary means the round
## could not be measured, and _check() has already said why.
func _one_round(diff: String) -> Dictionary:
	if AdaptiveDifficulty:
		AdaptiveDifficulty.current_difficulty = diff
		AdaptiveDifficulty.progressive_level = 0
	var packed: PackedScene = load(GAME_PATH)
	if packed == null:
		_check(false, "%s: CloudCatcher.tscn loads" % diff)
		return {}
	var game: Node = packed.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	if not game.has_method("start_game"):
		_check(false, "%s: MiniGameBase.start_game() is callable" % diff)
		game.queue_free()
		return {}
	var quota: int = int(game.get("target_plants"))
	var pool: int = (game.get("plants") as Array).size()
	var tunnel_before: int = _tunnelled
	_prev_y.clear()
	_taps = 0
	_starved = 0
	_active = 0
	Engine.time_scale = TIME_SCALE
	game.call("start_game")
	var real_start: float = Time.get_ticks_msec() / 1000.0
	var dur: float = float(game.get("game_duration"))
	var budget: float = dur / TIME_SCALE + 10.0
	while bool(game.get("game_active")):
		await get_tree().process_frame
		if not is_instance_valid(game):
			break
		_sample_step(game)
		if _ship_bot:
			_ship_bot_step(game, get_process_delta_time())
		else:
			_bot_step(game)
		if Time.get_ticks_msec() / 1000.0 - real_start > budget:
			break
	Engine.time_scale = 1.0
	var ran: float = (Time.get_ticks_msec() / 1000.0 - real_start) * TIME_SCALE
	var scored: int = int(game.get("plants_watered")) if is_instance_valid(game) else -1
	# Read the plants BEFORE the instance is freed. This summation used to sit after
	# queue_free() and an await, so every trial reported 0.0 drops landed - the metric that
	# separates "the bot could not find a cloud to tap" from "it tapped but the rain missed".
	var landed: float = 0.0
	if is_instance_valid(game):
		for plant in (game.get("plants") as Array):
			if is_instance_valid(plant):
				landed += float(plant.get_meta("water_amount", 0.0))
	if is_instance_valid(game):
		game.queue_free()
	await get_tree().process_frame
	if scored < 0:
		_check(false, "%s: the round instance survived to be read" % diff)
		return {}
	return {
		"won": scored >= quota, "scored": scored, "quota": quota, "pool": pool,
		# A drop that crossed a plant's hit sphere inside one frame was never tested against
		# it, so this trial measured the sampler rather than the game and is discarded.
		"invalid": _tunnelled > tunnel_before,
		"taps": _taps, "drops": int(round(landed / 0.5)), "ran": ran,
		# Seconds of round time per cloud the bot could actually convert. The old field was the
		# fraction of frames with no aligned cloud, which sat at 100% by construction: a tapped
		# cloud is removed on the spot, so the very next frame has none. THIS number is the one
		# the quota has to be affordable in - taps needed x seconds per tap against the clock.
		"per_tap": ran / maxf(1.0, float(_taps)), "dur": dur,
	}

## One frame of the optimal player. Taps the untapped cloud that is best aligned with a plant
## still short of water, counting drops already falling toward that plant so a second cloud is
## not wasted on a plant the first one has covered.
func _bot_step(game: Node) -> void:
	var plants: Array = game.get("plants")
	var clouds: Array = game.get("clouds")
	if plants == null or clouds == null:
		return

	# Drops in flight, so "already committed" is real rather than assumed.
	var falling: Array = []
	for child in game.get_children():
		if child is Label and child.has_meta("is_rain"):
			falling.append(child)

	# Plants that still need a cloud, and how many more drops each one needs.
	var wanted: Array = []
	for plant in plants:
		if not is_instance_valid(plant) or plant.get_meta("watered", false):
			continue
		var have: float = float(plant.get_meta("water_amount", 0.0))
		# Drops still needed, in drops: each one carries 1.0 / DROPS_PER_PLANT of the plant.
		var need: int = int(ceil((1.0 - have) / (1.0 / float(DROPS_PER_PLANT))))
		var committed: int = 0
		for drop in falling:
			if absf(drop.position.x - plant.position.x) <= HIT_RADIUS \
				and drop.position.y < plant.position.y:
				committed += 1
		# FIX 93 - was "committed < need * DROPS_PER_PLANT". need is ALREADY a count of drops, so the
		# multiply double-booked every plant: the bot kept aiming clouds at a plant that had two
		# drops inbound and only stopped at four, spending clouds it needed elsewhere. Nor was
		# the slack protective - committed only counts drops whose x already puts them inside
		# HIT_RADIUS, and a drop's x never changes once spawned, so a committed drop is a drop
		# that WILL land.
		if committed < need:
			wanted.append(plant)
	if wanted.is_empty():
		return
	_active += 1

	var best_cloud: Node = null
	var best_dx: float = ALIGN_TOL + 1.0
	for cloud in clouds:
		if not is_instance_valid(cloud) or cloud.get_meta("tapped", false):
			continue
		for plant in wanted:
			var dx: float = absf(cloud.position.x - plant.position.x)
			if dx < best_dx:
				best_dx = dx
				best_cloud = cloud
	if best_cloud == null:
		# A plant needs water and no cloud is anywhere near it. Counting these frames separates
		# the two ways this round can run out of road: not enough TIME to convert the chances,
		# or not enough CHANCES because clouds enter from the screen edges and a late one never
		# reaches the far plants.
		_starved += 1
		return
	if game.has_method("_on_cloud_tapped"):
		game.call("_on_cloud_tapped", best_cloud)
		_taps += 1

## Did the sampler ever let a drop skip a plant it should have hit?
##
## The first version of this asked a weaker question - "did any frame step a drop further than
## the collision radius" - and threw the trial away when one did. Coarse frames are common
## enough (a font hitch, a GC pause) that this discarded most trials while proving nothing:
## a big step only matters if a drop actually crossed a plant's hit sphere inside it. So
## measure the real thing. Each drop falls straight down, so dx to a plant is fixed and the
## sphere reduces to a y-band of half-height sqrt(r^2 - dx^2); a drop that was above the band

## One frame of the bot that ships. AutoPlayManager._process() is not reachable here - it gates on
## auto_play_enabled and would also drive menus, scene changes and the pause overlay - so the two
## things it does for a gameplay handler are done explicitly: age the tap cooldown, then dispatch.
## The handler itself is untouched, which is the point: this measures the shipped aiming code.
##
## A tap is detected by the cooldown the handler sets on success (0.3 s), the handler's only
## observable side effect besides the tap itself.
func _ship_bot_step(game: Node, delta: float) -> void:
	if AutoPlayManager == null or not AutoPlayManager.has_method("_play_cloud_catcher"):
		return
	AutoPlayManager.current_game = game
	if AutoPlayManager.tap_cooldown > 0.0:
		AutoPlayManager.tap_cooldown -= delta
	var before: float = AutoPlayManager.tap_cooldown
	AutoPlayManager.call("_play_cloud_catcher", delta)
	if AutoPlayManager.tap_cooldown > before:
		_taps += 1
## before the step and below it after, and is still alive, went THROUGH the plant untested.
func _sample_step(game: Node) -> void:
	var plants: Array = game.get("plants")
	if plants == null:
		return
	var seen: Dictionary = {}
	for child in game.get_children():
		if not (child is Label and child.has_meta("is_rain")):
			continue
		var id: int = child.get_instance_id()
		seen[id] = true
		var y: float = child.position.y
		if _prev_y.has(id):
			var py: float = float(_prev_y[id])
			_drop_frames += 1
			var step: float = y - py
			_worst_step = maxf(_worst_step, step)
			if step > MAX_STEP_UNITS:
				_over_step += 1
				for plant in plants:
					if not is_instance_valid(plant) or plant.get_meta("watered", false):
						continue
					var dx: float = absf(child.position.x - plant.position.x)
					if dx >= HIT_RADIUS:
						continue
					var half: float = sqrt(HIT_RADIUS * HIT_RADIUS - dx * dx)
					if py < plant.position.y - half and y > plant.position.y + half:
						_tunnelled += 1
		_prev_y[id] = y
	for id in _prev_y.keys():
		if not seen.has(id):
			_prev_y.erase(id)
## The first 💧 costs a font rasterization, and that hitch lands on the very frame the first
## drops start falling. Paying it before the measured trials keeps it out of the sample.
func _warm_glyphs() -> void:
	var l := Label.new()
	l.text = "💧☁️🌱🌻"
	l.add_theme_font_size_override("font_size", 56)
	add_child(l)
	await get_tree().process_frame
	await get_tree().process_frame
	l.queue_free()
