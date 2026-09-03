extends Node

## Which cutscene TIER does each minigame actually reach?
##
## Two different key sources decide it, which is why this is measured rather than read off the
## source: MiniGameIntroBridge resolves Tier 1 from GameManager.pending_next_minigame_name (the
## FILE key it also builds res://scenes/minigames/%s.tscn from), while
## MiniGameBase._play_beat_outro() resolves it from _get_minigame_key() on the live node. A game
## can reach the authored clip for its intro and the declarative CartoonStage fallback for its
## outro, or the other way round, with nothing printed either way.
##
## An earlier version of this probe read the minigame node's own `game_name` for the intro
## column and reported 0/25 reaching Tier 1. That was a probe artifact: `game_name` holds the
## localized display title (or MiniGameBase's "MiniGame" default before _ready() runs), and the
## bridge never reads it. The intro column below uses the key the bridge actually uses.

func _ready() -> void:
	await get_tree().process_frame
	var tree: SceneTree = get_tree()
	print("\n=== CutsceneTierReport ===")
	if GameManager and GameManager.has_method("_refresh_available_minigames"):
		GameManager.call("_refresh_available_minigames")
	var rotation: Array = GameManager.available_minigames if GameManager else []
	print("  GameManager.available_minigames (%d): %s" % [rotation.size(), str(rotation)])
	var dir := DirAccess.open("res://scenes/minigames")
	var rows: Array[String] = []
	var t1_intro: int = 0
	var t2_intro: int = 0
	var t1_outro: int = 0
	var t2_outro: int = 0
	var mismatch: Array[String] = []
	var not_in_rotation: Array[String] = []
	var not_a_minigame: Array[String] = []
	for f in dir.get_files():
		if not (f.ends_with(".tscn") or f.ends_with(".tscn.remap")):
			continue
		var file_key: String = f.trim_suffix(".remap").trim_suffix(".tscn")
		var packed := load("res://scenes/minigames/%s.tscn" % file_key) as PackedScene
		if packed == null:
			rows.append("%-22s COULD NOT LOAD" % file_key)
			continue
		var inst := packed.instantiate()
		var mkey: String = ""
		if inst.has_method("_get_minigame_key"):
			mkey = str(inst.call("_get_minigame_key"))
		inst.free()
		# The bridge's key IS the file key: it builds the minigame's own scene path from the same
		# string, so a mismatch there would mean the round could not launch at all.
		var intro_t1: bool = ResourceLoader.exists(
			"res://scenes/ui/cutscenes/beats/%sIntro.tscn" % file_key)
		var outro_t1: bool = mkey != "" and ResourceLoader.exists(
			"res://scenes/ui/cutscenes/beats/%sWinOutro.tscn" % mkey)
		if intro_t1: t1_intro += 1
		else: t2_intro += 1
		if outro_t1: t1_outro += 1
		else: t2_outro += 1
		if intro_t1 != outro_t1:
			mismatch.append(file_key)
		# A scene in the rotation that is not a MiniGameBase has no HUD, no scoring hand-off and no
		# cutscene tier - the shape RainwaterHarvesting is in. Absence of this method is how the outro
		# column above reads empty, so it is worth asserting rather than only printing.
		if rotation.has(file_key) and mkey == "":
			not_a_minigame.append(file_key)
		if not rotation.has(file_key):
			not_in_rotation.append(file_key)
		rows.append("%-22s outro_key=%-22s intro=%s outro=%s%s" % [
			file_key, mkey, "T1" if intro_t1 else "T2", "T1" if outro_t1 else "T2",
			"" if rotation.has(file_key) else "   (not in rotation)"])
	for r in rows:
		print("  " + r)
	print("  intro: %d reach the authored beat clip, %d fall back to CartoonStage" % [t1_intro, t2_intro])
	print("  outro: %d reach the authored beat clip, %d fall back to CartoonStage" % [t1_outro, t2_outro])
	print("  games whose intro and outro land on different tiers: %d %s" % [mismatch.size(), str(mismatch)])
	print("  games never handed to the bridge at all: %d %s" % [not_in_rotation.size(), str(not_in_rotation)])

	# ── Claims ────────────────────────────────────────────────────────────────────────────────
	# The report above was descriptive only, so a game losing its authored clip - or a clip being
	# authored for a game nobody can launch - printed a number and passed. These are the assertions.
	var missing: Array[String] = []
	for g in rotation:
		for suffix in ["Intro", "WinOutro", "LoseOutro"]:
			if not ResourceLoader.exists("res://scenes/ui/cutscenes/beats/%s%s.tscn" % [g, suffix]):
				missing.append("%s%s" % [g, suffix])
	_check(rotation.size() > 0, "the rotation was read", "%d games" % rotation.size())
	_check(missing.is_empty(), "every game in rotation has all three authored clips",
		"missing: %s" % ("none" if missing.is_empty() else ", ".join(missing)))
	_check(t2_intro == 0, "no game in rotation falls back for its intro", "%d fall back" % t2_intro)
	_check(not_a_minigame.is_empty(), "every game in rotation is a MiniGameBase",
		"not: %s" % ("none" if not_a_minigame.is_empty() else ", ".join(not_a_minigame)))

	# Clips authored for a game that cannot be launched are paid for (they load, they are kept in the
	# export, and they were the ones leaking 72 orphan nodes a play before the CastFactory clamp fix)
	# but no player reaches them. PROTOTYPES is the declared exception list, not a way to pass: a name
	# only belongs here while the game itself is knowingly unshippable, with the reason on record in
	# the game's own script header. Anything else with clips and no roster entry fails.
	var orphan_clips: Array[String] = []
	var clip_dir := DirAccess.open("res://scenes/ui/cutscenes/beats")
	if clip_dir != null:
		for f in clip_dir.get_files():
			if not (f.ends_with(".tscn") or f.ends_with(".tscn.remap")):
				continue
			var stem: String = f.trim_suffix(".remap").trim_suffix(".tscn")
			var owner_key: String = stem.trim_suffix("Intro").trim_suffix("WinOutro").trim_suffix("LoseOutro")
			if not rotation.has(owner_key) and not PROTOTYPES.has(owner_key):
				orphan_clips.append(stem)
	_check(clip_dir != null, "the authored clip folder was read")
	_check(orphan_clips.is_empty(), "no authored clip belongs to an unlaunchable game",
		"orphaned: %s" % ("none" if orphan_clips.is_empty() else ", ".join(orphan_clips)))
	for p in PROTOTYPES:
		print("  [info] %s is a declared prototype: 3 authored clips kept, game in no roster" % p)
	print("=== %d passed / %d failed ===" % [_pass, _fail])
	print("RESULT passed=%d failed=%d" % [_pass, _fail])
	tree.quit(0 if _fail == 0 else 1)

## Games that exist under scenes/minigames/ with authored cutscene clips but are deliberately in no
## roster. RainwaterHarvesting extends Node2D rather than MiniGameBase (no HUD, no scoring, no
## cutscene tier), requires MULTIPLAYER_COOP and a live NetworkManager or it bails to the main menu,
## and its only input path is KEY_SPACE / KEY_E behind the author's own "replace with proper UI"
## note - unusable on the touch-only target device. Listing it in a roster would put an unplayable
## scene in front of a player, which is worse than its absence; see the header of
## scenes/minigames/RainwaterHarvesting.gd.
const PROTOTYPES: Array[String] = ["RainwaterHarvesting"]

var _pass: int = 0
var _fail: int = 0

func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [ok]   %s%s" % [label, "" if detail.is_empty() else "  " + detail])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [label, "" if detail.is_empty() else "  " + detail])
