extends Node

## ── MP ROUND-SUMMARY FLOURISH VERIFICATION (headless) ──────────────────────
##
## The co-op round summary used to be a static wall of text while the
## single-player tally animated. This probes the multiplayer flourish added in
## MultiplayerMiniGameBase._animate_round_summary(): the droplet mascot exists,
## the entrance tweens actually run (title scale settles at 1, rows fade in),
## the fail case builds the deflated mascot, and everything is bounded.
##
## Run:  godot --headless --path . res://tools/VerifyMPSummaryFlourish.tscn

const GAME_SCENE := "res://scenes/multiplayer/MP_CatchTheRain.tscn"
const PORT: int = 7813

var _fails: int = 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _pass(m: String) -> void:
	print("  ✓ " + m)


func _fail(m: String) -> void:
	_fails += 1
	print("  ✗ " + m)


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  MP ROUND-SUMMARY FLOURISH PROBE")
	print("═══════════════════════════════════════════════════════════")
	if not GameManager.host_game(PORT):
		_fail("host_game(%d) failed" % PORT)
		_tree().quit(1)
		return

	for won in [true, false]:
		var game = (load(GAME_SCENE) as PackedScene).instantiate()
		add_child(game)
		await _frames(10)
		if game.has_method("start_game"):
			game.start_game()
		await _frames(5)
		# _show_round_summary() refills a ResultsOverlay that _show_results_screen()
		# created — the production order is round end → results screen → summary
		# when both completions land. Stage the overlay the same way, then refill.
		game.call("_show_results_screen", won)
		await _frames(3)
		game.call("_show_round_summary", won, won, 30, 20)
		await _frames(3)

		var overlay: Control = game.hud_layer.get_node_or_null("ResultsOverlay")
		if overlay == null:
			_fail("ResultsOverlay missing")
			game.queue_free()
			continue
		# The mascot row is the first child of the summary column.
		var col: VBoxContainer = null
		for c in overlay.find_children("*", "VBoxContainer", true, false):
			if (c as VBoxContainer).get_child_count() > 3:
				col = c
				break
		if col == null:
			_fail("summary column not found")
			game.queue_free()
			continue
		var row0 := col.get_child(0) as Control
		var mascot := row0.get_child(0) as Control if row0.get_child_count() > 0 else null
		if mascot != null:
			_pass("mascot built (%s case)" % ("win" if won else "fail"))
		else:
			_fail("mascot missing (%s case)" % ("win" if won else "fail"))
		# Entrance: after the tween settles, title scale is 1 and rows are visible.
		await get_tree().create_timer(1.2).timeout
		var title := col.get_child(1) as Control
		if title and title.scale.is_equal_approx(Vector2.ONE):
			_pass("title pop settled at scale 1 (%s case)" % ("win" if won else "fail"))
		else:
			_fail("title scale not settled (%s: %s)"
				% [("win" if won else "fail"), str(title.scale) if title else "none"])
		var all_visible := true
		for c in col.get_children():
			var ctl := c as Control
			if ctl and ctl != row0 and ctl.modulate.a < 0.99:
				all_visible = false
		if all_visible:
			_pass("all summary rows faded in (%s case)" % ("win" if won else "fail"))
		else:
			_fail("some rows never faded in (%s case)" % ("win" if won else "fail"))
		# Bounded: the mascot's x is back at rest after the fail shake.
		if won or mascot.position.x == 0.0:
			_pass("mascot at rest after bounded flourish (%s case)" % ("win" if won else "fail"))
		else:
			_fail("mascot left mid-shake (x=%.1f)" % mascot.position.x)
		game.queue_free()
		await _frames(3)

	GameManager.disconnect_multiplayer()
	print("")
	print("═══════════════════════════════════════════════════════════")
	if _fails == 0:
		print("  ALL FLOURISH CHECKS PASSED")
	else:
		print("  %d CHECK(S) FAILED" % _fails)
	print("═══════════════════════════════════════════════════════════")
	_tree().quit(1 if _fails > 0 else 0)
