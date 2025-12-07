extends Area2D

# Simple falling object script
var fall_speed: float = 200.0

func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	
	# Remove if off screen
	if position.y > get_viewport_rect().size.y + 100:
		queue_free()
