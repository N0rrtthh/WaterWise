class_name CutsceneParser
extends RefCounted

## Parser for cutscene configuration files with validation and error handling
## Supports both JSON and GDScript resource formats

# Parse cutscene configuration from file path
static func parse_config(config_path: String) -> CutsceneDataModels.CutsceneConfig:
	if not FileAccess.file_exists(config_path):
		push_error("[CutsceneParser] Configuration file not found: " + config_path + 
			". Please ensure the file exists or the system will use default configuration.")
		return null
	
	var file_extension = config_path.get_extension().to_lower()
	
	match file_extension:
		"json":
			return _parse_json_file(config_path)
		"tres", "res":
			return _parse_resource_file(config_path)
		_:
			push_error("[CutsceneParser] Unsupported file format: '" + file_extension + 
				"' for file: " + config_path + 
				" (expected json, tres, or res). System will fall back to default configuration.")
			return null


# Parse cutscene configuration from dictionary
static func parse_dict(config_dict: Dictionary) -> CutsceneDataModels.CutsceneConfig:
	if config_dict.is_empty():
		push_error("[CutsceneParser] Cannot parse empty dictionary. " +
			"Configuration must contain at least basic cutscene data. " +
			"System will use default configuration.")
		return null
	
	var config = CutsceneDataModels.CutsceneConfig.from_dict(config_dict)
	if config == null:
		push_error("[CutsceneParser] Failed to create CutsceneConfig from dictionary. " +
			"Check that the dictionary contains valid cutscene data with required fields. " +
			"System will use default configuration.")
	
	return config


# Validate configuration structure and return validation result
static func validate_config(config: CutsceneDataModels.CutsceneConfig) -> CutsceneDataModels.ValidationResult:
	var result = CutsceneDataModels.ValidationResult.new()
	
	if config == null:
		result.add_error("Configuration is null")
		return result
	
	# Validate duration
	if config.duration <= 0.0:
		result.add_error("Duration must be greater than 0 (got: " + str(config.duration) + ")")
	
	if config.duration < 1.5:
		result.add_error("Duration is too short (minimum: 1.5s, got: " + str(config.duration) + "s)")
	
	if config.duration > 4.0:
		result.add_error("Duration is too long (maximum: 4.0s, got: " + str(config.duration) + "s)")
	
	# Validate cutscene type bounds
	match config.cutscene_type:
		CutsceneTypes.CutsceneType.INTRO:
			if config.duration < 1.5 or config.duration > 2.5:
				result.add_error("Intro cutscene duration should be between 1.5-2.5s (got: " + str(config.duration) + "s)")
		CutsceneTypes.CutsceneType.WIN, CutsceneTypes.CutsceneType.FAIL:
			if config.duration < 2.0 or config.duration > 3.0:
				result.add_error("Win/Fail cutscene duration should be between 2.0-3.0s (got: " + str(config.duration) + "s)")
	
	# Validate minigame_key
	if config.minigame_key.is_empty():
		result.add_error("Minigame key cannot be empty")
	
	# Validate keyframes
	if config.keyframes.is_empty():
		result.add_error("Configuration must have at least one keyframe")
	else:
		_validate_keyframes(config.keyframes, config.duration, result)
	
	# Validate character configuration
	if config.character == null:
		result.add_error("Character configuration is missing")
	
	# Validate particles
	for particle in config.particles:
		_validate_particle(particle, config.duration, result)
	
	# Validate audio cues
	for audio in config.audio_cues:
		_validate_audio_cue(audio, config.duration, result)
	
	return result


# Pretty print configuration for debugging
static func pretty_print(config: CutsceneDataModels.CutsceneConfig) -> String:
	if config == null:
		return "[CutsceneParser] Cannot pretty print null configuration"
	
	var output = []
	output.append("=== Cutscene Configuration ===")
	output.append("Version: " + config.version)
	output.append("Minigame: " + config.minigame_key)
	output.append("Type: " + _cutscene_type_to_string(config.cutscene_type))
	output.append("Duration: " + str(config.duration) + "s")
	output.append("")
	
	# Character section
	output.append("Character:")
	output.append("  Expression: " + _expression_to_string(config.character.expression))
	output.append("  Deformation Enabled: " + str(config.character.deformation_enabled))
	output.append("")
	
	# Background color
	output.append("Background Color: " + config.background_color.to_html())
	output.append("")
	
	# Keyframes section
	output.append("Keyframes (" + str(config.keyframes.size()) + "):")
	for i in range(config.keyframes.size()):
		var kf = config.keyframes[i]
		output.append("  [" + str(i) + "] Time: " + str(kf.time) + "s, Easing: " + _easing_to_string(kf.easing))
		for t in kf.transforms:
			output.append("    - " + _transform_to_string(t))
	output.append("")
	
	# Particles section
	if not config.particles.is_empty():
		output.append("Particles (" + str(config.particles.size()) + "):")
		for p in config.particles:
			output.append("  - Time: " + str(p.time) + "s, Type: " + _particle_type_to_string(p.type) + ", Duration: " + str(p.duration) + "s, Density: " + p.density)
		output.append("")
	
	# Audio cues section
	if not config.audio_cues.is_empty():
		output.append("Audio Cues (" + str(config.audio_cues.size()) + "):")
		for a in config.audio_cues:
			output.append("  - Time: " + str(a.time) + "s, Sound: " + a.sound)
		output.append("")
	
	output.append("==============================")
	
	return "\n".join(output)


# ============================================================================
# PRIVATE HELPER METHODS
# ============================================================================

static func _parse_json_file(file_path: String) -> CutsceneDataModels.CutsceneConfig:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var error_code = FileAccess.get_open_error()
		push_error("[CutsceneParser] Failed to open JSON file: " + file_path + 
			" (Error code: " + str(error_code) + "). " +
			"Check file permissions and path validity. System will use default configuration.")
		return null
	
	var json_text = file.get_as_text()
	file.close()
	
	if json_text.is_empty():
		push_error("[CutsceneParser] JSON file is empty: " + file_path + 
			". System will use default configuration.")
		return null
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("[CutsceneParser] JSON parse error in " + file_path + 
			" at line " + str(json.get_error_line()) + ": " + json.get_error_message() + 
			". Check JSON syntax. System will use default configuration.")
		return null
	
	var data = json.get_data()
	if not data is Dictionary:
		push_error("[CutsceneParser] JSON root must be a dictionary in " + file_path + 
			" (found: " + str(typeof(data)) + "). " +
			"System will use default configuration.")
		return null
	
	var config = parse_dict(data)
	if config == null:
		push_error("[CutsceneParser] Failed to parse configuration dictionary from " + file_path + 
			". Check that all required fields are present. System will use default configuration.")
	
	return config


static func _parse_resource_file(file_path: String) -> CutsceneDataModels.CutsceneConfig:
	var resource = load(file_path)
	if resource == null:
		push_error("[CutsceneParser] Failed to load resource file: " + file_path + 
			". Check that the file exists and is a valid Godot resource. " +
			"System will use default configuration.")
		return null
	
	# If it's already a CutsceneConfig, return it
	if resource is CutsceneDataModels.CutsceneConfig:
		return resource
	
	# If it's a Resource with a to_dict method, convert it
	if resource.has_method("to_dict"):
		var config = parse_dict(resource.to_dict())
		if config == null:
			push_error("[CutsceneParser] Failed to convert resource to configuration: " + file_path + 
				". Check that the resource contains valid cutscene data. " +
				"System will use default configuration.")
		return config
	
	push_error("[CutsceneParser] Resource file does not contain valid cutscene configuration: " + file_path + 
		". Expected CutsceneConfig or Resource with to_dict() method. " +
		"System will use default configuration.")
	return null


static func _validate_keyframes(keyframes: Array, duration: float, result: CutsceneDataModels.ValidationResult) -> void:
	var prev_time = -1.0
	
	for i in range(keyframes.size()):
		var kf = keyframes[i]
		
		# Validate time ordering
		if kf.time < 0.0:
			result.add_error("Keyframe " + str(i) + " has negative time: " + str(kf.time))
		
		if kf.time > duration:
			result.add_error("Keyframe " + str(i) + " time (" + str(kf.time) + "s) exceeds cutscene duration (" + str(duration) + "s)")
		
		if kf.time < prev_time:
			result.add_error("Keyframe " + str(i) + " time (" + str(kf.time) + "s) is not in chronological order")
		
		prev_time = kf.time
		
		# Validate transforms
		if kf.transforms.is_empty():
			result.add_error("Keyframe " + str(i) + " has no transforms")
		
		for t in kf.transforms:
			_validate_transform(t, i, result)


static func _validate_transform(transform: CutsceneDataModels.Transform, keyframe_index: int, result: CutsceneDataModels.ValidationResult) -> void:
	if transform.value == null:
		result.add_error("Keyframe " + str(keyframe_index) + " has transform with null value")
		return
	
	match transform.type:
		CutsceneTypes.TransformType.POSITION:
			if not transform.value is Vector2:
				result.add_error("Keyframe " + str(keyframe_index) + " position transform must have Vector2 value")
		
		CutsceneTypes.TransformType.ROTATION:
			if not (transform.value is float or transform.value is int):
				result.add_error("Keyframe " + str(keyframe_index) + " rotation transform must have numeric value")
		
		CutsceneTypes.TransformType.SCALE:
			if not transform.value is Vector2:
				result.add_error("Keyframe " + str(keyframe_index) + " scale transform must have Vector2 value")
			elif transform.value.x <= 0.0 or transform.value.y <= 0.0:
				result.add_error("Keyframe " + str(keyframe_index) + " scale transform must have positive values")


static func _validate_particle(particle: CutsceneDataModels.ParticleEffect, duration: float, result: CutsceneDataModels.ValidationResult) -> void:
	if particle.time < 0.0:
		result.add_error("Particle effect has negative time: " + str(particle.time))
	
	if particle.time > duration:
		result.add_error("Particle effect time (" + str(particle.time) + "s) exceeds cutscene duration (" + str(duration) + "s)")
	
	if particle.duration <= 0.0:
		result.add_error("Particle effect duration must be positive (got: " + str(particle.duration) + "s)")
	
	if not particle.density in ["low", "medium", "high"]:
		result.add_error("Particle effect density must be 'low', 'medium', or 'high' (got: '" + particle.density + "')")


static func _validate_audio_cue(audio: CutsceneDataModels.AudioCue, duration: float, result: CutsceneDataModels.ValidationResult) -> void:
	if audio.time < 0.0:
		result.add_error("Audio cue has negative time: " + str(audio.time))
	
	if audio.time > duration:
		result.add_error("Audio cue time (" + str(audio.time) + "s) exceeds cutscene duration (" + str(duration) + "s)")
	
	if audio.sound.is_empty():
		result.add_error("Audio cue at time " + str(audio.time) + "s has empty sound name")


# ============================================================================
# STRING CONVERSION HELPERS FOR PRETTY PRINTING
# ============================================================================

static func _cutscene_type_to_string(type: CutsceneTypes.CutsceneType) -> String:
	match type:
		CutsceneTypes.CutsceneType.INTRO:
			return "INTRO"
		CutsceneTypes.CutsceneType.WIN:
			return "WIN"
		CutsceneTypes.CutsceneType.FAIL:
			return "FAIL"
		_:
			return "UNKNOWN"


static func _expression_to_string(expr: CutsceneTypes.CharacterExpression) -> String:
	match expr:
		CutsceneTypes.CharacterExpression.HAPPY:
			return "HAPPY"
		CutsceneTypes.CharacterExpression.SAD:
			return "SAD"
		CutsceneTypes.CharacterExpression.SURPRISED:
			return "SURPRISED"
		CutsceneTypes.CharacterExpression.DETERMINED:
			return "DETERMINED"
		CutsceneTypes.CharacterExpression.WORRIED:
			return "WORRIED"
		CutsceneTypes.CharacterExpression.EXCITED:
			return "EXCITED"
		_:
			return "UNKNOWN"


static func _easing_to_string(easing: CutsceneTypes.Easing) -> String:
	match easing:
		CutsceneTypes.Easing.LINEAR:
			return "LINEAR"
		CutsceneTypes.Easing.EASE_IN:
			return "EASE_IN"
		CutsceneTypes.Easing.EASE_OUT:
			return "EASE_OUT"
		CutsceneTypes.Easing.EASE_IN_OUT:
			return "EASE_IN_OUT"
		CutsceneTypes.Easing.BOUNCE:
			return "BOUNCE"
		CutsceneTypes.Easing.ELASTIC:
			return "ELASTIC"
		CutsceneTypes.Easing.BACK:
			return "BACK"
		_:
			return "UNKNOWN"


static func _particle_type_to_string(type: CutsceneTypes.ParticleType) -> String:
	match type:
		CutsceneTypes.ParticleType.SPARKLES:
			return "SPARKLES"
		CutsceneTypes.ParticleType.WATER_DROPS:
			return "WATER_DROPS"
		CutsceneTypes.ParticleType.STARS:
			return "STARS"
		CutsceneTypes.ParticleType.SMOKE:
			return "SMOKE"
		CutsceneTypes.ParticleType.SPLASH:
			return "SPLASH"
		_:
			return "UNKNOWN"


static func _transform_type_to_string(type: CutsceneTypes.TransformType) -> String:
	match type:
		CutsceneTypes.TransformType.POSITION:
			return "POSITION"
		CutsceneTypes.TransformType.ROTATION:
			return "ROTATION"
		CutsceneTypes.TransformType.SCALE:
			return "SCALE"
		_:
			return "UNKNOWN"


static func _transform_to_string(transform: CutsceneDataModels.Transform) -> String:
	var type_str = _transform_type_to_string(transform.type)
	var value_str = ""
	
	if transform.value is Vector2:
		value_str = "(" + str(transform.value.x) + ", " + str(transform.value.y) + ")"
	else:
		value_str = str(transform.value)
	
	var relative_str = " (relative)" if transform.relative else " (absolute)"
	
	return type_str + ": " + value_str + relative_str
