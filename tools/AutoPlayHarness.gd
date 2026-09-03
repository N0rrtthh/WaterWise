extends Node

## Headless soak harness.
##
## Boots a real single-player session with AutoPlayManager driving the input so
## the full round loop (intro cutscene → minigame → outcome clip → score page →
## next game) runs unattended. Used to reproduce and attribute runtime error
## spam that a plain boot log never surfaces.
##
## Usage:
##   godot --headless --path E:\waterwise res://tools/AutoPlayHarness.tscn
##
## Duration is controlled by SOAK_SECONDS; the harness quits itself so CI runs
## do not need an external kill.

## Soak duration in seconds.
##
## 150s is the floor for this harness to be worth running: the rolling window is
## 5 games and Φ only starts being evaluated at 3, so a shorter soak exits before
## the adaptive algorithm has ever run and reports a clean log that proves nothing.
## At observed autoplay pacing 150s completes ~8 rounds, which fills the window,
## exercises the FIFO eviction and lets at least one Easy→Medium transition happen.
const SOAK_SECONDS: float = 150.0

## Seconds spent back on the menu before quitting.
##
## The harness used to call tree.quit() from wherever the round loop happened to
## be — often mid-outro, with the round-end presentation chain parked on an await.
## At process exit no further frames or SceneTree timers run, so those awaits can
## never resume and their GDScriptFunctionState is reported leaked. That made the
## leak count a function of exit timing rather than of any lifecycle bug, and the
## two are the whole point of the measurement.
##
## Returning to the menu first is the same code path as the player quitting to menu
## mid-animation, which SceneTree timers *do* survive: every parked coroutine gets
## one more resume, sees it is detached, and unwinds through its own guard. Anything
## still stranded after this settle is stranded because of a real ownership bug, not
## because the process died underneath it.
const MENU_SETTLE_SECONDS: float = 3.0
const MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"

## Seconds between object-lifecycle probes.
##
## The exit-time "ObjectDB instances leaked at exit" warning cannot tell a real
## per-round lifecycle bug from shutdown ordering — it fires once, after the tree is
## already gone. A periodic sample can: flat orphan/object counts from round 2 onward
## mean nothing is accumulating and the exit report is a teardown artifact; a step up
## once per round is the leak, and the timestamp says which round caused it.
##
## 15s lands 2-3 probes inside every autoplay round at observed pacing — enough to
## separate a per-round step from ordinary intra-round churn without turning the soak
## log into a wall of numbers.
const PROBE_INTERVAL_SECONDS: float = 15.0

## Resolve the soak duration, allowing an override from the command line.
##
## Usage: godot --headless --path . res://tools/AutoPlayHarness.tscn -- 420
##
## Overridable because the two questions this harness answers need different lengths.
## SOAK_SECONDS (150s) is the floor for the adaptive algorithm to have run at all.
## Attributing memory growth needs long enough to REPLAY scenes: a 150s run visits 8
## distinct minigames and never repeats one, so every load is a first load and the
## engine's own resource cache is indistinguishable from a leak. A longer run revisits
## scenes, and first-load caching plateaus while a real leak keeps climbing.
func _resolve_soak_seconds() -> float:
	for arg in OS.get_cmdline_user_args():
		var seconds := arg.to_float()
		if seconds > 0.0:
			return seconds
	return SOAK_SECONDS

func _ready() -> void:
	print("[HARNESS] boot")
	# Let every autoload finish _ready() before we drive the flow.
	await get_tree().process_frame
	await get_tree().process_frame

	var soak_seconds := _resolve_soak_seconds()
	print("[HARNESS] soak duration %.0fs" % soak_seconds)

	# Unlock the whole single-player pool for the soak.
	#
	# In production available_minigames is filtered by the unlock bundles the player
	# has bought (GameManager.UNLOCK_ID_TO_MINIGAMES), and a default save has only
	# catch_rain + pipe_puzzle. That is why every soak before this one visited exactly
	# the same 8 scenes no matter how long it ran — 3 + 5 games from those two bundles
	# — leaving 16 of the 24 single-player minigames never once loaded, so no soak
	# could have caught a crash or a missing resource in any of them.
	#
	# GameManager documents this flag for exactly this use ("Test tools may flip this
	# back to true to exercise every game without a fully-unlocked save"). It is set
	# on the harness only; nothing here writes it to disk, so real saves keep their
	# real unlock state.
	var gm_pool := get_node_or_null("/root/GameManager")
	if gm_pool and "force_full_singleplayer_pool" in gm_pool:
		gm_pool.force_full_singleplayer_pool = true
		if gm_pool.has_method("_refresh_available_minigames"):
			gm_pool._refresh_available_minigames()
		print("[HARNESS] full SP pool forced (%d games available)"
			% gm_pool.available_minigames.size())
	else:
		push_warning("[HARNESS] could not force the full SP pool — coverage stays gated")

	var apm := get_node_or_null("/root/AutoPlayManager")
	if apm and apm.has_method("set_auto_play_enabled"):
		if apm.has_method("set_auto_play_duration"):
			apm.set_auto_play_duration(soak_seconds / 60.0 + 1.0)
		# persist=false: a run killed by `timeout` never reaches the restore below, and a
		# persisted flag then hijacks the next process (see AutoPlayManager:104).
		apm.set_auto_play_enabled(true, false)
		print("[HARNESS] autoplay on")
	else:
		push_warning("[HARNESS] AutoPlayManager unavailable")

	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("start_session"):
		gm.start_session(0)  # GameMode.SINGLE_PLAYER
		print("[HARNESS] session started")
	else:
		push_error("[HARNESS] GameManager unavailable")

	# Same scene-free caveat as SoakV2Games: attach shutdown to the timer so
	# it survives the session flow replacing the current scene, and always
	# turn AutoPlay off so the leaked flag can't hijack real play sessions.
	var tree := get_tree()
	var shutdown := func() -> void:
		if apm and apm.has_method("set_auto_play_enabled"):
			apm.set_auto_play_enabled(false)
		print("[HARNESS] returning to menu")
		# Deferred: the timer fires inside the tree's processing, and swapping the
		# current scene from there is exactly what change_scene_to_file() refuses
		# to do immediately.
		tree.change_scene_to_file.call_deferred(MENU_SCENE)
		await tree.create_timer(MENU_SETTLE_SECONDS).timeout
		print("[HARNESS] done")
		tree.quit(0)
	tree.create_timer(soak_seconds).timeout.connect(shutdown)

	# Object-lifecycle probes. Armed up front as N independent one-shot timers
	# rather than a self-rescheduling loop: this node is the current scene's root
	# and gets FREED the moment the session flow calls change_scene_to_file(), so
	# anything parked on `await` inside a method of this node would never resume
	# (and would itself show up as a leaked GDScriptFunctionState). Timers created
	# from the tree outlive the scene swap, which is the same reason `shutdown`
	# above is a lambda on a timer instead of a method.
	var probe_count := int(soak_seconds / PROBE_INTERVAL_SECONDS)
	for i in range(1, probe_count + 1):
		var at := float(i) * PROBE_INTERVAL_SECONDS
		tree.create_timer(at).timeout.connect(func() -> void:
			print("[HARNESS] lifecycle t=%.0fs objects=%d nodes=%d orphans=%d static_mem=%.2fMB" % [
				at,
				int(Performance.get_monitor(Performance.OBJECT_COUNT)),
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
				float(OS.get_static_memory_usage()) / (1024.0 * 1024.0),
			])
		)
