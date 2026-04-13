extends GutTest

## Unit tests for text overlay animation system
##
## Tests cover:
## - TextOverlay data model serialization
## - AnimatedTextOverlay component animations
## - Text overlay scheduling in AnimatedCutscenePlayer
## - Different animation types (fade, slide, bounce)
## - Positioning (top, center, bottom)
## - Styling (font size, color)

# Test TextOverlay data model creation
func test_text_overlay_creation():
	var overlay = CutsceneDataModels.TextOverlay.new("Test Text", 1.0)
	
	assert_eq(overlay.text, "Test Text", "Text should be set")
	assert_eq(overlay.time, 1.0, "Time should be set")
	assert_eq(overlay.animation_type, CutsceneTypes.TextAnimationType.FADE_IN, "Default animation type should be FADE_IN")
	assert_eq(overlay.duration, 1.0, "Default duration should be 1.0")
	assert_eq(overlay.position, CutsceneTypes.TextPosition.CENTER, "Default position should be CENTER")
	assert_eq(overlay.font_size, 32, "Default font size should be 32")
	assert_eq(overlay.color, Color.WHITE, "Default color should be WHITE")


# Test TextOverlay serialization
func test_text_overlay_serialization():
	var overlay = CutsceneDataModels.TextOverlay.new("Hello World", 0.5)
	overlay.animation_type = CutsceneTypes.TextAnimationType.SLIDE_IN
	overlay.duration = 2.0
	overlay.position = CutsceneTypes.TextPosition.TOP
	overlay.font_size = 48
	overlay.color = Color.YELLOW
	
	var dict = overlay.to_dict()
	
	assert_eq(dict["text"], "Hello World", "Text should serialize")
	assert_eq(dict["time"], 0.5, "Time should serialize")
	assert_eq(dict["animation_type"], "slide_in", "Animation type should serialize")
	assert_eq(dict["duration"], 2.0, "Duration should serialize")
	assert_eq(dict["position"], "top", "Position should serialize")
	assert_eq(dict["font_size"], 48, "Font size should serialize")
	assert_true(dict.has("color"), "Color should be present")


# Test TextOverlay deserialization
func test_text_overlay_deserialization():
	var dict = {
		"text": "Test Message",
		"time": 1.5,
		"animation_type": "bounce_in",
		"duration": 2.5,
		"position": "bottom",
		"font_size": 64,
		"color": "#ff0000"
	}
	
	var overlay = CutsceneDataModels.TextOverlay.from_dict(dict)
	
	assert_eq(overlay.text, "Test Message", "Text should deserialize")
	assert_eq(overlay.time, 1.5, "Time should deserialize")
	assert_eq(overlay.animation_type, CutsceneTypes.TextAnimationType.BOUNCE_IN, "Animation type should deserialize")
	assert_eq(overlay.duration, 2.5, "Duration should deserialize")
	assert_eq(overlay.position, CutsceneTypes.TextPosition.BOTTOM, "Position should deserialize")
	assert_eq(overlay.font_size, 64, "Font size should deserialize")
	assert_eq(overlay.color, Color.RED, "Color should deserialize")


# Test TextOverlay round-trip serialization
func test_text_overlay_round_trip():
	var original = CutsceneDataModels.TextOverlay.new("Round Trip", 0.8)
	original.animation_type = CutsceneTypes.TextAnimationType.FADE_IN
	original.duration = 1.5
	original.position = CutsceneTypes.TextPosition.CENTER
	original.font_size = 40
	original.color = Color.CYAN
	
	var dict = original.to_dict()
	var restored = CutsceneDataModels.TextOverlay.from_dict(dict)
	
	assert_eq(restored.text, original.text, "Text should survive round-trip")
	assert_eq(restored.time, original.time, "Time should survive round-trip")
	assert_eq(restored.animation_type, original.animation_type, "Animation type should survive round-trip")
	assert_eq(restored.duration, original.duration, "Duration should survive round-trip")
	assert_eq(restored.position, original.position, "Position should survive round-trip")
	assert_eq(restored.font_size, original.font_size, "Font size should survive round-trip")
	assert_approximately(restored.color.r, original.color.r, 0.01, "Color red should survive round-trip")
	assert_approximately(restored.color.g, original.color.g, 0.01, "Color green should survive round-trip")
	assert_approximately(restored.color.b, original.color.b, 0.01, "Color blue should survive round-trip")


# Test CutsceneConfig with text overlays
func test_cutscene_config_with_text_overlays():
	var config = CutsceneDataModels.CutsceneConfig.new()
	
	var overlay1 = CutsceneDataModels.TextOverlay.new("First", 0.5)
	var overlay2 = CutsceneDataModels.TextOverlay.new("Second", 1.5)
	
	config.add_text_overlay(overlay1)
	config.add_text_overlay(overlay2)
	
	assert_eq(config.text_overlays.size(), 2, "Should have 2 text overlays")
	assert_eq(config.text_overlays[0].text, "First", "First overlay should be correct")
	assert_eq(config.text_overlays[1].text, "Second", "Second overlay should be correct")


# Test CutsceneConfig serialization with text overlays
func test_cutscene_config_serialization_with_overlays():
	var config = CutsceneDataModels.CutsceneConfig.new()
	config.minigame_key = "TestGame"
	
	var overlay = CutsceneDataModels.TextOverlay.new("Test", 1.0)
	overlay.animation_type = CutsceneTypes.TextAnimationType.SLIDE_IN
	config.add_text_overlay(overlay)
	
	var dict = config.to_dict()
	
	assert_true(dict.has("text_overlays"), "Should have text_overlays field")
	assert_eq(dict["text_overlays"].size(), 1, "Should have 1 text overlay")
	assert_eq(dict["text_overlays"][0]["text"], "Test", "Overlay text should serialize")


# Test CutsceneConfig deserialization with text overlays
func test_cutscene_config_deserialization_with_overlays():
	var dict = {
		"version": "1.0",
		"minigame_key": "TestGame",
		"cutscene_type": "win",
		"duration": 2.0,
		"character": {
			"expression": "happy",
			"deformation_enabled": true
		},
		"background_color": "#0a1e0f",
		"keyframes": [],
		"particles": [],
		"audio_cues": [],
		"screen_shakes": [],
		"text_overlays": [
			{
				"text": "Victory!",
				"time": 0.5,
				"animation_type": "bounce_in",
				"duration": 1.5,
				"position": "center",
				"font_size": 48,
				"color": "#ffff00"
			}
		]
	}
	
	var config = CutsceneDataModels.CutsceneConfig.from_dict(dict)
	
	assert_eq(config.text_overlays.size(), 1, "Should have 1 text overlay")
	assert_eq(config.text_overlays[0].text, "Victory!", "Overlay text should deserialize")
	assert_eq(config.text_overlays[0].animation_type, CutsceneTypes.TextAnimationType.BOUNCE_IN, "Animation type should deserialize")


# Test AnimatedTextOverlay component creation
func test_animated_text_overlay_creation():
	var overlay_node = AnimatedTextOverlay.new()
	add_child_autofree(overlay_node)
	
	assert_not_null(overlay_node, "AnimatedTextOverlay should be created")
	assert_true(overlay_node is Label, "AnimatedTextOverlay should be a Label")


# Test AnimatedTextOverlay fade_in animation
func test_animated_text_overlay_fade_in():
	var overlay_node = AnimatedTextOverlay.new()
	add_child_autofree(overlay_node)
	
	var overlay_data = CutsceneDataModels.TextOverlay.new("Fade Test", 0.0)
	overlay_data.animation_type = CutsceneTypes.TextAnimationType.FADE_IN
	overlay_data.duration = 0.5
	
	overlay_node.play_animation(overlay_data, Vector2(800, 600))
	
	assert_eq(overlay_node.text, "Fade Test", "Text should be set")
	assert_eq(overlay_node.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "Text should be centered")


# Test AnimatedTextOverlay slide_in animation
func test_animated_text_overlay_slide_in():
	var overlay_node = AnimatedTextOverlay.new()
	add_child_autofree(overlay_node)
	
	var overlay_data = CutsceneDataModels.TextOverlay.new("Slide Test", 0.0)
	overlay_data.animation_type = CutsceneTypes.TextAnimationType.SLIDE_IN
	overlay_data.duration = 0.5
	
	overlay_node.play_animation(overlay_data, Vector2(800, 600))
	
	assert_eq(overlay_node.text, "Slide Test", "Text should be set")


# Test AnimatedTextOverlay bounce_in animation
func test_animated_text_overlay_bounce_in():
	var overlay_node = AnimatedTextOverlay.new()
	add_child_autofree(overlay_node)
	
	var overlay_data = CutsceneDataModels.TextOverlay.new("Bounce Test", 0.0)
	overlay_data.animation_type = CutsceneTypes.TextAnimationType.BOUNCE_IN
	overlay_data.duration = 0.5
	
	overlay_node.play_animation(overlay_data, Vector2(800, 600))
	
	assert_eq(overlay_node.text, "Bounce Test", "Text should be set")


# Test text overlay positioning - top
func test_text_overlay_position_top():
	var overlay_node = AnimatedTextOverlay.new()
	add_child_autofree(overlay_node)
	
	var overlay_data = CutsceneDataModels.TextOverlay.new("Top", 0.0)
	overlay_data.position = CutsceneTypes.TextPosition.TOP
	
	overlay_node.play_animation(overlay_data, Vector2(800, 600))
	
	# Position should be near the top (10% of height)
	assert_approximately(overlay_node.position.y, 60.0, 10.0, "Should be positioned at top")


# Test text overlay positioning - center
func test_text_overlay_position_center():
	var overlay_node = AnimatedTextOverlay.new()
	add_child_autofree(overlay_node)
	
	var overlay_data = CutsceneDataModels.TextOverlay.new("Center", 0.0)
	overlay_data.position = CutsceneTypes.TextPosition.CENTER
	
	overlay_node.play_animation(overlay_data, Vector2(800, 600))
	
	# Position should be near the center (50% of height)
	assert_approximately(overlay_node.position.y, 300.0, 50.0, "Should be positioned at center")


# Test text overlay positioning - bottom
func test_text_overlay_position_bottom():
	var overlay_node = AnimatedTextOverlay.new()
	add_child_autofree(overlay_node)
	
	var overlay_data = CutsceneDataModels.TextOverlay.new("Bottom", 0.0)
	overlay_data.position = CutsceneTypes.TextPosition.BOTTOM
	
	overlay_node.play_animation(overlay_data, Vector2(800, 600))
	
	# Position should be near the bottom (80% of height)
	assert_approximately(overlay_node.position.y, 480.0, 50.0, "Should be positioned at bottom")


# Test text overlay styling - font size
func test_text_overlay_font_size():
	var overlay_node = AnimatedTextOverlay.new()
	add_child_autofree(overlay_node)
	
	var overlay_data = CutsceneDataModels.TextOverlay.new("Big Text", 0.0)
	overlay_data.font_size = 64
	
	overlay_node.play_animation(overlay_data, Vector2(800, 600))
	
	# Font size should be applied via theme override
	assert_true(overlay_node.has_theme_font_size_override("font_size"), "Font size should be overridden")


# Test text overlay styling - color
func test_text_overlay_color():
	var overlay_node = AnimatedTextOverlay.new()
	add_child_autofree(overlay_node)
	
	var overlay_data = CutsceneDataModels.TextOverlay.new("Colored Text", 0.0)
	overlay_data.color = Color.RED
	
	overlay_node.play_animation(overlay_data, Vector2(800, 600))
	
	# Color should be applied via theme override
	assert_true(overlay_node.has_theme_color_override("font_color"), "Font color should be overridden")


# Test text overlay with various text lengths
func test_text_overlay_various_lengths():
	var test_texts = [
		"Short",
		"This is a medium length text overlay",
		"This is a very long text overlay that should still display correctly even with many words and characters"
	]
	
	for test_text in test_texts:
		var overlay_node = AnimatedTextOverlay.new()
		add_child_autofree(overlay_node)
		
		var overlay_data = CutsceneDataModels.TextOverlay.new(test_text, 0.0)
		overlay_node.play_animation(overlay_data, Vector2(800, 600))
		
		assert_eq(overlay_node.text, test_text, "Text should be set correctly regardless of length")


# Test enum conversion - TextAnimationType
func test_text_animation_type_conversion():
	assert_eq(CutsceneTypes.string_to_text_animation_type("fade_in"), CutsceneTypes.TextAnimationType.FADE_IN)
	assert_eq(CutsceneTypes.string_to_text_animation_type("slide_in"), CutsceneTypes.TextAnimationType.SLIDE_IN)
	assert_eq(CutsceneTypes.string_to_text_animation_type("bounce_in"), CutsceneTypes.TextAnimationType.BOUNCE_IN)
	assert_eq(CutsceneTypes.string_to_text_animation_type("invalid"), CutsceneTypes.TextAnimationType.FADE_IN, "Invalid should default to FADE_IN")


# Test enum conversion - TextPosition
func test_text_position_conversion():
	assert_eq(CutsceneTypes.string_to_text_position("top"), CutsceneTypes.TextPosition.TOP)
	assert_eq(CutsceneTypes.string_to_text_position("center"), CutsceneTypes.TextPosition.CENTER)
	assert_eq(CutsceneTypes.string_to_text_position("bottom"), CutsceneTypes.TextPosition.BOTTOM)
	assert_eq(CutsceneTypes.string_to_text_position("invalid"), CutsceneTypes.TextPosition.CENTER, "Invalid should default to CENTER")
