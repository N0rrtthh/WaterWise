class_name AnimatedCutscenePlayer
extends Control

## Main orchestrator for animated cutscene playback
##
## This component coordinates all cutscene elements:
## - Configuration loading with fallback hierarchy
## - Character lifecycle management
## - Animation playback via AnimationEngine
## - Particle and audio synchronization
## - Completion signaling

signal cutscene_finished()

# Configuration paths
const CONFIG_BASE_PATH = "res://data/cutscenes/"
const DEFAULT_CONFIG_PATH = "res://data/cutscenes/default/"

# Character scene (with error handling for missing asset)
const CHARACTER_SCENE_PATH = "res://scenes/cutscenes/WaterDropletCharacter.tscn"
var _character_scene: PackedScene = null

# Asset preloading and caching
static var _animation_cache: Dictionary = {}  # minigame_key -> {type -> CutsceneConfig}
static var _texture_cache: Dictionary = {}  # texture_path -> Texture2D
static var _particle_scene_cache: Dictionary = {}  # particle_type -> PackedScene

# Object pooling for particle effects
static var _particle_pool: Dictionary = {}  # particle_type -> Array[GPUParticles2D]
const MAX_POOL_SIZE_PER_TYPE = 5

# State
var _current_character: WaterDropletCharacter = null
var _current_tween: Tween = null
var _background_tween: Tween = null
var _is_playing: bool = false
var _active_particles: Array[GPUParticles2D] = []
var _active_text_overlays: Array[AnimatedTextOverlay] = []
var _scheduled_timers: Array[SceneTreeTimer] = []

# Background (created dynamically if not in scene)
var _background: ColorRect = null


func _ready() -> void:
	# Ensure background exists
	if has_node("Background"):
		_background = get_node("Background")
	else:
		_background = ColorRect.new()
		_background.name = "Background"
		_background.anchors_preset = Control.PRESET_FULL_RECT
		_background.color = Color(0.039, 0.118, 0.059)  # Default #0a1e0f
		add_child(_background)
		move_child(_background, 0)
	
	# Ensure placeholder assets exist before trying to load character scene
	var assets_script = load("res://scripts/cutscenes/create_placeholder_assets_runtime.gd")
	if assets_script:
		assets_script.ensure_assets_exist()
	
	# Try to load character scene (with error handling)
	_load_character_scene()


## Play a cutscene for a specific minigame and outcome
## @param minigame_key: Unique identifier for the minigame
## @param cutscene_type: Type of cutscene (INTRO, WIN, FAIL)
## @param options: Optional parameters (currently unused, for future expansion)
func play_cutscene(
	minigame_key: String,
	cutscene_type: CutsceneTypes.CutsceneType,
	_options: Dictionary = {}
) -> void:
	var force_legacy: bool = bool(_options.get("force_legacy", false))
	if force_legacy:
		await _fallback_to_legacy_cutscene(minigame_key, cutscene_type)
		cutscene_finished.emit()
		return

	if _is_playing:
		push_warning("[AnimatedCutscenePlayer] Cutscene already playing, ignoring request")
		return
	
	_is_playing = true
	
	# Check if character assets are available (Requirement 12.2)
	if not _can_use_animated_cutscene():
		push_error("[AnimatedCutscenePlayer] Character assets not available for " + minigame_key + 
			" (type: " + _cutscene_type_to_string(cutscene_type) + "). " +
			"Falling back to legacy emoji cutscene.")
		await _fallback_to_legacy_cutscene(minigame_key, cutscene_type)
		_is_playing = false
		cutscene_finished.emit()
		return
	
	# Load configuration with error handling
	var cutscene_config = _load_config(minigame_key, cutscene_type)
	if not cutscene_config:
		push_error("[AnimatedCutscenePlayer] Failed to load configuration for " + minigame_key + 
			" (type: " + _cutscene_type_to_string(cutscene_type) + "). " +
			"Using minimal default configuration to prevent blocking game progression.")
		# Create minimal config as last resort fallback
		cutscene_config = _create_minimal_config(minigame_key, cutscene_type)
	
	# Validate configuration with fallback to defaults for invalid fields
	var validation = CutsceneParser.validate_config(cutscene_config)
	if validation.has_errors():
		push_warning(
			"[AnimatedCutscenePlayer] Configuration validation found issues for " + minigame_key +
			" (type: " + _cutscene_type_to_string(cutscene_type) + "):\n" +
			validation.get_error_message() +
			"\nApplying default values for invalid fields to continue playback."
		)
		# Apply default values for invalid fields instead of failing
		cutscene_config = _apply_validation_defaults(cutscene_config, validation)
	
	# Set up scene
	_setup_cutscene(cutscene_config)
	
	# Play animation
	await _play_animation(cutscene_config)
	
	# Clean up
	_cleanup_cutscene()
	
	_is_playing = false
	cutscene_finished.emit()


## Preload cutscene assets for a minigame
## This method implements asset preloading to improve performance by:
## - Loading and caching cutscene configurations
## - Preloading character sprite textures
## - Preloading particle effect scenes
## - Caching animation data for quick access
## @param minigame_key: Unique identifier for the minigame
func preload_cutscene(minigame_key: String) -> void:
	# Preload texture atlas (only once)
	WaterDropletCharacter.preload_atlas()
	
	# Initialize cache entry for this minigame if not exists
	if not _animation_cache.has(minigame_key):
		_animation_cache[minigame_key] = {}
	
	# Preload all cutscene types for this minigame
	for cutscene_type in [
		CutsceneTypes.CutsceneType.INTRO,
		CutsceneTypes.CutsceneType.WIN,
		CutsceneTypes.CutsceneType.FAIL
	]:
		var preload_config = _load_config(minigame_key, cutscene_type)
		if preload_config:
			# Cache the configuration for quick access
			_animation_cache[minigame_key][cutscene_type] = preload_config
			
			# Preload character expression textures referenced in config
			_preload_character_textures(preload_config)
			
			# Preload particle effect scenes referenced in config
			_preload_particle_scenes(preload_config)


## Preload character expression textures from configuration
## @param config: The cutscene configuration
static func _preload_character_textures(config: CutsceneDataModels.CutsceneConfig) -> void:
	# Preload the expression texture for this cutscene
	var expression = config.character.expression
	var texture_path = WaterDropletCharacter.EXPRESSION_PATHS.get(expression, "")
	
	if texture_path and not _texture_cache.has(texture_path):
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			if texture:
				_texture_cache[texture_path] = texture
		else:
			push_warning(
				"[AnimatedCutscenePlayer] Expression texture not found " +
				"during preload: " + texture_path
			)


## Preload particle effect scenes from configuration
## @param config: The cutscene configuration
static func _preload_particle_scenes(config: CutsceneDataModels.CutsceneConfig) -> void:
	for particle in config.particles:
		var particle_type = particle.type
		
		# Skip if already cached
		if _particle_scene_cache.has(particle_type):
			continue
		
		var scene_path = WaterDropletCharacter.PARTICLE_SCENES.get(particle_type, "")
		if scene_path and ResourceLoader.exists(scene_path):
			var scene = load(scene_path)
			if scene:
				_particle_scene_cache[particle_type] = scene
		else:
			push_warning(
				"[AnimatedCutscenePlayer] Particle scene not found during preload: " + scene_path
			)


## Check if a custom cutscene exists for a minigame
## @param minigame_key: Unique identifier for the minigame
## @param cutscene_type: Type of cutscene to check
## @return: True if custom cutscene exists, false otherwise
func has_custom_cutscene(minigame_key: String, cutscene_type: CutsceneTypes.CutsceneType) -> bool:
	var custom_path = _get_config_path(minigame_key, cutscene_type)
	return FileAccess.file_exists(custom_path)


## Get a particle effect from the object pool or create a new one
## @param particle_type: The type of particle effect to get
## @return: A GPUParticles2D instance, or null if scene not found
static func _get_pooled_particle(particle_type: CutsceneTypes.ParticleType) -> GPUParticles2D:
	# Initialize pool for this type if needed
	if not _particle_pool.has(particle_type):
		_particle_pool[particle_type] = []
	
	var pool = _particle_pool[particle_type]
	
	# Try to reuse from pool
	while not pool.is_empty():
		var particle = pool.pop_back()
		if is_instance_valid(particle):
			# Reset particle state
			particle.emitting = false
			particle.restart()
			return particle
	
	# No available particles in pool, create new one
	var scene_path = WaterDropletCharacter.PARTICLE_SCENES.get(particle_type, "")
	if not scene_path or not ResourceLoader.exists(scene_path):
		push_warning("[AnimatedCutscenePlayer] Particle scene not found: " + str(particle_type))
		return null
	
	# Load from cache or disk
	var particle_scene: PackedScene
	if _particle_scene_cache.has(particle_type):
		particle_scene = _particle_scene_cache[particle_type]
	else:
		particle_scene = load(scene_path)
		_particle_scene_cache[particle_type] = particle_scene
	
	if not particle_scene:
		return null
	
	return particle_scene.instantiate()


## Return a particle effect to the object pool for reuse
## @param particle: The particle effect to return
## @param particle_type: The type of particle effect
static func _return_pooled_particle(
	particle: GPUParticles2D,
	particle_type: CutsceneTypes.ParticleType
) -> void:
	if not is_instance_valid(particle):
		return
	
	# Initialize pool for this type if needed
	if not _particle_pool.has(particle_type):
		_particle_pool[particle_type] = []
	
	var pool = _particle_pool[particle_type]
	
	# Only pool if under max size
	if pool.size() < MAX_POOL_SIZE_PER_TYPE:
		# Remove from scene tree but don't free
		if particle.get_parent():
			particle.get_parent().remove_child(particle)
		particle.emitting = false
		pool.append(particle)
	else:
		# Pool is full, free the particle
		particle.queue_free()


## Clear all cached resources and object pools
## Call this when memory usage is high or during scene transitions
static func clear_caches() -> void:
	_animation_cache.clear()
	_texture_cache.clear()
	_particle_scene_cache.clear()
	
	# Free all pooled particles
	for particle_type in _particle_pool.keys():
		var pool = _particle_pool[particle_type]
		for particle in pool:
			if is_instance_valid(particle):
				particle.queue_free()
		pool.clear()
	_particle_pool.clear()


## Get current memory usage statistics
## @return: Dictionary with memory usage information
static func get_memory_stats() -> Dictionary:
	return {
		"static_memory_mb": OS.get_static_memory_usage() / 1024.0 / 1024.0,
		"peak_memory_mb": OS.get_static_memory_peak_usage() / 1024.0 / 1024.0,
		"memory_ratio": _get_memory_usage_ratio(),
		"cached_animations": _animation_cache.size(),
		"cached_textures": _texture_cache.size(),
		"cached_particle_scenes": _particle_scene_cache.size(),
		"pooled_particles": _get_total_pooled_particles()
	}


## Get total number of particles in all pools
static func _get_total_pooled_particles() -> int:
	var total = 0
	for pool in _particle_pool.values():
		total += pool.size()
	return total


static func _get_memory_usage_ratio() -> float:
	var static_memory = OS.get_static_memory_usage()
	var peak_memory = OS.get_static_memory_peak_usage()
	if peak_memory == 0:
		return 0.0
	return float(static_memory) / float(peak_memory)


# ============================================================================
# PRIVATE METHODS - Asset Loading with Error Handling
# ============================================================================

## Load character scene with error handling
## Implements Requirement 12.2: Fallback to legacy emoji cutscenes on asset load failure
func _load_character_scene() -> void:
	if _character_scene:
		return  # Already loaded
	
	if ResourceLoader.exists(CHARACTER_SCENE_PATH):
		_character_scene = load(CHARACTER_SCENE_PATH)
		if _character_scene:
			push_warning("[AnimatedCutscenePlayer] Character scene loaded successfully")
		else:
			push_error(
				"[AnimatedCutscenePlayer] Failed to load character scene " +
				"from: " + CHARACTER_SCENE_PATH +
				". Will fall back to legacy emoji cutscenes."
			)
	else:
		push_error(
			"[AnimatedCutscenePlayer] Character scene not found at: " + CHARACTER_SCENE_PATH +
			". Will fall back to legacy emoji cutscenes."
		)


## Check if character assets are available
## @return: True if character scene can be instantiated
func _can_use_animated_cutscene() -> bool:
	return _character_scene != null


## Fall back to legacy emoji-based cutscene
## Implements Requirement 12.2: Fallback to legacy emoji cutscenes on asset load failure
## @param minigame_key: The minigame identifier
## @param cutscene_type: The type of cutscene
func _fallback_to_legacy_cutscene(
	minigame_key: String,
	cutscene_type: CutsceneTypes.CutsceneType
) -> void:
	push_warning(
		"[AnimatedCutscenePlayer] Falling back to legacy emoji cutscene for " + minigame_key +
		" (type: " + _cutscene_type_to_string(cutscene_type) + ")"
	)
	
	# Create a simple emoji-based display
	var emoji_label = Label.new()
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_label.anchors_preset = Control.PRESET_FULL_RECT
	
	# Set emoji based on cutscene type
	match cutscene_type:
		CutsceneTypes.CutsceneType.WIN:
			emoji_label.text = "🎉 Success! 💧"
		CutsceneTypes.CutsceneType.FAIL:
			emoji_label.text = "💦 Try Again! 💧"
		CutsceneTypes.CutsceneType.INTRO:
			emoji_label.text = "💧 Ready! 💧"
	
	# Style the label
	emoji_label.add_theme_font_size_override("font_size", 48)
	
	add_child(emoji_label)
	
	# Simple fade in/out animation with error recovery (Requirement 12.5)
	emoji_label.modulate.a = 0.0
	var tween = create_tween()
	
	if not tween:
		# If tween creation fails, show static emoji for fixed duration
		push_warning(
			"[AnimatedCutscenePlayer] Failed to create tween for " +
			"emoji fallback, using static display"
		)
		emoji_label.modulate.a = 1.0
		var static_timer = get_tree().create_timer(2.0)
		if static_timer:
			await static_timer.timeout
		else:
			# Last resort: minimal delay using process frames
			for i in range(120):  # ~2 seconds at 60fps
				await get_tree().process_frame
		emoji_label.queue_free()
		return
	
	tween.tween_property(emoji_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(emoji_label, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	
	emoji_label.queue_free()


# ============================================================================
# PRIVATE METHODS - Configuration Loading
# ============================================================================

func _load_config(
	minigame_key: String,
	cutscene_type: CutsceneTypes.CutsceneType
) -> CutsceneDataModels.CutsceneConfig:
	# Check cache first
	if _animation_cache.has(minigame_key) and _animation_cache[minigame_key].has(cutscene_type):
		return _animation_cache[minigame_key][cutscene_type]
	
	# Try custom minigame-specific configuration first
	var custom_path = _get_config_path(minigame_key, cutscene_type)
	if FileAccess.file_exists(custom_path):
		var custom_config = CutsceneParser.parse_config(custom_path)
		if custom_config:
			# Cache the loaded configuration
			if not _animation_cache.has(minigame_key):
				_animation_cache[minigame_key] = {}
			_animation_cache[minigame_key][cutscene_type] = custom_config
			print("[AnimatedCutscenePlayer] Loaded custom cutscene configuration: " + custom_path)
			return custom_config
		push_warning(
			"[AnimatedCutscenePlayer] Failed to parse custom configuration file: " + custom_path +
			". Falling back to default configuration."
		)
	else:
		print("[AnimatedCutscenePlayer] No custom cutscene found for " + minigame_key + 
			" (type: " + _cutscene_type_to_string(cutscene_type) + "). " +
			"Attempting to load default configuration.")
	
	# Fall back to default configuration
	var default_path = _get_default_config_path(cutscene_type)
	if FileAccess.file_exists(default_path):
		var default_config = CutsceneParser.parse_config(default_path)
		if default_config:
			# Cache the default configuration
			if not _animation_cache.has(minigame_key):
				_animation_cache[minigame_key] = {}
			_animation_cache[minigame_key][cutscene_type] = default_config
			print("[AnimatedCutscenePlayer] Loaded default cutscene configuration: " + default_path)
			return default_config
		push_warning(
			"[AnimatedCutscenePlayer] Failed to parse default configuration file: " + default_path +
			". Creating minimal fallback configuration."
		)
	else:
		push_warning(
			"[AnimatedCutscenePlayer] Default configuration file not found: " + default_path +
			". Creating minimal fallback configuration."
		)
	
	# Last resort: create minimal default configuration
	print("[AnimatedCutscenePlayer] Creating minimal fallback configuration for " + minigame_key + 
		" (type: " + _cutscene_type_to_string(cutscene_type) + ")")
	var fallback_config = _create_minimal_config(minigame_key, cutscene_type)
	# Cache the minimal configuration
	if not _animation_cache.has(minigame_key):
		_animation_cache[minigame_key] = {}
	_animation_cache[minigame_key][cutscene_type] = fallback_config
	return fallback_config


func _get_config_path(minigame_key: String, cutscene_type: CutsceneTypes.CutsceneType) -> String:
	var type_str = _cutscene_type_to_string(cutscene_type)
	return CONFIG_BASE_PATH + minigame_key + "/" + type_str + ".json"


func _get_default_config_path(cutscene_type: CutsceneTypes.CutsceneType) -> String:
	var type_str = _cutscene_type_to_string(cutscene_type)
	return DEFAULT_CONFIG_PATH + type_str + ".json"


## Apply default values for fields that failed validation
## This ensures the cutscene can still play even with invalid configuration data
## @param config: The configuration with validation errors
## @param validation: The validation result containing error information
## @return: A corrected configuration with default values applied
func _apply_validation_defaults(
	config: CutsceneDataModels.CutsceneConfig, 
	validation: CutsceneDataModels.ValidationResult
) -> CutsceneDataModels.CutsceneConfig:
	var errors = validation.get_errors()
	
	for error in errors:
		var error_lower = error.to_lower()
		
		# Fix duration issues
		if "duration" in error_lower:
			if config.duration <= 0.0:
				config.duration = 2.0
				print("[AnimatedCutscenePlayer] Applied default duration: 2.0s")
			elif config.duration < 1.5:
				config.duration = 1.5
				print("[AnimatedCutscenePlayer] Clamped duration to minimum: 1.5s")
			elif config.duration > 4.0:
				config.duration = 4.0
				print("[AnimatedCutscenePlayer] Clamped duration to maximum: 4.0s")
		
		# Fix missing minigame key
		if "minigame key" in error_lower and "empty" in error_lower:
			config.minigame_key = "Unknown"
			print("[AnimatedCutscenePlayer] Applied default minigame_key: 'Unknown'")
		
		# Fix missing keyframes
		if "keyframe" in error_lower and ("empty" in error_lower or "at least one" in error_lower):
			if config.keyframes.is_empty():
				# Add minimal keyframes for a simple pop-in animation
				var kf1 = CutsceneDataModels.Keyframe.new(0.0)
				kf1.add_transform(CutsceneDataModels.Transform.new(
					CutsceneTypes.TransformType.SCALE, 
					Vector2(0.3, 0.3), 
					false
				))
				kf1.easing = CutsceneTypes.Easing.EASE_OUT
				
				var kf2 = CutsceneDataModels.Keyframe.new(config.duration * 0.5)
				kf2.add_transform(CutsceneDataModels.Transform.new(
					CutsceneTypes.TransformType.SCALE, 
					Vector2(1.0, 1.0), 
					false
				))
				kf2.easing = CutsceneTypes.Easing.EASE_IN_OUT
				
				config.add_keyframe(kf1)
				config.add_keyframe(kf2)
				print("[AnimatedCutscenePlayer] Applied default keyframes for animation")
		
		# Fix missing character configuration
		if "character configuration is missing" in error_lower:
			config.character = CutsceneDataModels.CharacterConfig.new()
			config.character.expression = CutsceneTypes.CharacterExpression.HAPPY
			config.character.deformation_enabled = true
			print("[AnimatedCutscenePlayer] Applied default character configuration")
	
	# Re-validate to ensure we fixed the critical issues
	var revalidation = CutsceneParser.validate_config(config)
	if revalidation.has_errors():
		push_warning(
			"[AnimatedCutscenePlayer] Some validation errors remain after applying defaults. " +
			"Creating minimal fallback configuration."
		)
		# If we still have errors, create a completely new minimal config
		return _create_minimal_config(config.minigame_key, config.cutscene_type)
	
	return config


func _create_minimal_config(
	minigame_key: String,
	cutscene_type: CutsceneTypes.CutsceneType
) -> CutsceneDataModels.CutsceneConfig:
	var minimal_config = CutsceneDataModels.CutsceneConfig.new()
	minimal_config.minigame_key = minigame_key
	minimal_config.cutscene_type = cutscene_type
	minimal_config.duration = 2.0
	
	# Set expression based on cutscene type
	match cutscene_type:
		CutsceneTypes.CutsceneType.WIN:
			minimal_config.character.expression = CutsceneTypes.CharacterExpression.HAPPY
		CutsceneTypes.CutsceneType.FAIL:
			minimal_config.character.expression = CutsceneTypes.CharacterExpression.SAD
		CutsceneTypes.CutsceneType.INTRO:
			minimal_config.character.expression = CutsceneTypes.CharacterExpression.DETERMINED
	
	# Create simple animation: pop in and settle
	var keyframe1 = CutsceneDataModels.Keyframe.new(0.0)
	var scale_transform1 = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(0.3, 0.3),
		false
	)
	keyframe1.add_transform(scale_transform1)
	keyframe1.easing = CutsceneTypes.Easing.EASE_OUT
	
	var keyframe2 = CutsceneDataModels.Keyframe.new(1.0)
	var scale_transform2 = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	)
	keyframe2.add_transform(scale_transform2)
	keyframe2.easing = CutsceneTypes.Easing.EASE_IN_OUT
	
	minimal_config.add_keyframe(keyframe1)
	minimal_config.add_keyframe(keyframe2)
	
	# Add contextual particle effect for win and fail cutscenes
	if cutscene_type != CutsceneTypes.CutsceneType.INTRO:
		var particle = ParticleEffectManager.create_default_particle_effect(
			cutscene_type,
			minigame_key,
			0.5,
			1.5
		)
		minimal_config.add_particle(particle)
	
	return minimal_config


# ============================================================================
# PRIVATE METHODS - Scene Setup
# ============================================================================

func _setup_cutscene(config: CutsceneDataModels.CutsceneConfig) -> void:
	# Instantiate character with error handling (Requirement 12.2, 12.5)
	if not _character_scene:
		push_error(
			"[AnimatedCutscenePlayer] Character scene not loaded, cannot instantiate character"
		)
		return
	
	_current_character = _character_scene.instantiate()
	if not _current_character:
		push_error("[AnimatedCutscenePlayer] Failed to instantiate character from scene. " +
			"This may indicate memory allocation failure or corrupted scene file.")
		return
	
	# Add character to scene tree with error recovery (Requirement 12.5)
	add_child(_current_character)
	
	# Verify character was added successfully
	if not _current_character.is_inside_tree():
		push_error("[AnimatedCutscenePlayer] Failed to add character to scene tree. " +
			"Cutscene will be skipped to prevent blocking game progression.")
		_current_character.queue_free()
		_current_character = null
		return
	
	# Center character
	_current_character.position = size / 2.0
	
	# Set character expression with error handling
	if _current_character.has_method("set_expression"):
		_current_character.set_expression(config.character.expression)
	else:
		push_warning("[AnimatedCutscenePlayer] Character missing set_expression method")
	
	# Set deformation enabled with error handling
	if _current_character.has_method("set_deformation_enabled"):
		_current_character.set_deformation_enabled(config.character.deformation_enabled)
	else:
		push_warning("[AnimatedCutscenePlayer] Character missing set_deformation_enabled method")


# ============================================================================
# PRIVATE METHODS - Animation Playback
# ============================================================================

func _play_animation(config: CutsceneDataModels.CutsceneConfig) -> void:
	if not _current_character:
		push_warning(
			"[AnimatedCutscenePlayer] No character available for animation, " +
			"skipping cutscene playback"
		)
		return
	
	# Start background color transition if the target color is different
	if _background and _background.color != config.background_color:
		_start_background_transition(config.background_color, config.duration)
	
	# Start main animation with error recovery (Requirement 12.5)
	_current_tween = AnimationEngine.animate(
		_current_character,
		config.keyframes,
		config.duration
	)
	
	# Handle animation engine failure gracefully (Requirement 12.5)
	if not _current_tween:
		push_error("[AnimatedCutscenePlayer] Animation engine failed to create tween. " +
			"Falling back to static character display with minimal timing.")
		# Fallback: Show static character for the configured duration
		await _fallback_static_display(config.duration)
		return
	
	# Schedule particle effects (with error handling)
	for particle in config.particles:
		_schedule_particle_effect(particle)
	
	# Schedule audio cues (with error handling)
	for audio in config.audio_cues:
		_schedule_audio_cue(audio)
	
	# Schedule screen shakes (with error handling)
	for shake in config.screen_shakes:
		_schedule_screen_shake(shake)
	
	# Schedule text overlays (with error handling)
	for overlay in config.text_overlays:
		_schedule_text_overlay(overlay)
	
	# Wait for animation to complete with error recovery
	# If the tween becomes invalid during playback, we still need to complete
	if _current_tween and _current_tween.is_valid():
		await _current_tween.finished
	else:
		push_warning(
			"[AnimatedCutscenePlayer] Tween became invalid during playback, using fallback timing"
		)
		await _fallback_static_display(config.duration)


func _schedule_particle_effect(particle: CutsceneDataModels.ParticleEffect) -> void:
	if not _current_character:
		return
	
	# Wait for the specified time
	var timer = get_tree().create_timer(particle.time)
	if not timer:
		push_warning(
			"[AnimatedCutscenePlayer] Failed to create timer for particle effect, skipping"
		)
		return
	_scheduled_timers.append(timer)
	await timer.timeout

	if AccessibilityManager and AccessibilityManager.has_method("should_show_particles"):
		if not AccessibilityManager.should_show_particles():
			return
	elif SaveManager and SaveManager.has_method("is_particles_enabled"):
		if not SaveManager.is_particles_enabled():
			return
	
	# Spawn particle effect with adaptive density using object pool
	if is_instance_valid(_current_character):
		# Get particle from pool (with error handling for missing textures - Requirement 12.4)
		var particle_node = _get_pooled_particle(particle.type)
		
		if not particle_node:
			# Graceful degradation: Skip particles if texture/scene is missing or allocation fails
			push_warning(
				"[AnimatedCutscenePlayer] Skipping particle effect due to missing texture/scene " +
				"or memory allocation failure: " +
				str(particle.type) + ". Continuing cutscene without particles."
			)
			return
		
		# Add to character's particle container with error recovery (Requirement 12.5)
		if _current_character.particle_container:
			_current_character.particle_container.add_child(particle_node)
		else:
			_current_character.add_child(particle_node)
		
		# Track active particle
		_active_particles.append(particle_node)
		
		# Apply adaptive density based on performance
		ParticleEffectManager.apply_adaptive_density(particle_node)
		
		# Start emission
		particle_node.emitting = true
		
		# Schedule cleanup and return to pool
		if particle.duration > 0.0:
			var cleanup_timer = get_tree().create_timer(particle.duration)
			if not cleanup_timer:
				# If timer creation fails, clean up immediately to prevent memory leak
				push_warning(
					"[AnimatedCutscenePlayer] Failed to create cleanup timer, " +
					"cleaning up particle immediately"
				)
				particle_node.emitting = false
				_active_particles.erase(particle_node)
				_return_pooled_particle(particle_node, particle.type)
				return
			_scheduled_timers.append(cleanup_timer)
			await cleanup_timer.timeout
			
			if is_instance_valid(particle_node):
				particle_node.emitting = false
				# Wait for particles to finish, then return to pool
				var finish_timer = get_tree().create_timer(particle_node.lifetime)
				if finish_timer:
					_scheduled_timers.append(finish_timer)
					await finish_timer.timeout
				
				if is_instance_valid(particle_node):
					_active_particles.erase(particle_node)
					_return_pooled_particle(particle_node, particle.type)


func _schedule_audio_cue(audio: CutsceneDataModels.AudioCue) -> void:
	# Wait for the specified time with error recovery (Requirement 12.5)
	var timer = get_tree().create_timer(audio.time)
	if not timer:
		push_warning(
			"[AnimatedCutscenePlayer] Failed to create timer for audio cue, playing immediately"
		)
		# Fallback: Play audio immediately if timer creation fails
		_play_audio_by_name(audio.sound)
		return
	_scheduled_timers.append(timer)
	await timer.timeout
	
	# Play audio through AudioManager if available.
	if not AudioManager:
		push_warning(
			"[AnimatedCutscenePlayer] AudioManager not available, skipping audio cue: " +
			audio.sound +
			". Continuing cutscene without audio."
		)
		return
	
	# Try to play audio, but don't fail if it doesn't work
	_play_audio_by_name(audio.sound)


func _schedule_screen_shake(shake: CutsceneDataModels.ScreenShake) -> void:
	# Wait for the specified time with error recovery (Requirement 12.5)
	var timer = get_tree().create_timer(shake.time)
	if not timer:
		push_warning(
			"[AnimatedCutscenePlayer] Failed to create timer for screen shake, skipping effect"
		)
		return
	_scheduled_timers.append(timer)
	await timer.timeout
	
	# Check if screen shake is enabled in accessibility settings
	if SaveManager and SaveManager.has_method("is_screen_shake_enabled"):
		if not SaveManager.is_screen_shake_enabled():
			return
	
	# Get the camera from the viewport
	var camera = get_viewport().get_camera_2d()
	if not camera:
		push_warning("[AnimatedCutscenePlayer] No camera found for screen shake effect")
		return
	
	# Apply screen shake using the same pattern as JuiceEffects
	_apply_screen_shake(camera, shake.intensity, shake.duration)


func _start_background_transition(target_color: Color, duration: float) -> void:
	if not _background:
		return
	
	# Create a tween for smooth color interpolation with error recovery (Requirement 12.5)
	_background_tween = create_tween()
	if not _background_tween:
		push_error("[AnimatedCutscenePlayer] Failed to create background color tween. " +
			"Falling back to instant color change.")
		# Fallback: Set color instantly instead of animating
		_background.color = target_color
		return
	
	# Set easing for smooth transition
	_background_tween.set_ease(Tween.EASE_IN_OUT)
	_background_tween.set_trans(Tween.TRANS_QUAD)
	
	# Tween the background color over the cutscene duration
	_background_tween.tween_property(_background, "color", target_color, duration)


## Fallback method for displaying static character when animation fails
## Implements Requirement 12.5: Ensure game progression never blocks on cutscene errors
## @param duration: How long to display the static character
func _fallback_static_display(duration: float) -> void:
	# Display character statically for the specified duration when animation fails.
	# This ensures cutscene completion and game progression even if animation fails.
	print("[AnimatedCutscenePlayer] Using fallback static display for %.1f seconds" % duration)
	
	# Simply wait for the duration - character is already visible
	var timer = get_tree().create_timer(duration)
	if timer:
		await timer.timeout
	else:
		# If even timer creation fails (extreme memory pressure), use a minimal delay
		push_error("[AnimatedCutscenePlayer] Failed to create timer for fallback display. " +
			"Using minimal delay to ensure cutscene completes.")
		# Use process frames as last resort timing mechanism
		var start_time = Time.get_ticks_msec()
		var target_time = start_time + (duration * 1000.0)
		while Time.get_ticks_msec() < target_time:
			await get_tree().process_frame


func _apply_screen_shake(camera: Camera2D, intensity: float, duration: float) -> void:
	# Apply screen shake effect to the camera using viewport offset.
	if not camera:
		return
	
	var original_offset = camera.offset
	var shake_tween = camera.create_tween()
	
	# Handle tween creation failure gracefully (Requirement 12.5)
	if not shake_tween:
		push_warning(
			"[AnimatedCutscenePlayer] Failed to create screen shake tween, skipping effect"
		)
		return
	
	# Calculate number of shake iterations based on duration
	var num_shakes = int(duration / 0.05)
	
	# Apply random offsets for shake effect
	for i in range(num_shakes):
		shake_tween.tween_property(camera, "offset", original_offset + Vector2(
			randf_range(-intensity * 10, intensity * 10),
			randf_range(-intensity * 10, intensity * 10)
		), 0.05)
	
	# Return to original position
	shake_tween.tween_property(camera, "offset", original_offset, 0.05)


func _schedule_text_overlay(overlay: CutsceneDataModels.TextOverlay) -> void:
	# Wait for the specified time with error recovery (Requirement 12.5)
	var timer = get_tree().create_timer(overlay.time)
	if not timer:
		push_warning("[AnimatedCutscenePlayer] Failed to create timer for text overlay, skipping")
		return
	_scheduled_timers.append(timer)
	await timer.timeout
	
	# Create and add text overlay with memory allocation error handling (Requirement 12.5)
	var text_overlay = AnimatedTextOverlay.new()
	if not text_overlay:
		push_warning(
			"[AnimatedCutscenePlayer] Failed to allocate text overlay node, skipping text display"
		)
		return
	
	add_child(text_overlay)
	_active_text_overlays.append(text_overlay)
	
	# Play animation
	text_overlay.play_animation(overlay, size)


# ============================================================================
# PRIVATE METHODS - Cleanup
# ============================================================================

func _cleanup_cutscene() -> void:
	# Comprehensive cleanup of all active cutscene resources.
	
	# Kill tweens
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = null
	
	if _background_tween and _background_tween.is_valid():
		_background_tween.kill()
	_background_tween = null
	
	# Clean up active particles - return to pool for reuse (object pooling)
	for particle in _active_particles:
		if is_instance_valid(particle):
			particle.emitting = false
			# Determine particle type for pooling
			var particle_type = _identify_particle_type(particle)
			if particle_type != null:
				_return_pooled_particle(particle, particle_type)
			else:
				# Unknown type, just free it
				particle.queue_free()
	_active_particles.clear()
	
	# Clean up text overlays
	for overlay in _active_text_overlays:
		if is_instance_valid(overlay):
			overlay.queue_free()
	_active_text_overlays.clear()
	
	# Clear timer references (they auto-cleanup, but we clear our references)
	_scheduled_timers.clear()
	
	# Remove character
	if _current_character:
		_current_character.queue_free()
		_current_character = null
	
	# Check memory usage and clear caches if needed (adaptive quality reduction)
	var memory_ratio = _get_memory_usage_ratio()
	if memory_ratio > 0.8:  # 80% memory usage threshold
		push_warning(
			"[AnimatedCutscenePlayer] High memory usage detected (%.1f%%), clearing caches"
			% (memory_ratio * 100)
		)
		clear_caches()


## Identify the particle type from a particle node
## This is used for returning particles to the correct pool
## @param particle: The particle node to identify
## @return: The particle type, or null if unknown
func _identify_particle_type(particle: GPUParticles2D) -> CutsceneTypes.ParticleType:
	# Check the scene file path to determine type
	var scene_file = particle.scene_file_path
	if scene_file:
		for particle_type in WaterDropletCharacter.PARTICLE_SCENES.keys():
			if WaterDropletCharacter.PARTICLE_SCENES[particle_type] == scene_file:
				return particle_type
	
	# Fallback: check node name patterns
	var node_name = particle.name.to_lower()
	if "sparkle" in node_name:
		return CutsceneTypes.ParticleType.SPARKLES
	if "water" in node_name or "drop" in node_name:
		return CutsceneTypes.ParticleType.WATER_DROPS
	if "star" in node_name:
		return CutsceneTypes.ParticleType.STARS
	if "smoke" in node_name:
		return CutsceneTypes.ParticleType.SMOKE
	if "splash" in node_name:
		return CutsceneTypes.ParticleType.SPLASH
	
	# Default fallback
	return CutsceneTypes.ParticleType.SPARKLES


# ============================================================================
# HELPER METHODS
# ============================================================================

func _play_audio_by_name(sound_name: String) -> void:
	# Map sound name to AudioManager method and play it.
	# Wrap audio playback in error handling to prevent cutscene blocking
	# If audio fails, log warning but continue cutscene
	match sound_name.to_lower():
		"success_chime", "success", "chime":
			if AudioManager.has_method("play_success"):
				AudioManager.play_success()
			else:
				push_warning("[AnimatedCutscenePlayer] AudioManager.play_success() not available")
		"water_splash", "splash":
			if AudioManager.has_method("play_water_splash"):
				AudioManager.play_water_splash()
			else:
				push_warning(
					"[AnimatedCutscenePlayer] AudioManager.play_water_splash() not available"
				)
		"water_drop", "drop":
			if AudioManager.has_method("play_water_drop"):
				AudioManager.play_water_drop()
			else:
				push_warning(
					"[AnimatedCutscenePlayer] AudioManager.play_water_drop() not available"
				)
		"warning", "alert":
			if AudioManager.has_method("play_sfx"):
				AudioManager.play_sfx(AudioManager.SFXType.WARNING)
			else:
				push_warning("[AnimatedCutscenePlayer] AudioManager.play_sfx() not available")
		"thud", "impact", "damage":
			if AudioManager.has_method("play_damage"):
				AudioManager.play_damage()
			else:
				push_warning("[AnimatedCutscenePlayer] AudioManager.play_damage() not available")
		"whoosh", "game_start", "start":
			if AudioManager.has_method("play_game_start"):
				AudioManager.play_game_start()
			else:
				push_warning(
					"[AnimatedCutscenePlayer] AudioManager.play_game_start() not available"
				)
		"ready", "countdown":
			if AudioManager.has_method("play_countdown"):
				AudioManager.play_countdown()
			else:
				push_warning("[AnimatedCutscenePlayer] AudioManager.play_countdown() not available")
		"bonus", "collect":
			if AudioManager.has_method("play_bonus"):
				AudioManager.play_bonus()
			else:
				push_warning("[AnimatedCutscenePlayer] AudioManager.play_bonus() not available")
		"failure", "fail":
			if AudioManager.has_method("play_failure"):
				AudioManager.play_failure()
			else:
				push_warning("[AnimatedCutscenePlayer] AudioManager.play_failure() not available")
		"click":
			if AudioManager.has_method("play_click"):
				AudioManager.play_click()
			else:
				push_warning("[AnimatedCutscenePlayer] AudioManager.play_click() not available")
		"game_end", "end":
			if AudioManager.has_method("play_game_end"):
				AudioManager.play_game_end()
			else:
				push_warning("[AnimatedCutscenePlayer] AudioManager.play_game_end() not available")
		_:
			# Try to play as generic SFX if it matches an enum name
			push_warning("[AnimatedCutscenePlayer] Unknown sound name: " + sound_name + 
				". Skipping audio playback and continuing cutscene.")
			# Don't attempt to play unknown sounds - just skip them


func _cutscene_type_to_string(type: CutsceneTypes.CutsceneType) -> String:
	match type:
		CutsceneTypes.CutsceneType.INTRO:
			return "intro"
		CutsceneTypes.CutsceneType.WIN:
			return "win"
		CutsceneTypes.CutsceneType.FAIL:
			return "fail"
		_:
			return "intro"
