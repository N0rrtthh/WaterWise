@tool
extends SceneTree

## ═══════════════════════════════════════════════════════════════════
## PARSE CHECK ALL — headless audit harness
## ═══════════════════════════════════════════════════════════════════
## Walks res:// (skipping vendored/skill/doc folders), loads every .gd as a
## GDScript and every .tscn as a PackedScene, and reports which ones fail.
## Run:
##   godot --headless --path E:\waterwise --script res://tools/ParseCheckAll.gd
## This surfaces the *editor-side* error flood (broken scripts / scenes) that
## does not show up from just booting MainMenu.
##
## Runs from _initialize(), not _init(): at _init() time the project's autoloads
## and global class registry are not ready yet, which made every script that
## referenced a singleton or a `class_name` look broken.

const SKIP_DIRS: PackedStringArray = [
	"res://.godot",
	"res://.claude",
	"res://.agents",
	"res://.kiro",
	"res://.venv",
	"res://.vscode",
	"res://agent",
	"res://data/skills",
	"res://addons",
	"res://GOdot.md",
	"res://_build",
	"res://android",
]

func _initialize() -> void:
	var scripts: PackedStringArray = []
	var scenes: PackedStringArray = []
	_walk("res://", scripts, scenes)

	print("=== SCRIPTS FOUND: %d ===" % scripts.size())
	var bad_scripts := 0
	for path in scripts:
		# CACHE_MODE_REUSE, not CACHE_MODE_IGNORE.
		#
		# IGNORE forced a fresh compile of every script *and* its whole
		# dependency graph on each iteration. That had two consequences: the run
		# took long enough to look hung on 193 scripts, and it reported false
		# "Identifier not found: <Autoload>" failures, because a freshly
		# recompiled script does not see the singletons registered for the
		# already-booted project. REUSE keeps the run fast and only reports
		# scripts that genuinely fail to load.
		var res := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REUSE)
		if res == null:
			bad_scripts += 1
			print("SCRIPT_FAIL: %s" % path)
		elif res is GDScript and not (res as GDScript).can_instantiate():
			# can_instantiate() alone is the real signal. The previous condition
			# also required get_instance_base_type() == "", and reported 12
			# perfectly healthy scripts (SafeAreaInfo, AnimationEngine,
			# DropletSprite, ...) as SCRIPT_NOINST. Every one of them loads and
			# instantiates; they were only flagged because this ran from _init(),
			# before the script server had registered global class names.
			bad_scripts += 1
			print("SCRIPT_NOINST: %s" % path)

	print("=== SCENES FOUND: %d ===" % scenes.size())
	var bad_scenes := 0
	for path in scenes:
		var res := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
		if res == null:
			bad_scenes += 1
			print("SCENE_FAIL: %s" % path)

	print("=== SUMMARY: %d bad scripts, %d bad scenes ===" % [bad_scripts, bad_scenes])
	quit(0 if (bad_scripts == 0 and bad_scenes == 0) else 1)

func _walk(dir_path: String, scripts: PackedStringArray, scenes: PackedStringArray) -> void:
	for skip in SKIP_DIRS:
		if dir_path.begins_with(skip):
			return

	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name) if dir_path.ends_with("/") == false else dir_path + name
		if dir.current_is_dir():
			_walk(full + "/", scripts, scenes)
		elif name.ends_with(".gd"):
			scripts.append(full)
		elif name.ends_with(".tscn"):
			scenes.append(full)
		name = dir.get_next()
	dir.list_dir_end()
