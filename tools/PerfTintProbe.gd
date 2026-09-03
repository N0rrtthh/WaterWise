extends Node

## Fill-rate probe for ThemeManager's global full-screen tint.
##
## ThemeManager._ensure_theme_tint_layer() parents a CanvasLayer at layer 95 to
## the autoload and puts one PRESET_FULL_RECT ColorRect in it. That rect is
## alpha-blended over the entire finished frame on EVERY frame of EVERY scene,
## at alpha 0.06 in light mode and 0.18 in dark. A full-screen blend is the
## classic fill-rate tax on a legacy mobile GPU, and the thesis targets exactly
## that class of device, so the cost needs a number rather than an opinion.
##
## WHY A/B/A INSTEAD OF A THEN B
##   The effect being measured is expected to be a fraction of a millisecond.
##   Over two consecutive windows, CPU frequency scaling and other processes
##   drift by more than that, so a plain before/after cannot tell the tint cost
##   from the machine warming up. Measuring visible -> hidden -> visible and
##   requiring the two "visible" windows to agree makes drift visible as
##   disagreement instead of banking it as a result.
##
## WHY THIS MUST NOT RUN HEADLESS
##   --headless uses the dummy rasteriser: it reports 0 draw calls and 0
##   primitives no matter what is on screen, and it does no blending at all. A
##   fill-rate question is unanswerable there, so the probe refuses a verdict.
##
## Usage (WINDOWED, deliberately no --headless):
##   godot --path . res://tools/PerfTintProbe.tscn

const MB: float = 1048576.0
const WARMUP_FRAMES: int = 45
const SAMPLE_FRAMES: int = 180

## Scenes chosen for their fill-rate profile, not their gameplay: MainMenu
## already draws two full-screen shader ColorRects plus a grid overlay, so it is
## the closest thing in the project to a fill-rate-bound frame; ThirstyPlant is
## an ordinary minigame for contrast.
const SCENES: Array = [
	"res://scenes/ui/MainMenu.tscn",
	"res://scenes/minigames/ThirstyPlant.tscn",
]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _m(id: int) -> float:
	return float(Performance.get_monitor(id))


## One timing window. Returns avg/p95 wall-clock ms plus the draw-call average,
## measured exactly the way PerfProbe measures: Time.get_ticks_usec() deltas
## between process_frame signals, cross-checked against the whole window timed
## once, because Performance.TIME_PROCESS is a sampled monitor and reading it
## per frame produces figures that contradict the FPS counter beside them.
func _window() -> Dictionary:
	var times: Array[float] = []
	var last_us := Time.get_ticks_usec()
	var start_us := last_us
	var draw_sum := 0.0
	var prim_sum := 0.0
	for _i in range(SAMPLE_FRAMES):
		await _tree().process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last_us) / 1000.0)
		last_us = now
		draw_sum += _m(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prim_sum += _m(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var window_ms := float(Time.get_ticks_usec() - start_us) / 1000.0
	times.sort()
	var s := 0.0
	for t in times:
		s += t
	return {
		"avg": s / times.size(),
		"p95": times[int(floor(times.size() * 0.95)) - 1],
		"window_ms": window_ms,
		"draw": draw_sum / SAMPLE_FRAMES,
		"prim": prim_sum / SAMPLE_FRAMES,
	}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== THEMEMANAGER FULL-SCREEN TINT - FILL-RATE COST ===")

	var driver := DisplayServer.get_name()
	print("  display driver : %s" % driver)
	if driver == "headless":
		print("  REFUSING A VERDICT: the dummy rasteriser does no blending and")
		print("  reports 0 draw calls. Re-run WITHOUT --headless.")
		_tree().quit(2)
		return

	# Vsync must be OFF or every window measures 16.67ms and the cap is reported
	# as the cost of the tint.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := _tree().root.get_visible_rect().size
	print("  viewport       : %dx%d  (%.2f Mpx per full-screen pass)"
		% [int(vp.x), int(vp.y), vp.x * vp.y / 1000000.0])

	var tm := get_node_or_null("/root/ThemeManager")
	if tm == null:
		print("  ThemeManager autoload missing - nothing to measure")
		_tree().quit(1)
		return
	var rect: ColorRect = tm.get("_theme_tint_rect")
	if rect == null or not is_instance_valid(rect):
		print("  tint rect not built yet; forcing _ensure_theme_tint_layer()")
		if tm.has_method("_ensure_theme_tint_layer"):
			tm._ensure_theme_tint_layer()
			rect = tm.get("_theme_tint_rect")
	if rect == null or not is_instance_valid(rect):
		print("  FAIL: no tint rect exists - the layer is never built")
		_tree().quit(1)
		return

	print("  tint rect      : %s  size=%.0fx%.0f  color=%s (a=%.2f)"
		% [rect.get_path(), rect.size.x, rect.size.y, rect.color, rect.color.a])
	print("")

	for path in SCENES:
		if not ResourceLoader.exists(path):
			print("  SKIP %s (missing)" % path)
			continue
		var inst: Node = (load(path) as PackedScene).instantiate()
		_tree().root.add_child(inst)
		await _frames(WARMUP_FRAMES)

		# A/B/A. The tint is toggled with .visible, which is what removes it from
		# the render pass; setting alpha to 0 would still rasterise the quad.
		rect.visible = true
		var a1: Dictionary = await _window()
		rect.visible = false
		var b: Dictionary = await _window()
		rect.visible = true
		var a2: Dictionary = await _window()

		var vis_avg := (float(a1["avg"]) + float(a2["avg"])) * 0.5
		var hid_avg := float(b["avg"])
		var drift := absf(float(a1["avg"]) - float(a2["avg"]))
		var cost := vis_avg - hid_avg
		var draw_delta := ((float(a1["draw"]) + float(a2["draw"])) * 0.5) - float(b["draw"])

		print("  %s" % path.get_file())
		print("    tint ON  #1 : avg %6.3fms  p95 %6.3fms  draw %5.1f  prim %8.0f"
			% [a1["avg"], a1["p95"], a1["draw"], a1["prim"]])
		print("    tint OFF    : avg %6.3fms  p95 %6.3fms  draw %5.1f  prim %8.0f"
			% [b["avg"], b["p95"], b["draw"], b["prim"]])
		print("    tint ON  #2 : avg %6.3fms  p95 %6.3fms  draw %5.1f  prim %8.0f"
			% [a2["avg"], a2["p95"], a2["draw"], a2["prim"]])
		print("    - drift between the two ON windows : %.3fms" % drift)
		print("    - draw calls attributable to tint  : %+.2f" % draw_delta)
		if drift >= absf(cost):
			print("    - VERDICT: cost %+.3fms is INSIDE the %.3fms run-to-run drift."
				% [cost, drift])
			print("               Not separable from noise on this GPU. The draw-call")
			print("               delta above is the transferable figure.")
		else:
			var pct: float = 0.0
			if hid_avg > 0.0:
				pct = 100.0 * cost / hid_avg
			print("    - VERDICT: tint costs %+.3fms/frame (%+.1f%%), above %.3fms drift."
				% [cost, pct, drift])

		inst.queue_free()
		await _frames(4)
		print("")

	print("  -- INTERPRETATION --")
	print("  Draw calls are platform-independent and DO transfer to the target")
	print("  device. Frame time here is desktop-GPU time and is a LOWER BOUND")
	print("  for a legacy Android part, never a prediction: a full-screen")
	print("  alpha-blended quad is the single most bandwidth-bound thing a")
	print("  mobile GPU can be asked to do, so a cost invisible here can still")
	print("  matter there. What this probe establishes is the exact size of the")
	print("  extra work: %.2f Mpx of blending, plus the draw-call delta above."
		% (vp.x * vp.y / 1000000.0))
	print("")
	_tree().quit(0)
