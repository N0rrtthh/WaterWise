extends Node

## Gate: proves the adaptive algorithm's tier actually changes the TASK each
## minigame sets, at BOTH tier steps - not just the countdown and the chaos layer.
##
## Run:
##   godot --headless --path . res://tools/VerifyDifficultyConsumption.tscn
##
## Why this exists: the player reported "many games but it only got to Medium and
## it did not get harder". The first half is false (the difficulty timeline shows
## Hard reached and held for 41 consecutive evaluations in one session), but the
## second half needed measuring rather than asserting.
##
## A grep for Table 6's key names across the 30 minigame scripts finds
## speed_multiplier read by 4, task_complexity 4, item_count 1, hints 0,
## distractors 0 - which looks damning and is misleading. The games consume the
## TIER, not the keys: almost every one has a `match current_difficulty` block that
## sets its own hand-tuned numbers (BucketBrigade 1.5s->0.8s spawn and 3->5
## buckets, CloudCatcher 60->120 cloud speed and 4->8 plants, TimingTap 15%->5%
## tolerance). Grepping key names measures spelling; this measures behaviour.
##
## Method: instantiate every minigame at Easy, Medium and Hard, let _ready() park
## on the instruction overlay - after _apply_difficulty_settings() has run and
## before any gameplay has moved anything - then diff the variables the scene's OWN
## script declares. A game that is byte-identical across a tier step did not get
## harder at that step, and that is a failure.
##
## Base-class fields are excluded from the diff because MiniGameBase changes them
## on every tier by construction; counting them would make every game look adaptive
## whether it is or not.
const BASE_EXPECTED := {
	"game_duration": true,
	"mistake_time_penalty": true,
	"current_difficulty": true,
	"difficulty_settings": true,
	"chaos_effects_active": true,
	"_pending_chaos_effects": true,
	"time_left": true,
	"effective_time_left": true,
}

const TIERS: Array[String] = ["Easy", "Medium", "Hard"]

var _failures: Array[String] = []
var _checked: int = 0
var _clock_notes: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame

	var scenes := _list_minigames()
	print("=== VerifyDifficultyConsumption: %d scenes x %d tiers ===" % [scenes.size(), TIERS.size()])

	for scene_name in scenes:
		var snaps: Dictionary = {}
		var skipped := false
		for tier in TIERS:
			var s: Dictionary = await _snapshot(scene_name, tier)
			if s.is_empty():
				skipped = true
				break
			snaps[tier] = s
		if skipped:
			continue
		# Control run: a SECOND Easy instantiation. Any field that differs between two
		# runs of the SAME tier is randomised per round, not chosen by the tier, so it
		# is excluded from both diffs below. Without this the gate passes on noise -
		# QuickShower places its target zone at a random gauge position, so its
		# target_zone_start/end differ on every instantiation and would score as a
		# difficulty response even if the tier changed nothing at all.
		var control: Dictionary = await _snapshot(scene_name, "Easy")
		var noisy: Dictionary = {}
		if not control.is_empty():
			for k in _diff(snaps["Easy"], control):
				noisy[k.get_slice(" ", 0)] = true
		_checked += 1

		var e_m := _diff(snaps["Easy"], snaps["Medium"], noisy)
		var m_h := _diff(snaps["Medium"], snaps["Hard"], noisy)

		var clocks := [
			float(snaps["Easy"].get("game_duration", 0.0)),
			float(snaps["Medium"].get("game_duration", 0.0)),
			float(snaps["Hard"].get("game_duration", 0.0)),
		]
		# Reported, not failed. Table 6 lists time_limit 20/15/10, and MiniGameBase
		# seeds game_duration from it, but a game whose Hard board holds twice the
		# items legitimately overrides that with a longer clock - the round still has
		# to stay clearable, which is VerifyFairness's job, not this one's. Naming
		# them keeps the divergence from Table 6 visible instead of silent.
		if clocks[2] > clocks[0]:
			_clock_notes.append("%s (%.0fs->%.0fs)" % [scene_name, clocks[0], clocks[2]])

		var ok_em := not e_m.is_empty()
		var ok_mh := not m_h.is_empty()
		if not ok_em:
			_failures.append("%s: Easy and Medium set an identical board" % scene_name)
		if not ok_mh:
			_failures.append("%s: Medium and Hard set an identical board" % scene_name)

		var mark := "[x]" if (ok_em and ok_mh) else "[!]"
		var noise_tag := "" if noisy.is_empty() else "  (random: %s)" % ", ".join(noisy.keys())
		print("  %s %-22s clock %.0f/%.0f/%.0fs  E>M: %s  |  M>H: %s%s" % [
			mark, scene_name, clocks[0], clocks[1], clocks[2],
			_brief(e_m), _brief(m_h), noise_tag])

	print("--- %d minigames measured ---" % _checked)
	if not _clock_notes.is_empty():
		print("NOTE Hard clock is not shorter than Easy in %d game(s): %s"
			% [_clock_notes.size(), ", ".join(_clock_notes)])
	if _failures.is_empty():
		print("=== PASS: every minigame changes its own board at BOTH tier steps ===")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL %s" % f)
		printerr("=== FAIL: %d flat tier step(s) ===" % _failures.size())
		get_tree().quit(1)

func _diff(a: Dictionary, b: Dictionary, ignore: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	for k in a.keys():
		if BASE_EXPECTED.has(k) or ignore.has(k) or not b.has(k):
			continue
		if str(a[k]) != str(b[k]):
			out.append("%s %s>%s" % [k, str(a[k]), str(b[k])])
	out.sort()
	return out

func _brief(d: Array[String]) -> String:
	if d.is_empty():
		return "NOTHING"
	if d.size() <= 3:
		return ", ".join(d)
	return "%s, +%d more" % [", ".join(d.slice(0, 3)), d.size() - 3]

func _list_minigames() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("res://scenes/minigames")
	if dir == null:
		_failures.append("cannot open res://scenes/minigames")
		return out
	for f in dir.get_files():
		if f.get_extension() in ["tscn", "scn", "remap"]:
			var base := f.get_basename()
			if base.get_extension() != "":
				base = base.get_basename()
			if not out.has(base):
				out.append(base)
	out.sort()
	return out

## Instantiate one minigame at one tier and read back every variable its own
## script declares. Same lifecycle as VerifyFairness.
func _snapshot(scene_name: String, tier: String) -> Dictionary:
	var path := "res://scenes/minigames/%s.tscn" % scene_name
	if not ResourceLoader.exists(path):
		return {}

	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if ad:
		ad.current_difficulty = tier

	var packed := load(path) as PackedScene
	if packed == null:
		return {}
	var game := packed.instantiate()
	# Same exclusion as VerifyFairness: RainwaterHarvesting is a multiplayer Node2D
	# that swaps the scene out from under the harness in _ready().
	if not game.has_method("_apply_sp_time_penalty"):
		game.free()
		return {}

	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var snap: Dictionary = {}
	for pname in _own_property_names(game):
		var v = game.get(pname)
		if v is Array:
			snap[pname] = "Array(%d)" % v.size()
		elif v is Dictionary:
			snap[pname] = "Dict(%d)" % v.size()
		elif v is Object:
			continue
		else:
			snap[pname] = str(v)
	snap["game_duration"] = str(game.game_duration)

	remove_child(game)
	await get_tree().process_frame
	game.free()
	return snap

## Names of the variables declared by the scene's OWN script, excluding everything
## inherited from MiniGameBase / MicrogameShell. Without the subtraction the diff is
## dominated by base bookkeeping and every game scores as adaptive.
func _own_property_names(game: Node) -> Array[String]:
	var out: Array[String] = []
	var s: Script = game.get_script()
	if s == null:
		return out
	var inherited: Dictionary = {}
	var b: Script = s.get_base_script()
	while b != null:
		for p in b.get_script_property_list():
			inherited[p["name"]] = true
		b = b.get_base_script()
	for p in s.get_script_property_list():
		var n: String = p["name"]
		if inherited.has(n) or n.begins_with("__"):
			continue
		out.append(n)
	return out
