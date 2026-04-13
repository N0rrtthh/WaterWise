extends Node

## ═══════════════════════════════════════════════════════════════════
## GAME OBJECT SCALING VALIDATION SCRIPT
## ═══════════════════════════════════════════════════════════════════
## Simple validation script to verify apply_game_object_scaling logic
## Run this in Godot editor to validate the implementation
## ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("GAME OBJECT SCALING VALIDATION")
	print("=".repeat(70) + "\n")
	
	# Enable mobile mode
	MobileUIManager.enable_debug_mobile_mode(true)
	
	validate_interactive_object_scaling()
	validate_collectible_scaling()
	validate_draggable_minimum_size()
	validate_collision_preservation()
	validate_aspect_ratio_preservation()
	
	print("\n" + "=".repeat(70))
	print("VALIDATION COMPLETE")
	print("=".repeat(70) + "\n")

func validate_interactive_object_scaling() -> void:
	print("✓ Validating interactive object scaling (1.4x)...")
	var node = Node2D.new()
	node.name = "InteractiveObject"
	node.scale = Vector2(1.0, 1.0)
	
	MobileUIManager.apply_game_object_scaling(node)
	
	assert(abs(node.scale.x - 1.4) < 0.001, "Interactive object X scale should be 1.4")
	assert(abs(node.scale.y - 1.4) < 0.001, "Interactive object Y scale should be 1.4")
	
	node.free()
	print("  → Interactive objects scale to 1.4x ✓\n")

func validate_collectible_scaling() -> void:
	print("✓ Validating collectible scaling (1.3x)...")
	
	# Test with "drop" keyword
	var drop = Node2D.new()
	drop.name = "WaterDrop"
	drop.scale = Vector2(1.0, 1.0)
	MobileUIManager.apply_game_object_scaling(drop)
	assert(abs(drop.scale.x - 1.3) < 0.001, "Drop X scale should be 1.3")
	drop.free()
	
	# Test with "collectible" keyword
	var collectible = Node2D.new()
	collectible.name = "Collectible_Item"
	collectible.scale = Vector2(1.0, 1.0)
	MobileUIManager.apply_game_object_scaling(collectible)
	assert(abs(collectible.scale.x - 1.3) < 0.001, "Collectible X scale should be 1.3")
	collectible.free()
	
	# Test with group
	var grouped = Node2D.new()
	grouped.name = "Item"
	grouped.add_to_group("collectibles")
	grouped.scale = Vector2(1.0, 1.0)
	MobileUIManager.apply_game_object_scaling(grouped)
	assert(abs(grouped.scale.x - 1.3) < 0.001, "Grouped collectible X scale should be 1.3")
	grouped.free()
	
	print("  → Collectibles scale to 1.3x ✓\n")

func validate_draggable_minimum_size() -> void:
	print("✓ Validating draggable minimum size (120x120)...")
	
	# Create draggable with small collision shape
	var node = Node2D.new()
	node.name = "DraggableObject"
	node.input_pickable = true
	node.scale = Vector2(1.0, 1.0)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(50, 50)  # Too small
	collision.shape = shape
	node.add_child(collision)
	
	MobileUIManager.apply_game_object_scaling(node)
	
	var effective_size = shape.size * node.scale
	assert(effective_size.x >= 120.0, "Draggable width should be >= 120px")
	assert(effective_size.y >= 120.0, "Draggable height should be >= 120px")
	
	node.free()
	print("  → Draggable objects meet 120x120 minimum ✓\n")

func validate_collision_preservation() -> void:
	print("✓ Validating collision shape preservation...")
	
	var node = Node2D.new()
	node.name = "GameObject"
	node.scale = Vector2(1.0, 1.0)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	node.add_child(collision)
	
	var original_radius = shape.radius
	
	MobileUIManager.apply_game_object_scaling(node)
	
	# Shape properties unchanged (Godot scales with parent)
	assert(shape.radius == original_radius, "Shape radius should be unchanged")
	
	# But effective collision is scaled
	var effective_radius = shape.radius * node.scale.x
	assert(effective_radius > original_radius, "Effective collision should be scaled")
	
	node.free()
	print("  → Collision shapes preserved and scaled correctly ✓\n")

func validate_aspect_ratio_preservation() -> void:
	print("✓ Validating aspect ratio preservation...")
	
	# Test with non-uniform initial scale
	var node = Node2D.new()
	node.name = "StretchedObject"
	node.scale = Vector2(2.0, 1.0)  # 2:1 aspect ratio
	
	var original_ratio = node.scale.x / node.scale.y
	
	MobileUIManager.apply_game_object_scaling(node)
	
	var new_ratio = node.scale.x / node.scale.y
	assert(abs(new_ratio - original_ratio) < 0.001, "Aspect ratio should be preserved")
	
	node.free()
	print("  → Aspect ratios preserved during scaling ✓\n")
