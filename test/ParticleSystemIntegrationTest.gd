extends GutTest

## Integration tests for particle effect system
## Tests particle spawning, contextual selection, and adaptive density

var cutscene_player: AnimatedCutscenePlayer
var character: WaterDropletCharacter


func before_each():
	cutscene_player = AnimatedCutscenePlayer.new()
	add_child_autofree(cutscene_player)
	
	character = preload("res://scenes/cutscenes/WaterDropletCharacter.tscn").instantiate()
	add_child_autofree(character)


func after_each():
	cutscene_player = null
	character = null


# ============================================================================
# PARTICLE SPAWNING TESTS
# ============================================================================

func test_spawn_sparkles_particle():
	var particles = character.spawn_particles(CutsceneTypes.ParticleType.SPARKLES, 1.0)
	
	assert_not_null(particles, "Should spawn sparkles particle")
	assert_true(particles is GPUParticles2D, "Should be GPUParticles2D")
	assert_true(particles.emitting, "Particles should be emitting")


func test_spawn_water_drops_particle():
	var particles = character.spawn_particles(CutsceneTypes.ParticleType.WATER_DROPS, 1.0)
	
	assert_not_null(particles, "Should spawn water drops particle")
	assert_true(particles is GPUParticles2D, "Should be GPUParticles2D")
	assert_true(particles.emitting, "Particles should be emitting")


func test_spawn_stars_particle():
	var particles = character.spawn_particles(CutsceneTypes.ParticleType.STARS, 1.0)
	
	assert_not_null(particles, "Should spawn stars particle")
	assert_true(particles is GPUParticles2D, "Should be GPUParticles2D")
	assert_true(particles.emitting, "Particles should be emitting")


func test_spawn_smoke_particle():
	var particles = character.spawn_particles(CutsceneTypes.ParticleType.SMOKE, 1.0)
	
	assert_not_null(particles, "Should spawn smoke particle")
	assert_true(particles is GPUParticles2D, "Should be GPUParticles2D")
	assert_true(particles.emitting, "Particles should be emitting")


func test_spawn_splash_particle():
	var particles = character.spawn_particles(CutsceneTypes.ParticleType.SPLASH, 0.0)
	
	assert_not_null(particles, "Should spawn splash particle")
	assert_true(particles is GPUParticles2D, "Should be GPUParticles2D")
	assert_true(particles.emitting, "Particles should be emitting")
	assert_true(particles.one_shot, "Splash should be one-shot")


# ============================================================================
# CONTEXTUAL PARTICLE SELECTION TESTS
# ============================================================================

func test_win_cutscene_uses_celebratory_particles():
	# Test multiple times to account for randomness
	var celebratory_count = 0
	for i in range(10):
		var particle_type = ParticleEffectManager.select_contextual_particle(
			CutsceneTypes.CutsceneType.WIN,
			"TestMinigame"
		)
		if particle_type in [CutsceneTypes.ParticleType.SPARKLES, CutsceneTypes.ParticleType.STARS]:
			celebratory_count += 1
	
	assert_eq(celebratory_count, 10, "All win particles should be celebratory")


func test_fail_cutscene_uses_failure_particles():
	# Test multiple times to account for randomness
	var failure_count = 0
	for i in range(10):
		var particle_type = ParticleEffectManager.select_contextual_particle(
			CutsceneTypes.CutsceneType.FAIL,
			"TestMinigame"
		)
		if particle_type in [CutsceneTypes.ParticleType.SMOKE, CutsceneTypes.ParticleType.SPLASH]:
			failure_count += 1
	
	assert_eq(failure_count, 10, "All fail particles should be failure type")


func test_water_themed_minigame_uses_water_particles():
	var particle_type = ParticleEffectManager.select_contextual_particle(
		CutsceneTypes.CutsceneType.INTRO,
		"CatchTheRain"
	)
	
	# For water-themed intro, should use water particles
	assert_true(
		particle_type in [CutsceneTypes.ParticleType.WATER_DROPS, CutsceneTypes.ParticleType.SPLASH],
		"Water-themed minigame should use water particles"
	)


# ============================================================================
# ADAPTIVE DENSITY TESTS
# ============================================================================

func test_adaptive_density_reduces_particle_count():
	var particles = GPUParticles2D.new()
	particles.amount = 100
	add_child_autofree(particles)
	
	var original_amount = particles.amount
	
	# Apply adaptive density (may reduce based on performance)
	ParticleEffectManager.apply_adaptive_density(particles)
	
	# Amount should be <= original
	assert_true(
		particles.amount <= original_amount,
		"Adaptive density should not increase particle count"
	)


func test_particle_effect_manager_density_factor_in_valid_range():
	var density = ParticleEffectManager.get_adaptive_density_factor()
	
	assert_true(
		density >= 0.3 and density <= 1.0,
		"Density factor should be between 0.3 and 1.0"
	)


# ============================================================================
# INTEGRATION WITH CUTSCENE PLAYER TESTS
# ============================================================================

func test_cutscene_player_creates_particles_for_win():
	# Create a win cutscene config with particles
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestMinigame"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 1.0
	config.character.expression = CutsceneTypes.CharacterExpression.HAPPY
	
	# Add keyframes
	var keyframe = CutsceneDataModels.Keyframe.new(0.0)
	var transform = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	)
	keyframe.add_transform(transform)
	config.add_keyframe(keyframe)
	
	# Add particle effect
	var particle = ParticleEffectManager.create_default_particle_effect(
		CutsceneTypes.CutsceneType.WIN,
		"TestMinigame",
		0.2,
		0.5
	)
	config.add_particle(particle)
	
	# Verify particle was added
	assert_eq(config.particles.size(), 1, "Should have one particle effect")
	assert_true(
		particle.type in [CutsceneTypes.ParticleType.SPARKLES, CutsceneTypes.ParticleType.STARS],
		"Win particle should be celebratory"
	)


func test_minimal_config_includes_contextual_particles():
	# Test that minimal config creation includes appropriate particles
	var win_config = cutscene_player._create_minimal_config("TestMinigame", CutsceneTypes.CutsceneType.WIN)
	assert_true(win_config.particles.size() > 0, "Win config should have particles")
	
	var fail_config = cutscene_player._create_minimal_config("TestMinigame", CutsceneTypes.CutsceneType.FAIL)
	assert_true(fail_config.particles.size() > 0, "Fail config should have particles")
	
	var intro_config = cutscene_player._create_minimal_config("TestMinigame", CutsceneTypes.CutsceneType.INTRO)
	assert_eq(intro_config.particles.size(), 0, "Intro config should not have particles by default")


# ============================================================================
# PARTICLE SCENE CONFIGURATION TESTS
# ============================================================================

func test_all_particle_scenes_have_fixed_fps():
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
			instance.fixed_fps > 0,
			path + " should have fixed_fps set for consistent performance"
		)


func test_particle_scenes_have_appropriate_amounts():
	var particle_paths = {
		"res://scenes/particles/Sparkles.tscn": 40,
		"res://scenes/particles/WaterDrops.tscn": 55,
		"res://scenes/particles/Stars.tscn": 30,
		"res://scenes/particles/Smoke.tscn": 25,
		"res://scenes/particles/Splash.tscn": 50
	}
	
	for path in particle_paths:
		var scene = load(path)
		var instance = scene.instantiate()
		add_child_autofree(instance)
		
		var expected_amount = particle_paths[path]
		assert_eq(
			instance.amount,
			expected_amount,
			path + " should have " + str(expected_amount) + " particles"
		)
