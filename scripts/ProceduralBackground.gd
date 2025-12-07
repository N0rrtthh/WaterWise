extends Node2D

## ═══════════════════════════════════════════════════════════════════
## PROCEDURAL BACKGROUND - WATERWISE THEMED
## ═══════════════════════════════════════════════════════════════════
## A water conservation themed procedural background with:
## - Water drops falling
## - Gardens with water buckets
## - Rivers and streams
## - Clouds and sky
## ═══════════════════════════════════════════════════════════════════

# Configuration for generation
var num_clouds: int = 6
var num_drops: int = 20
var num_plants: int = 15
var num_buckets: int = 5
var river_segments: int = 8

# Store generated positions and properties
var clouds: Array = []
var drops: Array = []
var plants: Array = []
var buckets: Array = []
var river_points: PackedVector2Array = PackedVector2Array()

# Animation state
var _time: float = 0.0

func _ready() -> void:
	z_index = -1  # Behind UI
	generate_world()

func _process(delta: float) -> void:
	_time += delta
	# Animate drops falling
	for i in range(drops.size()):
		drops[i].pos.y += 50 * delta
		var screen_height: float = get_viewport_rect().size.y
		if drops[i].pos.y > screen_height + 20:
			drops[i].pos.y = -20.0
			drops[i].pos.x = randf() * get_viewport_rect().size.x
	queue_redraw()

func generate_world() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	
	# Generate Clouds
	for i in range(num_clouds):
		var pos := Vector2(randf() * screen_size.x, randf_range(20.0, screen_size.y * 0.25))
		var size := randf_range(60.0, 120.0)
		clouds.append({"pos": pos, "size": size})
	
	# Generate falling water drops
	for i in range(num_drops):
		var pos := Vector2(randf() * screen_size.x, randf() * screen_size.y)
		var size := randf_range(3.0, 8.0)
		drops.append({"pos": pos, "size": size})
	
	# Generate river at bottom
	var river_y: float = screen_size.y * 0.85
	river_points.append(Vector2(-10.0, river_y))
	for i in range(river_segments):
		var x: float = (float(i + 1) / float(river_segments + 1)) * (screen_size.x + 20.0)
		var y: float = river_y + sin(float(i) * 0.8) * 15.0
		river_points.append(Vector2(x, y))
	river_points.append(Vector2(screen_size.x + 10, river_y))
	river_points.append(Vector2(screen_size.x + 10, screen_size.y + 10))
	river_points.append(Vector2(-10.0, screen_size.y + 10))
	
	# Generate plants (above river)
	for i in range(num_plants):
		var pos := Vector2(randf() * screen_size.x, randf_range(screen_size.y * 0.6, screen_size.y * 0.82))
		var height := randf_range(20.0, 50.0)
		var is_healthy := randf() > 0.3  # 70% healthy
		plants.append({"pos": pos, "height": height, "healthy": is_healthy})
	
	# Generate water buckets
	for i in range(num_buckets):
		var pos := Vector2(randf() * screen_size.x, randf_range(screen_size.y * 0.65, screen_size.y * 0.80))
		var fill := randf_range(0.3, 1.0)  # Water level
		buckets.append({"pos": pos, "fill": fill})
	
	queue_redraw()

func _draw() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	
	# 1. Draw Sky gradient
	var sky_color_top := Color(0.6, 0.85, 1.0)  # Light blue
	var sky_color_bottom := Color(0.85, 0.95, 1.0)  # Very light blue
	for y in range(int(screen_size.y * 0.6)):
		var t: float = float(y) / (screen_size.y * 0.6)
		var color: Color = sky_color_top.lerp(sky_color_bottom, t)
		draw_line(Vector2(0, y), Vector2(screen_size.x, y), color)
	
	# 2. Draw Ground
	var ground_color := Color(0.45, 0.75, 0.4)  # Green
	draw_rect(Rect2(0, screen_size.y * 0.6, screen_size.x, screen_size.y * 0.4), ground_color)
	
	# 3. Draw Clouds
	for cloud in clouds:
		_draw_cloud(cloud.pos, cloud.size)
	
	# 4. Draw Plants
	for plant in plants:
		_draw_plant(plant.pos, plant.height, plant.healthy)
	
	# 5. Draw Buckets
	for bucket in buckets:
		_draw_bucket(bucket.pos, bucket.fill)
	
	# 6. Draw River
	var river_color := Color(0.3, 0.6, 0.9, 0.8)
	if river_points.size() > 2:
		draw_colored_polygon(river_points, river_color)
		# River shine/waves
		for i in range(river_points.size() - 4):
			var wave_y: float = river_points[i + 1].y + sin(_time * 2.0 + float(i)) * 3.0
			draw_line(
				Vector2(river_points[i + 1].x, wave_y),
				Vector2(river_points[i + 2].x, river_points[i + 2].y + sin(_time * 2.0 + float(i + 1)) * 3.0),
				Color(1.0, 1.0, 1.0, 0.3),
				2.0
			)
	
	# 7. Draw falling water drops
	for drop in drops:
		_draw_drop(drop.pos, drop.size)

func _draw_cloud(pos: Vector2, size: float) -> void:
	"""Draw a fluffy cloud"""
	var cloud_color := Color(1.0, 1.0, 1.0, 0.9)
	# Main blob
	draw_circle(pos, size * 0.4, cloud_color)
	# Side blobs
	draw_circle(pos + Vector2(-size * 0.3, 0), size * 0.3, cloud_color)
	draw_circle(pos + Vector2(size * 0.3, 0), size * 0.3, cloud_color)
	draw_circle(pos + Vector2(-size * 0.15, -size * 0.15), size * 0.25, cloud_color)
	draw_circle(pos + Vector2(size * 0.15, -size * 0.15), size * 0.25, cloud_color)

func _draw_plant(pos: Vector2, height: float, is_healthy: bool) -> void:
	"""Draw a plant/flower"""
	var stem_color := Color(0.3, 0.6, 0.3) if is_healthy else Color(0.5, 0.5, 0.3)
	var flower_color := Color(0.9, 0.3, 0.5) if is_healthy else Color(0.6, 0.5, 0.4)
	
	# Stem
	draw_line(pos, pos - Vector2(0, height), stem_color, 3.0)
	
	# Leaves
	var leaf_y := pos.y - height * 0.5
	draw_line(Vector2(pos.x, leaf_y), Vector2(pos.x - 10, leaf_y - 5), stem_color, 2.0)
	draw_line(Vector2(pos.x, leaf_y), Vector2(pos.x + 10, leaf_y - 5), stem_color, 2.0)
	
	# Flower head
	var flower_pos := pos - Vector2(0, height)
	if is_healthy:
		# Healthy flower with petals
		for angle in range(0, 360, 60):
			var petal_offset := Vector2(8, 0).rotated(deg_to_rad(float(angle)))
			draw_circle(flower_pos + petal_offset, 6.0, flower_color)
		draw_circle(flower_pos, 5.0, Color(1.0, 0.9, 0.2))  # Yellow center
	else:
		# Wilted flower
		draw_circle(flower_pos, 5.0, flower_color)

func _draw_bucket(pos: Vector2, fill_level: float) -> void:
	"""Draw a water bucket with water inside"""
	var bucket_width := 30.0
	var bucket_height := 25.0
	
	# Bucket body (trapezoid shape)
	var bucket_points := PackedVector2Array([
		pos + Vector2(-bucket_width * 0.4, 0),
		pos + Vector2(-bucket_width * 0.5, -bucket_height),
		pos + Vector2(bucket_width * 0.5, -bucket_height),
		pos + Vector2(bucket_width * 0.4, 0)
	])
	draw_colored_polygon(bucket_points, Color(0.4, 0.4, 0.5))  # Gray bucket
	
	# Water inside
	var water_height := bucket_height * fill_level
	var water_points := PackedVector2Array([
		pos + Vector2(-bucket_width * 0.35, 0),
		pos + Vector2(-bucket_width * 0.4, -water_height),
		pos + Vector2(bucket_width * 0.4, -water_height),
		pos + Vector2(bucket_width * 0.35, 0)
	])
	draw_colored_polygon(water_points, Color(0.3, 0.6, 0.9, 0.8))  # Blue water
	
	# Handle
	draw_arc(pos + Vector2(0, -bucket_height - 8), 12.0, PI * 0.2, PI * 0.8, 12, Color(0.3, 0.3, 0.4), 3.0)

func _draw_drop(pos: Vector2, size: float) -> void:
	"""Draw a water droplet"""
	var drop_color := Color(0.4, 0.7, 1.0, 0.7)
	
	# Teardrop shape using circle and triangle
	draw_circle(pos, size, drop_color)
	
	# Top point of teardrop
	var triangle := PackedVector2Array([
		pos + Vector2(-size * 0.7, -size * 0.5),
		pos + Vector2(0, -size * 2.0),
		pos + Vector2(size * 0.7, -size * 0.5)
	])
	draw_colored_polygon(triangle, drop_color)
	
	# Shine highlight
	draw_circle(pos + Vector2(-size * 0.3, -size * 0.3), size * 0.3, Color(1.0, 1.0, 1.0, 0.5))
