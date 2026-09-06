extends Node

## Two-peer verification of the co-op pause authority.
##
## Written for the Definition-of-Done row on session_2026-09-05T00-27-36.json:
##   "game_log should show exactly one 'Game paused' per pause action and one
##    'Game resumed' per resume action - no repeating pause<->resume pairs firing every
##    100-300 ms, no duplicate consecutive 'Game resumed' entries"
##
## That row is stated in terms of SessionLogger's game_log, so this harness counts the
## entries SessionLogger actually recorded rather than inspecting NetworkManager's
## internals - the same evidence a fresh on-device export would carry.
##
## Two processes, like tools/VerifyMPPauseClock.tscn:
##   godot --path . res://tools/VerifyPauseAuthority.tscn -- host
##   godot --path . res://tools/VerifyPauseAuthority.tscn -- client
##
## The host runs the assertions; the client exists to make the RPCs real. A single
## process cannot exercise this at all - the bug was an echo between two peers.

const PORT: int = 7787
const HOST_IP: String = "127.0.0.1"

var role: String = "host"
var results: Array = []


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _ready() -> void:
	_boot.call_deferred()


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _boot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "client":
			role = "client"
		elif arg == "host":
			role = "host"

	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  PAUSE AUTHORITY HARNESS — role: %s  port: %d" % [role, PORT])
	print("═══════════════════════════════════════════════════════════")

	if role == "host":
		if not GameManager.host_game(PORT):
			_check("host_game() bound port %d" % PORT, false)
			_finish()
			return
	else:
		if not GameManager.join_game(HOST_IP, PORT):
			_check("join_game() succeeded", false)
			_finish()
			return

	# Eventual, not clock-anchored: two OS processes do not agree on a frame boundary.
	var waited := 0.0
	while NetworkManager.players.size() < 2 and waited < 20.0:
		await _frames(6)
		waited += 0.1
	if NetworkManager.players.size() < 2:
		_check("peer connected within 20s", false, "players=%d" % NetworkManager.players.size())
		_finish()
		return

	if role == "client":
		# Keep the process alive so the host's RPCs have somewhere to land, then exit.
		await _frames(600)
		_tree().quit(0)
		return

	await _run_host_checks()
	_finish()


func _run_host_checks() -> void:
	_check("peer connected", true)

	# ── 1. A pause request produces exactly one transition ──────────────────────
	var before := _count_log_entries()
	NetworkManager.request_pause()
	await _frames(20)
	var after := _count_log_entries()
	_check(
		"one pause request -> one 'Game paused'",
		after["paused"] - before["paused"] == 1,
		"delta=%d" % (after["paused"] - before["paused"])
	)
	_check("tree is actually paused", _tree().paused)
	_check("NetworkManager.is_paused() agrees", NetworkManager.is_paused())
	_check("the pause reads as deliberate", NetworkManager.is_pause_deliberate())

	# ── 2. Repeats are dropped, not echoed ─────────────────────────────────────
	before = _count_log_entries()
	for _i in range(10):
		NetworkManager.request_pause()
		await _frames(2)
	after = _count_log_entries()
	_check(
		"10 further pause requests -> 0 extra transitions",
		after["paused"] - before["paused"] == 0,
		"delta=%d" % (after["paused"] - before["paused"])
	)

	# ── 3. Autoplay does not lift a deliberate pause ───────────────────────────
	# The exact call AutoPlayManager._process() makes while the tree is frozen. Before
	# the fix it ran once per frame and each call reached request_resume().
	before = _count_log_entries()
	var apm := get_node_or_null("/root/AutoPlayManager")
	var apm_ok := apm != null and apm.has_method("_try_resume_from_pause")
	if apm_ok:
		var lifted := false
		for _i in range(15):
			if apm._try_resume_from_pause():
				lifted = true
			await _frames(2)
		after = _count_log_entries()
		_check(
			"autoplay leaves a deliberate pause alone",
			not lifted and after["resumed"] - before["resumed"] == 0,
			"lifted=%s resumed_delta=%d" % [str(lifted), after["resumed"] - before["resumed"]]
		)
		_check("still paused after autoplay's attempts", _tree().paused)
	else:
		_check("AutoPlayManager reachable", false, "no _try_resume_from_pause")

	# ── 4. An explicit resume produces exactly one transition ──────────────────
	before = _count_log_entries()
	NetworkManager.request_resume()
	await _frames(20)
	after = _count_log_entries()
	_check(
		"one resume request -> one 'Game resumed'",
		after["resumed"] - before["resumed"] == 1,
		"delta=%d" % (after["resumed"] - before["resumed"])
	)
	_check("tree is running again", not _tree().paused)

	# ── 5. Resuming when not paused is a no-op ─────────────────────────────────
	before = _count_log_entries()
	for _i in range(10):
		NetworkManager.request_resume()
		await _frames(2)
	after = _count_log_entries()
	_check(
		"10 resume requests while running -> 0 transitions",
		after["resumed"] - before["resumed"] == 0,
		"delta=%d" % (after["resumed"] - before["resumed"])
	)

	# ── 6. No duplicate consecutive entries anywhere in the run ────────────────
	var seq := _pause_sequence()
	var dupes := 0
	for i in range(1, seq.size()):
		if seq[i] == seq[i - 1]:
			dupes += 1
	_check(
		"no two consecutive identical pause-state entries",
		dupes == 0,
		"sequence=%s" % str(seq)
	)
	_check(
		"sequence strictly alternates and is short",
		seq.size() == 2 and seq[0] == "paused" and seq[1] == "resumed",
		"sequence=%s" % str(seq)
	)


## Pause/resume entries SessionLogger recorded for NetworkManager, in order.
func _pause_sequence() -> Array:
	var out: Array = []
	if SessionLogger == null:
		return out
	for entry in SessionLogger.game_log:
		if str(entry.get("source", "")) != "NetworkManager":
			continue
		var msg := str(entry.get("message", ""))
		if msg.ends_with("Game paused"):
			out.append("paused")
		elif msg.ends_with("Game resumed"):
			out.append("resumed")
	return out


func _count_log_entries() -> Dictionary:
	var seq := _pause_sequence()
	var paused := 0
	var resumed := 0
	for s in seq:
		if s == "paused":
			paused += 1
		else:
			resumed += 1
	return {"paused": paused, "resumed": resumed}


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _finish() -> void:
	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("")
	print("  %s RESULT: %d passed, %d failed" % [role.to_upper(), results.size() - failed, failed])
	print("")
	_tree().quit(1 if failed > 0 else 0)
