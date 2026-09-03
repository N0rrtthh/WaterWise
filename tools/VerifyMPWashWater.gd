extends Node

## ═══════════════════════════════════════════════════════════════════════════════
## VerifyMPWashWater — the paired resource_transfer round (MP_WashVegetables → MP_WaterPlants)
## ═══════════════════════════════════════════════════════════════════════════════
## These two are the only games in the family that win on a COUNT of their own
## (QUOTA_P1 / QUOTA_P2 vegetables and plants) instead of on win_quota points, so each
## carries its own `if count >= QUOTA: end_game(true)` line. Both placed that line ABOVE
## the add_score() for the very action that met the quota:
##
##     if vegetables_washed >= QUOTA_P1:
##         end_game(true)      # <- reports local_score to NetworkManager here
##     add_score(10)           # <- the winning vegetable is paid AFTER the report
##
## end_game() is not a marker; it calls NetworkManager.report_player_completion(success,
## local_score, accuracy, reaction_ms) on the spot, and that dictionary is what
## _check_both_completed() and CoopAdaptation read. add_score() has no game_active guard,
## so the last award is not dropped — it lands one line too late, after the round has
## already published a score short by exactly one action, and after _show_results_screen()
## has drawn that short number for the player.
##
## MP_WaterPlants additionally kept three numbers in its instruction text that no longer
## match the constants above it (MAX_WILTED was raised 5→8 and the wilt timer 15→20 with
## the strings left behind), stamped every plant's wilt clock at scene-build time while
## the wilt timer only starts at round start — the instruction overlay between them waits
## on a player tap, so a player who reads for 20s starts a round whose whole board is
## already past the wilt age — and laid its 12 plants out with `plants.size() / 4.0`,
## float division where a row index was intended, which turns the 4x3 grid into a
## 12-step staircase.
##
## Only a host is opened: MultiplayerMiniGameBase gates on connection_active, which
## host_game() sets by itself, and nothing here needs a partner. game_active is written
## directly because the base normally opens a round behind an instruction overlay that
## waits for a tap headless cannot deliver.

const PORT: int = 7806

## How long a player is assumed to spend reading the instruction overlay before tapping it
## away. The overlay has no timeout — it waits on a tap — so this is a plain reading pace,
## not a worst case, and it is the interval the wilt clock must NOT count.
const READ_SECONDS: float = 18.0

var results: Array = []
var game: Node = null


func _ready() -> void:
	print("\n=== VerifyMPWashWater ===")
	# The copy these checks quote is the ENGLISH copy. Since the co-op games moved onto
	# Localization the default language is Filipino, so the language is pinned here and put
	# back afterwards; VerifyMPCopy is what proves both languages carry the same numbers.
	var _lang_was: int = Localization.current_language
	Localization.set_language(Localization.Language.ENGLISH)
	await get_tree().process_frame
	await _run()
	Localization.set_language(_lang_was as Localization.Language)
	var failed: int = results.count(false)
	print("  RESULT: %d passed, %d failed" % [results.count(true), failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	print("  %s %s%s" % ["✓" if ok else "✗", label, "" if detail.is_empty() else "  — " + detail])


func _open(scene_path: String, ready_probe: String) -> bool:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return false
	game = packed.instantiate()
	get_tree().root.add_child(game)
	var waited: float = 0.0
	while waited < 8.0:
		var probe = game.get(ready_probe)
		if probe != null and (not (probe is Array) or not (probe as Array).is_empty()):
			return true
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	return false


func _close() -> void:
	if game != null and is_instance_valid(game):
		game.set("game_active", false)
		get_tree().root.remove_child(game)
		game.free()
	game = null
	await get_tree().process_frame


## The score this peer actually published for the round, as CoopAdaptation and
## _check_both_completed() see it — not the local variable, which keeps moving afterwards.
func _reported_score() -> int:
	var id: int = multiplayer.get_unique_id()
	var status: Dictionary = NetworkManager.round_completion_status
	if not status.has(id):
		return -1
	return int((status[id] as Dictionary).get("score", -1))


func _run() -> void:
	_check("a session is open, which is all the base class gates on",
		GameManager.host_game(PORT),
		"connection_active=%s" % str(NetworkManager.connection_active))

	await _wash_vegetables()
	await _water_plants()


## ═══════════════════════════════════════════════════════════════════════════════
## MP_WashVegetables — Player 1
## ═══════════════════════════════════════════════════════════════════════════════
func _wash_vegetables() -> void:
	print("  ── MP_WashVegetables")
	if not await _open("res://scenes/multiplayer/MP_WashVegetables.tscn", "sink_area"):
		_check("[!] MP_WashVegetables never finished building", false)
		await _close()
		return

	var max_misses: int = int(game.MAX_MISSES)
	var quota: int = int(game.QUOTA_P1)
	var text: String = String(game.get_instructions())
	_check("MP_WashVegetables: the instructions state the miss allowance the game enforces",
		text.contains("Miss %d" % max_misses),
		"MAX_MISSES=%d, text says %s" % [max_misses, _miss_phrase(text)])

	# Drive the real wash path one vegetable at a time: _spawn_vegetable() counts the
	# oldest as missed past MAX_ON_SCREEN, so washing each before spawning the next keeps
	# the drive clean of misses it did not intend.
	NetworkManager.round_completion_status.clear()
	game.set("game_active", true)
	for _i in range(quota):
		game._spawn_vegetable()
		var veggies: Array = game.vegetables
		if veggies.is_empty():
			break
		game.set("dragging_vegetable", veggies[veggies.size() - 1])
		game._wash_vegetable()
	await get_tree().process_frame

	var washed: int = int(game.vegetables_washed)
	_check("MP_WashVegetables: the drive washed the full quota, so the win line was crossed",
		washed == quota, "washed %d of %d" % [washed, quota])

	var reported: int = _reported_score()
	var final_score: int = int(game.local_score)
	_check("MP_WashVegetables: the score it published equals the score it ended with",
		reported == final_score,
		"published %d, ended on %d (short by %d = the winning vegetable)"
			% [reported, final_score, final_score - reported])
	await _close()


## The miss number a player actually reads, pulled back out of the string for the failure
## detail so a mismatch names both sides instead of just saying "not found".
func _miss_phrase(text: String) -> String:
	var at: int = text.find("Miss ")
	if at < 0:
		return "no 'Miss N' phrase at all"
	return "\"%s\"" % text.substr(at, 12).strip_edges()


## ═══════════════════════════════════════════════════════════════════════════════
## MP_WaterPlants — Player 2
## ═══════════════════════════════════════════════════════════════════════════════
func _water_plants() -> void:
	print("  ── MP_WaterPlants")
	if not await _open("res://scenes/multiplayer/MP_WaterPlants.tscn", "plants"):
		_check("[!] MP_WaterPlants never finished building", false)
		await _close()
		return

	# Constants are read out of the script's constant map, not off the instance: the wilt
	# age had no constant at all before this fix (a bare 15.0 sat inside the check while
	# the timer beside it had been retuned to 20.0), and a missing name must fail a check
	# rather than throw on attribute access.
	var consts: Dictionary = game.get_script().get_script_constant_map()
	var max_wilted: int = int(consts.get("MAX_WILTED", -1))
	var wilt_seconds: float = float(consts.get("WILT_SECONDS", -1.0))
	var text: String = String(game.get_instructions())

	_check("MP_WaterPlants: the instructions state the wilt allowance the game enforces",
		text.contains("Let %d plants wilt" % max_wilted),
		"MAX_WILTED=%d, text says %s" % [max_wilted, _wilt_phrase(text)])
	_check("MP_WaterPlants: the wilt age is a named constant, not a literal beside a retuned timer",
		wilt_seconds > 0.0, "WILT_SECONDS=%s" % str(wilt_seconds))
	_check("MP_WaterPlants: the instructions state the wilt age the game enforces",
		wilt_seconds > 0.0 and text.contains("wilt after %ds" % int(wilt_seconds)),
		"WILT_SECONDS=%s, text says %s" % [str(wilt_seconds), _after_phrase(text)])

	# 12 plants laid out by row/col must occupy 4 columns and 3 rows. `plants.size() / 4.0`
	# is float division, so `row` advanced a quarter step per plant and the grid came out
	# as a 12-step staircase down the screen.
	var xs: Dictionary = {}
	var ys: Dictionary = {}
	for p in game.plants:
		xs[roundi((p as Node2D).position.x)] = true
		ys[roundi((p as Node2D).position.y)] = true
	_check("MP_WaterPlants: the 12 plants form a 4-column grid",
		xs.size() == 4, "%d distinct x positions" % xs.size())
	_check("MP_WaterPlants: the 12 plants form a 3-row grid, not a staircase",
		ys.size() == 3, "%d distinct y positions %s" % [ys.size(), str(ys.keys())])

	# A player who reads the instruction overlay before tapping it away. The overlay waits
	# on that tap with no timeout, so the round can begin any amount of time after the
	# plants were built — and their wilt clock was stamped at build.
	var read_ms: int = int(READ_SECONDS * 1000.0)
	for p in game.plants:
		p.set_meta("spawn_time", Time.get_ticks_msec() - read_ms)
	game.set("game_active", true)
	game._on_game_start()
	game._check_wilted_plants()

	var lost: int = _unwaterable()
	_check("MP_WaterPlants: reading the instructions for %ds does not wilt the board on the first tick"
			% int(READ_SECONDS),
		lost == 0,
		"%d of %d plants were already dead when the round began" % [lost, game.plants.size()])

	# Now age one plant past the wilt line for real, with the round running, and confirm
	# the state it lands in is legible: a dead plant must not be flagged `watered`, which
	# is what made _try_water_plant() answer "Plant already watered!" over a corpse.
	if wilt_seconds > 0.0 and not game.plants.is_empty():
		var victim: Node = game.plants[0]
		victim.set_meta("spawn_time", Time.get_ticks_msec() - int((wilt_seconds + 2.0) * 1000.0))
		game._check_wilted_plants()
		_check("MP_WaterPlants: a plant past the wilt age does wilt once the round is running",
			bool(victim.get_meta("dead", false)), "dead=%s" % str(victim.get_meta("dead", false)))
		_check("MP_WaterPlants: a wilted plant is dead, not reported to the player as watered",
			not bool(victim.get_meta("watered", false)),
			"watered=%s" % str(victim.get_meta("watered", false)))
	await _close()

	await _water_plants_scoring()


func _unwaterable() -> int:
	var n: int = 0
	for p in game.plants:
		if bool(p.get_meta("watered", false)) or bool(p.get_meta("dead", false)):
			n += 1
	return n


func _wilt_phrase(text: String) -> String:
	var at: int = text.find("Let ")
	if at < 0:
		return "no 'Let N plants wilt' phrase at all"
	return "\"%s\"" % text.substr(at, 18).strip_edges()


func _after_phrase(text: String) -> String:
	var at: int = text.find("wilt after")
	if at < 0:
		return "no 'wilt after Ns' phrase at all"
	return "\"%s\"" % text.substr(at, 16).strip_edges()


## Same published-score check as MP_WashVegetables, on a fresh instance so the wilt drive
## above cannot colour the count.
func _water_plants_scoring() -> void:
	if not await _open("res://scenes/multiplayer/MP_WaterPlants.tscn", "plants"):
		_check("[!] MP_WaterPlants never rebuilt for the scoring drive", false)
		await _close()
		return

	var quota: int = int(game.QUOTA_P2)
	NetworkManager.round_completion_status.clear()
	game.set("game_active", true)
	game.set("available_water", quota * 2)
	var watered: int = 0
	for p in game.plants:
		if watered >= quota:
			break
		game._try_water_plant(p)
		watered += 1
	await get_tree().process_frame

	_check("MP_WaterPlants: the drive watered the full quota, so the win line was crossed",
		int(game.plants_watered) == quota, "watered %d of %d" % [int(game.plants_watered), quota])

	var reported: int = _reported_score()
	var final_score: int = int(game.local_score)
	_check("MP_WaterPlants: the score it published equals the score it ended with",
		reported == final_score,
		"published %d, ended on %d (short by %d = the winning plant)"
			% [reported, final_score, final_score - reported])
	await _close()
