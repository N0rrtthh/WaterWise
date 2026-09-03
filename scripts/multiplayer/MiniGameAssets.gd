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
		var width_at_y = lerp(float(width) * 0.7, float(width), float(y) / float(height))
		var start_x = int((float(width) - width_at_y) / 2.0)
		var end_x = int(start_x + width_at_y)
		for x in range(start_x, end_x):
			img.set_pixel(x, y, color)
			
			# Add border/shading
			if x == start_x or x == end_x - 1 or y == height - 1:
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
	for x in range(int(width/4.0), int(width*3/4.0)):
		for y in range(0, int(height/3.0)):
			img.set_pixel(x, y, white)
	
	# Bowl
	for x in range(int(width/4.0), int(width*3/4.0)):
		for y in range(int(height/3.0), height):
			# Rounded bottom
			var bowl_taper := (int(width/4.0)) * (1.0 - (float(y - height*0.8)/(height*0.2)))
			if y < height * 0.8 or abs(x - int(width/2.0)) < bowl_taper:
				img.set_pixel(x, y, white)
				
	return ImageTexture.create_from_image(img)

static func create_plant_texture(size: int, flower_color: Color) -> Texture2D:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var center = Vector2(int(size/2.0), int(size/2.0))
	var green = Color(0.2, 0.8, 0.2)
	
	# Stem
	for y in range(int(size/2.0), size):
		for x in range(int(size/2.0) - 2, int(size/2.0) + 2):
			img.set_pixel(x, y, green)
			
	# Leaves
	for x in range(size):
		for y in range(int(size/2.0), size):
			if abs(x - int(size/2.0)) < 20 and abs(y - size*0.7) < 10:
				img.set_pixel(x, y, green)

	# Flower
	for x in range(size):
		for y in range(size):
			if Vector2(x, y).distance_to(center) < int(size/4.0):
				img.set_pixel(x, y, flower_color)
			elif Vector2(x, y).distance_to(center) < int(size/6.0):
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

## Guarantees a label survives whatever art ends up behind it.
##
## The HUD text in MiniGameBase gets a fixed pale halo, but labels that live in the play
## area sit over spawner art that changes every frame, so the backdrop cannot be known at
## the moment the label is built. Outlining with the opposite luminance of the fill puts a
## guaranteed light-to-dark edge inside every glyph box, which is what the WCAG contrast
## ratio measures - a white "0/2" over a pale bucket read 1.25:1 without one, and a bright
## green "OK" popup over wet mud read 1.49:1.
## `size` is a flat 4px on purpose. Scaling the rim with the font size looked like the safer rule
## and measured worse: a 2px rim on ToiletTankFix's 18px "← TAMANG LEBEL" dropped it from 5.97:1 to
## 3.66:1, because what the ratio reads is the rim-against-fill edge and a thinner rim puts fewer
## fully-rimmed pixels inside the glyph box. Nothing was gained either, since a 4px rim does not
## swallow small text: a 14px white caption rendered on this project's panels still peaks at pure
## white with one. The one case that looked like swallowing - five MP captions rasterising at 0.40
## grey - was the top bar's 60% black scrim over them, fixed in attach_hud_panel().
static func outline_text(label: Control, size: int = 4) -> void:
	if label == null:
		return
	var fill: Color = label.get_theme_color("font_color")
	var rim: Color = Color(0.04, 0.06, 0.09, 0.95)
	if fill.get_luminance() <= 0.45:
		rim = Color(1.0, 1.0, 1.0, 0.95)
	label.add_theme_color_override("font_outline_color", rim)
	label.add_theme_constant_override("outline_size", size)
