extends Node

## ═══════════════════════════════════════════════════════════════════
## NETWORK FAULT SIMULATOR - THESIS OBJECTIVE 3 VALIDATION
## ═══════════════════════════════════════════════════════════════════
## Simulates network degradation to validate G-Counter CRDT resilience.
##
## From thesis paper (Performance Evaluation):
## - 20% UDP packet drop baseline
## - 100ms–500ms random latency jitter
## - Convergence time < 200ms despite packet loss
## - Sweep from 10% to 90% packet loss
##
## This module sits between two simulated replicas and introduces:
## 1. Configurable packet drop rate (0%–100%)
## 2. Random latency jitter (min–max ms)
## 3. Convergence time measurement (increment → both agree)
## 4. Automated sweep test producing the thesis data table
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal packet_sent(from_replica: String, data: Dictionary)
signal packet_dropped(from_replica: String, loss_rate: float)
signal packet_delivered(from_replica: String, latency_ms: float)
signal convergence_measured(loss_rate: float, convergence_ms: float, converged: bool)
signal sweep_completed(results: Array)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION (Paper: Network Fault Injection)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Packet loss rate: 0.0 = perfect, 1.0 = drop everything
var packet_loss_rate: float = 0.20  # Paper: 20% baseline

## Latency jitter range (milliseconds)
var latency_min_ms: float = 100.0   # Paper: 100ms
var latency_max_ms: float = 500.0   # Paper: 500ms

## Convergence target (Paper: < 200ms)
const CONVERGENCE_TARGET_MS: float = 200.0

## Sweep test configuration (Paper: 10% to 90%)
const SWEEP_LOSS_RATES: Array = [0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90]
const SWEEP_TRIALS_PER_RATE: int = 20  # Repeat each rate for statistical significance

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIMULATION STATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Two simulated replicas (mirrors what GCounterDemo does)
var host_counter: Dictionary = {1: 0, 2: 0}
var client_counter: Dictionary = {1: 0, 2: 0}

## Delivery queue — packets "in flight" with scheduled delivery times
var delivery_queue: Array[Dictionary] = []

## Statistics
var total_packets_sent: int = 0
var total_packets_dropped: int = 0
var total_packets_delivered: int = 0
var convergence_times: Array[float] = []

## Current convergence measurement
var _convergence_start_usec: int = 0
var _waiting_for_convergence: bool = false

## Sweep test state
var sweep_results: Array[Dictionary] = []
var _sweep_running: bool = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	# This module is an OFFLINE simulator: it operates purely on its own
	# host_counter/client_counter pair and never touches NetworkManager or the
	# live GCounter. The rates below describe the fault conditions a sweep will
	# inject when one is explicitly started — real multiplayer traffic is never
	# dropped or delayed by this node.
	print("🌐 NetworkFaultSimulator ready (idle — no effect on live multiplayer)")
	print("   Sweep profile when run: %.0f%% loss, %.0f–%.0fms jitter" % [
		packet_loss_rate * 100, latency_min_ms, latency_max_ms])

	# Event-driven, not polled. As an autoload this node outlives every scene, so
	# a _process() that runs unconditionally would call into the delivery queue
	# ~60 times a second for the entire session — allocating a scratch array each
	# time — while the queue is empty in all but the few seconds a sweep is
	# actually running. Processing is switched on only while packets are in
	# flight (see send_sync_packet / _process_delivery_queue).
	set_process(false)

func _process(_delta: float) -> void:
	_process_delivery_queue()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CORE: SEND PACKET THROUGH SIMULATED NETWORK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Simulate sending a replica's state through a lossy, jittery network.
## Returns true if the packet was queued for delivery, false if dropped.
func send_sync_packet(from: String, counter_state: Dictionary) -> bool:
	total_packets_sent += 1
	packet_sent.emit(from, counter_state)

	# Roll for packet loss
	if randf() < packet_loss_rate:
		total_packets_dropped += 1
		packet_dropped.emit(from, packet_loss_rate)
		return false

	# Packet survives — add random latency jitter
	var jitter_ms = randf_range(latency_min_ms, latency_max_ms)
	var deliver_at_usec = Time.get_ticks_usec() + int(jitter_ms * 1000.0)

	delivery_queue.append({
		"from": from,
		"counter": counter_state.duplicate(),
		"deliver_at_usec": deliver_at_usec,
		"jitter_ms": jitter_ms
	})

	# A packet is now in flight, so the queue needs ticking until it drains.
	set_process(true)

	return true

## Process the delivery queue — deliver packets whose jitter time has elapsed.
##
## Packets are removed from the queue BEFORE being delivered. _deliver_packet
## emits packet_delivered and convergence_measured, and a listener is free to
## call send_sync_packet or reset_stats from those handlers — which would
## reallocate delivery_queue underneath us. Collecting indices during the walk
## and deleting afterwards (the previous approach) would then delete the wrong
## entries or index out of bounds.
func _process_delivery_queue() -> void:
	var now_usec := Time.get_ticks_usec()
	var due: Array[Dictionary] = []
	var still_in_flight: Array[Dictionary] = []

	for pkt in delivery_queue:
		if now_usec >= int(pkt["deliver_at_usec"]):
			due.append(pkt)
		else:
			still_in_flight.append(pkt)

	if due.is_empty():
		# Nothing due. Stop ticking once the queue is completely empty, otherwise
		# keep processing until the remaining jitter timers expire.
		if delivery_queue.is_empty():
			set_process(false)
		return

	delivery_queue = still_in_flight

	for pkt in due:
		_deliver_packet(pkt)

	if delivery_queue.is_empty():
		set_process(false)

## Deliver a packet — merge into the target replica
func _deliver_packet(pkt: Dictionary) -> void:
	total_packets_delivered += 1
	var remote_state = pkt["counter"]

	if pkt["from"] == "host":
		# Deliver to client — element-wise max
		for pid in remote_state:
			if client_counter.has(pid):
				client_counter[pid] = max(client_counter[pid], remote_state[pid])
			else:
				client_counter[pid] = remote_state[pid]
	elif pkt["from"] == "client":
		# Deliver to host — element-wise max
		for pid in remote_state:
			if host_counter.has(pid):
				host_counter[pid] = max(host_counter[pid], remote_state[pid])
			else:
				host_counter[pid] = remote_state[pid]

	packet_delivered.emit(pkt["from"], pkt["jitter_ms"])

	# Check convergence
	if _waiting_for_convergence and host_counter == client_counter:
		var elapsed_usec = Time.get_ticks_usec() - _convergence_start_usec
		var elapsed_ms = float(elapsed_usec) / 1000.0
		convergence_times.append(elapsed_ms)
		_waiting_for_convergence = false
		var converged = elapsed_ms <= CONVERGENCE_TARGET_MS
		convergence_measured.emit(packet_loss_rate, elapsed_ms, converged)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SINGLE CONVERGENCE TEST
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Run a single divergence→convergence scenario:
## 1. Both start at [0,0]
## 2. Host increments P1 by host_amount
## 3. Client increments P2 by client_amount
## 4. Both send sync packets through the lossy network
## 5. Measure time until both replicas agree
##
## Uses retry-based sync: keeps re-sending until delivered
## (mimicking real UDP with application-level retransmits)
func run_convergence_test(
	host_amount: int = 5,
	client_amount: int = 3,
	max_retries: int = 50
) -> void:
	# Reset replicas
	host_counter = {1: 0, 2: 0}
	client_counter = {1: 0, 2: 0}
	delivery_queue.clear()

	# Diverge: each side increments locally
	host_counter[1] += host_amount
	client_counter[2] += client_amount

	# Start convergence timer
	_convergence_start_usec = Time.get_ticks_usec()
	_waiting_for_convergence = true

	# Attempt to sync — retry until packet gets through
	var host_sent = false
	var client_sent = false
	for i in range(max_retries):
		if not host_sent:
			host_sent = send_sync_packet("host", host_counter)
		if not client_sent:
			client_sent = send_sync_packet("client", client_counter)
		if host_sent and client_sent:
			break
		# Small delay between retries (simulates retransmit timer)
		await get_tree().create_timer(0.005).timeout

## Synchronous version for sweep tests — waits for convergence or timeout
func _run_single_trial(
	host_amount: int, client_amount: int, timeout_ms: float = 2000.0
) -> Dictionary:
	# Reset
	host_counter = {1: 0, 2: 0}
	client_counter = {1: 0, 2: 0}
	delivery_queue.clear()
	_waiting_for_convergence = false

	# Diverge
	host_counter[1] += host_amount
	client_counter[2] += client_amount

	var start_usec = Time.get_ticks_usec()
	_convergence_start_usec = start_usec
	_waiting_for_convergence = true

	# Retry loop: keep sending until both get through, or timeout
	var host_delivered = false
	var client_delivered = false
	var retries = 0
	var max_retries = 100

	while _waiting_for_convergence:
		var elapsed_ms = float(Time.get_ticks_usec() - start_usec) / 1000.0
		if elapsed_ms > timeout_ms:
			_waiting_for_convergence = false
			return {
				"converged": false,
				"convergence_ms": elapsed_ms,
				"retries": retries,
				"packets_sent": total_packets_sent,
				"packets_dropped": total_packets_dropped
			}

		# Retry sending if not yet delivered
		if retries < max_retries:
			if not host_delivered:
				host_delivered = send_sync_packet("host", host_counter)
			if not client_delivered:
				client_delivered = send_sync_packet("client", client_counter)
			retries += 1

		# Let the delivery queue process
		await get_tree().create_timer(0.01).timeout

	# Convergence achieved
	var total_ms = float(Time.get_ticks_usec() - start_usec) / 1000.0
	return {
		"converged": true,
		"convergence_ms": total_ms,
		"retries": retries,
		"packets_sent": total_packets_sent,
		"packets_dropped": total_packets_dropped
	}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTOMATED SWEEP TEST (Paper: 10% to 90% packet loss)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Runs the full packet loss sweep described in the thesis.
## For each loss rate (10%–90%), runs SWEEP_TRIALS_PER_RATE trials
## and records average/min/max convergence time.
## Emits sweep_completed with the full results table.
func run_packet_loss_sweep(host_amount: int = 5, client_amount: int = 3) -> void:
	_sweep_running = true
	sweep_results.clear()

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🌐 NETWORK FAULT SWEEP TEST — G-COUNTER CRDT")
	print("   Rates: %s" % str(SWEEP_LOSS_RATES))
	print("   Trials per rate: %d" % SWEEP_TRIALS_PER_RATE)
	print("   Convergence target: < %.0fms" % CONVERGENCE_TARGET_MS)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	for rate in SWEEP_LOSS_RATES:
		packet_loss_rate = rate
		var trial_times: Array[float] = []
		var converge_count: int = 0
		var total_retries: int = 0

		# Reset stats for this rate
		total_packets_sent = 0
		total_packets_dropped = 0
		total_packets_delivered = 0

		for trial in range(SWEEP_TRIALS_PER_RATE):
			var result = await _run_single_trial(host_amount, client_amount)
			if result["converged"]:
				trial_times.append(result["convergence_ms"])
				converge_count += 1
			total_retries += result["retries"]

		# Calculate statistics
		var avg_ms = 0.0
		var min_ms = 99999.0
		var max_ms = 0.0
		if trial_times.size() > 0:
			for t in trial_times:
				avg_ms += t
				min_ms = min(min_ms, t)
				max_ms = max(max_ms, t)
			avg_ms /= trial_times.size()
		else:
			min_ms = 0.0

		var all_converged: bool = converge_count == SWEEP_TRIALS_PER_RATE
		var rate_result = {
			"loss_rate_pct": rate * 100.0,
			"trials": SWEEP_TRIALS_PER_RATE,
			"converged": converge_count,
			"convergence_rate_pct": float(converge_count) / SWEEP_TRIALS_PER_RATE * 100.0,
			"avg_convergence_ms": avg_ms,
			"min_convergence_ms": min_ms,
			"max_convergence_ms": max_ms,
			"meets_target": avg_ms <= CONVERGENCE_TARGET_MS and all_converged,
			"total_packets_sent": total_packets_sent,
			"total_packets_dropped": total_packets_dropped,
			"avg_retries": float(total_retries) / SWEEP_TRIALS_PER_RATE
		}
		sweep_results.append(rate_result)

		var status = "✅ PASS" if rate_result["meets_target"] else "⚠️"
		print("  %s %.0f%% loss | conv: %d/%d | avg: %.1fms | retries: %.1f %s" % [
			status, rate * 100.0, converge_count, SWEEP_TRIALS_PER_RATE,
			avg_ms, rate_result["avg_retries"], status])

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	_sweep_running = false
	sweep_completed.emit(sweep_results)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# REPORTING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_sweep_summary() -> Dictionary:
	return {
		"sweep_loss_rates": SWEEP_LOSS_RATES,
		"trials_per_rate": SWEEP_TRIALS_PER_RATE,
		"convergence_target_ms": CONVERGENCE_TARGET_MS,
		"results": sweep_results,
		"latency_range_ms": [latency_min_ms, latency_max_ms]
	}

func reset_stats() -> void:
	host_counter = {1: 0, 2: 0}
	client_counter = {1: 0, 2: 0}
	delivery_queue.clear()
	total_packets_sent = 0
	total_packets_dropped = 0
	total_packets_delivered = 0
	convergence_times.clear()
	sweep_results.clear()
	_waiting_for_convergence = false
	_sweep_running = false
