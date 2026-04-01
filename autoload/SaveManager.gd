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
	"first_play_date": "",
	"last_play_date": ""
}

# High Scores (per game)
var high_scores: Dictionary = {
	# "game_id": { "score": 0, "accuracy": 0.0, "best_time": 999 }
}

# Unlocked Content
var unlocked_content: Dictionary = {
	"characters": ["droppy_blue"],
	"minigames": ["catch_rain", "pipe_puzzle"],
	"themes": ["default"]
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
	"language": "en",
	"sfx_volume": 1.0,
	"music_volume": 0.8,
	"colorblind_mode": false,
	"large_touch_targets": false,
	"audio_cues": true,
	"screen_shake": true,
	"particles": true,
	"show_hints": true,
	"auto_difficulty": true
}

# Session tracking (not saved)
var session_games_played: int = 0
var win_streak: int = 0
var session_start_time: int = 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	load_all_data()
	session_start_time = int(Time.get_unix_time_from_system())
	
	# Set first play date if new player
	if player_data.first_play_date == "":
		player_data.first_play_date = Time.get_datetime_string_from_system()
	
	# Update last play date
	player_data.last_play_date = Time.get_datetime_string_from_system()

func _notification(what: int) -> void:
	# Auto-save when app closes
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_update_play_time()
		save_all_data()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SAVE/LOAD
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func save_all_data() -> void:
	_update_play_time()
	
	var save_data: Dictionary = {
		"player": player_data,
		"high_scores": high_scores,
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
	# Merge loaded data with defaults (handles missing keys from older saves).
	if data.has("player"):
		for key in data.player:
			player_data[key] = data.player[key]
	
	if data.has("high_scores"):
		high_scores = data.high_scores
	
	if data.has("unlocked"):
		for key in data.unlocked:
			unlocked_content[key] = data.unlocked[key]
	
	if data.has("achievements"):
		for key in data.achievements:
			if achievements.has(key):
				achievements[key].unlocked = data.achievements[key].get("unlocked", false)

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

func _update_play_time() -> void:
	var current_time = Time.get_unix_time_from_system()
	var session_duration = current_time - session_start_time
	player_data.total_play_time += session_duration
	session_start_time = int(current_time)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HIGH SCORES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func record_game_result(game_id: String, score: int, accuracy: float, time_seconds: float) -> bool:
	# Record game result and return true if it's a new high score.
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

func get_high_score(game_id: String) -> Dictionary:
	if high_scores.has(game_id):
		return high_scores[game_id]
	return { "score": 0, "accuracy": 0.0, "best_time": 999.0, "times_played": 0 }

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CURRENCY (Water Droplets)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func add_droplets(amount: int) -> void:
	player_data.water_droplets += amount
	if GameManager:
		GameManager.water_droplets = player_data.water_droplets

func spend_droplets(amount: int) -> bool:
	if player_data.water_droplets >= amount:
		player_data.water_droplets -= amount
		if GameManager:
			GameManager.water_droplets = player_data.water_droplets
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

func is_character_unlocked(char_id: String) -> bool:
	return char_id in unlocked_content.characters

func is_minigame_unlocked(game_id: String) -> bool:
	return game_id in unlocked_content.minigames

func set_selected_character(char_id: String) -> void:
	if is_character_unlocked(char_id):
		player_data.selected_character = char_id
		save_all_data()

func get_selected_character() -> String:
	return player_data.selected_character

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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATISTICS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_total_games_played() -> int:
	return player_data.games_played

func get_total_play_time() -> int:
	return player_data.total_play_time

func get_total_water_saved() -> float:
	return player_data.total_water_saved

func get_play_time_formatted() -> String:
	var total = player_data.total_play_time
	var hours = int(total / 3600)
	var minutes = int((total % 3600) / 60)
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
		"first_play_date": Time.get_datetime_string_from_system(),
		"last_play_date": Time.get_datetime_string_from_system()
	}
	
	high_scores = {}
	
	unlocked_content = {
		"characters": ["droppy_blue"],
		"minigames": ["catch_rain", "pipe_puzzle"],
		"themes": ["default"]
	}
	
	for id in achievements:
		achievements[id].unlocked = false
	
	save_all_data()
	print("🗑️ All data reset")
