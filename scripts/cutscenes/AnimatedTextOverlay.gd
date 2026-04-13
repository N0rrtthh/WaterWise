class_name AnimatedTextOverlay
extends Label

## Animated text overlay component for cutscenes
##
## This component provides animated text overlays with various animation types:
## - fade_in: Text fades in from transparent to opaque
## - slide_in: Text slides in from off-screen
## - bounce_in: Text bounces in with elastic effect

signal animation_finished()

var _animation_tween: Tween = null


## Initialize and play the text overlay animation
## @param overlay_data: TextOverlay data model with animation parameters
## @param parent_size: Size of the parent container for positioning
func play_animation(overlay_data: CutsceneDataModels.TextOverlay, parent_size: Vector2) -> void:
	# Set text content
	text = overlay_data.text
	
	# Set styling
	add_theme_font_size_override("font_size", overlay_data.font_size)
	add_theme_color_override("font_color", overlay_data.color)
	
	# Enable outline for better readability
	add_theme_constant_override("outline_size", 2)
	add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Center text alignment
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Set size to match parent width
	custom_minimum_size = Vector2(parent_size.x, 0)
	size = Vector2(parent_size.x, 0)
	
	# Position based on overlay position setting
	_set_position_from_enum(overlay_data.position, parent_size)
	
	# Play animation based on type
	match overlay_data.animation_type:
		CutsceneTypes.TextAnimationType.FADE_IN:
			_animate_fade_in(overlay_data.duration)
		CutsceneTypes.TextAnimationType.SLIDE_IN:
			_animate_slide_in(overlay_data.duration, parent_size)
		CutsceneTypes.TextAnimationType.BOUNCE_IN:
			_animate_bounce_in(overlay_data.duration)


## Set position based on TextPosition enum
func _set_position_from_enum(pos: CutsceneTypes.TextPosition, parent_size: Vector2) -> void:
	match pos:
		CutsceneTypes.TextPosition.TOP:
			position = Vector2(0, parent_size.y * 0.1)
		CutsceneTypes.TextPosition.CENTER:
			position = Vector2(0, parent_size.y * 0.5 - size.y / 2)
		CutsceneTypes.TextPosition.BOTTOM:
			position = Vector2(0, parent_size.y * 0.8)


## Animate fade in effect
func _animate_fade_in(duration: float) -> void:
	# Start transparent
	modulate.a = 0.0
	
	# Create tween
	_animation_tween = create_tween()
	_animation_tween.set_ease(Tween.EASE_IN_OUT)
	_animation_tween.set_trans(Tween.TRANS_QUAD)
	
	# Fade in
	_animation_tween.tween_property(self, "modulate:a", 1.0, duration * 0.5)
	
	# Hold for a moment
	_animation_tween.tween_interval(duration * 0.3)
	
	# Fade out
	_animation_tween.tween_property(self, "modulate:a", 0.0, duration * 0.2)
	
	# Emit signal when done
	_animation_tween.finished.connect(_on_animation_finished)


## Animate slide in effect
func _animate_slide_in(duration: float, parent_size: Vector2) -> void:
	# Store target position
	var target_pos = position
	
	# Start off-screen to the left
	position.x = -parent_size.x
	
	# Create tween
	_animation_tween = create_tween()
	_animation_tween.set_ease(Tween.EASE_OUT)
	_animation_tween.set_trans(Tween.TRANS_BACK)
	
	# Slide in
	_animation_tween.tween_property(self, "position:x", target_pos.x, duration * 0.5)
	
	# Hold
	_animation_tween.tween_interval(duration * 0.3)
	
	# Slide out to the right
	_animation_tween.tween_property(self, "position:x", parent_size.x, duration * 0.2)
	
	# Emit signal when done
	_animation_tween.finished.connect(_on_animation_finished)


## Animate bounce in effect
func _animate_bounce_in(duration: float) -> void:
	# Start small and transparent
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	
	# Create tween
	_animation_tween = create_tween()
	_animation_tween.set_parallel(true)
	
	# Bounce scale
	var scale_tween = _animation_tween.tween_property(self, "scale", Vector2(1.0, 1.0), duration * 0.5)
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.set_trans(Tween.TRANS_BOUNCE)
	
	# Fade in
	var fade_tween = _animation_tween.tween_property(self, "modulate:a", 1.0, duration * 0.3)
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.set_trans(Tween.TRANS_QUAD)
	
	# Chain to hold and fade out
	_animation_tween.chain()
	_animation_tween.tween_interval(duration * 0.3)
	_animation_tween.tween_property(self, "modulate:a", 0.0, duration * 0.2)
	
	# Emit signal when done
	_animation_tween.finished.connect(_on_animation_finished)


## Cleanup when animation finishes
func _on_animation_finished() -> void:
	animation_finished.emit()
	queue_free()


## Cleanup on exit
func _exit_tree() -> void:
	if _animation_tween and _animation_tween.is_valid():
		_animation_tween.kill()
	_animation_tween = null
