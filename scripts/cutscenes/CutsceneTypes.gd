class_name CutsceneTypes
extends RefCounted

## Core enums and constants for the animated cutscene system

enum CutsceneType {
	INTRO,
	WIN,
	FAIL
}

enum CharacterExpression {
	HAPPY,
	SAD,
	SURPRISED,
	DETERMINED,
	WORRIED,
	EXCITED
}

enum ParticleType {
	SPARKLES,
	WATER_DROPS,
	STARS,
	SMOKE,
	SPLASH
}

enum Easing {
	LINEAR,
	EASE_IN,
	EASE_OUT,
	EASE_IN_OUT,
	BOUNCE,
	ELASTIC,
	BACK
}

enum TransformType {
	POSITION,
	ROTATION,
	SCALE
}

enum TextAnimationType {
	FADE_IN,
	SLIDE_IN,
	BOUNCE_IN
}

enum TextPosition {
	TOP,
	CENTER,
	BOTTOM
}

# Convert string to CutsceneType enum
static func string_to_cutscene_type(type_str: String) -> CutsceneType:
	match type_str.to_lower():
		"intro":
			return CutsceneType.INTRO
		"win":
			return CutsceneType.WIN
		"fail":
			return CutsceneType.FAIL
		_:
			push_error("Invalid cutscene type: " + type_str)
			return CutsceneType.INTRO

# Convert string to CharacterExpression enum
static func string_to_expression(expr_str: String) -> CharacterExpression:
	match expr_str.to_lower():
		"happy":
			return CharacterExpression.HAPPY
		"sad":
			return CharacterExpression.SAD
		"surprised":
			return CharacterExpression.SURPRISED
		"determined":
			return CharacterExpression.DETERMINED
		"worried":
			return CharacterExpression.WORRIED
		"excited":
			return CharacterExpression.EXCITED
		_:
			push_error("Invalid expression: " + expr_str)
			return CharacterExpression.DETERMINED

# Convert string to ParticleType enum
static func string_to_particle_type(particle_str: String) -> ParticleType:
	match particle_str.to_lower():
		"sparkles":
			return ParticleType.SPARKLES
		"water_drops":
			return ParticleType.WATER_DROPS
		"stars":
			return ParticleType.STARS
		"smoke":
			return ParticleType.SMOKE
		"splash":
			return ParticleType.SPLASH
		_:
			push_error("Invalid particle type: " + particle_str)
			return ParticleType.SPARKLES

# Convert string to Easing enum
static func string_to_easing(easing_str: String) -> Easing:
	match easing_str.to_lower():
		"linear":
			return Easing.LINEAR
		"ease_in":
			return Easing.EASE_IN
		"ease_out":
			return Easing.EASE_OUT
		"ease_in_out":
			return Easing.EASE_IN_OUT
		"bounce":
			return Easing.BOUNCE
		"elastic":
			return Easing.ELASTIC
		"back":
			return Easing.BACK
		_:
			push_error("Invalid easing: " + easing_str)
			return Easing.LINEAR

# Convert string to TransformType enum
static func string_to_transform_type(transform_str: String) -> TransformType:
	match transform_str.to_lower():
		"position":
			return TransformType.POSITION
		"rotation":
			return TransformType.ROTATION
		"scale":
			return TransformType.SCALE
		_:
			push_error("Invalid transform type: " + transform_str)
			return TransformType.POSITION

# Convert string to TextAnimationType enum
static func string_to_text_animation_type(anim_str: String) -> TextAnimationType:
	match anim_str.to_lower():
		"fade_in":
			return TextAnimationType.FADE_IN
		"slide_in":
			return TextAnimationType.SLIDE_IN
		"bounce_in":
			return TextAnimationType.BOUNCE_IN
		_:
			push_error("Invalid text animation type: " + anim_str)
			return TextAnimationType.FADE_IN

# Convert string to TextPosition enum
static func string_to_text_position(pos_str: String) -> TextPosition:
	match pos_str.to_lower():
		"top":
			return TextPosition.TOP
		"center":
			return TextPosition.CENTER
		"bottom":
			return TextPosition.BOTTOM
		_:
			push_error("Invalid text position: " + pos_str)
			return TextPosition.CENTER
