extends Node

## VisualProbe — boots a minigame windowed and saves viewport PNGs so visual
## artifacts can be inspected frame-accurately (the old RigRenderProbe role).
##
## Usage (windowed, NOT headless — rendering is the point):
##   Godot_v4.5.1-stable_win64_console.exe --path E:\waterwise res://tools/VisualProbe.tscn
##
## Optional user args after "--": scene=res://... every=6 total=360 out=res://tools/probe_frames/x

var _scene_path := "res://scenes/minigames/FixLeak.tscn"
var _every := 6
var _total := 360
var _out_dir := "res://tools/probe_frames"
var _diff := ""


func _ready() -> void:
	_parse_args()
	print("[VISUAL] viewport=", get_viewport().get_visible_rect().size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	# Forced the way every tools/Verify* harness forces it, and BEFORE the instantiate:
	# _apply_difficulty_settings() runs inside the scene's own _ready(), so a write after
	# add_child() would be read by nothing.
	if not _diff.is_empty() and AdaptiveDifficulty:
		AdaptiveDifficulty.current_difficulty = _diff
		AdaptiveDifficulty.progressive_level = 0
		print("[VISUAL] difficulty forced to ", _diff)
	

	var packed: PackedScene = load(_scene_path)
	var game: Node = packed.instantiate()
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	await get_tree().process_frame

	# Dismiss the instruction card with a REAL click (Input singleton state
	# must update — see ProbeShellInput._boot_click for why).
	for i in range(30):
		await get_tree().process_frame
	_boot_click()
	await get_tree().process_frame
	_boot_release()

	var frame := get_viewport().get_texture()
	var saved := 0
	for i in range(_total):
		await get_tree().process_frame
		if i % _every == 0:
			var img: Image = frame.get_image()
			var name := "f%04d.png" % i
			img.save_png(ProjectSettings.globalize_path(_out_dir + "/" + name))
			saved += 1
	print("[VISUAL] saved ", saved, " frames to ", _out_dir)
	get_tree().quit(0)


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"scene":
				_scene_path = kv[1]
			"every":
				_every = maxi(1, int(kv[1]))
			"total":
				_total = maxi(1, int(kv[1]))
			"out":
				# Frames overwrite fNNNN.png, so probing several games in one run needs a
				# separate directory per game or the later runs erase the earlier evidence.
				_out_dir = kv[1]
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
			"diff":
				# Difficulty was NEVER forced here, so every frame this tool has ever saved was
				# taken at whatever AdaptiveDifficulty resolved to on boot - Medium for a fresh
				# profile. That is the wrong tier to LOOK at: the per-difficulty numbers are what
				# the layout has to survive (CloudCatcher's row is 4/6/8 plants, QuickShower's
				# gauge sweeps at 60/100/150), and the extremes are where a layout breaks.
				_diff = kv[1]
	print("[VISUAL] scene=", _scene_path, " every=", _every, " total=", _total)


func _boot_click() -> void:
	var vp_pos := Vector2(960.0, 540.0)
	var win_pos := get_tree().root.get_final_transform() * vp_pos
	var dn := InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.pressed = true
	dn.position = win_pos
	dn.global_position = win_pos
	dn.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(dn)


func _boot_release() -> void:
	var vp_pos := Vector2(960.0, 540.0)
	var win_pos := get_tree().root.get_final_transform() * vp_pos
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = win_pos
	up.global_position = win_pos
	up.button_mask = 0
	Input.parse_input_event(up)
