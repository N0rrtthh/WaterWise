extends Node
##
## VerifyPerFrameWork - what does ONE _process() call actually cost, per game?
##
## The Android FPS gate fails on real hardware (average_observed 29.4-29.5 against
## minimum_required 30, minimum_observed 21). A 2 % shortfall is not a rendering
## problem, it is script cost per frame, and the only honest way to attack it is to
## measure the per-frame body of each rostered game rather than guess which one is
## heavy. MiniGameBase._process is already decoupled (cached tenths/band/second, no
## allocation, no unconditional text write); the subclasses are not.
##
## Method: instantiate the real scene, let _ready() build its board, then call
## _process(dt) ITERATIONS times back to back and divide. Direct calls rather than
## real frames because a headless frame is ~87 ms of engine work that would bury the
## signal - here the ONLY thing between the two clock reads is the game's own code.
##
## Also counts children added during the run: a _process that allocates nodes shows
## up as a child delta, which no timing average would separate from slow arithmetic.
##
## Run: Godot --headless --path . tools/VerifyPerFrameWork.tscn
## Exit 0 always - this is a measurement, and the pass/fail bar for it lives in
## VerifyAndroidFrameBudget. Numbers only, so a before/after is comparable.

## The shipped roster, as GameManager.UNLOCK_ID_TO_MINIGAMES lists it.
const GAMES: Array = [
	"CatchTheRain", "CoverTheDrum", "RiceWashRescue",
	"TracePipePath", "PlugTheLeak", "FixLeak", "ToiletTankFix", "TurnOffTap",
	"GreywaterSorter", "VegetableBath", "ScrubToSave", "FilterBuilder", "SpotTheSpeck",
	"WringItOut", "QuickShower", "SwipeTheSoap", "WaterPlant",
	"ThirstyPlant", "MudPieMaker",
	"BucketBrigade", "TimingTap",
	"CloudCatcher", "WaterMemory", "DropletDash"
]

## Enough calls to average out a scheduler hiccup, few enough that a game which
## allocates per frame cannot exhaust memory before it is reported.
const ITERATIONS: int = 3000
const WARMUP: int = 200
const DT: float = 0.016667

var _rows: Array = []

func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame

func _ready() -> void:
	await _frames(2)
	print("=== PER-FRAME WORK (us per _process call, %d iterations) ===" % ITERATIONS)
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if ad != null:
		# Easy: chaos effects add timers and nodes of their own, and this harness is
		# measuring the game's own per-frame body, not the chaos system's.
		ad.set("current_difficulty", "Easy")
	for game in GAMES:
		await _measure(String(game))
	_report()

func _measure(game: String) -> void:
	var path := "res://scenes/minigames/%s.tscn" % game
	if not ResourceLoader.exists(path):
		_rows.append({"game": game, "us": -1.0, "kids": 0, "note": "scene missing"})
		return
	var ps := load(path) as PackedScene
	if ps == null:
		_rows.append({"game": game, "us": -1.0, "kids": 0, "note": "load failed"})
		return
	var inst: Node = ps.instantiate()
	get_tree().root.add_child(inst)
	await _frames(6)

	# The body under test is the ACTIVE one. Games gate _process on game_active and
	# MiniGameBase gates the timer half on timer_running; measuring the early-return
	# path would report every game as free.
	inst.set("game_active", true)
	if inst.get("timer_running") != null:
		inst.set("timer_running", true)
	# Long enough that the round cannot time out mid-measurement and flip
	# game_active false half way through the sample.
	inst.set("game_duration", 100000.0)

	var kids_before: int = inst.get_child_count()
	for _w in range(WARMUP):
		inst.call("_process", DT)
	var t0 := Time.get_ticks_usec()
	for _i in range(ITERATIONS):
		inst.call("_process", DT)
	var t1 := Time.get_ticks_usec()
	var kids_after: int = inst.get_child_count()

	var us: float = float(t1 - t0) / float(ITERATIONS)
	_rows.append({
		"game": game, "us": us, "kids": kids_after - kids_before,
		"note": "" if inst.get("game_active") else "went inactive"
	})
	inst.queue_free()
	await _frames(3)

func _report() -> void:
	_rows.sort_custom(func(a, b): return float(a["us"]) > float(b["us"]))
	print("")
	print("  %-18s %10s %8s  %s" % ["game", "us/call", "kids+", "note"])
	var total: float = 0.0
	for r in _rows:
		if float(r["us"]) > 0.0:
			total += float(r["us"])
		print("  %-18s %10.3f %8d  %s" % [r["game"], r["us"], int(r["kids"]), r["note"]])
	var measured: int = 0
	for r in _rows:
		if float(r["us"]) > 0.0:
			measured += 1
	if measured > 0:
		print("")
		print("  measured=%d  mean=%.3f us/call  sum=%.3f us" % [measured,
			total / float(measured), total])
		# Budget framing: 60 fps is 16667 us per frame, 30 fps is 33333 us. One game
		# runs at a time, so its own body is what matters, not the sum.
		print("  worst as %% of a 30 fps frame (33333 us): %.3f %%"
			% (float(_rows[0]["us"]) / 33333.0 * 100.0))
	print("=== PER-FRAME WORK DONE ===")
	get_tree().quit(0)
