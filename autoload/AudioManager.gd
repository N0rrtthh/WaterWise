extends Node

## ═══════════════════════════════════════════════════════════════════
## AUDIOMANAGER.GD - Sound Effects and Music Manager
## ═══════════════════════════════════════════════════════════════════
## Handles:
## - Background music per game/scene
## - Sound effects for interactions
## - Volume control integration with settings
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUDIO BUSES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUDIO PLAYERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 8

# Current state
var current_music: String = ""
var music_volume: float = 0.8
var sfx_volume: float = 1.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SFX DEFINITIONS (procedural tones since no audio files)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum SFXType {
	CLICK,
	SUCCESS,
	FAILURE,
	BONUS,
	WARNING,
	WATER_SPLASH,
	WATER_DROP,
	COUNTDOWN,
	GAME_START,
	GAME_END,
	COLLECT,
	DAMAGE
}

# Frequency definitions for procedural audio
var sfx_definitions: Dictionary = {
	SFXType.CLICK: { "freq": 660, "duration": 0.05, "wave": "square" },
	SFXType.SUCCESS: { "freq": 880, "duration": 0.15, "wave": "sine" },
	SFXType.FAILURE: { "freq": 220, "duration": 0.3, "wave": "sine" },
	SFXType.BONUS: { "freq": 1320, "duration": 0.2, "wave": "sine" },
	SFXType.WARNING: { "freq": 440, "duration": 0.1, "wave": "square" },
	SFXType.WATER_SPLASH: { "freq": 200, "duration": 0.4, "wave": "noise" },
	SFXType.WATER_DROP: { "freq": 800, "duration": 0.1, "wave": "sine" },
	SFXType.COUNTDOWN: { "freq": 523, "duration": 0.1, "wave": "sine" },
	SFXType.GAME_START: { "freq": 440, "duration": 0.5, "wave": "arpeggio" },
	SFXType.GAME_END: { "freq": 330, "duration": 0.8, "wave": "arpeggio" },
	SFXType.COLLECT: { "freq": 1000, "duration": 0.08, "wave": "sine" },
	SFXType.DAMAGE: { "freq": 150, "duration": 0.2, "wave": "square" }
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	_setup_audio_players()
	_load_volume_settings()

func _setup_audio_players() -> void:
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	music_player.volume_db = linear_to_db(music_volume)
	add_child(music_player)
	
	# SFX players pool
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		sfx_players.append(player)

func _get_save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")

func _load_volume_settings() -> void:
	var save_mgr = _get_save_manager()
	if save_mgr:
		music_volume = save_mgr.get_setting("music_volume", 0.8)
		sfx_volume = save_mgr.get_setting("sfx_volume", 1.0)
	
	music_player.volume_db = linear_to_db(music_volume)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MUSIC CONTROL
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func play_music(music_id: String, fade_duration: float = 1.0) -> void:
	"""Play background music with crossfade"""
	if music_id == current_music and music_player.playing:
		return
	
	current_music = music_id
	
	# Fade out current music
	if music_player.playing:
		var fade_out_tween = create_tween()
		fade_out_tween.tween_property(music_player, "volume_db", -40.0, fade_duration / 2)
		await fade_out_tween.finished
	
	# Load and play new music (placeholder - would load from file)
	# For now, generate procedural ambient music
	var music_stream = _generate_ambient_music(music_id)
	music_player.stream = music_stream
	music_player.volume_db = -40.0
	music_player.play()
	
	# Fade in
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), fade_duration / 2)

func stop_music(fade_duration: float = 1.0) -> void:
	"""Stop music with fade out"""
	if not music_player.playing:
		return
	
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -40.0, fade_duration)
	tween.tween_callback(music_player.stop)
	current_music = ""

func _generate_ambient_music(_music_id: String) -> AudioStreamWAV:
	"""Generate simple procedural ambient music"""
	var sample_rate := 44100.0
	var duration := 10.0  # 10 second loop
	var num_samples := int(sample_rate * duration)
	
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = int(sample_rate)
	audio.stereo = false
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.loop_end = num_samples
	
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	# Simple ambient waves (water-like)
	for i in range(num_samples):
		var t := float(i) / sample_rate
		
		# Multiple layered sine waves for water ambience
		var sample := 0.0
		sample += sin(2.0 * PI * 100 * t) * 0.1  # Deep bass
		sample += sin(2.0 * PI * 150 * t + sin(t * 0.5)) * 0.08  # Modulated low
		sample += sin(2.0 * PI * 200 * t + sin(t * 2)) * 0.05  # Mid frequency ripple
		
		# Add gentle noise for water texture
		sample += (randf() - 0.5) * 0.02
		
		var sample_int := int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF
	
	audio.data = data
	return audio

func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)
	var save_mgr = _get_save_manager()
	if save_mgr:
		save_mgr.set_setting("music_volume", music_volume)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SFX PLAYBACK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func play_sfx(sfx_type: SFXType) -> void:
	"""Play a sound effect"""
	if sfx_volume <= 0:
		return
	
	if not sfx_definitions.has(sfx_type):
		return
	
	var player = _get_available_sfx_player()
	if not player:
		return
	
	var def = sfx_definitions[sfx_type]
	var stream = _generate_sfx(def.freq, def.duration, def.wave)
	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume)
	player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:
	"""Get an available SFX player from the pool"""
	for player in sfx_players:
		if not player.playing:
			return player
	# All busy, return first one (will interrupt)
	return sfx_players[0]

func _generate_sfx(frequency: float, duration: float, wave_type: String) -> AudioStreamWAV:
	"""Generate a procedural sound effect"""
	var sample_rate := 44100.0
	var num_samples := int(sample_rate * duration)
	
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = int(sample_rate)
	audio.stereo = false
	
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var envelope := 1.0 - (float(i) / float(num_samples))  # Fade out
		var sample := 0.0
		
		match wave_type:
			"sine":
				sample = sin(2.0 * PI * frequency * t)
			"square":
				sample = 1.0 if fmod(frequency * t, 1.0) < 0.5 else -1.0
			"noise":
				sample = (randf() - 0.5) * 2.0
				# Add some resonance
				sample += sin(2.0 * PI * frequency * t) * 0.3
			"arpeggio":
				# Play ascending notes
				var note_duration := duration / 4
				var note_index := int(t / note_duration)
				var freqs := [frequency, frequency * 1.25, frequency * 1.5, frequency * 2.0]
				if note_index < freqs.size():
					sample = sin(2.0 * PI * freqs[note_index] * t)
		
		sample *= envelope * 0.5
		var sample_int := int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF
	
	audio.data = data
	return audio

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	if SaveManager:
		SaveManager.set_setting("sfx_volume", sfx_volume)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONVENIENCE FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func play_click() -> void:
	play_sfx(SFXType.CLICK)

func play_success() -> void:
	play_sfx(SFXType.SUCCESS)

func play_failure() -> void:
	play_sfx(SFXType.FAILURE)

func play_bonus() -> void:
	play_sfx(SFXType.BONUS)

func play_water_splash() -> void:
	play_sfx(SFXType.WATER_SPLASH)

func play_water_drop() -> void:
	play_sfx(SFXType.WATER_DROP)

func play_countdown() -> void:
	play_sfx(SFXType.COUNTDOWN)

func play_game_start() -> void:
	play_sfx(SFXType.GAME_START)

func play_game_end() -> void:
	play_sfx(SFXType.GAME_END)

func play_collect() -> void:
	play_sfx(SFXType.COLLECT)

func play_damage() -> void:
	play_sfx(SFXType.DAMAGE)
