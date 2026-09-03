extends Node

## Does a viewport resize survive the ambient animations that are always running?
##
## Both idle screens re-layout on `size_changed`: InitialScreen._on_viewport_resized()
## (:377) calls _layout_characters_for_viewport(), and MainMenu._on_viewport_resized()
## (:504) calls _place_main_character_in_view(). Both write `position` directly. But
## these screens are never NOT animating - the hub's hero, crowd, boat and clouds all
## carry create_tween().set_loops() tweens that own `position:x` / `position:y` and
## drive them toward absolute targets captured ONCE, from the pre-resize viewport
## (InitialScreen.gd:1501-1502, :1240-1248, :566-585, :511-535; MainMenu.gd:266).
##
## A running Tween writes its property every frame. So the layout handler's write is
## overwritten on the next frame by a tween interpolating toward a stale coordinate.
## The handler is not wrong - it is simply outranked, and the element ends up where it
## belonged before the resize. The boat and the clouds are not even re-placed: nothing
## in the resize path touches them.
##
## HOW THIS MEASURES IT, without baking in the authored ratios
##
## Each element is sampled as a FRACTION of the viewport, at two window sizes with
## different aspect ratios (stretch is canvas_items/expand, so the canvas rect really
## does change shape - project.godot:51-52). An element that tracked the resize keeps
## its fraction; an element the tween pinned keeps its PIXEL value instead and the
## fraction moves. That is the whole test, and it cannot be satisfied by guessing a
## constant wrong.
##
## Because the elements are mid-animation while being sampled, each sample runs a full
## loop cycle and takes the midpoint of the extremes, which cancels a symmetric
## oscillation. The cycle lengths are read off the tweens in the source: hero bounce
## 1.05+0.38+1.05+0.38, hero sway 1.10+1.06+0.72, boat bob 2.2+2.2, boat drift 6.0+6.0,
## cloud bob 1.4*speed, cloud drift 4*speed with speeds of 12/8/15/10 - so 60 s is the
## longest, and SAMPLE_SECS covers it by running the sample at Engine.time_scale.
##
## NON-VACUITY. "The fraction is preserved" is free if nothing moves, free if the resize
## never reached the viewport, and free on an axis the resize did not change. So the
## last case asserts the sweep changed the canvas on BOTH axes, and the first asserts
## every probed element is actually animating before any resize happens. The crowd's X
## is the anti-degeneracy control: it is integrated in _process() against bounds the
## resize handler updates (:196-203, :280-281), so no tween owns it and it should track
## correctly BEFORE the fix as well as after. If that control fails, the harness is
## broken, not the game.

const HUB: String = "res://scenes/ui/InitialScreen.tscn"
const MENU: String = "res://scenes/ui/MainMenu.tscn"
## Three window sizes, because canvas_items/expand only ever grows ONE axis: the canvas
## stays 1920x1080 (project.godot:48-49) and expands on whichever axis the window is
## longer than the base aspect. A is the 16:9 baseline, B is taller so the canvas grows
## vertically, C is wider so it grows horizontally. Resizing once - which is all the
## first version of this file did - leaves the other axis at 1920 and turns every
## horizontal assertion into a comparison of a number with itself.
const SIZE_A: Vector2i = Vector2i(1280, 720)   # 16:9  -> canvas 1920x1080
const SIZE_B: Vector2i = Vector2i(1280, 1024)  # 5:4   -> canvas 1920x1536
const SIZE_C: Vector2i = Vector2i(1600, 640)   # 2.5:1 -> canvas 2700x1080

## In seconds of ANIMATION time, run at TIME_SCALE, so the window covers the slowest
## ambient loop in either screen: the clouds drift for 4 x speed with speeds up to 15
## (InitialScreen.gd:511-522), i.e. 60 s per cycle. A midpoint taken over less than a
## full cycle is a function of the phase the sample started in, not of the layout.
const SAMPLE_SECS: float = 62.0
const TIME_SCALE: float = 8.0
## An element is allowed to end up this share of its required travel away from where it
## should be. 15% leaves room for the sampled midpoint being a frame or two off the true
## centre of an oscillation, while still catching a miss: an element a tween pinned in
## place is 100% of its travel away from where it belonged.
const TRAVEL_TOL: float = 0.15

## Floor on the allowance, and also the threshold below which an axis is not asserted at
## all. A few pixels of required travel says nothing about whether the layout tracked.
const PIX_FLOOR: float = 6.0

var _passed: int = 0
var _failed: int = 0
var _seen_rects: Array[Vector2] = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _secs(s: float) -> void:
	await _tree().create_timer(s, true, false, true).timeout


func _check(label: String, ok: bool, why: String = "") -> void:
	if ok:
		_passed += 1
		print("    PASS  %s" % label)
	else:
		_failed += 1
		print("    FAIL  %s" % label)
		if why != "":
			print("          %s" % why)


## Resize and let the content-scale machinery settle. Same shape as
## tools/VerifyAspectSupply.gd:117-125, which established that this pair of calls is
## what actually moves the canvas rect under the headless driver.
func _force_size(size: Vector2i) -> Vector2:
	DisplayServer.window_set_size(size)
	get_window().size = size
	await _frames(6)
	var rect: Vector2 = get_viewport().get_visible_rect().size
	if not _seen_rects.has(rect):
		_seen_rects.append(rect)
	return rect


func _boot(path: String) -> Node:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	_tree().root.add_child(inst)
	_tree().current_scene = inst
	# Long enough for the entrance sequence to hand off to the ambient loops: the hub
	# reaches _start_idle_loops() through an idle_delay tween callback (:1211), and the
	# hero's showtime tweens only exist after that.
	await _frames(4)
	await _secs(3.0)
	return inst


func _kill(inst: Node) -> void:
	if inst != null and is_instance_valid(inst):
		inst.queue_free()
	await _frames(4)


## One pass over a full ambient cycle, sampling every probe every frame.
##
## `probes` maps a label to a Callable returning the position under test. The midpoint
## of the extremes is what the assertions use: these are symmetric oscillations, so the
## midpoint is the layout anchor with the animation subtracted out. min/max are kept so
## a failure can say whether the element was pinned or merely displaced.
func _sample(probes: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var elapsed: float = 0.0
	while elapsed < SAMPLE_SECS:
		for label in probes.keys():
			var pos = (probes[label] as Callable).call()
			if pos == null:
				continue
			var v: Vector2 = pos
			if not out.has(label):
				out[label] = {"min": v, "max": v}
			else:
				var rec: Dictionary = out[label]
				rec["min"] = Vector2(minf(rec["min"].x, v.x), minf(rec["min"].y, v.y))
				rec["max"] = Vector2(maxf(rec["max"].x, v.x), maxf(rec["max"].y, v.y))
		await _tree().process_frame
		elapsed += _tree().root.get_process_delta_time()
	for label in out.keys():
		var rec: Dictionary = out[label]
		rec["mid"] = (rec["min"] + rec["max"]) * 0.5
	return out
## The comparison every case funnels through.
##
## Tracking the resize means keeping your FRACTION of the canvas; being pinned by a
## tween means keeping your PIXEL value instead. So the test is: given where the element
## sat before, where should it sit now, and how far off is it?
##
## The tolerance is a share of the distance the element had to travel, not a flat
## fraction of the canvas. A flat fraction is wrong for anything near an edge: cloud2
## sits at y = 0.04 of the canvas, so being completely pinned across a 1080 -> 1536
## resize moves its fraction by only 0.0119 and a 0.015 tolerance called that a PASS in
## an earlier run of this file - the cloud had not moved a pixel. Measuring the error
## against the required travel gives the same verdict everywhere on the screen.
func _axis(
	label: String, axis: String,
	mid_a: float, dim_a: float,
	mid_b: float, dim_b: float
) -> void:
	var frac_a: float = mid_a / dim_a
	var frac_b: float = mid_b / dim_b
	var want_b: float = frac_a * dim_b
	var travel: float = absf(want_b - mid_a)
	var err: float = absf(mid_b - want_b)
	var allow: float = maxf(PIX_FLOOR, TRAVEL_TOL * travel)
	if travel < PIX_FLOOR * 2.0:
		# Nothing worth asserting: the element barely had to move, so passing or
		# failing here would say more about the tolerance than about the game.
		print("    ---   %s %s: only %.1f px of travel required, not asserted"
			% [label, axis, travel])
		return
	_check("%s keeps its %s place across the resize" % [label, axis],
		err <= allow,
		("should have moved %.1f -> %.1f px (%.1f px of travel, canvas %.0f -> %.0f)"
			+ " but sat at %.1f - off by %.1f px, %.0f%% of the travel it owed."
			+ " Fraction %.4f -> %.4f.")
			% [mid_a, want_b, travel, dim_a, dim_b, mid_b, err,
				100.0 * err / maxf(travel, 0.001), frac_a, frac_b])
func _compare(
	label: String,
	a: Dictionary, vp_a: Vector2,
	b: Dictionary, vp_b: Vector2,
	axes: String = "xy"
) -> void:
	if a.is_empty() or b.is_empty():
		_check("%s was sampled at both sizes" % label, false,
			"no samples collected - the probe returned null, so nothing about this"
			+ " element was measured")
		return
	var mid_a: Vector2 = a["mid"]
	var mid_b: Vector2 = b["mid"]
	if axes.contains("x"):
		_axis(label, "horizontal", mid_a.x, vp_a.x, mid_b.x, vp_b.x)
	if axes.contains("y"):
		_axis(label, "vertical", mid_a.y, vp_a.y, mid_b.y, vp_b.y)


func _node_pos(n) -> Variant:
	if n == null or not is_instance_valid(n):
		return null
	return (n as Node2D).position


## Probes for the hub's four families of ambient motion. Two crowd members and two
## clouds rather than all of them: the loops are built from the same code path per
## element, so a third of each would restate the same finding.
func _hub_probes(g: Node) -> Dictionary:
	var probes: Dictionary = {}
	probes["hero"] = func() -> Variant: return _node_pos(g.get("_main_character"))
	probes["boat"] = func() -> Variant: return _node_pos(g.get("_boat_node"))
	var clouds = g.get("_cloud_nodes")
	if clouds is Array:
		for i in [0, 2]:
			if i < (clouds as Array).size():
				probes["cloud%d" % i] = func() -> Variant:
					var arr = g.get("_cloud_nodes")
					if arr is Array and i < (arr as Array).size():
						return _node_pos((arr as Array)[i])
					return null
	var chars = g.get("_characters")
	if chars is Array:
		for i in [0, 1]:
			if i < (chars as Array).size():
				probes["crowd%d" % i] = func() -> Variant:
					var arr = g.get("_characters")
					if arr is Array and i < (arr as Array).size():
						return _node_pos((arr as Array)[i])
					return null
	return probes


## The boat only exists if the decoration is switched on in the save, so switch it on -
## otherwise _spawn_decorations() returns early (:538-547) and the boat's three loop
## tweens would go unmeasured while the case still reported green.
func _enable_boat() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	if sm.has_method("unlock_decoration"):
		sm.call("unlock_decoration", "boat")
	if sm.has_method("toggle_decoration"):
		sm.call("toggle_decoration", "boat", true)


## Case 1. Is anything actually moving? Every "kept its place" assertion below is
## satisfied for free by a static screen, so this runs first and fails loudly if the
## ambient loops never started.
func _assert_animating(probes: Dictionary) -> void:
	var first: Dictionary = {}
	var moved: Array[String] = []
	var still: Array[String] = []
	for _i in range(90):
		for label in probes.keys():
			var pos = (probes[label] as Callable).call()
			if pos == null:
				continue
			var v: Vector2 = pos
			if not first.has(label):
				first[label] = v
			elif v.distance_to(first[label]) > 0.5 and not moved.has(label):
				moved.append(label)
		await _tree().process_frame
	for label in probes.keys():
		if not moved.has(label):
			still.append(label)
	print("    moving: %s" % str(moved))
	_check("the ambient animations are running before any resize",
		still.is_empty(),
		("these never moved across 90 frames: %s - a resize cannot be shown to"
			+ " disturb an animation that is not playing") % str(still))


func _case_hub() -> void:
	print("")
	print("── hub (InitialScreen): resize while the ambient loops run ──")
	_enable_boat()
	var vp_a: Vector2 = await _force_size(SIZE_A)
	var g: Node = await _boot(HUB)
	if g == null:
		_check("InitialScreen instantiated", false, "load() returned null")
		return

	var probes: Dictionary = _hub_probes(g)
	print("    probes: %s   canvas %s" % [str(probes.keys()), str(vp_a)])
	_check("the hub exposed a hero, a boat, clouds and crowd members to sample",
		probes.has("hero") and probes.has("boat")
			and probes.has("cloud0") and probes.has("crowd0"),
		"missing probes: %s" % str(probes.keys()))

	await _assert_animating(probes)

	# Three samples, because expand only ever grows one axis: A is the baseline, B is
	# taller (tests the vertical layout), C is wider (tests the horizontal).
	var sample_a: Dictionary = await _sample(probes)
	var vp_b: Vector2 = await _force_size(SIZE_B)
	await _secs(1.0)
	var sample_b: Dictionary = await _sample(probes)
	var vp_c: Vector2 = await _force_size(SIZE_C)
	await _secs(1.0)
	var sample_c: Dictionary = await _sample(probes)

	print("    canvas %s -> %s (taller) and -> %s (wider)"
		% [str(vp_a), str(vp_b), str(vp_c)])
	for key in ["hero", "boat", "cloud0", "cloud2"]:
		if not probes.has(key):
			continue
		_compare(key, sample_a.get(key, {}), vp_a, sample_b.get(key, {}), vp_b, "y")
		_compare(key, sample_a.get(key, {}), vp_a, sample_c.get(key, {}), vp_c, "x")
	# Crowd: vertical only. X is integrated by _process() as a walk across the whole
	# platform, so its midpoint is the middle of the walk and carries no layout claim -
	# it is asserted against the new bounds instead, just below.
	for key in ["crowd0", "crowd1"]:
		if probes.has(key):
			_compare(key, sample_a.get(key, {}), vp_a, sample_b.get(key, {}), vp_b, "y")

	_assert_crowd_within_bounds(g, sample_c)
	await _kill(g)


## The anti-degeneracy control.
##
## The crowd's horizontal walk is integrated in _process() (:193-203) against
## _crowd_left_bound / _crowd_right_bound, and the resize handler updates those bounds
## (:280-281). No tween owns position:x, so this axis is expected to follow the resize
## correctly whether or not the rest of this file is fixed. It is here so that a run
## where everything fails is distinguishable from a run where the probe itself is
## broken.
func _assert_crowd_within_bounds(g: Node, sample_b: Dictionary) -> void:
	var left: float = float(g.get("_crowd_left_bound"))
	var right: float = float(g.get("_crowd_right_bound"))
	var outside: Array[String] = []
	for key in ["crowd0", "crowd1"]:
		if not sample_b.has(key):
			continue
		var rec: Dictionary = sample_b[key]
		if rec["min"].x < left - 1.0 or rec["max"].x > right + 1.0:
			outside.append("%s x in [%.1f, %.1f]" % [key, rec["min"].x, rec["max"].x])
	print("    post-resize walk bounds: [%.1f, %.1f]" % [left, right])
	_check("CONTROL: the crowd's walk stays inside the post-resize bounds",
		outside.is_empty() and right > left,
		("out of bounds: %s (bounds [%.1f, %.1f]) - this axis has no tween on it, so a"
			+ " failure here means the harness is wrong, not the game")
			% [str(outside), left, right])


func _case_menu() -> void:
	print("")
	print("── MainMenu: resize while the character loop runs ──")
	var vp_a: Vector2 = await _force_size(SIZE_A)
	var g: Node = await _boot(MENU)
	if g == null:
		_check("MainMenu instantiated", false, "load() returned null")
		return
	var probes: Dictionary = {}
	probes["the menu character"] = func() -> Variant: return _node_pos(g.get("character"))
	_check("MainMenu exposed its character node",
		(probes["the menu character"] as Callable).call() != null,
		"`character` was null, so nothing about MainMenu was measured")
	await _assert_animating(probes)
	var key: String = "the menu character"
	var sample_a: Dictionary = await _sample(probes)
	var vp_b: Vector2 = await _force_size(SIZE_B)
	await _secs(1.0)
	var sample_b: Dictionary = await _sample(probes)
	var vp_c: Vector2 = await _force_size(SIZE_C)
	await _secs(1.0)
	var sample_c: Dictionary = await _sample(probes)
	print("    canvas %s -> %s (taller) and -> %s (wider)"
		% [str(vp_a), str(vp_b), str(vp_c)])
	_compare(key, sample_a.get(key, {}), vp_a, sample_b.get(key, {}), vp_b, "y")
	_compare(key, sample_a.get(key, {}), vp_a, sample_c.get(key, {}), vp_c, "x")
	await _kill(g)


## Case 0, reported last because it needs the resizes to have happened.
##
## Under canvas_items/expand only ONE axis ever leaves the base size: the canvas keeps
## 1920x1080 and grows on whichever axis the window is longer. So a single resize can
## only test one axis, and the first version of this file - which resized once, taller -
## reported four horizontal PASSes that had never been exercised: the canvas was 1920


## Case 2: repeated resizes must not stack tweens.
##
## The rebase kills and restarts the position loops, so the count has to come back to the
## same number every time. This is the failure mode that made the hero's body loops worth
## splitting out of _start_main_character_showtime(): re-running that whole function on
## each resize would leave a second arm, leg and sparkle loop behind every time, and two
## tweens writing one rotation_degrees give a stuttering limb, not a blended motion.
func _case_no_tween_accumulation() -> void:
	print("")
	print("── hub: six resizes in a row must not stack tweens ──")
	var hub: Node = load(HUB).instantiate()
	_tree().root.add_child(hub)
	await _force_size(SIZE_A)
	await _secs(1.0)
	# Wait for the idle loops, so the crowd and hero bobs are in the count.
	var waited: float = 0.0
	while not bool(hub.get("_crowd_idle_started")) and waited < 30.0:
		await _secs(0.4)
		waited += 0.4
	_check("the hub reached its idle loops", bool(hub.get("_crowd_idle_started")),
		"still false after %.1f s" % waited)

	var counts: Array = []
	for i in range(6):
		await _force_size(SIZE_B if i % 2 == 0 else SIZE_C)
		await _secs(0.35)
		counts.append([
			(hub.get("_ambient_tweens") as Array).size(),
			(hub.get("_tweens") as Array).size(),
		])
	print("    [ambient, total] after each resize: %s" % str(counts))
	var ambient_stable: bool = true
	var pool_stable: bool = true
	for c in counts:
		if c[0] != counts[0][0]:
			ambient_stable = false
		if c[1] != counts[0][1]:
			pool_stable = false
	_check("the ambient registry holds the same number of tweens after every resize",
		ambient_stable,
		"counts drifted: %s - a rebase is leaving tweens behind" % str(counts))
	_check("the one-shot pool does not grow with resizes", pool_stable,
		("counts drifted: %s - something layout-independent is being restarted and"
			+ " re-registered on each resize") % str(counts))
	hub.queue_free()
	await _frames(2)
## wide both times. Two resizes are needed, and this asserts both of them landed.
func _report_probe_validity() -> void:
	print("")
	print("── was the resize real? ──")
	print("    distinct canvas rects observed: %d  %s" % [_seen_rects.size(), str(_seen_rects)])
	var widths: Array[float] = []
	var heights: Array[float] = []
	for r in _seen_rects:
		if not widths.has(r.x):
			widths.append(r.x)
		if not heights.has(r.y):
			heights.append(r.y)
	_check("the sweep changed the canvas HEIGHT, so the vertical checks were real",
		heights.size() >= 2,
		("every rect was %s tall - the vertical assertions above were all taken at one"
			+ " height and prove nothing") % str(heights))
	_check("the sweep changed the canvas WIDTH, so the horizontal checks were real",
		widths.size() >= 2,
		("every rect was %s wide - the horizontal assertions above were all taken at one"
			+ " width and prove nothing") % str(widths))


func _summarise() -> void:
	print("")
	print("════════════════════════════════════════")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("════════════════════════════════════════")
	_tree().quit(1 if _failed > 0 else 0)


func _ready() -> void:
	print("")
	print("════════════════════════════════════════")
	print("  RESIZE DURING ANIMATION")
	print("════════════════════════════════════════")
	# The clouds' drift loops run for up to 4 x speed = 60 seconds per cycle
	# (InitialScreen.gd:511-522, speeds 12/8/15/10). Sampling less than a full cycle
	# would make the midpoint of the extremes a function of WHERE IN THE PHASE the
	# sample happened to start, which is how the first version of this file reported
	# cloud0 as broken and cloud2 as fine in the same run - a phase artifact, not a
	# finding. Tweens obey Engine.time_scale, so the cycles are run at 8x instead of
	# the sample window being shortened. _secs() passes ignore_time_scale, so the
	# settle waits below stay in wall-clock seconds.
	Engine.time_scale = TIME_SCALE
	print("  sampling at %.0fx time scale: %.1f s of animation per sample window"
		% [TIME_SCALE, SAMPLE_SECS])
	await _frames(2)
	await _case_hub()
	await _case_menu()
	await _case_no_tween_accumulation()
	_report_probe_validity()
	_summarise()
