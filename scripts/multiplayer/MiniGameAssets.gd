class_name MiniGameAssets
extends RefCounted

## ═══════════════════════════════════════════════════════════════════
## MINIGAME ASSET GENERATOR
## ═══════════════════════════════════════════════════════════════════
## Generates procedural textures for minigame elements
## ═══════════════════════════════════════════════════════════════════

static func create_bucket_texture(width: int, height: int, color: Color) -> Texture2D:
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	# Draw bucket shape (trapezoid)
	for y in range(height):
		var width_at_y = lerp(float(width) * 0.7, float(width), float(y) / height)
		var start_x = (width - width_at_y) / 2
		for x in range(start_x, start_x + width_at_y):
			img.set_pixel(x, y, color)
			
			# Add border/shading
			if x == int(start_x) or x == int(start_x + width_at_y) - 1 or y == height - 1:
				img.set_pixel(x, y, color.darkened(0.4))
			elif y < 5: # Rim
				img.set_pixel(x, y, color.lightened(0.2))
				
	return ImageTexture.create_from_image(img)

static func create_drop_texture(radius: int, color: Color) -> Texture2D:
	var size = radius * 2
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var center = Vector2(radius, radius)
	
	for x in range(size):
		for y in range(size):
			var d = Vector2(x, y).distance_to(center)
			if d <= radius:
				# Teardrop shape distortion
				var y_factor = 1.0 - (float(y) / size)
				if d <= radius * (0.8 + y_factor * 0.2):
					img.set_pixel(x, y, color)
					# Highlight
					if x > radius - 5 and x < radius and y > radius - 5 and y < radius:
						img.set_pixel(x, y, Color.WHITE)
	
	return ImageTexture.create_from_image(img)

static func create_dirt_texture(radius: int) -> Texture2D:
	var size = radius * 2
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var center = Vector2(radius, radius)
	var color = Color(0.4, 0.3, 0.2) # Brown
	
	for x in range(size):
		for y in range(size):
			if Vector2(x, y).distance_to(center) <= radius:
				# Noise/messy look
				if randf() > 0.2:
					img.set_pixel(x, y, color.darkened(randf() * 0.3))
	
	return ImageTexture.create_from_image(img)

static func create_toilet_texture(width: int, height: int) -> Texture2D:
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var white = Color(0.95, 0.95, 0.95)
	
	# Draw simple toilet shape
	# Tank
	for x in range(width/4, width*3/4):
		for y in range(0, height/3):
			img.set_pixel(x, y, white)
	
	# Bowl
	for x in range(width/4, width*3/4):
		for y in range(height/3, height):
			# Rounded bottom
			if y < height * 0.8 or abs(x - width/2) < (width/4) * (1.0 - (float(y - height*0.8)/(height*0.2))):
				img.set_pixel(x, y, white)
				
	return ImageTexture.create_from_image(img)

static func create_plant_texture(size: int, flower_color: Color) -> Texture2D:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var center = Vector2(size/2, size/2)
	var green = Color(0.2, 0.8, 0.2)
	
	# Stem
	for y in range(size/2, size):
		for x in range(size/2 - 2, size/2 + 2):
			img.set_pixel(x, y, green)
			
	# Leaves
	for x in range(size):
		for y in range(size/2, size):
			if abs(x - size/2) < 20 and abs(y - size*0.7) < 10:
				img.set_pixel(x, y, green)

	# Flower
	for x in range(size):
		for y in range(size):
			if Vector2(x, y).distance_to(center) < size/4:
				img.set_pixel(x, y, flower_color)
			elif Vector2(x, y).distance_to(center) < size/6:
				img.set_pixel(x, y, Color(0.3, 0.2, 0.1)) # Center
				
	return ImageTexture.create_from_image(img)

static func create_car_texture(width: int, height: int, color: Color) -> Texture2D:
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	# Simple rounded rect
	for x in range(width):
		for y in range(height):
			img.set_pixel(x, y, color)
			
	return ImageTexture.create_from_image(img)
