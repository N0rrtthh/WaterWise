extends Node
##
## DefenceVerdict - is there an artifact in user://session_logs that a defence can
## actually use?
##
## Every other harness in tools/ asserts internal consistency: that the exported file
## agrees with the live algorithm that produced it. That is necessary and it is not
## sufficient. A defence also needs at least one artifact produced by a PERSON playing,
## because a bot's reaction times are a bot's, and a log written before run_context
## existed cannot say which kind of run it came from at all.
##
## So this one reads the evidence folder rather than the code. It partitions the logs
## by provenance - human / synthetic / pre-provenance - and exits non-zero while no
## human-played log carries a real three-tier progression. It asserts nothing about the
## algorithm and it cannot be satisfied by writing code; only by playing.
##
## Run: Godot --headless --path . tools/DefenceVerdict.tscn
## Exit 0 = a usable human-played artifact exists, 1 = not yet.

const LOG_DIR := "user://session_logs"

func _ready() -> void:
	var names := _log_names()
	if names.is_empty():
		print("no logs in %s" % LOG_DIR)
		get_tree().quit(1)
		return

	var human: Array = []
	var synthetic: int = 0
	var preprov: int = 0
	var unparseable: int = 0
	var rows: Array = []

	for n in names:
		var raw := FileAccess.get_file_as_string(LOG_DIR + "/" + n)
		var parsed = JSON.parse_string(raw)
		if typeof(parsed) != TYPE_DICTIONARY:
			unparseable += 1
			continue
		var d: Dictionary = parsed
		var rc = d.get("run_context", null)
		var algo: Dictionary = d.get("sp_algorithm", {})
		var prog: Dictionary = algo.get("difficulty_progression", {})
		var recs: Array = d.get("sp_game_records", [])
		var per_action: int = 0
		for r in recs:
			if str((r as Dictionary).get("reaction_time_source", "")) == "per_action":
				per_action += 1

		var kind := "pre-provenance"
		if rc == null:
			preprov += 1
		elif bool((rc as Dictionary).get("synthetic", false)):
			kind = "synthetic"
			synthetic += 1
		else:
			kind = "HUMAN"
			human.append(n)

		rows.append({
			"file": n, "kind": kind, "rounds": recs.size(), "per_action": per_action,
			"final": str(algo.get("final_difficulty", "?")),
			"phi": float(algo.get("final_phi", 0.0)),
			# peak_difficulty is deliberately null when no adaptive evaluation ran at
			# all (an unmeasured tier must not read as "Easy"), and the key IS present,
			# so get()'s "-" default never applied and two HUMAN rows in this very
			# listing printed "peak=<null>". Normalised here rather than at the source:
			# it makes the printed table readable AND revives the != "-" guard in the
			# usable-log gate below, which str(null) == "<null>" had quietly made dead.
			"peak": ("-" if prog.get("peak_difficulty") == null
				else str(prog.get("peak_difficulty"))),
			"evals": int(prog.get("evaluations", 0)),
			"three": bool(prog.get("all_three_tiers_reached", false))
		})

	print("=== DEFENCE VERDICT ===")
	print("  logs: %d total  |  HUMAN %d  synthetic %d  pre-provenance %d  unparseable %d"
		% [names.size(), human.size(), synthetic, preprov, unparseable])
	print("")
	print("  newest 12 (file / kind / rounds / per_action / final / phi / peak / evals / 3-tiers)")
	var shown: int = 0
	for i in range(rows.size() - 1, -1, -1):
		if shown >= 12:
			break
		shown += 1
		var r: Dictionary = rows[i]
		print("   %-34s %-14s r=%-3d pa=%-3d %-6s phi=%.4f peak=%-6s ev=%-3d 3t=%s"
			% [r["file"], r["kind"], r["rounds"], r["per_action"], r["final"],
			   r["phi"], r["peak"], r["evals"], str(r["three"])])

	# The gate. A human-played log only counts if it carries the trajectory: a
	# progression block with real evaluations, and a peak above Easy. A short abandoned
	# run is a truthful artifact and still proves nothing about three tiers.
	var usable: Array = []
	for r in rows:
		if str(r["kind"]) != "HUMAN":
			continue
		if int(r["evals"]) > 0 and str(r["peak"]) != "Easy" and str(r["peak"]) != "-":
			usable.append(r)

	print("")
	if usable.is_empty():
		print("  [NOT YET] no human-played log carries a three-tier progression.")
		print("            Play one single-player session and let it END normally")
		print("            (lives exhausted, or Return to Menu). ~14 rounds reached")
		print("            Hard for the bot. Then re-run this harness.")
		get_tree().quit(1)
		return
	print("  [OK] %d human-played log(s) usable as defence evidence:" % usable.size())
	for r in usable:
		print("       %s  rounds=%d peak=%s evals=%d all_three=%s"
			% [r["file"], int(r["rounds"]), str(r["peak"]), int(r["evals"]), str(r["three"])])
	get_tree().quit(0)

func _log_names() -> Array:
	var d := DirAccess.open(LOG_DIR)
	if d == null:
		return []
	var out: Array = []
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(f)
	out.sort()
	return out
