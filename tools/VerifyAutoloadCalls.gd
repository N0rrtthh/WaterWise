extends Node

## ═══════════════════════════════════════════════════════════════════
## AUTOLOAD CALL-SITE RESOLUTION AUDIT
## ═══════════════════════════════════════════════════════════════════
## Every `SomeAutoload.method(...)` in the project, checked against the LIVE
## autoload node with has_method(). A miss is a call that raises
##     Invalid call. Nonexistent function 'x' in base 'Node (Y.gd)'
## at runtime and — this is the part that matters — ABORTS THE CALLING
## FUNCTION, so every line after it in that function silently never runs.
##
## Why this is a runtime tool and not a grep: has_method() on the real node
## resolves INHERITED methods too, so Object/Node built-ins (get, set, rpc,
## has_method, has_signal, is_connected, call_deferred, ...) come back true
## instead of drowning the report in false positives. A grep over `func` lines
## in the autoload's own script cannot do that.
##
## Found on the first run (all four confirmed absent project-wide, not just
## absent from the autoload):
##   scenes/minigames/RainwaterHarvesting.gd  GameManager.submit_coop_performance()
##   scenes/minigames/RainwaterHarvesting.gd  GameManager.receive_partner_performance()
##       — the second one aborted _on_partner_performance_received() before its
##         _show_team_results() call, parking BOTH players on "Waiting for
##         partner..." for the rest of the round.
##   scenes/ui/MiniGameResults.gd             GameManager.replay_current_minigame()
##       — the RETRY button, connected in the .tscn, styled and reparented into
##         the visible button row.
##   scenes/ui/InitialScreen.gd               AccessibilityManager.toggle_menu()
##       — in _on_accessibility_pressed(), which nothing connects; reported as
##         an unreachable call site rather than a live defect.
##
## Deliberately NOT reported: a call guarded by `if X.has_method("m"):` on the
## same or the previous line. That is a live feature-detect, and several are
## load-bearing in this project (MiniGameBase's ThemeManager lookups). They are
## counted and printed as a separate advisory tally instead.
##
## Run:
##   godot --headless --path . res://tools/VerifyAutoloadCalls.tscn

const SCAN_DIRS: Array[String] = [
	"res://scenes", "res://scripts", "res://autoload",
]

var results: Array = []
var misses: Array = []
var guarded_count: int = 0
var call_sites: int = 0
var files_scanned: int = 0


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  AUTOLOAD CALL-SITE RESOLUTION AUDIT")
	print("═══════════════════════════════════════════════════════════")
	var names: Array[String] = _autoload_names()
	print("  %d autoloads: %s" % [names.size(), ", ".join(names)])
	var files: Array[String] = []
	for d in SCAN_DIRS:
		_collect(d, files)
	files.sort()
	print("  scanning %d scripts" % files.size())
	print("")
	for f in files:
		_scan_file(f, names)
	_report()


## The autoload set, read from the project settings rather than hardcoded, so a
## newly added autoload is covered without editing this tool.
func _autoload_names() -> Array[String]:
	var out: Array[String] = []
	for prop in ProjectSettings.get_property_list():
		var key: String = str(prop.get("name", ""))
		if not key.begins_with("autoload/"):
			continue
		var n: String = key.substr("autoload/".length())
		if n.is_empty() or get_node_or_null("/root/" + n) == null:
			continue
		out.append(n)
	out.sort()
	return out


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = d.get_next()
			continue
		var full := dir_path.path_join(entry)
		if d.current_is_dir():
			_collect(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()


## Strip the comment tail of a line without cutting inside a string literal, so
## a `#` in "res://..." or a printed "#%d" is not mistaken for a comment start.
func _strip_comment(line: String) -> String:
	var in_s := false
	var q := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if in_s:
			if c == "\\":
				i += 2
				continue
			if c == q:
				in_s = false
		elif c == "\"" or c == "'":
			in_s = true
			q = c
		elif c == "#":
			return line.substr(0, i)
		i += 1
	return line


func _scan_file(path: String, names: Array[String]) -> void:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return
	files_scanned += 1
	var text := fa.get_as_text()
	fa.close()
	var lines := text.split("\n")
	var re := RegEx.new()
	# `X.method(` not preceded by an identifier character, so `Foo.GameManager.x(`
	# or a local `my_GameManager.x(` is not treated as the autoload.
	re.compile("(?<![A-Za-z0-9_.])(%s)[.]([A-Za-z_][A-Za-z0-9_]*)[(]" % "|".join(names))
	for n in range(lines.size()):
		var code := _strip_comment(lines[n])
		if code.strip_edges().is_empty():
			continue
		for m in re.search_all(code):
			var owner_name: String = m.get_string(1)
			var method: String = m.get_string(2)
			call_sites += 1
			var node := get_node_or_null("/root/" + owner_name)
			if node == null or node.has_method(method):
				continue
			# has_method() feature-detect on this line or the one before it.
			var window := code
			if n > 0:
				window += "\n" + _strip_comment(lines[n - 1])
			if window.contains("has_method(\"%s\")" % method):
				guarded_count += 1
				continue
			misses.append({"file": path, "line": n + 1,
				"owner": owner_name, "method": method})


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _report() -> void:
	for miss in misses:
		print("  ✗ UNRESOLVED  %s.%s()  at %s:%d"
			% [miss["owner"], miss["method"], miss["file"], miss["line"]])
	if misses.is_empty():
		print("  (no unresolved call sites)")
	print("")
	# Controls: a scan that found nothing because it scanned nothing, or because
	# the regex matched nothing, would otherwise "pass".
	_check("control: scripts were scanned", files_scanned > 50,
		"%d files" % files_scanned)
	_check("control: autoload call sites were found", call_sites > 200,
		"%d call sites" % call_sites)
	_check("every autoload call site resolves on the live node",
		misses.is_empty(),
		"%d unresolved" % misses.size())
	# The two fixes this tool was written for.
	_check("GameManager.replay_current_minigame() exists (MiniGameResults RETRY)",
		GameManager.has_method("replay_current_minigame"))
	_check("GameManager tracks the launched scene basename for a replay",
		"last_launched_minigame_name" in GameManager,
		"round_scores holds the display name, which cannot build a scene path")
	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("")
	print("  %d call sites across %d scripts | %d has_method-guarded (advisory)"
		% [call_sites, files_scanned, guarded_count])
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [results.size() - failed, failed])
	print("═══════════════════════════════════════════════════════════")
	print("")
	Engine.get_main_loop().quit(1 if failed > 0 else 0)
