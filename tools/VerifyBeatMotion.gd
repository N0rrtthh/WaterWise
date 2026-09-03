extends Node

## Is there actually MOTION in each authored beat, or does a clip put its animation in the wrong
## beat and leave the punchline standing still?
##
## All 75 clips override _beat_setup(), _on_impact() and _beat_payoff() with real bodies (checked
## statically), but that only proves code runs at those callbacks. A clip can create every tween in
## its setup beat with a long tween_interval in front, or hang its payoff on a tween that already
## finished, and the 1.20 s payoff beat - the punchline, the longest beat in the clip - is then dead
## air with a non-empty function behind it.
##
## So this measures the frame, not the code: every Node2D under the clip's world node is walked each
## frame and its position, rotation, scale and alpha summed into a signature. The absolute change in
## that signature between frames is attributed to whichever beat the clip's own _elapsed clock is in.
## An authored beat with no motion in it fails regardless of how the motion was authored - tween,
## tween chain, direct property write in _process, anything.
##
## The impact flash and the camera punch are deliberately invisible to this sensor: the flash is a
## ColorRect (a Control, not a Node2D) and the punch moves the Camera2D rather than the world, so
## what is measured is the CAST and the PROPS, not the base class's effects stack.

const BEATS_DIR := "res://scenes/ui/cutscenes/beats"

## Float noise floor. A still frame accumulates exact zeros here (nothing is being tweened), so
## anything above this is real movement.
const MOTION_EPS: float = 0.5

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
	print("\n=== VerifyBeatMotion ===")
	var names: Array[String] = []
	var d := DirAccess.open(BEATS_DIR)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".tscn"):
				names.append(f)
	names.sort()
	_check(names.size() == 75, "all authored clips found", "%d scenes" % names.size())

	var dead_setup: Array[String] = []
	var dead_payoff: Array[String] = []
	var worst_payoff: float = 1.0e20
	var worst_payoff_name: String = ""
	var total_motion: float = 0.0
	var measured: int = 0
	for scene_name in names:
		var m: Dictionary = await _measure(scene_name)
		if m.is_empty():
			continue
		measured += 1
		total_motion += float(m["all"])
		if float(m["setup"]) <= MOTION_EPS:
			dead_setup.append(scene_name.trim_suffix(".tscn"))
		if float(m["payoff"]) <= MOTION_EPS:
			dead_payoff.append(scene_name.trim_suffix(".tscn"))
		if float(m["payoff"]) < worst_payoff:
			worst_payoff = float(m["payoff"])
			worst_payoff_name = scene_name.trim_suffix(".tscn")
	_check(measured == names.size(), "every clip played to its finish", "%d of %d measured" % [measured, names.size()])
	_check(total_motion > 0.0, "the sensor actually sees motion", "%.0f px summed over %d clips" % [total_motion, measured])
	_check(dead_setup.is_empty(), "every clip moves during its setup beat",
		"still: %s" % ("none" if dead_setup.is_empty() else ", ".join(dead_setup)))
	_check(dead_payoff.is_empty(), "every clip moves during its payoff beat",
		"still: %s" % ("none" if dead_payoff.is_empty() else ", ".join(dead_payoff)))
	print("  [info] least animated payoff: %s at %.1f px of accumulated movement" % [worst_payoff_name, worst_payoff])
	print("=== %d passed / %d failed ===" % [_pass, _fail])
	print("RESULT passed=%d failed=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

## Sums position, rotation, scale and alpha of every Node2D under the clip into one number. Cheap,
## order-stable (the tree is walked depth-first and the tree does not reorder mid-clip), and
## sensitive to any authored movement of the cast or the props.
func _signature(n: Node) -> float:
	var s: float = 0.0
	var n2 := n as Node2D
	if n2 != null:
		s += n2.position.x + n2.position.y * 3.0 + n2.rotation * 57.0
		s += n2.scale.x * 11.0 + n2.scale.y * 13.0 + n2.modulate.a * 7.0
	for c in n.get_children():
		s += _signature(c)
	return s

## Plays one clip at its authored speed and returns the accumulated per-beat movement, or {} if the
## clip never finished. Beat boundaries come from the clip's own accessors rather than constants, so
## intro clips (shorter beats) are measured against their own timeline.
func _measure(scene_name: String) -> Dictionary:
	var packed: PackedScene = load(BEATS_DIR + "/" + scene_name)
	if packed == null:
		_check(false, "%s loads" % scene_name)
		return {}
	var inst := packed.instantiate()
	add_child(inst)
	var done := [false]
	inst.connect("outro_finished", func() -> void: done[0] = true)
	if inst.has_method("play_cause"):
		inst.call("play_cause")
	elif scene_name.contains("Lose"):
		inst.call("play_lose")
	else:
		inst.call("play_win")
	var world = inst.get("world")
	var t_setup: float = float(inst.call("_setup_sec"))
	var t_impact: float = t_setup + float(inst.call("_impact_hold_sec"))
	var t_payoff: float = t_impact + float(inst.call("_payoff_sec"))
	var acc := {"setup": 0.0, "impact": 0.0, "payoff": 0.0, "snap": 0.0, "all": 0.0}
	var prev: float = _signature(world) if is_instance_valid(world) else 0.0
	var real_start: float = Time.get_ticks_msec() / 1000.0
	while not done[0] and Time.get_ticks_msec() / 1000.0 - real_start < 20.0:
		await get_tree().process_frame
		if not is_instance_valid(world):
			break
		var cur: float = _signature(world)
		var delta: float = absf(cur - prev)
		prev = cur
		var t: float = float(inst.get("_elapsed"))
		var key: String = "snap"
		if t < t_setup:
			key = "setup"
		elif t < t_impact:
			key = "impact"
		elif t < t_payoff:
			key = "payoff"
		acc[key] = float(acc[key]) + delta
		acc["all"] = float(acc["all"]) + delta
	var finished: bool = done[0]
	inst.queue_free()
	await get_tree().process_frame
	return acc if finished else {}
