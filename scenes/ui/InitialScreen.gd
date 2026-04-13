extends Control

@onready var droplet_label = $UI/TopLeft/CoinBG/HBox/DropletCount
@onready var droplet_icon = $UI/TopLeft/CoinBG/HBox/DropletIcon
@onready var play_button = $UI/ButtonContainer/PlayButton
@onready var multiplayer_button = $UI/ButtonContainer/MultiplayerButton
@onready var welcome_popup = $WelcomePopup
@onready var welcome_panel = $WelcomePopup/Panel
@onready var highscore_label = $UI/HighscorePanel/HighscoreLabel
@onready var next_unlock_panel = $UI/BottomLeft

# Waterpark scene elements
var waterpark_container: Node2D
var walking_characters: Array = []

func _create_waterpark_background():
	var screen_size = get_viewport_rect().size
	
	# Create waterpark container
	waterpark_container = Node2D.new()
	waterpark_container.name = "WaterparkScene"
	waterpark_container.z_index = -5
	add_child(waterpark_container)
	move_child(waterpark_container, 0)
	
	# Draw layered background elements
	_draw_distant_hills(screen_size)
	_draw_main_pool(screen_size)
	_draw_water_slides(screen_size)
	_draw_palm_trees(screen_size)
	_draw_umbrellas(screen_size)
	_draw_lifeguard_chair(screen_size)
	_draw_pool_floats(screen_size)
	_draw_bushes(screen_size)
	_spawn_walking_characters(screen_size)

func _draw_distant_hills(screen_size: Vector2):
	# Green rolling hills in background
	var hills = Node2D.new()
	hills.name = "Hills"
	hills.z_index = -10
	waterpark_container.add_child(hills)
	
	# Multiple overlapping hill shapes
	var hill_colors = [
		Color(0.45, 0.7, 0.45),  # Darker back
		Color(0.5, 0.75, 0.5),   # Mid
		Color(0.55, 0.8, 0.55)   # Front lighter
	]
	
	for i in range(3):
		var hill = Polygon2D.new()
		var y_base = screen_size.y * 0.55 + i * 20
		var points: Array[Vector2] = []
		
		# Create wavy hill shape
		points.append(Vector2(-50, y_base))
		for x in range(0, int(screen_size.x) + 100, 80):
			var y_offset = sin(x * 0.008 + i * 1.5) * 40 + sin(x * 0.015) * 20
			points.append(Vector2(x, y_base - 60 + y_offset - i * 30))
		points.append(Vector2(screen_size.x + 50, y_base))
		points.append(Vector2(screen_size.x + 50, screen_size.y))
		points.append(Vector2(-50, screen_size.y))
		
		hill.polygon = PackedVector2Array(points)
		hill.color = hill_colors[i]
		hills.add_child(hill)

func _draw_main_pool(screen_size: Vector2):
	# Large central pool like in reference
	var pool = Node2D.new()
	pool.name = "MainPool"
	pool.position = Vector2(screen_size.x * 0.5, screen_size.y * 0.72)
	waterpark_container.add_child(pool)
	
	# Pool edge/border (cream colored)
	var pool_border = Polygon2D.new()
	var border_points = _create_oval_points(420, 140, 32)
	pool_border.polygon = PackedVector2Array(border_points)
	pool_border.color = Color(0.95, 0.92, 0.85)
	pool.add_child(pool_border)
	
	# Pool water (blue)
	var pool_water = Polygon2D.new()
	var water_points = _create_oval_points(400, 125, 32)
	pool_water.polygon = PackedVector2Array(water_points)
	pool_water.color = Color(0.55, 0.82, 0.9)
	pool.add_child(pool_water)
	
	# Water ripples/waves effect
	var ripple = Polygon2D.new()
	var ripple_points = _create_oval_points(350, 100, 24)
	ripple.polygon = PackedVector2Array(ripple_points)
	ripple.color = Color(0.6, 0.85, 0.92, 0.5)
	pool.add_child(ripple)
	
	# Animate ripple
	var rtween = create_tween().set_loops()
	rtween.tween_property(ripple, "scale", Vector2(1.05, 1.05), 1.5)
	rtween.tween_property(ripple, "scale", Vector2(0.95, 0.95), 1.5)

func _create_oval_points(width: float, height: float, segments: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle) * width, sin(angle) * height))
	return points

func _draw_water_slides(screen_size: Vector2):
	var slides = Node2D.new()
	slides.name = "WaterSlides"
	waterpark_container.add_child(slides)
	
	# Left spiral slide (yellow/orange)
	_create_spiral_slide(slides, Vector2(120, screen_size.y * 0.35), 
		Color(0.95, 0.75, 0.2), Color(0.9, 0.6, 0.15), true)
	
	# Left curved slide (cyan)
	_create_curved_slide(slides, Vector2(220, screen_size.y * 0.3),
		Color(0.4, 0.8, 0.85), 1)
	
	# Right slides (blue and yellow)
	_create_straight_slide(slides, Vector2(screen_size.x - 180, screen_size.y * 0.35),
		Color(0.3, 0.5, 0.85), -1)
	_create_straight_slide(slides, Vector2(screen_size.x - 120, screen_size.y * 0.38),
		Color(0.95, 0.8, 0.3), -1)

func _create_spiral_slide(parent: Node2D, pos: Vector2, color1: Color, _color2: Color, _left: bool):
	var slide = Node2D.new()
	slide.position = pos
	parent.add_child(slide)
	
	# Tower/support structure
	var tower = Polygon2D.new()
	tower.polygon = PackedVector2Array([
		Vector2(-25, -120), Vector2(25, -120),
		Vector2(30, 180), Vector2(-30, 180)
	])
	tower.color = Color(0.6, 0.6, 0.65)
	slide.add_child(tower)
	
	# Spiral tube segments
	var tube = Line2D.new()
	tube.width = 28
	tube.default_color = color1
	var spiral_points: Array[Vector2] = []
	for i in range(12):
		var t = i / 11.0
		var x = sin(t * 4) * 50 + t * 80
		var y = -100 + t * 280
		spiral_points.append(Vector2(x, y))
	tube.points = PackedVector2Array(spiral_points)
	tube.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tube.end_cap_mode = Line2D.LINE_CAP_ROUND
	slide.add_child(tube)

func _create_curved_slide(parent: Node2D, pos: Vector2, color: Color, dir: int):
	var slide = Node2D.new()
	slide.position = pos
	parent.add_child(slide)
	
	var tube = Line2D.new()
	tube.width = 22
	tube.default_color = color
	tube.points = PackedVector2Array([
		Vector2(0, -80),
		Vector2(40 * dir, 0),
		Vector2(100 * dir, 100),
		Vector2(180 * dir, 220),
		Vector2(220 * dir, 320)
	])
	tube.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tube.end_cap_mode = Line2D.LINE_CAP_ROUND
	slide.add_child(tube)

func _create_straight_slide(parent: Node2D, pos: Vector2, color: Color, dir: int):
	var slide = Node2D.new()
	slide.position = pos
	parent.add_child(slide)
	
	# Support tower
	var tower = Polygon2D.new()
	tower.polygon = PackedVector2Array([
		Vector2(-15, -100), Vector2(15, -100),
		Vector2(20, 150), Vector2(-20, 150)
	])
	tower.color = Color(0.55, 0.55, 0.6)
	slide.add_child(tower)
	
	var tube = Line2D.new()
	tube.width = 24
	tube.default_color = color
	tube.points = PackedVector2Array([
		Vector2(10 * dir, -90),
		Vector2(60 * dir, 50),
		Vector2(120 * dir, 200),
		Vector2(160 * dir, 320)
	])
	tube.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tube.end_cap_mode = Line2D.LINE_CAP_ROUND
	slide.add_child(tube)

func _draw_palm_trees(screen_size: Vector2):
	var trees = Node2D.new()
	trees.name = "PalmTrees"
	waterpark_container.add_child(trees)
	
	# Palm tree positions
	var positions = [
		Vector2(50, screen_size.y * 0.55),
		Vector2(screen_size.x - 60, screen_size.y * 0.5),
		Vector2(screen_size.x * 0.35, screen_size.y * 0.45),
		Vector2(screen_size.x * 0.7, screen_size.y * 0.48)
	]
	
	for pos in positions:
		_create_palm_tree(trees, pos, randf_range(0.7, 1.0))

func _create_palm_tree(parent: Node2D, pos: Vector2, scale_factor: float):
	var tree = Node2D.new()
	tree.position = pos
	tree.scale = Vector2(scale_factor, scale_factor)
	parent.add_child(tree)
	
	# Trunk
	var trunk = Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(-8, 0), Vector2(8, 0),
		Vector2(12, -120), Vector2(5, -180),
		Vector2(-5, -180), Vector2(-12, -120)
	])
	trunk.color = Color(0.55, 0.4, 0.25)
	tree.add_child(trunk)
	
	# Palm fronds
	var frond_count = 6
	for i in range(frond_count):
		var frond = Polygon2D.new()
		var angle = -PI/2 + (i - frond_count/2.0) * 0.5
		var length = randf_range(80, 100)
		
		var tip = Vector2(cos(angle) * length, sin(angle) * length - 180)
		frond.polygon = PackedVector2Array([
			Vector2(0, -175),
			Vector2(tip.x * 0.3, tip.y * 0.5 - 10),
			tip,
			Vector2(tip.x * 0.3, tip.y * 0.5 + 10)
		])
		frond.color = Color(0.3, 0.65, 0.35)
		tree.add_child(frond)

func _draw_umbrellas(screen_size: Vector2):
	var umbrellas = Node2D.new()
	umbrellas.name = "Umbrellas"
	waterpark_container.add_child(umbrellas)
	
	# Umbrella positions and colors
	var umbrella_data = [
		{"pos": Vector2(screen_size.x * 0.42, screen_size.y * 0.52), 
		 "colors": [Color(0.3, 0.5, 0.8), Color(0.95, 0.95, 0.95)]},
		{"pos": Vector2(screen_size.x * 0.58, screen_size.y * 0.5), 
		 "colors": [Color(0.9, 0.35, 0.35), Color(0.95, 0.95, 0.95)]},
		{"pos": Vector2(screen_size.x - 100, screen_size.y * 0.65), 
		 "colors": [Color(0.9, 0.35, 0.35), Color(0.95, 0.95, 0.95)]}
	]
	
	for data in umbrella_data:
		_create_umbrella(umbrellas, data.pos, data.colors)

func _create_umbrella(parent: Node2D, pos: Vector2, stripe_colors: Array):
	var umbrella = Node2D.new()
	umbrella.position = pos
	parent.add_child(umbrella)
	
	# Pole
	var pole = Polygon2D.new()
	pole.polygon = PackedVector2Array([
		Vector2(-3, -60), Vector2(3, -60),
		Vector2(3, 20), Vector2(-3, 20)
	])
	pole.color = Color(0.6, 0.5, 0.4)
	umbrella.add_child(pole)
	
	# Umbrella top (striped)
	for i in range(8):
		var segment = Polygon2D.new()
		var angle1 = i * TAU / 8 - PI
		var angle2 = (i + 1) * TAU / 8 - PI
		segment.polygon = PackedVector2Array([
			Vector2(0, -65),
			Vector2(cos(angle1) * 45, sin(angle1) * 20 - 55),
			Vector2(cos(angle2) * 45, sin(angle2) * 20 - 55)
		])
		segment.color = stripe_colors[i % stripe_colors.size()]
		umbrella.add_child(segment)

func _draw_lifeguard_chair(screen_size: Vector2):
	var chair = Node2D.new()
	chair.name = "LifeguardChair"
	chair.position = Vector2(screen_size.x * 0.48, screen_size.y * 0.48)
	waterpark_container.add_child(chair)
	
	# Tall legs
	var leg1 = Polygon2D.new()
	leg1.polygon = PackedVector2Array([
		Vector2(-20, -80), Vector2(-15, -80),
		Vector2(-10, 60), Vector2(-25, 60)
	])
	leg1.color = Color(0.7, 0.55, 0.4)
	chair.add_child(leg1)
	
	var leg2 = Polygon2D.new()
	leg2.polygon = PackedVector2Array([
		Vector2(15, -80), Vector2(20, -80),
		Vector2(25, 60), Vector2(10, 60)
	])
	leg2.color = Color(0.7, 0.55, 0.4)
	chair.add_child(leg2)
	
	# Seat
	var seat = Polygon2D.new()
	seat.polygon = PackedVector2Array([
		Vector2(-25, -85), Vector2(25, -85),
		Vector2(25, -75), Vector2(-25, -75)
	])
	seat.color = Color(0.85, 0.3, 0.3)
	chair.add_child(seat)
	
	# Back rest
	var back = Polygon2D.new()
	back.polygon = PackedVector2Array([
		Vector2(-22, -120), Vector2(22, -120),
		Vector2(22, -85), Vector2(-22, -85)
	])
	back.color = Color(0.85, 0.3, 0.3)
	chair.add_child(back)

func _draw_pool_floats(screen_size: Vector2):
	var floats = Node2D.new()
	floats.name = "PoolFloats"
	floats.z_index = 1
	waterpark_container.add_child(floats)
	
	# Float rings around/in pool
	var float_data = [
		{"pos": Vector2(screen_size.x * 0.35, screen_size.y * 0.78), 
		 "color": Color(0.95, 0.8, 0.2)},
		{"pos": Vector2(screen_size.x * 0.55, screen_size.y * 0.75), 
		 "color": Color(0.8, 0.3, 0.8)},
		{"pos": Vector2(screen_size.x * 0.2, screen_size.y * 0.82), 
		 "color": Color(0.95, 0.8, 0.2)},
		{"pos": Vector2(screen_size.x * 0.65, screen_size.y * 0.8), 
		 "color": Color(0.8, 0.3, 0.8)}
	]
	
	for data in float_data:
		_create_pool_float(floats, data.pos, data.color)

func _create_pool_float(parent: Node2D, pos: Vector2, color: Color):
	var float_ring = Node2D.new()
	float_ring.position = pos
	parent.add_child(float_ring)
	
	# Outer ring
	var outer = Polygon2D.new()
	var outer_pts = _create_oval_points(25, 12, 16)
	outer.polygon = PackedVector2Array(outer_pts)
	outer.color = color
	float_ring.add_child(outer)
	
	# Inner hole
	var inner = Polygon2D.new()
	var inner_pts = _create_oval_points(12, 6, 12)
	inner.polygon = PackedVector2Array(inner_pts)
	inner.color = Color(0.55, 0.82, 0.9)  # Pool water color
	float_ring.add_child(inner)
	
	# Gentle bobbing animation
	var bob_tween = create_tween().set_loops()
	bob_tween.tween_property(float_ring, "position:y", pos.y - 3, 1.0 + randf() * 0.5)
	bob_tween.tween_property(float_ring, "position:y", pos.y + 3, 1.0 + randf() * 0.5)

func _draw_bushes(screen_size: Vector2):
	var bushes = Node2D.new()
	bushes.name = "Bushes"
	bushes.z_index = 2
	waterpark_container.add_child(bushes)
	
	# Bottom corner bushes
	_create_bush_cluster(bushes, Vector2(40, screen_size.y - 50), 1.2)
	_create_bush_cluster(bushes, Vector2(screen_size.x - 40, screen_size.y - 40), 1.0)
	_create_bush_cluster(bushes, Vector2(100, screen_size.y - 30), 0.8)

func _create_bush_cluster(parent: Node2D, pos: Vector2, scale_factor: float):
	var bush = Node2D.new()
	bush.position = pos
	bush.scale = Vector2(scale_factor, scale_factor)
	parent.add_child(bush)
	
	# Multiple overlapping circles for bush shape
	var bush_colors = [Color(0.25, 0.55, 0.3), Color(0.3, 0.6, 0.35), Color(0.2, 0.5, 0.25)]
	var offsets = [
		Vector2(0, 0),
		Vector2(-20, 10),
		Vector2(25, 5),
		Vector2(-10, -15),
		Vector2(15, -10)
	]
	
	for i in range(offsets.size()):
		var circle = Polygon2D.new()
		var pts = _create_oval_points(30 + randf() * 10, 25 + randf() * 8, 12)
		circle.polygon = PackedVector2Array(pts)
		circle.position = offsets[i]
		circle.color = bush_colors[i % bush_colors.size()]
		bush.add_child(circle)

func _spawn_walking_characters(screen_size: Vector2):
	# Create main featured character (larger, near center)
	var main_char = _create_main_droplet_character()
	main_char.position = Vector2(screen_size.x * 0.5, screen_size.y * 0.48)
	main_char.scale = Vector2(1.3, 1.3)  # Make it bigger!
	main_char.z_index = 8
	waterpark_container.add_child(main_char)
	_animate_main_character(main_char)
	
	# Spawn MORE cute droplet characters (6 total) with different looks
	var char_positions = [
		Vector2(screen_size.x * 0.15, screen_size.y * 0.58),
		Vector2(screen_size.x * 0.25, screen_size.y * 0.65),
		Vector2(screen_size.x * 0.75, screen_size.y * 0.58),
		Vector2(screen_size.x * 0.85, screen_size.y * 0.62),
		Vector2(screen_size.x * 0.4, screen_size.y * 0.68),
		Vector2(screen_size.x * 0.6, screen_size.y * 0.66),
	]
	
	for i in range(char_positions.size()):
		var char_node = _create_droplet_character(i)
		char_node.position = char_positions[i]
		char_node.z_index = 5 + (i % 3)
		waterpark_container.add_child(char_node)
		walking_characters.append(char_node)
		_animate_character_walk(char_node, screen_size)
	
	# Add some fun floating elements (bubbles, sparkles)
	_add_floating_decorations(screen_size)

func _add_floating_decorations(screen_size: Vector2):
	# Floating bubbles
	for i in range(8):
		var bubble = _create_bubble()
		bubble.position = Vector2(
			randf_range(50, screen_size.x - 50),
			randf_range(screen_size.y * 0.3, screen_size.y * 0.7)
		)
		bubble.z_index = 3
		waterpark_container.add_child(bubble)
		_animate_bubble(bubble, screen_size)
	
	# Sparkle effects near pool
	for i in range(5):
		var sparkle = Label.new()
		sparkle.text = "✨"
		sparkle.add_theme_font_size_override("font_size", randi_range(16, 28))
		sparkle.position = Vector2(
			screen_size.x * 0.5 + randf_range(-200, 200),
			screen_size.y * 0.7 + randf_range(-30, 30)
		)
		sparkle.z_index = 4
		sparkle.modulate.a = randf_range(0.5, 1.0)
		waterpark_container.add_child(sparkle)
		
		var tw = create_tween().set_loops()
		tw.tween_property(sparkle, "modulate:a", 0.2, randf_range(0.5, 1.0))
		tw.tween_property(sparkle, "modulate:a", 1.0, randf_range(0.5, 1.0))

func _create_bubble() -> Node2D:
	var bubble = Node2D.new()
	var bubble_size = randf_range(8, 20)
	
	var circle = Polygon2D.new()
	circle.polygon = PackedVector2Array(_create_oval_points(bubble_size, bubble_size, 12))
	circle.color = Color(0.7, 0.9, 1, 0.4)
	bubble.add_child(circle)
	
	# Shine
	var shine = Polygon2D.new()
	shine.polygon = PackedVector2Array(_create_oval_points(bubble_size * 0.3, bubble_size * 0.3, 6))
	shine.position = Vector2(-bubble_size * 0.3, -bubble_size * 0.3)
	shine.color = Color(1, 1, 1, 0.6)
	bubble.add_child(shine)
	
	return bubble

func _animate_bubble(bubble: Node2D, _screen_size: Vector2):
	var tw = create_tween().set_loops()
	var start_y = bubble.position.y
	var float_dist = randf_range(30, 60)
	var duration = randf_range(2.0, 4.0)
	
	tw.tween_property(bubble, "position:y", start_y - float_dist, duration)
	tw.tween_property(bubble, "position:y", start_y, duration)
	
	# Slight horizontal wobble
	var wobble = create_tween().set_loops()
	wobble.tween_property(bubble, "position:x", bubble.position.x + 10, duration * 0.7)
	wobble.tween_property(bubble, "position:x", bubble.position.x - 10, duration * 0.7)

func _create_main_droplet_character() -> Node2D:
	var character = Node2D.new()
	character.name = "MainDropletCharacter"
	
	# Larger droplet body (water drop shape)
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -60), Vector2(30, -30), Vector2(35, 10),
		Vector2(28, 50), Vector2(0, 60), Vector2(-28, 50),
		Vector2(-35, 10), Vector2(-30, -30)
	])
	body.color = Color(0.35, 0.65, 0.9)
	character.add_child(body)
	
	# Highlight/shine
	var shine = Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-15, -40), Vector2(-8, -45), Vector2(-5, -25), Vector2(-12, -20)
	])
	shine.color = Color(0.6, 0.85, 1, 0.6)
	character.add_child(shine)
	
	# Big cute eyes
	var left_eye_white = Polygon2D.new()
	left_eye_white.polygon = PackedVector2Array(_create_oval_points(14, 18, 12))
	left_eye_white.position = Vector2(-12, -10)
	left_eye_white.color = Color.WHITE
	character.add_child(left_eye_white)
	
	var left_pupil = Polygon2D.new()
	left_pupil.polygon = PackedVector2Array(_create_oval_points(7, 9, 8))
	left_pupil.position = Vector2(-10, -6)
	left_pupil.color = Color(0.1, 0.1, 0.1)
	character.add_child(left_pupil)
	
	var right_eye_white = Polygon2D.new()
	right_eye_white.polygon = PackedVector2Array(_create_oval_points(14, 18, 12))
	right_eye_white.position = Vector2(12, -10)
	right_eye_white.color = Color.WHITE
	character.add_child(right_eye_white)
	
	var right_pupil = Polygon2D.new()
	right_pupil.polygon = PackedVector2Array(_create_oval_points(7, 9, 8))
	right_pupil.position = Vector2(14, -6)
	right_pupil.color = Color(0.1, 0.1, 0.1)
	character.add_child(right_pupil)
	
	# Big happy smile
	var smile = Line2D.new()
	smile.width = 4
	smile.default_color = Color(0.15, 0.15, 0.15)
	smile.points = PackedVector2Array([
		Vector2(-12, 20), Vector2(-5, 28), Vector2(5, 28), Vector2(12, 20)
	])
	character.add_child(smile)
	
	# Cute arms waving
	var left_arm = Polygon2D.new()
	left_arm.polygon = PackedVector2Array([
		Vector2(-35, 5), Vector2(-55, -15), Vector2(-60, -10), Vector2(-40, 10)
	])
	left_arm.color = Color(0.35, 0.65, 0.9)
	left_arm.name = "LeftArm"
	character.add_child(left_arm)
	
	var right_arm = Polygon2D.new()
	right_arm.polygon = PackedVector2Array([
		Vector2(35, 5), Vector2(55, -15), Vector2(60, -10), Vector2(40, 10)
	])
	right_arm.color = Color(0.35, 0.65, 0.9)
	right_arm.name = "RightArm"
	character.add_child(right_arm)
	
	return character

func _animate_main_character(character: Node2D):
	# Gentle idle bounce
	var bounce = create_tween().set_loops()
	bounce.tween_property(character, "position:y", character.position.y - 8, 0.6)
	bounce.tween_property(character, "position:y", character.position.y + 8, 0.6)
	
	# Wave arms
	var left_arm = character.get_node_or_null("LeftArm")
	var right_arm = character.get_node_or_null("RightArm")
	if left_arm:
		var wave_l = create_tween().set_loops()
		wave_l.tween_property(left_arm, "rotation_degrees", -15.0, 0.4)
		wave_l.tween_property(left_arm, "rotation_degrees", 15.0, 0.4)
	if right_arm:
		var wave_r = create_tween().set_loops()
		wave_r.tween_property(right_arm, "rotation_degrees", 15.0, 0.4)
		wave_r.tween_property(right_arm, "rotation_degrees", -15.0, 0.4)

func _create_droplet_character(index: int) -> Node2D:
	var character = Node2D.new()
	character.name = "WalkingChar" + str(index)
	
	# More varied droplet colors (kid-friendly rainbow!)
	var colors = [
		Color(0.4, 0.75, 0.95),   # Light blue
		Color(0.5, 0.85, 0.6),    # Mint green
		Color(0.95, 0.75, 0.4),   # Golden
		Color(0.9, 0.5, 0.7),     # Pink
		Color(0.6, 0.5, 0.9),     # Purple
		Color(0.95, 0.6, 0.5),    # Coral
	]
	var body_color = colors[index % colors.size()]
	
	# Body (blob shape)
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -35), Vector2(18, -15), Vector2(20, 10),
		Vector2(15, 30), Vector2(-15, 30), Vector2(-20, 10),
		Vector2(-18, -15)
	])
	body.color = body_color
	character.add_child(body)
	
	# Shine highlight
	var shine = Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-10, -25), Vector2(-5, -28), Vector2(-3, -18), Vector2(-8, -15)
	])
	shine.color = Color(1, 1, 1, 0.4)
	character.add_child(shine)
	
	# Eyes
	var left_eye = Polygon2D.new()
	left_eye.polygon = PackedVector2Array(_create_oval_points(6, 8, 8))
	left_eye.position = Vector2(-8, -5)
	left_eye.color = Color.WHITE
	character.add_child(left_eye)
	
	var left_pupil = Polygon2D.new()
	left_pupil.polygon = PackedVector2Array(_create_oval_points(3, 4, 6))
	left_pupil.position = Vector2(-8, -3)
	left_pupil.color = Color.BLACK
	character.add_child(left_pupil)
	
	var right_eye = Polygon2D.new()
	right_eye.polygon = PackedVector2Array(_create_oval_points(6, 8, 8))
	right_eye.position = Vector2(8, -5)
	right_eye.color = Color.WHITE
	character.add_child(right_eye)
	
	var right_pupil = Polygon2D.new()
	right_pupil.polygon = PackedVector2Array(_create_oval_points(3, 4, 6))
	right_pupil.position = Vector2(8, -3)
	right_pupil.color = Color.BLACK
	character.add_child(right_pupil)
	
	# Smile
	var smile = Line2D.new()
	smile.width = 2
	smile.default_color = Color(0.2, 0.2, 0.2)
	smile.points = PackedVector2Array([
		Vector2(-6, 8), Vector2(0, 12), Vector2(6, 8)
	])
	character.add_child(smile)
	
	# Arms
	var left_arm = Polygon2D.new()
	left_arm.polygon = PackedVector2Array([
		Vector2(-20, 0), Vector2(-35, -10), Vector2(-38, -5), Vector2(-22, 5)
	])
	left_arm.color = body_color
	character.add_child(left_arm)
	
	var right_arm = Polygon2D.new()
	right_arm.polygon = PackedVector2Array([
		Vector2(20, 0), Vector2(35, -10), Vector2(38, -5), Vector2(22, 5)
	])
	right_arm.color = body_color
	character.add_child(right_arm)
	
	# Add fun accessories based on index
	var accessory = Label.new()
	accessory.add_theme_font_size_override("font_size", 18)
	accessory.position = Vector2(-9, -50)
	
	var accessories = ["🎀", "🎩", "👒", "🧢", "🌸", "⭐"]
	accessory.text = accessories[index % accessories.size()]
	character.add_child(accessory)
	
	# Some characters get extra items (held items)
	if index % 3 == 0:
		var item = Label.new()
		item.add_theme_font_size_override("font_size", 14)
		item.position = Vector2(25, -5)
		var items = ["🍦", "🎈", "🌊", "💧"]
		item.text = items[index % items.size()]
		character.add_child(item)
	
	character.scale = Vector2(0.85, 0.85)
	return character

func _animate_character_walk(character: Node2D, screen_size: Vector2):
	var walk_tween = create_tween().set_loops()
	
	var start_x = randf_range(150, 400)
	var end_x = randf_range(screen_size.x - 400, screen_size.x - 150)
	var duration = randf_range(6.0, 10.0)
	
	# Walk right
	walk_tween.tween_property(character, "position:x", end_x, duration)
	walk_tween.tween_callback(func(): character.scale.x = -abs(character.scale.x))
	# Walk left
	walk_tween.tween_property(character, "position:x", start_x, duration)
	walk_tween.tween_callback(func(): character.scale.x = abs(character.scale.x))
	
	# Bobbing
	var bob_tween = create_tween().set_loops()
	bob_tween.tween_property(character, "position:y", character.position.y - 5, 0.25)
	bob_tween.tween_property(character, "position:y", character.position.y + 5, 0.25)

func _ready() -> void:
	_create_waterpark_background()
	_update_droplet_count()
	_update_highscore()
	_update_translations()
	_update_next_unlock()
	_apply_theme()

	# Start menu background music
	if AudioManager:
		AudioManager.play_music("menu")
	
	# Connect to language changes
	if Localization:
		Localization.language_changed.connect(_on_language_changed)
	
	# Connect to theme changes
	var theme_mgr = get_node_or_null("/root/ThemeManager")
	if theme_mgr:
		theme_mgr.theme_changed.connect(_on_theme_changed)
	
	# Show welcome popup ONLY on first ever launch
	await get_tree().create_timer(0.5).timeout
	if GameManager and GameManager.should_show_welcome_popup():
		_show_welcome_popup()
		GameManager.mark_welcome_shown()  # Never show again

func _on_theme_changed(_is_dark: bool) -> void:
	_apply_theme()

func _apply_theme() -> void:
	# Apply current theme colors
	var theme_mgr = get_node_or_null("/root/ThemeManager")
	if not theme_mgr:
		return
	
	# Apply to labels
	if highscore_label:
		theme_mgr.apply_to_label(highscore_label)
	if droplet_label:
		theme_mgr.apply_to_label(droplet_label)

func _update_highscore():
	if highscore_label and GameManager:
		highscore_label.text = "HIGHSCORE %d" % GameManager.high_score

func _update_next_unlock():
	if next_unlock_panel:
		next_unlock_panel.visible = true
		# Update progress based on droplets collected
		var progress_bar = next_unlock_panel.get_node_or_null("VBox/Progress")
		var points_label = next_unlock_panel.get_node_or_null("VBox/ItemName")
		if progress_bar and GameManager:
			var next_goal = 100  # Example goal
			var current = GameManager.water_droplets % next_goal
			progress_bar.value = (float(current) / next_goal) * 100
			if points_label:
				points_label.text = "%d points to go" % (next_goal - current)

func _setup_character_display():
	# Characters walk in the waterpark scene background
	pass

func _update_translations() -> void:
	if not Localization:
		return
	
	if play_button:
		play_button.text = Localization.get_text("play")
	if multiplayer_button:
		multiplayer_button.text = Localization.get_text("multiplayer")
	# Add translations for welcome popup here if needed

func _on_language_changed(_new_lang: String) -> void:
	_update_translations()

func _update_droplet_count() -> void:
	if GameManager:
		droplet_label.text = str(GameManager.water_droplets)
	else:
		droplet_label.text = "0"

func _show_welcome_popup() -> void:
	welcome_popup.visible = true
	welcome_panel.scale = Vector2.ZERO
	
	var tween = create_tween()
	tween.tween_property(welcome_panel, "scale", Vector2(1.1, 1.1), 0.3) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(welcome_panel, "scale", Vector2(1.0, 1.0), 0.1)

func _on_close_popup_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	var tween = create_tween()
	tween.tween_property(welcome_panel, "scale", Vector2(0.0, 0.0), 0.2) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): welcome_popup.visible = false)

func _on_play_button_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
		AudioManager.stop_music(0.3)
	# Start new session (this shuffles games and resets state)
	if GameManager:
		GameManager.start_new_session()
		GameManager.start_next_minigame()
	else:
		# Fallback if no GameManager
		pass

func _on_settings_button_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/Settings.tscn")

func _on_multiplayer_button_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _on_customize_button_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	# Navigate to unlockables screen (character customization)
	get_tree().change_scene_to_file("res://scenes/ui/UnlockablesScreen.tscn")

func _on_store_button_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	# Navigate to roadmap/journey screen
	get_tree().change_scene_to_file("res://scenes/ui/RoadmapScreen.tscn")
