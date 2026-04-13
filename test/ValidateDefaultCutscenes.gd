extends Node

## Validation script for default cutscene configurations
## Tests that all three default cutscenes parse and validate correctly
## Feature: animated-cutscenes
## Tests Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.2

var test_passed: int = 0
var test_failed: int = 0

func _ready():
	print("\n" + "=".repeat(60))
	print("DEFAULT CUTSCENE VALIDATION TEST")
	print("=".repeat(60) + "\n")
	
	test_win_cutscene()
	test_fail_cutscene()
	test_intro_cutscene()
	
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("=".repeat(60))
	print("Passed: " + str(test_passed))
	print("Failed: " + str(test_failed))
	
	if test_failed == 0:
		print("\n✅ ALL TESTS PASSED!")
	else:
		print("\n❌ SOME TESTS FAILED")
	
	# Exit after validation
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func test_win_cutscene():
	print("TEST: Win Cutscene Configuration")
	var config_path = "res://data/cutscenes/default/win.json"
	
	var config = CutsceneParser.parse_config(config_path)
	
	if config == null:
		_fail("Could not parse win.json")
		return
	
	var validation = CutsceneParser.validate_config(config)
	
	if validation.has_errors():
		_fail("Win cutscene validation failed:")
		for error in validation.errors:
			print("    - " + error)
		return
	
	# Verify specific requirements
	if config.cutscene_type != CutsceneTypes.CutsceneType.WIN:
		_fail("Win cutscene type is incorrect")
		return
	
	if config.character.expression != CutsceneTypes.CharacterExpression.HAPPY:
		_fail("Win cutscene should have happy expression")
		return
	
	if config.particles.is_empty():
		_fail("Win cutscene should have sparkle particles")
		return
	
	if config.particles[0].type != CutsceneTypes.ParticleType.SPARKLES:
		_fail("Win cutscene should have sparkles particle type")
		return
	
	if config.audio_cues.size() < 2:
		_fail("Win cutscene should have success audio cues")
		return
	
	_pass("Win cutscene is valid")
	print("  Duration: " + str(config.duration) + "s")
	print("  Keyframes: " + str(config.keyframes.size()))
	print("  Expression: HAPPY")
	print("  Particles: SPARKLES")


func test_fail_cutscene():
	print("\nTEST: Fail Cutscene Configuration")
	var config_path = "res://data/cutscenes/default/fail.json"
	
	var config = CutsceneParser.parse_config(config_path)
	
	if config == null:
		_fail("Could not parse fail.json")
		return
	
	var validation = CutsceneParser.validate_config(config)
	
	if validation.has_errors():
		_fail("Fail cutscene validation failed:")
		for error in validation.errors:
			print("    - " + error)
		return
	
	# Verify specific requirements
	if config.cutscene_type != CutsceneTypes.CutsceneType.FAIL:
		_fail("Fail cutscene type is incorrect")
		return
	
	if config.character.expression != CutsceneTypes.CharacterExpression.SAD:
		_fail("Fail cutscene should have sad expression")
		return
	
	if config.particles.is_empty():
		_fail("Fail cutscene should have smoke particles")
		return
	
	if config.particles[0].type != CutsceneTypes.ParticleType.SMOKE:
		_fail("Fail cutscene should have smoke particle type")
		return
	
	if config.audio_cues.size() < 2:
		_fail("Fail cutscene should have failure audio cues")
		return
	
	_pass("Fail cutscene is valid")
	print("  Duration: " + str(config.duration) + "s")
	print("  Keyframes: " + str(config.keyframes.size()))
	print("  Expression: SAD")
	print("  Particles: SMOKE")


func test_intro_cutscene():
	print("\nTEST: Intro Cutscene Configuration")
	var config_path = "res://data/cutscenes/default/intro.json"
	
	var config = CutsceneParser.parse_config(config_path)
	
	if config == null:
		_fail("Could not parse intro.json")
		return
	
	var validation = CutsceneParser.validate_config(config)
	
	if validation.has_errors():
		_fail("Intro cutscene validation failed:")
		for error in validation.errors:
			print("    - " + error)
		return
	
	# Verify specific requirements
	if config.cutscene_type != CutsceneTypes.CutsceneType.INTRO:
		_fail("Intro cutscene type is incorrect")
		return
	
	if config.character.expression != CutsceneTypes.CharacterExpression.DETERMINED:
		_fail("Intro cutscene should have determined expression")
		return
	
	if not config.particles.is_empty():
		_fail("Intro cutscene should have no particles")
		return
	
	if config.audio_cues.size() < 2:
		_fail("Intro cutscene should have intro audio cues")
		return
	
	_pass("Intro cutscene is valid")
	print("  Duration: " + str(config.duration) + "s")
	print("  Keyframes: " + str(config.keyframes.size()))
	print("  Expression: DETERMINED")
	print("  Particles: NONE")


func _pass(message: String):
	test_passed += 1
	print("  ✅ PASS: " + message)


func _fail(message: String):
	test_failed += 1
	print("  ❌ FAIL: " + message)
