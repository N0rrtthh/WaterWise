class_name WaterDropletCharacter
extends Node2D

## Animated water droplet character with expressions and deformation support
##
## This character is used in all cutscenes and supports:
## - Multiple facial expressions (happy, sad, surprised, determined, worried, excited)
## - Body deformation for squash and stretch effects
## - Particle effect spawning integration
## - Smooth anti-aliasing rendering

signal expression_changed(new_expression: CutsceneTypes.CharacterExpression)

# Character state
var current_expression: CutsceneTypes.CharacterExpression = CutsceneTypes.CharacterExpression.DETERMINED
var deformation_enabled: bool = true
var base_scale: Vector2 = Vector2.ONE

# Child nodes (set up in scene)
@onready var body_sprite: Sprite2D = $BodySprite
@onready var expression_sprite: Sprite2D = $ExpressionSprite
@onready var particle_container: Node2D = $ParticleContainer

# Expression texture paths
const EXPRESSION_PATHS = {
	CutsceneTypes.CharacterExpression.HAPPY: "res://assets/characters/expressions/happy.png",
	CutsceneTypes.CharacterExpression.SAD: "res://assets/characters/expressions/sad.png",
	CutsceneTypes.CharacterExpression.SURPRISED: "res://assets/characters/expressions/surprised.png",
	CutsceneTypes.CharacterExpression.DETERMINED: "res://assets/characters/expressions/determined.png",
	CutsceneTypes.CharacterExpression.WORRIED: "res://assets/characters/expressions/worried.png",
	CutsceneTypes.CharacterExpression.EXCITED: "res://assets/characters/expressions/excited.png"
}

# Texture atlas support
const ATLAS_PATH = "res://assets/characters/atlas/droplet_atlas.png"
const ATLAS_REGIONS = {
	CutsceneTypes.CharacterExpression.HAPPY: Rect2(0, 0, 512, 512),
	CutsceneTypes.CharacterExpression.SAD: Rect2(512, 0, 512, 512),
	CutsceneTypes.CharacterExpression.SURPRISED: Rect2(1024, 0, 512, 512),
	CutsceneTypes.CharacterExpression.DETERMINED: Rect2(0, 512, 512, 512),
	CutsceneTypes.CharacterExpression.WORRIED: Rect2(512, 512, 512, 512),
	CutsceneTypes.CharacterExpression.EXCITED: Rect2(1024, 512, 512, 512)
}

# Atlas texture (loaded once if available)
static var _atlas_texture: Texture2D = null
static var _use_atlas: bool = false

# Particle effect scene paths
const PARTICLE_SCENES = {
	CutsceneTypes.ParticleType.SPARKLES: "res://scenes/particles/Sparkles.tscn",
	CutsceneTypes.ParticleType.WATER_DROPS: "res://scenes/particles/WaterDrops.tscn",
	CutsceneTypes.ParticleType.STARS: "res://scenes/particles/Stars.tscn",
	CutsceneTypes.ParticleType.SMOKE: "res://scenes/particles/Smoke.tscn",
	CutsceneTypes.ParticleType.SPLASH: "res://scenes/particles/Splash.tscn"
}


func _ready() -> void:
	# Initialize atlas texture if available (only once per class)
	if _atlas_texture == null and ResourceLoader.exists(ATLAS_PATH):
		_atlas_texture = load(ATLAS_PATH)
		_use_atlas = (_atlas_texture != null)
		if _use_atlas:
			# Enable texture region for atlas usage
			if expression_sprite:
				expression_sprite.region_enabled = true
	
	# Store base scale for deformation calculations
	base_scale = scale
	
	# Set initial expression
	set_expression(current_expression)


## Preload the texture atlas for character sprites
## This should be called during game initialization for better performance
static func preload_atlas() -> void:
	if _atlas_texture == null and ResourceLoader.exists(ATLAS_PATH):
		_atlas_texture = load(ATLAS_PATH)
		_use_atlas = (_atlas_texture != null)


## Set character expression
## @param expression: The expression to display
func set_expression(expression: CutsceneTypes.CharacterExpression) -> void:
	if current_expression == expression:
		return
	
	current_expression = expression
	
	# Load and apply expression texture with error handling (Requirement 12.4)
	if expression_sprite:
		if _use_atlas and _atlas_texture and ATLAS_REGIONS.has(expression):
			# Use texture atlas for better performance
			expression_sprite.texture = _atlas_texture
			expression_sprite.region_enabled = true
			expression_sprite.region_rect = ATLAS_REGIONS[expression]
		elif EXPRESSION_PATHS.has(expression):
			# Fall back to individual textures
			var texture_path = EXPRESSION_PATHS[expression]
			if ResourceLoader.exists(texture_path):
				var texture = load(texture_path)
				if texture:
					expression_sprite.texture = texture
					expression_sprite.region_enabled = false
				else:
					push_warning("[WaterDropletCharacter] Failed to load expression texture: " + texture_path + 
						". Character will display without expression texture.")
			else:
				push_warning("[WaterDropletCharacter] Expression texture not found: " + texture_path + 
					". Character will display without expression texture.")
		else:
			push_warning("[WaterDropletCharacter] Unknown expression type: " + str(expression) + 
				". Character will display without expression texture.")
	
	expression_changed.emit(expression)


## Get current expression
## @return: Current expression enum value
func get_expression() -> CutsceneTypes.CharacterExpression:
	return current_expression


## Enable or disable body deformation
## @param enabled: Whether deformation should be enabled
func set_deformation_enabled(enabled: bool) -> void:
	deformation_enabled = enabled
	
	# Reset to base scale if disabling
	if not enabled:
		scale = base_scale


## Apply squash and stretch effect to the character
## This modulates the scale to create cartoon-style deformation
## @param squash: Vertical compression factor (0.0 = fully squashed, 1.0 = normal)
## @param stretch: Vertical stretch factor (1.0 = normal, 2.0 = double height)
func apply_squash_stretch(squash: float, stretch: float) -> void:
	if not deformation_enabled:
		return
	
	# Squash: compress vertically, expand horizontally to preserve volume
	# Stretch: extend vertically, compress horizontally to preserve volume
	var vertical_scale = base_scale.y * squash * stretch
	var horizontal_scale = base_scale.x / (squash * stretch)
	
	# Clamp to reasonable values to prevent extreme deformation
	vertical_scale = clamp(vertical_scale, base_scale.y * 0.3, base_scale.y * 2.5)
	horizontal_scale = clamp(horizontal_scale, base_scale.x * 0.3, base_scale.x * 2.5)
	
	scale = Vector2(horizontal_scale, vertical_scale)


## Spawn a particle effect at the character's position
## @param effect_type: The type of particle effect to spawn
## @param duration: How long the particles should emit (0 = one-shot)
## @return: The spawned particle node, or null if failed
func spawn_particles(effect_type: CutsceneTypes.ParticleType, duration: float = 1.0) -> Node:
	if AccessibilityManager and AccessibilityManager.has_method("should_show_particles"):
		if not AccessibilityManager.should_show_particles():
			return null
	elif SaveManager and SaveManager.has_method("is_particles_enabled"):
		if not SaveManager.is_particles_enabled():
			return null

	if not particle_container:
		push_warning("[WaterDropletCharacter] Particle container not found. Skipping particle effect.")
		return null
	
	if not PARTICLE_SCENES.has(effect_type):
		push_warning("[WaterDropletCharacter] Unknown particle type: " + str(effect_type) + 
			". Skipping particle effect.")
		return null
	
	var scene_path = PARTICLE_SCENES[effect_type]
	if not ResourceLoader.exists(scene_path):
		push_warning("[WaterDropletCharacter] Particle scene not found: " + scene_path + 
			". Skipping particle effect (Requirement 12.4: graceful degradation for missing particle textures).")
		return null
	
	# Load and instantiate particle scene with error handling
	var particle_scene = load(scene_path)
	if not particle_scene:
		push_warning("[WaterDropletCharacter] Failed to load particle scene: " + scene_path + 
			". Skipping particle effect.")
		return null
	
	var particles = particle_scene.instantiate()
	if not particles:
		push_warning("[WaterDropletCharacter] Failed to instantiate particle scene: " + scene_path + 
			". Skipping particle effect.")
		return null
	
	particle_container.add_child(particles)
	
	# Configure particle emission
	if particles is GPUParticles2D:
		particles.emitting = true
		particles.one_shot = (duration <= 0.0)
		
		# Auto-cleanup after duration
		if duration > 0.0:
			await get_tree().create_timer(duration).timeout
			if is_instance_valid(particles):
				particles.emitting = false
				# Wait for particles to finish, then remove
				await get_tree().create_timer(particles.lifetime).timeout
				if is_instance_valid(particles):
					particles.queue_free()
	
	return particles


## Reset character to default state
func reset() -> void:
	set_expression(CutsceneTypes.CharacterExpression.DETERMINED)
	scale = base_scale
	rotation = 0.0
	position = Vector2.ZERO
	
	# Clear all active particles
	if particle_container:
		for child in particle_container.get_children():
			child.queue_free()
