extends Area2D

# Simple horizontal moving object script
var horizontal_speed: float = 150.0

func _physics_process(delta: float) -> void:
	position.x += horizontal_speed * delta
	
	# Remove if off screen
	if position.x > get_viewport_rect().size.x + 100:
		queue_free()
