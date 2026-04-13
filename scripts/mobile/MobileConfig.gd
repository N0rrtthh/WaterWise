class_name MobileConfig
extends RefCounted

## ═══════════════════════════════════════════════════════════════════
## MOBILE CONFIG - CONFIGURATION DATA MODEL
## ═══════════════════════════════════════════════════════════════════
## Data model for mobile UI configuration settings
## Handles loading and saving configuration from/to files
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SCALING FACTORS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var ui_scale: float = 1.5
var font_scale: float = 1.4
var game_object_scale: float = 1.4
var collectible_scale: float = 1.3

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MINIMUM SIZES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var button_min_size: Vector2 = Vector2(100, 60)
var touch_target_min_size: Vector2 = Vector2(80, 80)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SPACING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var button_spacing_vertical: float = 20.0
var button_spacing_horizontal: float = 15.0
var safe_area_margin: float = 20.0
var edge_dead_zone: float = 15.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PERFORMANCE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var particle_reduction: float = 0.4
var max_tweens: int = 10
var target_fps: int = 30

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAMEPLAY ADJUSTMENTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var game_speed_reduction: float = 0.15
var timing_window_increase: float = 0.2
var spawn_rate_reduction: float = 0.1
var drag_smoothing_increase: float = 1.5
var visual_indicator_scale: float = 1.3

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - FILE OPERATIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func load_from_file(path: String) -> bool:
	"""Load configuration from file using ConfigFile API"""
	var config = ConfigFile.new()
	var err = config.load(path)
	
	if err != OK:
		push_warning("Failed to load mobile config from %s: %s" % [path, error_string(err)])
		return false
	
	# Load scaling factors
	ui_scale = config.get_value("scaling", "ui_scale", ui_scale)
	font_scale = config.get_value("scaling", "font_scale", font_scale)
	game_object_scale = config.get_value("scaling", "game_object_scale", game_object_scale)
	collectible_scale = config.get_value("scaling", "collectible_scale", collectible_scale)
	
	# Load minimum sizes
	button_min_size = config.get_value("sizes", "button_min_size", button_min_size)
	touch_target_min_size = config.get_value("sizes", "touch_target_min_size", touch_target_min_size)
	
	# Load spacing
	button_spacing_vertical = config.get_value("spacing", "button_vertical", button_spacing_vertical)
	button_spacing_horizontal = config.get_value("spacing", "button_horizontal", button_spacing_horizontal)
	safe_area_margin = config.get_value("spacing", "safe_area_margin", safe_area_margin)
	edge_dead_zone = config.get_value("spacing", "edge_dead_zone", edge_dead_zone)
	
	# Load performance settings
	particle_reduction = config.get_value("performance", "particle_reduction", particle_reduction)
	max_tweens = config.get_value("performance", "max_tweens", max_tweens)
	target_fps = config.get_value("performance", "target_fps", target_fps)
	
	# Load gameplay adjustments
	game_speed_reduction = config.get_value("gameplay", "speed_reduction", game_speed_reduction)
	timing_window_increase = config.get_value("gameplay", "timing_window_increase", timing_window_increase)
	spawn_rate_reduction = config.get_value("gameplay", "spawn_rate_reduction", spawn_rate_reduction)
	drag_smoothing_increase = config.get_value("gameplay", "drag_smoothing_increase", drag_smoothing_increase)
	visual_indicator_scale = config.get_value("gameplay", "visual_indicator_scale", visual_indicator_scale)
	
	print("📱 Loaded mobile config from %s" % path)
	return true

func save_to_file(path: String) -> bool:
	"""Save current configuration to file for persistence"""
	var config = ConfigFile.new()
	
	# Save scaling factors
	config.set_value("scaling", "ui_scale", ui_scale)
	config.set_value("scaling", "font_scale", font_scale)
	config.set_value("scaling", "game_object_scale", game_object_scale)
	config.set_value("scaling", "collectible_scale", collectible_scale)
	
	# Save minimum sizes
	config.set_value("sizes", "button_min_size", button_min_size)
	config.set_value("sizes", "touch_target_min_size", touch_target_min_size)
	
	# Save spacing
	config.set_value("spacing", "button_vertical", button_spacing_vertical)
	config.set_value("spacing", "button_horizontal", button_spacing_horizontal)
	config.set_value("spacing", "safe_area_margin", safe_area_margin)
	config.set_value("spacing", "edge_dead_zone", edge_dead_zone)
	
	# Save performance settings
	config.set_value("performance", "particle_reduction", particle_reduction)
	config.set_value("performance", "max_tweens", max_tweens)
	config.set_value("performance", "target_fps", target_fps)
	
	# Save gameplay adjustments
	config.set_value("gameplay", "speed_reduction", game_speed_reduction)
	config.set_value("gameplay", "timing_window_increase", timing_window_increase)
	config.set_value("gameplay", "spawn_rate_reduction", spawn_rate_reduction)
	config.set_value("gameplay", "drag_smoothing_increase", drag_smoothing_increase)
	config.set_value("gameplay", "visual_indicator_scale", visual_indicator_scale)
	
	var err = config.save(path)
	if err != OK:
		push_error("Failed to save mobile config to %s: %s" % [path, error_string(err)])
		return false
	
	print("📱 Saved mobile config to %s" % path)
	return true
