extends Node

## ═══════════════════════════════════════════════════════════════════
## STORY GATE — "the intro plays every time Play is pressed"
## ═══════════════════════════════════════════════════════════════════
##
## THE DEFECT
##   StoryScreen.get_next_unlocked_chapter() chose its chapter with
##
##       var chapter_index = (games_played / 5) % _chapters.size()
##
##   where games_played is GameManager.minigames_played_this_session — a counter that is 0 at
##   every launch. Integer division makes the answer index 0 for the first five games of a
##   session, so every press of Play on a fresh process opened "The Waking River". Nothing on
##   disk recorded having told the story, so nothing could distinguish "the intro" from "the
##   intro again". _story_shown_at, the only memory in play, is session-local too.
##
##   The same line hides a second bug the report did not name: a player who plays fewer than
##   five games at a sitting can never reach index 1, so chapters 2–6 are unreachable in normal
##   play. Both symptoms are that one expression, and both are fixed by the same change —
##   chapters are handed out one at a time, in order, and the record is the save file.
##
## WHAT IS MEASURED HERE
##   1. the fix is not the old arithmetic in disguise: the chapter chosen does NOT move with
##      minigames_played_this_session, and DOES move when a chapter is marked read.
##   2. reading a chapter to the end records it, and the record reaches the JSON on disk —
##      re-parsed from the file, not trusted from memory, because surviving the process is the
##      whole point.
##   3. the mark happens BEFORE _finish_story()'s fade-out await, so the caller freeing the
##      overlay the instant story_finished fires cannot lose it (a killed tween never emits
##      `finished`). Measured by freeing the screen in that exact window.
##   4. the safety timer's auto-advance path records it too, and firing both paths appends the
##      id once, not twice.
##   5. an exhausted story creates no overlay at all: GameManager._should_show_story() answers
##      false rather than letting a black CanvasLayer be parented for the frame it takes
##      _show_current_page() to notice {}.
##   6. the cadence for the chapters that are still unread is unchanged — intro at 0, then every
##      5 games, and not twice at the same count.
##   7. an OLD save with no "story_chapters" key loads as "nothing read yet" and needs no
##      SAVE_VERSION bump.
##   8. the static id reader agrees with the chapters the screen actually loads, so the gate and
##      the selector can never disagree about what "all read" means.
##   9. a chapter read inside Game Lab does not leak into the real profile — the sandbox already
##      snapshots unlocked_content, and this asserts that covers the new key.
##
## NOT MEASURED HERE (needs the device)
##   That the story looks right. This is about whether it is shown at all.
##
## The real user:// save is copied aside before the first write and put back at the end.
##
## Usage:
##   godot --headless --path . res://tools/VerifyStoryGate.tscn

const STORY_SCENE: String = "res://scenes/ui/StoryScreen.tscn"
const STORY_SCRIPT: String = "res://scenes/ui/StoryScreen.gd"
const SAVE_PATH: String = "user://waterwise_save.json"
const BAK_SAVE: String = "user://waterwise_save.storygate_bak"

var _pass: int = 0
var _fail: int = 0
var _save_existed: bool = false


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


# ── user:// save custody ────────────────────────────────────────────
## Every check below writes the real save file. It is copied aside first and put back at the
## end, restored to "absent" if it was absent, so running this harness cannot cost a tester
## their droplets.
func _backup_save() -> void:
	_save_existed = FileAccess.file_exists(SAVE_PATH)
	if _save_existed:
		DirAccess.copy_absolute(SAVE_PATH, BAK_SAVE)
	print("  [custody] real save present=%s" % str(_save_existed))


func _restore_save() -> void:
	if _save_existed and FileAccess.file_exists(BAK_SAVE):
		DirAccess.copy_absolute(BAK_SAVE, SAVE_PATH)
		DirAccess.remove_absolute(BAK_SAVE)
	elif not _save_existed:
		DirAccess.remove_absolute(SAVE_PATH)
	print("  [custody] real save restored")


## Nothing read yet, in memory and on disk.
func _clear_seen() -> void:
	SaveManager.unlocked_content["story_chapters"] = []
	SaveManager.save_now()


func _seen_list() -> Array:
	return SaveManager.unlocked_content.get("story_chapters", [])


## The seen list as the FILE has it, re-parsed. Memory is not evidence of persistence.
func _seen_on_disk() -> Array:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return []
	var raw := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK or not (json.data is Dictionary):
		return []
	var unlocked: Variant = (json.data as Dictionary).get("unlocked", {})
	if not (unlocked is Dictionary):
		return []
	var ids: Variant = (unlocked as Dictionary).get("story_chapters", [])
	return ids if ids is Array else []


## A live screen, its chapter already chosen, parked outside the tree's story flow.
func _new_screen() -> Node:
	var s: Node = load(STORY_SCENE).instantiate()
	add_child(s)
	await _frames(2)
	return s


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== Story gate: is the intro shown once, or at every press of Play? ===")

	if SaveManager == null or GameManager == null:
		print("  FAIL  SaveManager/GameManager autoload missing")
		get_tree().quit(1)
		return
	GameManager.sandbox_mode = false
	_backup_save()

	await _ids_row()
	await _selection_rows()
	await _finish_rows()
	await _fade_window_row()
	await _safety_timer_rows()
	await _gate_rows()
	await _old_save_row()
	await _sandbox_row()

	_restore_save()
	print("")
	print("  -- on-device row, not measurable headless --")
	print("     Press Play twice in one install and confirm the story does not open the second")
	print("     time. The evidence in the exported log is a single StoryScreen.tscn load.")
	print("")
	print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## The gate (GameManager) and the selector (StoryScreen) must agree about what "all read" means,
## or one of them stops working: a gate that knows about fewer ids than the screen can show would
## suppress chapters that are still unread.
func _ids_row() -> void:
	print("")
	print("  -- the chapter list --")
	var script: GDScript = load(STORY_SCRIPT)
	var ids: Array = script.read_chapter_ids()
	_check("the static id reader finds the authored chapters",
		ids.size() >= 1, "ids: %s" % str(ids))

	var screen: Node = await _new_screen()
	var loaded: Array = screen.get("_chapters")
	var loaded_ids: Array[String] = []
	for c in loaded:
		if c is Dictionary:
			loaded_ids.append(str((c as Dictionary).get("id", "")))
	_check("it agrees exactly with the chapters the screen itself loads, in order",
		str(ids) == str(loaded_ids),
		"reader %s vs screen %s" % [str(ids), str(loaded_ids)])
	_check("every chapter has an id, so every chapter can be recorded as read",
		not loaded_ids.has(""), "ids: %s" % str(loaded_ids))
	screen.queue_free()
	await _frames(2)


## The heart of it. The old expression was (minigames_played_this_session / 5) % size, so the
## answer moved with a per-session counter and never with anything the player had actually read.
## These rows assert the reverse of both halves.
func _selection_rows() -> void:
	print("")
	print("  -- which chapter is chosen, and what moves it --")
	_clear_seen()
	var script: GDScript = load(STORY_SCRIPT)
	var ids: Array = script.read_chapter_ids()

	var screen: Node = await _new_screen()
	var first_at_0: String = str(screen.call("get_next_unlocked_chapter").get("id", ""))
	_check("with nothing read the first chapter is the one offered",
		first_at_0 == str(ids[0]), "offered %s, expected %s" % [first_at_0, str(ids[0])])

	# The old code's own input. At 5 it returned index 1, at 10 index 2; if any of these three
	# differ now, the session counter is still steering the choice.
	var seen_at: Array[String] = []
	for count in [0, 3, 5, 12]:
		GameManager.minigames_played_this_session = count
		seen_at.append(str(screen.call("get_next_unlocked_chapter").get("id", "")))
	GameManager.minigames_played_this_session = 0
	var all_same: bool = true
	for s in seen_at:
		if s != first_at_0:
			all_same = false
	_check("the choice does not move with minigames_played_this_session (the old bug's input)",
		all_same, "at 0/3/5/12 games played: %s" % str(seen_at))

	# ...and the thing that DOES move it is the record of having read one. Note the counter is
	# still 0 here: under the old arithmetic index 0 was the only reachable answer at 0 games,
	# which is exactly why a player who plays three games a night saw one chapter forever.
	SaveManager.mark_story_chapter_seen(str(ids[0]))
	var second: String = str(screen.call("get_next_unlocked_chapter").get("id", ""))
	_check("reading the first chapter advances the offer to the second",
		second == str(ids[1]) if ids.size() > 1 else second == "",
		"offered %s after reading %s (games played still 0)" % [second, str(ids[0])])

	for id in ids:
		SaveManager.mark_story_chapter_seen(str(id))
	var exhausted: Dictionary = screen.call("get_next_unlocked_chapter")
	_check("with every chapter read the screen offers nothing rather than looping to the start",
		exhausted.is_empty(), "offered: %s" % str(exhausted.get("id", "<empty>")))
	screen.queue_free()
	await _frames(2)


## Tap through every page of the current chapter the way a player does — through advance_page(),
## the entry _input() calls — waiting out the per-page fade-in each time, because _advance_page()
## ignores a tap while _is_animating. The clock is compressed rather than the gate bypassed: at
## 0.9 s of animation per page a real-time run would spend seconds waiting to prove nothing.
func _drive_to_end(screen: Node, max_pages: int = 24) -> void:
	var old_scale: float = Engine.time_scale
	Engine.time_scale = 8.0
	var guard: int = 0
	while not bool(screen.get("_is_finishing")) and guard < max_pages:
		var spins: int = 0
		while bool(screen.get("_is_animating")) and spins < 600:
			await get_tree().process_frame
			spins += 1
		if bool(screen.get("_is_finishing")):
			break
		screen.call("advance_page")
		guard += 1
	Engine.time_scale = old_scale


## Spin, clock compressed, until a one-element flag array goes true or the frames run out.
func _await_flag(flag: Array, max_frames: int) -> void:
	var old_scale: float = Engine.time_scale
	Engine.time_scale = 8.0
	var spins: int = 0
	while not bool(flag[0]) and spins < max_frames:
		await get_tree().process_frame
		spins += 1
	Engine.time_scale = old_scale


## Reading a chapter to its last page has to reach the disk. In memory is not enough: the process
## the player is in is exactly the one that ends before the next press of Play.
func _finish_rows() -> void:
	print("")
	print("  -- reading a chapter to the end --")
	_clear_seen()
	var ids: Array = (load(STORY_SCRIPT) as GDScript).read_chapter_ids()
	var target: String = str(ids[0])

	var screen: Node = await _new_screen()
	var finished: Array[bool] = [false]
	screen.connect("story_finished", func(): finished[0] = true)
	_check("the screen opened on the chapter that was unread",
		str((screen.get("_current_chapter") as Dictionary).get("id", "")) == target,
		"opened %s" % str((screen.get("_current_chapter") as Dictionary).get("id", "")))
	_check("and nothing was recorded merely by opening it",
		not SaveManager.is_story_chapter_seen(target), "seen list: %s" % str(_seen_list()))

	await _drive_to_end(screen)
	# story_finished arrives on the far side of _finish_story()'s 0.5 s fade, so this waits for
	# the signal instead of a fixed handful of frames - which measured _is_finishing=true with
	# story_finished=false, i.e. the harness asking before the answer existed.
	await _await_flag(finished, 900)
	_check("tapping through to the last page finishes the story",
		finished[0] and bool(screen.get("_is_finishing")),
		"story_finished=%s _is_finishing=%s" % [str(finished[0]), str(screen.get("_is_finishing"))])
	_check("the chapter is recorded as read",
		SaveManager.is_story_chapter_seen(target), "seen list: %s" % str(_seen_list()))

	SaveManager.save_now()
	_check("the record reaches the save file on disk, re-parsed from it",
		_seen_on_disk().has(target), "file says: %s" % str(_seen_on_disk()))

	# The other half of persistence: a fresh boot has to read it back. unlocked_content is
	# emptied in memory first, so a pass here cannot come from the value still sitting there.
	SaveManager.unlocked_content["story_chapters"] = []
	SaveManager.load_all_data()
	_check("a reload from that file reports the chapter as read (survives the process)",
		SaveManager.is_story_chapter_seen(target), "after reload: %s" % str(_seen_list()))
	screen.queue_free()
	await _frames(2)


## The trap this fix could easily have walked into. _finish_story() fades the screen out with a
## tween and awaits it, and GameManager frees the whole StoryScreenLayer the moment
## story_finished arrives. A tween killed by that free never emits `finished`, so any write
## placed after the await is not guaranteed to run — the chapter would go unrecorded exactly on
## the runs where the player did read it, and the intro would come back. Measured by freeing the
## screen inside that window instead of trusting the ordering by reading it.
func _fade_window_row() -> void:
	print("")
	print("  -- the fade-out window --")
	_clear_seen()
	var ids: Array = (load(STORY_SCRIPT) as GDScript).read_chapter_ids()
	var target: String = str(ids[0])

	var screen: Node = await _new_screen()
	_check("the screen is on the unread chapter before the window opens",
		str((screen.get("_current_chapter") as Dictionary).get("id", "")) == target,
		"chapter %s" % str((screen.get("_current_chapter") as Dictionary).get("id", "")))

	# _finish_story() starts the fade and suspends. Freeing here is what the caller does.
	screen.call("_finish_story")
	_check("the mark is already in place before the fade has finished (recorded first, faded second)",
		SaveManager.is_story_chapter_seen(target), "seen list mid-fade: %s" % str(_seen_list()))
	# queue_free, because that is precisely what GameManager's story_finished handler does to the
	# layer this screen sits in.
	screen.queue_free()
	await _frames(4)
	_check("and it survives the overlay being freed mid-fade",
		SaveManager.is_story_chapter_seen(target), "seen list after free: %s" % str(_seen_list()))
	SaveManager.save_now()
	_check("a chapter cut short by that free is still on disk",
		_seen_on_disk().has(target), "file says: %s" % str(_seen_on_disk()))


## The mobile safety timer auto-advances a screen that looks stuck after 30 s. A player who sat
## through the story once and never tapped the last page should not be shown it again, so that
## path has to record too — and it must not double-record when a tap and the timer race.
func _safety_timer_rows() -> void:
	print("")
	print("  -- the 30 s auto-advance path --")
	_clear_seen()
	var ids: Array = (load(STORY_SCRIPT) as GDScript).read_chapter_ids()
	var target: String = str(ids[0])

	var screen: Node = await _new_screen()
	screen.call("_start_safety_timer")
	await _frames(2)
	var timer: Timer = screen.get("_safety_timer") as Timer
	_check("the safety timer exists and is the 30 s one-shot",
		timer != null and timer.one_shot and is_equal_approx(timer.wait_time, 30.0),
		"timer=%s wait=%.1f" % [str(timer != null), 0.0 if timer == null else timer.wait_time])
	var conns: Array = [] if timer == null else timer.timeout.get_connections()
	_check("something is listening to it, so it can auto-advance at all",
		conns.size() >= 1, "%d connection(s)" % conns.size())
	if conns.size() >= 1:
		# Fire the timer's own callable rather than waiting 30 s of wall clock.
		(conns[0]["callable"] as Callable).call()
		await _frames(2)
		_check("the auto-advance records the chapter as read",
			SaveManager.is_story_chapter_seen(target), "seen list: %s" % str(_seen_list()))
		# The race: the timer fires, then the player's tap lands. One id, not two.
		screen.call("_finish_story")
		screen.call("_advance_page")
		await _frames(2)
		var hits: int = 0
		for id in _seen_list():
			if str(id) == target:
				hits += 1
		_check("a tap arriving after the timer does not record the same chapter twice",
			hits == 1, "%d copies of %s in %s" % [hits, target, str(_seen_list())])
	screen.queue_free()
	await _frames(2)


## GameManager's half. Once the story is used up no overlay should be built at all: the screen
## would notice {} and emit story_finished, but only after a full-screen CanvasLayer at layer 200
## had been parented and drawn for a frame. On the reported device that frame is a visible black
## flash between pressing Play and the game appearing.
func _gate_rows() -> void:
	print("")
	print("  -- whether an overlay is created at all --")
	var ids: Array = (load(STORY_SCRIPT) as GDScript).read_chapter_ids()

	_clear_seen()
	GameManager.minigames_played_this_session = 0
	GameManager._story_shown_at.clear()
	_check("with the story unread, the intro is still shown at the first Play",
		bool(GameManager._should_show_story()), "seen list: %s" % str(_seen_list()))

	GameManager._story_shown_at.append(0)
	_check("and not a second time at the same count in one session",
		not bool(GameManager._should_show_story()), "_story_shown_at: %s"
			% str(GameManager._story_shown_at))

	GameManager._story_shown_at.clear()
	GameManager.minigames_played_this_session = 3
	_check("the every-5-games cadence for unread chapters is unchanged (3 games: no)",
		not bool(GameManager._should_show_story()), "at 3 games played")
	GameManager.minigames_played_this_session = 5
	_check("...and fires on the fifth (5 games: yes)",
		bool(GameManager._should_show_story()), "at 5 games played")

	for id in ids:
		SaveManager.mark_story_chapter_seen(str(id))
	var suppressed: Array[int] = []
	for count in [0, 5, 10, 15]:
		GameManager.minigames_played_this_session = count
		GameManager._story_shown_at.clear()
		if bool(GameManager._should_show_story()):
			suppressed.append(count)
	_check("with all %d chapters read no overlay is created, at any cadence point" % ids.size(),
		suppressed.is_empty(),
		"story would still be shown at games played: %s" % str(suppressed))
	GameManager.minigames_played_this_session = 0
	GameManager._story_shown_at.clear()

	# Vacuity guard for the row above: unread the last chapter and the gate must open again, or
	# the suppression could just as well be a gate that is stuck shut.
	SaveManager.unlocked_content["story_chapters"] = ids.slice(0, ids.size() - 1)
	_check("unreading one chapter opens the gate again (the suppression is not a stuck gate)",
		bool(GameManager._should_show_story()),
		"seen %d of %d chapters" % [ids.size() - 1, ids.size()])


## An install from before this change has no "story_chapters" key at all. It must read back as
## "nothing read yet" — not crash, and not be mistaken for a finished story — and it must not need
## a SAVE_VERSION bump, since _merge_data() installs every key under "unlocked" generically.
func _old_save_row() -> void:
	print("")
	print("  -- an old save with no story record --")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"save_version": 1,
		"player": {"water_droplets": 42, "games_played": 9},
		"high_scores": {},
		"sp_session_scores": [],
		"unlocked": {
			"characters": ["droppy_blue"], "minigames": ["catch_rain"],
			"themes": ["default"], "accessories": ["character_default"]
		},
		"achievements": {}
	}, "\t"))
	f.close()
	# The key is ERASED rather than set to a stale value, and that distinction is measured
	# semantics, not fussiness. _merge_data() installs the "unlocked" block key by key over
	# whatever is already in memory, so a key absent from the file keeps its in-memory value -
	# true of decorations and accessories as much as of this one. Setting a stale non-empty list
	# here would therefore fail, and it would be testing a shape the app cannot reach:
	# load_all_data() is called once, from _ready(), before anything can have marked a chapter.
	# Erasing the key instead reproduces the shape that IS reachable - a build whose store never
	# had the key - and is what _ensure_story_defaults() exists to answer.
	SaveManager.unlocked_content.erase("story_chapters")
	SaveManager.load_all_data()
	_check("the key is back-filled as empty rather than left missing",
		SaveManager.unlocked_content.has("story_chapters")
			and (SaveManager.unlocked_content["story_chapters"] as Array).is_empty(),
		"story_chapters = %s" % str(_seen_list()))
	_check("so an old install is told it has read nothing, and sees the intro once",
		not SaveManager.is_story_chapter_seen("ch1_awakening")
			and bool(GameManager._should_show_story()),
		"seen=%s should_show=%s" % [str(SaveManager.is_story_chapter_seen("ch1_awakening")),
			str(GameManager._should_show_story())])
	_check("and the rest of that old save still loaded (no version bump was needed)",
		int(SaveManager.player_data.get("water_droplets", 0)) == 42,
		"droplets %s" % str(SaveManager.player_data.get("water_droplets", 0)))

	# The same old file loaded on top of the shipping defaults - the actual boot shape, key
	# declared and empty, file silent about it.
	SaveManager.unlocked_content["story_chapters"] = []
	SaveManager.load_all_data()
	_check("the shipping default survives that load too, so nothing reads as pre-seen",
		(SaveManager.unlocked_content["story_chapters"] as Array).is_empty(),
		"story_chapters = %s" % str(_seen_list()))


## Game Lab is a sandbox: nothing done in it may reflect on the real profile. The story record is
## a new key in unlocked_content, so this asks whether the existing snapshot/restore covers it
## rather than assuming it does.
func _sandbox_row() -> void:
	print("")
	print("  -- Game Lab must not consume a chapter --")
	_clear_seen()
	SaveManager.sandbox_snapshot()
	GameManager.sandbox_mode = true
	SaveManager.mark_story_chapter_seen("ch1_awakening")
	SaveManager.save_now()
	_check("a chapter read inside the Lab never reaches the file",
		not _seen_on_disk().has("ch1_awakening"), "file says: %s" % str(_seen_on_disk()))
	GameManager.sandbox_mode = false
	SaveManager.sandbox_restore()
	_check("and leaving the Lab hands the real seen-list back untouched",
		not SaveManager.is_story_chapter_seen("ch1_awakening"),
		"seen list after restore: %s" % str(_seen_list()))
