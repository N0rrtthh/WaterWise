extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## Bundle 2: Shower Water Collection
## P1 collects shower water in buckets

const BUCKET_HALF_W: float = 75.0     # half of the 150px collision box
const BUCKET_MARGIN_BOTTOM: float = 150.0
const SPAWN_MARGIN: float = 80.0
const BUCKET_CAPACITY: int = 2   # was 3 — fills faster so P2 gets water sooner
const MAX_OVERFLOW: int = 8      # was 5 — more forgiving

## Points paid per drop caught, and the TEAM point total that ends the round. win_quota is
## measured against team_score() — the shared G-Counter sum — which the partner's flushing
## pays into as well, so the old "Catch 10 drops to win" was neither necessary nor sufficient.
const POINTS_PER_DROP: int = 5
const TEAM_TARGET: int = 50

var water_collected: int = 0
var overflows: int = 0
var buckets: Array = []
var spawn_timer: Timer
var dragging_bucket: Area2D = null
var _layout_ready: bool = false

func get_instructions() -> String:
	return Localization.get_text("mp_collect_shower_water_instructions") % [POINTS_PER_DROP, TEAM_TARGET, BUCKET_CAPACITY, MAX_OVERFLOW]

func get_controls_text() -> String:
	return Localization.get_text("mp_collect_shower_water_controls")

func _on_multiplayer_ready() -> void:
	game_name = "Collect Shower Water"
	title_key = "mp_title_collect_shower_water"
	win_quota = TEAM_TARGET # a TEAM total — the partner pays into it too
	set_process_input(true)
	
	_create_buckets()
	_connect_viewport_resize()
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.0   # was 1.5 — more drops = more water for P2
	spawn_timer.timeout.connect(_spawn_water_drop)
	add_child(spawn_timer)
	
	_log("🚿 Catch shower water! Overflow %d times = lose 1 life" % MAX_OVERFLOW)

func _on_game_start() -> void:
	spawn_timer.start()

func _create_buckets() -> void:
	for i in range(4):
		var bucket = Area2D.new()
		bucket.set_meta("water_level", 0)
		add_child(bucket)
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(150, 150)
		collision.shape = shape
		bucket.add_child(collision)
		
		var visual = Sprite2D.new()
		visual.name = "Visual"
		# Generated small and scaled: create_bucket_texture() sets every pixel from GDScript.
		visual.texture = MiniGameAssets.create_bucket_texture(100, 120, Color(0.8, 0.8, 0.8))
		visual.scale = Vector2(150.0 / 100.0, 150.0 / 120.0)
		bucket.add_child(visual)
		
		var label = Label.new()
		label.name = "Label"
		label.text = "0/%d" % BUCKET_CAPACITY
		label.position = Vector2(-20, -80)
		label.add_theme_font_size_override("font_size", 20)
		MiniGameAssets.outline_text(label)
		bucket.add_child(label)
		
		bucket.input_event.connect(_on_bucket_input.bind(bucket))
		buckets.append(bucket)
	# Seated from the visible rect, not from authored constants: see seat_catchers() in the base.
	_layout_ready = seat_catchers(buckets, BUCKET_HALF_W, BUCKET_MARGIN_BOTTOM, false)

func _connect_viewport_resize() -> void:
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	_layout_ready = seat_catchers(buckets, BUCKET_HALF_W, BUCKET_MARGIN_BOTTOM, _layout_ready)

func _on_bucket_input(_viewport: Node, event: InputEvent, _shape_idx: int, bucket: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_bucket = bucket

func _input(event: InputEvent) -> void:
	if not game_active:
		return
	
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_bucket = null
	
	if event is InputEventMouseMotion and dragging_bucket:
		dragging_bucket.position.x = clamp_x_into_playfield(
			world_from_screen(event.position).x, BUCKET_HALF_W)

func _spawn_water_drop() -> void:
	var drop = Area2D.new()
	drop.position = spawn_above_playfield(SPAWN_MARGIN)
	drop.set_meta("velocity", Vector2(0, 200))
	add_child(drop)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15
	collision.shape = shape
	drop.add_child(collision)
	
	var visual = ColorRect.new()
	visual.size = Vector2(30, 30)
	visual.position = Vector2(-15, -15)
	visual.color = Color(0.5, 0.7, 1.0)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.add_child(visual)
	
	drop.area_entered.connect(_on_drop_hit_bucket.bind(drop))

func _process(delta: float) -> void:
	if not game_active:
		return
	
	for child in get_children():
		if child is Area2D and child.has_meta("velocity"):
			child.position += child.get_meta("velocity") * delta
			
			if child.position.y > playfield_exit_y():
				overflows += 1
				_log("💧 Overflow! (%d/%d)" % [overflows, MAX_OVERFLOW])
				child.queue_free()
				
				if overflows >= MAX_OVERFLOW:
					overflows = 0
					report_miss_to_host()

func _on_drop_hit_bucket(area: Area2D, drop: Area2D) -> void:
	if not area.has_meta("water_level"):
		return
	
	var level = area.get_meta("water_level", 0)
	if level >= BUCKET_CAPACITY:
		return  # Bucket full
	
	level += 1
	area.set_meta("water_level", level)
	area.get_node("Label").text = "%d/%d" % [level, BUCKET_CAPACITY]
	
	var visual = area.get_node("Visual")
	visual.modulate = Color(0.3, 0.6, 1.0, 0.3 + level * 0.2)
	
	water_collected += 1
	add_score(POINTS_PER_DROP, true, area)
	
	drop.queue_free()
	
	if level >= BUCKET_CAPACITY:
		_empty_bucket(area)

func _empty_bucket(bucket: Area2D) -> void:
	_log("🏺 Bucket full! Sending to partner")
	send_resource_to_partner("shower_water", BUCKET_CAPACITY, 1.0)
	
	bucket.set_meta("water_level", 0)
	bucket.get_node("Label").text = "0/%d" % BUCKET_CAPACITY
	bucket.get_node("Visual").modulate = Color(0.4, 0.4, 0.4, 0.3)

func _on_game_over() -> void:
	spawn_timer.stop()
	super._on_game_over()
