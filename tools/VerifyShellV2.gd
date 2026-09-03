extends Node

## ═══════════════════════════════════════════════════════════════════
## V2 MICROGAME SHELL VERIFICATION (headless, thesis-auditable)
## ═══════════════════════════════════════════════════════════════════
## Four scenes — BucketBrigade, CatchTheRain, FixLeak, GreywaterSorter — do not
## run the scripts next to them in scenes/minigames/. Their .tscn files point at
## scripts/minigames_v2/*V2.gd, which extend MicrogameShell, which extends
## MiniGameBase. That second base class had drifted away from the first in two
## ways this harness pins down:
##
##   1. chaos_effects were dropped. BucketBrigadeV2, CatchTheRainV2 and
##      GreywaterSorterV2 overrode _apply_difficulty_settings() without calling
##      super(), and super() is what queues the chaos_effects the algorithm
##      selected. Three of the 25 minigames therefore ran clean at every
##      difficulty, silently discarding one of the four adaptive outputs the
##      thesis specifies. (FixLeakV2 always called super() — its comment even
##      says "incl. the super call for time/chaos".)
##
##   2. Actions were counted twice. MicrogameShell.record_hit()/record_miss()
##      repeated bookkeeping that MiniGameBase.record_action() already owns:
##      current_score, combo_streak, max_combo and mistakes_made. The combo
##      popper read "x2" after a single hit, and the doubled mistakes_made
##      corrupts E = m/(m+5) in the thesis score — i.e. the number fed to
##      AdaptiveDifficulty. CatchTheRainV2 had already worked around the score
##      half with a private quota counter rather than fixing the shell.
##
## It also covers control_reverse, the one Hard chaos effect that had no reader
## anywhere in the project: MiniGameBase set `controls_reversed` and nothing
## consumed it. MicrogameShell now mirrors drag input when it is set — and the two
## places that later decided something from the RAW finger position (CatchTheRain's
## tap, GreywaterSorter's release) are pinned here too, because a half-applied
## mirror is worse than none: the paddle jumped on touch-down, and a bucket the
## player could see over the garden scored as a drain drop.
##
## Run:
##   Godot --headless --path <project> res://tools/VerifyShellV2.tscn
## Exit code 0 = all passed, 1 = at least one failure.
##
## If the log stops after the autoload banners and the process never exits, this
## script failed to PARSE: Godot leaves the root node scriptless, so nothing ever
## reaches get_tree().quit() and the run idles forever. Windows block-buffers
## stdout into a file, so a redirected log looks frozen either way — but Godot's
## SCRIPT ERROR lines go to stderr, which is not buffered. Redirect 2>&1 into the
## same log and the parse error is the first thing you see. (printerr() is the same
## trick for tracing a genuine hang: it lands in the log immediately.)
## ═══════════════════════════════════════════════════════════════════

const DIFFICULTIES: PackedStringArray = ["Easy", "Medium", "Hard"]

## scene stem → the member holding that game's quota.
const SHELL_GAMES: Dictionary = {
	"BucketBrigade": "target_buckets",
	"CatchTheRain": "target_score",
	"FixLeak": "num_leaks",
	"GreywaterSorter": "target_sort",
}

## How many chaos_effects AdaptiveDifficulty.DIFFICULTY_SETTINGS emits per
## difficulty: NONE / MILD / STRONG in the paper's terms.
const EXPECTED_CHAOS: Dictionary = {"Easy": 0, "Medium": 1, "Hard": 5}

## Mirrors GreywaterSorterV2.ZONE_LEFT_X — a const on the game class cannot be
## read through an instance, and the harness needs the garden edge to assert
## where the bucket ended up.
const SORTER_GARDEN_EDGE: float = 0.30

## Mirrors CatchTheRainV2's SPAWN_Y, CATCH_BAND_BOTTOM, CATCH_WINDOW_S and the
## 0.72 good-drop rate in _spawn_drop(), for the same reason.
const RAIN_SPAWN_Y: float = -30.0
const RAIN_BAND_BOTTOM: float = -55.0
const RAIN_CATCH_WINDOW_S: float = 0.12
const RAIN_GOOD_DROP_RATE: float = 0.72

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE V2 MICROGAME SHELL VERIFICATION")
	print("═══════════════════════════════════════════════════════════")

	for diff in DIFFICULTIES:
		print("")
		print("── %s ──" % diff)
		await _verify_chaos_reaches_the_board(diff)

	print("")
	print("── quota escalates with difficulty ──")
	await _verify_quota_escalation()

	print("")
	print("── the rain falls in seconds, not pixels ──")
	await _verify_rain_fall_is_screen_independent()

	print("")
	print("── action accounting is single-entry ──")
	await _verify_scoring_parity()

	print("")
	print("── control_reverse mirrors drag input, tap and drag agree ──")
	await _verify_drag_mirror()

	print("")
	print("── a sorter drop is judged by the bucket, not the finger ──")
	await _verify_sorter_release_follows_the_bucket()

	print("")
	print("── the HUD number is the score, the water is the quota ──")
	await _verify_quota_and_score_stay_separate()

	print("")
	print("── AutoPlay reaches a shell paddle ──")
	await _verify_autoplay_reaches_the_paddle()

	print("")
	print("── juice tweens do not fight over a property ──")
	await _verify_juice_tween_slots()

	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		for f in _failures:
			print("    ✗ %s" % f)
	print("═══════════════════════════════════════════════════════════")
	print("")

	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		var msg := label if detail == "" else "%s — %s" % [label, detail]
		_failures.append(msg)
		print("    ✗ %s  %s" % [label, detail])


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


## Depth-first search for a Label whose text is exactly `want`.
func _find_label_with_text(root: Node, want: String) -> Label:
	for child in root.get_children():
		if child is Label and (child as Label).text == want:
			return child
		var found := _find_label_with_text(child, want)
		if found:
			return found
	return null


## The algorithm picks chaos_effects per difficulty; the base queues them during
## _apply_difficulty_settings() and drains the queue at the end of _ready(). Both
## halves have to happen for the effect to exist on screen, so this asserts the
## queue is empty (drained, not merely never filled) AND that the effects landed.
func _verify_chaos_reaches_the_board(diff: String) -> void:
	var want_count: int = EXPECTED_CHAOS[diff]
	for stem in SHELL_GAMES:
		var game: Node = await _boot(stem, diff)
		if game == null:
			continue

		var selected: Array = game.chaos_effects_active
		var pending: Array = game.get("_pending_chaos_effects")
		var reversed_now: bool = bool(game.controls_reversed)
		# buzzing_fly is a plain Label; unlike screen shake it has no
		# accessibility gate, so it is the honest witness that the queue drained.
		var fly := _find_label_with_text(game, "🐛")

		print("    %-16s %-6s selected=%d pending=%d reversed=%s fly=%s"
			% [stem, diff, selected.size(), pending.size(), reversed_now,
				fly != null])

		_check("%s/%s: the algorithm's chaos_effects are read" % [stem, diff],
			selected.size() == want_count,
			"chaos_effects_active has %d entries, %s emits %d"
				% [selected.size(), diff, want_count])
		_check("%s/%s: the chaos queue was drained" % [stem, diff],
			pending.is_empty(),
			"%d effect(s) still queued after _ready()" % pending.size())
		_check("%s/%s: control_reverse matches the selection" % [stem, diff],
			reversed_now == ("control_reverse" in selected),
			"controls_reversed=%s but selection is %s"
				% [reversed_now, str(selected)])
		if "buzzing_fly" in selected:
			_check("%s/%s: buzzing_fly actually spawned" % [stem, diff],
				fly != null, "no 🐛 Label under the game")
		await _teardown(game)


## Not a copy of each game's tuning table — that would only restate the source.
## The design claim under test is that the quota rises monotonically with
## difficulty, which is what a mis-wired current_difficulty would break.
func _verify_quota_escalation() -> void:
	for stem in SHELL_GAMES:
		var prop: String = SHELL_GAMES[stem]
		var quotas: Array[int] = []
		for diff in DIFFICULTIES:
			var game: Node = await _boot(stem, diff)
			if game == null:
				break
			quotas.append(int(game.get(prop)))
			await _teardown(game)
		if quotas.size() != DIFFICULTIES.size():
			continue
		print("    %-16s %s = %d / %d / %d  (Easy/Medium/Hard)"
			% [stem, prop, quotas[0], quotas[1], quotas[2]])
		_check("%s: %s rises with difficulty" % [stem, prop],
			quotas[0] < quotas[1] and quotas[1] < quotas[2],
			"Easy=%d Medium=%d Hard=%d" % [quotas[0], quotas[1], quotas[2]])


## CatchTheRain authored its fall as px/s, which makes the round a function of
## screen height: at Medium's old 350 px/s the drum sat 1725 px below the clouds on
## a 1920-tall viewport, so nothing was catchable for the first 4.9 s of a 10 s
## round and the 8-catch quota needed 8 of the ~10 good drops that could physically
## arrive. AutoPlay's omniscient driver lost every Medium round 7-of-8 with zero
## mistakes — the supply, not the aim, was the ceiling. Speed is now derived from
## fall_time, so this checks the three properties that fix depends on: the fall
## lasts the authored seconds, the catch window is a constant TIME (a fixed-pixel
## band shrinks to a couple of frames once the drops are fast), and enough good
## drops can reach the drum to clear the quota with room to spare.
func _verify_rain_fall_is_screen_independent() -> void:
	for diff in DIFFICULTIES:
		var g: Node = await _boot("CatchTheRain", diff)
		if g == null:
			continue
		# _shell_start() is where the derivation happens. _boot() stops short of
		# start_game() (which would await the verb flash and arm the timer), so call
		# it directly — it only releases the pool and does arithmetic.
		g.call("_shell_start")

		var band_bottom: float = g.drum_node.position.y + RAIN_BAND_BOTTOM
		var speed: float = float(g.drop_speed)
		var measured_fall: float = (band_bottom - RAIN_SPAWN_Y) / speed
		var window: float = float(g.catch_band_height) / speed
		var duration: float = float(g.game_duration)
		var arrivals: float = maxf(duration - measured_fall, 0.0) / float(g.spawn_interval)
		var good: float = arrivals * RAIN_GOOD_DROP_RATE
		var quota: int = int(g.target_score)

		print("    %-6s fall %.2fs (want %.2f) speed %.0f px/s  window %.0f ms"
			% [diff, measured_fall, float(g.fall_time), speed, window * 1000.0])
		print("      %.1f good drops can arrive in %.0fs for a quota of %d"
			% [good, duration, quota])
		_check("a drop takes fall_time to reach the drum (%s)" % diff,
			absf(measured_fall - float(g.fall_time)) < 0.02,
			"took %.3fs, authored %.3fs" % [measured_fall, float(g.fall_time)])
		_check("the catch window is a constant time (%s)" % diff,
			absf(window - RAIN_CATCH_WINDOW_S) < 0.005,
			"window is %.0f ms, expected %.0f ms"
				% [window * 1000.0, RAIN_CATCH_WINDOW_S * 1000.0])
		_check("the window spans several frames at 60 fps (%s)" % diff,
			window * 60.0 >= 4.0,
			"only %.1f frames — drops can pass through the drum" % (window * 60.0))
		_check("the quota is reachable with margin (%s)" % diff,
			good >= float(quota) * 1.5,
			"%.1f good drops available for a quota of %d" % [good, quota])
		await _teardown(g)


## record_action() in MiniGameBase owns every counter. The shell's record_hit()/
## record_miss() must add presentation only. Four hits then one miss, checked
## against the base's own arithmetic: +10 per hit plus floor(streak/3)*5.
func _verify_scoring_parity() -> void:
	var game: Node = await _boot("BucketBrigade", "Medium")
	if game == null:
		return

	game.current_score = 0
	game.total_actions = 0
	game.correct_actions = 0
	game.mistakes_made = 0
	game.combo_streak = 0
	game.max_combo = 0

	var want_score: int = 0
	for i in range(4):
		game.record_hit()
		want_score += 10 + int(floor(float(i + 1) / 3.0)) * 5

	print("    after 4 record_hit(): score=%d (expected %d) actions=%d correct=%d"
		% [int(game.current_score), want_score, int(game.total_actions),
			int(game.correct_actions)])
	print("      combo=%d max_combo=%d mistakes=%d"
		% [int(game.combo_streak), int(game.max_combo),
			int(game.mistakes_made)])

	_check("record_hit files one action", int(game.total_actions) == 4,
		"total_actions=%d after 4 hits" % int(game.total_actions))
	_check("record_hit advances the streak once",
		int(game.combo_streak) == 4,
		"combo_streak=%d after 4 hits" % int(game.combo_streak))
	_check("max_combo tracks the real streak", int(game.max_combo) == 4,
		"max_combo=%d after 4 hits" % int(game.max_combo))
	_check("record_hit awards the base score exactly once",
		int(game.current_score) == want_score,
		"score=%d, base arithmetic gives %d" % [int(game.current_score), want_score])
	_check("a hit is not also a mistake", int(game.mistakes_made) == 0,
		"mistakes_made=%d after 4 clean hits" % int(game.mistakes_made))

	game.record_miss()
	print("    after 1 record_miss(): actions=%d mistakes=%d combo=%d"
		% [int(game.total_actions), int(game.mistakes_made),
			int(game.combo_streak)])
	_check("record_miss files one mistake", int(game.mistakes_made) == 1,
		"mistakes_made=%d after one miss — E = m/(m+5) would be wrong"
			% int(game.mistakes_made))
	_check("record_miss files one action", int(game.total_actions) == 5,
		"total_actions=%d after 4 hits + 1 miss" % int(game.total_actions))
	_check("record_miss resets the streak", int(game.combo_streak) == 0,
		"combo_streak=%d after a miss" % int(game.combo_streak))

	await _teardown(game)


## control_reverse only means anything if some code reads controls_reversed. Hard
## selects it, so drag positions must come back mirrored there and untouched on
## Easy. The shell leaves TAP positions alone (a tap has no direction to reverse),
## but CatchTheRain's tap moves the paddle exactly like a drag does, so that game
## maps its own: otherwise touch-down jumped the drum to the raw finger x and the
## first drag snapped it across the screen to the mirrored one.
func _verify_drag_mirror() -> void:
	for diff in ["Easy", "Hard"]:
		var game: Node = await _boot("CatchTheRain", diff)
		if game == null:
			continue
		var vp_w: float = game.get_viewport_rect().size.x
		var probe := Vector2(120.0, 300.0)
		# call() rather than a direct dotted call: this is a harness deliberately
		# probing an underscore-private helper, and the linter is right to flag
		# the dotted form as a private-access violation.
		var mapped: Vector2 = game.call("_shell_map_drag", probe)
		var want := Vector2(vp_w - probe.x, probe.y) if bool(game.controls_reversed) \
			else probe
		print("    %-6s reversed=%s  drag x %.0f → %.0f (expected %.0f)"
			% [diff, bool(game.controls_reversed), probe.x, mapped.x, want.x])
		_check("drag mirror follows controls_reversed (%s)" % diff,
			mapped.is_equal_approx(want),
			"mapped %s, expected %s" % [str(mapped), str(want)])
		_check("the mirror leaves the vertical axis alone (%s)" % diff,
			is_equal_approx(mapped.y, probe.y),
			"y moved from %.1f to %.1f" % [probe.y, mapped.y])

		# Same finger, both gestures: the paddle must end up in one place.
		game.call("_shell_tap", probe)
		var x_tap: float = game.drum_node.position.x
		game.call("_shell_drag", mapped)
		var x_drag: float = game.drum_node.position.x
		print("      paddle: tap→%.0f drag→%.0f (expected %.0f)"
			% [x_tap, x_drag, want.x])
		_check("a tap and a drag agree on where the paddle goes (%s)" % diff,
			is_equal_approx(x_tap, x_drag),
			"tap left it at %.1f, drag at %.1f" % [x_tap, x_drag])
		_check("the paddle follows the mirrored finger (%s)" % diff,
			is_equal_approx(x_drag, want.x),
			"drum at %.1f, expected %.1f" % [x_drag, want.x])
		await _teardown(game)


## Drag a SAFE (blue) bucket onto the garden and check it scores as correct — at
## Easy by dragging left, at Hard by dragging right, because the mirror is what
## carries it left. The old code read the finger, so the Hard case scored the
## bucket the player could see over the garden as a drain drop.
func _verify_sorter_release_follows_the_bucket() -> void:
	for diff in ["Easy", "Hard"]:
		var g: Node = await _boot("GreywaterSorter", diff)
		if g == null:
			continue
		var vp_w: float = g.get_viewport_rect().size.x
		var pool: EntityPool = g.bucket_pool
		var b: Node2D = pool.acquire() as Node2D
		b.set_meta("safe", true)      # blue water belongs in the garden
		b.set_meta("being_sorted", false)
		b.position = Vector2(vp_w * 0.5, 320.0)
		b.scale = Vector2.ONE
		b.modulate = Color.WHITE

		g.sorted_correct = 0
		g.mistakes_made = 0
		# _sort_bucket refuses to score outside a live round; flipped back below so
		# no stray frame can run the timer or the spawner.
		g.game_active = true
		g.call("_shell_tap", b.position)
		var reversed_now: bool = bool(g.controls_reversed)
		var finger := Vector2(vp_w * (0.85 if reversed_now else 0.10), 320.0)
		g.call("_shell_drag", g.call("_shell_map_drag", finger))
		var bucket_x: float = b.position.x
		g.call("_shell_release", finger)
		g.game_active = false

		var edge: float = vp_w * SORTER_GARDEN_EDGE
		print("    GreywaterSorter %-4s finger→%.0f bucket→%.0f correct=%d wrong=%d"
			% [diff, finger.x, bucket_x, int(g.sorted_correct),
				int(g.mistakes_made)])
		_check("the drag carries the bucket onto the garden (%s)" % diff,
			bucket_x < edge,
			"bucket stopped at %.1f, garden ends at %.1f" % [bucket_x, edge])
		_check("a bucket dropped on the garden scores as correct (%s)" % diff,
			int(g.sorted_correct) == 1 and int(g.mistakes_made) == 0,
			"sorted_correct=%d mistakes=%d" % [int(g.sorted_correct),
				int(g.mistakes_made)])
		await _teardown(g)


## CatchTheRain has two numbers that look alike and are not: the quota (catches
## needed, drawn as the rising water) and the score (10 + floor(streak/3)*5 per
## hit, printed in the HUD). A dirty catch used to overwrite the HUD with the quota
## counter, so the big number read 30 after a catch and 3 after the next mistake.
func _verify_quota_and_score_stay_separate() -> void:
	var rain: Node = await _boot("CatchTheRain", "Medium")
	if rain == null:
		return
	rain.current_score = 0
	rain.total_actions = 0
	rain.correct_actions = 0
	rain.mistakes_made = 0
	rain.combo_streak = 0
	rain.caught_count = 0

	var pool: EntityPool = rain.drop_pool
	var good: Node2D = pool.acquire() as Node2D
	good.set_meta("good", true)
	rain.call("_on_caught", int(good.get_meta(EntityPool.META_POOL_IDX)), good)
	var score_after_hit: int = int(rain.current_score)
	var fill_after_hit: float = rain.water_level.scale.y

	var dirty: Node2D = pool.acquire() as Node2D
	dirty.set_meta("good", false)
	rain.call("_on_caught", int(dirty.get_meta(EntityPool.META_POOL_IDX)), dirty)
	print("    1 clean + 1 dirty catch: score=%d label=\"%s\" quota=%d"
		% [int(rain.current_score), rain.shell_score_label.text,
			int(rain.caught_count)])
	print("      water fill %.3f → %.3f" % [fill_after_hit, rain.water_level.scale.y])

	_check("the HUD number is the score, not the quota",
		rain.shell_score_label.text == str(int(rain.current_score)),
		"label reads \"%s\" with score %d"
			% [rain.shell_score_label.text, int(rain.current_score)])
	_check("a dirty catch awards no score",
		int(rain.current_score) == score_after_hit,
		"score moved %d → %d" % [score_after_hit, int(rain.current_score)])
	_check("a dirty catch files exactly one mistake",
		int(rain.mistakes_made) == 1,
		"mistakes_made=%d" % int(rain.mistakes_made))
	_check("a dirty catch walks the quota back",
		int(rain.caught_count) == 0,
		"caught_count=%d after +1 then -1" % int(rain.caught_count))
	_check("the water level tracks the quota",
		fill_after_hit > rain.water_level.scale.y,
		"fill did not fall: %.3f → %.3f"
			% [fill_after_hit, rain.water_level.scale.y])
	await _teardown(rain)


## AutoPlay drives the other 20 games by calling their handlers directly, but the
## catcher driver steered with Input.warp_mouse — which only works because a legacy
## catcher lerps toward the OS cursor every frame in _process. The shell is
## event-driven and its mouse-motion arm needs a HELD button, which the driver never
## presses, so the warp moved nothing: the drum sat centred for entire rounds while
## the soak log still counted a played game.
##
## Second half of the same probe: the v2 drops come from a pool, and a released drop
## keeps the position it died at — just past the bottom edge, i.e. the largest y in
## `drops`, which is exactly what the driver's "nearest good drop" scorer maximises.
## It chased corpses. Legacy games queue_free()d their drops, so the array only ever
## held live nodes and the scorer never had to care.
func _verify_autoplay_reaches_the_paddle() -> void:
	var game: Node = await _boot("CatchTheRain", "Medium")
	if game == null:
		return
	var apm := get_node_or_null("/root/AutoPlayManager")
	if apm == null:
		_check("AutoPlayManager is available", false, "autoload not found")
		await _teardown(game)
		return

	var vp: Vector2 = game.get_viewport_rect().size
	var pool: EntityPool = game.drop_pool

	var live: Node2D = pool.acquire() as Node2D
	live.set_meta("good", true)
	live.position = Vector2(vp.x - 260.0, 300.0)

	# A drop that already fell off the bottom and went back to the pool. Still
	# flagged good, still in `drops`, and its y beats every live drop on screen.
	var corpse: Node2D = pool.acquire() as Node2D
	corpse.set_meta("good", true)
	corpse.position = Vector2(120.0, vp.y + 400.0)
	pool.release(corpse)

	var start_x: float = game.drum_node.position.x
	var prev_game: Node = apm.current_game
	apm.current_game = game
	apm.call("_play_catcher", 0.016)
	apm.current_game = prev_game
	var end_x: float = game.drum_node.position.x

	print("    drum %.0f → %.0f   live drop x=%.0f, released drop x=%.0f"
		% [start_x, end_x, live.position.x, corpse.position.x])
	_check("the driver actually moves a shell paddle",
		not is_equal_approx(end_x, start_x),
		"drum never left %.1f — a cursor warp does not reach the shell" % start_x)
	_check("the driver chases the live drop, not a released one",
		is_equal_approx(end_x, live.position.x),
		"drum went to %.1f, the live drop is at %.1f"
			% [end_x, live.position.x])
	await _teardown(game)


## A combo punches the score label on every hit, and the punch lasts 0.28 s — so
## fast play always restarts a tween that is still running. Two live tweens on one
## property both keep writing it, and whichever finishes last decides where the
## node is left. Juice now keeps one tween slot per property group: a repeat kills
## its predecessor, and a different group must NOT evict a live one.
func _verify_juice_tween_slots() -> void:
	var node := Node2D.new()
	var label := Label.new()
	label.text = "0"
	add_child(node)
	add_child(label)
	await get_tree().process_frame

	Juice.pop(node)
	var first: Tween = node.get_meta(Juice.META_TWEEN_SCALE)
	Juice.pop(node)
	var second: Tween = node.get_meta(Juice.META_TWEEN_SCALE)
	print("    pop×2: first valid=%s second valid=%s same=%s"
		% [first.is_valid(), second.is_valid(), first == second])
	_check("a repeated pop kills the tween it replaces", not first.is_valid(),
		"both scale tweens are still live")
	_check("a repeated pop installs a fresh tween",
		second.is_valid() and second != first, "no new tween was stored")

	# A shake must not evict the scale tween — that would strand the node at the
	# pop's 1.35x overshoot for the rest of the round.
	Juice.shake(node, 4.0, 0.1)
	var pos_tw: Tween = node.get_meta(Juice.META_TWEEN_POS)
	print("    then shake: scale tween still valid=%s position tween valid=%s"
		% [second.is_valid(), pos_tw.is_valid()])
	_check("shake does not evict the scale tween", second.is_valid(),
		"the pop tween was killed by a shake, leaving scale mid-curve")
	_check("shake installs its own tween", pos_tw.is_valid() and pos_tw != second,
		"position and scale share one slot")

	Juice.punch_label(label)
	var l1: Tween = label.get_meta(Juice.META_TWEEN_SCALE)
	Juice.punch_label(label)
	var l2: Tween = label.get_meta(Juice.META_TWEEN_SCALE)
	print("    punch_label×2: first valid=%s second valid=%s"
		% [l1.is_valid(), l2.is_valid()])
	_check("a repeated label punch kills its predecessor", not l1.is_valid(),
		"two tweens are writing the label's scale")

	# Both curves end at the rest value; let them run out and confirm it.
	await get_tree().create_timer(0.6).timeout
	print("    settled: node.scale=%s label.scale=%s"
		% [str(node.scale), str(label.scale)])
	_check("the node settles back to its base scale",
		node.scale.is_equal_approx(Vector2.ONE),
		"scale left at %s" % str(node.scale))
	_check("the label settles back to its base scale",
		label.scale.is_equal_approx(Vector2.ONE),
		"scale left at %s" % str(label.scale))

	node.queue_free()
	label.queue_free()
	await get_tree().process_frame
