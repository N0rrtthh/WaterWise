extends Node

## ═══════════════════════════════════════════════════════════════════
## ALGORITHM VERIFICATION HARNESS (headless, thesis-auditable)
## ═══════════════════════════════════════════════════════════════════
## Runs as a real scene so the project's autoloads (AdaptiveDifficulty,
## GCounter, PerformanceProfiler) are live — the `test/` folder is
## .gdignore'd, so nothing in there is compiled or executed.
##
## Verifies:
##   1. Φ = WMA(accuracy) − CP  against hand-computed reference values
##   2. Rule-based decision-tree boundaries (0.5 / 0.85 thresholds)
##   3. Rolling window never exceeds window_size (O(1) space claim)
##   4. G-Counter CRDT: commutativity, associativity, idempotency
##   5. G-Counter grow-only + monotonicity invariants
##   6. Bounded telemetry history (memory-safety regression guard)
##
## Run:
##   Godot --headless --path <project> res://tools/VerifyAlgorithms.tscn
## Exit code 0 = all passed, 1 = at least one failure.
## ═══════════════════════════════════════════════════════════════════

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE ALGORITHM VERIFICATION")
	print("═══════════════════════════════════════════════════════════")

	_verify_wma_and_phi()
	_verify_decision_tree_boundaries()
	_verify_window_is_bounded()
	_verify_crdt_properties()
	_verify_grow_only()
	_verify_bounded_history()

	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		for f in _failures:
			print("    ✗ %s" % f)
	print("═══════════════════════════════════════════════════════════")
	print("")

	# Non-zero exit so CI / the thesis build pipeline can gate on this.
	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		var msg := label if detail == "" else "%s — %s" % [label, detail]
		_failures.append(msg)
		print("  ✗ %s  %s" % [label, detail])


func _approx(a: float, b: float, tol: float = 0.0005) -> bool:
	return absf(a - b) <= tol


# ═══════════════════════════════════════════════════════════════════
# 1. WEIGHTED MOVING AVERAGE + PROFICIENCY INDEX
# ═══════════════════════════════════════════════════════════════════
## Reference case taken from the algorithm's own documented example:
##   accuracies [0.50, 0.60, 0.70, 0.80, 0.90], linear weights 1..5
##   WMA = (0.5·1 + 0.6·2 + 0.7·3 + 0.8·4 + 0.9·5) / 15 = 11.50/15 = 0.76667
## Reaction times are held CONSTANT so σ = 0 → CP = 0 → Φ must equal WMA
## exactly. That isolates the WMA math from the penalty math.
func _verify_wma_and_phi() -> void:
	print("")
	print("── 1. Weighted Moving Average & Proficiency Index ──")

	AdaptiveDifficulty.reset()
	for a in [0.50, 0.60, 0.70, 0.80, 0.90]:
		# Constant reaction_time → zero variance → zero consistency penalty
		AdaptiveDifficulty.add_performance(a, 8000, 0)

	var m: Dictionary = AdaptiveDifficulty._calculate_window_metrics()
	var wma: float = m["weighted_accuracy"]
	var cp: float = m["consistency_penalty"]
	var phi: float = m["proficiency_index"]

	_check(
		"WMA of [.5 .6 .7 .8 .9] = 0.76667",
		_approx(wma, 11.50 / 15.0),
		"got %.5f" % wma
	)
	_check("σ=0 on constant times → CP = 0", _approx(cp, 0.0), "got %.5f" % cp)
	_check(
		"Φ = WMA − CP holds exactly",
		_approx(phi, wma - cp),
		"Φ=%.5f WMA=%.5f CP=%.5f" % [phi, wma, cp]
	)
	_check(
		"WMA > simple mean (0.70) — recency really is weighted",
		wma > 0.70,
		"got %.5f" % wma
	)

	# ── Consistency penalty: strictly positive, and capped at 0.2 ──
	AdaptiveDifficulty.reset()
	for t in [500, 19000, 1200, 18000, 900]:
		AdaptiveDifficulty.add_performance(0.9, t, 0)
	var m2: Dictionary = AdaptiveDifficulty._calculate_window_metrics()
	_check(
		"Erratic timing produces CP > 0",
		m2["consistency_penalty"] > 0.0,
		"CP=%.4f" % m2["consistency_penalty"]
	)
	_check(
		"CP capped at 0.20 (never over-penalizes)",
		m2["consistency_penalty"] <= 0.2001,
		"CP=%.4f" % m2["consistency_penalty"]
	)
	_check(
		"Φ stays within [-0.2, 1.0] under erratic input",
		m2["proficiency_index"] >= -0.2 and m2["proficiency_index"] <= 1.0,
		"Φ=%.4f" % m2["proficiency_index"]
	)


## Build a synthetic metrics dict so the decision tree is tested in
## isolation from the metric-computation pipeline.
func _metrics_for(phi: float) -> Dictionary:
	return {
		"proficiency_index": phi,
		"weighted_accuracy": phi,
		"consistency_penalty": 0.0,
		"std_deviation": 0.0,
		"success_rate": phi,
		"avg_time": 8000.0,
		"avg_mistakes": 0.0,
		"total_errors": 0,
		"window_size": 5,
	}


# ═══════════════════════════════════════════════════════════════════
# 2. RULE-BASED DECISION TREE BOUNDARIES
# ═══════════════════════════════════════════════════════════════════
## The paper defines three mutually exclusive rules:
##   Φ < 0.50        → Easy    (struggling / erratic)
##   0.50 ≤ Φ ≤ 0.85 → Medium  (flow state)
##   Φ > 0.85        → Hard    (mastery)
## Boundary values are tested explicitly — off-by-one comparison errors
## at 0.50 and 0.85 are the most likely defect in a rule-based engine.
func _verify_decision_tree_boundaries() -> void:
	print("")
	print("── 2. Rule-Based Decision Tree ──")

	var cases := [
		[0.10, "Easy",   "far below struggling threshold"],
		[0.49, "Easy",   "just below 0.50 boundary"],
		[0.50, "Medium", "exactly at lower flow boundary"],
		[0.70, "Medium", "mid flow state"],
		[0.85, "Medium", "exactly at upper flow boundary"],
		[0.86, "Hard",   "just above mastery threshold"],
		[0.99, "Hard",   "near-perfect mastery"],
	]

	for c in cases:
		var phi: float = c[0]
		var want: String = c[1]
		var decision: Dictionary = AdaptiveDifficulty._evaluate_decision_tree(
			_metrics_for(phi)
		)
		_check(
			"Φ=%.2f → %s (%s)" % [phi, want, c[2]],
			decision["new_difficulty"] == want,
			"got %s" % decision["new_difficulty"]
		)

	# Determinism is the core claim separating this from an ML model:
	# identical input must always produce identical output.
	var fixed := _metrics_for(0.66)
	var first: String = AdaptiveDifficulty._evaluate_decision_tree(fixed)["new_difficulty"]
	var deterministic := true
	for _i in range(50):
		if AdaptiveDifficulty._evaluate_decision_tree(fixed)["new_difficulty"] != first:
			deterministic = false
			break
	_check("Deterministic across 50 identical calls", deterministic)


# ═══════════════════════════════════════════════════════════════════
# 3. ROLLING WINDOW IS BOUNDED (O(1) space)
# ═══════════════════════════════════════════════════════════════════
## The thesis claims O(1) time/space via a fixed-size window. Feeding
## 200 games must never grow the window past window_size — otherwise the
## complexity claim is false and memory grows with session length.
func _verify_window_is_bounded() -> void:
	print("")
	print("── 3. Fixed-Size Rolling Window (O(1) space) ──")

	AdaptiveDifficulty.reset()
	var cap: int = AdaptiveDifficulty.window_size
	var max_seen: int = 0
	for i in range(200):
		AdaptiveDifficulty.add_performance(randf(), 5000 + (i % 7) * 400, i % 3)
		var sz: int = AdaptiveDifficulty.performance_window.size()
		if sz > max_seen:
			max_seen = sz

	_check(
		"Window never exceeds window_size (%d) across 200 games" % cap,
		max_seen <= cap,
		"peaked at %d" % max_seen
	)
	_check(
		"Window saturated at exactly %d after 200 games" % cap,
		AdaptiveDifficulty.performance_window.size() == cap,
		"got %d" % AdaptiveDifficulty.performance_window.size()
	)
	_check(
		"Difficulty is always one of the three defined levels",
		AdaptiveDifficulty.get_current_difficulty() in ["Easy", "Medium", "Hard"],
		AdaptiveDifficulty.get_current_difficulty()
	)


# ═══════════════════════════════════════════════════════════════════
# 4. G-COUNTER CRDT MATHEMATICAL PROPERTIES
# ═══════════════════════════════════════════════════════════════════
## Strong Eventual Consistency requires all three properties to hold.
## Beyond the built-in checks, convergence is verified empirically: two
## divergent replicas exchanging state in EITHER order must agree.
func _verify_crdt_properties() -> void:
	print("")
	print("── 4. G-Counter CRDT Properties ──")

	var props: Dictionary = GCounter.verify_all_properties()
	_check("Commutativity: merge(A,B) = merge(B,A)", props["commutativity"] == true)
	_check(
		"Associativity: merge(merge(A,B),C) = merge(A,merge(B,C))",
		props["associativity"] == true
	)
	_check("Idempotency: merge(A,A) = A", props["idempotency"] == true)

	# Replica 1 believes {1:7, 2:2}; Replica 2 believes {1:3, 2:9}.
	# Element-wise max must give {1:7, 2:9} → global 16, order-independent.
	GCounter.reset()
	GCounter.initialize([1, 2])
	GCounter.increment(1, 7)
	GCounter.increment(2, 2)
	GCounter.merge({1: 3, 2: 9})
	var score_a: int = GCounter.query()

	GCounter.reset()
	GCounter.initialize([1, 2])
	GCounter.increment(1, 3)
	GCounter.increment(2, 9)
	GCounter.merge({1: 7, 2: 2})
	var score_b: int = GCounter.query()

	_check(
		"Divergent replicas converge identically regardless of merge order",
		score_a == score_b and score_a == 16,
		"A=%d B=%d (expected 16)" % [score_a, score_b]
	)

	# Re-merging stale state must be a no-op (idempotency in practice).
	GCounter.merge({1: 7, 2: 2})
	_check(
		"Re-merging already-seen state does not alter the score",
		GCounter.query() == 16,
		"got %d" % GCounter.query()
	)


# ═══════════════════════════════════════════════════════════════════
# 5. GROW-ONLY INVARIANT
# ═══════════════════════════════════════════════════════════════════
## A G-Counter that can decrease is no longer conflict-free: concurrent
## decrements would produce divergent replicas.
func _verify_grow_only() -> void:
	print("")
	print("── 5. Grow-Only Invariant ──")

	GCounter.reset()
	GCounter.initialize([1, 2])
	GCounter.increment(1, 5)
	var before: int = GCounter.query()
	GCounter.increment(1, -3)  # must be rejected
	_check(
		"Negative increment rejected (score unchanged)",
		GCounter.query() == before,
		"before=%d after=%d" % [before, GCounter.query()]
	)

	GCounter.reset()
	GCounter.initialize([1, 2])
	var prev: int = 0
	var monotonic := true
	for i in range(300):
		GCounter.increment(1 if i % 2 == 0 else 2, 1)
		var now: int = GCounter.query()
		if now < prev:
			monotonic = false
			break
		prev = now
	_check("Global score monotonically non-decreasing over 300 increments", monotonic)


# ═══════════════════════════════════════════════════════════════════
# 6. BOUNDED TELEMETRY HISTORY (memory-safety regression guard)
# ═══════════════════════════════════════════════════════════════════
## History arrays must stay capped while reported lifetime totals stay
## exact. If totals were derived from .size(), a long session would
## silently under-report operations and skew the thesis figures.
func _verify_bounded_history() -> void:
	print("")
	print("── 6. Bounded Telemetry History ──")

	GCounter.reset()
	GCounter.initialize([1, 2])
	var n: int = GCounter.MAX_HISTORY_ENTRIES + 250
	for _i in range(n):
		GCounter.increment(1, 1)

	_check(
		"increment_history capped at %d" % GCounter.MAX_HISTORY_ENTRIES,
		GCounter.increment_history.size() <= GCounter.MAX_HISTORY_ENTRIES,
		"got %d" % GCounter.increment_history.size()
	)

	var exported: Dictionary = GCounter.export_session_data()
	_check(
		"Exported total_increments exact (%d) despite capped history" % n,
		exported["total_increments"] == n,
		"got %s" % str(exported["total_increments"])
	)
	_check(
		"Export flags that history was capped (honest reporting)",
		exported["history_capped"] == true
	)
	_check(
		"Score still exact after history trimming",
		GCounter.query() == n,
		"got %d" % GCounter.query()
	)

	_check(
		"Profiler MAX_HISTORY_SAMPLES = 1800 (30 min @ 1s)",
		PerformanceProfiler.MAX_HISTORY_SAMPLES == 1800,
		"got %d" % PerformanceProfiler.MAX_HISTORY_SAMPLES
	)
	_check(
		"Battery sysfs polling throttled to >= 1s (not per-frame)",
		PerformanceProfiler.BATTERY_SAMPLE_INTERVAL >= 1.0,
		"got %.2f" % PerformanceProfiler.BATTERY_SAMPLE_INTERVAL
	)


