extends Node

## ═══════════════════════════════════════════════════════════════════
## MOBILE UI MANAGER - RESPONSIVE UI SYSTEM
## ═══════════════════════════════════════════════════════════════════
## Central manager for mobile-specific UI adaptations
## Handles platform detection, UI scaling, and layout management
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEPENDENCIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const UIScalerUtil = preload("res://scripts/mobile/UIScaler.gd")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal mobile_mode_changed(is_mobile: bool)
signal orientation_changed(is_portrait: bool)
signal safe_area_changed(margins: Dictionary)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION EXPORTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Scaling factors
@export var mobile_ui_scale: float = 1.5
@export var mobile_font_scale: float = 1.4
@export var mobile_game_object_scale: float = 1.4
@export var mobile_collectible_scale: float = 1.3

## Minimum sizes
@export var mobile_button_min_size: Vector2 = Vector2(100, 60)
@export var mobile_touch_target_min_size: Vector2 = Vector2(80, 80)

## Spacing
@export var mobile_button_spacing_vertical: float = 20.0
@export var mobile_button_spacing_horizontal: float = 15.0
@export var mobile_safe_area_margin: float = 20.0
@export var mobile_edge_dead_zone: float = 15.0

## Performance
@export var mobile_particle_reduction: float = 0.4
@export var mobile_max_tweens: int = 10
@export var mobile_target_fps: int = 30

## Gameplay adjustments
@export var mobile_game_speed_reduction: float = 0.15
@export var mobile_timing_window_increase: float = 0.2
@export var mobile_spawn_rate_reduction: float = 0.1
@export var mobile_drag_smoothing_increase: float = 1.5

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var is_mobile: bool = false
var is_portrait: bool = false
var safe_area_margins: Dictionary = {}
var debug_mobile_mode: bool = false
var debug_logging_enabled: bool = false
var debug_visualization_enabled: bool = false
var viewport_width: int = 0
var viewport_height: int = 0

# Orientation change detection
var _orientation_change_timer: float = 0.0
var _pending_orientation_change: bool = false
var _new_orientation: bool = false

# Frame rate monitoring
var _fps_samples: Array[float] = []
var _fps_sample_interval: float = 1.0  # Sample FPS every second
var _fps_sample_timer: float = 0.0
var _low_fps_warning_shown: bool = false

# Background state
var _is_in_background: bool = false

# Debug visualization
var _debug_overlay: CanvasLayer = null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	_detect_platform()
	_detect_orientation()
	_calculate_safe_area()
	_load_config_if_exists()
	
	# Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Connect to app focus changes for background CPU reduction
	get_tree().root.focus_entered.connect(_on_app_focus_gained)
	get_tree().root.focus_exited.connect(_on_app_focus_lost)
	
	# Create debug overlay if enabled
	if debug_visualization_enabled:
		_create_debug_overlay()
	
	print("📱 MobileUIManager initialized")
	print("   - Platform: %s" % ("Mobile" if is_mobile else "Desktop"))
	print("   - Viewport: %dx%d" % [viewport_width, viewport_height])
	print("   - Orientation: %s" % ("Portrait" if is_portrait else "Landscape"))
	print("   - Debug Mode: %s" % debug_mobile_mode)

func _process(delta: float) -> void:
	# Monitor viewport size, detect orientation changes, and track FPS
	# Get current viewport size
	var viewport = get_viewport()
	if not viewport:
		return
	
	var viewport_size = viewport.get_visible_rect().size
	var current_width = int(viewport_size.x)
	var current_height = int(viewport_size.y)
	
	# Check if viewport size changed
	if current_width != viewport_width or current_height != viewport_height:
		viewport_width = current_width
		viewport_height = current_height
		
		# Detect new orientation
		var new_is_portrait = viewport_height > viewport_width
		
		# Check if orientation changed
		if new_is_portrait != is_portrait:
			# Start orientation change timer
			_pending_orientation_change = true
			_new_orientation = new_is_portrait
			_orientation_change_timer = 0.0
	
	# Handle pending orientation change
	if _pending_orientation_change:
		_orientation_change_timer += delta
		
		# Trigger layout reorganization within 0.5 seconds
		if _orientation_change_timer >= 0.5:
			is_portrait = _new_orientation
			orientation_changed.emit(is_portrait)
			_pending_orientation_change = false
			_orientation_change_timer = 0.0
			
			print("📱 Orientation changed: %s" % ("Portrait" if is_portrait else "Landscape"))
	
	# Frame rate monitoring (mobile only)
	if is_mobile and not _is_in_background:
		_monitor_frame_rate(delta)

func _detect_platform() -> void:
	# Detect if running on mobile platform or small viewport
	# Check OS platform
	var os_name = OS.get_name()
	var is_mobile_os = os_name in ["Android", "iOS"]
	
	# Check viewport size
	var viewport = get_viewport()
	if viewport:
		var viewport_size = viewport.get_visible_rect().size
		viewport_width = int(viewport_size.x)
		viewport_height = int(viewport_size.y)
		var is_small_viewport = viewport_width < 800
		
		# Mobile if either mobile OS or small viewport
		is_mobile = is_mobile_os or is_small_viewport
	else:
		is_mobile = is_mobile_os
	
	# Apply debug flag override
	if debug_mobile_mode:
		is_mobile = true

func _detect_orientation() -> void:
	# Detect if viewport is in portrait or landscape orientation
	is_portrait = viewport_height > viewport_width

func _calculate_safe_area() -> void:
	# Calculate safe area margins for devices with notches
	#
	# 	Uses SafeAreaInfo to calculate margins from DisplayServer and applies
	# 	a 20-pixel minimum margin from safe area boundaries as per requirements.
	# 	Emits safe_area_changed signal with the calculated margins.
	# Use SafeAreaInfo to calculate safe area margins
	var safe_area_info = SafeAreaInfo.new()
	safe_area_info.from_display_safe_area()
	
	# Get base margins from SafeAreaInfo
	var base_margins = safe_area_info.to_dictionary()
	
	# Apply 20-pixel minimum margin from safe area boundaries (Requirement 5.6)
	safe_area_margins = {
		"top": base_margins["top"] + mobile_safe_area_margin,
		"bottom": base_margins["bottom"] + mobile_safe_area_margin,
		"left": base_margins["left"] + mobile_safe_area_margin,
		"right": base_margins["right"] + mobile_safe_area_margin
	}
	
	# Emit signal with updated margins
	safe_area_changed.emit(safe_area_margins)

func _load_config_if_exists() -> void:
	# Load configuration from file if it exists
	var config_path = "user://mobile_ui_config.cfg"
	if FileAccess.file_exists(config_path):
		load_config_file(config_path)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - PLATFORM DETECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func is_mobile_platform() -> bool:
	# Returns true if running on mobile platform or small viewport
	return is_mobile

func is_portrait_orientation() -> bool:
	# Returns true if viewport is in portrait orientation
	return is_portrait

func is_landscape_orientation() -> bool:
	# Returns true if viewport is in landscape orientation
	return not is_portrait

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - SCALING FACTORS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_ui_scale() -> float:
	# Returns UI scale factor for mobile (1.5x) or desktop (1.0x)
	return mobile_ui_scale if is_mobile else 1.0

func get_font_scale() -> float:
	# Returns font scale factor for mobile (1.4x) or desktop (1.0x)
	return mobile_font_scale if is_mobile else 1.0

func get_game_object_scale() -> float:
	# Returns game object scale factor for mobile (1.4x) or desktop (1.0x)
	return mobile_game_object_scale if is_mobile else 1.0

func get_collectible_scale() -> float:
	# Returns collectible scale factor for mobile (1.3x) or desktop (1.0x)
	return mobile_collectible_scale if is_mobile else 1.0

func get_button_min_size() -> Vector2:
	# Returns minimum button size for mobile (100x60) or desktop (44x44)
	return mobile_button_min_size if is_mobile else Vector2(44, 44)

func get_touch_target_min_size() -> Vector2:
	# Returns minimum touch target size for mobile (80x80) or desktop (44x44)
	return mobile_touch_target_min_size if is_mobile else Vector2(44, 44)

func get_button_spacing_vertical() -> float:
	# Returns vertical button spacing for mobile (20px) or desktop (10px)
	return mobile_button_spacing_vertical if is_mobile else 10.0

func get_button_spacing_horizontal() -> float:
	# Returns horizontal button spacing for mobile (15px) or desktop (10px)
	return mobile_button_spacing_horizontal if is_mobile else 10.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - SAFE AREA
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_safe_area_margins() -> Dictionary:
	# Returns safe area margins for devices with notches
	return safe_area_margins

func get_safe_area_margin() -> float:
	# Returns minimum margin from safe area boundaries (20px)
	return mobile_safe_area_margin

func get_edge_dead_zone() -> float:
	# Returns edge dead zone size for preventing accidental touches (15px)
	return mobile_edge_dead_zone

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - PERFORMANCE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_particle_reduction() -> float:
	# Returns particle reduction factor for mobile (0.4 = 40% reduction)
	return mobile_particle_reduction if is_mobile else 0.0

func get_max_tweens() -> int:
	# Returns maximum simultaneous tweens for mobile (10)
	return mobile_max_tweens if is_mobile else 999

func get_target_fps() -> int:
	# Returns target FPS for mobile (30)
	return mobile_target_fps if is_mobile else 60

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - GAMEPLAY ADJUSTMENTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_game_speed_multiplier() -> float:
	# Returns game speed multiplier for mobile (0.85 = 15% slower)
	return 1.0 - mobile_game_speed_reduction if is_mobile else 1.0

func get_timing_window_multiplier() -> float:
	# Returns timing window multiplier for mobile (1.2 = 20% larger)
	return 1.0 + mobile_timing_window_increase if is_mobile else 1.0

func get_spawn_rate_multiplier() -> float:
	# Returns spawn rate multiplier for mobile (0.9 = 10% slower)
	return 1.0 - mobile_spawn_rate_reduction if is_mobile else 1.0

func get_drag_smoothing_multiplier() -> float:
	# Returns drag smoothing multiplier for mobile (1.5x)
	return mobile_drag_smoothing_increase if is_mobile else 1.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - UI SCALING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func apply_mobile_scaling(node: Control) -> void:
	# Apply mobile-specific scaling to a Control node
	if not is_mobile:
		return
	
	if not node:
		push_warning("MobileUIManager.apply_mobile_scaling: node is null")
		return
	
	_log_debug("Scaling Control node: %s (original size: %s)" % [node.name, node.size])
	
	# Apply UI scale factor
	UIScalerUtil.scale_control_node(node, mobile_ui_scale)
	
	# Apply button-specific handling
	if node is Button:
		# Ensure minimum button size (100x60 pixels)
		UIScalerUtil.ensure_minimum_size(node, mobile_button_min_size)
		
		# Add expanded hit detection area (10 pixels beyond visual boundaries)
		# This is done by increasing the custom_minimum_size slightly
		var expanded_size = node.custom_minimum_size + Vector2(20, 20)  # 10px on each side
		node.custom_minimum_size = expanded_size
		
		# Apply font scaling to button label
		# Buttons in Godot have their text rendered internally, but we can scale the font
		if node.get_theme_font_size("font_size") > 0:
			var current_font_size = node.get_theme_font_size("font_size")
			var scaled_font_size = int(current_font_size * mobile_font_scale)
			node.add_theme_font_size_override("font_size", scaled_font_size)
	
	# Apply font scaling to labels
	if node is Label:
		UIScalerUtil.scale_font(node, mobile_font_scale)
	
	# Ensure all touch targets meet minimum size
	UIScalerUtil.ensure_minimum_size(node, mobile_touch_target_min_size)
	
	_log_debug("Scaled Control node: %s (final size: %s)" % [node.name, node.size])

func apply_game_object_scaling(node: Node2D) -> void:
	# Apply mobile-specific scaling to game objects (Node2D)
	#
	# 	Scales interactive objects by 1.4x and collectibles by 1.3x.
	# 	Ensures draggable objects have minimum 120x120 pixel area.
	# 	Preserves collision shapes during scaling.
	#
	# 	@param node: The Node2D game object to scale
	if not is_mobile:
		return
	
	if not node:
		push_warning("MobileUIManager.apply_game_object_scaling: node is null")
		return
	
	_log_debug("Scaling game object: %s (original scale: %s)" % [node.name, node.scale])
	
	# Determine scale factor based on object type
	var scale_factor: float = mobile_game_object_scale  # Default: 1.4x for interactive objects
	
	# Check if this is a collectible (by name or group)
	var is_collectible = (
		"collectible" in node.name.to_lower() or
		"drop" in node.name.to_lower() or
		"coin" in node.name.to_lower() or
		"item" in node.name.to_lower() or
		node.is_in_group("collectibles")
	)
	
	if is_collectible:
		scale_factor = mobile_collectible_scale  # 1.3x for collectibles
	
	# Store original scale to preserve any existing scaling
	var original_scale = node.scale
	
	# Apply mobile scaling while preserving aspect ratio
	node.scale = original_scale * scale_factor
	
	# Check if this is a draggable object and ensure minimum size
	var is_draggable = (
		"drag" in node.name.to_lower() or
		node.is_in_group("draggable") or
		node.get("input_pickable") == true
	)
	
	if is_draggable:
		# Calculate effective size after scaling
		# For Node2D, we need to check if there's a visual representation
		var effective_size = Vector2.ZERO
		
		# Try to get size from Sprite2D
		var sprite = node.get_node_or_null("Sprite2D")
		if not sprite and node is Sprite2D:
			sprite = node
		
		if sprite and sprite is Sprite2D:
			var texture = sprite.texture
			if texture:
				effective_size = texture.get_size() * node.scale
		
		# Try to get size from CollisionShape2D
		if effective_size == Vector2.ZERO:
			var collision = node.get_node_or_null("CollisionShape2D")
			if not collision and node is CollisionShape2D:
				collision = node
			
			if collision and collision is CollisionShape2D:
				var shape = collision.shape
				if shape:
					if shape is RectangleShape2D:
						effective_size = shape.size * node.scale
					elif shape is CircleShape2D:
						var diameter = shape.radius * 2.0
						effective_size = Vector2(diameter, diameter) * node.scale
					elif shape is CapsuleShape2D:
						effective_size = Vector2(shape.radius * 2.0, shape.height) * node.scale
		
		# Ensure minimum draggable area of 120x120 pixels
		var min_draggable_size = Vector2(120, 120)
		if effective_size != Vector2.ZERO:
			if effective_size.x < min_draggable_size.x or effective_size.y < min_draggable_size.y:
				# Calculate additional scaling needed
				var additional_scale_x = min_draggable_size.x / effective_size.x if effective_size.x > 0 else 1.0
				var additional_scale_y = min_draggable_size.y / effective_size.y if effective_size.y > 0 else 1.0
				var additional_scale = max(additional_scale_x, additional_scale_y)
				
				# Apply additional scaling to meet minimum size
				node.scale *= additional_scale
	
	# Collision shapes are automatically scaled with the parent node in Godot
	# No additional work needed to preserve collision detection accuracy
	
	_log_debug("Scaled game object: %s (final scale: %s, type: %s)" % [node.name, node.scale, "collectible" if is_collectible else ("draggable" if is_draggable else "interactive")])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - DEMO BUTTONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func should_show_demo_buttons() -> bool:
	# Returns true if demo buttons should be visible
	# Hide on mobile unless in debug mode
	if is_mobile and not OS.is_debug_build():
		return false
	
	# Show on desktop in debug mode
	if OS.is_debug_build():
		return true
	
	# Hide in production builds
	return false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - DEBUG MODE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func enable_debug_mobile_mode(enabled: bool) -> void:
	# Enable/disable debug mobile mode for testing on desktop
	debug_mobile_mode = enabled
	_detect_platform()
	mobile_mode_changed.emit(is_mobile)
	
	print("📱 Debug mobile mode: %s" % ("enabled" if enabled else "disabled"))
	print("   - is_mobile: %s" % is_mobile)

func is_debug_mode() -> bool:
	# Returns true if debug mobile mode is enabled
	return debug_mobile_mode

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func load_config_file(path: String) -> bool:
	# Load configuration from file
	var config = ConfigFile.new()
	var err = config.load(path)
	
	if err != OK:
		push_warning("Failed to load mobile UI config from %s: %s" % [path, error_string(err)])
		return false
	
	# Load scaling factors
	mobile_ui_scale = config.get_value("scaling", "ui_scale", mobile_ui_scale)
	mobile_font_scale = config.get_value("scaling", "font_scale", mobile_font_scale)
	mobile_game_object_scale = config.get_value("scaling", "game_object_scale", mobile_game_object_scale)
	mobile_collectible_scale = config.get_value("scaling", "collectible_scale", mobile_collectible_scale)
	
	# Load minimum sizes
	mobile_button_min_size = config.get_value("sizes", "button_min_size", mobile_button_min_size)
	mobile_touch_target_min_size = config.get_value("sizes", "touch_target_min_size", mobile_touch_target_min_size)
	
	# Load spacing
	mobile_button_spacing_vertical = config.get_value("spacing", "button_vertical", mobile_button_spacing_vertical)
	mobile_button_spacing_horizontal = config.get_value("spacing", "button_horizontal", mobile_button_spacing_horizontal)
	mobile_safe_area_margin = config.get_value("spacing", "safe_area_margin", mobile_safe_area_margin)
	mobile_edge_dead_zone = config.get_value("spacing", "edge_dead_zone", mobile_edge_dead_zone)
	
	# Load performance settings
	mobile_particle_reduction = config.get_value("performance", "particle_reduction", mobile_particle_reduction)
	mobile_max_tweens = config.get_value("performance", "max_tweens", mobile_max_tweens)
	mobile_target_fps = config.get_value("performance", "target_fps", mobile_target_fps)
	
	# Load gameplay adjustments
	mobile_game_speed_reduction = config.get_value("gameplay", "speed_reduction", mobile_game_speed_reduction)
	mobile_timing_window_increase = config.get_value("gameplay", "timing_window_increase", mobile_timing_window_increase)
	mobile_spawn_rate_reduction = config.get_value("gameplay", "spawn_rate_reduction", mobile_spawn_rate_reduction)
	mobile_drag_smoothing_increase = config.get_value("gameplay", "drag_smoothing_increase", mobile_drag_smoothing_increase)
	
	print("📱 Loaded mobile UI config from %s" % path)
	return true

func save_config_file(path: String) -> bool:
	# Save current configuration to file
	var config = ConfigFile.new()
	
	# Save scaling factors
	config.set_value("scaling", "ui_scale", mobile_ui_scale)
	config.set_value("scaling", "font_scale", mobile_font_scale)
	config.set_value("scaling", "game_object_scale", mobile_game_object_scale)
	config.set_value("scaling", "collectible_scale", mobile_collectible_scale)
	
	# Save minimum sizes
	config.set_value("sizes", "button_min_size", mobile_button_min_size)
	config.set_value("sizes", "touch_target_min_size", mobile_touch_target_min_size)
	
	# Save spacing
	config.set_value("spacing", "button_vertical", mobile_button_spacing_vertical)
	config.set_value("spacing", "button_horizontal", mobile_button_spacing_horizontal)
	config.set_value("spacing", "safe_area_margin", mobile_safe_area_margin)
	config.set_value("spacing", "edge_dead_zone", mobile_edge_dead_zone)
	
	# Save performance settings
	config.set_value("performance", "particle_reduction", mobile_particle_reduction)
	config.set_value("performance", "max_tweens", mobile_max_tweens)
	config.set_value("performance", "target_fps", mobile_target_fps)
	
	# Save gameplay adjustments
	config.set_value("gameplay", "speed_reduction", mobile_game_speed_reduction)
	config.set_value("gameplay", "timing_window_increase", mobile_timing_window_increase)
	config.set_value("gameplay", "spawn_rate_reduction", mobile_spawn_rate_reduction)
	config.set_value("gameplay", "drag_smoothing_increase", mobile_drag_smoothing_increase)
	
	var err = config.save(path)
	if err != OK:
		push_error("Failed to save mobile UI config to %s: %s" % [path, error_string(err)])
		return false
	
	print("📱 Saved mobile UI config to %s" % path)
	return true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EVENT HANDLERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_viewport_size_changed() -> void:
	# Handle viewport size changes (orientation changes)
	var old_is_mobile = is_mobile
	var old_is_portrait = is_portrait
	
	_detect_platform()
	_detect_orientation()
	_calculate_safe_area()  # This now emits safe_area_changed signal
	
	# Emit signals if state changed
	if old_is_mobile != is_mobile:
		mobile_mode_changed.emit(is_mobile)
	
	if old_is_portrait != is_portrait:
		orientation_changed.emit(is_portrait)
		_log_debug("Orientation changed to: %s" % ("Portrait" if is_portrait else "Landscape"))
	
	# Update debug overlay if active
	if _debug_overlay:
		_destroy_debug_overlay()
		_create_debug_overlay()
	
	print("📱 Viewport size changed: %dx%d (%s)" % [viewport_width, viewport_height, "Portrait" if is_portrait else "Landscape"])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FRAME RATE MONITORING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _monitor_frame_rate(delta: float) -> void:
	# Monitor FPS and log warnings when performance drops below target
	#
	# 	Tracks FPS using Engine.get_frames_per_second() and logs warnings
	# 	when FPS drops below 30 on mobile. Samples FPS every second.
	_fps_sample_timer += delta
	
	if _fps_sample_timer >= _fps_sample_interval:
		var current_fps = Engine.get_frames_per_second()
		_fps_samples.append(current_fps)
		
		# Keep only last 5 samples
		if _fps_samples.size() > 5:
			_fps_samples.remove_at(0)
		
		# Calculate average FPS
		var avg_fps = 0.0
		for fps in _fps_samples:
			avg_fps += fps
		avg_fps /= _fps_samples.size()
		
		# Log warning if FPS drops below target
		if avg_fps < mobile_target_fps and not _low_fps_warning_shown:
			push_warning("📱 Low FPS detected: %.1f (target: %d)" % [avg_fps, mobile_target_fps])
			_low_fps_warning_shown = true
		elif avg_fps >= mobile_target_fps:
			_low_fps_warning_shown = false
		
		_fps_sample_timer = 0.0

func get_current_fps() -> float:
	# Get the current frames per second
	#
	# 	@return: Current FPS from Engine
	return Engine.get_frames_per_second()

func get_average_fps() -> float:
	# Get the average FPS from recent samples
	#
	# 	@return: Average FPS over last 5 seconds, or 0 if no samples
	if _fps_samples.is_empty():
		return 0.0
	
	var sum = 0.0
	for fps in _fps_samples:
		sum += fps
	return sum / _fps_samples.size()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BACKGROUND CPU REDUCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_app_focus_lost() -> void:
	# Handle app going to background
	#
	# 	Pauses all animations, reduces process priority, and disables
	# 	unnecessary updates to conserve battery and CPU.
	if not is_mobile:
		return
	
	_is_in_background = true
	
	# Pause the scene tree
	get_tree().paused = true
	
	# Disable screen keep-on when in background
	DisplayServer.screen_set_keep_on(false)
	
	print("📱 App went to background - pausing updates")

func _on_app_focus_gained() -> void:
	# Handle app returning to foreground
	#
	# 	Resumes all animations and normal processing.
	if not is_mobile:
		return
	
	_is_in_background = false
	
	# Resume the scene tree
	get_tree().paused = false
	
	# Re-enable screen keep-on when returning to foreground
	DisplayServer.screen_set_keep_on(true)
	
	print("📱 App returned to foreground - resuming updates")

func is_in_background() -> bool:
	# Check if app is currently in background
	#
	# 	@return: True if app is in background
	return _is_in_background

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEBUG VISUALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func enable_debug_visualization(enabled: bool) -> void:
	# Enable or disable debug visualization overlay
	#
	# 	Shows safe area boundaries as colored rectangles when enabled.
	#
	# 	@param enabled: True to show debug overlay
	debug_visualization_enabled = enabled
	
	if enabled and not _debug_overlay:
		_create_debug_overlay()
	elif not enabled and _debug_overlay:
		_destroy_debug_overlay()

func _create_debug_overlay() -> void:
	# Create debug overlay showing safe area boundaries
	if _debug_overlay:
		return
	
	_debug_overlay = CanvasLayer.new()
	_debug_overlay.name = "_MobileDebugOverlay"
	_debug_overlay.layer = 100  # On top of everything
	add_child(_debug_overlay)
	
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Top margin (red)
	var top_rect = ColorRect.new()
	top_rect.color = Color(1, 0, 0, 0.3)
	top_rect.position = Vector2(0, 0)
	top_rect.size = Vector2(viewport_size.x, safe_area_margins.get("top", 0))
	_debug_overlay.add_child(top_rect)
	
	# Bottom margin (green)
	var bottom_rect = ColorRect.new()
	bottom_rect.color = Color(0, 1, 0, 0.3)
	var bottom_margin = safe_area_margins.get("bottom", 0)
	bottom_rect.position = Vector2(0, viewport_size.y - bottom_margin)
	bottom_rect.size = Vector2(viewport_size.x, bottom_margin)
	_debug_overlay.add_child(bottom_rect)
	
	# Left margin (blue)
	var left_rect = ColorRect.new()
	left_rect.color = Color(0, 0, 1, 0.3)
	left_rect.position = Vector2(0, 0)
	left_rect.size = Vector2(safe_area_margins.get("left", 0), viewport_size.y)
	_debug_overlay.add_child(left_rect)
	
	# Right margin (yellow)
	var right_rect = ColorRect.new()
	right_rect.color = Color(1, 1, 0, 0.3)
	var right_margin = safe_area_margins.get("right", 0)
	right_rect.position = Vector2(viewport_size.x - right_margin, 0)
	right_rect.size = Vector2(right_margin, viewport_size.y)
	_debug_overlay.add_child(right_rect)
	
	# Info label
	var info_label = Label.new()
	info_label.text = "Safe Area Debug (Red=Top, Green=Bottom, Blue=Left, Yellow=Right)"
	info_label.position = Vector2(10, 10)
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color.WHITE)
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	info_label.add_theme_constant_override("outline_size", 2)
	_debug_overlay.add_child(info_label)
	
	print("📱 Debug visualization enabled")

func _destroy_debug_overlay() -> void:
	# Remove debug overlay
	if _debug_overlay:
		_debug_overlay.queue_free()
		_debug_overlay = null
		print("📱 Debug visualization disabled")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEBUG LOGGING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func enable_debug_logging(enabled: bool) -> void:
	# Enable or disable debug logging for scaling operations
	#
	# 	Logs all scaling operations, layout reorganization, and performance metrics.
	#
	# 	@param enabled: True to enable debug logging
	debug_logging_enabled = enabled
	print("📱 Debug logging: %s" % ("enabled" if enabled else "disabled"))

func _log_debug(message: String) -> void:
	# Log debug message if debug logging is enabled
	if debug_logging_enabled:
		print("📱 [DEBUG] " + message)
