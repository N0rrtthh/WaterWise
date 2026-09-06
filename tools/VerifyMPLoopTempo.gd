extends Node

## How long is a co-op round NOT playable for, and how much of that is nobody's fault?
##
## THE DEFECT
##   Reported as a slow loop with too much dead time. Measured from the code rather than from
##   feel, the unconditional stretch between "both players have tapped their instruction
##   screen" and "the round accepts input" was:
##       3 countdown ticks x 1.0 s   (NetworkManager._execute_countdown)
##     + 1.0 s hold on GO            (MultiplayerMiniGameBase._on_countdown_tick, count == 0)
##     = 4.0 s
##   every round, of which 3.2 s is a timer running with nothing on screen changing - the tick
##   and GO animations are 0.4 s each. A six-round set pays that six times: 24 s of held
##   breath, on top of six scene loads and twelve instruction screens. Both waits are now named
##   constants - NetworkManager.COUNTDOWN_TICK_SECONDS and
##   MultiplayerMiniGameBase.GO_HOLD_SECONDS - and shortened to 0.6 s and 0.45 s.
##
## WHAT IS MEASURED HERE
##   1. the real thing, in wall-clock milliseconds: from the tap that readies the local player
##      to game_active going true. Timed with Time.get_ticks_msec(), not frame counts, because
##      a headless run has no frame budget and a frame is not a duration.
##   2. that the countdown is quicker to READ and not skipped: all four ticks (3, 2, 1, GO) are
##      still broadcast, in order, and GO is still the word left on the label.
##   3. that the observed time matches what the two constants promise. Asserted against the
##      constants themselves rather than against a copy of their numbers, so a wait that was
##      renamed but left at 1.0 s somewhere downstream still fails here.
##   4. that each tick still outlasts the 0.4 s animation that draws it. "Faster" must not mean
##      a number that is wiped before it finishes scaling in.
##   5. that the saving is real and not rounding: the round has to become playable in
##      meaningfully less than the 4.0 s it used to take.
##   6. that single player cannot see any of this. Both constants live in multiplayer-only
##      files; MiniGameBase, which every single-player round extends, must not reference
##      either of them.
##
## NOT CHANGED, DELIBERATELY
##   The 6 s host fallback in _on_instruction_dismissed() and the 2 s pause on the round
##   results in NetworkManager. The fallback exists for a client whose ready RPC was lost, and
##   the first-play how-to-play beat landed just before this one - a first-timer now has three
##   pages to read before they tap, so shortening the window that force-starts the round
##   without them would turn a rare lost-packet safety net into a routine "started without me".
##   The 2 s on the results screen is the only time anyone sees what the round scored.
##
## Usage:
##   godot --headless --path . res://tools/VerifyMPLoopTempo.tscn

const PORT: int = 7819
const SPECIMEN: String = "res://scenes/multiplayer/MP_CatchTheRain.tscn"
const SPECIMEN_KEY: String = "mp_catch_the_rain"
## What the loop used to cost between the last tap and a playable round: 3 x 1.0 s + 1.0 s.
const OLD_COST_MS: int = 4000
## The scale animation that draws each countdown number: 0.2 s in, 0.2 s back.
const TICK_ANIM_SECONDS: float = 0.4

var results: Array = []
var game: MultiplayerMiniGameBase = null
var _scene_before: Node = null
var _shown_was: Array = []
var _ticks: Array = []
var _tick_ms: Array = []


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	var one_line: String = detail.replace("\n", " | ")
	print("  %s %s%s" % ["PASS" if ok else "FAIL", label, "" if one_line.is_empty() else "  - " + one_line])


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _on_tick(count: int) -> void:
	_ticks.append(count)
	_tick_ms.append(Time.get_ticks_msec())


func _tap() -> void:
	if game == null or game.instruction_overlay == null:
		return
	var catcher: Button = game.instruction_overlay.get_node_or_null("ClickCatcher") as Button
	if catcher != null:
		catcher.pressed.emit()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== VerifyMPLoopTempo - dead time between the tap and a playable round ===")

	_scene_before = get_tree().current_scene
	_shown_was = TutorialManager.shown_tutorials.duplicate()
	# The first-play beat is deliberately marked spent for this run: what is being timed is the
	# loop, and three extra pages of reading would time a player instead of the countdown.
	if not (SPECIMEN_KEY in TutorialManager.shown_tutorials):
		TutorialManager.shown_tutorials.append(SPECIMEN_KEY)

	_check("a session is open, which is all the round gates on",
		GameManager.host_game(PORT),
		"connection_active=%s" % str(NetworkManager.connection_active))

	var declared_ms: int = int(round(
		(3.0 * NetworkManager.COUNTDOWN_TICK_SECONDS
			+ MultiplayerMiniGameBase.GO_HOLD_SECONDS) * 1000.0))
	print("     declared cost: 3 x %.2f s of ticks + %.2f s on GO = %d ms (was %d ms)"
		% [NetworkManager.COUNTDOWN_TICK_SECONDS, MultiplayerMiniGameBase.GO_HOLD_SECONDS,
			declared_ms, OLD_COST_MS])

	# 4. Each number has to outlast the animation that draws it.
	_check("each countdown number stays up longer than the 0.4 s animation that draws it",
		NetworkManager.COUNTDOWN_TICK_SECONDS > TICK_ANIM_SECONDS,
		"%.2f s per tick against a %.2f s animation"
			% [NetworkManager.COUNTDOWN_TICK_SECONDS, TICK_ANIM_SECONDS])
	_check("GO stays up longer than the animation that draws it, so it cannot flicker",
		MultiplayerMiniGameBase.GO_HOLD_SECONDS > TICK_ANIM_SECONDS,
		"%.2f s hold against a %.2f s animation"
			% [MultiplayerMiniGameBase.GO_HOLD_SECONDS, TICK_ANIM_SECONDS])
	# 5. And the whole point of the change.
	_check("the declared cost is meaningfully below the four seconds it used to be",
		declared_ms <= OLD_COST_MS - 1000,
		"%d ms against %d ms, saving %d ms a round and %.1f s across a six-round set"
			% [declared_ms, OLD_COST_MS, OLD_COST_MS - declared_ms,
				float(OLD_COST_MS - declared_ms) * 6.0 / 1000.0])

	await _measure()

	# 6. Isolation. Every single-player round extends MiniGameBase, which must not be able to
	# see either constant - the brief's rule is that a multiplayer fix cannot change how single
	# player behaves, and the cheapest proof is that the shortened waits are unreachable from it.
	var sp: String = FileAccess.get_file_as_string("res://scripts/MiniGameBase.gd")
	_check("single player cannot reach either shortened wait",
		not sp.contains("COUNTDOWN_TICK_SECONDS") and not sp.contains("GO_HOLD_SECONDS"),
		"MiniGameBase.gd is %d chars and mentions neither constant" % sp.length())

	await _teardown()
	var failed: int = results.count(false)
	print("")
	print("  RESULT: %d passed, %d failed" % [results.count(true), failed])
	get_tree().quit(0 if failed == 0 else 1)


## The measurement. One round, opened by hand, tapped once, then timed to the millisecond from
## that tap to the frame game_active turns true.
func _measure() -> void:
	print("")
	print("  -- the tap, and how long until the round accepts input --")
	var packed := load(SPECIMEN) as PackedScene
	if packed == null:
		_check("the specimen round loads", false, SPECIMEN)
		return
	game = packed.instantiate() as MultiplayerMiniGameBase
	get_tree().root.add_child(game)
	# The round resolves itself through current_scene in several places, so the slot is handed
	# over rather than changed into - change_scene_to_file() would free this harness.
	get_tree().current_scene = game
	NetworkManager.clear_shared_target()

	var opened: bool = false
	var open_deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < open_deadline:
		await get_tree().process_frame
		if game.instruction_overlay != null and game.instruction_overlay.visible:
			opened = true
			break
	_check("the round opens on its instruction screen", opened)
	if not opened:
		return
	_check("the beat is out of the way, so what follows times the loop and not a reader",
		game._tutorial_pages.is_empty(), "%d pages" % game._tutorial_pages.size())
	_check("the round is not playable while the instruction screen is up",
		not game.game_active)

	NetworkManager.round_starting.connect(_on_tick)
	_ticks.clear()
	_tick_ms.clear()

	var t0: int = Time.get_ticks_msec()
	_tap()
	# What the second peer's ready RPC would have triggered. _check_all_players_ready() needs
	# MAX_PLAYERS entries in players{} and this process is one peer, so the host's own decision
	# is made here instead - the same call, from the same authority, one frame later than a real
	# session would make it.
	NetworkManager.start_countdown()

	var playable_ms: int = -1
	var deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if game.game_active:
			playable_ms = Time.get_ticks_msec() - t0
			break
	NetworkManager.round_starting.disconnect(_on_tick)

	_check("the round does become playable without anyone else tapping anything",
		playable_ms >= 0, "%d ms" % playable_ms)
	if playable_ms < 0:
		return

	# 2. Quicker to read, not skipped.
	_check("all four ticks are still broadcast, in order, ending on GO",
		_ticks == [3, 2, 1, 0], "ticks seen: %s" % str(_ticks))
	_check("GO is still the word left on the countdown label",
		game.countdown_label == null
			or game.countdown_label.text == Localization.get_text("mp_countdown_go")
			or not game.countdown_label.visible,
		"label reads \"%s\"" % ("<freed>" if game.countdown_label == null else game.countdown_label.text))
	var spacing: Array = []
	for i in range(1, _tick_ms.size()):
		spacing.append(int(_tick_ms[i]) - int(_tick_ms[i - 1]))
	print("     tick spacing: %s ms" % str(spacing))

	# 3. The observed time against what the constants promise. 400 ms of slack: three chained
	# SceneTree timers and a frame of settling each, on a machine also running the editor.
	var declared_ms: int = int(round(
		(3.0 * NetworkManager.COUNTDOWN_TICK_SECONDS
			+ MultiplayerMiniGameBase.GO_HOLD_SECONDS) * 1000.0))
	_check("the measured time matches what the two constants promise, within timer slack",
		absi(playable_ms - declared_ms) <= 400,
		"%d ms measured against %d ms declared" % [playable_ms, declared_ms])
	_check("and it is a second and a half faster than the four seconds it used to be",
		playable_ms <= OLD_COST_MS - 1000,
		"%d ms against %d ms before this change" % [playable_ms, OLD_COST_MS])
	print("     MEASURED: tap to playable in %d ms (was ~%d ms; %.1f s saved across six rounds)"
		% [playable_ms, OLD_COST_MS, float(OLD_COST_MS - playable_ms) * 6.0 / 1000.0])
	print("     (headless frame pacing runs SceneTree timers a few percent fast against the wall")
	print("      clock - the tick spacing above shows the wobble - so the row that carries the")
	print("      on-device claim is the one measured on the constants, not this one.)")


func _teardown() -> void:
	Engine.time_scale = 1.0
	if game != null and is_instance_valid(game):
		# current_scene back before the free, or the tree is left holding a freed pointer.
		get_tree().current_scene = _scene_before
		get_tree().root.remove_child(game)
		game.free()
	game = null
	TutorialManager.shown_tutorials.assign(_shown_was)
	TutorialManager._save_shown_tutorials()
	NetworkManager.clear_shared_target()
	GameManager.disconnect_multiplayer()
	await _frames(2)
