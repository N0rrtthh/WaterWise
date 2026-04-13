extends Control

## Interactive demo for WaterDropletCharacter
## Press keys to test different features

@onready var character: WaterDropletCharacter = $Character

var current_particle_index: int = 0
var particle_types = [
	CutsceneTypes.ParticleType.SPARKLES,
	CutsceneTypes.ParticleType.WATER_DROPS,
	CutsceneTypes.ParticleType.STARS,
	CutsceneTypes.ParticleType.SMOKE,
	CutsceneTypes.ParticleType.SPLASH
]


func _ready() -> void:
	print("\n=== Water Droplet Character Demo ===")
	print("Controls:")
	print("  1-6: Change expression")
	print("  Q: Squash")
	print("  W: Stretch")
	print("  E: Reset")
	print("  Space: Spawn particles (cycles through types)")
	print("=====================================\n")


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	
	match event.keycode:
		KEY_1:
			character.set_expression(CutsceneTypes.CharacterExpression.HAPPY)
			print("Expression: HAPPY")
		KEY_2:
			character.set_expression(CutsceneTypes.CharacterExpression.SAD)
			print("Expression: SAD")
		KEY_3:
			character.set_expression(CutsceneTypes.CharacterExpression.SURPRISED)
			print("Expression: SURPRISED")
		KEY_4:
			character.set_expression(CutsceneTypes.CharacterExpression.DETERMINED)
			print("Expression: DETERMINED")
		KEY_5:
			character.set_expression(CutsceneTypes.CharacterExpression.WORRIED)
			print("Expression: WORRIED")
		KEY_6:
			character.set_expression(CutsceneTypes.CharacterExpression.EXCITED)
			print("Expression: EXCITED")
		KEY_Q:
			character.apply_squash_stretch(0.5, 1.0)
			print("Applied squash")
		KEY_W:
			character.apply_squash_stretch(1.0, 1.5)
			print("Applied stretch")
		KEY_E:
			character.reset()
			print("Reset character")
		KEY_SPACE:
			var particle_type = particle_types[current_particle_index]
			character.spawn_particles(particle_type, 2.0)
			print("Spawned particles: " + str(particle_type))
			current_particle_index = (current_particle_index + 1) % particle_types.size()
		KEY_ESCAPE:
			get_tree().quit()
