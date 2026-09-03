extends Node

## ═══════════════════════════════════════════════════════════════════
## SOAK: THE MINIGAMES EDITED BY THE PAUSE-AWARE-DELAY AND V2-SIGNAL PASSES
## ═══════════════════════════════════════════════════════════════════
## FIX 42 rewrote 26 in-round delay sites across 15 minigame scripts, swapping
## `await get_tree().create_timer(t).timeout` for `await round_delay(t)`. That is a
## mechanical edit to the respawn/resolve path of nearly every singleplayer game,
## and VerifyPausedDelay only exercises two of them (SpotTheSpeck, WaterMemory).
## A typo in any of the other thirteen -- a mangled argument, a call on a node that
## does not extend MiniGameBase, an await that never resumes -- would not show up
## as a parse error. It would show up as a game that hangs mid-round, and nothing
## in the existing soaks covers most of these files: SoakUnvisited pins only five
## games, four of which this pass touched.
##
## FIX 43 additionally rewrote WaterMemory's flip end to end (tweens, pivot, a
## coroutine mismatch branch), so that game needs round-after-round exercise more
## than any of the others.
##
## The bag also carries the four v2 rebuilds' scenes, added after FIX 46-51 touched
## MicrogameShell (the verb-flash hold), FixLeakV2 and BucketBrigadeV2 (round-local
## animation clocks, and the new already-patched-leak / empty-handed-person mistake
## paths). Those live in scripts/minigames_v2/ and were outside the FIX 42 sweep, so
## none of them had ever been round-after-round soaked. GreywaterSorter was already
## pinned; BucketBrigade, CatchTheRain and FixLeak are the three added scenes.
##
## The pinned list is the 19 reachable edited scenes (CoverTheDrum and WaterPlant
## joined it when FIX 52 gave them round-local animation clocks). The one that
## cannot be pinned,
## RainwaterHarvesting, is in no roster -- not ALL_SINGLEPLAYER_MINIGAMES, not any
## UNLOCK_ID_TO_MINIGAMES entry -- so it cannot be pinned into the bag here; its
## one edited site was the post-round wait deliberately left raw anyway.
##
## Coverage is proved rather than assumed: every minigame_started /
## minigame_completed pair is tallied and the per-game counts are printed at the
## end, so a game the random bag never reached is visible as a zero instead of
## silently passing.
##
## Usage:
##   godot --headless --path <project> res://tools/SoakEditedGames.tscn
## ═══════════════════════════════════════════════════════════════════

const SOAK_SECONDS: float = 420.0
const EDITED_GAMES: PackedStringArray = [
	"BucketBrigade",
	"CatchTheRain",
	"CoverTheDrum",
	"FilterBuilder",
	"FixLeak",
	"GreywaterSorter",
	"MudPieMaker",
	"PlugTheLeak",
	"QuickShower",
	"ScrubToSave",
	"SpotTheSpeck",
	"SwipeTheSoap",
	"ThirstyPlant",
	"TimingTap",
	"ToiletTankFix",
	"TracePipePath",
	"VegetableBath",
	"WaterMemory",
	"WaterPlant"
]



func _ready() -> void:
	print("[SOAKEDIT] boot")
	await get_tree().process_frame
	await get_tree().process_frame

	var apm := get_node_or_null("/root/AutoPlayManager")
	if apm and apm.has_method("set_auto_play_enabled"):
		if apm.has_method("set_auto_play_duration"):
			apm.set_auto_play_duration(SOAK_SECONDS / 60.0 + 1.0)
		# persist=false: a run killed by `timeout` never reaches the restore below, and a
		# persisted flag then hijacks the next process (see AutoPlayManager:104).
		apm.set_auto_play_enabled(true, false)
		print("[SOAKEDIT] autoplay on")
	else:
		push_warning("[SOAKEDIT] AutoPlayManager unavailable")

	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("[SOAKEDIT] GameManager unavailable")
		get_tree().quit(1)
		return

	# The watcher lives under /root, not in this scene, so it survives the session's
	# change_scene_to_file() along with these two connections and the timer below.
	var watcher := SoakWatcher.new()
	watcher.name = "SoakWatcher"
	watcher.games = EDITED_GAMES
	watcher.apm = apm
	get_tree().root.add_child(watcher)

	gm.minigame_started.connect(watcher.on_started)
	gm.minigame_completed.connect(watcher.on_completed)

	# Pin BEFORE start_session and AGAIN after: start_session re-runs
	# _refresh_available_minigames() from save data, which would wipe the pin.
	_pin_pool(gm)
	gm.start_session(0)  # GameMode.SINGLE_PLAYER
	_pin_pool(gm)
	if gm.has_method("_rebuild_minigame_random_bag"):
		gm._rebuild_minigame_random_bag()
	print("[SOAKEDIT] pool pinned to %d games: %s" % [
		gm.available_minigames.size(), str(gm.available_minigames)])
	print("[SOAKEDIT] session started")

	get_tree().create_timer(SOAK_SECONDS).timeout.connect(watcher.report_and_quit)


func _pin_pool(gm: Node) -> void:
	gm.available_minigames.clear()
	for game_id in EDITED_GAMES:
		gm.available_minigames.append(game_id)


## The tally has to outlive the harness node.
##
## The session flow calls change_scene_to_file(), which frees the current scene --
## and this harness IS the current scene, because it is what --path loaded. A lambda
## connected to a SceneTreeTimer is owned by the object that created it, so when that
## happens the connection is silently dropped: the shutdown never fires, nothing is
## reported, and the run has to be killed from outside. That is what the first two
## soak attempts did, and an externally killed soak proves nothing either way.
##
## A child of /root is not part of the current scene, so it survives the swap along
## with the signal connections and the timer pointing at it.
class SoakWatcher extends Node:
	var games: PackedStringArray = []
	var apm: Node = null
	var started: Dictionary = {}
	var completed: Dictionary = {}
	## The id of the round currently in progress, and the display titles seen coming
	## back out. The two halves of GameManager's signal pair do NOT carry the same
	## string: minigame_started.emit() passes the SCENE ID off the random bag
	## ("MudPieMaker"), while complete_minigame() is handed MiniGameBase.game_name,
	## which is the human title and in several games a LOCALIZED one -- FixLeakV2 sets
	## it from Localization.get_text("fix_leak"). Keying `completed` by the name the
	## completion carries therefore matched nothing at all: every pinned game printed
	## "0 completed" and the WARN line meant to catch a hung round fired for all 17,
	## which made the one thing this soak exists to detect unreadable. Rounds are
	## strictly sequential in single-player, so the completion is credited to the id
	## that started, and the titles are kept only for the record.
	var _current: String = ""
	var titles: Dictionary = {}
	var _unpaired: int = 0

	func on_started(game_name: String) -> void:
		started[game_name] = int(started.get(game_name, 0)) + 1
		_current = game_name

	func on_completed(game_name: String, _results: Dictionary) -> void:
		titles[game_name] = _current
		if _current == "":
			_unpaired += 1
			return
		completed[_current] = int(completed.get(_current, 0)) + 1
		_current = ""

	func report_and_quit() -> void:
		# AutoPlayManager PERSISTS its enabled flag into the player's save, so it has to
		# go back off before quit or the next real play session has the AI holding the
		# controls.
		if apm and apm.has_method("set_auto_play_enabled"):
			apm.set_auto_play_enabled(false)
		var reached: int = 0
		var rounds: int = 0
		print("[SOAKEDIT] -- per-game coverage (started/completed) --")
		for game_id in games:
			var s: int = int(started.get(game_id, 0))
			var c: int = int(completed.get(game_id, 0))
			if s > 0:
				reached += 1
			rounds += s
			var flag: String = "   <-- NEVER REACHED" if s == 0 else ""
			print("[SOAKEDIT]   %-18s %d / %d%s" % [game_id, s, c, flag])
		# A game that started and never completed is the exact hang the round_delay()
		# rewrite could have introduced, so it is called out separately from one the
		# random bag simply never drew.
		for game_id in games:
			var s: int = int(started.get(game_id, 0))
			var c: int = int(completed.get(game_id, 0))
			if s > 0 and c == 0:
				print("[SOAKEDIT] WARN %s started %d time(s), completed none" % [game_id, s])
		print("[SOAKEDIT] reached %d of %d pinned games over %d round(s)" % [
			reached, games.size(), rounds])
		print("[SOAKEDIT] %d completion(s) arrived with no round open" % _unpaired)
		print("[SOAKEDIT] titles seen on the completion signal: %s" % str(titles.keys()))
		print("[SOAKEDIT] done")
		get_tree().quit(0)
