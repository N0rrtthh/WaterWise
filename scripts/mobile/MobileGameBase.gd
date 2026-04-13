extends Node
class_name MobileGameBase

## ═══════════════════════════════════════════════════════════════════
## MOBILE GAME BASE - MOBILE SUPPORT FOR MINIGAMES
## ═══════════════════════════════════════════════════════════════════
## Base class for minigames with mobile support
## Provides mobile scaling, adjustments, and visual feedback
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	if MobileUIManager and MobileUIManager.is_mobile_platform():
		_apply_mobile_optimizations()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MOBILE OPTIMIZATIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _apply_mobile_optimizations() -> void:
	# Apply all mobile optimizations to the game scene
	# Apply game object scaling
	_scale_game_objects()
	
	# Apply performance optimizations
	_optimize_performance()
	
	# Apply UI scaling
	_scale_ui_elements()
	
	print("📱 Mobile optimizations applied to %s" % get_parent().name if get_parent() else "game")

func _scale_game_objects() -> void:
	# Scale all game objects for mobile visibility
	var root = get_parent()
	if not root:
		return
	
	# Find and scale all Node2D game objects
	_scale_node2d_recursive(root)

func _scale_node2d_recursive(node: Node) -> void:
	# Recursively scale Node2D objects
	if node is Node2D:
		# Skip UI elements (Control nodes)
		if not node is Control:
			MobileUIManager.apply_game_object_scaling(node)
	
	for child in node.get_children():
		_scale_node2d_recursive(child)

func _optimize_performance() -> void:
	# Apply performance optimizations for mobile
	var root = get_parent()
	if not root:
		return
	
	# Optimize particle systems
	_optimize_particles_recursive(root)
	
	# Set max tweens limit
	PerformanceManager.set_max_tweens(MobileUIManager.get_max_tweens())

func _optimize_particles_recursive(node: Node) -> void:
	# Recursively optimize particle systems
	if node is GPUParticles2D:
		PerformanceManager.optimize_particle_system_for_mobile(node)
	
	for child in node.get_children():
		_optimize_particles_recursive(child)

func _scale_ui_elements() -> void:
	# Scale UI elements for mobile
	var root = get_parent()
	if not root:
		return
	
	# Find and scale all Control nodes
	_scale_control_recursive(root)
	
	# Enable haptics for all buttons
	if TouchInputManager:
		TouchInputManager.enable_haptics_for_scene(root)

func _scale_control_recursive(node: Node) -> void:
	# Recursively scale Control nodes
	if node is Control:
		MobileUIManager.apply_mobile_scaling(node)
	
	for child in node.get_children():
		_scale_control_recursive(child)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MOBILE ADJUSTMENT QUERIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_mobile_game_speed() -> float:
	# Get game speed multiplier for mobile (0.85 = 15% slower)
	# @return: Speed multiplier to apply to game logic
	# if MobileUIManager:
	# return MobileUIManager.get_game_speed_multiplier()
	# return 1.0
	#
	# func get_mobile_timing_window() -> float:Get timing window multiplier for mobile (1.2 = 20% larger)
	
	@return: Timing window multiplier for success detection
	# if MobileUIManager:
	# return MobileUIManager.get_timing_window_multiplier()
	# return 1.0
	#
	# func get_mobile_spawn_rate() -> float:Get spawn rate multiplier for mobile (0.9 = 10% slower)
	
	@return: Spawn rate multiplier to apply to object spawning
	# if MobileUIManager:
	# return MobileUIManager.get_spawn_rate_multiplier()
	# return 1.0
	#
	# func get_mobile_drag_smoothing() -> float:Get drag smoothing multiplier for mobile (1.5x)
	
	@return: Drag smoothing factor for reduced jitter
	# if MobileUIManager:
	# return MobileUIManager.get_drag_smoothing_multiplier()
	# return 1.0
	#
	# # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	# # DRAG VISUAL FEEDBACK
	# # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	#
	# func add_drag_visual_feedback(draggable: Node2D) -> void:Add visual feedback for draggable objects
	
	Adds highlight, shadow, or scale effect when object is being dragged.
	
	@param draggable: The Node2D object that can be dragged
	# if not draggable:
	# return
	#
	# # Add a highlight sprite as child
	# var highlight = Sprite2D.new()
	# highlight.name = "_drag_highlight"
	# highlight.modulate = Color(1, 1, 1, 0.5)
	# highlight.z_index = -1
	# highlight.visible = false
	#
	# # Copy texture from parent if it's a Sprite2D
	# if draggable is Sprite2D:
	# highlight.texture = draggable.texture
	# highlight.scale = Vector2(1.2, 1.2)  # 20% larger
	#
	# draggable.add_child(highlight)
	#
	# func show_drag_feedback(draggable: Node2D, is_dragging: bool) -> void:Show or hide drag visual feedback
	
	@param draggable: The draggable object
	@param is_dragging: True to show feedback, false to hide
	# if not draggable:
	# return
	#
	# var highlight = draggable.get_node_or_null("_drag_highlight")
	# if highlight:
	# highlight.visible = is_dragging
	#
	# if is_dragging:
	# # Scale up slightly
	# var tween = draggable.create_tween()
	# tween.tween_property(draggable, "scale", draggable.scale * 1.1, 0.1)
	# else:
	# # Scale back to normal
	# var tween = draggable.create_tween()
	# tween.tween_property(draggable, "scale", draggable.scale / 1.1, 0.1)
	#
	# # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	# # TOUCH ZONE INDICATORS
	# # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	#
	# func add_touch_zone_indicator(target: Node2D) -> void:Add visual indicator for touch zone on mobile
	
	Creates a visual indicator 30% larger than the interactive area
	to help players understand where they can touch.
	
	@param target: The Node2D to add indicator to
	if not MobileUIManager or not MobileUIManager.is_mobile_platform():
		return
	
	if not target:
		return
	
	TouchZoneIndicator.create_for_node(target)
