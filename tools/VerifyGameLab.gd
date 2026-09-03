extends Node

## GATE — Game Lab sandbox isolation.
##
## The Lab (scenes/ui/GameLab.gd) exists to try a mechanic out. Its promise is
## that a round played there changes nothing about the player: no save write, no
## droplets, no life, no session score, nothing in the exported session JSON, and
## no sample in either adaptive algorithm's rolling window. That promise is
## enforced at the SINKS (see the SANDBOX block in autoload/GameManager.gd), so
## this gate measures the sinks, not the screen's intentions.
##
## Method: photograph every observable, drive the REAL entry points a round uses,
## photograph again, and require the two to match. Then play an actual minigame
## round to its end_game() and require the same. The tier and the life count are
## deliberately BORROWED by the sandbox, so those two are asserted separately -
## changed while inside, handed back on the way out.
##
## Run: Godot_v4.7.2 --headless --path . tools/VerifyGameLab.tscn

const SAVE_PATH := "user://waterwise_save.json"

## Values the sandbox is ALLOWED to move while it is active, and must restore.
const BORROWED := ["ad_tier", "gm_lives"]

## enter_sandbox() deliberately calls save_now() ONCE on the way in, to flush what
## the player earned before opening the Lab - from then on every write is refused.
## That flush is a real write to the real file, so these two fields can legitimately
## differ afterwards: they are the play-time ledger for the session that was already
## running. Anything else moving means Lab data reached the disk.
const FLUSH_ALLOWED := ["player.last_play_date", "player.total_play_time"]

var _pass: int = 0
var _fail: int = 0
var _save_at_start: PackedByteArray = PackedByteArray()
var _save_existed: bool = false


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s%s" % [label, "" if detail == "" else "   " + detail])
	else:
		_fail += 1
		print("  FAIL  %s%s" % [label, "" if detail == "" else "   " + detail])


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _save_md5() -> String:
	if not FileAccess.file_exists(SAVE_PATH):
		return "<none>"
	return FileAccess.get_md5(SAVE_PATH)


## Everything a round could plausibly write to, in one dictionary.
func _snapshot() -> Dictionary:
	var sm := get_node_or_null("/root/SaveManager")
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	var sl := get_node_or_null("/root/SessionLogger")
	var ca := get_node_or_null("/root/CoopAdaptation")
	var gm := get_node_or_null("/root/GameManager")
	return {
		"save_md5": _save_md5(),
		"droplets": int(sm.get_droplets()) if sm else -1,
		"play_time": int(sm.get_total_play_time()) if sm else -1,
		"games_played": int(sm.get_total_games_played()) if sm else -1,
		"high_scores": (sm.high_scores as Dictionary).size() if sm else -1,
		"sp_sessions": (sm.sp_session_scores as Array).size() if sm else -1,
		"ad_window": (ad.performance_window as Array).size() if ad else -1,
		"ad_history": (ad.performance_history as Array).size() if ad else -1,
		"ad_recorded": int(ad.total_games_recorded) if ad else -1,
		"ad_tier": str(ad.current_difficulty) if ad else "?",
		"sl_sp": (sl.sp_games as Array).size() if sl else -1,
		"sl_sp_count": int(sl.sp_games_count) if sl else -1,
		"sl_scenes": (sl.scenes_visited as Array).size() if sl else -1,
		"sl_mp": (sl.mp_rounds as Array).size() if sl else -1,
		"sl_droplets": int(sl.total_droplets_earned) if sl else -1,
		"coop_p1": (ca.player1_window as Array).size() if ca else -1,
		"coop_p2": (ca.player2_window as Array).size() if ca else -1,
		"coop_total": int(ca.total_games) if ca else -1,
		"gm_score": int(gm.session_score) if gm else -1,
		"gm_played": int(gm.minigames_played_this_session) if gm else -1,
		"gm_lives": int(gm.session_lives) if gm else -1,
		"gm_droplets": int(gm.water_droplets) if gm else -1,
	}


## Keys whose value moved, ignoring the two the sandbox is allowed to borrow.
func _drift(before: Dictionary, after: Dictionary) -> Array[String]:
	var moved: Array[String] = []
	for k in before.keys():
		if k in BORROWED:
			continue
		if before[k] != after[k]:
			moved.append("%s %s->%s" % [k, str(before[k]), str(after[k])])
	return moved


func _ready() -> void:
	print("=== GAME LAB SANDBOX GATE ===")
	await _frames(2)

	# The real save file must come out of this run exactly as it went in. Entering
	# the sandbox deliberately FLUSHES first (so real progress is not lost), which
	# is itself a legitimate write - so the baseline for "no writes" is taken after
	# that flush, and the original bytes are put back before quitting.
	_save_existed = FileAccess.file_exists(SAVE_PATH)
	if _save_existed:
		_save_at_start = FileAccess.get_file_as_bytes(SAVE_PATH)
	print("  (save file %s, %d bytes)" % [
		"present" if _save_existed else "absent", _save_at_start.size()])

	await _check_a_sinks_refuse()
	await _check_b_real_round()
	await _check_c_coop_not_faked()
	await _check_d_lab_screen()
	_check_e_restore_save()

	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## A. Drive every sink a round uses, with sandbox ON, and require nothing moved.
func _check_a_sinks_refuse() -> void:
	print("")
	print("--- A. the nine sinks refuse a sandbox round ---")
	var gm := get_node_or_null("/root/GameManager")
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	var sm := get_node_or_null("/root/SaveManager")
	var sl := get_node_or_null("/root/SessionLogger")
	var ca := get_node_or_null("/root/CoopAdaptation")
	if gm == null or ad == null or sm == null or sl == null or ca == null:
		_check("autoloads present", false, "one of the five is missing")
		return

	# A real tier to park, deliberately different from the one the Lab borrows.
	ad.current_difficulty = "Hard"
	var real_lives: int = 2
	gm.session_lives = real_lives

	gm.enter_sandbox("Easy")
	await _frames(1)
	var before := _snapshot()
	_check("sandbox is on", gm.is_sandbox() == true)
	_check("tier borrowed", str(ad.current_difficulty) == "Easy",
		"parked Hard, now %s" % str(ad.current_difficulty))

	# Every writer a round touches, called through its real entry point.
	ad.add_performance(0.95, 1100, 0, "TracePipePath")
	ca.add_game_result(
		{"accuracy": 0.9, "time": 8.0, "errors": 0},
		{"accuracy": 0.8, "time": 9.0, "errors": 1},
		true)
	sl.record_sp_game("TracePipePath", 90, 0.95, 1100, 0, "Easy", 7)
	sl.record_scene_visit("GameLab")
	sm.add_droplets(50)
	sm.record_game_result("TracePipePath", 90, 0.95, 8.0)
	sm.save_now()
	gm.complete_minigame("Trace Pipe Path", 0.95, 1100, 0, 90, 4, true, "TracePipePath")
	await _frames(2)

	var after := _snapshot()
	var moved := _drift(before, after)
	_check("nothing moved across nine sinks", moved.is_empty(),
		"drift: %s" % ("none" if moved.is_empty() else ", ".join(moved)))
	_check("the round is still REPORTED to the Lab",
		not (gm.sandbox_last_result as Dictionary).is_empty()
			and str((gm.sandbox_last_result as Dictionary).get("game_id", "")) == "TracePipePath",
		"last_result game_id=%s" % str((gm.sandbox_last_result as Dictionary).get("game_id", "-")))
	_check("save file untouched while sandboxed", before["save_md5"] == after["save_md5"],
		"md5 %s" % str(after["save_md5"]).substr(0, 8))

	# The backstop, tested rather than assumed. add_droplets() and
	# record_game_result() refuse a sandbox round outright, but a writer added later
	# might not - so SaveManager photographs every persisted store on entry and puts
	# it back on exit. Poke the stores DIRECTLY, the way an unguarded writer would,
	# and require the rollback to undo it.
	var probe_droplets: int = int(before["droplets"]) + 999
	sm.player_data["water_droplets"] = probe_droplets
	sm.high_scores["__sandbox_probe__"] = {
		"score": 1, "accuracy": 1.0, "best_time": 1.0, "times_played": 1}
	sm.player_data["games_played"] = int(before["games_played"]) + 42
	_check("unguarded writer really did move the stores",
		int(sm.get_droplets()) == probe_droplets
			and sm.high_scores.has("__sandbox_probe__"),
		"droplets now %d, probe key present" % int(sm.get_droplets()))

	# On the way out: what was borrowed comes back, what leaked in memory is undone.
	gm.exit_sandbox()
	await _frames(1)
	var restored := _snapshot()
	_check("tier handed back", str(ad.current_difficulty) == "Hard",
		"now %s" % str(ad.current_difficulty))
	_check("lives handed back", int(gm.session_lives) == real_lives,
		"now %d, was %d" % [int(gm.session_lives), real_lives])
	_check("leaked droplets rolled back",
		int(restored["droplets"]) == int(before["droplets"]),
		"%d (probe had pushed it to %d)" % [
			int(restored["droplets"]), probe_droplets])
	_check("leaked high-score row rolled back",
		not sm.high_scores.has("__sandbox_probe__"),
		"%d entries" % int(restored["high_scores"]))
	_check("leaked games_played rolled back",
		int(restored["games_played"]) == int(before["games_played"]),
		"%d" % int(restored["games_played"]))
	_check("GameManager droplet mirror rolled back",
		int(restored["gm_droplets"]) == int(before["gm_droplets"]),
		"%d" % int(restored["gm_droplets"]))
	_check("sandbox is off", gm.is_sandbox() == false)


## B. A REAL round: a real minigame scene, started through its real prompt, ended
## through end_game(). complete_minigame() is reached synchronously inside
## end_game(), before the outro awaits, so the assertions are made before the
## instance is dropped - and it is dropped before the outro can change scene and
## take this harness with it.
func _check_b_real_round() -> void:
	print("")
	print("--- B. a real sandbox round of TracePipePath ---")
	var gm := get_node_or_null("/root/GameManager")
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if gm == null or ad == null:
		_check("autoloads present", false)
		return

	ad.current_difficulty = "Hard"
	gm.session_lives = 3
	gm.enter_sandbox("Medium")
	gm.set_game_mode(gm.GameMode.SINGLE_PLAYER)
	await _frames(1)
	var before := _snapshot()

	var md5_in: String = _save_md5()
	var inst: Node = await _live("TracePipePath")
	if inst == null:
		_check("TracePipePath starts", false, "never became active")
		gm.exit_sandbox()
		return
	_check("TracePipePath starts", true, "game_active=true")

	# A losing round: the path that would cost a life and pay nothing, plus the
	# path that would pay droplets is covered by the winning round below.
	inst.call("end_game", false)
	var lost := _snapshot()
	var lives_after_loss: int = int(gm.session_lives)
	var lost_drift := _drift(before, lost)
	var lost_result: Dictionary = (gm.sandbox_last_result as Dictionary).duplicate()
	inst.queue_free()
	await _frames(4)

	_check("lost round: nothing recorded", lost_drift.is_empty(),
		"drift: %s" % ("none" if lost_drift.is_empty() else ", ".join(lost_drift)))
	_check("lost round: no life deducted", lives_after_loss == 3,
		"session_lives=%d" % lives_after_loss)
	_check("lost round: reported to the Lab as a loss",
		lost_result.get("was_successful") == false,
		"was_successful=%s" % str(lost_result.get("was_successful")))

	# A winning round: this is the one that would pay droplets, bank a session
	# score, take a high-score slot and feed the Φ window.
	var inst2: Node = await _live("WaterMemory")
	if inst2 == null:
		_check("WaterMemory starts", false, "never became active")
		gm.exit_sandbox()
		return
	_check("WaterMemory starts", true, "game_active=true")
	inst2.set("current_score", 120)
	inst2.set("correct_actions", 10)
	inst2.set("total_actions", 10)
	inst2.call("end_game", true)
	var won := _snapshot()
	var won_drift := _drift(before, won)
	var won_result: Dictionary = (gm.sandbox_last_result as Dictionary).duplicate()
	inst2.queue_free()
	await _frames(4)

	_check("won round: nothing recorded", won_drift.is_empty(),
		"drift: %s" % ("none" if won_drift.is_empty() else ", ".join(won_drift)))
	_check("won round: no droplets paid",
		int(won["droplets"]) == int(before["droplets"]),
		"droplets still %d" % int(won["droplets"]))
	_check("won round: reported to the Lab as a win",
		won_result.get("was_successful") == true
			and int(won_result.get("score", -1)) > 0,
		"score=%s" % str(won_result.get("score")))
	_check("won round: Φ window still empty of it",
		(ad.performance_window as Array).size() == int(before["ad_window"]),
		"window size %d" % (ad.performance_window as Array).size())

	# start_next_minigame() is what the outro calls. In the sandbox it must leave the
	# session alone - no roster advance, no game-over - and land back in the Lab.
	#
	# It really does change the scene, and the scene it would free is THIS harness.
	# So a stand-in is made the current scene first: SceneTree._change_scene()
	# deletes whatever current_scene points at, so pointing it at a throwaway node
	# lets the swap happen for real and be observed, instead of being asserted from
	# the outside.
	var fired: Array[String] = []
	var started := func(gname: String) -> void: fired.append("minigame_started:" + gname)
	var over := func() -> void: fired.append("all_minigames_completed")
	gm.minigame_started.connect(started)
	gm.all_minigames_completed.connect(over)
	gm.session_lives = 0  # outside the sandbox this alone forces game-over

	var stand_in := Node.new()
	stand_in.name = "SandboxSceneStandIn"
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	gm.start_next_minigame()
	await _frames(3)
	gm.minigame_started.disconnect(started)
	gm.all_minigames_completed.disconnect(over)

	var landed: Node = get_tree().current_scene
	var landed_path: String = "" if landed == null else str(landed.scene_file_path)
	_check("start_next_minigame does not advance the session", fired.is_empty(),
		"fired: %s" % ("nothing" if fired.is_empty() else ", ".join(fired)))
	_check("two whole sandbox rounds left the file alone", _save_md5() == md5_in,
		"md5 %s -> %s" % [md5_in.substr(0, 8), _save_md5().substr(0, 8)])
	_check("a finished sandbox round lands back in the Lab",
		landed_path == "res://scenes/ui/GameLab.tscn", "current scene: %s" % (
			"<none>" if landed_path == "" else landed_path))
	if landed != null and landed != self:
		landed.queue_free()
	await _frames(2)
	get_tree().current_scene = self

	gm.exit_sandbox()
	await _frames(1)


## A minigame parked on its tap-to-start prompt, at whatever tier the sandbox is
## currently holding. MiniGameBase._ready() applies difficulty before its first
## await, so the instance is already configured the moment add_child() returns.
func _park(scene_name: String) -> Node:
	var path := "res://scenes/minigames/%s.tscn" % scene_name
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	if not inst.has_method("_apply_sp_time_penalty"):
		inst.free()
		return null
	get_tree().root.add_child(inst)
	await _frames(6)
	return inst


## A LIVE round, started through the real tap-to-start prompt rather than by
## poking game_active, so the round runs the same code a player's round runs.
func _live(scene_name: String) -> Node:
	var inst: Node = await _park(scene_name)
	if inst == null:
		return null
	for _attempt in range(120):
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = get_tree().root.get_visible_rect().size * 0.5
		Input.parse_input_event(down)
		await get_tree().process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = down.position
		Input.parse_input_event(up)
		await get_tree().process_frame
		if inst.get("game_active") == true:
			break
	return inst


## C. Co-op is not simulated. One process cannot hold two real peers, so what is
## proved here is the refusal side: every path that could invent a partner says no.
## The co-op rounds themselves are covered by the paired MP harnesses, which run as
## two processes.
func _check_c_coop_not_faked() -> void:
	print("-- C. co-op is refused, never faked")
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		_check("GameManager present", false)
		return

	var saved_host: bool = gm.is_host
	var saved_conn: bool = gm.is_multiplayer_connected
	var saved_mode: int = int(gm.current_game_mode)

	gm.is_host = false
	gm.is_multiplayer_connected = false
	var as_guest: bool = gm.start_multiplayer_round_named("MP_WaterMemory")
	_check("a non-host cannot start a co-op round", as_guest == false,
		"returned %s" % str(as_guest))

	# The lone tester's case: pressing PLAY on an MP row with nobody connected.
	gm.is_host = true
	var alone: bool = gm.start_multiplayer_round_named("MP_WaterMemory")
	_check("a host alone cannot start a co-op round", alone == false,
		"returned %s, peers=%d" % [str(alone), gm.get_connected_multiplayer_peer_ids().size()])
	_check("a refused co-op round does not switch the session to co-op",
		int(gm.current_game_mode) == saved_mode,
		"current_game_mode=%d" % int(gm.current_game_mode))

	gm.is_host = saved_host
	gm.is_multiplayer_connected = saved_conn
	gm.current_game_mode = saved_mode

	# The unknown-game branch can never be reached from the Lab, because every row
	# it offers comes out of this roster and each one is a scene that exists.
	var missing: Array[String] = []
	for game_name in gm.multiplayer_minigames:
		if not ResourceLoader.exists("res://scenes/multiplayer/%s.tscn" % str(game_name)):
			missing.append(str(game_name))
	_check("every co-op name on the roster is a real scene", missing.is_empty(),
		"%d names, missing: %s" % [gm.multiplayer_minigames.size(),
			"none" if missing.is_empty() else ", ".join(missing)])


## D. The Lab screen itself: opening it must isolate the session, the roster must be
## the real one, and the fairness readout must come from the real games rather than
## from a table written by hand.
func _check_d_lab_screen() -> void:
	print("-- D. the Lab screen")
	const LAB_LIVES := 3  # GameManager.SANDBOX_LIVES
	var gm := get_node_or_null("/root/GameManager")
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if gm == null or ad == null:
		_check("autoloads present", false)
		return
	if not ResourceLoader.exists("res://scenes/ui/GameLab.tscn"):
		_check("GameLab.tscn exists", false)
		return

	# Start from a real session, so the parking can be watched happening.
	if gm.sandbox_mode:
		gm.exit_sandbox()
		await _frames(1)
	ad.current_difficulty = "Hard"
	gm.session_lives = 2

	var lab: Node = (load("res://scenes/ui/GameLab.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(lab)
	await _frames(4)

	_check("opening the Lab turns the sandbox on", gm.sandbox_mode == true)
	_check("the Lab opens at the session's live tier", str(lab.get("_tier")) == "Hard",
		"_tier=%s, AdaptiveDifficulty=%s" % [str(lab.get("_tier")), str(ad.current_difficulty)])
	_check("the Lab lends the round a full set of lives",
		int(gm.session_lives) == LAB_LIVES, "session_lives=%d" % int(gm.session_lives))

	var list: ItemList = lab.get("game_list") as ItemList
	var expected := 0
	var dir := DirAccess.open("res://scenes/minigames")
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if not dir.current_is_dir() and f.ends_with(".tscn"):
				expected += 1
			f = dir.get_next()
		dir.list_dir_end()
	for game_name in gm.multiplayer_minigames:
		if ResourceLoader.exists("res://scenes/multiplayer/%s.tscn" % str(game_name)):
			expected += 1
	_check("every game on disk is listed", list != null and list.item_count == expected,
		"%d listed, %d found" % [-1 if list == null else list.item_count, expected])

	# The readout is only worth anything if it changes when the game's rules change.
	# TracePipePath is the user's own example: tries at Medium/Hard, clock at Easy.
	var entries: Array = lab.get("_entries")
	var sp_idx: int = -1
	var mp_idx: int = -1
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		if not bool(e["mp"]) and str(e["name"]) == "TracePipePath":
			sp_idx = i
		elif bool(e["mp"]) and mp_idx < 0:
			mp_idx = i
	var probe: Label = lab.get("probe_label") as Label
	if sp_idx < 0 or probe == null:
		_check("TracePipePath is selectable in the Lab", false,
			"index=%d, probe_label=%s" % [sp_idx, "missing" if probe == null else "ok"])
	else:
		list.select(sp_idx)
		lab.call("_on_game_selected", sp_idx)
		await _frames(8)
		var hard_text: String = str(probe.text)
		lab.call("_on_tier_pressed", "Easy")
		await _frames(8)
		var easy_text: String = str(probe.text)
		_check("the readout reads the real game at Hard (tries)",
			hard_text.contains("MISTAKES") and not hard_text.contains("on the CLOCK"),
			hard_text.replace("\n", " | "))
		_check("switching tier re-reads it and it changes (clock)",
			easy_text.contains("on the CLOCK") and not easy_text.contains("MISTAKES"),
			easy_text.replace("\n", " | "))
		_check("a tier button moves the difficulty the round will use",
			str(ad.current_difficulty) == "Easy" and str(lab.get("_tier")) == "Easy",
			"AdaptiveDifficulty=%s, _tier=%s" % [
				str(ad.current_difficulty), str(lab.get("_tier"))])

	# A co-op row with nobody connected must offer the lobby, not a round.
	var play: Button = lab.get("play_button") as Button
	if mp_idx < 0 or play == null:
		_check("a co-op row is selectable in the Lab", false, "index=%d" % mp_idx)
	else:
		list.select(mp_idx)
		lab.call("_on_game_selected", mp_idx)
		await _frames(4)
		_check("a co-op row alone offers the lobby, not a fake round",
			str(play.text) == "> OPEN CO-OP LOBBY", "button reads '%s'" % str(play.text))

	var md5_lab: String = _save_md5()

	# Leaving the Lab must hand the session back exactly as it was found. _on_back()
	# really does change the scene, so a stand-in takes the harness's place again.
	var stand_in := Node.new()
	stand_in.name = "LabBackStandIn"
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	lab.call("_on_back")
	await _frames(3)
	var landed: Node = get_tree().current_scene
	var landed_path: String = "" if landed == null else str(landed.scene_file_path)

	_check("the Lab screen itself wrote nothing", md5_lab == _save_md5(),
		"md5 %s -> %s" % [md5_lab.substr(0, 8), _save_md5().substr(0, 8)])
	_check("leaving the Lab turns the sandbox off", gm.sandbox_mode == false)
	_check("leaving hands the session's tier back", str(ad.current_difficulty) == "Hard",
		"AdaptiveDifficulty=%s" % str(ad.current_difficulty))
	_check("leaving hands the session's lives back", int(gm.session_lives) == 2,
		"session_lives=%d" % int(gm.session_lives))
	_check("the Back button returns to Settings",
		landed_path == "res://scenes/ui/Settings.tscn",
		"current scene: %s" % ("<none>" if landed_path == "" else landed_path))

	if landed != null and landed != self:
		landed.queue_free()
	if is_instance_valid(lab):
		lab.queue_free()
	await _frames(2)
	get_tree().current_scene = self


## E. The last word: the real save file on disk must be byte-identical to how this
## run found it. Anything the harness did move is put back, so a failure here is
## reported rather than left behind.
func _check_e_restore_save() -> void:
	print("-- E. the save file on disk")
	if not _save_existed:
		_check("no save file was created", not FileAccess.file_exists(SAVE_PATH),
			"none at start, %s now" % ("one now" if FileAccess.file_exists(SAVE_PATH) else "still none"))
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		return

	var now: PackedByteArray = FileAccess.get_file_as_bytes(SAVE_PATH)
	var same: bool = now == _save_at_start
	var moved: Array[String] = [] if same else _json_diff(_save_at_start, now)
	var stray: Array[String] = []
	for m in moved:
		if not m.split(" ")[0] in FLUSH_ALLOWED:
			stray.append(m)
	_check("nothing but the entry flush ever reached the file", stray.is_empty(),
		"%d field(s) moved: %s" % [moved.size(),
			"none" if moved.is_empty() else ", ".join(moved)])
	if not same:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_buffer(_save_at_start)
			f.close()
			print("  (original save bytes restored)")


## Which fields of the save moved, named rather than just counted, so a failure
## points at the writer instead of at the byte count.
func _json_diff(a: PackedByteArray, b: PackedByteArray) -> Array[String]:
	var moved: Array[String] = []
	var da: Variant = JSON.parse_string(a.get_string_from_utf8())
	var db: Variant = JSON.parse_string(b.get_string_from_utf8())
	if not (da is Dictionary and db is Dictionary):
		moved.append("<unparseable>")
		return moved
	var keys: Array = (da as Dictionary).keys()
	for k in (db as Dictionary).keys():
		if not k in keys:
			keys.append(k)
	for k in keys:
		var va: Variant = (da as Dictionary).get(k)
		var vb: Variant = (db as Dictionary).get(k)
		if va == vb:
			continue
		if va is Dictionary and vb is Dictionary:
			var sub: Array = (va as Dictionary).keys()
			for sk in (vb as Dictionary).keys():
				if not sk in sub:
					sub.append(sk)
			for sk in sub:
				var sa: Variant = (va as Dictionary).get(sk)
				var sb: Variant = (vb as Dictionary).get(sk)
				if sa != sb:
					moved.append("%s.%s %s->%s" % [str(k), str(sk),
						JSON.stringify(sa), JSON.stringify(sb)])
		else:
			moved.append("%s %s->%s" % [str(k), JSON.stringify(va), JSON.stringify(vb)])
	if moved.is_empty():
		moved.append("<same keys, different bytes>")
	return moved
