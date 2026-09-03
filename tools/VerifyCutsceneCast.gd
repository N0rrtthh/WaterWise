extends Node

## Does the recurring cast arrive the way the clip asked for it?
##
## CastFactory.make_townsfolk() clamps its count to 3..5. All 75 authored clip scripts stage the
## crowd through exactly one literal call each, and what they ask for is:
##
##   39 x _stage_townsfolk(2)  -> 3 delivered
##   29 x _stage_townsfolk(3)  -> 3
##    6 x _stage_townsfolk(4)  -> 4
##    2 x _stage_townsfolk(5)  -> 5
##    3 x make_townsfolk(1)[0] -> 3 built, 1 staged, 2 never parented
##
## Two defect classes come out of that one lower bound:
##
##   COUNT   39 clips get a body they did not ask for. Positions come from
##           lerpf(left_x, right_x, i / (n - 1)) across a span the author picked for two, so the
##           uninvited blob lands between them and halves the spacing.
##
##   ORPHAN  CartoonActor extends Node2D, so it is NOT reference-counted. The two unused actors
##           from make_townsfolk(1) are parented by nobody and freed by nobody - they sit in
##           ObjectDB until the process exits. RainwaterHarvesting's intro is on the reachable
##           tier (25/25 intros resolve to these scenes), so this leaks on a real play.
##
## The requested count is read out of each clip's own source instead of being tabulated here, so
## the claim cannot drift away from what the clips actually ask for. MicrogameOutroBase already
## carries an "if n == 1" guard in _stage_townsfolk() - unreachable while the clamp floor is 3 -
## which is the base author's own statement that a crowd of one was meant to be possible.

const BEATS_DIR := "res://scenes/ui/cutscenes/beats"
const SCRIPTS_DIR := "res://scripts/cutscenes/beats"

var _pass: int = 0
var _fail: int = 0
var _rx_crowd: RegEx = RegEx.create_from_string("_stage_townsfolk[(] *([0-9]+)")
var _rx_single: RegEx = RegEx.create_from_string("make_townsfolk[(] *([0-9]+)")

func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [ok]   %s%s" % [label, "" if detail.is_empty() else "  " + detail])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [label, "" if detail.is_empty() else "  " + detail])

func _ready() -> void:
	await get_tree().process_frame
	print("\n=== VerifyCutsceneCast ===")

	# CLAIM 1 - the factory honours the count it is handed. A request the factory silently rounds up
	# is a request the clip author cannot express, and every consequence below follows from it.
	print("-- CastFactory.make_townsfolk() contract --")
	for want in [1, 2, 3, 4, 5]:
		var crowd: Array[CartoonActor] = CastFactory.make_townsfolk(want)
		var got: int = crowd.size()
		_check(got == want, "asked for %d townsfolk" % want, "got %d" % got)
		for a in crowd:
			a.free()
	# The upper bound is real and documented (3-5 palette swaps exist); it should still clamp.
	var over: Array[CartoonActor] = CastFactory.make_townsfolk(9)
	_check(over.size() == 5, "a request above the palette clamps to 5", "got %d" % over.size())
	for a in over:
		a.free()
	var under: Array[CartoonActor] = CastFactory.make_townsfolk(0)
	_check(under.size() >= 1, "a request of zero still yields a usable crowd", "got %d" % under.size())
	for a in under:
		a.free()

	print("-- per-clip staging (75 clips) --")
	var names: Array[String] = _clip_names()
	_check(names.size() == 75, "all authored clips found", "%d scenes" % names.size())
	var count_bad: Array[String] = []
	var orphan_bad: Array[String] = []
	var total_staged: int = 0
	var min_gap: float = INF
	var min_gap_clip: String = ""
	var widest: float = 0.0
	var occluded: int = 0
	var occluded_clips: Array[String] = []
	var overlap_clips: int = 0
	for scene_name in names:
		var r: Dictionary = await _measure_clip(scene_name)
		if r.is_empty():
			continue
		total_staged += int(r["delivered"])
		widest = maxf(widest, float(r["half_width"]))
		if int(r["requested"]) != int(r["delivered"]):
			count_bad.append("%s %d->%d" % [scene_name, int(r["requested"]), int(r["delivered"])])
		if int(r["orphans"]) != 0:
			orphan_bad.append("%s +%d" % [scene_name, int(r["orphans"])])
		if int(r["occluded"]) > 0:
			occluded += int(r["occluded"])
			occluded_clips.append(scene_name)
		if float(r["gap"]) < 0.0:
			overlap_clips += 1
		if float(r["gap"]) < min_gap:
			min_gap = float(r["gap"])
			min_gap_clip = scene_name

	# Anti-vacuous guards: a sensor that staged nobody, or that measured a zero-width silhouette,
	# would report "no overlaps" for the wrong reason.
	_check(total_staged >= 150, "the sensor actually staged a crowd", "%d townsfolk over %d clips" % [total_staged, names.size()])
	_check(widest > 10.0, "the sensor actually measured a silhouette", "widest half-width %.1f px" % widest)

	_check(count_bad.is_empty(), "every clip gets the crowd size it asked for",
		"%d clips differ%s" % [count_bad.size(), "" if count_bad.is_empty() else ": " + ", ".join(count_bad.slice(0, 4)) + (" ..." if count_bad.size() > 4 else "")])
	_check(orphan_bad.is_empty(), "no clip leaves an unparented actor behind",
		"%d clips leak%s" % [orphan_bad.size(), "" if orphan_bad.is_empty() else ": " + ", ".join(orphan_bad)])
	# Partial overlap in a background crowd is authored huddling, not a defect: the tightest spans in
	# the tree are things like _stage_townsfolk(2, _vp.x * 0.03, _vp.x * 0.09) - 6% of the width for
	# two bodies 15% wide each - and the palette swaps keep them readable as separate shapes. What IS
	# a defect is a body drawn entirely inside another's silhouette: invisible, with a whole 36-node
	# rig built and paid for. Tightest clearance is reported either way so the huddling stays on
	# record rather than being asserted away.
	_check(occluded == 0, "no townsperson is drawn entirely behind another",
		"%d fully hidden%s" % [occluded, "" if occluded_clips.is_empty() else " in " + ", ".join(occluded_clips.slice(0, 4))])
	print("  [info] tightest neighbour clearance %.1f px in %s; %d of %d clips huddle (any overlap)" % [min_gap, min_gap_clip, overlap_clips, names.size()])

	print("=== %d passed / %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func _clip_names() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(BEATS_DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".tscn"):
			out.append(f)
	out.sort()
	return out

## Reads the count the clip's own source asks for. Returns -1 when the clip stages no crowd,
## which no authored clip currently does - if that changes the caller reports it rather than
## silently skipping the clip.
func _requested_count(scene_name: String) -> int:
	var path: String = "%s/%s.gd" % [SCRIPTS_DIR, scene_name.trim_suffix(".tscn")]
	if not FileAccess.file_exists(path):
		_check(false, "%s: script found next to the scene" % scene_name, path)
		return -1
	var src: String = FileAccess.get_file_as_string(path)
	var m: RegExMatch = _rx_crowd.search(src)
	if m != null:
		return int(m.get_string(1))
	m = _rx_single.search(src)
	if m != null:
		return int(m.get_string(1))
	return -1

## Stages one clip, reads its crowd, and books the orphan cost. _run() stages synchronously
## (_ensure_built -> _setup_stage -> _run_timeline, no await between them) so the cast is on
## screen the moment play_* returns; the frame wait is only so global transforms settle.
func _measure_clip(scene_name: String) -> Dictionary:
	var requested: int = _requested_count(scene_name)
	if requested < 0:
		_check(false, "%s: stages a crowd" % scene_name, "no literal count found in its source")
		return {}
	# Warm the resource cache BEFORE the baseline, so first-load allocations are not booked as leaks.
	var packed: PackedScene = load("%s/%s" % [BEATS_DIR, scene_name])
	if packed == null:
		_check(false, "%s: loads" % scene_name)
		return {}
	await get_tree().process_frame
	var base_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var inst := packed.instantiate()
	add_child(inst)
	if inst.has_method("play_cause"):
		inst.call("play_cause")
	elif scene_name.contains("Lose"):
		inst.call("play_lose")
	else:
		inst.call("play_win")
	await get_tree().process_frame
	var crowd: Array = inst.get("townsfolk") if inst.get("townsfolk") != null else []
	var delivered: int = crowd.size()
	var actors: Array = crowd.duplicate()
	if delivered == 0:
		var partner = inst.get("partner")
		if partner != null and is_instance_valid(partner):
			delivered = 1
			actors.append(partner)
	var spans: Array = []
	var half_width: float = 0.0
	for a in actors:
		var s: Vector2 = _silhouette_span(a)
		if s.y > s.x:
			spans.append(s)
			half_width = maxf(half_width, (s.y - s.x) * 0.5)
	var gap: float = _tightest_gap(spans)
	var hidden: int = _fully_hidden(spans)
	inst.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - base_orphans
	return {
		"requested": requested, "delivered": delivered, "orphans": maxi(orphans, 0),
		"gap": gap, "half_width": half_width, "occluded": hidden,
	}

## On-screen x extent of one actor's silhouette, taken from the body polygon through its own
## global transform so every ancestor scale (content scale, ACTOR_SCALE, per-clip scale, squash)
## is included rather than assumed. Returns (min_x, max_x); (0, 0) when the rig is not built.
func _silhouette_span(a) -> Vector2:
	if a == null or not is_instance_valid(a):
		return Vector2.ZERO
	var actor := a as CartoonActor
	if actor == null or actor.body == null or not is_instance_valid(actor.body):
		return Vector2.ZERO
	var pts: PackedVector2Array = actor.body.polygon
	if pts.is_empty():
		return Vector2.ZERO
	var xf: Transform2D = actor.body.get_global_transform()
	var lo: float = INF
	var hi: float = -INF
	for p in pts:
		var g: Vector2 = xf * p
		lo = minf(lo, g.x)
		hi = maxf(hi, g.x)
	return Vector2(lo, hi)

## Tightest clearance between neighbouring silhouettes. Negative means they overlap. INF when
## fewer than two bodies are on screen, which the caller treats as "nothing to compare".
func _tightest_gap(spans: Array) -> float:
	if spans.size() < 2:
		return INF
	var sorted: Array = spans.duplicate()
	sorted.sort_custom(func(u: Vector2, v: Vector2) -> bool: return u.x < v.x)
	var tightest: float = INF
	for i in range(sorted.size() - 1):
		var cur: Vector2 = sorted[i]
		var nxt: Vector2 = sorted[i + 1]
		tightest = minf(tightest, nxt.x - cur.y)
	return tightest

## How many bodies sit entirely inside another body's horizontal span. Equal-width actors can only
## reach this by being placed within a pixel or two of each other, which is why it is a real
## defect rather than a matter of taste: the hidden one contributes nothing a player can see.
func _fully_hidden(spans: Array) -> int:
	var n: int = 0
	for i in range(spans.size()):
		var a: Vector2 = spans[i]
		for j in range(spans.size()):
			if i == j:
				continue
			var b: Vector2 = spans[j]
			if b.x <= a.x and b.y >= a.y:
				n += 1
				break
	return n
