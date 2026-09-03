extends Node

## Memory attribution probe.
##
## The 480s soak sampled OS.get_static_memory_usage() every 15s and caught exactly
## one doubling: 105.33MB at t=345s → 209.27MB at t=360s → 106.07MB at t=375s. The
## sample landed on the FinalScore → InitialScreen hand-off, which is a CORRELATION,
## not an attribution — a 15s interval cannot say which call allocated, and reading
## FinalScore.gd rules out the obvious suspects: it builds Labels, Polygon2Ds and
## ColorRects, its music is a cached 176KB procedural AudioStreamWAV, and the session
## export it coincides with writes a 37KB JSON file. None of those is 100MB.
##
## This probe brackets each suspect with a sample so a delta belongs to ONE call.
## Every scene runs twice, because a first load also pays for the engine's resource
## cache and for font-atlas rasterisation at each distinct size — one-time costs that
## must not be reported as a per-visit leak.
##
## Usage:
##   godot --headless --path . res://tools/ProbeMemory.tscn

const MB: float = 1048576.0

var _last_static: float = 0.0


func _sample(label: String) -> void:
	var stat := float(OS.get_static_memory_usage()) / MB
	var delta := stat - _last_static
	_last_static = stat
	print("[PROBE] %-42s static=%8.2fMB  d=%+8.2fMB  obj=%5d node=%4d orph=%3d tex=%6.2fMB" % [
		label,
		stat,
		delta,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / MB,
	])


func _settle(frames: int = 3) -> void:
	for _i in range(frames):
		await get_tree().process_frame


## Populate the state FinalScore reads, matching what the soak had on screen:
## a completed 8-round single-player session with every life spent, which is the
## is_game_over branch (extra title/subtitle Labels + TRY AGAIN button).
func _seed_session() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		push_warning("[PROBE] GameManager unavailable — FinalScore will build its empty path")
		return
	var games := [
		"catch_rain", "fix_leak", "plug_the_leak", "cover_the_drum",
		"rice_wash_rescue", "trace_pipe_path", "toilet_tank_fix", "turn_off_tap",
	]
	var rounds: Array = []
	for i in range(games.size()):
		rounds.append({
			"game": games[i],
			"score": 60 + i * 5,
			"accuracy": 0.45 + 0.06 * float(i),
			"reaction_time": 900 + i * 40,
		})
	gm.round_scores = rounds
	gm.session_score = 640
	gm.session_lives = 0


## Load → instantiate → enter tree → settle → free, sampling between each step.
##
## The four steps are separated because they cost in different places: load() pays
## for the .tscn and its dependency graph, instantiate() for the node objects,
## add_child() for _ready() (which is where every builder and every font atlas
## lands), and the settle for whatever the tweens allocate as they run.
func _cycle(path: String, pass_no: int) -> void:
	var tag := "%s p%d" % [path.get_file().get_basename(), pass_no]
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("[PROBE] could not load %s" % path)
		return
	await _settle(1)
	_sample("%s load()" % tag)

	var inst := packed.instantiate()
	await _settle(1)
	_sample("%s instantiate()" % tag)

	get_tree().root.add_child(inst)
	await _settle(4)
	_sample("%s add_child()+_ready" % tag)

	await get_tree().create_timer(1.5).timeout
	_sample("%s +1.5s tweens running" % tag)

	inst.queue_free()
	await _settle(4)
	_sample("%s queue_free()" % tag)


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE MEMORY ATTRIBUTION PROBE")
	print("═══════════════════════════════════════════════════════════")
	# Let all autoloads finish _ready(), and let AudioManager's deferred
	# _prewarm_music_cache() generate all 7 tracks (one per frame) so its ~1.2MB
	# does not land in the middle of a scene measurement.
	await _settle(20)
	_last_static = float(OS.get_static_memory_usage()) / MB
	_sample("baseline (autoloads + music prewarm)")

	_seed_session()
	await _settle(2)
	_sample("seeded 8-round game-over session")

	# The two scenes the spike sample sat between, in the order the soak hit them.
	for pass_no in [1, 2]:
		await _cycle("res://scenes/ui/FinalScore.tscn", pass_no)
		await _cycle("res://scenes/ui/InitialScreen.tscn", pass_no)

	# The three exports that ran in the same 15s window as the spike sample.
	var sl := get_node_or_null("/root/SessionLogger")
	if sl and sl.has_method("export_session"):
		sl.export_session(true)
		await _settle(2)
		_sample("SessionLogger.export_session()")

	var pp := get_node_or_null("/root/PerformanceProfiler")
	if pp and pp.has_method("export_session_log_to_file"):
		pp.export_session_log_to_file()
		await _settle(2)
		_sample("PerformanceProfiler export_session_log")

	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if ad and ad.has_method("export_to_json_file"):
		ad.export_to_json_file()
		await _settle(2)
		_sample("AdaptiveDifficulty export_to_json_file")

	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_now"):
		sm.save_now()
		await _settle(2)
		_sample("SaveManager.save_now()")

	print("═══════════════════════════════════════════════════════════")
	print("")
	get_tree().quit(0)
