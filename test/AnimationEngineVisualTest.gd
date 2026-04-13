extends Node2D

## Visual test for AnimationEngine
## Run this scene in the Godot editor to see animations in action

var character: WaterDropletCharacter
var test_index: int = 0
var tests: Array[Dictionary] = []


func _ready() -> void:
	# Load and instantiate character
	var character_scene = load("res://scenes/cutscenes/WaterDropletCharacter.tscn")
	if not character_scene:
		print("ERROR: Could not load WaterDropletCharacter scene")
		return
	
	character = character_scene.instantiate()
	add_child(character)
	character.position = Vector2(400, 300)
	
	# Define tests
	tests = [
		{
			"name": "Position Transform (Ease Out)",
			"func": test_position_transform
		},
		{
			"name": "Rotation Transform (Bounce)",
			"func": test_rotation_transform
		},
		{
			"name": "Scale Transform (Elastic)",
			"func": test_scale_transform
		},
		{
			"name": "Parallel Composition",
			"func": test_parallel_composition
		},
		{
			"name": "Keyframe Sequence (Win Animation)",
			"func": test_keyframe_sequence
		}
	]
	
	print("\n" + "=".repeat(60))
	print("ANIMATION ENGINE VISUAL TEST")
	print("=".repeat(60))
	print("Press SPACE to run next test")
	print("Press R to reset character")
	print("=".repeat(60) + "\n")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			run_next_test()
		elif event.keycode == KEY_R:
			reset_character()


func run_next_test() -> void:
	if test_index >= tests.size():
		print("\nAll tests complete! Press SPACE to restart.")
		test_index = 0
		return
	
	var test = tests[test_index]
	print("\n[Test " + str(test_index + 1) + "/" + str(tests.size()) + "] " + test["name"])
	
	reset_character()
	await get_tree().create_timer(0.5).timeout
	
	await test["func"].call()
	
	test_index += 1
	print("  ✓ Complete! Press SPACE for next test.")


func reset_character() -> void:
	character.reset()
	character.position = Vector2(400, 300)
	character.rotation = 0.0
	character.scale = Vector2.ONE


func test_position_transform() -> void:
	print("  Moving character to (600, 200) with EASE_OUT...")
	
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.POSITION
	transform.value = Vector2(600, 200)
	transform.relative = false
	
	var tween = AnimationEngine.apply_transform(
		character,
		transform,
		1.0,
		CutsceneTypes.Easing.EASE_OUT
	)
	
	if tween:
		await tween.finished


func test_rotation_transform() -> void:
	print("  Rotating character 360 degrees with BOUNCE...")
	
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.ROTATION
	transform.value = PI * 2
	transform.relative = false
	
	var tween = AnimationEngine.apply_transform(
		character,
		transform,
		1.5,
		CutsceneTypes.Easing.BOUNCE
	)
	
	if tween:
		await tween.finished


func test_scale_transform() -> void:
	print("  Scaling character to 2x with ELASTIC...")
	
	var transform = CutsceneDataModels.Transform.new()
	transform.type = CutsceneTypes.TransformType.SCALE
	transform.value = Vector2(2.0, 2.0)
	transform.relative = false
	
	var tween = AnimationEngine.apply_transform(
		character,
		transform,
		1.5,
		CutsceneTypes.Easing.ELASTIC
	)
	
	if tween:
		await tween.finished


func test_parallel_composition() -> void:
	print("  Applying position, rotation, and scale simultaneously...")
	
	var transforms: Array[CutsceneDataModels.Transform] = []
	
	# Position
	var pos_transform = CutsceneDataModels.Transform.new()
	pos_transform.type = CutsceneTypes.TransformType.POSITION
	pos_transform.value = Vector2(200, 400)
	pos_transform.relative = false
	transforms.append(pos_transform)
	
	# Rotation
	var rot_transform = CutsceneDataModels.Transform.new()
	rot_transform.type = CutsceneTypes.TransformType.ROTATION
	rot_transform.value = PI
	rot_transform.relative = false
	transforms.append(rot_transform)
	
	# Scale
	var scale_transform = CutsceneDataModels.Transform.new()
	scale_transform.type = CutsceneTypes.TransformType.SCALE
	scale_transform.value = Vector2(1.5, 1.5)
	scale_transform.relative = false
	transforms.append(scale_transform)
	
	var tween = AnimationEngine.compose_transforms(character, transforms, 1.5)
	
	if tween:
		await tween.finished


func test_keyframe_sequence() -> void:
	print("  Playing win animation sequence...")
	
	character.set_expression(CutsceneTypes.CharacterExpression.HAPPY)
	
	var keyframes: Array[CutsceneDataModels.Keyframe] = []
	
	# Keyframe 1: Start small (time 0.0)
	var kf1 = CutsceneDataModels.Keyframe.new(0.0)
	var kf1_scale = CutsceneDataModels.Transform.new()
	kf1_scale.type = CutsceneTypes.TransformType.SCALE
	kf1_scale.value = Vector2(0.3, 0.3)
	kf1_scale.relative = false
	kf1.add_transform(kf1_scale)
	kf1.easing = CutsceneTypes.Easing.EASE_OUT
	keyframes.append(kf1)
	
	# Keyframe 2: Pop to large (time 0.5)
	var kf2 = CutsceneDataModels.Keyframe.new(0.5)
	var kf2_scale = CutsceneDataModels.Transform.new()
	kf2_scale.type = CutsceneTypes.TransformType.SCALE
	kf2_scale.value = Vector2(1.3, 1.3)
	kf2_scale.relative = false
	kf2.add_transform(kf2_scale)
	var kf2_rot = CutsceneDataModels.Transform.new()
	kf2_rot.type = CutsceneTypes.TransformType.ROTATION
	kf2_rot.value = 0.3
	kf2_rot.relative = false
	kf2.add_transform(kf2_rot)
	kf2.easing = CutsceneTypes.Easing.BOUNCE
	keyframes.append(kf2)
	
	# Keyframe 3: Settle to normal (time 1.5)
	var kf3 = CutsceneDataModels.Keyframe.new(1.5)
	var kf3_scale = CutsceneDataModels.Transform.new()
	kf3_scale.type = CutsceneTypes.TransformType.SCALE
	kf3_scale.value = Vector2(1.0, 1.0)
	kf3_scale.relative = false
	kf3.add_transform(kf3_scale)
	var kf3_rot = CutsceneDataModels.Transform.new()
	kf3_rot.type = CutsceneTypes.TransformType.ROTATION
	kf3_rot.value = 0.0
	kf3_rot.relative = false
	kf3.add_transform(kf3_rot)
	kf3.easing = CutsceneTypes.Easing.EASE_IN_OUT
	keyframes.append(kf3)
	
	var tween = AnimationEngine.animate(character, keyframes, 2.0)
	
	# Spawn particles at bounce
	await get_tree().create_timer(0.5).timeout
	character.spawn_particles(CutsceneTypes.ParticleType.SPARKLES, 1.5)
	
	if tween:
		await tween.finished
