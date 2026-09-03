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
##   7. The paper's PUBLISHED worked example, end to end
##   8. Raw Game Score formula behaviour
##   9. Integer-only G-Counter sync payload
##  10. Published Output Specification sets, and that the supplementary
##      progression ramp stays bounded instead of escalating without limit
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
	_verify_published_worked_example()
	_verify_raw_game_score()
	_verify_sync_payload()
	_verify_output_specification()

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

	var m: Dictionary = AdaptiveDifficulty.get_window_metrics()
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
	var m2: Dictionary = AdaptiveDifficulty.get_window_metrics()
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
		var decision: Dictionary = AdaptiveDifficulty.evaluate_decision_tree(
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
	var first: String = AdaptiveDifficulty.evaluate_decision_tree(fixed)["new_difficulty"]
	var deterministic := true
	for _i in range(50):
		if AdaptiveDifficulty.evaluate_decision_tree(fixed)["new_difficulty"] != first:
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


# ═══════════════════════════════════════════════════════════════════
# 7. THE PAPER'S PUBLISHED WORKED EXAMPLE
# ═══════════════════════════════════════════════════════════════════
## Sections 1-3 verify internal consistency: that Φ = WMA − CP, that the
## thresholds sit where they should, that the window stays bounded. All of
## that can hold perfectly while the artifact still produces DIFFERENT
## NUMBERS from the ones printed in the thesis — which is undefendable at a
## defense, because the panel can hand-check the published table.
##
## So this section pins the paper's own 5-game simulation, end to end:
##   accuracies      [0.60, 0.65, 0.75, 0.85, 0.90]
##   reaction times  [8000, 7500, 6500, 5500, 5000] ms
##   mistakes        [4, 3, 2, 1, 0]
## from which the paper derives, for Game 6's decision:
##   WMA = 12.05/15 = 0.803
##   σ   = sqrt(6500000/5) = 1140 ms
##   CP  = min(1140/5000, 0.2) = 0.2  (capped)
##   Φ   = 0.803 − 0.2 = 0.603 → MEDIUM
##
## The CP line is the one that matters: the normalizer is a FIXED 5000, not
## the active difficulty's time limit. A tier-scaled divisor yields CP=0.057
## and Φ=0.746 on this same data — still Medium, so no test that only checks
## the final tier would catch it, yet every intermediate figure in the paper
## would be wrong.
const SIM_ACCURACY: Array = [0.60, 0.65, 0.75, 0.85, 0.90]
const SIM_REACTION_MS: Array = [8000, 7500, 6500, 5500, 5000]
const SIM_MISTAKES: Array = [4, 3, 2, 1, 0]


func _verify_published_worked_example() -> void:
	print("")
	print("── 7. Paper's Published Worked Example ──")

	var phi_by_tier: Dictionary = {}

	for tier in ["Easy", "Medium", "Hard"]:
		AdaptiveDifficulty.reset()
		AdaptiveDifficulty.current_difficulty = tier
		for i in range(SIM_ACCURACY.size()):
			AdaptiveDifficulty.add_performance(
				SIM_ACCURACY[i], SIM_REACTION_MS[i], SIM_MISTAKES[i]
			)
		var m: Dictionary = AdaptiveDifficulty.get_window_metrics()
		phi_by_tier[tier] = m["proficiency_index"]

		if tier == "Easy":
			_check(
				"Published WMA = 0.803",
				_approx(m["weighted_accuracy"], 0.803, 0.001),
				"got %.4f" % m["weighted_accuracy"]
			)
			_check(
				"Published σ = 1140 ms",
				_approx(m["std_deviation"], 1140.0, 1.0),
				"got %.2f" % m["std_deviation"]
			)
			_check(
				"Published CP = 0.2 (σ/5000 capped, NOT σ/time_limit)",
				_approx(m["consistency_penalty"], 0.2, 0.001),
				"got %.4f" % m["consistency_penalty"]
			)
			_check(
				"Published Φ = 0.603",
				_approx(m["proficiency_index"], 0.603, 0.001),
				"got %.4f" % m["proficiency_index"]
			)
			_check(
				"Published decision for Game 6 = Medium",
				AdaptiveDifficulty.evaluate_decision_tree(m)["new_difficulty"] == "Medium",
				AdaptiveDifficulty.evaluate_decision_tree(m)["new_difficulty"]
			)

	# Φ must be a pure function of player performance. If CP were normalized by
	# the active time limit, Φ would depend on the tier the player happens to be
	# in — and since Φ *chooses* that tier, the algorithm would be feeding back
	# into itself. Same input, same Φ, from every starting tier.
	_check(
		"Φ independent of starting tier (no self-referential feedback)",
		_approx(phi_by_tier["Easy"], phi_by_tier["Medium"], 0.0001)
			and _approx(phi_by_tier["Easy"], phi_by_tier["Hard"], 0.0001),
		"Easy=%.4f Medium=%.4f Hard=%.4f" % [
			phi_by_tier["Easy"], phi_by_tier["Medium"], phi_by_tier["Hard"]
		]
	)

	# Adaptation latency must be a REAL measurement. The paper reports an
	# adaptation latency figure as evidence; returning the target constant in its
	# place would make that figure fabricated rather than observed.
	var lat: Dictionary = AdaptiveDifficulty.get_latency_report()
	_check(
		"Adaptation latency was actually measured",
		lat["measured"] == true,
		"samples=%s" % str(lat["samples"])
	)
	_check(
		"Reported latency is a measurement, not the declared target",
		absf(float(lat["avg_ms"]) - float(lat["target_ms"])) > 0.0001,
		"avg=%.4f target=%.1f" % [lat["avg_ms"], lat["target_ms"]]
	)
	_check(
		"Measured adaptation latency under the paper's 100 ms budget",
		float(lat["avg_ms"]) >= 0.0 and float(lat["avg_ms"]) < 100.0,
		"avg=%.4fms max=%.4fms over %s samples" % [
			lat["avg_ms"], lat["max_ms"], str(lat["samples"])
		]
	)


# ═══════════════════════════════════════════════════════════════════
# 8. RAW GAME SCORE
# ═══════════════════════════════════════════════════════════════════
## S = w_a·A + w_s·(1 − T_r/T_max) − w_e·E, with w = [0.6, 0.3, 0.1].
##
## The property that actually matters is MONOTONICITY IN E: committing more
## errors must never raise the score. That is not automatic — the previous
## implementation returned E = (1 − accuracy) whenever mistakes == 0, so at
## accuracy 0.40 a flawless run was penalized E=0.60 while a run with one
## mistake was penalized only E=0.167. A clean run scored LOWER than a
## sloppier one, inverting the formula's intent.
func _verify_raw_game_score() -> void:
	print("")
	print("── 8. Raw Game Score ──")

	AdaptiveDifficulty.reset()
	AdaptiveDifficulty.current_difficulty = "Medium"  # T_max = 15 s

	var clean: float = AdaptiveDifficulty.calculate_raw_game_score(0.40, 7000, 0)
	var one: float = AdaptiveDifficulty.calculate_raw_game_score(0.40, 7000, 1)
	var five: float = AdaptiveDifficulty.calculate_raw_game_score(0.40, 7000, 5)

	_check(
		"Zero errors scores ≥ one error (monotonic in E)",
		clean >= one,
		"clean=%.4f one_error=%.4f" % [clean, one]
	)
	_check(
		"One error scores ≥ five errors (monotonic in E)",
		one >= five,
		"one=%.4f five=%.4f" % [one, five]
	)

	# Ceiling is w_a + w_s = 0.9, not 1.0: the remaining 0.1 belongs to the
	# error term and is only ever subtracted.
	_check(
		"Perfect run scores w_a + w_s = 0.9",
		_approx(AdaptiveDifficulty.calculate_raw_game_score(1.0, 0, 0), 0.9, 0.001),
		"got %.4f" % AdaptiveDifficulty.calculate_raw_game_score(1.0, 0, 0)
	)
	_check(
		"Total failure scores 0.0",
		_approx(AdaptiveDifficulty.calculate_raw_game_score(0.0, 15000, 10), 0.0, 0.001),
		"got %.4f" % AdaptiveDifficulty.calculate_raw_game_score(0.0, 15000, 10)
	)
	_check(
		"S rises with accuracy",
		AdaptiveDifficulty.calculate_raw_game_score(0.9, 7000, 0)
			> AdaptiveDifficulty.calculate_raw_game_score(0.5, 7000, 0)
	)
	_check(
		"S rises with speed",
		AdaptiveDifficulty.calculate_raw_game_score(0.7, 3000, 0)
			> AdaptiveDifficulty.calculate_raw_game_score(0.7, 12000, 0)
	)

	# Sweep the whole input domain, including out-of-range reaction times and
	# absurd error counts, so S can never escape [0,1] and corrupt scoring.
	var out_of_range: int = 0
	for a in [0.0, 0.25, 0.5, 0.75, 1.0]:
		for t in [0, 3000, 7500, 15000, 30000]:
			for e in [0, 1, 3, 10, 50]:
				var s: float = AdaptiveDifficulty.calculate_raw_game_score(a, t, e)
				if s < 0.0 or s > 1.0:
					out_of_range += 1
	_check(
		"S stays in [0,1] across 125 input combinations",
		out_of_range == 0,
		"%d combinations escaped the range" % out_of_range
	)


# ═══════════════════════════════════════════════════════════════════
# 9. INTEGER-ONLY SYNC PAYLOAD
# ═══════════════════════════════════════════════════════════════════
## The paper's bandwidth claim rests on the counter being a small array of
## plain integers, bit-packed rather than JSON-serialized. Two things can
## quietly break that: a float or string sneaking into the counter, and the
## payload growing past the documented per-packet ceiling.
func _verify_sync_payload() -> void:
	print("")
	print("── 9. Integer-Only Sync Payload ──")

	GCounter.reset()
	GCounter.initialize([1, 2])
	GCounter.increment(1, 7)
	GCounter.increment(2, 3)

	var non_int: int = 0
	for pid in GCounter.counter:
		if typeof(GCounter.counter[pid]) != TYPE_INT:
			non_int += 1
	_check(
		"Every counter value is an integer (no floats, no strings)",
		non_int == 0,
		"%d non-integer values in %s" % [non_int, str(GCounter.counter)]
	)

	# Bit-pack exactly as the network layer does: one signed 32-bit int per peer.
	var packed := PackedByteArray()
	packed.resize(GCounter.counter.size() * 4)
	var idx: int = 0
	for pid in GCounter.counter:
		packed.encode_s32(idx * 4, int(GCounter.counter[pid]))
		idx += 1

	var json_bytes: int = JSON.stringify(GCounter.counter).to_utf8_buffer().size()

	_check(
		"Packed payload is 4 bytes per peer (8 bytes for 2 players)",
		packed.size() == 8,
		"got %d bytes" % packed.size()
	)
	_check(
		"Payload under the paper's 1 KB per-packet ceiling",
		packed.size() < 1024,
		"got %d bytes" % packed.size()
	)
	_check(
		"Packed payload smaller than the JSON equivalent",
		packed.size() < json_bytes,
		"packed=%dB json=%dB (%.1f%% smaller)" % [
			packed.size(), json_bytes,
			100.0 * (1.0 - float(packed.size()) / float(json_bytes))
		]
	)

	# Round-trip: unpacking must reproduce the counter exactly, or a "converged"
	# replica is only converged in appearance.
	var unpacked: Dictionary = {}
	var peers: Array = GCounter.counter.keys()
	for i in range(peers.size()):
		unpacked[peers[i]] = packed.decode_s32(i * 4)
	_check(
		"Packed payload round-trips to the identical counter",
		unpacked == GCounter.counter,
		"unpacked=%s original=%s" % [str(unpacked), str(GCounter.counter)]
	)


# ═══════════════════════════════════════════════════════════════════
# 10. PUBLISHED OUTPUT SPECIFICATION
# ═══════════════════════════════════════════════════════════════════
## The paper's Output Specification table declares enumerated sets, not ranges:
##   difficulty_level ∈ {EASY, MEDIUM, HARD}
##   speed_multiplier ∈ {0.7, 1.0, 1.5}
##   time_limit       ∈ {10, 15, 20}
##   visual_guidance  ∈ {TRUE, FALSE}
##
## The supplementary progression ramp scales the applied values past those sets,
## which is fine for gameplay but must never be mistaken for the declared outputs.
## These checks pin both halves: the declared accessor reproduces the table
## exactly, and the applied path stays bounded rather than escalating forever.
func _verify_output_specification() -> void:
	print("")
	print("── 10. Published output specification ──────────────────────")

	var declared := {
		"Easy": {"speed_multiplier": 0.7, "time_limit": 20, "visual_guidance": true},
		"Medium": {"speed_multiplier": 1.0, "time_limit": 15, "visual_guidance": false},
		"Hard": {"speed_multiplier": 1.5, "time_limit": 10, "visual_guidance": false},
	}

	# Force progression to its ceiling so the declared accessor is proven to be
	# unaffected by it — that is the whole point of having a separate accessor.
	AdaptiveDifficulty.progressive_level = AdaptiveDifficulty.MAX_PROGRESSIVE_LEVEL

	for tier in declared:
		AdaptiveDifficulty.current_difficulty = tier
		var paper: Dictionary = AdaptiveDifficulty.get_paper_difficulty_settings()
		var want: Dictionary = declared[tier]
		_check(
			"%s declares speed_multiplier = %s" % [tier, want["speed_multiplier"]],
			_approx(float(paper["speed_multiplier"]), float(want["speed_multiplier"])),
			"got %s" % str(paper["speed_multiplier"])
		)
		_check(
			"%s declares time_limit = %ds" % [tier, want["time_limit"]],
			int(paper["time_limit"]) == int(want["time_limit"]),
			"got %s" % str(paper["time_limit"])
		)
		_check(
			"%s declares visual_guidance = %s" % [tier, want["visual_guidance"]],
			bool(paper["visual_guidance"]) == bool(want["visual_guidance"]),
			"got %s" % str(paper["visual_guidance"])
		)

	# Applied path at the ceiling: must stay winnable and bounded.
	AdaptiveDifficulty.current_difficulty = "Hard"
	var applied: Dictionary = AdaptiveDifficulty.get_difficulty_settings()
	_check(
		"Applied time_limit stays above the 3s floor at max progression",
		int(applied["time_limit"]) > 3,
		"got %ds" % int(applied["time_limit"])
	)
	_check(
		"Applied item_count bounded at max progression (<= 16)",
		int(applied["item_count"]) <= 16,
		"got %d" % int(applied["item_count"])
	)
	_check(
		"Applied speed_multiplier bounded at max progression (<= 2.5x)",
		float(applied["speed_multiplier"]) <= 2.5,
		"got %.2fx" % float(applied["speed_multiplier"])
	)

	# The ramp must never climb past its ceiling, however many wins are fed in.
	AdaptiveDifficulty.progressive_level = AdaptiveDifficulty.MAX_PROGRESSIVE_LEVEL
	AdaptiveDifficulty.consecutive_successes = 0
	for _i in range(30):
		AdaptiveDifficulty.add_performance(1.0, 500, 0, "SpecProbe")
	_check(
		"progressive_level never exceeds MAX_PROGRESSIVE_LEVEL",
		AdaptiveDifficulty.progressive_level <= AdaptiveDifficulty.MAX_PROGRESSIVE_LEVEL,
		"reached %d, cap %d" % [
			AdaptiveDifficulty.progressive_level,
			AdaptiveDifficulty.MAX_PROGRESSIVE_LEVEL
		]
	)

	AdaptiveDifficulty.reset()


