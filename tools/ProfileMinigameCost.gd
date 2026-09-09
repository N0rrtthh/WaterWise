extends Node

## ── MINIGAME FRAME-COST + TEARDOWN PROBE ───────────────────────────────────
##
## Item-1 follow-up (Moto E5 Plus throttling, worst samples late in the session
## and at scene-transition boundaries). Two questions per minigame, answered
## headless where wall-clock per frame IS the CPU cost:
##
##   1. Cost: average wall-clock per frame over 240 frames of active play, and
##      node count — the relative per-frame load each game adds on top of the
##      engine. On a device these numbers are what the thermal governor reacts
##      to; the game with the worst ratio is where sustained-heat reduction
##      pays most.
##   2. Teardown: after the game is freed the way a scene transition frees it
##      (queue_free + 3 frames), the whole SceneTree node count must return to
##      its pre-instantiation baseline. A positive delta is orphaned work that
##      would accumulate across a session of consecutive minigames.
##
## Run:  godot --headless --path . res://tools/ProfileMinigameCost.tscn

const GAMES := [
	"ToiletTankFix", "CoverTheDrum", "QuickShower",
	"RiceWashRescue", "CatchTheRain", "VegetableBath",
]
const WARM_FRAMES := 30
const MEASURE_FRAMES := 240


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  MINIGAME COST + TEARDOWN PROBE (headless CPU wall-clock)")
	print("═══════════════════════════════════════════════════════════")
	var worst_cost := ""
	var worst_cost_ms := 0.0
	var any_orphan := false
	for game_name in GAMES:
		var path := "res://scenes/minigames/%s.tscn" % game_name
		if not ResourceLoader.exists(path):
			print("  %s: scene missing, skipped" % game_name)
			continue
		var baseline: int = _tree().get_node_count()
		var scene := load(path) as PackedScene
		var game = scene.instantiate()
		add_child(game)
		await _frames(WARM_FRAMES)
		# Force the round active even if the intro overlay is still playing:
		# the measurement must reflect gameplay, not the intro.
		if game.has_method("start_game") and not game.game_active:
			game.start_game()
		await _frames(2)
		var nodes_live: int = _tree().get_node_count()
		var t0 := Time.get_ticks_usec()
		for _i in range(MEASURE_FRAMES):
			await _tree().process_frame
		var ms_per_frame := (Time.get_ticks_usec() - t0) / 1000.0 / float(MEASURE_FRAMES)
		if ms_per_frame > worst_cost_ms:
			worst_cost_ms = ms_per_frame
			worst_cost = game_name
		# Teardown the way GameManager.transition_to_scene does: the old scene
		# is simply freed.
		game.queue_free()
		await _frames(3)
		var after: int = _tree().get_node_count()
		var orphan: int = after - baseline
		print("  %s" % game_name)
		print("    nodes_live=%d  cost=%.2f ms/frame" % [nodes_live - baseline, ms_per_frame])
		print("    teardown: baseline=%d after=%d delta=%d  %s"
			% [baseline, after, orphan, "OK" if orphan <= 0 else "ORPHANED NODES"])
		if orphan > 0:
			any_orphan = true

	print("")
	print("  heaviest game: %s (%.2f ms/frame)" % [worst_cost, worst_cost_ms])
	if any_orphan:
		print("  ✗ ORPHANED NODES DETECTED — teardown leak across rounds")
	else:
		print("  ✓ every game tears down to the baseline node count (no cross-round accumulation)")
	print("═══════════════════════════════════════════════════════════")
	_tree().quit(1 if any_orphan else 0)
