class_name MPMovingObject
extends Area2D

## ═══════════════════════════════════════════════════════════════════
## MOVINGOBJECT.GD - Generic Spawnable Object for Multiplayer Games
## ═══════════════════════════════════════════════════════════════════
## Used for: Drops, Leaves, Trash, Items in all multiplayer mini-games
##
## FEATURES:
## - Moves in a specified direction at specified speed
## - Detects screen exit (failure condition)
## - Detects clicks (for P2 tap-to-destroy)
## - Detects collisions (for P1 bucket catch)
## - Supports spinning animation (for Hard difficulty)
##
## USAGE:
## 1. Instantiate the object
## 2. Call setup(direction, speed, extra_effects)
## 3. Connect to signals: caught, missed, destroyed
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Emitted when object is caught by bucket (P1)
signal caught(obj: Area2D, is_special: bool)

## Emitted when object exits screen without being caught/destroyed
signal missed(obj: Area2D, is_special: bool)

## Emitted when object is clicked/tapped (P2)
signal destroyed(obj: Area2D)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OBJECT TYPE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum ObjectType {
	WATER_DROP,    # P1 catches these (good)
	ACID_DROP,     # P1 avoids these (bad)
	LEAF,          # P2 clicks these
	TRASH,         # Sorting game - swipe down
	WATER_BUBBLE,  # Sorting game - swipe up
	FLOWER,        # Gardener game - tap to water
	LIGHT,         # Detector game - tap to mark
	CRACK          # Fixer game - swipe to repair
}

@export var object_type: ObjectType = ObjectType.WATER_DROP

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MOVEMENT PROPERTIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@export var move_direction: Vector2 = Vector2.DOWN
@export var move_speed: float = 200.0
@export var rotation_speed: float = 0.0  # Radians per second (for spinning)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var is_special: bool = false  # True for acid drops, trick items, etc.
var is_active: bool = true
var screen_size: Vector2 = Vector2.ZERO

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	# Enable input for click detection
	input_pickable = true
	
	# Connect collision signals
	area_entered.connect(_on_area_entered)
	
	# Connect input signal
	input_event.connect(_on_input_event)

func setup(direction: Vector2, speed: float, special_or_spin: Variant = false) -> void:
	# Setup the object's movement properties.
	#
	# Parameters:
	# - direction: Movement direction (normalized)
	# - speed: Movement speed in pixels/second
	# - special_or_spin: bool for is_special OR spin enabled
	move_direction = direction.normalized()
	move_speed = speed
	
	if special_or_spin is bool:
		# For drops: this is is_special (acid)
		# For leaves: this is spin enabled
		if object_type == ObjectType.LEAF:
			rotation_speed = 3.0 if special_or_spin else 0.0
		else:
			is_special = special_or_spin

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MOVEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _process(delta: float) -> void:
	if not is_active:
		return
	
	# Move in direction
	position += move_direction * move_speed * delta
	
	# Rotate if spinning
	if rotation_speed != 0.0:
		rotation += rotation_speed * delta
	
	# Check if exited screen (missed)
	if _is_off_screen():
		_on_missed()

func _is_off_screen() -> bool:
	# Check if object has exited the playable screen area
	var margin: float = 100.0  # Buffer zone
	
	return (
		position.x < -margin or
		position.x > screen_size.x + margin or
		position.y < -margin or
		position.y > screen_size.y + margin
	)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COLLISION DETECTION (P1 Bucket Catch)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_area_entered(other: Area2D) -> void:
	# Called when this object collides with another Area2D (bucket)
	if not is_active:
		return
	
	# Check if it's the bucket
	if other.name == "Bucket" or other.is_in_group("bucket"):
		is_active = false
		caught.emit(self, is_special)
		_play_catch_effect()

func _play_catch_effect() -> void:
	# Visual feedback when caught
	var tween: Tween = create_tween()
	tween.set_loops(1)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLICK/TAP DETECTION (P2 Destroy)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Called when this object receives input (click/tap)
	if not is_active:
		return
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			is_active = false
			destroyed.emit(self)
			_play_destroy_effect()

func _play_destroy_effect() -> void:
	# Visual feedback when destroyed by click
	# Burst effect
	var tween: Tween = create_tween()
	tween.set_loops(1)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15)
	tween.tween_property(self, "rotation", rotation + PI, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MISS DETECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_missed() -> void:
	# Called when object exits screen without interaction
	if not is_active:
		return
	
	is_active = false
	missed.emit(self, is_special)
	queue_free()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SWIPE DETECTION (For sorting/repair games)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var swipe_start: Vector2 = Vector2.ZERO
var is_swiping: bool = false
const MIN_SWIPE_DISTANCE: float = 50.0

signal swiped_up(obj: Area2D)
signal swiped_down(obj: Area2D)
signal swiped_left(obj: Area2D)
signal swiped_right(obj: Area2D)
signal swipe_traced(obj: Area2D, accuracy: float)

func _unhandled_input(event: InputEvent) -> void:
	# Handle swipe gestures for sorting/repair games
	if not is_active:
		return
	
	# Only process if this is a swipeable object type
	if object_type not in [ObjectType.TRASH, ObjectType.WATER_BUBBLE, ObjectType.CRACK, ObjectType.LEAF]:
		return
	
	# For LEAFs: Check if the input is over this object
	if object_type == ObjectType.LEAF:
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var global_pos = event.position
				if _is_point_inside(global_pos):
					swipe_start = global_pos
					is_swiping = true
			elif not event.pressed and is_swiping:
				_process_swipe(event.position)
				is_swiping = false
		return
	
	# For other swipeable objects
	if event is InputEventMouseButton:
		if event.pressed:
			# Check if swipe started on this object
			if _is_point_inside(event.position):
				swipe_start = event.position
				is_swiping = true
		else:
			if is_swiping:
				_process_swipe(event.position)
				is_swiping = false

func _is_point_inside(point: Vector2) -> bool:
	# Check if a point is inside this object's collision area
	var local_point: Vector2 = to_local(point)
	# Simple radius check (adjust based on your collision shape)
	return local_point.length() < 50.0

func _process_swipe(end_pos: Vector2) -> void:
	# Determine swipe direction and emit appropriate signal
	var swipe_vector: Vector2 = end_pos - swipe_start
	var distance: float = swipe_vector.length()
	
	if distance < MIN_SWIPE_DISTANCE:
		return  # Too short to be a swipe
	
	# Visual feedback - show swipe trail
	var line = Line2D.new()
	line.add_point(to_local(swipe_start))
	line.add_point(to_local(end_pos))
	line.width = 5.0
	line.default_color = Color.YELLOW
	add_child(line)
	
	# Remove trail after animation
	var trail_tween = create_tween()
	trail_tween.set_loops(1)
	trail_tween.tween_property(line, "modulate:a", 0.0, 0.3)
	trail_tween.tween_callback(line.queue_free)
	
	# Determine primary direction
	var angle: float = swipe_vector.angle()
	
	# Up: -135° to -45° (-PI*3/4 to -PI/4)
	# Down: 45° to 135° (PI/4 to PI*3/4)
	# Left: 135° to -135° (PI*3/4 to -PI*3/4, wrapping)
	# Right: -45° to 45° (-PI/4 to PI/4)
	
	is_active = false
	
	if angle > -PI/4 and angle < PI/4:
		swiped_right.emit(self)
	elif angle > PI/4 and angle < PI*3/4:
		swiped_down.emit(self)
	elif angle < -PI/4 and angle > -PI*3/4:
		swiped_up.emit(self)
	else:
		swiped_left.emit(self)
	
	_play_destroy_effect()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TRACING DETECTION (For crack repair in Leak Detectives)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var trace_points: Array[Vector2] = []
var target_path: Array[Vector2] = []  # Set this for crack repair games
var is_tracing: bool = false

func setup_trace_path(path: Array[Vector2]) -> void:
	# Setup the target path for tracing (crack repair)
	target_path = path
	object_type = ObjectType.CRACK

func _handle_trace_input(event: InputEvent) -> void:
	# Handle continuous tracing for crack repair
	if object_type != ObjectType.CRACK:
		return
	
	if event is InputEventMouseButton:
		if event.pressed:
			trace_points.clear()
			is_tracing = true
		else:
			if is_tracing:
				var accuracy: float = _calculate_trace_accuracy()
				swipe_traced.emit(self, accuracy)
				is_tracing = false
	
	elif event is InputEventMouseMotion and is_tracing:
		trace_points.append(event.position)

func _calculate_trace_accuracy() -> float:
	# Calculate how accurately the player traced the target path
	if target_path.is_empty() or trace_points.is_empty():
		return 0.0
	
	var total_distance: float = 0.0
	
	for trace_point in trace_points:
		var min_dist: float = INF
		for target_point in target_path:
			var dist: float = trace_point.distance_to(target_point)
			min_dist = minf(min_dist, dist)
		total_distance += min_dist
	
	var avg_distance: float = total_distance / float(trace_points.size())
	
	# Convert distance to accuracy (0-1)
	# Assuming 50 pixels is max acceptable deviation
	var accuracy: float = clampf(1.0 - (avg_distance / 50.0), 0.0, 1.0)
	
	return accuracy

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func set_color(color: Color) -> void:
	# Set the visual color of the object
	for child in get_children():
		if child is Polygon2D:
			child.color = color
		elif child is Sprite2D:
			child.modulate = color

func flash(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	# Flash the object with a color
	var original_modulate: Color = modulate
	var tween: Tween = create_tween()
	tween.set_loops(1)
	tween.tween_property(self, "modulate", color, duration / 2)
	tween.tween_property(self, "modulate", original_modulate, duration / 2)
