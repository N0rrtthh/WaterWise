class_name SafeAreaInfo
extends RefCounted

## ═══════════════════════════════════════════════════════════════════
## SAFE AREA INFO - DEVICE SAFE AREA DATA MODEL
## ═══════════════════════════════════════════════════════════════════
## Data model for device safe area information (notches, rounded corners)
## Calculates margins from DisplayServer and provides easy access
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SAFE AREA MARGINS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var top: float = 0.0
var bottom: float = 0.0
var left: float = 0.0
var right: float = 0.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - SAFE AREA CALCULATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func from_display_safe_area() -> void:
	# Calculate safe area margins from DisplayServer.get_display_safe_area()
	var safe_area = DisplayServer.get_display_safe_area()
	var screen_size = DisplayServer.screen_get_size()
	
	# Validate safe area data
	if not _is_valid_safe_area(safe_area, screen_size):
		# Only worth a warning where a safe area is expected to exist. Headless
		# runs and desktop report an empty rect by design, so warning there
		# means the log opens with a false problem on every single boot.
		if _platform_has_safe_area():
			push_warning(
				"Invalid safe area data received from DisplayServer, using zero margins"
			)
		_reset_margins()
		return
	
	# Calculate margins from safe area
	top = safe_area.position.y
	bottom = screen_size.y - (safe_area.position.y + safe_area.size.y)
	left = safe_area.position.x
	right = screen_size.x - (safe_area.position.x + safe_area.size.x)
	
	# Ensure non-negative margins
	top = max(0.0, top)
	bottom = max(0.0, bottom)
	left = max(0.0, left)
	right = max(0.0, right)

func to_dictionary() -> Dictionary:
	# Convert safe area margins to dictionary for easy access
	return {
		"top": top,
		"bottom": bottom,
		"left": left,
		"right": right
	}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PRIVATE HELPERS - VALIDATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## True only on platforms that actually report notches / cutouts.
## Everywhere else, an empty safe area is the correct answer rather than a fault.
func _platform_has_safe_area() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var platform := OS.get_name()
	return platform == "Android" or platform == "iOS"

func _is_valid_safe_area(safe_area: Rect2i, screen_size: Vector2i) -> bool:
	# Validate safe area data to prevent invalid calculations
	#
	# Invalid data is EXPECTED, not exceptional: headless runs, and desktop
	# platforms with no safe-area concept, both report a zero screen size. The
	# caller already emits one push_warning and falls back to zero margins, so
	# these checks return quietly instead of pushing an error per boot.
	# Check for zero or negative screen size
	if screen_size.x <= 0 or screen_size.y <= 0:
		return false
	
	# Check for negative safe area position
	if safe_area.position.x < 0 or safe_area.position.y < 0:
		return false
	
	# Check for zero or negative safe area size
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return false
	
	# Check if safe area extends beyond screen bounds
	if safe_area.position.x + safe_area.size.x > screen_size.x:
		return false
	
	if safe_area.position.y + safe_area.size.y > screen_size.y:
		return false
	
	return true

func _reset_margins() -> void:
	# Reset all margins to zero (fallback for invalid data)
	top = 0.0
	bottom = 0.0
	left = 0.0
	right = 0.0
