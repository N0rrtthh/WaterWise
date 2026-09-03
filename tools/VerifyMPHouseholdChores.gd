extends Node

## ═══════════════════════════════════════════════════════════════════════════════
## VerifyMPHouseholdChores — the three "spend the water your partner sent" games
## ═══════════════════════════════════════════════════════════════════════════════
## MP_FillAquarium, MP_FlushToilets and MP_WashCar are the P2 halves of bundles 3, 2 and
## 5: each receives a resource over the wire and spends it on a chore. All three were
## retuned to be more forgiving (MAX_EMPTY_TIME 20 to 30, the dirty interval 8 to 12 with
## MAX_UNFLUSHED 3 to 5, MAX_DIRTY_TIME 25 to 40) and all three left the old numbers
## standing in get_instructions(), so each game now tells the player one number in its
## overlay and a different one in its own log line two functions further down.
##
## Underneath the copy sit three behavioural defects, each reproduced below before it was
## touched:
##
## MP_WashCar dead-boards itself. _make_section_dirty() has exactly two callers:
## _on_game_start() once, and the tail of a SUCCESSFUL _try_wash(). The MAX_DIRTY_TIME
## branch in _process() clears the section and charges a life but re-dirties nothing, so a
## player who runs out of partner water and eats that one penalty is left with a spotless
## car: nothing to wash, nothing to score, no further pressure, and no way to reach the
## quota for the rest of the round. That is the soft lock the brief rules out.
##
## MP_FlushToilets inverts its own pressure at full failure. unflushed_count is a parallel
## tally, incremented per dirtying and zeroed when it hits MAX_UNFLUSHED while the toilets
## it counted stay dirty. With 6 toilets and an allowance of 5, one penalty empties the
## tally, the 6th dirtying fills the board, and from then on _mark_toilet_dirty() finds no
## clean toilet and returns early forever: a completely filthy bathroom costs the team
## nothing, and the count it prints has stopped describing the board.
##
## MP_WashCar also defers its next dirty section behind a 2.0s create_timer await with no
## re-check, so a wash landing near the final whistle dirties a round that already ended.
##
## Only a host is opened: MultiplayerMiniGameBase gates on connection_active, which
## host_game() sets by itself, and none of these checks need a partner. game_active is
## written directly because the base normally opens a round behind an instruction overlay
## that waits for a tap headless cannot deliver.

const PORT: int = 7807

var results: Array = []
var game: Node = null


func _ready() -> void:
	print("\n=== VerifyMPHouseholdChores ===")
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


## Reads a constant out of the constant map of the script rather than off the instance, so
## a renamed or deleted constant fails a check with a readable number instead of throwing.
func _const(name: String, fallback: float) -> float:
	var map: Dictionary = game.get_script().get_script_constant_map()
	if not map.has(name):
		return fallback
	return float(map[name])


## Misses this peer has charged the team, counted the way CoopAdaptation counts them.
## report_miss_to_host() is the only path in the base that calls _track_action(false), so
## the gap between total and correct actions IS the miss count, and unlike team_lives it is
## readable with no RPC round trip.
func _misses() -> int:
	return int(game.total_actions) - int(game.correct_actions)


## Quotes the offending fragment back, so a copy failure names the wrong number instead of
## just asserting false.
func _near(text: String, needle: String, before: int = 4, after: int = 10) -> String:
	var at: int = text.find(needle)
	if at < 0:
		return "no %s anywhere in the text" % needle
	var frag: String = text.substr(maxi(0, at - before), before + needle.length() + after)
	return "\"%s\"" % frag.replace("\n", " ").strip_edges()


## Quotes the fragment where a NUMBER meets `needle`, skipping unrelated occurrences of the
## same word — MP_WashCar now says "a couple of seconds after each one you finish" before it
## says "40 seconds", and quoting the first match would misreport what the copy claims.
func _near_number(text: String, needle: String) -> String:
	var at: int = text.find(needle)
	while at >= 0:
		var head: String = text.substr(maxi(0, at - 4), mini(4, at))
		for i in head.length():
			if head[i].is_valid_int():
				return "\"%s\"" % (head + text.substr(at, needle.length() + 8)) \
					.replace("\n", " ").strip_edges()
		at = text.find(needle, at + 1)
	return "no numbered \"%s\" anywhere in the text" % needle


func _run() -> void:
	_check("a session is open, which is all the base class gates on",
		GameManager.host_game(PORT),
		"connection_active=%s" % str(NetworkManager.connection_active))

	await _fill_aquarium()
	await _flush_toilets()
	await _wash_car()


## ═══════════════════════════════════════════════════════════════════════════════
## MP_FillAquarium — bundle 3, P2
## ═══════════════════════════════════════════════════════════════════════════════
func _fill_aquarium() -> void:
	print("  ── MP_FillAquarium")
	if not await _open("res://scenes/multiplayer/MP_FillAquarium.tscn", "aquarium_visual"):
		_check("[!] MP_FillAquarium never finished building", false)
		await _close()
		return

	var text: String = String(game.get_instructions())
	var empty_secs: int = int(_const("MAX_EMPTY_TIME", -1.0))
	_check("MP_FillAquarium: the instructions state the empty allowance the game enforces",
		empty_secs > 0 and text.contains("%d second" % empty_secs),
		"MAX_EMPTY_TIME=%ds, text says %s" % [empty_secs, _near_number(text, "second")])

	game.set("game_active", true)

	# Evaporation is the whole reason the tank level cannot be the win condition, so first
	# confirm it runs, at the rate the comment beside it documents.
	game.set("aquarium_level", 50.0)
	await get_tree().create_timer(1.0).timeout
	var drop: float = 50.0 - float(game.aquarium_level)
	_check("MP_FillAquarium: the tank evaporates while you fill it",
		drop > 0.5 and drop < 2.5, "%.2f%% lost in 1.0s" % drop)
	_check("MP_FillAquarium: the water rect is drawn at the level it holds",
		(game.aquarium_visual as Control).size.y > 0.0,
		"water rect %s at %.0f%%" % [str((game.aquarium_visual as Control).size), float(game.aquarium_level)])

	# The overlay promises a win for filling the tank to 100%. Nothing reads aquarium_level
	# for a win: park the tank at a brimming 100% and the round simply keeps going.
	NetworkManager.round_completion_status.clear()
	game.set("aquarium_level", 100.0)
	await get_tree().process_frame
	_check("MP_FillAquarium: a brimming tank is decoration, not the thing that ends the round",
		bool(game.game_active),
		"level=%.0f%%, still running=%s" % [float(game.aquarium_level), str(game.game_active)])

	# What ends it is win_quota TEAM points, at 10 points per add.
	var quota: int = int(game.win_quota)
	var adds_needed: int = quota / 10
	game.set("available_water", adds_needed * 2)
	var adds: int = 0
	while adds < adds_needed * 2 and bool(game.game_active):
		game._try_fill()
		adds += 1
		await get_tree().process_frame
	_check("MP_FillAquarium: %d adds meet the team quota and end the round" % adds_needed,
		not bool(game.game_active) and adds == adds_needed,
		"ended after %d adds (quota %d pts), published=%s"
			% [adds, quota, str(NetworkManager.round_completion_status.has(multiplayer.get_unique_id()))])
	_check("MP_FillAquarium: the instructions state that win, not a tank level nothing reads",
		not text.contains("100% to win") and text.contains("%d " % adds_needed),
		"win is %d team points = %d adds, text says %s"
			% [quota, adds_needed, _near(text, "to win", 22, 0)])
	await _close()


## ═══════════════════════════════════════════════════════════════════════════════
## MP_FlushToilets — bundle 2, P2
## ═══════════════════════════════════════════════════════════════════════════════
func _flush_toilets() -> void:
	print("  ── MP_FlushToilets")
	if not await _open("res://scenes/multiplayer/MP_FlushToilets.tscn", "toilets"):
		_check("[!] MP_FlushToilets never finished building", false)
		await _close()
		return

	var text: String = String(game.get_instructions())
	var allowance: int = int(_const("MAX_UNFLUSHED", -1.0))
	var interval: int = int((game.spawn_timer as Timer).wait_time)
	_check("MP_FlushToilets: the instructions state the dirty interval the timer runs on",
		text.contains("every %d second" % interval),
		"wait_time=%ds, text says %s" % [interval, _near(text, "every ", 0, 12)])
	_check("MP_FlushToilets: the instructions state the unflushed allowance the game enforces",
		allowance > 0 and text.contains("Leave %d" % allowance),
		"MAX_UNFLUSHED=%d, text says %s" % [allowance, _near(text, "Leave ", 0, 12)])

	game.set("game_active", true)
	var total: int = (game.toilets as Array).size()

	# Dirty every toilet. With 6 toilets and an allowance of 5 the tally reaches the
	# allowance once, zeroes itself, and the 6th dirtying fills the board.
	for i in total:
		game._mark_toilet_dirty()
	_check("MP_FlushToilets: dirtying every toilet does leave every toilet dirty",
		_dirty_toilets() == total, "%d of %d dirty" % [_dirty_toilets(), total])
	_check("MP_FlushToilets: the count it shows the player is the count on the board",
		int(game.unflushed_count) == _dirty_toilets(),
		"overlay says %d, board has %d dirty" % [int(game.unflushed_count), _dirty_toilets()])

	# Three more dirty ticks against a board past the allowance the entire time.
	var before: int = _misses()
	for i in 3:
		game._mark_toilet_dirty()
	_check("MP_FlushToilets: a fully dirty bathroom keeps costing the team lives",
		_misses() > before,
		"%d lives charged over 3 ticks with %d of %d dirty"
			% [_misses() - before, _dirty_toilets(), total])

	# The pressure also has to be escapable: flushing must clear the fail state.
	game.set("available_water", total * 2)
	for t in game.toilets:
		game._try_flush(t)
	_check("MP_FlushToilets: flushing the board clears the fail state",
		_dirty_toilets() == 0 and int(game.unflushed_count) == 0,
		"dirty=%d, overlay says %d" % [_dirty_toilets(), int(game.unflushed_count)])
	var clean_misses: int = _misses()
	game._mark_toilet_dirty()
	_check("MP_FlushToilets: one dirty toilet on an otherwise clean board costs nothing",
		_misses() == clean_misses,
		"misses %d to %d with %d dirty" % [clean_misses, _misses(), _dirty_toilets()])
	await _close()


func _dirty_toilets() -> int:
	var n: int = 0
	for t in game.toilets:
		if bool(t.get_meta("needs_flush", false)):
			n += 1
	return n


## ═══════════════════════════════════════════════════════════════════════════════
## MP_WashCar — bundle 5, P2
## ═══════════════════════════════════════════════════════════════════════════════
func _wash_car() -> void:
	print("  ── MP_WashCar")
	if not await _open("res://scenes/multiplayer/MP_WashCar.tscn", "car_sections"):
		_check("[!] MP_WashCar never finished building", false)
		await _close()
		return

	var text: String = String(game.get_instructions())
	var secs: int = int(_const("MAX_DIRTY_TIME", -1.0))
	var sections: int = (game.car_sections as Array).size()
	_check("MP_WashCar: the instructions state the dirty timeout the game enforces",
		secs > 0 and text.contains("%d second" % secs),
		"MAX_DIRTY_TIME=%ds, text says %s" % [secs, _near_number(text, "second")])

	game.set("game_active", true)
	game._make_section_dirty()
	_check("MP_WashCar: the round opens with something to wash",
		_dirty_sections() == 1, "%d of %d sections dirty" % [_dirty_sections(), sections])

	# Backdate the dirty clock past the allowance: this is the player who ran out of partner
	# water and could not wash the section in time.
	for s in game.car_sections:
		if bool(s.get_meta("dirty", false)):
			s.set_meta("dirty_time", Time.get_ticks_msec() - (secs * 1000) - 1000)
	var before: int = _misses()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("MP_WashCar: a section left dirty past the allowance charges a life",
		_misses() > before, "misses %d to %d" % [before, _misses()])

	# 2.6s clears the 2.0s delay the wash path uses to schedule the next dirty section.
	await get_tree().create_timer(2.6).timeout
	_check("MP_WashCar: the car does not go permanently clean once that life is spent",
		_dirty_sections() > 0,
		"%d of %d sections dirty 2.6s after the penalty" % [_dirty_sections(), sections])

	# The round also has to stay playable: something to wash, and a score that moves when the
	# player washes it. Otherwise the quota is unreachable for the rest of the round.
	game.set("available_water", 10)
	var score_before: int = int(game.local_score)
	for s in game.car_sections:
		game._try_wash(s)
	_check("MP_WashCar: washing still scores after the penalty, so the quota stays reachable",
		int(game.local_score) > score_before,
		"local_score %d to %d" % [score_before, int(game.local_score)])

	# A wash landing near the final whistle schedules its next dirty section 2s out. If the
	# round ends inside that window, the deferred call must not dirty a finished board.
	game._make_section_dirty()
	for s in game.car_sections:
		if bool(s.get_meta("dirty", false)):
			game._try_wash(s)
			break
	game.set("game_active", false)
	for s in game.car_sections:
		s.set_meta("dirty", false)
	await get_tree().create_timer(2.6).timeout
	_check("MP_WashCar: the deferred re-dirty does not touch a round that already ended",
		_dirty_sections() == 0, "%d sections dirtied after game over" % _dirty_sections())
	await _close()


func _dirty_sections() -> int:
	var n: int = 0
	for s in game.car_sections:
		if bool(s.get_meta("dirty", false)):
			n += 1
	return n
