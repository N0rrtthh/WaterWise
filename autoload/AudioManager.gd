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
	DAMAGE,
	TIMER_TICK,
	LIFE_LOST,
	COMBO,
	PAUSE,
	RESUME,
	WHOOSH,
	FANFARE,
	UI_HOVER,
	SCORE_TICK
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
	SFXType.DAMAGE: { "freq": 150, "duration": 0.2, "wave": "square" },
	SFXType.TIMER_TICK: { "freq": 900, "duration": 0.03, "wave": "sine" },
	SFXType.LIFE_LOST: { "freq": 180, "duration": 0.45, "wave": "arpeggio_down" },
	SFXType.COMBO: { "freq": 1100, "duration": 0.12, "wave": "arpeggio_up" },
	SFXType.PAUSE: { "freq": 350, "duration": 0.15, "wave": "sine" },
	SFXType.RESUME: { "freq": 500, "duration": 0.15, "wave": "sine" },
	SFXType.WHOOSH: { "freq": 300, "duration": 0.25, "wave": "whoosh" },
	SFXType.FANFARE: { "freq": 523, "duration": 1.0, "wave": "fanfare" },
	SFXType.UI_HOVER: { "freq": 1200, "duration": 0.025, "wave": "sine" },
	SFXType.SCORE_TICK: { "freq": 1400, "duration": 0.04, "wave": "sine" }
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
	# Play background music with crossfade
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
	# Stop music with fade out
	if not music_player.playing:
		return
	
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -40.0, fade_duration)
	tween.tween_callback(music_player.stop)
	current_music = ""

func _generate_ambient_music(music_id: String) -> AudioStreamWAV:
	# Generate procedural music that varies by scene type
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
	
	match music_id:
		"gameplay":
			_fill_gameplay_music(data, num_samples, sample_rate)
		"results":
			_fill_results_music(data, num_samples, sample_rate)
		"cutscene":
			_fill_cutscene_music(data, num_samples, sample_rate)
		_:
			_fill_menu_music(data, num_samples, sample_rate)
	
	audio.data = data
	return audio

func _fill_menu_music(data: PackedByteArray, num_samples: int, sample_rate: float) -> void:
	# Happy, bouncy, uplifting — DWTD-style cheerful main menu vibe
	# C major pentatonic in upper octave — bright and joyful
	var melody = [523.3, 587.3, 659.3, 784.0, 880.0, 784.0, 659.3, 784.0,
		880.0, 1047.0, 880.0, 784.0, 659.3, 587.3, 523.3, 659.3]
	var bass_notes = [130.8, 164.8, 174.6, 130.8]
	var beat_dur = sample_rate * 0.25  # Fast tempo (~240 BPM feel)
	var bass_dur = sample_rate * 1.0
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var mel_idx := int(float(i) / beat_dur) % melody.size()
		var bass_idx := int(float(i) / bass_dur) % bass_notes.size()
		var freq = melody[mel_idx]
		var bass_freq = bass_notes[bass_idx]
		var note_t = fmod(float(i), beat_dur) / beat_dur
		# Bouncy staccato envelope — short bright notes
		var envelope = maxf(0.0, 1.0 - note_t * 3.5) * 0.7
		# Sub-beat bounce accent
		var bounce_accent = 1.0 + 0.3 * maxf(0.0, 1.0 - note_t * 8.0)

		var sample := 0.0
		# Bright melody (sine + slight square character)
		sample += sin(2.0 * PI * freq * t) * 0.11 * envelope * bounce_accent
		sample += sin(2.0 * PI * freq * 2.0 * t) * 0.04 * envelope  # Octave shimmer
		sample += sin(2.0 * PI * freq * 3.0 * t) * 0.015 * envelope  # Harmonics sparkle
		# Bouncy bass — short punchy
		var bass_t = fmod(float(i), bass_dur) / bass_dur
		var bass_env = maxf(0.0, 1.0 - bass_t * 4.0) * 0.8
		sample += sin(2.0 * PI * bass_freq * t) * 0.10 * bass_env
		# Upbeat rhythm clap/snap — every half beat
		var half_t = fmod(float(i), beat_dur * 0.5) / (beat_dur * 0.5)
		var clap_env = maxf(0.0, 1.0 - half_t * 15.0) * 0.4
		sample += (randf() - 0.5) * 0.04 * clap_env
		# Cheerful chord pad (major triad, soft sustain)
		var pad_env = 0.35 + 0.15 * sin(t * 1.2)
		sample += sin(2.0 * PI * 261.6 * t) * 0.025 * pad_env
		sample += sin(2.0 * PI * 329.6 * t) * 0.02 * pad_env
		sample += sin(2.0 * PI * 392.0 * t) * 0.02 * pad_env

		var sample_int := int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

func _fill_gameplay_music(data: PackedByteArray, num_samples: int, sample_rate: float) -> void:
	# Upbeat, driving rhythm — energetic like DWTD gameplay
	var bass_line = [130.8, 130.8, 164.8, 146.8, 130.8, 174.6, 164.8, 146.8]
	var beat_samples = int(sample_rate * 0.3125)
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var beat_idx: int = (i / beat_samples) % bass_line.size()
		var bass_freq: float = bass_line[beat_idx]
		var beat_phase = fmod(float(i), float(beat_samples)) / float(beat_samples)
		
		var sample := 0.0
		var bass_env = maxf(0, 1.0 - beat_phase * 3.0)
		sample += sin(2.0 * PI * bass_freq * t) * 0.15 * bass_env
		var kick_env = maxf(0, 1.0 - beat_phase * 8.0)
		sample += sin(2.0 * PI * (60.0 - beat_phase * 40.0) * t) * 0.12 * kick_env
		var half_beat = fmod(float(i), float(beat_samples / 2)) / float(beat_samples / 2)
		var hat_env = maxf(0, 1.0 - half_beat * 12.0)
		sample += (randf() - 0.5) * 0.06 * hat_env
		var arp_notes = [523.3, 659.3, 784.0, 659.3]
		var arp_idx: int = (i / (beat_samples / 2)) % arp_notes.size()
		var arp_freq: float = arp_notes[arp_idx]
		var arp_env = maxf(0, 1.0 - half_beat * 2.5) * 0.5
		sample += sin(2.0 * PI * arp_freq * t) * 0.06 * arp_env
		
		var sample_int := int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

func _fill_results_music(data: PackedByteArray, num_samples: int, sample_rate: float) -> void:
	# Triumphant, warm — score reveal feel
	var chord_notes = [
		[261.6, 329.6, 392.0],
		[293.7, 370.0, 440.0],
		[329.6, 415.3, 493.9],
		[349.2, 440.0, 523.3],
	]
	var chord_dur = sample_rate * 2.5
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var chord_idx := int(float(i) / chord_dur) % chord_notes.size()
		var chord = chord_notes[chord_idx]
		var chord_t = fmod(float(i), chord_dur) / chord_dur
		var envelope = sin(chord_t * PI) * 0.5
		
		var sample := 0.0
		for note in chord:
			sample += sin(2.0 * PI * note * t) * 0.07 * envelope
			sample += sin(2.0 * PI * note * 0.5 * t) * 0.04 * envelope
		if fmod(t, 0.625) < 0.05:
			sample += sin(2.0 * PI * 1318.5 * t) * 0.03
		sample += sin(2.0 * PI * 130.8 * t) * 0.06 * (0.6 + 0.4 * sin(t * 0.5))
		
		var sample_int := int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

func _fill_cutscene_music(data: PackedByteArray, num_samples: int, sample_rate: float) -> void:
	# Dramatic, cinematic — tension/reveal for cutscene moments
	var tension_notes = [130.8, 155.6, 164.8, 196.0, 164.8, 155.6, 146.8, 130.8]
	var note_dur = sample_rate * 1.25
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var note_idx := int(float(i) / note_dur) % tension_notes.size()
		var freq = tension_notes[note_idx]
		var note_phase = fmod(float(i), note_dur) / note_dur
		var envelope = sin(note_phase * PI)
		
		var sample := 0.0
		sample += sin(2.0 * PI * freq * t) * 0.10 * envelope
		sample += sin(2.0 * PI * freq * 1.5 * t) * 0.04 * envelope
		sample += sin(2.0 * PI * 65.4 * t) * 0.08 * (0.5 + 0.5 * sin(t * 0.3))
		sample += sin(2.0 * PI * freq * 4.0 * t) * 0.015 * envelope * sin(t * 2.0)
		sample += (randf() - 0.5) * 0.018 * (0.4 + 0.6 * sin(t * 0.7))
		
		var sample_int := int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

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
	# Play a sound effect
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
	# Get an available SFX player from the pool
	for player in sfx_players:
		if not player.playing:
			return player
	# All busy, return first one (will interrupt)
	return sfx_players[0]

func _generate_sfx(frequency: float, duration: float, wave_type: String) -> AudioStreamWAV:
	# Generate a procedural sound effect
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
			"arpeggio_down":
				var nd := duration / 3
				var ni := int(t / nd)
				var df := [frequency, frequency * 0.75, frequency * 0.5]
				if ni < df.size():
					sample = sin(2.0 * PI * df[ni] * t)
			"arpeggio_up":
				var nd2 := duration / 3
				var ni2 := int(t / nd2)
				var uf := [frequency, frequency * 1.33, frequency * 1.67]
				if ni2 < uf.size():
					sample = sin(2.0 * PI * uf[ni2] * t)
			"whoosh":
				var sweep_freq := lerpf(frequency * 2.0, frequency * 0.3, float(i) / float(num_samples))
				sample = (randf() - 0.5) * 0.6 + sin(2.0 * PI * sweep_freq * t) * 0.4
			"fanfare":
				var fn_dur := duration / 6
				var fn_idx := int(t / fn_dur)
				var fn_notes := [frequency, frequency, frequency * 1.25, frequency * 1.5, frequency * 1.5, frequency * 2.0]
				if fn_idx < fn_notes.size():
					sample = sin(2.0 * PI * fn_notes[fn_idx] * t) * 0.8 + sin(2.0 * PI * fn_notes[fn_idx] * 2.0 * t) * 0.2
		
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

func play_warning() -> void:
	play_sfx(SFXType.WARNING)

func play_timer_tick() -> void:
	play_sfx(SFXType.TIMER_TICK)

func play_life_lost() -> void:
	play_sfx(SFXType.LIFE_LOST)

func play_combo() -> void:
	play_sfx(SFXType.COMBO)

func play_pause() -> void:
	play_sfx(SFXType.PAUSE)

func play_resume() -> void:
	play_sfx(SFXType.RESUME)

func play_whoosh() -> void:
	play_sfx(SFXType.WHOOSH)

func play_fanfare() -> void:
	play_sfx(SFXType.FANFARE)

func play_ui_hover() -> void:
	play_sfx(SFXType.UI_HOVER)

func play_score_tick() -> void:
	play_sfx(SFXType.SCORE_TICK)
