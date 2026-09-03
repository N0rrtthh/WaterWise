extends Node

## ═══════════════════════════════════════════════════════════════════
## CO-OP INTAKE HARNESS — GameManager._check_both_players_done()
## ═══════════════════════════════════════════════════════════════════
## The one place where a finished multiplayer round becomes input to the thesis's
## Dynamic Co-Adaptation Algorithm. Two defects were fixed here by reading only,
## and neither is reachable from a parse check:
##
##   FIX 10  P1/P2 were taken from pending_mp_performance in DICTIONARY INSERTION
##           order, i.e. "whoever reported first". The same two humans could swap
##           roles between rounds, so player1_history mixed both of them and Φ1/Φ2
##           stopped describing anybody. Now assigned by sorted peer id.
##
##   FIX 11  team_success was `get_global_score() > 0` — a round that ended 1/20
##           was fed to the algorithm as a WIN, so co-op difficulty could only
##           ratchet upward. Now the round's quota must actually be met.
##
## Neither needs a second process: _check_both_players_done() is local host logic
## reading two dictionaries. It is called directly here with the table seeded in
## the hostile order (higher peer id first), which is exactly what the old code
## got wrong and what a passing run must be immune to.
##
## Run:
##   godot --headless --path . res://tools/VerifyCoopIntake.tscn
## ═══════════════════════════════════════════════════════════════════

## Deliberately NOT in ascending order when inserted: the low id is inserted
## SECOND so insertion order and sorted order disagree. P1 must still be LOW_ID.
const LOW_ID: int = 12
const HIGH_ID: int = 77

## Tags the two seeded dictionaries apart. Read back out of CoopAdaptation's own
## history, so the assertion is about what the algorithm received, not about what
## GameManager thought it sent.
const LOW_ACC: float = 0.90
const HIGH_ACC: float = 0.10

var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", label])
	if detail != "":
		print("          %s" % detail)


## Wipe the co-op state so a check reads only what this round put there. Cleared
## through the same fields add_game_result() appends to; CoopAdaptation has no
## reset entry point and adding one for a test would be a product change.
func _reset_coop() -> void:
	CoopAdaptation.player1_window.clear()
	CoopAdaptation.player1_history.clear()
	CoopAdaptation.player2_window.clear()
	CoopAdaptation.player2_history.clear()
	CoopAdaptation.total_games = 0
	CoopAdaptation.successful_games = 0
	CoopAdaptation.team_success_rate = 0.0


## Seed the round: HIGH id first so insertion order is the wrong answer.
func _seed(team_total: int, quota: int) -> void:
	GameManager.pending_mp_performance.clear()
	GameManager.pending_mp_performance[HIGH_ID] = {
		"accuracy": HIGH_ACC, "time": 9.0, "errors": 4,
	}
	GameManager.pending_mp_performance[LOW_ID] = {
		"accuracy": LOW_ACC, "time": 3.0, "errors": 0,
	}
	GameManager.g_counter = {LOW_ID: team_total}
	GameManager.current_minigame_quota = quota


func _last_acc(hist: Array) -> float:
	if hist.is_empty():
		return -1.0
	return float((hist[hist.size() - 1] as Dictionary).get("accuracy", -1.0))


func _run() -> void:
	print("\n=== VERIFY CO-OP INTAKE ===")
	if not (GameManager and CoopAdaptation):
		_check("[0] both autoloads present", false, "GameManager or CoopAdaptation missing")
		get_tree().quit(1)
		return
	_check("[0] both autoloads present", true)

	# ── FIX 11, losing side: 1 point against a quota of 20 is NOT a team success ──
	_reset_coop()
	_seed(1, 20)
	GameManager._check_both_players_done()
	var lose_games: int = int(CoopAdaptation.total_games)
	var lose_ok: int = int(CoopAdaptation.successful_games)
	_check("[1] the round reached the algorithm at all", lose_games == 1,
		"total_games=%d (a 0 here would make every later check vacuous)" % lose_games)
	_check("[2] 1/20 is recorded as a team FAILURE", lose_ok == 0,
		"successful_games=%d after a 1/20 round" % lose_ok)

	# ── FIX 10: P1 is the LOW peer id even though it was inserted SECOND ──
	var p1_acc: float = _last_acc(CoopAdaptation.player1_history)
	var p2_acc: float = _last_acc(CoopAdaptation.player2_history)
	_check("[3] P1 is the lower peer id, not the first reporter",
		is_equal_approx(p1_acc, LOW_ACC) and is_equal_approx(p2_acc, HIGH_ACC),
		"P1 acc=%.2f (want %.2f from peer %d), P2 acc=%.2f (want %.2f from peer %d)"
			% [p1_acc, LOW_ACC, LOW_ID, p2_acc, HIGH_ACC, HIGH_ID])

	# The table must be emptied, or the next round inherits this one's reporters and
	# the size() < 2 guard lets a HALF-reported round through.
	_check("[4] the pending table is cleared for the next round",
		GameManager.pending_mp_performance.is_empty(),
		"%d left: %s" % [GameManager.pending_mp_performance.size(),
			str(GameManager.pending_mp_performance.keys())])

	# ── Order independence: seed the SAME round with the ids swapped in ──────────
	# Same assertion, opposite insertion order. If [3] passed only because this
	# dictionary happens to iterate small-int keys in ascending order, this fails.
	_reset_coop()
	GameManager.pending_mp_performance.clear()
	GameManager.pending_mp_performance[LOW_ID] = {
		"accuracy": LOW_ACC, "time": 3.0, "errors": 0,
	}
	GameManager.pending_mp_performance[HIGH_ID] = {
		"accuracy": HIGH_ACC, "time": 9.0, "errors": 4,
	}
	GameManager.g_counter = {LOW_ID: 1}
	GameManager.current_minigame_quota = 20
	GameManager._check_both_players_done()
	_check("[5] the mapping is the same with the other insertion order",
		is_equal_approx(_last_acc(CoopAdaptation.player1_history), LOW_ACC)
			and is_equal_approx(_last_acc(CoopAdaptation.player2_history), HIGH_ACC),
		"P1 acc=%.2f P2 acc=%.2f" % [_last_acc(CoopAdaptation.player1_history),
			_last_acc(CoopAdaptation.player2_history)])

	# ── FIX 11, winning side: the criterion still passes a round that MET quota ──
	_reset_coop()
	_seed(20, 20)
	GameManager._check_both_players_done()
	_check("[6] 20/20 is recorded as a team SUCCESS",
		int(CoopAdaptation.successful_games) == 1,
		"successful_games=%d after a 20/20 round" % int(CoopAdaptation.successful_games))

	# ── and a survival round (no quota) is still a success ──────────────────────
	# current_minigame_quota <= 0 means the game had no points target; the old
	# `> 0` test would have called such a round a failure at 0 points.
	_reset_coop()
	_seed(0, 0)
	GameManager._check_both_players_done()
	_check("[7] a no-quota round counts as a success at 0 points",
		int(CoopAdaptation.successful_games) == 1,
		"successful_games=%d with quota=0" % int(CoopAdaptation.successful_games))

	# ── the guard: one reporter is not a round ──────────────────────────────────
	_reset_coop()
	GameManager.pending_mp_performance.clear()
	GameManager.pending_mp_performance[LOW_ID] = {
		"accuracy": LOW_ACC, "time": 3.0, "errors": 0,
	}
	GameManager._check_both_players_done()
	_check("[8] a single reporter does not feed the algorithm",
		int(CoopAdaptation.total_games) == 0
			and GameManager.pending_mp_performance.size() == 1,
		"total_games=%d pending=%d" % [int(CoopAdaptation.total_games),
			GameManager.pending_mp_performance.size()])

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
