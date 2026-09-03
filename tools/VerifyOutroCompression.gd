extends Node

## Does a compressed clip play the same animation, faster - or does it just get cut off?
##
## MiniGameIntroBridge and MiniGameBase both hand the authored beat clips a speed_scale of up to
## 5.1x (1.7x low-end device times 3.0x reduced motion), and the bridge's own comment states the
## intent: the cause clip "plays compressed rather than being cut, because the cause clip is the
## educational payload of the loop".
##
## MicrogameOutroBase divides its four beat intervals by speed_scale, so the TIMELINE compresses.
## The animation inside the beats does not: the 75 authored clip scripts contain 1159
## tween_property/tween_interval calls and not one of them mentions speed_scale. A 0.26s card
## flight still takes 0.26s inside a beat that has shrunk to 0.08s, so the scene is freed with the
## card mid-air. That is being cut, not compressed.
##
## Sensor: how many seconds of authored animation the clip actually plays. Every Tween that appears
## while the clip runs is collected (a Tween is RefCounted, so holding it keeps its final reading
## legible after it stops) and its get_total_elapsed_time() is summed at outro_finished. A tween's
## elapsed time advances by delta times its own speed_scale, and delta is already scaled by
## Engine.time_scale, so every number below is in AUTHORED seconds regardless of how fast the
## clip or the engine is running. Compression must change the clip's duration, not its content:
## the sum at 5.1x must match the sum at 1.0x.
##
## Infinite idle loops need no special handling - they help. An idle loop scaled with the clip
## accumulates (clip duration x speed_scale) = the same authored seconds either way, and an
## unscaled one accumulates only the shortened wall time, which shows up as part of the deficit.
##
## Engine.time_scale is lowered in both runs so that no tween can start and finish between two
## sample frames; the compressed run is slowed harder because its tweens are shorter.

const BEATS_DIR := "res://scenes/ui/cutscenes/beats"

## Deterministic clips only (12 of the 100 beat scripts use randf/randi/pick_random, and a random
## clip cannot be compared against itself across two runs). These three are the densest such
## clips: 16, 14 and 14 tween sites. Lose, win and intro are separate paths through the base.
const CLIPS: Array[String] = [
	"TimingTapLoseOutro.tscn", "ToiletTankFixWinOutro.tscn", "FilterBuilderIntro.tscn",
]

## Worst compression the bridge asks for: (1.7 low-end) x (3.0 reduced motion).
const WORST_SPEED: float = 5.1

## How far the compressed run's authored-animation total may fall from the 1.0x run's.
const TOLERANCE: float = 0.15

## A sensor that reads zero in both runs would "agree" and pass vacuously. Every sampled clip has
## to show at least this much authored animation at 1.0x for its comparison to mean anything.
const MIN_SENSED_SEC: float = 2.0

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
	print("\n=== VerifyOutroCompression ===")
	print("  authored animation seconds played, 1.0x vs %.1fx, tolerance %.0f%%" % [WORST_SPEED, TOLERANCE * 100.0])
	var totals: Dictionary = {}
	for scene_name in CLIPS:
		var slow: Dictionary = await _play_and_measure(scene_name, 1.0, 0.25)
		var fast: Dictionary = await _play_and_measure(scene_name, WORST_SPEED, 0.05)
		totals[scene_name] = [slow, fast]
	print("-- per clip --")
	for scene_name in CLIPS:
		var label: String = scene_name.trim_suffix(".tscn")
		var slow: Dictionary = totals[scene_name][0]
		var fast: Dictionary = totals[scene_name][1]
		var a: float = float(slow.get("anim_sec", 0.0))
		var b: float = float(fast.get("anim_sec", 0.0))
		print("  %-24s 1.0x: %5.2fs anim over %5.2fs clip, %d tweens (%d unfinished)" % [
			label, a, float(slow.get("clip_sec", 0.0)), int(slow.get("tweens", 0)), int(slow.get("unfinished", 0))])
		print("  %-24s %.1fx (ran %.1fx): %5.2fs anim over %5.2fs clip, %d tweens (%d unfinished)" % [
			"", WORST_SPEED, float(fast.get("speed", 0.0)), b, float(fast.get("clip_sec", 0.0)), int(fast.get("tweens", 0)), int(fast.get("unfinished", 0))])
	print("=== claims ===")
	for scene_name in CLIPS:
		var label: String = scene_name.trim_suffix(".tscn")
		var slow: Dictionary = totals[scene_name][0]
		var fast: Dictionary = totals[scene_name][1]
		var a: float = float(slow.get("anim_sec", 0.0))
		var b: float = float(fast.get("anim_sec", 0.0))
		_check(a >= MIN_SENSED_SEC, "%s: sensor sees the clip's animation at 1.0x" % label,
			"%.2fs authored animation across %d tweens (floor %.1f)" % [a, int(slow.get("tweens", 0)), MIN_SENSED_SEC])
		var kept: float = (b / a) if a > 0.0 else 0.0
		_check(a > 0.0 and absf(b - a) <= a * TOLERANCE,
			"%s: %.1fx compression keeps the animation" % [label, WORST_SPEED],
			"%.2fs of %.2fs authored seconds survive (%.0f%%, need %.0f%%)" % [b, a, kept * 100.0, (1.0 - TOLERANCE) * 100.0])
		_check(int(fast.get("unfinished", 0)) <= int(slow.get("unfinished", 0)) + 1,
			"%s: %.1fx leaves no extra animation in flight" % [label, WORST_SPEED],
			"%d unfinished at %.1fx vs %d at 1.0x" % [int(fast.get("unfinished", 0)), WORST_SPEED, int(slow.get("unfinished", 0))])
		var payoff_window: float = float(fast.get("clip_sec", 0.0)) - float(fast.get("payoff_at", 0.0))
		_check(payoff_window >= MicrogameOutroBase.SKIP_PAYOFF_HOLD_SEC,
			"%s: the payoff frame survives the compression" % label,
			"%.3fs on screen from payoff to finish at %.1fx (floor %.2f, the project's own perceptual minimum)"
				% [payoff_window, float(fast.get("speed", 0.0)), MicrogameOutroBase.SKIP_PAYOFF_HOLD_SEC])
	print("=== %d passed / %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

## Plays one clip at one speed and returns how much authored animation it managed to play.
##
## The baseline snapshot is what makes the reading the CLIP's: tweens already being stepped when
## the clip is spawned (autoloads own a few) are excluded by instance id, and everything that
## appears afterwards is collected. Sampling happens every frame because a Tween that has finished
## is no longer in get_processed_tweens() - miss it and its seconds are lost from the total.
func _play_and_measure(scene_name: String, speed: float, time_scale: float) -> Dictionary:
	var baseline: Dictionary = {}
	for t in get_tree().get_processed_tweens():
		baseline[t.get_instance_id()] = true
	var packed: PackedScene = load(BEATS_DIR + "/" + scene_name)
	if packed == null:
		_check(false, "%s loads" % scene_name)
		return {}
	var inst := packed.instantiate()
	add_child(inst)
	inst.set("speed_scale", speed)
	Engine.time_scale = time_scale
	var done := [false]
	inst.connect("outro_finished", func() -> void: done[0] = true)
	if inst.has_method("play_cause"):
		inst.call("play_cause")
	elif inst.name.contains("Lose"):
		inst.call("play_lose")
	else:
		inst.call("play_win")
	var seen: Dictionary = {}
	var real_start: float = Time.get_ticks_msec() / 1000.0
	while not done[0] and Time.get_ticks_msec() / 1000.0 - real_start < 40.0:
		await get_tree().process_frame
		_collect(baseline, seen)
	_collect(baseline, seen)
	var anim_sec: float = 0.0
	var unfinished: int = 0
	var live: Dictionary = {}
	for t in get_tree().get_processed_tweens():
		live[t.get_instance_id()] = true
	for id in seen:
		var t: Tween = seen[id]
		anim_sec += t.get_total_elapsed_time()
		if live.has(id):
			unfinished += 1
	var clip_sec: float = float(inst.get("_elapsed"))
	var payoff_at: float = float(inst.get("_payoff_at"))
	var effective: float = float(inst.get("speed_scale"))
	inst.queue_free()
	Engine.time_scale = 1.0
	await get_tree().process_frame
	return {
		"anim_sec": anim_sec, "clip_sec": clip_sec, "tweens": seen.size(),
		"unfinished": unfinished, "payoff_at": payoff_at, "speed": effective,
	}

func _collect(baseline: Dictionary, seen: Dictionary) -> void:
	for t in get_tree().get_processed_tweens():
		var id: int = t.get_instance_id()
		if not baseline.has(id) and not seen.has(id):
			seen[id] = t
