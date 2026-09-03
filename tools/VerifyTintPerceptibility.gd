extends Node

## Measures what ThemeManager's full-screen tint actually contributes to the
## final image, in 8-bit channel levels, so the decision about whether it is
## worth a full-screen alpha blend rests on pixels rather than on an opinion.
##
## Method: render the same scene twice, once with the tint layer visible and
## once hidden, capture the real framebuffer both times, and diff them
## pixel-by-pixel. Both themes are measured, because light mode is a 6% wash
## and dark mode is an 18% one and they are not the same question.
##
## WHY TIME IS FROZEN FOR THE CAPTURE
##   The first version of this probe diffed two frames six frames apart and
##   reported a 115/255 max delta for a 6% wash. That is arithmetically
##   impossible - an alpha-0.06 blend cannot move a channel by more than
##   ~15 levels - and the excess was MainMenu animating: two scrolling wave
##   shaders and a bobbing character moved between the two captures, so the
##   diff was mostly animation. Engine.time_scale = 0 freezes both the
##   script/tween side (delta becomes 0) and shader TIME, which Godot 4
##   scales with time_scale, so the ONLY difference left between the two
##   frames is the thing being toggled.
##
## THE CONTROL
##   Before measuring anything, two frames are captured with NOTHING changed
##   between them. If that delta is not ~0 the scene is still moving and every
##   number below it is worthless, so the probe says so and fails instead of
##   reporting.
##
## The capture is taken after RenderingServer.frame_post_draw, which is the only
## point at which the viewport texture holds a finished frame; reading it earlier
## returns the previous frame or an empty image and would silently compare a
## frame against itself.
##
## Usage (WINDOWED - a headless run has no framebuffer to read):
##   godot --path . res://tools/VerifyTintPerceptibility.tscn

const SCENE: String = "res://scenes/ui/MainMenu.tscn"
const WARMUP_FRAMES: int = 40

var _pass: int = 0
var _fail: int = 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s%s" % [label, "" if detail.is_empty() else "   (%s)" % detail])
	else:
		_fail += 1
		print("  FAIL  %s%s" % [label, "" if detail.is_empty() else "   (%s)" % detail])


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var tex := _tree().root.get_texture()
	if tex == null:
		return null
	return tex.get_image()


## Max and mean absolute per-channel difference between two frames, in 0-255
## levels. Sampled on a grid rather than every pixel: 2.1M pixels through
## GDScript would take minutes, and a 4-pixel stride cannot miss a FULL-SCREEN
## uniform wash, which is the only thing being measured.
func _diff(a: Image, b: Image) -> Dictionary:
	var w: int = mini(a.get_width(), b.get_width())
	var h: int = mini(a.get_height(), b.get_height())
	var max_d: float = 0.0
	var sum_d: float = 0.0
	var n: int = 0
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d: float = maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b))
			max_d = maxf(max_d, d)
			sum_d += d
			n += 1
			x += 4
		y += 4
	return {
		"max": max_d * 255.0,
		"mean": (sum_d / float(maxi(n, 1))) * 255.0,
		"samples": n,
	}


## Two captures with nothing changed between them. Any nonzero result means
## the scene is still animating and no tint measurement taken here can be
## trusted; this is checked before the real measurements, not after.
func _control_diff() -> Dictionary:
	var first := await _grab()
	await _frames(6)
	var second := await _grab()
	if first == null or second == null:
		return {}
	return _diff(first, second)


func _measure_mode(rect: ColorRect, label: String) -> Dictionary:
	rect.visible = true
	await _frames(6)
	var on_img := await _grab()
	rect.visible = false
	await _frames(6)
	var off_img := await _grab()
	rect.visible = true
	await _frames(2)
	if on_img == null or off_img == null:
		print("  %s: capture failed (no viewport texture)" % label)
		return {}
	var d := _diff(on_img, off_img)
	print("  %-6s tint a=%.2f -> max delta %5.1f/255   mean delta %5.2f/255   (%d samples)"
		% [label, rect.color.a, d["max"], d["mean"], d["samples"]])
	return d


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== TINT PERCEPTIBILITY - MEASURED IN 8-BIT CHANNEL LEVELS ===")
	if DisplayServer.get_name() == "headless":
		print("  REFUSING: no framebuffer to read under the dummy driver.")
		_tree().quit(2)
		return

	var tm := get_node_or_null("/root/ThemeManager")
	var gm := get_node_or_null("/root/GameManager")
	if tm == null or gm == null:
		print("  FAIL: ThemeManager/GameManager unavailable")
		_tree().quit(1)
		return
	var rect: ColorRect = tm.get("_theme_tint_rect")
	if rect == null:
		print("  FAIL: no tint rect")
		_tree().quit(1)
		return

	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	_tree().root.add_child(inst)
	await _frames(WARMUP_FRAMES)

	# Snapshot the player's real theme so this probe does not leave the save in
	# whatever mode it measured last.
	var orig_dark: bool = bool(gm.dark_mode_enabled)

	# Let the tint tween settle FIRST, then freeze. Freezing before the tween
	# finishes would park the tint at an intermediate alpha and measure that.
	tm.set_dark_mode(false)
	await _frames(30)  # let _apply_theme_tint's 0.25s tween finish
	Engine.time_scale = 0.0
	await _frames(3)
	var control: Dictionary = await _control_diff()
	if control.is_empty():
		_check("control capture succeeded", false, "no viewport texture")
	else:
		_check("control: two identical frames differ by nothing",
			float(control["max"]) < 1.0,
			"max %.1f levels with nothing toggled" % control["max"])
	var light := await _measure_mode(rect, "LIGHT")

	# Time must run for the 0.25s tween to reach the dark alpha, then freeze again.
	Engine.time_scale = 1.0
	tm.set_dark_mode(true)
	await _frames(30)
	Engine.time_scale = 0.0
	await _frames(3)
	var dark := await _measure_mode(rect, "DARK")

	Engine.time_scale = 1.0
	tm.set_dark_mode(orig_dark)
	await _frames(20)

	print("")
	if light.is_empty() or dark.is_empty():
		_check("both modes captured", false, "capture failure")
	else:
		# Bounds derived from the blend itself, not fitted to the output: an
		# alpha-a source over ANY background can move a channel by at most
		# a*255 levels, plus one level of slack because the blended and the
		# unblended value are each quantised to 8 bits independently and can
		# round in opposite directions. Light a=0.06 -> 15.3+1, dark a=0.18 ->
		# 45.9+1. Asserting against arithmetic rather than against the numbers
		# just printed is what makes this a check instead of an echo - and it is
		# exactly what caught the first version of this probe, which reported 115
		# levels for the 0.06 wash because it was diffing animation, not the tint.
		_check("light wash stays within the 0.06 blend ceiling (15.3+1 levels)",
			float(light["max"]) <= 17.0,
			"max %.1f levels" % light["max"])
		_check("dark wash stays within the 0.18 blend ceiling (45.9+1 levels)",
			float(dark["max"]) <= 47.0,
			"max %.1f levels" % dark["max"])
		# The decision this probe exists to inform is whether the full-screen
		# blend buys anything visible. It does, in BOTH modes, so the assertion
		# is on perceptibility rather than on which mode wins.
		#
		# The original assertion here was "dark contributes more than light", on
		# the assumption that triple the alpha means a bigger change. Measurement
		# says otherwise (dark mean 10.89 vs light 11.76) and the arithmetic
		# explains why: contribution is alpha * |tint - background|, and the dark
		# tint (0.30,0.45,0.68) sits much closer to MainMenu background
		# (0.23,0.32,0.46) than the cream light tint (1.0,0.97,0.88) does. The
		# larger alpha is multiplying a much smaller colour distance.
		_check("light wash is perceptible (mean above the 2-3 level JND)",
			float(light["mean"]) > 3.0,
			"mean %.2f levels" % light["mean"])
		_check("dark wash is perceptible (mean above the 2-3 level JND)",
			float(dark["mean"]) > 3.0,
			"mean %.2f levels" % dark["mean"])
		print("")
		print("  MEAN contribution: light %.2f levels, dark %.2f levels per pixel"
			% [light["mean"], dark["mean"]])
		print("  Both cost the SAME full-screen alpha blend to draw, and both are")
		print("  well above the visible-difference floor, so the blend is buying a")
		print("  real visual, not overdraw for nothing.")

	inst.queue_free()
	await _frames(4)
	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	_tree().quit(1 if _fail > 0 else 0)
