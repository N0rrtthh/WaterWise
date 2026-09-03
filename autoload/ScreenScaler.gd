extends Node

## ═══════════════════════════════════════════════════════════════════
## SCREEN SCALER - DYNAMIC GAME CONTENT SCALING
## ═══════════════════════════════════════════════════════════════════
## Works alongside the project's stretch settings (canvas_items + expand)
## to ensure game content fills the viewport correctly on all devices.
##
## With canvas_items/EXPAND, the viewport does NOT stay at 1920×1080: one
## axis is held at the design size and the other grows to match the device
## aspect, so nothing is letterboxed and no content is cropped. On a 19.5:9
## phone the visible rect measures ~2411×1080 and screen_scale is (1.26, 1.0).
## Scenes that build Node2D content in code use the helpers below to match.
##
## Under --headless there is no real window (DisplayServer reports 0×0 and the
## backing store is 64×64, aspect 1.0), so EXPAND resolves the visible rect to
## a square 1920×1920 and scale_y prints as 1.78. That is a property of the
## headless driver, not a scaling defect — verified with tools/ViewportProbe.tscn,
## which reports 2411×1080 / (1.26, 1.0) for the same build in a real window.
## ═══════════════════════════════════════════════════════════════════

const BASE_WIDTH = 1920.0
const BASE_HEIGHT = 1080.0

var screen_scale: Vector2 = Vector2.ONE
var screen_size: Vector2 = Vector2(BASE_WIDTH, BASE_HEIGHT)

func _ready() -> void:
	_calculate_screen_scale()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	print("📐 ScreenScaler initialized")
	print("   Screen size: %dx%d" % [screen_size.x, screen_size.y])
	print("   Scale factor: %.2fx%.2f" % [screen_scale.x, screen_scale.y])

func _calculate_screen_scale() -> void:
	var viewport = get_viewport()
	if not viewport:
		return
	
	screen_size = viewport.get_visible_rect().size
	
	# Calculate scale factor relative to design resolution
	screen_scale.x = screen_size.x / BASE_WIDTH
	screen_scale.y = screen_size.y / BASE_HEIGHT

func _on_viewport_size_changed() -> void:
	_calculate_screen_scale()

## Get current screen scale factor
func get_scale_factor() -> Vector2:
	return screen_scale

## Get uniform scale factor (smaller of x/y to maintain aspect ratio)
func get_uniform_scale() -> float:
	return min(screen_scale.x, screen_scale.y)

## Scale a Node2D to fill screen (use larger factor — may crop edges)
func scale_to_fill(node: Node2D) -> void:
	if not node:
		return
	var scale_factor = max(screen_scale.x, screen_scale.y)
	node.scale = Vector2(scale_factor, scale_factor)

## Scale a Node2D to fit screen (use smaller factor — may letterbox)
func scale_to_fit(node: Node2D) -> void:
	if not node:
		return
	var scale_factor = min(screen_scale.x, screen_scale.y)
	node.scale = Vector2(scale_factor, scale_factor)
