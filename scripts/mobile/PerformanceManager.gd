extends Object
class_name PerformanceManager

## ═══════════════════════════════════════════════════════════════════
## PERFORMANCE MANAGER - MOBILE OPTIMIZATION
## ═══════════════════════════════════════════════════════════════════
## Static helper class for optimizing performance on mobile devices
## Provides methods for particle reduction, tween limiting, and texture optimization
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PARTICLE OPTIMIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Reduce particle count for mobile performance.
## Reduces the amount property of a particle system by the given factor.
## Typical reduction_factor is 0.5 (50% reduction) for mobile devices.
static func reduce_particles(particle_system: GPUParticles2D, reduction_factor: float) -> void:
	if not particle_system:
		push_warning("PerformanceManager.reduce_particles: particle_system is null")
		return

	if reduction_factor < 0.0 or reduction_factor > 1.0:
		push_warning("PerformanceManager.reduce_particles: reduction_factor must be between 0.0 and 1.0")
		return

	var original_amount = particle_system.amount
	particle_system.amount = int(original_amount * reduction_factor)

	# Also reduce emission rate if using process material
	if particle_system.process_material:
		var material = particle_system.process_material
		if material is ParticleProcessMaterial:
			material.emission_ring_radius = material.emission_ring_radius * reduction_factor

## Apply comprehensive mobile optimizations to a particle system.
## Reduces particle count by 50%, disables sub-emitters, and simplifies
## process material settings for better mobile performance.
static func optimize_particle_system_for_mobile(particle_system: GPUParticles2D) -> void:
	if not particle_system:
		return

	# Reduce particle count by 50%
	reduce_particles(particle_system, 0.5)

	# Disable sub-emitters on mobile
	particle_system.sub_emitter = NodePath()

	# Simplify process material if present
	if particle_system.process_material and particle_system.process_material is ParticleProcessMaterial:
		var material = particle_system.process_material as ParticleProcessMaterial
		# Disable expensive features
		material.turbulence_enabled = false
		material.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TWEEN OPTIMIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

static var _active_tweens: Array[Tween] = []
static var _max_tweens: int = 20  # Default limit

## Set the maximum number of concurrent tweens allowed.
static func set_max_tweens(max_count: int) -> void:
	_max_tweens = max(1, max_count)

## Create a tween with automatic limiting.
## Creates a new tween and tracks it. If the maximum number of tweens
## is exceeded, the oldest tween is killed to maintain performance.
static func create_managed_tween(scene_tree: SceneTree) -> Tween:
	if not scene_tree:
		push_error("PerformanceManager.create_managed_tween: scene_tree is null")
		return null

	# Clean up finished tweens
	_cleanup_finished_tweens()

	# If at limit, kill oldest tween
	if _active_tweens.size() >= _max_tweens:
		var oldest = _active_tweens[0]
		if oldest and oldest.is_valid():
			oldest.kill()
		_active_tweens.remove_at(0)

	# Create new tween
	var tween = scene_tree.create_tween()
	_active_tweens.append(tween)

	return tween

## Remove finished or invalid tweens from tracking.
static func _cleanup_finished_tweens() -> void:
	_active_tweens = _active_tweens.filter(func(t): return t and t.is_valid() and t.is_running())

## Get the current number of active tweens.
static func get_active_tween_count() -> int:
	_cleanup_finished_tweens()
	return _active_tweens.size()

## Kill all tracked tweens immediately.
## Useful for cleanup or when transitioning between scenes.
static func kill_all_tweens() -> void:
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEXTURE OPTIMIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Verify that a texture uses mobile-optimized compression.
## Checks if the texture uses ETC2 or ASTC compression formats
## which are optimized for mobile GPUs.
static func verify_texture_compression(texture: Texture2D) -> bool:
	if not texture:
		return false

	# For CompressedTexture2D, check the format
	if texture is CompressedTexture2D:
		var format = texture.get_format()
		# ETC2 and ASTC formats are mobile-optimized
		var mobile_formats = [
			Image.FORMAT_ETC2_R11,
			Image.FORMAT_ETC2_R11S,
			Image.FORMAT_ETC2_RG11,
			Image.FORMAT_ETC2_RG11S,
			Image.FORMAT_ETC2_RGB8,
			Image.FORMAT_ETC2_RGBA8,
			Image.FORMAT_ETC2_RGB8A1,
			Image.FORMAT_ASTC_4x4,
			Image.FORMAT_ASTC_4x4_HDR,
			Image.FORMAT_ASTC_8x8,
			Image.FORMAT_ASTC_8x8_HDR,
		]
		return format in mobile_formats

	return false

## Scan scene tree and report texture optimization status.
## Recursively checks all Sprite2D and TextureRect nodes for
## mobile-optimized texture compression.
static func optimize_textures_for_mobile(root: Node) -> Dictionary:
	var stats = {
		"total_textures": 0,
		"optimized_textures": 0,
		"unoptimized_nodes": []
	}

	_scan_textures_recursive(root, stats)

	return stats

## Recursively scan for textures in the scene tree.
static func _scan_textures_recursive(node: Node, stats: Dictionary) -> void:
	# Check Sprite2D nodes
	if node is Sprite2D:
		var sprite = node as Sprite2D
		if sprite.texture:
			stats["total_textures"] += 1
			if verify_texture_compression(sprite.texture):
				stats["optimized_textures"] += 1
			else:
				stats["unoptimized_nodes"].append(node.get_path())

	# Check TextureRect nodes
	if node is TextureRect:
		var tex_rect = node as TextureRect
		if tex_rect.texture:
			stats["total_textures"] += 1
			if verify_texture_compression(tex_rect.texture):
				stats["optimized_textures"] += 1
			else:
				stats["unoptimized_nodes"].append(node.get_path())

	# Recurse to children
	for child in node.get_children():
		_scan_textures_recursive(child, stats)
