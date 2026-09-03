extends Node

## ═══════════════════════════════════════════════════════════════════
## WHAT SIGNAL DO THE FOUR V2 GAMES ACTUALLY FEED THE ALGORITHM?
## ═══════════════════════════════════════════════════════════════════
## The thesis's rule-based adaptive difficulty scores a round as
##     S = 0.6*A + 0.3*Spd - 0.1*E,  A = correct/total,  E = m/(m+5)
## so a game that can never register an incorrect action reports A = 1.00 and
## E = 0.00 on every round no matter how the player plays: two of the three inputs
## become constants and only speed moves. That is not a faked algorithm, but it is a
## degenerate signal, and it is invisible from the outside because the numbers look
## perfect.
##
## GreywaterSorterV2 (wrong bin) and CatchTheRainV2 (dirty water) both call
## record_miss(). FixLeakV2 and BucketBrigadeV2 did not call it anywhere: their tap
## handlers `return` on a tap that hits nothing AND on a tap that hits a real but
## invalid target — an already-patched leak, a person holding no bucket. Those two
## are deliberate wrong actions on a visible object, not stray taps on background.
##
## WHAT IS MEASURED
##   [1..4] per game: drive one correct action, then one deliberate WRONG action,
##          and report the deltas in total_actions / correct_actions / mistakes_made.
##          A game whose wrong action moves nothing is reported as degenerate.
##   [5]    a tap on genuinely empty background is still free in all four (a wasted
##          swipe must not cost accuracy, or the signal is noise instead).
##   [6]    the sway/drip animation clocks are round-local, not app uptime.
##   [7]    and they do not jump across a pause.
##
## Usage:
##   godot --headless --path . res://tools/VerifyV2Signals.tscn

const GAMES: Array = [
	"res://scenes/minigames/FixLeak.tscn",
	"res://scenes/minigames/BucketBrigade.tscn",
	"res://scenes/minigames/GreywaterSorter.tscn",
	"res://scenes/minigames/CatchTheRain.tscn",
]

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


## A live round, started through the real tap-to-start prompt and the verb flash.
func _live(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await _frames(30)
	# A script with a parse error still instantiates as a bare Node in 4.5.1, so every
	# later property read comes back null and the harness dies of a cast error 200 lines
	# from the cause. Say so here instead. (This is how FIX 48's stray `t` surfaced.)
	if inst.get("game_active") == null:
		_check("%s : script did not load (parse error?)" % String(path).get_file(), false)
		print("\n=== %d passed, %d failed ===" % [_pass, _fail])
		get_tree().quit(1)
		await _frames(600)
		return inst
	for _attempt in range(200):
		var d := InputEventMouseButton.new()
		d.button_index = MOUSE_BUTTON_LEFT
		d.pressed = true
		d.position = get_tree().root.get_visible_rect().size * 0.5
		Input.parse_input_event(d)
		await get_tree().process_frame
		var u := InputEventMouseButton.new()
		u.button_index = MOUSE_BUTTON_LEFT
		u.pressed = false
		u.position = d.position
		Input.parse_input_event(u)
		await get_tree().process_frame
		if inst.get("game_active") == true:
			break
	return inst


## total_actions / correct_actions / mistakes_made, as one comparable triple.
func _snap(g: Node) -> Array:
	return [int(g.get("total_actions")), int(g.get("correct_actions")),
		int(g.get("mistakes_made"))]


func _delta(a: Array, b: Array) -> String:
	return "total %d->%d, correct %d->%d, mistakes %d->%d" % [
		a[0], b[0], a[1], b[1], a[2], b[2]]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n=== VerifyV2Signals ===")
	await _frames(20)
	var degenerate: PackedStringArray = []

	# ── [1] FixLeakV2 ─────────────────────────────────────────────────────────
	var g := await _live(GAMES[0])
	var leak: Node2D = null
	for i in range(int(g.get("LEAK_POOL_SIZE"))):
		var l: Node2D = g.leak_pool.get_item(i)
		if l.visible and not l.get_meta("fixed"):
			leak = l
			break
	_check("[1] FixLeakV2 round live with a patchable leak",
		g.get("game_active") == true and leak != null)
	if leak != null:
		var a := _snap(g)
		g._shell_tap(leak.position)
		await _frames(3)
		var b := _snap(g)
		_check("[1a] patching a leak is one correct action",
			b[0] == a[0] + 1 and b[1] == a[1] + 1, _delta(a, b))
		# Immediately again, inside the grace window: the eager double-tap. Free.
		g._shell_tap(leak.position)
		await _frames(3)
		var bd := _snap(g)
		_check("[1d] an instant double-tap on the leak just patched is forgiven",
			bd[0] == b[0] and bd[2] == b[2], _delta(b, bd))
		# The same leak, well after the grace window, still plainly wearing a patch: a
		# deliberate tap on a visible object that cannot be acted on. Not stray input.
		await _wait_real(0.45)
		g._shell_tap(leak.position)
		await _frames(3)
		var c := _snap(g)
		_check("[1b] tapping an ALREADY-PATCHED leak is counted",
			c[0] == bd[0] + 1 and c[2] == bd[2] + 1, _delta(bd, c))
		if c[0] == bd[0]:
			degenerate.append("FixLeakV2 (already-patched leak)")
		# Genuinely empty background must stay free.
		var far := Vector2(8.0, 8.0)
		g._shell_tap(far)
		await _frames(3)
		var d := _snap(g)
		_check("[1c] a tap on empty background costs nothing",
			d[0] == c[0] and d[2] == c[2], _delta(c, d))
	g.queue_free()
	await _frames(10)

	# ── [2] BucketBrigadeV2 ───────────────────────────────────────────────────
	g = await _live(GAMES[1])
	var holder: int = -1
	for _w in range(240):
		for i in range(int(g.get("NUM_PEOPLE"))):
			if g.bucket_at_person[i] != null:
				holder = i
				break
		if holder >= 0:
			break
		await get_tree().process_frame
	_check("[2] BucketBrigadeV2 round live with a bucket in hand",
		g.get("game_active") == true and holder >= 0, "holder index %d" % holder)
	if holder >= 0:
		var ppos: Vector2 = (g.people[holder] as Node2D).position
		var a2 := _snap(g)
		g._handle_tap(ppos)
		await _frames(3)
		var b2 := _snap(g)
		_check("[2a] passing a bucket along is one correct action",
			b2[0] == a2[0] + 1 and b2[1] == a2[1] + 1, _delta(a2, b2))
		var empty_handed: bool = g.bucket_at_person[holder] == null
		# Straight away: the same eager double-tap. Free.
		g._handle_tap(ppos)
		await _frames(3)
		var b2d := _snap(g)
		_check("[2d] an instant double-tap on the person who just passed is forgiven",
			empty_handed and b2d[0] == b2[0] and b2d[2] == b2[2],
			"empty_handed=%s, %s" % [empty_handed, _delta(b2, b2d)])
		# Well after the grace window: a mistimed pass, the one wrong move this game has.
		# A person OTHER than the one just passed was never handed anything, so their
		# grace timer cannot mask the result — and by then a fresh bucket may well have
		# reached `holder` again, which would make a second tap on them correct.
		await _wait_real(0.45)
		var target_i: int = -1
		for i in range(int(g.get("NUM_PEOPLE"))):
			if i != holder and g.bucket_at_person[i] == null:
				target_i = i
				break
		if target_i < 0 and g.bucket_at_person[holder] == null:
			target_i = holder
		var still_empty: bool = target_i >= 0
		if still_empty:
			g._handle_tap((g.people[target_i] as Node2D).position)
		await _frames(3)
		var c2 := _snap(g)
		_check("[2b] tapping a person with NO bucket is counted",
			still_empty and c2[0] == b2d[0] + 1 and c2[2] == b2d[2] + 1,
			"empty-handed person %d, %s" % [target_i, _delta(b2d, c2)])
		if still_empty and c2[0] == b2d[0]:
			degenerate.append("BucketBrigadeV2 (person with no bucket)")
		g._handle_tap(Vector2(8.0, 8.0))
		await _frames(3)
		var d2 := _snap(g)
		_check("[2c] a tap on empty background costs nothing",
			d2[0] == c2[0] and d2[2] == c2[2], _delta(c2, d2))
		# [6a]/[7] the sway clock, while a round is live and buckets exist.
		# get() first: on the pre-fix file the member does not exist at all, and
		# float(null) is a hard cast error that would take the whole run down.
		var anim_raw: Variant = g.get("_anim_t")
		var anim_t: float = 0.0 if anim_raw == null else float(anim_raw)
		_check("[6a] BucketBrigadeV2 sway clock is round-local, not app uptime",
			anim_raw != null and anim_t >= 0.0 and anim_t < 8.0,
			"_anim_t=%s after %.1fs of process uptime"
			% [("ABSENT" if anim_raw == null else "%.2fs" % anim_t),
				Time.get_ticks_msec() / 1000.0])
		var bucket: Node2D = null
		for i in range(int(g.get("BUCKET_POOL_SIZE"))):
			var bk: Node2D = g.bucket_pool.get_item(i)
			if bk.visible:
				bucket = bk
				break
		if bucket != null:
			var before: float = bucket.rotation
			get_tree().paused = true
			await _wait_real(0.52)
			var during: float = bucket.rotation
			get_tree().paused = false
			await _frames(2)
			var after: float = bucket.rotation
			# 0.52s of wall clock is 3.1 rad of a sin(t*6) sway: a resumed bucket would
			# snap to an unrelated tilt. One frame of round-local time is ~0.001 rad.
			_check("[7] bucket tilt does not snap across a 0.52s pause",
				absf(after - before) < 0.02,
				"before %.4f, during pause %.4f, after resume %.4f rad"
				% [before, during, after])
		else:
			_check("[7] bucket tilt does not snap across a 0.52s pause", false,
				"no visible bucket to sample")
	g.queue_free()
	await _frames(10)

	# ── [3] GreywaterSorterV2 (control: this one already has a miss path) ──────
	g = await _live(GAMES[2])
	var bk1: Node2D = null
	for _w in range(240):
		for i in range(int(g.get("BUCKET_POOL_SIZE"))):
			var b3: Node2D = g.bucket_pool.get_item(i)
			if b3.visible:
				bk1 = b3
				break
		if bk1 != null:
			break
		await get_tree().process_frame
	_check("[3] GreywaterSorterV2 round live with a bucket on screen",
		g.get("game_active") == true and bk1 != null)
	if bk1 != null:
		var a3 := _snap(g)
		# The bin the bucket belongs in: safe greywater to the garden, foul to the drain.
		g._sort_bucket(bk1, bool(bk1.get_meta("safe")))
		await _frames(3)
		var b3d := _snap(g)
		_check("[3a] sorting into the right bin is one correct action",
			b3d[0] == a3[0] + 1 and b3d[1] == a3[1] + 1, _delta(a3, b3d))
		# A pooled bucket is REUSED, so "a different node than bk1" is a test that can
		# never come true when the density cap keeps one bucket on screen: wait for bk1
		# to be released (the 0.28s exit tween ends in _release_bucket) and then take
		# whatever the pool hands out next, same object or not.
		var bk2: Node2D = null
		for _w in range(240):
			if not bk1.visible:
				break
			await get_tree().process_frame
		for _w in range(240):
			for i in range(int(g.get("BUCKET_POOL_SIZE"))):
				var b4: Node2D = g.bucket_pool.get_item(i)
				if b4.visible and not bool(b4.get_meta("being_sorted")):
					bk2 = b4
					break
			if bk2 != null:
				break
			await get_tree().process_frame
		if bk2 != null:
			g._sort_bucket(bk2, not bool(bk2.get_meta("safe")))
			await _frames(3)
			var c3 := _snap(g)
			_check("[3b] sorting into the WRONG bin is counted",
				c3[0] == b3d[0] + 1 and c3[2] == b3d[2] + 1, _delta(b3d, c3))
			if c3[0] == b3d[0]:
				degenerate.append("GreywaterSorterV2 (wrong bin)")
			g._shell_tap(Vector2(8.0, 8.0))
			await _frames(3)
			var d3 := _snap(g)
			_check("[3c] a grab that hits no bucket costs nothing",
				d3[0] == c3[0] and d3[2] == c3[2], _delta(c3, d3))
		else:
			_check("[3b] sorting into the WRONG bin is counted", false,
				"no second bucket spawned within 240 frames")
	g.queue_free()
	await _frames(10)

	# ── [4] CatchTheRainV2 (control: dirty water is already a miss) ────────────
	g = await _live(GAMES[3])
	var drop_idx: int = -1
	for _w in range(240):
		for i in range(int(g.get("DROP_POOL_SIZE"))):
			var dp: Node2D = g.drop_pool.get_item(i)
			if dp.visible:
				drop_idx = i
				break
		if drop_idx >= 0:
			break
		await get_tree().process_frame
	_check("[4] CatchTheRainV2 round live with a drop falling",
		g.get("game_active") == true and drop_idx >= 0)
	if drop_idx >= 0:
		var drop: Node2D = g.drop_pool.get_item(drop_idx)
		drop.set_meta("good", true)
		var a4 := _snap(g)
		g._on_caught(drop_idx, drop)
		await _frames(3)
		var b4d := _snap(g)
		_check("[4a] catching clean rain is one correct action",
			b4d[0] == a4[0] + 1 and b4d[1] == a4[1] + 1, _delta(a4, b4d))
		var idx2: int = -1
		for _w in range(240):
			for i in range(int(g.get("DROP_POOL_SIZE"))):
				var dp2: Node2D = g.drop_pool.get_item(i)
				if dp2.visible:
					idx2 = i
					break
			if idx2 >= 0:
				break
			await get_tree().process_frame
		if idx2 >= 0:
			var d2n: Node2D = g.drop_pool.get_item(idx2)
			d2n.set_meta("good", false)
			g._on_caught(idx2, d2n)
			await _frames(3)
			var c4 := _snap(g)
			_check("[4b] catching dirty water is counted",
				c4[0] == b4d[0] + 1 and c4[2] == b4d[2] + 1, _delta(b4d, c4))
			if c4[0] == b4d[0]:
				degenerate.append("CatchTheRainV2 (dirty water)")
			g._shell_tap(Vector2(8.0, 8.0))
			await _frames(3)
			var d4 := _snap(g)
			_check("[4c] a tap that catches nothing costs nothing",
				d4[0] == c4[0] and d4[2] == c4[2], _delta(c4, d4))
		else:
			_check("[4b] catching dirty water is counted", false,
				"no second drop spawned within 240 frames")
	g.queue_free()
	await _frames(10)

	# ── [6b] the other wall-clock animation site that was rewritten ────────────
	g = await _live(GAMES[0])
	await _wait_real(0.4)
	var drip_raw: Variant = g.get("_anim_t")
	var drip_t: float = 0.0 if drip_raw == null else float(drip_raw)
	_check("[6b] FixLeakV2 drip clock is round-local, not app uptime",
		drip_raw != null and drip_t >= 0.0 and drip_t < 8.0,
		"_anim_t=%s after %.1fs of process uptime"
		% [("ABSENT" if drip_raw == null else "%.2fs" % drip_t),
			Time.get_ticks_msec() / 1000.0])
	g.queue_free()
	await _frames(10)

	if degenerate.size() > 0:
		print("\n  DEGENERATE ACCURACY SIGNAL in %d game(s):" % degenerate.size())
		for d in degenerate:
			print("    - %s : the wrong action moves no counter, so A=1.00 and E=0.00" % d)

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
