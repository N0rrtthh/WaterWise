class_name AnimationEngine
extends RefCounted

## Animation engine for applying transformations to characters over time
##
## This engine handles:
## - Easing functions (linear, ease_in, ease_out, ease_in_out, bounce, elastic, back)
## - Single transform application (position, rotation, scale)
## - Parallel transform composition
## - Full keyframe sequence animation
## - Tween management and cleanup

## Apply a single transformation to a target node
## @param target: The Node2D to animate
## @param transform: The Transform data model containing type, value, and relative flag
## @param duration: Animation duration in seconds
## @param easing: Easing function to use (from CutsceneTypes.Easing enum)
## @return: The created Tween object
static func apply_transform(
	target: Node2D,
	transform: CutsceneDataModels.Transform,
	duration: float,
	easing: CutsceneTypes.Easing
) -> Tween:
	if not is_instance_valid(target):
		push_error("[AnimationEngine] Invalid target node")
		return null
	
	# Validate duration to prevent negative or zero values (Requirement 12.5)
	if duration <= 0.0:
		push_warning("[AnimationEngine] Invalid duration (%.2f), clamping to minimum 0.01s" % duration)
		duration = 0.01
	
	var tween = target.create_tween()
	if not tween:
		push_error("[AnimationEngine] Failed to create tween - possible memory allocation failure")
		return null
	
	# Get the easing function
	var easing_func = _get_easing_function(easing)
	tween.set_ease(easing_func[0])
	tween.set_trans(easing_func[1])
	
	# Apply the transformation based on type with error recovery
	match transform.type:
		CutsceneTypes.TransformType.POSITION:
			var target_pos = transform.value as Vector2
			if transform.relative:
				target_pos = target.position + target_pos
			tween.tween_property(target, "position", target_pos, duration)
		
		CutsceneTypes.TransformType.ROTATION:
			var target_rot = transform.value as float
			if transform.relative:
				target_rot = target.rotation + target_rot
			tween.tween_property(target, "rotation", target_rot, duration)
		
		CutsceneTypes.TransformType.SCALE:
			var target_scale = transform.value as Vector2
			if transform.relative:
				target_scale = target.scale * target_scale
			# Clamp scale to prevent extreme values that could cause rendering issues
			target_scale.x = clamp(target_scale.x, 0.01, 10.0)
			target_scale.y = clamp(target_scale.y, 0.01, 10.0)
			tween.tween_property(target, "scale", target_scale, duration)
	
	return tween


## Compose multiple transformations to run in parallel
## @param target: The Node2D to animate
## @param transforms: Array of Transform data models
## @param duration: Animation duration in seconds
## @return: The created Tween object with parallel animations
static func compose_transforms(
	target: Node2D,
	transforms: Array[CutsceneDataModels.Transform],
	duration: float
) -> Tween:
	if not is_instance_valid(target):
		push_error("[AnimationEngine] Invalid target node")
		return null
	
	if transforms.is_empty():
		push_warning("[AnimationEngine] No transforms provided")
		return null
	
	# Validate duration to prevent negative or zero values (Requirement 12.5)
	if duration <= 0.0:
		push_warning("[AnimationEngine] Invalid duration (%.2f), clamping to minimum 0.01s" % duration)
		duration = 0.01
	
	var tween = target.create_tween()
	if not tween:
		push_error("[AnimationEngine] Failed to create tween - possible memory allocation failure")
		return null
	
	# Set parallel mode so all transforms run simultaneously
	tween.set_parallel(true)
	
	# Apply each transform with error recovery
	for transform in transforms:
		var easing_func = _get_easing_function(CutsceneTypes.Easing.LINEAR)
		
		match transform.type:
			CutsceneTypes.TransformType.POSITION:
				var target_pos = transform.value as Vector2
				if transform.relative:
					target_pos = target.position + target_pos
				tween.tween_property(target, "position", target_pos, duration)
			
			CutsceneTypes.TransformType.ROTATION:
				var target_rot = transform.value as float
				if transform.relative:
					target_rot = target.rotation + target_rot
				tween.tween_property(target, "rotation", target_rot, duration)
			
			CutsceneTypes.TransformType.SCALE:
				var target_scale = transform.value as Vector2
				if transform.relative:
					target_scale = target.scale * target_scale
				# Clamp scale to prevent extreme values that could cause rendering issues
				target_scale.x = clamp(target_scale.x, 0.01, 10.0)
				target_scale.y = clamp(target_scale.y, 0.01, 10.0)
				tween.tween_property(target, "scale", target_scale, duration)
	
	return tween


## Animate a target through a full sequence of keyframes
## @param target: The Node2D to animate
## @param keyframes: Array of Keyframe data models
## @param total_duration: Total animation duration in seconds
## @return: The created Tween object
static func animate(
	target: Node2D,
	keyframes: Array[CutsceneDataModels.Keyframe],
	total_duration: float
) -> Tween:
	if not is_instance_valid(target):
		push_error("[AnimationEngine] Invalid target node")
		return null
	
	if keyframes.is_empty():
		push_warning("[AnimationEngine] No keyframes provided")
		return null
	
	# Validate duration to prevent negative or zero values (Requirement 12.5)
	if total_duration <= 0.0:
		push_warning("[AnimationEngine] Invalid total duration (%.2f), clamping to minimum 0.01s" % total_duration)
		total_duration = 0.01
	
	var tween = target.create_tween()
	if not tween:
		push_error("[AnimationEngine] Failed to create tween - possible memory allocation failure")
		return null
	
	# Sort keyframes by time
	var sorted_keyframes = keyframes.duplicate()
	sorted_keyframes.sort_custom(func(a, b): return a.time < b.time)
	
	# Track previous keyframe time for calculating durations
	var prev_time = 0.0
	
	for i in range(sorted_keyframes.size()):
		var keyframe = sorted_keyframes[i]
		var segment_duration = keyframe.time - prev_time
		
		# Skip if duration is zero or negative
		if segment_duration <= 0.0 and i > 0:
			continue
		
		# Clamp segment duration to prevent issues
		segment_duration = max(segment_duration, 0.01)
		
		# Get easing function for this keyframe
		var easing_func = _get_easing_function(keyframe.easing)
		
		# If this is not the first keyframe, set sequential mode
		if i > 0:
			tween.set_parallel(false)
		
		# Apply all transforms in this keyframe in parallel with error recovery
		if not keyframe.transforms.is_empty():
			tween.set_parallel(true)
			
			for transform in keyframe.transforms:
				match transform.type:
					CutsceneTypes.TransformType.POSITION:
						var target_pos = transform.value as Vector2
						if transform.relative:
							target_pos = target.position + target_pos
						var prop_tween = tween.tween_property(target, "position", target_pos, segment_duration)
						if prop_tween:
							prop_tween.set_ease(easing_func[0])
							prop_tween.set_trans(easing_func[1])
					
					CutsceneTypes.TransformType.ROTATION:
						var target_rot = transform.value as float
						if transform.relative:
							target_rot = target.rotation + target_rot
						var prop_tween = tween.tween_property(target, "rotation", target_rot, segment_duration)
						if prop_tween:
							prop_tween.set_ease(easing_func[0])
							prop_tween.set_trans(easing_func[1])
					
					CutsceneTypes.TransformType.SCALE:
						var target_scale = transform.value as Vector2
						if transform.relative:
							target_scale = target.scale * target_scale
						# Clamp scale to prevent extreme values that could cause rendering issues
						target_scale.x = clamp(target_scale.x, 0.01, 10.0)
						target_scale.y = clamp(target_scale.y, 0.01, 10.0)
						var prop_tween = tween.tween_property(target, "scale", target_scale, segment_duration)
						if prop_tween:
							prop_tween.set_ease(easing_func[0])
							prop_tween.set_trans(easing_func[1])
		
		prev_time = keyframe.time
	
	return tween


## Get Godot's Tween.EaseType and Tween.TransitionType for a given easing
## @param easing: The easing enum value
## @return: Array [EaseType, TransitionType]
static func _get_easing_function(easing: CutsceneTypes.Easing) -> Array:
	match easing:
		CutsceneTypes.Easing.LINEAR:
			return [Tween.EASE_IN_OUT, Tween.TRANS_LINEAR]
		
		CutsceneTypes.Easing.EASE_IN:
			return [Tween.EASE_IN, Tween.TRANS_QUAD]
		
		CutsceneTypes.Easing.EASE_OUT:
			return [Tween.EASE_OUT, Tween.TRANS_QUAD]
		
		CutsceneTypes.Easing.EASE_IN_OUT:
			return [Tween.EASE_IN_OUT, Tween.TRANS_QUAD]
		
		CutsceneTypes.Easing.BOUNCE:
			return [Tween.EASE_OUT, Tween.TRANS_BOUNCE]
		
		CutsceneTypes.Easing.ELASTIC:
			return [Tween.EASE_OUT, Tween.TRANS_ELASTIC]
		
		CutsceneTypes.Easing.BACK:
			return [Tween.EASE_OUT, Tween.TRANS_BACK]
		
		_:
			push_warning("[AnimationEngine] Unknown easing type, using linear")
			return [Tween.EASE_IN_OUT, Tween.TRANS_LINEAR]


## Apply custom easing interpolation (for advanced use cases)
## This provides the mathematical easing curves directly
## @param t: Time value (0.0 to 1.0)
## @param easing: The easing enum value
## @return: Eased value (0.0 to 1.0)
static func apply_easing(t: float, easing: CutsceneTypes.Easing) -> float:
	t = clamp(t, 0.0, 1.0)
	
	match easing:
		CutsceneTypes.Easing.LINEAR:
			return t
		
		CutsceneTypes.Easing.EASE_IN:
			return t * t
		
		CutsceneTypes.Easing.EASE_OUT:
			return t * (2.0 - t)
		
		CutsceneTypes.Easing.EASE_IN_OUT:
			return t * t * (3.0 - 2.0 * t)
		
		CutsceneTypes.Easing.BOUNCE:
			if t < 0.5:
				return 2.0 * t * t
			else:
				return 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
		
		CutsceneTypes.Easing.ELASTIC:
			var c4 = (2.0 * PI) / 3.0
			if t == 0.0:
				return 0.0
			if t == 1.0:
				return 1.0
			return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0
		
		CutsceneTypes.Easing.BACK:
			var c1 = 1.70158
			var c3 = c1 + 1.0
			return c3 * t * t * t - c1 * t * t
		
		_:
			return t  # Fallback to linear
