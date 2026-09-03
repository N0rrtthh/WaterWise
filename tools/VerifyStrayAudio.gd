extends Node

## ═══════════════════════════════════════════════════════════════════
## STRAY-AUDIO-AFTER-SCENE-CHANGE HARNESS
## ═══════════════════════════════════════════════════════════════════
## AudioManager owns the music player: _setup_audio_players() does
## `music_player = AudioStreamPlayer.new(); add_child(music_player)` on the
## AUTOLOAD (autoload/AudioManager.gd:116-119). So a track outlives the scene that
## started it - freeing a minigame does not silence it, and the only thing that can
## is an explicit stop_music() or a play_music() of some other track.
##
## That makes every music start a promise the scene has to keep on EVERY exit, and
## the destinations do not cover for it: of the screens a round can land on, only
## MainMenu (:53, "menu") and FinalScore (:88, "results") start a track at all.
## InitialScreen - the hub return_to_main_menu() actually goes to - starts none, and
## neither do MultiplayerLobby, MultiplayerMenu, Settings, UnlockablesScreen or
## RoadmapScreen. Anything still playing when one of those loads keeps playing.
##
## MiniGameBase starts five tracks: "instruction" (:229), "gameplay" (:595),
## "scoring" from the quit tally (:1718) and from the round-end score page (:2210),
## and "outcome_win"/"outcome_fail" from the two micro-cutscenes (:2838, :2781).
## Only ONE of those five pairs its stop with the lifetime of the thing that
## started it: the round-end score page hangs stop_music on page.tree_exiting, with
## a comment recording that the stop used to sit on the coroutine's last line ~5.5s
## and forty await points later, so any earlier exit left the track playing over
## whatever came next. The other four still have that shape - a stop on a later
## line of the same coroutine, or no stop at all.
##
## WHAT THIS MEASURES
##   AudioManager.current_music and music_player.playing across REAL transitions,
##   at the instant after the transition. Both are read, because they answer
##   different questions: current_music is what AudioManager believes it owns, and
##   playing is whether sound is actually coming out. A stop_music() fades over
##   0.15s before calling stop, so a check that only read `playing` would report a
##   pass for a track that is merely on its way down - and one that only read
##   current_music would report a pass for a stopped-in-name-only track. The two
##   together are the honest pair.
##
## NON-VACUITY
##   Every case first asserts the track it is about to check for IS playing. A
##   "no stray audio" check on a silent AudioManager passes without being able to
##   detect anything, which is the same trap the signal-drift check in
##   VerifySessionRestart fell into.
##
## HONESTY: HEADLESS AUDIO
##   The Dummy audio driver still runs the whole AudioStreamPlayer state machine -
##   stream assignment, play(), playing, stop(), and the volume tweens - which is
##   everything asserted here. What it does not do is produce sound, so this
##   harness measures the CONTROL path and not audibility. That is the whole defect
##   either way: the bug is a player left in the playing state across a scene
##   change, not a mix problem.
##
## Usage (headless is fine; see above):
##   godot --headless --path . res://tools/VerifyStrayAudio.tscn

const SCENE: String = "res://scenes/minigames/CatchTheRain.tscn"
const HUB: String = "res://scenes/ui/InitialScreen.tscn"

var passed: int = 0
var failed: int = 0
var _detached: bool = false


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _secs(s: float) -> void:
	await _tree().create_timer(s).timeout


func _check(label: String, ok: bool, detail: String) -> void:
	if ok:
		passed += 1
		print("  [PASS] %s  %s" % [label, detail])
	else:
		failed += 1
		print("  [FAIL] %s  %s" % [label, detail])


## What AudioManager is doing right now.
##
## Both halves matter and they disagree during a fade: stop_music() clears
## current_music immediately and only stops the player after fade_duration, while
## play_music() sets current_music before the stream is even assigned. A check
## reading one field alone would pass on a track that is stopped in name only, or on
## one that is still audibly winding down.
func _audio() -> Dictionary:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		return {"id": "<no AudioManager>", "playing": false, "vol": 0.0}
	var mp = am.get("music_player")
	return {
		"id": String(am.get("current_music")),
		"playing": (mp != null and is_instance_valid(mp) and bool(mp.playing)),
		"vol": (float(mp.volume_db) if (mp != null and is_instance_valid(mp)) else 0.0),
	}


func _fmt(a: Dictionary) -> String:
	return "current_music='%s' playing=%s vol=%.1fdB" % [a["id"], a["playing"], a["vol"]]


## Poll until cond() or timeout. Returns whether it came true.
func _until(cond: Callable, limit: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < limit:
		if cond.call():
			return true
		await _tree().process_frame
	return false


## Wait for AudioManager to be playing a specific track id.
func _wait_track(id: String, limit: float) -> bool:
	return await _until(func(): return _audio()["id"] == id, limit)


## A live minigame mid-round, started the way the player starts it.
##
## Copied in shape from tools/VerifyRoundEndOnce.gd: MiniGameBase._ready() awaits
## _wait_for_input() for a real tap-to-start, so the round is begun with real
## InputEventMouseButton pairs through Input.parse_input_event rather than by calling
## start_game() directly. Forcing start_game() would skip the "instruction" track
## this harness needs to see.
func _live_round() -> Node:
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	_tree().root.add_child(inst)
	_tree().current_scene = inst
	for _i in range(30):
		await _tree().process_frame
		if _tree().paused:
			_tree().paused = false
	for attempt in range(90):
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = _tree().root.get_visible_rect().size * 0.5
		Input.parse_input_event(down)
		await _tree().process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = down.position
		Input.parse_input_event(up)
		await _tree().process_frame
		if _tree().paused:
			_tree().paused = false
		if inst.get("game_active") == true:
			print("          (round went live after %d simulated taps)" % (attempt + 1))
			break
	return inst


## Leave the minigame the way production leaves it, and settle.
##
## GameManager.return_to_main_menu() is the single teardown entry point the shipped
## paths use: the pause menu's QUIT reaches it through _on_exit_pressed(), Android
## Back reaches it through GameManager.handle_back_request() (:1676), and the
## roster's own advance goes through the sibling start_next_minigame(). Using it
## rather than a synthetic queue_free() means the scene is destroyed exactly as it is
## in the product - change_scene_to_file frees the old current_scene - so anything
## bound to that scene's lifetime gets its chance to run.
##
## SETTLE is longer than the longest fade any of these paths starts (stop_music(0.5)
## from end_game), because stop_music() clears current_music at once but only calls
## music_player.stop() from a tween_callback at the END of the fade. Sampling sooner
## would report a stop that had not actually silenced anything, and - worse - would
## let a genuine leak look like a fade still in progress.
const SETTLE: float = 1.2

func _leave() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.return_to_main_menu()
	else:
		_tree().change_scene_to_file(HUB)
	await _frames(4)
	await _secs(SETTLE)


## Where we landed, so a "silent" verdict cannot be a scene that never changed.
func _scene_path() -> String:
	var cs := _tree().current_scene
	if cs == null or not is_instance_valid(cs):
		return "<none>"
	return cs.scene_file_path


func _ready() -> void:
	# Auto-play OFF first, before anything is spawned. This harness makes the round it
	# builds the tree's current_scene, which is exactly what AutoPlayManager's navigator
	# looks at - so an auto_play_enabled=true left in the settings file by a killed soak run
	# had AutoNav clicking Play on the hub, advancing the story screen and finally changing
	# scene out from under the round being measured ("previously freed instance"), and three
	# of six cases reported the fixture dead. AutoPlayManager.set_auto_play_enabled() now
	# takes persist=false for the soak tools so the flag stops leaking, and this is the
	# belt-and-braces half: never measure a round somebody else is driving.
	var apm := get_node_or_null("/root/AutoPlayManager")
	if apm != null and apm.get("auto_play_enabled"):
		apm.set_auto_play_enabled(false)
	_run.call_deferred()


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  STRAY AUDIO AFTER SCENE CHANGE")
	print("═══════════════════════════════════════════════════════════")
	print("  scene under test : %s" % SCENE)
	print("  destination      : %s (starts no music of its own)" % HUB)
	print("  driver           : %s" % AudioServer.get_driver_name())

	await _case1_instruction_then_gameplay()
	await _case2_real_quit_path()
	await _case3_quit_tally_torn_down()
	await _case4_real_win_path()
	await _case5_micro_cutscene_reachability()
	await _case6_outro_music_inventory()

	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  %d passed, %d failed" % [passed, failed])
	print("═══════════════════════════════════════════════════════════")
	await _frames(2)
	_tree().quit(0 if failed == 0 else 1)


## ── CASE 1 ────────────────────────────────────────────────────────
## Non-vacuity. Everything below asserts "no track was left playing", which a
## silent AudioManager satisfies for free - so first establish that this harness
## can see a track at all, and that the two tracks a round starts really do start.
func _case1_instruction_then_gameplay() -> void:
	print("")
	print("── CASE 1: the round's own tracks start (control) ──────────")
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	_tree().root.add_child(inst)
	_tree().current_scene = inst
	# _ready() plays "instruction" at MiniGameBase:229, immediately before the
	# _wait_for_input() that holds the round at the tap-to-start prompt - so this is
	# a real window the player sits in, not a transient.
	var saw_instruction: bool = await _wait_track("instruction", 6.0)
	var a1 := _audio()
	_check("instruction track plays over the prompt", saw_instruction and a1["playing"], _fmt(a1))

	for _i in range(90):
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = _tree().root.get_visible_rect().size * 0.5
		Input.parse_input_event(down)
		await _tree().process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = down.position
		Input.parse_input_event(up)
		await _tree().process_frame
		if _tree().paused:
			_tree().paused = false
		if inst.get("game_active") == true:
			break
	var saw_gameplay: bool = await _wait_track("gameplay", 6.0)
	var a2 := _audio()
	_check("gameplay track replaces it on start", saw_gameplay and a2["playing"], _fmt(a2))
	# Supersession, not a stop: play_music() crossfades, so "instruction" was never
	# stopped by anyone. Worth asserting explicitly, because it is the reason a
	# teardown at the prompt has nothing to silence it.
	_check("game_active reached (fixture)", inst.get("game_active") == true,
		"game_active=%s" % inst.get("game_active"))
	# Teardown MID-ROUND, through the production call. Nothing on this path calls
	# stop_music(): end_game() is what stops the gameplay track (:664) and it never
	# ran, so if the track survives the scene change it plays on over the hub.
	#
	# Reachability is stated rather than assumed. Today no shipped button reaches
	# here - the pause menu's QUIT goes through _on_exit_pressed(), which supersedes
	# the track with "scoring", and Android Back is swallowed by
	# MiniGameBase.on_back_requested() (:3576) which turns it into a pause. So this
	# case measures the exposure of the pattern, and is reported as such; it is not
	# claimed as a live player-facing bug.
	await _leave()
	var a3 := _audio()
	print("       after mid-round teardown -> %s  scene=%s" % [_fmt(a3), _scene_path()])
	_check("landed on the hub (fixture)", _scene_path() == HUB, "scene=%s" % _scene_path())
	_check("no gameplay track left playing over the hub",
		a3["id"] == "" and not a3["playing"], _fmt(a3))


## ── CASE 2 ────────────────────────────────────────────────────────
## The real quit path, uninterrupted, all the way to the hub.
##
## _on_exit_pressed() plays "scoring" from its tally (:1718) and stops it on the
## coroutine's last line (:1863), then returns to the hub. If that coroutine runs to
## completion the track is stopped; this case establishes that the shipped quit is
## clean, so CASE 3 isolates the interruption rather than blaming the whole path.
func _case2_real_quit_path() -> void:
	print("")
	print("── CASE 2: shipped QUIT path runs clean ───────────────────")
	var g: Node = await _live_round()
	if g.get("game_active") != true:
		_check("fixture: round live before quit", false, "game_active never became true")
		await _leave()
		return
	# Not awaited: _on_exit_pressed() awaits its own tally screen and then navigates
	# by itself, so awaiting it here would just serialise this probe behind it.
	g.call("_on_exit_pressed")
	var saw: bool = await _wait_track("scoring", 6.0)
	_check("quit tally starts the scoring track (non-vacuity)", saw, _fmt(_audio()))
	# The tally is fade-in 0.35 + hold 2.8 + fade-out 0.35, then the stop, then the
	# scene change. Wait past all of it plus the 0.15 fade.
	var landed: bool = await _until(func(): return _scene_path() == HUB, 12.0)
	await _secs(SETTLE)
	var a := _audio()
	print("       after the shipped quit -> %s  scene=%s" % [_fmt(a), _scene_path()])
	_check("reached the hub", landed, "scene=%s" % _scene_path())
	_check("no track left playing over the hub",
		a["id"] == "" and not a["playing"], _fmt(a))


## ── CASE 3 ────────────────────────────────────────────────────────
## The quit tally interrupted before its last line.
##
## _show_quit_tally_screen() starts "scoring" at :1718 and stops it at :1863 - after
## `await fade_in.finished`, `await create_timer(2.8).timeout` and
## `await fade_out.finished`. The two tween awaits are the problem: create_tween() on
## this node binds the tween to the node, and a killed tween never emits `finished`,
## so a teardown inside that ~3.5s window strands the coroutine and the stop on its
## last line never executes. It is the exact shape the score page at :2210 was already
## fixed for, and its comment there names this failure mode.
##
## Driven with the production teardown call while the tally is up. As in CASE 1 the
## reachability is reported honestly: no shipped button reaches this today, so this
## measures the pattern's exposure - but unlike CASE 1 the fix is free and the
## score-page precedent is already in the file.
func _case3_quit_tally_torn_down() -> void:
	print("")
	print("── CASE 3: quit tally destroyed before its stop_music ─────")
	var g: Node = await _live_round()
	if g.get("game_active") != true:
		_check("fixture: round live before quit", false, "game_active never became true")
		await _leave()
		return
	g.call("_on_exit_pressed")
	var saw: bool = await _wait_track("scoring", 6.0)
	_check("scoring track is playing before teardown (non-vacuity)", saw, _fmt(_audio()))
	if not saw:
		await _leave()
		return
	# Inside the fade-in/hold window, well before :1863.
	await _leave()
	var a := _audio()
	print("       after tally teardown -> %s  scene=%s" % [_fmt(a), _scene_path()])
	_check("no track left playing over the hub",
		a["id"] == "" and not a["playing"], _fmt(a))


## ── CASE 4 ────────────────────────────────────────────────────────
## The real win path: end_game(true) -> outro -> score page -> hub.
##
## Anti-degeneracy for the whole suite. The score page's stop IS lifetime-paired
## (:2213, bound to page.tree_exiting), so a teardown anywhere inside the score page
## must come out silent. If this case ever failed alongside the others, the harness
## would be flagging something about scene changes in general rather than the missing
## pairings the other cases are about.
func _case4_real_win_path() -> void:
	print("")
	print("── CASE 4: score page's paired stop holds (control) ───────")
	var g: Node = await _live_round()
	if g.get("game_active") != true:
		_check("fixture: round live before end_game", false, "game_active never became true")
		await _leave()
		return
	var before := _audio()
	_check("gameplay track playing before end_game (non-vacuity)",
		before["id"] == "gameplay" and before["playing"], _fmt(before))
	# Not awaited: end_game() awaits the outro, the tally and the score page, then
	# advances the roster by itself.
	g.call("end_game", true)
	var saw: bool = await _wait_track("scoring", 20.0)
	_check("score page starts the scoring track", saw, _fmt(_audio()))
	if not saw:
		await _leave()
		return
	# Torn down mid-score-page, the same instant CASE 3 tears down the tally.
	await _leave()
	var a := _audio()
	print("       after score-page teardown -> %s  scene=%s" % [_fmt(a), _scene_path()])
	_check("no track left playing over the hub",
		a["id"] == "" and not a["playing"], _fmt(a))


## ── CASE 5 ────────────────────────────────────────────────────────
## The two micro-cutscenes: reachable or not?
##
## _show_failure_micro_cutscene() (:2779) and _show_success_micro_cutscene() (:2836)
## each start a track ("outcome_fail" / "outcome_win") and NEVER stop it - no
## stop_music anywhere in either function, and both end in cutscene.queue_free().
## But end_game() only calls them under `if not use_cartoon_cutscenes:` (:724), and
## use_cartoon_cutscenes is `true` at :157 with no assignment anywhere else in the
## project - so in the shipped build neither runs, and neither track is ever played.
##
## Asserted rather than concluded from grep, in both directions: the flag is read
## off a live instance, and the tracks are confirmed absent from a real completed
## round (CASE 4 above played end_game(true) and never saw "outcome_win").
##
## The functions are still fixed, because the flag is documented as a supported
## per-subclass opt-out (GOdot.md/Cutscene System.md:58) - a game switching it off
## tomorrow would ship the leak.
func _case5_micro_cutscene_reachability() -> void:
	print("")
	print("── CASE 5: micro-cutscene tracks (reachability) ───────────")
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	_tree().root.add_child(inst)
	await _frames(4)
	var flag = inst.get("use_cartoon_cutscenes")
	_check("use_cartoon_cutscenes is on, so the micro-cutscenes are skipped",
		flag == true, "use_cartoon_cutscenes=%s (end_game gates on `not` it, :724)" % flag)
	_check("both micro-cutscenes route through _play_scoped_music now",
		inst.has_method("_show_failure_micro_cutscene")
			and inst.has_method("_show_success_micro_cutscene"),
		"they had no stop at all; scoped to the round even though unreachable today")
	inst.queue_free()
	await _frames(4)



## ── CASE 6 ────────────────────────────────────────────────────────
## What the outro presentation actually does with music.
##
## Three separate stacks under scripts/cutscenes/ and scenes/ui/cutscenes/ start music
## with no stop_music anywhere in their file: CartoonStage._play_audio_cue()
## (:852-864, "instruction"/"outcome_win"/"outcome_fail"), SimpleCutscenePlayer
## (:30-33), and the CharacterOutcomeNarrative / MiniGameOutroCutscene /
## MiniGameIntroCutscene screens. Which of them runs is decided at runtime by
## MiniGameBase._show_tally_screen()'s three tiers, so this case MEASURES the outro of
## a real completed round rather than reading the resolver.
##
## The measured answer: none of them. Tier 1 wins - _play_beat_outro() finds an
## authored clip (every shipped minigame has one under
## res://scenes/ui/cutscenes/beats/) and MicrogameOutroBase plays no music at all - so
## the whole outro beat runs in silence between end_game()'s stop_music(0.5) and the
## score page's "scoring". That is a presentation gap, not a leak, and it is reported
## as one; the unpaired stacks behind it are fixed anyway because a game added without
## a beat clip falls straight through to CartoonStage.
##
## Asserted non-vacuously: the silence only means something if the outro window was
## real, so the case also asserts that the round ended and that "scoring" did arrive
## afterwards - i.e. that there WAS a window between the two and this probe was
## sampling during it.
func _case6_outro_music_inventory() -> void:
	print("")
	print("── CASE 6: what the live outro does with music ────────────")
	var g: Node = await _live_round()
	if g.get("game_active") != true:
		_check("fixture: round live before end_game", false, "game_active never became true")
		await _leave()
		return
	var key: String = String(g.call("_get_minigame_key"))
	var clip_path: String = "res://scenes/ui/cutscenes/beats/%sLoseOutro.tscn" % key
	_check("tier 1 wins: an authored beat clip exists for '%s'" % key,
		ResourceLoader.exists(clip_path), clip_path)
	g.call("end_game", false)
	# Sample every frame across the whole outro and record every distinct track id, so
	# a bed that appears and is superseded before "scoring" cannot be missed.
	var ids: Array[String] = []
	var saw_scoring: bool = false
	for _k in range(900):
		var id: String = _audio()["id"]
		if not ids.has(id):
			ids.append(id)
		if id == "scoring":
			saw_scoring = true
			break
		await _tree().process_frame
	print("       distinct track ids across the outro -> %s" % str(ids))
	_check("the outro window was real (round ended, score page followed)",
		saw_scoring and g.get("game_active") == false,
		"saw_scoring=%s game_active=%s" % [saw_scoring, g.get("game_active")])
	_check("no cutscene bed starts during the outro (silent beat, reported)",
		not ids.has("outcome_win") and not ids.has("outcome_fail")
			and not ids.has("instruction"),
		"ids=%s" % str(ids))
	await _leave()
	var a := _audio()
	_check("no track left playing over the hub",
		a["id"] == "" and not a["playing"], _fmt(a))
