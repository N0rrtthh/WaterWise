class_name PlayerBucket
extends Area2D

## ═══════════════════════════════════════════════════════════════════
## PLAYERBUCKET.GD - Player-Controlled Bucket for Catch Games
## ═══════════════════════════════════════════════════════════════════
## Used by: P1 (Host) in Catch The Rain, Water Saver, etc.
##
## FEATURES:
## - Horizontal movement following mouse/touch
## - Collision detection with falling objects
## - Visual feedback on catch/miss
## - Size adjustment based on difficulty
##
## ALGORITHM INTEGRATION:
## - Bucket width adjusted by difficulty_multiplier from Rolling Window
## - Speed bonus adjusted by G-Counter performance
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Emitted when bucket catches an object
signal object_caught(obj: Area2D, is_bad: bool)

## Emitted when bucket misses an object
signal object_missed(obj: Area2D)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EXPORTED PROPERTIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Base bucket width (adjusted by difficulty)
@export var base_width: float = 100.0

## Movement smoothing (higher = snappier)
@export var move_smoothness: float = 15.0

## Vertical position (Y coordinate)
@export var y_position: float = 0.0

## Bucket color
@export var bucket_color: Color = Color(0.2, 0.6, 1.0)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var screen_size: Vector2 = Vector2.ZERO
var current_width: float = 100.0
var target_x: float = 0.0
var is_active: bool = true

# Difficulty adjustment
var difficulty_multiplier: float = 1.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	# Set default Y position (80% down the screen)
	if y_position == 0.0:
		y_position = screen_size.y * 0.85
	
	position.y = y_position
	position.x = screen_size.x / 2.0
	target_x = position.x
	
	# Add to bucket group for collision detection
	add_to_group("bucket")
	
	# Setup collision signals
	area_entered.connect(_on_area_entered)
	
	# Apply initial width
	_update_bucket_width()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DIFFICULTY SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func set_difficulty(multiplier: float) -> void:
	# Set difficulty multiplier from Rolling Window algorithm.
	#
	# Higher difficulty = smaller bucket
	# Multiplier range: 0.8 (easy) to 1.4 (hard)
	difficulty_multiplier = multiplier
	_update_bucket_width()

func _update_bucket_width() -> void:
	# Update bucket width based on difficulty
	# Invert multiplier for bucket size (harder = smaller)
	var size_factor: float = 1.0 / difficulty_multiplier
	current_width = base_width * size_factor
	
	# Clamp to reasonable bounds
	current_width = clampf(current_width, 60.0, 150.0)
	
	# Update visual (if using Polygon2D or CollisionShape2D)
	_update_visual()

func _update_visual() -> void:
	# Update the visual representation of the bucket
	# Update collision shape if it exists
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision:
		var shape: RectangleShape2D = collision.shape as RectangleShape2D
		if shape:
			shape.size.x = current_width
	
	# Update polygon visual if it exists
	var polygon: Polygon2D = get_node_or_null("Polygon2D")
	if polygon:
		var half_w: float = current_width / 2.0
		var height: float = 30.0
		polygon.polygon = PackedVector2Array([
			Vector2(-half_w - 10, -height),  # Top-left outer
			Vector2(-half_w, 0),              # Bottom-left
			Vector2(half_w, 0),               # Bottom-right
			Vector2(half_w + 10, -height)     # Top-right outer
		])
		polygon.color = bucket_color

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MOVEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _process(delta: float) -> void:
	if not is_active:
		return
	
	# Smooth movement toward target
	position.x = lerpf(position.x, target_x, move_smoothness * delta)
	
	# Clamp to screen bounds
	var half_width: float = current_width / 2.0
	position.x = clampf(position.x, half_width, screen_size.x - half_width)

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Follow mouse/touch position
	if event is InputEventMouseMotion:
		target_x = event.position.x
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		target_x = event.position.x

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COLLISION HANDLING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_area_entered(other: Area2D) -> void:
	# Handle collision with falling objects
	if not is_active:
		return
	
	# Check if it's a MovingObject
	if other is MovingObject:
		var obj: MovingObject = other as MovingObject
		var is_bad: bool = obj.is_special
		
		object_caught.emit(other, is_bad)
		
		# Visual feedback
		if is_bad:
			_flash_red()
		else:
			_flash_green()

func _flash_green() -> void:
	# Flash green for successful catch
	var tween: Tween = create_tween()
	tween.set_loops(1)
	var original: Color = modulate
	tween.tween_property(self, "modulate", Color.GREEN, 0.05)
	tween.tween_property(self, "modulate", original, 0.1)

func _flash_red() -> void:
	# Flash red for bad catch
	var tween: Tween = create_tween()
	tween.set_loops(1)
	var original: Color = modulate
	tween.tween_property(self, "modulate", Color.RED, 0.05)
	tween.tween_property(self, "modulate", original, 0.1)
	
	# Shake effect
	var original_pos: Vector2 = position
	for i in range(5):
		tween.tween_property(self, "position:x", position.x + randf_range(-10, 10), 0.02)
	tween.tween_property(self, "position", original_pos, 0.05)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ACTIVATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func activate() -> void:
	# Enable bucket control
	is_active = true
	modulate.a = 1.0

func deactivate() -> void:
	# Disable bucket control
	is_active = false
	modulate.a = 0.5

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# POWER-UPS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func apply_size_boost(duration: float = 5.0) -> void:
	# Temporarily increase bucket size
	var original_width: float = current_width
	current_width *= 1.5
	_update_visual()
	
	# Visual indicator
	modulate = Color.GOLD
	
	# Reset after duration
	await get_tree().create_timer(duration).timeout
	current_width = original_width
	_update_visual()
	modulate = Color.WHITE

func apply_magnet(duration: float = 5.0, radius: float = 100.0) -> void:
	# Temporarily attract nearby drops
	var timer: float = 0.0
	
	while timer < duration:
		# Find nearby drops and pull them
		for obj in get_tree().get_nodes_in_group("drops"):
			if obj is MovingObject and obj.is_active:
				var dist: float = obj.position.distance_to(position)
				if dist < radius:
					var pull_strength: float = (radius - dist) / radius
					var pull_dir: Vector2 = (position - obj.position).normalized()
					obj.position += pull_dir * pull_strength * 5.0
		
		timer += get_process_delta_time()
		await get_tree().process_frame
