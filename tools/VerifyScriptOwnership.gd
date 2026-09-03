extends Node

## ═══════════════════════════════════════════════════════════════════
## SCRIPT OWNERSHIP: DOES THE FILE I AM EDITING ACTUALLY RUN?
## ═══════════════════════════════════════════════════════════════════
## THE MISTAKE THIS EXISTS TO PREVENT
##   FIX 44 (Fix Leak's unreachable waste threshold) was written into
##   res://scenes/minigames/FixLeak.gd -- the obvious file, named after the scene,
##   sitting next to 20 siblings that DO run. FixLeak.tscn does not load it. It
##   loads res://scripts/minigames_v2/FixLeakV2.gd. The edit was inert, the
##   verification harness reported pre-fix numbers against "fixed" code, and the
##   only reason it was caught is that the harness was run at all.
##
##   Four of the 25 single-player scenes were rebuilt on MicrogameShell and left
##   their originals behind. Nothing in the tree says so: same directory, same
##   name, same `extends MiniGameBase`, no marker.
##
## WHAT IS ENFORCED
##   [1] every scene under scenes/minigames names a script that exists on disk
##   [2] that script loads and derives from MiniGameBase (so the roster is real)
##   [3] every .gd in the game-script dirs is either reachable -- loaded by a scene,
##       referenced by res:// path, or used through its class_name -- or carries a
##       line-1 "## ORPHAN:" banner saying what supersedes it
##   [4] no scene points at a banner-marked orphan (the banner has to stay true)
##   [5] the four known v2 rebuilds still map to their V2 scripts
##
## Reachability is decided by reading the project's own text, not a hand-written
## list, so a file that stops being loaded starts failing [3] on the next run.
##
## Usage:
##   godot --headless --path . res://tools/VerifyScriptOwnership.tscn

## Directories whose scripts are gameplay code -- where the misfire happened.
const SCAN_DIRS: Array = [
	"res://scenes/minigames",
	"res://scripts/minigames_v2",
	"res://scripts/multiplayer",
]
## Roots walked RECURSIVELY for references. scenes/multiplayer holds the 12 MP_*
## scenes and is two levels down; missing it made all 12 MP scripts look orphaned.
const REF_ROOTS: Array = [
	"res://autoload",
	"res://scenes",
	"res://scripts",
	"res://tools",
]
## Autoloads are named here and nowhere else - LevelSets.gd has no other reference.
const PROJECT_FILE: String = "res://project.godot"
const ORPHAN_MARK: String = "## ORPHAN:"
const SCENE_DIR: String = "res://scenes/minigames"
## The rebuilds. Scene stem -> the script it must actually be running.
const V2_MAP: Dictionary = {
	"FixLeak": "res://scripts/minigames_v2/FixLeakV2.gd",
	"GreywaterSorter": "res://scripts/minigames_v2/GreywaterSorterV2.gd",
	"BucketBrigade": "res://scripts/minigames_v2/BucketBrigadeV2.gd",
	"CatchTheRain": "res://scripts/minigames_v2/CatchTheRainV2.gd",
}

var _pass: int = 0
var _fail: int = 0
## Every line of every script and scene in REF_DIRS, concatenated once.
var _corpus: String = ""


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


func _files_in(dir_path: String, ext: String) -> Array:
	var out: Array = []
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append("%s/%s" % [dir_path, f])
	out.sort()
	return out


## The script a scene's root node runs, read straight out of the .tscn text.
func _scene_script(scene_path: String) -> String:
	var txt: String = FileAccess.get_file_as_string(scene_path)
	for line in txt.split("\n"):
		if not line.begins_with("[ext_resource"):
			continue
		if not line.contains("type=\"Script\""):
			continue
		var i: int = line.find("path=\"")
		if i < 0:
			continue
		var rest: String = line.substr(i + 6)
		return rest.substr(0, rest.find("\""))
	return ""


## A file's text with comment lines removed. Without this the harness's own doc
## comment ("...was written into res://scenes/minigames/FixLeak.gd...") counts as a
## reference and the file it exists to flag looks reachable. Any prose mention of a
## path would do the same, so comments are dropped project-wide rather than
## special-casing this file.
func _code_only(text: String) -> String:
	var kept: PackedStringArray = []
	for line in text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		kept.append(line)
	return "\n".join(kept)


func _build_corpus() -> void:
	var parts: PackedStringArray = [FileAccess.get_file_as_string(PROJECT_FILE)]
	var queue: Array = REF_ROOTS.duplicate()
	var seen_dir: Dictionary = {}
	while not queue.is_empty():
		var dir_path: String = queue.pop_back()
		if seen_dir.has(dir_path):
			continue
		seen_dir[dir_path] = true
		var d: DirAccess = DirAccess.open(dir_path)
		if d == null:
			continue
		for sub in d.get_directories():
			queue.append("%s/%s" % [dir_path, sub])
		for f in d.get_files():
			if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
				parts.append(_code_only(FileAccess.get_file_as_string("%s/%s" % [dir_path, f])))
	_corpus = "\n".join(parts)


## Why this script is reachable, or "" if nothing in the project mentions it.
func _is_reachable(path: String, own_text: String) -> String:
	# By res:// path -- how a .tscn names its script and how load()/preload() name one.
	var refs: int = _corpus.count(path) - own_text.count(path)
	if refs > 0:
		return "referenced by path"
	# By class_name -- EntityPool and MiniGameAssets are used this way and never by path.
	for line in own_text.split("\n"):
		if not line.begins_with("class_name "):
			continue
		var cn: String = line.substr(11).strip_edges()
		if cn == "":
			break
		var uses: int = _corpus.count(cn) - own_text.count(cn)
		if uses > 0:
			return "used as class %s" % cn
		break
	return ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== DOES EVERY GAMEPLAY SCRIPT ACTUALLY RUN? ===")
	print("")
	_build_corpus()

	# -- [1..2b] Every scene's script exists, parses, and is a real minigame. --
	var scenes: Array = _files_in(SCENE_DIR, ".tscn")
	var missing: Array = []
	var wont_load: Array = []
	var not_base: Array = []
	var scripted: Dictionary = {}
	for s in scenes:
		var sp: String = _scene_script(s)
		if sp == "":
			missing.append("%s (no script at all)" % String(s).get_file())
			continue
		if not FileAccess.file_exists(sp):
			missing.append("%s -> %s" % [String(s).get_file(), sp])
			continue
		scripted[s] = sp
		# can_instantiate(), not `load(sp) == null`: a script with a parse error still
		# loads as a non-null GDScript in 4.5.1 (only reload() reports ERR_PARSE_ERROR 43
		# and get_instance_base_type() comes back empty), so the null test silently passed
		# over RainwaterHarvesting.gd for a whole phase. This is what caught the FIX-42
		# regression there: the sweep replaced its create_timer() calls with round_delay(),
		# which only exists on MiniGameBase, and that scene extends Node2D.
		var scr: Object = load(sp)
		if scr == null or not (scr as GDScript).can_instantiate():
			wont_load.append(String(sp).get_file())
			continue
		var first: String = ""
		for line in FileAccess.get_file_as_string(sp).split("\n"):
			if line.begins_with("extends "):
				first = line.substr(8).strip_edges().replace("\"", "")
				break
		# Both spellings are the same base: 21 files say `extends MiniGameBase`, two say
		# `extends "res://scripts/MiniGameBase.gd"`, and the four v2 scenes reach it
		# through MicrogameShell.
		if first.get_file() == "MiniGameBase.gd":
			first = "MiniGameBase"
		if first != "MiniGameBase" and first != "MicrogameShell":
			not_base.append("%s extends %s" % [String(sp).get_file(), first])
	_check("[1] every minigame scene names a script that is on disk",
		missing.is_empty(),
		"%d broken: %s" % [missing.size(), ", ".join(missing)])
	_check("[2] every one of those scripts parses",
		wont_load.is_empty(),
		"%d will not load: %s" % [wont_load.size(), ", ".join(wont_load)])
	# RainwaterHarvesting.tscn is a standalone Node2D scene that no roster reaches -
	# a documented deviation, not a defect, so it is named rather than counted.
	_check("[2b] every scene on the roster is a MiniGameBase/MicrogameShell game",
		not_base == ["RainwaterHarvesting.gd extends Node2D"] or not_base.is_empty(),
		"%d off-roster: %s" % [not_base.size(), ", ".join(not_base)])
	print("          %d scenes scanned, %d with a resolvable script"
		% [scenes.size(), scripted.size()])

	# -- [3] Nothing unreachable is left unlabelled. --
	var silent: Array = []
	var labelled: Array = []
	var live: int = 0
	for dir_path in SCAN_DIRS:
		for f in _files_in(dir_path, ".gd"):
			var raw_text: String = FileAccess.get_file_as_string(f)
			# Code-only for the self-reference subtraction, raw for the banner: the
			# banner is itself a comment and would be stripped away.
			if _is_reachable(f, _code_only(raw_text)) != "":
				live += 1
			elif raw_text.begins_with(ORPHAN_MARK):
				labelled.append(String(f).get_file())
			else:
				silent.append(String(f).get_file())
	_check("[3] no unreachable gameplay script is left unlabelled",
		silent.is_empty(),
		"%d silent orphan(s) - the FIX 44 trap: %s"
			% [silent.size(), ", ".join(silent)])
	print("          %d reachable, %d banner-marked orphan(s): %s"
		% [live, labelled.size(), ", ".join(labelled)])

	# -- [4] A banner-marked file is not secretly still in use. --
	var lying: Array = []
	for s in scripted.keys():
		var sp: String = scripted[s]
		if FileAccess.get_file_as_string(sp).begins_with(ORPHAN_MARK):
			lying.append("%s loads %s" % [String(s).get_file(), sp.get_file()])
	_check("[4] no scene loads a script marked ORPHAN",
		lying.is_empty(),
		"%d stale banner(s): %s" % [lying.size(), ", ".join(lying)])

	# -- [5] The four rebuilds still resolve to their v2 scripts. --
	var wrong: Array = []
	for stem in V2_MAP.keys():
		var scene_path: String = "%s/%s.tscn" % [SCENE_DIR, stem]
		if not FileAccess.file_exists(scene_path):
			wrong.append("%s.tscn is gone" % stem)
			continue
		var got: String = _scene_script(scene_path)
		if got != V2_MAP[stem]:
			wrong.append("%s.tscn -> %s (expected %s)"
				% [stem, got.get_file(), String(V2_MAP[stem]).get_file()])
	_check("[5] the v2 rebuilds are the scripts their scenes load",
		wrong.is_empty(),
		"%d mismatch(es): %s" % [wrong.size(), ", ".join(wrong)])

	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	print("")
	get_tree().quit(1 if _fail > 0 else 0)
