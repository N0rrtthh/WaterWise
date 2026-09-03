extends Node

## ═══════════════════════════════════════════════════════════════════
## SAVEMANAGER.GD - Persistence System for WaterWise
## ═══════════════════════════════════════════════════════════════════
## Handles saving/loading of:
## - Player progress
## - High scores per game
## - Unlocked characters/games
## - Achievements
## - Settings preferences
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal data_loaded()
signal data_saved()
signal achievement_unlocked(achievement_id: String)
signal setting_changed(key: String, value: Variant)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONSTANTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const SAVE_PATH: String = "user://waterwise_save.json"
const SETTINGS_PATH: String = "user://waterwise_settings.json"
const SAVE_VERSION: int = 1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DATA STRUCTURES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Player Progress
var player_data: Dictionary = {
	"save_version": SAVE_VERSION,
	"total_water_saved": 0,
	"water_droplets": 0,
	"games_played": 0,
	"total_play_time": 0,  # seconds
	"current_level": 1,
	"selected_character": "droppy_blue",
	"selected_accessory": "character_default",
	"first_play_date": "",
	"last_play_date": ""
}

# High Scores (per game)
var high_scores: Dictionary = {
	# "game_id": { "score": 0, "accuracy": 0.0, "best_time": 999 }
}

# Single-player session score history (for leaderboards)
var sp_session_scores: Array = []

# Unlocked Content
var unlocked_content: Dictionary = {
	"characters": ["droppy_blue"],
	"minigames": ["catch_rain", "pipe_puzzle"],
	"themes": ["default"],
	"accessories": ["character_default"],
	"decorations": []
}

# Achievements
var achievements: Dictionary = {
	"first_drop": {
		"name": "First Drop", "desc": "Complete your first game", "unlocked": false, "icon": "💧"
	},
	"water_saver": {
		"name": "Water Saver", "desc": "Save 100 liters of water", "unlocked": false, "icon": "🌊"
	},
	"perfect_game": {
		"name": "Perfect!", "desc": "Get 100% accuracy in any game", "unlocked": false, "icon": "⭐"
	},
	"speed_demon": {
		"name": "Speed Demon", "desc": "Complete a game in under 30 seconds", "unlocked": false,
		"icon": "⚡"
	},
	"persistent": {
		"name": "Persistent", "desc": "Play 10 games in one session", "unlocked": false,
		"icon": "🔄"
	},
	"collector": {
		"name": "Collector", "desc": "Unlock 5 characters", "unlocked": false, "icon": "👤"
	},
	"explorer": {
		"name": "Explorer", "desc": "Play all available minigames", "unlocked": false, "icon": "🗺️"
	},
	"coop_star": {
		"name": "Co-op Star", "desc": "Win a multiplayer game", "unlocked": false, "icon": "🤝"
	},
	"streak_3": {
		"name": "Hat Trick", "desc": "Win 3 games in a row", "unlocked": false, "icon": "🎯"
	},
	"streak_5": {
		"name": "On Fire!", "desc": "Win 5 games in a row", "unlocked": false, "icon": "🔥"
	},
	"master": {
		"name": "Water Master", "desc": "Reach Hard difficulty", "unlocked": false, "icon": "👑"
	},
	"eco_warrior": {
		"name": "Eco Warrior", "desc": "Save 1000 liters total", "unlocked": false, "icon": "🌍"
	}
}

# Settings
var settings: Dictionary = {
	# NO "language" key here on purpose. Localization owns the language and persists it
	# to user://settings.cfg as the Language enum; this dictionary used to carry a
	# second "language": "en" that nothing read and nothing updated, so a build running
	# in Filipino still shipped "language": "en" inside waterwise_settings.json --
	# two stores disagreeing, with the dead one being the human-readable artifact.
	# Existing save files keep the stale key (_load_settings copies unknown keys in),
	# which is harmless because no call site asks for it. Use Localization instead.
	"sfx_volume": 1.0,
	"music_volume": 0.8,
	"colorblind_mode": false,
	"large_touch_targets": false,
	"audio_cues": true,
	"screen_shake": true,
	"particles": true,
	"fullscreen": true,
	"show_hints": true,
	"haptics_enabled": true,
	"auto_difficulty": true,
	"dev_mode": false,
	"dev_show_profiler": false,
	"dev_show_algorithm_overlay": false,
	"auto_play_enabled": false,
	"auto_play_duration": 0.0  # 0 = unlimited, otherwise seconds
}

# Session tracking (not saved)
var session_games_played: int = 0
var win_streak: int = 0
var session_start_time: float = 0.0
## Sub-second remainder of the play-time accounting (see _update_play_time).
var _play_time_carry: float = 0.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	load_all_data()
	_apply_fullscreen_setting()
	session_start_time = Time.get_unix_time_from_system()
	_ensure_accessory_defaults()

	# Debounce timer for coalesced writes (see save_all_data).
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SEC
	_save_timer.timeout.connect(_flush_save)
	# Keep flushing while the tree is paused, otherwise a save requested just
	# before the pause menu opens would sit unwritten until the game resumes.
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_save_timer)

	# Set first play date if new player
	if player_data.first_play_date == "":
		player_data.first_play_date = Time.get_datetime_string_from_system()

	# Update last play date
	player_data.last_play_date = Time.get_datetime_string_from_system()

func _notification(what: int) -> void:
	# Auto-save when app closes
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_update_play_time()
		save_now()
	# Android does not send a close request when the user backgrounds the app —
	# it sends APPLICATION_PAUSED, and the OS may kill the process afterwards
	# without any further notification. Without this branch a coalesced save
	# still sitting in the deferred queue would be lost along with the round the
	# player just finished. Both paths write synchronously: a deferred call is
	# not guaranteed to run once the process is going away.
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_update_play_time()
		save_now()

func _exit_tree() -> void:
	# Last line of defence for the debounce window. Not every shutdown path
	# raises a close request (a headless run or an explicit get_tree().quit()
	# does not), and a queued write would otherwise die with the timer.
	if _save_pending:
		save_now()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SAVE/LOAD
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Set while a coalesced write is queued.
var _save_pending: bool = false
var _save_timer: Timer = null

## How long to gather save requests before writing. A single round end fans out
## into several requests (add_droplets → record_game_result → update_stat → …)
## spread over consecutive frames, so a purely per-frame coalesce collapsed
## almost nothing: a measured 8-round soak still performed 20 writes. Anything
## the process might not survive (shutdown, Android pause) writes synchronously
## via save_now(), so the worst case this window risks is losing under a second
## of progress to a hard crash.
const SAVE_DEBOUNCE_SEC: float = 1.0

## Request a save. Requests within SAVE_DEBOUNCE_SEC collapse into one write.
##
## Around fifteen call sites inside this class each used to write immediately, so
## finishing a single round wrote the whole save file two or three times over.
## Each write is a pretty-printed JSON.stringify of the entire player record plus
## a second write for settings — avoidable flash I/O and avoidable garbage on a
## low-end Android device, and one interruption window per write.
##
## Semantics are unchanged for callers: the data is still saved, just once.
func save_all_data() -> void:
	_save_pending = true
	if _save_timer:
		# Restarting on each request is intentional: it batches a burst into one
		# write at the end of the burst.
		_save_timer.start()
	else:
		# Before _ready (or in a bare SceneTree harness) there is no timer to
		# schedule against, so fall back to writing straight through rather than
		# silently dropping the request.
		save_now()

func _flush_save() -> void:
	if not _save_pending:
		return
	save_now()

## Write immediately, bypassing coalescing. Use when the process may not survive
## to the end of the debounce window.
func save_now() -> void:
	# Game Lab: the sandbox may not reach the disk. This is the single chokepoint
	# for every write - droplets, high scores, unlocks, play time, settings - so
	# refusing here is what makes "it will not reflect on the main game" true
	# rather than merely intended.
	if GameManager and GameManager.sandbox_mode:
		_save_pending = false
		if _save_timer:
			_save_timer.stop()
		return

	_save_pending = false
	if _save_timer:
		_save_timer.stop()
	_update_play_time()

	# Always stamp current version before writing
	player_data["save_version"] = SAVE_VERSION

	var save_data: Dictionary = {
		"save_version": SAVE_VERSION,
		"player": player_data,
		"high_scores": high_scores,
		"sp_session_scores": sp_session_scores,
		"unlocked": unlocked_content,
		"achievements": achievements
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("💾 Game data saved")
		data_saved.emit()
	else:
		push_error("Failed to save game data")

	# Save settings separately
	_save_settings()

## ── Game Lab: in-memory rollback ──────────────────────────────────────────
##
## Blocking save_now() stops a sandbox round reaching the disk, but not the
## in-memory stores it writes on the way there: SaveManager.add_droplets()
## raises player_data.water_droplets and only THEN asks for a save. Refusing the
## save leaves the inflated count sitting in memory, and the next REAL save -
## after the player leaves the Lab - would write it out. Measured on the co-op
## path: NetworkManager._check_both_completed() awards MP droplets directly
## through add_droplets(), with no round record in between to guard.
##
## So the Lab snapshots every persisted store on the way in and puts it back on
## the way out. That covers droplets, high scores, per-game stats, unlocks,
## achievements and play time in one place, instead of a guard per writer that a
## future writer could be added without.
var _sandbox_snapshot: Dictionary = {}

func sandbox_snapshot() -> void:
	_sandbox_snapshot = {
		"player": player_data.duplicate(true),
		"high_scores": high_scores.duplicate(true),
		"sp_session_scores": sp_session_scores.duplicate(true),
		"unlocked": unlocked_content.duplicate(true),
		"achievements": achievements.duplicate(true),
		"play_time_carry": _play_time_carry,
		"session_games_played": session_games_played,
		"win_streak": win_streak
	}

func sandbox_restore() -> void:
	if _sandbox_snapshot.is_empty():
		return
	player_data = (_sandbox_snapshot["player"] as Dictionary).duplicate(true)
	high_scores = (_sandbox_snapshot["high_scores"] as Dictionary).duplicate(true)
	sp_session_scores = (_sandbox_snapshot["sp_session_scores"] as Array).duplicate(true)
	unlocked_content = (_sandbox_snapshot["unlocked"] as Dictionary).duplicate(true)
	achievements = (_sandbox_snapshot["achievements"] as Dictionary).duplicate(true)
	_play_time_carry = float(_sandbox_snapshot["play_time_carry"])
	session_games_played = int(_sandbox_snapshot["session_games_played"])
	win_streak = int(_sandbox_snapshot["win_streak"])
	_sandbox_snapshot = {}
	# GameManager's own water_droplets mirror is parked and restored by
	# GameManager.exit_sandbox(). Deriving it from player_data here would also
	# "fix" a divergence that existed before the Lab was opened, which is a live
	# change the Lab has no business making.
	# Drop the Lab's wall-clock from the play-time ledger. _update_play_time() only
	# runs inside save_now(), which the sandbox refuses, so session_start_time was
	# left at the moment the Lab opened - the first real save after leaving would
	# otherwise bill every minute spent testing as time played.
	session_start_time = Time.get_unix_time_from_system()

func load_all_data() -> void:
	# Load game data
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(json_text) == OK:
				var data = json.get_data()
				if data is Dictionary:
					_merge_data(data)
					print("💾 Game data loaded")
	
	# Load settings
	_load_settings()
	
	data_loaded.emit()

func _merge_data(data: Dictionary) -> void:
	# Version check — reject incompatible save formats
	var file_version = data.get("save_version", data.get("player", {}).get("save_version", 0))
	if file_version > SAVE_VERSION:
		push_warning(
			"💾 Save file version %d is newer than supported %d — ignoring save"
			% [file_version, SAVE_VERSION]
		)
		return
	if file_version < SAVE_VERSION:
		print("💾 Migrating save from v%d to v%d" % [file_version, SAVE_VERSION])
		# Future migration logic goes here

	# This function is a trust boundary: `data` is whatever was on disk, and the
	# file is user-writable, hand-editable and may have been written by a build
	# that shaped a field differently. Each field is therefore checked for SHAPE
	# before it is installed, for two reasons measured in
	# tools/VerifySavePersistence.tscn:
	#
	#   * The member vars are statically typed, so `high_scores = data.high_scores`
	#     with an Array on the right does not merely store the wrong thing — it
	#     raises "Trying to assign value of type 'Array' to a variable of type
	#     'Dictionary'" and ABORTS THIS FUNCTION. Everything below the offending
	#     line (session scores, unlocked content, achievements, and the accessory
	#     back-fill) was then silently dropped while player_data, merged above,
	#     was kept: a half-loaded profile, which is worse than either accepting or
	#     rejecting the file.
	#   * JSON has a single number type, so every integer round-trips as a float
	#     (games_played 9 -> 9.0). total_play_time in particular feeds
	#     get_play_time_formatted()'s `total % 3600`, and GDScript's `%` is
	#     integer-only, so a loaded float armed a runtime error on that path.
	#
	# A rejected field falls back to its default and says so; it never takes the
	# rest of the save down with it.

	if data.has("player"):
		if data["player"] is Dictionary:
			for key in data["player"]:
				var value = data["player"][key]
				if key in INT_PLAYER_FIELDS:
					if value is float or value is int:
						player_data[key] = int(value)
					else:
						_reject("player.%s" % key, value, "a number")
					continue
				player_data[key] = value
		else:
			_reject("player", data["player"], "a Dictionary")

	if data.has("high_scores"):
		if data["high_scores"] is Dictionary:
			high_scores = _sanitized_high_scores(data["high_scores"])
		else:
			_reject("high_scores", data["high_scores"], "a Dictionary")

	if data.has("sp_session_scores"):
		if data["sp_session_scores"] is Array:
			sp_session_scores = _sanitized_session_scores(data["sp_session_scores"])
		else:
			_reject("sp_session_scores", data["sp_session_scores"], "an Array")

	if data.has("unlocked"):
		if data["unlocked"] is Dictionary:
			for key in data["unlocked"]:
				if data["unlocked"][key] is Array:
					unlocked_content[key] = data["unlocked"][key]
				else:
					_reject("unlocked.%s" % key, data["unlocked"][key], "an Array")
		else:
			_reject("unlocked", data["unlocked"], "a Dictionary")

	if data.has("achievements"):
		if data["achievements"] is Dictionary:
			for key in data["achievements"]:
				if not achievements.has(key):
					continue  # an achievement this build no longer defines
				var entry = data["achievements"][key]
				if entry is Dictionary:
					achievements[key].unlocked = bool(entry.get("unlocked", false))
				else:
					_reject("achievements.%s" % key, entry, "a Dictionary")
		else:
			_reject("achievements", data["achievements"], "a Dictionary")

	_ensure_accessory_defaults()
	_ensure_decoration_defaults()


## Field names inside `player` that the rest of the code reads as ints:
## total_play_time feeds an integer modulo, the others feed "%d" formatting and
## int-typed getters. JSON hands all of them back as floats.
const INT_PLAYER_FIELDS: PackedStringArray = [
	"save_version", "water_droplets", "games_played", "total_play_time", "current_level"
]


func _reject(field: String, value: Variant, expected: String) -> void:
	push_warning("💾 Save field \"%s\" is %s, expected %s — keeping the default"
		% [field, type_string(typeof(value)), expected])


## Drop malformed per-game records and put the numeric fields back on the types
## their readers assume: score/times_played are counted and formatted as ints,
## accuracy/best_time are compared as floats.
func _sanitized_high_scores(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for game_id in raw:
		var record = raw[game_id]
		if not record is Dictionary:
			_reject("high_scores.%s" % str(game_id), record, "a Dictionary")
			continue
		out[str(game_id)] = {
			"score": int(record.get("score", 0)),
			"accuracy": float(record.get("accuracy", 0.0)),
			"best_time": float(record.get("best_time", 999.0)),
			"times_played": int(record.get("times_played", 0)),
		}
	return out


## The leaderboard readers sort these and format them with "%d"; a non-numeric
## entry would sort as 0 and render as a silent phantom run, so it is dropped.
func _sanitized_session_scores(raw: Array) -> Array:
	var out: Array = []
	for score in raw:
		if score is float or score is int:
			out.append(int(score))
		else:
			_reject("sp_session_scores entry", score, "a number")
	return out


func _ensure_accessory_defaults() -> void:
	if not player_data.has("selected_accessory"):
		player_data["selected_accessory"] = "character_default"

	if not player_data.has("character_accessories"):
		player_data["character_accessories"] = {}

	if not unlocked_content.has("accessories"):
		unlocked_content["accessories"] = ["character_default"]

	if "character_default" not in unlocked_content["accessories"]:
		unlocked_content["accessories"].append("character_default")

	var selected = str(player_data.get("selected_accessory", "character_default"))
	if selected not in unlocked_content["accessories"]:
		player_data["selected_accessory"] = "character_default"

func _save_settings() -> void:
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(json_text) == OK:
				var data = json.get_data()
				if data is Dictionary:
					for key in data:
						settings[key] = data[key]

## Bank the wall-clock time since the last call.
##
## Two things this has to get right. First, session_start_time is a FLOAT: it used
## to be an int re-based with int(current_time) while the elapsed time was measured
## from the un-truncated now, so every call re-charged frac(now) — mean 0.5 s of
## play time that never happened, on every save_now() and on both _notification()
## branches. tools/VerifySavePersistence.tscn measured 40 saves inside one frame
## inventing 19.2 s.
##
## Second, total_play_time stays an INT: `int += float` retyped the field, and
## get_play_time_formatted()'s `total % 3600` is GDScript's integer-only modulo, so
## the first save of a session armed a runtime error there. Whole seconds are banked
## and the sub-second remainder is carried, because repeated saves inside the same
## second would otherwise each round down to zero and lose the time for good.
func _update_play_time() -> void:
	var current_time := Time.get_unix_time_from_system()
	var session_duration := current_time - session_start_time
	session_start_time = current_time
	if session_duration <= 0.0:
		# A backwards clock jump (NTP correction, or the player changing the device
		# clock) must not subtract from a recorded total.
		return
	_play_time_carry += session_duration
	var whole := int(_play_time_carry)
	if whole > 0:
		_play_time_carry -= float(whole)
		player_data.total_play_time = int(player_data.get("total_play_time", 0)) + whole

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HIGH SCORES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func record_game_result(game_id: String, score: int, accuracy: float, time_seconds: float) -> bool:
	# Record game result and return true if it's a new high score.
	#
	# Game Lab: refused outright rather than left to sandbox_restore(). The
	# rollback is the backstop for writers nobody guarded; a writer we KNOW a round
	# reaches is guarded here so the high-score table and games_played counter are
	# never even briefly wrong on screen (the shop and the leaderboard read them
	# live, from inside the same sandbox session).
	if GameManager and GameManager.sandbox_mode:
		return false

	var is_new_record := false
	
	if not high_scores.has(game_id):
		high_scores[game_id] = {
			"score": 0,
			"accuracy": 0.0,
			"best_time": 999.0,
			"times_played": 0
		}
	
	var record = high_scores[game_id]
	record.times_played += 1
	
	if score > record.score:
		record.score = score
		is_new_record = true
	
	if accuracy > record.accuracy:
		record.accuracy = accuracy
		is_new_record = true
	
	if time_seconds < record.best_time and time_seconds > 0:
		record.best_time = time_seconds
		is_new_record = true
	
	# Update player stats
	player_data.games_played += 1
	session_games_played += 1
	
	# Check achievements
	_check_game_achievements(accuracy, time_seconds)
	
	# Auto-save
	save_all_data()
	
	return is_new_record

func record_sp_session_score(score: int) -> void:
	if score <= 0:
		return
	sp_session_scores.append(score)
	sp_session_scores.sort_custom(func(a, b): return int(a) > int(b))
	save_all_data()

func get_sp_session_scores(limit: int = 0) -> Array:
	var scores := sp_session_scores.duplicate()
	scores.sort_custom(func(a, b): return int(a) > int(b))
	if limit > 0 and scores.size() > limit:
		return scores.slice(0, limit)
	return scores

func get_sp_session_high_score() -> int:
	var best_score := 0
	for score in sp_session_scores:
		best_score = max(best_score, int(score))
	return best_score

func get_sp_session_leaderboard(limit: int = 0) -> Array:
	var entries: Array = []
	var scores := get_sp_session_scores(limit)
	for i in range(scores.size()):
		entries.append({
			"position": i + 1,
			"score": int(scores[i])
		})
	return entries

func get_high_score(game_id: String = "catch_rain") -> Dictionary:
	if high_scores.has(game_id):
		return high_scores[game_id]
	return { "score": 0, "accuracy": 0.0, "best_time": 999.0, "times_played": 0 }

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CURRENCY (Water Droplets)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func add_droplets(amount: int) -> void:
	if amount <= 0:
		return
	# Game Lab: same reason as record_game_result(). Droplets are spendable, and
	# the shop is reachable while the sandbox is still open.
	if GameManager and GameManager.sandbox_mode:
		return
	player_data.water_droplets += amount
	if GameManager:
		GameManager.water_droplets = player_data.water_droplets
	save_all_data()

func spend_droplets(amount: int) -> bool:
	if amount <= 0:
		return true
	if player_data.water_droplets >= amount:
		player_data.water_droplets -= amount
		if GameManager:
			GameManager.water_droplets = player_data.water_droplets
		save_all_data()
		return true
	return false

func get_droplets() -> int:
	return player_data.water_droplets

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UNLOCKABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func unlock_character(char_id: String) -> void:
	if char_id not in unlocked_content.characters:
		unlocked_content.characters.append(char_id)
		_check_collector_achievement()
		save_all_data()

func unlock_minigame(game_id: String) -> void:
	if game_id not in unlocked_content.minigames:
		unlocked_content.minigames.append(game_id)
		save_all_data()

func unlock_accessory(accessory_id: String) -> void:
	_ensure_accessory_defaults()
	if accessory_id not in unlocked_content.accessories:
		unlocked_content.accessories.append(accessory_id)
		save_all_data()

func is_character_unlocked(char_id: String) -> bool:
	return char_id in unlocked_content.characters

func is_minigame_unlocked(game_id: String) -> bool:
	return game_id in unlocked_content.minigames

func is_accessory_unlocked(accessory_id: String) -> bool:
	_ensure_accessory_defaults()
	return accessory_id in unlocked_content.accessories

func set_selected_character(char_id: String) -> void:
	if is_character_unlocked(char_id):
		player_data.selected_character = char_id
		save_all_data()

func set_selected_accessory(accessory_id: String) -> void:
	if is_accessory_unlocked(accessory_id):
		player_data["selected_accessory"] = accessory_id
		save_all_data()

func get_selected_character() -> String:
	return player_data.selected_character

func get_selected_accessory() -> String:
	_ensure_accessory_defaults()
	return str(player_data.get("selected_accessory", "character_default"))

func get_accessory_icon(accessory_id: String) -> String:
	var icon_map: Dictionary = {
		"character_default": "",
		"sun_hat": "👒",
		"cool_shades": "🕶️",
		"party_cap": "🎉",
		"leaf_crown": "🍃",
		"bow": "🎀",
		"safety_helmet": "⛑️",
	}
	return str(icon_map.get(accessory_id, ""))


func set_character_accessory(char_id: String, acc_id: String) -> void:
	_ensure_accessory_defaults()
	if not is_accessory_unlocked(acc_id):
		return
	player_data["character_accessories"][char_id] = acc_id
	# Also update the global selected_accessory for the active character
	if char_id == str(player_data.get("selected_character", "droppy_blue")):
		player_data["selected_accessory"] = acc_id
	save_all_data()


func get_character_accessory(char_id: String) -> String:
	_ensure_accessory_defaults()
	var ca = player_data.get("character_accessories", {})
	return str(ca.get(char_id, "character_default"))

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DECORATIONS (boat, furniture, etc.)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ensure_decoration_defaults() -> void:
	if not unlocked_content.has("decorations"):
		unlocked_content["decorations"] = []
	if not player_data.has("enabled_decorations"):
		player_data["enabled_decorations"] = []

func unlock_decoration(dec_id: String) -> void:
	_ensure_decoration_defaults()
	if dec_id not in unlocked_content.decorations:
		unlocked_content.decorations.append(dec_id)
		save_all_data()

func is_decoration_unlocked(dec_id: String) -> bool:
	_ensure_decoration_defaults()
	return dec_id in unlocked_content.decorations

func toggle_decoration(dec_id: String, enabled: bool) -> void:
	_ensure_decoration_defaults()
	var arr: Array = player_data.enabled_decorations
	if enabled and dec_id not in arr:
		arr.append(dec_id)
	elif not enabled and dec_id in arr:
		arr.erase(dec_id)
	save_all_data()

func is_decoration_enabled(dec_id: String) -> bool:
	_ensure_decoration_defaults()
	return dec_id in player_data.get(
		"enabled_decorations", []
	)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ACHIEVEMENTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func unlock_achievement(achievement_id: String) -> void:
	if achievements.has(achievement_id) and not achievements[achievement_id].unlocked:
		achievements[achievement_id].unlocked = true
		achievement_unlocked.emit(achievement_id)
		print("🏆 Achievement unlocked: " + achievements[achievement_id].name)
		save_all_data()

func is_achievement_unlocked(achievement_id: String) -> bool:
	if achievements.has(achievement_id):
		return achievements[achievement_id].unlocked
	return false

func get_achievement(achievement_id: String) -> Dictionary:
	return achievements.get(achievement_id, {})

func get_all_achievements() -> Dictionary:
	return achievements

func get_unlocked_count() -> int:
	var count := 0
	for id in achievements:
		if achievements[id].unlocked:
			count += 1
	return count

func _check_game_achievements(accuracy: float, time_seconds: float) -> void:
	# First Drop
	if player_data.games_played == 1:
		unlock_achievement("first_drop")
	
	# Perfect Game
	if accuracy >= 1.0:
		unlock_achievement("perfect_game")
	
	# Speed Demon
	if time_seconds < 30.0 and time_seconds > 0:
		unlock_achievement("speed_demon")
	
	# Persistent (10 games in session)
	if session_games_played >= 10:
		unlock_achievement("persistent")

func _check_collector_achievement() -> void:
	if unlocked_content.characters.size() >= 5:
		unlock_achievement("collector")

func record_win() -> void:
	win_streak += 1
	if win_streak >= 3:
		unlock_achievement("streak_3")
	if win_streak >= 5:
		unlock_achievement("streak_5")

func record_loss() -> void:
	win_streak = 0

func record_water_saved(liters: float) -> void:
	player_data.total_water_saved += liters
	
	if player_data.total_water_saved >= 100:
		unlock_achievement("water_saver")
	if player_data.total_water_saved >= 1000:
		unlock_achievement("eco_warrior")

func record_coop_win() -> void:
	unlock_achievement("coop_star")

func record_difficulty_reached(difficulty: String) -> void:
	if difficulty == "Hard":
		unlock_achievement("master")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SETTINGS HELPERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_save_settings()
	if key == "fullscreen":
		_apply_fullscreen_setting()
	setting_changed.emit(key, value)

func get_setting(key: String, default: Variant = null) -> Variant:
	return settings.get(key, default)

func is_colorblind_mode() -> bool:
	return settings.colorblind_mode

func is_large_touch_targets() -> bool:
	return settings.large_touch_targets

func is_audio_cues_enabled() -> bool:
	return settings.audio_cues

func is_screen_shake_enabled() -> bool:
	return settings.screen_shake

func is_particles_enabled() -> bool:
	return settings.particles

func is_fullscreen_enabled() -> bool:
	return bool(settings.get("fullscreen", true))

func _apply_fullscreen_setting() -> void:
	# Mobile platforms are already fullscreen by design.
	if OS.get_name() in ["Android", "iOS"]:
		return

	var wants_fullscreen = is_fullscreen_enabled()
	var mode = DisplayServer.window_get_mode()
	var is_fullscreen_mode = (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)

	if wants_fullscreen and not is_fullscreen_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not wants_fullscreen and is_fullscreen_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATISTICS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_total_games_played() -> int:
	return player_data.games_played

func get_total_play_time() -> int:
	return int(player_data.get("total_play_time", 0))

func get_total_water_saved() -> float:
	return player_data.total_water_saved

func get_session_games_played() -> int:
	return session_games_played

func reset_session_stats() -> void:
	session_games_played = 0
	win_streak = 0
	session_start_time = Time.get_unix_time_from_system()
	# The unbanked remainder belongs to the stretch being reset, not the next one.
	_play_time_carry = 0.0

func get_play_time_formatted() -> String:
	# int() rather than trusting the stored type: GDScript % is integer-only, so a
	# float total (an older save, or a future writer) is a runtime error here.
	var total := int(player_data.get("total_play_time", 0))
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	return "%dh %dm" % [hours, minutes]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RESET (for testing)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func reset_all_data() -> void:
	# WARNING: Resets all player progress.
	player_data = {
		"save_version": SAVE_VERSION,
		"total_water_saved": 0,
		"water_droplets": 0,
		"games_played": 0,
		"total_play_time": 0,
		"current_level": 1,
		"selected_character": "droppy_blue",
		"selected_accessory": "character_default",
		"first_play_date": Time.get_datetime_string_from_system(),
		"last_play_date": Time.get_datetime_string_from_system()
	}
	
	high_scores = {}
	sp_session_scores = []
	
	unlocked_content = {
		"characters": ["droppy_blue"],
		"minigames": ["catch_rain", "pipe_puzzle"],
		"themes": ["default"],
		"accessories": ["character_default"],
		# Kept in step with the declaration above: without it the first
		# is_decoration_unlocked() call after a reset has no key to read.
		"decorations": []
	}
	
	for id in achievements:
		achievements[id].unlocked = false

	reset_session_stats()

	if GameManager:
		GameManager.high_score = 0
		GameManager.water_droplets = 0
		if GameManager.has_method("save_persistent_data"):
			GameManager.save_persistent_data()
	
	save_all_data()
	print("🗑️ All data reset")
