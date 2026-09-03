extends Node

## ═══════════════════════════════════════════════════════════════════
## DO THE IDLE ANIMATIONS RUN ON A CLOCK THAT CAN BE PAUSED?
## ═══════════════════════════════════════════════════════════════════
## MobileUIManager pauses the tree when the app loses focus, so anything animated
## off Time.get_ticks_msec() keeps accumulating phase behind the pause and snaps to
## an unrelated value the instant play resumes. The player sees mosquitoes teleport
## mid-flight and pulsing bubbles jump brightness on every notification pull-down.
## Three live minigames did this (CoverTheDrum's mosquito wiggle and tilt,
## MudPieMaker's pouring bucket, WaterPlant's thirst bubble); BucketBrigadeV2 and
## FixLeakV2 did too and are covered by tools/VerifyV2Signals.
##
## WHAT IS MEASURED
##   [1]    static: no LIVE minigame script feeds Time.get_ticks_msec() into a
##          sin()/cos(). Banner-marked orphans are excluded and listed, because the
##          two dead legacy files still contain the old expressions on purpose.
##   [2..4] live: across a real 0.5s tree pause, each game's _anim_t advances by at
##          most one frame while the wall clock advances the full half second. That
##          contrast in a single run IS the discrimination -- the wall-clock number
##          printed beside it is what the animation used to read.
##   [5]    live: a mosquito's tilt does not jump across the same pause.
##
## Usage:
##   godot --headless --path . res://tools/VerifyAnimClocks.tscn

const SCAN_DIR: String = "res://scenes/minigames"
const V2_DIR: String = "res://scripts/minigames_v2"
const ORPHAN_MARK: String = "## ORPHAN:"
const CUTSCENE_DIR: String = "res://scripts/cutscenes"
const BEAT_PATH: String = "res://scenes/ui/cutscenes/beats/DropletDashLoseOutro.tscn"
const PAUSE_SEC: float = 0.5
## One frame of slack. Headless runs nowhere near 60 fps, so this is generous on
## purpose: even at 8 fps a single post-resume frame is 0.125s, and the defect it
## has to reject is a 0.5s jump.
const MAX_CLOCK_JUMP: float = 0.2

const CLOCK_GAMES: Array = [
	{"scene": "res://scenes/minigames/CoverTheDrum.tscn", "label": "[2] CoverTheDrum"},
	{"scene": "res://scenes/minigames/MudPieMaker.tscn", "label": "[3] MudPieMaker"},
	{"scene": "res://scenes/minigames/WaterPlant.tscn", "label": "[4] WaterPlant"},
]

var _pass: int = 0
var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _files_in(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir() and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
		f = d.get_next()
	d.list_dir_end()
	return out



## Recursive .gd list, for the cutscene tree (beats live one level down).
func _files_rec(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				out.append_array(_files_rec(dir_path.path_join(f)))
		elif f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
		f = d.get_next()
	d.list_dir_end()
	return out

func _live(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await _frames(30)
	for _attempt in range(200):
		var d := InputEventMouseButton.new()
		d.button_index = MOUSE_BUTTON_LEFT
		d.pressed = true
		d.position = get_tree().root.get_visible_rect().size * 0.5
		Input.parse_input_event(d)
		await get_tree().process_frame
		var u := InputEventMouseButton.new()
		u.button_index = MOUSE_BUTTON_LEFT
		u.pressed = false
		u.position = d.position
		Input.parse_input_event(u)
		await get_tree().process_frame
		if inst.get("game_active") == true:
			break
	return inst


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("\n=== VerifyAnimClocks ===")
	await _frames(20)

	# ── [1] static sweep ──────────────────────────────────────────────────────
	var offenders: PackedStringArray = []
	var excused: PackedStringArray = []
	var files: PackedStringArray = _files_in(SCAN_DIR)
	files.append_array(_files_in(V2_DIR))
	for f in files:
		var txt: String = FileAccess.get_file_as_string(f)
		var is_orphan: bool = txt.begins_with(ORPHAN_MARK)
		for line in txt.split("\n"):
			var code: String = line.strip_edges()
			if code.begins_with("#"):
				continue  # a comment explaining the old bug is not the old bug
			if not code.contains("Time.get_ticks_msec"):
				continue
			# sin/cos is what makes it an animation phase rather than a stopwatch;
			# debounces and elapsed-time telemetry are legitimate uses of wall clock.
			if not (code.contains("sin(") or code.contains("cos(")):
				continue
			var entry: String = String(f).get_file()
			if is_orphan:
				if not excused.has(entry):
					excused.append(entry)
			elif not offenders.has(entry):
				offenders.append(entry)
	_check("[1] no live minigame animates off the wall clock",
		offenders.size() == 0,
		"%d offender(s): %s | %d excused orphan(s): %s"
		% [offenders.size(), ", ".join(offenders), excused.size(), ", ".join(excused)])

	# ── [2..4] live pause test ────────────────────────────────────────────────
	for entry in CLOCK_GAMES:
		var g := await _live(String(entry["scene"]))
		var label: String = String(entry["label"])
		if g.get("game_active") != true or g.get("_anim_t") == null:
			_check("%s round live with an _anim_t clock" % label, false,
				"game_active=%s, _anim_t=%s" % [g.get("game_active"), g.get("_anim_t")])
			g.queue_free()
			await _frames(10)
			continue
		await _wait_real(0.3)
		var anim_before: float = float(g.get("_anim_t"))
		var wall_before: int = Time.get_ticks_msec()
		get_tree().paused = true
		await _wait_real(PAUSE_SEC)
		get_tree().paused = false
		await _frames(2)
		var anim_after: float = float(g.get("_anim_t"))
		var wall_delta: float = float(Time.get_ticks_msec() - wall_before) / 1000.0
		var anim_delta: float = anim_after - anim_before
		_check("%s animation clock stops with the tree" % label,
			anim_delta < MAX_CLOCK_JUMP and wall_delta > 0.45,
			"_anim_t +%.3fs while the wall clock the old code read went +%.3fs"
			% [anim_delta, wall_delta])
		# [5] the observable that used to snap, for the one game that shows it best.
		# [5] the observable itself, for the game whose snap was most visible. NOT a
		# before/after comparison: the tilt is sin(t * 30) * 0.2, so at the ~70 fps this
		# harness gets, one honest frame already moves it by up to 0.08 rad and a
		# continuity threshold cannot tell that apart from a jump. What IS decisive is
		# whether the drawn tilt agrees with the round-local clock: a wall-clock mosquito
		# would sit at sin(uptime * 30) * 0.2, which bears no relation to _anim_t.
		if label.begins_with("[2]"):
			var mosq: Node2D = null
			for _w in range(360):
				var arr: Array = g.get("mosquitoes")
				for m in arr:
					if is_instance_valid(m):
						mosq = m
						break
				if mosq != null:
					break
				await get_tree().process_frame
			if mosq == null:
				_check("[5] mosquito tilt is drawn off the round-local clock", false,
					"no mosquito spawned within 360 frames")
			else:
				get_tree().paused = true
				await _wait_real(PAUSE_SEC)
				get_tree().paused = false
				var worst: float = 0.0
				var samples: int = 0
				for _s in range(5):
					await get_tree().process_frame
					if not is_instance_valid(mosq):
						break
					var predicted: float = sin(float(g.get("_anim_t")) * 30.0) * 0.2
					worst = maxf(worst, absf(mosq.rotation - predicted))
					samples += 1
				_check("[5] mosquito tilt is drawn off the round-local clock",
					samples > 0 and worst < 0.02,
					"worst disagreement with sin(_anim_t*30)*0.2 over %d frame(s) after a %.1fs pause: %.4f rad"
					% [samples, PAUSE_SEC, worst])
		g.queue_free()
		await _frames(10)

	# ── [6] the same sweep over the cutscene stack ────────────────────────────
	# The minigame sweep above stops at scenes/minigames + scripts/minigames_v2, but
	# beat clips animate the same way and pause the same way: a beat's tweens are bound
	# to its own node, so they stop with the tree while app uptime does not.
	var beat_offenders: PackedStringArray = []
	for f in _files_rec(CUTSCENE_DIR):
		for line in FileAccess.get_file_as_string(f).split("\n"):
			var bcode: String = line.strip_edges()
			if bcode.begins_with("#") or not bcode.contains("Time.get_ticks_msec"):
				continue
			if not (bcode.contains("sin(") or bcode.contains("cos(")):
				continue
			var bentry: String = String(f).get_file()
			if not beat_offenders.has(bentry):
				beat_offenders.append(bentry)
	_check("[6] no cutscene animates off the wall clock", beat_offenders.is_empty(),
		"%d offender(s): %s" % [beat_offenders.size(), ", ".join(beat_offenders)])

	# ── [7] the beat that did, live ───────────────────────────────────────────
	# DropletDashLoseOutro's panic wiggle is added on top of a tween-interpolated base
	# position, and the base moves up to 20 px a frame during the fast segment, so the
	# drawn y cannot be watched for continuity. _sweep_step() is a plain method though:
	# calling it with a zero base isolates the wiggle exactly, and the wiggle has to
	# equal sin(_elapsed * 28) * 9 -- the beat-local clock, not app uptime. Sampled
	# either side of a pause, because a wall-clock wiggle can only coincide with the
	# prediction at one fixed phase offset, and the pause changes that offset.
	var beat: Node = (load(BEAT_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(beat)
	await _frames(4)
	if beat.get("_elapsed") == null or not beat.has_method("_sweep_step"):
		_check("[7] DropletDashLoseOutro wiggle rides the beat-local clock", false,
			"script did not load, or _elapsed/_sweep_step absent (parse error?)")
	else:
		beat.call("play_lose")
		var dribble: Node2D = null
		for _w in range(600):
			await get_tree().process_frame
			var d: Variant = beat.get("dribble")
			if d != null and is_instance_valid(d):
				dribble = d
				break
		if dribble == null:
			_check("[7] DropletDashLoseOutro wiggle rides the beat-local clock", false,
				"Dribble never staged within 600 frames")
		else:
			var e0: float = float(beat.get("_elapsed"))
			await _frames(3)
			var ticking: bool = float(beat.get("_elapsed")) > e0
			var worst_w: float = 0.0
			var n_w: int = 0
			for pass_i in range(2):
				if pass_i == 1:
					get_tree().paused = true
					await _wait_real(PAUSE_SEC)
					get_tree().paused = false
				for _s in range(5):
					await get_tree().process_frame
					if not is_instance_valid(dribble):
						break
					beat.call("_sweep_step", Vector2.ZERO)
					var predicted: float = sin(float(beat.get("_elapsed")) * 28.0) * 9.0
					worst_w = maxf(worst_w, absf(dribble.position.y - predicted))
					n_w += 1
			_check("[7] DropletDashLoseOutro wiggle rides the beat-local clock",
				ticking and n_w >= 6 and worst_w < 0.05,
				"worst disagreement with sin(_elapsed*28)*9 over %d frame(s) either side of a %.1fs pause: %.4f px (beat clock ticking: %s)"
				% [n_w, PAUSE_SEC, worst_w, str(ticking)])
	beat.queue_free()
	await _frames(4)

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
