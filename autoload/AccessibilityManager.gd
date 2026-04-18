extends Node

## ═══════════════════════════════════════════════════════════════════
## ACCESSIBILITYMANAGER.GD - Accessibility Features for WaterWise
## ═══════════════════════════════════════════════════════════════════
## Provides:
## - Colorblind-friendly indicators
## - Larger touch targets for mobile
## - Audio cues for visual feedback
## - High contrast mode
## - Reduced motion options
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal colorblind_mode_changed(enabled: bool)
signal large_targets_changed(enabled: bool)
signal audio_cues_changed(enabled: bool)
signal particles_changed(enabled: bool)
signal screen_shake_changed(enabled: bool)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COLORBLIND PALETTES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum ColorblindType {
	NONE,
	DEUTERANOPIA,  # Red-green (most common)
	PROTANOPIA,    # Red-green 
	TRITANOPIA     # Blue-yellow (rare)
}

# Standard colors
var standard_colors: Dictionary = {
	"good": Color(0.2, 0.8, 0.3),      # Green
	"bad": Color(0.9, 0.2, 0.2),       # Red
	"warning": Color(1.0, 0.8, 0.2),   # Yellow
	"neutral": Color(0.3, 0.6, 1.0),   # Blue
	"bonus": Color(0.8, 0.4, 1.0)      # Purple
}

# Colorblind-safe palettes (high contrast, pattern-supported)
var colorblind_colors: Dictionary = {
	"good": Color(0.0, 0.45, 0.7),     # Blue (instead of green)
	"bad": Color(0.9, 0.6, 0.0),       # Orange (instead of red)
	"warning": Color(0.95, 0.9, 0.25), # Bright yellow
	"neutral": Color(0.35, 0.7, 0.9),  # Light blue
	"bonus": Color(0.8, 0.4, 0.0)      # Dark orange
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SETTINGS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var colorblind_mode: bool = false
var colorblind_type: ColorblindType = ColorblindType.DEUTERANOPIA
var large_touch_targets: bool = false
var audio_cues_enabled: bool = true
var reduced_motion: bool = false
var high_contrast: bool = false
var particles_enabled: bool = true
var screen_shake_enabled: bool = true
var _last_scene: Node = null

# Touch target sizes
const NORMAL_TARGET_SIZE: float = 50.0
const LARGE_TARGET_SIZE: float = 80.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUDIO CUES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Sound frequencies for different events (Hz)
var audio_cues: Dictionary = {
	"success": { "freq": 880, "duration": 0.15 },      # A5 - high, happy
	"failure": { "freq": 220, "duration": 0.3 },       # A3 - low, sad
	"warning": { "freq": 440, "duration": 0.1 },       # A4 - middle, alert
	"click": { "freq": 660, "duration": 0.05 },        # E5 - quick click
	"bonus": { "freq": 1320, "duration": 0.2 },        # E6 - very high, exciting
	"countdown": { "freq": 523, "duration": 0.1 }      # C5 - tick
}

var audio_player: AudioStreamPlayer

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _get_save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")

func _ready() -> void:
	_load_settings()
	_setup_audio_player()
	_connect_scene_events()
	call_deferred("_apply_particles_to_current_scene")

func _load_settings() -> void:
	var save_mgr = _get_save_manager()
	if save_mgr:
		colorblind_mode = save_mgr.get_setting("colorblind_mode", false)
		large_touch_targets = save_mgr.get_setting("large_touch_targets", false)
		audio_cues_enabled = save_mgr.get_setting("audio_cues", true)
		reduced_motion = save_mgr.get_setting("reduced_motion", false)
		high_contrast = save_mgr.get_setting("high_contrast", false)
		particles_enabled = save_mgr.get_setting("particles", true)
		screen_shake_enabled = save_mgr.get_setting("screen_shake", true)

func _setup_audio_player() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COLOR FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_color(color_type: String) -> Color:
	"""Get appropriate color based on accessibility settings"""
	if colorblind_mode:
		return colorblind_colors.get(color_type, Color.WHITE)
	return standard_colors.get(color_type, Color.WHITE)

func get_good_color() -> Color:
	return get_color("good")

func get_bad_color() -> Color:
	return get_color("bad")

func get_warning_color() -> Color:
	return get_color("warning")

func get_neutral_color() -> Color:
	return get_color("neutral")

func get_bonus_color() -> Color:
	return get_color("bonus")

func set_colorblind_mode(enabled: bool) -> void:
	colorblind_mode = enabled
	var save_mgr = _get_save_manager()
	if save_mgr:
		save_mgr.set_setting("colorblind_mode", enabled)
	colorblind_mode_changed.emit(enabled)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SHAPE INDICATORS (for colorblind support)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_indicator_shape(is_good: bool) -> PackedVector2Array:
	"""Get shape indicator for colorblind users"""
	if is_good:
		# Checkmark shape ✓
		return PackedVector2Array([
			Vector2(-10, 0),
			Vector2(-3, 8),
			Vector2(10, -8)
		])
	else:
		# X shape ✗
		return PackedVector2Array([
			Vector2(-8, -8),
			Vector2(0, 0),
			Vector2(-8, 8),
			Vector2(0, 0),
			Vector2(8, -8),
			Vector2(0, 0),
			Vector2(8, 8)
		])

func create_indicator_node(is_good: bool) -> Node2D:
	"""Create a shape indicator node"""
	var indicator = Node2D.new()
	
	var line = Line2D.new()
	line.points = get_indicator_shape(is_good)
	line.width = 3
	line.default_color = get_color("good") if is_good else get_color("bad")
	
	indicator.add_child(line)
	return indicator

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TOUCH TARGETS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_touch_target_size() -> float:
	"""Get appropriate touch target size"""
	return LARGE_TARGET_SIZE if large_touch_targets else NORMAL_TARGET_SIZE

func set_large_touch_targets(enabled: bool) -> void:
	large_touch_targets = enabled
	var save_mgr = _get_save_manager()
	if save_mgr:
		save_mgr.set_setting("large_touch_targets", enabled)
	large_targets_changed.emit(enabled)

func apply_touch_target_to_button(button: Button) -> void:
	"""Apply appropriate touch target size to a button"""
	var size = get_touch_target_size()
	button.custom_minimum_size = Vector2(size, size)

func apply_touch_targets_to_container(container: Node) -> void:
	"""Apply touch targets to all buttons in a container"""
	for child in container.get_children():
		if child is Button:
			apply_touch_target_to_button(child)
		elif child.get_child_count() > 0:
			apply_touch_targets_to_container(child)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUDIO CUES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func play_audio_cue(cue_type: String) -> void:
	"""Play an audio cue for accessibility"""
	if not audio_cues_enabled:
		return
	
	if not audio_cues.has(cue_type):
		return
	
	var cue = audio_cues[cue_type]
	_play_tone(cue.freq, cue.duration)

func _play_tone(frequency: float, duration: float) -> void:
	"""Generate and play a simple tone"""
	var sample_rate := 44100.0
	var num_samples := int(sample_rate * duration)
	
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = int(sample_rate)
	audio.stereo = false
	
	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit = 2 bytes per sample
	
	for i in range(num_samples):
		var t := float(i) / sample_rate
		# Sine wave with fade out
		var fade := 1.0 - (float(i) / float(num_samples))
		var sample := sin(2.0 * PI * frequency * t) * fade * 0.3
		var sample_int := int(sample * 32767)
		
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF
	
	audio.data = data
	audio_player.stream = audio
	audio_player.play()

func play_success_cue() -> void:
	play_audio_cue("success")

func play_failure_cue() -> void:
	play_audio_cue("failure")

func play_warning_cue() -> void:
	play_audio_cue("warning")

func play_click_cue() -> void:
	play_audio_cue("click")

func play_bonus_cue() -> void:
	play_audio_cue("bonus")

func set_audio_cues_enabled(enabled: bool) -> void:
	audio_cues_enabled = enabled
	var save_mgr = _get_save_manager()
	if save_mgr:
		save_mgr.set_setting("audio_cues", enabled)
	audio_cues_changed.emit(enabled)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MOTION PREFERENCES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func should_reduce_motion() -> bool:
	return reduced_motion

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	var save_mgr = _get_save_manager()
	if save_mgr:
		save_mgr.set_setting("reduced_motion", enabled)
	_apply_particles_to_current_scene()

func get_animation_speed() -> float:
	"""Get animation speed multiplier (faster for reduced motion)"""
	return 3.0 if reduced_motion else 1.0

func should_show_particles() -> bool:
	"""Check if particles should be shown"""
	return is_particles_enabled() and not reduced_motion


func is_particles_enabled() -> bool:
	var save_mgr = _get_save_manager()
	if save_mgr:
		return bool(save_mgr.get_setting("particles", true))
	return particles_enabled


func set_particles_enabled(enabled: bool) -> void:
	particles_enabled = enabled
	var save_mgr = _get_save_manager()
	if save_mgr:
		save_mgr.set_setting("particles", enabled)
	_apply_particles_to_current_scene()
	particles_changed.emit(enabled)


func is_screen_shake_enabled() -> bool:
	var save_mgr = _get_save_manager()
	if save_mgr:
		return bool(save_mgr.get_setting("screen_shake", true)) and not reduced_motion
	return screen_shake_enabled and not reduced_motion


func set_screen_shake_enabled(enabled: bool) -> void:
	screen_shake_enabled = enabled
	var save_mgr = _get_save_manager()
	if save_mgr:
		save_mgr.set_setting("screen_shake", enabled)
	screen_shake_changed.emit(enabled)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HIGH CONTRAST
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func is_high_contrast() -> bool:
	return high_contrast

func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	var save_mgr = _get_save_manager()
	if save_mgr:
		save_mgr.set_setting("high_contrast", enabled)

func get_text_color() -> Color:
	"""Get appropriate text color for contrast"""
	return Color.WHITE if high_contrast else Color(0.1, 0.1, 0.1)

func get_background_color() -> Color:
	"""Get appropriate background color for contrast"""
	return Color.BLACK if high_contrast else Color(0.95, 0.95, 0.95)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func announce(text: String) -> void:
	"""Announce text for screen readers (future implementation)"""
	# This would integrate with OS accessibility APIs
	print("[Accessibility] " + text)
	
	# Play a notification sound
	if audio_cues_enabled:
		play_audio_cue("click")

func create_accessible_button(text: String, icon: String = "") -> Button:
	"""Create a button with accessibility features"""
	var btn = Button.new()
	btn.text = icon + " " + text if icon else text
	
	apply_touch_target_to_button(btn)
	
	# High contrast styling
	if high_contrast:
		var style = StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.border_color = Color.BLACK
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", Color.BLACK)
	
	# Connect audio cue
	btn.pressed.connect(play_click_cue)
	
	return btn


func _connect_scene_events() -> void:
	if get_tree().has_signal("current_scene_changed"):
		if not get_tree().is_connected("current_scene_changed", _on_current_scene_changed):
			get_tree().connect("current_scene_changed", _on_current_scene_changed)
	else:
		get_tree().tree_changed.connect(_on_tree_changed)


func _on_current_scene_changed(_scene_root: Node) -> void:
	call_deferred("_apply_particles_to_current_scene")


func _on_tree_changed() -> void:
	var tree = get_tree()
	if not tree:
		return
	var current = tree.current_scene
	if current != _last_scene:
		_last_scene = current
		if current != null:
			call_deferred("_apply_particles_to_current_scene")


func _apply_particles_to_current_scene() -> void:
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	apply_particles_to_tree(current_scene, should_show_particles())


func apply_particles_to_tree(root: Node, allow_particles: bool) -> void:
	if not root:
		return
	_apply_particles_recursive(root, allow_particles)


func _apply_particles_recursive(node: Node, allow_particles: bool) -> void:
	if node is GPUParticles2D or node is CPUParticles2D:
		_apply_particle_node_state(node, allow_particles)

	for child in node.get_children():
		_apply_particles_recursive(child, allow_particles)


func _apply_particle_node_state(particle_node: Node, allow_particles: bool) -> void:
	if not (particle_node is CanvasItem):
		return

	var item = particle_node as CanvasItem

	if not allow_particles:
		if not particle_node.has_meta("_acc_prev_emitting"):
			particle_node.set_meta("_acc_prev_emitting", bool(particle_node.get("emitting")))
		if not particle_node.has_meta("_acc_prev_visible"):
			particle_node.set_meta("_acc_prev_visible", item.visible)
		particle_node.set("emitting", false)
		item.visible = false
		return

	item.visible = bool(particle_node.get_meta("_acc_prev_visible", true))
	if particle_node.has_meta("_acc_prev_emitting"):
		particle_node.set("emitting", bool(particle_node.get_meta("_acc_prev_emitting")))
