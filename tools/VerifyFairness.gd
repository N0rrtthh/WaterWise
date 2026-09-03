extends Node

## Fairness gate: proves every minigame round is physically clearable by a human.
##
## Run:
##   godot --path . res://tools/VerifyFairness.tscn
##
## Why this exists: difficulty tables and the mistake penalty were tuned in
## separate files, so nothing caught the combinations where they multiply into an
## unwinnable round. Two real examples this gate now blocks:
##
##   1. Hard TurnOffTap ran an 8 s clock with a flat 10 s mistake penalty. One
##      wrong tap set effective_time_left below zero on the same frame — the
##      round was lost before the player could respond.
##   2. Survival games deducted time for mistakes, but in survival mode running
##      the clock out IS the win, so a mistake *helped*.
##
## Both are properties of the numbers, not of the rendering, so they are
## checkable headlessly without playing a round.
##
## Checks, for every minigame scene, at Easy / Medium / Hard:
##   A. penalty budget — a round must survive at least MIN_MISTAKES errors
##   B. survival games must have a zero clock penalty
##   C. quota pace — required actions per second must stay under MAX_APS
##   D. timer sanity — game_duration must be positive and finite
##
## Exits 0 on success, 1 on any failure, so it can gate a build.

## A round must tolerate this many mistakes before the clock hits zero.
## Three is the floor for "recoverable": one slip, one panic, one bad read.
const MIN_MISTAKES: int = 3

## Sustained taps/drags per second a child on a phone can hold for a whole
## round. Deliberately conservative — DWTD rounds are short and readable, not
## twitch tests. Anything above this is a reflex wall, not a difficulty curve.
const MAX_APS: float = 1.6

## Quota variable per game. Games absent from this map have no countable quota
## (they use a progress bar, a tolerance band, or survival rules) and are only
## checked for A, B and D.
const QUOTA_VAR := {
	"BucketBrigade": "target_buckets",
	"CatchTheRain": "target_score",
	"CloudCatcher": "target_plants",
	"FilterBuilder": "target_filters",
	"GreywaterSorter": "target_sort",
	"QuickShower": "target_showers",
	"ScrubToSave": "target_dishes",
	"SpotTheSpeck": "target_correct",
	"SwipeTheSoap": "target_soaps",
	"TimingTap": "target_containers",
	"ToiletTankFix": "target_tanks",
	"TracePipePath": "target_paths",
	"TurnOffTap": "target_taps",
}


## Games whose quota counts DISTINCT objects from a pool the scene builds once, so each
## element can score at most one point and the quota cannot exceed the pool.
##
## Derived by sweeping every QUOTA_VAR game for an array populated in setup and never added
## to again during play, then reading each win path by hand. The others all re-supply their
## scorables during the round - BucketBrigade and GreywaterSorter spawn from a timer,
## TurnOffTap recycles positions out of available_positions, SpotTheSpeck, QuickShower,
## FilterBuilder and TracePipePath rebuild their subject after every judgement - so their
## quota is a throughput target and this check does not apply to them.
const COVERAGE_POOL := {
	"CloudCatcher": "plants",
}

const DIFFICULTIES: Array[String] = ["Easy", "Medium", "Hard"]

var _failures: Array[String] = []
var _checked: int = 0

func _ready() -> void:
	await get_tree().process_frame

	var scenes := _list_minigames()
	print("▶ Fairness gate: %d minigames × %d difficulties" % [scenes.size(), DIFFICULTIES.size()])

	for scene_name in scenes:
		for diff in DIFFICULTIES:
			await _check(scene_name, diff)

	print("— checked %d game/difficulty pairs" % _checked)
	if _failures.is_empty():
		print("✅ VerifyFairness: all rounds are clearable")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("❌ %s" % f)
		printerr("❌ VerifyFairness: %d failure(s)" % _failures.size())
		get_tree().quit(1)

func _list_minigames() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("res://scenes/minigames")
	if dir == null:
		_failures.append("cannot open res://scenes/minigames")
		return out
	for f in dir.get_files():
		# Exported builds rename .tscn to .scn/.remap; accept every spelling.
		if f.get_extension() in ["tscn", "scn", "remap"]:
			var base := f.get_basename()
			if base.get_extension() != "":
				base = base.get_basename()
			if not out.has(base):
				out.append(base)
	out.sort()
	return out

func _check(scene_name: String, difficulty: String) -> void:
	var path := "res://scenes/minigames/%s.tscn" % scene_name
	if not ResourceLoader.exists(path):
		_failures.append("%s: scene missing at %s" % [scene_name, path])
		return

	# Pin the difficulty before the scene's _ready() reads it. MiniGameBase
	# awaits one frame first, so setting it here lands in time.
	if AdaptiveDifficulty:
		AdaptiveDifficulty.current_difficulty = difficulty

	var packed := load(path) as PackedScene
	if packed == null:
		_failures.append("%s: could not load PackedScene" % scene_name)
		return

	var game := packed.instantiate()

	# Skip scenes that are not MiniGameBase rounds. RainwaterHarvesting is a
	# multiplayer Node2D that calls change_scene_to_file() in _ready(), which
	# tears the tree out from under this harness — every later `await
	# get_tree().process_frame` then fails on a null tree. Filtering before
	# add_child() keeps it out of the tree entirely.
	if not game.has_method("_apply_sp_time_penalty"):
		game.free()
		return

	add_child(game)

	# MiniGameBase._ready() awaits a frame, then loads and applies difficulty.
	# Two frames covers both; it then blocks on the instruction overlay, which
	# is exactly where we want to inspect the numbers.
	await get_tree().process_frame
	await get_tree().process_frame

	var tag := "%s/%s" % [scene_name, difficulty]
	_checked += 1

	var duration: float = float(game.game_duration)
	var mode: String = str(game.game_mode)

	# Recompute the penalty the way _start_timer() will.
	#
	# Reading game.mistake_time_penalty here would measure the *provisional*
	# value set during _load_difficulty_settings(), before the subclass's
	# _apply_difficulty_settings() had set the real game_duration. Since the
	# penalty scales with duration, that value is wrong by exactly the ratio of
	# default to actual duration — it reported 3.6 s for a 10 s round that
	# actually charges 1.8 s. The round is blocked on the instruction overlay at
	# this point, so _start_timer() has not run yet.
	var penalty: float = float(game._penalty_for_difficulty(str(game.current_difficulty)))

	# ── D. timer sanity ────────────────────────────────────────────────────
	if duration <= 0.0 or not is_finite(duration):
		_failures.append("%s: game_duration is %s" % [tag, duration])
		# Same detach-then-free order as the tail of this function.
		remove_child(game)
		await get_tree().process_frame
		game.free()
		return

	if mode == "survival":
		# ── B. survival games must not be clock-penalised ───────────────────
		# Timer expiry calls end_game(true), so a positive penalty turns a
		# mistake into a shortcut to victory.
		var applied := _probe_penalty(game)
		if applied > 0.0:
			_failures.append(
				"%s: survival mode deducted %.1fs for a mistake (must be 0)"
				% [tag, applied]
			)
	else:
		# ── A. penalty budget ──────────────────────────────────────────────
		if penalty > 0.0:
			var affordable := int(floor(duration / penalty))
			if affordable < MIN_MISTAKES:
				_failures.append(
					"%s: %.1fs round with %.1fs penalty survives only %d mistake(s), need %d"
					% [tag, duration, penalty, affordable, MIN_MISTAKES]
				)

		# ── C. quota pace ──────────────────────────────────────────────────
		if QUOTA_VAR.has(scene_name):
			var quota_var: String = QUOTA_VAR[scene_name]
			var quota: float = float(game.get(quota_var))
			if quota > 0.0:
				var aps := quota / duration
				if aps > MAX_APS:
					_failures.append(
						"%s: needs %.0f %s in %.1fs = %.2f actions/sec (max %.2f)"
						% [tag, quota, quota_var, duration, aps, MAX_APS]
					)

		# ── E. coverage-quota reachability ─────────────────────────────────────
		# A quota that counts DISTINCT one-shot objects cannot exceed the pool the
		# scene built. This is not the pace check above: CloudCatcher Hard asked for
		# 8 plants in 10 s = 0.80 actions/sec, comfortably fair, from a hardcoded row
		# of 6 plants that each score once. plants_watered could never reach 8, so
		# the win branch never ran and a perfect round reported a loss. A gate whose
		# header says it "proves every round is physically clearable" has to look at
		# whether the win condition can fire at all, not only at how fast it asks.
		if COVERAGE_POOL.has(scene_name):
			var pool_var: String = COVERAGE_POOL[scene_name]
			var pool = game.get(pool_var)
			var pool_size: int = (pool as Array).size() if pool is Array else -1
			var need: int = int(game.get(QUOTA_VAR[scene_name]))
			if pool_size < 0:
				_failures.append("%s: %s is not an Array, cannot size the pool"
					% [tag, pool_var])
			elif pool_size < need:
				_failures.append(
					"%s: quota of %d %s over a pool of %d one-shot %s - the win condition cannot fire"
					% [tag, need, QUOTA_VAR[scene_name], pool_size, pool_var])

	# Detach, let the parked coroutine notice, then free.
	#
	# This harness inspects the round while it is still blocked on the instruction overlay -
	# see the comment above add_child() - so MiniGameBase._wait_for_input() is parked on
	# `await get_tree().process_frame` in every single probe. Freeing it there destroys the
	# tree connection that would have resumed it, and the orphaned GDScriptFunctionState is
	# never released: 72 at exit under --verbose, exactly one per probe, with
	# `Orphan StringName: _wait_for_input (total: 72)` naming the function. Removing the node
	# first and giving the tree one frame lets the loop resume, see is_inside_tree() go false
	# and return on its own, which is what releases the state.
	remove_child(game)
	await get_tree().process_frame
	game.free()

## Fire one mistake through the real code path and report the seconds it cost.
##
## Reading mistake_time_penalty is not enough: _apply_sp_time_penalty() decides
## whether to charge it. This measures what a player would actually lose.
func _probe_penalty(game: Node) -> float:
	var before: float = float(game._time_penalty_total)
	# The guard clause needs both flags set, otherwise the call returns early
	# and a real bug would read as a pass.
	game.game_active = true
	game.timer_running = true
	game._apply_sp_time_penalty()
	return float(game._time_penalty_total) - before
