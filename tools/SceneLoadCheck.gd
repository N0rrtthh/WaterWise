extends SceneTree

## ═══════════════════════════════════════════════════════════════════
## SCENE LOAD CHECK - instantiate every minigame scene once
## ═══════════════════════════════════════════════════════════════════
## ParseCheckAll.gd loads scripts in isolation, so any script that
## references an autoload singleton reports a false "Identifier not found"
## there. This tool runs inside a normal project boot (autoloads present)
## and instantiates each minigame scene, which is the check that actually
## matters: it proves the scene tree, script, and singleton references all
## resolve together.
##
## Usage:
##   Godot_console.exe --headless --path <project> --script tools/SceneLoadCheck.gd

const MINIGAME_DIR := "res://scenes/minigames"

func _initialize() -> void:
	var scene_paths := _collect_scenes(MINIGAME_DIR)
	scene_paths.sort()

	print("=== SCENE LOAD CHECK: %d scenes ===" % scene_paths.size())

	var failed: PackedStringArray = PackedStringArray()
	for path in scene_paths:
		var packed := load(path) as PackedScene
		if packed == null:
			failed.append("LOAD_FAILED  " + path)
			continue

		var instance := packed.instantiate()
		if instance == null:
			failed.append("INSTANTIATE_FAILED  " + path)
			continue

		# Free immediately; _ready() never runs because we never add it to the
		# tree, so this checks construction and script attachment only.
		instance.free()

	if failed.is_empty():
		print("RESULT: OK — all %d scenes loaded and instantiated" % scene_paths.size())
	else:
		print("RESULT: %d FAILURE(S)" % failed.size())
		for line in failed:
			print("  " + line)

	quit(0 if failed.is_empty() else 1)

func _collect_scenes(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("SceneLoadCheck: cannot open %s" % dir_path)
		return out

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_collect_scenes(dir_path + "/" + entry))
		elif entry.ends_with(".tscn"):
			out.append(dir_path + "/" + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return out
