extends MiniGameBase

var veggies_to_wash: int = 5
var veggies_washed: int = 0
var time_penalty: float = 3.0

var source_basket: Node2D
var wash_bowl: Node2D
var clean_basket: Node2D

var veggies: Array = []
var selected_veggie: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO

func _apply_difficulty_settings() -> void:
	match current_difficulty:
		"Easy":
			veggies_to_wash = 3
			time_penalty = 2.0
			game_duration = 20.0
		"Medium":
			veggies_to_wash = 4
			time_penalty = 3.0
			game_duration = 20.0
		"Hard":
			veggies_to_wash = 5
			time_penalty = 5.0
			game_duration = 18.0

func _ready():
	game_name = "Vegetable Bath"
	game_instruction_text = "DRAG: Dirty Basket → Wash Bowl → Clean Basket!\nDirty in clean = TIME PENALTY! 🥕"
	game_duration = 25.0
	game_mode = "quota"
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.95, 0.9, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Counter
	var counter = ColorRect.new()
	counter.color = Color(0.55, 0.35, 0.2)
	counter.position = Vector2(0, screen_size.y * 0.78)
	counter.size = Vector2(screen_size.x, screen_size.y * 0.22)
	counter.z_index = -5
	add_child(counter)
	
	# Score
	var score_lbl = Label.new()
	score_lbl.name = "ScoreLabel"
	score_lbl.text = "🥬 Clean: 0 / %d" % veggies_to_wash
	score_lbl.add_theme_font_size_override("font_size", 32)
	score_lbl.add_theme_color_override("font_color", Color.WHITE)
	score_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	score_lbl.add_theme_constant_override("outline_size", 4)
	score_lbl.position = Vector2(screen_size.x / 2 - 100, 120)
	add_child(score_lbl)
	
	_create_source_basket(screen_size)
	_create_wash_bowl(screen_size)
	_create_clean_basket(screen_size)
	_create_veggies()

func _create_source_basket(screen_size: Vector2):
	source_basket = Node2D.new()
	source_basket.position = Vector2(screen_size.x * 0.15, screen_size.y * 0.55)
	add_child(source_basket)
	
	var basket = Polygon2D.new()
	basket.polygon = PackedVector2Array([
		Vector2(-80, -40), Vector2(80, -40),
		Vector2(70, 60), Vector2(-70, 60)
	])
	basket.color = Color(0.6, 0.4, 0.2)
	source_basket.add_child(basket)
	
	var lbl = Label.new()
	lbl.text = "🥬 DIRTY"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.3))
	lbl.position = Vector2(-45, 65)
	source_basket.add_child(lbl)

func _create_wash_bowl(screen_size: Vector2):
	wash_bowl = Node2D.new()
	wash_bowl.position = Vector2(screen_size.x * 0.5, screen_size.y * 0.55)
	add_child(wash_bowl)
	
	var bowl = Polygon2D.new()
	bowl.polygon = PackedVector2Array([
		Vector2(-90, -30), Vector2(90, -30),
		Vector2(75, 60), Vector2(-75, 60)
	])
	bowl.color = Color(0.7, 0.7, 0.75)
	wash_bowl.add_child(bowl)
	
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-80, -20), Vector2(80, -20),
		Vector2(65, 55), Vector2(-65, 55)
	])
	water.color = Color(0.3, 0.6, 0.9, 0.7)
	wash_bowl.add_child(water)
	
	var lbl = Label.new()
	lbl.text = "💧 WASH"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.2, 0.5, 0.8))
	lbl.position = Vector2(-45, 65)
	wash_bowl.add_child(lbl)

func _create_clean_basket(screen_size: Vector2):
	clean_basket = Node2D.new()
	clean_basket.position = Vector2(screen_size.x * 0.85, screen_size.y * 0.55)
	add_child(clean_basket)
	
	var basket = Polygon2D.new()
	basket.polygon = PackedVector2Array([
		Vector2(-80, -40), Vector2(80, -40),
		Vector2(70, 60), Vector2(-70, 60)
	])
	basket.color = Color(0.4, 0.7, 0.4)
	clean_basket.add_child(basket)
	
	var lbl = Label.new()
	lbl.text = "✓ CLEAN"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
	lbl.position = Vector2(-45, 65)
	clean_basket.add_child(lbl)

func _create_veggies():
	var types = [
		{"color": Color(1.0, 0.4, 0.2), "emoji": "🥕"},
		{"color": Color(0.2, 0.7, 0.2), "emoji": "🥬"},
		{"color": Color(0.8, 0.2, 0.2), "emoji": "🍅"},
		{"color": Color(0.5, 0.3, 0.6), "emoji": "🍆"},
		{"color": Color(0.9, 0.8, 0.2), "emoji": "🌽"}
	]
	
	for i in range(veggies_to_wash):
		var type = types[i % types.size()]
		var veggie = Node2D.new()
		veggie.position = source_basket.position + Vector2(randf_range(-50, 50), randf_range(-25, 25))
		veggie.set_meta("washed", false)
		veggie.set_meta("done", false)
		add_child(veggie)
		
		var visual = Polygon2D.new()
		var points = PackedVector2Array()
		for j in range(10):
			var angle = j * TAU / 10
			points.append(Vector2(cos(angle) * 28, sin(angle) * 28))
		visual.polygon = points
		visual.color = type.color
		visual.name = "Visual"
		veggie.add_child(visual)
		
		var emoji = Label.new()
		emoji.text = type.emoji
		emoji.add_theme_font_size_override("font_size", 32)
		emoji.position = Vector2(-16, -20)
		veggie.add_child(emoji)
		
		var dirt = Node2D.new()
		dirt.name = "Dirt"
		for d in range(4):
			var spot = Polygon2D.new()
			var sp = PackedVector2Array()
			for k in range(5):
				var a = k * TAU / 5
				sp.append(Vector2(cos(a) * 6, sin(a) * 6))
			spot.polygon = sp
			spot.color = Color(0.4, 0.3, 0.15, 0.7)
			spot.position = Vector2(randf_range(-18, 18), randf_range(-18, 18))
			dirt.add_child(spot)
		veggie.add_child(dirt)
		
		veggies.append(veggie)

func _input(event):
	if not game_active: return
	
	var pos = Vector2.ZERO
	var pressed = false
	var released = false
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	
	if pressed:
		for veggie in veggies:
			if not is_instance_valid(veggie): continue
			if veggie.get_meta("done"): continue
			if pos.distance_to(veggie.position) < 50:
				selected_veggie = veggie
				drag_offset = veggie.position - pos
				veggie.scale = Vector2(1.2, 1.2)
				veggie.z_index = 10
				break
	
	if released and selected_veggie:
		selected_veggie.scale = Vector2(1.0, 1.0)
		selected_veggie.z_index = 0
		_check_placement(selected_veggie)
		selected_veggie = null

func _check_placement(veggie: Node2D):
	var pos = veggie.position
	
	# In wash bowl
	if pos.distance_to(wash_bowl.position) < 100:
		if not veggie.get_meta("washed"):
			veggie.set_meta("washed", true)
			veggie.get_node("Dirt").visible = false
			var sparkle = Label.new()
			sparkle.text = "✨"
			sparkle.add_theme_font_size_override("font_size", 40)
			sparkle.position = veggie.position + Vector2(-15, -40)
			add_child(sparkle)
			var tw = create_tween()
			tw.tween_property(sparkle, "modulate:a", 0.0, 0.5)
			tw.tween_callback(sparkle.queue_free)
		veggie.position = wash_bowl.position + Vector2(randf_range(-40, 40), randf_range(-15, 25))
		return
	
	# In clean basket
	if pos.distance_to(clean_basket.position) < 100:
		if veggie.get_meta("washed"):
			veggie.set_meta("done", true)
			veggies_washed += 1
			record_action(true)
			get_node("ScoreLabel").text = "🥬 Clean: %d / %d" % [veggies_washed, veggies_to_wash]
			veggie.position = clean_basket.position + Vector2(randf_range(-40, 40), randf_range(-20, 30))
			if veggies_washed >= veggies_to_wash:
				await get_tree().create_timer(0.5).timeout
				end_game(true)
		else:
			# DIRTY VEGGIE PENALTY
			record_action(false)
			var warn = Label.new()
			warn.text = "❌ DIRTY!"
			warn.add_theme_font_size_override("font_size", 36)
			warn.add_theme_color_override("font_color", Color.RED)
			warn.position = veggie.position + Vector2(-60, -60)
			add_child(warn)
			var tw = create_tween()
			tw.tween_property(warn, "modulate:a", 0.0, 1.0)
			tw.tween_callback(warn.queue_free)
			var bounce_tw = create_tween()
			bounce_tw.tween_property(veggie, "position", source_basket.position, 0.3)
		return
	
	# Return to source
	var return_tw = create_tween()
	return_tw.tween_property(veggie, "position", source_basket.position + Vector2(randf_range(-40, 40), randf_range(-20, 20)), 0.2)

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	if selected_veggie and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		selected_veggie.position = get_viewport().get_mouse_position() + drag_offset
