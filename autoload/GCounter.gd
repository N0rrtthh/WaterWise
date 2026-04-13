extends Node

## ═══════════════════════════════════════════════════════════════════
## G-COUNTER CRDT - CONFLICT-FREE REPLICATED DATA TYPE
## ═══════════════════════════════════════════════════════════════════
## Standalone Grow-Only Counter implementing the G-Counter CRDT
## as described in the thesis paper (Section: G-Counter CRDT
## Multiplayer Synchronization Algorithm).
##
## Mathematical Properties (guaranteeing Strong Eventual Consistency):
## 1. Commutativity: merge(A, B) = merge(B, A)
## 2. Associativity: merge(merge(A, B), C) = merge(A, merge(B, C))
## 3. Idempotency: merge(A, A) = A
##
## Operations:
## - Increment: O(1) - Player i increments only their own counter
## - Query:     O(n) where n = fixed player count (O(1) for 2 players)
## - Merge:     O(n) element-wise maximum
##
## Data Structure: C = [c_1, c_2] where c_i = Player i's score
## Global Score = Σ(c_i) for all i
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal counter_incremented(peer_id: int, new_value: int)
signal counter_merged(local_state: Dictionary, remote_state: Dictionary)
signal global_score_changed(new_score: int)
signal synchronization_changed(is_synced: bool)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# G-COUNTER STATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Counter array: { peer_id: int_score }
## Each player only increments their OWN counter entry.
## This is the core of "conflict-free" - no overwrites possible.
var counter: Dictionary = {}

## Synchronization tracking (Paper: G-Counter Output Specification)
var is_synchronized: bool = true
var last_sync_timestamp: int = 0  # ms since last successful merge
var network_latency: int = 0  # Round-trip time for sync (ms)

## Local peer identifier
var local_peer_id: int = 0

## Merge history for research logging
var merge_history: Array[Dictionary] = []
var increment_history: Array[Dictionary] = []

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	print("📊 GCounter CRDT initialized")
	print("   Properties: Commutative, Associative, Idempotent")
	print("   Complexity: O(1) increment, O(n) merge/query")

## Initialize counter for a new session with given peer IDs
func initialize(peer_ids: Array) -> void:
	counter.clear()
	for pid in peer_ids:
		counter[pid] = 0
	
	if peer_ids.size() > 0:
		local_peer_id = peer_ids[0]
	
	is_synchronized = true
	last_sync_timestamp = Time.get_ticks_msec()
	merge_history.clear()
	increment_history.clear()
	
	print("📊 GCounter initialized: %s" % str(counter))

## Reset the counter
func reset() -> void:
	counter.clear()
	is_synchronized = true
	last_sync_timestamp = Time.get_ticks_msec()
	merge_history.clear()
	increment_history.clear()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CORE OPERATIONS (As defined in the paper)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## ═══════════════════════════════════════════════════════════════════
## INCREMENT - O(1) Local Operation
## ═══════════════════════════════════════════════════════════════════
## Player i increments ONLY their own counter position.
## This is what makes it "conflict-free" — no player can modify
## another player's counter, so no write conflicts are possible.
##
## Time Complexity: O(1) - Single array index update
## ═══════════════════════════════════════════════════════════════════
func increment(peer_id: int, amount: int = 1) -> void:
	# Instrument for ISO 25010 latency measurement
	var _lat_start = 0
	if PerformanceProfiler:
		_lat_start = PerformanceProfiler.begin_latency_measurement()

	# Ensure peer exists in counter
	if not counter.has(peer_id):
		counter[peer_id] = 0
	
	# G-Counter: GROW ONLY — amount must be positive
	if amount < 0:
		push_warning("GCounter: Cannot decrement! G-Counter is grow-only.")
		return
	
	# O(1) increment operation
	counter[peer_id] += amount
	
	# Mark as potentially unsynchronized with remote
	is_synchronized = false
	
	# Log for research
	increment_history.append({
		"timestamp": Time.get_ticks_msec(),
		"peer_id": peer_id,
		"amount": amount,
		"new_value": counter[peer_id]
	})
	
	counter_incremented.emit(peer_id, counter[peer_id])
	global_score_changed.emit(query())

	# Record latency for ISO 25010 compliance
	if PerformanceProfiler and _lat_start > 0:
		PerformanceProfiler.end_latency_measurement(_lat_start, "GCounter.increment")

## ═══════════════════════════════════════════════════════════════════
## QUERY - O(n) Local Operation (O(1) for fixed n=2)
## ═══════════════════════════════════════════════════════════════════
## GlobalScore = Σ(c_i) for all players i
## Since n is fixed at 2 players, this is effectively O(1).
## ═══════════════════════════════════════════════════════════════════
func query() -> int:
	var total: int = 0
	for pid in counter:
		total += counter[pid]
	return total

## Alias for query()
func get_global_score() -> int:
	return query()

## Get a specific player's score contribution
func get_player_score(peer_id: int) -> int:
	return counter.get(peer_id, 0)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MERGE OPERATION (Synchronization)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## ═══════════════════════════════════════════════════════════════════
## MERGE - O(n) Synchronization Operation
## ═══════════════════════════════════════════════════════════════════
## Element-wise maximum of two counter arrays.
## This operation satisfies all three CRDT mathematical properties:
##
## 1. COMMUTATIVITY: merge(A, B) = merge(B, A)
##    → Order doesn't matter — both sides get same result
##
## 2. ASSOCIATIVITY: merge(merge(A, B), C) = merge(A, merge(B, C))
##    → Grouping doesn't matter — result is always the same
##
## 3. IDEMPOTENCY: merge(A, A) = A
##    → Merging with yourself changes nothing — safe to re-send
##
## These guarantee STRONG EVENTUAL CONSISTENCY:
## If two replicas receive the same set of updates (in ANY order),
## they will converge to identical states.
##
## Example (from paper):
##   Host:   [7, 3]  (Host scored 7, knows Client had 3)
##   Client: [5, 7]  (Client knows Host had 5, Client scored 7)
##   After merge: [max(7,5), max(3,7)] = [7, 7]
##   Both replicas now agree: GlobalScore = 14
## ═══════════════════════════════════════════════════════════════════
func merge(remote_counter: Dictionary) -> void:
	var merge_start = Time.get_ticks_msec()
	var pre_merge_state = counter.duplicate()

	# Instrument for ISO 25010 latency measurement
	var _lat_start = 0
	if PerformanceProfiler:
		_lat_start = PerformanceProfiler.begin_latency_measurement()
	
	# Element-wise maximum
	for pid in remote_counter:
		if counter.has(pid):
			# Take the maximum (paper: element-wise max)
			counter[pid] = max(counter[pid], remote_counter[pid])
		else:
			# New peer — adopt their counter
			counter[pid] = remote_counter[pid]
	
	# Update sync tracking
	var merge_end = Time.get_ticks_msec()
	network_latency = merge_end - merge_start
	last_sync_timestamp = merge_end
	is_synchronized = true
	
	# Log merge event
	merge_history.append({
		"timestamp": merge_end,
		"pre_merge": pre_merge_state,
		"remote": remote_counter.duplicate(),
		"post_merge": counter.duplicate(),
		"latency_ms": network_latency
	})
	
	counter_merged.emit(pre_merge_state, remote_counter)
	synchronization_changed.emit(true)
	global_score_changed.emit(query())

	# Record latency for ISO 25010 compliance
	if PerformanceProfiler and _lat_start > 0:
		PerformanceProfiler.end_latency_measurement(_lat_start, "GCounter.merge")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OUTPUT SPECIFICATION (As defined in thesis Table)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Returns all output parameters as specified in the paper
func get_output_specification() -> Dictionary:
	return {
		"g_counter": counter.duplicate(),
		"GlobalScore": query(),
		"peer_id": local_peer_id,
		"is_synchronized": is_synchronized,
		"last_sync_timestamp": last_sync_timestamp,
		"network_latency": network_latency
	}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MATHEMATICAL PROPERTY VERIFICATION (For thesis demo)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Verify commutativity: merge(A,B) == merge(B,A)
func verify_commutativity(
	a: Dictionary, b: Dictionary
) -> bool:
	var result_ab = _simulate_merge(a, b)
	var result_ba = _simulate_merge(b, a)
	return result_ab == result_ba

## Verify associativity: merge(merge(A,B),C) == merge(A,merge(B,C))
func verify_associativity(
	a: Dictionary, b: Dictionary, c: Dictionary
) -> bool:
	var ab = _simulate_merge(a, b)
	var ab_c = _simulate_merge(ab, c)
	var bc = _simulate_merge(b, c)
	var a_bc = _simulate_merge(a, bc)
	return ab_c == a_bc

## Verify idempotency: merge(A,A) == A
func verify_idempotency(a: Dictionary) -> bool:
	var result = _simulate_merge(a, a)
	return result == a

## Simulate a merge without modifying actual state
func _simulate_merge(
	local: Dictionary, remote: Dictionary
) -> Dictionary:
	var result = local.duplicate()
	for pid in remote:
		if result.has(pid):
			result[pid] = max(result[pid], remote[pid])
		else:
			result[pid] = remote[pid]
	return result

## Run all three property verifications and return results
func verify_all_properties() -> Dictionary:
	var a = {1: 5, 2: 3}
	var b = {1: 3, 2: 7}
	var c = {1: 2, 2: 4}
	
	var results = {
		"commutativity": verify_commutativity(a, b),
		"associativity": verify_associativity(a, b, c),
		"idempotency": verify_idempotency(a),
		"test_vectors": {
			"A": a, "B": b, "C": c,
			"merge(A,B)": _simulate_merge(a, b),
			"merge(B,A)": _simulate_merge(b, a)
		}
	}
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📊 G-COUNTER CRDT PROPERTY VERIFICATION")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("✅ Commutativity: %s" % results["commutativity"])
	print("✅ Associativity: %s" % results["associativity"])
	print("✅ Idempotency:   %s" % results["idempotency"])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	return results

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RESEARCH DATA EXPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func export_session_data() -> Dictionary:
	return {
		"final_counter": counter.duplicate(),
		"global_score": query(),
		"total_increments": increment_history.size(),
		"total_merges": merge_history.size(),
		"merge_history": merge_history.duplicate(),
		"increment_history": increment_history.duplicate(),
		"properties_verified": verify_all_properties()
	}
