extends Area2D
class_name MovingObject

## ═══════════════════════════════════════════════════════════════════
## MOVING OBJECT - BASE CLASS FOR DROPS & LEAVES
## ═══════════════════════════════════════════════════════════════════
## Falls from top of screen, emits signals when collected/destroyed/missed
## Used in asymmetric 2-player co-op minigames
## ═══════════════════════════════════════════════════════════════════

signal collected(object: MovingObject)
signal destroyed(object: MovingObject)
signal missed(object: MovingObject)

enum ObjectType {
	DROP,   # For Host to catch
	LEAF    # For Client to destroy
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EXPORTED PROPERTIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@export var object_type: ObjectType = ObjectType.DROP
@export var fall_speed: float = 200.0  # pixels per second
@export var sway_amount: float = 30.0  # horizontal sway amplitude
@export var sway_speed: float = 2.0    # sway frequency
@export var rotation_speed: float = 1.0  # for leaves

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTERNAL STATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var _elapsed_time: float = 0.0
var _initial_x: float = 0.0
var _screen_height: float = 0.0
var _is_active: bool = true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	_initial_x = position.x
	_screen_height = get_viewport_rect().size.y
	
	# Add to appropriate group for easy access
	if object_type == ObjectType.DROP:
		add_to_group("drops")
	else:
		add_to_group("leaves")
	
	# Connect input detection for touch
	input_event.connect(_on_input_event)
	
	# Adjust fall speed based on difficulty
	fall_speed *= GameManager.difficulty_multiplier

func _process(delta: float) -> void:
	if not _is_active:
		return
	
	_elapsed_time += delta
	
	# Apply gravity (fall down)
	position.y += fall_speed * delta
	
	# Apply horizontal sway
	if sway_amount > 0:
		position.x = _initial_x + sin(_elapsed_time * sway_speed) * sway_amount
	
	# Apply rotation for leaves
	if object_type == ObjectType.LEAF:
		rotation += rotation_speed * delta
	
	# Check if off screen (missed)
	if position.y > _screen_height + 50.0:
		_on_missed()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INPUT HANDLING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Handle direct input on this object
	if not _is_active:
		return
	
	var is_tap: bool = false
	if event is InputEventMouseButton and event.pressed:
		is_tap = true
	elif event is InputEventScreenTouch and event.pressed:
		is_tap = true
	
	if is_tap:
		_handle_tap()

func _handle_tap() -> void:
	# Process tap based on object type and player role
	if object_type == ObjectType.DROP:
		# Only Host can catch drops
		if GameManager.is_host:
			_on_collected()
	else:  # LEAF
		# Only Client can destroy leaves
		if not GameManager.is_host:
			_on_destroyed()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EVENT HANDLERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_collected() -> void:
	# Called when a Drop is caught by Host
	if not _is_active:
		return
	
	_is_active = false
	collected.emit(self)
	
	# Play collection effect
	_play_collect_effect()
	
	# Remove after effect
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
	
	print("💧 Drop collected!")

func _on_destroyed() -> void:
	# Called when a Leaf is destroyed by Client
	if not _is_active:
		return
	
	_is_active = false
	destroyed.emit(self)
	
	# Play destruction effect
	_play_destroy_effect()
	
	# Remove after effect
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(queue_free)
	
	print("🍃 Leaf destroyed!")

func _on_missed() -> void:
	# Called when object falls off screen without being caught/destroyed
	if not _is_active:
		return
	
	_is_active = false
	missed.emit(self)
	
	print("❌ ", "Drop" if object_type == ObjectType.DROP else "Leaf", " missed!")
	
	queue_free()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VISUAL EFFECTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _play_collect_effect() -> void:
	# Visual feedback for collecting a drop
	# Scale up briefly
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Change color to bright
	modulate = Color(0.5, 0.8, 1.0, 1.0)  # Light blue flash

func _play_destroy_effect() -> void:
	# Visual feedback for destroying a leaf
	# Spin and shrink
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation", rotation + TAU * 2, 0.3)
	tween.tween_property(self, "modulate", Color(1.0, 0.5, 0.0, 0.5), 0.3)  # Orange fade

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func set_fall_speed(speed: float) -> void:
	# Override fall speed
	fall_speed = speed

func set_sway(amount: float, speed: float) -> void:
	# Configure horizontal sway
	sway_amount = amount
	sway_speed = speed

func is_drop() -> bool:
	return object_type == ObjectType.DROP

func is_leaf() -> bool:
	return object_type == ObjectType.LEAF
