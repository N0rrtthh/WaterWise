extends Node

## Reports the authored timing of every cartoon beat — hold length, the natural duration of the
## action it fires, the caption's reading rate — and then asserts the caption reading floor in
## CartoonStage._beat_hold() actually survives the worst compression the game can apply.
##
## The floor is checked by calling the shipping CartoonStage._beat_hold() on a real (unparented)
## stage instance, not by re-deriving the formula here: a harness that reimplements the rule
## would agree with a wrong implementation of it.
##
## Measured before the floor: captions ran to 47.3 chars/sec at speed 1.0, and CartoonStage
## divides every hold by speed_scale — 1.7x low-end times 3.0x reduced-motion is 5.1x — so the
## worst caption got 0.216s of screen time, about 241 chars/sec. Check [2] is the one that failed.
## Check [3] is the control: it re-runs [2] against the raw authored hold and requires that the
## old behaviour still fails, so a floor that silently stopped applying cannot pass this file.

const ACTION_SEC: Dictionary = {
	"hop": 0.62, "squash": 0.22, "shake": 0.55, "spin": 0.55, "panic": 0.75,
	"faint": 0.45, "cheer": 0.66, "splash": 0.55, "flash": 0.28,
	"fill_bucket": 0.70, "grow_puddle": 0.70, "wilt": 0.80,
	"look_up": 0.0, "look_side": 0.0,
	"rain": -1.0, "leak": -1.0, "stars": -1.0,
}

## Worst compression the shipping code asks for: MiniGameIntroBridge sets
## speed_scale = (1.7 if is_low_end else 1.0) * _motion_speed(), and _motion_speed() reaches 3.0.
const WORST_SPEED: float = 5.1

## The rate the floor must guarantee, in characters per second. Deliberately looser than
## CartoonStage.READ_CHARS_PER_SEC so the fixation allowance is not what makes this pass.
const CLAIM_CHARS_PER_SEC: float = 22.0

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
	await get_tree().process_frame
	var tree: SceneTree = get_tree()
	var keys := _keys()
	var over: Array[String] = []
	var slowest: Array = []
	var holds: Array[float] = []
	var caps: Array = []
	var flat: int = 0
	var clips: int = 0
	for key in keys:
		for kind in [CartoonStage.Kind.CAUSE, CartoonStage.Kind.EFFECT_WIN, CartoonStage.Kind.EFFECT_LOSE]:
			var clip: Dictionary = CartoonScenarios.get_scenario(key, kind)
			if clip.is_empty():
				continue
			clips += 1
			var beats: Array = clip.get("beats", [])
			var clip_holds: Array[float] = []
			for bv in beats:
				var b: Dictionary = bv
				var hold: float = float(b.get("hold", 0.9))
				var action: String = str(b.get("action", ""))
				var cap: String = str(b.get("caption", ""))
				holds.append(hold)
				clip_holds.append(hold)
				var need: float = float(ACTION_SEC.get(action, 0.0))
				if need > 0.0 and need > hold:
					over.append("%s/%d %s needs %.2fs, hold %.2fs" % [key, kind, action, need, hold])
				if cap.strip_edges().length() > 0:
					slowest.append([float(cap.length()) / maxf(hold, 0.01), cap.length(), hold, key, cap])
					caps.append([key, kind, b])
			if clip_holds.size() > 1:
				var same: bool = true
				for h in clip_holds:
					if absf(h - clip_holds[0]) > 0.001:
						same = false
				if same:
					flat += 1
	holds.sort()
	slowest.sort_custom(func(a, b): return a[0] > b[0])
	print("\n=== BeatTimingReport ===")
	print("  clips=%d  beats=%d  captioned beats=%d" % [clips, holds.size(), caps.size()])
	print("  hold min=%.2f  median=%.2f  max=%.2f" % [holds[0], holds[holds.size() / 2], holds[holds.size() - 1]])
	var counts: Dictionary = {}
	for h in holds:
		counts[h] = int(counts.get(h, 0)) + 1
	var uniq := counts.keys()
	uniq.sort()
	var line: String = ""
	for h in uniq:
		line += "%.2fx%d  " % [h, counts[h]]
	print("  hold histogram: %s" % line)
	print("  clips whose every beat holds for the same length: %d of %d" % [flat, clips])
	print("  beats whose action cannot finish inside the hold: %d" % over.size())
	for s in over:
		print("    ! %s" % s)
	print("  fastest captions as authored (chars/sec, length, hold):")
	for i in range(mini(5, slowest.size())):
		var r: Array = slowest[i]
		print("    %5.1f c/s  %3d chars in %.2fs  %s: \"%s\"" % [r[0], r[1], r[2], r[3], r[4]])

	# The shipping formula, on a real stage object. Never parented, so _ready() does not run and
	# no scene is built; _beat_hold() reads nothing but speed_scale and the beat dictionary.
	var stage: CartoonStage = CartoonStage.new()
	print("  reading floor: %.1f chars/sec + %.2fs fixation, capped at %.2fs; claim is %.1f chars/sec" % [
		CartoonStage.READ_CHARS_PER_SEC, CartoonStage.READ_FIXATION_SEC,
		CartoonStage.READ_FLOOR_MAX_SEC, CLAIM_CHARS_PER_SEC
	])
	print("=== claims ===")

	for speed in [1.0, WORST_SPEED]:
		stage.speed_scale = speed
		var worst_rate: float = 0.0
		var worst_desc: String = ""
		var bad: int = 0
		var lengthened: int = 0
		for c in caps:
			var b: Dictionary = c[2]
			var cap: String = str(b.get("caption", ""))
			var on_screen: float = stage._beat_hold(b) / speed
			var rate: float = float(cap.length()) / maxf(on_screen, 0.0001)
			if stage._beat_hold(b) > float(b.get("hold", 0.9)) + 0.0001:
				lengthened += 1
			if rate > CLAIM_CHARS_PER_SEC:
				bad += 1
			if rate > worst_rate:
				worst_rate = rate
				worst_desc = "%s: %d chars in %.3fs" % [c[0], cap.length(), on_screen]
		_check(bad == 0, "at speed %.1fx every caption reads at or under %.1f c/s" % [speed, CLAIM_CHARS_PER_SEC],
			"worst %.1f c/s (%s), over-budget beats=%d, floor lengthened %d of %d" % [
				worst_rate, worst_desc, bad, lengthened, caps.size()])

	# Control. Same measurement against the raw authored hold, which is what shipped before the
	# floor. It must still fail, otherwise checks [1] and [2] are passing for some other reason and
	# would keep passing if the floor were deleted.
	var raw_bad: int = 0
	var raw_worst: float = 0.0
	for c in caps:
		var b: Dictionary = c[2]
		var cap: String = str(b.get("caption", ""))
		var rate: float = float(cap.length()) / maxf(float(b.get("hold", 0.9)) / WORST_SPEED, 0.0001)
		if rate > CLAIM_CHARS_PER_SEC:
			raw_bad += 1
		raw_worst = maxf(raw_worst, rate)
	_check(raw_bad > 0, "control: without the floor, %.1fx compression breaks the claim" % WORST_SPEED,
		"%d of %d beats over budget, worst %.1f c/s" % [raw_bad, caps.size(), raw_worst])

	# A beat with no caption is pure staging. The floor must not touch it, at any speed.
	stage.speed_scale = WORST_SPEED
	var silent_moved: int = 0
	var silent_total: int = 0
	for key in keys:
		for kind in [CartoonStage.Kind.CAUSE, CartoonStage.Kind.EFFECT_WIN, CartoonStage.Kind.EFFECT_LOSE]:
			var clip: Dictionary = CartoonScenarios.get_scenario(key, kind)
			for bv in clip.get("beats", []):
				var b: Dictionary = bv
				if str(b.get("caption", "")).strip_edges().length() > 0:
					continue
				silent_total += 1
				if absf(stage._beat_hold(b) - float(b.get("hold", 0.9))) > 0.0001:
					silent_moved += 1
	_check(silent_moved == 0, "captionless beats keep their authored hold",
		"%d of %d uncaptioned beats changed" % [silent_moved, silent_total])

	# The floor is bounded, so no single caption can stall a clip. Longest possible hold is the cap
	# times the divisor it has to survive.
	var ceiling: float = CartoonStage.READ_FLOOR_MAX_SEC * WORST_SPEED
	var too_long: int = 0
	var longest: float = 0.0
	for c in caps:
		var h: float = stage._beat_hold(c[2])
		longest = maxf(longest, h)
		if h > ceiling + 0.0001:
			too_long += 1
	_check(too_long == 0, "no beat is inflated past the %.2fs bound" % ceiling,
		"longest hold %.2fs (%.2fs on screen at %.1fx)" % [longest, longest / WORST_SPEED, WORST_SPEED])


	# The cost of the floor, stated rather than hidden: how much longer the whole fallback tier runs
	# at normal speed now. The authored holds were written for comedic snap, not for reading, so the
	# floor is what makes the captions legible and this is what it costs.
	stage.speed_scale = 1.0
	var sum_authored: float = 0.0
	var sum_floored: float = 0.0
	for c in caps:
		sum_authored += float((c[2] as Dictionary).get("hold", 0.9))
		sum_floored += stage._beat_hold(c[2])
	print("  cost at 1.0x: all captioned beats total %.1fs authored, %.1fs with the floor (%.2fx)" % [
		sum_authored, sum_floored, sum_floored / maxf(sum_authored, 0.01)])
	stage.free()
	print("=== %d passed / %d failed ===" % [_pass, _fail])
	tree.quit(0 if _fail == 0 else 1)

func _keys() -> PackedStringArray:
	var keys := PackedStringArray()
	var dir := DirAccess.open("res://scenes/minigames")
	if dir == null:
		return keys
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			keys.append(f.trim_suffix(".tscn"))
		elif f.ends_with(".tscn.remap"):
			keys.append(f.trim_suffix(".tscn.remap"))
	return keys
