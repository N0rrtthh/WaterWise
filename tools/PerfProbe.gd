extends Node

## ═══════════════════════════════════════════════════════════════════
## PER-SCENE FRAME-COST PROBE
## ═══════════════════════════════════════════════════════════════════
## PerformanceProfiler (a thesis system) already tracks FPS, frame_time_ms,
## dropped_frames (>16.67ms), memory, orphans, temperature and battery. It does
## NOT track the three numbers that say WHY a frame is expensive:
##
##     draw calls          — the count the CPU submits per frame
##     texture memory      — VRAM resident for the loaded scene
##     rendered primitives — triangles actually rasterised
##
## MUST run with a real renderer. `--headless` selects the dummy driver, which
## reports 0 draw calls and 0 primitives no matter what is on screen, so a
## headless frame-cost number is not a measurement of anything. The probe prints
## the active driver and refuses to report a PASS/FAIL verdict under "dummy".
##
## WHAT TRANSFERS TO THE TARGET DEVICE, AND WHAT DOES NOT
##   draw calls / primitives / texture memory / node counts: platform-independent
##     properties of the scene — these are the numbers to hold against a budget.
##   frame time: measured on this desktop GPU. It is a LOWER BOUND for a
##     <2GB legacy Android device, never a prediction. Reported, never used as a
##     pass/fail for the 16.6ms budget.
##
## Frame time is reported as a p95 alongside min/avg/max because one 40ms hitch in
## a 120-frame window moves the average by 0.3ms and hides completely — a mean
## cannot see a stutter, which is the thing a player feels.
##
## Run (windowed, at the target device's portrait resolution):
##   godot --path . --resolution 720x1440 res://tools/PerfProbe.tscn
## Contrast run to demonstrate the dummy-driver caveat:
##   godot --headless --path . res://tools/PerfProbe.tscn

const MB: float = 1048576.0
## 60fps budget from the thesis. PerformanceProfiler counts a frame over 16.67ms
## as dropped; this is the same line.
const FRAME_BUDGET_MS: float = 16.6
## Frames discarded after a scene loads, before sampling starts: the first frames
## pay for shader compilation, font-atlas rasterisation and tween start-up, none
## of which recur while the player sits on the screen.
const WARMUP_FRAMES: int = 45
## Frames sampled per scene. 120 at 60fps is 2 seconds — long enough for the
## menu's wave/grid shaders and the idle character animation to cycle.
const SAMPLE_FRAMES: int = 120

## Representative screens: the two heaviest menus, plus minigames chosen for
## different rendering shapes (particle-driven, sprite-heavy, shader background).
const SCENES: Array = [
	"res://scenes/ui/MainMenu.tscn",
	"res://scenes/ui/MultiplayerMenu.tscn",
	# Added after the memory probe attributed a 25.85MB per-load cost to
	# InitialScreen: seven 2360x1640 parallax layers. Memory was the question
	# that led here, but seven full-screen layers is a FILL-RATE question and
	# this scene was missing from the sample entirely.
	"res://scenes/ui/InitialScreen.tscn",
	"res://scenes/ui/FinalScore.tscn",
	"res://scenes/minigames/ThirstyPlant.tscn",
	"res://scenes/minigames/CatchTheRain.tscn",
	"res://scenes/minigames/DropletDash.tscn",
	"res://scenes/minigames/BucketBrigade.tscn",
]

var rows: Array = []
var _dummy: bool = false


func _ready() -> void:
	_run.call_deferred()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _m(id: int) -> float:
	return float(Performance.get_monitor(id))


## Sample one scene: load it, let it settle, then time SAMPLE_FRAMES of it.
func _measure(path: String) -> Dictionary:
	var row := {"scene": path.get_file(), "ok": false}
	if not ResourceLoader.exists(path):
		row["note"] = "missing"
		return row

	var tex_before := _m(Performance.RENDER_TEXTURE_MEM_USED) / MB
	var packed := load(path) as PackedScene
	if packed == null:
		row["note"] = "load failed"
		return row
	var inst: Node = packed.instantiate()
	_tree().root.add_child(inst)
	await _frames(WARMUP_FRAMES)

	# Steady state, after warm-up: what the player actually sits in front of.
	# Frame cost is the WALL-CLOCK interval between process_frame signals, not
	# Performance.TIME_PROCESS: that monitor is a sampled figure, and reading it
	# every frame produced 405ms "frames" alongside a reported 101 FPS in the
	# first run of this probe — two numbers that cannot both be true.
	var times: Array[float] = []
	var last_us := Time.get_ticks_usec()
	var window_start_us := last_us
	var draw_sum := 0.0
	var prim_sum := 0.0
	var draw_peak := 0.0
	for _i in range(SAMPLE_FRAMES):
		await _tree().process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last_us) / 1000.0)
		last_us = now
		var dc := _m(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		draw_sum += dc
		draw_peak = maxf(draw_peak, dc)
		prim_sum += _m(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)

	# Cross-check: the engine's own FPS counter over the same window. A
	# wall-clock average that disagrees with 1000/fps means the sampling itself
	# perturbed the run.
	var fps := _m(Performance.TIME_FPS)
	# Decisive cross-check on the per-frame deltas: the whole window timed once.
	# If SAMPLE_FRAMES * avg does not equal this, the per-frame sampling is lying
	# and every distribution above it is worthless.
	var window_ms := float(Time.get_ticks_usec() - window_start_us) / 1000.0

	times.sort()
	row["ok"] = true
	row["min"] = times[0]
	row["p95"] = times[int(floor(times.size() * 0.95)) - 1]
	row["max"] = times[times.size() - 1]
	var s := 0.0
	for t in times:
		s += t
	row["avg"] = s / times.size()
	row["over"] = 0
	for t in times:
		if t > FRAME_BUDGET_MS:
			row["over"] = int(row["over"]) + 1
	row["draw_avg"] = draw_sum / SAMPLE_FRAMES
	row["draw_peak"] = draw_peak
	row["prim_avg"] = prim_sum / SAMPLE_FRAMES
	row["fps"] = fps
	row["window_ms"] = window_ms
	row["implied_fps"] = 1000.0 / (window_ms / SAMPLE_FRAMES)
	row["nodes"] = int(_m(Performance.OBJECT_NODE_COUNT))
	row["objects"] = int(_m(Performance.OBJECT_COUNT))
	row["tex_mb"] = _m(Performance.RENDER_TEXTURE_MEM_USED) / MB
	row["tex_delta_mb"] = row["tex_mb"] - tex_before
	row["static_mb"] = float(OS.get_static_memory_usage()) / MB

	inst.queue_free()
	await _frames(6)
	row["orphans_after"] = int(_m(Performance.OBJECT_ORPHAN_NODE_COUNT))
	return row


func _run() -> void:
	# Vsync must be OFF or every frame measures 16.67ms regardless of how much
	# work it did — the cap would be reported as the cost. Windowed only; the
	# dummy driver has no swapchain to configure.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0

	var driver := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))
	var adapter := RenderingServer.get_video_adapter_name()
	_dummy = DisplayServer.get_name() == "headless" or adapter == ""
	print("")
	print("═══════════════════════════════════════════════════════════════════")
	print("  PER-SCENE FRAME COST — budget %.1fms/frame (60fps)" % FRAME_BUDGET_MS)
	print("  method=%s  display=%s  adapter=%s" % [driver, DisplayServer.get_name(),
		(adapter if adapter != "" else "<none>")])
	print("  viewport=%s" % str(_tree().root.size))
	if _dummy:
		print("  ⚠ DUMMY DRIVER — draw calls and primitives are meaningless here.")
		print("    This run demonstrates the caveat; it does not measure frame cost.")
	print("═══════════════════════════════════════════════════════════════════")

	for path in SCENES:
		var row: Dictionary = await _measure(path)
		rows.append(row)
		if not bool(row.get("ok", false)):
			print("  %-26s SKIPPED — %s" % [row["scene"], row.get("note", "?")])
			continue
		print(("  %-26s cpu min/avg/p95/max %5.2f/%5.2f/%5.2f/%5.2f ms"
			+ "  over-budget %3d/%d") % [
			row["scene"], row["min"], row["avg"], row["p95"], row["max"],
			row["over"], SAMPLE_FRAMES])
		print(("  %-26s draw avg/peak %6.0f/%6.0f  prims %8.0f  nodes %4d"
			+ "  tex %6.2fMB  rss %6.2fMB") % [
			"", row["draw_avg"], row["draw_peak"], row["prim_avg"], row["nodes"],
			row["tex_mb"], row["static_mb"]])
		print(("  %-26s window %7.1fms over %d frames -> %6.1f fps implied"
			+ "  (Performance.TIME_FPS said %.0f)") % [
			"", row["window_ms"], SAMPLE_FRAMES, row["implied_fps"], row["fps"]])

	print("")
	print("── worst offenders ────────────────────────────────────────────────")
	var by_draw := rows.duplicate()
	by_draw = by_draw.filter(func(r): return bool(r.get("ok", false)))
	by_draw.sort_custom(func(a, b): return float(a["draw_avg"]) > float(b["draw_avg"]))
	for r in by_draw.slice(0, 3):
		print("  %-26s %6.0f draw calls/frame, %6.2fMB textures"
			% [r["scene"], r["draw_avg"], r["tex_mb"]])

	# The verdict is only stated where it can be honestly stated.
	if _dummy:
		print("")
		print("  NO VERDICT: the dummy driver renders nothing.")
	else:
		var worst_p95 := 0.0
		var worst_name := ""
		for r in by_draw:
			if float(r["p95"]) > worst_p95:
				worst_p95 = float(r["p95"])
				worst_name = str(r["scene"])
		print("")
		print("  desktop CPU-side worst p95: %.2fms on %s (budget %.1fms)"
			% [worst_p95, worst_name, FRAME_BUDGET_MS])
		print("  NOTE: desktop frame time is a LOWER BOUND for legacy Android,")
		print("        never a prediction. Draw calls / textures / nodes DO transfer.")
	print("═══════════════════════════════════════════════════════════════════")
	print("")
	_tree().quit(0)
