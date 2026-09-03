extends Node

## TEMP tool: renders one beat clip (res://scenes/ui/cutscenes/beats/*.tscn)
## and saves PNG frames to _build/beats_fix/ so the choreography can be
## eyeballed without launching the game.
## Usage:
##   godot --path . res://tools/BeatShotProbe.tscn -- --clip=TracePipePathWinOutro

const SHOT_TIMES: Array[float] = [0.3, 0.9, 1.6, 2.4, 3.4, 4.6]

func _ready() -> void:
	var clip_name := "TracePipePathWinOutro"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clip="):
			clip_name = arg.substr("--clip=".length())
	var path := "res://scenes/ui/cutscenes/beats/%s.tscn" % clip_name
	var packed: PackedScene = load(path)
	var clip := packed.instantiate()
	add_child(clip)
	var done := [false]
	if clip.has_signal("outro_finished"):
		clip.connect("outro_finished", func() -> void:
			done[0] = true
			print("SIGNAL outro_finished fired")	
		)
	if clip_name.ends_with("Intro"):
		clip.call("play_cause")
	elif clip_name.ends_with("WinOutro"):
		clip.call("play_win")
	else:
		clip.call("play_lose")
	DirAccess.make_dir_recursive_absolute("res://_build/beats_fix")
	var prev := 0.0
	for i in SHOT_TIMES.size():
		await get_tree().create_timer(SHOT_TIMES[i] - prev).timeout
		prev = SHOT_TIMES[i]
		if not is_instance_valid(clip):
			break
		var img := get_viewport().get_texture().get_image()
		var p := "res://_build/beats_fix/%s_%d.png" % [clip_name, i]
		img.save_png(p)
		print("wrote ", p)
	if not done[0]:
		await get_tree().create_timer(4.0).timeout
	print("done")
	get_tree().quit(0)