class_name CutsceneDataModels
extends RefCounted

## Data model classes for cutscene configuration

class Transform:
	var type: CutsceneTypes.TransformType
	var value: Variant  # Vector2 for position/scale, float for rotation
	var relative: bool = false
	
	func _init(p_type: CutsceneTypes.TransformType = CutsceneTypes.TransformType.POSITION, p_value: Variant = null, p_relative: bool = false):
		type = p_type
		value = p_value
		relative = p_relative
	
	func to_dict() -> Dictionary:
		var type_str = ""
		match type:
			CutsceneTypes.TransformType.POSITION:
				type_str = "position"
			CutsceneTypes.TransformType.ROTATION:
				type_str = "rotation"
			CutsceneTypes.TransformType.SCALE:
				type_str = "scale"
		
		var value_data = value
		if value is Vector2:
			value_data = [value.x, value.y]
		
		return {
			"type": type_str,
			"value": value_data,
			"relative": relative
		}
	
	static func from_dict(data: Dictionary) -> Transform:
		var transform = Transform.new()
		
		if data.has("type"):
			transform.type = CutsceneTypes.string_to_transform_type(data["type"])
		
		if data.has("value"):
			var val = data["value"]
			if val is Array and val.size() == 2:
				transform.value = Vector2(val[0], val[1])
			else:
				transform.value = val
		
		if data.has("relative"):
			transform.relative = data["relative"]
		
		return transform


class Keyframe:
	var time: float = 0.0
	var transforms: Array[Transform] = []
	var easing: CutsceneTypes.Easing = CutsceneTypes.Easing.LINEAR
	
	func _init(p_time: float = 0.0):
		time = p_time
	
	func add_transform(transform: Transform) -> void:
		transforms.append(transform)
	
	func to_dict() -> Dictionary:
		var easing_str = ""
		match easing:
			CutsceneTypes.Easing.LINEAR:
				easing_str = "linear"
			CutsceneTypes.Easing.EASE_IN:
				easing_str = "ease_in"
			CutsceneTypes.Easing.EASE_OUT:
				easing_str = "ease_out"
			CutsceneTypes.Easing.EASE_IN_OUT:
				easing_str = "ease_in_out"
			CutsceneTypes.Easing.BOUNCE:
				easing_str = "bounce"
			CutsceneTypes.Easing.ELASTIC:
				easing_str = "elastic"
			CutsceneTypes.Easing.BACK:
				easing_str = "back"
		
		var transforms_data = []
		for t in transforms:
			transforms_data.append(t.to_dict())
		
		return {
			"time": time,
			"transforms": transforms_data,
			"easing": easing_str
		}
	
	static func from_dict(data: Dictionary) -> Keyframe:
		var keyframe = Keyframe.new()
		
		if data.has("time"):
			keyframe.time = data["time"]
		
		if data.has("easing"):
			keyframe.easing = CutsceneTypes.string_to_easing(data["easing"])
		
		if data.has("transforms") and data["transforms"] is Array:
			for t_data in data["transforms"]:
				if t_data is Dictionary:
					keyframe.transforms.append(Transform.from_dict(t_data))
		
		return keyframe


class ParticleEffect:
	var time: float = 0.0
	var type: CutsceneTypes.ParticleType = CutsceneTypes.ParticleType.SPARKLES
	var duration: float = 1.0
	var density: String = "medium"  # low, medium, high
	
	func _init(p_time: float = 0.0, p_type: CutsceneTypes.ParticleType = CutsceneTypes.ParticleType.SPARKLES):
		time = p_time
		type = p_type
	
	func to_dict() -> Dictionary:
		var type_str = ""
		match type:
			CutsceneTypes.ParticleType.SPARKLES:
				type_str = "sparkles"
			CutsceneTypes.ParticleType.WATER_DROPS:
				type_str = "water_drops"
			CutsceneTypes.ParticleType.STARS:
				type_str = "stars"
			CutsceneTypes.ParticleType.SMOKE:
				type_str = "smoke"
			CutsceneTypes.ParticleType.SPLASH:
				type_str = "splash"
		
		return {
			"time": time,
			"type": type_str,
			"duration": duration,
			"density": density
		}
	
	static func from_dict(data: Dictionary) -> ParticleEffect:
		var particle = ParticleEffect.new()
		
		if data.has("time"):
			particle.time = data["time"]
		
		if data.has("type"):
			particle.type = CutsceneTypes.string_to_particle_type(data["type"])
		
		if data.has("duration"):
			particle.duration = data["duration"]
		
		if data.has("density"):
			particle.density = data["density"]
		
		return particle


class AudioCue:
	var time: float = 0.0
	var sound: String = ""
	
	func _init(p_time: float = 0.0, p_sound: String = ""):
		time = p_time
		sound = p_sound
	
	func to_dict() -> Dictionary:
		return {
			"time": time,
			"sound": sound
		}
	
	static func from_dict(data: Dictionary) -> AudioCue:
		var audio = AudioCue.new()
		
		if data.has("time"):
			audio.time = data["time"]
		
		if data.has("sound"):
			audio.sound = data["sound"]
		
		return audio


class ScreenShake:
	var time: float = 0.0
	var intensity: float = 0.5
	var duration: float = 0.3
	
	func _init(p_time: float = 0.0, p_intensity: float = 0.5, p_duration: float = 0.3):
		time = p_time
		intensity = p_intensity
		duration = p_duration
	
	func to_dict() -> Dictionary:
		return {
			"time": time,
			"intensity": intensity,
			"duration": duration
		}
	
	static func from_dict(data: Dictionary) -> ScreenShake:
		var shake = ScreenShake.new()
		
		if data.has("time"):
			shake.time = data["time"]
		
		if data.has("intensity"):
			shake.intensity = data["intensity"]
		
		if data.has("duration"):
			shake.duration = data["duration"]
		
		return shake


class TextOverlay:
	var text: String = ""
	var time: float = 0.0
	var animation_type: CutsceneTypes.TextAnimationType = CutsceneTypes.TextAnimationType.FADE_IN
	var duration: float = 1.0
	var position: CutsceneTypes.TextPosition = CutsceneTypes.TextPosition.CENTER
	var font_size: int = 32
	var color: Color = Color.WHITE
	
	func _init(p_text: String = "", p_time: float = 0.0):
		text = p_text
		time = p_time
	
	func to_dict() -> Dictionary:
		var anim_type_str = ""
		match animation_type:
			CutsceneTypes.TextAnimationType.FADE_IN:
				anim_type_str = "fade_in"
			CutsceneTypes.TextAnimationType.SLIDE_IN:
				anim_type_str = "slide_in"
			CutsceneTypes.TextAnimationType.BOUNCE_IN:
				anim_type_str = "bounce_in"
		
		var pos_str = ""
		match position:
			CutsceneTypes.TextPosition.TOP:
				pos_str = "top"
			CutsceneTypes.TextPosition.CENTER:
				pos_str = "center"
			CutsceneTypes.TextPosition.BOTTOM:
				pos_str = "bottom"
		
		return {
			"text": text,
			"time": time,
			"animation_type": anim_type_str,
			"duration": duration,
			"position": pos_str,
			"font_size": font_size,
			"color": color.to_html()
		}
	
	static func from_dict(data: Dictionary) -> TextOverlay:
		var overlay = TextOverlay.new()
		
		if data.has("text"):
			overlay.text = data["text"]
		
		if data.has("time"):
			overlay.time = data["time"]
		
		if data.has("animation_type"):
			overlay.animation_type = CutsceneTypes.string_to_text_animation_type(data["animation_type"])
		
		if data.has("duration"):
			overlay.duration = data["duration"]
		
		if data.has("position"):
			overlay.position = CutsceneTypes.string_to_text_position(data["position"])
		
		if data.has("font_size"):
			overlay.font_size = data["font_size"]
		
		if data.has("color"):
			var color_str = data["color"]
			if color_str is String:
				overlay.color = Color(color_str)
		
		return overlay


class CharacterConfig:
	var expression: CutsceneTypes.CharacterExpression = CutsceneTypes.CharacterExpression.DETERMINED
	var deformation_enabled: bool = true
	
	func to_dict() -> Dictionary:
		var expr_str = ""
		match expression:
			CutsceneTypes.CharacterExpression.HAPPY:
				expr_str = "happy"
			CutsceneTypes.CharacterExpression.SAD:
				expr_str = "sad"
			CutsceneTypes.CharacterExpression.SURPRISED:
				expr_str = "surprised"
			CutsceneTypes.CharacterExpression.DETERMINED:
				expr_str = "determined"
			CutsceneTypes.CharacterExpression.WORRIED:
				expr_str = "worried"
			CutsceneTypes.CharacterExpression.EXCITED:
				expr_str = "excited"
		
		return {
			"expression": expr_str,
			"deformation_enabled": deformation_enabled
		}
	
	static func from_dict(data: Dictionary) -> CharacterConfig:
		var config = CharacterConfig.new()
		
		if data.has("expression"):
			config.expression = CutsceneTypes.string_to_expression(data["expression"])
		
		if data.has("deformation_enabled"):
			config.deformation_enabled = data["deformation_enabled"]
		
		return config


class CutsceneConfig:
	var version: String = "1.0"
	var minigame_key: String = ""
	var cutscene_type: CutsceneTypes.CutsceneType = CutsceneTypes.CutsceneType.INTRO
	var duration: float = 2.0
	var character: CharacterConfig = CharacterConfig.new()
	var background_color: Color = Color(0.039, 0.118, 0.059)  # #0a1e0f
	var keyframes: Array[Keyframe] = []
	var particles: Array[ParticleEffect] = []
	var audio_cues: Array[AudioCue] = []
	var screen_shakes: Array[ScreenShake] = []
	var text_overlays: Array[TextOverlay] = []
	
	func add_keyframe(keyframe: Keyframe) -> void:
		keyframes.append(keyframe)
	
	func add_particle(particle: ParticleEffect) -> void:
		particles.append(particle)
	
	func add_audio_cue(audio: AudioCue) -> void:
		audio_cues.append(audio)
	
	func add_screen_shake(shake: ScreenShake) -> void:
		screen_shakes.append(shake)
	
	func add_text_overlay(overlay: TextOverlay) -> void:
		text_overlays.append(overlay)
	
	func to_dict() -> Dictionary:
		var type_str = ""
		match cutscene_type:
			CutsceneTypes.CutsceneType.INTRO:
				type_str = "intro"
			CutsceneTypes.CutsceneType.WIN:
				type_str = "win"
			CutsceneTypes.CutsceneType.FAIL:
				type_str = "fail"
		
		var keyframes_data = []
		for k in keyframes:
			keyframes_data.append(k.to_dict())
		
		var particles_data = []
		for p in particles:
			particles_data.append(p.to_dict())
		
		var audio_data = []
		for a in audio_cues:
			audio_data.append(a.to_dict())
		
		var shakes_data = []
		for s in screen_shakes:
			shakes_data.append(s.to_dict())
		
		var overlays_data = []
		for o in text_overlays:
			overlays_data.append(o.to_dict())
		
		return {
			"version": version,
			"minigame_key": minigame_key,
			"cutscene_type": type_str,
			"duration": duration,
			"character": character.to_dict(),
			"background_color": background_color.to_html(),
			"keyframes": keyframes_data,
			"particles": particles_data,
			"audio_cues": audio_data,
			"screen_shakes": shakes_data,
			"text_overlays": overlays_data
		}
	
	static func from_dict(data: Dictionary) -> CutsceneConfig:
		var config = CutsceneConfig.new()
		
		if data.has("version"):
			config.version = data["version"]
		
		if data.has("minigame_key"):
			config.minigame_key = data["minigame_key"]
		
		if data.has("cutscene_type"):
			config.cutscene_type = CutsceneTypes.string_to_cutscene_type(data["cutscene_type"])
		
		if data.has("duration"):
			config.duration = data["duration"]
		
		if data.has("character") and data["character"] is Dictionary:
			config.character = CharacterConfig.from_dict(data["character"])
		
		if data.has("background_color"):
			var color_str = data["background_color"]
			if color_str is String:
				config.background_color = Color(color_str)
		
		if data.has("keyframes") and data["keyframes"] is Array:
			for k_data in data["keyframes"]:
				if k_data is Dictionary:
					config.keyframes.append(Keyframe.from_dict(k_data))
		
		if data.has("particles") and data["particles"] is Array:
			for p_data in data["particles"]:
				if p_data is Dictionary:
					config.particles.append(ParticleEffect.from_dict(p_data))
		
		if data.has("audio_cues") and data["audio_cues"] is Array:
			for a_data in data["audio_cues"]:
				if a_data is Dictionary:
					config.audio_cues.append(AudioCue.from_dict(a_data))
		
		if data.has("screen_shakes") and data["screen_shakes"] is Array:
			for s_data in data["screen_shakes"]:
				if s_data is Dictionary:
					config.screen_shakes.append(ScreenShake.from_dict(s_data))
		
		if data.has("text_overlays") and data["text_overlays"] is Array:
			for o_data in data["text_overlays"]:
				if o_data is Dictionary:
					config.text_overlays.append(TextOverlay.from_dict(o_data))
		
		return config


class ValidationResult:
	var is_valid: bool = true
	var errors: Array[String] = []
	
	func add_error(error: String) -> void:
		is_valid = false
		errors.append(error)
	
	func has_errors() -> bool:
		return not is_valid
	
	func get_error_message() -> String:
		if is_valid:
			return "Validation passed"
		return "Validation failed:\n  - " + "\n  - ".join(errors)
