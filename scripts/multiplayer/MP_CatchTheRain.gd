extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## ═══════════════════════════════════════════════════════════════════
## MP_CatchTheRain - Player 1 Game
## ═══════════════════════════════════════════════════════════════════
## Player 1 catches falling raindrops with a bucket
## Caught water is sent to Player 2 for filtering
## ═══════════════════════════════════════════════════════════════════

const DROP_SPEED: float = 200.0
const SPAWN_INTERVAL: float = 1.0   # was 1.5 — faster rain = more water for P2
const BUCKET_SPEED: float = 400.0
const BUCKET_HALF_W: float = 60.0
const BUCKET_MARGIN_BOTTOM: float = 100.0
const POINTER_FOLLOW: float = 12.0
const SPAWN_MARGIN: float = 80.0
const MAX_ALLOWED_MISSES: int = 8   # was 3 — generous, uses shared life
## WHAT A CAUGHT DROP PAYS, AND THE TEAM TOTAL THAT ENDS THE ROUND
##
## The catch paid a bare add_score(10) while every sibling catcher in this project pays 5
## (MP_CatchRainAquarium.POINTS_PER_DROP), and the 50-point "team quota" in the comment here was
## never calibrated against what the pair actually earns: with the old 10 and MP_FilterWater's
## old 30-per-unit, a single drop caught and filtered was worth 40 team points, so the target
## landed after two drops — a round decided at t=2s. At 5 here and 15 there a drop carried all
## the way through is worth 20, and 10 such drops is a target that needs most of the round: rain
## spawns every SPAWN_INTERVAL second — 30 drops offered at Medium, 45 once the Hard tier scales
## the timer up — and the partner has to land PARTICLES_PER_WATER taps on each unit sent over.
const POINTS_PER_DROP: int = 5
const TEAM_TARGET: int = 200  # matches MP_FilterWater's TEAM_TARGET — 10 drops caught AND filtered

var bucket: Area2D
var spawn_timer: Timer
var drops_caught: int = 0
var drops_missed: int = 0
var _layout_ready: bool = false
## Where the last touch or mouse event landed in world space, and whether one has arrived.
## The bucket is steered from these instead of polling get_global_mouse_position(): that poll
## returns WORLD coordinates and was being range-checked against 0..viewport_width, which on this
## camera excluded the visible left band (x -384..0) entirely and admitted 334px of off-screen
## right. On a touch build the emulated mouse also reads (0, 0) until the first tap.
var _pointer_active: bool = false
var _pointer_world_x: float = 0.0

func get_instructions() -> String:
	return Localization.get_text("mp_catch_the_rain_instructions") % [POINTS_PER_DROP, TEAM_TARGET, MAX_ALLOWED_MISSES]

func get_controls_text() -> String:
	return Localization.get_text("mp_catch_the_rain_controls")

## Records a pointer position for _process to steer toward. _unhandled_input, not _input, so the
## instruction overlay and the pause menu keep first claim on a tap.
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

func _note_pointer(screen_pos: Vector2) -> void:
	_pointer_world_x = world_from_screen(screen_pos).x
	_pointer_active = true

func _on_multiplayer_ready() -> void:
	# Setup game when multiplayer is ready
	game_name = "Catch the Rain"
	title_key = "catch_the_rain"
	connection_type = "resource_transfer"
	_connect_viewport_resize()
	
	# THE TEAM TARGET, ON BOTH WIN PATHS AT ONCE
	#
	# win_quota is the target MultiplayerMiniGameBase measures — add_score() ends the round early
	# on it and _on_time_up() fails the round when it is missed — and it was never set here, so
	# this round could not be won or lost, only survived, and CoopAdaptation recorded a success
	# from it whatever the players did. GameManager's copy is the CRDT path (the host's
	# _check_win_condition() compares the G-Counter total against it) and it was being set to
	# QUOTA * GameManager.difficulty_multiplier — a SINGLE-PLAYER number, since MP tiers come from
	# CoopAdaptation — so the two targets disagreed and the console could announce TEAM WINS at a
	# score the round went on playing through. One number now, on both paths.
	win_quota = TEAM_TARGET # a TEAM total — the partner's filtering pays into it too
	if GameManager:
		GameManager.set_minigame_quota(TEAM_TARGET)
		_log("🎯 Team target: %d pts (%d per drop caught, plus what the partner filters)"
			% [TEAM_TARGET, POINTS_PER_DROP])
	
	# Create bucket
	_create_bucket()
	
	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = SPAWN_INTERVAL / max(1.0, GameManager.difficulty_multiplier if GameManager else 1.0)
	spawn_timer.timeout.connect(_spawn_raindrop)
	add_child(spawn_timer)
	
	_log("Game ready - Catch raindrops to send water to partner!")

func _on_game_start() -> void:
	# Called when game starts (after countdown)
	spawn_timer.start()
	_log("Catching rain started!")

func _create_bucket() -> void:
	# Create the player's bucket
	bucket = Area2D.new()
	bucket.position = Vector2(0, 0)
	bucket.z_as_relative = false
	bucket.z_index = 50
	add_child(bucket)
	
	# Collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 30)
	collision.shape = shape
	bucket.add_child(collision)
	
	# Visual (Sprite + fallback shape)
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-50, -20), Vector2(50, -20),
		Vector2(60, 20), Vector2(-60, 20)
	])
	body.color = Color(1.0, 0.6, 0.2, 0.9)
	body.z_index = -1
	bucket.add_child(body)

	var rim = Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-55, -25), Vector2(55, -25),
		Vector2(55, -15), Vector2(-55, -15)
	])
	rim.color = Color(1.0, 0.7, 0.3, 0.95)
	rim.z_index = -1
	bucket.add_child(rim)

	var sprite = Sprite2D.new()
	var bucket_texture = MiniGameAssets.create_bucket_texture(100, 40, Color(1.0, 0.6, 0.2))
	if bucket_texture and bucket_texture.get_width() > 0:
		sprite.texture = bucket_texture # Orange bucket
		sprite.position = Vector2(0, 0)
		bucket.add_child(sprite)
	
	# Connect collision
	bucket.area_entered.connect(_on_bucket_collision)
	_update_bucket_layout()

func _connect_viewport_resize() -> void:
	var viewport = get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	_update_bucket_layout()

## Seats the bucket on the visible bottom edge. The first pass centres it; later passes (a resize,
## an orientation flip) only re-seat the height and clamp the x the player steered to, because
## teleporting a steered bucket back to the centre mid-round loses a drop the player had lined up.
func _update_bucket_layout() -> void:
	if bucket == null:
		return
	var view := playfield_rect()
	if view.size.x <= 1.0:
		return
	var y: float = view.end.y - BUCKET_MARGIN_BOTTOM
	if not _layout_ready:
		bucket.position = Vector2(view.get_center().x, y)
		_layout_ready = true
	else:
		bucket.position = Vector2(
			clampf(bucket.position.x, view.position.x + BUCKET_HALF_W, view.end.x - BUCKET_HALF_W), y)

func _spawn_raindrop() -> void:
	# Spawn a falling raindrop
	if not game_active:
		return
	var view := playfield_rect()
	if view.size.x <= 1.0:
		return
	
	var drop = Area2D.new()
	# Across the VISIBLE width, and above the visible top so the drop enters frame instead of
	# blinking into existence. The old band was world x[50, viewport_width - 50]: with the camera
	# at (576, 324) that put ~18% of the rain outside the right edge, uncatchable and costing a
	# shared life every eighth time, while the leftmost 434px never saw a drop at all.
	drop.position = Vector2(
		randf_range(view.position.x + SPAWN_MARGIN, view.end.x - SPAWN_MARGIN),
		view.position.y - 50.0)
	add_child(drop)
	
	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15
	collision.shape = shape
	drop.add_child(collision)
	
	# Visual
	var sprite = Sprite2D.new()
	sprite.texture = MiniGameAssets.create_drop_texture(15, Color(0.3, 0.7, 1.0))
	drop.add_child(sprite)
	
	# Add to moving group
	drop.set_meta("velocity", Vector2(0, DROP_SPEED))
	drop.set_meta("type", "raindrop")

func _process(delta: float) -> void:
	if not game_active:
		return
	if not _layout_ready:
		_update_bucket_layout()
	var view := playfield_rect()
	if view.size.x <= 1.0:
		return
	var min_x: float = view.position.x + BUCKET_HALF_W
	var max_x: float = view.end.x - BUCKET_HALF_W
	
	# Move bucket: arrow keys take priority, otherwise it eases toward the last pointer position.
	if bucket:
		var input_dir: float = Input.get_axis("ui_left", "ui_right")
		if input_dir != 0.0:
			bucket.position.x += input_dir * BUCKET_SPEED * delta
		elif _pointer_active:
			var target_x: float = clampf(_pointer_world_x, min_x, max_x)
			bucket.position.x = lerpf(bucket.position.x, target_x,
				clampf(POINTER_FOLLOW * delta, 0.0, 1.0))
		bucket.position.x = clampf(bucket.position.x, min_x, max_x)
	
	# Move all drops
	for child in get_children():
		if child is Area2D and child.has_meta("velocity"):
			var velocity = child.get_meta("velocity") as Vector2
			child.position += velocity * delta
			# Missed once it has passed the VISIBLE bottom. The old line was viewport height read as
			# world space, 266px below what the player can see on desktop and 686px below it in a
			# taller viewport, so a drop that had already left the screen kept falling.
			if child.position.y > view.end.y + 50.0:
				_on_drop_missed()
				child.queue_free()

func _on_bucket_collision(area: Area2D) -> void:
	# Raindrop caught!
	if not area.has_meta("type"):
		return
	
	if area.get_meta("type") == "raindrop":
		drops_caught += 1
		add_score(POINTS_PER_DROP)
		
		# Send water resource to partner
		send_resource_to_partner("clean_water", 1, 1.0)
		
		# Visual feedback
		_play_catch_effect(area.global_position)
		
		area.queue_free()
		_log("💧 Caught raindrop! Total: %d" % drops_caught)

func _on_drop_missed() -> void:
	# Raindrop missed!
	drops_missed += 1
	_log("❌ Missed raindrop! Missed: %d" % drops_missed)
	
	# Use shared life system instead of hard-failing instantly
	if drops_missed >= MAX_ALLOWED_MISSES:
		drops_missed = 0
		_log("💔 Too many misses - losing shared life!")
		report_miss_to_host()

func _play_catch_effect(pos: Vector2) -> void:
	# Show catch effect
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 5.0
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.gravity = Vector2(0, 200)
	particles.color = Color(0.3, 0.7, 1.0)
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func _on_game_over() -> void:
	# Game over handling
	spawn_timer.stop()
	_log("Game over! Caught: %d, Missed: %d" % [drops_caught, drops_missed])
	super._on_game_over()
