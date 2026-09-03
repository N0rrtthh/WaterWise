extends Node

## TEMP smoke tool (delete after use): disk-driven scan of every beat clip.
## Run as a SCENE (autoloads present): res://tools/BeatSmoke.tscn
## For each res://scenes/ui/cutscenes/beats/*.tscn:
##   * Intro    -> fresh instance, play_cause(), awaits outro_finished (8s cap)
##   * WinOutro -> fresh instance, play_win(),   awaits outro_finished (8s)
##   * LoseOutro-> fresh instance, play_lose(),  awaits outro_finished (8s)
## Prints "RESULT ok=<n> fail=<n>". A clip fails if it never finishes in time.

const BEATS_DIR := "res://scenes/ui/cutscenes/beats"
const TIMEOUT := 8.0

var ok := 0
var fail := 0
var _start := 0.0


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	var dir := DirAccess.open(BEATS_DIR)
	if dir == null:
		print("RESULT ok=0 fail=1 (cannot open %s)" % BEATS_DIR)
		get_tree().quit(1)
		return
	var names := []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tscn"):
			names.append(f)
		f = dir.get_next()
	names.sort()

	for scene_name in names:
		if scene_name.ends_with("Intro.tscn"):
			await _play_one(scene_name, "play_cause")
		elif scene_name.ends_with("WinOutro.tscn"):
			await _play_one(scene_name, "play_win")
		elif scene_name.ends_with("LoseOutro.tscn"):
			await _play_one(scene_name, "play_lose")

	print("RESULT ok=%d fail=%d" % [ok, fail])
	get_tree().quit(1 if fail > 0 else 0)


func _play_one(scene_name: String, method: String) -> void:
	var path := BEATS_DIR + "/" + scene_name
	var packed: PackedScene = load(path)
	if packed == null:
		print("FAIL load %s" % path)
		fail += 1
		return
	var inst := packed.instantiate()
	if inst == null or not inst.has_method(method):
		print("FAIL instantiate %s" % path)
		fail += 1
		if inst:
			inst.free()
		return
	add_child(inst)
	var done := [false]
	if inst.has_signal("outro_finished"):
		inst.connect("outro_finished", func() -> void: done[0] = true)
	if inst.has_method(method):
		inst.call(method)
	var waited := 0.0
	_start = Time.get_ticks_msec() / 1000.0
	while not done[0] and waited < TIMEOUT:
		await get_tree().process_frame
		waited = Time.get_ticks_msec() / 1000.0 - _start
	if done[0]:
		ok += 1
		print("ok   %s %s" % [scene_name, method])
	else:
		fail += 1
		print("FAIL timeout %s %s" % [scene_name, method])
	inst.queue_free()
	await get_tree().process_frame