extends Node

## ═══════════════════════════════════════════════════════════════════
## SESSION LOGGER — Comprehensive Thesis Defence Telemetry
## ═══════════════════════════════════════════════════════════════════
##
## Records EVERYTHING from app launch to exit into a single structured
## JSON file per session.  Covers every metric the defence panel needs:
##
##   Gameplay   → SP games, MP rounds, scores, accuracy, droplets
##   Algorithm  → Every Φ value, difficulty change, coop adjustment
##   Performance → FPS (min/max/avg), memory peak, CPU temp peak,
##                 throttle events, dropped frames, algo latency
##   Network    → G-Counter payload size, MP sync score
##   Device     → Platform, model, Godot version, screen size
##   Timeline   → Scene visits, session start/end, duration
##
## Exported automatically on app quit, and manually via Dev Stats page.
## Files saved to: user://session_logs/session_YYYY-MM-DD_HH-MM-SS.json
## ═══════════════════════════════════════════════════════════════════

signal log_exported(file_path: String)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SESSION IDENTITY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var session_id: String = ""
## Started at instantiation, NOT in _ready(). Autoloads run _ready() in declaration
## order and NetworkManager (declared above SessionLogger) calls log_entry() from its
## own _ready(), so with the clock started in _ready() that first entry's elapsed_sec
## was Time.get_unix_time_from_system() - 0.0, i.e. a raw epoch (1788442502.25 in the
## Android log that exposed this) in a field every other row measures in seconds since
## launch. Property initialisers run when the autoload is instantiated, which is before
## any other autoload's _ready() can reach this node.
var session_start_unix: float = Time.get_unix_time_from_system()
var session_start_iso: String = Time.get_datetime_string_from_system()

## The ONE file this session writes. One app-open to app-close is one session and must
## leave one artifact: GameManager finalizes on EVERY return to the menu and each
## finalize exports, so a timestamped name per export wrote a new cumulative superset
## each time - one Android session produced four files at 282s/483s/821s/1129s, each a
## superset of the last. The path is chosen once and rewritten in place, which keeps the
## crash-safety the repeated export exists for (an app killed by Home still leaves the
## latest state on disk) without multiplying the artifact.
var _session_file_path: String = ""

## True once auto-play has driven ANY part of this session. run_context is written at
## export time from a live read, so a session that switched auto-play on partway through
## exported auto_play=false for its early files and true for its last one - the same
## session_id classified both HUMAN and synthetic, which is exactly the partition
## DefenceVerdict decides evidence on. Sticky, and in the conservative direction: a
## session a bot played any part of is not a human-played artifact.
var _auto_play_ever: bool = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAMEPLAY RECORDS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Each entry: {game_num, game_name, elapsed_sec, timestamp,
##              score, accuracy_pct, reaction_time_ms, reaction_time_s,
##              mistakes, difficulty, phi_index, droplets_earned}
var sp_games: Array = []

## Each entry: {round_num, elapsed_sec, timestamp,
##              p1:{score,success,difficulty,phi}, p2:{...},
##              team_success, team_score, sync_score}
var mp_rounds: Array = []

## Each entry: {scene, elapsed_sec, timestamp}
var scenes_visited: Array = []

## Last scene key seen by _track_current_scene(); "" until the first scene loads.
var _last_scene_key: String = ""

## Times this session's file has been rewritten (see _session_file_path).
var _export_count: int = 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ALGORITHM RECORDS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## SP difficulty changes from AdaptiveDifficulty.difficulty_changed signal
## Each entry: {elapsed_sec, from, to, reason, wma, phi, games_in_window}
var sp_difficulty_changes: Array = []

## CoopAdaptation adjustments from CoopAdaptation.difficulty_adapted signal
## Each entry: {elapsed_sec, p1_difficulty, p2_difficulty, skill_gap, mode}
var coop_difficulty_changes: Array = []

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PERFORMANCE RECORDS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Snapshots every SNAPSHOT_INTERVAL seconds
## Each entry: {elapsed_sec, fps, fps_avg, memory_mb, cpu_temp_c,
##              algo_latency_avg_ms, frame_time_ms, is_throttling, dropped_frames_total}
var perf_snapshots: Array = []

## Warning events: fps_critical, memory_exceeded, etc.
var perf_warnings: Array = []

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RUNNING AGGREGATES (updated by snapshot)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Share of frames that must meet the 30FPS floor for fps.passed to be true.
## The floor itself already carries a 10% tolerance in the frame time it is measured
## against (PerformanceProfiler.FRAME_BUDGET_MS = 36.67ms), so this is a tolerance on
## HOW OFTEN the floor may be missed, not on the floor. 95% because a scene transition
## legitimately costs a handful of frames and a session loads dozens of scenes; the raw
## percentage is published beside the verdict so a reader can apply a stricter bar.
const FPS_SUSTAINED_MIN_PCT: float = 95.0

## Below this many measured frames the sustained rate is not evidence and fps.passed
## publishes null instead of a verdict, exactly as thermal does without a sensor.
## 300 is ten seconds at the 30FPS floor. It only ever fires on a harness run or an
## instant-quit launch - a real session is minutes long - and those are precisely the
## runs that must not be able to claim a pass: a 9-frame headless export was reporting
## 100% sustained and passed=true at an actual 3FPS.
const FPS_MIN_FRAMES_FOR_VERDICT: int = 300

var fps_min_session: float = 9999.0
var fps_max_session: float = 0.0
var memory_peak_mb: float = 0.0
var cpu_temp_peak_c: float = 0.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CUMULATIVE GAMEPLAY STATS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var sp_games_count: int = 0
var mp_rounds_count: int = 0
var sp_total_score: int = 0
var mp_total_score: int = 0
var mp_p1_total_score: int = 0  # Cumulative P1 score across all MP rounds this session
var mp_p2_total_score: int = 0  # Cumulative P2 score across all MP rounds this session
var total_droplets_earned: int = 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME LOG (in-game print/debug messages ring buffer)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Ring buffer of in-game log messages captured during the session.
## Each entry: {elapsed_sec, source, message}
var game_log: Array = []
const MAX_LOG_ENTRIES: int = 800  # Keep last 800 messages to avoid memory bloat

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTERNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const SNAPSHOT_INTERVAL: float = 5.0
var _snapshot_timer: float = 0.0
var _last_exported_path: String = ""

## Record a single in-game log message (called from _log() helpers in autoloads).
## source: short tag e.g. "NetworkManager", "MPGame", "AutoPlay".
func log_entry(source: String, message: String) -> void:
	if game_log.size() >= MAX_LOG_ENTRIES:
		game_log.pop_front()  # Drop oldest to keep ring bounded
	game_log.append({
		"elapsed_sec": _elapsed(),
		"source": source,
		"message": message
	})

## Helper: snap a float to N decimal places.
## Godot has no global snapf() — use float.snapped(step) instead.
## Example: snapf(3.14159, 2) → 3.14
func snapf(value: float, decimals: int) -> float:
	var step := 1.0
	for i in range(decimals):
		step *= 0.1
	return snapped(value, step)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LIFECYCLE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)

	session_id = "WW_%s_%04d" % [
		session_start_iso
			.replace(":", "").replace("-", "").replace(" ", "_"),
		randi() % 9999
	]

	# Defer signal connections so all autoloads are ready
	call_deferred("_connect_signals")

	print("📋 SessionLogger ready — %s" % session_id)

func _connect_signals() -> void:
	# AdaptiveDifficulty — SP algorithm events
	if AdaptiveDifficulty:
		if not AdaptiveDifficulty.difficulty_changed.is_connected(_on_sp_difficulty_changed):
			AdaptiveDifficulty.difficulty_changed.connect(_on_sp_difficulty_changed)

	# CoopAdaptation — MP coop events
	if CoopAdaptation:
		if not CoopAdaptation.difficulty_adapted.is_connected(_on_coop_difficulty_adapted):
			CoopAdaptation.difficulty_adapted.connect(_on_coop_difficulty_adapted)

	# NetworkManager — MP round completions
	if NetworkManager:
		if not NetworkManager.both_players_completed.is_connected(_on_mp_round_completed):
			NetworkManager.both_players_completed.connect(_on_mp_round_completed)

	# PerformanceProfiler — warning events
	if PerformanceProfiler:
		if not PerformanceProfiler.performance_warning.is_connected(_on_perf_warning):
			PerformanceProfiler.performance_warning.connect(_on_perf_warning)

func _process(delta: float) -> void:
	# Latch auto-play the moment it is seen, not at export time. See _auto_play_ever.
	if not _auto_play_ever and _auto_play_live():
		_auto_play_ever = true

	_track_current_scene()

	_snapshot_timer += delta
	if _snapshot_timer >= SNAPSHOT_INTERVAL:
		_snapshot_timer = 0.0
		_take_perf_snapshot()


## Records a scene visit whenever the tree's current scene changes.
##
## record_scene_visit() below is the API for this and NOTHING in the shipped game called
## it - only tools/VerifyGameLab.gd did - so scenes_visited was [] and
## scenes_visited_count 0 in every exported log, including one with 50 recorded rounds.
## Polling the tree is what makes it complete: GameManager.transition_to_scene() is not
## the only route between scenes (62 direct change_scene_to_file() calls exist across
## autoload/, scenes/ and scripts/), so instrumenting that one function would have
## under-reported instead of not reporting.
func _track_current_scene() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var cur := tree.current_scene
	if cur == null:
		return
	var path := String(cur.scene_file_path)
	var key := path if path != "" else String(cur.name)
	if key == _last_scene_key:
		return
	_last_scene_key = key
	record_scene_visit(key.get_file().get_basename() if path != "" else key)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		export_session()
		get_tree().quit()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SCENE TRACKING (called by scenes on _ready)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func record_scene_visit(scene_name: String) -> void:
	# Game Lab visits are not part of the player's route through the game.
	if GameManager and GameManager.sandbox_mode:
		return
	scenes_visited.append({
		"scene": scene_name,
		"elapsed_sec": _elapsed(),
		"timestamp": Time.get_datetime_string_from_system()
	})

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SP GAME RECORDING (called from GameManager.complete_minigame)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Which quantity the round's reaction_time actually was. Read off the live
## minigame rather than guessed: MiniGameBase.report_reaction_time_source()
## returns "per_action" when the round produced measured action latencies and
## "round_duration" when it had nothing discrete to grade. "unknown" is returned
## only when no minigame is in the tree to ask, and is deliberately not defaulted
## to either real value.
func _reaction_time_source() -> String:
	var tree := get_tree()
	if tree == null:
		return "unknown"
	var scene := tree.current_scene
	if scene != null and scene.has_method("report_reaction_time_source"):
		return str(scene.call("report_reaction_time_source"))
	return "unknown"


## True when AutoPlayManager is driving the rounds, i.e. the samples are a bot's,
## not a player's. Read live rather than latched so a session that enables auto-play
## partway through is still marked.
func _auto_play_live() -> bool:
	var apm := get_node_or_null("/root/AutoPlayManager")
	if apm == null:
		return false
	if apm.has_method("is_auto_play_enabled"):
		return bool(apm.call("is_auto_play_enabled"))
	return false


## Sticky: true if auto-play was live at any point in this session. _process() latches
## it, and this also samples live so a caller reached before the first frame still sees
## an already-running bot.
func _auto_play_active() -> bool:
	if _auto_play_ever:
		return true
	if _auto_play_live():
		_auto_play_ever = true
	return true if _auto_play_ever else false


func record_sp_game(
	game_name: String,
	score: int,
	accuracy: float,
	reaction_time_ms: int,
	mistakes: int,
	difficulty: String,
	droplets_earned: int
) -> void:
	# Game Lab rounds never enter the exported log. A sandbox round has no place in
	# sp_game_records: it would be counted in the accuracy and sigma the defence
	# export is computed from.
	if GameManager and GameManager.sandbox_mode:
		return

	var phi: float = _get_current_phi()
	var wma: float = _get_current_wma()
	var cp: float = _get_current_cp()

	var record: Dictionary = {
		"game_num": sp_games_count + 1,
		"game_name": game_name,
		"elapsed_sec": _elapsed(),
		"timestamp": Time.get_datetime_string_from_system(),
		"score": score,
		"accuracy_pct": snapf(accuracy * 100.0, 1),
		"reaction_time_ms": reaction_time_ms,
		"reaction_time_s": snapf(float(reaction_time_ms) / 1000.0, 2),
		"mistakes": mistakes,
		"difficulty": difficulty,
		# Recorded so a reader can tell a real reaction-time sample from the
		# round-duration fallback used by games with no discrete graded actions.
		"reaction_time_source": _reaction_time_source(),
		# Which ALGORITHM session this round belongs to. SessionLogger accumulates for
		# the whole process - it has no reset and session_start_unix is set once in
		# _ready() - while GameManager finalizes and exports on every return to the
		# menu, so one exported log can hold rounds from several game sessions whose
		# sp_algorithm block describes only the last one. Without this field there is
		# no way to partition the record list back into the sessions that produced it.
		"algo_session_id": (str(AdaptiveDifficulty.session_id) if AdaptiveDifficulty else ""),
		"phi_index": snapf(phi, 4),
		"wma": snapf(wma, 4),
		"consistency_penalty": snapf(cp, 4),
		"droplets_earned": droplets_earned
	}
	sp_games.append(record)
	sp_games_count += 1
	sp_total_score += score
	total_droplets_earned += droplets_earned

	print("📋 SP logged #%d %s | Score:%d | Acc:%.0f%% | %s | Φ=%.3f" % [
		sp_games_count, game_name, score, accuracy * 100.0, difficulty, phi
	])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNAL HANDLERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_sp_difficulty_changed(old_diff: String, new_diff: String, reason: String) -> void:
	var metrics: Dictionary = {}
	# Public accessor, not the private _calculate_window_metrics() this used to
	# reach for. Every field below defaults to 0 when metrics comes back empty, so
	# if that private name were ever renamed the has_method() guard would quietly
	# log Φ=0.0 for every tier change instead of failing — corrupting the research
	# record rather than reporting a problem.
	if AdaptiveDifficulty and AdaptiveDifficulty.has_method("get_window_metrics"):
		metrics = AdaptiveDifficulty.get_window_metrics()

	sp_difficulty_changes.append({
		"elapsed_sec": _elapsed(),
		"timestamp": Time.get_datetime_string_from_system(),
		"from_difficulty": old_diff,
		"to_difficulty": new_diff,
		"reason": reason,
		"phi": snapf(metrics.get("proficiency_index", 0.0), 4),
		"wma": snapf(metrics.get("weighted_accuracy", 0.0), 4),
		"consistency_penalty": snapf(metrics.get("consistency_penalty", 0.0), 4),
		"std_deviation_ms": snapf(metrics.get("std_deviation", 0.0), 1),
		"games_in_window": int(metrics.get("window_size", 0))
	})

func _on_coop_difficulty_adapted(p1_diff: String, p2_diff: String, gap: float) -> void:
	var mode = "asymmetric" if gap > 0.15 else "symmetric"
	coop_difficulty_changes.append({
		"elapsed_sec": _elapsed(),
		"timestamp": Time.get_datetime_string_from_system(),
		"p1_difficulty": p1_diff,
		"p2_difficulty": p2_diff,
		"skill_gap": snapf(gap, 4),
		"mode": mode
	})

func _on_mp_round_completed(
	p1_success: bool, p2_success: bool,
	p1_score: int, p2_score: int
) -> void:
	# Game Lab rounds never enter the exported log - see record_sp_game().
	if GameManager and GameManager.sandbox_mode:
		return

	var p1_diff: String = "Unknown"
	var p2_diff: String = "Unknown"
	var p1_phi: float = 0.0
	var p2_phi: float = 0.0
	var skill_gap: float = 0.0
	var sync_score: float = 0.0

	if CoopAdaptation:
		p1_diff = CoopAdaptation.get_player_difficulty(1)
		p2_diff = CoopAdaptation.get_player_difficulty(2)
		if CoopAdaptation.has_method("get_team_metrics"):
			var tm: Dictionary = CoopAdaptation.get_team_metrics()
			p1_phi = snapf(float(tm.get("player1_proficiency", 0.0)), 4)
			p2_phi = snapf(float(tm.get("player2_proficiency", 0.0)), 4)
			skill_gap = snapf(float(tm.get("skill_gap", 0.0)), 4)
			sync_score = snapf(float(tm.get("current_sync_score", 0.0)), 1)

	var record: Dictionary = {
		"round_num": mp_rounds_count + 1,
		"elapsed_sec": _elapsed(),
		"timestamp": Time.get_datetime_string_from_system(),
		"p1": {
			"score": p1_score,
			"success": p1_success,
			"difficulty": p1_diff,
			"phi": p1_phi
		},
		"p2": {
			"score": p2_score,
			"success": p2_success,
			"difficulty": p2_diff,
			"phi": p2_phi
		},
		"team_success": p1_success and p2_success,
		"team_score": p1_score + p2_score,
		"sync_score": sync_score,
		"skill_gap": skill_gap
	}
	mp_rounds.append(record)
	mp_rounds_count += 1
	mp_total_score += p1_score + p2_score
	mp_p1_total_score += p1_score
	mp_p2_total_score += p2_score

	print("📋 MP round #%d | P1:%d P2:%d | Team:%s | Gap:%.3f" % [
		mp_rounds_count, p1_score, p2_score, str(p1_success and p2_success), skill_gap
	])

func _on_perf_warning(metric: String, value: float, threshold: float) -> void:
	# Only record significant events to avoid noise
	if metric in ["fps_critical", "memory_exceeded"]:
		perf_warnings.append({
			"elapsed_sec": _elapsed(),
			"metric": metric,
			"value": snapf(value, 2),
			"threshold": snapf(threshold, 2)
		})

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PERFORMANCE SNAPSHOT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _take_perf_snapshot() -> void:
	if not PerformanceProfiler:
		return

	var snap: Dictionary = {
		"elapsed_sec": _elapsed(),
		"fps": snapf(PerformanceProfiler.fps_current, 1),
		"fps_avg": snapf(PerformanceProfiler.fps_avg, 1),
		"memory_mb": snapf(PerformanceProfiler.memory_current_mb, 2),
		"cpu_temp_c": snapf(PerformanceProfiler.cpu_temp_c, 1),
		"algo_latency_avg_ms": snapf(PerformanceProfiler.algo_latency_avg_ms, 3),
		"algo_latency_max_ms": snapf(PerformanceProfiler.algo_latency_max_ms, 3),
		"frame_time_ms": snapf(PerformanceProfiler.frame_time_ms, 2),
		"is_throttling": PerformanceProfiler.is_throttling,
		"clock_speed_ratio": snapf(PerformanceProfiler.clock_speed_ratio, 3),
		"dropped_frames_total": PerformanceProfiler.dropped_frames,
		"total_frames": PerformanceProfiler.total_frames
	}
	perf_snapshots.append(snap)

	# Update session peaks
	if PerformanceProfiler.fps_current < fps_min_session:
		fps_min_session = PerformanceProfiler.fps_current
	if PerformanceProfiler.fps_current > fps_max_session:
		fps_max_session = PerformanceProfiler.fps_current
	if PerformanceProfiler.memory_current_mb > memory_peak_mb:
		memory_peak_mb = PerformanceProfiler.memory_current_mb
	if PerformanceProfiler.cpu_temp_c > cpu_temp_peak_c:
		cpu_temp_peak_c = PerformanceProfiler.cpu_temp_c

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LIVE SUMMARY (for DevStats UI)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_current_summary() -> Dictionary:
	var now_fps: float = PerformanceProfiler.fps_current if PerformanceProfiler else 0.0
	var now_temp: float = PerformanceProfiler.cpu_temp_c if PerformanceProfiler else 0.0
	var now_mem: float = PerformanceProfiler.memory_current_mb if PerformanceProfiler else 0.0
	var throttles: int = PerformanceProfiler.throttle_count if PerformanceProfiler else 0
	var dropped: int = PerformanceProfiler.dropped_frames if PerformanceProfiler else 0
	var total_fr: int = PerformanceProfiler.total_frames if PerformanceProfiler else 0
	var lat_avg: float = PerformanceProfiler.algo_latency_avg_ms if PerformanceProfiler else 0.0
	var lat_max: float = PerformanceProfiler.algo_latency_max_ms if PerformanceProfiler else 0.0
	var batt: float = PerformanceProfiler.battery_drain_per_min if PerformanceProfiler else 0.0
	var _ratio: float = PerformanceProfiler.rule_based_vs_dl_ratio if PerformanceProfiler else 0.0

	return {
		"session_id": session_id,
		"elapsed_sec": _elapsed(),
		"elapsed_formatted": _format_duration(_elapsed()),
		# Gameplay
		"sp_games": sp_games_count,
		"mp_rounds": mp_rounds_count,
		"sp_total_score": sp_total_score,
		"mp_total_score": mp_total_score,
		"total_droplets": _get_session_droplets_earned(),
		"scenes_visited": scenes_visited.size(),
		# SP Algorithm
		"sp_difficulty": AdaptiveDifficulty.get_current_difficulty() if AdaptiveDifficulty else "N/A",
		"phi": _get_current_phi(),
		"wma": _get_current_wma(),
		"cp": _get_current_cp(),
		"difficulty_changes": sp_difficulty_changes.size(),
		# MP Algorithm
		"p1_difficulty": CoopAdaptation.get_player_difficulty(1) if CoopAdaptation else "N/A",
		"p2_difficulty": CoopAdaptation.get_player_difficulty(2) if CoopAdaptation else "N/A",
		"coop_adjustments": coop_difficulty_changes.size(),
		# Performance
		"fps_now": snapf(now_fps, 1),
		"fps_min": snapf(fps_min_session if fps_min_session < 9999.0 else 0.0, 1),
		"fps_max": snapf(fps_max_session, 1),
		"fps_avg": _calc_fps_avg(),
		"memory_now_mb": snapf(now_mem, 1),
		"memory_peak_mb": snapf(memory_peak_mb, 1),
		"cpu_temp_now": snapf(now_temp, 1),
		"cpu_temp_peak": snapf(cpu_temp_peak_c, 1),
		"throttle_count": throttles,
		"throttle_events": PerformanceProfiler.throttle_events if PerformanceProfiler else [],
		"dropped_frames": dropped,
		"total_frames": total_fr,
		"drop_rate_pct": _calc_drop_rate(),
		"algo_latency_avg_ms": snapf(lat_avg, 3),
		"algo_latency_max_ms": snapf(lat_max, 3),
		"battery_mah_per_min": snapf(batt, 3),
		"battery_source": PerformanceProfiler.battery_source if PerformanceProfiler else "N/A",
		# Whether cpu_temp_* above came from a real sensor. A reader (and the Dev Stats
		# ISO list) cannot tell 0.0 "cool" from 0.0 "no sensor on this device" without it.
		"thermal_source": _thermal_source_str(),
		"efficiency_vs_dl_pct": _calc_efficiency_pct(),
		"fps_std_dev": _get_fps_std_dev(),
		"iso_pass": _check_iso_pass(),
		"last_exported_path": _last_exported_path,
		"perf_warnings_count": perf_warnings.size()
	}

## Returns the SP game records array for display
func get_sp_records() -> Array:
	return sp_games

## Returns the MP round records array for display
func get_mp_records() -> Array:
	return mp_rounds

## Returns algorithm decision log
func get_sp_difficulty_changes() -> Array:
	return sp_difficulty_changes

## Returns coop adjustments log
func get_coop_changes() -> Array:
	return coop_difficulty_changes

## Returns throttle event log from PerformanceProfiler
func get_throttle_events() -> Array:
	if PerformanceProfiler:
		return PerformanceProfiler.throttle_events
	return []

## Returns an Array of Dictionaries suitable for displaying the MP leaderboard.
## Each entry: {round_num, p1_score, p2_score, team_score, team_success, timestamp}
## Plus a trailing "totals" entry.
func get_mp_leaderboard() -> Array:
	var rows: Array = []
	# No rounds, no leaderboard. The totals sentinel used to be appended
	# unconditionally, so a session that never played multiplayer exported
	# mp_rounds_played: 0, mp_round_records: [] and a one-row mp_leaderboard holding
	# round_num: -1 with team_success: true - a zero-round session claiming a team
	# success. MultiplayerLobby already special-cases "size()==1 and round_num==-1" to
	# show its empty state, so returning [] is what that caller means by empty.
	if mp_rounds.is_empty():
		return rows
	for r in mp_rounds:
		rows.append({
			"round_num": r.get("round_num", 0),
			"p1_score": r.get("p1", {}).get("score", 0),
			"p2_score": r.get("p2", {}).get("score", 0),
			"team_score": r.get("team_score", 0),
			"team_success": r.get("team_success", false),
			"timestamp": r.get("timestamp", "")
		})
	# Append session totals as a sentinel row (round_num == -1)
	rows.append({
		"round_num": -1,
		"p1_score": mp_p1_total_score,
		"p2_score": mp_p2_total_score,
		"team_score": mp_p1_total_score + mp_p2_total_score,
		"team_success": true,
		"timestamp": ""
	})
	return rows

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EXPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## force=false is the automatic path (session finalize, window close): a log with no
## rounds of either kind carries no measurement, and GameManager finalizes on EVERY
## return to the menu, so those exports filled session_logs/ with content-free files -
## 31 of 97 at the time this guard was added. Callers that deliberately want the
## artifact regardless (harnesses that assert on the file) pass force=true. Nothing is
## hidden: the skip is printed, and an empty log never carried anything a reader could
## use.
##
## Every call in one session rewrites ONE file (see _session_file_path), so calling this
## repeatedly cannot multiply the artifact.
func export_session(force: bool = false) -> String:
	if not force and sp_games.is_empty() and mp_rounds.is_empty():
		print("\U0001F4CA SessionLogger: no rounds recorded - export skipped (pass force=true to write anyway)")
		return ""
	_take_perf_snapshot()  # Final snapshot before export

	var end_unix := Time.get_unix_time_from_system()
	var duration_sec := end_unix - session_start_unix

	# ── Device info ──────────────────────────────────────────────────
	var vp_size := Vector2.ZERO
	if get_viewport():
		vp_size = get_viewport().get_visible_rect().size

	var device_info: Dictionary = {
		"platform": OS.get_name(),
		# The OS version was absent from every exported session, and it is the one field
		# that settles a platform question outright. Android's storage rules change at
		# API 29, 30 and 33, so a log saying only "moto e5 plus / Android" could not
		# distinguish a missing runtime permission from a scoped-storage block - the
		# reader had to guess which of three causes made an export fail.
		# Three fields because the content is platform-defined and no single one of them
		# is guaranteed to carry the API level: get_version() is the raw string,
		# get_version_alias() the human form, get_distribution_name() the OS family.
		# Desktop control values: "10.0.19045" / "10 (build 19045)" / "Windows".
		"os_version": OS.get_version(),
		"os_version_alias": OS.get_version_alias(),
		"os_distribution": OS.get_distribution_name(),
		"model": OS.get_model_name(),
		"processor_count": OS.get_processor_count(),
		"processor_name": OS.get_processor_name(),
		"godot_version": Engine.get_version_info().get("string", "?"),
		"screen_width": int(vp_size.x),
		"screen_height": int(vp_size.y)
	}

	# ── Performance summary ───────────────────────────────────────────
	var fps_avg := _calc_fps_avg()
	var drop_rate := _calc_drop_rate()
	var algo_lat_avg := _get_algo_latency_avg()
	var algo_lat_max := _get_algo_latency_max()
	var batt := _get_battery_drain()
	var throttles := _get_throttle_count()
	var efficiency := _calc_efficiency_pct()

	# Each criterion first, then the verdict FROM them. This used to publish
	# PerformanceProfiler._check_iso_compliance(), which judges the last 60 frames
	# (PerformanceProfiler.fps_avg is a rolling window), while "fps" below reports the
	# whole session (the mean of every 5-second snapshot). On the Android device that
	# exposed this the file said fps.passed=false, average_observed=29.5 AND
	# iso_25010_compliant=true in the same block. A compliance claim must be derivable
	# from the numbers printed next to it.
	# "minimum_required: 30" is a SUSTAINED-rate requirement and it used to be tested as
	# `mean of the FPS series >= 30.0`. That comparison is unsatisfiable on BOTH target
	# platforms, because on both of them 30 is the CEILING and not the floor:
	#   Android - MobileUIManager._apply_mobile_performance_profile() sets
	#             Engine.max_fps = mobile_target_fps (30) as a battery policy, so
	#             Engine.get_frames_per_second() cannot report more than 30.
	#   Laptop  - vsync on a 60Hz panel halves to a steady 33.33ms cadence.
	# A mean can only equal its own ceiling if EVERY sample sits exactly on it, so one
	# scene-load hitch anywhere in a session failed the whole session and dragged
	# iso_25010_compliant down with it. Measured on session_2026-05-05T20-32-37.json:
	# 7510 frames with 44 over the 36.67ms budget (99.41% sustained), all 51 sampled
	# frame times between 33.33ms and 33.38ms, and the file still said passed=false
	# because the mean of a series bounded by 30.0 came out at 29.6.
	# So the criterion is now the sustained rate itself, read from the per-frame
	# counters PerformanceProfiler already keeps (dropped_frames counts frames slower
	# than FRAME_BUDGET_MS, excluding STARTUP_WARMUP_SEC). That is per-frame over the
	# whole session rather than one instant every 5 seconds, and it cannot be rescued
	# by high peaks the way a mean can. The old mean test is still published beside it
	# as mean_at_or_above_floor, so this change is auditable from the file alone.
	# Numerator and denominator come from the same population: both are gated on
	# STARTUP_WARMUP_SEC. Dividing by total_frames instead mixed populations, because
	# total_frames counts startup frames that dropped_frames is not allowed to count.
	var frames_measured := _get_frames_after_warmup()
	var frames_over := _get_dropped_frames()
	var sustained_pct := (
		snapf(100.0 * (1.0 - float(frames_over) / float(frames_measured)), 2)
		if frames_measured > 0 else 0.0
	)
	var fps_mean_pass := fps_avg >= 30.0
	# Too few frames is not a fail and not a pass. Same rule as thermal below: a
	# criterion with no measurement behind it publishes null.
	var fps_evaluated := frames_measured >= FPS_MIN_FRAMES_FOR_VERDICT
	var fps_pass = (sustained_pct >= FPS_SUSTAINED_MIN_PCT) if fps_evaluated else null
	var mem_pass := memory_peak_mb <= 200.0
	var lat_pass := algo_lat_max <= 16.0
	var thermal_measured := _thermal_source_str() == "sensor"
	var thermal_pass = (
		(cpu_temp_peak_c <= 45.0 and throttles == 0) if thermal_measured else null
	)
	# Unmeasured thermal does not fail the session and does not pass it either: the
	# three measured criteria decide, exactly as PerformanceProfiler._check_iso_compliance
	# does when it has no sensor.
	# Explicitly typed: thermal_pass is Variant (bool or null), so the compiler cannot
	# infer the type of an expression that reads it.
	var iso_pass: bool = (
		(fps_pass != false) and mem_pass and lat_pass and (thermal_pass != false)
	)

	var perf_summary: Dictionary = {
		"iso_25010_compliant": iso_pass,
		# Which criteria the verdict above was computed from, and which could not be
		# measured on this device.
		"iso_criteria": {
			"fps_passed": fps_pass,
			"fps_evaluated": fps_evaluated,
			"memory_passed": mem_pass,
			"algorithm_latency_passed": lat_pass,
			"thermal_passed": thermal_pass,
			"thermal_evaluated": thermal_measured
		},
		"fps": {
			"target": 60,
			"minimum_required": 30,
			# The ceiling average_observed is bounded by. Without it a reader cannot
			# tell 29.6 "the device is struggling" from 29.6 "the device is pinned
			# at 30". 0 means uncapped (desktop); on mobile it is mobile_target_fps.
			"engine_max_fps": Engine.max_fps,
			# All three of these now describe ONE series - the 5-second samples of
			# PerformanceProfiler.fps_avg that average_observed is the mean of - so
			# minimum <= average <= maximum holds by construction. They used to mix
			# two series: the average came from the rolling means while min/max came
			# from instantaneous fps_current, sampled once per snapshot. Real
			# exported evidence therefore contradicted itself -
			# session_2026-09-03T20-10-53.json published min=1.0, max=1.0 and
			# average=5.7 in the same block. The instantaneous extremes are kept
			# below under their own names.
			"minimum_observed": _calc_fps_min(),
			"maximum_observed": _calc_fps_max(),
			"average_observed": fps_avg,
			# The unsmoothed extremes, at the 5-second snapshot instants only.
			# Narrower evidence than the series above (one frame in ~150), which is
			# exactly why they are no longer what minimum/maximum_observed report.
			"instantaneous_minimum": snapf(
				fps_min_session if fps_min_session < 9999.0 else 0.0, 1),
			"instantaneous_maximum": snapf(fps_max_session, 1),
			# Per-frame, whole session, startup excluded - the basis of passed below.
			"frames_measured": frames_measured,
			"frames_over_budget": frames_over,
			"budget_ms": PerformanceProfiler.FRAME_BUDGET_MS,
			"sustained_at_floor_pct": sustained_pct,
			"sustained_required_pct": FPS_SUSTAINED_MIN_PCT,
			# Startup frames are counted here but are not eligible to be over budget, so
			# this is deliberately NOT the denominator of the rate above. Published so the
			# two counts can be compared and the excluded warmup is visible.
			"frames_total_including_warmup": _get_total_frames(),
			"minimum_frames_for_verdict": FPS_MIN_FRAMES_FOR_VERDICT,
			"evaluated": fps_evaluated,
			"mean_at_or_above_floor": fps_mean_pass,
			# null when evaluated is false: too short a run to make the claim.
			"passed": fps_pass
		},
		"memory": {
			"budget_mb": 200.0,
			"peak_mb": snapf(memory_peak_mb, 2),
			"passed": mem_pass
		},
		"thermal": {
			"threshold_c": 45.0,
			"peak_c": snapf(cpu_temp_peak_c, 1),
			"throttle_events": throttles,
			"throttle_details": get_throttle_events(),
			# cpu_temp_peak_c only ever moves when PerformanceProfiler has a real
			# sensor to read; on desktop (and on any Android build whose sysfs nodes
			# are unreadable) it stays 0.0, and "0.0 <= 45.0" published
			# "passed": true — a thermal pass in the exported session log of a run
			# that measured no temperature. null = not evaluated, matching
			# PerformanceProfiler's thermal block and _check_iso_compliance, which
			# both already refuse to judge thermal without sensor data.
			"thermal_source": _thermal_source_str(),
			"temperature_evaluated": thermal_measured,
			"passed": thermal_pass,
			# S_clk is a behavioural proxy (FPS/target) and IS measured everywhere,
			# so the stability half of the criterion is still reported as a bool.
			"s_clk_stable": throttles == 0
		},
		"algorithm_latency": {
			"budget_ms": 16.0,
			"avg_ms": algo_lat_avg,
			"max_ms": algo_lat_max,
			"passed": lat_pass
		},
		"dropped_frames": {
			"count": _get_dropped_frames(),
			"total_frames": _get_total_frames(),
			"drop_rate_pct": drop_rate
		},
		# What the ISO overlay cost the frame budget it was measuring. It rebuilt a
		# 15-line emoji Label once per frame before this, which is why enabling the
		# profiler on the Moto E5 Plus made the numbers it reported worse. refresh_hz
		# near 4 means the throttle held; near the frame rate means it did not.
		"overlay_cost": {
			"refresh_count": (
				PerformanceProfiler.overlay_refresh_count if PerformanceProfiler else 0
			),
			"refresh_hz": (
				(float(PerformanceProfiler.overlay_refresh_count)
					/ PerformanceProfiler.session_elapsed_sec)
				if PerformanceProfiler and PerformanceProfiler.session_elapsed_sec > 0.0
				else 0.0
			),
			"was_visible": (
				PerformanceProfiler.overlay_visible if PerformanceProfiler else false
			)
		},
		"battery_efficiency": {
			"measured_mah_per_min": batt,
			"dl_baseline_mah_per_min": 10.0,
			"rule_based_savings_pct": efficiency,
			"battery_source": PerformanceProfiler.battery_source if PerformanceProfiler else "N/A"
		},
		"perf_warnings": perf_warnings
	}

	# ── SP algorithm summary ──────────────────────────────────────────
	var sp_algo: Dictionary = {
		"algorithm": "Rule-Based Rolling Window with Proficiency Index (Φ)",
		# The block below describes ONE game session - this one. Cross-reference it
		# against sp_game_records[].algo_session_id to select that session's rounds.
		"algo_session_id": (str(AdaptiveDifficulty.session_id) if AdaptiveDifficulty else ""),
		"window_size": AdaptiveDifficulty.window_size if AdaptiveDifficulty else 5,
		"warmup_games": AdaptiveDifficulty.min_games_before_adaptation if AdaptiveDifficulty else 3,
		"final_difficulty": AdaptiveDifficulty.get_current_difficulty() if AdaptiveDifficulty else "N/A",
		# final_difficulty above is ONE INSTANTANEOUS SAMPLE - the tier the last
		# evaluated window landed on - and reading it as the session's outcome is what
		# produced the report "many games but it only got to Medium and it did not get
		# harder". Across the 48 case studies in user://, final_difficulty reads Easy in
		# 38 and Medium in 10 and Hard in none, while the difficulty timelines inside
		# those same files hold 129 Hard decisions including one unbroken 41-evaluation
		# Hard streak: a long Hard run followed by a few abandoned rounds exports "Easy".
		# This field is the trajectory those decisions actually took, and it is the one
		# that evidences the three-tier decision tree. See
		# AdaptiveDifficulty.get_difficulty_progression().
		"difficulty_progression": (
			AdaptiveDifficulty.get_difficulty_progression()
			if AdaptiveDifficulty and AdaptiveDifficulty.has_method("get_difficulty_progression")
			else {}),
		"final_phi": _get_current_phi(),
		"final_wma": _get_current_wma(),
		"final_cp": _get_current_cp(),
		"progressive_level": AdaptiveDifficulty.progressive_level if AdaptiveDifficulty else 0,
		"total_difficulty_changes": sp_difficulty_changes.size(),
		"difficulty_change_log": sp_difficulty_changes
	}

	# ── MP algorithm summary ──────────────────────────────────────────
	var mp_metrics: Dictionary = {}
	if CoopAdaptation and CoopAdaptation.has_method("get_team_metrics"):
		mp_metrics = CoopAdaptation.get_team_metrics()

	var mp_algo: Dictionary = {
		"algorithm": "CoopAdaptation — Per-Player Φ + Skill Gap Co-Adaptation",
		"skill_gap_threshold": 0.15,
		"p1_final_difficulty": CoopAdaptation.get_player_difficulty(1) if CoopAdaptation else "N/A",
		"p2_final_difficulty": CoopAdaptation.get_player_difficulty(2) if CoopAdaptation else "N/A",
		"p1_phi": snapf(float(mp_metrics.get("player1_proficiency", 0.0)), 4),
		"p2_phi": snapf(float(mp_metrics.get("player2_proficiency", 0.0)), 4),
		"skill_gap": snapf(float(mp_metrics.get("skill_gap", 0.0)), 4),
		"team_success_rate": snapf(float(mp_metrics.get("team_success_rate", 0.0)), 3),
		"avg_sync_score": snapf(float(mp_metrics.get("avg_sync_score", 0.0)), 1),
		"is_asymmetric_mode": bool(mp_metrics.get("is_asymmetric", false)),
		"total_coop_adjustments": coop_difficulty_changes.size(),
		"coop_adjustment_log": coop_difficulty_changes
	}

	# ── Gameplay summary ──────────────────────────────────────────────
	var gameplay: Dictionary = {
		"sp_games_played": sp_games_count,
		"sp_total_score": sp_total_score,
		"sp_avg_score": snapf(float(sp_total_score) / max(sp_games_count, 1), 1),
		"sp_avg_accuracy_pct": _calc_sp_avg_accuracy(),
		"sp_avg_reaction_time_s": _calc_sp_avg_reaction_time(),
		"mp_rounds_played": mp_rounds_count,
		"mp_total_score": mp_total_score,
		"mp_p1_total_score": mp_p1_total_score,
		"mp_p2_total_score": mp_p2_total_score,
		"mp_leaderboard": get_mp_leaderboard(),
		"mp_team_wins": _count_mp_wins(),
		"mp_win_rate_pct": _calc_mp_win_rate(),
		"total_droplets_earned": _get_session_droplets_earned(),
		"scenes_visited_count": scenes_visited.size()
	}

	# ── Full report ───────────────────────────────────────────────────
	var report: Dictionary = {
		"waterwise_session_log": true,
		# 2.1 added device.os_version / os_version_alias / os_distribution.
		# 2.2 reworks performance.fps: engine_max_fps, the sustained-rate fields, and
		# minimum/maximum_observed now taken from the same series as average_observed
		# (see the block itself). That part is NOT purely additive - those two keys
		# changed which series they describe - so a reader comparing files across the
		# boundary needs the version to know it. No code branches on this string; it is
		# provenance for a human.
		"schema_version": "2.2",
		# Which kind of run produced this file. user:// mixes real play with headless
		# harness and soak output, and the two are not interchangeable as evidence:
		# a harness round has no minigame in the tree, so its reaction_time_source is
		# "unknown" and its samples are synthetic. Recorded rather than left for a
		# reader to infer from the numbers.
		"run_context": {
			"headless": DisplayServer.get_name() == "headless",
			"auto_play": _auto_play_active(),
			"synthetic": DisplayServer.get_name() == "headless" or _auto_play_active()
		},
		# How many times this session's single file has been rewritten. A session
		# finalizes on every return to the menu, so >1 is normal and does not mean
		# more than one session is in here.
		"export_count": _export_count + 1,
		"session_id": session_id,
		"session_start": session_start_iso,
		"session_end": Time.get_datetime_string_from_system(),
		"session_duration_sec": snapf(duration_sec, 1),
		"session_duration_formatted": _format_duration(duration_sec),
		"device": device_info,
		"gameplay_summary": gameplay,
		"sp_algorithm": sp_algo,
		"mp_algorithm": mp_algo,
		"performance": perf_summary,
		"sp_game_records": sp_games,
		"mp_round_records": mp_rounds,
		"scenes_visited": scenes_visited,
		"performance_snapshots": perf_snapshots,
		"game_log": game_log
	}

	# ── Write to file ─────────────────────────────────────────────────
	var user_dir := DirAccess.open("user://")
	if user_dir:
		user_dir.make_dir_recursive("session_logs")

	# The SAME path every time this session exports - chosen once, from the session
	# start, not from the clock at export time. See _session_file_path.
	if _session_file_path == "":
		_session_file_path = "user://session_logs/session_%s.json" % session_start_iso \
			.replace(":", "-").replace(" ", "_")
	var filename := _session_file_path
	var file := FileAccess.open(filename, FileAccess.WRITE)

	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
		_export_count += 1
		_last_exported_path = ProjectSettings.globalize_path(filename)
		print("📊 SessionLogger export (#%d): %s" % [_export_count, _last_exported_path])
		log_exported.emit(_last_exported_path)
		return _last_exported_path

	push_error("SessionLogger: Failed to write %s" % filename)
	return ""

func get_last_exported_path() -> String:
	return _last_exported_path

## Returns the directory where session log files are written.
## FileExporter calls this to know where to read logs back from for export.
func get_export_dir() -> String:
	return "user://session_logs/"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _elapsed() -> float:
	return snapf(Time.get_unix_time_from_system() - session_start_unix, 2)

func _format_duration(sec: float) -> String:
	var remaining_sec: int = maxi(0, int(sec))
	var h: int = 0
	var m: int = 0
	while remaining_sec >= 3600:
		h += 1
		remaining_sec -= 3600
	while remaining_sec >= 60:
		m += 1
		remaining_sec -= 60
	var s: int = remaining_sec
	return "%02d:%02d:%02d" % [h, m, s]

func _get_current_phi() -> float:
	if AdaptiveDifficulty and AdaptiveDifficulty.has_method("get_window_metrics"):
		return snapf(AdaptiveDifficulty.get_window_metrics().get("proficiency_index", 0.0), 4)
	return 0.0

func _get_current_wma() -> float:
	if AdaptiveDifficulty and AdaptiveDifficulty.has_method("get_window_metrics"):
		return snapf(AdaptiveDifficulty.get_window_metrics().get("weighted_accuracy", 0.0), 4)
	return 0.0

func _get_current_cp() -> float:
	if AdaptiveDifficulty and AdaptiveDifficulty.has_method("get_window_metrics"):
		return snapf(AdaptiveDifficulty.get_window_metrics().get("consistency_penalty", 0.0), 4)
	return 0.0

func _get_session_droplets_earned() -> int:
	if GameManager and GameManager.has_method("get"):
		return int(GameManager.get("session_droplets_earned"))
	return total_droplets_earned

func _calc_fps_avg() -> float:
	if perf_snapshots.is_empty():
		return snapf(PerformanceProfiler.fps_avg if PerformanceProfiler else 0.0, 1)
	var total := 0.0
	for s in perf_snapshots:
		total += float(s.get("fps_avg", 0.0))
	return snapf(total / float(perf_snapshots.size()), 1)

## Over the same series _calc_fps_avg() averages, so the published minimum, average
## and maximum cannot disagree. Falls back to the live rolling average when no
## snapshot has been taken yet, exactly as _calc_fps_avg() does.
func _calc_fps_min() -> float:
	if perf_snapshots.is_empty():
		return snapf(PerformanceProfiler.fps_avg if PerformanceProfiler else 0.0, 1)
	var lo := INF
	for s in perf_snapshots:
		lo = minf(lo, float(s.get("fps_avg", 0.0)))
	return snapf(lo, 1)

func _calc_fps_max() -> float:
	if perf_snapshots.is_empty():
		return snapf(PerformanceProfiler.fps_avg if PerformanceProfiler else 0.0, 1)
	var hi := -INF
	for s in perf_snapshots:
		hi = maxf(hi, float(s.get("fps_avg", 0.0)))
	return snapf(hi, 1)

func _calc_drop_rate() -> float:
	if PerformanceProfiler and PerformanceProfiler.total_frames > 0:
		return snapf(
			float(PerformanceProfiler.dropped_frames) /
			float(PerformanceProfiler.total_frames) * 100.0, 2
		)
	return 0.0

func _get_throttle_count() -> int:
	return PerformanceProfiler.throttle_count if PerformanceProfiler else 0

func _get_dropped_frames() -> int:
	return PerformanceProfiler.dropped_frames if PerformanceProfiler else 0

## Frames counted under the same warmup gate as dropped_frames, so the two form a
## ratio over one population. See PerformanceProfiler.frames_after_warmup.
func _get_frames_after_warmup() -> int:
	return PerformanceProfiler.frames_after_warmup if PerformanceProfiler else 0

func _get_total_frames() -> int:
	return PerformanceProfiler.total_frames if PerformanceProfiler else 0

func _get_algo_latency_avg() -> float:
	return snapf(PerformanceProfiler.algo_latency_avg_ms if PerformanceProfiler else 0.0, 3)

func _get_algo_latency_max() -> float:
	return snapf(PerformanceProfiler.algo_latency_max_ms if PerformanceProfiler else 0.0, 3)

func _get_battery_drain() -> float:
	return snapf(PerformanceProfiler.battery_drain_per_min if PerformanceProfiler else 0.0, 3)

func _calc_efficiency_pct() -> float:
	if PerformanceProfiler and PerformanceProfiler.battery_drain_per_min > 0.0:
		return snapf((1.0 - PerformanceProfiler.rule_based_vs_dl_ratio) * 100.0, 1)
	return 0.0

func _check_iso_pass() -> bool:
	if PerformanceProfiler:
		return PerformanceProfiler._check_iso_compliance()
	return false

func _calc_sp_avg_accuracy() -> float:
	if sp_games.is_empty():
		return 0.0
	var total := 0.0
	for g in sp_games:
		total += float(g.get("accuracy_pct", 0.0))
	return snapf(total / float(sp_games.size()), 1)

func _calc_sp_avg_reaction_time() -> float:
	if sp_games.is_empty():
		return 0.0
	var total := 0.0
	for g in sp_games:
		total += float(g.get("reaction_time_s", 0.0))
	return snapf(total / float(sp_games.size()), 2)

func _count_mp_wins() -> int:
	var wins := 0
	for r in mp_rounds:
		if bool(r.get("team_success", false)):
			wins += 1
	return wins

func _calc_mp_win_rate() -> float:
	if mp_rounds.is_empty():
		return 0.0
	return snapf(float(_count_mp_wins()) / float(mp_rounds.size()) * 100.0, 1)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THESIS DEFENCE DATA ACCESSORS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _get_fps_std_dev() -> float:
	if PerformanceProfiler and PerformanceProfiler.has_method("get_fps_std_dev"):
		return snapf(PerformanceProfiler.get_fps_std_dev(), 2)
	return 0.0

## Temperature heat curve — bucketed 1-second samples for DevStats display.
func get_temp_curve() -> Array:
	if PerformanceProfiler and PerformanceProfiler.has_method("get_temp_curve"):
		return PerformanceProfiler.get_temp_curve()
	return []

## Memory usage over time — bucketed snapshots for leak-detection display.
func get_memory_trend() -> Array:
	if PerformanceProfiler and PerformanceProfiler.has_method("get_memory_curve"):
		return PerformanceProfiler.get_memory_curve()
	return []

## Structured DL baseline comparison table for Chapter 4.
func get_dl_comparison() -> Array:
	if PerformanceProfiler and PerformanceProfiler.has_method("get_dl_comparison"):
		return PerformanceProfiler.get_dl_comparison()
	return []

## Thermal provenance, forwarded from the profiler so the exported log can say why a
## thermal criterion was or was not evaluated. "unknown" when the profiler is absent
## — which is itself not a pass.
func _thermal_source_str() -> String:
	if PerformanceProfiler and PerformanceProfiler.has_method("get_thermal_source"):
		return PerformanceProfiler.get_thermal_source()
	return "unknown"
