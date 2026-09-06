extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## Bundle 3: Rain Collection for Aquarium
## P1 catches raindrops for aquarium

const MAX_MISSED: int = 5

## Points paid per drop caught, and the TEAM point total that ends the round. win_quota is
## compared against team_score() — the shared G-Counter sum — so the partner filling the
## aquarium pays into this very number at 10 a pour. The overlay used to promise a win for
## "10 drops", a count that is neither necessary nor sufficient: with a 30-point partner
## contribution merged in, the round was measured ending after 4 catches. TEAM_TARGET also
## has to AGREE with MP_FillAquarium's target — the two halves of this bundle read the same
## total, and they held 50 and 100, so P1's round ended at half of what P2 was working toward.
const POINTS_PER_DROP: int = 5
const TEAM_TARGET: int = 100  # matches MP_FillAquarium's ADDS_TO_WIN * POINTS_PER_ADD
## Half the bucket's collision width, and how far its rim sits above the visible bottom. Both
## are world-space, so they stay honest on any viewport once the layout below is driven off the
## camera instead of the 1152x648 numbers this file used to hardcode.
const BUCKET_HALF_W: float = 60.0
const BUCKET_MARGIN_BOTTOM: float = 110.0
## Arrow-key sweep speed, and how hard the bucket is pulled toward a held finger per second.
const BUCKET_SPEED: float = 520.0
## HOW FAST A DROP FALLS
##
## Was an unnamed Vector2(0, 250) inside _spawn_drop. It is the number that decides whether the
## bucket can cross the field before a drop lands - the difference between a miss the player
## made and one the geometry made - and it was the only speed in this file without a name, so
## nothing outside _spawn_drop could read it. Named the way MP_CatchTheRain names its own.
const DROP_SPEED: float = 250.0
const POINTER_FOLLOW: float = 12.0
## Keeps a drop from spawning half off the side of the playfield.
const SPAWN_MARGIN: float = 80.0

var drops_caught: int = 0
var drops_missed: int = 0
var bucket: Area2D
var spawn_timer: Timer
var _layout_ready: bool = false
## Where the last touch or mouse event landed, in world space, and whether one has arrived yet.
## The bucket is steered from these instead of polling get_global_mouse_position(): on an Android
## build the emulated mouse reads (0, 0) until the first tap, and following that poll blindly
## parked the bucket against the left clamp for the whole round — the player's opening drops were
## losses by construction. Recording the event also picks up a real InputEventScreenDrag directly
## rather than depending on emulate_mouse_from_touch to translate it.
var _pointer_active: bool = false
var _pointer_world_x: float = 0.0

func get_instructions() -> String:
	return Localization.get_text("mp_catch_rain_aquarium_instructions") % [POINTS_PER_DROP, TEAM_TARGET, MAX_MISSED]

func get_controls_text() -> String:
	return Localization.get_text("mp_catch_rain_aquarium_controls")

func _on_multiplayer_ready() -> void:
	game_name = "Catch Rain for Aquarium"
	title_key = "mp_title_catch_rain_aquarium"
	win_quota = TEAM_TARGET # a TEAM total — the partner pays into it too
	
	_connect_viewport_resize()
	_create_bucket()
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 0.9   # was 1.2 — more rain = P2 can keep aquarium full
	spawn_timer.timeout.connect(_spawn_raindrop)
	add_child(spawn_timer)
	
	_log("🌧️ Catch rain! Miss %d = lose 1 life" % MAX_MISSED)

func _on_game_start() -> void:
	spawn_timer.start()

func _create_bucket() -> void:
	bucket = Area2D.new()
	add_child(bucket)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(120, 40)
	collision.shape = shape
	bucket.add_child(collision)
	
	var visual = Sprite2D.new()
	visual.texture = MiniGameAssets.create_bucket_texture(120, 40, Color(0.3, 0.3, 0.3))
	bucket.add_child(visual)
	
	_update_bucket_layout()


func _connect_viewport_resize() -> void:
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_update_bucket_layout()


func _update_bucket_layout() -> void:
	if bucket == null:
		return
	var view := playfield_rect()
	if view.size.x <= 1.0:
		return
	var y: float = view.position.y + view.size.y - BUCKET_MARGIN_BOTTOM
	if not _layout_ready:
		bucket.position = Vector2(view.position.x + view.size.x * 0.5, y)
		_layout_ready = true
	else:
		# A rotation mid-round must not teleport a bucket the player is steering; it only gets
		# pulled back inside the new bounds.
		bucket.position = Vector2(
			clampf(bucket.position.x, view.position.x + BUCKET_HALF_W, view.end.x - BUCKET_HALF_W), y)


## Records the pointer from whatever the platform actually sends: screen touch and drag on
## Android, mouse on desktop. Nothing is consumed here — the Area2D pickers elsewhere in the
## scene still see the event.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_note_pointer(event.position)
	elif event is InputEventScreenDrag:
		_note_pointer(event.position)
	elif event is InputEventMouseMotion:
		_note_pointer(event.position)
	elif event is InputEventMouseButton and event.pressed:
		_note_pointer(event.position)


## Screen space to world space, via the base's world_from_screen(): the scene runs under a
## Camera2D, so the two differ by the canvas transform and a raw event.position would steer the
## bucket to the wrong place.
func _note_pointer(screen_pos: Vector2) -> void:
	_pointer_world_x = world_from_screen(screen_pos).x
	_pointer_active = true


func _spawn_raindrop() -> void:
	var view := playfield_rect()
	if view.size.x <= 1.0:
		return
	var drop = Area2D.new()
	# Spawned across the whole playfield, not across the old 100..1052 authoring band, which on a
	# 1920-wide window left a wide dead margin on both sides that no drop ever fell into.
	drop.position = Vector2(randf_range(view.position.x + SPAWN_MARGIN, view.end.x - SPAWN_MARGIN),
		view.position.y - 50.0)
	drop.set_meta("velocity", Vector2(0, DROP_SPEED))
	drop.set_meta("type", "raindrop")
	add_child(drop)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12
	collision.shape = shape
	drop.add_child(collision)
	
	var visual = ColorRect.new()
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	visual.color = Color(0.4, 0.7, 1.0)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.add_child(visual)
	
	drop.area_entered.connect(_on_drop_hit.bind(drop))

func _process(delta: float) -> void:
	if not game_active:
		return
	if not _layout_ready:
		_update_bucket_layout()
	var view := playfield_rect()
	if view.size.x <= 1.0:
		return
	
	# Arrow keys steer, a finger drags. Matched to MP_CatchTheRain so the instruction text is
	# true on both halves of the pairing instead of only on one.
	if bucket:
		var input_dir := Input.get_axis("ui_left", "ui_right")
		if input_dir != 0.0:
			bucket.position.x += input_dir * BUCKET_SPEED * delta
		elif _pointer_active:
			# Eased, not snapped. A drag that teleports the bucket under the finger hides which
			# drop it was lined up with. The target is clamped rather than discarded so a finger
			# that slides off the edge still parks the bucket at that edge.
			var target_x := clampf(_pointer_world_x,
				view.position.x + BUCKET_HALF_W, view.end.x - BUCKET_HALF_W)
			bucket.position.x = lerp(bucket.position.x, target_x,
				clampf(POINTER_FOLLOW * delta, 0.0, 1.0))
		bucket.position.x = clampf(bucket.position.x,
			view.position.x + BUCKET_HALF_W, view.end.x - BUCKET_HALF_W)
	
	# Move drops
	for child in get_children():
		if child is Area2D and child.has_meta("velocity"):
			child.position += child.get_meta("velocity") * delta
			
			# Counted as missed when it leaves the SCREEN, not at the old y > 700, which on this
			# camera is 164 px above the bottom — drops used to vanish in mid-air below the bucket.
			if child.position.y > view.end.y + 50.0:
				drops_missed += 1
				_log("❌ Missed! (%d/%d)" % [drops_missed, MAX_MISSED])
				child.queue_free()
				
				if drops_missed >= MAX_MISSED:
					drops_missed = 0
					report_miss_to_host(bucket)

func _on_drop_hit(area: Area2D, drop: Area2D) -> void:
	if area != bucket:
		return
	
	drops_caught += 1
	add_score(POINTS_PER_DROP, true, bucket)
	
	send_resource_to_partner("rainwater", 1, 1.0)
	_log("💧 Caught drop! Total: %d" % drops_caught)
	
	drop.queue_free()

func _on_game_over() -> void:
	spawn_timer.stop()
	super._on_game_over()
