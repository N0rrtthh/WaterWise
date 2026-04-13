extends Control

## Visual test for background color transitions in AnimatedCutscenePlayer
## This test demonstrates smooth color interpolation during cutscene playback

var cutscene_player: AnimatedCutscenePlayer
var test_label: Label


func _ready():
	# Set up UI
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Background Color Transition Visual Test"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	# Status label
	test_label = Label.new()
	test_label.text = "Click buttons to test background color transitions"
	test_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(test_label)
	
	# Button container
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 10)
	vbox.add_child(button_container)
	
	# Test buttons
	var test1_btn = Button.new()
	test1_btn.text = "Test 1: Dark to Light"
	test1_btn.pressed.connect(_test_dark_to_light)
	button_container.add_child(test1_btn)
	
	var test2_btn = Button.new()
	test2_btn.text = "Test 2: Green to Red"
	test2_btn.pressed.connect(_test_green_to_red)
	button_container.add_child(test2_btn)
	
	var test3_btn = Button.new()
	test3_btn.text = "Test 3: Blue to Yellow"
	test3_btn.pressed.connect(_test_blue_to_yellow)
	button_container.add_child(test3_btn)
	
	# Cutscene player container
	var player_container = CenterContainer.new()
	player_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(player_container)
	
	# Create cutscene player
	cutscene_player = AnimatedCutscenePlayer.new()
	cutscene_player.custom_minimum_size = Vector2(800, 600)
	player_container.add_child(cutscene_player)


func _test_dark_to_light():
	test_label.text = "Testing: Dark (black) to Light (white) transition"
	_run_test(Color(0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0))


func _test_green_to_red():
	test_label.text = "Testing: Green to Red transition"
	_run_test(Color(0.0, 0.8, 0.0), Color(0.8, 0.0, 0.0))


func _test_blue_to_yellow():
	test_label.text = "Testing: Blue to Yellow transition"
	_run_test(Color(0.0, 0.0, 0.8), Color(0.8, 0.8, 0.0))


func _run_test(start_color: Color, end_color: Color):
	# Set initial background color
	var background = cutscene_player.get_node_or_null("Background")
	if background:
		background.color = start_color
	
	# Create test configuration
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "VisualTest"
	config.cutscene_type = CutsceneTypes.CutsceneType.WIN
	config.duration = 3.0  # 3 second transition
	config.background_color = end_color
	config.character.expression = CutsceneTypes.CharacterExpression.HAPPY
	
	# Create animation keyframes
	var keyframe1 = CutsceneDataModels.Keyframe.new(0.0)
	var scale_transform1 = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(0.3, 0.3),
		false
	)
	keyframe1.add_transform(scale_transform1)
	keyframe1.easing = CutsceneTypes.Easing.EASE_OUT
	
	var keyframe2 = CutsceneDataModels.Keyframe.new(1.5)
	var scale_transform2 = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.2, 1.2),
		false
	)
	keyframe2.add_transform(scale_transform2)
	keyframe2.easing = CutsceneTypes.Easing.BOUNCE
	
	var keyframe3 = CutsceneDataModels.Keyframe.new(3.0)
	var scale_transform3 = CutsceneDataModels.Transform.new(
		CutsceneTypes.TransformType.SCALE,
		Vector2(1.0, 1.0),
		false
	)
	keyframe3.add_transform(scale_transform3)
	keyframe3.easing = CutsceneTypes.Easing.EASE_IN_OUT
	
	config.add_keyframe(keyframe1)
	config.add_keyframe(keyframe2)
	config.add_keyframe(keyframe3)
	
	# Add sparkle particles
	var particle = CutsceneDataModels.ParticleEffect.new(1.5, CutsceneTypes.ParticleType.SPARKLES)
	particle.duration = 1.5
	config.add_particle(particle)
	
	# Play cutscene
	cutscene_player.play_cutscene("VisualTest", CutsceneTypes.CutsceneType.WIN)
	
	# Wait for completion
	await cutscene_player.cutscene_finished
	test_label.text = "Test complete! Background transitioned from " + _color_to_string(start_color) + " to " + _color_to_string(end_color)


func _color_to_string(color: Color) -> String:
	return "RGB(%.2f, %.2f, %.2f)" % [color.r, color.g, color.b]
