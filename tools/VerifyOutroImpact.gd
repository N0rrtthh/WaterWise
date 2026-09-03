extends Node

## Phase 10-11 gate: does every authored WIN/LOSE outro actually LAND?
##
## Run as a SCENE (the stinger fallback needs the AudioManager autoload):
##   godot --headless --path . res://tools/VerifyOutroImpact.tscn
##
## MicrogameOutroBase._on_impact() is a HOOK and all 50 outro clips override
## it. The four things that make the impact frame readable - white flash,
## camera punch, audio stinger, particle burst - live in the BASE, so an
## override that neither calls super._on_impact() nor inlines the helpers
## leaves that clip with no impact at all. Nothing measured that: BeatSmoke
## only asks whether a clip FINISHES, which a craft-less clip does happily.
##
## Per clip, sampled every frame:
##   flash   flash_rect.color.a peaks >= MIN_FLASH  (base drives it to 0.55)
##   punch   |camera.zoom.x - 1| peaks >= MIN_ZOOM  (base drives it to 1.07)
##   burst   >= 1 GPUParticles2D named Burst* appears under `world`
##   sfx     the cue this clip is supposed to play actually reached the pool
##   finish  outro_finished arrives inside TIMEOUT
##
## Plus two reports that describe rather than gate:
##   * clips where the impact stack fired more than once
##   * whether WIN and LOSE are audibly distinct, by checking WHICH of the two
##     cached cues each side played - a win clip that plays the lose sting is
##     just as wrong as one that plays nothing.

const BEATS_DIR := "res://scenes/ui/cutscenes/beats"
const TIMEOUT := 8.0
const MIN_FLASH := 0.30
const MIN_ZOOM := 0.02

## The impact stack is short: the camera punch is 2 x 70 ms and the flash rises
## for 50 ms then falls for 140 ms. One sample per frame is enough only while
## frames are shorter than those windows -- and they are not. BucketBrigadeLose
## builds two shard polygons, spin_stars and a squash in the same frame as the
## impact, and that frame measured 190 ms in tools/TraceOutroImpact.tscn: the
## punch began and ended inside it, so the next sample read zoom back at exactly
## 1.0000 and the flash already half-way down its fall at 0.33. The clip was
## correct; the sampling was too coarse. Slowing the engine clock stretches
## animation time against frame time, so a 70 ms window spans many frames.
## Tweens and tween_callback beats both obey time_scale (the outro base schedules
## its beats entirely with tweens -- no create_timer anywhere), so the whole clip
## stretches uniformly and the amplitudes being asserted do not change. TIMEOUT
## and the printed t= stay in CLIP seconds, comparable to the authored ~2.05 s.
const TIME_SCALE := 0.2

var passed := 0
var failed := 0

## Instance ids of AudioManager's two cached stinger streams. _generate_sfx()
## caches by (wave, freq, duration), so warming them here yields the exact
## objects _play_stinger()'s fallback will hand to a pool player.
var _id_win := 0
var _id_lose := 0

## key -> {"win": {...}, "lose": {...}} so the distinctness report can pair the
## two halves of each game up after the sweep.
var _by_game: Dictionary = {}
var _multi: Array[String] = []


func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	await _run()
	Engine.time_scale = 1.0


func _run() -> void:
	await get_tree().process_frame
	_warm_stinger_ids()
	var names := _list_outros()
	if names.is_empty():
		print("RESULT passed=0 failed=1 (no outro clips under %s)" % BEATS_DIR)
		get_tree().quit(1)
		return
	print("scanning %d outro clips (sfx_volume=%.2f)"
		% [names.size(), AudioManager.sfx_volume])
	for scene_name in names:
		await _measure(scene_name)
	_report_pairs()
	if not _multi.is_empty():
		print("NOTE impact stack fired more than once in %d clip(s): %s"
			% [_multi.size(), ", ".join(_multi)])
	print("RESULT passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


## play_sfx() early-returns when sfx_volume <= 0, and volume comes from the
## user's save, so a muted save would make every sfx row fail for a reason
## that has nothing to do with the clips. Force it audible and say so.
func _warm_stinger_ids() -> void:
	AudioManager.sfx_volume = 1.0
	var d_win: Dictionary = AudioManager.sfx_definitions[AudioManager.SFXType.SUCCESS]
	var d_lose: Dictionary = AudioManager.sfx_definitions[AudioManager.SFXType.FAILURE]
	_id_win = AudioManager._generate_sfx(
		d_win["freq"], d_win["duration"], d_win["wave"]).get_instance_id()
	_id_lose = AudioManager._generate_sfx(
		d_lose["freq"], d_lose["duration"], d_lose["wave"]).get_instance_id()


func _list_outros() -> Array:
	var out := []
	var dir := DirAccess.open(BEATS_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with("WinOutro.tscn") or f.ends_with("LoseOutro.tscn"):
			out.append(f)
		f = dir.get_next()
	out.sort()
	return out


func _measure(scene_name: String) -> void:
	var is_win := scene_name.ends_with("WinOutro.tscn")
	var label := scene_name.trim_suffix(".tscn")
	var packed: PackedScene = load(BEATS_DIR + "/" + scene_name)
	if packed == null:
		_check(label, false, "scene failed to load")
		return
	var clip := packed.instantiate()
	if clip == null:
		_check(label, false, "scene failed to instantiate")
		return
	add_child(clip)

	var done := [false]
	clip.connect("outro_finished", func() -> void: done[0] = true)
	clip.call("play_win" if is_win else "play_lose")

	var max_flash := 0.0
	var max_zoom := 0.0
	var bursts: Dictionary = {}
	var cues: Dictionary = {}
	var own_stinger := [false]
	var max_simul := 0
	var start := Time.get_ticks_msec()
	var waited := 0.0
	while not done[0] and waited < TIMEOUT / TIME_SCALE:
		max_flash = maxf(max_flash, _flash_alpha(clip))
		max_zoom = maxf(max_zoom, _zoom_deviation(clip))
		_collect_bursts(clip, bursts)
		_collect_cues(clip, cues, own_stinger)
		max_simul = maxi(max_simul, _simul_cue(_id_win if is_win else _id_lose))
		await get_tree().process_frame
		waited = float(Time.get_ticks_msec() - start) / 1000.0
	# The SNAP beat can land outro_finished on the same frame as the last
	# sample, so take one more reading after the loop exits.
	max_flash = maxf(max_flash, _flash_alpha(clip))
	max_zoom = maxf(max_zoom, _zoom_deviation(clip))
	_collect_bursts(clip, bursts)
	_collect_cues(clip, cues, own_stinger)

	max_simul = maxi(max_simul, _simul_cue(_id_win if is_win else _id_lose))
	var want_id := _id_win if is_win else _id_lose
	var other_id := _id_lose if is_win else _id_win
	var heard_want: bool = cues.has(want_id) or own_stinger[0]
	print("%-32s flash=%.2f zoom=%.3f bursts=%d cue=%s simul=%d t=%.2fs"
		% [label, max_flash, max_zoom, bursts.size(),
			"yes" if heard_want else "NO", max_simul, waited * TIME_SCALE])

	_check(label + " finish", done[0],
		"outro_finished never arrived inside %.1fs" % TIMEOUT)
	_check(label + " flash", max_flash >= MIN_FLASH,
		"impact flash peaked at %.3f, need >= %.2f" % [max_flash, MIN_FLASH])
	_check(label + " punch", max_zoom >= MIN_ZOOM,
		"camera zoom never left 1.0 (peak deviation %.4f)" % max_zoom)
	_check(label + " burst", bursts.size() >= 1,
		"no particle burst spawned under world")
	_check(label + " cue", heard_want,
		"the %s stinger never reached the audio pool" % ("win" if is_win else "lose"))
	if bursts.size() > 1:
		_multi.append("%s (%d bursts)" % [label, bursts.size()])

	var key := label.trim_suffix("WinOutro") if is_win else label.trim_suffix("LoseOutro")
	if not _by_game.has(key):
		_by_game[key] = {}
	_by_game[key]["win" if is_win else "lose"] = {
		"want": heard_want, "other": cues.has(other_id),
	}

	clip.queue_free()
	await get_tree().process_frame


func _flash_alpha(clip: Node) -> float:
	var fr = clip.get("flash_rect")
	return fr.color.a if fr is ColorRect else 0.0


func _zoom_deviation(clip: Node) -> float:
	var cam = clip.get("camera")
	return absf(cam.zoom.x - 1.0) if cam is Camera2D else 0.0


## Bursts are tracked by instance id, not by a count of live children: they are
## one-shot and self-freeing, so a clip that spawned two of them 200 ms apart
## can still have only one alive at any single sample.
func _collect_bursts(clip: Node, into: Dictionary) -> void:
	var w = clip.get("world")
	if not (w is Node2D):
		return
	for child in w.get_children():
		# one_shot, not a name match: _spawn_burst() names every burst "Burst", and
		# Godot renames a same-frame duplicate sibling to "@GPUParticles2D@N" -- neither
		# begins_with nor contains("Burst") sees that, so a clip firing the impact
		# stack twice in one frame read as a single burst: FixLeakLoseOutro spawned
		# "Burst" and "@GPUParticles2D@82" in the same frame and read as one.
		# one_shot is exact for _spawn_burst output and excludes prop jets and rain.
		if child is GPUParticles2D and child.one_shot:
			into[child.get_instance_id()] = true


## The stinger .ogg files named by STINGER_WIN_PATH / STINGER_LOSE_PATH are not
## in the project, so _play_stinger() takes its documented fallback and the cue
## comes out of AudioManager's pool. Both paths are watched, so this keeps
## measuring the right thing once real stinger audio is dropped in.


## How many pool players are pushing the SAME stinger stream at once. A clip that
## calls _play_stinger() twice in one frame starts the cached stream on two pool
## players simultaneously: same sample, same phase, roughly +6 dB on the single
## most important audio frame of the clip. A Dictionary keyed by stream id cannot
## see that, so it is counted separately.
func _simul_cue(want_id: int) -> int:
	var n := 0
	for p in AudioManager.sfx_players:
		if p.playing and p.stream != null and p.stream.get_instance_id() == want_id:
			n += 1
	return n
func _collect_cues(clip: Node, into: Dictionary, own: Array) -> void:
	var st = clip.get("stinger")
	if st is AudioStreamPlayer and st.playing and st.stream != null:
		own[0] = true
	for p in AudioManager.sfx_players:
		if p.playing and p.stream != null:
			into[p.stream.get_instance_id()] = true


## A win clip that plays the LOSE cue reads as wrong just as loudly as one that
## plays nothing, so distinctness is checked in both directions.
func _report_pairs() -> void:
	var bad: Array[String] = []
	for key in _by_game:
		var g: Dictionary = _by_game[key]
		if not (g.has("win") and g.has("lose")):
			bad.append("%s (missing half)" % key)
			continue
		var ok_win: bool = g["win"]["want"] and not g["win"]["other"]
		var ok_lose: bool = g["lose"]["want"] and not g["lose"]["other"]
		if not (ok_win and ok_lose):
			bad.append(key)
	_check("win/lose cues distinct", bad.is_empty(),
		"%d game(s) do not cue win and lose differently: %s"
			% [bad.size(), ", ".join(bad)])


func _check(label: String, cond: bool, detail: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL %s: %s" % [label, detail])
