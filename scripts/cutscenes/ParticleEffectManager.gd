class_name ParticleEffectManager

## Manages particle effect selection and adaptive density for cutscenes
##
## This component provides:
## - Contextual particle selection based on cutscene type
## - Adaptive particle density based on performance
## - Integration with PerformanceManager for optimization

# Particle type mappings for contextual selection
const CELEBRATORY_PARTICLES = [
	CutsceneTypes.ParticleType.SPARKLES,
	CutsceneTypes.ParticleType.STARS
]

const FAILURE_PARTICLES = [
	CutsceneTypes.ParticleType.SMOKE,
	CutsceneTypes.ParticleType.SPLASH
]

const WATER_THEMED_PARTICLES = [
	CutsceneTypes.ParticleType.WATER_DROPS,
	CutsceneTypes.ParticleType.SPLASH
]

# Performance thresholds
const MEMORY_THRESHOLD_HIGH = 0.8  # 80% memory usage
const FPS_THRESHOLD_LOW = 45  # Below 45 FPS triggers reduction

# Density reduction factors
const DENSITY_NORMAL = 1.0
const DENSITY_REDUCED = 0.6
const DENSITY_MINIMAL = 0.3


## Select appropriate particle type based on cutscene context
## @param cutscene_type: The type of cutscene (INTRO, WIN, FAIL)
## @param minigame_key: The minigame identifier for theme detection
## @return: Appropriate particle type for the context
static func select_contextual_particle(
	cutscene_type: CutsceneTypes.CutsceneType,
	minigame_key: String = ""
) -> CutsceneTypes.ParticleType:
	match cutscene_type:
		CutsceneTypes.CutsceneType.WIN:
			# Celebratory particles for win
			return CELEBRATORY_PARTICLES.pick_random()
		
		CutsceneTypes.CutsceneType.FAIL:
			# Failure particles for fail
			return FAILURE_PARTICLES.pick_random()
		
		CutsceneTypes.CutsceneType.INTRO:
			# Water-themed particles for water-related minigames
			if _is_water_themed_minigame(minigame_key):
				return WATER_THEMED_PARTICLES.pick_random()
			# No particles for non-water intro cutscenes
			return CutsceneTypes.ParticleType.SPARKLES  # Default fallback
		
		_:
			return CutsceneTypes.ParticleType.SPARKLES


## Check if a minigame is water-themed based on its key
## @param minigame_key: The minigame identifier
## @return: True if the minigame is water-themed
static func _is_water_themed_minigame(minigame_key: String) -> bool:
	var water_keywords = ["Rain", "Leak", "Tap", "Water", "Pipe", "Shower", "Aquarium"]
	for keyword in water_keywords:
		if keyword.to_lower() in minigame_key.to_lower():
			return true
	return false


## Get current performance-based density factor
## @return: Density factor (0.3 to 1.0) based on current performance
static func get_adaptive_density_factor() -> float:
	var memory_usage = get_memory_usage_ratio()
	var current_fps = Engine.get_frames_per_second()
	
	# Check memory pressure
	if memory_usage > MEMORY_THRESHOLD_HIGH:
		return DENSITY_MINIMAL
	
	# Check FPS
	if current_fps < FPS_THRESHOLD_LOW:
		return DENSITY_REDUCED
	
	# Normal performance
	return DENSITY_NORMAL


## Apply adaptive density to a particle system
## @param particles: The GPUParticles2D node to optimize
static func apply_adaptive_density(particles: GPUParticles2D) -> void:
	if not particles:
		return
	
	var density_factor = get_adaptive_density_factor()
	
	# Only reduce if performance is poor
	if density_factor < DENSITY_NORMAL:
		PerformanceManager.reduce_particles(particles, density_factor)


## Get memory usage ratio (0.0 to 1.0)
## @return: Memory usage as a ratio of available memory
static func get_memory_usage_ratio() -> float:
	var static_memory = OS.get_static_memory_usage()
	var max_memory = OS.get_static_memory_peak_usage()
	
	if max_memory == 0:
		return 0.0
	
	return float(static_memory) / float(max_memory)


## Enhance particle configuration with contextual settings
## @param particle_effect: The particle effect data model
## @param cutscene_type: The type of cutscene
## @param minigame_key: The minigame identifier
static func enhance_particle_config(
	particle_effect: CutsceneDataModels.ParticleEffect,
	cutscene_type: CutsceneTypes.CutsceneType,
	minigame_key: String = ""
) -> void:
	# If no particle type specified, select contextually
	if particle_effect.type == CutsceneTypes.ParticleType.SPARKLES and cutscene_type != CutsceneTypes.CutsceneType.INTRO:
		particle_effect.type = select_contextual_particle(cutscene_type, minigame_key)


## Create default particle effect for a cutscene type
## @param cutscene_type: The type of cutscene
## @param minigame_key: The minigame identifier
## @param time: When to spawn the particle (in seconds)
## @param duration: How long particles should emit
## @return: A configured ParticleEffect data model
static func create_default_particle_effect(
	cutscene_type: CutsceneTypes.CutsceneType,
	minigame_key: String = "",
	time: float = 0.5,
	duration: float = 1.0
) -> CutsceneDataModels.ParticleEffect:
	var particle = CutsceneDataModels.ParticleEffect.new()
	particle.time = time
	particle.duration = duration
	particle.type = select_contextual_particle(cutscene_type, minigame_key)
	return particle
