extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## Bundle 5: Collect Dish Water
## P1 catches water from dishwashing

const BUCKET_HALF_W: float = 75.0     # collision radius: how far the bowl reaches sideways (48dp floor)
const BUCKET_MARGIN_BOTTOM: float = 130.0
const SPAWN_MARGIN: float = 80.0
const MAX_SPILLS: int = 8   # was 5 — more forgiving

## Points paid per drop caught, and the TEAM point total that ends the round. win_quota is
## measured against team_score() — the shared G-Counter sum — which the partner's scrubbing
## pays into as well, so the old "Catch 10 drops to win" was neither necessary nor sufficient.
const POINTS_PER_DROP: int = 5
const TEAM_TARGET: int = 50

var water_collected: int = 0
var spills: int = 0
var buckets: Array = []
var spawn_timer: Timer
var dragging_bucket: Area2D = null
var _layout_ready: bool = false

func get_instructions() -> String:
	return Localization.get_text("mp_collect_dish_water_instructions") % [POINTS_PER_DROP, TEAM_TARGET, MAX_SPILLS]

func get_controls_text() -> String:
	return Localization.get_text("mp_collect_dish_water_controls")

func _on_multiplayer_ready() -> void:
	game_name = "Collect Dish Water"
	title_key = "mp_title_collect_dish_water"
	win_quota = TEAM_TARGET # a TEAM total — the partner pays into it too
	set_process_input(true)
	
	_create_buckets()
	_connect_viewport_resize()
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.2   # was 1.8 — more drops = more water for P2
	spawn_timer.timeout.connect(_spawn_water_drop)
	add_child(spawn_timer)
	
	_log("🍽️ Catch dish water! %d spills = lose 1 life" % MAX_SPILLS)

func _on_game_start() -> void:
	spawn_timer.start()

func _create_buckets() -> void:
	for i in range(3):
		var bucket = Area2D.new()
		add_child(bucket)
		
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = BUCKET_HALF_W
		collision.shape = shape
		bucket.add_child(collision)
		
		var visual = Sprite2D.new()
		# Generated at 120 and scaled, not generated at 150: create_bucket_texture() writes
		# every pixel from GDScript, and 150x150 x3 buckets is 67k set_pixel calls at round
		# start on a phone. Sprite2D.scale costs nothing and the hit shape is the real size.
		visual.texture = MiniGameAssets.create_bucket_texture(120, 120, Color(0.6, 0.6, 0.6))
		visual.scale = Vector2.ONE * (BUCKET_HALF_W * 2.0 / 120.0)
		bucket.add_child(visual)
		
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
	drop.set_meta("velocity", Vector2(0, 220))
	drop.set_meta("type", "dishwater")
	add_child(drop)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 18
	collision.shape = shape
	drop.add_child(collision)
	
	var visual = ColorRect.new()
	visual.size = Vector2(36, 36)
	visual.position = Vector2(-18, -18)
	visual.color = Color(0.7, 0.7, 0.6)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.add_child(visual)
	
	drop.area_entered.connect(_on_drop_caught.bind(drop))

func _process(delta: float) -> void:
	if not game_active:
		return
	
	for child in get_children():
		if child is Area2D and child.has_meta("velocity"):
			child.position += child.get_meta("velocity") * delta
			
			if child.position.y > playfield_exit_y():
				spills += 1
				_log("💦 Spilled! (%d/%d)" % [spills, MAX_SPILLS])
				child.queue_free()
				
				if spills >= MAX_SPILLS:
					spills = 0
					report_miss_to_host()

func _on_drop_caught(area: Area2D, drop: Area2D) -> void:
	if not buckets.has(area):
		return
	
	water_collected += 1
	add_score(POINTS_PER_DROP)
	# Send 1 unit per drop so P2 gets water immediately each catch
	send_resource_to_partner("dishwater", 1, 1.0)
	_log("📤 Sent dish water (total: %d)" % water_collected)

	drop.queue_free()

func _on_game_over() -> void:
	spawn_timer.stop()
	super._on_game_over()
