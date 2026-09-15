extends Node

## ── G-COUNTER WIRE-PAYLOAD MEASUREMENT (Multiplayer, headless) ─────────────
##
## Answers "what does the CRDT actually cost on the wire?" with measured bytes,
## not estimates. Two serialization paths exist in the shipping multiplayer code:
##
##   1. NetworkManager._merge_counter(peer_id: int, value: int) - the per-tap
##      increment RPC. Two integers, sent reliably.
##   2. GameManager._sync_game_state(counters: Dictionary, lives, diff_mult) -
##      the full-state resync the host pushes to a rejoining peer, carrying the
##      whole counter dictionary.
##
## Both are Godot RPCs; Godot serializes RPC arguments with its own binary
## encoding, which var_to_bytes() reproduces (same Variant encoder). The JSON
## comparison is the equivalent document a thesis reader would write by hand:
## {"p1_score": 10, "p2_score": 15}.
##
## Everything below is counted with .size() on the produced buffers.
##
## Run:  godot --headless --path . res://tools/MeasureGCounterPayload.tscn

func _ready() -> void:
	_run.call_deferred()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _json_bytes(v: Variant) -> int:
	return JSON.stringify(v).to_utf8_buffer().size()


func _godot_bytes(v: Variant) -> int:
	return var_to_bytes(v).size()


func _row(label: String, godot_b: int, json_b: int) -> void:
	var reduction := 0.0
	if json_b > 0:
		reduction = 100.0 * (1.0 - float(godot_b) / float(json_b))
	print("  %-58s %5d B  | JSON %5d B  | %5.1f%% smaller"
		% [label, godot_b, json_b, reduction])


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  G-COUNTER WIRE PAYLOAD vs JSON (measured bytes)")
	print("═══════════════════════════════════════════════════════════")

	# ── 1. The thesis's example document: two peers, small totals ──
	var thesis_counter := {1: 10, 2: 15}
	var thesis_json := {"p1_score": 10, "p2_score": 15}
	print("")
	print("  ── thesis example: {p1:10, p2:15} (small ENet ids 1 and 2) ──")
	_row("full dictionary, Godot binary (var_to_bytes)",
		_godot_bytes(thesis_counter), _json_bytes(thesis_json))
	# The increment RPC is not a dictionary at all: two integers on the wire.
	_row("increment RPC args (peer_id, value), Godot binary",
		_godot_bytes([1, 10]), _json_bytes({"peer_id": 1, "value": 10}))

	# ── 2. Same counters, realistic ENet ids (host 1, client 6+ digits) ──
	var big_counter := {1: 10, 245634567: 15}
	print("")
	print("  ── same scores, realistic long client peer id ──")
	_row("full dictionary, Godot binary",
		_godot_bytes(big_counter), _json_bytes(big_counter))

	# ── 3. The full resync payload the host pushes to a rejoining peer ──
	var resync_state := {
		"counters": {1: 340, 245634567: 297},
		"lives": 2,
		"difficulty_multiplier": 1.35,
	}
	var resync_rpc := [resync_state["counters"], resync_state["lives"],
		resync_state["difficulty_multiplier"]]
	print("")
	print("  ── mid-session resync (2 slots, lives, difficulty) ──")
	_row("_sync_game_state args, Godot binary",
		_godot_bytes(resync_rpc), _json_bytes(resync_state))

	# ── 4. A long session (thesis-scale) for the same comparison ──
	var long_state := {
		"counters": {1: 1520, 245634567: 1487},
		"lives": 0,
		"difficulty_multiplier": 1.35,
	}
	var long_rpc := [long_state["counters"], long_state["lives"],
		long_state["difficulty_multiplier"]]
	print("")
	print("  ── end-of-session resync (2 slots, ~3000 total points) ──")
	_row("_sync_game_state args, Godot binary",
		_godot_bytes(long_rpc), _json_bytes(long_state))

	# ── 5. A 90-dial reconnect hold, for the low-end budget ──
	# RECONNECT_RETRY_INTERVAL dials over RECONNECT_HOLD_SECONDS: the increment
	# RPC is the only recurring per-action payload, and it is 2 integers.
	print("")
	print("  ── recurrence ──")
	var merges := 40
	print("  40 increments (a busy round) = 40 × %d B RPC args = %d B total"
		% [_godot_bytes([1, 10]), 40 * _godot_bytes([1, 10])])
	print("  reconnect hold dials: %d × 1.5 s = %.0f s window, zero score payload"
		% [int(NetworkManager.RECONNECT_HOLD_SECONDS / NetworkManager.RECONNECT_RETRY_INTERVAL),
			NetworkManager.RECONNECT_HOLD_SECONDS])

	print("")
	print("═══════════════════════════════════════════════════════════")
	_tree().quit(0)
