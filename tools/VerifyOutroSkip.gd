extends Node

## Does a SKIPPED authored beat clip still deliver its payoff, and do the fixed-length impact
## effects stay inside the beat they belong to when the clip is compressed?
##
## Two defect classes, both on the tier that actually ships (25/25 intros and 24/25 outros resolve
## to these authored scenes — tools/CutsceneTierReport.tscn):
##
##   SKIP  MicrogameOutroBase._try_skip() calls _timeline.custom_step(999.0), which fires the
##         remaining callbacks — payoff, snap, finish — inside ONE frame. The payoff tweens are
##         created and the scene is freed before they are ever stepped, so a player who taps
##         (the expected gesture in this genre) never sees the punchline. CartoonStage already
##         holds SKIP_PAYOFF_HOLD_SEC on skip for exactly this reason and says so in a comment:
##         "the payoff frame is always seen. Cause precedes effect even in the skipped path."
##         The authored tier had no such hold.
##
##   BLEED _impact_flash() (0.05 s rise + 0.14 s fall) and _camera_punch() (2 x 70 ms) are fixed
##         lengths, while the beats around them are divided by speed_scale (up to 5.1x: 1.7x
##         low-end times 3.0x reduced motion). At 5.1x the impact hold is 39 ms and the flash is
##         190 ms, so the payoff beat plays under a white wash with the camera still zoomed.
##
## Sampling: the windows being measured are tens of milliseconds, shorter than a frame. Engine
## time_scale is lowered so clip time stretches against frame time — the same technique, and the
## same reason, as tools/VerifyOutroImpact.gd. Tweens and tween_callbacks both obey time_scale and
## _elapsed accumulates scaled delta, so every number below stays in CLIP seconds.

const BEATS_DIR := "res://scenes/ui/cutscenes/beats"

## Win, lose and intro clips are separate code paths through the base (different _on_impact,
## different _beat_snap, different beat lengths), so all three are represented.
const SKIP_CLIPS: Array[String] = [
	"BucketBrigadeWinOutro.tscn", "ThirstyPlantLoseOutro.tscn",
	"CatchTheRainLoseOutro.tscn", "FilterBuilderIntro.tscn",
]
const BLEED_CLIPS: Array[String] = ["WaterMemoryWinOutro.tscn", "TurnOffTapIntro.tscn"]

## Worst compression the bridge asks for: (1.7 low-end) x (3.0 reduced motion).
const WORST_SPEED: float = 5.1

## A skipped clip must give the payoff at least this much screen time, and must still be gone
## well inside the second. Both bounds matter: the first is the fix, the second is the proof the
## fix did not simply ignore the tap.
const MIN_SKIP_PAYOFF_SEC: float = 0.30
const MAX_SKIP_TAIL_SEC: float = 1.20

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
	print("\n=== VerifyOutroSkip ===")
	print("  skip lockout %.2fs, worst compression %.1fx" % [MicrogameOutroBase.SKIP_LOCKOUT_SEC, WORST_SPEED])

	print("-- skip path (speed 1.0) --")
	for scene_name in SKIP_CLIPS:
		await _skip_one(scene_name)

	print("-- impact bleed at %.1fx --" % WORST_SPEED)
	for scene_name in BLEED_CLIPS:
		await _bleed_one(scene_name)

	print("=== %d passed / %d failed ===" % [_pass, _fail])
	tree.quit(0 if _fail == 0 else 1)

## Instantiates a clip, starts it, and returns it. Never returns null without reporting.
func _spawn(scene_name: String) -> Node:
	var packed: PackedScene = load(BEATS_DIR + "/" + scene_name)
	if packed == null:
		_check(false, "%s loads" % scene_name)
		return null
	var inst := packed.instantiate()
	add_child(inst)
	return inst

func _start(inst: Node) -> void:
	if inst.has_method("play_cause"):
		inst.call("play_cause")
	elif inst.name.contains("Lose"):
		inst.call("play_lose")
	else:
		inst.call("play_win")

## A real touch through the handler the player's finger reaches, not a direct _try_skip() call,
## so the input branch is covered too.
func _tap(inst: Node) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.index = 0
	inst.call("_gui_input", ev)

## Plays a clip, taps once the lockout has expired, and measures how much clip time the payoff
## actually got. Also records the flash peak before the tap as a control on the sensor.
func _skip_one(scene_name: String) -> void:
	Engine.time_scale = 0.2
	var inst := _spawn(scene_name)
	if inst == null:
		Engine.time_scale = 1.0
		return
	var done := [false, 0]
	inst.connect("outro_finished", func() -> void:
		done[0] = true
		done[1] = int(done[1]) + 1)
	_start(inst)
	var flash_peak: float = 0.0
	var real_start: float = Time.get_ticks_msec() / 1000.0
	# Wait out the lockout, watching the impact flash go by.
	while not done[0] and float(inst.get("_elapsed")) < MicrogameOutroBase.SKIP_LOCKOUT_SEC + 0.03:
		await get_tree().process_frame
		flash_peak = maxf(flash_peak, _flash_alpha(inst))
		if Time.get_ticks_msec() / 1000.0 - real_start > 20.0:
			break
	var t0: float = float(inst.get("_elapsed"))
	var finished_early: bool = done[0]
	_tap(inst)
	_tap(inst)  # a second tap must not queue a second finish
	while not done[0] and Time.get_ticks_msec() / 1000.0 - real_start < 30.0:
		await get_tree().process_frame
	var t1: float = float(inst.get("_elapsed"))
	var tail: float = t1 - t0
	var label: String = scene_name.trim_suffix(".tscn")
	_check(flash_peak >= 0.30, "%s: sensor sees the impact flash" % label,
		"peak alpha %.3f" % flash_peak)
	_check(not finished_early, "%s: still running when the lockout expires" % label,
		"tapped at %.2fs" % t0)
	_check(tail >= MIN_SKIP_PAYOFF_SEC, "%s: skip still shows the payoff" % label,
		"%.3fs of clip time between tap and finish (need %.2f)" % [tail, MIN_SKIP_PAYOFF_SEC])
	_check(tail <= MAX_SKIP_TAIL_SEC, "%s: skip still ends promptly" % label,
		"%.3fs tail (cap %.2f)" % [tail, MAX_SKIP_TAIL_SEC])
	_check(done[0] and int(done[1]) == 1, "%s: two taps emit outro_finished once" % label,
		"emits=%d" % int(done[1]))
	inst.queue_free()
	await get_tree().process_frame
	Engine.time_scale = 1.0

func _flash_alpha(inst: Node) -> float:
	var r = inst.get("flash_rect")
	if r == null or not is_instance_valid(r):
		return -1.0
	return (r as ColorRect).color.a

## Plays a clip at the worst compression and reads the flash and the camera at the exact frame the
## payoff beat opens. Both should already be back at rest: the impact is beat 2, the payoff is
## beat 3, and an effect that is still running has moved into a beat it does not belong to.
func _bleed_one(scene_name: String) -> void:
	Engine.time_scale = 0.1
	var inst := _spawn(scene_name)
	if inst == null:
		Engine.time_scale = 1.0
		return
	inst.set("speed_scale", WORST_SPEED)
	# The clip caps what it accepts (MicrogameOutroBase.speed_scale bounds compression at
	# _payoff_sec() / SKIP_PAYOFF_HOLD_SEC), so the beat boundary has to be derived from the speed the
	# clip ACTUALLY runs at. Dividing by the requested 5.1 would sample during the impact hold and
	# read a clear screen for the wrong reason.
	var speed: float = float(inst.get("speed_scale"))
	var done := [false]
	inst.connect("outro_finished", func() -> void: done[0] = true)
	_start(inst)
	var payoff_at: float = (float(inst.call("_setup_sec")) + float(inst.call("_impact_hold_sec"))) / speed
	var flash_peak: float = 0.0
	var flash_at_payoff: float = -1.0
	var zoom_at_payoff: float = -1.0
	var real_start: float = Time.get_ticks_msec() / 1000.0
	while not done[0] and Time.get_ticks_msec() / 1000.0 - real_start < 25.0:
		await get_tree().process_frame
		flash_peak = maxf(flash_peak, _flash_alpha(inst))
		if flash_at_payoff < 0.0 and float(inst.get("_elapsed")) >= payoff_at:
			flash_at_payoff = _flash_alpha(inst)
			var cam = inst.get("camera")
			zoom_at_payoff = (cam as Camera2D).zoom.x if is_instance_valid(cam) else -1.0
	var label: String = scene_name.trim_suffix(".tscn")
	_check(flash_peak >= 0.30, "%s: sensor sees the impact flash at %.1fx" % [label, speed],
		"peak alpha %.3f" % flash_peak)
	_check(flash_at_payoff >= 0.0, "%s: payoff frame was sampled" % label,
		"payoff opens at %.3fs of clip time (clip capped %.1fx of the %.1fx asked)" % [payoff_at, speed, WORST_SPEED])
	_check(flash_at_payoff >= 0.0 and flash_at_payoff <= 0.15,
		"%s: impact flash has cleared before the payoff" % label,
		"alpha %.3f at payoff (cap 0.15)" % flash_at_payoff)
	_check(zoom_at_payoff > 0.0 and absf(zoom_at_payoff - 1.0) <= 0.02,
		"%s: camera punch has settled before the payoff" % label,
		"zoom %.4f at payoff" % zoom_at_payoff)
	inst.queue_free()
	await get_tree().process_frame
	Engine.time_scale = 1.0
