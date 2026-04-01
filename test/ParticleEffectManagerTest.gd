extends GutTest

## Unit tests for ParticleEffectManager
## Tests contextual particle selection and adaptive density

# ============================================================================
# CONTEXTUAL PARTICLE SELECTION TESTS
# ============================================================================

func test_select_celebratory_particle_for_win():
	var particle_type = ParticleEffectManager.select_contextual_particle(
		CutsceneTypes.CutsceneType.WIN,
		"CatchTheRain"
	)
	
	# Should be either sparkles or stars (celebratory)
	assert_true(
		particle_type == CutsceneTypes.ParticleType.SPARKLES or
		particle_type == CutsceneTypes.ParticleType.STARS,
		"Win cutscene should use celebratory particles"
	)


func test_select_failure_particle_for_fail():
	var particle_type = ParticleEffectManager.select_contextual_particle(
		CutsceneTypes.CutsceneType.FAIL,
		"FixLeak"
	)
	
	# Should be either smoke or splash (failure)
	assert_true(
		particle_type == CutsceneTypes.ParticleType.SMOKE or
		particle_type == CutsceneTypes.ParticleType.SPLASH,
		"Fail cutscene should use failure particles"
	)


func test_water_themed_minigame_detection():
	var water_minigames = [
		"CatchTheRain",
		"FixLeak",
		"WaterPlant",
		"QuickShower",
		"FillAquarium"
	]
	
	for minigame in water_minigames:
		var is_water = ParticleEffectManager._is_water_themed_minigame(minigame)
		assert_true(is_water, minigame + " should be detected as water-themed")


func test_non_water_themed_minigame_detection():
	var non_water_minigames = [
		"FilterBuilder",
		"MudPieMaker",
		"SpotTheSpeck"
	]
	
	for minigame in non_water_minigames:
		var is_water = ParticleEffectManager._is_water_themed_minigame(minigame)
		assert_false(is_water, minigame + " should not be detected as water-themed")


# ============================================================================
# ADAPTIVE DENSITY TESTS
# ============================================================================

func test_get_adaptive_density_factor_returns_valid_range():
	var density = ParticleEffectManager.get_adaptive_density_factor()
	
	assert_true(
		density >= 0.3 and density <= 1.0,
		"Density factor should be between 0.3 and 1.0, got: " + str(density)
	)


func test_apply_adaptive_density_to_particle_system():
	# Create a test particle system
	var particles = GPUParticles2D.new()
	particles.amount = 100
	add_child_autofree(particles)
	
	var original_amount = particles.amount
	
	# Apply adaptive density
	ParticleEffectManager.apply_adaptive_density(particles)
	
	# Amount should be <= original (may be reduced based on performance)
	assert_true(
		particles.amount <= original_amount,
		"Particle amount should not increase after adaptive density"
	)


func test_apply_adaptive_density_handles_null_gracefully():
	# Should not crash with null input
	ParticleEffectManager.apply_adaptive_density(null)
	pass_test("apply_adaptive_density handled null gracefully")


# ============================================================================
# PARTICLE EFFECT CREATION TESTS
# ============================================================================

func test_create_default_particle_effect_for_win():
	var particle = ParticleEffectManager.create_default_particle_effect(
		CutsceneTypes.CutsceneType.WIN,
		"CatchTheRain",
		0.5,
		1.0
	)
	
	assert_not_null(particle, "Should create particle effect")
	assert_eq(particle.time, 0.5, "Should set correct time")
	assert_eq(particle.duration, 1.0, "Should set correct duration")
	assert_true(
		particle.type == CutsceneTypes.ParticleType.SPARKLES or
		particle.type == CutsceneTypes.ParticleType.STARS,
		"Should use celebratory particle for win"
	)


func test_create_default_particle_effect_for_fail():
	var particle = ParticleEffectManager.create_default_particle_effect(
		CutsceneTypes.CutsceneType.FAIL,
		"FixLeak",
		0.3,
		1.5
	)
	
	assert_not_null(particle, "Should create particle effect")
	assert_eq(particle.time, 0.3, "Should set correct time")
	assert_eq(particle.duration, 1.5, "Should set correct duration")
	assert_true(
		particle.type == CutsceneTypes.ParticleType.SMOKE or
		particle.type == CutsceneTypes.ParticleType.SPLASH,
		"Should use failure particle for fail"
	)


func test_enhance_particle_config_updates_type():
	var particle = CutsceneDataModels.ParticleEffect.new()
	particle.type = CutsceneTypes.ParticleType.SPARKLES
	particle.time = 0.5
	particle.duration = 1.0
	
	# Enhance for fail cutscene (should change from sparkles to failure particle)
	ParticleEffectManager.enhance_particle_config(
		particle,
		CutsceneTypes.CutsceneType.FAIL,
		"FixLeak"
	)
	
	# Should now be a failure particle
	assert_true(
		particle.type == CutsceneTypes.ParticleType.SMOKE or
		particle.type == CutsceneTypes.ParticleType.SPLASH,
		"Should update to failure particle"
	)


# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_particle_scenes_exist():
	var particle_paths = [
		"res://scenes/particles/Sparkles.tscn",
		"res://scenes/particles/WaterDrops.tscn",
		"res://scenes/particles/Stars.tscn",
		"res://scenes/particles/Smoke.tscn",
		"res://scenes/particles/Splash.tscn"
	]
	
	for path in particle_paths:
		assert_true(
			ResourceLoader.exists(path),
			"Particle scene should exist: " + path
		)


func test_particle_scenes_are_gpu_particles():
	var particle_paths = [
		"res://scenes/particles/Sparkles.tscn",
		"res://scenes/particles/WaterDrops.tscn",
		"res://scenes/particles/Stars.tscn",
		"res://scenes/particles/Smoke.tscn",
		"res://scenes/particles/Splash.tscn"
	]
	
	for path in particle_paths:
		var scene = load(path)
		var instance = scene.instantiate()
		add_child_autofree(instance)
		
		assert_true(
			instance is GPUParticles2D,
			"Particle scene should be GPUParticles2D: " + path
		)
