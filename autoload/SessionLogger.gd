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
## JSON + TXT saved to the configured export directory (default: user://session_logs/).
## Change export path via Settings > Dev Mode > "Log Export Path"
## or call SessionLogger.set_export_dir(path) at runtime.
## On Android, set an external path like "/sdcard/Documents/WaterWise/" for easy access.
## ═══════════════════════════════════════════════════════════════════

signal log_exported(file_path: String)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SESSION IDENTITY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var session_id: String = ""
var session_start_unix: float = 0.0
var session_start_iso: String = ""

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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER PER-DEVICE RECORDS (Each device records its own metrics)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Local player's individual performance in each MP round
## Each entry: {round_num, game_name, my_score, my_accuracy_pct, my_reaction_time_ms,
##              my_mistakes, my_difficulty, my_phi, partner_score, team_success,
##              latency_ms, packet_loss_pct}
var mp_local_performance: Array = []

## Connection quality metrics per round
## Each entry: {round_num, latency_ms, packet_loss_pct, sync_events, desyncs}
var mp_connection_metrics: Array = []

## Network events (disconnects, reconnects, sync issues)
## Each entry: {elapsed_sec, timestamp, event_type, details}
var mp_network_events: Array = []

## Each entry: {scene, elapsed_sec, timestamp}
var scenes_visited: Array = []

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
var total_droplets_earned: int = 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTERNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const SNAPSHOT_INTERVAL: float = 5.0
var _snapshot_timer: float = 0.0
var _last_exported_path: String = ""

## Configurable export directory.
## Supports user:// paths or absolute paths (e.g. /sdcard/Documents/WaterWise/).
## Loaded from SaveManager key "session_log_dir"; defaults to user://session_logs/
var export_dir: String = "user://session_logs/"

func set_export_dir(dir: String) -> void:
	## Set a custom export directory and persist it in SaveManager.
	## Pass an empty string to reset to the default.
	if dir.strip_edges().is_empty():
		export_dir = "user://session_logs/"
	else:
		export_dir = dir if dir.ends_with("/") else dir + "/"
	if SaveManager:
		SaveManager.set_setting("session_log_dir", export_dir)
	print("\ud83d\udcc1 SessionLogger export dir set to: %s" % export_dir)

func get_export_dir() -> String:
	return export_dir

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

	session_start_unix = Time.get_unix_time_from_system()
	session_start_iso = Time.get_datetime_string_from_system()
	session_id = "WW_%s_%04d" % [
		Time.get_datetime_string_from_system()
			.replace(":", "").replace("-", "").replace(" ", "_"),
		randi() % 9999
	]

	# Load configurable export directory from SaveManager (deferred so SM is ready)
	call_deferred("_load_export_dir")
	# Defer signal connections so all autoloads are ready
	call_deferred("_connect_signals")

	print("📋 SessionLogger ready — %s" % session_id)

func _load_export_dir() -> void:
	if SaveManager:
		var saved_dir: String = SaveManager.get_setting("session_log_dir", "")
		if not saved_dir.is_empty():
			export_dir = saved_dir
	print("📁 SessionLogger export dir: %s" % export_dir)

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
	_snapshot_timer += delta
	if _snapshot_timer >= SNAPSHOT_INTERVAL:
		_snapshot_timer = 0.0
		_take_perf_snapshot()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		export_session()
		get_tree().quit()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SCENE TRACKING (called by scenes on _ready)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func record_scene_visit(scene_name: String) -> void:
	scenes_visited.append({
		"scene": scene_name,
		"elapsed_sec": _elapsed(),
		"timestamp": Time.get_datetime_string_from_system()
	})

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SP GAME RECORDING (called from GameManager.complete_minigame)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func record_sp_game(
	game_name: String,
	score: int,
	accuracy: float,
	reaction_time_ms: int,
	mistakes: int,
	difficulty: String,
	droplets_earned: int
) -> void:
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
# MP LOCAL PERFORMANCE RECORDING (Per-Device)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func record_mp_local_round(
	round_num: int,
	game_name: String,
	my_score: int,
	my_accuracy: float,
	my_reaction_time_ms: int,
	my_mistakes: int,
	my_difficulty: String,
	my_phi: float,
	partner_score: int,
	team_success: bool,
	latency_ms: float = 0.0,
	packet_loss_pct: float = 0.0
) -> void:
	## Record local player's performance in this MP round
	var record: Dictionary = {
		"round_num": round_num,
		"game_name": game_name,
		"elapsed_sec": _elapsed(),
		"timestamp": Time.get_datetime_string_from_system(),
		# Local metrics
		"my_score": my_score,
		"my_accuracy_pct": snapf(my_accuracy * 100.0, 1),
		"my_reaction_time_ms": my_reaction_time_ms,
		"my_reaction_time_s": snapf(float(my_reaction_time_ms) / 1000.0, 2),
		"my_mistakes": my_mistakes,
		"my_difficulty": my_difficulty,
		"my_phi": snapf(my_phi, 4),
		# Team metrics
		"partner_score": partner_score,
		"team_success": team_success,
		"team_score": my_score + partner_score,
		# Connection metrics
		"latency_ms": snapf(latency_ms, 1),
		"packet_loss_pct": snapf(packet_loss_pct, 2)
	}
	mp_local_performance.append(record)
	
	# Also record connection metrics separately
	mp_connection_metrics.append({
		"round_num": round_num,
		"elapsed_sec": _elapsed(),
		"latency_ms": snapf(latency_ms, 1),
		"packet_loss_pct": snapf(packet_loss_pct, 2),
		"sync_events": 0,
		"desyncs": 0
	})
	
	print("📋 MP Local P%d #%d %s | MyScore:%d | Acc:%.0f%% | Latency:%.0fms" % [
		_get_local_player_num(), round_num, game_name, my_score, 
		my_accuracy * 100.0, latency_ms
	])

func record_mp_network_event(event_type: String, details: Dictionary = {}) -> void:
	## Record network events (disconnect, reconnect, desync, etc.)
	mp_network_events.append({
		"elapsed_sec": _elapsed(),
		"timestamp": Time.get_datetime_string_from_system(),
		"event_type": event_type,
		"details": details
	})
	print("📡 MP Network Event: %s" % event_type)

func _get_local_player_num() -> int:
	if GameManager:
		return GameManager.local_player_num
	elif NetworkManager:
		return NetworkManager.get_local_player_num()
	return 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNAL HANDLERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_sp_difficulty_changed(old_diff: String, new_diff: String, reason: String) -> void:
	var metrics: Dictionary = {}
	if AdaptiveDifficulty and AdaptiveDifficulty.has_method("_calculate_window_metrics"):
		metrics = AdaptiveDifficulty._calculate_window_metrics()

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
		"total_droplets": total_droplets_earned,
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
		"efficiency_vs_dl_pct": _calc_efficiency_pct(),
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EXPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func export_session() -> String:
	_take_perf_snapshot()  # Final snapshot before export

	var end_unix := Time.get_unix_time_from_system()
	var duration_sec := end_unix - session_start_unix

	# ── Device info ──────────────────────────────────────────────────
	var vp_size := Vector2.ZERO
	if get_viewport():
		vp_size = get_viewport().get_visible_rect().size

	var device_info: Dictionary = {
		"platform": OS.get_name(),
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
	var iso_pass := _check_iso_pass()

	var perf_summary: Dictionary = {
		"iso_25010_compliant": iso_pass,
		"fps": {
			"target": 60,
			"minimum_required": 30,
			"minimum_observed": snapf(fps_min_session if fps_min_session < 9999.0 else 0.0, 1),
			"maximum_observed": snapf(fps_max_session, 1),
			"average_observed": fps_avg,
			"passed": fps_avg >= 30.0
		},
		"memory": {
			"budget_mb": 200.0,
			"peak_mb": snapf(memory_peak_mb, 2),
			"passed": memory_peak_mb <= 200.0
		},
		"thermal": {
			"threshold_c": 45.0,
			"peak_c": snapf(cpu_temp_peak_c, 1),
			"throttle_events": throttles,
			"throttle_details": get_throttle_events(),
			"passed": cpu_temp_peak_c <= 45.0 and throttles == 0
		},
		"algorithm_latency": {
			"budget_ms": 16.0,
			"avg_ms": algo_lat_avg,
			"max_ms": algo_lat_max,
			"passed": algo_lat_max <= 16.0
		},
		"dropped_frames": {
			"count": _get_dropped_frames(),
			"total_frames": _get_total_frames(),
			"drop_rate_pct": drop_rate
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
		"window_size": AdaptiveDifficulty.window_size if AdaptiveDifficulty else 5,
		"warmup_games": AdaptiveDifficulty.min_games_before_adaptation if AdaptiveDifficulty else 3,
		"final_difficulty": AdaptiveDifficulty.get_current_difficulty() if AdaptiveDifficulty else "N/A",
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
		"mp_team_wins": _count_mp_wins(),
		"mp_win_rate_pct": _calc_mp_win_rate(),
		"total_droplets_earned": total_droplets_earned,
		"scenes_visited_count": scenes_visited.size()
	}

	# ── MP Local Performance (Per-Device) ─────────────────────────────
	var mp_local_summary: Dictionary = {
		"local_player_num": _get_local_player_num(),
		"local_peer_id": multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 0,
		"rounds_played": mp_local_performance.size(),
		"my_total_score": _calc_mp_local_total_score(),
		"my_avg_score": _calc_mp_local_avg_score(),
		"my_avg_accuracy_pct": _calc_mp_local_avg_accuracy(),
		"my_avg_reaction_time_s": _calc_mp_local_avg_reaction_time(),
		"my_total_mistakes": _calc_mp_local_total_mistakes(),
		"team_wins": _count_mp_local_wins(),
		"win_rate_pct": _calc_mp_local_win_rate(),
		"avg_latency_ms": _calc_mp_avg_latency(),
		"avg_packet_loss_pct": _calc_mp_avg_packet_loss(),
		"network_events_count": mp_network_events.size()
	}

	# ── Full report ───────────────────────────────────────────────────
	var report: Dictionary = {
		"waterwise_session_log": true,
		"schema_version": "2.0",
		"session_id": session_id,
		"session_start": session_start_iso,
		"session_end": Time.get_datetime_string_from_system(),
		"session_duration_sec": snapf(duration_sec, 1),
		"session_duration_formatted": _format_duration(duration_sec),
		"device": device_info,
		"gameplay_summary": gameplay,
		"sp_algorithm": sp_algo,
		"mp_algorithm": mp_algo,
		"mp_local_performance": mp_local_summary,
		"performance": perf_summary,
		"sp_game_records": sp_games,
		"mp_round_records": mp_rounds,
		"mp_local_round_records": mp_local_performance,
		"mp_connection_metrics": mp_connection_metrics,
		"mp_network_events": mp_network_events,
		"scenes_visited": scenes_visited,
		"performance_snapshots": perf_snapshots
	}

	# ── Write to file ─────────────────────────────────────────────────
	var dt := Time.get_datetime_string_from_system() \
		.replace(":", "-").replace(" ", "_")

	# Ensure the export directory exists (handles both user:// and absolute paths)
	_ensure_export_dir(export_dir)

	var json_path := export_dir + "session_%s.json" % dt
	var txt_path  := export_dir + "session_%s.txt"  % dt

	# Write JSON
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file:
		json_file.store_string(JSON.stringify(report, "\t"))
		json_file.close()
		_last_exported_path = ProjectSettings.globalize_path(json_path)
		print("📊 SessionLogger JSON: %s" % _last_exported_path)
	else:
		push_error("SessionLogger: Failed to write JSON: %s" % json_path)

	# Write TXT (human-readable summary alongside the JSON)
	var txt_written := _write_txt_report(report, txt_path)
	if txt_written:
		print("📄 SessionLogger TXT:  %s" % ProjectSettings.globalize_path(txt_path))

	if _last_exported_path != "":
		log_exported.emit(_last_exported_path)
		return _last_exported_path

	push_error("SessionLogger: Export failed for %s" % json_path)
	return ""

## Ensure the export directory exists, handling both user:// and absolute paths.
func _ensure_export_dir(dir_path: String) -> void:
	if dir_path.begins_with("user://") or dir_path.begins_with("res://"):
		var da := DirAccess.open("user://")
		if da:
			var rel := dir_path.replace("user://", "").trim_suffix("/")
			da.make_dir_recursive(rel)
	else:
		DirAccess.make_dir_recursive_absolute(dir_path.trim_suffix("/"))

## Write a concise human-readable .txt companion to the JSON export.
func _write_txt_report(report: Dictionary, txt_path: String) -> bool:
	var f := FileAccess.open(txt_path, FileAccess.WRITE)
	if not f:
		return false

	var sep60 := "============================================================"
	var sep40 := "----------------------------------------"

	f.store_line(sep60)
	f.store_line("  WATERWISE SESSION LOG")
	f.store_line(sep60)
	f.store_line("Session ID   : " + str(report.get("session_id", "")))
	f.store_line("Start Time   : " + str(report.get("session_start", "")))
	f.store_line("End Time     : " + str(report.get("session_end", "")))
	f.store_line("Duration     : " + str(report.get("session_duration_formatted", "")))
	f.store_line("")

	# Device
	var dev: Dictionary = report.get("device", {})
	f.store_line("[DEVICE]")
	f.store_line("  Platform   : " + str(dev.get("platform", "?")))
	f.store_line("  Model      : " + str(dev.get("model", "?")))
	f.store_line("  Processors : " + str(dev.get("processor_count", "?")))
	f.store_line("  Resolution : %dx%d" % [
		int(dev.get("screen_width", 0)), int(dev.get("screen_height", 0))
	])
	f.store_line("  Godot      : " + str(dev.get("godot_version", "?")))
	f.store_line("")

	# Gameplay
	var gp: Dictionary = report.get("gameplay_summary", {})
	f.store_line("[GAMEPLAY SUMMARY]")
	f.store_line("  SP Games Played    : " + str(gp.get("sp_games_played", 0)))
	f.store_line("  SP Total Score     : " + str(gp.get("sp_total_score", 0)))
	f.store_line("  SP Avg Score       : " + str(gp.get("sp_avg_score", 0.0)))
	f.store_line("  SP Avg Accuracy    : " + str(gp.get("sp_avg_accuracy_pct", 0.0)) + "%")
	f.store_line("  SP Avg Reaction    : " + str(gp.get("sp_avg_reaction_time_s", 0.0)) + "s")
	f.store_line("  MP Rounds Played   : " + str(gp.get("mp_rounds_played", 0)))
	f.store_line("  MP Total Score     : " + str(gp.get("mp_total_score", 0)))
	f.store_line("  MP Team Wins       : " + str(gp.get("mp_team_wins", 0)))
	f.store_line("  Total Droplets     : " + str(gp.get("total_droplets_earned", 0)))
	f.store_line("")

	# SP Algorithm
	var alg: Dictionary = report.get("sp_algorithm", {})
	f.store_line("[SP ALGORITHM]")
	f.store_line("  Algorithm          : " + str(alg.get("algorithm", "?")))
	f.store_line("  Final Difficulty   : " + str(alg.get("final_difficulty", "?")))
	f.store_line("  Final Phi (Φ)      : " + str(alg.get("final_phi", 0.0)))
	f.store_line("  Final WMA          : " + str(alg.get("final_wma", 0.0)))
	f.store_line("  Difficulty Changes : " + str(alg.get("total_difficulty_changes", 0)))
	f.store_line("")

	# MP Algorithm
	var mp_alg: Dictionary = report.get("mp_algorithm", {})
	f.store_line("[MP ALGORITHM]")
	f.store_line("  P1 Difficulty      : " + str(mp_alg.get("p1_final_difficulty", "?")))
	f.store_line("  P2 Difficulty      : " + str(mp_alg.get("p2_final_difficulty", "?")))
	f.store_line("  Skill Gap          : " + str(mp_alg.get("skill_gap", 0.0)))
	f.store_line("  Team Success Rate  : " + str(mp_alg.get("team_success_rate", 0.0)))
	f.store_line("")

	# Performance
	var perf: Dictionary = report.get("performance", {})
	var fps_d: Dictionary = perf.get("fps", {})
	var mem_d: Dictionary = perf.get("memory", {})
	var therm: Dictionary = perf.get("thermal", {})
	var lat_d: Dictionary = perf.get("algorithm_latency", {})
	f.store_line("[PERFORMANCE]")
	f.store_line("  ISO 25010 Pass     : " + str(perf.get("iso_25010_compliant", false)))
	f.store_line("  FPS Min/Avg/Max    : %s / %s / %s" % [
		str(fps_d.get("minimum_observed", 0)),
		str(fps_d.get("average_observed", 0)),
		str(fps_d.get("maximum_observed", 0))
	])
	f.store_line("  FPS Pass           : " + str(fps_d.get("passed", false)))
	f.store_line("  Memory Peak        : " + str(mem_d.get("peak_mb", 0.0)) + " MB")
	f.store_line("  Memory Pass        : " + str(mem_d.get("passed", false)))
	f.store_line("  CPU Temp Peak      : " + str(therm.get("peak_c", 0.0)) + " °C")
	f.store_line("  Throttle Events    : " + str(therm.get("throttle_events", 0)))
	f.store_line("  Algo Latency Avg   : " + str(lat_d.get("avg_ms", 0.0)) + " ms")
	f.store_line("  Algo Latency Max   : " + str(lat_d.get("max_ms", 0.0)) + " ms")
	f.store_line("")

	# SP Game Records
	var sp_games_arr: Array = report.get("sp_game_records", [])
	f.store_line("[SP GAME RECORDS]  (%d games)" % sp_games_arr.size())
	f.store_line("  #    | Game                  | Score | Acc%  | React | Diff   | Φ")
	f.store_line("  " + sep40)
	for rec in sp_games_arr:
		f.store_line("  %-4d | %-21s | %-5d | %-5s | %-5s | %-6s | %s" % [
			int(rec.get("game_num", 0)),
			str(rec.get("game_name", "")).left(21),
			int(rec.get("score", 0)),
			str(snapf(float(rec.get("accuracy_pct", 0.0)), 1)),
			str(snapf(float(rec.get("reaction_time_s", 0.0)), 2)) + "s",
			str(rec.get("difficulty", "?")),
			str(rec.get("phi_index", 0.0))
		])
	f.store_line("")

	# MP Round Records
	var mp_rounds_arr: Array = report.get("mp_round_records", [])
	f.store_line("[MP ROUND RECORDS]  (%d rounds)" % mp_rounds_arr.size())
	for rec in mp_rounds_arr:
		var p1d: Dictionary = rec.get("p1", {})
		var p2d: Dictionary = rec.get("p2", {})
		f.store_line("  Round %-3d | Team %s | P1 score=%-4d | P2 score=%-4d | Sync=%.1f" % [
			int(rec.get("round_num", 0)),
			("WIN " if rec.get("team_success", false) else "LOSS"),
			int(p1d.get("score", 0)),
			int(p2d.get("score", 0)),
			float(rec.get("sync_score", 0.0))
		])
	f.store_line("")

	f.store_line(sep60)
	f.store_line("  Export dir: " + export_dir)
	f.store_line(sep60)
	f.close()
	return true

func get_last_exported_path() -> String:
	return _last_exported_path

## Export ONLY a .txt human-readable summary (no JSON).
## Returns the absolute path on success, empty string on failure.
func export_session_txt() -> String:
	_take_perf_snapshot()

	# Re-use export_session() to build the full report dictionary, then
	# write only the TXT file so we don't double-write JSON.
	var end_unix := Time.get_unix_time_from_system()
	var duration_sec := end_unix - session_start_unix

	var vp_size := Vector2.ZERO
	if get_viewport():
		vp_size = get_viewport().get_visible_rect().size

	var device_info: Dictionary = {
		"platform": OS.get_name(), "model": OS.get_model_name(),
		"processor_count": OS.get_processor_count(),
		"processor_name": OS.get_processor_name(),
		"godot_version": Engine.get_version_info().get("string", "?"),
		"screen_width": int(vp_size.x), "screen_height": int(vp_size.y)
	}

	var fps_avg := _calc_fps_avg()
	var drop_rate := _calc_drop_rate()
	var algo_lat_avg := _get_algo_latency_avg()
	var algo_lat_max := _get_algo_latency_max()
	var batt := _get_battery_drain()
	var throttles := _get_throttle_count()
	var efficiency := _calc_efficiency_pct()
	var iso_pass := _check_iso_pass()

	var perf_summary: Dictionary = {
		"iso_25010_compliant": iso_pass,
		"fps": {"target": 60, "minimum_required": 30,
			"minimum_observed": snapf(fps_min_session if fps_min_session < 9999.0 else 0.0, 1),
			"maximum_observed": snapf(fps_max_session, 1), "average_observed": fps_avg,
			"passed": fps_avg >= 30.0},
		"memory": {"budget_mb": 200.0, "peak_mb": snapf(memory_peak_mb, 2),
			"passed": memory_peak_mb <= 200.0},
		"thermal": {"threshold_c": 45.0, "peak_c": snapf(cpu_temp_peak_c, 1),
			"throttle_events": throttles, "throttle_details": get_throttle_events(),
			"passed": cpu_temp_peak_c <= 45.0 and throttles == 0},
		"algorithm_latency": {"budget_ms": 16.0, "avg_ms": algo_lat_avg,
			"max_ms": algo_lat_max, "passed": algo_lat_max <= 16.0},
		"dropped_frames": {"count": _get_dropped_frames(),
			"total_frames": _get_total_frames(), "drop_rate_pct": drop_rate},
		"battery_efficiency": {"measured_mah_per_min": batt,
			"dl_baseline_mah_per_min": 10.0, "rule_based_savings_pct": efficiency,
			"battery_source": PerformanceProfiler.battery_source if PerformanceProfiler else "N/A"},
		"perf_warnings": perf_warnings
	}

	var sp_algo: Dictionary = {
		"algorithm": "Rule-Based Rolling Window with Proficiency Index (Φ)",
		"window_size": AdaptiveDifficulty.window_size if AdaptiveDifficulty else 5,
		"warmup_games": AdaptiveDifficulty.min_games_before_adaptation if AdaptiveDifficulty else 3,
		"final_difficulty": AdaptiveDifficulty.get_current_difficulty() if AdaptiveDifficulty else "N/A",
		"final_phi": _get_current_phi(), "final_wma": _get_current_wma(),
		"final_cp": _get_current_cp(),
		"progressive_level": AdaptiveDifficulty.progressive_level if AdaptiveDifficulty else 0,
		"total_difficulty_changes": sp_difficulty_changes.size(),
		"difficulty_change_log": sp_difficulty_changes
	}

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

	var gameplay: Dictionary = {
		"sp_games_played": sp_games_count, "sp_total_score": sp_total_score,
		"sp_avg_score": snapf(float(sp_total_score) / max(sp_games_count, 1), 1),
		"sp_avg_accuracy_pct": _calc_sp_avg_accuracy(),
		"sp_avg_reaction_time_s": _calc_sp_avg_reaction_time(),
		"mp_rounds_played": mp_rounds_count, "mp_total_score": mp_total_score,
		"mp_team_wins": _count_mp_wins(), "mp_win_rate_pct": _calc_mp_win_rate(),
		"total_droplets_earned": total_droplets_earned,
		"scenes_visited_count": scenes_visited.size()
	}

	var report: Dictionary = {
		"waterwise_session_log": true, "schema_version": "2.0",
		"session_id": session_id, "session_start": session_start_iso,
		"session_end": Time.get_datetime_string_from_system(),
		"session_duration_sec": snapf(duration_sec, 1),
		"session_duration_formatted": _format_duration(duration_sec),
		"device": device_info, "gameplay_summary": gameplay,
		"sp_algorithm": sp_algo, "mp_algorithm": mp_algo,
		"performance": perf_summary, "sp_game_records": sp_games,
		"mp_round_records": mp_rounds, "scenes_visited": scenes_visited,
		"performance_snapshots": perf_snapshots
	}

	_ensure_export_dir(export_dir)
	var dt := Time.get_datetime_string_from_system() \
		.replace(":", "-").replace(" ", "_")
	var txt_path := export_dir + "session_%s.txt" % dt

	if _write_txt_report(report, txt_path):
		var abs_path := ProjectSettings.globalize_path(txt_path)
		print("📄 SessionLogger TXT (standalone): %s" % abs_path)
		return abs_path

	push_error("SessionLogger: TXT export failed for %s" % txt_path)
	return ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _elapsed() -> float:
	return snapf(Time.get_unix_time_from_system() - session_start_unix, 2)

func _format_duration(sec: float) -> String:
	var h := int(sec / 3600.0)
	var m := int((sec - h * 3600) / 60.0)
	var s := int(sec) % 60
	return "%02d:%02d:%02d" % [h, m, s]

func _get_current_phi() -> float:
	if AdaptiveDifficulty and AdaptiveDifficulty.has_method("_calculate_window_metrics"):
		return snapf(AdaptiveDifficulty._calculate_window_metrics().get("proficiency_index", 0.0), 4)
	return 0.0

func _get_current_wma() -> float:
	if AdaptiveDifficulty and AdaptiveDifficulty.has_method("_calculate_window_metrics"):
		return snapf(AdaptiveDifficulty._calculate_window_metrics().get("weighted_accuracy", 0.0), 4)
	return 0.0

func _get_current_cp() -> float:
	if AdaptiveDifficulty and AdaptiveDifficulty.has_method("_calculate_window_metrics"):
		return snapf(AdaptiveDifficulty._calculate_window_metrics().get("consistency_penalty", 0.0), 4)
	return 0.0

func _calc_fps_avg() -> float:
	if perf_snapshots.is_empty():
		return snapf(PerformanceProfiler.fps_avg if PerformanceProfiler else 0.0, 1)
	var total := 0.0
	for s in perf_snapshots:
		total += float(s.get("fps_avg", 0.0))
	return snapf(total / float(perf_snapshots.size()), 1)

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
# MP LOCAL PERFORMANCE HELPERS (Per-Device Metrics)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _calc_mp_local_total_score() -> int:
	var total: int = 0
	for rec in mp_local_performance:
		total += int(rec.get("my_score", 0))
	return total

func _calc_mp_local_avg_score() -> float:
	if mp_local_performance.is_empty():
		return 0.0
	return snapf(float(_calc_mp_local_total_score()) / float(mp_local_performance.size()), 1)

func _calc_mp_local_avg_accuracy() -> float:
	if mp_local_performance.is_empty():
		return 0.0
	var sum: float = 0.0
	for rec in mp_local_performance:
		sum += float(rec.get("my_accuracy_pct", 0.0))
	return snapf(sum / float(mp_local_performance.size()), 1)

func _calc_mp_local_avg_reaction_time() -> float:
	if mp_local_performance.is_empty():
		return 0.0
	var sum: float = 0.0
	for rec in mp_local_performance:
		sum += float(rec.get("my_reaction_time_s", 0.0))
	return snapf(sum / float(mp_local_performance.size()), 2)

func _calc_mp_local_total_mistakes() -> int:
	var total: int = 0
	for rec in mp_local_performance:
		total += int(rec.get("my_mistakes", 0))
	return total

func _count_mp_local_wins() -> int:
	var wins: int = 0
	for rec in mp_local_performance:
		if rec.get("team_success", false):
			wins += 1
	return wins

func _calc_mp_local_win_rate() -> float:
	if mp_local_performance.is_empty():
		return 0.0
	return snapf(float(_count_mp_local_wins()) / float(mp_local_performance.size()) * 100.0, 1)

func _calc_mp_avg_latency() -> float:
	if mp_connection_metrics.is_empty():
		return 0.0
	var sum: float = 0.0
	for rec in mp_connection_metrics:
		sum += float(rec.get("latency_ms", 0.0))
	return snapf(sum / float(mp_connection_metrics.size()), 1)

func _calc_mp_avg_packet_loss() -> float:
	if mp_connection_metrics.is_empty():
		return 0.0
	var sum: float = 0.0
	for rec in mp_connection_metrics:
		sum += float(rec.get("packet_loss_pct", 0.0))
	return snapf(sum / float(mp_connection_metrics.size()), 2)
