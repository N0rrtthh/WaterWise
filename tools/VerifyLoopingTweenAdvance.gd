extends Node

## Does a looping Tween whose only tweener drives a property to a FIXED value keep
## moving after its first pass?
##
## InitialScreen's "spinner" crowd member is written as
##     create_tween().set_loops().tween_property(ch, "rotation", TAU, 2.5)
## which reads as "turn forever". A PropertyTweener with no from() captures the property
## when the tweener STARTS, and a looping Tween starts its tweeners again on every loop.
## If that re-capture happens, the second loop animates TAU -> TAU and the character
## stands still after one revolution. This file measures it rather than assuming it:
## case 0 is a synthetic pair (absolute vs as_relative) that establishes what the engine
## does, and case 1 checks the real crowd member in the real scene.

const HUB: String = "res://scenes/ui/InitialScreen.tscn"
const TIME_SCALE: float = 4.0

## Animation-time window for the "later" sample. The spin is 2.5 s per revolution, so a
## window that opens at 7.5 s covers revolutions 4 and 5 - long past the first pass.
const LATE_START: float = 7.5
const LATE_END: float = 12.5

## A revolution is TAU rad. An element still turning covers most of one per 2.5 s, so
## anything under a tenth of a turn across a 5 s window is standing still.
## The WringItOut LOSE outro spins the basin water with set_loops(3) x 0.55 s and each
## cyclone band with set_loops(4) x 0.4 s. Both first passes are over by 0.55 s, so a
## window opening at 0.75 s is entirely past them, and it closes well before the clip
## ends at 2.05 s.
const WRING_LOSE: String = "res://scenes/ui/cutscenes/beats/WringItOutLoseOutro.tscn"
const CLIP_LATE_START: float = 0.75
const CLIP_LATE_END: float = 1.50

const STILL_RAD: float = 0.6

var _pass: int = 0
var _fail: int = 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


## Wall-clock wait, so TIME_SCALE does not stretch the settle pauses.
func _secs(s: float) -> void:
	await _tree().create_timer(s, true, false, true).timeout


## Waits `s` seconds of ANIMATION time, which is what the tween durations are measured in.
func _anim_secs(s: float) -> void:
	await _tree().create_timer(s / TIME_SCALE, true, false, true).timeout


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("    PASS  %s" % label)
	else:
		_fail += 1
		print("    FAIL  %s" % label)
		if detail != "":
			print("          %s" % detail)


func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	await _frames(2)
	await _case_synthetic()
	await _case_in_scene()
	await _case_beat_clip()
	print("")
	print("════════════════════════════════════════")
	print("  %d passed, %d failed" % [_pass, _fail])
	print("════════════════════════════════════════")
	Engine.time_scale = 1.0
	await _frames(2)
	_tree().quit(0 if _fail == 0 else 1)


## Case 0: the engine's own behaviour, on two throwaway nodes.
##
## `fixed` uses the shape InitialScreen used; `relative` uses as_relative(), which adds
## its value to whatever the property is when the tweener starts instead of animating to
## an absolute. Both are sampled over the same two windows, so the difference between the
## two numbers is the whole finding.
func _case_synthetic() -> void:
	print("")
	print("── engine behaviour: one looping tweener, fixed target vs relative ──")
	var fixed := Node2D.new()
	var relative := Node2D.new()
	add_child(fixed)
	add_child(relative)

	var tw_fixed := create_tween().set_loops()
	tw_fixed.tween_property(fixed, "rotation", TAU, 2.5).set_trans(Tween.TRANS_LINEAR)
	var tw_rel := create_tween().set_loops()
	tw_rel.tween_property(relative, "rotation", TAU, 2.5).set_trans(
		Tween.TRANS_LINEAR
	).as_relative()

	await _anim_secs(LATE_START)
	var fixed_at_start: float = fixed.rotation
	var rel_at_start: float = relative.rotation
	await _anim_secs(LATE_END - LATE_START)
	var fixed_moved: float = absf(fixed.rotation - fixed_at_start)
	var rel_moved: float = absf(relative.rotation - rel_at_start)

	print("    over animation seconds %.1f -> %.1f (%.1f s, %.1f revolutions of runway)"
		% [LATE_START, LATE_END, LATE_END - LATE_START, (LATE_END - LATE_START) / 2.5])
	print("    fixed target:  %.3f -> %.3f rad, moved %.3f rad (%.2f turns)"
		% [fixed_at_start, fixed.rotation, fixed_moved, fixed_moved / TAU])
	print("    as_relative(): %.3f -> %.3f rad, moved %.3f rad (%.2f turns)"
		% [rel_at_start, relative.rotation, rel_moved, rel_moved / TAU])

	_check("as_relative() keeps turning on every loop",
		rel_moved > STILL_RAD,
		"moved only %.3f rad in %.1f s of animation" % [rel_moved, LATE_END - LATE_START])
	_check("a fixed-target looping tweener stops after its first pass",
		fixed_moved <= STILL_RAD,
		("it moved %.3f rad, so the engine does NOT re-capture the property on loop and"
			+ " the spinner finding below does not hold - re-read this file's premise.")
			% fixed_moved)
	# Kill the tweens before freeing their targets. Left running against a freed node
	# they complete each loop in zero time, which Godot reports as
	# "Infinite loop detected. Check set_loops() description for more info." - two of
	# them, once per synthetic tween, which is exactly what an earlier run of this file
	# printed just after case 0. Not a defect in the hub.
	tw_fixed.kill()
	tw_rel.kill()
	fixed.queue_free()
	relative.queue_free()


## Case 1: the real crowd member, in the real hub scene.
##
## Peachy carries trait "spinner" (InitialScreen.gd:111) and the trait string is what
## lands in the "role" meta (_build_droplet :962), so the spinner branch does run for her
## whenever she is in the roster.
func _case_in_scene() -> void:
	print("")
	print("── hub: the spinner crowd member ──")
	var hub: Node = load(HUB).instantiate()
	_tree().root.add_child(hub)
	await _frames(4)

	# The idle loops start after the entrance hands over, so wait for the flag rather
	# than guessing a duration.
	var waited: float = 0.0
	while not bool(hub.get("_crowd_idle_started")) and waited < 30.0:
		await _anim_secs(0.5)
		waited += 0.5
	_check("the hub reached its idle loops", bool(hub.get("_crowd_idle_started")),
		"still false after %.1f s of animation time" % waited)

	var spinner: Node2D = null
	var roles: Array = []
	for ch in (hub.get("_characters") as Array):
		if not is_instance_valid(ch):
			continue
		var role := str((ch as Node2D).get_meta("role", "idle"))
		roles.append(role)
		if role == "spinner" and spinner == null:
			spinner = ch
	print("    crowd roles: %s" % str(roles))
	_check("a spinner is present in the crowd", spinner != null,
		"no crowd member carries role \"spinner\", so this case proves nothing")
	if spinner == null:
		hub.queue_free()
		await _frames(2)
		return

	await _anim_secs(LATE_START)
	var at_start: float = spinner.rotation
	await _anim_secs(LATE_END - LATE_START)
	var moved: float = absf(spinner.rotation - at_start)
	print("    spinner rotation over animation seconds %.1f -> %.1f: %.3f -> %.3f rad"
		% [LATE_START, LATE_END, at_start, spinner.rotation])
	_check("the spinner is still turning after its first revolution",
		moved > STILL_RAD,
		("it moved %.3f rad (%.2f turns) in %.1f s of animation - two full revolutions of"
			+ " runway. The character stands frozen mid-crowd after the first 2.5 s.")
			% [moved, moved / TAU, LATE_END - LATE_START])

	hub.queue_free()
	await _frames(2)


## Case 2: the same shape inside an authored beat clip, on the SHIPPED outcome path.
##
## Case 1's crowd member is decoration on the hub. This one plays whenever a player loses
## WringItOut: _beat_setup() spins the basin water and each cyclone band with a single
## fixed-target rotation tweener under set_loops(3) / set_loops(4). If the re-capture case
## 0 measures applies here too, the funnel stops turning at exactly the moment the
## eruption is supposed to peak - the one frame the whole clip is built around.
func _case_beat_clip() -> void:
	print("")
	print("── case 2: WringItOut LOSE outro — basin water + cyclone band ──")
	var packed: PackedScene = load(WRING_LOSE)
	_check("the lose outro scene loads", packed != null, WRING_LOSE)
	if packed == null:
		return
	var clip := packed.instantiate()
	add_child(clip)
	clip.call("play_lose")
	await _frames(3)

	var basin = clip.get("basin")
	var cyclone = clip.get("cyclone")
	var water: Node2D = null
	if basin != null:
		water = basin.get_node_or_null("Water") as Node2D
	var band: Node2D = null
	if cyclone != null and cyclone.get_child_count() > 0:
		band = cyclone.get_child(0) as Node2D
	_check("the basin water node is reachable", water != null,
		"_beat_setup() spins basin/Water; without that node this case proves nothing")
	_check("a cyclone band was built", band != null,
		"_beat_setup() adds three bands under Cyclone; none were found")
	if water == null or band == null:
		clip.queue_free()
		await _frames(2)
		return

	await _anim_secs(CLIP_LATE_START)
	var w0: float = water.rotation
	var b0: float = band.rotation
	await _anim_secs(CLIP_LATE_END - CLIP_LATE_START)
	var w_moved: float = absf(water.rotation - w0)
	var b_moved: float = absf(band.rotation - b0)
	print("    animation seconds %.2f -> %.2f" % [CLIP_LATE_START, CLIP_LATE_END])
	print("    basin water  %.3f -> %.3f rad  (moved %.3f)"
		% [w0, water.rotation, w_moved])
	print("    cyclone band %.3f -> %.3f rad  (moved %.3f)"
		% [b0, band.rotation, b_moved])
	_check("the basin water keeps spinning past its first revolution",
		w_moved > STILL_RAD,
		("it moved %.3f rad (%.2f turns) across %.2f s of animation. set_loops(3) reads as"
			+ " three revolutions; the water stops after one.")
			% [w_moved, w_moved / TAU, CLIP_LATE_END - CLIP_LATE_START])
	_check("the cyclone band keeps spinning past its first revolution",
		b_moved > STILL_RAD,
		("it moved %.3f rad (%.2f turns) across %.2f s of animation. set_loops(4) reads as"
			+ " four revolutions; the funnel freezes after one.")
			% [b_moved, b_moved / TAU, CLIP_LATE_END - CLIP_LATE_START])

	clip.queue_free()
	await _frames(2)
