extends Node

## ═══════════════════════════════════════════════════════════════════
## VERIFY: THE ROUND'S IDENTITY IS THE SCENE ID, NOT THE DISPLAY TITLE
## ═══════════════════════════════════════════════════════════════════
## GameManager.complete_minigame() is handed MiniGameBase.game_name, which is the
## HUMAN TITLE ("Mud Pie Maker") and, in FixLeakV2, a LOCALIZED one
## (Localization.get_text("fix_leak") -> "Ayusin ang Tagas" in Filipino). That string
## was then used as an identity in four places: the completed set, SaveManager's
## per-game high-score record (whose parameter is named game_id), the algorithm's
## per-round log, and the minigame_completed signal — whose partner
## minigame_started has always emitted the SCENE ID off the random bag. Consequences,
## none of which crash:
##   * the signal pair is not joinable by any consumer (measured: SoakEditedGames had
##     to credit completions positionally because the two strings never matched);
##   * high_scores grows a second row for the same game when the player switches
##     language, so times_played and the best score split across "Fix Leak" and
##     "Ayusin ang Tagas";
##   * the thesis session export labels the same game differently per locale.
##
## Everything here is measured through a REAL autoplayed round: AutoPlayManager drives
## the game, the game calls end_game(), end_game() calls complete_minigame(). No call
## into complete_minigame() is made by this harness, because a harness calling it with
## the argument the fix adds would prove only that the harness can pass an argument.
##
## The language is set to FILIPINO for the whole run, which is what makes the
## difference observable at all: check [0] fails the run if the probe's title and id
## are equal, because then every other check here would pass vacuously.
##
## Usage:
##   godot --headless --path <project> res://tools/VerifyGameIdentity.tscn
## ═══════════════════════════════════════════════════════════════════

const RUN_SECONDS: float = 420.0
const PINNED: PackedStringArray = ["FixLeak", "MudPieMaker"]
const MIN_ROUNDS: int = 3


func _ready() -> void:
	print("[IDENTITY] boot")
	await get_tree().process_frame
	await get_tree().process_frame

	var gm := get_node_or_null("/root/GameManager")
	var sm := get_node_or_null("/root/SaveManager")
	var loc := get_node_or_null("/root/Localization")
	if gm == null or sm == null or loc == null:
		push_error("[IDENTITY] GameManager/SaveManager/Localization unavailable")
		get_tree().quit(1)
		return

	loc.set_language(loc.Language.FILIPINO)
	await get_tree().process_frame

	# [0] the premise. FixLeakV2 localizes its title, so in Filipino the title and the
	# scene id must differ — otherwise the run cannot tell the two apart and every
	# check below would pass for the wrong reason.
	var probe: Node = (load("res://scenes/minigames/FixLeak.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(probe)
	await get_tree().process_frame
	var probe_title: String = str(probe.get("game_name"))
	var probe_id: String = str(probe.call("_get_minigame_key"))
	probe.queue_free()
	await get_tree().process_frame
	print("[IDENTITY] [0] probe title=\"%s\" id=\"%s\"" % [probe_title, probe_id])
	if probe_title == probe_id:
		push_error("[IDENTITY] [0] VACUOUS: title and id are the same string")
		get_tree().quit(1)
		return

	var watcher := IdWatcher.new()
	watcher.name = "IdWatcher"
	watcher.roster_ids = PINNED
	watcher.probe_title = probe_title
	watcher.probe_id = probe_id
	watcher.sm = sm
	watcher.gm = gm
	watcher.apm = get_node_or_null("/root/AutoPlayManager")
	get_tree().root.add_child(watcher)

	gm.minigame_started.connect(watcher.on_started)
	gm.minigame_completed.connect(watcher.on_completed)

	# Baseline: rows already in the save from earlier play must not be counted as
	# evidence either way.
	for k in sm.high_scores.keys():
		watcher.pre_existing[str(k)] = true

	if watcher.apm:
		if watcher.apm.has_method("set_auto_play_duration"):
			watcher.apm.set_auto_play_duration(RUN_SECONDS / 60.0 + 1.0)
		watcher.apm.set_auto_play_enabled(true)

	_pin(gm)
	gm.start_session(0)  # GameMode.SINGLE_PLAYER
	_pin(gm)
	if gm.has_method("_rebuild_minigame_random_bag"):
		gm._rebuild_minigame_random_bag()
	print("[IDENTITY] pinned to %s" % str(gm.available_minigames))

	get_tree().create_timer(RUN_SECONDS).timeout.connect(watcher.report_and_quit)


func _pin(gm: Node) -> void:
	gm.available_minigames.clear()
	for game_id in PINNED:
		gm.available_minigames.append(game_id)


## Lives under /root, not in this scene: the session calls change_scene_to_file() and
## this harness IS the current scene, so a connection owned by it would be dropped
## along with the node (the lesson SoakEditedGames records).
class IdWatcher extends Node:
	var roster_ids: PackedStringArray = []
	var probe_title: String = ""
	var probe_id: String = ""
	var sm: Node = null
	var gm: Node = null
	var apm: Node = null
	var pre_existing: Dictionary = {}

	var _started: Array = []
	var _pairs: Array = []          # [{started, completed, results}]
	var _current: String = ""
	var _pass: int = 0
	var _fail: int = 0

	func _check(label: String, ok: bool, detail: String = "") -> void:
		if ok:
			_pass += 1
			print("  PASS  %s" % label)
		else:
			_fail += 1
			print("  FAIL  %s" % label)
		if detail != "":
			print("          %s" % detail)

	func on_started(game_id: String) -> void:
		_started.append(game_id)
		_current = game_id

	func on_completed(game_id: String, results: Dictionary) -> void:
		_pairs.append({"started": _current, "completed": game_id, "results": results})
		_current = ""

	func report_and_quit() -> void:
		# AutoPlayManager persists its flag into the save, so it goes back off before
		# quit or the next real session has the AI holding the controls.
		if apm and apm.has_method("set_auto_play_enabled"):
			apm.set_auto_play_enabled(false)
		print("\n=== VERIFY GAME IDENTITY ===")
		print("[IDENTITY] %d start(s), %d completion(s)" % [_started.size(), _pairs.size()])
		_check("[1] enough rounds actually completed to judge", _pairs.size() >= MIN_ROUNDS,
			"%d completion(s)" % _pairs.size())

		# [2] joinable pair: the string coming out of the completion is the string that
		# went in on the start. This is what no consumer could rely on before.
		var mismatched: PackedStringArray = []
		for p in _pairs:
			if str(p["completed"]) != str(p["started"]):
				mismatched.append("started \"%s\" -> completed \"%s\"" % [p["started"], p["completed"]])
		_check("[2] minigame_completed joins minigame_started", mismatched.is_empty(),
			"%d mismatched: %s" % [mismatched.size(), ", ".join(mismatched)])

		# [3] the emitted id is a scene id, so it is in the pinned roster and carries no
		# spaces. "Mud Pie Maker" fails both halves; "MudPieMaker" passes.
		var not_id: PackedStringArray = []
		for p in _pairs:
			var c: String = str(p["completed"])
			if c.contains(" ") or not (c in roster_ids):
				not_id.append("\"%s\"" % c)
		_check("[3] the emitted identity is a scene id", not_id.is_empty(),
			"%d not an id: %s" % [not_id.size(), ", ".join(not_id)])

		# [4] the results payload still carries the DISPLAY title for the UI, alongside
		# the id. Dropping the title would have been a regression: MiniGameResults and
		# DevStats read a human name.
		var bad_payload: PackedStringArray = []
		for p in _pairs:
			var r: Dictionary = p["results"]
			var disp: String = str(r.get("game_name", ""))
			var rid: String = str(r.get("game_id", ""))
			if disp.is_empty() or rid != str(p["completed"]):
				bad_payload.append("game_name=\"%s\" game_id=\"%s\"" % [disp, rid])
		_check("[4] results carries both the id and a display title", bad_payload.is_empty(),
			"%d bad: %s" % [bad_payload.size(), ", ".join(bad_payload)])

		# [5] the save is keyed by the id. The localized title must not appear as a key
		# at all: that is the row that would split a player's record on a language change.
		var played: Dictionary = {}
		for p in _pairs:
			played[str(p["completed"])] = true
		var missing_rows: PackedStringArray = []
		for k in played:
			if not sm.high_scores.has(str(k)):
				missing_rows.append(str(k))
		var title_rows: PackedStringArray = []
		for k in sm.high_scores.keys():
			var ks: String = str(k)
			if pre_existing.has(ks):
				continue
			if ks.contains(" "):
				title_rows.append("\"%s\"" % ks)
		_check("[5] every played round has a high-score row under its id",
			missing_rows.is_empty(),
			"%d missing: %s (rows now: %s)" % [missing_rows.size(),
				", ".join(missing_rows), str(sm.high_scores.keys())])
		_check("[6] no NEW high-score row is keyed by a display title",
			title_rows.is_empty(),
			"%d title row(s): %s" % [title_rows.size(), ", ".join(title_rows)])

		# [7] the same for GameManager's own completed set, which gates nothing today but
		# is saved and read back as a list of ids.
		var bad_completed: PackedStringArray = []
		for e in gm.completed_minigames:
			if str(e).contains(" "):
				bad_completed.append("\"%s\"" % str(e))
		_check("[7] completed_minigames holds ids, not titles", bad_completed.is_empty(),
			"%d title(s): %s" % [bad_completed.size(), ", ".join(bad_completed)])

		# [8] the localized title is still what the PLAYER sees — the fix moved the
		# identity, it did not un-localize the game.
		_check("[8] the display title is still localized",
			probe_title != probe_id and probe_title.strip_edges() != "",
			"title=\"%s\" id=\"%s\"" % [probe_title, probe_id])

		print("\n=== %d passed, %d failed ===" % [_pass, _fail])

		# Leave /root the way it was found before asking the tree to quit.
		#
		# This watcher outlives the harness scene on purpose (see the class comment), so at
		# teardown it is still parented to /root and still connected to two GameManager
		# signals, holding references to three autoloads the engine is about to free. Runs of
		# this harness ended in "ERROR: BUG: Unreferenced static string to 0" from
		# core/string/string_name.cpp, and one run ended in "CrashHandlerException: Program
		# crashed with signal 11" - both AFTER "=== 8 passed, 0 failed ===" had printed, so the
		# verdict was never in doubt, only the exit. Disconnecting and freeing first costs one
		# frame and takes this harness out of an undefined teardown order.
		if gm:
			if gm.minigame_started.is_connected(on_started):
				gm.minigame_started.disconnect(on_started)
			if gm.minigame_completed.is_connected(on_completed):
				gm.minigame_completed.disconnect(on_completed)
		sm = null
		gm = null
		apm = null
		# Order matters, and getting it wrong cost a whole run: queue_free() BEFORE the await
		# deleted this node in the same frame the await was waiting on, so the coroutine never
		# resumed and tree.quit() was never reached. The verdict had already printed, the game
		# just kept playing (the log shows StoryScreen.tscn loading after "8 passed, 0 failed")
		# until the outer timeout killed it at rc=124. Detach, spend the frame while still
		# alive, then ask for both the deletion and the quit - SceneTree flushes its deletion
		# queue at the end of this frame and acts on quit() after the iteration, in that order.
		var tree: SceneTree = get_tree()
		get_parent().remove_child(self)
		await tree.process_frame
		queue_free()
		tree.quit(0 if _fail == 0 else 1)
