extends Node

## ═══════════════════════════════════════════════════════════════════
## VerifyHumanSim — proves the OPT-IN human-simulation realism layer (item 3).
## ═══════════════════════════════════════════════════════════════════
## The realism layer lives INSIDE the injection primitives (_tap_at,
## _start_gesture, _drive_pointer/_hold_at/_drag_to) and is gated by
## AutoPlayManager._hsim_active(), which is FALSE in the default PERFECT mode.
##
## Three phases, headless, self-contained:
##   A — PERFECT is a STRICT no-op at the hook level: gates fire on first sight
##       (no reaction clock), aim helpers return the input position unchanged,
##       the miss roll never fires, and no reaction sample is ever recorded.
##   B — HUMAN_LIKE hooks produce real variance: reaction times span the Hard
##       band and differ sample-to-sample, aim jitter perturbs the target, the
##       miss roll fires sometimes, and a brand-new target is delayed once.
##   C — End-to-end on two shipped games (one tap, one hold) over several runs:
##       HUMAN_LIKE yields mistakes>0 and accuracy<100% at least sometimes and
##       reaction times that vary run-to-run; switching back to PERFECT injects
##       NO reaction delay during real play and never adds mistakes.
##
## This harness drives the REAL AutoPlayManager._process (the only drive that
## reaches injected input) exactly like tools/VerifyCloudCatcherClearable.gd,
## and tears each round down BEFORE its round-end chain so a change_scene can
## never free this coroutine out from under itself.

const TAP_GAME := "res://scenes/minigames/ThirstyPlant.tscn"
const HOLD_GAME := "res://scenes/minigames/RiceWashRescue.tscn"
## DropletDash is the game whose OWN grading turns injected realism into a graded
## mistake: every lane switch is a _start_gesture (gated by the discrete reaction
## delay), each obstacle the delayed dodge fails to avoid is a record_action(false)
## (3 lives), and record_action(true) fires only on a caught collectible. So a
## HUMAN_LIKE reaction delay reliably drops accuracy below 100% while PERFECT — no
## delay — dodges clean. ThirstyPlant (tap) and RiceWashRescue (hold) represent the
## _tap_at and _drive_pointer primitive families and prove the reaction delay varies
## run-to-run on the real drive; a realistic ~130px aim miss simply whiffs between
## ThirstyPlant's 480px-apart buckets, so the mistake signal is carried by DropletDash.
const DASH_GAME := "res://scenes/minigames/DropletDash.tscn"
## Hard tier = slowest reactions, widest miss band, highest mistake rate — the
## most visible realism, so the variance shows up within a handful of runs.
const DIFF := "Hard"
const HUMAN_RUNS := 3
const PERFECT_RUNS := 2

var _pass: int = 0
var _fail: int = 0

func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [ok]   %s%s" % [label, "" if detail.is_empty() else "  —  " + detail])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [label, "" if detail.is_empty() else "  —  " + detail])

func _ready() -> void:
	var vw: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	get_window().size = Vector2i(vw, vh)
	await get_tree().process_frame
	await get_tree().process_frame
	print("\n=== VerifyHumanSim (opt-in realism; PERFECT must stay a no-op) ===")
	print("  viewport %dx%d, difficulty %s, %d human / %d perfect runs per game"
		% [vw, vh, DIFF, HUMAN_RUNS, PERFECT_RUNS])

	_phase_a_perfect_noop()
	_phase_b_human_hooks()
	await _phase_c_games()

	# Leave the autoload exactly as a fresh boot would: PERFECT, autoplay off.
	AutoPlayManager.set_human_sim_mode(HumanSimProfile.Mode.PERFECT, false)
	AutoPlayManager.auto_play_enabled = false
	AutoPlayManager.call("_hsim_reset")

	print("=== %d passed / %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE A — PERFECT is a strict no-op at the hook level
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _phase_a_perfect_noop() -> void:
	print("-- Phase A: PERFECT no-op --")
	AutoPlayManager.set_human_sim_mode(HumanSimProfile.Mode.PERFECT, false)
	# Deliberately leave the autoplay path LIVE: even with the bot armed, PERFECT
	# must not touch a single realism hook. This is the byte-identical invariant.
	AutoPlayManager.auto_play_enabled = true
	AutoPlayManager.hsim_reaction_samples.clear()
	AutoPlayManager.call("_hsim_reset")

	_check(AutoPlayManager.get_human_sim_mode() == HumanSimProfile.Mode.PERFECT,
		"mode is PERFECT (the default)")
	_check(AutoPlayManager.call("_hsim_active") == false,
		"_hsim_active() is false in PERFECT even with autoplay on")

	var p := Vector2(300.0, 400.0)
	var p2 := Vector2(900.0, 1200.0)
	# A brand-new target fires on the FIRST sight: no reaction clock was started.
	_check(AutoPlayManager.call("_hsim_gate_discrete", p) == true,
		"discrete gate fires immediately on a new target (no reaction delay)")
	_check(AutoPlayManager.call("_hsim_gate_continuous", p2) == true,
		"continuous gate engages immediately (no reaction delay)")
	_check(AutoPlayManager.call("_hsim_aim_discrete", p) == p,
		"discrete aim returns the position unchanged")
	_check(AutoPlayManager.call("_hsim_aim_continuous", p) == p,
		"continuous aim returns the position unchanged")
	_check(AutoPlayManager.call("_hsim_should_miss") == false,
		"miss roll never fires in PERFECT")
	_check(AutoPlayManager.hsim_reaction_samples.is_empty(),
		"no reaction sample recorded in PERFECT")

	AutoPlayManager.auto_play_enabled = false
	AutoPlayManager.call("_hsim_reset")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE B — HUMAN_LIKE hooks produce real variance
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _phase_b_human_hooks() -> void:
	print("-- Phase B: HUMAN_LIKE variance at the hook level --")
	if AdaptiveDifficulty:
		AdaptiveDifficulty.current_difficulty = DIFF
		AdaptiveDifficulty.progressive_level = 0
	AutoPlayManager.set_human_sim_mode(HumanSimProfile.Mode.HUMAN_LIKE, false)
	AutoPlayManager.auto_play_enabled = true
	AutoPlayManager.hsim_reaction_samples.clear()
	AutoPlayManager.call("_hsim_reset")

	_check(AutoPlayManager.call("_hsim_active") == true,
		"_hsim_active() is true in HUMAN_LIKE with autoplay on")

	# The Hard band straight from a reference profile — not hardcoded here.
	var ref: HumanSimProfile = HumanSimProfile.new()
	var band: Vector2 = ref.get_reaction_range(HumanSimProfile.Difficulty.HARD)

	for _i in range(60):
		AutoPlayManager.call("_hsim_sample_reaction_ms")
	var s: Array = AutoPlayManager.hsim_reaction_samples.duplicate()
	var distinct: Dictionary = {}
	var lo: int = 1 << 30
	var hi: int = -1
	for v in s:
		distinct[int(v)] = true
		lo = mini(lo, int(v))
		hi = maxi(hi, int(v))
	_check(distinct.size() >= 5, "reaction times vary",
		"%d distinct of %d samples" % [distinct.size(), s.size()])
	_check(hi > lo, "reaction span is non-zero", "%d..%d ms" % [lo, hi])
	_check(lo >= int(band.x) - 10 and hi <= int(band.y) + 10,
		"reaction samples sit inside the Hard band",
		"got %d..%d, band %d..%d" % [lo, hi, int(band.x), int(band.y)])

	# Aim jitter + miss roll on a discrete shot.
	var base := Vector2(600.0, 800.0)
	var seen: Dictionary = {}
	var far: int = 0
	for _i in range(120):
		var a: Vector2 = AutoPlayManager.call("_hsim_aim_discrete", base)
		seen[a] = true
		if a.distance_to(base) > 60.0:
			far += 1
	_check(seen.size() >= 10, "aim jitter perturbs the target",
		"%d distinct aims of 120" % seen.size())
	_check(far > 0, "miss roll deliberately aims off-target sometimes",
		"%d/120 far off-target" % far)

	# A brand-new discrete target is delayed ONCE and samples exactly one reaction.
	AutoPlayManager.call("_hsim_reset")
	AutoPlayManager.hsim_reaction_samples.clear()
	var first: bool = AutoPlayManager.call("_hsim_gate_discrete", Vector2(222.0, 888.0))
	_check(first == false, "discrete gate delays a brand-new target (reaction clock started)")
	_check(AutoPlayManager.hsim_reaction_samples.size() == 1,
		"exactly one reaction sampled on target acquisition")

	AutoPlayManager.hsim_reaction_samples.clear()
	AutoPlayManager.auto_play_enabled = false
	AutoPlayManager.call("_hsim_reset")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE C — end-to-end on two shipped games over several runs
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _phase_c_games() -> void:
	print("-- Phase C: real game drives (tap / hold / gesture) --")
	# One entry per primitive family: _tap_at (ThirstyPlant), _drive_pointer hold
	# (RiceWashRescue), _start_gesture discrete (DropletDash, the mistake-producer).
	var games: Array = [
		[TAP_GAME, "tap  "], [HOLD_GAME, "hold "], [DASH_GAME, "dash "],
	]

	# ── HUMAN_LIKE ──────────────────────────────────────────────
	if AdaptiveDifficulty:
		AdaptiveDifficulty.current_difficulty = DIFF
		AdaptiveDifficulty.progressive_level = 0
	AutoPlayManager.set_human_sim_mode(HumanSimProfile.Mode.HUMAN_LIKE, false)
	AutoPlayManager.hsim_reaction_samples.clear()

	var h_mistakes: int = 0
	var h_runs_with_mistake: int = 0
	var h_min_acc: float = 1.0
	var h_acc_sum: float = 0.0
	var h_acc_n: int = 0
	var per_run_first: Array[int] = []
	for entry in games:
		var game_path: String = entry[0]
		var tag: String = entry[1]
		for r in range(HUMAN_RUNS):
			var base: int = AutoPlayManager.hsim_reaction_samples.size()
			var res: Dictionary = await _drive_game(game_path, DIFF)
			if res.is_empty():
				continue
			var run_samples: Array = AutoPlayManager.hsim_reaction_samples.slice(base)
			if run_samples.size() > 0:
				per_run_first.append(int(run_samples[0]))
			h_mistakes += int(res["mistakes"])
			if int(res["mistakes"]) > 0:
				h_runs_with_mistake += 1
			h_min_acc = minf(h_min_acc, float(res["accuracy"]))
			h_acc_sum += float(res["accuracy"])
			h_acc_n += 1
			print("   [HUMAN ] %s %-20s run %d: mistakes=%d correct=%d total=%d acc=%.2f react_first=%s"
				% [tag, game_path.get_file(), r, int(res["mistakes"]), int(res["correct"]),
					int(res["total"]), float(res["accuracy"]),
					str(run_samples[0]) if run_samples.size() > 0 else "n/a"])
	var h_mean_acc: float = h_acc_sum / float(maxi(1, h_acc_n))

	_check(h_runs_with_mistake > 0, "HUMAN_LIKE produced mistakes>0 in at least one run",
		"%d runs, %d with a mistake" % [HUMAN_RUNS * games.size(), h_runs_with_mistake])
	_check(h_min_acc < 1.0, "HUMAN_LIKE accuracy dropped below 100% at least once",
		"min acc %.2f" % h_min_acc)
	var distinct_runs: Dictionary = {}
	for v in per_run_first:
		distinct_runs[v] = true
	_check(distinct_runs.size() >= 2, "reaction time varies run-to-run",
		"%d distinct first-reactions across %d runs" % [distinct_runs.size(), per_run_first.size()])

	# ── PERFECT (deterministic, no injected realism) ─────────────
	AutoPlayManager.set_human_sim_mode(HumanSimProfile.Mode.PERFECT, false)
	AutoPlayManager.hsim_reaction_samples.clear()
	var p_mistakes: int = 0
	var p_acc_sum: float = 0.0
	var p_acc_n: int = 0
	for entry in games:
		var game_path: String = entry[0]
		var tag: String = entry[1]
		for r in range(PERFECT_RUNS):
			var res: Dictionary = await _drive_game(game_path, DIFF)
			if res.is_empty():
				continue
			p_mistakes += int(res["mistakes"])
			p_acc_sum += float(res["accuracy"])
			p_acc_n += 1
			print("   [PERFCT] %s %-20s run %d: mistakes=%d correct=%d total=%d acc=%.2f"
				% [tag, game_path.get_file(), r, int(res["mistakes"]), int(res["correct"]),
					int(res["total"]), float(res["accuracy"])])
	var p_mean_acc: float = p_acc_sum / float(maxi(1, p_acc_n))

	# The strongest end-to-end no-op proof: during REAL gameplay in PERFECT the
	# realism path never ran, so not one reaction sample was recorded.
	_check(AutoPlayManager.hsim_reaction_samples.is_empty(),
		"PERFECT injected NO reaction delay during real play",
		"%d samples" % AutoPlayManager.hsim_reaction_samples.size())
	_check(p_mistakes <= h_mistakes,
		"PERFECT never adds mistakes vs HUMAN_LIKE (realism only injects errors)",
		"PERFECT %d vs HUMAN_LIKE %d" % [p_mistakes, h_mistakes])
	_check(p_mean_acc >= h_mean_acc - 0.02,
		"PERFECT mean accuracy is at least HUMAN_LIKE's",
		"PERFECT %.2f vs HUMAN_LIKE %.2f" % [p_mean_acc, h_mean_acc])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Drive one real round through AutoPlayManager._process (the shipped bot path).
# Returns {mistakes, correct, total, accuracy}; empty if it could not be driven.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _drive_game(scene_path: String, diff: String) -> Dictionary:
	if AdaptiveDifficulty:
		AdaptiveDifficulty.current_difficulty = diff
		AdaptiveDifficulty.progressive_level = 0
	var packed: PackedScene = load(scene_path)
	if packed == null:
		_check(false, "%s loads" % scene_path.get_file())
		return {}
	var game: Node = packed.instantiate()
	# Enable autoplay BEFORE the game enters the tree: MiniGameBase registers with
	# AutoPlayManager in its own _ready, and register_game() returns early unless
	# autoplay is already on. The game goes under ROOT (not this harness, which is
	# the current scene) so a round-end transition cannot take the harness down.
	AutoPlayManager.auto_play_enabled = true
	AutoPlayManager.auto_play_duration = 0.0
	AutoPlayManager.auto_play_start_time = 0
	AutoPlayManager.current_game = null
	AutoPlayManager.game_name = ""
	get_tree().root.add_child(game)
	for _i in range(8):
		await get_tree().process_frame
	AutoPlayManager.current_game = game
	if not game.has_method("start_game"):
		_teardown(game)
		return {}
	if game.has_method("_hide_instruction_overlay"):
		game.call("_hide_instruction_overlay")
	game.call("start_game")

	# Budget = the round's own clock at ~60fps plus a 12s slack so a round that
	# never ends on its own cannot hang the harness.
	var dur: float = float(game.get("game_duration")) if "game_duration" in game else 15.0
	var budget: int = int(dur * 60.0) + 720
	var frames: int = 0
	while frames < budget:
		await get_tree().process_frame
		frames += 1
		if not is_instance_valid(game):
			break
		if not bool(game.get("game_active")):
			break

	var res: Dictionary = {}
	if is_instance_valid(game):
		var mistakes: int = int(game.get("mistakes_made")) if "mistakes_made" in game else 0
		var correct: int = int(game.get("correct_actions")) if "correct_actions" in game else 0
		var total: int = int(game.get("total_actions")) if "total_actions" in game else 0
		res = {
			"mistakes": mistakes, "correct": correct, "total": total,
			"accuracy": (float(correct) / float(total)) if total > 0 else 1.0,
		}
	_teardown(game)
	await get_tree().process_frame
	return res

## Detach the round the shipped bot just drove. auto_play_enabled goes false FIRST
## so the next AutoPlayManager._process cannot run _navigate_ui() on a finished
## round and fire a real change_scene that would free this harness. The game is
## removed from root and free()d (not queue_free) so its end chain is stranded on a
## dead instance instead of changing the scene.
func _teardown(game: Node) -> void:
	if AutoPlayManager != null:
		AutoPlayManager.current_game = null
		AutoPlayManager.auto_play_enabled = false
		AutoPlayManager.game_name = ""
		if AutoPlayManager.has_method("_release_pointer"):
			AutoPlayManager.call("_release_pointer")
		AutoPlayManager.call("_hsim_reset")
	get_tree().paused = false
	if is_instance_valid(game):
		if game.is_inside_tree():
			game.get_parent().remove_child(game)
		game.free()
