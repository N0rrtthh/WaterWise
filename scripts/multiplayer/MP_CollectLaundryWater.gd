extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## Bundle 4: Collect Laundry Water
## P1 collects water from washing machine

const CONTAINER_CAPACITY: int = 2     # fills after 2 catches, so P2 gets water sooner
const CONTAINER_HALF_W: float = 75.0  # half of the 150px collision box
const CONTAINER_MARGIN_BOTTOM: float = 140.0
const SPAWN_MARGIN: float = 80.0
const MAX_MISSED: int = 8   # was 5 — more forgiving, uses shared life

## Points paid per stream caught, and the TEAM point total that ends the round. win_quota is
## measured against team_score() — the shared G-Counter sum — which the partner's mopping
## pays into as well, so the old "Catch 10 streams to win" was neither necessary nor sufficient.
const POINTS_PER_CATCH: int = 5
const TEAM_TARGET: int = 50

var water_collected: int = 0
var water_missed: int = 0
var containers: Array = []
var spawn_timer: Timer
var dragging_container: Area2D = null
var _layout_ready: bool = false

func get_instructions() -> String:
	return Localization.get_text("mp_collect_laundry_water_instructions") % [POINTS_PER_CATCH, TEAM_TARGET, MAX_MISSED]

func get_controls_text() -> String:
	return Localization.get_text("mp_collect_laundry_water_controls")

func _on_multiplayer_ready() -> void:
	game_name = "Collect Laundry Water"
	title_key = "mp_title_collect_laundry_water"
	win_quota = TEAM_TARGET # a TEAM total — the partner pays into it too
	set_process_input(true)
	
	_create_containers()
	_connect_viewport_resize()
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.2   # was 2.0 — faster streams = more water for P2
	spawn_timer.timeout.connect(_spawn_water_stream)
	add_child(spawn_timer)
	
	_log("🧺 Catch laundry water! Miss %d = lose 1 life" % MAX_MISSED)

func _on_game_start() -> void:
	spawn_timer.start()

func _create_containers() -> void:
	for i in range(3):
		var container = Area2D.new()
		container.set_meta("capacity", CONTAINER_CAPACITY)
		container.set_meta("current", 0)
		add_child(container)
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(150, 150)
		collision.shape = shape
		container.add_child(collision)
		
		var visual = Sprite2D.new()
		visual.name = "Visual"
		visual.texture = MiniGameAssets.create_bucket_texture(
			150,
			100,
			Color(0.9, 0.9, 0.9)
		)
		# 150x150 hit shape, 150x100 art: the generator writes every pixel from GDScript,
		# so the extra height is a free Sprite2D scale rather than 15k more set_pixel calls.
		visual.scale = Vector2(1.0, 1.5)
		container.add_child(visual)
		
		var label = Label.new()
		label.name = "Label"
		label.text = "0/%d" % CONTAINER_CAPACITY
		label.position = Vector2(-20, -70)
		label.add_theme_font_size_override("font_size", 24)
		MiniGameAssets.outline_text(label)
		container.add_child(label)
		
		container.input_event.connect(_on_container_input.bind(container))
		containers.append(container)
	# Seated from the visible rect, not from authored constants: see seat_catchers() in the base.
	_layout_ready = seat_catchers(containers, CONTAINER_HALF_W, CONTAINER_MARGIN_BOTTOM, false)

func _connect_viewport_resize() -> void:
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	_layout_ready = seat_catchers(
		containers, CONTAINER_HALF_W, CONTAINER_MARGIN_BOTTOM, _layout_ready)

func _on_container_input(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int,
	container: Area2D
) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_container = container

func _input(event: InputEvent) -> void:
	if not game_active:
		return
	
	if (
		event is InputEventMouseButton
		and not event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		dragging_container = null
	
	if event is InputEventMouseMotion and dragging_container:
		dragging_container.position.x = clamp_x_into_playfield(
			world_from_screen(event.position).x, CONTAINER_HALF_W)

func _spawn_water_stream() -> void:
	var stream = Area2D.new()
	stream.position = spawn_above_playfield(SPAWN_MARGIN)
	stream.set_meta("velocity", Vector2(0, 180))
	stream.set_meta("type", "water")
	add_child(stream)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	collision.shape = shape
	stream.add_child(collision)
	
	var visual = ColorRect.new()
	visual.size = Vector2(40, 40)
	visual.position = Vector2(-20, -20)
	visual.color = Color(0.6, 0.6, 0.8)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stream.add_child(visual)
	
	stream.area_entered.connect(_on_water_caught.bind(stream))

func _process(delta: float) -> void:
	if not game_active:
		return
	
	for child in get_children():
		if child is Area2D and child.has_meta("velocity"):
			child.position += child.get_meta("velocity") * delta
			
			if child.position.y > playfield_exit_y():
				water_missed += 1
				_log("❌ Missed water! (%d/%d)" % [water_missed, MAX_MISSED])
				child.queue_free()
				
				if water_missed >= MAX_MISSED:
					water_missed = 0
					_log("💔 Too many misses - losing shared life!")
					report_miss_to_host()

func _on_water_caught(area: Area2D, stream: Area2D) -> void:
	if not area.has_meta("capacity"):
		return
	
	var current = area.get_meta("current", 0)
	var capacity = area.get_meta("capacity", CONTAINER_CAPACITY)
	
	if current >= capacity:
		return
	
	current += 1
	area.set_meta("current", current)
	area.get_node("Label").text = "%d/%d" % [current, capacity]
	
	var visual = area.get_node("Visual")
	visual.modulate = Color(0.6, 0.7, 0.9, 0.3 + current * 0.1)
	
	water_collected += 1
	add_score(POINTS_PER_CATCH)
	stream.queue_free()
	
	if current >= capacity:
		_send_container(area)

func _send_container(container: Area2D) -> void:
	var amount = container.get_meta("capacity", CONTAINER_CAPACITY)
	send_resource_to_partner("laundry_water", amount, 1.0)
	_log("📤 Sent laundry water!")
	
	container.set_meta("current", 0)
	container.get_node("Label").text = "0/%d" % amount
	container.get_node("Visual").modulate = Color(0.5, 0.5, 0.5, 0.3)

func _on_game_over() -> void:
	spawn_timer.stop()
	super._on_game_over()
