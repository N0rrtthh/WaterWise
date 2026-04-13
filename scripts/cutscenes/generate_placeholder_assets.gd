@tool
extends EditorScript

## Utility script to generate placeholder character assets
## Run this from the Godot editor: File > Run

func _run() -> void:
	print("Generating placeholder water droplet character assets...")
	
	# Create base droplet texture
	_create_base_droplet()
	
	# Create expression textures
	_create_expression_textures()
	
	print("Placeholder assets generated successfully!")
	print("Assets created in res://assets/characters/")


func _create_base_droplet() -> void:
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
	
	# Save the image
	var path = "res://assets/characters/droplet_base.png"
	image.save_png(path)
	print("Created: " + path)


func _create_expression_textures() -> void:
	var expressions = [
		"happy",
		"sad",
		"surprised",
		"determined",
		"worried",
		"excited"
	]
	
	# Create expressions directory
	DirAccess.make_dir_recursive_absolute("res://assets/characters/expressions")
	
	for expr in expressions:
		_create_expression_texture(expr)


func _create_expression_texture(expression_name: String) -> void:
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
			# Add sparkle to eyes
			_draw_circle(image, Vector2(center.x - eye_spacing + 8, eye_y - 8), 5, Color.WHITE)
			_draw_circle(image, Vector2(center.x + eye_spacing + 8, eye_y - 8), 5, Color.WHITE)
	
	# Save the image
	var path = "res://assets/characters/expressions/" + expression_name + ".png"
	image.save_png(path)
	print("Created: " + path)


func _draw_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var size = image.get_size()
	for y in range(max(0, int(center.y - radius)), min(size.y, int(center.y + radius + 1))):
		for x in range(max(0, int(center.x - radius)), min(size.x, int(center.x + radius + 1))):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				image.set_pixel(x, y, color)


func _draw_smile(image: Image, center: Vector2, width: float, upward: bool) -> void:
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


func _draw_line(image: Image, from: Vector2, to: Vector2, color: Color) -> void:
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


func _draw_wavy_mouth(image: Image, center: Vector2) -> void:
	for x in range(int(center.x - 40), int(center.x + 40)):
		var t = float(x - (center.x - 40)) / 80.0
		var wave = sin(t * PI * 3) * 10
		var y = int(center.y + wave)
		if y >= 0 and y < image.get_height() and x >= 0 and x < image.get_width():
			for dy in range(-2, 3):
				if y + dy >= 0 and y + dy < image.get_height():
					image.set_pixel(x, y + dy, Color.BLACK)
