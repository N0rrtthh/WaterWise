extends MiniGameBase

var buckets: Array = []
var correct_bucket: Node2D = null
var shuffled: bool = false
var shuffle_timer: float = 0.0
var shuffle_swaps: int = 0
var max_swaps: int = 4
var shuffle_speed: float = 0.8
var can_click: bool = false
var plant_node: Node2D

## Seconds a single swap animation takes. The shuffle phase cannot hand control
## back to the player until the last one has landed — see _process.
const SWAP_DURATION: float = 0.3

## Set while a swap tween is in flight, so _process can wait it out.
var _swap_settle_left: float = 0.0

func _apply_difficulty_settings() -> void:
	# super() activates the chaos effects the algorithm picked for this round.
	super._apply_difficulty_settings()

	match current_difficulty:
		"Easy":
			max_swaps = 2
			shuffle_speed = 1.2  # Slower shuffle
			game_duration = 15.0
		"Medium":
			max_swaps = 4
			shuffle_speed = 0.8
			game_duration = 10.0
		"Hard":
			max_swaps = 7
			shuffle_speed = 0.4  # Fast shuffle
			game_duration = 8.0

func _ready():
	# Localized: the title stayed English above the Filipino objective FIX 58
	# authored. _loc() keeps the English literal as the fallback for the case
	# where the table is not up yet (tools/SceneLoadCheck instantiates that way).
	game_name = _loc("thirsty_plant", "Thirsty Plant")
	game_instruction_text = (
		Localization.get_text("plant_instruction")
		if Localization
		else "TAP THE GREEN BUCKET!\nUSE REUSED WATER!"
	)
	game_duration = 10.0
	game_mode = "quota"
	timer_starts_paused = true  # Timer starts AFTER shuffle
	show_timer = false  # Hide timer during shuffle phase
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.6, 0.8, 0.5)
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	bg.z_index = -10
	add_child(bg)
	
	# Ground
	var ground = ColorRect.new()
	ground.color = Color(0.5, 0.35, 0.2)
	ground.position = Vector2(0, screen_size.y * 0.8)
	ground.size = Vector2(screen_size.x, screen_size.y * 0.2)
	ground.z_index = -5
	add_child(ground)
	
	# Plant
	plant_node = Node2D.new()
	plant_node.position = Vector2(screen_size.x * 0.5, screen_size.y * 0.35)
	add_child(plant_node)
	
	var pot = Polygon2D.new()
	pot.polygon = PackedVector2Array([
		Vector2(-50, 0), Vector2(50, 0),
		Vector2(40, 80), Vector2(-40, 80)
	])
	pot.color = Color(0.7, 0.4, 0.2)
	plant_node.add_child(pot)
	
	var stem = Line2D.new()
	stem.name = "Stem"
	stem.points = PackedVector2Array([Vector2(0, 0), Vector2(-10, -60), Vector2(0, -100)])
	stem.width = 8
	stem.default_color = Color(0.3, 0.5, 0.2)
	plant_node.add_child(stem)

	var leaf1 = Polygon2D.new()
	leaf1.name = "Leaf"
	leaf1.polygon = PackedVector2Array([Vector2(0, 0), Vector2(-50, -20), Vector2(-40, 10)])
	leaf1.color = Color(0.5, 0.6, 0.3)
	leaf1.position = Vector2(-10, -60)
	plant_node.add_child(leaf1)

	var bubble = Label.new()
	bubble.name = "Bubble"
	bubble.text = "💧?"
	bubble.add_theme_font_size_override("font_size", 48)
	bubble.position = Vector2(60, -120)
	plant_node.add_child(bubble)
	
	# Buckets
	var positions = [
		Vector2(screen_size.x * 0.25, screen_size.y * 0.7),
		Vector2(screen_size.x * 0.5, screen_size.y * 0.7),
		Vector2(screen_size.x * 0.75, screen_size.y * 0.7)
	]
	
	for i in range(3):
		var is_correct = (i == 0)
		var bucket = _create_bucket(positions[i], is_correct)
		buckets.append(bucket)
		if is_correct:
			correct_bucket = bucket
	
	# Status
	var status = Label.new()
	status.text = _loc("hud_watch_green_bucket", "👀 Watch the GREEN bucket!")
	status.add_theme_font_size_override("font_size", 32)
	status.add_theme_color_override("font_color", Color.WHITE)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	status.add_theme_constant_override("outline_size", 4)
	status.position = Vector2(screen_size.x / 2 - 200, screen_size.y - 100)
	status.name = "StatusLabel"
	add_child(status)

func _create_bucket(pos: Vector2, is_correct: bool) -> Node2D:
	var bucket = Node2D.new()
	bucket.position = pos
	bucket.set_meta("is_correct", is_correct)
	add_child(bucket)
	
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-50, -60), Vector2(50, -60),
		Vector2(40, 60), Vector2(-40, 60)
	])
	body.color = Color(0.2, 0.8, 0.3) if is_correct else Color(0.3, 0.4, 0.8)
	body.name = "Body"
	bucket.add_child(body)
	
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-45, -30), Vector2(45, -30),
		Vector2(38, 55), Vector2(-38, 55)
	])
	water.color = Color(0.3, 0.6, 1.0, 0.7)
	bucket.add_child(water)
	
	return bucket

func _input(event):
	if not game_active or not can_click: return
	
	var tap_pos = Vector2.ZERO
	var is_tap = false
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
		is_tap = true
	elif event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
		is_tap = true
	
	if is_tap:
		for bucket in buckets:
			if tap_pos.distance_to(bucket.position) < 80:
				_on_bucket_pressed(bucket)
				break

func _process(delta):
	super._process(delta)
	if not game_active: return

	var status = get_node("StatusLabel")

	if _swap_settle_left > 0.0:
		_swap_settle_left -= delta

	# Shuffling phase
	if not shuffled:
		shuffle_timer += delta
		if shuffle_timer > shuffle_speed and shuffle_swaps < max_swaps:
			shuffle_timer = 0
			_swap_random_buckets()
			shuffle_swaps += 1
			status.text = _loc("hud_shuffling", "🔀 Shuffling... (%d/%d)") % [shuffle_swaps, max_swaps]
		elif shuffle_swaps >= max_swaps and _swap_settle_left <= 0.0:
			# Only hand over control once the last swap tween has LANDED.
			#
			# The frame after the final swap starts, shuffle_timer has just been
			# reset so the first branch is false and this one used to fire
			# immediately — 0.3 s before the buckets stopped moving. Tapping in that
			# window hit-tested against `bucket.position` mid-interpolation, so the
			# hitbox was somewhere between the two slots while the player was aiming
			# at what they could see. On Hard (shuffle_speed 0.4) that was most of
			# the gap between swaps.
			shuffled = true
			can_click = true
			status.text = _loc("hud_tap_water_bucket", "👆 TAP the water bucket!")

			# Hide all bucket colors
			for bucket in buckets:
				bucket.get_node("Body").color = Color(0.3, 0.4, 0.8)

			# NOW start the timer
			show_timer = true
			start_timer_now()
			if timer_bar:
				timer_bar.visible = true

func _swap_random_buckets():
	var idx1 = randi() % buckets.size()
	var idx2 = (idx1 + 1 + randi() % (buckets.size() - 1)) % buckets.size()

	var b1 = buckets[idx1]
	var b2 = buckets[idx2]

	var pos1 = b1.position
	var pos2 = b2.position

	_swap_settle_left = SWAP_DURATION

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(b1, "position", pos2, SWAP_DURATION).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(b2, "position", pos1, SWAP_DURATION).set_trans(Tween.TRANS_QUAD)
	# A squash out and a settle back reads as weight; without it the buckets slide
	# like cursors. Scale is independent of the position tween above, so the two
	# cannot fight over a property, and the return leg is a delay rather than a
	# chained step so the whole thing stays one parallel group.
	var half: float = SWAP_DURATION * 0.5
	for b in [b1, b2]:
		tween.tween_property(b, "scale", Vector2(0.88, 1.1), half)
		tween.tween_property(b, "scale", Vector2.ONE, half).set_delay(half)

func _on_bucket_pressed(bucket: Node2D):
	if not game_active or not can_click: return
	can_click = false
	
	var is_correct = bucket.get_meta("is_correct")
	
	if is_correct:
		record_action(true)
		bucket.get_node("Body").color = Color(0.2, 0.9, 0.3)
		
		var tween = create_tween()
		tween.tween_property(bucket, "position:y", plant_node.position.y, 0.5)
		tween.tween_callback(func(): _water_plant())
	else:
		record_action(false)
		bucket.get_node("Body").color = Color(0.9, 0.3, 0.3)
		correct_bucket.get_node("Body").color = Color(0.2, 0.9, 0.3)
		
		await round_delay(1.0)
		end_game(false)

func _water_plant():
	## Perk the plant up: greener foliage, a relieved bubble, and a growth pop.
	##
	## This used to recolor "every Polygon2D whose color.g < 0.7", which caught the
	## terracotta pot (0.7, 0.4, 0.2) as well as the leaf and turned it grass green,
	## while missing the stem entirely because a Line2D is not a Polygon2D. Naming
	## the two parts that represent foliage fixes both halves.
	var leaf := plant_node.get_node_or_null("Leaf") as Polygon2D
	if leaf:
		leaf.color = Color(0.3, 0.8, 0.3)
	var stem := plant_node.get_node_or_null("Stem") as Line2D
	if stem:
		stem.default_color = Color(0.25, 0.7, 0.25)

	# The bubble asked "💧?" for the whole round; leaving it up after a successful
	# watering read as though the plant were still thirsty.
	var bubble := plant_node.get_node_or_null("Bubble") as Label
	if bubble:
		bubble.text = "😌💚"

	# Anticipation-free but readable: a stretch up, an overshoot settle. The plant
	# visibly grows from being watered, which is the lesson in one beat.
	plant_node.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(plant_node, "scale", Vector2(0.9, 1.25), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(plant_node, "scale", Vector2(1.08, 1.05), 0.1)
	tw.tween_property(plant_node, "scale", Vector2.ONE, 0.12)

	await round_delay(0.5)
	end_game(true)
