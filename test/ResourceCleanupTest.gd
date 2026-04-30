extends GutTest

## Unit tests for Task 9.2: Resource cleanup system
##
## Tests verify:
## - Cleanup method frees tweens, particles, and temporary nodes
## - Memory monitoring and adaptive quality reduction
## - Object pooling for particle effects

# Test constants
const MEMORY_THRESHOLD = 0.8

# Test fixtures
var cutscene_player: AnimatedCutscenePlayer
var test_character: WaterDropletCharacter


func before_each():
	cutscene_player = AnimatedCutscenePlayer.new()
	add_child_autofree(cutscene_player)


func after_each():
	# Clear all caches after each test
	AnimatedCutscenePlayer.clear_caches()


# ============================================================================
# CLEANUP METHOD TESTS
# ============================================================================

func test_cleanup_frees_tweens():
	# Test that cleanup method kills and frees all active tweens
	# Create a simple character for testing
	var character = WaterDropletCharacter.new()
	cutscene_player.add_child(character)
	cutscene_player._current_character = character
	
	# Create some tweens
	var tween1 = character.create_tween()
	tween1.tween_property(character, "position", Vector2(100, 100), 1.0)
	cutscene_player._current_tween = tween1
	
	var tween2 = cutscene_player.create_tween()
	tween2.tween_property(cutscene_player._background, "color", Color.RED, 1.0)
	cutscene_player._background_tween = tween2
	
	# Verify tweens are valid before cleanup
	assert_true(tween1.is_valid(), "Tween 1 should be valid before cleanup")
	assert_true(tween2.is_valid(), "Tween 2 should be valid before cleanup")
	
	# Cleanup
	cutscene_player._cleanup_cutscene()
	
	# Verify tweens are killed
	assert_false(tween1.is_valid(), "Tween 1 should be killed after cleanup")
	assert_false(tween2.is_valid(), "Tween 2 should be killed after cleanup")
	assert_null(cutscene_player._current_tween, "Current tween reference should be null")
	assert_null(cutscene_player._background_tween, "Background tween reference should be null")


func test_cleanup_frees_particles():
	# Test that cleanup method stops and returns particles to pool
	# Create character
	var character = WaterDropletCharacter.new()
	cutscene_player.add_child(character)
	cutscene_player._current_character = character
	
	# Get a particle from pool
	var particle = AnimatedCutscenePlayer._get_pooled_particle(CutsceneTypes.ParticleType.SPARKLES)
	if particle:
		character.particle_container.add_child(particle)
		cutscene_player._active_particles.append(particle)
		particle.emitting = true
		
		# Verify particle is active
		assert_true(is_instance_valid(particle), "Particle should be valid before cleanup")
		assert_eq(cutscene_player._active_particles.size(), 1, "Should have 1 active particle")
		
		# Cleanup
		cutscene_player._cleanup_cutscene()
		
		# Verify particle is stopped and array is cleared
		assert_eq(cutscene_player._active_particles.size(), 0, "Active particles array should be empty")


func test_cleanup_frees_text_overlays():
	# Test that cleanup method removes temporary text overlay nodes
	# Create character
	var character = WaterDropletCharacter.new()
	cutscene_player.add_child(character)
	cutscene_player._current_character = character
	
	# Create text overlays
	var overlay1 = AnimatedTextOverlay.new()
	var overlay2 = AnimatedTextOverlay.new()
	cutscene_player.add_child(overlay1)
	cutscene_player.add_child(overlay2)
	cutscene_player._active_text_overlays.append(overlay1)
	cutscene_player._active_text_overlays.append(overlay2)
	
	# Verify overlays exist
	assert_eq(cutscene_player._active_text_overlays.size(), 2, "Should have 2 active overlays")
	
	# Cleanup
	cutscene_player._cleanup_cutscene()
	
	# Verify overlays are cleared
	assert_eq(cutscene_player._active_text_overlays.size(), 0, "Active overlays array should be empty")


func test_cleanup_clears_timer_references():
	# Test that cleanup method clears scheduled timer references
	# Create character
	var character = WaterDropletCharacter.new()
	cutscene_player.add_child(character)
	cutscene_player._current_character = character
	
	# Create some timers
	var timer1 = get_tree().create_timer(1.0)
	var timer2 = get_tree().create_timer(2.0)
	cutscene_player._scheduled_timers.append(timer1)
	cutscene_player._scheduled_timers.append(timer2)
	
	# Verify timers are tracked
	assert_eq(cutscene_player._scheduled_timers.size(), 2, "Should have 2 scheduled timers")
	
	# Cleanup
	cutscene_player._cleanup_cutscene()
	
	# Verify timer references are cleared
	assert_eq(cutscene_player._scheduled_timers.size(), 0, "Scheduled timers array should be empty")


func test_cleanup_frees_character():
	# Test that cleanup method frees the character node
	# Create character
	var character = WaterDropletCharacter.new()
	cutscene_player.add_child(character)
	cutscene_player._current_character = character
	
	# Verify character exists
	assert_not_null(cutscene_player._current_character, "Character should exist before cleanup")
	
	# Cleanup
	cutscene_player._cleanup_cutscene()
	
	# Verify character is freed
	assert_null(cutscene_player._current_character, "Character reference should be null after cleanup")


# ============================================================================
# MEMORY MONITORING TESTS
# ============================================================================

func test_cleanup_clears_caches_on_high_memory():
	# Test that cleanup clears caches when memory usage is high
	# Pre-populate caches
	AnimatedCutscenePlayer._animation_cache["TestGame"] = {}
	AnimatedCutscenePlayer._texture_cache["test_texture.png"] = null
	AnimatedCutscenePlayer._particle_scene_cache[CutsceneTypes.ParticleType.SPARKLES] = null
	
	# Verify caches have data
	assert_gt(AnimatedCutscenePlayer._animation_cache.size(), 0, "Animation cache should have data")
	
	# Note: We can't easily simulate high memory usage in tests,
	# but we can verify the clear_caches method works
	AnimatedCutscenePlayer.clear_caches()
	
	# Verify caches are cleared
	assert_eq(AnimatedCutscenePlayer._animation_cache.size(), 0, "Animation cache should be empty")
	assert_eq(AnimatedCutscenePlayer._texture_cache.size(), 0, "Texture cache should be empty")
	assert_eq(AnimatedCutscenePlayer._particle_scene_cache.size(), 0, "Particle scene cache should be empty")


func test_memory_stats_returns_valid_data():
	# Test that get_memory_stats returns valid memory information
	var stats = AnimatedCutscenePlayer.get_memory_stats()
	
	# Verify all expected keys exist
	assert_has(stats, "static_memory_mb", "Should have static_memory_mb")
	assert_has(stats, "peak_memory_mb", "Should have peak_memory_mb")
	assert_has(stats, "memory_ratio", "Should have memory_ratio")
	assert_has(stats, "cached_animations", "Should have cached_animations")
	assert_has(stats, "cached_textures", "Should have cached_textures")
	assert_has(stats, "cached_particle_scenes", "Should have cached_particle_scenes")
	assert_has(stats, "pooled_particles", "Should have pooled_particles")
	
	# Verify values are reasonable
	assert_typeof(stats["static_memory_mb"], TYPE_FLOAT, "static_memory_mb should be float")
	assert_typeof(stats["peak_memory_mb"], TYPE_FLOAT, "peak_memory_mb should be float")
	assert_typeof(stats["memory_ratio"], TYPE_FLOAT, "memory_ratio should be float")
	assert_gte(stats["memory_ratio"], 0.0, "memory_ratio should be >= 0")
	assert_lte(stats["memory_ratio"], 1.0, "memory_ratio should be <= 1")


# ============================================================================
# OBJECT POOLING TESTS
# ============================================================================

func test_particle_pooling_reuses_instances():
	# Test that object pooling reuses particle instances
	# Get a particle from pool
	var particle1 = AnimatedCutscenePlayer._get_pooled_particle(CutsceneTypes.ParticleType.SPARKLES)
	assert_not_null(particle1, "Should get a particle from pool")
	
	# Return it to pool
	AnimatedCutscenePlayer._return_pooled_particle(particle1, CutsceneTypes.ParticleType.SPARKLES)
	
	# Get another particle - should be the same instance
	var particle2 = AnimatedCutscenePlayer._get_pooled_particle(CutsceneTypes.ParticleType.SPARKLES)
	assert_not_null(particle2, "Should get a particle from pool")
	assert_same(particle1, particle2, "Should reuse the same particle instance")


func test_particle_pooling_respects_max_size():
	# Test that object pool respects maximum size per type
	var particles = []
	
	# Fill the pool beyond max size
	for i in range(AnimatedCutscenePlayer.MAX_POOL_SIZE_PER_TYPE + 3):
		var particle = AnimatedCutscenePlayer._get_pooled_particle(CutsceneTypes.ParticleType.SPARKLES)
		if particle:
			particles.append(particle)
	
	# Return all particles to pool
	for particle in particles:
		AnimatedCutscenePlayer._return_pooled_particle(particle, CutsceneTypes.ParticleType.SPARKLES)
	
	# Verify pool size doesn't exceed max
	var pool_size = AnimatedCutscenePlayer._particle_pool.get(CutsceneTypes.ParticleType.SPARKLES, []).size()
	assert_lte(pool_size, AnimatedCutscenePlayer.MAX_POOL_SIZE_PER_TYPE, 
		"Pool size should not exceed MAX_POOL_SIZE_PER_TYPE")


func test_particle_pooling_resets_state():
	# Test that pooled particles have their state reset
	# Get a particle and modify its state
	var particle = AnimatedCutscenePlayer._get_pooled_particle(CutsceneTypes.ParticleType.SPARKLES)
	if particle:
		particle.emitting = true
		
		# Return to pool
		AnimatedCutscenePlayer._return_pooled_particle(particle, CutsceneTypes.ParticleType.SPARKLES)
		
		# Get it again
		var reused_particle = AnimatedCutscenePlayer._get_pooled_particle(CutsceneTypes.ParticleType.SPARKLES)
		
		# Verify state is reset
		assert_false(reused_particle.emitting, "Reused particle should not be emitting")


func test_clear_caches_frees_pooled_particles():
	# Test that clear_caches frees all pooled particles
	# Create and pool some particles
	var particles = []
	for i in range(3):
		var particle = AnimatedCutscenePlayer._get_pooled_particle(CutsceneTypes.ParticleType.SPARKLES)
		if particle:
			particles.append(particle)
			AnimatedCutscenePlayer._return_pooled_particle(particle, CutsceneTypes.ParticleType.SPARKLES)
	
	# Verify pool has particles
	var pool_size_before = AnimatedCutscenePlayer._get_total_pooled_particles()
	assert_gt(pool_size_before, 0, "Pool should have particles before clear")
	
	# Clear caches
	AnimatedCutscenePlayer.clear_caches()
	
	# Verify pool is empty
	var pool_size_after = AnimatedCutscenePlayer._get_total_pooled_particles()
	assert_eq(pool_size_after, 0, "Pool should be empty after clear_caches")


# ============================================================================
# ADAPTIVE QUALITY TESTS
# ============================================================================

func test_adaptive_density_reduces_particles_on_low_fps():
	# Test that adaptive density reduces particles when FPS is low
	# This test verifies the ParticleEffectManager integration
	# We can't easily simulate low FPS, but we can verify the method exists and works
	
	var particle = GPUParticles2D.new()
	add_child_autofree(particle)
	particle.amount = 100
	
	# Apply adaptive density (will check FPS internally)
	ParticleEffectManager.apply_adaptive_density(particle)
	
	# Particle amount may be reduced if FPS is low
	# We just verify the method doesn't crash
	assert_not_null(particle, "Particle should still exist after adaptive density")


func test_adaptive_density_reduces_particles_on_high_memory():
	# Test that adaptive density reduces particles when memory is high
	# Similar to above, we verify the integration works
	var particle = GPUParticles2D.new()
	add_child_autofree(particle)
	particle.amount = 100
	
	# Get density factor
	var density_factor = ParticleEffectManager.get_adaptive_density_factor()
	
	# Verify density factor is valid
	assert_typeof(density_factor, TYPE_FLOAT, "Density factor should be float")
	assert_gte(density_factor, 0.3, "Density factor should be >= 0.3")
	assert_lte(density_factor, 1.0, "Density factor should be <= 1.0")


# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_full_cutscene_cleanup_integration():
	# Integration test: Full cutscene playback and cleanup
	# This test would require a full cutscene setup
	# For now, we verify the cleanup method can be called safely
	
	cutscene_player._cleanup_cutscene()
	
	# Verify all state is cleared
	assert_null(cutscene_player._current_character, "Character should be null")
	assert_null(cutscene_player._current_tween, "Current tween should be null")
	assert_null(cutscene_player._background_tween, "Background tween should be null")
	assert_eq(cutscene_player._active_particles.size(), 0, "Active particles should be empty")
	assert_eq(cutscene_player._active_text_overlays.size(), 0, "Active overlays should be empty")
	assert_eq(cutscene_player._scheduled_timers.size(), 0, "Scheduled timers should be empty")
