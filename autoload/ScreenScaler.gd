extends Node

## ═══════════════════════════════════════════════════════════════════
## SCREEN SCALER - DYNAMIC GAME CONTENT SCALING
## ═══════════════════════════════════════════════════════════════════
## Scales game content (sprites, animations, minigames) to fill screen
## Works with viewport stretch mode to ensure everything fills the screen
## ═══════════════════════════════════════════════════════════════════

const BASE_WIDTH = 1920.0
const BASE_HEIGHT = 1080.0

var screen_scale: Vector2 = Vector2.ONE
var screen_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	_calculate_screen_scale()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Auto-scale scenes when they load
	get_tree().node_added.connect(_on_node_added)
	
	print("📐 ScreenScaler initialized")
	print("   Screen size: %dx%d" % [screen_size.x, screen_size.y])
	print("   Scale factor: %.2fx%.2f" % [screen_scale.x, screen_scale.y])

func _calculate_screen_scale() -> void:
	var viewport = get_viewport()
	if not viewport:
		return
	
	screen_size = viewport.get_visible_rect().size
	
	# Calculate scale factor to fill screen
	screen_scale.x = screen_size.x / BASE_WIDTH
	screen_scale.y = screen_size.y / BASE_HEIGHT
	
	print("📐 Screen scale updated: %.2fx%.2f" % [screen_scale.x, screen_scale.y])

func _on_viewport_size_changed() -> void:
	_calculate_screen_scale()

func _on_node_added(node: Node) -> void:
	# Auto-scale game scenes when they're added
	if node is Node2D or node is Control:
		# Check if this is a game scene root
		var scene_path = node.scene_file_path
		if scene_path.contains("minigames/") or scene_path.contains("cutscenes/"):
			call_deferred("scale_game_content", node)

## Scale game content to fill screen
func scale_game_content(root: Node) -> void:
	if not root:
		return
	
	# Don't scale UI elements
	if root is Control and not root.scene_file_path.contains("minigames/"):
		return
	
	# Scale Node2D game content
	if root is Node2D:
		# Use the smaller scale factor to ensure everything fits
		var scale_factor = min(screen_scale.x, screen_scale.y)
		root.scale = Vector2(scale_factor, scale_factor)
		print("📐 Scaled game content: %s (%.2fx)" % [root.name, scale_factor])

## Get current screen scale factor
func get_scale_factor() -> Vector2:
	return screen_scale

## Get uniform scale factor (smaller of x/y to maintain aspect ratio)
func get_uniform_scale() -> float:
	return min(screen_scale.x, screen_scale.y)

## Scale a node to fill screen
func scale_to_fill(node: Node2D) -> void:
	if not node:
		return
	var scale_factor = min(screen_scale.x, screen_scale.y)
	node.scale = Vector2(scale_factor, scale_factor)

## Scale a node to fit screen (may have letterboxing)
func scale_to_fit(node: Node2D) -> void:
	if not node:
		return
	var scale_factor = max(screen_scale.x, screen_scale.y)
	node.scale = Vector2(scale_factor, scale_factor)
