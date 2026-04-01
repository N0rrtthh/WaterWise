extends Node

## Runtime utility to create placeholder character assets if they don't exist
## This ensures the animated cutscene system works even without pre-generated assets

static func ensure_assets_exist() -> bool:
	"""Create placeholder assets if they don't exist. Returns true if assets are available."""
	
	# Check if base droplet exists
	if not ResourceLoader.exists("res://assets/characters/droplet_base.png"):
		if not _create_base_droplet():
			return false
	
	# Check if expression textures exist
	var expressions = ["happy", "sad", "surprised", "determined", "worried", "excited"]
	for expr in expressions:
		var path = "res://assets/characters/expressions/" + expr + ".png"
		if not ResourceLoader.exists(path):
			if not _create_expression_texture(expr):
				return false
	
	return true


static func _create_base_droplet() -> bool:
	"""Create a simple blue water droplet texture"""
	var size = 512
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	# Draw a blue water droplet shape
	var center = Vector2(size / 2, size / 2)
	var radius = size / 2 - 20
	
	for y in range(size):
		for x in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			# Create circular droplet shape
			if dist < radius:
				# Blue color with alpha based on distance from center
				var alpha = 1.0 - (dist / radius) * 0.3
				var color = Color(0.3, 0.65, 1.0, alpha)
				image.set_pixel(x, y, color)
			else:
				# Transparent outside
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	
	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute("res://assets/characters")
	
	# Save the image
	var path = "res://assets/characters/droplet_base.png"
	var err = image.save_png(path)
	if err != OK:
		push_error("Failed to save base droplet texture: " + str(err))
		return false
	
	print("[PlaceholderAssets] Created: " + path)
	return true


static func _create_expression_texture(expression_name: String) -> bool:
	"""Create a simple expression overlay texture"""
	var size = 512
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	# Fill with transparent
	image.fill(Color(0, 0, 0, 0))
	
	# Draw simple face based on expression
	var center = Vector2(size / 2, size / 2)
	var eye_y = center.y - 80
	var eye_spacing = 80
	var mouth_y = center.y + 60
	
	# Draw eyes
	_draw_circle(image, Vector2(center.x - eye_spacing, eye_y), 20, Color.BLACK)
	_draw_circle(image, Vector2(center.x + eye_spacing, eye_y), 20, Color.BLACK)
	
	# Draw mouth based on expression
	match expression_name:
		"happy":
			_draw_smile(image, Vector2(center.x, mouth_y), 60, true)
		"sad":
			_draw_smile(image, Vector2(center.x, mouth_y + 20), 60, false)
		"surprised":
			_draw_circle(image, Vector2(center.x, mouth_y), 30, Color.BLACK)
		"determined":
			_draw_line(image, Vector2(center.x - 40, mouth_y), Vector2(center.x + 40, mouth_y), Color.BLACK)
		"worried":
			_draw_wavy_mouth(image, Vector2(center.x, mouth_y))
		"excited":
			_draw_smile(image, Vector2(center.x, mouth_y), 70, true)
	
	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute("res://assets/characters/expressions")
	
	# Save the image
	var path = "res://assets/characters/expressions/" + expression_name + ".png"
	var err = image.save_png(path)
	if err != OK:
		push_error("Failed to save expression texture: " + str(err))
		return false
	
	print("[PlaceholderAssets] Created: " + path)
	return true


static func _draw_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var size = image.get_size()
	for y in range(max(0, int(center.y - radius)), min(size.y, int(center.y + radius + 1))):
		for x in range(max(0, int(center.x - radius)), min(size.x, int(center.x + radius + 1))):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				image.set_pixel(x, y, color)


static func _draw_smile(image: Image, center: Vector2, width: float, upward: bool) -> void:
	var direction = 1 if upward else -1
	for x in range(int(center.x - width), int(center.x + width)):
		var t = float(x - (center.x - width)) / (width * 2)
		var curve = sin(t * PI) * 30 * direction
		var y = int(center.y + curve)
		if y >= 0 and y < image.get_height() and x >= 0 and x < image.get_width():
			# Draw thick line
			for dy in range(-2, 3):
				if y + dy >= 0 and y + dy < image.get_height():
					image.set_pixel(x, y + dy, Color.BLACK)


static func _draw_line(image: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var diff = to - from
	var steps = int(diff.length())
	for i in range(steps):
		var t = float(i) / steps
		var pos = from + diff * t
		var x = int(pos.x)
		var y = int(pos.y)
		if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
			# Draw thick line
			for dy in range(-2, 3):
				if y + dy >= 0 and y + dy < image.get_height():
					image.set_pixel(x, y + dy, color)


static func _draw_wavy_mouth(image: Image, center: Vector2) -> void:
	for x in range(int(center.x - 40), int(center.x + 40)):
		var t = float(x - (center.x - 40)) / 80.0
		var wave = sin(t * PI * 3) * 10
		var y = int(center.y + wave)
		if y >= 0 and y < image.get_height() and x >= 0 and x < image.get_width():
			for dy in range(-2, 3):
				if y + dy >= 0 and y + dy < image.get_height():
					image.set_pixel(x, y + dy, Color.BLACK)
