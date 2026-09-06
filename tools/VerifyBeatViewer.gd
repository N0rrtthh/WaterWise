extends Node

## BeatViewer is the dev tool that plays authored beat clips straight from Settings, and its
## playback is a coroutine: _play_clip() awaits process_frame until the clip reports finished or a
## 10 s wall-clock cap expires, then runs a tail that hides preview_holder, clears _playing and
## unlocks the buttons.
##
## STOP frees the clip and unlocks the buttons immediately, but the coroutine keeps awaiting until
## it notices - one frame later, when queue_free() takes effect. Anything started inside that frame
## is running when the OLD coroutine's tail fires, and that tail hides the holder and unlocks the
## buttons under it: the new clip plays invisibly while the UI claims nothing is playing.
##
## The three claims below are the state a user can see: a clip on screen while playing, a clip
## still on screen after STOP-then-play, and a clean idle state once it ends.

const VIEWER := "res://scenes/ui/BeatViewer.tscn"

var _pass: int = 0
var _fail: int = 0

func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [ok]   %s%s" % [label, "" if detail.is_empty() else "  " + detail])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [label, "" if detail.is_empty() else "  " + detail])

func _ready() -> void:
	await get_tree().process_frame
	print("\n=== VerifyBeatViewer ===")
	var packed: PackedScene = load(VIEWER)
	if packed == null:
		_check(false, "BeatViewer loads")
		get_tree().quit(1)
		return
	var v := packed.instantiate()
	add_child(v)
	await get_tree().process_frame

	_listing_claims(v)

	# Pick the first listed game that actually has a win clip, the way a user would.
	var games: Array = v.get("_games")
	var pick: String = ""
	var pick_i: int = -1
	for i in range(games.size()):
		if String(v.call("_clip_path", String(games[i]), "WinOutro")) != "":
			pick = String(games[i])
			pick_i = i
			break
	_check(pick != "", "the viewer lists a game with an authored win clip", pick)
	if pick == "":
		get_tree().quit(1)
		return
	var holder: Control = v.get("preview_holder")
	v.get("game_list").call("select", pick_i)
	v.call("_on_game_selected", pick_i)

	# CLAIM 1 (control) - a plain playback puts a clip on screen and locks the UI.
	v.call("_play_clip", pick, "WinOutro", "play_win")
	await get_tree().process_frame
	_check(holder.get_child_count() == 1 and holder.visible and bool(v.get("_playing")),
		"a playing clip is on screen and the UI is locked",
		"children=%d visible=%s _playing=%s" % [holder.get_child_count(), holder.visible, v.get("_playing")])

	# CLAIM 2 - STOP, then start another clip in the SAME frame. The first coroutine is still
	# awaiting; its tail must not touch the second clip's state.
	v.call("_stop_preview")
	v.call("_play_clip", pick, "LoseOutro", "play_lose")
	var alive_after: int = 0
	var visible_after: bool = true
	var locked_after: bool = true
	# Three frames is past the point the stale coroutine notices its clip is gone and runs its tail.
	for _i in range(3):
		await get_tree().process_frame
		alive_after = holder.get_child_count()
		visible_after = visible_after and holder.visible
		locked_after = locked_after and bool(v.get("_playing"))
	_check(alive_after >= 1 and visible_after and locked_after,
		"a clip started right after STOP keeps playing and stays visible",
		"children=%d holder stayed visible=%s stayed locked=%s" % [alive_after, visible_after, locked_after])

	# CLAIM 3 - once that clip really ends, the viewer returns to a usable idle state.
	var t0: float = Time.get_ticks_msec() / 1000.0
	while bool(v.get("_playing")) and Time.get_ticks_msec() / 1000.0 - t0 < 15.0:
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not bool(v.get("_playing")) and not holder.visible and holder.get_child_count() == 0,
		"the viewer returns to idle after the clip ends",
		"_playing=%s visible=%s children=%d" % [v.get("_playing"), holder.visible, holder.get_child_count()])
	var stop_btn: Button = v.get("stop_button")
	var back_btn: Button = v.get("back_button")
	_check(stop_btn.disabled and not back_btn.disabled,
		"idle leaves STOP disabled and Back usable",
		"stop.disabled=%s back.disabled=%s" % [stop_btn.disabled, back_btn.disabled])

	v.queue_free()
	await get_tree().process_frame
	print("=== %d passed / %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


## -- THE REPORTED DEFECT ---------------------------------------------------------------
## "Beat Viewer renders empty on mobile."
##
## Nothing was wrong with the rendering. The list was built by walking res://scenes/minigames
## with DirAccess and keeping names that end with ".tscn", and an exported Android build has no
## ".tscn" in it: convert_text_resources_to_binary (the engine default, unset in project.godot)
## stores each scene as a binary Foo.scn plus a Foo.tscn.remap stub. The filter matched zero
## entries, so the ItemList had no rows and every control under it had nothing to act on.
##
## Headless cannot BE an exported build, so the export condition is reproduced where it
## actually bites: _collect_game_names() takes the directory listing as an argument, and these
## rows hand it the exact spelling a PCK reports. Each row that measures the fix is paired with
## the count the OLD filter would have produced from the same input, so none of them can pass
## vacuously.
func _listing_claims(v: Node) -> void:
	var on_disk := _disk_scene_names()
	_check(on_disk.size() >= 20, "the harness found the minigame scenes to compare against",
		"%d .tscn under res://scenes/minigames" % on_disk.size())

	# CLAIM A - the screen a user opens is populated, and populated with everything the old
	# directory scan used to find. This is what "renders empty" was about.
	var listed: Array = v.get("_games")
	var item_count: int = int(v.get("game_list").call("get_item_count"))
	_check(listed.size() == on_disk.size() and item_count == listed.size(),
		"the viewer lists every minigame scene on disk, one row each",
		"%d names, %d rows, %d scenes on disk" % [listed.size(), item_count, on_disk.size()])
	var missing: Array[String] = []
	for n in on_disk:
		if not listed.has(n):
			missing.append(n)
	_check(missing.is_empty(), "no scene on disk is missing from the list",
		"missing: %s" % ("none" if missing.is_empty() else ", ".join(missing)))

	# CLAIM B - the defect itself. Feed the population path exactly what an EXPORTED build
	# reports for that folder: Foo.scn for the converted scene, plus its Foo.tscn.remap stub.
	var exported := PackedStringArray()
	for n in on_disk:
		exported.append("%s.scn" % n)
		exported.append("%s.tscn.remap" % n)
	var old_hits: int = 0
	for f in exported:
		if String(f).ends_with(".tscn"):
			old_hits += 1
	_check(old_hits == 0,
		"the old ends_with(\".tscn\") filter really matches nothing in an exported build",
		"%d of %d exported entries matched - this is why the list was empty"
			% [old_hits, exported.size()])
	var from_export: Array = v.call("_collect_game_names", exported)
	_check(from_export.size() == on_disk.size() and from_export == listed,
		"fed an exported build's file names, the list comes out complete anyway",
		"%d names from %d exported entries" % [from_export.size(), exported.size()])

	# CLAIM C - the other export failure mode: the folder cannot be walked at all. The list is
	# seeded from constants that are present in every build, so an unreadable folder costs
	# nothing, where it used to replace the whole screen with "Cannot open res://...".
	var from_nothing: Array = v.call("_collect_game_names", PackedStringArray())
	_check(from_nothing == listed, "with no directory listing at all the list is still complete",
		"%d names from an empty listing" % from_nothing.size())

	# CLAIM D - and the list stays honest: a name the listing offers with no scene behind it is
	# dropped, because every candidate is confirmed with ResourceLoader.exists().
	var junk := PackedStringArray(["NotAGame.scn", "AlsoNotAGame.tscn.remap", "README.md", "x.gd"])
	var reduced := String(v.call("_scene_base_name", "NotAGame.scn"))
	_check(reduced == "NotAGame",
		"the junk row is dropped by the scene check, not by a suffix miss",
		"\"NotAGame.scn\" reduces to \"%s\"" % reduced)
	var with_junk: Array = v.call("_collect_game_names", junk)
	_check(with_junk == listed, "a listed file with no scene behind it never reaches the list",
		"%d names from 4 bogus entries" % with_junk.size())

	# CLAIM E - every spelling a build can hand over reduces to the same game name, and a file
	# that is not a scene reduces to nothing.
	var pick_name: String = String(on_disk[0])
	var spellings := {
		"%s.tscn" % pick_name: pick_name,
		"%s.scn" % pick_name: pick_name,
		"%s.tscn.remap" % pick_name: pick_name,
		"%s.scn.remap" % pick_name: pick_name,
		"%s.gd" % pick_name: "",
		"%s.png.import" % pick_name: "",
	}
	var bad: Array[String] = []
	for spelling in spellings:
		var got := String(v.call("_scene_base_name", spelling))
		if got != String(spellings[spelling]):
			bad.append("%s -> \"%s\" (want \"%s\")" % [spelling, got, String(spellings[spelling])])
	_check(bad.is_empty(),
		"all four scene spellings reduce to the game name, non-scenes to nothing",
		"failures: %s" % ("none" if bad.is_empty() else "; ".join(bad)))

	# CLAIM F - the union of two sources must not blur the SP/MP tag the rows are read by.
	# RainwaterHarvesting is the co-op-only scene and the one name the single-player pool does
	# not contain, so it is both the tag check and the check that the extra source is unioned in.
	_check(listed.has("RainwaterHarvesting"),
		"the multiplayer-only scene is listed even though it is not in the single-player pool")
	var mp_row := _row_text(v, "RainwaterHarvesting")
	var sp_row := _row_text(v, "WringItOut")
	_check(mp_row.contains("[MP]") and sp_row.contains("[SP]"),
		"the rows still carry the right SP/MP tag",
		"\"%s\" / \"%s\"" % [mp_row, sp_row])

	# CLAIM G - and every row can actually be acted on: the buttons below load these paths.
	var unloadable: Array[String] = []
	for n in listed:
		if not ResourceLoader.exists("res://scenes/minigames/%s.tscn" % String(n)):
			unloadable.append(String(n))
	_check(unloadable.is_empty(), "every listed game resolves to a scene that loads",
		"unresolvable: %s" % ("none" if unloadable.is_empty() else ", ".join(unloadable)))


## The reference truth for the rows above, read the way the OLD code read it - which is correct
## here, because this harness runs against the source tree, where a .tscn really is a .tscn.
func _disk_scene_names() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("res://scenes/minigames")
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".tscn"):
			out.append(f.trim_suffix(".tscn"))
		f = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _row_text(v: Node, game: String) -> String:
	var list: ItemList = v.get("game_list")
	for i in range(list.get_item_count()):
		if list.get_item_text(i).begins_with(game):
			return list.get_item_text(i)
	return ""
