extends Node2D
class_name TouchZoneIndicator

## ═══════════════════════════════════════════════════════════════════
## TOUCH ZONE INDICATOR - VISUAL FEEDBACK FOR MOBILE
## ═══════════════════════════════════════════════════════════════════
## Creates visual indicators for touch zones on mobile devices
## Scales indicators 30% larger than interactive areas for clarity
## ═══════════════════════════════════════════════════════════════════

@export var indicator_color: Color = Color(1.0, 1.0, 1.0, 0.3)
@export var indicator_border_color: Color = Color(1.0, 1.0, 1.0, 0.6)
@export var indicator_border_width: float = 2.0
@export var pulse_enabled: bool = true
@export var pulse_duration: float = 1.0

var _target_node: Node2D = null
var _indicator_scale: float = 1.3  # 30% larger than interactive area

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	z_index = -1  # Behind the target
	
	if pulse_enabled:
		_start_pulse_animation()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func set_target(target: Node2D) -> void:
	# Set the target node to create indicator for
	# @param target: The Node2D to create visual indicator for
	# _target_node = target
	# queue_redraw()
	#
	# func set_indicator_scale(scale_factor: float) -> void:Set the scale of the indicator relative to target
	
	@param scale: Scale factor (1.3 = 30% larger than target)
	# _indicator_scale = scale_factor
	# queue_redraw()
	#
	# # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	# # DRAWING
	# # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	#
	# func _draw() -> void:
	# if not _target_node:
	# return
	#
	# # Get target size
	# var target_size = _get_target_size()
	# if target_size == Vector2.ZERO:
	# return
	#
	# # Calculate indicator size (30% larger)
	# var indicator_size = target_size * _indicator_scale
	# var half_size = indicator_size / 2.0
	#
	# # Draw filled circle or rectangle based on target shape
	# var rect = Rect2(-half_size, indicator_size)
	# draw_rect(rect, indicator_color, true)
	#
	# # Draw border
	# if indicator_border_width > 0:
	# draw_rect(rect, indicator_border_color, false, indicator_border_width)
	#
	# func _get_target_size() -> Vector2:Get the visual size of the target node
	if not _target_node:
		return Vector2.ZERO
	
	# Try to get size from Sprite2D
	if _target_node is Sprite2D:
		var sprite = _target_node as Sprite2D
		if sprite.texture:
			return sprite.texture.get_size() * _target_node.scale
	
	# Try to get size from CollisionShape2D
	for child in _target_node.get_children():
		if child is CollisionShape2D:
			var collision = child as CollisionShape2D
			if collision.shape:
				if collision.shape is RectangleShape2D:
					return collision.shape.size * _target_node.scale
				elif collision.shape is CircleShape2D:
					var diameter = collision.shape.radius * 2.0
					return Vector2(diameter, diameter) * _target_node.scale
	
	return Vector2(64, 64)  # Default size

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ANIMATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _start_pulse_animation() -> void:
	# Start pulsing animation for the indicator
	var tween = create_tween().set_loops()
	tween.tween_property(self, "modulate:a", 0.2, pulse_duration / 2.0)
	tween.tween_property(self, "modulate:a", 0.5, pulse_duration / 2.0)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATIC HELPER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

static func create_for_node(target: Node2D) -> TouchZoneIndicator:
	# Create and attach a touch zone indicator to a target node
	# @param target: The Node2D to create indicator for
	@return: The created TouchZoneIndicator instance
	var indicator = TouchZoneIndicator.new()
	indicator.set_target(target)
	target.add_child(indicator)
	return indicator
