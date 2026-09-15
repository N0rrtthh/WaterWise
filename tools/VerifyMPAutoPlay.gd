extends Node

## ── MULTIPLAYER AUTOPLAY VERIFICATION (Test C, headless) ───────────────────
##
## Does the multiplayer bot actually PLAY a co-op round through the real
## gameplay pipeline, the way the single-player bot does?
##
## What is driven, per role:
##   • Catcher role (MP_CatchTheRain): the bot steers the bucket with synthetic
##     pointer drags and must CATCH drops — real input, real collisions, real
##     scoring through the round's own add_score() path.
##   • Target role (MP_WaterPlants): the bot taps the round's real clickable
##     targets. Score needs the partner's water by design (co-op), so the
##     assertion here is that real input reaches the round, not that a score
##     can grow without a partner.
##
## "Real input" is proven with the touch-delivery instrumentation from the
## input-drop investigation: TouchInputManager counts every event the OS/driver
## delivered, and the autoplay injects through the same parse_input_event path
## a human finger takes. If the bot instead bumped a score variable directly,
## that counter would stay at zero.
##
## Run:  godot --headless --path . res://tools/VerifyMPAutoPlay.tscn

const CATCHER_SCENE := "res://scenes/multiplayer/MP_CatchTheRain.tscn"
const TARGET_SCENE := "res://scenes/multiplayer/MP_WaterPlants.tscn"
const PLAY_SECONDS: float = 14.0

var _fails: int = 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _pass(msg: String) -> void:
	print("  ✓ " + msg)


func _fail(msg: String) -> void:
	_fails += 1
	print("  ✗ " + msg)


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  MULTIPLAYER AUTOPLAY — real simulation probe")
	print("═══════════════════════════════════════════════════════════")
	var tim = get_node_or_null("/root/TouchInputManager")
	if tim == null:
		_fail("TouchInputManager missing — cannot prove real input")
		_tree().quit(1)
		return

	# MP autoplay only. The single-player flag stays OFF — this pass must not
	# touch single-player behavior, and the two flags are independent.
	AutoPlayManager.set_mp_auto_play_enabled(true)
	# The round base gates _ready() on a live session and routes to the lobby
	# without one, so this run opens a REAL host session (ENet bind, loopback)
	# the same way MultiplayerLobby's Create button does. Distinct port so an
	# aborted run of another multiplayer harness cannot collide with the bind.
	var port: int = 7812
	if not GameManager.host_game(port):
		_fail("host_game(%d) failed — no session to play in" % port)
		AutoPlayManager.set_mp_auto_play_enabled(false)
		_tree().quit(1)
		return
	_pass("host session open on port %d" % port)

	# ── catcher role: the bot must catch drops ──
	var down_before: int = tim.diag_down_total
	var game = (load(CATCHER_SCENE) as PackedScene).instantiate()
	add_child(game)
	await _frames(10)
	if game.has_method("start_game"):
		game.start_game()
	await _frames(5)
	var live: bool = bool(game.get("game_active"))
	if live:
		_pass("catcher round is live after start_game()")
	else:
		_fail("catcher round never became active")
	await get_tree().create_timer(PLAY_SECONDS).timeout

	var down_delta: int = tim.diag_down_total - down_before
	var caught: int = int(game.get("drops_caught")) if "drops_caught" in game else -1
	var score: int = int(game.get("local_score")) if "local_score" in game else -1
	print("  catcher: injected events delivered=%d, drops_caught=%d, local_score=%d"
		% [down_delta, caught, score])
	if down_delta > 0:
		_pass("autoplay injected REAL input the round received (%d events)" % down_delta)
	else:
		_fail("no input reached the round — the driver is not simulating")
	if caught > 0:
		_pass("the bot caught %d drops through the real collision path" % caught)
	else:
		_fail("the bot caught nothing in %.0fs of play" % PLAY_SECONDS)
	if score > 0:
		_pass("score flowed through the round's own add_score() path (%d pts)" % score)
	else:
		_fail("no score accrued despite catches")
	game.queue_free()
	await _frames(3)

	# ── target role: real taps on the round's real targets ──
	down_before = tim.diag_down_total
	var tgame = (load(TARGET_SCENE) as PackedScene).instantiate()
	add_child(tgame)
	await _frames(10)
	if tgame.has_method("start_game"):
		tgame.start_game()
	await _frames(5)
	var tlive: bool = bool(tgame.get("game_active"))
	if tlive:
		_pass("target round is live after start_game()")
	else:
		_fail("target round never became active")
	await get_tree().create_timer(PLAY_SECONDS).timeout
	var tdown: int = tim.diag_down_total - down_before
	print("  target: injected events delivered=%d" % tdown)
	if tdown > 0:
		_pass("autoplay taps reached the target round (%d events)" % tdown)
	else:
		_fail("no taps reached the target round")
	# Score honesty: the target role consumes the partner's water by design, so
	# a solo run is not expected to score — stated, not asserted.
	print("  (target-role score needs the partner's water by co-op design; "
		+ "input delivery is what this run asserts)")
	tgame.queue_free()
	await _frames(3)

	AutoPlayManager.set_mp_auto_play_enabled(false)
	if GameManager.has_method("disconnect_multiplayer"):
		GameManager.disconnect_multiplayer()
	print("")
	print("═══════════════════════════════════════════════════════════")
	if _fails == 0:
		print("  ALL MULTIPLAYER AUTOPLAY CHECKS PASSED")
	else:
		print("  %d CHECK(S) FAILED" % _fails)
	print("═══════════════════════════════════════════════════════════")
	_tree().quit(1 if _fails > 0 else 0)
